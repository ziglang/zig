// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/test/builtins/Unit/comparedf2_test.c

const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;

const comparedf2 = @import("compareXf2.zig");

const TestVector = struct {
    a: f64,
    b: f64,
    eqReference: c_int,
    geReference: c_int,
    gtReference: c_int,
    leReference: c_int,
    ltReference: c_int,
    neReference: c_int,
    unReference: c_int,
};

fn test__cmpdf2(vector: TestVector) bool {
    if (comparedf2.__eqdf2(vector.a, vector.b) != vector.eqReference) {
        return false;
    }
    if (comparedf2.__gedf2(vector.a, vector.b) != vector.geReference) {
        return false;
    }
    if (comparedf2.__gtdf2(vector.a, vector.b) != vector.gtReference) {
        return false;
    }
    if (comparedf2.__ledf2(vector.a, vector.b) != vector.leReference) {
        return false;
    }
    if (comparedf2.__ltdf2(vector.a, vector.b) != vector.ltReference) {
        return false;
    }
    if (comparedf2.__nedf2(vector.a, vector.b) != vector.neReference) {
        return false;
    }
    if (comparedf2.__unorddf2(vector.a, vector.b) != vector.unReference) {
        return false;
    }
    return true;
}

const arguments = [_]f64{
    std.math.nan(f64),
    -std.math.inf(f64),
    -0x1.fffffffffffffp1023,
    -0x1.0000000000001p0 - 0x1.0000000000000p0,
    -0x1.fffffffffffffp-1,
    -0x1.0000000000000p-1022,
    -0x0.fffffffffffffp-1022,
    -0x0.0000000000001p-1022,
    -0.0,
    0.0,
    0x0.0000000000001p-1022,
    0x0.fffffffffffffp-1022,
    0x1.0000000000000p-1022,
    0x1.fffffffffffffp-1,
    0x1.0000000000000p0,
    0x1.0000000000001p0,
    0x1.fffffffffffffp1023,
    std.math.inf(f64),
};

fn generateVector(comptime a: f64, comptime b: f64) TestVector {
    const leResult = if (a < b) -1 else if (a == b) 0 else 1;
    const geResult = if (a > b) 1 else if (a == b) 0 else -1;
    const unResult = if (a != a or b != b) 1 else 0;
    return TestVector{
        .a = a,
        .b = b,
        .eqReference = leResult,
        .geReference = geResult,
        .gtReference = geResult,
        .leReference = leResult,
        .ltReference = leResult,
        .neReference = leResult,
        .unReference = unResult,
    };
}

const test_vectors = init: {
    @setEvalBranchQuota(10000);
    var vectors: [arguments.len * arguments.len]TestVector = undefined;
    for (arguments[0..]) |arg_i, i| {
        for (arguments[0..]) |arg_j, j| {
            vectors[(i * arguments.len) + j] = generateVector(arg_i, arg_j);
        }
    }
    break :init vectors;
};

test "compare f64" {
    for (test_vectors) |vector| {
        try std.testing.expect(test__cmpdf2(vector));
    }
}
