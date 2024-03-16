const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const os = std.os;

context: *const anyopaque,
writeFn: *const fn (context: *const anyopaque, bytes: []const u8) anyerror!usize,
readFn: *const fn (context: *const anyopaque, buffer: []u8) anyerror!usize,
closeFn: *const fn (context: *const anyopaque) void,

const Self = @This();
pub const Error = anyerror;

pub fn write(self: Self, bytes: []const u8) anyerror!usize {
    return self.writeFn(self.context, bytes);
}

/// Returns the number of bytes read. It may be less than buffer.len.
/// If the number of bytes read is 0, it means end of stream.
/// End of stream is not an error condition.
pub fn read(self: Self, buffer: []u8) anyerror!usize {
    return self.readFn(self.context, buffer);
}

pub fn close(self: Self) void {
    return self.closeFn(self.context);
}

pub fn reader(self: Self) std.io.AnyReader {
    return .{ .context = self.context, .readFn = self.readFn };
}

pub fn writer(self: Self) std.io.AnyWriter {
    return .{ .context = self.context, .writeFn = self.writeFn };
}

