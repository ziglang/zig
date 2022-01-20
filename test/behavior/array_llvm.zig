const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const mem = std.mem;

var s_array: [8]Sub = undefined;
const Sub = struct { b: u8 };
const Str = struct { a: []Sub };
test "set global var array via slice embedded in struct" {
    var s = Str{ .a = s_array[0..] };

    s.a[0].b = 1;
    s.a[1].b = 2;
    s.a[2].b = 3;

    try expect(s_array[0].b == 1);
    try expect(s_array[1].b == 2);
    try expect(s_array[2].b == 3);
}

test "read/write through global variable array of struct fields initialized via array mult" {
    const S = struct {
        fn doTheTest() !void {
            try expect(storage[0].term == 1);
            storage[0] = MyStruct{ .term = 123 };
            try expect(storage[0].term == 123);
        }

        pub const MyStruct = struct {
            term: usize,
        };

        var storage: [1]MyStruct = [_]MyStruct{MyStruct{ .term = 1 }} ** 1;
    };
    try S.doTheTest();
}

test "implicit cast single-item pointer" {
    try testImplicitCastSingleItemPtr();
    comptime try testImplicitCastSingleItemPtr();
}

fn testImplicitCastSingleItemPtr() !void {
    var byte: u8 = 100;
    const slice = @as(*[1]u8, &byte)[0..];
    slice[0] += 1;
    try expect(byte == 101);
}

fn testArrayByValAtComptime(b: [2]u8) u8 {
    return b[0];
}

test "comptime evaluating function that takes array by value" {
    const arr = [_]u8{ 1, 2 };
    const x = comptime testArrayByValAtComptime(arr);
    const y = comptime testArrayByValAtComptime(arr);
    try expect(x == 1);
    try expect(y == 1);
}

test "runtime initialize array elem and then implicit cast to slice" {
    var two: i32 = 2;
    const x: []const i32 = &[_]i32{two};
    try expect(x[0] == 2);
}

test "array literal as argument to function" {
    const S = struct {
        fn entry(two: i32) !void {
            try foo(&[_]i32{ 1, 2, 3 });
            try foo(&[_]i32{ 1, two, 3 });
            try foo2(true, &[_]i32{ 1, 2, 3 });
            try foo2(true, &[_]i32{ 1, two, 3 });
        }
        fn foo(x: []const i32) !void {
            try expect(x[0] == 1);
            try expect(x[1] == 2);
            try expect(x[2] == 3);
        }
        fn foo2(trash: bool, x: []const i32) !void {
            try expect(trash);
            try expect(x[0] == 1);
            try expect(x[1] == 2);
            try expect(x[2] == 3);
        }
    };
    try S.entry(2);
    comptime try S.entry(2);
}

test "double nested array to const slice cast in array literal" {
    const S = struct {
        fn entry(two: i32) !void {
            const cases = [_][]const []const i32{
                &[_][]const i32{&[_]i32{1}},
                &[_][]const i32{&[_]i32{ 2, 3 }},
                &[_][]const i32{
                    &[_]i32{4},
                    &[_]i32{ 5, 6, 7 },
                },
            };
            try check(&cases);

            const cases2 = [_][]const i32{
                &[_]i32{1},
                &[_]i32{ two, 3 },
            };
            try expect(cases2.len == 2);
            try expect(cases2[0].len == 1);
            try expect(cases2[0][0] == 1);
            try expect(cases2[1].len == 2);
            try expect(cases2[1][0] == 2);
            try expect(cases2[1][1] == 3);

            const cases3 = [_][]const []const i32{
                &[_][]const i32{&[_]i32{1}},
                &[_][]const i32{&[_]i32{ two, 3 }},
                &[_][]const i32{
                    &[_]i32{4},
                    &[_]i32{ 5, 6, 7 },
                },
            };
            try check(&cases3);
        }

        fn check(cases: []const []const []const i32) !void {
            try expect(cases.len == 3);
            try expect(cases[0].len == 1);
            try expect(cases[0][0].len == 1);
            try expect(cases[0][0][0] == 1);
            try expect(cases[1].len == 1);
            try expect(cases[1][0].len == 2);
            try expect(cases[1][0][0] == 2);
            try expect(cases[1][0][1] == 3);
            try expect(cases[2].len == 2);
            try expect(cases[2][0].len == 1);
            try expect(cases[2][0][0] == 4);
            try expect(cases[2][1].len == 3);
            try expect(cases[2][1][0] == 5);
            try expect(cases[2][1][1] == 6);
            try expect(cases[2][1][2] == 7);
        }
    };
    try S.entry(2);
    comptime try S.entry(2);
}

test "anonymous literal in array" {
    const S = struct {
        const Foo = struct {
            a: usize = 2,
            b: usize = 4,
        };
        fn doTheTest() !void {
            var array: [2]Foo = .{
                .{ .a = 3 },
                .{ .b = 3 },
            };
            try expect(array[0].a == 3);
            try expect(array[0].b == 4);
            try expect(array[1].a == 2);
            try expect(array[1].b == 3);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

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
    if (@import("builtin").zig_backend == .stage2_llvm) return error.SkipZigTest; // TODO

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
    if (@import("builtin").zig_backend == .stage2_llvm) return error.SkipZigTest; // TODO

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

            if (@import("builtin").zig_backend == .stage2_llvm) return error.SkipZigTest; // TODO

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
    if (@import("builtin").zig_backend == .stage2_llvm) return error.SkipZigTest; // TODO

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
