const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;

/// Many producer, many consumer, non-allocating, thread-safe, lock-free
/// This implementation has a crippling limitation - it hangs onto node
/// memory for 1 extra get() and 1 extra put() operation - when get() returns a node, that
/// node must not be freed until both the next get() and the next put() completes.
pub fn QueueMpmc(comptime T: type) type {
    return struct {
        head: *Node,
        tail: *Node,
        root: Node,

        pub const Self = this;

        pub const Node = struct {
            next: ?*Node,
            data: T,
        };

        /// TODO: well defined copy elision: https://github.com/ziglang/zig/issues/287
        pub fn init(self: *Self) void {
            self.root.next = null;
            self.head = &self.root;
            self.tail = &self.root;
        }

        pub fn put(self: *Self, node: *Node) void {
            node.next = null;

            const tail = @atomicRmw(*Node, &self.tail, AtomicRmwOp.Xchg, node, AtomicOrder.SeqCst);
            _ = @atomicRmw(?*Node, &tail.next, AtomicRmwOp.Xchg, node, AtomicOrder.SeqCst);
        }

        /// node must not be freed until both the next get() and the next put() complete
        pub fn get(self: *Self) ?*Node {
            var head = @atomicLoad(*Node, &self.head, AtomicOrder.SeqCst);
            while (true) {
                const node = head.next orelse return null;
                head = @cmpxchgWeak(*Node, &self.head, head, node, AtomicOrder.SeqCst, AtomicOrder.SeqCst) orelse return node;
            }
        }

        ///// This is a debug function that is not thread-safe.
        pub fn dump(self: *Self) void {
            std.debug.warn("head: ");
            dumpRecursive(self.head, 0);
            std.debug.warn("tail: ");
            dumpRecursive(self.tail, 0);
        }

        fn dumpRecursive(optional_node: ?*Node, indent: usize) void {
            var stderr_file = std.io.getStdErr() catch return;
            const stderr = &std.io.FileOutStream.init(&stderr_file).stream;
            stderr.writeByteNTimes(' ', indent) catch return;
            if (optional_node) |node| {
                std.debug.warn("0x{x}={}\n", @ptrToInt(node), node.data);
                dumpRecursive(node.next, indent + 1);
            } else {
                std.debug.warn("(null)\n");
            }
        }
    };
}

const std = @import("std");
const assert = std.debug.assert;

const Context = struct {
    allocator: *std.mem.Allocator,
    queue: *QueueMpmc(i32),
    put_sum: isize,
    get_sum: isize,
    get_count: usize,
    puts_done: u8, // TODO make this a bool
};

// TODO add lazy evaluated build options and then put puts_per_thread behind
// some option such as: "AggressiveMultithreadedFuzzTest". In the AppVeyor
// CI we would use a less aggressive setting since at 1 core, while we still
// want this test to pass, we need a smaller value since there is so much thrashing
// we would also use a less aggressive setting when running in valgrind
const puts_per_thread = 500;
const put_thread_count = 3;

test "std.atomic.queue_mpmc" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var plenty_of_memory = try direct_allocator.allocator.alloc(u8, 300 * 1024);
    defer direct_allocator.allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var queue: QueueMpmc(i32) = undefined;
    queue.init();
    var context = Context{
        .allocator = a,
        .queue = &queue,
        .put_sum = 0,
        .get_sum = 0,
        .puts_done = 0,
        .get_count = 0,
    };

    var putters: [put_thread_count]*std.os.Thread = undefined;
    for (putters) |*t| {
        t.* = try std.os.spawnThread(&context, startPuts);
    }
    var getters: [put_thread_count]*std.os.Thread = undefined;
    for (getters) |*t| {
        t.* = try std.os.spawnThread(&context, startGets);
    }

    for (putters) |t|
        t.wait();
    _ = @atomicRmw(u8, &context.puts_done, builtin.AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
    for (getters) |t|
        t.wait();

    if (context.put_sum != context.get_sum) {
        std.debug.panic("failure\nput_sum:{} != get_sum:{}", context.put_sum, context.get_sum);
    }

    if (context.get_count != puts_per_thread * put_thread_count) {
        std.debug.panic(
            "failure\nget_count:{} != puts_per_thread:{} * put_thread_count:{}",
            context.get_count,
            u32(puts_per_thread),
            u32(put_thread_count),
        );
    }
}

fn startPuts(ctx: *Context) u8 {
    var put_count: usize = puts_per_thread;
    var r = std.rand.DefaultPrng.init(0xdeadbeef);
    while (put_count != 0) : (put_count -= 1) {
        std.os.time.sleep(0, 1); // let the os scheduler be our fuzz
        const x = @bitCast(i32, r.random.scalar(u32));
        const node = ctx.allocator.create(QueueMpmc(i32).Node{
            .next = undefined,
            .data = x,
        }) catch unreachable;
        ctx.queue.put(node);
        _ = @atomicRmw(isize, &ctx.put_sum, builtin.AtomicRmwOp.Add, x, AtomicOrder.SeqCst);
    }
    return 0;
}

fn startGets(ctx: *Context) u8 {
    while (true) {
        const last = @atomicLoad(u8, &ctx.puts_done, builtin.AtomicOrder.SeqCst) == 1;

        while (ctx.queue.get()) |node| {
            std.os.time.sleep(0, 1); // let the os scheduler be our fuzz
            _ = @atomicRmw(isize, &ctx.get_sum, builtin.AtomicRmwOp.Add, node.data, builtin.AtomicOrder.SeqCst);
            _ = @atomicRmw(usize, &ctx.get_count, builtin.AtomicRmwOp.Add, 1, builtin.AtomicOrder.SeqCst);
        }

        if (last) return 0;
    }
}

test "std.atomic.queue_mpmc single-threaded" {
    var queue: QueueMpmc(i32) = undefined;
    queue.init();

    var node_0 = QueueMpmc(i32).Node{
        .data = 0,
        .next = undefined,
    };
    queue.put(&node_0);

    var node_1 = QueueMpmc(i32).Node{
        .data = 1,
        .next = undefined,
    };
    queue.put(&node_1);

    assert(queue.get().?.data == 0);

    var node_2 = QueueMpmc(i32).Node{
        .data = 2,
        .next = undefined,
    };
    queue.put(&node_2);

    var node_3 = QueueMpmc(i32).Node{
        .data = 3,
        .next = undefined,
    };
    queue.put(&node_3);

    assert(queue.get().?.data == 1);

    assert(queue.get().?.data == 2);

    var node_4 = QueueMpmc(i32).Node{
        .data = 4,
        .next = undefined,
    };
    queue.put(&node_4);

    assert(queue.get().?.data == 3);
    // if we were to set node_3.next to null here, it would cause this test
    // to fail. this demonstrates the limitation of hanging on to extra memory.

    assert(queue.get().?.data == 4);

    assert(queue.get() == null);
}
