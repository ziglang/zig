const std = @import("std");
const assert = std.debug.assert;

test "@bswap" {
    comptime testByteSwap();
    testByteSwap();
}

fn testByteSwap() void {
    assert(@bswap(u0, 0) == 0);
    assert(@bswap(u8, 0x12) == 0x12);
    assert(@bswap(u16, 0x1234) == 0x3412);
    assert(@bswap(u24, 0x123456) == 0x563412);
    assert(@bswap(u32, 0x12345678) == 0x78563412);
    assert(@bswap(u40, 0x123456789a) == 0x9a78563412);
    assert(@bswap(u48, 0x123456789abc) == 0xbc9a78563412);
    assert(@bswap(u56, 0x123456789abcde) == 0xdebc9a78563412);
    assert(@bswap(u64, 0x123456789abcdef1) == 0xf1debc9a78563412);
    assert(@bswap(u128, 0x123456789abcdef11121314151617181) == 0x8171615141312111f1debc9a78563412);

    assert(@bswap(i0, 0) == 0);
    assert(@bswap(i8, -50) == -50);
    assert(@bswap(i16, @bitCast(i16, u16(0x1234))) == @bitCast(i16, u16(0x3412)));
    assert(@bswap(i24, @bitCast(i24, u24(0x123456))) == @bitCast(i24, u24(0x563412)));
    assert(@bswap(i32, @bitCast(i32, u32(0x12345678))) == @bitCast(i32, u32(0x78563412)));
    assert(@bswap(i40, @bitCast(i40, u40(0x123456789a))) == @bitCast(i40, u40(0x9a78563412)));
    assert(@bswap(i48, @bitCast(i48, u48(0x123456789abc))) == @bitCast(i48, u48(0xbc9a78563412)));
    assert(@bswap(i56, @bitCast(i56, u56(0x123456789abcde))) == @bitCast(i56, u56(0xdebc9a78563412)));
    assert(@bswap(i64, @bitCast(i64, u64(0x123456789abcdef1))) == @bitCast(i64, u64(0xf1debc9a78563412)));
    assert(@bswap(i128, @bitCast(i128, u128(0x123456789abcdef11121314151617181))) ==
        @bitCast(i128, u128(0x8171615141312111f1debc9a78563412)));
}
