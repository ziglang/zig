const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const mem = std.mem;
const maxInt = std.math.maxInt;
const native_endian = builtin.target.cpu.arch.endian();

test "int to ptr cast" {
    const x = @as(usize, 13);
    const y = @as(*u8, @ptrFromInt(x));
    const z = @intFromPtr(y);
    try expect(z == 13);
}

test "integer literal to pointer cast" {
    const vga_mem = @as(*u16, @ptrFromInt(0xB8000));
    try expect(@intFromPtr(vga_mem) == 0xB8000);
}

test "peer type resolution: ?T and T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    try comptime testResolveUndefWithInt(true, 1234);
}
fn testResolveUndefWithInt(b: bool, x: i32) !void {
    const value = if (b) x else undefined;
    if (b) {
        try expect(value == x);
    }
}

test "@intCast to comptime_int" {
    try expect(@as(comptime_int, @intCast(0)) == 0);
}

test "implicit cast comptime numbers to any type when the value fits" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const a: u64 = 255;
    var b: u8 = a;
    _ = &b;
    try expect(b == 255);
}

test "implicit cast comptime_int to comptime_float" {
    comptime assert(@as(comptime_float, 10) == @as(f32, 10));
    try expect(2 == 2.0);
}

test "comptime_int @floatFromInt" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    {
        const result = @as(f16, @floatFromInt(1234));
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @as(f32, @floatFromInt(1234));
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
    {
        const result = @as(f64, @floatFromInt(1234));
        try expect(@TypeOf(result) == f64);
        try expect(result == 1234.0);
    }

    {
        const result = @as(f128, @floatFromInt(1234));
        try expect(@TypeOf(result) == f128);
        try expect(result == 1234.0);
    }
    // big comptime_int (> 64 bits) to f128 conversion
    {
        const result = @as(f128, @floatFromInt(0x1_0000_0000_0000_0000));
        try expect(@TypeOf(result) == f128);
        try expect(result == 0x1_0000_0000_0000_0000.0);
    }
}

test "@floatFromInt" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try testIntToFloat(-2);
        }

        fn testIntToFloat(k: i32) !void {
            const f = @as(f32, @floatFromInt(k));
            const i = @as(i32, @intFromFloat(f));
            try expect(i == k);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@floatFromInt(f80)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c and comptime builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(comptime Int: type) !void {
            try testIntToFloat(Int, -2);
        }

        fn testIntToFloat(comptime Int: type, k: Int) !void {
            @setRuntimeSafety(false); // TODO
            const f = @as(f80, @floatFromInt(k));
            const i = @as(Int, @intFromFloat(f));
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
    try comptime S.doTheTest(i31);
    try comptime S.doTheTest(i32);
    try comptime S.doTheTest(i45);
    try comptime S.doTheTest(i64);
    try comptime S.doTheTest(i80);
    try comptime S.doTheTest(i128);
    try comptime S.doTheTest(i256);
}

test "@intFromFloat" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testIntFromFloats();
    try comptime testIntFromFloats();
}

fn testIntFromFloats() !void {
    const x = @as(i32, 1e4);
    try expect(x == 10000);
    const y = @as(i32, @intFromFloat(@as(f32, 1e4)));
    try expect(y == 10000);
    try expectIntFromFloat(f32, 255.1, u8, 255);
    try expectIntFromFloat(f32, 127.2, i8, 127);
    try expectIntFromFloat(f32, -128.2, i8, -128);
}

fn expectIntFromFloat(comptime F: type, f: F, comptime I: type, i: I) !void {
    try expect(@as(I, @intFromFloat(f)) == i);
}

test "implicitly cast indirect pointer to maybe-indirect pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    const result = @as(i32, @intCast(1234));
    try expect(@TypeOf(result) == i32);
    try expect(result == 1234);
}

test "@floatCast comptime_int and comptime_float" {
    {
        const result = @as(f16, @floatCast(1234));
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @as(f16, @floatCast(1234.0));
        try expect(@TypeOf(result) == f16);
        try expect(result == 1234.0);
    }
    {
        const result = @as(f32, @floatCast(1234));
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
    {
        const result = @as(f32, @floatCast(1234.0));
        try expect(@TypeOf(result) == f32);
        try expect(result == 1234.0);
    }
}

test "coerce undefined to optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: [4]u16 = [4]u16{ 0, 1, 2, 3 };
    var y: [*c]u16 = &x;

    try expect(std.mem.eql(u16, x[0..4], y[0..4]));
    x[0] = 8;
    y[3] = 6;
    try expect(std.mem.eql(u16, x[0..4], y[0..4]));
}

test "*usize to *void" {
    var i = @as(usize, 0);
    const v: *void = @ptrCast(&i);
    v.* = {};
}

test "@enumFromInt passed a comptime_int to an enum with one item" {
    const E = enum { A };
    const x = @as(E, @enumFromInt(0));
    try expect(x == E.A);
}

test "@intCast to u0 and use the result" {
    const S = struct {
        fn doTheTest(zero: u1, one: u1, bigzero: i32) !void {
            try expect((one << @as(u0, @intCast(bigzero))) == 1);
            try expect((zero << @as(u0, @intCast(bigzero))) == 0);
        }
    };
    try S.doTheTest(0, 1, 0);
    try comptime S.doTheTest(0, 1, 0);
}

test "peer result null and comptime_int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    comptime assert(S.blah(0) == null);
    try expect(S.blah(10).? == 1);
    comptime assert(S.blah(10).? == 1);
    try expect(S.blah(-10).? == -1);
    comptime assert(S.blah(-10).? == -1);
}

test "*const ?[*]const T to [*c]const [*c]const T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var array = [_]u8{ 'o', 'k' };
    const opt_array_ptr: ?[*]const u8 = &array;
    const a: *const ?[*]const u8 = &opt_array_ptr;
    const b: [*c]const [*c]const u8 = a;
    try expect(b.*[0] == 'o');
    try expect(b[0][1] == 'k');
}

test "array coercion to undefined at runtime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try expect(foo(123).? == 123);
        }
        fn foo(arg: u8) ?u32 {
            return arg;
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "cast from ?[*]T to ??[*]T" {
    const a: ??[*]u8 = @as(?[*]u8, null);
    try expect(a != null and a.? == null);
}

test "peer type unsigned int to signed" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var w: u31 = 5;
    var x: u8 = 7;
    var y: i32 = -5;
    _ = .{ &w, &x, &y };
    const a = w + y + x;
    comptime assert(@TypeOf(a) == i32);
    try expect(a == 7);
}

