const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const Air = @import("../../Air.zig");
const codegen = @import("../../codegen.zig");
const InternPool = @import("../../InternPool.zig");
const link = @import("../../link.zig");
const Zcu = @import("../../Zcu.zig");
const Module = @import("../../Package/Module.zig");
const Type = @import("../../Type.zig");
const Value = @import("../../Value.zig");

const abi = @import("./abi.zig");
const bits = @import("./bits.zig");
const Mir = @import("./Mir.zig");
const Lir = @import("./Lir.zig");
const Emit = @import("./Emit.zig");
const encoding = @import("./encoding.zig");
const RegisterManager = abi.RegisterManager;
const Register = bits.Register;
const FrameIndex = bits.FrameIndex;

const assert = std.debug.assert;
const log = std.log.scoped(.codegen);
const cg_mir_log = std.log.scoped(.codegen_mir);
const verbose_tracking_log = std.log.scoped(.verbose_tracking);

const CodeGen = @This();

const InnerError = codegen.CodeGenError || error{OutOfRegisters};

const err_ret_trace_index: Air.Inst.Index = @enumFromInt(std.math.maxInt(u32));

gpa: Allocator,
pt: Zcu.PerThread,
air: Air,
liveness: Air.Liveness,
bin_file: *link.File,
debug_output: link.File.DebugInfoOutput,

target: *const std.Target,
owner: Owner,
inline_func: InternPool.Index,
mod: *Module,
fn_type: Type,

// Call infos
call_info: abi.CallInfo,
arg_index: u32,
// MCVs of arguments.
// Note that if the argument is passed by reference,
// the MCV will be the pointer.
args_mcv: []MCValue,
ret_mcv: MCValue,

src_loc: Zcu.LazySrcLoc,

/// MIR instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .empty,

reused_operands: std.StaticBitSet(Air.Liveness.bpi - 1) = undefined,
inst_tracking: InstTrackingMap = .empty,
register_manager: RegisterManager = .{},

// Key is the block instruction
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, State) = .empty,

/// Generation of the current scope, increments by 1 for every entered scope.
scope_generation: u32 = 0,

frame_allocs: std.MultiArrayList(FrameAlloc) = .empty,
free_frame_indices: std.ArrayListUnmanaged(FrameIndex) = .empty,
frame_locs: std.MultiArrayList(Mir.FrameLoc) = .empty,

loops: std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
    /// The state to restore before branching.
    state: State,
    /// The branch target.
    target: Mir.Inst.Index,
}) = .empty,

next_temp_index: Temp.Index = @enumFromInt(0),
temp_type: [Temp.Index.max]Type = undefined,

const State = struct {
    registers: RegisterManager.TrackedRegisters,
    reg_tracking: [RegisterManager.RegisterBitSet.bit_length]InstTracking,
    free_registers: RegisterManager.RegisterBitSet,
    inst_tracking_len: u32,
    scope_generation: u32,
};

const Owner = union(enum) {
    nav_index: InternPool.Nav.Index,
    lazy_sym: link.File.LazySymbol,

    fn getSymbolIndex(owner: Owner, cg: *CodeGen) !u32 {
        const pt = cg.pt;
        switch (owner) {
            .nav_index => |nav_index| if (cg.bin_file.cast(.elf)) |elf_file| {
                return elf_file.zigObjectPtr().?.getOrCreateMetadataForNav(pt.zcu, nav_index);
            } else unreachable,
            .lazy_sym => |lazy_sym| if (cg.bin_file.cast(.elf)) |elf_file| {
                return elf_file.zigObjectPtr().?.getOrCreateMetadataForLazySymbol(elf_file, pt, lazy_sym) catch |err|
                    cg.fail("{s} creating lazy symbol", .{@errorName(err)});
            } else unreachable,
        }
    }
};

