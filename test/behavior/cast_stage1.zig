const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const maxInt = std.math.maxInt;
const Vector = std.meta.Vector;
const native_endian = @import("builtin").target.cpu.arch.endian();

test "explicit cast from integer to error type" {
    try testCastIntToErr(error.ItBroke);
    comptime try testCastIntToErr(error.ItBroke);
}
fn testCastIntToErr(err: anyerror) !void {
    const x = @errorToInt(err);
    const y = @intToError(x);
    try expect(error.ItBroke == y);
}

test "peer resolve arrays of different size to const slice" {
    try expect(mem.eql(u8, boolToStr(true), "true"));
    try expect(mem.eql(u8, boolToStr(false), "false"));
    comptime try expect(mem.eql(u8, boolToStr(true), "true"));
    comptime try expect(mem.eql(u8, boolToStr(false), "false"));
}
fn boolToStr(b: bool) []const u8 {
    return if (b) "true" else "false";
}

test "peer resolve array and const slice" {
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
    _ = g catch {};

    const a = A{ .a = z };
    const b: anyerror!?A = a;
    try expect((b catch unreachable).?.a == 1);
}

test "implicitly cast from [0]T to anyerror![]T" {
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
    const window_name = [1][*]const u8{"window name"};
    const x: [*]const ?[*]const u8 = &window_name;
    try expect(mem.eql(u8, std.mem.sliceTo(@ptrCast([*:0]const u8, x[0].?), 0), "window name"));
}

test "cast f16 to wider types" {
    const S = struct {
        fn doTheTest() !void {
            var x: f16 = 1234.0;
            try std.testing.expectEqual(@as(f32, 1234.0), x);
            try std.testing.expectEqual(@as(f64, 1234.0), x);
            try std.testing.expectEqual(@as(f128, 1234.0), x);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast f128 to narrower types" {
    const S = struct {
        fn doTheTest() !void {
            var x: f128 = 1234.0;
            try std.testing.expectEqual(@as(f16, 1234.0), @floatCast(f16, x));
            try std.testing.expectEqual(@as(f32, 1234.0), @floatCast(f32, x));
            try std.testing.expectEqual(@as(f64, 1234.0), @floatCast(f64, x));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "vector casts" {
    const S = struct {
        fn doTheTest() !void {
            // Upcast (implicit, equivalent to @intCast)
            var up0: Vector(2, u8) = [_]u8{ 0x55, 0xaa };
            var up1 = @as(Vector(2, u16), up0);
            var up2 = @as(Vector(2, u32), up0);
            var up3 = @as(Vector(2, u64), up0);
            // Downcast (safety-checked)
            var down0 = up3;
            var down1 = @intCast(Vector(2, u32), down0);
            var down2 = @intCast(Vector(2, u16), down0);
            var down3 = @intCast(Vector(2, u8), down0);

            try expect(mem.eql(u16, &@as([2]u16, up1), &[2]u16{ 0x55, 0xaa }));
            try expect(mem.eql(u32, &@as([2]u32, up2), &[2]u32{ 0x55, 0xaa }));
            try expect(mem.eql(u64, &@as([2]u64, up3), &[2]u64{ 0x55, 0xaa }));

            try expect(mem.eql(u32, &@as([2]u32, down1), &[2]u32{ 0x55, 0xaa }));
            try expect(mem.eql(u16, &@as([2]u16, down2), &[2]u16{ 0x55, 0xaa }));
            try expect(mem.eql(u8, &@as([2]u8, down3), &[2]u8{ 0x55, 0xaa }));
        }

        fn doTheTestFloat() !void {
            var vec = @splat(2, @as(f32, 1234.0));
            var wider: Vector(2, f64) = vec;
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

test "peer type resolution: unreachable, null, slice" {
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

test "peer type resolution: unreachable, error set, unreachable" {
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

test "peer cast *[0]T to E![]const T" {
    var buffer: [5]u8 = "abcde".*;
    var buf: anyerror![]const u8 = buffer[0..];
    var b = false;
    var y = if (b) &[0]u8{} else buf;
    try expect(mem.eql(u8, "abcde", y catch unreachable));
}

test "peer cast *[0]T to []const T" {
    var buffer: [5]u8 = "abcde".*;
    var buf: []const u8 = buffer[0..];
    var b = false;
    var y = if (b) &[0]u8{} else buf;
    try expect(mem.eql(u8, "abcde", y));
}

test "peer resolution of string literals" {
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

test "type coercion related to sentinel-termination" {
    const S = struct {
        fn doTheTest() !void {
            // [:x]T to []T
            {
                var array = [4:0]i32{ 1, 2, 3, 4 };
                var slice: [:0]i32 = &array;
                var dest: []i32 = slice;
                try expect(mem.eql(i32, dest, &[_]i32{ 1, 2, 3, 4 }));
            }

            // [*:x]T to [*]T
            {
                var array = [4:99]i32{ 1, 2, 3, 4 };
                var dest: [*]i32 = &array;
                try expect(dest[0] == 1);
                try expect(dest[1] == 2);
                try expect(dest[2] == 3);
                try expect(dest[3] == 4);
                try expect(dest[4] == 99);
            }

            // [N:x]T to [N]T
            {
                var array = [4:0]i32{ 1, 2, 3, 4 };
                var dest: [4]i32 = array;
                try expect(mem.eql(i32, &dest, &[_]i32{ 1, 2, 3, 4 }));
            }

            // *[N:x]T to *[N]T
            {
                var array = [4:0]i32{ 1, 2, 3, 4 };
                var dest: *[4]i32 = &array;
                try expect(mem.eql(i32, dest, &[_]i32{ 1, 2, 3, 4 }));
            }

            // [:x]T to [*:x]T
            {
                var array = [4:0]i32{ 1, 2, 3, 4 };
                var slice: [:0]i32 = &array;
                var dest: [*:0]i32 = slice;
                try expect(dest[0] == 1);
                try expect(dest[1] == 2);
                try expect(dest[2] == 3);
                try expect(dest[3] == 4);
                try expect(dest[4] == 0);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "cast i8 fn call peers to i32 result" {
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

test "peer type resolution implicit cast to return type" {
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
}

test "peer type resolve string lit with sentinel-terminated mutable slice" {
    var array: [4:0]u8 = undefined;
    array[4] = 0; // TODO remove this when #4372 is solved
    var slice: [:0]u8 = array[0..4 :0];
    comptime try expect(@TypeOf(slice, "hi") == [:0]const u8);
    comptime try expect(@TypeOf("hi", slice) == [:0]const u8);
}

test "peer type unsigned int to signed" {
    var w: u31 = 5;
    var x: u8 = 7;
    var y: i32 = -5;
    var a = w + y + x;
    comptime try expect(@TypeOf(a) == i32);
    try expect(a == 7);
}

test "peer type resolve array pointers, one of them const" {
    var array1: [4]u8 = undefined;
    const array2: [5]u8 = undefined;
    comptime try expect(@TypeOf(&array1, &array2) == []const u8);
    comptime try expect(@TypeOf(&array2, &array1) == []const u8);
}

test "peer type resolve array pointer and unknown pointer" {
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

fn expectFloatToInt(comptime F: type, f: F, comptime I: type, i: I) !void {
    try expect(@floatToInt(I, f) == i);
}
