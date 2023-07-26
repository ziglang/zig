const std = @import("../std.zig");
const math = std.math;
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;
const native_endian = @import("builtin").target.cpu.arch.endian();

pub fn Reader(
    comptime Context: type,
    comptime ReadError: type,
    /// Returns the number of bytes read. It may be less than buffer.len.
    /// If the number of bytes read is 0, it means end of stream.
    /// End of stream is not an error condition.
    comptime readFn: fn (context: Context, buffer: []u8) ReadError!usize,
) type {
    return struct {
        pub const Error = ReadError;

        context: Context,

        const Self = @This();

        /// Returns the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        pub fn read(self: Self, buffer: []u8) Error!usize {
            return readFn(self.context, buffer);
        }

        /// Returns the number of bytes read. If the number read is smaller than `buffer.len`, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        pub fn readAll(self: Self, buffer: []u8) Error!usize {
            return readAtLeast(self, buffer, buffer.len);
        }

        /// Returns the number of bytes read, calling the underlying read
        /// function the minimal number of times until the buffer has at least
        /// `len` bytes filled. If the number read is less than `len` it means
        /// the stream reached the end. Reaching the end of the stream is not
        /// an error condition.
        pub fn readAtLeast(self: Self, buffer: []u8, len: usize) Error!usize {
            assert(len <= buffer.len);
            var index: usize = 0;
            while (index < len) {
                const amt = try self.read(buffer[index..]);
                if (amt == 0) break;
                index += amt;
            }
            return index;
        }

        /// If the number read would be smaller than `buf.len`, `error.EndOfStream` is returned instead.
        pub fn readNoEof(self: Self, buf: []u8) (Error || error{EndOfStream})!void {
            const amt_read = try self.readAll(buf);
            if (amt_read < buf.len) return error.EndOfStream;
        }

        /// Appends to the `std.ArrayList` contents by reading from the stream
        /// until end of stream is found.
        /// If the number of bytes appended would exceed `max_append_size`,
        /// `error.StreamTooLong` is returned
        /// and the `std.ArrayList` has exactly `max_append_size` bytes appended.
        pub fn readAllArrayList(self: Self, array_list: *std.ArrayList(u8), max_append_size: usize) !void {
            return self.readAllArrayListAligned(null, array_list, max_append_size);
        }

        pub fn readAllArrayListAligned(
            self: Self,
            comptime alignment: ?u29,
            array_list: *std.ArrayListAligned(u8, alignment),
            max_append_size: usize,
        ) !void {
            try array_list.ensureTotalCapacity(@min(max_append_size, 4096));
            const original_len = array_list.items.len;
            var start_index: usize = original_len;
            while (true) {
                array_list.expandToCapacity();
                const dest_slice = array_list.items[start_index..];
                const bytes_read = try self.readAll(dest_slice);
                start_index += bytes_read;

                if (start_index - original_len > max_append_size) {
                    array_list.shrinkAndFree(original_len + max_append_size);
                    return error.StreamTooLong;
                }

                if (bytes_read != dest_slice.len) {
                    array_list.shrinkAndFree(start_index);
                    return;
                }

                // This will trigger ArrayList to expand superlinearly at whatever its growth rate is.
                try array_list.ensureTotalCapacity(start_index + 1);
            }
        }

        /// Allocates enough memory to hold all the contents of the stream. If the allocated
        /// memory would be greater than `max_size`, returns `error.StreamTooLong`.
        /// Caller owns returned memory.
        /// If this function returns an error, the contents from the stream read so far are lost.
        pub fn readAllAlloc(self: Self, allocator: mem.Allocator, max_size: usize) ![]u8 {
            var array_list = std.ArrayList(u8).init(allocator);
            defer array_list.deinit();
            try self.readAllArrayList(&array_list, max_size);
            return try array_list.toOwnedSlice();
        }

        /// Deprecated: use `streamUntilDelimiter` with ArrayList's writer instead.
        /// Replaces the `std.ArrayList` contents by reading from the stream until `delimiter` is found.
        /// Does not include the delimiter in the result.
        /// If the `std.ArrayList` length would exceed `max_size`, `error.StreamTooLong` is returned and the
        /// `std.ArrayList` is populated with `max_size` bytes from the stream.
        pub fn readUntilDelimiterArrayList(
            self: Self,
            array_list: *std.ArrayList(u8),
            delimiter: u8,
            max_size: usize,
        ) !void {
            array_list.shrinkRetainingCapacity(0);
            try self.streamUntilDelimiter(array_list.writer(), delimiter, max_size);
        }

        /// Deprecated: use `streamUntilDelimiter` with ArrayList's writer instead.
        /// Allocates enough memory to read until `delimiter`. If the allocated
        /// memory would be greater than `max_size`, returns `error.StreamTooLong`.
        /// Caller owns returned memory.
        /// If this function returns an error, the contents from the stream read so far are lost.
        pub fn readUntilDelimiterAlloc(
            self: Self,
            allocator: mem.Allocator,
            delimiter: u8,
            max_size: usize,
        ) ![]u8 {
            var array_list = std.ArrayList(u8).init(allocator);
            defer array_list.deinit();
            try self.streamUntilDelimiter(array_list.writer(), delimiter, max_size);
            return try array_list.toOwnedSlice();
        }

        /// Deprecated: use `streamUntilDelimiter` with FixedBufferStream's writer instead.
        /// Reads from the stream until specified byte is found. If the buffer is not
        /// large enough to hold the entire contents, `error.StreamTooLong` is returned.
        /// If end-of-stream is found, `error.EndOfStream` is returned.
        /// Returns a slice of the stream data, with ptr equal to `buf.ptr`. The
        /// delimiter byte is written to the output buffer but is not included
        /// in the returned slice.
        pub fn readUntilDelimiter(self: Self, buf: []u8, delimiter: u8) ![]u8 {
            var fbs = std.io.fixedBufferStream(buf);
            try self.streamUntilDelimiter(fbs.writer(), delimiter, fbs.buffer.len);
            const output = fbs.getWritten();
            buf[output.len] = delimiter; // emulating old behaviour
            return output;
        }

        /// Deprecated: use `streamUntilDelimiter` with ArrayList's (or any other's) writer instead.
        /// Allocates enough memory to read until `delimiter` or end-of-stream.
        /// If the allocated memory would be greater than `max_size`, returns
        /// `error.StreamTooLong`. If end-of-stream is found, returns the rest
        /// of the stream. If this function is called again after that, returns
        /// null.
        /// Caller owns returned memory.
        /// If this function returns an error, the contents from the stream read so far are lost.
        pub fn readUntilDelimiterOrEofAlloc(
            self: Self,
            allocator: mem.Allocator,
            delimiter: u8,
            max_size: usize,
        ) !?[]u8 {
            var array_list = std.ArrayList(u8).init(allocator);
            defer array_list.deinit();
            self.streamUntilDelimiter(array_list.writer(), delimiter, max_size) catch |err| switch (err) {
                error.EndOfStream => if (array_list.items.len == 0) {
                    return null;
                },
                else => |e| return e,
            };
            return try array_list.toOwnedSlice();
        }

        /// Deprecated: use `streamUntilDelimiter` with FixedBufferStream's writer instead.
        /// Reads from the stream until specified byte is found. If the buffer is not
        /// large enough to hold the entire contents, `error.StreamTooLong` is returned.
        /// If end-of-stream is found, returns the rest of the stream. If this
        /// function is called again after that, returns null.
        /// Returns a slice of the stream data, with ptr equal to `buf.ptr`. The
        /// delimiter byte is written to the output buffer but is not included
        /// in the returned slice.
        pub fn readUntilDelimiterOrEof(self: Self, buf: []u8, delimiter: u8) !?[]u8 {
            var fbs = std.io.fixedBufferStream(buf);
            self.streamUntilDelimiter(fbs.writer(), delimiter, fbs.buffer.len) catch |err| switch (err) {
                error.EndOfStream => if (fbs.getWritten().len == 0) {
                    return null;
                },

                else => |e| return e,
            };
            const output = fbs.getWritten();
            buf[output.len] = delimiter; // emulating old behaviour
            return output;
        }

        /// Appends to the `writer` contents by reading from the stream until `delimiter` is found.
        /// Does not write the delimiter itself.
        /// If `optional_max_size` is not null and amount of written bytes exceeds `optional_max_size`,
        /// returns `error.StreamTooLong` and finishes appending.
        /// If `optional_max_size` is null, appending is unbounded.
        pub fn streamUntilDelimiter(self: Self, writer: anytype, delimiter: u8, optional_max_size: ?usize) (Error || error{ EndOfStream, StreamTooLong } || @TypeOf(writer).Error)!void {
            if (optional_max_size) |max_size| {
                for (0..max_size) |_| {
                    const byte: u8 = try self.readByte(); // (Error || error{EndOfStream})
                    if (byte == delimiter) return;
                    try writer.writeByte(byte); // @TypeOf(writer).Error
                }
                return error.StreamTooLong;
            } else {
                while (true) {
                    const byte: u8 = try self.readByte(); // (Error || error{EndOfStream})
                    if (byte == delimiter) return;
                    try writer.writeByte(byte); // @TypeOf(writer).Error
                }
                // Can not throw `error.StreamTooLong` since there are no boundary.
            }
        }

        /// Reads from the stream until specified byte is found, discarding all data,
        /// including the delimiter.
        /// If end-of-stream is found, this function succeeds.
        pub fn skipUntilDelimiterOrEof(self: Self, delimiter: u8) Error!void {
            while (true) {
                const byte = self.readByte() catch |err| switch (err) {
                    error.EndOfStream => return,
                    else => |e| return e,
                };
                if (byte == delimiter) return;
            }
        }

        /// Reads 1 byte from the stream or returns `error.EndOfStream`.
        pub fn readByte(self: Self) (Error || error{EndOfStream})!u8 {
            var result: [1]u8 = undefined;
            const amt_read = try self.read(result[0..]);
            if (amt_read < 1) return error.EndOfStream;
            return result[0];
        }

        /// Same as `readByte` except the returned byte is signed.
        pub fn readByteSigned(self: Self) (Error || error{EndOfStream})!i8 {
            return @as(i8, @bitCast(try self.readByte()));
        }

        /// Reads exactly `num_bytes` bytes and returns as an array.
        /// `num_bytes` must be comptime-known
        pub fn readBytesNoEof(self: Self, comptime num_bytes: usize) (Error || error{EndOfStream})![num_bytes]u8 {
            var bytes: [num_bytes]u8 = undefined;
            try self.readNoEof(&bytes);
            return bytes;
        }

        /// Reads bytes until `bounded.len` is equal to `num_bytes`,
        /// or the stream ends.
        ///
        /// * it is assumed that `num_bytes` will not exceed `bounded.capacity()`
        pub fn readIntoBoundedBytes(
            self: Self,
            comptime num_bytes: usize,
            bounded: *std.BoundedArray(u8, num_bytes),
        ) Error!void {
            while (bounded.len < num_bytes) {
                // get at most the number of bytes free in the bounded array
                const bytes_read = try self.read(bounded.unusedCapacitySlice());
                if (bytes_read == 0) return;

                // bytes_read will never be larger than @TypeOf(bounded.len)
                // due to `self.read` being bounded by `bounded.unusedCapacitySlice()`
                bounded.len += @as(@TypeOf(bounded.len), @intCast(bytes_read));
            }
        }

        /// Reads at most `num_bytes` and returns as a bounded array.
        pub fn readBoundedBytes(self: Self, comptime num_bytes: usize) Error!std.BoundedArray(u8, num_bytes) {
            var result = std.BoundedArray(u8, num_bytes){};
            try self.readIntoBoundedBytes(num_bytes, &result);
            return result;
        }

        /// Reads a native-endian integer
        pub fn readIntNative(self: Self, comptime T: type) (Error || error{EndOfStream})!T {
            const bytes = try self.readBytesNoEof(@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8)));
            return mem.readIntNative(T, &bytes);
        }

        /// Reads a foreign-endian integer
        pub fn readIntForeign(self: Self, comptime T: type) (Error || error{EndOfStream})!T {
            const bytes = try self.readBytesNoEof(@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8)));
            return mem.readIntForeign(T, &bytes);
        }

        pub fn readIntLittle(self: Self, comptime T: type) !T {
            const bytes = try self.readBytesNoEof(@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8)));
            return mem.readIntLittle(T, &bytes);
        }

        pub fn readIntBig(self: Self, comptime T: type) !T {
            const bytes = try self.readBytesNoEof(@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8)));
            return mem.readIntBig(T, &bytes);
        }

        pub fn readInt(self: Self, comptime T: type, endian: std.builtin.Endian) !T {
            const bytes = try self.readBytesNoEof(@as(u16, @intCast((@as(u17, @typeInfo(T).Int.bits) + 7) / 8)));
            return mem.readInt(T, &bytes, endian);
        }

        pub fn readVarInt(self: Self, comptime ReturnType: type, endian: std.builtin.Endian, size: usize) !ReturnType {
            assert(size <= @sizeOf(ReturnType));
            var bytes_buf: [@sizeOf(ReturnType)]u8 = undefined;
            const bytes = bytes_buf[0..size];
            try self.readNoEof(bytes);
            return mem.readVarInt(ReturnType, bytes, endian);
        }

        /// Optional parameters for `skipBytes`
        pub const SkipBytesOptions = struct {
            buf_size: usize = 512,
        };

        // `num_bytes` is a `u64` to match `off_t`
        /// Reads `num_bytes` bytes from the stream and discards them
        pub fn skipBytes(self: Self, num_bytes: u64, comptime options: SkipBytesOptions) !void {
            var buf: [options.buf_size]u8 = undefined;
            var remaining = num_bytes;

            while (remaining > 0) {
                const amt = @min(remaining, options.buf_size);
                try self.readNoEof(buf[0..amt]);
                remaining -= amt;
            }
        }

        /// Reads `slice.len` bytes from the stream and returns if they are the same as the passed slice
        pub fn isBytes(self: Self, slice: []const u8) !bool {
            var i: usize = 0;
            var matches = true;
            while (i < slice.len) : (i += 1) {
                if (slice[i] != try self.readByte()) {
                    matches = false;
                }
            }
            return matches;
        }

        pub fn readStruct(self: Self, comptime T: type) !T {
            // Only extern and packed structs have defined in-memory layout.
            comptime assert(@typeInfo(T).Struct.layout != .Auto);
            var res: [1]T = undefined;
            try self.readNoEof(mem.sliceAsBytes(res[0..]));
            return res[0];
        }

        pub fn readStructBig(self: Self, comptime T: type) !T {
            var res = try self.readStruct(T);
            if (native_endian != std.builtin.Endian.Big) {
                mem.byteSwapAllFields(T, &res);
            }
            return res;
        }

        /// Reads an integer with the same size as the given enum's tag type. If the integer matches
        /// an enum tag, casts the integer to the enum tag and returns it. Otherwise, returns an `error.InvalidValue`.
        /// TODO optimization taking advantage of most fields being in order
        pub fn readEnum(self: Self, comptime Enum: type, endian: std.builtin.Endian) !Enum {
            const E = error{
                /// An integer was read, but it did not match any of the tags in the supplied enum.
                InvalidValue,
            };
            const type_info = @typeInfo(Enum).Enum;
            const tag = try self.readInt(type_info.tag_type, endian);

            inline for (std.meta.fields(Enum)) |field| {
                if (tag == field.value) {
                    return @field(Enum, field.name);
                }
            }

            return E.InvalidValue;
        }
    };
}

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
    }, undefined)) == .c);
    try testing.expectError(error.EndOfStream, reader.readByte());
}

