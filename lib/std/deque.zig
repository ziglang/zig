const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

/// A contiguous, growable, double-ended queue.
///
/// Pushing/popping items from either end of the queue is O(1).
pub fn Deque(comptime T: type) type {
    return struct {
        const Self = @This();

        /// A ring buffer.
        buffer: []T,
        /// The index in buffer where the first item in the logical deque is stored.
        head: usize,
        /// The number of items stored in the logical deque.
        len: usize,

        /// A Deque containing no elements.
        pub const empty: Self = .{
            .buffer = &.{},
            .head = 0,
            .len = 0,
        };

        /// Initialize with capacity to hold `capacity` elements.
        /// The resulting capacity will equal `capacity` exactly.
        /// Deinitialize with `deinit`.
        pub fn initCapacity(gpa: Allocator, capacity: usize) Allocator.Error!Self {
            var deque: Self = .empty;
            try deque.ensureTotalCapacityPrecise(gpa, capacity);
            return deque;
        }

        /// Initialize with externally-managed memory. The buffer determines the
        /// capacity and the deque is initially empty.
        ///
        /// When initialized this way, all functions that accept an Allocator
        /// argument cause illegal behavior.
        pub fn initBuffer(buffer: []T) Self {
            return .{
                .buffer = buffer,
                .head = 0,
                .len = 0,
            };
        }

        /// Release all allocated memory.
        pub fn deinit(deque: *Self, gpa: Allocator) void {
            gpa.free(deque.buffer);
            deque.* = undefined;
        }

        /// Modify the deque so that it can hold at least `new_capacity` items.
        /// Implements super-linear growth to achieve amortized O(1) push/pop operations.
        /// Invalidates element pointers if additional memory is needed.
        pub fn ensureTotalCapacity(deque: *Self, gpa: Allocator, new_capacity: usize) Allocator.Error!void {
            if (deque.buffer.len >= new_capacity) return;
            return deque.ensureTotalCapacityPrecise(gpa, std.ArrayList(T).growCapacity(new_capacity));
        }

        /// If the current capacity is less than `new_capacity`, this function will
        /// modify the deque so that it can hold exactly `new_capacity` items.
        /// Invalidates element pointers if additional memory is needed.
        pub fn ensureTotalCapacityPrecise(deque: *Self, gpa: Allocator, new_capacity: usize) Allocator.Error!void {
            if (deque.buffer.len >= new_capacity) return;
            const old_buffer = deque.buffer;
            if (gpa.remap(old_buffer, new_capacity)) |new_buffer| {
                // If the items wrap around the end of the buffer we need to do
                // a memcpy to prevent a gap after resizing the buffer.
                if (deque.head > old_buffer.len - deque.len) {
                    // The gap splits the items in the deque into head and tail parts.
                    // Choose the shorter part to copy.
                    const head = new_buffer[deque.head..old_buffer.len];
                    const tail = new_buffer[0 .. deque.len - head.len];
                    if (head.len > tail.len and new_buffer.len - old_buffer.len > tail.len) {
                        @memcpy(new_buffer[old_buffer.len..][0..tail.len], tail);
                    } else {
                        // In this case overlap is possible if e.g. the capacity increase is 1
                        // and head.len is greater than 1.
                        deque.head = new_buffer.len - head.len;
                        @memmove(new_buffer[deque.head..][0..head.len], head);
                    }
                }
                deque.buffer = new_buffer;
            } else {
                const new_buffer = try gpa.alloc(T, new_capacity);
                if (deque.head < old_buffer.len - deque.len) {
                    @memcpy(new_buffer[0..deque.len], old_buffer[deque.head..][0..deque.len]);
                } else {
                    const head = old_buffer[deque.head..];
                    const tail = old_buffer[0 .. deque.len - head.len];
                    @memcpy(new_buffer[0..head.len], head);
                    @memcpy(new_buffer[head.len..][0..tail.len], tail);
                }
                deque.head = 0;
                deque.buffer = new_buffer;
                gpa.free(old_buffer);
            }
        }

        /// Modify the deque so that it can hold at least `additional_count` **more** items.
        /// Invalidates element pointers if additional memory is needed.
        pub fn ensureUnusedCapacity(
            deque: *Self,
            gpa: Allocator,
            additional_count: usize,
        ) Allocator.Error!void {
            return deque.ensureTotalCapacity(gpa, try addOrOom(deque.len, additional_count));
        }

        /// Add one item to the front of the deque.
        ///
        /// Invalidates element pointers if additional memory is needed.
        pub fn pushFront(deque: *Self, gpa: Allocator, item: T) error{OutOfMemory}!void {
            try deque.ensureUnusedCapacity(gpa, 1);
            deque.pushFrontAssumeCapacity(item);
        }

        /// Add one item to the front of the deque.
        ///
        /// Never invalidates element pointers.
        ///
        /// If the deque lacks unused capacity for the additional item, returns
        /// `error.OutOfMemory`.
        pub fn pushFrontBounded(deque: *Self, item: T) error{OutOfMemory}!void {
            if (deque.buffer.len - deque.len == 0) return error.OutOfMemory;
            return deque.pushFrontAssumeCapacity(item);
        }

        /// Add one item to the front of the deque.
        ///
        /// Never invalidates element pointers.
        ///
        /// Asserts that the deque can hold one additional item.
        pub fn pushFrontAssumeCapacity(deque: *Self, item: T) void {
            assert(deque.len < deque.buffer.len);
            if (deque.head == 0) {
                deque.head = deque.buffer.len;
            }
            deque.head -= 1;
            deque.buffer[deque.head] = item;
            deque.len += 1;
        }

        /// Add one item to the back of the deque.
        ///
        /// Invalidates element pointers if additional memory is needed.
        pub fn pushBack(deque: *Self, gpa: Allocator, item: T) error{OutOfMemory}!void {
            try deque.ensureUnusedCapacity(gpa, 1);
            deque.pushBackAssumeCapacity(item);
        }

        /// Add one item to the back of the deque.
        ///
        /// Never invalidates element pointers.
        ///
        /// If the deque lacks unused capacity for the additional item, returns
        /// `error.OutOfMemory`.
        pub fn pushBackBounded(deque: *Self, item: T) error{OutOfMemory}!void {
            if (deque.buffer.len - deque.len == 0) return error.OutOfMemory;
            deque.pushBackAssumeCapacity(item);
        }

        /// Add one item to the back of the deque.
        ///
        /// Never invalidates element pointers.
        ///
        /// Asserts that the deque can hold one additional item.
        pub fn pushBackAssumeCapacity(deque: *Self, item: T) void {
            assert(deque.len < deque.buffer.len);
            const buffer_index = deque.bufferIndex(deque.len);
            deque.buffer[buffer_index] = item;
            deque.len += 1;
        }

        /// Return the first item in the deque or null if empty.
        pub fn front(deque: *const Self) ?T {
            if (deque.len == 0) return null;
            return deque.buffer[deque.head];
        }

        /// Return the last item in the deque or null if empty.
        pub fn back(deque: *const Self) ?T {
            if (deque.len == 0) return null;
            return deque.buffer[deque.bufferIndex(deque.len - 1)];
        }

        /// Return the item at the given index in the deque.
        ///
        /// The first item in the queue is at index 0.
        ///
        /// Asserts that the index is in-bounds.
        pub fn at(deque: *const Self, index: usize) T {
            assert(index < deque.len);
            return deque.buffer[deque.bufferIndex(index)];
        }

        /// Remove and return the first item in the deque or null if empty.
        pub fn popFront(deque: *Self) ?T {
            if (deque.len == 0) return null;
            const pop_index = deque.head;
            deque.head = deque.bufferIndex(1);
            deque.len -= 1;
            return deque.buffer[pop_index];
        }

        /// Remove and return the last item in the deque or null if empty.
        pub fn popBack(deque: *Self) ?T {
            if (deque.len == 0) return null;
            deque.len -= 1;
            return deque.buffer[deque.bufferIndex(deque.len)];
        }

        pub const Iterator = struct {
            deque: *const Self,
            index: usize,

            pub fn next(it: *Iterator) ?T {
                if (it.index < it.deque.len) {
                    defer it.index += 1;
                    return it.deque.at(it.index);
                } else {
                    return null;
                }
            }
        };

        /// Iterates over all items in the deque in order from front to back.
        pub fn iterator(deque: *const Self) Iterator {
            return .{ .deque = deque, .index = 0 };
        }

        /// Returns the index in `buffer` where the element at the given
        /// index in the logical deque is stored.
        fn bufferIndex(deque: *const Self, index: usize) usize {
            // This function is written in this way to avoid overflow and
            // expensive division.
            const head_len = deque.buffer.len - deque.head;
            if (index < head_len) {
                return deque.head + index;
            } else {
                return index - head_len;
            }
        }
    };
}

