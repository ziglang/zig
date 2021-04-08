const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Type = @import("../Type.zig");
const DW = std.dwarf;

// zig fmt: off

/// Definitions of all of the x64 registers. The order is semantically meaningful.
/// The registers are defined such that IDs go in descending order of 64-bit,
/// 32-bit, 16-bit, and then 8-bit, and each set contains exactly sixteen
/// registers. This results in some useful properties:
///
/// Any 64-bit register can be turned into its 32-bit form by adding 16, and
/// vice versa. This also works between 32-bit and 16-bit forms. With 8-bit, it
/// works for all except for sp, bp, si, and di, which do *not* have an 8-bit
/// form.
///
/// If (register & 8) is set, the register is extended.
///
/// The ID can be easily determined by figuring out what range the register is
/// in, and then subtracting the base.
pub const Register = enum(u8) {
    // 0 through 15, 64-bit registers. 8-15 are extended.
    // id is just the int value.
    rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi,
    r8, r9, r10, r11, r12, r13, r14, r15,

    // 16 through 31, 32-bit registers. 24-31 are extended.
    // id is int value - 16.
    eax, ecx, edx, ebx, esp, ebp, esi, edi, 
    r8d, r9d, r10d, r11d, r12d, r13d, r14d, r15d,

    // 32-47, 16-bit registers. 40-47 are extended.
    // id is int value - 32.
    ax, cx, dx, bx, sp, bp, si, di,
    r8w, r9w, r10w, r11w, r12w, r13w, r14w, r15w,
    
    // 48-63, 8-bit registers. 56-63 are extended.
    // id is int value - 48.
    al, cl, dl, bl, ah, ch, dh, bh,
    r8b, r9b, r10b, r11b, r12b, r13b, r14b, r15b,

    /// Returns the bit-width of the register.
    pub fn size(self: Register) u7 {
        return switch (@enumToInt(self)) {
            0...15 => 64,
            16...31 => 32,
            32...47 => 16,
            48...64 => 8,
            else => unreachable,
        };
    }

    /// Returns whether the register is *extended*. Extended registers are the
    /// new registers added with amd64, r8 through r15. This also includes any
    /// other variant of access to those registers, such as r8b, r15d, and so
    /// on. This is needed because access to these registers requires special
    /// handling via the REX prefix, via the B or R bits, depending on context.
    pub fn isExtended(self: Register) bool {
        return @enumToInt(self) & 0x08 != 0;
    }

    /// This returns the 4-bit register ID, which is used in practically every
    /// opcode. Note that bit 3 (the highest bit) is *never* used directly in
    /// an instruction (@see isExtended), and requires special handling. The
    /// lower three bits are often embedded directly in instructions (such as
    /// the B8 variant of moves), or used in R/M bytes.
    pub fn id(self: Register) u4 {
        return @truncate(u4, @enumToInt(self));
    }

    /// Like id, but only returns the lower 3 bits.
    pub fn low_id(self: Register) u3 {
        return @truncate(u3, @enumToInt(self));
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        return switch (self) {
            .rax, .eax, .ax, .al => 0,
            .rcx, .ecx, .cx, .cl => 1,
            .rdx, .edx, .dx, .dl => 2,
            .rsi, .esi, .si  => 3,
            .rdi, .edi, .di => 4,
            .r8, .r8d, .r8w, .r8b => 5,
            .r9, .r9d, .r9w, .r9b => 6,
            .r10, .r10d, .r10w, .r10b => 7,
            .r11, .r11d, .r11w, .r11b => 8,
            else => null,
        };
    }

    /// Convert from any register to its 64 bit alias.
    pub fn to64(self: Register) Register {
        return @intToEnum(Register, self.id());
    }

    /// Convert from any register to its 32 bit alias.
    pub fn to32(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 16);
    }

    /// Convert from any register to its 16 bit alias.
    pub fn to16(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 32);
    }

    /// Convert from any register to its 8 bit alias.
    pub fn to8(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 48);
    }

    pub fn dwarfLocOp(self: Register) u8 {
        return switch (self.to64()) {
            .rax => DW.OP_reg0,
            .rdx => DW.OP_reg1,
            .rcx => DW.OP_reg2,
            .rbx => DW.OP_reg3,
            .rsi => DW.OP_reg4,
            .rdi => DW.OP_reg5,
            .rbp => DW.OP_reg6,
            .rsp => DW.OP_reg7,

            .r8 => DW.OP_reg8,
            .r9 => DW.OP_reg9,
            .r10 => DW.OP_reg10,
            .r11 => DW.OP_reg11,
            .r12 => DW.OP_reg12,
            .r13 => DW.OP_reg13,
            .r14 => DW.OP_reg14,
            .r15 => DW.OP_reg15,

            else => unreachable,
        };
    }
};

