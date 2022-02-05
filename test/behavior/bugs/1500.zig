const builtin = @import("builtin");
const A = struct {
    b: B,
};

const B = *const fn (A) void;

test "allow these dependencies" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    var a: A = undefined;
    var b: B = undefined;
    if (false) {
        a;
        b;
    }
}
