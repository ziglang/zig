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
        const mir_inst = emit.lower.mir.instructions.get(mir_index);
        code_offset_mapping[mir_index] = @intCast(emit.code.items.len);

        const lowered = try emit.lower.lowerMir(mir_index);
        var lir_relocs = lowered.relocs;

        if (mir_inst.tag == Mir.Inst.Tag.fromPseudo(.func_epilogue)) {
            switch (emit.debug_output) {
                .dwarf => |dwarf| {
                    try dwarf.setEpilogueBegin();
                    try emit.dbgAdvancePCAndLine(emit.prev_di_loc);
                },
                .plan9, .none => {},
            }
        }

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

        switch (mir_inst.tag.unwrap()) {
            else => {},
            .pseudo => |tag| switch (tag) {
                .func_prologue => {
                    switch (emit.debug_output) {
                        .dwarf => |dwarf| try dwarf.setPrologueEnd(),
                        .plan9, .none => {},
                    }
                },
                .dbg_line_stmt_line_column => try emit.dbgAdvancePCAndLine(.{
                    .line = mir_inst.data.line_column.line,
                    .column = mir_inst.data.line_column.column,
                    .is_stmt = true,
                }),
                .dbg_line_line_column => try emit.dbgAdvancePCAndLine(.{
                    .line = mir_inst.data.line_column.line,
                    .column = mir_inst.data.line_column.column,
                    .is_stmt = false,
                }),
                else => {},
            },
        }
    }

    for (relocs.items) |reloc| {
        const target = @as(i32, @intCast(code_offset_mapping[reloc.target])) + reloc.off;
        const target_u32 = @as(u32, @intCast(target));
        const offset = @as(i32, @intCast(@as(usize, target_u32) - reloc.source));
        const offset_u32 = @as(u32, @intCast(offset));

        const inst_bytes = emit.code.items[reloc.source..][0..4];
        var inst_u32 = std.mem.readInt(u32, inst_bytes, .little);

        switch (reloc.loc) {
            .b26 => inst_u32 = inst_u32 |
                (@as(u32, @as(u16, @intCast((offset_u32 >> 2) & 0xffff))) << 10) |
                @as(u32, @as(u10, @intCast((offset_u32 >> 2) >> 16))),
        }

        std.mem.writeInt(u32, inst_bytes, inst_u32, .little);
    }
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

fn dbgAdvancePCAndLine(emit: *Emit, loc: Loc) Error!void {
    const delta_line = @as(i33, loc.line) - @as(i33, emit.prev_di_loc.line);
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    log.debug("  (advance pc={d} and line={d})", .{ delta_pc, delta_line });
    switch (emit.debug_output) {
        .dwarf => |dwarf| {
            if (loc.is_stmt != emit.prev_di_loc.is_stmt) try dwarf.negateStmt();
            if (loc.column != emit.prev_di_loc.column) try dwarf.setColumn(loc.column);
            try dwarf.advancePCAndLine(delta_line, delta_pc);
            emit.prev_di_loc = loc;
            emit.prev_di_pc = emit.code.items.len;
        },
        .plan9, .none => {},
    }
}
