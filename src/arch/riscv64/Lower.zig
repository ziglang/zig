//! This file contains the functionality for lowering RISC-V MIR to Instructions

bin_file: *link.File,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
pic: bool,
allocator: Allocator,
mir: Mir,
cc: std.builtin.CallingConvention,
err_msg: ?*ErrorMsg = null,
src_loc: Zcu.SrcLoc,
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
        /// Relocs the lowered_inst_index and the next instruction.
        call_extern_fn_reloc: bits.Symbol,
    };
};

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, index: Mir.Inst.Index) Error!struct {
    insts: []const Instruction,
    relocs: []const Reloc,
} {
    const zcu = lower.bin_file.comp.module.?;

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
        .pseudo => switch (inst.ops) {
            .pseudo_dbg_line_column,
            .pseudo_dbg_epilogue_begin,
            .pseudo_dbg_prologue_end,
            .pseudo_dead,
            => {},

            .pseudo_load_rm, .pseudo_store_rm => {
                const rm = inst.data.rm;

                const frame_loc = rm.m.toFrameLoc(lower.mir);

                switch (inst.ops) {
                    .pseudo_load_rm => {
                        const dest_reg = rm.r;
                        const dest_reg_class = dest_reg.class();
                        const float = dest_reg_class == .float;

                        const src_size = rm.m.mod.size;
                        const unsigned = rm.m.mod.unsigned;

                        const tag: Encoding.Mnemonic = if (!float)
                            switch (src_size) {
                                .byte => if (unsigned) .lbu else .lb,
                                .hword => if (unsigned) .lhu else .lh,
                                .word => if (unsigned) .lwu else .lw,
                                .dword => .ld,
                            }
                        else switch (src_size) {
                            .byte => unreachable, // Zig does not support 8-bit floats
                            .hword => return lower.fail("TODO: lowerMir pseudo_load_rm support 16-bit floats", .{}),
                            .word => .flw,
                            .dword => .fld,
                        };

                        try lower.emit(tag, &.{
                            .{ .reg = rm.r },
                            .{ .reg = frame_loc.base },
                            .{ .imm = Immediate.s(frame_loc.disp) },
                        });
                    },
                    .pseudo_store_rm => {
                        const src_reg = rm.r;
                        const src_reg_class = src_reg.class();
                        const float = src_reg_class == .float;

                        // TODO: do we actually need this? are all stores not usize?
                        const dest_size = rm.m.mod.size;

                        const tag: Encoding.Mnemonic = if (!float)
                            switch (dest_size) {
                                .byte => .sb,
                                .hword => .sh,
                                .word => .sw,
                                .dword => .sd,
                            }
                        else switch (dest_size) {
                            .byte => unreachable, // Zig does not support 8-bit floats
                            .hword => return lower.fail("TODO: lowerMir pseudo_load_rm support 16-bit floats", .{}),
                            .word => .fsw,
                            .dword => .fsd,
                        };

                        try lower.emit(tag, &.{
                            .{ .reg = frame_loc.base },
                            .{ .reg = rm.r },
                            .{ .imm = Immediate.s(frame_loc.disp) },
                        });
                    },
                    else => unreachable,
                }
            },

            .pseudo_mv => {
                const rr = inst.data.rr;

                const dst_class = rr.rd.class();
                const src_class = rr.rs.class();

                assert(dst_class == src_class);

                switch (dst_class) {
                    .float => {
                        try lower.emit(if (lower.hasFeature(.d)) .fsgnjnd else .fsgnjns, &.{
                            .{ .reg = rr.rd },
                            .{ .reg = rr.rs },
                            .{ .reg = rr.rs },
                        });
                    },
                    .int => {
                        try lower.emit(.addi, &.{
                            .{ .reg = rr.rd },
                            .{ .reg = rr.rs },
                            .{ .imm = Immediate.s(0) },
                        });
                    },
                }
            },

            .pseudo_ret => {
                try lower.emit(.jalr, &.{
                    .{ .reg = .zero },
                    .{ .reg = .ra },
                    .{ .imm = Immediate.s(0) },
                });
            },

            .pseudo_j => {
                try lower.emit(.jal, &.{
                    .{ .reg = .zero },
                    .{ .imm = lower.reloc(.{ .inst = inst.data.inst }) },
                });
            },

            .pseudo_spill_regs => try lower.pushPopRegList(true, inst.data.reg_list),
            .pseudo_restore_regs => try lower.pushPopRegList(false, inst.data.reg_list),

            .pseudo_load_symbol => {
                const payload = inst.data.payload;
                const data = lower.mir.extraData(Mir.LoadSymbolPayload, payload).data;
                const dst_reg: bits.Register = @enumFromInt(data.register);
                assert(dst_reg.class() == .int);

                try lower.emit(.lui, &.{
                    .{ .reg = dst_reg },
                    .{ .imm = lower.reloc(.{
                        .load_symbol_reloc = .{
                            .atom_index = data.atom_index,
                            .sym_index = data.sym_index,
                        },
                    }) },
                });

                // the above reloc implies this one
                try lower.emit(.addi, &.{
                    .{ .reg = dst_reg },
                    .{ .reg = dst_reg },
                    .{ .imm = Immediate.s(0) },
                });
            },

            .pseudo_lea_rm => {
                const rm = inst.data.rm;
                assert(rm.r.class() == .int);

                const frame = rm.m.toFrameLoc(lower.mir);

                try lower.emit(.addi, &.{
                    .{ .reg = rm.r },
                    .{ .reg = frame.base },
                    .{ .imm = Immediate.s(frame.disp) },
                });
            },

            .pseudo_fabs => {
                const fabs = inst.data.fabs;
                assert(fabs.rs.class() == .float and fabs.rd.class() == .float);

                const mnem: Encoding.Mnemonic = switch (fabs.bits) {
                    16 => return lower.fail("TODO: airAbs Float 16", .{}),
                    32 => .fsgnjxs,
                    64 => .fsgnjxd,
                    80 => return lower.fail("TODO: airAbs Float 80", .{}),
                    128 => return lower.fail("TODO: airAbs Float 128", .{}),
                    else => unreachable,
                };

                try lower.emit(mnem, &.{
                    .{ .reg = fabs.rs },
                    .{ .reg = fabs.rd },
                    .{ .reg = fabs.rd },
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

                const less_than: Encoding.Mnemonic = if (is_unsigned) .sltu else .slt;

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
                                .{ .reg = rs1 },
                                .{ .reg = rs2 },
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
                }
            },

            .pseudo_not => {
                const rr = inst.data.rr;
                assert(rr.rs.class() == .int and rr.rd.class() == .int);

                try lower.emit(.xori, &.{
                    .{ .reg = rr.rd },
                    .{ .reg = rr.rs },
                    .{ .imm = Immediate.s(1) },
                });
            },

            .pseudo_extern_fn_reloc => {
                const inst_reloc = inst.data.reloc;

                try lower.emit(.auipc, &.{
                    .{ .reg = .ra },
                    .{ .imm = lower.reloc(
                        .{ .call_extern_fn_reloc = .{
                            .atom_index = inst_reloc.atom_index,
                            .sym_index = inst_reloc.sym_index,
                        } },
                    ) },
                });

                try lower.emit(.jalr, &.{
                    .{ .reg = .ra },
                    .{ .reg = .ra },
                    .{ .imm = Immediate.s(0) },
                });
            },

            else => return lower.fail("TODO lower: psuedo {s}", .{@tagName(inst.ops)}),
        },
    }

    return .{
        .insts = lower.result_insts[0..lower.result_insts_len],
        .relocs = lower.result_relocs[0..lower.result_relocs_len],
    };
}

