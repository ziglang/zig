const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const EventLoop = @This();
const Alignment = std.mem.Alignment;
const IoUring = std.os.linux.IoUring;

/// Must be a thread-safe allocator.
gpa: Allocator,
main_fiber_buffer: [@sizeOf(Fiber) + Fiber.max_result_size]u8 align(@alignOf(Fiber)),
threads: Thread.List,
detached: struct {
    mutex: std.Io.Mutex,
    list: std.DoublyLinkedList(void),
},

/// Empirically saw >128KB being used by the self-hosted backend to panic.
const idle_stack_size = 256 * 1024;

const max_idle_search = 4;
const max_steal_ready_search = 4;

const io_uring_entries = 64;

const Thread = struct {
    thread: std.Thread,
    idle_context: Context,
    current_context: *Context,
    ready_queue: ?*Fiber,
    io_uring: IoUring,
    idle_search_index: u32,
    steal_ready_search_index: u32,

    const canceling: ?*Thread = @ptrFromInt(@alignOf(Thread));

    threadlocal var self: *Thread = undefined;

    fn current() *Thread {
        return self;
    }

    fn currentFiber(thread: *Thread) *Fiber {
        return @fieldParentPtr("context", thread.current_context);
    }

    const List = struct {
        allocated: []Thread,
        reserved: u32,
        active: u32,
    };
};

const Fiber = struct {
    required_align: void align(4),
    context: Context,
    awaiter: ?*Fiber,
    queue_next: ?*Fiber,
    cancel_thread: ?*Thread,
    awaiting_completions: std.StaticBitSet(3),

    const finished: ?*Fiber = @ptrFromInt(@alignOf(Thread));

    const max_result_align: Alignment = .@"16";
    const max_result_size = max_result_align.forward(64);
    /// This includes any stack realignments that need to happen, and also the
    /// initial frame return address slot and argument frame, depending on target.
    const min_stack_size = 4 * 1024 * 1024;
    const max_context_align: Alignment = .@"16";
    const max_context_size = max_context_align.forward(1024);
    const max_closure_size: usize = @max(@sizeOf(AsyncClosure), @sizeOf(DetachedClosure));
    const max_closure_align: Alignment = .max(.of(AsyncClosure), .of(DetachedClosure));
    const allocation_size = std.mem.alignForward(
        usize,
        max_closure_align.max(max_context_align).forward(
            max_result_align.forward(@sizeOf(Fiber)) + max_result_size + min_stack_size,
        ) + max_closure_size + max_context_size,
        std.heap.page_size_max,
    );

    fn allocate(el: *EventLoop) error{OutOfMemory}!*Fiber {
        return @ptrCast(try el.gpa.alignedAlloc(u8, @alignOf(Fiber), allocation_size));
    }

    fn allocatedSlice(f: *Fiber) []align(@alignOf(Fiber)) u8 {
        return @as([*]align(@alignOf(Fiber)) u8, @ptrCast(f))[0..allocation_size];
    }

    fn allocatedEnd(f: *Fiber) [*]u8 {
        const allocated_slice = f.allocatedSlice();
        return allocated_slice[allocated_slice.len..].ptr;
    }

    fn resultPointer(f: *Fiber, comptime Result: type) *Result {
        return @alignCast(@ptrCast(f.resultBytes(.of(Result))));
    }

    fn resultBytes(f: *Fiber, alignment: Alignment) [*]u8 {
        return @ptrFromInt(alignment.forward(@intFromPtr(f) + @sizeOf(Fiber)));
    }

    fn enterCancelRegion(fiber: *Fiber, thread: *Thread) error{Canceled}!void {
        if (@cmpxchgStrong(
            ?*Thread,
            &fiber.cancel_thread,
            null,
            thread,
            .acq_rel,
            .acquire,
        )) |cancel_thread| {
            assert(cancel_thread == Thread.canceling);
            return error.Canceled;
        }
    }

    fn exitCancelRegion(fiber: *Fiber, thread: *Thread) void {
        if (@cmpxchgStrong(
            ?*Thread,
            &fiber.cancel_thread,
            thread,
            null,
            .acq_rel,
            .acquire,
        )) |cancel_thread| assert(cancel_thread == Thread.canceling);
    }

    const Queue = struct { head: *Fiber, tail: *Fiber };
};

fn recycle(el: *EventLoop, fiber: *Fiber) void {
    std.log.debug("recyling {*}", .{fiber});
    assert(fiber.queue_next == null);
    el.gpa.free(fiber.allocatedSlice());
}

pub fn io(el: *EventLoop) Io {
    return .{
        .userdata = el,
        .vtable = &.{
            .@"async" = @"async",
            .@"await" = @"await",
            .go = go,
            .select = select,
            .cancel = cancel,
            .cancelRequested = cancelRequested,

            .mutexLock = mutexLock,
            .mutexUnlock = mutexUnlock,

            .conditionWait = conditionWait,
            .conditionWake = conditionWake,

            .createFile = createFile,
            .openFile = openFile,
            .closeFile = closeFile,
            .pread = pread,
            .pwrite = pwrite,

            .now = now,
            .sleep = sleep,
        },
    };
}