test "expected [*c]const u8, found [*:0]const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: [*:0]const u8 = "hello";
    _ = &a;
    const b: [*c]const u8 = a;
    const c: [*:0]const u8 = b;
    try expect(std.mem.eql(u8, c[0..5], "hello"));
}

test "explicit cast from integer to error type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCastIntToErr(error.ItBroke);
    try comptime testCastIntToErr(error.ItBroke);
}
fn testCastIntToErr(err: anyerror) !void {
    const x = @intFromError(err);
    const y = @errorFromInt(x);
    try expect(error.ItBroke == y);
}

test "peer resolve array and const slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testPeerResolveArrayConstSlice(true);
    try comptime testPeerResolveArrayConstSlice(true);
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try castToOptionalTypeError(1);
    try comptime castToOptionalTypeError(1);
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCastZeroArrayToErrSliceMut();
    try comptime testCastZeroArrayToErrSliceMut();
}

fn testCastZeroArrayToErrSliceMut() !void {
    try expect((gimmeErrOrSlice() catch unreachable).len == 0);
}

fn gimmeErrOrSlice() anyerror![]u8 {
    return &[_]u8{};
}

test "peer type resolution: [0]u8, []const u8, and anyerror![]u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) anyerror![]u8 {
    if (a) {
        return &[_]u8{};
    }

    return slice[0..1];
}

test "implicit cast from *const [N]T to []const T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testCastConstArrayRefToConstSlice();
    try comptime testCastConstArrayRefToConstSlice();
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    comptime assert(mem.eql(u8, try testPeerErrorAndArray(0), "OK"));
    try expect(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
    comptime assert(mem.eql(u8, try testPeerErrorAndArray2(1), "OKK"));
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCastPtrOfArrayToSliceAndPtr();
    try comptime testCastPtrOfArrayToSliceAndPtr();
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const window_name = [1][*]const u8{"window name"};
    const x: [*]const ?[*]const u8 = &window_name;
    try expect(mem.eql(u8, std.mem.sliceTo(@as([*:0]const u8, @ptrCast(x[0].?)), 0), "window name"));
}

test "@intCast on vector" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            // Upcast (implicit, equivalent to @intCast)
            var up0: @Vector(2, u8) = [_]u8{ 0x55, 0xaa };
            _ = &up0;
            const up1: @Vector(2, u16) = up0;
            const up2: @Vector(2, u32) = up0;
            const up3: @Vector(2, u64) = up0;
            // Downcast (safety-checked)
            var down0 = up3;
            _ = &down0;
            const down1: @Vector(2, u32) = @intCast(down0);
            const down2: @Vector(2, u16) = @intCast(down0);
            const down3: @Vector(2, u8) = @intCast(down0);

            try expect(mem.eql(u16, &@as([2]u16, up1), &[2]u16{ 0x55, 0xaa }));
            try expect(mem.eql(u32, &@as([2]u32, up2), &[2]u32{ 0x55, 0xaa }));
            try expect(mem.eql(u64, &@as([2]u64, up3), &[2]u64{ 0x55, 0xaa }));

            try expect(mem.eql(u32, &@as([2]u32, down1), &[2]u32{ 0x55, 0xaa }));
            try expect(mem.eql(u16, &@as([2]u16, down2), &[2]u16{ 0x55, 0xaa }));
            try expect(mem.eql(u8, &@as([2]u8, down3), &[2]u8{ 0x55, 0xaa }));
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@floatCast cast down" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    {
        var double: f64 = 0.001534;
        _ = &double;
        const single = @as(f32, @floatCast(double));
        try expect(single == 0.001534);
    }
    {
        const double: f64 = 0.001534;
        const single = @as(f32, @floatCast(double));
        try expect(single == 0.001534);
    }
}

test "peer type resolution: unreachable, error set, unreachable" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    _ = &err;
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a: error{ One, Two } = undefined;
    const b: error{Three} = undefined;

    {
        const ty = @TypeOf(a, b);
        const error_set_info = @typeInfo(ty);
        try expect(error_set_info == .ErrorSet);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Three"));
    }

    {
        const ty = @TypeOf(b, a);
        const error_set_info = @typeInfo(ty);
        try expect(error_set_info == .ErrorSet);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Three"));
    }
}

test "peer type resolution: error union and error set" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const a: error{Three} = undefined;
    const b: error{ One, Two }!u32 = undefined;

    {
        const ty = @TypeOf(a, b);
        const info = @typeInfo(ty);
        try expect(info == .ErrorUnion);

        const error_set_info = @typeInfo(info.ErrorUnion.error_set);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Three"));
    }

    {
        const ty = @TypeOf(b, a);
        const info = @typeInfo(ty);
        try expect(info == .ErrorUnion);

        const error_set_info = @typeInfo(info.ErrorUnion.error_set);
        try expect(error_set_info.ErrorSet.?.len == 3);
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[0].name, "One"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[1].name, "Two"));
        try expect(mem.eql(u8, error_set_info.ErrorSet.?[2].name, "Three"));
    }
}

test "peer type resolution: error union after non-error" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var buffer: [5]u8 = "abcde".*;
    const buf: anyerror![]const u8 = buffer[0..];
    var b = false;
    _ = &b;
    const y = if (b) &[0]u8{} else buf;
    const z = if (!b) buf else &[0]u8{};
    try expect(mem.eql(u8, "abcde", y catch unreachable));
    try expect(mem.eql(u8, "abcde", z catch unreachable));
}

test "peer cast *[0]T to []const T" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var buffer: [5]u8 = "abcde".*;
    const buf: []const u8 = buffer[0..];
    var b = false;
    _ = &b;
    const y = if (b) &[0]u8{} else buf;
    try expect(mem.eql(u8, "abcde", y));
}

test "peer cast *[N]T to [*]T" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var array = [4:99]i32{ 1, 2, 3, 4 };
    var dest: [*]i32 = undefined;
    _ = &dest;
    try expect(@TypeOf(&array, dest) == [*]i32);
    try expect(@TypeOf(dest, &array) == [*]i32);
}

test "peer resolution of string literals" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    try comptime S.doTheTest(.b);
}

