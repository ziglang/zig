const std = @import("std");
const DW = std.dwarf;
const testing = std.testing;

/// The condition field specifies the flags neccessary for an
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
};

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
        return @truncate(u4, @enumToInt(self));
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        inline for (callee_preserved_regs) |cpreg, i| {
            if (self.id() == cpreg.id()) return i;
        }
        return null;
    }

    pub fn dwarfLocOp(self: Register) u8 {
        return @as(u8, self.id()) + DW.OP_reg0;
    }
};

test "Register.id" {
    testing.expectEqual(@as(u4, 15), Register.r15.id());
    testing.expectEqual(@as(u4, 15), Register.pc.id());
}

pub const callee_preserved_regs = [_]Register{ .r0, .r1, .r2, .r3, .r4, .r5, .r6, .r7, .r8, .r10 };
pub const c_abi_int_param_regs = [_]Register{ .r0, .r1, .r2, .r3 };
pub const c_abi_int_return_regs = [_]Register{ .r0, .r1 };

/// Represents an instruction in the ARM instruction set architecture
pub const Instruction = union(enum) {
    DataProcessing: packed struct {
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
    SingleDataTransfer: packed struct {
        offset: u12,
        rd: u4,
        rn: u4,
        l: u1,
        w: u1,
        b: u1,
        u: u1,
        p: u1,
        i: u1,
        fixed: u2 = 0b01,
        cond: u4,
    },
    Branch: packed struct {
        offset: u24,
        link: u1,
        fixed: u3 = 0b101,
        cond: u4,
    },
    BranchExchange: packed struct {
        rn: u4,
        fixed_1: u1 = 0b1,
        link: u1,
        fixed_2: u22 = 0b0001_0010_1111_1111_1111_00,
        cond: u4,
    },
    SupervisorCall: packed struct {
        comment: u24,
        fixed: u4 = 0b1111,
        cond: u4,
    },
    Breakpoint: packed struct {
        imm4: u4,
        fixed_1: u4 = 0b0111,
        imm12: u12,
        fixed_2_and_cond: u12 = 0b1110_0001_0010,
    },

    /// Represents the possible operations which can be performed by a
    /// DataProcessing instruction
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
        Register: packed struct {
            rm: u4,
            shift: u8,
        },
        Immediate: packed struct {
            imm: u8,
            rotate: u4,
        },

        /// Represents multiple ways a register can be shifted. A
        /// register can be shifted by a specific immediate value or
        /// by the contents of another register
        pub const Shift = union(enum) {
            Immediate: packed struct {
                fixed: u1 = 0b0,
                typ: u2,
                amount: u5,
            },
            Register: packed struct {
                fixed_1: u1 = 0b1,
                typ: u2,
                fixed_2: u1 = 0b0,
                rs: u4,
            },

            const Type = enum(u2) {
                LogicalLeft,
                LogicalRight,
                ArithmeticRight,
                RotateRight,
            };

            const none = Shift{
                .Immediate = .{
                    .amount = 0,
                    .typ = 0,
                },
            };

            pub fn toU8(self: Shift) u8 {
                return switch (self) {
                    .Register => |v| @bitCast(u8, v),
                    .Immediate => |v| @bitCast(u8, v),
                };
            }

            pub fn reg(rs: Register, typ: Type) Shift {
                return Shift{
                    .Register = .{
                        .rs = rs.id(),
                        .typ = @enumToInt(typ),
                    },
                };
            }

            pub fn imm(amount: u5, typ: Type) Shift {
                return Shift{
                    .Immediate = .{
                        .amount = amount,
                        .typ = @enumToInt(typ),
                    },
                };
            }
        };

        pub fn toU12(self: Operand) u12 {
            return switch (self) {
                .Register => |v| @bitCast(u12, v),
                .Immediate => |v| @bitCast(u12, v),
            };
        }

        pub fn reg(rm: Register, shift: Shift) Operand {
            return Operand{
                .Register = .{
                    .rm = rm.id(),
                    .shift = shift.toU8(),
                },
            };
        }

        pub fn imm(immediate: u8, rotate: u4) Operand {
            return Operand{
                .Immediate = .{
                    .imm = immediate,
                    .rotate = rotate,
                },
            };
        }
    };

    /// Represents the offset operand of a load or store
    /// instruction. Data can be loaded from memory with either an
    /// immediate offset or an offset that is stored in some register.
    pub const Offset = union(enum) {
        Immediate: u12,
        Register: packed struct {
            rm: u4,
            shift: u8,
        },

        pub const none = Offset{
            .Immediate = 0,
        };

        pub fn toU12(self: Offset) u12 {
            return switch (self) {
                .Register => |v| @bitCast(u12, v),
                .Immediate => |v| v,
            };
        }

        pub fn reg(rm: Register, shift: u8) Offset {
            return Offset{
                .Register = .{
                    .rm = rm.id(),
                    .shift = shift,
                },
            };
        }

        pub fn imm(immediate: u8) Offset {
            return Offset{
                .Immediate = immediate,
            };
        }
    };

    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .DataProcessing => |v| @bitCast(u32, v),
            .SingleDataTransfer => |v| @bitCast(u32, v),
            .Branch => |v| @bitCast(u32, v),
            .BranchExchange => |v| @bitCast(u32, v),
            .SupervisorCall => |v| @bitCast(u32, v),
            .Breakpoint => |v| @intCast(u32, v.imm4) | (@intCast(u32, v.fixed_1) << 4) | (@intCast(u32, v.imm12) << 8) | (@intCast(u32, v.fixed_2_and_cond) << 20),
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
            .DataProcessing = .{
                .cond = @enumToInt(cond),
                .i = if (op2 == .Immediate) 1 else 0,
                .opcode = @enumToInt(opcode),
                .s = s,
                .rn = rn.id(),
                .rd = rd.id(),
                .op2 = op2.toU12(),
            },
        };
    }

    fn singleDataTransfer(
        cond: Condition,
        rd: Register,
        rn: Register,
        offset: Offset,
        pre_post: u1,
        up_down: u1,
        byte_word: u1,
        writeback: u1,
        load_store: u1,
    ) Instruction {
        return Instruction{
            .SingleDataTransfer = .{
                .cond = @enumToInt(cond),
                .rn = rn.id(),
                .rd = rd.id(),
                .offset = offset.toU12(),
                .l = load_store,
                .w = writeback,
                .b = byte_word,
                .u = up_down,
                .p = pre_post,
                .i = if (offset == .Immediate) 0 else 1,
            },
        };
    }

    fn branch(cond: Condition, offset: i24, link: u1) Instruction {
        return Instruction{
            .Branch = .{
                .cond = @enumToInt(cond),
                .link = link,
                .offset = @bitCast(u24, offset),
            },
        };
    }

    fn branchExchange(cond: Condition, rn: Register, link: u1) Instruction {
        return Instruction{
            .BranchExchange = .{
                .cond = @enumToInt(cond),
                .link = link,
                .rn = rn.id(),
            },
        };
    }

    fn supervisorCall(cond: Condition, comment: u24) Instruction {
        return Instruction{
            .SupervisorCall = .{
                .cond = @enumToInt(cond),
                .comment = comment,
            },
        };
    }

    fn breakpoint(imm: u16) Instruction {
        return Instruction{
            .Breakpoint = .{
                .imm12 = @truncate(u12, imm >> 4),
                .imm4 = @truncate(u4, imm),
            },
        };
    }

    // Public functions replicating assembler syntax as closely as
    // possible

    // Data processing

    pub fn @"and"(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .@"and", s, rd, rn, op2);
    }

    pub fn eor(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .eor, s, rd, rn, op2);
    }

    pub fn sub(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .sub, s, rd, rn, op2);
    }

    pub fn rsb(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .rsb, s, rd, rn, op2);
    }

    pub fn add(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .add, s, rd, rn, op2);
    }

    pub fn adc(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .adc, s, rd, rn, op2);
    }

    pub fn sbc(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .sbc, s, rd, rn, op2);
    }

    pub fn rsc(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .rsc, s, rd, rn, op2);
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

    pub fn orr(cond: Condition, s: u1, rd: Register, rn: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .orr, s, rd, rn, op2);
    }

    pub fn mov(cond: Condition, s: u1, rd: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .mov, s, rd, .r0, op2);
    }

    pub fn bic(cond: Condition, s: u1, rd: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .bic, s, rd, rn, op2);
    }

    pub fn mvn(cond: Condition, s: u1, rd: Register, op2: Operand) Instruction {
        return dataProcessing(cond, .mvn, s, rd, .r0, op2);
    }

    // Single data transfer

    pub fn ldr(cond: Condition, rd: Register, rn: Register, offset: Offset) Instruction {
        return singleDataTransfer(cond, rd, rn, offset, 1, 1, 0, 0, 1);
    }

    pub fn str(cond: Condition, rd: Register, rn: Register, offset: Offset) Instruction {
        return singleDataTransfer(cond, rd, rn, offset, 1, 1, 0, 0, 0);
    }

    // Branch

    pub fn b(cond: Condition, offset: i24) Instruction {
        return branch(cond, offset, 0);
    }

    pub fn bl(cond: Condition, offset: i24) Instruction {
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
};

