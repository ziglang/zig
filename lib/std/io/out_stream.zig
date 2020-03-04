const std = @import("../std.zig");
const builtin = @import("builtin");
const root = @import("root");
const mem = std.mem;

pub const default_stack_size = 1 * 1024 * 1024;
pub const stack_size: usize = if (@hasDecl(root, "stack_size_std_io_OutStream"))
    root.stack_size_std_io_OutStream
else
    default_stack_size;

pub fn OutStream(comptime WriteError: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriteError;
        pub const WriteFn = if (std.io.is_async)
            async fn (self: *Self, bytes: []const u8) Error!usize
        else
            fn (self: *Self, bytes: []const u8) Error!usize;

        writeFn: WriteFn,

        pub fn writeOnce(self: *Self, bytes: []const u8) Error!usize {
            if (std.io.is_async) {
                // Let's not be writing 0xaa in safe modes for upwards of 4 MiB for every stream write.
                @setRuntimeSafety(false);
                var stack_frame: [stack_size]u8 align(std.Target.stack_align) = undefined;
                return await @asyncCall(&stack_frame, {}, self.writeFn, self, bytes);
            } else {
                return self.writeFn(self, bytes);
            }
        }

        pub fn write(self: *Self, bytes: []const u8) Error!void {
            var index: usize = 0;
            while (index != bytes.len) {
                index += try self.writeOnce(bytes[index..]);
            }
        }

        pub fn print(self: *Self, comptime format: []const u8, args: var) Error!void {
            return std.fmt.format(self, Error, write, format, args);
        }

        pub fn writeByte(self: *Self, byte: u8) Error!void {
            const array = [1]u8{byte};
            return self.write(&array);
        }

        pub fn writeByteNTimes(self: *Self, byte: u8, n: usize) Error!void {
            var bytes: [256]u8 = undefined;
            mem.set(u8, bytes[0..], byte);

            var remaining: usize = n;
            while (remaining > 0) {
                const to_write = std.math.min(remaining, bytes.len);
                try self.write(bytes[0..to_write]);
                remaining -= to_write;
            }
        }

        /// Write a native-endian integer.
        pub fn writeIntNative(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [(T.bit_count + 7) / 8]u8 = undefined;
            mem.writeIntNative(T, &bytes, value);
            return self.write(&bytes);
        }

        /// Write a foreign-endian integer.
        pub fn writeIntForeign(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [(T.bit_count + 7) / 8]u8 = undefined;
            mem.writeIntForeign(T, &bytes, value);
            return self.write(&bytes);
        }

        pub fn writeIntLittle(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [(T.bit_count + 7) / 8]u8 = undefined;
            mem.writeIntLittle(T, &bytes, value);
            return self.write(&bytes);
        }

        pub fn writeIntBig(self: *Self, comptime T: type, value: T) Error!void {
            var bytes: [(T.bit_count + 7) / 8]u8 = undefined;
            mem.writeIntBig(T, &bytes, value);
            return self.write(&bytes);
        }

        pub fn writeInt(self: *Self, comptime T: type, value: T, endian: builtin.Endian) Error!void {
            var bytes: [(T.bit_count + 7) / 8]u8 = undefined;
            mem.writeInt(T, &bytes, value, endian);
            return self.write(&bytes);
        }
    };
}
