//! This file contains the functionality for lowering LoongArch MIR to Instructions

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.lower);
const Writer = std.Io.Writer;

const Allocator = std.mem.Allocator;
const cast = std.math.cast;
const R_LARCH = std.elf.R_LARCH;

const link = @import("../../link.zig");
const Air = @import("../../Air.zig");
const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const codegen = @import("../../codegen.zig");
const ErrorMsg = Zcu.ErrorMsg;

const Mir = @import("Mir.zig");
const abi = @import("abi.zig");
const bits = @import("bits.zig");
const encoding = @import("encoding.zig");
const Lir = @import("Lir.zig");
const utils = @import("./utils.zig");
const Register = bits.Register;

const Lower = @This();

pt: Zcu.PerThread,
link_file: *link.File,
target: *const std.Target,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
pic: bool,
allocator: std.mem.Allocator,
mir: Mir,
cc: std.builtin.CallingConvention,
err_msg: ?*Zcu.ErrorMsg = null,
src_loc: Zcu.LazySrcLoc,
result_insts_len: ResultInstIndex = undefined,
result_insts: [max_result_insts]Lir.Inst = undefined,
result_relocs_len: ResultRelocIndex = undefined,
result_relocs: [max_result_relocs]Reloc = undefined,

pub const Error = error{
    OutOfMemory,
    LowerFail,
    CodegenFail,
} || codegen.GenerateSymbolError;

