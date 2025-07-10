//! Deprecated. Stop using this API

const std = @import("std");
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;

pub fn LinearFifo(comptime T: type) type {
    return struct {
        allocator: Allocator,
        buf: []T,
        head: usize,
        count: usize,

        const Self = @This();
<<<<<<<< HEAD:src/deprecated.zig
|||||||| edf785db0f:lib/std/fifo.zig
        pub const Reader = std.io.Reader(*Self, error{}, readFn);
        pub const Writer = std.io.Writer(*Self, error{OutOfMemory}, appendWrite);
========
        pub const Reader = std.io.GenericReader(*Self, error{}, readFn);
        pub const Writer = std.io.GenericWriter(*Self, error{OutOfMemory}, appendWrite);
>>>>>>>> origin/master:lib/std/fifo.zig

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .buf = &.{},
                .head = 0,
                .count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buf);
            self.* = undefined;
        }

        pub fn realign(self: *Self) void {
            if (self.buf.len - self.head >= self.count) {
                mem.copyForwards(T, self.buf[0..self.count], self.buf[self.head..][0..self.count]);
                self.head = 0;
            } else {
                var tmp: [4096 / 2 / @sizeOf(T)]T = undefined;

                while (self.head != 0) {
                    const n = @min(self.head, tmp.len);
                    const m = self.buf.len - n;
                    @memcpy(tmp[0..n], self.buf[0..n]);
                    mem.copyForwards(T, self.buf[0..m], self.buf[n..][0..m]);
                    @memcpy(self.buf[m..][0..n], tmp[0..n]);
                    self.head -= n;
                }
            }
            { // set unused area to undefined
                const unused = mem.sliceAsBytes(self.buf[self.count..]);
                @memset(unused, undefined);
            }
        }

        /// Reduce allocated capacity to `size`.
        pub fn shrink(self: *Self, size: usize) void {
            assert(size >= self.count);
            self.realign();
            self.buf = self.allocator.realloc(self.buf, size) catch |e| switch (e) {
                error.OutOfMemory => return, // no problem, capacity is still correct then.
            };
        }

        /// Ensure that the buffer can fit at least `size` items
        pub fn ensureTotalCapacity(self: *Self, size: usize) !void {
            if (self.buf.len >= size) return;
            self.realign();
            const new_size = math.ceilPowerOfTwo(usize, size) catch return error.OutOfMemory;
            self.buf = try self.allocator.realloc(self.buf, new_size);
        }

        /// Makes sure at least `size` items are unused
        pub fn ensureUnusedCapacity(self: *Self, size: usize) error{OutOfMemory}!void {
            if (self.writableLength() >= size) return;

            return try self.ensureTotalCapacity(math.add(usize, self.count, size) catch return error.OutOfMemory);
        }

        /// Returns number of items currently in fifo
        pub fn readableLength(self: Self) usize {
            return self.count;
        }

        /// Returns a writable slice from the 'read' end of the fifo
        fn readableSliceMut(self: Self, offset: usize) []T {
            if (offset > self.count) return &[_]T{};

            var start = self.head + offset;
            if (start >= self.buf.len) {
                start -= self.buf.len;
                return self.buf[start .. start + (self.count - offset)];
            } else {
                const end = @min(self.head + self.count, self.buf.len);
                return self.buf[start..end];
            }
        }

        /// Returns a readable slice from `offset`
        pub fn readableSlice(self: Self, offset: usize) []const T {
            return self.readableSliceMut(offset);
        }

        pub fn readableSliceOfLen(self: *Self, len: usize) []const T {
            assert(len <= self.count);
            const buf = self.readableSlice(0);
            if (buf.len >= len) {
                return buf[0..len];
            } else {
                self.realign();
                return self.readableSlice(0)[0..len];
            }
        }

        /// Discard first `count` items in the fifo
        pub fn discard(self: *Self, count: usize) void {
            assert(count <= self.count);
            { // set old range to undefined. Note: may be wrapped around
                const slice = self.readableSliceMut(0);
                if (slice.len >= count) {
                    const unused = mem.sliceAsBytes(slice[0..count]);
                    @memset(unused, undefined);
                } else {
                    const unused = mem.sliceAsBytes(slice[0..]);
                    @memset(unused, undefined);
                    const unused2 = mem.sliceAsBytes(self.readableSliceMut(slice.len)[0 .. count - slice.len]);
                    @memset(unused2, undefined);
                }
            }
            var head = self.head + count;
            // Note it is safe to do a wrapping subtract as
            // bitwise & with all 1s is a noop
            head &= self.buf.len -% 1;
            self.head = head;
            self.count -= count;
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
                const n = @min(slice.len, dst_left.len);
                @memcpy(dst_left[0..n], slice[0..n]);
                self.discard(n);
                dst_left = dst_left[n..];
            }

            return dst.len - dst_left.len;
        }

        /// Same as `read` except it returns an error union
        /// The purpose of this function existing is to match `std.io.GenericReader` API.
        fn readFn(self: *Self, dest: []u8) error{}!usize {
            return self.read(dest);
        }

        /// Returns number of items available in fifo
        pub fn writableLength(self: Self) usize {
            return self.buf.len - self.count;
        }

        /// Returns the first section of writable buffer.
        /// Note that this may be of length 0
        pub fn writableSlice(self: Self, offset: usize) []T {
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
                const n = @min(writable_slice.len, src_left.len);
                @memcpy(writable_slice[0..n], src_left[0..n]);
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
            tail &= self.buf.len - 1;
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
        /// as `bytes.len`. The purpose of this function existing is to match `std.io.GenericWriter` API.
        fn appendWrite(self: *Self, bytes: []const u8) error{OutOfMemory}!usize {
            try self.write(bytes);
            return bytes.len;
        }

        /// Make `count` items available before the current read location
        fn rewind(self: *Self, count: usize) void {
            assert(self.writableLength() >= count);

            var head = self.head + (self.buf.len - count);
            head &= self.buf.len - 1;
            self.head = head;
            self.count += count;
        }

        /// Place data back into the read stream
        pub fn unget(self: *Self, src: []const T) !void {
            try self.ensureUnusedCapacity(src.len);

            self.rewind(src.len);

            const slice = self.readableSliceMut(0);
            if (src.len < slice.len) {
                @memcpy(slice[0..src.len], src);
            } else {
                @memcpy(slice, src[0..slice.len]);
                const slice2 = self.readableSliceMut(slice.len);
                @memcpy(slice2[0 .. src.len - slice.len], src[slice.len..]);
            }
        }

        /// Returns the item at `offset`.
        /// Asserts offset is within bounds.
        pub fn peekItem(self: Self, offset: usize) T {
            assert(offset < self.count);

            var index = self.head + offset;
            index &= self.buf.len - 1;
            return self.buf[index];
        }

        pub fn toOwnedSlice(self: *Self) Allocator.Error![]T {
            if (self.head != 0) self.realign();
            assert(self.head == 0);
            assert(self.count <= self.buf.len);
            const allocator = self.allocator;
            if (allocator.resize(self.buf, self.count)) {
                const result = self.buf[0..self.count];
                self.* = Self.init(allocator);
                return result;
            }
            const new_memory = try allocator.dupe(T, self.buf[0..self.count]);
            allocator.free(self.buf);
            self.* = Self.init(allocator);
            return new_memory;
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
    try testing.expectEqual(@as(usize, 5), fifo.readableLength());
    try testing.expectEqualSlices(u8, "HELLO", fifo.readableSlice(0));

    {
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            try fifo.write(&[_]u8{fifo.peekItem(i)});
        }
        try testing.expectEqual(@as(usize, 10), fifo.readableLength());
        try testing.expectEqualSlices(u8, "HELLOHELLO", fifo.readableSlice(0));
    }

    {
        try testing.expectEqual(@as(u8, 'H'), fifo.readItem().?);
        try testing.expectEqual(@as(u8, 'E'), fifo.readItem().?);
        try testing.expectEqual(@as(u8, 'L'), fifo.readItem().?);
        try testing.expectEqual(@as(u8, 'L'), fifo.readItem().?);
        try testing.expectEqual(@as(u8, 'O'), fifo.readItem().?);
    }
    try testing.expectEqual(@as(usize, 5), fifo.readableLength());

    { // Writes that wrap around
        try testing.expectEqual(@as(usize, 11), fifo.writableLength());
        try testing.expectEqual(@as(usize, 6), fifo.writableSlice(0).len);
        fifo.writeAssumeCapacity("6<chars<11");
        try testing.expectEqualSlices(u8, "HELLO6<char", fifo.readableSlice(0));
        try testing.expectEqualSlices(u8, "s<11", fifo.readableSlice(11));
        try testing.expectEqualSlices(u8, "11", fifo.readableSlice(13));
        try testing.expectEqualSlices(u8, "", fifo.readableSlice(15));
        fifo.discard(11);
        try testing.expectEqualSlices(u8, "s<11", fifo.readableSlice(0));
        fifo.discard(4);
        try testing.expectEqual(@as(usize, 0), fifo.readableLength());
    }

    {
        const buf = try fifo.writableWithSize(12);
        try testing.expectEqual(@as(usize, 12), buf.len);
        var i: u8 = 0;
        while (i < 10) : (i += 1) {
            buf[i] = i + 'a';
        }
        fifo.update(10);
        try testing.expectEqualSlices(u8, "abcdefghij", fifo.readableSlice(0));
    }

    {
        try fifo.unget("prependedstring");
        var result: [30]u8 = undefined;
        try testing.expectEqualSlices(u8, "prependedstringabcdefghij", result[0..fifo.read(&result)]);
        try fifo.unget("b");
        try fifo.unget("a");
        try testing.expectEqualSlices(u8, "ab", result[0..fifo.read(&result)]);
    }

    fifo.shrink(0);

    {
        try fifo.writer().print("{s}, {s}!", .{ "Hello", "World" });
        var result: [30]u8 = undefined;
        try testing.expectEqualSlices(u8, "Hello, World!", result[0..fifo.read(&result)]);
        try testing.expectEqual(@as(usize, 0), fifo.readableLength());
    }

    {
        try fifo.writer().writeAll("This is a test");
        var result: [30]u8 = undefined;
        try testing.expectEqualSlices(u8, "This", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
        try testing.expectEqualSlices(u8, "is", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
        try testing.expectEqualSlices(u8, "a", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
        try testing.expectEqualSlices(u8, "test", (try fifo.reader().readUntilDelimiterOrEof(&result, ' ')).?);
    }

    {
        try fifo.ensureTotalCapacity(1);
        var in_fbs = std.io.fixedBufferStream("pump test");
        var out_buf: [50]u8 = undefined;
        var out_fbs = std.io.fixedBufferStream(&out_buf);
        try fifo.pump(in_fbs.reader(), out_fbs.writer());
        try testing.expectEqualSlices(u8, in_fbs.buffer, out_fbs.getWritten());
    }
}

test LinearFifo {
    inline for ([_]type{ u1, u8, u16, u64 }) |T| {
        const FifoType = LinearFifo(T);
        var fifo: FifoType = .init(testing.allocator);
        defer fifo.deinit();

        try fifo.write(&[_]T{ 0, 1, 1, 0, 1 });
        try testing.expectEqual(@as(usize, 5), fifo.readableLength());

        {
            try testing.expectEqual(@as(T, 0), fifo.readItem().?);
            try testing.expectEqual(@as(T, 1), fifo.readItem().?);
            try testing.expectEqual(@as(T, 1), fifo.readItem().?);
            try testing.expectEqual(@as(T, 0), fifo.readItem().?);
            try testing.expectEqual(@as(T, 1), fifo.readItem().?);
            try testing.expectEqual(@as(usize, 0), fifo.readableLength());
        }

        {
            try fifo.writeItem(1);
            try fifo.writeItem(1);
            try fifo.writeItem(1);
            try testing.expectEqual(@as(usize, 3), fifo.readableLength());
        }

        {
            var readBuf: [3]T = undefined;
            const n = fifo.read(&readBuf);
            try testing.expectEqual(@as(usize, 3), n); // NOTE: It should be the number of items.
        }
    }
}
