//! This file contains the functionality for emitting x86_64 MIR as machine code

lower: Lower,
bin_file: *link.File,
pt: Zcu.PerThread,
pic: bool,
atom_index: u32,
debug_output: link.File.DebugInfoOutput,
code: *std.ArrayListUnmanaged(u8),

prev_di_loc: Loc,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

code_offset_mapping: std.ArrayListUnmanaged(u32),
relocs: std.ArrayListUnmanaged(Reloc),
table_relocs: std.ArrayListUnmanaged(TableReloc),

pub const Error = Lower.Error || error{
    EmitFail,
} || link.File.UpdateDebugInfoError;

pub fn emitMir(emit: *Emit) Error!void {
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;
    try emit.code_offset_mapping.resize(gpa, emit.lower.mir.instructions.len);
    emit.relocs.clearRetainingCapacity();
    emit.table_relocs.clearRetainingCapacity();
    var local_index: usize = 0;
    for (0..emit.lower.mir.instructions.len) |mir_i| {
        const mir_index: Mir.Inst.Index = @intCast(mir_i);
        emit.code_offset_mapping.items[mir_index] = @intCast(emit.code.items.len);
        const lowered = try emit.lower.lowerMir(mir_index);
        var lowered_relocs = lowered.relocs;
        lowered_inst: for (lowered.insts, 0..) |lowered_inst, lowered_index| {
            if (lowered_inst.prefix == .directive) {
                const start_offset: u32 = @intCast(emit.code.items.len);
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
            var reloc_info_buf: [2]RelocInfo = undefined;
            var reloc_info_index: usize = 0;
            while (lowered_relocs.len > 0 and
                lowered_relocs[0].lowered_inst_index == lowered_index) : ({
                lowered_relocs = lowered_relocs[1..];
                reloc_info_index += 1;
            }) reloc_info_buf[reloc_info_index] = .{
                .op_index = lowered_relocs[0].op_index,
                .off = lowered_relocs[0].off,
                .target = target: switch (lowered_relocs[0].target) {
                    .inst => |inst| .{ .index = inst, .is_extern = false, .type = .inst },
                    .table => .{ .index = undefined, .is_extern = false, .type = .table },
                    .nav => |nav| {
                        const sym_index = switch (try codegen.genNavRef(
                            emit.bin_file,
                            emit.pt,
                            emit.lower.src_loc,
                            nav,
                            emit.lower.target,
                        )) {
                            .sym_index => |sym_index| sym_index,
                            .fail => |em| {
                                assert(emit.lower.err_msg == null);
                                emit.lower.err_msg = em;
                                return error.EmitFail;
                            },
                        };
                        const ip = &emit.pt.zcu.intern_pool;
                        break :target switch (ip.getNav(nav).status) {
                            .unresolved => unreachable,
                            .type_resolved => |type_resolved| .{
                                .index = sym_index,
                                .is_extern = false,
                                .type = if (type_resolved.is_threadlocal and comp.config.any_non_single_threaded) .tlv else .symbol,
                            },
                            .fully_resolved => |fully_resolved| switch (ip.indexToKey(fully_resolved.val)) {
                                .@"extern" => |@"extern"| .{
                                    .index = sym_index,
                                    .is_extern = switch (@"extern".visibility) {
                                        .default => true,
                                        .hidden, .protected => false,
                                    },
                                    .type = if (@"extern".is_threadlocal and comp.config.any_non_single_threaded) .tlv else .symbol,
                                    .force_pcrel_direct = switch (@"extern".relocation) {
                                        .any => false,
                                        .pcrel => true,
                                    },
                                },
                                .variable => |variable| .{
                                    .index = sym_index,
                                    .is_extern = false,
                                    .type = if (variable.is_threadlocal and comp.config.any_non_single_threaded) .tlv else .symbol,
                                },
                                else => .{ .index = sym_index, .is_extern = false, .type = .symbol },
                            },
                        };
                    },
                    .uav => |uav| .{
                        .index = switch (try emit.bin_file.lowerUav(
                            emit.pt,
                            uav.val,
                            Type.fromInterned(uav.orig_ty).ptrAlignment(emit.pt.zcu),
                            emit.lower.src_loc,
                        )) {
                            .sym_index => |sym_index| sym_index,
                            .fail => |em| {
                                assert(emit.lower.err_msg == null);
                                emit.lower.err_msg = em;
                                return error.EmitFail;
                            },
                        },
                        .is_extern = false,
                        .type = .symbol,
                    },
                    .lazy_sym => |lazy_sym| .{
                        .index = if (emit.bin_file.cast(.elf)) |elf_file|
                            elf_file.zigObjectPtr().?.getOrCreateMetadataForLazySymbol(elf_file, emit.pt, lazy_sym) catch |err|
                                return emit.fail("{s} creating lazy symbol", .{@errorName(err)})
                        else if (emit.bin_file.cast(.macho)) |macho_file|
                            macho_file.getZigObject().?.getOrCreateMetadataForLazySymbol(macho_file, emit.pt, lazy_sym) catch |err|
                                return emit.fail("{s} creating lazy symbol", .{@errorName(err)})
                        else if (emit.bin_file.cast(.coff)) |coff_file| sym_index: {
                            const atom = coff_file.getOrCreateAtomForLazySymbol(emit.pt, lazy_sym) catch |err|
                                return emit.fail("{s} creating lazy symbol", .{@errorName(err)});
                            break :sym_index coff_file.getAtom(atom).getSymbolIndex().?;
                        } else if (emit.bin_file.cast(.plan9)) |p9_file|
                            p9_file.getOrCreateAtomForLazySymbol(emit.pt, lazy_sym) catch |err|
                                return emit.fail("{s} creating lazy symbol", .{@errorName(err)})
                        else
                            return emit.fail("lazy symbols unimplemented for {s}", .{@tagName(emit.bin_file.tag)}),
                        .is_extern = false,
                        .type = .symbol,
                    },
                    .extern_func => |extern_func| .{
                        .index = if (emit.bin_file.cast(.elf)) |elf_file|
                            try elf_file.getGlobalSymbol(extern_func.toSlice(&emit.lower.mir).?, null)
                        else if (emit.bin_file.cast(.macho)) |macho_file|
                            try macho_file.getGlobalSymbol(extern_func.toSlice(&emit.lower.mir).?, null)
                        else if (emit.bin_file.cast(.coff)) |coff_file|
                            try coff_file.getGlobalSymbol(extern_func.toSlice(&emit.lower.mir).?, "compiler_rt")
                        else
                            return emit.fail("external symbols unimplemented for {s}", .{@tagName(emit.bin_file.tag)}),
                        .is_extern = true,
                        .type = .symbol,
                    },
                },
            };
            const reloc_info = reloc_info_buf[0..reloc_info_index];
            for (reloc_info) |*reloc| switch (reloc.target.type) {
                .inst, .table => {},
                .symbol => {
                    switch (lowered_inst.encoding.mnemonic) {
                        .call => {
                            reloc.target.type = .branch;
                            if (emit.bin_file.cast(.coff)) |_| try emit.encodeInst(try .new(.none, .call, &.{
                                .{ .mem = .initRip(.ptr, 0) },
                            }, emit.lower.target), reloc_info) else try emit.encodeInst(lowered_inst, reloc_info);
                            continue :lowered_inst;
                        },
                        else => {},
                    }
                    if (emit.bin_file.cast(.elf)) |_| {
                        if (!emit.pic) switch (lowered_inst.encoding.mnemonic) {
                            .lea => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .imm = .s(0) },
                            }, emit.lower.target), reloc_info),
                            .mov => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initSib(lowered_inst.ops[reloc.op_index].mem.sib.ptr_size, .{
                                    .base = .{ .reg = .ds },
                                }) },
                            }, emit.lower.target), reloc_info),
                            else => unreachable,
                        } else if (reloc.target.is_extern) switch (lowered_inst.encoding.mnemonic) {
                            .lea => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(.ptr, 0) },
                            }, emit.lower.target), reloc_info),
                            .mov => {
                                try emit.encodeInst(try .new(.none, .mov, &.{
                                    lowered_inst.ops[0],
                                    .{ .mem = .initRip(.ptr, 0) },
                                }, emit.lower.target), reloc_info);
                                try emit.encodeInst(try .new(.none, .mov, &.{
                                    lowered_inst.ops[0],
                                    .{ .mem = .initSib(lowered_inst.ops[reloc.op_index].mem.sib.ptr_size, .{ .base = .{
                                        .reg = lowered_inst.ops[0].reg.to64(),
                                    } }) },
                                }, emit.lower.target), &.{});
                            },
                            else => unreachable,
                        } else switch (lowered_inst.encoding.mnemonic) {
                            .lea => try emit.encodeInst(try .new(.none, .lea, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(.none, 0) },
                            }, emit.lower.target), reloc_info),
                            .mov => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(lowered_inst.ops[reloc.op_index].mem.sib.ptr_size, 0) },
                            }, emit.lower.target), reloc_info),
                            else => unreachable,
                        }
                    } else if (emit.bin_file.cast(.macho)) |_| {
                        if (reloc.target.is_extern) switch (lowered_inst.encoding.mnemonic) {
                            .lea => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(.ptr, 0) },
                            }, emit.lower.target), reloc_info),
                            .mov => {
                                try emit.encodeInst(try .new(.none, .mov, &.{
                                    lowered_inst.ops[0],
                                    .{ .mem = .initRip(.ptr, 0) },
                                }, emit.lower.target), reloc_info);
                                try emit.encodeInst(try .new(.none, .mov, &.{
                                    lowered_inst.ops[0],
                                    .{ .mem = .initSib(lowered_inst.ops[reloc.op_index].mem.sib.ptr_size, .{ .base = .{
                                        .reg = lowered_inst.ops[0].reg.to64(),
                                    } }) },
                                }, emit.lower.target), &.{});
                            },
                            else => unreachable,
                        } else switch (lowered_inst.encoding.mnemonic) {
                            .lea => try emit.encodeInst(try .new(.none, .lea, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(.none, 0) },
                            }, emit.lower.target), reloc_info),
                            .mov => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(lowered_inst.ops[reloc.op_index].mem.sib.ptr_size, 0) },
                            }, emit.lower.target), reloc_info),
                            else => unreachable,
                        }
                    } else if (emit.bin_file.cast(.coff)) |_| {
                        if (reloc.target.is_extern) switch (lowered_inst.encoding.mnemonic) {
                            .lea => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(.ptr, 0) },
                            }, emit.lower.target), reloc_info),
                            .mov => {
                                const dst_reg = lowered_inst.ops[0].reg.to64();
                                try emit.encodeInst(try .new(.none, .mov, &.{
                                    .{ .reg = dst_reg },
                                    .{ .mem = .initRip(.ptr, 0) },
                                }, emit.lower.target), reloc_info);
                                try emit.encodeInst(try .new(.none, .mov, &.{
                                    lowered_inst.ops[0],
                                    .{ .mem = .initSib(lowered_inst.ops[reloc.op_index].mem.sib.ptr_size, .{ .base = .{
                                        .reg = dst_reg,
                                    } }) },
                                }, emit.lower.target), &.{});
                            },
                            else => unreachable,
                        } else switch (lowered_inst.encoding.mnemonic) {
                            .lea => try emit.encodeInst(try .new(.none, .lea, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(.none, 0) },
                            }, emit.lower.target), reloc_info),
                            .mov => try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initRip(lowered_inst.ops[reloc.op_index].mem.sib.ptr_size, 0) },
                            }, emit.lower.target), reloc_info),
                            else => unreachable,
                        }
                    } else return emit.fail("TODO implement relocs for {s}", .{
                        @tagName(emit.bin_file.tag),
                    });
                    continue :lowered_inst;
                },
                .branch, .tls => unreachable,
                .tlv => {
                    if (emit.bin_file.cast(.elf)) |elf_file| {
                        // TODO handle extern TLS vars, i.e., emit GD model
                        if (emit.pic) switch (lowered_inst.encoding.mnemonic) {
                            .lea, .mov => {
                                // Here, we currently assume local dynamic TLS vars, and so
                                // we emit LD model.
                                try emit.encodeInst(try .new(.none, .lea, &.{
                                    .{ .reg = .rdi },
                                    .{ .mem = .initRip(.none, 0) },
                                }, emit.lower.target), &.{.{
                                    .op_index = 1,
                                    .target = .{
                                        .index = reloc.target.index,
                                        .is_extern = false,
                                        .type = .tls,
                                    },
                                }});
                                try emit.encodeInst(try .new(.none, .call, &.{
                                    .{ .imm = .s(0) },
                                }, emit.lower.target), &.{.{
                                    .op_index = 0,
                                    .target = .{
                                        .index = try elf_file.getGlobalSymbol("__tls_get_addr", null),
                                        .is_extern = true,
                                        .type = .branch,
                                    },
                                }});
                                try emit.encodeInst(try .new(.none, lowered_inst.encoding.mnemonic, &.{
                                    lowered_inst.ops[0],
                                    .{ .mem = .initSib(.none, .{
                                        .base = .{ .reg = .rax },
                                        .disp = std.math.minInt(i32),
                                    }) },
                                }, emit.lower.target), reloc_info);
                            },
                            else => unreachable,
                        } else switch (lowered_inst.encoding.mnemonic) {
                            .lea, .mov => {
                                // Since we are linking statically, we emit LE model directly.
                                try emit.encodeInst(try .new(.none, .mov, &.{
                                    .{ .reg = .rax },
                                    .{ .mem = .initSib(.qword, .{ .base = .{ .reg = .fs } }) },
                                }, emit.lower.target), &.{});
                                try emit.encodeInst(try .new(.none, lowered_inst.encoding.mnemonic, &.{
                                    lowered_inst.ops[0],
                                    .{ .mem = .initSib(.none, .{
                                        .base = .{ .reg = .rax },
                                        .disp = std.math.minInt(i32),
                                    }) },
                                }, emit.lower.target), reloc_info);
                            },
                            else => unreachable,
                        }
                    } else if (emit.bin_file.cast(.macho)) |_| switch (lowered_inst.encoding.mnemonic) {
                        .lea => {
                            try emit.encodeInst(try .new(.none, .mov, &.{
                                .{ .reg = .rdi },
                                .{ .mem = .initRip(.ptr, 0) },
                            }, emit.lower.target), reloc_info);
                            try emit.encodeInst(try .new(.none, .call, &.{
                                .{ .mem = .initSib(.qword, .{ .base = .{ .reg = .rdi } }) },
                            }, emit.lower.target), &.{});
                            try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .reg = .rax },
                            }, emit.lower.target), &.{});
                        },
                        .mov => {
                            try emit.encodeInst(try .new(.none, .mov, &.{
                                .{ .reg = .rdi },
                                .{ .mem = .initRip(.ptr, 0) },
                            }, emit.lower.target), reloc_info);
                            try emit.encodeInst(try .new(.none, .call, &.{
                                .{ .mem = .initSib(.qword, .{ .base = .{ .reg = .rdi } }) },
                            }, emit.lower.target), &.{});
                            try emit.encodeInst(try .new(.none, .mov, &.{
                                lowered_inst.ops[0],
                                .{ .mem = .initSib(.qword, .{ .base = .{ .reg = .rax } }) },
                            }, emit.lower.target), &.{});
                        },
                        else => unreachable,
                    } else return emit.fail("TODO implement relocs for {s}", .{
                        @tagName(emit.bin_file.tag),
                    });
                    continue :lowered_inst;
                },
            };
            try emit.encodeInst(lowered_inst, reloc_info);
        }
        assert(lowered_relocs.len == 0);

        if (lowered.insts.len == 0) {
            const mir_inst = emit.lower.mir.instructions.get(mir_index);
            switch (mir_inst.tag) {
                else => unreachable,
                .pseudo => switch (mir_inst.ops) {
                    else => unreachable,
                    .pseudo_dbg_prologue_end_none => switch (emit.debug_output) {
                        .dwarf => |dwarf| try dwarf.setPrologueEnd(),
                        .plan9 => {},
                        .none => {},
                    },
                    .pseudo_dbg_line_stmt_line_column => try emit.dbgAdvancePCAndLine(.{
                        .line = mir_inst.data.line_column.line,
                        .column = mir_inst.data.line_column.column,
                        .is_stmt = true,
                    }),
                    .pseudo_dbg_line_line_column => try emit.dbgAdvancePCAndLine(.{
                        .line = mir_inst.data.line_column.line,
                        .column = mir_inst.data.line_column.column,
                        .is_stmt = false,
                    }),
                    .pseudo_dbg_epilogue_begin_none => switch (emit.debug_output) {
                        .dwarf => |dwarf| {
                            try dwarf.setEpilogueBegin();
                            log.debug("mirDbgEpilogueBegin (line={d}, col={d})", .{
                                emit.prev_di_loc.line, emit.prev_di_loc.column,
                            });
                            try emit.dbgAdvancePCAndLine(emit.prev_di_loc);
                        },
                        .plan9 => {},
                        .none => {},
                    },
                    .pseudo_dbg_enter_block_none => switch (emit.debug_output) {
                        .dwarf => |dwarf| {
                            log.debug("mirDbgEnterBlock (line={d}, col={d})", .{
                                emit.prev_di_loc.line, emit.prev_di_loc.column,
                            });
                            try dwarf.enterBlock(emit.code.items.len);
                        },
                        .plan9 => {},
                        .none => {},
                    },
                    .pseudo_dbg_leave_block_none => switch (emit.debug_output) {
                        .dwarf => |dwarf| {
                            log.debug("mirDbgLeaveBlock (line={d}, col={d})", .{
                                emit.prev_di_loc.line, emit.prev_di_loc.column,
                            });
                            try dwarf.leaveBlock(emit.code.items.len);
                        },
                        .plan9 => {},
                        .none => {},
                    },
                    .pseudo_dbg_enter_inline_func => switch (emit.debug_output) {
                        .dwarf => |dwarf| {
                            log.debug("mirDbgEnterInline (line={d}, col={d})", .{
                                emit.prev_di_loc.line, emit.prev_di_loc.column,
                            });
                            try dwarf.enterInlineFunc(mir_inst.data.ip_index, emit.code.items.len, emit.prev_di_loc.line, emit.prev_di_loc.column);
                        },
                        .plan9 => {},
                        .none => {},
                    },
                    .pseudo_dbg_leave_inline_func => switch (emit.debug_output) {
                        .dwarf => |dwarf| {
                            log.debug("mirDbgLeaveInline (line={d}, col={d})", .{
                                emit.prev_di_loc.line, emit.prev_di_loc.column,
                            });
                            try dwarf.leaveInlineFunc(mir_inst.data.ip_index, emit.code.items.len);
                        },
                        .plan9 => {},
                        .none => {},
                    },
                    .pseudo_dbg_arg_none,
                    .pseudo_dbg_arg_i_s,
                    .pseudo_dbg_arg_i_u,
                    .pseudo_dbg_arg_i_64,
                    .pseudo_dbg_arg_ro,
                    .pseudo_dbg_arg_fa,
                    .pseudo_dbg_arg_m,
                    .pseudo_dbg_var_none,
                    .pseudo_dbg_var_i_s,
                    .pseudo_dbg_var_i_u,
                    .pseudo_dbg_var_i_64,
                    .pseudo_dbg_var_ro,
                    .pseudo_dbg_var_fa,
                    .pseudo_dbg_var_m,
                    => switch (emit.debug_output) {
                        .dwarf => |dwarf| {
                            var loc_buf: [2]link.File.Dwarf.Loc = undefined;
                            const loc: link.File.Dwarf.Loc = loc: switch (mir_inst.ops) {
                                else => unreachable,
                                .pseudo_dbg_arg_none, .pseudo_dbg_var_none => .empty,
                                .pseudo_dbg_arg_i_s,
                                .pseudo_dbg_arg_i_u,
                                .pseudo_dbg_var_i_s,
                                .pseudo_dbg_var_i_u,
                                => .{ .stack_value = stack_value: {
                                    loc_buf[0] = switch (emit.lower.imm(mir_inst.ops, mir_inst.data.i.i)) {
                                        .signed => |s| .{ .consts = s },
                                        .unsigned => |u| .{ .constu = u },
                                    };
                                    break :stack_value &loc_buf[0];
                                } },
                                .pseudo_dbg_arg_i_64, .pseudo_dbg_var_i_64 => .{ .stack_value = stack_value: {
                                    loc_buf[0] = .{ .constu = mir_inst.data.i64 };
                                    break :stack_value &loc_buf[0];
                                } },
                                .pseudo_dbg_arg_fa, .pseudo_dbg_var_fa => {
                                    const reg_off = emit.lower.mir.resolveFrameAddr(mir_inst.data.fa);
                                    break :loc .{ .plus = .{
                                        reg: {
                                            loc_buf[0] = .{ .breg = reg_off.reg.dwarfNum() };
                                            break :reg &loc_buf[0];
                                        },
                                        off: {
                                            loc_buf[1] = .{ .consts = reg_off.off };
                                            break :off &loc_buf[1];
                                        },
                                    } };
                                },
                                .pseudo_dbg_arg_m, .pseudo_dbg_var_m => {
                                    const mem = emit.lower.mir.resolveMemoryExtra(mir_inst.data.x.payload).decode();
                                    break :loc .{ .plus = .{
                                        base: {
                                            loc_buf[0] = switch (mem.base()) {
                                                .none => .{ .constu = 0 },
                                                .reg => |reg| .{ .breg = reg.dwarfNum() },
                                                .frame, .table, .rip_inst => unreachable,
                                                .nav => |nav| .{ .addr_reloc = switch (codegen.genNavRef(
                                                    emit.bin_file,
                                                    emit.pt,
                                                    emit.lower.src_loc,
                                                    nav,
                                                    emit.lower.target,
                                                ) catch |err| switch (err) {
                                                    error.CodegenFail,
                                                    => return emit.fail("unable to codegen: {s}", .{@errorName(err)}),
                                                    else => |e| return e,
                                                }) {
                                                    .sym_index => |sym_index| sym_index,
                                                    .fail => |em| {
                                                        assert(emit.lower.err_msg == null);
                                                        emit.lower.err_msg = em;
                                                        return error.EmitFail;
                                                    },
                                                } },
                                                .uav => |uav| .{ .addr_reloc = switch (try emit.bin_file.lowerUav(
                                                    emit.pt,
                                                    uav.val,
                                                    Type.fromInterned(uav.orig_ty).ptrAlignment(emit.pt.zcu),
                                                    emit.lower.src_loc,
                                                )) {
                                                    .sym_index => |sym_index| sym_index,
                                                    .fail => |em| {
                                                        assert(emit.lower.err_msg == null);
                                                        emit.lower.err_msg = em;
                                                        return error.EmitFail;
                                                    },
                                                } },
                                                .lazy_sym, .extern_func => unreachable,
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
                                    } };
                                },
                            };

                            const local = &emit.lower.mir.locals[local_index];
                            local_index += 1;
                            try dwarf.genLocalVarDebugInfo(
                                switch (mir_inst.ops) {
                                    else => unreachable,
                                    .pseudo_dbg_arg_none,
                                    .pseudo_dbg_arg_i_s,
                                    .pseudo_dbg_arg_i_u,
                                    .pseudo_dbg_arg_i_64,
                                    .pseudo_dbg_arg_ro,
                                    .pseudo_dbg_arg_fa,
                                    .pseudo_dbg_arg_m,
                                    .pseudo_dbg_arg_val,
                                    => .arg,
                                    .pseudo_dbg_var_none,
                                    .pseudo_dbg_var_i_s,
                                    .pseudo_dbg_var_i_u,
                                    .pseudo_dbg_var_i_64,
                                    .pseudo_dbg_var_ro,
                                    .pseudo_dbg_var_fa,
                                    .pseudo_dbg_var_m,
                                    .pseudo_dbg_var_val,
                                    => .local_var,
                                },
                                local.name.toSlice(&emit.lower.mir),
                                .fromInterned(local.type),
                                loc,
                            );
                        },
                        .plan9, .none => local_index += 1,
                    },
                    .pseudo_dbg_arg_val, .pseudo_dbg_var_val => switch (emit.debug_output) {
                        .dwarf => |dwarf| {
                            const local = &emit.lower.mir.locals[local_index];
                            local_index += 1;
                            try dwarf.genLocalConstDebugInfo(
                                emit.lower.src_loc,
                                switch (mir_inst.ops) {
                                    else => unreachable,
                                    .pseudo_dbg_arg_val => .comptime_arg,
                                    .pseudo_dbg_var_val => .local_const,
                                },
                                local.name.toSlice(&emit.lower.mir),
                                .fromInterned(mir_inst.data.ip_index),
                            );
                        },
                        .plan9, .none => local_index += 1,
                    },
                    .pseudo_dbg_var_args_none => switch (emit.debug_output) {
                        .dwarf => |dwarf| try dwarf.genVarArgsDebugInfo(),
                        .plan9 => {},
                        .none => {},
                    },
                    .pseudo_dead_none => {},
                },
            }
        }
    }
    for (emit.relocs.items) |reloc| {
        const target = emit.code_offset_mapping.items[reloc.target];
        const disp = @as(i64, @intCast(target)) - @as(i64, @intCast(reloc.inst_offset + reloc.inst_length)) + reloc.target_offset;
        const inst_bytes = emit.code.items[reloc.inst_offset..][0..reloc.inst_length];
        switch (reloc.source_length) {
            else => unreachable,
            inline 1, 4 => |source_length| std.mem.writeInt(
                @Type(.{ .int = .{ .signedness = .signed, .bits = @as(u16, 8) * source_length } }),
                inst_bytes[reloc.source_offset..][0..source_length],
                @intCast(disp),
                .little,
            ),
        }
    }
    if (emit.lower.mir.table.len > 0) {
        if (emit.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(emit.atom_index).atom(elf_file).?;

            const ptr_size = @divExact(emit.lower.target.ptrBitWidth(), 8);
            var table_offset = std.mem.alignForward(u32, @intCast(emit.code.items.len), ptr_size);
            for (emit.table_relocs.items) |table_reloc| try atom.addReloc(gpa, .{
                .r_offset = table_reloc.source_offset,
                .r_info = @as(u64, emit.atom_index) << 32 | @intFromEnum(std.elf.R_X86_64.@"32"),
                .r_addend = @as(i64, table_offset) + table_reloc.target_offset,
            }, zo);
            for (emit.lower.mir.table) |entry| {
                try atom.addReloc(gpa, .{
                    .r_offset = table_offset,
                    .r_info = @as(u64, emit.atom_index) << 32 | @intFromEnum(std.elf.R_X86_64.@"64"),
                    .r_addend = emit.code_offset_mapping.items[entry],
                }, zo);
                table_offset += ptr_size;
            }
            try emit.code.appendNTimes(gpa, 0, table_offset - emit.code.items.len);
        } else unreachable;
    }
}

