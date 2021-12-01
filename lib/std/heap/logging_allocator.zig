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
            return Allocator.init(self, alloc, resize, free);
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
            self: *Self,
            len: usize,
            ptr_align: u29,
            len_align: u29,
            ra: usize,
        ) error{OutOfMemory}![]u8 {
            const result = self.parent_allocator.rawAlloc(len, ptr_align, len_align, ra);
            if (result) |_| {
                logHelper(
                    success_log_level,
                    "alloc - success - len: {}, ptr_align: {}, len_align: {}",
                    .{ len, ptr_align, len_align },
                );
            } else |err| {
                logHelper(
                    failure_log_level,
                    "alloc - failure: {s} - len: {}, ptr_align: {}, len_align: {}",
                    .{ @errorName(err), len, ptr_align, len_align },
                );
            }
            return result;
        }

        fn resize(
            self: *Self,
            buf: []u8,
            buf_align: u29,
            new_len: usize,
            len_align: u29,
            ra: usize,
        ) ?usize {
            if (self.parent_allocator.rawResize(buf, buf_align, new_len, len_align, ra)) |resized_len| {
                if (new_len <= buf.len) {
                    logHelper(
                        success_log_level,
                        "shrink - success - {} to {}, len_align: {}, buf_align: {}",
                        .{ buf.len, new_len, len_align, buf_align },
                    );
                } else {
                    logHelper(
                        success_log_level,
                        "expand - success - {} to {}, len_align: {}, buf_align: {}",
                        .{ buf.len, new_len, len_align, buf_align },
                    );
                }

                return resized_len;
            }

            std.debug.assert(new_len > buf.len);
            logHelper(
                failure_log_level,
                "expand - failure - {} to {}, len_align: {}, buf_align: {}",
                .{ buf.len, new_len, len_align, buf_align },
            );
            return null;
        }

        fn free(
            self: *Self,
            buf: []u8,
            buf_align: u29,
            ra: usize,
        ) void {
            self.parent_allocator.rawFree(buf, buf_align, ra);
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
