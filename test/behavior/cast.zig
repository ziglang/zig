const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const maxInt = std.math.maxInt;
const native_endian = builtin.target.cpu.arch.endian();

test "int to ptr cast" {
    const x = @as(usize, 13);
    const y = @intToPtr(*u8, x);
    const z = @ptrToInt(y);
    try expect(z == 13);
}

test "integer literal to pointer cast" {
    const vga_mem = @intToPtr(*u16, 0xB8000);
    try expect(@ptrToInt(vga_mem) == 0xB8000);
}

test "peer type resolution: ?T and T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(peerTypeTAndOptionalT(true, false).? == 0);
    try expect(peerTypeTAndOptionalT(false, false).? == 3);
    comptime {
        try expect(peerTypeTAndOptionalT(true, false).? == 0);
        try expect(peerTypeTAndOptionalT(false, false).? == 3);
    }
}
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
    if (c) {
        return if (b) null else @as(usize, 0);
    }

    return @as(usize, 3);
}

test "resolve undefined with integer" {
    try testResolveUndefWithInt(true, 1234);
    comptime try testResolveUndefWithInt(true, 1234);
}
fn testResolveUndefWithInt(b: bool, x: i32) !void {
    const value = if (b) x else undefined;
    if (b) {
        try expect(value == x);
    }
}

test "@intCast to comptime_int" {
    try expect(@intCast(comptime_int, 0) == 0);
}

test "implicit cast comptime numbers to any type when the value fits" {
    const a: u64 = 255;
    var b: u8 = a;
    try expect(b == 255);
}

test "implicit cast comptime_int to comptime_float" {
    comptime try expect(@as(comptime_float, 10) == @as(f32, 10));
    try expect(2 == 2.0);
}

test "comptime_int @intToFloat" {
    {
        const result = @intToFloat(f16, 1234);
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @intToFloat(f32, 1234);
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
    {
        const result = @intToFloat(f64, 1234);
        try expect(@TypeOf(result) == f64);
        try expect(result == 1234.0);
    }

    {
        const result = @intToFloat(f128, 1234);
        try expect(@TypeOf(result) == f128);
        try expect(result == 1234.0);
    }
    // big comptime_int (> 64 bits) to f128 conversion
    {
        const result = @intToFloat(f128, 0x1_0000_0000_0000_0000);
        try expect(@TypeOf(result) == f128);
        try expect(result == 0x1_0000_0000_0000_0000.0);
    }
}

test "@intToFloat" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            try testIntToFloat(-2);
        }

        fn testIntToFloat(k: i32) !void {
            const f = @intToFloat(f32, k);
            const i = @floatToInt(i32, f);
            try expect(i == k);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@intToFloat(f80)" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(comptime Int: type) !void {
            try testIntToFloat(Int, -2);
        }

        fn testIntToFloat(comptime Int: type, k: Int) !void {
            const f = @intToFloat(f80, k);
            const i = @floatToInt(Int, f);
            try expect(i == k);
        }
    };
    try S.doTheTest(i31);
    try S.doTheTest(i32);
    try S.doTheTest(i45);
    try S.doTheTest(i64);
    try S.doTheTest(i80);
    try S.doTheTest(i128);
    // try S.doTheTest(i256); // TODO missing compiler_rt symbols
    comptime try S.doTheTest(i31);
    comptime try S.doTheTest(i32);
    comptime try S.doTheTest(i45);
    comptime try S.doTheTest(i64);
    comptime try S.doTheTest(i80);
    comptime try S.doTheTest(i128);
    comptime try S.doTheTest(i256);
}

test "@floatToInt" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try testFloatToInts();
    comptime try testFloatToInts();
}

fn testFloatToInts() !void {
    const x = @as(i32, 1e4);
    try expect(x == 10000);
    const y = @floatToInt(i32, @as(f32, 1e4));
    try expect(y == 10000);
    try expectFloatToInt(f32, 255.1, u8, 255);
    try expectFloatToInt(f32, 127.2, i8, 127);
    try expectFloatToInt(f32, -128.2, i8, -128);
}

fn expectFloatToInt(comptime F: type, f: F, comptime I: type, i: I) !void {
    try expect(@floatToInt(I, f) == i);
}

