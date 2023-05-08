const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@max" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x: i32 = 10;
            var y: f32 = 0.68;
            try expect(@as(i32, 10) == @max(@as(i32, -3), x));
            try expect(@as(f32, 3.2) == @max(@as(f32, 3.2), y));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@max on vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var b: @Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
            var x = @max(a, b);
            try expect(mem.eql(i32, &@as([4]i32, x), &[4]i32{ 2147483647, 2147483647, 30, 40 }));

            var c: @Vector(4, f32) = [4]f32{ 0, 0.4, -2.4, 7.8 };
            var d: @Vector(4, f32) = [4]f32{ -0.23, 0.42, -0.64, 0.9 };
            var y = @max(c, d);
            try expect(mem.eql(f32, &@as([4]f32, y), &[4]f32{ 0, 0.42, -0.64, 7.8 }));

            var e: @Vector(2, f32) = [2]f32{ 0, std.math.qnan_f32 };
            var f: @Vector(2, f32) = [2]f32{ std.math.qnan_f32, 0 };
            var z = @max(e, f);
            try expect(mem.eql(f32, &@as([2]f32, z), &[2]f32{ 0, 0 }));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@min" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x: i32 = 10;
            var y: f32 = 0.68;
            try expect(@as(i32, -3) == @min(@as(i32, -3), x));
            try expect(@as(f32, 0.68) == @min(@as(f32, 3.2), y));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@min for vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            var b: @Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
            var x = @min(a, b);
            try expect(mem.eql(i32, &@as([4]i32, x), &[4]i32{ 1, -2, 3, 4 }));

            var c: @Vector(4, f32) = [4]f32{ 0, 0.4, -2.4, 7.8 };
            var d: @Vector(4, f32) = [4]f32{ -0.23, 0.42, -0.64, 0.9 };
            var y = @min(c, d);
            try expect(mem.eql(f32, &@as([4]f32, y), &[4]f32{ -0.23, 0.4, -2.4, 0.9 }));

            var e: @Vector(2, f32) = [2]f32{ 0, std.math.qnan_f32 };
            var f: @Vector(2, f32) = [2]f32{ std.math.qnan_f32, 0 };
            var z = @max(e, f);
            try expect(mem.eql(f32, &@as([2]f32, z), &[2]f32{ 0, 0 }));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@min/@max on lazy values" {
    const A = extern struct { u8_4: [4]u8 };
    const B = extern struct { u8_16: [16]u8 };
    const size = @max(@sizeOf(A), @sizeOf(B));
    try expect(size == @sizeOf(B));
}

test "@min/@max more than two arguments" {
    const x: u32 = 30;
    const y: u32 = 10;
    const z: u32 = 20;
    try expectEqual(@as(u32, 10), @min(x, y, z));
    try expectEqual(@as(u32, 30), @max(x, y, z));
}

test "@min/@max more than two vector arguments" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const x: @Vector(2, u32) = .{ 3, 2 };
    const y: @Vector(2, u32) = .{ 4, 1 };
    const z: @Vector(2, u32) = .{ 5, 0 };
    try expectEqual(@Vector(2, u32){ 3, 0 }, @min(x, y, z));
    try expectEqual(@Vector(2, u32){ 5, 2 }, @max(x, y, z));
}

test "@min/@max notices bounds" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: u16 = 20;
    const y = 30;
    var z: u32 = 100;
    const min = @min(x, y, z);
    const max = @max(x, y, z);
    try expectEqual(x, min);
    try expectEqual(u5, @TypeOf(min));
    try expectEqual(z, max);
    try expectEqual(u32, @TypeOf(max));
}

test "@min/@max notices vector bounds" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: @Vector(2, u16) = .{ 140, 40 };
    const y: @Vector(2, u64) = .{ 5, 100 };
    var z: @Vector(2, u32) = .{ 10, 300 };
    const min = @min(x, y, z);
    const max = @max(x, y, z);
    try expectEqual(@Vector(2, u32){ 5, 40 }, min);
    try expectEqual(@Vector(2, u7), @TypeOf(min));
    try expectEqual(@Vector(2, u32){ 140, 300 }, max);
    try expectEqual(@Vector(2, u32), @TypeOf(max));
}
