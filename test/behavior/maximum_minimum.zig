const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@max" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var x: i32 = 10;
            var y: f32 = 0.68;
            try expect(@as(i32, 10) == @max(@as(i32, -3), x));
            try expect(@as(f32, 3.2) == @max(@as(f32, 3.2), y));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@max on vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}

test "@min" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var x: i32 = 10;
            var y: f32 = 0.68;
            try expect(@as(i32, -3) == @min(@as(i32, -3), x));
            try expect(@as(f32, 0.68) == @min(@as(f32, 3.2), y));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@min for vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1)) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}

test "@min/max for floats" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(comptime T: type) !void {
            var x: T = -3.14;
            var y: T = 5.27;
            try expectEqual(x, @min(x, y));
            try expectEqual(x, @min(y, x));
            try expectEqual(y, @max(x, y));
            try expectEqual(y, @max(y, x));
        }
    };

    inline for (.{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        try S.doTheTest(T);
        try comptime S.doTheTest(T);
    }
    try comptime S.doTheTest(comptime_float);
}

test "@min/@max on lazy values" {
    const A = extern struct { u8_4: [4]u8 };
    const B = extern struct { u8_16: [16]u8 };
    const size = @max(@sizeOf(A), @sizeOf(B));
    try expect(size == @sizeOf(B));
}

test "@min/@max more than two arguments" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const x: u32 = 30;
    const y: u32 = 10;
    const z: u32 = 20;
    try expectEqual(@as(u32, 10), @min(x, y, z));
    try expectEqual(@as(u32, 30), @max(x, y, z));
}

test "@min/@max more than two vector arguments" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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

test "@min/@max on comptime_int" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO

    const min = @min(1, 2, -2, -1);
    const max = @max(1, 2, -2, -1);

    try expectEqual(comptime_int, @TypeOf(min));
    try expectEqual(comptime_int, @TypeOf(max));
    try expectEqual(-2, min);
    try expectEqual(2, max);
}

test "@min/@max notices bounds from types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u16 = 123;
    var y: u32 = 456;
    var z: u8 = 10;

    const min = @min(x, y, z);
    const max = @max(x, y, z);

    comptime assert(@TypeOf(min) == u8);
    comptime assert(@TypeOf(max) == u32);

    try expectEqual(z, min);
    try expectEqual(y, max);
}

test "@min/@max notices bounds from vector types" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: @Vector(2, u16) = .{ 30, 67 };
    var y: @Vector(2, u32) = .{ 20, 500 };
    var z: @Vector(2, u8) = .{ 60, 15 };

    const min = @min(x, y, z);
    const max = @max(x, y, z);

    comptime assert(@TypeOf(min) == @Vector(2, u8));
    comptime assert(@TypeOf(max) == @Vector(2, u32));

    try expectEqual(@Vector(2, u8){ 20, 15 }, min);
    try expectEqual(@Vector(2, u32){ 60, 500 }, max);
}

test "@min/@max notices bounds from types when comptime-known value is undef" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u32 = 1_000_000;
    const y: u16 = undefined;
    // y is comptime-known, but is undef, so bounds cannot be refined using its value

    const min = @min(x, y);
    const max = @max(x, y);

    comptime assert(@TypeOf(min) == u16);
    comptime assert(@TypeOf(max) == u32);

    // Cannot assert values as one was undefined
}

test "@min/@max notices bounds from vector types when element of comptime-known vector is undef" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: @Vector(2, u32) = .{ 1_000_000, 12345 };
    const y: @Vector(2, u16) = .{ 10, undefined };
    // y is comptime-known, but an element is undef, so bounds cannot be refined using its value

    const min = @min(x, y);
    const max = @max(x, y);

    comptime assert(@TypeOf(min) == @Vector(2, u16));
    comptime assert(@TypeOf(max) == @Vector(2, u32));

    try expectEqual(@as(u16, 10), min[0]);
    try expectEqual(@as(u32, 1_000_000), max[0]);
    // Cannot assert values at index 1 as one was undefined
}

test "@min/@max of signed and unsigned runtime integers" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: i32 = -1;
    var y: u31 = 1;

    const min = @min(x, y);
    const max = @max(x, y);

    comptime assert(@TypeOf(min) == i32);
    comptime assert(@TypeOf(max) == u31);

    try expectEqual(x, @min(x, y));
    try expectEqual(y, @max(x, y));
}
