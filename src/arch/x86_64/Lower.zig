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
        2, // cmovcc: cmovcc \ cmovcc
        3, // setcc: setcc \ setcc \ logicop
        2, // jcc: jcc \ jcc
        abi.Win64.callee_preserved_regs.len, // push_regs/pop_regs
        abi.SysV.callee_preserved_regs.len, // push_regs/pop_regs
    })
]Instruction = undefined,
result_relocs: [
    std.mem.max(usize, &.{
        2, // jcc: jcc \ jcc
    })
]Reloc = undefined,

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
        @"extern": Mir.Reloc,
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
        .adc,
        .add,
        .@"and",
        .bsf,
        .bsr,
        .bswap,
        .bt,
        .btc,
        .btr,
        .bts,
        .call,
        .cbw,
        .cwde,
        .cdqe,
        .cwd,
        .cdq,
        .cqo,
        .cmp,
        .cmpxchg,
        .div,
        .fisttp,
        .fld,
        .idiv,
        .imul,
        .int3,
        .jmp,
        .lea,
        .lfence,
        .lzcnt,
        .mfence,
        .mov,
        .movbe,
        .movd,
        .movq,
        .movzx,
        .mul,
        .neg,
        .nop,
        .not,
        .@"or",
        .pop,
        .popcnt,
        .push,
        .rcl,
        .rcr,
        .ret,
        .rol,
        .ror,
        .sal,
        .sar,
        .sbb,
        .sfence,
        .shl,
        .shld,
        .shr,
        .shrd,
        .sub,
        .syscall,
        .@"test",
        .tzcnt,
        .ud2,
        .xadd,
        .xchg,
        .xor,

        .addss,
        .andnps,
        .andps,
        .cmpss,
        .cvtsi2ss,
        .divss,
        .maxss,
        .minss,
        .movaps,
        .movss,
        .movups,
        .mulss,
        .orps,
        .pextrw,
        .pinsrw,
        .sqrtps,
        .sqrtss,
        .subss,
        .ucomiss,
        .xorps,

        .addsd,
        .andnpd,
        .andpd,
        .cmpsd,
        .cvtsd2ss,
        .cvtsi2sd,
        .cvtss2sd,
        .divsd,
        .maxsd,
        .minsd,
        .movsd,
        .mulsd,
        .orpd,
        .pshufhw,
        .pshuflw,
        .psrld,
        .psrlq,
        .psrlw,
        .punpckhbw,
        .punpckhdq,
        .punpckhqdq,
        .punpckhwd,
        .punpcklbw,
        .punpckldq,
        .punpcklqdq,
        .punpcklwd,
        .sqrtpd,
        .sqrtsd,
        .subsd,
        .ucomisd,
        .xorpd,

        .movddup,
        .movshdup,
        .movsldup,

        .roundsd,
        .roundss,

        .vcvtsd2ss,
        .vcvtsi2sd,
        .vcvtsi2ss,
        .vcvtss2sd,
        .vmovapd,
        .vmovaps,
        .vmovddup,
        .vmovsd,
        .vmovshdup,
        .vmovsldup,
        .vmovss,
        .vmovupd,
        .vmovups,
        .vpextrw,
        .vpinsrw,
        .vpshufhw,
        .vpshuflw,
        .vpsrld,
        .vpsrlq,
        .vpsrlw,
        .vpunpckhbw,
        .vpunpckhdq,
        .vpunpckhqdq,
        .vpunpckhwd,
        .vpunpcklbw,
        .vpunpckldq,
        .vpunpcklqdq,
        .vpunpcklwd,
        .vsqrtpd,
        .vsqrtps,
        .vsqrtsd,
        .vsqrtss,

        .vcvtph2ps,
        .vcvtps2ph,

        .vfmadd132pd,
        .vfmadd213pd,
        .vfmadd231pd,
        .vfmadd132ps,
        .vfmadd213ps,
        .vfmadd231ps,
        .vfmadd132sd,
        .vfmadd213sd,
        .vfmadd231sd,
        .vfmadd132ss,
        .vfmadd213ss,
        .vfmadd231ss,
        => try lower.mirGeneric(inst),

        .cmps,
        .lods,
        .movs,
        .scas,
        .stos,
        => try lower.mirString(inst),

        .cmpxchgb => try lower.mirCmpxchgBytes(inst),

        .jmp_reloc => try lower.emitInstWithReloc(.none, .jmp, &.{
            .{ .imm = Immediate.s(0) },
        }, .{ .inst = inst.data.inst }),

        .call_extern => try lower.emitInstWithReloc(.none, .call, &.{
            .{ .imm = Immediate.s(0) },
        }, .{ .@"extern" = inst.data.relocation }),

        .lea_linker => try lower.mirLinker(.lea, inst),
        .mov_linker => try lower.mirLinker(.mov, inst),

        .mov_moffs => try lower.mirMovMoffs(inst),

        .movsx => try lower.mirMovsx(inst),
        .cmovcc => try lower.mirCmovcc(inst),
        .setcc => try lower.mirSetcc(inst),
        .jcc => try lower.mirJcc(index, inst),

        .push_regs => try lower.mirRegisterList(.push, inst),
        .pop_regs => try lower.mirRegisterList(.pop, inst),

        .dbg_line,
        .dbg_prologue_end,
        .dbg_epilogue_begin,
        .dead,
        => {},
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

