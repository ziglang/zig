const builtin = @import("builtin");

test "casting integer address to function pointer" {
    addressToFunction();
    comptime addressToFunction();
}

fn addressToFunction() void {
    var addr: usize = 0xdeadbee0;
    _ = @intToPtr(*const fn () void, addr);
}

test "mutate through ptr initialized with constant intToPtr value" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    forceCompilerAnalyzeBranchHardCodedPtrDereference(false);
}

fn forceCompilerAnalyzeBranchHardCodedPtrDereference(x: bool) void {
    const hardCodedP = @intToPtr(*volatile u8, 0xdeadbeef);
    if (x) {
        hardCodedP.* = hardCodedP.* | 10;
    } else {
        return;
    }
}
