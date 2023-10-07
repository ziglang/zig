const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;

pub fn Writer(
    comptime Context: type,
    comptime WriteError: type,
    comptime writeFn: fn (context: Context, bytes: []const u8) WriteError!usize,
) type {
    return struct {
        context: Context,

        const Self = @This();
        pub const Error = WriteError;

        pub fn write(self: Self, bytes: []const u8) Error!usize {
            return writeFn(self.context, bytes);
        }

        pub fn writeAll(self: Self, bytes: []const u8) Error!void {
            var index: usize = 0;
            while (index != bytes.len) {
                index += try self.write(bytes[index..]);
            }
        }

        pub fn print(self: Self, comptime format: []const u8, args: anytype) Error!void {
            return std.fmt.format(self, format, args);
        }

        pub fn writeByte(self: Self, byte: u8) Error!void {
            const array = [1]u8{byte};
            return self.writeAll(&array);
        }

        pub fn writeByteNTimes(self: Self, byte: u8, n: usize) Error!void {
            var bytes: [256]u8 = undefined;
            @memset(bytes[0..], byte);

            var remaining: usize = n;
            while (remaining > 0) {
                const to_write = @min(remaining, bytes.len);
                try self.writeAll(bytes[0..to_write]);
                remaining -= to_write;
            }
        }

        /// Write a native-endian integer.
        pub fn writeIntNative(self: Self, comptime T: type, value: T) Error!void {
            var bytes: [@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8))]u8 = undefined;
            mem.writeIntNative(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value);
            return self.writeAll(&bytes);
        }

        /// Write a foreign-endian integer.
        pub fn writeIntForeign(self: Self, comptime T: type, value: T) Error!void {
            var bytes: [@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8))]u8 = undefined;
            mem.writeIntForeign(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value);
            return self.writeAll(&bytes);
        }

        pub fn writeIntLittle(self: Self, comptime T: type, value: T) Error!void {
            var bytes: [@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8))]u8 = undefined;
            mem.writeIntLittle(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value);
            return self.writeAll(&bytes);
        }

        pub fn writeIntBig(self: Self, comptime T: type, value: T) Error!void {
            var bytes: [@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8))]u8 = undefined;
            mem.writeIntBig(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value);
            return self.writeAll(&bytes);
        }

        pub fn writeInt(self: Self, comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
            var bytes: [@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8))]u8 = undefined;
            mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
            return self.writeAll(&bytes);
        }

        pub fn writeStruct(self: Self, value: anytype) Error!void {
            // Only extern and packed structs have defined in-memory layout.
            comptime assert(@typeInfo(@TypeOf(value)).Struct.layout != .Auto);
            return self.writeAll(mem.asBytes(&value));
        }
    };
}
