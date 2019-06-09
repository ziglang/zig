const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
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
    assertLenIsZero(msg);
}

fn assertLenIsZero(msg: []const u8) void {
    expect(msg.len == 0);
}

test "C pointer" {
    var buf: [*c]const u8 = c"kjdhfkjdhfdkjhfkfjhdfkjdhfkdjhfdkjhf";
    var len: u32 = 10;
    var slice = buf[0..len];
    expectEqualSlices(u8, "kjdhfkjdhf", slice);
}

fn sliceSum(comptime q: []const u8) i32 {
    comptime var result = 0;
    inline for (q) |item| {
        result += item;
    }
    return result;
}

test "comptime slices are disambiguated" {
    expect(sliceSum([_]u8{ 1, 2 }) == 3);
    expect(sliceSum([_]u8{ 3, 4 }) == 7);
}
