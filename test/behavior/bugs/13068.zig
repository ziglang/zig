const std = @import("std");
const builtin = @import("builtin");

pub const allocator = std.heap.page_allocator;
var list = std.ArrayList(u32).init(allocator);

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    list.items.len = 0;
}
