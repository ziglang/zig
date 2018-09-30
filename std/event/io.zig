const std = @import("../index.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

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

        /// Same as `read` but end of stream returns `error.EndOfStream`.
        pub async fn readFull(self: *Self, buf: []u8) !void {
            var index: usize = 0;
            while (index != buf.len) {
                const amt_read = try await (async self.read(buf[index..]) catch unreachable);
                if (amt_read == 0) return error.EndOfStream;
                index += amt_read;
            }
        }

        pub async fn readStruct(self: *Self, comptime T: type, ptr: *T) !void {
            // Only extern and packed structs have defined in-memory layout.
            comptime assert(@typeInfo(T).Struct.layout != builtin.TypeInfo.ContainerLayout.Auto);
            return await (async self.readFull(@sliceToBytes((*[1]T)(ptr)[0..])) catch unreachable);
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
