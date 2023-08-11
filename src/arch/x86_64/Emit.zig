//! This file contains the functionality for emitting x86_64 MIR as machine code

lower: Lower,
bin_file: *link.File,
debug_output: DebugInfoOutput,
code: *std.ArrayList(u8),

prev_di_line: u32,
prev_di_column: u32,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

code_offset_mapping: std.AutoHashMapUnmanaged(Mir.Inst.Index, usize) = .{},
relocs: std.ArrayListUnmanaged(Reloc) = .{},

pub const Error = Lower.Error || error{
    EmitFail,
};

pub fn emitMir(emit: *Emit) Error!void {
    for (0..emit.lower.mir.instructions.len) |mir_i| {
        const mir_index = @as(Mir.Inst.Index, @intCast(mir_i));
        try emit.code_offset_mapping.putNoClobber(
            emit.lower.allocator,
            mir_index,
            @as(u32, @intCast(emit.code.items.len)),
        );
        const lowered = try emit.lower.lowerMir(mir_index);
        var lowered_relocs = lowered.relocs;
        for (lowered.insts, 0..) |lowered_inst, lowered_index| {
            const start_offset = @as(u32, @intCast(emit.code.items.len));
            try lowered_inst.encode(emit.code.writer(), .{});
            const end_offset = @as(u32, @intCast(emit.code.items.len));
            while (lowered_relocs.len > 0 and
                lowered_relocs[0].lowered_inst_index == lowered_index) : ({
                lowered_relocs = lowered_relocs[1..];
            }) switch (lowered_relocs[0].target) {
                .inst => |target| try emit.relocs.append(emit.lower.allocator, .{
                    .source = start_offset,
                    .target = target,
                    .offset = end_offset - 4,
                    .length = @as(u5, @intCast(end_offset - start_offset)),
                }),
                .linker_extern_fn => |symbol| if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
                    // Add relocation to the decl.
                    const atom_index = macho_file.getAtomIndexForSymbol(
                        .{ .sym_index = symbol.atom_index, .file = null },
                    ).?;
                    const target = macho_file.getGlobalByIndex(symbol.sym_index);
                    try link.File.MachO.Atom.addRelocation(macho_file, atom_index, .{
                        .type = .branch,
                        .target = target,
                        .offset = end_offset - 4,
                        .addend = 0,
                        .pcrel = true,
                        .length = 2,
                    });
                } else if (emit.bin_file.cast(link.File.Coff)) |coff_file| {
                    // Add relocation to the decl.
                    const atom_index = coff_file.getAtomIndexForSymbol(
                        .{ .sym_index = symbol.atom_index, .file = null },
                    ).?;
                    const target = coff_file.getGlobalByIndex(symbol.sym_index);
                    try link.File.Coff.Atom.addRelocation(coff_file, atom_index, .{
                        .type = .direct,
                        .target = target,
                        .offset = end_offset - 4,
                        .addend = 0,
                        .pcrel = true,
                        .length = 2,
                    });
                } else return emit.fail("TODO implement extern reloc for {s}", .{
                    @tagName(emit.bin_file.tag),
                }),
                .linker_got,
                .linker_direct,
                .linker_import,
                .linker_tlv,
                => |symbol| if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
                    const atom_index = macho_file.getAtomIndexForSymbol(.{
                        .sym_index = symbol.atom_index,
                        .file = null,
                    }).?;
                    try link.File.MachO.Atom.addRelocation(macho_file, atom_index, .{
                        .type = switch (lowered_relocs[0].target) {
                            .linker_got => .got,
                            .linker_direct => .signed,
                            .linker_tlv => .tlv,
                            else => unreachable,
                        },
                        .target = .{ .sym_index = symbol.sym_index, .file = null },
                        .offset = @as(u32, @intCast(end_offset - 4)),
                        .addend = 0,
                        .pcrel = true,
                        .length = 2,
                    });
                } else if (emit.bin_file.cast(link.File.Coff)) |coff_file| {
                    const atom_index = coff_file.getAtomIndexForSymbol(.{
                        .sym_index = symbol.atom_index,
                        .file = null,
                    }).?;
                    try link.File.Coff.Atom.addRelocation(coff_file, atom_index, .{
                        .type = switch (lowered_relocs[0].target) {
                            .linker_got => .got,
                            .linker_direct => .direct,
                            .linker_import => .import,
                            else => unreachable,
                        },
                        .target = switch (lowered_relocs[0].target) {
                            .linker_got,
                            .linker_direct,
                            => .{ .sym_index = symbol.sym_index, .file = null },
                            .linker_import => coff_file.getGlobalByIndex(symbol.sym_index),
                            else => unreachable,
                        },
                        .offset = @as(u32, @intCast(end_offset - 4)),
                        .addend = 0,
                        .pcrel = true,
                        .length = 2,
                    });
                } else if (emit.bin_file.cast(link.File.Plan9)) |p9_file| {
                    const atom_index = symbol.atom_index;
                    try p9_file.addReloc(atom_index, .{ // TODO we may need to add a .type field to the relocs if they are .linker_got instead of just .linker_direct
                        .target = symbol.sym_index, // we set sym_index to just be the atom index
                        .offset = @as(u32, @intCast(end_offset - 4)),
                        .addend = 0,
                        .type = .pcrel,
                    });
                } else return emit.fail("TODO implement linker reloc for {s}", .{
                    @tagName(emit.bin_file.tag),
                }),
            };
        }
        std.debug.assert(lowered_relocs.len == 0);

        if (lowered.insts.len == 0) {
            const mir_inst = emit.lower.mir.instructions.get(mir_index);
            switch (mir_inst.tag) {
                else => unreachable,
                .pseudo => switch (mir_inst.ops) {
                    else => unreachable,
                    .pseudo_dbg_prologue_end_none => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| {
                                try dw.setPrologueEnd();
                                log.debug("mirDbgPrologueEnd (line={d}, col={d})", .{
                                    emit.prev_di_line, emit.prev_di_column,
                                });
                                try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
                            },
                            .plan9 => {},
                            .none => {},
                        }
                    },
                    .pseudo_dbg_line_line_column => try emit.dbgAdvancePCAndLine(
                        mir_inst.data.line_column.line,
                        mir_inst.data.line_column.column,
                    ),
                    .pseudo_dbg_epilogue_begin_none => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| {
                                try dw.setEpilogueBegin();
                                log.debug("mirDbgEpilogueBegin (line={d}, col={d})", .{
                                    emit.prev_di_line, emit.prev_di_column,
                                });
                                try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
                            },
                            .plan9 => {},
                            .none => {},
                        }
                    },
                    .pseudo_dead_none => {},
                },
            }
        }
    }
    try emit.fixupRelocs();
}

