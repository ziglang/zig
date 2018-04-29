const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;

/// Many reader, many writer, non-allocating, thread-safe, lock-free
pub fn Queue(comptime T: type) type {
    return struct {
        head: &Node,
        tail: &Node,
        root: Node,

        pub const Self = this;

        pub const Node = struct {
            next: ?&Node,
            data: T,
        };

        // TODO: well defined copy elision: https://github.com/zig-lang/zig/issues/287
        pub fn init(self: &Self) void {
            self.root.next = null;
            self.head = &self.root;
            self.tail = &self.root;
        }

        pub fn put(self: &Self, node: &Node) void {
            node.next = null;

            const tail = @atomicRmw(&Node, &self.tail, AtomicRmwOp.Xchg, node, AtomicOrder.SeqCst);
            _ = @atomicRmw(?&Node, &tail.next, AtomicRmwOp.Xchg, node, AtomicOrder.SeqCst);
        }

        pub fn get(self: &Self) ?&Node {
            var head = @atomicLoad(&Node, &self.head, AtomicOrder.Acquire);
            while (true) {
                const node = head.next ?? return null;
                head = @cmpxchgWeak(&Node, &self.head, head, node, AtomicOrder.Release, AtomicOrder.Acquire) ?? return node;
            }
        }
    };
}

const std = @import("std");
const Context = struct {
    allocator: &std.mem.Allocator,
    queue: &Queue(i32),
    put_sum: isize,
    get_sum: isize,
    get_count: usize,
    puts_done: u8, // TODO make this a bool
};
const puts_per_thread = 10000;
const put_thread_count = 3;

test "std.atomic.queue" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var plenty_of_memory = try direct_allocator.allocator.alloc(u8, 64 * 1024 * 1024);
    defer direct_allocator.allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var queue: Queue(i32) = undefined;
    queue.init();
    var context = Context {
        .allocator = a,
        .queue = &queue,
        .put_sum = 0,
        .get_sum = 0,
        .puts_done = 0,
        .get_count = 0,
    };

    var putters: [put_thread_count]&std.os.Thread = undefined;
    for (putters) |*t| {
        *t = try std.os.spawnThread(&context, startPuts);
    }
    var getters: [put_thread_count]&std.os.Thread = undefined;
    for (getters) |*t| {
        *t = try std.os.spawnThread(&context, startGets);
    }

    for (putters) |t| t.wait();
    _ = @atomicRmw(u8, &context.puts_done, builtin.AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
    for (getters) |t| t.wait();

    std.debug.assert(context.put_sum == context.get_sum);
    std.debug.assert(context.get_count == puts_per_thread * put_thread_count);
}

fn startPuts(ctx: &Context) u8 {
    var put_count: usize = puts_per_thread;
    var r = std.rand.DefaultPrng.init(0xdeadbeef);
    while (put_count != 0) : (put_count -= 1) {
        std.os.time.sleep(0, 1); // let the os scheduler be our fuzz
        const x = @bitCast(i32, r.random.scalar(u32));
        const node = ctx.allocator.create(Queue(i32).Node) catch unreachable;
        node.data = x;
        ctx.queue.put(node);
        _ = @atomicRmw(isize, &ctx.put_sum, builtin.AtomicRmwOp.Add, x, AtomicOrder.SeqCst);
    }
    return 0;
}

fn startGets(ctx: &Context) u8 {
    while (true) {
        while (ctx.queue.get()) |node| {
            std.os.time.sleep(0, 1); // let the os scheduler be our fuzz
            _ = @atomicRmw(isize, &ctx.get_sum, builtin.AtomicRmwOp.Add, node.data, builtin.AtomicOrder.SeqCst);
            _ = @atomicRmw(usize, &ctx.get_count, builtin.AtomicRmwOp.Add, 1, builtin.AtomicOrder.SeqCst);
        }

        if (@atomicLoad(u8, &ctx.puts_done, builtin.AtomicOrder.SeqCst) == 1) {
            break;
        }
    }
    return 0;
}