fn mnem_cc(comptime base: @Type(.EnumLiteral), cc: bits.Condition) Mnemonic {
    return switch (cc) {
        inline else => |c| if (@hasField(Mnemonic, @tagName(base) ++ @tagName(c)))
            @field(Mnemonic, @tagName(base) ++ @tagName(c))
        else
            unreachable,
    };
}

fn imm(lower: Lower, ops: Mir.Inst.Ops, i: u32) Immediate {
    return switch (ops) {
        .rri_s,
        .ri_s,
        .i_s,
        .mi_sib_s,
        .mi_rip_s,
        .lock_mi_sib_s,
        .lock_mi_rip_s,
        => Immediate.s(@bitCast(i32, i)),

        .rri_u,
        .ri_u,
        .i_u,
        .mi_sib_u,
        .mi_rip_u,
        .lock_mi_sib_u,
        .lock_mi_rip_u,
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
        .rm_sib_cc,
        .rmi_sib,
        .m_sib,
        .m_sib_cc,
        .mi_sib_u,
        .mi_sib_s,
        .mr_sib,
        .mrr_sib,
        .mri_sib,
        .rrm_sib,
        .rrmi_sib,
        .lock_m_sib,
        .lock_mi_sib_u,
        .lock_mi_sib_s,
        .lock_mr_sib,
        => lower.mir.extraData(Mir.MemorySib, payload).data.decode(),

        .rm_rip,
        .rm_rip_cc,
        .rmi_rip,
        .m_rip,
        .m_rip_cc,
        .mi_rip_u,
        .mi_rip_s,
        .mr_rip,
        .mrr_rip,
        .mri_rip,
        .rrm_rip,
        .rrmi_rip,
        .lock_m_rip,
        .lock_mi_rip_u,
        .lock_mi_rip_s,
        .lock_mr_rip,
        => lower.mir.extraData(Mir.MemoryRip, payload).data.decode(),

        .rax_moffs,
        .moffs_rax,
        .lock_moffs_rax,
        => lower.mir.extraData(Mir.MemoryMoffs, payload).data.decode(),

        else => unreachable,
    });
}

fn emitInst(lower: *Lower, prefix: Prefix, mnemonic: Mnemonic, ops: []const Operand) Error!void {
    lower.result_insts[lower.result_insts_len] = try Instruction.new(prefix, mnemonic, ops);
    lower.result_insts_len += 1;
}

fn emitInstWithReloc(
    lower: *Lower,
    prefix: Prefix,
    mnemonic: Mnemonic,
    ops: []const Operand,
    target: Reloc.Target,
) Error!void {
    lower.result_relocs[lower.result_relocs_len] = .{
        .lowered_inst_index = lower.result_insts_len,
        .target = target,
    };
    lower.result_relocs_len += 1;
    try lower.emitInst(prefix, mnemonic, ops);
}