pub fn deinit(emit: *Emit) void {
    const gpa = emit.bin_file.comp.gpa;
    emit.code_offset_mapping.deinit(gpa);
    emit.relocs.deinit(gpa);
    emit.table_relocs.deinit(gpa);
    emit.* = undefined;
}

const RelocInfo = struct {
    op_index: Lower.InstOpIndex,
    off: i32 = 0,
    target: Target,

    const Target = struct {
        index: u32,
        is_extern: bool,
        type: Target.Type,
        force_pcrel_direct: bool = false,

        const Type = enum { inst, table, symbol, branch, tls, tlv };
    };
};

fn encodeInst(emit: *Emit, lowered_inst: Instruction, reloc_info: []const RelocInfo) Error!void {
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;
    const start_offset: u32 = @intCast(emit.code.items.len);
    try lowered_inst.encode(emit.code.writer(gpa), .{});
    const end_offset: u32 = @intCast(emit.code.items.len);
    for (reloc_info) |reloc| switch (reloc.target.type) {
        .inst => {
            const inst_length: u4 = @intCast(end_offset - start_offset);
            const reloc_offset, const reloc_length = reloc_offset_length: {
                var reloc_offset = inst_length;
                var op_index: usize = lowered_inst.ops.len;
                while (true) {
                    op_index -= 1;
                    const op = lowered_inst.encoding.data.ops[op_index];
                    if (op == .none) continue;
                    const is_mem = op.isMemory();
                    const enc_length: u4 = if (is_mem) switch (lowered_inst.ops[op_index].mem.sib.base) {
                        .rip_inst => 4,
                        else => unreachable,
                    } else @intCast(std.math.divCeil(u7, @intCast(op.immBitSize()), 8) catch unreachable);
                    reloc_offset -= enc_length;
                    if (op_index == reloc.op_index) break :reloc_offset_length .{ reloc_offset, enc_length };
                    assert(!is_mem);
                }
            };
            try emit.relocs.append(emit.lower.allocator, .{
                .inst_offset = start_offset,
                .inst_length = inst_length,
                .source_offset = reloc_offset,
                .source_length = reloc_length,
                .target = reloc.target.index,
                .target_offset = reloc.off,
            });
        },
        .table => try emit.table_relocs.append(emit.lower.allocator, .{
            .source_offset = end_offset - 4,
            .target_offset = reloc.off,
        }),
        .symbol => if (emit.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(emit.atom_index).atom(elf_file).?;
            const r_type: std.elf.R_X86_64 = if (!emit.pic)
                .@"32"
            else if (reloc.target.is_extern and !reloc.target.force_pcrel_direct)
                .GOTPCREL
            else
                .PC32;
            try atom.addReloc(gpa, .{
                .r_offset = end_offset - 4,
                .r_info = @as(u64, reloc.target.index) << 32 | @intFromEnum(r_type),
                .r_addend = if (emit.pic) reloc.off - 4 else reloc.off,
            }, zo);
        } else if (emit.bin_file.cast(.macho)) |macho_file| {
            const zo = macho_file.getZigObject().?;
            const atom = zo.symbols.items[emit.atom_index].getAtom(macho_file).?;
            try atom.addReloc(macho_file, .{
                .tag = .@"extern",
                .offset = end_offset - 4,
                .target = reloc.target.index,
                .addend = reloc.off,
                .type = if (reloc.target.is_extern and !reloc.target.force_pcrel_direct) .got_load else .signed,
                .meta = .{
                    .pcrel = true,
                    .has_subtractor = false,
                    .length = 2,
                    .symbolnum = @intCast(reloc.target.index),
                },
            });
        } else if (emit.bin_file.cast(.coff)) |coff_file| {
            const atom_index = coff_file.getAtomIndexForSymbol(
                .{ .sym_index = emit.atom_index, .file = null },
            ).?;
            try coff_file.addRelocation(atom_index, .{
                .type = if (reloc.target.is_extern) .got else .direct,
                .target = if (reloc.target.is_extern)
                    coff_file.getGlobalByIndex(reloc.target.index)
                else
                    .{ .sym_index = reloc.target.index, .file = null },
                .offset = end_offset - 4,
                .addend = @intCast(reloc.off),
                .pcrel = true,
                .length = 2,
            });
        } else unreachable,
        .branch => if (emit.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(emit.atom_index).atom(elf_file).?;
            const r_type: std.elf.R_X86_64 = .PLT32;
            try atom.addReloc(gpa, .{
                .r_offset = end_offset - 4,
                .r_info = @as(u64, reloc.target.index) << 32 | @intFromEnum(r_type),
                .r_addend = reloc.off - 4,
            }, zo);
        } else if (emit.bin_file.cast(.macho)) |macho_file| {
            const zo = macho_file.getZigObject().?;
            const atom = zo.symbols.items[emit.atom_index].getAtom(macho_file).?;
            try atom.addReloc(macho_file, .{
                .tag = .@"extern",
                .offset = end_offset - 4,
                .target = reloc.target.index,
                .addend = reloc.off,
                .type = .branch,
                .meta = .{
                    .pcrel = true,
                    .has_subtractor = false,
                    .length = 2,
                    .symbolnum = @intCast(reloc.target.index),
                },
            });
        } else if (emit.bin_file.cast(.coff)) |coff_file| {
            const atom_index = coff_file.getAtomIndexForSymbol(
                .{ .sym_index = emit.atom_index, .file = null },
            ).?;
            try coff_file.addRelocation(atom_index, .{
                .type = if (reloc.target.is_extern) .import else .got,
                .target = if (reloc.target.is_extern)
                    coff_file.getGlobalByIndex(reloc.target.index)
                else
                    .{ .sym_index = reloc.target.index, .file = null },
                .offset = end_offset - 4,
                .addend = @intCast(reloc.off),
                .pcrel = true,
                .length = 2,
            });
        } else return emit.fail("TODO implement {s} reloc for {s}", .{
            @tagName(reloc.target.type), @tagName(emit.bin_file.tag),
        }),
        .tls => if (emit.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(emit.atom_index).atom(elf_file).?;
            const r_type: std.elf.R_X86_64 = if (emit.pic) .TLSLD else unreachable;
            try atom.addReloc(gpa, .{
                .r_offset = end_offset - 4,
                .r_info = @as(u64, reloc.target.index) << 32 | @intFromEnum(r_type),
                .r_addend = reloc.off - 4,
            }, zo);
        } else return emit.fail("TODO implement {s} reloc for {s}", .{
            @tagName(reloc.target.type), @tagName(emit.bin_file.tag),
        }),
        .tlv => if (emit.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(emit.atom_index).atom(elf_file).?;
            const r_type: std.elf.R_X86_64 = if (emit.pic) .DTPOFF32 else .TPOFF32;
            try atom.addReloc(gpa, .{
                .r_offset = end_offset - 4,
                .r_info = @as(u64, reloc.target.index) << 32 | @intFromEnum(r_type),
                .r_addend = reloc.off,
            }, zo);
        } else if (emit.bin_file.cast(.macho)) |macho_file| {
            const zo = macho_file.getZigObject().?;
            const atom = zo.symbols.items[emit.atom_index].getAtom(macho_file).?;
            try atom.addReloc(macho_file, .{
                .tag = .@"extern",
                .offset = end_offset - 4,
                .target = reloc.target.index,
                .addend = reloc.off,
                .type = .tlv,
                .meta = .{
                    .pcrel = true,
                    .has_subtractor = false,
                    .length = 2,
                    .symbolnum = @intCast(reloc.target.index),
                },
            });
        } else return emit.fail("TODO implement {s} reloc for {s}", .{
            @tagName(reloc.target.type), @tagName(emit.bin_file.tag),
        }),
    };
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) Error {
    return switch (emit.lower.fail(format, args)) {
        error.LowerFail => error.EmitFail,
        else => |e| e,
    };
}

const Reloc = struct {
    /// Offset of the instruction.
    inst_offset: u32,
    /// Length of the instruction.
    inst_length: u4,
    /// Offset of the relocation within the instruction.
    source_offset: u4,
    /// Length of the relocation.
    source_length: u4,
    /// Target of the relocation.
    target: Mir.Inst.Index,
    /// Offset from the target.
    target_offset: i32,
};

const TableReloc = struct {
    /// Offset of the relocation.
    source_offset: u32,
    /// Offset from the start of the table.
    target_offset: i32,
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
                dbg_out.start_line = emit.prev_di_loc.line;
            dbg_out.end_line = loc.line;
            // only do this if the pc changed
            emit.prev_di_loc = loc;
            emit.prev_di_pc = emit.code.items.len;
        },
        .none => {},
    }
}

const assert = std.debug.assert;
const bits = @import("bits.zig");
const codegen = @import("../../codegen.zig");
const Emit = @This();
const encoder = @import("encoder.zig");
const Instruction = encoder.Instruction;
const InternPool = @import("../../InternPool.zig");
const link = @import("../../link.zig");
const log = std.log.scoped(.emit);
const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
const std = @import("std");
const Type = @import("../../Type.zig");
const Zcu = @import("../../Zcu.zig");
