const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

/// This allocator is used in front of another allocator and logs to `std.log`
/// on every call to the allocator.
/// For logging to a `std.io.Writer` see `std.heap.LogToWriterAllocator`
pub fn LoggingAllocator(
    comptime success_log_level: std.log.Level,
    comptime failure_log_level: std.log.Level,
) type {
    return ScopedLoggingAllocator(.default, success_log_level, failure_log_level);
}

/// This allocator is used in front of another allocator and logs to `std.log`
/// with the given scope on every call to the allocator.
/// For logging to a `std.io.Writer` see `std.heap.LogToWriterAllocator`
pub fn ScopedLoggingAllocator(
    comptime scope: @Type(.EnumLiteral),
    comptime success_log_level: std.log.Level,
    comptime failure_log_level: std.log.Level,
) type {
    const log = std.log.scoped(scope);

    return struct {
        parent_allocator: Allocator,

        const Self = @This();

        pub fn init(parent_allocator: Allocator) Self {
            return .{
                .parent_allocator = parent_allocator,
            };
        }

        pub fn allocator(self: *Self) Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        // This function is required as the `std.log.log` function is not public
        inline fn logHelper(comptime log_level: std.log.Level, comptime format: []const u8, args: anytype) void {
            switch (log_level) {
                .err => log.err(format, args),
                .warn => log.warn(format, args),
                .info => log.info(format, args),
                .debug => log.debug(format, args),
            }
        }

        fn alloc(
            ctx: *anyopaque,
            len: usize,
            log2_ptr_align: u8,
            ra: usize,
        ) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            const result = self.parent_allocator.rawAlloc(len, log2_ptr_align, ra);
            if (result != null) {
                logHelper(
                    success_log_level,
                    "alloc - success - len: {}, ptr_align: {}",
                    .{ len, log2_ptr_align },
                );
            } else {
                logHelper(
                    failure_log_level,
                    "alloc - failure: OutOfMemory - len: {}, ptr_align: {}",
                    .{ len, log2_ptr_align },
                );
            }
            return result;
        }

        fn resize(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            new_len: usize,
            ra: usize,
        ) bool {
            const self: *Self = @ptrCast(@alignCast(ctx));
            if (self.parent_allocator.rawResize(buf, log2_buf_align, new_len, ra)) {
                if (new_len <= buf.len) {
                    logHelper(
                        success_log_level,
                        "shrink - success - {} to {}, buf_align: {}",
                        .{ buf.len, new_len, log2_buf_align },
                    );
                } else {
                    logHelper(
                        success_log_level,
                        "expand - success - {} to {}, buf_align: {}",
                        .{ buf.len, new_len, log2_buf_align },
                    );
                }

                return true;
            }

            std.debug.assert(new_len > buf.len);
            logHelper(
                failure_log_level,
                "expand - failure - {} to {}, buf_align: {}",
                .{ buf.len, new_len, log2_buf_align },
            );
            return false;
        }

        fn free(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            ra: usize,
        ) void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.parent_allocator.rawFree(buf, log2_buf_align, ra);
            logHelper(success_log_level, "free - len: {}", .{buf.len});
        }
    };
}

/// This allocator is used in front of another allocator and logs to `std.log`
/// on every call to the allocator.
/// For logging to a `std.io.Writer` see `std.heap.LogToWriterAllocator`
pub fn loggingAllocator(parent_allocator: Allocator) LoggingAllocator(.debug, .err) {
    return LoggingAllocator(.debug, .err).init(parent_allocator);
}
