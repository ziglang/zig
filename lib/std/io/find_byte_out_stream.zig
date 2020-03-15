const std = @import("../std.zig");
const io = std.io;
const assert = std.debug.assert;

// An OutStream that returns whether the given character has been written to it.
// The contents are not written to anything.
pub fn FindByteOutStream(comptime OutStreamType: type) type {
    return struct {
        const Self = @This();
        pub const Error = OutStreamType.Error;
        pub const OutStream = io.OutStream(*Self, Error, write);

        out_stream: *OutStreamType,
        byte_found: bool,
        byte: u8,

        pub fn init(byte: u8, out_stream: *OutStreamType) Self {
            return Self{
                .out_stream = out_stream,
                .byte = byte,
                .byte_found = false,
            };
        }

        pub fn outStream(self: *Self) OutStream {
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
            return self.out_stream.outStream().write(bytes);
        }
    };
}
pub fn findByteOutStream(byte: u8, underlying_stream: var) FindByteOutStream(@TypeOf(underlying_stream).Child) {
    comptime assert(@typeInfo(@TypeOf(underlying_stream)) == .Pointer);
    return FindByteOutStream(@TypeOf(underlying_stream).Child).init(byte, underlying_stream);
}
