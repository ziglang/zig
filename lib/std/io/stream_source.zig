const std = @import("../std.zig");
const builtin = @import("builtin");
const io = std.io;

/// Provides `io.SeekableReader` and `io.SeekableWriter` for in-memory buffers as
/// well as files.
/// For memory sources, if the supplied byte buffer is const, then `io.Writer` is not available.
/// The error set of the stream functions is the error set of the corresponding file functions.
pub const StreamSource = union(enum) {
    const has_file = (builtin.os.tag != .freestanding);

    /// The stream access is redirected to this buffer.
    buffer: io.FixedBufferStream([]u8),

    /// The stream access is redirected to this buffer.
    /// Writing to the source will always yield `error.AccessDenied`.
    const_buffer: io.FixedBufferStream([]const u8),

    /// The stream access is redirected to this file.
    /// On freestanding, this must never be initialized!
    readable_file: if (has_file) io.BufferedReader(4096, std.fs.File.Reader) else void,
    writeable_file: if (has_file) io.BufferedWriter(4096, std.fs.File.Writer) else void,

    const ReadSeekError = if (has_file) io.BufferedReader(4096, std.fs.File.Reader).SeekError else error{};
    const WriteSeekError = if (has_file) io.BufferedWriter(4096, std.fs.File.Writer).SeekError else error{};
    pub const ReadError = io.FixedBufferStream([]u8).ReadError || (if (has_file) std.fs.File.ReadError else error{});
    pub const WriteError = error{AccessDenied} || io.FixedBufferStream([]u8).WriteError || (if (has_file) std.fs.File.WriteError else error{});
    pub const SeekError = io.FixedBufferStream([]u8).SeekError || (if (has_file) ReadSeekError || WriteSeekError else error{});
    pub const GetSeekPosError = io.FixedBufferStream([]u8).GetSeekPosError || (if (has_file) std.fs.File.GetSeekPosError else error{});

    pub const Reader = io.SeekableReader(*StreamSource, ReadError, read);
    pub const Writer = io.SeekableWriter(*StreamSource, WriteError, write);

    pub fn fromBuffer(buffer: []u8) StreamSource {
        return .{ .buffer = io.fixedBufferStream(buffer) };
    }

    pub fn fromConstBuffer(buffer: []const u8) StreamSource {
        return .{ .const_buffer = io.fixedBufferStream(buffer) };
    }

    pub usingnamespace if (has_file) struct {
        pub fn fromFileReader(file_reader: std.fs.File.Reader) StreamSource {
            return .{ .readable_file = io.bufferedReader(file_reader) };
        }

        pub fn fromFileWriter(file_writer: std.fs.File.Writer) StreamSource {
            return .{ .writeable_file = io.bufferedWriter(file_writer) };
        }
    } else struct {};

    pub fn read(self: *StreamSource, dest: []u8) ReadError!usize {
        switch (self.*) {
            .buffer => |*x| return x.read(dest),
            .const_buffer => |*x| return x.read(dest),
            .readable_file => |*x| if (!has_file) unreachable else return x.read(dest),
            .writeable_file => if (!has_file) unreachable else return error.NotOpenForReading,
        }
    }

    pub fn write(self: *StreamSource, bytes: []const u8) WriteError!usize {
        switch (self.*) {
            .buffer => |*x| return x.write(bytes),
            .const_buffer => return error.AccessDenied,
            .writeable_file => |*x| if (!has_file) unreachable else return x.write(bytes),
            .readable_file => if (!has_file) unreachable else return error.NotOpenForWriting,
        }
    }

    pub fn seekTo(self: *StreamSource, pos: u64) SeekError!void {
        switch (self.*) {
            .buffer => |*x| return x.seekTo(pos),
            .const_buffer => |*x| return x.seekTo(pos),
            .readable_file => |*x| if (!has_file) unreachable else return x.seekTo(pos),
            .writeable_file => |*x| if (!has_file) unreachable else return x.seekTo(pos),
        }
    }

    pub fn seekBy(self: *StreamSource, amt: i64) SeekError!void {
        switch (self.*) {
            .buffer => |*x| return x.seekBy(amt),
            .const_buffer => |*x| return x.seekBy(amt),
            .readable_file => |*x| if (!has_file) unreachable else return x.seekBy(amt),
            .writeable_file => |*x| if (!has_file) unreachable else return x.seekBy(amt),
        }
    }

    pub fn getEndPos(self: *StreamSource) GetSeekPosError!u64 {
        switch (self.*) {
            .buffer => |*x| return x.getEndPos(),
            .const_buffer => |*x| return x.getEndPos(),
            .readable_file => |*x| if (!has_file) unreachable else return x.getEndPos(),
            .writeable_file => |*x| if (!has_file) unreachable else return x.getEndPos(),
        }
    }

    pub fn getPos(self: *StreamSource) GetSeekPosError!u64 {
        switch (self.*) {
            .buffer => |*x| return x.getPos(),
            .const_buffer => |*x| return x.getPos(),
            .readable_file => |*x| if (!has_file) unreachable else return x.getPos(),
            .writeable_file => |*x| if (!has_file) unreachable else return x.getPos(),
        }
    }

    pub fn reader(self: *StreamSource) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *StreamSource) Writer {
        return .{ .context = self };
    }
};

test "StreamSource (refs)" {
    std.testing.refAllDecls(StreamSource);
}

test "StreamSource (mutable buffer)" {
    var buffer: [64]u8 = undefined;
    var source = StreamSource.fromBuffer(&buffer);

    var writer = source.writer();

    try writer.writeAll("Hello, World!");

    try std.testing.expectEqualStrings("Hello, World!", source.buffer.getWritten());
}

test "StreamSource (const buffer)" {
    const buffer: [64]u8 = "Hello, World!".* ++ ([1]u8{0xAA} ** 51);
    var source = StreamSource.fromConstBuffer(&buffer);

    var reader = source.reader();

    var dst_buffer: [13]u8 = undefined;
    try reader.readNoEof(&dst_buffer);

    try std.testing.expectEqualStrings("Hello, World!", &dst_buffer);
}
