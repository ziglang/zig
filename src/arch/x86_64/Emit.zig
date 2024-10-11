//! This file contains the functionality for emitting x86_64 MIR as machine code

air: Air,
lower: Lower,
atom_index: u32,
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
} || link.File.UpdateDebugInfoError;

pub fn emitMir(emit: *Emit) Error!void {
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
            if (lowered_inst.prefix == .directive) {
                switch (emit.debug_output) {
                    .dwarf => |dwarf| switch (lowered_inst.encoding.mnemonic) {
                        .@".cfi_def_cfa" => try dwarf.genDebugFrame(start_offset, .{ .def_cfa = .{
                            .reg = lowered_inst.ops[0].reg.dwarfNum(),
                            .off = lowered_inst.ops[1].imm.signed,
                        } }),
                        .@".cfi_def_cfa_register" => try dwarf.genDebugFrame(start_offset, .{
                            .def_cfa_register = lowered_inst.ops[0].reg.dwarfNum(),
                        }),
                        .@".cfi_def_cfa_offset" => try dwarf.genDebugFrame(start_offset, .{
                            .def_cfa_offset = lowered_inst.ops[0].imm.signed,
                        }),
                        .@".cfi_adjust_cfa_offset" => try dwarf.genDebugFrame(start_offset, .{
                            .adjust_cfa_offset = lowered_inst.ops[0].imm.signed,
                        }),
                        .@".cfi_offset" => try dwarf.genDebugFrame(start_offset, .{ .offset = .{
                            .reg = lowered_inst.ops[0].reg.dwarfNum(),
                            .off = lowered_inst.ops[1].imm.signed,
                        } }),
                        .@".cfi_val_offset" => try dwarf.genDebugFrame(start_offset, .{ .val_offset = .{
                            .reg = lowered_inst.ops[0].reg.dwarfNum(),
                            .off = lowered_inst.ops[1].imm.signed,
                        } }),
                        .@".cfi_rel_offset" => try dwarf.genDebugFrame(start_offset, .{ .rel_offset = .{
                            .reg = lowered_inst.ops[0].reg.dwarfNum(),
                            .off = lowered_inst.ops[1].imm.signed,
                        } }),
                        .@".cfi_register" => try dwarf.genDebugFrame(start_offset, .{ .register = .{
                            lowered_inst.ops[0].reg.dwarfNum(),
                            lowered_inst.ops[1].reg.dwarfNum(),
                        } }),
                        .@".cfi_restore" => try dwarf.genDebugFrame(start_offset, .{
                            .restore = lowered_inst.ops[0].reg.dwarfNum(),
                        }),
                        .@".cfi_undefined" => try dwarf.genDebugFrame(start_offset, .{
                            .undefined = lowered_inst.ops[0].reg.dwarfNum(),
                        }),
                        .@".cfi_same_value" => try dwarf.genDebugFrame(start_offset, .{
                            .same_value = lowered_inst.ops[0].reg.dwarfNum(),
                        }),
                        .@".cfi_remember_state" => try dwarf.genDebugFrame(start_offset, .remember_state),
                        .@".cfi_restore_state" => try dwarf.genDebugFrame(start_offset, .restore_state),
                        .@".cfi_escape" => try dwarf.genDebugFrame(start_offset, .{
                            .escape = lowered_inst.ops[0].bytes,
                        }),
                        else => unreachable,
                    },
                    .plan9 => {},
                    .none => {},
                }
                continue;
            }
            try lowered_inst.encode(emit.code.writer(), .{});
            const end_offset: u32 = @intCast(emit.code.items.len);
            while (lowered_relocs.len > 0 and
                lowered_relocs[0].lowered_inst_index == lowered_index) : ({
                lowered_relocs = lowered_relocs[1..];
            }) switch (lowered_relocs[0].target) {
                .inst => |target| try emit.relocs.append(emit.lower.allocator, .{
                    .source = start_offset,
                    .source_offset = end_offset - 4,
                    .target = target,
                    .target_offset = lowered_relocs[0].off,
                    .length = @intCast(end_offset - start_offset),
                }),
                .linker_extern_fn => |sym_index| if (emit.lower.bin_file.cast(.elf)) |elf_file| {
                    // Add relocation to the decl.
                    const zo = elf_file.zigObjectPtr().?;
                    const atom_ptr = zo.symbol(emit.atom_index).atom(elf_file).?;
                    const r_type = @intFromEnum(std.elf.R_X86_64.PLT32);
                    try atom_ptr.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = end_offset - 4,
                        .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                        .r_addend = lowered_relocs[0].off - 4,
                    }, zo);
                } else if (emit.lower.bin_file.cast(.macho)) |macho_file| {
                    // Add relocation to the decl.
                    const zo = macho_file.getZigObject().?;
                    const atom = zo.symbols.items[emit.atom_index].getAtom(macho_file).?;
                    try atom.addReloc(macho_file, .{
                        .tag = .@"extern",
                        .offset = end_offset - 4,
                        .target = sym_index,
                        .addend = lowered_relocs[0].off,
                        .type = .branch,
                        .meta = .{
                            .pcrel = true,
                            .has_subtractor = false,
                            .length = 2,
                            .symbolnum = @intCast(sym_index),
                        },
                    });
                } else if (emit.lower.bin_file.cast(.coff)) |coff_file| {
                    // Add relocation to the decl.
                    const atom_index = coff_file.getAtomIndexForSymbol(
                        .{ .sym_index = emit.atom_index, .file = null },
                    ).?;
                    const target = if (link.File.Coff.global_symbol_bit & sym_index != 0)
                        coff_file.getGlobalByIndex(link.File.Coff.global_symbol_mask & sym_index)
                    else
                        link.File.Coff.SymbolWithLoc{ .sym_index = sym_index, .file = null };
                    try link.File.Coff.Atom.addRelocation(coff_file, atom_index, .{
                        .type = .direct,
                        .target = target,
                        .offset = end_offset - 4,
                        .addend = @intCast(lowered_relocs[0].off),
                        .pcrel = true,
                        .length = 2,
                    });
                } else return emit.fail("TODO implement extern reloc for {s}", .{
                    @tagName(emit.lower.bin_file.tag),
                }),
                .linker_tlsld => |sym_index| {
                    const elf_file = emit.lower.bin_file.cast(.elf).?;
                    const zo = elf_file.zigObjectPtr().?;
                    const atom = zo.symbol(emit.atom_index).atom(elf_file).?;
                    const r_type = @intFromEnum(std.elf.R_X86_64.TLSLD);
                    try atom.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = end_offset - 4,
                        .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                        .r_addend = lowered_relocs[0].off - 4,
                    }, zo);
                },
                .linker_dtpoff => |sym_index| {
                    const elf_file = emit.lower.bin_file.cast(.elf).?;
                    const zo = elf_file.zigObjectPtr().?;
                    const atom = zo.symbol(emit.atom_index).atom(elf_file).?;
                    const r_type = @intFromEnum(std.elf.R_X86_64.DTPOFF32);
                    try atom.addReloc(elf_file.base.comp.gpa, .{
                        .r_offset = end_offset - 4,
                        .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                        .r_addend = lowered_relocs[0].off,
                    }, zo);
                },
                .linker_reloc => |sym_index| if (emit.lower.bin_file.cast(.elf)) |elf_file| {
                    const zo = elf_file.zigObjectPtr().?;
                    const atom = zo.symbol(emit.atom_index).atom(elf_file).?;
                    const sym = zo.symbol(sym_index);
                    if (emit.lower.pic) {
                        const r_type: u32 = if (sym.flags.is_extern_ptr)
                            @intFromEnum(std.elf.R_X86_64.GOTPCREL)
                        else
                            @intFromEnum(std.elf.R_X86_64.PC32);
                        try atom.addReloc(elf_file.base.comp.gpa, .{
                            .r_offset = end_offset - 4,
                            .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                            .r_addend = lowered_relocs[0].off - 4,
                        }, zo);
                    } else {
                        const r_type: u32 = if (sym.flags.is_tls)
                            @intFromEnum(std.elf.R_X86_64.TPOFF32)
                        else
                            @intFromEnum(std.elf.R_X86_64.@"32");
                        try atom.addReloc(elf_file.base.comp.gpa, .{
                            .r_offset = end_offset - 4,
                            .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                            .r_addend = lowered_relocs[0].off,
                        }, zo);
                    }
                } else if (emit.lower.bin_file.cast(.macho)) |macho_file| {
                    const zo = macho_file.getZigObject().?;
                    const atom = zo.symbols.items[emit.atom_index].getAtom(macho_file).?;
                    const sym = &zo.symbols.items[sym_index];
                    const @"type": link.File.MachO.Relocation.Type = if (sym.flags.is_extern_ptr)
                        .got_load
                    else if (sym.flags.tlv)
                        .tlv
                    else
                        .signed;
                    try atom.addReloc(macho_file, .{
                        .tag = .@"extern",
                        .offset = @intCast(end_offset - 4),
                        .target = sym_index,
                        .addend = lowered_relocs[0].off,
                        .type = @"type",
                        .meta = .{
                            .pcrel = true,
                            .has_subtractor = false,
                            .length = 2,
                            .symbolnum = @intCast(sym_index),
                        },
                    });
                } else unreachable,
                .linker_got,
                .linker_direct,
                .linker_import,
                => |sym_index| if (emit.lower.bin_file.cast(.elf)) |_| {
                    unreachable;
                } else if (emit.lower.bin_file.cast(.macho)) |_| {
                    unreachable;
                } else if (emit.lower.bin_file.cast(.coff)) |coff_file| {
                    const atom_index = coff_file.getAtomIndexForSymbol(.{
                        .sym_index = emit.atom_index,
                        .file = null,
                    }).?;
                    const target = if (link.File.Coff.global_symbol_bit & sym_index != 0)
                        coff_file.getGlobalByIndex(link.File.Coff.global_symbol_mask & sym_index)
                    else
                        link.File.Coff.SymbolWithLoc{ .sym_index = sym_index, .file = null };
                    try link.File.Coff.Atom.addRelocation(coff_file, atom_index, .{
                        .type = switch (lowered_relocs[0].target) {
                            .linker_got => .got,
                            .linker_direct => .direct,
                            .linker_import => .import,
                            else => unreachable,
                        },
                        .target = target,
                        .offset = @intCast(end_offset - 4),
                        .addend = @intCast(lowered_relocs[0].off),
                        .pcrel = true,
                        .length = 2,
                    });
                } else if (emit.lower.bin_file.cast(.plan9)) |p9_file| {
                    try p9_file.addReloc(emit.atom_index, .{ // TODO we may need to add a .type field to the relocs if they are .linker_got instead of just .linker_direct
                        .target = sym_index, // we set sym_index to just be the atom index
                        .offset = @intCast(end_offset - 4),
                        .addend = @intCast(lowered_relocs[0].off),
                        .type = .pcrel,
                    });
                } else return emit.fail("TODO implement linker reloc for {s}", .{
                    @tagName(emit.lower.bin_file.tag),
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
                            .dwarf => |dw| try dw.setPrologueEnd(),
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
                    .pseudo_dbg_enter_block_none => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| {
                                log.debug("mirDbgEnterBlock (line={d}, col={d})", .{
                                    emit.prev_di_line, emit.prev_di_column,
                                });
                                try dw.enterBlock(emit.code.items.len);
                            },
                            .plan9 => {},
                            .none => {},
                        }
                    },
                    .pseudo_dbg_leave_block_none => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| {
                                log.debug("mirDbgLeaveBlock (line={d}, col={d})", .{
                                    emit.prev_di_line, emit.prev_di_column,
                                });
                                try dw.leaveBlock(emit.code.items.len);
                            },
                            .plan9 => {},
                            .none => {},
                        }
                    },
                    .pseudo_dbg_enter_inline_func => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| {
                                log.debug("mirDbgEnterInline (line={d}, col={d})", .{
                                    emit.prev_di_line, emit.prev_di_column,
                                });
                                try dw.enterInlineFunc(mir_inst.data.func, emit.code.items.len, emit.prev_di_line, emit.prev_di_column);
                            },
                            .plan9 => {},
                            .none => {},
                        }
                    },
                    .pseudo_dbg_leave_inline_func => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| {
                                log.debug("mirDbgLeaveInline (line={d}, col={d})", .{
                                    emit.prev_di_line, emit.prev_di_column,
                                });
                                try dw.leaveInlineFunc(mir_inst.data.func, emit.code.items.len);
                            },
                            .plan9 => {},
                            .none => {},
                        }
                    },
                    .pseudo_dbg_local_a,
                    .pseudo_dbg_local_ai_s,
                    .pseudo_dbg_local_ai_u,
                    .pseudo_dbg_local_ai_64,
                    .pseudo_dbg_local_as,
                    .pseudo_dbg_local_aso,
                    .pseudo_dbg_local_aro,
                    .pseudo_dbg_local_af,
                    .pseudo_dbg_local_am,
                    => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| {
                                var loc_buf: [2]link.File.Dwarf.Loc = undefined;
                                const air_inst_index, const loc: link.File.Dwarf.Loc = switch (mir_inst.ops) {
                                    else => unreachable,
                                    .pseudo_dbg_local_a => .{ mir_inst.data.a.air_inst, .empty },
                                    .pseudo_dbg_local_ai_s,
                                    .pseudo_dbg_local_ai_u,
                                    .pseudo_dbg_local_ai_64,
                                    => .{ mir_inst.data.ai.air_inst, .{ .stack_value = stack_value: {
                                        loc_buf[0] = switch (emit.lower.imm(mir_inst.ops, mir_inst.data.ai.i)) {
                                            .signed => |s| .{ .consts = s },
                                            .unsigned => |u| .{ .constu = u },
                                        };
                                        break :stack_value &loc_buf[0];
                                    } } },
                                    .pseudo_dbg_local_as => .{ mir_inst.data.as.air_inst, .{ .addr = .{
                                        .sym = mir_inst.data.as.sym_index,
                                    } } },
                                    .pseudo_dbg_local_aso => loc: {
                                        const sym_off = emit.lower.mir.extraData(
                                            bits.SymbolOffset,
                                            mir_inst.data.ax.payload,
                                        ).data;
                                        break :loc .{ mir_inst.data.ax.air_inst, .{ .plus = .{
                                            sym: {
                                                loc_buf[0] = .{ .addr = .{ .sym = sym_off.sym_index } };
                                                break :sym &loc_buf[0];
                                            },
                                            off: {
                                                loc_buf[1] = .{ .consts = sym_off.off };
                                                break :off &loc_buf[1];
                                            },
                                        } } };
                                    },
                                    .pseudo_dbg_local_aro => loc: {
                                        const air_off = emit.lower.mir.extraData(
                                            Mir.AirOffset,
                                            mir_inst.data.rx.payload,
                                        ).data;
                                        break :loc .{ air_off.air_inst, .{ .plus = .{
                                            reg: {
                                                loc_buf[0] = .{ .breg = mir_inst.data.rx.r1.dwarfNum() };
                                                break :reg &loc_buf[0];
                                            },
                                            off: {
                                                loc_buf[1] = .{ .consts = air_off.off };
                                                break :off &loc_buf[1];
                                            },
                                        } } };
                                    },
                                    .pseudo_dbg_local_af => loc: {
                                        const reg_off = emit.lower.mir.resolveFrameAddr(emit.lower.mir.extraData(
                                            bits.FrameAddr,
                                            mir_inst.data.ax.payload,
                                        ).data);
                                        break :loc .{ mir_inst.data.ax.air_inst, .{ .plus = .{
                                            reg: {
                                                loc_buf[0] = .{ .breg = reg_off.reg.dwarfNum() };
                                                break :reg &loc_buf[0];
                                            },
                                            off: {
                                                loc_buf[1] = .{ .consts = reg_off.off };
                                                break :off &loc_buf[1];
                                            },
                                        } } };
                                    },
                                    .pseudo_dbg_local_am => loc: {
                                        const mem = emit.lower.mem(mir_inst.data.ax.payload);
                                        break :loc .{ mir_inst.data.ax.air_inst, .{ .plus = .{
                                            base: {
                                                loc_buf[0] = switch (mem.base()) {
                                                    .none => .{ .constu = 0 },
                                                    .reg => |reg| .{ .breg = reg.dwarfNum() },
                                                    .frame => unreachable,
                                                    .reloc => |sym_index| .{ .addr = .{ .sym = sym_index } },
                                                };
                                                break :base &loc_buf[0];
                                            },
                                            disp: {
                                                loc_buf[1] = switch (mem.disp()) {
                                                    .signed => |s| .{ .consts = s },
                                                    .unsigned => |u| .{ .constu = u },
                                                };
                                                break :disp &loc_buf[1];
                                            },
                                        } } };
                                    },
                                };
                                const ip = &emit.lower.bin_file.comp.zcu.?.intern_pool;
                                const air_inst = emit.air.instructions.get(@intFromEnum(air_inst_index));
                                const name: Air.NullTerminatedString = switch (air_inst.tag) {
                                    else => unreachable,
                                    .arg => air_inst.data.arg.name,
                                    .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline => @enumFromInt(air_inst.data.pl_op.payload),
                                };
                                try dw.genLocalDebugInfo(
                                    switch (air_inst.tag) {
                                        else => unreachable,
                                        .arg, .dbg_arg_inline => .local_arg,
                                        .dbg_var_ptr, .dbg_var_val => .local_var,
                                    },
                                    name.toSlice(emit.air),
                                    switch (air_inst.tag) {
                                        else => unreachable,
                                        .arg => emit.air.typeOfIndex(air_inst_index, ip),
                                        .dbg_var_ptr => emit.air.typeOf(air_inst.data.pl_op.operand, ip).childTypeIp(ip),
                                        .dbg_var_val, .dbg_arg_inline => emit.air.typeOf(air_inst.data.pl_op.operand, ip),
                                    },
                                    loc,
                                );
                            },
                            .plan9 => {},
                            .none => {},
                        }
                    },
                    .pseudo_dbg_var_args_none => {
                        switch (emit.debug_output) {
                            .dwarf => |dw| try dw.genVarArgsDebugInfo(),
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
    /// Offset of the relocation within the instruction.
    source_offset: u32,
    /// Target of the relocation.
    target: Mir.Inst.Index,
    /// Offset from the target instruction.
    target_offset: i32,
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
        const disp = @as(i64, @intCast(target)) - @as(i64, @intCast(reloc.source + reloc.length)) + reloc.target_offset;
        std.mem.writeInt(i32, emit.code.items[reloc.source_offset..][0..4], @intCast(disp), .little);
    }
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) Error!void {
    const delta_line = @as(i33, line) - @as(i33, emit.prev_di_line);
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    log.debug("  (advance pc={d} and line={d})", .{ delta_pc, delta_line });
    switch (emit.debug_output) {
        .dwarf => |dw| {
            if (column != emit.prev_di_column) try dw.setColumn(column);
            try dw.advancePCAndLine(delta_line, delta_pc);
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes

            // increasing the line number
            try link.File.Plan9.changeLine(&dbg_out.dbg_line, @intCast(delta_line));
            // increasing the pc
            const d_pc_p9 = @as(i64, @intCast(delta_pc)) - dbg_out.pc_quanta;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one pc quanta
                var diff = @divExact(d_pc_p9, dbg_out.pc_quanta) - dbg_out.pc_quanta;
                while (diff > 0) {
                    if (diff < 64) {
                        try dbg_out.dbg_line.append(@intCast(diff + 128));
                        diff = 0;
                    } else {
                        try dbg_out.dbg_line.append(@intCast(64 + 128));
                        diff -= 64;
                    }
                }
                if (dbg_out.pcop_change_index) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index = @intCast(dbg_out.dbg_line.items.len - 1);
            } else if (d_pc_p9 == 0) {
                // we don't need to do anything, because adding the pc quanta does it for us
            } else unreachable;
            if (dbg_out.start_line == null)
                dbg_out.start_line = emit.prev_di_line;
            dbg_out.end_line = line;
            // only do this if the pc changed
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .none => {},
    }
}

const bits = @import("bits.zig");
const link = @import("../../link.zig");
const log = std.log.scoped(.emit);
const std = @import("std");

const Air = @import("../../Air.zig");
const Emit = @This();
const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