pub const MCValue = union(enum) {
    /// No runtime bits / not available yet.
    none,
    /// Unreachable.
    /// CFG will not allow this value to be observed.
    unreach,
    /// No more references to this value remain.
    /// The payload is the value of scope_generation at the point where the death occurred
    dead: u32,
    /// The value is undefined.
    undef,
    /// A pointer-sized integer that fits in a register.
    /// If the type is a pointer, this is the pointer address in virtual address space.
    immediate: u64,
    /// The value is in a register.
    register: Register,
    /// The value is split across two registers.
    register_pair: [2]Register,
    /// The value is split across three registers.
    register_triple: [3]Register,
    /// The value is split across four registers.
    register_quadruple: [4]Register,
    /// The value is a constant offset plus the value in a register.
    register_bias: bits.RegisterOffset,
    /// The value is in memory at a hard-coded address.
    /// If the type is a pointer, it means the pointer address is at this memory location.
    memory: u64,
    /// The value is in memory at an address not-yet-allocated by the linker.
    /// This traditionally corresponds to a relocation emitted in a relocatable object file.
    load_symbol: bits.SymbolOffset,
    /// The address of the memory location not-yet-allocated by the linker.
    lea_symbol: bits.SymbolOffset,
    /// The value stored at an offset from a frame index
    /// Payload is a frame address.
    load_frame: bits.FrameAddr,
    /// The address of an offset from a frame index
    /// Payload is a frame address.
    lea_frame: bits.FrameAddr,
    /// A value whose lower-ordered bits are in a register and the others are in a frame.
    register_frame: bits.RegisterFrame,
    /// The value is in memory at a constant offset from the address in a register.
    register_offset: bits.RegisterOffset,
    /// This indicates that we have already allocated a frame index for this instruction,
    /// but it has not been spilled there yet in the current control flow.
    reserved_frame: FrameIndex,
    /// Reference to the value of another AIR.
    air_ref: Air.Inst.Ref,

    fn isModifiable(mcv: MCValue) bool {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .immediate,
            .register_bias,
            .lea_symbol,
            .lea_frame,
            .reserved_frame,
            .air_ref,
            => false,
            .register,
            .register_pair,
            .register_triple,
            .register_quadruple,
            .memory,
            .load_symbol,
            .register_frame,
            .register_offset,
            => true,
            .load_frame => |frame_addr| !frame_addr.index.isNamed(),
        };
    }

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory, .register_offset, .load_frame, .load_symbol => true,
            else => false,
        };
    }

    fn isImmediate(mcv: MCValue) bool {
        return switch (mcv) {
            .immediate => true,
            else => false,
        };
    }

    fn isRegister(mcv: MCValue) bool {
        return switch (mcv) {
            .register => true,
            .register_bias => |reg_off| reg_off.off == 0,
            else => false,
        };
    }

    fn isRegisterOffset(mcv: MCValue) bool {
        return switch (mcv) {
            .register, .register_bias => true,
            else => false,
        };
    }

    fn getReg(mcv: MCValue) ?Register {
        return switch (mcv) {
            .register => |reg| reg,
            .register_bias, .register_offset => |ro| ro.reg,
            .register_frame => |reg_frame| reg_frame.reg,
            else => null,
        };
    }

    fn getRegs(mcv: *const MCValue) []const Register {
        return switch (mcv.*) {
            .register => |*reg| reg[0..1],
            inline .register_pair,
            .register_triple,
            .register_quadruple,
            => |*regs| regs,
            inline .register_bias,
            .register_offset,
            => |*pl| (&pl.reg)[0..1],
            .register_frame => |*reg_frame| (&reg_frame.reg)[0..1],
            else => &.{},
        };
    }

    fn isAddress(mcv: MCValue) bool {
        return switch (mcv) {
            .immediate, .register, .register_bias, .lea_symbol, .lea_frame => true,
            else => false,
        };
    }

    fn address(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .immediate,
            .register,
            .register_pair,
            .register_triple,
            .register_quadruple,
            .register_bias,
            .lea_symbol,
            .lea_frame,
            .reserved_frame,
            .air_ref,
            => unreachable, // not in memory
            .memory => |addr| .{ .immediate = addr },
            .register_offset => |reg_off| switch (reg_off.off) {
                0 => .{ .register = reg_off.reg },
                else => .{ .register_bias = reg_off },
            },
            .load_symbol => |sym_off| .{ .lea_symbol = sym_off },
            .load_frame => |frame_addr| .{ .lea_frame = frame_addr },
            .register_frame => |reg_frame| .{ .lea_frame = reg_frame.frame },
        };
    }

    fn deref(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .register_pair,
            .register_triple,
            .register_quadruple,
            .memory,
            .register_offset,
            .load_symbol,
            .load_frame,
            .register_frame,
            .reserved_frame,
            .air_ref,
            => unreachable, // not dereferenceable
            .immediate => |addr| .{ .memory = addr },
            .register => |reg| .{ .register_offset = .{ .reg = reg } },
            .register_bias => |reg_off| .{ .indirect = reg_off },
            .lea_symbol => |sym_index| .{ .load_symbol = sym_index },
            .lea_frame => |frame_addr| .{ .load_frame = frame_addr },
        };
    }

    fn offset(mcv: MCValue, off: i32) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .reserved_frame,
            .air_ref,
            => unreachable, // not valid
            .register_pair,
            .register_triple,
            .register_quadruple,
            .memory,
            .register_offset,
            .load_symbol,
            .load_frame,
            .register_frame,
            => switch (off) {
                0 => mcv,
                else => unreachable, // not offsettable
            },
            .immediate => |imm| .{ .immediate = @bitCast(@as(i64, @bitCast(imm)) +% off) },
            .register => |reg| .{ .register_offset = .{ .reg = reg, .off = off } },
            .register_bias => |reg_off| .{
                .register_bias = .{ .reg = reg_off.reg, .off = reg_off.off + off },
            },
            .lea_symbol => |symbol_off| .{
                .lea_symbol = .{ .index = symbol_off.index, .off = symbol_off.off + off },
            },
            .lea_frame => |frame_addr| .{
                .lea_frame = .{ .index = frame_addr.index, .off = frame_addr.off + off },
            },
        };
    }

    pub fn format(
        mcv: MCValue,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        switch (mcv) {
            .none, .unreach, .dead, .undef => try writer.print("({s})", .{@tagName(mcv)}),
            .immediate => |pl| try writer.print("0x{x}", .{pl}),
            .register => |pl| try writer.print("{s}", .{@tagName(pl)}),
            .register_pair => |pl| try writer.print("{s}:{s}", .{ @tagName(pl[1]), @tagName(pl[0]) }),
            .register_triple => |pl| try writer.print("{s}:{s}:{s}", .{
                @tagName(pl[2]), @tagName(pl[1]), @tagName(pl[0]),
            }),
            .register_quadruple => |pl| try writer.print("{s}:{s}:{s}:{s}", .{
                @tagName(pl[3]), @tagName(pl[2]), @tagName(pl[1]), @tagName(pl[0]),
            }),
            .register_bias => |pl| try writer.print("{s} + 0x{x}", .{ @tagName(pl.reg), pl.off }),
            .memory => |pl| try writer.print("[0x{x}]", .{pl}),
            .load_symbol => |pl| try writer.print("[sym:{} + 0x{x}]", .{ pl.index, pl.off }),
            .lea_symbol => |pl| try writer.print("sym:{} + 0x{x}", .{ pl.index, pl.off }),
            .load_frame => |pl| try writer.print("[frame:{} + 0x{x}]", .{ pl.index, pl.off }),
            .lea_frame => |pl| try writer.print("frame:{} + 0x{x}", .{ pl.index, pl.off }),
            .register_frame => |pl| try writer.print("{{{s}, (frame:{} + 0x{x})}}", .{ @tagName(pl.reg), pl.frame.index, pl.frame.off }),
            .register_offset => |pl| try writer.print("[{s} + 0x{x}]", .{ @tagName(pl.reg), pl.off }),
            .reserved_frame => |pl| try writer.print("(dead:{})", .{pl}),
            .air_ref => |pl| try writer.print("(air:{})", .{@intFromEnum(pl)}),
        }
    }
};

const InstTrackingMap = std.AutoArrayHashMapUnmanaged(Air.Inst.Index, InstTracking);
const ConstTrackingMap = std.AutoArrayHashMapUnmanaged(InternPool.Index, InstTracking);

