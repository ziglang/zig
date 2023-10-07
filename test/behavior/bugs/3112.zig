const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

const State = struct {
    const Self = @This();
    enter: *const fn (previous: ?Self) void,
};

fn prev(p: ?State) void {
    expect(p == null) catch @panic("test failure");
}

test "zig test crash" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var global: State = undefined;
    global.enter = prev;
    global.enter(null);
}
