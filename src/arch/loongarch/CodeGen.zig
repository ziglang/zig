const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const cast = std.math.cast;
const Writer = std.Io.Writer;

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
    /// The value is stored as a NAV.
    load_nav: bits.NavOffset,
    /// The value is the address of a NAV.
    lea_nav: bits.NavOffset,
    /// The value is stored as a UAV.
    load_uav: bits.UavOffset,
    /// The value is the address of a UAV.
    lea_uav: bits.UavOffset,
    /// The value is a lazy symbol.
    load_lazy_sym: link.File.LazySymbol,
    /// The value is the address of a lazy symbol.
    lea_lazy_sym: link.File.LazySymbol,
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
            .lea_frame,
            .load_nav,
            .lea_nav,
            .load_uav,
            .lea_uav,
            .load_lazy_sym,
            .lea_lazy_sym,
            .reserved_frame,
            .air_ref,
            => false,
            .register,
            .register_pair,
            .register_triple,
            .register_quadruple,
            .memory,
            .register_frame,
            .register_offset,
            => true,
            .load_frame => |frame_addr| !frame_addr.index.isNamed(),
        };
    }

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory, .register_offset, .load_frame, .load_nav, .load_uav, .load_lazy_sym => true,
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
            .immediate, .register, .register_bias, .lea_frame, .lea_nav, .lea_uav, .lea_lazy_sym => true,
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
            .lea_nav,
            .lea_uav,
            .lea_lazy_sym,
            .lea_frame,
            .reserved_frame,
            .air_ref,
            => unreachable, // not in memory
            .memory => |addr| .{ .immediate = addr },
            .register_offset => |reg_off| switch (reg_off.off) {
                0 => .{ .register = reg_off.reg },
                else => .{ .register_bias = reg_off },
            },
            .load_frame => |frame_addr| .{ .lea_frame = frame_addr },
            .register_frame => |reg_frame| .{ .lea_frame = reg_frame.frame },
            .load_nav => |nav_off| .{ .lea_nav = nav_off },
            .load_uav => |uav_off| .{ .lea_uav = uav_off },
            .load_lazy_sym => |sym| .{ .lea_lazy_sym = sym },
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
            .load_frame,
            .register_frame,
            .load_nav,
            .load_uav,
            .load_lazy_sym,
            .reserved_frame,
            .air_ref,
            => unreachable, // not dereferenceable
            .immediate => |addr| .{ .memory = addr },
            .register => |reg| .{ .register_offset = .{ .reg = reg } },
            .register_bias => |reg_off| .{ .register_offset = reg_off },
            .lea_frame => |frame_addr| .{ .load_frame = frame_addr },
            .lea_nav => |nav_off| .{ .load_nav = nav_off },
            .lea_uav => |uav_off| .{ .load_uav = uav_off },
            .lea_lazy_sym => |sym| .{ .load_lazy_sym = sym },
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
            .load_frame,
            .register_frame,
            .load_nav,
            .load_uav,
            .load_lazy_sym,
            .lea_lazy_sym,
            => switch (off) {
                0 => mcv,
                else => unreachable, // not offsettable
            },
            .immediate => |imm| .{ .immediate = @bitCast(@as(i64, @bitCast(imm)) +% off) },
            .register => |reg| .{ .register_bias = .{ .reg = reg, .off = off } },
            .register_bias => |reg_off| .{
                .register_bias = .{ .reg = reg_off.reg, .off = reg_off.off + off },
            },
            .lea_frame => |frame_addr| .{
                .lea_frame = .{ .index = frame_addr.index, .off = frame_addr.off + off },
            },
            .lea_nav => |nav_off| .{
                .lea_nav = .{ .index = nav_off.index, .off = nav_off.off + off },
            },
            .lea_uav => |uav_off| .{
                .lea_uav = .{ .index = uav_off.index, .off = uav_off.off + off },
            },
        };
    }

    /// Returns MCV of a limb.
    /// Caller does not own returned values.
    fn toLimbValue(mcv: MCValue, limb_index: u64) MCValue {
        switch (mcv) {
            else => std.debug.panic("{s}: {f}\n", .{ @src().fn_name, mcv }),
            .register, .immediate, .register_bias, .lea_frame, .lea_nav, .lea_uav, .lea_lazy_sym => {
                assert(limb_index == 0);
                return mcv;
            },
            inline .register_pair, .register_triple, .register_quadruple => |regs| {
                return .{ .register = regs[@intCast(limb_index)] };
            },
            .load_frame => |frame_addr| {
                return .{ .load_frame = .{
                    .index = frame_addr.index,
                    .off = frame_addr.off + @as(u31, @intCast(limb_index)) * 8,
                } };
            },
            .register_offset => |reg_off| {
                return .{ .register_offset = .{
                    .reg = reg_off.reg,
                    .off = reg_off.off + @as(u31, @intCast(limb_index)) * 8,
                } };
            },
            .load_nav => |nav_off| {
                return .{ .load_nav = .{
                    .index = nav_off.index,
                    .off = nav_off.off + @as(u31, @intCast(limb_index)) * 8,
                } };
            },
            .load_uav => |uav_off| {
                return .{ .load_uav = .{
                    .index = uav_off.index,
                    .off = uav_off.off + @as(u31, @intCast(limb_index)) * 8,
                } };
            },
        }
    }

    pub fn format(mcv: MCValue, writer: *Writer) Writer.Error!void {
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
            .load_frame => |pl| try writer.print("[frame:{f} + 0x{x}]", .{ pl.index, pl.off }),
            .lea_frame => |pl| try writer.print("frame:{f} + 0x{x}", .{ pl.index, pl.off }),
            .register_frame => |pl| try writer.print("{{{s}, (frame:{f} + 0x{x})}}", .{ @tagName(pl.reg), pl.frame.index, pl.frame.off }),
            .register_offset => |pl| try writer.print("[{s} + 0x{x}]", .{ @tagName(pl.reg), pl.off }),
            .load_nav => |pl| try writer.print("[nav:{} + 0x{x}]", .{ pl.index, pl.off }),
            .lea_nav => |pl| try writer.print("nav:{} + 0x{x}", .{ pl.index, pl.off }),
            .load_uav => |pl| try writer.print("[uav:{} + 0x{x}]", .{ pl.index, pl.off }),
            .lea_uav => |pl| try writer.print("uav:{} + 0x{x}", .{ pl.index, pl.off }),
            .load_lazy_sym => |pl| try writer.print("[lazy sym:{s}:{}]", .{ @tagName(pl.kind), pl.ty }),
            .lea_lazy_sym => |pl| try writer.print("lazy sym:{s}:{}", .{ @tagName(pl.kind), pl.ty }),
            .reserved_frame => |pl| try writer.print("(dead:{f})", .{pl}),
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
            .register_triple => |regs| .{ .register_triple = regs },
            .register_quadruple => |regs| .{ .register_quadruple = regs },
            .frame => |off| .{ .load_frame = .{ .index = frame, .off = off } },
            .split => |pl| .{ .register_frame = .{
                .reg = pl.reg,
                .frame = .{ .index = frame, .off = pl.frame_off },
            } },
            .ref_register => |reg| .{ .register_offset = .{ .reg = reg, .off = 0 } },
            .ref_frame => |off| .{ .load_frame = .{ .index = frame, .off = off } },
        };
    }

    /// Allocates and loads `val` to registers if `val` is not in regs yet.
    /// Returns either self or the allocated reg and a flag indicating whether allocation happened.
    fn ensureReg(val: MCValue, cg: *CodeGen, inst: Air.Inst.Index, ty: Type) InnerError!struct { Register, bool } {
        if (val.isInRegister()) {
            return .{ val.register, false };
        } else {
            const temp_reg = try cg.allocReg(ty, inst);
            try cg.genCopyToReg(.fromByteSize(ty.abiSize(cg.pt.zcu)), temp_reg, val, .{});
            return .{ temp_reg, true };
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
            .load_frame,
            .lea_frame,
            .load_nav,
            .lea_nav,
            .load_uav,
            .lea_uav,
            .load_lazy_sym,
            .lea_lazy_sym,
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

    pub fn format(inst_tracking: InstTracking, writer: *Writer) Writer.Error!void {
        if (!std.meta.eql(inst_tracking.long, inst_tracking.short))
            try writer.print("|{f}| ", .{inst_tracking.long});
        try writer.print("{f}", .{inst_tracking.short});
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
        tracking_log.debug("{f} => {f} (death)", .{ inst, self.* });
    }

    fn reuse(
        self: *InstTracking,
        cg: *CodeGen,
        new_inst: Air.Inst.Index,
        old_inst: Air.Inst.Index,
    ) void {
        tracking_log.debug("{f} => {f} (reuse {f})", .{ new_inst, self.*, old_inst });
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
        tracking_log.debug("spill {f} from {f} to {f}", .{ inst, self.short, self.long });
        try cg.genCopy(cg.typeOfIndex(inst), self.long, self.short, .{});
    }

    fn trackSpill(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) !void {
        try cg.freeValue(inst_tracking.short);
        inst_tracking.reuseFrame();
        tracking_log.debug("{f} => {f} (spilled)", .{ inst, inst_tracking.* });
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
                tracking_log.debug("{f} => {f} (resurrect)", .{ inst, inst_tracking.* });
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
            .load_nav,
            .lea_nav,
            .load_uav,
            .lea_uav,
            .load_lazy_sym,
            .lea_lazy_sym,
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
        tracking_log.debug("{f} => {f} (materialize)", .{ inst, inst_tracking.* });
    }

    fn liveOut(inst_tracking: *InstTracking, cg: *CodeGen, inst: Air.Inst.Index) void {
        for (inst_tracking.getRegs()) |reg| {
            if (cg.register_manager.isRegFree(reg)) {
                tracking_log.debug("{f} => {f} (live-out)", .{ inst, inst_tracking.* });
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

            tracking_log.debug("{f} => {f} (live-out {f})", .{ inst, inst_tracking.*, tracked_inst });
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
    air: *const Air,
    liveness: *const Air.Liveness,
) codegen.CodeGenError!Mir {
    _ = bin_file;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);
    const fn_type: Type = .fromInterned(func.ty);
    const mod = zcu.navFileScope(func.owner_nav).mod.?;

    // initialize CG
    var cg: CodeGen = .{
        .gpa = gpa,
        .pt = pt,
        .air = air.*,
        .liveness = liveness.*,
        .target = &mod.resolved_target.result,
        .mod = mod,
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

    cg_mir_log.debug("{f}:", .{ip.getNav(func.owner_nav).fqn.fmt(ip)});

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
    if (!cg.mod.strip) _ = try cg.addInst(.{
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
    log.debug("Frame layout: {} bytes{f}", .{ frame_size, cg.fmtFrameLocs() });

    // construct MIR
    const mir: Mir = .{
        .instructions = cg.mir_instructions.toOwnedSlice(),
        .frame_locs = cg.frame_locs.toOwnedSlice(),
        .frame_size = frame_size,
        .epilogue_begin = cg.epilogue_label,
        .spill_ra = ra_allocated,
    };

    return mir;
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
    if (!cg.mod.strip) try cg.asmPseudo(.dbg_enter_block, .none);
    try cg.genBody(body);
    if (!cg.mod.strip) try cg.asmPseudo(.dbg_exit_block, .none);
}

fn hasFeature(cg: *CodeGen, feature: std.Target.loongarch.Feature) bool {
    return cg.target.cpu.has(.loongarch, feature);
}

fn intRegisterSize(cg: *CodeGen) u16 {
    return switch (cg.target.cpu.arch) {
        .loongarch32 => 32,
        .loongarch64 => 64,
        else => unreachable,
    };
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

    cg_mir_log.debug("  | {}: {f}", .{ result_index, inst });

    cg.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
}

fn backpatchInst(cg: *CodeGen, index: Mir.Inst.Index, inst: Mir.Inst) void {
    cg_mir_log.debug("  | backpatch: {}: {f}", .{ index, inst });
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

        fn toType(index: Index, cg: *CodeGen, ty: Type) void {
            assert(index.isValid(cg));
            cg.temp_type[@intFromEnum(index)] = ty;
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

    fn maybeTracking(temp: Temp, cg: *CodeGen) ?InstTracking {
        switch (temp.index.unwrap()) {
            .ref => |temp_ref| if (temp_ref.toInternedAllowNone() != null) return null,
            else => {},
        }
        return cg.inst_tracking.get(temp.index).?;
    }

    fn isMut(temp: Temp, cg: *CodeGen) bool {
        return switch (temp.unwrap(cg)) {
            .ref, .err_ret_trace => false,
            .temp => |_| temp.tracking(cg).short.isModifiable(),
        };
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
            .lea_nav,
            .lea_uav,
            .lea_lazy_sym,
            => {
                const ty = temp.typeOf(cg);
                const new_temp = try cg.tempAllocMem(ty);
                temp.copy(new_temp, cg, ty);
                try temp.die(cg);
                temp.* = new_temp;
                return true;
            },
            .memory,
            .register_offset,
            .load_frame,
            .register_frame,
            .load_nav,
            .load_uav,
            .load_lazy_sym,
            => return false,
        }
    }

    fn getReg(temp: Temp, cg: *CodeGen) Register {
        return temp.tracking(cg).getReg().?;
    }

    fn getUnsignedImm(temp: Temp, cg: *CodeGen) u64 {
        return temp.tracking(cg).short.immediate;
    }

    fn getSignedImm(temp: Temp, cg: *CodeGen) i64 {
        return @bitCast(temp.tracking(cg).short.immediate);
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

                tracking_log.debug("{f} => {f} (birth copied from {f})", .{ inst, result_mcv, temp.index });
                cg.inst_tracking.putAssumeCapacityNoClobber(inst, .init(result_mcv));
            },
            .temp => |temp_index| {
                const temp_tracking = temp_index.tracking(cg);
                tracking_log.debug("{f} => {f} (birth from {f})", .{ inst, temp_tracking.short, temp.index });
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
        off: i32 = 0,
    };

    fn load(ptr: Temp, cg: *CodeGen, ty: Type, opts: AccessOptions) InnerError!Temp {
        const val = try cg.tempAlloc(ty, .{});
        try ptr.loadTo(val, cg, ty, opts);
        return val;
    }

    fn loadTo(ptr: Temp, dst: Temp, cg: *CodeGen, ty: Type, opts: AccessOptions) InnerError!void {
        const addr, _ = try ptr.ensureOffsetable(cg);
        addr.toOffset(cg, opts.off);
        try cg.genCopy(ty, dst.tracking(cg).short, addr.tracking(cg).short.deref(), .{ .safety = opts.safety });
    }

    fn storeTo(val: Temp, ptr: Temp, cg: *CodeGen, ty: Type, opts: AccessOptions) InnerError!void {
        const addr, _ = try ptr.ensureOffsetable(cg);
        addr.toOffset(cg, opts.off);
        try cg.genCopy(ty, addr.tracking(cg).short.deref(), val.tracking(cg).short, .{ .safety = opts.safety });
    }

    fn read(val: Temp, cg: *CodeGen, ty: Type, opts: AccessOptions) InnerError!Temp {
        const dst = try cg.tempAlloc(ty, .{});
        try val.readTo(dst, cg, ty, opts);
        return dst;
    }

    fn readTo(val: Temp, dst: Temp, cg: *CodeGen, ty: Type, opts: AccessOptions) InnerError!void {
        const val_mcv = val.tracking(cg).short;
        switch (val_mcv) {
            else => |mcv| std.debug.panic("{s}: {f}\n", .{ @src().fn_name, mcv }),
            .register, .register_bias => {
                assert(opts.off == 0);
                try val.copy(dst, cg, ty);
            },
            inline .register_pair, .register_triple, .register_quadruple => |regs| {
                assert(@rem(opts.off, 8) == 0);
                assert(opts.off >= 0);
                assert(ty.abiSize(cg.pt.zcu) <= 8); // TODO not implemented yet
                try cg.genCopy(ty, dst.tracking(cg).short, .{ .register = regs[@as(u32, @intCast(opts.off)) / 8] }, .{ .safety = opts.safety });
            },
            .memory, .register_offset, .load_frame, .load_nav, .load_uav, .load_lazy_sym => {
                var addr_ptr = try cg.tempInit(.usize, val_mcv.address());
                try addr_ptr.loadTo(dst, cg, ty, opts);
                try addr_ptr.die(cg);
            },
        }
    }

    fn write(dst: Temp, val: Temp, cg: *CodeGen, opts: AccessOptions) InnerError!void {
        const ty = val.typeOf(cg);
        const dst_mcv = dst.tracking(cg).short;
        switch (dst_mcv) {
            else => |mcv| std.debug.panic("{s}: {f}\n", .{ @src().fn_name, mcv }),
            .register, .register_bias => {
                assert(opts.off == 0);
                try val.copy(dst, cg, ty);
            },
            inline .register_pair, .register_triple, .register_quadruple => |regs| {
                assert(@rem(opts.off, 8) == 0);
                assert(opts.off >= 0);
                assert(ty.abiSize(cg.pt.zcu) <= 8); // TODO not implemented yet
                try cg.genCopy(ty, dst.tracking(cg).short, .{ .register = regs[@as(u32, @intCast(opts.off)) / 8] }, .{ .safety = opts.safety });
            },
            .memory, .register_offset, .load_frame, .load_nav, .load_uav, .load_lazy_sym => {
                var addr_ptr = try cg.tempInit(.usize, dst_mcv.address());
                try val.storeTo(addr_ptr, cg, ty, opts);
                try addr_ptr.die(cg);
            },
        }
    }

    fn getLimbCount(temp: Temp, cg: *CodeGen) u64 {
        return cg.getLimbCount(temp.typeOf(cg));
    }

    fn getLimb(temp: Temp, limb_ty: Type, limb_index: u28, cg: *CodeGen, reuse: bool) InnerError!Temp {
        if (reuse) try temp.die(cg);
        const new_temp_index = cg.next_temp_index;
        cg.next_temp_index = @enumFromInt(@intFromEnum(new_temp_index) + 1);
        cg.temp_type[@intFromEnum(new_temp_index)] = limb_ty;
        const temp_mcv = temp.tracking(cg).short;
        switch (temp_mcv) {
            else => |mcv| std.debug.panic("{s}: {f}\n", .{ @src().fn_name, mcv }),
            .immediate => |imm| {
                assert(limb_index == 0);
                new_temp_index.tracking(cg).* = .init(.{ .immediate = imm });
            },
            .register => |reg| {
                assert(limb_index == 0);
                if (reuse)
                    new_temp_index.tracking(cg).* = .init(.{ .register = reg })
                else {
                    const new_reg =
                        try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterSets.gp);
                    new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                    try cg.asmInst(.@"or"(new_reg, reg, .zero));
                }
            },
            inline .register_pair, .register_triple, .register_quadruple => |regs| {
                if (reuse)
                    new_temp_index.tracking(cg).* = .init(.{ .register = regs[@intCast(limb_index)] })
                else {
                    const new_reg =
                        try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterSets.gp);
                    new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                    try cg.asmInst(.@"or"(new_reg, regs[@intCast(limb_index)], .zero));
                }
            },
            .register_bias, .register_offset => |_| {
                assert(limb_index == 0);
                if (reuse)
                    new_temp_index.tracking(cg).* = .init(temp_mcv)
                else {
                    const new_reg =
                        try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterSets.gp);
                    new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                    try cg.genCopyToReg(.dword, new_reg, temp.tracking(cg).short, .{});
                }
            },
            .load_frame => |frame_addr| {
                const new_mcv: MCValue = .{ .load_frame = .{
                    .index = frame_addr.index,
                    .off = frame_addr.off + @as(u31, limb_index) * 8,
                } };
                if (reuse)
                    new_temp_index.tracking(cg).* = .init(new_mcv)
                else {
                    const new_reg =
                        try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterSets.gp);
                    new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                    try cg.genCopyToReg(.dword, new_reg, new_mcv, .{});
                }
            },
            .lea_frame => |frame_addr| {
                assert(limb_index == 0);
                new_temp_index.tracking(cg).* = .init(.{ .lea_frame = frame_addr });
            },
            .load_nav => |nav_off| {
                const new_mcv: MCValue = .{ .load_nav = .{
                    .index = nav_off.index,
                    .off = nav_off.off + @as(u31, limb_index) * 8,
                } };
                if (reuse)
                    new_temp_index.tracking(cg).* = .init(new_mcv)
                else {
                    const new_reg =
                        try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterSets.gp);
                    new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                    try cg.genCopyToReg(.dword, new_reg, new_mcv, .{});
                }
            },
            .lea_nav => |nav_off| {
                assert(limb_index == 0);
                new_temp_index.tracking(cg).* = .init(.{ .lea_nav = nav_off });
            },
            .load_uav => |uav_off| {
                const new_mcv: MCValue = .{ .load_uav = .{
                    .index = uav_off.index,
                    .off = uav_off.off + @as(u31, limb_index) * 8,
                } };
                if (reuse)
                    new_temp_index.tracking(cg).* = .init(new_mcv)
                else {
                    const new_reg =
                        try cg.register_manager.allocReg(new_temp_index.toIndex(), abi.RegisterSets.gp);
                    new_temp_index.tracking(cg).* = .init(.{ .register = new_reg });
                    try cg.genCopyToReg(.dword, new_reg, new_mcv, .{});
                }
            },
            .lea_uav => |nav_off| {
                assert(limb_index == 0);
                new_temp_index.tracking(cg).* = .init(.{ .lea_uav = nav_off });
            },
        }
        try cg.getValueIfFree(new_temp_index.tracking(cg).short, new_temp_index.toIndex());
        return .{ .index = new_temp_index.toIndex() };
    }

    /// Returns MCV of a limb.
    /// Caller does not own return values.
    fn toLimbValue(temp: Temp, limb_index: u64, cg: *CodeGen) MCValue {
        return temp.tracking(cg).short.toLimbValue(limb_index);
    }

    /// Loads `val` to `temp` if `val` is not in regs yet.
    /// Returns either MCV of self if copy occurred or `val` if `val` is already in regs.
    fn ensureReg(temp: Temp, cg: *CodeGen, val: MCValue) InnerError!MCValue {
        if (val.isInRegister()) {
            return val;
        } else {
            const temp_mcv = temp.tracking(cg).short;
            try cg.genCopyToReg(.fromByteSize(temp.typeOf(cg).abiSize(cg.pt.zcu)), temp.getReg(cg), val, .{});
            return temp_mcv;
        }
    }

    /// Loads `temp` to a newly allocated register if it is not in register yet.
    fn ensureOffsetable(temp: Temp, cg: *CodeGen) InnerError!struct { Temp, bool } {
        const mcv = temp.tracking(cg).short;
        if (!mcv.isMemory()) {
            return .{ temp, false };
        } else {
            const ty = temp.typeOf(cg);
            const new_temp = try cg.tempAlloc(ty, .{ .use_frame = false });
            try temp.copy(new_temp, cg, ty);
            return .{ new_temp, true };
        }
    }

    fn truncateRegister(temp: Temp, cg: *CodeGen) !void {
        const temp_tracking = temp.tracking(cg);
        const regs = temp_tracking.getRegs();
        assert(regs.len > 0);
        return cg.truncateRegister(temp.typeOf(cg), regs[regs.len - 1]);
    }

    fn toType(temp: Temp, cg: *CodeGen, ty: Type) void {
        return switch (temp.unwrap(cg)) {
            .ref, .err_ret_trace => unreachable,
            .temp => |temp_index| temp_index.toType(cg, ty),
        };
    }

    fn toOffset(temp: Temp, cg: *CodeGen, off: i32) void {
        const temp_tracking = cg.inst_tracking.getPtr(temp.index).?;
        temp_tracking.short = temp_tracking.short.offset(off);
    }
};

fn getValue(cg: *CodeGen, value: MCValue, inst: ?Air.Inst.Index) !void {
    for (value.getRegs()) |reg| try cg.register_manager.getReg(reg, inst);
}

fn getValueIfFree(cg: *CodeGen, value: MCValue, inst: ?Air.Inst.Index) !void {
    for (value.getRegs()) |reg| if (cg.register_manager.isRegFree(reg))
        try cg.register_manager.getReg(reg, inst);
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
    tracking_log.debug("free frame {f}", .{frame});
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
        return cg.fail("Cannot allocate register for {f} (Zig compiler bug)", .{ty.fmt(cg.pt)});
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

    return cg.fail("Cannot allocate {f} with options {} (Zig compiler bug)", .{ ty.fmt(cg.pt), opts });
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
        tracking_log.debug("reuse frame {f}", .{frame_index});
        return frame_index;
    }

    const frame_index: FrameIndex = @enumFromInt(cg.frame_allocs.len);
    try cg.frame_allocs.append(cg.gpa, alloc);
    tracking_log.debug("new frame {f}", .{frame_index});
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

fn getLimbCount(cg: *CodeGen, ty: Type) u64 {
    return std.math.divCeil(u64, ty.abiSize(cg.pt.zcu), 8) catch unreachable;
}

fn getLimbSize(cg: *CodeGen, ty: Type, limb: u64) bits.Memory.Size {
    return .fromByteSize(@min(ty.abiSize(cg.pt.zcu) - limb * 8, 8));
}

fn fieldOffset(cg: *CodeGen, ptr_agg_ty: Type, ptr_field_ty: Type, field_index: u32) i32 {
    const pt = cg.pt;
    const zcu = pt.zcu;
    const agg_ty = ptr_agg_ty.childType(zcu);
    return switch (agg_ty.containerLayout(zcu)) {
        .auto, .@"extern" => @intCast(agg_ty.structFieldOffset(field_index, zcu)),
        .@"packed" => @divExact(@as(i32, ptr_agg_ty.ptrInfo(zcu).packed_offset.bit_offset) +
            (if (zcu.typeToStruct(agg_ty)) |loaded_struct| pt.structPackedFieldBitOffset(loaded_struct, field_index) else 0) -
            ptr_field_ty.ptrInfo(zcu).packed_offset.bit_offset, 8),
    };
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
    return abi.CCResolver.resolve(cg.pt, cg.gpa, cg.target, fn_ty) catch |err| switch (err) {
        error.CCSelectFailed => return cg.fail("Failed to resolve calling convention values", .{}),
        else => |e| return e,
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

        cg_mir_log.debug("{f}", .{cg.fmtAir(inst)});

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
            .not => try cg.airNot(inst),

            .bitcast => try cg.airBitCast(inst),
            .intcast => try cg.airIntCast(inst),

            .assembly => cg.airAsm(inst) catch |err| switch (err) {
                error.AsmParseFail => return error.CodegenFail,
                else => |e| return e,
            },
            .trap, .breakpoint => try cg.asmInst(.@"break"(0)),

            .ret_addr => try cg.airRetAddr(inst),
            .frame_addr => try (try cg.tempInit(.usize, .{ .lea_frame = .{ .index = .stack_frame } })).finish(inst, &.{}, cg),

            .alloc => try cg.airAlloc(inst),
            .ret_ptr => try cg.airRetPtr(inst),
            .inferred_alloc, .inferred_alloc_comptime => unreachable,
            .load => try cg.airLoad(inst),
            .store => try cg.airStore(inst, false),
            .store_safe => try cg.airStore(inst, true),

            .call => try cg.airCall(inst, .auto),
            .call_always_tail => try cg.airCall(inst, .always_tail),
            .call_never_tail => try cg.airCall(inst, .never_tail),
            .call_never_inline => try cg.airCall(inst, .never_inline),

            .cmp_eq => try cg.airCmp(inst, .{ .cond = .eq, .swap = false, .opti = false }),
            .cmp_eq_optimized => try cg.airCmp(inst, .{ .cond = .eq, .swap = false, .opti = true }),
            .cmp_neq => try cg.airCmp(inst, .{ .cond = .ne, .swap = false, .opti = false }),
            .cmp_neq_optimized => try cg.airCmp(inst, .{ .cond = .ne, .swap = false, .opti = true }),
            .cmp_lt => try cg.airCmp(inst, .{ .cond = .gt, .swap = true, .opti = false }),
            .cmp_lt_optimized => try cg.airCmp(inst, .{ .cond = .gt, .swap = true, .opti = true }),
            .cmp_lte => try cg.airCmp(inst, .{ .cond = .le, .swap = false, .opti = false }),
            .cmp_lte_optimized => try cg.airCmp(inst, .{ .cond = .le, .swap = false, .opti = true }),
            .cmp_gt => try cg.airCmp(inst, .{ .cond = .gt, .swap = false, .opti = false }),
            .cmp_gt_optimized => try cg.airCmp(inst, .{ .cond = .gt, .swap = false, .opti = true }),
            .cmp_gte => try cg.airCmp(inst, .{ .cond = .le, .swap = true, .opti = false }),
            .cmp_gte_optimized => try cg.airCmp(inst, .{ .cond = .le, .swap = true, .opti = true }),

            .block => try cg.airBlock(inst),
            .dbg_inline_block => try cg.airDbgInlineBlock(inst),
            .loop => try cg.airLoop(inst),
            .br => try cg.airBr(inst),
            .repeat => try cg.airRepeat(inst),
            .cond_br => try cg.airCondBr(inst),

            .is_err => try cg.airIsErr(inst, false),
            .is_non_err => try cg.airIsErr(inst, true),

            .slice_ptr => try cg.airSlicePtr(inst),
            .slice_len => try cg.airSliceLen(inst),
            .slice_elem_ptr => try cg.airPtrElemPtr(inst),
            .ptr_elem_ptr => try cg.airPtrElemPtr(inst),
            .slice_elem_val => try cg.airPtrElemVal(inst),
            .ptr_elem_val => try cg.airPtrElemVal(inst),

            .struct_field_ptr => try cg.airStructFieldPtr(inst),
            .struct_field_ptr_index_0 => try cg.airStructFieldPtrConst(inst, 0),
            .struct_field_ptr_index_1 => try cg.airStructFieldPtrConst(inst, 1),
            .struct_field_ptr_index_2 => try cg.airStructFieldPtrConst(inst, 2),
            .struct_field_ptr_index_3 => try cg.airStructFieldPtrConst(inst, 3),

            .unwrap_errunion_payload => try cg.airUnwrapErrUnionPayload(inst),
            .unwrap_errunion_err => try cg.airUnwrapErrUnionErr(inst),
            .unwrap_errunion_payload_ptr => try cg.airUnwrapErrUnionPayloadPtr(inst),
            .unwrap_errunion_err_ptr => try cg.airUnwrapErrUnionErrPtr(inst),
            .wrap_errunion_payload => try cg.airWrapErrUnionPayload(inst),
            .wrap_errunion_err => try cg.airWrapErrUnionErr(inst),

            .@"try", .try_cold => try cg.airTry(inst),
            .try_ptr, .try_ptr_cold => try cg.airTryPtr(inst),

            .unreach => {},

            .intcast_safe,
            .add_safe,
            .sub_safe,
            .mul_safe,
            => return cg.fail("legalization miss (Zig compiler bug)", .{}),

            .dbg_stmt => if (!cg.mod.strip) {
                const dbg_stmt = cg.getAirData(inst).dbg_stmt;
                try cg.asmPseudo(.dbg_line_stmt_line_column, .{ .line_column = .{
                    .line = dbg_stmt.line,
                    .column = dbg_stmt.column,
                } });
            },
            .dbg_empty_stmt => if (!cg.mod.strip) {
                if (cg.mir_instructions.len > 0) {
                    const prev_mir_tag = &cg.mir_instructions.items(.tag)[cg.mir_instructions.len - 1];
                    if (prev_mir_tag.* == Mir.Inst.Tag.fromPseudo(.dbg_line_line_column))
                        prev_mir_tag.* = Mir.Inst.Tag.fromPseudo(.dbg_line_stmt_line_column);
                }
                try cg.asmInst(.andi(.r0, .r0, 0));
            },
            // TODO: emit debug info
            .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline => {
                const pl_op = cg.getAirData(inst).pl_op;
                var ops = try cg.tempsFromOperands(inst, .{pl_op.operand});
                try ops[0].die(cg);
            },

            else => return cg.fail(
                "TODO implement {s} for LoongArch64 CodeGen",
                .{@tagName(air_tags[@intFromEnum(inst)])},
            ),
        }

        try cg.resetTemps(@enumFromInt(0));
        verbose_tracking_log.debug("{f}", .{cg.fmtTracking()});
        cg.checkInvariantsAfterAirInst();
    }
}