test "peer cast [:x]T to []T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            const slice: [:0]i32 = &array;
            const dest: []i32 = slice;
            try expect(mem.eql(i32, dest, &[_]i32{ 1, 2, 3, 4 }));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "peer cast [N:x]T to [N]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            _ = &array;
            const dest: [4]i32 = array;
            try expect(mem.eql(i32, &dest, &[_]i32{ 1, 2, 3, 4 }));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "peer cast *[N:x]T to *[N]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            const dest: *[4]i32 = &array;
            try expect(mem.eql(i32, dest, &[_]i32{ 1, 2, 3, 4 }));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "peer cast [*:x]T to [*]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var array = [4:99]i32{ 1, 2, 3, 4 };
            const dest: [*]i32 = &array;
            try expect(dest[0] == 1);
            try expect(dest[1] == 2);
            try expect(dest[2] == 3);
            try expect(dest[3] == 4);
            try expect(dest[4] == 99);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "peer cast [:x]T to [*:x]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var array = [4:0]i32{ 1, 2, 3, 4 };
            const slice: [:0]i32 = &array;
            const dest: [*:0]i32 = slice;
            try expect(dest[0] == 1);
            try expect(dest[1] == 2);
            try expect(dest[2] == 3);
            try expect(dest[3] == 4);
            try expect(dest[4] == 0);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "peer type resolution implicit cast to return type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}

test "peer type resolution implicit cast to variable type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    try comptime S.doTheTest();
}

test "variable initialization uses result locations properly with regards to the type" {
    var b = true;
    _ = &b;
    const x: i32 = if (b) 1 else 2;
    try expect(x == 1);
}

test "cast between C pointer with different but compatible types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn foo(arg: [*]c_ushort) u16 {
            return arg[0];
        }
        fn doTheTest() !void {
            var x = [_]u16{ 4, 2, 1, 3 };
            try expect(foo(@as([*]u16, @ptrCast(&x))) == 4);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "peer type resolve string lit with sentinel-terminated mutable slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var array: [4:0]u8 = undefined;
    array[4] = 0; // TODO remove this when #4372 is solved
    const slice: [:0]u8 = array[0..4 :0];
    comptime assert(@TypeOf(slice, "hi") == [:0]const u8);
    comptime assert(@TypeOf("hi", slice) == [:0]const u8);
}

test "peer type resolve array pointers, one of them const" {
    var array1: [4]u8 = undefined;
    const array2: [5]u8 = undefined;
    comptime assert(@TypeOf(&array1, &array2) == []const u8);
    comptime assert(@TypeOf(&array2, &array1) == []const u8);
}

test "peer type resolve array pointer and unknown pointer" {
    const const_array: [4]u8 = undefined;
    var array: [4]u8 = undefined;
    var const_ptr: [*]const u8 = undefined;
    var ptr: [*]u8 = undefined;
    _ = .{ &const_ptr, &ptr };

    comptime assert(@TypeOf(&array, ptr) == [*]u8);
    comptime assert(@TypeOf(ptr, &array) == [*]u8);

    comptime assert(@TypeOf(&const_array, ptr) == [*]const u8);
    comptime assert(@TypeOf(ptr, &const_array) == [*]const u8);

    comptime assert(@TypeOf(&array, const_ptr) == [*]const u8);
    comptime assert(@TypeOf(const_ptr, &array) == [*]const u8);

    comptime assert(@TypeOf(&const_array, const_ptr) == [*]const u8);
    comptime assert(@TypeOf(const_ptr, &const_array) == [*]const u8);
}

test "comptime float casts" {
    const a = @as(comptime_float, @floatFromInt(1));
    try expect(a == 1);
    try expect(@TypeOf(a) == comptime_float);
    const b = @as(comptime_int, @intFromFloat(2));
    try expect(b == 2);
    try expect(@TypeOf(b) == comptime_int);

    try expectIntFromFloat(comptime_int, 1234, i16, 1234);
    try expectIntFromFloat(comptime_float, 12.3, comptime_int, 12);
}

test "pointer reinterpret const float to int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // The hex representation is 0x3fe3333333333303.
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @as(*const i32, @ptrCast(float_ptr));
    const int_val = int_ptr.*;
    if (native_endian == .little)
        try expect(int_val == 0x33333303)
    else
        try expect(int_val == 0x3fe33333);
}

test "implicit cast from [*]T to ?*anyopaque" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = [_]u8{ 3, 2, 1 };
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    incrementVoidPtrArray(a[runtime_zero..].ptr, 3);
    try expect(std.mem.eql(u8, &a, &[_]u8{ 4, 3, 2 }));
}

fn incrementVoidPtrArray(array: ?*anyopaque, len: usize) void {
    var n: usize = 0;
    while (n < len) : (n += 1) {
        @as([*]u8, @ptrCast(array.?))[n] += 1;
    }
}

test "compile time int to ptr of function" {
    try foobar(FUNCTION_CONSTANT);
}

// On some architectures function pointers must be aligned.
const hardcoded_fn_addr = maxInt(usize) & ~@as(usize, 0xf);
pub const FUNCTION_CONSTANT = @as(PFN_void, @ptrFromInt(hardcoded_fn_addr));
pub const PFN_void = *const fn (*anyopaque) callconv(.C) void;

fn foobar(func: PFN_void) !void {
    try std.testing.expect(@intFromPtr(func) == hardcoded_fn_addr);
}

test "cast function with an opaque parameter" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_c) {
        // https://github.com/ziglang/zig/issues/16845
        return error.SkipZigTest;
    }

    const Container = struct {
        const Ctx = opaque {};
        ctx: *Ctx,
        func: *const fn (*Ctx) void,
    };
    const Foo = struct {
        x: i32,
        y: i32,
        fn funcImpl(self: *@This()) void {
            self.x += 1;
            self.y += 1;
        }
    };
    var foo = Foo{ .x = 100, .y = 200 };
    var c = Container{
        .ctx = @ptrCast(&foo),
        .func = @ptrCast(&Foo.funcImpl),
    };
    c.func(c.ctx);
    try std.testing.expectEqual(Foo{ .x = 101, .y = 201 }, foo);
}

test "implicit ptr to *anyopaque" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: u32 = 1;
    const ptr: *align(@alignOf(u32)) anyopaque = &a;
    const b: *u32 = @as(*u32, @ptrCast(ptr));
    try expect(b.* == 1);
    const ptr2: ?*align(@alignOf(u32)) anyopaque = &a;
    const c: *u32 = @as(*u32, @ptrCast(ptr2.?));
    try expect(c.* == 1);
}

test "return null from fn () anyerror!?&T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(mem.eql(u8, castToOptionalSlice().?, "hi"));
    comptime assert(mem.eql(u8, castToOptionalSlice().?, "hi"));
}