test "implicitly cast indirect pointer to maybe-indirect pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        const Self = @This();
        x: u8,
        fn constConst(p: *const *const Self) u8 {
            return p.*.x;
        }
        fn maybeConstConst(p: ?*const *const Self) u8 {
            return p.?.*.x;
        }
        fn constConstConst(p: *const *const *const Self) u8 {
            return p.*.*.x;
        }
        fn maybeConstConstConst(p: ?*const *const *const Self) u8 {
            return p.?.*.*.x;
        }
    };
    const s = S{ .x = 42 };
    const p = &s;
    const q = &p;
    const r = &q;
    try expect(42 == S.constConst(q));
    try expect(42 == S.maybeConstConst(q));
    try expect(42 == S.constConstConst(r));
    try expect(42 == S.maybeConstConstConst(r));
}

test "@intCast comptime_int" {
    const result = @intCast(i32, 1234);
    try expect(@TypeOf(result) == i32);
    try expect(result == 1234);
}

test "@floatCast comptime_int and comptime_float" {
    {
        const result = @floatCast(f16, 1234);
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @floatCast(f16, 1234.0);
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234);
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
    {
        const result = @floatCast(f32, 1234.0);
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
}

test "coerce undefined to optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try expect(MakeType(void).getNull() == null);
    try expect(MakeType(void).getNonNull() != null);
}

fn MakeType(comptime T: type) type {
    return struct {
        fn getNull() ?T {
            return null;
        }

        fn getNonNull() ?T {
            return @as(T, undefined);
        }
    };
}

test "implicit cast from *[N]T to [*c]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var x: [4]u16 = [4]u16{ 0, 1, 2, 3 };
    var y: [*c]u16 = &x;

    try expect(std.mem.eql(u16, x[0..4], y[0..4]));
    x[0] = 8;
    y[3] = 6;
    try expect(std.mem.eql(u16, x[0..4], y[0..4]));
}

test "*usize to *void" {
    var i = @as(usize, 0);
    var v = @ptrCast(*void, &i);
    v.* = {};
}

test "@intToEnum passed a comptime_int to an enum with one item" {
    const E = enum { A };
    const x = @intToEnum(E, 0);
    try expect(x == E.A);
}

test "@intCast to u0 and use the result" {
    const S = struct {
        fn doTheTest(zero: u1, one: u1, bigzero: i32) !void {
            try expect((one << @intCast(u0, bigzero)) == 1);
            try expect((zero << @intCast(u0, bigzero)) == 0);
        }
    };
    try S.doTheTest(0, 1, 0);
    comptime try S.doTheTest(0, 1, 0);
}

test "peer result null and comptime_int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn blah(n: i32) ?i32 {
            if (n == 0) {
                return null;
            } else if (n < 0) {
                return -1;
            } else {
                return 1;
            }
        }
    };

    try expect(S.blah(0) == null);
    comptime try expect(S.blah(0) == null);
    try expect(S.blah(10).? == 1);
    comptime try expect(S.blah(10).? == 1);
    try expect(S.blah(-10).? == -1);
    comptime try expect(S.blah(-10).? == -1);
}

test "*const ?[*]const T to [*c]const [*c]const T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var array = [_]u8{ 'o', 'k' };
    const opt_array_ptr: ?[*]const u8 = &array;
    const a: *const ?[*]const u8 = &opt_array_ptr;
    const b: [*c]const [*c]const u8 = a;
    try expect(b.*[0] == 'o');
    try expect(b[0][1] == 'k');
}

test "array coersion to undefined at runtime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    @setRuntimeSafety(true);

    if (builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
        return error.SkipZigTest;
    }

    var array = [4]u8{ 3, 4, 5, 6 };
    var undefined_val = [4]u8{ 0xAA, 0xAA, 0xAA, 0xAA };

    try expect(std.mem.eql(u8, &array, &array));
    array = undefined;
    try expect(std.mem.eql(u8, &array, &undefined_val));
}

test "implicitly cast from int to anyerror!?T" {
    implicitIntLitToOptional();
    comptime implicitIntLitToOptional();
}
fn implicitIntLitToOptional() void {
    const f: ?i32 = 1;
    _ = f;
    const g: anyerror!?i32 = 1;
    _ = g catch {};
}

