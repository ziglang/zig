const std = @import("std");
const DW = std.dwarf;
const assert = std.debug.assert;
const testing = std.testing;

/// The condition field specifies the flags necessary for an
/// Instruction to be executed
pub const Condition = enum(u4) {
    /// equal
    eq,
    /// not equal
    ne,
    /// unsigned higher or same
    cs,
    /// unsigned lower
    cc,
    /// negative
    mi,
    /// positive or zero
    pl,
    /// overflow
    vs,
    /// no overflow
    vc,
    /// unsigned higer
    hi,
    /// unsigned lower or same
    ls,
    /// greater or equal
    ge,
    /// less than
    lt,
    /// greater than
    gt,
    /// less than or equal
    le,
    /// always
    al,

    /// Converts a std.math.CompareOperator into a condition flag,
    /// i.e. returns the condition that is true iff the result of the
    /// comparison is true. Assumes signed comparison
    pub fn fromCompareOperatorSigned(op: std.math.CompareOperator) Condition {
        return switch (op) {
            .gte => .ge,
            .gt => .gt,
            .neq => .ne,
            .lt => .lt,
            .lte => .le,
            .eq => .eq,
        };
    }

    /// Converts a std.math.CompareOperator into a condition flag,
    /// i.e. returns the condition that is true iff the result of the
    /// comparison is true. Assumes unsigned comparison
    pub fn fromCompareOperatorUnsigned(op: std.math.CompareOperator) Condition {
        return switch (op) {
            .gte => .cs,
            .gt => .hi,
            .neq => .ne,
            .lt => .cc,
            .lte => .ls,
            .eq => .eq,
        };
    }

    /// Returns the condition which is true iff the given condition is
    /// false (if such a condition exists)
    pub fn negate(cond: Condition) Condition {
        return switch (cond) {
            .eq => .ne,
            .ne => .eq,
            .cs => .cc,
            .cc => .cs,
            .mi => .pl,
            .pl => .mi,
            .vs => .vc,
            .vc => .vs,
            .hi => .ls,
            .ls => .hi,
            .ge => .lt,
            .lt => .ge,
            .gt => .le,
            .le => .gt,
            .al => unreachable,
        };
    }
};

test "condition from CompareOperator" {
    try testing.expectEqual(@as(Condition, .eq), Condition.fromCompareOperatorSigned(.eq));
    try testing.expectEqual(@as(Condition, .eq), Condition.fromCompareOperatorUnsigned(.eq));

    try testing.expectEqual(@as(Condition, .gt), Condition.fromCompareOperatorSigned(.gt));
    try testing.expectEqual(@as(Condition, .hi), Condition.fromCompareOperatorUnsigned(.gt));

    try testing.expectEqual(@as(Condition, .le), Condition.fromCompareOperatorSigned(.lte));
    try testing.expectEqual(@as(Condition, .ls), Condition.fromCompareOperatorUnsigned(.lte));
}

test "negate condition" {
    try testing.expectEqual(@as(Condition, .eq), Condition.ne.negate());
    try testing.expectEqual(@as(Condition, .ne), Condition.eq.negate());
}

/// Represents a register in the ARM instruction set architecture
pub const Register = enum(u5) {
    r0,
    r1,
    r2,
    r3,
    r4,
    r5,
    r6,
    r7,
    r8,
    r9,
    r10,
    r11,
    r12,
    r13,
    r14,
    r15,

    /// Argument / result / scratch register 1
    a1,
    /// Argument / result / scratch register 2
    a2,
    /// Argument / scratch register 3
    a3,
    /// Argument / scratch register 4
    a4,
    /// Variable-register 1
    v1,
    /// Variable-register 2
    v2,
    /// Variable-register 3
    v3,
    /// Variable-register 4
    v4,
    /// Variable-register 5
    v5,
    /// Platform register
    v6,
    /// Variable-register 7
    v7,
    /// Frame pointer or Variable-register 8
    fp,
    /// Intra-Procedure-call scratch register
    ip,
    /// Stack pointer
    sp,
    /// Link register
    lr,
    /// Program counter
    pc,

    /// Returns the unique 4-bit ID of this register which is used in
    /// the machine code
    pub fn id(self: Register) u4 {
        return @as(u4, @truncate(@intFromEnum(self)));
    }

    pub fn dwarfLocOp(self: Register) u8 {
        return @as(u8, self.id()) + DW.OP.reg0;
    }
};

test "Register.id" {
    try testing.expectEqual(@as(u4, 15), Register.r15.id());
    try testing.expectEqual(@as(u4, 15), Register.pc.id());
}

/// Program status registers containing flags, mode bits and other
/// vital information
pub const Psr = enum {
    cpsr,
    spsr,
};