const FormatAirData = struct {
    self: *CodeGen,
    inst: Air.Inst.Index,
};
fn formatAir(data: FormatAirData, writer: *Writer) Writer.Error!void {
    return data.self.air.writeInst(writer, data.inst, data.self.pt, data.self.liveness);
}
fn fmtAir(self: *CodeGen, inst: Air.Inst.Index) std.fmt.Formatter(FormatAirData, formatAir) {
    return .{ .data = .{ .self = self, .inst = inst } };
}

fn formatTracking(cg: *CodeGen, writer: *Writer) Writer.Error!void {
    var it = cg.inst_tracking.iterator();
    while (it.next()) |entry| try writer.print("\n{f} = {f}", .{ entry.key_ptr.*, entry.value_ptr.* });

    try writer.writeAll("\nUsed registers:");
    var reg_it = cg.register_manager.free_registers.iterator(.{ .kind = .unset });
    while (reg_it.next()) |index| try writer.print(" {s}", .{@tagName(RegisterManager.regAtTrackedIndex(@intCast(index)))});
}
fn fmtTracking(cg: *CodeGen) std.fmt.Formatter(*CodeGen, formatTracking) {
    return .{ .data = cg };
}

fn formatFrameLocs(cg: *CodeGen, writer: *Writer) Writer.Error!void {
    for (0..cg.frame_allocs.len) |i| {
        try writer.print("\n- {f}: {}\n      @ {f}", .{ @as(FrameIndex, @enumFromInt(i)), cg.frame_allocs.get(i), cg.frame_locs.get(i) });
    }
}
fn fmtFrameLocs(cg: *CodeGen) std.fmt.Formatter(*CodeGen, formatFrameLocs) {
    return .{ .data = cg };
}

