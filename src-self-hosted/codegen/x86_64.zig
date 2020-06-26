// zig fmt: off

/// Definitions of all of the x64 registers. The order is very, very important.
/// The registers are defined such that IDs go in descending order of 64-bit,
/// 32-bit, 16-bit, and then 8-bit, and each set contains exactly sixteen
/// registers. This results in some very, very useful properties:
///
/// Any 64-bit register can be turned into its 32-bit form by adding 16, and
/// vice versa. This also works between 32-bit and 16-bit forms. With 8-bit, it
/// works for all except for sp, bp, si, and di, which don't *have* an 8-bit
/// form.
///
/// If (register & 8) is set, the register is extended.
///
/// The ID can be easily determined by figuring out what range the register is
/// in, and then subtracting the base.
/// 
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
    pub fn size(self: @This()) u7 {
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
    pub fn isExtended(self: @This()) bool {
        return @enumToInt(self) & 0x08 != 0;
    }

    /// This returns the 4-bit register ID, which is used in practically every
    /// opcode. Note that bit 3 (the highest bit) is *never* used directly in
    /// an instruction (@see isExtended), and requires special handling. The
    /// lower three bits are often embedded directly in instructions (such as
    /// the B8 variant of moves), or used in R/M bytes.
    pub fn id(self: @This()) u4 {
        return @truncate(u4, @enumToInt(self));
    }
};

// zig fmt: on

pub const SysV = struct {
    const Type = @import("../type.zig").Type;
    const Function = @import("../codegen.zig").Function;
    pub const ParameterClass = enum {
        INTEGER,
        SSE,
        SSEUP,
        X87,
        X87UP,
        COMPLEX_X87,
        NO_CLASS,
        MEMORY,
        pub fn classify(param_types: []Type, index: usize) @This() {
            const T = param_types[index];
            if (T.isInt() or T.tag() == .bool or T.isSinglePointer() or T.isCPtr()) {
                var i: usize = 0;
                var ints: u3 = 1;
                while (i < index) : (i += 1) {
                    const oT = param_types[i];
                    if (oT.isInt() or oT.tag() == .bool or oT.isSinglePointer() or oT.isCPtr()) {
                        ints += 1;
                    }
                }
                if (ints > 6) {
                    return .MEMORY;
                }
                return .INTEGER;
            }
            return .NO_CLASS;
        }
    };

    pub const IntegerRegs = [6]Register{
        .rdi,
        .rsi,
        .rdx,
        .rcx,
        .r8,
        .r9,
    };

    pub fn integerParameter(param_types: []Type, index: usize) Register {
        var i: usize = 0;
        var ints: u3 = 0;
        while (i < index) : (i += 1) {
            const oT = param_types[i];
            if (oT.isInt() or oT.tag() == .bool or oT.isSinglePointer() or oT.isCPtr()) {
                ints += 1;
            }
        }
        return IntegerRegs[ints];
    }
};
