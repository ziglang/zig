const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const EventLoop = @This();

gpa: Allocator,
mutex: std.Thread.Mutex,
cond: std.Thread.Condition,
queue: std.DoublyLinkedList(void),
free: std.DoublyLinkedList(void),
main_fiber_buffer: [@sizeOf(Fiber) + max_result_len]u8 align(@alignOf(Fiber)),
exiting: bool,
idle_count: usize,
threads: std.ArrayListUnmanaged(Thread),

threadlocal var current_thread: *Thread = undefined;
threadlocal var current_fiber: *Fiber = undefined;

const max_result_len = 64;
const min_stack_size = 4 * 1024 * 1024;

const Thread = struct {
    thread: std.Thread,
    idle_fiber: Fiber,
};

const Fiber = struct {
    context: Context,
    awaiter: ?*Fiber,
    queue_node: std.DoublyLinkedList(void).Node,

    const finished: ?*Fiber = @ptrFromInt(std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(Fiber)));

    fn allocatedSlice(f: *Fiber) []align(@alignOf(Fiber)) u8 {
        const base: [*]align(@alignOf(Fiber)) u8 = @ptrCast(f);
        return base[0..std.mem.alignForward(
            usize,
            @sizeOf(Fiber) + max_result_len + min_stack_size,
            std.heap.page_size_max,
        )];
    }

    fn resultSlice(f: *Fiber) []u8 {
        const base: [*]align(@alignOf(Fiber)) u8 = @ptrCast(f);
        return base[@sizeOf(Fiber)..][0..max_result_len];
    }

    fn stackEndPointer(f: *Fiber) [*]u8 {
        const allocated_slice = f.allocatedSlice();
        return allocated_slice[allocated_slice.len..].ptr;
    }
};

pub fn init(el: *EventLoop, gpa: Allocator) error{OutOfMemory}!void {
    el.* = .{
        .gpa = gpa,
        .mutex = .{},
        .cond = .{},
        .queue = .{},
        .free = .{},
        .main_fiber_buffer = undefined,
        .exiting = false,
        .idle_count = 0,
        .threads = try .initCapacity(gpa, @max(std.Thread.getCpuCount() catch 1, 1)),
    };
    current_thread = el.threads.addOneAssumeCapacity();
    current_fiber = @ptrCast(&el.main_fiber_buffer);
}

pub fn deinit(el: *EventLoop) void {
    {
        el.mutex.lock();
        defer el.mutex.unlock();
        assert(el.queue.len == 0); // pending async
        el.exiting = true;
    }
    el.cond.broadcast();
    while (el.free.pop()) |free_node| {
        const free_fiber: *Fiber = @fieldParentPtr("queue_node", free_node);
        el.gpa.free(free_fiber.allocatedSlice());
    }
    for (el.threads.items[1..]) |*thread| thread.thread.join();
    el.threads.deinit(el.gpa);
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
    const ready_fiber: *Fiber = optional_fiber orelse if (ready_node: {
        el.mutex.lock();
        defer el.mutex.unlock();
        break :ready_node el.queue.pop();
    }) |ready_node|
        @fieldParentPtr("queue_node", ready_node)
    else
        &current_thread.idle_fiber;
    const message: SwitchMessage = .{
        .prev_context = &current_fiber.context,
        .ready_context = &ready_fiber.context,
        .register_awaiter = register_awaiter,
    };
    std.log.debug("switching from {*} to {*}", .{
        @as(*Fiber, @fieldParentPtr("context", message.prev_context)),
        @as(*Fiber, @fieldParentPtr("context", message.ready_context)),
    });
    contextSwitch(&message).handle(el);
}

fn schedule(el: *EventLoop, fiber: *Fiber) void {
    signal: {
        el.mutex.lock();
        defer el.mutex.unlock();
        el.queue.append(&fiber.queue_node);
        if (el.idle_count > 0) break :signal;
        if (el.threads.items.len == el.threads.capacity) return;
        const thread = el.threads.addOneAssumeCapacity();
        thread.thread = std.Thread.spawn(.{
            .stack_size = min_stack_size,
            .allocator = el.gpa,
        }, threadEntry, .{ el, thread }) catch return;
    }
    el.cond.signal();
}

