// FIFO of fixed size items
// Usually used for e.g. byte buffers

const std = @import("std");
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;

pub fn FixedSizeFifo(comptime T: type) type {
    return struct {
        allocator: *Allocator,
        buf: []u8,
        head: usize,
        count: usize,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return Self{
                .allocator = allocator,
                .buf = [_]T{},
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
                const unused = @sliceToBytes(self.buf[self.count..]);
                @memset(unused.ptr, undefined, unused.len);
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
        pub fn ensureCapacity(self: *Self, size: usize) error{OutOfMemory}!void {
            if (self.buf.len >= size) return;
            self.realign();
            const new_size = math.ceilPowerOfTwo(usize, size) catch return error.OutOfMemory;
            self.buf = try self.allocator.realloc(self.buf, new_size);
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
        fn readableSliceMut(self: Self, offset: usize) []T {
            if (offset > self.count) return [_]T{};

            const start = self.head + offset;
            if (start >= self.buf.len) {
                return self.buf[start - self.buf.len ..][0 .. self.count - offset];
            } else {
                const end: usize = self.head + self.count;
                if (end >= self.buf.len) {
                    return self.buf[start..self.buf.len];
                } else {
                    return self.buf[start..end];
                }
            }
        }

        /// Returns a readable slice from `offset`
        pub fn readableSlice(self: Self, offset: usize) []const T {
            return self.readableSliceMut(offset);
        }

        const autoalign = false;

        /// Discard first `count` bytes of readable data
        pub fn discard(self: *Self, count: usize) void {
            assert(count <= self.count);
            { // set old range to undefined. Note: may be wrapped around
                const slice = self.readableSliceMut(0);
                if (slice.len >= count) {
                    const unused = @sliceToBytes(slice[0..count]);
                    @memset(unused.ptr, undefined, unused.len);
                } else {
                    const unused = @sliceToBytes(slice[0..]);
                    @memset(unused.ptr, undefined, unused.len);
                    const unused2 = @sliceToBytes(self.readableSliceMut(slice.len)[0 .. count - slice.len]);
                    @memset(unused2.ptr, undefined, unused2.len);
                }
            }
            self.head = (self.head + count) % self.buf.len;
            self.count -= count;
            if (autoalign and self.count == 0)
                self.head = 0;
        }

        /// Read the next item from the fifo
        pub fn readItem(self: *Self) !T {
            if (self.count == 0) return error.EndOfStream;

            const c = self.buf[self.head];
            self.discard(1);
            return c;
        }

        /// Read data from the fifo into `dst`, returns slice of bytes copied (subslice of `dst`)
        pub fn read(self: *Self, dst: []T) []T {
            var dst_left = dst;

            while (dst_left.len > 0) {
                const slice = self.readableSlice(0);
                if (slice.len == 0) break;
                const n = math.min(slice.len, dst_left.len);
                mem.copy(T, dst_left, slice[0..n]);
                self.discard(n);
                dst_left = dst_left[n..];
            }

            return dst[0 .. dst.len - dst_left.len];
        }

        /// Returns number of bytes available in fifo
        pub fn writableLength(self: Self) usize {
            return self.buf.len - self.count;
        }

        /// Returns the first section of writable buffer
        /// Note that this may be of length 0
        pub fn writableSlice(self: Self, offset: usize) []T {
            if (offset > self.buf.len) return [_]T{};

            const tail = self.head + offset + self.count;
            if (tail < self.buf.len) {
                return self.buf[tail..];
            } else {
                return self.buf[tail - self.buf.len ..][0 .. self.writableLength() - offset];
            }
        }

        /// Returns a writable buffer of at least `size` bytes, allocating memory as needed.
        /// Use `fifo.update` once you've written data to it.
        pub fn writeableWithSize(self: *Self, size: usize) ![]T {
            try self.ensureUnusedCapacity(size);

            // try to avoid realigning buffer
            var slice = self.writableSlice(0);
            if (slice.len < size) {
                self.realign();
                slice = self.writableSlice(0);
            }
            return slice;
        }

        /// Update the tail location of the buffer (usually follows use of writable/writeableWithSize)
        pub fn update(self: *Self, count: usize) void {
            assert(self.count + count <= self.buf.len);
            self.count += count;
        }

        /// Appends the data in `src` to the fifo. You must
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

        /// Appends the data in `src` to the fifo.
        /// Allocates more memory as necessary
        pub fn write(self: *Self, src: []const T) !void {
            try self.ensureUnusedCapacity(src.len);

            return self.writeAssumeCapacity(src);
        }

        pub fn print(self: *Self, comptime format: []const u8, args: ...) !void {
            return std.fmt.format(self, error{OutOfMemory}, Self.write, format, args);
        }

        /// Make `count` bytes available before the current read location
        fn rewind(self: *Self, size: usize) void {
            assert(self.writableLength() >= size);

            self.head = (self.head + (self.buf.len - size)) % self.buf.len;
            self.count += size;
        }

        /// Place data back into the read stream
        pub fn unget(self: *Self, src: []const T) !void {
            try self.ensureUnusedCapacity(src.len);

            self.rewind(src.len);

            const slice = self.readableSliceMut(0);
            mem.copy(T, slice, src[0..slice.len]);
            const slice2 = self.readableSliceMut(slice.len);
            mem.copy(T, slice2, src[slice.len..]);
        }

        /// Peek at the item at `offset`
        pub fn peekItem(self: Self, offset: usize) error{EndOfStream}!T {
            if (offset >= self.count)
                return error.EndOfStream;

            return self.buf[(self.head + offset) % self.buf.len];
        }
    };
}

const ByteFifo = FixedSizeFifo(u8);

test "ByteFifo" {
    var fifo = ByteFifo.init(debug.global_allocator);
    defer fifo.deinit();

    try fifo.write("HELLO");
    testing.expectEqual(@as(usize, 5), fifo.readableLength());
    testing.expectEqualSlices(u8, "HELLO", fifo.readableSlice(0));

    {
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            try fifo.write([_]u8{try fifo.peekItem(i)});
        }
        testing.expectEqual(@as(usize, 10), fifo.readableLength());
        testing.expectEqualSlices(u8, "HELLOHELLO", fifo.readableSlice(0));
    }

    {
        testing.expectEqual(@as(u8, 'H'), try fifo.readItem());
        testing.expectEqual(@as(u8, 'E'), try fifo.readItem());
        testing.expectEqual(@as(u8, 'L'), try fifo.readItem());
        testing.expectEqual(@as(u8, 'L'), try fifo.readItem());
        testing.expectEqual(@as(u8, 'O'), try fifo.readItem());
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
        const buf = try fifo.writeableWithSize(12);
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
        testing.expectEqualSlices(u8, "prependedstringabcdefghij", fifo.read(&result));
    }

    fifo.shrink(0);

    {
        try fifo.print("{}, {}!", "Hello", "World");
        var result: [30]u8 = undefined;
        testing.expectEqualSlices(u8, "Hello, World!", fifo.read(&result));
        testing.expectEqual(@as(usize, 0), fifo.readableLength());
    }
}
