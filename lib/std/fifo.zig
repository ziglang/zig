// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// FIFO of fixed size items
// Usually used for e.g. byte buffers

const std = @import("std");
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;

pub const LinearFifoBufferType = union(enum) {
    /// The buffer is internal to the fifo; it is of the specified size.
    Static: usize,

    /// The buffer is passed as a slice to the initialiser.
    Slice,

    /// The buffer is managed dynamically using a `mem.Allocator`.
    Dynamic,
};

pub fn LinearFifo(
    comptime T: type,
    comptime buffer_type: LinearFifoBufferType,
) type {
    const autoalign = false;

    const powers_of_two = switch (buffer_type) {
        .Static => std.math.isPowerOfTwo(buffer_type.Static),
        .Slice => false, // Any size slice could be passed in
        .Dynamic => true, // This could be configurable in future
    };

    return struct {
        allocator: if (buffer_type == .Dynamic) *Allocator else void,
        buf: if (buffer_type == .Static) [buffer_type.Static]T else []T,
        head: usize,
        count: usize,

        const Self = @This();

        // Type of Self argument for slice operations.
        // If buffer is inline (Static) then we need to ensure we haven't
        // returned a slice into a copy on the stack
        const SliceSelfArg = if (buffer_type == .Static) *Self else Self;

        pub usingnamespace switch (buffer_type) {
            .Static => struct {
                pub fn init() Self {
                    return .{
                        .allocator = {},
                        .buf = undefined,
                        .head = 0,
                        .count = 0,
                    };
                }
            },
            .Slice => struct {
                pub fn init(buf: []T) Self {
                    return .{
                        .allocator = {},
                        .buf = buf,
                        .head = 0,
                        .count = 0,
                    };
                }
            },
            .Dynamic => struct {
                pub fn init(allocator: *Allocator) Self {
                    return .{
                        .allocator = allocator,
                        .buf = &[_]T{},
                        .head = 0,
                        .count = 0,
                    };
                }
            },
        };

        pub fn deinit(self: Self) void {
            if (buffer_type == .Dynamic) self.allocator.free(self.buf);
        }

        pub fn realign(self: *Self) void {
            if (self.buf.len - self.head >= self.count) {
                // this copy overlaps
                mem.copy(T, self.buf[0..self.count], self.buf[self.head..][0..self.count]);
                self.head = 0;
            } else {
                var tmp: [mem.page_size / 2 / @sizeOf(T)]T = undefined;

                while (self.head != 0) {
                    const n = math.min(self.head, tmp.len);
                    const m = self.buf.len - n;
                    mem.copy(T, tmp[0..n], self.buf[0..n]);
                    // this middle copy overlaps; the others here don't
                    mem.copy(T, self.buf[0..m], self.buf[n..][0..m]);
                    mem.copy(T, self.buf[m..], tmp[0..n]);
                    self.head -= n;
                }
            }
            { // set unused area to undefined
                const unused = mem.sliceAsBytes(self.buf[self.count..]);
                @memset(unused.ptr, undefined, unused.len);
            }
        }

        /// Reduce allocated capacity to `size`.
        pub fn shrink(self: *Self, size: usize) void {
            assert(size >= self.count);
            if (buffer_type == .Dynamic) {
                self.realign();
                self.buf = self.allocator.realloc(self.buf, size) catch |e| switch (e) {
                    error.OutOfMemory => return, // no problem, capacity is still correct then.
                };
            }
        }

        /// Ensure that the buffer can fit at least `size` items
        pub fn ensureCapacity(self: *Self, size: usize) !void {
            if (self.buf.len >= size) return;
            if (buffer_type == .Dynamic) {
                self.realign();
                const new_size = if (powers_of_two) math.ceilPowerOfTwo(usize, size) catch return error.OutOfMemory else size;
                self.buf = try self.allocator.realloc(self.buf, new_size);
            } else {
                return error.OutOfMemory;
            }
        }

        /// Makes sure at least `size` items are unused
        pub fn ensureUnusedCapacity(self: *Self, size: usize) error{OutOfMemory}!void {
            if (self.writableLength() >= size) return;

            return try self.ensureCapacity(math.add(usize, self.count, size) catch return error.OutOfMemory);
        }

        /// Returns number of items currently in fifo
        pub fn readableLength(self: Self) usize {
            return self.count;
        }

        /// Returns a writable slice from the 'read' end of the fifo
        fn readableSliceMut(self: SliceSelfArg, offset: usize) []T {
            if (offset > self.count) return &[_]T{};

            var start = self.head + offset;
            if (start >= self.buf.len) {
                start -= self.buf.len;
                return self.buf[start .. self.count - offset];
            } else {
                const end = math.min(self.head + self.count, self.buf.len);
                return self.buf[start..end];
            }
        }

        /// Returns a readable slice from `offset`
        pub fn readableSlice(self: SliceSelfArg, offset: usize) []const T {
            return self.readableSliceMut(offset);
        }

        /// Discard first `count` items in the fifo
        pub fn discard(self: *Self, count: usize) void {
            assert(count <= self.count);
            { // set old range to undefined. Note: may be wrapped around
                const slice = self.readableSliceMut(0);
                if (slice.len >= count) {
                    const unused = mem.sliceAsBytes(slice[0..count]);
                    @memset(unused.ptr, undefined, unused.len);
                } else {
                    const unused = mem.sliceAsBytes(slice[0..]);
                    @memset(unused.ptr, undefined, unused.len);
                    const unused2 = mem.sliceAsBytes(self.readableSliceMut(slice.len)[0 .. count - slice.len]);
                    @memset(unused2.ptr, undefined, unused2.len);
                }
            }
            if (autoalign and self.count == count) {
                self.head = 0;
                self.count = 0;
            } else {
                var head = self.head + count;
                if (powers_of_two) {
                    // Note it is safe to do a wrapping subtract as
                    // bitwise & with all 1s is a noop
                    head &= self.buf.len -% 1;
                } else {
                    head %= self.buf.len;
                }
                self.head = head;
                self.count -= count;
            }
        }

        /// Read the next item from the fifo
        pub fn readItem(self: *Self) ?T {
            if (self.count == 0) return null;

            const c = self.buf[self.head];
            self.discard(1);
            return c;
        }

        /// Read data from the fifo into `dst`, returns number of items copied.
        pub fn read(self: *Self, dst: []T) usize {
            var dst_left = dst;

            while (dst_left.len > 0) {
                const slice = self.readableSlice(0);
                if (slice.len == 0) break;
                const n = math.min(slice.len, dst_left.len);
                mem.copy(T, dst_left, slice[0..n]);
                self.discard(n);
                dst_left = dst_left[n..];
            }

            return dst.len - dst_left.len;
        }

        /// Same as `read` except it returns an error union
        /// The purpose of this function existing is to match `std.io.Reader` API.
        fn readFn(self: *Self, dest: []u8) error{}!usize {
            return self.read(dest);
        }

        pub fn reader(self: *Self) std.io.Reader(*Self, error{}, readFn) {
            return .{ .context = self };
        }

        /// Returns number of items available in fifo
        pub fn writableLength(self: Self) usize {
            return self.buf.len - self.count;
        }

        /// Returns the first section of writable buffer
        /// Note that this may be of length 0
        pub fn writableSlice(self: SliceSelfArg, offset: usize) []T {
            if (offset > self.buf.len) return &[_]T{};

            const tail = self.head + offset + self.count;
            if (tail < self.buf.len) {
                return self.buf[tail..];
            } else {
                return self.buf[tail - self.buf.len ..][0 .. self.writableLength() - offset];
            }
        }

        /// Returns a writable buffer of at least `size` items, allocating memory as needed.
        /// Use `fifo.update` once you've written data to it.
        pub fn writableWithSize(self: *Self, size: usize) ![]T {
            try self.ensureUnusedCapacity(size);

            // try to avoid realigning buffer
            var slice = self.writableSlice(0);
            if (slice.len < size) {
                self.realign();
                slice = self.writableSlice(0);
            }
            return slice;
        }

        /// Update the tail location of the buffer (usually follows use of writable/writableWithSize)
        pub fn update(self: *Self, count: usize) void {
            assert(self.count + count <= self.buf.len);
            self.count += count;
        }

        /// Appends the data in `src` to the fifo.
        /// You must have ensured there is enough space.
        pub fn writeAssumeCapacity(self: *Self, src: []const T) void {
            assert(self.writableLength() >= src.len);

            var src_left = src;
            while (src_left.len > 0) {
                const writable_slice = self.writableSlice(0);
                assert(writable_slice.len != 0);
                const n = math.min(writable_slice.len, src_left.len);
                mem.copy(T, writable_slice, src_left[0..n]);
                self.update(n);
                src_left = src_left[n..];
            }
        }

        /// Write a single item to the fifo
        pub fn writeItem(self: *Self, item: T) !void {
            try self.ensureUnusedCapacity(1);
            return self.writeItemAssumeCapacity(item);
        }

        pub fn writeItemAssumeCapacity(self: *Self, item: T) void {
            var tail = self.head + self.count;
            if (powers_of_two) {
                tail &= self.buf.len - 1;
            } else {
                tail %= self.buf.len;
            }
            self.buf[tail] = item;
            self.update(1);
        }

        /// Appends the data in `src` to the fifo.
        /// Allocates more memory as necessary
        pub fn write(self: *Self, src: []const T) !void {
            try self.ensureUnusedCapacity(src.len);

            return self.writeAssumeCapacity(src);
        }

        /// Same as `write` except it returns the number of bytes written, which is always the same
        /// as `bytes.len`. The purpose of this function existing is to match `std.io.Writer` API.
        fn appendWrite(self: *Self, bytes: []const u8) error{OutOfMemory}!usize {
            try self.write(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) std.io.Writer(*Self, error{OutOfMemory}, appendWrite) {
            return .{ .context = self };
        }

        /// Make `count` items available before the current read location
        fn rewind(self: *Self, count: usize) void {
            assert(self.writableLength() >= count);

            var head = self.head + (self.buf.len - count);
            if (powers_of_two) {
                head &= self.buf.len - 1;
            } else {
                head %= self.buf.len;
            }
            self.head = head;
            self.count += count;
        }

        /// Place data back into the read stream
        pub fn unget(self: *Self, src: []const T) !void {
            try self.ensureUnusedCapacity(src.len);

            self.rewind(src.len);

            const slice = self.readableSliceMut(0);
            if (src.len < slice.len) {
                mem.copy(T, slice, src);
            } else {
                mem.copy(T, slice, src[0..slice.len]);
                const slice2 = self.readableSliceMut(slice.len);
                mem.copy(T, slice2, src[slice.len..]);
            }
        }

        /// Returns the item at `offset`.
        /// Asserts offset is within bounds.
        pub fn peekItem(self: Self, offset: usize) T {
            assert(offset < self.count);

            var index = self.head + offset;
            if (powers_of_two) {
                index &= self.buf.len - 1;
            } else {
                index %= self.buf.len;
            }
            return self.buf[index];
        }

        /// Pump data from a reader into a writer
        /// stops when reader returns 0 bytes (EOF)
        /// Buffer size must be set before calling; a buffer length of 0 is invalid.
        pub fn pump(self: *Self, src_reader: anytype, dest_writer: anytype) !void {
            assert(self.buf.len > 0);
            while (true) {
                if (self.writableLength() > 0) {
                    const n = try src_reader.read(self.writableSlice(0));
                    if (n == 0) break; // EOF
                    self.update(n);
                }
                self.discard(try dest_writer.write(self.readableSlice(0)));
            }
            // flush remaining data
            while (self.readableLength() > 0) {
                self.discard(try dest_writer.write(self.readableSlice(0)));
            }
        }
    };
}

test "LinearFifo(u8, .Dynamic) discard(0) from empty buffer should not error on overflow" {
    var fifo = LinearFifo(u8, .Dynamic).init(testing.allocator);
    defer fifo.deinit();

    // If overflow is not explicitly allowed this will crash in debug / safe mode
    fifo.discard(0);
}

test "LinearFifo(u8, .Dynamic)" {
    var fifo = LinearFifo(u8, .Dynamic).init(testing.allocator);
    defer fifo.deinit();

    try fifo.write("HELLO");
    testing.expectEqual(@as(usize, 5), fifo.readableLength());
    testing.expectEqualSlices(u8, "HELLO", fifo.readableSlice(0));

    {
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            try fifo.write(&[_]u8{fifo.peekItem(i)});
        }
        testing.expectEqual(@as(usize, 10), fifo.readableLength());
        testing.expectEqualSlices(u8, "HELLOHELLO", fifo.readableSlice(0));
    }

    {
        testing.expectEqual(@as(u8, 'H'), fifo.readItem().?);
        testing.expectEqual(@as(u8, 'E'), fifo.readItem().?);
        testing.expectEqual(@as(u8, 'L'), fifo.readItem().?);
        testing.expectEqual(@as(u8, 'L'), fifo.readItem().?);
        testing.expectEqual(@as(u8, 'O'), fifo.readItem().?);
    }
    testing.expectEqual(@as(usize, 5), fifo.readableLength());

    { // Writes that wrap around
        testing.expectEqual(@as(usize, 11), fifo.writableLength());
        testing.expectEqual(@as(usize, 6), fifo.writableSlice(0).len);
        fifo.writeAssumeCapacity("6<chars<11");
        testing.expectEqualSlices(u8, "HELLO6<char", fifo.readableSlice(0));
        testing.expectEqualSlices(u8, "s<11", fifo.readableSlice(11));
        fifo.discard(11);
        testing.expectEqualSlices(u8, "s<11", fifo.readableSlice(0));
        fifo.discard(4);
        testing.expectEqual(@as(usize, 0), fifo.readableLength());
    }

    {
        const buf = try fifo.writableWithSize(12);
        testing.expectEqual(@as(usize, 12), buf.len);
        var i: u8 = 0;
        while (i < 10) : (i += 1) {
            buf[i] = i + 'a';
        }
        fifo.update(10);
        testing.expectEqualSlices(u8, "abcdefghij", fifo.readableSlice(0));
    }

    {
        try fifo.unget("prependedstring");
        var result: [30]u8 = undefined;
        testing.expectEqualSlices(u8, "prependedstringabcdefghij", result[0..fifo.read(&result)]);
        try fifo.unget("b");
        try fifo.unget("a");
        testing.expectEqualSlices(u8, "ab", result[0..fifo.read(&result)]);
    }

    fifo.shrink(0);

    {
        try fifo.writer().print("{s}, {s}!", .{ "Hello", "World" });
        var result: [30]u8 = undefined;
        testing.expectEqualSlices(u8, "Hello, World!", result[0..fifo.read(&result)]);
        testing.expectEqual(@as(usize, 0), fifo.readableLength());
    }

    {
        try fifo.writer().writeAll("This is a test");
        var result: [30]u8 = undefined;
        testing.expectEqualSlices(u8, "This", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
        testing.expectEqualSlices(u8, "is", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
        testing.expectEqualSlices(u8, "a", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
        testing.expectEqualSlices(u8, "test", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
    }

    {
        try fifo.ensureCapacity(1);
        var in_fbs = std.io.fixedBufferStream("pump test");
        var out_buf: [50]u8 = undefined;
        var out_fbs = std.io.fixedBufferStream(&out_buf);
        try fifo.pump(in_fbs.reader(), out_fbs.writer());
        testing.expectEqualSlices(u8, in_fbs.buffer, out_fbs.getWritten());
    }
}

test "LinearFifo" {
    inline for ([_]type{ u1, u8, u16, u64 }) |T| {
        inline for ([_]LinearFifoBufferType{ LinearFifoBufferType{ .Static = 32 }, .Slice, .Dynamic }) |bt| {
            const FifoType = LinearFifo(T, bt);
            var buf: if (bt == .Slice) [32]T else void = undefined;
            var fifo = switch (bt) {
                .Static => FifoType.init(),
                .Slice => FifoType.init(buf[0..]),
                .Dynamic => FifoType.init(testing.allocator),
            };
            defer fifo.deinit();

            try fifo.write(&[_]T{ 0, 1, 1, 0, 1 });
            testing.expectEqual(@as(usize, 5), fifo.readableLength());

            {
                testing.expectEqual(@as(T, 0), fifo.readItem().?);
                testing.expectEqual(@as(T, 1), fifo.readItem().?);
                testing.expectEqual(@as(T, 1), fifo.readItem().?);
                testing.expectEqual(@as(T, 0), fifo.readItem().?);
                testing.expectEqual(@as(T, 1), fifo.readItem().?);
                testing.expectEqual(@as(usize, 0), fifo.readableLength());
            }

            {
                try fifo.writeItem(1);
                try fifo.writeItem(1);
                try fifo.writeItem(1);
                testing.expectEqual(@as(usize, 3), fifo.readableLength());
            }

            {
                var readBuf: [3]T = undefined;
                const n = fifo.read(&readBuf);
                testing.expectEqual(@as(usize, 3), n); // NOTE: It should be the number of items.
            }
        }
    }
}
