const builtin = @import("builtin");
const std = @import("../../std.zig");
const testing = std.testing;

test "Reader" {
    var buf = "a\x02".*;
    var fis = std.io.fixedBufferStream(&buf);
    const reader = fis.reader();
    try testing.expect((try reader.readByte()) == 'a');
    try testing.expect((try reader.readEnum(enum(u8) {
        a = 0,
        b = 99,
        c = 2,
        d = 3,
    }, builtin.cpu.arch.endian())) == .c);
    try testing.expectError(error.EndOfStream, reader.readByte());
}

test "isBytes" {
    var fis = std.io.fixedBufferStream("foobar");
    const reader = fis.reader();
    try testing.expectEqual(true, try reader.isBytes("foo"));
    try testing.expectEqual(false, try reader.isBytes("qux"));
}

test "skipBytes" {
    var fis = std.io.fixedBufferStream("foobar");
    const reader = fis.reader();
    try reader.skipBytes(3, .{});
    try testing.expect(try reader.isBytes("bar"));
    try reader.skipBytes(0, .{});
    try testing.expectError(error.EndOfStream, reader.skipBytes(1, .{}));
}

test "readUntilDelimiterArrayList returns ArrayLists with bytes read until the delimiter, then EndOfStream" {
    const a = std.testing.allocator;
    var list = std.ArrayList(u8).init(a);
    defer list.deinit();

    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();

    try reader.readUntilDelimiterArrayList(&list, '\n', 5);
    try std.testing.expectEqualStrings("0000", list.items);
    try reader.readUntilDelimiterArrayList(&list, '\n', 5);
    try std.testing.expectEqualStrings("1234", list.items);
    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiterArrayList(&list, '\n', 5));
}

test "readUntilDelimiterArrayList returns an empty ArrayList" {
    const a = std.testing.allocator;
    var list = std.ArrayList(u8).init(a);
    defer list.deinit();

    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();

    try reader.readUntilDelimiterArrayList(&list, '\n', 5);
    try std.testing.expectEqualStrings("", list.items);
}

test "readUntilDelimiterArrayList returns StreamTooLong, then an ArrayList with bytes read until the delimiter" {
    const a = std.testing.allocator;
    var list = std.ArrayList(u8).init(a);
    defer list.deinit();

    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();

    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterArrayList(&list, '\n', 5));
    try std.testing.expectEqualStrings("12345", list.items);
    try reader.readUntilDelimiterArrayList(&list, '\n', 5);
    try std.testing.expectEqualStrings("67", list.items);
}

test "readUntilDelimiterArrayList returns EndOfStream" {
    const a = std.testing.allocator;
    var list = std.ArrayList(u8).init(a);
    defer list.deinit();

    var fis = std.io.fixedBufferStream("1234");
    const reader = fis.reader();

    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiterArrayList(&list, '\n', 5));
    try std.testing.expectEqualStrings("1234", list.items);
}

test "readUntilDelimiterAlloc returns ArrayLists with bytes read until the delimiter, then EndOfStream" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();

    {
        const result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
        defer a.free(result);
        try std.testing.expectEqualStrings("0000", result);
    }

    {
        const result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
        defer a.free(result);
        try std.testing.expectEqualStrings("1234", result);
    }

    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiterAlloc(a, '\n', 5));
}

test "readUntilDelimiterAlloc returns an empty ArrayList" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();

    {
        const result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
        defer a.free(result);
        try std.testing.expectEqualStrings("", result);
    }
}

test "readUntilDelimiterAlloc returns StreamTooLong, then an ArrayList with bytes read until the delimiter" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();

    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterAlloc(a, '\n', 5));

    const result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
    defer a.free(result);
    try std.testing.expectEqualStrings("67", result);
}

test "readUntilDelimiterAlloc returns EndOfStream" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("1234");
    const reader = fis.reader();

    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiterAlloc(a, '\n', 5));
}

test "readUntilDelimiter returns bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("0000", try reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("1234", try reader.readUntilDelimiter(&buf, '\n'));
}

test "readUntilDelimiter returns an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("", try reader.readUntilDelimiter(&buf, '\n'));
}

test "readUntilDelimiter returns StreamTooLong, then an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("12345\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("", try reader.readUntilDelimiter(&buf, '\n'));
}

test "readUntilDelimiter returns StreamTooLong, then bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("67", try reader.readUntilDelimiter(&buf, '\n'));
}

