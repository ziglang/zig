const std = @import("../std.zig");
const io = std.io;
const mem = std.mem;
const assert = std.debug.assert;

pub fn ChangeDetectionStream(comptime OutStreamType: type) type {
    return struct {
        const Self = @This();
        pub const Error = OutStreamType.Error;
        pub const OutStream = io.OutStream(*Self, Error, write);

        anything_changed: bool = false,
        out_stream: *OutStreamType,
        source_index: usize,
        source: []const u8,

        pub fn init(source: []const u8, out_stream: *OutStreamType) Self {
            return Self{
                .out_stream = out_stream,
                .source_index = 0,
                .source = source,
            };
        }

        pub fn outStream(self: *Self) OutStream {
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

            return self.out_stream.write(bytes);
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
