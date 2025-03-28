const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const EventLoop = @This();
const Alignment = std.mem.Alignment;

gpa: Allocator,
mutex: std.Thread.Mutex,
cond: std.Thread.Condition,
queue: std.DoublyLinkedList(void),
free: std.DoublyLinkedList(void),
main_context: Context,
exit_awaiter: ?*Fiber,
idle_count: usize,
threads: std.ArrayListUnmanaged(Thread),

threadlocal var current_idle_context: *Context = undefined;
threadlocal var current_context: *Context = undefined;

/// Empirically saw 10KB being used by the self-hosted backend for logging.
const idle_stack_size = 32 * 1024;

const Thread = struct {
    thread: std.Thread,
    idle_context: Context,
};

const Fiber = struct {
    context: Context,
    awaiter: ?*Fiber,
    queue_node: std.DoublyLinkedList(void).Node,
    result_align: Alignment,

    const finished: ?*Fiber = @ptrFromInt(std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(Fiber)));

    const max_result_align: Alignment = .@"16";
    const max_result_size = max_result_align.forward(64);
    /// This includes any stack realignments that need to happen, and also the
    /// initial frame return address slot and argument frame, depending on target.
    const min_stack_size = 4 * 1024 * 1024;
    const max_context_align: Alignment = .@"16";
    const max_context_size = max_context_align.forward(1024);
    const allocation_size = std.mem.alignForward(
        usize,
        std.mem.alignForward(
            usize,
            max_result_align.forward(@sizeOf(Fiber)) + max_result_size + min_stack_size,
            @max(@alignOf(AsyncClosure), max_context_align.toByteUnits()),
        ) + @sizeOf(AsyncClosure) + max_context_size,
        std.heap.page_size_max,
    );

    fn allocate(el: *EventLoop) error{OutOfMemory}!*Fiber {
        return if (free_node: {
            el.mutex.lock();
            defer el.mutex.unlock();
            break :free_node el.free.pop();
        }) |free_node|
            @alignCast(@fieldParentPtr("queue_node", free_node))
        else
            @ptrCast(try el.gpa.alignedAlloc(u8, @alignOf(Fiber), allocation_size));
    }

    fn allocatedSlice(f: *Fiber) []align(@alignOf(Fiber)) u8 {
        return @as([*]align(@alignOf(Fiber)) u8, @ptrCast(f))[0..allocation_size];
    }

    fn allocatedEnd(f: *Fiber) [*]u8 {
        const allocated_slice = f.allocatedSlice();
        return allocated_slice[allocated_slice.len..].ptr;
    }

    fn resultPointer(f: *Fiber) [*]u8 {
        return @ptrFromInt(f.result_align.forward(@intFromPtr(f) + @sizeOf(Fiber)));
    }
};

pub fn io(el: *EventLoop) Io {
    return .{
        .userdata = el,
        .vtable = &.{
            .@"async" = @"async",
            .@"await" = @"await",
        },
    };
}

pub fn init(el: *EventLoop, gpa: Allocator) error{OutOfMemory}!void {
    const threads_bytes = ((std.Thread.getCpuCount() catch 1) -| 1) * @sizeOf(Thread);
    const idle_context_offset = std.mem.alignForward(usize, threads_bytes, @alignOf(Context));
    const idle_stack_end_offset = std.mem.alignForward(usize, idle_context_offset + idle_stack_size, std.heap.page_size_max);
    const allocated_slice = try gpa.alignedAlloc(u8, @max(@alignOf(Thread), @alignOf(Context)), idle_stack_end_offset);
    errdefer gpa.free(allocated_slice);
    el.* = .{
        .gpa = gpa,
        .mutex = .{},
        .cond = .{},
        .queue = .{},
        .free = .{},
        .main_context = undefined,
        .exit_awaiter = null,
        .idle_count = 0,
        .threads = .initBuffer(@ptrCast(allocated_slice[0..threads_bytes])),
    };
    const main_idle_context: *Context = @alignCast(std.mem.bytesAsValue(Context, allocated_slice[idle_context_offset..][0..@sizeOf(Context)]));
    const idle_stack_end: [*]align(@max(@alignOf(Thread), @alignOf(Context))) usize = @alignCast(@ptrCast(allocated_slice[idle_stack_end_offset..].ptr));
    (idle_stack_end - 1)[0..1].* = .{@intFromPtr(el)};
    main_idle_context.* = .{
        .rsp = @intFromPtr(idle_stack_end - 1),
        .rbp = 0,
        .rip = @intFromPtr(&mainIdleEntry),
    };
    std.log.debug("created main idle {*}", .{main_idle_context});
    current_idle_context = main_idle_context;
    std.log.debug("created main {*}", .{&el.main_context});
    current_context = &el.main_context;
}

