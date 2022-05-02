const std = @import("std");
const io = std.io;
const testing = std.testing;

/// Copies from the source to dest until either the end of stream or an error occurs.
/// Data is continuously read from the source into a buffer and then written to dest.
///
/// This function uses a static 4096 byte buffer.
pub fn copy(dest: anytype, source: anytype) !usize {
    var buffer: [4096]u8 = undefined;
    return copyUsingBuffer(dest, source, &buffer);
}

/// Copies from the source to dest until either the end of stream or an error occurs.
/// Data is continuously read from the source into a buffer and then written to dest.
///
/// This function is the same as copy but uses the provided buffer instead of a static one.
pub fn copyUsingBuffer(dest: anytype, source: anytype, buffer: []u8) (error{BufferTooSmall} || @TypeOf(dest).Error || @TypeOf(source).Error)!usize {
    const WriterType = @TypeOf(dest);
    const ReaderType = @TypeOf(source);

    if (!comptime std.meta.trait.hasFn("write")(WriterType)) {
        @compileError("dest must be a io.Writer type");
    }
    if (!comptime std.meta.trait.hasFn("read")(ReaderType)) {
        @compileError("source must be a io.Reader type");
    }

    if (buffer.len <= 0) return error.BufferTooSmall;

    var copied: usize = 0;
    while (true) {
        const n = try source.read(buffer);
        if (n <= 0) return copied;

        const data = buffer[0..n];

        var write_index: usize = 0;
        while (write_index != n) {
            write_index += try dest.write(data[write_index..]);
        }

        copied += n;
    }

    return copied;
}

test "copy empty buffer" {
    var source = io.fixedBufferStream("foobar");

    var dest_buffer: [1024]u8 = undefined;
    var dest = io.fixedBufferStream(&dest_buffer);

    var empty_buffer: [0]u8 = undefined;
    try testing.expectError(error.BufferTooSmall, copyUsingBuffer(dest.writer(), source.reader(), &empty_buffer));
}

test "copy file" {
    var dir = testing.tmpDir(.{});
    defer dir.cleanup();

    var file1 = try dir.dir.createFile("file1.txt", .{ .read = true });
    defer file1.close();
    var file2 = try dir.dir.createFile("file2.txt", .{ .read = true });
    defer file2.close();

    const data = "old_data";

    try file1.writeAll(data);
    try file1.seekTo(0);

    const copied = try copy(file2.writer(), file1.reader());
    try testing.expectEqual(data.len, copied);

    try file2.seekTo(0);
    const file2_data = try file2.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(file2_data);
    try testing.expectEqualStrings(data, file2_data);
}
