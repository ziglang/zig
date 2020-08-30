const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;

/// An OutStream that returns whether the given character has been written to it.
/// The contents are not written to anything.
pub fn FindByteOutStream(comptime WriterType: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, write);

        writer_pointer: *WriterType,
        byte_found: bool,
        byte: u8,

        pub fn init(byte: u8, writer_pointer: *WriterType) Self {
            return Self{
                .writer_pointer = writer_pointer,
                .byte = byte,
                .byte_found = false,
            };
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        fn write(self: *Self, bytes: []const u8) Error!usize {
            if (!self.byte_found) {
                self.byte_found = blk: {
                    for (bytes) |b|
                        if (b == self.byte) break :blk true;
                    break :blk false;
                };
            }
            return self.writer_pointer.writer().write(bytes);
        }
    };
}
pub fn findByteOutStream(byte: u8, underlying_stream: anytype) FindByteOutStream(@TypeOf(underlying_stream).Child) {
    comptime assert(@typeInfo(@TypeOf(underlying_stream)) == .Pointer);
    return FindByteOutStream(@TypeOf(underlying_stream).Child).init(byte, underlying_stream);
}
