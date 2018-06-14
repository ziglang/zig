const udivmod = @import("udivmod.zig").udivmod;
const builtin = @import("builtin");
const compiler_rt = @import("index.zig");

pub extern fn __muloti4(a: i128, b: i128, overflow: *c_int) i128 {
    @setRuntimeSafety(builtin.is_test);

    const min = @bitCast(i128, u128(1 << (i128.bit_count - 1)));
    const max = ~min;
    overflow.* = 0;

    const r = a *% b;
    if (a == min) {
        if (b != 0 and b != 1) {
            overflow.* = 1;
        }
        return r;
    }
    if (b == min) {
        if (a != 0 and a != 1) {
            overflow.* = 1;
        }
        return r;
    }

    const sa = a >> (i128.bit_count - 1);
    const abs_a = (a ^ sa) -% sa;
    const sb = b >> (i128.bit_count - 1);
    const abs_b = (b ^ sb) -% sb;

    if (abs_a < 2 or abs_b < 2) {
        return r;
    }

    if (sa == sb) {
        if (abs_a > @divFloor(max, abs_b)) {
            overflow.* = 1;
        }
    } else {
        if (abs_a > @divFloor(min, -abs_b)) {
            overflow.* = 1;
        }
    }

    return r;
}

pub extern fn __muloti4_windows_x86_64(a: *const i128, b: *const i128, overflow: *c_int) void {
    @setRuntimeSafety(builtin.is_test);
    compiler_rt.setXmm0(i128, __muloti4(a.*, b.*, overflow));
}

test "import muloti4" {
    _ = @import("muloti4_test.zig");
}
