const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const cast = std.math.cast;

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
const AsmParser = @import("./AsmParser.zig");
const RegisterManager = abi.RegisterManager;
const Register = bits.Register;
const FrameIndex = bits.FrameIndex;

const assert = std.debug.assert;
const log = std.log.scoped(.codegen);
const cg_mir_log = std.log.scoped(.codegen_mir);
const cg_select_log = std.log.scoped(.codegen_select);
const tracking_log = std.log.scoped(.tracking);
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
// For ref_frame CCVs, the MCV is the pointer in load_frame.
args_mcv: []MCValue,
ret_mcv: MCValue,

src_loc: Zcu.LazySrcLoc,

/// MIR instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .empty,
epilogue_label: Mir.Inst.Index = undefined,

reused_operands: std.StaticBitSet(Air.Liveness.bpi - 1) = undefined,
inst_tracking: InstTrackingMap = .empty,
register_manager: RegisterManager = .{},

// Key is the block instruction
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockState) = .empty,

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

    fn isRegisterOf(mcv: MCValue, rc: Register.Class) bool {
        return switch (mcv) {
            .register => |reg| reg.class() == rc,
            .register_bias => |reg_off| reg_off.off == 0 and reg_off.reg.class() == rc,
            else => false,
        };
    }

    fn isInRegister(mcv: MCValue) bool {
        return switch (mcv) {
            .register, .register_pair, .register_triple, .register_quadruple => true,
            .register_bias => |reg_off| reg_off.off == 0,
            else => false,
        };
    }

    fn isRegisterBias(mcv: MCValue) bool {
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
            .register_bias => |reg_off| .{ .register_offset = reg_off },
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

    /// Returns MCV of a limb.
    /// Caller does not own returned values.
    fn toLimbValue(mcv: MCValue, limb_index: usize) MCValue {
        switch (mcv) {
            else => std.debug.panic("{s}: {}\n", .{ @src().fn_name, mcv }),
            .register, .immediate, .register_bias, .register_offset, .lea_symbol, .lea_frame => {
                assert(limb_index == 0);
                return mcv;
            },
            inline .register_pair, .register_triple, .register_quadruple => |regs| {
                return .{ .register = regs[limb_index] };
            },
            .load_symbol => |sym_off| {
                return .{ .load_symbol = .{
                    .index = sym_off.index,
                    .off = sym_off.off + @as(u31, @intCast(limb_index)) * 8,
                } };
            },
            .load_frame => |frame_addr| {
                return .{ .load_frame = .{
                    .index = frame_addr.index,
                    .off = frame_addr.off + @as(u31, @intCast(limb_index)) * 8,
                } };
            },
        }
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

    /// Converts a CCV to MCV.
    /// `ref_frame` values will be converted into `load_frame`
    /// pointing to the ptr on the call frame as MCValue cannot
    /// represent double indirect.
    fn fromCCValue(ccv: abi.CCValue, frame: FrameIndex) MCValue {
        return switch (ccv) {
            .none => .none,
            .register => |reg| .{ .register = reg },
            .register_pair => |regs| .{ .register_pair = regs },
            .frame => |off| .{ .load_frame = .{ .index = frame, .off = off } },
            .split => |pl| .{ .register_frame = .{
                .reg = pl.reg,
                .frame = .{ .index = frame, .off = pl.frame_off },
            } },
            .ref_register => |reg| .{ .register_offset = .{ .reg = reg, .off = 0 } },
            .ref_frame => |off| .{ .load_frame = .{ .index = frame, .off = off } },
        };
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
        if (!std.meta.eql(inst_tracking.long, inst_tracking.short))
            try writer.print("|{}| ", .{inst_tracking.long});
        try writer.print("{}", .{inst_tracking.short});
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
        tracking_log.debug("{} => {} (death)", .{ inst, self.* });
    }

    fn reuse(
        self: *InstTracking,
        cg: *CodeGen,
        new_inst: Air.Inst.Index,
        old_inst: Air.Inst.Index,
    ) void {
        tracking_log.debug("{} => {} (reuse {})", .{ new_inst, self.*, old_inst });
        self.short = .{ .dead = cg.scope_generation };
    }

    fn spill(self: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) !void {
        if (std.meta.eql(self.long, self.short)) return; // Already spilled
        // Allocate or reuse frame index
        switch (self.long) {
            .none => self.long = try cg.allocRegOrMem(cg.typeOfIndex(inst), inst, .{ .use_reg = false }),
            .load_frame => {},
            .lea_frame => return,
            .reserved_frame => |index| self.long = .{ .load_frame = .{ .index = index } },
            else => unreachable,
        }
        tracking_log.debug("spill {} from {} to {}", .{ inst, self.short, self.long });
        try cg.genCopy(cg.typeOfIndex(inst), self.long, self.short, .{});
    }

    fn trackSpill(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) !void {
        try cg.freeValue(inst_tracking.short);
        inst_tracking.reuseFrame();
        tracking_log.debug("%{d} => {} (spilled)", .{ inst, inst_tracking.* });
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

    fn resurrect(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index, scope_generation: u32) !void {
        switch (inst_tracking.short) {
            .dead => |die_generation| if (die_generation >= scope_generation) {
                inst_tracking.reuseFrame();
                try cg.getValue(inst_tracking.short, inst);
                tracking_log.debug("%{d} => {} (resurrect)", .{ inst, inst_tracking.* });
            },
            else => {},
        }
    }

    fn verifyMaterialize(inst_tracking: InstTracking, target: InstTracking) void {
        switch (inst_tracking.long) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .lea_frame,
            .load_symbol,
            .lea_symbol,
            => assert(std.meta.eql(inst_tracking.long, target.long)),
            .load_frame,
            .reserved_frame,
            => switch (target.long) {
                .none,
                .load_frame,
                .reserved_frame,
                => {},
                else => unreachable,
            },
            else => unreachable,
        }
    }

    fn materialize(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index, target: InstTracking) !void {
        inst_tracking.verifyMaterialize(target);
        try inst_tracking.materializeUnsafe(cg, inst, target);
    }

    fn materializeUnsafe(inst_tracking: InstTracking, cg: *CodeGen, inst: Air.Inst.Index, target: InstTracking) !void {
        const ty = cg.typeOfIndex(inst);
        if ((inst_tracking.long == .none or inst_tracking.long == .reserved_frame) and target.long == .load_frame)
            try cg.genCopy(ty, target.long, inst_tracking.short, .{});
        try cg.genCopy(ty, target.short, inst_tracking.short, .{});
    }

    fn trackMaterialize(inst_tracking: *InstTracking, inst: Air.Inst.Index, target: InstTracking) void {
        inst_tracking.verifyMaterialize(target);
        // do not clobber reserved frame indices
        inst_tracking.long = if (target.long == .none) switch (inst_tracking.long) {
            .load_frame => |addr| .{ .reserved_frame = addr.index },
            .reserved_frame => inst_tracking.long,
            else => target.long,
        } else target.long;
        inst_tracking.short = target.short;
        tracking_log.debug("%{d} => {} (materialize)", .{ inst, inst_tracking.* });
    }

    fn liveOut(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) void {
        for (inst_tracking.getRegs()) |reg| {
            if (cg.register_manager.isRegFree(reg)) {
                tracking_log.debug("{} => {} (live-out)", .{ inst, inst_tracking.* });
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

            tracking_log.debug("{} => {} (live-out {})", .{ inst, inst_tracking.*, tracked_inst });
        }
    }
};

const FrameAlloc = struct {
    abi_size: u31,
    spill_pad: u3,
    abi_align: InternPool.Alignment,

    fn init(alloc_abi: struct { size: u64, pad: u3 = 0, alignment: InternPool.Alignment }) FrameAlloc {
        return .{
            .abi_size = @intCast(alloc_abi.size),
            .spill_pad = alloc_abi.pad,
            .abi_align = alloc_abi.alignment,
        };
    }

    fn initType(ty: Type, zcu: *Zcu) FrameAlloc {
        return init(.{
            .size = ty.abiSize(zcu),
            .alignment = ty.abiAlignment(zcu),
        });
    }
};

pub fn legalizeFeatures(_: *const std.Target) *const Air.Legalize.Features {
    return comptime &.initMany(&.{
        .expand_intcast_safe,
        .expand_add_safe,
        .expand_sub_safe,
        .expand_mul_safe,
        .expand_packed_load,
        .expand_packed_store,
        .expand_packed_struct_field_val,
        .expand_packed_aggregate_init,
    });
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
        cg.args_mcv[i] = .fromCCValue(ccv, .args_frame);
        for (ccv.getRegs()) |arg_reg| {
            cg.register_manager.getRegAssumeFree(arg_reg, null);
        }
    }
    cg.ret_mcv = .fromCCValue(cg.call_info.return_value, .args_frame);
    switch (cg.call_info.return_value) {
        .ref_register => |reg| cg.register_manager.getRegAssumeFree(reg, null),
        else => {},
    }

    // init basic frames
    try cg.frame_allocs.resize(gpa, FrameIndex.named_count);
    inline for ([_]FrameIndex{
        .stack_frame,
        .call_frame,
        .spill_int_frame,
        .spill_float_frame,
        .ret_addr_frame,
    }) |frame| {
        cg.frame_allocs.set(
            @intFromEnum(frame),
            .init(.{ .size = 0, .alignment = .@"1" }),
        );
    }
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

    // end the function at the right brace
    if (debug_output != .none) _ = try cg.addInst(.{
        .tag = .fromPseudo(.dbg_line_line_column),
        .data = .{ .line_column = .{
            .line = func.rbrace_line,
            .column = func.rbrace_column,
        } },
    });

    // check if $ra needs to be spilled
    const ra_allocated = cg.register_manager.isRegAllocated(.ra);
    if (ra_allocated) {
        cg.frame_allocs.set(
            @intFromEnum(FrameIndex.ret_addr_frame),
            .init(.{ .size = 8, .alignment = .@"8" }),
        );
    }

    // compute frame layout
    const frame_size = try cg.computeFrameLayout();
    log.debug("Frame layout: {} bytes{}", .{ frame_size, cg.fmtFrameLocs() });

    // construct MIR
    var mir: Mir = .{
        .instructions = cg.mir_instructions.toOwnedSlice(),
        .frame_locs = cg.frame_locs.toOwnedSlice(),
        .frame_size = frame_size,
        .epilogue_begin = cg.epilogue_label,
        .spill_ra = ra_allocated,
    };
    defer mir.deinit(gpa);

    // emit MC
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

/// Computes frame layout and fill `frame_locs` based on `frame_allocs`.
/// Returns size of the frame.
fn computeFrameLayout(cg: *CodeGen) !usize {
    const frame_allocs_len = cg.frame_allocs.len;
    try cg.frame_locs.resize(cg.gpa, frame_allocs_len);

    const frame_align = cg.frame_allocs.items(.abi_align);
    const frame_offset = cg.frame_locs.items(.offset);

    // sort frames by alignment
    const frame_alloc_order = try cg.gpa.alloc(FrameIndex, frame_allocs_len - FrameIndex.named_count);
    defer cg.gpa.free(frame_alloc_order);

    for (frame_alloc_order, FrameIndex.named_count..) |*frame_order, frame_index|
        frame_order.* = @enumFromInt(frame_index);

    {
        const SortContext = struct {
            frame_align: @TypeOf(frame_align),
            pub fn lessThan(ctx: @This(), lhs: FrameIndex, rhs: FrameIndex) bool {
                return ctx.frame_align[@intFromEnum(lhs)].compare(.gt, ctx.frame_align[@intFromEnum(rhs)]);
            }
        };
        const sort_context: SortContext = .{ .frame_align = frame_align };
        std.mem.sort(FrameIndex, frame_alloc_order, sort_context, SortContext.lessThan);
    }

    // TODO: use frame pointer when needed
    // TODO: optimize: don't touch sp for leave functions

    // compute locations from the bottom to the top
    var sp_offset: i32 = 0;
    cg.setFrameLoc(.stack_frame, .sp, &sp_offset, true);
    cg.setFrameLoc(.call_frame, .sp, &sp_offset, true);
    for (frame_alloc_order) |frame_index| cg.setFrameLoc(frame_index, .sp, &sp_offset, true);
    cg.setFrameLoc(.spill_float_frame, .sp, &sp_offset, true);
    cg.setFrameLoc(.spill_int_frame, .sp, &sp_offset, true);
    cg.setFrameLoc(.ret_addr_frame, .sp, &sp_offset, true);
    cg.setFrameLoc(.args_frame, .sp, &sp_offset, false);

    return @intCast(sp_offset - frame_offset[@intFromEnum(FrameIndex.call_frame)]);
}

fn setFrameLoc(cg: *CodeGen, frame_index: FrameIndex, base: Register, offset: *i32, comptime aligned: bool) void {
    const frame_i = @intFromEnum(frame_index);
    if (aligned) {
        const alignment = cg.frame_allocs.items(.abi_align)[frame_i];
        offset.* = @intCast(alignment.forward(@intCast(offset.*)));
    }
    cg.frame_locs.set(frame_i, .{ .base = base, .offset = offset.* });
    offset.* += cg.frame_allocs.items(.abi_size)[frame_i];
}

/// Adjusts a frame alloc for a required size and alignment.
fn adjustFrame(cg: *CodeGen, frame: FrameIndex, size: u32, alignment: InternPool.Alignment) void {
    const frame_size =
        &cg.frame_allocs.items(.abi_size)[@intFromEnum(frame)];
    frame_size.* = @max(frame_size.*, @as(u31, @intCast(size)));
    const frame_align =
        &cg.frame_allocs.items(.abi_align)[@intFromEnum(frame)];
    frame_align.* = frame_align.max(alignment);
}

/// Computes static registers that need to be spilled.
fn computeSpillRegs(cg: *CodeGen, regs: []const Register) Mir.RegisterList {
    var list: Mir.RegisterList = .empty;
    for (regs) |reg|
        if (cg.register_manager.isRegAllocated(reg)) list.push(reg);
    return list;
}

/// Adjusts spill frames.
fn adjustSpillFrame(cg: *CodeGen, rc: Register.Class, regs: Mir.RegisterList) void {
    const size = rc.byteSize(cg.target) * regs.count();
    const frame: FrameIndex = switch (rc) {
        .int => .spill_int_frame,
        .float => .spill_float_frame,
        else => unreachable,
    };
    cg.adjustFrame(frame, @intCast(size), .fromByteUnits(@intCast(rc.byteSize(cg.target))));
}

/// Generates the function body.
fn gen(cg: *CodeGen) InnerError!void {
    try cg.asmPseudo(.func_prologue, .none);
    const bp_spill_regs_int = try cg.asmPlaceholder();
    const bp_spill_regs_float = try cg.asmPlaceholder();

    try cg.genBody(cg.air.getMainBody());
    cg.epilogue_label = cg.label();

    // Spill static registers
    const spill_regs_int = cg.computeSpillRegs(&(abi.zigcc.Integer.static_regs));
    const spill_regs_float = cg.computeSpillRegs(&abi.zigcc.Floating.static_regs);
    cg.backpatchPseudo(bp_spill_regs_int, .spill_int_regs, .{ .reg_list = spill_regs_int });
    cg.backpatchPseudo(bp_spill_regs_float, .spill_float_regs, .{ .reg_list = spill_regs_float });
    try cg.asmPseudo(.restore_int_regs, .{ .reg_list = spill_regs_int });
    try cg.asmPseudo(.restore_float_regs, .{ .reg_list = spill_regs_float });
    cg.adjustSpillFrame(.int, spill_regs_int);
    cg.adjustSpillFrame(.float, spill_regs_float);

    try cg.asmPseudo(.func_epilogue, .none);
}

/// Generates a lexical block.
fn genBodyBlock(cg: *CodeGen, body: []const Air.Inst.Index) InnerError!void {
    if (cg.debug_output != .none) try cg.asmPseudo(.dbg_enter_block, .none);
    try cg.genBody(body);
    if (cg.debug_output != .none) try cg.asmPseudo(.dbg_exit_block, .none);
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

    try cg.mir_instructions.ensureUnusedCapacity(gpa, 1);
    const result_index: Mir.Inst.Index = @intCast(cg.mir_instructions.len);

    cg_mir_log.debug("  | {}: {}", .{ result_index, inst });

    cg.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
}

fn backpatchInst(cg: *CodeGen, index: Mir.Inst.Index, inst: Mir.Inst) void {
    cg_mir_log.debug("  | backpatch: {}: {}", .{ index, inst });
    cg.mir_instructions.set(index, inst);
}

inline fn asmPseudo(cg: *CodeGen, tag: Mir.Inst.PseudoTag, data: Mir.Inst.Data) error{OutOfMemory}!void {
    _ = try cg.addInst(.{ .tag = .fromPseudo(tag), .data = data });
}

inline fn asmPlaceholder(cg: *CodeGen) error{OutOfMemory}!u32 {
    return cg.addInst(.{ .tag = .fromPseudo(.none), .data = .none });
}

inline fn backpatchPseudo(cg: *CodeGen, index: Mir.Inst.Index, tag: Mir.Inst.PseudoTag, data: Mir.Inst.Data) void {
    cg.backpatchInst(index, .{ .tag = .fromPseudo(tag), .data = data });
}

inline fn asmInst(cg: *CodeGen, inst: encoding.Inst) error{OutOfMemory}!void {
    _ = try cg.addInst(.initInst(inst));
}

fn asmBr(cg: *CodeGen, target: ?Mir.Inst.Index, cond: Mir.BranchCondition) InnerError!Mir.Inst.Index {
    return cg.addInst(.{
        .tag = .fromPseudo(.branch),
        .data = .{
            .br = .{
                .inst = target orelse 0, // use zero instead of undefined to make debugging easier
                .cond = cond,
            },
        },
    });
}

fn performReloc(cg: *CodeGen, reloc: Mir.Inst.Index) void {
    cg_mir_log.debug("  | <-- reloc {}", .{reloc});

    const next_inst: u32 = @intCast(cg.mir_instructions.len);
    switch (cg.mir_instructions.items(.tag)[reloc].unwrap()) {
        .inst => unreachable,
        .pseudo => |tag| {
            switch (tag) {
                .branch => cg.mir_instructions.items(.data)[reloc].br.inst = next_inst,
                else => unreachable,
            }
        },
    }
}

fn label(cg: *CodeGen) Mir.Inst.Index {
    return @intCast(cg.mir_instructions.len);
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

    fn isMut(temp: Temp, cg: *CodeGen) bool {
        return switch (temp.unwrap(cg)) {
            .ref, .err_ret_trace => false,
            .temp => |_| temp.tracking(cg).short.isModifiable(),
        };
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
                try temp.die(cg);
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
                try temp.die(cg);
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

    fn getReg(temp: Temp, cg: *CodeGen) Register {
        return temp.tracking(cg).getReg().?;
    }

    fn getImm(temp: Temp, cg: *CodeGen) u64 {
        return temp.tracking(cg).short.immediate;
    }

    fn moveToMemory(temp: *Temp, cg: *CodeGen, mut: bool) InnerError!bool {
        const temp_mcv = temp.tracking(cg).short;
        if (temp_mcv.isMemory() and (temp_mcv.isModifiable() or !mut)) {
            return false;
        } else {
            const temp_ty = temp.typeOf(cg);
            try temp.die(cg);
            temp.* = try cg.tempAllocMem(temp_ty);
            try cg.genCopy(temp_ty, temp.tracking(cg).short, temp_mcv, .{});
            return true;
        }
    }

    fn moveToRegister(temp: *Temp, cg: *CodeGen, rc: Register.Class, mut: bool) InnerError!bool {
        const temp_mcv = temp.tracking(cg).short;
        if (temp.tracking(cg).short.isRegister() and (temp_mcv.isModifiable() or !mut)) {
            return false;
        } else {
            const old_mcv = temp.tracking(cg).short;
            const temp_ty = temp.typeOf(cg);
            try temp.die(cg);
            temp.* = try cg.tempAllocReg(temp_ty, abi.getAllocatableRegSet(rc));
            try cg.genCopy(temp_ty, temp.tracking(cg).short, old_mcv, .{});
            return true;
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
                switch (temp.index.unwrap()) {
                    .ref => |op_ref| if (op_ref.toIndex()) |op_inst| {
                        try cg.inst_tracking.getPtr(op_inst).?.die(cg, op_inst);
                    },
                    .target => {},
                }
            }
        }
        if (cg.liveness.isUnused(inst)) try temp.die(cg) else switch (temp.unwrap(cg)) {
            .ref, .err_ret_trace => {
                const ty = cg.typeOfIndex(inst);
                const result_mcv = try cg.allocRegOrMem(ty, inst, .{});
                try cg.genCopy(cg.typeOfIndex(inst), result_mcv, temp.tracking(cg).short, .{});

                tracking_log.debug("{} => {} (birth copied from {})", .{ inst, result_mcv, temp.index });
                cg.inst_tracking.putAssumeCapacityNoClobber(inst, .init(result_mcv));
            },
            .temp => |temp_index| {
                const temp_tracking = temp_index.tracking(cg);
                tracking_log.debug("{} => {} (birth from {})", .{ inst, temp_tracking.short, temp.index });
                cg.inst_tracking.putAssumeCapacityNoClobber(inst, .init(temp_tracking.short));
                assert(cg.reuseTemp(temp_tracking, inst, temp_index.toIndex()));
            },
        }
        // Tomb operands that are used as result
        for (0.., ops) |op_index, op| {
            if (op.index != temp.index) continue;
            if ((tomb_bits & @as(Air.Liveness.Bpi, 1) << @intCast(op_index) == 1) and !cg.reused_operands.isSet(op_index)) {
                switch (temp.index.unwrap()) {
                    .ref => |op_ref| if (op_ref.toIndex()) |op_inst| {
                        try cg.inst_tracking.getPtr(op_inst).?.die(cg, op_inst);
                    },
                    .target => {},
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
        const val = try cg.tempAlloc(val_ty, .{});
        while (try ptr.toLea(cg)) {}
        const val_mcv = val.tracking(cg).short;

        // TODO: safety check
        _ = opts;

        switch (val_mcv) {
            else => |mcv| return cg.fail("{s}: {}\n", .{ @src().fn_name, mcv }),
        }
        return val;
    }

    fn getLimbCount(temp: Temp, cg: *CodeGen) u64 {
        return std.math.divCeil(u64, temp.typeOf(cg).abiSize(cg.pt.zcu), 8) catch unreachable;
    }

    fn getLimb(temp: Temp, limb_ty: Type, limb_index: u28, cg: *CodeGen) InnerError!Temp {
        const new_temp_index = cg.next_temp_index;
        cg.next_temp_index = @enumFromInt(@intFromEnum(new_temp_index) + 1);
        cg.temp_type[@intFromEnum(new_temp_index)] = limb_ty;
        switch (temp.tracking(cg).short) {
            else => |mcv| std.debug.panic("{s}: {}\n", .{ @src().fn_name, mcv }),
            .immediate => |imm| {
                assert(limb_index == 0);
                new_temp_index.tracking(cg).* = .init(.{ .immediate = imm });
            },
            .register => |reg| {
                assert(limb_index == 0);
                const new_reg =
                    try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterClass.int);
                new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                try cg.asmInst(.ori(new_reg, reg, 0));
            },
            inline .register_pair, .register_triple, .register_quadruple => |regs| {
                const new_reg =
                    try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterClass.int);
                new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                try cg.asmInst(.ori(new_reg, regs[limb_index], 0));
            },
            .register_bias, .register_offset => |_| {
                assert(limb_index == 0);
                const new_reg =
                    try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterClass.int);
                new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                try cg.genCopyToReg(.usize, new_reg, temp.tracking(cg).short, .{});
            },
            .load_symbol => |sym_off| {
                const new_reg =
                    try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterClass.int);
                new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                try cg.genCopyToReg(.usize, new_reg, .{ .load_symbol = .{
                    .index = sym_off.index,
                    .off = sym_off.off + @as(u31, limb_index) * 8,
                } }, .{});
            },
            .lea_symbol => |sym_off| {
                assert(limb_index == 0);
                new_temp_index.tracking(cg).* = .init(.{ .lea_symbol = sym_off });
            },
            .load_frame => |frame_addr| {
                const new_reg =
                    try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterClass.int);
                new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                try cg.genCopyToReg(.usize, new_reg, .{ .load_frame = .{
                    .index = frame_addr.index,
                    .off = frame_addr.off + @as(u31, limb_index) * 8,
                } }, .{});
            },
            .lea_frame => |frame_addr| {
                assert(limb_index == 0);
                new_temp_index.tracking(cg).* = .init(.{ .lea_frame = frame_addr });
            },
        }
        return .{ .index = new_temp_index.toIndex() };
    }

    /// Returns MCV of a limb.
    /// Caller does not own return values.
    fn toLimbValue(temp: Temp, limb_index: usize, cg: *CodeGen) MCValue {
        return temp.tracking(cg).short.toLimbValue(limb_index);
    }

    /// Loads `val` to `temp` if `val` is not in regs yet.
    /// Returns either MCV of self if copy occurred or `val` if `val` is already in regs.
    fn ensureReg(temp: Temp, cg: *CodeGen, val: MCValue) InnerError!MCValue {
        if (val.isInRegister()) {
            return val;
        } else {
            const temp_mcv = temp.tracking(cg).short;
            try cg.genCopyToReg(temp.typeOf(cg), temp.getReg(cg), val, .{});
            return temp_mcv;
        }
    }

    fn truncateRegister(temp: Temp, cg: *CodeGen) !void {
        const temp_tracking = temp.tracking(cg);
        const regs = temp_tracking.getRegs();
        assert(regs.len > 0);
        return cg.truncateRegister(temp.typeOf(cg), regs[regs.len - 1]);
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

const MCVAllocOptions = struct {
    use_reg: bool = true,
    use_frame: bool = true,
};

fn canAllocInReg(cg: *CodeGen, ty: Type) bool {
    const zcu = cg.pt.zcu;
    const abi_size = ty.abiSize(zcu);
    const max_abi_size = @as(u32, switch (ty.zigTypeTag(zcu)) {
        .float => 16,
        else => 8,
    });
    return std.math.isPowerOfTwo(abi_size) and abi_size <= max_abi_size;
}

pub fn allocReg(cg: *CodeGen, ty: Type, inst: ?Air.Inst.Index) !Register {
    if (cg.register_manager.tryAllocReg(inst, cg.getAllocatableRegSetForType(ty))) |reg| {
        return reg;
    } else {
        return cg.fail("Cannot allocate register for {} (Zig compiler bug)", .{ty.fmt(cg.pt)});
    }
}

pub fn allocRegAndLock(cg: *CodeGen, ty: Type) !struct { Register, RegisterManager.RegisterLock } {
    const reg = try cg.allocReg(ty, null);
    const lock = cg.register_manager.lockRegAssumeUnused(reg);
    return .{ reg, lock };
}

pub fn allocRegOrMem(cg: *CodeGen, ty: Type, inst: ?Air.Inst.Index, opts: MCVAllocOptions) !MCValue {
    const zcu = cg.pt.zcu;

    if (opts.use_reg and cg.canAllocInReg(ty)) {
        if (cg.register_manager.tryAllocReg(inst, cg.getAllocatableRegSetForType(ty))) |reg| {
            return .{ .register = reg };
        }
    }

    if (opts.use_frame) {
        const frame_index = try cg.allocFrameIndex(.initType(ty, zcu));
        return .{ .load_frame = .{ .index = frame_index } };
    }

    return cg.fail("Cannot allocate {} with options {} (Zig compiler bug)", .{ ty.fmt(cg.pt), opts });
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
    return if (ty.isRuntimeFloat()) ty.floatBits(cg.target.*) else null;
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

inline fn getAirData(cg: *CodeGen, inst: Air.Inst.Index) Air.Inst.Data {
    return cg.air.instructions.items(.data)[@intFromEnum(inst)];
}

const State = struct {
    registers: RegisterManager.TrackedRegisters,
    reg_tracking: [RegisterManager.RegisterBitSet.bit_length]InstTracking,
    free_registers: RegisterManager.RegisterBitSet,
    next_temp_index: Temp.Index,
    inst_tracking_len: u32,
    scope_generation: u32,
};

fn initRetroactiveState(cg: *CodeGen) State {
    var state: State = undefined;
    state.next_temp_index = cg.next_temp_index;
    state.inst_tracking_len = @intCast(cg.inst_tracking.count());
    state.scope_generation = cg.scope_generation;
    cg.scope_generation += 1;
    return state;
}

fn saveRetroactiveState(cg: *CodeGen, state: *State) !void {
    const free_registers = cg.register_manager.free_registers;
    var it = free_registers.iterator(.{ .kind = .unset });
    while (it.next()) |index| {
        const tracked_inst = cg.register_manager.registers[index];
        state.registers[index] = tracked_inst;
        state.reg_tracking[index] = cg.inst_tracking.get(tracked_inst).?;
    }
    state.free_registers = free_registers;
}

fn saveState(cg: *CodeGen) !State {
    var state = cg.initRetroactiveState();
    try cg.saveRetroactiveState(&state);
    return state;
}

fn restoreState(cg: *CodeGen, state: State, deaths: []const Air.Inst.Index, comptime opts: struct {
    emit_instructions: bool,
    update_tracking: bool,
    resurrect: bool,
    close_scope: bool,
}) !void {
    if (opts.close_scope) {
        // kill temps
        for (@intFromEnum(state.next_temp_index)..@intFromEnum(cg.next_temp_index)) |temp_i|
            try (Temp{ .index = @enumFromInt(temp_i) }).die(cg);
        cg.next_temp_index = state.next_temp_index;

        // kill inst results
        for (
            cg.inst_tracking.keys()[state.inst_tracking_len..],
            cg.inst_tracking.values()[state.inst_tracking_len..],
        ) |inst, *tracking| try tracking.die(cg, inst);
        cg.inst_tracking.shrinkRetainingCapacity(state.inst_tracking_len);
    }

    if (opts.resurrect) {
        // resurrect temps
        for (
            cg.inst_tracking.keys()[0..@intFromEnum(state.next_temp_index)],
            cg.inst_tracking.values()[0..@intFromEnum(state.next_temp_index)],
        ) |inst, *tracking| try tracking.resurrect(cg, inst, state.scope_generation);
        // recurrect inst results
        for (
            cg.inst_tracking.keys()[Temp.Index.max..state.inst_tracking_len],
            cg.inst_tracking.values()[Temp.Index.max..state.inst_tracking_len],
        ) |inst, *tracking| try tracking.resurrect(cg, inst, state.scope_generation);
    }
    for (deaths) |death| try cg.inst_tracking.getPtr(death).?.die(cg, death);

    const ExpectedContents = [@typeInfo(RegisterManager.TrackedRegisters).array.len]RegisterManager.RegisterLock;
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        if (opts.update_tracking) {} else std.heap.stackFallback(@sizeOf(ExpectedContents), cg.gpa);

    var reg_locks = if (opts.update_tracking) {} else try std.ArrayList(RegisterManager.RegisterLock).initCapacity(
        stack.get(),
        @typeInfo(ExpectedContents).array.len,
    );
    defer if (!opts.update_tracking) {
        for (reg_locks.items) |lock| cg.register_manager.unlockReg(lock);
        reg_locks.deinit();
    };

    // restore register state
    for (
        0..,
        cg.register_manager.registers,
        state.registers,
        state.reg_tracking,
    ) |reg_i, current_slot, target_slot, reg_tracking| {
        const reg_index: RegisterManager.TrackedIndex = @intCast(reg_i);
        const current_maybe_inst = if (cg.register_manager.isRegIndexFree(reg_index)) null else current_slot;
        const target_maybe_inst = if (state.free_registers.isSet(reg_index)) null else target_slot;

        if (std.debug.runtime_safety) if (target_maybe_inst) |target_inst|
            assert(cg.inst_tracking.getIndex(target_inst).? < state.inst_tracking_len);

        if (opts.emit_instructions and current_maybe_inst != target_maybe_inst) {
            if (current_maybe_inst) |current_inst|
                try cg.inst_tracking.getPtr(current_inst).?.spill(cg, current_inst);
            if (target_maybe_inst) |target_inst|
                try cg.inst_tracking.getPtr(target_inst).?.materialize(cg, target_inst, reg_tracking);
        }
        if (opts.update_tracking) {
            if (current_maybe_inst) |current_inst| {
                try cg.inst_tracking.getPtr(current_inst).?.trackSpill(cg, current_inst);
                cg.register_manager.freeRegIndex(reg_index);
            }
            if (target_maybe_inst) |target_inst| {
                cg.register_manager.getRegIndexAssumeFree(reg_index, target_inst);
                cg.inst_tracking.getPtr(target_inst).?.trackMaterialize(target_inst, reg_tracking);
            }
        } else if (target_maybe_inst) |_|
            try reg_locks.append(cg.register_manager.lockRegIndexAssumeUnused(reg_index));
    }

    // verify register state
    if (opts.update_tracking and std.debug.runtime_safety) {
        assert(cg.register_manager.free_registers.eql(state.free_registers));
        var used_reg_it = state.free_registers.iterator(.{ .kind = .unset });
        while (used_reg_it.next()) |index|
            assert(cg.register_manager.registers[index] == state.registers[index]);
    }
}

const BlockState = struct {
    state: State,
    relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .empty,

    fn deinit(self: *BlockState, gpa: Allocator) void {
        self.relocs.deinit(gpa);
        self.* = undefined;
    }
};

/// Generates a AIR block.
fn genBody(cg: *CodeGen, body: []const Air.Inst.Index) InnerError!void {
    @setEvalBranchQuota(28_600);
    const pt = cg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const air_tags = cg.air.instructions.items(.tag);

    for (body) |inst| {
        if (cg.liveness.isUnused(inst) and !cg.air.mustLower(inst, ip)) continue;

        cg_mir_log.debug("{}", .{cg.fmtAir(inst)});
        verbose_tracking_log.debug("{}", .{cg.fmtTracking()});

        cg.reused_operands = .initEmpty();
        try cg.inst_tracking.ensureUnusedCapacity(cg.gpa, 1);

        switch (air_tags[@intFromEnum(inst)]) {
            .arg => try cg.airArg(inst),
            .ret => try cg.airRet(inst, false),
            .ret_safe => try cg.airRet(inst, true),
            .ret_load => try cg.airRetLoad(inst),

            .add, .add_wrap => try cg.airArithBinOp(inst, .add),
            .sub, .sub_wrap => try cg.airArithBinOp(inst, .sub),

            .bit_and => try cg.airLogicBinOp(inst, .@"and"),
            .bit_or => try cg.airLogicBinOp(inst, .@"or"),
            .xor => try cg.airLogicBinOp(inst, .xor),

            .bitcast => try cg.airBitCast(inst),

            .assembly => cg.airAsm(inst) catch |err| switch (err) {
                error.AsmParseFail => return error.CodegenFail,
                else => |e| return e,
            },
            .trap => try cg.asmInst(.@"break"(0)),
            .breakpoint => try cg.asmInst(.@"break"(0)),

            .ret_addr => try cg.airRetAddr(inst),
            .frame_addr => try (try cg.tempInit(.usize, .{ .lea_frame = .{ .index = .stack_frame } })).finish(inst, &.{}, cg),

            .alloc => try cg.airAlloc(inst),
            .ret_ptr => try cg.airRetPtr(inst),
            .inferred_alloc, .inferred_alloc_comptime => unreachable,
            .load => try cg.airLoad(inst),
            .store => try cg.airStore(inst),

            .call => try cg.airCall(inst, .auto),
            .call_always_tail => try cg.airCall(inst, .always_tail),
            .call_never_tail => try cg.airCall(inst, .never_tail),
            .call_never_inline => try cg.airCall(inst, .never_inline),

            .cmp_eq => try cg.airCompareToBool(inst, .{ .cond = .eq, .swap = false, .opti = false }),
            .cmp_eq_optimized => try cg.airCompareToBool(inst, .{ .cond = .eq, .swap = false, .opti = true }),
            .cmp_neq => try cg.airCompareToBool(inst, .{ .cond = .ne, .swap = false, .opti = false }),
            .cmp_neq_optimized => try cg.airCompareToBool(inst, .{ .cond = .ne, .swap = false, .opti = true }),
            .cmp_lt => try cg.airCompareToBool(inst, .{ .cond = .gt, .swap = true, .opti = false }),
            .cmp_lt_optimized => try cg.airCompareToBool(inst, .{ .cond = .gt, .swap = true, .opti = true }),
            .cmp_lte => try cg.airCompareToBool(inst, .{ .cond = .le, .swap = false, .opti = false }),
            .cmp_lte_optimized => try cg.airCompareToBool(inst, .{ .cond = .le, .swap = false, .opti = true }),
            .cmp_gt => try cg.airCompareToBool(inst, .{ .cond = .gt, .swap = false, .opti = false }),
            .cmp_gt_optimized => try cg.airCompareToBool(inst, .{ .cond = .gt, .swap = false, .opti = true }),
            .cmp_gte => try cg.airCompareToBool(inst, .{ .cond = .le, .swap = true, .opti = false }),
            .cmp_gte_optimized => try cg.airCompareToBool(inst, .{ .cond = .le, .swap = true, .opti = true }),

            .block => try cg.airBlock(inst),
            .dbg_inline_block => try cg.airDbgInlineBlock(inst),
            .br => try cg.airBr(inst),
            .cond_br => try cg.airCondBr(inst),

            .unreach => {},

            .intcast_safe,
            .add_safe,
            .sub_safe,
            .mul_safe,
            => return cg.fail("legalization miss (Zig compiler bug)", .{}),

            .dbg_stmt => if (cg.debug_output != .none) {
                const dbg_stmt = cg.getAirData(inst).dbg_stmt;
                try cg.asmPseudo(.dbg_line_stmt_line_column, .{ .line_column = .{
                    .line = dbg_stmt.line,
                    .column = dbg_stmt.column,
                } });
            },
            .dbg_empty_stmt => if (cg.debug_output != .none) {
                if (cg.mir_instructions.len > 0) {
                    const prev_mir_tag = &cg.mir_instructions.items(.tag)[cg.mir_instructions.len - 1];
                    if (prev_mir_tag.* == Mir.Inst.Tag.fromPseudo(.dbg_line_line_column))
                        prev_mir_tag.* = Mir.Inst.Tag.fromPseudo(.dbg_line_stmt_line_column);
                }
                try cg.asmInst(.andi(.r0, .r0, 0));
            },
            // TODO: emit debug info
            .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline => {},
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

fn formatFrameLocs(
    cg: *CodeGen,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    for (0..cg.frame_allocs.len) |i| {
        try writer.print("\n- {}: {}\n      @ {}", .{ @as(FrameIndex, @enumFromInt(i)), cg.frame_allocs.get(i), cg.frame_locs.get(i) });
    }
}
fn fmtFrameLocs(self: *CodeGen) std.fmt.Formatter(formatFrameLocs) {
    return .{ .data = self };
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

fn tempAlloc(cg: *CodeGen, ty: Type, opts: MCVAllocOptions) InnerError!Temp {
    const temp_index = cg.next_temp_index;
    temp_index.tracking(cg).* = .init(try cg.allocRegOrMem(ty, temp_index.toIndex(), opts));
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
        try cg.allocRegOrMem(ty, temp_index.toIndex(), .{ .use_reg = false }),
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
    tracking_log.debug("{} => {} (birth)", .{ temp_index.toIndex(), value });
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
        tracking_log.debug("{} => {} (birth from operand)", .{ temp_index.toIndex(), tracking.short });

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

fn tempReuseOrAlloc(cg: *CodeGen, inst: Air.Inst.Index, op: Temp, op_i: Air.Liveness.OperandInt, ty: Type, opts: MCVAllocOptions) InnerError!Temp {
    if (cg.liveness.operandDies(inst, op_i) and op.isMut(cg)) {
        cg.reused_operands.set(op_i);
        return op;
    } else {
        return cg.tempAlloc(ty, opts);
    }
}

fn tempTryReuseOrAlloc(cg: *CodeGen, inst: Air.Inst.Index, op_temps: []const Temp, opts: MCVAllocOptions) InnerError!Temp {
    for (op_temps, 0..) |op, op_i| {
        if (cg.liveness.operandDies(inst, @truncate(op_i)) and op.isMut(cg)) {
            cg.reused_operands.set(op_i);
            return op;
        }
    }
    return cg.tempAlloc(op_temps[0].typeOf(cg), opts);
}

fn reuseOperand(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    operand: Air.Inst.Index,
    op_index: Air.Liveness.OperandInt,
    mcv: MCValue,
) bool {
    return cg.reuseOperandAdvanced(inst, operand, op_index, mcv, inst);
}

fn reuseOperandAdvanced(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    operand: Air.Inst.Index,
    op_index: Air.Liveness.OperandInt,
    mcv: MCValue,
    maybe_tracked_inst: ?Air.Inst.Index,
) bool {
    if (!cg.liveness.operandDies(inst, op_index))
        return false;

    switch (mcv) {
        .register,
        .register_pair,
        .register_triple,
        .register_quadruple,
        => for (mcv.getRegs()) |reg| {
            // If it's in the registers table, need to associate the register(s) with the
            // new instruction.
            if (maybe_tracked_inst) |tracked_inst| {
                if (!cg.register_manager.isRegFree(reg)) {
                    if (RegisterManager.indexOfRegIntoTracked(reg)) |index| {
                        cg.register_manager.registers[index] = tracked_inst;
                    }
                }
            } else cg.register_manager.freeReg(reg);
        },
        .load_frame => |frame_addr| if (frame_addr.index.isNamed()) return false,
        else => return false,
    }

    // Prevent the operand deaths processing code from deallocating it.
    cg.reused_operands.set(op_index);
    cg.resolveInst(operand).reuse(cg, inst, operand);

    return true;
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

fn feed(cg: *CodeGen, bt: *Air.Liveness.BigTomb, op: Air.Inst.Ref) !void {
    if (bt.feed()) if (op.toIndex()) |inst| try cg.inst_tracking.getPtr(inst).?.die(cg, inst);
}

const CopyOptions = struct {
    safety: bool = false,
};

fn genCopy(cg: *CodeGen, ty: Type, dst_mcv: MCValue, src_mcv: MCValue, opts: CopyOptions) !void {
    if (dst_mcv == .none) return;
    const zcu = cg.pt.zcu;
    if (!ty.hasRuntimeBits(zcu)) return;

    switch (dst_mcv) {
        .register => |reg| try cg.genCopyToReg(ty, reg, src_mcv, opts),
        .load_frame => try cg.genCopyToMem(ty, dst_mcv, src_mcv),
        else => return cg.fail("TODO: genCopy {s} => {s}", .{ @tagName(src_mcv), @tagName(dst_mcv) }),
    }
}

fn genCopyToReg(cg: *CodeGen, ty: Type, dst: Register, src_mcv: MCValue, opts: CopyOptions) !void {
    switch (src_mcv) {
        .none => {},
        .dead, .unreach => unreachable,
        .undef => if (opts.safety) try cg.asmInst(.lu12i_w(dst, 0xaaaa)),
        .register => |src| if (dst != src) try cg.asmInst(.ori(dst, src, 0)),
        .register_bias => |ro| {
            try cg.asmInst(.addi_d(dst, ro.reg, cast(i12, ro.off) orelse return cg.fail("TODO copy reg_bias to reg", .{})));
        },
        .immediate => |imm| try cg.asmPseudo(.imm_to_reg, .{ .imm_reg = .{
            .imm = imm,
            .reg = dst,
        } }),
        .register_offset => |ro| {
            const size = bits.Memory.Size.fromByteSize(ty.abiSize(cg.pt.zcu));
            if (cast(i12, ro.off)) |off| {
                switch (size) {
                    .byte => try cg.asmInst(.ld_bu(dst, ro.reg, off)),
                    .hword => try cg.asmInst(.ld_hu(dst, ro.reg, off)),
                    .word => try cg.asmInst(.ld_w(dst, ro.reg, off)),
                    .dword => try cg.asmInst(.ld_d(dst, ro.reg, off)),
                }
                return;
            }
            if (cast(i16, ro.off)) |off| {
                if (off & 0b11 == 0) {
                    switch (size) {
                        .word => return cg.asmInst(.ldox4_w(dst, ro.reg, @intCast(off >> 2))),
                        .dword => return cg.asmInst(.ldox4_d(dst, ro.reg, @intCast(off >> 2))),
                        else => {},
                    }
                }
            }
            try cg.genCopyToReg(.usize, dst, .{ .register_bias = .{ .reg = ro.reg, .off = ro.off } }, .{});
            return cg.genCopyToReg(ty, dst, .{ .register_offset = .{ .reg = dst } }, .{});
        },
        .lea_frame => |addr| try cg.asmPseudo(.frame_addr_to_reg, .{ .frame_reg = .{
            .frame = addr,
            .reg = dst,
        } }),
        .load_frame => |addr| {
            const size = bits.Memory.Size.fromByteSize(ty.abiSize(cg.pt.zcu));
            const op: encoding.OpCode, const opx: encoding.OpCode = switch (size) {
                .byte => .{ .ld_bu, .ldx_bu },
                .hword => .{ .ld_hu, .ldx_hu },
                .word => .{ .ld_w, .ldx_w },
                .dword => .{ .ld_d, .ldx_d },
            };
            try cg.asmPseudo(.frame_addr_reg_mem, .{ .op_frame_reg = .{
                .op = op,
                .opx = opx,
                .frame = addr,
                .reg = dst,
            } });
        },
        else => return cg.fail("TODO: genCopyToReg from {s}", .{@tagName(src_mcv)}),
    }
}

/// Copies a value from register to memory.
fn genCopyRegToMem(cg: *CodeGen, dst_mcv: MCValue, src: Register, size: bits.Memory.Size) !void {
    switch (dst_mcv) {
        else => unreachable,
        .air_ref => |dst_ref| try cg.genCopyRegToMem(try cg.resolveRef(dst_ref), src, size),
        .memory => |addr| {
            const tmp_reg, const tmp_reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(tmp_reg_lock);
            try cg.genCopyToReg(.usize, tmp_reg, .{ .immediate = addr }, .{});
            try cg.genCopyRegToMem(.{ .register_offset = .{ .reg = tmp_reg } }, src, size);
        },
        .register_offset => |ro| {
            if (cast(i12, ro.off)) |off| {
                switch (size) {
                    .byte => try cg.asmInst(.st_b(src, ro.reg, off)),
                    .hword => try cg.asmInst(.st_h(src, ro.reg, off)),
                    .word => try cg.asmInst(.st_w(src, ro.reg, off)),
                    .dword => try cg.asmInst(.st_d(src, ro.reg, off)),
                }
                return;
            }
            if (cast(i16, ro.off)) |off| {
                if (off & 0b11 == 0) {
                    switch (size) {
                        .word => return cg.asmInst(.stox4_w(src, ro.reg, @intCast(off >> 2))),
                        .dword => return cg.asmInst(.stox4_d(src, ro.reg, @intCast(off >> 2))),
                        else => {},
                    }
                }
            }
            return cg.fail("TODO: genCopyRegToMem to {s}", .{@tagName(dst_mcv)});
        },
        .load_frame => |addr| {
            const op: encoding.OpCode, const opx: encoding.OpCode = switch (size) {
                .byte => .{ .st_b, .stx_b },
                .hword => .{ .st_h, .stx_h },
                .word => .{ .st_w, .stx_w },
                .dword => .{ .st_d, .stx_d },
            };
            try cg.asmPseudo(.frame_addr_reg_mem, .{ .op_frame_reg = .{
                .op = op,
                .opx = opx,
                .frame = addr,
                .reg = src,
            } });
        },
        .undef,
        .load_symbol,
        => return cg.fail("TODO: genCopyRegToMem to {s}", .{@tagName(dst_mcv)}),
    }
}

fn genCopyToMem(cg: *CodeGen, ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;

    const abi_size: u32 = @intCast(ty.abiSize(zcu));
    switch (src_mcv) {
        .none,
        .unreach,
        .dead,
        .reserved_frame,
        => unreachable,
        .air_ref => |src_ref| try cg.genCopyToMem(ty, dst_mcv, try cg.resolveRef(src_ref)),
        .register => |reg| return cg.genCopyRegToMem(dst_mcv, reg, .fromByteSize(ty.abiSize(zcu))),
        .register_offset,
        .memory,
        .load_symbol,
        .load_frame,
        => return cg.fail("TODO: genCopyToMem from {s}", .{@tagName(src_mcv)}),
        inline .register_pair, .register_triple, .register_quadruple => |regs| {
            for (regs, 0..) |reg, reg_i| {
                const size: bits.Memory.Size = if (reg_i == regs.len - 1) .fromByteSize(abi_size % 8) else .dword;
                try cg.genCopyRegToMem(dst_mcv.toLimbValue(reg_i), reg, size);
            }
        },
        .immediate, .register_bias, .lea_symbol, .lea_frame => {
            const tmp_reg, const tmp_reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(tmp_reg_lock);

            try cg.genCopyToReg(.usize, tmp_reg, src_mcv, .{});
            try cg.genCopyRegToMem(dst_mcv, tmp_reg, .dword);
        },
        .register_frame => |reg_frame| {
            // copy reg
            try cg.genCopyRegToMem(dst_mcv, reg_frame.reg, .dword);
            // copy memory
            return cg.fail("TODO: genCopyToMem from {s}", .{@tagName(src_mcv)});
        },
        else => return cg.fail("TODO: genCopyToMem from {s}", .{@tagName(src_mcv)}),
    }
}

/// Truncates the value in the register in place.
/// Clobbers any remaining bits.
/// 32-bit values will not be truncated.
fn truncateRegister(cg: *CodeGen, ty: Type, reg: Register) !void {
    const zcu = cg.pt.zcu;

    assert(reg.class() == .int);
    const bit_size = @as(u6, @intCast(ty.bitSize(zcu) % 64));

    // skip unneeded truncation
    if (bit_size == 0 or bit_size == 32) return;

    if (ty.isAbiInt(zcu)) {
        if (bit_size <= 32) {
            try cg.asmInst(.bstrpick_w(reg, reg, 0, @intCast(bit_size - 1)));
        } else {
            try cg.asmInst(.bstrpick_d(reg, reg, 0, bit_size - 1));
        }
    } else {
        try cg.asmInst(.bstrpick_d(reg, reg, 0, bit_size - 1));
    }
}

/// Pattern matching framework.
const Select = struct {
    cg: *CodeGen,
    inst: ?Air.Inst.Index,

    ops: [Air.Liveness.bpi]Temp = undefined,
    op_types: [Air.Liveness.bpi]Type = undefined,
    ops_count: usize = 0,
    temps: [8]Temp = undefined,
    temps_count: usize = 0,
    case_i: usize = 0,

    const Error = InnerError || error{SelectFailed};

    fn init(cg: *CodeGen, inst: ?Air.Inst.Index, ops: []const Temp) Select {
        var sel = Select{ .cg = cg, .inst = inst };
        sel.ops_count = ops.len;
        for (ops, 0..) |op, op_i| {
            sel.ops[op_i] = op;
            sel.op_types[op_i] = op.typeOf(cg);
        }
        return sel;
    }

    fn finish(sel: *Select, result: Temp) !void {
        if (sel.inst) |inst| {
            try result.finish(inst, sel.ops[0..sel.ops_count], sel.cg);
        }
        for (sel.temps[0..sel.temps_count]) |temp| {
            if (temp.index == result.index) continue;
            try temp.die(sel.cg);
        }
    }

    fn fail(sel: *Select) error{ OutOfMemory, CodegenFail } {
        if (sel.inst) |inst| {
            return sel.cg.fail("failed to select {}", .{sel.cg.fmtAir(inst)});
        } else {
            return sel.cg.fail("failed to select", .{});
        }
    }

    inline fn match(sel: *Select, case: Case) !bool {
        sel.case_i += 1;
        for (case.requires, 0..) |requires, req_i| {
            if (!requires) {
                cg_select_log.debug("case {} miss for req {}", .{ sel.case_i, req_i + 1 });
                return false;
            }
        }

        patterns: for (case.patterns, 0..) |pattern, pat_i| {
            std.mem.swap(Temp, &sel.ops[pattern.commute[0]], &sel.ops[pattern.commute[1]]);

            for (pattern.srcs, 0..) |src, src_i| {
                if (!src.matches(sel.ops[src_i], sel.cg)) {
                    std.mem.swap(Temp, &sel.ops[pattern.commute[0]], &sel.ops[pattern.commute[1]]);
                    cg_select_log.debug("case {} pattern {} miss for src {}", .{ sel.case_i, pat_i + 1, src_i + 1 });
                    continue :patterns;
                }
            }

            cg_select_log.debug("case {} pattern {} matched", .{ sel.case_i, pat_i + 1 });

            for (pattern.srcs, 0..) |src, src_i| {
                while (try src.convert(&sel.ops[src_i], sel.cg)) {}
            }
            break;
        } else return false;

        sel.temps_count = case.temps.len;
        for (case.temps, 0..) |temp, temp_i| sel.temps[temp_i] = try temp.create(sel);

        return true;
    }

    pub const Case = struct {
        requires: []const bool = &[_]bool{},
        patterns: []const SrcPattern,
        temps: []const TempSpec = &[_]TempSpec{},
    };

    pub const SrcPattern = struct {
        srcs: []const Src,
        commute: struct { u8, u8 } = .{ 0, 0 },

        pub const Src = union(enum) {
            none,
            any,
            imm_val: i32,
            imm_fit: u5,
            mem,
            to_mem,
            mut_mem,
            to_mut_mem,
            reg: Register.Class,
            to_reg: Register.Class,
            mut_reg: Register.Class,
            to_mut_reg: Register.Class,

            pub const imm12: Src = .{ .imm_fit = 12 };
            pub const imm20: Src = .{ .imm_fit = 20 };
            pub const int_reg: Src = .{ .reg = .int };
            pub const to_int_reg: Src = .{ .to_reg = .int };
            pub const int_mut_reg: Src = .{ .mut_reg = .int };
            pub const to_int_mut_reg: Src = .{ .to_mut_reg = .int };

            fn matches(pat: Src, temp: Temp, cg: *CodeGen) bool {
                return switch (pat) {
                    .none => temp.tracking(cg).short == .none,
                    .any => true,
                    .imm_val => |val| switch (temp.tracking(cg).short) {
                        .immediate => |imm| @as(i32, @intCast(imm)) == val,
                        else => false,
                    },
                    .imm_fit => |max_size| switch (temp.tracking(cg).short) {
                        .immediate => |imm| (imm >> max_size) == 0,
                        else => false,
                    },
                    .mem => temp.tracking(cg).short.isMemory(),
                    .mut_mem => temp.isMut(cg) and temp.tracking(cg).short.isMemory(),
                    .to_mem, .to_mut_mem => true,
                    .reg => |rc| temp.tracking(cg).short.isRegisterOf(rc),
                    .to_reg => |_| temp.typeOf(cg).abiSize(cg.pt.zcu) <= 8,
                    .mut_reg => |rc| temp.isMut(cg) and temp.tracking(cg).short.isRegisterOf(rc),
                    .to_mut_reg => |_| temp.typeOf(cg).abiSize(cg.pt.zcu) <= 8,
                };
            }

            fn convert(pat: Src, temp: *Temp, cg: *CodeGen) InnerError!bool {
                return switch (pat) {
                    .none, .any, .imm_val, .imm_fit => false,
                    .mem, .to_mem => try temp.moveToMemory(cg, false),
                    .mut_mem, .to_mut_mem => try temp.moveToMemory(cg, true),
                    .reg, .to_reg => |rc| try temp.moveToRegister(cg, rc, false),
                    .mut_reg, .to_mut_reg => |rc| try temp.moveToRegister(cg, rc, true),
                };
            }
        };
    };

    pub const TempSpec = struct {
        type: Type = .noreturn,
        kind: Kind = .any,

        pub const Kind = union(enum) {
            alloc: MCVAllocOptions,
            mcv: MCValue,
            constant: Value,
            lazy_symbol: struct { kind: link.File.LazySymbol.Kind },
            symbol: *const struct { lib: ?[]const u8 = null, name: []const u8 },

            pub const none: Kind = .{ .mcv = .none };
            pub const undef: Kind = .{ .mcv = .undef };
            pub const any: Kind = .{ .alloc = .{} };
            pub const any_reg: Kind = .{ .alloc = .{ .use_frame = false } };
            pub const any_frame: Kind = .{ .alloc = .{ .use_reg = false } };
        };

        pub const any_usize_reg: TempSpec = .{ .type = .usize, .kind = .any_reg };

        fn create(spec: TempSpec, sel: *const Select) InnerError!Temp {
            const cg = sel.cg;
            const pt = cg.pt;
            const zcu = pt.zcu;

            return switch (spec.kind) {
                .alloc => |alloc_opts| try cg.tempAlloc(spec.type, alloc_opts),
                .mcv => |mcv| try cg.tempInit(spec.type, mcv),
                .constant => |constant| try cg.tempInit(constant.typeOf(zcu), try cg.genTypedValue(constant)),
                .lazy_symbol => |lazy_symbol_spec| {
                    const ip = &pt.zcu.intern_pool;
                    const ty = spec.type;
                    const lazy_symbol: link.File.LazySymbol = .{
                        .kind = lazy_symbol_spec.kind,
                        .ty = switch (ip.indexToKey(ty.toIntern())) {
                            .inferred_error_set_type => |func_index| switch (ip.funcIesResolvedUnordered(func_index)) {
                                .none => unreachable, // unresolved inferred error set
                                else => |ty_index| ty_index,
                            },
                            else => ty.toIntern(),
                        },
                    };
                    return try cg.tempInit(.usize, .{ .lea_symbol = .{
                        .index = if (cg.bin_file.cast(.elf)) |elf_file|
                            elf_file.zigObjectPtr().?.getOrCreateMetadataForLazySymbol(elf_file, pt, lazy_symbol) catch |err|
                                return cg.fail("{s} creating lazy symbol", .{@errorName(err)})
                        else
                            return cg.fail("external symbols unimplemented for {s}", .{@tagName(cg.bin_file.tag)}),
                    } });
                },
                .symbol => |symbol_spec| try cg.tempInit(spec.type, .{ .lea_symbol = .{
                    .index = if (cg.bin_file.cast(.elf)) |elf_file|
                        try elf_file.getGlobalSymbol(symbol_spec.name, symbol_spec.lib)
                    else
                        return cg.fail("external symbols unimplemented for {s}", .{@tagName(cg.bin_file.tag)}),
                } }),
            };
        }
    };
};

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

    const un_temp = try cg.tempFromOperand(un_op, false);

    if (!std.meta.eql(un_temp.tracking(cg).short, cg.ret_mcv)) {
        // copy return values into proper location
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
        try un_temp.copy(ret_temp, cg, ret_ty);

        try ret_temp.finish(inst, &.{un_temp}, cg);
        try cg.finishReturn(inst);
    } else {
        try un_temp.finish(inst, &.{un_temp}, cg);
        try cg.finishReturn(inst);
    }
}

fn airRetLoad(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;
    const un_op = cg.getAirData(inst).un_op;

    var un_temp = try cg.tempFromOperand(un_op, false);
    switch (cg.call_info.return_value) {
        // per AIR semantics, when the return value is passed by-ref, operand is always ret_ptr.
        .ref_register, .ref_frame => {},
        // or, load from memory
        else => {
            const ret_ty = cg.fn_type.fnReturnType(zcu);
            const ret_temp = try cg.tempInit(ret_ty, cg.ret_mcv);

            while (try un_temp.toMemory(cg)) {}
            try un_temp.copy(ret_temp, cg, ret_ty);
            try ret_temp.die(cg);
        },
    }

    try (try cg.tempInit(.noreturn, .undef)).finish(inst, &.{un_temp}, cg);
    try cg.finishReturn(inst);
}

/// Finishes a return.
/// The return value is expected to be copied to the proper location.
fn finishReturn(cg: *CodeGen, inst: Air.Inst.Index) !void {
    _ = inst;

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

fn airArithBinOp(cg: *CodeGen, inst: Air.Inst.Index, op: enum { add, sub }) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;

    const bin_op = cg.getAirData(inst).bin_op;
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ bin_op.lhs, bin_op.rhs }));
    const ty = sel.ops[0].typeOf(cg);

    if (ty.isInt(zcu) and
        ty.intInfo(zcu).bits <= 32 and
        try sel.match(.{
            .patterns = &.{.{ .srcs = &.{ .to_int_reg, .to_int_reg } }},
        }))
    {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempReuseOrAlloc(inst, lhs, 0, ty, .{ .use_frame = false });
        switch (op) {
            .add => try cg.asmInst(.add_w(dst.getReg(cg), lhs.getReg(cg), rhs.getReg(cg))),
            .sub => try cg.asmInst(.sub_w(dst.getReg(cg), lhs.getReg(cg), rhs.getReg(cg))),
        }
        try dst.truncateRegister(cg);
        try sel.finish(dst);
    } else return sel.fail();
}

const LogicBinOpKind = enum { @"and", @"or", xor };

fn asmIntLogicBinOpRRR(cg: *CodeGen, op: LogicBinOpKind, dst: Register, src1: Register, src2: Register) !void {
    return switch (op) {
        .@"and" => cg.asmInst(.@"and"(dst, src1, src2)),
        .@"or" => cg.asmInst(.@"or"(dst, src1, src2)),
        .xor => cg.asmInst(.xor(dst, src1, src2)),
    };
}

fn asmIntLogicBinOpRRI(cg: *CodeGen, op: LogicBinOpKind, dst: Register, src1: Register, src2: u12) !void {
    return switch (op) {
        .@"and" => cg.asmInst(.andi(dst, src1, src2)),
        .@"or" => cg.asmInst(.ori(dst, src1, src2)),
        .xor => cg.asmInst(.xori(dst, src1, src2)),
    };
}

fn airLogicBinOp(cg: *CodeGen, inst: Air.Inst.Index, op: LogicBinOpKind) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;

    const bin_op = cg.getAirData(inst).bin_op;
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ bin_op.lhs, bin_op.rhs }));
    const ty = sel.ops[0].typeOf(cg);
    assert(ty.isAbiInt(zcu));

    if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .imm12 } },
            .{ .srcs = &.{ .to_int_reg, .imm12 }, .commute = .{ 0, 1 } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempReuseOrAlloc(inst, lhs, 0, ty, .{ .use_frame = false });
        const lhs_limb = lhs.toLimbValue(0, cg);
        const dst_limb = dst.toLimbValue(0, cg);
        try asmIntLogicBinOpRRI(cg, op, dst_limb.getReg().?, lhs_limb.getReg().?, @intCast(rhs.getImm(cg)));
        try sel.finish(dst);
    } else if (try sel.match(.{
        .patterns = &.{.{ .srcs = &.{ .to_int_reg, .to_int_reg } }},
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempReuseOrAlloc(inst, lhs, 0, ty, .{ .use_frame = false });
        for (0..lhs.getLimbCount(cg)) |limb_i| {
            const lhs_limb = lhs.toLimbValue(limb_i, cg);
            const rhs_limb = rhs.toLimbValue(limb_i, cg);
            const dst_limb = dst.toLimbValue(limb_i, cg);
            try asmIntLogicBinOpRRR(cg, op, dst_limb.getReg().?, lhs_limb.getReg().?, rhs_limb.getReg().?);
        }
        try sel.finish(dst);
    } else if (try sel.match(.{
        .requires = &.{cg.canAllocInReg(ty)},
        .patterns = &.{.{ .srcs = &.{ .any, .any } }},
        .temps = &.{ .any_usize_reg, .any_usize_reg },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const tmp1, const tmp2 = sel.temps[0..2].*;
        const dst = try cg.tempReuseOrAlloc(inst, lhs, 0, ty, .{ .use_frame = false });
        for (0..lhs.getLimbCount(cg)) |limb_i| {
            const lhs_limb = try tmp1.ensureReg(cg, lhs.toLimbValue(limb_i, cg));
            const rhs_limb = try tmp2.ensureReg(cg, rhs.toLimbValue(limb_i, cg));
            const dst_limb = dst.toLimbValue(limb_i, cg);
            try asmIntLogicBinOpRRR(cg, op, dst_limb.getReg().?, lhs_limb.getReg().?, rhs_limb.getReg().?);
        }
        try sel.finish(dst);
    } else return sel.fail();
}

fn airRetAddr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    // do not mark $ra as allocated
    const index = RegisterManager.indexOfKnownRegIntoTracked(.ra).?;
    const ra_allocated = cg.register_manager.allocated_registers.isSet(index);
    const dst = try cg.tempInit(.usize, .{ .register = .ra });
    cg.register_manager.allocated_registers.setValue(index, ra_allocated);

    try cg.asmPseudo(.load_ra, .none);
    try dst.finish(inst, &.{}, cg);
}

fn airAlloc(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty = cg.getAirData(inst).ty;
    const frame = try cg.allocFrameIndex(.initType(ty, zcu));
    const result = try cg.tempInit(.ptr_usize, .{ .lea_frame = .{ .index = frame } });
    try result.finish(inst, &.{}, cg);
}

fn airRetPtr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    switch (cg.call_info.return_value) {
        .ref_register => |reg| {
            const result = try cg.tempInit(.ptr_usize, .{ .register = reg });
            try result.finish(inst, &.{}, cg);
        },
        .ref_frame => |frame_off| {
            const result = try cg.tempInit(.ptr_usize, .{ .load_frame = .{
                .index = .args_frame,
                .off = frame_off,
            } });
            try result.finish(inst, &.{}, cg);
        },
        else => try cg.airAlloc(inst),
    }
}

fn airLoad(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_op = cg.getAirData(inst).ty_op;
    const ty = ty_op.ty.toType();
    const val_mcv = try cg.resolveRef(ty_op.operand);
    var val = (try cg.tempsFromOperands(inst, .{ty_op.operand}))[0];
    return switch (val_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .register_pair,
        .register_triple,
        .register_quadruple,
        .register_frame,
        .reserved_frame,
        .air_ref,
        => unreachable,
        .memory, .register_offset, .load_symbol, .load_frame => {
            const tmp = try cg.tempAlloc(.usize, .{ .use_frame = false });
            try val.copy(tmp, cg, .usize);
            while (try val.toMemory(cg)) {}
            try tmp.finish(inst, &.{val}, cg);
        },
        .immediate, .register, .register_bias, .lea_symbol, .lea_frame => {
            while (try val.toMemory(cg)) {}
            cg.temp_type[@intFromEnum(val.index)] = ty;
            try val.finish(inst, &.{val}, cg);
        },
    };
}

fn airStore(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const bin_op = cg.getAirData(inst).bin_op;
    var ptr, const val = try cg.tempsFromOperands(inst, .{ bin_op.lhs, bin_op.rhs });
    const val_ty = val.typeOf(cg);

    while (try ptr.toMemory(cg)) {}
    try val.copy(ptr, cg, val_ty);
    try (try cg.tempInit(.void, .none)).finish(inst, &.{ ptr, val }, cg);
}

fn airCall(cg: *CodeGen, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !void {
    // TODO: tail call
    const pt = cg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = cg.gpa;
    const pl_op = cg.getAirData(inst).pl_op;
    const callee = pl_op.operand;
    const callee_ty = cg.typeOf(callee);

    const fn_ty = zcu.typeToFunc(switch (callee_ty.zigTypeTag(zcu)) {
        .@"fn" => callee_ty,
        .pointer => callee_ty.childType(zcu),
        else => unreachable,
    }).?;
    var call_info = try cg.resolveCallInfo(&fn_ty);
    defer call_info.deinit(gpa);
    const ret_ty: Type = .fromInterned(fn_ty.return_type);

    if (modifier == .always_tail) return cg.fail("TODO implement tail calls for loongarch64", .{});

    const extra = cg.air.extraData(Air.Call, pl_op.payload);
    const arg_refs: []const Air.Inst.Ref = @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.args_len]);

    if (arg_refs.len != fn_ty.param_types.len)
        return cg.fail("var-arg calls are not supported in LA yet", .{});

    // adjust call frame size & alignment for the call
    cg.adjustFrame(.call_frame, call_info.frame_size, call_info.frame_align);

    var reg_locks = std.ArrayList(RegisterManager.RegisterLock).init(gpa);
    defer reg_locks.deinit();
    try reg_locks.ensureTotalCapacity(abi.zigcc.Integer.function_arg_regs.len);
    defer for (reg_locks.items) |reg_lock| cg.register_manager.unlockReg(reg_lock);

    // frame indices for by-ref CCVs
    const frame_indices = try gpa.alloc(FrameIndex, arg_refs.len);
    defer gpa.free(frame_indices);

    // lock regs & alloc frames
    for (call_info.params, arg_refs, frame_indices) |ccv, arg_ref, *frame_index| {
        // lock regs
        for (ccv.getRegs()) |reg| {
            try cg.register_manager.getReg(reg, null);
            try reg_locks.append(cg.register_manager.lockReg(reg) orelse unreachable);
        }

        // alloc frames
        switch (ccv) {
            .ref_register, .ref_frame => frame_index.* = try cg.allocFrameIndex(.initType(cg.typeOf(arg_ref), zcu)),
            else => {},
        }
    }

    // lock ret regs
    for (call_info.return_value.getRegs()) |reg| {
        try cg.register_manager.getReg(reg, null);
        if (cg.register_manager.lockReg(reg)) |lock| try reg_locks.append(lock);
    }

    // lock temporary regs
    for (abi.zigcc.all_temporary) |reg| {
        try cg.register_manager.getReg(reg, null);
        if (cg.register_manager.lockReg(reg)) |lock| try reg_locks.append(lock);
    }

    // resolve ret MCV
    const ret_mcv: MCValue = if (cg.liveness.isUnused(inst)) .unreach else ret_mcv: switch (call_info.return_value) {
        .ref_register, .ref_frame => {
            const frame = try cg.allocFrameIndex(.initType(ret_ty, zcu));
            break :ret_mcv .{ .load_frame = .{ .index = frame } };
        },
        .split => unreachable,
        else => |ccv| .fromCCValue(ccv, .call_frame),
    };

    // set arguments in place
    for (call_info.params, arg_refs, frame_indices) |ccv, arg_ref, frame_index| {
        switch (ccv) {
            .ref_register, .ref_frame => {
                const dst: MCValue = .{ .load_frame = .{ .index = frame_index } };
                try cg.genCopy(cg.typeOf(arg_ref), dst, try cg.resolveRef(arg_ref), .{});
            },
            else => {
                try cg.genCopy(cg.typeOf(arg_ref), .fromCCValue(ccv, .call_frame), try cg.resolveRef(arg_ref), .{});
            },
        }
    }

    // lock ra
    try cg.register_manager.getReg(.ra, null);
    try reg_locks.append(cg.register_manager.lockReg(.ra) orelse unreachable);

    // do the transfer
    if (try cg.air.value(pl_op.operand, pt)) |func_value| {
        const func_key = ip.indexToKey(func_value.ip_index);
        switch (switch (func_key) {
            else => func_key,
            .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                .nav => |nav| ip.indexToKey(zcu.navValue(nav).toIntern()),
                else => func_key,
            } else func_key,
        }) {
            .func => |func| {
                if (cg.bin_file.cast(.elf)) |elf_file| {
                    const zo = elf_file.zigObjectPtr().?;
                    const sym_index = try zo.getOrCreateMetadataForNav(zcu, func.owner_nav);
                    try cg.asmPseudo(.call, .{ .sym = sym_index });
                } else unreachable;
            },
            .@"extern" => |ext| if (cg.bin_file.cast(.elf)) |elf_file| {
                const sym_index = try elf_file.getGlobalSymbol(ext.name.toSlice(ip), ext.lib_name.toSlice(ip));
                try cg.asmPseudo(.call, .{ .sym = sym_index });
            } else unreachable,
            // TODO what's this
            else => return cg.fail("TODO implement calling bitcasted functions", .{}),
        }
    } else {
        assert(callee.toType().zigTypeTag(zcu) == .pointer);
        const addr_mcv = try cg.resolveRef(pl_op.operand);
        call: {
            switch (addr_mcv) {
                .register => |reg| break :call try cg.asmInst(.jirl(.ra, reg, 0)),
                .register_bias => |ro| if (cast(i18, ro.off)) |off18|
                    if (off18 & 0b11 == 0)
                        break :call try cg.asmInst(.jirl(.ra, ro.reg, @truncate(off18 >> 2))),
                else => {},
            }
            try cg.genCopyToReg(.usize, .t0, addr_mcv, .{});
            try cg.asmInst(.jirl(.ra, .t0, 0));
        }
    }

    // finish
    var bt = cg.liveness.iterateBigTomb(inst);
    try cg.feed(&bt, pl_op.operand);
    for (arg_refs) |arg_ref| try cg.feed(&bt, arg_ref);

    try (try cg.tempInit(ret_ty, ret_mcv)).finish(inst, &.{}, cg);
}

