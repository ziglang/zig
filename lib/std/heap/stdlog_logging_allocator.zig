// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

/// This allocator is used in front of another allocator and logs to `std.log`
/// on every call to the allocator.
pub fn StdLogLoggingAllocator(
    comptime success_log_level: std.log.Level,
    comptime failure_log_level: std.log.Level,
) type {
    return ScopedStdLogLoggingAllocator(.default, success_log_level, failure_log_level);
}

/// This allocator is used in front of another allocator and logs to `std.log`
/// with the given scope on every call to the allocator.
pub fn ScopedStdLogLoggingAllocator(
    comptime scope: @Type(.EnumLiteral),
    comptime success_log_level: std.log.Level,
    comptime failure_log_level: std.log.Level,
) type {
    const log = std.log.scoped(scope);

    return struct {
        allocator: Allocator,
        parent_allocator: *Allocator,

        const Self = @This();

        pub fn init(parent_allocator: *Allocator) Self {
            return .{ .allocator = Allocator{
                .allocFn = alloc,
                .resizeFn = resize,
            }, .parent_allocator = parent_allocator };
        }

        // This function is required as the `std.log.log` function is not public
        fn logHelper(comptime log_level: std.log.Level, comptime format: []const u8, args: anytype) callconv(.Inline) void {
            switch (log_level) {
                .emerg => log.emerg(format, args),
                .alert => log.alert(format, args),
                .crit => log.crit(format, args),
                .err => log.err(format, args),
                .warn => log.warn(format, args),
                .notice => log.notice(format, args),
                .info => log.info(format, args),
                .debug => log.debug(format, args),
            }
        }

        fn alloc(
            allocator: *Allocator,
            len: usize,
            ptr_align: u29,
            len_align: u29,
            ra: usize,
        ) error{OutOfMemory}![]u8 {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            const result = self.parent_allocator.allocFn(self.parent_allocator, len, ptr_align, len_align, ra);
            if (result) |buff| {
                logHelper(success_log_level, "alloc: {} success!", .{len});
            } else |err| {
                logHelper(failure_log_level, "alloc: {} failure!", .{len});
            }
            return result;
        }

        fn resize(
            allocator: *Allocator,
            buf: []u8,
            buf_align: u29,
            new_len: usize,
            len_align: u29,
            ra: usize,
        ) error{OutOfMemory}!usize {
            const self = @fieldParentPtr(Self, "allocator", allocator);

            if (self.parent_allocator.resizeFn(self.parent_allocator, buf, buf_align, new_len, len_align, ra)) |resized_len| {
                if (new_len == 0) {
                    logHelper(success_log_level, "free: {} success!", .{buf.len});
                } else if (new_len <= buf.len) {
                    logHelper(success_log_level, "shrink: {} to {} success!", .{ buf.len, new_len });
                } else {
                    logHelper(success_log_level, "expand: {} to {} success!", .{ buf.len, new_len });
                }

                return resized_len;
            } else |e| {
                std.debug.assert(new_len > buf.len);
                logHelper(failure_log_level, "expand: {} to {} failure!", .{ buf.len, new_len });
                return e;
            }
        }
    };
}


pub fn stdLogLoggingAllocator(parent_allocator: *Allocator) StdLogLoggingAllocator(.debug, .crit) {
    return StdLogLoggingAllocator(.debug, .crit).init(parent_allocator);
}
