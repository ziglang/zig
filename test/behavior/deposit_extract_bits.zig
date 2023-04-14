const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@depositBits" {
    if (builtin.zig_backend != .stage2_llvm) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0;
            var b: u64 = 0xFFFF_FFFF_FFFF_FFFF;
            var c: u64 = 0x1234_5678_9012_3456;
            var d: u64 = 0x00F0_FF00_F00F_00FF;
            var e: u128 = @as(u128, d) << 64;

            try expect(@depositBits(b, a) == 0);
            try expect(@depositBits(a, b) == 0);

            try expect(@depositBits(b, c) == c);
            try expect(@depositBits(b, d) == d);

            try expect(@depositBits(c, d) == 0x0000_1200_3004_0056);
            try expect(@depositBits(c, e) == 0x0000_1200_3004_0056 << 64);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits" {
    if (builtin.zig_backend != .stage2_llvm) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0;
            var b: u64 = 0xFFFF_FFFF_FFFF_FFFF;
            var c: u64 = 0x1234_5678_9012_3456;
            var d: u64 = 0x00F0_FF00_F00F_00FF;
            var e: u128 = @as(u128, c) << 64;
            var f: u128 = @as(u128, d) << 64;

            try expect(@extractBits(b, a) == 0);
            try expect(@extractBits(a, b) == 0);

            try expect(@extractBits(c, b) == c);
            try expect(@extractBits(d, b) == d);

            try expect(@extractBits(c, d) == 0x0356_9256);
            try expect(@extractBits(e, f) == 0x0356_9256);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}
