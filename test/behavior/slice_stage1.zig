const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

test "slice string literal has correct type" {
    comptime {
        try expect(@TypeOf("aoeu"[0..]) == *const [4:0]u8);
        const array = [_]i32{ 1, 2, 3, 4 };
        try expect(@TypeOf(array[0..]) == *const [4]i32);
    }
    var runtime_zero: usize = 0;
    comptime try expect(@TypeOf("aoeu"[runtime_zero..]) == [:0]const u8);
    const array = [_]i32{ 1, 2, 3, 4 };
    comptime try expect(@TypeOf(array[runtime_zero..]) == []const i32);
}

test "result location zero sized array inside struct field implicit cast to slice" {
    const E = struct {
        entries: []u32,
    };
    var foo = E{ .entries = &[_]u32{} };
    try expect(foo.entries.len == 0);
}

const x = @intToPtr([*]i32, 0x1000)[0..0x500];
const y = x[0x100..];
test "compile time slice of pointer to hard coded address" {
    try expect(@ptrToInt(x) == 0x1000);
    try expect(x.len == 0x500);

    try expect(@ptrToInt(y) == 0x1100);
    try expect(y.len == 0x400);
}

test "runtime safety lets us slice from len..len" {
    var an_array = [_]u8{ 1, 2, 3 };
    try expect(mem.eql(u8, sliceFromLenToLen(an_array[0..], 3, 3), ""));
}

fn sliceFromLenToLen(a_slice: []u8, start: usize, end: usize) []u8 {
    return a_slice[start..end];
}

test "C pointer" {
    var buf: [*c]const u8 = "kjdhfkjdhfdkjhfkfjhdfkjdhfkdjhfdkjhf";
    var len: u32 = 10;
    var slice = buf[0..len];
    try expectEqualSlices(u8, "kjdhfkjdhf", slice);
}

test "C pointer slice access" {
    var buf: [10]u32 = [1]u32{42} ** 10;
    const c_ptr = @ptrCast([*c]const u32, &buf);

    var runtime_zero: usize = 0;
    comptime try expectEqual([]const u32, @TypeOf(c_ptr[runtime_zero..1]));
    comptime try expectEqual(*const [1]u32, @TypeOf(c_ptr[0..1]));

    for (c_ptr[0..5]) |*cl| {
        try expectEqual(@as(u32, 42), cl.*);
    }
}

fn sliceSum(comptime q: []const u8) i32 {
    comptime var result = 0;
    inline for (q) |item| {
        result += item;
    }
    return result;
}

test "comptime slices are disambiguated" {
    try expect(sliceSum(&[_]u8{ 1, 2 }) == 3);
    try expect(sliceSum(&[_]u8{ 3, 4 }) == 7);
}

test "slice type with custom alignment" {
    const LazilyResolvedType = struct {
        anything: i32,
    };
    var slice: []align(32) LazilyResolvedType = undefined;
    var array: [10]LazilyResolvedType align(32) = undefined;
    slice = &array;
    slice[1].anything = 42;
    try expect(array[1].anything == 42);
}

test "obtaining a null terminated slice" {
    // here we have a normal array
    var buf: [50]u8 = undefined;

    buf[0] = 'a';
    buf[1] = 'b';
    buf[2] = 'c';
    buf[3] = 0;

    // now we obtain a null terminated slice:
    const ptr = buf[0..3 :0];
    _ = ptr;

    var runtime_len: usize = 3;
    const ptr2 = buf[0..runtime_len :0];
    // ptr2 is a null-terminated slice
    comptime try expect(@TypeOf(ptr2) == [:0]u8);
    comptime try expect(@TypeOf(ptr2[0..2]) == *[2]u8);
    var runtime_zero: usize = 0;
    comptime try expect(@TypeOf(ptr2[runtime_zero..2]) == []u8);
}

