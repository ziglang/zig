const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
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

/// Encoding helper functions for x86_64 instructions
///
/// Many of these helpers do very little, but they can help make things
/// slightly more readable with more descriptive field names / function names.
///
/// Some of them also have asserts to ensure that we aren't doing dumb things.
/// For example, trying to use register 4 (esp) in an indirect modr/m byte is illegal,
/// you need to encode it with an SIB byte.
///
/// Note that ALL of these helper functions will assume capacity,
/// so ensure that the `code` has sufficient capacity before using them.
/// The `init` method is the recommended way to ensure capacity.
pub const Encoder = struct {
    /// Non-owning reference to the code array
    code: *ArrayList(u8),

    const Self = @This();

    /// Wrap `code` in Encoder to make it easier to call these helper functions
    ///
    /// maximum_inst_size should contain the maximum number of bytes
    /// that the encoded instruction will take.
    /// This is because the helper functions will assume capacity
    /// in order to avoid bounds checking.
    pub fn init(code: *ArrayList(u8), maximum_inst_size: u8) !Self {
        try code.ensureUnusedCapacity(maximum_inst_size);
        return Self{ .code = code };
    }

    /// Directly write a number to the code array with big endianness
    pub fn writeIntBig(self: Self, comptime T: type, value: T) void {
        mem.writeIntBig(
            T,
            self.code.addManyAsArrayAssumeCapacity(@divExact(@typeInfo(T).Int.bits, 8)),
            value,
        );
    }

    /// Directly write a number to the code array with little endianness
    pub fn writeIntLittle(self: Self, comptime T: type, value: T) void {
        mem.writeIntLittle(
            T,
            self.code.addManyAsArrayAssumeCapacity(@divExact(@typeInfo(T).Int.bits, 8)),
            value,
        );
    }

    // --------
    // Prefixes
    // --------

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

        /// Operand size override (enables 16 bit operation)
        prefix_66: bool = false,

        /// Address size override (enables 16 bit address size)
        prefix_67: bool = false,

        padding: u5 = 0,
    };

    /// Encodes legacy prefixes
    pub fn legacyPrefixes(self: Self, prefixes: LegacyPrefixes) void {
        if (@bitCast(u16, prefixes) != 0) {
            // Hopefully this path isn't taken very often, so we'll do it the slow way for now

            // LOCK
            if (prefixes.prefix_f0) self.code.appendAssumeCapacity(0xf0);
            // REPNZ, REPNE, REP, Scalar Double-precision
            if (prefixes.prefix_f2) self.code.appendAssumeCapacity(0xf2);
            // REPZ, REPE, REP, Scalar Single-precision
            if (prefixes.prefix_f3) self.code.appendAssumeCapacity(0xf3);

            // CS segment override or Branch not taken
            if (prefixes.prefix_2e) self.code.appendAssumeCapacity(0x2e);
            // DS segment override
            if (prefixes.prefix_36) self.code.appendAssumeCapacity(0x36);
            // ES segment override
            if (prefixes.prefix_26) self.code.appendAssumeCapacity(0x26);
            // FS segment override
            if (prefixes.prefix_64) self.code.appendAssumeCapacity(0x64);
            // GS segment override
            if (prefixes.prefix_65) self.code.appendAssumeCapacity(0x65);

            // Branch taken
            if (prefixes.prefix_3e) self.code.appendAssumeCapacity(0x3e);

            // Operand size override
            if (prefixes.prefix_66) self.code.appendAssumeCapacity(0x66);

            // Address size override
            if (prefixes.prefix_67) self.code.appendAssumeCapacity(0x67);
        }
    }

    /// Use 16 bit operand size
    ///
    /// Note that this flag is overridden by REX.W, if both are present.
    pub fn prefix16BitMode(self: Self) void {
        self.code.appendAssumeCapacity(0x66);
    }

    /// From section 2.2.1.2 of the manual, REX is encoded as b0100WRXB
    pub const Rex = struct {
        /// Wide, enables 64-bit operation
        w: bool = false,
        /// Extends the reg field in the ModR/M byte
        r: bool = false,
        /// Extends the index field in the SIB byte
        x: bool = false,
        /// Extends the r/m field in the ModR/M byte,
        ///      or the base field in the SIB byte,
        ///      or the reg field in the Opcode byte
        b: bool = false,
    };

    /// Encodes a REX prefix byte given all the fields
    ///
    /// Use this byte whenever you need 64 bit operation,
    /// or one of reg, index, r/m, base, or opcode-reg might be extended.
    ///
    /// See struct `Rex` for a description of each field.
    ///
    /// Does not add a prefix byte if none of the fields are set!
    pub fn rex(self: Self, byte: Rex) void {
        var value: u8 = 0b0100_0000;

        if (byte.w) value |= 0b1000;
        if (byte.r) value |= 0b0100;
        if (byte.x) value |= 0b0010;
        if (byte.b) value |= 0b0001;

        if (value != 0b0100_0000) {
            self.code.appendAssumeCapacity(value);
        }
    }

    // ------
    // Opcode
    // ------

    /// Encodes a 1 byte opcode
    pub fn opcode_1byte(self: Self, opcode: u8) void {
        self.code.appendAssumeCapacity(opcode);
    }

    /// Encodes a 2 byte opcode
    ///
    /// e.g. IMUL has the opcode 0x0f 0xaf, so you use
    ///
    /// encoder.opcode_2byte(0x0f, 0xaf);
    pub fn opcode_2byte(self: Self, prefix: u8, opcode: u8) void {
        self.code.appendAssumeCapacity(prefix);
        self.code.appendAssumeCapacity(opcode);
    }

    /// Encodes a 1 byte opcode with a reg field
    ///
    /// Remember to add a REX prefix byte if reg is extended!
    pub fn opcode_withReg(self: Self, opcode: u8, reg: u3) void {
        assert(opcode & 0b111 == 0);
        self.code.appendAssumeCapacity(opcode | reg);
    }

    // ------
    // ModR/M
    // ------

    /// Construct a ModR/M byte given all the fields
    ///
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm(self: Self, mod: u2, reg_or_opx: u3, rm: u3) void {
        self.code.appendAssumeCapacity(
            @as(u8, mod) << 6 | @as(u8, reg_or_opx) << 3 | rm,
        );
    }

    /// Construct a ModR/M byte using direct r/m addressing
    /// r/m effective address: r/m
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_direct(self: Self, reg_or_opx: u3, rm: u3) void {
        self.modRm(0b11, reg_or_opx, rm);
    }

    /// Construct a ModR/M byte using indirect r/m addressing
    /// r/m effective address: [r/m]
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_indirectDisp0(self: Self, reg_or_opx: u3, rm: u3) void {
        assert(rm != 4 and rm != 5);
        self.modRm(0b00, reg_or_opx, rm);
    }

    /// Construct a ModR/M byte using indirect SIB addressing
    /// r/m effective address: [SIB]
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_SIBDisp0(self: Self, reg_or_opx: u3) void {
        self.modRm(0b00, reg_or_opx, 0b100);
    }

    /// Construct a ModR/M byte using RIP-relative addressing
    /// r/m effective address: [RIP + disp32]
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_RIPDisp32(self: Self, reg_or_opx: u3) void {
        self.modRm(0b00, reg_or_opx, 0b101);
    }

    /// Construct a ModR/M byte using indirect r/m with a 8bit displacement
    /// r/m effective address: [r/m + disp8]
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_indirectDisp8(self: Self, reg_or_opx: u3, rm: u3) void {
        assert(rm != 4);
        self.modRm(0b01, reg_or_opx, rm);
    }

    /// Construct a ModR/M byte using indirect SIB with a 8bit displacement
    /// r/m effective address: [SIB + disp8]
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_SIBDisp8(self: Self, reg_or_opx: u3) void {
        self.modRm(0b01, reg_or_opx, 0b100);
    }

    /// Construct a ModR/M byte using indirect r/m with a 32bit displacement
    /// r/m effective address: [r/m + disp32]
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_indirectDisp32(self: Self, reg_or_opx: u3, rm: u3) void {
        assert(rm != 4);
        self.modRm(0b10, reg_or_opx, rm);
    }

    /// Construct a ModR/M byte using indirect SIB with a 32bit displacement
    /// r/m effective address: [SIB + disp32]
    ///
    /// Note reg's effective address is always just reg for the ModR/M byte.
    /// Remember to add a REX prefix byte if reg or rm are extended!
    pub fn modRm_SIBDisp32(self: Self, reg_or_opx: u3) void {
        self.modRm(0b10, reg_or_opx, 0b100);
    }

    // ---
    // SIB
    // ---

    /// Construct a SIB byte given all the fields
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib(self: Self, scale: u2, index: u3, base: u3) void {
        self.code.appendAssumeCapacity(
            @as(u8, scale) << 6 | @as(u8, index) << 3 | base,
        );
    }

    /// Construct a SIB byte with scale * index + base, no frills.
    /// r/m effective address: [base + scale * index]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_scaleIndexBase(self: Self, scale: u2, index: u3, base: u3) void {
        assert(base != 5);

        self.sib(scale, index, base);
    }

    /// Construct a SIB byte with scale * index + disp32
    /// r/m effective address: [scale * index + disp32]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_scaleIndexDisp32(self: Self, scale: u2, index: u3) void {
        assert(index != 4);

        // scale is actually ignored
        // index = 4 means no index
        // base = 5 means no base, if mod == 0.
        self.sib(scale, index, 5);
    }

    /// Construct a SIB byte with just base
    /// r/m effective address: [base]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_base(self: Self, base: u3) void {
        assert(base != 5);

        // scale is actually ignored
        // index = 4 means no index
        self.sib(0, 4, base);
    }

    /// Construct a SIB byte with just disp32
    /// r/m effective address: [disp32]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_disp32(self: Self) void {
        // scale is actually ignored
        // index = 4 means no index
        // base = 5 means no base, if mod == 0.
        self.sib(0, 4, 5);
    }

    /// Construct a SIB byte with scale * index + base + disp8
    /// r/m effective address: [base + scale * index + disp8]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_scaleIndexBaseDisp8(self: Self, scale: u2, index: u3, base: u3) void {
        self.sib(scale, index, base);
    }

    /// Construct a SIB byte with base + disp8, no index
    /// r/m effective address: [base + disp8]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_baseDisp8(self: Self, base: u3) void {
        // scale is ignored
        // index = 4 means no index
        self.sib(0, 4, base);
    }

    /// Construct a SIB byte with scale * index + base + disp32
    /// r/m effective address: [base + scale * index + disp32]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_scaleIndexBaseDisp32(self: Self, scale: u2, index: u3, base: u3) void {
        self.sib(scale, index, base);
    }

    /// Construct a SIB byte with base + disp32, no index
    /// r/m effective address: [base + disp32]
    ///
    /// Remember to add a REX prefix byte if index or base are extended!
    pub fn sib_baseDisp32(self: Self, base: u3) void {
        // scale is ignored
        // index = 4 means no index
        self.sib(0, 4, base);
    }

    // -------------------------
    // Trivial (no bit fiddling)
    // -------------------------

    /// Encode an 8 bit immediate
    ///
    /// It is sign-extended to 64 bits by the cpu.
    pub fn imm8(self: Self, imm: i8) void {
        self.code.appendAssumeCapacity(@bitCast(u8, imm));
    }

    /// Encode an 8 bit displacement
    ///
    /// It is sign-extended to 64 bits by the cpu.
    pub fn disp8(self: Self, disp: i8) void {
        self.code.appendAssumeCapacity(@bitCast(u8, disp));
    }

    /// Encode an 16 bit immediate
    ///
    /// It is sign-extended to 64 bits by the cpu.
    pub fn imm16(self: Self, imm: i16) void {
        self.writeIntLittle(i16, imm);
    }

    /// Encode an 32 bit immediate
    ///
    /// It is sign-extended to 64 bits by the cpu.
    pub fn imm32(self: Self, imm: i32) void {
        self.writeIntLittle(i32, imm);
    }

    /// Encode an 32 bit displacement
    ///
    /// It is sign-extended to 64 bits by the cpu.
    pub fn disp32(self: Self, disp: i32) void {
        self.writeIntLittle(i32, disp);
    }

    /// Encode an 64 bit immediate
    ///
    /// It is sign-extended to 64 bits by the cpu.
    pub fn imm64(self: Self, imm: u64) void {
        self.writeIntLittle(u64, imm);
    }
};