pub fn init(el: *EventLoop, gpa: Allocator) !void {
    const threads_size = @max(std.Thread.getCpuCount() catch 1, 1) * @sizeOf(Thread);
    const idle_stack_end_offset = std.mem.alignForward(usize, threads_size + idle_stack_size, std.heap.page_size_max);
    const allocated_slice = try gpa.alignedAlloc(u8, @alignOf(Thread), idle_stack_end_offset);
    errdefer gpa.free(allocated_slice);
    el.* = .{
        .gpa = gpa,
        .main_fiber_buffer = undefined,
        .threads = .{
            .allocated = @ptrCast(allocated_slice[0..threads_size]),
            .reserved = 1,
            .active = 1,
        },
        .detached = .{
            .mutex = .init,
            .list = .{},
        },
    };
    const main_fiber: *Fiber = @ptrCast(&el.main_fiber_buffer);
    main_fiber.* = .{
        .required_align = {},
        .context = undefined,
        .awaiter = null,
        .queue_next = null,
        .cancel_thread = null,
        .awaiting_completions = .initEmpty(),
    };
    const main_thread = &el.threads.allocated[0];
    Thread.self = main_thread;
    const idle_stack_end: [*]usize = @alignCast(@ptrCast(allocated_slice[idle_stack_end_offset..].ptr));
    (idle_stack_end - 1)[0..1].* = .{@intFromPtr(el)};
    main_thread.* = .{
        .thread = undefined,
        .idle_context = .{
            .rsp = @intFromPtr(idle_stack_end - 1),
            .rbp = 0,
            .rip = @intFromPtr(&mainIdleEntry),
        },
        .current_context = &main_fiber.context,
        .ready_queue = null,
        .io_uring = try IoUring.init(io_uring_entries, 0),
        .idle_search_index = 1,
        .steal_ready_search_index = 1,
    };
    errdefer main_thread.io_uring.deinit();
    std.log.debug("created main idle {*}", .{&main_thread.idle_context});
    std.log.debug("created main {*}", .{main_fiber});
}

pub fn deinit(el: *EventLoop) void {
    while (true) cancel(el, detached_future: {
        el.detached.mutex.lock(el.io()) catch |err| switch (err) {
            error.Canceled => unreachable, // main fiber cannot be canceled
        };
        defer el.detached.mutex.unlock(el.io());
        const detached: *DetachedClosure = @fieldParentPtr(
            "detached_queue_node",
            el.detached.list.pop() orelse break,
        );
        // notify the detached fiber that it is no longer allowed to recycle itself
        detached.detached_queue_node = .{
            .prev = &detached.detached_queue_node,
            .next = &detached.detached_queue_node,
            .data = {},
        };
        break :detached_future @ptrCast(detached.fiber);
    }, &.{}, .@"1");
    const active_threads = @atomicLoad(u32, &el.threads.active, .acquire);
    for (el.threads.allocated[0..active_threads]) |*thread| {
        const ready_fiber = @atomicLoad(?*Fiber, &thread.ready_queue, .monotonic);
        assert(ready_fiber == null or ready_fiber == Fiber.finished); // pending async
    }
    el.yield(null, .exit);
    const allocated_ptr: [*]align(@alignOf(Thread)) u8 = @alignCast(@ptrCast(el.threads.allocated.ptr));
    const idle_stack_end_offset = std.mem.alignForward(usize, el.threads.allocated.len * @sizeOf(Thread) + idle_stack_size, std.heap.page_size_max);
    for (el.threads.allocated[1..active_threads]) |*thread| thread.thread.join();
    el.gpa.free(allocated_ptr[0..idle_stack_end_offset]);
    el.* = undefined;
}

fn findReadyFiber(el: *EventLoop, thread: *Thread) ?*Fiber {
    if (@atomicRmw(?*Fiber, &thread.ready_queue, .Xchg, Fiber.finished, .acquire)) |ready_fiber| {
        @atomicStore(?*Fiber, &thread.ready_queue, ready_fiber.queue_next, .release);
        ready_fiber.queue_next = null;
        return ready_fiber;
    }
    const active_threads = @atomicLoad(u32, &el.threads.active, .acquire);
    for (0..@min(max_steal_ready_search, active_threads)) |_| {
        defer thread.steal_ready_search_index += 1;
        if (thread.steal_ready_search_index == active_threads) thread.steal_ready_search_index = 0;
        const steal_ready_search_thread = &el.threads.allocated[0..active_threads][thread.steal_ready_search_index];
        if (steal_ready_search_thread == thread) continue;
        const ready_fiber = @atomicLoad(?*Fiber, &steal_ready_search_thread.ready_queue, .acquire) orelse continue;
        if (ready_fiber == Fiber.finished) continue;
        if (@cmpxchgWeak(
            ?*Fiber,
            &steal_ready_search_thread.ready_queue,
            ready_fiber,
            null,
            .acquire,
            .monotonic,
        )) |_| continue;
        @atomicStore(?*Fiber, &thread.ready_queue, ready_fiber.queue_next, .release);
        ready_fiber.queue_next = null;
        return ready_fiber;
    }
    // couldn't find anything to do, so we are now open for business
    @atomicStore(?*Fiber, &thread.ready_queue, null, .monotonic);
    return null;
}

fn yield(el: *EventLoop, maybe_ready_fiber: ?*Fiber, pending_task: SwitchMessage.PendingTask) void {
    const thread: *Thread = .current();
    const ready_context = if (maybe_ready_fiber orelse el.findReadyFiber(thread)) |ready_fiber|
        &ready_fiber.context
    else
        &thread.idle_context;
    const message: SwitchMessage = .{
        .contexts = .{
            .prev = thread.current_context,
            .ready = ready_context,
        },
        .pending_task = pending_task,
    };
    std.log.debug("switching from {*} to {*}", .{ message.contexts.prev, message.contexts.ready });
    contextSwitch(&message).handle(el);
}

