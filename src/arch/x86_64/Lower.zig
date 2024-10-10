//! This file contains the functionality for lowering x86_64 MIR to Instructions

bin_file: *link.File,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
pic: bool,
allocator: std.mem.Allocator,
mir: Mir,
cc: std.builtin.CallingConvention,
err_msg: ?*Zcu.ErrorMsg = null,
src_loc: Zcu.LazySrcLoc,
result_insts_len: u8 = undefined,
result_relocs_len: u8 = undefined,
result_insts: [
    @max(
        1, // non-pseudo instructions
        3, // (ELF only) TLS local dynamic (LD) sequence in PIC mode
        2, // cmovcc: cmovcc \ cmovcc
        3, // setcc: setcc \ setcc \ logicop
        2, // jcc: jcc \ jcc
        pseudo_probe_align_insts,
        pseudo_probe_adjust_unrolled_max_insts,
        pseudo_probe_adjust_setup_insts,
        pseudo_probe_adjust_loop_insts,
        abi.Win64.callee_preserved_regs.len * 2, // push_regs/pop_regs
        abi.SysV.callee_preserved_regs.len * 2, // push_regs/pop_regs
    )
]Instruction = undefined,
result_relocs: [
    @max(
        1, // jmp/jcc/call/mov/lea: jmp/jcc/call/mov/lea
        2, // jcc: jcc \ jcc
        2, // test \ jcc \ probe \ sub \ jmp
        1, // probe \ sub \ jcc
        3, // (ELF only) TLS local dynamic (LD) sequence in PIC mode
    )
]Reloc = undefined,

pub const pseudo_probe_align_insts = 5; // test \ jcc \ probe \ sub \ jmp
pub const pseudo_probe_adjust_unrolled_max_insts =
    pseudo_probe_adjust_setup_insts + pseudo_probe_adjust_loop_insts;
pub const pseudo_probe_adjust_setup_insts = 2; // mov \ sub
pub const pseudo_probe_adjust_loop_insts = 3; // probe \ sub \ jcc

pub const Error = error{
    OutOfMemory,
    LowerFail,
    InvalidInstruction,
    CannotEncode,
};

pub const Reloc = struct {
    lowered_inst_index: u8,
    target: Target,
    off: i32,

    const Target = union(enum) {
        inst: Mir.Inst.Index,
        linker_reloc: u32,
        linker_tlsld: u32,
        linker_dtpoff: u32,
        linker_extern_fn: u32,
        linker_got: u32,
        linker_direct: u32,
        linker_import: u32,
    };
};

