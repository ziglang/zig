const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "array to slice" {
    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    const a_slice: []align(1) const u32 = @as(*const [1]u32, &a)[0..];
    const b_slice: []align(1) const u32 = @as(*const [1]u32, &b)[0..];
    try expect(a_slice[0] + b_slice[0] == 7);

    const d: []const u32 = &[2]u32{ 1, 2 };
    const e: []const u32 = &[3]u32{ 3, 4, 5 };
    try expect(d[0] + e[0] + d[1] + e[1] == 10);
}

test "arrays" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var array: [5]u32 = undefined;

    var i: u32 = 0;
    while (i < 5) {
        array[i] = i + 1;
        i = array[i];
    }

    i = 0;
    var accumulator = @as(u32, 0);
    while (i < 5) {
        accumulator += array[i];

        i += 1;
    }

    try expect(accumulator == 15);
    try expect(getArrayLen(&array) == 5);
}
fn getArrayLen(a: []const u32) usize {
    return a.len;
}

test "array concat with undefined" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            {
                var array = "hello".* ++ @as([5]u8, undefined);
                array[5..10].* = "world".*;
                try std.testing.expect(std.mem.eql(u8, &array, "helloworld"));
            }
            {
                var array = @as([5]u8, undefined) ++ "world".*;
                array[0..5].* = "hello".*;
                try std.testing.expect(std.mem.eql(u8, &array, "helloworld"));
            }
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "array concat with tuple" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const array: [2]u8 = .{ 1, 2 };
    {
        const seq = array ++ .{ 3, 4 };
        try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, &seq);
    }
    {
        const seq = .{ 3, 4 } ++ array;
        try std.testing.expectEqualSlices(u8, &.{ 3, 4, 1, 2 }, &seq);
    }
}

test "array init with concat" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const a = 'a';
    var i: [4]u8 = [2]u8{ a, 'b' } ++ [2]u8{ 'c', 'd' };
    try expect(std.mem.eql(u8, &i, "abcd"));
}

test "array init with mult" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a = 'a';
    var i: [8]u8 = [2]u8{ a, 'b' } ** 4;
    try expect(std.mem.eql(u8, &i, "abababab"));

    var j: [4]u8 = [1]u8{'a'} ** 4;
    try expect(std.mem.eql(u8, &j, "aaaa"));
}

test "array literal with explicit type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const hex_mult: [4]u16 = .{ 4096, 256, 16, 1 };

    try expect(hex_mult.len == 4);
    try expect(hex_mult[1] == 256);
}

test "array literal with inferred length" {
    const hex_mult = [_]u16{ 4096, 256, 16, 1 };

    try expect(hex_mult.len == 4);
    try expect(hex_mult[1] == 256);
}

test "array dot len const expr" {
    try expect(comptime x: {
        break :x some_array.len == 4;
    });
}

const ArrayDotLenConstExpr = struct {
    y: [some_array.len]u8,
};
const some_array = [_]u8{ 0, 1, 2, 3 };

test "array literal with specified size" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var array = [2]u8{ 1, 2 };
    _ = &array;
    try expect(array[0] == 1);
    try expect(array[1] == 2);
}

test "array len field" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var arr = [4]u8{ 0, 0, 0, 0 };
    const ptr = &arr;
    try expect(arr.len == 4);
    comptime assert(arr.len == 4);
    try expect(ptr.len == 4);
    comptime assert(ptr.len == 4);
    try expect(@TypeOf(arr.len) == usize);
}

test "array with sentinels" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(is_ct: bool) !void {
            {
                var zero_sized: [0:0xde]u8 = [_:0xde]u8{};
                try expect(zero_sized[0] == 0xde);
                var reinterpreted: *[1]u8 = @ptrCast(&zero_sized);
                _ = &reinterpreted;
                try expect(reinterpreted[0] == 0xde);
            }
            var arr: [3:0x55]u8 = undefined;
            // Make sure the sentinel pointer is pointing after the last element.
            if (!is_ct) {
                const sentinel_ptr = @intFromPtr(&arr[3]);
                const last_elem_ptr = @intFromPtr(&arr[2]);
                try expect((sentinel_ptr - last_elem_ptr) == 1);
            }
            // Make sure the sentinel is writeable.
            arr[3] = 0x55;
        }
    };

    try S.doTheTest(false);
    try comptime S.doTheTest(true);
}