/// Integer addition returning `error.OutOfMemory` on overflow.
fn addOrOom(a: usize, b: usize) error{OutOfMemory}!usize {
    const result, const overflow = @addWithOverflow(a, b);
    if (overflow != 0) return error.OutOfMemory;
    return result;
}

test "basic" {
    const testing = std.testing;
    const gpa = testing.allocator;

    var q: Deque(u32) = .empty;
    defer q.deinit(gpa);

    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());

    try q.pushBack(gpa, 1);
    try q.pushBack(gpa, 2);
    try q.pushBack(gpa, 3);
    try q.pushFront(gpa, 0);

    try testing.expectEqual(0, q.popFront());
    try testing.expectEqual(1, q.popFront());
    try testing.expectEqual(3, q.popBack());
    try testing.expectEqual(2, q.popFront());
    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());
}

test "buffer" {
    const testing = std.testing;

    var buffer: [4]u32 = undefined;
    var q: Deque(u32) = .initBuffer(&buffer);

    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());

    try q.pushBackBounded(1);
    try q.pushBackBounded(2);
    try q.pushBackBounded(3);
    try q.pushFrontBounded(0);
    try testing.expectError(error.OutOfMemory, q.pushBackBounded(4));

    try testing.expectEqual(0, q.popFront());
    try testing.expectEqual(1, q.popFront());
    try testing.expectEqual(3, q.popBack());
    try testing.expectEqual(2, q.popFront());
    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());
}

