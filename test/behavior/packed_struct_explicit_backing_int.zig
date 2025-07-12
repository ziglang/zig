const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const builtin = @import("builtin");

const native_endian = builtin.cpu.arch.endian();

test "packed struct explicit backing integer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S1 = packed struct { a: u8, b: u8, c: u8 };

    const S2 = packed struct(i24) { d: u8, e: u8, f: u8 };

    const S3 = packed struct { x: S1, y: S2 };
    const S3Padded = packed struct(u64) { s3: S3, pad: u16 };

    try expect(48 == @bitSizeOf(S3));
    try expect(@sizeOf(u48) == @sizeOf(S3));

    try expect(3 == @offsetOf(S3, "y"));
    try expect(24 == @bitOffsetOf(S3, "y"));

    if (native_endian == .little) {
        const s3 = @as(S3Padded, @bitCast(@as(u64, 0xe952d5c71ff4))).s3;
        try expect(@as(u8, 0xf4) == s3.x.a);
        try expect(@as(u8, 0x1f) == s3.x.b);
        try expect(@as(u8, 0xc7) == s3.x.c);
        try expect(@as(u8, 0xd5) == s3.y.d);
        try expect(@as(u8, 0x52) == s3.y.e);
        try expect(@as(u8, 0xe9) == s3.y.f);
    }

    const S4 = packed struct { a: i32, b: i8 };
    const S5 = packed struct(u80) { a: i32, b: i8, c: S4 };
    const S6 = packed struct(i80) { a: i32, b: S4, c: i8 };

    const expectedBitSize = 80;
    const expectedByteSize = @sizeOf(u80);
    try expect(expectedBitSize == @bitSizeOf(S5));
    try expect(expectedByteSize == @sizeOf(S5));
    try expect(expectedBitSize == @bitSizeOf(S6));
    try expect(expectedByteSize == @sizeOf(S6));

    try expect(5 == @offsetOf(S5, "c"));
    try expect(40 == @bitOffsetOf(S5, "c"));
    try expect(9 == @offsetOf(S6, "c"));
    try expect(72 == @bitOffsetOf(S6, "c"));
}
