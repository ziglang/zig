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
    expect(f == a);
}

test "implicit unsigned integer to signed integer" {
    var a: u8 = 250;
    var b: i16 = a;
    expect(b == 250);
}

test "float widening" {
    var a: f16 = 12.34;
    var b: f32 = a;
    var c: f64 = b;
    var d: f128 = c;
    expect(a == b);
    expect(b == c);
    expect(c == d);
}

test "float widening f16 to f128" {
    // TODO https://github.com/ziglang/zig/issues/3282
    if (@import("builtin").arch == .aarch64) return error.SkipZigTest;
    if (@import("builtin").arch == .powerpc64le) return error.SkipZigTest;

    var x: f16 = 12.34;
    var y: f128 = x;
    expect(x == y);
}