test "Reader.isBytes" {
    var fis = std.io.fixedBufferStream("foobar");
    const reader = fis.reader();
    try testing.expectEqual(true, try reader.isBytes("foo"));
    try testing.expectEqual(false, try reader.isBytes("qux"));
}

test "Reader.skipBytes" {
    var fis = std.io.fixedBufferStream("foobar");
    const reader = fis.reader();
    try reader.skipBytes(3, .{});
    try testing.expect(try reader.isBytes("bar"));
    try reader.skipBytes(0, .{});
    try testing.expectError(error.EndOfStream, reader.skipBytes(1, .{}));
}

test "Reader.readUntilDelimiterArrayList returns ArrayLists with bytes read until the delimiter, then EndOfStream" {
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

test "Reader.readUntilDelimiterArrayList returns an empty ArrayList" {
    const a = std.testing.allocator;
    var list = std.ArrayList(u8).init(a);
    defer list.deinit();

    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();

    try reader.readUntilDelimiterArrayList(&list, '\n', 5);
    try std.testing.expectEqualStrings("", list.items);
}

test "Reader.readUntilDelimiterArrayList returns StreamTooLong, then an ArrayList with bytes read until the delimiter" {
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

test "Reader.readUntilDelimiterArrayList returns EndOfStream" {
    const a = std.testing.allocator;
    var list = std.ArrayList(u8).init(a);
    defer list.deinit();

    var fis = std.io.fixedBufferStream("1234");
    const reader = fis.reader();

    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiterArrayList(&list, '\n', 5));
    try std.testing.expectEqualStrings("1234", list.items);
}

test "Reader.readUntilDelimiterAlloc returns ArrayLists with bytes read until the delimiter, then EndOfStream" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();

    {
        var result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
        defer a.free(result);
        try std.testing.expectEqualStrings("0000", result);
    }

    {
        var result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
        defer a.free(result);
        try std.testing.expectEqualStrings("1234", result);
    }

    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiterAlloc(a, '\n', 5));
}