fn castToOptionalSlice() ?[]const u8 {
    return "hi";
}

test "cast u128 to f128 and back" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime testCast128();
    try testCast128();
}

fn testCast128() !void {
    try expect(cast128Int(cast128Float(0x7fff0000000000000000000000000000)) == 0x7fff0000000000000000000000000000);
}

fn cast128Int(x: f128) u128 {
    return @as(u128, @bitCast(x));
}

fn cast128Float(x: u128) f128 {
    return @as(f128, @bitCast(x));
}

test "implicit cast from *[N]T to ?[*]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: u8 = 1;
    incrementVoidPtrValue(&a);
    try std.testing.expect(a == 2);
}

fn incrementVoidPtrValue(value: ?*anyopaque) void {
    @as(*u8, @ptrCast(value.?)).* += 1;
}

test "implicit cast *[0]T to E![]const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x = @as(anyerror![]const u8, &[0]u8{});
    _ = &x;
    try expect((x catch unreachable).len == 0);
}

var global_array: [4]u8 = undefined;
test "cast from array reference to fn: comptime fn ptr" {
    const f = @as(*align(1) const fn () callconv(.C) void, @ptrCast(&global_array));
    try expect(@intFromPtr(f) == @intFromPtr(&global_array));
}
test "cast from array reference to fn: runtime fn ptr" {
    var f = @as(*align(1) const fn () callconv(.C) void, @ptrCast(&global_array));
    _ = &f;
    try expect(@intFromPtr(f) == @intFromPtr(&global_array));
}

test "*const [N]null u8 to ?[]const u8" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a = "Hello";
            _ = &a;
            const b: ?[]const u8 = a;
            try expect(mem.eql(u8, b.?, "Hello"));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "cast between [*c]T and ?[*:0]T on fn parameter" {
    const S = struct {
        const Handler = ?fn ([*c]const u8) callconv(.C) void;
        fn addCallback(comptime handler: Handler) void {
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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var foo: struct { ptr: ?*anyopaque } = .{ .ptr = &global_struct };
    _ = &foo;
    try expect(foo.ptr.? == @as(*anyopaque, @ptrCast(&global_struct)));
}

test "cast between *[N]void and []void" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: [4]void = undefined;
    const b: []void = &a;
    try expect(b.len == 4);
}

test "peer resolve arrays of different size to const slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, boolToStr(true), "true"));
    try expect(mem.eql(u8, boolToStr(false), "false"));
    comptime assert(mem.eql(u8, boolToStr(true), "true"));
    comptime assert(mem.eql(u8, boolToStr(false), "false"));
}
fn boolToStr(b: bool) []const u8 {
    return if (b) "true" else "false";
}

test "cast f16 to wider types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c and comptime builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var x: f16 = 1234.0;
            _ = &x;
            try expect(@as(f32, 1234.0) == x);
            try expect(@as(f64, 1234.0) == x);
            try expect(@as(f128, 1234.0) == x);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "cast f128 to narrower types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var x: f128 = 1234.0;
            _ = &x;
            try expect(@as(f16, 1234.0) == @as(f16, @floatCast(x)));
            try expect(@as(f32, 1234.0) == @as(f32, @floatCast(x)));
            try expect(@as(f64, 1234.0) == @as(f64, @floatCast(x)));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "peer type resolution: unreachable, null, slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var cond = true;
            _ = &cond;
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
    try comptime S.doTheTest();
}

test "cast compatible optional types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: ?[:0]const u8 = null;
    _ = &a;
    const b: ?[]const u8 = a;
    try expect(b == null);
}

test "coerce undefined single-item pointer of array to error union of slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const a = @as([*]u8, undefined)[0..0];
    var b: error{a}![]const u8 = a;
    _ = &b;
    const s = try b;
    try expect(s.len == 0);
}

test "pointer to empty struct literal to mutable slice" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: []i32 = &.{};
    _ = &x;
    try expect(x.len == 0);
}

test "coerce between pointers of compatible differently-named floats" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c and builtin.os.tag == .windows and !builtin.link_libc) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/12396
        return error.SkipZigTest;
    }

    const F = switch (@typeInfo(c_longdouble).Float.bits) {
        16 => f16,
        32 => f32,
        64 => f64,
        80 => f80,
        128 => f128,
        else => @compileError("unreachable"),
    };
    var f1: F = 12.34;
    const f2: *c_longdouble = &f1;
    f2.* += 1;
    try expect(f1 == @as(F, 12.34) + 1);
}

test "peer type resolution of const and non-const pointer to array" {
    const a = @as(*[1024]u8, @ptrFromInt(42));
    const b = @as(*const [1024]u8, @ptrFromInt(42));
    try std.testing.expect(@TypeOf(a, b) == *const [1024]u8);
    try std.testing.expect(a == b);
}

test "intFromFloat to zero-bit int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a: f32 = 0.0;
    try comptime std.testing.expect(@as(u0, @intFromFloat(a)) == 0);
}

test "peer type resolution of function pointer and function body" {
    const T = fn () u32;
    const a: T = undefined;
    const b: *const T = undefined;
    try expect(@TypeOf(a, b) == *const fn () u32);
    try expect(@TypeOf(b, a) == *const fn () u32);
}

test "cast typed undefined to int" {
    comptime {
        const a: u16 = undefined;
        const b: u8 = a;
        _ = b;
    }
}

test "implicit cast from [:0]T to [*c]T" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: [:0]const u8 = "foo";
    _ = &a;
    const b: [*c]const u8 = a;
    const c = std.mem.span(b);
    try expect(c.len == a.len);
    try expect(c.ptr == a.ptr);
}

test "bitcast packed struct with u0" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = packed struct(u2) { a: u0, b: u2 };
    const s = @as(S, @bitCast(@as(u2, 2)));
    try expect(s.a == 0);
    try expect(s.b == 2);
    const i = @as(u2, @bitCast(s));
    try expect(i == 2);
}

test "optional pointer coerced to optional allowzero pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var p: ?*u32 = undefined;
    var q: ?*allowzero u32 = undefined;
    p = @as(*u32, @ptrFromInt(4));
    q = p;
    try expect(@intFromPtr(q.?) == 4);
}

test "optional slice coerced to allowzero many pointer" {
    const a: ?[]const u32 = null;
    const b: [*]allowzero const u8 = @ptrCast(a);
    const c = @intFromPtr(b);
    try std.testing.expect(c == 0);
}