fn mirGeneric(lower: *Lower, inst: Mir.Inst) Error!void {
    try lower.emitInst(switch (inst.ops) {
        else => .none,
        .lock_m_sib,
        .lock_m_rip,
        .lock_mi_sib_u,
        .lock_mi_rip_u,
        .lock_mi_sib_s,
        .lock_mi_rip_s,
        .lock_mr_sib,
        .lock_mr_rip,
        .lock_moffs_rax,
        => .lock,
    }, switch (inst.tag) {
        inline else => |tag| if (@hasField(Mnemonic, @tagName(tag)))
            @field(Mnemonic, @tagName(tag))
        else
            unreachable,
    }, switch (inst.ops) {
        .none => &.{},
        .i_s, .i_u => &.{
            .{ .imm = lower.imm(inst.ops, inst.data.i) },
        },
        .r => &.{
            .{ .reg = inst.data.r },
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
        .ri_s, .ri_u => &.{
            .{ .reg = inst.data.ri.r },
            .{ .imm = lower.imm(inst.ops, inst.data.ri.i) },
        },
        .ri64 => &.{
            .{ .reg = inst.data.rx.r },
            .{ .imm = lower.imm(inst.ops, inst.data.rx.payload) },
        },
        .rri_s, .rri_u => &.{
            .{ .reg = inst.data.rri.r1 },
            .{ .reg = inst.data.rri.r2 },
            .{ .imm = lower.imm(inst.ops, inst.data.rri.i) },
        },
        .m_sib, .lock_m_sib, .m_rip, .lock_m_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.payload) },
        },
        .mi_sib_s,
        .lock_mi_sib_s,
        .mi_sib_u,
        .lock_mi_sib_u,
        .mi_rip_u,
        .lock_mi_rip_u,
        .mi_rip_s,
        .lock_mi_rip_s,
        => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.ix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.ix.i) },
        },
        .rm_sib, .rm_rip => &.{
            .{ .reg = inst.data.rx.r },
            .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
        },
        .rmi_sib, .rmi_rip => &.{
            .{ .reg = inst.data.rix.r },
            .{ .mem = lower.mem(inst.ops, inst.data.rix.payload) },
            .{ .imm = lower.imm(inst.ops, inst.data.rix.i) },
        },
        .mr_sib, .lock_mr_sib, .mr_rip, .lock_mr_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
            .{ .reg = inst.data.rx.r },
        },
        .mrr_sib, .mrr_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.rrx.payload) },
            .{ .reg = inst.data.rrx.r1 },
            .{ .reg = inst.data.rrx.r2 },
        },
        .mri_sib, .mri_rip => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.rix.payload) },
            .{ .reg = inst.data.rix.r },
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
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    });
}

fn mirString(lower: *Lower, inst: Mir.Inst) Error!void {
    switch (inst.ops) {
        .string => try lower.emitInst(switch (inst.data.string.repeat) {
            inline else => |repeat| @field(Prefix, @tagName(repeat)),
        }, switch (inst.tag) {
            inline .cmps, .lods, .movs, .scas, .stos => |tag| switch (inst.data.string.width) {
                inline else => |width| @field(Mnemonic, @tagName(tag) ++ @tagName(width)),
            },
            else => unreachable,
        }, &.{}),
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    }
}

fn mirCmpxchgBytes(lower: *Lower, inst: Mir.Inst) Error!void {
    const ops: [1]Operand = switch (inst.ops) {
        .m_sib, .lock_m_sib, .m_rip, .lock_m_rip => .{
            .{ .mem = lower.mem(inst.ops, inst.data.payload) },
        },
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    };
    try lower.emitInst(switch (inst.ops) {
        .m_sib, .m_rip => .none,
        .lock_m_sib, .lock_m_rip => .lock,
        else => unreachable,
    }, switch (@divExact(ops[0].bitSize(), 8)) {
        8 => .cmpxchg8b,
        16 => .cmpxchg16b,
        else => return lower.fail("invalid operand for {s}", .{@tagName(inst.tag)}),
    }, &ops);
}

fn mirMovMoffs(lower: *Lower, inst: Mir.Inst) Error!void {
    try lower.emitInst(switch (inst.ops) {
        .rax_moffs, .moffs_rax => .none,
        .lock_moffs_rax => .lock,
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    }, .mov, switch (inst.ops) {
        .rax_moffs => &.{
            .{ .reg = .rax },
            .{ .mem = lower.mem(inst.ops, inst.data.payload) },
        },
        .moffs_rax, .lock_moffs_rax => &.{
            .{ .mem = lower.mem(inst.ops, inst.data.payload) },
            .{ .reg = .rax },
        },
        else => unreachable,
    });
}

fn mirMovsx(lower: *Lower, inst: Mir.Inst) Error!void {
    const ops: [2]Operand = switch (inst.ops) {
        .rr => .{
            .{ .reg = inst.data.rr.r1 },
            .{ .reg = inst.data.rr.r2 },
        },
        .rm_sib, .rm_rip => .{
            .{ .reg = inst.data.rx.r },
            .{ .mem = lower.mem(inst.ops, inst.data.rx.payload) },
        },
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    };
    try lower.emitInst(.none, switch (ops[0].bitSize()) {
        32, 64 => switch (ops[1].bitSize()) {
            32 => .movsxd,
            else => .movsx,
        },
        else => .movsx,
    }, &ops);
}

