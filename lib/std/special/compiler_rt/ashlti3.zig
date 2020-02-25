const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

pub fn __ashlti3(a: i128, b: i32) callconv(.C) i128 {
    var input = twords{ .all = a };
    var result: twords = undefined;

    if (b > 63) {
        // 64 <= b < 128
        result.s.low = 0;
        result.s.high = input.s.low << @intCast(u6, b - 64);
    } else {
        // 0 <= b < 64
        if (b == 0) return a;
        result.s.low = input.s.low << @intCast(u6, b);
        result.s.high = input.s.low >> @intCast(u6, 64 - b);
        result.s.high |= input.s.high << @intCast(u6, b);
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

test "import ashlti3" {
    _ = @import("ashlti3_test.zig");
}
