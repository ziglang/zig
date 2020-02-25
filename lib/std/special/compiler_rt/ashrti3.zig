const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

pub fn __ashrti3(a: i128, b: i32) callconv(.C) i128 {
    var input = twords{ .all = a };
    var result: twords = undefined;

    if (b > 63) {
        // 64 <= b < 128
        result.s.low = input.s.high >> @intCast(u6, b - 64);
        result.s.high = input.s.high >> 63;
    } else {
        // 0 <= b < 64
        if (b == 0) return a;
        result.s.low = input.s.high << @intCast(u6, 64 - b);
        // Avoid sign-extension here
        result.s.low |= @bitCast(i64, @bitCast(u64, input.s.low) >> @intCast(u6, b));
        result.s.high = input.s.high >> @intCast(u6, b);
    }

    return result.all;
}

const twords = extern union {
    all: i128,
    s: S,

    const S = if (builtin.endian == .Little)
        struct {
            low: i64,
            high: i64,
        }
    else
        struct {
            high: i64,
            low: i64,
        };
};

test "import ashrti3" {
    _ = @import("ashrti3_test.zig");
}
