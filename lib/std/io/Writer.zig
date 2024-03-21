const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const WriteBuffers = std.io.WriteBuffers;

context: *const anyopaque,
writevFn: *const fn (context: *const anyopaque, iov: []WriteBuffers) anyerror!usize,

const Self = @This();
pub const Error = anyerror;

pub fn writev(self: Self, iov: []WriteBuffers) anyerror!usize {
    return self.writevFn(self.context, iov);
}

pub fn writevAll(self: Self, iovecs: []WriteBuffers) anyerror!void {
    if (iovecs.len == 0) return;

    var i: usize = 0;
    while (true) {
        var amt = try self.writev(iovecs[i..]);
        while (amt >= iovecs[i].len) {
            amt -= iovecs[i].len;
            i += 1;
            if (i >= iovecs.len) return;
        }
        iovecs[i].ptr += amt;
        iovecs[i].len -= amt;
    }
}

pub fn write(self: Self, bytes: []const u8) anyerror!usize {
    var iov = [_]WriteBuffers{.{ .ptr = bytes.ptr, .len = bytes.len }};
    return self.writev(&iov);
}

pub fn writeAll(self: Self, bytes: []const u8) anyerror!void {
    var iov = [_]WriteBuffers{.{ .ptr = bytes.ptr, .len = bytes.len }};
    return self.writevAll(&iov);
}

pub fn print(self: Self, comptime format: []const u8, args: anytype) anyerror!void {
    return std.fmt.format(self, format, args);
}

pub fn writeByte(self: Self, byte: u8) anyerror!void {
    const array = [1]u8{byte};
    return self.writeAll(&array);
}

pub fn writeByteNTimes(self: Self, byte: u8, n: usize) anyerror!void {
    var bytes: [256]u8 = undefined;
    @memset(bytes[0..], byte);

    var remaining: usize = n;
    while (remaining > 0) {
        const to_write = @min(remaining, bytes.len);
        try self.writeAll(bytes[0..to_write]);
        remaining -= to_write;
    }
}

pub fn writeBytesNTimes(self: Self, bytes: []const u8, n: usize) anyerror!void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        try self.writeAll(bytes);
    }
}

pub inline fn writeInt(self: Self, comptime T: type, value: T, endian: std.builtin.Endian) anyerror!void {
    var bytes: [@divExact(@typeInfo(T).Int.bits, 8)]u8 = undefined;
    mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
    return self.writeAll(&bytes);
}

pub fn writeStruct(self: Self, value: anytype) anyerror!void {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(@TypeOf(value)).Struct.layout != .auto);
    return self.writeAll(mem.asBytes(&value));
}

pub fn writeFile(self: Self, file: std.fs.File) anyerror!void {
    // TODO: figure out how to adjust std lib abstractions so that this ends up
    // doing sendfile or maybe even copy_file_range under the right conditions.
    var buf: [4000]u8 = undefined;
    while (true) {
        const n = try file.readAll(&buf);
        try self.writeAll(buf[0..n]);
        if (n < buf.len) return;
    }
}
