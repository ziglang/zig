//! A Reader that counts how many bytes has been read from it.

const std = @import("../std.zig");
const CountingReader = @This();

child_reader: std.io.Reader,
bytes_read: u64 = 0,

pub fn read(self: *@This(), buf: []u8) anyerror!usize {
    const amt = try self.child_reader.read(buf);
    self.bytes_read += amt;
    return amt;
}

pub fn reader(self: *@This()) std.io.Reader {
    return .{ .context = self };
}

test CountingReader {
    const bytes = "yay" ** 20;
    var fbs: std.io.BufferedReader = undefined;
    fbs.initFixed(bytes);
    var counting_stream: CountingReader = .{ .child_reader = fbs.reader() };
    var stream = counting_stream.reader().unbuffered();
    while (stream.readByte()) |_| {} else |err| {
        try std.testing.expectError(error.EndOfStream, err);
    }
    try std.testing.expect(counting_stream.bytes_read == bytes.len);
}
