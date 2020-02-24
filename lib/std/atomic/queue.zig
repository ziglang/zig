const std = @import("../std.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;
const expect = std.testing.expect;

/// Many producer, many consumer, non-allocating, thread-safe.
/// Uses a mutex to protect access.
pub fn Queue(comptime T: type) type {
    return struct {
        head: ?*Node,
        tail: ?*Node,
        mutex: std.Mutex,

        pub const Self = @This();
        pub const Node = std.TailQueue(T).Node;

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
            return self.head == null;
        }

        pub fn dump(self: *Self) void {
            var stderr_file = std.io.getStdErr() catch return;
            const stderr = &stderr_file.outStream().stream;
            const Error = @typeInfo(@TypeOf(stderr)).Pointer.child.Error;

            self.dumpToStream(Error, stderr) catch return;
        }

        pub fn dumpToStream(self: *Self, comptime Error: type, stream: *std.io.OutStream(Error)) Error!void {
            const S = struct {
                fn dumpRecursive(
                    s: *std.io.OutStream(Error),
                    optional_node: ?*Node,
                    indent: usize,
                    comptime depth: comptime_int,
                ) Error!void {
                    try s.writeByteNTimes(' ', indent);
                    if (optional_node) |node| {
                        try s.print("0x{x}={}\n", .{ @ptrToInt(node), node.data });
                        if (depth == 0) {
                            try s.print("(max depth)\n", .{});
                            return;
                        }
                        try dumpRecursive(s, node.next, indent + 1, depth - 1);
                    } else {
                        try s.print("(null)\n", .{});
                    }
                }
            };
            const held = self.mutex.acquire();
            defer held.release();

            try stream.print("head: ", .{});
            try S.dumpRecursive(stream, self.head, 0, 4);
            try stream.print("tail: ", .{});
            try S.dumpRecursive(stream, self.tail, 0, 4);
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
    var plenty_of_memory = try std.heap.page_allocator.alloc(u8, 300 * 1024);
    defer std.heap.page_allocator.free(plenty_of_memory);

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

    if (builtin.single_threaded) {
        expect(context.queue.isEmpty());
        {
            var i: usize = 0;
            while (i < put_thread_count) : (i += 1) {
                expect(startPuts(&context) == 0);
            }
        }
        expect(!context.queue.isEmpty());
        context.puts_done = 1;
        {
            var i: usize = 0;
            while (i < put_thread_count) : (i += 1) {
                expect(startGets(&context) == 0);
            }
        }
        expect(context.queue.isEmpty());
    } else {
        expect(context.queue.isEmpty());

        var putters: [put_thread_count]*std.Thread = undefined;
        for (putters) |*t| {
            t.* = try std.Thread.spawn(&context, startPuts);
        }
        var getters: [put_thread_count]*std.Thread = undefined;
        for (getters) |*t| {
            t.* = try std.Thread.spawn(&context, startGets);
        }

        for (putters) |t|
            t.wait();
        @atomicStore(u8, &context.puts_done, 1, AtomicOrder.SeqCst);
        for (getters) |t|
            t.wait();

        expect(context.queue.isEmpty());
    }

    if (context.put_sum != context.get_sum) {
        std.debug.panic("failure\nput_sum:{} != get_sum:{}", .{ context.put_sum, context.get_sum });
    }

    if (context.get_count != puts_per_thread * put_thread_count) {
        std.debug.panic("failure\nget_count:{} != puts_per_thread:{} * put_thread_count:{}", .{
            context.get_count,
            @as(u32, puts_per_thread),
            @as(u32, put_thread_count),
        });
    }
}

fn startPuts(ctx: *Context) u8 {
    var put_count: usize = puts_per_thread;
    var r = std.rand.DefaultPrng.init(0xdeadbeef);
    while (put_count != 0) : (put_count -= 1) {
        std.time.sleep(1); // let the os scheduler be our fuzz
        const x = @bitCast(i32, r.random.scalar(u32));
        const node = ctx.allocator.create(Queue(i32).Node) catch unreachable;
        node.* = Queue(i32).Node{
            .prev = undefined,
            .next = undefined,
            .data = x,
        };
        ctx.queue.put(node);
        _ = @atomicRmw(isize, &ctx.put_sum, builtin.AtomicRmwOp.Add, x, AtomicOrder.SeqCst);
    }
    return 0;
}

fn startGets(ctx: *Context) u8 {
    while (true) {
        const last = @atomicLoad(u8, &ctx.puts_done, builtin.AtomicOrder.SeqCst) == 1;

        while (ctx.queue.get()) |node| {
            std.time.sleep(1); // let the os scheduler be our fuzz
            _ = @atomicRmw(isize, &ctx.get_sum, builtin.AtomicRmwOp.Add, node.data, builtin.AtomicOrder.SeqCst);
            _ = @atomicRmw(usize, &ctx.get_count, builtin.AtomicRmwOp.Add, 1, builtin.AtomicOrder.SeqCst);
        }

        if (last) return 0;
    }
}

test "std.atomic.Queue single-threaded" {
    var queue = Queue(i32).init();
    expect(queue.isEmpty());

    var node_0 = Queue(i32).Node{
        .data = 0,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_0);
    expect(!queue.isEmpty());

    var node_1 = Queue(i32).Node{
        .data = 1,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_1);
    expect(!queue.isEmpty());

    expect(queue.get().?.data == 0);
    expect(!queue.isEmpty());

    var node_2 = Queue(i32).Node{
        .data = 2,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_2);
    expect(!queue.isEmpty());

    var node_3 = Queue(i32).Node{
        .data = 3,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_3);
    expect(!queue.isEmpty());

    expect(queue.get().?.data == 1);
    expect(!queue.isEmpty());

    expect(queue.get().?.data == 2);
    expect(!queue.isEmpty());

    var node_4 = Queue(i32).Node{
        .data = 4,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_4);
    expect(!queue.isEmpty());

    expect(queue.get().?.data == 3);
    node_3.next = null;
    expect(!queue.isEmpty());

    expect(queue.get().?.data == 4);
    expect(queue.isEmpty());

    expect(queue.get() == null);
    expect(queue.isEmpty());
}

test "std.atomic.Queue dump" {
    const mem = std.mem;
    const SliceOutStream = std.io.SliceOutStream;
    var buffer: [1024]u8 = undefined;
    var expected_buffer: [1024]u8 = undefined;
    var sos = SliceOutStream.init(buffer[0..]);

    var queue = Queue(i32).init();

    // Test empty stream
    sos.reset();
    try queue.dumpToStream(SliceOutStream.Error, &sos.stream);
    expect(mem.eql(u8, buffer[0..sos.pos],
        \\head: (null)
        \\tail: (null)
        \\
    ));

    // Test a stream with one element
    var node_0 = Queue(i32).Node{
        .data = 1,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_0);

    sos.reset();
    try queue.dumpToStream(SliceOutStream.Error, &sos.stream);

    var expected = try std.fmt.bufPrint(expected_buffer[0..],
        \\head: 0x{x}=1
        \\ (null)
        \\tail: 0x{x}=1
        \\ (null)
        \\
    , .{ @ptrToInt(queue.head), @ptrToInt(queue.tail) });
    expect(mem.eql(u8, buffer[0..sos.pos], expected));

    // Test a stream with two elements
    var node_1 = Queue(i32).Node{
        .data = 2,
        .next = undefined,
        .prev = undefined,
    };
    queue.put(&node_1);

    sos.reset();
    try queue.dumpToStream(SliceOutStream.Error, &sos.stream);

    expected = try std.fmt.bufPrint(expected_buffer[0..],
        \\head: 0x{x}=1
        \\ 0x{x}=2
        \\  (null)
        \\tail: 0x{x}=2
        \\ (null)
        \\
    , .{ @ptrToInt(queue.head), @ptrToInt(queue.head.?.next), @ptrToInt(queue.tail) });
    expect(mem.eql(u8, buffer[0..sos.pos], expected));
}