/// Represents an instruction in the ARM instruction set architecture
pub const Instruction = union(enum) {
    data_processing: packed struct {
        // Note to self: The order of the fields top-to-bottom is
        // right-to-left in the actual 32-bit int representation
        op2: u12,
        rd: u4,
        rn: u4,
        s: u1,
        opcode: u4,
        i: u1,
        fixed: u2 = 0b00,
        cond: u4,
    },
    multiply: packed struct {
        rn: u4,
        fixed_1: u4 = 0b1001,
        rm: u4,
        ra: u4,
        rd: u4,
        set_cond: u1,
        accumulate: u1,
        fixed_2: u6 = 0b000000,
        cond: u4,
    },
    multiply_long: packed struct {
        rn: u4,
        fixed_1: u4 = 0b1001,
        rm: u4,
        rdlo: u4,
        rdhi: u4,
        set_cond: u1,
        accumulate: u1,
        unsigned: u1,
        fixed_2: u5 = 0b00001,
        cond: u4,
    },
    signed_multiply_halfwords: packed struct {
        rn: u4,
        fixed_1: u1 = 0b0,
        n: u1,
        m: u1,
        fixed_2: u1 = 0b1,
        rm: u4,
        fixed_3: u4 = 0b0000,
        rd: u4,
        fixed_4: u8 = 0b00010110,
        cond: u4,
    },
    integer_saturating_arithmetic: packed struct {
        rm: u4,
        fixed_1: u8 = 0b0000_0101,
        rd: u4,
        rn: u4,
        fixed_2: u1 = 0b0,
        opc: u2,
        fixed_3: u5 = 0b00010,
        cond: u4,
    },
    bit_field_extract: packed struct {
        rn: u4,
        fixed_1: u3 = 0b101,
        lsb: u5,
        rd: u4,
        widthm1: u5,
        fixed_2: u1 = 0b1,
        unsigned: u1,
        fixed_3: u5 = 0b01111,
        cond: u4,
    },
    single_data_transfer: packed struct {
        offset: u12,
        rd: u4,
        rn: u4,
        load_store: u1,
        write_back: u1,
        byte_word: u1,
        up_down: u1,
        pre_post: u1,
        imm: u1,
        fixed: u2 = 0b01,
        cond: u4,
    },
    extra_load_store: packed struct {
        imm4l: u4,
        fixed_1: u1 = 0b1,
        op2: u2,
        fixed_2: u1 = 0b1,
        imm4h: u4,
        rt: u4,
        rn: u4,
        o1: u1,
        write_back: u1,
        imm: u1,
        up_down: u1,
        pre_index: u1,
        fixed_3: u3 = 0b000,
        cond: u4,
    },
    block_data_transfer: packed struct {
        register_list: u16,
        rn: u4,
        load_store: u1,
        write_back: u1,
        psr_or_user: u1,
        up_down: u1,
        pre_post: u1,
        fixed: u3 = 0b100,
        cond: u4,
    },
    branch: packed struct {
        offset: u24,
        link: u1,
        fixed: u3 = 0b101,
        cond: u4,
    },
    branch_exchange: packed struct {
        rn: u4,
        fixed_1: u1 = 0b1,
        link: u1,
        fixed_2: u22 = 0b0001_0010_1111_1111_1111_00,
        cond: u4,
    },
    supervisor_call: packed struct {
        comment: u24,
        fixed: u4 = 0b1111,
        cond: u4,
    },
    undefined_instruction: packed struct {
        imm32: u32 = 0xe7ffdefe,
    },
    breakpoint: packed struct {
        imm4: u4,
        fixed_1: u4 = 0b0111,
        imm12: u12,
        fixed_2_and_cond: u12 = 0b1110_0001_0010,
    },

    /// Represents the possible operations which can be performed by a
    /// Data Processing instruction
    const Opcode = enum(u4) {
        // Rd := Op1 AND Op2
        @"and",
        // Rd := Op1 EOR Op2
        eor,
        // Rd := Op1 - Op2
        sub,
        // Rd := Op2 - Op1
        rsb,
        // Rd := Op1 + Op2
        add,
        // Rd := Op1 + Op2 + C
        adc,
        // Rd := Op1 - Op2 + C - 1
        sbc,
        // Rd := Op2 - Op1 + C - 1
        rsc,
        // set condition codes on Op1 AND Op2
        tst,
        // set condition codes on Op1 EOR Op2
        teq,
        // set condition codes on Op1 - Op2
        cmp,
        // set condition codes on Op1 + Op2
        cmn,
        // Rd := Op1 OR Op2
        orr,
        // Rd := Op2
        mov,
        // Rd := Op1 AND NOT Op2
        bic,
        // Rd := NOT Op2
        mvn,
    };

    /// Represents the second operand to a data processing instruction
    /// which can either be content from a register or an immediate
    /// value
    pub const Operand = union(enum) {
        register: packed struct {
            rm: u4,
            shift: u8,
        },
        immediate: packed struct {
            imm: u8,
            rotate: u4,
        },

        /// Represents multiple ways a register can be shifted. A
        /// register can be shifted by a specific immediate value or
        /// by the contents of another register
        pub const Shift = union(enum) {
            immediate: packed struct {
                fixed: u1 = 0b0,
                typ: u2,
                amount: u5,
            },
            register: packed struct {
                fixed_1: u1 = 0b1,
                typ: u2,
                fixed_2: u1 = 0b0,
                rs: u4,
            },

            pub const Type = enum(u2) {
                logical_left,
                logical_right,
                arithmetic_right,
                rotate_right,
            };

            pub const none = Shift{
                .immediate = .{
                    .amount = 0,
                    .typ = 0,
                },
            };

            pub fn toU8(self: Shift) u8 {
                return switch (self) {
                    .register => |v| @as(u8, @bitCast(v)),
                    .immediate => |v| @as(u8, @bitCast(v)),
                };
            }

            pub fn reg(rs: Register, typ: Type) Shift {
                return Shift{
                    .register = .{
                        .rs = rs.id(),
                        .typ = @intFromEnum(typ),
                    },
                };
            }

            pub fn imm(amount: u5, typ: Type) Shift {
                return Shift{
                    .immediate = .{
                        .amount = amount,
                        .typ = @intFromEnum(typ),
                    },
                };
            }
        };

        pub fn toU12(self: Operand) u12 {
            return switch (self) {
                .register => |v| @as(u12, @bitCast(v)),
                .immediate => |v| @as(u12, @bitCast(v)),
            };
        }

        pub fn reg(rm: Register, shift: Shift) Operand {
            return Operand{
                .register = .{
                    .rm = rm.id(),
                    .shift = shift.toU8(),
                },
            };
        }

        pub fn imm(immediate: u8, rotate: u4) Operand {
            return Operand{
                .immediate = .{
                    .imm = immediate,
                    .rotate = rotate,
                },
            };
        }

        /// Tries to convert an unsigned 32 bit integer into an
        /// immediate operand using rotation. Returns null when there
        /// is no conversion
        pub fn fromU32(x: u32) ?Operand {
            const masks = comptime blk: {
                const base_mask: u32 = std.math.maxInt(u8);
                var result = [_]u32{0} ** 16;
                for (&result, 0..) |*mask, i| mask.* = std.math.rotr(u32, base_mask, 2 * i);
                break :blk result;
            };

            return for (masks, 0..) |mask, i| {
                if (x & mask == x) {
                    break Operand{
                        .immediate = .{
                            .imm = @as(u8, @intCast(std.math.rotl(u32, x, 2 * i))),
                            .rotate = @as(u4, @intCast(i)),
                        },
                    };
                }
            } else null;
        }
    };

    pub const AddressingMode = enum {
        /// [<Rn>, <offset>]
        ///
        /// Address = Rn + offset
        offset,
        /// [<Rn>, <offset>]!
        ///
        /// Address = Rn + offset
        /// Rn = Rn + offset
        pre_index,
        /// [<Rn>], <offset>
        ///
        /// Address = Rn
        /// Rn = Rn + offset
        post_index,
    };

    /// Represents the offset operand of a load or store
    /// instruction. Data can be loaded from memory with either an
    /// immediate offset or an offset that is stored in some register.
    pub const Offset = union(enum) {
        immediate: u12,
        register: packed struct {
            rm: u4,
            fixed: u1 = 0b0,
            stype: u2,
            imm5: u5,
        },

        pub const Shift = union(enum) {
            /// No shift
            none,
            /// Logical shift left
            lsl: u5,
            /// Logical shift right
            lsr: u5,
            /// Arithmetic shift right
            asr: u5,
            /// Rotate right
            ror: u5,
            /// Rotate right one bit, with extend
            rrx,
        };

        pub const none = Offset{
            .immediate = 0,
        };

        pub fn toU12(self: Offset) u12 {
            return switch (self) {
                .register => |v| @as(u12, @bitCast(v)),
                .immediate => |v| v,
            };
        }

        pub fn reg(rm: Register, shift: Shift) Offset {
            return Offset{
                .register = .{
                    .rm = rm.id(),
                    .stype = switch (shift) {
                        .none => 0b00,
                        .lsl => 0b00,
                        .lsr => 0b01,
                        .asr => 0b10,
                        .ror => 0b11,
                        .rrx => 0b11,
                    },
                    .imm5 = switch (shift) {
                        .none => 0,
                        .lsl => |n| n,
                        .lsr => |n| n,
                        .asr => |n| n,
                        .ror => |n| n,
                        .rrx => 0,
                    },
                },
            };
        }

        pub fn imm(immediate: u12) Offset {
            return Offset{
                .immediate = immediate,
            };
        }
    };

    /// Represents the offset operand of an extra load or store
    /// instruction.
    pub const ExtraLoadStoreOffset = union(enum) {
        immediate: u8,
        register: u4,

        pub const none = ExtraLoadStoreOffset{
            .immediate = 0,
        };

        pub fn reg(register: Register) ExtraLoadStoreOffset {
            return ExtraLoadStoreOffset{
                .register = register.id(),
            };
        }

        pub fn imm(immediate: u8) ExtraLoadStoreOffset {
            return ExtraLoadStoreOffset{
                .immediate = immediate,
            };
        }
    };

    /// Represents the register list operand to a block data transfer
    /// instruction
    pub const RegisterList = packed struct {
        r0: bool = false,
        r1: bool = false,
        r2: bool = false,
        r3: bool = false,
        r4: bool = false,
        r5: bool = false,
        r6: bool = false,
        r7: bool = false,
        r8: bool = false,
        r9: bool = false,
        r10: bool = false,
        r11: bool = false,
        r12: bool = false,
        r13: bool = false,
        r14: bool = false,
        r15: bool = false,
    };

    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .data_processing => |v| @as(u32, @bitCast(v)),
            .multiply => |v| @as(u32, @bitCast(v)),
            .multiply_long => |v| @as(u32, @bitCast(v)),
            .signed_multiply_halfwords => |v| @as(u32, @bitCast(v)),
            .integer_saturating_arithmetic => |v| @as(u32, @bitCast(v)),
            .bit_field_extract => |v| @as(u32, @bitCast(v)),
            .single_data_transfer => |v| @as(u32, @bitCast(v)),
            .extra_load_store => |v| @as(u32, @bitCast(v)),
            .block_data_transfer => |v| @as(u32, @bitCast(v)),
            .branch => |v| @as(u32, @bitCast(v)),
            .branch_exchange => |v| @as(u32, @bitCast(v)),
            .supervisor_call => |v| @as(u32, @bitCast(v)),
            .undefined_instruction => |v| v.imm32,
            .breakpoint => |v| @as(u32, @intCast(v.imm4)) | (@as(u32, @intCast(v.fixed_1)) << 4) | (@as(u32, @intCast(v.imm12)) << 8) | (@as(u32, @intCast(v.fixed_2_and_cond)) << 20),
        };
    }

    // Helper functions for the "real" functions below

    fn dataProcessing(
        cond: Condition,
        opcode: Opcode,
        s: u1,
        rd: Register,
        rn: Register,
        op2: Operand,
    ) Instruction {
        return Instruction{
            .data_processing = .{
                .cond = @intFromEnum(cond),
                .i = @intFromBool(op2 == .immediate),
                .opcode = @intFromEnum(opcode),
                .s = s,
                .rn = rn.id(),
                .rd = rd.id(),
                .op2 = op2.toU12(),
            },
        };
    }

    fn specialMov(
        cond: Condition,
        rd: Register,
        imm: u16,
        top: bool,
    ) Instruction {
        return Instruction{
            .data_processing = .{
                .cond = @intFromEnum(cond),
                .i = 1,
                .opcode = if (top) 0b1010 else 0b1000,
                .s = 0,
                .rn = @as(u4, @truncate(imm >> 12)),
                .rd = rd.id(),
                .op2 = @as(u12, @truncate(imm)),
            },
        };
    }

    fn multiply(
        cond: Condition,
        set_cond: u1,
        rd: Register,
        rn: Register,
        rm: Register,
        ra: ?Register,
    ) Instruction {
        return Instruction{
            .multiply = .{
                .cond = @intFromEnum(cond),
                .accumulate = @intFromBool(ra != null),
                .set_cond = set_cond,
                .rd = rd.id(),
                .rn = rn.id(),
                .ra = if (ra) |reg| reg.id() else 0b0000,
                .rm = rm.id(),
            },
        };
    }

    fn multiplyLong(
        cond: Condition,
        signed: u1,
        accumulate: u1,
        set_cond: u1,
        rdhi: Register,
        rdlo: Register,
        rm: Register,
        rn: Register,
    ) Instruction {
        return Instruction{
            .multiply_long = .{
                .cond = @intFromEnum(cond),
                .unsigned = signed,
                .accumulate = accumulate,
                .set_cond = set_cond,
                .rdlo = rdlo.id(),
                .rdhi = rdhi.id(),
                .rn = rn.id(),
                .rm = rm.id(),
            },
        };
    }

    fn signedMultiplyHalfwords(
        n: u1,
        m: u1,
        cond: Condition,
        rd: Register,
        rn: Register,
        rm: Register,
    ) Instruction {
        return Instruction{
            .signed_multiply_halfwords = .{
                .rn = rn.id(),
                .n = n,
                .m = m,
                .rm = rm.id(),
                .rd = rd.id(),
                .cond = @intFromEnum(cond),
            },
        };
    }

    fn integerSaturationArithmetic(
        cond: Condition,
        rd: Register,
        rm: Register,
        rn: Register,
        opc: u2,
    ) Instruction {
        return Instruction{
            .integer_saturating_arithmetic = .{
                .rm = rm.id(),
                .rd = rd.id(),
                .rn = rn.id(),
                .opc = opc,
                .cond = @intFromEnum(cond),
            },
        };
    }

    fn bitFieldExtract(
        unsigned: u1,
        cond: Condition,
        rd: Register,
        rn: Register,
        lsb: u5,
        width: u6,
    ) Instruction {
        assert(width > 0 and width <= 32);
        return Instruction{
            .bit_field_extract = .{
                .rn = rn.id(),
                .lsb = lsb,
                .rd = rd.id(),
                .widthm1 = @as(u5, @intCast(width - 1)),
                .unsigned = unsigned,
                .cond = @intFromEnum(cond),
            },
        };
    }

    fn singleDataTransfer(
        cond: Condition,
        rd: Register,
        rn: Register,
        offset: Offset,
        mode: AddressingMode,
        positive: bool,
        byte_word: u1,
        load_store: u1,
    ) Instruction {
        return Instruction{
            .single_data_transfer = .{
                .cond = @intFromEnum(cond),
                .rn = rn.id(),
                .rd = rd.id(),
                .offset = offset.toU12(),
                .load_store = load_store,
                .write_back = switch (mode) {
                    .offset => 0b0,
                    .pre_index, .post_index => 0b1,
                },
                .byte_word = byte_word,
                .up_down = @intFromBool(positive),
                .pre_post = switch (mode) {
                    .offset, .pre_index => 0b1,
                    .post_index => 0b0,
                },
                .imm = @intFromBool(offset != .immediate),
            },
        };
    }

    fn extraLoadStore(
        cond: Condition,
        mode: AddressingMode,
        positive: bool,
        o1: u1,
        op2: u2,
        rn: Register,
        rt: Register,
        offset: ExtraLoadStoreOffset,
    ) Instruction {
        const imm4l: u4 = switch (offset) {
            .immediate => |imm| @as(u4, @truncate(imm)),
            .register => |reg| reg,
        };
        const imm4h: u4 = switch (offset) {
            .immediate => |imm| @as(u4, @truncate(imm >> 4)),
            .register => 0b0000,
        };

        return Instruction{
            .extra_load_store = .{
                .imm4l = imm4l,
                .op2 = op2,
                .imm4h = imm4h,
                .rt = rt.id(),
                .rn = rn.id(),
                .o1 = o1,
                .write_back = switch (mode) {
                    .offset => 0b0,
                    .pre_index, .post_index => 0b1,
                },
                .imm = @intFromBool(offset == .immediate),
                .up_down = @intFromBool(positive),
                .pre_index = switch (mode) {
                    .offset, .pre_index => 0b1,
                    .post_index => 0b0,
                },
                .cond = @intFromEnum(cond),
            },
        };
    }

    fn blockDataTransfer(
        cond: Condition,
        rn: Register,
        reg_list: RegisterList,
        pre_post: u1,
        up_down: u1,
        psr_or_user: u1,
        write_back: bool,
        load_store: u1,
    ) Instruction {
        return Instruction{
            .block_data_transfer = .{
                .register_list = @as(u16, @bitCast(reg_list)),
                .rn = rn.id(),
                .load_store = load_store,
                .write_back = @intFromBool(write_back),
                .psr_or_user = psr_or_user,
                .up_down = up_down,
                .pre_post = pre_post,
                .cond = @intFromEnum(cond),
            },
        };
    }

    fn branch(cond: Condition, offset: i26, link: u1) Instruction {
        return Instruction{
            .branch = .{
                .cond = @intFromEnum(cond),
                .link = link,
                .offset = @as(u24, @bitCast(@as(i24, @intCast(offset >> 2)))),
            },
        };
    }

    fn branchExchange(cond: Condition, rn: Register, link: u1) Instruction {
        return Instruction{
            .branch_exchange = .{
                .cond = @intFromEnum(cond),
                .link = link,
                .rn = rn.id(),
            },
        };
    }

    fn supervisorCall(cond: Condition, comment: u24) Instruction {
        return Instruction{
            .supervisor_call = .{
                .cond = @intFromEnum(cond),
                .comment = comment,
            },
        };
    }

    // This instruction has no official mnemonic equivalent so it is public as-is.
    pub fn undefinedInstruction() Instruction {
        return Instruction{
            .undefined_instruction = .{},
        };
    }

    fn breakpoint(imm: u16) Instruction {
        return Instruction{
            .breakpoint = .{
                .imm12 = @as(u12, @truncate(imm >> 4)),
                .imm4 = @as(u4, @truncate(imm)),
            },
        };
    }

    // Public functions replicating assembler syntax as closely as
    // possible

    // Data processing

    pub fn @"and"(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .@"and", 0, rd, rn, op2);
    }

    pub fn ands(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .@"and", 1, rd, rn, op2);
    }

    pub fn eor(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .eor, 0, rd, rn, op2);
    }

    pub fn eors(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .eor, 1, rd, rn, op2);
    }

    pub fn sub(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .sub, 0, rd, rn, op2);
    }

    pub fn subs(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .sub, 1, rd, rn, op2);
    }

    pub fn rsb(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .rsb, 0, rd, rn, op2);
    }

    pub fn rsbs(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .rsb, 1, rd, rn, op2);
    }

    pub fn add(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .add, 0, rd, rn, op2);
    }

    pub fn adds(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .add, 1, rd, rn, op2);
    }

    pub fn adc(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .adc, 0, rd, rn, op2);
    }

    pub fn adcs(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .adc, 1, rd, rn, op2);
    }

    pub fn sbc(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .sbc, 0, rd, rn, op2);
    }

    pub fn sbcs(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .sbc, 1, rd, rn, op2);
    }

    pub fn rsc(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .rsc, 0, rd, rn, op2);
    }

    pub fn rscs(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .rsc, 1, rd, rn, op2);
    }

    pub fn tst(cond: Condition, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .tst, 1, .r0, rn, op2);
    }

    pub fn teq(cond: Condition, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .teq, 1, .r0, rn, op2);
    }

    pub fn cmp(cond: Condition, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .cmp, 1, .r0, rn, op2);
    }

    pub fn cmn(cond: Condition, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .cmn, 1, .r0, rn, op2);
    }

    pub fn orr(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .orr, 0, rd, rn, op2);
    }

    pub fn orrs(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .orr, 1, rd, rn, op2);
    }

    pub fn mov(cond: Condition, rd: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .mov, 0, rd, .r0, op2);
    }

    pub fn movs(cond: Condition, rd: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .mov, 1, rd, .r0, op2);
    }

    pub fn bic(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .bic, 0, rd, rn, op2);
    }

    pub fn bics(cond: Condition, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .bic, 1, rd, rn, op2);
    }

    pub fn mvn(cond: Condition, rd: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .mvn, 0, rd, .r0, op2);
    }

    pub fn mvns(cond: Condition, rd: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .mvn, 1, rd, .r0, op2);
    }

    // Integer Saturating Arithmetic

    pub fn qadd(cond: Condition, rd: Register, rm: Register, rn: Register) Instruction {
        return integerSaturationArithmetic(cond, rd, rm, rn, 0b00);
    }

    pub fn qsub(cond: Condition, rd: Register, rm: Register, rn: Register) Instruction {
        return integerSaturationArithmetic(cond, rd, rm, rn, 0b01);
    }

    pub fn qdadd(cond: Condition, rd: Register, rm: Register, rn: Register) Instruction {
        return integerSaturationArithmetic(cond, rd, rm, rn, 0b10);
    }

    pub fn qdsub(cond: Condition, rd: Register, rm: Register, rn: Register) Instruction {
        return integerSaturationArithmetic(cond, rd, rm, rn, 0b11);
    }

    // movw and movt

    pub fn movw(cond: Condition, rd: Register, imm: u16) Instruction {
        return specialMov(cond, rd, imm, false);
    }

    pub fn movt(cond: Condition, rd: Register, imm: u16) Instruction {
        return specialMov(cond, rd, imm, true);
    }

    // PSR transfer

    pub fn mrs(cond: Condition, rd: Register, psr: Psr) Instruction {
        return Instruction{
            .data_processing = .{
                .cond = @intFromEnum(cond),
                .i = 0,
                .opcode = if (psr == .spsr) 0b1010 else 0b1000,
                .s = 0,
                .rn = 0b1111,
                .rd = rd.id(),
                .op2 = 0b0000_0000_0000,
            },
        };
    }

    pub fn msr(cond: Condition, psr: Psr, op: Operand) Instruction {
        return Instruction{
            .data_processing = .{
                .cond = @intFromEnum(cond),
                .i = 0,
                .opcode = if (psr == .spsr) 0b1011 else 0b1001,
                .s = 0,
                .rn = 0b1111,
                .rd = 0b1111,
                .op2 = op.toU12(),
            },
        };
    }

    // Multiply

    pub fn mul(cond: Condition, rd: Register, rn: Register, rm: Register) Instruction {
        return multiply(cond, 0, rd, rn, rm, null);
    }

    pub fn muls(cond: Condition, rd: Register, rn: Register, rm: Register) Instruction {
        return multiply(cond, 1, rd, rn, rm, null);
    }

    pub fn mla(cond: Condition, rd: Register, rn: Register, rm: Register, ra: Register) Instruction {
        return multiply(cond, 0, rd, rn, rm, ra);
    }

    pub fn mlas(cond: Condition, rd: Register, rn: Register, rm: Register, ra: Register) Instruction {
        return multiply(cond, 1, rd, rn, rm, ra);
    }

    // Multiply long

    pub fn umull(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 0, 0, 0, rdhi, rdlo, rm, rn);
    }

    pub fn umulls(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 0, 0, 1, rdhi, rdlo, rm, rn);
    }

    pub fn umlal(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 0, 1, 0, rdhi, rdlo, rm, rn);
    }

    pub fn umlals(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 0, 1, 1, rdhi, rdlo, rm, rn);
    }

    pub fn smull(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 1, 0, 0, rdhi, rdlo, rm, rn);
    }

    pub fn smulls(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 1, 0, 1, rdhi, rdlo, rm, rn);
    }

    pub fn smlal(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 1, 1, 0, rdhi, rdlo, rm, rn);
    }

    pub fn smlals(cond: Condition, rdlo: Register, rdhi: Register, rn: Register, rm: Register) Instruction {
        return multiplyLong(cond, 1, 1, 1, rdhi, rdlo, rm, rn);
    }

    // Signed Multiply (halfwords)

    pub fn smulbb(cond: Condition, rd: Register, rn: Register, rm: Register) Instruction {
        return signedMultiplyHalfwords(0, 0, cond, rd, rn, rm);
    }

    pub fn smulbt(cond: Condition, rd: Register, rn: Register, rm: Register) Instruction {
        return signedMultiplyHalfwords(0, 1, cond, rd, rn, rm);
    }

    pub fn smultb(cond: Condition, rd: Register, rn: Register, rm: Register) Instruction {
        return signedMultiplyHalfwords(1, 0, cond, rd, rn, rm);
    }

    pub fn smultt(cond: Condition, rd: Register, rn: Register, rm: Register) Instruction {
        return signedMultiplyHalfwords(1, 1, cond, rd, rn, rm);
    }

    // Bit field extract

    pub fn ubfx(cond: Condition, rd: Register, rn: Register, lsb: u5, width: u6) Instruction {
        return bitFieldExtract(0b1, cond, rd, rn, lsb, width);
    }

    pub fn sbfx(cond: Condition, rd: Register, rn: Register, lsb: u5, width: u6) Instruction {
        return bitFieldExtract(0b0, cond, rd, rn, lsb, width);
    }

    // Single data transfer

    pub const OffsetArgs = struct {
        mode: AddressingMode = .offset,
        positive: bool = true,
        offset: Offset,
    };

    pub fn ldr(cond: Condition, rd: Register, rn: Register, args: OffsetArgs) Instruction {
        return singleDataTransfer(cond, rd, rn, args.offset, args.mode, args.positive, 0, 1);
    }

    pub fn ldrb(cond: Condition, rd: Register, rn: Register, args: OffsetArgs) Instruction {
        return singleDataTransfer(cond, rd, rn, args.offset, args.mode, args.positive, 1, 1);
    }

    pub fn str(cond: Condition, rd: Register, rn: Register, args: OffsetArgs) Instruction {
        return singleDataTransfer(cond, rd, rn, args.offset, args.mode, args.positive, 0, 0);
    }

    pub fn strb(cond: Condition, rd: Register, rn: Register, args: OffsetArgs) Instruction {
        return singleDataTransfer(cond, rd, rn, args.offset, args.mode, args.positive, 1, 0);
    }

    // Extra load/store

    pub const ExtraLoadStoreOffsetArgs = struct {
        mode: AddressingMode = .offset,
        positive: bool = true,
        offset: ExtraLoadStoreOffset,
    };

    pub fn strh(cond: Condition, rt: Register, rn: Register, args: ExtraLoadStoreOffsetArgs) Instruction {
        return extraLoadStore(cond, args.mode, args.positive, 0b0, 0b01, rn, rt, args.offset);
    }

    pub fn ldrh(cond: Condition, rt: Register, rn: Register, args: ExtraLoadStoreOffsetArgs) Instruction {
        return extraLoadStore(cond, args.mode, args.positive, 0b1, 0b01, rn, rt, args.offset);
    }

    pub fn ldrsh(cond: Condition, rt: Register, rn: Register, args: ExtraLoadStoreOffsetArgs) Instruction {
        return extraLoadStore(cond, args.mode, args.positive, 0b1, 0b11, rn, rt, args.offset);
    }

    pub fn ldrsb(cond: Condition, rt: Register, rn: Register, args: ExtraLoadStoreOffsetArgs) Instruction {
        return extraLoadStore(cond, args.mode, args.positive, 0b1, 0b10, rn, rt, args.offset);
    }

    // Block data transfer

    pub fn ldmda(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 0, 0, 0, write_back, 1);
    }

    pub fn ldmdb(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 1, 0, 0, write_back, 1);
    }

    pub fn ldmib(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 1, 1, 0, write_back, 1);
    }

    pub fn ldmia(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 0, 1, 0, write_back, 1);
    }

    pub const ldmfa = ldmda;
    pub const ldmea = ldmdb;
    pub const ldmed = ldmib;
    pub const ldmfd = ldmia;
    pub const ldm = ldmia;

    pub fn stmda(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 0, 0, 0, write_back, 0);
    }

    pub fn stmdb(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 1, 0, 0, write_back, 0);
    }

    pub fn stmib(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 1, 1, 0, write_back, 0);
    }

    pub fn stmia(cond: Condition, rn: Register, write_back: bool, reg_list: RegisterList) Instruction {
        return blockDataTransfer(cond, rn, reg_list, 0, 1, 0, write_back, 0);
    }

    pub const stmed = stmda;
    pub const stmfd = stmdb;
    pub const stmfa = stmib;
    pub const stmea = stmia;
    pub const stm = stmia;

    // Branch

    pub fn b(cond: Condition, offset: i26) Instruction {
        return branch(cond, offset, 0);
    }

    pub fn bl(cond: Condition, offset: i26) Instruction {
        return branch(cond, offset, 1);
    }

    // Branch and exchange

    pub fn bx(cond: Condition, rn: Register) Instruction {
        return branchExchange(cond, rn, 0);
    }

    pub fn blx(cond: Condition, rn: Register) Instruction {
        return branchExchange(cond, rn, 1);
    }

    // Supervisor Call

    pub const swi = svc;

    pub fn svc(cond: Condition, comment: u24) Instruction {
        return supervisorCall(cond, comment);
    }

    // Breakpoint

    pub fn bkpt(imm: u16) Instruction {
        return breakpoint(imm);
    }

    // Aliases

    pub fn nop() Instruction {
        return mov(.al, .r0, Instruction.Operand.reg(.r0, Instruction.Operand.Shift.none));
    }

    pub fn pop(cond: Condition, args: anytype) Instruction {
        if (@typeInfo(@TypeOf(args)) != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(@TypeOf(args)));
        }

        if (args.len < 1) {
            @compileError("Expected at least one register");
        } else if (args.len == 1) {
            const reg = args[0];
            return ldr(cond, reg, .sp, .{
                .mode = .post_index,
                .positive = true,
                .offset = Offset.imm(4),
            });
        } else {
            var register_list: u16 = 0;
            inline for (args) |arg| {
                const reg = @as(Register, arg);
                register_list |= @as(u16, 1) << reg.id();
            }
            return ldm(cond, .sp, true, @as(RegisterList, @bitCast(register_list)));
        }
    }

    pub fn push(cond: Condition, args: anytype) Instruction {
        if (@typeInfo(@TypeOf(args)) != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(@TypeOf(args)));
        }

        if (args.len < 1) {
            @compileError("Expected at least one register");
        } else if (args.len == 1) {
            const reg = args[0];
            return str(cond, reg, .sp, .{
                .mode = .pre_index,
                .positive = false,
                .offset = Offset.imm(4),
            });
        } else {
            var register_list: u16 = 0;
            inline for (args) |arg| {
                const reg = @as(Register, arg);
                register_list |= @as(u16, 1) << reg.id();
            }
            return stmdb(cond, .sp, true, @as(RegisterList, @bitCast(register_list)));
        }
    }

    pub const ShiftAmount = union(enum) {
        immediate: u5,
        register: Register,

        pub fn imm(immediate: u5) ShiftAmount {
            return .{
                .immediate = immediate,
            };
        }

        pub fn reg(register: Register) ShiftAmount {
            return .{
                .register = register,
            };
        }
    };

    pub fn lsl(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| mov(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .logical_left))),
            .register => |reg| mov(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .logical_left))),
        };
    }

    pub fn lsr(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| mov(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .logical_right))),
            .register => |reg| mov(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .logical_right))),
        };
    }

    pub fn asr(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| mov(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .arithmetic_right))),
            .register => |reg| mov(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .arithmetic_right))),
        };
    }

    pub fn ror(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| mov(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .rotate_right))),
            .register => |reg| mov(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .rotate_right))),
        };
    }

    pub fn lsls(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| movs(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .logical_left))),
            .register => |reg| movs(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .logical_left))),
        };
    }

    pub fn lsrs(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| movs(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .logical_right))),
            .register => |reg| movs(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .logical_right))),
        };
    }

    pub fn asrs(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| movs(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .arithmetic_right))),
            .register => |reg| movs(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .arithmetic_right))),
        };
    }

    pub fn rors(cond: Condition, rd: Register, rm: Register, shift: ShiftAmount) Instruction {
        return switch (shift) {
            .immediate => |imm| movs(cond, rd, Operand.reg(rm, Operand.Shift.imm(imm, .rotate_right))),
            .register => |reg| movs(cond, rd, Operand.reg(rm, Operand.Shift.reg(reg, .rotate_right))),
        };
    }
};