test "optional slice passed as parameter coerced to allowzero many pointer" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const ns = struct {
        const Color = struct {
            r: u8,
            g: u8,
            b: u8,
            a: u8,
        };

        fn foo(pixels: ?[]const Color) !void {
            const data: [*]allowzero const u8 = @ptrCast(pixels);
            const int = @intFromPtr(data);
            try std.testing.expect(int == 0);
        }
    };

    try ns.foo(null);
}

test "single item pointer to pointer to array to slice" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: i32 = 1234;
    try expect(@as([]const i32, @as(*[1]i32, &x))[0] == 1234);
    const z1 = @as([]const i32, @as(*[1]i32, &x));
    try expect(z1[0] == 1234);
}

test "peer type resolution forms error union" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var foo: i32 = 123;
    _ = &foo;
    const result = if (foo < 0) switch (-foo) {
        0 => unreachable,
        42 => error.AccessDenied,
        else => unreachable,
    } else @as(u32, @intCast(foo));
    try expect(try result == 123);
}

test "@constCast without a result location" {
    const x: i32 = 1234;
    const y = @constCast(&x);
    try expect(@TypeOf(y) == *i32);
    try expect(y.* == 1234);
}

test "@constCast optional" {
    const x: u8 = 10;
    const m: ?*const u8 = &x;
    const p = @constCast(m);
    try expect(@TypeOf(p) == ?*u8);
}

test "@volatileCast without a result location" {
    var x: i32 = 1234;
    const y: *volatile i32 = &x;
    const z = @volatileCast(y);
    try expect(@TypeOf(z) == *i32);
    try expect(z.* == 1234);
}

test "coercion from single-item pointer to @as to slice" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: u32 = 1;

    // Why the following line gets a compile error?
    const t: []u32 = @as(*[1]u32, &x);

    try expect(t[0] == 1);
}

test "peer type resolution: const sentinel slice and mutable non-sentinel slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(comptime T: type, comptime s: T) !void {
            var a: [:s]const T = @as(*const [2:s]T, @ptrFromInt(0x1000));
            var b: []T = @as(*[3]T, @ptrFromInt(0x2000));
            _ = .{ &a, &b };
            comptime assert(@TypeOf(a, b) == []const T);
            comptime assert(@TypeOf(b, a) == []const T);

            var t = true;
            _ = &t;
            const r1 = if (t) a else b;
            const r2 = if (t) b else a;

            const R = @TypeOf(r1);

            try expectEqual(@as(R, @as(*const [2:s]T, @ptrFromInt(0x1000))), r1);
            try expectEqual(@as(R, @as(*const [3]T, @ptrFromInt(0x2000))), r2);
        }
    };

    try S.doTheTest(u8, 0);
    try S.doTheTest(?*anyopaque, null);
}

test "peer type resolution: float and comptime-known fixed-width integer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const i: u8 = 100;
    var f: f32 = 1.234;
    _ = &f;
    comptime assert(@TypeOf(i, f) == f32);
    comptime assert(@TypeOf(f, i) == f32);

    var t = true;
    _ = &t;
    const r1 = if (t) i else f;
    const r2 = if (t) f else i;

    const T = @TypeOf(r1);

    try expectEqual(@as(T, 100.0), r1);
    try expectEqual(@as(T, 1.234), r2);
}

test "peer type resolution: same array type with sentinel" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: [2:0]u32 = .{ 0, 1 };
    var b: [2:0]u32 = .{ 2, 3 };
    _ = .{ &a, &b };
    comptime assert(@TypeOf(a, b) == [2:0]u32);
    comptime assert(@TypeOf(b, a) == [2:0]u32);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    const T = @TypeOf(r1);

    try expectEqual(T{ 0, 1 }, r1);
    try expectEqual(T{ 2, 3 }, r2);
}

test "peer type resolution: array with sentinel and array without sentinel" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: [2:0]u32 = .{ 0, 1 };
    var b: [2]u32 = .{ 2, 3 };
    _ = .{ &a, &b };
    comptime assert(@TypeOf(a, b) == [2]u32);
    comptime assert(@TypeOf(b, a) == [2]u32);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    const T = @TypeOf(r1);

    try expectEqual(T{ 0, 1 }, r1);
    try expectEqual(T{ 2, 3 }, r2);
}

test "peer type resolution: array and vector with same child type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var arr: [2]u32 = .{ 0, 1 };
    var vec: @Vector(2, u32) = .{ 2, 3 };
    _ = .{ &arr, &vec };
    comptime assert(@TypeOf(arr, vec) == @Vector(2, u32));
    comptime assert(@TypeOf(vec, arr) == @Vector(2, u32));

    var t = true;
    _ = &t;
    const r1 = if (t) arr else vec;
    const r2 = if (t) vec else arr;

    const T = @TypeOf(r1);

    try expectEqual(T{ 0, 1 }, r1);
    try expectEqual(T{ 2, 3 }, r2);
}

test "peer type resolution: array with smaller child type and vector with larger child type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var arr: [2]u8 = .{ 0, 1 };
    var vec: @Vector(2, u64) = .{ 2, 3 };
    _ = .{ &arr, &vec };
    comptime assert(@TypeOf(arr, vec) == @Vector(2, u64));
    comptime assert(@TypeOf(vec, arr) == @Vector(2, u64));

    var t = true;
    _ = &t;
    const r1 = if (t) arr else vec;
    const r2 = if (t) vec else arr;

    const T = @TypeOf(r1);

    try expectEqual(T{ 0, 1 }, r1);
    try expectEqual(T{ 2, 3 }, r2);
}

test "peer type resolution: error union and optional of same type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const E = error{Foo};
    var a: E!*u8 = error.Foo;
    var b: ?*u8 = null;
    _ = .{ &a, &b };
    comptime assert(@TypeOf(a, b) == E!?*u8);
    comptime assert(@TypeOf(b, a) == E!?*u8);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    const T = @TypeOf(r1);

    try expectEqual(@as(T, error.Foo), r1);
    try expectEqual(@as(T, null), r2);
}

test "peer type resolution: C pointer and @TypeOf(null)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: [*c]c_int = 0x1000;
    _ = &a;
    const b = null;
    comptime assert(@TypeOf(a, b) == [*c]c_int);
    comptime assert(@TypeOf(b, a) == [*c]c_int);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    const T = @TypeOf(r1);

    try expectEqual(@as(T, 0x1000), r1);
    try expectEqual(@as(T, null), r2);
}

