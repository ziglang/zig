const builtin = @import("builtin");

fn getError() !void {
    return error.Test;
}

fn getError2() !void {
    var a: u8 = 'c';
    _ = &a;
    try if (a == 'a') getError() else if (a == 'b') getError() else getError();
}

test "`try`ing an if/else expression" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try @import("std").testing.expectError(error.Test, getError2());
}
