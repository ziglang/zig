const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const TestContext = struct {
    server_context: *ListenerContext,
};

const ListenerContext = struct {
    context_alloc: *ContextAllocator,
};

const ContextAllocator = MemoryPool(TestContext);

fn MemoryPool(comptime T: type) type {
    _ = T;
    return struct {
        n: usize,
    };
}

test "foo" {
    if (builtin.zig_backend == .zsf_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .zsf_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .zsf_sparc64) return error.SkipZigTest; // TODO

    var allocator = ContextAllocator{ .n = 10 };
    try expect(allocator.n == 10);
}
