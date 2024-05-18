//! This file contains the functionality for emitting RISC-V MIR as machine code

lower: Lower,
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
    log.debug("mir instruction len: {}", .{emit.lower.mir.instructions.len});
    for (0..emit.lower.mir.instructions.len) |mir_i| {
        const mir_index: Mir.Inst.Index = @intCast(mir_i);
        try emit.code_offset_mapping.putNoClobber(
            emit.lower.allocator,
            mir_index,
            @intCast(emit.code.items.len),
        );
        const lowered = try emit.lower.lowerMir(mir_index);
        var lowered_relocs = lowered.relocs;
        for (lowered.insts, 0..) |lowered_inst, lowered_index| {
            const start_offset: u32 = @intCast(emit.code.items.len);
            try lowered_inst.encode(emit.code.writer());

            while (lowered_relocs.len > 0 and
                lowered_relocs[0].lowered_inst_index == lowered_index) : ({
                lowered_relocs = lowered_relocs[1..];
            }) switch (lowered_relocs[0].target) {
                .inst => |target| try emit.relocs.append(emit.lower.allocator, .{
                    .source = start_offset,
                    .target = target,
                    .offset = 0,
                    .enc = std.meta.activeTag(lowered_inst.encoding.data),
                }),
                .load_symbol_reloc => |symbol| {
                    if (emit.lower.bin_file.cast(link.File.Elf)) |elf_file| {
                        const atom_ptr = elf_file.symbol(symbol.atom_index).atom(elf_file).?;
                        const sym_index = elf_file.zigObjectPtr().?.symbol(symbol.sym_index);
                        const sym = elf_file.symbol(sym_index);

                        var hi_r_type: u32 = @intFromEnum(std.elf.R_RISCV.HI20);
                        var lo_r_type: u32 = @intFromEnum(std.elf.R_RISCV.LO12_I);

                        if (sym.flags.needs_zig_got) {
                            _ = try sym.getOrCreateZigGotEntry(sym_index, elf_file);

                            hi_r_type = Elf.R_ZIG_GOT_HI20;
                            lo_r_type = Elf.R_ZIG_GOT_LO12;
                        }

                        try atom_ptr.addReloc(elf_file, .{
                            .r_offset = start_offset,
                            .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | hi_r_type,
                            .r_addend = 0,
                        });

                        try atom_ptr.addReloc(elf_file, .{
                            .r_offset = start_offset + 4,
                            .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | lo_r_type,
                            .r_addend = 0,
                        });
                    } else return emit.fail("TODO: load_symbol_reloc non-ELF", .{});
                },
            };
        }
        std.debug.assert(lowered_relocs.len == 0);

        if (lowered.insts.len == 0) {
            const mir_inst = emit.lower.mir.instructions.get(mir_index);
            switch (mir_inst.tag) {
                else => unreachable,
                .pseudo => switch (mir_inst.ops) {
                    else => unreachable,
                    .pseudo_dbg_prologue_end => {
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
                    .pseudo_dbg_line_column => try emit.dbgAdvancePCAndLine(
                        mir_inst.data.pseudo_dbg_line_column.line,
                        mir_inst.data.pseudo_dbg_line_column.column,
                    ),
                    .pseudo_dbg_epilogue_begin => {
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
                    .pseudo_dead => {},
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

const Reloc = struct {
    /// Offset of the instruction.
    source: usize,
    /// Target of the relocation.
    target: Mir.Inst.Index,
    /// Offset of the relocation within the instruction.
    offset: u32,
    /// Encoding of the instruction, used to determine how to modify it.
    enc: Encoding.InstEnc,
};

fn fixupRelocs(emit: *Emit) Error!void {
    for (emit.relocs.items) |reloc| {
        log.debug("target inst: {}", .{emit.lower.mir.instructions.get(reloc.target)});
        const target = emit.code_offset_mapping.get(reloc.target) orelse
            return emit.fail("relocation target not found!", .{});

        const disp = @as(i32, @intCast(target)) - @as(i32, @intCast(reloc.source));
        const code: *[4]u8 = emit.code.items[reloc.source + reloc.offset ..][0..4];

        log.debug("disp: {x}", .{disp});

        switch (reloc.enc) {
            .J => riscv_util.writeInstJ(code, @bitCast(disp)),
            .B => riscv_util.writeInstB(code, @bitCast(disp)),
            else => return emit.fail("tried to reloc encoding type {s}", .{@tagName(reloc.enc)}),
        }
    }
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) Error!void {
    const delta_line = @as(i33, line) - @as(i33, emit.prev_di_line);
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    log.debug("  (advance pc={d} and line={d})", .{ delta_pc, delta_line });
    switch (emit.debug_output) {
        .dwarf => |dw| {
            if (column != emit.prev_di_column) try dw.setColumn(column);
            if (delta_line == 0) return; // TODO: fix these edge cases.
            try dw.advancePCAndLine(delta_line, delta_pc);
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .plan9 => {},
        .none => {},
    }
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) Error {
    return switch (emit.lower.fail(format, args)) {
        error.LowerFail => error.EmitFail,
        else => |e| e,
    };
}

const link = @import("../../link.zig");
const log = std.log.scoped(.emit);
const mem = std.mem;
const std = @import("std");

const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const Emit = @This();
const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
const riscv_util = @import("../../link/riscv.zig");
const Encoding = @import("Encoding.zig");
const Elf = @import("../../link/Elf.zig");
