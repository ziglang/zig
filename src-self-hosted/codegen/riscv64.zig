pub const Instructions = struct {
    pub const CallBreak = packed struct {
        pub const Mode = packed enum(u12) { ecall, ebreak };
        opcode: u7 = 0b1110011,
        unused1: u5 = 0,
        unused2: u3 = 0,
        unused3: u5 = 0,
        mode: u12,
    };
    pub const Addi = packed struct {
        pub const Mode = packed enum(u3) { addi = 0b000, slti = 0b010, sltiu = 0b011, xori = 0b100, ori = 0b110, andi = 0b111 };
        opcode: u7 = 0b0010011,
        rd: u5,
        mode: u3,
        rsi1: u5,
        imm: u11,
        signextend: u1 = 0,
    };
};

// zig fmt: off
pub const Register = enum(u8) {
    // 64 bit registers
    zero = 0, // zero
    ra = 1, // return address. caller saved
    sp = 2, // stack pointer. callee saved.
    gp = 3, // global pointer
    tp = 4, // thread pointer
    t0 = 5, t1 = 6, t2 = 7, // temporaries. caller saved.
    s0 = 8, // s0/fp, callee saved.
    s1, // callee saved.
    a0, a1, // fn args/return values. caller saved.
    a2, a3, a4, a5, a6, a7, // fn args. caller saved.
    s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, // saved registers. callee saved.
    t3, t4, t5, t6, // caller saved

    /// Returns the bit-width of the register.
    pub fn size(self: @This()) u7 {
        return switch (@enumToInt(self)) {
            0...31 => 64,
            else => unreachable,
        };
    }
    
    pub fn to64(self: @This()) Register {
        return self;
    }

    /// Returns the register's id. This is used in practically every opcode the
    /// riscv64 has.
    pub fn id(self: @This()) u5 {
        return @truncate(u5, @enumToInt(self));
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        inline for(callee_preserved_regs) |cpreg, i| {
            if(self == cpreg) return i;
        }
        return null;
    }
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{
    .s0, .s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
};