fn resetTemps(cg: *CodeGen, from_index: Temp.Index) InnerError!void {
    if (std.debug.runtime_safety) {
        var any_valid = false;
        for (@intFromEnum(from_index)..@intFromEnum(cg.next_temp_index)) |temp_index| {
            const temp: Temp.Index = @enumFromInt(temp_index);
            if (temp.isValid(cg)) {
                any_valid = true;
                log.err("failed to kill {f}: {f}, tracking: {f}", .{
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
    tracking_log.debug("{f} => {f} (birth)", .{ temp_index.toIndex(), value });
    return .{ .index = temp_index.toIndex() };
}

fn tempFromValue(cg: *CodeGen, value: Value) InnerError!Temp {
    return cg.tempInit(value.typeOf(cg.pt.zcu), try cg.lowerValue(value));
}

fn tempMemFromValue(cg: *CodeGen, value: Value) InnerError!Temp {
    return cg.tempMemFromAlignedValue(.none, value);
}

fn tempMemFromAlignedValue(cg: *CodeGen, alignment: InternPool.Alignment, value: Value) InnerError!Temp {
    const ty = value.typeOf(cg.pt.zcu);
    return cg.tempInit(ty, .{ .load_uav = .{
        .val = value.toIntern(),
        .orig_ty = (try cg.pt.ptrType(.{
            .child = ty.toIntern(),
            .flags = .{
                .is_const = true,
                .alignment = alignment,
            },
        })).toIntern(),
    } });
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
        tracking_log.debug("{f} => {f} (birth from operand)", .{ temp_index.toIndex(), tracking.short });

        if (!cg.reuseTemp(tracking, temp.index, op_inst)) return .{ .index = op_ref.toIndex().? };
        cg.temp_type[@intFromEnum(temp_index)] = cg.typeOf(op_ref);
        cg.next_temp_index = @enumFromInt(@intFromEnum(temp_index) + 1);
        return temp;
    }

    if (op_ref.toIndex()) |op_inst| return .{ .index = op_inst };
    const val = op_ref.toInterned().?;
    return cg.tempInit(.fromInterned(ip.typeOf(val)), try cg.lowerValue(.fromInterned(val)));
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

fn tempReuseOrAlloc(cg: *CodeGen, inst: Air.Inst.Index, op: Temp, op_i: Air.Liveness.OperandInt, ty: Type, opts: MCVAllocOptions) InnerError!struct { Temp, bool } {
    if (cg.liveness.operandDies(inst, op_i) and op.isMut(cg)) {
        cg.reused_operands.set(op_i);
        return .{ op, true };
    } else {
        return .{ try cg.tempAlloc(ty, opts), false };
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

fn resolveRef(cg: *CodeGen, ref: Air.Inst.Ref) InnerError!MCValue {
    const zcu = cg.pt.zcu;
    const ty = cg.typeOf(ref);

    // If the type has no codegen bits, no need to store it.
    if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;

    const mcv: MCValue = if (ref.toIndex()) |inst| mcv: {
        break :mcv cg.inst_tracking.getPtr(inst).?.short;
    } else mcv: {
        break :mcv try cg.lowerValue(.fromInterned(ref.toInterned().?));
    };

    switch (mcv) {
        .none, .unreach, .dead => unreachable,
        else => return mcv,
    }
}

fn resolveInst(cg: *CodeGen, inst: Air.Inst.Index) *InstTracking {
    const tracking = cg.inst_tracking.getPtr(inst).?;
    return switch (tracking.short) {
        .none, .unreach, .dead => unreachable,
        else => tracking,
    };
}

pub fn spillInstruction(cg: *CodeGen, reg: Register, inst: Air.Inst.Index) !void {
    const tracking = cg.inst_tracking.getPtr(inst) orelse return;
    if (std.debug.runtime_safety) {
        for (tracking.getRegs()) |tracked_reg| {
            if (tracked_reg.id() == reg.id()) break;
        } else unreachable; // spilled reg not tracked with spilled instruction
    }
    try tracking.spill(cg, inst);
    try tracking.trackSpill(cg, inst);
}

fn lowerValue(cg: *CodeGen, val: Value) Allocator.Error!MCValue {
    return switch (try codegen.lowerValue(cg.pt, val, cg.target)) {
        .none => .none,
        .undef => .undef,
        .immediate => |imm| .{ .immediate = imm },
        .lea_nav => |nav| .{ .lea_nav = .{ .index = nav } },
        .lea_uav => |uav| .{ .lea_uav = .{ .index = uav } },
        .load_uav => |uav| .{ .load_uav = .{ .index = uav } },
    };
}

fn checkInvariantsAfterAirInst(cg: *CodeGen) void {
    assert(!cg.register_manager.lockedRegsExist());

    if (std.debug.runtime_safety) {
        // check consistency of tracked registers
        var it = cg.register_manager.free_registers.iterator(.{ .kind = .unset });
        while (it.next()) |index| {
            const tracked_inst = cg.register_manager.registers[index];
            const tracking = cg.resolveInst(tracked_inst);
            for (tracking.getRegs()) |reg| {
                if (RegisterManager.indexOfRegIntoTracked(reg).? == index) break;
            } else unreachable; // tracked register not in use
        }
    }
}

fn feed(cg: *CodeGen, bt: *Air.Liveness.BigTomb, op: Air.Inst.Ref) !void {
    if (bt.feed()) if (op.toIndex()) |inst| try cg.inst_tracking.getPtr(inst).?.die(cg, inst);
}

fn finishAirResult(cg: *CodeGen, inst: Air.Inst.Index, result: MCValue) !void {
    if (cg.liveness.isUnused(inst) and cg.air.instructions.items(.tag)[@intFromEnum(inst)] != .arg) switch (result) {
        .none, .dead, .unreach => {},
        else => unreachable, // Why didn't the result die?
    } else {
        tracking_log.debug("{f} => {f} (birth)", .{ inst, result });
        cg.inst_tracking.putAssumeCapacityNoClobber(inst, .init(result));
        try cg.getValueIfFree(result, inst);
    }
}

fn finishAir(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    result: MCValue,
    operands: [Air.Liveness.bpi - 1]Air.Inst.Ref,
) !void {
    const tomb_bits = cg.liveness.getTombBits(inst);
    for (0.., operands) |op_index, op| {
        if (tomb_bits & @as(Air.Liveness.Bpi, 1) << @intCast(op_index) == 0) continue;
        if (cg.reused_operands.isSet(op_index)) continue;
        try cg.inst_tracking.getPtr(op.toIndexAllowNone() orelse continue).?.die(cg, inst);
    }
    cg.finishAirResult(inst, result);
}

const CopyOptions = struct {
    safety: bool = false,
};

fn genCopy(cg: *CodeGen, ty: Type, dst_mcv: MCValue, src_mcv: MCValue, opts: CopyOptions) !void {
    if (dst_mcv == .none) return;
    const zcu = cg.pt.zcu;
    if (!ty.hasRuntimeBits(zcu)) return;

    log.debug("copying {f} to {f} ({f}, safety = {})", .{ src_mcv, dst_mcv, ty.fmt(cg.pt), opts.safety });
    switch (dst_mcv) {
        .register => |reg| try cg.genCopyToReg(.fromByteSize(ty.abiSize(zcu)), reg, src_mcv, opts),
        inline .register_pair, .register_triple, .register_quadruple => |regs| {
            for (regs, 0..) |reg, reg_i| {
                try cg.genCopyToReg(cg.getLimbSize(ty, reg_i), reg, src_mcv.toLimbValue(reg_i), opts);
            }
        },
        .load_frame, .load_nav, .load_uav => try cg.genCopyToMem(ty, dst_mcv, src_mcv),
        else => return cg.fail("TODO: genCopy {s} => {s}", .{ @tagName(src_mcv), @tagName(dst_mcv) }),
    }
}

fn genCopyToReg(cg: *CodeGen, size: bits.Memory.Size, dst: Register, src_mcv: MCValue, opts: CopyOptions) !void {
    if (size == .dword and !cg.hasFeature(.@"64bit")) return cg.fail("Cannot copy double-words to register on LA32", .{});
    switch (src_mcv) {
        .none => {},
        .dead, .unreach => unreachable,
        .undef => if (opts.safety) try cg.asmInst(.lu12i_w(dst, 0xaaaa)),
        .register => |src| if (dst != src) try cg.asmInst(.@"or"(dst, src, .zero)),
        .register_bias => |ro| {
            const off = cast(i12, ro.off) orelse return cg.fail("TODO copy reg_bias to reg", .{});
            switch (cg.target.cpu.arch) {
                .loongarch32 => try cg.asmInst(.addi_w(dst, ro.reg, off)),
                .loongarch64 => try cg.asmInst(.addi_d(dst, ro.reg, off)),
                else => unreachable,
            }
        },
        .immediate => |imm| try cg.asmPseudo(.imm_to_reg, .{ .imm_reg = .{
            .imm = imm,
            .reg = dst,
        } }),
        .register_offset => |ro| {
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
            try cg.genCopyToReg(.dword, dst, .{ .register_bias = .{ .reg = ro.reg, .off = ro.off } }, .{});
            return cg.genCopyToReg(size, dst, .{ .register_offset = .{ .reg = dst } }, .{});
        },
        .lea_frame => |addr| try cg.asmPseudo(.frame_addr_to_reg, .{ .frame_reg = .{
            .frame = addr,
            .reg = dst,
        } }),
        .load_frame => |addr| {
            try cg.asmPseudo(.frame_addr_reg_mem, .{ .memop_frame_reg = .{
                .op = .{
                    .op = .load,
                    .signedness = .unsigned,
                    .size = size,
                },
                .frame = addr,
                .reg = dst,
                .tmp_reg = dst,
            } });
        },
        .lea_nav => |nav| try cg.asmPseudo(.nav_addr_to_reg, .{ .nav_reg = .{
            .nav = nav,
            .reg = dst,
        } }),
        .load_nav => |nav| {
            try cg.asmPseudo(.nav_memop, .{ .memop_nav_reg = .{
                .op = .{
                    .op = .load,
                    .signedness = .unsigned,
                    .size = size,
                },
                .nav = nav,
                .reg = dst,
                .tmp_reg = dst,
            } });
        },
        .lea_uav => |uav| try cg.asmPseudo(.uav_addr_to_reg, .{ .uav_reg = .{
            .uav = uav,
            .reg = dst,
        } }),
        .load_uav => |uav| {
            try cg.asmPseudo(.uav_memop, .{ .memop_uav_reg = .{
                .op = .{
                    .op = .load,
                    .signedness = .unsigned,
                    .size = size,
                },
                .uav = uav,
                .reg = dst,
                .tmp_reg = dst,
            } });
        },
        else => return cg.fail("TODO: genCopyToReg from {s}", .{@tagName(src_mcv)}),
    }
}

/// Copies a value from register to memory.
fn genCopyRegToMem(cg: *CodeGen, dst_mcv: MCValue, src: Register, size: bits.Memory.Size) !void {
    if (size == .dword and !cg.hasFeature(.@"64bit")) return cg.fail("Cannot copy double-words from register to memory on LA32", .{});
    switch (dst_mcv) {
        else => unreachable,
        .air_ref => |dst_ref| try cg.genCopyRegToMem(try cg.resolveRef(dst_ref), src, size),
        .memory => |addr| {
            const tmp_reg, const tmp_reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(tmp_reg_lock);
            try cg.genCopyToReg(.dword, tmp_reg, .{ .immediate = addr }, .{});
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
            const tmp_reg, const tmp_reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(tmp_reg_lock);
            try cg.asmPseudo(.frame_addr_reg_mem, .{ .memop_frame_reg = .{
                .op = .{
                    .op = .store,
                    .size = size,
                    .signedness = undefined,
                },
                .frame = addr,
                .reg = src,
                .tmp_reg = tmp_reg,
            } });
        },
        .load_nav => |nav_off| {
            const tmp_reg, const tmp_reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(tmp_reg_lock);
            try cg.asmPseudo(.nav_memop, .{ .memop_nav_reg = .{
                .op = .{
                    .op = .store,
                    .size = size,
                    .signedness = undefined,
                },
                .nav = nav_off,
                .reg = src,
                .tmp_reg = tmp_reg,
            } });
        },
        .load_uav => |uav_off| {
            const tmp_reg, const tmp_reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(tmp_reg_lock);
            try cg.asmPseudo(.uav_memop, .{ .memop_uav_reg = .{
                .op = .{
                    .op = .store,
                    .size = size,
                    .signedness = undefined,
                },
                .uav = uav_off,
                .reg = src,
                .tmp_reg = tmp_reg,
            } });
        },
        .undef,
        .load_lazy_sym,
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
        .register => |reg| return cg.genCopyRegToMem(dst_mcv, reg, .fromByteSize(abi_size)),
        .memory,
        .undef,
        => return cg.fail("TODO: genCopyToMem from {s}", .{@tagName(src_mcv)}),
        inline .register_pair, .register_triple, .register_quadruple => |regs| {
            for (regs, 0..) |reg, reg_i| {
                const size: bits.Memory.Size = limb_size: {
                    if (reg_i != regs.len - 1) break :limb_size .dword else {
                        const size = abi_size % 8;
                        break :limb_size if (size == 0) .dword else .fromByteSize(size);
                    }
                };
                try cg.genCopyRegToMem(dst_mcv.toLimbValue(reg_i), reg, size);
            }
        },
        .immediate, .register_bias, .lea_frame, .lea_nav, .lea_uav, .lea_lazy_sym => {
            const tmp_reg, const tmp_reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(tmp_reg_lock);

            try cg.genCopyToReg(.dword, tmp_reg, src_mcv, .{});
            try cg.genCopyRegToMem(dst_mcv, tmp_reg, .dword);
        },
        .register_frame => |reg_frame| {
            // copy reg
            try cg.genCopyRegToMem(dst_mcv, reg_frame.reg, .dword);
            // copy memory
            return cg.fail("TODO: genCopyToMem from {s}", .{@tagName(src_mcv)});
        },
        .register_offset, .load_frame, .load_nav, .load_uav, .load_lazy_sym => {
            const reg, const reg_lock = try cg.allocRegAndLock(.usize);
            defer cg.register_manager.unlockReg(reg_lock);
            for (0..@intCast(cg.getLimbCount(ty))) |limb_i| {
                const size = cg.getLimbSize(ty, limb_i);
                try cg.genCopyToReg(size, reg, src_mcv.toLimbValue(limb_i), .{});
                try cg.genCopyRegToMem(dst_mcv.toLimbValue(limb_i), reg, size);
            }
        },
    }
}

/// Truncates the value in the register in place.
/// Clobbers any remaining bits.
/// 32-bit values will not be truncated.
fn truncateRegister(cg: *CodeGen, ty: Type, reg: Register) !void {
    const zcu = cg.pt.zcu;

    assert(reg.class() == .int);
    const reg_size = cg.intRegisterSize();
    const bit_size = @as(u6, @intCast(ty.bitSize(zcu) % reg_size));

    // skip unneeded truncation
    if (bit_size == 0 or bit_size == 32) return;

    if (ty.isAbiInt(zcu)) {
        if (bit_size <= 32) {
            try cg.asmInst(.bstrpick_w(reg, reg, 0, @intCast(bit_size - 1)));
        } else {
            try cg.asmInst(.bstrpick_d(reg, reg, 0, bit_size - 1));
        }
    } else {
        if (reg_size == 32) {
            try cg.asmInst(.bstrpick_w(reg, reg, 0, @intCast(bit_size - 1)));
        } else {
            try cg.asmInst(.bstrpick_d(reg, reg, 0, bit_size - 1));
        }
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
        cg_select_log.debug("select finished: {}", .{result});
        if (sel.inst) |inst| {
            try result.finish(inst, sel.ops[0..sel.ops_count], sel.cg);
        }
        for (sel.temps[0..sel.temps_count]) |temp| {
            if (temp.index == result.index) continue;
            if (Temp.Index.fromIndex(temp.index).isValid(sel.cg)) try temp.die(sel.cg);
        }
    }

    fn fail(sel: *Select) error{ OutOfMemory, CodegenFail } {
        cg_select_log.debug("select failed after {} cases", .{sel.case_i});
        return sel.cg.fail("Failed to select", .{});
    }

    inline fn match(sel: *Select, case: Case) !bool {
        sel.case_i += 1;
        if (!case.requirement) {
            cg_select_log.debug("case {} miss for pre-requirement", .{sel.case_i});
            return false;
        }
        for (case.required_features.features) |maybe_feature| {
            if (maybe_feature) |feature| {
                if (!sel.cg.hasFeature(feature)) {
                    cg_select_log.debug("case {} miss for missing feature: {s}", .{ sel.case_i, @tagName(feature) });
                    return false;
                }
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
        required_features: FeatureRequirement = .none,
        requirement: bool = true,
        patterns: []const SrcPattern,
        temps: []const TempSpec = &.{},
    };

    pub const FeatureRequirement = struct {
        features: [4]?std.Target.loongarch.Feature = @splat(null),

        const none: FeatureRequirement = .{};

        fn init(comptime features: packed struct {
            la64: bool = false,
            f: bool = false,
            d: bool = false,
            lsx: bool = false,
            lasx: bool = false,
        }) FeatureRequirement {
            var result: FeatureRequirement = .{};
            var result_i: usize = 0;

            if (features.la64) {
                result.features[result_i] = .@"64bit";
                result_i += 1;
            }
            if (features.f) {
                result.features[result_i] = .f;
                result_i += 1;
            }
            if (features.d) {
                result.features[result_i] = .d;
                result_i += 1;
            }
            if (features.lasx) {
                result.features[result_i] = .lasx;
                result_i += 1;
            } else if (features.lsx) {
                result.features[result_i] = .lsx;
                result_i += 1;
            }

            return result;
        }
    };

    pub const SrcPattern = struct {
        srcs: []const Src,
        commute: struct { u8, u8 } = .{ 0, 0 },

        pub const Src = union(enum) {
            none,
            any,
            zero,
            imm,
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
            regs,
            reg_frame,

            pub const imm12: Src = .{ .imm_fit = 12 };
            pub const imm20: Src = .{ .imm_fit = 20 };
            /// Immediate 0, see also zero
            pub const imm_zero: Src = .{ .imm_val = 0 };
            pub const imm_one: Src = .{ .imm_val = 1 };
            pub const int_reg: Src = .{ .reg = .int };
            pub const to_int_reg: Src = .{ .to_reg = .int };
            pub const int_mut_reg: Src = .{ .mut_reg = .int };
            pub const to_int_mut_reg: Src = .{ .to_mut_reg = .int };

            fn matches(pat: Src, temp: Temp, cg: *CodeGen) bool {
                return switch (pat) {
                    .none => temp.tracking(cg).short == .none,
                    .any => true,
                    .zero => switch (temp.tracking(cg).short) {
                        .immediate => |imm| imm == 0,
                        .register => |reg| reg == Register.zero,
                        else => false,
                    },
                    .imm => temp.tracking(cg).short == .immediate,
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
                    .regs => temp.tracking(cg).short.isInRegister(),
                    .reg_frame => temp.tracking(cg).short == .register_frame,
                };
            }

            fn convert(pat: Src, temp: *Temp, cg: *CodeGen) InnerError!bool {
                return switch (pat) {
                    .none, .any, .zero, .imm, .imm_val, .imm_fit, .regs, .reg_frame => false,
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
                .constant => |constant| try cg.tempInit(constant.typeOf(zcu), try cg.lowerValue(constant)),
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
                    return try cg.tempInit(.usize, .{ .lea_lazy_sym = lazy_symbol });
                },
            };
        }
    };
};

fn airArg(cg: *CodeGen, inst: Air.Inst.Index) !void {
    var arg_index = cg.arg_index;
    while (cg.args_mcv[arg_index] == .none) arg_index += 1;
    const arg_mcv = cg.args_mcv[arg_index];
    cg.arg_index = arg_index + 1;

    try cg.finishAirResult(inst, arg_mcv);
}

fn airRet(cg: *CodeGen, inst: Air.Inst.Index, safety: bool) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;
    const un_op = cg.getAirData(inst).un_op;

    const op_temp = try cg.tempFromOperand(un_op, false);

    // try to skip the copy
    if (op_temp.maybeTracking(cg)) |op_tracking| {
        if (std.meta.eql(op_tracking.short, cg.ret_mcv)) {
            try op_temp.finish(inst, &.{op_temp}, cg);
            try cg.finishReturn(inst);
            return;
        }
    }

    // copy return values into proper location
    const ret_ty = cg.fn_type.fnReturnType(zcu);
    const ret_temp = switch (cg.call_info.return_value) {
        .ref_frame => |_| deref_ret: {
            // load pointer
            const ret_ptr = try cg.tempInit(.usize, cg.ret_mcv);
            const ret_temp = try ret_ptr.load(cg, ret_ty, .{ .safety = safety });
            try ret_ptr.die(cg);
            break :deref_ret ret_temp;
        },
        else => try cg.tempInit(ret_ty, cg.ret_mcv),
    };
    try op_temp.copy(ret_temp, cg, ret_ty);

    try ret_temp.finish(inst, &.{op_temp}, cg);
    try cg.finishReturn(inst);
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
            try un_temp.loadTo(ret_temp, cg, ret_ty, .{});
            try ret_temp.die(cg);
        },
    }

    try (try cg.tempInit(.noreturn, .unreach)).finish(inst, &.{un_temp}, cg);
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

    // case 1: 32-bit integers
    if (try sel.match(.{
        .requirement = ty.isInt(zcu) and
            ty.intInfo(zcu).bits <= 32,
        .patterns = &.{.{ .srcs = &.{ .to_int_reg, .to_int_reg } }},
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{ lhs, rhs }, .{ .use_frame = false });
        switch (op) {
            .add => try cg.asmInst(.add_w(dst.getReg(cg), lhs.getReg(cg), rhs.getReg(cg))),
            .sub => try cg.asmInst(.sub_w(dst.getReg(cg), lhs.getReg(cg), rhs.getReg(cg))),
        }
        try dst.truncateRegister(cg);
        try sel.finish(dst);
    } else
    // case 2: 64-bit integers
    if (try sel.match(.{
        .required_features = .init(.{ .la64 = true }),
        .requirement = ty.isInt(zcu) and
            ty.intInfo(zcu).bits <= 64,
        .patterns = &.{.{ .srcs = &.{ .to_int_reg, .to_int_reg } }},
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{ lhs, rhs }, .{ .use_frame = false });
        switch (op) {
            .add => try cg.asmInst(.add_d(dst.getReg(cg), lhs.getReg(cg), rhs.getReg(cg))),
            .sub => try cg.asmInst(.sub_d(dst.getReg(cg), lhs.getReg(cg), rhs.getReg(cg))),
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

    // case 1: RI
    if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .imm12 } },
            .{ .srcs = &.{ .to_int_reg, .imm12 }, .commute = .{ 0, 1 } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst, _ = try cg.tempReuseOrAlloc(inst, lhs, 0, ty, .{ .use_frame = false });
        const lhs_limb = lhs.toLimbValue(0, cg);
        const dst_limb = dst.toLimbValue(0, cg);
        try asmIntLogicBinOpRRI(cg, op, dst_limb.getReg().?, lhs_limb.getReg().?, @intCast(rhs.getUnsignedImm(cg)));
        try sel.finish(dst);
    }
    // case 2: RR
    else if (try sel.match(.{
        .patterns = &.{.{ .srcs = &.{ .to_int_reg, .to_int_reg } }},
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst, _ = try cg.tempReuseOrAlloc(inst, lhs, 0, ty, .{ .use_frame = false });
        for (0..@intCast(lhs.getLimbCount(cg))) |limb_i| {
            const lhs_limb = lhs.toLimbValue(limb_i, cg);
            const rhs_limb = rhs.toLimbValue(limb_i, cg);
            const dst_limb = dst.toLimbValue(limb_i, cg);
            try asmIntLogicBinOpRRR(cg, op, dst_limb.getReg().?, lhs_limb.getReg().?, rhs_limb.getReg().?);
        }
        try sel.finish(dst);
    }
    // case 3: limbs
    else if (try sel.match(.{
        .patterns = &.{.{ .srcs = &.{ .any, .any } }},
        .temps = &.{ .any_usize_reg, .any_usize_reg },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const tmp1, const tmp2 = sel.temps[0..2].*;
        const dst, _ = try cg.tempReuseOrAlloc(inst, lhs, 0, ty, .{ .use_frame = false });
        for (0..@intCast(lhs.getLimbCount(cg))) |limb_i| {
            const lhs_limb = try tmp1.ensureReg(cg, lhs.toLimbValue(limb_i, cg));
            const rhs_limb = try tmp2.ensureReg(cg, rhs.toLimbValue(limb_i, cg));
            const dst_limb = dst.toLimbValue(limb_i, cg);
            try asmIntLogicBinOpRRR(cg, op, dst_limb.getReg().?, lhs_limb.getReg().?, rhs_limb.getReg().?);
        }
        try sel.finish(dst);
    } else return sel.fail();
}

fn airNot(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;

    const ty_op = cg.getAirData(inst).ty_op;
    const ty = ty_op.ty.toType();
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ty_op.operand}));

    // case 1: booleans
    if (try sel.match(.{
        .requirement = ty.zigTypeTag(zcu) == .bool,
        .patterns = &.{
            .{ .srcs = &.{.to_int_reg} },
        },
    })) {
        const op = sel.ops[0];
        const dst, _ = try cg.tempReuseOrAlloc(inst, op, 0, ty, .{ .use_frame = false });
        try cg.asmInst(.xori(dst.getReg(cg), op.getReg(cg), 1));
        try sel.finish(dst);
    }
    // case 2: integers, fit in one register
    else if (try sel.match(.{
        .requirement = ty.isInt(zcu),
        .patterns = &.{.{ .srcs = &.{.to_int_reg} }},
    })) {
        const op = sel.ops[0];
        const dst, _ = try cg.tempReuseOrAlloc(inst, op, 0, ty, .{ .use_frame = false });
        try cg.asmInst(.nor(dst.getReg(cg), op.getReg(cg), .zero));
        try sel.finish(dst);
    }
    // case 3: integers, per-limb
    else if (try sel.match(.{
        .requirement = ty.isInt(zcu),
        .patterns = &.{.{ .srcs = &.{.any} }},
        .temps = &.{.any_usize_reg},
    })) {
        const op = sel.ops[0];
        const tmp = sel.temps[0];
        const dst, _ = try cg.tempReuseOrAlloc(inst, op, 0, ty, .{ .use_frame = false });
        for (0..@intCast(op.getLimbCount(cg))) |limb_i| {
            const op_limb = try tmp.ensureReg(cg, op.toLimbValue(limb_i, cg));
            const dst_limb = dst.toLimbValue(limb_i, cg);
            try cg.asmInst(.nor(dst_limb.getReg().?, op_limb.getReg().?, .zero));
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
    const child_ty = ty.childType(zcu);
    const frame = try cg.allocFrameIndex(.initType(child_ty, zcu));
    const result = try cg.tempInit(.usize, .{ .lea_frame = .{ .index = frame } });
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
    const zcu = cg.pt.zcu;
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
        .memory, .register_offset, .load_frame, .load_nav, .load_uav, .load_lazy_sym => {
            if (ty.abiSize(zcu) == Type.usize.abiSize(zcu)) {
                var tmp = try cg.tempAlloc(.usize, .{ .use_frame = false });
                try val.copy(tmp, cg, .usize);
                try tmp.loadTo(tmp, cg, ty, .{});
                tmp.toType(cg, ty);
                try tmp.finish(inst, &.{val}, cg);
            } else {
                const tmp = try cg.tempAlloc(.usize, .{ .use_frame = false });
                try val.copy(tmp, cg, .usize);
                const dst = try tmp.load(cg, ty, .{});
                try tmp.die(cg);
                try dst.finish(inst, &.{val}, cg);
            }
        },
        .immediate, .register, .register_bias, .lea_frame, .lea_nav, .lea_uav, .lea_lazy_sym => {
            const tmp = try cg.tempAlloc(ty, .{});
            try val.loadTo(tmp, cg, ty, .{});
            try tmp.finish(inst, &.{val}, cg);
        },
    };
}

fn airStore(cg: *CodeGen, inst: Air.Inst.Index, safety: bool) !void {
    const bin_op = cg.getAirData(inst).bin_op;
    var ptr, const val = try cg.tempsFromOperands(inst, .{ bin_op.lhs, bin_op.rhs });
    const val_ty = val.typeOf(cg);

    try val.storeTo(ptr, cg, val_ty, .{ .safety = safety });

    try ptr.die(cg);
    try val.die(cg);
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
            .func => |func| try cg.asmPseudo(.call, .{ .nav = .{ .index = func.owner_nav } }),
            .@"extern" => |ext| try cg.asmPseudo(.call, .{ .nav = .{ .index = ext.owner_nav } }),
            // TODO what's this
            else => return cg.fail("TODO implement calling bitcasted functions", .{}),
        }
    } else {
        assert(cg.typeOf(callee).zigTypeTag(zcu) == .pointer);
        const addr_mcv = try cg.resolveRef(pl_op.operand);
        call: {
            switch (addr_mcv) {
                .register => |reg| break :call try cg.asmInst(.jirl(.ra, reg, 0)),
                .register_bias => |ro| if (cast(i18, ro.off)) |off18|
                    if (off18 & 0b11 == 0)
                        break :call try cg.asmInst(.jirl(.ra, ro.reg, @truncate(off18 >> 2))),
                else => {},
            }
            try cg.genCopyToReg(.dword, .t0, addr_mcv, .{});
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
                try cg.genCopyToReg(.fromByteSize(cg.typeOf(input).abiSize(cg.pt.zcu)), reg, input_cgv, .{});
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

const CmpOptions = struct {
    cond: Mir.BranchCondition.Tag,
    swap: bool,
    opti: bool,
};

// TODO: instruction combination
fn airCmp(cg: *CodeGen, inst: Air.Inst.Index, comptime opts: CmpOptions) !void {
    const zcu = cg.pt.zcu;
    const bin_op = cg.getAirData(inst).bin_op;
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ bin_op.lhs, bin_op.rhs }));
    if (opts.swap) std.mem.swap(Temp, &sel.ops[0], &sel.ops[1]);

    const ty = sel.ops[0].typeOf(cg);
    const cond: Mir.BranchCondition.Tag =
        if (ty.isSignedInt(zcu))
            opts.cond
        else switch (opts.cond) {
            .none, .eq, .ne, .leu, .gtu => opts.cond,
            .le => .leu,
            .gt => .gtu,
        };

    // case 1: SLTI
    if (try sel.match(.{
        .requirement = cond == .gt,
        .patterns = &.{
            .{ .srcs = &.{ .imm12, .to_int_reg } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{rhs}, .{ .use_frame = false });
        try cg.asmInst(.slti(dst.getReg(cg), rhs.getReg(cg), @intCast(lhs.getSignedImm(cg))));
        try sel.finish(dst);
    }
    // case 2: SLTUI
    else if (try sel.match(.{
        .requirement = cond == .gtu,
        .patterns = &.{
            .{ .srcs = &.{ .imm12, .to_int_reg } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{rhs}, .{ .use_frame = false });
        try cg.asmInst(.sltui(dst.getReg(cg), rhs.getReg(cg), @intCast(lhs.getSignedImm(cg))));
        try sel.finish(dst);
    }
    // case 3: SLT
    else if (try sel.match(.{
        .requirement = cond == .gt,
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .to_int_reg } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{ lhs, rhs }, .{ .use_frame = false });
        try cg.asmInst(.slt(dst.getReg(cg), rhs.getReg(cg), lhs.getReg(cg)));
        try sel.finish(dst);
    }
    // case 4: SLTU
    else if (try sel.match(.{
        .requirement = cond == .gtu,
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .to_int_reg } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{ lhs, rhs }, .{ .use_frame = false });
        try cg.asmInst(.sltu(dst.getReg(cg), rhs.getReg(cg), lhs.getReg(cg)));
        try sel.finish(dst);
    }
    // case 5: fallback to conditional branch
    else if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .to_int_reg } },
        },
    })) {
        const lhs, const rhs = sel.ops[0..2].*;
        const dst = try cg.tempTryReuseOrAlloc(inst, &.{ lhs, rhs }, .{ .use_frame = false });

        const label_if = try cg.asmBr(null, .compare(cond, lhs.getReg(cg), rhs.getReg(cg)));
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

    if (!cg.mod.strip) try cg.asmPseudo(.dbg_enter_block, .none);
    try cg.lowerBlock(inst, ty_pl.ty, @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]));
    if (!cg.mod.strip) try cg.asmPseudo(.dbg_exit_block, .none);
}

fn airDbgInlineBlock(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_pl = cg.getAirData(inst).ty_pl;
    const extra = cg.air.extraData(Air.DbgInlineBlock, ty_pl.payload);

    const old_inline_func = cg.inline_func;
    defer cg.inline_func = old_inline_func;
    cg.inline_func = extra.data.func;

    if (!cg.mod.strip) try cg.asmPseudo(.dbg_enter_inline_func, .{ .func = extra.data.func });
    try cg.lowerBlock(inst, ty_pl.ty, @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]));
    if (!cg.mod.strip) try cg.asmPseudo(.dbg_enter_inline_func, .{ .func = old_inline_func });
}

fn airLoop(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_pl = cg.getAirData(inst).ty_pl;
    const block = cg.air.extraData(Air.Block, ty_pl.payload);

    try cg.loops.putNoClobber(cg.gpa, inst, .{
        .state = try cg.saveState(),
        .target = cg.label(),
    });
    defer assert(cg.loops.remove(inst));
    try cg.genBodyBlock(@ptrCast(cg.air.extra.items[block.end..][0..block.data.body_len]));
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
    }
    try cg.getValueIfFree(tracking.short, inst);
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
        if (br.operand.toIndex()) |op_inst| try cg.inst_tracking.getPtr(op_inst).?.die(cg, op_inst);
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

fn airRepeat(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const repeat = cg.getAirData(inst).repeat;
    const loop = cg.loops.get(repeat.loop_inst).?;

    try cg.restoreState(loop.state, &.{}, .{
        .emit_instructions = true,
        .update_tracking = false,
        .resurrect = false,
        .close_scope = false,
    });
    _ = try cg.asmBr(loop.target, .none);
}

fn airCondBr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const pt = cg.pt;
    const zcu = pt.zcu;

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
            try cg.genCopyToReg(.fromByteSize(cond_ty.abiSize(zcu)), tmp_reg, cond_mcv, .{});
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

    // case 1: no operation needed
    // src and dst must have the same ABI size
    if (try sel.match(.{
        .requirement = src_ty.abiSize(zcu) == dst_ty.abiSize(zcu),
        .patterns = &.{.{ .srcs = &.{.any} }},
    })) {
        const src = sel.ops[0];
        if (cg.liveness.operandDies(inst, 0)) {
            cg.reused_operands.set(0);
            try src.finish(inst, &.{src}, cg);
        } else {
            const dst = try cg.tempAlloc(dst_ty, .{});
            try src.copy(dst, cg, dst_ty);
            try dst.finish(inst, &.{src}, cg);
        }
    } else return sel.fail();
}

fn airIntCast(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const dst_ty = ty_op.ty.toType();
    const src_ty = cg.typeOf(ty_op.operand);
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ty_op.operand}));

    assert(src_ty.isAbiInt(zcu) and dst_ty.isAbiInt(zcu));
    const src_ty_info = src_ty.intInfo(zcu);
    const dst_ty_info = dst_ty.intInfo(zcu);
    const src_reg_size = (src_ty_info.bits + 63) / 64;
    const dst_reg_size = (dst_ty_info.bits + 63) / 64;
    const src_tail_bits: u6 = @intCast(src_ty_info.bits % 64);
    const dst_tail_bits: u6 = @intCast(dst_ty_info.bits % 64);

    // case 1: no operation needed
    // 1. types with same bit size
    // 2. sign-extending modes are the same
    // 3. i32 to i32...64 promotion
    if (try sel.match(.{
        .requirement = src_reg_size == dst_reg_size and
            (src_ty_info.bits == dst_ty_info.bits or
                (src_tail_bits <= 32 and dst_tail_bits <= 32 and dst_tail_bits != 0) or
                (src_tail_bits > 32 and dst_tail_bits > 32) or
                (src_tail_bits == 32 and (dst_tail_bits >= 32 or dst_tail_bits == 0))),
        .patterns = &.{.{ .srcs = &.{.any} }},
    })) {
        const src = sel.ops[0];
        if (cg.liveness.operandDies(inst, 0)) {
            cg.reused_operands.set(0);
            try src.finish(inst, &.{src}, cg);
        } else {
            try (try cg.tempInit(dst_ty, .{ .air_ref = ty_op.operand })).finish(inst, &.{src}, cg);
        }
    } else
    // case 2: zero-extend the highest limb
    // 1. u32 to u/i33...64 promotion
    if (try sel.match(.{
        .required_features = .init(.{ .la64 = true }),
        .requirement = src_reg_size == dst_reg_size and
            src_ty_info.bits == 32 and
            src_ty_info.signedness == .unsigned and
            (dst_tail_bits > 32 or dst_tail_bits == 0),
        .patterns = &.{.{ .srcs = &.{.any} }},
    })) {
        const src = sel.ops[0];
        const dst, const dst_reused = try cg.tempReuseOrAlloc(inst, src, 0, dst_ty, .{});
        if (!dst_reused)
            try src.copy(dst, cg, src_ty);
        const src_limb, const src_alloc = try src.toLimbValue(src.getLimbCount(cg) - 1, cg).ensureReg(cg, inst, .usize);
        const dst_limb, const dst_alloc = try dst.toLimbValue(dst.getLimbCount(cg) - 1, cg).ensureReg(cg, inst, .usize);

        try cg.asmInst(.bstrpick_d(dst_limb, src_limb, 0, src_tail_bits));

        if (src_alloc) try cg.freeReg(src_limb);
        if (dst_alloc) try cg.freeReg(dst_limb);
        try dst.finish(inst, &.{src}, cg);
    } else return sel.fail();
}

/// Checks if a error union value is error. Returns only register values.
fn genIsErr(cg: *CodeGen, eu: Temp, reuse: bool, inverted: bool) !Temp {
    var sel = Select.init(cg, null, &.{eu});

    // case 1: error is in register
    if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{.regs} },
            .{ .srcs = &.{.reg_frame} },
        },
    })) {
        const src = sel.ops[0];
        const src_mcv = src.tracking(cg);
        const err_reg = src_mcv.getRegs()[0];
        const dst = dst: {
            if (reuse) {
                try src.die(cg);
                break :dst try cg.tempInit(.bool, .{ .register = err_reg });
            } else break :dst try cg.tempAlloc(.bool, .{ .use_frame = false });
        };
        const dst_reg = dst.getReg(cg);

        try cg.asmInst(.sltui(dst_reg, err_reg, 1));
        if (!inverted)
            try cg.asmInst(.xori(dst_reg, dst_reg, 1));

        try sel.finish(dst);
        return dst;
    }
    // case 2: error is in memory
    else if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{.to_mem} },
        },
    })) {
        const src = sel.ops[0];
        var limb = try src.getLimb(.bool, 0, cg, reuse);
        while (try limb.moveToRegister(cg, .int, true)) {}
        limb.toType(cg, .bool);
        const limb_reg = limb.getReg(cg);

        try cg.asmInst(.sltui(limb_reg, limb_reg, 1));
        if (!inverted)
            try cg.asmInst(.xori(limb_reg, limb_reg, 1));

        try sel.finish(limb);
        return limb;
    } else return sel.fail();
}

