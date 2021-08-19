// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("std").builtin;

// Returns: if number of bits odd: 1, else: 0
// Algorithms taken from Bit Twiddling Hacks (under public domain)

pub fn __paritysi2(a: i32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);

    a ^= a >> 16;
    a ^= a >> 8;
    a ^= a >> 4;
    a &= 0xf;
    return (0x6996 >> a) & 1; // 0x6996 is magic lookup table
}

pub fn __paritydi2(a: i64) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);

    a ^= a >> 1;
    a ^= a >> 2;
    a &= 0x011111111;
    a *= 0x011111111;
    return ((a >> 28) & 1) != 0;
    // TODO check if *parity ^= (-((x[0] >> 30) & 0x00000001) & 0xc3e0d69f);
    // has a reference somewhere

    //LLVM code: TODO: test if current code breaks on big endian
    //dwords x;
    //x.all = a;
    //su_int x2 = x.s.high ^ x.s.low;
    //x2 ^= x2 >> 16;
    //x2 ^= x2 >> 8;
    //x2 ^= x2 >> 4;
    //return (0x6996 >> (x2 & 0xF)) & 1;
}

//pub fn __parityti2(a: i128) callconv(.C) i32 {
//    @setRuntimeSafety(builtin.is_test);
//
//    // TODO: test if below code is faster or if it breaks
//    // on big endian
//    // a ^= a >> 64;
//    // a ^= a >> 32;
//    var x: twords = a;
//    var y: dword = undefined;
//    y.all = x.s.high ^ x.s.low;
//    var z: u32 = y.s.high ^ y.s.low;
//
//    a ^= a >> 16;
//    a ^= a >> 8;
//    a ^= a >> 4;
//    a &= 0xf;
//    return (0x6996 >> a) & 1; // 0x6996 is magic lookup table
//}

//test {
//    _ = @import("parity_test.zig");
//}