test "return u8 coercing into ?u32 return type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try expect(foo(123).? == 123);
        }
        fn foo(arg: u8) ?u32 {
            return arg;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast from ?[*]T to ??[*]T" {
    const a: ??[*]u8 = @as(?[*]u8, null);
    try expect(a != null and a.? == null);
}

test "peer type unsigned int to signed" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var w: u31 = 5;
    var x: u8 = 7;
    var y: i32 = -5;
    var a = w + y + x;
    comptime try expect(@TypeOf(a) == i32);
    try expect(a == 7);
}

test "expected [*c]const u8, found [*:0]const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var a: [*:0]const u8 = "hello";
    var b: [*c]const u8 = a;
    var c: [*:0]const u8 = b;
    try expect(std.mem.eql(u8, c[0..5], "hello"));
}

test "explicit cast from integer to error type" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try testCastIntToErr(error.ItBroke);
    comptime try testCastIntToErr(error.ItBroke);
}
fn testCastIntToErr(err: anyerror) !void {
    const x = @errorToInt(err);
    const y = @intToError(x);
    try expect(error.ItBroke == y);
}

test "peer resolve array and const slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try testPeerResolveArrayConstSlice(true);
    comptime try testPeerResolveArrayConstSlice(true);
}
fn testPeerResolveArrayConstSlice(b: bool) !void {
    const value1 = if (b) "aoeu" else @as([]const u8, "zz");
    const value2 = if (b) @as([]const u8, "zz") else "aoeu";
    try expect(mem.eql(u8, value1, "aoeu"));
    try expect(mem.eql(u8, value2, "zz"));
}

test "implicitly cast from T to anyerror!?T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try castToOptionalTypeError(1);
    comptime try castToOptionalTypeError(1);
}

const A = struct {
    a: i32,
};
fn castToOptionalTypeError(z: i32) !void {
    const x = @as(i32, 1);
    const y: anyerror!?i32 = x;
    try expect((try y).? == 1);

    const f = z;
    const g: anyerror!?i32 = f;
    _ = try g;

    const a = A{ .a = z };
    const b: anyerror!?A = a;
    try expect((b catch unreachable).?.a == 1);
}

test "implicitly cast from [0]T to anyerror![]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    try testCastZeroArrayToErrSliceMut();
    comptime try testCastZeroArrayToErrSliceMut();
}

fn testCastZeroArrayToErrSliceMut() !void {
    try expect((gimmeErrOrSlice() catch unreachable).len == 0);
}

fn gimmeErrOrSlice() anyerror![]u8 {
    return &[_]u8{};
}

