//! This file contains the functionality for emitting LoongArch MIR as machine code

const bits = @import("bits.zig");
const link = @import("../../link.zig");
const log = std.log.scoped(.emit);
const std = @import("std");

const Air = @import("../../Air.zig");
const Lower = @import("Lower.zig");
const Lir = @import("Lir.zig");
const Mir = @import("Mir.zig");

const Emit = @This();

air: Air,
lower: Lower,
atom_index: u32,
debug_output: link.File.DebugInfoOutput,
code: *std.ArrayListUnmanaged(u8),

prev_di_loc: Loc,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

pub const Error = Lower.Error || error{
    EmitFail,
} || link.File.UpdateDebugInfoError;

pub fn emitMir(emit: *Emit) Error!void {
    const gpa = emit.lower.bin_file.comp.gpa;

    var relocs: std.ArrayListUnmanaged(Reloc) = .empty;
    defer relocs.deinit(emit.lower.allocator);

    for (0..emit.lower.mir.instructions.len) |mir_i| {
        const mir_index: Mir.Inst.Index = @intCast(mir_i);

        const lowered = try emit.lower.lowerMir(mir_index);
        var lir_relocs = lowered.relocs;

        for (lowered.insts, 0..) |lir_inst, lir_index| {
            const start_offset: u32 = @intCast(emit.code.items.len);
            try emit.code.writer(gpa).writeInt(u32, lir_inst.encode(), .little);

            while (lir_relocs.len > 0 and
                lir_relocs[0].lir_index == lir_index) : ({
                lir_relocs = lir_relocs[1..];
            }) switch (lir_relocs[0].target) {
                .inst => |target| {
                    try relocs.append(emit.lower.allocator, .{
                        .source = start_offset,
                        .loc = lir_relocs[0].loc,
                        .target = target,
                        .off = lir_relocs[0].off,
                    });
                },
            };
        }
        std.debug.assert(lir_relocs.len == 0);

        if (lowered.insts.len == 0) {
            const mir_inst = emit.lower.mir.instructions.get(mir_index);
            switch (mir_inst.tag.unwrap()) {
                else => unreachable,
                .pseudo => |tag| switch (tag) {
                    .func_prologue => {}, // TODO: func_prologue current does not lower to any instructions
                    .jump_to_epilogue => {}, // jump_to_epilogue may be optimized out
                    else => unreachable,
                },
            }
        }
    }
    // TODO: emit relocs
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) Error {
    return switch (emit.lower.fail(format, args)) {
        error.LowerFail => error.EmitFail,
        else => |e| e,
    };
}

const Reloc = struct {
    source: usize,
    loc: Lower.Reloc.Type,
    target: Mir.Inst.Index,
    off: i32,
};

const Loc = struct {
    line: u32,
    column: u32,
    is_stmt: bool,
};