test "readUntilDelimiter returns EndOfStream" {
    {
        var buf: [5]u8 = undefined;
        var fis = std.io.fixedBufferStream("");
        const reader = fis.reader();
        try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiter(&buf, '\n'));
    }
    {
        var buf: [5]u8 = undefined;
        var fis = std.io.fixedBufferStream("1234");
        const reader = fis.reader();
        try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiter(&buf, '\n'));
    }
}

test "readUntilDelimiter returns bytes read until delimiter, then EndOfStream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("1234", try reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiter(&buf, '\n'));
}

test "readUntilDelimiter returns StreamTooLong, then EndOfStream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("12345");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiter(&buf, '\n'));
}

test "readUntilDelimiter writes all bytes read to the output buffer" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n12345");
    const reader = fis.reader();
    _ = try reader.readUntilDelimiter(&buf, '\n');
    try std.testing.expectEqualStrings("0000\n", &buf);
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("12345", &buf);
}

test "readUntilDelimiterOrEofAlloc returns ArrayLists with bytes read until the delimiter, then EndOfStream" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();

    {
        const result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
        defer a.free(result);
        try std.testing.expectEqualStrings("0000", result);
    }

    {
        const result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
        defer a.free(result);
        try std.testing.expectEqualStrings("1234", result);
    }

    try std.testing.expect((try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)) == null);
}

test "readUntilDelimiterOrEofAlloc returns an empty ArrayList" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();

    {
        const result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
        defer a.free(result);
        try std.testing.expectEqualStrings("", result);
    }
}

test "readUntilDelimiterOrEofAlloc returns StreamTooLong, then an ArrayList with bytes read until the delimiter" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();

    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEofAlloc(a, '\n', 5));

    const result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
    defer a.free(result);
    try std.testing.expectEqualStrings("67", result);
}

test "readUntilDelimiterOrEof returns bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("0000", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
    try std.testing.expectEqualStrings("1234", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "readUntilDelimiterOrEof returns an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "readUntilDelimiterOrEof returns StreamTooLong, then an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("12345\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "readUntilDelimiterOrEof returns StreamTooLong, then bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("67", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "readUntilDelimiterOrEof returns null" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("");
    const reader = fis.reader();
    try std.testing.expect((try reader.readUntilDelimiterOrEof(&buf, '\n')) == null);
}

test "readUntilDelimiterOrEof returns bytes read until delimiter, then null" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("1234", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
    try std.testing.expect((try reader.readUntilDelimiterOrEof(&buf, '\n')) == null);
}

test "readUntilDelimiterOrEof returns bytes read until end-of-stream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("1234", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "readUntilDelimiterOrEof returns StreamTooLong, then bytes read until end-of-stream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234567");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("67", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "readUntilDelimiterOrEof writes all bytes read to the output buffer" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n12345");
    const reader = fis.reader();
    _ = try reader.readUntilDelimiterOrEof(&buf, '\n');
    try std.testing.expectEqualStrings("0000\n", &buf);
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("12345", &buf);
}

test "streamUntilDelimiter writes all bytes without delimiter to the output" {
    const input_string = "some_string_with_delimiter!";
    var input_fbs = std.io.fixedBufferStream(input_string);
    const reader = input_fbs.reader();

    var output: [input_string.len]u8 = undefined;
    var output_fbs = std.io.fixedBufferStream(&output);
    const writer = output_fbs.writer();

    try reader.streamUntilDelimiter(writer, '!', input_fbs.buffer.len);
    try std.testing.expectEqualStrings("some_string_with_delimiter", output_fbs.getWritten());
    try std.testing.expectError(error.EndOfStream, reader.streamUntilDelimiter(writer, '!', input_fbs.buffer.len));

    input_fbs.reset();
    output_fbs.reset();

    try std.testing.expectError(error.StreamTooLong, reader.streamUntilDelimiter(writer, '!', 5));
}

test "readBoundedBytes correctly reads into a new bounded array" {
    const test_string = "abcdefg";
    var fis = std.io.fixedBufferStream(test_string);
    const reader = fis.reader();

    var array = try reader.readBoundedBytes(10000);
    try testing.expectEqualStrings(array.slice(), test_string);
}

test "readIntoBoundedBytes correctly reads into a provided bounded array" {
    const test_string = "abcdefg";
    var fis = std.io.fixedBufferStream(test_string);
    const reader = fis.reader();

    var bounded_array = std.BoundedArray(u8, 10000){};

    // compile time error if the size is not the same at the provided `bounded.capacity()`
    try reader.readIntoBoundedBytes(10000, &bounded_array);
    try testing.expectEqualStrings(bounded_array.slice(), test_string);
}