test "Reader.readUntilDelimiterAlloc returns an empty ArrayList" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();

    {
        var result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
        defer a.free(result);
        try std.testing.expectEqualStrings("", result);
    }
}

test "Reader.readUntilDelimiterAlloc returns StreamTooLong, then an ArrayList with bytes read until the delimiter" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();

    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterAlloc(a, '\n', 5));

    var result = try reader.readUntilDelimiterAlloc(a, '\n', 5);
    defer a.free(result);
    try std.testing.expectEqualStrings("67", result);
}

test "Reader.readUntilDelimiterAlloc returns EndOfStream" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("1234");
    const reader = fis.reader();

    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiterAlloc(a, '\n', 5));
}

test "Reader.readUntilDelimiter returns bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("0000", try reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("1234", try reader.readUntilDelimiter(&buf, '\n'));
}

test "Reader.readUntilDelimiter returns an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("", try reader.readUntilDelimiter(&buf, '\n'));
}

test "Reader.readUntilDelimiter returns StreamTooLong, then an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("12345\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("", try reader.readUntilDelimiter(&buf, '\n'));
}

test "Reader.readUntilDelimiter returns StreamTooLong, then bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("67", try reader.readUntilDelimiter(&buf, '\n'));
}

test "Reader.readUntilDelimiter returns EndOfStream" {
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

test "Reader.readUntilDelimiter returns bytes read until delimiter, then EndOfStream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("1234", try reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiter(&buf, '\n'));
}