fn airIsErr(cg: *CodeGen, inst: Air.Inst.Index, inverted: bool) !void {
    const un_op = cg.getAirData(inst).un_op;
    const ops = try cg.tempsFromOperands(inst, .{un_op});
    const reuse = !cg.liveness.operandDies(inst, 0);
    const dst = try cg.genIsErr(ops[0], reuse, inverted);
    try dst.finish(inst, &ops, cg);
}

fn airSlicePtr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_op = cg.getAirData(inst).ty_op;
    const op = (try cg.tempsFromOperands(inst, .{ty_op.operand}))[0];
    const ty = ty_op.ty.toType();
    if (ty.isSlice(cg.pt.zcu)) {
        const ptr_ty = ty_op.ty.toType().slicePtrFieldType(cg.pt.zcu);
        const dst = try op.getLimb(ptr_ty, 0, cg, cg.liveness.operandDies(inst, 0));
        try dst.finish(inst, &.{op}, cg);
    } else {
        try op.finish(inst, &.{op}, cg);
    }
}

fn airSliceLen(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_op = cg.getAirData(inst).ty_op;
    const op = (try cg.tempsFromOperands(inst, .{ty_op.operand}))[0];
    const dst = try op.getLimb(.usize, 1, cg, cg.liveness.operandDies(inst, 0));
    try dst.finish(inst, &.{op}, cg);
}

