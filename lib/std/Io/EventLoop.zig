const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const EventLoop = @This();

gpa: Allocator,
queue: std.DoublyLinkedList(void),
free: std.DoublyLinkedList(void),
main_fiber_buffer: [@sizeOf(Fiber) + max_result_len]u8 align(@alignOf(Fiber)),

threadlocal var current_fiber: *Fiber = undefined;

const max_result_len = 64;
const min_stack_size = 4 * 1024 * 1024;

const Fiber = struct {
    regs: Regs,
    awaiter: ?*Fiber,
    queue_node: std.DoublyLinkedList(void).Node,

    const finished: ?*Fiber = @ptrFromInt(std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(Fiber)));

    fn resultPointer(f: *Fiber) [*]u8 {
        const base: [*]u8 = @ptrCast(f);
        return base + @sizeOf(Fiber);
    }

    fn stackEndPointer(f: *Fiber) [*]u8 {
        const base: [*]u8 = @ptrCast(f);
        return base + std.mem.alignForward(
            usize,
            @sizeOf(Fiber) + max_result_len + min_stack_size,
            std.heap.page_size_max,
        );
    }
};

pub fn init(el: *EventLoop, gpa: Allocator) void {
    el.* = .{
        .gpa = gpa,
        .queue = .{},
        .free = .{},
        .main_fiber_buffer = undefined,
    };
    current_fiber = @ptrCast(&el.main_fiber_buffer);
}

fn allocateFiber(el: *EventLoop, result_len: usize) error{OutOfMemory}!*Fiber {
    assert(result_len <= max_result_len);
    const free_node = el.free.pop() orelse {
        const n = std.mem.alignForward(
            usize,
            @sizeOf(Fiber) + max_result_len + min_stack_size,
            std.heap.page_size_max,
        );
        return @alignCast(@ptrCast(try el.gpa.alignedAlloc(u8, @alignOf(Fiber), n)));
    };
    return @fieldParentPtr("queue_node", free_node);
}

fn yield(el: *EventLoop, optional_fiber: ?*Fiber) void {
    if (optional_fiber) |fiber| {
        const old = &current_fiber.regs;
        current_fiber = fiber;
        contextSwitch(old, &fiber.regs);
        return;
    }
    if (el.queue.pop()) |node| {
        const fiber: *Fiber = @fieldParentPtr("queue_node", node);
        const old = &current_fiber.regs;
        current_fiber = fiber;
        contextSwitch(old, &fiber.regs);
        return;
    }
    @panic("everything is done");
}

/// Equivalent to calling `yield` and then giving the fiber back to the event loop.
fn exit(el: *EventLoop, optional_fiber: ?*Fiber) noreturn {
    yield(el, optional_fiber);
    @panic("TODO recycle the fiber");
}

fn schedule(el: *EventLoop, fiber: *Fiber) void {
    el.queue.append(&fiber.queue_node);
}

fn myFiber(el: *EventLoop) *Fiber {
    _ = el;
    return current_fiber;
}

const Regs = extern struct {
    rsp: usize,
    r15: usize,
    r14: usize,
    r13: usize,
    r12: usize,
    rbx: usize,
    rbp: usize,
};

const contextSwitch: *const fn (old: *Regs, new: *Regs) callconv(.c) void = @ptrCast(&contextSwitch_naked);

noinline fn contextSwitch_naked() callconv(.naked) void {
    asm volatile (
        \\movq %%rsp, 0x00(%%rdi)
        \\movq %%r15, 0x08(%%rdi)
        \\movq %%r14, 0x10(%%rdi)
        \\movq %%r13, 0x18(%%rdi)
        \\movq %%r12, 0x20(%%rdi)
        \\movq %%rbx, 0x28(%%rdi)
        \\movq %%rbp, 0x30(%%rdi)
        \\
        \\movq 0x00(%%rsi), %%rsp
        \\movq 0x08(%%rsi), %%r15
        \\movq 0x10(%%rsi), %%r14
        \\movq 0x18(%%rsi), %%r13
        \\movq 0x20(%%rsi), %%r12
        \\movq 0x28(%%rsi), %%rbx
        \\movq 0x30(%%rsi), %%rbp
        \\
        \\ret
    );
}

fn popRet() callconv(.naked) void {
    asm volatile (
        \\pop %%rdi
        \\ret
    );
}

pub fn @"async"(
    userdata: ?*anyopaque,
    eager_result: []u8,
    context: ?*anyopaque,
    start: *const fn (context: ?*anyopaque, result: *anyopaque) void,
) ?*std.Io.AnyFuture {
    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const fiber = event_loop.allocateFiber(eager_result.len) catch {
        start(context, eager_result.ptr);
        return null;
    };
    fiber.awaiter = null;
    fiber.queue_node = .{ .data = {} };

    const closure: *AsyncClosure = @ptrFromInt(std.mem.alignBackward(
        usize,
        @intFromPtr(fiber.stackEndPointer() - @sizeOf(AsyncClosure)),
        @alignOf(AsyncClosure),
    ));
    closure.* = .{
        .event_loop = event_loop,
        .context = context,
        .fiber = fiber,
        .start = start,
    };
    const stack_end_ptr: [*]align(16) usize = @alignCast(@ptrCast(closure));
    (stack_end_ptr - 1)[0] = 0;
    (stack_end_ptr - 2)[0] = @intFromPtr(&AsyncClosure.call);
    (stack_end_ptr - 3)[0] = @intFromPtr(closure);
    (stack_end_ptr - 4)[0] = @intFromPtr(&popRet);

    fiber.regs = .{
        .rsp = @intFromPtr(stack_end_ptr - 4),
        .r15 = 0,
        .r14 = 0,
        .r13 = 0,
        .r12 = 0,
        .rbx = 0,
        .rbp = 0,
    };

    event_loop.schedule(fiber);
    return @ptrCast(fiber);
}

const AsyncClosure = struct {
    _: void align(16) = {},
    event_loop: *EventLoop,
    context: ?*anyopaque,
    fiber: *EventLoop.Fiber,
    start: *const fn (context: ?*anyopaque, result: *anyopaque) void,

    fn call(closure: *AsyncClosure) callconv(.c) void {
        std.log.debug("wrap called in async", .{});
        closure.start(closure.context, closure.fiber.resultPointer());
        const awaiter = @atomicRmw(?*EventLoop.Fiber, &closure.fiber.awaiter, .Xchg, EventLoop.Fiber.finished, .seq_cst);
        closure.event_loop.exit(awaiter);
    }
};

pub fn @"await"(userdata: ?*anyopaque, any_future: *std.Io.AnyFuture, result: []u8) void {
    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const future_fiber: *EventLoop.Fiber = @alignCast(@ptrCast(any_future));
    const result_src = future_fiber.resultPointer()[0..result.len];
    const my_fiber = event_loop.myFiber();

    const prev = @atomicRmw(?*EventLoop.Fiber, &future_fiber.awaiter, .Xchg, my_fiber, .seq_cst);
    if (prev == EventLoop.Fiber.finished) {
        @memcpy(result, result_src);
        return;
    }
    event_loop.yield(prev);
    // Resumed when the value is available.
    std.log.debug("yield returned in await", .{});
    @memcpy(result, result_src);
}
