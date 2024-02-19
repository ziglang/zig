const builtin = @import("builtin");

const Namespace = struct {
    test "thingy" {}
};

fn thingy(a: usize, b: usize) usize {
    return a + b;
}

comptime {
    _ = Namespace;
}

test "thingy" {}

test thingy {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    if (thingy(1, 2) != 3) unreachable;
}
