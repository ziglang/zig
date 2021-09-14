const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expectEqual = std.testing.expectEqual;
const Vector = std.meta.Vector;
const minInt = std.math.minInt;
const maxInt = std.math.maxInt;

const Op = enum { add, sub, mul, shl };
fn testSaturatingOp(comptime op: Op, comptime T: type, test_data: [3]T) !void {
    const a = test_data[0];
    const b = test_data[1];
    const expected = test_data[2];
    const actual = switch (op) {
        .add => @addWithSaturation(a, b),
        .sub => @subWithSaturation(a, b),
        .mul => @mulWithSaturation(a, b),
        .shl => @shlWithSaturation(a, b),
    };
    try expectEqual(expected, actual);
}

test "@addWithSaturation" {
    const S = struct {
        fn doTheTest() !void {
            //                             .{a, b, expected a+b}
            try testSaturatingOp(.add, i8, .{ -3, 10, 7 });
            try testSaturatingOp(.add, i8, .{ -128, -128, -128 });
            try testSaturatingOp(.add, i2, .{ 1, 1, 1 });
            try testSaturatingOp(.add, i64, .{ maxInt(i64), 1, maxInt(i64) });
            try testSaturatingOp(.add, i128, .{ maxInt(i128), -maxInt(i128), 0 });
            try testSaturatingOp(.add, i128, .{ minInt(i128), maxInt(i128), -1 });
            try testSaturatingOp(.add, i8, .{ 127, 127, 127 });
            try testSaturatingOp(.add, u8, .{ 3, 10, 13 });
            try testSaturatingOp(.add, u8, .{ 255, 255, 255 });
            try testSaturatingOp(.add, u2, .{ 3, 2, 3 });
            try testSaturatingOp(.add, u3, .{ 7, 1, 7 });
            try testSaturatingOp(.add, u128, .{ maxInt(u128), 1, maxInt(u128) });

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 255, 255, 255 }, @addWithSaturation(
                u8x3{ 255, 254, 1 },
                u8x3{ 1, 2, 255 },
            ));
            const i8x3 = std.meta.Vector(3, i8);
            try expectEqual(i8x3{ 127, 127, 127 }, @addWithSaturation(
                i8x3{ 127, 126, 1 },
                i8x3{ 1, 2, 127 },
            ));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@subWithSaturation" {
    const S = struct {
        fn doTheTest() !void {
            //                             .{a, b, expected a-b}
            try testSaturatingOp(.sub, i8, .{ -3, 10, -13 });
            try testSaturatingOp(.sub, i8, .{ -128, -128, 0 });
            try testSaturatingOp(.sub, i8, .{ -1, 127, -128 });
            try testSaturatingOp(.sub, i64, .{ minInt(i64), 1, minInt(i64) });
            try testSaturatingOp(.sub, i128, .{ maxInt(i128), -1, maxInt(i128) });
            try testSaturatingOp(.sub, i128, .{ minInt(i128), -maxInt(i128), -1 });
            try testSaturatingOp(.sub, u8, .{ 10, 3, 7 });
            try testSaturatingOp(.sub, u8, .{ 0, 255, 0 });
            try testSaturatingOp(.sub, u5, .{ 0, 31, 0 });
            try testSaturatingOp(.sub, u128, .{ 0, maxInt(u128), 0 });

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 0, 0, 0 }, @subWithSaturation(
                u8x3{ 0, 0, 0 },
                u8x3{ 255, 255, 255 },
            ));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@mulWithSaturation" {
    // TODO: once #9660 has been solved, remove this line
    if (std.builtin.target.cpu.arch == .wasm32) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            //                             .{a, b, expected a*b}
            try testSaturatingOp(.mul, i8, .{ -3, 10, -30 });
            try testSaturatingOp(.mul, i4, .{ 2, 4, 7 });
            try testSaturatingOp(.mul, i8, .{ 2, 127, 127 });
            // TODO: uncomment these after #9643 has been solved - this should happen at 0.9.0/llvm-13 release
            // try testSaturatingOp(.mul, i8, .{ -128, -128, 127 });
            // try testSaturatingOp(.mul, i8, .{ maxInt(i8), maxInt(i8), maxInt(i8) });
            try testSaturatingOp(.mul, i16, .{ maxInt(i16), -1, minInt(i16) + 1 });
            try testSaturatingOp(.mul, i128, .{ maxInt(i128), -1, minInt(i128) + 1 });
            try testSaturatingOp(.mul, i128, .{ minInt(i128), -1, maxInt(i128) });
            try testSaturatingOp(.mul, u8, .{ 10, 3, 30 });
            try testSaturatingOp(.mul, u8, .{ 2, 255, 255 });
            try testSaturatingOp(.mul, u128, .{ maxInt(u128), maxInt(u128), maxInt(u128) });

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 255, 255, 255 }, @mulWithSaturation(
                u8x3{ 2, 2, 2 },
                u8x3{ 255, 255, 255 },
            ));
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@shlWithSaturation" {
    const S = struct {
        fn doTheTest() !void {
            //                             .{a, b, expected a<<b}
            try testSaturatingOp(.shl, i8, .{ 1, 2, 4 });
            try testSaturatingOp(.shl, i8, .{ 127, 1, 127 });
            try testSaturatingOp(.shl, i8, .{ -128, 1, -128 });
            // TODO: remove this check once #9668 is completed
            if (std.builtin.target.cpu.arch != .wasm32) {
                // skip testing ints > 64 bits on wasm due to miscompilation / wasmtime ci error
                try testSaturatingOp(.shl, i128, .{ maxInt(i128), 64, maxInt(i128) });
                try testSaturatingOp(.shl, u128, .{ maxInt(u128), 64, maxInt(u128) });
            }
            try testSaturatingOp(.shl, u8, .{ 1, 2, 4 });
            try testSaturatingOp(.shl, u8, .{ 255, 1, 255 });

            const u8x3 = std.meta.Vector(3, u8);
            try expectEqual(u8x3{ 255, 255, 255 }, @shlWithSaturation(
                u8x3{ 255, 255, 255 },
                u8x3{ 1, 1, 1 },
            ));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
