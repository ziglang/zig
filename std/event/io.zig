const std = @import("../index.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const mem = std.mem;

pub fn InStream(comptime ReadError: type) type {
    return struct {
        const Self = @This();
        pub const Error = ReadError;

        /// Return the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        readFn: async<*Allocator> fn (self: *Self, buffer: []u8) Error!usize,

        /// Return the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        pub async fn read(self: *Self, buffer: []u8) !usize {
            return await (async self.readFn(self, buffer) catch unreachable);
        }

        /// Return the number of bytes read. If it is less than buffer.len
        /// it means end of stream.
        pub async fn readFull(self: *Self, buffer: []u8) !usize {
            var index: usize = 0;
            while (index != buf.len) {
                const amt_read = try await (async self.read(buf[index..]) catch unreachable);
                if (amt_read == 0) return index;
                index += amt_read;
            }
            return index;
        }

        /// Same as `readFull` but end of stream returns `error.EndOfStream`.
        pub async fn readNoEof(self: *Self, buf: []u8) !void {
            const amt_read = try await (async self.readFull(buf[index..]) catch unreachable);
            if (amt_read < buf.len) return error.EndOfStream;
        }

        pub async fn readIntLe(self: *Self, comptime T: type) !T {
            return await (async self.readInt(T, builtin.Endian.Little) catch unreachable);
        }

        pub async fn readIntBe(self: *Self, comptime T: type) !T {
            return await (async self.readInt(T, builtin.Endian.Big) catch unreachable);
        }

        pub async fn readInt(self: *Self, comptime T: type, endian: builtin.Endian) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try await (async self.readNoEof(bytes[0..]) catch unreachable);
            return mem.readInt(T, bytes, endian);
        }

        pub async fn readStruct(self: *Self, comptime T: type) !T {
            // Only extern and packed structs have defined in-memory layout.
            comptime assert(@typeInfo(T).Struct.layout != builtin.TypeInfo.ContainerLayout.Auto);
            var res: [1]T = undefined;
            try await (async self.readNoEof(@sliceToBytes(res[0..])) catch unreachable);
            return res[0];
        }
    };
}

pub fn OutStream(comptime WriteError: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriteError;

        writeFn: async<*Allocator> fn (self: *Self, buffer: []u8) Error!void,
    };
}
