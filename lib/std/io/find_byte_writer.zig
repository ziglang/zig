const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;

/// A Writer that returns whether the given character has been written to it.
/// The contents are not written to anything.
pub fn FindByteWriter(comptime UnderlyingWriter: type) type {
    return struct {
        const Self = @This();
        pub const Error = UnderlyingWriter.Error;
        pub const Writer = io.Writer(*Self, Error, write);

        underlying_writer: UnderlyingWriter,
        byte_found: bool,
        byte: u8,

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
            return self.underlying_writer.write(bytes);
        }
    };
}

pub fn findByteWriter(byte: u8, underlying_writer: anytype) FindByteWriter(@TypeOf(underlying_writer)) {
    return FindByteWriter(@TypeOf(underlying_writer)){
        .underlying_writer = underlying_writer,
        .byte = byte,
        .byte_found = false,
    };
}
