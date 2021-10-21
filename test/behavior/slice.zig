const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

// comptime array passed as slice argument
comptime {
    const S = struct {
        fn indexOfScalarPos(comptime T: type, slice: []const T, start_index: usize, value: T) ?usize {
            var i: usize = start_index;
            while (i < slice.len) : (i += 1) {
                if (slice[i] == value) return i;
            }
            return null;
        }

        fn indexOfScalar(comptime T: type, slice: []const T, value: T) ?usize {
            return indexOfScalarPos(T, slice, 0, value);
        }
    };
    const unsigned = [_]type{ c_uint, c_ulong, c_ulonglong };
    const list: []const type = &unsigned;
    var pos = S.indexOfScalar(type, list, c_ulong).?;
    if (pos != 1) @compileError("bad pos");
}

test "slicing" {
    var array: [20]i32 = undefined;

    array[5] = 1234;

    var slice = array[5..10];

    if (slice.len != 5) unreachable;

    const ptr = &slice[0];
    if (ptr.* != 1234) unreachable;

    var slice_rest = array[10..];
    if (slice_rest.len != 10) unreachable;
}

test "const slice" {
    comptime {
        const a = "1234567890";
        try expect(a.len == 10);
        const b = a[1..2];
        try expect(b.len == 1);
        try expect(b[0] == '2');
    }
}

test "comptime slice of undefined pointer of length 0" {
    const slice1 = @as([*]i32, undefined)[0..0];
    try expect(slice1.len == 0);
    const slice2 = @as([*]i32, undefined)[100..100];
    try expect(slice2.len == 0);
}

test "implicitly cast array of size 0 to slice" {
    var msg = [_]u8{};
    try assertLenIsZero(&msg);
}

fn assertLenIsZero(msg: []const u8) !void {
    try expect(msg.len == 0);
}

test "access len index of sentinel-terminated slice" {
    const S = struct {
        fn doTheTest() !void {
            var slice: [:0]const u8 = "hello";

            try expect(slice.len == 5);
            try expect(slice[5] == 0);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "comptime slice of slice preserves comptime var" {
    comptime {
        var buff: [10]u8 = undefined;
        buff[0..][0..][0] = 1;
        try expect(buff[0..][0..][0] == 1);
    }
}

test "slice of type" {
    comptime {
        var types_array = [_]type{ i32, f64, type };
        for (types_array) |T, i| {
            switch (i) {
                0 => try expect(T == i32),
                1 => try expect(T == f64),
                2 => try expect(T == type),
                else => unreachable,
            }
        }
        for (types_array[0..]) |T, i| {
            switch (i) {
                0 => try expect(T == i32),
                1 => try expect(T == f64),
                2 => try expect(T == type),
                else => unreachable,
            }
        }
    }
}