test "peer type resolution: three-way resolution combines error set and optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const E = error{Foo};
    var a: E = error.Foo;
    var b: *const [5:0]u8 = @ptrFromInt(0x1000);
    var c: ?[*:0]u8 = null;
    _ = .{ &a, &b, &c };
    comptime assert(@TypeOf(a, b, c) == E!?[*:0]const u8);
    comptime assert(@TypeOf(a, c, b) == E!?[*:0]const u8);
    comptime assert(@TypeOf(b, a, c) == E!?[*:0]const u8);
    comptime assert(@TypeOf(b, c, a) == E!?[*:0]const u8);
    comptime assert(@TypeOf(c, a, b) == E!?[*:0]const u8);
    comptime assert(@TypeOf(c, b, a) == E!?[*:0]const u8);

    var x: u8 = 0;
    _ = &x;
    const r1 = switch (x) {
        0 => a,
        1 => b,
        else => c,
    };
    const r2 = switch (x) {
        0 => b,
        1 => a,
        else => c,
    };
    const r3 = switch (x) {
        0 => c,
        1 => a,
        else => b,
    };

    const T = @TypeOf(r1);

    try expectEqual(@as(T, error.Foo), r1);
    try expectEqual(@as(T, @as([*:0]u8, @ptrFromInt(0x1000))), r2);
    try expectEqual(@as(T, null), r3);
}

test "peer type resolution: vector and optional vector" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: ?@Vector(3, u32) = .{ 0, 1, 2 };
    var b: @Vector(3, u32) = .{ 3, 4, 5 };
    _ = .{ &a, &b };
    comptime assert(@TypeOf(a, b) == ?@Vector(3, u32));
    comptime assert(@TypeOf(b, a) == ?@Vector(3, u32));

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    const T = @TypeOf(r1);

    try expectEqual(@as(T, .{ 0, 1, 2 }), r1);
    try expectEqual(@as(T, .{ 3, 4, 5 }), r2);
}

test "peer type resolution: optional fixed-width int and comptime_int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: ?i32 = 42;
    _ = &a;
    const b: comptime_int = 50;
    comptime assert(@TypeOf(a, b) == ?i32);
    comptime assert(@TypeOf(b, a) == ?i32);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    const T = @TypeOf(r1);

    try expectEqual(@as(T, 42), r1);
    try expectEqual(@as(T, 50), r2);
}

test "peer type resolution: array and tuple" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var arr: [3]i32 = .{ 1, 2, 3 };
    _ = &arr;
    const tup = .{ 4, 5, 6 };

    comptime assert(@TypeOf(arr, tup) == [3]i32);
    comptime assert(@TypeOf(tup, arr) == [3]i32);

    var t = true;
    _ = &t;
    const r1 = if (t) arr else tup;
    const r2 = if (t) tup else arr;

    const T = @TypeOf(r1);

    try expectEqual(T{ 1, 2, 3 }, r1);
    try expectEqual(T{ 4, 5, 6 }, r2);
}

test "peer type resolution: vector and tuple" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var vec: @Vector(3, i32) = .{ 1, 2, 3 };
    _ = &vec;
    const tup = .{ 4, 5, 6 };

    comptime assert(@TypeOf(vec, tup) == @Vector(3, i32));
    comptime assert(@TypeOf(tup, vec) == @Vector(3, i32));

    var t = true;
    _ = &t;
    const r1 = if (t) vec else tup;
    const r2 = if (t) tup else vec;

    const T = @TypeOf(r1);

    try expectEqual(T{ 1, 2, 3 }, r1);
    try expectEqual(T{ 4, 5, 6 }, r2);
}

test "peer type resolution: vector and array and tuple" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var vec: @Vector(2, i8) = .{ 10, 20 };
    var arr: [2]i8 = .{ 30, 40 };
    _ = .{ &vec, &arr };
    const tup = .{ 50, 60 };

    comptime assert(@TypeOf(vec, arr, tup) == @Vector(2, i8));
    comptime assert(@TypeOf(vec, tup, arr) == @Vector(2, i8));
    comptime assert(@TypeOf(arr, vec, tup) == @Vector(2, i8));
    comptime assert(@TypeOf(arr, tup, vec) == @Vector(2, i8));
    comptime assert(@TypeOf(tup, vec, arr) == @Vector(2, i8));
    comptime assert(@TypeOf(tup, arr, vec) == @Vector(2, i8));

    var x: u8 = 0;
    _ = &x;
    const r1 = switch (x) {
        0 => vec,
        1 => arr,
        else => tup,
    };
    const r2 = switch (x) {
        0 => arr,
        1 => vec,
        else => tup,
    };
    const r3 = switch (x) {
        0 => tup,
        1 => vec,
        else => arr,
    };

    const T = @TypeOf(r1);

    try expectEqual(T{ 10, 20 }, r1);
    try expectEqual(T{ 30, 40 }, r2);
    try expectEqual(T{ 50, 60 }, r3);
}

test "peer type resolution: empty tuple pointer and slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var a: [:0]const u8 = "Hello";
    var b = &.{};
    _ = .{ &a, &b };

    comptime assert(@TypeOf(a, b) == []const u8);
    comptime assert(@TypeOf(b, a) == []const u8);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    try expectEqualSlices(u8, "Hello", r1);
    try expectEqualSlices(u8, "", r2);
}

test "peer type resolution: tuple pointer and slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var a: [:0]const u8 = "Hello";
    var b = &.{ @as(u8, 'x'), @as(u8, 'y'), @as(u8, 'z') };
    _ = .{ &a, &b };

    comptime assert(@TypeOf(a, b) == []const u8);
    comptime assert(@TypeOf(b, a) == []const u8);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    try expectEqualSlices(u8, "Hello", r1);
    try expectEqualSlices(u8, "xyz", r2);
}

test "peer type resolution: tuple pointer and optional slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    // Miscompilation on Intel's OpenCL CPU runtime.
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // flaky

    var a: ?[:0]const u8 = null;
    var b = &.{ @as(u8, 'x'), @as(u8, 'y'), @as(u8, 'z') };
    _ = .{ &a, &b };

    comptime assert(@TypeOf(a, b) == ?[]const u8);
    comptime assert(@TypeOf(b, a) == ?[]const u8);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    try expectEqual(@as(?[]const u8, null), r1);
    try expectEqualSlices(u8, "xyz", r2 orelse "");
}

