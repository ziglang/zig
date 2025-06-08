//! This file contains the functionality for lowering x86_64 MIR to Instructions

target: *const std.Target,
allocator: std.mem.Allocator,
mir: Mir,
cc: std.builtin.CallingConvention,
err_msg: ?*Zcu.ErrorMsg = null,
src_loc: Zcu.LazySrcLoc,
result_insts_len: ResultInstIndex = undefined,
result_insts: [max_result_insts]Instruction = undefined,
result_relocs_len: ResultRelocIndex = undefined,
result_relocs: [max_result_relocs]Reloc = undefined,

const max_result_insts = @max(
    1, // non-pseudo instructions
    2, // cmovcc: cmovcc \ cmovcc
    3, // setcc: setcc \ setcc \ logicop
    2, // jcc: jcc \ jcc
    pseudo_probe_align_insts,
    pseudo_probe_adjust_unrolled_max_insts,
    pseudo_probe_adjust_setup_insts,
    pseudo_probe_adjust_loop_insts,
    abi.zigcc.callee_preserved_regs.len * 2, // push_regs/pop_regs
    abi.Win64.callee_preserved_regs.len * 2, // push_regs/pop_regs
    abi.SysV.callee_preserved_regs.len * 2, // push_regs/pop_regs
);
const max_result_relocs = @max(
    1, // jmp/jcc/call/mov/lea: jmp/jcc/call/mov/lea
    2, // jcc: jcc \ jcc
    2, // test \ jcc \ probe \ sub \ jmp
    1, // probe \ sub \ jcc
);

const ResultInstIndex = std.math.IntFittingRange(0, max_result_insts);
const ResultRelocIndex = std.math.IntFittingRange(0, max_result_relocs);
pub const InstOpIndex = std.math.IntFittingRange(
    0,
    @typeInfo(@FieldType(Instruction, "ops")).array.len,
);

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
    CodegenFail,
} || codegen.GenerateSymbolError;

pub const Reloc = struct {
    lowered_inst_index: ResultInstIndex,
    op_index: InstOpIndex,
    target: Target,
    off: i32,

    const Target = union(enum) {
        inst: Mir.Inst.Index,
        table,
        nav: InternPool.Nav.Index,
        uav: InternPool.Key.Ptr.BaseAddr.Uav,
        lazy_sym: link.File.LazySymbol,
        extern_func: Mir.NullTerminatedString,
    };
};

