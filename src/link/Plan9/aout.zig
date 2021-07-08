const std = @import("std");
const assert = std.debug.assert;

/// All integers are in big-endian format (needs a byteswap).
pub const ExecHdr = extern struct {
    magic: u32,
    text: u32,
    data: u32,
    bss: u32,
    syms: u32,
    /// You should truncate this to 32 bits on 64 bit systems, then but the actual 8 bytes
    /// in the fat header.
    entry: u32,
    spsz: u32,
    pcsz: u32,
    comptime {
        assert(@sizeOf(@This()) == 32);
    }
    /// It is up to the caller to disgard the last 8 bytes if the header is not fat.
    pub fn toU8s(self: *@This()) [40]u8 {
        var buf: [40]u8 = undefined;
        var i: u8 = 0;
        inline for (std.meta.fields(@This())) |f| {
            std.mem.writeIntSliceBig(u32, buf[i .. i + 4], @field(self, f.name));
            i += 4;
        }
        return buf;
    }
};

pub const Sym = struct {
    /// Big endian in the file
    value: u64,
    type: Type,
    name: []const u8,

    /// The type field is one of the following characters with the
    /// high bit set:
    /// T    text segment symbol
    /// t    static text segment symbol
    /// L    leaf function text segment symbol
    /// l    static leaf function text segment symbol
    /// D    data segment symbol
    /// d    static data segment symbol
    /// B    bss segment symbol
    /// b    static bss segment symbol
    /// a    automatic (local) variable symbol
    /// p    function parameter symbol
    /// f    source file name components
    /// z    source file name
    /// Z    source file line offset
    /// m for '.frame'
    pub const Type = enum(u8) {
        T = 0x80 | 'T',
        t = 0x80 | 't',
        L = 0x80 | 'L',
        l = 0x80 | 'l',
        D = 0x80 | 'D',
        d = 0x80 | 'd',
        B = 0x80 | 'B',
        b = 0x80 | 'b',
        a = 0x80 | 'a',
        p = 0x80 | 'p',
        f = 0x80 | 'f',
        z = 0x80 | 'z',
        Z = 0x80 | 'Z',
        m = 0x80 | 'm',

        pub fn toGlobal(self: Type) Type {
            return switch (self) {
                .t => .T,
                .b => .B,
                .d => .D,
                else => unreachable,
            };
        }
    };
};

pub const HDR_MAGIC = 0x00008000;
pub inline fn _MAGIC(f: anytype, b: anytype) @TypeOf(f | ((((@as(c_int, 4) * b) + @as(c_int, 0)) * b) + @as(c_int, 7))) {
    return f | ((((@as(c_int, 4) * b) + @as(c_int, 0)) * b) + @as(c_int, 7));
}
pub const A_MAGIC = _MAGIC(0, 8); // 68020
pub const I_MAGIC = _MAGIC(0, 11); // intel 386
pub const J_MAGIC = _MAGIC(0, 12); // intel 960 (retired)
pub const K_MAGIC = _MAGIC(0, 13); // sparc
pub const V_MAGIC = _MAGIC(0, 16); // mips 3000 BE
pub const X_MAGIC = _MAGIC(0, 17); // att dsp 3210 (retired)
pub const M_MAGIC = _MAGIC(0, 18); // mips 4000 BE
pub const D_MAGIC = _MAGIC(0, 19); // amd 29000 (retired)
pub const E_MAGIC = _MAGIC(0, 20); // arm
pub const Q_MAGIC = _MAGIC(0, 21); // powerpc
pub const N_MAGIC = _MAGIC(0, 22); // mips 4000 LE
pub const L_MAGIC = _MAGIC(0, 23); // dec alpha (retired)
pub const P_MAGIC = _MAGIC(0, 24); // mips 3000 LE
pub const U_MAGIC = _MAGIC(0, 25); // sparc64
pub const S_MAGIC = _MAGIC(HDR_MAGIC, 26); // amd64
pub const T_MAGIC = _MAGIC(HDR_MAGIC, 27); // powerpc64
pub const R_MAGIC = _MAGIC(HDR_MAGIC, 28); // arm64

pub fn magicFromArch(arch: std.Target.Cpu.Arch) !u32 {
    return switch (arch) {
        .i386 => I_MAGIC,
        .sparc => K_MAGIC, // TODO should sparcv9 and sparcel go here?
        .mips => V_MAGIC,
        .arm => E_MAGIC,
        .aarch64 => R_MAGIC,
        .powerpc => Q_MAGIC,
        .powerpc64 => T_MAGIC,
        .x86_64 => S_MAGIC,
        else => error.ArchNotSupportedByPlan9,
    };
}
