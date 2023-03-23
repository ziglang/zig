const std = @import("std");
const builtin = @import("builtin");

pub const allocator = std.heap.page_allocator;
var list = std.ArrayList(u32).init(allocator);

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    list.items.len = 0;
}