const InstTracking = struct {
    long: MCValue,
    short: MCValue,

    fn init(result: MCValue) InstTracking {
        return .{ .long = switch (result) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .load_symbol,
            .lea_symbol,
            .load_frame,
            .lea_frame,
            => result,
            .dead,
            .reserved_frame,
            .air_ref,
            => unreachable,
            .register,
            .register_pair,
            .register_triple,
            .register_quadruple,
            .register_bias,
            .register_offset,
            .register_frame,
            => .none,
        }, .short = result };
    }

    fn getReg(inst_tracking: InstTracking) ?Register {
        return inst_tracking.short.getReg();
    }

    fn getRegs(inst_tracking: *const InstTracking) []const Register {
        return inst_tracking.short.getRegs();
    }

    pub fn format(
        inst_tracking: InstTracking,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (std.meta.eql(inst_tracking.long, inst_tracking.short))
            try writer.print("{}", .{inst_tracking.short})
        else
            try writer.print("|{}| ", .{inst_tracking.long});
    }

    fn die(self: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) !void {
        if (self.short == .dead) return;
        try cg.freeValue(self.short);

        if (self.long == .none) {
            switch (self.short) {
                .load_frame => |frame| {
                    if (frame.off == 0) self.long = .{ .reserved_frame = frame.index };
                },
                else => {},
            }
        }

        self.short = .{ .dead = cg.scope_generation };
        log.debug("{} => {} (death)", .{ inst, self.* });
    }

    fn reuse(
        self: *InstTracking,
        cg: *CodeGen,
        new_inst: Air.Inst.Index,
        old_inst: Air.Inst.Index,
    ) void {
        self.short = .{ .dead = cg.scope_generation };
        log.debug("{} => {} (reuse {})", .{ new_inst, self.*, old_inst });
    }

    fn spill(self: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) !void {
        if (std.meta.eql(self.long, self.short)) return; // Already spilled
        // Allocate or reuse frame index
        switch (self.long) {
            .none => self.long = try cg.allocRegOrMem(cg.typeOfIndex(inst), inst, false),
            .load_frame => {},
            .lea_frame => return,
            .reserved_frame => |index| self.long = .{ .load_frame = .{ .index = index } },
            else => unreachable,
        }
        log.debug("spill {} from {} to {}", .{ inst, self.short, self.long });
        try cg.genCopy(cg.typeOfIndex(inst), self.long, self.short, .{});
    }

    fn trackSpill(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) !void {
        try cg.freeValue(inst_tracking.short);
        inst_tracking.reuseFrame();
        log.debug("%{d} => {} (spilled)", .{ inst, inst_tracking.* });
    }

    fn reuseFrame(inst_tracking: *InstTracking) void {
        inst_tracking.* = .init(switch (inst_tracking.long) {
            .none => switch (inst_tracking.short) {
                .dead => .none,
                else => |short| short,
            },
            .reserved_frame => |index| .{ .load_frame = .{ .index = index } },
            else => |long| long,
        });
    }

    fn liveOut(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) void {
        for (inst_tracking.getRegs()) |reg| {
            if (cg.register_manager.isRegFree(reg)) {
                log.debug("{} => {} (live-out)", .{ inst, inst_tracking.* });
                continue;
            }

            const index = RegisterManager.indexOfRegIntoTracked(reg).?;
            const tracked_inst = cg.register_manager.registers[index];
            const tracking = cg.resolveInst(tracked_inst);

            // Disable death.
            var found_reg = false;
            var remaining_reg: Register = .zero;
            for (tracking.getRegs()) |tracked_reg| if (tracked_reg.id() == reg.id()) {
                assert(!found_reg);
                found_reg = true;
            } else {
                assert(remaining_reg == Register.zero);
                remaining_reg = tracked_reg;
            };
            assert(found_reg);
            tracking.short = switch (remaining_reg) {
                Register.zero => .{ .dead = cg.scope_generation },
                else => .{ .register = remaining_reg },
            };

            // Perform side-effects of freeValue manually.
            cg.register_manager.freeReg(reg);

            log.debug("{} => {} (live-out {})", .{ inst, inst_tracking.*, tracked_inst });
        }
    }
};

const FrameAlloc = struct {
    abi_size: u31,
    spill_pad: u3,
    abi_align: InternPool.Alignment,
    ref_count: u16,

    fn init(alloc_abi: struct { size: u64, pad: u3 = 0, alignment: InternPool.Alignment }) FrameAlloc {
        return .{
            .abi_size = @intCast(alloc_abi.size),
            .spill_pad = alloc_abi.pad,
            .abi_align = alloc_abi.alignment,
            .ref_count = 0,
        };
    }

    fn initType(ty: Type, zcu: *Zcu) FrameAlloc {
        return init(.{
            .size = ty.abiSize(zcu),
            .alignment = ty.abiAlignment(zcu),
        });
    }
};

pub fn legalizeFeatures(_: *const std.Target) ?*const Air.Legalize.Features {
    return null;
}

