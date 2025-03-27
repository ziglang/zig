const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const EventLoop = @This();

gpa: Allocator,
mutex: std.Thread.Mutex,
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
        .mutex = .{},
        .queue = .{},
        .free = .{},
        .main_fiber_buffer = undefined,
    };
    current_fiber = @ptrCast(&el.main_fiber_buffer);
}

fn allocateFiber(el: *EventLoop, result_len: usize) error{OutOfMemory}!*Fiber {
    assert(result_len <= max_result_len);
    const free_node = free_node: {
        el.mutex.lock();
        defer el.mutex.unlock();
        break :free_node el.free.pop();
    } orelse {
        const n = std.mem.alignForward(
            usize,
            @sizeOf(Fiber) + max_result_len + min_stack_size,
            std.heap.page_size_max,
        );
        return @alignCast(@ptrCast(try el.gpa.alignedAlloc(u8, @alignOf(Fiber), n)));
    };
    return @fieldParentPtr("queue_node", free_node);
}

fn yield(el: *EventLoop, optional_fiber: ?*Fiber, register_awaiter: ?*?*Fiber) void {
    const message: SwitchMessage = .{
        .ready_fiber = optional_fiber orelse if (ready_node: {
            el.mutex.lock();
            defer el.mutex.unlock();
            break :ready_node el.queue.pop();
        }) |ready_node|
            @fieldParentPtr("queue_node", ready_node)
        else if (register_awaiter) |_|
            @panic("no other fiber to switch to in order to be able to register this fiber as an awaiter") // time to switch to an idle fiber?
        else
            return, // nothing to do
        .register_awaiter = register_awaiter,
    };
    std.log.debug("switching from {*} to {*}", .{ current_fiber, message.ready_fiber });
    SwitchMessage.handle(@ptrFromInt(contextSwitch(&current_fiber.regs, &message.ready_fiber.regs, @intFromPtr(&message))), el);
}

const SwitchMessage = struct {
    ready_fiber: *Fiber,
    register_awaiter: ?*?*Fiber,

    fn handle(message: *const SwitchMessage, el: *EventLoop) void {
        const prev_fiber = current_fiber;
        current_fiber = message.ready_fiber;
        if (message.register_awaiter) |awaiter| if (@atomicRmw(?*Fiber, awaiter, .Xchg, prev_fiber, .acq_rel) == Fiber.finished) el.schedule(prev_fiber);
    }
};

fn schedule(el: *EventLoop, fiber: *Fiber) void {
    el.mutex.lock();
    defer el.mutex.unlock();
    el.queue.append(&fiber.queue_node);
}

fn recycle(el: *EventLoop, fiber: *Fiber) void {
    std.log.debug("recyling {*}", .{fiber});
    fiber.awaiter = undefined;
    @memset(fiber.resultPointer()[0..max_result_len], undefined);
    el.mutex.lock();
    defer el.mutex.unlock();
    el.free.append(&fiber.queue_node);
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

const contextSwitch: *const fn (old: *Regs, new: *Regs, message: usize) callconv(.c) usize = @ptrCast(&contextSwitch_naked);

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
        \\movq %%rdx, %%rax
        \\ret
    );
}

fn popRet() callconv(.naked) void {
    asm volatile (
        \\pop %%rdi
        \\movq %%rax, %%rsi
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
    std.log.debug("allocated {*}", .{fiber});

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
    const stack_end: [*]align(16) usize = @alignCast(@ptrCast(closure));
    const stack_top = (stack_end - 4)[0..4];
    stack_top.* = .{
        @intFromPtr(&popRet),
        @intFromPtr(closure),
        @intFromPtr(&AsyncClosure.call),
        0,
    };
    fiber.regs = .{
        .rsp = @intFromPtr(stack_top),
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
    fiber: *Fiber,
    start: *const fn (context: ?*anyopaque, result: *anyopaque) void,

    fn call(closure: *AsyncClosure, message: *const SwitchMessage) callconv(.c) noreturn {
        message.handle(closure.event_loop);
        std.log.debug("{*} performing async", .{closure.fiber});
        closure.start(closure.context, closure.fiber.resultPointer());
        const awaiter = @atomicRmw(?*Fiber, &closure.fiber.awaiter, .Xchg, Fiber.finished, .acq_rel);
        closure.event_loop.yield(awaiter, null);
        unreachable; // switched to dead fiber
    }
};

pub fn @"await"(userdata: ?*anyopaque, any_future: *std.Io.AnyFuture, result: []u8) void {
    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const future_fiber: *Fiber = @alignCast(@ptrCast(any_future));
    const result_src = future_fiber.resultPointer()[0..result.len];
    if (@atomicLoad(?*Fiber, &future_fiber.awaiter, .acquire) != Fiber.finished) event_loop.yield(null, &future_fiber.awaiter);
    @memcpy(result, result_src);
    event_loop.recycle(future_fiber);
}