fn airPtrElemPtr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_pl = cg.getAirData(inst).ty_pl;
    const bin = cg.air.extraData(Air.Bin, ty_pl.payload);
    const elem_ty = ty_pl.ty.toType().elemType2(zcu);
    var sel = Select.init(cg, inst, &try cg.tempsFromOperands(inst, .{ bin.data.lhs, bin.data.rhs }));
    const elem_off = elem_ty.abiAlignment(zcu).forward(elem_ty.abiSize(zcu));

    // case 1: constant index
    if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .imm } },
        },
    })) {
        const ptr_temp, const index_temp = sel.ops[0..2].*;
        ptr_temp.toOffset(cg, @intCast(index_temp.getUnsignedImm(cg) * elem_off));
        try sel.finish(ptr_temp);
    }
    // case 2: non-constant index
    else if (try sel.match(.{
        .required_features = .init(.{ .la64 = true }),
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .to_int_reg } },
        },
        .temps = &.{
            .any_usize_reg,
        },
    })) {
        const ptr_temp, const index_temp = sel.ops[0..2].*;
        const dst = sel.temps[0];
        const dst_reg = dst.getReg(cg);

        try cg.asmInst(.ori(dst_reg, .zero, @intCast(elem_off)));
        try cg.asmInst(.mul_d(dst_reg, dst_reg, index_temp.getReg(cg)));
        try cg.asmInst(.add_d(dst_reg, dst_reg, ptr_temp.getReg(cg)));

        try sel.finish(dst);
    } else return sel.fail();
}