fn schedule(el: *EventLoop, thread: *Thread, ready_queue: Fiber.Queue) void {
    {
        var fiber = ready_queue.head;
        while (true) {
            std.log.debug("scheduling {*}", .{fiber});
            fiber = fiber.queue_next orelse break;
        }
        assert(fiber == ready_queue.tail);
    }
    // shared fields of previous `Thread` must be initialized before later ones are marked as active
    const new_thread_index = @atomicLoad(u32, &el.threads.active, .acquire);
    for (0..@min(max_idle_search, new_thread_index)) |_| {
        defer thread.idle_search_index += 1;
        if (thread.idle_search_index == new_thread_index) thread.idle_search_index = 0;
        const idle_search_thread = &el.threads.allocated[0..new_thread_index][thread.idle_search_index];
        if (idle_search_thread == thread) continue;
        if (@cmpxchgWeak(
            ?*Fiber,
            &idle_search_thread.ready_queue,
            null,
            ready_queue.head,
            .release,
            .monotonic,
        )) |_| continue;
        getSqe(&thread.io_uring).* = .{
            .opcode = .MSG_RING,
            .flags = std.os.linux.IOSQE_CQE_SKIP_SUCCESS,
            .ioprio = 0,
            .fd = idle_search_thread.io_uring.fd,
            .off = @intFromEnum(Completion.UserData.wakeup),
            .addr = 0,
            .len = 0,
            .rw_flags = 0,
            .user_data = @intFromEnum(Completion.UserData.wakeup),
            .buf_index = 0,
            .personality = 0,
            .splice_fd_in = 0,
            .addr3 = 0,
            .resv = 0,
        };
        return;
    }
    spawn_thread: {
        // previous failed reservations must have completed before retrying
        if (new_thread_index == el.threads.allocated.len or @cmpxchgWeak(
            u32,
            &el.threads.reserved,
            new_thread_index,
            new_thread_index + 1,
            .acquire,
            .monotonic,
        ) != null) break :spawn_thread;
        const new_thread = &el.threads.allocated[new_thread_index];
        const next_thread_index = new_thread_index + 1;
        new_thread.* = .{
            .thread = undefined,
            .idle_context = undefined,
            .current_context = &new_thread.idle_context,
            .ready_queue = ready_queue.head,
            .io_uring = IoUring.init(io_uring_entries, 0) catch |err| {
                @atomicStore(u32, &el.threads.reserved, new_thread_index, .release);
                // no more access to `thread` after giving up reservation
                std.log.warn("unable to create worker thread due to io_uring init failure: {s}", .{@errorName(err)});
                break :spawn_thread;
            },
            .idle_search_index = 0,
            .steal_ready_search_index = 0,
        };
        new_thread.thread = std.Thread.spawn(.{
            .stack_size = idle_stack_size,
            .allocator = el.gpa,
        }, threadEntry, .{ el, new_thread_index }) catch |err| {
            new_thread.io_uring.deinit();
            @atomicStore(u32, &el.threads.reserved, new_thread_index, .release);
            // no more access to `thread` after giving up reservation
            std.log.warn("unable to create worker thread due spawn failure: {s}", .{@errorName(err)});
            break :spawn_thread;
        };
        // shared fields of `Thread` must be initialized before being marked active
        @atomicStore(u32, &el.threads.active, next_thread_index, .release);
        return;
    }
    // nobody wanted it, so just queue it on ourselves
    while (@cmpxchgWeak(
        ?*Fiber,
        &thread.ready_queue,
        ready_queue.tail.queue_next,
        ready_queue.head,
        .acq_rel,
        .acquire,
    )) |old_head| ready_queue.tail.queue_next = old_head;
}

fn mainIdle(el: *EventLoop, message: *const SwitchMessage) callconv(.withStackAlign(.c, @max(@alignOf(Thread), @alignOf(Context)))) noreturn {
    message.handle(el);
    el.idle(&el.threads.allocated[0]);
    el.yield(@ptrCast(&el.main_fiber_buffer), .nothing);
    unreachable; // switched to dead fiber
}

fn threadEntry(el: *EventLoop, index: u32) void {
    const thread: *Thread = &el.threads.allocated[index];
    Thread.self = thread;
    std.log.debug("created thread idle {*}", .{&thread.idle_context});
    el.idle(thread);
}

const Completion = struct {
    const UserData = enum(usize) {
        unused,
        wakeup,
        cleanup,
        exit,
        /// *Fiber
        _,
    };
    result: i32,
    flags: u32,
};

fn idle(el: *EventLoop, thread: *Thread) void {
    var maybe_ready_fiber: ?*Fiber = null;
    while (true) {
        while (maybe_ready_fiber orelse el.findReadyFiber(thread)) |ready_fiber| {
            el.yield(ready_fiber, .nothing);
            maybe_ready_fiber = null;
        }
        _ = thread.io_uring.submit_and_wait(1) catch |err| switch (err) {
            error.SignalInterrupt => std.log.warn("submit_and_wait failed with SignalInterrupt", .{}),
            else => |e| @panic(@errorName(e)),
        };
        var cqes_buffer: [io_uring_entries]std.os.linux.io_uring_cqe = undefined;
        var maybe_ready_queue: ?Fiber.Queue = null;
        for (cqes_buffer[0 .. thread.io_uring.copy_cqes(&cqes_buffer, 0) catch |err| switch (err) {
            error.SignalInterrupt => cqes_len: {
                std.log.warn("copy_cqes failed with SignalInterrupt", .{});
                break :cqes_len 0;
            },
            else => |e| @panic(@errorName(e)),
        }]) |cqe| switch (@as(Completion.UserData, @enumFromInt(cqe.user_data))) {
            .unused => unreachable, // bad submission queued?
            .wakeup => {},
            .cleanup => @panic("failed to notify other threads that we are exiting"),
            .exit => {
                assert(maybe_ready_fiber == null and maybe_ready_queue == null); // pending async
                return;
            },
            _ => switch (errno(cqe.res)) {
                .INTR => getSqe(&thread.io_uring).* = .{
                    .opcode = .ASYNC_CANCEL,
                    .flags = std.os.linux.IOSQE_CQE_SKIP_SUCCESS,
                    .ioprio = 0,
                    .fd = 0,
                    .off = 0,
                    .addr = cqe.user_data,
                    .len = 0,
                    .rw_flags = 0,
                    .user_data = @intFromEnum(Completion.UserData.wakeup),
                    .buf_index = 0,
                    .personality = 0,
                    .splice_fd_in = 0,
                    .addr3 = 0,
                    .resv = 0,
                },
                else => {
                    const fiber: *Fiber = @ptrFromInt(cqe.user_data);
                    assert(fiber.queue_next == null);
                    fiber.resultPointer(Completion).* = .{
                        .result = cqe.res,
                        .flags = cqe.flags,
                    };
                    if (maybe_ready_fiber == null) maybe_ready_fiber = fiber else if (maybe_ready_queue) |*ready_queue| {
                        ready_queue.tail.queue_next = fiber;
                        ready_queue.tail = fiber;
                    } else maybe_ready_queue = .{ .head = fiber, .tail = fiber };
                },
            },
        };
        if (maybe_ready_queue) |ready_queue| el.schedule(thread, ready_queue);
    }
}

