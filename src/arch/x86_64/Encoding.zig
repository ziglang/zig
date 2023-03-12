const Encoding = @This();

const std = @import("std");
const assert = std.debug.assert;
const math = std.math;

const bits = @import("bits.zig");
const encoder = @import("encoder.zig");
const Instruction = encoder.Instruction;
const Register = bits.Register;
const Rex = encoder.Rex;
const LegacyPrefixes = encoder.LegacyPrefixes;

const table = @import("encodings.zig").table;

mnemonic: Mnemonic,
op_en: OpEn,
op1: Op,
op2: Op,
op3: Op,
op4: Op,
opc_len: u2,
opc: [3]u8,
modrm_ext: u3,
mode: Mode,

pub fn findByMnemonic(mnemonic: Mnemonic, args: struct {
    op1: Instruction.Operand,
    op2: Instruction.Operand,
    op3: Instruction.Operand,
    op4: Instruction.Operand,
}) !?Encoding {
    const input_op1 = Op.fromOperand(args.op1);
    const input_op2 = Op.fromOperand(args.op2);
    const input_op3 = Op.fromOperand(args.op3);
    const input_op4 = Op.fromOperand(args.op4);

    const ops = &[_]Instruction.Operand{ args.op1, args.op2, args.op3, args.op4 };
    const rex_required = for (ops) |op| switch (op) {
        .reg => |r| switch (r) {
            .spl, .bpl, .sil, .dil => break true,
            else => {},
        },
        else => {},
    } else false;
    const rex_invalid = for (ops) |op| switch (op) {
        .reg => |r| switch (r) {
            .ah, .bh, .ch, .dh => break true,
            else => {},
        },
        else => {},
    } else false;
    const rex_extended = for (ops) |op| switch (op) {
        .reg => |r| if (r.isExtended()) break true,
        .mem => |m| {
            if (m.base()) |base| {
                if (base.isExtended()) break true;
            }
            if (m.scaleIndex()) |si| {
                if (si.index.isExtended()) break true;
            }
        },
        else => {},
    } else false;

    if ((rex_required or rex_extended) and rex_invalid) return error.CannotEncode;

    // TODO work out what is the maximum number of variants we can actually find in one swoop.
    var candidates: [10]Encoding = undefined;
    var count: usize = 0;
    for (table) |entry| {
        const enc = Encoding{
            .mnemonic = entry[0],
            .op_en = entry[1],
            .op1 = entry[2],
            .op2 = entry[3],
            .op3 = entry[4],
            .op4 = entry[5],
            .opc_len = entry[6],
            .opc = .{ entry[7], entry[8], entry[9] },
            .modrm_ext = entry[10],
            .mode = entry[11],
        };
        if (enc.mnemonic == mnemonic and
            input_op1.isSubset(enc.op1, enc.mode) and
            input_op2.isSubset(enc.op2, enc.mode) and
            input_op3.isSubset(enc.op3, enc.mode) and
            input_op4.isSubset(enc.op4, enc.mode))
        {
            if (rex_required) {
                switch (enc.mode) {
                    .rex, .long => {
                        candidates[count] = enc;
                        count += 1;
                    },
                    else => {},
                }
            } else {
                if (enc.mode != .rex) {
                    candidates[count] = enc;
                    count += 1;
                }
            }
        }
    }

    if (count == 0) return null;
    if (count == 1) return candidates[0];

    const EncodingLength = struct {
        fn estimate(encoding: Encoding, params: struct {
            op1: Instruction.Operand,
            op2: Instruction.Operand,
            op3: Instruction.Operand,
            op4: Instruction.Operand,
        }) usize {
            var inst = Instruction{
                .op1 = params.op1,
                .op2 = params.op2,
                .op3 = params.op3,
                .op4 = params.op4,
                .encoding = encoding,
            };
            var cwriter = std.io.countingWriter(std.io.null_writer);
            inst.encode(cwriter.writer()) catch unreachable; // Not allowed to fail here unless OOM.
            return @intCast(usize, cwriter.bytes_written);
        }
    };

    var shortest_encoding: ?struct {
        index: usize,
        len: usize,
    } = null;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const candidate = candidates[i];
        switch (candidate.mode) {
            .long, .rex => if (rex_invalid) return error.CannotEncode,
            else => {},
        }

        const len = EncodingLength.estimate(candidate, .{
            .op1 = args.op1,
            .op2 = args.op2,
            .op3 = args.op3,
            .op4 = args.op4,
        });
        const current = shortest_encoding orelse {
            shortest_encoding = .{ .index = i, .len = len };
            continue;
        };
        if (len < current.len) {
            shortest_encoding = .{ .index = i, .len = len };
        }
    }

    return candidates[shortest_encoding.?.index];
}

