const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const codegen = @import("../../codegen.zig");
const leb128 = std.leb;
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const tracking_log = std.log.scoped(.tracking);
const verbose_tracking_log = std.log.scoped(.verbose_tracking);
const wip_mir_log = std.log.scoped(.wip_mir);
const math = std.math;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;

const Air = @import("../../Air.zig");
const Allocator = mem.Allocator;
const CodeGenError = codegen.CodeGenError;
const Compilation = @import("../../Compilation.zig");
const ErrorMsg = Zcu.ErrorMsg;
const Result = codegen.Result;
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
const Package = @import("../../Package.zig");
const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const Alignment = InternPool.Alignment;
const Target = std.Target;
const Type = @import("../../Type.zig");
const Value = @import("../../Value.zig");
const Instruction = @import("encoder.zig").Instruction;

const abi = @import("abi.zig");
const bits = @import("bits.zig");
const errUnionErrorOffset = codegen.errUnionErrorOffset;
const errUnionPayloadOffset = codegen.errUnionPayloadOffset;

const Condition = bits.Condition;
const Immediate = bits.Immediate;
const Memory = bits.Memory;
const Register = bits.Register;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const FrameIndex = bits.FrameIndex;

const InnerError = CodeGenError || error{OutOfRegisters};

gpa: Allocator,
pt: Zcu.PerThread,
air: Air,
liveness: Liveness,
bin_file: *link.File,
debug_output: link.File.DebugInfoOutput,
target: *const std.Target,
owner: Owner,
inline_func: InternPool.Index,
mod: *Package.Module,
err_msg: ?*ErrorMsg,
arg_index: u32,
args: []MCValue,
va_info: union {
    sysv: struct {
        gp_count: u32,
        fp_count: u32,
        overflow_arg_area: bits.FrameAddr,
        reg_save_area: bits.FrameAddr,
    },
    win64: struct {},
},
ret_mcv: InstTracking,
fn_type: Type,
src_loc: Zcu.LazySrcLoc,

eflags_inst: ?Air.Inst.Index = null,

/// MIR Instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// MIR extra data
mir_extra: std.ArrayListUnmanaged(u32) = .empty,

/// Byte offset within the source file of the ending curly.
end_di_line: u32,
end_di_column: u32,

/// The value is an offset into the `Function` `code` from the beginning.
/// To perform the reloc, write 32-bit signed little-endian integer
/// which is a relative jump, based on the address following the reloc.
exitlude_jump_relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .empty,

const_tracking: ConstTrackingMap = .{},
inst_tracking: InstTrackingMap = .{},

// Key is the block instruction
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .empty,

register_manager: RegisterManager = .{},

/// Generation of the current scope, increments by 1 for every entered scope.
scope_generation: u32 = 0,

frame_allocs: std.MultiArrayList(FrameAlloc) = .{},
free_frame_indices: std.AutoArrayHashMapUnmanaged(FrameIndex, void) = .empty,
frame_locs: std.MultiArrayList(Mir.FrameLoc) = .{},

loops: std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
    /// The state to restore before branching.
    state: State,
    /// The branch target.
    jmp_target: Mir.Inst.Index,
}) = .{},

/// Debug field, used to find bugs in the compiler.
air_bookkeeping: @TypeOf(air_bookkeeping_init) = air_bookkeeping_init,

const air_bookkeeping_init = if (std.debug.runtime_safety) @as(usize, 0) else {};

const Owner = union(enum) {
    nav_index: InternPool.Nav.Index,
    lazy_sym: link.File.LazySymbol,

    fn getSymbolIndex(owner: Owner, ctx: *Self) !u32 {
        const pt = ctx.pt;
        switch (owner) {
            .nav_index => |nav_index| if (ctx.bin_file.cast(.elf)) |elf_file| {
                return elf_file.zigObjectPtr().?.getOrCreateMetadataForNav(elf_file, nav_index);
            } else if (ctx.bin_file.cast(.macho)) |macho_file| {
                return macho_file.getZigObject().?.getOrCreateMetadataForNav(macho_file, nav_index);
            } else if (ctx.bin_file.cast(.coff)) |coff_file| {
                const atom = try coff_file.getOrCreateAtomForNav(nav_index);
                return coff_file.getAtom(atom).getSymbolIndex().?;
            } else if (ctx.bin_file.cast(.plan9)) |p9_file| {
                return p9_file.seeNav(pt, nav_index);
            } else unreachable,
            .lazy_sym => |lazy_sym| if (ctx.bin_file.cast(.elf)) |elf_file| {
                return elf_file.zigObjectPtr().?.getOrCreateMetadataForLazySymbol(elf_file, pt, lazy_sym) catch |err|
                    ctx.fail("{s} creating lazy symbol", .{@errorName(err)});
            } else if (ctx.bin_file.cast(.macho)) |macho_file| {
                return macho_file.getZigObject().?.getOrCreateMetadataForLazySymbol(macho_file, pt, lazy_sym) catch |err|
                    ctx.fail("{s} creating lazy symbol", .{@errorName(err)});
            } else if (ctx.bin_file.cast(.coff)) |coff_file| {
                const atom = coff_file.getOrCreateAtomForLazySymbol(pt, lazy_sym) catch |err|
                    return ctx.fail("{s} creating lazy symbol", .{@errorName(err)});
                return coff_file.getAtom(atom).getSymbolIndex().?;
            } else if (ctx.bin_file.cast(.plan9)) |p9_file| {
                return p9_file.getOrCreateAtomForLazySymbol(pt, lazy_sym) catch |err|
                    return ctx.fail("{s} creating lazy symbol", .{@errorName(err)});
            } else unreachable,
        }
    }
};

pub const MCValue = union(enum) {
    /// No runtime bits. `void` types, empty structs, u0, enums with 1 tag, etc.
    /// TODO Look into deleting this tag and using `dead` instead, since every use
    /// of MCValue.none should be instead looking at the type and noticing it is 0 bits.
    none,
    /// Control flow will not allow this value to be observed.
    unreach,
    /// No more references to this value remain.
    /// The payload is the value of scope_generation at the point where the death occurred
    dead: u32,
    /// The value is undefined.
    undef,
    /// A pointer-sized integer that fits in a register.
    /// If the type is a pointer, this is the pointer address in virtual address space.
    immediate: u64,
    /// The value resides in the EFLAGS register.
    eflags: Condition,
    /// The value is in a register.
    register: Register,
    /// The value is split across two registers.
    register_pair: [2]Register,
    /// The value is a constant offset from the value in a register.
    register_offset: bits.RegisterOffset,
    /// The value is a tuple { wrapped, overflow } where wrapped value is stored in the GP register.
    register_overflow: struct { reg: Register, eflags: Condition },
    /// The value is in memory at a hard-coded address.
    /// If the type is a pointer, it means the pointer address is stored at this memory location.
    memory: u64,
    /// The value is in memory at an address not-yet-allocated by the linker.
    /// This traditionally corresponds to a relocation emitted in a relocatable object file.
    load_symbol: bits.SymbolOffset,
    /// The address of the memory location not-yet-allocated by the linker.
    lea_symbol: bits.SymbolOffset,
    /// The value is in memory at a constant offset from the address in a register.
    indirect: bits.RegisterOffset,
    /// The value is in memory.
    /// Payload is a symbol index.
    load_direct: u32,
    /// The value is a pointer to a value in memory.
    /// Payload is a symbol index.
    lea_direct: u32,
    /// The value is in memory referenced indirectly via GOT.
    /// Payload is a symbol index.
    load_got: u32,
    /// The value is a pointer to a value referenced indirectly via GOT.
    /// Payload is a symbol index.
    lea_got: u32,
    /// The value is a threadlocal variable.
    /// Payload is a symbol index.
    load_tlv: u32,
    /// The value is a pointer to a threadlocal variable.
    /// Payload is a symbol index.
    lea_tlv: u32,
    /// The value stored at an offset from a frame index
    /// Payload is a frame address.
    load_frame: bits.FrameAddr,
    /// The address of an offset from a frame index
    /// Payload is a frame address.
    lea_frame: bits.FrameAddr,
    /// Supports integer_per_element abi
    elementwise_regs_then_frame: packed struct { regs: u3 = 0, frame_off: i29 = 0, frame_index: FrameIndex },
    /// This indicates that we have already allocated a frame index for this instruction,
    /// but it has not been spilled there yet in the current control flow.
    /// Payload is a frame index.
    reserved_frame: FrameIndex,
    air_ref: Air.Inst.Ref,

    fn isModifiable(mcv: MCValue) bool {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .immediate,
            .register_offset,
            .eflags,
            .register_overflow,
            .lea_symbol,
            .lea_direct,
            .lea_got,
            .lea_tlv,
            .lea_frame,
            .elementwise_regs_then_frame,
            .reserved_frame,
            .air_ref,
            => false,
            .register,
            .register_pair,
            .memory,
            .load_symbol,
            .load_got,
            .load_direct,
            .load_tlv,
            .indirect,
            => true,
            .load_frame => |frame_addr| !frame_addr.index.isNamed(),
        };
    }

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory, .indirect, .load_frame => true,
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
            .register_offset => |reg_off| return reg_off.off == 0,
            else => false,
        };
    }

    fn isRegisterOffset(mcv: MCValue) bool {
        return switch (mcv) {
            .register, .register_offset => true,
            else => false,
        };
    }

    fn getReg(mcv: MCValue) ?Register {
        return switch (mcv) {
            .register => |reg| reg,
            .register_offset, .indirect => |ro| ro.reg,
            .register_overflow => |ro| ro.reg,
            else => null,
        };
    }

    fn getRegs(mcv: *const MCValue) []const Register {
        return switch (mcv.*) {
            .register => |*reg| @as(*const [1]Register, reg),
            .register_pair => |*regs| regs,
            .register_offset, .indirect => |*ro| @as(*const [1]Register, &ro.reg),
            .register_overflow => |*ro| @as(*const [1]Register, &ro.reg),
            else => &.{},
        };
    }

    fn getCondition(mcv: MCValue) ?Condition {
        return switch (mcv) {
            .eflags => |cc| cc,
            .register_overflow => |reg_ov| reg_ov.eflags,
            else => null,
        };
    }

    fn address(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .immediate,
            .eflags,
            .register,
            .register_pair,
            .register_offset,
            .register_overflow,
            .lea_symbol,
            .lea_direct,
            .lea_got,
            .lea_tlv,
            .lea_frame,
            .elementwise_regs_then_frame,
            .reserved_frame,
            .air_ref,
            => unreachable, // not in memory
            .memory => |addr| .{ .immediate = addr },
            .indirect => |reg_off| switch (reg_off.off) {
                0 => .{ .register = reg_off.reg },
                else => .{ .register_offset = reg_off },
            },
            .load_direct => |sym_index| .{ .lea_direct = sym_index },
            .load_got => |sym_index| .{ .lea_got = sym_index },
            .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
            .load_frame => |frame_addr| .{ .lea_frame = frame_addr },
            .load_symbol => |sym_off| .{ .lea_symbol = sym_off },
        };
    }

    fn deref(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .eflags,
            .register_pair,
            .register_overflow,
            .memory,
            .indirect,
            .load_direct,
            .load_got,
            .load_tlv,
            .load_frame,
            .load_symbol,
            .elementwise_regs_then_frame,
            .reserved_frame,
            .air_ref,
            => unreachable, // not dereferenceable
            .immediate => |addr| .{ .memory = addr },
            .register => |reg| .{ .indirect = .{ .reg = reg } },
            .register_offset => |reg_off| .{ .indirect = reg_off },
            .lea_direct => |sym_index| .{ .load_direct = sym_index },
            .lea_got => |sym_index| .{ .load_got = sym_index },
            .lea_tlv => |sym_index| .{ .load_tlv = sym_index },
            .lea_frame => |frame_addr| .{ .load_frame = frame_addr },
            .lea_symbol => |sym_index| .{ .load_symbol = sym_index },
        };
    }

    fn offset(mcv: MCValue, off: i32) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .elementwise_regs_then_frame,
            .reserved_frame,
            .air_ref,
            => unreachable, // not valid
            .eflags,
            .register_pair,
            .register_overflow,
            .memory,
            .indirect,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .load_frame,
            .load_symbol,
            .lea_symbol,
            => switch (off) {
                0 => mcv,
                else => unreachable, // not offsettable
            },
            .immediate => |imm| .{ .immediate = @bitCast(@as(i64, @bitCast(imm)) +% off) },
            .register => |reg| .{ .register_offset = .{ .reg = reg, .off = off } },
            .register_offset => |reg_off| .{
                .register_offset = .{ .reg = reg_off.reg, .off = reg_off.off + off },
            },
            .lea_frame => |frame_addr| .{
                .lea_frame = .{ .index = frame_addr.index, .off = frame_addr.off + off },
            },
        };
    }

    fn mem(mcv: MCValue, function: *Self, size: Memory.Size) !Memory {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .immediate,
            .eflags,
            .register,
            .register_pair,
            .register_offset,
            .register_overflow,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .lea_frame,
            .elementwise_regs_then_frame,
            .reserved_frame,
            .lea_symbol,
            => unreachable,
            .memory => |addr| if (math.cast(i32, @as(i64, @bitCast(addr)))) |small_addr| .{
                .base = .{ .reg = .ds },
                .mod = .{ .rm = .{
                    .size = size,
                    .disp = small_addr,
                } },
            } else .{ .base = .{ .reg = .ds }, .mod = .{ .off = addr } },
            .indirect => |reg_off| .{
                .base = .{ .reg = reg_off.reg },
                .mod = .{ .rm = .{
                    .size = size,
                    .disp = reg_off.off,
                } },
            },
            .load_frame => |frame_addr| .{
                .base = .{ .frame = frame_addr.index },
                .mod = .{ .rm = .{
                    .size = size,
                    .disp = frame_addr.off,
                } },
            },
            .load_symbol => |sym_off| {
                assert(sym_off.off == 0);
                return .{
                    .base = .{ .reloc = sym_off.sym_index },
                    .mod = .{ .rm = .{
                        .size = size,
                        .disp = sym_off.off,
                    } },
                };
            },
            .air_ref => |ref| (try function.resolveInst(ref)).mem(function, size),
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
            .memory => |pl| try writer.print("[ds:0x{x}]", .{pl}),
            inline .eflags, .register => |pl| try writer.print("{s}", .{@tagName(pl)}),
            .register_pair => |pl| try writer.print("{s}:{s}", .{ @tagName(pl[1]), @tagName(pl[0]) }),
            .register_offset => |pl| try writer.print("{s} + 0x{x}", .{ @tagName(pl.reg), pl.off }),
            .register_overflow => |pl| try writer.print("{s}:{s}", .{
                @tagName(pl.eflags), @tagName(pl.reg),
            }),
            .load_symbol => |pl| try writer.print("[{} + 0x{x}]", .{ pl.sym_index, pl.off }),
            .lea_symbol => |pl| try writer.print("{} + 0x{x}", .{ pl.sym_index, pl.off }),
            .indirect => |pl| try writer.print("[{s} + 0x{x}]", .{ @tagName(pl.reg), pl.off }),
            .load_direct => |pl| try writer.print("[direct:{d}]", .{pl}),
            .lea_direct => |pl| try writer.print("direct:{d}", .{pl}),
            .load_got => |pl| try writer.print("[got:{d}]", .{pl}),
            .lea_got => |pl| try writer.print("got:{d}", .{pl}),
            .load_tlv => |pl| try writer.print("[tlv:{d}]", .{pl}),
            .lea_tlv => |pl| try writer.print("tlv:{d}", .{pl}),
            .load_frame => |pl| try writer.print("[{} + 0x{x}]", .{ pl.index, pl.off }),
            .elementwise_regs_then_frame => |pl| try writer.print("elementwise:{d}:[{} + 0x{x}]", .{ pl.regs, pl.frame_index, pl.frame_off }),
            .lea_frame => |pl| try writer.print("{} + 0x{x}", .{ pl.index, pl.off }),
            .reserved_frame => |pl| try writer.print("(dead:{})", .{pl}),
            .air_ref => |pl| try writer.print("(air:0x{x})", .{@intFromEnum(pl)}),
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
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .load_frame,
            .lea_frame,
            .load_symbol,
            .lea_symbol,
            => result,
            .dead,
            .elementwise_regs_then_frame,
            .reserved_frame,
            .air_ref,
            => unreachable,
            .eflags,
            .register,
            .register_pair,
            .register_offset,
            .register_overflow,
            .indirect,
            => .none,
        }, .short = result };
    }

    fn getReg(self: InstTracking) ?Register {
        return self.short.getReg();
    }

    fn getRegs(self: *const InstTracking) []const Register {
        return self.short.getRegs();
    }

    fn getCondition(self: InstTracking) ?Condition {
        return self.short.getCondition();
    }

    fn spill(self: *InstTracking, function: *Self, inst: Air.Inst.Index) !void {
        if (std.meta.eql(self.long, self.short)) return; // Already spilled
        // Allocate or reuse frame index
        switch (self.long) {
            .none => self.long = try function.allocRegOrMem(inst, false),
            .load_frame => {},
            .reserved_frame => |index| self.long = .{ .load_frame = .{ .index = index } },
            else => unreachable,
        }
        tracking_log.debug("spill %{d} from {} to {}", .{ inst, self.short, self.long });
        try function.genCopy(function.typeOfIndex(inst), self.long, self.short, .{});
    }

    fn reuseFrame(self: *InstTracking) void {
        switch (self.long) {
            .reserved_frame => |index| self.long = .{ .load_frame = .{ .index = index } },
            else => {},
        }
        self.short = switch (self.long) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .load_frame,
            .lea_frame,
            .load_symbol,
            .lea_symbol,
            => self.long,
            .dead,
            .eflags,
            .register,
            .register_pair,
            .register_offset,
            .register_overflow,
            .indirect,
            .elementwise_regs_then_frame,
            .reserved_frame,
            .air_ref,
            => unreachable,
        };
    }

    fn trackSpill(self: *InstTracking, function: *Self, inst: Air.Inst.Index) !void {
        try function.freeValue(self.short);
        self.reuseFrame();
        tracking_log.debug("%{d} => {} (spilled)", .{ inst, self.* });
    }

    fn verifyMaterialize(self: InstTracking, target: InstTracking) void {
        switch (self.long) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .lea_frame,
            .load_symbol,
            .lea_symbol,
            => assert(std.meta.eql(self.long, target.long)),
            .load_frame,
            .reserved_frame,
            => switch (target.long) {
                .none,
                .load_frame,
                .reserved_frame,
                => {},
                else => unreachable,
            },
            .dead,
            .eflags,
            .register,
            .register_pair,
            .register_offset,
            .register_overflow,
            .indirect,
            .elementwise_regs_then_frame,
            .air_ref,
            => unreachable,
        }
    }

    fn materialize(
        self: *InstTracking,
        function: *Self,
        inst: Air.Inst.Index,
        target: InstTracking,
    ) !void {
        self.verifyMaterialize(target);
        try self.materializeUnsafe(function, inst, target);
    }

    fn materializeUnsafe(
        self: InstTracking,
        function: *Self,
        inst: Air.Inst.Index,
        target: InstTracking,
    ) !void {
        const ty = function.typeOfIndex(inst);
        if ((self.long == .none or self.long == .reserved_frame) and target.long == .load_frame)
            try function.genCopy(ty, target.long, self.short, .{});
        try function.genCopy(ty, target.short, self.short, .{});
    }

    fn trackMaterialize(self: *InstTracking, inst: Air.Inst.Index, target: InstTracking) void {
        self.verifyMaterialize(target);
        // Don't clobber reserved frame indices
        self.long = if (target.long == .none) switch (self.long) {
            .load_frame => |addr| .{ .reserved_frame = addr.index },
            .reserved_frame => self.long,
            else => target.long,
        } else target.long;
        self.short = target.short;
        tracking_log.debug("%{d} => {} (materialize)", .{ inst, self.* });
    }

    fn resurrect(self: *InstTracking, inst: Air.Inst.Index, scope_generation: u32) void {
        switch (self.short) {
            .dead => |die_generation| if (die_generation >= scope_generation) {
                self.reuseFrame();
                tracking_log.debug("%{d} => {} (resurrect)", .{ inst, self.* });
            },
            else => {},
        }
    }

    fn die(self: *InstTracking, function: *Self, inst: Air.Inst.Index) !void {
        if (self.short == .dead) return;
        try function.freeValue(self.short);
        self.short = .{ .dead = function.scope_generation };
        tracking_log.debug("%{d} => {} (death)", .{ inst, self.* });
    }

    fn reuse(
        self: *InstTracking,
        function: *Self,
        new_inst: ?Air.Inst.Index,
        old_inst: Air.Inst.Index,
    ) void {
        self.short = .{ .dead = function.scope_generation };
        if (new_inst) |inst|
            tracking_log.debug("%{d} => {} (reuse %{d})", .{ inst, self.*, old_inst })
        else
            tracking_log.debug("tmp => {} (reuse %{d})", .{ self.*, old_inst });
    }

    fn liveOut(self: *InstTracking, function: *Self, inst: Air.Inst.Index) void {
        for (self.getRegs()) |reg| {
            if (function.register_manager.isRegFree(reg)) {
                tracking_log.debug("%{d} => {} (live-out)", .{ inst, self.* });
                continue;
            }

            const index = RegisterManager.indexOfRegIntoTracked(reg).?;
            const tracked_inst = function.register_manager.registers[index];
            const tracking = function.getResolvedInstValue(tracked_inst);

            // Disable death.
            var found_reg = false;
            var remaining_reg: Register = .none;
            for (tracking.getRegs()) |tracked_reg| if (tracked_reg.id() == reg.id()) {
                assert(!found_reg);
                found_reg = true;
            } else {
                assert(remaining_reg == .none);
                remaining_reg = tracked_reg;
            };
            assert(found_reg);
            tracking.short = switch (remaining_reg) {
                .none => .{ .dead = function.scope_generation },
                else => .{ .register = remaining_reg },
            };

            // Perform side-effects of freeValue manually.
            function.register_manager.freeReg(reg);

            tracking_log.debug("%{d} => {} (live-out %{d})", .{ inst, self.*, tracked_inst });
        }
    }

    pub fn format(
        self: InstTracking,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (!std.meta.eql(self.long, self.short)) try writer.print("|{}| ", .{self.long});
        try writer.print("{}", .{self.short});
    }
};

const FrameAlloc = struct {
    abi_size: u31,
    spill_pad: u3,
    abi_align: Alignment,
    ref_count: u16,

    fn init(alloc_abi: struct { size: u64, pad: u3 = 0, alignment: Alignment }) FrameAlloc {
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
    fn initSpill(ty: Type, zcu: *Zcu) FrameAlloc {
        const abi_size = ty.abiSize(zcu);
        const spill_size = if (abi_size < 8)
            math.ceilPowerOfTwoAssert(u64, abi_size)
        else
            std.mem.alignForward(u64, abi_size, 8);
        return init(.{
            .size = spill_size,
            .pad = @intCast(spill_size - abi_size),
            .alignment = ty.abiAlignment(zcu).maxStrict(
                Alignment.fromNonzeroByteUnits(@min(spill_size, 8)),
            ),
        });
    }
};

const StackAllocation = struct {
    inst: ?Air.Inst.Index,
    /// TODO do we need size? should be determined by inst.ty.abiSize(zcu)
    size: u32,
};

const BlockData = struct {
    relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .empty,
    state: State,

    fn deinit(self: *BlockData, gpa: Allocator) void {
        self.relocs.deinit(gpa);
        self.* = undefined;
    }
};

const Self = @This();

pub fn generate(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: link.File.DebugInfoOutput,
) CodeGenError!Result {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);
    const fn_type = Type.fromInterned(func.ty);
    const mod = zcu.navFileScope(func.owner_nav).mod;

    var function: Self = .{
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
        .err_msg = null,
        .arg_index = undefined,
        .args = undefined, // populated after `resolveCallingConventionValues`
        .va_info = undefined, // populated after `resolveCallingConventionValues`
        .ret_mcv = undefined, // populated after `resolveCallingConventionValues`
        .fn_type = fn_type,
        .src_loc = src_loc,
        .end_di_line = func.rbrace_line,
        .end_di_column = func.rbrace_column,
    };
    defer {
        function.frame_allocs.deinit(gpa);
        function.free_frame_indices.deinit(gpa);
        function.frame_locs.deinit(gpa);
        function.loops.deinit(gpa);
        var block_it = function.blocks.valueIterator();
        while (block_it.next()) |block| block.deinit(gpa);
        function.blocks.deinit(gpa);
        function.inst_tracking.deinit(gpa);
        function.const_tracking.deinit(gpa);
        function.exitlude_jump_relocs.deinit(gpa);
        function.mir_instructions.deinit(gpa);
        function.mir_extra.deinit(gpa);
    }

    wip_mir_log.debug("{}:", .{fmtNav(func.owner_nav, ip)});

    try function.frame_allocs.resize(gpa, FrameIndex.named_count);
    function.frame_allocs.set(
        @intFromEnum(FrameIndex.stack_frame),
        FrameAlloc.init(.{
            .size = 0,
            .alignment = func.analysisUnordered(ip).stack_alignment.max(.@"1"),
        }),
    );
    function.frame_allocs.set(
        @intFromEnum(FrameIndex.call_frame),
        FrameAlloc.init(.{ .size = 0, .alignment = .@"1" }),
    );

    const fn_info = zcu.typeToFunc(fn_type).?;
    const cc = abi.resolveCallingConvention(fn_info.cc, function.target.*);
    var call_info = function.resolveCallingConventionValues(fn_info, &.{}, .args_frame) catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(
                gpa,
                src_loc,
                "CodeGen ran out of registers. This is a bug in the Zig compiler.",
                .{},
            ),
        },
        else => |e| return e,
    };
    defer call_info.deinit(&function);

    function.args = call_info.args;
    function.ret_mcv = call_info.return_value;
    function.frame_allocs.set(@intFromEnum(FrameIndex.ret_addr), FrameAlloc.init(.{
        .size = Type.usize.abiSize(zcu),
        .alignment = Type.usize.abiAlignment(zcu).min(call_info.stack_align),
    }));
    function.frame_allocs.set(@intFromEnum(FrameIndex.base_ptr), FrameAlloc.init(.{
        .size = Type.usize.abiSize(zcu),
        .alignment = Alignment.min(
            call_info.stack_align,
            Alignment.fromNonzeroByteUnits(function.target.stackAlignment()),
        ),
    }));
    function.frame_allocs.set(
        @intFromEnum(FrameIndex.args_frame),
        FrameAlloc.init(.{
            .size = call_info.stack_byte_count,
            .alignment = call_info.stack_align,
        }),
    );
    function.va_info = switch (cc) {
        else => undefined,
        .SysV => .{ .sysv = .{
            .gp_count = call_info.gp_count,
            .fp_count = call_info.fp_count,
            .overflow_arg_area = .{ .index = .args_frame, .off = call_info.stack_byte_count },
            .reg_save_area = undefined,
        } },
        .Win64 => .{ .win64 = .{} },
    };

    function.gen() catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    var mir: Mir = .{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = try function.mir_extra.toOwnedSlice(gpa),
        .frame_locs = function.frame_locs.toOwnedSlice(),
    };
    defer mir.deinit(gpa);

    var emit: Emit = .{
        .air = function.air,
        .lower = .{
            .bin_file = bin_file,
            .allocator = gpa,
            .mir = mir,
            .cc = cc,
            .src_loc = src_loc,
            .output_mode = comp.config.output_mode,
            .link_mode = comp.config.link_mode,
            .pic = mod.pic,
        },
        .atom_index = function.owner.getSymbolIndex(&function) catch |err| switch (err) {
            error.CodegenFail => return Result{ .fail = function.err_msg.? },
            error.OutOfRegisters => return Result{
                .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
            },
            else => |e| return e,
        },
        .debug_output = debug_output,
        .code = code,
        .prev_di_pc = 0,
        .prev_di_line = func.lbrace_line,
        .prev_di_column = func.lbrace_column,
    };
    defer emit.deinit();
    emit.emitMir() catch |err| switch (err) {
        error.LowerFail, error.EmitFail => return Result{ .fail = emit.lower.err_msg.? },
        error.InvalidInstruction, error.CannotEncode => |e| {
            const msg = switch (e) {
                error.InvalidInstruction => "CodeGen failed to find a viable instruction.",
                error.CannotEncode => "CodeGen failed to encode the instruction.",
            };
            return Result{
                .fail = try ErrorMsg.create(
                    gpa,
                    src_loc,
                    "{s} This is a bug in the Zig compiler.",
                    .{msg},
                ),
            };
        },
        else => |e| return e,
    };

    if (function.err_msg) |em| {
        return Result{ .fail = em };
    } else {
        return Result.ok;
    }
}

pub fn generateLazy(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayList(u8),
    debug_output: link.File.DebugInfoOutput,
) CodeGenError!Result {
    const comp = bin_file.comp;
    const gpa = comp.gpa;
    // This function is for generating global code, so we use the root module.
    const mod = comp.root_mod;
    var function: Self = .{
        .gpa = gpa,
        .pt = pt,
        .air = undefined,
        .liveness = undefined,
        .target = &mod.resolved_target.result,
        .mod = mod,
        .bin_file = bin_file,
        .debug_output = debug_output,
        .owner = .{ .lazy_sym = lazy_sym },
        .inline_func = undefined,
        .err_msg = null,
        .arg_index = undefined,
        .args = undefined,
        .va_info = undefined,
        .ret_mcv = undefined,
        .fn_type = undefined,
        .src_loc = src_loc,
        .end_di_line = undefined, // no debug info yet
        .end_di_column = undefined, // no debug info yet
    };
    defer {
        function.mir_instructions.deinit(gpa);
        function.mir_extra.deinit(gpa);
    }

    function.genLazy(lazy_sym) catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    var mir: Mir = .{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = try function.mir_extra.toOwnedSlice(gpa),
        .frame_locs = function.frame_locs.toOwnedSlice(),
    };
    defer mir.deinit(gpa);

    var emit: Emit = .{
        .air = function.air,
        .lower = .{
            .bin_file = bin_file,
            .allocator = gpa,
            .mir = mir,
            .cc = abi.resolveCallingConvention(.Unspecified, function.target.*),
            .src_loc = src_loc,
            .output_mode = comp.config.output_mode,
            .link_mode = comp.config.link_mode,
            .pic = mod.pic,
        },
        .atom_index = function.owner.getSymbolIndex(&function) catch |err| switch (err) {
            error.CodegenFail => return Result{ .fail = function.err_msg.? },
            error.OutOfRegisters => return Result{
                .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
            },
            else => |e| return e,
        },
        .debug_output = debug_output,
        .code = code,
        .prev_di_pc = undefined, // no debug info yet
        .prev_di_line = undefined, // no debug info yet
        .prev_di_column = undefined, // no debug info yet
    };
    defer emit.deinit();
    emit.emitMir() catch |err| switch (err) {
        error.LowerFail, error.EmitFail => return Result{ .fail = emit.lower.err_msg.? },
        error.InvalidInstruction, error.CannotEncode => |e| {
            const msg = switch (e) {
                error.InvalidInstruction => "CodeGen failed to find a viable instruction.",
                error.CannotEncode => "CodeGen failed to encode the instruction.",
            };
            return Result{
                .fail = try ErrorMsg.create(
                    gpa,
                    src_loc,
                    "{s} This is a bug in the Zig compiler.",
                    .{msg},
                ),
            };
        },
        else => |e| return e,
    };

    if (function.err_msg) |em| {
        return Result{ .fail = em };
    } else {
        return Result.ok;
    }
}

const FormatNavData = struct {
    ip: *const InternPool,
    nav_index: InternPool.Nav.Index,
};
fn formatNav(
    data: FormatNavData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    try writer.print("{}", .{data.ip.getNav(data.nav_index).fqn.fmt(data.ip)});
}
fn fmtNav(nav_index: InternPool.Nav.Index, ip: *const InternPool) std.fmt.Formatter(formatNav) {
    return .{ .data = .{
        .ip = ip,
        .nav_index = nav_index,
    } };
}

const FormatAirData = struct {
    self: *Self,
    inst: Air.Inst.Index,
};
fn formatAir(
    data: FormatAirData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    @import("../../print_air.zig").dumpInst(
        data.inst,
        data.self.pt,
        data.self.air,
        data.self.liveness,
    );
}
fn fmtAir(self: *Self, inst: Air.Inst.Index) std.fmt.Formatter(formatAir) {
    return .{ .data = .{ .self = self, .inst = inst } };
}

const FormatWipMirData = struct {
    self: *Self,
    inst: Mir.Inst.Index,
};
fn formatWipMir(
    data: FormatWipMirData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    const comp = data.self.bin_file.comp;
    const mod = comp.root_mod;
    var lower: Lower = .{
        .bin_file = data.self.bin_file,
        .allocator = data.self.gpa,
        .mir = .{
            .instructions = data.self.mir_instructions.slice(),
            .extra = data.self.mir_extra.items,
            .frame_locs = (std.MultiArrayList(Mir.FrameLoc){}).slice(),
        },
        .cc = .Unspecified,
        .src_loc = data.self.src_loc,
        .output_mode = comp.config.output_mode,
        .link_mode = comp.config.link_mode,
        .pic = mod.pic,
    };
    var first = true;
    for ((lower.lowerMir(data.inst) catch |err| switch (err) {
        error.LowerFail => {
            defer {
                lower.err_msg.?.deinit(data.self.gpa);
                lower.err_msg = null;
            }
            try writer.writeAll(lower.err_msg.?.msg);
            return;
        },
        error.OutOfMemory, error.InvalidInstruction, error.CannotEncode => |e| {
            try writer.writeAll(switch (e) {
                error.OutOfMemory => "Out of memory",
                error.InvalidInstruction => "CodeGen failed to find a viable instruction.",
                error.CannotEncode => "CodeGen failed to encode the instruction.",
            });
            return;
        },
        else => |e| return e,
    }).insts) |lowered_inst| {
        if (!first) try writer.writeAll("\ndebug(wip_mir): ");
        try writer.print("  | {}", .{lowered_inst});
        first = false;
    }
}
fn fmtWipMir(self: *Self, inst: Mir.Inst.Index) std.fmt.Formatter(formatWipMir) {
    return .{ .data = .{ .self = self, .inst = inst } };
}

const FormatTrackingData = struct {
    self: *Self,
};
fn formatTracking(
    data: FormatTrackingData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var it = data.self.inst_tracking.iterator();
    while (it.next()) |entry| try writer.print("\n%{d} = {}", .{ entry.key_ptr.*, entry.value_ptr.* });
}
fn fmtTracking(self: *Self) std.fmt.Formatter(formatTracking) {
    return .{ .data = .{ .self = self } };
}

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;
    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);
    const result_index: Mir.Inst.Index = @intCast(self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    if (inst.tag != .pseudo or switch (inst.ops) {
        else => true,
        .pseudo_dbg_prologue_end_none,
        .pseudo_dbg_line_line_column,
        .pseudo_dbg_epilogue_begin_none,
        .pseudo_dead_none,
        => false,
    }) wip_mir_log.debug("{}", .{self.fmtWipMir(result_index)});
    return result_index;
}

fn addExtra(self: *Self, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try self.mir_extra.ensureUnusedCapacity(self.gpa, fields.len);
    return self.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(self: *Self, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result: u32 = @intCast(self.mir_extra.items.len);
    inline for (fields) |field| {
        self.mir_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            i32, Mir.Memory.Info => @bitCast(@field(extra, field.name)),
            bits.FrameIndex => @intFromEnum(@field(extra, field.name)),
            else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
        });
    }
    return result;
}

/// A `cc` of `.z_and_np` clobbers `reg2`!
fn asmCmovccRegisterRegister(self: *Self, cc: Condition, reg1: Register, reg2: Register) !void {
    _ = try self.addInst(.{
        .tag = switch (cc) {
            else => .cmov,
            .z_and_np, .nz_or_p => .pseudo,
        },
        .ops = switch (cc) {
            else => .rr,
            .z_and_np => .pseudo_cmov_z_and_np_rr,
            .nz_or_p => .pseudo_cmov_nz_or_p_rr,
        },
        .data = .{ .rr = .{
            .fixes = switch (cc) {
                else => Mir.Inst.Fixes.fromCondition(cc),
                .z_and_np, .nz_or_p => ._,
            },
            .r1 = reg1,
            .r2 = reg2,
        } },
    });
}

/// A `cc` of `.z_and_np` is not supported by this encoding!
fn asmCmovccRegisterMemory(self: *Self, cc: Condition, reg: Register, m: Memory) !void {
    _ = try self.addInst(.{
        .tag = switch (cc) {
            else => .cmov,
            .z_and_np => unreachable,
            .nz_or_p => .pseudo,
        },
        .ops = switch (cc) {
            else => .rm,
            .z_and_np => unreachable,
            .nz_or_p => .pseudo_cmov_nz_or_p_rm,
        },
        .data = .{ .rx = .{
            .fixes = switch (cc) {
                else => Mir.Inst.Fixes.fromCondition(cc),
                .z_and_np => unreachable,
                .nz_or_p => ._,
            },
            .r1 = reg,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmSetccRegister(self: *Self, cc: Condition, reg: Register) !void {
    _ = try self.addInst(.{
        .tag = switch (cc) {
            else => .set,
            .z_and_np, .nz_or_p => .pseudo,
        },
        .ops = switch (cc) {
            else => .r,
            .z_and_np => .pseudo_set_z_and_np_r,
            .nz_or_p => .pseudo_set_nz_or_p_r,
        },
        .data = switch (cc) {
            else => .{ .r = .{
                .fixes = Mir.Inst.Fixes.fromCondition(cc),
                .r1 = reg,
            } },
            .z_and_np, .nz_or_p => .{ .rr = .{
                .r1 = reg,
                .r2 = (try self.register_manager.allocReg(null, abi.RegisterClass.gp)).to8(),
            } },
        },
    });
}

fn asmSetccMemory(self: *Self, cc: Condition, m: Memory) !void {
    const payload = try self.addExtra(Mir.Memory.encode(m));
    _ = try self.addInst(.{
        .tag = switch (cc) {
            else => .set,
            .z_and_np, .nz_or_p => .pseudo,
        },
        .ops = switch (cc) {
            else => .m,
            .z_and_np => .pseudo_set_z_and_np_m,
            .nz_or_p => .pseudo_set_nz_or_p_m,
        },
        .data = switch (cc) {
            else => .{ .x = .{
                .fixes = Mir.Inst.Fixes.fromCondition(cc),
                .payload = payload,
            } },
            .z_and_np, .nz_or_p => .{ .rx = .{
                .r1 = (try self.register_manager.allocReg(null, abi.RegisterClass.gp)).to8(),
                .payload = payload,
            } },
        },
    });
}

fn asmJmpReloc(self: *Self, target: Mir.Inst.Index) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = .jmp,
        .ops = .inst,
        .data = .{ .inst = .{
            .inst = target,
        } },
    });
}

fn asmJccReloc(self: *Self, cc: Condition, target: Mir.Inst.Index) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = switch (cc) {
            else => .j,
            .z_and_np, .nz_or_p => .pseudo,
        },
        .ops = switch (cc) {
            else => .inst,
            .z_and_np => .pseudo_j_z_and_np_inst,
            .nz_or_p => .pseudo_j_nz_or_p_inst,
        },
        .data = .{ .inst = .{
            .fixes = switch (cc) {
                else => Mir.Inst.Fixes.fromCondition(cc),
                .z_and_np, .nz_or_p => ._,
            },
            .inst = target,
        } },
    });
}

fn asmReloc(self: *Self, tag: Mir.Inst.FixedTag, target: Mir.Inst.Index) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .inst,
        .data = .{ .inst = .{
            .fixes = tag[0],
            .inst = target,
        } },
    });
}

fn asmPlaceholder(self: *Self) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_dead_none,
        .data = undefined,
    });
}

const MirTagAir = enum { dbg_local };

fn asmAir(self: *Self, tag: MirTagAir, inst: Air.Inst.Index) !void {
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = switch (tag) {
            .dbg_local => .pseudo_dbg_local_a,
        },
        .data = .{ .a = .{ .air_inst = inst } },
    });
}

fn asmAirImmediate(self: *Self, tag: MirTagAir, inst: Air.Inst.Index, imm: Immediate) !void {
    switch (imm) {
        .signed => |s| _ = try self.addInst(.{
            .tag = .pseudo,
            .ops = switch (tag) {
                .dbg_local => .pseudo_dbg_local_ai_s,
            },
            .data = .{ .ai = .{
                .air_inst = inst,
                .i = @bitCast(s),
            } },
        }),
        .unsigned => |u| _ = if (math.cast(u32, u)) |small| try self.addInst(.{
            .tag = .pseudo,
            .ops = switch (tag) {
                .dbg_local => .pseudo_dbg_local_ai_u,
            },
            .data = .{ .ai = .{
                .air_inst = inst,
                .i = small,
            } },
        }) else try self.addInst(.{
            .tag = .pseudo,
            .ops = switch (tag) {
                .dbg_local => .pseudo_dbg_local_ai_64,
            },
            .data = .{ .ai = .{
                .air_inst = inst,
                .i = try self.addExtra(Mir.Imm64.encode(u)),
            } },
        }),
        .reloc => |sym_off| _ = if (sym_off.off == 0) try self.addInst(.{
            .tag = .pseudo,
            .ops = switch (tag) {
                .dbg_local => .pseudo_dbg_local_as,
            },
            .data = .{ .as = .{
                .air_inst = inst,
                .sym_index = sym_off.sym_index,
            } },
        }) else try self.addInst(.{
            .tag = .pseudo,
            .ops = switch (tag) {
                .dbg_local => .pseudo_dbg_local_aso,
            },
            .data = .{ .ax = .{
                .air_inst = inst,
                .payload = try self.addExtra(sym_off),
            } },
        }),
    }
}

fn asmAirRegisterImmediate(
    self: *Self,
    tag: MirTagAir,
    inst: Air.Inst.Index,
    reg: Register,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = switch (tag) {
            .dbg_local => .pseudo_dbg_local_aro,
        },
        .data = .{ .rx = .{
            .r1 = reg,
            .payload = try self.addExtra(Mir.AirOffset{
                .air_inst = inst,
                .off = imm.signed,
            }),
        } },
    });
}

fn asmAirFrameAddress(
    self: *Self,
    tag: MirTagAir,
    inst: Air.Inst.Index,
    frame_addr: bits.FrameAddr,
) !void {
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = switch (tag) {
            .dbg_local => .pseudo_dbg_local_af,
        },
        .data = .{ .ax = .{
            .air_inst = inst,
            .payload = try self.addExtra(frame_addr),
        } },
    });
}

fn asmAirMemory(self: *Self, tag: MirTagAir, inst: Air.Inst.Index, m: Memory) !void {
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = switch (tag) {
            .dbg_local => .pseudo_dbg_local_am,
        },
        .data = .{ .ax = .{
            .air_inst = inst,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmOpOnly(self: *Self, tag: Mir.Inst.FixedTag) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .none,
        .data = .{ .none = .{
            .fixes = tag[0],
        } },
    });
}

fn asmPseudo(self: *Self, ops: Mir.Inst.Ops) !void {
    assert(std.mem.startsWith(u8, @tagName(ops), "pseudo_") and
        std.mem.endsWith(u8, @tagName(ops), "_none"));
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = ops,
        .data = undefined,
    });
}

fn asmPseudoRegister(self: *Self, ops: Mir.Inst.Ops, reg: Register) !void {
    assert(std.mem.startsWith(u8, @tagName(ops), "pseudo_") and
        std.mem.endsWith(u8, @tagName(ops), "_r"));
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = ops,
        .data = .{ .r = .{ .r1 = reg } },
    });
}

fn asmPseudoImmediate(self: *Self, ops: Mir.Inst.Ops, imm: Immediate) !void {
    assert(std.mem.startsWith(u8, @tagName(ops), "pseudo_") and
        std.mem.endsWith(u8, @tagName(ops), "_i_s"));
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = ops,
        .data = .{ .i = .{ .i = @bitCast(imm.signed) } },
    });
}

fn asmPseudoRegisterRegister(self: *Self, ops: Mir.Inst.Ops, reg1: Register, reg2: Register) !void {
    assert(std.mem.startsWith(u8, @tagName(ops), "pseudo_") and
        std.mem.endsWith(u8, @tagName(ops), "_rr"));
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = ops,
        .data = .{ .rr = .{ .r1 = reg1, .r2 = reg2 } },
    });
}

fn asmPseudoRegisterImmediate(self: *Self, ops: Mir.Inst.Ops, reg: Register, imm: Immediate) !void {
    assert(std.mem.startsWith(u8, @tagName(ops), "pseudo_") and
        std.mem.endsWith(u8, @tagName(ops), "_ri_s"));
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = ops,
        .data = .{ .ri = .{ .r1 = reg, .i = @bitCast(imm.signed) } },
    });
}

fn asmRegister(self: *Self, tag: Mir.Inst.FixedTag, reg: Register) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .r,
        .data = .{ .r = .{
            .fixes = tag[0],
            .r1 = reg,
        } },
    });
}

fn asmImmediate(self: *Self, tag: Mir.Inst.FixedTag, imm: Immediate) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = switch (imm) {
            .signed => .i_s,
            .unsigned => .i_u,
            .reloc => .rel,
        },
        .data = switch (imm) {
            .reloc => |sym_off| reloc: {
                assert(tag[0] == ._);
                break :reloc .{ .reloc = sym_off };
            },
            .signed, .unsigned => .{ .i = .{
                .fixes = tag[0],
                .i = switch (imm) {
                    .signed => |s| @bitCast(s),
                    .unsigned => |u| @intCast(u),
                    .reloc => unreachable,
                },
            } },
        },
    });
}

fn asmRegisterRegister(self: *Self, tag: Mir.Inst.FixedTag, reg1: Register, reg2: Register) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rr,
        .data = .{ .rr = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
        } },
    });
}

fn asmRegisterImmediate(self: *Self, tag: Mir.Inst.FixedTag, reg: Register, imm: Immediate) !void {
    const ops: Mir.Inst.Ops, const i: u32 = switch (imm) {
        .signed => |s| .{ .ri_s, @bitCast(s) },
        .unsigned => |u| if (math.cast(u32, u)) |small|
            .{ .ri_u, small }
        else
            .{ .ri_64, try self.addExtra(Mir.Imm64.encode(imm.unsigned)) },
        .reloc => unreachable,
    };
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = ops,
        .data = .{ .ri = .{
            .fixes = tag[0],
            .r1 = reg,
            .i = i,
        } },
    });
}

fn asmRegisterRegisterRegister(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    reg2: Register,
    reg3: Register,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rrr,
        .data = .{ .rrr = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .r3 = reg3,
        } },
    });
}

fn asmRegisterRegisterRegisterRegister(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    reg2: Register,
    reg3: Register,
    reg4: Register,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rrrr,
        .data = .{ .rrrr = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .r3 = reg3,
            .r4 = reg4,
        } },
    });
}

fn asmRegisterRegisterRegisterImmediate(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    reg2: Register,
    reg3: Register,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rrri,
        .data = .{ .rrri = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .r3 = reg3,
            .i = switch (imm) {
                .signed => |s| @bitCast(@as(i8, @intCast(s))),
                .unsigned => |u| @intCast(u),
                .reloc => unreachable,
            },
        } },
    });
}

fn asmRegisterRegisterImmediate(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    reg2: Register,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = switch (imm) {
            .signed => .rri_s,
            .unsigned => .rri_u,
            .reloc => unreachable,
        },
        .data = .{ .rri = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .i = switch (imm) {
                .signed => |s| @bitCast(s),
                .unsigned => |u| @intCast(u),
                .reloc => unreachable,
            },
        } },
    });
}

fn asmRegisterRegisterMemory(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    reg2: Register,
    m: Memory,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rrm,
        .data = .{ .rrx = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmRegisterRegisterMemoryRegister(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    reg2: Register,
    m: Memory,
    reg3: Register,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rrmr,
        .data = .{ .rrrx = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .r3 = reg3,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmMemory(self: *Self, tag: Mir.Inst.FixedTag, m: Memory) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .m,
        .data = .{ .x = .{
            .fixes = tag[0],
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmRegisterMemory(self: *Self, tag: Mir.Inst.FixedTag, reg: Register, m: Memory) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rm,
        .data = .{ .rx = .{
            .fixes = tag[0],
            .r1 = reg,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmRegisterMemoryRegister(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    m: Memory,
    reg2: Register,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rmr,
        .data = .{ .rrx = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmRegisterMemoryImmediate(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg: Register,
    m: Memory,
    imm: Immediate,
) !void {
    if (switch (imm) {
        .signed => |s| if (math.cast(i16, s)) |x| @as(u16, @bitCast(x)) else null,
        .unsigned => |u| math.cast(u16, u),
        .reloc => unreachable,
    }) |small_imm| {
        _ = try self.addInst(.{
            .tag = tag[1],
            .ops = .rmi,
            .data = .{ .rix = .{
                .fixes = tag[0],
                .r1 = reg,
                .i = small_imm,
                .payload = try self.addExtra(Mir.Memory.encode(m)),
            } },
        });
    } else {
        const payload = try self.addExtra(Mir.Imm32{ .imm = switch (imm) {
            .signed => |s| @bitCast(s),
            .unsigned => unreachable,
            .reloc => unreachable,
        } });
        assert(payload + 1 == try self.addExtra(Mir.Memory.encode(m)));
        _ = try self.addInst(.{
            .tag = tag[1],
            .ops = switch (imm) {
                .signed => .rmi_s,
                .unsigned => .rmi_u,
                .reloc => unreachable,
            },
            .data = .{ .rx = .{
                .fixes = tag[0],
                .r1 = reg,
                .payload = payload,
            } },
        });
    }
}

fn asmRegisterRegisterMemoryImmediate(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    reg1: Register,
    reg2: Register,
    m: Memory,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .rrmi,
        .data = .{ .rrix = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .i = @intCast(imm.unsigned),
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmMemoryRegister(self: *Self, tag: Mir.Inst.FixedTag, m: Memory, reg: Register) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .mr,
        .data = .{ .rx = .{
            .fixes = tag[0],
            .r1 = reg,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmMemoryImmediate(self: *Self, tag: Mir.Inst.FixedTag, m: Memory, imm: Immediate) !void {
    const payload = try self.addExtra(Mir.Imm32{ .imm = switch (imm) {
        .signed => |s| @bitCast(s),
        .unsigned => |u| @intCast(u),
        .reloc => unreachable,
    } });
    assert(payload + 1 == try self.addExtra(Mir.Memory.encode(m)));
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = switch (imm) {
            .signed => .mi_s,
            .unsigned => .mi_u,
            .reloc => unreachable,
        },
        .data = .{ .x = .{
            .fixes = tag[0],
            .payload = payload,
        } },
    });
}

fn asmMemoryRegisterRegister(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    m: Memory,
    reg1: Register,
    reg2: Register,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .mrr,
        .data = .{ .rrx = .{
            .fixes = tag[0],
            .r1 = reg1,
            .r2 = reg2,
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn asmMemoryRegisterImmediate(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    m: Memory,
    reg: Register,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = tag[1],
        .ops = .mri,
        .data = .{ .rix = .{
            .fixes = tag[0],
            .r1 = reg,
            .i = @intCast(imm.unsigned),
            .payload = try self.addExtra(Mir.Memory.encode(m)),
        } },
    });
}

fn gen(self: *Self) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const fn_info = zcu.typeToFunc(self.fn_type).?;
    const cc = abi.resolveCallingConvention(fn_info.cc, self.target.*);
    if (cc != .Naked) {
        try self.asmRegister(.{ ._, .push }, .rbp);
        try self.asmPseudoImmediate(.pseudo_cfi_adjust_cfa_offset_i_s, Immediate.s(8));
        try self.asmPseudoRegisterImmediate(.pseudo_cfi_rel_offset_ri_s, .rbp, Immediate.s(0));
        try self.asmRegisterRegister(.{ ._, .mov }, .rbp, .rsp);
        try self.asmPseudoRegister(.pseudo_cfi_def_cfa_register_r, .rbp);
        const backpatch_push_callee_preserved_regs = try self.asmPlaceholder();
        const backpatch_frame_align = try self.asmPlaceholder();
        const backpatch_frame_align_extra = try self.asmPlaceholder();
        const backpatch_stack_alloc = try self.asmPlaceholder();
        const backpatch_stack_alloc_extra = try self.asmPlaceholder();

        switch (self.ret_mcv.long) {
            .none, .unreach => {},
            .indirect => {
                // The address where to store the return value for the caller is in a
                // register which the callee is free to clobber. Therefore, we purposely
                // spill it to stack immediately.
                const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(Type.usize, zcu));
                try self.genSetMem(
                    .{ .frame = frame_index },
                    0,
                    Type.usize,
                    self.ret_mcv.long.address().offset(-self.ret_mcv.short.indirect.off),
                    .{},
                );
                self.ret_mcv.long = .{ .load_frame = .{ .index = frame_index } };
                tracking_log.debug("spill {} to {}", .{ self.ret_mcv.long, frame_index });
            },
            else => unreachable,
        }

        if (fn_info.is_var_args) switch (cc) {
            .SysV => {
                const info = &self.va_info.sysv;
                const reg_save_area_fi = try self.allocFrameIndex(FrameAlloc.init(.{
                    .size = abi.SysV.c_abi_int_param_regs.len * 8 +
                        abi.SysV.c_abi_sse_param_regs.len * 16,
                    .alignment = .@"16",
                }));
                info.reg_save_area = .{ .index = reg_save_area_fi };

                for (abi.SysV.c_abi_int_param_regs[info.gp_count..], info.gp_count..) |reg, reg_i|
                    try self.genSetMem(
                        .{ .frame = reg_save_area_fi },
                        @intCast(reg_i * 8),
                        Type.usize,
                        .{ .register = reg },
                        .{},
                    );

                try self.asmRegisterImmediate(.{ ._, .cmp }, .al, Immediate.u(info.fp_count));
                const skip_sse_reloc = try self.asmJccReloc(.na, undefined);

                const vec_2_f64 = try pt.vectorType(.{ .len = 2, .child = .f64_type });
                for (abi.SysV.c_abi_sse_param_regs[info.fp_count..], info.fp_count..) |reg, reg_i|
                    try self.genSetMem(
                        .{ .frame = reg_save_area_fi },
                        @intCast(abi.SysV.c_abi_int_param_regs.len * 8 + reg_i * 16),
                        vec_2_f64,
                        .{ .register = reg },
                        .{},
                    );

                self.performReloc(skip_sse_reloc);
            },
            .Win64 => return self.fail("TODO implement gen var arg function for Win64", .{}),
            else => unreachable,
        };

        try self.asmPseudo(.pseudo_dbg_prologue_end_none);

        try self.genBody(self.air.getMainBody());

        // TODO can single exitlude jump reloc be elided? What if it is not at the end of the code?
        // Example:
        // pub fn main() void {
        //     maybeErr() catch return;
        //     unreachable;
        // }
        // Eliding the reloc will cause a miscompilation in this case.
        for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            self.mir_instructions.items(.data)[jmp_reloc].inst.inst =
                @intCast(self.mir_instructions.len);
        }

        try self.asmPseudo(.pseudo_dbg_epilogue_begin_none);
        const backpatch_stack_dealloc = try self.asmPlaceholder();
        const backpatch_pop_callee_preserved_regs = try self.asmPlaceholder();
        try self.asmRegister(.{ ._, .pop }, .rbp);
        try self.asmPseudoRegisterImmediate(.pseudo_cfi_def_cfa_ri_s, .rsp, Immediate.s(8));
        try self.asmOpOnly(.{ ._, .ret });

        const frame_layout = try self.computeFrameLayout(cc);
        const need_frame_align = frame_layout.stack_mask != math.maxInt(u32);
        const need_stack_adjust = frame_layout.stack_adjust > 0;
        const need_save_reg = frame_layout.save_reg_list.count() > 0;
        if (need_frame_align) {
            const page_align = @as(u32, math.maxInt(u32)) << 12;
            self.mir_instructions.set(backpatch_frame_align, .{
                .tag = .@"and",
                .ops = .ri_s,
                .data = .{ .ri = .{
                    .r1 = .rsp,
                    .i = @max(frame_layout.stack_mask, page_align),
                } },
            });
            if (frame_layout.stack_mask < page_align) {
                self.mir_instructions.set(backpatch_frame_align_extra, .{
                    .tag = .pseudo,
                    .ops = .pseudo_probe_align_ri_s,
                    .data = .{ .ri = .{
                        .r1 = .rsp,
                        .i = ~frame_layout.stack_mask & page_align,
                    } },
                });
            }
        }
        if (need_stack_adjust) {
            const page_size: u32 = 1 << 12;
            if (frame_layout.stack_adjust <= page_size) {
                self.mir_instructions.set(backpatch_stack_alloc, .{
                    .tag = .sub,
                    .ops = .ri_s,
                    .data = .{ .ri = .{
                        .r1 = .rsp,
                        .i = frame_layout.stack_adjust,
                    } },
                });
            } else if (frame_layout.stack_adjust <
                page_size * Lower.pseudo_probe_adjust_unrolled_max_insts)
            {
                self.mir_instructions.set(backpatch_stack_alloc, .{
                    .tag = .pseudo,
                    .ops = .pseudo_probe_adjust_unrolled_ri_s,
                    .data = .{ .ri = .{
                        .r1 = .rsp,
                        .i = frame_layout.stack_adjust,
                    } },
                });
            } else {
                self.mir_instructions.set(backpatch_stack_alloc, .{
                    .tag = .pseudo,
                    .ops = .pseudo_probe_adjust_setup_rri_s,
                    .data = .{ .rri = .{
                        .r1 = .rsp,
                        .r2 = .rax,
                        .i = frame_layout.stack_adjust,
                    } },
                });
                self.mir_instructions.set(backpatch_stack_alloc_extra, .{
                    .tag = .pseudo,
                    .ops = .pseudo_probe_adjust_loop_rr,
                    .data = .{ .rr = .{
                        .r1 = .rsp,
                        .r2 = .rax,
                    } },
                });
            }
        }
        if (need_frame_align or need_stack_adjust) {
            self.mir_instructions.set(backpatch_stack_dealloc, .{
                .tag = .lea,
                .ops = .rm,
                .data = .{ .rx = .{
                    .r1 = .rsp,
                    .payload = try self.addExtra(Mir.Memory.encode(.{
                        .base = .{ .reg = .rbp },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .disp = -frame_layout.save_reg_list.size(),
                        } },
                    })),
                } },
            });
        }
        if (need_save_reg) {
            self.mir_instructions.set(backpatch_push_callee_preserved_regs, .{
                .tag = .pseudo,
                .ops = .pseudo_push_reg_list,
                .data = .{ .reg_list = frame_layout.save_reg_list },
            });
            self.mir_instructions.set(backpatch_pop_callee_preserved_regs, .{
                .tag = .pseudo,
                .ops = .pseudo_pop_reg_list,
                .data = .{ .reg_list = frame_layout.save_reg_list },
            });
        }
    } else {
        try self.asmPseudo(.pseudo_dbg_prologue_end_none);
        try self.genBody(self.air.getMainBody());
        try self.asmPseudo(.pseudo_dbg_epilogue_begin_none);
    }

    // Drop them off at the rbrace.
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_dbg_line_line_column,
        .data = .{ .line_column = .{
            .line = self.end_di_line,
            .column = self.end_di_column,
        } },
    });
}

fn checkInvariantsAfterAirInst(self: *Self, inst: Air.Inst.Index, old_air_bookkeeping: @TypeOf(air_bookkeeping_init)) void {
    assert(!self.register_manager.lockedRegsExist());

    if (std.debug.runtime_safety) {
        if (self.air_bookkeeping < old_air_bookkeeping + 1) {
            std.debug.panic("in codegen.zig, handling of AIR instruction %{d} ('{}') did not do proper bookkeeping. Look for a missing call to finishAir.", .{ inst, self.air.instructions.items(.tag)[@intFromEnum(inst)] });
        }

        { // check consistency of tracked registers
            var it = self.register_manager.free_registers.iterator(.{ .kind = .unset });
            while (it.next()) |index| {
                const tracked_inst = self.register_manager.registers[index];
                const tracking = self.getResolvedInstValue(tracked_inst);
                for (tracking.getRegs()) |reg| {
                    if (RegisterManager.indexOfRegIntoTracked(reg).? == index) break;
                } else unreachable; // tracked register not in use
            }
        }
    }
}

fn genBody(self: *Self, body: []const Air.Inst.Index) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const air_tags = self.air.instructions.items(.tag);

    self.arg_index = 0;
    for (body) |inst| switch (air_tags[@intFromEnum(inst)]) {
        .arg => {
            wip_mir_log.debug("{}", .{self.fmtAir(inst)});
            verbose_tracking_log.debug("{}", .{self.fmtTracking()});

            const old_air_bookkeeping = self.air_bookkeeping;
            try self.inst_tracking.ensureUnusedCapacity(self.gpa, 1);

            try self.airArg(inst);

            self.checkInvariantsAfterAirInst(inst, old_air_bookkeeping);
        },
        else => break,
    };

    if (self.arg_index == 0) try self.airDbgVarArgs();
    self.arg_index = 0;
    for (body) |inst| {
        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip)) continue;
        wip_mir_log.debug("{}", .{self.fmtAir(inst)});
        verbose_tracking_log.debug("{}", .{self.fmtTracking()});

        const old_air_bookkeeping = self.air_bookkeeping;
        try self.inst_tracking.ensureUnusedCapacity(self.gpa, 1);
        switch (air_tags[@intFromEnum(inst)]) {
            // zig fmt: off
            .not,
            => |tag| try self.airUnOp(inst, tag),

            .add,
            .add_wrap,
            .sub,
            .sub_wrap,
            .bool_and,
            .bool_or,
            .bit_and,
            .bit_or,
            .xor,
            .min,
            .max,
            => |tag| try self.airBinOp(inst, tag),

            .ptr_add, .ptr_sub => |tag| try self.airPtrArithmetic(inst, tag),

            .shr, .shr_exact => try self.airShlShrBinOp(inst),
            .shl, .shl_exact => try self.airShlShrBinOp(inst),

            .mul             => try self.airMulDivBinOp(inst),
            .mul_wrap        => try self.airMulDivBinOp(inst),
            .rem             => try self.airMulDivBinOp(inst),
            .mod             => try self.airMulDivBinOp(inst),

            .add_sat         => try self.airAddSat(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul_sat         => try self.airMulSat(inst),
            .shl_sat         => try self.airShlSat(inst),
            .slice           => try self.airSlice(inst),

            .sin,
            .cos,
            .tan,
            .exp,
            .exp2,
            .log,
            .log2,
            .log10,
            .round,
            => |tag| try self.airUnaryMath(inst, tag),

            .floor       => try self.airRound(inst, .{ .mode = .down, .precision = .inexact }),
            .ceil        => try self.airRound(inst, .{ .mode = .up, .precision = .inexact }),
            .trunc_float => try self.airRound(inst, .{ .mode = .zero, .precision = .inexact }),
            .sqrt        => try self.airSqrt(inst),
            .neg         => try self.airFloatSign(inst),

            .abs => try self.airAbs(inst),

            .add_with_overflow => try self.airAddSubWithOverflow(inst),
            .sub_with_overflow => try self.airAddSubWithOverflow(inst),
            .mul_with_overflow => try self.airMulWithOverflow(inst),
            .shl_with_overflow => try self.airShlWithOverflow(inst),

            .div_float, .div_trunc, .div_floor, .div_exact => try self.airMulDivBinOp(inst),

            .cmp_lt  => try self.airCmp(inst, .lt),
            .cmp_lte => try self.airCmp(inst, .lte),
            .cmp_eq  => try self.airCmp(inst, .eq),
            .cmp_gte => try self.airCmp(inst, .gte),
            .cmp_gt  => try self.airCmp(inst, .gt),
            .cmp_neq => try self.airCmp(inst, .neq),

            .cmp_vector => try self.airCmpVector(inst),
            .cmp_lt_errors_len => try self.airCmpLtErrorsLen(inst),

            .alloc           => try self.airAlloc(inst),
            .ret_ptr         => try self.airRetPtr(inst),
            .arg             => try self.airDbgArg(inst),
            .assembly        => try self.airAsm(inst),
            .bitcast         => try self.airBitCast(inst),
            .block           => try self.airBlock(inst),
            .br              => try self.airBr(inst),
            .repeat          => try self.airRepeat(inst),
            .switch_dispatch => try self.airSwitchDispatch(inst),
            .trap            => try self.airTrap(),
            .breakpoint      => try self.airBreakpoint(),
            .ret_addr        => try self.airRetAddr(inst),
            .frame_addr      => try self.airFrameAddress(inst),
            .fence           => try self.airFence(inst),
            .cond_br         => try self.airCondBr(inst),
            .fptrunc         => try self.airFptrunc(inst),
            .fpext           => try self.airFpext(inst),
            .intcast         => try self.airIntCast(inst),
            .trunc           => try self.airTrunc(inst),
            .int_from_bool     => try self.airIntFromBool(inst),
            .is_non_null     => try self.airIsNonNull(inst),
            .is_non_null_ptr => try self.airIsNonNullPtr(inst),
            .is_null         => try self.airIsNull(inst),
            .is_null_ptr     => try self.airIsNullPtr(inst),
            .is_non_err      => try self.airIsNonErr(inst),
            .is_non_err_ptr  => try self.airIsNonErrPtr(inst),
            .is_err          => try self.airIsErr(inst),
            .is_err_ptr      => try self.airIsErrPtr(inst),
            .load            => try self.airLoad(inst),
            .loop            => try self.airLoop(inst),
            .int_from_ptr        => try self.airIntFromPtr(inst),
            .ret             => try self.airRet(inst, false),
            .ret_safe        => try self.airRet(inst, true),
            .ret_load        => try self.airRetLoad(inst),
            .store           => try self.airStore(inst, false),
            .store_safe      => try self.airStore(inst, true),
            .struct_field_ptr=> try self.airStructFieldPtr(inst),
            .struct_field_val=> try self.airStructFieldVal(inst),
            .array_to_slice  => try self.airArrayToSlice(inst),
            .float_from_int    => try self.airFloatFromInt(inst),
            .int_from_float    => try self.airIntFromFloat(inst),
            .cmpxchg_strong  => try self.airCmpxchg(inst),
            .cmpxchg_weak    => try self.airCmpxchg(inst),
            .atomic_rmw      => try self.airAtomicRmw(inst),
            .atomic_load     => try self.airAtomicLoad(inst),
            .memcpy          => try self.airMemcpy(inst),
            .memset          => try self.airMemset(inst, false),
            .memset_safe     => try self.airMemset(inst, true),
            .set_union_tag   => try self.airSetUnionTag(inst),
            .get_union_tag   => try self.airGetUnionTag(inst),
            .clz             => try self.airClz(inst),
            .ctz             => try self.airCtz(inst),
            .popcount        => try self.airPopCount(inst),
            .byte_swap       => try self.airByteSwap(inst),
            .bit_reverse     => try self.airBitReverse(inst),
            .tag_name        => try self.airTagName(inst),
            .error_name      => try self.airErrorName(inst),
            .splat           => try self.airSplat(inst),
            .select          => try self.airSelect(inst),
            .shuffle         => try self.airShuffle(inst),
            .reduce          => try self.airReduce(inst),
            .aggregate_init  => try self.airAggregateInit(inst),
            .union_init      => try self.airUnionInit(inst),
            .prefetch        => try self.airPrefetch(inst),
            .mul_add         => try self.airMulAdd(inst),
            .addrspace_cast  => return self.fail("TODO implement addrspace_cast", .{}),

            .@"try"          => try self.airTry(inst),
            .try_cold        => try self.airTry(inst), // TODO
            .try_ptr         => try self.airTryPtr(inst),
            .try_ptr_cold    => try self.airTryPtr(inst), // TODO

            .dbg_stmt         => try self.airDbgStmt(inst),
            .dbg_inline_block => try self.airDbgInlineBlock(inst),
            .dbg_var_ptr,
            .dbg_var_val,
            .dbg_arg_inline,
            => try self.airDbgVar(inst),

            .call              => try self.airCall(inst, .auto),
            .call_always_tail  => try self.airCall(inst, .always_tail),
            .call_never_tail   => try self.airCall(inst, .never_tail),
            .call_never_inline => try self.airCall(inst, .never_inline),

            .atomic_store_unordered => try self.airAtomicStore(inst, .unordered),
            .atomic_store_monotonic => try self.airAtomicStore(inst, .monotonic),
            .atomic_store_release   => try self.airAtomicStore(inst, .release),
            .atomic_store_seq_cst   => try self.airAtomicStore(inst, .seq_cst),

            .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

            .field_parent_ptr => try self.airFieldParentPtr(inst),

            .switch_br       => try self.airSwitchBr(inst),
            .loop_switch_br  => try self.airLoopSwitchBr(inst),
            .slice_ptr       => try self.airSlicePtr(inst),
            .slice_len       => try self.airSliceLen(inst),

            .ptr_slice_len_ptr => try self.airPtrSliceLenPtr(inst),
            .ptr_slice_ptr_ptr => try self.airPtrSlicePtrPtr(inst),

            .array_elem_val      => try self.airArrayElemVal(inst),
            .slice_elem_val      => try self.airSliceElemVal(inst),
            .slice_elem_ptr      => try self.airSliceElemPtr(inst),
            .ptr_elem_val        => try self.airPtrElemVal(inst),
            .ptr_elem_ptr        => try self.airPtrElemPtr(inst),

            .inferred_alloc, .inferred_alloc_comptime => unreachable,
            .unreach  => self.finishAirBookkeeping(),

            .optional_payload           => try self.airOptionalPayload(inst),
            .optional_payload_ptr       => try self.airOptionalPayloadPtr(inst),
            .optional_payload_ptr_set   => try self.airOptionalPayloadPtrSet(inst),
            .unwrap_errunion_err        => try self.airUnwrapErrUnionErr(inst),
            .unwrap_errunion_payload    => try self.airUnwrapErrUnionPayload(inst),
            .unwrap_errunion_err_ptr    => try self.airUnwrapErrUnionErrPtr(inst),
            .unwrap_errunion_payload_ptr=> try self.airUnwrapErrUnionPayloadPtr(inst),
            .errunion_payload_ptr_set   => try self.airErrUnionPayloadPtrSet(inst),
            .err_return_trace           => try self.airErrReturnTrace(inst),
            .set_err_return_trace       => try self.airSetErrReturnTrace(inst),
            .save_err_return_trace_index=> try self.airSaveErrReturnTraceIndex(inst),

            .wrap_optional         => try self.airWrapOptional(inst),
            .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
            .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),

            .add_optimized,
            .sub_optimized,
            .mul_optimized,
            .div_float_optimized,
            .div_trunc_optimized,
            .div_floor_optimized,
            .div_exact_optimized,
            .rem_optimized,
            .mod_optimized,
            .neg_optimized,
            .cmp_lt_optimized,
            .cmp_lte_optimized,
            .cmp_eq_optimized,
            .cmp_gte_optimized,
            .cmp_gt_optimized,
            .cmp_neq_optimized,
            .cmp_vector_optimized,
            .reduce_optimized,
            .int_from_float_optimized,
            => return self.fail("TODO implement optimized float mode", .{}),

            .add_safe,
            .sub_safe,
            .mul_safe,
            => return self.fail("TODO implement safety_checked_instructions", .{}),

            .is_named_enum_value => return self.fail("TODO implement is_named_enum_value", .{}),
            .error_set_has_value => return self.fail("TODO implement error_set_has_value", .{}),
            .vector_store_elem => return self.fail("TODO implement vector_store_elem", .{}),

            .c_va_arg => try self.airVaArg(inst),
            .c_va_copy => try self.airVaCopy(inst),
            .c_va_end => try self.airVaEnd(inst),
            .c_va_start => try self.airVaStart(inst),

            .wasm_memory_size => unreachable,
            .wasm_memory_grow => unreachable,

            .work_item_id => unreachable,
            .work_group_size => unreachable,
            .work_group_id => unreachable,
            // zig fmt: on
        }
        self.checkInvariantsAfterAirInst(inst, old_air_bookkeeping);
    }
    verbose_tracking_log.debug("{}", .{self.fmtTracking()});
}

fn genLazy(self: *Self, lazy_sym: link.File.LazySymbol) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    switch (Type.fromInterned(lazy_sym.ty).zigTypeTag(zcu)) {
        .@"enum" => {
            const enum_ty = Type.fromInterned(lazy_sym.ty);
            wip_mir_log.debug("{}.@tagName:", .{enum_ty.fmt(pt)});

            const resolved_cc = abi.resolveCallingConvention(.Unspecified, self.target.*);
            const param_regs = abi.getCAbiIntParamRegs(resolved_cc);
            const param_locks = self.register_manager.lockRegsAssumeUnused(2, param_regs[0..2].*);
            defer for (param_locks) |lock| self.register_manager.unlockReg(lock);

            const ret_reg = param_regs[0];
            const enum_mcv = MCValue{ .register = param_regs[1] };

            const exitlude_jump_relocs = try self.gpa.alloc(Mir.Inst.Index, enum_ty.enumFieldCount(zcu));
            defer self.gpa.free(exitlude_jump_relocs);

            const data_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const data_lock = self.register_manager.lockRegAssumeUnused(data_reg);
            defer self.register_manager.unlockReg(data_lock);
            try self.genLazySymbolRef(.lea, data_reg, .{ .kind = .const_data, .ty = enum_ty.toIntern() });

            var data_off: i32 = 0;
            const tag_names = enum_ty.enumFields(zcu);
            for (exitlude_jump_relocs, 0..) |*exitlude_jump_reloc, tag_index| {
                const tag_name_len = tag_names.get(ip)[tag_index].length(ip);
                const tag_val = try pt.enumValueFieldIndex(enum_ty, @intCast(tag_index));
                const tag_mcv = try self.genTypedValue(tag_val);
                try self.genBinOpMir(.{ ._, .cmp }, enum_ty, enum_mcv, tag_mcv);
                const skip_reloc = try self.asmJccReloc(.ne, undefined);

                try self.genSetMem(
                    .{ .reg = ret_reg },
                    0,
                    Type.usize,
                    .{ .register_offset = .{ .reg = data_reg, .off = data_off } },
                    .{},
                );
                try self.genSetMem(
                    .{ .reg = ret_reg },
                    8,
                    Type.usize,
                    .{ .immediate = tag_name_len },
                    .{},
                );

                exitlude_jump_reloc.* = try self.asmJmpReloc(undefined);
                self.performReloc(skip_reloc);

                data_off += @intCast(tag_name_len + 1);
            }

            try self.airTrap();

            for (exitlude_jump_relocs) |reloc| self.performReloc(reloc);
            try self.asmOpOnly(.{ ._, .ret });
        },
        else => return self.fail(
            "TODO implement {s} for {}",
            .{ @tagName(lazy_sym.kind), Type.fromInterned(lazy_sym.ty).fmt(pt) },
        ),
    }
}

fn getValue(self: *Self, value: MCValue, inst: ?Air.Inst.Index) !void {
    for (value.getRegs()) |reg| try self.register_manager.getReg(reg, inst);
}

fn getValueIfFree(self: *Self, value: MCValue, inst: ?Air.Inst.Index) void {
    for (value.getRegs()) |reg| if (self.register_manager.isRegFree(reg))
        self.register_manager.getRegAssumeFree(reg, inst);
}

fn freeValue(self: *Self, value: MCValue) !void {
    switch (value) {
        .register => |reg| {
            self.register_manager.freeReg(reg);
            if (reg.class() == .x87) try self.asmRegister(.{ .f_, .free }, reg);
        },
        .register_pair => |regs| for (regs) |reg| self.register_manager.freeReg(reg),
        .register_offset => |reg_off| self.register_manager.freeReg(reg_off.reg),
        .register_overflow => |reg_ov| {
            self.register_manager.freeReg(reg_ov.reg);
            self.eflags_inst = null;
        },
        .eflags => self.eflags_inst = null,
        else => {}, // TODO process stack allocation death
    }
}

fn feed(self: *Self, bt: *Liveness.BigTomb, operand: Air.Inst.Ref) !void {
    if (bt.feed()) if (operand.toIndex()) |inst| try self.processDeath(inst);
}

/// Asserts there is already capacity to insert into top branch inst_table.
fn processDeath(self: *Self, inst: Air.Inst.Index) !void {
    try self.inst_tracking.getPtr(inst).?.die(self, inst);
}

/// Called when there are no operands, and the instruction is always unreferenced.
fn finishAirBookkeeping(self: *Self) void {
    if (std.debug.runtime_safety) {
        self.air_bookkeeping += 1;
    }
}

fn finishAirResult(self: *Self, inst: Air.Inst.Index, result: MCValue) void {
    if (self.liveness.isUnused(inst) and self.air.instructions.items(.tag)[@intFromEnum(inst)] != .arg) switch (result) {
        .none, .dead, .unreach => {},
        else => unreachable, // Why didn't the result die?
    } else {
        tracking_log.debug("%{d} => {} (birth)", .{ inst, result });
        self.inst_tracking.putAssumeCapacityNoClobber(inst, InstTracking.init(result));
        // In some cases, an operand may be reused as the result.
        // If that operand died and was a register, it was freed by
        // processDeath, so we have to "re-allocate" the register.
        self.getValueIfFree(result, inst);
    }
    self.finishAirBookkeeping();
}

fn finishAir(
    self: *Self,
    inst: Air.Inst.Index,
    result: MCValue,
    operands: [Liveness.bpi - 1]Air.Inst.Ref,
) !void {
    var tomb_bits = self.liveness.getTombBits(inst);
    for (operands) |op| {
        const dies = @as(u1, @truncate(tomb_bits)) != 0;
        tomb_bits >>= 1;
        if (!dies) continue;
        try self.processDeath(op.toIndexAllowNone() orelse continue);
    }
    self.finishAirResult(inst, result);
}

const FrameLayout = struct {
    stack_mask: u32,
    stack_adjust: u32,
    save_reg_list: Mir.RegisterList,
};

fn setFrameLoc(
    self: *Self,
    frame_index: FrameIndex,
    base: Register,
    offset: *i32,
    comptime aligned: bool,
) void {
    const frame_i = @intFromEnum(frame_index);
    if (aligned) {
        const alignment = self.frame_allocs.items(.abi_align)[frame_i];
        offset.* = @intCast(alignment.forward(@intCast(offset.*)));
    }
    self.frame_locs.set(frame_i, .{ .base = base, .disp = offset.* });
    offset.* += self.frame_allocs.items(.abi_size)[frame_i];
}

fn computeFrameLayout(self: *Self, cc: std.builtin.CallingConvention) !FrameLayout {
    const frame_allocs_len = self.frame_allocs.len;
    try self.frame_locs.resize(self.gpa, frame_allocs_len);
    const stack_frame_order = try self.gpa.alloc(FrameIndex, frame_allocs_len - FrameIndex.named_count);
    defer self.gpa.free(stack_frame_order);

    const frame_size = self.frame_allocs.items(.abi_size);
    const frame_align = self.frame_allocs.items(.abi_align);
    const frame_offset = self.frame_locs.items(.disp);

    for (stack_frame_order, FrameIndex.named_count..) |*frame_order, frame_index|
        frame_order.* = @enumFromInt(frame_index);
    {
        const SortContext = struct {
            frame_align: @TypeOf(frame_align),
            pub fn lessThan(context: @This(), lhs: FrameIndex, rhs: FrameIndex) bool {
                return context.frame_align[@intFromEnum(lhs)].compare(.gt, context.frame_align[@intFromEnum(rhs)]);
            }
        };
        const sort_context = SortContext{ .frame_align = frame_align };
        mem.sort(FrameIndex, stack_frame_order, sort_context, SortContext.lessThan);
    }

    const call_frame_align = frame_align[@intFromEnum(FrameIndex.call_frame)];
    const stack_frame_align = frame_align[@intFromEnum(FrameIndex.stack_frame)];
    const args_frame_align = frame_align[@intFromEnum(FrameIndex.args_frame)];
    const needed_align = call_frame_align.max(stack_frame_align);
    const need_align_stack = needed_align.compare(.gt, args_frame_align);

    // Create list of registers to save in the prologue.
    // TODO handle register classes
    var save_reg_list = Mir.RegisterList{};
    const callee_preserved_regs =
        abi.getCalleePreservedRegs(abi.resolveCallingConvention(cc, self.target.*));
    for (callee_preserved_regs) |reg| {
        if (self.register_manager.isRegAllocated(reg)) {
            save_reg_list.push(callee_preserved_regs, reg);
        }
    }

    var rbp_offset: i32 = 0;
    self.setFrameLoc(.base_ptr, .rbp, &rbp_offset, false);
    self.setFrameLoc(.ret_addr, .rbp, &rbp_offset, false);
    self.setFrameLoc(.args_frame, .rbp, &rbp_offset, false);
    const stack_frame_align_offset = if (need_align_stack)
        0
    else
        save_reg_list.size() + frame_offset[@intFromEnum(FrameIndex.args_frame)];

    var rsp_offset: i32 = 0;
    self.setFrameLoc(.call_frame, .rsp, &rsp_offset, true);
    self.setFrameLoc(.stack_frame, .rsp, &rsp_offset, true);
    for (stack_frame_order) |frame_index| self.setFrameLoc(frame_index, .rsp, &rsp_offset, true);
    rsp_offset += stack_frame_align_offset;
    rsp_offset = @intCast(needed_align.forward(@intCast(rsp_offset)));
    rsp_offset -= stack_frame_align_offset;
    frame_size[@intFromEnum(FrameIndex.call_frame)] =
        @intCast(rsp_offset - frame_offset[@intFromEnum(FrameIndex.stack_frame)]);

    return .{
        .stack_mask = @as(u32, math.maxInt(u32)) << @intCast(if (need_align_stack) @intFromEnum(needed_align) else 0),
        .stack_adjust = @intCast(rsp_offset - frame_offset[@intFromEnum(FrameIndex.call_frame)]),
        .save_reg_list = save_reg_list,
    };
}

fn getFrameAddrAlignment(self: *Self, frame_addr: bits.FrameAddr) Alignment {
    const alloc_align = self.frame_allocs.get(@intFromEnum(frame_addr.index)).abi_align;
    return @enumFromInt(@min(@intFromEnum(alloc_align), @ctz(frame_addr.off)));
}

fn getFrameAddrSize(self: *Self, frame_addr: bits.FrameAddr) u32 {
    return self.frame_allocs.get(@intFromEnum(frame_addr.index)).abi_size - @as(u31, @intCast(frame_addr.off));
}

fn allocFrameIndex(self: *Self, alloc: FrameAlloc) !FrameIndex {
    const frame_allocs_slice = self.frame_allocs.slice();
    const frame_size = frame_allocs_slice.items(.abi_size);
    const frame_align = frame_allocs_slice.items(.abi_align);

    const stack_frame_align = &frame_align[@intFromEnum(FrameIndex.stack_frame)];
    stack_frame_align.* = stack_frame_align.max(alloc.abi_align);

    for (self.free_frame_indices.keys(), 0..) |frame_index, free_i| {
        const abi_size = frame_size[@intFromEnum(frame_index)];
        if (abi_size != alloc.abi_size) continue;
        const abi_align = &frame_align[@intFromEnum(frame_index)];
        abi_align.* = abi_align.max(alloc.abi_align);

        _ = self.free_frame_indices.swapRemoveAt(free_i);
        return frame_index;
    }
    const frame_index: FrameIndex = @enumFromInt(self.frame_allocs.len);
    try self.frame_allocs.append(self.gpa, alloc);
    return frame_index;
}

/// Use a pointer instruction as the basis for allocating stack memory.
fn allocMemPtr(self: *Self, inst: Air.Inst.Index) !FrameIndex {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ptr_ty = self.typeOfIndex(inst);
    const val_ty = ptr_ty.childType(zcu);
    return self.allocFrameIndex(FrameAlloc.init(.{
        .size = math.cast(u32, val_ty.abiSize(zcu)) orelse {
            return self.fail("type '{}' too big to fit into stack frame", .{val_ty.fmt(pt)});
        },
        .alignment = ptr_ty.ptrAlignment(zcu).max(.@"1"),
    }));
}

fn allocRegOrMem(self: *Self, inst: Air.Inst.Index, reg_ok: bool) !MCValue {
    return self.allocRegOrMemAdvanced(self.typeOfIndex(inst), inst, reg_ok);
}

fn allocTempRegOrMem(self: *Self, elem_ty: Type, reg_ok: bool) !MCValue {
    return self.allocRegOrMemAdvanced(elem_ty, null, reg_ok);
}

fn allocRegOrMemAdvanced(self: *Self, ty: Type, inst: ?Air.Inst.Index, reg_ok: bool) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size = math.cast(u32, ty.abiSize(zcu)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{ty.fmt(pt)});
    };

    if (reg_ok) need_mem: {
        if (abi_size <= @as(u32, switch (ty.zigTypeTag(zcu)) {
            .float => switch (ty.floatBits(self.target.*)) {
                16, 32, 64, 128 => 16,
                80 => break :need_mem,
                else => unreachable,
            },
            .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                    16, 32, 64, 128 => if (self.hasFeature(.avx)) 32 else 16,
                    80 => break :need_mem,
                    else => unreachable,
                },
                else => if (self.hasFeature(.avx)) 32 else 16,
            },
            else => 8,
        })) {
            if (self.register_manager.tryAllocReg(inst, self.regClassForType(ty))) |reg| {
                return MCValue{ .register = registerAlias(reg, abi_size) };
            }
        }
    }

    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(ty, zcu));
    return .{ .load_frame = .{ .index = frame_index } };
}

fn regClassForType(self: *Self, ty: Type) RegisterManager.RegisterBitSet {
    const pt = self.pt;
    const zcu = pt.zcu;
    return switch (ty.zigTypeTag(zcu)) {
        .float => switch (ty.floatBits(self.target.*)) {
            80 => abi.RegisterClass.x87,
            else => abi.RegisterClass.sse,
        },
        .vector => switch (ty.childType(zcu).toIntern()) {
            .bool_type, .u1_type => abi.RegisterClass.gp,
            else => if (ty.isAbiInt(zcu) and ty.intInfo(zcu).bits == 1)
                abi.RegisterClass.gp
            else
                abi.RegisterClass.sse,
        },
        else => abi.RegisterClass.gp,
    };
}

const State = struct {
    registers: RegisterManager.TrackedRegisters,
    reg_tracking: [RegisterManager.RegisterBitSet.bit_length]InstTracking,
    free_registers: RegisterManager.RegisterBitSet,
    inst_tracking_len: u32,
    scope_generation: u32,
};

fn initRetroactiveState(self: *Self) State {
    var state: State = undefined;
    state.inst_tracking_len = @intCast(self.inst_tracking.count());
    state.scope_generation = self.scope_generation;
    return state;
}

fn saveRetroactiveState(self: *Self, state: *State) !void {
    try self.spillEflagsIfOccupied();
    const free_registers = self.register_manager.free_registers;
    var it = free_registers.iterator(.{ .kind = .unset });
    while (it.next()) |index| {
        const tracked_inst = self.register_manager.registers[index];
        state.registers[index] = tracked_inst;
        state.reg_tracking[index] = self.inst_tracking.get(tracked_inst).?;
    }
    state.free_registers = free_registers;
}

fn saveState(self: *Self) !State {
    var state = self.initRetroactiveState();
    try self.saveRetroactiveState(&state);
    return state;
}

fn restoreState(self: *Self, state: State, deaths: []const Air.Inst.Index, comptime opts: struct {
    emit_instructions: bool,
    update_tracking: bool,
    resurrect: bool,
    close_scope: bool,
}) !void {
    if (opts.close_scope) {
        for (
            self.inst_tracking.keys()[state.inst_tracking_len..],
            self.inst_tracking.values()[state.inst_tracking_len..],
        ) |inst, *tracking| try tracking.die(self, inst);
        self.inst_tracking.shrinkRetainingCapacity(state.inst_tracking_len);
    }

    if (opts.resurrect) for (
        self.inst_tracking.keys()[0..state.inst_tracking_len],
        self.inst_tracking.values()[0..state.inst_tracking_len],
    ) |inst, *tracking| tracking.resurrect(inst, state.scope_generation);
    for (deaths) |death| try self.processDeath(death);

    const ExpectedContents = [@typeInfo(RegisterManager.TrackedRegisters).array.len]RegisterLock;
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        if (opts.update_tracking)
    {} else std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);

    var reg_locks = if (opts.update_tracking) {} else try std.ArrayList(RegisterLock).initCapacity(
        stack.get(),
        @typeInfo(ExpectedContents).array.len,
    );
    defer if (!opts.update_tracking) {
        for (reg_locks.items) |lock| self.register_manager.unlockReg(lock);
        reg_locks.deinit();
    };

    for (0..state.registers.len) |index| {
        const current_maybe_inst = if (self.register_manager.free_registers.isSet(index))
            null
        else
            self.register_manager.registers[index];
        const target_maybe_inst = if (state.free_registers.isSet(index))
            null
        else
            state.registers[index];
        if (std.debug.runtime_safety) if (target_maybe_inst) |target_inst|
            assert(self.inst_tracking.getIndex(target_inst).? < state.inst_tracking_len);
        if (opts.emit_instructions) {
            if (current_maybe_inst) |current_inst| {
                try self.inst_tracking.getPtr(current_inst).?.spill(self, current_inst);
            }
            if (target_maybe_inst) |target_inst| {
                const target_tracking = self.inst_tracking.getPtr(target_inst).?;
                try target_tracking.materialize(self, target_inst, state.reg_tracking[index]);
            }
        }
        if (opts.update_tracking) {
            if (current_maybe_inst) |current_inst| {
                try self.inst_tracking.getPtr(current_inst).?.trackSpill(self, current_inst);
            }
            {
                const reg = RegisterManager.regAtTrackedIndex(@intCast(index));
                self.register_manager.freeReg(reg);
                self.register_manager.getRegAssumeFree(reg, target_maybe_inst);
            }
            if (target_maybe_inst) |target_inst| {
                self.inst_tracking.getPtr(target_inst).?.trackMaterialize(
                    target_inst,
                    state.reg_tracking[index],
                );
            }
        } else if (target_maybe_inst) |_|
            try reg_locks.append(self.register_manager.lockRegIndexAssumeUnused(@intCast(index)));
    }
    if (opts.emit_instructions) if (self.eflags_inst) |inst|
        try self.inst_tracking.getPtr(inst).?.spill(self, inst);
    if (opts.update_tracking) if (self.eflags_inst) |inst| {
        self.eflags_inst = null;
        try self.inst_tracking.getPtr(inst).?.trackSpill(self, inst);
    };

    if (opts.update_tracking and std.debug.runtime_safety) {
        assert(self.eflags_inst == null);
        assert(self.register_manager.free_registers.eql(state.free_registers));
        var used_reg_it = state.free_registers.iterator(.{ .kind = .unset });
        while (used_reg_it.next()) |index|
            assert(self.register_manager.registers[index] == state.registers[index]);
    }
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const tracking = self.inst_tracking.getPtr(inst) orelse return;
    for (tracking.getRegs()) |tracked_reg| {
        if (tracked_reg.id() == reg.id()) break;
    } else unreachable; // spilled reg not tracked with spilled instruction
    try tracking.spill(self, inst);
    try tracking.trackSpill(self, inst);
}

pub fn spillEflagsIfOccupied(self: *Self) !void {
    if (self.eflags_inst) |inst| {
        self.eflags_inst = null;
        const tracking = self.inst_tracking.getPtr(inst).?;
        assert(tracking.getCondition() != null);
        try tracking.spill(self, inst);
        try tracking.trackSpill(self, inst);
    }
}

pub fn spillCallerPreservedRegs(self: *Self, cc: std.builtin.CallingConvention) !void {
    switch (cc) {
        inline .SysV, .Win64 => |known_cc| try self.spillRegisters(
            comptime abi.getCallerPreservedRegs(known_cc),
        ),
        else => unreachable,
    }
}

pub fn spillRegisters(self: *Self, comptime registers: []const Register) !void {
    inline for (registers) |reg| try self.register_manager.getKnownReg(reg, null);
}

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg = try self.register_manager.allocReg(null, self.regClassForType(ty));
    try self.genSetReg(reg, ty, mcv, .{});
    return reg;
}

/// Allocates a new register and copies `mcv` into it.
/// `reg_owner` is the instruction that gets associated with the register in the register table.
/// This can have a side effect of spilling instructions to the stack to free up a register.
/// WARNING make sure that the allocated register matches the returned MCValue from an instruction!
fn copyToRegisterWithInstTracking(
    self: *Self,
    reg_owner: Air.Inst.Index,
    ty: Type,
    mcv: MCValue,
) !MCValue {
    const reg: Register = try self.register_manager.allocReg(reg_owner, self.regClassForType(ty));
    try self.genSetReg(reg, ty, mcv, .{});
    return MCValue{ .register = reg };
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) !void {
    const result = MCValue{ .lea_frame = .{ .index = try self.allocMemPtr(inst) } };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = switch (self.ret_mcv.long) {
        else => unreachable,
        .none => .{ .lea_frame = .{ .index = try self.allocMemPtr(inst) } },
        .load_frame => .{ .register_offset = .{
            .reg = (try self.copyToRegisterWithInstTracking(
                inst,
                self.typeOfIndex(inst),
                self.ret_mcv.long,
            )).register,
            .off = self.ret_mcv.short.indirect.off,
        } },
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFptrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const dst_ty = self.typeOfIndex(inst);
    const dst_bits = dst_ty.floatBits(self.target.*);
    const src_ty = self.typeOf(ty_op.operand);
    const src_bits = src_ty.floatBits(self.target.*);

    const result = result: {
        if (switch (dst_bits) {
            16 => switch (src_bits) {
                32 => !self.hasFeature(.f16c),
                64, 80, 128 => true,
                else => unreachable,
            },
            32 => switch (src_bits) {
                64 => false,
                80, 128 => true,
                else => unreachable,
            },
            64 => switch (src_bits) {
                80, 128 => true,
                else => unreachable,
            },
            80 => switch (src_bits) {
                128 => true,
                else => unreachable,
            },
            else => unreachable,
        }) {
            var callee_buf: ["__trunc?f?f2".len]u8 = undefined;
            break :result try self.genCall(.{ .lib = .{
                .return_type = self.floatCompilerRtAbiType(dst_ty, src_ty).toIntern(),
                .param_types = &.{self.floatCompilerRtAbiType(src_ty, dst_ty).toIntern()},
                .callee = std.fmt.bufPrint(&callee_buf, "__trunc{c}f{c}f2", .{
                    floatCompilerRtAbiName(src_bits),
                    floatCompilerRtAbiName(dst_bits),
                }) catch unreachable,
            } }, &.{src_ty}, &.{.{ .air_ref = ty_op.operand }});
        }

        const src_mcv = try self.resolveInst(ty_op.operand);
        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);
        const dst_reg = dst_mcv.getReg().?.to128();
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        if (dst_bits == 16) {
            assert(self.hasFeature(.f16c));
            switch (src_bits) {
                32 => {
                    const mat_src_reg = if (src_mcv.isRegister())
                        src_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(src_ty, src_mcv);
                    try self.asmRegisterRegisterImmediate(
                        .{ .v_, .cvtps2ph },
                        dst_reg,
                        mat_src_reg.to128(),
                        Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                    );
                },
                else => unreachable,
            }
        } else {
            assert(src_bits == 64 and dst_bits == 32);
            if (self.hasFeature(.avx)) if (src_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                .{ .v_ss, .cvtsd2 },
                dst_reg,
                dst_reg,
                try src_mcv.mem(self, .qword),
            ) else try self.asmRegisterRegisterRegister(
                .{ .v_ss, .cvtsd2 },
                dst_reg,
                dst_reg,
                (if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(src_ty, src_mcv)).to128(),
            ) else if (src_mcv.isMemory()) try self.asmRegisterMemory(
                .{ ._ss, .cvtsd2 },
                dst_reg,
                try src_mcv.mem(self, .qword),
            ) else try self.asmRegisterRegister(
                .{ ._ss, .cvtsd2 },
                dst_reg,
                (if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(src_ty, src_mcv)).to128(),
            );
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFpext(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const dst_ty = self.typeOfIndex(inst);
    const dst_scalar_ty = dst_ty.scalarType(zcu);
    const dst_bits = dst_scalar_ty.floatBits(self.target.*);
    const src_ty = self.typeOf(ty_op.operand);
    const src_scalar_ty = src_ty.scalarType(zcu);
    const src_bits = src_scalar_ty.floatBits(self.target.*);

    const result = result: {
        if (switch (src_bits) {
            16 => switch (dst_bits) {
                32, 64 => !self.hasFeature(.f16c),
                80, 128 => true,
                else => unreachable,
            },
            32 => switch (dst_bits) {
                64 => false,
                80, 128 => true,
                else => unreachable,
            },
            64 => switch (dst_bits) {
                80, 128 => true,
                else => unreachable,
            },
            80 => switch (dst_bits) {
                128 => true,
                else => unreachable,
            },
            else => unreachable,
        }) {
            if (dst_ty.isVector(zcu)) break :result null;
            var callee_buf: ["__extend?f?f2".len]u8 = undefined;
            break :result try self.genCall(.{ .lib = .{
                .return_type = self.floatCompilerRtAbiType(dst_scalar_ty, src_scalar_ty).toIntern(),
                .param_types = &.{self.floatCompilerRtAbiType(src_scalar_ty, dst_scalar_ty).toIntern()},
                .callee = std.fmt.bufPrint(&callee_buf, "__extend{c}f{c}f2", .{
                    floatCompilerRtAbiName(src_bits),
                    floatCompilerRtAbiName(dst_bits),
                }) catch unreachable,
            } }, &.{src_scalar_ty}, &.{.{ .air_ref = ty_op.operand }});
        }

        const src_abi_size: u32 = @intCast(src_ty.abiSize(zcu));
        const src_mcv = try self.resolveInst(ty_op.operand);
        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);
        const dst_reg = dst_mcv.getReg().?;
        const dst_alias = registerAlias(dst_reg, @intCast(@max(dst_ty.abiSize(zcu), 16)));
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const vec_len = if (dst_ty.isVector(zcu)) dst_ty.vectorLen(zcu) else 1;
        if (src_bits == 16) {
            assert(self.hasFeature(.f16c));
            const mat_src_reg = if (src_mcv.isRegister())
                src_mcv.getReg().?
            else
                try self.copyToTmpRegister(src_ty, src_mcv);
            try self.asmRegisterRegister(
                .{ .v_ps, .cvtph2 },
                dst_alias,
                registerAlias(mat_src_reg, src_abi_size),
            );
            switch (dst_bits) {
                32 => {},
                64 => try self.asmRegisterRegisterRegister(
                    .{ .v_sd, .cvtss2 },
                    dst_alias,
                    dst_alias,
                    dst_alias,
                ),
                else => unreachable,
            }
        } else {
            assert(src_bits == 32 and dst_bits == 64);
            if (self.hasFeature(.avx)) switch (vec_len) {
                1 => if (src_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                    .{ .v_sd, .cvtss2 },
                    dst_alias,
                    dst_alias,
                    try src_mcv.mem(self, self.memSize(src_ty)),
                ) else try self.asmRegisterRegisterRegister(
                    .{ .v_sd, .cvtss2 },
                    dst_alias,
                    dst_alias,
                    registerAlias(if (src_mcv.isRegister())
                        src_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(src_ty, src_mcv), src_abi_size),
                ),
                2...4 => if (src_mcv.isMemory()) try self.asmRegisterMemory(
                    .{ .v_pd, .cvtps2 },
                    dst_alias,
                    try src_mcv.mem(self, self.memSize(src_ty)),
                ) else try self.asmRegisterRegister(
                    .{ .v_pd, .cvtps2 },
                    dst_alias,
                    registerAlias(if (src_mcv.isRegister())
                        src_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(src_ty, src_mcv), src_abi_size),
                ),
                else => break :result null,
            } else if (src_mcv.isMemory()) try self.asmRegisterMemory(
                switch (vec_len) {
                    1 => .{ ._sd, .cvtss2 },
                    2 => .{ ._pd, .cvtps2 },
                    else => break :result null,
                },
                dst_alias,
                try src_mcv.mem(self, self.memSize(src_ty)),
            ) else try self.asmRegisterRegister(
                switch (vec_len) {
                    1 => .{ ._sd, .cvtss2 },
                    2 => .{ ._pd, .cvtps2 },
                    else => break :result null,
                },
                dst_alias,
                registerAlias(if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(src_ty, src_mcv), src_abi_size),
            );
        }
        break :result dst_mcv;
    } orelse return self.fail("TODO implement airFpext from {} to {}", .{
        src_ty.fmt(pt), dst_ty.fmt(pt),
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntCast(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const src_ty = self.typeOf(ty_op.operand);
    const dst_ty = self.typeOfIndex(inst);

    const result = @as(?MCValue, result: {
        const dst_abi_size: u32 = @intCast(dst_ty.abiSize(zcu));

        const src_int_info = src_ty.intInfo(zcu);
        const dst_int_info = dst_ty.intInfo(zcu);
        const extend = switch (src_int_info.signedness) {
            .signed => dst_int_info,
            .unsigned => src_int_info,
        }.signedness;

        const src_mcv = try self.resolveInst(ty_op.operand);
        if (dst_ty.isVector(zcu)) {
            const src_abi_size: u32 = @intCast(src_ty.abiSize(zcu));
            const max_abi_size = @max(dst_abi_size, src_abi_size);
            if (max_abi_size > @as(u32, if (self.hasFeature(.avx2)) 32 else 16)) break :result null;
            const has_avx = self.hasFeature(.avx);

            const dst_elem_abi_size = dst_ty.childType(zcu).abiSize(zcu);
            const src_elem_abi_size = src_ty.childType(zcu).abiSize(zcu);
            switch (math.order(dst_elem_abi_size, src_elem_abi_size)) {
                .lt => {
                    const mir_tag: Mir.Inst.FixedTag = switch (dst_elem_abi_size) {
                        else => break :result null,
                        1 => switch (src_elem_abi_size) {
                            else => break :result null,
                            2 => switch (dst_int_info.signedness) {
                                .signed => if (has_avx) .{ .vp_b, .ackssw } else .{ .p_b, .ackssw },
                                .unsigned => if (has_avx) .{ .vp_b, .ackusw } else .{ .p_b, .ackusw },
                            },
                        },
                        2 => switch (src_elem_abi_size) {
                            else => break :result null,
                            4 => switch (dst_int_info.signedness) {
                                .signed => if (has_avx) .{ .vp_w, .ackssd } else .{ .p_w, .ackssd },
                                .unsigned => if (has_avx)
                                    .{ .vp_w, .ackusd }
                                else if (self.hasFeature(.sse4_1))
                                    .{ .p_w, .ackusd }
                                else
                                    break :result null,
                            },
                        },
                    };

                    const dst_mcv: MCValue = if (src_mcv.isRegister() and
                        self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                        src_mcv
                    else if (has_avx and src_mcv.isRegister())
                        .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
                    else
                        try self.copyToRegisterWithInstTracking(inst, src_ty, src_mcv);
                    const dst_reg = dst_mcv.getReg().?;
                    const dst_alias = registerAlias(dst_reg, dst_abi_size);

                    if (has_avx) try self.asmRegisterRegisterRegister(
                        mir_tag,
                        dst_alias,
                        registerAlias(if (src_mcv.isRegister())
                            src_mcv.getReg().?
                        else
                            dst_reg, src_abi_size),
                        dst_alias,
                    ) else try self.asmRegisterRegister(
                        mir_tag,
                        dst_alias,
                        dst_alias,
                    );
                    break :result dst_mcv;
                },
                .eq => if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                    break :result src_mcv
                else {
                    const dst_mcv = try self.allocRegOrMem(inst, true);
                    try self.genCopy(dst_ty, dst_mcv, src_mcv, .{});
                    break :result dst_mcv;
                },
                .gt => if (self.hasFeature(.sse4_1)) {
                    const mir_tag: Mir.Inst.FixedTag = .{ switch (dst_elem_abi_size) {
                        else => break :result null,
                        2 => if (has_avx) .vp_w else .p_w,
                        4 => if (has_avx) .vp_d else .p_d,
                        8 => if (has_avx) .vp_q else .p_q,
                    }, switch (src_elem_abi_size) {
                        else => break :result null,
                        1 => switch (extend) {
                            .signed => .movsxb,
                            .unsigned => .movzxb,
                        },
                        2 => switch (extend) {
                            .signed => .movsxw,
                            .unsigned => .movzxw,
                        },
                        4 => switch (extend) {
                            .signed => .movsxd,
                            .unsigned => .movzxd,
                        },
                    } };

                    const dst_mcv: MCValue = if (src_mcv.isRegister() and
                        self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                        src_mcv
                    else
                        .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) };
                    const dst_reg = dst_mcv.getReg().?;
                    const dst_alias = registerAlias(dst_reg, dst_abi_size);

                    if (src_mcv.isMemory()) try self.asmRegisterMemory(
                        mir_tag,
                        dst_alias,
                        try src_mcv.mem(self, self.memSize(src_ty)),
                    ) else try self.asmRegisterRegister(
                        mir_tag,
                        dst_alias,
                        registerAlias(if (src_mcv.isRegister())
                            src_mcv.getReg().?
                        else
                            try self.copyToTmpRegister(src_ty, src_mcv), src_abi_size),
                    );
                    break :result dst_mcv;
                } else {
                    const mir_tag: Mir.Inst.FixedTag = switch (dst_elem_abi_size) {
                        else => break :result null,
                        2 => switch (src_elem_abi_size) {
                            else => break :result null,
                            1 => .{ .p_, .unpcklbw },
                        },
                        4 => switch (src_elem_abi_size) {
                            else => break :result null,
                            2 => .{ .p_, .unpcklwd },
                        },
                        8 => switch (src_elem_abi_size) {
                            else => break :result null,
                            2 => .{ .p_, .unpckldq },
                        },
                    };

                    const dst_mcv: MCValue = if (src_mcv.isRegister() and
                        self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                        src_mcv
                    else
                        try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);
                    const dst_reg = dst_mcv.getReg().?;

                    const ext_reg = try self.register_manager.allocReg(null, abi.RegisterClass.sse);
                    const ext_alias = registerAlias(ext_reg, src_abi_size);
                    const ext_lock = self.register_manager.lockRegAssumeUnused(ext_reg);
                    defer self.register_manager.unlockReg(ext_lock);

                    try self.asmRegisterRegister(.{ .p_, .xor }, ext_alias, ext_alias);
                    switch (extend) {
                        .signed => try self.asmRegisterRegister(
                            .{ switch (src_elem_abi_size) {
                                else => unreachable,
                                1 => .p_b,
                                2 => .p_w,
                                4 => .p_d,
                            }, .cmpgt },
                            ext_alias,
                            registerAlias(dst_reg, src_abi_size),
                        ),
                        .unsigned => {},
                    }
                    try self.asmRegisterRegister(
                        mir_tag,
                        registerAlias(dst_reg, dst_abi_size),
                        registerAlias(ext_reg, dst_abi_size),
                    );
                    break :result dst_mcv;
                },
            }
            @compileError("unreachable");
        }

        const min_ty = if (dst_int_info.bits < src_int_info.bits) dst_ty else src_ty;

        const src_storage_bits: u16 = switch (src_mcv) {
            .register, .register_offset => 64,
            .register_pair => 128,
            .load_frame => |frame_addr| @intCast(self.getFrameAddrSize(frame_addr) * 8),
            else => src_int_info.bits,
        };

        const dst_mcv = if (dst_int_info.bits <= src_storage_bits and
            math.divCeil(u16, dst_int_info.bits, 64) catch unreachable ==
            math.divCeil(u32, src_storage_bits, 64) catch unreachable and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) src_mcv else dst: {
            const dst_mcv = try self.allocRegOrMem(inst, true);
            try self.genCopy(min_ty, dst_mcv, src_mcv, .{});
            break :dst dst_mcv;
        };

        if (dst_int_info.bits <= src_int_info.bits) break :result if (dst_mcv.isRegister())
            .{ .register = registerAlias(dst_mcv.getReg().?, dst_abi_size) }
        else
            dst_mcv;

        if (dst_mcv.isRegister()) {
            try self.truncateRegister(src_ty, dst_mcv.getReg().?);
            break :result .{ .register = registerAlias(dst_mcv.getReg().?, dst_abi_size) };
        }

        const src_limbs_len = math.divCeil(u16, src_int_info.bits, 64) catch unreachable;
        const dst_limbs_len = math.divCeil(u16, dst_int_info.bits, 64) catch unreachable;

        const high_mcv: MCValue = if (dst_mcv.isMemory())
            dst_mcv.address().offset((src_limbs_len - 1) * 8).deref()
        else
            .{ .register = dst_mcv.register_pair[1] };
        const high_reg = if (high_mcv.isRegister())
            high_mcv.getReg().?
        else
            try self.copyToTmpRegister(switch (src_int_info.signedness) {
                .signed => Type.isize,
                .unsigned => Type.usize,
            }, high_mcv);
        const high_lock = self.register_manager.lockRegAssumeUnused(high_reg);
        defer self.register_manager.unlockReg(high_lock);

        const high_bits = src_int_info.bits % 64;
        if (high_bits > 0) {
            try self.truncateRegister(src_ty, high_reg);
            const high_ty = if (dst_int_info.bits >= 64) Type.usize else dst_ty;
            try self.genCopy(high_ty, high_mcv, .{ .register = high_reg }, .{});
        }

        if (dst_limbs_len > src_limbs_len) try self.genInlineMemset(
            dst_mcv.address().offset(src_limbs_len * 8),
            switch (extend) {
                .signed => extend: {
                    const extend_mcv = MCValue{ .register = high_reg };
                    try self.genShiftBinOpMir(
                        .{ ._r, .sa },
                        Type.isize,
                        extend_mcv,
                        Type.u8,
                        .{ .immediate = 63 },
                    );
                    break :extend extend_mcv;
                },
                .unsigned => .{ .immediate = 0 },
            },
            .{ .immediate = (dst_limbs_len - src_limbs_len) * 8 },
            .{},
        );

        break :result dst_mcv;
    }) orelse return self.fail("TODO implement airIntCast from {} to {}", .{
        src_ty.fmt(pt), dst_ty.fmt(pt),
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const dst_ty = self.typeOfIndex(inst);
    const dst_abi_size: u32 = @intCast(dst_ty.abiSize(zcu));
    const src_ty = self.typeOf(ty_op.operand);
    const src_abi_size: u32 = @intCast(src_ty.abiSize(zcu));

    const result = result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_lock =
            if (src_mcv.getReg()) |reg| self.register_manager.lockRegAssumeUnused(reg) else null;
        defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else if (dst_abi_size <= 8)
            try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv)
        else if (dst_abi_size <= 16 and !dst_ty.isVector(zcu)) dst: {
            const dst_regs =
                try self.register_manager.allocRegs(2, .{ inst, inst }, abi.RegisterClass.gp);
            const dst_mcv: MCValue = .{ .register_pair = dst_regs };
            const dst_locks = self.register_manager.lockRegsAssumeUnused(2, dst_regs);
            defer for (dst_locks) |lock| self.register_manager.unlockReg(lock);

            try self.genCopy(dst_ty, dst_mcv, src_mcv, .{});
            break :dst dst_mcv;
        } else dst: {
            const dst_mcv = try self.allocRegOrMemAdvanced(src_ty, inst, true);
            try self.genCopy(src_ty, dst_mcv, src_mcv, .{});
            break :dst dst_mcv;
        };

        if (dst_ty.zigTypeTag(zcu) == .vector) {
            assert(src_ty.zigTypeTag(zcu) == .vector and dst_ty.vectorLen(zcu) == src_ty.vectorLen(zcu));
            const dst_elem_ty = dst_ty.childType(zcu);
            const dst_elem_abi_size: u32 = @intCast(dst_elem_ty.abiSize(zcu));
            const src_elem_ty = src_ty.childType(zcu);
            const src_elem_abi_size: u32 = @intCast(src_elem_ty.abiSize(zcu));

            const mir_tag = @as(?Mir.Inst.FixedTag, switch (dst_elem_abi_size) {
                1 => switch (src_elem_abi_size) {
                    2 => switch (dst_ty.vectorLen(zcu)) {
                        1...8 => if (self.hasFeature(.avx)) .{ .vp_b, .ackusw } else .{ .p_b, .ackusw },
                        9...16 => if (self.hasFeature(.avx2)) .{ .vp_b, .ackusw } else null,
                        else => null,
                    },
                    else => null,
                },
                2 => switch (src_elem_abi_size) {
                    4 => switch (dst_ty.vectorLen(zcu)) {
                        1...4 => if (self.hasFeature(.avx))
                            .{ .vp_w, .ackusd }
                        else if (self.hasFeature(.sse4_1))
                            .{ .p_w, .ackusd }
                        else
                            null,
                        5...8 => if (self.hasFeature(.avx2)) .{ .vp_w, .ackusd } else null,
                        else => null,
                    },
                    else => null,
                },
                else => null,
            }) orelse return self.fail("TODO implement airTrunc for {}", .{dst_ty.fmt(pt)});

            const dst_info = dst_elem_ty.intInfo(zcu);
            const src_info = src_elem_ty.intInfo(zcu);

            const mask_val = try pt.intValue(src_elem_ty, @as(u64, math.maxInt(u64)) >> @intCast(64 - dst_info.bits));

            const splat_ty = try pt.vectorType(.{
                .len = @intCast(@divExact(@as(u64, if (src_abi_size > 16) 256 else 128), src_info.bits)),
                .child = src_elem_ty.ip_index,
            });
            const splat_abi_size: u32 = @intCast(splat_ty.abiSize(zcu));

            const splat_val = try pt.intern(.{ .aggregate = .{
                .ty = splat_ty.ip_index,
                .storage = .{ .repeated_elem = mask_val.ip_index },
            } });

            const splat_mcv = try self.genTypedValue(Value.fromInterned(splat_val));
            const splat_addr_mcv: MCValue = switch (splat_mcv) {
                .memory, .indirect, .load_frame => splat_mcv.address(),
                else => .{ .register = try self.copyToTmpRegister(Type.usize, splat_mcv.address()) },
            };

            const dst_reg = dst_mcv.getReg().?;
            const dst_alias = registerAlias(dst_reg, src_abi_size);
            if (self.hasFeature(.avx)) {
                try self.asmRegisterRegisterMemory(
                    .{ .vp_, .@"and" },
                    dst_alias,
                    dst_alias,
                    try splat_addr_mcv.deref().mem(self, Memory.Size.fromSize(splat_abi_size)),
                );
                if (src_abi_size > 16) {
                    const temp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.sse);
                    const temp_lock = self.register_manager.lockRegAssumeUnused(temp_reg);
                    defer self.register_manager.unlockReg(temp_lock);

                    try self.asmRegisterRegisterImmediate(
                        .{ if (self.hasFeature(.avx2)) .v_i128 else .v_f128, .extract },
                        registerAlias(temp_reg, dst_abi_size),
                        dst_alias,
                        Immediate.u(1),
                    );
                    try self.asmRegisterRegisterRegister(
                        mir_tag,
                        registerAlias(dst_reg, dst_abi_size),
                        registerAlias(dst_reg, dst_abi_size),
                        registerAlias(temp_reg, dst_abi_size),
                    );
                } else try self.asmRegisterRegisterRegister(mir_tag, dst_alias, dst_alias, dst_alias);
            } else {
                try self.asmRegisterMemory(
                    .{ .p_, .@"and" },
                    dst_alias,
                    try splat_addr_mcv.deref().mem(self, Memory.Size.fromSize(splat_abi_size)),
                );
                try self.asmRegisterRegister(mir_tag, dst_alias, dst_alias);
            }
            break :result dst_mcv;
        }

        // when truncating a `u16` to `u5`, for example, those top 3 bits in the result
        // have to be removed. this only happens if the dst if not a power-of-two size.
        if (dst_abi_size <= 8) {
            if (self.regExtraBits(dst_ty) > 0) {
                try self.truncateRegister(dst_ty, dst_mcv.register.to64());
            }
        } else if (dst_abi_size <= 16) {
            const dst_info = dst_ty.intInfo(zcu);
            const high_ty = try pt.intType(dst_info.signedness, dst_info.bits - 64);
            if (self.regExtraBits(high_ty) > 0) {
                try self.truncateRegister(high_ty, dst_mcv.register_pair[1].to64());
            }
        }

        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromBool(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ty = self.typeOfIndex(inst);

    const operand = try self.resolveInst(un_op);
    const dst_mcv = if (self.reuseOperand(inst, un_op, 0, operand))
        operand
    else
        try self.copyToRegisterWithInstTracking(inst, ty, operand);

    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    const slice_ty = self.typeOfIndex(inst);
    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(slice_ty, zcu));

    const ptr_ty = self.typeOf(bin_op.lhs);
    try self.genSetMem(.{ .frame = frame_index }, 0, ptr_ty, .{ .air_ref = bin_op.lhs }, .{});

    const len_ty = self.typeOf(bin_op.rhs);
    try self.genSetMem(
        .{ .frame = frame_index },
        @intCast(ptr_ty.abiSize(zcu)),
        len_ty,
        .{ .air_ref = bin_op.rhs },
        .{},
    );

    const result = MCValue{ .load_frame = .{ .index = frame_index } };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airUnOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const dst_mcv = try self.genUnOp(inst, tag, ty_op.operand);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const dst_mcv = try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);

    const dst_ty = self.typeOfIndex(inst);
    if (dst_ty.isAbiInt(zcu)) {
        const abi_size: u32 = @intCast(dst_ty.abiSize(zcu));
        const bit_size: u32 = @intCast(dst_ty.bitSize(zcu));
        if (abi_size * 8 > bit_size) {
            const dst_lock = switch (dst_mcv) {
                .register => |dst_reg| self.register_manager.lockRegAssumeUnused(dst_reg),
                else => null,
            };
            defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

            if (dst_mcv.isRegister()) {
                try self.truncateRegister(dst_ty, dst_mcv.getReg().?);
            } else {
                const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                defer self.register_manager.unlockReg(tmp_lock);

                const hi_ty = try pt.intType(.unsigned, @intCast((dst_ty.bitSize(zcu) - 1) % 64 + 1));
                const hi_mcv = dst_mcv.address().offset(@intCast(bit_size / 64 * 8)).deref();
                try self.genSetReg(tmp_reg, hi_ty, hi_mcv, .{});
                try self.truncateRegister(dst_ty, tmp_reg);
                try self.genCopy(hi_ty, hi_mcv, .{ .register = tmp_reg }, .{});
            }
        }
    }
    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const dst_mcv = try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn activeIntBits(self: *Self, dst_air: Air.Inst.Ref) u16 {
    const pt = self.pt;
    const zcu = pt.zcu;
    const air_tag = self.air.instructions.items(.tag);
    const air_data = self.air.instructions.items(.data);

    const dst_ty = self.typeOf(dst_air);
    const dst_info = dst_ty.intInfo(zcu);
    if (dst_air.toIndex()) |inst| {
        switch (air_tag[@intFromEnum(inst)]) {
            .intcast => {
                const src_ty = self.typeOf(air_data[@intFromEnum(inst)].ty_op.operand);
                const src_info = src_ty.intInfo(zcu);
                return @min(switch (src_info.signedness) {
                    .signed => switch (dst_info.signedness) {
                        .signed => src_info.bits,
                        .unsigned => src_info.bits - 1,
                    },
                    .unsigned => switch (dst_info.signedness) {
                        .signed => src_info.bits + 1,
                        .unsigned => src_info.bits,
                    },
                }, dst_info.bits);
            },
            else => {},
        }
    } else if (dst_air.toInterned()) |ip_index| {
        var space: Value.BigIntSpace = undefined;
        const src_int = Value.fromInterned(ip_index).toBigInt(&space, zcu);
        return @as(u16, @intCast(src_int.bitCountTwosComp())) +
            @intFromBool(src_int.positive and dst_info.signedness == .signed);
    }
    return dst_info.bits;
}

fn airMulDivBinOp(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result = result: {
        const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
        const dst_ty = self.typeOfIndex(inst);
        switch (dst_ty.zigTypeTag(zcu)) {
            .float, .vector => break :result try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs),
            else => {},
        }
        const dst_abi_size: u32 = @intCast(dst_ty.abiSize(zcu));

        const dst_info = dst_ty.intInfo(zcu);
        const src_ty = try pt.intType(dst_info.signedness, switch (tag) {
            else => unreachable,
            .mul, .mul_wrap => @max(
                self.activeIntBits(bin_op.lhs),
                self.activeIntBits(bin_op.rhs),
                dst_info.bits / 2,
            ),
            .div_trunc, .div_floor, .div_exact, .rem, .mod => dst_info.bits,
        });
        const src_abi_size: u32 = @intCast(src_ty.abiSize(zcu));

        if (dst_abi_size == 16 and src_abi_size == 16) switch (tag) {
            else => unreachable,
            .mul, .mul_wrap => {},
            .div_trunc, .div_floor, .div_exact, .rem, .mod => {
                const signed = dst_ty.isSignedInt(zcu);
                var callee_buf: ["__udiv?i3".len]u8 = undefined;
                const signed_div_floor_state: struct {
                    frame_index: FrameIndex,
                    state: State,
                    reloc: Mir.Inst.Index,
                } = if (signed and tag == .div_floor) state: {
                    const frame_index = try self.allocFrameIndex(FrameAlloc.initType(Type.usize, zcu));
                    try self.asmMemoryImmediate(
                        .{ ._, .mov },
                        .{ .base = .{ .frame = frame_index }, .mod = .{ .rm = .{ .size = .qword } } },
                        Immediate.u(0),
                    );

                    const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    const lhs_mcv = try self.resolveInst(bin_op.lhs);
                    const mat_lhs_mcv = switch (lhs_mcv) {
                        .load_symbol => mat_lhs_mcv: {
                            // TODO clean this up!
                            const addr_reg = try self.copyToTmpRegister(Type.usize, lhs_mcv.address());
                            break :mat_lhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
                        },
                        else => lhs_mcv,
                    };
                    const mat_lhs_lock = switch (mat_lhs_mcv) {
                        .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
                        else => null,
                    };
                    defer if (mat_lhs_lock) |lock| self.register_manager.unlockReg(lock);
                    if (mat_lhs_mcv.isMemory()) try self.asmRegisterMemory(
                        .{ ._, .mov },
                        tmp_reg,
                        try mat_lhs_mcv.address().offset(8).deref().mem(self, .qword),
                    ) else try self.asmRegisterRegister(
                        .{ ._, .mov },
                        tmp_reg,
                        mat_lhs_mcv.register_pair[1],
                    );

                    const rhs_mcv = try self.resolveInst(bin_op.rhs);
                    const mat_rhs_mcv = switch (rhs_mcv) {
                        .load_symbol => mat_rhs_mcv: {
                            // TODO clean this up!
                            const addr_reg = try self.copyToTmpRegister(Type.usize, rhs_mcv.address());
                            break :mat_rhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
                        },
                        else => rhs_mcv,
                    };
                    const mat_rhs_lock = switch (mat_rhs_mcv) {
                        .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
                        else => null,
                    };
                    defer if (mat_rhs_lock) |lock| self.register_manager.unlockReg(lock);
                    if (mat_rhs_mcv.isMemory()) try self.asmRegisterMemory(
                        .{ ._, .xor },
                        tmp_reg,
                        try mat_rhs_mcv.address().offset(8).deref().mem(self, .qword),
                    ) else try self.asmRegisterRegister(
                        .{ ._, .xor },
                        tmp_reg,
                        mat_rhs_mcv.register_pair[1],
                    );
                    const state = try self.saveState();
                    const reloc = try self.asmJccReloc(.ns, undefined);

                    break :state .{ .frame_index = frame_index, .state = state, .reloc = reloc };
                } else undefined;
                const call_mcv = try self.genCall(
                    .{ .lib = .{
                        .return_type = dst_ty.toIntern(),
                        .param_types = &.{ src_ty.toIntern(), src_ty.toIntern() },
                        .callee = std.fmt.bufPrint(&callee_buf, "__{s}{s}{c}i3", .{
                            if (signed) "" else "u",
                            switch (tag) {
                                .div_trunc, .div_exact => "div",
                                .div_floor => if (signed) "mod" else "div",
                                .rem, .mod => "mod",
                                else => unreachable,
                            },
                            intCompilerRtAbiName(@intCast(dst_ty.bitSize(zcu))),
                        }) catch unreachable,
                    } },
                    &.{ src_ty, src_ty },
                    &.{ .{ .air_ref = bin_op.lhs }, .{ .air_ref = bin_op.rhs } },
                );
                break :result if (signed) switch (tag) {
                    .div_floor => {
                        try self.asmRegisterRegister(
                            .{ ._, .@"or" },
                            call_mcv.register_pair[0],
                            call_mcv.register_pair[1],
                        );
                        try self.asmSetccMemory(.nz, .{
                            .base = .{ .frame = signed_div_floor_state.frame_index },
                            .mod = .{ .rm = .{ .size = .byte } },
                        });
                        try self.restoreState(signed_div_floor_state.state, &.{}, .{
                            .emit_instructions = true,
                            .update_tracking = true,
                            .resurrect = true,
                            .close_scope = true,
                        });
                        self.performReloc(signed_div_floor_state.reloc);
                        const dst_mcv = try self.genCall(
                            .{ .lib = .{
                                .return_type = dst_ty.toIntern(),
                                .param_types = &.{ src_ty.toIntern(), src_ty.toIntern() },
                                .callee = std.fmt.bufPrint(&callee_buf, "__div{c}i3", .{
                                    intCompilerRtAbiName(@intCast(dst_ty.bitSize(zcu))),
                                }) catch unreachable,
                            } },
                            &.{ src_ty, src_ty },
                            &.{ .{ .air_ref = bin_op.lhs }, .{ .air_ref = bin_op.rhs } },
                        );
                        try self.asmRegisterMemory(
                            .{ ._, .sub },
                            dst_mcv.register_pair[0],
                            .{
                                .base = .{ .frame = signed_div_floor_state.frame_index },
                                .mod = .{ .rm = .{ .size = .qword } },
                            },
                        );
                        try self.asmRegisterImmediate(
                            .{ ._, .sbb },
                            dst_mcv.register_pair[1],
                            Immediate.u(0),
                        );
                        try self.freeValue(
                            .{ .load_frame = .{ .index = signed_div_floor_state.frame_index } },
                        );
                        break :result dst_mcv;
                    },
                    .mod => {
                        const dst_regs = call_mcv.register_pair;
                        const dst_locks = self.register_manager.lockRegsAssumeUnused(2, dst_regs);
                        defer for (dst_locks) |lock| self.register_manager.unlockReg(lock);

                        const tmp_regs =
                            try self.register_manager.allocRegs(2, .{null} ** 2, abi.RegisterClass.gp);
                        const tmp_locks = self.register_manager.lockRegsAssumeUnused(2, tmp_regs);
                        defer for (tmp_locks) |lock| self.register_manager.unlockReg(lock);

                        const rhs_mcv = try self.resolveInst(bin_op.rhs);
                        const mat_rhs_mcv = switch (rhs_mcv) {
                            .load_symbol => mat_rhs_mcv: {
                                // TODO clean this up!
                                const addr_reg = try self.copyToTmpRegister(Type.usize, rhs_mcv.address());
                                break :mat_rhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
                            },
                            else => rhs_mcv,
                        };
                        const mat_rhs_lock = switch (mat_rhs_mcv) {
                            .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
                            else => null,
                        };
                        defer if (mat_rhs_lock) |lock| self.register_manager.unlockReg(lock);

                        for (tmp_regs, dst_regs) |tmp_reg, dst_reg|
                            try self.asmRegisterRegister(.{ ._, .mov }, tmp_reg, dst_reg);
                        if (mat_rhs_mcv.isMemory()) {
                            try self.asmRegisterMemory(
                                .{ ._, .add },
                                tmp_regs[0],
                                try mat_rhs_mcv.mem(self, .qword),
                            );
                            try self.asmRegisterMemory(
                                .{ ._, .adc },
                                tmp_regs[1],
                                try mat_rhs_mcv.address().offset(8).deref().mem(self, .qword),
                            );
                        } else for (
                            [_]Mir.Inst.Tag{ .add, .adc },
                            tmp_regs,
                            mat_rhs_mcv.register_pair,
                        ) |op, tmp_reg, rhs_reg|
                            try self.asmRegisterRegister(.{ ._, op }, tmp_reg, rhs_reg);
                        try self.asmRegisterRegister(.{ ._, .@"test" }, dst_regs[1], dst_regs[1]);
                        for (dst_regs, tmp_regs) |dst_reg, tmp_reg|
                            try self.asmCmovccRegisterRegister(.s, dst_reg, tmp_reg);
                        break :result call_mcv;
                    },
                    else => call_mcv,
                } else call_mcv;
            },
        };

        try self.spillEflagsIfOccupied();
        try self.spillRegisters(&.{ .rax, .rcx, .rdx });
        const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rax, .rcx, .rdx });
        defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

        const lhs_mcv = try self.resolveInst(bin_op.lhs);
        const rhs_mcv = try self.resolveInst(bin_op.rhs);
        break :result try self.genMulDivBinOp(tag, inst, dst_ty, src_ty, lhs_mcv, rhs_mcv);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ty = self.typeOf(bin_op.lhs);
    if (ty.zigTypeTag(zcu) == .vector or ty.abiSize(zcu) > 8) return self.fail(
        "TODO implement airAddSat for {}",
        .{ty.fmt(pt)},
    );

    const lhs_mcv = try self.resolveInst(bin_op.lhs);
    const dst_mcv = if (lhs_mcv.isRegister() and self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv))
        lhs_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, ty, lhs_mcv);
    const dst_reg = dst_mcv.register;
    const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
    defer self.register_manager.unlockReg(dst_lock);

    const rhs_mcv = try self.resolveInst(bin_op.rhs);
    const rhs_lock = switch (rhs_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    const limit_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const limit_mcv = MCValue{ .register = limit_reg };
    const limit_lock = self.register_manager.lockRegAssumeUnused(limit_reg);
    defer self.register_manager.unlockReg(limit_lock);

    const reg_bits = self.regBitSize(ty);
    const reg_extra_bits = self.regExtraBits(ty);
    const cc: Condition = if (ty.isSignedInt(zcu)) cc: {
        if (reg_extra_bits > 0) {
            try self.genShiftBinOpMir(
                .{ ._l, .sa },
                ty,
                dst_mcv,
                Type.u8,
                .{ .immediate = reg_extra_bits },
            );
        }
        try self.genSetReg(limit_reg, ty, dst_mcv, .{});
        try self.genShiftBinOpMir(
            .{ ._r, .sa },
            ty,
            limit_mcv,
            Type.u8,
            .{ .immediate = reg_bits - 1 },
        );
        try self.genBinOpMir(.{ ._, .xor }, ty, limit_mcv, .{
            .immediate = (@as(u64, 1) << @intCast(reg_bits - 1)) - 1,
        });
        if (reg_extra_bits > 0) {
            const shifted_rhs_reg = try self.copyToTmpRegister(ty, rhs_mcv);
            const shifted_rhs_mcv = MCValue{ .register = shifted_rhs_reg };
            const shifted_rhs_lock = self.register_manager.lockRegAssumeUnused(shifted_rhs_reg);
            defer self.register_manager.unlockReg(shifted_rhs_lock);

            try self.genShiftBinOpMir(
                .{ ._l, .sa },
                ty,
                shifted_rhs_mcv,
                Type.u8,
                .{ .immediate = reg_extra_bits },
            );
            try self.genBinOpMir(.{ ._, .add }, ty, dst_mcv, shifted_rhs_mcv);
        } else try self.genBinOpMir(.{ ._, .add }, ty, dst_mcv, rhs_mcv);
        break :cc .o;
    } else cc: {
        try self.genSetReg(limit_reg, ty, .{
            .immediate = @as(u64, math.maxInt(u64)) >> @intCast(64 - ty.bitSize(zcu)),
        }, .{});

        try self.genBinOpMir(.{ ._, .add }, ty, dst_mcv, rhs_mcv);
        if (reg_extra_bits > 0) {
            try self.genBinOpMir(.{ ._, .cmp }, ty, dst_mcv, limit_mcv);
            break :cc .a;
        }
        break :cc .c;
    };

    const cmov_abi_size = @max(@as(u32, @intCast(ty.abiSize(zcu))), 2);
    try self.asmCmovccRegisterRegister(
        cc,
        registerAlias(dst_reg, cmov_abi_size),
        registerAlias(limit_reg, cmov_abi_size),
    );

    if (reg_extra_bits > 0 and ty.isSignedInt(zcu)) try self.genShiftBinOpMir(
        .{ ._r, .sa },
        ty,
        dst_mcv,
        Type.u8,
        .{ .immediate = reg_extra_bits },
    );

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ty = self.typeOf(bin_op.lhs);
    if (ty.zigTypeTag(zcu) == .vector or ty.abiSize(zcu) > 8) return self.fail(
        "TODO implement airSubSat for {}",
        .{ty.fmt(pt)},
    );

    const lhs_mcv = try self.resolveInst(bin_op.lhs);
    const dst_mcv = if (lhs_mcv.isRegister() and self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv))
        lhs_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, ty, lhs_mcv);
    const dst_reg = dst_mcv.register;
    const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
    defer self.register_manager.unlockReg(dst_lock);

    const rhs_mcv = try self.resolveInst(bin_op.rhs);
    const rhs_lock = switch (rhs_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    const limit_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const limit_mcv = MCValue{ .register = limit_reg };
    const limit_lock = self.register_manager.lockRegAssumeUnused(limit_reg);
    defer self.register_manager.unlockReg(limit_lock);

    const reg_bits = self.regBitSize(ty);
    const reg_extra_bits = self.regExtraBits(ty);
    const cc: Condition = if (ty.isSignedInt(zcu)) cc: {
        if (reg_extra_bits > 0) {
            try self.genShiftBinOpMir(
                .{ ._l, .sa },
                ty,
                dst_mcv,
                Type.u8,
                .{ .immediate = reg_extra_bits },
            );
        }
        try self.genSetReg(limit_reg, ty, dst_mcv, .{});
        try self.genShiftBinOpMir(
            .{ ._r, .sa },
            ty,
            limit_mcv,
            Type.u8,
            .{ .immediate = reg_bits - 1 },
        );
        try self.genBinOpMir(.{ ._, .xor }, ty, limit_mcv, .{
            .immediate = (@as(u64, 1) << @intCast(reg_bits - 1)) - 1,
        });
        if (reg_extra_bits > 0) {
            const shifted_rhs_reg = try self.copyToTmpRegister(ty, rhs_mcv);
            const shifted_rhs_mcv = MCValue{ .register = shifted_rhs_reg };
            const shifted_rhs_lock = self.register_manager.lockRegAssumeUnused(shifted_rhs_reg);
            defer self.register_manager.unlockReg(shifted_rhs_lock);

            try self.genShiftBinOpMir(
                .{ ._l, .sa },
                ty,
                shifted_rhs_mcv,
                Type.u8,
                .{ .immediate = reg_extra_bits },
            );
            try self.genBinOpMir(.{ ._, .sub }, ty, dst_mcv, shifted_rhs_mcv);
        } else try self.genBinOpMir(.{ ._, .sub }, ty, dst_mcv, rhs_mcv);
        break :cc .o;
    } else cc: {
        try self.genSetReg(limit_reg, ty, .{ .immediate = 0 }, .{});
        try self.genBinOpMir(.{ ._, .sub }, ty, dst_mcv, rhs_mcv);
        break :cc .c;
    };

    const cmov_abi_size = @max(@as(u32, @intCast(ty.abiSize(zcu))), 2);
    try self.asmCmovccRegisterRegister(
        cc,
        registerAlias(dst_reg, cmov_abi_size),
        registerAlias(limit_reg, cmov_abi_size),
    );

    if (reg_extra_bits > 0 and ty.isSignedInt(zcu)) try self.genShiftBinOpMir(
        .{ ._r, .sa },
        ty,
        dst_mcv,
        Type.u8,
        .{ .immediate = reg_extra_bits },
    );

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ty = self.typeOf(bin_op.lhs);

    const result = result: {
        if (ty.toIntern() == .i128_type) {
            const ptr_c_int = try pt.singleMutPtrType(Type.c_int);
            const overflow = try self.allocTempRegOrMem(Type.c_int, false);

            const dst_mcv = try self.genCall(.{ .lib = .{
                .return_type = .i128_type,
                .param_types = &.{ .i128_type, .i128_type, ptr_c_int.toIntern() },
                .callee = "__muloti4",
            } }, &.{ Type.i128, Type.i128, ptr_c_int }, &.{
                .{ .air_ref = bin_op.lhs },
                .{ .air_ref = bin_op.rhs },
                overflow.address(),
            });
            const dst_locks = self.register_manager.lockRegsAssumeUnused(2, dst_mcv.register_pair);
            defer for (dst_locks) |lock| self.register_manager.unlockReg(lock);

            const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            const lhs_mcv = try self.resolveInst(bin_op.lhs);
            const mat_lhs_mcv = switch (lhs_mcv) {
                .load_symbol => mat_lhs_mcv: {
                    // TODO clean this up!
                    const addr_reg = try self.copyToTmpRegister(Type.usize, lhs_mcv.address());
                    break :mat_lhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
                },
                else => lhs_mcv,
            };
            const mat_lhs_lock = switch (mat_lhs_mcv) {
                .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
                else => null,
            };
            defer if (mat_lhs_lock) |lock| self.register_manager.unlockReg(lock);
            if (mat_lhs_mcv.isMemory()) try self.asmRegisterMemory(
                .{ ._, .mov },
                tmp_reg,
                try mat_lhs_mcv.address().offset(8).deref().mem(self, .qword),
            ) else try self.asmRegisterRegister(
                .{ ._, .mov },
                tmp_reg,
                mat_lhs_mcv.register_pair[1],
            );

            const rhs_mcv = try self.resolveInst(bin_op.rhs);
            const mat_rhs_mcv = switch (rhs_mcv) {
                .load_symbol => mat_rhs_mcv: {
                    // TODO clean this up!
                    const addr_reg = try self.copyToTmpRegister(Type.usize, rhs_mcv.address());
                    break :mat_rhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
                },
                else => rhs_mcv,
            };
            const mat_rhs_lock = switch (mat_rhs_mcv) {
                .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
                else => null,
            };
            defer if (mat_rhs_lock) |lock| self.register_manager.unlockReg(lock);
            if (mat_rhs_mcv.isMemory()) try self.asmRegisterMemory(
                .{ ._, .xor },
                tmp_reg,
                try mat_rhs_mcv.address().offset(8).deref().mem(self, .qword),
            ) else try self.asmRegisterRegister(
                .{ ._, .xor },
                tmp_reg,
                mat_rhs_mcv.register_pair[1],
            );

            try self.asmRegisterImmediate(.{ ._r, .sa }, tmp_reg, Immediate.u(63));
            try self.asmRegister(.{ ._, .not }, tmp_reg);
            try self.asmMemoryImmediate(.{ ._, .cmp }, try overflow.mem(self, .dword), Immediate.s(0));
            try self.freeValue(overflow);
            try self.asmCmovccRegisterRegister(.ne, dst_mcv.register_pair[0], tmp_reg);
            try self.asmRegisterImmediate(.{ ._c, .bt }, tmp_reg, Immediate.u(63));
            try self.asmCmovccRegisterRegister(.ne, dst_mcv.register_pair[1], tmp_reg);
            break :result dst_mcv;
        }

        if (ty.zigTypeTag(zcu) == .vector or ty.abiSize(zcu) > 8) return self.fail(
            "TODO implement airMulSat for {}",
            .{ty.fmt(pt)},
        );

        try self.spillRegisters(&.{ .rax, .rcx, .rdx });
        const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rax, .rcx, .rdx });
        defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

        const lhs_mcv = try self.resolveInst(bin_op.lhs);
        const lhs_lock = switch (lhs_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const rhs_mcv = try self.resolveInst(bin_op.rhs);
        const rhs_lock = switch (rhs_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const limit_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
        const limit_mcv = MCValue{ .register = limit_reg };
        const limit_lock = self.register_manager.lockRegAssumeUnused(limit_reg);
        defer self.register_manager.unlockReg(limit_lock);

        const reg_bits = self.regBitSize(ty);
        const cc: Condition = if (ty.isSignedInt(zcu)) cc: {
            try self.genSetReg(limit_reg, ty, lhs_mcv, .{});
            try self.genBinOpMir(.{ ._, .xor }, ty, limit_mcv, rhs_mcv);
            try self.genShiftBinOpMir(
                .{ ._r, .sa },
                ty,
                limit_mcv,
                Type.u8,
                .{ .immediate = reg_bits - 1 },
            );
            try self.genBinOpMir(.{ ._, .xor }, ty, limit_mcv, .{
                .immediate = (@as(u64, 1) << @intCast(reg_bits - 1)) - 1,
            });
            break :cc .o;
        } else cc: {
            try self.genSetReg(limit_reg, ty, .{
                .immediate = @as(u64, math.maxInt(u64)) >> @intCast(64 - reg_bits),
            }, .{});
            break :cc .c;
        };

        const dst_mcv = try self.genMulDivBinOp(.mul, inst, ty, ty, lhs_mcv, rhs_mcv);
        const cmov_abi_size = @max(@as(u32, @intCast(ty.abiSize(zcu))), 2);
        try self.asmCmovccRegisterRegister(
            cc,
            registerAlias(dst_mcv.register, cmov_abi_size),
            registerAlias(limit_reg, cmov_abi_size),
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSubWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = result: {
        const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
        const ty = self.typeOf(bin_op.lhs);
        switch (ty.zigTypeTag(zcu)) {
            .vector => return self.fail("TODO implement add/sub with overflow for Vector type", .{}),
            .int => {
                try self.spillEflagsIfOccupied();
                try self.spillRegisters(&.{ .rcx, .rdi, .rsi });
                const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rcx, .rdi, .rsi });
                defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

                const partial_mcv = try self.genBinOp(null, switch (tag) {
                    .add_with_overflow => .add,
                    .sub_with_overflow => .sub,
                    else => unreachable,
                }, bin_op.lhs, bin_op.rhs);
                const int_info = ty.intInfo(zcu);
                const cc: Condition = switch (int_info.signedness) {
                    .unsigned => .c,
                    .signed => .o,
                };

                const tuple_ty = self.typeOfIndex(inst);
                if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
                    switch (partial_mcv) {
                        .register => |reg| {
                            self.eflags_inst = inst;
                            break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                        },
                        else => {},
                    }

                    const frame_index =
                        try self.allocFrameIndex(FrameAlloc.initSpill(tuple_ty, zcu));
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(tuple_ty.structFieldOffset(1, zcu)),
                        Type.u1,
                        .{ .eflags = cc },
                        .{},
                    );
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(tuple_ty.structFieldOffset(0, zcu)),
                        ty,
                        partial_mcv,
                        .{},
                    );
                    break :result .{ .load_frame = .{ .index = frame_index } };
                }

                const frame_index =
                    try self.allocFrameIndex(FrameAlloc.initSpill(tuple_ty, zcu));
                try self.genSetFrameTruncatedOverflowCompare(tuple_ty, frame_index, partial_mcv, cc);
                break :result .{ .load_frame = .{ .index = frame_index } };
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = result: {
        const lhs_ty = self.typeOf(bin_op.lhs);
        const rhs_ty = self.typeOf(bin_op.rhs);
        switch (lhs_ty.zigTypeTag(zcu)) {
            .vector => return self.fail("TODO implement shl with overflow for Vector type", .{}),
            .int => {
                try self.spillEflagsIfOccupied();
                try self.spillRegisters(&.{ .rcx, .rdi, .rsi });
                const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rcx, .rdi, .rsi });
                defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

                const lhs = try self.resolveInst(bin_op.lhs);
                const rhs = try self.resolveInst(bin_op.rhs);

                const int_info = lhs_ty.intInfo(zcu);

                const partial_mcv = try self.genShiftBinOp(.shl, null, lhs, rhs, lhs_ty, rhs_ty);
                const partial_lock = switch (partial_mcv) {
                    .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                    else => null,
                };
                defer if (partial_lock) |lock| self.register_manager.unlockReg(lock);

                const tmp_mcv = try self.genShiftBinOp(.shr, null, partial_mcv, rhs, lhs_ty, rhs_ty);
                const tmp_lock = switch (tmp_mcv) {
                    .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                    else => null,
                };
                defer if (tmp_lock) |lock| self.register_manager.unlockReg(lock);

                try self.genBinOpMir(.{ ._, .cmp }, lhs_ty, tmp_mcv, lhs);
                const cc = Condition.ne;

                const tuple_ty = self.typeOfIndex(inst);
                if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
                    switch (partial_mcv) {
                        .register => |reg| {
                            self.eflags_inst = inst;
                            break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                        },
                        else => {},
                    }

                    const frame_index =
                        try self.allocFrameIndex(FrameAlloc.initSpill(tuple_ty, zcu));
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(tuple_ty.structFieldOffset(1, zcu)),
                        tuple_ty.fieldType(1, zcu),
                        .{ .eflags = cc },
                        .{},
                    );
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(tuple_ty.structFieldOffset(0, zcu)),
                        tuple_ty.fieldType(0, zcu),
                        partial_mcv,
                        .{},
                    );
                    break :result .{ .load_frame = .{ .index = frame_index } };
                }

                const frame_index =
                    try self.allocFrameIndex(FrameAlloc.initSpill(tuple_ty, zcu));
                try self.genSetFrameTruncatedOverflowCompare(tuple_ty, frame_index, partial_mcv, cc);
                break :result .{ .load_frame = .{ .index = frame_index } };
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn genSetFrameTruncatedOverflowCompare(
    self: *Self,
    tuple_ty: Type,
    frame_index: FrameIndex,
    src_mcv: MCValue,
    overflow_cc: ?Condition,
) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const src_lock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    const ty = tuple_ty.fieldType(0, zcu);
    const int_info = ty.intInfo(zcu);

    const hi_bits = (int_info.bits - 1) % 64 + 1;
    const hi_ty = try pt.intType(int_info.signedness, hi_bits);

    const limb_bits: u16 = @intCast(if (int_info.bits <= 64) self.regBitSize(ty) else 64);
    const limb_ty = try pt.intType(int_info.signedness, limb_bits);

    const rest_ty = try pt.intType(.unsigned, int_info.bits - hi_bits);

    const temp_regs =
        try self.register_manager.allocRegs(3, .{null} ** 3, abi.RegisterClass.gp);
    const temp_locks = self.register_manager.lockRegsAssumeUnused(3, temp_regs);
    defer for (temp_locks) |lock| self.register_manager.unlockReg(lock);

    const overflow_reg = temp_regs[0];
    if (overflow_cc) |cc| try self.asmSetccRegister(cc, overflow_reg.to8());

    const scratch_reg = temp_regs[1];
    const hi_limb_off = if (int_info.bits <= 64) 0 else (int_info.bits - 1) / 64 * 8;
    const hi_limb_mcv = if (hi_limb_off > 0)
        src_mcv.address().offset(int_info.bits / 64 * 8).deref()
    else
        src_mcv;
    try self.genSetReg(scratch_reg, limb_ty, hi_limb_mcv, .{});
    try self.truncateRegister(hi_ty, scratch_reg);
    try self.genBinOpMir(.{ ._, .cmp }, limb_ty, .{ .register = scratch_reg }, hi_limb_mcv);

    const eq_reg = temp_regs[2];
    if (overflow_cc) |_| {
        try self.asmSetccRegister(.ne, eq_reg.to8());
        try self.genBinOpMir(
            .{ ._, .@"or" },
            Type.u8,
            .{ .register = overflow_reg },
            .{ .register = eq_reg },
        );
    }

    const payload_off: i32 = @intCast(tuple_ty.structFieldOffset(0, zcu));
    if (hi_limb_off > 0) try self.genSetMem(
        .{ .frame = frame_index },
        payload_off,
        rest_ty,
        src_mcv,
        .{},
    );
    try self.genSetMem(
        .{ .frame = frame_index },
        payload_off + hi_limb_off,
        limb_ty,
        .{ .register = scratch_reg },
        .{},
    );
    try self.genSetMem(
        .{ .frame = frame_index },
        @intCast(tuple_ty.structFieldOffset(1, zcu)),
        tuple_ty.fieldType(1, zcu),
        if (overflow_cc) |_| .{ .register = overflow_reg.to8() } else .{ .eflags = .ne },
        .{},
    );
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const tuple_ty = self.typeOfIndex(inst);
    const dst_ty = self.typeOf(bin_op.lhs);
    const result: MCValue = switch (dst_ty.zigTypeTag(zcu)) {
        .vector => return self.fail("TODO implement airMulWithOverflow for {}", .{dst_ty.fmt(pt)}),
        .int => result: {
            const dst_info = dst_ty.intInfo(zcu);
            if (dst_info.bits > 128 and dst_info.signedness == .unsigned) {
                const slow_inc = self.hasFeature(.slow_incdec);
                const abi_size: u32 = @intCast(dst_ty.abiSize(zcu));
                const limb_len = math.divCeil(u32, abi_size, 8) catch unreachable;

                try self.spillRegisters(&.{ .rax, .rcx, .rdx });
                const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rax, .rcx, .rdx });
                defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

                const dst_mcv = try self.allocRegOrMem(inst, false);
                try self.genInlineMemset(
                    dst_mcv.address(),
                    .{ .immediate = 0 },
                    .{ .immediate = tuple_ty.abiSize(zcu) },
                    .{},
                );
                const lhs_mcv = try self.resolveInst(bin_op.lhs);
                const rhs_mcv = try self.resolveInst(bin_op.rhs);

                const temp_regs =
                    try self.register_manager.allocRegs(4, .{null} ** 4, abi.RegisterClass.gp);
                const temp_locks = self.register_manager.lockRegsAssumeUnused(4, temp_regs);
                defer for (temp_locks) |lock| self.register_manager.unlockReg(lock);

                try self.asmRegisterRegister(.{ ._, .xor }, temp_regs[0].to32(), temp_regs[0].to32());

                const outer_loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                try self.asmRegisterMemory(.{ ._, .mov }, temp_regs[1].to64(), .{
                    .base = .{ .frame = rhs_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[0].to64(),
                        .scale = .@"8",
                        .disp = rhs_mcv.load_frame.off,
                    } },
                });
                try self.asmRegisterRegister(.{ ._, .@"test" }, temp_regs[1].to64(), temp_regs[1].to64());
                const skip_inner = try self.asmJccReloc(.z, undefined);

                try self.asmRegisterRegister(.{ ._, .xor }, temp_regs[2].to32(), temp_regs[2].to32());
                try self.asmRegisterRegister(.{ ._, .mov }, temp_regs[3].to32(), temp_regs[0].to32());
                try self.asmRegisterRegister(.{ ._, .xor }, .ecx, .ecx);
                try self.asmRegisterRegister(.{ ._, .xor }, .edx, .edx);

                const inner_loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                try self.asmRegisterImmediate(.{ ._r, .sh }, .cl, Immediate.u(1));
                try self.asmMemoryRegister(.{ ._, .adc }, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[3].to64(),
                        .scale = .@"8",
                        .disp = dst_mcv.load_frame.off +
                            @as(i32, @intCast(tuple_ty.structFieldOffset(0, zcu))),
                    } },
                }, .rdx);
                try self.asmSetccRegister(.c, .cl);

                try self.asmRegisterMemory(.{ ._, .mov }, .rax, .{
                    .base = .{ .frame = lhs_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[2].to64(),
                        .scale = .@"8",
                        .disp = lhs_mcv.load_frame.off,
                    } },
                });
                try self.asmRegister(.{ ._, .mul }, temp_regs[1].to64());

                try self.asmRegisterImmediate(.{ ._r, .sh }, .ch, Immediate.u(1));
                try self.asmMemoryRegister(.{ ._, .adc }, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[3].to64(),
                        .scale = .@"8",
                        .disp = dst_mcv.load_frame.off +
                            @as(i32, @intCast(tuple_ty.structFieldOffset(0, zcu))),
                    } },
                }, .rax);
                try self.asmSetccRegister(.c, .ch);

                if (slow_inc) {
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[2].to32(), Immediate.u(1));
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[3].to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, temp_regs[2].to32());
                    try self.asmRegister(.{ ._, .inc }, temp_regs[3].to32());
                }
                try self.asmRegisterImmediate(
                    .{ ._, .cmp },
                    temp_regs[3].to32(),
                    Immediate.u(limb_len),
                );
                _ = try self.asmJccReloc(.b, inner_loop);

                try self.asmRegisterRegister(.{ ._, .@"or" }, .rdx, .rcx);
                const overflow = try self.asmJccReloc(.nz, undefined);
                const overflow_loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                try self.asmRegisterImmediate(
                    .{ ._, .cmp },
                    temp_regs[2].to32(),
                    Immediate.u(limb_len),
                );
                const no_overflow = try self.asmJccReloc(.nb, undefined);
                if (slow_inc) {
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[2].to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, temp_regs[2].to32());
                }
                try self.asmMemoryImmediate(.{ ._, .cmp }, .{
                    .base = .{ .frame = lhs_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[2].to64(),
                        .scale = .@"8",
                        .disp = lhs_mcv.load_frame.off - 8,
                    } },
                }, Immediate.u(0));
                _ = try self.asmJccReloc(.z, overflow_loop);
                self.performReloc(overflow);
                try self.asmMemoryImmediate(.{ ._, .mov }, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .byte,
                        .disp = dst_mcv.load_frame.off +
                            @as(i32, @intCast(tuple_ty.structFieldOffset(1, zcu))),
                    } },
                }, Immediate.u(1));
                self.performReloc(no_overflow);

                self.performReloc(skip_inner);
                if (slow_inc) {
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[0].to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, temp_regs[0].to32());
                }
                try self.asmRegisterImmediate(
                    .{ ._, .cmp },
                    temp_regs[0].to32(),
                    Immediate.u(limb_len),
                );
                _ = try self.asmJccReloc(.b, outer_loop);

                break :result dst_mcv;
            }

            const lhs_active_bits = self.activeIntBits(bin_op.lhs);
            const rhs_active_bits = self.activeIntBits(bin_op.rhs);
            const src_bits = @max(lhs_active_bits, rhs_active_bits, dst_info.bits / 2);
            const src_ty = try pt.intType(dst_info.signedness, src_bits);
            if (src_bits > 64 and src_bits <= 128 and
                dst_info.bits > 64 and dst_info.bits <= 128) switch (dst_info.signedness) {
                .signed => {
                    const ptr_c_int = try pt.singleMutPtrType(Type.c_int);
                    const overflow = try self.allocTempRegOrMem(Type.c_int, false);
                    const result = try self.genCall(.{ .lib = .{
                        .return_type = .i128_type,
                        .param_types = &.{ .i128_type, .i128_type, ptr_c_int.toIntern() },
                        .callee = "__muloti4",
                    } }, &.{ Type.i128, Type.i128, ptr_c_int }, &.{
                        .{ .air_ref = bin_op.lhs },
                        .{ .air_ref = bin_op.rhs },
                        overflow.address(),
                    });

                    const dst_mcv = try self.allocRegOrMem(inst, false);
                    try self.genSetMem(
                        .{ .frame = dst_mcv.load_frame.index },
                        @intCast(tuple_ty.structFieldOffset(0, zcu)),
                        tuple_ty.fieldType(0, zcu),
                        result,
                        .{},
                    );
                    try self.asmMemoryImmediate(
                        .{ ._, .cmp },
                        try overflow.mem(self, self.memSize(Type.c_int)),
                        Immediate.s(0),
                    );
                    try self.genSetMem(
                        .{ .frame = dst_mcv.load_frame.index },
                        @intCast(tuple_ty.structFieldOffset(1, zcu)),
                        tuple_ty.fieldType(1, zcu),
                        .{ .eflags = .ne },
                        .{},
                    );
                    try self.freeValue(overflow);
                    break :result dst_mcv;
                },
                .unsigned => {
                    try self.spillEflagsIfOccupied();
                    try self.spillRegisters(&.{ .rax, .rdx });
                    const reg_locks = self.register_manager.lockRegsAssumeUnused(2, .{ .rax, .rdx });
                    defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

                    const tmp_regs =
                        try self.register_manager.allocRegs(4, .{null} ** 4, abi.RegisterClass.gp);
                    const tmp_locks = self.register_manager.lockRegsAssumeUnused(4, tmp_regs);
                    defer for (tmp_locks) |lock| self.register_manager.unlockReg(lock);

                    const lhs_mcv = try self.resolveInst(bin_op.lhs);
                    const rhs_mcv = try self.resolveInst(bin_op.rhs);
                    const mat_lhs_mcv = switch (lhs_mcv) {
                        .load_symbol => mat_lhs_mcv: {
                            // TODO clean this up!
                            const addr_reg = try self.copyToTmpRegister(Type.usize, lhs_mcv.address());
                            break :mat_lhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
                        },
                        else => lhs_mcv,
                    };
                    const mat_lhs_lock = switch (mat_lhs_mcv) {
                        .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
                        else => null,
                    };
                    defer if (mat_lhs_lock) |lock| self.register_manager.unlockReg(lock);
                    const mat_rhs_mcv = switch (rhs_mcv) {
                        .load_symbol => mat_rhs_mcv: {
                            // TODO clean this up!
                            const addr_reg = try self.copyToTmpRegister(Type.usize, rhs_mcv.address());
                            break :mat_rhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
                        },
                        else => rhs_mcv,
                    };
                    const mat_rhs_lock = switch (mat_rhs_mcv) {
                        .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
                        else => null,
                    };
                    defer if (mat_rhs_lock) |lock| self.register_manager.unlockReg(lock);

                    if (mat_lhs_mcv.isMemory()) try self.asmRegisterMemory(
                        .{ ._, .mov },
                        .rax,
                        try mat_lhs_mcv.mem(self, .qword),
                    ) else try self.asmRegisterRegister(
                        .{ ._, .mov },
                        .rax,
                        mat_lhs_mcv.register_pair[0],
                    );
                    if (mat_rhs_mcv.isMemory()) try self.asmRegisterMemory(
                        .{ ._, .mov },
                        tmp_regs[0],
                        try mat_rhs_mcv.address().offset(8).deref().mem(self, .qword),
                    ) else try self.asmRegisterRegister(
                        .{ ._, .mov },
                        tmp_regs[0],
                        mat_rhs_mcv.register_pair[1],
                    );
                    try self.asmRegisterRegister(.{ ._, .@"test" }, tmp_regs[0], tmp_regs[0]);
                    try self.asmSetccRegister(.nz, tmp_regs[1].to8());
                    try self.asmRegisterRegister(.{ .i_, .mul }, tmp_regs[0], .rax);
                    try self.asmSetccRegister(.o, tmp_regs[2].to8());
                    if (mat_rhs_mcv.isMemory())
                        try self.asmMemory(.{ ._, .mul }, try mat_rhs_mcv.mem(self, .qword))
                    else
                        try self.asmRegister(.{ ._, .mul }, mat_rhs_mcv.register_pair[0]);
                    try self.asmRegisterRegister(.{ ._, .add }, .rdx, tmp_regs[0]);
                    try self.asmSetccRegister(.c, tmp_regs[3].to8());
                    try self.asmRegisterRegister(.{ ._, .@"or" }, tmp_regs[2].to8(), tmp_regs[3].to8());
                    if (mat_lhs_mcv.isMemory()) try self.asmRegisterMemory(
                        .{ ._, .mov },
                        tmp_regs[0],
                        try mat_lhs_mcv.address().offset(8).deref().mem(self, .qword),
                    ) else try self.asmRegisterRegister(
                        .{ ._, .mov },
                        tmp_regs[0],
                        mat_lhs_mcv.register_pair[1],
                    );
                    try self.asmRegisterRegister(.{ ._, .@"test" }, tmp_regs[0], tmp_regs[0]);
                    try self.asmSetccRegister(.nz, tmp_regs[3].to8());
                    try self.asmRegisterRegister(
                        .{ ._, .@"and" },
                        tmp_regs[1].to8(),
                        tmp_regs[3].to8(),
                    );
                    try self.asmRegisterRegister(.{ ._, .@"or" }, tmp_regs[1].to8(), tmp_regs[2].to8());
                    if (mat_rhs_mcv.isMemory()) try self.asmRegisterMemory(
                        .{ .i_, .mul },
                        tmp_regs[0],
                        try mat_rhs_mcv.mem(self, .qword),
                    ) else try self.asmRegisterRegister(
                        .{ .i_, .mul },
                        tmp_regs[0],
                        mat_rhs_mcv.register_pair[0],
                    );
                    try self.asmSetccRegister(.o, tmp_regs[2].to8());
                    try self.asmRegisterRegister(.{ ._, .@"or" }, tmp_regs[1].to8(), tmp_regs[2].to8());
                    try self.asmRegisterRegister(.{ ._, .add }, .rdx, tmp_regs[0]);
                    try self.asmSetccRegister(.c, tmp_regs[2].to8());
                    try self.asmRegisterRegister(.{ ._, .@"or" }, tmp_regs[1].to8(), tmp_regs[2].to8());

                    const dst_mcv = try self.allocRegOrMem(inst, false);
                    try self.genSetMem(
                        .{ .frame = dst_mcv.load_frame.index },
                        @intCast(tuple_ty.structFieldOffset(0, zcu)),
                        tuple_ty.fieldType(0, zcu),
                        .{ .register_pair = .{ .rax, .rdx } },
                        .{},
                    );
                    try self.genSetMem(
                        .{ .frame = dst_mcv.load_frame.index },
                        @intCast(tuple_ty.structFieldOffset(1, zcu)),
                        tuple_ty.fieldType(1, zcu),
                        .{ .register = tmp_regs[1] },
                        .{},
                    );
                    break :result dst_mcv;
                },
            };

            try self.spillEflagsIfOccupied();
            try self.spillRegisters(&.{ .rax, .rcx, .rdx, .rdi, .rsi });
            const reg_locks = self.register_manager.lockRegsAssumeUnused(5, .{ .rax, .rcx, .rdx, .rdi, .rsi });
            defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

            const cc: Condition = switch (dst_info.signedness) {
                .unsigned => .c,
                .signed => .o,
            };

            const lhs = try self.resolveInst(bin_op.lhs);
            const rhs = try self.resolveInst(bin_op.rhs);

            const extra_bits = if (dst_info.bits <= 64)
                self.regExtraBits(dst_ty)
            else
                dst_info.bits % 64;
            const partial_mcv = try self.genMulDivBinOp(.mul, null, dst_ty, src_ty, lhs, rhs);

            switch (partial_mcv) {
                .register => |reg| if (extra_bits == 0) {
                    self.eflags_inst = inst;
                    break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                } else {
                    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(tuple_ty, zcu));
                    try self.genSetFrameTruncatedOverflowCompare(tuple_ty, frame_index, partial_mcv, cc);
                    break :result .{ .load_frame = .{ .index = frame_index } };
                },
                else => {
                    // For now, this is the only supported multiply that doesn't fit in a register.
                    if (dst_info.bits > 128 or src_bits != 64)
                        return self.fail("TODO implement airWithOverflow from {} to {}", .{
                            src_ty.fmt(pt), dst_ty.fmt(pt),
                        });

                    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(tuple_ty, zcu));
                    if (dst_info.bits >= lhs_active_bits + rhs_active_bits) {
                        try self.genSetMem(
                            .{ .frame = frame_index },
                            @intCast(tuple_ty.structFieldOffset(0, zcu)),
                            tuple_ty.fieldType(0, zcu),
                            partial_mcv,
                            .{},
                        );
                        try self.genSetMem(
                            .{ .frame = frame_index },
                            @intCast(tuple_ty.structFieldOffset(1, zcu)),
                            tuple_ty.fieldType(1, zcu),
                            .{ .immediate = 0 }, // cc being set is impossible
                            .{},
                        );
                    } else try self.genSetFrameTruncatedOverflowCompare(
                        tuple_ty,
                        frame_index,
                        partial_mcv,
                        null,
                    );
                    break :result .{ .load_frame = .{ .index = frame_index } };
                },
            }
        },
        else => unreachable,
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

/// Generates signed or unsigned integer multiplication/division.
/// Clobbers .rax and .rdx registers.
/// Quotient is saved in .rax and remainder in .rdx.
fn genIntMulDivOpMir(self: *Self, tag: Mir.Inst.FixedTag, ty: Type, lhs: MCValue, rhs: MCValue) !void {
    const pt = self.pt;
    const abi_size: u32 = @intCast(ty.abiSize(pt.zcu));
    const bit_size: u32 = @intCast(self.regBitSize(ty));
    if (abi_size > 8) {
        return self.fail("TODO implement genIntMulDivOpMir for ABI size larger than 8", .{});
    }

    try self.genSetReg(.rax, ty, lhs, .{});
    switch (tag[1]) {
        else => unreachable,
        .mul => {},
        .div => switch (tag[0]) {
            ._ => {
                const hi_reg: Register =
                    switch (bit_size) {
                    8 => .ah,
                    16, 32, 64 => .edx,
                    else => unreachable,
                };
                try self.asmRegisterRegister(.{ ._, .xor }, hi_reg, hi_reg);
            },
            .i_ => try self.asmOpOnly(.{ ._, switch (bit_size) {
                8 => .cbw,
                16 => .cwd,
                32 => .cdq,
                64 => .cqo,
                else => unreachable,
            } }),
            else => unreachable,
        },
    }

    const mat_rhs: MCValue = switch (rhs) {
        .register, .indirect, .load_frame => rhs,
        else => .{ .register = try self.copyToTmpRegister(ty, rhs) },
    };
    switch (mat_rhs) {
        .register => |reg| try self.asmRegister(tag, registerAlias(reg, abi_size)),
        .memory, .indirect, .load_frame => try self.asmMemory(
            tag,
            try mat_rhs.mem(self, Memory.Size.fromSize(abi_size)),
        ),
        else => unreachable,
    }
    if (tag[1] == .div and bit_size == 8) try self.asmRegisterRegister(.{ ._, .mov }, .dl, .ah);
}

/// Always returns a register.
/// Clobbers .rax and .rdx registers.
fn genInlineIntDivFloor(self: *Self, ty: Type, lhs: MCValue, rhs: MCValue) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size: u32 = @intCast(ty.abiSize(zcu));
    const int_info = ty.intInfo(zcu);
    const dividend = switch (lhs) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ty, lhs),
    };
    const dividend_lock = self.register_manager.lockReg(dividend);
    defer if (dividend_lock) |lock| self.register_manager.unlockReg(lock);

    const divisor = switch (rhs) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ty, rhs),
    };
    const divisor_lock = self.register_manager.lockReg(divisor);
    defer if (divisor_lock) |lock| self.register_manager.unlockReg(lock);

    try self.genIntMulDivOpMir(
        switch (int_info.signedness) {
            .signed => .{ .i_, .div },
            .unsigned => .{ ._, .div },
        },
        ty,
        .{ .register = dividend },
        .{ .register = divisor },
    );

    try self.asmRegisterRegister(
        .{ ._, .xor },
        registerAlias(divisor, abi_size),
        registerAlias(dividend, abi_size),
    );
    try self.asmRegisterImmediate(
        .{ ._r, .sa },
        registerAlias(divisor, abi_size),
        Immediate.u(int_info.bits - 1),
    );
    try self.asmRegisterRegister(
        .{ ._, .@"test" },
        registerAlias(.rdx, abi_size),
        registerAlias(.rdx, abi_size),
    );
    try self.asmCmovccRegisterRegister(
        .z,
        registerAlias(divisor, @max(abi_size, 2)),
        registerAlias(.rdx, @max(abi_size, 2)),
    );
    try self.genBinOpMir(.{ ._, .add }, ty, .{ .register = divisor }, .{ .register = .rax });
    return MCValue{ .register = divisor };
}

fn airShlShrBinOp(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const air_tags = self.air.instructions.items(.tag);
    const tag = air_tags[@intFromEnum(inst)];
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);
    const result: MCValue = result: {
        switch (lhs_ty.zigTypeTag(zcu)) {
            .int => {
                try self.spillRegisters(&.{.rcx});
                try self.register_manager.getKnownReg(.rcx, null);
                const lhs_mcv = try self.resolveInst(bin_op.lhs);
                const rhs_mcv = try self.resolveInst(bin_op.rhs);

                const dst_mcv = try self.genShiftBinOp(tag, inst, lhs_mcv, rhs_mcv, lhs_ty, rhs_ty);
                switch (tag) {
                    .shr, .shr_exact, .shl_exact => {},
                    .shl => switch (dst_mcv) {
                        .register => |dst_reg| try self.truncateRegister(lhs_ty, dst_reg),
                        .register_pair => |dst_regs| try self.truncateRegister(lhs_ty, dst_regs[1]),
                        .load_frame => |frame_addr| {
                            const tmp_reg =
                                try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                            defer self.register_manager.unlockReg(tmp_lock);

                            const lhs_bits: u31 = @intCast(lhs_ty.bitSize(zcu));
                            const tmp_ty = if (lhs_bits > 64) Type.usize else lhs_ty;
                            const off = frame_addr.off + (lhs_bits - 1) / 64 * 8;
                            try self.genSetReg(
                                tmp_reg,
                                tmp_ty,
                                .{ .load_frame = .{ .index = frame_addr.index, .off = off } },
                                .{},
                            );
                            try self.truncateRegister(lhs_ty, tmp_reg);
                            try self.genSetMem(
                                .{ .frame = frame_addr.index },
                                off,
                                tmp_ty,
                                .{ .register = tmp_reg },
                                .{},
                            );
                        },
                        else => {},
                    },
                    else => unreachable,
                }
                break :result dst_mcv;
            },
            .vector => switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
                .int => if (@as(?Mir.Inst.FixedTag, switch (lhs_ty.childType(zcu).intInfo(zcu).bits) {
                    else => null,
                    16 => switch (lhs_ty.vectorLen(zcu)) {
                        else => null,
                        1...8 => switch (tag) {
                            else => unreachable,
                            .shr, .shr_exact => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                                .signed => if (self.hasFeature(.avx))
                                    .{ .vp_w, .sra }
                                else
                                    .{ .p_w, .sra },
                                .unsigned => if (self.hasFeature(.avx))
                                    .{ .vp_w, .srl }
                                else
                                    .{ .p_w, .srl },
                            },
                            .shl, .shl_exact => if (self.hasFeature(.avx))
                                .{ .vp_w, .sll }
                            else
                                .{ .p_w, .sll },
                        },
                        9...16 => switch (tag) {
                            else => unreachable,
                            .shr, .shr_exact => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                                .signed => if (self.hasFeature(.avx2)) .{ .vp_w, .sra } else null,
                                .unsigned => if (self.hasFeature(.avx2)) .{ .vp_w, .srl } else null,
                            },
                            .shl, .shl_exact => if (self.hasFeature(.avx2)) .{ .vp_w, .sll } else null,
                        },
                    },
                    32 => switch (lhs_ty.vectorLen(zcu)) {
                        else => null,
                        1...4 => switch (tag) {
                            else => unreachable,
                            .shr, .shr_exact => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                                .signed => if (self.hasFeature(.avx))
                                    .{ .vp_d, .sra }
                                else
                                    .{ .p_d, .sra },
                                .unsigned => if (self.hasFeature(.avx))
                                    .{ .vp_d, .srl }
                                else
                                    .{ .p_d, .srl },
                            },
                            .shl, .shl_exact => if (self.hasFeature(.avx))
                                .{ .vp_d, .sll }
                            else
                                .{ .p_d, .sll },
                        },
                        5...8 => switch (tag) {
                            else => unreachable,
                            .shr, .shr_exact => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                                .signed => if (self.hasFeature(.avx2)) .{ .vp_d, .sra } else null,
                                .unsigned => if (self.hasFeature(.avx2)) .{ .vp_d, .srl } else null,
                            },
                            .shl, .shl_exact => if (self.hasFeature(.avx2)) .{ .vp_d, .sll } else null,
                        },
                    },
                    64 => switch (lhs_ty.vectorLen(zcu)) {
                        else => null,
                        1...2 => switch (tag) {
                            else => unreachable,
                            .shr, .shr_exact => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                                .signed => if (self.hasFeature(.avx))
                                    .{ .vp_q, .sra }
                                else
                                    .{ .p_q, .sra },
                                .unsigned => if (self.hasFeature(.avx))
                                    .{ .vp_q, .srl }
                                else
                                    .{ .p_q, .srl },
                            },
                            .shl, .shl_exact => if (self.hasFeature(.avx))
                                .{ .vp_q, .sll }
                            else
                                .{ .p_q, .sll },
                        },
                        3...4 => switch (tag) {
                            else => unreachable,
                            .shr, .shr_exact => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                                .signed => if (self.hasFeature(.avx2)) .{ .vp_q, .sra } else null,
                                .unsigned => if (self.hasFeature(.avx2)) .{ .vp_q, .srl } else null,
                            },
                            .shl, .shl_exact => if (self.hasFeature(.avx2)) .{ .vp_q, .sll } else null,
                        },
                    },
                })) |mir_tag| if (try self.air.value(bin_op.rhs, pt)) |rhs_val| {
                    switch (zcu.intern_pool.indexToKey(rhs_val.toIntern())) {
                        .aggregate => |rhs_aggregate| switch (rhs_aggregate.storage) {
                            .repeated_elem => |rhs_elem| {
                                const abi_size: u32 = @intCast(lhs_ty.abiSize(zcu));

                                const lhs_mcv = try self.resolveInst(bin_op.lhs);
                                const dst_reg, const lhs_reg = if (lhs_mcv.isRegister() and
                                    self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv))
                                    .{lhs_mcv.getReg().?} ** 2
                                else if (lhs_mcv.isRegister() and self.hasFeature(.avx)) .{
                                    try self.register_manager.allocReg(inst, abi.RegisterClass.sse),
                                    lhs_mcv.getReg().?,
                                } else .{(try self.copyToRegisterWithInstTracking(
                                    inst,
                                    lhs_ty,
                                    lhs_mcv,
                                )).register} ** 2;
                                const reg_locks =
                                    self.register_manager.lockRegs(2, .{ dst_reg, lhs_reg });
                                defer for (reg_locks) |reg_lock| if (reg_lock) |lock|
                                    self.register_manager.unlockReg(lock);

                                const shift_imm =
                                    Immediate.u(@intCast(Value.fromInterned(rhs_elem).toUnsignedInt(zcu)));
                                if (self.hasFeature(.avx)) try self.asmRegisterRegisterImmediate(
                                    mir_tag,
                                    registerAlias(dst_reg, abi_size),
                                    registerAlias(lhs_reg, abi_size),
                                    shift_imm,
                                ) else {
                                    assert(dst_reg.id() == lhs_reg.id());
                                    try self.asmRegisterImmediate(
                                        mir_tag,
                                        registerAlias(dst_reg, abi_size),
                                        shift_imm,
                                    );
                                }
                                break :result .{ .register = dst_reg };
                            },
                            else => {},
                        },
                        else => {},
                    }
                } else if (bin_op.rhs.toIndex()) |rhs_inst| switch (air_tags[@intFromEnum(rhs_inst)]) {
                    .splat => {
                        const abi_size: u32 = @intCast(lhs_ty.abiSize(zcu));

                        const lhs_mcv = try self.resolveInst(bin_op.lhs);
                        const dst_reg, const lhs_reg = if (lhs_mcv.isRegister() and
                            self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv))
                            .{lhs_mcv.getReg().?} ** 2
                        else if (lhs_mcv.isRegister() and self.hasFeature(.avx)) .{
                            try self.register_manager.allocReg(inst, abi.RegisterClass.sse),
                            lhs_mcv.getReg().?,
                        } else .{(try self.copyToRegisterWithInstTracking(
                            inst,
                            lhs_ty,
                            lhs_mcv,
                        )).register} ** 2;
                        const reg_locks = self.register_manager.lockRegs(2, .{ dst_reg, lhs_reg });
                        defer for (reg_locks) |reg_lock| if (reg_lock) |lock|
                            self.register_manager.unlockReg(lock);

                        const shift_reg =
                            try self.copyToTmpRegister(rhs_ty, .{ .air_ref = bin_op.rhs });
                        const shift_lock = self.register_manager.lockRegAssumeUnused(shift_reg);
                        defer self.register_manager.unlockReg(shift_lock);

                        const mask_ty = try pt.vectorType(.{ .len = 16, .child = .u8_type });
                        const mask_mcv = try self.genTypedValue(Value.fromInterned(try pt.intern(.{ .aggregate = .{
                            .ty = mask_ty.toIntern(),
                            .storage = .{ .elems = &([1]InternPool.Index{
                                (try rhs_ty.childType(zcu).maxIntScalar(pt, Type.u8)).toIntern(),
                            } ++ [1]InternPool.Index{
                                (try pt.intValue(Type.u8, 0)).toIntern(),
                            } ** 15) },
                        } })));
                        const mask_addr_reg =
                            try self.copyToTmpRegister(Type.usize, mask_mcv.address());
                        const mask_addr_lock = self.register_manager.lockRegAssumeUnused(mask_addr_reg);
                        defer self.register_manager.unlockReg(mask_addr_lock);

                        if (self.hasFeature(.avx)) {
                            try self.asmRegisterRegisterMemory(
                                .{ .vp_, .@"and" },
                                shift_reg.to128(),
                                shift_reg.to128(),
                                .{
                                    .base = .{ .reg = mask_addr_reg },
                                    .mod = .{ .rm = .{ .size = .xword } },
                                },
                            );
                            try self.asmRegisterRegisterRegister(
                                mir_tag,
                                registerAlias(dst_reg, abi_size),
                                registerAlias(lhs_reg, abi_size),
                                shift_reg.to128(),
                            );
                        } else {
                            try self.asmRegisterMemory(
                                .{ .p_, .@"and" },
                                shift_reg.to128(),
                                .{
                                    .base = .{ .reg = mask_addr_reg },
                                    .mod = .{ .rm = .{ .size = .xword } },
                                },
                            );
                            assert(dst_reg.id() == lhs_reg.id());
                            try self.asmRegisterRegister(
                                mir_tag,
                                registerAlias(dst_reg, abi_size),
                                shift_reg.to128(),
                            );
                        }
                        break :result .{ .register = dst_reg };
                    },
                    else => {},
                },
                else => {},
            },
            else => {},
        }
        return self.fail("TODO implement airShlShrBinOp for {}", .{lhs_ty.fmt(pt)});
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    _ = bin_op;
    return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    //return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = result: {
        const pl_ty = self.typeOfIndex(inst);
        if (!pl_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;

        const opt_mcv = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv)) {
            const pl_mcv: MCValue = switch (opt_mcv) {
                .register_overflow => |ro| pl: {
                    self.eflags_inst = null; // actually stop tracking the overflow part
                    break :pl .{ .register = ro.reg };
                },
                else => opt_mcv,
            };
            switch (pl_mcv) {
                .register => |pl_reg| try self.truncateRegister(pl_ty, pl_reg),
                else => {},
            }
            break :result pl_mcv;
        }

        const pl_mcv = try self.allocRegOrMem(inst, true);
        try self.genCopy(pl_ty, pl_mcv, switch (opt_mcv) {
            else => opt_mcv,
            .register_overflow => |ro| .{ .register = ro.reg },
        }, .{});
        break :result pl_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const dst_ty = self.typeOfIndex(inst);
    const opt_mcv = try self.resolveInst(ty_op.operand);

    const dst_mcv = if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv))
        opt_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, dst_ty, opt_mcv);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = result: {
        const dst_ty = self.typeOfIndex(inst);
        const src_ty = self.typeOf(ty_op.operand);
        const opt_ty = src_ty.childType(zcu);
        const src_mcv = try self.resolveInst(ty_op.operand);

        if (opt_ty.optionalReprIsPayload(zcu)) {
            break :result if (self.liveness.isUnused(inst))
                .unreach
            else if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                src_mcv
            else
                try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);
        }

        const dst_mcv: MCValue = if (src_mcv.isRegister() and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else if (self.liveness.isUnused(inst))
            .{ .register = try self.copyToTmpRegister(dst_ty, src_mcv) }
        else
            try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);

        const pl_ty = dst_ty.childType(zcu);
        const pl_abi_size: i32 = @intCast(pl_ty.abiSize(zcu));
        try self.genSetMem(
            .{ .reg = dst_mcv.getReg().? },
            pl_abi_size,
            Type.bool,
            .{ .immediate = 1 },
            .{},
        );
        break :result if (self.liveness.isUnused(inst)) .unreach else dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const err_union_ty = self.typeOf(ty_op.operand);
    const err_ty = err_union_ty.errorUnionSet(zcu);
    const payload_ty = err_union_ty.errorUnionPayload(zcu);
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        if (err_ty.errorSetIsEmpty(zcu)) {
            break :result MCValue{ .immediate = 0 };
        }

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            break :result operand;
        }

        const err_off = errUnionErrorOffset(payload_ty, zcu);
        switch (operand) {
            .register => |reg| {
                // TODO reuse operand
                const eu_lock = self.register_manager.lockReg(reg);
                defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

                const result = try self.copyToRegisterWithInstTracking(inst, err_union_ty, operand);
                if (err_off > 0) try self.genShiftBinOpMir(
                    .{ ._r, .sh },
                    err_union_ty,
                    result,
                    Type.u8,
                    .{ .immediate = @as(u6, @intCast(err_off * 8)) },
                ) else try self.truncateRegister(Type.anyerror, result.register);
                break :result result;
            },
            .load_frame => |frame_addr| break :result .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + @as(i32, @intCast(err_off)),
            } },
            else => return self.fail("TODO implement unwrap_err_err for {}", .{operand}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_ty = self.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const result = try self.genUnwrapErrUnionPayloadMir(inst, operand_ty, operand);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> E
fn airUnwrapErrUnionErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const src_ty = self.typeOf(ty_op.operand);
    const src_mcv = try self.resolveInst(ty_op.operand);
    const src_reg = switch (src_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(src_ty, src_mcv),
    };
    const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
    defer self.register_manager.unlockReg(src_lock);

    const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
    const dst_mcv = MCValue{ .register = dst_reg };
    const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
    defer self.register_manager.unlockReg(dst_lock);

    const eu_ty = src_ty.childType(zcu);
    const pl_ty = eu_ty.errorUnionPayload(zcu);
    const err_ty = eu_ty.errorUnionSet(zcu);
    const err_off: i32 = @intCast(errUnionErrorOffset(pl_ty, zcu));
    const err_abi_size: u32 = @intCast(err_ty.abiSize(zcu));
    try self.asmRegisterMemory(
        .{ ._, .mov },
        registerAlias(dst_reg, err_abi_size),
        .{
            .base = .{ .reg = src_reg },
            .mod = .{ .rm = .{
                .size = Memory.Size.fromSize(err_abi_size),
                .disp = err_off,
            } },
        },
    );

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> *T
fn airUnwrapErrUnionPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_ty = self.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const result = try self.genUnwrapErrUnionPayloadPtrMir(inst, operand_ty, operand);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = result: {
        const src_ty = self.typeOf(ty_op.operand);
        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_reg = switch (src_mcv) {
            .register => |reg| reg,
            else => try self.copyToTmpRegister(src_ty, src_mcv),
        };
        const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
        defer self.register_manager.unlockReg(src_lock);

        const eu_ty = src_ty.childType(zcu);
        const pl_ty = eu_ty.errorUnionPayload(zcu);
        const err_ty = eu_ty.errorUnionSet(zcu);
        const err_off: i32 = @intCast(errUnionErrorOffset(pl_ty, zcu));
        const err_abi_size: u32 = @intCast(err_ty.abiSize(zcu));
        try self.asmMemoryImmediate(
            .{ ._, .mov },
            .{
                .base = .{ .reg = src_reg },
                .mod = .{ .rm = .{
                    .size = Memory.Size.fromSize(err_abi_size),
                    .disp = err_off,
                } },
            },
            Immediate.u(0),
        );

        if (self.liveness.isUnused(inst)) break :result .unreach;

        const dst_ty = self.typeOfIndex(inst);
        const dst_reg = if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_reg
        else
            try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const pl_off: i32 = @intCast(errUnionPayloadOffset(pl_ty, zcu));
        const dst_abi_size: u32 = @intCast(dst_ty.abiSize(zcu));
        try self.asmRegisterMemory(
            .{ ._, .lea },
            registerAlias(dst_reg, dst_abi_size),
            .{
                .base = .{ .reg = src_reg },
                .mod = .{ .rm = .{ .size = .qword, .disp = pl_off } },
            },
        );
        break :result .{ .register = dst_reg };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn genUnwrapErrUnionPayloadMir(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    err_union_ty: Type,
    err_union: MCValue,
) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const payload_ty = err_union_ty.errorUnionPayload(zcu);

    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;

        const payload_off: u31 = @intCast(errUnionPayloadOffset(payload_ty, zcu));
        switch (err_union) {
            .load_frame => |frame_addr| break :result .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + payload_off,
            } },
            .register => |reg| {
                // TODO reuse operand
                const eu_lock = self.register_manager.lockReg(reg);
                defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

                const payload_in_gp = self.regClassForType(payload_ty).supersetOf(abi.RegisterClass.gp);
                const result_mcv: MCValue = if (payload_in_gp and maybe_inst != null)
                    try self.copyToRegisterWithInstTracking(maybe_inst.?, err_union_ty, err_union)
                else
                    .{ .register = try self.copyToTmpRegister(err_union_ty, err_union) };
                if (payload_off > 0) try self.genShiftBinOpMir(
                    .{ ._r, .sh },
                    err_union_ty,
                    result_mcv,
                    Type.u8,
                    .{ .immediate = @as(u6, @intCast(payload_off * 8)) },
                ) else try self.truncateRegister(payload_ty, result_mcv.register);
                break :result if (payload_in_gp)
                    result_mcv
                else if (maybe_inst) |inst|
                    try self.copyToRegisterWithInstTracking(inst, payload_ty, result_mcv)
                else
                    .{ .register = try self.copyToTmpRegister(payload_ty, result_mcv) };
            },
            else => return self.fail("TODO implement genUnwrapErrUnionPayloadMir for {}", .{err_union}),
        }
    };

    return result;
}

fn genUnwrapErrUnionPayloadPtrMir(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    ptr_ty: Type,
    ptr_mcv: MCValue,
) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const err_union_ty = ptr_ty.childType(zcu);
    const payload_ty = err_union_ty.errorUnionPayload(zcu);

    const result: MCValue = result: {
        const payload_off = errUnionPayloadOffset(payload_ty, zcu);
        const result_mcv: MCValue = if (maybe_inst) |inst|
            try self.copyToRegisterWithInstTracking(inst, ptr_ty, ptr_mcv)
        else
            .{ .register = try self.copyToTmpRegister(ptr_ty, ptr_mcv) };
        try self.genBinOpMir(.{ ._, .add }, ptr_ty, result_mcv, .{ .immediate = payload_off });
        break :result result_mcv;
    };

    return result;
}

fn airErrReturnTrace(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airErrReturnTrace for {}", .{self.target.cpu.arch});
    //return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airSetErrReturnTrace(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airSetErrReturnTrace for {}", .{self.target.cpu.arch});
}

fn airSaveErrReturnTraceIndex(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airSaveErrReturnTraceIndex for {}", .{self.target.cpu.arch});
}

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = result: {
        const pl_ty = self.typeOf(ty_op.operand);
        if (!pl_ty.hasRuntimeBits(zcu)) break :result .{ .immediate = 1 };

        const opt_ty = self.typeOfIndex(inst);
        const pl_mcv = try self.resolveInst(ty_op.operand);
        const same_repr = opt_ty.optionalReprIsPayload(zcu);
        if (same_repr and self.reuseOperand(inst, ty_op.operand, 0, pl_mcv)) break :result pl_mcv;

        const pl_lock: ?RegisterLock = switch (pl_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (pl_lock) |lock| self.register_manager.unlockReg(lock);

        const opt_mcv = try self.allocRegOrMem(inst, true);
        try self.genCopy(pl_ty, opt_mcv, pl_mcv, .{});

        if (!same_repr) {
            const pl_abi_size: i32 = @intCast(pl_ty.abiSize(zcu));
            switch (opt_mcv) {
                else => unreachable,

                .register => |opt_reg| {
                    try self.truncateRegister(pl_ty, opt_reg);
                    try self.asmRegisterImmediate(
                        .{ ._s, .bt },
                        opt_reg,
                        Immediate.u(@as(u6, @intCast(pl_abi_size * 8))),
                    );
                },

                .load_frame => |frame_addr| try self.asmMemoryImmediate(
                    .{ ._, .mov },
                    .{
                        .base = .{ .frame = frame_addr.index },
                        .mod = .{ .rm = .{
                            .size = .byte,
                            .disp = frame_addr.off + pl_abi_size,
                        } },
                    },
                    Immediate.u(1),
                ),
            }
        }
        break :result opt_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const eu_ty = ty_op.ty.toType();
    const pl_ty = eu_ty.errorUnionPayload(zcu);
    const err_ty = eu_ty.errorUnionSet(zcu);
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        if (!pl_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .{ .immediate = 0 };

        const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(eu_ty, zcu));
        const pl_off: i32 = @intCast(errUnionPayloadOffset(pl_ty, zcu));
        const err_off: i32 = @intCast(errUnionErrorOffset(pl_ty, zcu));
        try self.genSetMem(.{ .frame = frame_index }, pl_off, pl_ty, operand, .{});
        try self.genSetMem(.{ .frame = frame_index }, err_off, err_ty, .{ .immediate = 0 }, .{});
        break :result .{ .load_frame = .{ .index = frame_index } };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const eu_ty = ty_op.ty.toType();
    const pl_ty = eu_ty.errorUnionPayload(zcu);
    const err_ty = eu_ty.errorUnionSet(zcu);

    const result: MCValue = result: {
        if (!pl_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result try self.resolveInst(ty_op.operand);

        const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(eu_ty, zcu));
        const pl_off: i32 = @intCast(errUnionPayloadOffset(pl_ty, zcu));
        const err_off: i32 = @intCast(errUnionErrorOffset(pl_ty, zcu));
        try self.genSetMem(.{ .frame = frame_index }, pl_off, pl_ty, .undef, .{});
        const operand = try self.resolveInst(ty_op.operand);
        try self.genSetMem(.{ .frame = frame_index }, err_off, err_ty, operand, .{});
        break :result .{ .load_frame = .{ .index = frame_index } };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.typeOfIndex(inst);
        try self.genCopy(dst_ty, dst_mcv, src_mcv, .{});
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const result: MCValue = result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        switch (src_mcv) {
            .load_frame => |frame_addr| {
                const len_mcv: MCValue = .{ .load_frame = .{
                    .index = frame_addr.index,
                    .off = frame_addr.off + 8,
                } };
                if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result len_mcv;

                const dst_mcv = try self.allocRegOrMem(inst, true);
                try self.genCopy(Type.usize, dst_mcv, len_mcv, .{});
                break :result dst_mcv;
            },
            else => return self.fail("TODO implement slice_len for {}", .{src_mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const src_ty = self.typeOf(ty_op.operand);
    const src_mcv = try self.resolveInst(ty_op.operand);
    const src_reg = switch (src_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(src_ty, src_mcv),
    };
    const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
    defer self.register_manager.unlockReg(src_lock);

    const dst_ty = self.typeOfIndex(inst);
    const dst_reg = if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
        src_reg
    else
        try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
    const dst_mcv = MCValue{ .register = dst_reg };
    const dst_lock = self.register_manager.lockReg(dst_reg);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_abi_size: u32 = @intCast(dst_ty.abiSize(pt.zcu));
    try self.asmRegisterMemory(
        .{ ._, .lea },
        registerAlias(dst_reg, dst_abi_size),
        .{
            .base = .{ .reg = src_reg },
            .mod = .{ .rm = .{ .size = .qword, .disp = 8 } },
        },
    );

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const dst_ty = self.typeOfIndex(inst);
    const opt_mcv = try self.resolveInst(ty_op.operand);

    const dst_mcv = if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv))
        opt_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, dst_ty, opt_mcv);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn elemOffset(self: *Self, index_ty: Type, index: MCValue, elem_size: u64) !Register {
    const reg: Register = blk: {
        switch (index) {
            .immediate => |imm| {
                // Optimisation: if index MCValue is an immediate, we can multiply in `comptime`
                // and set the register directly to the scaled offset as an immediate.
                const reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                try self.genSetReg(reg, index_ty, .{ .immediate = imm * elem_size }, .{});
                break :blk reg;
            },
            else => {
                const reg = try self.copyToTmpRegister(index_ty, index);
                try self.genIntMulComplexOpMir(index_ty, .{ .register = reg }, .{ .immediate = elem_size });
                break :blk reg;
            },
        }
    };
    return reg;
}

fn genSliceElemPtr(self: *Self, lhs: Air.Inst.Ref, rhs: Air.Inst.Ref) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const slice_ty = self.typeOf(lhs);
    const slice_mcv = try self.resolveInst(lhs);
    const slice_mcv_lock: ?RegisterLock = switch (slice_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (slice_mcv_lock) |lock| self.register_manager.unlockReg(lock);

    const elem_ty = slice_ty.childType(zcu);
    const elem_size = elem_ty.abiSize(zcu);
    const slice_ptr_field_type = slice_ty.slicePtrFieldType(zcu);

    const index_ty = self.typeOf(rhs);
    const index_mcv = try self.resolveInst(rhs);
    const index_mcv_lock: ?RegisterLock = switch (index_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (index_mcv_lock) |lock| self.register_manager.unlockReg(lock);

    const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_size);
    const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
    defer self.register_manager.unlockReg(offset_reg_lock);

    const addr_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    try self.genSetReg(addr_reg, Type.usize, slice_mcv, .{});
    // TODO we could allocate register here, but need to expect addr register and potentially
    // offset register.
    try self.genBinOpMir(.{ ._, .add }, slice_ptr_field_type, .{ .register = addr_reg }, .{
        .register = offset_reg,
    });
    return MCValue{ .register = addr_reg.to64() };
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const result: MCValue = result: {
        const elem_ty = self.typeOfIndex(inst);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;

        const slice_ty = self.typeOf(bin_op.lhs);
        const slice_ptr_field_type = slice_ty.slicePtrFieldType(zcu);
        const elem_ptr = try self.genSliceElemPtr(bin_op.lhs, bin_op.rhs);
        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.load(dst_mcv, slice_ptr_field_type, elem_ptr);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const dst_mcv = try self.genSliceElemPtr(extra.lhs, extra.rhs);
    return self.finishAir(inst, dst_mcv, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const result: MCValue = result: {
        const array_ty = self.typeOf(bin_op.lhs);
        const elem_ty = array_ty.childType(zcu);

        const array_mcv = try self.resolveInst(bin_op.lhs);
        const array_lock: ?RegisterLock = switch (array_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (array_lock) |lock| self.register_manager.unlockReg(lock);

        const index_ty = self.typeOf(bin_op.rhs);
        const index_mcv = try self.resolveInst(bin_op.rhs);
        const index_lock: ?RegisterLock = switch (index_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (index_lock) |lock| self.register_manager.unlockReg(lock);

        try self.spillEflagsIfOccupied();
        if (array_ty.isVector(zcu) and elem_ty.bitSize(zcu) == 1) {
            const index_reg = switch (index_mcv) {
                .register => |reg| reg,
                else => try self.copyToTmpRegister(index_ty, index_mcv),
            };
            switch (array_mcv) {
                .register => |array_reg| switch (array_reg.class()) {
                    .general_purpose => try self.asmRegisterRegister(
                        .{ ._, .bt },
                        array_reg.to64(),
                        index_reg.to64(),
                    ),
                    .sse => {
                        const frame_index = try self.allocFrameIndex(FrameAlloc.initType(array_ty, zcu));
                        try self.genSetMem(.{ .frame = frame_index }, 0, array_ty, array_mcv, .{});
                        try self.asmMemoryRegister(
                            .{ ._, .bt },
                            .{
                                .base = .{ .frame = frame_index },
                                .mod = .{ .rm = .{ .size = .qword } },
                            },
                            index_reg.to64(),
                        );
                    },
                    else => unreachable,
                },
                .load_frame => try self.asmMemoryRegister(
                    .{ ._, .bt },
                    try array_mcv.mem(self, .qword),
                    index_reg.to64(),
                ),
                .memory, .load_symbol, .load_direct, .load_got, .load_tlv => try self.asmMemoryRegister(
                    .{ ._, .bt },
                    .{
                        .base = .{
                            .reg = try self.copyToTmpRegister(Type.usize, array_mcv.address()),
                        },
                        .mod = .{ .rm = .{ .size = .qword } },
                    },
                    index_reg.to64(),
                ),
                else => return self.fail("TODO airArrayElemVal for {s} of {}", .{
                    @tagName(array_mcv), array_ty.fmt(pt),
                }),
            }

            const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
            try self.asmSetccRegister(.c, dst_reg.to8());
            break :result .{ .register = dst_reg };
        }

        const elem_abi_size = elem_ty.abiSize(zcu);
        const addr_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
        const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
        defer self.register_manager.unlockReg(addr_lock);

        switch (array_mcv) {
            .register => {
                const frame_index = try self.allocFrameIndex(FrameAlloc.initType(array_ty, zcu));
                try self.genSetMem(.{ .frame = frame_index }, 0, array_ty, array_mcv, .{});
                try self.asmRegisterMemory(
                    .{ ._, .lea },
                    addr_reg,
                    .{ .base = .{ .frame = frame_index }, .mod = .{ .rm = .{ .size = .qword } } },
                );
            },
            .load_frame => |frame_addr| try self.asmRegisterMemory(
                .{ ._, .lea },
                addr_reg,
                .{
                    .base = .{ .frame = frame_addr.index },
                    .mod = .{ .rm = .{ .size = .qword, .disp = frame_addr.off } },
                },
            ),
            .memory,
            .load_symbol,
            .load_direct,
            .load_got,
            .load_tlv,
            => try self.genSetReg(addr_reg, Type.usize, array_mcv.address(), .{}),
            .lea_symbol, .lea_direct, .lea_tlv => unreachable,
            else => return self.fail("TODO airArrayElemVal_val for {s} of {}", .{
                @tagName(array_mcv), array_ty.fmt(pt),
            }),
        }

        const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_abi_size);
        const offset_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
        defer self.register_manager.unlockReg(offset_lock);

        // TODO we could allocate register here, but need to expect addr register and potentially
        // offset register.
        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.genBinOpMir(
            .{ ._, .add },
            Type.usize,
            .{ .register = addr_reg },
            .{ .register = offset_reg },
        );
        try self.genCopy(elem_ty, dst_mcv, .{ .indirect = .{ .reg = addr_reg } }, .{});
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr_ty = self.typeOf(bin_op.lhs);

    // this is identical to the `airPtrElemPtr` codegen expect here an
    // additional `mov` is needed at the end to get the actual value

    const result = result: {
        const elem_ty = ptr_ty.elemType2(zcu);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;

        const elem_abi_size: u32 = @intCast(elem_ty.abiSize(zcu));
        const index_ty = self.typeOf(bin_op.rhs);
        const index_mcv = try self.resolveInst(bin_op.rhs);
        const index_lock = switch (index_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (index_lock) |lock| self.register_manager.unlockReg(lock);

        const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_abi_size);
        const offset_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
        defer self.register_manager.unlockReg(offset_lock);

        const ptr_mcv = try self.resolveInst(bin_op.lhs);
        const elem_ptr_reg = if (ptr_mcv.isRegister() and self.liveness.operandDies(inst, 0))
            ptr_mcv.register
        else
            try self.copyToTmpRegister(ptr_ty, ptr_mcv);
        const elem_ptr_lock = self.register_manager.lockRegAssumeUnused(elem_ptr_reg);
        defer self.register_manager.unlockReg(elem_ptr_lock);
        try self.asmRegisterRegister(
            .{ ._, .add },
            elem_ptr_reg,
            offset_reg,
        );

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_lock = switch (dst_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);
        try self.load(dst_mcv, ptr_ty, .{ .register = elem_ptr_reg });
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

    const result = result: {
        const elem_ptr_ty = self.typeOfIndex(inst);
        const base_ptr_ty = self.typeOf(extra.lhs);

        const base_ptr_mcv = try self.resolveInst(extra.lhs);
        const base_ptr_lock: ?RegisterLock = switch (base_ptr_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (base_ptr_lock) |lock| self.register_manager.unlockReg(lock);

        if (elem_ptr_ty.ptrInfo(zcu).flags.vector_index != .none) {
            break :result if (self.reuseOperand(inst, extra.lhs, 0, base_ptr_mcv))
                base_ptr_mcv
            else
                try self.copyToRegisterWithInstTracking(inst, elem_ptr_ty, base_ptr_mcv);
        }

        const elem_ty = base_ptr_ty.elemType2(zcu);
        const elem_abi_size = elem_ty.abiSize(zcu);
        const index_ty = self.typeOf(extra.rhs);
        const index_mcv = try self.resolveInst(extra.rhs);
        const index_lock: ?RegisterLock = switch (index_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (index_lock) |lock| self.register_manager.unlockReg(lock);

        const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_abi_size);
        const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
        defer self.register_manager.unlockReg(offset_reg_lock);

        const dst_mcv = try self.copyToRegisterWithInstTracking(inst, elem_ptr_ty, base_ptr_mcv);
        try self.genBinOpMir(.{ ._, .add }, elem_ptr_ty, dst_mcv, .{ .register = offset_reg });

        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr_union_ty = self.typeOf(bin_op.lhs);
    const union_ty = ptr_union_ty.childType(zcu);
    const tag_ty = self.typeOf(bin_op.rhs);
    const layout = union_ty.unionGetLayout(zcu);

    if (layout.tag_size == 0) {
        return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ptr = try self.resolveInst(bin_op.lhs);
    const ptr_lock: ?RegisterLock = switch (ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const tag = try self.resolveInst(bin_op.rhs);
    const tag_lock: ?RegisterLock = switch (tag) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (tag_lock) |lock| self.register_manager.unlockReg(lock);

    const adjusted_ptr: MCValue = if (layout.payload_size > 0 and layout.tag_align.compare(.lt, layout.payload_align)) blk: {
        // TODO reusing the operand
        const reg = try self.copyToTmpRegister(ptr_union_ty, ptr);
        try self.genBinOpMir(
            .{ ._, .add },
            ptr_union_ty,
            .{ .register = reg },
            .{ .immediate = layout.payload_size },
        );
        break :blk MCValue{ .register = reg };
    } else ptr;

    const ptr_tag_ty = try pt.adjustPtrTypeChild(ptr_union_ty, tag_ty);
    try self.store(ptr_tag_ty, adjusted_ptr, tag, .{});

    return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const tag_ty = self.typeOfIndex(inst);
    const union_ty = self.typeOf(ty_op.operand);
    const layout = union_ty.unionGetLayout(zcu);

    if (layout.tag_size == 0) {
        return self.finishAir(inst, .none, .{ ty_op.operand, .none, .none });
    }

    // TODO reusing the operand
    const operand = try self.resolveInst(ty_op.operand);
    const operand_lock: ?RegisterLock = switch (operand) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

    const tag_abi_size = tag_ty.abiSize(zcu);
    const dst_mcv: MCValue = blk: {
        switch (operand) {
            .load_frame => |frame_addr| {
                if (tag_abi_size <= 8) {
                    const off: i32 = @intCast(layout.tagOffset());
                    break :blk try self.copyToRegisterWithInstTracking(inst, tag_ty, .{
                        .load_frame = .{ .index = frame_addr.index, .off = frame_addr.off + off },
                    });
                }

                return self.fail(
                    "TODO implement get_union_tag for ABI larger than 8 bytes and operand {}",
                    .{operand},
                );
            },
            .register => {
                const shift: u6 = @intCast(layout.tagOffset() * 8);
                const result = try self.copyToRegisterWithInstTracking(inst, union_ty, operand);
                try self.genShiftBinOpMir(
                    .{ ._r, .sh },
                    Type.usize,
                    result,
                    Type.u8,
                    .{ .immediate = shift },
                );
                break :blk MCValue{
                    .register = registerAlias(result.register, @intCast(layout.tag_size)),
                };
            },
            else => return self.fail("TODO implement get_union_tag for {}", .{operand}),
        }
    };

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = result: {
        try self.spillEflagsIfOccupied();

        const dst_ty = self.typeOfIndex(inst);
        const src_ty = self.typeOf(ty_op.operand);
        if (src_ty.zigTypeTag(zcu) == .vector) return self.fail("TODO implement airClz for {}", .{
            src_ty.fmt(pt),
        });

        const src_mcv = try self.resolveInst(ty_op.operand);
        const mat_src_mcv = switch (src_mcv) {
            .immediate => MCValue{ .register = try self.copyToTmpRegister(src_ty, src_mcv) },
            else => src_mcv,
        };
        const mat_src_lock = switch (mat_src_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (mat_src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
        const dst_mcv = MCValue{ .register = dst_reg };
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        const abi_size: u31 = @intCast(src_ty.abiSize(zcu));
        const src_bits: u31 = @intCast(src_ty.bitSize(zcu));
        const has_lzcnt = self.hasFeature(.lzcnt);
        if (src_bits > @as(u32, if (has_lzcnt) 128 else 64)) {
            const limbs_len = math.divCeil(u32, abi_size, 8) catch unreachable;
            const extra_bits = abi_size * 8 - src_bits;

            const index_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const index_lock = self.register_manager.lockRegAssumeUnused(index_reg);
            defer self.register_manager.unlockReg(index_lock);

            try self.asmRegisterImmediate(.{ ._, .mov }, index_reg.to32(), Immediate.u(limbs_len));
            switch (extra_bits) {
                1 => try self.asmRegisterRegister(.{ ._, .xor }, dst_reg.to32(), dst_reg.to32()),
                else => try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    dst_reg.to32(),
                    Immediate.s(@as(i32, extra_bits) - 1),
                ),
            }
            const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
            try self.asmRegisterRegister(.{ ._, .@"test" }, index_reg.to32(), index_reg.to32());
            const zero = try self.asmJccReloc(.z, undefined);
            if (self.hasFeature(.slow_incdec)) {
                try self.asmRegisterImmediate(.{ ._, .sub }, index_reg.to32(), Immediate.u(1));
            } else {
                try self.asmRegister(.{ ._, .dec }, index_reg.to32());
            }
            try self.asmMemoryImmediate(.{ ._, .cmp }, .{
                .base = .{ .frame = src_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = index_reg.to64(),
                    .scale = .@"8",
                    .disp = src_mcv.load_frame.off,
                } },
            }, Immediate.u(0));
            _ = try self.asmJccReloc(.e, loop);
            try self.asmRegisterMemory(.{ ._, .bsr }, dst_reg.to64(), .{
                .base = .{ .frame = src_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = index_reg.to64(),
                    .scale = .@"8",
                    .disp = src_mcv.load_frame.off,
                } },
            });
            self.performReloc(zero);
            try self.asmRegisterImmediate(.{ ._l, .sh }, index_reg.to32(), Immediate.u(6));
            try self.asmRegisterRegister(.{ ._, .add }, index_reg.to32(), dst_reg.to32());
            try self.asmRegisterImmediate(.{ ._, .mov }, dst_reg.to32(), Immediate.u(src_bits - 1));
            try self.asmRegisterRegister(.{ ._, .sub }, dst_reg.to32(), index_reg.to32());
            break :result dst_mcv;
        }

        if (has_lzcnt) {
            if (src_bits <= 8) {
                const wide_reg = try self.copyToTmpRegister(src_ty, mat_src_mcv);
                try self.truncateRegister(src_ty, wide_reg);
                try self.genBinOpMir(.{ ._, .lzcnt }, Type.u32, dst_mcv, .{ .register = wide_reg });
                try self.genBinOpMir(
                    .{ ._, .sub },
                    dst_ty,
                    dst_mcv,
                    .{ .immediate = 32 - src_bits },
                );
            } else if (src_bits <= 64) {
                try self.genBinOpMir(.{ ._, .lzcnt }, src_ty, dst_mcv, mat_src_mcv);
                const extra_bits = self.regExtraBits(src_ty);
                if (extra_bits > 0) {
                    try self.genBinOpMir(.{ ._, .sub }, dst_ty, dst_mcv, .{ .immediate = extra_bits });
                }
            } else {
                assert(src_bits <= 128);
                const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const tmp_mcv = MCValue{ .register = tmp_reg };
                const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                defer self.register_manager.unlockReg(tmp_lock);

                try self.genBinOpMir(
                    .{ ._, .lzcnt },
                    Type.u64,
                    dst_mcv,
                    if (mat_src_mcv.isMemory())
                        mat_src_mcv
                    else
                        .{ .register = mat_src_mcv.register_pair[0] },
                );
                try self.genBinOpMir(.{ ._, .add }, dst_ty, dst_mcv, .{ .immediate = 64 });
                try self.genBinOpMir(
                    .{ ._, .lzcnt },
                    Type.u64,
                    tmp_mcv,
                    if (mat_src_mcv.isMemory())
                        mat_src_mcv.address().offset(8).deref()
                    else
                        .{ .register = mat_src_mcv.register_pair[1] },
                );
                try self.asmCmovccRegisterRegister(.nc, dst_reg.to32(), tmp_reg.to32());

                if (src_bits < 128) try self.genBinOpMir(
                    .{ ._, .sub },
                    dst_ty,
                    dst_mcv,
                    .{ .immediate = 128 - src_bits },
                );
            }
            break :result dst_mcv;
        }

        assert(src_bits <= 64);
        const cmov_abi_size = @max(@as(u32, @intCast(dst_ty.abiSize(zcu))), 2);
        if (math.isPowerOfTwo(src_bits)) {
            const imm_reg = try self.copyToTmpRegister(dst_ty, .{
                .immediate = src_bits ^ (src_bits - 1),
            });
            const imm_lock = self.register_manager.lockRegAssumeUnused(imm_reg);
            defer self.register_manager.unlockReg(imm_lock);

            if (src_bits <= 8) {
                const wide_reg = try self.copyToTmpRegister(src_ty, mat_src_mcv);
                const wide_lock = self.register_manager.lockRegAssumeUnused(wide_reg);
                defer self.register_manager.unlockReg(wide_lock);

                try self.truncateRegister(src_ty, wide_reg);
                try self.genBinOpMir(.{ ._, .bsr }, Type.u16, dst_mcv, .{ .register = wide_reg });
            } else try self.genBinOpMir(.{ ._, .bsr }, src_ty, dst_mcv, mat_src_mcv);

            try self.asmCmovccRegisterRegister(
                .z,
                registerAlias(dst_reg, cmov_abi_size),
                registerAlias(imm_reg, cmov_abi_size),
            );

            try self.genBinOpMir(.{ ._, .xor }, dst_ty, dst_mcv, .{ .immediate = src_bits - 1 });
        } else {
            const imm_reg = try self.copyToTmpRegister(dst_ty, .{
                .immediate = @as(u64, math.maxInt(u64)) >> @intCast(64 - self.regBitSize(dst_ty)),
            });
            const imm_lock = self.register_manager.lockRegAssumeUnused(imm_reg);
            defer self.register_manager.unlockReg(imm_lock);

            const wide_reg = try self.copyToTmpRegister(src_ty, mat_src_mcv);
            const wide_lock = self.register_manager.lockRegAssumeUnused(wide_reg);
            defer self.register_manager.unlockReg(wide_lock);

            try self.truncateRegister(src_ty, wide_reg);
            try self.genBinOpMir(
                .{ ._, .bsr },
                if (src_bits <= 8) Type.u16 else src_ty,
                dst_mcv,
                .{ .register = wide_reg },
            );

            try self.asmCmovccRegisterRegister(
                .nz,
                registerAlias(imm_reg, cmov_abi_size),
                registerAlias(dst_reg, cmov_abi_size),
            );

            try self.genSetReg(dst_reg, dst_ty, .{ .immediate = src_bits - 1 }, .{});
            try self.genBinOpMir(.{ ._, .sub }, dst_ty, dst_mcv, .{ .register = imm_reg });
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = result: {
        try self.spillEflagsIfOccupied();

        const dst_ty = self.typeOfIndex(inst);
        const src_ty = self.typeOf(ty_op.operand);
        if (src_ty.zigTypeTag(zcu) == .vector) return self.fail("TODO implement airCtz for {}", .{
            src_ty.fmt(pt),
        });

        const src_mcv = try self.resolveInst(ty_op.operand);
        const mat_src_mcv = switch (src_mcv) {
            .immediate => MCValue{ .register = try self.copyToTmpRegister(src_ty, src_mcv) },
            else => src_mcv,
        };
        const mat_src_lock = switch (mat_src_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (mat_src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
        const dst_mcv = MCValue{ .register = dst_reg };
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const abi_size: u31 = @intCast(src_ty.abiSize(zcu));
        const src_bits: u31 = @intCast(src_ty.bitSize(zcu));
        const has_bmi = self.hasFeature(.bmi);
        if (src_bits > @as(u32, if (has_bmi) 128 else 64)) {
            const limbs_len = math.divCeil(u32, abi_size, 8) catch unreachable;
            const extra_bits = abi_size * 8 - src_bits;

            const index_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const index_lock = self.register_manager.lockRegAssumeUnused(index_reg);
            defer self.register_manager.unlockReg(index_lock);

            try self.asmRegisterImmediate(.{ ._, .mov }, index_reg.to32(), Immediate.s(-1));
            switch (extra_bits) {
                0 => try self.asmRegisterRegister(.{ ._, .xor }, dst_reg.to32(), dst_reg.to32()),
                1 => try self.asmRegisterRegister(.{ ._, .mov }, dst_reg.to32(), dst_reg.to32()),
                else => try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    dst_reg.to32(),
                    Immediate.s(-@as(i32, extra_bits)),
                ),
            }
            const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
            if (self.hasFeature(.slow_incdec)) {
                try self.asmRegisterImmediate(.{ ._, .add }, index_reg.to32(), Immediate.u(1));
            } else {
                try self.asmRegister(.{ ._, .inc }, index_reg.to32());
            }
            try self.asmRegisterImmediate(.{ ._, .cmp }, index_reg.to32(), Immediate.u(limbs_len));
            const zero = try self.asmJccReloc(.nb, undefined);
            try self.asmMemoryImmediate(.{ ._, .cmp }, .{
                .base = .{ .frame = src_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = index_reg.to64(),
                    .scale = .@"8",
                    .disp = src_mcv.load_frame.off,
                } },
            }, Immediate.u(0));
            _ = try self.asmJccReloc(.e, loop);
            try self.asmRegisterMemory(.{ ._, .bsf }, dst_reg.to64(), .{
                .base = .{ .frame = src_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = index_reg.to64(),
                    .scale = .@"8",
                    .disp = src_mcv.load_frame.off,
                } },
            });
            self.performReloc(zero);
            try self.asmRegisterImmediate(.{ ._l, .sh }, index_reg.to32(), Immediate.u(6));
            try self.asmRegisterRegister(.{ ._, .add }, dst_reg.to32(), index_reg.to32());
            break :result dst_mcv;
        }

        const wide_ty = if (src_bits <= 8) Type.u16 else src_ty;
        if (has_bmi) {
            if (src_bits <= 64) {
                const extra_bits = self.regExtraBits(src_ty) + @as(u64, if (src_bits <= 8) 8 else 0);
                const masked_mcv = if (extra_bits > 0) masked: {
                    const tmp_mcv = tmp: {
                        if (src_mcv.isImmediate() or self.liveness.operandDies(inst, 0))
                            break :tmp src_mcv;
                        try self.genSetReg(dst_reg, wide_ty, src_mcv, .{});
                        break :tmp dst_mcv;
                    };
                    try self.genBinOpMir(
                        .{ ._, .@"or" },
                        wide_ty,
                        tmp_mcv,
                        .{ .immediate = (@as(u64, math.maxInt(u64)) >> @intCast(64 - extra_bits)) <<
                            @intCast(src_bits) },
                    );
                    break :masked tmp_mcv;
                } else mat_src_mcv;
                try self.genBinOpMir(.{ ._, .tzcnt }, wide_ty, dst_mcv, masked_mcv);
            } else {
                assert(src_bits <= 128);
                const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const tmp_mcv = MCValue{ .register = tmp_reg };
                const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                defer self.register_manager.unlockReg(tmp_lock);

                const lo_mat_src_mcv: MCValue = if (mat_src_mcv.isMemory())
                    mat_src_mcv
                else
                    .{ .register = mat_src_mcv.register_pair[0] };
                const hi_mat_src_mcv: MCValue = if (mat_src_mcv.isMemory())
                    mat_src_mcv.address().offset(8).deref()
                else
                    .{ .register = mat_src_mcv.register_pair[1] };
                const masked_mcv = if (src_bits < 128) masked: {
                    try self.genCopy(Type.u64, dst_mcv, hi_mat_src_mcv, .{});
                    try self.genBinOpMir(
                        .{ ._, .@"or" },
                        Type.u64,
                        dst_mcv,
                        .{ .immediate = @as(u64, math.maxInt(u64)) << @intCast(src_bits - 64) },
                    );
                    break :masked dst_mcv;
                } else hi_mat_src_mcv;
                try self.genBinOpMir(.{ ._, .tzcnt }, Type.u64, dst_mcv, masked_mcv);
                try self.genBinOpMir(.{ ._, .add }, dst_ty, dst_mcv, .{ .immediate = 64 });
                try self.genBinOpMir(.{ ._, .tzcnt }, Type.u64, tmp_mcv, lo_mat_src_mcv);
                try self.asmCmovccRegisterRegister(.nc, dst_reg.to32(), tmp_reg.to32());
            }
            break :result dst_mcv;
        }

        assert(src_bits <= 64);
        const width_reg = try self.copyToTmpRegister(dst_ty, .{ .immediate = src_bits });
        const width_lock = self.register_manager.lockRegAssumeUnused(width_reg);
        defer self.register_manager.unlockReg(width_lock);

        if (src_bits <= 8 or !math.isPowerOfTwo(src_bits)) {
            const wide_reg = try self.copyToTmpRegister(src_ty, mat_src_mcv);
            const wide_lock = self.register_manager.lockRegAssumeUnused(wide_reg);
            defer self.register_manager.unlockReg(wide_lock);

            try self.truncateRegister(src_ty, wide_reg);
            try self.genBinOpMir(.{ ._, .bsf }, wide_ty, dst_mcv, .{ .register = wide_reg });
        } else try self.genBinOpMir(.{ ._, .bsf }, src_ty, dst_mcv, mat_src_mcv);

        const cmov_abi_size = @max(@as(u32, @intCast(dst_ty.abiSize(zcu))), 2);
        try self.asmCmovccRegisterRegister(
            .z,
            registerAlias(dst_reg, cmov_abi_size),
            registerAlias(width_reg, cmov_abi_size),
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopCount(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = result: {
        try self.spillEflagsIfOccupied();

        const src_ty = self.typeOf(ty_op.operand);
        const src_abi_size: u32 = @intCast(src_ty.abiSize(zcu));
        if (src_ty.zigTypeTag(zcu) == .vector or src_abi_size > 16)
            return self.fail("TODO implement airPopCount for {}", .{src_ty.fmt(pt)});
        const src_mcv = try self.resolveInst(ty_op.operand);

        const mat_src_mcv = switch (src_mcv) {
            .immediate => MCValue{ .register = try self.copyToTmpRegister(src_ty, src_mcv) },
            else => src_mcv,
        };
        const mat_src_lock = switch (mat_src_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (mat_src_lock) |lock| self.register_manager.unlockReg(lock);

        if (src_abi_size <= 8) {
            const dst_contains_src =
                src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv);
            const dst_reg = if (dst_contains_src)
                src_mcv.getReg().?
            else
                try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
            const dst_lock = self.register_manager.lockReg(dst_reg);
            defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

            try self.genPopCount(dst_reg, src_ty, mat_src_mcv, dst_contains_src);
            break :result .{ .register = dst_reg };
        }

        assert(src_abi_size > 8 and src_abi_size <= 16);
        const tmp_regs = try self.register_manager.allocRegs(2, .{ inst, null }, abi.RegisterClass.gp);
        const tmp_locks = self.register_manager.lockRegsAssumeUnused(2, tmp_regs);
        defer for (tmp_locks) |lock| self.register_manager.unlockReg(lock);

        try self.genPopCount(tmp_regs[0], Type.usize, if (mat_src_mcv.isMemory())
            mat_src_mcv
        else
            .{ .register = mat_src_mcv.register_pair[0] }, false);
        const src_info = src_ty.intInfo(zcu);
        const hi_ty = try pt.intType(src_info.signedness, (src_info.bits - 1) % 64 + 1);
        try self.genPopCount(tmp_regs[1], hi_ty, if (mat_src_mcv.isMemory())
            mat_src_mcv.address().offset(8).deref()
        else
            .{ .register = mat_src_mcv.register_pair[1] }, false);
        try self.asmRegisterRegister(.{ ._, .add }, tmp_regs[0].to8(), tmp_regs[1].to8());
        break :result .{ .register = tmp_regs[0] };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn genPopCount(
    self: *Self,
    dst_reg: Register,
    src_ty: Type,
    src_mcv: MCValue,
    dst_contains_src: bool,
) !void {
    const pt = self.pt;

    const src_abi_size: u32 = @intCast(src_ty.abiSize(pt.zcu));
    if (self.hasFeature(.popcnt)) return self.genBinOpMir(
        .{ ._, .popcnt },
        if (src_abi_size > 1) src_ty else Type.u32,
        .{ .register = dst_reg },
        if (src_abi_size > 1) src_mcv else src: {
            if (!dst_contains_src) try self.genSetReg(dst_reg, src_ty, src_mcv, .{});
            try self.truncateRegister(try src_ty.toUnsigned(pt), dst_reg);
            break :src .{ .register = dst_reg };
        },
    );

    const mask = @as(u64, math.maxInt(u64)) >> @intCast(64 - src_abi_size * 8);
    const imm_0_1 = Immediate.u(mask / 0b1_1);
    const imm_00_11 = Immediate.u(mask / 0b01_01);
    const imm_0000_1111 = Immediate.u(mask / 0b0001_0001);
    const imm_0000_0001 = Immediate.u(mask / 0b1111_1111);

    const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
    defer self.register_manager.unlockReg(tmp_lock);

    const dst = registerAlias(dst_reg, src_abi_size);
    const tmp = registerAlias(tmp_reg, src_abi_size);
    const imm = if (src_abi_size > 4)
        try self.register_manager.allocReg(null, abi.RegisterClass.gp)
    else
        undefined;

    if (!dst_contains_src) try self.genSetReg(dst, src_ty, src_mcv, .{});
    // dst = operand
    try self.asmRegisterRegister(.{ ._, .mov }, tmp, dst);
    // tmp = operand
    try self.asmRegisterImmediate(.{ ._r, .sh }, tmp, Immediate.u(1));
    // tmp = operand >> 1
    if (src_abi_size > 4) {
        try self.asmRegisterImmediate(.{ ._, .mov }, imm, imm_0_1);
        try self.asmRegisterRegister(.{ ._, .@"and" }, tmp, imm);
    } else try self.asmRegisterImmediate(.{ ._, .@"and" }, tmp, imm_0_1);
    // tmp = (operand >> 1) & 0x55...55
    try self.asmRegisterRegister(.{ ._, .sub }, dst, tmp);
    // dst = temp1 = operand - ((operand >> 1) & 0x55...55)
    try self.asmRegisterRegister(.{ ._, .mov }, tmp, dst);
    // tmp = temp1
    try self.asmRegisterImmediate(.{ ._r, .sh }, dst, Immediate.u(2));
    // dst = temp1 >> 2
    if (src_abi_size > 4) {
        try self.asmRegisterImmediate(.{ ._, .mov }, imm, imm_00_11);
        try self.asmRegisterRegister(.{ ._, .@"and" }, tmp, imm);
        try self.asmRegisterRegister(.{ ._, .@"and" }, dst, imm);
    } else {
        try self.asmRegisterImmediate(.{ ._, .@"and" }, tmp, imm_00_11);
        try self.asmRegisterImmediate(.{ ._, .@"and" }, dst, imm_00_11);
    }
    // tmp = temp1 & 0x33...33
    // dst = (temp1 >> 2) & 0x33...33
    try self.asmRegisterRegister(.{ ._, .add }, tmp, dst);
    // tmp = temp2 = (temp1 & 0x33...33) + ((temp1 >> 2) & 0x33...33)
    try self.asmRegisterRegister(.{ ._, .mov }, dst, tmp);
    // dst = temp2
    try self.asmRegisterImmediate(.{ ._r, .sh }, tmp, Immediate.u(4));
    // tmp = temp2 >> 4
    try self.asmRegisterRegister(.{ ._, .add }, dst, tmp);
    // dst = temp2 + (temp2 >> 4)
    if (src_abi_size > 4) {
        try self.asmRegisterImmediate(.{ ._, .mov }, imm, imm_0000_1111);
        try self.asmRegisterImmediate(.{ ._, .mov }, tmp, imm_0000_0001);
        try self.asmRegisterRegister(.{ ._, .@"and" }, dst, imm);
        try self.asmRegisterRegister(.{ .i_, .mul }, dst, tmp);
    } else {
        try self.asmRegisterImmediate(.{ ._, .@"and" }, dst, imm_0000_1111);
        if (src_abi_size > 1) {
            try self.asmRegisterRegisterImmediate(.{ .i_, .mul }, dst, dst, imm_0000_0001);
        }
    }
    // dst = temp3 = (temp2 + (temp2 >> 4)) & 0x0f...0f
    // dst = temp3 * 0x01...01
    if (src_abi_size > 1) {
        try self.asmRegisterImmediate(.{ ._r, .sh }, dst, Immediate.u((src_abi_size - 1) * 8));
    }
    // dst = (temp3 * 0x01...01) >> (bits - 8)
}

fn genByteSwap(
    self: *Self,
    inst: Air.Inst.Index,
    src_ty: Type,
    src_mcv: MCValue,
    mem_ok: bool,
) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const has_movbe = self.hasFeature(.movbe);

    if (src_ty.zigTypeTag(zcu) == .vector) return self.fail(
        "TODO implement genByteSwap for {}",
        .{src_ty.fmt(pt)},
    );

    const src_lock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    const abi_size: u32 = @intCast(src_ty.abiSize(zcu));
    switch (abi_size) {
        0 => unreachable,
        1 => return if ((mem_ok or src_mcv.isRegister()) and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, src_ty, src_mcv),
        2 => if ((mem_ok or src_mcv.isRegister()) and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
        {
            try self.genBinOpMir(.{ ._l, .ro }, src_ty, src_mcv, .{ .immediate = 8 });
            return src_mcv;
        },
        3...8 => if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) {
            try self.genUnOpMir(.{ ._, .bswap }, src_ty, src_mcv);
            return src_mcv;
        },
        9...16 => {
            switch (src_mcv) {
                .register_pair => |src_regs| if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) {
                    for (src_regs) |src_reg| try self.asmRegister(.{ ._, .bswap }, src_reg.to64());
                    return .{ .register_pair = .{ src_regs[1], src_regs[0] } };
                },
                else => {},
            }

            const dst_regs =
                try self.register_manager.allocRegs(2, .{ inst, inst }, abi.RegisterClass.gp);
            const dst_locks = self.register_manager.lockRegsAssumeUnused(2, dst_regs);
            defer for (dst_locks) |lock| self.register_manager.unlockReg(lock);

            for (dst_regs, 0..) |dst_reg, limb_index| {
                if (src_mcv.isMemory()) {
                    try self.asmRegisterMemory(
                        .{ ._, if (has_movbe) .movbe else .mov },
                        dst_reg.to64(),
                        try src_mcv.address().offset(@intCast(limb_index * 8)).deref().mem(self, .qword),
                    );
                    if (!has_movbe) try self.asmRegister(.{ ._, .bswap }, dst_reg.to64());
                } else {
                    try self.asmRegisterRegister(
                        .{ ._, .mov },
                        dst_reg.to64(),
                        src_mcv.register_pair[limb_index].to64(),
                    );
                    try self.asmRegister(.{ ._, .bswap }, dst_reg.to64());
                }
            }
            return .{ .register_pair = .{ dst_regs[1], dst_regs[0] } };
        },
        else => {
            const limbs_len = math.divCeil(u32, abi_size, 8) catch unreachable;

            const temp_regs =
                try self.register_manager.allocRegs(4, .{null} ** 4, abi.RegisterClass.gp);
            const temp_locks = self.register_manager.lockRegsAssumeUnused(4, temp_regs);
            defer for (temp_locks) |lock| self.register_manager.unlockReg(lock);

            const dst_mcv = try self.allocRegOrMem(inst, false);
            try self.asmRegisterRegister(.{ ._, .xor }, temp_regs[0].to32(), temp_regs[0].to32());
            try self.asmRegisterImmediate(
                .{ ._, .mov },
                temp_regs[1].to32(),
                Immediate.u(limbs_len - 1),
            );

            const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
            try self.asmRegisterMemory(
                .{ ._, if (has_movbe) .movbe else .mov },
                temp_regs[2].to64(),
                .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[0].to64(),
                        .scale = .@"8",
                        .disp = dst_mcv.load_frame.off,
                    } },
                },
            );
            try self.asmRegisterMemory(
                .{ ._, if (has_movbe) .movbe else .mov },
                temp_regs[3].to64(),
                .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[1].to64(),
                        .scale = .@"8",
                        .disp = dst_mcv.load_frame.off,
                    } },
                },
            );
            if (!has_movbe) {
                try self.asmRegister(.{ ._, .bswap }, temp_regs[2].to64());
                try self.asmRegister(.{ ._, .bswap }, temp_regs[3].to64());
            }
            try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = dst_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = temp_regs[0].to64(),
                    .scale = .@"8",
                    .disp = dst_mcv.load_frame.off,
                } },
            }, temp_regs[3].to64());
            try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = dst_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = temp_regs[1].to64(),
                    .scale = .@"8",
                    .disp = dst_mcv.load_frame.off,
                } },
            }, temp_regs[2].to64());
            if (self.hasFeature(.slow_incdec)) {
                try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[0].to32(), Immediate.u(1));
                try self.asmRegisterImmediate(.{ ._, .sub }, temp_regs[1].to32(), Immediate.u(1));
            } else {
                try self.asmRegister(.{ ._, .inc }, temp_regs[0].to32());
                try self.asmRegister(.{ ._, .dec }, temp_regs[1].to32());
            }
            try self.asmRegisterRegister(.{ ._, .cmp }, temp_regs[0].to32(), temp_regs[1].to32());
            _ = try self.asmJccReloc(.be, loop);
            return dst_mcv;
        },
    }

    const dst_mcv: MCValue = if (mem_ok and has_movbe and src_mcv.isRegister())
        try self.allocRegOrMem(inst, true)
    else
        .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.gp) };
    if (dst_mcv.getReg()) |dst_reg| {
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_mcv.register);
        defer self.register_manager.unlockReg(dst_lock);

        try self.genSetReg(dst_reg, src_ty, src_mcv, .{});
        switch (abi_size) {
            else => unreachable,
            2 => try self.genBinOpMir(.{ ._l, .ro }, src_ty, dst_mcv, .{ .immediate = 8 }),
            3...8 => try self.genUnOpMir(.{ ._, .bswap }, src_ty, dst_mcv),
        }
    } else try self.genBinOpMir(.{ ._, .movbe }, src_ty, dst_mcv, src_mcv);
    return dst_mcv;
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const src_ty = self.typeOf(ty_op.operand);
    const src_bits: u32 = @intCast(src_ty.bitSize(zcu));
    const src_mcv = try self.resolveInst(ty_op.operand);

    const dst_mcv = try self.genByteSwap(inst, src_ty, src_mcv, true);
    try self.genShiftBinOpMir(
        .{ ._r, switch (if (src_ty.isAbiInt(zcu)) src_ty.intInfo(zcu).signedness else .unsigned) {
            .signed => .sa,
            .unsigned => .sh,
        } },
        src_ty,
        dst_mcv,
        if (src_bits > 256) Type.u16 else Type.u8,
        .{ .immediate = src_ty.abiSize(zcu) * 8 - src_bits },
    );
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const src_ty = self.typeOf(ty_op.operand);
    const abi_size: u32 = @intCast(src_ty.abiSize(zcu));
    const bit_size: u32 = @intCast(src_ty.bitSize(zcu));
    const src_mcv = try self.resolveInst(ty_op.operand);

    const dst_mcv = try self.genByteSwap(inst, src_ty, src_mcv, false);
    const dst_locks: [2]?RegisterLock = switch (dst_mcv) {
        .register => |dst_reg| .{ self.register_manager.lockReg(dst_reg), null },
        .register_pair => |dst_regs| self.register_manager.lockRegs(2, dst_regs),
        else => unreachable,
    };
    defer for (dst_locks) |dst_lock| if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
    defer self.register_manager.unlockReg(tmp_lock);

    const limb_abi_size: u32 = @min(abi_size, 8);
    const tmp = registerAlias(tmp_reg, limb_abi_size);
    const imm = if (limb_abi_size > 4)
        try self.register_manager.allocReg(null, abi.RegisterClass.gp)
    else
        undefined;

    const mask = @as(u64, math.maxInt(u64)) >> @intCast(64 - limb_abi_size * 8);
    const imm_0000_1111 = Immediate.u(mask / 0b0001_0001);
    const imm_00_11 = Immediate.u(mask / 0b01_01);
    const imm_0_1 = Immediate.u(mask / 0b1_1);

    for (dst_mcv.getRegs()) |dst_reg| {
        const dst = registerAlias(dst_reg, limb_abi_size);

        // dst = temp1 = bswap(operand)
        try self.asmRegisterRegister(.{ ._, .mov }, tmp, dst);
        // tmp = temp1
        try self.asmRegisterImmediate(.{ ._r, .sh }, dst, Immediate.u(4));
        // dst = temp1 >> 4
        if (limb_abi_size > 4) {
            try self.asmRegisterImmediate(.{ ._, .mov }, imm, imm_0000_1111);
            try self.asmRegisterRegister(.{ ._, .@"and" }, tmp, imm);
            try self.asmRegisterRegister(.{ ._, .@"and" }, dst, imm);
        } else {
            try self.asmRegisterImmediate(.{ ._, .@"and" }, tmp, imm_0000_1111);
            try self.asmRegisterImmediate(.{ ._, .@"and" }, dst, imm_0000_1111);
        }
        // tmp = temp1 & 0x0F...0F
        // dst = (temp1 >> 4) & 0x0F...0F
        try self.asmRegisterImmediate(.{ ._l, .sh }, tmp, Immediate.u(4));
        // tmp = (temp1 & 0x0F...0F) << 4
        try self.asmRegisterRegister(.{ ._, .@"or" }, dst, tmp);
        // dst = temp2 = ((temp1 >> 4) & 0x0F...0F) | ((temp1 & 0x0F...0F) << 4)
        try self.asmRegisterRegister(.{ ._, .mov }, tmp, dst);
        // tmp = temp2
        try self.asmRegisterImmediate(.{ ._r, .sh }, dst, Immediate.u(2));
        // dst = temp2 >> 2
        if (limb_abi_size > 4) {
            try self.asmRegisterImmediate(.{ ._, .mov }, imm, imm_00_11);
            try self.asmRegisterRegister(.{ ._, .@"and" }, tmp, imm);
            try self.asmRegisterRegister(.{ ._, .@"and" }, dst, imm);
        } else {
            try self.asmRegisterImmediate(.{ ._, .@"and" }, tmp, imm_00_11);
            try self.asmRegisterImmediate(.{ ._, .@"and" }, dst, imm_00_11);
        }
        // tmp = temp2 & 0x33...33
        // dst = (temp2 >> 2) & 0x33...33
        try self.asmRegisterMemory(
            .{ ._, .lea },
            if (limb_abi_size > 4) tmp.to64() else tmp.to32(),
            .{
                .base = .{ .reg = dst.to64() },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = tmp.to64(),
                    .scale = .@"4",
                } },
            },
        );
        // tmp = temp3 = ((temp2 >> 2) & 0x33...33) + ((temp2 & 0x33...33) << 2)
        try self.asmRegisterRegister(.{ ._, .mov }, dst, tmp);
        // dst = temp3
        try self.asmRegisterImmediate(.{ ._r, .sh }, tmp, Immediate.u(1));
        // tmp = temp3 >> 1
        if (limb_abi_size > 4) {
            try self.asmRegisterImmediate(.{ ._, .mov }, imm, imm_0_1);
            try self.asmRegisterRegister(.{ ._, .@"and" }, dst, imm);
            try self.asmRegisterRegister(.{ ._, .@"and" }, tmp, imm);
        } else {
            try self.asmRegisterImmediate(.{ ._, .@"and" }, dst, imm_0_1);
            try self.asmRegisterImmediate(.{ ._, .@"and" }, tmp, imm_0_1);
        }
        // dst = temp3 & 0x55...55
        // tmp = (temp3 >> 1) & 0x55...55
        try self.asmRegisterMemory(
            .{ ._, .lea },
            if (limb_abi_size > 4) dst.to64() else dst.to32(),
            .{
                .base = .{ .reg = tmp.to64() },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = dst.to64(),
                    .scale = .@"2",
                } },
            },
        );
        // dst = ((temp3 >> 1) & 0x55...55) + ((temp3 & 0x55...55) << 1)
    }

    const extra_bits = abi_size * 8 - bit_size;
    const signedness: std.builtin.Signedness =
        if (src_ty.isAbiInt(zcu)) src_ty.intInfo(zcu).signedness else .unsigned;
    if (extra_bits > 0) try self.genShiftBinOpMir(switch (signedness) {
        .signed => .{ ._r, .sa },
        .unsigned => .{ ._r, .sh },
    }, src_ty, dst_mcv, Type.u8, .{ .immediate = extra_bits });

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn floatSign(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, ty: Type) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];

    const result = result: {
        const scalar_bits = ty.scalarType(zcu).floatBits(self.target.*);
        if (scalar_bits == 80) {
            if (ty.zigTypeTag(zcu) != .float) return self.fail("TODO implement floatSign for {}", .{
                ty.fmt(pt),
            });

            const src_mcv = try self.resolveInst(operand);
            const src_lock = if (src_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
            defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

            const dst_mcv: MCValue = .{ .register = .st0 };
            if (!std.meta.eql(src_mcv, dst_mcv) or !self.reuseOperand(inst, operand, 0, src_mcv))
                try self.register_manager.getKnownReg(.st0, inst);

            try self.genCopy(ty, dst_mcv, src_mcv, .{});
            switch (tag) {
                .neg => try self.asmOpOnly(.{ .f_, .chs }),
                .abs => try self.asmOpOnly(.{ .f_, .abs }),
                else => unreachable,
            }
            break :result dst_mcv;
        }

        const abi_size: u32 = switch (ty.abiSize(zcu)) {
            1...16 => 16,
            17...32 => 32,
            else => return self.fail("TODO implement floatSign for {}", .{
                ty.fmt(pt),
            }),
        };

        const src_mcv = try self.resolveInst(operand);
        const src_lock = if (src_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
        defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mcv: MCValue = if (src_mcv.isRegister() and
            self.reuseOperand(inst, operand, 0, src_mcv))
            src_mcv
        else if (self.hasFeature(.avx))
            .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
        else
            try self.copyToRegisterWithInstTracking(inst, ty, src_mcv);
        const dst_reg = dst_mcv.getReg().?;
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const vec_ty = try pt.vectorType(.{
            .len = @divExact(abi_size * 8, scalar_bits),
            .child = (try pt.intType(.signed, scalar_bits)).ip_index,
        });

        const sign_mcv = try self.genTypedValue(switch (tag) {
            .neg => try vec_ty.minInt(pt, vec_ty),
            .abs => try vec_ty.maxInt(pt, vec_ty),
            else => unreachable,
        });
        const sign_mem: Memory = if (sign_mcv.isMemory())
            try sign_mcv.mem(self, Memory.Size.fromSize(abi_size))
        else
            .{
                .base = .{ .reg = try self.copyToTmpRegister(Type.usize, sign_mcv.address()) },
                .mod = .{ .rm = .{ .size = Memory.Size.fromSize(abi_size) } },
            };

        if (self.hasFeature(.avx)) try self.asmRegisterRegisterMemory(
            switch (scalar_bits) {
                16, 128 => if (abi_size <= 16 or self.hasFeature(.avx2)) switch (tag) {
                    .neg => .{ .vp_, .xor },
                    .abs => .{ .vp_, .@"and" },
                    else => unreachable,
                } else switch (tag) {
                    .neg => .{ .v_ps, .xor },
                    .abs => .{ .v_ps, .@"and" },
                    else => unreachable,
                },
                32 => switch (tag) {
                    .neg => .{ .v_ps, .xor },
                    .abs => .{ .v_ps, .@"and" },
                    else => unreachable,
                },
                64 => switch (tag) {
                    .neg => .{ .v_pd, .xor },
                    .abs => .{ .v_pd, .@"and" },
                    else => unreachable,
                },
                80 => return self.fail("TODO implement floatSign for {}", .{ty.fmt(pt)}),
                else => unreachable,
            },
            registerAlias(dst_reg, abi_size),
            registerAlias(if (src_mcv.isRegister())
                src_mcv.getReg().?
            else
                try self.copyToTmpRegister(ty, src_mcv), abi_size),
            sign_mem,
        ) else try self.asmRegisterMemory(
            switch (scalar_bits) {
                16, 128 => switch (tag) {
                    .neg => .{ .p_, .xor },
                    .abs => .{ .p_, .@"and" },
                    else => unreachable,
                },
                32 => switch (tag) {
                    .neg => .{ ._ps, .xor },
                    .abs => .{ ._ps, .@"and" },
                    else => unreachable,
                },
                64 => switch (tag) {
                    .neg => .{ ._pd, .xor },
                    .abs => .{ ._pd, .@"and" },
                    else => unreachable,
                },
                80 => return self.fail("TODO implement floatSign for {}", .{ty.fmt(pt)}),
                else => unreachable,
            },
            registerAlias(dst_reg, abi_size),
            sign_mem,
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ operand, .none, .none });
}

fn airFloatSign(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ty = self.typeOf(un_op);
    return self.floatSign(inst, un_op, ty);
}

const RoundMode = packed struct(u5) {
    mode: enum(u4) {
        /// Round to nearest (even)
        nearest = 0b0_00,
        /// Round down (toward -∞)
        down = 0b0_01,
        /// Round up (toward +∞)
        up = 0b0_10,
        /// Round toward zero (truncate)
        zero = 0b0_11,
        /// Use current rounding mode of MXCSR.RC
        mxcsr = 0b1_00,
    },
    precision: enum(u1) {
        normal = 0b0,
        inexact = 0b1,
    } = .normal,
};

fn airRound(self: *Self, inst: Air.Inst.Index, mode: RoundMode) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ty = self.typeOf(un_op);

    const result = result: {
        switch (try self.genRoundLibcall(ty, .{ .air_ref = un_op }, mode)) {
            .none => {},
            else => |dst_mcv| break :result dst_mcv,
        }

        const src_mcv = try self.resolveInst(un_op);
        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, un_op, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, ty, src_mcv);
        const dst_reg = dst_mcv.getReg().?;
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);
        try self.genRound(ty, dst_reg, src_mcv, mode);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn getRoundTag(self: *Self, ty: Type) ?Mir.Inst.FixedTag {
    const pt = self.pt;
    const zcu = pt.zcu;
    return if (self.hasFeature(.sse4_1)) switch (ty.zigTypeTag(zcu)) {
        .float => switch (ty.floatBits(self.target.*)) {
            32 => if (self.hasFeature(.avx)) .{ .v_ss, .round } else .{ ._ss, .round },
            64 => if (self.hasFeature(.avx)) .{ .v_sd, .round } else .{ ._sd, .round },
            16, 80, 128 => null,
            else => unreachable,
        },
        .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
            .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                32 => switch (ty.vectorLen(zcu)) {
                    1 => if (self.hasFeature(.avx)) .{ .v_ss, .round } else .{ ._ss, .round },
                    2...4 => if (self.hasFeature(.avx)) .{ .v_ps, .round } else .{ ._ps, .round },
                    5...8 => if (self.hasFeature(.avx)) .{ .v_ps, .round } else null,
                    else => null,
                },
                64 => switch (ty.vectorLen(zcu)) {
                    1 => if (self.hasFeature(.avx)) .{ .v_sd, .round } else .{ ._sd, .round },
                    2 => if (self.hasFeature(.avx)) .{ .v_pd, .round } else .{ ._pd, .round },
                    3...4 => if (self.hasFeature(.avx)) .{ .v_pd, .round } else null,
                    else => null,
                },
                16, 80, 128 => null,
                else => unreachable,
            },
            else => null,
        },
        else => unreachable,
    } else null;
}

fn genRoundLibcall(self: *Self, ty: Type, src_mcv: MCValue, mode: RoundMode) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    if (self.getRoundTag(ty)) |_| return .none;

    if (ty.zigTypeTag(zcu) != .float)
        return self.fail("TODO implement genRound for {}", .{ty.fmt(pt)});

    var callee_buf: ["__trunc?".len]u8 = undefined;
    return try self.genCall(.{ .lib = .{
        .return_type = ty.toIntern(),
        .param_types = &.{ty.toIntern()},
        .callee = std.fmt.bufPrint(&callee_buf, "{s}{s}{s}", .{
            floatLibcAbiPrefix(ty),
            switch (mode.mode) {
                .down => "floor",
                .up => "ceil",
                .zero => "trunc",
                else => unreachable,
            },
            floatLibcAbiSuffix(ty),
        }) catch unreachable,
    } }, &.{ty}, &.{src_mcv});
}

fn genRound(self: *Self, ty: Type, dst_reg: Register, src_mcv: MCValue, mode: RoundMode) !void {
    const pt = self.pt;
    const mir_tag = self.getRoundTag(ty) orelse {
        const result = try self.genRoundLibcall(ty, src_mcv, mode);
        return self.genSetReg(dst_reg, ty, result, .{});
    };
    const abi_size: u32 = @intCast(ty.abiSize(pt.zcu));
    const dst_alias = registerAlias(dst_reg, abi_size);
    switch (mir_tag[0]) {
        .v_ss, .v_sd => if (src_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
            mir_tag,
            dst_alias,
            dst_alias,
            try src_mcv.mem(self, Memory.Size.fromSize(abi_size)),
            Immediate.u(@as(u5, @bitCast(mode))),
        ) else try self.asmRegisterRegisterRegisterImmediate(
            mir_tag,
            dst_alias,
            dst_alias,
            registerAlias(if (src_mcv.isRegister())
                src_mcv.getReg().?
            else
                try self.copyToTmpRegister(ty, src_mcv), abi_size),
            Immediate.u(@as(u5, @bitCast(mode))),
        ),
        else => if (src_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
            mir_tag,
            dst_alias,
            try src_mcv.mem(self, Memory.Size.fromSize(abi_size)),
            Immediate.u(@as(u5, @bitCast(mode))),
        ) else try self.asmRegisterRegisterImmediate(
            mir_tag,
            dst_alias,
            registerAlias(if (src_mcv.isRegister())
                src_mcv.getReg().?
            else
                try self.copyToTmpRegister(ty, src_mcv), abi_size),
            Immediate.u(@as(u5, @bitCast(mode))),
        ),
    }
}

fn airAbs(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const ty = self.typeOf(ty_op.operand);

    const result: MCValue = result: {
        const mir_tag = @as(?Mir.Inst.FixedTag, switch (ty.zigTypeTag(zcu)) {
            else => null,
            .int => switch (ty.abiSize(zcu)) {
                0 => unreachable,
                1...8 => {
                    try self.spillEflagsIfOccupied();
                    const src_mcv = try self.resolveInst(ty_op.operand);
                    const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ty, src_mcv);

                    try self.genUnOpMir(.{ ._, .neg }, ty, dst_mcv);

                    const cmov_abi_size = @max(@as(u32, @intCast(ty.abiSize(zcu))), 2);
                    switch (src_mcv) {
                        .register => |val_reg| try self.asmCmovccRegisterRegister(
                            .l,
                            registerAlias(dst_mcv.register, cmov_abi_size),
                            registerAlias(val_reg, cmov_abi_size),
                        ),
                        .memory, .indirect, .load_frame => try self.asmCmovccRegisterMemory(
                            .l,
                            registerAlias(dst_mcv.register, cmov_abi_size),
                            try src_mcv.mem(self, Memory.Size.fromSize(cmov_abi_size)),
                        ),
                        else => {
                            const val_reg = try self.copyToTmpRegister(ty, src_mcv);
                            try self.asmCmovccRegisterRegister(
                                .l,
                                registerAlias(dst_mcv.register, cmov_abi_size),
                                registerAlias(val_reg, cmov_abi_size),
                            );
                        },
                    }
                    break :result dst_mcv;
                },
                9...16 => {
                    try self.spillEflagsIfOccupied();
                    const src_mcv = try self.resolveInst(ty_op.operand);
                    const dst_mcv = if (src_mcv == .register_pair and
                        self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) src_mcv else dst: {
                        const dst_regs = try self.register_manager.allocRegs(
                            2,
                            .{ inst, inst },
                            abi.RegisterClass.gp,
                        );
                        const dst_mcv: MCValue = .{ .register_pair = dst_regs };
                        const dst_locks = self.register_manager.lockRegsAssumeUnused(2, dst_regs);
                        defer for (dst_locks) |lock| self.register_manager.unlockReg(lock);

                        try self.genCopy(ty, dst_mcv, src_mcv, .{});
                        break :dst dst_mcv;
                    };
                    const dst_regs = dst_mcv.register_pair;
                    const dst_locks = self.register_manager.lockRegs(2, dst_regs);
                    defer for (dst_locks) |dst_lock| if (dst_lock) |lock|
                        self.register_manager.unlockReg(lock);

                    const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    try self.asmRegisterRegister(.{ ._, .mov }, tmp_reg, dst_regs[1]);
                    try self.asmRegisterImmediate(.{ ._r, .sa }, tmp_reg, Immediate.u(63));
                    try self.asmRegisterRegister(.{ ._, .xor }, dst_regs[0], tmp_reg);
                    try self.asmRegisterRegister(.{ ._, .xor }, dst_regs[1], tmp_reg);
                    try self.asmRegisterRegister(.{ ._, .sub }, dst_regs[0], tmp_reg);
                    try self.asmRegisterRegister(.{ ._, .sbb }, dst_regs[1], tmp_reg);

                    break :result dst_mcv;
                },
                else => {
                    const abi_size: u31 = @intCast(ty.abiSize(zcu));
                    const limb_len = math.divCeil(u31, abi_size, 8) catch unreachable;

                    const tmp_regs =
                        try self.register_manager.allocRegs(3, .{null} ** 3, abi.RegisterClass.gp);
                    const tmp_locks = self.register_manager.lockRegsAssumeUnused(3, tmp_regs);
                    defer for (tmp_locks) |lock| self.register_manager.unlockReg(lock);

                    try self.spillEflagsIfOccupied();
                    const src_mcv = try self.resolveInst(ty_op.operand);
                    const dst_mcv = if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                        src_mcv
                    else
                        try self.allocRegOrMem(inst, false);

                    try self.asmMemoryImmediate(
                        .{ ._, .cmp },
                        try dst_mcv.address().offset((limb_len - 1) * 8).deref().mem(self, .qword),
                        Immediate.u(0),
                    );
                    const positive = try self.asmJccReloc(.ns, undefined);

                    try self.asmRegisterRegister(.{ ._, .xor }, tmp_regs[0].to32(), tmp_regs[0].to32());
                    try self.asmRegisterRegister(.{ ._, .xor }, tmp_regs[1].to8(), tmp_regs[1].to8());

                    const neg_loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                    try self.asmRegisterRegister(.{ ._, .xor }, tmp_regs[2].to32(), tmp_regs[2].to32());
                    try self.asmRegisterImmediate(.{ ._r, .sh }, tmp_regs[1].to8(), Immediate.u(1));
                    try self.asmRegisterMemory(.{ ._, .sbb }, tmp_regs[2].to64(), .{
                        .base = .{ .frame = dst_mcv.load_frame.index },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .index = tmp_regs[0].to64(),
                            .scale = .@"8",
                            .disp = dst_mcv.load_frame.off,
                        } },
                    });
                    try self.asmSetccRegister(.c, tmp_regs[1].to8());
                    try self.asmMemoryRegister(.{ ._, .mov }, .{
                        .base = .{ .frame = dst_mcv.load_frame.index },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .index = tmp_regs[0].to64(),
                            .scale = .@"8",
                            .disp = dst_mcv.load_frame.off,
                        } },
                    }, tmp_regs[2].to64());

                    if (self.hasFeature(.slow_incdec)) {
                        try self.asmRegisterImmediate(.{ ._, .add }, tmp_regs[0].to32(), Immediate.u(1));
                    } else {
                        try self.asmRegister(.{ ._, .inc }, tmp_regs[0].to32());
                    }
                    try self.asmRegisterImmediate(.{ ._, .cmp }, tmp_regs[0].to32(), Immediate.u(limb_len));
                    _ = try self.asmJccReloc(.b, neg_loop);

                    self.performReloc(positive);
                    break :result dst_mcv;
                },
            },
            .float => return self.floatSign(inst, ty_op.operand, ty),
            .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                else => null,
                .int => switch (ty.childType(zcu).intInfo(zcu).bits) {
                    else => null,
                    8 => switch (ty.vectorLen(zcu)) {
                        else => null,
                        1...16 => if (self.hasFeature(.avx))
                            .{ .vp_b, .abs }
                        else if (self.hasFeature(.ssse3))
                            .{ .p_b, .abs }
                        else
                            null,
                        17...32 => if (self.hasFeature(.avx2)) .{ .vp_b, .abs } else null,
                    },
                    16 => switch (ty.vectorLen(zcu)) {
                        else => null,
                        1...8 => if (self.hasFeature(.avx))
                            .{ .vp_w, .abs }
                        else if (self.hasFeature(.ssse3))
                            .{ .p_w, .abs }
                        else
                            null,
                        9...16 => if (self.hasFeature(.avx2)) .{ .vp_w, .abs } else null,
                    },
                    32 => switch (ty.vectorLen(zcu)) {
                        else => null,
                        1...4 => if (self.hasFeature(.avx))
                            .{ .vp_d, .abs }
                        else if (self.hasFeature(.ssse3))
                            .{ .p_d, .abs }
                        else
                            null,
                        5...8 => if (self.hasFeature(.avx2)) .{ .vp_d, .abs } else null,
                    },
                },
                .float => return self.floatSign(inst, ty_op.operand, ty),
            },
        }) orelse return self.fail("TODO implement airAbs for {}", .{ty.fmt(pt)});

        const abi_size: u32 = @intCast(ty.abiSize(zcu));
        const src_mcv = try self.resolveInst(ty_op.operand);
        const dst_reg = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv.getReg().?
        else
            try self.register_manager.allocReg(inst, self.regClassForType(ty));
        const dst_alias = registerAlias(dst_reg, abi_size);
        if (src_mcv.isMemory()) try self.asmRegisterMemory(
            mir_tag,
            dst_alias,
            try src_mcv.mem(self, self.memSize(ty)),
        ) else try self.asmRegisterRegister(
            mir_tag,
            dst_alias,
            registerAlias(if (src_mcv.isRegister())
                src_mcv.getReg().?
            else
                try self.copyToTmpRegister(ty, src_mcv), abi_size),
        );
        break :result .{ .register = dst_reg };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSqrt(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ty = self.typeOf(un_op);
    const abi_size: u32 = @intCast(ty.abiSize(zcu));

    const result: MCValue = result: {
        switch (ty.zigTypeTag(zcu)) {
            .float => {
                const float_bits = ty.floatBits(self.target.*);
                if (switch (float_bits) {
                    16 => !self.hasFeature(.f16c),
                    32, 64 => false,
                    80, 128 => true,
                    else => unreachable,
                }) {
                    var callee_buf: ["__sqrt?".len]u8 = undefined;
                    break :result try self.genCall(.{ .lib = .{
                        .return_type = ty.toIntern(),
                        .param_types = &.{ty.toIntern()},
                        .callee = std.fmt.bufPrint(&callee_buf, "{s}sqrt{s}", .{
                            floatLibcAbiPrefix(ty),
                            floatLibcAbiSuffix(ty),
                        }) catch unreachable,
                    } }, &.{ty}, &.{.{ .air_ref = un_op }});
                }
            },
            else => {},
        }

        const src_mcv = try self.resolveInst(un_op);
        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, un_op, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, ty, src_mcv);
        const dst_reg = registerAlias(dst_mcv.getReg().?, abi_size);
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const mir_tag = @as(?Mir.Inst.FixedTag, switch (ty.zigTypeTag(zcu)) {
            .float => switch (ty.floatBits(self.target.*)) {
                16 => {
                    assert(self.hasFeature(.f16c));
                    const mat_src_reg = if (src_mcv.isRegister())
                        src_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(ty, src_mcv);
                    try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, dst_reg, mat_src_reg.to128());
                    try self.asmRegisterRegisterRegister(.{ .v_ss, .sqrt }, dst_reg, dst_reg, dst_reg);
                    try self.asmRegisterRegisterImmediate(
                        .{ .v_, .cvtps2ph },
                        dst_reg,
                        dst_reg,
                        Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                    );
                    break :result dst_mcv;
                },
                32 => if (self.hasFeature(.avx)) .{ .v_ss, .sqrt } else .{ ._ss, .sqrt },
                64 => if (self.hasFeature(.avx)) .{ .v_sd, .sqrt } else .{ ._sd, .sqrt },
                else => unreachable,
            },
            .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                    16 => if (self.hasFeature(.f16c)) switch (ty.vectorLen(zcu)) {
                        1 => {
                            try self.asmRegisterRegister(
                                .{ .v_ps, .cvtph2 },
                                dst_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(ty, src_mcv)).to128(),
                            );
                            try self.asmRegisterRegisterRegister(
                                .{ .v_ss, .sqrt },
                                dst_reg,
                                dst_reg,
                                dst_reg,
                            );
                            try self.asmRegisterRegisterImmediate(
                                .{ .v_, .cvtps2ph },
                                dst_reg,
                                dst_reg,
                                Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                            );
                            break :result dst_mcv;
                        },
                        2...8 => {
                            const wide_reg = registerAlias(dst_reg, abi_size * 2);
                            if (src_mcv.isMemory()) try self.asmRegisterMemory(
                                .{ .v_ps, .cvtph2 },
                                wide_reg,
                                try src_mcv.mem(self, Memory.Size.fromSize(
                                    @intCast(@divExact(wide_reg.bitSize(), 16)),
                                )),
                            ) else try self.asmRegisterRegister(
                                .{ .v_ps, .cvtph2 },
                                wide_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(ty, src_mcv)).to128(),
                            );
                            try self.asmRegisterRegister(.{ .v_ps, .sqrt }, wide_reg, wide_reg);
                            try self.asmRegisterRegisterImmediate(
                                .{ .v_, .cvtps2ph },
                                dst_reg,
                                wide_reg,
                                Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                            );
                            break :result dst_mcv;
                        },
                        else => null,
                    } else null,
                    32 => switch (ty.vectorLen(zcu)) {
                        1 => if (self.hasFeature(.avx)) .{ .v_ss, .sqrt } else .{ ._ss, .sqrt },
                        2...4 => if (self.hasFeature(.avx)) .{ .v_ps, .sqrt } else .{ ._ps, .sqrt },
                        5...8 => if (self.hasFeature(.avx)) .{ .v_ps, .sqrt } else null,
                        else => null,
                    },
                    64 => switch (ty.vectorLen(zcu)) {
                        1 => if (self.hasFeature(.avx)) .{ .v_sd, .sqrt } else .{ ._sd, .sqrt },
                        2 => if (self.hasFeature(.avx)) .{ .v_pd, .sqrt } else .{ ._pd, .sqrt },
                        3...4 => if (self.hasFeature(.avx)) .{ .v_pd, .sqrt } else null,
                        else => null,
                    },
                    80, 128 => null,
                    else => unreachable,
                },
                else => unreachable,
            },
            else => unreachable,
        }) orelse return self.fail("TODO implement airSqrt for {}", .{
            ty.fmt(pt),
        });
        switch (mir_tag[0]) {
            .v_ss, .v_sd => if (src_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                mir_tag,
                dst_reg,
                dst_reg,
                try src_mcv.mem(self, Memory.Size.fromSize(abi_size)),
            ) else try self.asmRegisterRegisterRegister(
                mir_tag,
                dst_reg,
                dst_reg,
                registerAlias(if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(ty, src_mcv), abi_size),
            ),
            else => if (src_mcv.isMemory()) try self.asmRegisterMemory(
                mir_tag,
                dst_reg,
                try src_mcv.mem(self, Memory.Size.fromSize(abi_size)),
            ) else try self.asmRegisterRegister(
                mir_tag,
                dst_reg,
                registerAlias(if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(ty, src_mcv), abi_size),
            ),
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airUnaryMath(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ty = self.typeOf(un_op);
    var callee_buf: ["__round?".len]u8 = undefined;
    const result = try self.genCall(.{ .lib = .{
        .return_type = ty.toIntern(),
        .param_types = &.{ty.toIntern()},
        .callee = std.fmt.bufPrint(&callee_buf, "{s}{s}{s}", .{
            floatLibcAbiPrefix(ty),
            switch (tag) {
                .sin,
                .cos,
                .tan,
                .exp,
                .exp2,
                .log,
                .log2,
                .log10,
                .round,
                => @tagName(tag),
                else => unreachable,
            },
            floatLibcAbiSuffix(ty),
        }) catch unreachable,
    } }, &.{ty}, &.{.{ .air_ref = un_op }});
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn reuseOperand(
    self: *Self,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    op_index: Liveness.OperandInt,
    mcv: MCValue,
) bool {
    return self.reuseOperandAdvanced(inst, operand, op_index, mcv, inst);
}

fn reuseOperandAdvanced(
    self: *Self,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    op_index: Liveness.OperandInt,
    mcv: MCValue,
    maybe_tracked_inst: ?Air.Inst.Index,
) bool {
    if (!self.liveness.operandDies(inst, op_index))
        return false;

    switch (mcv) {
        .register, .register_pair, .register_overflow => for (mcv.getRegs()) |reg| {
            // If it's in the registers table, need to associate the register(s) with the
            // new instruction.
            if (maybe_tracked_inst) |tracked_inst| {
                if (!self.register_manager.isRegFree(reg)) {
                    if (RegisterManager.indexOfRegIntoTracked(reg)) |index| {
                        self.register_manager.registers[index] = tracked_inst;
                    }
                }
            } else self.register_manager.freeReg(reg);
        },
        .load_frame => |frame_addr| if (frame_addr.index.isNamed()) return false,
        else => return false,
    }
    switch (mcv) {
        .eflags, .register_overflow => self.eflags_inst = maybe_tracked_inst,
        else => {},
    }

    // Prevent the operand deaths processing code from deallocating it.
    self.liveness.clearOperandDeath(inst, op_index);
    const op_inst = operand.toIndex().?;
    self.getResolvedInstValue(op_inst).reuse(self, maybe_tracked_inst, op_inst);

    return true;
}

fn packedLoad(self: *Self, dst_mcv: MCValue, ptr_ty: Type, ptr_mcv: MCValue) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;

    const ptr_info = ptr_ty.ptrInfo(zcu);
    const val_ty = Type.fromInterned(ptr_info.child);
    if (!val_ty.hasRuntimeBitsIgnoreComptime(zcu)) return;
    const val_abi_size: u32 = @intCast(val_ty.abiSize(zcu));

    const val_bit_size: u32 = @intCast(val_ty.bitSize(zcu));
    const ptr_bit_off = ptr_info.packed_offset.bit_offset + switch (ptr_info.flags.vector_index) {
        .none => 0,
        .runtime => unreachable,
        else => |vector_index| @intFromEnum(vector_index) * val_bit_size,
    };
    if (ptr_bit_off % 8 == 0) {
        {
            const mat_ptr_mcv: MCValue = switch (ptr_mcv) {
                .immediate, .register, .register_offset, .lea_frame => ptr_mcv,
                else => .{ .register = try self.copyToTmpRegister(ptr_ty, ptr_mcv) },
            };
            const mat_ptr_lock = switch (mat_ptr_mcv) {
                .register => |mat_ptr_reg| self.register_manager.lockReg(mat_ptr_reg),
                else => null,
            };
            defer if (mat_ptr_lock) |lock| self.register_manager.unlockReg(lock);

            try self.load(dst_mcv, ptr_ty, mat_ptr_mcv.offset(@intCast(@divExact(ptr_bit_off, 8))));
        }

        if (val_abi_size * 8 > val_bit_size) {
            if (dst_mcv.isRegister()) {
                try self.truncateRegister(val_ty, dst_mcv.getReg().?);
            } else {
                const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                defer self.register_manager.unlockReg(tmp_lock);

                const hi_mcv = dst_mcv.address().offset(@intCast(val_bit_size / 64 * 8)).deref();
                try self.genSetReg(tmp_reg, Type.usize, hi_mcv, .{});
                try self.truncateRegister(val_ty, tmp_reg);
                try self.genCopy(Type.usize, hi_mcv, .{ .register = tmp_reg }, .{});
            }
        }
        return;
    }

    if (val_abi_size > 8) return self.fail("TODO implement packed load of {}", .{val_ty.fmt(pt)});

    const limb_abi_size: u31 = @min(val_abi_size, 8);
    const limb_abi_bits = limb_abi_size * 8;
    const val_byte_off: i32 = @intCast(ptr_bit_off / limb_abi_bits * limb_abi_size);
    const val_bit_off = ptr_bit_off % limb_abi_bits;
    const val_extra_bits = self.regExtraBits(val_ty);

    const ptr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
    const ptr_lock = self.register_manager.lockRegAssumeUnused(ptr_reg);
    defer self.register_manager.unlockReg(ptr_lock);

    const dst_reg = switch (dst_mcv) {
        .register => |reg| reg,
        else => try self.register_manager.allocReg(null, abi.RegisterClass.gp),
    };
    const dst_lock = self.register_manager.lockReg(dst_reg);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const load_abi_size =
        if (val_bit_off < val_extra_bits) val_abi_size else val_abi_size * 2;
    if (load_abi_size <= 8) {
        const load_reg = registerAlias(dst_reg, load_abi_size);
        try self.asmRegisterMemory(.{ ._, .mov }, load_reg, .{
            .base = .{ .reg = ptr_reg },
            .mod = .{ .rm = .{
                .size = Memory.Size.fromSize(load_abi_size),
                .disp = val_byte_off,
            } },
        });
        try self.spillEflagsIfOccupied();
        try self.asmRegisterImmediate(.{ ._r, .sh }, load_reg, Immediate.u(val_bit_off));
    } else {
        const tmp_reg =
            registerAlias(try self.register_manager.allocReg(null, abi.RegisterClass.gp), val_abi_size);
        const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
        defer self.register_manager.unlockReg(tmp_lock);

        const dst_alias = registerAlias(dst_reg, val_abi_size);
        try self.asmRegisterMemory(.{ ._, .mov }, dst_alias, .{
            .base = .{ .reg = ptr_reg },
            .mod = .{ .rm = .{
                .size = Memory.Size.fromSize(val_abi_size),
                .disp = val_byte_off,
            } },
        });
        try self.asmRegisterMemory(.{ ._, .mov }, tmp_reg, .{
            .base = .{ .reg = ptr_reg },
            .mod = .{ .rm = .{
                .size = Memory.Size.fromSize(val_abi_size),
                .disp = val_byte_off + limb_abi_size,
            } },
        });
        try self.spillEflagsIfOccupied();
        try self.asmRegisterRegisterImmediate(
            .{ ._rd, .sh },
            dst_alias,
            tmp_reg,
            Immediate.u(val_bit_off),
        );
    }

    if (val_extra_bits > 0) try self.truncateRegister(val_ty, dst_reg);
    try self.genCopy(val_ty, dst_mcv, .{ .register = dst_reg }, .{});
}

fn load(self: *Self, dst_mcv: MCValue, ptr_ty: Type, ptr_mcv: MCValue) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const dst_ty = ptr_ty.childType(zcu);
    if (!dst_ty.hasRuntimeBitsIgnoreComptime(zcu)) return;
    switch (ptr_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .eflags,
        .register_pair,
        .register_overflow,
        .elementwise_regs_then_frame,
        .reserved_frame,
        => unreachable, // not a valid pointer
        .immediate,
        .register,
        .register_offset,
        .lea_symbol,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        => try self.genCopy(dst_ty, dst_mcv, ptr_mcv.deref(), .{}),
        .memory,
        .indirect,
        .load_symbol,
        .load_direct,
        .load_got,
        .load_tlv,
        .load_frame,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genCopy(dst_ty, dst_mcv, .{ .indirect = .{ .reg = addr_reg } }, .{});
        },
        .air_ref => |ptr_ref| try self.load(dst_mcv, ptr_ty, try self.resolveInst(ptr_ref)),
    }
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const elem_ty = self.typeOfIndex(inst);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;

        try self.spillRegisters(&.{ .rdi, .rsi, .rcx });
        const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rdi, .rsi, .rcx });
        defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

        const ptr_ty = self.typeOf(ty_op.operand);
        const elem_size = elem_ty.abiSize(zcu);

        const elem_rc = self.regClassForType(elem_ty);
        const ptr_rc = self.regClassForType(ptr_ty);

        const ptr_mcv = try self.resolveInst(ty_op.operand);
        const dst_mcv = if (elem_size <= 8 and elem_rc.supersetOf(ptr_rc) and
            self.reuseOperand(inst, ty_op.operand, 0, ptr_mcv))
            // The MCValue that holds the pointer can be re-used as the value.
            ptr_mcv
        else
            try self.allocRegOrMem(inst, true);

        const ptr_info = ptr_ty.ptrInfo(zcu);
        if (ptr_info.flags.vector_index != .none or ptr_info.packed_offset.host_size > 0) {
            try self.packedLoad(dst_mcv, ptr_ty, ptr_mcv);
        } else {
            try self.load(dst_mcv, ptr_ty, ptr_mcv);
        }

        if (elem_ty.isAbiInt(zcu) and elem_size * 8 > elem_ty.bitSize(zcu)) {
            const high_mcv: MCValue = switch (dst_mcv) {
                .register => |dst_reg| .{ .register = dst_reg },
                .register_pair => |dst_regs| .{ .register = dst_regs[1] },
                else => dst_mcv.address().offset(@intCast((elem_size - 1) / 8 * 8)).deref(),
            };
            const high_reg = if (high_mcv.isRegister())
                high_mcv.getReg().?
            else
                try self.copyToTmpRegister(Type.usize, high_mcv);
            const high_lock = self.register_manager.lockReg(high_reg);
            defer if (high_lock) |lock| self.register_manager.unlockReg(lock);

            try self.truncateRegister(elem_ty, high_reg);
            if (!high_mcv.isRegister()) try self.genCopy(
                if (elem_size <= 8) elem_ty else Type.usize,
                high_mcv,
                .{ .register = high_reg },
                .{},
            );
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn packedStore(self: *Self, ptr_ty: Type, ptr_mcv: MCValue, src_mcv: MCValue) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ptr_info = ptr_ty.ptrInfo(zcu);
    const src_ty = Type.fromInterned(ptr_info.child);
    if (!src_ty.hasRuntimeBitsIgnoreComptime(zcu)) return;

    const limb_abi_size: u16 = @min(ptr_info.packed_offset.host_size, 8);
    const limb_abi_bits = limb_abi_size * 8;
    const limb_ty = try pt.intType(.unsigned, limb_abi_bits);

    const src_bit_size = src_ty.bitSize(zcu);
    const ptr_bit_off = ptr_info.packed_offset.bit_offset + switch (ptr_info.flags.vector_index) {
        .none => 0,
        .runtime => unreachable,
        else => |vector_index| @intFromEnum(vector_index) * src_bit_size,
    };
    const src_byte_off: i32 = @intCast(ptr_bit_off / limb_abi_bits * limb_abi_size);
    const src_bit_off = ptr_bit_off % limb_abi_bits;

    const ptr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
    const ptr_lock = self.register_manager.lockRegAssumeUnused(ptr_reg);
    defer self.register_manager.unlockReg(ptr_lock);

    var limb_i: u16 = 0;
    while (limb_i * limb_abi_bits < src_bit_off + src_bit_size) : (limb_i += 1) {
        const part_bit_off = if (limb_i == 0) src_bit_off else 0;
        const part_bit_size =
            @min(src_bit_off + src_bit_size - limb_i * limb_abi_bits, limb_abi_bits) - part_bit_off;
        const limb_mem: Memory = .{
            .base = .{ .reg = ptr_reg },
            .mod = .{ .rm = .{
                .size = Memory.Size.fromSize(limb_abi_size),
                .disp = src_byte_off + limb_i * limb_abi_size,
            } },
        };

        const part_mask = (@as(u64, math.maxInt(u64)) >> @intCast(64 - part_bit_size)) <<
            @intCast(part_bit_off);
        const part_mask_not = part_mask ^ (@as(u64, math.maxInt(u64)) >> @intCast(64 - limb_abi_bits));
        if (limb_abi_size <= 4) {
            try self.asmMemoryImmediate(.{ ._, .@"and" }, limb_mem, Immediate.u(part_mask_not));
        } else if (math.cast(i32, @as(i64, @bitCast(part_mask_not)))) |small| {
            try self.asmMemoryImmediate(.{ ._, .@"and" }, limb_mem, Immediate.s(small));
        } else {
            const part_mask_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            try self.asmRegisterImmediate(.{ ._, .mov }, part_mask_reg, Immediate.u(part_mask_not));
            try self.asmMemoryRegister(.{ ._, .@"and" }, limb_mem, part_mask_reg);
        }

        if (src_bit_size <= 64) {
            const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genSetReg(tmp_reg, limb_ty, src_mcv, .{});
            switch (limb_i) {
                0 => try self.genShiftBinOpMir(
                    .{ ._l, .sh },
                    limb_ty,
                    tmp_mcv,
                    Type.u8,
                    .{ .immediate = src_bit_off },
                ),
                1 => try self.genShiftBinOpMir(
                    .{ ._r, .sh },
                    limb_ty,
                    tmp_mcv,
                    Type.u8,
                    .{ .immediate = limb_abi_bits - src_bit_off },
                ),
                else => unreachable,
            }
            try self.genBinOpMir(.{ ._, .@"and" }, limb_ty, tmp_mcv, .{ .immediate = part_mask });
            try self.asmMemoryRegister(
                .{ ._, .@"or" },
                limb_mem,
                registerAlias(tmp_reg, limb_abi_size),
            );
        } else if (src_bit_size <= 128 and src_bit_off == 0) {
            const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genSetReg(tmp_reg, limb_ty, switch (limb_i) {
                0 => src_mcv,
                else => src_mcv.address().offset(limb_i * limb_abi_size).deref(),
            }, .{});
            try self.genBinOpMir(.{ ._, .@"and" }, limb_ty, tmp_mcv, .{ .immediate = part_mask });
            try self.asmMemoryRegister(
                .{ ._, .@"or" },
                limb_mem,
                registerAlias(tmp_reg, limb_abi_size),
            );
        } else return self.fail("TODO: implement packed store of {}", .{src_ty.fmt(pt)});
    }
}

fn store(
    self: *Self,
    ptr_ty: Type,
    ptr_mcv: MCValue,
    src_mcv: MCValue,
    opts: CopyOptions,
) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const src_ty = ptr_ty.childType(zcu);
    if (!src_ty.hasRuntimeBitsIgnoreComptime(zcu)) return;
    switch (ptr_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .eflags,
        .register_pair,
        .register_overflow,
        .elementwise_regs_then_frame,
        .reserved_frame,
        => unreachable, // not a valid pointer
        .immediate,
        .register,
        .register_offset,
        .lea_symbol,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        => try self.genCopy(src_ty, ptr_mcv.deref(), src_mcv, opts),
        .memory,
        .indirect,
        .load_symbol,
        .load_direct,
        .load_got,
        .load_tlv,
        .load_frame,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genCopy(src_ty, .{ .indirect = .{ .reg = addr_reg } }, src_mcv, opts);
        },
        .air_ref => |ptr_ref| try self.store(ptr_ty, try self.resolveInst(ptr_ref), src_mcv, opts),
    }
}

fn airStore(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    result: {
        if (!safety and (try self.resolveInst(bin_op.rhs)) == .undef) break :result;

        try self.spillRegisters(&.{ .rdi, .rsi, .rcx });
        const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rdi, .rsi, .rcx });
        defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

        const src_mcv = try self.resolveInst(bin_op.rhs);
        const ptr_mcv = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);

        const ptr_info = ptr_ty.ptrInfo(zcu);
        if (ptr_info.flags.vector_index != .none or ptr_info.packed_offset.host_size > 0) {
            try self.packedStore(ptr_ty, ptr_mcv, src_mcv);
        } else {
            try self.store(ptr_ty, ptr_mcv, src_mcv, .{ .safety = safety });
        }
    }
    return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airStructFieldPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const result = try self.fieldPtr(inst, extra.struct_operand, extra.field_index);
    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u8) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = try self.fieldPtr(inst, ty_op.operand, index);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn fieldPtr(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, index: u32) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ptr_field_ty = self.typeOfIndex(inst);
    const ptr_container_ty = self.typeOf(operand);
    const container_ty = ptr_container_ty.childType(zcu);

    const field_off: i32 = switch (container_ty.containerLayout(zcu)) {
        .auto, .@"extern" => @intCast(container_ty.structFieldOffset(index, zcu)),
        .@"packed" => @divExact(@as(i32, ptr_container_ty.ptrInfo(zcu).packed_offset.bit_offset) +
            (if (zcu.typeToStruct(container_ty)) |struct_obj| pt.structPackedFieldBitOffset(struct_obj, index) else 0) -
            ptr_field_ty.ptrInfo(zcu).packed_offset.bit_offset, 8),
    };

    const src_mcv = try self.resolveInst(operand);
    const dst_mcv = if (switch (src_mcv) {
        .immediate, .lea_frame => true,
        .register, .register_offset => self.reuseOperand(inst, operand, 0, src_mcv),
        else => false,
    }) src_mcv else try self.copyToRegisterWithInstTracking(inst, ptr_field_ty, src_mcv);
    return dst_mcv.offset(field_off);
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const result: MCValue = result: {
        const operand = extra.struct_operand;
        const index = extra.field_index;

        const container_ty = self.typeOf(operand);
        const container_rc = self.regClassForType(container_ty);
        const field_ty = container_ty.fieldType(index, zcu);
        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;
        const field_rc = self.regClassForType(field_ty);
        const field_is_gp = field_rc.supersetOf(abi.RegisterClass.gp);

        const src_mcv = try self.resolveInst(operand);
        const field_off: u32 = switch (container_ty.containerLayout(zcu)) {
            .auto, .@"extern" => @intCast(container_ty.structFieldOffset(extra.field_index, zcu) * 8),
            .@"packed" => if (zcu.typeToStruct(container_ty)) |struct_obj| pt.structPackedFieldBitOffset(struct_obj, extra.field_index) else 0,
        };

        switch (src_mcv) {
            .register => |src_reg| {
                const src_reg_lock = self.register_manager.lockRegAssumeUnused(src_reg);
                defer self.register_manager.unlockReg(src_reg_lock);

                const src_in_field_rc =
                    field_rc.isSet(RegisterManager.indexOfRegIntoTracked(src_reg).?);
                const dst_reg = if (src_in_field_rc and self.reuseOperand(inst, operand, 0, src_mcv))
                    src_reg
                else if (field_off == 0)
                    (try self.copyToRegisterWithInstTracking(inst, field_ty, src_mcv)).register
                else
                    try self.copyToTmpRegister(Type.usize, .{ .register = src_reg });
                const dst_mcv: MCValue = .{ .register = dst_reg };
                const dst_lock = self.register_manager.lockReg(dst_reg);
                defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

                if (field_off > 0) {
                    try self.spillEflagsIfOccupied();
                    try self.genShiftBinOpMir(
                        .{ ._r, .sh },
                        Type.usize,
                        dst_mcv,
                        Type.u8,
                        .{ .immediate = field_off },
                    );
                }
                if (abi.RegisterClass.gp.isSet(RegisterManager.indexOfRegIntoTracked(dst_reg).?) and
                    container_ty.abiSize(zcu) * 8 > field_ty.bitSize(zcu))
                    try self.truncateRegister(field_ty, dst_reg);

                break :result if (field_off == 0 or field_rc.supersetOf(abi.RegisterClass.gp))
                    dst_mcv
                else
                    try self.copyToRegisterWithInstTracking(inst, field_ty, dst_mcv);
            },
            .register_pair => |src_regs| {
                const src_regs_lock = self.register_manager.lockRegsAssumeUnused(2, src_regs);
                defer for (src_regs_lock) |lock| self.register_manager.unlockReg(lock);

                const field_bit_size: u32 = @intCast(field_ty.bitSize(zcu));
                const src_reg = if (field_off + field_bit_size <= 64)
                    src_regs[0]
                else if (field_off >= 64)
                    src_regs[1]
                else {
                    const dst_regs: [2]Register = if (field_rc.supersetOf(container_rc) and
                        self.reuseOperand(inst, operand, 0, src_mcv)) src_regs else dst: {
                        const dst_regs =
                            try self.register_manager.allocRegs(2, .{null} ** 2, field_rc);
                        const dst_locks = self.register_manager.lockRegsAssumeUnused(2, dst_regs);
                        defer for (dst_locks) |lock| self.register_manager.unlockReg(lock);

                        try self.genCopy(container_ty, .{ .register_pair = dst_regs }, src_mcv, .{});
                        break :dst dst_regs;
                    };
                    const dst_mcv = MCValue{ .register_pair = dst_regs };
                    const dst_locks = self.register_manager.lockRegs(2, dst_regs);
                    defer for (dst_locks) |dst_lock| if (dst_lock) |lock|
                        self.register_manager.unlockReg(lock);

                    if (field_off > 0) {
                        try self.spillEflagsIfOccupied();
                        try self.genShiftBinOpMir(
                            .{ ._r, .sh },
                            Type.u128,
                            dst_mcv,
                            Type.u8,
                            .{ .immediate = field_off },
                        );
                    }

                    if (field_bit_size <= 64) {
                        if (self.regExtraBits(field_ty) > 0)
                            try self.truncateRegister(field_ty, dst_regs[0]);
                        break :result if (field_rc.supersetOf(abi.RegisterClass.gp))
                            .{ .register = dst_regs[0] }
                        else
                            try self.copyToRegisterWithInstTracking(inst, field_ty, .{
                                .register = dst_regs[0],
                            });
                    }

                    if (field_bit_size < 128) try self.truncateRegister(
                        try pt.intType(.unsigned, @intCast(field_bit_size - 64)),
                        dst_regs[1],
                    );
                    break :result if (field_rc.supersetOf(abi.RegisterClass.gp))
                        dst_mcv
                    else
                        try self.copyToRegisterWithInstTracking(inst, field_ty, dst_mcv);
                };

                const dst_reg = try self.copyToTmpRegister(Type.usize, .{ .register = src_reg });
                const dst_mcv = MCValue{ .register = dst_reg };
                const dst_lock = self.register_manager.lockReg(dst_reg);
                defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

                if (field_off % 64 > 0) {
                    try self.spillEflagsIfOccupied();
                    try self.genShiftBinOpMir(
                        .{ ._r, .sh },
                        Type.usize,
                        dst_mcv,
                        Type.u8,
                        .{ .immediate = field_off % 64 },
                    );
                }
                if (self.regExtraBits(field_ty) > 0) try self.truncateRegister(field_ty, dst_reg);

                break :result if (field_rc.supersetOf(abi.RegisterClass.gp))
                    dst_mcv
                else
                    try self.copyToRegisterWithInstTracking(inst, field_ty, dst_mcv);
            },
            .register_overflow => |ro| {
                switch (index) {
                    // Get wrapped value for overflow operation.
                    0 => if (self.reuseOperand(inst, extra.struct_operand, 0, src_mcv)) {
                        self.eflags_inst = null; // actually stop tracking the overflow part
                        break :result .{ .register = ro.reg };
                    } else break :result try self.copyToRegisterWithInstTracking(
                        inst,
                        Type.usize,
                        .{ .register = ro.reg },
                    ),
                    // Get overflow bit.
                    1 => if (self.reuseOperandAdvanced(inst, extra.struct_operand, 0, src_mcv, null)) {
                        self.eflags_inst = inst; // actually keep tracking the overflow part
                        break :result .{ .eflags = ro.eflags };
                    } else {
                        const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
                        try self.asmSetccRegister(ro.eflags, dst_reg.to8());
                        break :result .{ .register = dst_reg.to8() };
                    },
                    else => unreachable,
                }
            },
            .load_frame => |frame_addr| {
                const field_abi_size: u32 = @intCast(field_ty.abiSize(zcu));
                if (field_off % 8 == 0) {
                    const field_byte_off = @divExact(field_off, 8);
                    const off_mcv = src_mcv.address().offset(@intCast(field_byte_off)).deref();
                    const field_bit_size = field_ty.bitSize(zcu);

                    if (field_abi_size <= 8) {
                        const int_ty = try pt.intType(
                            if (field_ty.isAbiInt(zcu)) field_ty.intInfo(zcu).signedness else .unsigned,
                            @intCast(field_bit_size),
                        );

                        const dst_reg = try self.register_manager.allocReg(
                            if (field_is_gp) inst else null,
                            abi.RegisterClass.gp,
                        );
                        const dst_mcv = MCValue{ .register = dst_reg };
                        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
                        defer self.register_manager.unlockReg(dst_lock);

                        try self.genCopy(int_ty, dst_mcv, off_mcv, .{});
                        if (self.regExtraBits(field_ty) > 0) try self.truncateRegister(int_ty, dst_reg);
                        break :result if (field_is_gp)
                            dst_mcv
                        else
                            try self.copyToRegisterWithInstTracking(inst, field_ty, dst_mcv);
                    }

                    const container_abi_size: u32 = @intCast(container_ty.abiSize(zcu));
                    const dst_mcv = if (field_byte_off + field_abi_size <= container_abi_size and
                        self.reuseOperand(inst, operand, 0, src_mcv))
                        off_mcv
                    else dst: {
                        const dst_mcv = try self.allocRegOrMem(inst, true);
                        try self.genCopy(field_ty, dst_mcv, off_mcv, .{});
                        break :dst dst_mcv;
                    };
                    if (field_abi_size * 8 > field_bit_size and dst_mcv.isMemory()) {
                        const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                        const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                        defer self.register_manager.unlockReg(tmp_lock);

                        const hi_mcv =
                            dst_mcv.address().offset(@intCast(field_bit_size / 64 * 8)).deref();
                        try self.genSetReg(tmp_reg, Type.usize, hi_mcv, .{});
                        try self.truncateRegister(field_ty, tmp_reg);
                        try self.genCopy(Type.usize, hi_mcv, .{ .register = tmp_reg }, .{});
                    }
                    break :result dst_mcv;
                }

                const limb_abi_size: u31 = @min(field_abi_size, 8);
                const limb_abi_bits = limb_abi_size * 8;
                const field_byte_off: i32 = @intCast(field_off / limb_abi_bits * limb_abi_size);
                const field_bit_off = field_off % limb_abi_bits;

                if (field_abi_size > 8) {
                    return self.fail("TODO implement struct_field_val with large packed field", .{});
                }

                const dst_reg = try self.register_manager.allocReg(
                    if (field_is_gp) inst else null,
                    abi.RegisterClass.gp,
                );
                const field_extra_bits = self.regExtraBits(field_ty);
                const load_abi_size =
                    if (field_bit_off < field_extra_bits) field_abi_size else field_abi_size * 2;
                if (load_abi_size <= 8) {
                    const load_reg = registerAlias(dst_reg, load_abi_size);
                    try self.asmRegisterMemory(.{ ._, .mov }, load_reg, .{
                        .base = .{ .frame = frame_addr.index },
                        .mod = .{ .rm = .{
                            .size = Memory.Size.fromSize(load_abi_size),
                            .disp = frame_addr.off + field_byte_off,
                        } },
                    });
                    try self.spillEflagsIfOccupied();
                    try self.asmRegisterImmediate(.{ ._r, .sh }, load_reg, Immediate.u(field_bit_off));
                } else {
                    const tmp_reg = registerAlias(
                        try self.register_manager.allocReg(null, abi.RegisterClass.gp),
                        field_abi_size,
                    );
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    const dst_alias = registerAlias(dst_reg, field_abi_size);
                    try self.asmRegisterMemory(
                        .{ ._, .mov },
                        dst_alias,
                        .{
                            .base = .{ .frame = frame_addr.index },
                            .mod = .{ .rm = .{
                                .size = Memory.Size.fromSize(field_abi_size),
                                .disp = frame_addr.off + field_byte_off,
                            } },
                        },
                    );
                    try self.asmRegisterMemory(.{ ._, .mov }, tmp_reg, .{
                        .base = .{ .frame = frame_addr.index },
                        .mod = .{ .rm = .{
                            .size = Memory.Size.fromSize(field_abi_size),
                            .disp = frame_addr.off + field_byte_off + limb_abi_size,
                        } },
                    });
                    try self.spillEflagsIfOccupied();
                    try self.asmRegisterRegisterImmediate(
                        .{ ._rd, .sh },
                        dst_alias,
                        tmp_reg,
                        Immediate.u(field_bit_off),
                    );
                }

                if (field_extra_bits > 0) try self.truncateRegister(field_ty, dst_reg);

                const dst_mcv = MCValue{ .register = dst_reg };
                break :result if (field_is_gp)
                    dst_mcv
                else
                    try self.copyToRegisterWithInstTracking(inst, field_ty, dst_mcv);
            },
            else => return self.fail("TODO implement airStructFieldVal for {}", .{src_mcv}),
        }
    };
    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    const inst_ty = self.typeOfIndex(inst);
    const parent_ty = inst_ty.childType(zcu);
    const field_off: i32 = switch (parent_ty.containerLayout(zcu)) {
        .auto, .@"extern" => @intCast(parent_ty.structFieldOffset(extra.field_index, zcu)),
        .@"packed" => @divExact(@as(i32, inst_ty.ptrInfo(zcu).packed_offset.bit_offset) +
            (if (zcu.typeToStruct(parent_ty)) |struct_obj| pt.structPackedFieldBitOffset(struct_obj, extra.field_index) else 0) -
            self.typeOf(extra.field_ptr).ptrInfo(zcu).packed_offset.bit_offset, 8),
    };

    const src_mcv = try self.resolveInst(extra.field_ptr);
    const dst_mcv = if (src_mcv.isRegisterOffset() and
        self.reuseOperand(inst, extra.field_ptr, 0, src_mcv))
        src_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, inst_ty, src_mcv);
    const result = dst_mcv.offset(-field_off);
    return self.finishAir(inst, result, .{ extra.field_ptr, .none, .none });
}

fn genUnOp(self: *Self, maybe_inst: ?Air.Inst.Index, tag: Air.Inst.Tag, src_air: Air.Inst.Ref) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const src_ty = self.typeOf(src_air);
    if (src_ty.zigTypeTag(zcu) == .vector)
        return self.fail("TODO implement genUnOp for {}", .{src_ty.fmt(pt)});

    var src_mcv = try self.resolveInst(src_air);
    switch (src_mcv) {
        .eflags => |cc| switch (tag) {
            .not => {
                if (maybe_inst) |inst| if (self.reuseOperand(inst, src_air, 0, src_mcv))
                    return .{ .eflags = cc.negate() };
                try self.spillEflagsIfOccupied();
                src_mcv = try self.resolveInst(src_air);
            },
            else => {},
        },
        else => {},
    }

    const src_lock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_mcv: MCValue = dst: {
        if (maybe_inst) |inst| if (self.reuseOperand(inst, src_air, 0, src_mcv)) break :dst src_mcv;

        const dst_mcv = try self.allocRegOrMemAdvanced(src_ty, maybe_inst, true);
        try self.genCopy(src_ty, dst_mcv, src_mcv, .{});
        break :dst dst_mcv;
    };
    const dst_lock = switch (dst_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const abi_size: u16 = @intCast(src_ty.abiSize(zcu));
    switch (tag) {
        .not => {
            const limb_abi_size: u16 = @min(abi_size, 8);
            const int_info = if (src_ty.ip_index == .bool_type)
                std.builtin.Type.Int{ .signedness = .unsigned, .bits = 1 }
            else
                src_ty.intInfo(zcu);
            var byte_off: i32 = 0;
            while (byte_off * 8 < int_info.bits) : (byte_off += limb_abi_size) {
                const limb_bits: u16 = @intCast(@min(switch (int_info.signedness) {
                    .signed => abi_size * 8,
                    .unsigned => int_info.bits,
                } - byte_off * 8, limb_abi_size * 8));
                const limb_ty = try pt.intType(int_info.signedness, limb_bits);
                const limb_mcv = switch (byte_off) {
                    0 => dst_mcv,
                    else => dst_mcv.address().offset(byte_off).deref(),
                };

                if (int_info.signedness == .unsigned and self.regExtraBits(limb_ty) > 0) {
                    const mask = @as(u64, math.maxInt(u64)) >> @intCast(64 - limb_bits);
                    try self.genBinOpMir(.{ ._, .xor }, limb_ty, limb_mcv, .{ .immediate = mask });
                } else try self.genUnOpMir(.{ ._, .not }, limb_ty, limb_mcv);
            }
        },
        .neg => {
            try self.genUnOpMir(.{ ._, .neg }, src_ty, dst_mcv);
            const bit_size = src_ty.intInfo(zcu).bits;
            if (abi_size * 8 > bit_size) {
                if (dst_mcv.isRegister()) {
                    try self.truncateRegister(src_ty, dst_mcv.getReg().?);
                } else {
                    const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    const hi_mcv = dst_mcv.address().offset(@intCast(bit_size / 64 * 8)).deref();
                    try self.genSetReg(tmp_reg, Type.usize, hi_mcv, .{});
                    try self.truncateRegister(src_ty, tmp_reg);
                    try self.genCopy(Type.usize, hi_mcv, .{ .register = tmp_reg }, .{});
                }
            }
        },
        else => unreachable,
    }
    return dst_mcv;
}

fn genUnOpMir(self: *Self, mir_tag: Mir.Inst.FixedTag, dst_ty: Type, dst_mcv: MCValue) !void {
    const pt = self.pt;
    const abi_size: u32 = @intCast(dst_ty.abiSize(pt.zcu));
    if (abi_size > 8) return self.fail("TODO implement {} for {}", .{ mir_tag, dst_ty.fmt(pt) });
    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .register_offset,
        .eflags,
        .register_overflow,
        .lea_symbol,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .elementwise_regs_then_frame,
        .reserved_frame,
        .air_ref,
        => unreachable, // unmodifiable destination
        .register => |dst_reg| try self.asmRegister(mir_tag, registerAlias(dst_reg, abi_size)),
        .register_pair => unreachable, // unimplemented
        .memory, .load_symbol, .load_got, .load_direct, .load_tlv => {
            const addr_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            try self.genSetReg(addr_reg, Type.usize, dst_mcv.address(), .{});
            try self.asmMemory(mir_tag, .{ .base = .{ .reg = addr_reg }, .mod = .{ .rm = .{
                .size = Memory.Size.fromSize(abi_size),
            } } });
        },
        .indirect, .load_frame => try self.asmMemory(
            mir_tag,
            try dst_mcv.mem(self, Memory.Size.fromSize(abi_size)),
        ),
    }
}

/// Clobbers .rcx for non-immediate shift value.
fn genShiftBinOpMir(
    self: *Self,
    tag: Mir.Inst.FixedTag,
    lhs_ty: Type,
    lhs_mcv: MCValue,
    rhs_ty: Type,
    rhs_mcv: MCValue,
) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size: u32 = @intCast(lhs_ty.abiSize(zcu));
    const shift_abi_size: u32 = @intCast(rhs_ty.abiSize(zcu));
    try self.spillEflagsIfOccupied();

    if (abi_size > 16) {
        const limbs_len = math.divCeil(u32, abi_size, 8) catch unreachable;
        assert(shift_abi_size >= 1 and shift_abi_size <= 2);

        const rcx_lock: ?RegisterLock = switch (rhs_mcv) {
            .immediate => |shift_imm| switch (shift_imm) {
                0 => return,
                else => null,
            },
            else => lock: {
                if (switch (rhs_mcv) {
                    .register => |rhs_reg| rhs_reg.id() != Register.rcx.id(),
                    else => true,
                }) {
                    self.register_manager.getRegAssumeFree(.rcx, null);
                    try self.genSetReg(.rcx, rhs_ty, rhs_mcv, .{});
                }
                break :lock self.register_manager.lockReg(.rcx);
            },
        };
        defer if (rcx_lock) |lock| self.register_manager.unlockReg(lock);

        const temp_regs = try self.register_manager.allocRegs(4, .{null} ** 4, abi.RegisterClass.gp);
        const temp_locks = self.register_manager.lockRegsAssumeUnused(4, temp_regs);
        defer for (temp_locks) |lock| self.register_manager.unlockReg(lock);

        switch (tag[0]) {
            ._l => {
                try self.asmRegisterImmediate(.{ ._, .mov }, temp_regs[1].to32(), Immediate.u(limbs_len - 1));
                switch (rhs_mcv) {
                    .immediate => |shift_imm| try self.asmRegisterImmediate(
                        .{ ._, .mov },
                        temp_regs[0].to32(),
                        Immediate.u(limbs_len - (shift_imm >> 6) - 1),
                    ),
                    else => {
                        try self.asmRegisterRegister(
                            .{ ._, .movzx },
                            temp_regs[2].to32(),
                            registerAlias(.rcx, shift_abi_size),
                        );
                        try self.asmRegisterImmediate(
                            .{ ._, .@"and" },
                            .cl,
                            Immediate.u(math.maxInt(u6)),
                        );
                        try self.asmRegisterImmediate(
                            .{ ._r, .sh },
                            temp_regs[2].to32(),
                            Immediate.u(6),
                        );
                        try self.asmRegisterRegister(
                            .{ ._, .mov },
                            temp_regs[0].to32(),
                            temp_regs[1].to32(),
                        );
                        try self.asmRegisterRegister(
                            .{ ._, .sub },
                            temp_regs[0].to32(),
                            temp_regs[2].to32(),
                        );
                    },
                }
            },
            ._r => {
                try self.asmRegisterRegister(.{ ._, .xor }, temp_regs[1].to32(), temp_regs[1].to32());
                switch (rhs_mcv) {
                    .immediate => |shift_imm| try self.asmRegisterImmediate(
                        .{ ._, .mov },
                        temp_regs[0].to32(),
                        Immediate.u(shift_imm >> 6),
                    ),
                    else => {
                        try self.asmRegisterRegister(
                            .{ ._, .movzx },
                            temp_regs[0].to32(),
                            registerAlias(.rcx, shift_abi_size),
                        );
                        try self.asmRegisterImmediate(
                            .{ ._, .@"and" },
                            .cl,
                            Immediate.u(math.maxInt(u6)),
                        );
                        try self.asmRegisterImmediate(
                            .{ ._r, .sh },
                            temp_regs[0].to32(),
                            Immediate.u(6),
                        );
                    },
                }
            },
            else => unreachable,
        }

        const slow_inc_dec = self.hasFeature(.slow_incdec);
        if (switch (rhs_mcv) {
            .immediate => |shift_imm| shift_imm >> 6 < limbs_len - 1,
            else => true,
        }) {
            try self.asmRegisterMemory(.{ ._, .mov }, temp_regs[2].to64(), .{
                .base = .{ .frame = lhs_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = temp_regs[0].to64(),
                    .scale = .@"8",
                    .disp = lhs_mcv.load_frame.off,
                } },
            });
            const skip = switch (rhs_mcv) {
                .immediate => undefined,
                else => switch (tag[0]) {
                    ._l => try self.asmJccReloc(.z, undefined),
                    ._r => skip: {
                        try self.asmRegisterImmediate(
                            .{ ._, .cmp },
                            temp_regs[0].to32(),
                            Immediate.u(limbs_len - 1),
                        );
                        break :skip try self.asmJccReloc(.nb, undefined);
                    },
                    else => unreachable,
                },
            };
            const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
            try self.asmRegisterMemory(.{ ._, .mov }, temp_regs[3].to64(), .{
                .base = .{ .frame = lhs_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = temp_regs[0].to64(),
                    .scale = .@"8",
                    .disp = switch (tag[0]) {
                        ._l => lhs_mcv.load_frame.off - 8,
                        ._r => lhs_mcv.load_frame.off + 8,
                        else => unreachable,
                    },
                } },
            });
            switch (rhs_mcv) {
                .immediate => |shift_imm| try self.asmRegisterRegisterImmediate(
                    .{ switch (tag[0]) {
                        ._l => ._ld,
                        ._r => ._rd,
                        else => unreachable,
                    }, .sh },
                    temp_regs[2].to64(),
                    temp_regs[3].to64(),
                    Immediate.u(shift_imm & math.maxInt(u6)),
                ),
                else => try self.asmRegisterRegisterRegister(.{ switch (tag[0]) {
                    ._l => ._ld,
                    ._r => ._rd,
                    else => unreachable,
                }, .sh }, temp_regs[2].to64(), temp_regs[3].to64(), .cl),
            }
            try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = lhs_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = temp_regs[1].to64(),
                    .scale = .@"8",
                    .disp = lhs_mcv.load_frame.off,
                } },
            }, temp_regs[2].to64());
            try self.asmRegisterRegister(.{ ._, .mov }, temp_regs[2].to64(), temp_regs[3].to64());
            switch (tag[0]) {
                ._l => {
                    if (slow_inc_dec) {
                        try self.asmRegisterImmediate(.{ ._, .sub }, temp_regs[1].to32(), Immediate.u(1));
                        try self.asmRegisterImmediate(.{ ._, .sub }, temp_regs[0].to32(), Immediate.u(1));
                    } else {
                        try self.asmRegister(.{ ._, .dec }, temp_regs[1].to32());
                        try self.asmRegister(.{ ._, .dec }, temp_regs[0].to32());
                    }
                    _ = try self.asmJccReloc(.nz, loop);
                },
                ._r => {
                    if (slow_inc_dec) {
                        try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[1].to32(), Immediate.u(1));
                        try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[0].to32(), Immediate.u(1));
                    } else {
                        try self.asmRegister(.{ ._, .inc }, temp_regs[1].to32());
                        try self.asmRegister(.{ ._, .inc }, temp_regs[0].to32());
                    }
                    try self.asmRegisterImmediate(
                        .{ ._, .cmp },
                        temp_regs[0].to32(),
                        Immediate.u(limbs_len - 1),
                    );
                    _ = try self.asmJccReloc(.b, loop);
                },
                else => unreachable,
            }
            switch (rhs_mcv) {
                .immediate => {},
                else => self.performReloc(skip),
            }
        }
        switch (rhs_mcv) {
            .immediate => |shift_imm| try self.asmRegisterImmediate(
                tag,
                temp_regs[2].to64(),
                Immediate.u(shift_imm & math.maxInt(u6)),
            ),
            else => try self.asmRegisterRegister(tag, temp_regs[2].to64(), .cl),
        }
        try self.asmMemoryRegister(.{ ._, .mov }, .{
            .base = .{ .frame = lhs_mcv.load_frame.index },
            .mod = .{ .rm = .{
                .size = .qword,
                .index = temp_regs[1].to64(),
                .scale = .@"8",
                .disp = lhs_mcv.load_frame.off,
            } },
        }, temp_regs[2].to64());
        if (tag[0] == ._r and tag[1] == .sa) try self.asmRegisterImmediate(
            tag,
            temp_regs[2].to64(),
            Immediate.u(63),
        );
        if (switch (rhs_mcv) {
            .immediate => |shift_imm| shift_imm >> 6 > 0,
            else => true,
        }) {
            const skip = switch (rhs_mcv) {
                .immediate => undefined,
                else => switch (tag[0]) {
                    ._l => skip: {
                        try self.asmRegisterRegister(
                            .{ ._, .@"test" },
                            temp_regs[1].to32(),
                            temp_regs[1].to32(),
                        );
                        break :skip try self.asmJccReloc(.z, undefined);
                    },
                    ._r => skip: {
                        try self.asmRegisterImmediate(
                            .{ ._, .cmp },
                            temp_regs[1].to32(),
                            Immediate.u(limbs_len - 1),
                        );
                        break :skip try self.asmJccReloc(.nb, undefined);
                    },
                    else => unreachable,
                },
            };
            const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
            switch (tag[0]) {
                ._l => if (slow_inc_dec) {
                    try self.asmRegisterImmediate(.{ ._, .sub }, temp_regs[1].to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .dec }, temp_regs[1].to32());
                },
                ._r => if (slow_inc_dec) {
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[1].to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, temp_regs[1].to32());
                },
                else => unreachable,
            }
            if (tag[0] == ._r and tag[1] == .sa) try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = lhs_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = temp_regs[1].to64(),
                    .scale = .@"8",
                    .disp = lhs_mcv.load_frame.off,
                } },
            }, temp_regs[2].to64()) else try self.asmMemoryImmediate(.{ ._, .mov }, .{
                .base = .{ .frame = lhs_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = temp_regs[1].to64(),
                    .scale = .@"8",
                    .disp = lhs_mcv.load_frame.off,
                } },
            }, Immediate.u(0));
            switch (tag[0]) {
                ._l => _ = try self.asmJccReloc(.nz, loop),
                ._r => {
                    try self.asmRegisterImmediate(
                        .{ ._, .cmp },
                        temp_regs[1].to32(),
                        Immediate.u(limbs_len - 1),
                    );
                    _ = try self.asmJccReloc(.b, loop);
                },
                else => unreachable,
            }
            switch (rhs_mcv) {
                .immediate => {},
                else => self.performReloc(skip),
            }
        }
        return;
    }

    assert(shift_abi_size == 1);
    const shift_mcv: MCValue = shift: {
        switch (rhs_mcv) {
            .immediate => |shift_imm| switch (shift_imm) {
                0 => return,
                else => break :shift rhs_mcv,
            },
            .register => |rhs_reg| if (rhs_reg.id() == Register.rcx.id())
                break :shift rhs_mcv,
            else => {},
        }
        self.register_manager.getRegAssumeFree(.rcx, null);
        try self.genSetReg(.cl, rhs_ty, rhs_mcv, .{});
        break :shift .{ .register = .rcx };
    };
    if (abi_size > 8) {
        const info: struct { indices: [2]u31, double_tag: Mir.Inst.FixedTag } = switch (tag[0]) {
            ._l => .{ .indices = .{ 0, 1 }, .double_tag = .{ ._ld, .sh } },
            ._r => .{ .indices = .{ 1, 0 }, .double_tag = .{ ._rd, .sh } },
            else => unreachable,
        };
        switch (lhs_mcv) {
            .register_pair => |lhs_regs| switch (shift_mcv) {
                .immediate => |shift_imm| if (shift_imm > 0 and shift_imm < 64) {
                    try self.asmRegisterRegisterImmediate(
                        info.double_tag,
                        lhs_regs[info.indices[1]],
                        lhs_regs[info.indices[0]],
                        Immediate.u(shift_imm),
                    );
                    try self.asmRegisterImmediate(
                        tag,
                        lhs_regs[info.indices[0]],
                        Immediate.u(shift_imm),
                    );
                    return;
                } else {
                    assert(shift_imm < 128);
                    try self.asmRegisterRegister(
                        .{ ._, .mov },
                        lhs_regs[info.indices[1]],
                        lhs_regs[info.indices[0]],
                    );
                    if (tag[0] == ._r and tag[1] == .sa) try self.asmRegisterImmediate(
                        tag,
                        lhs_regs[info.indices[0]],
                        Immediate.u(63),
                    ) else try self.asmRegisterRegister(
                        .{ ._, .xor },
                        lhs_regs[info.indices[0]],
                        lhs_regs[info.indices[0]],
                    );
                    if (shift_imm > 64) try self.asmRegisterImmediate(
                        tag,
                        lhs_regs[info.indices[1]],
                        Immediate.u(shift_imm - 64),
                    );
                    return;
                },
                .register => |shift_reg| {
                    const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    if (tag[0] == ._r and tag[1] == .sa) {
                        try self.asmRegisterRegister(.{ ._, .mov }, tmp_reg, lhs_regs[info.indices[0]]);
                        try self.asmRegisterImmediate(tag, tmp_reg, Immediate.u(63));
                    } else try self.asmRegisterRegister(
                        .{ ._, .xor },
                        tmp_reg.to32(),
                        tmp_reg.to32(),
                    );
                    try self.asmRegisterRegisterRegister(
                        info.double_tag,
                        lhs_regs[info.indices[1]],
                        lhs_regs[info.indices[0]],
                        registerAlias(shift_reg, 1),
                    );
                    try self.asmRegisterRegister(
                        tag,
                        lhs_regs[info.indices[0]],
                        registerAlias(shift_reg, 1),
                    );
                    try self.asmRegisterImmediate(
                        .{ ._, .cmp },
                        registerAlias(shift_reg, 1),
                        Immediate.u(64),
                    );
                    try self.asmCmovccRegisterRegister(
                        .ae,
                        lhs_regs[info.indices[1]],
                        lhs_regs[info.indices[0]],
                    );
                    try self.asmCmovccRegisterRegister(.ae, lhs_regs[info.indices[0]], tmp_reg);
                    return;
                },
                else => {},
            },
            .load_frame => |dst_frame_addr| {
                const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                defer self.register_manager.unlockReg(tmp_lock);

                switch (shift_mcv) {
                    .immediate => |shift_imm| if (shift_imm > 0 and shift_imm < 64) {
                        try self.asmRegisterMemory(
                            .{ ._, .mov },
                            tmp_reg,
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[0] * 8,
                                } },
                            },
                        );
                        try self.asmMemoryRegisterImmediate(
                            info.double_tag,
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[1] * 8,
                                } },
                            },
                            tmp_reg,
                            Immediate.u(shift_imm),
                        );
                        try self.asmMemoryImmediate(
                            tag,
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[0] * 8,
                                } },
                            },
                            Immediate.u(shift_imm),
                        );
                        return;
                    } else {
                        assert(shift_imm < 128);
                        try self.asmRegisterMemory(
                            .{ ._, .mov },
                            tmp_reg,
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[0] * 8,
                                } },
                            },
                        );
                        if (shift_imm > 64) try self.asmRegisterImmediate(
                            tag,
                            tmp_reg,
                            Immediate.u(shift_imm - 64),
                        );
                        try self.asmMemoryRegister(
                            .{ ._, .mov },
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[1] * 8,
                                } },
                            },
                            tmp_reg,
                        );
                        if (tag[0] == ._r and tag[1] == .sa) try self.asmMemoryImmediate(
                            tag,
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[0] * 8,
                                } },
                            },
                            Immediate.u(63),
                        ) else {
                            try self.asmRegisterRegister(.{ ._, .xor }, tmp_reg.to32(), tmp_reg.to32());
                            try self.asmMemoryRegister(
                                .{ ._, .mov },
                                .{
                                    .base = .{ .frame = dst_frame_addr.index },
                                    .mod = .{ .rm = .{
                                        .size = .qword,
                                        .disp = dst_frame_addr.off + info.indices[0] * 8,
                                    } },
                                },
                                tmp_reg,
                            );
                        }
                        return;
                    },
                    .register => |shift_reg| {
                        const first_reg =
                            try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                        const first_lock = self.register_manager.lockRegAssumeUnused(first_reg);
                        defer self.register_manager.unlockReg(first_lock);

                        const second_reg =
                            try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                        const second_lock = self.register_manager.lockRegAssumeUnused(second_reg);
                        defer self.register_manager.unlockReg(second_lock);

                        try self.asmRegisterMemory(
                            .{ ._, .mov },
                            first_reg,
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[0] * 8,
                                } },
                            },
                        );
                        try self.asmRegisterMemory(
                            .{ ._, .mov },
                            second_reg,
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[1] * 8,
                                } },
                            },
                        );
                        if (tag[0] == ._r and tag[1] == .sa) {
                            try self.asmRegisterRegister(.{ ._, .mov }, tmp_reg, first_reg);
                            try self.asmRegisterImmediate(tag, tmp_reg, Immediate.u(63));
                        } else try self.asmRegisterRegister(
                            .{ ._, .xor },
                            tmp_reg.to32(),
                            tmp_reg.to32(),
                        );
                        try self.asmRegisterRegisterRegister(
                            info.double_tag,
                            second_reg,
                            first_reg,
                            registerAlias(shift_reg, 1),
                        );
                        try self.asmRegisterRegister(tag, first_reg, registerAlias(shift_reg, 1));
                        try self.asmRegisterImmediate(
                            .{ ._, .cmp },
                            registerAlias(shift_reg, 1),
                            Immediate.u(64),
                        );
                        try self.asmCmovccRegisterRegister(.ae, second_reg, first_reg);
                        try self.asmCmovccRegisterRegister(.ae, first_reg, tmp_reg);
                        try self.asmMemoryRegister(
                            .{ ._, .mov },
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[1] * 8,
                                } },
                            },
                            second_reg,
                        );
                        try self.asmMemoryRegister(
                            .{ ._, .mov },
                            .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .mod = .{ .rm = .{
                                    .size = .qword,
                                    .disp = dst_frame_addr.off + info.indices[0] * 8,
                                } },
                            },
                            first_reg,
                        );
                        return;
                    },
                    else => {},
                }
            },
            else => {},
        }
    } else switch (lhs_mcv) {
        .register => |lhs_reg| switch (shift_mcv) {
            .immediate => |shift_imm| return self.asmRegisterImmediate(
                tag,
                registerAlias(lhs_reg, abi_size),
                Immediate.u(shift_imm),
            ),
            .register => |shift_reg| return self.asmRegisterRegister(
                tag,
                registerAlias(lhs_reg, abi_size),
                registerAlias(shift_reg, 1),
            ),
            else => {},
        },
        .memory, .indirect, .load_frame => {
            const lhs_mem: Memory = switch (lhs_mcv) {
                .memory => |addr| .{
                    .base = .{ .reg = .ds },
                    .mod = .{ .rm = .{
                        .size = Memory.Size.fromSize(abi_size),
                        .disp = math.cast(i32, @as(i64, @bitCast(addr))) orelse
                            return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
                            @tagName(lhs_mcv),
                            @tagName(shift_mcv),
                        }),
                    } },
                },
                .indirect => |reg_off| .{
                    .base = .{ .reg = reg_off.reg },
                    .mod = .{ .rm = .{
                        .size = Memory.Size.fromSize(abi_size),
                        .disp = reg_off.off,
                    } },
                },
                .load_frame => |frame_addr| .{
                    .base = .{ .frame = frame_addr.index },
                    .mod = .{ .rm = .{
                        .size = Memory.Size.fromSize(abi_size),
                        .disp = frame_addr.off,
                    } },
                },
                else => unreachable,
            };
            switch (shift_mcv) {
                .immediate => |shift_imm| return self.asmMemoryImmediate(
                    tag,
                    lhs_mem,
                    Immediate.u(shift_imm),
                ),
                .register => |shift_reg| return self.asmMemoryRegister(
                    tag,
                    lhs_mem,
                    registerAlias(shift_reg, 1),
                ),
                else => {},
            }
        },
        else => {},
    }
    return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
        @tagName(lhs_mcv),
        @tagName(shift_mcv),
    });
}

/// Result is always a register.
/// Clobbers .rcx for non-immediate rhs, therefore care is needed to spill .rcx upfront.
/// Asserts .rcx is free.
fn genShiftBinOp(
    self: *Self,
    air_tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    lhs_mcv: MCValue,
    rhs_mcv: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    if (lhs_ty.zigTypeTag(zcu) == .vector) return self.fail("TODO implement genShiftBinOp for {}", .{
        lhs_ty.fmt(pt),
    });

    try self.register_manager.getKnownReg(.rcx, null);
    const rcx_lock = self.register_manager.lockReg(.rcx);
    defer if (rcx_lock) |lock| self.register_manager.unlockReg(lock);

    const lhs_lock = switch (lhs_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

    const rhs_lock = switch (rhs_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_mcv: MCValue = dst: {
        if (maybe_inst) |inst| {
            const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
            if (self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv)) break :dst lhs_mcv;
        }
        const dst_mcv = try self.allocRegOrMemAdvanced(lhs_ty, maybe_inst, true);
        try self.genCopy(lhs_ty, dst_mcv, lhs_mcv, .{});
        break :dst dst_mcv;
    };

    const signedness = lhs_ty.intInfo(zcu).signedness;
    try self.genShiftBinOpMir(switch (air_tag) {
        .shl, .shl_exact => switch (signedness) {
            .signed => .{ ._l, .sa },
            .unsigned => .{ ._l, .sh },
        },
        .shr, .shr_exact => switch (signedness) {
            .signed => .{ ._r, .sa },
            .unsigned => .{ ._r, .sh },
        },
        else => unreachable,
    }, lhs_ty, dst_mcv, rhs_ty, rhs_mcv);
    return dst_mcv;
}

/// Result is always a register.
/// Clobbers .rax and .rdx therefore care is needed to spill .rax and .rdx upfront.
/// Asserts .rax and .rdx are free.
fn genMulDivBinOp(
    self: *Self,
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    dst_ty: Type,
    src_ty: Type,
    lhs_mcv: MCValue,
    rhs_mcv: MCValue,
) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    if (dst_ty.zigTypeTag(zcu) == .vector or dst_ty.zigTypeTag(zcu) == .float) return self.fail(
        "TODO implement genMulDivBinOp for {s} from {} to {}",
        .{ @tagName(tag), src_ty.fmt(pt), dst_ty.fmt(pt) },
    );
    const dst_abi_size: u32 = @intCast(dst_ty.abiSize(zcu));
    const src_abi_size: u32 = @intCast(src_ty.abiSize(zcu));

    assert(self.register_manager.isRegFree(.rax));
    assert(self.register_manager.isRegFree(.rcx));
    assert(self.register_manager.isRegFree(.rdx));
    assert(self.eflags_inst == null);

    if (dst_abi_size == 16 and src_abi_size == 16) {
        assert(tag == .mul or tag == .mul_wrap);
        const reg_locks = self.register_manager.lockRegs(2, .{ .rax, .rdx });
        defer for (reg_locks) |reg_lock| if (reg_lock) |lock| self.register_manager.unlockReg(lock);

        const mat_lhs_mcv = switch (lhs_mcv) {
            .load_symbol => mat_lhs_mcv: {
                // TODO clean this up!
                const addr_reg = try self.copyToTmpRegister(Type.usize, lhs_mcv.address());
                break :mat_lhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
            },
            else => lhs_mcv,
        };
        const mat_lhs_lock = switch (mat_lhs_mcv) {
            .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
            else => null,
        };
        defer if (mat_lhs_lock) |lock| self.register_manager.unlockReg(lock);
        const mat_rhs_mcv = switch (rhs_mcv) {
            .load_symbol => mat_rhs_mcv: {
                // TODO clean this up!
                const addr_reg = try self.copyToTmpRegister(Type.usize, rhs_mcv.address());
                break :mat_rhs_mcv MCValue{ .indirect = .{ .reg = addr_reg } };
            },
            else => rhs_mcv,
        };
        const mat_rhs_lock = switch (mat_rhs_mcv) {
            .indirect => |reg_off| self.register_manager.lockReg(reg_off.reg),
            else => null,
        };
        defer if (mat_rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
        const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
        defer self.register_manager.unlockReg(tmp_lock);

        if (mat_lhs_mcv.isMemory())
            try self.asmRegisterMemory(.{ ._, .mov }, .rax, try mat_lhs_mcv.mem(self, .qword))
        else
            try self.asmRegisterRegister(.{ ._, .mov }, .rax, mat_lhs_mcv.register_pair[0]);
        if (mat_rhs_mcv.isMemory()) try self.asmRegisterMemory(
            .{ ._, .mov },
            tmp_reg,
            try mat_rhs_mcv.address().offset(8).deref().mem(self, .qword),
        ) else try self.asmRegisterRegister(.{ ._, .mov }, tmp_reg, mat_rhs_mcv.register_pair[1]);
        try self.asmRegisterRegister(.{ .i_, .mul }, tmp_reg, .rax);
        if (mat_rhs_mcv.isMemory())
            try self.asmMemory(.{ ._, .mul }, try mat_rhs_mcv.mem(self, .qword))
        else
            try self.asmRegister(.{ ._, .mul }, mat_rhs_mcv.register_pair[0]);
        try self.asmRegisterRegister(.{ ._, .add }, .rdx, tmp_reg);
        if (mat_lhs_mcv.isMemory()) try self.asmRegisterMemory(
            .{ ._, .mov },
            tmp_reg,
            try mat_lhs_mcv.address().offset(8).deref().mem(self, .qword),
        ) else try self.asmRegisterRegister(.{ ._, .mov }, tmp_reg, mat_lhs_mcv.register_pair[1]);
        if (mat_rhs_mcv.isMemory())
            try self.asmRegisterMemory(.{ .i_, .mul }, tmp_reg, try mat_rhs_mcv.mem(self, .qword))
        else
            try self.asmRegisterRegister(.{ .i_, .mul }, tmp_reg, mat_rhs_mcv.register_pair[0]);
        try self.asmRegisterRegister(.{ ._, .add }, .rdx, tmp_reg);
        return .{ .register_pair = .{ .rax, .rdx } };
    }

    if (switch (tag) {
        else => unreachable,
        .mul, .mul_wrap => dst_abi_size != src_abi_size and dst_abi_size != src_abi_size * 2,
        .div_trunc, .div_floor, .div_exact, .rem, .mod => dst_abi_size != src_abi_size,
    } or src_abi_size > 8) {
        const src_info = src_ty.intInfo(zcu);
        switch (tag) {
            .mul, .mul_wrap => {
                const slow_inc = self.hasFeature(.slow_incdec);
                const limb_len = math.divCeil(u32, src_abi_size, 8) catch unreachable;

                try self.spillRegisters(&.{ .rax, .rcx, .rdx });
                const reg_locks = self.register_manager.lockRegs(3, .{ .rax, .rcx, .rdx });
                defer for (reg_locks) |reg_lock| if (reg_lock) |lock|
                    self.register_manager.unlockReg(lock);

                const dst_mcv = try self.allocRegOrMemAdvanced(dst_ty, maybe_inst, false);
                try self.genInlineMemset(
                    dst_mcv.address(),
                    .{ .immediate = 0 },
                    .{ .immediate = src_abi_size },
                    .{},
                );

                const temp_regs =
                    try self.register_manager.allocRegs(4, .{null} ** 4, abi.RegisterClass.gp);
                const temp_locks = self.register_manager.lockRegsAssumeUnused(4, temp_regs);
                defer for (temp_locks) |lock| self.register_manager.unlockReg(lock);

                try self.asmRegisterRegister(.{ ._, .xor }, temp_regs[0].to32(), temp_regs[0].to32());

                const outer_loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                try self.asmRegisterMemory(.{ ._, .mov }, temp_regs[1].to64(), .{
                    .base = .{ .frame = rhs_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[0].to64(),
                        .scale = .@"8",
                        .disp = rhs_mcv.load_frame.off,
                    } },
                });
                try self.asmRegisterRegister(.{ ._, .@"test" }, temp_regs[1].to64(), temp_regs[1].to64());
                const skip_inner = try self.asmJccReloc(.z, undefined);

                try self.asmRegisterRegister(.{ ._, .xor }, temp_regs[2].to32(), temp_regs[2].to32());
                try self.asmRegisterRegister(.{ ._, .mov }, temp_regs[3].to32(), temp_regs[0].to32());
                try self.asmRegisterRegister(.{ ._, .xor }, .ecx, .ecx);
                try self.asmRegisterRegister(.{ ._, .xor }, .edx, .edx);

                const inner_loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                try self.asmRegisterImmediate(.{ ._r, .sh }, .cl, Immediate.u(1));
                try self.asmMemoryRegister(.{ ._, .adc }, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[3].to64(),
                        .scale = .@"8",
                        .disp = dst_mcv.load_frame.off,
                    } },
                }, .rdx);
                try self.asmSetccRegister(.c, .cl);

                try self.asmRegisterMemory(.{ ._, .mov }, .rax, .{
                    .base = .{ .frame = lhs_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[2].to64(),
                        .scale = .@"8",
                        .disp = lhs_mcv.load_frame.off,
                    } },
                });
                try self.asmRegister(.{ ._, .mul }, temp_regs[1].to64());

                try self.asmRegisterImmediate(.{ ._r, .sh }, .ch, Immediate.u(1));
                try self.asmMemoryRegister(.{ ._, .adc }, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .index = temp_regs[3].to64(),
                        .scale = .@"8",
                        .disp = dst_mcv.load_frame.off,
                    } },
                }, .rax);
                try self.asmSetccRegister(.c, .ch);

                if (slow_inc) {
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[2].to32(), Immediate.u(1));
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[3].to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, temp_regs[2].to32());
                    try self.asmRegister(.{ ._, .inc }, temp_regs[3].to32());
                }
                try self.asmRegisterImmediate(
                    .{ ._, .cmp },
                    temp_regs[3].to32(),
                    Immediate.u(limb_len),
                );
                _ = try self.asmJccReloc(.b, inner_loop);

                self.performReloc(skip_inner);
                if (slow_inc) {
                    try self.asmRegisterImmediate(.{ ._, .add }, temp_regs[0].to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, temp_regs[0].to32());
                }
                try self.asmRegisterImmediate(
                    .{ ._, .cmp },
                    temp_regs[0].to32(),
                    Immediate.u(limb_len),
                );
                _ = try self.asmJccReloc(.b, outer_loop);

                return dst_mcv;
            },
            .div_trunc, .div_floor, .div_exact, .rem, .mod => switch (src_info.signedness) {
                .signed => {},
                .unsigned => {
                    const dst_mcv = try self.allocRegOrMemAdvanced(dst_ty, maybe_inst, false);
                    const manyptr_u32_ty = try pt.ptrType(.{
                        .child = .u32_type,
                        .flags = .{
                            .size = .Many,
                        },
                    });
                    const manyptr_const_u32_ty = try pt.ptrType(.{
                        .child = .u32_type,
                        .flags = .{
                            .size = .Many,
                            .is_const = true,
                        },
                    });
                    _ = try self.genCall(.{ .lib = .{
                        .return_type = .void_type,
                        .param_types = &.{
                            manyptr_u32_ty.toIntern(),
                            manyptr_const_u32_ty.toIntern(),
                            manyptr_const_u32_ty.toIntern(),
                            .usize_type,
                        },
                        .callee = switch (tag) {
                            .div_trunc,
                            .div_floor,
                            .div_exact,
                            => "__udivei4",
                            .rem,
                            .mod,
                            => "__umodei4",
                            else => unreachable,
                        },
                    } }, &.{
                        manyptr_u32_ty,
                        manyptr_const_u32_ty,
                        manyptr_const_u32_ty,
                        Type.usize,
                    }, &.{
                        dst_mcv.address(),
                        lhs_mcv.address(),
                        rhs_mcv.address(),
                        .{ .immediate = src_info.bits },
                    });
                    return dst_mcv;
                },
            },
            else => {},
        }
        return self.fail(
            "TODO implement genMulDivBinOp for {s} from {} to {}",
            .{ @tagName(tag), src_ty.fmt(pt), dst_ty.fmt(pt) },
        );
    }
    const ty = if (dst_abi_size <= 8) dst_ty else src_ty;
    const abi_size = if (dst_abi_size <= 8) dst_abi_size else src_abi_size;

    const reg_locks = self.register_manager.lockRegs(2, .{ .rax, .rdx });
    defer for (reg_locks) |reg_lock| if (reg_lock) |lock| self.register_manager.unlockReg(lock);

    const signedness = ty.intInfo(zcu).signedness;
    switch (tag) {
        .mul,
        .mul_wrap,
        .rem,
        .div_trunc,
        .div_exact,
        => {
            const track_inst_rax = switch (tag) {
                .mul, .mul_wrap => if (dst_abi_size <= 8) maybe_inst else null,
                .div_exact, .div_trunc => maybe_inst,
                else => null,
            };
            const track_inst_rdx = switch (tag) {
                .rem => maybe_inst,
                else => null,
            };
            try self.register_manager.getKnownReg(.rax, track_inst_rax);
            try self.register_manager.getKnownReg(.rdx, track_inst_rdx);

            try self.genIntMulDivOpMir(switch (signedness) {
                .signed => switch (tag) {
                    .mul, .mul_wrap => .{ .i_, .mul },
                    .div_trunc, .div_exact, .rem => .{ .i_, .div },
                    else => unreachable,
                },
                .unsigned => switch (tag) {
                    .mul, .mul_wrap => .{ ._, .mul },
                    .div_trunc, .div_exact, .rem => .{ ._, .div },
                    else => unreachable,
                },
            }, ty, lhs_mcv, rhs_mcv);

            if (dst_abi_size <= 8) return .{ .register = registerAlias(switch (tag) {
                .mul, .mul_wrap, .div_trunc, .div_exact => .rax,
                .rem => .rdx,
                else => unreachable,
            }, dst_abi_size) };

            const dst_mcv = try self.allocRegOrMemAdvanced(dst_ty, maybe_inst, false);
            try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = dst_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .disp = dst_mcv.load_frame.off,
                } },
            }, .rax);
            try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = dst_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .disp = dst_mcv.load_frame.off + 8,
                } },
            }, .rdx);
            return dst_mcv;
        },

        .mod => {
            try self.register_manager.getKnownReg(.rax, null);
            try self.register_manager.getKnownReg(
                .rdx,
                if (signedness == .unsigned) maybe_inst else null,
            );

            switch (signedness) {
                .signed => {
                    const lhs_lock = switch (lhs_mcv) {
                        .register => |reg| self.register_manager.lockReg(reg),
                        else => null,
                    };
                    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);
                    const rhs_lock = switch (rhs_mcv) {
                        .register => |reg| self.register_manager.lockReg(reg),
                        else => null,
                    };
                    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

                    // hack around hazard between rhs and div_floor by copying rhs to another register
                    const rhs_copy = try self.copyToTmpRegister(ty, rhs_mcv);
                    const rhs_copy_lock = self.register_manager.lockRegAssumeUnused(rhs_copy);
                    defer self.register_manager.unlockReg(rhs_copy_lock);

                    const div_floor = try self.genInlineIntDivFloor(ty, lhs_mcv, rhs_mcv);
                    try self.genIntMulComplexOpMir(ty, div_floor, .{ .register = rhs_copy });
                    const div_floor_lock = self.register_manager.lockReg(div_floor.register);
                    defer if (div_floor_lock) |lock| self.register_manager.unlockReg(lock);

                    const result: MCValue = if (maybe_inst) |inst|
                        try self.copyToRegisterWithInstTracking(inst, ty, lhs_mcv)
                    else
                        .{ .register = try self.copyToTmpRegister(ty, lhs_mcv) };
                    try self.genBinOpMir(.{ ._, .sub }, ty, result, div_floor);

                    return result;
                },
                .unsigned => {
                    try self.genIntMulDivOpMir(.{ ._, .div }, ty, lhs_mcv, rhs_mcv);
                    return .{ .register = registerAlias(.rdx, abi_size) };
                },
            }
        },

        .div_floor => {
            try self.register_manager.getKnownReg(
                .rax,
                if (signedness == .unsigned) maybe_inst else null,
            );
            try self.register_manager.getKnownReg(.rdx, null);

            const lhs_lock: ?RegisterLock = switch (lhs_mcv) {
                .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                else => null,
            };
            defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

            const actual_rhs_mcv: MCValue = blk: {
                switch (signedness) {
                    .signed => {
                        const rhs_lock: ?RegisterLock = switch (rhs_mcv) {
                            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                            else => null,
                        };
                        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

                        if (maybe_inst) |inst| {
                            break :blk try self.copyToRegisterWithInstTracking(inst, ty, rhs_mcv);
                        }
                        break :blk MCValue{ .register = try self.copyToTmpRegister(ty, rhs_mcv) };
                    },
                    .unsigned => break :blk rhs_mcv,
                }
            };
            const rhs_lock: ?RegisterLock = switch (actual_rhs_mcv) {
                .register => |reg| self.register_manager.lockReg(reg),
                else => null,
            };
            defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

            switch (signedness) {
                .signed => return try self.genInlineIntDivFloor(ty, lhs_mcv, actual_rhs_mcv),
                .unsigned => {
                    try self.genIntMulDivOpMir(.{ ._, .div }, ty, lhs_mcv, actual_rhs_mcv);
                    return .{ .register = registerAlias(.rax, abi_size) };
                },
            }
        },

        else => unreachable,
    }
}

fn genBinOp(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    air_tag: Air.Inst.Tag,
    lhs_air: Air.Inst.Ref,
    rhs_air: Air.Inst.Ref,
) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const lhs_ty = self.typeOf(lhs_air);
    const rhs_ty = self.typeOf(rhs_air);
    const abi_size: u32 = @intCast(lhs_ty.abiSize(zcu));

    if (lhs_ty.isRuntimeFloat()) libcall: {
        const float_bits = lhs_ty.floatBits(self.target.*);
        const type_needs_libcall = switch (float_bits) {
            16 => !self.hasFeature(.f16c),
            32, 64 => false,
            80, 128 => true,
            else => unreachable,
        };
        switch (air_tag) {
            .rem, .mod => {},
            else => if (!type_needs_libcall) break :libcall,
        }
        var callee_buf: ["__mod?f3".len]u8 = undefined;
        const callee = switch (air_tag) {
            .add,
            .sub,
            .mul,
            .div_float,
            .div_trunc,
            .div_floor,
            .div_exact,
            => std.fmt.bufPrint(&callee_buf, "__{s}{c}f3", .{
                @tagName(air_tag)[0..3],
                floatCompilerRtAbiName(float_bits),
            }),
            .rem, .mod, .min, .max => std.fmt.bufPrint(&callee_buf, "{s}f{s}{s}", .{
                floatLibcAbiPrefix(lhs_ty),
                switch (air_tag) {
                    .rem, .mod => "mod",
                    .min => "min",
                    .max => "max",
                    else => unreachable,
                },
                floatLibcAbiSuffix(lhs_ty),
            }),
            else => return self.fail("TODO implement genBinOp for {s} {}", .{
                @tagName(air_tag), lhs_ty.fmt(pt),
            }),
        } catch unreachable;
        const result = try self.genCall(.{ .lib = .{
            .return_type = lhs_ty.toIntern(),
            .param_types = &.{ lhs_ty.toIntern(), rhs_ty.toIntern() },
            .callee = callee,
        } }, &.{ lhs_ty, rhs_ty }, &.{ .{ .air_ref = lhs_air }, .{ .air_ref = rhs_air } });
        return switch (air_tag) {
            .mod => result: {
                const adjusted: MCValue = if (type_needs_libcall) adjusted: {
                    var add_callee_buf: ["__add?f3".len]u8 = undefined;
                    break :adjusted try self.genCall(.{ .lib = .{
                        .return_type = lhs_ty.toIntern(),
                        .param_types = &.{
                            lhs_ty.toIntern(),
                            rhs_ty.toIntern(),
                        },
                        .callee = std.fmt.bufPrint(&add_callee_buf, "__add{c}f3", .{
                            floatCompilerRtAbiName(float_bits),
                        }) catch unreachable,
                    } }, &.{ lhs_ty, rhs_ty }, &.{ result, .{ .air_ref = rhs_air } });
                } else switch (float_bits) {
                    16, 32, 64 => adjusted: {
                        const dst_reg = switch (result) {
                            .register => |reg| reg,
                            else => if (maybe_inst) |inst|
                                (try self.copyToRegisterWithInstTracking(inst, lhs_ty, result)).register
                            else
                                try self.copyToTmpRegister(lhs_ty, result),
                        };
                        const dst_lock = self.register_manager.lockReg(dst_reg);
                        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

                        const rhs_mcv = try self.resolveInst(rhs_air);
                        const src_mcv: MCValue = if (float_bits == 16) src: {
                            assert(self.hasFeature(.f16c));
                            const tmp_reg = (try self.register_manager.allocReg(
                                null,
                                abi.RegisterClass.sse,
                            )).to128();
                            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                            defer self.register_manager.unlockReg(tmp_lock);

                            if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                                .{ .vp_w, .insr },
                                dst_reg,
                                dst_reg,
                                try rhs_mcv.mem(self, .word),
                                Immediate.u(1),
                            ) else try self.asmRegisterRegisterRegister(
                                .{ .vp_, .unpcklwd },
                                dst_reg,
                                dst_reg,
                                (if (rhs_mcv.isRegister())
                                    rhs_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(rhs_ty, rhs_mcv)).to128(),
                            );
                            try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, dst_reg, dst_reg);
                            break :src .{ .register = tmp_reg };
                        } else rhs_mcv;

                        if (self.hasFeature(.avx)) {
                            const mir_tag: Mir.Inst.FixedTag = switch (float_bits) {
                                16, 32 => .{ .v_ss, .add },
                                64 => .{ .v_sd, .add },
                                else => unreachable,
                            };
                            if (src_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                                mir_tag,
                                dst_reg,
                                dst_reg,
                                try src_mcv.mem(self, Memory.Size.fromBitSize(float_bits)),
                            ) else try self.asmRegisterRegisterRegister(
                                mir_tag,
                                dst_reg,
                                dst_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(rhs_ty, src_mcv)).to128(),
                            );
                        } else {
                            const mir_tag: Mir.Inst.FixedTag = switch (float_bits) {
                                32 => .{ ._ss, .add },
                                64 => .{ ._sd, .add },
                                else => unreachable,
                            };
                            if (src_mcv.isMemory()) try self.asmRegisterMemory(
                                mir_tag,
                                dst_reg,
                                try src_mcv.mem(self, Memory.Size.fromBitSize(float_bits)),
                            ) else try self.asmRegisterRegister(
                                mir_tag,
                                dst_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(rhs_ty, src_mcv)).to128(),
                            );
                        }

                        if (float_bits == 16) try self.asmRegisterRegisterImmediate(
                            .{ .v_, .cvtps2ph },
                            dst_reg,
                            dst_reg,
                            Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                        );
                        break :adjusted .{ .register = dst_reg };
                    },
                    80, 128 => return self.fail("TODO implement genBinOp for {s} of {}", .{
                        @tagName(air_tag), lhs_ty.fmt(pt),
                    }),
                    else => unreachable,
                };
                break :result try self.genCall(.{ .lib = .{
                    .return_type = lhs_ty.toIntern(),
                    .param_types = &.{ lhs_ty.toIntern(), rhs_ty.toIntern() },
                    .callee = callee,
                } }, &.{ lhs_ty, rhs_ty }, &.{ adjusted, .{ .air_ref = rhs_air } });
            },
            .div_trunc, .div_floor => try self.genRoundLibcall(lhs_ty, result, .{
                .mode = switch (air_tag) {
                    .div_trunc => .zero,
                    .div_floor => .down,
                    else => unreachable,
                },
                .precision = .inexact,
            }),
            else => result,
        };
    }

    const sse_op = switch (lhs_ty.zigTypeTag(zcu)) {
        else => false,
        .float => true,
        .vector => switch (lhs_ty.childType(zcu).toIntern()) {
            .bool_type, .u1_type => false,
            else => true,
        },
    };
    if (sse_op and ((lhs_ty.scalarType(zcu).isRuntimeFloat() and
        lhs_ty.scalarType(zcu).floatBits(self.target.*) == 80) or
        lhs_ty.abiSize(zcu) > @as(u6, if (self.hasFeature(.avx)) 32 else 16)))
        return self.fail("TODO implement genBinOp for {s} {}", .{ @tagName(air_tag), lhs_ty.fmt(pt) });

    const maybe_mask_reg = switch (air_tag) {
        else => null,
        .rem, .mod => unreachable,
        .max, .min => if (lhs_ty.scalarType(zcu).isRuntimeFloat()) registerAlias(
            if (!self.hasFeature(.avx) and self.hasFeature(.sse4_1)) mask: {
                try self.register_manager.getKnownReg(.xmm0, null);
                break :mask .xmm0;
            } else try self.register_manager.allocReg(null, abi.RegisterClass.sse),
            abi_size,
        ) else null,
    };
    const mask_lock =
        if (maybe_mask_reg) |mask_reg| self.register_manager.lockRegAssumeUnused(mask_reg) else null;
    defer if (mask_lock) |lock| self.register_manager.unlockReg(lock);

    const ordered_air: [2]Air.Inst.Ref = if (lhs_ty.isVector(zcu) and
        switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
        .bool => false,
        .int => switch (air_tag) {
            .cmp_lt, .cmp_gte => true,
            else => false,
        },
        .float => switch (air_tag) {
            .cmp_gte, .cmp_gt => true,
            else => false,
        },
        else => unreachable,
    }) .{ rhs_air, lhs_air } else .{ lhs_air, rhs_air };

    if (lhs_ty.isAbiInt(zcu)) for (ordered_air) |op_air| {
        switch (try self.resolveInst(op_air)) {
            .register => |op_reg| switch (op_reg.class()) {
                .sse => try self.register_manager.getReg(op_reg, null),
                else => {},
            },
            else => {},
        }
    };

    const lhs_mcv = try self.resolveInst(ordered_air[0]);
    var rhs_mcv = try self.resolveInst(ordered_air[1]);
    switch (lhs_mcv) {
        .immediate => |imm| switch (imm) {
            0 => switch (air_tag) {
                .sub, .sub_wrap => return self.genUnOp(maybe_inst, .neg, ordered_air[1]),
                else => {},
            },
            else => {},
        },
        else => {},
    }

    const is_commutative = switch (air_tag) {
        .add,
        .add_wrap,
        .mul,
        .bool_or,
        .bit_or,
        .bool_and,
        .bit_and,
        .xor,
        .min,
        .max,
        .cmp_eq,
        .cmp_neq,
        => true,

        else => false,
    };

    const lhs_locks: [2]?RegisterLock = switch (lhs_mcv) {
        .register => |lhs_reg| .{ self.register_manager.lockRegAssumeUnused(lhs_reg), null },
        .register_pair => |lhs_regs| locks: {
            const locks = self.register_manager.lockRegsAssumeUnused(2, lhs_regs);
            break :locks .{ locks[0], locks[1] };
        },
        else => .{null} ** 2,
    };
    defer for (lhs_locks) |lhs_lock| if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

    const rhs_locks: [2]?RegisterLock = switch (rhs_mcv) {
        .register => |rhs_reg| .{ self.register_manager.lockReg(rhs_reg), null },
        .register_pair => |rhs_regs| self.register_manager.lockRegs(2, rhs_regs),
        else => .{null} ** 2,
    };
    defer for (rhs_locks) |rhs_lock| if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    var flipped = false;
    var copied_to_dst = true;
    const dst_mcv: MCValue = dst: {
        const tracked_inst = switch (air_tag) {
            else => maybe_inst,
            .cmp_lt, .cmp_lte, .cmp_eq, .cmp_gte, .cmp_gt, .cmp_neq => null,
        };
        if (maybe_inst) |inst| {
            if ((!sse_op or lhs_mcv.isRegister()) and
                self.reuseOperandAdvanced(inst, ordered_air[0], 0, lhs_mcv, tracked_inst))
                break :dst lhs_mcv;
            if (is_commutative and (!sse_op or rhs_mcv.isRegister()) and
                self.reuseOperandAdvanced(inst, ordered_air[1], 1, rhs_mcv, tracked_inst))
            {
                flipped = true;
                break :dst rhs_mcv;
            }
        }
        const dst_mcv = try self.allocRegOrMemAdvanced(lhs_ty, tracked_inst, true);
        if (sse_op and lhs_mcv.isRegister() and self.hasFeature(.avx))
            copied_to_dst = false
        else
            try self.genCopy(lhs_ty, dst_mcv, lhs_mcv, .{});
        rhs_mcv = try self.resolveInst(ordered_air[1]);
        break :dst dst_mcv;
    };
    const dst_locks: [2]?RegisterLock = switch (dst_mcv) {
        .register => |dst_reg| .{ self.register_manager.lockReg(dst_reg), null },
        .register_pair => |dst_regs| self.register_manager.lockRegs(2, dst_regs),
        else => .{null} ** 2,
    };
    defer for (dst_locks) |dst_lock| if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const unmat_src_mcv = if (flipped) lhs_mcv else rhs_mcv;
    const src_mcv: MCValue = if (maybe_mask_reg) |mask_reg|
        if (self.hasFeature(.avx) and unmat_src_mcv.isRegister() and maybe_inst != null and
            self.liveness.operandDies(maybe_inst.?, if (flipped) 0 else 1)) unmat_src_mcv else src: {
            try self.genSetReg(mask_reg, rhs_ty, unmat_src_mcv, .{});
            break :src .{ .register = mask_reg };
        }
    else
        unmat_src_mcv;
    const src_locks: [2]?RegisterLock = switch (src_mcv) {
        .register => |src_reg| .{ self.register_manager.lockReg(src_reg), null },
        .register_pair => |src_regs| self.register_manager.lockRegs(2, src_regs),
        else => .{null} ** 2,
    };
    defer for (src_locks) |src_lock| if (src_lock) |lock| self.register_manager.unlockReg(lock);

    if (!sse_op) {
        switch (air_tag) {
            .add,
            .add_wrap,
            => try self.genBinOpMir(.{ ._, .add }, lhs_ty, dst_mcv, src_mcv),

            .sub,
            .sub_wrap,
            => try self.genBinOpMir(.{ ._, .sub }, lhs_ty, dst_mcv, src_mcv),

            .ptr_add,
            .ptr_sub,
            => {
                const tmp_reg = try self.copyToTmpRegister(rhs_ty, src_mcv);
                const tmp_mcv = MCValue{ .register = tmp_reg };
                const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                defer self.register_manager.unlockReg(tmp_lock);

                const elem_size = lhs_ty.elemType2(zcu).abiSize(zcu);
                try self.genIntMulComplexOpMir(rhs_ty, tmp_mcv, .{ .immediate = elem_size });
                try self.genBinOpMir(
                    switch (air_tag) {
                        .ptr_add => .{ ._, .add },
                        .ptr_sub => .{ ._, .sub },
                        else => unreachable,
                    },
                    lhs_ty,
                    dst_mcv,
                    tmp_mcv,
                );
            },

            .bool_or,
            .bit_or,
            => try self.genBinOpMir(.{ ._, .@"or" }, lhs_ty, dst_mcv, src_mcv),

            .bool_and,
            .bit_and,
            => try self.genBinOpMir(.{ ._, .@"and" }, lhs_ty, dst_mcv, src_mcv),

            .xor => try self.genBinOpMir(.{ ._, .xor }, lhs_ty, dst_mcv, src_mcv),

            .min,
            .max,
            => {
                const resolved_src_mcv = switch (src_mcv) {
                    else => src_mcv,
                    .air_ref => |src_ref| try self.resolveInst(src_ref),
                };

                if (abi_size > 8) {
                    const dst_regs = switch (dst_mcv) {
                        .register_pair => |dst_regs| dst_regs,
                        else => dst: {
                            const dst_regs = try self.register_manager.allocRegs(
                                2,
                                .{null} ** 2,
                                abi.RegisterClass.gp,
                            );
                            const dst_regs_locks = self.register_manager.lockRegsAssumeUnused(2, dst_regs);
                            defer for (dst_regs_locks) |lock| self.register_manager.unlockReg(lock);

                            try self.genCopy(lhs_ty, .{ .register_pair = dst_regs }, dst_mcv, .{});
                            break :dst dst_regs;
                        },
                    };
                    const dst_regs_locks = self.register_manager.lockRegs(2, dst_regs);
                    defer for (dst_regs_locks) |dst_lock| if (dst_lock) |lock|
                        self.register_manager.unlockReg(lock);

                    const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    const signed = lhs_ty.isSignedInt(zcu);
                    const cc: Condition = switch (air_tag) {
                        .min => if (signed) .nl else .nb,
                        .max => if (signed) .nge else .nae,
                        else => unreachable,
                    };

                    try self.asmRegisterRegister(.{ ._, .mov }, tmp_reg, dst_regs[1]);
                    if (src_mcv.isMemory()) {
                        try self.asmRegisterMemory(
                            .{ ._, .cmp },
                            dst_regs[0],
                            try src_mcv.mem(self, .qword),
                        );
                        try self.asmRegisterMemory(
                            .{ ._, .sbb },
                            tmp_reg,
                            try src_mcv.address().offset(8).deref().mem(self, .qword),
                        );
                        try self.asmCmovccRegisterMemory(
                            cc,
                            dst_regs[0],
                            try src_mcv.mem(self, .qword),
                        );
                        try self.asmCmovccRegisterMemory(
                            cc,
                            dst_regs[1],
                            try src_mcv.address().offset(8).deref().mem(self, .qword),
                        );
                    } else {
                        try self.asmRegisterRegister(
                            .{ ._, .cmp },
                            dst_regs[0],
                            src_mcv.register_pair[0],
                        );
                        try self.asmRegisterRegister(
                            .{ ._, .sbb },
                            tmp_reg,
                            src_mcv.register_pair[1],
                        );
                        try self.asmCmovccRegisterRegister(cc, dst_regs[0], src_mcv.register_pair[0]);
                        try self.asmCmovccRegisterRegister(cc, dst_regs[1], src_mcv.register_pair[1]);
                    }
                    try self.genCopy(lhs_ty, dst_mcv, .{ .register_pair = dst_regs }, .{});
                } else {
                    const mat_src_mcv: MCValue = if (switch (resolved_src_mcv) {
                        .immediate,
                        .eflags,
                        .register_offset,
                        .load_symbol,
                        .lea_symbol,
                        .load_direct,
                        .lea_direct,
                        .load_got,
                        .lea_got,
                        .load_tlv,
                        .lea_tlv,
                        .lea_frame,
                        => true,
                        .memory => |addr| math.cast(i32, @as(i64, @bitCast(addr))) == null,
                        else => false,
                        .register_pair,
                        .register_overflow,
                        => unreachable,
                    })
                        .{ .register = try self.copyToTmpRegister(rhs_ty, resolved_src_mcv) }
                    else
                        resolved_src_mcv;
                    const mat_mcv_lock = switch (mat_src_mcv) {
                        .register => |reg| self.register_manager.lockReg(reg),
                        else => null,
                    };
                    defer if (mat_mcv_lock) |lock| self.register_manager.unlockReg(lock);

                    try self.genBinOpMir(.{ ._, .cmp }, lhs_ty, dst_mcv, mat_src_mcv);

                    const int_info = lhs_ty.intInfo(zcu);
                    const cc: Condition = switch (int_info.signedness) {
                        .unsigned => switch (air_tag) {
                            .min => .a,
                            .max => .b,
                            else => unreachable,
                        },
                        .signed => switch (air_tag) {
                            .min => .g,
                            .max => .l,
                            else => unreachable,
                        },
                    };

                    const cmov_abi_size = @max(@as(u32, @intCast(lhs_ty.abiSize(zcu))), 2);
                    const tmp_reg = switch (dst_mcv) {
                        .register => |reg| reg,
                        else => try self.copyToTmpRegister(lhs_ty, dst_mcv),
                    };
                    const tmp_lock = self.register_manager.lockReg(tmp_reg);
                    defer if (tmp_lock) |lock| self.register_manager.unlockReg(lock);
                    switch (mat_src_mcv) {
                        .none,
                        .unreach,
                        .dead,
                        .undef,
                        .immediate,
                        .eflags,
                        .register_pair,
                        .register_offset,
                        .register_overflow,
                        .load_symbol,
                        .lea_symbol,
                        .load_direct,
                        .lea_direct,
                        .load_got,
                        .lea_got,
                        .load_tlv,
                        .lea_tlv,
                        .lea_frame,
                        .elementwise_regs_then_frame,
                        .reserved_frame,
                        .air_ref,
                        => unreachable,
                        .register => |src_reg| try self.asmCmovccRegisterRegister(
                            cc,
                            registerAlias(tmp_reg, cmov_abi_size),
                            registerAlias(src_reg, cmov_abi_size),
                        ),
                        .memory, .indirect, .load_frame => try self.asmCmovccRegisterMemory(
                            cc,
                            registerAlias(tmp_reg, cmov_abi_size),
                            switch (mat_src_mcv) {
                                .memory => |addr| .{
                                    .base = .{ .reg = .ds },
                                    .mod = .{ .rm = .{
                                        .size = Memory.Size.fromSize(cmov_abi_size),
                                        .disp = @intCast(@as(i64, @bitCast(addr))),
                                    } },
                                },
                                .indirect => |reg_off| .{
                                    .base = .{ .reg = reg_off.reg },
                                    .mod = .{ .rm = .{
                                        .size = Memory.Size.fromSize(cmov_abi_size),
                                        .disp = reg_off.off,
                                    } },
                                },
                                .load_frame => |frame_addr| .{
                                    .base = .{ .frame = frame_addr.index },
                                    .mod = .{ .rm = .{
                                        .size = Memory.Size.fromSize(cmov_abi_size),
                                        .disp = frame_addr.off,
                                    } },
                                },
                                else => unreachable,
                            },
                        ),
                    }
                    try self.genCopy(lhs_ty, dst_mcv, .{ .register = tmp_reg }, .{});
                }
            },

            .cmp_eq, .cmp_neq => {
                assert(lhs_ty.isVector(zcu) and lhs_ty.childType(zcu).toIntern() == .bool_type);
                try self.genBinOpMir(.{ ._, .xor }, lhs_ty, dst_mcv, src_mcv);
                switch (air_tag) {
                    .cmp_eq => try self.genUnOpMir(.{ ._, .not }, lhs_ty, dst_mcv),
                    .cmp_neq => {},
                    else => unreachable,
                }
            },

            else => return self.fail("TODO implement genBinOp for {s} {}", .{
                @tagName(air_tag), lhs_ty.fmt(pt),
            }),
        }
        return dst_mcv;
    }

    const dst_reg = registerAlias(dst_mcv.getReg().?, abi_size);
    const mir_tag = @as(?Mir.Inst.FixedTag, switch (lhs_ty.zigTypeTag(zcu)) {
        else => unreachable,
        .float => switch (lhs_ty.floatBits(self.target.*)) {
            16 => {
                assert(self.hasFeature(.f16c));
                const tmp_reg =
                    (try self.register_manager.allocReg(null, abi.RegisterClass.sse)).to128();
                const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                defer self.register_manager.unlockReg(tmp_lock);

                if (src_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                    .{ .vp_w, .insr },
                    dst_reg,
                    dst_reg,
                    try src_mcv.mem(self, .word),
                    Immediate.u(1),
                ) else try self.asmRegisterRegisterRegister(
                    .{ .vp_, .unpcklwd },
                    dst_reg,
                    dst_reg,
                    (if (src_mcv.isRegister())
                        src_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(rhs_ty, src_mcv)).to128(),
                );
                try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, dst_reg, dst_reg);
                try self.asmRegisterRegister(.{ .v_, .movshdup }, tmp_reg, dst_reg);
                try self.asmRegisterRegisterRegister(
                    switch (air_tag) {
                        .add => .{ .v_ss, .add },
                        .sub => .{ .v_ss, .sub },
                        .mul => .{ .v_ss, .mul },
                        .div_float, .div_trunc, .div_floor, .div_exact => .{ .v_ss, .div },
                        .max => .{ .v_ss, .max },
                        .min => .{ .v_ss, .max },
                        else => unreachable,
                    },
                    dst_reg,
                    dst_reg,
                    tmp_reg,
                );
                switch (air_tag) {
                    .div_trunc, .div_floor => try self.asmRegisterRegisterRegisterImmediate(
                        .{ .v_ss, .round },
                        dst_reg,
                        dst_reg,
                        dst_reg,
                        Immediate.u(@as(u5, @bitCast(RoundMode{
                            .mode = switch (air_tag) {
                                .div_trunc => .zero,
                                .div_floor => .down,
                                else => unreachable,
                            },
                            .precision = .inexact,
                        }))),
                    ),
                    else => {},
                }
                try self.asmRegisterRegisterImmediate(
                    .{ .v_, .cvtps2ph },
                    dst_reg,
                    dst_reg,
                    Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                );
                return dst_mcv;
            },
            32 => switch (air_tag) {
                .add => if (self.hasFeature(.avx)) .{ .v_ss, .add } else .{ ._ss, .add },
                .sub => if (self.hasFeature(.avx)) .{ .v_ss, .sub } else .{ ._ss, .sub },
                .mul => if (self.hasFeature(.avx)) .{ .v_ss, .mul } else .{ ._ss, .mul },
                .div_float,
                .div_trunc,
                .div_floor,
                .div_exact,
                => if (self.hasFeature(.avx)) .{ .v_ss, .div } else .{ ._ss, .div },
                .max => if (self.hasFeature(.avx)) .{ .v_ss, .max } else .{ ._ss, .max },
                .min => if (self.hasFeature(.avx)) .{ .v_ss, .min } else .{ ._ss, .min },
                else => unreachable,
            },
            64 => switch (air_tag) {
                .add => if (self.hasFeature(.avx)) .{ .v_sd, .add } else .{ ._sd, .add },
                .sub => if (self.hasFeature(.avx)) .{ .v_sd, .sub } else .{ ._sd, .sub },
                .mul => if (self.hasFeature(.avx)) .{ .v_sd, .mul } else .{ ._sd, .mul },
                .div_float,
                .div_trunc,
                .div_floor,
                .div_exact,
                => if (self.hasFeature(.avx)) .{ .v_sd, .div } else .{ ._sd, .div },
                .max => if (self.hasFeature(.avx)) .{ .v_sd, .max } else .{ ._sd, .max },
                .min => if (self.hasFeature(.avx)) .{ .v_sd, .min } else .{ ._sd, .min },
                else => unreachable,
            },
            80, 128 => null,
            else => unreachable,
        },
        .vector => switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
            else => null,
            .int => switch (lhs_ty.childType(zcu).intInfo(zcu).bits) {
                8 => switch (lhs_ty.vectorLen(zcu)) {
                    1...16 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_b, .add } else .{ .p_b, .add },
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_b, .sub } else .{ .p_b, .sub },
                        .bit_and => if (self.hasFeature(.avx))
                            .{ .vp_, .@"and" }
                        else
                            .{ .p_, .@"and" },
                        .bit_or => if (self.hasFeature(.avx)) .{ .vp_, .@"or" } else .{ .p_, .@"or" },
                        .xor => if (self.hasFeature(.avx)) .{ .vp_, .xor } else .{ .p_, .xor },
                        .min => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_b, .mins }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_b, .mins }
                            else
                                null,
                            .unsigned => if (self.hasFeature(.avx))
                                .{ .vp_b, .minu }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_b, .minu }
                            else
                                null,
                        },
                        .max => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_b, .maxs }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_b, .maxs }
                            else
                                null,
                            .unsigned => if (self.hasFeature(.avx))
                                .{ .vp_b, .maxu }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_b, .maxu }
                            else
                                null,
                        },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gte,
                        .cmp_gt,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_b, .cmpgt }
                            else
                                .{ .p_b, .cmpgt },
                            .unsigned => null,
                        },
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .vp_b, .cmpeq } else .{ .p_b, .cmpeq },
                        else => null,
                    },
                    17...32 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_b, .add } else null,
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_b, .sub } else null,
                        .bit_and => if (self.hasFeature(.avx2)) .{ .vp_, .@"and" } else null,
                        .bit_or => if (self.hasFeature(.avx2)) .{ .vp_, .@"or" } else null,
                        .xor => if (self.hasFeature(.avx2)) .{ .vp_, .xor } else null,
                        .min => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx2)) .{ .vp_b, .mins } else null,
                            .unsigned => if (self.hasFeature(.avx)) .{ .vp_b, .minu } else null,
                        },
                        .max => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx2)) .{ .vp_b, .maxs } else null,
                            .unsigned => if (self.hasFeature(.avx2)) .{ .vp_b, .maxu } else null,
                        },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gte,
                        .cmp_gt,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx)) .{ .vp_b, .cmpgt } else null,
                            .unsigned => null,
                        },
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .vp_b, .cmpeq } else null,
                        else => null,
                    },
                    else => null,
                },
                16 => switch (lhs_ty.vectorLen(zcu)) {
                    1...8 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_w, .add } else .{ .p_w, .add },
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_w, .sub } else .{ .p_w, .sub },
                        .mul,
                        .mul_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_w, .mull } else .{ .p_d, .mull },
                        .bit_and => if (self.hasFeature(.avx))
                            .{ .vp_, .@"and" }
                        else
                            .{ .p_, .@"and" },
                        .bit_or => if (self.hasFeature(.avx)) .{ .vp_, .@"or" } else .{ .p_, .@"or" },
                        .xor => if (self.hasFeature(.avx)) .{ .vp_, .xor } else .{ .p_, .xor },
                        .min => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_w, .mins }
                            else
                                .{ .p_w, .mins },
                            .unsigned => if (self.hasFeature(.avx))
                                .{ .vp_w, .minu }
                            else
                                .{ .p_w, .minu },
                        },
                        .max => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_w, .maxs }
                            else
                                .{ .p_w, .maxs },
                            .unsigned => if (self.hasFeature(.avx))
                                .{ .vp_w, .maxu }
                            else
                                .{ .p_w, .maxu },
                        },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gte,
                        .cmp_gt,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_w, .cmpgt }
                            else
                                .{ .p_w, .cmpgt },
                            .unsigned => null,
                        },
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .vp_w, .cmpeq } else .{ .p_w, .cmpeq },
                        else => null,
                    },
                    9...16 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_w, .add } else null,
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_w, .sub } else null,
                        .mul,
                        .mul_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_w, .mull } else null,
                        .bit_and => if (self.hasFeature(.avx2)) .{ .vp_, .@"and" } else null,
                        .bit_or => if (self.hasFeature(.avx2)) .{ .vp_, .@"or" } else null,
                        .xor => if (self.hasFeature(.avx2)) .{ .vp_, .xor } else null,
                        .min => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx2)) .{ .vp_w, .mins } else null,
                            .unsigned => if (self.hasFeature(.avx)) .{ .vp_w, .minu } else null,
                        },
                        .max => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx2)) .{ .vp_w, .maxs } else null,
                            .unsigned => if (self.hasFeature(.avx2)) .{ .vp_w, .maxu } else null,
                        },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gte,
                        .cmp_gt,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx)) .{ .vp_w, .cmpgt } else null,
                            .unsigned => null,
                        },
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .vp_w, .cmpeq } else null,
                        else => null,
                    },
                    else => null,
                },
                32 => switch (lhs_ty.vectorLen(zcu)) {
                    1...4 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_d, .add } else .{ .p_d, .add },
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_d, .sub } else .{ .p_d, .sub },
                        .mul,
                        .mul_wrap,
                        => if (self.hasFeature(.avx))
                            .{ .vp_d, .mull }
                        else if (self.hasFeature(.sse4_1))
                            .{ .p_d, .mull }
                        else
                            null,
                        .bit_and => if (self.hasFeature(.avx))
                            .{ .vp_, .@"and" }
                        else
                            .{ .p_, .@"and" },
                        .bit_or => if (self.hasFeature(.avx)) .{ .vp_, .@"or" } else .{ .p_, .@"or" },
                        .xor => if (self.hasFeature(.avx)) .{ .vp_, .xor } else .{ .p_, .xor },
                        .min => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_d, .mins }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_d, .mins }
                            else
                                null,
                            .unsigned => if (self.hasFeature(.avx))
                                .{ .vp_d, .minu }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_d, .minu }
                            else
                                null,
                        },
                        .max => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_d, .maxs }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_d, .maxs }
                            else
                                null,
                            .unsigned => if (self.hasFeature(.avx))
                                .{ .vp_d, .maxu }
                            else if (self.hasFeature(.sse4_1))
                                .{ .p_d, .maxu }
                            else
                                null,
                        },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gte,
                        .cmp_gt,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_d, .cmpgt }
                            else
                                .{ .p_d, .cmpgt },
                            .unsigned => null,
                        },
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .vp_d, .cmpeq } else .{ .p_d, .cmpeq },
                        else => null,
                    },
                    5...8 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_d, .add } else null,
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_d, .sub } else null,
                        .mul,
                        .mul_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_d, .mull } else null,
                        .bit_and => if (self.hasFeature(.avx2)) .{ .vp_, .@"and" } else null,
                        .bit_or => if (self.hasFeature(.avx2)) .{ .vp_, .@"or" } else null,
                        .xor => if (self.hasFeature(.avx2)) .{ .vp_, .xor } else null,
                        .min => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx2)) .{ .vp_d, .mins } else null,
                            .unsigned => if (self.hasFeature(.avx)) .{ .vp_d, .minu } else null,
                        },
                        .max => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx2)) .{ .vp_d, .maxs } else null,
                            .unsigned => if (self.hasFeature(.avx2)) .{ .vp_d, .maxu } else null,
                        },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gte,
                        .cmp_gt,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx)) .{ .vp_d, .cmpgt } else null,
                            .unsigned => null,
                        },
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .vp_d, .cmpeq } else null,
                        else => null,
                    },
                    else => null,
                },
                64 => switch (lhs_ty.vectorLen(zcu)) {
                    1...2 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_q, .add } else .{ .p_q, .add },
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx)) .{ .vp_q, .sub } else .{ .p_q, .sub },
                        .bit_and => if (self.hasFeature(.avx))
                            .{ .vp_, .@"and" }
                        else
                            .{ .p_, .@"and" },
                        .bit_or => if (self.hasFeature(.avx)) .{ .vp_, .@"or" } else .{ .p_, .@"or" },
                        .xor => if (self.hasFeature(.avx)) .{ .vp_, .xor } else .{ .p_, .xor },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gte,
                        .cmp_gt,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx))
                                .{ .vp_q, .cmpgt }
                            else if (self.hasFeature(.sse4_2))
                                .{ .p_q, .cmpgt }
                            else
                                null,
                            .unsigned => null,
                        },
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx))
                            .{ .vp_q, .cmpeq }
                        else if (self.hasFeature(.sse4_1))
                            .{ .p_q, .cmpeq }
                        else
                            null,
                        else => null,
                    },
                    3...4 => switch (air_tag) {
                        .add,
                        .add_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_q, .add } else null,
                        .sub,
                        .sub_wrap,
                        => if (self.hasFeature(.avx2)) .{ .vp_q, .sub } else null,
                        .bit_and => if (self.hasFeature(.avx2)) .{ .vp_, .@"and" } else null,
                        .bit_or => if (self.hasFeature(.avx2)) .{ .vp_, .@"or" } else null,
                        .xor => if (self.hasFeature(.avx2)) .{ .vp_, .xor } else null,
                        .cmp_eq,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .vp_d, .cmpeq } else null,
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_gt,
                        .cmp_gte,
                        => switch (lhs_ty.childType(zcu).intInfo(zcu).signedness) {
                            .signed => if (self.hasFeature(.avx)) .{ .vp_d, .cmpgt } else null,
                            .unsigned => null,
                        },
                        else => null,
                    },
                    else => null,
                },
                else => null,
            },
            .float => switch (lhs_ty.childType(zcu).floatBits(self.target.*)) {
                16 => tag: {
                    assert(self.hasFeature(.f16c));
                    switch (lhs_ty.vectorLen(zcu)) {
                        1 => {
                            const tmp_reg = (try self.register_manager.allocReg(
                                null,
                                abi.RegisterClass.sse,
                            )).to128();
                            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                            defer self.register_manager.unlockReg(tmp_lock);

                            if (src_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                                .{ .vp_w, .insr },
                                dst_reg,
                                dst_reg,
                                try src_mcv.mem(self, .word),
                                Immediate.u(1),
                            ) else try self.asmRegisterRegisterRegister(
                                .{ .vp_, .unpcklwd },
                                dst_reg,
                                dst_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(rhs_ty, src_mcv)).to128(),
                            );
                            try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, dst_reg, dst_reg);
                            try self.asmRegisterRegister(.{ .v_, .movshdup }, tmp_reg, dst_reg);
                            try self.asmRegisterRegisterRegister(
                                switch (air_tag) {
                                    .add => .{ .v_ss, .add },
                                    .sub => .{ .v_ss, .sub },
                                    .mul => .{ .v_ss, .mul },
                                    .div_float, .div_trunc, .div_floor, .div_exact => .{ .v_ss, .div },
                                    .max => .{ .v_ss, .max },
                                    .min => .{ .v_ss, .max },
                                    else => unreachable,
                                },
                                dst_reg,
                                dst_reg,
                                tmp_reg,
                            );
                            try self.asmRegisterRegisterImmediate(
                                .{ .v_, .cvtps2ph },
                                dst_reg,
                                dst_reg,
                                Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                            );
                            return dst_mcv;
                        },
                        2 => {
                            const tmp_reg = (try self.register_manager.allocReg(
                                null,
                                abi.RegisterClass.sse,
                            )).to128();
                            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                            defer self.register_manager.unlockReg(tmp_lock);

                            if (src_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
                                .{ .vp_d, .insr },
                                dst_reg,
                                try src_mcv.mem(self, .dword),
                                Immediate.u(1),
                            ) else try self.asmRegisterRegisterRegister(
                                .{ .v_ps, .unpckl },
                                dst_reg,
                                dst_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(rhs_ty, src_mcv)).to128(),
                            );
                            try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, dst_reg, dst_reg);
                            try self.asmRegisterRegisterRegister(
                                .{ .v_ps, .movhl },
                                tmp_reg,
                                dst_reg,
                                dst_reg,
                            );
                            try self.asmRegisterRegisterRegister(
                                switch (air_tag) {
                                    .add => .{ .v_ps, .add },
                                    .sub => .{ .v_ps, .sub },
                                    .mul => .{ .v_ps, .mul },
                                    .div_float, .div_trunc, .div_floor, .div_exact => .{ .v_ps, .div },
                                    .max => .{ .v_ps, .max },
                                    .min => .{ .v_ps, .max },
                                    else => unreachable,
                                },
                                dst_reg,
                                dst_reg,
                                tmp_reg,
                            );
                            try self.asmRegisterRegisterImmediate(
                                .{ .v_, .cvtps2ph },
                                dst_reg,
                                dst_reg,
                                Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                            );
                            return dst_mcv;
                        },
                        3...4 => {
                            const tmp_reg = (try self.register_manager.allocReg(
                                null,
                                abi.RegisterClass.sse,
                            )).to128();
                            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                            defer self.register_manager.unlockReg(tmp_lock);

                            try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, dst_reg, dst_reg);
                            if (src_mcv.isMemory()) try self.asmRegisterMemory(
                                .{ .v_ps, .cvtph2 },
                                tmp_reg,
                                try src_mcv.mem(self, .qword),
                            ) else try self.asmRegisterRegister(
                                .{ .v_ps, .cvtph2 },
                                tmp_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(rhs_ty, src_mcv)).to128(),
                            );
                            try self.asmRegisterRegisterRegister(
                                switch (air_tag) {
                                    .add => .{ .v_ps, .add },
                                    .sub => .{ .v_ps, .sub },
                                    .mul => .{ .v_ps, .mul },
                                    .div_float, .div_trunc, .div_floor, .div_exact => .{ .v_ps, .div },
                                    .max => .{ .v_ps, .max },
                                    .min => .{ .v_ps, .max },
                                    else => unreachable,
                                },
                                dst_reg,
                                dst_reg,
                                tmp_reg,
                            );
                            try self.asmRegisterRegisterImmediate(
                                .{ .v_, .cvtps2ph },
                                dst_reg,
                                dst_reg,
                                Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                            );
                            return dst_mcv;
                        },
                        5...8 => {
                            const tmp_reg = (try self.register_manager.allocReg(
                                null,
                                abi.RegisterClass.sse,
                            )).to256();
                            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                            defer self.register_manager.unlockReg(tmp_lock);

                            try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, dst_reg.to256(), dst_reg);
                            if (src_mcv.isMemory()) try self.asmRegisterMemory(
                                .{ .v_ps, .cvtph2 },
                                tmp_reg,
                                try src_mcv.mem(self, .xword),
                            ) else try self.asmRegisterRegister(
                                .{ .v_ps, .cvtph2 },
                                tmp_reg,
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(rhs_ty, src_mcv)).to128(),
                            );
                            try self.asmRegisterRegisterRegister(
                                switch (air_tag) {
                                    .add => .{ .v_ps, .add },
                                    .sub => .{ .v_ps, .sub },
                                    .mul => .{ .v_ps, .mul },
                                    .div_float, .div_trunc, .div_floor, .div_exact => .{ .v_ps, .div },
                                    .max => .{ .v_ps, .max },
                                    .min => .{ .v_ps, .max },
                                    else => unreachable,
                                },
                                dst_reg.to256(),
                                dst_reg.to256(),
                                tmp_reg,
                            );
                            try self.asmRegisterRegisterImmediate(
                                .{ .v_, .cvtps2ph },
                                dst_reg,
                                dst_reg.to256(),
                                Immediate.u(@as(u5, @bitCast(RoundMode{ .mode = .mxcsr }))),
                            );
                            return dst_mcv;
                        },
                        else => break :tag null,
                    }
                },
                32 => switch (lhs_ty.vectorLen(zcu)) {
                    1 => switch (air_tag) {
                        .add => if (self.hasFeature(.avx)) .{ .v_ss, .add } else .{ ._ss, .add },
                        .sub => if (self.hasFeature(.avx)) .{ .v_ss, .sub } else .{ ._ss, .sub },
                        .mul => if (self.hasFeature(.avx)) .{ .v_ss, .mul } else .{ ._ss, .mul },
                        .div_float,
                        .div_trunc,
                        .div_floor,
                        .div_exact,
                        => if (self.hasFeature(.avx)) .{ .v_ss, .div } else .{ ._ss, .div },
                        .max => if (self.hasFeature(.avx)) .{ .v_ss, .max } else .{ ._ss, .max },
                        .min => if (self.hasFeature(.avx)) .{ .v_ss, .min } else .{ ._ss, .min },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_eq,
                        .cmp_gte,
                        .cmp_gt,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .v_ss, .cmp } else .{ ._ss, .cmp },
                        else => unreachable,
                    },
                    2...4 => switch (air_tag) {
                        .add => if (self.hasFeature(.avx)) .{ .v_ps, .add } else .{ ._ps, .add },
                        .sub => if (self.hasFeature(.avx)) .{ .v_ps, .sub } else .{ ._ps, .sub },
                        .mul => if (self.hasFeature(.avx)) .{ .v_ps, .mul } else .{ ._ps, .mul },
                        .div_float,
                        .div_trunc,
                        .div_floor,
                        .div_exact,
                        => if (self.hasFeature(.avx)) .{ .v_ps, .div } else .{ ._ps, .div },
                        .max => if (self.hasFeature(.avx)) .{ .v_ps, .max } else .{ ._ps, .max },
                        .min => if (self.hasFeature(.avx)) .{ .v_ps, .min } else .{ ._ps, .min },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_eq,
                        .cmp_gte,
                        .cmp_gt,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .v_ps, .cmp } else .{ ._ps, .cmp },
                        else => unreachable,
                    },
                    5...8 => if (self.hasFeature(.avx)) switch (air_tag) {
                        .add => .{ .v_ps, .add },
                        .sub => .{ .v_ps, .sub },
                        .mul => .{ .v_ps, .mul },
                        .div_float, .div_trunc, .div_floor, .div_exact => .{ .v_ps, .div },
                        .max => .{ .v_ps, .max },
                        .min => .{ .v_ps, .min },
                        .cmp_lt, .cmp_lte, .cmp_eq, .cmp_gte, .cmp_gt, .cmp_neq => .{ .v_ps, .cmp },
                        else => unreachable,
                    } else null,
                    else => null,
                },
                64 => switch (lhs_ty.vectorLen(zcu)) {
                    1 => switch (air_tag) {
                        .add => if (self.hasFeature(.avx)) .{ .v_sd, .add } else .{ ._sd, .add },
                        .sub => if (self.hasFeature(.avx)) .{ .v_sd, .sub } else .{ ._sd, .sub },
                        .mul => if (self.hasFeature(.avx)) .{ .v_sd, .mul } else .{ ._sd, .mul },
                        .div_float,
                        .div_trunc,
                        .div_floor,
                        .div_exact,
                        => if (self.hasFeature(.avx)) .{ .v_sd, .div } else .{ ._sd, .div },
                        .max => if (self.hasFeature(.avx)) .{ .v_sd, .max } else .{ ._sd, .max },
                        .min => if (self.hasFeature(.avx)) .{ .v_sd, .min } else .{ ._sd, .min },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_eq,
                        .cmp_gte,
                        .cmp_gt,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .v_sd, .cmp } else .{ ._sd, .cmp },
                        else => unreachable,
                    },
                    2 => switch (air_tag) {
                        .add => if (self.hasFeature(.avx)) .{ .v_pd, .add } else .{ ._pd, .add },
                        .sub => if (self.hasFeature(.avx)) .{ .v_pd, .sub } else .{ ._pd, .sub },
                        .mul => if (self.hasFeature(.avx)) .{ .v_pd, .mul } else .{ ._pd, .mul },
                        .div_float,
                        .div_trunc,
                        .div_floor,
                        .div_exact,
                        => if (self.hasFeature(.avx)) .{ .v_pd, .div } else .{ ._pd, .div },
                        .max => if (self.hasFeature(.avx)) .{ .v_pd, .max } else .{ ._pd, .max },
                        .min => if (self.hasFeature(.avx)) .{ .v_pd, .min } else .{ ._pd, .min },
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_eq,
                        .cmp_gte,
                        .cmp_gt,
                        .cmp_neq,
                        => if (self.hasFeature(.avx)) .{ .v_pd, .cmp } else .{ ._pd, .cmp },
                        else => unreachable,
                    },
                    3...4 => if (self.hasFeature(.avx)) switch (air_tag) {
                        .add => .{ .v_pd, .add },
                        .sub => .{ .v_pd, .sub },
                        .mul => .{ .v_pd, .mul },
                        .div_float, .div_trunc, .div_floor, .div_exact => .{ .v_pd, .div },
                        .max => .{ .v_pd, .max },
                        .cmp_lt, .cmp_lte, .cmp_eq, .cmp_gte, .cmp_gt, .cmp_neq => .{ .v_pd, .cmp },
                        .min => .{ .v_pd, .min },
                        else => unreachable,
                    } else null,
                    else => null,
                },
                80, 128 => null,
                else => unreachable,
            },
        },
    }) orelse return self.fail("TODO implement genBinOp for {s} {}", .{
        @tagName(air_tag), lhs_ty.fmt(pt),
    });

    const lhs_copy_reg = if (maybe_mask_reg) |_| registerAlias(
        if (copied_to_dst) try self.copyToTmpRegister(lhs_ty, dst_mcv) else lhs_mcv.getReg().?,
        abi_size,
    ) else null;
    const lhs_copy_lock = if (lhs_copy_reg) |reg| self.register_manager.lockReg(reg) else null;
    defer if (lhs_copy_lock) |lock| self.register_manager.unlockReg(lock);

    switch (mir_tag[1]) {
        else => if (self.hasFeature(.avx)) {
            const lhs_reg =
                if (copied_to_dst) dst_reg else registerAlias(lhs_mcv.getReg().?, abi_size);
            if (src_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                mir_tag,
                dst_reg,
                lhs_reg,
                try src_mcv.mem(self, switch (lhs_ty.zigTypeTag(zcu)) {
                    else => Memory.Size.fromSize(abi_size),
                    .vector => Memory.Size.fromBitSize(dst_reg.bitSize()),
                }),
            ) else try self.asmRegisterRegisterRegister(
                mir_tag,
                dst_reg,
                lhs_reg,
                registerAlias(if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(rhs_ty, src_mcv), abi_size),
            );
        } else {
            assert(copied_to_dst);
            if (src_mcv.isMemory()) try self.asmRegisterMemory(
                mir_tag,
                dst_reg,
                try src_mcv.mem(self, switch (lhs_ty.zigTypeTag(zcu)) {
                    else => Memory.Size.fromSize(abi_size),
                    .vector => Memory.Size.fromBitSize(dst_reg.bitSize()),
                }),
            ) else try self.asmRegisterRegister(
                mir_tag,
                dst_reg,
                registerAlias(if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(rhs_ty, src_mcv), abi_size),
            );
        },
        .cmp => {
            const imm = Immediate.u(switch (air_tag) {
                .cmp_eq => 0,
                .cmp_lt, .cmp_gt => 1,
                .cmp_lte, .cmp_gte => 2,
                .cmp_neq => 4,
                else => unreachable,
            });
            if (self.hasFeature(.avx)) {
                const lhs_reg =
                    if (copied_to_dst) dst_reg else registerAlias(lhs_mcv.getReg().?, abi_size);
                if (src_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                    mir_tag,
                    dst_reg,
                    lhs_reg,
                    try src_mcv.mem(self, switch (lhs_ty.zigTypeTag(zcu)) {
                        else => Memory.Size.fromSize(abi_size),
                        .vector => Memory.Size.fromBitSize(dst_reg.bitSize()),
                    }),
                    imm,
                ) else try self.asmRegisterRegisterRegisterImmediate(
                    mir_tag,
                    dst_reg,
                    lhs_reg,
                    registerAlias(if (src_mcv.isRegister())
                        src_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(rhs_ty, src_mcv), abi_size),
                    imm,
                );
            } else {
                assert(copied_to_dst);
                if (src_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
                    mir_tag,
                    dst_reg,
                    try src_mcv.mem(self, switch (lhs_ty.zigTypeTag(zcu)) {
                        else => Memory.Size.fromSize(abi_size),
                        .vector => Memory.Size.fromBitSize(dst_reg.bitSize()),
                    }),
                    imm,
                ) else try self.asmRegisterRegisterImmediate(
                    mir_tag,
                    dst_reg,
                    registerAlias(if (src_mcv.isRegister())
                        src_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(rhs_ty, src_mcv), abi_size),
                    imm,
                );
            }
        },
    }

    switch (air_tag) {
        .add, .add_wrap, .sub, .sub_wrap, .mul, .mul_wrap, .div_float, .div_exact => {},
        .div_trunc, .div_floor => try self.genRound(lhs_ty, dst_reg, .{ .register = dst_reg }, .{
            .mode = switch (air_tag) {
                .div_trunc => .zero,
                .div_floor => .down,
                else => unreachable,
            },
            .precision = .inexact,
        }),
        .bit_and, .bit_or, .xor => {},
        .max, .min => if (maybe_mask_reg) |mask_reg| if (self.hasFeature(.avx)) {
            const rhs_copy_reg = registerAlias(src_mcv.getReg().?, abi_size);

            try self.asmRegisterRegisterRegisterImmediate(
                @as(?Mir.Inst.FixedTag, switch (lhs_ty.zigTypeTag(zcu)) {
                    .float => switch (lhs_ty.floatBits(self.target.*)) {
                        32 => .{ .v_ss, .cmp },
                        64 => .{ .v_sd, .cmp },
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    .vector => switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
                        .float => switch (lhs_ty.childType(zcu).floatBits(self.target.*)) {
                            32 => switch (lhs_ty.vectorLen(zcu)) {
                                1 => .{ .v_ss, .cmp },
                                2...8 => .{ .v_ps, .cmp },
                                else => null,
                            },
                            64 => switch (lhs_ty.vectorLen(zcu)) {
                                1 => .{ .v_sd, .cmp },
                                2...4 => .{ .v_pd, .cmp },
                                else => null,
                            },
                            16, 80, 128 => null,
                            else => unreachable,
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                }) orelse return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(air_tag), lhs_ty.fmt(pt),
                }),
                mask_reg,
                rhs_copy_reg,
                rhs_copy_reg,
                Immediate.u(3), // unord
            );
            try self.asmRegisterRegisterRegisterRegister(
                @as(?Mir.Inst.FixedTag, switch (lhs_ty.zigTypeTag(zcu)) {
                    .float => switch (lhs_ty.floatBits(self.target.*)) {
                        32 => .{ .v_ps, .blendv },
                        64 => .{ .v_pd, .blendv },
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    .vector => switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
                        .float => switch (lhs_ty.childType(zcu).floatBits(self.target.*)) {
                            32 => switch (lhs_ty.vectorLen(zcu)) {
                                1...8 => .{ .v_ps, .blendv },
                                else => null,
                            },
                            64 => switch (lhs_ty.vectorLen(zcu)) {
                                1...4 => .{ .v_pd, .blendv },
                                else => null,
                            },
                            16, 80, 128 => null,
                            else => unreachable,
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                }) orelse return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(air_tag), lhs_ty.fmt(pt),
                }),
                dst_reg,
                dst_reg,
                lhs_copy_reg.?,
                mask_reg,
            );
        } else {
            const has_blend = self.hasFeature(.sse4_1);
            try self.asmRegisterRegisterImmediate(
                @as(?Mir.Inst.FixedTag, switch (lhs_ty.zigTypeTag(zcu)) {
                    .float => switch (lhs_ty.floatBits(self.target.*)) {
                        32 => .{ ._ss, .cmp },
                        64 => .{ ._sd, .cmp },
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    .vector => switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
                        .float => switch (lhs_ty.childType(zcu).floatBits(self.target.*)) {
                            32 => switch (lhs_ty.vectorLen(zcu)) {
                                1 => .{ ._ss, .cmp },
                                2...4 => .{ ._ps, .cmp },
                                else => null,
                            },
                            64 => switch (lhs_ty.vectorLen(zcu)) {
                                1 => .{ ._sd, .cmp },
                                2 => .{ ._pd, .cmp },
                                else => null,
                            },
                            16, 80, 128 => null,
                            else => unreachable,
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                }) orelse return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(air_tag), lhs_ty.fmt(pt),
                }),
                mask_reg,
                mask_reg,
                Immediate.u(if (has_blend) 3 else 7), // unord, ord
            );
            if (has_blend) try self.asmRegisterRegisterRegister(
                @as(?Mir.Inst.FixedTag, switch (lhs_ty.zigTypeTag(zcu)) {
                    .float => switch (lhs_ty.floatBits(self.target.*)) {
                        32 => .{ ._ps, .blendv },
                        64 => .{ ._pd, .blendv },
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    .vector => switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
                        .float => switch (lhs_ty.childType(zcu).floatBits(self.target.*)) {
                            32 => switch (lhs_ty.vectorLen(zcu)) {
                                1...4 => .{ ._ps, .blendv },
                                else => null,
                            },
                            64 => switch (lhs_ty.vectorLen(zcu)) {
                                1...2 => .{ ._pd, .blendv },
                                else => null,
                            },
                            16, 80, 128 => null,
                            else => unreachable,
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                }) orelse return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(air_tag), lhs_ty.fmt(pt),
                }),
                dst_reg,
                lhs_copy_reg.?,
                mask_reg,
            ) else {
                const mir_fixes = @as(?Mir.Inst.Fixes, switch (lhs_ty.zigTypeTag(zcu)) {
                    .float => switch (lhs_ty.floatBits(self.target.*)) {
                        32 => ._ps,
                        64 => ._pd,
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    .vector => switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
                        .float => switch (lhs_ty.childType(zcu).floatBits(self.target.*)) {
                            32 => switch (lhs_ty.vectorLen(zcu)) {
                                1...4 => ._ps,
                                else => null,
                            },
                            64 => switch (lhs_ty.vectorLen(zcu)) {
                                1...2 => ._pd,
                                else => null,
                            },
                            16, 80, 128 => null,
                            else => unreachable,
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                }) orelse return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(air_tag), lhs_ty.fmt(pt),
                });
                try self.asmRegisterRegister(.{ mir_fixes, .@"and" }, dst_reg, mask_reg);
                try self.asmRegisterRegister(.{ mir_fixes, .andn }, mask_reg, lhs_copy_reg.?);
                try self.asmRegisterRegister(.{ mir_fixes, .@"or" }, dst_reg, mask_reg);
            }
        },
        .cmp_lt, .cmp_lte, .cmp_eq, .cmp_gte, .cmp_gt, .cmp_neq => {
            switch (lhs_ty.childType(zcu).zigTypeTag(zcu)) {
                .int => switch (air_tag) {
                    .cmp_lt,
                    .cmp_eq,
                    .cmp_gt,
                    => {},
                    .cmp_lte,
                    .cmp_gte,
                    .cmp_neq,
                    => {
                        const unsigned_ty = try lhs_ty.toUnsigned(pt);
                        const not_mcv = try self.genTypedValue(try unsigned_ty.maxInt(pt, unsigned_ty));
                        const not_mem: Memory = if (not_mcv.isMemory())
                            try not_mcv.mem(self, Memory.Size.fromSize(abi_size))
                        else
                            .{ .base = .{
                                .reg = try self.copyToTmpRegister(Type.usize, not_mcv.address()),
                            }, .mod = .{ .rm = .{ .size = Memory.Size.fromSize(abi_size) } } };
                        switch (mir_tag[0]) {
                            .vp_b, .vp_d, .vp_q, .vp_w => try self.asmRegisterRegisterMemory(
                                .{ .vp_, .xor },
                                dst_reg,
                                dst_reg,
                                not_mem,
                            ),
                            .p_b, .p_d, .p_q, .p_w => try self.asmRegisterMemory(
                                .{ .p_, .xor },
                                dst_reg,
                                not_mem,
                            ),
                            else => unreachable,
                        }
                    },
                    else => unreachable,
                },
                .float => {},
                else => unreachable,
            }

            const gp_reg = try self.register_manager.allocReg(maybe_inst, abi.RegisterClass.gp);
            const gp_lock = self.register_manager.lockRegAssumeUnused(gp_reg);
            defer self.register_manager.unlockReg(gp_lock);

            try self.asmRegisterRegister(switch (mir_tag[0]) {
                ._pd, ._sd, .p_q => .{ ._pd, .movmsk },
                ._ps, ._ss, .p_d => .{ ._ps, .movmsk },
                .p_b => .{ .p_b, .movmsk },
                .p_w => movmsk: {
                    try self.asmRegisterRegister(.{ .p_b, .ackssw }, dst_reg, dst_reg);
                    break :movmsk .{ .p_b, .movmsk };
                },
                .v_pd, .v_sd, .vp_q => .{ .v_pd, .movmsk },
                .v_ps, .v_ss, .vp_d => .{ .v_ps, .movmsk },
                .vp_b => .{ .vp_b, .movmsk },
                .vp_w => movmsk: {
                    try self.asmRegisterRegisterRegister(
                        .{ .vp_b, .ackssw },
                        dst_reg,
                        dst_reg,
                        dst_reg,
                    );
                    break :movmsk .{ .vp_b, .movmsk };
                },
                else => unreachable,
            }, gp_reg.to32(), dst_reg);
            return .{ .register = gp_reg };
        },
        else => unreachable,
    }

    return dst_mcv;
}

fn genBinOpMir(
    self: *Self,
    mir_tag: Mir.Inst.FixedTag,
    ty: Type,
    dst_mcv: MCValue,
    src_mcv: MCValue,
) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size: u32 = @intCast(ty.abiSize(zcu));
    try self.spillEflagsIfOccupied();
    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .eflags,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .lea_symbol,
        .elementwise_regs_then_frame,
        .reserved_frame,
        .air_ref,
        => unreachable, // unmodifiable destination
        .register, .register_pair, .register_offset => {
            switch (dst_mcv) {
                .register, .register_pair => {},
                .register_offset => |ro| assert(ro.off == 0),
                else => unreachable,
            }
            for (dst_mcv.getRegs(), 0..) |dst_reg, dst_reg_i| {
                const dst_reg_lock = self.register_manager.lockReg(dst_reg);
                defer if (dst_reg_lock) |lock| self.register_manager.unlockReg(lock);

                const mir_limb_tag: Mir.Inst.FixedTag = switch (dst_reg_i) {
                    0 => mir_tag,
                    1 => switch (mir_tag[1]) {
                        .add => .{ ._, .adc },
                        .sub, .cmp => .{ ._, .sbb },
                        .@"or", .@"and", .xor => mir_tag,
                        else => return self.fail("TODO genBinOpMir implement large ABI for {s}", .{
                            @tagName(mir_tag[1]),
                        }),
                    },
                    else => unreachable,
                };
                const off: u4 = @intCast(dst_reg_i * 8);
                const limb_abi_size = @min(abi_size - off, 8);
                const dst_alias = registerAlias(dst_reg, limb_abi_size);
                switch (src_mcv) {
                    .none,
                    .unreach,
                    .dead,
                    .undef,
                    .register_overflow,
                    .elementwise_regs_then_frame,
                    .reserved_frame,
                    => unreachable,
                    .register, .register_pair => try self.asmRegisterRegister(
                        mir_limb_tag,
                        dst_alias,
                        registerAlias(src_mcv.getRegs()[dst_reg_i], limb_abi_size),
                    ),
                    .immediate => |imm| {
                        assert(off == 0);
                        switch (self.regBitSize(ty)) {
                            8 => try self.asmRegisterImmediate(
                                mir_limb_tag,
                                dst_alias,
                                if (math.cast(i8, @as(i64, @bitCast(imm)))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@as(u8, @intCast(imm))),
                            ),
                            16 => try self.asmRegisterImmediate(
                                mir_limb_tag,
                                dst_alias,
                                if (math.cast(i16, @as(i64, @bitCast(imm)))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@as(u16, @intCast(imm))),
                            ),
                            32 => try self.asmRegisterImmediate(
                                mir_limb_tag,
                                dst_alias,
                                if (math.cast(i32, @as(i64, @bitCast(imm)))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@as(u32, @intCast(imm))),
                            ),
                            64 => if (math.cast(i32, @as(i64, @bitCast(imm)))) |small|
                                try self.asmRegisterImmediate(mir_limb_tag, dst_alias, Immediate.s(small))
                            else
                                try self.asmRegisterRegister(mir_limb_tag, dst_alias, registerAlias(
                                    try self.copyToTmpRegister(ty, src_mcv),
                                    limb_abi_size,
                                )),
                            else => unreachable,
                        }
                    },
                    .eflags,
                    .register_offset,
                    .memory,
                    .indirect,
                    .load_symbol,
                    .lea_symbol,
                    .load_direct,
                    .lea_direct,
                    .load_got,
                    .lea_got,
                    .load_tlv,
                    .lea_tlv,
                    .load_frame,
                    .lea_frame,
                    => {
                        direct: {
                            try self.asmRegisterMemory(mir_limb_tag, dst_alias, switch (src_mcv) {
                                .memory => |addr| .{
                                    .base = .{ .reg = .ds },
                                    .mod = .{ .rm = .{
                                        .size = Memory.Size.fromSize(limb_abi_size),
                                        .disp = math.cast(i32, addr + off) orelse break :direct,
                                    } },
                                },
                                .indirect => |reg_off| .{
                                    .base = .{ .reg = reg_off.reg },
                                    .mod = .{ .rm = .{
                                        .size = Memory.Size.fromSize(limb_abi_size),
                                        .disp = reg_off.off + off,
                                    } },
                                },
                                .load_frame => |frame_addr| .{
                                    .base = .{ .frame = frame_addr.index },
                                    .mod = .{ .rm = .{
                                        .size = Memory.Size.fromSize(limb_abi_size),
                                        .disp = frame_addr.off + off,
                                    } },
                                },
                                else => break :direct,
                            });
                            continue;
                        }

                        switch (src_mcv) {
                            .eflags,
                            .register_offset,
                            .lea_symbol,
                            .lea_direct,
                            .lea_got,
                            .lea_tlv,
                            .lea_frame,
                            => {
                                assert(off == 0);
                                const reg = try self.copyToTmpRegister(ty, src_mcv);
                                return self.genBinOpMir(
                                    mir_limb_tag,
                                    ty,
                                    dst_mcv,
                                    .{ .register = reg },
                                );
                            },
                            .memory,
                            .load_symbol,
                            .load_direct,
                            .load_got,
                            .load_tlv,
                            => {
                                const ptr_ty = try pt.singleConstPtrType(ty);
                                const addr_reg = try self.copyToTmpRegister(ptr_ty, src_mcv.address());
                                return self.genBinOpMir(mir_limb_tag, ty, dst_mcv, .{
                                    .indirect = .{ .reg = addr_reg, .off = off },
                                });
                            },
                            else => unreachable,
                        }
                    },
                    .air_ref => |src_ref| return self.genBinOpMir(
                        mir_tag,
                        ty,
                        dst_mcv,
                        try self.resolveInst(src_ref),
                    ),
                }
            }
        },
        .memory, .indirect, .load_symbol, .load_got, .load_direct, .load_tlv, .load_frame => {
            const OpInfo = ?struct { addr_reg: Register, addr_lock: RegisterLock };
            const limb_abi_size: u32 = @min(abi_size, 8);

            const dst_info: OpInfo = switch (dst_mcv) {
                else => unreachable,
                .memory, .load_symbol, .load_got, .load_direct, .load_tlv => dst: {
                    const dst_addr_reg =
                        (try self.register_manager.allocReg(null, abi.RegisterClass.gp)).to64();
                    const dst_addr_lock = self.register_manager.lockRegAssumeUnused(dst_addr_reg);
                    errdefer self.register_manager.unlockReg(dst_addr_lock);

                    try self.genSetReg(dst_addr_reg, Type.usize, dst_mcv.address(), .{});
                    break :dst .{ .addr_reg = dst_addr_reg, .addr_lock = dst_addr_lock };
                },
                .load_frame => null,
            };
            defer if (dst_info) |info| self.register_manager.unlockReg(info.addr_lock);

            const resolved_src_mcv = switch (src_mcv) {
                else => src_mcv,
                .air_ref => |src_ref| try self.resolveInst(src_ref),
            };
            const src_info: OpInfo = switch (resolved_src_mcv) {
                .none,
                .unreach,
                .dead,
                .undef,
                .register_overflow,
                .elementwise_regs_then_frame,
                .reserved_frame,
                .air_ref,
                => unreachable,
                .immediate,
                .eflags,
                .register,
                .register_pair,
                .register_offset,
                .indirect,
                .lea_direct,
                .lea_got,
                .lea_tlv,
                .load_frame,
                .lea_frame,
                .lea_symbol,
                => null,
                .memory, .load_symbol, .load_got, .load_direct, .load_tlv => src: {
                    switch (resolved_src_mcv) {
                        .memory => |addr| if (math.cast(i32, @as(i64, @bitCast(addr))) != null and
                            math.cast(i32, @as(i64, @bitCast(addr)) + abi_size - limb_abi_size) != null)
                            break :src null,
                        .load_symbol, .load_got, .load_direct, .load_tlv => {},
                        else => unreachable,
                    }

                    const src_addr_reg =
                        (try self.register_manager.allocReg(null, abi.RegisterClass.gp)).to64();
                    const src_addr_lock = self.register_manager.lockRegAssumeUnused(src_addr_reg);
                    errdefer self.register_manager.unlockReg(src_addr_lock);

                    try self.genSetReg(src_addr_reg, Type.usize, resolved_src_mcv.address(), .{});
                    break :src .{ .addr_reg = src_addr_reg, .addr_lock = src_addr_lock };
                },
            };
            defer if (src_info) |info| self.register_manager.unlockReg(info.addr_lock);

            const ty_signedness =
                if (ty.isAbiInt(zcu)) ty.intInfo(zcu).signedness else .unsigned;
            const limb_ty = if (abi_size <= 8) ty else switch (ty_signedness) {
                .signed => Type.usize,
                .unsigned => Type.isize,
            };
            var limb_i: usize = 0;
            var off: i32 = 0;
            while (off < abi_size) : ({
                limb_i += 1;
                off += 8;
            }) {
                const mir_limb_tag: Mir.Inst.FixedTag = switch (limb_i) {
                    0 => mir_tag,
                    else => switch (mir_tag[1]) {
                        .add => .{ ._, .adc },
                        .sub, .cmp => .{ ._, .sbb },
                        .@"or", .@"and", .xor => mir_tag,
                        else => return self.fail("TODO genBinOpMir implement large ABI for {s}", .{
                            @tagName(mir_tag[1]),
                        }),
                    },
                };
                const dst_limb_mem: Memory = switch (dst_mcv) {
                    .memory,
                    .load_symbol,
                    .load_got,
                    .load_direct,
                    .load_tlv,
                    => .{
                        .base = .{ .reg = dst_info.?.addr_reg },
                        .mod = .{ .rm = .{
                            .size = Memory.Size.fromSize(limb_abi_size),
                            .disp = off,
                        } },
                    },
                    .indirect => |reg_off| .{
                        .base = .{ .reg = reg_off.reg },
                        .mod = .{ .rm = .{
                            .size = Memory.Size.fromSize(limb_abi_size),
                            .disp = reg_off.off + off,
                        } },
                    },
                    .load_frame => |frame_addr| .{
                        .base = .{ .frame = frame_addr.index },
                        .mod = .{ .rm = .{
                            .size = Memory.Size.fromSize(limb_abi_size),
                            .disp = frame_addr.off + off,
                        } },
                    },
                    else => unreachable,
                };
                switch (resolved_src_mcv) {
                    .none,
                    .unreach,
                    .dead,
                    .undef,
                    .register_overflow,
                    .elementwise_regs_then_frame,
                    .reserved_frame,
                    .air_ref,
                    => unreachable,
                    .immediate => |src_imm| {
                        const imm: u64 = switch (limb_i) {
                            0 => src_imm,
                            else => switch (ty_signedness) {
                                .signed => @bitCast(@as(i64, @bitCast(src_imm)) >> 63),
                                .unsigned => 0,
                            },
                        };
                        switch (self.regBitSize(limb_ty)) {
                            8 => try self.asmMemoryImmediate(
                                mir_limb_tag,
                                dst_limb_mem,
                                if (math.cast(i8, @as(i64, @bitCast(imm)))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@as(u8, @intCast(imm))),
                            ),
                            16 => try self.asmMemoryImmediate(
                                mir_limb_tag,
                                dst_limb_mem,
                                if (math.cast(i16, @as(i64, @bitCast(imm)))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@as(u16, @intCast(imm))),
                            ),
                            32 => try self.asmMemoryImmediate(
                                mir_limb_tag,
                                dst_limb_mem,
                                if (math.cast(i32, @as(i64, @bitCast(imm)))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@as(u32, @intCast(imm))),
                            ),
                            64 => if (math.cast(i32, @as(i64, @bitCast(imm)))) |small|
                                try self.asmMemoryImmediate(
                                    mir_limb_tag,
                                    dst_limb_mem,
                                    Immediate.s(small),
                                )
                            else
                                try self.asmMemoryRegister(
                                    mir_limb_tag,
                                    dst_limb_mem,
                                    registerAlias(
                                        try self.copyToTmpRegister(limb_ty, .{ .immediate = imm }),
                                        limb_abi_size,
                                    ),
                                ),
                            else => unreachable,
                        }
                    },
                    .register,
                    .register_pair,
                    .register_offset,
                    .eflags,
                    .memory,
                    .indirect,
                    .load_symbol,
                    .lea_symbol,
                    .load_direct,
                    .lea_direct,
                    .load_got,
                    .lea_got,
                    .load_tlv,
                    .lea_tlv,
                    .load_frame,
                    .lea_frame,
                    => {
                        const src_limb_mcv: MCValue = if (src_info) |info| .{
                            .indirect = .{ .reg = info.addr_reg, .off = off },
                        } else switch (resolved_src_mcv) {
                            .register, .register_pair => .{
                                .register = resolved_src_mcv.getRegs()[limb_i],
                            },
                            .eflags,
                            .register_offset,
                            .lea_symbol,
                            .lea_direct,
                            .lea_got,
                            .lea_tlv,
                            .lea_frame,
                            => switch (limb_i) {
                                0 => resolved_src_mcv,
                                else => .{ .immediate = 0 },
                            },
                            .memory => |addr| .{ .memory = @bitCast(@as(i64, @bitCast(addr)) + off) },
                            .indirect => |reg_off| .{ .indirect = .{
                                .reg = reg_off.reg,
                                .off = reg_off.off + off,
                            } },
                            .load_frame => |frame_addr| .{ .load_frame = .{
                                .index = frame_addr.index,
                                .off = frame_addr.off + off,
                            } },
                            else => unreachable,
                        };
                        const src_limb_reg = if (src_limb_mcv.isRegister())
                            src_limb_mcv.getReg().?
                        else
                            try self.copyToTmpRegister(limb_ty, src_limb_mcv);
                        try self.asmMemoryRegister(
                            mir_limb_tag,
                            dst_limb_mem,
                            registerAlias(src_limb_reg, limb_abi_size),
                        );
                    },
                }
            }
        },
    }
}

/// Performs multi-operand integer multiplication between dst_mcv and src_mcv, storing the result in dst_mcv.
/// Does not support byte-size operands.
fn genIntMulComplexOpMir(self: *Self, dst_ty: Type, dst_mcv: MCValue, src_mcv: MCValue) InnerError!void {
    const pt = self.pt;
    const abi_size: u32 = @intCast(dst_ty.abiSize(pt.zcu));
    try self.spillEflagsIfOccupied();
    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .eflags,
        .register_offset,
        .register_overflow,
        .lea_symbol,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .elementwise_regs_then_frame,
        .reserved_frame,
        .air_ref,
        => unreachable, // unmodifiable destination
        .register => |dst_reg| {
            const dst_alias = registerAlias(dst_reg, abi_size);
            const dst_lock = self.register_manager.lockReg(dst_reg);
            defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

            const resolved_src_mcv = switch (src_mcv) {
                else => src_mcv,
                .air_ref => |src_ref| try self.resolveInst(src_ref),
            };
            switch (resolved_src_mcv) {
                .none,
                .unreach,
                .dead,
                .undef,
                .register_pair,
                .register_overflow,
                .elementwise_regs_then_frame,
                .reserved_frame,
                .air_ref,
                => unreachable,
                .register => |src_reg| try self.asmRegisterRegister(
                    .{ .i_, .mul },
                    dst_alias,
                    registerAlias(src_reg, abi_size),
                ),
                .immediate => |imm| {
                    if (math.cast(i32, imm)) |small| {
                        try self.asmRegisterRegisterImmediate(
                            .{ .i_, .mul },
                            dst_alias,
                            dst_alias,
                            Immediate.s(small),
                        );
                    } else {
                        const src_reg = try self.copyToTmpRegister(dst_ty, resolved_src_mcv);
                        return self.genIntMulComplexOpMir(dst_ty, dst_mcv, MCValue{ .register = src_reg });
                    }
                },
                .register_offset,
                .eflags,
                .load_symbol,
                .lea_symbol,
                .load_direct,
                .lea_direct,
                .load_got,
                .lea_got,
                .load_tlv,
                .lea_tlv,
                .lea_frame,
                => try self.asmRegisterRegister(
                    .{ .i_, .mul },
                    dst_alias,
                    registerAlias(try self.copyToTmpRegister(dst_ty, resolved_src_mcv), abi_size),
                ),
                .memory, .indirect, .load_frame => try self.asmRegisterMemory(
                    .{ .i_, .mul },
                    dst_alias,
                    switch (resolved_src_mcv) {
                        .memory => |addr| .{
                            .base = .{ .reg = .ds },
                            .mod = .{ .rm = .{
                                .size = Memory.Size.fromSize(abi_size),
                                .disp = math.cast(i32, @as(i64, @bitCast(addr))) orelse
                                    return self.asmRegisterRegister(
                                    .{ .i_, .mul },
                                    dst_alias,
                                    registerAlias(
                                        try self.copyToTmpRegister(dst_ty, resolved_src_mcv),
                                        abi_size,
                                    ),
                                ),
                            } },
                        },
                        .indirect => |reg_off| .{
                            .base = .{ .reg = reg_off.reg },
                            .mod = .{ .rm = .{
                                .size = Memory.Size.fromSize(abi_size),
                                .disp = reg_off.off,
                            } },
                        },
                        .load_frame => |frame_addr| .{
                            .base = .{ .frame = frame_addr.index },
                            .mod = .{ .rm = .{
                                .size = Memory.Size.fromSize(abi_size),
                                .disp = frame_addr.off,
                            } },
                        },
                        else => unreachable,
                    },
                ),
            }
        },
        .register_pair => unreachable, // unimplemented
        .memory, .indirect, .load_symbol, .load_direct, .load_got, .load_tlv, .load_frame => {
            const tmp_reg = try self.copyToTmpRegister(dst_ty, dst_mcv);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genIntMulComplexOpMir(dst_ty, tmp_mcv, src_mcv);
            try self.genCopy(dst_ty, dst_mcv, tmp_mcv, .{});
        },
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    // skip zero-bit arguments as they don't have a corresponding arg instruction
    var arg_index = self.arg_index;
    while (self.args[arg_index] == .none) arg_index += 1;
    self.arg_index = arg_index + 1;

    const result: MCValue = if (self.debug_output == .none and self.liveness.isUnused(inst)) .unreach else result: {
        const arg_ty = self.typeOfIndex(inst);
        const src_mcv = self.args[arg_index];
        switch (src_mcv) {
            .register, .register_pair, .load_frame => {
                for (src_mcv.getRegs()) |reg| self.register_manager.getRegAssumeFree(reg, inst);
                break :result src_mcv;
            },
            .indirect => |reg_off| {
                self.register_manager.getRegAssumeFree(reg_off.reg, inst);
                const dst_mcv = try self.allocRegOrMem(inst, false);
                try self.genCopy(arg_ty, dst_mcv, src_mcv, .{});
                break :result dst_mcv;
            },
            .elementwise_regs_then_frame => |regs_frame_addr| {
                try self.spillEflagsIfOccupied();

                const fn_info = zcu.typeToFunc(self.fn_type).?;
                const cc = abi.resolveCallingConvention(fn_info.cc, self.target.*);
                const param_int_regs = abi.getCAbiIntParamRegs(cc);
                var prev_reg: Register = undefined;
                for (
                    param_int_regs[param_int_regs.len - regs_frame_addr.regs ..],
                    0..,
                ) |dst_reg, elem_index| {
                    assert(self.register_manager.isRegFree(dst_reg));
                    if (elem_index > 0) {
                        try self.asmRegisterImmediate(
                            .{ ._l, .sh },
                            dst_reg.to8(),
                            Immediate.u(elem_index),
                        );
                        try self.asmRegisterRegister(
                            .{ ._, .@"or" },
                            dst_reg.to8(),
                            prev_reg.to8(),
                        );
                    }
                    prev_reg = dst_reg;
                }

                const prev_lock = if (regs_frame_addr.regs > 0)
                    self.register_manager.lockRegAssumeUnused(prev_reg)
                else
                    null;
                defer if (prev_lock) |lock| self.register_manager.unlockReg(lock);

                const dst_mcv = try self.allocRegOrMem(inst, false);
                if (regs_frame_addr.regs > 0) try self.asmMemoryRegister(
                    .{ ._, .mov },
                    try dst_mcv.mem(self, .byte),
                    prev_reg.to8(),
                );
                try self.genInlineMemset(
                    dst_mcv.address().offset(@intFromBool(regs_frame_addr.regs > 0)),
                    .{ .immediate = 0 },
                    .{ .immediate = arg_ty.abiSize(zcu) - @intFromBool(regs_frame_addr.regs > 0) },
                    .{},
                );

                const index_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const index_lock = self.register_manager.lockRegAssumeUnused(index_reg);
                defer self.register_manager.unlockReg(index_lock);

                try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    index_reg.to32(),
                    Immediate.u(regs_frame_addr.regs),
                );
                const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                try self.asmMemoryImmediate(.{ ._, .cmp }, .{
                    .base = .{ .frame = regs_frame_addr.frame_index },
                    .mod = .{ .rm = .{
                        .size = .byte,
                        .index = index_reg.to64(),
                        .scale = .@"8",
                        .disp = regs_frame_addr.frame_off - @as(u6, regs_frame_addr.regs) * 8,
                    } },
                }, Immediate.u(0));
                const unset = try self.asmJccReloc(.e, undefined);
                try self.asmMemoryRegister(
                    .{ ._s, .bt },
                    try dst_mcv.mem(self, .dword),
                    index_reg.to32(),
                );
                self.performReloc(unset);
                if (self.hasFeature(.slow_incdec)) {
                    try self.asmRegisterImmediate(.{ ._, .add }, index_reg.to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, index_reg.to32());
                }
                try self.asmRegisterImmediate(
                    .{ ._, .cmp },
                    index_reg.to32(),
                    Immediate.u(arg_ty.vectorLen(zcu)),
                );
                _ = try self.asmJccReloc(.b, loop);

                break :result dst_mcv;
            },
            else => return self.fail("TODO implement arg for {}", .{src_mcv}),
        }
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airDbgArg(self: *Self, inst: Air.Inst.Index) !void {
    // skip zero-bit arguments as they don't have a corresponding arg instruction
    var arg_index = self.arg_index;
    while (self.args[arg_index] == .none) arg_index += 1;
    self.arg_index = arg_index + 1;

    if (self.debug_output != .none) {
        const name = self.air.instructions.items(.data)[@intFromEnum(inst)].arg.name;
        if (name != .none) try self.genLocalDebugInfo(inst, self.getResolvedInstValue(inst).short);
        if (self.liveness.isUnused(inst)) try self.processDeath(inst);
    }
    for (self.args[self.arg_index..]) |arg| {
        if (arg != .none) break;
    } else try self.airDbgVarArgs();
    self.finishAirBookkeeping();
}

fn airDbgVarArgs(self: *Self) !void {
    if (self.pt.zcu.typeToFunc(self.fn_type).?.is_var_args)
        try self.asmPseudo(.pseudo_dbg_var_args_none);
}

fn genLocalDebugInfo(
    self: *Self,
    inst: Air.Inst.Index,
    mcv: MCValue,
) !void {
    if (self.debug_output == .none) return;
    switch (self.air.instructions.items(.tag)[@intFromEnum(inst)]) {
        else => unreachable,
        .arg, .dbg_arg_inline, .dbg_var_val => |tag| {
            switch (mcv) {
                .none => try self.asmAir(.dbg_local, inst),
                .unreach, .dead, .elementwise_regs_then_frame, .reserved_frame, .air_ref => unreachable,
                .immediate => |imm| try self.asmAirImmediate(.dbg_local, inst, Immediate.u(imm)),
                .lea_frame => |frame_addr| try self.asmAirFrameAddress(.dbg_local, inst, frame_addr),
                .lea_symbol => |sym_off| try self.asmAirImmediate(.dbg_local, inst, Immediate.rel(sym_off)),
                else => {
                    const ty = switch (tag) {
                        else => unreachable,
                        .arg => self.typeOfIndex(inst),
                        .dbg_arg_inline, .dbg_var_val => self.typeOf(
                            self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op.operand,
                        ),
                    };
                    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(ty, self.pt.zcu));
                    try self.genSetMem(.{ .frame = frame_index }, 0, ty, mcv, .{});
                    try self.asmAirMemory(.dbg_local, inst, .{
                        .base = .{ .frame = frame_index },
                        .mod = .{ .rm = .{ .size = .qword } },
                    });
                },
            }
        },
        .dbg_var_ptr => switch (mcv) {
            else => unreachable,
            .unreach, .dead, .elementwise_regs_then_frame, .reserved_frame, .air_ref => unreachable,
            .lea_frame => |frame_addr| try self.asmAirMemory(.dbg_local, inst, .{
                .base = .{ .frame = frame_addr.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .disp = frame_addr.off,
                } },
            }),
            .lea_symbol => |sym_off| try self.asmAirMemory(.dbg_local, inst, .{
                .base = .{ .reloc = sym_off.sym_index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .disp = sym_off.off,
                } },
            }),
            .lea_direct, .lea_got, .lea_tlv => |sym_index| try self.asmAirMemory(.dbg_local, inst, .{
                .base = .{ .reloc = sym_index },
                .mod = .{ .rm = .{ .size = .qword } },
            }),
        },
    }
}

fn airTrap(self: *Self) !void {
    try self.asmOpOnly(.{ ._, .ud2 });
    self.finishAirBookkeeping();
}

fn airBreakpoint(self: *Self) !void {
    try self.asmOpOnly(.{ ._, .int3 });
    self.finishAirBookkeeping();
}

fn airRetAddr(self: *Self, inst: Air.Inst.Index) !void {
    const dst_mcv = try self.allocRegOrMem(inst, true);
    try self.genCopy(Type.usize, dst_mcv, .{ .load_frame = .{ .index = .ret_addr } }, .{});
    return self.finishAir(inst, dst_mcv, .{ .none, .none, .none });
}

fn airFrameAddress(self: *Self, inst: Air.Inst.Index) !void {
    const dst_mcv = try self.allocRegOrMem(inst, true);
    try self.genCopy(Type.usize, dst_mcv, .{ .lea_frame = .{ .index = .base_ptr } }, .{});
    return self.finishAir(inst, dst_mcv, .{ .none, .none, .none });
}

fn airFence(self: *Self, inst: Air.Inst.Index) !void {
    const order = self.air.instructions.items(.data)[@intFromEnum(inst)].fence;
    switch (order) {
        .unordered, .monotonic => unreachable,
        .acquire, .release, .acq_rel => {},
        .seq_cst => try self.asmOpOnly(.{ ._, .mfence }),
    }
    self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for x86_64", .{});

    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const arg_refs: []const Air.Inst.Ref =
        @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]);

    const ExpectedContents = extern struct {
        tys: [16][@sizeOf(Type)]u8 align(@alignOf(Type)),
        vals: [16][@sizeOf(MCValue)]u8 align(@alignOf(MCValue)),
    };
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
    const allocator = stack.get();

    const arg_tys = try allocator.alloc(Type, arg_refs.len);
    defer allocator.free(arg_tys);
    for (arg_tys, arg_refs) |*arg_ty, arg_ref| arg_ty.* = self.typeOf(arg_ref);

    const arg_vals = try allocator.alloc(MCValue, arg_refs.len);
    defer allocator.free(arg_vals);
    for (arg_vals, arg_refs) |*arg_val, arg_ref| arg_val.* = .{ .air_ref = arg_ref };

    const ret = try self.genCall(.{ .air = pl_op.operand }, arg_tys, arg_vals);

    var bt = self.liveness.iterateBigTomb(inst);
    try self.feed(&bt, pl_op.operand);
    for (arg_refs) |arg_ref| try self.feed(&bt, arg_ref);

    const result = if (self.liveness.isUnused(inst)) .unreach else ret;
    return self.finishAirResult(inst, result);
}

fn genCall(self: *Self, info: union(enum) {
    air: Air.Inst.Ref,
    lib: struct {
        return_type: InternPool.Index,
        param_types: []const InternPool.Index,
        lib: ?[]const u8 = null,
        callee: []const u8,
    },
}, arg_types: []const Type, args: []const MCValue) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    const fn_ty = switch (info) {
        .air => |callee| fn_info: {
            const callee_ty = self.typeOf(callee);
            break :fn_info switch (callee_ty.zigTypeTag(zcu)) {
                .@"fn" => callee_ty,
                .pointer => callee_ty.childType(zcu),
                else => unreachable,
            };
        },
        .lib => |lib| try pt.funcType(.{
            .param_types = lib.param_types,
            .return_type = lib.return_type,
            .cc = .C,
        }),
    };
    const fn_info = zcu.typeToFunc(fn_ty).?;
    const resolved_cc = abi.resolveCallingConvention(fn_info.cc, self.target.*);

    const ExpectedContents = extern struct {
        var_args: [16][@sizeOf(Type)]u8 align(@alignOf(Type)),
        frame_indices: [16]FrameIndex,
        reg_locks: [16][@sizeOf(?RegisterLock)]u8 align(@alignOf(?RegisterLock)),
    };
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
    const allocator = stack.get();

    const var_args = try allocator.alloc(Type, args.len - fn_info.param_types.len);
    defer allocator.free(var_args);
    for (var_args, arg_types[fn_info.param_types.len..]) |*var_arg, arg_ty| var_arg.* = arg_ty;

    const frame_indices = try allocator.alloc(FrameIndex, args.len);
    defer allocator.free(frame_indices);

    var reg_locks = std.ArrayList(?RegisterLock).init(allocator);
    defer reg_locks.deinit();
    try reg_locks.ensureTotalCapacity(16);
    defer for (reg_locks.items) |reg_lock| if (reg_lock) |lock| self.register_manager.unlockReg(lock);

    var call_info = try self.resolveCallingConventionValues(fn_info, var_args, .call_frame);
    defer call_info.deinit(self);

    // We need a properly aligned and sized call frame to be able to call this function.
    {
        const needed_call_frame = FrameAlloc.init(.{
            .size = call_info.stack_byte_count,
            .alignment = call_info.stack_align,
        });
        const frame_allocs_slice = self.frame_allocs.slice();
        const stack_frame_size =
            &frame_allocs_slice.items(.abi_size)[@intFromEnum(FrameIndex.call_frame)];
        stack_frame_size.* = @max(stack_frame_size.*, needed_call_frame.abi_size);
        const stack_frame_align =
            &frame_allocs_slice.items(.abi_align)[@intFromEnum(FrameIndex.call_frame)];
        stack_frame_align.* = stack_frame_align.max(needed_call_frame.abi_align);
    }

    try self.spillEflagsIfOccupied();
    try self.spillCallerPreservedRegs(resolved_cc);

    // set stack arguments first because this can clobber registers
    // also clobber spill arguments as we go
    switch (call_info.return_value.long) {
        .none, .unreach => {},
        .indirect => |reg_off| try self.register_manager.getReg(reg_off.reg, null),
        else => unreachable,
    }
    for (call_info.args, arg_types, args, frame_indices) |dst_arg, arg_ty, src_arg, *frame_index|
        switch (dst_arg) {
            .none => {},
            .register => |reg| {
                try self.register_manager.getReg(reg, null);
                try reg_locks.append(self.register_manager.lockReg(reg));
            },
            .register_pair => |regs| {
                for (regs) |reg| try self.register_manager.getReg(reg, null);
                try reg_locks.appendSlice(&self.register_manager.lockRegs(2, regs));
            },
            .indirect => |reg_off| {
                frame_index.* = try self.allocFrameIndex(FrameAlloc.initType(arg_ty, zcu));
                try self.genSetMem(.{ .frame = frame_index.* }, 0, arg_ty, src_arg, .{});
                try self.register_manager.getReg(reg_off.reg, null);
                try reg_locks.append(self.register_manager.lockReg(reg_off.reg));
            },
            .load_frame => {
                try self.genCopy(arg_ty, dst_arg, src_arg, .{});
                try self.freeValue(src_arg);
            },
            .elementwise_regs_then_frame => |regs_frame_addr| {
                const index_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const index_lock = self.register_manager.lockRegAssumeUnused(index_reg);
                defer self.register_manager.unlockReg(index_lock);

                const src_mem: Memory = if (src_arg.isMemory()) try src_arg.mem(self, .dword) else .{
                    .base = .{ .reg = try self.copyToTmpRegister(
                        Type.usize,
                        switch (src_arg) {
                            else => src_arg,
                            .air_ref => |src_ref| try self.resolveInst(src_ref),
                        }.address(),
                    ) },
                    .mod = .{ .rm = .{ .size = .dword } },
                };
                const src_lock = switch (src_mem.base) {
                    .reg => |src_reg| self.register_manager.lockReg(src_reg),
                    else => null,
                };
                defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

                try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    index_reg.to32(),
                    Immediate.u(regs_frame_addr.regs),
                );
                const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
                try self.asmMemoryRegister(.{ ._, .bt }, src_mem, index_reg.to32());
                try self.asmSetccMemory(.c, .{
                    .base = .{ .frame = regs_frame_addr.frame_index },
                    .mod = .{ .rm = .{
                        .size = .byte,
                        .index = index_reg.to64(),
                        .scale = .@"8",
                        .disp = regs_frame_addr.frame_off - @as(u6, regs_frame_addr.regs) * 8,
                    } },
                });
                if (self.hasFeature(.slow_incdec)) {
                    try self.asmRegisterImmediate(.{ ._, .add }, index_reg.to32(), Immediate.u(1));
                } else {
                    try self.asmRegister(.{ ._, .inc }, index_reg.to32());
                }
                try self.asmRegisterImmediate(
                    .{ ._, .cmp },
                    index_reg.to32(),
                    Immediate.u(arg_ty.vectorLen(zcu)),
                );
                _ = try self.asmJccReloc(.b, loop);

                const param_int_regs = abi.getCAbiIntParamRegs(resolved_cc);
                for (param_int_regs[param_int_regs.len - regs_frame_addr.regs ..]) |dst_reg| {
                    try self.register_manager.getReg(dst_reg, null);
                    try reg_locks.append(self.register_manager.lockReg(dst_reg));
                }
            },
            else => unreachable,
        };

    // now we are free to set register arguments
    switch (call_info.return_value.long) {
        .none, .unreach => {},
        .indirect => |reg_off| {
            const ret_ty = Type.fromInterned(fn_info.return_type);
            const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(ret_ty, zcu));
            try self.genSetReg(reg_off.reg, Type.usize, .{
                .lea_frame = .{ .index = frame_index, .off = -reg_off.off },
            }, .{});
            call_info.return_value.short = .{ .load_frame = .{ .index = frame_index } };
            try reg_locks.append(self.register_manager.lockReg(reg_off.reg));
        },
        else => unreachable,
    }

    for (call_info.args, arg_types, args, frame_indices) |dst_arg, arg_ty, src_arg, frame_index|
        switch (dst_arg) {
            .none, .load_frame => {},
            .register => |dst_reg| switch (fn_info.cc) {
                else => try self.genSetReg(
                    registerAlias(dst_reg, @intCast(arg_ty.abiSize(zcu))),
                    arg_ty,
                    src_arg,
                    .{},
                ),
                .C, .SysV, .Win64 => {
                    const promoted_ty = self.promoteInt(arg_ty);
                    const promoted_abi_size: u32 = @intCast(promoted_ty.abiSize(zcu));
                    const dst_alias = registerAlias(dst_reg, promoted_abi_size);
                    try self.genSetReg(dst_alias, promoted_ty, src_arg, .{});
                    if (promoted_ty.toIntern() != arg_ty.toIntern())
                        try self.truncateRegister(arg_ty, dst_alias);
                },
            },
            .register_pair => try self.genCopy(arg_ty, dst_arg, src_arg, .{}),
            .indirect => |reg_off| try self.genSetReg(reg_off.reg, Type.usize, .{
                .lea_frame = .{ .index = frame_index, .off = -reg_off.off },
            }, .{}),
            .elementwise_regs_then_frame => |regs_frame_addr| {
                const src_mem: Memory = if (src_arg.isMemory()) try src_arg.mem(self, .dword) else .{
                    .base = .{ .reg = try self.copyToTmpRegister(
                        Type.usize,
                        switch (src_arg) {
                            else => src_arg,
                            .air_ref => |src_ref| try self.resolveInst(src_ref),
                        }.address(),
                    ) },
                    .mod = .{ .rm = .{ .size = .dword } },
                };
                const src_lock = switch (src_mem.base) {
                    .reg => |src_reg| self.register_manager.lockReg(src_reg),
                    else => null,
                };
                defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

                const param_int_regs = abi.getCAbiIntParamRegs(resolved_cc);
                for (
                    param_int_regs[param_int_regs.len - regs_frame_addr.regs ..],
                    0..,
                ) |dst_reg, elem_index| {
                    try self.asmRegisterRegister(.{ ._, .xor }, dst_reg.to32(), dst_reg.to32());
                    try self.asmMemoryImmediate(
                        .{ ._, .bt },
                        src_mem,
                        Immediate.u(elem_index),
                    );
                    try self.asmSetccRegister(.c, dst_reg.to8());
                }
            },
            else => unreachable,
        };

    if (fn_info.is_var_args)
        try self.asmRegisterImmediate(.{ ._, .mov }, .al, Immediate.u(call_info.fp_count));

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    switch (info) {
        .air => |callee| if (try self.air.value(callee, pt)) |func_value| {
            const func_key = ip.indexToKey(func_value.ip_index);
            switch (switch (func_key) {
                else => func_key,
                .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                    .nav => |nav| ip.indexToKey(zcu.navValue(nav).toIntern()),
                    else => func_key,
                } else func_key,
            }) {
                .func => |func| {
                    if (self.bin_file.cast(.elf)) |elf_file| {
                        const zo = elf_file.zigObjectPtr().?;
                        const sym_index = try zo.getOrCreateMetadataForNav(elf_file, func.owner_nav);
                        try self.asmImmediate(.{ ._, .call }, Immediate.rel(.{ .sym_index = sym_index }));
                    } else if (self.bin_file.cast(.coff)) |coff_file| {
                        const atom = try coff_file.getOrCreateAtomForNav(func.owner_nav);
                        const sym_index = coff_file.getAtom(atom).getSymbolIndex().?;
                        try self.genSetReg(.rax, Type.usize, .{ .lea_got = sym_index }, .{});
                        try self.asmRegister(.{ ._, .call }, .rax);
                    } else if (self.bin_file.cast(.macho)) |macho_file| {
                        const zo = macho_file.getZigObject().?;
                        const sym_index = try zo.getOrCreateMetadataForNav(macho_file, func.owner_nav);
                        const sym = zo.symbols.items[sym_index];
                        try self.asmImmediate(.{ ._, .call }, Immediate.rel(.{ .sym_index = sym.nlist_idx }));
                    } else if (self.bin_file.cast(.plan9)) |p9| {
                        const atom_index = try p9.seeNav(pt, func.owner_nav);
                        const atom = p9.getAtom(atom_index);
                        try self.asmMemory(.{ ._, .call }, .{
                            .base = .{ .reg = .ds },
                            .mod = .{ .rm = .{
                                .size = .qword,
                                .disp = @intCast(atom.getOffsetTableAddress(p9)),
                            } },
                        });
                    } else unreachable;
                },
                .@"extern" => |@"extern"| if (self.bin_file.cast(.elf)) |elf_file| {
                    const target_sym_index = try elf_file.getGlobalSymbol(
                        @"extern".name.toSlice(ip),
                        @"extern".lib_name.toSlice(ip),
                    );
                    try self.asmImmediate(.{ ._, .call }, Immediate.rel(.{ .sym_index = target_sym_index }));
                } else if (self.bin_file.cast(.macho)) |macho_file| {
                    const target_sym_index = try macho_file.getGlobalSymbol(
                        @"extern".name.toSlice(ip),
                        @"extern".lib_name.toSlice(ip),
                    );
                    try self.asmImmediate(.{ ._, .call }, Immediate.rel(.{ .sym_index = target_sym_index }));
                } else try self.genExternSymbolRef(
                    .call,
                    @"extern".lib_name.toSlice(ip),
                    @"extern".name.toSlice(ip),
                ),
                else => return self.fail("TODO implement calling bitcasted functions", .{}),
            }
        } else {
            assert(self.typeOf(callee).zigTypeTag(zcu) == .pointer);
            try self.genSetReg(.rax, Type.usize, .{ .air_ref = callee }, .{});
            try self.asmRegister(.{ ._, .call }, .rax);
        },
        .lib => |lib| if (self.bin_file.cast(.elf)) |elf_file| {
            const target_sym_index = try elf_file.getGlobalSymbol(lib.callee, lib.lib);
            try self.asmImmediate(.{ ._, .call }, Immediate.rel(.{ .sym_index = target_sym_index }));
        } else if (self.bin_file.cast(.macho)) |macho_file| {
            const target_sym_index = try macho_file.getGlobalSymbol(lib.callee, lib.lib);
            try self.asmImmediate(.{ ._, .call }, Immediate.rel(.{ .sym_index = target_sym_index }));
        } else try self.genExternSymbolRef(.call, lib.lib, lib.callee),
    }
    return call_info.return_value.short;
}

fn airRet(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const ret_ty = self.fn_type.fnReturnType(zcu);
    switch (self.ret_mcv.short) {
        .none => {},
        .register,
        .register_pair,
        => try self.genCopy(ret_ty, self.ret_mcv.short, .{ .air_ref = un_op }, .{ .safety = safety }),
        .indirect => |reg_off| {
            try self.register_manager.getReg(reg_off.reg, null);
            const lock = self.register_manager.lockRegAssumeUnused(reg_off.reg);
            defer self.register_manager.unlockReg(lock);

            try self.genSetReg(reg_off.reg, Type.usize, self.ret_mcv.long, .{});
            try self.genSetMem(
                .{ .reg = reg_off.reg },
                reg_off.off,
                ret_ty,
                .{ .air_ref = un_op },
                .{ .safety = safety },
            );
        },
        else => unreachable,
    }
    self.ret_mcv.liveOut(self, inst);
    try self.finishAir(inst, .unreach, .{ un_op, .none, .none });

    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ptr = try self.resolveInst(un_op);

    const ptr_ty = self.typeOf(un_op);
    switch (self.ret_mcv.short) {
        .none => {},
        .register, .register_pair => try self.load(self.ret_mcv.short, ptr_ty, ptr),
        .indirect => |reg_off| try self.genSetReg(reg_off.reg, ptr_ty, ptr, .{}),
        else => unreachable,
    }
    self.ret_mcv.liveOut(self, inst);
    try self.finishAir(inst, .unreach, .{ un_op, .none, .none });

    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    var ty = self.typeOf(bin_op.lhs);
    var null_compare: ?Mir.Inst.Index = null;

    const result: Condition = result: {
        try self.spillEflagsIfOccupied();

        const lhs_mcv = try self.resolveInst(bin_op.lhs);
        const lhs_locks: [2]?RegisterLock = switch (lhs_mcv) {
            .register => |lhs_reg| .{ self.register_manager.lockRegAssumeUnused(lhs_reg), null },
            .register_pair => |lhs_regs| locks: {
                const locks = self.register_manager.lockRegsAssumeUnused(2, lhs_regs);
                break :locks .{ locks[0], locks[1] };
            },
            .register_offset => |lhs_ro| .{
                self.register_manager.lockRegAssumeUnused(lhs_ro.reg),
                null,
            },
            else => .{null} ** 2,
        };
        defer for (lhs_locks) |lhs_lock| if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const rhs_mcv = try self.resolveInst(bin_op.rhs);
        const rhs_locks: [2]?RegisterLock = switch (rhs_mcv) {
            .register => |rhs_reg| .{ self.register_manager.lockReg(rhs_reg), null },
            .register_pair => |rhs_regs| self.register_manager.lockRegs(2, rhs_regs),
            .register_offset => |rhs_ro| .{ self.register_manager.lockReg(rhs_ro.reg), null },
            else => .{null} ** 2,
        };
        defer for (rhs_locks) |rhs_lock| if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        switch (ty.zigTypeTag(zcu)) {
            .float => {
                const float_bits = ty.floatBits(self.target.*);
                if (switch (float_bits) {
                    16 => !self.hasFeature(.f16c),
                    32, 64 => false,
                    80, 128 => true,
                    else => unreachable,
                }) {
                    var callee_buf: ["__???f2".len]u8 = undefined;
                    const ret = try self.genCall(.{ .lib = .{
                        .return_type = .i32_type,
                        .param_types = &.{ ty.toIntern(), ty.toIntern() },
                        .callee = std.fmt.bufPrint(&callee_buf, "__{s}{c}f2", .{
                            switch (op) {
                                .eq => "eq",
                                .neq => "ne",
                                .lt => "lt",
                                .lte => "le",
                                .gt => "gt",
                                .gte => "ge",
                            },
                            floatCompilerRtAbiName(float_bits),
                        }) catch unreachable,
                    } }, &.{ ty, ty }, &.{ .{ .air_ref = bin_op.lhs }, .{ .air_ref = bin_op.rhs } });
                    try self.genBinOpMir(.{ ._, .@"test" }, Type.i32, ret, ret);
                    break :result switch (op) {
                        .eq => .e,
                        .neq => .ne,
                        .lt => .l,
                        .lte => .le,
                        .gt => .g,
                        .gte => .ge,
                    };
                }
            },
            .optional => if (!ty.optionalReprIsPayload(zcu)) {
                const opt_ty = ty;
                const opt_abi_size: u31 = @intCast(opt_ty.abiSize(zcu));
                ty = opt_ty.optionalChild(zcu);
                const payload_abi_size: u31 = @intCast(ty.abiSize(zcu));

                const temp_lhs_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const temp_lhs_lock = self.register_manager.lockRegAssumeUnused(temp_lhs_reg);
                defer self.register_manager.unlockReg(temp_lhs_lock);

                if (lhs_mcv.isMemory()) try self.asmRegisterMemory(
                    .{ ._, .mov },
                    temp_lhs_reg.to8(),
                    try lhs_mcv.address().offset(payload_abi_size).deref().mem(self, .byte),
                ) else {
                    try self.genSetReg(temp_lhs_reg, opt_ty, lhs_mcv, .{});
                    try self.asmRegisterImmediate(
                        .{ ._r, .sh },
                        registerAlias(temp_lhs_reg, opt_abi_size),
                        Immediate.u(payload_abi_size * 8),
                    );
                }

                const payload_compare = payload_compare: {
                    if (rhs_mcv.isMemory()) {
                        const rhs_mem =
                            try rhs_mcv.address().offset(payload_abi_size).deref().mem(self, .byte);
                        try self.asmMemoryRegister(.{ ._, .@"test" }, rhs_mem, temp_lhs_reg.to8());
                        const payload_compare = try self.asmJccReloc(.nz, undefined);
                        try self.asmRegisterMemory(.{ ._, .cmp }, temp_lhs_reg.to8(), rhs_mem);
                        break :payload_compare payload_compare;
                    }

                    const temp_rhs_reg = try self.copyToTmpRegister(opt_ty, rhs_mcv);
                    const temp_rhs_lock = self.register_manager.lockRegAssumeUnused(temp_rhs_reg);
                    defer self.register_manager.unlockReg(temp_rhs_lock);

                    try self.asmRegisterImmediate(
                        .{ ._r, .sh },
                        registerAlias(temp_rhs_reg, opt_abi_size),
                        Immediate.u(payload_abi_size * 8),
                    );
                    try self.asmRegisterRegister(
                        .{ ._, .@"test" },
                        temp_lhs_reg.to8(),
                        temp_rhs_reg.to8(),
                    );
                    const payload_compare = try self.asmJccReloc(.nz, undefined);
                    try self.asmRegisterRegister(
                        .{ ._, .cmp },
                        temp_lhs_reg.to8(),
                        temp_rhs_reg.to8(),
                    );
                    break :payload_compare payload_compare;
                };
                null_compare = try self.asmJmpReloc(undefined);
                self.performReloc(payload_compare);
            },
            else => {},
        }

        switch (ty.zigTypeTag(zcu)) {
            else => {
                const abi_size: u16 = @intCast(ty.abiSize(zcu));
                const may_flip: enum {
                    may_flip,
                    must_flip,
                    must_not_flip,
                } = if (abi_size > 8) switch (op) {
                    .lt, .gte => .must_not_flip,
                    .lte, .gt => .must_flip,
                    .eq, .neq => .may_flip,
                } else .may_flip;

                const flipped = switch (may_flip) {
                    .may_flip => !lhs_mcv.isRegister() and !lhs_mcv.isMemory(),
                    .must_flip => true,
                    .must_not_flip => false,
                };
                const unmat_dst_mcv = if (flipped) rhs_mcv else lhs_mcv;
                const dst_mcv = if (unmat_dst_mcv.isRegister() or
                    (abi_size <= 8 and unmat_dst_mcv.isMemory())) unmat_dst_mcv else dst: {
                    const dst_mcv = try self.allocTempRegOrMem(ty, true);
                    try self.genCopy(ty, dst_mcv, unmat_dst_mcv, .{});
                    break :dst dst_mcv;
                };
                const dst_lock =
                    if (dst_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
                defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

                const src_mcv = try self.resolveInst(if (flipped) bin_op.lhs else bin_op.rhs);
                const src_lock =
                    if (src_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
                defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

                break :result Condition.fromCompareOperator(
                    if (ty.isAbiInt(zcu)) ty.intInfo(zcu).signedness else .unsigned,
                    result_op: {
                        const flipped_op = if (flipped) op.reverse() else op;
                        if (abi_size > 8) switch (flipped_op) {
                            .lt, .gte => {},
                            .lte, .gt => unreachable,
                            .eq, .neq => {
                                const OpInfo = ?struct { addr_reg: Register, addr_lock: RegisterLock };

                                const resolved_dst_mcv = switch (dst_mcv) {
                                    else => dst_mcv,
                                    .air_ref => |dst_ref| try self.resolveInst(dst_ref),
                                };
                                const dst_info: OpInfo = switch (resolved_dst_mcv) {
                                    .none,
                                    .unreach,
                                    .dead,
                                    .undef,
                                    .immediate,
                                    .eflags,
                                    .register,
                                    .register_offset,
                                    .register_overflow,
                                    .indirect,
                                    .lea_direct,
                                    .lea_got,
                                    .lea_tlv,
                                    .lea_frame,
                                    .lea_symbol,
                                    .elementwise_regs_then_frame,
                                    .reserved_frame,
                                    .air_ref,
                                    => unreachable,
                                    .register_pair, .load_frame => null,
                                    .memory, .load_symbol, .load_got, .load_direct, .load_tlv => dst: {
                                        switch (resolved_dst_mcv) {
                                            .memory => |addr| if (math.cast(
                                                i32,
                                                @as(i64, @bitCast(addr)),
                                            ) != null and math.cast(
                                                i32,
                                                @as(i64, @bitCast(addr)) + abi_size - 8,
                                            ) != null) break :dst null,
                                            .load_symbol, .load_got, .load_direct, .load_tlv => {},
                                            else => unreachable,
                                        }

                                        const dst_addr_reg = (try self.register_manager.allocReg(
                                            null,
                                            abi.RegisterClass.gp,
                                        )).to64();
                                        const dst_addr_lock =
                                            self.register_manager.lockRegAssumeUnused(dst_addr_reg);
                                        errdefer self.register_manager.unlockReg(dst_addr_lock);

                                        try self.genSetReg(
                                            dst_addr_reg,
                                            Type.usize,
                                            resolved_dst_mcv.address(),
                                            .{},
                                        );
                                        break :dst .{
                                            .addr_reg = dst_addr_reg,
                                            .addr_lock = dst_addr_lock,
                                        };
                                    },
                                };
                                defer if (dst_info) |info|
                                    self.register_manager.unlockReg(info.addr_lock);

                                const resolved_src_mcv = switch (src_mcv) {
                                    else => src_mcv,
                                    .air_ref => |src_ref| try self.resolveInst(src_ref),
                                };
                                const src_info: OpInfo = switch (resolved_src_mcv) {
                                    .none,
                                    .unreach,
                                    .dead,
                                    .undef,
                                    .immediate,
                                    .eflags,
                                    .register,
                                    .register_offset,
                                    .register_overflow,
                                    .indirect,
                                    .lea_symbol,
                                    .lea_direct,
                                    .lea_got,
                                    .lea_tlv,
                                    .lea_frame,
                                    .elementwise_regs_then_frame,
                                    .reserved_frame,
                                    .air_ref,
                                    => unreachable,
                                    .register_pair, .load_frame => null,
                                    .memory, .load_symbol, .load_got, .load_direct, .load_tlv => src: {
                                        switch (resolved_src_mcv) {
                                            .memory => |addr| if (math.cast(
                                                i32,
                                                @as(i64, @bitCast(addr)),
                                            ) != null and math.cast(
                                                i32,
                                                @as(i64, @bitCast(addr)) + abi_size - 8,
                                            ) != null) break :src null,
                                            .load_symbol, .load_got, .load_direct, .load_tlv => {},
                                            else => unreachable,
                                        }

                                        const src_addr_reg = (try self.register_manager.allocReg(
                                            null,
                                            abi.RegisterClass.gp,
                                        )).to64();
                                        const src_addr_lock =
                                            self.register_manager.lockRegAssumeUnused(src_addr_reg);
                                        errdefer self.register_manager.unlockReg(src_addr_lock);

                                        try self.genSetReg(
                                            src_addr_reg,
                                            Type.usize,
                                            resolved_src_mcv.address(),
                                            .{},
                                        );
                                        break :src .{
                                            .addr_reg = src_addr_reg,
                                            .addr_lock = src_addr_lock,
                                        };
                                    },
                                };
                                defer if (src_info) |info|
                                    self.register_manager.unlockReg(info.addr_lock);

                                const regs = try self.register_manager.allocRegs(
                                    2,
                                    .{null} ** 2,
                                    abi.RegisterClass.gp,
                                );
                                const acc_reg = regs[0].to64();
                                const locks = self.register_manager.lockRegsAssumeUnused(2, regs);
                                defer for (locks) |lock| self.register_manager.unlockReg(lock);

                                const limbs_len = math.divCeil(u16, abi_size, 8) catch unreachable;
                                var limb_i: u16 = 0;
                                while (limb_i < limbs_len) : (limb_i += 1) {
                                    const off = limb_i * 8;
                                    const tmp_reg = regs[@min(limb_i, 1)].to64();

                                    try self.genSetReg(tmp_reg, Type.usize, if (dst_info) |info| .{
                                        .indirect = .{ .reg = info.addr_reg, .off = off },
                                    } else switch (resolved_dst_mcv) {
                                        .register_pair => |dst_regs| .{ .register = dst_regs[limb_i] },
                                        .memory => |dst_addr| .{
                                            .memory = @bitCast(@as(i64, @bitCast(dst_addr)) + off),
                                        },
                                        .indirect => |reg_off| .{ .indirect = .{
                                            .reg = reg_off.reg,
                                            .off = reg_off.off + off,
                                        } },
                                        .load_frame => |frame_addr| .{ .load_frame = .{
                                            .index = frame_addr.index,
                                            .off = frame_addr.off + off,
                                        } },
                                        else => unreachable,
                                    }, .{});

                                    try self.genBinOpMir(
                                        .{ ._, .xor },
                                        Type.usize,
                                        .{ .register = tmp_reg },
                                        if (src_info) |info| .{
                                            .indirect = .{ .reg = info.addr_reg, .off = off },
                                        } else switch (resolved_src_mcv) {
                                            .register_pair => |src_regs| .{
                                                .register = src_regs[limb_i],
                                            },
                                            .memory => |src_addr| .{
                                                .memory = @bitCast(@as(i64, @bitCast(src_addr)) + off),
                                            },
                                            .indirect => |reg_off| .{ .indirect = .{
                                                .reg = reg_off.reg,
                                                .off = reg_off.off + off,
                                            } },
                                            .load_frame => |frame_addr| .{ .load_frame = .{
                                                .index = frame_addr.index,
                                                .off = frame_addr.off + off,
                                            } },
                                            else => unreachable,
                                        },
                                    );

                                    if (limb_i > 0)
                                        try self.asmRegisterRegister(.{ ._, .@"or" }, acc_reg, tmp_reg);
                                }
                                assert(limbs_len >= 2); // use flags from or
                                break :result_op flipped_op;
                            },
                        };
                        try self.genBinOpMir(.{ ._, .cmp }, ty, dst_mcv, src_mcv);
                        break :result_op flipped_op;
                    },
                );
            },
            .float => {
                const flipped = switch (op) {
                    .lt, .lte => true,
                    .eq, .gte, .gt, .neq => false,
                };

                const dst_mcv = if (flipped) rhs_mcv else lhs_mcv;
                const dst_reg = if (dst_mcv.isRegister())
                    dst_mcv.getReg().?
                else
                    try self.copyToTmpRegister(ty, dst_mcv);
                const dst_lock = self.register_manager.lockReg(dst_reg);
                defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);
                const src_mcv = if (flipped) lhs_mcv else rhs_mcv;

                switch (ty.floatBits(self.target.*)) {
                    16 => {
                        assert(self.hasFeature(.f16c));
                        const tmp1_reg =
                            (try self.register_manager.allocReg(null, abi.RegisterClass.sse)).to128();
                        const tmp1_mcv = MCValue{ .register = tmp1_reg };
                        const tmp1_lock = self.register_manager.lockRegAssumeUnused(tmp1_reg);
                        defer self.register_manager.unlockReg(tmp1_lock);

                        const tmp2_reg =
                            (try self.register_manager.allocReg(null, abi.RegisterClass.sse)).to128();
                        const tmp2_mcv = MCValue{ .register = tmp2_reg };
                        const tmp2_lock = self.register_manager.lockRegAssumeUnused(tmp2_reg);
                        defer self.register_manager.unlockReg(tmp2_lock);

                        if (src_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                            .{ .vp_w, .insr },
                            tmp1_reg,
                            dst_reg.to128(),
                            try src_mcv.mem(self, .word),
                            Immediate.u(1),
                        ) else try self.asmRegisterRegisterRegister(
                            .{ .vp_, .unpcklwd },
                            tmp1_reg,
                            dst_reg.to128(),
                            (if (src_mcv.isRegister())
                                src_mcv.getReg().?
                            else
                                try self.copyToTmpRegister(ty, src_mcv)).to128(),
                        );
                        try self.asmRegisterRegister(.{ .v_ps, .cvtph2 }, tmp1_reg, tmp1_reg);
                        try self.asmRegisterRegister(.{ .v_, .movshdup }, tmp2_reg, tmp1_reg);
                        try self.genBinOpMir(.{ ._ss, .ucomi }, ty, tmp1_mcv, tmp2_mcv);
                    },
                    32 => try self.genBinOpMir(
                        .{ ._ss, .ucomi },
                        ty,
                        .{ .register = dst_reg },
                        src_mcv,
                    ),
                    64 => try self.genBinOpMir(
                        .{ ._sd, .ucomi },
                        ty,
                        .{ .register = dst_reg },
                        src_mcv,
                    ),
                    else => unreachable,
                }

                break :result switch (if (flipped) op.reverse() else op) {
                    .lt, .lte => unreachable, // required to have been canonicalized to gt(e)
                    .gt => .a,
                    .gte => .ae,
                    .eq => .z_and_np,
                    .neq => .nz_or_p,
                };
            },
        }
    };

    if (null_compare) |reloc| self.performReloc(reloc);
    self.eflags_inst = inst;
    return self.finishAir(inst, .{ .eflags = result }, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airCmpVector(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.VectorCmp, ty_pl.payload).data;
    const dst_mcv = try self.genBinOp(
        inst,
        Air.Inst.Tag.fromCmpOp(extra.compareOperator(), false),
        extra.lhs,
        extra.rhs,
    );
    return self.finishAir(inst, dst_mcv, .{ extra.lhs, extra.rhs, .none });
}

fn airCmpLtErrorsLen(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const addr_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
    defer self.register_manager.unlockReg(addr_lock);
    const anyerror_lazy_sym: link.File.LazySymbol = .{ .kind = .const_data, .ty = .anyerror_type };
    try self.genLazySymbolRef(.lea, addr_reg, anyerror_lazy_sym);

    try self.spillEflagsIfOccupied();

    const op_ty = self.typeOf(un_op);
    const op_abi_size: u32 = @intCast(op_ty.abiSize(zcu));
    const op_mcv = try self.resolveInst(un_op);
    const dst_reg = switch (op_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(op_ty, op_mcv),
    };
    try self.asmRegisterMemory(
        .{ ._, .cmp },
        registerAlias(dst_reg, op_abi_size),
        .{
            .base = .{ .reg = addr_reg },
            .mod = .{ .rm = .{ .size = Memory.Size.fromSize(op_abi_size) } },
        },
    );

    self.eflags_inst = inst;
    return self.finishAir(inst, .{ .eflags = .b }, .{ un_op, .none, .none });
}

fn airTry(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
    const operand_ty = self.typeOf(pl_op.operand);
    const result = try self.genTry(inst, pl_op.operand, body, operand_ty, false);
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airTryPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
    const operand_ty = self.typeOf(extra.data.ptr);
    const result = try self.genTry(inst, extra.data.ptr, body, operand_ty, true);
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn genTry(
    self: *Self,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    body: []const Air.Inst.Index,
    operand_ty: Type,
    operand_is_ptr: bool,
) !MCValue {
    const liveness_cond_br = self.liveness.getCondBr(inst);

    const operand_mcv = try self.resolveInst(operand);
    const is_err_mcv = if (operand_is_ptr)
        try self.isErrPtr(null, operand_ty, operand_mcv)
    else
        try self.isErr(null, operand_ty, operand_mcv);

    const reloc = try self.genCondBrMir(Type.anyerror, is_err_mcv);

    if (self.liveness.operandDies(inst, 0)) {
        if (operand.toIndex()) |operand_inst| try self.processDeath(operand_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();

    for (liveness_cond_br.else_deaths) |death| try self.processDeath(death);
    try self.genBody(body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    self.performReloc(reloc);

    for (liveness_cond_br.then_deaths) |death| try self.processDeath(death);

    const result = if (self.liveness.isUnused(inst))
        .unreach
    else if (operand_is_ptr)
        try self.genUnwrapErrUnionPayloadPtrMir(inst, operand_ty, operand_mcv)
    else
        try self.genUnwrapErrUnionPayloadMir(inst, operand_ty, operand_mcv);
    return result;
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_dbg_line_line_column,
        .data = .{ .line_column = .{
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        } },
    });
    self.finishAirBookkeeping();
}

fn airDbgInlineBlock(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
    const old_inline_func = self.inline_func;
    defer self.inline_func = old_inline_func;
    self.inline_func = extra.data.func;
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_dbg_enter_inline_func,
        .data = .{ .func = extra.data.func },
    });
    try self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_dbg_leave_inline_func,
        .data = .{ .func = old_inline_func },
    });
}

fn airDbgVar(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    try self.genLocalDebugInfo(inst, try self.resolveInst(pl_op.operand));
    return self.finishAir(inst, .unreach, .{ pl_op.operand, .none, .none });
}

fn genCondBrMir(self: *Self, ty: Type, mcv: MCValue) !Mir.Inst.Index {
    const pt = self.pt;
    const abi_size = ty.abiSize(pt.zcu);
    switch (mcv) {
        .eflags => |cc| {
            // Here we map the opposites since the jump is to the false branch.
            return self.asmJccReloc(cc.negate(), undefined);
        },
        .register => |reg| {
            try self.spillEflagsIfOccupied();
            try self.asmRegisterImmediate(.{ ._, .@"test" }, reg.to8(), Immediate.u(1));
            return self.asmJccReloc(.z, undefined);
        },
        .immediate,
        .load_frame,
        => {
            try self.spillEflagsIfOccupied();
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genCondBrMir(ty, .{ .register = reg });
            }
            return self.fail("TODO implement condbr when condition is {} with abi larger than 8 bytes", .{mcv});
        },
        else => return self.fail("TODO implement condbr when condition is {s}", .{@tagName(mcv)}),
    }
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const cond = try self.resolveInst(pl_op.operand);
    const cond_ty = self.typeOf(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index =
        @ptrCast(self.air.extra[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index =
        @ptrCast(self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_cond_br = self.liveness.getCondBr(inst);

    // If the condition dies here in this condbr instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (pl_op.operand.toIndex()) |op_inst| try self.processDeath(op_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();
    const reloc = try self.genCondBrMir(cond_ty, cond);

    for (liveness_cond_br.then_deaths) |death| try self.processDeath(death);
    try self.genBody(then_body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    self.performReloc(reloc);

    for (liveness_cond_br.else_deaths) |death| try self.processDeath(death);
    try self.genBody(else_body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    // We already took care of pl_op.operand earlier, so there's nothing left to do.
    self.finishAirBookkeeping();
}

fn isNull(self: *Self, inst: Air.Inst.Index, opt_ty: Type, opt_mcv: MCValue) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    switch (opt_mcv) {
        .register_overflow => |ro| return .{ .eflags = ro.eflags.negate() },
        else => {},
    }

    try self.spillEflagsIfOccupied();

    const pl_ty = opt_ty.optionalChild(zcu);

    const some_info: struct { off: i32, ty: Type } = if (opt_ty.optionalReprIsPayload(zcu))
        .{ .off = 0, .ty = if (pl_ty.isSlice(zcu)) pl_ty.slicePtrFieldType(zcu) else pl_ty }
    else
        .{ .off = @intCast(pl_ty.abiSize(zcu)), .ty = Type.bool };

    self.eflags_inst = inst;
    switch (opt_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .eflags,
        .register_pair,
        .register_offset,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_symbol,
        .elementwise_regs_then_frame,
        .reserved_frame,
        .air_ref,
        => unreachable,

        .lea_frame => {
            self.eflags_inst = null;
            return .{ .immediate = @intFromBool(false) };
        },

        .register => |opt_reg| {
            if (some_info.off == 0) {
                const some_abi_size: u32 = @intCast(some_info.ty.abiSize(zcu));
                const alias_reg = registerAlias(opt_reg, some_abi_size);
                assert(some_abi_size * 8 == alias_reg.bitSize());
                try self.asmRegisterRegister(.{ ._, .@"test" }, alias_reg, alias_reg);
                return .{ .eflags = .z };
            }
            assert(some_info.ty.ip_index == .bool_type);
            const opt_abi_size: u32 = @intCast(opt_ty.abiSize(zcu));
            try self.asmRegisterImmediate(
                .{ ._, .bt },
                registerAlias(opt_reg, opt_abi_size),
                Immediate.u(@as(u6, @intCast(some_info.off * 8))),
            );
            return .{ .eflags = .nc };
        },

        .memory,
        .load_symbol,
        .load_got,
        .load_direct,
        .load_tlv,
        => {
            const addr_reg = (try self.register_manager.allocReg(null, abi.RegisterClass.gp)).to64();
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            try self.genSetReg(addr_reg, Type.usize, opt_mcv.address(), .{});
            const some_abi_size: u32 = @intCast(some_info.ty.abiSize(zcu));
            try self.asmMemoryImmediate(
                .{ ._, .cmp },
                .{
                    .base = .{ .reg = addr_reg },
                    .mod = .{ .rm = .{
                        .size = Memory.Size.fromSize(some_abi_size),
                        .disp = some_info.off,
                    } },
                },
                Immediate.u(0),
            );
            return .{ .eflags = .e };
        },

        .indirect, .load_frame => {
            const some_abi_size: u32 = @intCast(some_info.ty.abiSize(zcu));
            try self.asmMemoryImmediate(
                .{ ._, .cmp },
                switch (opt_mcv) {
                    .indirect => |reg_off| .{
                        .base = .{ .reg = reg_off.reg },
                        .mod = .{ .rm = .{
                            .size = Memory.Size.fromSize(some_abi_size),
                            .disp = reg_off.off + some_info.off,
                        } },
                    },
                    .load_frame => |frame_addr| .{
                        .base = .{ .frame = frame_addr.index },
                        .mod = .{ .rm = .{
                            .size = Memory.Size.fromSize(some_abi_size),
                            .disp = frame_addr.off + some_info.off,
                        } },
                    },
                    else => unreachable,
                },
                Immediate.u(0),
            );
            return .{ .eflags = .e };
        },
    }
}

fn isNullPtr(self: *Self, inst: Air.Inst.Index, ptr_ty: Type, ptr_mcv: MCValue) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const opt_ty = ptr_ty.childType(zcu);
    const pl_ty = opt_ty.optionalChild(zcu);

    try self.spillEflagsIfOccupied();

    const some_info: struct { off: i32, ty: Type } = if (opt_ty.optionalReprIsPayload(zcu))
        .{ .off = 0, .ty = if (pl_ty.isSlice(zcu)) pl_ty.slicePtrFieldType(zcu) else pl_ty }
    else
        .{ .off = @intCast(pl_ty.abiSize(zcu)), .ty = Type.bool };

    const ptr_reg = switch (ptr_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ptr_ty, ptr_mcv),
    };
    const ptr_lock = self.register_manager.lockReg(ptr_reg);
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const some_abi_size: u32 = @intCast(some_info.ty.abiSize(zcu));
    try self.asmMemoryImmediate(
        .{ ._, .cmp },
        .{
            .base = .{ .reg = ptr_reg },
            .mod = .{ .rm = .{
                .size = Memory.Size.fromSize(some_abi_size),
                .disp = some_info.off,
            } },
        },
        Immediate.u(0),
    );

    self.eflags_inst = inst;
    return .{ .eflags = .e };
}

fn isErr(self: *Self, maybe_inst: ?Air.Inst.Index, eu_ty: Type, eu_mcv: MCValue) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const err_ty = eu_ty.errorUnionSet(zcu);
    if (err_ty.errorSetIsEmpty(zcu)) return MCValue{ .immediate = 0 }; // always false

    try self.spillEflagsIfOccupied();

    const err_off: u31 = @intCast(errUnionErrorOffset(eu_ty.errorUnionPayload(zcu), zcu));
    switch (eu_mcv) {
        .register => |reg| {
            const eu_lock = self.register_manager.lockReg(reg);
            defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

            const tmp_reg = try self.copyToTmpRegister(eu_ty, eu_mcv);
            if (err_off > 0) {
                try self.genShiftBinOpMir(
                    .{ ._r, .sh },
                    eu_ty,
                    .{ .register = tmp_reg },
                    Type.u8,
                    .{ .immediate = @as(u6, @intCast(err_off * 8)) },
                );
            } else {
                try self.truncateRegister(Type.anyerror, tmp_reg);
            }
            try self.genBinOpMir(
                .{ ._, .cmp },
                Type.anyerror,
                .{ .register = tmp_reg },
                .{ .immediate = 0 },
            );
        },
        .load_frame => |frame_addr| try self.genBinOpMir(
            .{ ._, .cmp },
            Type.anyerror,
            .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + err_off,
            } },
            .{ .immediate = 0 },
        ),
        else => return self.fail("TODO implement isErr for {}", .{eu_mcv}),
    }

    if (maybe_inst) |inst| self.eflags_inst = inst;
    return MCValue{ .eflags = .a };
}

fn isErrPtr(self: *Self, maybe_inst: ?Air.Inst.Index, ptr_ty: Type, ptr_mcv: MCValue) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const eu_ty = ptr_ty.childType(zcu);
    const err_ty = eu_ty.errorUnionSet(zcu);
    if (err_ty.errorSetIsEmpty(zcu)) return MCValue{ .immediate = 0 }; // always false

    try self.spillEflagsIfOccupied();

    const ptr_reg = switch (ptr_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ptr_ty, ptr_mcv),
    };
    const ptr_lock = self.register_manager.lockReg(ptr_reg);
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const err_off: u31 = @intCast(errUnionErrorOffset(eu_ty.errorUnionPayload(zcu), zcu));
    try self.asmMemoryImmediate(
        .{ ._, .cmp },
        .{
            .base = .{ .reg = ptr_reg },
            .mod = .{ .rm = .{
                .size = self.memSize(Type.anyerror),
                .disp = err_off,
            } },
        },
        Immediate.u(0),
    );

    if (maybe_inst) |inst| self.eflags_inst = inst;
    return MCValue{ .eflags = .a };
}

fn isNonErr(self: *Self, inst: Air.Inst.Index, eu_ty: Type, eu_mcv: MCValue) !MCValue {
    const is_err_res = try self.isErr(inst, eu_ty, eu_mcv);
    switch (is_err_res) {
        .eflags => |cc| {
            assert(cc == .a);
            return MCValue{ .eflags = cc.negate() };
        },
        .immediate => |imm| {
            assert(imm == 0);
            return MCValue{ .immediate = @intFromBool(imm == 0) };
        },
        else => unreachable,
    }
}

fn isNonErrPtr(self: *Self, inst: Air.Inst.Index, ptr_ty: Type, ptr_mcv: MCValue) !MCValue {
    const is_err_res = try self.isErrPtr(inst, ptr_ty, ptr_mcv);
    switch (is_err_res) {
        .eflags => |cc| {
            assert(cc == .a);
            return MCValue{ .eflags = cc.negate() };
        },
        .immediate => |imm| {
            assert(imm == 0);
            return MCValue{ .immediate = @intFromBool(imm == 0) };
        },
        else => unreachable,
    }
}

fn airIsNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result = try self.isNull(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result = try self.isNullPtr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result: MCValue = switch (try self.isNull(inst, ty, operand)) {
        .immediate => |imm| .{ .immediate = @intFromBool(imm == 0) },
        .eflags => |cc| .{ .eflags = cc.negate() },
        else => unreachable,
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result = switch (try self.isNullPtr(inst, ty, operand)) {
        .eflags => |cc| .{ .eflags = cc.negate() },
        else => unreachable,
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result = try self.isErr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result = try self.isErrPtr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result = try self.isNonErr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.typeOf(un_op);
    const result = try self.isNonErrPtr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[loop.end..][0..loop.data.body_len]);

    self.scope_generation += 1;
    const state = try self.saveState();

    try self.loops.putNoClobber(self.gpa, inst, .{
        .state = state,
        .jmp_target = @intCast(self.mir_instructions.len),
    });
    defer assert(self.loops.remove(inst));

    try self.genBody(body);
    self.finishAirBookkeeping();
}

fn airBlock(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    try self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
}

fn lowerBlock(self: *Self, inst: Air.Inst.Index, body: []const Air.Inst.Index) !void {
    // A block is a setup to be able to jump to the end.
    const inst_tracking_i = self.inst_tracking.count();
    self.inst_tracking.putAssumeCapacityNoClobber(inst, InstTracking.init(.unreach));

    self.scope_generation += 1;
    try self.blocks.putNoClobber(self.gpa, inst, .{ .state = self.initRetroactiveState() });
    const liveness = self.liveness.getBlock(inst);

    // TODO emit debug info lexical block
    try self.genBody(body);

    var block_data = self.blocks.fetchRemove(inst).?;
    defer block_data.value.deinit(self.gpa);
    if (block_data.value.relocs.items.len > 0) {
        try self.restoreState(block_data.value.state, liveness.deaths, .{
            .emit_instructions = false,
            .update_tracking = true,
            .resurrect = true,
            .close_scope = true,
        });
        for (block_data.value.relocs.items) |reloc| self.performReloc(reloc);
    }

    if (std.debug.runtime_safety) assert(self.inst_tracking.getIndex(inst).? == inst_tracking_i);
    const tracking = &self.inst_tracking.values()[inst_tracking_i];
    if (self.liveness.isUnused(inst)) try tracking.die(self, inst);
    self.getValueIfFree(tracking.short, inst);
    self.finishAirBookkeeping();
}

fn lowerSwitchBr(self: *Self, inst: Air.Inst.Index, switch_br: Air.UnwrappedSwitch, condition: MCValue) !void {
    const zcu = self.pt.zcu;
    const condition_ty = self.typeOf(switch_br.operand);
    const liveness = try self.liveness.getSwitchBr(self.gpa, inst, switch_br.cases_len + 1);
    defer self.gpa.free(liveness.deaths);

    const signedness = switch (condition_ty.zigTypeTag(zcu)) {
        .bool, .pointer => .unsigned,
        .int, .@"enum", .error_set => condition_ty.intInfo(zcu).signedness,
        else => unreachable,
    };

    self.scope_generation += 1;
    const state = try self.saveState();

    var it = switch_br.iterateCases();
    while (it.next()) |case| {
        var relocs = try self.gpa.alloc(Mir.Inst.Index, case.items.len + case.ranges.len);
        defer self.gpa.free(relocs);

        try self.spillEflagsIfOccupied();
        for (case.items, relocs[0..case.items.len]) |item, *reloc| {
            const item_mcv = try self.resolveInst(item);
            const cc: Condition = switch (condition) {
                .eflags => |cc| switch (item_mcv.immediate) {
                    0 => cc.negate(),
                    1 => cc,
                    else => unreachable,
                },
                else => cc: {
                    try self.genBinOpMir(.{ ._, .cmp }, condition_ty, condition, item_mcv);
                    break :cc .e;
                },
            };
            reloc.* = try self.asmJccReloc(cc, undefined);
        }

        for (case.ranges, relocs[case.items.len..]) |range, *reloc| {
            const min_mcv = try self.resolveInst(range[0]);
            const max_mcv = try self.resolveInst(range[1]);
            // `null` means always false.
            const lt_min: ?Condition = switch (condition) {
                .eflags => |cc| switch (min_mcv.immediate) {
                    0 => null, // condition never <0
                    1 => cc.negate(),
                    else => unreachable,
                },
                else => cc: {
                    try self.genBinOpMir(.{ ._, .cmp }, condition_ty, condition, min_mcv);
                    break :cc switch (signedness) {
                        .unsigned => .b,
                        .signed => .l,
                    };
                },
            };
            const lt_min_reloc = if (lt_min) |cc| r: {
                break :r try self.asmJccReloc(cc, undefined);
            } else null;
            // `null` means always true.
            const lte_max: ?Condition = switch (condition) {
                .eflags => |cc| switch (max_mcv.immediate) {
                    0 => cc.negate(),
                    1 => null, // condition always >=1
                    else => unreachable,
                },
                else => cc: {
                    try self.genBinOpMir(.{ ._, .cmp }, condition_ty, condition, max_mcv);
                    break :cc switch (signedness) {
                        .unsigned => .be,
                        .signed => .le,
                    };
                },
            };
            // "Success" case is in `reloc`....
            if (lte_max) |cc| {
                reloc.* = try self.asmJccReloc(cc, undefined);
            } else {
                reloc.* = try self.asmJmpReloc(undefined);
            }
            // ...and "fail" case falls through to next checks.
            if (lt_min_reloc) |r| self.performReloc(r);
        }

        // The jump to skip this case if the conditions all failed.
        const skip_case_reloc = try self.asmJmpReloc(undefined);

        for (liveness.deaths[case.idx]) |operand| try self.processDeath(operand);

        // Relocate all success cases to the body we're about to generate.
        for (relocs) |reloc| self.performReloc(reloc);
        try self.genBody(case.body);
        try self.restoreState(state, &.{}, .{
            .emit_instructions = false,
            .update_tracking = true,
            .resurrect = true,
            .close_scope = true,
        });

        // Relocate the "skip" branch to fall through to the next case.
        self.performReloc(skip_case_reloc);
    }

    if (switch_br.else_body_len > 0) {
        const else_body = it.elseBody();

        const else_deaths = liveness.deaths.len - 1;
        for (liveness.deaths[else_deaths]) |operand| try self.processDeath(operand);

        try self.genBody(else_body);
        try self.restoreState(state, &.{}, .{
            .emit_instructions = false,
            .update_tracking = true,
            .resurrect = true,
            .close_scope = true,
        });
    }
}

fn airSwitchBr(self: *Self, inst: Air.Inst.Index) !void {
    const switch_br = self.air.unwrapSwitch(inst);
    const condition = try self.resolveInst(switch_br.operand);

    // If the condition dies here in this switch instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (switch_br.operand.toIndex()) |op_inst| try self.processDeath(op_inst);
    }

    try self.lowerSwitchBr(inst, switch_br, condition);

    // We already took care of pl_op.operand earlier, so there's nothing left to do
    self.finishAirBookkeeping();
}

fn airLoopSwitchBr(self: *Self, inst: Air.Inst.Index) !void {
    const switch_br = self.air.unwrapSwitch(inst);
    const condition = try self.resolveInst(switch_br.operand);

    const mat_cond = if (condition.isModifiable() and
        self.reuseOperand(inst, switch_br.operand, 0, condition))
        condition
    else mat_cond: {
        const mat_cond = try self.allocRegOrMem(inst, true);
        try self.genCopy(self.typeOf(switch_br.operand), mat_cond, condition, .{});
        break :mat_cond mat_cond;
    };
    self.inst_tracking.putAssumeCapacityNoClobber(inst, InstTracking.init(mat_cond));

    // If the condition dies here in this switch instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (switch_br.operand.toIndex()) |op_inst| try self.processDeath(op_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();

    try self.loops.putNoClobber(self.gpa, inst, .{
        .state = state,
        .jmp_target = @intCast(self.mir_instructions.len),
    });
    defer assert(self.loops.remove(inst));

    // Stop tracking block result without forgetting tracking info
    try self.freeValue(mat_cond);

    try self.lowerSwitchBr(inst, switch_br, mat_cond);

    try self.processDeath(inst);
    self.finishAirBookkeeping();
}

fn airSwitchDispatch(self: *Self, inst: Air.Inst.Index) !void {
    const br = self.air.instructions.items(.data)[@intFromEnum(inst)].br;

    const block_ty = self.typeOfIndex(br.block_inst);
    const block_tracking = self.inst_tracking.getPtr(br.block_inst).?;
    const loop_data = self.loops.getPtr(br.block_inst).?;
    done: {
        try self.getValue(block_tracking.short, null);
        const src_mcv = try self.resolveInst(br.operand);

        if (self.reuseOperandAdvanced(inst, br.operand, 0, src_mcv, br.block_inst)) {
            try self.getValue(block_tracking.short, br.block_inst);
            // .long = .none to avoid merging operand and block result stack frames.
            const current_tracking: InstTracking = .{ .long = .none, .short = src_mcv };
            try current_tracking.materializeUnsafe(self, br.block_inst, block_tracking.*);
            for (current_tracking.getRegs()) |src_reg| self.register_manager.freeReg(src_reg);
            break :done;
        }

        try self.getValue(block_tracking.short, br.block_inst);
        const dst_mcv = block_tracking.short;
        try self.genCopy(block_ty, dst_mcv, try self.resolveInst(br.operand), .{});
        break :done;
    }

    // Process operand death so that it is properly accounted for in the State below.
    if (self.liveness.operandDies(inst, 0)) {
        if (br.operand.toIndex()) |op_inst| try self.processDeath(op_inst);
    }

    try self.restoreState(loop_data.state, &.{}, .{
        .emit_instructions = true,
        .update_tracking = false,
        .resurrect = false,
        .close_scope = false,
    });

    // Emit a jump with a relocation. It will be patched up after the block ends.
    // Leave the jump offset undefined
    _ = try self.asmJmpReloc(loop_data.jmp_target);

    // Stop tracking block result without forgetting tracking info
    try self.freeValue(block_tracking.short);

    self.finishAirBookkeeping();
}

fn performReloc(self: *Self, reloc: Mir.Inst.Index) void {
    const next_inst: u32 = @intCast(self.mir_instructions.len);
    switch (self.mir_instructions.items(.tag)[reloc]) {
        .j, .jmp => {},
        .pseudo => switch (self.mir_instructions.items(.ops)[reloc]) {
            .pseudo_j_z_and_np_inst, .pseudo_j_nz_or_p_inst => {},
            else => unreachable,
        },
        else => unreachable,
    }
    self.mir_instructions.items(.data)[reloc].inst.inst = next_inst;
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.pt.zcu;
    const br = self.air.instructions.items(.data)[@intFromEnum(inst)].br;

    const block_ty = self.typeOfIndex(br.block_inst);
    const block_unused =
        !block_ty.hasRuntimeBitsIgnoreComptime(zcu) or self.liveness.isUnused(br.block_inst);
    const block_tracking = self.inst_tracking.getPtr(br.block_inst).?;
    const block_data = self.blocks.getPtr(br.block_inst).?;
    const first_br = block_data.relocs.items.len == 0;
    const block_result = result: {
        if (block_unused) break :result .none;

        if (!first_br) try self.getValue(block_tracking.short, null);
        const src_mcv = try self.resolveInst(br.operand);

        if (self.reuseOperandAdvanced(inst, br.operand, 0, src_mcv, br.block_inst)) {
            if (first_br) break :result src_mcv;

            try self.getValue(block_tracking.short, br.block_inst);
            // .long = .none to avoid merging operand and block result stack frames.
            const current_tracking: InstTracking = .{ .long = .none, .short = src_mcv };
            try current_tracking.materializeUnsafe(self, br.block_inst, block_tracking.*);
            for (current_tracking.getRegs()) |src_reg| self.register_manager.freeReg(src_reg);
            break :result block_tracking.short;
        }

        const dst_mcv = if (first_br) try self.allocRegOrMem(br.block_inst, true) else dst: {
            try self.getValue(block_tracking.short, br.block_inst);
            break :dst block_tracking.short;
        };
        try self.genCopy(block_ty, dst_mcv, try self.resolveInst(br.operand), .{});
        break :result dst_mcv;
    };

    // Process operand death so that it is properly accounted for in the State below.
    if (self.liveness.operandDies(inst, 0)) {
        if (br.operand.toIndex()) |op_inst| try self.processDeath(op_inst);
    }

    if (first_br) {
        block_tracking.* = InstTracking.init(block_result);
        try self.saveRetroactiveState(&block_data.state);
    } else try self.restoreState(block_data.state, &.{}, .{
        .emit_instructions = true,
        .update_tracking = false,
        .resurrect = false,
        .close_scope = false,
    });

    // Emit a jump with a relocation. It will be patched up after the block ends.
    // Leave the jump offset undefined
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try block_data.relocs.append(self.gpa, jmp_reloc);

    // Stop tracking block result without forgetting tracking info
    try self.freeValue(block_tracking.short);

    self.finishAirBookkeeping();
}

fn airRepeat(self: *Self, inst: Air.Inst.Index) !void {
    const loop_inst = self.air.instructions.items(.data)[@intFromEnum(inst)].repeat.loop_inst;
    const repeat_info = self.loops.get(loop_inst).?;
    try self.restoreState(repeat_info.state, &.{}, .{
        .emit_instructions = true,
        .update_tracking = false,
        .resurrect = false,
        .close_scope = true,
    });
    _ = try self.asmJmpReloc(repeat_info.jmp_target);
    self.finishAirBookkeeping();
}

fn airAsm(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Asm, ty_pl.payload);
    const clobbers_len: u31 = @truncate(extra.data.flags);
    var extra_i: usize = extra.end;
    const outputs: []const Air.Inst.Ref =
        @ptrCast(self.air.extra[extra_i..][0..extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.inputs_len]);
    extra_i += inputs.len;

    var result: MCValue = .none;
    var args = std.ArrayList(MCValue).init(self.gpa);
    try args.ensureTotalCapacity(outputs.len + inputs.len);
    defer {
        for (args.items) |arg| if (arg.getReg()) |reg| self.register_manager.unlockReg(.{
            .tracked_index = RegisterManager.indexOfRegIntoTracked(reg) orelse continue,
        });
        args.deinit();
    }
    var arg_map = std.StringHashMap(u8).init(self.gpa);
    try arg_map.ensureTotalCapacity(@intCast(outputs.len + inputs.len));
    defer arg_map.deinit();

    var outputs_extra_i = extra_i;
    for (outputs) |output| {
        const extra_bytes = mem.sliceAsBytes(self.air.extra[extra_i..]);
        const constraint = mem.sliceTo(mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
        const name = mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
        // This equation accounts for the fact that even if we have exactly 4 bytes
        // for the string, we still use the next u32 for the null terminator.
        extra_i += (constraint.len + name.len + (2 + 3)) / 4;

        const maybe_inst = switch (output) {
            .none => inst,
            else => null,
        };
        const ty = switch (output) {
            .none => self.typeOfIndex(inst),
            else => self.typeOf(output).childType(zcu),
        };
        const is_read = switch (constraint[0]) {
            '=' => false,
            '+' => read: {
                if (output == .none) return self.fail(
                    "read-write constraint unsupported for asm result: '{s}'",
                    .{constraint},
                );
                break :read true;
            },
            else => return self.fail("invalid constraint: '{s}'", .{constraint}),
        };
        const is_early_clobber = constraint[1] == '&';
        const rest = constraint[@as(usize, 1) + @intFromBool(is_early_clobber) ..];
        const arg_mcv: MCValue = arg_mcv: {
            const arg_maybe_reg: ?Register = if (mem.eql(u8, rest, "r") or
                mem.eql(u8, rest, "f") or mem.eql(u8, rest, "x"))
                registerAlias(
                    self.register_manager.tryAllocReg(maybe_inst, switch (rest[0]) {
                        'r' => abi.RegisterClass.gp,
                        'f' => abi.RegisterClass.x87,
                        'x' => abi.RegisterClass.sse,
                        else => unreachable,
                    }) orelse return self.fail("ran out of registers lowering inline asm", .{}),
                    @intCast(ty.abiSize(zcu)),
                )
            else if (mem.eql(u8, rest, "m"))
                if (output != .none) null else return self.fail(
                    "memory constraint unsupported for asm result: '{s}'",
                    .{constraint},
                )
            else if (mem.eql(u8, rest, "g") or
                mem.eql(u8, rest, "rm") or mem.eql(u8, rest, "mr") or
                mem.eql(u8, rest, "r,m") or mem.eql(u8, rest, "m,r"))
                self.register_manager.tryAllocReg(maybe_inst, abi.RegisterClass.gp) orelse
                    if (output != .none)
                    null
                else
                    return self.fail("ran out of registers lowering inline asm", .{})
            else if (mem.startsWith(u8, rest, "{") and mem.endsWith(u8, rest, "}"))
                parseRegName(rest["{".len .. rest.len - "}".len]) orelse
                    return self.fail("invalid register constraint: '{s}'", .{constraint})
            else if (rest.len == 1 and std.ascii.isDigit(rest[0])) {
                const index = std.fmt.charToDigit(rest[0], 10) catch unreachable;
                if (index >= args.items.len) return self.fail("constraint out of bounds: '{s}'", .{
                    constraint,
                });
                break :arg_mcv args.items[index];
            } else return self.fail("invalid constraint: '{s}'", .{constraint});
            break :arg_mcv if (arg_maybe_reg) |reg| .{ .register = reg } else arg: {
                const ptr_mcv = try self.resolveInst(output);
                switch (ptr_mcv) {
                    .immediate => |addr| if (math.cast(i32, @as(i64, @bitCast(addr)))) |_|
                        break :arg ptr_mcv.deref(),
                    .register, .register_offset, .lea_frame => break :arg ptr_mcv.deref(),
                    else => {},
                }
                break :arg .{ .indirect = .{ .reg = try self.copyToTmpRegister(Type.usize, ptr_mcv) } };
            };
        };
        if (arg_mcv.getReg()) |reg| if (RegisterManager.indexOfRegIntoTracked(reg)) |_| {
            _ = self.register_manager.lockReg(reg);
        };
        if (!mem.eql(u8, name, "_"))
            arg_map.putAssumeCapacityNoClobber(name, @intCast(args.items.len));
        args.appendAssumeCapacity(arg_mcv);
        if (output == .none) result = arg_mcv;
        if (is_read) try self.load(arg_mcv, self.typeOf(output), .{ .air_ref = output });
    }

    for (inputs) |input| {
        const input_bytes = mem.sliceAsBytes(self.air.extra[extra_i..]);
        const constraint = mem.sliceTo(input_bytes, 0);
        const name = mem.sliceTo(input_bytes[constraint.len + 1 ..], 0);
        // This equation accounts for the fact that even if we have exactly 4 bytes
        // for the string, we still use the next u32 for the null terminator.
        extra_i += (constraint.len + name.len + (2 + 3)) / 4;

        const ty = self.typeOf(input);
        const input_mcv = try self.resolveInst(input);
        const arg_mcv: MCValue = if (mem.eql(u8, constraint, "r") or
            mem.eql(u8, constraint, "f") or mem.eql(u8, constraint, "x"))
        arg: {
            const rc = switch (constraint[0]) {
                'r' => abi.RegisterClass.gp,
                'f' => abi.RegisterClass.x87,
                'x' => abi.RegisterClass.sse,
                else => unreachable,
            };
            if (input_mcv.isRegister() and
                rc.isSet(RegisterManager.indexOfRegIntoTracked(input_mcv.getReg().?).?))
                break :arg input_mcv;
            const reg = try self.register_manager.allocReg(null, rc);
            try self.genSetReg(reg, ty, input_mcv, .{});
            break :arg .{ .register = registerAlias(reg, @intCast(ty.abiSize(zcu))) };
        } else if (mem.eql(u8, constraint, "i") or mem.eql(u8, constraint, "n"))
            switch (input_mcv) {
                .immediate => |imm| .{ .immediate = imm },
                else => return self.fail("immediate operand requires comptime value: '{s}'", .{
                    constraint,
                }),
            }
        else if (mem.eql(u8, constraint, "m")) arg: {
            switch (input_mcv) {
                .memory => |addr| if (math.cast(i32, @as(i64, @bitCast(addr)))) |_|
                    break :arg input_mcv,
                .indirect, .load_frame => break :arg input_mcv,
                .load_symbol, .load_direct, .load_got, .load_tlv => {},
                else => {
                    const temp_mcv = try self.allocTempRegOrMem(ty, false);
                    try self.genCopy(ty, temp_mcv, input_mcv, .{});
                    break :arg temp_mcv;
                },
            }
            const addr_reg = self.register_manager.tryAllocReg(null, abi.RegisterClass.gp) orelse {
                const temp_mcv = try self.allocTempRegOrMem(ty, false);
                try self.genCopy(ty, temp_mcv, input_mcv, .{});
                break :arg temp_mcv;
            };
            try self.genSetReg(addr_reg, Type.usize, input_mcv.address(), .{});
            break :arg .{ .indirect = .{ .reg = addr_reg } };
        } else if (mem.eql(u8, constraint, "g") or
            mem.eql(u8, constraint, "rm") or mem.eql(u8, constraint, "mr") or
            mem.eql(u8, constraint, "r,m") or mem.eql(u8, constraint, "m,r"))
        arg: {
            switch (input_mcv) {
                .register, .indirect, .load_frame => break :arg input_mcv,
                .memory => |addr| if (math.cast(i32, @as(i64, @bitCast(addr)))) |_|
                    break :arg input_mcv,
                else => {},
            }
            const temp_mcv = try self.allocTempRegOrMem(ty, true);
            try self.genCopy(ty, temp_mcv, input_mcv, .{});
            break :arg temp_mcv;
        } else if (mem.eql(u8, constraint, "X"))
            input_mcv
        else if (mem.startsWith(u8, constraint, "{") and mem.endsWith(u8, constraint, "}")) arg: {
            const reg = parseRegName(constraint["{".len .. constraint.len - "}".len]) orelse
                return self.fail("invalid register constraint: '{s}'", .{constraint});
            try self.register_manager.getReg(reg, null);
            try self.genSetReg(reg, ty, input_mcv, .{});
            break :arg .{ .register = reg };
        } else if (constraint.len == 1 and std.ascii.isDigit(constraint[0])) arg: {
            const index = std.fmt.charToDigit(constraint[0], 10) catch unreachable;
            if (index >= args.items.len) return self.fail("constraint out of bounds: '{s}'", .{constraint});
            try self.genCopy(ty, args.items[index], input_mcv, .{});
            break :arg args.items[index];
        } else return self.fail("invalid constraint: '{s}'", .{constraint});
        if (arg_mcv.getReg()) |reg| if (RegisterManager.indexOfRegIntoTracked(reg)) |_| {
            _ = self.register_manager.lockReg(reg);
        };
        if (!mem.eql(u8, name, "_"))
            arg_map.putAssumeCapacityNoClobber(name, @intCast(args.items.len));
        args.appendAssumeCapacity(arg_mcv);
    }

    {
        var clobber_i: u32 = 0;
        while (clobber_i < clobbers_len) : (clobber_i += 1) {
            const clobber = mem.sliceTo(mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += clobber.len / 4 + 1;

            if (std.mem.eql(u8, clobber, "") or std.mem.eql(u8, clobber, "memory")) {
                // ok, sure
            } else if (std.mem.eql(u8, clobber, "cc") or
                std.mem.eql(u8, clobber, "flags") or
                std.mem.eql(u8, clobber, "eflags") or
                std.mem.eql(u8, clobber, "rflags"))
            {
                try self.spillEflagsIfOccupied();
            } else {
                try self.register_manager.getReg(parseRegName(clobber) orelse
                    return self.fail("invalid clobber: '{s}'", .{clobber}), null);
            }
        }
    }

    const Label = struct {
        target: Mir.Inst.Index = undefined,
        pending_relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .empty,

        const Kind = enum { definition, reference };

        fn isValid(kind: Kind, name: []const u8) bool {
            for (name, 0..) |c, i| switch (c) {
                else => return false,
                '$' => if (i == 0) return false,
                '.' => {},
                '0'...'9' => if (i == 0) switch (kind) {
                    .definition => if (name.len != 1) return false,
                    .reference => {
                        if (name.len != 2) return false;
                        switch (name[1]) {
                            else => return false,
                            'B', 'F', 'b', 'f' => {},
                        }
                    },
                },
                '@', 'A'...'Z', '_', 'a'...'z' => {},
            };
            return name.len > 0;
        }
    };
    var labels: std.StringHashMapUnmanaged(Label) = .empty;
    defer {
        var label_it = labels.valueIterator();
        while (label_it.next()) |label| label.pending_relocs.deinit(self.gpa);
        labels.deinit(self.gpa);
    }

    const asm_source = mem.sliceAsBytes(self.air.extra[extra_i..])[0..extra.data.source_len];
    var line_it = mem.tokenizeAny(u8, asm_source, "\n\r;");
    next_line: while (line_it.next()) |line| {
        var mnem_it = mem.tokenizeAny(u8, line, " \t");
        var prefix: Instruction.Prefix = .none;
        const mnem_str = while (mnem_it.next()) |mnem_str| {
            if (mnem_str[0] == '#') continue :next_line;
            if (mem.startsWith(u8, mnem_str, "//")) continue :next_line;
            if (std.meta.stringToEnum(Instruction.Prefix, mnem_str)) |pre| {
                if (prefix != .none) return self.fail("extra prefix: '{s}'", .{mnem_str});
                prefix = pre;
                continue;
            }
            if (!mem.endsWith(u8, mnem_str, ":")) break mnem_str;
            const label_name = mnem_str[0 .. mnem_str.len - ":".len];
            if (!Label.isValid(.definition, label_name))
                return self.fail("invalid label: '{s}'", .{label_name});
            const label_gop = try labels.getOrPut(self.gpa, label_name);
            if (!label_gop.found_existing) label_gop.value_ptr.* = .{} else {
                const anon = std.ascii.isDigit(label_name[0]);
                if (!anon and label_gop.value_ptr.pending_relocs.items.len == 0)
                    return self.fail("redefined label: '{s}'", .{label_name});
                for (label_gop.value_ptr.pending_relocs.items) |pending_reloc|
                    self.performReloc(pending_reloc);
                if (anon)
                    label_gop.value_ptr.pending_relocs.clearRetainingCapacity()
                else
                    label_gop.value_ptr.pending_relocs.clearAndFree(self.gpa);
            }
            label_gop.value_ptr.target = @intCast(self.mir_instructions.len);
        } else continue;
        if (mnem_str[0] == '.') {
            if (prefix != .none) return self.fail("prefixed directive: '{s} {s}'", .{ @tagName(prefix), mnem_str });
            prefix = .directive;
        }

        var mnem_size: ?Memory.Size = if (prefix == .directive)
            null
        else if (mem.endsWith(u8, mnem_str, "b"))
            .byte
        else if (mem.endsWith(u8, mnem_str, "w"))
            .word
        else if (mem.endsWith(u8, mnem_str, "l"))
            .dword
        else if (mem.endsWith(u8, mnem_str, "q") and
            (std.mem.indexOfScalar(u8, "vp", mnem_str[0]) == null or !mem.endsWith(u8, mnem_str, "dq")))
            .qword
        else if (mem.endsWith(u8, mnem_str, "t"))
            .tbyte
        else
            null;
        const mnem_tag = while (true) break std.meta.stringToEnum(
            Instruction.Mnemonic,
            mnem_str[0 .. mnem_str.len - @intFromBool(mnem_size != null)],
        ) orelse if (mnem_size) |_| {
            mnem_size = null;
            continue;
        } else return self.fail("invalid mnemonic: '{s}'", .{mnem_str});
        if (@as(?Memory.Size, switch (mnem_tag) {
            .clflush => .byte,
            .fldenv, .fnstenv, .fstenv => .none,
            .ldmxcsr, .stmxcsr, .vldmxcsr, .vstmxcsr => .dword,
            else => null,
        })) |fixed_mnem_size| {
            if (mnem_size) |size| if (size != fixed_mnem_size)
                return self.fail("invalid size: '{s}'", .{mnem_str});
            mnem_size = fixed_mnem_size;
        }
        const mnem_name = @tagName(mnem_tag);
        const mnem_fixed_tag: Mir.Inst.FixedTag = if (prefix == .directive)
            .{ ._, .pseudo }
        else for (std.enums.values(Mir.Inst.Fixes)) |fixes| {
            const fixes_name = @tagName(fixes);
            const space_i = mem.indexOfScalar(u8, fixes_name, ' ');
            const fixes_prefix = if (space_i) |i|
                std.meta.stringToEnum(Instruction.Prefix, fixes_name[0..i]).?
            else
                .none;
            if (fixes_prefix != prefix) continue;
            const pattern = fixes_name[if (space_i) |i| i + " ".len else 0..];
            const wildcard_i = mem.indexOfScalar(u8, pattern, '_').?;
            const mnem_prefix = pattern[0..wildcard_i];
            const mnem_suffix = pattern[wildcard_i + "_".len ..];
            if (!mem.startsWith(u8, mnem_name, mnem_prefix)) continue;
            if (!mem.endsWith(u8, mnem_name, mnem_suffix)) continue;
            break .{ fixes, std.meta.stringToEnum(
                Mir.Inst.Tag,
                mnem_name[mnem_prefix.len .. mnem_name.len - mnem_suffix.len],
            ) orelse continue };
        } else {
            assert(prefix != .none); // no combination of fixes produced a known mnemonic
            return self.fail("invalid prefix for mnemonic: '{s} {s}'", .{
                @tagName(prefix), mnem_name,
            });
        };

        const Operand = union(enum) {
            none,
            reg: Register,
            mem: Memory,
            imm: Immediate,
            inst: Mir.Inst.Index,
        };
        var ops: [4]Operand = .{.none} ** 4;

        var last_op = false;
        var op_it = mem.splitScalar(u8, mnem_it.rest(), ',');
        next_op: for (&ops) |*op| {
            const op_str = while (!last_op) {
                const full_str = op_it.next() orelse break :next_op;
                const code_str = if (mem.indexOfScalar(u8, full_str, '#') orelse
                    mem.indexOf(u8, full_str, "//")) |comment|
                code: {
                    last_op = true;
                    break :code full_str[0..comment];
                } else full_str;
                const trim_str = mem.trim(u8, code_str, " \t*");
                if (trim_str.len > 0) break trim_str;
            } else break;
            if (mem.startsWith(u8, op_str, "%%")) {
                const colon = mem.indexOfScalarPos(u8, op_str, "%%".len + 2, ':');
                const reg = parseRegName(op_str["%%".len .. colon orelse op_str.len]) orelse
                    return self.fail("invalid register: '{s}'", .{op_str});
                if (colon) |colon_pos| {
                    const disp = std.fmt.parseInt(i32, op_str[colon_pos + ":".len ..], 0) catch
                        return self.fail("invalid displacement: '{s}'", .{op_str});
                    op.* = .{ .mem = .{
                        .base = .{ .reg = reg },
                        .mod = .{ .rm = .{
                            .size = mnem_size orelse return self.fail("unknown size: '{s}'", .{op_str}),
                            .disp = disp,
                        } },
                    } };
                } else {
                    if (mnem_size) |size| if (reg.bitSize() != size.bitSize())
                        return self.fail("invalid register size: '{s}'", .{op_str});
                    op.* = .{ .reg = reg };
                }
            } else if (mem.startsWith(u8, op_str, "%[") and mem.endsWith(u8, op_str, "]")) {
                const colon = mem.indexOfScalarPos(u8, op_str, "%[".len, ':');
                const modifier = if (colon) |colon_pos|
                    op_str[colon_pos + ":".len .. op_str.len - "]".len]
                else
                    "";
                op.* = switch (args.items[
                    arg_map.get(op_str["%[".len .. colon orelse op_str.len - "]".len]) orelse
                        return self.fail("no matching constraint: '{s}'", .{op_str})
                ]) {
                    .immediate => |imm| if (mem.eql(u8, modifier, "") or mem.eql(u8, modifier, "c"))
                        .{ .imm = Immediate.u(imm) }
                    else
                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                    .register => |reg| if (mem.eql(u8, modifier, ""))
                        .{ .reg = reg }
                    else
                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                    .memory => |addr| if (mem.eql(u8, modifier, "") or mem.eql(u8, modifier, "P"))
                        .{ .mem = .{
                            .base = .{ .reg = .ds },
                            .mod = .{ .rm = .{
                                .size = mnem_size orelse
                                    return self.fail("unknown size: '{s}'", .{op_str}),
                                .disp = @intCast(@as(i64, @bitCast(addr))),
                            } },
                        } }
                    else
                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                    .indirect => |reg_off| if (mem.eql(u8, modifier, ""))
                        .{ .mem = .{
                            .base = .{ .reg = reg_off.reg },
                            .mod = .{ .rm = .{
                                .size = mnem_size orelse
                                    return self.fail("unknown size: '{s}'", .{op_str}),
                                .disp = reg_off.off,
                            } },
                        } }
                    else
                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                    .load_frame => |frame_addr| if (mem.eql(u8, modifier, ""))
                        .{ .mem = .{
                            .base = .{ .frame = frame_addr.index },
                            .mod = .{ .rm = .{
                                .size = mnem_size orelse
                                    return self.fail("unknown size: '{s}'", .{op_str}),
                                .disp = frame_addr.off,
                            } },
                        } }
                    else
                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                    .lea_got => |sym_index| if (mem.eql(u8, modifier, "P"))
                        .{ .reg = try self.copyToTmpRegister(Type.usize, .{ .lea_got = sym_index }) }
                    else
                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                    .lea_symbol => |sym_off| if (mem.eql(u8, modifier, "P"))
                        .{ .reg = try self.copyToTmpRegister(Type.usize, .{ .lea_symbol = sym_off }) }
                    else
                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                    else => return self.fail("invalid constraint: '{s}'", .{op_str}),
                };
            } else if (mem.startsWith(u8, op_str, "$")) {
                if (std.fmt.parseInt(i32, op_str["$".len..], 0)) |s| {
                    if (mnem_size) |size| {
                        const max = @as(u64, math.maxInt(u64)) >> @intCast(64 - (size.bitSize() - 1));
                        if ((if (s < 0) ~s else s) > max)
                            return self.fail("invalid immediate size: '{s}'", .{op_str});
                    }
                    op.* = .{ .imm = Immediate.s(s) };
                } else |_| if (std.fmt.parseInt(u64, op_str["$".len..], 0)) |u| {
                    if (mnem_size) |size| {
                        const max = @as(u64, math.maxInt(u64)) >> @intCast(64 - size.bitSize());
                        if (u > max)
                            return self.fail("invalid immediate size: '{s}'", .{op_str});
                    }
                    op.* = .{ .imm = Immediate.u(u) };
                } else |_| return self.fail("invalid immediate: '{s}'", .{op_str});
            } else if (mem.endsWith(u8, op_str, ")")) {
                const open = mem.indexOfScalar(u8, op_str, '(') orelse
                    return self.fail("invalid operand: '{s}'", .{op_str});
                var sib_it = mem.splitScalar(u8, op_str[open + "(".len .. op_str.len - ")".len], ',');
                const base_str = sib_it.next() orelse
                    return self.fail("invalid memory operand: '{s}'", .{op_str});
                if (base_str.len > 0 and !mem.startsWith(u8, base_str, "%%"))
                    return self.fail("invalid memory operand: '{s}'", .{op_str});
                const index_str = sib_it.next() orelse "";
                if (index_str.len > 0 and !mem.startsWith(u8, base_str, "%%"))
                    return self.fail("invalid memory operand: '{s}'", .{op_str});
                const scale_str = sib_it.next() orelse "";
                if (index_str.len == 0 and scale_str.len > 0)
                    return self.fail("invalid memory operand: '{s}'", .{op_str});
                const scale: Memory.Scale = if (scale_str.len > 0)
                    switch (std.fmt.parseInt(u4, scale_str, 10) catch
                        return self.fail("invalid scale: '{s}'", .{op_str})) {
                        1 => .@"1",
                        2 => .@"2",
                        4 => .@"4",
                        8 => .@"8",
                        else => return self.fail("invalid scale: '{s}'", .{op_str}),
                    }
                else
                    .@"1";
                if (sib_it.next()) |_| return self.fail("invalid memory operand: '{s}'", .{op_str});
                op.* = .{
                    .mem = .{
                        .base = if (base_str.len > 0)
                            .{ .reg = parseRegName(base_str["%%".len..]) orelse
                                return self.fail("invalid base register: '{s}'", .{base_str}) }
                        else
                            .none,
                        .mod = .{ .rm = .{
                            .size = mnem_size orelse return self.fail("unknown size: '{s}'", .{op_str}),
                            .index = if (index_str.len > 0)
                                parseRegName(index_str["%%".len..]) orelse
                                    return self.fail("invalid index register: '{s}'", .{op_str})
                            else
                                .none,
                            .scale = scale,
                            .disp = if (mem.startsWith(u8, op_str[0..open], "%[") and
                                mem.endsWith(u8, op_str[0..open], "]"))
                            disp: {
                                const colon = mem.indexOfScalarPos(u8, op_str[0..open], "%[".len, ':');
                                const modifier = if (colon) |colon_pos|
                                    op_str[colon_pos + ":".len .. open - "]".len]
                                else
                                    "";
                                break :disp switch (args.items[
                                    arg_map.get(op_str["%[".len .. colon orelse open - "]".len]) orelse
                                        return self.fail("no matching constraint: '{s}'", .{op_str})
                                ]) {
                                    .immediate => |imm| if (mem.eql(u8, modifier, "") or
                                        mem.eql(u8, modifier, "c"))
                                        math.cast(i32, @as(i64, @bitCast(imm))) orelse
                                            return self.fail("invalid displacement: '{s}'", .{op_str})
                                    else
                                        return self.fail("invalid modifier: '{s}'", .{modifier}),
                                    else => return self.fail("invalid constraint: '{s}'", .{op_str}),
                                };
                            } else if (open > 0)
                                std.fmt.parseInt(i32, op_str[0..open], 0) catch
                                    return self.fail("invalid displacement: '{s}'", .{op_str})
                            else
                                0,
                        } },
                    },
                };
            } else if (Label.isValid(.reference, op_str)) {
                const anon = std.ascii.isDigit(op_str[0]);
                const label_gop = try labels.getOrPut(self.gpa, op_str[0..if (anon) 1 else op_str.len]);
                if (!label_gop.found_existing) label_gop.value_ptr.* = .{};
                if (anon and (op_str[1] == 'b' or op_str[1] == 'B') and !label_gop.found_existing)
                    return self.fail("undefined label: '{s}'", .{op_str});
                const pending_relocs = &label_gop.value_ptr.pending_relocs;
                if (if (anon)
                    op_str[1] == 'f' or op_str[1] == 'F'
                else
                    !label_gop.found_existing or pending_relocs.items.len > 0)
                    try pending_relocs.append(self.gpa, @intCast(self.mir_instructions.len));
                op.* = .{ .inst = label_gop.value_ptr.target };
            } else return self.fail("invalid operand: '{s}'", .{op_str});
        } else if (op_it.next()) |op_str| return self.fail("extra operand: '{s}'", .{op_str});

        (if (prefix == .directive) switch (mnem_tag) {
            .@".cfi_def_cfa" => if (ops[0] == .reg and ops[1] == .imm and ops[2] == .none)
                self.asmPseudoRegisterImmediate(.pseudo_cfi_def_cfa_ri_s, ops[0].reg, ops[1].imm)
            else
                error.InvalidInstruction,
            .@".cfi_def_cfa_register" => if (ops[0] == .reg and ops[1] == .none)
                self.asmPseudoRegister(.pseudo_cfi_def_cfa_register_r, ops[0].reg)
            else
                error.InvalidInstruction,
            .@".cfi_def_cfa_offset" => if (ops[0] == .imm and ops[1] == .none)
                self.asmPseudoImmediate(.pseudo_cfi_def_cfa_offset_i_s, ops[0].imm)
            else
                error.InvalidInstruction,
            .@".cfi_adjust_cfa_offset" => if (ops[0] == .imm and ops[1] == .none)
                self.asmPseudoImmediate(.pseudo_cfi_adjust_cfa_offset_i_s, ops[0].imm)
            else
                error.InvalidInstruction,
            .@".cfi_offset" => if (ops[0] == .reg and ops[1] == .imm and ops[2] == .none)
                self.asmPseudoRegisterImmediate(.pseudo_cfi_offset_ri_s, ops[0].reg, ops[1].imm)
            else
                error.InvalidInstruction,
            .@".cfi_val_offset" => if (ops[0] == .reg and ops[1] == .imm and ops[2] == .none)
                self.asmPseudoRegisterImmediate(.pseudo_cfi_val_offset_ri_s, ops[0].reg, ops[1].imm)
            else
                error.InvalidInstruction,
            .@".cfi_rel_offset" => if (ops[0] == .reg and ops[1] == .imm and ops[2] == .none)
                self.asmPseudoRegisterImmediate(.pseudo_cfi_rel_offset_ri_s, ops[0].reg, ops[1].imm)
            else
                error.InvalidInstruction,
            .@".cfi_register" => if (ops[0] == .reg and ops[1] == .reg and ops[2] == .none)
                self.asmPseudoRegisterRegister(.pseudo_cfi_register_rr, ops[0].reg, ops[1].reg)
            else
                error.InvalidInstruction,
            .@".cfi_restore" => if (ops[0] == .reg and ops[1] == .none)
                self.asmPseudoRegister(.pseudo_cfi_restore_r, ops[0].reg)
            else
                error.InvalidInstruction,
            .@".cfi_undefined" => if (ops[0] == .reg and ops[1] == .none)
                self.asmPseudoRegister(.pseudo_cfi_undefined_r, ops[0].reg)
            else
                error.InvalidInstruction,
            .@".cfi_same_value" => if (ops[0] == .reg and ops[1] == .none)
                self.asmPseudoRegister(.pseudo_cfi_same_value_r, ops[0].reg)
            else
                error.InvalidInstruction,
            .@".cfi_remember_state" => if (ops[0] == .none)
                self.asmPseudo(.pseudo_cfi_remember_state_none)
            else
                error.InvalidInstruction,
            .@".cfi_restore_state" => if (ops[0] == .none)
                self.asmPseudo(.pseudo_cfi_restore_state_none)
            else
                error.InvalidInstruction,
            .@".cfi_escape" => error.InvalidInstruction,
            else => unreachable,
        } else switch (ops[0]) {
            .none => self.asmOpOnly(mnem_fixed_tag),
            .reg => |reg0| switch (ops[1]) {
                .none => self.asmRegister(mnem_fixed_tag, reg0),
                .reg => |reg1| switch (ops[2]) {
                    .none => self.asmRegisterRegister(mnem_fixed_tag, reg1, reg0),
                    .reg => |reg2| switch (ops[3]) {
                        .none => self.asmRegisterRegisterRegister(mnem_fixed_tag, reg2, reg1, reg0),
                        else => error.InvalidInstruction,
                    },
                    .mem => |mem2| switch (ops[3]) {
                        .none => self.asmMemoryRegisterRegister(mnem_fixed_tag, mem2, reg1, reg0),
                        else => error.InvalidInstruction,
                    },
                    else => error.InvalidInstruction,
                },
                .mem => |mem1| switch (ops[2]) {
                    .none => self.asmMemoryRegister(mnem_fixed_tag, mem1, reg0),
                    else => error.InvalidInstruction,
                },
                else => error.InvalidInstruction,
            },
            .mem => |mem0| switch (ops[1]) {
                .none => self.asmMemory(mnem_fixed_tag, mem0),
                .reg => |reg1| switch (ops[2]) {
                    .none => self.asmRegisterMemory(mnem_fixed_tag, reg1, mem0),
                    else => error.InvalidInstruction,
                },
                else => error.InvalidInstruction,
            },
            .imm => |imm0| switch (ops[1]) {
                .none => self.asmImmediate(mnem_fixed_tag, imm0),
                .reg => |reg1| switch (ops[2]) {
                    .none => self.asmRegisterImmediate(mnem_fixed_tag, reg1, imm0),
                    .reg => |reg2| switch (ops[3]) {
                        .none => self.asmRegisterRegisterImmediate(mnem_fixed_tag, reg2, reg1, imm0),
                        .reg => |reg3| self.asmRegisterRegisterRegisterImmediate(
                            mnem_fixed_tag,
                            reg3,
                            reg2,
                            reg1,
                            imm0,
                        ),
                        else => error.InvalidInstruction,
                    },
                    .mem => |mem2| switch (ops[3]) {
                        .none => self.asmMemoryRegisterImmediate(mnem_fixed_tag, mem2, reg1, imm0),
                        else => error.InvalidInstruction,
                    },
                    else => error.InvalidInstruction,
                },
                .mem => |mem1| switch (ops[2]) {
                    .none => self.asmMemoryImmediate(mnem_fixed_tag, mem1, imm0),
                    else => error.InvalidInstruction,
                },
                else => error.InvalidInstruction,
            },
            .inst => |inst0| switch (ops[1]) {
                .none => self.asmReloc(mnem_fixed_tag, inst0),
                else => error.InvalidInstruction,
            },
        }) catch |err| switch (err) {
            error.InvalidInstruction => return self.fail(
                "invalid instruction: '{s} {s} {s} {s} {s}'",
                .{
                    mnem_str,
                    @tagName(ops[0]),
                    @tagName(ops[1]),
                    @tagName(ops[2]),
                    @tagName(ops[3]),
                },
            ),
            else => |e| return e,
        };
    }

    var label_it = labels.iterator();
    while (label_it.next()) |label| if (label.value_ptr.pending_relocs.items.len > 0)
        return self.fail("undefined label: '{s}'", .{label.key_ptr.*});

    for (outputs, args.items[0..outputs.len]) |output, arg_mcv| {
        const extra_bytes = mem.sliceAsBytes(self.air.extra[outputs_extra_i..]);
        const constraint =
            mem.sliceTo(mem.sliceAsBytes(self.air.extra[outputs_extra_i..]), 0);
        const name = mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
        // This equation accounts for the fact that even if we have exactly 4 bytes
        // for the string, we still use the next u32 for the null terminator.
        outputs_extra_i += (constraint.len + name.len + (2 + 3)) / 4;

        if (output == .none) continue;
        if (arg_mcv != .register) continue;
        if (constraint.len == 2 and std.ascii.isDigit(constraint[1])) continue;
        try self.store(self.typeOf(output), .{ .air_ref = output }, arg_mcv, .{});
    }

    simple: {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        var buf_index: usize = 0;
        for (outputs) |output| {
            if (output == .none) continue;

            if (buf_index >= buf.len) break :simple;
            buf[buf_index] = output;
            buf_index += 1;
        }
        if (buf_index + inputs.len > buf.len) break :simple;
        @memcpy(buf[buf_index..][0..inputs.len], inputs);
        return self.finishAir(inst, result, buf);
    }
    var bt = self.liveness.iterateBigTomb(inst);
    for (outputs) |output| if (output != .none) try self.feed(&bt, output);
    for (inputs) |input| try self.feed(&bt, input);
    return self.finishAirResult(inst, result);
}

const MoveStrategy = union(enum) {
    move: Mir.Inst.FixedTag,
    x87_load_store,
    insert_extract: InsertExtract,
    vex_insert_extract: InsertExtract,

    const InsertExtract = struct {
        insert: Mir.Inst.FixedTag,
        extract: Mir.Inst.FixedTag,
    };

    pub fn read(strat: MoveStrategy, self: *Self, dst_reg: Register, src_mem: Memory) !void {
        switch (strat) {
            .move => |tag| try self.asmRegisterMemory(tag, dst_reg, src_mem),
            .x87_load_store => {
                try self.asmMemory(.{ .f_, .ld }, src_mem);
                assert(dst_reg != .st7);
                try self.asmRegister(.{ .f_p, .st }, @enumFromInt(@intFromEnum(dst_reg) + 1));
            },
            .insert_extract => |ie| try self.asmRegisterMemoryImmediate(
                ie.insert,
                dst_reg,
                src_mem,
                Immediate.u(0),
            ),
            .vex_insert_extract => |ie| try self.asmRegisterRegisterMemoryImmediate(
                ie.insert,
                dst_reg,
                dst_reg,
                src_mem,
                Immediate.u(0),
            ),
        }
    }
    pub fn write(strat: MoveStrategy, self: *Self, dst_mem: Memory, src_reg: Register) !void {
        switch (strat) {
            .move => |tag| try self.asmMemoryRegister(tag, dst_mem, src_reg),
            .x87_load_store => {
                try self.asmRegister(.{ .f_, .ld }, src_reg);
                try self.asmMemory(.{ .f_p, .st }, dst_mem);
            },
            .insert_extract, .vex_insert_extract => |ie| try self.asmMemoryRegisterImmediate(
                ie.extract,
                dst_mem,
                src_reg,
                Immediate.u(0),
            ),
        }
    }
};
fn moveStrategy(self: *Self, ty: Type, class: Register.Class, aligned: bool) !MoveStrategy {
    const pt = self.pt;
    const zcu = pt.zcu;
    switch (class) {
        .general_purpose, .segment => return .{ .move = .{ ._, .mov } },
        .x87 => return .x87_load_store,
        .mmx => {},
        .sse => switch (ty.zigTypeTag(zcu)) {
            else => {
                const classes = mem.sliceTo(&abi.classifySystemV(ty, zcu, self.target.*, .other), .none);
                assert(std.mem.indexOfNone(abi.Class, classes, &.{
                    .integer, .sse, .sseup, .memory, .float, .float_combine,
                }) == null);
                const abi_size = ty.abiSize(zcu);
                if (abi_size < 4 or
                    std.mem.indexOfScalar(abi.Class, classes, .integer) != null) switch (abi_size) {
                    1 => if (self.hasFeature(.avx)) return .{ .vex_insert_extract = .{
                        .insert = .{ .vp_b, .insr },
                        .extract = .{ .vp_b, .extr },
                    } } else if (self.hasFeature(.sse4_2)) return .{ .insert_extract = .{
                        .insert = .{ .p_b, .insr },
                        .extract = .{ .p_b, .extr },
                    } },
                    2 => return if (self.hasFeature(.avx)) .{ .vex_insert_extract = .{
                        .insert = .{ .vp_w, .insr },
                        .extract = .{ .vp_w, .extr },
                    } } else .{ .insert_extract = .{
                        .insert = .{ .p_w, .insr },
                        .extract = .{ .p_w, .extr },
                    } },
                    3...4 => return .{ .move = if (self.hasFeature(.avx))
                        .{ .v_d, .mov }
                    else
                        .{ ._d, .mov } },
                    5...8 => return .{ .move = if (self.hasFeature(.avx))
                        .{ .v_q, .mov }
                    else
                        .{ ._q, .mov } },
                    9...16 => return .{ .move = if (self.hasFeature(.avx))
                        if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                    else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                    17...32 => if (self.hasFeature(.avx))
                        return .{ .move = if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu } },
                    else => {},
                } else switch (abi_size) {
                    4 => return .{ .move = if (self.hasFeature(.avx))
                        .{ .v_ss, .mov }
                    else
                        .{ ._ss, .mov } },
                    5...8 => return .{ .move = if (self.hasFeature(.avx))
                        .{ .v_sd, .mov }
                    else
                        .{ ._sd, .mov } },
                    9...16 => return .{ .move = if (self.hasFeature(.avx))
                        if (aligned) .{ .v_pd, .mova } else .{ .v_pd, .movu }
                    else if (aligned) .{ ._pd, .mova } else .{ ._pd, .movu } },
                    17...32 => if (self.hasFeature(.avx)) return .{ .move = if (aligned)
                        .{ .v_pd, .mova }
                    else
                        .{ .v_pd, .movu } },
                    else => {},
                }
            },
            .float => switch (ty.floatBits(self.target.*)) {
                16 => return if (self.hasFeature(.avx)) .{ .vex_insert_extract = .{
                    .insert = .{ .vp_w, .insr },
                    .extract = .{ .vp_w, .extr },
                } } else .{ .insert_extract = .{
                    .insert = .{ .p_w, .insr },
                    .extract = .{ .p_w, .extr },
                } },
                32 => return .{ .move = if (self.hasFeature(.avx))
                    .{ .v_ss, .mov }
                else
                    .{ ._ss, .mov } },
                64 => return .{ .move = if (self.hasFeature(.avx))
                    .{ .v_sd, .mov }
                else
                    .{ ._sd, .mov } },
                128 => return .{ .move = if (self.hasFeature(.avx))
                    if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                else => {},
            },
            .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                .bool => switch (ty.vectorLen(zcu)) {
                    33...64 => return .{ .move = if (self.hasFeature(.avx))
                        .{ .v_q, .mov }
                    else
                        .{ ._q, .mov } },
                    else => {},
                },
                .int => switch (ty.childType(zcu).intInfo(zcu).bits) {
                    1...8 => switch (ty.vectorLen(zcu)) {
                        1...16 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        17...32 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    9...16 => switch (ty.vectorLen(zcu)) {
                        1...8 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        9...16 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    17...32 => switch (ty.vectorLen(zcu)) {
                        1...4 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        5...8 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    33...64 => switch (ty.vectorLen(zcu)) {
                        1...2 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        3...4 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    65...128 => switch (ty.vectorLen(zcu)) {
                        1 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        2 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    129...256 => switch (ty.vectorLen(zcu)) {
                        1 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    else => {},
                },
                .pointer, .optional => if (ty.childType(zcu).isPtrAtRuntime(zcu))
                    switch (ty.vectorLen(zcu)) {
                        1...2 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        3...4 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    }
                else
                    unreachable,
                .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                    16 => switch (ty.vectorLen(zcu)) {
                        1...8 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        9...16 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    32 => switch (ty.vectorLen(zcu)) {
                        1...4 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_ps, .mova } else .{ .v_ps, .movu }
                        else if (aligned) .{ ._ps, .mova } else .{ ._ps, .movu } },
                        5...8 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_ps, .mova }
                            else
                                .{ .v_ps, .movu } },
                        else => {},
                    },
                    64 => switch (ty.vectorLen(zcu)) {
                        1...2 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_pd, .mova } else .{ .v_pd, .movu }
                        else if (aligned) .{ ._pd, .mova } else .{ ._pd, .movu } },
                        3...4 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_pd, .mova }
                            else
                                .{ .v_pd, .movu } },
                        else => {},
                    },
                    128 => switch (ty.vectorLen(zcu)) {
                        1 => return .{ .move = if (self.hasFeature(.avx))
                            if (aligned) .{ .v_, .movdqa } else .{ .v_, .movdqu }
                        else if (aligned) .{ ._, .movdqa } else .{ ._, .movdqu } },
                        2 => if (self.hasFeature(.avx))
                            return .{ .move = if (aligned)
                                .{ .v_, .movdqa }
                            else
                                .{ .v_, .movdqu } },
                        else => {},
                    },
                    else => {},
                },
                else => {},
            },
        },
        .ip => {},
    }
    return self.fail("TODO moveStrategy for {}", .{ty.fmt(pt)});
}

const CopyOptions = struct {
    safety: bool = false,
};

fn genCopy(self: *Self, ty: Type, dst_mcv: MCValue, src_mcv: MCValue, opts: CopyOptions) InnerError!void {
    const pt = self.pt;

    const src_lock = if (src_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .eflags,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .lea_symbol,
        .elementwise_regs_then_frame,
        .reserved_frame,
        .air_ref,
        => unreachable, // unmodifiable destination
        .register => |reg| try self.genSetReg(reg, ty, src_mcv, opts),
        .register_offset => |dst_reg_off| try self.genSetReg(dst_reg_off.reg, ty, switch (src_mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .register_overflow,
            .elementwise_regs_then_frame,
            .reserved_frame,
            => unreachable,
            .immediate,
            .register,
            .register_offset,
            .lea_frame,
            => src_mcv.offset(-dst_reg_off.off),
            else => .{ .register_offset = .{
                .reg = try self.copyToTmpRegister(ty, src_mcv),
                .off = -dst_reg_off.off,
            } },
        }, opts),
        .register_pair => |dst_regs| {
            const src_info: ?struct { addr_reg: Register, addr_lock: RegisterLock } = switch (src_mcv) {
                .register_pair, .memory, .indirect, .load_frame => null,
                .load_symbol, .load_direct, .load_got, .load_tlv => src: {
                    const src_addr_reg =
                        (try self.register_manager.allocReg(null, abi.RegisterClass.gp)).to64();
                    const src_addr_lock = self.register_manager.lockRegAssumeUnused(src_addr_reg);
                    errdefer self.register_manager.unlockReg(src_addr_lock);

                    try self.genSetReg(src_addr_reg, Type.usize, src_mcv.address(), opts);
                    break :src .{ .addr_reg = src_addr_reg, .addr_lock = src_addr_lock };
                },
                .air_ref => |src_ref| return self.genCopy(
                    ty,
                    dst_mcv,
                    try self.resolveInst(src_ref),
                    opts,
                ),
                else => return self.fail("TODO implement genCopy for {s} of {}", .{
                    @tagName(src_mcv), ty.fmt(pt),
                }),
            };
            defer if (src_info) |info| self.register_manager.unlockReg(info.addr_lock);

            var part_disp: i32 = 0;
            for (dst_regs, try self.splitType(ty), 0..) |dst_reg, dst_ty, part_i| {
                try self.genSetReg(dst_reg, dst_ty, switch (src_mcv) {
                    .register_pair => |src_regs| .{ .register = src_regs[part_i] },
                    .memory, .indirect, .load_frame => src_mcv.address().offset(part_disp).deref(),
                    .load_symbol, .load_direct, .load_got, .load_tlv => .{ .indirect = .{
                        .reg = src_info.?.addr_reg,
                        .off = part_disp,
                    } },
                    else => unreachable,
                }, opts);
                part_disp += @intCast(dst_ty.abiSize(pt.zcu));
            }
        },
        .indirect => |reg_off| try self.genSetMem(
            .{ .reg = reg_off.reg },
            reg_off.off,
            ty,
            src_mcv,
            opts,
        ),
        .memory, .load_symbol, .load_direct, .load_got, .load_tlv => {
            switch (dst_mcv) {
                .memory => |addr| if (math.cast(i32, @as(i64, @bitCast(addr)))) |small_addr|
                    return self.genSetMem(.{ .reg = .ds }, small_addr, ty, src_mcv, opts),
                .load_symbol, .load_direct, .load_got, .load_tlv => {},
                else => unreachable,
            }

            const addr_reg = try self.copyToTmpRegister(Type.usize, dst_mcv.address());
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genSetMem(.{ .reg = addr_reg }, 0, ty, src_mcv, opts);
        },
        .load_frame => |frame_addr| try self.genSetMem(
            .{ .frame = frame_addr.index },
            frame_addr.off,
            ty,
            src_mcv,
            opts,
        ),
    }
}

fn genSetReg(
    self: *Self,
    dst_reg: Register,
    ty: Type,
    src_mcv: MCValue,
    opts: CopyOptions,
) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size: u32 = @intCast(ty.abiSize(zcu));
    if (ty.bitSize(zcu) > dst_reg.bitSize())
        return self.fail("genSetReg called with a value larger than dst_reg", .{});
    switch (src_mcv) {
        .none,
        .unreach,
        .dead,
        .register_overflow,
        .elementwise_regs_then_frame,
        .reserved_frame,
        => unreachable,
        .undef => if (opts.safety) switch (dst_reg.class()) {
            .general_purpose => switch (abi_size) {
                1 => try self.asmRegisterImmediate(.{ ._, .mov }, dst_reg.to8(), Immediate.u(0xAA)),
                2 => try self.asmRegisterImmediate(.{ ._, .mov }, dst_reg.to16(), Immediate.u(0xAAAA)),
                3...4 => try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    dst_reg.to32(),
                    Immediate.s(@as(i32, @bitCast(@as(u32, 0xAAAAAAAA)))),
                ),
                5...8 => try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    dst_reg.to64(),
                    Immediate.u(0xAAAAAAAAAAAAAAAA),
                ),
                else => unreachable,
            },
            .segment, .x87, .mmx, .sse => try self.genSetReg(dst_reg, ty, try self.genTypedValue(try pt.undefValue(ty)), opts),
            .ip => unreachable,
        },
        .eflags => |cc| try self.asmSetccRegister(cc, dst_reg.to8()),
        .immediate => |imm| {
            if (imm == 0) {
                // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
                // register is the fastest way to zero a register.
                try self.spillEflagsIfOccupied();
                try self.asmRegisterRegister(.{ ._, .xor }, dst_reg.to32(), dst_reg.to32());
            } else if (abi_size > 4 and math.cast(u32, imm) != null) {
                // 32-bit moves zero-extend to 64-bit.
                try self.asmRegisterImmediate(.{ ._, .mov }, dst_reg.to32(), Immediate.u(imm));
            } else if (abi_size <= 4 and @as(i64, @bitCast(imm)) < 0) {
                try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    registerAlias(dst_reg, abi_size),
                    Immediate.s(@intCast(@as(i64, @bitCast(imm)))),
                );
            } else {
                try self.asmRegisterImmediate(
                    .{ ._, .mov },
                    registerAlias(dst_reg, abi_size),
                    Immediate.u(imm),
                );
            }
        },
        .register => |src_reg| if (dst_reg.id() != src_reg.id()) switch (dst_reg.class()) {
            .general_purpose => switch (src_reg.class()) {
                .general_purpose => try self.asmRegisterRegister(
                    .{ ._, .mov },
                    registerAlias(dst_reg, abi_size),
                    registerAlias(src_reg, abi_size),
                ),
                .segment => try self.asmRegisterRegister(
                    .{ ._, .mov },
                    registerAlias(dst_reg, abi_size),
                    src_reg,
                ),
                .x87, .mmx, .ip => unreachable,
                .sse => try self.asmRegisterRegister(
                    switch (abi_size) {
                        1...4 => if (self.hasFeature(.avx)) .{ .v_d, .mov } else .{ ._d, .mov },
                        5...8 => if (self.hasFeature(.avx)) .{ .v_q, .mov } else .{ ._q, .mov },
                        else => unreachable,
                    },
                    registerAlias(dst_reg, @max(abi_size, 4)),
                    src_reg.to128(),
                ),
            },
            .segment => try self.asmRegisterRegister(
                .{ ._, .mov },
                dst_reg,
                switch (src_reg.class()) {
                    .general_purpose, .segment => registerAlias(src_reg, abi_size),
                    .x87, .mmx, .ip => unreachable,
                    .sse => try self.copyToTmpRegister(ty, src_mcv),
                },
            ),
            .x87 => switch (src_reg.class()) {
                .general_purpose, .segment => unreachable,
                .x87 => switch (src_reg) {
                    .st0 => try self.asmRegister(.{ .f_, .st }, dst_reg),
                    .st1, .st2, .st3, .st4, .st5, .st6 => {
                        try self.asmRegister(.{ .f_, .ld }, src_reg);
                        assert(dst_reg != .st7);
                        try self.asmRegister(.{ .f_p, .st }, @enumFromInt(@intFromEnum(dst_reg) + 1));
                    },
                    else => unreachable,
                },
                .mmx, .sse, .ip => unreachable,
            },
            .mmx => unreachable,
            .sse => switch (src_reg.class()) {
                .general_purpose => try self.asmRegisterRegister(
                    switch (abi_size) {
                        1...4 => if (self.hasFeature(.avx)) .{ .v_d, .mov } else .{ ._d, .mov },
                        5...8 => if (self.hasFeature(.avx)) .{ .v_q, .mov } else .{ ._q, .mov },
                        else => unreachable,
                    },
                    dst_reg.to128(),
                    registerAlias(src_reg, @max(abi_size, 4)),
                ),
                .segment => try self.genSetReg(
                    dst_reg,
                    ty,
                    .{ .register = try self.copyToTmpRegister(ty, src_mcv) },
                    opts,
                ),
                .x87, .mmx, .ip => unreachable,
                .sse => try self.asmRegisterRegister(
                    @as(?Mir.Inst.FixedTag, switch (ty.scalarType(zcu).zigTypeTag(zcu)) {
                        else => switch (abi_size) {
                            1...16 => if (self.hasFeature(.avx)) .{ .v_, .movdqa } else .{ ._, .movdqa },
                            17...32 => if (self.hasFeature(.avx)) .{ .v_, .movdqa } else null,
                            else => null,
                        },
                        .float => switch (ty.scalarType(zcu).floatBits(self.target.*)) {
                            16, 128 => switch (abi_size) {
                                2...16 => if (self.hasFeature(.avx))
                                    .{ .v_, .movdqa }
                                else
                                    .{ ._, .movdqa },
                                17...32 => if (self.hasFeature(.avx)) .{ .v_, .movdqa } else null,
                                else => null,
                            },
                            32 => if (self.hasFeature(.avx)) .{ .v_ps, .mova } else .{ ._ps, .mova },
                            64 => if (self.hasFeature(.avx)) .{ .v_pd, .mova } else .{ ._pd, .mova },
                            80 => null,
                            else => unreachable,
                        },
                    }) orelse return self.fail("TODO implement genSetReg for {}", .{ty.fmt(pt)}),
                    registerAlias(dst_reg, abi_size),
                    registerAlias(src_reg, abi_size),
                ),
            },
            .ip => unreachable,
        },
        .register_pair => |src_regs| try self.genSetReg(dst_reg, ty, .{ .register = src_regs[0] }, opts),
        .register_offset,
        .indirect,
        .load_frame,
        .lea_frame,
        => try @as(MoveStrategy, switch (src_mcv) {
            .register_offset => |reg_off| switch (reg_off.off) {
                0 => return self.genSetReg(dst_reg, ty, .{ .register = reg_off.reg }, opts),
                else => .{ .move = .{ ._, .lea } },
            },
            .indirect => try self.moveStrategy(ty, dst_reg.class(), false),
            .load_frame => |frame_addr| try self.moveStrategy(
                ty,
                dst_reg.class(),
                self.getFrameAddrAlignment(frame_addr).compare(.gte, Alignment.fromLog2Units(
                    math.log2_int_ceil(u10, @divExact(dst_reg.bitSize(), 8)),
                )),
            ),
            .lea_frame => .{ .move = .{ ._, .lea } },
            else => unreachable,
        }).read(self, registerAlias(dst_reg, abi_size), switch (src_mcv) {
            .register_offset, .indirect => |reg_off| .{
                .base = .{ .reg = reg_off.reg },
                .mod = .{ .rm = .{
                    .size = self.memSize(ty),
                    .disp = reg_off.off,
                } },
            },
            .load_frame, .lea_frame => |frame_addr| .{
                .base = .{ .frame = frame_addr.index },
                .mod = .{ .rm = .{
                    .size = self.memSize(ty),
                    .disp = frame_addr.off,
                } },
            },
            else => unreachable,
        }),
        .memory, .load_symbol, .load_direct, .load_got, .load_tlv => {
            switch (src_mcv) {
                .memory => |addr| if (math.cast(i32, @as(i64, @bitCast(addr)))) |small_addr|
                    return (try self.moveStrategy(
                        ty,
                        dst_reg.class(),
                        ty.abiAlignment(zcu).check(@as(u32, @bitCast(small_addr))),
                    )).read(self, registerAlias(dst_reg, abi_size), .{
                        .base = .{ .reg = .ds },
                        .mod = .{ .rm = .{
                            .size = self.memSize(ty),
                            .disp = small_addr,
                        } },
                    }),
                .load_symbol => |sym_off| switch (dst_reg.class()) {
                    .general_purpose => {
                        assert(sym_off.off == 0);
                        try self.asmRegisterMemory(.{ ._, .mov }, registerAlias(dst_reg, abi_size), .{
                            .base = .{ .reloc = sym_off.sym_index },
                            .mod = .{ .rm = .{
                                .size = self.memSize(ty),
                                .disp = sym_off.off,
                            } },
                        });
                        return;
                    },
                    .segment, .mmx, .ip => unreachable,
                    .x87, .sse => {},
                },
                .load_direct => |sym_index| switch (dst_reg.class()) {
                    .general_purpose => {
                        _ = try self.addInst(.{
                            .tag = .mov,
                            .ops = .direct_reloc,
                            .data = .{ .rx = .{
                                .r1 = registerAlias(dst_reg, abi_size),
                                .payload = try self.addExtra(bits.SymbolOffset{ .sym_index = sym_index }),
                            } },
                        });
                        return;
                    },
                    .segment, .mmx, .ip => unreachable,
                    .x87, .sse => {},
                },
                .load_got, .load_tlv => {},
                else => unreachable,
            }

            const addr_reg = try self.copyToTmpRegister(Type.usize, src_mcv.address());
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try (try self.moveStrategy(ty, dst_reg.class(), false)).read(
                self,
                registerAlias(dst_reg, abi_size),
                .{
                    .base = .{ .reg = addr_reg },
                    .mod = .{ .rm = .{ .size = self.memSize(ty) } },
                },
            );
        },
        .lea_symbol => |sym_off| switch (self.bin_file.tag) {
            .elf, .macho => try self.asmRegisterMemory(
                .{ ._, .lea },
                dst_reg.to64(),
                .{
                    .base = .{ .reloc = sym_off.sym_index },
                    .mod = .{ .rm = .{
                        .size = .qword,
                        .disp = sym_off.off,
                    } },
                },
            ),
            else => return self.fail("TODO emit symbol sequence on {s}", .{
                @tagName(self.bin_file.tag),
            }),
        },
        .lea_direct, .lea_got => |sym_index| _ = try self.addInst(.{
            .tag = switch (src_mcv) {
                .lea_direct => .lea,
                .lea_got => .mov,
                else => unreachable,
            },
            .ops = switch (src_mcv) {
                .lea_direct => .direct_reloc,
                .lea_got => .got_reloc,
                else => unreachable,
            },
            .data = .{ .rx = .{
                .r1 = dst_reg.to64(),
                .payload = try self.addExtra(bits.SymbolOffset{ .sym_index = sym_index }),
            } },
        }),
        .lea_tlv => unreachable, // TODO: remove this
        .air_ref => |src_ref| try self.genSetReg(dst_reg, ty, try self.resolveInst(src_ref), opts),
    }
}

fn genSetMem(
    self: *Self,
    base: Memory.Base,
    disp: i32,
    ty: Type,
    src_mcv: MCValue,
    opts: CopyOptions,
) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size: u32 = @intCast(ty.abiSize(zcu));
    const dst_ptr_mcv: MCValue = switch (base) {
        .none => .{ .immediate = @bitCast(@as(i64, disp)) },
        .reg => |base_reg| .{ .register_offset = .{ .reg = base_reg, .off = disp } },
        .frame => |base_frame_index| .{ .lea_frame = .{ .index = base_frame_index, .off = disp } },
        .reloc => |sym_index| .{ .lea_symbol = .{ .sym_index = sym_index, .off = disp } },
    };
    switch (src_mcv) {
        .none,
        .unreach,
        .dead,
        .elementwise_regs_then_frame,
        .reserved_frame,
        => unreachable,
        .undef => if (opts.safety) try self.genInlineMemset(
            dst_ptr_mcv,
            src_mcv,
            .{ .immediate = abi_size },
            opts,
        ),
        .immediate => |imm| switch (abi_size) {
            1, 2, 4 => {
                const immediate = switch (if (ty.isAbiInt(zcu))
                    ty.intInfo(zcu).signedness
                else
                    .unsigned) {
                    .signed => Immediate.s(@truncate(@as(i64, @bitCast(imm)))),
                    .unsigned => Immediate.u(@as(u32, @intCast(imm))),
                };
                try self.asmMemoryImmediate(
                    .{ ._, .mov },
                    .{ .base = base, .mod = .{ .rm = .{
                        .size = Memory.Size.fromSize(abi_size),
                        .disp = disp,
                    } } },
                    immediate,
                );
            },
            3, 5...7 => unreachable,
            else => if (math.cast(i32, @as(i64, @bitCast(imm)))) |small| {
                try self.asmMemoryImmediate(
                    .{ ._, .mov },
                    .{ .base = base, .mod = .{ .rm = .{
                        .size = Memory.Size.fromSize(abi_size),
                        .disp = disp,
                    } } },
                    Immediate.s(small),
                );
            } else {
                var offset: i32 = 0;
                while (offset < abi_size) : (offset += 4) try self.asmMemoryImmediate(
                    .{ ._, .mov },
                    .{ .base = base, .mod = .{ .rm = .{
                        .size = .dword,
                        .disp = disp + offset,
                    } } },
                    if (ty.isSignedInt(zcu)) Immediate.s(
                        @truncate(@as(i64, @bitCast(imm)) >> (math.cast(u6, offset * 8) orelse 63)),
                    ) else Immediate.u(
                        @as(u32, @truncate(if (math.cast(u6, offset * 8)) |shift| imm >> shift else 0)),
                    ),
                );
            },
        },
        .eflags => |cc| try self.asmSetccMemory(cc, .{ .base = base, .mod = .{
            .rm = .{ .size = .byte, .disp = disp },
        } }),
        .register => |src_reg| {
            const mem_size = switch (base) {
                .frame => |base_fi| mem_size: {
                    assert(disp >= 0);
                    const frame_abi_size = self.frame_allocs.items(.abi_size)[@intFromEnum(base_fi)];
                    const frame_spill_pad = self.frame_allocs.items(.spill_pad)[@intFromEnum(base_fi)];
                    assert(frame_abi_size - frame_spill_pad - disp >= abi_size);
                    break :mem_size if (frame_abi_size - frame_spill_pad - disp == abi_size)
                        frame_abi_size
                    else
                        abi_size;
                },
                else => abi_size,
            };
            const src_alias = registerAlias(src_reg, abi_size);
            const src_size: u32 = @intCast(switch (src_alias.class()) {
                .general_purpose, .segment, .x87, .ip => @divExact(src_alias.bitSize(), 8),
                .mmx, .sse => abi_size,
            });
            const src_align = Alignment.fromNonzeroByteUnits(math.ceilPowerOfTwoAssert(u32, src_size));
            if (src_size > mem_size) {
                const frame_index = try self.allocFrameIndex(FrameAlloc.init(.{
                    .size = src_size,
                    .alignment = src_align,
                }));
                const frame_mcv: MCValue = .{ .load_frame = .{ .index = frame_index } };
                try (try self.moveStrategy(ty, src_alias.class(), true)).write(
                    self,
                    .{ .base = .{ .frame = frame_index }, .mod = .{ .rm = .{
                        .size = Memory.Size.fromSize(src_size),
                    } } },
                    src_alias,
                );
                try self.genSetMem(base, disp, ty, frame_mcv, opts);
                try self.freeValue(frame_mcv);
            } else try (try self.moveStrategy(ty, src_alias.class(), switch (base) {
                .none => src_align.check(@as(u32, @bitCast(disp))),
                .reg => |reg| switch (reg) {
                    .es, .cs, .ss, .ds => src_align.check(@as(u32, @bitCast(disp))),
                    else => false,
                },
                .frame => |frame_index| self.getFrameAddrAlignment(.{
                    .index = frame_index,
                    .off = disp,
                }).compare(.gte, src_align),
                .reloc => false,
            })).write(
                self,
                .{ .base = base, .mod = .{ .rm = .{
                    .size = Memory.Size.fromBitSize(@min(self.memSize(ty).bitSize(), src_alias.bitSize())),
                    .disp = disp,
                } } },
                src_alias,
            );
        },
        .register_pair => |src_regs| {
            var part_disp: i32 = disp;
            for (try self.splitType(ty), src_regs) |src_ty, src_reg| {
                try self.genSetMem(base, part_disp, src_ty, .{ .register = src_reg }, opts);
                part_disp += @intCast(src_ty.abiSize(zcu));
            }
        },
        .register_overflow => |ro| switch (ty.zigTypeTag(zcu)) {
            .@"struct" => {
                try self.genSetMem(
                    base,
                    disp + @as(i32, @intCast(ty.structFieldOffset(0, zcu))),
                    ty.fieldType(0, zcu),
                    .{ .register = ro.reg },
                    opts,
                );
                try self.genSetMem(
                    base,
                    disp + @as(i32, @intCast(ty.structFieldOffset(1, zcu))),
                    ty.fieldType(1, zcu),
                    .{ .eflags = ro.eflags },
                    opts,
                );
            },
            .optional => {
                assert(!ty.optionalReprIsPayload(zcu));
                const child_ty = ty.optionalChild(zcu);
                try self.genSetMem(base, disp, child_ty, .{ .register = ro.reg }, opts);
                try self.genSetMem(
                    base,
                    disp + @as(i32, @intCast(child_ty.abiSize(zcu))),
                    Type.bool,
                    .{ .eflags = ro.eflags },
                    opts,
                );
            },
            else => return self.fail("TODO implement genSetMem for {s} of {}", .{
                @tagName(src_mcv), ty.fmt(pt),
            }),
        },
        .register_offset => |reg_off| {
            const src_reg = self.copyToTmpRegister(ty, src_mcv) catch |err| switch (err) {
                error.OutOfRegisters => {
                    const src_reg = registerAlias(reg_off.reg, abi_size);
                    try self.asmRegisterMemory(.{ ._, .lea }, src_reg, .{
                        .base = .{ .reg = src_reg },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .disp = reg_off.off,
                        } },
                    });
                    try self.genSetMem(base, disp, ty, .{ .register = reg_off.reg }, opts);
                    return self.asmRegisterMemory(.{ ._, .lea }, src_reg, .{
                        .base = .{ .reg = src_reg },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .disp = -reg_off.off,
                        } },
                    });
                },
                else => |e| return e,
            };
            const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
            defer self.register_manager.unlockReg(src_lock);

            try self.genSetMem(base, disp, ty, .{ .register = src_reg }, opts);
        },
        .memory,
        .indirect,
        .load_direct,
        .lea_direct,
        .load_got,
        .lea_got,
        .load_tlv,
        .lea_tlv,
        .load_frame,
        .lea_frame,
        .load_symbol,
        .lea_symbol,
        => switch (abi_size) {
            0 => {},
            1, 2, 4, 8 => {
                const src_reg = try self.copyToTmpRegister(ty, src_mcv);
                const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
                defer self.register_manager.unlockReg(src_lock);

                try self.genSetMem(base, disp, ty, .{ .register = src_reg }, opts);
            },
            else => try self.genInlineMemcpy(
                dst_ptr_mcv,
                src_mcv.address(),
                .{ .immediate = abi_size },
            ),
        },
        .air_ref => |src_ref| try self.genSetMem(base, disp, ty, try self.resolveInst(src_ref), opts),
    }
}

fn genInlineMemcpy(self: *Self, dst_ptr: MCValue, src_ptr: MCValue, len: MCValue) InnerError!void {
    try self.spillRegisters(&.{ .rsi, .rdi, .rcx });
    try self.genSetReg(.rsi, Type.usize, src_ptr, .{});
    try self.genSetReg(.rdi, Type.usize, dst_ptr, .{});
    try self.genSetReg(.rcx, Type.usize, len, .{});
    try self.asmOpOnly(.{ .@"rep _sb", .mov });
}

fn genInlineMemset(
    self: *Self,
    dst_ptr: MCValue,
    value: MCValue,
    len: MCValue,
    opts: CopyOptions,
) InnerError!void {
    try self.spillRegisters(&.{ .rdi, .al, .rcx });
    try self.genSetReg(.rdi, Type.usize, dst_ptr, .{});
    try self.genSetReg(.al, Type.u8, value, opts);
    try self.genSetReg(.rcx, Type.usize, len, .{});
    try self.asmOpOnly(.{ .@"rep _sb", .sto });
}

fn genExternSymbolRef(
    self: *Self,
    comptime tag: Mir.Inst.Tag,
    lib: ?[]const u8,
    callee: []const u8,
) InnerError!void {
    if (self.bin_file.cast(.coff)) |coff_file| {
        const global_index = try coff_file.getGlobalSymbol(callee, lib);
        _ = try self.addInst(.{
            .tag = .mov,
            .ops = .import_reloc,
            .data = .{ .rx = .{
                .r1 = .rax,
                .payload = try self.addExtra(bits.SymbolOffset{
                    .sym_index = link.File.Coff.global_symbol_bit | global_index,
                }),
            } },
        });
        switch (tag) {
            .mov => {},
            .call => try self.asmRegister(.{ ._, .call }, .rax),
            else => unreachable,
        }
    } else return self.fail("TODO implement calling extern functions", .{});
}

fn genLazySymbolRef(
    self: *Self,
    comptime tag: Mir.Inst.Tag,
    reg: Register,
    lazy_sym: link.File.LazySymbol,
) InnerError!void {
    const pt = self.pt;
    if (self.bin_file.cast(.elf)) |elf_file| {
        const zo = elf_file.zigObjectPtr().?;
        const sym_index = zo.getOrCreateMetadataForLazySymbol(elf_file, pt, lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        if (self.mod.pic) {
            switch (tag) {
                .lea, .call => try self.genSetReg(reg, Type.usize, .{
                    .lea_symbol = .{ .sym_index = sym_index },
                }, .{}),
                .mov => try self.genSetReg(reg, Type.usize, .{
                    .load_symbol = .{ .sym_index = sym_index },
                }, .{}),
                else => unreachable,
            }
            switch (tag) {
                .lea, .mov => {},
                .call => try self.asmRegister(.{ ._, .call }, reg),
                else => unreachable,
            }
        } else switch (tag) {
            .lea, .mov => try self.asmRegisterMemory(.{ ._, tag }, reg.to64(), .{
                .base = .{ .reloc = sym_index },
                .mod = .{ .rm = .{ .size = .qword } },
            }),
            .call => try self.asmImmediate(.{ ._, .call }, Immediate.rel(.{ .sym_index = sym_index })),
            else => unreachable,
        }
    } else if (self.bin_file.cast(.plan9)) |p9_file| {
        const atom_index = p9_file.getOrCreateAtomForLazySymbol(pt, lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        var atom = p9_file.getAtom(atom_index);
        _ = atom.getOrCreateOffsetTableEntry(p9_file);
        const got_addr = atom.getOffsetTableAddress(p9_file);
        const got_mem: Memory = .{
            .base = .{ .reg = .ds },
            .mod = .{ .rm = .{
                .size = .qword,
                .disp = @intCast(got_addr),
            } },
        };
        switch (tag) {
            .lea, .mov => try self.asmRegisterMemory(.{ ._, .mov }, reg.to64(), got_mem),
            .call => try self.asmMemory(.{ ._, .call }, got_mem),
            else => unreachable,
        }
        switch (tag) {
            .lea, .call => {},
            .mov => try self.asmRegisterMemory(
                .{ ._, tag },
                reg.to64(),
                Memory.initSib(.qword, .{ .base = .{ .reg = reg.to64() } }),
            ),
            else => unreachable,
        }
    } else if (self.bin_file.cast(.coff)) |coff_file| {
        const atom_index = coff_file.getOrCreateAtomForLazySymbol(pt, lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
        switch (tag) {
            .lea, .call => try self.genSetReg(reg, Type.usize, .{ .lea_got = sym_index }, .{}),
            .mov => try self.genSetReg(reg, Type.usize, .{ .load_got = sym_index }, .{}),
            else => unreachable,
        }
        switch (tag) {
            .lea, .mov => {},
            .call => try self.asmRegister(.{ ._, .call }, reg),
            else => unreachable,
        }
    } else if (self.bin_file.cast(.macho)) |macho_file| {
        const zo = macho_file.getZigObject().?;
        const sym_index = zo.getOrCreateMetadataForLazySymbol(macho_file, pt, lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        const sym = zo.symbols.items[sym_index];
        switch (tag) {
            .lea, .call => try self.genSetReg(reg, Type.usize, .{
                .lea_symbol = .{ .sym_index = sym.nlist_idx },
            }, .{}),
            .mov => try self.genSetReg(reg, Type.usize, .{
                .load_symbol = .{ .sym_index = sym.nlist_idx },
            }, .{}),
            else => unreachable,
        }
        switch (tag) {
            .lea, .mov => {},
            .call => try self.asmRegister(.{ ._, .call }, reg),
            else => unreachable,
        }
    } else {
        return self.fail("TODO implement genLazySymbol for x86_64 {s}", .{@tagName(self.bin_file.tag)});
    }
}

fn airIntFromPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result = result: {
        // TODO: handle case where the operand is a slice not a raw pointer
        const src_mcv = try self.resolveInst(un_op);
        if (self.reuseOperand(inst, un_op, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.typeOfIndex(inst);
        try self.genCopy(dst_ty, dst_mcv, src_mcv, .{});
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airBitCast(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const dst_ty = self.typeOfIndex(inst);
    const src_ty = self.typeOf(ty_op.operand);

    const result = result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        if (dst_ty.isPtrAtRuntime(zcu) and src_ty.isPtrAtRuntime(zcu)) switch (src_mcv) {
            .lea_frame => break :result src_mcv,
            else => if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv,
        };

        const dst_rc = self.regClassForType(dst_ty);
        const src_rc = self.regClassForType(src_ty);

        const src_lock = if (src_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
        defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mcv = if (dst_rc.supersetOf(src_rc) and dst_ty.abiSize(zcu) <= src_ty.abiSize(zcu) and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) src_mcv else dst: {
            const dst_mcv = try self.allocRegOrMem(inst, true);
            try self.genCopy(switch (math.order(dst_ty.abiSize(zcu), src_ty.abiSize(zcu))) {
                .lt => dst_ty,
                .eq => if (!dst_mcv.isMemory() or src_mcv.isMemory()) dst_ty else src_ty,
                .gt => src_ty,
            }, dst_mcv, src_mcv, .{});
            break :dst dst_mcv;
        };

        if (dst_ty.isRuntimeFloat()) break :result dst_mcv;

        if (dst_ty.isAbiInt(zcu) and src_ty.isAbiInt(zcu) and
            dst_ty.intInfo(zcu).signedness == src_ty.intInfo(zcu).signedness) break :result dst_mcv;

        const abi_size = dst_ty.abiSize(zcu);
        const bit_size = dst_ty.bitSize(zcu);
        if (abi_size * 8 <= bit_size or dst_ty.isVector(zcu)) break :result dst_mcv;

        const dst_limbs_len = math.divCeil(i32, @intCast(bit_size), 64) catch unreachable;
        const high_mcv: MCValue = switch (dst_mcv) {
            .register => |dst_reg| .{ .register = dst_reg },
            .register_pair => |dst_regs| .{ .register = dst_regs[1] },
            else => dst_mcv.address().offset((dst_limbs_len - 1) * 8).deref(),
        };
        const high_reg = if (high_mcv.isRegister())
            high_mcv.getReg().?
        else
            try self.copyToTmpRegister(Type.usize, high_mcv);
        const high_lock = self.register_manager.lockReg(high_reg);
        defer if (high_lock) |lock| self.register_manager.unlockReg(lock);

        try self.truncateRegister(dst_ty, high_reg);
        if (!high_mcv.isRegister()) try self.genCopy(
            if (abi_size <= 8) dst_ty else Type.usize,
            high_mcv,
            .{ .register = high_reg },
            .{},
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const slice_ty = self.typeOfIndex(inst);
    const ptr_ty = self.typeOf(ty_op.operand);
    const ptr = try self.resolveInst(ty_op.operand);
    const array_ty = ptr_ty.childType(zcu);
    const array_len = array_ty.arrayLen(zcu);

    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(slice_ty, zcu));
    try self.genSetMem(.{ .frame = frame_index }, 0, ptr_ty, ptr, .{});
    try self.genSetMem(
        .{ .frame = frame_index },
        @intCast(ptr_ty.abiSize(zcu)),
        Type.usize,
        .{ .immediate = array_len },
        .{},
    );

    const result = MCValue{ .load_frame = .{ .index = frame_index } };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFloatFromInt(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const dst_ty = self.typeOfIndex(inst);
    const dst_bits = dst_ty.floatBits(self.target.*);

    const src_ty = self.typeOf(ty_op.operand);
    const src_bits: u32 = @intCast(src_ty.bitSize(zcu));
    const src_signedness =
        if (src_ty.isAbiInt(zcu)) src_ty.intInfo(zcu).signedness else .unsigned;
    const src_size = math.divCeil(u32, @max(switch (src_signedness) {
        .signed => src_bits,
        .unsigned => src_bits + 1,
    }, 32), 8) catch unreachable;

    const result = result: {
        if (switch (dst_bits) {
            16, 80, 128 => true,
            32, 64 => src_size > 8,
            else => unreachable,
        }) {
            if (src_bits > 128) return self.fail("TODO implement airFloatFromInt from {} to {}", .{
                src_ty.fmt(pt), dst_ty.fmt(pt),
            });

            var callee_buf: ["__floatun?i?f".len]u8 = undefined;
            break :result try self.genCall(.{ .lib = .{
                .return_type = dst_ty.toIntern(),
                .param_types = &.{src_ty.toIntern()},
                .callee = std.fmt.bufPrint(&callee_buf, "__float{s}{c}i{c}f", .{
                    switch (src_signedness) {
                        .signed => "",
                        .unsigned => "un",
                    },
                    intCompilerRtAbiName(src_bits),
                    floatCompilerRtAbiName(dst_bits),
                }) catch unreachable,
            } }, &.{src_ty}, &.{.{ .air_ref = ty_op.operand }});
        }

        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_reg = if (src_mcv.isRegister())
            src_mcv.getReg().?
        else
            try self.copyToTmpRegister(src_ty, src_mcv);
        const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
        defer self.register_manager.unlockReg(src_lock);

        if (src_bits < src_size * 8) try self.truncateRegister(src_ty, src_reg);

        const dst_reg = try self.register_manager.allocReg(inst, self.regClassForType(dst_ty));
        const dst_mcv = MCValue{ .register = dst_reg };
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        const mir_tag = @as(?Mir.Inst.FixedTag, switch (dst_ty.zigTypeTag(zcu)) {
            .float => switch (dst_ty.floatBits(self.target.*)) {
                32 => if (self.hasFeature(.avx)) .{ .v_ss, .cvtsi2 } else .{ ._ss, .cvtsi2 },
                64 => if (self.hasFeature(.avx)) .{ .v_sd, .cvtsi2 } else .{ ._sd, .cvtsi2 },
                16, 80, 128 => null,
                else => unreachable,
            },
            else => null,
        }) orelse return self.fail("TODO implement airFloatFromInt from {} to {}", .{
            src_ty.fmt(pt), dst_ty.fmt(pt),
        });
        const dst_alias = dst_reg.to128();
        const src_alias = registerAlias(src_reg, src_size);
        switch (mir_tag[0]) {
            .v_ss, .v_sd => try self.asmRegisterRegisterRegister(mir_tag, dst_alias, dst_alias, src_alias),
            else => try self.asmRegisterRegister(mir_tag, dst_alias, src_alias),
        }

        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromFloat(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const dst_ty = self.typeOfIndex(inst);
    const dst_bits: u32 = @intCast(dst_ty.bitSize(zcu));
    const dst_signedness =
        if (dst_ty.isAbiInt(zcu)) dst_ty.intInfo(zcu).signedness else .unsigned;
    const dst_size = math.divCeil(u32, @max(switch (dst_signedness) {
        .signed => dst_bits,
        .unsigned => dst_bits + 1,
    }, 32), 8) catch unreachable;

    const src_ty = self.typeOf(ty_op.operand);
    const src_bits = src_ty.floatBits(self.target.*);

    const result = result: {
        if (switch (src_bits) {
            16, 80, 128 => true,
            32, 64 => dst_size > 8,
            else => unreachable,
        }) {
            if (dst_bits > 128) return self.fail("TODO implement airIntFromFloat from {} to {}", .{
                src_ty.fmt(pt), dst_ty.fmt(pt),
            });

            var callee_buf: ["__fixuns?f?i".len]u8 = undefined;
            break :result try self.genCall(.{ .lib = .{
                .return_type = dst_ty.toIntern(),
                .param_types = &.{src_ty.toIntern()},
                .callee = std.fmt.bufPrint(&callee_buf, "__fix{s}{c}f{c}i", .{
                    switch (dst_signedness) {
                        .signed => "",
                        .unsigned => "uns",
                    },
                    floatCompilerRtAbiName(src_bits),
                    intCompilerRtAbiName(dst_bits),
                }) catch unreachable,
            } }, &.{src_ty}, &.{.{ .air_ref = ty_op.operand }});
        }

        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_reg = if (src_mcv.isRegister())
            src_mcv.getReg().?
        else
            try self.copyToTmpRegister(src_ty, src_mcv);
        const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
        defer self.register_manager.unlockReg(src_lock);

        const dst_reg = try self.register_manager.allocReg(inst, self.regClassForType(dst_ty));
        const dst_mcv = MCValue{ .register = dst_reg };
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        try self.asmRegisterRegister(
            switch (src_bits) {
                32 => if (self.hasFeature(.avx)) .{ .v_, .cvttss2si } else .{ ._, .cvttss2si },
                64 => if (self.hasFeature(.avx)) .{ .v_, .cvttsd2si } else .{ ._, .cvttsd2si },
                else => unreachable,
            },
            registerAlias(dst_reg, dst_size),
            src_reg.to128(),
        );

        if (dst_bits < dst_size * 8) try self.truncateRegister(dst_ty, dst_reg);

        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCmpxchg(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Cmpxchg, ty_pl.payload).data;

    const ptr_ty = self.typeOf(extra.ptr);
    const val_ty = self.typeOf(extra.expected_value);
    const val_abi_size: u32 = @intCast(val_ty.abiSize(pt.zcu));

    try self.spillRegisters(&.{ .rax, .rdx, .rbx, .rcx });
    const regs_lock = self.register_manager.lockRegsAssumeUnused(4, .{ .rax, .rdx, .rbx, .rcx });
    defer for (regs_lock) |lock| self.register_manager.unlockReg(lock);

    const exp_mcv = try self.resolveInst(extra.expected_value);
    if (val_abi_size > 8) {
        const exp_addr_mcv: MCValue = switch (exp_mcv) {
            .memory, .indirect, .load_frame => exp_mcv.address(),
            else => .{ .register = try self.copyToTmpRegister(Type.usize, exp_mcv.address()) },
        };
        const exp_addr_lock =
            if (exp_addr_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
        defer if (exp_addr_lock) |lock| self.register_manager.unlockReg(lock);

        try self.genSetReg(.rax, Type.usize, exp_addr_mcv.deref(), .{});
        try self.genSetReg(.rdx, Type.usize, exp_addr_mcv.offset(8).deref(), .{});
    } else try self.genSetReg(.rax, val_ty, exp_mcv, .{});

    const new_mcv = try self.resolveInst(extra.new_value);
    const new_reg = if (val_abi_size > 8) new: {
        const new_addr_mcv: MCValue = switch (new_mcv) {
            .memory, .indirect, .load_frame => new_mcv.address(),
            else => .{ .register = try self.copyToTmpRegister(Type.usize, new_mcv.address()) },
        };
        const new_addr_lock =
            if (new_addr_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
        defer if (new_addr_lock) |lock| self.register_manager.unlockReg(lock);

        try self.genSetReg(.rbx, Type.usize, new_addr_mcv.deref(), .{});
        try self.genSetReg(.rcx, Type.usize, new_addr_mcv.offset(8).deref(), .{});
        break :new null;
    } else try self.copyToTmpRegister(val_ty, new_mcv);
    const new_lock = if (new_reg) |reg| self.register_manager.lockRegAssumeUnused(reg) else null;
    defer if (new_lock) |lock| self.register_manager.unlockReg(lock);

    const ptr_mcv = try self.resolveInst(extra.ptr);
    const mem_size = Memory.Size.fromSize(val_abi_size);
    const ptr_mem: Memory = switch (ptr_mcv) {
        .immediate, .register, .register_offset, .lea_frame => try ptr_mcv.deref().mem(self, mem_size),
        else => .{
            .base = .{ .reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv) },
            .mod = .{ .rm = .{ .size = mem_size } },
        },
    };
    switch (ptr_mem.mod) {
        .rm => {},
        .off => return self.fail("TODO airCmpxchg with {s}", .{@tagName(ptr_mcv)}),
    }
    const ptr_lock = switch (ptr_mem.base) {
        .none, .frame, .reloc => null,
        .reg => |reg| self.register_manager.lockReg(reg),
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    try self.spillEflagsIfOccupied();
    if (val_abi_size <= 8) try self.asmMemoryRegister(
        .{ .@"lock _", .cmpxchg },
        ptr_mem,
        registerAlias(new_reg.?, val_abi_size),
    ) else try self.asmMemory(.{ .@"lock _16b", .cmpxchg }, ptr_mem);

    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .unreach;

        if (val_abi_size <= 8) {
            self.eflags_inst = inst;
            break :result .{ .register_overflow = .{ .reg = .rax, .eflags = .ne } };
        }

        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.genCopy(Type.usize, dst_mcv, .{ .register = .rax }, .{});
        try self.genCopy(Type.usize, dst_mcv.address().offset(8).deref(), .{ .register = .rdx }, .{});
        try self.genCopy(Type.bool, dst_mcv.address().offset(16).deref(), .{ .eflags = .ne }, .{});
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ extra.ptr, extra.expected_value, extra.new_value });
}

fn atomicOp(
    self: *Self,
    ptr_mcv: MCValue,
    val_mcv: MCValue,
    ptr_ty: Type,
    val_ty: Type,
    unused: bool,
    rmw_op: ?std.builtin.AtomicRmwOp,
    order: std.builtin.AtomicOrder,
) InnerError!MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ptr_lock = switch (ptr_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const val_lock = switch (val_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (val_lock) |lock| self.register_manager.unlockReg(lock);

    const val_abi_size: u32 = @intCast(val_ty.abiSize(zcu));
    const mem_size = Memory.Size.fromSize(val_abi_size);
    const ptr_mem: Memory = switch (ptr_mcv) {
        .immediate, .register, .register_offset, .lea_frame => try ptr_mcv.deref().mem(self, mem_size),
        else => .{
            .base = .{ .reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv) },
            .mod = .{ .rm = .{ .size = mem_size } },
        },
    };
    switch (ptr_mem.mod) {
        .rm => {},
        .off => return self.fail("TODO airCmpxchg with {s}", .{@tagName(ptr_mcv)}),
    }
    const mem_lock = switch (ptr_mem.base) {
        .none, .frame, .reloc => null,
        .reg => |reg| self.register_manager.lockReg(reg),
    };
    defer if (mem_lock) |lock| self.register_manager.unlockReg(lock);

    const use_sse = rmw_op orelse .Xchg != .Xchg and val_ty.isRuntimeFloat();
    const strat: enum { lock, loop, libcall } = if (use_sse) .loop else switch (rmw_op orelse .Xchg) {
        .Xchg,
        .Add,
        .Sub,
        => if (val_abi_size <= 8) .lock else if (val_abi_size <= 16) .loop else .libcall,
        .And,
        .Or,
        .Xor,
        => if (val_abi_size <= 8 and unused) .lock else if (val_abi_size <= 16) .loop else .libcall,
        .Nand,
        .Max,
        .Min,
        => if (val_abi_size <= 16) .loop else .libcall,
    };
    switch (strat) {
        .lock => {
            const tag: Mir.Inst.Tag = if (rmw_op) |op| switch (op) {
                .Xchg => if (unused) .mov else .xchg,
                .Add => if (unused) .add else .xadd,
                .Sub => if (unused) .sub else .xadd,
                .And => .@"and",
                .Or => .@"or",
                .Xor => .xor,
                else => unreachable,
            } else switch (order) {
                .unordered, .monotonic, .release, .acq_rel => .mov,
                .acquire => unreachable,
                .seq_cst => .xchg,
            };

            const dst_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const dst_mcv = MCValue{ .register = dst_reg };
            const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
            defer self.register_manager.unlockReg(dst_lock);

            try self.genSetReg(dst_reg, val_ty, val_mcv, .{});
            if (rmw_op == std.builtin.AtomicRmwOp.Sub and tag == .xadd) {
                try self.genUnOpMir(.{ ._, .neg }, val_ty, dst_mcv);
            }
            try self.asmMemoryRegister(
                switch (tag) {
                    .mov, .xchg => .{ ._, tag },
                    .xadd, .add, .sub, .@"and", .@"or", .xor => .{ .@"lock _", tag },
                    else => unreachable,
                },
                ptr_mem,
                registerAlias(dst_reg, val_abi_size),
            );

            return if (unused) .unreach else dst_mcv;
        },
        .loop => _ = if (val_abi_size <= 8) {
            const sse_reg: Register = if (use_sse)
                try self.register_manager.allocReg(null, abi.RegisterClass.sse)
            else
                undefined;
            const sse_lock =
                if (use_sse) self.register_manager.lockRegAssumeUnused(sse_reg) else undefined;
            defer if (use_sse) self.register_manager.unlockReg(sse_lock);

            const tmp_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.asmRegisterMemory(.{ ._, .mov }, registerAlias(.rax, val_abi_size), ptr_mem);
            const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
            if (!use_sse and rmw_op orelse .Xchg != .Xchg) {
                try self.genSetReg(tmp_reg, val_ty, .{ .register = .rax }, .{});
            }
            if (rmw_op) |op| if (use_sse) {
                const mir_tag = @as(?Mir.Inst.FixedTag, switch (op) {
                    .Add => switch (val_ty.floatBits(self.target.*)) {
                        32 => if (self.hasFeature(.avx)) .{ .v_ss, .add } else .{ ._ss, .add },
                        64 => if (self.hasFeature(.avx)) .{ .v_sd, .add } else .{ ._sd, .add },
                        else => null,
                    },
                    .Sub => switch (val_ty.floatBits(self.target.*)) {
                        32 => if (self.hasFeature(.avx)) .{ .v_ss, .sub } else .{ ._ss, .sub },
                        64 => if (self.hasFeature(.avx)) .{ .v_sd, .sub } else .{ ._sd, .sub },
                        else => null,
                    },
                    .Min => switch (val_ty.floatBits(self.target.*)) {
                        32 => if (self.hasFeature(.avx)) .{ .v_ss, .min } else .{ ._ss, .min },
                        64 => if (self.hasFeature(.avx)) .{ .v_sd, .min } else .{ ._sd, .min },
                        else => null,
                    },
                    .Max => switch (val_ty.floatBits(self.target.*)) {
                        32 => if (self.hasFeature(.avx)) .{ .v_ss, .max } else .{ ._ss, .max },
                        64 => if (self.hasFeature(.avx)) .{ .v_sd, .max } else .{ ._sd, .max },
                        else => null,
                    },
                    else => unreachable,
                }) orelse return self.fail("TODO implement atomicOp of {s} for {}", .{
                    @tagName(op), val_ty.fmt(pt),
                });
                try self.genSetReg(sse_reg, val_ty, .{ .register = .rax }, .{});
                switch (mir_tag[0]) {
                    .v_ss, .v_sd => if (val_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                        mir_tag,
                        sse_reg.to128(),
                        sse_reg.to128(),
                        try val_mcv.mem(self, self.memSize(val_ty)),
                    ) else try self.asmRegisterRegisterRegister(
                        mir_tag,
                        sse_reg.to128(),
                        sse_reg.to128(),
                        (if (val_mcv.isRegister())
                            val_mcv.getReg().?
                        else
                            try self.copyToTmpRegister(val_ty, val_mcv)).to128(),
                    ),
                    ._ss, ._sd => if (val_mcv.isMemory()) try self.asmRegisterMemory(
                        mir_tag,
                        sse_reg.to128(),
                        try val_mcv.mem(self, self.memSize(val_ty)),
                    ) else try self.asmRegisterRegister(
                        mir_tag,
                        sse_reg.to128(),
                        (if (val_mcv.isRegister())
                            val_mcv.getReg().?
                        else
                            try self.copyToTmpRegister(val_ty, val_mcv)).to128(),
                    ),
                    else => unreachable,
                }
                try self.genSetReg(tmp_reg, val_ty, .{ .register = sse_reg }, .{});
            } else switch (op) {
                .Xchg => try self.genSetReg(tmp_reg, val_ty, val_mcv, .{}),
                .Add => try self.genBinOpMir(.{ ._, .add }, val_ty, tmp_mcv, val_mcv),
                .Sub => try self.genBinOpMir(.{ ._, .sub }, val_ty, tmp_mcv, val_mcv),
                .And => try self.genBinOpMir(.{ ._, .@"and" }, val_ty, tmp_mcv, val_mcv),
                .Nand => {
                    try self.genBinOpMir(.{ ._, .@"and" }, val_ty, tmp_mcv, val_mcv);
                    try self.genUnOpMir(.{ ._, .not }, val_ty, tmp_mcv);
                },
                .Or => try self.genBinOpMir(.{ ._, .@"or" }, val_ty, tmp_mcv, val_mcv),
                .Xor => try self.genBinOpMir(.{ ._, .xor }, val_ty, tmp_mcv, val_mcv),
                .Min, .Max => {
                    const cc: Condition = switch (if (val_ty.isAbiInt(zcu))
                        val_ty.intInfo(zcu).signedness
                    else
                        .unsigned) {
                        .unsigned => switch (op) {
                            .Min => .a,
                            .Max => .b,
                            else => unreachable,
                        },
                        .signed => switch (op) {
                            .Min => .g,
                            .Max => .l,
                            else => unreachable,
                        },
                    };

                    const cmov_abi_size = @max(val_abi_size, 2);
                    switch (val_mcv) {
                        .register => |val_reg| {
                            try self.genBinOpMir(.{ ._, .cmp }, val_ty, tmp_mcv, val_mcv);
                            try self.asmCmovccRegisterRegister(
                                cc,
                                registerAlias(tmp_reg, cmov_abi_size),
                                registerAlias(val_reg, cmov_abi_size),
                            );
                        },
                        .memory, .indirect, .load_frame => {
                            try self.genBinOpMir(.{ ._, .cmp }, val_ty, tmp_mcv, val_mcv);
                            try self.asmCmovccRegisterMemory(
                                cc,
                                registerAlias(tmp_reg, cmov_abi_size),
                                try val_mcv.mem(self, Memory.Size.fromSize(cmov_abi_size)),
                            );
                        },
                        else => {
                            const mat_reg = try self.copyToTmpRegister(val_ty, val_mcv);
                            const mat_lock = self.register_manager.lockRegAssumeUnused(mat_reg);
                            defer self.register_manager.unlockReg(mat_lock);

                            try self.genBinOpMir(
                                .{ ._, .cmp },
                                val_ty,
                                tmp_mcv,
                                .{ .register = mat_reg },
                            );
                            try self.asmCmovccRegisterRegister(
                                cc,
                                registerAlias(tmp_reg, cmov_abi_size),
                                registerAlias(mat_reg, cmov_abi_size),
                            );
                        },
                    }
                },
            };
            try self.asmMemoryRegister(
                .{ .@"lock _", .cmpxchg },
                ptr_mem,
                registerAlias(tmp_reg, val_abi_size),
            );
            _ = try self.asmJccReloc(.ne, loop);
            return if (unused) .unreach else .{ .register = .rax };
        } else {
            try self.asmRegisterMemory(.{ ._, .mov }, .rax, .{
                .base = ptr_mem.base,
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = ptr_mem.mod.rm.index,
                    .scale = ptr_mem.mod.rm.scale,
                    .disp = ptr_mem.mod.rm.disp + 0,
                } },
            });
            try self.asmRegisterMemory(.{ ._, .mov }, .rdx, .{
                .base = ptr_mem.base,
                .mod = .{ .rm = .{
                    .size = .qword,
                    .index = ptr_mem.mod.rm.index,
                    .scale = ptr_mem.mod.rm.scale,
                    .disp = ptr_mem.mod.rm.disp + 8,
                } },
            });
            const loop: Mir.Inst.Index = @intCast(self.mir_instructions.len);
            const val_mem_mcv: MCValue = switch (val_mcv) {
                .memory, .indirect, .load_frame => val_mcv,
                else => .{ .indirect = .{
                    .reg = try self.copyToTmpRegister(Type.usize, val_mcv.address()),
                } },
            };
            const val_lo_mem = try val_mem_mcv.mem(self, .qword);
            const val_hi_mem = try val_mem_mcv.address().offset(8).deref().mem(self, .qword);
            if (rmw_op != std.builtin.AtomicRmwOp.Xchg) {
                try self.asmRegisterRegister(.{ ._, .mov }, .rbx, .rax);
                try self.asmRegisterRegister(.{ ._, .mov }, .rcx, .rdx);
            }
            if (rmw_op) |op| switch (op) {
                .Xchg => {
                    try self.asmRegisterMemory(.{ ._, .mov }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .mov }, .rcx, val_hi_mem);
                },
                .Add => {
                    try self.asmRegisterMemory(.{ ._, .add }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .adc }, .rcx, val_hi_mem);
                },
                .Sub => {
                    try self.asmRegisterMemory(.{ ._, .sub }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .sbb }, .rcx, val_hi_mem);
                },
                .And => {
                    try self.asmRegisterMemory(.{ ._, .@"and" }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .@"and" }, .rcx, val_hi_mem);
                },
                .Nand => {
                    try self.asmRegisterMemory(.{ ._, .@"and" }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .@"and" }, .rcx, val_hi_mem);
                    try self.asmRegister(.{ ._, .not }, .rbx);
                    try self.asmRegister(.{ ._, .not }, .rcx);
                },
                .Or => {
                    try self.asmRegisterMemory(.{ ._, .@"or" }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .@"or" }, .rcx, val_hi_mem);
                },
                .Xor => {
                    try self.asmRegisterMemory(.{ ._, .xor }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .xor }, .rcx, val_hi_mem);
                },
                .Min, .Max => {
                    const cc: Condition = switch (if (val_ty.isAbiInt(zcu))
                        val_ty.intInfo(zcu).signedness
                    else
                        .unsigned) {
                        .unsigned => switch (op) {
                            .Min => .a,
                            .Max => .b,
                            else => unreachable,
                        },
                        .signed => switch (op) {
                            .Min => .g,
                            .Max => .l,
                            else => unreachable,
                        },
                    };

                    const tmp_reg = try self.copyToTmpRegister(Type.usize, .{ .register = .rcx });
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    try self.asmRegisterMemory(.{ ._, .cmp }, .rbx, val_lo_mem);
                    try self.asmRegisterMemory(.{ ._, .sbb }, tmp_reg, val_hi_mem);
                    try self.asmCmovccRegisterMemory(cc, .rbx, val_lo_mem);
                    try self.asmCmovccRegisterMemory(cc, .rcx, val_hi_mem);
                },
            };
            try self.asmMemory(.{ .@"lock _16b", .cmpxchg }, ptr_mem);
            _ = try self.asmJccReloc(.ne, loop);

            if (unused) return .unreach;
            const dst_mcv = try self.allocTempRegOrMem(val_ty, false);
            try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = dst_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .disp = dst_mcv.load_frame.off + 0,
                } },
            }, .rax);
            try self.asmMemoryRegister(.{ ._, .mov }, .{
                .base = .{ .frame = dst_mcv.load_frame.index },
                .mod = .{ .rm = .{
                    .size = .qword,
                    .disp = dst_mcv.load_frame.off + 8,
                } },
            }, .rdx);
            return dst_mcv;
        },
        .libcall => return self.fail("TODO implement x86 atomic libcall", .{}),
    }
}

fn airAtomicRmw(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.AtomicRmw, pl_op.payload).data;

    try self.spillRegisters(&.{ .rax, .rdx, .rbx, .rcx });
    const regs_lock = self.register_manager.lockRegsAssumeUnused(4, .{ .rax, .rdx, .rbx, .rcx });
    defer for (regs_lock) |lock| self.register_manager.unlockReg(lock);

    const unused = self.liveness.isUnused(inst);

    const ptr_ty = self.typeOf(pl_op.operand);
    const ptr_mcv = try self.resolveInst(pl_op.operand);

    const val_ty = self.typeOf(extra.operand);
    const val_mcv = try self.resolveInst(extra.operand);

    const result =
        try self.atomicOp(ptr_mcv, val_mcv, ptr_ty, val_ty, unused, extra.op(), extra.ordering());
    return self.finishAir(inst, result, .{ pl_op.operand, extra.operand, .none });
}

fn airAtomicLoad(self: *Self, inst: Air.Inst.Index) !void {
    const atomic_load = self.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;

    const ptr_ty = self.typeOf(atomic_load.ptr);
    const ptr_mcv = try self.resolveInst(atomic_load.ptr);
    const ptr_lock = switch (ptr_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_mcv =
        if (self.reuseOperand(inst, atomic_load.ptr, 0, ptr_mcv))
        ptr_mcv
    else
        try self.allocRegOrMem(inst, true);

    try self.load(dst_mcv, ptr_ty, ptr_mcv);
    return self.finishAir(inst, dst_mcv, .{ atomic_load.ptr, .none, .none });
}

fn airAtomicStore(self: *Self, inst: Air.Inst.Index, order: std.builtin.AtomicOrder) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ptr_ty = self.typeOf(bin_op.lhs);
    const ptr_mcv = try self.resolveInst(bin_op.lhs);

    const val_ty = self.typeOf(bin_op.rhs);
    const val_mcv = try self.resolveInst(bin_op.rhs);

    const result = try self.atomicOp(ptr_mcv, val_mcv, ptr_ty, val_ty, true, null, order);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMemset(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    result: {
        if (!safety and (try self.resolveInst(bin_op.rhs)) == .undef) break :result;

        try self.spillRegisters(&.{ .rax, .rdi, .rsi, .rcx });
        const reg_locks = self.register_manager.lockRegsAssumeUnused(4, .{ .rax, .rdi, .rsi, .rcx });
        defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

        const dst_ptr = try self.resolveInst(bin_op.lhs);
        const dst_ptr_ty = self.typeOf(bin_op.lhs);
        const dst_ptr_lock: ?RegisterLock = switch (dst_ptr) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (dst_ptr_lock) |lock| self.register_manager.unlockReg(lock);

        const src_val = try self.resolveInst(bin_op.rhs);
        const elem_ty = self.typeOf(bin_op.rhs);
        const src_val_lock: ?RegisterLock = switch (src_val) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (src_val_lock) |lock| self.register_manager.unlockReg(lock);

        const elem_abi_size: u31 = @intCast(elem_ty.abiSize(zcu));

        if (elem_abi_size == 1) {
            const ptr: MCValue = switch (dst_ptr_ty.ptrSize(zcu)) {
                // TODO: this only handles slices stored in the stack
                .Slice => dst_ptr,
                .One => dst_ptr,
                .C, .Many => unreachable,
            };
            const len: MCValue = switch (dst_ptr_ty.ptrSize(zcu)) {
                // TODO: this only handles slices stored in the stack
                .Slice => dst_ptr.address().offset(8).deref(),
                .One => .{ .immediate = dst_ptr_ty.childType(zcu).arrayLen(zcu) },
                .C, .Many => unreachable,
            };
            const len_lock: ?RegisterLock = switch (len) {
                .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                else => null,
            };
            defer if (len_lock) |lock| self.register_manager.unlockReg(lock);

            try self.genInlineMemset(ptr, src_val, len, .{ .safety = safety });
            break :result;
        }

        // Store the first element, and then rely on memcpy copying forwards.
        // Length zero requires a runtime check - so we handle arrays specially
        // here to elide it.
        switch (dst_ptr_ty.ptrSize(zcu)) {
            .Slice => {
                const slice_ptr_ty = dst_ptr_ty.slicePtrFieldType(zcu);

                // TODO: this only handles slices stored in the stack
                const ptr = dst_ptr;
                const len = dst_ptr.address().offset(8).deref();

                // Used to store the number of elements for comparison.
                // After comparison, updated to store number of bytes needed to copy.
                const len_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const len_mcv: MCValue = .{ .register = len_reg };
                const len_lock = self.register_manager.lockRegAssumeUnused(len_reg);
                defer self.register_manager.unlockReg(len_lock);

                try self.genSetReg(len_reg, Type.usize, len, .{});
                try self.asmRegisterRegister(.{ ._, .@"test" }, len_reg, len_reg);

                const skip_reloc = try self.asmJccReloc(.z, undefined);
                try self.store(slice_ptr_ty, ptr, src_val, .{ .safety = safety });

                const second_elem_ptr_reg =
                    try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const second_elem_ptr_mcv: MCValue = .{ .register = second_elem_ptr_reg };
                const second_elem_ptr_lock =
                    self.register_manager.lockRegAssumeUnused(second_elem_ptr_reg);
                defer self.register_manager.unlockReg(second_elem_ptr_lock);

                try self.genSetReg(second_elem_ptr_reg, Type.usize, .{ .register_offset = .{
                    .reg = try self.copyToTmpRegister(Type.usize, ptr),
                    .off = elem_abi_size,
                } }, .{});

                try self.genBinOpMir(.{ ._, .sub }, Type.usize, len_mcv, .{ .immediate = 1 });
                try self.asmRegisterRegisterImmediate(
                    .{ .i_, .mul },
                    len_reg,
                    len_reg,
                    Immediate.s(elem_abi_size),
                );
                try self.genInlineMemcpy(second_elem_ptr_mcv, ptr, len_mcv);

                self.performReloc(skip_reloc);
            },
            .One => {
                const elem_ptr_ty = try pt.singleMutPtrType(elem_ty);

                const len = dst_ptr_ty.childType(zcu).arrayLen(zcu);

                assert(len != 0); // prevented by Sema
                try self.store(elem_ptr_ty, dst_ptr, src_val, .{ .safety = safety });

                const second_elem_ptr_reg =
                    try self.register_manager.allocReg(null, abi.RegisterClass.gp);
                const second_elem_ptr_mcv: MCValue = .{ .register = second_elem_ptr_reg };
                const second_elem_ptr_lock =
                    self.register_manager.lockRegAssumeUnused(second_elem_ptr_reg);
                defer self.register_manager.unlockReg(second_elem_ptr_lock);

                try self.genSetReg(second_elem_ptr_reg, Type.usize, .{ .register_offset = .{
                    .reg = try self.copyToTmpRegister(Type.usize, dst_ptr),
                    .off = elem_abi_size,
                } }, .{});

                const bytes_to_copy: MCValue = .{ .immediate = elem_abi_size * (len - 1) };
                try self.genInlineMemcpy(second_elem_ptr_mcv, dst_ptr, bytes_to_copy);
            },
            .C, .Many => unreachable,
        }
    }
    return self.finishAir(inst, .unreach, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    try self.spillRegisters(&.{ .rdi, .rsi, .rcx });
    const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rdi, .rsi, .rcx });
    defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

    const dst_ptr = try self.resolveInst(bin_op.lhs);
    const dst_ptr_ty = self.typeOf(bin_op.lhs);
    const dst_ptr_lock: ?RegisterLock = switch (dst_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (dst_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const src_ptr = try self.resolveInst(bin_op.rhs);
    const src_ptr_lock: ?RegisterLock = switch (src_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const len: MCValue = switch (dst_ptr_ty.ptrSize(zcu)) {
        .Slice => len: {
            const len_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
            const len_lock = self.register_manager.lockRegAssumeUnused(len_reg);
            defer self.register_manager.unlockReg(len_lock);

            try self.asmRegisterMemoryImmediate(
                .{ .i_, .mul },
                len_reg,
                try dst_ptr.address().offset(8).deref().mem(self, .qword),
                Immediate.s(@intCast(dst_ptr_ty.childType(zcu).abiSize(zcu))),
            );
            break :len .{ .register = len_reg };
        },
        .One => len: {
            const array_ty = dst_ptr_ty.childType(zcu);
            break :len .{ .immediate = array_ty.arrayLen(zcu) * array_ty.childType(zcu).abiSize(zcu) };
        },
        .C, .Many => unreachable,
    };
    const len_lock: ?RegisterLock = switch (len) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (len_lock) |lock| self.register_manager.unlockReg(lock);

    // TODO: dst_ptr and src_ptr could be slices rather than raw pointers
    try self.genInlineMemcpy(dst_ptr, src_ptr, len);

    return self.finishAir(inst, .unreach, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airTagName(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const inst_ty = self.typeOfIndex(inst);
    const enum_ty = self.typeOf(un_op);
    const resolved_cc = abi.resolveCallingConvention(.Unspecified, self.target.*);

    // We need a properly aligned and sized call frame to be able to call this function.
    {
        const needed_call_frame = FrameAlloc.init(.{
            .size = inst_ty.abiSize(zcu),
            .alignment = inst_ty.abiAlignment(zcu),
        });
        const frame_allocs_slice = self.frame_allocs.slice();
        const stack_frame_size =
            &frame_allocs_slice.items(.abi_size)[@intFromEnum(FrameIndex.call_frame)];
        stack_frame_size.* = @max(stack_frame_size.*, needed_call_frame.abi_size);
        const stack_frame_align =
            &frame_allocs_slice.items(.abi_align)[@intFromEnum(FrameIndex.call_frame)];
        stack_frame_align.* = stack_frame_align.max(needed_call_frame.abi_align);
    }

    try self.spillEflagsIfOccupied();
    try self.spillCallerPreservedRegs(resolved_cc);

    const param_regs = abi.getCAbiIntParamRegs(resolved_cc);

    const dst_mcv = try self.allocRegOrMem(inst, false);
    try self.genSetReg(param_regs[0], Type.usize, dst_mcv.address(), .{});

    const operand = try self.resolveInst(un_op);
    try self.genSetReg(param_regs[1], enum_ty, operand, .{});

    const enum_lazy_sym: link.File.LazySymbol = .{ .kind = .code, .ty = enum_ty.toIntern() };
    try self.genLazySymbolRef(.call, .rax, enum_lazy_sym);

    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const err_ty = self.typeOf(un_op);
    const err_mcv = try self.resolveInst(un_op);
    const err_reg = try self.copyToTmpRegister(err_ty, err_mcv);
    const err_lock = self.register_manager.lockRegAssumeUnused(err_reg);
    defer self.register_manager.unlockReg(err_lock);

    const addr_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
    defer self.register_manager.unlockReg(addr_lock);
    const anyerror_lazy_sym: link.File.LazySymbol = .{ .kind = .const_data, .ty = .anyerror_type };
    try self.genLazySymbolRef(.lea, addr_reg, anyerror_lazy_sym);

    const start_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const start_lock = self.register_manager.lockRegAssumeUnused(start_reg);
    defer self.register_manager.unlockReg(start_lock);

    const end_reg = try self.register_manager.allocReg(null, abi.RegisterClass.gp);
    const end_lock = self.register_manager.lockRegAssumeUnused(end_reg);
    defer self.register_manager.unlockReg(end_lock);

    try self.truncateRegister(err_ty, err_reg.to32());

    try self.asmRegisterMemory(
        .{ ._, .mov },
        start_reg.to32(),
        .{
            .base = .{ .reg = addr_reg.to64() },
            .mod = .{ .rm = .{
                .size = .dword,
                .index = err_reg.to64(),
                .scale = .@"4",
                .disp = (1 - 1) * 4,
            } },
        },
    );
    try self.asmRegisterMemory(
        .{ ._, .mov },
        end_reg.to32(),
        .{
            .base = .{ .reg = addr_reg.to64() },
            .mod = .{ .rm = .{
                .size = .dword,
                .index = err_reg.to64(),
                .scale = .@"4",
                .disp = (2 - 1) * 4,
            } },
        },
    );
    try self.asmRegisterRegister(.{ ._, .sub }, end_reg.to32(), start_reg.to32());
    try self.asmRegisterMemory(
        .{ ._, .lea },
        start_reg.to64(),
        .{
            .base = .{ .reg = addr_reg.to64() },
            .mod = .{ .rm = .{
                .size = .dword,
                .index = start_reg.to64(),
            } },
        },
    );
    try self.asmRegisterMemory(
        .{ ._, .lea },
        end_reg.to32(),
        .{
            .base = .{ .reg = end_reg.to64() },
            .mod = .{ .rm = .{
                .size = .byte,
                .disp = -1,
            } },
        },
    );

    const dst_mcv = try self.allocRegOrMem(inst, false);
    try self.asmMemoryRegister(
        .{ ._, .mov },
        .{
            .base = .{ .frame = dst_mcv.load_frame.index },
            .mod = .{ .rm = .{
                .size = .qword,
                .disp = dst_mcv.load_frame.off,
            } },
        },
        start_reg.to64(),
    );
    try self.asmMemoryRegister(
        .{ ._, .mov },
        .{
            .base = .{ .frame = dst_mcv.load_frame.index },
            .mod = .{ .rm = .{
                .size = .qword,
                .disp = dst_mcv.load_frame.off + 8,
            } },
        },
        end_reg.to64(),
    );

    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const vector_ty = self.typeOfIndex(inst);
    const vector_len = vector_ty.vectorLen(zcu);
    const dst_rc = self.regClassForType(vector_ty);
    const scalar_ty = self.typeOf(ty_op.operand);

    const result: MCValue = result: {
        switch (scalar_ty.zigTypeTag(zcu)) {
            else => {},
            .bool => {
                const regs =
                    try self.register_manager.allocRegs(2, .{ inst, null }, abi.RegisterClass.gp);
                const reg_locks = self.register_manager.lockRegsAssumeUnused(2, regs);
                defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

                try self.genSetReg(regs[1], vector_ty, .{ .immediate = 0 }, .{});
                try self.genSetReg(
                    regs[1],
                    vector_ty,
                    .{ .immediate = @as(u64, math.maxInt(u64)) >> @intCast(64 - vector_len) },
                    .{},
                );
                const src_mcv = try self.resolveInst(ty_op.operand);
                const abi_size = @max(math.divCeil(u32, vector_len, 8) catch unreachable, 4);
                try self.asmCmovccRegisterRegister(
                    switch (src_mcv) {
                        .eflags => |cc| cc,
                        .register => |src_reg| cc: {
                            try self.asmRegisterImmediate(
                                .{ ._, .@"test" },
                                src_reg.to8(),
                                Immediate.u(1),
                            );
                            break :cc .nz;
                        },
                        else => cc: {
                            try self.asmMemoryImmediate(
                                .{ ._, .@"test" },
                                try src_mcv.mem(self, .byte),
                                Immediate.u(1),
                            );
                            break :cc .nz;
                        },
                    },
                    registerAlias(regs[0], abi_size),
                    registerAlias(regs[1], abi_size),
                );
                break :result .{ .register = regs[0] };
            },
            .int => if (self.hasFeature(.avx2)) avx2: {
                const mir_tag = @as(?Mir.Inst.FixedTag, switch (scalar_ty.intInfo(zcu).bits) {
                    else => null,
                    1...8 => switch (vector_len) {
                        else => null,
                        1...32 => .{ .vp_b, .broadcast },
                    },
                    9...16 => switch (vector_len) {
                        else => null,
                        1...16 => .{ .vp_w, .broadcast },
                    },
                    17...32 => switch (vector_len) {
                        else => null,
                        1...8 => .{ .vp_d, .broadcast },
                    },
                    33...64 => switch (vector_len) {
                        else => null,
                        1...4 => .{ .vp_q, .broadcast },
                    },
                    65...128 => switch (vector_len) {
                        else => null,
                        1...2 => .{ .v_i128, .broadcast },
                    },
                }) orelse break :avx2;

                const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.sse);
                const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
                defer self.register_manager.unlockReg(dst_lock);

                const src_mcv = try self.resolveInst(ty_op.operand);
                if (src_mcv.isMemory()) try self.asmRegisterMemory(
                    mir_tag,
                    registerAlias(dst_reg, @intCast(vector_ty.abiSize(zcu))),
                    try src_mcv.mem(self, self.memSize(scalar_ty)),
                ) else {
                    if (mir_tag[0] == .v_i128) break :avx2;
                    try self.genSetReg(dst_reg, scalar_ty, src_mcv, .{});
                    try self.asmRegisterRegister(
                        mir_tag,
                        registerAlias(dst_reg, @intCast(vector_ty.abiSize(zcu))),
                        registerAlias(dst_reg, @intCast(scalar_ty.abiSize(zcu))),
                    );
                }
                break :result .{ .register = dst_reg };
            } else {
                const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.sse);
                const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
                defer self.register_manager.unlockReg(dst_lock);

                try self.genSetReg(dst_reg, scalar_ty, .{ .air_ref = ty_op.operand }, .{});
                if (vector_len == 1) break :result .{ .register = dst_reg };

                const dst_alias = registerAlias(dst_reg, @intCast(vector_ty.abiSize(zcu)));
                const scalar_bits = scalar_ty.intInfo(zcu).bits;
                if (switch (scalar_bits) {
                    1...8 => true,
                    9...128 => false,
                    else => unreachable,
                }) if (self.hasFeature(.avx)) try self.asmRegisterRegisterRegister(
                    .{ .vp_, .unpcklbw },
                    dst_alias,
                    dst_alias,
                    dst_alias,
                ) else try self.asmRegisterRegister(
                    .{ .p_, .unpcklbw },
                    dst_alias,
                    dst_alias,
                );
                if (switch (scalar_bits) {
                    1...8 => vector_len > 2,
                    9...16 => true,
                    17...128 => false,
                    else => unreachable,
                }) try self.asmRegisterRegisterImmediate(
                    .{ if (self.hasFeature(.avx)) .vp_w else .p_w, .shufl },
                    dst_alias,
                    dst_alias,
                    Immediate.u(0b00_00_00_00),
                );
                if (switch (scalar_bits) {
                    1...8 => vector_len > 4,
                    9...16 => vector_len > 2,
                    17...64 => true,
                    65...128 => false,
                    else => unreachable,
                }) try self.asmRegisterRegisterImmediate(
                    .{ if (self.hasFeature(.avx)) .vp_d else .p_d, .shuf },
                    dst_alias,
                    dst_alias,
                    Immediate.u(if (scalar_bits <= 64) 0b00_00_00_00 else 0b01_00_01_00),
                );
                break :result .{ .register = dst_reg };
            },
            .float => switch (scalar_ty.floatBits(self.target.*)) {
                32 => switch (vector_len) {
                    1 => {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv;
                        const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                        try self.genSetReg(dst_reg, scalar_ty, src_mcv, .{});
                        break :result .{ .register = dst_reg };
                    },
                    2...4 => {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        if (self.hasFeature(.avx)) {
                            const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                            if (src_mcv.isMemory()) try self.asmRegisterMemory(
                                .{ .v_ss, .broadcast },
                                dst_reg.to128(),
                                try src_mcv.mem(self, .dword),
                            ) else {
                                const src_reg = if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(scalar_ty, src_mcv);
                                try self.asmRegisterRegisterRegisterImmediate(
                                    .{ .v_ps, .shuf },
                                    dst_reg.to128(),
                                    src_reg.to128(),
                                    src_reg.to128(),
                                    Immediate.u(0),
                                );
                            }
                            break :result .{ .register = dst_reg };
                        } else {
                            const dst_mcv = if (src_mcv.isRegister() and
                                self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                                src_mcv
                            else
                                try self.copyToRegisterWithInstTracking(inst, scalar_ty, src_mcv);
                            const dst_reg = dst_mcv.getReg().?;
                            try self.asmRegisterRegisterImmediate(
                                .{ ._ps, .shuf },
                                dst_reg.to128(),
                                dst_reg.to128(),
                                Immediate.u(0),
                            );
                            break :result dst_mcv;
                        }
                    },
                    5...8 => if (self.hasFeature(.avx)) {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                        if (src_mcv.isMemory()) try self.asmRegisterMemory(
                            .{ .v_ss, .broadcast },
                            dst_reg.to256(),
                            try src_mcv.mem(self, .dword),
                        ) else {
                            const src_reg = if (src_mcv.isRegister())
                                src_mcv.getReg().?
                            else
                                try self.copyToTmpRegister(scalar_ty, src_mcv);
                            if (self.hasFeature(.avx2)) try self.asmRegisterRegister(
                                .{ .v_ss, .broadcast },
                                dst_reg.to256(),
                                src_reg.to128(),
                            ) else {
                                try self.asmRegisterRegisterRegisterImmediate(
                                    .{ .v_ps, .shuf },
                                    dst_reg.to128(),
                                    src_reg.to128(),
                                    src_reg.to128(),
                                    Immediate.u(0),
                                );
                                try self.asmRegisterRegisterRegisterImmediate(
                                    .{ .v_f128, .insert },
                                    dst_reg.to256(),
                                    dst_reg.to256(),
                                    dst_reg.to128(),
                                    Immediate.u(1),
                                );
                            }
                        }
                        break :result .{ .register = dst_reg };
                    },
                    else => {},
                },
                64 => switch (vector_len) {
                    1 => {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv;
                        const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                        try self.genSetReg(dst_reg, scalar_ty, src_mcv, .{});
                        break :result .{ .register = dst_reg };
                    },
                    2 => {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                        if (self.hasFeature(.sse3)) {
                            if (src_mcv.isMemory()) try self.asmRegisterMemory(
                                if (self.hasFeature(.avx)) .{ .v_, .movddup } else .{ ._, .movddup },
                                dst_reg.to128(),
                                try src_mcv.mem(self, .qword),
                            ) else try self.asmRegisterRegister(
                                if (self.hasFeature(.avx)) .{ .v_, .movddup } else .{ ._, .movddup },
                                dst_reg.to128(),
                                (if (src_mcv.isRegister())
                                    src_mcv.getReg().?
                                else
                                    try self.copyToTmpRegister(scalar_ty, src_mcv)).to128(),
                            );
                            break :result .{ .register = dst_reg };
                        } else try self.asmRegisterRegister(
                            .{ ._ps, .movlh },
                            dst_reg.to128(),
                            (if (src_mcv.isRegister())
                                src_mcv.getReg().?
                            else
                                try self.copyToTmpRegister(scalar_ty, src_mcv)).to128(),
                        );
                    },
                    3...4 => if (self.hasFeature(.avx)) {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                        if (src_mcv.isMemory()) try self.asmRegisterMemory(
                            .{ .v_sd, .broadcast },
                            dst_reg.to256(),
                            try src_mcv.mem(self, .qword),
                        ) else {
                            const src_reg = if (src_mcv.isRegister())
                                src_mcv.getReg().?
                            else
                                try self.copyToTmpRegister(scalar_ty, src_mcv);
                            if (self.hasFeature(.avx2)) try self.asmRegisterRegister(
                                .{ .v_sd, .broadcast },
                                dst_reg.to256(),
                                src_reg.to128(),
                            ) else {
                                try self.asmRegisterRegister(
                                    .{ .v_, .movddup },
                                    dst_reg.to128(),
                                    src_reg.to128(),
                                );
                                try self.asmRegisterRegisterRegisterImmediate(
                                    .{ .v_f128, .insert },
                                    dst_reg.to256(),
                                    dst_reg.to256(),
                                    dst_reg.to128(),
                                    Immediate.u(1),
                                );
                            }
                        }
                        break :result .{ .register = dst_reg };
                    },
                    else => {},
                },
                128 => switch (vector_len) {
                    1 => {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv;
                        const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                        try self.genSetReg(dst_reg, scalar_ty, src_mcv, .{});
                        break :result .{ .register = dst_reg };
                    },
                    2 => if (self.hasFeature(.avx)) {
                        const src_mcv = try self.resolveInst(ty_op.operand);
                        const dst_reg = try self.register_manager.allocReg(inst, dst_rc);
                        if (src_mcv.isMemory()) try self.asmRegisterMemory(
                            .{ .v_f128, .broadcast },
                            dst_reg.to256(),
                            try src_mcv.mem(self, .xword),
                        ) else {
                            const src_reg = if (src_mcv.isRegister())
                                src_mcv.getReg().?
                            else
                                try self.copyToTmpRegister(scalar_ty, src_mcv);
                            try self.asmRegisterRegisterRegisterImmediate(
                                .{ .v_f128, .insert },
                                dst_reg.to256(),
                                src_reg.to256(),
                                src_reg.to128(),
                                Immediate.u(1),
                            );
                        }
                        break :result .{ .register = dst_reg };
                    },
                    else => {},
                },
                16, 80 => {},
                else => unreachable,
            },
        }
        return self.fail("TODO implement airSplat for {}", .{vector_ty.fmt(pt)});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const ty = self.typeOfIndex(inst);
    const vec_len = ty.vectorLen(zcu);
    const elem_ty = ty.childType(zcu);
    const elem_abi_size: u32 = @intCast(elem_ty.abiSize(zcu));
    const abi_size: u32 = @intCast(ty.abiSize(zcu));
    const pred_ty = self.typeOf(pl_op.operand);

    const result = result: {
        const has_blend = self.hasFeature(.sse4_1);
        const has_avx = self.hasFeature(.avx);
        const need_xmm0 = has_blend and !has_avx;
        const pred_mcv = try self.resolveInst(pl_op.operand);
        const mask_reg = mask: {
            switch (pred_mcv) {
                .register => |pred_reg| switch (pred_reg.class()) {
                    .general_purpose => {},
                    .sse => if (need_xmm0 and pred_reg.id() != comptime Register.xmm0.id()) {
                        try self.register_manager.getKnownReg(.xmm0, null);
                        try self.genSetReg(.xmm0, pred_ty, pred_mcv, .{});
                        break :mask .xmm0;
                    } else break :mask if (has_blend)
                        pred_reg
                    else
                        try self.copyToTmpRegister(pred_ty, pred_mcv),
                    else => unreachable,
                },
                else => {},
            }
            const mask_reg: Register = if (need_xmm0) mask_reg: {
                try self.register_manager.getKnownReg(.xmm0, null);
                break :mask_reg .xmm0;
            } else try self.register_manager.allocReg(null, abi.RegisterClass.sse);
            const mask_alias = registerAlias(mask_reg, abi_size);
            const mask_lock = self.register_manager.lockRegAssumeUnused(mask_reg);
            defer self.register_manager.unlockReg(mask_lock);

            const pred_fits_in_elem = vec_len <= elem_abi_size;
            if (self.hasFeature(.avx2) and abi_size <= 32) {
                if (pred_mcv.isRegister()) broadcast: {
                    try self.asmRegisterRegister(
                        .{ .v_d, .mov },
                        mask_reg.to128(),
                        pred_mcv.getReg().?.to32(),
                    );
                    if (pred_fits_in_elem and vec_len > 1) try self.asmRegisterRegister(
                        .{ switch (elem_abi_size) {
                            1 => .vp_b,
                            2 => .vp_w,
                            3...4 => .vp_d,
                            5...8 => .vp_q,
                            9...16 => {
                                try self.asmRegisterRegisterRegisterImmediate(
                                    .{ .v_f128, .insert },
                                    mask_alias,
                                    mask_alias,
                                    mask_reg.to128(),
                                    Immediate.u(1),
                                );
                                break :broadcast;
                            },
                            17...32 => break :broadcast,
                            else => unreachable,
                        }, .broadcast },
                        mask_alias,
                        mask_reg.to128(),
                    );
                } else try self.asmRegisterMemory(
                    .{ switch (vec_len) {
                        1...8 => .vp_b,
                        9...16 => .vp_w,
                        17...32 => .vp_d,
                        else => unreachable,
                    }, .broadcast },
                    mask_alias,
                    if (pred_mcv.isMemory()) try pred_mcv.mem(self, .byte) else .{
                        .base = .{ .reg = (try self.copyToTmpRegister(
                            Type.usize,
                            pred_mcv.address(),
                        )).to64() },
                        .mod = .{ .rm = .{ .size = .byte } },
                    },
                );
            } else if (abi_size <= 16) broadcast: {
                try self.asmRegisterRegister(
                    .{ if (has_avx) .v_d else ._d, .mov },
                    mask_alias,
                    (if (pred_mcv.isRegister())
                        pred_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(pred_ty, pred_mcv.address())).to32(),
                );
                if (!pred_fits_in_elem or vec_len == 1) break :broadcast;
                if (elem_abi_size <= 1) {
                    if (has_avx) try self.asmRegisterRegisterRegister(
                        .{ .vp_, .unpcklbw },
                        mask_alias,
                        mask_alias,
                        mask_alias,
                    ) else try self.asmRegisterRegister(
                        .{ .p_, .unpcklbw },
                        mask_alias,
                        mask_alias,
                    );
                    if (abi_size <= 2) break :broadcast;
                }
                if (elem_abi_size <= 2) {
                    try self.asmRegisterRegisterImmediate(
                        .{ if (has_avx) .vp_w else .p_w, .shufl },
                        mask_alias,
                        mask_alias,
                        Immediate.u(0b00_00_00_00),
                    );
                    if (abi_size <= 8) break :broadcast;
                }
                try self.asmRegisterRegisterImmediate(
                    .{ if (has_avx) .vp_d else .p_d, .shuf },
                    mask_alias,
                    mask_alias,
                    Immediate.u(switch (elem_abi_size) {
                        1...2, 5...8 => 0b01_00_01_00,
                        3...4 => 0b00_00_00_00,
                        else => unreachable,
                    }),
                );
            } else return self.fail("TODO implement airSelect for {}", .{ty.fmt(pt)});
            const elem_bits: u16 = @intCast(elem_abi_size * 8);
            const mask_elem_ty = try pt.intType(.unsigned, elem_bits);
            const mask_ty = try pt.vectorType(.{ .len = vec_len, .child = mask_elem_ty.toIntern() });
            if (!pred_fits_in_elem) if (self.hasFeature(.ssse3)) {
                var mask_elems: [32]InternPool.Index = undefined;
                for (mask_elems[0..vec_len], 0..) |*elem, bit| elem.* = try pt.intern(.{ .int = .{
                    .ty = mask_elem_ty.toIntern(),
                    .storage = .{ .u64 = bit / elem_bits },
                } });
                const mask_mcv = try self.genTypedValue(Value.fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = mask_ty.toIntern(),
                    .storage = .{ .elems = mask_elems[0..vec_len] },
                } })));
                const mask_mem: Memory = .{
                    .base = .{ .reg = try self.copyToTmpRegister(Type.usize, mask_mcv.address()) },
                    .mod = .{ .rm = .{ .size = self.memSize(ty) } },
                };
                if (has_avx) try self.asmRegisterRegisterMemory(
                    .{ .vp_b, .shuf },
                    mask_alias,
                    mask_alias,
                    mask_mem,
                ) else try self.asmRegisterMemory(
                    .{ .p_b, .shuf },
                    mask_alias,
                    mask_mem,
                );
            } else return self.fail("TODO implement airSelect for {}", .{ty.fmt(pt)});
            {
                var mask_elems: [32]InternPool.Index = undefined;
                for (mask_elems[0..vec_len], 0..) |*elem, bit| elem.* = try pt.intern(.{ .int = .{
                    .ty = mask_elem_ty.toIntern(),
                    .storage = .{ .u64 = @as(u32, 1) << @intCast(bit & (elem_bits - 1)) },
                } });
                const mask_mcv = try self.genTypedValue(Value.fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = mask_ty.toIntern(),
                    .storage = .{ .elems = mask_elems[0..vec_len] },
                } })));
                const mask_mem: Memory = .{
                    .base = .{ .reg = try self.copyToTmpRegister(Type.usize, mask_mcv.address()) },
                    .mod = .{ .rm = .{ .size = self.memSize(ty) } },
                };
                if (has_avx) {
                    try self.asmRegisterRegisterMemory(
                        .{ .vp_, .@"and" },
                        mask_alias,
                        mask_alias,
                        mask_mem,
                    );
                    try self.asmRegisterRegisterMemory(
                        .{ .vp_d, .cmpeq },
                        mask_alias,
                        mask_alias,
                        mask_mem,
                    );
                } else {
                    try self.asmRegisterMemory(
                        .{ .p_, .@"and" },
                        mask_alias,
                        mask_mem,
                    );
                    try self.asmRegisterMemory(
                        .{ .p_d, .cmpeq },
                        mask_alias,
                        mask_mem,
                    );
                }
            }
            break :mask mask_reg;
        };
        const mask_alias = registerAlias(mask_reg, abi_size);
        const mask_lock = self.register_manager.lockRegAssumeUnused(mask_reg);
        defer self.register_manager.unlockReg(mask_lock);

        const lhs_mcv = try self.resolveInst(extra.lhs);
        const lhs_lock = switch (lhs_mcv) {
            .register => |lhs_reg| self.register_manager.lockRegAssumeUnused(lhs_reg),
            else => null,
        };
        defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const rhs_mcv = try self.resolveInst(extra.rhs);
        const rhs_lock = switch (rhs_mcv) {
            .register => |rhs_reg| self.register_manager.lockReg(rhs_reg),
            else => null,
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const reuse_mcv = if (has_blend) rhs_mcv else lhs_mcv;
        const dst_mcv: MCValue = if (reuse_mcv.isRegister() and self.reuseOperand(
            inst,
            if (has_blend) extra.rhs else extra.lhs,
            @intFromBool(has_blend),
            reuse_mcv,
        )) reuse_mcv else if (has_avx)
            .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
        else
            try self.copyToRegisterWithInstTracking(inst, ty, reuse_mcv);
        const dst_reg = dst_mcv.getReg().?;
        const dst_alias = registerAlias(dst_reg, abi_size);
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const mir_tag = @as(?Mir.Inst.FixedTag, switch (ty.childType(zcu).zigTypeTag(zcu)) {
            else => null,
            .int => switch (abi_size) {
                0 => unreachable,
                1...16 => if (has_avx)
                    .{ .vp_b, .blendv }
                else if (has_blend)
                    .{ .p_b, .blendv }
                else
                    .{ .p_, undefined },
                17...32 => if (self.hasFeature(.avx2))
                    .{ .vp_b, .blendv }
                else
                    null,
                else => null,
            },
            .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                else => unreachable,
                16, 80, 128 => null,
                32 => switch (vec_len) {
                    0 => unreachable,
                    1...4 => if (has_avx) .{ .v_ps, .blendv } else .{ ._ps, .blendv },
                    5...8 => if (has_avx) .{ .v_ps, .blendv } else null,
                    else => null,
                },
                64 => switch (vec_len) {
                    0 => unreachable,
                    1...2 => if (has_avx) .{ .v_pd, .blendv } else .{ ._pd, .blendv },
                    3...4 => if (has_avx) .{ .v_pd, .blendv } else null,
                    else => null,
                },
            },
        }) orelse return self.fail("TODO implement airSelect for {}", .{ty.fmt(pt)});
        if (has_avx) {
            const rhs_alias = if (rhs_mcv.isRegister())
                registerAlias(rhs_mcv.getReg().?, abi_size)
            else rhs: {
                try self.genSetReg(dst_reg, ty, rhs_mcv, .{});
                break :rhs dst_alias;
            };
            if (lhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryRegister(
                mir_tag,
                dst_alias,
                rhs_alias,
                try lhs_mcv.mem(self, self.memSize(ty)),
                mask_alias,
            ) else try self.asmRegisterRegisterRegisterRegister(
                mir_tag,
                dst_alias,
                rhs_alias,
                registerAlias(if (lhs_mcv.isRegister())
                    lhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(ty, lhs_mcv), abi_size),
                mask_alias,
            );
        } else if (has_blend) if (lhs_mcv.isMemory()) try self.asmRegisterMemoryRegister(
            mir_tag,
            dst_alias,
            try lhs_mcv.mem(self, self.memSize(ty)),
            mask_alias,
        ) else try self.asmRegisterRegisterRegister(
            mir_tag,
            dst_alias,
            registerAlias(if (lhs_mcv.isRegister())
                lhs_mcv.getReg().?
            else
                try self.copyToTmpRegister(ty, lhs_mcv), abi_size),
            mask_alias,
        ) else {
            const mir_fixes = @as(?Mir.Inst.Fixes, switch (elem_ty.zigTypeTag(zcu)) {
                else => null,
                .int => .p_,
                .float => switch (elem_ty.floatBits(self.target.*)) {
                    32 => ._ps,
                    64 => ._pd,
                    16, 80, 128 => null,
                    else => unreachable,
                },
            }) orelse return self.fail("TODO implement airSelect for {}", .{ty.fmt(pt)});
            try self.asmRegisterRegister(.{ mir_fixes, .@"and" }, dst_alias, mask_alias);
            if (rhs_mcv.isMemory()) try self.asmRegisterMemory(
                .{ mir_fixes, .andn },
                mask_alias,
                try rhs_mcv.mem(self, Memory.Size.fromSize(abi_size)),
            ) else try self.asmRegisterRegister(
                .{ mir_fixes, .andn },
                mask_alias,
                if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(ty, rhs_mcv),
            );
            try self.asmRegisterRegister(.{ mir_fixes, .@"or" }, dst_alias, mask_alias);
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Shuffle, ty_pl.payload).data;

    const dst_ty = self.typeOfIndex(inst);
    const elem_ty = dst_ty.childType(zcu);
    const elem_abi_size: u16 = @intCast(elem_ty.abiSize(zcu));
    const dst_abi_size: u32 = @intCast(dst_ty.abiSize(zcu));
    const lhs_ty = self.typeOf(extra.a);
    const lhs_abi_size: u32 = @intCast(lhs_ty.abiSize(zcu));
    const rhs_ty = self.typeOf(extra.b);
    const rhs_abi_size: u32 = @intCast(rhs_ty.abiSize(zcu));
    const max_abi_size = @max(dst_abi_size, lhs_abi_size, rhs_abi_size);

    const ExpectedContents = [32]?i32;
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
    const allocator = stack.get();

    const mask_elems = try allocator.alloc(?i32, extra.mask_len);
    defer allocator.free(mask_elems);
    for (mask_elems, 0..) |*mask_elem, elem_index| {
        const mask_elem_val =
            Value.fromInterned(extra.mask).elemValue(pt, elem_index) catch unreachable;
        mask_elem.* = if (mask_elem_val.isUndef(zcu))
            null
        else
            @intCast(mask_elem_val.toSignedInt(zcu));
    }

    const has_avx = self.hasFeature(.avx);
    const result = @as(?MCValue, result: {
        for (mask_elems) |mask_elem| {
            if (mask_elem) |_| break;
        } else break :result try self.allocRegOrMem(inst, true);

        for (mask_elems, 0..) |mask_elem, elem_index| {
            if (mask_elem orelse continue != elem_index) break;
        } else {
            const lhs_mcv = try self.resolveInst(extra.a);
            if (self.reuseOperand(inst, extra.a, 0, lhs_mcv)) break :result lhs_mcv;
            const dst_mcv = try self.allocRegOrMem(inst, true);
            try self.genCopy(dst_ty, dst_mcv, lhs_mcv, .{});
            break :result dst_mcv;
        }

        for (mask_elems, 0..) |mask_elem, elem_index| {
            if (~(mask_elem orelse continue) != elem_index) break;
        } else {
            const rhs_mcv = try self.resolveInst(extra.b);
            if (self.reuseOperand(inst, extra.b, 1, rhs_mcv)) break :result rhs_mcv;
            const dst_mcv = try self.allocRegOrMem(inst, true);
            try self.genCopy(dst_ty, dst_mcv, rhs_mcv, .{});
            break :result dst_mcv;
        }

        for ([_]Mir.Inst.Tag{ .unpckl, .unpckh }) |variant| unpck: {
            if (elem_abi_size > 8) break :unpck;
            if (dst_abi_size > @as(u32, if (if (elem_abi_size >= 4)
                has_avx
            else
                self.hasFeature(.avx2)) 32 else 16)) break :unpck;

            var sources = [1]?u1{null} ** 2;
            for (mask_elems, 0..) |maybe_mask_elem, elem_index| {
                const mask_elem = maybe_mask_elem orelse continue;
                const mask_elem_index =
                    math.cast(u5, if (mask_elem < 0) ~mask_elem else mask_elem) orelse break :unpck;
                const elem_byte = (elem_index >> 1) * elem_abi_size;
                if (mask_elem_index * elem_abi_size != (elem_byte & 0b0111) | @as(u4, switch (variant) {
                    .unpckl => 0b0000,
                    .unpckh => 0b1000,
                    else => unreachable,
                }) | (elem_byte << 1 & 0b10000)) break :unpck;

                const source = @intFromBool(mask_elem < 0);
                if (sources[elem_index & 0b00001]) |prev_source| {
                    if (source != prev_source) break :unpck;
                } else sources[elem_index & 0b00001] = source;
            }
            if (sources[0] orelse break :unpck == sources[1] orelse break :unpck) break :unpck;

            const operands = [2]Air.Inst.Ref{ extra.a, extra.b };
            const operand_tys = [2]Type{ lhs_ty, rhs_ty };
            const lhs_mcv = try self.resolveInst(operands[sources[0].?]);
            const rhs_mcv = try self.resolveInst(operands[sources[1].?]);

            const dst_mcv: MCValue = if (lhs_mcv.isRegister() and
                self.reuseOperand(inst, operands[sources[0].?], sources[0].?, lhs_mcv))
                lhs_mcv
            else if (has_avx and lhs_mcv.isRegister())
                .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
            else
                try self.copyToRegisterWithInstTracking(inst, operand_tys[sources[0].?], lhs_mcv);
            const dst_reg = dst_mcv.getReg().?;
            const dst_alias = registerAlias(dst_reg, max_abi_size);

            const mir_tag: Mir.Inst.FixedTag = if ((elem_abi_size >= 4 and elem_ty.isRuntimeFloat()) or
                (dst_abi_size > 16 and !self.hasFeature(.avx2))) .{ switch (elem_abi_size) {
                4 => if (has_avx) .v_ps else ._ps,
                8 => if (has_avx) .v_pd else ._pd,
                else => unreachable,
            }, variant } else .{ if (has_avx) .vp_ else .p_, switch (variant) {
                .unpckl => switch (elem_abi_size) {
                    1 => .unpcklbw,
                    2 => .unpcklwd,
                    4 => .unpckldq,
                    8 => .unpcklqdq,
                    else => unreachable,
                },
                .unpckh => switch (elem_abi_size) {
                    1 => .unpckhbw,
                    2 => .unpckhwd,
                    4 => .unpckhdq,
                    8 => .unpckhqdq,
                    else => unreachable,
                },
                else => unreachable,
            } };
            if (has_avx) if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                mir_tag,
                dst_alias,
                registerAlias(lhs_mcv.getReg() orelse dst_reg, max_abi_size),
                try rhs_mcv.mem(self, Memory.Size.fromSize(max_abi_size)),
            ) else try self.asmRegisterRegisterRegister(
                mir_tag,
                dst_alias,
                registerAlias(lhs_mcv.getReg() orelse dst_reg, max_abi_size),
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(operand_tys[sources[1].?], rhs_mcv), max_abi_size),
            ) else if (rhs_mcv.isMemory()) try self.asmRegisterMemory(
                mir_tag,
                dst_alias,
                try rhs_mcv.mem(self, Memory.Size.fromSize(max_abi_size)),
            ) else try self.asmRegisterRegister(
                mir_tag,
                dst_alias,
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(operand_tys[sources[1].?], rhs_mcv), max_abi_size),
            );
            break :result dst_mcv;
        }

        pshufd: {
            if (elem_abi_size != 4) break :pshufd;
            if (max_abi_size > @as(u32, if (has_avx) 32 else 16)) break :pshufd;

            var control: u8 = 0b00_00_00_00;
            var sources = [1]?u1{null} ** 1;
            for (mask_elems, 0..) |maybe_mask_elem, elem_index| {
                const mask_elem = maybe_mask_elem orelse continue;
                const mask_elem_index: u3 = @intCast(if (mask_elem < 0) ~mask_elem else mask_elem);
                if (mask_elem_index & 0b100 != elem_index & 0b100) break :pshufd;

                const source = @intFromBool(mask_elem < 0);
                if (sources[0]) |prev_source| {
                    if (source != prev_source) break :pshufd;
                } else sources[(elem_index & 0b010) >> 1] = source;

                const select_bit: u3 = @intCast((elem_index & 0b011) << 1);
                const select = @as(u8, @intCast(mask_elem_index & 0b011)) << select_bit;
                if (elem_index & 0b100 == 0)
                    control |= select
                else if (control & @as(u8, 0b11) << select_bit != select) break :pshufd;
            }

            const operands = [2]Air.Inst.Ref{ extra.a, extra.b };
            const operand_tys = [2]Type{ lhs_ty, rhs_ty };
            const src_mcv = try self.resolveInst(operands[sources[0] orelse break :pshufd]);

            const dst_reg = if (src_mcv.isRegister() and
                self.reuseOperand(inst, operands[sources[0].?], sources[0].?, src_mcv))
                src_mcv.getReg().?
            else
                try self.register_manager.allocReg(inst, abi.RegisterClass.sse);
            const dst_alias = registerAlias(dst_reg, max_abi_size);

            if (src_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
                .{ if (has_avx) .vp_d else .p_d, .shuf },
                dst_alias,
                try src_mcv.mem(self, Memory.Size.fromSize(max_abi_size)),
                Immediate.u(control),
            ) else try self.asmRegisterRegisterImmediate(
                .{ if (has_avx) .vp_d else .p_d, .shuf },
                dst_alias,
                registerAlias(if (src_mcv.isRegister())
                    src_mcv.getReg().?
                else
                    try self.copyToTmpRegister(operand_tys[sources[0].?], src_mcv), max_abi_size),
                Immediate.u(control),
            );
            break :result .{ .register = dst_reg };
        }

        shufps: {
            if (elem_abi_size != 4) break :shufps;
            if (max_abi_size > @as(u32, if (has_avx) 32 else 16)) break :shufps;

            var control: u8 = 0b00_00_00_00;
            var sources = [1]?u1{null} ** 2;
            for (mask_elems, 0..) |maybe_mask_elem, elem_index| {
                const mask_elem = maybe_mask_elem orelse continue;
                const mask_elem_index: u3 = @intCast(if (mask_elem < 0) ~mask_elem else mask_elem);
                if (mask_elem_index & 0b100 != elem_index & 0b100) break :shufps;

                const source = @intFromBool(mask_elem < 0);
                if (sources[(elem_index & 0b010) >> 1]) |prev_source| {
                    if (source != prev_source) break :shufps;
                } else sources[(elem_index & 0b010) >> 1] = source;

                const select_bit: u3 = @intCast((elem_index & 0b011) << 1);
                const select = @as(u8, @intCast(mask_elem_index & 0b011)) << select_bit;
                if (elem_index & 0b100 == 0)
                    control |= select
                else if (control & @as(u8, 0b11) << select_bit != select) break :shufps;
            }
            if (sources[0] orelse break :shufps == sources[1] orelse break :shufps) break :shufps;

            const operands = [2]Air.Inst.Ref{ extra.a, extra.b };
            const operand_tys = [2]Type{ lhs_ty, rhs_ty };
            const lhs_mcv = try self.resolveInst(operands[sources[0].?]);
            const rhs_mcv = try self.resolveInst(operands[sources[1].?]);

            const dst_mcv: MCValue = if (lhs_mcv.isRegister() and
                self.reuseOperand(inst, operands[sources[0].?], sources[0].?, lhs_mcv))
                lhs_mcv
            else if (has_avx and lhs_mcv.isRegister())
                .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
            else
                try self.copyToRegisterWithInstTracking(inst, operand_tys[sources[0].?], lhs_mcv);
            const dst_reg = dst_mcv.getReg().?;
            const dst_alias = registerAlias(dst_reg, max_abi_size);

            if (has_avx) if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                .{ .v_ps, .shuf },
                dst_alias,
                registerAlias(lhs_mcv.getReg() orelse dst_reg, max_abi_size),
                try rhs_mcv.mem(self, Memory.Size.fromSize(max_abi_size)),
                Immediate.u(control),
            ) else try self.asmRegisterRegisterRegisterImmediate(
                .{ .v_ps, .shuf },
                dst_alias,
                registerAlias(lhs_mcv.getReg() orelse dst_reg, max_abi_size),
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(operand_tys[sources[1].?], rhs_mcv), max_abi_size),
                Immediate.u(control),
            ) else if (rhs_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
                .{ ._ps, .shuf },
                dst_alias,
                try rhs_mcv.mem(self, Memory.Size.fromSize(max_abi_size)),
                Immediate.u(control),
            ) else try self.asmRegisterRegisterImmediate(
                .{ ._ps, .shuf },
                dst_alias,
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(operand_tys[sources[1].?], rhs_mcv), max_abi_size),
                Immediate.u(control),
            );
            break :result dst_mcv;
        }

        shufpd: {
            if (elem_abi_size != 8) break :shufpd;
            if (max_abi_size > @as(u32, if (has_avx) 32 else 16)) break :shufpd;

            var control: u4 = 0b0_0_0_0;
            var sources = [1]?u1{null} ** 2;
            for (mask_elems, 0..) |maybe_mask_elem, elem_index| {
                const mask_elem = maybe_mask_elem orelse continue;
                const mask_elem_index: u2 = @intCast(if (mask_elem < 0) ~mask_elem else mask_elem);
                if (mask_elem_index & 0b10 != elem_index & 0b10) break :shufpd;

                const source = @intFromBool(mask_elem < 0);
                if (sources[elem_index & 0b01]) |prev_source| {
                    if (source != prev_source) break :shufpd;
                } else sources[elem_index & 0b01] = source;

                control |= @as(u4, @intCast(mask_elem_index & 0b01)) << @intCast(elem_index);
            }
            if (sources[0] orelse break :shufpd == sources[1] orelse break :shufpd) break :shufpd;

            const operands: [2]Air.Inst.Ref = .{ extra.a, extra.b };
            const operand_tys: [2]Type = .{ lhs_ty, rhs_ty };
            const lhs_mcv = try self.resolveInst(operands[sources[0].?]);
            const rhs_mcv = try self.resolveInst(operands[sources[1].?]);

            const dst_mcv: MCValue = if (lhs_mcv.isRegister() and
                self.reuseOperand(inst, operands[sources[0].?], sources[0].?, lhs_mcv))
                lhs_mcv
            else if (has_avx and lhs_mcv.isRegister())
                .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
            else
                try self.copyToRegisterWithInstTracking(inst, operand_tys[sources[0].?], lhs_mcv);
            const dst_reg = dst_mcv.getReg().?;
            const dst_alias = registerAlias(dst_reg, max_abi_size);

            if (has_avx) if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                .{ .v_pd, .shuf },
                dst_alias,
                registerAlias(lhs_mcv.getReg() orelse dst_reg, max_abi_size),
                try rhs_mcv.mem(self, Memory.Size.fromSize(max_abi_size)),
                Immediate.u(control),
            ) else try self.asmRegisterRegisterRegisterImmediate(
                .{ .v_pd, .shuf },
                dst_alias,
                registerAlias(lhs_mcv.getReg() orelse dst_reg, max_abi_size),
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(operand_tys[sources[1].?], rhs_mcv), max_abi_size),
                Immediate.u(control),
            ) else if (rhs_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
                .{ ._pd, .shuf },
                dst_alias,
                try rhs_mcv.mem(self, Memory.Size.fromSize(max_abi_size)),
                Immediate.u(control),
            ) else try self.asmRegisterRegisterImmediate(
                .{ ._pd, .shuf },
                dst_alias,
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(operand_tys[sources[1].?], rhs_mcv), max_abi_size),
                Immediate.u(control),
            );
            break :result dst_mcv;
        }

        blend: {
            if (elem_abi_size < 2) break :blend;
            if (dst_abi_size > @as(u32, if (has_avx) 32 else 16)) break :blend;
            if (!self.hasFeature(.sse4_1)) break :blend;

            var control: u8 = 0b0_0_0_0_0_0_0_0;
            for (mask_elems, 0..) |maybe_mask_elem, elem_index| {
                const mask_elem = maybe_mask_elem orelse continue;
                const mask_elem_index =
                    math.cast(u4, if (mask_elem < 0) ~mask_elem else mask_elem) orelse break :blend;
                if (mask_elem_index != elem_index) break :blend;

                const select = @as(u8, @intFromBool(mask_elem < 0)) << @truncate(elem_index);
                if (elem_index & 0b1000 == 0)
                    control |= select
                else if (control & @as(u8, 0b1) << @truncate(elem_index) != select) break :blend;
            }

            if (!elem_ty.isRuntimeFloat() and self.hasFeature(.avx2)) vpblendd: {
                const expanded_control = switch (elem_abi_size) {
                    4 => control,
                    8 => @as(u8, if (control & 0b0001 != 0) 0b00_00_00_11 else 0b00_00_00_00) |
                        @as(u8, if (control & 0b0010 != 0) 0b00_00_11_00 else 0b00_00_00_00) |
                        @as(u8, if (control & 0b0100 != 0) 0b00_11_00_00 else 0b00_00_00_00) |
                        @as(u8, if (control & 0b1000 != 0) 0b11_00_00_00 else 0b00_00_00_00),
                    else => break :vpblendd,
                };

                const lhs_mcv = try self.resolveInst(extra.a);
                const lhs_reg = if (lhs_mcv.isRegister())
                    lhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(dst_ty, lhs_mcv);
                const lhs_lock = self.register_manager.lockReg(lhs_reg);
                defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

                const rhs_mcv = try self.resolveInst(extra.b);
                const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.sse);
                if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                    .{ .vp_d, .blend },
                    registerAlias(dst_reg, dst_abi_size),
                    registerAlias(lhs_reg, dst_abi_size),
                    try rhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
                    Immediate.u(expanded_control),
                ) else try self.asmRegisterRegisterRegisterImmediate(
                    .{ .vp_d, .blend },
                    registerAlias(dst_reg, dst_abi_size),
                    registerAlias(lhs_reg, dst_abi_size),
                    registerAlias(if (rhs_mcv.isRegister())
                        rhs_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(dst_ty, rhs_mcv), dst_abi_size),
                    Immediate.u(expanded_control),
                );
                break :result .{ .register = dst_reg };
            }

            if (!elem_ty.isRuntimeFloat() or elem_abi_size == 2) pblendw: {
                const expanded_control = switch (elem_abi_size) {
                    2 => control,
                    4 => if (dst_abi_size <= 16 or
                        @as(u4, @intCast(control >> 4)) == @as(u4, @truncate(control >> 0)))
                        @as(u8, if (control & 0b0001 != 0) 0b00_00_00_11 else 0b00_00_00_00) |
                            @as(u8, if (control & 0b0010 != 0) 0b00_00_11_00 else 0b00_00_00_00) |
                            @as(u8, if (control & 0b0100 != 0) 0b00_11_00_00 else 0b00_00_00_00) |
                            @as(u8, if (control & 0b1000 != 0) 0b11_00_00_00 else 0b00_00_00_00)
                    else
                        break :pblendw,
                    8 => if (dst_abi_size <= 16 or
                        @as(u2, @intCast(control >> 2)) == @as(u2, @truncate(control >> 0)))
                        @as(u8, if (control & 0b01 != 0) 0b0000_1111 else 0b0000_0000) |
                            @as(u8, if (control & 0b10 != 0) 0b1111_0000 else 0b0000_0000)
                    else
                        break :pblendw,
                    16 => break :pblendw,
                    else => unreachable,
                };

                const lhs_mcv = try self.resolveInst(extra.a);
                const rhs_mcv = try self.resolveInst(extra.b);

                const dst_mcv: MCValue = if (lhs_mcv.isRegister() and
                    self.reuseOperand(inst, extra.a, 0, lhs_mcv))
                    lhs_mcv
                else if (has_avx and lhs_mcv.isRegister())
                    .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
                else
                    try self.copyToRegisterWithInstTracking(inst, dst_ty, lhs_mcv);
                const dst_reg = dst_mcv.getReg().?;

                if (has_avx) if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                    .{ .vp_w, .blend },
                    registerAlias(dst_reg, dst_abi_size),
                    registerAlias(if (lhs_mcv.isRegister())
                        lhs_mcv.getReg().?
                    else
                        dst_reg, dst_abi_size),
                    try rhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
                    Immediate.u(expanded_control),
                ) else try self.asmRegisterRegisterRegisterImmediate(
                    .{ .vp_w, .blend },
                    registerAlias(dst_reg, dst_abi_size),
                    registerAlias(if (lhs_mcv.isRegister())
                        lhs_mcv.getReg().?
                    else
                        dst_reg, dst_abi_size),
                    registerAlias(if (rhs_mcv.isRegister())
                        rhs_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(dst_ty, rhs_mcv), dst_abi_size),
                    Immediate.u(expanded_control),
                ) else if (rhs_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
                    .{ .p_w, .blend },
                    registerAlias(dst_reg, dst_abi_size),
                    try rhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
                    Immediate.u(expanded_control),
                ) else try self.asmRegisterRegisterImmediate(
                    .{ .p_w, .blend },
                    registerAlias(dst_reg, dst_abi_size),
                    registerAlias(if (rhs_mcv.isRegister())
                        rhs_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(dst_ty, rhs_mcv), dst_abi_size),
                    Immediate.u(expanded_control),
                );
                break :result .{ .register = dst_reg };
            }

            const expanded_control = switch (elem_abi_size) {
                4, 8 => control,
                16 => @as(u4, if (control & 0b01 != 0) 0b00_11 else 0b00_00) |
                    @as(u4, if (control & 0b10 != 0) 0b11_00 else 0b00_00),
                else => unreachable,
            };

            const lhs_mcv = try self.resolveInst(extra.a);
            const rhs_mcv = try self.resolveInst(extra.b);

            const dst_mcv: MCValue = if (lhs_mcv.isRegister() and
                self.reuseOperand(inst, extra.a, 0, lhs_mcv))
                lhs_mcv
            else if (has_avx and lhs_mcv.isRegister())
                .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
            else
                try self.copyToRegisterWithInstTracking(inst, dst_ty, lhs_mcv);
            const dst_reg = dst_mcv.getReg().?;

            if (has_avx) if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryImmediate(
                switch (elem_abi_size) {
                    4 => .{ .v_ps, .blend },
                    8, 16 => .{ .v_pd, .blend },
                    else => unreachable,
                },
                registerAlias(dst_reg, dst_abi_size),
                registerAlias(if (lhs_mcv.isRegister())
                    lhs_mcv.getReg().?
                else
                    dst_reg, dst_abi_size),
                try rhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
                Immediate.u(expanded_control),
            ) else try self.asmRegisterRegisterRegisterImmediate(
                switch (elem_abi_size) {
                    4 => .{ .v_ps, .blend },
                    8, 16 => .{ .v_pd, .blend },
                    else => unreachable,
                },
                registerAlias(dst_reg, dst_abi_size),
                registerAlias(if (lhs_mcv.isRegister())
                    lhs_mcv.getReg().?
                else
                    dst_reg, dst_abi_size),
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(dst_ty, rhs_mcv), dst_abi_size),
                Immediate.u(expanded_control),
            ) else if (rhs_mcv.isMemory()) try self.asmRegisterMemoryImmediate(
                switch (elem_abi_size) {
                    4 => .{ ._ps, .blend },
                    8, 16 => .{ ._pd, .blend },
                    else => unreachable,
                },
                registerAlias(dst_reg, dst_abi_size),
                try rhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
                Immediate.u(expanded_control),
            ) else try self.asmRegisterRegisterImmediate(
                switch (elem_abi_size) {
                    4 => .{ ._ps, .blend },
                    8, 16 => .{ ._pd, .blend },
                    else => unreachable,
                },
                registerAlias(dst_reg, dst_abi_size),
                registerAlias(if (rhs_mcv.isRegister())
                    rhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(dst_ty, rhs_mcv), dst_abi_size),
                Immediate.u(expanded_control),
            );
            break :result .{ .register = dst_reg };
        }

        blendv: {
            if (dst_abi_size > @as(u32, if (if (elem_abi_size >= 4)
                has_avx
            else
                self.hasFeature(.avx2)) 32 else 16)) break :blendv;

            const select_mask_elem_ty = try pt.intType(.unsigned, elem_abi_size * 8);
            const select_mask_ty = try pt.vectorType(.{
                .len = @intCast(mask_elems.len),
                .child = select_mask_elem_ty.toIntern(),
            });
            var select_mask_elems: [32]InternPool.Index = undefined;
            for (
                select_mask_elems[0..mask_elems.len],
                mask_elems,
                0..,
            ) |*select_mask_elem, maybe_mask_elem, elem_index| {
                const mask_elem = maybe_mask_elem orelse continue;
                const mask_elem_index =
                    math.cast(u5, if (mask_elem < 0) ~mask_elem else mask_elem) orelse break :blendv;
                if (mask_elem_index != elem_index) break :blendv;

                select_mask_elem.* = (if (mask_elem < 0)
                    try select_mask_elem_ty.maxIntScalar(pt, select_mask_elem_ty)
                else
                    try select_mask_elem_ty.minIntScalar(pt, select_mask_elem_ty)).toIntern();
            }
            const select_mask_mcv = try self.genTypedValue(Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = select_mask_ty.toIntern(),
                .storage = .{ .elems = select_mask_elems[0..mask_elems.len] },
            } })));

            if (self.hasFeature(.sse4_1)) {
                const mir_tag: Mir.Inst.FixedTag = .{
                    if ((elem_abi_size >= 4 and elem_ty.isRuntimeFloat()) or
                        (dst_abi_size > 16 and !self.hasFeature(.avx2))) switch (elem_abi_size) {
                        4 => if (has_avx) .v_ps else ._ps,
                        8 => if (has_avx) .v_pd else ._pd,
                        else => unreachable,
                    } else if (has_avx) .vp_b else .p_b,
                    .blendv,
                };

                const select_mask_reg = if (!has_avx) reg: {
                    try self.register_manager.getKnownReg(.xmm0, null);
                    try self.genSetReg(.xmm0, select_mask_elem_ty, select_mask_mcv, .{});
                    break :reg .xmm0;
                } else try self.copyToTmpRegister(select_mask_ty, select_mask_mcv);
                const select_mask_alias = registerAlias(select_mask_reg, dst_abi_size);
                const select_mask_lock = self.register_manager.lockRegAssumeUnused(select_mask_reg);
                defer self.register_manager.unlockReg(select_mask_lock);

                const lhs_mcv = try self.resolveInst(extra.a);
                const rhs_mcv = try self.resolveInst(extra.b);

                const dst_mcv: MCValue = if (lhs_mcv.isRegister() and
                    self.reuseOperand(inst, extra.a, 0, lhs_mcv))
                    lhs_mcv
                else if (has_avx and lhs_mcv.isRegister())
                    .{ .register = try self.register_manager.allocReg(inst, abi.RegisterClass.sse) }
                else
                    try self.copyToRegisterWithInstTracking(inst, dst_ty, lhs_mcv);
                const dst_reg = dst_mcv.getReg().?;
                const dst_alias = registerAlias(dst_reg, dst_abi_size);

                if (has_avx) if (rhs_mcv.isMemory()) try self.asmRegisterRegisterMemoryRegister(
                    mir_tag,
                    dst_alias,
                    if (lhs_mcv.isRegister())
                        registerAlias(lhs_mcv.getReg().?, dst_abi_size)
                    else
                        dst_alias,
                    try rhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
                    select_mask_alias,
                ) else try self.asmRegisterRegisterRegisterRegister(
                    mir_tag,
                    dst_alias,
                    if (lhs_mcv.isRegister())
                        registerAlias(lhs_mcv.getReg().?, dst_abi_size)
                    else
                        dst_alias,
                    registerAlias(if (rhs_mcv.isRegister())
                        rhs_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(dst_ty, rhs_mcv), dst_abi_size),
                    select_mask_alias,
                ) else if (rhs_mcv.isMemory()) try self.asmRegisterMemoryRegister(
                    mir_tag,
                    dst_alias,
                    try rhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
                    select_mask_alias,
                ) else try self.asmRegisterRegisterRegister(
                    mir_tag,
                    dst_alias,
                    registerAlias(if (rhs_mcv.isRegister())
                        rhs_mcv.getReg().?
                    else
                        try self.copyToTmpRegister(dst_ty, rhs_mcv), dst_abi_size),
                    select_mask_alias,
                );
                break :result dst_mcv;
            }

            const lhs_mcv = try self.resolveInst(extra.a);
            const rhs_mcv = try self.resolveInst(extra.b);

            const dst_mcv: MCValue = if (rhs_mcv.isRegister() and
                self.reuseOperand(inst, extra.b, 1, rhs_mcv))
                rhs_mcv
            else
                try self.copyToRegisterWithInstTracking(inst, dst_ty, rhs_mcv);
            const dst_reg = dst_mcv.getReg().?;
            const dst_alias = registerAlias(dst_reg, dst_abi_size);

            const mask_reg = try self.copyToTmpRegister(select_mask_ty, select_mask_mcv);
            const mask_alias = registerAlias(mask_reg, dst_abi_size);
            const mask_lock = self.register_manager.lockRegAssumeUnused(mask_reg);
            defer self.register_manager.unlockReg(mask_lock);

            const mir_fixes: Mir.Inst.Fixes = if (elem_ty.isRuntimeFloat())
                switch (elem_ty.floatBits(self.target.*)) {
                    16, 80, 128 => .p_,
                    32 => ._ps,
                    64 => ._pd,
                    else => unreachable,
                }
            else
                .p_;
            try self.asmRegisterRegister(.{ mir_fixes, .@"and" }, dst_alias, mask_alias);
            if (lhs_mcv.isMemory()) try self.asmRegisterMemory(
                .{ mir_fixes, .andn },
                mask_alias,
                try lhs_mcv.mem(self, Memory.Size.fromSize(dst_abi_size)),
            ) else try self.asmRegisterRegister(
                .{ mir_fixes, .andn },
                mask_alias,
                if (lhs_mcv.isRegister())
                    lhs_mcv.getReg().?
                else
                    try self.copyToTmpRegister(dst_ty, lhs_mcv),
            );
            try self.asmRegisterRegister(.{ mir_fixes, .@"or" }, dst_alias, mask_alias);
            break :result dst_mcv;
        }

        pshufb: {
            if (max_abi_size > 16) break :pshufb;
            if (!self.hasFeature(.ssse3)) break :pshufb;

            const temp_regs =
                try self.register_manager.allocRegs(2, .{ inst, null }, abi.RegisterClass.sse);
            const temp_locks = self.register_manager.lockRegsAssumeUnused(2, temp_regs);
            defer for (temp_locks) |lock| self.register_manager.unlockReg(lock);

            const lhs_temp_alias = registerAlias(temp_regs[0], max_abi_size);
            try self.genSetReg(temp_regs[0], lhs_ty, .{ .air_ref = extra.a }, .{});

            const rhs_temp_alias = registerAlias(temp_regs[1], max_abi_size);
            try self.genSetReg(temp_regs[1], rhs_ty, .{ .air_ref = extra.b }, .{});

            var lhs_mask_elems: [16]InternPool.Index = undefined;
            for (lhs_mask_elems[0..max_abi_size], 0..) |*lhs_mask_elem, byte_index| {
                const elem_index = byte_index / elem_abi_size;
                lhs_mask_elem.* = try pt.intern(.{ .int = .{
                    .ty = .u8_type,
                    .storage = .{ .u64 = if (elem_index >= mask_elems.len) 0b1_00_00000 else elem: {
                        const mask_elem = mask_elems[elem_index] orelse break :elem 0b1_00_00000;
                        if (mask_elem < 0) break :elem 0b1_00_00000;
                        const mask_elem_index: u31 = @intCast(mask_elem);
                        const byte_off: u32 = @intCast(byte_index % elem_abi_size);
                        break :elem @intCast(mask_elem_index * elem_abi_size + byte_off);
                    } },
                } });
            }
            const lhs_mask_ty = try pt.vectorType(.{ .len = max_abi_size, .child = .u8_type });
            const lhs_mask_mcv = try self.genTypedValue(Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = lhs_mask_ty.toIntern(),
                .storage = .{ .elems = lhs_mask_elems[0..max_abi_size] },
            } })));
            const lhs_mask_mem: Memory = .{
                .base = .{ .reg = try self.copyToTmpRegister(Type.usize, lhs_mask_mcv.address()) },
                .mod = .{ .rm = .{ .size = Memory.Size.fromSize(@max(max_abi_size, 16)) } },
            };
            if (has_avx) try self.asmRegisterRegisterMemory(
                .{ .vp_b, .shuf },
                lhs_temp_alias,
                lhs_temp_alias,
                lhs_mask_mem,
            ) else try self.asmRegisterMemory(
                .{ .p_b, .shuf },
                lhs_temp_alias,
                lhs_mask_mem,
            );

            var rhs_mask_elems: [16]InternPool.Index = undefined;
            for (rhs_mask_elems[0..max_abi_size], 0..) |*rhs_mask_elem, byte_index| {
                const elem_index = byte_index / elem_abi_size;
                rhs_mask_elem.* = try pt.intern(.{ .int = .{
                    .ty = .u8_type,
                    .storage = .{ .u64 = if (elem_index >= mask_elems.len) 0b1_00_00000 else elem: {
                        const mask_elem = mask_elems[elem_index] orelse break :elem 0b1_00_00000;
                        if (mask_elem >= 0) break :elem 0b1_00_00000;
                        const mask_elem_index: u31 = @intCast(~mask_elem);
                        const byte_off: u32 = @intCast(byte_index % elem_abi_size);
                        break :elem @intCast(mask_elem_index * elem_abi_size + byte_off);
                    } },
                } });
            }
            const rhs_mask_ty = try pt.vectorType(.{ .len = max_abi_size, .child = .u8_type });
            const rhs_mask_mcv = try self.genTypedValue(Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = rhs_mask_ty.toIntern(),
                .storage = .{ .elems = rhs_mask_elems[0..max_abi_size] },
            } })));
            const rhs_mask_mem: Memory = .{
                .base = .{ .reg = try self.copyToTmpRegister(Type.usize, rhs_mask_mcv.address()) },
                .mod = .{ .rm = .{ .size = Memory.Size.fromSize(@max(max_abi_size, 16)) } },
            };
            if (has_avx) try self.asmRegisterRegisterMemory(
                .{ .vp_b, .shuf },
                rhs_temp_alias,
                rhs_temp_alias,
                rhs_mask_mem,
            ) else try self.asmRegisterMemory(
                .{ .p_b, .shuf },
                rhs_temp_alias,
                rhs_mask_mem,
            );

            if (has_avx) try self.asmRegisterRegisterRegister(
                .{ switch (elem_ty.zigTypeTag(zcu)) {
                    else => break :result null,
                    .int => .vp_,
                    .float => switch (elem_ty.floatBits(self.target.*)) {
                        32 => .v_ps,
                        64 => .v_pd,
                        16, 80, 128 => break :result null,
                        else => unreachable,
                    },
                }, .@"or" },
                lhs_temp_alias,
                lhs_temp_alias,
                rhs_temp_alias,
            ) else try self.asmRegisterRegister(
                .{ switch (elem_ty.zigTypeTag(zcu)) {
                    else => break :result null,
                    .int => .p_,
                    .float => switch (elem_ty.floatBits(self.target.*)) {
                        32 => ._ps,
                        64 => ._pd,
                        16, 80, 128 => break :result null,
                        else => unreachable,
                    },
                }, .@"or" },
                lhs_temp_alias,
                rhs_temp_alias,
            );
            break :result .{ .register = temp_regs[0] };
        }

        break :result null;
    }) orelse return self.fail("TODO implement airShuffle from {} and {} to {} with {}", .{
        lhs_ty.fmt(pt),                              rhs_ty.fmt(pt), dst_ty.fmt(pt),
        Value.fromInterned(extra.mask).fmtValue(pt),
    });
    return self.finishAir(inst, result, .{ extra.a, extra.b, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const reduce = self.air.instructions.items(.data)[@intFromEnum(inst)].reduce;

    const result: MCValue = result: {
        const operand_ty = self.typeOf(reduce.operand);
        if (operand_ty.isVector(zcu) and operand_ty.childType(zcu).toIntern() == .bool_type) {
            try self.spillEflagsIfOccupied();

            const operand_mcv = try self.resolveInst(reduce.operand);
            const mask_len = (math.cast(u6, operand_ty.vectorLen(zcu)) orelse
                return self.fail("TODO implement airReduce for {}", .{operand_ty.fmt(pt)}));
            const mask = (@as(u64, 1) << mask_len) - 1;
            const abi_size: u32 = @intCast(operand_ty.abiSize(zcu));
            switch (reduce.operation) {
                .Or => {
                    if (operand_mcv.isMemory()) try self.asmMemoryImmediate(
                        .{ ._, .@"test" },
                        try operand_mcv.mem(self, Memory.Size.fromSize(abi_size)),
                        Immediate.u(mask),
                    ) else {
                        const operand_reg = registerAlias(if (operand_mcv.isRegister())
                            operand_mcv.getReg().?
                        else
                            try self.copyToTmpRegister(operand_ty, operand_mcv), abi_size);
                        if (mask_len < abi_size * 8) try self.asmRegisterImmediate(
                            .{ ._, .@"test" },
                            operand_reg,
                            Immediate.u(mask),
                        ) else try self.asmRegisterRegister(
                            .{ ._, .@"test" },
                            operand_reg,
                            operand_reg,
                        );
                    }
                    break :result .{ .eflags = .nz };
                },
                .And => {
                    const tmp_reg = try self.copyToTmpRegister(operand_ty, operand_mcv);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    try self.asmRegister(.{ ._, .not }, tmp_reg);
                    if (mask_len < abi_size * 8)
                        try self.asmRegisterImmediate(.{ ._, .@"test" }, tmp_reg, Immediate.u(mask))
                    else
                        try self.asmRegisterRegister(.{ ._, .@"test" }, tmp_reg, tmp_reg);
                    break :result .{ .eflags = .z };
                },
                else => return self.fail("TODO implement airReduce for {}", .{operand_ty.fmt(pt)}),
            }
        }
        return self.fail("TODO implement airReduce for {}", .{operand_ty.fmt(pt)});
    };
    return self.finishAir(inst, result, .{ reduce.operand, .none, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const result_ty = self.typeOfIndex(inst);
    const len: usize = @intCast(result_ty.arrayLen(zcu));
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const elements: []const Air.Inst.Ref = @ptrCast(self.air.extra[ty_pl.payload..][0..len]);
    const result: MCValue = result: {
        switch (result_ty.zigTypeTag(zcu)) {
            .@"struct" => {
                const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(result_ty, zcu));
                if (result_ty.containerLayout(zcu) == .@"packed") {
                    const struct_obj = zcu.typeToStruct(result_ty).?;
                    try self.genInlineMemset(
                        .{ .lea_frame = .{ .index = frame_index } },
                        .{ .immediate = 0 },
                        .{ .immediate = result_ty.abiSize(zcu) },
                        .{},
                    );
                    for (elements, 0..) |elem, elem_i_usize| {
                        const elem_i: u32 = @intCast(elem_i_usize);
                        if ((try result_ty.structFieldValueComptime(pt, elem_i)) != null) continue;

                        const elem_ty = result_ty.fieldType(elem_i, zcu);
                        const elem_bit_size: u32 = @intCast(elem_ty.bitSize(zcu));
                        if (elem_bit_size > 64) {
                            return self.fail(
                                "TODO airAggregateInit implement packed structs with large fields",
                                .{},
                            );
                        }
                        const elem_abi_size: u32 = @intCast(elem_ty.abiSize(zcu));
                        const elem_abi_bits = elem_abi_size * 8;
                        const elem_off = pt.structPackedFieldBitOffset(struct_obj, elem_i);
                        const elem_byte_off: i32 = @intCast(elem_off / elem_abi_bits * elem_abi_size);
                        const elem_bit_off = elem_off % elem_abi_bits;
                        const elem_mcv = try self.resolveInst(elem);
                        const mat_elem_mcv = switch (elem_mcv) {
                            .load_tlv => |sym_index| MCValue{ .lea_tlv = sym_index },
                            else => elem_mcv,
                        };
                        const elem_lock = switch (mat_elem_mcv) {
                            .register => |reg| self.register_manager.lockReg(reg),
                            .immediate => |imm| lock: {
                                if (imm == 0) continue;
                                break :lock null;
                            },
                            else => null,
                        };
                        defer if (elem_lock) |lock| self.register_manager.unlockReg(lock);

                        const elem_extra_bits = self.regExtraBits(elem_ty);
                        {
                            const temp_reg = try self.copyToTmpRegister(elem_ty, mat_elem_mcv);
                            const temp_alias = registerAlias(temp_reg, elem_abi_size);
                            const temp_lock = self.register_manager.lockRegAssumeUnused(temp_reg);
                            defer self.register_manager.unlockReg(temp_lock);

                            if (elem_bit_off < elem_extra_bits) {
                                try self.truncateRegister(elem_ty, temp_alias);
                            }
                            if (elem_bit_off > 0) try self.genShiftBinOpMir(
                                .{ ._l, .sh },
                                elem_ty,
                                .{ .register = temp_alias },
                                Type.u8,
                                .{ .immediate = elem_bit_off },
                            );
                            try self.genBinOpMir(
                                .{ ._, .@"or" },
                                elem_ty,
                                .{ .load_frame = .{ .index = frame_index, .off = elem_byte_off } },
                                .{ .register = temp_alias },
                            );
                        }
                        if (elem_bit_off > elem_extra_bits) {
                            const temp_reg = try self.copyToTmpRegister(elem_ty, mat_elem_mcv);
                            const temp_alias = registerAlias(temp_reg, elem_abi_size);
                            const temp_lock = self.register_manager.lockRegAssumeUnused(temp_reg);
                            defer self.register_manager.unlockReg(temp_lock);

                            if (elem_extra_bits > 0) {
                                try self.truncateRegister(elem_ty, temp_alias);
                            }
                            try self.genShiftBinOpMir(
                                .{ ._r, .sh },
                                elem_ty,
                                .{ .register = temp_reg },
                                Type.u8,
                                .{ .immediate = elem_abi_bits - elem_bit_off },
                            );
                            try self.genBinOpMir(
                                .{ ._, .@"or" },
                                elem_ty,
                                .{ .load_frame = .{
                                    .index = frame_index,
                                    .off = elem_byte_off + @as(i32, @intCast(elem_abi_size)),
                                } },
                                .{ .register = temp_alias },
                            );
                        }
                    }
                } else for (elements, 0..) |elem, elem_i| {
                    if ((try result_ty.structFieldValueComptime(pt, elem_i)) != null) continue;

                    const elem_ty = result_ty.fieldType(elem_i, zcu);
                    const elem_off: i32 = @intCast(result_ty.structFieldOffset(elem_i, zcu));
                    const elem_mcv = try self.resolveInst(elem);
                    const mat_elem_mcv = switch (elem_mcv) {
                        .load_tlv => |sym_index| MCValue{ .lea_tlv = sym_index },
                        else => elem_mcv,
                    };
                    try self.genSetMem(.{ .frame = frame_index }, elem_off, elem_ty, mat_elem_mcv, .{});
                }
                break :result .{ .load_frame = .{ .index = frame_index } };
            },
            .array, .vector => {
                const elem_ty = result_ty.childType(zcu);
                if (result_ty.isVector(zcu) and elem_ty.toIntern() == .bool_type) {
                    const result_size: u32 = @intCast(result_ty.abiSize(zcu));
                    const dst_reg = try self.register_manager.allocReg(inst, abi.RegisterClass.gp);
                    try self.asmRegisterRegister(
                        .{ ._, .xor },
                        registerAlias(dst_reg, @min(result_size, 4)),
                        registerAlias(dst_reg, @min(result_size, 4)),
                    );

                    for (elements, 0..) |elem, elem_i| {
                        const elem_reg = try self.copyToTmpRegister(elem_ty, .{ .air_ref = elem });
                        const elem_lock = self.register_manager.lockRegAssumeUnused(elem_reg);
                        defer self.register_manager.unlockReg(elem_lock);

                        try self.asmRegisterImmediate(
                            .{ ._, .@"and" },
                            registerAlias(elem_reg, @min(result_size, 4)),
                            Immediate.u(1),
                        );
                        if (elem_i > 0) try self.asmRegisterImmediate(
                            .{ ._l, .sh },
                            registerAlias(elem_reg, result_size),
                            Immediate.u(@intCast(elem_i)),
                        );
                        try self.asmRegisterRegister(
                            .{ ._, .@"or" },
                            registerAlias(dst_reg, result_size),
                            registerAlias(elem_reg, result_size),
                        );
                    }
                    break :result .{ .register = dst_reg };
                } else {
                    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(result_ty, zcu));
                    const elem_size: u32 = @intCast(elem_ty.abiSize(zcu));

                    for (elements, 0..) |elem, elem_i| {
                        const elem_mcv = try self.resolveInst(elem);
                        const mat_elem_mcv = switch (elem_mcv) {
                            .load_tlv => |sym_index| MCValue{ .lea_tlv = sym_index },
                            else => elem_mcv,
                        };
                        const elem_off: i32 = @intCast(elem_size * elem_i);
                        try self.genSetMem(
                            .{ .frame = frame_index },
                            elem_off,
                            elem_ty,
                            mat_elem_mcv,
                            .{},
                        );
                    }
                    if (result_ty.sentinel(zcu)) |sentinel| try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(elem_size * elements.len),
                        elem_ty,
                        try self.genTypedValue(sentinel),
                        .{},
                    );
                    break :result .{ .load_frame = .{ .index = frame_index } };
                }
            },
            else => unreachable,
        }
    };

    if (elements.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        @memcpy(buf[0..elements.len], elements);
        return self.finishAir(inst, result, buf);
    }
    var bt = self.liveness.iterateBigTomb(inst);
    for (elements) |elem| try self.feed(&bt, elem);
    return self.finishAirResult(inst, result);
}

fn airUnionInit(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
    const result: MCValue = result: {
        const union_ty = self.typeOfIndex(inst);
        const layout = union_ty.unionGetLayout(zcu);

        const src_ty = self.typeOf(extra.init);
        const src_mcv = try self.resolveInst(extra.init);
        if (layout.tag_size == 0) {
            if (layout.abi_size <= src_ty.abiSize(zcu) and
                self.reuseOperand(inst, extra.init, 0, src_mcv)) break :result src_mcv;

            const dst_mcv = try self.allocRegOrMem(inst, true);
            try self.genCopy(src_ty, dst_mcv, src_mcv, .{});
            break :result dst_mcv;
        }

        const dst_mcv = try self.allocRegOrMem(inst, false);

        const union_obj = zcu.typeToUnion(union_ty).?;
        const field_name = union_obj.loadTagType(ip).names.get(ip)[extra.field_index];
        const tag_ty = Type.fromInterned(union_obj.enum_tag_ty);
        const field_index = tag_ty.enumFieldIndex(field_name, zcu).?;
        const tag_val = try pt.enumValueFieldIndex(tag_ty, field_index);
        const tag_int_val = try tag_val.intFromEnum(tag_ty, pt);
        const tag_int = tag_int_val.toUnsignedInt(zcu);
        const tag_off: i32 = @intCast(layout.tagOffset());
        try self.genCopy(
            tag_ty,
            dst_mcv.address().offset(tag_off).deref(),
            .{ .immediate = tag_int },
            .{},
        );

        const pl_off: i32 = @intCast(layout.payloadOffset());
        try self.genCopy(src_ty, dst_mcv.address().offset(pl_off).deref(), src_mcv, .{});

        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ extra.init, .none, .none });
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;
    return self.finishAir(inst, .unreach, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const ty = self.typeOfIndex(inst);

    const ops = [3]Air.Inst.Ref{ extra.lhs, extra.rhs, pl_op.operand };
    const result = result: {
        if (switch (ty.scalarType(zcu).floatBits(self.target.*)) {
            16, 80, 128 => true,
            32, 64 => !self.hasFeature(.fma),
            else => unreachable,
        }) {
            if (ty.zigTypeTag(zcu) != .float) return self.fail("TODO implement airMulAdd for {}", .{
                ty.fmt(pt),
            });

            var callee_buf: ["__fma?".len]u8 = undefined;
            break :result try self.genCall(.{ .lib = .{
                .return_type = ty.toIntern(),
                .param_types = &.{ ty.toIntern(), ty.toIntern(), ty.toIntern() },
                .callee = std.fmt.bufPrint(&callee_buf, "{s}fma{s}", .{
                    floatLibcAbiPrefix(ty),
                    floatLibcAbiSuffix(ty),
                }) catch unreachable,
            } }, &.{ ty, ty, ty }, &.{
                .{ .air_ref = extra.lhs }, .{ .air_ref = extra.rhs }, .{ .air_ref = pl_op.operand },
            });
        }

        var mcvs: [3]MCValue = undefined;
        var locks = [1]?RegisterManager.RegisterLock{null} ** 3;
        defer for (locks) |reg_lock| if (reg_lock) |lock| self.register_manager.unlockReg(lock);
        var order = [1]u2{0} ** 3;
        var unused = std.StaticBitSet(3).initFull();
        for (ops, &mcvs, &locks, 0..) |op, *mcv, *lock, op_i| {
            const op_index: u2 = @intCast(op_i);
            mcv.* = try self.resolveInst(op);
            if (unused.isSet(0) and mcv.isRegister() and self.reuseOperand(inst, op, op_index, mcv.*)) {
                order[op_index] = 1;
                unused.unset(0);
            } else if (unused.isSet(2) and mcv.isMemory()) {
                order[op_index] = 3;
                unused.unset(2);
            }
            switch (mcv.*) {
                .register => |reg| lock.* = self.register_manager.lockReg(reg),
                else => {},
            }
        }
        for (&order, &mcvs, &locks) |*mop_index, *mcv, *lock| {
            if (mop_index.* != 0) continue;
            mop_index.* = 1 + @as(u2, @intCast(unused.toggleFirstSet().?));
            if (mop_index.* > 1 and mcv.isRegister()) continue;
            const reg = try self.copyToTmpRegister(ty, mcv.*);
            mcv.* = .{ .register = reg };
            if (lock.*) |old_lock| self.register_manager.unlockReg(old_lock);
            lock.* = self.register_manager.lockRegAssumeUnused(reg);
        }

        const mir_tag = @as(?Mir.Inst.FixedTag, if (mem.eql(u2, &order, &.{ 1, 3, 2 }) or
            mem.eql(u2, &order, &.{ 3, 1, 2 }))
            switch (ty.zigTypeTag(zcu)) {
                .float => switch (ty.floatBits(self.target.*)) {
                    32 => .{ .v_ss, .fmadd132 },
                    64 => .{ .v_sd, .fmadd132 },
                    16, 80, 128 => null,
                    else => unreachable,
                },
                .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                    .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                        32 => switch (ty.vectorLen(zcu)) {
                            1 => .{ .v_ss, .fmadd132 },
                            2...8 => .{ .v_ps, .fmadd132 },
                            else => null,
                        },
                        64 => switch (ty.vectorLen(zcu)) {
                            1 => .{ .v_sd, .fmadd132 },
                            2...4 => .{ .v_pd, .fmadd132 },
                            else => null,
                        },
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    else => unreachable,
                },
                else => unreachable,
            }
        else if (mem.eql(u2, &order, &.{ 2, 1, 3 }) or mem.eql(u2, &order, &.{ 1, 2, 3 }))
            switch (ty.zigTypeTag(zcu)) {
                .float => switch (ty.floatBits(self.target.*)) {
                    32 => .{ .v_ss, .fmadd213 },
                    64 => .{ .v_sd, .fmadd213 },
                    16, 80, 128 => null,
                    else => unreachable,
                },
                .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                    .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                        32 => switch (ty.vectorLen(zcu)) {
                            1 => .{ .v_ss, .fmadd213 },
                            2...8 => .{ .v_ps, .fmadd213 },
                            else => null,
                        },
                        64 => switch (ty.vectorLen(zcu)) {
                            1 => .{ .v_sd, .fmadd213 },
                            2...4 => .{ .v_pd, .fmadd213 },
                            else => null,
                        },
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    else => unreachable,
                },
                else => unreachable,
            }
        else if (mem.eql(u2, &order, &.{ 2, 3, 1 }) or mem.eql(u2, &order, &.{ 3, 2, 1 }))
            switch (ty.zigTypeTag(zcu)) {
                .float => switch (ty.floatBits(self.target.*)) {
                    32 => .{ .v_ss, .fmadd231 },
                    64 => .{ .v_sd, .fmadd231 },
                    16, 80, 128 => null,
                    else => unreachable,
                },
                .vector => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                    .float => switch (ty.childType(zcu).floatBits(self.target.*)) {
                        32 => switch (ty.vectorLen(zcu)) {
                            1 => .{ .v_ss, .fmadd231 },
                            2...8 => .{ .v_ps, .fmadd231 },
                            else => null,
                        },
                        64 => switch (ty.vectorLen(zcu)) {
                            1 => .{ .v_sd, .fmadd231 },
                            2...4 => .{ .v_pd, .fmadd231 },
                            else => null,
                        },
                        16, 80, 128 => null,
                        else => unreachable,
                    },
                    else => unreachable,
                },
                else => unreachable,
            }
        else
            unreachable) orelse return self.fail("TODO implement airMulAdd for {}", .{ty.fmt(pt)});

        var mops: [3]MCValue = undefined;
        for (order, mcvs) |mop_index, mcv| mops[mop_index - 1] = mcv;

        const abi_size: u32 = @intCast(ty.abiSize(zcu));
        const mop1_reg = registerAlias(mops[0].getReg().?, abi_size);
        const mop2_reg = registerAlias(mops[1].getReg().?, abi_size);
        if (mops[2].isRegister()) try self.asmRegisterRegisterRegister(
            mir_tag,
            mop1_reg,
            mop2_reg,
            registerAlias(mops[2].getReg().?, abi_size),
        ) else try self.asmRegisterRegisterMemory(
            mir_tag,
            mop1_reg,
            mop2_reg,
            try mops[2].mem(self, Memory.Size.fromSize(abi_size)),
        );
        break :result mops[0];
    };
    return self.finishAir(inst, result, ops);
}

fn airVaStart(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const va_list_ty = self.air.instructions.items(.data)[@intFromEnum(inst)].ty;
    const ptr_anyopaque_ty = try pt.singleMutPtrType(Type.anyopaque);

    const result: MCValue = switch (abi.resolveCallingConvention(
        self.fn_type.fnCallingConvention(zcu),
        self.target.*,
    )) {
        .SysV => result: {
            const info = self.va_info.sysv;
            const dst_fi = try self.allocFrameIndex(FrameAlloc.initSpill(va_list_ty, zcu));
            var field_off: u31 = 0;
            // gp_offset: c_uint,
            try self.genSetMem(
                .{ .frame = dst_fi },
                field_off,
                Type.c_uint,
                .{ .immediate = info.gp_count * 8 },
                .{},
            );
            field_off += @intCast(Type.c_uint.abiSize(zcu));
            // fp_offset: c_uint,
            try self.genSetMem(
                .{ .frame = dst_fi },
                field_off,
                Type.c_uint,
                .{ .immediate = abi.SysV.c_abi_int_param_regs.len * 8 + info.fp_count * 16 },
                .{},
            );
            field_off += @intCast(Type.c_uint.abiSize(zcu));
            // overflow_arg_area: *anyopaque,
            try self.genSetMem(
                .{ .frame = dst_fi },
                field_off,
                ptr_anyopaque_ty,
                .{ .lea_frame = info.overflow_arg_area },
                .{},
            );
            field_off += @intCast(ptr_anyopaque_ty.abiSize(zcu));
            // reg_save_area: *anyopaque,
            try self.genSetMem(
                .{ .frame = dst_fi },
                field_off,
                ptr_anyopaque_ty,
                .{ .lea_frame = info.reg_save_area },
                .{},
            );
            field_off += @intCast(ptr_anyopaque_ty.abiSize(zcu));
            break :result .{ .load_frame = .{ .index = dst_fi } };
        },
        .Win64 => return self.fail("TODO implement c_va_start for Win64", .{}),
        else => unreachable,
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airVaArg(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const ty = self.typeOfIndex(inst);
    const promote_ty = self.promoteVarArg(ty);
    const ptr_anyopaque_ty = try pt.singleMutPtrType(Type.anyopaque);
    const unused = self.liveness.isUnused(inst);

    const result: MCValue = switch (abi.resolveCallingConvention(
        self.fn_type.fnCallingConvention(zcu),
        self.target.*,
    )) {
        .SysV => result: {
            try self.spillEflagsIfOccupied();

            const tmp_regs =
                try self.register_manager.allocRegs(2, .{null} ** 2, abi.RegisterClass.gp);
            const offset_reg = tmp_regs[0].to32();
            const addr_reg = tmp_regs[1].to64();
            const tmp_locks = self.register_manager.lockRegsAssumeUnused(2, tmp_regs);
            defer for (tmp_locks) |lock| self.register_manager.unlockReg(lock);

            const promote_mcv = try self.allocTempRegOrMem(promote_ty, true);
            const promote_lock = switch (promote_mcv) {
                .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                else => null,
            };
            defer if (promote_lock) |lock| self.register_manager.unlockReg(lock);

            const ptr_arg_list_reg =
                try self.copyToTmpRegister(self.typeOf(ty_op.operand), .{ .air_ref = ty_op.operand });
            const ptr_arg_list_lock = self.register_manager.lockRegAssumeUnused(ptr_arg_list_reg);
            defer self.register_manager.unlockReg(ptr_arg_list_lock);

            const gp_offset: MCValue = .{ .indirect = .{ .reg = ptr_arg_list_reg, .off = 0 } };
            const fp_offset: MCValue = .{ .indirect = .{ .reg = ptr_arg_list_reg, .off = 4 } };
            const overflow_arg_area: MCValue = .{ .indirect = .{ .reg = ptr_arg_list_reg, .off = 8 } };
            const reg_save_area: MCValue = .{ .indirect = .{ .reg = ptr_arg_list_reg, .off = 16 } };

            const classes = mem.sliceTo(&abi.classifySystemV(promote_ty, zcu, self.target.*, .arg), .none);
            switch (classes[0]) {
                .integer => {
                    assert(classes.len == 1);

                    try self.genSetReg(offset_reg, Type.c_uint, gp_offset, .{});
                    try self.asmRegisterImmediate(.{ ._, .cmp }, offset_reg, Immediate.u(
                        abi.SysV.c_abi_int_param_regs.len * 8,
                    ));
                    const mem_reloc = try self.asmJccReloc(.ae, undefined);

                    try self.genSetReg(addr_reg, ptr_anyopaque_ty, reg_save_area, .{});
                    if (!unused) try self.asmRegisterMemory(.{ ._, .lea }, addr_reg, .{
                        .base = .{ .reg = addr_reg },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .index = offset_reg.to64(),
                        } },
                    });
                    try self.asmRegisterMemory(.{ ._, .lea }, offset_reg, .{
                        .base = .{ .reg = offset_reg.to64() },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .disp = 8,
                        } },
                    });
                    try self.genCopy(Type.c_uint, gp_offset, .{ .register = offset_reg }, .{});
                    const done_reloc = try self.asmJmpReloc(undefined);

                    self.performReloc(mem_reloc);
                    try self.genSetReg(addr_reg, ptr_anyopaque_ty, overflow_arg_area, .{});
                    try self.asmRegisterMemory(.{ ._, .lea }, offset_reg.to64(), .{
                        .base = .{ .reg = addr_reg },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .disp = @intCast(@max(promote_ty.abiSize(zcu), 8)),
                        } },
                    });
                    try self.genCopy(
                        ptr_anyopaque_ty,
                        overflow_arg_area,
                        .{ .register = offset_reg.to64() },
                        .{},
                    );

                    self.performReloc(done_reloc);
                    if (!unused) try self.genCopy(promote_ty, promote_mcv, .{
                        .indirect = .{ .reg = addr_reg },
                    }, .{});
                },
                .sse => {
                    assert(classes.len == 1);

                    try self.genSetReg(offset_reg, Type.c_uint, fp_offset, .{});
                    try self.asmRegisterImmediate(.{ ._, .cmp }, offset_reg, Immediate.u(
                        abi.SysV.c_abi_int_param_regs.len * 8 + abi.SysV.c_abi_sse_param_regs.len * 16,
                    ));
                    const mem_reloc = try self.asmJccReloc(.ae, undefined);

                    try self.genSetReg(addr_reg, ptr_anyopaque_ty, reg_save_area, .{});
                    if (!unused) try self.asmRegisterMemory(.{ ._, .lea }, addr_reg, .{
                        .base = .{ .reg = addr_reg },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .index = offset_reg.to64(),
                        } },
                    });
                    try self.asmRegisterMemory(.{ ._, .lea }, offset_reg, .{
                        .base = .{ .reg = offset_reg.to64() },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .disp = 16,
                        } },
                    });
                    try self.genCopy(Type.c_uint, fp_offset, .{ .register = offset_reg }, .{});
                    const done_reloc = try self.asmJmpReloc(undefined);

                    self.performReloc(mem_reloc);
                    try self.genSetReg(addr_reg, ptr_anyopaque_ty, overflow_arg_area, .{});
                    try self.asmRegisterMemory(.{ ._, .lea }, offset_reg.to64(), .{
                        .base = .{ .reg = addr_reg },
                        .mod = .{ .rm = .{
                            .size = .qword,
                            .disp = @intCast(@max(promote_ty.abiSize(zcu), 8)),
                        } },
                    });
                    try self.genCopy(
                        ptr_anyopaque_ty,
                        overflow_arg_area,
                        .{ .register = offset_reg.to64() },
                        .{},
                    );

                    self.performReloc(done_reloc);
                    if (!unused) try self.genCopy(promote_ty, promote_mcv, .{
                        .indirect = .{ .reg = addr_reg },
                    }, .{});
                },
                .memory => {
                    assert(classes.len == 1);
                    unreachable;
                },
                else => return self.fail("TODO implement c_va_arg for {} on SysV", .{
                    promote_ty.fmt(pt),
                }),
            }

            if (unused) break :result .unreach;
            if (ty.toIntern() == promote_ty.toIntern()) break :result promote_mcv;

            if (!promote_ty.isRuntimeFloat()) {
                const dst_mcv = try self.allocRegOrMem(inst, true);
                try self.genCopy(ty, dst_mcv, promote_mcv, .{});
                break :result dst_mcv;
            }

            assert(ty.toIntern() == .f32_type and promote_ty.toIntern() == .f64_type);
            const dst_mcv = if (promote_mcv.isRegister())
                promote_mcv
            else
                try self.copyToRegisterWithInstTracking(inst, ty, promote_mcv);
            const dst_reg = dst_mcv.getReg().?.to128();
            const dst_lock = self.register_manager.lockReg(dst_reg);
            defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

            if (self.hasFeature(.avx)) if (promote_mcv.isMemory()) try self.asmRegisterRegisterMemory(
                .{ .v_ss, .cvtsd2 },
                dst_reg,
                dst_reg,
                try promote_mcv.mem(self, .qword),
            ) else try self.asmRegisterRegisterRegister(
                .{ .v_ss, .cvtsd2 },
                dst_reg,
                dst_reg,
                (if (promote_mcv.isRegister())
                    promote_mcv.getReg().?
                else
                    try self.copyToTmpRegister(promote_ty, promote_mcv)).to128(),
            ) else if (promote_mcv.isMemory()) try self.asmRegisterMemory(
                .{ ._ss, .cvtsd2 },
                dst_reg,
                try promote_mcv.mem(self, .qword),
            ) else try self.asmRegisterRegister(
                .{ ._ss, .cvtsd2 },
                dst_reg,
                (if (promote_mcv.isRegister())
                    promote_mcv.getReg().?
                else
                    try self.copyToTmpRegister(promote_ty, promote_mcv)).to128(),
            );
            break :result promote_mcv;
        },
        .Win64 => return self.fail("TODO implement c_va_arg for Win64", .{}),
        else => unreachable,
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airVaCopy(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const ptr_va_list_ty = self.typeOf(ty_op.operand);

    const dst_mcv = try self.allocRegOrMem(inst, true);
    try self.load(dst_mcv, ptr_va_list_ty, .{ .air_ref = ty_op.operand });
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airVaEnd(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    return self.finishAir(inst, .unreach, .{ un_op, .none, .none });
}

fn resolveInst(self: *Self, ref: Air.Inst.Ref) InnerError!MCValue {
    const zcu = self.pt.zcu;
    const ty = self.typeOf(ref);

    // If the type has no codegen bits, no need to store it.
    if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;

    const mcv = if (ref.toIndex()) |inst| mcv: {
        break :mcv self.inst_tracking.getPtr(inst).?.short;
    } else mcv: {
        const ip_index = ref.toInterned().?;
        const gop = try self.const_tracking.getOrPut(self.gpa, ip_index);
        if (!gop.found_existing) gop.value_ptr.* = InstTracking.init(init: {
            const const_mcv = try self.genTypedValue(Value.fromInterned(ip_index));
            switch (const_mcv) {
                .lea_tlv => |tlv_sym| switch (self.bin_file.tag) {
                    .elf, .macho => {
                        if (self.mod.pic) {
                            try self.spillRegisters(&.{ .rdi, .rax });
                        } else {
                            try self.spillRegisters(&.{.rax});
                        }
                        const frame_index = try self.allocFrameIndex(FrameAlloc.init(.{
                            .size = 8,
                            .alignment = .@"8",
                        }));
                        try self.genSetMem(
                            .{ .frame = frame_index },
                            0,
                            Type.usize,
                            .{ .lea_symbol = .{ .sym_index = tlv_sym } },
                            .{},
                        );
                        break :init .{ .load_frame = .{ .index = frame_index } };
                    },
                    else => break :init const_mcv,
                },
                else => break :init const_mcv,
            }
        });
        break :mcv gop.value_ptr.short;
    };

    switch (mcv) {
        .none, .unreach, .dead => unreachable,
        else => return mcv,
    }
}

fn getResolvedInstValue(self: *Self, inst: Air.Inst.Index) *InstTracking {
    const tracking = self.inst_tracking.getPtr(inst).?;
    return switch (tracking.short) {
        .none, .unreach, .dead => unreachable,
        else => tracking,
    };
}

/// If the MCValue is an immediate, and it does not fit within this type,
/// we put it in a register.
/// A potential opportunity for future optimization here would be keeping track
/// of the fact that the instruction is available both as an immediate
/// and as a register.
fn limitImmediateType(self: *Self, operand: Air.Inst.Ref, comptime T: type) !MCValue {
    const mcv = try self.resolveInst(operand);
    const ti = @typeInfo(T).int;
    switch (mcv) {
        .immediate => |imm| {
            // This immediate is unsigned.
            const U = std.meta.Int(.unsigned, ti.bits - @intFromBool(ti.signedness == .signed));
            if (imm >= math.maxInt(U)) {
                return MCValue{ .register = try self.copyToTmpRegister(Type.usize, mcv) };
            }
        },
        else => {},
    }
    return mcv;
}

fn genTypedValue(self: *Self, val: Value) InnerError!MCValue {
    const pt = self.pt;
    return switch (try codegen.genTypedValue(self.bin_file, pt, self.src_loc, val, self.target.*)) {
        .mcv => |mcv| switch (mcv) {
            .none => .none,
            .undef => .undef,
            .immediate => |imm| .{ .immediate = imm },
            .memory => |addr| .{ .memory = addr },
            .load_symbol => |sym_index| .{ .load_symbol = .{ .sym_index = sym_index } },
            .lea_symbol => |sym_index| .{ .lea_symbol = .{ .sym_index = sym_index } },
            .load_direct => |sym_index| .{ .load_direct = sym_index },
            .lea_direct => |sym_index| .{ .lea_direct = sym_index },
            .load_got => |sym_index| .{ .lea_got = sym_index },
            .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
        },
        .fail => |msg| {
            self.err_msg = msg;
            return error.CodegenFail;
        },
    };
}

const CallMCValues = struct {
    args: []MCValue,
    return_value: InstTracking,
    stack_byte_count: u31,
    stack_align: Alignment,
    gp_count: u32,
    fp_count: u32,

    fn deinit(self: *CallMCValues, func: *Self) void {
        func.gpa.free(self.args);
        self.* = undefined;
    }
};

/// Caller must call `CallMCValues.deinit`.
fn resolveCallingConventionValues(
    self: *Self,
    fn_info: InternPool.Key.FuncType,
    var_args: []const Type,
    stack_frame_base: FrameIndex,
) !CallMCValues {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const cc = fn_info.cc;
    const param_types = try self.gpa.alloc(Type, fn_info.param_types.len + var_args.len);
    defer self.gpa.free(param_types);

    for (param_types[0..fn_info.param_types.len], fn_info.param_types.get(ip)) |*dest, src| {
        dest.* = Type.fromInterned(src);
    }
    for (param_types[fn_info.param_types.len..], var_args) |*param_ty, arg_ty|
        param_ty.* = self.promoteVarArg(arg_ty);

    var result: CallMCValues = .{
        .args = try self.gpa.alloc(MCValue, param_types.len),
        // These undefined values must be populated before returning from this function.
        .return_value = undefined,
        .stack_byte_count = 0,
        .stack_align = undefined,
        .gp_count = 0,
        .fp_count = 0,
    };
    errdefer self.gpa.free(result.args);

    const ret_ty = Type.fromInterned(fn_info.return_type);

    const resolved_cc = abi.resolveCallingConvention(cc, self.target.*);
    switch (cc) {
        .Naked => {
            assert(result.args.len == 0);
            result.return_value = InstTracking.init(.unreach);
            result.stack_align = .@"8";
        },
        .C, .SysV, .Win64 => {
            var ret_int_reg_i: u32 = 0;
            var ret_sse_reg_i: u32 = 0;
            var param_int_reg_i: u32 = 0;
            var param_sse_reg_i: u32 = 0;
            result.stack_align = .@"16";

            switch (resolved_cc) {
                .SysV => {},
                .Win64 => {
                    // Align the stack to 16bytes before allocating shadow stack space (if any).
                    result.stack_byte_count += @intCast(4 * Type.usize.abiSize(zcu));
                },
                else => unreachable,
            }

            // Return values
            if (ret_ty.zigTypeTag(zcu) == .noreturn) {
                result.return_value = InstTracking.init(.unreach);
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                // TODO: is this even possible for C calling convention?
                result.return_value = InstTracking.init(.none);
            } else {
                var ret_tracking: [2]InstTracking = undefined;
                var ret_tracking_i: usize = 0;

                const classes = switch (resolved_cc) {
                    .SysV => mem.sliceTo(&abi.classifySystemV(ret_ty, zcu, self.target.*, .ret), .none),
                    .Win64 => &.{abi.classifyWindows(ret_ty, zcu)},
                    else => unreachable,
                };
                for (classes) |class| switch (class) {
                    .integer => {
                        const ret_int_reg = registerAlias(
                            abi.getCAbiIntReturnRegs(resolved_cc)[ret_int_reg_i],
                            @intCast(@min(ret_ty.abiSize(zcu), 8)),
                        );
                        ret_int_reg_i += 1;

                        ret_tracking[ret_tracking_i] = InstTracking.init(.{ .register = ret_int_reg });
                        ret_tracking_i += 1;
                    },
                    .sse, .float, .float_combine, .win_i128 => {
                        const ret_sse_reg = registerAlias(
                            abi.getCAbiSseReturnRegs(resolved_cc)[ret_sse_reg_i],
                            @intCast(ret_ty.abiSize(zcu)),
                        );
                        ret_sse_reg_i += 1;

                        ret_tracking[ret_tracking_i] = InstTracking.init(.{ .register = ret_sse_reg });
                        ret_tracking_i += 1;
                    },
                    .sseup => assert(ret_tracking[ret_tracking_i - 1].short.register.class() == .sse),
                    .x87 => {
                        ret_tracking[ret_tracking_i] = InstTracking.init(.{ .register = .st0 });
                        ret_tracking_i += 1;
                    },
                    .x87up => assert(ret_tracking[ret_tracking_i - 1].short.register.class() == .x87),
                    .complex_x87 => {
                        ret_tracking[ret_tracking_i] =
                            InstTracking.init(.{ .register_pair = .{ .st0, .st1 } });
                        ret_tracking_i += 1;
                    },
                    .memory => {
                        const ret_int_reg = abi.getCAbiIntReturnRegs(resolved_cc)[ret_int_reg_i].to64();
                        ret_int_reg_i += 1;
                        const ret_indirect_reg = abi.getCAbiIntParamRegs(resolved_cc)[param_int_reg_i];
                        param_int_reg_i += 1;

                        ret_tracking[ret_tracking_i] = .{
                            .short = .{ .indirect = .{ .reg = ret_int_reg } },
                            .long = .{ .indirect = .{ .reg = ret_indirect_reg } },
                        };
                        ret_tracking_i += 1;
                    },
                    .none, .integer_per_element => unreachable,
                };
                result.return_value = switch (ret_tracking_i) {
                    else => unreachable,
                    1 => ret_tracking[0],
                    2 => InstTracking.init(.{ .register_pair = .{
                        ret_tracking[0].short.register, ret_tracking[1].short.register,
                    } }),
                };
            }

            // Input params
            for (param_types, result.args) |ty, *arg| {
                assert(ty.hasRuntimeBitsIgnoreComptime(zcu));
                switch (resolved_cc) {
                    .SysV => {},
                    .Win64 => {
                        param_int_reg_i = @max(param_int_reg_i, param_sse_reg_i);
                        param_sse_reg_i = param_int_reg_i;
                    },
                    else => unreachable,
                }

                var arg_mcv: [2]MCValue = undefined;
                var arg_mcv_i: usize = 0;

                const classes = switch (resolved_cc) {
                    .SysV => mem.sliceTo(&abi.classifySystemV(ty, zcu, self.target.*, .arg), .none),
                    .Win64 => &.{abi.classifyWindows(ty, zcu)},
                    else => unreachable,
                };
                for (classes) |class| switch (class) {
                    .integer => {
                        const param_int_regs = abi.getCAbiIntParamRegs(resolved_cc);
                        if (param_int_reg_i >= param_int_regs.len) break;

                        const param_int_reg = registerAlias(
                            abi.getCAbiIntParamRegs(resolved_cc)[param_int_reg_i],
                            @intCast(@min(ty.abiSize(zcu), 8)),
                        );
                        param_int_reg_i += 1;

                        arg_mcv[arg_mcv_i] = .{ .register = param_int_reg };
                        arg_mcv_i += 1;
                    },
                    .sse, .float, .float_combine => {
                        const param_sse_regs = abi.getCAbiSseParamRegs(resolved_cc);
                        if (param_sse_reg_i >= param_sse_regs.len) break;

                        const param_sse_reg = registerAlias(
                            abi.getCAbiSseParamRegs(resolved_cc)[param_sse_reg_i],
                            @intCast(ty.abiSize(zcu)),
                        );
                        param_sse_reg_i += 1;

                        arg_mcv[arg_mcv_i] = .{ .register = param_sse_reg };
                        arg_mcv_i += 1;
                    },
                    .sseup => assert(arg_mcv[arg_mcv_i - 1].register.class() == .sse),
                    .x87, .x87up, .complex_x87, .memory, .win_i128 => switch (resolved_cc) {
                        .SysV => switch (class) {
                            .x87, .x87up, .complex_x87, .memory => break,
                            else => unreachable,
                        },
                        .Win64 => if (ty.abiSize(zcu) > 8) {
                            const param_int_reg =
                                abi.getCAbiIntParamRegs(resolved_cc)[param_int_reg_i].to64();
                            param_int_reg_i += 1;

                            arg_mcv[arg_mcv_i] = .{ .indirect = .{ .reg = param_int_reg } };
                            arg_mcv_i += 1;
                        } else break,
                        else => unreachable,
                    },
                    .none => unreachable,
                    .integer_per_element => {
                        const param_int_regs_len: u32 =
                            @intCast(abi.getCAbiIntParamRegs(resolved_cc).len);
                        const remaining_param_int_regs: u3 =
                            @intCast(param_int_regs_len - param_int_reg_i);
                        param_int_reg_i = param_int_regs_len;

                        const frame_elem_align = 8;
                        const frame_elems_len = ty.vectorLen(zcu) - remaining_param_int_regs;
                        const frame_elem_size = mem.alignForward(
                            u64,
                            ty.childType(zcu).abiSize(zcu),
                            frame_elem_align,
                        );
                        const frame_size: u31 = @intCast(frame_elems_len * frame_elem_size);

                        result.stack_byte_count =
                            mem.alignForward(u31, result.stack_byte_count, frame_elem_align);
                        arg_mcv[arg_mcv_i] = .{ .elementwise_regs_then_frame = .{
                            .regs = remaining_param_int_regs,
                            .frame_off = @intCast(result.stack_byte_count),
                            .frame_index = stack_frame_base,
                        } };
                        arg_mcv_i += 1;
                        result.stack_byte_count += frame_size;
                    },
                } else {
                    arg.* = switch (arg_mcv_i) {
                        else => unreachable,
                        1 => arg_mcv[0],
                        2 => .{ .register_pair = .{ arg_mcv[0].register, arg_mcv[1].register } },
                    };
                    continue;
                }

                const param_size: u31 = @intCast(ty.abiSize(zcu));
                const param_align: u31 =
                    @intCast(@max(ty.abiAlignment(zcu).toByteUnits().?, 8));
                result.stack_byte_count =
                    mem.alignForward(u31, result.stack_byte_count, param_align);
                arg.* = .{ .load_frame = .{
                    .index = stack_frame_base,
                    .off = result.stack_byte_count,
                } };
                result.stack_byte_count += param_size;
            }
            assert(param_int_reg_i <= 6);
            result.gp_count = param_int_reg_i;
            assert(param_sse_reg_i <= 16);
            result.fp_count = param_sse_reg_i;
        },
        .Unspecified => {
            result.stack_align = .@"16";

            // Return values
            if (ret_ty.zigTypeTag(zcu) == .noreturn) {
                result.return_value = InstTracking.init(.unreach);
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                result.return_value = InstTracking.init(.none);
            } else {
                const ret_reg = abi.getCAbiIntReturnRegs(resolved_cc)[0];
                const ret_ty_size: u31 = @intCast(ret_ty.abiSize(zcu));
                if (ret_ty_size <= 8 and !ret_ty.isRuntimeFloat()) {
                    const aliased_reg = registerAlias(ret_reg, ret_ty_size);
                    result.return_value = .{ .short = .{ .register = aliased_reg }, .long = .none };
                } else {
                    const ret_indirect_reg = abi.getCAbiIntParamRegs(resolved_cc)[0];
                    result.return_value = .{
                        .short = .{ .indirect = .{ .reg = ret_reg } },
                        .long = .{ .indirect = .{ .reg = ret_indirect_reg } },
                    };
                }
            }

            // Input params
            for (param_types, result.args) |ty, *arg| {
                if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    arg.* = .none;
                    continue;
                }
                const param_size: u31 = @intCast(ty.abiSize(zcu));
                const param_align: u31 = @intCast(ty.abiAlignment(zcu).toByteUnits().?);
                result.stack_byte_count =
                    mem.alignForward(u31, result.stack_byte_count, param_align);
                arg.* = .{ .load_frame = .{
                    .index = stack_frame_base,
                    .off = result.stack_byte_count,
                } };
                result.stack_byte_count += param_size;
            }
        },
        else => return self.fail("TODO implement function parameters and return values for {} on x86_64", .{cc}),
    }

    result.stack_byte_count = @intCast(result.stack_align.forward(result.stack_byte_count));
    return result;
}

fn fail(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @branchHint(.cold);
    assert(self.err_msg == null);
    const gpa = self.gpa;
    self.err_msg = try ErrorMsg.create(gpa, self.src_loc, format, args);
    return error.CodegenFail;
}

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}

/// Returns register wide enough to hold at least `size_bytes`.
fn registerAlias(reg: Register, size_bytes: u32) Register {
    return switch (reg.class()) {
        .general_purpose => if (size_bytes == 0)
            unreachable // should be comptime-known
        else if (size_bytes <= 1)
            reg.to8()
        else if (size_bytes <= 2)
            reg.to16()
        else if (size_bytes <= 4)
            reg.to32()
        else if (size_bytes <= 8)
            reg.to64()
        else
            unreachable,
        .segment => if (size_bytes <= 2)
            reg
        else
            unreachable,
        .x87 => if (size_bytes == 16)
            reg
        else
            unreachable,
        .mmx => if (size_bytes <= 8)
            reg
        else
            unreachable,
        .sse => if (size_bytes <= 16)
            reg.to128()
        else if (size_bytes <= 32)
            reg.to256()
        else
            unreachable,
        .ip => if (size_bytes <= 2)
            .ip
        else if (size_bytes <= 4)
            .eip
        else if (size_bytes <= 8)
            .rip
        else
            unreachable,
    };
}

fn memSize(self: *Self, ty: Type) Memory.Size {
    const pt = self.pt;
    const zcu = pt.zcu;
    return switch (ty.zigTypeTag(zcu)) {
        .float => Memory.Size.fromBitSize(ty.floatBits(self.target.*)),
        else => Memory.Size.fromSize(@intCast(ty.abiSize(zcu))),
    };
}

fn splitType(self: *Self, ty: Type) ![2]Type {
    const pt = self.pt;
    const zcu = pt.zcu;
    const classes = mem.sliceTo(&abi.classifySystemV(ty, zcu, self.target.*, .other), .none);
    var parts: [2]Type = undefined;
    if (classes.len == 2) for (&parts, classes, 0..) |*part, class, part_i| {
        part.* = switch (class) {
            .integer => switch (part_i) {
                0 => Type.u64,
                1 => part: {
                    const elem_size = ty.abiAlignment(zcu).minStrict(.@"8").toByteUnits().?;
                    const elem_ty = try pt.intType(.unsigned, @intCast(elem_size * 8));
                    break :part switch (@divExact(ty.abiSize(zcu) - 8, elem_size)) {
                        1 => elem_ty,
                        else => |len| try pt.arrayType(.{ .len = len, .child = elem_ty.toIntern() }),
                    };
                },
                else => unreachable,
            },
            .float => Type.f32,
            .float_combine => try pt.arrayType(.{ .len = 2, .child = .f32_type }),
            .sse => Type.f64,
            else => break,
        };
    } else if (parts[0].abiSize(zcu) + parts[1].abiSize(zcu) == ty.abiSize(zcu)) return parts;
    return self.fail("TODO implement splitType for {}", .{ty.fmt(pt)});
}

/// Truncates the value in the register in place.
/// Clobbers any remaining bits.
fn truncateRegister(self: *Self, ty: Type, reg: Register) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const int_info = if (ty.isAbiInt(zcu)) ty.intInfo(zcu) else std.builtin.Type.Int{
        .signedness = .unsigned,
        .bits = @intCast(ty.bitSize(zcu)),
    };
    const shift = math.cast(u6, 64 - int_info.bits % 64) orelse return;
    try self.spillEflagsIfOccupied();
    switch (int_info.signedness) {
        .signed => {
            try self.genShiftBinOpMir(
                .{ ._l, .sa },
                Type.isize,
                .{ .register = reg },
                Type.u8,
                .{ .immediate = shift },
            );
            try self.genShiftBinOpMir(
                .{ ._r, .sa },
                Type.isize,
                .{ .register = reg },
                Type.u8,
                .{ .immediate = shift },
            );
        },
        .unsigned => {
            const mask = ~@as(u64, 0) >> shift;
            if (int_info.bits <= 32) {
                try self.genBinOpMir(
                    .{ ._, .@"and" },
                    Type.u32,
                    .{ .register = reg },
                    .{ .immediate = mask },
                );
            } else {
                const tmp_reg = try self.copyToTmpRegister(Type.usize, .{ .immediate = mask });
                try self.genBinOpMir(
                    .{ ._, .@"and" },
                    Type.usize,
                    .{ .register = reg },
                    .{ .register = tmp_reg },
                );
            }
        },
    }
}

fn regBitSize(self: *Self, ty: Type) u64 {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size = ty.abiSize(zcu);
    return switch (ty.zigTypeTag(zcu)) {
        else => switch (abi_size) {
            1 => 8,
            2 => 16,
            3...4 => 32,
            5...8 => 64,
            else => unreachable,
        },
        .float => switch (abi_size) {
            1...16 => 128,
            17...32 => 256,
            else => unreachable,
        },
    };
}

fn regExtraBits(self: *Self, ty: Type) u64 {
    return self.regBitSize(ty) - ty.bitSize(self.pt.zcu);
}

fn hasFeature(self: *Self, feature: Target.x86.Feature) bool {
    return Target.x86.featureSetHas(self.target.cpu.features, feature);
}
fn hasAnyFeatures(self: *Self, features: anytype) bool {
    return Target.x86.featureSetHasAny(self.target.cpu.features, features);
}
fn hasAllFeatures(self: *Self, features: anytype) bool {
    return Target.x86.featureSetHasAll(self.target.cpu.features, features);
}

fn typeOf(self: *Self, inst: Air.Inst.Ref) Type {
    const pt = self.pt;
    const zcu = pt.zcu;
    return self.air.typeOf(inst, &zcu.intern_pool);
}

fn typeOfIndex(self: *Self, inst: Air.Inst.Index) Type {
    const pt = self.pt;
    const zcu = pt.zcu;
    return switch (self.air.instructions.items(.tag)[@intFromEnum(inst)]) {
        .loop_switch_br => self.typeOf(self.air.unwrapSwitch(inst).operand),
        else => self.air.typeOfIndex(inst, &zcu.intern_pool),
    };
}

fn intCompilerRtAbiName(int_bits: u32) u8 {
    return switch (int_bits) {
        1...32 => 's',
        33...64 => 'd',
        65...128 => 't',
        else => unreachable,
    };
}

fn floatCompilerRtAbiName(float_bits: u32) u8 {
    return switch (float_bits) {
        16 => 'h',
        32 => 's',
        64 => 'd',
        80 => 'x',
        128 => 't',
        else => unreachable,
    };
}

fn floatCompilerRtAbiType(self: *Self, ty: Type, other_ty: Type) Type {
    if (ty.toIntern() == .f16_type and
        (other_ty.toIntern() == .f32_type or other_ty.toIntern() == .f64_type) and
        self.target.isDarwin()) return Type.u16;
    return ty;
}

fn floatLibcAbiPrefix(ty: Type) []const u8 {
    return switch (ty.toIntern()) {
        .f16_type, .f80_type => "__",
        .f32_type, .f64_type, .f128_type, .c_longdouble_type => "",
        else => unreachable,
    };
}

fn floatLibcAbiSuffix(ty: Type) []const u8 {
    return switch (ty.toIntern()) {
        .f16_type => "h",
        .f32_type => "f",
        .f64_type => "",
        .f80_type => "x",
        .f128_type => "q",
        .c_longdouble_type => "l",
        else => unreachable,
    };
}

fn promoteInt(self: *Self, ty: Type) Type {
    const pt = self.pt;
    const zcu = pt.zcu;
    const int_info: InternPool.Key.IntType = switch (ty.toIntern()) {
        .bool_type => .{ .signedness = .unsigned, .bits = 1 },
        else => if (ty.isAbiInt(zcu)) ty.intInfo(zcu) else return ty,
    };
    for ([_]Type{
        Type.c_int,      Type.c_uint,
        Type.c_long,     Type.c_ulong,
        Type.c_longlong, Type.c_ulonglong,
    }) |promote_ty| {
        const promote_info = promote_ty.intInfo(zcu);
        if (int_info.signedness == .signed and promote_info.signedness == .unsigned) continue;
        if (int_info.bits + @intFromBool(int_info.signedness == .unsigned and
            promote_info.signedness == .signed) <= promote_info.bits) return promote_ty;
    }
    return ty;
}

fn promoteVarArg(self: *Self, ty: Type) Type {
    if (!ty.isRuntimeFloat()) return self.promoteInt(ty);
    switch (ty.floatBits(self.target.*)) {
        32, 64 => return Type.f64,
        else => |float_bits| {
            assert(float_bits == self.target.cTypeBitSize(.longdouble));
            return Type.c_longdouble;
        },
    }
}
