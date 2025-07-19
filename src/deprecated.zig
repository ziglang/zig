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
    };
}