pub fn deinit(el: *EventLoop) void {
    assert(el.queue.len == 0); // pending async
    el.yield(null, &el.exit_awaiter);
    while (el.free.pop()) |free_node| {
        const free_fiber: *Fiber = @alignCast(@fieldParentPtr("queue_node", free_node));
        el.gpa.free(free_fiber.allocatedSlice());
    }
    const idle_context_offset = std.mem.alignForward(usize, el.threads.items.len * @sizeOf(Thread), @alignOf(Context));
    const idle_stack_end = std.mem.alignForward(usize, idle_context_offset + idle_stack_size, std.heap.page_size_max);
    const allocated_ptr: [*]align(@max(@alignOf(Thread), @alignOf(Context))) u8 = @alignCast(@ptrCast(el.threads.items.ptr));
    for (el.threads.items) |*thread| thread.thread.join();
    el.gpa.free(allocated_ptr[0..idle_stack_end]);
}

fn yield(el: *EventLoop, optional_fiber: ?*Fiber, register_awaiter: ?*?*Fiber) void {
    const ready_context: *Context = ready_context: {
        const ready_fiber: *Fiber = optional_fiber orelse if (ready_node: {
            el.mutex.lock();
            defer el.mutex.unlock();
            break :ready_node el.queue.pop();
        }) |ready_node|
            @alignCast(@fieldParentPtr("queue_node", ready_node))
        else
            break :ready_context current_idle_context;
        break :ready_context &ready_fiber.context;
    };
    const message: SwitchMessage = .{
        .prev_context = current_context,
        .ready_context = ready_context,
        .register_awaiter = register_awaiter,
    };
    std.log.debug("switching from {*} to {*}", .{ message.prev_context, message.ready_context });
    contextSwitch(&message).handle(el);
}

fn schedule(el: *EventLoop, fiber: *Fiber) void {
    el.mutex.lock();
    el.queue.append(&fiber.queue_node);
    if (el.idle_count > 0) {
        el.mutex.unlock();
        el.cond.signal();
        return;
    }
    defer el.mutex.unlock();
    if (el.threads.items.len == el.threads.capacity) return;
    const thread = el.threads.addOneAssumeCapacity();
    thread.thread = std.Thread.spawn(.{
        .stack_size = idle_stack_size,
        .allocator = el.gpa,
    }, threadEntry, .{ el, thread }) catch {
        el.threads.items.len -= 1;
        return;
    };
}

fn recycle(el: *EventLoop, fiber: *Fiber) void {
    std.log.debug("recyling {*}", .{fiber});
    @memset(fiber.allocatedSlice(), undefined);
    el.mutex.lock();
    defer el.mutex.unlock();
    el.free.append(&fiber.queue_node);
}

fn mainIdle(el: *EventLoop, message: *const SwitchMessage) callconv(.withStackAlign(.c, @max(@alignOf(Thread), @alignOf(Context)))) noreturn {
    message.handle(el);
    el.yield(el.idle(), null);
    unreachable; // switched to dead fiber
}

fn threadEntry(el: *EventLoop, thread: *Thread) void {
    std.log.debug("created thread idle {*}", .{&thread.idle_context});
    current_idle_context = &thread.idle_context;
    current_context = &thread.idle_context;
    _ = el.idle();
}