fn airPtrElemVal(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const bin_op = cg.getAirData(inst).bin_op;
    const lhs_ty = cg.typeOf(bin_op.lhs);
    const elem_ty = lhs_ty.childType(zcu);
    const ptr_ty = if (lhs_ty.isSliceAtRuntime(zcu)) lhs_ty.slicePtrFieldType(zcu) else lhs_ty;
    const elem_off = elem_ty.abiAlignment(zcu).forward(elem_ty.abiSize(zcu));

    var ops = try cg.tempsFromOperands(inst, .{ bin_op.lhs, bin_op.rhs });
    ops[0] = try ops[0].getLimb(ptr_ty, 0, cg, cg.liveness.operandDies(inst, 0));
    var sel = Select.init(cg, inst, &ops);

    // case 1: constant index
    if (try sel.match(.{
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .imm } },
        },
        .temps = &.{
            .{ .type = elem_ty, .kind = .any },
        },
    })) {
        var ptr_temp, const index_temp = sel.ops[0..2].*;
        const dst = sel.temps[0];
        ptr_temp.toOffset(cg, @intCast(index_temp.getUnsignedImm(cg) * elem_off));
        try ptr_temp.loadTo(dst, cg, elem_ty, .{});
        try sel.finish(dst);
    }
    // case 2: non-constant index
    else if (try sel.match(.{
        .required_features = .init(.{ .la64 = true }),
        .patterns = &.{
            .{ .srcs = &.{ .to_int_reg, .to_int_reg } },
        },
        .temps = &.{
            .any_usize_reg,
            .{ .type = elem_ty, .kind = .any },
        },
    })) {
        const ptr_temp, const index_temp = sel.ops[0..2].*;
        var off, const dst = sel.temps[0..2].*;
        const off_reg = off.getReg(cg);

        try cg.asmInst(.ori(off_reg, .zero, @intCast(elem_off)));
        try cg.asmInst(.mul_d(off_reg, off_reg, index_temp.getReg(cg)));
        try cg.asmInst(.add_d(off_reg, off_reg, ptr_temp.getReg(cg)));

        try off.loadTo(dst, cg, elem_ty, .{});

        try sel.finish(dst);
    } else return sel.fail();
}