test "peer type resolution: [0]u8, []const u8, and anyerror![]u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() anyerror!void {
            {
                var data = "hi".*;
                const slice = data[0..];
                try expect((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
                try expect((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
            }
            {
                var data: [2]u8 = "hi".*;
                const slice = data[0..];
                try expect((try peerTypeEmptyArrayAndSliceAndError(true, slice)).len == 0);
                try expect((try peerTypeEmptyArrayAndSliceAndError(false, slice)).len == 1);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) anyerror![]u8 {
    if (a) {
        return &[_]u8{};
    }

    return slice[0..1];
}

test "implicit cast from *const [N]T to []const T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testCastConstArrayRefToConstSlice();
    comptime try testCastConstArrayRefToConstSlice();
}

fn testCastConstArrayRefToConstSlice() !void {
    {
        const blah = "aoeu".*;
        const const_array_ref = &blah;
        try expect(@TypeOf(const_array_ref) == *const [4:0]u8);
        const slice: []const u8 = const_array_ref;
        try expect(mem.eql(u8, slice, "aoeu"));
    }
    {
        const blah: [4]u8 = "aoeu".*;
        const const_array_ref = &blah;
        try expect(@TypeOf(const_array_ref) == *const [4]u8);
        const slice: []const u8 = const_array_ref;
        try expect(mem.eql(u8, slice, "aoeu"));
    }
}

test "peer type resolution: error and [N]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    comptime try expect(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    try expect(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
    comptime try expect(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
}

fn testPeerErrorAndArray(x: u8) anyerror![]const u8 {
    return switch (x) {
        0x00 => "OK",
        else => error.BadValue,
    };
}
fn testPeerErrorAndArray2(x: u8) anyerror![]const u8 {
    return switch (x) {
        0x00 => "OK",
        0x01 => "OKK",
        else => error.BadValue,
    };
}

test "single-item pointer of array to slice to unknown length pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try testCastPtrOfArrayToSliceAndPtr();
    comptime try testCastPtrOfArrayToSliceAndPtr();
}

fn testCastPtrOfArrayToSliceAndPtr() !void {
    {
        var array = "aoeu".*;
        const x: [*]u8 = &array;
        x[0] += 1;
        try expect(mem.eql(u8, array[0..], "boeu"));
        const y: []u8 = &array;
        y[0] += 1;
        try expect(mem.eql(u8, array[0..], "coeu"));
    }
    {
        var array: [4]u8 = "aoeu".*;
        const x: [*]u8 = &array;
        x[0] += 1;
        try expect(mem.eql(u8, array[0..], "boeu"));
        const y: []u8 = &array;
        y[0] += 1;
        try expect(mem.eql(u8, array[0..], "coeu"));
    }
}

test "cast *[1][*]const u8 to [*]const ?[*]const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const window_name = [1][*]const u8{"window name"};
    const x: [*]const ?[*]const u8 = &window_name;
    try expect(mem.eql(u8, std.mem.sliceTo(@ptrCast([*:0]const u8, x[0].?), 0), "window name"));
}

test "vector casts" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            // Upcast (implicit, equivalent to @intCast)
            var up0: @Vector(2, u8) = [_]u8{ 0x55, 0xaa };
            var up1 = @as(@Vector(2, u16), up0);
            var up2 = @as(@Vector(2, u32), up0);
            var up3 = @as(@Vector(2, u64), up0);
            // Downcast (safety-checked)
            var down0 = up3;
            var down1 = @intCast(@Vector(2, u32), down0);
            var down2 = @intCast(@Vector(2, u16), down0);
            var down3 = @intCast(@Vector(2, u8), down0);

            try expect(mem.eql(u16, &@as([2]u16, up1), &[2]u16{ 0x55, 0xaa }));
            try expect(mem.eql(u32, &@as([2]u32, up2), &[2]u32{ 0x55, 0xaa }));
            try expect(mem.eql(u64, &@as([2]u64, up3), &[2]u64{ 0x55, 0xaa }));

            try expect(mem.eql(u32, &@as([2]u32, down1), &[2]u32{ 0x55, 0xaa }));
            try expect(mem.eql(u16, &@as([2]u16, down2), &[2]u16{ 0x55, 0xaa }));
            try expect(mem.eql(u8, &@as([2]u8, down3), &[2]u8{ 0x55, 0xaa }));
        }

        fn doTheTestFloat() !void {
            var vec = @splat(2, @as(f32, 1234.0));
            var wider: @Vector(2, f64) = vec;
            try expect(wider[0] == 1234.0);
            try expect(wider[1] == 1234.0);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
    try S.doTheTestFloat();
    comptime try S.doTheTestFloat();
}

test "@floatCast cast down" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    {
        var double: f64 = 0.001534;
        var single = @floatCast(f32, double);
        try expect(single == 0.001534);
    }
    {
        const double: f64 = 0.001534;
        const single = @floatCast(f32, double);
        try expect(single == 0.001534);
    }
}

test "peer type resolution: unreachable, error set, unreachable" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Error = error{
        FileDescriptorAlreadyPresentInSet,
        OperationCausesCircularLoop,
        FileDescriptorNotRegistered,
        SystemResources,
        UserResourceLimitReached,
        FileDescriptorIncompatibleWithEpoll,
        Unexpected,
    };
    var err = Error.SystemResources;
    const transformed_err = switch (err) {
        error.FileDescriptorAlreadyPresentInSet => unreachable,
        error.OperationCausesCircularLoop => unreachable,
        error.FileDescriptorNotRegistered => unreachable,
        error.SystemResources => error.SystemResources,
        error.UserResourceLimitReached => error.UserResourceLimitReached,
        error.FileDescriptorIncompatibleWithEpoll => unreachable,
        error.Unexpected => unreachable,
    };
    try expect(transformed_err == error.SystemResources);
}

