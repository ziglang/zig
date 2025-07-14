//! This file contains the functionality for emitting LoongArch MIR as machine code

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.emit);
const R_LARCH = std.elf.R_LARCH;

const link = @import("../../link.zig");
const codegen = @import("../../codegen.zig");
const Zcu = @import("../../Zcu.zig");
const Type = @import("../../Type.zig");
const InternPool = @import("../../InternPool.zig");

const Lower = @import("Lower.zig");
const Lir = @import("Lir.zig");
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");

const Emit = @This();

lower: Lower,
pt: Zcu.PerThread,
bin_file: *link.File,
owner_nav: InternPool.Nav.Index,
atom_index: u32,
debug_output: link.File.DebugInfoOutput,
code: *std.ArrayListUnmanaged(u8),

prev_di_loc: Loc,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

pub const Error = Lower.Error || error{EmitFail} || link.File.UpdateDebugInfoError;

pub fn emitMir(emit: *Emit) Error!void {
    const ip = &emit.pt.zcu.intern_pool;
    log.debug("Begin Emit: {f}", .{ip.getNav(emit.owner_nav).fqn.fmt(ip)});
    const gpa = emit.lower.link_file.comp.gpa;

    const code_offset_mapping = try emit.lower.allocator.alloc(u32, emit.lower.mir.instructions.len);
    defer emit.lower.allocator.free(code_offset_mapping);
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
                .inst => |reloc| {
                    try relocs.append(emit.lower.allocator, .{
                        .source = start_offset,
                        .loc = reloc.loc,
                        .target = reloc.inst,
                        .off = lir_relocs[0].off,
                    });
                },
                .elf_nav => |sym| {
                    const sym_index = switch (try codegen.genNavRef(
                        emit.bin_file,
                        emit.pt,
                        emit.lower.src_loc,
                        sym.symbol,
                        emit.lower.target,
                    )) {
                        .sym_index => |index| index,
                        .fail => |em| {
                            assert(emit.lower.err_msg == null);
                            emit.lower.err_msg = em;
                            return error.EmitFail;
                        },
                    };
                    const elf_file = emit.lower.link_file.cast(.elf).?;
                    const zo = elf_file.zigObjectPtr().?;
                    const atom_ptr = zo.symbol(emit.atom_index).atom(elf_file).?;
                    try atom_ptr.addReloc(gpa, .{
                        .r_offset = start_offset,
                        .r_info = (@as(u64, sym_index) << 32) | @intFromEnum(sym.ty),
                        .r_addend = lir_relocs[0].off,
                    }, zo);
                },
                .elf_uav => |sym| {
                    const sym_index = switch (try emit.bin_file.lowerUav(
                        emit.pt,
                        sym.symbol.val,
                        Type.fromInterned(sym.symbol.orig_ty).ptrAlignment(emit.pt.zcu),
                        emit.lower.src_loc,
                    )) {
                        .sym_index => |index| index,
                        .fail => |em| {
                            assert(emit.lower.err_msg == null);
                            emit.lower.err_msg = em;
                            return error.EmitFail;
                        },
                    };
                    const elf_file = emit.lower.link_file.cast(.elf).?;
                    const zo = elf_file.zigObjectPtr().?;
                    const atom_ptr = zo.symbol(emit.atom_index).atom(elf_file).?;
                    try atom_ptr.addReloc(gpa, .{
                        .r_offset = start_offset,
                        .r_info = (@as(u64, sym_index) << 32) | @intFromEnum(sym.ty),
                        .r_addend = lir_relocs[0].off,
                    }, zo);
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
                .dbg_enter_block => switch (emit.debug_output) {
                    .dwarf => |dwarf| try dwarf.enterBlock(emit.code.items.len),
                    .plan9, .none => {},
                },
                .dbg_exit_block => switch (emit.debug_output) {
                    .dwarf => |dwarf| try dwarf.leaveBlock(emit.code.items.len),
                    .plan9, .none => {},
                },
                .dbg_enter_inline_func => switch (emit.debug_output) {
                    .dwarf => |dwarf| try dwarf.enterInlineFunc(
                        mir_inst.data.func,
                        emit.code.items.len,
                        emit.prev_di_loc.line,
                        emit.prev_di_loc.column,
                    ),
                    .plan9, .none => {},
                },
                .dbg_exit_inline_func => switch (emit.debug_output) {
                    .dwarf => |dwarf| try dwarf.leaveInlineFunc(
                        mir_inst.data.func,
                        emit.code.items.len,
                    ),
                    .plan9, .none => {},
                },
                else => {},
            },
        }
    }

    for (relocs.items) |reloc| {
        const target = @as(i32, @intCast(code_offset_mapping[reloc.target])) + reloc.off;
        const offset = target - @as(i32, @intCast(reloc.source));
        const offset_u32 = @as(u32, @bitCast(offset));

        const inst_bytes = emit.code.items[reloc.source..][0..4];
        var inst_u32 = std.mem.readInt(u32, inst_bytes, .little);

        switch (reloc.loc) {
            .b26 => inst_u32 = inst_u32 |
                (@as(u32, @as(u16, @truncate((offset_u32 >> 2) & 0xffff))) << 10) |
                @as(u32, @as(u10, @truncate((offset_u32 >> 2) >> 16))),
            .k16 => inst_u32 = inst_u32 |
                (@as(u32, @as(u16, @truncate((offset_u32 >> 2) & 0xffff))) << 10),
        }

        std.mem.writeInt(u32, inst_bytes, inst_u32, .little);
    }
    log.debug("End Emit: {f}", .{ip.getNav(emit.owner_nav).fqn.fmt(ip)});
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) Error {
    @branchHint(.cold);
    assert(emit.lower.err_msg == null);
    emit.lower.err_msg = try Zcu.ErrorMsg.create(emit.lower.allocator, emit.lower.src_loc, format, args);
    return error.LowerFail;
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
