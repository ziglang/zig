const std = @import("std");
const expect = std.testing.expect;
const minInt = std.math.minInt;

test "@bitreverse" {
    comptime testBitReverse();
    testBitReverse();
}

fn testBitReverse() void {
    // using comptime_ints, unsigned
    expect(@bitreverse(u0, 0) == 0);
    expect(@bitreverse(u5, 0x12) == 0x9);
    expect(@bitreverse(u8, 0x12) == 0x48);
    expect(@bitreverse(u16, 0x1234) == 0x2c48);
    expect(@bitreverse(u24, 0x123456) == 0x6a2c48);
    expect(@bitreverse(u32, 0x12345678) == 0x1e6a2c48);
    expect(@bitreverse(u40, 0x123456789a) == 0x591e6a2c48);
    expect(@bitreverse(u48, 0x123456789abc) == 0x3d591e6a2c48);
    expect(@bitreverse(u56, 0x123456789abcde) == 0x7b3d591e6a2c48);
    expect(@bitreverse(u64, 0x123456789abcdef1) == 0x8f7b3d591e6a2c48);
    expect(@bitreverse(u128, 0x123456789abcdef11121314151617181) == 0x818e868a828c84888f7b3d591e6a2c48);

    // using runtime uints, unsigned
    var num0: u0 = 0;
    expect(@bitreverse(u0, num0) == 0);
    var num5: u5 = 0x12;
    expect(@bitreverse(u5, num5) == 0x9);
    var num8: u8 = 0x12;
    expect(@bitreverse(u8, num8) == 0x48);
    var num16: u16 = 0x1234;
    expect(@bitreverse(u16, num16) == 0x2c48);
    var num24: u24 = 0x123456;
    expect(@bitreverse(u24, num24) == 0x6a2c48);
    var num32: u32 = 0x12345678;
    expect(@bitreverse(u32, num32) == 0x1e6a2c48);
    var num40: u40 = 0x123456789a;
    expect(@bitreverse(u40, num40) == 0x591e6a2c48);
    var num48: u48 = 0x123456789abc;
    expect(@bitreverse(u48, num48) == 0x3d591e6a2c48);
    var num56: u56 = 0x123456789abcde;
    expect(@bitreverse(u56, num56) == 0x7b3d591e6a2c48);
    var num64: u64 = 0x123456789abcdef1;
    expect(@bitreverse(u64, num64) == 0x8f7b3d591e6a2c48);
    var num128: u128 = 0x123456789abcdef11121314151617181;
    expect(@bitreverse(u128, num128) == 0x818e868a828c84888f7b3d591e6a2c48);

    // using comptime_ints, signed, positive
    expect(@bitreverse(i0, 0) == 0);
    expect(@bitreverse(i8, @bitCast(i8, u8(0x92))) == @bitCast(i8, u8(0x49)));
    expect(@bitreverse(i16, @bitCast(i16, u16(0x1234))) == @bitCast(i16, u16(0x2c48)));
    expect(@bitreverse(i24, @bitCast(i24, u24(0x123456))) == @bitCast(i24, u24(0x6a2c48)));
    expect(@bitreverse(i32, @bitCast(i32, u32(0x12345678))) == @bitCast(i32, u32(0x1e6a2c48)));
    expect(@bitreverse(i40, @bitCast(i40, u40(0x123456789a))) == @bitCast(i40, u40(0x591e6a2c48)));
    expect(@bitreverse(i48, @bitCast(i48, u48(0x123456789abc))) == @bitCast(i48, u48(0x3d591e6a2c48)));
    expect(@bitreverse(i56, @bitCast(i56, u56(0x123456789abcde))) == @bitCast(i56, u56(0x7b3d591e6a2c48)));
    expect(@bitreverse(i64, @bitCast(i64, u64(0x123456789abcdef1))) == @bitCast(i64, u64(0x8f7b3d591e6a2c48)));
    expect(@bitreverse(i128, @bitCast(i128, u128(0x123456789abcdef11121314151617181))) == @bitCast(i128, u128(0x818e868a828c84888f7b3d591e6a2c48)));

    // using comptime_ints, signed, negative. Compare to runtime ints returned from llvm.
    var neg5: i5 = minInt(i5) + 1;
    expect(@bitreverse(i5, minInt(i5) + 1) == @bitreverse(i5, neg5));
    var neg8: i8 = -18;
    expect(@bitreverse(i8, -18) == @bitreverse(i8, neg8));
    var neg16: i16 = -32694;
    expect(@bitreverse(i16, -32694) == @bitreverse(i16, neg16));
    var neg24: i24 = -6773785;
    expect(@bitreverse(i24, -6773785) == @bitreverse(i24, neg24));
    var neg32: i32 = -16773785;
    expect(@bitreverse(i32, -16773785) == @bitreverse(i32, neg32));
    var neg40: i40 = minInt(i40) + 12345;
    expect(@bitreverse(i40, minInt(i40) + 12345) == @bitreverse(i40, neg40));
    var neg48: i48 = minInt(i48) + 12345;
    expect(@bitreverse(i48, minInt(i48) + 12345) == @bitreverse(i48, neg48));
    var neg56: i56 = minInt(i56) + 12345;
    expect(@bitreverse(i56, minInt(i56) + 12345) == @bitreverse(i56, neg56));
    var neg64: i64 = minInt(i64) + 12345;
    expect(@bitreverse(i64, minInt(i64) + 12345) == @bitreverse(i64, neg64));
    var neg128: i128 = minInt(i128) + 12345;
    expect(@bitreverse(i128, minInt(i128) + 12345) == @bitreverse(i128, neg128));
}