test "peer cast: error set any anyerror" {
    const a: error{ One, Two } = undefined;
    const b: anyerror = undefined;
    try expect(@TypeOf(a, b) == anyerror);
    try expect(@TypeOf(b, a) == anyerror);
}

test "peer type resolution: error set supersets" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const a: error{ One, Two } = undefined;
    const b: error{One} = undefined;

    // A superset of B
    {
        const ty = @TypeOf(a, b);
        const error_set_info = @typeInfo(ty);
        try expect(error_set_info == .ErrorSet);
        try expect(error_set_info.ErrorSet.?.len == 2);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
    }

    // B superset of A
    {
        const ty = @TypeOf(b, a);
        const error_set_info = @typeInfo(ty);
        try expect(error_set_info == .ErrorSet);
        try expect(error_set_info.ErrorSet.?.len == 2);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
    }
}

test "peer type resolution: disjoint error sets" {
    if (builtin.zig_backend == .stage1) {
        // stage1 gets the order of the error names wrong after merging the sets.
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const a: error{ One, Two } = undefined;
    const b: error{Three} = undefined;

    {
        const ty = @TypeOf(a, b);
        const error_set_info = @typeInfo(ty);
        try expect(error_set_info == .ErrorSet);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Three"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Two"));
    }

    {
        const ty = @TypeOf(b, a);
        const error_set_info = @typeInfo(ty);
        try expect(error_set_info == .ErrorSet);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Three"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Two"));
    }
}

test "peer type resolution: error union and error set" {
    if (builtin.zig_backend == .stage1) {
        // stage1 gets the order of the error names wrong after merging the sets.
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const a: error{Three} = undefined;
    const b: error{ One, Two }!u32 = undefined;

    {
        const ty = @TypeOf(a, b);
        const info = @typeInfo(ty);
        try expect(info == .ErrorUnion);

        const error_set_info = @typeInfo(info.ErrorUnion.error_set);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Three"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Two"));
    }

    {
        const ty = @TypeOf(b, a);
        const info = @typeInfo(ty);
        try expect(info == .ErrorUnion);

        const error_set_info = @typeInfo(info.ErrorUnion.error_set);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Three"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Two"));
    }
}

test "peer type resolution: error union after non-error" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const a: u32 = undefined;
    const b: error{ One, Two }!u32 = undefined;

    {
        const ty = @TypeOf(a, b);
        const info = @typeInfo(ty);
        try expect(info == .ErrorUnion);
        try expect(info.ErrorUnion.payload == u32);

        const error_set_info = @typeInfo(info.ErrorUnion.error_set);
        try expect(error_set_info.ErrorSet.?.len == 2);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
    }

    {
        const ty = @TypeOf(b, a);
        const info = @typeInfo(ty);
        try expect(info == .ErrorUnion);
        try expect(info.ErrorUnion.payload == u32);

        const error_set_info = @typeInfo(info.ErrorUnion.error_set);
        try expect(error_set_info.ErrorSet.?.len == 2);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
    }
}

test "peer cast *[0]T to E![]const T" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    var buffer: [5]u8 = "abcde".*;
    var buf: anyerror![]const u8 = buffer[0..];
    var b = false;
    var y = if (b) &[0]u8{} else buf;
    var z = if (!b) buf else &[0]u8{};
    try expect(mem.eql(u8, "abcde", y catch unreachable));
    try expect(mem.eql(u8, "abcde", z catch unreachable));
}

test "peer cast *[0]T to []const T" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    var buffer: [5]u8 = "abcde".*;
    var buf: []const u8 = buffer[0..];
    var b = false;
    var y = if (b) &[0]u8{} else buf;
    try expect(mem.eql(u8, "abcde", y));
}

test "peer cast *[N]T to [*]T" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    var array = [4:99]i32{ 1, 2, 3, 4 };
    var dest: [*]i32 = undefined;
    try expect(@TypeOf(&array, dest) == [*]i32);
    try expect(@TypeOf(dest, &array) == [*]i32);
}

test "peer resolution of string literals" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        const E = enum { a, b, c, d };

        fn doTheTest(e: E) !void {
            const cmd = switch (e) {
                .a => "one",
                .b => "two",
                .c => "three",
                .d => "four",
            };
            try expect(mem.eql(u8, cmd, "two"));
        }
    };
    try S.doTheTest(.b);
    comptime try S.doTheTest(.b);
}

