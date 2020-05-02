const std = @import("std");
const expect = std.testing.expect;

test "@byteSwap integers" {
    const ByteSwapIntTest = struct {
        fn run() void {
            t(u0, 0, 0);
            t(u8, 0x12, 0x12);
            t(u16, 0x1234, 0x3412);
            t(u24, 0x123456, 0x563412);
            t(u32, 0x12345678, 0x78563412);
            t(u40, 0x123456789a, 0x9a78563412);
            t(i48, 0x123456789abc, @bitCast(i48, @as(u48, 0xbc9a78563412)));
            t(u56, 0x123456789abcde, 0xdebc9a78563412);
            t(u64, 0x123456789abcdef1, 0xf1debc9a78563412);
            t(u128, 0x123456789abcdef11121314151617181, 0x8171615141312111f1debc9a78563412);

            t(u0, @as(u0, 0), 0);
            t(i8, @as(i8, -50), -50);
            t(i16, @bitCast(i16, @as(u16, 0x1234)), @bitCast(i16, @as(u16, 0x3412)));
            t(i24, @bitCast(i24, @as(u24, 0x123456)), @bitCast(i24, @as(u24, 0x563412)));
            t(i32, @bitCast(i32, @as(u32, 0x12345678)), @bitCast(i32, @as(u32, 0x78563412)));
            t(u40, @bitCast(i40, @as(u40, 0x123456789a)), @as(u40, 0x9a78563412));
            t(i48, @bitCast(i48, @as(u48, 0x123456789abc)), @bitCast(i48, @as(u48, 0xbc9a78563412)));
            t(i56, @bitCast(i56, @as(u56, 0x123456789abcde)), @bitCast(i56, @as(u56, 0xdebc9a78563412)));
            t(i64, @bitCast(i64, @as(u64, 0x123456789abcdef1)), @bitCast(i64, @as(u64, 0xf1debc9a78563412)));
            t(
                i128,
                @bitCast(i128, @as(u128, 0x123456789abcdef11121314151617181)),
                @bitCast(i128, @as(u128, 0x8171615141312111f1debc9a78563412)),
            );
        }
        fn t(comptime I: type, input: I, expected_output: I) void {
            std.testing.expectEqual(expected_output, @byteSwap(I, input));
        }
    };
    comptime ByteSwapIntTest.run();
    ByteSwapIntTest.run();
}

test "@byteSwap vectors" {
    // https://github.com/ziglang/zig/issues/3563
    if (std.Target.current.os.tag == .dragonfly) return error.SkipZigTest;

    // https://github.com/ziglang/zig/issues/3317
    if (std.Target.current.cpu.arch == .mipsel or std.Target.current.cpu.arch == .mips) return error.SkipZigTest;

    const ByteSwapVectorTest = struct {
        fn run() void {
            t(u8, 2, [_]u8{ 0x12, 0x13 }, [_]u8{ 0x12, 0x13 });
            t(u16, 2, [_]u16{ 0x1234, 0x2345 }, [_]u16{ 0x3412, 0x4523 });
            t(u24, 2, [_]u24{ 0x123456, 0x234567 }, [_]u24{ 0x563412, 0x674523 });
        }

        fn t(
            comptime I: type,
            comptime n: comptime_int,
            input: std.meta.Vector(n, I),
            expected_vector: std.meta.Vector(n, I),
        ) void {
            const actual_output: [n]I = @byteSwap(I, input);
            const expected_output: [n]I = expected_vector;
            std.testing.expectEqual(expected_output, actual_output);
        }
    };
    comptime ByteSwapVectorTest.run();
    ByteSwapVectorTest.run();
}
