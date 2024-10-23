const builtin = @import("builtin");
const std = @import("std");

test "@prefetch()" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var a: [2]u32 = .{ 42, 42 };
    var a_len = a.len;
    _ = &a_len;

    @prefetch(&a, .{});

    @prefetch(&a[0], .{ .rw = .read, .locality = 3, .cache = .data });
    @prefetch(&a, .{ .rw = .read, .locality = 2, .cache = .data });
    @prefetch(a[0..].ptr, .{ .rw = .read, .locality = 1, .cache = .data });
    @prefetch(a[0..a_len], .{ .rw = .read, .locality = 0, .cache = .data });

    @prefetch(&a[0], .{ .rw = .write, .locality = 3, .cache = .data });
    @prefetch(&a, .{ .rw = .write, .locality = 2, .cache = .data });
    @prefetch(a[0..].ptr, .{ .rw = .write, .locality = 1, .cache = .data });
    @prefetch(a[0..a_len], .{ .rw = .write, .locality = 0, .cache = .data });

    @prefetch(&a[0], .{ .rw = .read, .locality = 3, .cache = .instruction });
    @prefetch(&a, .{ .rw = .read, .locality = 2, .cache = .instruction });
    @prefetch(a[0..].ptr, .{ .rw = .read, .locality = 1, .cache = .instruction });
    @prefetch(a[0..a_len], .{ .rw = .read, .locality = 0, .cache = .instruction });

    @prefetch(&a[0], .{ .rw = .write, .locality = 3, .cache = .instruction });
    @prefetch(&a, .{ .rw = .write, .locality = 2, .cache = .instruction });
    @prefetch(a[0..].ptr, .{ .rw = .write, .locality = 1, .cache = .instruction });
    @prefetch(a[0..a_len], .{ .rw = .write, .locality = 0, .cache = .instruction });
}