test "peer cast [:x]T to []T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            var slice: [:0]i32 = &array;
            var dest: []i32 = slice;
            try expect(mem.eql(i32, dest, &[_]i32{ 1, 2, 3, 4 }));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer cast [N:x]T to [N]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            var dest: [4]i32 = array;
            try expect(mem.eql(i32, &dest, &[_]i32{ 1, 2, 3, 4 }));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer cast *[N:x]T to *[N]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            var dest: *[4]i32 = &array;
            try expect(mem.eql(i32, dest, &[_]i32{ 1, 2, 3, 4 }));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer cast [*:x]T to [*]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [4:99]i32{ 1, 2, 3, 4 };
            var dest: [*]i32 = &array;
            try expect(dest[0] == 1);
            try expect(dest[1] == 2);
            try expect(dest[2] == 3);
            try expect(dest[3] == 4);
            try expect(dest[4] == 99);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer cast [:x]T to [*:x]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            var slice: [:0]i32 = &array;
            var dest: [*:0]i32 = slice;
            try expect(dest[0] == 1);
            try expect(dest[1] == 2);
            try expect(dest[2] == 3);
            try expect(dest[3] == 4);
            try expect(dest[4] == 0);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer type resolution implicit cast to return type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            for ("hello") |c| _ = f(c);
        }
        fn f(c: u8) []const u8 {
            return switch (c) {
                'h', 'e' => &[_]u8{c}, // should cast to slice
                'l', ' ' => &[_]u8{ c, '.' }, // should cast to slice
                else => ([_]u8{c})[0..], // is a slice
            };
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer type resolution implicit cast to variable type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x: []const u8 = undefined;
            for ("hello") |c| x = switch (c) {
                'h', 'e' => &[_]u8{c}, // should cast to slice
                'l', ' ' => &[_]u8{ c, '.' }, // should cast to slice
                else => ([_]u8{c})[0..], // is a slice
            };
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "variable initialization uses result locations properly with regards to the type" {
    var b = true;
    const x: i32 = if (b) 1 else 2;
    try expect(x == 1);
}

test "cast between C pointer with different but compatible types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(arg: [*]c_ushort) u16 {
            return arg[0];
        }
        fn doTheTest() !void {
            var x = [_]u16{ 4, 2, 1, 3 };
            try expect(foo(@ptrCast([*]u16, &x)) == 4);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer type resolve string lit with sentinel-terminated mutable slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    var array: [4:0]u8 = undefined;
    array[4] = 0; // TODO remove this when #4372 is solved
    var slice: [:0]u8 = array[0..4 :0];
    comptime try expect(@TypeOf(slice, "hi") == [:0]const u8);
    comptime try expect(@TypeOf("hi", slice) == [:0]const u8);
}

test "peer type resolve array pointers, one of them const" {
    var array1: [4]u8 = undefined;
    const array2: [5]u8 = undefined;
    comptime try expect(@TypeOf(&array1, &array2) == []const u8);
    comptime try expect(@TypeOf(&array2, &array1) == []const u8);
}

test "peer type resolve array pointer and unknown pointer" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const const_array: [4]u8 = undefined;
    var array: [4]u8 = undefined;
    var const_ptr: [*]const u8 = undefined;
    var ptr: [*]u8 = undefined;

    comptime try expect(@TypeOf(&array, ptr) == [*]u8);
    comptime try expect(@TypeOf(ptr, &array) == [*]u8);

    comptime try expect(@TypeOf(&const_array, ptr) == [*]const u8);
    comptime try expect(@TypeOf(ptr, &const_array) == [*]const u8);

    comptime try expect(@TypeOf(&array, const_ptr) == [*]const u8);
    comptime try expect(@TypeOf(const_ptr, &array) == [*]const u8);

    comptime try expect(@TypeOf(&const_array, const_ptr) == [*]const u8);
    comptime try expect(@TypeOf(const_ptr, &const_array) == [*]const u8);
}

