const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

pub fn __lshrti3(a: i128, b: i32) callconv(.C) i128 {
    var input = twords{ .all = a };
    var result: twords = undefined;

    if (b > 63) {
        // 64 <= b < 128
        result.s.low = input.s.high >> @intCast(u6, b - 64);
        result.s.high = 0;
    } else {
        // 0 <= b < 64
        if (b == 0) return a;
        result.s.low = input.s.high << @intCast(u6, 64 - b);
        result.s.low |= input.s.low >> @intCast(u6, b);
        result.s.high = input.s.high >> @intCast(u6, b);
    }

    return result.all;
}

const twords = extern union {
    all: i128,
    s: S,

    const S = if (builtin.endian == .Little)
        struct {
            low: u64,
            high: u64,
        }
    else
        struct {
            high: u64,
            low: u64,
        };
};

test "import lshrti3" {
    _ = @import("lshrti3_test.zig");
}