test "void arrays" {
    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    try expect(@sizeOf(@TypeOf(array)) == 0);
    try expect(array.len == 4);
}

test "nested arrays of strings" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const array_of_strings = [_][]const u8{ "hello", "this", "is", "my", "thing" };
    for (array_of_strings, 0..) |s, i| {
        if (i == 0) try expect(mem.eql(u8, s, "hello"));
        if (i == 1) try expect(mem.eql(u8, s, "this"));
        if (i == 2) try expect(mem.eql(u8, s, "is"));
        if (i == 3) try expect(mem.eql(u8, s, "my"));
        if (i == 4) try expect(mem.eql(u8, s, "thing"));
    }
}

test "nested arrays of integers" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const array_of_numbers = [_][2]u8{
        [2]u8{ 1, 2 },
        [2]u8{ 3, 4 },
    };

    try expect(array_of_numbers[0][0] == 1);
    try expect(array_of_numbers[0][1] == 2);
    try expect(array_of_numbers[1][0] == 3);
    try expect(array_of_numbers[1][1] == 4);
}

test "implicit comptime in array type size" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var arr: [plusOne(10)]bool = undefined;
    _ = &arr;
    try expect(arr.len == 11);
}

fn plusOne(x: u32) u32 {
    return x + 1;
}

test "single-item pointer to array indexing and slicing" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testSingleItemPtrArrayIndexSlice();
    try comptime testSingleItemPtrArrayIndexSlice();
}

fn testSingleItemPtrArrayIndexSlice() !void {
    {
        var array: [4]u8 = "aaaa".*;
        doSomeMangling(&array);
        try expect(mem.eql(u8, "azya", &array));
    }
    {
        var array = "aaaa".*;
        doSomeMangling(&array);
        try expect(mem.eql(u8, "azya", &array));
    }
}

fn doSomeMangling(array: *[4]u8) void {
    array[1] = 'z';
    array[2..3][0] = 'y';
}

test "implicit cast zero sized array ptr to slice" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    {
        var b = "".*;
        const c: []const u8 = &b;
        try expect(c.len == 0);
    }
    {
        var b: [0]u8 = "".*;
        const c: []const u8 = &b;
        try expect(c.len == 0);
    }
}

test "anonymous list literal syntax" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array: [4]u8 = .{ 1, 2, 3, 4 };
            _ = &array;
            try expect(array[0] == 1);
            try expect(array[1] == 2);
            try expect(array[2] == 3);
            try expect(array[3] == 4);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

var s_array: [8]Sub = undefined;
const Sub = struct { b: u8 };
const Str = struct { a: []Sub };
test "set global var array via slice embedded in struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var s = Str{ .a = s_array[0..] };

    s.a[0].b = 1;
    s.a[1].b = 2;
    s.a[2].b = 3;

    try expect(s_array[0].b == 1);
    try expect(s_array[1].b == 2);
    try expect(s_array[2].b == 3);
}

test "read/write through global variable array of struct fields initialized via array mult" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testImplicitCastSingleItemPtr();
    try comptime testImplicitCastSingleItemPtr();
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const arr = [_]u8{ 1, 2 };
    const x = comptime testArrayByValAtComptime(arr);
    const y = comptime testArrayByValAtComptime(arr);
    try expect(x == 1);
    try expect(y == 1);
}

test "runtime initialize array elem and then implicit cast to slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var two: i32 = 2;
    _ = &two;
    const x: []const i32 = &[_]i32{two};
    try expect(x[0] == 2);
}

test "array literal as argument to function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime S.entry(2);
}

test "double nested array to const slice cast in array literal" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime S.entry(2);
}