const SwitchMessage = struct {
    contexts: extern struct {
        prev: *Context,
        ready: *Context,
    },
    pending_task: PendingTask,

    const PendingTask = union(enum) {
        nothing,
        reschedule,
        recycle,
        register_awaiter: *?*Fiber,
        mutex_lock: struct {
            prev_state: Io.Mutex.State,
            mutex: *Io.Mutex,
        },
        condition_wait: struct {
            cond: *Io.Condition,
            mutex: *Io.Mutex,
        },
        exit,
    };

    fn handle(message: *const SwitchMessage, el: *EventLoop) void {
        const thread: *Thread = .current();
        thread.current_context = message.contexts.ready;
        switch (message.pending_task) {
            .nothing => {},
            .reschedule => if (message.contexts.prev != &thread.idle_context) {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                el.schedule(thread, .{ .head = prev_fiber, .tail = prev_fiber });
            },
            .recycle => {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                el.recycle(prev_fiber);
            },
            .register_awaiter => |awaiter| {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                if (@atomicRmw(
                    ?*Fiber,
                    awaiter,
                    .Xchg,
                    prev_fiber,
                    .acq_rel,
                ) == Fiber.finished) el.schedule(thread, .{ .head = prev_fiber, .tail = prev_fiber });
            },
            .mutex_lock => |mutex_lock| {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                var prev_state = mutex_lock.prev_state;
                while (switch (prev_state) {
                    else => next_state: {
                        prev_fiber.queue_next = @ptrFromInt(@intFromEnum(prev_state));
                        break :next_state @cmpxchgWeak(
                            Io.Mutex.State,
                            &mutex_lock.mutex.state,
                            prev_state,
                            @enumFromInt(@intFromPtr(prev_fiber)),
                            .release,
                            .acquire,
                        );
                    },
                    .unlocked => @cmpxchgWeak(
                        Io.Mutex.State,
                        &mutex_lock.mutex.state,
                        .unlocked,
                        .locked_once,
                        .acquire,
                        .acquire,
                    ) orelse {
                        prev_fiber.queue_next = null;
                        el.schedule(thread, .{ .head = prev_fiber, .tail = prev_fiber });
                        return;
                    },
                }) |next_state| prev_state = next_state;
            },
            .condition_wait => |condition_wait| {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                const cond_impl = prev_fiber.resultPointer(ConditionImpl);
                cond_impl.* = .{
                    .tail = prev_fiber,
                    .event = .queued,
                };
                if (@cmpxchgStrong(
                    ?*Fiber,
                    @as(*?*Fiber, @ptrCast(&condition_wait.cond.state)),
                    null,
                    prev_fiber,
                    .release,
                    .acquire,
                )) |waiting_fiber| {
                    const waiting_cond_impl = waiting_fiber.?.resultPointer(ConditionImpl);
                    assert(waiting_cond_impl.tail.queue_next == null);
                    waiting_cond_impl.tail.queue_next = prev_fiber;
                    waiting_cond_impl.tail = prev_fiber;
                }
                condition_wait.mutex.unlock(el.io());
            },
            .exit => for (el.threads.allocated[0..@atomicLoad(u32, &el.threads.active, .acquire)]) |*each_thread| {
                getSqe(&thread.io_uring).* = .{
                    .opcode = .MSG_RING,
                    .flags = std.os.linux.IOSQE_CQE_SKIP_SUCCESS,
                    .ioprio = 0,
                    .fd = each_thread.io_uring.fd,
                    .off = @intFromEnum(Completion.UserData.exit),
                    .addr = 0,
                    .len = 0,
                    .rw_flags = 0,
                    .user_data = @intFromEnum(Completion.UserData.cleanup),
                    .buf_index = 0,
                    .personality = 0,
                    .splice_fd_in = 0,
                    .addr3 = 0,
                    .resv = 0,
                };
            },
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
    return @fieldParentPtr("contexts", switch (builtin.cpu.arch) {
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
            : [received_message] "={rsi}" (-> *const @FieldType(SwitchMessage, "contexts")),
            : [message_to_send] "{rsi}" (&message.contexts),
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
    });
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
            \\ jmpq *(%%rsp)
        ),
        else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
    }
}

