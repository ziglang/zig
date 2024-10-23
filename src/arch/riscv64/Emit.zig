//! This file contains the functionality for emitting RISC-V MIR as machine code

bin_file: *link.File,
lower: Lower,
debug_output: link.File.DebugInfoOutput,
code: *std.ArrayList(u8),

prev_di_line: u32,
prev_di_column: u32,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

code_offset_mapping: std.AutoHashMapUnmanaged(Mir.Inst.Index, usize) = .empty,
relocs: std.ArrayListUnmanaged(Reloc) = .empty,

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
        const lowered = try emit.lower.lowerMir(mir_index, .{ .allow_frame_locs = true });
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
                    .fmt = std.meta.activeTag(lowered_inst),
                }),
                .load_symbol_reloc => |symbol| {
                    const elf_file = emit.bin_file.cast(.elf).?;
                    const zo = elf_file.zigObjectPtr().?;

                    const atom_ptr = zo.symbol(symbol.atom_index).atom(elf_file).?;
                    const sym = zo.symbol(symbol.sym_index);

                    if (sym.flags.is_extern_ptr and emit.lower.pic) {
                        return emit.fail("emit GOT relocation for symbol '{s}'", .{sym.name(elf_file)});
                    }

                    const hi_r_type: u32 = @intFromEnum(std.elf.R_RISCV.HI20);
                    const lo_r_type: u32 = @intFromEnum(std.elf.R_RISCV.LO12_I);

                    try atom_ptr.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = start_offset,
                        .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | hi_r_type,
                        .r_addend = 0,
                    }, zo);

                    try atom_ptr.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = start_offset + 4,
                        .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | lo_r_type,
                        .r_addend = 0,
                    }, zo);
                },
                .load_tlv_reloc => |symbol| {
                    const elf_file = emit.bin_file.cast(.elf).?;
                    const zo = elf_file.zigObjectPtr().?;

                    const atom_ptr = zo.symbol(symbol.atom_index).atom(elf_file).?;

                    const R_RISCV = std.elf.R_RISCV;

                    try atom_ptr.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = start_offset,
                        .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | @intFromEnum(R_RISCV.TPREL_HI20),
                        .r_addend = 0,
                    }, zo);

                    try atom_ptr.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = start_offset + 4,
                        .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | @intFromEnum(R_RISCV.TPREL_ADD),
                        .r_addend = 0,
                    }, zo);

                    try atom_ptr.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = start_offset + 8,
                        .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | @intFromEnum(R_RISCV.TPREL_LO12_I),
                        .r_addend = 0,
                    }, zo);
                },
                .call_extern_fn_reloc => |symbol| {
                    const elf_file = emit.bin_file.cast(.elf).?;
                    const zo = elf_file.zigObjectPtr().?;
                    const atom_ptr = zo.symbol(symbol.atom_index).atom(elf_file).?;

                    const r_type: u32 = @intFromEnum(std.elf.R_RISCV.CALL_PLT);

                    try atom_ptr.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = start_offset,
                        .r_info = (@as(u64, @intCast(symbol.sym_index)) << 32) | r_type,
                        .r_addend = 0,
                    }, zo);
                },
            };
        }
        std.debug.assert(lowered_relocs.len == 0);

        if (lowered.insts.len == 0) {
            const mir_inst = emit.lower.mir.instructions.get(mir_index);
            switch (mir_inst.tag) {
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
    /// Format of the instruction, used to determine how to modify it.
    fmt: encoding.Lir.Format,
};

fn fixupRelocs(emit: *Emit) Error!void {
    for (emit.relocs.items) |reloc| {
        log.debug("target inst: {}", .{emit.lower.mir.instructions.get(reloc.target)});
        const target = emit.code_offset_mapping.get(reloc.target) orelse
            return emit.fail("relocation target not found!", .{});

        const disp = @as(i32, @intCast(target)) - @as(i32, @intCast(reloc.source));
        const code: *[4]u8 = emit.code.items[reloc.source + reloc.offset ..][0..4];

        switch (reloc.fmt) {
            .J => riscv_util.writeInstJ(code, @bitCast(disp)),
            .B => riscv_util.writeInstB(code, @bitCast(disp)),
            else => return emit.fail("tried to reloc format type {s}", .{@tagName(reloc.fmt)}),
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

const Emit = @This();
const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
const riscv_util = @import("../../link/riscv.zig");
const Elf = @import("../../link/Elf.zig");
const encoding = @import("encoding.zig");