pub fn generate(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Air.Liveness,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) codegen.CodeGenError!void {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);
    const fn_type: Type = .fromInterned(func.ty);
    const mod = zcu.navFileScope(func.owner_nav).mod.?;

    // initialize CG
    var cg: CodeGen = .{
        .gpa = gpa,
        .pt = pt,
        .air = air,
        .liveness = liveness,
        .target = &mod.resolved_target.result,
        .mod = mod,
        .bin_file = bin_file,
        .debug_output = debug_output,
        .owner = .{ .nav_index = func.owner_nav },
        .inline_func = func_index,
        .arg_index = 0,
        .call_info = undefined,
        .args_mcv = undefined,
        .ret_mcv = undefined,
        .fn_type = fn_type,
        .src_loc = src_loc,
    };
    try cg.inst_tracking.ensureTotalCapacity(gpa, Temp.Index.max);
    for (0..Temp.Index.max) |temp_index| {
        const temp: Temp.Index = @enumFromInt(temp_index);
        cg.inst_tracking.putAssumeCapacityNoClobber(temp.toIndex(), .init(.none));
    }
    defer {
        cg.frame_allocs.deinit(gpa);
        cg.free_frame_indices.deinit(gpa);
        cg.frame_locs.deinit(gpa);
        cg.loops.deinit(gpa);
        cg.blocks.deinit(gpa);
        cg.inst_tracking.deinit(gpa);
        cg.mir_instructions.deinit(gpa);
    }

    cg_mir_log.debug("{}:", .{ip.getNav(func.owner_nav).fqn.fmt(ip)});

    // resolve CC values
    const fn_ty = zcu.typeToFunc(fn_type).?;
    cg.call_info = try cg.resolveCallInfo(&fn_ty);
    defer cg.call_info.deinit(gpa);

    if (cg.call_info.err_ret_trace_reg) |err_ret_trace_reg| {
        cg.register_manager.getRegAssumeFree(err_ret_trace_reg, err_ret_trace_index);
        try cg.inst_tracking.putNoClobber(
            gpa,
            err_ret_trace_index,
            .init(.{ .register = err_ret_trace_reg }),
        );
    }

    cg.args_mcv = try gpa.alloc(MCValue, cg.call_info.params.len);
    defer gpa.free(cg.args_mcv);
    for (cg.call_info.params, 0..) |ccv, i| {
        cg.args_mcv[i] = switch (ccv) {
            .none => .none,
            .register => |reg| .{ .register = reg },
            .register_pair => |regs| .{ .register_pair = regs },
            .frame => |off| .{ .load_frame = .{ .index = .args_frame, .off = off } },
            .split => |pl| .{ .register_frame = .{
                .reg = pl.reg,
                .frame = .{ .index = .args_frame, .off = pl.frame_off },
            } },
            .ref_register => |reg| .{ .register = reg },
            .ref_frame => |off| .{ .load_frame = .{ .index = .args_frame, .off = off } },
        };
        for (ccv.getRegs()) |arg_reg| {
            cg.register_manager.getRegAssumeFree(arg_reg, null);
        }
    }
    cg.ret_mcv = switch (cg.call_info.return_value) {
        .none => .none,
        .register => |reg| .{ .register = reg },
        .register_pair => |regs| .{ .register_pair = regs },
        .frame, .split => unreachable,
        .ref_register => |reg| .{ .register_offset = .{ .reg = reg, .off = 0 } },
        .ref_frame => |off| .{ .load_frame = .{ .index = .args_frame, .off = off } },
    };
    switch (cg.call_info.return_value) {
        .ref_register => |reg| cg.register_manager.getRegAssumeFree(reg, null),
        else => {},
    }

    // init basic frames
    try cg.frame_allocs.resize(gpa, FrameIndex.named_count);
    inline for ([_]FrameIndex{ .stack_frame, .call_frame }) |frame| {
        cg.frame_allocs.set(
            @intFromEnum(frame),
            .init(.{ .size = 0, .alignment = .@"1" }),
        );
    }
    cg.frame_allocs.set(@intFromEnum(FrameIndex.ret_addr), .init(.{
        .size = Type.usize.abiSize(zcu),
        .alignment = Type.usize.abiAlignment(zcu).min(cg.call_info.frame_align),
    }));
    cg.frame_allocs.set(@intFromEnum(FrameIndex.base_ptr), .init(.{
        .size = Type.usize.abiSize(zcu),
        .alignment = cg.call_info.frame_align.min(
            .fromNonzeroByteUnits(cg.target.stackAlignment()),
        ),
    }));
    cg.frame_allocs.set(
        @intFromEnum(FrameIndex.args_frame),
        .init(.{
            .size = cg.call_info.frame_size,
            .alignment = cg.call_info.frame_align,
        }),
    );

    // generate code
    cg.gen() catch |err| switch (err) {
        error.OutOfRegisters => return cg.fail("ran out of registers (Zig compiler bug)", .{}),
        else => |e| return e,
    };

    // TODO end the function at the right brace
    // if (debug_output != .none) _ = try cg.addInst(.{
    //     .tag = .fromPseudo(.dbg_line),
    //     .data = .{ .line_column = .{
    //         .line = func.rbrace_line,
    //         .column = func.rbrace_column,
    //     } },
    // });

    var mir: Mir = .{
        .instructions = cg.mir_instructions.toOwnedSlice(),
        .frame_locs = cg.frame_locs.toOwnedSlice(),
    };
    defer mir.deinit(gpa);

    var emit: Emit = .{
        .air = cg.air,
        .lower = .{
            .bin_file = bin_file,
            .target = cg.target,
            .allocator = gpa,
            .mir = mir,
            .cc = cg.fn_type.fnCallingConvention(zcu),
            .src_loc = src_loc,
            .output_mode = comp.config.output_mode,
            .link_mode = comp.config.link_mode,
            .pic = mod.pic,
        },
        .atom_index = cg.owner.getSymbolIndex(&cg) catch |err| switch (err) {
            error.CodegenFail => return error.CodegenFail,
            else => |e| return e,
        },
        .debug_output = debug_output,
        .code = code,
        .prev_di_loc = .{
            .line = func.lbrace_line,
            .column = func.lbrace_column,
            .is_stmt = switch (debug_output) {
                .dwarf => |dwarf| dwarf.dwarf.debug_line.header.default_is_stmt,
                .plan9 => undefined,
                .none => undefined,
            },
        },
        .prev_di_pc = 0,
    };
    emit.emitMir() catch |err| switch (err) {
        error.LowerFail, error.EmitFail => return cg.failMsg(emit.lower.err_msg.?),
        else => |e| return cg.fail("emit MIR failed: {s} (Zig compiler bug)", .{@errorName(e)}),
    };
}

pub fn generateLazy(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) codegen.CodeGenError!void {
    _ = bin_file;
    _ = pt;
    _ = src_loc;
    _ = lazy_sym;
    _ = code;
    _ = debug_output;

    unreachable;
}

fn gen(cg: *CodeGen) InnerError!void {
    try cg.asmPseudo(.func_prologue, .none);
    try cg.genBody(cg.air.getMainBody());
    try cg.asmPseudo(.func_epilogue, .none);
}

fn fail(cg: *CodeGen, comptime format: []const u8, args: anytype) error{ OutOfMemory, CodegenFail } {
    @branchHint(.cold);
    const zcu = cg.pt.zcu;
    switch (cg.owner) {
        .nav_index => |i| return zcu.codegenFail(i, format, args),
        .lazy_sym => |s| return zcu.codegenFailType(s.ty, format, args),
    }
    return error.CodegenFail;
}

fn failMsg(self: *CodeGen, msg: *Zcu.ErrorMsg) error{ OutOfMemory, CodegenFail } {
    @branchHint(.cold);
    const zcu = self.pt.zcu;
    switch (self.owner) {
        .nav_index => |i| return zcu.codegenFailMsg(i, msg),
        .lazy_sym => |s| return zcu.codegenFailTypeMsg(s.ty, msg),
    }
    return error.CodegenFail;
}

fn addInst(cg: *CodeGen, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = cg.gpa;

    cg_mir_log.debug("  | {}", .{inst});

    try cg.mir_instructions.ensureUnusedCapacity(gpa, 1);
    const result_index: Mir.Inst.Index = @intCast(cg.mir_instructions.len);
    cg.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
}

fn asmPseudo(cg: *CodeGen, tag: Mir.Inst.PseudoTag, data: Mir.Inst.Data) error{OutOfMemory}!void {
    _ = try cg.addInst(.{ .tag = .fromPseudo(tag), .data = data });
}

fn asmInst(cg: *CodeGen, opcode: encoding.OpCode, ops: encoding.Data) error{OutOfMemory}!void {
    _ = try cg.addInst(.initInst(opcode, ops));
}

