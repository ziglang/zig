//! This file contains the functionality for lowering x86_64 MIR to Instructions

allocator: Allocator,
mir: Mir,
target: *const std.Target,
err_msg: ?*ErrorMsg = null,
src_loc: Module.SrcLoc,
result: [
    std.mem.max(usize, &.{
        abi.Win64.callee_preserved_regs.len,
        abi.SysV.callee_preserved_regs.len,
    })
]Instruction = undefined,
result_len: usize = undefined,

pub const Error = error{
    OutOfMemory,
    LowerFail,
    InvalidInstruction,
    CannotEncode,
};

/// The returned slice is overwritten by the next call to lowerMir.
pub fn lowerMir(lower: *Lower, inst: Mir.Inst) Error![]const Instruction {
    lower.result = undefined;
    errdefer lower.result = undefined;
    lower.result_len = 0;
    defer lower.result_len = undefined;

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
        .cmpss,
        .divss,
        .maxss,
        .minss,
        .movss,
        .mulss,
        .roundss,
        .subss,
        .ucomiss,
        .addsd,
        .cmpsd,
        .divsd,
        .maxsd,
        .minsd,
        .movsd,
        .mulsd,
        .roundsd,
        .subsd,
        .ucomisd,
        => try lower.mirGeneric(inst),

        .cmps,
        .lods,
        .movs,
        .scas,
        .stos,
        => try lower.mirString(inst),

        .cmpxchgb => try lower.mirCmpxchgBytes(inst),

        .jmp_reloc => try lower.emit(.none, .jmp, &.{.{ .imm = Immediate.s(0) }}),

        .call_extern => try lower.emit(.none, .call, &.{.{ .imm = Immediate.s(0) }}),

        .lea_linker => try lower.mirLeaLinker(inst),
        .mov_linker => try lower.mirMovLinker(inst),

        .mov_moffs => try lower.mirMovMoffs(inst),

        .movsx => try lower.mirMovsx(inst),
        .cmovcc => try lower.mirCmovcc(inst),
        .setcc => try lower.mirSetcc(inst),
        .jcc => try lower.emit(.none, mnem_cc(.j, inst.data.inst_cc.cc), &.{.{ .imm = Immediate.s(0) }}),

        .push_regs, .pop_regs => try lower.mirPushPopRegisterList(inst),

        .dbg_line,
        .dbg_prologue_end,
        .dbg_epilogue_begin,
        .dead,
        => {},
    }

    return lower.result[0..lower.result_len];
}

pub fn fail(lower: *Lower, comptime format: []const u8, args: anytype) Error {
    @setCold(true);
    assert(lower.err_msg == null);
    lower.err_msg = try ErrorMsg.create(lower.allocator, lower.src_loc, format, args);
    return error.LowerFail;
}

fn mnem_cc(comptime base: @Type(.EnumLiteral), cc: bits.Condition) Mnemonic {
    return switch (cc) {
        inline else => |c| @field(Mnemonic, @tagName(base) ++ @tagName(c)),
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
        .mri_sib,
        .mri_rip,
        => Immediate.u(i),

        .ri64 => Immediate.u(lower.mir.extraData(Mir.Imm64, i).data.decode()),

        else => unreachable,
    };
}

fn mem(lower: Lower, ops: Mir.Inst.Ops, payload: u32) Memory {
    return switch (ops) {
        .rm_sib,
        .rm_sib_cc,
        .m_sib,
        .m_sib_cc,
        .mi_sib_u,
        .mi_sib_s,
        .mr_sib,
        .mrr_sib,
        .mri_sib,
        .lock_m_sib,
        .lock_mi_sib_u,
        .lock_mi_sib_s,
        .lock_mr_sib,
        => lower.mir.extraData(Mir.MemorySib, payload).data.decode(),

        .rm_rip,
        .rm_rip_cc,
        .m_rip,
        .m_rip_cc,
        .mi_rip_u,
        .mi_rip_s,
        .mr_rip,
        .mrr_rip,
        .mri_rip,
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
    };
}

fn emit(lower: *Lower, prefix: Prefix, mnemonic: Mnemonic, ops: []const Operand) Error!void {
    lower.result[lower.result_len] = try Instruction.new(prefix, mnemonic, ops);
    lower.result_len += 1;
}

