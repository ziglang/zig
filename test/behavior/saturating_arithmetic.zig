const std = @import("std");
const builtin = @import("builtin");
const minInt = std.math.minInt;
const maxInt = std.math.maxInt;
const expect = std.testing.expect;

test "saturating add" {
    const S = struct {
        fn doTheTest() !void {
            try testSatAdd(i8, -3, 10, 7);
            try testSatAdd(i8, -128, -128, -128);
            try testSatAdd(i2, 1, 1, 1);
            try testSatAdd(i64, maxInt(i64), 1, maxInt(i64));
            try testSatAdd(i128, maxInt(i128), -maxInt(i128), 0);
            try testSatAdd(i128, minInt(i128), maxInt(i128), -1);
            try testSatAdd(i8, 127, 127, 127);
            try testSatAdd(u8, 3, 10, 13);
            try testSatAdd(u8, 255, 255, 255);
            try testSatAdd(u2, 3, 2, 3);
            try testSatAdd(u3, 7, 1, 7);
            try testSatAdd(u128, maxInt(u128), 1, maxInt(u128));
        }

        fn testSatAdd(comptime T: type, lhs: T, rhs: T, expected: T) !void {
            try expect((lhs +| rhs) == expected);

            var x = lhs;
            x +|= rhs;
            try expect(x == expected);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "saturating subtraction" {
    const S = struct {
        fn doTheTest() !void {
            try testSatSub(i8, -3, 10, -13);
            try testSatSub(i8, -128, -128, 0);
            try testSatSub(i8, -1, 127, -128);
            try testSatSub(i64, minInt(i64), 1, minInt(i64));
            try testSatSub(i128, maxInt(i128), -1, maxInt(i128));
            try testSatSub(i128, minInt(i128), -maxInt(i128), -1);
            try testSatSub(u8, 10, 3, 7);
            try testSatSub(u8, 0, 255, 0);
            try testSatSub(u5, 0, 31, 0);
            try testSatSub(u128, 0, maxInt(u128), 0);
        }

        fn testSatSub(comptime T: type, lhs: T, rhs: T, expected: T) !void {
            try expect((lhs -| rhs) == expected);

            var x = lhs;
            x -|= rhs;
            try expect(x == expected);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "saturating multiplication" {
    // TODO: once #9660 has been solved, remove this line
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try testSatMul(i8, -3, 10, -30);
            try testSatMul(i4, 2, 4, 7);
            try testSatMul(i8, 2, 127, 127);
            try testSatMul(i8, -128, -128, 127);
            try testSatMul(i8, maxInt(i8), maxInt(i8), maxInt(i8));
            try testSatMul(i16, maxInt(i16), -1, minInt(i16) + 1);
            try testSatMul(i128, maxInt(i128), -1, minInt(i128) + 1);
            try testSatMul(i128, minInt(i128), -1, maxInt(i128));
            try testSatMul(u8, 10, 3, 30);
            try testSatMul(u8, 2, 255, 255);
            try testSatMul(u128, maxInt(u128), maxInt(u128), maxInt(u128));
        }

        fn testSatMul(comptime T: type, lhs: T, rhs: T, expected: T) !void {
            try expect((lhs *| rhs) == expected);

            var x = lhs;
            x *|= rhs;
            try expect(x == expected);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "saturating shift-left" {
    const S = struct {
        fn doTheTest() !void {
            try testSatShl(i8, 1, 2, 4);
            try testSatShl(i8, 127, 1, 127);
            try testSatShl(i8, -128, 1, -128);
            // TODO: remove this check once #9668 is completed
            if (builtin.cpu.arch != .wasm32) {
                // skip testing ints > 64 bits on wasm due to miscompilation / wasmtime ci error
                try testSatShl(i128, maxInt(i128), 64, maxInt(i128));
                try testSatShl(u128, maxInt(u128), 64, maxInt(u128));
            }
            try testSatShl(u8, 1, 2, 4);
            try testSatShl(u8, 255, 1, 255);
        }
        fn testSatShl(comptime T: type, lhs: T, rhs: T, expected: T) !void {
            try expect((lhs <<| rhs) == expected);

            var x = lhs;
            x <<|= rhs;
            try expect(x == expected);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