fn recycle(el: *EventLoop, fiber: *Fiber) void {
    std.log.debug("recyling {*}", .{fiber});
    fiber.awaiter = undefined;
    @memset(fiber.resultSlice(), undefined);
    el.mutex.lock();
    defer el.mutex.unlock();
    el.free.append(&fiber.queue_node);
}

fn threadEntry(el: *EventLoop, thread: *Thread) void {
    current_thread = thread;
    current_fiber = &thread.idle_fiber;
    while (true) {
        el.yield(null, null);
        el.mutex.lock();
        defer el.mutex.unlock();
        if (el.exiting) return;
        el.idle_count += 1;
        defer el.idle_count -= 1;
        el.cond.wait(&el.mutex);
    }
}

const SwitchMessage = extern struct {
    prev_context: *Context,
    ready_context: *Context,
    register_awaiter: ?*?*Fiber,

    fn handle(message: *const SwitchMessage, el: *EventLoop) void {
        const prev_fiber: *Fiber = @fieldParentPtr("context", message.prev_context);
        current_fiber = @fieldParentPtr("context", message.ready_context);
        if (message.register_awaiter) |awaiter| if (@atomicRmw(?*Fiber, awaiter, .Xchg, prev_fiber, .acq_rel) == Fiber.finished) el.schedule(prev_fiber);
    }
};

const Context = extern struct {
    rsp: usize,
    rbp: usize,
    rip: usize,
};

inline fn contextSwitch(message: *const SwitchMessage) *const SwitchMessage {
    return switch (builtin.cpu.arch) {
        .x86_64 => asm volatile (
            \\ movq 0(%%rsi), %%rax
            \\ movq 8(%%rsi), %%rcx
            \\ leaq 0f(%%rip), %%rdx
            \\ movq %%rsp, 0(%%rax)
            \\ movq %%rbp, 8(%%rax)
            \\ movq %%rdx, 16(%%rax)
            \\ movq 0(%%rcx), %%rsp
            \\ movq 8(%%rcx), %%rbp
            \\ jmpq *16(%%rcx)
            \\0:
            : [received_message] "={rsi}" (-> *const SwitchMessage),
            : [message_to_send] "{rsi}" (message),
            : "rax", "rcx", "rdx", "rbx", "rdi", //
            "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15", //
            "mm0", "mm1", "mm2", "mm3", "mm4", "mm5", "mm6", "mm7", //
            "zmm0", "zmm1", "zmm2", "zmm3", "zmm4", "zmm5", "zmm6", "zmm7", //
            "zmm8", "zmm9", "zmm10", "zmm11", "zmm12", "zmm13", "zmm14", "zmm15", //
            "zmm16", "zmm17", "zmm18", "zmm19", "zmm20", "zmm21", "zmm22", "zmm23", //
            "zmm24", "zmm25", "zmm26", "zmm27", "zmm28", "zmm29", "zmm30", "zmm31", //
            "fpsr", "fpcr", "mxcsr", "rflags", "dirflag", "memory"
        ),
        else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
    };
}

fn fiberEntry() callconv(.naked) void {
    switch (builtin.cpu.arch) {
        .x86_64 => asm volatile (
            \\ leaq 8(%%rsp), %%rdi
            \\ jmp %[AsyncClosure_call:P]
            :
            : [AsyncClosure_call] "X" (&AsyncClosure.call),
        ),
        else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
    }
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
    fiber.context = .{
        .rsp = @intFromPtr(stack_end - 1),
        .rbp = 0,
        .rip = @intFromPtr(&fiberEntry),
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
        closure.start(closure.context, closure.fiber.resultSlice().ptr);
        const awaiter = @atomicRmw(?*Fiber, &closure.fiber.awaiter, .Xchg, Fiber.finished, .acq_rel);
        closure.event_loop.yield(awaiter, null);
        unreachable; // switched to dead fiber
    }
};

pub fn @"await"(userdata: ?*anyopaque, any_future: *std.Io.AnyFuture, result: []u8) void {
    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const future_fiber: *Fiber = @alignCast(@ptrCast(any_future));
    const result_src = future_fiber.resultSlice()[0..result.len];
    if (@atomicLoad(?*Fiber, &future_fiber.awaiter, .acquire) != Fiber.finished) event_loop.yield(null, &future_fiber.awaiter);
    @memcpy(result, result_src);
    event_loop.recycle(future_fiber);
}