test "comptime float casts" {
    const a = @intToFloat(comptime_float, 1);
    try expect(a == 1);
    try expect(@TypeOf(a) == comptime_float);
    const b = @floatToInt(comptime_int, 2);
    try expect(b == 2);
    try expect(@TypeOf(b) == comptime_int);

    try expectFloatToInt(comptime_int, 1234, i16, 1234);
    try expectFloatToInt(comptime_float, 12.3, comptime_int, 12);
}

test "pointer reinterpret const float to int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    // The hex representation is 0x3fe3333333333303.
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(*const i32, float_ptr);
    const int_val = int_ptr.*;
    if (native_endian == .Little)
        try expect(int_val == 0x33333303)
    else
        try expect(int_val == 0x3fe33333);
}

test "implicit cast from [*]T to ?*anyopaque" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var a = [_]u8{ 3, 2, 1 };
    var runtime_zero: usize = 0;
    incrementVoidPtrArray(a[runtime_zero..].ptr, 3);
    try expect(std.mem.eql(u8, &a, &[_]u8{ 4, 3, 2 }));
}

fn incrementVoidPtrArray(array: ?*anyopaque, len: usize) void {
    var n: usize = 0;
    while (n < len) : (n += 1) {
        @ptrCast([*]u8, array.?)[n] += 1;
    }
}

test "compile time int to ptr of function" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try foobar(FUNCTION_CONSTANT);
}

// On some architectures function pointers must be aligned.
const hardcoded_fn_addr = maxInt(usize) & ~@as(usize, 0xf);
pub const FUNCTION_CONSTANT = @intToPtr(PFN_void, hardcoded_fn_addr);
pub const PFN_void = *const fn (*anyopaque) callconv(.C) void;

fn foobar(func: PFN_void) !void {
    try std.testing.expect(@ptrToInt(func) == hardcoded_fn_addr);
}

test "implicit ptr to *anyopaque" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var a: u32 = 1;
    var ptr: *align(@alignOf(u32)) anyopaque = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    try expect(b.* == 1);
    var ptr2: ?*align(@alignOf(u32)) anyopaque = &a;
    var c: *u32 = @ptrCast(*u32, ptr2.?);
    try expect(c.* == 1);
}

test "return null from fn() anyerror!?&T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const a = returnNullFromOptionalTypeErrorRef();
    const b = returnNullLitFromOptionalTypeErrorRef();
    try expect((try a) == null and (try b) == null);
}
fn returnNullFromOptionalTypeErrorRef() anyerror!?*A {
    const a: ?*A = null;
    return a;
}
fn returnNullLitFromOptionalTypeErrorRef() anyerror!?*A {
    return null;
}

test "peer type resolution: [0]u8 and []const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    try expect(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
    try expect(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    comptime {
        try expect(peerTypeEmptyArrayAndSlice(true, "hi").len == 0);
        try expect(peerTypeEmptyArrayAndSlice(false, "hi").len == 1);
    }
}
fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) []const u8 {
    if (a) {
        return &[_]u8{};
    }

    return slice[0..1];
}

test "implicitly cast from [N]T to ?[]const T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, castToOptionalSlice().?, "hi"));
    comptime try expect(mem.eql(u8, castToOptionalSlice().?, "hi"));
}

fn castToOptionalSlice() ?[]const u8 {
    return "hi";
}

test "cast u128 to f128 and back" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    comptime try testCast128();
    try testCast128();
}

fn testCast128() !void {
    try expect(cast128Int(cast128Float(0x7fff0000000000000000000000000000)) == 0x7fff0000000000000000000000000000);
}

fn cast128Int(x: f128) u128 {
    return @bitCast(u128, x);
}

fn cast128Float(x: u128) f128 {
    return @bitCast(f128, x);
}

test "implicit cast from *[N]T to ?[*]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    var x: ?[*]u16 = null;
    var y: [4]u16 = [4]u16{ 0, 1, 2, 3 };

    x = &y;
    try expect(std.mem.eql(u16, x.?[0..4], y[0..4]));
    x.?[0] = 8;
    y[3] = 6;
    try expect(std.mem.eql(u16, x.?[0..4], y[0..4]));
}

test "implicit cast from *T to ?*anyopaque" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var a: u8 = 1;
    incrementVoidPtrValue(&a);
    try std.testing.expect(a == 2);
}