/// Returns first matching encoding by opcode.
pub fn findByOpcode(opc: []const u8, prefixes: struct {
    legacy: LegacyPrefixes,
    rex: Rex,
}, modrm_ext: ?u3) ?Encoding {
    for (table) |entry| {
        const enc = Encoding{
            .mnemonic = entry[0],
            .op_en = entry[1],
            .op1 = entry[2],
            .op2 = entry[3],
            .op3 = entry[4],
            .op4 = entry[5],
            .opc_len = entry[6],
            .opc = .{ entry[7], entry[8], entry[9] },
            .modrm_ext = entry[10],
            .mode = entry[11],
        };
        const match = match: {
            if (modrm_ext) |ext| {
                break :match ext == enc.modrm_ext and std.mem.eql(u8, enc.opcode(), opc);
            }
            break :match std.mem.eql(u8, enc.opcode(), opc);
        };
        if (match) {
            if (prefixes.rex.w) {
                switch (enc.mode) {
                    .fpu, .sse, .sse2, .none => {},
                    .long, .rex => return enc,
                }
            } else if (prefixes.rex.present and !prefixes.rex.isSet()) {
                if (enc.mode == .rex) return enc;
            } else if (prefixes.legacy.prefix_66) {
                switch (enc.operandBitSize()) {
                    16 => return enc,
                    else => {},
                }
            } else {
                if (enc.mode == .none) {
                    switch (enc.operandBitSize()) {
                        16 => {},
                        else => return enc,
                    }
                }
            }
        }
    }
    return null;
}

pub fn opcode(encoding: *const Encoding) []const u8 {
    return encoding.opc[0..encoding.opc_len];
}

pub fn mandatoryPrefix(encoding: *const Encoding) ?u8 {
    const prefix = encoding.opc[0];
    return switch (prefix) {
        0x66, 0xf2, 0xf3 => prefix,
        else => null,
    };
}

pub fn modRmExt(encoding: Encoding) u3 {
    return switch (encoding.op_en) {
        .m, .mi, .m1, .mc => encoding.modrm_ext,
        else => unreachable,
    };
}

pub fn operandBitSize(encoding: Encoding) u64 {
    if (encoding.mode == .long) return 64;
    const bit_size: u64 = switch (encoding.op_en) {
        .np => switch (encoding.op1) {
            .o16 => 16,
            .o32 => 32,
            .o64 => 64,
            else => 32,
        },
        .td => encoding.op2.bitSize(),
        else => encoding.op1.bitSize(),
    };
    return bit_size;
}

pub fn format(
    encoding: Encoding,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;
    switch (encoding.mode) {
        .long => try writer.writeAll("REX.W + "),
        else => {},
    }

    for (encoding.opcode()) |byte| {
        try writer.print("{x:0>2} ", .{byte});
    }

    switch (encoding.op_en) {
        .np, .fd, .td, .i, .zi, .d => {},
        .o, .oi => {
            const tag = switch (encoding.op1) {
                .r8 => "rb",
                .r16 => "rw",
                .r32 => "rd",
                .r64 => "rd",
                else => unreachable,
            };
            try writer.print("+{s} ", .{tag});
        },
        .m, .mi, .m1, .mc => try writer.print("/{d} ", .{encoding.modRmExt()}),
        .mr, .rm, .rmi => try writer.writeAll("/r "),
    }

    switch (encoding.op_en) {
        .i, .d, .zi, .oi, .mi, .rmi => {
            const op = switch (encoding.op_en) {
                .i, .d => encoding.op1,
                .zi, .oi, .mi => encoding.op2,
                .rmi => encoding.op3,
                else => unreachable,
            };
            const tag = switch (op) {
                .imm8, .imm8s => "ib",
                .imm16, .imm16s => "iw",
                .imm32, .imm32s => "id",
                .imm64 => "io",
                .rel8 => "cb",
                .rel16 => "cw",
                .rel32 => "cd",
                else => unreachable,
            };
            try writer.print("{s} ", .{tag});
        },
        .np, .fd, .td, .o, .m, .m1, .mc, .mr, .rm => {},
    }

    try writer.print("{s} ", .{@tagName(encoding.mnemonic)});

    const ops = &[_]Op{ encoding.op1, encoding.op2, encoding.op3, encoding.op4 };
    for (ops) |op| switch (op) {
        .none, .o16, .o32, .o64 => break,
        else => try writer.print("{s} ", .{@tagName(op)}),
    };

    const op_en = switch (encoding.op_en) {
        .zi => .i,
        else => |op_en| op_en,
    };
    try writer.print("{s}", .{@tagName(op_en)});
}