pub fn deinit(emit: *Emit) void {
    emit.relocs.deinit(emit.lower.allocator);
    emit.code_offset_mapping.deinit(emit.lower.allocator);
    emit.* = undefined;
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) Error {
    return switch (emit.lower.fail(format, args)) {
        error.LowerFail => error.EmitFail,
        else => |e| e,
    };
}

const Reloc = struct {
    /// Offset of the instruction.
    source: usize,
    /// Target of the relocation.
    target: Mir.Inst.Index,
    /// Offset of the relocation within the instruction.
    offset: usize,
    /// Length of the instruction.
    length: u5,
};

fn fixupRelocs(emit: *Emit) Error!void {
    // TODO this function currently assumes all relocs via JMP/CALL instructions are 32bit in size.
    // This should be reversed like it is done in aarch64 MIR emit code: start with the smallest
    // possible resolution, i.e., 8bit, and iteratively converge on the minimum required resolution
    // until the entire decl is correctly emitted with all JMP/CALL instructions within range.
    for (emit.relocs.items) |reloc| {
        const target = emit.code_offset_mapping.get(reloc.target) orelse
            return emit.fail("JMP/CALL relocation target not found!", .{});
        const disp = @as(i32, @intCast(@as(i64, @intCast(target)) - @as(i64, @intCast(reloc.source + reloc.length))));
        mem.writeIntLittle(i32, emit.code.items[reloc.offset..][0..4], disp);
    }
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) Error!void {
    const delta_line = @as(i32, @intCast(line)) - @as(i32, @intCast(emit.prev_di_line));
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    log.debug("  (advance pc={d} and line={d})", .{ delta_line, delta_pc });
    switch (emit.debug_output) {
        .dwarf => |dw| {
            try dw.advancePCAndLine(delta_line, delta_pc);
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes
            // we have already checked the target in the linker to make sure it is compatable
            const quant = @import("../../link/Plan9/aout.zig").getPCQuant(emit.lower.target.cpu.arch) catch unreachable;

            // increasing the line number
            try @import("../../link/Plan9.zig").changeLine(dbg_out.dbg_line, delta_line);
            // increasing the pc
            const d_pc_p9 = @as(i64, @intCast(delta_pc)) - quant;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one quanta
                var diff = @divExact(d_pc_p9, quant) - quant;
                while (diff > 0) {
                    if (diff < 64) {
                        try dbg_out.dbg_line.append(@as(u8, @intCast(diff + 128)));
                        diff = 0;
                    } else {
                        try dbg_out.dbg_line.append(@as(u8, @intCast(64 + 128)));
                        diff -= 64;
                    }
                }
                if (dbg_out.pcop_change_index.*) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index.* = @as(u32, @intCast(dbg_out.dbg_line.items.len - 1));
            } else if (d_pc_p9 == 0) {
                // we don't need to do anything, because adding the quant does it for us
            } else unreachable;
            if (dbg_out.start_line.* == null)
                dbg_out.start_line.* = emit.prev_di_line;
            dbg_out.end_line.* = line;
            // only do this if the pc changed
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .none => {},
    }
}

const link = @import("../../link.zig");
const log = std.log.scoped(.emit);
const mem = std.mem;
const std = @import("std");

const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const Emit = @This();
const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
