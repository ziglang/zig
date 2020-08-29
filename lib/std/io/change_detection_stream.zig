const std = @import("../std.zig");
const io = std.io;
const mem = std.mem;
const assert = std.debug.assert;

/// Used to detect if the data written to a stream differs from a source buffer
pub fn ChangeDetectionStream(comptime WriterType: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, write);

        anything_changed: bool = false,
        writer_pointer: *WriterType,
        source_index: usize,
        source: []const u8,

        pub fn init(source: []const u8, writer_pointer: *WriterType) Self {
            return Self{
                .writer_pointer = writer_pointer,
                .source_index = 0,
                .source = source,
            };
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        fn write(self: *Self, bytes: []const u8) Error!usize {
            if (!self.anything_changed) {
                const end = self.source_index + bytes.len;
                if (end > self.source.len) {
                    self.anything_changed = true;
                } else {
                    const src_slice = self.source[self.source_index..end];
                    self.source_index += bytes.len;
                    if (!mem.eql(u8, bytes, src_slice)) {
                        self.anything_changed = true;
                    }
                }
            }

            return self.writer_pointer.write(bytes);
        }

        pub fn changeDetected(self: *Self) bool {
            return self.anything_changed or (self.source_index != self.source.len);
        }
    };
}

pub fn changeDetectionStream(
    source: []const u8,
    underlying_stream: anytype,
) ChangeDetectionStream(@TypeOf(underlying_stream).Child) {
    comptime assert(@typeInfo(@TypeOf(underlying_stream)) == .Pointer);
    return ChangeDetectionStream(@TypeOf(underlying_stream).Child).init(source, underlying_stream);
}