// zig fmt: on

/// These registers belong to the called function.
pub const callee_preserved_regs = [_]Register{ .rax, .rcx, .rdx, .rsi, .rdi, .r8, .r9, .r10, .r11 };
pub const c_abi_int_param_regs = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9 };
pub const c_abi_int_return_regs = [_]Register{ .rax, .rdx };

/// Represents an unencoded x86 instruction.
///
/// Roughly based on the table headings at http://ref.x86asm.net/coder64.html
pub const Instruction = struct {
    /// Opcode prefix, needed for certain rare ops (e.g. MOVSS)
    opcode_prefix: ?u8 = null,

    /// One-byte primary opcode
    primary_opcode_1b: ?u8 = null,
    /// Two-byte primary opcode (always prefixed with 0f)
    primary_opcode_2b: ?u8 = null,
    // TODO: Support 3-byte opcodes

    /// Secondary opcode
    secondary_opcode: ?u8 = null,

    /// Opcode extension (to be placed in the ModR/M byte in place of reg)
    opcode_extension: ?u3 = null,

    /// Legacy prefixes to use with this instruction
    /// Most of the time, this field will be 0 and no prefixes are added.
    /// Otherwise, a prefix will be added for each field set.
    legacy_prefixes: LegacyPrefixes = .{},

    /// 64-bit operand size
    operand_size_64: bool = false,

    /// The opcode-reg field,
    /// stored in the 3 least significant bits of the opcode
    /// on certain instructions + REX if extended
    opcode_reg: ?Register = null,

    /// The reg field
    reg: ?Register = null,
    /// The mod + r/m field
    modrm: ?ModrmEffectiveAddress = null,
    /// Location of the 3rd operand, if applicable
    sib: ?SibEffectiveAddress = null,

    /// Number of bytes of immediate
    immediate_bytes: u8 = 0,
    /// The value of the immediate
    immediate: u64 = 0,

    /// See legacy_prefixes
    pub const LegacyPrefixes = packed struct {
        /// LOCK
        prefix_f0: bool = false,
        /// REPNZ, REPNE, REP, Scalar Double-precision
        prefix_f2: bool = false,
        /// REPZ, REPE, REP, Scalar Single-precision
        prefix_f3: bool = false,

        /// CS segment override or Branch not taken
        prefix_2e: bool = false,
        /// DS segment override
        prefix_36: bool = false,
        /// ES segment override
        prefix_26: bool = false,
        /// FS segment override
        prefix_64: bool = false,
        /// GS segment override
        prefix_65: bool = false,

        /// Branch taken
        prefix_3e: bool = false,

        /// Operand size override
        prefix_66: bool = false,

        /// Address size override
        prefix_67: bool = false,

        padding: u5 = 0,
    };

    /// Encodes an effective address for the Mod + R/M part of the ModR/M byte
    ///
    /// Note that depending on the instruction, not all effective addresses are allowed.
    ///
    /// Examples:
    ///   eax:       .reg = .eax
    ///   [eax]:     .mem = .eax
    ///   [eax + 8]: .mem_disp = .{ .reg = .eax, .disp = 8 }
    ///   [eax - 8]: .mem_disp = .{ .reg = .eax, .disp = -8 }
    ///   [55]:      .disp32 = 55
    pub const ModrmEffectiveAddress = union(enum) {
        reg: Register,
        mem: Register,
        mem_disp: struct {
            reg: Register,
            disp: i32,
        },
        disp32: u32,

        pub fn isExtended(self: @This()) bool {
            return switch (self) {
                .reg => |reg| reg.isExtended(),
                .mem => |memea| memea.isExtended(),
                .mem_disp => |mem_disp| mem_disp.reg.isExtended(),
                .disp32 => false,
            };
        }
    };

    /// Encodes an effective address for the SIB byte
    ///
    /// Note that depending on the instruction, not all effective addresses are allowed.
    ///
    /// Examples:
    ///   [eax + ebx * 2]:       .base_index = .{ .base = .eax, .index = .ebx, .scale = 2 }
    ///   [eax]:                 .base_index = .{ .base = .eax, .index = null, .scale = 1 }
    ///   [ebx * 2 + 256]:       .index_disp = .{ .index = .ebx, .scale = 2, .disp = 256 }
    ///   [[ebp] + ebx * 2 + 8]: .ebp_index_disp = .{ .index = .ebx, .scale = 2, .disp = 8 }
    pub const SibEffectiveAddress = union(enum) {
        base_index: struct {
            base: Register,
            index: ?Register,
            scale: u8, // 1, 2, 4, or 8
        },
        index_disp: struct {
            index: ?Register,
            scale: u8, // 1, 2, 4, or 8
            disp: u32,
        },
        ebp_index_disp: struct {
            index: ?Register,
            scale: u8, // 1, 2, 4, or 8
            disp: u32,
        },

        pub fn baseIsExtended(self: @This()) bool {
            return switch (self) {
                .base_index => |base_index| base_index.base.isExtended(),
                .index_disp, .ebp_index_disp => false,
            };
        }

        pub fn indexIsExtended(self: @This()) bool {
            return switch (self) {
                .base_index => |base_index| if (base_index.index) |idx| idx.isExtended() else false,
                .index_disp => |index_disp| if (index_disp.index) |idx| idx.isExtended() else false,
                .ebp_index_disp => |ebp_index_disp| if (ebp_index_disp.index) |idx| idx.isExtended() else false,
            };
        }
    };

    /// Writes the encoded Instruction to the code ArrayList
    pub fn encodeInto(inst: Instruction, code: *ArrayList(u8)) !void {
        // We need to write the following, in that order:
        // - Legacy prefixes (0 to 13 bytes)
        // - REX prefix (0 to 1 byte)
        // - Opcode (1, 2, or 3 bytes)
        // - ModR/M (0 or 1 byte)
        // - SIB (0 or 1 byte)
        // - Displacement (0, 1, 2, or 4 bytes)
        // - Immediate (0, 1, 2, 4, or 8 bytes)

        // By this calculation, an instruction could be up to 31 bytes long (will probably not happen)
        try code.ensureCapacity(code.items.len + 31);

        // Legacy prefixes
        if (@bitCast(u16, inst.legacy_prefixes) != 0) {
            // Hopefully this path isn't taken very often, so we'll do it the slow way for now

            // LOCK
            if (inst.legacy_prefixes.prefix_f0) code.appendAssumeCapacity(0xf0);
            // REPNZ, REPNE, REP, Scalar Double-precision
            if (inst.legacy_prefixes.prefix_f2) code.appendAssumeCapacity(0xf2);
            // REPZ, REPE, REP, Scalar Single-precision
            if (inst.legacy_prefixes.prefix_f3) code.appendAssumeCapacity(0xf3);

            // CS segment override or Branch not taken
            if (inst.legacy_prefixes.prefix_2e) code.appendAssumeCapacity(0x2e);
            // DS segment override
            if (inst.legacy_prefixes.prefix_36) code.appendAssumeCapacity(0x36);
            // ES segment override
            if (inst.legacy_prefixes.prefix_26) code.appendAssumeCapacity(0x26);
            // FS segment override
            if (inst.legacy_prefixes.prefix_64) code.appendAssumeCapacity(0x64);
            // GS segment override
            if (inst.legacy_prefixes.prefix_65) code.appendAssumeCapacity(0x65);

            // Branch taken
            if (inst.legacy_prefixes.prefix_3e) code.appendAssumeCapacity(0x3e);

            // Operand size override
            if (inst.legacy_prefixes.prefix_66) code.appendAssumeCapacity(0x66);

            // Address size override
            if (inst.legacy_prefixes.prefix_67) code.appendAssumeCapacity(0x67);
        }

        // REX prefix
        //
        // A REX prefix has the following form:
        //   0b0100_WRXB
        // 0100: fixed bits
        // W: stands for "wide", indicates that the instruction uses 64-bit operands.
        // R, X, and B each contain the 4th bit of a register
        // these have to be set when using registers 8-15.
        // R: stands for "reg", extends the reg field in the ModR/M byte.
        // X: stands for "index", extends the index field in the SIB byte.
        // B: stands for "base", extends either the r/m field in the ModR/M byte,
        //                                      the base field in the SIB byte,
        //                                      or the opcode reg field in the Opcode byte.
        {
            var value: u8 = 0x40;
            if (inst.opcode_reg) |opcode_reg| {
                if (opcode_reg.isExtended()) {
                    value |= 0x1;
                }
            }
            if (inst.modrm) |modrm| {
                if (modrm.isExtended()) {
                    value |= 0x1;
                }
            }
            if (inst.sib) |sib| {
                if (sib.baseIsExtended()) {
                    value |= 0x1;
                }
                if (sib.indexIsExtended()) {
                    value |= 0x2;
                }
            }
            if (inst.reg) |reg| {
                if (reg.isExtended()) {
                    value |= 0x4;
                }
            }
            if (inst.operand_size_64) {
                value |= 0x8;
            }
            if (value != 0x40) {
                code.appendAssumeCapacity(value);
            }
        }

        // Opcode
        if (inst.primary_opcode_1b) |opcode| {
            var value = opcode;
            if (inst.opcode_reg) |opcode_reg| {
                value |= opcode_reg.low_id();
            }
            code.appendAssumeCapacity(value);
        } else if (inst.primary_opcode_2b) |opcode| {
            code.appendAssumeCapacity(0x0f);
            var value = opcode;
            if (inst.opcode_reg) |opcode_reg| {
                value |= opcode_reg.low_id();
            }
            code.appendAssumeCapacity(value);
        }

        var disp8: ?u8 = null;
        var disp16: ?u16 = null;
        var disp32: ?u32 = null;

        // ModR/M
        //
        // Example ModR/M byte:
        //   c7: ModR/M byte that contains:
        //     11 000 111:
        //     ^  ^   ^
        //   mod  |   |
        //      reg   |
        //          r/m
        //   where mod = 11 indicates that both operands are registers,
        //         reg = 000 indicates that the first operand is register EAX
        //         r/m = 111 indicates that the second operand is register EDI (since mod = 11)
        if (inst.modrm != null or inst.reg != null or inst.opcode_extension != null) {
            var value: u8 = 0;

            // mod + rm
            if (inst.modrm) |modrm| {
                switch (modrm) {
                    .reg => |reg| {
                        value |= reg.low_id();
                        value |= 0b11_000_000;
                    },
                    .mem => |memea| {
                        assert(memea.low_id() != 4 and memea.low_id() != 5);
                        value |= memea.low_id();
                        // value |= 0b00_000_000;
                    },
                    .mem_disp => |mem_disp| {
                        assert(mem_disp.reg.low_id() != 4);
                        value |= mem_disp.reg.low_id();
                        if (mem_disp.disp < 128) {
                            // Use 1 byte of displacement
                            value |= 0b01_000_000;
                            disp8 = @bitCast(u8, @intCast(i8, mem_disp.disp));
                        } else {
                            // Use all 4 bytes of displacement
                            value |= 0b10_000_000;
                            disp32 = @bitCast(u32, mem_disp.disp);
                        }
                    },
                    .disp32 => |d| {
                        value |= 0b00_000_101;
                        disp32 = d;
                    },
                }
            }

            // reg
            if (inst.reg) |reg| {
                value |= @as(u8, reg.low_id()) << 3;
            } else if (inst.opcode_extension) |ext| {
                value |= @as(u8, ext) << 3;
            }

            code.appendAssumeCapacity(value);
        }

        // SIB
        {
            if (inst.sib) |sib| {
                return error.TODOSIBByteForX8664;
            }
        }

        // Displacement
        //
        // The size of the displacement depends on the instruction used and is very fragile.
        // The bytes are simply written in LE order.
        {

            // These writes won't fail because we ensured capacity earlier.
            if (disp8) |d|
                code.appendAssumeCapacity(d)
            else if (disp16) |d|
                mem.writeIntLittle(u16, code.addManyAsArrayAssumeCapacity(2), d)
            else if (disp32) |d|
                mem.writeIntLittle(u32, code.addManyAsArrayAssumeCapacity(4), d);
        }

        // Immediate
        //
        // The size of the immediate depends on the instruction used and is very fragile.
        // The bytes are simply written in LE order.
        {
            // These writes won't fail because we ensured capacity earlier.
            if (inst.immediate_bytes == 1)
                code.appendAssumeCapacity(@intCast(u8, inst.immediate))
            else if (inst.immediate_bytes == 2)
                mem.writeIntLittle(u16, code.addManyAsArrayAssumeCapacity(2), @intCast(u16, inst.immediate))
            else if (inst.immediate_bytes == 4)
                mem.writeIntLittle(u32, code.addManyAsArrayAssumeCapacity(4), @intCast(u32, inst.immediate))
            else if (inst.immediate_bytes == 8)
                mem.writeIntLittle(u64, code.addManyAsArrayAssumeCapacity(8), inst.immediate);
        }
    }
};

