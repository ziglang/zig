const std = @import("../std.zig");
const math = std.math;
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;

/// Seek whence union values.
pub const Whence = union(enum) {
    /// Seek offset relative to the start of file.
    start: u64,
    /// Seek offset relative to the current offset.
    current: i64,
    /// Seek offset relative to the end of file.
    end: i64,
    // data: i64,
    // hole: i64,
    /// Shrinks or expands file size.
    set_end_pos: u64,
    /// Get file size.
    get_end_pos: void,
};

/// A Seeker turn a stream into an seekable stream.
///
/// Seek emulates conventional posix lseek function and extends
/// a few of commands for extra functions.
/// The Seeker provides a hand of helpers work on top of seek.
pub fn Seeker(
    comptime Context: type,
    comptime SeekError: type,
    /// Seek sets the offset for the next step read or write. On success,
    /// it returns the the new offset relative the start of file.
    comptime seekFn: fn (context: Context, whence: Whence) SeekError!u64,
) type {
    return struct {
        context: Context,

        const Self = @This();
        pub const Error = SeekError;

        /// Get file size.
        pub fn getEndPos(self: Self) Error!u64 {
            return seekFn(self.context, .{ .get_end_pos = {} });
        }

        /// Set file size.
        pub fn setEndPos(self: Self, pos: u64) Error!void {
            _ = try seekFn(self.context, .{ .set_end_pos = pos });
        }

        /// Get current offset of file.
        pub fn getPos(self: Self) Error!u64 {
            return seekFn(self.context, .{ .current = 0 });
        }

        /// Seek to the start of file.
        pub fn rewind(self: Self) Error!void {
            _ = try seekFn(self.context, .{ .start = 0 });
        }

        pub fn seek(self: Self, whence: Whence) Error!u64 {
            return seekFn(self.context, whence);
        }

        /// Seek offset relative to current position.
        pub fn seekBy(self: Self, amt: i64) Error!void {
            _ = try seekFn(self.context, .{ .current = amt });
        }

        /// Seek offset relative to the end of file.
        pub fn seekFromEnd(self: Self, pos: i64) Error!void {
            _ = try seekFn(self.context, .{ .end = pos });
        }

        /// Seek offset relative to the start of file.
        pub fn seekTo(self: Self, pos: u64) Error!void {
            _ = try seekFn(self.context, .{ .start = pos });
        }
    };
}