test "serialize instructions" {
    const Testcase = struct {
        inst: Instruction,
        expected: u32,
    };

    const testcases = [_]Testcase{
        .{ // add r0, r0, r0
            .inst = Instruction.add(.al, 0, .r0, .r0, Instruction.Operand.reg(.r0, Instruction.Operand.Shift.none)),
            .expected = 0b1110_00_0_0100_0_0000_0000_00000000_0000,
        },
        .{ // mov r4, r2
            .inst = Instruction.mov(.al, 0, .r4, Instruction.Operand.reg(.r2, Instruction.Operand.Shift.none)),
            .expected = 0b1110_00_0_1101_0_0000_0100_00000000_0010,
        },
        .{ // mov r0, #42
            .inst = Instruction.mov(.al, 0, .r0, Instruction.Operand.imm(42, 0)),
            .expected = 0b1110_00_1_1101_0_0000_0000_0000_00101010,
        },
        .{ // ldr r0, [r2, #42]
            .inst = Instruction.ldr(.al, .r0, .r2, Instruction.Offset.imm(42)),
            .expected = 0b1110_01_0_1_1_0_0_1_0010_0000_000000101010,
        },
        .{ // str r0, [r3]
            .inst = Instruction.str(.al, .r0, .r3, Instruction.Offset.none),
            .expected = 0b1110_01_0_1_1_0_0_0_0011_0000_000000000000,
        },
        .{ // b #12
            .inst = Instruction.b(.al, 12),
            .expected = 0b1110_101_0_0000_0000_0000_0000_0000_1100,
        },
        .{ // bl #-4
            .inst = Instruction.bl(.al, -4),
            .expected = 0b1110_101_1_1111_1111_1111_1111_1111_1100,
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
    };

    for (testcases) |case| {
        const actual = case.inst.toU32();
        testing.expectEqual(case.expected, actual);
    }
}