/// Lowered relocation.
/// The fields in instructions to be relocated must be lowered to zero.
pub const Reloc = struct {
    lir_index: u8,
    target: Target,
    off: i32,

    pub const Target = union(enum) {
        inst: struct {
            loc: Type,
            inst: Mir.Inst.Index,
        },
        elf_nav: struct {
            ty: R_LARCH,
            symbol: InternPool.Nav.Index,
        },
        elf_uav: struct {
            ty: R_LARCH,
            symbol: InternPool.Key.Ptr.BaseAddr.Uav,
        },

        pub fn format(target: Target, writer: *Writer) Writer.Error!void {
            switch (target) {
                .inst => |pl| try writer.print("MIR: {} ({s})", .{ pl.inst, @tagName(pl.loc) }),
                .elf_nav => |pl| try writer.print("NAV: R_LARCH_{s} => {}", .{ @tagName(pl.ty), pl.symbol }),
                .elf_uav => |pl| try writer.print("UAV: R_LARCH_{s} => {}", .{ @tagName(pl.ty), pl.symbol }),
            }
        }
    };

    pub const Type = enum {
        /// Immediate slot of Sd10k16ps2, right shift 2, relative to PC
        b26,
        /// Immediate slot of JDSk16ps2, right shift 2, relative to PC
        k16,
    };
};

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, index: Mir.Inst.Index) Error!struct {
    insts: []const Lir.Inst,
    relocs: []const Reloc,
} {
    lower.result_insts = undefined;
    lower.result_relocs = undefined;
    errdefer lower.result_insts = undefined;
    errdefer lower.result_relocs = undefined;
    lower.result_insts_len = 0;
    lower.result_relocs_len = 0;
    defer lower.result_insts_len = undefined;
    defer lower.result_relocs_len = undefined;

    const inst = lower.mir.instructions.get(index);
    log.debug("  {}: {f}", .{ index, inst });

    lower_inst: switch (inst.tag.unwrap()) {
        .inst => |opcode| lower.emitLir(.{ .opcode = opcode, .data = inst.data.op }),
        .pseudo => |tag| {
            switch (tag) {
                .none => {},
                // TODO: impl func prolugue
                .func_prologue => {
                    if (lower.mir.frame_size != 0) {
                        const off = -@as(i64, @intCast(lower.mir.frame_size));
                        try lower.emitRegBiasToReg(.sp, .sp, off);
                    }
                    if (lower.mir.spill_ra)
                        try lower.emitRegFrameOp(.ra, .{ .index = .ret_addr_frame }, .t0, .st_d, .stx_d);
                },
                .func_epilogue => {
                    if (lower.mir.spill_ra)
                        try lower.emitRegFrameOp(.ra, .{ .index = .ret_addr_frame }, .t0, .ld_d, .ldx_d);
                    if (lower.mir.frame_size != 0)
                        try lower.emitRegBiasToReg(.sp, .sp, @intCast(lower.mir.frame_size));
                    lower.emit(.jirl(.ra, .ra, 0));
                },
                .jump_to_epilogue => {
                    if (index + 1 == lower.mir.epilogue_begin) {
                        log.debug("omitted jump_to_epilogue", .{});
                    } else {
                        lower.emit(.b(0, 0));
                        lower.relocInst(.b26, lower.mir.epilogue_begin, 0);
                    }
                },
                .dbg_line_line_column,
                .dbg_line_stmt_line_column,
                .dbg_enter_block,
                .dbg_exit_block,
                .dbg_enter_inline_func,
                .dbg_exit_inline_func,
                => {},
                .branch => {
                    const target_inst = inst.data.br.inst;
                    if (target_inst + 1 == index) break :lower_inst;
                    switch (inst.data.br.cond) {
                        .none => {
                            lower.emit(.b(0, 0));
                            lower.relocInst(.b26, target_inst, 0);
                        },
                        .eq => |regs| {
                            lower.emit(.beq(regs[0], regs[1], 0));
                            lower.relocInst(.k16, target_inst, 0);
                        },
                        .ne => |regs| {
                            lower.emit(.bne(regs[0], regs[1], 0));
                            lower.relocInst(.k16, target_inst, 0);
                        },
                        .le => |regs| {
                            lower.emit(.ble(regs[0], regs[1], 0));
                            lower.relocInst(.k16, target_inst, 0);
                        },
                        .gt => |regs| {
                            lower.emit(.bgt(regs[0], regs[1], 0));
                            lower.relocInst(.k16, target_inst, 0);
                        },
                        .leu => |regs| {
                            lower.emit(.bleu(regs[0], regs[1], 0));
                            lower.relocInst(.k16, target_inst, 0);
                        },
                        .gtu => |regs| {
                            lower.emit(.bgtu(regs[0], regs[1], 0));
                            lower.relocInst(.k16, target_inst, 0);
                        },
                    }
                },
                .imm_to_reg => try lower.emitImmToReg(inst.data.imm_reg.imm, inst.data.imm_reg.reg),
                .frame_addr_to_reg => {
                    const frame_addr = inst.data.frame_reg.frame;
                    const frame_loc = lower.resolveFrame(frame_addr.index);
                    const reg = inst.data.frame_reg.reg;
                    try lower.emitRegBiasToReg(reg, frame_loc.base, @as(i64, frame_loc.offset + frame_addr.off));
                },
                .frame_addr_reg_mem => {
                    const data = inst.data.memop_frame_reg;
                    try lower.emitRegFrameOp(data.reg, data.frame, data.tmp_reg, data.op.toOpCodeRI(), data.op.toOpCodeRR());
                },
                .nav_memop => {
                    const data = inst.data.memop_nav_reg;
                    lower.emit(.pcalau12i(data.tmp_reg, 0));
                    lower.relocElfNav(.PCALA_HI20, data.nav);
                    lower.emit(.{ .opcode = data.op.toOpCodeRI(), .data = .{ .DJSk12 = .{ data.reg, data.tmp_reg, 0 } } });
                    lower.relocElfNav(.PCALA_LO12, data.nav);
                },
                .uav_memop => {
                    const data = inst.data.memop_uav_reg;
                    lower.emit(.pcalau12i(data.tmp_reg, 0));
                    lower.relocElfUav(.PCALA_HI20, data.uav);
                    lower.emit(.{ .opcode = data.op.toOpCodeRI(), .data = .{ .DJSk12 = .{ data.reg, data.tmp_reg, 0 } } });
                    lower.relocElfUav(.PCALA_LO12, data.uav);
                },
                .nav_addr_to_reg => {
                    const data = inst.data.nav_reg;
                    lower.emit(.pcalau12i(data.reg, 0));
                    lower.relocElfNav(.PCALA_HI20, data.nav);
                    lower.emit(.addi_d(data.reg, data.reg, 0));
                    lower.relocElfNav(.PCALA_LO12, data.nav);
                },
                .uav_addr_to_reg => {
                    const data = inst.data.uav_reg;
                    lower.emit(.pcalau12i(data.reg, 0));
                    lower.relocElfUav(.PCALA_HI20, data.uav);
                    lower.emit(.addi_d(data.reg, data.reg, 0));
                    lower.relocElfUav(.PCALA_LO12, data.uav);
                },
                .call => {
                    if (!lower.hasFeature(.@"64bit")) return lower.fail("TODO function call in LA32", .{});
                    const nav = inst.data.nav;
                    lower.emit(.pcaddu18i(.ra, 0));
                    lower.relocElfNav(.CALL36, nav);
                    lower.emit(.jirl(.ra, .ra, 0));
                },
                .load_ra => if (lower.mir.spill_ra)
                    try lower.emitRegFrameOp(.ra, .{ .index = .ret_addr_frame }, .ra, .ld_d, .ldx_d),
                .spill_int_regs => lower.emitRegSpill(inst.data.reg_list, .{
                    .frame = .spill_int_frame,
                    .reg_class = .int,
                    .inst = .st_d,
                }),
                .restore_int_regs => lower.emitRegSpill(inst.data.reg_list, .{
                    .frame = .spill_int_frame,
                    .reg_class = .int,
                    .inst = .ld_d,
                }),
                .spill_float_regs => lower.emitRegSpill(inst.data.reg_list, .{
                    .frame = .spill_float_frame,
                    .reg_class = .float,
                    .inst = .fst_d,
                }),
                .restore_float_regs => lower.emitRegSpill(inst.data.reg_list, .{
                    .frame = .spill_float_frame,
                    .reg_class = .float,
                    .inst = .fld_d,
                }),
            }
        },
    }

    return .{
        .insts = lower.result_insts[0..lower.result_insts_len],
        .relocs = lower.result_relocs[0..lower.result_relocs_len],
    };
}