const Options = struct { allow_frame_locs: bool };

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, index: Mir.Inst.Index) Error!struct {
    insts: []Instruction,
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
                try lower.encode(.none, .cmovnz, &.{
                    .{ .reg = inst.data.rr.r2 },
                    .{ .reg = inst.data.rr.r1 },
                });
                try lower.encode(.none, .cmovnp, &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_cmov_nz_or_p_rr => {
                assert(inst.data.rr.fixes == ._);
                try lower.encode(.none, .cmovnz, &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
                try lower.encode(.none, .cmovp, &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_cmov_nz_or_p_rm => {
                assert(inst.data.rx.fixes == ._);
                try lower.encode(.none, .cmovnz, &.{
                    .{ .reg = inst.data.rx.r1 },
                    .{ .mem = lower.mem(1, inst.data.rx.payload) },
                });
                try lower.encode(.none, .cmovp, &.{
                    .{ .reg = inst.data.rx.r1 },
                    .{ .mem = lower.mem(1, inst.data.rx.payload) },
                });
            },
            .pseudo_set_z_and_np_r => {
                assert(inst.data.rr.fixes == ._);
                try lower.encode(.none, .setz, &.{
                    .{ .reg = inst.data.rr.r1 },
                });
                try lower.encode(.none, .setnp, &.{
                    .{ .reg = inst.data.rr.r2 },
                });
                try lower.encode(.none, .@"and", &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_set_z_and_np_m => {
                assert(inst.data.rx.fixes == ._);
                try lower.encode(.none, .setz, &.{
                    .{ .mem = lower.mem(0, inst.data.rx.payload) },
                });
                try lower.encode(.none, .setnp, &.{
                    .{ .reg = inst.data.rx.r1 },
                });
                try lower.encode(.none, .@"and", &.{
                    .{ .mem = lower.mem(0, inst.data.rx.payload) },
                    .{ .reg = inst.data.rx.r1 },
                });
            },
            .pseudo_set_nz_or_p_r => {
                assert(inst.data.rr.fixes == ._);
                try lower.encode(.none, .setnz, &.{
                    .{ .reg = inst.data.rr.r1 },
                });
                try lower.encode(.none, .setp, &.{
                    .{ .reg = inst.data.rr.r2 },
                });
                try lower.encode(.none, .@"or", &.{
                    .{ .reg = inst.data.rr.r1 },
                    .{ .reg = inst.data.rr.r2 },
                });
            },
            .pseudo_set_nz_or_p_m => {
                assert(inst.data.rx.fixes == ._);
                try lower.encode(.none, .setnz, &.{
                    .{ .mem = lower.mem(0, inst.data.rx.payload) },
                });
                try lower.encode(.none, .setp, &.{
                    .{ .reg = inst.data.rx.r1 },
                });
                try lower.encode(.none, .@"or", &.{
                    .{ .mem = lower.mem(0, inst.data.rx.payload) },
                    .{ .reg = inst.data.rx.r1 },
                });
            },
            .pseudo_j_z_and_np_inst => {
                assert(inst.data.inst.fixes == ._);
                try lower.encode(.none, .jnz, &.{
                    .{ .imm = lower.reloc(0, .{ .inst = index + 1 }, 0) },
                });
                try lower.encode(.none, .jnp, &.{
                    .{ .imm = lower.reloc(0, .{ .inst = inst.data.inst.inst }, 0) },
                });
            },
            .pseudo_j_nz_or_p_inst => {
                assert(inst.data.inst.fixes == ._);
                try lower.encode(.none, .jnz, &.{
                    .{ .imm = lower.reloc(0, .{ .inst = inst.data.inst.inst }, 0) },
                });
                try lower.encode(.none, .jp, &.{
                    .{ .imm = lower.reloc(0, .{ .inst = inst.data.inst.inst }, 0) },
                });
            },

            .pseudo_probe_align_ri_s => {
                try lower.encode(.none, .@"test", &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .imm = .s(@bitCast(inst.data.ri.i)) },
                });
                try lower.encode(.none, .jz, &.{
                    .{ .imm = lower.reloc(0, .{ .inst = index + 1 }, 0) },
                });
                try lower.encode(.none, .lea, &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .mem = Memory.initSib(.qword, .{
                        .base = .{ .reg = inst.data.ri.r1 },
                        .disp = -page_size,
                    }) },
                });
                try lower.encode(.none, .@"test", &.{
                    .{ .mem = Memory.initSib(.dword, .{
                        .base = .{ .reg = inst.data.ri.r1 },
                    }) },
                    .{ .reg = inst.data.ri.r1.to32() },
                });
                try lower.encode(.none, .jmp, &.{
                    .{ .imm = lower.reloc(0, .{ .inst = index }, 0) },
                });
                assert(lower.result_insts_len == pseudo_probe_align_insts);
            },
            .pseudo_probe_adjust_unrolled_ri_s => {
                var offset = page_size;
                while (offset < @as(i32, @bitCast(inst.data.ri.i))) : (offset += page_size) {
                    try lower.encode(.none, .@"test", &.{
                        .{ .mem = Memory.initSib(.dword, .{
                            .base = .{ .reg = inst.data.ri.r1 },
                            .disp = -offset,
                        }) },
                        .{ .reg = inst.data.ri.r1.to32() },
                    });
                }
                try lower.encode(.none, .sub, &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .imm = .s(@bitCast(inst.data.ri.i)) },
                });
                assert(lower.result_insts_len <= pseudo_probe_adjust_unrolled_max_insts);
            },
            .pseudo_probe_adjust_setup_rri_s => {
                try lower.encode(.none, .mov, &.{
                    .{ .reg = inst.data.rri.r2.to32() },
                    .{ .imm = .s(@bitCast(inst.data.rri.i)) },
                });
                try lower.encode(.none, .sub, &.{
                    .{ .reg = inst.data.rri.r1 },
                    .{ .reg = inst.data.rri.r2 },
                });
                assert(lower.result_insts_len == pseudo_probe_adjust_setup_insts);
            },
            .pseudo_probe_adjust_loop_rr => {
                try lower.encode(.none, .@"test", &.{
                    .{ .mem = Memory.initSib(.dword, .{
                        .base = .{ .reg = inst.data.rr.r1 },
                        .scale_index = .{ .scale = 1, .index = inst.data.rr.r2 },
                        .disp = -page_size,
                    }) },
                    .{ .reg = inst.data.rr.r1.to32() },
                });
                try lower.encode(.none, .sub, &.{
                    .{ .reg = inst.data.rr.r2 },
                    .{ .imm = .s(page_size) },
                });
                try lower.encode(.none, .jae, &.{
                    .{ .imm = lower.reloc(0, .{ .inst = index }, 0) },
                });
                assert(lower.result_insts_len == pseudo_probe_adjust_loop_insts);
            },
            .pseudo_push_reg_list => try lower.pushPopRegList(.push, inst),
            .pseudo_pop_reg_list => try lower.pushPopRegList(.pop, inst),

            .pseudo_cfi_def_cfa_ri_s => try lower.encode(.directive, .@".cfi_def_cfa", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_def_cfa_register_r => try lower.encode(.directive, .@".cfi_def_cfa_register", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_def_cfa_offset_i_s => try lower.encode(.directive, .@".cfi_def_cfa_offset", &.{
                .{ .imm = lower.imm(.i_s, inst.data.i.i) },
            }),
            .pseudo_cfi_adjust_cfa_offset_i_s => try lower.encode(.directive, .@".cfi_adjust_cfa_offset", &.{
                .{ .imm = lower.imm(.i_s, inst.data.i.i) },
            }),
            .pseudo_cfi_offset_ri_s => try lower.encode(.directive, .@".cfi_offset", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_val_offset_ri_s => try lower.encode(.directive, .@".cfi_val_offset", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_rel_offset_ri_s => try lower.encode(.directive, .@".cfi_rel_offset", &.{
                .{ .reg = inst.data.ri.r1 },
                .{ .imm = lower.imm(.ri_s, inst.data.ri.i) },
            }),
            .pseudo_cfi_register_rr => try lower.encode(.directive, .@".cfi_register", &.{
                .{ .reg = inst.data.rr.r1 },
                .{ .reg = inst.data.rr.r2 },
            }),
            .pseudo_cfi_restore_r => try lower.encode(.directive, .@".cfi_restore", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_undefined_r => try lower.encode(.directive, .@".cfi_undefined", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_same_value_r => try lower.encode(.directive, .@".cfi_same_value", &.{
                .{ .reg = inst.data.r.r1 },
            }),
            .pseudo_cfi_remember_state_none => try lower.encode(.directive, .@".cfi_remember_state", &.{}),
            .pseudo_cfi_restore_state_none => try lower.encode(.directive, .@".cfi_restore_state", &.{}),
            .pseudo_cfi_escape_bytes => try lower.encode(.directive, .@".cfi_escape", &.{
                .{ .bytes = inst.data.bytes.get(lower.mir) },
            }),

            .pseudo_dbg_prologue_end_none,
            .pseudo_dbg_line_stmt_line_column,
            .pseudo_dbg_line_line_column,
            .pseudo_dbg_epilogue_begin_none,
            .pseudo_dbg_enter_block_none,
            .pseudo_dbg_leave_block_none,
            .pseudo_dbg_enter_inline_func,
            .pseudo_dbg_leave_inline_func,
            .pseudo_dbg_arg_none,
            .pseudo_dbg_arg_i_s,
            .pseudo_dbg_arg_i_u,
            .pseudo_dbg_arg_i_64,
            .pseudo_dbg_arg_ro,
            .pseudo_dbg_arg_fa,
            .pseudo_dbg_arg_m,
            .pseudo_dbg_arg_val,
            .pseudo_dbg_var_args_none,
            .pseudo_dbg_var_none,
            .pseudo_dbg_var_i_s,
            .pseudo_dbg_var_i_u,
            .pseudo_dbg_var_i_64,
            .pseudo_dbg_var_ro,
            .pseudo_dbg_var_fa,
            .pseudo_dbg_var_m,
            .pseudo_dbg_var_val,

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
    lower.err_msg = try .create(lower.allocator, lower.src_loc, format, args);
    return error.LowerFail;
}

pub fn imm(lower: *const Lower, ops: Mir.Inst.Ops, i: u32) Immediate {
    return switch (ops) {
        .rri_s,
        .ri_s,
        .i_s,
        .mi_s,
        .rmi_s,
        .pseudo_dbg_arg_i_s,
        .pseudo_dbg_var_i_s,
        => .s(@bitCast(i)),

        .ii,
        .ir,
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
        .pseudo_dbg_arg_i_u,
        .pseudo_dbg_var_i_u,
        => .u(i),

        .ri_64,
        => .u(lower.mir.extraData(Mir.Imm64, i).data.decode()),

        .pseudo_dbg_arg_i_64,
        .pseudo_dbg_var_i_64,
        => unreachable,

        else => unreachable,
    };
}

fn mem(lower: *Lower, op_index: InstOpIndex, payload: u32) Memory {
    var m = lower.mir.resolveMemoryExtra(payload).decode();
    switch (m) {
        .sib => |*sib| switch (sib.base) {
            .none, .reg, .frame => {},
            .table => sib.disp = lower.reloc(op_index, .table, sib.disp).signed,
            .rip_inst => |inst_index| sib.disp = lower.reloc(op_index, .{ .inst = inst_index }, sib.disp).signed,
            .nav => |nav| sib.disp = lower.reloc(op_index, .{ .nav = nav }, sib.disp).signed,
            .uav => |uav| sib.disp = lower.reloc(op_index, .{ .uav = uav }, sib.disp).signed,
            .lazy_sym => |lazy_sym| sib.disp = lower.reloc(op_index, .{ .lazy_sym = lazy_sym }, sib.disp).signed,
            .extern_func => |extern_func| sib.disp = lower.reloc(op_index, .{ .extern_func = extern_func }, sib.disp).signed,
        },
        else => {},
    }
    return m;
}

fn reloc(lower: *Lower, op_index: InstOpIndex, target: Reloc.Target, off: i32) Immediate {
    lower.result_relocs[lower.result_relocs_len] = .{
        .lowered_inst_index = lower.result_insts_len,
        .op_index = op_index,
        .target = target,
        .off = off,
    };
    lower.result_relocs_len += 1;
    return .s(0);
}

fn encode(lower: *Lower, prefix: Prefix, mnemonic: Mnemonic, ops: []const Operand) Error!void {
    lower.result_insts[lower.result_insts_len] = try .new(prefix, mnemonic, ops, lower.target);
    lower.result_insts_len += 1;
}

fn generic(lower: *Lower, inst: Mir.Inst) Error!void {
    @setEvalBranchQuota(2_800);
    const fixes = switch (inst.ops) {
        .none => inst.data.none.fixes,
        .inst => inst.data.inst.fixes,
        .i_s, .i_u => inst.data.i.fixes,
        .ii => inst.data.ii.fixes,
        .r => inst.data.r.fixes,
        .rr => inst.data.rr.fixes,
        .rrr => inst.data.rrr.fixes,
        .rrrr => inst.data.rrrr.fixes,
        .rrri => inst.data.rrri.fixes,
        .rri_s, .rri_u => inst.data.rri.fixes,
        .ri_s, .ri_u, .ri_64, .ir => inst.data.ri.fixes,
        .rm, .rmi_s, .rmi_u, .mr => inst.data.rx.fixes,
        .mrr, .rrm, .rmr => inst.data.rrx.fixes,
        .rmi, .mri => inst.data.rix.fixes,
        .rrmr => inst.data.rrrx.fixes,
        .rrmi => inst.data.rrix.fixes,
        .mi_u, .mi_s => inst.data.x.fixes,
        .m => inst.data.x.fixes,
        .nav, .uav, .lazy_sym, .extern_func => ._,
        else => return lower.fail("TODO lower .{s}", .{@tagName(inst.ops)}),
    };
    try lower.encode(switch (fixes) {
        inline else => |tag| comptime if (std.mem.indexOfScalar(u8, @tagName(tag), ' ')) |space|
            @field(Prefix, @tagName(tag)[0..space])
        else
            .none,
    }, mnemonic: {
        comptime var max_len = 0;
        inline for (@typeInfo(Mnemonic).@"enum".fields) |field| max_len = @max(field.name.len, max_len);
        var buf: [max_len]u8 = undefined;

        const fixes_name = @tagName(fixes);
        const pattern = fixes_name[if (std.mem.indexOfScalar(u8, fixes_name, ' ')) |i| i + " ".len else 0..];
        const wildcard_index = std.mem.indexOfScalar(u8, pattern, '_').?;
        const parts = .{ pattern[0..wildcard_index], @tagName(inst.tag), pattern[wildcard_index + "_".len ..] };
        const err_msg = "unsupported mnemonic: ";
        const mnemonic = std.fmt.bufPrint(&buf, "{s}{s}{s}", parts) catch
            return lower.fail(err_msg ++ "'{s}{s}{s}'", parts);
        break :mnemonic std.meta.stringToEnum(Mnemonic, mnemonic) orelse
            return lower.fail(err_msg ++ "'{s}'", .{mnemonic});
    }, switch (inst.ops) {
        .none => &.{},
        .inst => &.{
            .{ .imm = lower.reloc(0, .{ .inst = inst.data.inst.inst }, 0) },
        },
        .i_s, .i_u => &.{
            .{ .imm = lower.imm(inst.ops, inst.data.i.i) },
        },
        .ii => &.{
            .{ .imm = lower.imm(inst.ops, inst.data.ii.i1) },
            .{ .imm = lower.imm(inst.ops, inst.data.ii.i2) },
        },
        .ir => &.{
            .{ .imm = lower.imm(inst.ops, inst.data.ri.i) },
            .{ .reg = inst.data.ri.r1 },
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
            .{ .mem = lower.mem(0, inst.data.x.payload) },
        },
        .mi_s, .mi_u => &.{
            .{ .mem = lower.mem(0, inst.data.x.payload + 1) },
            .{ .imm = lower.imm(
                inst.ops,
                lower.mir.extraData(Mir.Imm32, inst.data.x.payload).data.imm,
            ) },
        },
        .rm => &.{
            .{ .reg = inst.data.rx.r1 },
            .{ .mem = lower.mem(1, inst.data.rx.payload) },
        },
        .rmr => &.{
            .{ .reg = inst.data.rrx.r1 },
            .{ .mem = lower.mem(1, inst.data.rrx.payload) },
            .{ .reg = inst.data.rrx.r2 },
        },
        .rmi => &.{
            .{ .reg = inst.data.rix.r1 },
            .{ .mem = lower.mem(1, inst.data.rix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.rix.i) },
        },
        .rmi_s, .rmi_u => &.{
            .{ .reg = inst.data.rx.r1 },
            .{ .mem = lower.mem(1, inst.data.rx.payload + 1) },
            .{ .imm = lower.imm(
                inst.ops,
                lower.mir.extraData(Mir.Imm32, inst.data.rx.payload).data.imm,
            ) },
        },
        .mr => &.{
            .{ .mem = lower.mem(0, inst.data.rx.payload) },
            .{ .reg = inst.data.rx.r1 },
        },
        .mrr => &.{
            .{ .mem = lower.mem(0, inst.data.rrx.payload) },
            .{ .reg = inst.data.rrx.r1 },
            .{ .reg = inst.data.rrx.r2 },
        },
        .mri => &.{
            .{ .mem = lower.mem(0, inst.data.rix.payload) },
            .{ .reg = inst.data.rix.r1 },
            .{ .imm = lower.imm(inst.ops, inst.data.rix.i) },
        },
        .rrm => &.{
            .{ .reg = inst.data.rrx.r1 },
            .{ .reg = inst.data.rrx.r2 },
            .{ .mem = lower.mem(2, inst.data.rrx.payload) },
        },
        .rrmr => &.{
            .{ .reg = inst.data.rrrx.r1 },
            .{ .reg = inst.data.rrrx.r2 },
            .{ .mem = lower.mem(2, inst.data.rrrx.payload) },
            .{ .reg = inst.data.rrrx.r3 },
        },
        .rrmi => &.{
            .{ .reg = inst.data.rrix.r1 },
            .{ .reg = inst.data.rrix.r2 },
            .{ .mem = lower.mem(2, inst.data.rrix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.rrix.i) },
        },
        .nav => &.{
            .{ .imm = lower.reloc(0, .{ .nav = inst.data.nav.index }, inst.data.nav.off) },
        },
        .uav => &.{
            .{ .imm = lower.reloc(0, .{ .uav = inst.data.uav }, 0) },
        },
        .lazy_sym => &.{
            .{ .imm = lower.reloc(0, .{ .lazy_sym = inst.data.lazy_sym }, 0) },
        },
        .extern_func => &.{
            .{ .imm = lower.reloc(0, .{ .extern_func = inst.data.extern_func }, 0) },
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
            try lower.encode(.none, mnemonic, &.{.{
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
                try lower.encode(.directive, .@".cfi_rel_offset", &.{
                    .{ .reg = callee_preserved_regs[i] },
                    .{ .imm = .s(off) },
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
const codegen = @import("../../codegen.zig");
const encoder = @import("encoder.zig");
const link = @import("../../link.zig");
const std = @import("std");

const Immediate = Instruction.Immediate;
const Instruction = encoder.Instruction;
const InternPool = @import("../../InternPool.zig");
const Lower = @This();
const Memory = Instruction.Memory;
const Mir = @import("Mir.zig");
const Mnemonic = Instruction.Mnemonic;
const Zcu = @import("../../Zcu.zig");
const Operand = Instruction.Operand;
const Prefix = Instruction.Prefix;
const Register = bits.Register;
const Type = @import("../../Type.zig");
