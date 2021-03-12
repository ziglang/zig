const std = @import("std.zig");

/// Simple wrapper for a value and a held mutex.
pub fn HeldValue(comptime T: type) type {
    return struct {
        const Self = @This();

        // work around for https://github.com/ziglang/zig/issues/8212
        const Held = @TypeOf(blk: {
            var mutex = std.Thread.Mutex{};
            break :blk mutex.acquire();
        });

        value: T,
        held: Held,

        pub fn release(self: *const Self) void {
            self.held.release();
        }
    };
}