pub const Mnemonic = enum {
    // zig fmt: off
    // General-purpose
    adc, add, @"and",
    call, cbw, cwde, cdqe, cwd, cdq, cqo, cmp,
    cmova, cmovae, cmovb, cmovbe, cmovc, cmove, cmovg, cmovge, cmovl, cmovle, cmovna,
    cmovnae, cmovnb, cmovnbe, cmovnc, cmovne, cmovng, cmovnge, cmovnl, cmovnle, cmovno,
    cmovnp, cmovns, cmovnz, cmovo, cmovp, cmovpe, cmovpo, cmovs, cmovz,
    div,
    fisttp, fld,
    idiv, imul, int3,
    ja, jae, jb, jbe, jc, jrcxz, je, jg, jge, jl, jle, jna, jnae, jnb, jnbe,
    jnc, jne, jng, jnge, jnl, jnle, jno, jnp, jns, jnz, jo, jp, jpe, jpo, js, jz,
    jmp, 
    lea,
    mov, movsx, movsxd, movzx, mul,
    nop,
    @"or",
    pop, push,
    ret,
    sal, sar, sbb, shl, shr, sub, syscall,
    seta, setae, setb, setbe, setc, sete, setg, setge, setl, setle, setna, setnae,
    setnb, setnbe, setnc, setne, setng, setnge, setnl, setnle, setno, setnp, setns,
    setnz, seto, setp, setpe, setpo, sets, setz,
    @"test",
    ud2,
    xor,
    // SSE
    addss,
    cmpss,
    movss,
    ucomiss,
    // SSE2
    addsd,
    cmpsd,
    movq, movsd,
    ucomisd,
    // zig fmt: on
};

pub const OpEn = enum {
    // zig fmt: off
    np,
    o, oi,
    i, zi,
    d, m,
    fd, td,
    m1, mc, mi, mr, rm, rmi,
    // zig fmt: on
};

