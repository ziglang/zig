const std = @import("std");
const expect = std.testing.expect;

test "@byteSwap" {
    comptime testByteSwap();
    testByteSwap();
}

fn testByteSwap() void {
    expect(@byteSwap(u0, 0) == 0);
    expect(@byteSwap(u8, 0x12) == 0x12);
    expect(@byteSwap(u16, 0x1234) == 0x3412);
    expect(@byteSwap(u24, 0x123456) == 0x563412);
    expect(@byteSwap(u32, 0x12345678) == 0x78563412);
    expect(@byteSwap(u40, 0x123456789a) == 0x9a78563412);
    expect(@byteSwap(i48, 0x123456789abc) == @bitCast(i48, u48(0xbc9a78563412)));
    expect(@byteSwap(u56, 0x123456789abcde) == 0xdebc9a78563412);
    expect(@byteSwap(u64, 0x123456789abcdef1) == 0xf1debc9a78563412);
    expect(@byteSwap(u128, 0x123456789abcdef11121314151617181) == 0x8171615141312111f1debc9a78563412);

    expect(@byteSwap(u0, u0(0)) == 0);
    expect(@byteSwap(i8, i8(-50)) == -50);
    expect(@byteSwap(i16, @bitCast(i16, u16(0x1234))) == @bitCast(i16, u16(0x3412)));
    expect(@byteSwap(i24, @bitCast(i24, u24(0x123456))) == @bitCast(i24, u24(0x563412)));
    expect(@byteSwap(i32, @bitCast(i32, u32(0x12345678))) == @bitCast(i32, u32(0x78563412)));
    expect(@byteSwap(u40, @bitCast(i40, u40(0x123456789a))) == u40(0x9a78563412));
    expect(@byteSwap(i48, @bitCast(i48, u48(0x123456789abc))) == @bitCast(i48, u48(0xbc9a78563412)));
    expect(@byteSwap(i56, @bitCast(i56, u56(0x123456789abcde))) == @bitCast(i56, u56(0xdebc9a78563412)));
    expect(@byteSwap(i64, @bitCast(i64, u64(0x123456789abcdef1))) == @bitCast(i64, u64(0xf1debc9a78563412)));
    expect(@byteSwap(i128, @bitCast(i128, u128(0x123456789abcdef11121314151617181))) ==
        @bitCast(i128, u128(0x8171615141312111f1debc9a78563412)));
}