fn expectEncoded(inst: Instruction, expected: []const u8) !void {
    var code = ArrayList(u8).init(testing.allocator);
    defer code.deinit();
    try inst.encodeInto(&code);
    testing.expectEqualSlices(u8, expected, code.items);
}

test "x86_64 Instruction.encodeInto" {
    // simple integer multiplication

    // imul eax,edi
    // 0faf   c7
    try expectEncoded(Instruction{
        .primary_opcode_2b = 0xaf, // imul
        .reg = .eax, // destination
        .modrm = .{ .reg = .edi }, // source
    }, &[_]u8{ 0x0f, 0xaf, 0xc7 });

    // simple mov

    // mov eax,edi
    // 89    f8
    try expectEncoded(Instruction{
        .primary_opcode_1b = 0x89, // mov (with rm as destination)
        .reg = .edi, // source
        .modrm = .{ .reg = .eax }, // destination
    }, &[_]u8{ 0x89, 0xf8 });

    // signed integer addition of 32-bit sign extended immediate to 64 bit register

    // add rcx, 2147483647
    //
    // Using the following opcode: REX.W + 81 /0 id, we expect the following encoding
    //
    // 48       :  REX.W set for 64 bit operand (*r*cx)
    // 81       :  opcode for "<arithmetic> with immediate"
    // c1       :  id = rcx,
    //          :  c1 = 11  <-- mod = 11 indicates r/m is register (rcx)
    //          :       000 <-- opcode_extension = 0 because opcode extension is /0. /0 specifies ADD
    //          :       001 <-- 001 is rcx
    // ffffff7f :  2147483647
    try expectEncoded(Instruction{
        // REX.W +
        .operand_size_64 = true,
        // 81
        .primary_opcode_1b = 0x81,
        // /0
        .opcode_extension = 0,
        // rcx
        .modrm = .{ .reg = .rcx },
        // immediate
        .immediate_bytes = 4,
        .immediate = 2147483647,
    }, &[_]u8{ 0x48, 0x81, 0xc1, 0xff, 0xff, 0xff, 0x7f });
}