test "anonymous literal in array" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
            _ = &array;
            try expect(array[0].a == 3);
            try expect(array[0].b == 4);
            try expect(array[1].a == 2);
            try expect(array[1].b == 3);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "access the null element of a null terminated array" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array: [4:0]u8 = .{ 'a', 'o', 'e', 'u' };
            _ = &array;
            try expect(array[4] == 0);
            var len: usize = 4;
            _ = &len;
            try expect(array[len] == 0);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "type deduction for array subscript expression" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var array = [_]u8{ 0x55, 0xAA };
            var v0 = true;
            try expect(@as(u8, 0xAA) == array[if (v0) 1 else 0]);
            var v1 = false;
            try expect(@as(u8, 0x55) == array[if (v1) 1 else 0]);
            _ = .{ &array, &v0, &v1 };
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "sentinel element count towards the ABI size calculation" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            const T = extern struct {
                fill_pre: u8 = 0x55,
                data: [0:0]u8 = undefined,
                fill_post: u8 = 0xAA,
            };
            var x = T{};
            const as_slice = mem.asBytes(&x);
            try expect(@as(usize, 3) == as_slice.len);
            try expect(@as(u8, 0x55) == as_slice[0]);
            try expect(@as(u8, 0xAA) == as_slice[2]);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "zero-sized array with recursive type definition" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    _ = &t;
    try expect(@as(usize, 0) == t.list.x);
}

test "type coercion of anon struct literal to array" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        const U = union {
            a: u32,
            b: bool,
            c: []const u8,
        };

        fn doTheTest() !void {
            var x1: u8 = 42;
            _ = &x1;
            const t1 = .{ x1, 56, 54 };
            const arr1: [3]u8 = t1;
            try expect(arr1[0] == 42);
            try expect(arr1[1] == 56);
            try expect(arr1[2] == 54);

            var x2: U = .{ .a = 42 };
            _ = &x2;
            const t2 = .{ x2, .{ .b = true }, .{ .c = "hello" } };
            const arr2: [3]U = t2;
            try expect(arr2[0].a == 42);
            try expect(arr2[1].b == true);
            try expect(mem.eql(u8, arr2[2].c, "hello"));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "type coercion of pointer to anon struct literal to pointer to array" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const U = union {
            a: u32,
            b: bool,
            c: []const u8,
        };

        fn doTheTest() !void {
            var x1: u8 = 42;
            _ = &x1;
            const t1 = &.{ x1, 56, 54 };
            const arr1: *const [3]u8 = t1;
            try expect(arr1[0] == 42);
            try expect(arr1[1] == 56);
            try expect(arr1[2] == 54);

            var x2: U = .{ .a = 42 };
            _ = &x2;
            const t2 = &.{ x2, .{ .b = true }, .{ .c = "hello" } };
            const arr2: *const [3]U = t2;
            try expect(arr2[0].a == 42);
            try expect(arr2[1].b == true);
            try expect(mem.eql(u8, arr2[2].c, "hello"));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "array with comptime-only element type" {
    const a = [_]type{ u32, i32 };
    try testing.expect(a[0] == u32);
    try testing.expect(a[1] == i32);
}

test "tuple to array handles sentinel" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const a = .{ 1, 2, 3 };
        var b: [3:0]u8 = a;
    };
    try expect(S.b[0] == 1);
}

test "array init of container level array variable" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        var pair: [2]usize = .{ 1, 2 };
        noinline fn foo(x: usize, y: usize) void {
            pair = [2]usize{ x, y };
        }
        noinline fn bar(x: usize, y: usize) void {
            var tmp: [2]usize = .{ x, y };
            _ = &tmp;
            pair = tmp;
        }
    };
    try expectEqual([2]usize{ 1, 2 }, S.pair);
    S.foo(3, 4);
    try expectEqual([2]usize{ 3, 4 }, S.pair);
    S.bar(5, 6);
    try expectEqual([2]usize{ 5, 6 }, S.pair);
}

test "runtime initialized sentinel-terminated array literal" {
    var c: u16 = 300;
    _ = &c;
    const f = &[_:0x9999]u16{c};
    const g = @as(*const [4]u8, @ptrCast(f));
    try std.testing.expect(g[2] == 0x99);
    try std.testing.expect(g[3] == 0x99);
}

test "array of array agregate init" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var a = [1]u32{11} ** 10;
    var b = [1][10]u32{a} ** 2;
    _ = .{ &a, &b };
    try std.testing.expect(b[1][1] == 11);
}