fn mirCmovcc(lower: *Lower, inst: Mir.Inst) Error!void {
    const data: struct { cc: bits.Condition, ops: [2]Operand } = switch (inst.ops) {
        .rr_cc => .{ .cc = inst.data.rr_cc.cc, .ops = .{
            .{ .reg = inst.data.rr_cc.r1 },
            .{ .reg = inst.data.rr_cc.r2 },
        } },
        .rm_sib_cc, .rm_rip_cc => .{ .cc = inst.data.rx_cc.cc, .ops = .{
            .{ .reg = inst.data.rx_cc.r },
            .{ .mem = lower.mem(inst.ops, inst.data.rx_cc.payload) },
        } },
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    };
    switch (data.cc) {
        else => |cc| try lower.emitInst(.none, mnem_cc(.cmov, cc), &data.ops),
        .z_and_np => {
            try lower.emitInst(.none, mnem_cc(.cmov, .nz), &.{ data.ops[1], data.ops[0] });
            try lower.emitInst(.none, mnem_cc(.cmov, .np), &data.ops);
        },
        .nz_or_p => {
            try lower.emitInst(.none, mnem_cc(.cmov, .nz), &data.ops);
            try lower.emitInst(.none, mnem_cc(.cmov, .p), &data.ops);
        },
    }
}

fn mirSetcc(lower: *Lower, inst: Mir.Inst) Error!void {
    const data: struct { cc: bits.Condition, ops: [2]Operand } = switch (inst.ops) {
        .r_cc => .{ .cc = inst.data.r_cc.cc, .ops = .{
            .{ .reg = inst.data.r_cc.r },
            .{ .reg = inst.data.r_cc.scratch },
        } },
        .m_sib_cc, .m_rip_cc => .{ .cc = inst.data.x_cc.cc, .ops = .{
            .{ .mem = lower.mem(inst.ops, inst.data.x_cc.payload) },
            .{ .reg = inst.data.x_cc.scratch },
        } },
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    };
    switch (data.cc) {
        else => |cc| try lower.emitInst(.none, mnem_cc(.set, cc), data.ops[0..1]),
        .z_and_np => {
            try lower.emitInst(.none, mnem_cc(.set, .z), data.ops[0..1]);
            try lower.emitInst(.none, mnem_cc(.set, .np), data.ops[1..2]);
            try lower.emitInst(.none, .@"and", data.ops[0..2]);
        },
        .nz_or_p => {
            try lower.emitInst(.none, mnem_cc(.set, .nz), data.ops[0..1]);
            try lower.emitInst(.none, mnem_cc(.set, .p), data.ops[1..2]);
            try lower.emitInst(.none, .@"or", data.ops[0..2]);
        },
    }
}

fn mirJcc(lower: *Lower, index: Mir.Inst.Index, inst: Mir.Inst) Error!void {
    switch (inst.data.inst_cc.cc) {
        else => |cc| try lower.emitInstWithReloc(.none, mnem_cc(.j, cc), &.{
            .{ .imm = Immediate.s(0) },
        }, .{ .inst = inst.data.inst_cc.inst }),
        .z_and_np => {
            try lower.emitInstWithReloc(.none, mnem_cc(.j, .nz), &.{
                .{ .imm = Immediate.s(0) },
            }, .{ .inst = index + 1 });
            try lower.emitInstWithReloc(.none, mnem_cc(.j, .np), &.{
                .{ .imm = Immediate.s(0) },
            }, .{ .inst = inst.data.inst_cc.inst });
        },
        .nz_or_p => {
            try lower.emitInstWithReloc(.none, mnem_cc(.j, .nz), &.{
                .{ .imm = Immediate.s(0) },
            }, .{ .inst = inst.data.inst_cc.inst });
            try lower.emitInstWithReloc(.none, mnem_cc(.j, .p), &.{
                .{ .imm = Immediate.s(0) },
            }, .{ .inst = inst.data.inst_cc.inst });
        },
    }
}

fn mirRegisterList(lower: *Lower, comptime mnemonic: Mnemonic, inst: Mir.Inst) Error!void {
    const reg_list = Mir.RegisterList.fromInt(inst.data.payload);
    const callee_preserved_regs = abi.getCalleePreservedRegs(lower.target.*);
    var it = reg_list.iterator(.{ .direction = switch (mnemonic) {
        .push => .reverse,
        .pop => .forward,
        else => unreachable,
    } });
    while (it.next()) |i| try lower.emitInst(.none, mnemonic, &.{.{ .reg = callee_preserved_regs[i] }});
}

fn mirLinker(lower: *Lower, mnemonic: Mnemonic, inst: Mir.Inst) Error!void {
    const reloc = lower.mir.extraData(Mir.Reloc, inst.data.rx.payload).data;
    try lower.emitInstWithReloc(.none, mnemonic, &.{
        .{ .reg = inst.data.rx.r },
        .{ .mem = Memory.rip(Memory.PtrSize.fromBitSize(inst.data.rx.r.bitSize()), 0) },
    }, switch (inst.ops) {
        .got_reloc => .{ .linker_got = reloc },
        .direct_reloc => .{ .linker_direct = reloc },
        .import_reloc => .{ .linker_import = reloc },
        .tlv_reloc => .{ .linker_tlv = reloc },
        else => unreachable,
    });
}

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
