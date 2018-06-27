const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;

/// Many reader, many writer, non-allocating, thread-safe, lock-free
pub fn Stack(comptime T: type) type {
    return struct {
        root: ?*Node,

        pub const Self = this;

        pub const Node = struct {
            next: ?*Node,
            data: T,
        };

        pub fn init() Self {
            return Self{ .root = null };
        }

        /// push operation, but only if you are the first item in the stack. if you did not succeed in
        /// being the first item in the stack, returns the other item that was there.
        pub fn pushFirst(self: *Self, node: *Node) ?*Node {
            node.next = null;
            return @cmpxchgStrong(?*Node, &self.root, null, node, AtomicOrder.SeqCst, AtomicOrder.SeqCst);
        }

        pub fn push(self: *Self, node: *Node) void {
            var root = @atomicLoad(?*Node, &self.root, AtomicOrder.SeqCst);
            while (true) {
                node.next = root;
                root = @cmpxchgWeak(?*Node, &self.root, root, node, AtomicOrder.SeqCst, AtomicOrder.SeqCst) orelse break;
            }
        }

        pub fn pop(self: *Self) ?*Node {
            var root = @atomicLoad(?*Node, &self.root, AtomicOrder.SeqCst);
            while (true) {
                root = @cmpxchgWeak(?*Node, &self.root, root, (root orelse return null).next, AtomicOrder.SeqCst, AtomicOrder.SeqCst) orelse return root;
            }
        }

        pub fn isEmpty(self: *Self) bool {
            return @atomicLoad(?*Node, &self.root, AtomicOrder.SeqCst) == null;
        }
    };
}

const std = @import("std");
const Context = struct {
    allocator: *std.mem.Allocator,
    stack: *Stack(i32),
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

test "std.atomic.stack" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var plenty_of_memory = try direct_allocator.allocator.alloc(u8, 300 * 1024);
    defer direct_allocator.allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var stack = Stack(i32).init();
    var context = Context{
        .allocator = a,
        .stack = &stack,
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
        const node = ctx.allocator.create(Stack(i32).Node{
            .next = undefined,
            .data = x,
        }) catch unreachable;
        ctx.stack.push(node);
        _ = @atomicRmw(isize, &ctx.put_sum, builtin.AtomicRmwOp.Add, x, AtomicOrder.SeqCst);
    }
    return 0;
}

fn startGets(ctx: *Context) u8 {
    while (true) {
        const last = @atomicLoad(u8, &ctx.puts_done, builtin.AtomicOrder.SeqCst) == 1;

        while (ctx.stack.pop()) |node| {
            std.os.time.sleep(0, 1); // let the os scheduler be our fuzz
            _ = @atomicRmw(isize, &ctx.get_sum, builtin.AtomicRmwOp.Add, node.data, builtin.AtomicOrder.SeqCst);
            _ = @atomicRmw(usize, &ctx.get_count, builtin.AtomicRmwOp.Add, 1, builtin.AtomicOrder.SeqCst);
        }

        if (last) return 0;
    }
}
