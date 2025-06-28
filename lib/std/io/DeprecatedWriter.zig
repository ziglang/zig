const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const native_endian = @import("builtin").target.cpu.arch.endian();

context: *const anyopaque,
writeFn: *const fn (context: *const anyopaque, bytes: []const u8) anyerror!usize,

const Self = @This();
pub const Error = anyerror;

pub fn write(self: Self, bytes: []const u8) anyerror!usize {
    return self.writeFn(self.context, bytes);
}

pub fn writeAll(self: Self, bytes: []const u8) anyerror!void {
    var index: usize = 0;
    while (index != bytes.len) {
        index += try self.write(bytes[index..]);
    }
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
    var bytes: [@divExact(@typeInfo(T).int.bits, 8)]u8 = undefined;
    mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
    return self.writeAll(&bytes);
}

pub fn writeStruct(self: Self, value: anytype) anyerror!void {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(@TypeOf(value)).@"struct".layout != .auto);
    return self.writeAll(mem.asBytes(&value));
}

pub fn writeStructEndian(self: Self, value: anytype, endian: std.builtin.Endian) anyerror!void {
    // TODO: make sure this value is not a reference type
    if (native_endian == endian) {
        return self.writeStruct(value);
    } else {
        var copy = value;
        mem.byteSwapAllFields(@TypeOf(value), &copy);
        return self.writeStruct(copy);
    }
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
