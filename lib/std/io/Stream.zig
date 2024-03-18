const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const os = std.os;
const iovec = os.iovec;
const iovec_const = os.iovec_const;

context: *const anyopaque,
readvFn: *const fn (context: *const anyopaque, iov: []iovec) anyerror!usize,
writevFn: *const fn (context: *const anyopaque, iov: []iovec_const) anyerror!usize,
closeFn: *const fn (context: *const anyopaque) void,

const Self = @This();
pub const Error = anyerror;

pub fn writev(self: Self, iov: []iovec_const) anyerror!usize {
    return self.writevFn(self.context, iov);
}

/// Returns the number of bytes read. It may be less than buffer.len.
/// If the number of bytes read is 0, it means end of stream.
/// End of stream is not an error condition.
pub fn readv(self: Self, iov: []iovec) anyerror!usize {
    return self.readvFn(self.context, iov);
}

pub fn reader(self: Self) std.io.AnyReader {
    return .{ .context = self.context, .readvFn = self.readvFn };
}

pub fn writer(self: Self) std.io.AnyWriter {
    return .{ .context = self.context, .writevFn = self.writevFn };
}

pub fn close(self: Self) void {
    return self.closeFn(self.context);
}

