const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const Loop = std.event.Loop;

/// many producer, many consumer, thread-safe, lock-free, runtime configurable buffer size
/// when buffer is empty, consumers suspend and are resumed by producers
/// when buffer is full, producers suspend and are resumed by consumers
pub fn Channel(comptime T: type) type {
    return struct {
        loop: *Loop,

        getters: std.atomic.Queue(GetNode),
        putters: std.atomic.Queue(PutNode),
        get_count: usize,
        put_count: usize,
        dispatch_lock: u8, // TODO make this a bool
        need_dispatch: u8, // TODO make this a bool

        // simple fixed size ring buffer
        buffer_nodes: []T,
        buffer_index: usize,
        buffer_len: usize,

        const SelfChannel = this;
        const GetNode = struct {
            ptr: *T,
            tick_node: *Loop.NextTickNode,
        };
        const PutNode = struct {
            data: T,
            tick_node: *Loop.NextTickNode,
        };

        /// call destroy when done
        pub fn create(loop: *Loop, capacity: usize) !*SelfChannel {
            const buffer_nodes = try loop.allocator.alloc(T, capacity);
            errdefer loop.allocator.free(buffer_nodes);

            const self = try loop.allocator.create(SelfChannel{
                .loop = loop,
                .buffer_len = 0,
                .buffer_nodes = buffer_nodes,
                .buffer_index = 0,
                .dispatch_lock = 0,
                .need_dispatch = 0,
                .getters = std.atomic.Queue(GetNode).init(),
                .putters = std.atomic.Queue(PutNode).init(),
                .get_count = 0,
                .put_count = 0,
            });
            errdefer loop.allocator.destroy(self);

            return self;
        }

        /// must be called when all calls to put and get have suspended and no more calls occur
        pub fn destroy(self: *SelfChannel) void {
            while (self.getters.get()) |get_node| {
                cancel get_node.data.tick_node.data;
            }
            while (self.putters.get()) |put_node| {
                cancel put_node.data.tick_node.data;
            }
            self.loop.allocator.free(self.buffer_nodes);
            self.loop.allocator.destroy(self);
        }

        /// puts a data item in the channel. The promise completes when the value has been added to the
        /// buffer, or in the case of a zero size buffer, when the item has been retrieved by a getter.
        pub async fn put(self: *SelfChannel, data: T) void {
            suspend |handle| {
                var my_tick_node = Loop.NextTickNode{
                    .next = undefined,
                    .data = handle,
                };
                var queue_node = std.atomic.Queue(PutNode).Node{
                    .data = PutNode{
                        .tick_node = &my_tick_node,
                        .data = data,
                    },
                    .next = undefined,
                };
                self.putters.put(&queue_node);
                _ = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);

                self.dispatch();
            }
        }

        /// await this function to get an item from the channel. If the buffer is empty, the promise will
        /// complete when the next item is put in the channel.
        pub async fn get(self: *SelfChannel) T {
            // TODO integrate this function with named return values
            // so we can get rid of this extra result copy
            var result: T = undefined;
            suspend |handle| {
                var my_tick_node = Loop.NextTickNode{
                    .next = undefined,
                    .data = handle,
                };
                var queue_node = std.atomic.Queue(GetNode).Node{
                    .data = GetNode{
                        .ptr = &result,
                        .tick_node = &my_tick_node,
                    },
                    .next = undefined,
                };
                self.getters.put(&queue_node);
                _ = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);

                self.dispatch();
            }
            return result;
        }

        fn getOrNull(self: *SelfChannel) ?T {
            TODO();
        }

        fn dispatch(self: *SelfChannel) void {
            // set the "need dispatch" flag
            _ = @atomicRmw(u8, &self.need_dispatch, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);

            lock: while (true) {
                // set the lock flag
                const prev_lock = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
                if (prev_lock != 0) return;

                // clear the need_dispatch flag since we're about to do it
                _ = @atomicRmw(u8, &self.need_dispatch, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);

                while (true) {
                    one_dispatch: {
                        // later we correct these extra subtractions
                        var get_count = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        var put_count = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);

                        // transfer self.buffer to self.getters
                        while (self.buffer_len != 0) {
                            if (get_count == 0) break :one_dispatch;

                            const get_node = &self.getters.get().?.data;
                            get_node.ptr.* = self.buffer_nodes[self.buffer_index -% self.buffer_len];
                            self.loop.onNextTick(get_node.tick_node);
                            self.buffer_len -= 1;

                            get_count = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }

                        // direct transfer self.putters to self.getters
                        while (get_count != 0 and put_count != 0) {
                            const get_node = &self.getters.get().?.data;
                            const put_node = &self.putters.get().?.data;

                            get_node.ptr.* = put_node.data;
                            self.loop.onNextTick(get_node.tick_node);
                            self.loop.onNextTick(put_node.tick_node);

                            get_count = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                            put_count = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }

                        // transfer self.putters to self.buffer
                        while (self.buffer_len != self.buffer_nodes.len and put_count != 0) {
                            const put_node = &self.putters.get().?.data;

                            self.buffer_nodes[self.buffer_index] = put_node.data;
                            self.loop.onNextTick(put_node.tick_node);
                            self.buffer_index +%= 1;
                            self.buffer_len += 1;

                            put_count = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }
                    }

                    // undo the extra subtractions
                    _ = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
                    _ = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);

                    // clear need-dispatch flag
                    const need_dispatch = @atomicRmw(u8, &self.need_dispatch, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                    if (need_dispatch != 0) continue;

                    const my_lock = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                    assert(my_lock != 0);

                    // we have to check again now that we unlocked
                    if (@atomicLoad(u8, &self.need_dispatch, AtomicOrder.SeqCst) != 0) continue :lock;

                    return;
                }
            }
        }
    };
}

test "std.event.Channel" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop: Loop = undefined;
    // TODO make a multi threaded test
    try loop.initSingleThreaded(allocator);
    defer loop.deinit();

    const channel = try Channel(i32).create(&loop, 0);
    defer channel.destroy();

    const handle = try async<allocator> testChannelGetter(&loop, channel);
    defer cancel handle;

    const putter = try async<allocator> testChannelPutter(channel);
    defer cancel putter;

    loop.run();
}

async fn testChannelGetter(loop: *Loop, channel: *Channel(i32)) void {
    errdefer @panic("test failed");

    const value1_promise = try async channel.get();
    const value1 = await value1_promise;
    assert(value1 == 1234);

    const value2_promise = try async channel.get();
    const value2 = await value2_promise;
    assert(value2 == 4567);
}

async fn testChannelPutter(channel: *Channel(i32)) void {
    await (async channel.put(1234) catch @panic("out of memory"));
    await (async channel.put(4567) catch @panic("out of memory"));
}

