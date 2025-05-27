const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__mulvsi3, .{ .name = "__mulvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __mulvsi3(a: i32, b: i32) callconv(.c) i32 {
    const bits = 32;
    if (a == -2147483648) {
        if (b == 0 or b == 1)
            return a * b;
        @panic("compiler-rt: interger overflow");
    }
    if (b == -2147483648) {
        if (a == 0 or a == 1)
            return a * b;
        @panic("compiler-rt: interger overflow");
    }
    const sa = a >> (bits - 1);
    const abs_a = (a ^ sa) - sa;
    const sb = b >> (bits - 1);
    const abs_b = (b ^ sb) - sb;
    if (abs_a < 2 or abs_b < 2)
        return a * b;
    if (sa == sb) {
        if (abs_a > @divTrunc(2147483647, abs_b))
            @panic("compiler-rt: interger overflow");
    } else {
        if (abs_a > @divTrunc(-2147483648, -abs_b))
            @panic("compiler-rt: interger overflow");
    }
    return a * b;
}