const AsyncClosure = struct {
    event_loop: *EventLoop,
    fiber: *Fiber,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
    result_align: Alignment,

    fn contextPointer(closure: *AsyncClosure) [*]align(Fiber.max_context_align.toByteUnits()) u8 {
        return @alignCast(@as([*]u8, @ptrCast(closure)) + @sizeOf(AsyncClosure));
    }

    fn call(closure: *AsyncClosure, message: *const SwitchMessage) callconv(.withStackAlign(.c, @alignOf(AsyncClosure))) noreturn {
        message.handle(closure.event_loop);
        std.log.debug("{*} performing async", .{closure.fiber});
        closure.start(closure.contextPointer(), closure.fiber.resultBytes(closure.result_align));
        const awaiter = @atomicRmw(?*Fiber, &closure.fiber.awaiter, .Xchg, Fiber.finished, .acq_rel);
        closure.event_loop.yield(awaiter, .nothing);
        unreachable; // switched to dead fiber
    }
};

fn @"async"(
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
    const stack_end: [*]usize = @alignCast(@ptrCast(closure));
    (stack_end - 1)[0..1].* = .{@intFromPtr(&AsyncClosure.call)};
    fiber.* = .{
        .required_align = {},
        .context = switch (builtin.cpu.arch) {
            .x86_64 => .{
                .rsp = @intFromPtr(stack_end - 1),
                .rbp = 0,
                .rip = @intFromPtr(&fiberEntry),
            },
            else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
        },
        .awaiter = null,
        .queue_next = null,
        .cancel_thread = null,
        .awaiting_completions = .initEmpty(),
    };
    closure.* = .{
        .event_loop = event_loop,
        .fiber = fiber,
        .start = start,
        .result_align = result_alignment,
    };
    @memcpy(closure.contextPointer(), context);

    event_loop.schedule(.current(), .{ .head = fiber, .tail = fiber });
    return @ptrCast(fiber);
}

fn select(userdata: ?*anyopaque, futures: []const *Io.AnyFuture) usize {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    _ = el;
    _ = futures;
    @panic("TODO");
}

const DetachedClosure = struct {
    event_loop: *EventLoop,
    fiber: *Fiber,
    start: *const fn (context: *const anyopaque) void,
    detached_queue_node: std.DoublyLinkedList(void).Node,

    fn contextPointer(closure: *DetachedClosure) [*]align(Fiber.max_context_align.toByteUnits()) u8 {
        return @alignCast(@as([*]u8, @ptrCast(closure)) + @sizeOf(DetachedClosure));
    }

    fn call(closure: *DetachedClosure, message: *const SwitchMessage) callconv(.withStackAlign(.c, @alignOf(DetachedClosure))) noreturn {
        message.handle(closure.event_loop);
        std.log.debug("{*} performing async detached", .{closure.fiber});
        closure.start(closure.contextPointer());
        const awaiter = @atomicRmw(?*Fiber, &closure.fiber.awaiter, .Xchg, Fiber.finished, .acq_rel);
        closure.event_loop.yield(awaiter, pending_task: {
            closure.event_loop.detached.mutex.lock(closure.event_loop.io()) catch |err| switch (err) {
                error.Canceled => break :pending_task .nothing,
            };
            defer closure.event_loop.detached.mutex.unlock(closure.event_loop.io());
            if (closure.detached_queue_node.next == &closure.detached_queue_node) break :pending_task .nothing;
            closure.event_loop.detached.list.remove(&closure.detached_queue_node);
            break :pending_task .recycle;
        });
        unreachable; // switched to dead fiber
    }
};

fn go(
    userdata: ?*anyopaque,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque) void,
) void {
    assert(context_alignment.compare(.lte, Fiber.max_context_align)); // TODO
    assert(context.len <= Fiber.max_context_size); // TODO

    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const fiber = Fiber.allocate(event_loop) catch {
        start(context.ptr);
        return;
    };
    std.log.debug("allocated {*}", .{fiber});

    const current_thread: *Thread = .current();
    const closure: *DetachedClosure = @ptrFromInt(Fiber.max_context_align.max(.of(DetachedClosure)).backward(
        @intFromPtr(fiber.allocatedEnd()) - Fiber.max_context_size,
    ) - @sizeOf(DetachedClosure));
    const stack_end: [*]usize = @alignCast(@ptrCast(closure));
    (stack_end - 1)[0..1].* = .{@intFromPtr(&DetachedClosure.call)};
    fiber.* = .{
        .required_align = {},
        .context = switch (builtin.cpu.arch) {
            .x86_64 => .{
                .rsp = @intFromPtr(stack_end - 1),
                .rbp = 0,
                .rip = @intFromPtr(&fiberEntry),
            },
            else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
        },
        .awaiter = null,
        .queue_next = null,
        .cancel_thread = null,
        .awaiting_completions = .initEmpty(),
    };
    closure.* = .{
        .event_loop = event_loop,
        .fiber = fiber,
        .start = start,
        .detached_queue_node = .{ .data = {} },
    };
    {
        event_loop.detached.mutex.lock(event_loop.io()) catch |err| switch (err) {
            error.Canceled => {
                event_loop.recycle(fiber);
                start(context.ptr);
                return;
            },
        };
        defer event_loop.detached.mutex.unlock(event_loop.io());
        event_loop.detached.list.append(&closure.detached_queue_node);
    }
    @memcpy(closure.contextPointer(), context);

    event_loop.schedule(current_thread, .{ .head = fiber, .tail = fiber });
}

fn @"await"(
    userdata: ?*anyopaque,
    any_future: *std.Io.AnyFuture,
    result: []u8,
    result_alignment: Alignment,
) void {
    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const future_fiber: *Fiber = @alignCast(@ptrCast(any_future));
    if (@atomicLoad(?*Fiber, &future_fiber.awaiter, .acquire) != Fiber.finished)
        event_loop.yield(null, .{ .register_awaiter = &future_fiber.awaiter });
    @memcpy(result, future_fiber.resultBytes(result_alignment));
    event_loop.recycle(future_fiber);
}

