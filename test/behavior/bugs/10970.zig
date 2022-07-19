const builtin = @import("builtin");

fn retOpt() ?u32 {
    return null;
}
test "breaking from a loop in an if statement" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    var cond = true;
    const opt = while (cond) {
        if (retOpt()) |opt| {
            break opt;
        }
        break 1;
    } else 2;
    _ = opt;
}
