const std = @import("../index.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;

/// Many producer, single consumer, non-allocating, thread-safe, lock-free
pub fn QueueMpsc(comptime T: type) type {
    return struct {
        inboxes: [2]std.atomic.Stack(T),
        outbox: std.atomic.Stack(T),
        inbox_index: usize,

        pub const Self = this;

        pub const Node = std.atomic.Stack(T).Node;

        pub fn init() Self {
            return Self{
                .inboxes = []std.atomic.Stack(T){
                    std.atomic.Stack(T).init(),
                    std.atomic.Stack(T).init(),
                },
                .outbox = std.atomic.Stack(T).init(),
                .inbox_index = 0,
            };
        }

        pub fn put(self: *Self, node: *Node) void {
            const inbox_index = @atomicLoad(usize, &self.inbox_index, AtomicOrder.SeqCst);
            const inbox = &self.inboxes[inbox_index];
            inbox.push(node);
        }

        pub fn get(self: *Self) ?*Node {
            if (self.outbox.pop()) |node| {
                return node;
            }
            const prev_inbox_index = @atomicRmw(usize, &self.inbox_index, AtomicRmwOp.Xor, 0x1, AtomicOrder.SeqCst);
            const prev_inbox = &self.inboxes[prev_inbox_index];
            while (prev_inbox.pop()) |node| {
                self.outbox.push(node);
            }
            return self.outbox.pop();
        }
    };
}

const Context = struct {
    allocator: *std.mem.Allocator,
    queue: *QueueMpsc(i32),
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

test "std.atomic.queue_mpsc" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var plenty_of_memory = try direct_allocator.allocator.alloc(u8, 300 * 1024);
    defer direct_allocator.allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var queue = QueueMpsc(i32).init();
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
    var getters: [1]*std.os.Thread = undefined;
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
        const node = ctx.allocator.create(QueueMpsc(i32).Node{
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