test "serialize instructions" {
    const Testcase = struct {
        inst: Instruction,
        expected: u32,
    };

    const testcases = [_]Testcase{
        .{ // add r0, r0, r0
            .inst = Instruction.add(.al, .r0, .r0, Instruction.Operand.reg(.r0, Instruction.Operand.Shift.none)),
            .expected = 0b1110_00_0_0100_0_0000_0000_00000000_0000,
        },
        .{ // mov r4, r2
            .inst = Instruction.mov(.al, .r4, Instruction.Operand.reg(.r2, Instruction.Operand.Shift.none)),
            .expected = 0b1110_00_0_1101_0_0000_0100_00000000_0010,
        },
        .{ // mov r0, #42
            .inst = Instruction.mov(.al, .r0, Instruction.Operand.imm(42, 0)),
            .expected = 0b1110_00_1_1101_0_0000_0000_0000_00101010,
        },
        .{ // mrs r5, cpsr
            .inst = Instruction.mrs(.al, .r5, .cpsr),
            .expected = 0b1110_00010_0_001111_0101_000000000000,
        },
        .{ // mul r0, r1, r2
            .inst = Instruction.mul(.al, .r0, .r1, .r2),
            .expected = 0b1110_000000_0_0_0000_0000_0010_1001_0001,
        },
        .{ // umlal r0, r1, r5, r6
            .inst = Instruction.umlal(.al, .r0, .r1, .r5, .r6),
            .expected = 0b1110_00001_0_1_0_0001_0000_0110_1001_0101,
        },
        .{ // ldr r0, [r2, #42]
            .inst = Instruction.ldr(.al, .r0, .r2, .{
                .offset = Instruction.Offset.imm(42),
            }),
            .expected = 0b1110_01_0_1_1_0_0_1_0010_0000_000000101010,
        },
        .{ // str r0, [r3]
            .inst = Instruction.str(.al, .r0, .r3, .{
                .offset = Instruction.Offset.none,
            }),
            .expected = 0b1110_01_0_1_1_0_0_0_0011_0000_000000000000,
        },
        .{ // strh r1, [r5]
            .inst = Instruction.strh(.al, .r1, .r5, .{
                .offset = Instruction.ExtraLoadStoreOffset.none,
            }),
            .expected = 0b1110_000_1_1_1_0_0_0101_0001_0000_1011_0000,
        },
        .{ // b #12
            .inst = Instruction.b(.al, 12),
            .expected = 0b1110_101_0_0000_0000_0000_0000_0000_0011,
        },
        .{ // bl #-4
            .inst = Instruction.bl(.al, -4),
            .expected = 0b1110_101_1_1111_1111_1111_1111_1111_1111,
        },
        .{ // bx lr
            .inst = Instruction.bx(.al, .lr),
            .expected = 0b1110_0001_0010_1111_1111_1111_0001_1110,
        },
        .{ // svc #0
            .inst = Instruction.svc(.al, 0),
            .expected = 0b1110_1111_0000_0000_0000_0000_0000_0000,
        },
        .{ // bkpt #42
            .inst = Instruction.bkpt(42),
            .expected = 0b1110_0001_0010_000000000010_0111_1010,
        },
        .{ // stmdb r9, {r0}
            .inst = Instruction.stmdb(.al, .r9, false, .{ .r0 = true }),
            .expected = 0b1110_100_1_0_0_0_0_1001_0000000000000001,
        },
        .{ // ldmea r4!, {r2, r5}
            .inst = Instruction.ldmea(.al, .r4, true, .{ .r2 = true, .r5 = true }),
            .expected = 0b1110_100_1_0_0_1_1_0100_0000000000100100,
        },
        .{ // qadd r0, r7, r8
            .inst = Instruction.qadd(.al, .r0, .r7, .r8),
            .expected = 0b1110_00010_00_0_1000_0000_0000_0101_0111,
        },
        .{ // smulbt r0, r0, r0
            .inst = Instruction.smulbt(.al, .r0, .r0, .r0),
            .expected = 0b1110_00010110_0000_0000_0000_1_1_0_0_0000,
        },
    };

    for (testcases) |case| {
        const actual = case.inst.toU32();
        try testing.expectEqual(case.expected, actual);
    }
}