fn airAsm(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_pl = cg.getAirData(inst).ty_pl;
    const extra = cg.air.extraData(Air.Asm, ty_pl.payload);
    var extra_i: usize = extra.end;
    const outputs: []const Air.Inst.Ref =
        @ptrCast(cg.air.extra.items[extra_i..][0..extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs: []const Air.Inst.Ref = @ptrCast(cg.air.extra.items[extra_i..][0..extra.data.inputs_len]);
    extra_i += inputs.len;
    const clobbers_len = @as(u31, @truncate(extra.data.flags));

    var parser: AsmParser = .{
        .pt = cg.pt,
        .target = cg.target,
        .gpa = cg.gpa,
        .register_manager = &cg.register_manager,
        .src_loc = cg.src_loc,
        .output_len = outputs.len,
        .input_len = inputs.len,
        .clobber_len = clobbers_len,
        .mir_offset = cg.label(),
    };
    try parser.init();
    defer parser.deinit();
    errdefer if (parser.err_msg) |msg| {
        cg.failMsg(msg) catch {};
    };

    // parse constraints
    for (outputs) |_| {
        const extra_bytes = std.mem.sliceAsBytes(cg.air.extra.items[extra_i..]);
        const constraint = std.mem.sliceTo(extra_bytes, 0);
        const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
        // This equation accounts for the fact that even if we have exactly 4 bytes
        // for the string, we still use the next u32 for the null terminator.
        extra_i += (constraint.len + name.len + (2 + 3)) / 4;

        try parser.parseOutputConstraint(name, constraint);
    }

    for (inputs) |_| {
        const input_bytes = std.mem.sliceAsBytes(cg.air.extra.items[extra_i..]);
        const constraint = std.mem.sliceTo(input_bytes, 0);
        const name = std.mem.sliceTo(input_bytes[constraint.len + 1 ..], 0);
        // This equation accounts for the fact that even if we have exactly 4 bytes
        // for the string, we still use the next u32 for the null terminator.
        extra_i += (constraint.len + name.len + (2 + 3)) / 4;

        try parser.parseOutputConstraint(name, constraint);
    }

    for (0..clobbers_len) |_| {
        const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(cg.air.extra.items[extra_i..]), 0);
        // This equation accounts for the fact that even if we have exactly 4 bytes
        // for the string, we still use the next u32 for the null terminator.
        extra_i += clobber.len / 4 + 1;

        try parser.parseClobberConstraint(clobber);
    }

    // prepare to input load
    try parser.finalizeConstraints();

    // load inputs
    for (inputs, 0..) |input, input_i| {
        const input_mcv = &parser.args.items[outputs.len + input_i].value;
        const input_cgv = try cg.resolveRef(input);

        switch (input_mcv.*) {
            .none => unreachable,
            .imm => |*imm| {
                switch (input_cgv) {
                    .immediate => |input_imm| {
                        if (cast(i32, @as(i64, @bitCast(input_imm)))) |imm32|
                            imm.* = imm32
                        else
                            return cg.fail("input immediate {} cannot fit into operand", .{imm});
                    },
                    else => return cg.fail("input {} is not an immediate", .{input_i + 1}),
                }
            },
            .reg => |reg| {
                try cg.genCopyToReg(cg.typeOf(input), reg, input_cgv, .{});
            },
        }
    }

    // parse source
    const asm_source = std.mem.sliceAsBytes(cg.air.extra.items[extra_i..])[0..extra.data.source_len];
    try parser.parseSource(asm_source);

    // finish MC generation
    try parser.finalizeCodeGen();

    // copy instructions
    try cg.mir_instructions.ensureUnusedCapacity(cg.gpa, parser.mir_insts.items.len);
    for (parser.mir_insts.items) |mc_inst|
        cg.mir_instructions.appendAssumeCapacity(mc_inst);

    // kill operands
    var bt = cg.liveness.iterateBigTomb(inst);
    for (outputs) |output| if (output != .none) try cg.feed(&bt, output);
    for (inputs) |input| try cg.feed(&bt, input);

    // finish assembly block
    if (outputs.len != 0) {
        assert(outputs.len == 1);
        const result_mcv = parser.args.items[0].value;
        switch (result_mcv) {
            .none, .imm => unreachable,
            .reg => |reg| {
                const result_ty = cg.typeOfIndex(inst);
                const result_tmp = try cg.tempInit(result_ty, .{ .register = reg });
                try result_tmp.finish(inst, &.{}, cg);
            },
        }
    } else {
        try (try cg.tempInit(.void, .none)).finish(inst, &.{}, cg);
    }
}

const CmpToBoolOptions = struct {
    cond: Mir.BranchCondition.Tag,
    swap: bool,
    opti: bool,
};

// TODO: instruction combination
fn airCompareToBool(cg: *CodeGen, inst: Air.Inst.Index, comptime opts: CmpToBoolOptions) !void {
    var bin_op = cg.getAirData(inst).bin_op;
    if (opts.swap) std.mem.swap(Air.Inst.Ref, &bin_op.lhs, &bin_op.rhs);
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ bin_op.lhs, bin_op.rhs }));

    if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .to_int_reg } },
            .{ .srcs = &.{ .to_int_reg, .to_int_reg }, .commute = .{ 0, 1 } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{ lhs, rhs }, .{ .use_frame = false });

        const label_if = try cg.asmBr(null, .compare(opts.cond, lhs.getReg(cg), rhs.getReg(cg)));
        try cg.asmInst(.ori(dst.getReg(cg), .zero, 0));
        const label_fall = try cg.asmBr(null, .none);
        cg.performReloc(label_if);
        try cg.asmInst(.ori(dst.getReg(cg), .zero, 1));
        cg.performReloc(label_fall);

        try sel.finish(dst);
    } else return sel.fail();
}

