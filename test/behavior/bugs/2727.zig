const builtin = @import("builtin");

fn t() bool {
    return true;
}

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    comptime var i: usize = 0;
    inline while (i < 2) : (i += 1) {
        if (t()) {} else return;
    }
}
