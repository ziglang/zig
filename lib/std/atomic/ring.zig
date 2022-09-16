const std = @import("std");
const builtin = @import("builtin");
const Atomic = std.atomic.Atomic;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

pub const RingKind = enum(u8) {
    mpmc,
    spmc,
    mpsc,
    spsc,
    non_atomic,
    _,
};

/// A fixed size, fifo queue. It is lock-free (but not wait-free). The size
/// must be a power of two.
///
/// Internally, it uses a producer and consumer "span." Each span consists of
/// a head and a tail index. The buffer is considered empty when the consumer
/// head is equal to the producer tail. Conversely, the buffer is considered
/// full when the producer head is equal to the consumer tail plus the size of
/// the buffer.
///
/// The space between a span's head and tail indicates in progress copying
/// in or out of the buffer. For multi-producer or multi-consumer, concurrent
/// writes to or reads from the buffer cause the losing thread to spin. It is
/// possible for a thread to become starved due to this.
///
/// Counterintuitively, each index is not bound within the size of the buffer;
/// instead, additions to each index are bound within the maximum size of the
/// index using wrapping addition. Upon accessing each index's slot, they are
/// masked to get the actual index within the buffer.
///
/// This is largely based off the logic described in DPDK's [rte_ring](https://
/// doc.dpdk.org/guides-1.8/prog_guide/ring_lib.html) library reference.
pub fn RingBuffer(
    comptime T: type,
    comptime size: usize,
    comptime kind: RingKind,
) type {
    std.debug.assert(std.math.isPowerOfTwo(size));
    const idx_mask = size - 1;
    const Span = struct {
        head: Atomic(usize) = .{ .value = 0 },
        tail: Atomic(usize) = .{ .value = 0 },
    };
    return struct {
        const Self = @This();
        /// The backing buffer of all the elements.
        buffer: [size]T = undefined,
        /// Write index.
        producer: Span = .{},
        /// Read index.
        consumer: Span = .{},

        /// Initialize the buffer in-place.
        pub inline fn init(self: *Self) void {
            self.producer = .{};
            self.consumer = .{};
        }

        // Choose the correct `get` function depending upon `kind`.
        pub usingnamespace switch (kind) {
            .mpmc, .spmc => struct {
                /// Get the next item and advance the tail. If the read tail
                /// has caught up to the write head, then null is returned.
                pub fn get(self: *Self) ?T {
                    var head = self.consumer.head.load(.Monotonic);
                    while (true) {
                        // Calculate read space.
                        const end = self.producer.tail.load(.Acquire);
                        const space = end -% head;
                        if (space == 0) return null;

                        // Reserve the next element for reading.
                        const next = head +% 1;
                        if (self.consumer.head.tryCompareAndSwap(
                            head,
                            next,
                            .Acquire,
                            .Monotonic,
                        )) |h| {
                            head = h;
                            std.atomic.spinLoopHint();
                            continue;
                        }

                        // Copy the slot by value.
                        const result = self.buffer[next & idx_mask];

                        // Spin until the consumer tail is equal to where
                        // head began. This orders the write space calculation
                        // in `put` after the copy by value in the previous
                        // statement.
                        while (self.consumer.tail.tryCompareAndSwap(
                            head,
                            next,
                            .Release,
                            .Monotonic,
                        )) |_| {
                            std.atomic.spinLoopHint();
                        }

                        return result;
                    }
                }
            },
            .spsc, .mpsc => struct {
                /// Get the next item and advance the tail. If the read tail
                /// has caught up to the write head, then null is returned.
                //
                // This implementation doesn't use atomic instructions for
                // loading/storing `consumer.head` because there is assumed to
                // only be a single consumer.
                pub fn get(self: *Self) ?T {
                    const end = self.producer.tail.load(.Acquire);
                    const space = end -% self.consumer.head.value;
                    if (space == 0) return null;
                    self.consumer.head.value +%= 1;
                    const result = self.buffer[self.consumer.head.value & idx_mask];
                    _ = self.consumer.tail.fetchAdd(1, .Release);
                    return result;
                }
            },
            .non_atomic => struct {
                /// Get the next item and advance the tail. If the read tail
                /// has caught up to the write head, then null is returned.
                pub fn get(self: *Self) ?T {
                    const space = self.producer.tail.value -% self.consumer.head.value;
                    if (space == 0) return null;
                    self.consumer.head.value +%= 1;
                    const result = self.buffer[self.consumer.head.value & idx_mask];
                    self.consumer.tail.value +%= 1;
                    return result;
                }
            },
            else => struct {},
        };

        // Choose the correct `put` function depending upon `kind`.
        pub usingnamespace switch (kind) {
            .mpmc, .mpsc => struct {
                /// Put the next item and advance the head. If the `new` item
                /// cannot be written (i.e.: write head has caught up to read
                /// tail), then false is returned.
                pub fn put(self: *Self, new: T) bool {
                    var head = self.producer.head.load(.Monotonic);
                    while (true) {
                        // Calculate write space.
                        const end = size +% self.consumer.tail.load(.Acquire);
                        const space = end -% head;
                        if (space == 0) return false;

                        // Reserve the next element for writing.
                        const next = head +% 1;
                        if (self.producer.head.tryCompareAndSwap(
                            head,
                            next,
                            .Acquire,
                            .Monotonic,
                        )) |h| {
                            head = h;
                            std.atomic.spinLoopHint();
                            continue;
                        }

                        self.buffer[next & idx_mask] = new;

                        // Spin until the producer tail is equal to where
                        // head began. This orders the read space calculation
                        // in `get` after the assignment in the previous
                        // statement.
                        while (self.producer.tail.tryCompareAndSwap(
                            head,
                            next,
                            .Release,
                            .Monotonic,
                        )) |_| {
                            std.atomic.spinLoopHint();
                        }

                        return true;
                    }
                }
            },
            .spsc, .spmc => struct {
                /// Put the next item and advance the head. If the `new` item
                /// cannot be written (i.e.: write head has caught up to read
                /// tail), then false is returned.
                pub fn put(self: *Self, new: T) bool {
                    const end = size +% self.consumer.tail.load(.Acquire);
                    const space = end -% self.producer.head.value;
                    if (space == 0) return false;
                    self.producer.head.value +%= 1;
                    self.buffer[self.producer.head.value & idx_mask] = new;
                    _ = self.producer.tail.fetchAdd(1, .Release);
                    return true;
                }
            },
            .non_atomic => struct {
                /// Put the next item and advance the head. If the `new` item
                /// cannot be written (i.e.: write head has caught up to read
                /// tail), then false is returned.
                pub fn put(self: *Self, new: T) bool {
                    const end = size +% self.consumer.tail.value;
                    const space = end -% self.producer.head.value;
                    if (space == 0) return false;
                    self.producer.head.value +%= 1;
                    self.buffer[self.producer.head.value & idx_mask] = new;
                    self.producer.tail.value +%= 1;
                    return true;
                }
            },
            else => struct {},
        };
    };
}