test "peer type resolution: many compatible pointers" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var buf = "foo-3".*;

    var vals = .{
        @as([*]const u8, "foo-0"),
        @as([*:0]const u8, "foo-1"),
        @as([*:0]const u8, "foo-2"),
        @as([*]u8, &buf),
        @as(*const [5]u8, "foo-4"),
    };
    _ = &vals;

    // Check every possible permutation of types in @TypeOf
    @setEvalBranchQuota(5000);
    comptime var perms = 0; // check the loop is hitting every permutation
    inline for (0..5) |i_0| {
        inline for (0..5) |i_1| {
            if (i_1 == i_0) continue;
            inline for (0..5) |i_2| {
                if (i_2 == i_0 or i_2 == i_1) continue;
                inline for (0..5) |i_3| {
                    if (i_3 == i_0 or i_3 == i_1 or i_3 == i_2) continue;
                    inline for (0..5) |i_4| {
                        if (i_4 == i_0 or i_4 == i_1 or i_4 == i_2 or i_4 == i_3) continue;
                        perms += 1;
                        comptime assert(@TypeOf(
                            vals[i_0],
                            vals[i_1],
                            vals[i_2],
                            vals[i_3],
                            vals[i_4],
                        ) == [*]const u8);
                    }
                }
            }
        }
    }
    comptime assert(perms == 5 * 4 * 3 * 2 * 1);

    var x: u8 = 0;
    _ = &x;
    inline for (0..5) |i| {
        const r = switch (x) {
            0 => vals[i],
            1 => vals[0],
            2 => vals[1],
            3 => vals[2],
            4 => vals[3],
            else => vals[4],
        };
        const expected = switch (i) {
            0 => "foo-0",
            1 => "foo-1",
            2 => "foo-2",
            3 => "foo-3",
            4 => "foo-4",
            else => unreachable,
        };
        try expectEqualSlices(u8, expected, std.mem.span(@as([*:0]const u8, @ptrCast(r))));
    }
}

test "peer type resolution: tuples with comptime fields" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const a = .{ 1, 2 };
    const b = .{ @as(u32, 3), @as(i16, 4) };

    // TODO: tuple type equality doesn't work properly yet
    const ti1 = @typeInfo(@TypeOf(a, b));
    const ti2 = @typeInfo(@TypeOf(b, a));
    inline for (.{ ti1, ti2 }) |ti| {
        const s = ti.Struct;
        comptime assert(s.is_tuple);
        comptime assert(s.fields.len == 2);
        comptime assert(s.fields[0].type == u32);
        comptime assert(s.fields[1].type == i16);
    }

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    try expectEqual(@as(u32, 1), r1[0]);
    try expectEqual(@as(i16, 2), r1[1]);

    try expectEqual(@as(u32, 3), r2[0]);
    try expectEqual(@as(i16, 4), r2[1]);
}

test "peer type resolution: C pointer and many pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var buf = "hello".*;

    const a: [*c]u8 = &buf;
    var b: [*:0]const u8 = "world";
    _ = &b;

    comptime assert(@TypeOf(a, b) == [*c]const u8);
    comptime assert(@TypeOf(b, a) == [*c]const u8);

    var t = true;
    _ = &t;
    const r1 = if (t) a else b;
    const r2 = if (t) b else a;

    try expectEqual(r1, a);
    try expectEqual(r2, b);
}

test "peer type resolution: pointer attributes are combined correctly" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var buf_a align(4) = "foo".*;
    var buf_b align(4) = "bar".*;
    var buf_c align(4) = "baz".*;

    const a: [*:0]align(4) const u8 = &buf_a;
    const b: *align(2) volatile [3:0]u8 = &buf_b;
    const c: [*:0]align(4) u8 = &buf_c;

    comptime assert(@TypeOf(a, b, c) == [*:0]align(2) const volatile u8);
    comptime assert(@TypeOf(a, c, b) == [*:0]align(2) const volatile u8);
    comptime assert(@TypeOf(b, a, c) == [*:0]align(2) const volatile u8);
    comptime assert(@TypeOf(b, c, a) == [*:0]align(2) const volatile u8);
    comptime assert(@TypeOf(c, a, b) == [*:0]align(2) const volatile u8);
    comptime assert(@TypeOf(c, b, a) == [*:0]align(2) const volatile u8);

    var x: u8 = 0;
    _ = &x;
    const r1 = switch (x) {
        0 => a,
        1 => b,
        else => c,
    };
    const r2 = switch (x) {
        0 => b,
        1 => a,
        else => c,
    };
    const r3 = switch (x) {
        0 => c,
        1 => a,
        else => b,
    };

    try expectEqualSlices(u8, std.mem.span(@volatileCast(r1)), "foo");
    try expectEqualSlices(u8, std.mem.span(@volatileCast(r2)), "bar");
    try expectEqualSlices(u8, std.mem.span(@volatileCast(r3)), "baz");
}

test "peer type resolution: arrays of compatible types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var e0: u8 = 3;
    var e1: u8 = 2;
    var e2: u8 = 1;
    const a = [3]*u8{ &e0, &e1, &e2 };
    const b = [3]*const u8{ &e0, &e1, &e2 };

    comptime assert(@TypeOf(a, b) == [3]*const u8);
    comptime assert(@TypeOf(b, a) == [3]*const u8);

    try expectEqual(@as(@TypeOf(a, b), a), b);
}

