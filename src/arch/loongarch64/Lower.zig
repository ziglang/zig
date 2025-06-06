//! This file contains the functionality for lowering LoongArch MIR to Instructions

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
const Lir = @import("Lir.zig");

const Lower = @This();

bin_file: *link.File,
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
};

/// Lowered relocation.
/// The fields in instructions to be relocated must be lowered to zero.
pub const Reloc = struct {
    lir_index: u8,
    loc: Type,
    target: Target,
    off: i32,

    pub const Target = union(enum) {
        inst: Mir.Inst.Index,
    };

    pub const Type = enum {
        /// Immediate slot of Sd10k16ps2, right shift 2, relative to PC
        b26,
        /// Immediate slot of JDSk16ps2ps2, right shift 2, relative to PC
        k16,
    };
};

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, index: Mir.Inst.Index) Error!struct {
    insts: []const Lir.Inst,
    relocs: []const Reloc,
} {
    // const pt = lower.pt;
    // const zcu = pt.zcu;

    lower.result_insts = undefined;
    lower.result_relocs = undefined;
    errdefer lower.result_insts = undefined;
    errdefer lower.result_relocs = undefined;
    lower.result_insts_len = 0;
    lower.result_relocs_len = 0;
    defer lower.result_insts_len = undefined;
    defer lower.result_relocs_len = undefined;

    const inst = lower.mir.instructions.get(index);
    log.debug("lowering: {}", .{inst});

    switch (inst.tag.unwrap()) {
        .inst => |opcode| lower.emitLir(.{ .opcode = opcode, .data = inst.data.op }),
        .pseudo => |tag| {
            switch (tag) {
                // TODO: impl func prolugue
                .func_prologue => {},
                .func_epilogue => {
                    lower.emit(.jirl(.ra, .ra, 0));
                },
                .jump_to_epilogue => {
                    if (index + 1 < lower.mir.instructions.len and
                        lower.mir.instructions.get(index + 1).tag == Mir.Inst.Tag.fromPseudo(.func_epilogue))
                    {
                        log.debug("omit jump_to_epilogue", .{});
                    } else {
                        lower.emit(.b(0, 0));
                        lower.reloc(.b26, .{ .inst = @intCast(lower.mir.instructions.len - 1) }, 0);
                    }
                },
                .dbg_line_line_column, .dbg_line_stmt_line_column => {},
                .branch => {
                    switch (inst.data.br.cond) {
                        .none => {
                            lower.emit(.b(0, 0));
                            lower.reloc(.b26, .{ .inst = inst.data.br.inst }, 0);
                        },
                        .eq => |regs| {
                            lower.emit(.beq(regs[0], regs[1], 0));
                            lower.reloc(.k16, .{ .inst = inst.data.br.inst }, 0);
                        },
                        .ne => |regs| {
                            lower.emit(.bne(regs[0], regs[1], 0));
                            lower.reloc(.k16, .{ .inst = inst.data.br.inst }, 0);
                        },
                        .le => |regs| {
                            lower.emit(.ble(regs[0], regs[1], 0));
                            lower.reloc(.k16, .{ .inst = inst.data.br.inst }, 0);
                        },
                        .gt => |regs| {
                            lower.emit(.bgt(regs[0], regs[1], 0));
                            lower.reloc(.k16, .{ .inst = inst.data.br.inst }, 0);
                        },
                        .leu => |regs| {
                            lower.emit(.bleu(regs[0], regs[1], 0));
                            lower.reloc(.k16, .{ .inst = inst.data.br.inst }, 0);
                        },
                        .gtu => |regs| {
                            lower.emit(.bgtu(regs[0], regs[1], 0));
                            lower.reloc(.k16, .{ .inst = inst.data.br.inst }, 0);
                        },
                    }
                },
                else => unreachable,
            }
        },
    }

    return .{
        .insts = lower.result_insts[0..lower.result_insts_len],
        .relocs = lower.result_relocs[0..lower.result_relocs_len],
    };
}

fn emit(lower: *Lower, inst: encoding.Inst) void {
    lower.emitLir(.fromInst(inst));
}

fn emitLir(lower: *Lower, inst: Lir.Inst) void {
    log.debug("  | {}", .{inst});
    lower.result_insts[lower.result_insts_len] = inst;
    lower.result_insts_len += 1;
}

fn reloc(lower: *Lower, loc: Reloc.Type, target: Reloc.Target, off: i32) void {
    lower.result_relocs[lower.result_relocs_len] = .{
        .lir_index = lower.result_insts_len - 1,
        .loc = loc,
        .target = target,
        .off = off,
    };
    lower.result_relocs_len += 1;
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

const max_result_insts = @max(
    1, // non-pseudo instructions
    abi.zigcc.all_static.len + 1, // push_regs/pop_regs
    abi.c_abi.all_static.len + 1, // push_regs/pop_regs
);
const max_result_relocs = @max(
    1, // jump to epilogue
    0,
);

const ResultInstIndex = std.math.IntFittingRange(0, max_result_insts);
const ResultRelocIndex = std.math.IntFittingRange(0, max_result_relocs);