fn cancel(
    userdata: ?*anyopaque,
    any_future: *std.Io.AnyFuture,
    result: []u8,
    result_alignment: Alignment,
) void {
    const future_fiber: *Fiber = @alignCast(@ptrCast(any_future));
    if (@atomicRmw(
        ?*Thread,
        &future_fiber.cancel_thread,
        .Xchg,
        Thread.canceling,
        .acq_rel,
    )) |cancel_thread| if (cancel_thread != Thread.canceling) {
        getSqe(&Thread.current().io_uring).* = .{
            .opcode = .MSG_RING,
            .flags = std.os.linux.IOSQE_CQE_SKIP_SUCCESS,
            .ioprio = 0,
            .fd = cancel_thread.io_uring.fd,
            .off = @intFromPtr(future_fiber),
            .addr = 0,
            .len = @bitCast(-@as(i32, @intFromEnum(std.os.linux.E.INTR))),
            .rw_flags = 0,
            .user_data = @intFromEnum(Completion.UserData.cleanup),
            .buf_index = 0,
            .personality = 0,
            .splice_fd_in = 0,
            .addr3 = 0,
            .resv = 0,
        };
    };
    @"await"(userdata, any_future, result, result_alignment);
}

fn cancelRequested(userdata: ?*anyopaque) bool {
    _ = userdata;
    return @atomicLoad(?*Thread, &Thread.current().currentFiber().cancel_thread, .acquire) == Thread.canceling;
}

fn createFile(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.CreateFlags,
) Io.File.OpenError!Io.File {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    const thread: *Thread = .current();
    const iou = &thread.io_uring;
    const fiber = thread.currentFiber();
    try fiber.enterCancelRegion(thread);

    const posix = std.posix;
    const sub_path_c = try posix.toPosixPath(sub_path);

    var os_flags: posix.O = .{
        .ACCMODE = if (flags.read) .RDWR else .WRONLY,
        .CREAT = true,
        .TRUNC = flags.truncate,
        .EXCL = flags.exclusive,
    };
    if (@hasField(posix.O, "LARGEFILE")) os_flags.LARGEFILE = true;
    if (@hasField(posix.O, "CLOEXEC")) os_flags.CLOEXEC = true;

    // Use the O locking flags if the os supports them to acquire the lock
    // atomically. Note that the NONBLOCK flag is removed after the openat()
    // call is successful.
    const has_flock_open_flags = @hasField(posix.O, "EXLOCK");
    if (has_flock_open_flags) switch (flags.lock) {
        .none => {},
        .shared => {
            os_flags.SHLOCK = true;
            os_flags.NONBLOCK = flags.lock_nonblocking;
        },
        .exclusive => {
            os_flags.EXLOCK = true;
            os_flags.NONBLOCK = flags.lock_nonblocking;
        },
    };
    const have_flock = @TypeOf(posix.system.flock) != void;

    if (have_flock and !has_flock_open_flags and flags.lock != .none) {
        @panic("TODO");
    }

    if (has_flock_open_flags and flags.lock_nonblocking) {
        @panic("TODO");
    }

    getSqe(iou).* = .{
        .opcode = .OPENAT,
        .flags = 0,
        .ioprio = 0,
        .fd = dir.handle,
        .off = 0,
        .addr = @intFromPtr(&sub_path_c),
        .len = @intCast(flags.mode),
        .rw_flags = @bitCast(os_flags),
        .user_data = @intFromPtr(fiber),
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };

    el.yield(null, .nothing);
    fiber.exitCancelRegion(thread);

    const completion = fiber.resultPointer(Completion);
    switch (errno(completion.result)) {
        .SUCCESS => return .{ .handle = completion.result },
        .INTR => unreachable,
        .CANCELED => return error.Canceled,

        .FAULT => unreachable,
        .INVAL => return error.BadPathName,
        .BADF => unreachable,
        .ACCES => return error.AccessDenied,
        .FBIG => return error.FileTooBig,
        .OVERFLOW => return error.FileTooBig,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NODEV => return error.NoDevice,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .NOTDIR => return error.NotDir,
        .PERM => return error.PermissionDenied,
        .EXIST => return error.PathAlreadyExists,
        .BUSY => return error.DeviceBusy,
        .OPNOTSUPP => return error.FileLocksNotSupported,
        .AGAIN => return error.WouldBlock,
        .TXTBSY => return error.FileBusy,
        .NXIO => return error.NoDevice,
        else => |err| return posix.unexpectedErrno(err),
    }
}

