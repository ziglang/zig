const std = @import("std");
const assert = std.debug.assert;
const warn = std.debug.warn;

test "bitReverse" {
//    comptime testBitReverse();
    testBitReverse();
}

fn testBitReverse() void { // TODO: add tests for non %4 == 0 bit widths
    assert(@bitreverse(u0, 0) == 0);
    assert(@bitreverse(i0, 0) == 0);
    warn("\n0b{b}\n",@bitreverse(u8,0b10110110));
//    assert(@bitreverse(u8, 0x12) == 0x48);
//    assert(@bitreverse(i8, 0x12) == 0x48);
    warn("\n0b{b}\n",@bitreverse(u16,0b10110110));
//    warn("\n0b{b}\n",@bswap(u16,0b10110110));
//    assert(@bitreverse(u16, 0x1234) == 0x2c48);
//    assert(@bitreverse(i16, 0x1234) == 0x2c48);
//    assert(@bitreverse(u24, 0x123456) == 0x6a2c48);
//    assert(@bitreverse(i24, 0x123456) == 0x6a2c48);
//    assert(@bitreverse(u32, 0x12345678) == 0x1e6a2c48);
//    assert(@bitreverse(i32, 0x12345678) == 0x1e6a2c48);
//    assert(@bitreverse(u40, 0x123456789a) == 0x591e6a2c48);
//    assert(@bitreverse(i40, 0x123456789a) == 0x591e6a2c48);
//    assert(@bitreverse(u48, 0x123456789abc) == 0x3d591e6a2c48);
//    assert(@bitreverse(i48, 0x123456789abc) == 0x3d591e6a2c48);
//    assert(@bitreverse(u56, 0x123456789abcde) == 0x7b3d591e6a2c48);
//    assert(@bitreverse(i56, 0x123456789abcde) == 0x7b3d591e6a2c48);
//    const rev_u64_pattern: u64 = 0x8f7b3d591e6a2c48;
//    assert(@bitreverse(u64, 0x123456789abcdef1) == 0x8f7b3d591e6a2c48);
//    assert(@bitreverse(i64, 0x123456789abcdef1) == @bitCast(i64,rev_u64_pattern));
//    const rev_u128_pattern: u128 = 0x818e868a828c84888f7b3d591e6a2c48;
//    assert(@bitreverse(u128, 0x123456789abcdef11121314151617181) == 0x818e868a828c84888f7b3d591e6a2c48);
//    assert(@bitreverse(i128, 0x123456789abcdef11121314151617181) == @bitCast(i128,rev_u128_pattern));

}