fn airBlock(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_pl = cg.getAirData(inst).ty_pl;
    const extra = cg.air.extraData(Air.Block, ty_pl.payload);

    if (cg.debug_output != .none) try cg.asmPseudo(.dbg_enter_block, .none);
    try cg.lowerBlock(inst, ty_pl.ty, @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]));
    if (cg.debug_output != .none) try cg.asmPseudo(.dbg_exit_block, .none);
}

fn airDbgInlineBlock(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_pl = cg.getAirData(inst).ty_pl;
    const extra = cg.air.extraData(Air.DbgInlineBlock, ty_pl.payload);

    const old_inline_func = cg.inline_func;
    defer cg.inline_func = old_inline_func;
    cg.inline_func = extra.data.func;

    if (cg.debug_output != .none) try cg.asmPseudo(.dbg_enter_inline_func, .{ .func = extra.data.func });
    try cg.lowerBlock(inst, ty_pl.ty, @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]));
    if (cg.debug_output != .none) try cg.asmPseudo(.dbg_enter_inline_func, .{ .func = old_inline_func });
}

fn lowerBlock(cg: *CodeGen, inst: Air.Inst.Index, ty_ref: Air.Inst.Ref, body: []const Air.Inst.Index) !void {
    const ty = ty_ref.toType();
    const inst_tracking_i = cg.inst_tracking.count();
    cg.inst_tracking.putAssumeCapacityNoClobber(inst, .init(.unreach));

    // init block data
    try cg.blocks.putNoClobber(cg.gpa, inst, .{ .state = cg.initRetroactiveState() });
    const liveness = cg.liveness.getBlock(inst);

    // generate the body
    try cg.genBody(body);

    // remove block data
    var block_data = cg.blocks.fetchRemove(inst).?.value;
    defer block_data.deinit(cg.gpa);

    // if there are any br-s targeting this block
    if (block_data.relocs.items.len > 0) {
        assert(!ty.eql(.noreturn, cg.pt.zcu));
        try cg.restoreState(block_data.state, liveness.deaths, .{
            .emit_instructions = false,
            .update_tracking = true,
            .resurrect = true,
            .close_scope = true,
        });
        for (block_data.relocs.items) |reloc| cg.performReloc(reloc);
    } else assert(ty.eql(.noreturn, cg.pt.zcu));

    // process return value
    if (std.debug.runtime_safety) assert(cg.inst_tracking.getIndex(inst).? == inst_tracking_i);
    const tracking = &cg.inst_tracking.values()[inst_tracking_i];
    if (cg.liveness.isUnused(inst)) {
        try tracking.die(cg, inst);
    } else {
        try cg.getValue(tracking.short, inst);
    }
}

