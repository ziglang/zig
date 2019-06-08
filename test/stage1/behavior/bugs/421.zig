const assert = @import("std").debug.assert;

test "bitCast to array" {
    comptime testBitCastArray();
    testBitCastArray();
}

fn testBitCastArray() void {
    assert(extractOne64(0x0123456789abcdef0123456789abcdef) == 0x0123456789abcdef);
}

fn extractOne64(a: u128) u64 {
    const x = @bitCast([2]u64, a);
    return x[1];
}