test "aliases" {
    const Testcase = struct {
        expected: Instruction,
        actual: Instruction,
    };

    const testcases = [_]Testcase{
        .{ // pop { r6 }
            .actual = Instruction.pop(.al, .{.r6}),
            .expected = Instruction.ldr(.al, .r6, .sp, .{
                .mode = .post_index,
                .positive = true,
                .offset = Instruction.Offset.imm(4),
            }),
        },
        .{ // pop { r1, r5 }
            .actual = Instruction.pop(.al, .{ .r1, .r5 }),
            .expected = Instruction.ldm(.al, .sp, true, .{ .r1 = true, .r5 = true }),
        },
        .{ // push { r3 }
            .actual = Instruction.push(.al, .{.r3}),
            .expected = Instruction.str(.al, .r3, .sp, .{
                .mode = .pre_index,
                .positive = false,
                .offset = Instruction.Offset.imm(4),
            }),
        },
        .{ // push { r0, r2 }
            .actual = Instruction.push(.al, .{ .r0, .r2 }),
            .expected = Instruction.stmdb(.al, .sp, true, .{ .r0 = true, .r2 = true }),
        },
        .{ // lsl r4, r5, #5
            .actual = Instruction.lsl(.al, .r4, .r5, Instruction.ShiftAmount.imm(5)),
            .expected = Instruction.mov(.al, .r4, Instruction.Operand.reg(
                .r5,
                Instruction.Operand.Shift.imm(5, .logical_left),
            )),
        },
        .{ // asrs r1, r1, r3
            .actual = Instruction.asrs(.al, .r1, .r1, Instruction.ShiftAmount.reg(.r3)),
            .expected = Instruction.movs(.al, .r1, Instruction.Operand.reg(
                .r1,
                Instruction.Operand.Shift.reg(.r3, .arithmetic_right),
            )),
        },
    };

    for (testcases) |case| {
        try testing.expectEqual(case.expected.toU32(), case.actual.toU32());
    }
}