fn airBr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const br = cg.getAirData(inst).br;

    const block_ty = cg.typeOfIndex(br.block_inst);
    const block_unused =
        !block_ty.hasRuntimeBitsIgnoreComptime(zcu) or cg.liveness.isUnused(br.block_inst);

    const block_tracking = cg.inst_tracking.getPtr(br.block_inst).?;
    const block_data = cg.blocks.getPtr(br.block_inst).?;
    const first_br = block_data.relocs.items.len == 0;

    // prepare/copy the result
    const block_result = result: {
        if (block_unused) break :result .none;

        if (!first_br) try cg.getValue(block_tracking.short, null);
        const op_mcv = try cg.resolveRef(br.operand);

        // try to reuse operand
        if (br.operand.toIndex()) |op_index| {
            if (cg.reuseOperandAdvanced(inst, op_index, 0, op_mcv, br.block_inst)) {
                if (first_br) break :result op_mcv;

                // load value to destination
                try cg.getValue(block_tracking.short, br.block_inst);
                // .long = .none to avoid merging operand and block result stack frames.
                const current_tracking: InstTracking = .{ .long = .none, .short = op_mcv };
                try current_tracking.materializeUnsafe(cg, br.block_inst, block_tracking.*);
                try cg.freeValue(op_mcv);

                break :result block_tracking.short;
            }
        }

        // allocate and copy
        const dst_mcv = dst: {
            if (first_br) {
                break :dst try cg.allocRegOrMem(cg.typeOfIndex(br.block_inst), br.block_inst, .{});
            } else {
                try cg.getValue(block_tracking.short, br.block_inst);
                break :dst block_tracking.short;
            }
        };
        try cg.genCopy(block_ty, dst_mcv, op_mcv, .{});
        break :result dst_mcv;
    };

    // process operand death
    if (cg.liveness.operandDies(inst, 0)) {
        if (br.operand.toIndex()) |op_inst| try cg.resolveInst(op_inst).die(cg, op_inst);
    }

    if (first_br) {
        block_tracking.* = .init(block_result);
        try cg.saveRetroactiveState(&block_data.state);
    } else {
        try cg.restoreState(block_data.state, &.{}, .{
            .emit_instructions = true,
            .update_tracking = false,
            .resurrect = false,
            .close_scope = false,
        });
    }

    // jump to block ends
    const jmp_reloc = try cg.asmBr(null, .none);
    try block_data.relocs.append(cg.gpa, jmp_reloc);

    // stop tracking block result without forgetting tracking info
    try cg.freeValue(block_tracking.short);
}