inline fn emit(lower: *Lower, inst: encoding.Inst) void {
    lower.emitLir(.fromInst(inst));
}

fn emitLir(lower: *Lower, inst: Lir.Inst) void {
    log.debug("  | {f}", .{inst});
    lower.result_insts[lower.result_insts_len] = inst;
    lower.result_insts_len += 1;
}

fn reloc(lower: *Lower, target: Reloc.Target, off: i32) void {
    log.debug("  |    reloc: {f} (+{})", .{ target, off });
    lower.result_relocs[lower.result_relocs_len] = .{
        .lir_index = lower.result_insts_len - 1,
        .target = target,
        .off = off,
    };
    lower.result_relocs_len += 1;
}

inline fn relocElfNav(lower: *Lower, ty: R_LARCH, sym: bits.NavOffset) void {
    lower.reloc(.{ .elf_nav = .{ .ty = ty, .symbol = sym.index } }, sym.off);
}

inline fn relocElfUav(lower: *Lower, ty: R_LARCH, sym: bits.UavOffset) void {
    lower.reloc(.{ .elf_uav = .{ .ty = ty, .symbol = sym.index } }, sym.off);
}

inline fn relocInst(lower: *Lower, loc: Reloc.Type, inst: Mir.Inst.Index, off: i32) void {
    lower.reloc(.{ .inst = .{ .loc = loc, .inst = inst } }, off);
}

fn fail(lower: *Lower, comptime format: []const u8, args: anytype) Error {
    @branchHint(.cold);
    assert(lower.err_msg == null);
    lower.err_msg = try ErrorMsg.create(lower.allocator, lower.src_loc, format, args);
    return error.LowerFail;
}

fn hasFeature(lower: *Lower, feature: std.Target.loongarch.Feature) bool {
    const target = lower.pt.zcu.getTarget();
    const features = target.cpu.features;
    return std.Target.loongarch.featureSetHas(features, feature);
}

inline fn resolveFrame(lower: *Lower, frame: bits.FrameIndex) Mir.FrameLoc {
    return lower.mir.frame_locs.get(@intFromEnum(frame));
}

const max_result_insts = @max(
    1, // non-pseudo instructions/branch
    abi.zigcc.all_static.len + 1, // push_regs/pop_regs
    abi.c_abi.all_static.len + 1, // push_regs/pop_regs
    4, // emitImmToReg/imm_to_reg
    5, // emitRegBiasToReg/frame_addr_to_reg/func_prolugue
    6, // emitRegFrameOp/frame_addr_reg_mem/load_ra
    7, // func_epilogue
);
const max_result_relocs = @max(
    1, // jump_to_epilogue
    2, // call
    0,
);

const ResultInstIndex = std.math.IntFittingRange(0, max_result_insts);
const ResultRelocIndex = std.math.IntFittingRange(0, max_result_relocs);