fn mirGeneric(lower: *Lower, inst: Mir.Inst) Error!void {
    try lower.emit(switch (inst.ops) {
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
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    });
}

fn mirString(lower: *Lower, inst: Mir.Inst) Error!void {
    switch (inst.ops) {
        .string => try lower.emit(switch (inst.data.string.repeat) {
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
    try lower.emit(switch (inst.ops) {
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
    try lower.emit(switch (inst.ops) {
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
    try lower.emit(.none, switch (ops[0].bitSize()) {
        32, 64 => switch (ops[1].bitSize()) {
            32 => .movsxd,
            else => .movsx,
        },
        else => .movsx,
    }, &ops);
}

fn mirCmovcc(lower: *Lower, inst: Mir.Inst) Error!void {
    switch (inst.ops) {
        .rr_cc => try lower.emit(.none, mnem_cc(.cmov, inst.data.rr_cc.cc), &.{
            .{ .reg = inst.data.rr_cc.r1 },
            .{ .reg = inst.data.rr_cc.r2 },
        }),
        .rm_sib_cc, .rm_rip_cc => try lower.emit(.none, mnem_cc(.cmov, inst.data.rx_cc.cc), &.{
            .{ .reg = inst.data.rx_cc.r },
            .{ .mem = lower.mem(inst.ops, inst.data.rx_cc.payload) },
        }),
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    }
}

fn mirSetcc(lower: *Lower, inst: Mir.Inst) Error!void {
    switch (inst.ops) {
        .r_cc => try lower.emit(.none, mnem_cc(.set, inst.data.r_cc.cc), &.{
            .{ .reg = inst.data.r_cc.r },
        }),
        .m_sib_cc, .m_rip_cc => try lower.emit(.none, mnem_cc(.set, inst.data.x_cc.cc), &.{
            .{ .mem = lower.mem(inst.ops, inst.data.x_cc.payload) },
        }),
        else => return lower.fail("TODO lower {s} {s}", .{ @tagName(inst.tag), @tagName(inst.ops) }),
    }
}

fn mirPushPopRegisterList(lower: *Lower, inst: Mir.Inst) Error!void {
    const save_reg_list = lower.mir.extraData(Mir.SaveRegisterList, inst.data.payload).data;
    const base = @intToEnum(Register, save_reg_list.base_reg);
    var disp: i32 = -@intCast(i32, save_reg_list.stack_end);
    const reg_list = Mir.RegisterList.fromInt(save_reg_list.register_list);
    const callee_preserved_regs = abi.getCalleePreservedRegs(lower.target.*);
    for (callee_preserved_regs) |callee_preserved_reg| {
        if (!reg_list.isSet(callee_preserved_regs, callee_preserved_reg)) continue;
        const reg_op = Operand{ .reg = callee_preserved_reg };
        const mem_op = Operand{ .mem = Memory.sib(.qword, .{ .base = base, .disp = disp }) };
        try lower.emit(.none, .mov, switch (inst.tag) {
            .push_regs => &.{ mem_op, reg_op },
            .pop_regs => &.{ reg_op, mem_op },
            else => unreachable,
        });
        disp += 8;
    }
}

fn mirLeaLinker(lower: *Lower, inst: Mir.Inst) Error!void {
    const metadata = lower.mir.extraData(Mir.LeaRegisterReloc, inst.data.payload).data;
    const reg = @intToEnum(Register, metadata.reg);
    try lower.emit(.none, .lea, &.{
        .{ .reg = reg },
        .{ .mem = Memory.rip(Memory.PtrSize.fromBitSize(reg.bitSize()), 0) },
    });
}

fn mirMovLinker(lower: *Lower, inst: Mir.Inst) Error!void {
    const metadata = lower.mir.extraData(Mir.LeaRegisterReloc, inst.data.payload).data;
    const reg = @intToEnum(Register, metadata.reg);
    try lower.emit(.none, .mov, &.{
        .{ .reg = reg },
        .{ .mem = Memory.rip(Memory.PtrSize.fromBitSize(reg.bitSize()), 0) },
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