test "Reader.readUntilDelimiter returns StreamTooLong, then EndOfStream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("12345");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectError(error.EndOfStream, reader.readUntilDelimiter(&buf, '\n'));
}

test "Reader.readUntilDelimiter writes all bytes read to the output buffer" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n12345");
    const reader = fis.reader();
    _ = try reader.readUntilDelimiter(&buf, '\n');
    try std.testing.expectEqualStrings("0000\n", &buf);
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiter(&buf, '\n'));
    try std.testing.expectEqualStrings("12345", &buf);
}

test "Reader.readUntilDelimiterOrEofAlloc returns ArrayLists with bytes read until the delimiter, then EndOfStream" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();

    {
        var result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
        defer a.free(result);
        try std.testing.expectEqualStrings("0000", result);
    }

    {
        var result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
        defer a.free(result);
        try std.testing.expectEqualStrings("1234", result);
    }

    try std.testing.expect((try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)) == null);
}

test "Reader.readUntilDelimiterOrEofAlloc returns an empty ArrayList" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();

    {
        var result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
        defer a.free(result);
        try std.testing.expectEqualStrings("", result);
    }
}

test "Reader.readUntilDelimiterOrEofAlloc returns StreamTooLong, then an ArrayList with bytes read until the delimiter" {
    const a = std.testing.allocator;

    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();

    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEofAlloc(a, '\n', 5));

    var result = (try reader.readUntilDelimiterOrEofAlloc(a, '\n', 5)).?;
    defer a.free(result);
    try std.testing.expectEqualStrings("67", result);
}