test "cast builtins can wrap result in optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const MyEnum = enum(u32) { _ };
        fn a() ?MyEnum {
            return @enumFromInt(123);
        }
        fn b() ?u32 {
            return @intFromFloat(42.50);
        }
        fn c() ?*const f32 {
            const x: u32 = 1;
            return @ptrCast(&x);
        }

        fn doTheTest() !void {
            const ra = a() orelse return error.ImpossibleError;
            const rb = b() orelse return error.ImpossibleError;
            const rc = c() orelse return error.ImpossibleError;

            comptime assert(@TypeOf(ra) == MyEnum);
            comptime assert(@TypeOf(rb) == u32);
            comptime assert(@TypeOf(rc) == *const f32);

            try expect(@intFromEnum(ra) == 123);
            try expect(rb == 42);
            try expect(@as(*const u32, @ptrCast(rc)).* == 1);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "cast builtins can wrap result in error union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const MyEnum = enum(u32) { _ };
        const E = error{ImpossibleError};
        fn a() E!MyEnum {
            return @enumFromInt(123);
        }
        fn b() E!u32 {
            return @intFromFloat(42.50);
        }
        fn c() E!*const f32 {
            const x: u32 = 1;
            return @ptrCast(&x);
        }

        fn doTheTest() !void {
            const ra = try a();
            const rb = try b();
            const rc = try c();

            comptime assert(@TypeOf(ra) == MyEnum);
            comptime assert(@TypeOf(rb) == u32);
            comptime assert(@TypeOf(rc) == *const f32);

            try expect(@intFromEnum(ra) == 123);
            try expect(rb == 42);
            try expect(@as(*const u32, @ptrCast(rc)).* == 1);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "cast builtins can wrap result in error union and optional" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const MyEnum = enum(u32) { _ };
        const E = error{ImpossibleError};
        fn a() E!?MyEnum {
            return @enumFromInt(123);
        }
        fn b() E!?u32 {
            return @intFromFloat(42.50);
        }
        fn c() E!?*const f32 {
            const x: u32 = 1;
            return @ptrCast(&x);
        }

        fn doTheTest() !void {
            const ra = try a() orelse return error.ImpossibleError;
            const rb = try b() orelse return error.ImpossibleError;
            const rc = try c() orelse return error.ImpossibleError;

            comptime assert(@TypeOf(ra) == MyEnum);
            comptime assert(@TypeOf(rb) == u32);
            comptime assert(@TypeOf(rc) == *const f32);

            try expect(@intFromEnum(ra) == 123);
            try expect(rb == 42);
            try expect(@as(*const u32, @ptrCast(rc)).* == 1);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@floatCast on vector" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            {
                var a: @Vector(2, f64) = .{ 1.5, 2.5 };
                _ = &a;
                const b: @Vector(2, f32) = @floatCast(a);
                try expectEqual(@Vector(2, f32){ 1.5, 2.5 }, b);
            }
            {
                var a: @Vector(2, f32) = .{ 3.25, 4.25 };
                _ = &a;
                const b: @Vector(2, f64) = @floatCast(a);
                try expectEqual(@Vector(2, f64){ 3.25, 4.25 }, b);
            }
            {
                var a: @Vector(2, f32) = .{ 5.75, 6.75 };
                _ = &a;
                const b: @Vector(2, f64) = a;
                try expectEqual(@Vector(2, f64){ 5.75, 6.75 }, b);
            }
            {
                var vec: @Vector(2, f32) = @splat(1234.0);
                _ = &vec;
                const wider: @Vector(2, f64) = vec;
                try expect(wider[0] == 1234.0);
                try expect(wider[1] == 1234.0);
            }
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@ptrFromInt on vector" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a: @Vector(3, usize) = .{ 0x1000, 0x2000, 0x3000 };
            _ = &a;
            const b: @Vector(3, *anyopaque) = @ptrFromInt(a);
            try expectEqual(@Vector(3, *anyopaque){
                @ptrFromInt(0x1000),
                @ptrFromInt(0x2000),
                @ptrFromInt(0x3000),
            }, b);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@intFromPtr on vector" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a: @Vector(3, *anyopaque) = .{
                @ptrFromInt(0x1000),
                @ptrFromInt(0x2000),
                @ptrFromInt(0x3000),
            };
            _ = &a;
            const b: @Vector(3, usize) = @intFromPtr(a);
            try expectEqual(@Vector(3, usize){ 0x1000, 0x2000, 0x3000 }, b);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@floatFromInt on vector" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a: @Vector(3, u32) = .{ 10, 20, 30 };
            _ = &a;
            const b: @Vector(3, f32) = @floatFromInt(a);
            try expectEqual(@Vector(3, f32){ 10.0, 20.0, 30.0 }, b);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@intFromFloat on vector" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a: @Vector(3, f32) = .{ 10.3, 20.5, 30.7 };
            _ = &a;
            const b: @Vector(3, u32) = @intFromFloat(a);
            try expectEqual(@Vector(3, u32){ 10, 20, 30 }, b);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@intFromBool on vector" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and
        builtin.cpu.arch == .aarch64 and builtin.os.tag == .windows)
    {
        // https://github.com/ziglang/zig/issues/19825
        return error.SkipZigTest;
    }

    const S = struct {
        fn doTheTest() !void {
            var a: @Vector(3, bool) = .{ false, true, false };
            _ = &a;
            const b: @Vector(3, u1) = @intFromBool(a);
            try expectEqual(@Vector(3, u1){ 0, 1, 0 }, b);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "numeric coercions with undefined" {
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const from: i32 = undefined;
    var to: f32 = from;
    to = @floatFromInt(from);
    to = 42.0;
    try expectEqual(@as(f32, 42.0), to);
}

test "15-bit int to float" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: u15 = 42;
    _ = &a;
    const b: f32 = @floatFromInt(a);
    try expect(b == 42.0);
}

test "@as does not corrupt values with incompatible representations" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const x: f32 = @as(f16, blk: {
        if (false) {
            // Trick the compiler into trying to use a result pointer if it can!
            break :blk .{undefined};
        }
        break :blk 1.23;
    });
    try std.testing.expectApproxEqAbs(@as(f32, 1.23), x, 0.001);
}

test "result information is preserved through many nested structures" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            const E = error{Foo};
            const T = *const ?E!struct { x: ?*const E!?u8 };

            var val: T = &.{ .x = &@truncate(0x1234) };
            _ = &val;

            const struct_val = val.*.? catch unreachable;
            const int_val = (struct_val.x.?.* catch unreachable).?;

            try expect(int_val == 0x34);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@intCast vector of signed integer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    _ = &x;
    const y: @Vector(4, i8) = @intCast(x);

    try expect(y[0] == 1);
    try expect(y[1] == 2);
    try expect(y[2] == 3);
    try expect(y[3] == 4);
}

test "result type is preserved into comptime block" {
    const x: u32 = comptime @intCast(123);
    try expect(x == 123);
}

test "implicit cast from ptr to tuple to ptr to struct" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const ComptimeReason = union(enum) {
        c_import: struct {
            a: u32,
        },
    };

    const Block = struct {
        reason: ?*const ComptimeReason,
    };

    var a: u32 = 16;
    _ = &a;
    var reason = .{ .c_import = .{ .a = a } };
    var block = Block{
        .reason = &reason,
    };
    _ = &block;
    try expect(block.reason.?.c_import.a == 16);
}

test "bitcast vector" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const u8x32 = @Vector(32, u8);
    const u32x8 = @Vector(8, u32);

    const zerox32: u8x32 = [_]u8{0} ** 32;
    const bigsum: u32x8 = @bitCast(zerox32);
    try std.testing.expectEqual(0, @reduce(.Add, bigsum));
}
