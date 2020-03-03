const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

const x = @intToPtr([*]i32, 0x1000)[0..0x500];
const y = x[0x100..];
test "compile time slice of pointer to hard coded address" {
    expect(@ptrToInt(x.ptr) == 0x1000);
    expect(x.len == 0x500);

    expect(@ptrToInt(y.ptr) == 0x1100);
    expect(y.len == 0x400);
}

test "runtime safety lets us slice from len..len" {
    var an_array = [_]u8{
        1,
        2,
        3,
    };
    expect(mem.eql(u8, sliceFromLenToLen(an_array[0..], 3, 3), ""));
}

fn sliceFromLenToLen(a_slice: []u8, start: usize, end: usize) []u8 {
    return a_slice[start..end];
}

test "implicitly cast array of size 0 to slice" {
    var msg = [_]u8{};
    assertLenIsZero(&msg);
}

fn assertLenIsZero(msg: []const u8) void {
    expect(msg.len == 0);
}

test "C pointer" {
    var buf: [*c]const u8 = "kjdhfkjdhfdkjhfkfjhdfkjdhfkdjhfdkjhf";
    var len: u32 = 10;
    var slice = buf[0..len];
    expectEqualSlices(u8, "kjdhfkjdhf", slice);
}

test "C pointer slice access" {
    var buf: [10]u32 = [1]u32{42} ** 10;
    const c_ptr = @ptrCast([*c]const u32, &buf);

    comptime expectEqual([]const u32, @TypeOf(c_ptr[0..1]));

    for (c_ptr[0..5]) |*cl| {
        expectEqual(@as(u32, 42), cl.*);
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
    expect(sliceSum(&[_]u8{ 1, 2 }) == 3);
    expect(sliceSum(&[_]u8{ 3, 4 }) == 7);
}

test "slice type with custom alignment" {
    const LazilyResolvedType = struct {
        anything: i32,
    };
    var slice: []align(32) LazilyResolvedType = undefined;
    var array: [10]LazilyResolvedType align(32) = undefined;
    slice = &array;
    slice[1].anything = 42;
    expect(array[1].anything == 42);
}

test "access len index of sentinel-terminated slice" {
    const S = struct {
        fn doTheTest() void {
            var slice: [:0]const u8 = "hello";

            expect(slice.len == 5);
            expect(slice[5] == 0);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
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

    var runtime_len: usize = 3;
    const ptr2 = buf[0..runtime_len :0];
    // ptr2 is a null-terminated slice
    comptime expect(@TypeOf(ptr2) == [:0]u8);
    comptime expect(@TypeOf(ptr2[0..2]) == []u8);
}

test "empty array to slice" {
    const S = struct {
        fn doTheTest() void {
            const empty: []align(16) u8 = &[_]u8{};
            const align_1: []align(1) u8 = empty;
            const align_4: []align(4) u8 = empty;
            const align_16: []align(16) u8 = empty;
            expectEqual(1, @typeInfo(@TypeOf(align_1)).Pointer.alignment);
            expectEqual(4, @typeInfo(@TypeOf(align_4)).Pointer.alignment);
            expectEqual(16, @typeInfo(@TypeOf(align_16)).Pointer.alignment);
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}