/// Loads an immediate to a reg.
/// Emits up to 5 instructions.
fn emitImmToReg(lower: *Lower, imm: u64, dst: Register) !void {
    var use_lu12i = false;
    var set_hi = false;
    // Loads 31..12 bits as LU12I.W clears 11..00 bits
    if (utils.notZero((imm & 0x00000000fffff000) >> 12)) |part| {
        lower.emit(.lu12i_w(dst, @truncate(@as(i64, @bitCast(part)))));
        use_lu12i = true;
        set_hi = (part >> 11) != 0;
    }
    // Then loads 11..0 bits with ORI first if LU12I.W is not used
    // in order to clear 63..12 bits
    const lo12: u12 = @truncate(imm & 0x0000000000000fff);
    if (!use_lu12i) {
        lower.emit(.ori(dst, .zero, lo12));
        set_hi = false;
    }
    // Loads 51..32 bits
    if (utils.notZero((imm & 0x000fffff00000000) >> 32)) |part| {
        if (!(part == 0xfffff and set_hi)) {
            if (!lower.hasFeature(.@"64bit")) {
                return lower.fail("Cannot load immediate with more than 32 bits to integer register in LA32", .{});
            }
            lower.emit(.cu32i_d(dst, @truncate(@as(i64, @bitCast(part)))));
            set_hi = (part >> 11) != 0;
        }
    }
    // Loads 63..52 bits
    if (utils.notZero((imm & 0xfff0000000000000) >> 52)) |part| {
        if (!(part == 0xfff and set_hi)) {
            if (!lower.hasFeature(.@"64bit")) {
                return lower.fail("Cannot load immediate with more than 32 bits to integer register in LA32", .{});
            }
            lower.emit(.cu52i_d(dst, dst, @truncate(@as(i64, @bitCast(part)))));
        }
    }
    // Loads 11..0 at the end if LU12I.W is used, to preserve higher bits.
    if (use_lu12i and lo12 != 0x000) {
        lower.emit(.ori(dst, dst, lo12));
    }
}

/// Loads an immediate plus a reg to a reg.
/// Emits up to 6 instructions.
/// dst and src cannot be the same reg, or t0 will be clobberred.
fn emitRegBiasToReg(lower: *Lower, dst: Register, src: Register, imm: i64) !void {
    if (cast(i12, imm)) |imm12| {
        if (lower.hasFeature(.@"64bit")) {
            lower.emit(.addi_d(dst, src, imm12));
        } else {
            lower.emit(.addi_w(dst, src, imm12));
        }
    } else if (dst == src) {
        try lower.emitImmToReg(@bitCast(imm), .t0);
        if (lower.hasFeature(.@"64bit")) {
            lower.emit(.add_d(dst, .t0, src));
        } else {
            lower.emit(.add_w(dst, .t0, src));
        }
    } else {
        try lower.emitImmToReg(@bitCast(imm), dst);
        if (lower.hasFeature(.@"64bit")) {
            lower.emit(.add_d(dst, dst, src));
        } else {
            lower.emit(.add_w(dst, dst, src));
        }
    }
}

/// Emits up to 6 instructions.
/// See Mir.Inst.PseudoTag.frame_addr_reg_mem.
fn emitRegFrameOp(
    lower: *Lower,
    reg: Register,
    frame: bits.FrameAddr,
    tmp_reg: Register,
    op_ri: encoding.OpCode,
    op_rr: encoding.OpCode,
) !void {
    const frame_loc = lower.resolveFrame(frame.index);
    const offset = @as(i64, frame_loc.offset + frame.off);
    if (cast(i12, offset)) |off12| {
        lower.emit(.{
            .opcode = op_ri,
            .data = .{ .DJSk12 = .{ reg, frame_loc.base, off12 } },
        });
    } else {
        try lower.emitImmToReg(@bitCast(@as(i64, frame_loc.offset + frame.off)), tmp_reg);
        lower.emit(.{
            .opcode = op_rr,
            .data = .{ .DJK = .{ reg, frame_loc.base, tmp_reg } },
        });
    }
}

const SpillOptions = struct {
    frame: bits.FrameIndex,
    reg_class: Register.Class,
    inst: encoding.OpCode,
};

/// Emits register spill/restores with DJSk12/VdJSK12/XdJSK12 instructions.
/// rd/vd/xd is the operand register. rj + si12 is the frame address.
fn emitRegSpill(lower: *Lower, regs: Mir.RegisterList, opts: SpillOptions) void {
    const frame = lower.resolveFrame(opts.frame);
    var offset = frame.offset;
    const reg_size: i32 = @intCast(opts.reg_class.byteSize(lower.target));
    var iter = regs.iterator(.{});
    while (iter.next()) |reg_index| {
        const reg = Mir.RegisterList.getRegFromIndex(opts.reg_class, reg_index);
        lower.emit(.{
            .opcode = opts.inst,
            .data = .{ .DJSk12 = .{ reg, frame.base, @intCast(offset) } },
        });
        offset += reg_size;
    }
}
