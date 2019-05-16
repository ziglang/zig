const std = @import("std");
const expect = std.testing.expect;
const math = std.math;

fn ctz(x: var) usize {
    return @ctz(@typeOf(x), x);
}

test "fixed" {
    testClz();
    comptime testClz();
}

fn testClz() void {
    expect(ctz(u128(0x40000000000000000000000000000000)) == 126);
    expect(math.rotl(u128, u128(0x40000000000000000000000000000000), u8(1)) == u128(0x80000000000000000000000000000000));
    expect(ctz(u128(0x80000000000000000000000000000000)) == 127);
    expect(ctz(math.rotl(u128, u128(0x40000000000000000000000000000000), u8(1))) == 127);
}