fn airCondBr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const pt = cg.pt;

    const pl_op = cg.getAirData(inst).pl_op;
    const extra = cg.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_cond_br = cg.liveness.getCondBr(inst);

    const cond_mcv = try cg.resolveRef(pl_op.operand);
    const cond_ty = cg.typeOf(pl_op.operand);

    // try to kill the operand earlier so it does not need to be spilled
    if (cg.liveness.operandDies(inst, 0))
        if (pl_op.operand.toIndex()) |index| try cg.resolveInst(index).die(cg, index);

    const state = try cg.saveState();

    // do the branch
    const reloc = gen_br: switch (cond_mcv) {
        .register => |reg| try cg.asmBr(null, .{ .eq = .{ reg, .zero } }),
        .immediate,
        .load_frame,
        => {
            assert(cond_ty.abiSize(pt.zcu) <= 8);
            const tmp_reg = try cg.allocReg(cond_ty, null);
            try cg.genCopyToReg(cond_ty, tmp_reg, cond_mcv, .{});
            break :gen_br try cg.asmBr(null, .{ .eq = .{ tmp_reg, .zero } });
        },
        else => unreachable,
    };

    for (liveness_cond_br.then_deaths) |death| try cg.resolveInst(death).die(cg, death);
    try cg.genBodyBlock(then_body);
    try cg.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    cg.performReloc(reloc);
    for (liveness_cond_br.else_deaths) |death| try cg.resolveInst(death).die(cg, death);
    try cg.genBodyBlock(else_body);
    try cg.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });
}

fn airBitCast(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const dst_ty = ty_op.ty.toType();
    const src_ty = cg.typeOf(ty_op.operand);
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ty_op.operand}));

    if (dst_ty.isAbiInt(zcu) and
        src_ty.isAbiInt(zcu) and
        src_ty.abiSize(zcu) == dst_ty.abiSize(zcu) and
        try sel.match(.{
            .patterns = &.{.{ .srcs = &.{.any} }},
        }))
    {
        const src = sel.ops[0];
        if (cg.liveness.operandDies(inst, 0)) {
            cg.reused_operands.set(0);
            try src.finish(inst, &.{src}, cg);
        } else {
            try (try cg.tempInit(dst_ty, .{ .air_ref = ty_op.operand })).finish(inst, &.{src}, cg);
        }
    } else return sel.fail();
}