const Options = struct { allow_frame_locs: bool };

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, index: Mir.Inst.Index) Error!struct {
    insts: []const Instruction,
    relocs: []const Reloc,
} {
    lower.result_insts = undefined;
    lower.result_relocs = undefined;
    errdefer lower.result_insts = undefined;
    errdefer lower.result_relocs = undefined;
    lower.result_insts_len = 0;
    lower.result_relocs_len = 0;
    defer lower.result_insts_len = undefined;
    defer lower.result_relocs_len = undefined;

    const inst = lower.mir.instructions.get(index);
    switch (inst.tag) {
        else => try lower.generic(inst),
        .pseudo => switch (inst.ops) {
            .pseudo_cmov_z_and_np_rr => {
                assert(inst.data.rr.fixes == ._);
                try lower.emit(.none, .cmovnz, &.{
                    .{ .reg = inst.data.rr.r2 },
                    .{ .reg = inst.data.rr.r1 },
                });
                try lower.emit(.none, .cmovnp, &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_cmov_nz_or_p_rr => {
                assert(inst.data.rr.fixes == ._);
                try lower.emit(.none, .cmovnz, &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
                try lower.emit(.none, .cmovp, &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_cmov_nz_or_p_rm => {
                assert(inst.data.rx.fixes == ._);
                try lower.emit(.none, .cmovnz, &.{
                    .{ .reg = inst.data.rx.r1 },
                    .{ .mem = lower.mem(inst.data.rx.payload) },
                });
                try lower.emit(.none, .cmovp, &.{
                    .{ .reg = inst.data.rx.r1 },
                    .{ .mem = lower.mem(inst.data.rx.payload) },
                });
            },
            .pseudo_set_z_and_np_r => {
                assert(inst.data.rr.fixes == ._);
                try lower.emit(.none, .setz, &.{
                    .{ .reg = inst.data.rr.r1 },
                });
                try lower.emit(.none, .setnp, &.{
                    .{ .reg = inst.data.rr.r2 },
                });
                try lower.emit(.none, .@"and", &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_set_z_and_np_m => {
                assert(inst.data.rx.fixes == ._);
                try lower.emit(.none, .setz, &.{
                    .{ .mem = lower.mem(inst.data.rx.payload) },
                });
                try lower.emit(.none, .setnp, &.{
                    .{ .reg = inst.data.rx.r1 },
                });
                try lower.emit(.none, .@"and", &.{
                    .{ .mem = lower.mem(inst.data.rx.payload) },
                    .{ .reg = inst.data.rx.r1 },
                });
            },
            .pseudo_set_nz_or_p_r => {
                assert(inst.data.rr.fixes == ._);
                try lower.emit(.none, .setnz, &.{
                    .{ .reg = inst.data.rr.r1 },
                });
                try lower.emit(.none, .setp, &.{
                    .{ .reg = inst.data.rr.r2 },
                });
                try lower.emit(.none, .@"or", &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_set_nz_or_p_m => {
                assert(inst.data.rx.fixes == ._);
                try lower.emit(.none, .setnz, &.{
                    .{ .mem = lower.mem(inst.data.rx.payload) },
                });
                try lower.emit(.none, .setp, &.{
                    .{ .reg = inst.data.rx.r1 },
                });
                try lower.emit(.none, .@"or", &.{
                    .{ .mem = lower.mem(inst.data.rx.payload) },
                    .{ .reg = inst.data.rx.r1 },
                });
            },
            .pseudo_j_z_and_np_inst => {
                assert(inst.data.inst.fixes == ._);
                try lower.emit(.none, .jnz, &.{
                    .{ .imm = lower.reloc(.{ .inst = index + 1 }, 0) },
                });
                try lower.emit(.none, .jnp, &.{
                    .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }, 0) },
                });
            },
            .pseudo_j_nz_or_p_inst => {
                assert(inst.data.inst.fixes == ._);
                try lower.emit(.none, .jnz, &.{
                    .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }, 0) },
                });
                try lower.emit(.none, .jp, &.{
                    .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }, 0) },
                });
            },

            .pseudo_probe_align_ri_s => {
                try lower.emit(.none, .@"test", &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .imm = Immediate.s(@bitCast(inst.data.ri.i)) },
                });
                try lower.emit(.none, .jz, &.{
                    .{ .imm = lower.reloc(.{ .inst = index + 1 }, 0) },
                });
                try lower.emit(.none, .lea, &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .mem = Memory.initSib(.qword, .{
                        .base = .{ .reg = inst.data.ri.r1 },
                        .disp = -page_size,
                    }) },
                });
                try lower.emit(.none, .@"test", &.{
                    .{ .mem = Memory.initSib(.dword, .{
                        .base = .{ .reg = inst.data.ri.r1 },
                    }) },
                    .{ .reg = inst.data.ri.r1.to32() },
                });
                try lower.emit(.none, .jmp, &.{
                    .{ .imm = lower.reloc(.{ .inst = index }, 0) },
                });
                assert(lower.result_insts_len == pseudo_probe_align_insts);
            },
            .pseudo_probe_adjust_unrolled_ri_s => {
                var offset = page_size;
                while (offset < @as(i32, @bitCast(inst.data.ri.i))) : (offset += page_size) {
                    try lower.emit(.none, .@"test", &.{
                        .{ .mem = Memory.initSib(.dword, .{
                            .base = .{ .reg = inst.data.ri.r1 },
                            .disp = -offset,
                        }) },
                        .{ .reg = inst.data.ri.r1.to32() },
                    });
                }
                try lower.emit(.none, .sub, &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .imm = Immediate.s(@bitCast(inst.data.ri.i)) },
                });
                assert(lower.result_insts_len <= pseudo_probe_adjust_unrolled_max_insts);
            },
            .pseudo_probe_adjust_setup_rri_s => {
                try lower.emit(.none, .mov, &.{
                    .{ .reg = inst.data.rri.r2.to32() },
                    .{ .imm = Immediate.s(@bitCast(inst.data.rri.i)) },
                });
                try lower.emit(.none, .sub, &.{
                    .{ .reg = inst.data.rri.r1 },
                    .{ .reg = inst.data.rri.r2 },
                });
                assert(lower.result_insts_len == pseudo_probe_adjust_setup_insts);
            },
            .pseudo_probe_adjust_loop_rr => {
                try lower.emit(.none, .@"test", &.{
                    .{ .mem = Memory.initSib(.dword, .{
                        .base = .{ .reg = inst.data.rr.r1 },
                        .scale_index = .{ .scale = 1, .index = inst.data.rr.r2 },
                        .disp = -page_size,
                    }) },
                    .{ .reg = inst.data.rr.r1.to32() },
                });
                try lower.emit(.none, .sub, &.{
                    .{ .reg = inst.data.rr.r2 },
                    .{ .imm = Immediate.s(page_size) },
                });
                try lower.emit(.none, .jae, &.{
                    .{ .imm = lower.reloc(.{ .inst = index }, 0) },
                });
                assert(lower.result_insts_len == pseudo_probe_adjust_loop_insts);
            },
            .pseudo_push_reg_list => try lower.pushPopRegList(.push, inst),
            .pseudo_pop_reg_list => try lower.pushPopRegList(.pop, inst),

            .pseudo_cfi_def_cfa_ri_s => try lower.emit(.directive, .@".cfi_def_cfa", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_def_cfa_register_r => try lower.emit(.directive, .@".cfi_def_cfa_register", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_def_cfa_offset_i_s => try lower.emit(.directive, .@".cfi_def_cfa_offset", &.{
                .{ .imm = lower.imm(.i_s, inst.data.i.i) },
            }),
            .pseudo_cfi_adjust_cfa_offset_i_s => try lower.emit(.directive, .@".cfi_adjust_cfa_offset", &.{
                .{ .imm = lower.imm(.i_s, inst.data.i.i) },
            }),
            .pseudo_cfi_offset_ri_s => try lower.emit(.directive, .@".cfi_offset", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_val_offset_ri_s => try lower.emit(.directive, .@".cfi_val_offset", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_rel_offset_ri_s => try lower.emit(.directive, .@".cfi_rel_offset", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_register_rr => try lower.emit(.directive, .@".cfi_register", &.{
                .{ .reg = inst.data.rr.r1 },
                .{ .reg = inst.data.rr.r2 },
            }),
            .pseudo_cfi_restore_r => try lower.emit(.directive, .@".cfi_restore", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_undefined_r => try lower.emit(.directive, .@".cfi_undefined", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_same_value_r => try lower.emit(.directive, .@".cfi_same_value", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_remember_state_none => try lower.emit(.directive, .@".cfi_remember_state", &.{}),
            .pseudo_cfi_restore_state_none => try lower.emit(.directive, .@".cfi_restore_state", &.{}),
            .pseudo_cfi_escape_bytes => try lower.emit(.directive, .@".cfi_escape", &.{
                .{ .bytes = inst.data.bytes.get(lower.mir) },
            }),

            .pseudo_dbg_prologue_end_none,
            .pseudo_dbg_line_line_column,
            .pseudo_dbg_epilogue_begin_none,
            .pseudo_dbg_enter_block_none,
            .pseudo_dbg_leave_block_none,
            .pseudo_dbg_enter_inline_func,
            .pseudo_dbg_leave_inline_func,
            .pseudo_dbg_local_a,
            .pseudo_dbg_local_ai_s,
            .pseudo_dbg_local_ai_u,
            .pseudo_dbg_local_ai_64,
            .pseudo_dbg_local_as,
            .pseudo_dbg_local_aso,
            .pseudo_dbg_local_aro,
            .pseudo_dbg_local_af,
            .pseudo_dbg_local_am,
            .pseudo_dbg_var_args_none,

            .pseudo_dead_none,
            => {},
            else => unreachable,
        },
    }

    return .{
        .insts = lower.result_insts[0..lower.result_insts_len],
        .relocs = lower.result_relocs[0..lower.result_relocs_len],
    };
}

pub fn fail(lower: *Lower, comptime format: []const u8, args: anytype) Error {
    @branchHint(.cold);
    assert(lower.err_msg == null);
    lower.err_msg = try Zcu.ErrorMsg.create(lower.allocator, lower.src_loc, format, args);
    return error.LowerFail;
}

pub fn imm(lower: Lower, ops: Mir.Inst.Ops, i: u32) Immediate {
    return switch (ops) {
        .rri_s,
        .ri_s,
        .i_s,
        .mi_s,
        .rmi_s,
        .pseudo_dbg_local_ai_s,
        => Immediate.s(@bitCast(i)),

        .rrri,
        .rri_u,
        .ri_u,
        .i_u,
        .mi_u,
        .rmi,
        .rmi_u,
        .mri,
        .rrm,
        .rrmi,
        .pseudo_dbg_local_ai_u,
        => Immediate.u(i),

        .ri_64,
        .pseudo_dbg_local_ai_64,
        => Immediate.u(lower.mir.extraData(Mir.Imm64, i).data.decode()),

        else => unreachable,
    };
}

pub fn mem(lower: Lower, payload: u32) Memory {
    return lower.mir.resolveFrameLoc(lower.mir.extraData(Mir.Memory, payload).data).decode();
}

fn reloc(lower: *Lower, target: Reloc.Target, off: i32) Immediate {
    lower.result_relocs[lower.result_relocs_len] = .{
        .lowered_inst_index = lower.result_insts_len,
        .target = target,
        .off = off,
    };
    lower.result_relocs_len += 1;
    return Immediate.s(0);
}

fn emit(lower: *Lower, prefix: Prefix, mnemonic: Mnemonic, ops: []const Operand) Error!void {
    const emit_prefix = prefix;
    var emit_mnemonic = mnemonic;
    var emit_ops_storage: [4]Operand = undefined;
    const emit_ops = emit_ops_storage[0..ops.len];
    for (emit_ops, ops) |*emit_op, op| {
        emit_op.* = switch (op) {
            else => op,
            .mem => |mem_op| switch (mem_op.base()) {
                else => op,
                .reloc => |sym_index| op: {
                    assert(prefix == .none);
                    assert(mem_op.sib.disp == 0);
                    assert(mem_op.sib.scale_index.scale == 0);

                    if (lower.bin_file.cast(.elf)) |elf_file| {
                        const zo = elf_file.zigObjectPtr().?;
                        const elf_sym = zo.symbol(sym_index);

                        if (elf_sym.flags.is_tls) {
                            // TODO handle extern TLS vars, i.e., emit GD model
                            if (lower.pic) {
                                // Here, we currently assume local dynamic TLS vars, and so
                                // we emit LD model.
                                _ = lower.reloc(.{ .linker_tlsld = sym_index }, 0);
                                lower.result_insts[lower.result_insts_len] =
                                    try Instruction.new(.none, .lea, &[_]Operand{
                                    .{ .reg = .rdi },
                                    .{ .mem = Memory.initRip(mem_op.sib.ptr_size, 0) },
                                });
                                lower.result_insts_len += 1;
                                _ = lower.reloc(.{
                                    .linker_extern_fn = try elf_file.getGlobalSymbol("__tls_get_addr", null),
                                }, 0);
                                lower.result_insts[lower.result_insts_len] =
                                    try Instruction.new(.none, .call, &[_]Operand{
                                    .{ .imm = Immediate.s(0) },
                                });
                                lower.result_insts_len += 1;
                                _ = lower.reloc(.{ .linker_dtpoff = sym_index }, 0);
                                emit_mnemonic = .lea;
                                break :op .{ .mem = Memory.initSib(mem_op.sib.ptr_size, .{
                                    .base = .{ .reg = .rax },
                                    .disp = std.math.minInt(i32),
                                }) };
                            } else {
                                // Since we are linking statically, we emit LE model directly.
                                lower.result_insts[lower.result_insts_len] =
                                    try Instruction.new(.none, .mov, &[_]Operand{
                                    .{ .reg = .rax },
                                    .{ .mem = Memory.initSib(.qword, .{ .base = .{ .reg = .fs } }) },
                                });
                                lower.result_insts_len += 1;
                                _ = lower.reloc(.{ .linker_reloc = sym_index }, 0);
                                emit_mnemonic = .lea;
                                break :op .{ .mem = Memory.initSib(mem_op.sib.ptr_size, .{
                                    .base = .{ .reg = .rax },
                                    .disp = std.math.minInt(i32),
                                }) };
                            }
                        }

                        _ = lower.reloc(.{ .linker_reloc = sym_index }, 0);
                        if (lower.pic) switch (mnemonic) {
                            .lea => {
                                if (elf_sym.flags.is_extern_ptr) emit_mnemonic = .mov;
                                break :op .{ .mem = Memory.initRip(mem_op.sib.ptr_size, 0) };
                            },
                            .mov => {
                                if (elf_sym.flags.is_extern_ptr) {
                                    const reg = ops[0].reg;
                                    lower.result_insts[lower.result_insts_len] =
                                        try Instruction.new(.none, .mov, &[_]Operand{
                                        .{ .reg = reg.to64() },
                                        .{ .mem = Memory.initRip(.qword, 0) },
                                    });
                                    lower.result_insts_len += 1;
                                    break :op .{ .mem = Memory.initSib(mem_op.sib.ptr_size, .{ .base = .{
                                        .reg = reg.to64(),
                                    } }) };
                                }
                                break :op .{ .mem = Memory.initRip(mem_op.sib.ptr_size, 0) };
                            },
                            else => unreachable,
                        } else switch (mnemonic) {
                            .call => break :op .{ .mem = Memory.initSib(mem_op.sib.ptr_size, .{
                                .base = .{ .reg = .ds },
                            }) },
                            .lea => {
                                emit_mnemonic = .mov;
                                break :op .{ .imm = Immediate.s(0) };
                            },
                            .mov => break :op .{ .mem = Memory.initSib(mem_op.sib.ptr_size, .{
                                .base = .{ .reg = .ds },
                            }) },
                            else => unreachable,
                        }
                    } else if (lower.bin_file.cast(.macho)) |macho_file| {
                        const zo = macho_file.getZigObject().?;
                        const macho_sym = zo.symbols.items[sym_index];

                        if (macho_sym.flags.tlv) {
                            _ = lower.reloc(.{ .linker_reloc = sym_index }, 0);
                            lower.result_insts[lower.result_insts_len] =
                                try Instruction.new(.none, .mov, &[_]Operand{
                                .{ .reg = .rdi },
                                .{ .mem = Memory.initRip(mem_op.sib.ptr_size, 0) },
                            });
                            lower.result_insts_len += 1;
                            lower.result_insts[lower.result_insts_len] =
                                try Instruction.new(.none, .call, &[_]Operand{
                                .{ .mem = Memory.initSib(.qword, .{ .base = .{ .reg = .rdi } }) },
                            });
                            lower.result_insts_len += 1;
                            emit_mnemonic = .mov;
                            break :op .{ .reg = .rax };
                        }

                        _ = lower.reloc(.{ .linker_reloc = sym_index }, 0);
                        break :op switch (mnemonic) {
                            .lea => {
                                if (macho_sym.flags.is_extern_ptr) emit_mnemonic = .mov;
                                break :op .{ .mem = Memory.initRip(mem_op.sib.ptr_size, 0) };
                            },
                            .mov => {
                                if (macho_sym.flags.is_extern_ptr) {
                                    const reg = ops[0].reg;
                                    lower.result_insts[lower.result_insts_len] =
                                        try Instruction.new(.none, .mov, &[_]Operand{
                                        .{ .reg = reg.to64() },
                                        .{ .mem = Memory.initRip(.qword, 0) },
                                    });
                                    lower.result_insts_len += 1;
                                    break :op .{ .mem = Memory.initSib(mem_op.sib.ptr_size, .{ .base = .{
                                        .reg = reg.to64(),
                                    } }) };
                                }
                                break :op .{ .mem = Memory.initRip(mem_op.sib.ptr_size, 0) };
                            },
                            else => unreachable,
                        };
                    }
                },
            },
        };
    }
    lower.result_insts[lower.result_insts_len] =
        try Instruction.new(emit_prefix, emit_mnemonic, emit_ops);
    lower.result_insts_len += 1;
}

fn generic(lower: *Lower, inst: Mir.Inst) Error!void {
    const fixes = switch (inst.ops) {
        .none => inst.data.none.fixes,
        .inst => inst.data.inst.fixes,
        .i_s, .i_u => inst.data.i.fixes,
        .r => inst.data.r.fixes,
        .rr => inst.data.rr.fixes,
        .rrr => inst.data.rrr.fixes,
        .rrrr => inst.data.rrrr.fixes,
        .rrri => inst.data.rrri.fixes,
        .rri_s, .rri_u => inst.data.rri.fixes,
        .ri_s, .ri_u, .ri_64 => inst.data.ri.fixes,
        .rm, .rmi_s, .mr => inst.data.rx.fixes,
        .mrr, .rrm, .rmr => inst.data.rrx.fixes,
        .rmi, .mri => inst.data.rix.fixes,
        .rrmr => inst.data.rrrx.fixes,
        .rrmi => inst.data.rrix.fixes,
        .mi_u, .mi_s => inst.data.x.fixes,
        .m => inst.data.x.fixes,
        .extern_fn_reloc, .got_reloc, .direct_reloc, .import_reloc, .tlv_reloc, .rel => ._,
        else => return lower.fail("TODO lower .{s}", .{@tagName(inst.ops)}),
    };
    try lower.emit(switch (fixes) {
        inline else => |tag| comptime if (std.mem.indexOfScalar(u8, @tagName(tag), ' ')) |space|
            @field(Prefix, @tagName(tag)[0..space])
        else
            .none,
    }, mnemonic: {
        @setEvalBranchQuota(2_000);

        comptime var max_len = 0;
        inline for (@typeInfo(Mnemonic).@"enum".fields) |field| max_len = @max(field.name.len, max_len);
        var buf: [max_len]u8 = undefined;

        const fixes_name = @tagName(fixes);
        const pattern = fixes_name[if (std.mem.indexOfScalar(u8, fixes_name, ' ')) |i| i + 1 else 0..];
        const wildcard_i = std.mem.indexOfScalar(u8, pattern, '_').?;
        const parts = .{ pattern[0..wildcard_i], @tagName(inst.tag), pattern[wildcard_i + 1 ..] };
        const err_msg = "unsupported mnemonic: ";
        const mnemonic = std.fmt.bufPrint(&buf, "{s}{s}{s}", parts) catch
            return lower.fail(err_msg ++ "'{s}{s}{s}'", parts);
        break :mnemonic std.meta.stringToEnum(Mnemonic, mnemonic) orelse
            return lower.fail(err_msg ++ "'{s}'", .{mnemonic});
    }, switch (inst.ops) {
        .none => &.{},
        .inst => &.{
            .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }, 0) },
        },
        .i_s, .i_u => &.{
            .{ .imm = lower.imm(inst.ops, inst.data.i.i) },
        },
        .r => &.{
            .{ .reg = inst.data.r.r1 },
        },
        .rr => &.{
            .{ .reg = inst.data.rr.r1 },
            .{ .reg = inst.data.rr.r2 },
        },
        .rrr => &.{
            .{ .reg = inst.data.rrr.r1 },
            .{ .reg = inst.data.rrr.r2 },
            .{ .reg = inst.data.rrr.r3 },
        },
        .rrrr => &.{
            .{ .reg = inst.data.rrrr.r1 },
            .{ .reg = inst.data.rrrr.r2 },
            .{ .reg = inst.data.rrrr.r3 },
            .{ .reg = inst.data.rrrr.r4 },
        },
        .rrri => &.{
            .{ .reg = inst.data.rrri.r1 },
            .{ .reg = inst.data.rrri.r2 },
            .{ .reg = inst.data.rrri.r3 },
            .{ .imm = lower.imm(inst.ops, inst.data.rrri.i) },
        },
        .ri_s, .ri_u, .ri_64 => &.{
            .{ .reg = inst.data.ri.r1 },
            .{ .imm = lower.imm(inst.ops, inst.data.ri.i) },
        },
        .rri_s, .rri_u => &.{
            .{ .reg = inst.data.rri.r1 },
            .{ .reg = inst.data.rri.r2 },
            .{ .imm = lower.imm(inst.ops, inst.data.rri.i) },
        },
        .m => &.{
            .{ .mem = lower.mem(inst.data.x.payload) },
        },
        .mi_s, .mi_u => &.{
            .{ .mem = lower.mem(inst.data.x.payload + 1) },
            .{ .imm = lower.imm(
                inst.ops,
                lower.mir.extraData(Mir.Imm32, inst.data.x.payload).data.imm,
            ) },
        },
        .rm => &.{
            .{ .reg = inst.data.rx.r1 },
            .{ .mem = lower.mem(inst.data.rx.payload) },
        },
        .rmr => &.{
            .{ .reg = inst.data.rrx.r1 },
            .{ .mem = lower.mem(inst.data.rrx.payload) },
            .{ .reg = inst.data.rrx.r2 },
        },
        .rmi => &.{
            .{ .reg = inst.data.rix.r1 },
            .{ .mem = lower.mem(inst.data.rix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.rix.i) },
        },
        .rmi_s, .rmi_u => &.{
            .{ .reg = inst.data.rx.r1 },
            .{ .mem = lower.mem(inst.data.rx.payload + 1) },
            .{ .imm = lower.imm(
                inst.ops,
                lower.mir.extraData(Mir.Imm32, inst.data.rx.payload).data.imm,
            ) },
        },
        .mr => &.{
            .{ .mem = lower.mem(inst.data.rx.payload) },
            .{ .reg = inst.data.rx.r1 },
        },
        .mrr => &.{
            .{ .mem = lower.mem(inst.data.rrx.payload) },
            .{ .reg = inst.data.rrx.r1 },
            .{ .reg = inst.data.rrx.r2 },
        },
        .mri => &.{
            .{ .mem = lower.mem(inst.data.rix.payload) },
            .{ .reg = inst.data.rix.r1 },
            .{ .imm = lower.imm(inst.ops, inst.data.rix.i) },
        },
        .rrm => &.{
            .{ .reg = inst.data.rrx.r1 },
            .{ .reg = inst.data.rrx.r2 },
            .{ .mem = lower.mem(inst.data.rrx.payload) },
        },
        .rrmr => &.{
            .{ .reg = inst.data.rrrx.r1 },
            .{ .reg = inst.data.rrrx.r2 },
            .{ .mem = lower.mem(inst.data.rrrx.payload) },
            .{ .reg = inst.data.rrrx.r3 },
        },
        .rrmi => &.{
            .{ .reg = inst.data.rrix.r1 },
            .{ .reg = inst.data.rrix.r2 },
            .{ .mem = lower.mem(inst.data.rrix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.rrix.i) },
        },
        .extern_fn_reloc, .rel => &.{
            .{ .imm = lower.reloc(.{ .linker_extern_fn = inst.data.reloc.sym_index }, inst.data.reloc.off) },
        },
        .got_reloc, .direct_reloc, .import_reloc => ops: {
            const reg = inst.data.rx.r1;
            const extra = lower.mir.extraData(bits.SymbolOffset, inst.data.rx.payload).data;
            _ = lower.reloc(switch (inst.ops) {
                .got_reloc => .{ .linker_got = extra.sym_index },
                .direct_reloc => .{ .linker_direct = extra.sym_index },
                .import_reloc => .{ .linker_import = extra.sym_index },
                else => unreachable,
            }, extra.off);
            break :ops &.{
                .{ .reg = reg },
                .{ .mem = Memory.initRip(Memory.PtrSize.fromBitSize(reg.bitSize()), 0) },
            };
        },
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    });
}

fn pushPopRegList(lower: *Lower, comptime mnemonic: Mnemonic, inst: Mir.Inst) Error!void {
    const callee_preserved_regs = abi.getCalleePreservedRegs(lower.cc);
    var off: i32 = switch (mnemonic) {
        .push => 0,
        .pop => undefined,
        else => unreachable,
    };
    {
        var it = inst.data.reg_list.iterator(.{ .direction = switch (mnemonic) {
            .push => .reverse,
            .pop => .forward,
            else => unreachable,
        } });
        while (it.next()) |i| {
            try lower.emit(.none, mnemonic, &.{.{
                .reg = callee_preserved_regs[i],
            }});
            switch (mnemonic) {
                .push => off -= 8,
                .pop => {},
                else => unreachable,
            }
        }
    }
    switch (mnemonic) {
        .push => {
            var it = inst.data.reg_list.iterator(.{});
            while (it.next()) |i| {
                try lower.emit(.directive, .@".cfi_rel_offset", &.{
                    .{ .reg = callee_preserved_regs[i] },
                    .{ .imm = Immediate.s(off) },
                });
                off += 8;
            }
            assert(off == 0);
        },
        .pop => {},
        else => unreachable,
    }
}

const page_size: i32 = 1 << 12;

const abi = @import("abi.zig");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const encoder = @import("encoder.zig");
const link = @import("../../link.zig");
const std = @import("std");

const Immediate = Instruction.Immediate;
const Instruction = encoder.Instruction;
const Lower = @This();
const Memory = Instruction.Memory;
const Mir = @import("Mir.zig");
const Mnemonic = Instruction.Mnemonic;
const Zcu = @import("../../Zcu.zig");
const Operand = Instruction.Operand;
const Prefix = Instruction.Prefix;
const Register = bits.Register;
