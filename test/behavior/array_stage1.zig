const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "access the null element of a null terminated array" {
    const S = struct {
        fn doTheTest() !void {
            var array: [4:0]u8 = .{ 'a', 'o', 'e', 'u' };
            try expect(array[4] == 0);
            var len: usize = 4;
            try expect(array[len] == 0);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "type deduction for array subscript expression" {
    const S = struct {
        fn doTheTest() !void {
            var array = [_]u8{ 0x55, 0xAA };
            var v0 = true;
            try expect(@as(u8, 0xAA) == array[if (v0) 1 else 0]);
            var v1 = false;
            try expect(@as(u8, 0x55) == array[if (v1) 1 else 0]);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "sentinel element count towards the ABI size calculation" {
    const S = struct {
        fn doTheTest() !void {
            const T = packed struct {
                fill_pre: u8 = 0x55,
                data: [0:0]u8 = undefined,
                fill_post: u8 = 0xAA,
            };
            var x = T{};
            var as_slice = mem.asBytes(&x);
            try expect(@as(usize, 3) == as_slice.len);
            try expect(@as(u8, 0x55) == as_slice[0]);
            try expect(@as(u8, 0xAA) == as_slice[2]);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "zero-sized array with recursive type definition" {
    const U = struct {
        fn foo(comptime T: type, comptime n: usize) type {
            return struct {
                s: [n]T,
                x: usize = n,
            };
        }
    };

    const S = struct {
        list: U.foo(@This(), 0),
    };

    var t: S = .{ .list = .{ .s = undefined } };
    try expect(@as(usize, 0) == t.list.x);
}

test "type coercion of anon struct literal to array" {
    const S = struct {
        const U = union {
            a: u32,
            b: bool,
            c: []const u8,
        };

        fn doTheTest() !void {
            var x1: u8 = 42;
            const t1 = .{ x1, 56, 54 };
            var arr1: [3]u8 = t1;
            try expect(arr1[0] == 42);
            try expect(arr1[1] == 56);
            try expect(arr1[2] == 54);

            var x2: U = .{ .a = 42 };
            const t2 = .{ x2, .{ .b = true }, .{ .c = "hello" } };
            var arr2: [3]U = t2;
            try expect(arr2[0].a == 42);
            try expect(arr2[1].b == true);
            try expect(mem.eql(u8, arr2[2].c, "hello"));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "type coercion of pointer to anon struct literal to pointer to array" {
    const S = struct {
        const U = union {
            a: u32,
            b: bool,
            c: []const u8,
        };

        fn doTheTest() !void {
            var x1: u8 = 42;
            const t1 = &.{ x1, 56, 54 };
            var arr1: *const [3]u8 = t1;
            try expect(arr1[0] == 42);
            try expect(arr1[1] == 56);
            try expect(arr1[2] == 54);

            var x2: U = .{ .a = 42 };
            const t2 = &.{ x2, .{ .b = true }, .{ .c = "hello" } };
            var arr2: *const [3]U = t2;
            try expect(arr2[0].a == 42);
            try expect(arr2[1].b == true);
            try expect(mem.eql(u8, arr2[2].c, "hello"));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
