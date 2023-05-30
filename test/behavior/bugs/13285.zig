const builtin = @import("builtin");

const Crasher = struct {
    lets_crash: u64 = 0,
};

test {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var a: Crasher = undefined;
    var crasher_ptr = &a;
    var crasher_local = crasher_ptr.*;
    const crasher_local_ptr = &crasher_local;
    crasher_local_ptr.lets_crash = 1;
}
