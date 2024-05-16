//! This file contains the functionality for lowering RISC-V MIR to Instructions

bin_file: *link.File,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
pic: bool,
allocator: Allocator,
mir: Mir,
cc: std.builtin.CallingConvention,
err_msg: ?*ErrorMsg = null,
src_loc: Module.SrcLoc,
result_insts_len: u8 = undefined,
result_relocs_len: u8 = undefined,
result_insts: [
    @max(
        1, // non-pseudo instruction
        abi.callee_preserved_regs.len, // spill / restore regs,
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

        /// Relocs the lowered_inst_index and the next one.
        load_symbol_reloc: bits.Symbol,
    };
};

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, index: Mir.Inst.Index) Error!struct {
    insts: []const Instruction,
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
                        const tag: Encoding.Mnemonic = switch (rm.m.mod.rm.size) {
                            .byte => .lb,
                            .hword => .lh,
                            .word => .lw,
                            .dword => .ld,
                        };

                        try lower.emit(tag, &.{
                            .{ .reg = rm.r },
                            .{ .reg = frame_loc.base },
                            .{ .imm = Immediate.s(frame_loc.disp) },
                        });
                    },
                    .pseudo_store_rm => {
                        const tag: Encoding.Mnemonic = switch (rm.m.mod.rm.size) {
                            .byte => .sb,
                            .hword => .sh,
                            .word => .sw,
                            .dword => .sd,
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

                try lower.emit(.addi, &.{
                    .{ .reg = rr.rd },
                    .{ .reg = rr.rs },
                    .{ .imm = Immediate.s(0) },
                });
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

                try lower.emit(.lui, &.{
                    .{ .reg = @enumFromInt(data.register) },
                    .{ .imm = lower.reloc(.{ .load_symbol_reloc = .{
                        .atom_index = data.atom_index,
                        .sym_index = data.sym_index,
                    } }) },
                });

                // the above reloc implies this one
                try lower.emit(.addi, &.{
                    .{ .reg = @enumFromInt(data.register) },
                    .{ .reg = @enumFromInt(data.register) },
                    .{ .imm = Immediate.s(0) },
                });
            },

            .pseudo_lea_rm => {
                const rm = inst.data.rm;
                const frame = rm.m.toFrameLoc(lower.mir);

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

                switch (op) {
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
                        try lower.emit(.sltu, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                    },
                    .gte => {
                        try lower.emit(.sltu, &.{
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
                        try lower.emit(.slt, &.{
                            .{ .reg = rd },
                            .{ .reg = rs1 },
                            .{ .reg = rs2 },
                        });
                    },
                    .lte => {
                        try lower.emit(.slt, &.{
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
                }
            },

            .pseudo_not => {
                const rr = inst.data.rr;

                try lower.emit(.xori, &.{
                    .{ .reg = rr.rd },
                    .{ .reg = rr.rs },
                    .{ .imm = Immediate.s(1) },
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

        if (spilling) {
            try lower.emit(.sd, &.{
                .{ .reg = frame.base },
                .{ .reg = abi.callee_preserved_regs[i] },
                .{ .imm = Immediate.s(frame.disp + reg_i) },
            });
        } else {
            try lower.emit(.ld, &.{
                .{ .reg = abi.callee_preserved_regs[i] },
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
const ErrorMsg = Module.ErrorMsg;
const Mir = @import("Mir.zig");
const Module = @import("../../Module.zig");
const Instruction = encoder.Instruction;
const Immediate = bits.Immediate;
