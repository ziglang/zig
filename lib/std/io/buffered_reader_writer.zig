const std = @import("../std.zig");
const io = std.io;
const meta = std.meta;

/// Provides both `io.BufferedReader` and `io.BufferedWriter` interface for stream or file.
pub fn BufferedReaderWriter(comptime read_size: usize, comptime write_size: usize, comptime ReaderWriter: type) type {
    return struct {
        const Self = @This();
        pub const Container = if (meta.trait.isContainer(ReaderWriter)) ReaderWriter else meta.Child(ReaderWriter);
        pub const ReadError = if (@hasDecl(Container, "ReadError")) Container.ReadError else Container.Error;
        pub const WriteError = if (@hasDecl(Container, "WriteError")) Container.WriteError else Container.Error;

        pub const Reader = io.Reader(*Self, ReadError, read);
        pub const Writer = io.Writer(*Self, WriteError, write);

        pub const BufferedReader = io.BufferedReader(read_size, 0, ReaderWriter);
        pub const BufferedWriter = io.BufferedWriter(write_size, ReaderWriter);

        buffered_reader: BufferedReader,
        buffered_writer: BufferedWriter,

        pub fn init(unbuffered: ReaderWriter) Self {
            return Self{ .buffered_reader = .{
                .unbuffered_reader = unbuffered,
            }, .buffered_writer = .{
                .unbuffered_writer = unbuffered,
            } };
        }

        /// Return reader buffer to user directly.
        pub fn peek(self: *Self, least: usize) []const u8 {
            return self.buffered_reader.peek(least);
        }

        /// Froward reader buffer cursor position after peeking data.
        pub fn discard(self: *Self, num: usize) ReadError!void {
            try self.buffered_reader.discard(num);
        }

        pub fn read(self: *Self, dest: []u8) ReadError!usize {
            return self.buffered_reader.read(dest);
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        /// Flush buffered write to underlying writer.
        pub fn flush(self: *Self) WriteError!void {
            return self.buffered_writer.flush();
        }

        pub fn write(self: *Self, data: []const u8) WriteError!usize {
            return self.buffered_writer.write(data);
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}
