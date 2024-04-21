const std = @import("std");
const builtin = @import("builtin");
const minInt = std.math.minInt;
const maxInt = std.math.maxInt;
const expect = std.testing.expect;

test "wrapping add" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try testWrapAdd(i8, -3, 10, 7);
            try testWrapAdd(i8, -128, -128, 0);
            try testWrapAdd(i2, 1, 1, -2);
            try testWrapAdd(i64, maxInt(i64), 1, minInt(i64));
            try testWrapAdd(i128, maxInt(i128), -maxInt(i128), 0);
            try testWrapAdd(i128, minInt(i128), maxInt(i128), -1);
            try testWrapAdd(i8, 127, 127, -2);
            try testWrapAdd(u8, 3, 10, 13);
            try testWrapAdd(u8, 255, 255, 254);
            try testWrapAdd(u2, 3, 2, 1);
            try testWrapAdd(u3, 7, 1, 0);
            try testWrapAdd(u128, maxInt(u128), 1, minInt(u128));
        }

        fn testWrapAdd(comptime T: type, lhs: T, rhs: T, expected: T) !void {
            try expect((lhs +% rhs) == expected);

            var x = lhs;
            x +%= rhs;
            try expect(x == expected);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();

    try comptime S.testWrapAdd(comptime_int, 0, 0, 0);
    try comptime S.testWrapAdd(comptime_int, 3, 2, 5);
    try comptime S.testWrapAdd(comptime_int, 651075816498665588400716961808225370057, 468229432685078038144554201546849378455, 1119305249183743626545271163355074748512);
    try comptime S.testWrapAdd(comptime_int, 7, -593423721213448152027139550640105366508, -593423721213448152027139550640105366501);
}

test "wrapping subtraction" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try testWrapSub(i8, -3, 10, -13);
            try testWrapSub(i8, -128, -128, 0);
            try testWrapSub(i8, -1, 127, -128);
            try testWrapSub(i64, minInt(i64), 1, maxInt(i64));
            try testWrapSub(i128, maxInt(i128), -1, minInt(i128));
            try testWrapSub(i128, minInt(i128), -maxInt(i128), -1);
            try testWrapSub(u8, 10, 3, 7);
            try testWrapSub(u8, 0, 255, 1);
            try testWrapSub(u5, 0, 31, 1);
            try testWrapSub(u128, 0, maxInt(u128), 1);
        }

        fn testWrapSub(comptime T: type, lhs: T, rhs: T, expected: T) !void {
            try expect((lhs -% rhs) == expected);

            var x = lhs;
            x -%= rhs;
            try expect(x == expected);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();

    try comptime S.testWrapSub(comptime_int, 0, 0, 0);
    try comptime S.testWrapSub(comptime_int, 3, 2, 1);
    try comptime S.testWrapSub(comptime_int, 651075816498665588400716961808225370057, 468229432685078038144554201546849378455, 182846383813587550256162760261375991602);
    try comptime S.testWrapSub(comptime_int, 7, -593423721213448152027139550640105366508, 593423721213448152027139550640105366515);
}

test "wrapping multiplication" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    // TODO: once #9660 has been solved, remove this line
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try testWrapMul(i8, -3, 10, -30);
            try testWrapMul(i4, 2, 4, -8);
            try testWrapMul(i8, 2, 127, -2);
            try testWrapMul(i8, -128, -128, 0);
            try testWrapMul(i8, maxInt(i8), maxInt(i8), 1);
            try testWrapMul(i16, maxInt(i16), -1, minInt(i16) + 1);
            try testWrapMul(i128, maxInt(i128), -1, minInt(i128) + 1);
            try testWrapMul(i128, minInt(i128), -1, minInt(i128));
            try testWrapMul(u8, 10, 3, 30);
            try testWrapMul(u8, 2, 255, 254);
            try testWrapMul(u128, maxInt(u128), maxInt(u128), 1);
        }

        fn testWrapMul(comptime T: type, lhs: T, rhs: T, expected: T) !void {
            try expect((lhs *% rhs) == expected);

            var x = lhs;
            x *%= rhs;
            try expect(x == expected);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();

    try comptime S.testWrapMul(comptime_int, 0, 0, 0);
    try comptime S.testWrapMul(comptime_int, 3, 2, 6);
    try comptime S.testWrapMul(comptime_int, 651075816498665588400716961808225370057, 468229432685078038144554201546849378455, 304852860194144160265083087140337419215516305999637969803722975979232817921935);
    try comptime S.testWrapMul(comptime_int, 7, -593423721213448152027139550640105366508, -4153966048494137064189976854480737565556);
}
