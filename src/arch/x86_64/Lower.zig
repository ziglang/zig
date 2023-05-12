//! This file contains the functionality for lowering x86_64 MIR to Instructions

allocator: Allocator,
mir: Mir,
target: *const std.Target,
err_msg: ?*ErrorMsg = null,
src_loc: Module.SrcLoc,
result_insts_len: u8 = undefined,
result_relocs_len: u8 = undefined,
result_insts: [
    std.mem.max(usize, &.{
        1, // non-pseudo instructions
        2, // cmovcc: cmovcc \ cmovcc
        3, // setcc: setcc \ setcc \ logicop
        2, // jcc: jcc \ jcc
        pseudo_probe_align_insts,
        pseudo_probe_adjust_unrolled_max_insts,
        pseudo_probe_adjust_setup_insts,
        pseudo_probe_adjust_loop_insts,
        abi.Win64.callee_preserved_regs.len, // push_regs/pop_regs
        abi.SysV.callee_preserved_regs.len, // push_regs/pop_regs
    })
]Instruction = undefined,
result_relocs: [
    std.mem.max(usize, &.{
        1, // jmp/jcc/call/mov/lea: jmp/jcc/call/mov/lea
        2, // jcc: jcc \ jcc
        2, // test \ jcc \ probe \ sub \ jmp
        1, // probe \ sub \ jcc
    })
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

    const Target = union(enum) {
        inst: Mir.Inst.Index,
        linker_extern_fn: Mir.Reloc,
        linker_got: Mir.Reloc,
        linker_direct: Mir.Reloc,
        linker_import: Mir.Reloc,
        linker_tlv: Mir.Reloc,
    };
};

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
            .pseudo_cmov_nz_or_p_rm_sib,
            .pseudo_cmov_nz_or_p_rm_rip,
            => {
                assert(inst.data.rx.fixes == ._);
                try lower.emit(.none, .cmovnz, &.{
                    .{ .reg = inst.data.rx.r1 },
                    .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
                });
                try lower.emit(.none, .cmovp, &.{
                    .{ .reg = inst.data.rx.r1 },
                    .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
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
            .pseudo_set_z_and_np_m_sib,
            .pseudo_set_z_and_np_m_rip,
            => {
                assert(inst.data.rx.fixes == ._);
                try lower.emit(.none, .setz, &.{
                    .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
                });
                try lower.emit(.none, .setnp, &.{
                    .{ .reg = inst.data.rx.r1 },
                });
                try lower.emit(.none, .@"and", &.{
                    .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
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
            .pseudo_set_nz_or_p_m_sib,
            .pseudo_set_nz_or_p_m_rip,
            => {
                assert(inst.data.rx.fixes == ._);
                try lower.emit(.none, .setnz, &.{
                    .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
                });
                try lower.emit(.none, .setp, &.{
                    .{ .reg = inst.data.rx.r1 },
                });
                try lower.emit(.none, .@"or", &.{
                    .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
                    .{ .reg = inst.data.rx.r1 },
                });
            },
            .pseudo_j_z_and_np_inst => {
                assert(inst.data.inst.fixes == ._);
                try lower.emit(.none, .jnz, &.{
                    .{ .imm = lower.reloc(.{ .inst = index + 1 }) },
                });
                try lower.emit(.none, .jnp, &.{
                    .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }) },
                });
            },
            .pseudo_j_nz_or_p_inst => {
                assert(inst.data.inst.fixes == ._);
                try lower.emit(.none, .jnz, &.{
                    .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }) },
                });
                try lower.emit(.none, .jp, &.{
                    .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }) },
                });
            },

            .pseudo_probe_align_ri_s => {
                try lower.emit(.none, .@"test", &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .imm = Immediate.s(@bitCast(i32, inst.data.ri.i)) },
                });
                try lower.emit(.none, .jz, &.{
                    .{ .imm = lower.reloc(.{ .inst = index + 1 }) },
                });
                try lower.emit(.none, .lea, &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .mem = Memory.sib(.qword, .{
                        .base = .{ .reg = inst.data.ri.r1 },
                        .disp = -page_size,
                    }) },
                });
                try lower.emit(.none, .@"test", &.{
                    .{ .mem = Memory.sib(.dword, .{
                        .base = .{ .reg = inst.data.ri.r1 },
                    }) },
                    .{ .reg = inst.data.ri.r1.to32() },
                });
                try lower.emit(.none, .jmp, &.{
                    .{ .imm = lower.reloc(.{ .inst = index }) },
                });
                assert(lower.result_insts_len == pseudo_probe_align_insts);
            },
            .pseudo_probe_adjust_unrolled_ri_s => {
                var offset = page_size;
                while (offset < @bitCast(i32, inst.data.ri.i)) : (offset += page_size) {
                    try lower.emit(.none, .@"test", &.{
                        .{ .mem = Memory.sib(.dword, .{
                            .base = .{ .reg = inst.data.ri.r1 },
                            .disp = -offset,
                        }) },
                        .{ .reg = inst.data.ri.r1.to32() },
                    });
                }
                try lower.emit(.none, .sub, &.{
                    .{ .reg = inst.data.ri.r1 },
                    .{ .imm = Immediate.s(@bitCast(i32, inst.data.ri.i)) },
                });
                assert(lower.result_insts_len <= pseudo_probe_adjust_unrolled_max_insts);
            },
            .pseudo_probe_adjust_setup_rri_s => {
                try lower.emit(.none, .mov, &.{
                    .{ .reg = inst.data.rri.r2.to32() },
                    .{ .imm = Immediate.s(@bitCast(i32, inst.data.rri.i)) },
                });
                try lower.emit(.none, .sub, &.{
                    .{ .reg = inst.data.rri.r1 },
                    .{ .reg = inst.data.rri.r2 },
                });
                assert(lower.result_insts_len == pseudo_probe_adjust_setup_insts);
            },
            .pseudo_probe_adjust_loop_rr => {
                try lower.emit(.none, .@"test", &.{
                    .{ .mem = Memory.sib(.dword, .{
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
                    .{ .imm = lower.reloc(.{ .inst = index }) },
                });
                assert(lower.result_insts_len == pseudo_probe_adjust_loop_insts);
            },
            .pseudo_push_reg_list => try lower.pushPopRegList(.push, inst),
            .pseudo_pop_reg_list => try lower.pushPopRegList(.pop, inst),

            .pseudo_dbg_prologue_end_none,
            .pseudo_dbg_line_line_column,
            .pseudo_dbg_epilogue_begin_none,
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
    @setCold(true);
    assert(lower.err_msg == null);
    lower.err_msg = try ErrorMsg.create(lower.allocator, lower.src_loc, format, args);
    return error.LowerFail;
}

fn imm(lower: Lower, ops: Mir.Inst.Ops, i: u32) Immediate {
    return switch (ops) {
        .rri_s,
        .ri_s,
        .i_s,
        .mi_sib_s,
        .mi_rip_s,
        => Immediate.s(@bitCast(i32, i)),

        .rrri,
        .rri_u,
        .ri_u,
        .i_u,
        .mi_sib_u,
        .mi_rip_u,
        .rmi_sib,
        .rmi_rip,
        .mri_sib,
        .mri_rip,
        .rrm_sib,
        .rrm_rip,
        .rrmi_sib,
        .rrmi_rip,
        => Immediate.u(i),

        .ri64 => Immediate.u(lower.mir.extraData(Mir.Imm64, i).data.decode()),

        else => unreachable,
    };
}

fn mem(lower: Lower, ops: Mir.Inst.Ops, payload: u32) Memory {
    return lower.mir.resolveFrameLoc(switch (ops) {
        .rm_sib,
        .rmi_sib,
        .m_sib,
        .mi_sib_u,
        .mi_sib_s,
        .mr_sib,
        .mrr_sib,
        .mri_sib,
        .rrm_sib,
        .rrmi_sib,

        .pseudo_cmov_nz_or_p_rm_sib,
        .pseudo_set_z_and_np_m_sib,
        .pseudo_set_nz_or_p_m_sib,
        => lower.mir.extraData(Mir.MemorySib, payload).data.decode(),

        .rm_rip,
        .rmi_rip,
        .m_rip,
        .mi_rip_u,
        .mi_rip_s,
        .mr_rip,
        .mrr_rip,
        .mri_rip,
        .rrm_rip,
        .rrmi_rip,

        .pseudo_cmov_nz_or_p_rm_rip,
        .pseudo_set_z_and_np_m_rip,
        .pseudo_set_nz_or_p_m_rip,
        => lower.mir.extraData(Mir.MemoryRip, payload).data.decode(),

        .rax_moffs,
        .moffs_rax,
        => lower.mir.extraData(Mir.MemoryMoffs, payload).data.decode(),

        else => unreachable,
    });
}

fn reloc(lower: *Lower, target: Reloc.Target) Immediate {
    lower.result_relocs[lower.result_relocs_len] = .{
        .lowered_inst_index = lower.result_insts_len,
        .target = target,
    };
    lower.result_relocs_len += 1;
    return Immediate.s(0);
}

fn emit(lower: *Lower, prefix: Prefix, mnemonic: Mnemonic, ops: []const Operand) Error!void {
    lower.result_insts[lower.result_insts_len] = try Instruction.new(prefix, mnemonic, ops);
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
        .rrri => inst.data.rrri.fixes,
        .rri_s, .rri_u => inst.data.rri.fixes,
        .ri_s, .ri_u => inst.data.ri.fixes,
        .ri64, .rm_sib, .rm_rip, .mr_sib, .mr_rip => inst.data.rx.fixes,
        .mrr_sib, .mrr_rip, .rrm_sib, .rrm_rip => inst.data.rrx.fixes,
        .rmi_sib, .rmi_rip, .mri_sib, .mri_rip => inst.data.rix.fixes,
        .rrmi_sib, .rrmi_rip => inst.data.rrix.fixes,
        .mi_sib_u, .mi_rip_u, .mi_sib_s, .mi_rip_s => inst.data.x.fixes,
        .m_sib, .m_rip, .rax_moffs, .moffs_rax => inst.data.x.fixes,
        .extern_fn_reloc, .got_reloc, .direct_reloc, .import_reloc, .tlv_reloc => ._,
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
        inline for (@typeInfo(Mnemonic).Enum.fields) |field| max_len = @max(field.name.len, max_len);
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
            .{ .imm = lower.reloc(.{ .inst = inst.data.inst.inst }) },
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
        .rrri => &.{
            .{ .reg = inst.data.rrri.r1 },
            .{ .reg = inst.data.rrri.r2 },
            .{ .reg = inst.data.rrri.r3 },
            .{ .imm = lower.imm(inst.ops, inst.data.rrri.i) },
        },
        .ri_s, .ri_u => &.{
            .{ .reg = inst.data.ri.r1 },
            .{ .imm = lower.imm(inst.ops, inst.data.ri.i) },
        },
        .ri64 => &.{
            .{ .reg = inst.data.rx.r1 },
            .{ .imm = lower.imm(inst.ops, inst.data.rx.payload) },
        },
        .rri_s, .rri_u => &.{
            .{ .reg = inst.data.rri.r1 },
            .{ .reg = inst.data.rri.r2 },
            .{ .imm = lower.imm(inst.ops, inst.data.rri.i) },
        },
        .m_sib, .m_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.x.payload) },
        },
        .mi_sib_s, .mi_sib_u, .mi_rip_u, .mi_rip_s => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.x.payload + 1) },
            .{ .imm = lower.imm(
                inst.ops,
                lower.mir.extraData(Mir.Imm32, inst.data.x.payload).data.imm,
            ) },
        },
        .rm_sib, .rm_rip => &.{
            .{ .reg = inst.data.rx.r1 },
            .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
        },
        .rmi_sib, .rmi_rip => &.{
            .{ .reg = inst.data.rix.r1 },
            .{ .mem = lower.mem(inst.ops, inst.data.rix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.rix.i) },
        },
        .mr_sib, .mr_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
            .{ .reg = inst.data.rx.r1 },
        },
        .mrr_sib, .mrr_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.rrx.payload) },
            .{ .reg = inst.data.rrx.r1 },
            .{ .reg = inst.data.rrx.r2 },
        },
        .mri_sib, .mri_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.rix.payload) },
            .{ .reg = inst.data.rix.r1 },
            .{ .imm = lower.imm(inst.ops, inst.data.rix.i) },
        },
        .rrm_sib, .rrm_rip => &.{
            .{ .reg = inst.data.rrx.r1 },
            .{ .reg = inst.data.rrx.r2 },
            .{ .mem = lower.mem(inst.ops, inst.data.rrx.payload) },
        },
        .rrmi_sib, .rrmi_rip => &.{
            .{ .reg = inst.data.rrix.r1 },
            .{ .reg = inst.data.rrix.r2 },
            .{ .mem = lower.mem(inst.ops, inst.data.rrix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.rrix.i) },
        },
        .rax_moffs => &.{
            .{ .reg = .rax },
            .{ .mem = lower.mem(inst.ops, inst.data.x.payload) },
        },
        .moffs_rax => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.x.payload) },
            .{ .reg = .rax },
        },
        .extern_fn_reloc => &.{
            .{ .imm = lower.reloc(.{ .linker_extern_fn = inst.data.reloc }) },
        },
        .got_reloc, .direct_reloc, .import_reloc, .tlv_reloc => ops: {
            const reg = inst.data.rx.r1;
            const extra = lower.mir.extraData(Mir.Reloc, inst.data.rx.payload).data;
            _ = lower.reloc(switch (inst.ops) {
                .got_reloc => .{ .linker_got = extra },
                .direct_reloc => .{ .linker_direct = extra },
                .import_reloc => .{ .linker_import = extra },
                .tlv_reloc => .{ .linker_tlv = extra },
                else => unreachable,
            });
            break :ops &.{
                .{ .reg = reg },
                .{ .mem = Memory.rip(Memory.PtrSize.fromBitSize(reg.bitSize()), 0) },
            };
        },
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    });
}

fn pushPopRegList(lower: *Lower, comptime mnemonic: Mnemonic, inst: Mir.Inst) Error!void {
    const callee_preserved_regs = abi.getCalleePreservedRegs(lower.target.*);
    var it = inst.data.reg_list.iterator(.{ .direction = switch (mnemonic) {
        .push => .reverse,
        .pop => .forward,
        else => unreachable,
    } });
    while (it.next()) |i| try lower.emit(.none, mnemonic, &.{.{
        .reg = callee_preserved_regs[i],
    }});
}

const page_size: i32 = 1 << 12;

const abi = @import("abi.zig");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const encoder = @import("encoder.zig");
const std = @import("std");

const Air = @import("../../Air.zig");
const Allocator = std.mem.Allocator;
const ErrorMsg = Module.ErrorMsg;
const Immediate = bits.Immediate;
const Instruction = encoder.Instruction;
const Lower = @This();
const Memory = bits.Memory;
const Mir = @import("Mir.zig");
const Mnemonic = Instruction.Mnemonic;
const Module = @import("../../Module.zig");
const Operand = Instruction.Operand;
const Prefix = Instruction.Prefix;
const Register = bits.Register;
