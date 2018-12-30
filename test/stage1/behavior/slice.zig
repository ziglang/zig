const assert = @import("std").debug.assert;
const mem = @import("std").mem;

const x = @intToPtr([*]i32, 0x1000)[0..0x500];
const y = x[0x100..];
test "compile time slice of pointer to hard coded address" {
    assert(@ptrToInt(x.ptr) == 0x1000);
    assert(x.len == 0x500);

    assert(@ptrToInt(y.ptr) == 0x1100);
    assert(y.len == 0x400);
}

test "slice child property" {
    var array: [5]i32 = undefined;
    var slice = array[0..];
    assert(@typeOf(slice).Child == i32);
}

test "runtime safety lets us slice from len..len" {
    var an_array = []u8{
        1,
        2,
        3,
    };
    assert(mem.eql(u8, sliceFromLenToLen(an_array[0..], 3, 3), ""));
}

fn sliceFromLenToLen(a_slice: []u8, start: usize, end: usize) []u8 {
    return a_slice[start..end];
}

test "implicitly cast array of size 0 to slice" {
    var msg = []u8{};
    assertLenIsZero(msg);
}

fn assertLenIsZero(msg: []const u8) void {
    assert(msg.len == 0);
}