/// A temporary operand.
/// Either a allocated temp or a Air.Inst.Ref (ref to a AIR inst or a interned val) or error return trace.
const Temp = struct {
    index: Air.Inst.Index,

    const Index = enum(u5) {
        _,

        fn toIndex(index: Index) Air.Inst.Index {
            return .fromTargetIndex(@intFromEnum(index));
        }

        fn fromIndex(index: Air.Inst.Index) Index {
            return @enumFromInt(index.toTargetIndex());
        }

        fn tracking(index: Index, cg: *CodeGen) *InstTracking {
            return &cg.inst_tracking.values()[@intFromEnum(index)];
        }

        fn isValid(index: Index, cg: *CodeGen) bool {
            return @intFromEnum(index) < @intFromEnum(cg.next_temp_index) and
                index.tracking(cg).short != .dead;
        }

        fn typeOf(index: Index, cg: *CodeGen) Type {
            assert(index.isValid(cg));
            return cg.temp_type[@intFromEnum(index)];
        }

        const max = std.math.maxInt(@typeInfo(Index).@"enum".tag_type);
    };

    fn unwrap(temp: Temp, cg: *CodeGen) union(enum) { ref: Air.Inst.Ref, temp: Index, err_ret_trace } {
        switch (temp.index.unwrap()) {
            .ref => |ref| return .{ .ref = ref },
            .target => |target_index| {
                if (@as(Air.Inst.Index, @enumFromInt(target_index)) == err_ret_trace_index) return .err_ret_trace;
                const temp_index: Index = @enumFromInt(target_index);
                assert(temp_index.isValid(cg));
                return .{ .temp = temp_index };
            },
        }
    }

    fn typeOf(temp: Temp, cg: *CodeGen) Type {
        return switch (temp.unwrap(cg)) {
            .ref => switch (cg.air.instructions.items(.tag)[@intFromEnum(temp.index)]) {
                .loop_switch_br => cg.typeOf(cg.air.unwrapSwitch(temp.index).operand),
                else => cg.air.typeOfIndex(temp.index, &cg.pt.zcu.intern_pool),
            },
            .temp => |temp_index| temp_index.typeOf(cg),
            .err_ret_trace => .usize,
        };
    }

    fn tracking(temp: Temp, cg: *CodeGen) InstTracking {
        return cg.inst_tracking.get(temp.index).?;
    }

    fn toLea(temp: *Temp, cg: *CodeGen) InnerError!bool {
        switch (temp.tracking(cg).short) {
            .none,
            .unreach,
            .dead,
            .undef,
            .register_pair,
            .register_triple,
            .register_quadruple,
            .reserved_frame,
            .air_ref,
            => unreachable, // not a valid pointer
            .immediate,
            .register,
            .register_bias,
            .lea_frame,
            .lea_symbol,
            .register_frame,
            => return false,
            .memory,
            .register_offset,
            .load_symbol,
            .load_frame,
            => {
                temp.* = try cg.tempInit(temp.typeOf(cg), temp.tracking(cg).short.address());
                return true;
            },
        }
    }

    fn toMemory(temp: *Temp, cg: *CodeGen) InnerError!bool {
        switch (temp.tracking(cg).short) {
            .none,
            .unreach,
            .dead,
            .undef,
            .register_pair,
            .register_triple,
            .register_quadruple,
            .reserved_frame,
            .air_ref,
            => unreachable, // not a valid pointer
            .immediate,
            .register,
            .register_bias,
            .lea_frame,
            .lea_symbol,
            => {
                temp.* = try cg.tempInit(temp.typeOf(cg), temp.tracking(cg).short.deref());
                return true;
            },
            .memory,
            .register_offset,
            .load_symbol,
            .load_frame,
            .register_frame,
            => return false,
        }
    }

    fn die(temp: Temp, cg: *CodeGen) InnerError!void {
        switch (temp.unwrap(cg)) {
            .ref, .err_ret_trace => {},
            .temp => |temp_index| try temp_index.tracking(cg).die(cg, temp_index.toIndex()),
        }
    }

    fn finish(
        temp: Temp,
        inst: Air.Inst.Index,
        ops: []const Temp,
        cg: *CodeGen,
    ) InnerError!void {
        const tomb_bits = cg.liveness.getTombBits(inst);
        // Tomb operands except for that are used as result
        for (0.., ops) |op_index, op| {
            if (op.index == temp.index) continue;
            if (op.tracking(cg).short != .dead) try op.die(cg);
            if ((tomb_bits & @as(Air.Liveness.Bpi, 1) << @intCast(op_index) == 1) and !cg.reused_operands.isSet(op_index)) {
                switch (op.unwrap(cg)) {
                    .temp, .err_ret_trace => {},
                    .ref => |op_ref| if (op_ref.toIndex()) |op_inst| {
                        try cg.inst_tracking.getPtr(op_inst).?.die(cg, op_inst);
                    },
                }
            }
        }
        if (cg.liveness.isUnused(inst)) try temp.die(cg) else switch (temp.unwrap(cg)) {
            .ref, .err_ret_trace => {
                const ty = cg.typeOfIndex(inst);
                const result_mcv = try cg.allocRegOrMem(ty, inst, true);
                try cg.genCopy(cg.typeOfIndex(inst), result_mcv, temp.tracking(cg).short, .{});

                log.debug("{} => {} (birth)", .{ inst, result_mcv });
                cg.inst_tracking.putAssumeCapacityNoClobber(inst, .init(result_mcv));
            },
            .temp => |temp_index| {
                const temp_tracking = temp_index.tracking(cg);
                log.debug("{} => {} (birth)", .{ inst, temp_tracking.short });
                cg.inst_tracking.putAssumeCapacityNoClobber(inst, .init(temp_tracking.short));
                assert(cg.reuseTemp(temp_tracking, inst, temp_index.toIndex()));
            },
        }
        // Tomb operands that are used as result
        for (0.., ops) |op_index, op| {
            if (op.index != temp.index) continue;
            if ((tomb_bits & @as(Air.Liveness.Bpi, 1) << @intCast(op_index) == 1) and !cg.reused_operands.isSet(op_index)) {
                switch (op.unwrap(cg)) {
                    .temp, .err_ret_trace => {},
                    .ref => |op_ref| if (op_ref.toIndex()) |op_inst| {
                        try cg.inst_tracking.getPtr(op_inst).?.die(cg, op_inst);
                    },
                }
            }
        }
    }

    fn copy(src: Temp, dst: Temp, cg: *CodeGen, ty: Type) InnerError!void {
        try cg.genCopy(ty, dst.tracking(cg).short, src.tracking(cg).short, .{});
    }

    const AccessOptions = struct {
        safety: bool = false,
    };

    fn load(ptr: *Temp, val_ty: Type, opts: AccessOptions, cg: *CodeGen) InnerError!Temp {
        const val = try cg.tempAlloc(val_ty);
        while (try ptr.toLea(cg)) {}
        const val_mcv = val.tracking(cg).short;

        // TODO: safety check
        _ = opts;

        switch (val_mcv) {
            else => |mcv| return cg.fail("{s}: {}\n", .{ @src().fn_name, mcv }),
            // .register => |val_reg| try ptr.loadReg(val_ty, registerAlias(
            //     val_reg,
            //     @intCast(val_ty.abiSize(cg.pt.zcu)),
            // ), cg),
            // inline .register_pair,
            // .register_triple,
            // .register_quadruple,
            // => |val_regs| for (val_regs) |val_reg| {
            //     try ptr.loadReg(val_ty, val_reg, cg);
            //     try ptr.toOffset(@divExact(val_reg.bitSize(), 8), cg);
            //     while (try ptr.toLea(cg)) {}
            // },
            // .register_offset => |val_reg_off| switch (val_reg_off.off) {
            //     0 => try ptr.loadReg(val_ty, registerAlias(
            //         val_reg_off.reg,
            //         @intCast(val_ty.abiSize(cg.pt.zcu)),
            //     ), cg),
            //     else => unreachable,
            // },
            // .memory, .indirect, .load_frame, .load_symbol => {
            //     var val_ptr = try cg.tempInit(.usize, val_mcv.address());
            //     var len = try cg.tempInit(.usize, .{ .immediate = val_ty.abiSize(cg.pt.zcu) });
            //     try val_ptr.memcpy(ptr, &len, cg);
            //     try val_ptr.die(cg);
            //     try len.die(cg);
            // },
        }
        return val;
    }
};

