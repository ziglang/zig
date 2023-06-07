const builtin = @import("builtin");
const A = struct {
    b: B,
};

const B = *const fn (A) void;

test "allow these dependencies" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var a: A = undefined;
    var b: B = undefined;
    if (false) {
        a;
        b;
    }
}