test "Reader.readUntilDelimiterOrEof returns bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("0000", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
    try std.testing.expectEqualStrings("1234", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "Reader.readUntilDelimiterOrEof returns an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "Reader.readUntilDelimiterOrEof returns StreamTooLong, then an empty string" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("12345\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "Reader.readUntilDelimiterOrEof returns StreamTooLong, then bytes read until the delimiter" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234567\n");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("67", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "Reader.readUntilDelimiterOrEof returns null" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("");
    const reader = fis.reader();
    try std.testing.expect((try reader.readUntilDelimiterOrEof(&buf, '\n')) == null);
}

test "Reader.readUntilDelimiterOrEof returns bytes read until delimiter, then null" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234\n");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("1234", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
    try std.testing.expect((try reader.readUntilDelimiterOrEof(&buf, '\n')) == null);
}

test "Reader.readUntilDelimiterOrEof returns bytes read until end-of-stream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234");
    const reader = fis.reader();
    try std.testing.expectEqualStrings("1234", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "Reader.readUntilDelimiterOrEof returns StreamTooLong, then bytes read until end-of-stream" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("1234567");
    const reader = fis.reader();
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("67", (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
}

test "Reader.readUntilDelimiterOrEof writes all bytes read to the output buffer" {
    var buf: [5]u8 = undefined;
    var fis = std.io.fixedBufferStream("0000\n12345");
    const reader = fis.reader();
    _ = try reader.readUntilDelimiterOrEof(&buf, '\n');
    try std.testing.expectEqualStrings("0000\n", &buf);
    try std.testing.expectError(error.StreamTooLong, reader.readUntilDelimiterOrEof(&buf, '\n'));
    try std.testing.expectEqualStrings("12345", &buf);
}

test "Reader.streamUntilDelimiter writes all bytes without delimiter to the output" {
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

test "Reader.readBoundedBytes correctly reads into a new bounded array" {
    const test_string = "abcdefg";
    var fis = std.io.fixedBufferStream(test_string);
    const reader = fis.reader();

    var array = try reader.readBoundedBytes(10000);
    try testing.expectEqualStrings(array.slice(), test_string);
}

test "Reader.readIntoBoundedBytes correctly reads into a provided bounded array" {
    const test_string = "abcdefg";
    var fis = std.io.fixedBufferStream(test_string);
    const reader = fis.reader();

    var bounded_array = std.BoundedArray(u8, 10000){};

    // compile time error if the size is not the same at the provided `bounded.capacity()`
    try reader.readIntoBoundedBytes(10000, &bounded_array);
    try testing.expectEqualStrings(bounded_array.slice(), test_string);
}
