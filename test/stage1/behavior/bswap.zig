const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

test "@bswap" {
    comptime testByteSwap();
    testByteSwap();
}

fn testByteSwap() void {
    assertOrPanic(@bswap(u0, 0) == 0);
    assertOrPanic(@bswap(u8, 0x12) == 0x12);
    assertOrPanic(@bswap(u16, 0x1234) == 0x3412);
    assertOrPanic(@bswap(u24, 0x123456) == 0x563412);
    assertOrPanic(@bswap(u32, 0x12345678) == 0x78563412);
    assertOrPanic(@bswap(u40, 0x123456789a) == 0x9a78563412);
    assertOrPanic(@bswap(u48, 0x123456789abc) == 0xbc9a78563412);
    assertOrPanic(@bswap(u56, 0x123456789abcde) == 0xdebc9a78563412);
    assertOrPanic(@bswap(u64, 0x123456789abcdef1) == 0xf1debc9a78563412);
    assertOrPanic(@bswap(u128, 0x123456789abcdef11121314151617181) == 0x8171615141312111f1debc9a78563412);

    assertOrPanic(@bswap(i0, 0) == 0);
    assertOrPanic(@bswap(i8, -50) == -50);
    assertOrPanic(@bswap(i16, @bitCast(i16, u16(0x1234))) == @bitCast(i16, u16(0x3412)));
    assertOrPanic(@bswap(i24, @bitCast(i24, u24(0x123456))) == @bitCast(i24, u24(0x563412)));
    assertOrPanic(@bswap(i32, @bitCast(i32, u32(0x12345678))) == @bitCast(i32, u32(0x78563412)));
    assertOrPanic(@bswap(i40, @bitCast(i40, u40(0x123456789a))) == @bitCast(i40, u40(0x9a78563412)));
    assertOrPanic(@bswap(i48, @bitCast(i48, u48(0x123456789abc))) == @bitCast(i48, u48(0xbc9a78563412)));
    assertOrPanic(@bswap(i56, @bitCast(i56, u56(0x123456789abcde))) == @bitCast(i56, u56(0xdebc9a78563412)));
    assertOrPanic(@bswap(i64, @bitCast(i64, u64(0x123456789abcdef1))) == @bitCast(i64, u64(0xf1debc9a78563412)));
    assertOrPanic(@bswap(i128, @bitCast(i128, u128(0x123456789abcdef11121314151617181))) ==
        @bitCast(i128, u128(0x8171615141312111f1debc9a78563412)));
}
