const std = @import("std");
const assert = std.debug.assert;
const warn = std.debug.warn;

test "bitReverse" {
//    comptime testBitReverse();
    testBitReverse();
}

fn testBitReverse() void { // TODO: add tests for non %4 == 0 bit widths
    // using comptime_ints, unsigned
    assert(@bitreverse(u0,   0) == 0);
    assert(@bitreverse(u8,   0x12) == 0x48);
    assert(@bitreverse(u16,  0x1234) == 0x2c48);
    assert(@bitreverse(u24,  0x123456) == 0x6a2c48);
    assert(@bitreverse(u32,  0x12345678) == 0x1e6a2c48);
    assert(@bitreverse(u40,  0x123456789a) == 0x591e6a2c48);
    assert(@bitreverse(u48,  0x123456789abc) == 0x3d591e6a2c48);
    assert(@bitreverse(u56,  0x123456789abcde) == 0x7b3d591e6a2c48);
    assert(@bitreverse(u64,  0x123456789abcdef1) == 0x8f7b3d591e6a2c48);
    assert(@bitreverse(u128, 0x123456789abcdef11121314151617181) == 0x818e868a828c84888f7b3d591e6a2c48);

    // using comptime_ints, signed
    assert(@bitreverse(i0,   0) == 0);
    assert(@bitreverse(i8,   -50) == @bitCast(i8,u8(206)));
//    assert(@bitreverse(i8,   @bitCast(i8,  u8(0x92))) == @bitCast(i8, u8( 0x49)));
//    assert(@bitreverse(i16,  @bitCast(i16, u16(0x1234))) == @bitCast(i16, u16( 0x2c48)));
//    assert(@bitreverse(i24,  @bitCast(i24, u24(0x123456))) == @bitCast(i24, u24( 0x6a2c48)));
//    assert(@bitreverse(i32,  @bitCast(i32, u32(0x12345678))) == @bitCast(i32, u32( 0x1e6a2c48)));
//    assert(@bitreverse(i40,  @bitCast(i40, u40(0x123456789a))) == @bitCast(i40, u40( 0x591e6a2c48)));
//    assert(@bitreverse(i48,  @bitCast(i48, u48(0x123456789abc))) == @bitCast(i48, u48( 0x3d591e6a2c48)));
//    assert(@bitreverse(i56,  @bitCast(i56, u56(0x123456789abcde))) == @bitCast(i56, u56( 0x7b3d591e6a2c48)));
//    assert(@bitreverse(i64,  @bitCast(i64, u64(0x123456789abcdef1))) ==  @bitCast(i64,u64(0x8f7b3d591e6a2c48)));
//    assert(@bitreverse(i128, @bitCast(i128,u128(0x123456789abcdef11121314151617181))) ==  @bitCast(i128,u128(0x818e868a828c84888f7b3d591e6a2c48)));

}
