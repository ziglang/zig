const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__mulosi4, .{ .name = "__mulosi4", .linkage = common.linkage });
    @export(__mulodi4, .{ .name = "__mulodi4", .linkage = common.linkage });
    @export(__muloti4, .{ .name = "__muloti4", .linkage = common.linkage });
}

// mulo - multiplication overflow
// * return a*%b.
// * return if a*b overflows => 1 else => 0
// - muloXi4_genericSmall as default
// - muloXi4_genericFast for 2*bitsize <= usize

inline fn muloXi4_genericSmall(comptime ST: type, a: ST, b: ST, overflow: *c_int) ST {
    overflow.* = 0;
    const min = math.minInt(ST);
    var res: ST = a *% b;
    // Hacker's Delight section Overflow subsection Multiplication
    // case a=-2^{31}, b=-1 problem, because
    // on some machines a*b = -2^{31} with overflow
    // Then -2^{31}/-1 overflows and any result is possible.
    // => check with a<0 and b=-2^{31}
    if ((a < 0 and b == min) or (a != 0 and @divTrunc(res, a) != b))
        overflow.* = 1;
    return res;
}

inline fn muloXi4_genericFast(comptime ST: type, a: ST, b: ST, overflow: *c_int) ST {
    overflow.* = 0;
    const EST = switch (ST) {
        i32 => i64,
        i64 => i128,
        i128 => i256,
        else => unreachable,
    };
    const min = math.minInt(ST);
    const max = math.maxInt(ST);
    var res: EST = @as(EST, a) * @as(EST, b);
    //invariant: -2^{bitwidth(EST)} < res < 2^{bitwidth(EST)-1}
    if (res < min or max < res)
        overflow.* = 1;
    return @truncate(ST, res);
}

pub fn __mulosi4(a: i32, b: i32, overflow: *c_int) callconv(.C) i32 {
    if (2 * @bitSizeOf(i32) <= @bitSizeOf(usize)) {
        return muloXi4_genericFast(i32, a, b, overflow);
    } else {
        return muloXi4_genericSmall(i32, a, b, overflow);
    }
}

pub fn __mulodi4(a: i64, b: i64, overflow: *c_int) callconv(.C) i64 {
    if (2 * @bitSizeOf(i64) <= @bitSizeOf(usize)) {
        return muloXi4_genericFast(i64, a, b, overflow);
    } else {
        return muloXi4_genericSmall(i64, a, b, overflow);
    }
}

pub fn __muloti4(a: i128, b: i128, overflow: *c_int) callconv(.C) i128 {
    switch (builtin.zig_backend) {
        .stage1, .stage2_llvm => {
            // Workaround for https://github.com/llvm/llvm-project/issues/56403
            // When we call the genericSmall implementation instead, LLVM optimizer
            // optimizes __muloti4 to a call to itself.
            return muloXi4_genericFast(i128, a, b, overflow);
        },
        else => {},
    }
    if (2 * @bitSizeOf(i128) <= @bitSizeOf(usize)) {
        return muloXi4_genericFast(i128, a, b, overflow);
    } else {
        return muloXi4_genericSmall(i128, a, b, overflow);
    }
}

test {
    _ = @import("mulosi4_test.zig");
    _ = @import("mulodi4_test.zig");
    _ = @import("muloti4_test.zig");
}