fn generic(lower: *Lower, inst: Mir.Inst) Error!void {
    const mnemonic = std.meta.stringToEnum(Encoding.Mnemonic, @tagName(inst.tag)) orelse {
        return lower.fail("generic inst name '{s}' with op {s} doesn't match with a mnemonic", .{
            @tagName(inst.tag),
            @tagName(inst.ops),
        });
    };
    try lower.emit(mnemonic, switch (inst.ops) {
        .none => &.{},
        .ri => &.{
            .{ .reg = inst.data.u_type.rd },
            .{ .imm = inst.data.u_type.imm20 },
        },
        .rr => &.{
            .{ .reg = inst.data.rr.rd },
            .{ .reg = inst.data.rr.rs },
        },
        .rri => &.{
            .{ .reg = inst.data.i_type.rd },
            .{ .reg = inst.data.i_type.rs1 },
            .{ .imm = inst.data.i_type.imm12 },
        },
        .rr_inst => &.{
            .{ .reg = inst.data.b_type.rs1 },
            .{ .reg = inst.data.b_type.rs2 },
            .{ .imm = lower.reloc(.{ .inst = inst.data.b_type.inst }) },
        },
        .rrr => &.{
            .{ .reg = inst.data.r_type.rd },
            .{ .reg = inst.data.r_type.rs1 },
            .{ .reg = inst.data.r_type.rs2 },
        },
        else => return lower.fail("TODO: generic lower ops {s}", .{@tagName(inst.ops)}),
    });
}

fn emit(lower: *Lower, mnemonic: Encoding.Mnemonic, ops: []const Instruction.Operand) !void {
    lower.result_insts[lower.result_insts_len] =
        try Instruction.new(mnemonic, ops);
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
        const is_float_reg = reg_class == .float;

        if (spilling) {
            try lower.emit(if (is_float_reg) .fsd else .sd, &.{
                .{ .reg = frame.base },
                .{ .reg = abi.Registers.all_preserved[i] },
                .{ .imm = Immediate.s(frame.disp + reg_i) },
            });
        } else {
            try lower.emit(if (is_float_reg) .fld else .ld, &.{
                .{ .reg = abi.Registers.all_preserved[i] },
                .{ .reg = frame.base },
                .{ .imm = Immediate.s(frame.disp + reg_i) },
            });
        }

        reg_i += 8;
    }
}

pub fn fail(lower: *Lower, comptime format: []const u8, args: anytype) Error {
    @setCold(true);
    assert(lower.err_msg == null);
    lower.err_msg = try ErrorMsg.create(lower.allocator, lower.src_loc, format, args);
    return error.LowerFail;
}

fn hasFeature(lower: *Lower, feature: std.Target.riscv.Feature) bool {
    const target = lower.bin_file.comp.module.?.getTarget();
    const features = target.cpu.features;
    return std.Target.riscv.featureSetHas(features, feature);
}

const Lower = @This();

const abi = @import("abi.zig");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const encoder = @import("encoder.zig");
const link = @import("../../link.zig");
const Encoding = @import("Encoding.zig");
const std = @import("std");
const log = std.log.scoped(.lower);

const Air = @import("../../Air.zig");
const Allocator = std.mem.Allocator;
const ErrorMsg = Zcu.ErrorMsg;
const Mir = @import("Mir.zig");
const Zcu = @import("../../Zcu.zig");
const Instruction = encoder.Instruction;
const Immediate = bits.Immediate;
