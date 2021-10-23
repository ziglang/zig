const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const mem = std.mem;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "arrays" {
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

test "array init with mult" {
    const a = 'a';
    var i: [8]u8 = [2]u8{ a, 'b' } ** 4;
    try expect(std.mem.eql(u8, &i, "abababab"));

    var j: [4]u8 = [1]u8{'a'} ** 4;
    try expect(std.mem.eql(u8, &j, "aaaa"));
}

test "array literal with explicit type" {
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
    var array = [2]u8{ 1, 2 };
    try expect(array[0] == 1);
    try expect(array[1] == 2);
}

test "array len field" {
    var arr = [4]u8{ 0, 0, 0, 0 };
    var ptr = &arr;
    try expect(arr.len == 4);
    comptime try expect(arr.len == 4);
    try expect(ptr.len == 4);
    comptime try expect(ptr.len == 4);
}

test "array with sentinels" {
    const S = struct {
        fn doTheTest(is_ct: bool) !void {
            if (is_ct or builtin.zig_is_stage2) {
                var zero_sized: [0:0xde]u8 = [_:0xde]u8{};
                // Stage1 test coverage disabled at runtime because of
                // https://github.com/ziglang/zig/issues/4372
                try expect(zero_sized[0] == 0xde);
                var reinterpreted = @ptrCast(*[1]u8, &zero_sized);
                try expect(reinterpreted[0] == 0xde);
            }
            var arr: [3:0x55]u8 = undefined;
            // Make sure the sentinel pointer is pointing after the last element.
            if (!is_ct) {
                const sentinel_ptr = @ptrToInt(&arr[3]);
                const last_elem_ptr = @ptrToInt(&arr[2]);
                try expect((sentinel_ptr - last_elem_ptr) == 1);
            }
            // Make sure the sentinel is writeable.
            arr[3] = 0x55;
        }
    };

    try S.doTheTest(false);
    comptime try S.doTheTest(true);
}

test "void arrays" {
    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    try expect(@sizeOf(@TypeOf(array)) == 0);
    try expect(array.len == 4);
}

test "nested arrays" {
    const array_of_strings = [_][]const u8{ "hello", "this", "is", "my", "thing" };
    for (array_of_strings) |s, i| {
        if (i == 0) try expect(mem.eql(u8, s, "hello"));
        if (i == 1) try expect(mem.eql(u8, s, "this"));
        if (i == 2) try expect(mem.eql(u8, s, "is"));
        if (i == 3) try expect(mem.eql(u8, s, "my"));
        if (i == 4) try expect(mem.eql(u8, s, "thing"));
    }
}

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

test "implicit comptime in array type size" {
    var arr: [plusOne(10)]bool = undefined;
    try expect(arr.len == 11);
}

fn plusOne(x: u32) u32 {
    return x + 1;
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