fn airStructFieldPtr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_pl = cg.getAirData(inst).ty_pl;
    const struct_field = cg.air.extraData(Air.StructField, ty_pl.payload).data;
    const ops = try cg.tempsFromOperands(inst, .{struct_field.struct_operand});
    const off = cg.fieldOffset(
        cg.typeOf(struct_field.struct_operand),
        ty_pl.ty.toType(),
        struct_field.field_index,
    );
    const dst, _ = try ops[0].ensureOffsetable(cg);
    dst.toOffset(cg, off);
    try dst.finish(inst, &ops, cg);
}

fn airStructFieldPtrConst(cg: *CodeGen, inst: Air.Inst.Index, index: u32) !void {
    const ty_op = cg.getAirData(inst).ty_op;
    const ops = try cg.tempsFromOperands(inst, .{ty_op.operand});
    const off = cg.fieldOffset(cg.typeOf(ty_op.operand), ty_op.ty.toType(), index);
    const dst, _ = try ops[0].ensureOffsetable(cg);
    dst.toOffset(cg, off);
    try dst.finish(inst, &ops, cg);
}

fn airUnwrapErrUnionPayload(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const payload_ty = ty_op.ty.toType();
    const field_off: i32 = @intCast(codegen.errUnionPayloadOffset(payload_ty, zcu));

    var ops = try cg.tempsFromOperands(inst, .{ty_op.operand});
    const dst = if (payload_ty.hasRuntimeBitsIgnoreComptime(zcu))
        try ops[0].read(cg, payload_ty, .{ .off = field_off })
    else
        try cg.tempInit(payload_ty, .none);
    try dst.finish(inst, &ops, cg);
}

