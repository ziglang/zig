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
    for (0..emit.lower.mir.instructions.len) |i| {
        const index = @intCast(Mir.Inst.Index, i);
        const inst = emit.lower.mir.instructions.get(index);

        const start_offset = @intCast(u32, emit.code.items.len);
        try emit.code_offset_mapping.putNoClobber(emit.lower.allocator, index, start_offset);
        for (try emit.lower.lowerMir(inst)) |lower_inst| try lower_inst.encode(emit.code.writer(), .{});
        const end_offset = @intCast(u32, emit.code.items.len);

        switch (inst.tag) {
            else => {},

            .jmp_reloc => try emit.relocs.append(emit.lower.allocator, .{
                .source = start_offset,
                .target = inst.data.inst,
                .offset = end_offset - 4,
                .length = 5,
            }),

            .call_extern => if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
                // Add relocation to the decl.
                const atom_index = macho_file.getAtomIndexForSymbol(
                    .{ .sym_index = inst.data.relocation.atom_index, .file = null },
                ).?;
                const target = macho_file.getGlobalByIndex(inst.data.relocation.sym_index);
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
                    .{ .sym_index = inst.data.relocation.atom_index, .file = null },
                ).?;
                const target = coff_file.getGlobalByIndex(inst.data.relocation.sym_index);
                try link.File.Coff.Atom.addRelocation(coff_file, atom_index, .{
                    .type = .direct,
                    .target = target,
                    .offset = end_offset - 4,
                    .addend = 0,
                    .pcrel = true,
                    .length = 2,
                });
            } else return emit.fail("TODO implement {} for {}", .{ inst.tag, emit.bin_file.tag }),

            .mov_linker, .lea_linker => if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
                const metadata =
                    emit.lower.mir.extraData(Mir.LeaRegisterReloc, inst.data.payload).data;
                const atom_index = macho_file.getAtomIndexForSymbol(.{
                    .sym_index = metadata.atom_index,
                    .file = null,
                }).?;
                try link.File.MachO.Atom.addRelocation(macho_file, atom_index, .{
                    .type = switch (inst.ops) {
                        .got_reloc => .got,
                        .direct_reloc => .signed,
                        .tlv_reloc => .tlv,
                        else => unreachable,
                    },
                    .target = .{ .sym_index = metadata.sym_index, .file = null },
                    .offset = @intCast(u32, end_offset - 4),
                    .addend = 0,
                    .pcrel = true,
                    .length = 2,
                });
            } else if (emit.bin_file.cast(link.File.Coff)) |coff_file| {
                const metadata =
                    emit.lower.mir.extraData(Mir.LeaRegisterReloc, inst.data.payload).data;
                const atom_index = coff_file.getAtomIndexForSymbol(.{
                    .sym_index = metadata.atom_index,
                    .file = null,
                }).?;
                try link.File.Coff.Atom.addRelocation(coff_file, atom_index, .{
                    .type = switch (inst.ops) {
                        .got_reloc => .got,
                        .direct_reloc => .direct,
                        .import_reloc => .import,
                        else => unreachable,
                    },
                    .target = switch (inst.ops) {
                        .got_reloc,
                        .direct_reloc,
                        => .{ .sym_index = metadata.sym_index, .file = null },
                        .import_reloc => coff_file.getGlobalByIndex(metadata.sym_index),
                        else => unreachable,
                    },
                    .offset = @intCast(u32, end_offset - 4),
                    .addend = 0,
                    .pcrel = true,
                    .length = 2,
                });
            } else return emit.fail("TODO implement {} for {}", .{ inst.tag, emit.bin_file.tag }),

            .jcc => try emit.relocs.append(emit.lower.allocator, .{
                .source = start_offset,
                .target = inst.data.inst_cc.inst,
                .offset = end_offset - 4,
                .length = 6,
            }),

            .dbg_line => try emit.dbgAdvancePCAndLine(
                inst.data.line_column.line,
                inst.data.line_column.column,
            ),

            .dbg_prologue_end => {
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

            .dbg_epilogue_begin => {
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
        const disp = @intCast(i32, @intCast(i64, target) - @intCast(i64, reloc.source + reloc.length));
        mem.writeIntLittle(i32, emit.code.items[reloc.offset..][0..4], disp);
    }
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) Error!void {
    const delta_line = @intCast(i32, line) - @intCast(i32, emit.prev_di_line);
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
            const d_pc_p9 = @intCast(i64, delta_pc) - quant;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one quanta
                var diff = @divExact(d_pc_p9, quant) - quant;
                while (diff > 0) {
                    if (diff < 64) {
                        try dbg_out.dbg_line.append(@intCast(u8, diff + 128));
                        diff = 0;
                    } else {
                        try dbg_out.dbg_line.append(@intCast(u8, 64 + 128));
                        diff -= 64;
                    }
                }
                if (dbg_out.pcop_change_index.*) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index.* = @intCast(u32, dbg_out.dbg_line.items.len - 1);
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
