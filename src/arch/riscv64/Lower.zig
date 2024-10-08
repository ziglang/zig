//! This file contains the functionality for lowering RISC-V MIR to Instructions

pt: Zcu.PerThread,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
pic: bool,
allocator: Allocator,
mir: Mir,
cc: std.builtin.CallingConvention,
err_msg: ?*ErrorMsg = null,
src_loc: Zcu.LazySrcLoc,
result_insts_len: u8 = undefined,
result_relocs_len: u8 = undefined,
result_insts: [
    @max(
        1, // non-pseudo instruction
        abi.Registers.all_preserved.len, // spill / restore regs,
    )
]Instruction = undefined,
result_relocs: [1]Reloc = undefined,

pub const Error = error{
    OutOfMemory,
    LowerFail,
    InvalidInstruction,
};

pub const Reloc = struct {
    lowered_inst_index: u8,
    target: Target,

    const Target = union(enum) {
        inst: Mir.Inst.Index,

        /// Relocs the lowered_inst_index and the next instruction.
        load_symbol_reloc: bits.Symbol,
        /// Relocs the lowered_inst_index and the next two instructions.
        load_tlv_reloc: bits.Symbol,
        /// Relocs the lowered_inst_index and the next instruction.
        call_extern_fn_reloc: bits.Symbol,
    };
};

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, index: Mir.Inst.Index, options: struct {
    allow_frame_locs: bool,
}) Error!struct {
    insts: []const Instruction,
    relocs: []const Reloc,
} {
    const pt = lower.pt;
    const zcu = pt.zcu;

    lower.result_insts = undefined;
    lower.result_relocs = undefined;
    errdefer lower.result_insts = undefined;
    errdefer lower.result_relocs = undefined;
    lower.result_insts_len = 0;
    lower.result_relocs_len = 0;
    defer lower.result_insts_len = undefined;
    defer lower.result_relocs_len = undefined;

    const inst = lower.mir.instructions.get(index);
    log.debug("lowerMir {}", .{inst});
    switch (inst.tag) {
        else => try lower.generic(inst),
        .pseudo_dbg_line_column,
        .pseudo_dbg_epilogue_begin,
        .pseudo_dbg_prologue_end,
        .pseudo_dead,
        => {},

        .pseudo_load_rm, .pseudo_store_rm => {
            const rm = inst.data.rm;

            const frame_loc: Mir.FrameLoc = if (options.allow_frame_locs)
                rm.m.toFrameLoc(lower.mir)
            else
                .{ .base = .s0, .disp = 0 };

            switch (inst.tag) {
                .pseudo_load_rm => {
                    const dest_reg = rm.r;
                    const dest_reg_class = dest_reg.class();

                    const src_size = rm.m.mod.size;
                    const unsigned = rm.m.mod.unsigned;

                    const mnem: Mnemonic = switch (dest_reg_class) {
                        .int => switch (src_size) {
                            .byte => if (unsigned) .lbu else .lb,
                            .hword => if (unsigned) .lhu else .lh,
                            .word => if (unsigned) .lwu else .lw,
                            .dword => .ld,
                        },
                        .float => switch (src_size) {
                            .byte => unreachable, // Zig does not support 8-bit floats
                            .hword => return lower.fail("TODO: lowerMir pseudo_load_rm support 16-bit floats", .{}),
                            .word => .flw,
                            .dword => .fld,
                        },
                        .vector => switch (src_size) {
                            .byte => .vle8v,
                            .hword => .vle32v,
                            .word => .vle32v,
                            .dword => .vle64v,
                        },
                    };

                    switch (dest_reg_class) {
                        .int, .float => {
                            try lower.emit(mnem, &.{
                                .{ .reg = rm.r },
                                .{ .reg = frame_loc.base },
                                .{ .imm = Immediate.s(frame_loc.disp) },
                            });
                        },
                        .vector => {
                            assert(frame_loc.disp == 0);
                            try lower.emit(mnem, &.{
                                .{ .reg = rm.r },
                                .{ .reg = frame_loc.base },
                                .{ .reg = .zero },
                            });
                        },
                    }
                },
                .pseudo_store_rm => {
                    const src_reg = rm.r;
                    const src_reg_class = src_reg.class();

                    const dest_size = rm.m.mod.size;

                    const mnem: Mnemonic = switch (src_reg_class) {
                        .int => switch (dest_size) {
                            .byte => .sb,
                            .hword => .sh,
                            .word => .sw,
                            .dword => .sd,
                        },
                        .float => switch (dest_size) {
                            .byte => unreachable, // Zig does not support 8-bit floats
                            .hword => return lower.fail("TODO: lowerMir pseudo_store_rm support 16-bit floats", .{}),
                            .word => .fsw,
                            .dword => .fsd,
                        },
                        .vector => switch (dest_size) {
                            .byte => .vse8v,
                            .hword => .vse16v,
                            .word => .vse32v,
                            .dword => .vse64v,
                        },
                    };

                    switch (src_reg_class) {
                        .int, .float => {
                            try lower.emit(mnem, &.{
                                .{ .reg = frame_loc.base },
                                .{ .reg = rm.r },
                                .{ .imm = Immediate.s(frame_loc.disp) },
                            });
                        },
                        .vector => {
                            assert(frame_loc.disp == 0);
                            try lower.emit(mnem, &.{
                                .{ .reg = rm.r },
                                .{ .reg = frame_loc.base },
                                .{ .reg = .zero },
                            });
                        },
                    }
                },
                else => unreachable,
            }
        },

        .pseudo_mv => {
            const rr = inst.data.rr;

            const dst_class = rr.rd.class();
            const src_class = rr.rs.class();

            switch (src_class) {
                .float => switch (dst_class) {
                    .float => {
                        try lower.emit(if (lower.hasFeature(.d)) .fsgnjnd else .fsgnjns, &.{
                            .{ .reg = rr.rd },
                            .{ .reg = rr.rs },
                            .{ .reg = rr.rs },
                        });
                    },
                    .int, .vector => return lower.fail("TODO: lowerMir pseudo_mv float -> {s}", .{@tagName(dst_class)}),
                },
                .int => switch (dst_class) {
                    .int => {
                        try lower.emit(.addi, &.{
                            .{ .reg = rr.rd },
                            .{ .reg = rr.rs },
                            .{ .imm = Immediate.s(0) },
                        });
                    },
                    .vector => {
                        try lower.emit(.vmvvx, &.{
                            .{ .reg = rr.rd },
                            .{ .reg = rr.rs },
                            .{ .reg = .x0 },
                        });
                    },
                    .float => return lower.fail("TODO: lowerMir pseudo_mv int -> {s}", .{@tagName(dst_class)}),
                },
                .vector => switch (dst_class) {
                    .int => {
                        try lower.emit(.vadcvv, &.{
                            .{ .reg = rr.rd },
                            .{ .reg = .zero },
                            .{ .reg = rr.rs },
                        });
                    },
                    .float, .vector => return lower.fail("TODO: lowerMir pseudo_mv vector -> {s}", .{@tagName(dst_class)}),
                },
            }
        },

        .pseudo_j => {
            const j_type = inst.data.j_type;
            try lower.emit(.jal, &.{
                .{ .reg = j_type.rd },
                .{ .imm = lower.reloc(.{ .inst = j_type.inst }) },
            });
        },

        .pseudo_spill_regs => try lower.pushPopRegList(true, inst.data.reg_list),
        .pseudo_restore_regs => try lower.pushPopRegList(false, inst.data.reg_list),

        .pseudo_load_symbol => {
            const payload = inst.data.reloc;
            const dst_reg = payload.register;
            assert(dst_reg.class() == .int);

            try lower.emit(.lui, &.{
                .{ .reg = dst_reg },
                .{ .imm = lower.reloc(.{
                    .load_symbol_reloc = .{
                        .atom_index = payload.atom_index,
                        .sym_index = payload.sym_index,
                    },
                }) },
            });

            // the reloc above implies this one
            try lower.emit(.addi, &.{
                .{ .reg = dst_reg },
                .{ .reg = dst_reg },
                .{ .imm = Immediate.s(0) },
            });
        },

        .pseudo_load_tlv => {
            const payload = inst.data.reloc;
            const dst_reg = payload.register;
            assert(dst_reg.class() == .int);

            try lower.emit(.lui, &.{
                .{ .reg = dst_reg },
                .{ .imm = lower.reloc(.{
                    .load_tlv_reloc = .{
                        .atom_index = payload.atom_index,
                        .sym_index = payload.sym_index,
                    },
                }) },
            });

            try lower.emit(.add, &.{
                .{ .reg = dst_reg },
                .{ .reg = dst_reg },
                .{ .reg = .tp },
            });

            try lower.emit(.addi, &.{
                .{ .reg = dst_reg },
                .{ .reg = dst_reg },
                .{ .imm = Immediate.s(0) },
            });
        },

        .pseudo_lea_rm => {
            const rm = inst.data.rm;
            assert(rm.r.class() == .int);

            const frame: Mir.FrameLoc = if (options.allow_frame_locs)
                rm.m.toFrameLoc(lower.mir)
            else
                .{ .base = .s0, .disp = 0 };

            try lower.emit(.addi, &.{
                .{ .reg = rm.r },
                .{ .reg = frame.base },
                .{ .imm = Immediate.s(frame.disp) },
            });
        },

        .pseudo_compare => {
            const compare = inst.data.compare;
            const op = compare.op;

            const rd = compare.rd;
            const rs1 = compare.rs1;
            const rs2 = compare.rs2;

            const class = rs1.class();
            const ty = compare.ty;
            const size = std.math.ceilPowerOfTwo(u64, ty.bitSize(zcu)) catch {
                return lower.fail("pseudo_compare size {}", .{ty.bitSize(zcu)});
            };

            const is_unsigned = ty.isUnsignedInt(zcu);
            const less_than: Mnemonic = if (is_unsigned) .sltu else .slt;

            switch (class) {
                .int => switch (op) {
                    .eq => {
                        try lower.emit(.xor, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });

                        try lower.emit(.sltiu, &.{
                            .{ .reg = rd },
                            .{ .reg = rd },
                            .{ .imm = Immediate.s(1) },
                        });
                    },
                    .neq => {
                        try lower.emit(.xor, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });

                        try lower.emit(.sltu, &.{
                            .{ .reg = rd },
                            .{ .reg = .zero },
                            .{ .reg = rd },
                        });
                    },
                    .gt => {
                        try lower.emit(less_than, &.{
                            .{ .reg = rd },
                            .{ .reg = rs2 },
                            .{ .reg = rs1 },
                        });
                    },
                    .gte => {
                        try lower.emit(less_than, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                        try lower.emit(.xori, &.{
                            .{ .reg = rd },
                            .{ .reg = rd },
                            .{ .imm = Immediate.s(1) },
                        });
                    },
                    .lt => {
                        try lower.emit(less_than, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                    },
                    .lte => {
                        try lower.emit(less_than, &.{
                            .{ .reg = rd },
                            .{ .reg = rs2 },
                            .{ .reg = rs1 },
                        });

                        try lower.emit(.xori, &.{
                            .{ .reg = rd },
                            .{ .reg = rd },
                            .{ .imm = Immediate.s(1) },
                        });
                    },
                },
                .float => switch (op) {
                    // eq
                    .eq => {
                        try lower.emit(if (size == 64) .feqd else .feqs, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                    },
                    // !(eq)
                    .neq => {
                        try lower.emit(if (size == 64) .feqd else .feqs, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                        try lower.emit(.xori, &.{
                            .{ .reg = rd },
                            .{ .reg = rd },
                            .{ .imm = Immediate.s(1) },
                        });
                    },
                    .lt => {
                        try lower.emit(if (size == 64) .fltd else .flts, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                    },
                    .lte => {
                        try lower.emit(if (size == 64) .fled else .fles, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                    },
                    .gt => {
                        try lower.emit(if (size == 64) .fltd else .flts, &.{
                            .{ .reg = rd },
                            .{ .reg = rs2 },
                            .{ .reg = rs1 },
                        });
                    },
                    .gte => {
                        try lower.emit(if (size == 64) .fled else .fles, &.{
                            .{ .reg = rd },
                            .{ .reg = rs2 },
                            .{ .reg = rs1 },
                        });
                    },
                },
                .vector => return lower.fail("TODO: lowerMir pseudo_cmp vector", .{}),
            }
        },

        .pseudo_not => {
            const rr = inst.data.rr;
            assert(rr.rs.class() == .int and rr.rd.class() == .int);

            // mask out any other bits that aren't the boolean
            try lower.emit(.andi, &.{
                .{ .reg = rr.rs },
                .{ .reg = rr.rs },
                .{ .imm = Immediate.s(1) },
            });

            try lower.emit(.sltiu, &.{
                .{ .reg = rr.rd },
                .{ .reg = rr.rs },
                .{ .imm = Immediate.s(1) },
            });
        },

        .pseudo_extern_fn_reloc => {
            const inst_reloc = inst.data.reloc;
            const link_reg = inst_reloc.register;

            try lower.emit(.auipc, &.{
                .{ .reg = link_reg },
                .{ .imm = lower.reloc(
                    .{ .call_extern_fn_reloc = .{
                        .atom_index = inst_reloc.atom_index,
                        .sym_index = inst_reloc.sym_index,
                    } },
                ) },
            });

            try lower.emit(.jalr, &.{
                .{ .reg = link_reg },
                .{ .reg = link_reg },
                .{ .imm = Immediate.s(0) },
            });
        },
    }

    return .{
        .insts = lower.result_insts[0..lower.result_insts_len],
        .relocs = lower.result_relocs[0..lower.result_relocs_len],
    };
}

fn generic(lower: *Lower, inst: Mir.Inst) Error!void {
    const mnemonic = inst.tag;
    try lower.emit(mnemonic, switch (inst.data) {
        .none => &.{},
        .u_type => |u| &.{
            .{ .reg = u.rd },
            .{ .imm = u.imm20 },
        },
        .i_type => |i| &.{
            .{ .reg = i.rd },
            .{ .reg = i.rs1 },
            .{ .imm = i.imm12 },
        },
        .rr => |rr| &.{
            .{ .reg = rr.rd },
            .{ .reg = rr.rs },
        },
        .b_type => |b| &.{
            .{ .reg = b.rs1 },
            .{ .reg = b.rs2 },
            .{ .imm = lower.reloc(.{ .inst = b.inst }) },
        },
        .r_type => |r| &.{
            .{ .reg = r.rd },
            .{ .reg = r.rs1 },
            .{ .reg = r.rs2 },
        },
        .csr => |csr| &.{
            .{ .csr = csr.csr },
            .{ .reg = csr.rs1 },
            .{ .reg = csr.rd },
        },
        .amo => |amo| &.{
            .{ .reg = amo.rd },
            .{ .reg = amo.rs1 },
            .{ .reg = amo.rs2 },
            .{ .barrier = amo.rl },
            .{ .barrier = amo.aq },
        },
        .fence => |fence| &.{
            .{ .barrier = fence.succ },
            .{ .barrier = fence.pred },
        },
        else => return lower.fail("TODO: generic lower {s}", .{@tagName(inst.data)}),
    });
}

fn emit(lower: *Lower, mnemonic: Mnemonic, ops: []const Instruction.Operand) !void {
    const lir = encoding.Lir.fromMnem(mnemonic);
    const inst = Instruction.fromLir(lir, ops);

    lower.result_insts[lower.result_insts_len] = inst;
    lower.result_insts_len += 1;
}

fn reloc(lower: *Lower, target: Reloc.Target) Immediate {
    lower.result_relocs[lower.result_relocs_len] = .{
        .lowered_inst_index = lower.result_insts_len,
        .target = target,
    };
    lower.result_relocs_len += 1;
    return Immediate.s(0);
}

fn pushPopRegList(lower: *Lower, comptime spilling: bool, reg_list: Mir.RegisterList) !void {
    var it = reg_list.iterator(.{ .direction = .forward });

    var reg_i: u31 = 0;
    while (it.next()) |i| {
        const frame = lower.mir.frame_locs.get(@intFromEnum(bits.FrameIndex.spill_frame));
        const reg = abi.Registers.all_preserved[i];

        const reg_class = reg.class();
        const load_inst: Mnemonic, const store_inst: Mnemonic = switch (reg_class) {
            .int => .{ .ld, .sd },
            .float => .{ .fld, .fsd },
            .vector => unreachable,
        };

        if (spilling) {
            try lower.emit(store_inst, &.{
                .{ .reg = frame.base },
                .{ .reg = abi.Registers.all_preserved[i] },
                .{ .imm = Immediate.s(frame.disp + reg_i) },
            });
        } else {
            try lower.emit(load_inst, &.{
                .{ .reg = abi.Registers.all_preserved[i] },
                .{ .reg = frame.base },
                .{ .imm = Immediate.s(frame.disp + reg_i) },
            });
        }

        reg_i += 8;
    }
}

pub fn fail(lower: *Lower, comptime format: []const u8, args: anytype) Error {
    @branchHint(.cold);
    assert(lower.err_msg == null);
    lower.err_msg = try ErrorMsg.create(lower.allocator, lower.src_loc, format, args);
    return error.LowerFail;
}

fn hasFeature(lower: *Lower, feature: std.Target.riscv.Feature) bool {
    const target = lower.pt.zcu.getTarget();
    const features = target.cpu.features;
    return std.Target.riscv.featureSetHas(features, feature);
}

const Lower = @This();
const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.lower);

const Allocator = std.mem.Allocator;
const ErrorMsg = Zcu.ErrorMsg;

const link = @import("../../link.zig");
const Air = @import("../../Air.zig");
const Zcu = @import("../../Zcu.zig");

const Mir = @import("Mir.zig");
const abi = @import("abi.zig");
const bits = @import("bits.zig");
const encoding = @import("encoding.zig");

const Mnemonic = @import("mnem.zig").Mnemonic;
const Immediate = bits.Immediate;
const Instruction = encoding.Instruction;