fn incrementVoidPtrValue(value: ?*anyopaque) void {
    @ptrCast(*u8, value.?).* += 1;
}

test "implicit cast *[0]T to E![]const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    var x = @as(anyerror![]const u8, &[0]u8{});
    try expect((x catch unreachable).len == 0);
}

var global_array: [4]u8 = undefined;
test "cast from array reference to fn: comptime fn ptr" {
    const f = @ptrCast(*const fn () callconv(.C) void, &global_array);
    try expect(@ptrToInt(f) == @ptrToInt(&global_array));
}
test "cast from array reference to fn: runtime fn ptr" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    var f = @ptrCast(*const fn () callconv(.C) void, &global_array);
    try expect(@ptrToInt(f) == @ptrToInt(&global_array));
}

test "*const [N]null u8 to ?[]const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var a = "Hello";
            var b: ?[]const u8 = a;
            try expect(mem.eql(u8, b.?, "Hello"));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast between [*c]T and ?[*:0]T on fn parameter" {
    const S = struct {
        const Handler = ?fn ([*c]const u8) callconv(.C) void;
        fn addCallback(handler: Handler) void {
            _ = handler;
        }

        fn myCallback(cstr: ?[*:0]const u8) callconv(.C) void {
            _ = cstr;
        }

        fn doTheTest() void {
            addCallback(myCallback);
        }
    };
    S.doTheTest();
}

var global_struct: struct { f0: usize } = undefined;
test "assignment to optional pointer result loc" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var foo: struct { ptr: ?*anyopaque } = .{ .ptr = &global_struct };
    try expect(foo.ptr.? == @ptrCast(*anyopaque, &global_struct));
}

test "cast between *[N]void and []void" {
    var a: [4]void = undefined;
    var b: []void = &a;
    try expect(b.len == 4);
}

test "peer resolve arrays of different size to const slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(mem.eql(u8, boolToStr(true), "true"));
    try expect(mem.eql(u8, boolToStr(false), "false"));
    comptime try expect(mem.eql(u8, boolToStr(true), "true"));
    comptime try expect(mem.eql(u8, boolToStr(false), "false"));
}
fn boolToStr(b: bool) []const u8 {
    return if (b) "true" else "false";
}

test "cast f16 to wider types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x: f16 = 1234.0;
            try expect(@as(f32, 1234.0) == x);
            try expect(@as(f64, 1234.0) == x);
            try expect(@as(f128, 1234.0) == x);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast f128 to narrower types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x: f128 = 1234.0;
            try expect(@as(f16, 1234.0) == @floatCast(f16, x));
            try expect(@as(f32, 1234.0) == @floatCast(f32, x));
            try expect(@as(f64, 1234.0) == @floatCast(f64, x));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "peer type resolution: unreachable, null, slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(num: usize, word: []const u8) !void {
            const result = switch (num) {
                0 => null,
                1 => word,
                else => unreachable,
            };
            try expect(mem.eql(u8, result.?, "hi"));
        }
    };
    try S.doTheTest(1, "hi");
}

test "cast i8 fn call peers to i32 result" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var cond = true;
            const value: i32 = if (cond) smallBoi() else bigBoi();
            try expect(value == 123);
        }
        fn smallBoi() i8 {
            return 123;
        }
        fn bigBoi() i16 {
            return 1234;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast compatible optional types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var a: ?[:0]const u8 = null;
    var b: ?[]const u8 = a;
    try expect(b == null);
}

test "coerce undefined single-item pointer of array to error union of slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const a = @as([*]u8, undefined)[0..0];
    var b: error{a}![]const u8 = a;
    const s = try b;
    try expect(s.len == 0);
}

test "pointer to empty struct literal to mutable slice" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    var x: []i32 = &.{};
    try expect(x.len == 0);
}

test "coerce between pointers of compatible differently-named floats" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const F = switch (@typeInfo(c_longdouble).Float.bits) {
        16 => f16,
        32 => f32,
        64 => f64,
        80 => f80,
        128 => f128,
        else => @compileError("unreachable"),
    };
    var f1: F = 12.34;
    var f2: *c_longdouble = &f1;
    f2.* += 1;
    try expect(f1 == @as(F, 12.34) + 1);
}
