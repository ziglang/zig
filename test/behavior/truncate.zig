const std = @import("std");
const expect = std.testing.expect;

test "truncate u0 to larger integer allowed and has comptime known result" {
    var x: u0 = 0;
    const y = @truncate(u8, x);
    comptime try expect(y == 0);
}

test "truncate.u0.literal" {
    var z = @truncate(u0, 0);
    try expect(z == 0);
}

test "truncate.u0.const" {
    const c0: usize = 0;
    var z = @truncate(u0, c0);
    try expect(z == 0);
}

test "truncate.u0.var" {
    var d: u8 = 2;
    var z = @truncate(u0, d);
    try expect(z == 0);
}

test "truncate sign mismatch but comptime known so it works anyway" {
    const x: u32 = 10;
    var result = @truncate(i8, x);
    try expect(result == 10);
}

test "truncate on comptime integer" {
    var x = @truncate(u16, 9999);
    try expect(x == 9999);
}