test "pointer to array has ptr field" {
    const arr: *const [5]u32 = &.{ 10, 20, 30, 40, 50 };
    try std.testing.expect(arr.ptr == @as([*]const u32, arr));
    try std.testing.expect(arr.ptr[0] == 10);
    try std.testing.expect(arr.ptr[1] == 20);
    try std.testing.expect(arr.ptr[2] == 30);
    try std.testing.expect(arr.ptr[3] == 40);
    try std.testing.expect((&arr.ptr).*[4] == 50);
}

test "discarded array init preserves result location" {
    const S = struct {
        fn f(p: *u32) u16 {
            p.* += 1;
            return 0;
        }
    };

    var x: u32 = 0;
    _ = [2]u8{
        @intCast(S.f(&x)),
        @intCast(S.f(&x)),
    };

    // Ensure function was run
    try expect(x == 2);
}

test "array init with no result location has result type" {
    const x = .{ .foo = [2]u16{
        @intCast(10),
        @intCast(20),
    } };

    try expect(x.foo.len == 2);
    try expect(x.foo[0] == 10);
    try expect(x.foo[1] == 20);
}

test "slicing array of zero-sized values" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var arr: [32]u0 = undefined;
    for (arr[0..]) |*zero|
        zero.* = 0;
    for (arr[0..]) |zero|
        try expect(zero == 0);
}

test "array init with no result pointer sets field result types" {
    const S = struct {
        // A function parameter has a result type, but no result pointer.
        fn f(arr: [1]u32) u32 {
            return arr[0];
        }
    };

    const x: u64 = 123;
    const y = S.f(.{@intCast(x)});

    try expect(y == x);
}

test "runtime side-effects in comptime-known array init" {
    var side_effects: u4 = 0;
    const init = [4]u4{
        blk: {
            side_effects += 1;
            break :blk 1;
        },
        blk: {
            side_effects += 2;
            break :blk 2;
        },
        blk: {
            side_effects += 4;
            break :blk 4;
        },
        blk: {
            side_effects += 8;
            break :blk 8;
        },
    };
    try expectEqual([4]u4{ 1, 2, 4, 8 }, init);
    try expectEqual(@as(u4, std.math.maxInt(u4)), side_effects);
}

test "slice initialized through reference to anonymous array init provides result types" {
    var my_u32: u32 = 123;
    var my_u64: u64 = 456;
    _ = .{ &my_u32, &my_u64 };
    const foo: []const u16 = &.{
        @intCast(my_u32),
        @intCast(my_u64),
        @truncate(my_u32),
        @truncate(my_u64),
    };
    try std.testing.expectEqualSlices(u16, &.{ 123, 456, 123, 456 }, foo);
}

test "sentinel-terminated slice initialized through reference to anonymous array init provides result types" {
    var my_u32: u32 = 123;
    var my_u64: u64 = 456;
    _ = .{ &my_u32, &my_u64 };
    const foo: [:999]const u16 = &.{
        @intCast(my_u32),
        @intCast(my_u64),
        @truncate(my_u32),
        @truncate(my_u64),
    };
    try std.testing.expectEqualSentinel(u16, 999, &.{ 123, 456, 123, 456 }, foo);
}

test "many-item pointer initialized through reference to anonymous array init provides result types" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var my_u32: u32 = 123;
    var my_u64: u64 = 456;
    _ = .{ &my_u32, &my_u64 };
    const foo: [*]const u16 = &.{
        @intCast(my_u32),
        @intCast(my_u64),
        @truncate(my_u32),
        @truncate(my_u64),
    };
    try expectEqual(123, foo[0]);
    try expectEqual(456, foo[1]);
    try expectEqual(123, foo[2]);
    try expectEqual(456, foo[3]);
}

test "many-item sentinel-terminated pointer initialized through reference to anonymous array init provides result types" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var my_u32: u32 = 123;
    var my_u64: u64 = 456;
    _ = .{ &my_u32, &my_u64 };
    const foo: [*:999]const u16 = &.{
        @intCast(my_u32),
        @intCast(my_u64),
        @truncate(my_u32),
        @truncate(my_u64),
    };
    try expectEqual(123, foo[0]);
    try expectEqual(456, foo[1]);
    try expectEqual(123, foo[2]);
    try expectEqual(456, foo[3]);
    try expectEqual(999, foo[4]);
}

