const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

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