fn idle(el: *EventLoop) *Fiber {
    while (true) {
        el.yield(null, null);
        if (@atomicLoad(?*Fiber, &el.exit_awaiter, .acquire)) |exit_awaiter| {
            el.cond.broadcast();
            return exit_awaiter;
        }
        el.mutex.lock();
        defer el.mutex.unlock();
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
        current_context = message.ready_context;
        if (message.register_awaiter) |awaiter| {
            const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.prev_context));
            if (@atomicRmw(?*Fiber, awaiter, .Xchg, prev_fiber, .acq_rel) == Fiber.finished) el.schedule(prev_fiber);
        }
    }
};

const Context = switch (builtin.cpu.arch) {
    .x86_64 => extern struct {
        rsp: u64,
        rbp: u64,
        rip: u64,
    },
    else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
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

fn mainIdleEntry() callconv(.naked) void {
    switch (builtin.cpu.arch) {
        .x86_64 => asm volatile (
            \\ movq (%%rsp), %%rdi
            \\ jmp %[mainIdle:P]
            :
            : [mainIdle] "X" (&mainIdle),
        ),
        else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
    }
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
    result: []u8,
    result_alignment: Alignment,
    context: []const u8,
    context_alignment: Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*std.Io.AnyFuture {
    assert(result_alignment.compare(.lte, Fiber.max_result_align)); // TODO
    assert(context_alignment.compare(.lte, Fiber.max_context_align)); // TODO
    assert(result.len <= Fiber.max_result_size); // TODO
    assert(context.len <= Fiber.max_context_size); // TODO

    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const fiber = Fiber.allocate(event_loop) catch {
        start(context.ptr, result.ptr);
        return null;
    };
    std.log.debug("allocated {*}", .{fiber});

    const closure: *AsyncClosure = @ptrFromInt(Fiber.max_context_align.max(.of(AsyncClosure)).backward(
        @intFromPtr(fiber.allocatedEnd()) - Fiber.max_context_size,
    ) - @sizeOf(AsyncClosure));
    fiber.* = .{
        .context = switch (builtin.cpu.arch) {
            .x86_64 => .{
                .rsp = @intFromPtr(closure) - @sizeOf(usize),
                .rbp = 0,
                .rip = @intFromPtr(&fiberEntry),
            },
            else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
        },
        .awaiter = null,
        .queue_node = undefined,
        .result_align = result_alignment,
    };
    closure.* = .{
        .event_loop = event_loop,
        .fiber = fiber,
        .start = start,
    };
    @memcpy(closure.contextPointer(), context);

    event_loop.schedule(fiber);
    return @ptrCast(fiber);
}

const AsyncClosure = struct {
    event_loop: *EventLoop,
    fiber: *Fiber,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,

    fn contextPointer(closure: *AsyncClosure) [*]align(Fiber.max_context_align.toByteUnits()) u8 {
        return @alignCast(@as([*]u8, @ptrCast(closure)) + @sizeOf(AsyncClosure));
    }

    fn call(closure: *AsyncClosure, message: *const SwitchMessage) callconv(.withStackAlign(.c, @alignOf(AsyncClosure))) noreturn {
        message.handle(closure.event_loop);
        std.log.debug("{*} performing async", .{closure.fiber});
        closure.start(closure.contextPointer(), closure.fiber.resultPointer());
        const awaiter = @atomicRmw(?*Fiber, &closure.fiber.awaiter, .Xchg, Fiber.finished, .acq_rel);
        closure.event_loop.yield(awaiter, null);
        unreachable; // switched to dead fiber
    }
};

pub fn @"await"(userdata: ?*anyopaque, any_future: *std.Io.AnyFuture, result: []u8) void {
    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const future_fiber: *Fiber = @alignCast(@ptrCast(any_future));
    if (@atomicLoad(?*Fiber, &future_fiber.awaiter, .acquire) != Fiber.finished) event_loop.yield(null, &future_fiber.awaiter);
    @memcpy(result, future_fiber.resultPointer());
    event_loop.recycle(future_fiber);
}