fn getValue(self: *CodeGen, value: MCValue, inst: ?Air.Inst.Index) !void {
    for (value.getRegs()) |reg| try self.register_manager.getReg(reg, inst);
}

fn freeValue(cg: *CodeGen, value: MCValue) !void {
    switch (value) {
        .register => |reg| try cg.freeReg(reg),
        inline .register_pair,
        .register_triple,
        .register_quadruple,
        => |regs| for (regs) |reg| try cg.freeReg(reg),
        .register_bias, .register_offset => |reg_off| try cg.freeReg(reg_off.reg),
        .load_frame => |frame| try cg.freeFrame(frame.index),
        else => {},
    }
}

fn freeReg(cg: *CodeGen, reg: Register) !void {
    cg.register_manager.freeReg(reg);
}

fn freeFrame(cg: *CodeGen, frame: FrameIndex) !void {
    try cg.free_frame_indices.append(cg.gpa, frame);
}

pub fn allocRegOrMem(cg: *CodeGen, ty: Type, inst: ?Air.Inst.Index, use_reg: bool) !MCValue {
    const pt = cg.pt;
    const zcu = pt.zcu;
    const abi_size = std.math.cast(u32, ty.abiSize(zcu)) orelse {
        return cg.fail("type '{}' too big to fit into stack frame", .{ty.fmt(pt)});
    };

    if (use_reg) {
        const max_abi_size = @as(u32, switch (ty.zigTypeTag(zcu)) {
            .float => 16,
            else => 8,
        });
        if (std.math.isPowerOfTwo(abi_size) and abi_size <= max_abi_size) {
            if (cg.register_manager.tryAllocReg(inst, cg.getAllocatableRegSetForType(ty))) |reg| {
                return MCValue{ .register = reg };
            }
        }
    }

    const frame_index = try cg.allocFrameIndex(.initType(ty, zcu));
    return .{ .load_frame = .{ .index = frame_index } };
}

fn allocFrameIndex(cg: *CodeGen, alloc: FrameAlloc) !FrameIndex {
    const frame_allocs_slice = cg.frame_allocs.slice();
    const frame_size = frame_allocs_slice.items(.abi_size);
    const frame_align = frame_allocs_slice.items(.abi_align);

    const stack_frame_align = &frame_align[@intFromEnum(FrameIndex.stack_frame)];
    stack_frame_align.* = stack_frame_align.max(alloc.abi_align);

    for (cg.free_frame_indices.items, 0..) |frame_index, i| {
        const abi_size = frame_size[@intFromEnum(frame_index)];
        if (abi_size != alloc.abi_size) continue;

        // reuse frame
        const abi_align = &frame_align[@intFromEnum(frame_index)];
        abi_align.* = abi_align.max(alloc.abi_align);
        _ = cg.free_frame_indices.swapRemove(i);
        return frame_index;
    }

    const frame_index: FrameIndex = @enumFromInt(cg.frame_allocs.len);
    try cg.frame_allocs.append(cg.gpa, alloc);
    return frame_index;
}

fn getAllocatableRegSetForType(self: *CodeGen, ty: Type) RegisterManager.RegisterBitSet {
    return abi.getAllocatableRegSet(self.getRegClassForType(ty));
}

fn getRegClassForType(self: *CodeGen, ty: Type) Register.Class {
    const pt = self.pt;
    const zcu = pt.zcu;

    if (ty.isRuntimeFloat()) return .float;
    if (ty.isVector(zcu)) unreachable; // TODO implement vector
    return .int;
}

fn typeOf(self: *CodeGen, inst: Air.Inst.Ref) Type {
    const pt = self.pt;
    const zcu = pt.zcu;
    return self.air.typeOf(inst, &zcu.intern_pool);
}

fn typeOfIndex(self: *CodeGen, inst: Air.Inst.Index) Type {
    return Temp.typeOf(.{ .index = inst }, self);
}

fn floatBits(cg: *CodeGen, ty: Type) ?u16 {
    return if (ty.isRuntimeFloat()) ty.floatBits(cg.target) else null;
}

fn reuseTemp(
    cg: *CodeGen,
    tracking: *InstTracking,
    new_inst: Air.Inst.Index,
    old_inst: Air.Inst.Index,
) bool {
    switch (tracking.short) {
        .register,
        .register_pair,
        .register_triple,
        .register_quadruple,
        .register_bias,
        .register_offset,
        => for (tracking.short.getRegs()) |tracked_reg| {
            if (RegisterManager.indexOfRegIntoTracked(tracked_reg)) |tracked_index| {
                cg.register_manager.registers[tracked_index] = new_inst;
            }
        },
        .load_frame => |frame_addr| if (frame_addr.index.isNamed()) return false,
        else => {},
    }
    tracking.reuse(cg, new_inst, old_inst);
    return true;
}

fn resolveCallInfo(cg: *CodeGen, fn_ty: *const InternPool.Key.FuncType) codegen.CodeGenError!abi.CallInfo {
    const cc_tag: std.builtin.CallingConvention.Tag = fn_ty.cc;
    return switch (cc_tag) {
        inline .auto,
        .loongarch64_lp64,
        => |cc| abi.getAbiInfo(cc).CCResolver.resolve(&cg.pt, cg.gpa, cg.target, fn_ty) catch |err| switch (err) {
            error.CCSelectFailed => return cg.fail("Failed to resolve calling convention values", .{}),
            else => |e| return e,
        },
        else => unreachable,
    };
}

fn getAirData(cg: *CodeGen, inst: Air.Inst.Index) Air.Inst.Data {
    return cg.air.instructions.items(.data)[@intFromEnum(inst)];
}