test "x86_64 Encoder helpers" {
    var code = ArrayList(u8).init(testing.allocator);
    defer code.deinit();

    // simple integer multiplication

    // imul eax,edi
    // 0faf   c7
    {
        try code.resize(0);
        const encoder = try Encoder.init(&code, 4);
        encoder.rex(.{
            .r = Register.eax.isExtended(),
            .b = Register.edi.isExtended(),
        });
        encoder.opcode_2byte(0x0f, 0xaf);
        encoder.modRm_direct(
            Register.eax.low_id(),
            Register.edi.low_id(),
        );

        try testing.expectEqualSlices(u8, &[_]u8{ 0x0f, 0xaf, 0xc7 }, code.items);
    }

    // simple mov

    // mov eax,edi
    // 89    f8
    {
        try code.resize(0);
        const encoder = try Encoder.init(&code, 3);
        encoder.rex(.{
            .r = Register.edi.isExtended(),
            .b = Register.eax.isExtended(),
        });
        encoder.opcode_1byte(0x89);
        encoder.modRm_direct(
            Register.edi.low_id(),
            Register.eax.low_id(),
        );

        try testing.expectEqualSlices(u8, &[_]u8{ 0x89, 0xf8 }, code.items);
    }

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
    {
        try code.resize(0);
        const encoder = try Encoder.init(&code, 7);
        encoder.rex(.{ .w = true }); // use 64 bit operation
        encoder.opcode_1byte(0x81);
        encoder.modRm_direct(
            0,
            Register.rcx.low_id(),
        );
        encoder.imm32(2147483647);

        try testing.expectEqualSlices(u8, &[_]u8{ 0x48, 0x81, 0xc1, 0xff, 0xff, 0xff, 0x7f }, code.items);
    }
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
