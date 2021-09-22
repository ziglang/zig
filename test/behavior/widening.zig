const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

test "integer widening" {
    var a: u8 = 250;
    var b: u16 = a;
    var c: u32 = b;
    var d: u64 = c;
    var e: u64 = d;
    var f: u128 = e;
    try expect(f == a);
}

test "implicit unsigned integer to signed integer" {
    var a: u8 = 250;
    var b: i16 = a;
    try expect(b == 250);
}