fn genBody(cg: *CodeGen, body: []const Air.Inst.Index) InnerError!void {
    @setEvalBranchQuota(28_600);
    const pt = cg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const air_tags = cg.air.instructions.items(.tag);

    for (body) |inst| {
        if (cg.liveness.isUnused(inst) and !cg.air.mustLower(inst, ip)) continue;

        cg_mir_log.debug("  {}", .{cg.fmtAir(inst)});
        verbose_tracking_log.debug("{}", .{cg.fmtTracking()});

        cg.reused_operands = .initEmpty();
        try cg.inst_tracking.ensureUnusedCapacity(cg.gpa, 1);

        switch (air_tags[@intFromEnum(inst)]) {
            .arg => try cg.airArg(inst),
            .ret => try cg.airRet(inst, false),
            .ret_safe => try cg.airRet(inst, true),
            // TODO: emit debug info
            .dbg_stmt, .dbg_empty_stmt, .dbg_inline_block, .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline => {},
            else => return cg.fail(
                "TODO implement {s} for LoongArch64 CodeGen",
                .{@tagName(air_tags[@intFromEnum(inst)])},
            ),
        }

        try cg.resetTemps(@enumFromInt(0));
        cg.checkInvariantsAfterAirInst();
    }
}

const FormatAirData = struct {
    self: *CodeGen,
    inst: Air.Inst.Index,
};
fn formatAir(
    data: FormatAirData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    data.self.air.dumpInst(data.inst, data.self.pt, data.self.liveness);
}
fn fmtAir(self: *CodeGen, inst: Air.Inst.Index) std.fmt.Formatter(formatAir) {
    return .{ .data = .{ .self = self, .inst = inst } };
}

const FormatTrackingData = struct {
    self: *CodeGen,
};
fn formatTracking(
    data: FormatTrackingData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var it = data.self.inst_tracking.iterator();
    while (it.next()) |entry| try writer.print("\n{} = {}", .{ entry.key_ptr.*, entry.value_ptr.* });
}
fn fmtTracking(self: *CodeGen) std.fmt.Formatter(formatTracking) {
    return .{ .data = .{ .self = self } };
}

fn resetTemps(cg: *CodeGen, from_index: Temp.Index) InnerError!void {
    if (std.debug.runtime_safety) {
        var any_valid = false;
        for (@intFromEnum(from_index)..@intFromEnum(cg.next_temp_index)) |temp_index| {
            const temp: Temp.Index = @enumFromInt(temp_index);
            if (temp.isValid(cg)) {
                any_valid = true;
                log.err("failed to kill {}: {}, tracking: {}", .{
                    temp.toIndex(),
                    cg.temp_type[temp_index].fmt(cg.pt),
                    temp.tracking(cg),
                });
            }
            cg.temp_type[temp_index] = undefined;
        }
        if (any_valid) return cg.fail("failed to kill all temps", .{});
    }
    cg.next_temp_index = from_index;
}

fn tempAlloc(cg: *CodeGen, ty: Type) InnerError!Temp {
    const temp_index = cg.next_temp_index;
    temp_index.tracking(cg).* = .init(try cg.allocRegOrMem(ty, temp_index.toIndex(), true));
    cg.temp_type[@intFromEnum(temp_index)] = ty;
    cg.next_temp_index = @enumFromInt(@intFromEnum(temp_index) + 1);
    return .{ .index = temp_index.toIndex() };
}

fn tempAllocReg(cg: *CodeGen, ty: Type, regs: RegisterManager.RegisterBitSet) InnerError!Temp {
    const temp_index = cg.next_temp_index;
    temp_index.tracking(cg).* = .init(
        .{ .register = try cg.register_manager.allocReg(temp_index.toIndex(), regs) },
    );
    cg.temp_type[@intFromEnum(temp_index)] = ty;
    cg.next_temp_index = @enumFromInt(@intFromEnum(temp_index) + 1);
    return .{ .index = temp_index.toIndex() };
}

fn tempAllocRegPair(cg: *CodeGen, ty: Type, rs: RegisterManager.RegisterBitSet) InnerError!Temp {
    const temp_index = cg.next_temp_index;
    temp_index.tracking(cg).* = .init(
        .{ .register_pair = try cg.register_manager.allocRegs(2, @splat(temp_index.toIndex()), rs) },
    );
    cg.temp_type[@intFromEnum(temp_index)] = ty;
    cg.next_temp_index = @enumFromInt(@intFromEnum(temp_index) + 1);
    return .{ .index = temp_index.toIndex() };
}

fn tempAllocMem(cg: *CodeGen, ty: Type) InnerError!Temp {
    const temp_index = cg.next_temp_index;
    temp_index.tracking(cg).* = .init(
        try cg.allocRegOrMem(ty, temp_index.toIndex(), false),
    );
    cg.temp_type[@intFromEnum(temp_index)] = ty;
    cg.next_temp_index = @enumFromInt(@intFromEnum(temp_index) + 1);
    return .{ .index = temp_index.toIndex() };
}

fn tempInit(cg: *CodeGen, ty: Type, value: MCValue) InnerError!Temp {
    const temp_index = cg.next_temp_index;
    temp_index.tracking(cg).* = .init(value);
    cg.temp_type[@intFromEnum(temp_index)] = ty;
    try cg.getValue(value, temp_index.toIndex());
    cg.next_temp_index = @enumFromInt(@intFromEnum(temp_index) + 1);
    return .{ .index = temp_index.toIndex() };
}

fn tempFromValue(cg: *CodeGen, value: Value) InnerError!Temp {
    return cg.tempInit(value.typeOf(cg.pt.zcu), try cg.genTypedValue(value));
}

fn tempMemFromValue(cg: *CodeGen, value: Value) InnerError!Temp {
    return cg.tempMemFromAlignedValue(.none, value);
}

fn tempMemFromAlignedValue(cg: *CodeGen, alignment: InternPool.Alignment, value: Value) InnerError!Temp {
    return cg.tempInit(value.typeOf(cg.pt.zcu), try cg.lowerUav(value, alignment));
}

fn tempFromOperand(cg: *CodeGen, op_ref: Air.Inst.Ref, op_dies: bool) InnerError!Temp {
    const zcu = cg.pt.zcu;
    const ip = &zcu.intern_pool;

    if (op_dies) {
        const temp_index = cg.next_temp_index;
        const temp: Temp = .{ .index = temp_index.toIndex() };
        const op_inst = op_ref.toIndex().?;
        const tracking = cg.resolveInst(op_inst);
        temp_index.tracking(cg).* = tracking.*;
        if (!cg.reuseTemp(tracking, temp.index, op_inst)) return .{ .index = op_ref.toIndex().? };
        cg.temp_type[@intFromEnum(temp_index)] = cg.typeOf(op_ref);
        cg.next_temp_index = @enumFromInt(@intFromEnum(temp_index) + 1);
        return temp;
    }

    if (op_ref.toIndex()) |op_inst| return .{ .index = op_inst };
    const val = op_ref.toInterned().?;
    return cg.tempInit(.fromInterned(ip.typeOf(val)), try cg.genTypedValue(.fromInterned(val)));
}