test "Ring fails writing when full" {
    var ring = RingBuffer(usize, 2, .mpmc){};
    try expectEqual(ring.put(1), true);
    try expectEqual(ring.put(2), true);
    try expectEqual(ring.put(3), false);
    try expectEqual(ring.get(), 1);
    try expectEqual(ring.put(3), true);
    try expectEqual(ring.get(), 2);
}

test "Ring fails reading when empty" {
    var ring = RingBuffer(usize, 2, .mpmc){};
    try expectEqual(ring.get(), null);
    try expectEqual(ring.put(1), true);
    try expectEqual(ring.get(), 1);
    try expectEqual(ring.get(), null);
}

test "Ring put thrash doesn't drop data" {
    // Skip this test when using the single_threaded target.
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    // Overly complicated because the extra data is useful when debugging.
    const Msg = struct {
        thread: std.Thread.Id,
        item: u8,
        idx: usize,
    };

    // The threaded function. Each instance pushes the provided `data` down the
    // `ring` and increments `done` when complete.
    const S = struct {
        fn func(
            ring: *RingBuffer(Msg, 8, .mpsc),
            data: []const u8,
            done: *Atomic(usize),
        ) void {
            const id = std.Thread.getCurrentId();
            for (data) |datum, idx| {
                while (!ring.put(.{
                    .thread = id,
                    .item = datum,
                    .idx = idx,
                })) {}
            }
            _ = done.fetchAdd(1, .Release);
        }
    };

    // The data which should be duplicated by each thread and pushed down the
    // ring buffer.
    var data: []u8 = try std.testing.allocator.alloc(u8, 16);
    defer std.testing.allocator.free(data);

    // The seeds to use when populating the data. Add an erroring seed when it
    // appears to uniquely produce an error.
    const seeds = [_]u64{
        0xdeadbeef,
        @truncate(u64, @bitCast(u128, std.time.nanoTimestamp())),
    };

    for (seeds) |seed| {
        // Print the seed so it can be hardcoded in the event that it alone
        // produces the error.
        errdefer std.debug.print("Seed: 0x{x:016}\n", .{seed});

        // The DUT.
        var ring = RingBuffer(Msg, 8, .mpsc){};

        // Generate random data from the given seed.
        var rng = std.rand.DefaultPrng.init(seed);
        rng.fill(data);

        // Incremented by the threads to indicate they have completed.
        var done = Atomic(usize).init(0);

        // Spawn all the threads.
        var threads: [8]std.Thread = undefined;
        for (threads) |*thread| {
            thread.* = try std.Thread.spawn(
                .{},
                S.func,
                .{ &ring, data, &done },
            );
        }
        defer for (threads) |thread| {
            thread.join();
        };

        // Collect all the duplicated data into a single buffer by pulling from
        // the ring continuously until all threads have completed.
        var results = std.ArrayList(u8).init(std.testing.allocator);
        defer results.deinit();
        while (done.load(.Monotonic) < threads.len) {
            while (ring.get()) |datum| {
                try results.append(datum.item);
            }
        }

        // Early sanity check to show at least the correct number of items was
        // received. This doesn't necessarily indicate all the correct data
        // was transmitted (i.e.: double send + dropped data).
        try expectEqual(results.items.len, data.len * threads.len);

        // Sort both the results and the input data.
        std.sort.sort(u8, data, {}, comptime std.sort.asc(u8));
        std.sort.sort(u8, results.items, {}, comptime std.sort.asc(u8));

        // Compare byte by byte. Can't do `expectEqualSlices` because each item
        // in `data` is duplicated `threads.len` times in result.
        for (results.items) |result, idx| {
            try expectEqual(result, data[idx / threads.len]);
        }
    }
}