fn openFile(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.OpenFlags,
) Io.File.OpenError!Io.File {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    const thread: *Thread = .current();
    const iou = &thread.io_uring;
    const fiber = thread.currentFiber();
    try fiber.enterCancelRegion(thread);

    const posix = std.posix;
    const sub_path_c = try posix.toPosixPath(sub_path);

    var os_flags: posix.O = .{
        .ACCMODE = switch (flags.mode) {
            .read_only => .RDONLY,
            .write_only => .WRONLY,
            .read_write => .RDWR,
        },
    };

    if (@hasField(posix.O, "CLOEXEC")) os_flags.CLOEXEC = true;
    if (@hasField(posix.O, "LARGEFILE")) os_flags.LARGEFILE = true;
    if (@hasField(posix.O, "NOCTTY")) os_flags.NOCTTY = !flags.allow_ctty;

    // Use the O locking flags if the os supports them to acquire the lock
    // atomically.
    const has_flock_open_flags = @hasField(posix.O, "EXLOCK");
    if (has_flock_open_flags) {
        // Note that the NONBLOCK flag is removed after the openat() call
        // is successful.
        switch (flags.lock) {
            .none => {},
            .shared => {
                os_flags.SHLOCK = true;
                os_flags.NONBLOCK = flags.lock_nonblocking;
            },
            .exclusive => {
                os_flags.EXLOCK = true;
                os_flags.NONBLOCK = flags.lock_nonblocking;
            },
        }
    }
    const have_flock = @TypeOf(posix.system.flock) != void;

    if (have_flock and !has_flock_open_flags and flags.lock != .none) {
        @panic("TODO");
    }

    if (has_flock_open_flags and flags.lock_nonblocking) {
        @panic("TODO");
    }

    getSqe(iou).* = .{
        .opcode = .OPENAT,
        .flags = 0,
        .ioprio = 0,
        .fd = dir.handle,
        .off = 0,
        .addr = @intFromPtr(&sub_path_c),
        .len = 0,
        .rw_flags = @bitCast(os_flags),
        .user_data = @intFromPtr(fiber),
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };

    el.yield(null, .nothing);
    fiber.exitCancelRegion(thread);

    const completion = fiber.resultPointer(Completion);
    switch (errno(completion.result)) {
        .SUCCESS => return .{ .handle = completion.result },
        .INTR => unreachable,
        .CANCELED => return error.Canceled,

        .FAULT => unreachable,
        .INVAL => return error.BadPathName,
        .BADF => unreachable,
        .ACCES => return error.AccessDenied,
        .FBIG => return error.FileTooBig,
        .OVERFLOW => return error.FileTooBig,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NODEV => return error.NoDevice,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .NOTDIR => return error.NotDir,
        .PERM => return error.PermissionDenied,
        .EXIST => return error.PathAlreadyExists,
        .BUSY => return error.DeviceBusy,
        .OPNOTSUPP => return error.FileLocksNotSupported,
        .AGAIN => return error.WouldBlock,
        .TXTBSY => return error.FileBusy,
        .NXIO => return error.NoDevice,
        else => |err| return posix.unexpectedErrno(err),
    }
}

fn closeFile(userdata: ?*anyopaque, file: Io.File) void {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    const thread: *Thread = .current();
    const iou = &thread.io_uring;
    const fiber = thread.currentFiber();

    getSqe(iou).* = .{
        .opcode = .CLOSE,
        .flags = 0,
        .ioprio = 0,
        .fd = file.handle,
        .off = 0,
        .addr = 0,
        .len = 0,
        .rw_flags = 0,
        .user_data = @intFromPtr(fiber),
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };

    el.yield(null, .nothing);

    const completion = fiber.resultPointer(Completion);
    switch (errno(completion.result)) {
        .SUCCESS => return,
        .INTR => unreachable,
        .CANCELED => return,

        .BADF => unreachable, // Always a race condition.
        else => return,
    }
}