test "empty array to slice" {
    const S = struct {
        fn doTheTest() !void {
            const empty: []align(16) u8 = &[_]u8{};
            const align_1: []align(1) u8 = empty;
            const align_4: []align(4) u8 = empty;
            const align_16: []align(16) u8 = empty;
            try expectEqual(1, @typeInfo(@TypeOf(align_1)).Pointer.alignment);
            try expectEqual(4, @typeInfo(@TypeOf(align_4)).Pointer.alignment);
            try expectEqual(16, @typeInfo(@TypeOf(align_16)).Pointer.alignment);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@ptrCast slice to pointer" {
    const S = struct {
        fn doTheTest() !void {
            var array align(@alignOf(u16)) = [5]u8{ 0xff, 0xff, 0xff, 0xff, 0xff };
            var slice: []u8 = &array;
            var ptr = @ptrCast(*u16, slice);
            try expect(ptr.* == 65535);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "slice syntax resulting in pointer-to-array" {
    const S = struct {
        fn doTheTest() !void {
            try testArray();
            try testArrayZ();
            try testArray0();
            try testArrayAlign();
            try testPointer();
            try testPointerZ();
            try testPointer0();
            try testPointerAlign();
            try testSlice();
            try testSliceZ();
            try testSlice0();
            try testSliceOpt();
            try testSliceAlign();
        }

        fn testArray() !void {
            var array = [5]u8{ 1, 2, 3, 4, 5 };
            var slice = array[1..3];
            comptime try expect(@TypeOf(slice) == *[2]u8);
            try expect(slice[0] == 2);
            try expect(slice[1] == 3);
        }

        fn testArrayZ() !void {
            var array = [5:0]u8{ 1, 2, 3, 4, 5 };
            comptime try expect(@TypeOf(array[1..3]) == *[2]u8);
            comptime try expect(@TypeOf(array[1..5]) == *[4:0]u8);
            comptime try expect(@TypeOf(array[1..]) == *[4:0]u8);
            comptime try expect(@TypeOf(array[1..3 :4]) == *[2:4]u8);
        }

        fn testArray0() !void {
            {
                var array = [0]u8{};
                var slice = array[0..0];
                comptime try expect(@TypeOf(slice) == *[0]u8);
            }
            {
                var array = [0:0]u8{};
                var slice = array[0..0];
                comptime try expect(@TypeOf(slice) == *[0:0]u8);
                try expect(slice[0] == 0);
            }
        }

        fn testArrayAlign() !void {
            var array align(4) = [5]u8{ 1, 2, 3, 4, 5 };
            var slice = array[4..5];
            comptime try expect(@TypeOf(slice) == *align(4) [1]u8);
            try expect(slice[0] == 5);
            comptime try expect(@TypeOf(array[0..2]) == *align(4) [2]u8);
        }

        fn testPointer() !void {
            var array = [5]u8{ 1, 2, 3, 4, 5 };
            var pointer: [*]u8 = &array;
            var slice = pointer[1..3];
            comptime try expect(@TypeOf(slice) == *[2]u8);
            try expect(slice[0] == 2);
            try expect(slice[1] == 3);
        }

        fn testPointerZ() !void {
            var array = [5:0]u8{ 1, 2, 3, 4, 5 };
            var pointer: [*:0]u8 = &array;
            comptime try expect(@TypeOf(pointer[1..3]) == *[2]u8);
            comptime try expect(@TypeOf(pointer[1..3 :4]) == *[2:4]u8);
        }

        fn testPointer0() !void {
            var pointer: [*]const u0 = &[1]u0{0};
            var slice = pointer[0..1];
            comptime try expect(@TypeOf(slice) == *const [1]u0);
            try expect(slice[0] == 0);
        }

        fn testPointerAlign() !void {
            var array align(4) = [5]u8{ 1, 2, 3, 4, 5 };
            var pointer: [*]align(4) u8 = &array;
            var slice = pointer[4..5];
            comptime try expect(@TypeOf(slice) == *align(4) [1]u8);
            try expect(slice[0] == 5);
            comptime try expect(@TypeOf(pointer[0..2]) == *align(4) [2]u8);
        }

        fn testSlice() !void {
            var array = [5]u8{ 1, 2, 3, 4, 5 };
            var src_slice: []u8 = &array;
            var slice = src_slice[1..3];
            comptime try expect(@TypeOf(slice) == *[2]u8);
            try expect(slice[0] == 2);
            try expect(slice[1] == 3);
        }

        fn testSliceZ() !void {
            var array = [5:0]u8{ 1, 2, 3, 4, 5 };
            var slice: [:0]u8 = &array;
            comptime try expect(@TypeOf(slice[1..3]) == *[2]u8);
            comptime try expect(@TypeOf(slice[1..]) == [:0]u8);
            comptime try expect(@TypeOf(slice[1..3 :4]) == *[2:4]u8);
        }

        fn testSliceOpt() !void {
            var array: [2]u8 = [2]u8{ 1, 2 };
            var slice: ?[]u8 = &array;
            comptime try expect(@TypeOf(&array, slice) == ?[]u8);
            comptime try expect(@TypeOf(slice.?[0..2]) == *[2]u8);
        }

        fn testSlice0() !void {
            {
                var array = [0]u8{};
                var src_slice: []u8 = &array;
                var slice = src_slice[0..0];
                comptime try expect(@TypeOf(slice) == *[0]u8);
            }
            {
                var array = [0:0]u8{};
                var src_slice: [:0]u8 = &array;
                var slice = src_slice[0..0];
                comptime try expect(@TypeOf(slice) == *[0]u8);
            }
        }

        fn testSliceAlign() !void {
            var array align(4) = [5]u8{ 1, 2, 3, 4, 5 };
            var src_slice: []align(4) u8 = &array;
            var slice = src_slice[4..5];
            comptime try expect(@TypeOf(slice) == *align(4) [1]u8);
            try expect(slice[0] == 5);
            comptime try expect(@TypeOf(src_slice[0..2]) == *align(4) [2]u8);
        }

        fn testConcatStrLiterals() !void {
            try expectEqualSlices("a"[0..] ++ "b"[0..], "ab");
            try expectEqualSlices("a"[0.. :0] ++ "b"[0.. :0], "ab");
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "type coercion of pointer to anon struct literal to pointer to slice" {
    const S = struct {
        const U = union {
            a: u32,
            b: bool,
            c: []const u8,
        };

        fn doTheTest() !void {
            var x1: u8 = 42;
            const t1 = &.{ x1, 56, 54 };
            var slice1: []const u8 = t1;
            try expect(slice1.len == 3);
            try expect(slice1[0] == 42);
            try expect(slice1[1] == 56);
            try expect(slice1[2] == 54);

            var x2: []const u8 = "hello";
            const t2 = &.{ x2, ", ", "world!" };
            // @compileLog(@TypeOf(t2));
            var slice2: []const []const u8 = t2;
            try expect(slice2.len == 3);
            try expect(mem.eql(u8, slice2[0], "hello"));
            try expect(mem.eql(u8, slice2[1], ", "));
            try expect(mem.eql(u8, slice2[2], "world!"));
        }
    };
    // try S.doTheTest();
    comptime try S.doTheTest();
}

test "array concat of slices gives slice" {
    comptime {
        var a: []const u8 = "aoeu";
        var b: []const u8 = "asdf";
        const c = a ++ b;
        try expect(std.mem.eql(u8, c, "aoeuasdf"));
    }
}

test "slice bounds in comptime concatenation" {
    const bs = comptime blk: {
        const b = "........1........";
        break :blk b[8..9];
    };
    const str = "" ++ bs;
    try expect(str.len == 1);
    try expect(std.mem.eql(u8, str, "1"));

    const str2 = bs ++ "";
    try expect(str2.len == 1);
    try expect(std.mem.eql(u8, str2, "1"));
}