test "slow growth" {
    const testing = std.testing;
    const gpa = testing.allocator;

    var q: Deque(i32) = .empty;
    defer q.deinit(gpa);

    try q.ensureTotalCapacityPrecise(gpa, 1);
    q.pushBackAssumeCapacity(1);
    try q.ensureTotalCapacityPrecise(gpa, 2);
    q.pushFrontAssumeCapacity(0);
    try q.ensureTotalCapacityPrecise(gpa, 3);
    q.pushBackAssumeCapacity(2);
    try q.ensureTotalCapacityPrecise(gpa, 5);
    q.pushBackAssumeCapacity(3);
    q.pushFrontAssumeCapacity(-1);
    try q.ensureTotalCapacityPrecise(gpa, 6);
    q.pushFrontAssumeCapacity(-2);

    try testing.expectEqual(-2, q.popFront());
    try testing.expectEqual(-1, q.popFront());
    try testing.expectEqual(3, q.popBack());
    try testing.expectEqual(0, q.popFront());
    try testing.expectEqual(2, q.popBack());
    try testing.expectEqual(1, q.popBack());
    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());
}

test "fuzz against ArrayList oracle" {
    try std.testing.fuzz({}, fuzzAgainstArrayList, .{});
}

const FuzzAllocator = struct {
    smith: *std.testing.Smith,
    bufs: [2][256 * 4]u8 align(4),
    used_bitmap: u2,
    used_len: [2]usize,

    pub fn init(smith: *std.testing.Smith) FuzzAllocator {
        return .{
            .smith = smith,
            .bufs = undefined,
            .used_len = undefined,
            .used_bitmap = 0,
        };
    }

    pub fn allocator(f: *FuzzAllocator) std.mem.Allocator {
        return .{
            .ptr = f,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    pub fn allocCount(f: *FuzzAllocator) u2 {
        return @popCount(f.used_bitmap);
    }

    fn alloc(ctx: *anyopaque, len: usize, a: std.mem.Alignment, _: usize) ?[*]u8 {
        const f: *FuzzAllocator = @ptrCast(@alignCast(ctx));
        assert(a == .@"4");
        assert(len % 4 == 0);

        const slot: u1 = @intCast(@ctz(~f.used_bitmap));
        const buf: []u8 = &f.bufs[slot];
        if (len > buf.len) return null;
        f.used_bitmap |= @as(u2, 1) << slot;
        f.used_len[slot] = len;
        return buf.ptr;
    }

    fn memSlot(f: *FuzzAllocator, mem: []u8) u1 {
        const slot: u1 = if (&mem[0] == &f.bufs[0][0])
            0
        else if (&mem[0] == &f.bufs[1][0])
            1
        else
            unreachable;
        assert((f.used_bitmap >> slot) & 1 == 1);
        assert(mem.len == f.used_len[slot]);
        return slot;
    }

    fn resize(ctx: *anyopaque, mem: []u8, a: std.mem.Alignment, new_len: usize, _: usize) bool {
        const f: *FuzzAllocator = @ptrCast(@alignCast(ctx));
        assert(a == .@"4");
        assert(f.allocCount() == 1);

        const slot = f.memSlot(mem);
        if (new_len > f.bufs[slot].len or f.smith.value(bool)) return false;
        f.used_len[slot] = new_len;
        return true;
    }

    fn remap(ctx: *anyopaque, mem: []u8, a: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
        const f: *FuzzAllocator = @ptrCast(@alignCast(ctx));
        assert(a == .@"4");
        assert(f.allocCount() == 1);

        const slot = f.memSlot(mem);
        if (new_len > f.bufs[slot].len or f.smith.value(bool)) return null;

        if (f.smith.value(bool)) {
            f.used_len[slot] = new_len;
            // remap in place
            return mem.ptr;
        } else {
            // moving remap
            const new_slot = ~slot;
            f.used_bitmap = ~f.used_bitmap;
            f.used_len[new_slot] = new_len;

            const new_buf = &f.bufs[new_slot];
            @memcpy(new_buf[0..mem.len], mem);
            return new_buf.ptr;
        }
    }

    fn free(ctx: *anyopaque, mem: []u8, a: std.mem.Alignment, _: usize) void {
        const f: *FuzzAllocator = @ptrCast(@alignCast(ctx));
        assert(a == .@"4");
        f.used_bitmap ^= @as(u2, 1) << f.memSlot(mem);
    }
};

fn fuzzAgainstArrayList(_: void, smith: *std.testing.Smith) anyerror!void {
    const testing = std.testing;

    var q_gpa_inst: FuzzAllocator = .init(smith);
    var l_gpa_buf: [q_gpa_inst.bufs[0].len]u8 align(4) = undefined;
    var l_gpa_inst: std.heap.FixedBufferAllocator = .init(&l_gpa_buf);
    const q_gpa = q_gpa_inst.allocator();
    const l_gpa = l_gpa_inst.allocator();

    var q: Deque(u32) = .empty;
    var l: std.ArrayList(u32) = .empty;

    const Action = enum(u8) {
        grow,
        push_back,
        push_front,
        pop_back,
        pop_front,
    };

    while (!smith.eosWeightedSimple(15, 1)) {
        const baseline = testing.Smith.baselineWeights(Action);
        const grow_weight: testing.Smith.Weight = .value(Action, .grow, 3);
        switch (smith.valueWeighted(Action, baseline ++ .{grow_weight})) {
            .push_back => {
                const item = smith.value(u32);
                try testing.expectEqual(
                    l.appendBounded(item),
                    q.pushBackBounded(item),
                );
            },
            .push_front => {
                const item = smith.value(u32);
                try testing.expectEqual(
                    l.insertBounded(0, item),
                    q.pushFrontBounded(item),
                );
            },
            .pop_back => {
                try testing.expectEqual(l.pop(), q.popBack());
            },
            .pop_front => {
                try testing.expectEqual(
                    if (l.items.len > 0) l.orderedRemove(0) else null,
                    q.popFront(),
                );
            },
            // Growing by small, random, linear amounts seems to better test
            // ensureTotalCapacityPrecise(), which is the most complex part
            // of the Deque implementation.
            .grow => {
                const growth = smith.value(u3);
                try l.ensureTotalCapacityPrecise(l_gpa, l.items.len + growth);
                try q.ensureTotalCapacityPrecise(q_gpa, q.len + growth);
            },
        }
        try testing.expectEqual(l.getLastOrNull(), q.back());
        try testing.expectEqual(
            if (l.items.len > 0) l.items[0] else null,
            q.front(),
        );
        try testing.expectEqual(l.items.len, q.len);
        try testing.expectEqual(l.capacity, q.buffer.len);
        {
            var it = q.iterator();
            for (l.items) |item| {
                try testing.expectEqual(item, it.next());
            }
            try testing.expectEqual(null, it.next());
        }
        try testing.expectEqual(@intFromBool(q.buffer.len != 0), q_gpa_inst.allocCount());
    }
    q.deinit(q_gpa);
    try testing.expectEqual(0, q_gpa_inst.allocCount());
}
