const std = @import("std");
const mem = std.mem;

pub const Prefix = enum(u8) {
    binary = 2,
    octal = 8,
    decimal = 10,
    hex = 16,

    pub fn digitAllowed(prefix: Prefix, c: u8) bool {
        return switch (c) {
            '0', '1' => true,
            '2'...'7' => prefix != .binary,
            '8'...'9' => prefix == .decimal or prefix == .hex,
            'a'...'f', 'A'...'F' => prefix == .hex,
            else => false,
        };
    }

    pub fn fromString(buf: []const u8) Prefix {
        if (buf.len == 1) return .decimal;
        // tokenizer enforces that first byte is a decimal digit or period
        switch (buf[0]) {
            '.', '1'...'9' => return .decimal,
            '0' => {},
            else => unreachable,
        }
        switch (buf[1]) {
            'x', 'X' => return if (buf.len == 2) .decimal else .hex,
            'b', 'B' => return if (buf.len == 2) .decimal else .binary,
            else => {
                if (mem.indexOfAny(u8, buf, "eE.")) |_| {
                    // This is a decimal floating point number that happens to start with zero
                    return .decimal;
                } else if (Suffix.fromString(buf[1..], .int)) |_| {
                    // This is `0` with a valid suffix
                    return .decimal;
                } else {
                    return .octal;
                }
            },
        }
    }

    /// Length of this prefix as a string
    pub fn stringLen(prefix: Prefix) usize {
        return switch (prefix) {
            .binary => 2,
            .octal => 1,
            .decimal => 0,
            .hex => 2,
        };
    }
};

pub const Suffix = enum {
    // zig fmt: off

    // int and imaginary int
    None, I,

    // unsigned real integers
    U, UL, ULL,

    // unsigned imaginary integers
    IU, IUL, IULL,

    // long or long double, real and imaginary
    L, IL,

    // long long and imaginary long long
    LL, ILL,

    // float and imaginary float
    F, IF,

    // _Float16 and imaginary _Float16
    F16, IF16,

    // __float80
    W,

    // Imaginary __float80
    IW,

    // _Float128
    Q, F128,

    // Imaginary _Float128
    IQ, IF128,

    // Imaginary _Bitint
    IWB, IUWB,

    // _Bitint
    WB, UWB,

    // __bf16
    BF16,

    // _Float32 and imaginary _Float32
    F32, IF32,

    // _Float64 and imaginary _Float64
    F64, IF64,

    // _Float32x and imaginary _Float32x
    F32x, IF32x,

    // _Float64x and imaginary _Float64x
    F64x, IF64x,

    // _Decimal32
    D32,

    // _Decimal64
    D64,

    // _Decimal128
    D128,

    // _Decimal64x
    D64x,

    // zig fmt: on

    const Tuple = struct { Suffix, []const []const u8 };

    const IntSuffixes = &[_]Tuple{
        .{ .U, &.{"U"} },
        .{ .L, &.{"L"} },
        .{ .WB, &.{"WB"} },
        .{ .UL, &.{ "U", "L" } },
        .{ .UWB, &.{ "U", "WB" } },
        .{ .LL, &.{"LL"} },
        .{ .ULL, &.{ "U", "LL" } },

        .{ .I, &.{"I"} },

        .{ .IWB, &.{ "I", "WB" } },
        .{ .IU, &.{ "I", "U" } },
        .{ .IL, &.{ "I", "L" } },
        .{ .IUL, &.{ "I", "U", "L" } },
        .{ .IUWB, &.{ "I", "U", "WB" } },
        .{ .ILL, &.{ "I", "LL" } },
        .{ .IULL, &.{ "I", "U", "LL" } },
    };

    const FloatSuffixes = &[_]Tuple{
        .{ .F16, &.{"F16"} },
        .{ .F, &.{"F"} },
        .{ .L, &.{"L"} },
        .{ .W, &.{"W"} },
        .{ .F128, &.{"F128"} },
        .{ .Q, &.{"Q"} },
        .{ .BF16, &.{"BF16"} },
        .{ .F32, &.{"F32"} },
        .{ .F64, &.{"F64"} },
        .{ .F32x, &.{"F32x"} },
        .{ .F64x, &.{"F64x"} },
        .{ .D32, &.{"D32"} },
        .{ .D64, &.{"D64"} },
        .{ .D128, &.{"D128"} },
        .{ .D64x, &.{"D64x"} },

        .{ .I, &.{"I"} },
        .{ .IL, &.{ "I", "L" } },
        .{ .IF16, &.{ "I", "F16" } },
        .{ .IF, &.{ "I", "F" } },
        .{ .IW, &.{ "I", "W" } },
        .{ .IF128, &.{ "I", "F128" } },
        .{ .IQ, &.{ "I", "Q" } },
        .{ .IF32, &.{ "I", "F32" } },
        .{ .IF64, &.{ "I", "F64" } },
        .{ .IF32x, &.{ "I", "F32x" } },
        .{ .IF64x, &.{ "I", "F64x" } },
    };

    pub fn fromString(buf: []const u8, suffix_kind: enum { int, float }) ?Suffix {
        if (buf.len == 0) return .None;

        const suffixes = switch (suffix_kind) {
            .float => FloatSuffixes,
            .int => IntSuffixes,
        };
        var scratch: [4]u8 = undefined;
        top: for (suffixes) |candidate| {
            const tag = candidate[0];
            const parts = candidate[1];
            var len: usize = 0;
            for (parts) |part| len += part.len;
            if (len != buf.len) continue;

            for (parts) |part| {
                const lower = std.ascii.lowerString(&scratch, part);
                if (mem.indexOf(u8, buf, part) == null and mem.indexOf(u8, buf, lower) == null) continue :top;
            }
            return tag;
        }
        return null;
    }

    pub fn isImaginary(suffix: Suffix) bool {
        return switch (suffix) {
            .I, .IL, .IF, .IU, .IUL, .ILL, .IULL, .IWB, .IUWB, .IF128, .IQ, .IW, .IF16, .IF32, .IF64, .IF32x, .IF64x => true,
            .None, .L, .F16, .F, .U, .UL, .LL, .ULL, .WB, .UWB, .F128, .Q, .W, .F32, .F64, .F32x, .F64x, .D32, .D64, .D128, .D64x, .BF16 => false,
        };
    }

    pub fn isSignedInteger(suffix: Suffix) bool {
        return switch (suffix) {
            .None, .L, .LL, .I, .IL, .ILL, .WB, .IWB => true,
            .U, .UL, .ULL, .IU, .IUL, .IULL, .UWB, .IUWB => false,
            .F, .IF, .F16, .F128, .IF128, .Q, .IQ, .W, .IW, .IF16, .F32, .IF32, .F64, .IF64, .F32x, .IF32x, .F64x, .IF64x, .D32, .D64, .D128, .D64x, .BF16 => unreachable,
        };
    }

    pub fn signedness(suffix: Suffix) std.builtin.Signedness {
        return if (suffix.isSignedInteger()) .signed else .unsigned;
    }

    pub fn isBitInt(suffix: Suffix) bool {
        return switch (suffix) {
            .WB, .UWB, .IWB, .IUWB => true,
            else => false,
        };
    }

    pub fn isFloat80(suffix: Suffix) bool {
        return suffix == .W or suffix == .IW;
    }
};
