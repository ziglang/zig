const std = @import("../index.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;

/// Many producer, many consumer, non-allocating, thread-safe.
/// Uses a mutex to protect access.
pub fn Queue(comptime T: type) type {
    return struct {
        head: ?*Node,
        tail: ?*Node,
        mutex: std.Mutex,

        pub const Self = @This();
        pub const Node = std.LinkedList(T).Node;

        pub fn init() Self {
            return Self{
                .head = null,
                .tail = null,
                .mutex = std.Mutex.init(),
            };
        }

        pub fn put(self: *Self, node: *Node) void {
            node.next = null;

            const held = self.mutex.acquire();
            defer held.release();

            node.prev = self.tail;
            self.tail = node;
            if (node.prev) |prev_tail| {
                prev_tail.next = node;
            } else {
                assert(self.head == null);
                self.head = node;
            }
        }

        pub fn get(self: *Self) ?*Node {
            const held = self.mutex.acquire();
            defer held.release();

            const head = self.head orelse return null;
            self.head = head.next;
            if (head.next) |new_head| {
                new_head.prev = null;
            } else {
                self.tail = null;
            }
            // This way, a get() and a remove() are thread-safe with each other.
            head.prev = null;
            head.next = null;
            return head;
        }

        pub fn unget(self: *Self, node: *Node) void {
            node.prev = null;

            const held = self.mutex.acquire();
            defer held.release();

            const opt_head = self.head;
            self.head = node;
            if (opt_head) |head| {
                head.next = node;
            } else {
                assert(self.tail == null);
                self.tail = node;
            }
        }

        /// Thread-safe with get() and remove(). Returns whether node was actually removed.
        pub fn remove(self: *Self, node: *Node) bool {
            const held = self.mutex.acquire();
            defer held.release();

            if (node.prev == null and node.next == null and self.head != node) {
                return false;
            }

            if (node.prev) |prev| {
                prev.next = node.next;
            } else {
                self.head = node.next;
            }
            if (node.next) |next| {
                next.prev = node.prev;
            } else {
                self.tail = node.prev;
            }
            node.prev = null;
            node.next = null;
            return true;
        }

        pub fn isEmpty(self: *Self) bool {
            const held = self.mutex.acquire();
            defer held.release();
            return self.head != null;
        }

        pub fn dump(self: *Self) void {
            const held = self.mutex.acquire();
            defer held.release();

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

const Context = struct {
    allocator: *std.mem.Allocator,
    queue: *Queue(i32),
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

test "std.atomic.Queue" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var plenty_of_memory = try direct_allocator.allocator.alloc(u8, 300 * 1024);
    defer direct_allocator.allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var queue = Queue(i32).init();
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
        const node = ctx.allocator.create(Queue(i32).Node{
            .prev = undefined,
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

test "std.atomic.Queue single-threaded" {
    var queue = Queue(i32).init();

    var node_0 = Queue(i32).Node{
        .data = 0,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_0);

    var node_1 = Queue(i32).Node{
        .data = 1,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_1);

    assert(queue.get().?.data == 0);

    var node_2 = Queue(i32).Node{
        .data = 2,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_2);

    var node_3 = Queue(i32).Node{
        .data = 3,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_3);

    assert(queue.get().?.data == 1);

    assert(queue.get().?.data == 2);

    var node_4 = Queue(i32).Node{
        .data = 4,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_4);

    assert(queue.get().?.data == 3);
    node_3.next = null;

    assert(queue.get().?.data == 4);

    assert(queue.get() == null);
}