fn pread(userdata: ?*anyopaque, file: Io.File, buffer: []u8, offset: std.posix.off_t) Io.File.PReadError!usize {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    const thread: *Thread = .current();
    const iou = &thread.io_uring;
    const fiber = thread.currentFiber();
    try fiber.enterCancelRegion(thread);

    getSqe(iou).* = .{
        .opcode = .READ,
        .flags = 0,
        .ioprio = 0,
        .fd = file.handle,
        .off = @bitCast(offset),
        .addr = @intFromPtr(buffer.ptr),
        .len = @min(buffer.len, 0x7ffff000),
        .rw_flags = 0,
        .user_data = @intFromPtr(fiber),
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };

    el.yield(null, .nothing);
    fiber.exitCancelRegion(thread);

    const completion = fiber.resultPointer(Completion);
    switch (errno(completion.result)) {
        .SUCCESS => return @as(u32, @bitCast(completion.result)),
        .INTR => unreachable,
        .CANCELED => return error.Canceled,

        .INVAL => unreachable,
        .FAULT => unreachable,
        .NOENT => return error.ProcessNotFound,
        .AGAIN => return error.WouldBlock,
        .BADF => return error.NotOpenForReading, // Can be a race condition.
        .IO => return error.InputOutput,
        .ISDIR => return error.IsDir,
        .NOBUFS => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        .NOTCONN => return error.SocketNotConnected,
        .CONNRESET => return error.ConnectionResetByPeer,
        .TIMEDOUT => return error.ConnectionTimedOut,
        .NXIO => return error.Unseekable,
        .SPIPE => return error.Unseekable,
        .OVERFLOW => return error.Unseekable,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

fn pwrite(userdata: ?*anyopaque, file: Io.File, buffer: []const u8, offset: std.posix.off_t) Io.File.PWriteError!usize {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    const thread: *Thread = .current();
    const iou = &thread.io_uring;
    const fiber = thread.currentFiber();
    try fiber.enterCancelRegion(thread);

    getSqe(iou).* = .{
        .opcode = .WRITE,
        .flags = 0,
        .ioprio = 0,
        .fd = file.handle,
        .off = @bitCast(offset),
        .addr = @intFromPtr(buffer.ptr),
        .len = @min(buffer.len, 0x7ffff000),
        .rw_flags = 0,
        .user_data = @intFromPtr(fiber),
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };

    el.yield(null, .nothing);
    fiber.exitCancelRegion(thread);

    const completion = fiber.resultPointer(Completion);
    switch (errno(completion.result)) {
        .SUCCESS => return @as(u32, @bitCast(completion.result)),
        .INTR => unreachable,
        .CANCELED => return error.Canceled,

        .INVAL => return error.InvalidArgument,
        .FAULT => unreachable,
        .NOENT => return error.ProcessNotFound,
        .AGAIN => return error.WouldBlock,
        .BADF => return error.NotOpenForWriting, // can be a race condition.
        .DESTADDRREQ => unreachable, // `connect` was never called.
        .DQUOT => return error.DiskQuota,
        .FBIG => return error.FileTooBig,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .ACCES => return error.AccessDenied,
        .PERM => return error.PermissionDenied,
        .PIPE => return error.BrokenPipe,
        .NXIO => return error.Unseekable,
        .SPIPE => return error.Unseekable,
        .OVERFLOW => return error.Unseekable,
        .BUSY => return error.DeviceBusy,
        .CONNRESET => return error.ConnectionResetByPeer,
        .MSGSIZE => return error.MessageTooBig,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

fn now(userdata: ?*anyopaque, clockid: std.posix.clockid_t) Io.ClockGetTimeError!Io.Timestamp {
    _ = userdata;
    const timespec = try std.posix.clock_gettime(clockid);
    return @enumFromInt(@as(i128, timespec.sec) * std.time.ns_per_s + timespec.nsec);
}

fn sleep(userdata: ?*anyopaque, clockid: std.posix.clockid_t, deadline: Io.Deadline) Io.SleepError!void {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    const thread: *Thread = .current();
    const iou = &thread.io_uring;
    const fiber = thread.currentFiber();
    try fiber.enterCancelRegion(thread);

    const deadline_nanoseconds: i96 = switch (deadline) {
        .duration => |duration| duration.nanoseconds,
        .timestamp => |timestamp| @intFromEnum(timestamp),
    };
    const timespec: std.os.linux.kernel_timespec = .{
        .sec = @intCast(@divFloor(deadline_nanoseconds, std.time.ns_per_s)),
        .nsec = @intCast(@mod(deadline_nanoseconds, std.time.ns_per_s)),
    };
    getSqe(iou).* = .{
        .opcode = .TIMEOUT,
        .flags = 0,
        .ioprio = 0,
        .fd = 0,
        .off = 0,
        .addr = @intFromPtr(&timespec),
        .len = 1,
        .rw_flags = @as(u32, switch (deadline) {
            .duration => 0,
            .timestamp => std.os.linux.IORING_TIMEOUT_ABS,
        }) | @as(u32, switch (clockid) {
            .REALTIME => std.os.linux.IORING_TIMEOUT_REALTIME,
            .MONOTONIC => 0,
            .BOOTTIME => std.os.linux.IORING_TIMEOUT_BOOTTIME,
            else => return error.UnsupportedClock,
        }),
        .user_data = @intFromPtr(fiber),
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };

    el.yield(null, .nothing);
    fiber.exitCancelRegion(thread);

    const completion = fiber.resultPointer(Completion);
    switch (errno(completion.result)) {
        .SUCCESS, .TIME => return,
        .INTR => unreachable,
        .CANCELED => return error.Canceled,

        else => |err| return std.posix.unexpectedErrno(err),
    }
}

fn mutexLock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) error{Canceled}!void {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    el.yield(null, .{ .mutex_lock = .{ .prev_state = prev_state, .mutex = mutex } });
}
fn mutexUnlock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    var maybe_waiting_fiber: ?*Fiber = @ptrFromInt(@intFromEnum(prev_state));
    while (if (maybe_waiting_fiber) |waiting_fiber| @cmpxchgWeak(
        Io.Mutex.State,
        &mutex.state,
        @enumFromInt(@intFromPtr(waiting_fiber)),
        @enumFromInt(@intFromPtr(waiting_fiber.queue_next)),
        .release,
        .acquire,
    ) else @cmpxchgWeak(
        Io.Mutex.State,
        &mutex.state,
        .locked_once,
        .unlocked,
        .release,
        .acquire,
    ) orelse return) |next_state| maybe_waiting_fiber = @ptrFromInt(@intFromEnum(next_state));
    maybe_waiting_fiber.?.queue_next = null;
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    el.yield(maybe_waiting_fiber.?, .reschedule);
}

const ConditionImpl = struct {
    tail: *Fiber,
    event: union(enum) {
        queued,
        wake: Io.Condition.Wake,
    },
};

fn conditionWait(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) Io.Cancelable!void {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    el.yield(null, .{ .condition_wait = .{ .cond = cond, .mutex = mutex } });
    const thread = Thread.current();
    const fiber = thread.currentFiber();
    const cond_impl = fiber.resultPointer(ConditionImpl);
    try mutex.lock(el.io());
    switch (cond_impl.event) {
        .queued => {},
        .wake => |wake| if (fiber.queue_next) |next_fiber| switch (wake) {
            .one => if (@cmpxchgStrong(
                ?*Fiber,
                @as(*?*Fiber, @ptrCast(&cond.state)),
                null,
                next_fiber,
                .release,
                .acquire,
            )) |old_fiber| {
                const old_cond_impl = old_fiber.?.resultPointer(ConditionImpl);
                assert(old_cond_impl.tail.queue_next == null);
                old_cond_impl.tail.queue_next = next_fiber;
                old_cond_impl.tail = cond_impl.tail;
            },
            .all => el.schedule(thread, .{ .head = next_fiber, .tail = cond_impl.tail }),
        },
    }
    fiber.queue_next = null;
}

fn conditionWake(userdata: ?*anyopaque, cond: *Io.Condition, wake: Io.Condition.Wake) void {
    const el: *EventLoop = @alignCast(@ptrCast(userdata));
    const waiting_fiber = @atomicRmw(?*Fiber, @as(*?*Fiber, @ptrCast(&cond.state)), .Xchg, null, .acquire) orelse return;
    waiting_fiber.resultPointer(ConditionImpl).event = .{ .wake = wake };
    el.yield(waiting_fiber, .reschedule);
}

fn errno(signed: i32) std.os.linux.E {
    return .init(@bitCast(@as(isize, signed)));
}

fn getSqe(iou: *IoUring) *std.os.linux.io_uring_sqe {
    while (true) return iou.get_sqe() catch {
        _ = iou.submit_and_wait(0) catch |err| switch (err) {
            error.SignalInterrupt => std.log.warn("submit_and_wait failed with SignalInterrupt", .{}),
            else => |e| @panic(@errorName(e)),
        };
        continue;
    };
}