test "pointer to array initialized through reference to anonymous array init provides result types" {
    var my_u32: u32 = 123;
    var my_u64: u64 = 456;
    _ = .{ &my_u32, &my_u64 };
    const foo: *const [4]u16 = &.{
        @intCast(my_u32),
        @intCast(my_u64),
        @truncate(my_u32),
        @truncate(my_u64),
    };
    try std.testing.expectEqualSlices(u16, &.{ 123, 456, 123, 456 }, foo);
}

test "pointer to sentinel-terminated array initialized through reference to anonymous array init provides result types" {
    var my_u32: u32 = 123;
    var my_u64: u64 = 456;
    _ = .{ &my_u32, &my_u64 };
    const foo: *const [4:999]u16 = &.{
        @intCast(my_u32),
        @intCast(my_u64),
        @truncate(my_u32),
        @truncate(my_u64),
    };
    try std.testing.expectEqualSentinel(u16, 999, &.{ 123, 456, 123, 456 }, foo);
}

test "tuple initialized through reference to anonymous array init provides result types" {
    const Tuple = struct { u64, *const u32 };
    const foo: *const Tuple = &.{
        @intCast(12345),
        @ptrFromInt(0x1000),
    };
    try expect(foo[0] == 12345);
    try expect(@intFromPtr(foo[1]) == 0x1000);
}

test "copied array element doesn't alias source" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: [10][10]u32 = undefined;

    x[0][1] = 0;
    const a = x[0];
    x[0][1] = 15;

    try expect(a[1] == 0);
}

test "array initialized with string literal" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        a: u32,
        c: [5]u8,
    };
    const U = union {
        s: S,
    };
    const s_1 = S{
        .a = undefined,
        .c = "12345".*, // this caused problems
    };

    var u_2 = U{ .s = s_1 };
    _ = &u_2;
    try std.testing.expectEqualStrings("12345", &u_2.s.c);
}

test "array initialized with array with sentinel" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        a: u32,
        c: [5]u8,
    };
    const U = union {
        s: S,
    };
    const c = [5:0]u8{ 1, 2, 3, 4, 5 };
    const s_1 = S{
        .a = undefined,
        .c = c, // this caused problems
    };
    var u_2 = U{ .s = s_1 };
    _ = &u_2;
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5 }, &u_2.s.c);
}

test "store array of array of structs at comptime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn storeArrayOfArrayOfStructs() u8 {
            const S = struct {
                x: u8,
            };

            var cases = [_][1]S{
                [_]S{
                    S{ .x = 15 },
                },
            };
            _ = &cases;
            return cases[0][0].x;
        }
    };

    try expect(S.storeArrayOfArrayOfStructs() == 15);
    comptime assert(S.storeArrayOfArrayOfStructs() == 15);
}

test "accessing multidimensional global array at comptime" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        const array = [_][]const []const u8{
            &.{"hello"},
            &.{ "world", "hello" },
        };
    };

    try std.testing.expect(S.array[0].len == 1);
    try std.testing.expectEqualStrings("hello", S.array[0][0]);
}

test "union that needs padding bytes inside an array" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const B = union(enum) {
        D: u8,
        E: u16,
    };
    const A = union(enum) {
        B: B,
        C: u8,
    };
    var as = [_]A{
        A{ .B = B{ .D = 1 } },
        A{ .B = B{ .D = 1 } },
    };
    _ = &as;

    const a = as[0].B;
    try std.testing.expect(a.D == 1);
}

test "runtime index of array of zero-bit values" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var runtime: struct { array: [1]void, index: usize } = undefined;
    runtime = .{ .array = .{{}}, .index = 0 };
    const result = struct { index: usize, value: void }{
        .index = runtime.index,
        .value = runtime.array[runtime.index],
    };
    try std.testing.expect(result.index == 0);
    try std.testing.expect(result.value == {});
}