// TODO add these registers to the enum and populate dwarfLocOp
//    // Return Address register. This is stored in `0(%rsp, "")` and is not a physical register.
//    RA = (16, "RA"),
//
//    XMM0 = (17, "xmm0"),
//    XMM1 = (18, "xmm1"),
//    XMM2 = (19, "xmm2"),
//    XMM3 = (20, "xmm3"),
//    XMM4 = (21, "xmm4"),
//    XMM5 = (22, "xmm5"),
//    XMM6 = (23, "xmm6"),
//    XMM7 = (24, "xmm7"),
//
//    XMM8 = (25, "xmm8"),
//    XMM9 = (26, "xmm9"),
//    XMM10 = (27, "xmm10"),
//    XMM11 = (28, "xmm11"),
//    XMM12 = (29, "xmm12"),
//    XMM13 = (30, "xmm13"),
//    XMM14 = (31, "xmm14"),
//    XMM15 = (32, "xmm15"),
//
//    ST0 = (33, "st0"),
//    ST1 = (34, "st1"),
//    ST2 = (35, "st2"),
//    ST3 = (36, "st3"),
//    ST4 = (37, "st4"),
//    ST5 = (38, "st5"),
//    ST6 = (39, "st6"),
//    ST7 = (40, "st7"),
//
//    MM0 = (41, "mm0"),
//    MM1 = (42, "mm1"),
//    MM2 = (43, "mm2"),
//    MM3 = (44, "mm3"),
//    MM4 = (45, "mm4"),
//    MM5 = (46, "mm5"),
//    MM6 = (47, "mm6"),
//    MM7 = (48, "mm7"),
//
//    RFLAGS = (49, "rFLAGS"),
//    ES = (50, "es"),
//    CS = (51, "cs"),
//    SS = (52, "ss"),
//    DS = (53, "ds"),
//    FS = (54, "fs"),
//    GS = (55, "gs"),
//
//    FS_BASE = (58, "fs.base"),
//    GS_BASE = (59, "gs.base"),
//
//    TR = (62, "tr"),
//    LDTR = (63, "ldtr"),
//    MXCSR = (64, "mxcsr"),
//    FCW = (65, "fcw"),
//    FSW = (66, "fsw"),
//
//    XMM16 = (67, "xmm16"),
//    XMM17 = (68, "xmm17"),
//    XMM18 = (69, "xmm18"),
//    XMM19 = (70, "xmm19"),
//    XMM20 = (71, "xmm20"),
//    XMM21 = (72, "xmm21"),
//    XMM22 = (73, "xmm22"),
//    XMM23 = (74, "xmm23"),
//    XMM24 = (75, "xmm24"),
//    XMM25 = (76, "xmm25"),
//    XMM26 = (77, "xmm26"),
//    XMM27 = (78, "xmm27"),
//    XMM28 = (79, "xmm28"),
//    XMM29 = (80, "xmm29"),
//    XMM30 = (81, "xmm30"),
//    XMM31 = (82, "xmm31"),
//
//    K0 = (118, "k0"),
//    K1 = (119, "k1"),
//    K2 = (120, "k2"),
//    K3 = (121, "k3"),
//    K4 = (122, "k4"),
//    K5 = (123, "k5"),
//    K6 = (124, "k6"),
//    K7 = (125, "k7"),