fn tempsFromOperandsInner(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    op_temps: []Temp,
    op_refs: []const Air.Inst.Ref,
) InnerError!void {
    for (op_temps, 0.., op_refs) |*op_temp, op_index, op_ref| op_temp.* = try cg.tempFromOperand(op_ref, for (op_refs[0..op_index]) |prev_op_ref| {
        if (op_ref == prev_op_ref) break false;
    } else cg.liveness.operandDies(inst, @intCast(op_index)));
}

inline fn tempsFromOperands(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    op_refs: anytype,
) InnerError![op_refs.len]Temp {
    var op_temps: [op_refs.len]Temp = undefined;
    try cg.tempsFromOperandsInner(inst, &op_temps, &op_refs);
    return op_temps;
}

fn resolveRef(self: *CodeGen, ref: Air.Inst.Ref) InnerError!MCValue {
    const zcu = self.pt.zcu;
    const ty = self.typeOf(ref);

    // If the type has no codegen bits, no need to store it.
    if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;

    const mcv: MCValue = if (ref.toIndex()) |inst| mcv: {
        break :mcv self.inst_tracking.getPtr(inst).?.short;
    } else mcv: {
        break :mcv try self.genTypedValue(.fromInterned(ref.toInterned().?));
    };

    switch (mcv) {
        .none, .unreach, .dead => unreachable,
        else => return mcv,
    }
}

fn resolveInst(self: *CodeGen, inst: Air.Inst.Index) *InstTracking {
    const tracking = self.inst_tracking.getPtr(inst).?;
    return switch (tracking.short) {
        .none, .unreach, .dead => unreachable,
        else => tracking,
    };
}

pub fn spillInstruction(self: *CodeGen, reg: Register, inst: Air.Inst.Index) !void {
    const tracking = self.inst_tracking.getPtr(inst) orelse return;
    if (std.debug.runtime_safety) {
        for (tracking.getRegs()) |tracked_reg| {
            if (tracked_reg.id() == reg.id()) break;
        } else unreachable; // spilled reg not tracked with spilled instruction
    }
    try tracking.spill(self, inst);
}

fn handleGenResult(cg: *CodeGen, res: codegen.GenResult) InnerError!MCValue {
    return switch (res) {
        .mcv => |mcv| switch (mcv) {
            .none => .none,
            .undef => .undef,
            .immediate => |imm| .{ .immediate = imm },
            .memory => |addr| .{ .memory = addr },
            .load_symbol => |sym_index| .{ .load_symbol = .{ .index = sym_index } },
            .lea_symbol => |sym_index| .{ .lea_symbol = .{ .index = sym_index } },
            .load_got, .load_direct, .lea_direct => {
                return cg.fail("TODO: genTypedValue {s}", .{@tagName(mcv)});
            },
        },
        .fail => |msg| return cg.failMsg(msg),
    };
}

fn genTypedValue(cg: *CodeGen, val: Value) InnerError!MCValue {
    return cg.handleGenResult(try codegen.genTypedValue(cg.bin_file, cg.pt, cg.src_loc, val, cg.target.*));
}

fn lowerUav(cg: *CodeGen, val: Value, alignment: InternPool.Alignment) InnerError!MCValue {
    return cg.handleGenResult(try cg.bin_file.lowerUav(cg.pt, val.toIntern(), alignment, cg.src_loc));
}

fn checkInvariantsAfterAirInst(self: *CodeGen) void {
    assert(!self.register_manager.lockedRegsExist());

    if (std.debug.runtime_safety) {
        // check consistency of tracked registers
        var it = self.register_manager.free_registers.iterator(.{ .kind = .unset });
        while (it.next()) |index| {
            const tracked_inst = self.register_manager.registers[index];
            const tracking = self.resolveInst(tracked_inst);
            for (tracking.getRegs()) |reg| {
                if (RegisterManager.indexOfRegIntoTracked(reg).? == index) break;
            } else unreachable; // tracked register not in use
        }
    }
}

const CopyOptions = struct {
    safety: bool = false,
};

fn genCopy(cg: *CodeGen, ty: Type, dst_mcv: MCValue, src_mcv: MCValue, opts: CopyOptions) !void {
    if (dst_mcv == .none) return;
    const zcu = cg.pt.zcu;
    if (!ty.hasRuntimeBits(zcu)) return;

    _ = opts;

    switch (dst_mcv) {
        else => return std.debug.panic("TODO: genCopy {s} => {s}", .{ @tagName(src_mcv), @tagName(dst_mcv) }),
    }
}

fn airArg(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const arg_ty = cg.typeOfIndex(inst);

    const arg_mcv = cg.args_mcv[cg.arg_index];
    cg.arg_index += 1;
    const arg_temp = try cg.tempInit(arg_ty, arg_mcv);

    try arg_temp.finish(inst, &.{}, cg);
}

fn airRet(cg: *CodeGen, inst: Air.Inst.Index, safety: bool) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;
    const un_op = cg.getAirData(inst).un_op;

    const ret_ty = cg.fn_type.fnReturnType(zcu);
    const ret_temp = switch (cg.call_info.return_value) {
        .ref_frame => |_| deref_ret: {
            // load pointer
            var ret_ptr = try cg.tempInit(.usize, cg.ret_mcv);
            const ret_temp = try ret_ptr.load(ret_ty, .{ .safety = safety }, cg);
            try ret_ptr.die(cg);
            break :deref_ret ret_temp;
        },
        else => try cg.tempInit(ret_ty, cg.ret_mcv),
    };

    const un_temp = try cg.tempFromOperand(un_op, false);
    try un_temp.copy(ret_temp, cg, ret_ty);
    try ret_temp.die(cg);

    try (try cg.tempInit(.noreturn, .unreach)).finish(inst, &.{un_temp}, cg);
    try cg.finishReturn(inst);
}

/// Finishes a return.
/// The return value is expected to be copied to ret_mcv.
fn finishReturn(cg: *CodeGen, inst: Air.Inst.Index) !void {
    // lock return value regs
    for (cg.call_info.return_value.getRegs()) |reg| {
        try cg.register_manager.getReg(reg, inst);
    }

    // restore error return trace
    if (cg.call_info.err_ret_trace_reg) |err_ret_trace_reg| {
        if (cg.inst_tracking.getPtr(err_ret_trace_index)) |err_ret_trace| {
            if (switch (err_ret_trace.short) {
                .register => |reg| err_ret_trace_reg != reg,
                else => true,
            }) try cg.genCopy(.usize, .{ .register = err_ret_trace_reg }, err_ret_trace.short, .{});
            err_ret_trace.liveOut(cg, err_ret_trace_index);
        }
    }

    // jump to epilogue
    try cg.asmPseudo(.jump_to_epilogue, .none);
}