fn airUnwrapErrUnionErr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const eu_ty = cg.typeOf(ty_op.operand);
    const eu_err_ty = ty_op.ty.toType();
    const payload_ty = eu_ty.errorUnionPayload(zcu);
    const field_off: i32 = @intCast(codegen.errUnionErrorOffset(payload_ty, zcu));

    var ops = try cg.tempsFromOperands(inst, .{ty_op.operand});
    const dst = try ops[0].read(cg, eu_err_ty, .{ .off = field_off });
    try dst.finish(inst, &ops, cg);
}

fn airUnwrapErrUnionPayloadPtr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const eu_ty = cg.typeOf(ty_op.operand).childType(zcu);
    const eu_pl_ty = eu_ty.errorUnionPayload(zcu);
    const eu_pl_off: i32 = @intCast(codegen.errUnionPayloadOffset(eu_pl_ty, zcu));

    var ops = try cg.tempsFromOperands(inst, .{ty_op.operand});
    const dst, _ = try ops[0].ensureOffsetable(cg);
    dst.toOffset(cg, eu_pl_off);
    try dst.finish(inst, &ops, cg);
}

fn airUnwrapErrUnionErrPtr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const eu_ty = cg.typeOf(ty_op.operand).childType(zcu);
    const eu_err_ty = ty_op.ty.toType();
    const eu_pl_ty = eu_ty.errorUnionPayload(zcu);
    const eu_err_off: i32 = @intCast(codegen.errUnionErrorOffset(eu_pl_ty, zcu));

    var ops = try cg.tempsFromOperands(inst, .{ty_op.operand});
    const dst = try ops[0].load(cg, eu_err_ty, .{ .off = eu_err_off });
    try dst.finish(inst, &ops, cg);
}

fn airWrapErrUnionPayload(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const eu_ty = ty_op.ty.toType();
    const eu_err_ty = eu_ty.errorUnionSet(zcu);
    const eu_pl_ty = cg.typeOf(ty_op.operand);
    const eu_err_off: i32 = @intCast(codegen.errUnionErrorOffset(eu_pl_ty, zcu));
    const eu_pl_off: i32 = @intCast(codegen.errUnionPayloadOffset(eu_pl_ty, zcu));

    var ops = try cg.tempsFromOperands(inst, .{ty_op.operand});
    var eu = try cg.tempAlloc(eu_ty, .{});
    try eu.write(ops[0], cg, .{ .off = eu_pl_off });

    var err = try cg.tempInit(eu_err_ty, .{ .immediate = 0 });
    try eu.write(err, cg, .{ .off = eu_err_off });
    try err.die(cg);

    try eu.finish(inst, &ops, cg);
}

fn airWrapErrUnionErr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const zcu = cg.pt.zcu;
    const ty_op = cg.getAirData(inst).ty_op;
    const eu_ty = ty_op.ty.toType();
    const eu_pl_ty = eu_ty.errorUnionPayload(zcu);
    const eu_err_off: i32 = @intCast(codegen.errUnionErrorOffset(eu_pl_ty, zcu));

    var ops = try cg.tempsFromOperands(inst, .{ty_op.operand});

    var eu = try cg.tempAlloc(eu_ty, .{});
    try eu.write(ops[0], cg, .{ .off = eu_err_off });
    try eu.finish(inst, &ops, cg);
}

fn airTry(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const pl_op = cg.getAirData(inst).pl_op;
    const extra = cg.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]);

    const operand_ty = cg.typeOf(pl_op.operand);
    const result = try cg.genTry(inst, pl_op.operand, operand_ty, false, body);
    try result.finish(inst, &.{}, cg);
}

fn airTryPtr(cg: *CodeGen, inst: Air.Inst.Index) !void {
    const ty_pl = cg.getAirData(inst).ty_pl;
    const extra = cg.air.extraData(Air.TryPtr, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(cg.air.extra.items[extra.end..][0..extra.data.body_len]);

    const operand_ty = cg.typeOf(extra.data.ptr);
    const result = try cg.genTry(inst, extra.data.ptr, operand_ty, true, body);
    try result.finish(inst, &.{}, cg);
}

fn genTry(
    cg: *CodeGen,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    operand_ty: Type,
    operand_is_ptr: bool,
    body: []const Air.Inst.Index,
) !Temp {
    const zcu = cg.pt.zcu;
    const liveness_cond_br = cg.liveness.getCondBr(inst);
    const ops = try cg.tempsFromOperands(inst, .{operand});
    const reuse_op = !cg.liveness.operandDies(inst, 0);

    const is_err_temp = if (operand_is_ptr)
        unreachable // TODO
    else
        try cg.genIsErr(ops[0], reuse_op, true);
    const is_err_reg = is_err_temp.getReg(cg);

    if (!reuse_op)
        try ops[0].die(cg);
    try is_err_temp.die(cg);
    try cg.resetTemps(@enumFromInt(0));

    const reloc = try cg.asmBr(null, .{ .ne = .{ is_err_reg, .zero } });
    const state = try cg.saveState();
    for (liveness_cond_br.else_deaths) |death| try cg.resolveInst(death).die(cg, death);
    try cg.genBodyBlock(body);
    try cg.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });
    cg.performReloc(reloc);

    for (liveness_cond_br.then_deaths) |death| try cg.resolveInst(death).die(cg, death);

    const payload_ty = operand_ty.errorUnionPayload(zcu);
    const field_off: i32 = @intCast(codegen.errUnionPayloadOffset(payload_ty, zcu));
    const result =
        if (cg.liveness.isUnused(inst))
            try cg.tempInit(payload_ty, .unreach)
        else if (operand_is_ptr)
            unreachable // TODO
        else if (payload_ty.hasRuntimeBitsIgnoreComptime(zcu))
            try ops[0].read(cg, payload_ty, .{ .off = field_off })
        else
            try cg.tempInit(payload_ty, .none);

    return result;
}