test "Ring get thrash doesn't duplicate or drop data" {
    // Skip this test when using the single_threaded target.
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    // The threaded function. Each instance waits for `pushing` to be set then
    // collects from `ring` into `dest`.
    const S = struct {
        fn func(
            pushing: *std.Thread.ResetEvent,
            ring: *RingBuffer(u8, 8, .spmc),
            dest: *std.ArrayList(u8),
        ) void {
            pushing.wait();
            while (pushing.isSet()) {
                while (ring.get()) |item| {
                    dest.append(item) catch unreachable;
                }
            }
        }
    };

    // The data which should be pushed down the ring.
    var data: []u8 = try std.testing.allocator.alloc(u8, 16);
    defer std.testing.allocator.free(data);

    // The seeds to use when populating the data. Add an erroring seed when it
    // appears to uniquely produce an error.
    const seeds = [_]u64{
        0xdeadbeef,
        @truncate(u64, @bitCast(u128, std.time.nanoTimestamp())),
    };

    for (seeds) |seed| {
        // Print the seed so it can be hardcoded in the event that it alone
        // produces the error.
        errdefer std.debug.print("Seed: 0x{x:016}\n", .{seed});

        // Generate random data from the given seed.
        var rng = std.rand.DefaultPrng.init(seed);
        rng.fill(data);

        // Set when the main thread has started pushing down the pipeline.
        var pushing = std.Thread.ResetEvent{};

        // The DUT.
        var ring = RingBuffer(u8, 8, .spmc){};

        // Spawn all the threads, creating the dest for each.
        var threads: [8]struct {
            thread: std.Thread,
            dest: std.ArrayList(u8),
        } = undefined;
        for (threads) |*thread| {
            thread.dest = std.ArrayList(u8).init(std.testing.allocator);
            thread.thread = try std.Thread.spawn(
                .{},
                S.func,
                .{ &pushing, &ring, &thread.dest },
            );
        }
        defer for (threads) |thread| {
            thread.dest.deinit();
        };

        // Start pushing down the ring.
        pushing.set();
        for (data) |datum| {
            while (!ring.put(datum)) {}
        }
        pushing.reset();

        // Wait for all threads to complete.
        for (threads) |thread| {
            thread.thread.join();
        }

        // Collect all the results into a single buffer.
        var results = std.ArrayList(u8).init(std.testing.allocator);
        defer results.deinit();
        for (threads) |thread| {
            try results.appendSlice(thread.dest.items);
        }

        // Sort both the input data and the results.
        std.sort.sort(u8, data, {}, comptime std.sort.asc(u8));
        std.sort.sort(u8, results.items, {}, comptime std.sort.asc(u8));

        // All the data should have been received.
        try expectEqualSlices(u8, data, results.items);
    }
}

test "NonAtomicRing fails writing when full" {
    var ring = RingBuffer(usize, 2, .non_atomic){};
    try expectEqual(ring.put(1), true);
    try expectEqual(ring.put(2), true);
    try expectEqual(ring.put(3), false);
    try expectEqual(ring.get(), 1);
    try expectEqual(ring.put(3), true);
    try expectEqual(ring.get(), 2);
}

test "NonAtomicRing fails reading when empty" {
    var ring = RingBuffer(usize, 2, .non_atomic){};
    try expectEqual(ring.get(), null);
    try expectEqual(ring.put(1), true);
    try expectEqual(ring.get(), 1);
    try expectEqual(ring.get(), null);
}
