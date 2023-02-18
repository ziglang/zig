// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/test/builtins/Unit/comparedf2_test.c

const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;

const __eqdf2 = @import("./cmpdf2.zig").__eqdf2;
const __ledf2 = @import("./cmpdf2.zig").__ledf2;
const __ltdf2 = @import("./cmpdf2.zig").__ltdf2;
const __nedf2 = @import("./cmpdf2.zig").__nedf2;

const __gedf2 = @import("./gedf2.zig").__gedf2;
const __gtdf2 = @import("./gedf2.zig").__gtdf2;

const __unorddf2 = @import("./unorddf2.zig").__unorddf2;

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
    if (__eqdf2(vector.a, vector.b) != vector.eqReference) {
        return false;
    }
    if (__gedf2(vector.a, vector.b) != vector.geReference) {
        return false;
    }
    if (__gtdf2(vector.a, vector.b) != vector.gtReference) {
        return false;
    }
    if (__ledf2(vector.a, vector.b) != vector.leReference) {
        return false;
    }
    if (__ltdf2(vector.a, vector.b) != vector.ltReference) {
        return false;
    }
    if (__nedf2(vector.a, vector.b) != vector.neReference) {
        return false;
    }
    if (__unorddf2(vector.a, vector.b) != vector.unReference) {
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
    for (arguments[0..], 0..) |arg_i, i| {
        for (arguments[0..], 0..) |arg_j, j| {
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