pub const Op = enum {
    // zig fmt: off
    none,
    o16, o32, o64,
    unity,
    imm8, imm16, imm32, imm64,
    imm8s, imm16s, imm32s,
    al, ax, eax, rax,
    cl,
    r8, r16, r32, r64,
    rm8, rm16, rm32, rm64,
    m8, m16, m32, m64, m80,
    rel8, rel16, rel32,
    m,
    moffs,
    sreg,
    xmm, xmm_m32, xmm_m64,
    // zig fmt: on

    pub fn fromOperand(operand: Instruction.Operand) Op {
        switch (operand) {
            .none => return .none,

            .reg => |reg| {
                switch (reg.class()) {
                    .segment => return .sreg,
                    .floating_point => return switch (reg.bitSize()) {
                        128 => .xmm,
                        else => unreachable,
                    },
                    .general_purpose => {
                        if (reg.to64() == .rax) return switch (reg) {
                            .al => .al,
                            .ax => .ax,
                            .eax => .eax,
                            .rax => .rax,
                            else => unreachable,
                        };
                        if (reg == .cl) return .cl;
                        return switch (reg.bitSize()) {
                            8 => .r8,
                            16 => .r16,
                            32 => .r32,
                            64 => .r64,
                            else => unreachable,
                        };
                    },
                }
            },

            .mem => |mem| switch (mem) {
                .moffs => return .moffs,
                .sib, .rip => {
                    const bit_size = mem.bitSize();
                    return switch (bit_size) {
                        8 => .m8,
                        16 => .m16,
                        32 => .m32,
                        64 => .m64,
                        80 => .m80,
                        else => unreachable,
                    };
                },
            },

            .imm => |imm| {
                switch (imm) {
                    .signed => |x| {
                        if (x == 1) return .unity;
                        if (math.cast(i8, x)) |_| return .imm8s;
                        if (math.cast(i16, x)) |_| return .imm16s;
                        return .imm32s;
                    },
                    .unsigned => |x| {
                        if (x == 1) return .unity;
                        if (math.cast(i8, x)) |_| return .imm8s;
                        if (math.cast(u8, x)) |_| return .imm8;
                        if (math.cast(i16, x)) |_| return .imm16s;
                        if (math.cast(u16, x)) |_| return .imm16;
                        if (math.cast(i32, x)) |_| return .imm32s;
                        if (math.cast(u32, x)) |_| return .imm32;
                        return .imm64;
                    },
                }
            },
        }
    }

    pub fn bitSize(op: Op) u64 {
        return switch (op) {
            .none, .o16, .o32, .o64, .moffs, .m, .sreg => unreachable,
            .unity => 1,
            .imm8, .imm8s, .al, .cl, .r8, .m8, .rm8, .rel8 => 8,
            .imm16, .imm16s, .ax, .r16, .m16, .rm16, .rel16 => 16,
            .imm32, .imm32s, .eax, .r32, .m32, .rm32, .rel32, .xmm_m32 => 32,
            .imm64, .rax, .r64, .m64, .rm64, .xmm_m64 => 64,
            .m80 => 80,
            .xmm => 128,
        };
    }

    pub fn isSigned(op: Op) bool {
        return switch (op) {
            .unity, .imm8, .imm16, .imm32, .imm64 => false,
            .imm8s, .imm16s, .imm32s => true,
            else => unreachable,
        };
    }

    pub fn isUnsigned(op: Op) bool {
        return !op.isSigned();
    }

    pub fn isRegister(op: Op) bool {
        // zig fmt: off
        return switch (op) {
            .cl,
            .al, .ax, .eax, .rax,
            .r8, .r16, .r32, .r64,
            .rm8, .rm16, .rm32, .rm64,
            .xmm, .xmm_m32, .xmm_m64,
            =>  true,
            else => false,
        };
        // zig fmt: on
    }

    pub fn isImmediate(op: Op) bool {
        // zig fmt: off
        return switch (op) {
            .imm8, .imm16, .imm32, .imm64, 
            .imm8s, .imm16s, .imm32s,
            .rel8, .rel16, .rel32,
            .unity,
            =>  true,
            else => false,
        };
        // zig fmt: on
    }

    pub fn isMemory(op: Op) bool {
        // zig fmt: off
        return switch (op) {
            .rm8, .rm16, .rm32, .rm64,
            .m8, .m16, .m32, .m64, .m80,
            .m,
            .xmm_m32, .xmm_m64,
            =>  true,
            else => false,
        };
        // zig fmt: on
    }

    pub fn isSegmentRegister(op: Op) bool {
        return switch (op) {
            .moffs, .sreg => true,
            else => false,
        };
    }

    pub fn isFloatingPointRegister(op: Op) bool {
        return switch (op) {
            .xmm, .xmm_m32, .xmm_m64 => true,
            else => false,
        };
    }

    /// Given an operand `op` checks if `target` is a subset for the purposes of the encoding.
    pub fn isSubset(op: Op, target: Op, mode: Mode) bool {
        switch (op) {
            .m, .o16, .o32, .o64 => unreachable,
            .moffs, .sreg => return op == target,
            .none => switch (target) {
                .o16, .o32, .o64, .none => return true,
                else => return false,
            },
            else => {
                if (op.isRegister() and target.isRegister()) {
                    switch (mode) {
                        .sse, .sse2 => return op.isFloatingPointRegister() and target.isFloatingPointRegister(),
                        else => switch (target) {
                            .cl, .al, .ax, .eax, .rax => return op == target,
                            else => return op.bitSize() == target.bitSize(),
                        },
                    }
                }
                if (op.isMemory() and target.isMemory()) {
                    switch (target) {
                        .m => return true,
                        else => return op.bitSize() == target.bitSize(),
                    }
                }
                if (op.isImmediate() and target.isImmediate()) {
                    switch (target) {
                        .imm64 => if (op.bitSize() <= 64) return true,
                        .imm32s, .rel32 => if (op.bitSize() < 32 or (op.bitSize() == 32 and op.isSigned()))
                            return true,
                        .imm32 => if (op.bitSize() <= 32) return true,
                        .imm16s, .rel16 => if (op.bitSize() < 16 or (op.bitSize() == 16 and op.isSigned()))
                            return true,
                        .imm16 => if (op.bitSize() <= 16) return true,
                        .imm8s, .rel8 => if (op.bitSize() < 8 or (op.bitSize() == 8 and op.isSigned()))
                            return true,
                        .imm8 => if (op.bitSize() <= 8) return true,
                        else => {},
                    }
                    return op == target;
                }
                return false;
            },
        }
    }
};

pub const Mode = enum {
    none,
    fpu,
    rex,
    long,
    sse,
    sse2,
};
