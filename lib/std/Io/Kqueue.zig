const Kqueue = @This();
const builtin = @import("builtin");

const std = @import("../std.zig");
const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;
const net = std.Io.net;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const IpAddress = std.Io.net.IpAddress;
const errnoBug = std.Io.Threaded.errnoBug;
const posix = std.posix;

/// Must be a thread-safe allocator.
gpa: Allocator,
mutex: std.Thread.Mutex,
main_fiber_buffer: [@sizeOf(Fiber) + Fiber.max_result_size]u8 align(@alignOf(Fiber)),
threads: Thread.List,

/// Empirically saw >128KB being used by the self-hosted backend to panic.
const idle_stack_size = 256 * 1024;

const max_idle_search = 4;
const max_steal_ready_search = 4;
const max_iovecs_len = 8;

const changes_buffer_len = 64;

const Thread = struct {
    thread: std.Thread,
    idle_context: Context,
    current_context: *Context,
    ready_queue: ?*Fiber,
    kq_fd: posix.fd_t,
    idle_search_index: u32,
    steal_ready_search_index: u32,
    /// For ensuring multiple fibers waiting on the same file descriptor and
    /// filter use the same kevent.
    wait_queues: std.AutoArrayHashMapUnmanaged(WaitQueueKey, *Fiber),

    const WaitQueueKey = struct {
        ident: usize,
        filter: i32,
    };

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

    fn deinit(thread: *Thread, gpa: Allocator) void {
        posix.close(thread.kq_fd);
        assert(thread.wait_queues.count() == 0);
        thread.wait_queues.deinit(gpa);
        thread.* = undefined;
    }
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
    const max_closure_size: usize = @sizeOf(AsyncClosure);
    const max_closure_align: Alignment = .of(AsyncClosure);
    const allocation_size = std.mem.alignForward(
        usize,
        max_closure_align.max(max_context_align).forward(
            max_result_align.forward(@sizeOf(Fiber)) + max_result_size + min_stack_size,
        ) + max_closure_size + max_context_size,
        std.heap.page_size_max,
    );

    fn allocate(k: *Kqueue) error{OutOfMemory}!*Fiber {
        return @ptrCast(try k.gpa.alignedAlloc(u8, .of(Fiber), allocation_size));
    }

    fn allocatedSlice(f: *Fiber) []align(@alignOf(Fiber)) u8 {
        return @as([*]align(@alignOf(Fiber)) u8, @ptrCast(f))[0..allocation_size];
    }

    fn allocatedEnd(f: *Fiber) [*]u8 {
        const allocated_slice = f.allocatedSlice();
        return allocated_slice[allocated_slice.len..].ptr;
    }

    fn resultPointer(f: *Fiber, comptime Result: type) *Result {
        return @ptrCast(@alignCast(f.resultBytes(.of(Result))));
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

fn recycle(k: *Kqueue, fiber: *Fiber) void {
    std.log.debug("recyling {*}", .{fiber});
    assert(fiber.queue_next == null);
    k.gpa.free(fiber.allocatedSlice());
}

pub const InitOptions = struct {
    n_threads: ?usize = null,
};

pub fn init(k: *Kqueue, gpa: Allocator, options: InitOptions) !void {
    assert(options.n_threads != 0);
    const n_threads = @max(1, options.n_threads orelse std.Thread.getCpuCount() catch 1);
    const threads_size = n_threads * @sizeOf(Thread);
    const idle_stack_end_offset = std.mem.alignForward(usize, threads_size + idle_stack_size, std.heap.page_size_max);
    const allocated_slice = try gpa.alignedAlloc(u8, .of(Thread), idle_stack_end_offset);
    errdefer gpa.free(allocated_slice);
    k.* = .{
        .gpa = gpa,
        .mutex = .{},
        .main_fiber_buffer = undefined,
        .threads = .{
            .allocated = @ptrCast(allocated_slice[0..threads_size]),
            .reserved = 1,
            .active = 1,
        },
    };
    const main_fiber: *Fiber = @ptrCast(&k.main_fiber_buffer);
    main_fiber.* = .{
        .required_align = {},
        .context = undefined,
        .awaiter = null,
        .queue_next = null,
        .cancel_thread = null,
        .awaiting_completions = .initEmpty(),
    };
    const main_thread = &k.threads.allocated[0];
    Thread.self = main_thread;
    const idle_stack_end: [*]align(16) usize = @ptrCast(@alignCast(allocated_slice[idle_stack_end_offset..].ptr));
    (idle_stack_end - 1)[0..1].* = .{@intFromPtr(k)};
    main_thread.* = .{
        .thread = undefined,
        .idle_context = switch (builtin.cpu.arch) {
            .aarch64 => .{
                .sp = @intFromPtr(idle_stack_end),
                .fp = 0,
                .pc = @intFromPtr(&mainIdleEntry),
            },
            .x86_64 => .{
                .rsp = @intFromPtr(idle_stack_end - 1),
                .rbp = 0,
                .rip = @intFromPtr(&mainIdleEntry),
            },
            else => @compileError("unimplemented architecture"),
        },
        .current_context = &main_fiber.context,
        .ready_queue = null,
        .kq_fd = try posix.kqueue(),
        .idle_search_index = 1,
        .steal_ready_search_index = 1,
        .wait_queues = .empty,
    };
    errdefer std.posix.close(main_thread.kq_fd);
    std.log.debug("created main idle {*}", .{&main_thread.idle_context});
    std.log.debug("created main {*}", .{main_fiber});
}

pub fn deinit(k: *Kqueue) void {
    const active_threads = @atomicLoad(u32, &k.threads.active, .acquire);
    for (k.threads.allocated[0..active_threads]) |*thread| {
        const ready_fiber = @atomicLoad(?*Fiber, &thread.ready_queue, .monotonic);
        assert(ready_fiber == null or ready_fiber == Fiber.finished); // pending async
    }
    k.yield(null, .exit);
    const main_thread = &k.threads.allocated[0];
    const gpa = k.gpa;
    main_thread.deinit(gpa);
    const allocated_ptr: [*]align(@alignOf(Thread)) u8 = @ptrCast(@alignCast(k.threads.allocated.ptr));
    const idle_stack_end_offset = std.mem.alignForward(usize, k.threads.allocated.len * @sizeOf(Thread) + idle_stack_size, std.heap.page_size_max);
    for (k.threads.allocated[1..active_threads]) |*thread| thread.thread.join();
    gpa.free(allocated_ptr[0..idle_stack_end_offset]);
    k.* = undefined;
}

fn findReadyFiber(k: *Kqueue, thread: *Thread) ?*Fiber {
    if (@atomicRmw(?*Fiber, &thread.ready_queue, .Xchg, Fiber.finished, .acquire)) |ready_fiber| {
        @atomicStore(?*Fiber, &thread.ready_queue, ready_fiber.queue_next, .release);
        ready_fiber.queue_next = null;
        return ready_fiber;
    }
    const active_threads = @atomicLoad(u32, &k.threads.active, .acquire);
    for (0..@min(max_steal_ready_search, active_threads)) |_| {
        defer thread.steal_ready_search_index += 1;
        if (thread.steal_ready_search_index == active_threads) thread.steal_ready_search_index = 0;
        const steal_ready_search_thread = &k.threads.allocated[0..active_threads][thread.steal_ready_search_index];
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

fn yield(k: *Kqueue, maybe_ready_fiber: ?*Fiber, pending_task: SwitchMessage.PendingTask) void {
    const thread: *Thread = .current();
    const ready_context = if (maybe_ready_fiber orelse k.findReadyFiber(thread)) |ready_fiber|
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
    contextSwitch(&message).handle(k);
}

fn schedule(k: *Kqueue, thread: *Thread, ready_queue: Fiber.Queue) void {
    {
        var fiber = ready_queue.head;
        while (true) {
            std.log.debug("scheduling {*}", .{fiber});
            fiber = fiber.queue_next orelse break;
        }
        assert(fiber == ready_queue.tail);
    }
    // shared fields of previous `Thread` must be initialized before later ones are marked as active
    const new_thread_index = @atomicLoad(u32, &k.threads.active, .acquire);
    for (0..@min(max_idle_search, new_thread_index)) |_| {
        defer thread.idle_search_index += 1;
        if (thread.idle_search_index == new_thread_index) thread.idle_search_index = 0;
        const idle_search_thread = &k.threads.allocated[0..new_thread_index][thread.idle_search_index];
        if (idle_search_thread == thread) continue;
        if (@cmpxchgWeak(
            ?*Fiber,
            &idle_search_thread.ready_queue,
            null,
            ready_queue.head,
            .release,
            .monotonic,
        )) |_| continue;
        const changes = [_]posix.Kevent{
            .{
                .ident = 0,
                .filter = std.c.EVFILT.USER,
                .flags = std.c.EV.ADD | std.c.EV.ONESHOT,
                .fflags = std.c.NOTE.TRIGGER,
                .data = 0,
                .udata = @intFromEnum(Completion.UserData.wakeup),
            },
        };
        // If an error occurs it only pessimises scheduling.
        _ = posix.kevent(idle_search_thread.kq_fd, &changes, &.{}, null) catch {};
        return;
    }
    spawn_thread: {
        // previous failed reservations must have completed before retrying
        if (new_thread_index == k.threads.allocated.len or @cmpxchgWeak(
            u32,
            &k.threads.reserved,
            new_thread_index,
            new_thread_index + 1,
            .acquire,
            .monotonic,
        ) != null) break :spawn_thread;
        const new_thread = &k.threads.allocated[new_thread_index];
        const next_thread_index = new_thread_index + 1;
        new_thread.* = .{
            .thread = undefined,
            .idle_context = undefined,
            .current_context = &new_thread.idle_context,
            .ready_queue = ready_queue.head,
            .kq_fd = posix.kqueue() catch |err| {
                @atomicStore(u32, &k.threads.reserved, new_thread_index, .release);
                // no more access to `thread` after giving up reservation
                std.log.warn("unable to create worker thread due to kqueue init failure: {t}", .{err});
                break :spawn_thread;
            },
            .idle_search_index = 0,
            .steal_ready_search_index = 0,
            .wait_queues = .empty,
        };
        new_thread.thread = std.Thread.spawn(.{
            .stack_size = idle_stack_size,
            .allocator = k.gpa,
        }, threadEntry, .{ k, new_thread_index }) catch |err| {
            posix.close(new_thread.kq_fd);
            @atomicStore(u32, &k.threads.reserved, new_thread_index, .release);
            // no more access to `thread` after giving up reservation
            std.log.warn("unable to create worker thread due spawn failure: {s}", .{@errorName(err)});
            break :spawn_thread;
        };
        // shared fields of `Thread` must be initialized before being marked active
        @atomicStore(u32, &k.threads.active, next_thread_index, .release);
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

fn mainIdle(k: *Kqueue, message: *const SwitchMessage) callconv(.withStackAlign(.c, @max(@alignOf(Thread), @alignOf(Context)))) noreturn {
    message.handle(k);
    k.idle(&k.threads.allocated[0]);
    k.yield(@ptrCast(&k.main_fiber_buffer), .nothing);
    unreachable; // switched to dead fiber
}

fn threadEntry(k: *Kqueue, index: u32) void {
    const thread: *Thread = &k.threads.allocated[index];
    Thread.self = thread;
    std.log.debug("created thread idle {*}", .{&thread.idle_context});
    k.idle(thread);
    thread.deinit(k.gpa);
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
    /// Corresponds to Kevent field.
    flags: u16,
    /// Corresponds to Kevent field.
    fflags: u32,
    /// Corresponds to Kevent field.
    data: isize,
};

fn idle(k: *Kqueue, thread: *Thread) void {
    var events_buffer: [changes_buffer_len]posix.Kevent = undefined;
    var maybe_ready_fiber: ?*Fiber = null;
    while (true) {
        while (maybe_ready_fiber orelse k.findReadyFiber(thread)) |ready_fiber| {
            k.yield(ready_fiber, .nothing);
            maybe_ready_fiber = null;
        }
        const n = posix.kevent(thread.kq_fd, &.{}, &events_buffer, null) catch |err| {
            // TODO handle EINTR for cancellation purposes
            @panic(@errorName(err));
        };
        var maybe_ready_queue: ?Fiber.Queue = null;
        for (events_buffer[0..n]) |event| switch (@as(Completion.UserData, @enumFromInt(event.udata))) {
            .unused => unreachable, // bad submission queued?
            .wakeup => {},
            .cleanup => @panic("failed to notify other threads that we are exiting"),
            .exit => {
                assert(maybe_ready_fiber == null and maybe_ready_queue == null); // pending async
                return;
            },
            _ => {
                const event_head_fiber: *Fiber = @ptrFromInt(event.udata);
                const event_tail_fiber = thread.wait_queues.fetchSwapRemove(.{
                    .ident = event.ident,
                    .filter = event.filter,
                }).?.value;
                assert(event_tail_fiber.queue_next == null);

                // TODO reevaluate this logic
                event_head_fiber.resultPointer(Completion).* = .{
                    .flags = event.flags,
                    .fflags = event.fflags,
                    .data = event.data,
                };

                queue_ready: {
                    const head: *Fiber = if (maybe_ready_fiber == null) f: {
                        maybe_ready_fiber = event_head_fiber;
                        const next = event_head_fiber.queue_next orelse break :queue_ready;
                        event_head_fiber.queue_next = null;
                        break :f next;
                    } else event_head_fiber;

                    if (maybe_ready_queue) |*ready_queue| {
                        ready_queue.tail.queue_next = head;
                        ready_queue.tail = event_tail_fiber;
                    } else {
                        maybe_ready_queue = .{ .head = head, .tail = event_tail_fiber };
                    }
                }
            },
        };
        if (maybe_ready_queue) |ready_queue| k.schedule(thread, ready_queue);
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
        recycle: *Fiber,
        register_awaiter: *?*Fiber,
        register_select: []const *Io.AnyFuture,
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

    fn handle(message: *const SwitchMessage, k: *Kqueue) void {
        const thread: *Thread = .current();
        thread.current_context = message.contexts.ready;
        switch (message.pending_task) {
            .nothing => {},
            .reschedule => if (message.contexts.prev != &thread.idle_context) {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                k.schedule(thread, .{ .head = prev_fiber, .tail = prev_fiber });
            },
            .recycle => |fiber| {
                k.recycle(fiber);
            },
            .register_awaiter => |awaiter| {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                if (@atomicRmw(?*Fiber, awaiter, .Xchg, prev_fiber, .acq_rel) == Fiber.finished)
                    k.schedule(thread, .{ .head = prev_fiber, .tail = prev_fiber });
            },
            .register_select => |futures| {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                for (futures) |any_future| {
                    const future_fiber: *Fiber = @ptrCast(@alignCast(any_future));
                    if (@atomicRmw(?*Fiber, &future_fiber.awaiter, .Xchg, prev_fiber, .acq_rel) == Fiber.finished) {
                        const closure: *AsyncClosure = .fromFiber(future_fiber);
                        if (!@atomicRmw(bool, &closure.already_awaited, .Xchg, true, .seq_cst)) {
                            k.schedule(thread, .{ .head = prev_fiber, .tail = prev_fiber });
                        }
                    }
                }
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
                        k.schedule(thread, .{ .head = prev_fiber, .tail = prev_fiber });
                        return;
                    },
                }) |next_state| prev_state = next_state;
            },
            .condition_wait => |condition_wait| {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                assert(prev_fiber.queue_next == null);
                const cond_impl = prev_fiber.resultPointer(Condition);
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
                    const waiting_cond_impl = waiting_fiber.?.resultPointer(Condition);
                    assert(waiting_cond_impl.tail.queue_next == null);
                    waiting_cond_impl.tail.queue_next = prev_fiber;
                    waiting_cond_impl.tail = prev_fiber;
                }
                condition_wait.mutex.unlock(k.io());
            },
            .exit => for (k.threads.allocated[0..@atomicLoad(u32, &k.threads.active, .acquire)]) |*each_thread| {
                const changes = [_]posix.Kevent{
                    .{
                        .ident = 0,
                        .filter = std.c.EVFILT.USER,
                        .flags = std.c.EV.ADD | std.c.EV.ONESHOT,
                        .fflags = std.c.NOTE.TRIGGER,
                        .data = 0,
                        .udata = @intFromEnum(Completion.UserData.exit),
                    },
                };
                _ = posix.kevent(each_thread.kq_fd, &changes, &.{}, null) catch |err| {
                    @panic(@errorName(err));
                };
            },
        }
    }
};

const Context = switch (builtin.cpu.arch) {
    .aarch64 => extern struct {
        sp: u64,
        fp: u64,
        pc: u64,
    },
    .x86_64 => extern struct {
        rsp: u64,
        rbp: u64,
        rip: u64,
    },
    else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
};

inline fn contextSwitch(message: *const SwitchMessage) *const SwitchMessage {
    return @fieldParentPtr("contexts", switch (builtin.cpu.arch) {
        .aarch64 => asm volatile (
            \\ ldp x0, x2, [x1]
            \\ ldr x3, [x2, #16]
            \\ mov x4, sp
            \\ stp x4, fp, [x0]
            \\ adr x5, 0f
            \\ ldp x4, fp, [x2]
            \\ str x5, [x0, #16]
            \\ mov sp, x4
            \\ br x3
            \\0:
            : [received_message] "={x1}" (-> *const @FieldType(SwitchMessage, "contexts")),
            : [message_to_send] "{x1}" (&message.contexts),
            : .{
              .x0 = true,
              .x1 = true,
              .x2 = true,
              .x3 = true,
              .x4 = true,
              .x5 = true,
              .x6 = true,
              .x7 = true,
              .x8 = true,
              .x9 = true,
              .x10 = true,
              .x11 = true,
              .x12 = true,
              .x13 = true,
              .x14 = true,
              .x15 = true,
              .x16 = true,
              .x17 = true,
              .x19 = true,
              .x20 = true,
              .x21 = true,
              .x22 = true,
              .x23 = true,
              .x24 = true,
              .x25 = true,
              .x26 = true,
              .x27 = true,
              .x28 = true,
              .x30 = true,
              .z0 = true,
              .z1 = true,
              .z2 = true,
              .z3 = true,
              .z4 = true,
              .z5 = true,
              .z6 = true,
              .z7 = true,
              .z8 = true,
              .z9 = true,
              .z10 = true,
              .z11 = true,
              .z12 = true,
              .z13 = true,
              .z14 = true,
              .z15 = true,
              .z16 = true,
              .z17 = true,
              .z18 = true,
              .z19 = true,
              .z20 = true,
              .z21 = true,
              .z22 = true,
              .z23 = true,
              .z24 = true,
              .z25 = true,
              .z26 = true,
              .z27 = true,
              .z28 = true,
              .z29 = true,
              .z30 = true,
              .z31 = true,
              .p0 = true,
              .p1 = true,
              .p2 = true,
              .p3 = true,
              .p4 = true,
              .p5 = true,
              .p6 = true,
              .p7 = true,
              .p8 = true,
              .p9 = true,
              .p10 = true,
              .p11 = true,
              .p12 = true,
              .p13 = true,
              .p14 = true,
              .p15 = true,
              .fpcr = true,
              .fpsr = true,
              .ffr = true,
              .memory = true,
            }),
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
            : .{
              .rax = true,
              .rcx = true,
              .rdx = true,
              .rbx = true,
              .rsi = true,
              .rdi = true,
              .r8 = true,
              .r9 = true,
              .r10 = true,
              .r11 = true,
              .r12 = true,
              .r13 = true,
              .r14 = true,
              .r15 = true,
              .mm0 = true,
              .mm1 = true,
              .mm2 = true,
              .mm3 = true,
              .mm4 = true,
              .mm5 = true,
              .mm6 = true,
              .mm7 = true,
              .zmm0 = true,
              .zmm1 = true,
              .zmm2 = true,
              .zmm3 = true,
              .zmm4 = true,
              .zmm5 = true,
              .zmm6 = true,
              .zmm7 = true,
              .zmm8 = true,
              .zmm9 = true,
              .zmm10 = true,
              .zmm11 = true,
              .zmm12 = true,
              .zmm13 = true,
              .zmm14 = true,
              .zmm15 = true,
              .zmm16 = true,
              .zmm17 = true,
              .zmm18 = true,
              .zmm19 = true,
              .zmm20 = true,
              .zmm21 = true,
              .zmm22 = true,
              .zmm23 = true,
              .zmm24 = true,
              .zmm25 = true,
              .zmm26 = true,
              .zmm27 = true,
              .zmm28 = true,
              .zmm29 = true,
              .zmm30 = true,
              .zmm31 = true,
              .fpsr = true,
              .fpcr = true,
              .mxcsr = true,
              .rflags = true,
              .dirflag = true,
              .memory = true,
            }),
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
        .aarch64 => asm volatile (
            \\ ldr x0, [sp, #-8]
            \\ b %[mainIdle]
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
        .aarch64 => asm volatile (
            \\ mov x0, sp
            \\ b %[AsyncClosure_call]
            :
            : [AsyncClosure_call] "X" (&AsyncClosure.call),
        ),
        else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
    }
}

const AsyncClosure = struct {
    kqueue: *Kqueue,
    fiber: *Fiber,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
    result_align: Alignment,
    already_awaited: bool,

    fn contextPointer(closure: *AsyncClosure) [*]align(Fiber.max_context_align.toByteUnits()) u8 {
        return @alignCast(@as([*]u8, @ptrCast(closure)) + @sizeOf(AsyncClosure));
    }

    fn call(closure: *AsyncClosure, message: *const SwitchMessage) callconv(.withStackAlign(.c, @alignOf(AsyncClosure))) noreturn {
        message.handle(closure.kqueue);
        const fiber = closure.fiber;
        std.log.debug("{*} performing async", .{fiber});
        closure.start(closure.contextPointer(), fiber.resultBytes(closure.result_align));
        const awaiter = @atomicRmw(?*Fiber, &fiber.awaiter, .Xchg, Fiber.finished, .acq_rel);
        const ready_awaiter = r: {
            const a = awaiter orelse break :r null;
            if (@atomicRmw(bool, &closure.already_awaited, .Xchg, true, .acq_rel)) break :r null;
            break :r a;
        };
        closure.kqueue.yield(ready_awaiter, .nothing);
        unreachable; // switched to dead fiber
    }

    fn fromFiber(fiber: *Fiber) *AsyncClosure {
        return @ptrFromInt(Fiber.max_context_align.max(.of(AsyncClosure)).backward(
            @intFromPtr(fiber.allocatedEnd()) - Fiber.max_context_size,
        ) - @sizeOf(AsyncClosure));
    }
};

pub fn io(k: *Kqueue) Io {
    return .{
        .userdata = k,
        .vtable = &.{
            .async = async,
            .concurrent = concurrent,
            .await = await,
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .select = select,

            .groupAsync = groupAsync,
            .groupWait = groupWait,
            .groupCancel = groupCancel,

            .mutexLock = mutexLock,
            .mutexLockUncancelable = mutexLockUncancelable,
            .mutexUnlock = mutexUnlock,

            .conditionWait = conditionWait,
            .conditionWaitUncancelable = conditionWaitUncancelable,
            .conditionWake = conditionWake,

            .dirMake = dirMake,
            .dirMakePath = dirMakePath,
            .dirMakeOpenPath = dirMakeOpenPath,
            .dirStat = dirStat,
            .dirStatPath = dirStatPath,

            .fileStat = fileStat,
            .dirAccess = dirAccess,
            .dirCreateFile = dirCreateFile,
            .dirOpenFile = dirOpenFile,
            .dirOpenDir = dirOpenDir,
            .dirClose = dirClose,
            .fileClose = fileClose,
            .fileWriteStreaming = fileWriteStreaming,
            .fileWritePositional = fileWritePositional,
            .fileReadStreaming = fileReadStreaming,
            .fileReadPositional = fileReadPositional,
            .fileSeekBy = fileSeekBy,
            .fileSeekTo = fileSeekTo,
            .openSelfExe = openSelfExe,

            .now = now,
            .sleep = sleep,

            .netListenIp = netListenIp,
            .netListenUnix = netListenUnix,
            .netAccept = netAccept,
            .netBindIp = netBindIp,
            .netConnectIp = netConnectIp,
            .netConnectUnix = netConnectUnix,
            .netClose = netClose,
            .netRead = netRead,
            .netWrite = netWrite,
            .netSend = netSend,
            .netReceive = netReceive,
            .netInterfaceNameResolve = netInterfaceNameResolve,
            .netInterfaceName = netInterfaceName,
            .netLookup = netLookup,
        },
    };
}

fn async(
    userdata: ?*anyopaque,
    result: []u8,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*Io.AnyFuture {
    return concurrent(userdata, result.len, result_alignment, context, context_alignment, start) catch {
        start(context.ptr, result.ptr);
        return null;
    };
}

fn concurrent(
    userdata: ?*anyopaque,
    result_len: usize,
    result_alignment: Alignment,
    context: []const u8,
    context_alignment: Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) Io.ConcurrentError!*Io.AnyFuture {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    assert(result_alignment.compare(.lte, Fiber.max_result_align)); // TODO
    assert(context_alignment.compare(.lte, Fiber.max_context_align)); // TODO
    assert(result_len <= Fiber.max_result_size); // TODO
    assert(context.len <= Fiber.max_context_size); // TODO

    const fiber = Fiber.allocate(k) catch return error.ConcurrencyUnavailable;
    std.log.debug("allocated {*}", .{fiber});

    const closure: *AsyncClosure = .fromFiber(fiber);
    fiber.* = .{
        .required_align = {},
        .context = switch (builtin.cpu.arch) {
            .x86_64 => .{
                .rsp = @intFromPtr(closure) - @sizeOf(usize),
                .rbp = 0,
                .rip = @intFromPtr(&fiberEntry),
            },
            .aarch64 => .{
                .sp = @intFromPtr(closure),
                .fp = 0,
                .pc = @intFromPtr(&fiberEntry),
            },
            else => |arch| @compileError("unimplemented architecture: " ++ @tagName(arch)),
        },
        .awaiter = null,
        .queue_next = null,
        .cancel_thread = null,
        .awaiting_completions = .initEmpty(),
    };
    closure.* = .{
        .kqueue = k,
        .fiber = fiber,
        .start = start,
        .result_align = result_alignment,
        .already_awaited = false,
    };
    @memcpy(closure.contextPointer(), context);

    k.schedule(.current(), .{ .head = fiber, .tail = fiber });
    return @ptrCast(fiber);
}

fn await(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    const future_fiber: *Fiber = @ptrCast(@alignCast(any_future));
    if (@atomicLoad(?*Fiber, &future_fiber.awaiter, .acquire) != Fiber.finished)
        k.yield(null, .{ .register_awaiter = &future_fiber.awaiter });
    @memcpy(result, future_fiber.resultBytes(result_alignment));
    k.recycle(future_fiber);
}

fn cancel(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = any_future;
    _ = result;
    _ = result_alignment;
    @panic("TODO");
}

fn cancelRequested(userdata: ?*anyopaque) bool {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    return false; // TODO
}

fn groupAsync(
    userdata: ?*anyopaque,
    group: *Io.Group,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (*Io.Group, context: *const anyopaque) void,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = group;
    _ = context;
    _ = context_alignment;
    _ = start;
    @panic("TODO");
}

fn groupWait(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = group;
    _ = token;
    @panic("TODO");
}

fn groupCancel(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = group;
    _ = token;
    @panic("TODO");
}

fn select(userdata: ?*anyopaque, futures: []const *Io.AnyFuture) Io.Cancelable!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = futures;
    @panic("TODO");
}

fn mutexLock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) Io.Cancelable!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = prev_state;
    _ = mutex;
    @panic("TODO");
}
fn mutexLockUncancelable(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = prev_state;
    _ = mutex;
    @panic("TODO");
}
fn mutexUnlock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = prev_state;
    _ = mutex;
    @panic("TODO");
}

fn conditionWait(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) Io.Cancelable!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    k.yield(null, .{ .condition_wait = .{ .cond = cond, .mutex = mutex } });
    const thread = Thread.current();
    const fiber = thread.currentFiber();
    const cond_impl = fiber.resultPointer(Condition);
    try mutex.lock(k.io());
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
                const old_cond_impl = old_fiber.?.resultPointer(Condition);
                assert(old_cond_impl.tail.queue_next == null);
                old_cond_impl.tail.queue_next = next_fiber;
                old_cond_impl.tail = cond_impl.tail;
            },
            .all => k.schedule(thread, .{ .head = next_fiber, .tail = cond_impl.tail }),
        },
    }
    fiber.queue_next = null;
}

fn conditionWaitUncancelable(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = cond;
    _ = mutex;
    @panic("TODO");
}
fn conditionWake(userdata: ?*anyopaque, cond: *Io.Condition, wake: Io.Condition.Wake) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    const waiting_fiber = @atomicRmw(?*Fiber, @as(*?*Fiber, @ptrCast(&cond.state)), .Xchg, null, .acquire) orelse return;
    waiting_fiber.resultPointer(Condition).event = .{ .wake = wake };
    k.yield(waiting_fiber, .reschedule);
}

fn dirMake(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, mode: Dir.Mode) Dir.MakeError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = mode;
    @panic("TODO");
}
fn dirMakePath(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, mode: Dir.Mode) Dir.MakeError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = mode;
    @panic("TODO");
}
fn dirMakeOpenPath(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.OpenOptions) Dir.MakeOpenPathError!Dir {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirStat(userdata: ?*anyopaque, dir: Dir) Dir.StatError!Dir.Stat {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    @panic("TODO");
}
fn dirStatPath(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.StatPathOptions) Dir.StatPathError!File.Stat {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirAccess(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.AccessOptions) Dir.AccessError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirCreateFile(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = flags;
    @panic("TODO");
}
fn dirOpenFile(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = flags;
    @panic("TODO");
}
fn dirOpenDir(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.OpenOptions) Dir.OpenError!Dir {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirClose(userdata: ?*anyopaque, dir: Dir) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    @panic("TODO");
}
fn fileStat(userdata: ?*anyopaque, file: File) File.StatError!File.Stat {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    @panic("TODO");
}
fn fileClose(userdata: ?*anyopaque, file: File) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    @panic("TODO");
}
fn fileWriteStreaming(userdata: ?*anyopaque, file: File, buffer: [][]const u8) File.WriteStreamingError!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = buffer;
    @panic("TODO");
}
fn fileWritePositional(userdata: ?*anyopaque, file: File, buffer: [][]const u8, offset: u64) File.WritePositionalError!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = buffer;
    _ = offset;
    @panic("TODO");
}
fn fileReadStreaming(userdata: ?*anyopaque, file: File, data: [][]u8) File.Reader.Error!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = data;
    @panic("TODO");
}
fn fileReadPositional(userdata: ?*anyopaque, file: File, data: [][]u8, offset: u64) File.ReadPositionalError!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = data;
    _ = offset;
    @panic("TODO");
}
fn fileSeekBy(userdata: ?*anyopaque, file: File, relative_offset: i64) File.SeekError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = relative_offset;
    @panic("TODO");
}
fn fileSeekTo(userdata: ?*anyopaque, file: File, absolute_offset: u64) File.SeekError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = absolute_offset;
    @panic("TODO");
}
fn openSelfExe(userdata: ?*anyopaque, file: File.OpenFlags) File.OpenSelfExeError!File {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    @panic("TODO");
}

fn now(userdata: ?*anyopaque, clock: Io.Clock) Io.Clock.Error!Io.Timestamp {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = clock;
    @panic("TODO");
}
fn sleep(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = timeout;
    @panic("TODO");
}

fn netListenIp(
    userdata: ?*anyopaque,
    address: net.IpAddress,
    options: net.IpAddress.ListenOptions,
) net.IpAddress.ListenError!net.Server {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = address;
    _ = options;
    @panic("TODO");
}
fn netAccept(userdata: ?*anyopaque, server: net.Socket.Handle) net.Server.AcceptError!net.Stream {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = server;
    @panic("TODO");
}
fn netBindIp(
    userdata: ?*anyopaque,
    address: *const net.IpAddress,
    options: net.IpAddress.BindOptions,
) net.IpAddress.BindError!net.Socket {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    const family = Io.Threaded.posixAddressFamily(address);
    const socket_fd = try openSocketPosix(k, family, options);
    errdefer std.posix.close(socket_fd);
    var storage: Io.Threaded.PosixAddress = undefined;
    var addr_len = Io.Threaded.addressToPosix(address, &storage);
    try posixBind(k, socket_fd, &storage.any, addr_len);
    try posixGetSockName(k, socket_fd, &storage.any, &addr_len);
    return .{
        .handle = socket_fd,
        .address = Io.Threaded.addressFromPosix(&storage),
    };
}
fn netConnectIp(userdata: ?*anyopaque, address: *const net.IpAddress, options: net.IpAddress.ConnectOptions) net.IpAddress.ConnectError!net.Stream {
    if (options.timeout != .none) @panic("TODO");
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    const family = Io.Threaded.posixAddressFamily(address);
    const socket_fd = try openSocketPosix(k, family, .{
        .mode = options.mode,
        .protocol = options.protocol,
    });
    errdefer posix.close(socket_fd);
    var storage: Io.Threaded.PosixAddress = undefined;
    var addr_len = Io.Threaded.addressToPosix(address, &storage);
    try posixConnect(k, socket_fd, &storage.any, addr_len);
    try posixGetSockName(k, socket_fd, &storage.any, &addr_len);
    return .{ .socket = .{
        .handle = socket_fd,
        .address = Io.Threaded.addressFromPosix(&storage),
    } };
}

fn posixConnect(k: *Kqueue, socket_fd: posix.socket_t, addr: *const posix.sockaddr, addr_len: posix.socklen_t) !void {
    while (true) {
        try k.checkCancel();
        switch (posix.errno(posix.system.connect(socket_fd, addr, addr_len))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,
            .AGAIN => @panic("TODO"),
            .INPROGRESS => return, // Due to TCP fast open, we find out possible error later.

            .ADDRNOTAVAIL => return error.AddressUnavailable,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .ALREADY => return error.ConnectionPending,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .CONNREFUSED => return error.ConnectionRefused,
            .CONNRESET => return error.ConnectionResetByPeer,
            .FAULT => |err| return errnoBug(err),
            .ISCONN => |err| return errnoBug(err),
            .HOSTUNREACH => return error.HostUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTSOCK => |err| return errnoBug(err),
            .PROTOTYPE => |err| return errnoBug(err),
            .TIMEDOUT => return error.Timeout,
            .CONNABORTED => |err| return errnoBug(err),
            .ACCES => return error.AccessDenied,
            .PERM => |err| return errnoBug(err),
            .NOENT => |err| return errnoBug(err),
            .NETDOWN => return error.NetworkDown,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn netListenUnix(
    userdata: ?*anyopaque,
    unix_address: *const net.UnixAddress,
    options: net.UnixAddress.ListenOptions,
) net.UnixAddress.ListenError!net.Socket.Handle {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = unix_address;
    _ = options;
    @panic("TODO");
}
fn netConnectUnix(
    userdata: ?*anyopaque,
    unix_address: *const net.UnixAddress,
) net.UnixAddress.ConnectError!net.Socket.Handle {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = unix_address;
    @panic("TODO");
}

fn netSend(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    outgoing_messages: []net.OutgoingMessage,
    flags: net.SendFlags,
) struct { ?net.Socket.SendError, usize } {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));

    const posix_flags: u32 =
        @as(u32, if (@hasDecl(posix.MSG, "CONFIRM") and flags.confirm) posix.MSG.CONFIRM else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "DONTROUTE") and flags.dont_route) posix.MSG.DONTROUTE else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "EOR") and flags.eor) posix.MSG.EOR else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "OOB") and flags.oob) posix.MSG.OOB else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "FASTOPEN") and flags.fastopen) posix.MSG.FASTOPEN else 0) |
        posix.MSG.NOSIGNAL;

    for (outgoing_messages, 0..) |*msg, i| {
        netSendOne(k, handle, msg, posix_flags) catch |err| return .{ err, i };
    }

    return .{ null, outgoing_messages.len };
}

fn netSendOne(
    k: *Kqueue,
    handle: net.Socket.Handle,
    message: *net.OutgoingMessage,
    flags: u32,
) net.Socket.SendError!void {
    var addr: Io.Threaded.PosixAddress = undefined;
    var iovec: posix.iovec_const = .{ .base = @constCast(message.data_ptr), .len = message.data_len };
    const msg: posix.msghdr_const = .{
        .name = &addr.any,
        .namelen = Io.Threaded.addressToPosix(message.address, &addr),
        .iov = (&iovec)[0..1],
        .iovlen = 1,
        // OS returns EINVAL if this pointer is invalid even if controllen is zero.
        .control = if (message.control.len == 0) null else @constCast(message.control.ptr),
        .controllen = @intCast(message.control.len),
        .flags = 0,
    };
    while (true) {
        try k.checkCancel();
        const rc = posix.system.sendmsg(handle, &msg, flags);
        switch (posix.errno(rc)) {
            .SUCCESS => {
                message.data_len = @intCast(rc);
                return;
            },
            .INTR => continue,
            .CANCELED => return error.Canceled,
            .AGAIN => @panic("TODO register kevent"),

            .ACCES => return error.AccessDenied,
            .ALREADY => return error.FastOpenAlreadyInProgress,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .CONNRESET => return error.ConnectionResetByPeer,
            .DESTADDRREQ => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err),
            .ISCONN => |err| return errnoBug(err),
            .MSGSIZE => return error.MessageOversize,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTSOCK => |err| return errnoBug(err),
            .OPNOTSUPP => |err| return errnoBug(err),
            .PIPE => return error.SocketUnconnected,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .HOSTUNREACH => return error.HostUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTCONN => return error.SocketUnconnected,
            .NETDOWN => return error.NetworkDown,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn netReceive(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    message_buffer: []net.IncomingMessage,
    data_buffer: []u8,
    flags: net.ReceiveFlags,
    timeout: Io.Timeout,
) struct { ?net.Socket.ReceiveTimeoutError, usize } {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = handle;
    _ = message_buffer;
    _ = data_buffer;
    _ = flags;
    _ = timeout;
    @panic("TODO");
}

fn netRead(userdata: ?*anyopaque, fd: net.Socket.Handle, data: [][]u8) net.Stream.Reader.Error!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));

    var iovecs_buffer: [max_iovecs_len]posix.iovec = undefined;
    var i: usize = 0;
    for (data) |buf| {
        if (iovecs_buffer.len - i == 0) break;
        if (buf.len != 0) {
            iovecs_buffer[i] = .{ .base = buf.ptr, .len = buf.len };
            i += 1;
        }
    }
    const dest = iovecs_buffer[0..i];
    assert(dest[0].len > 0);

    while (true) {
        try k.checkCancel();
        const rc = posix.system.readv(fd, dest.ptr, @intCast(dest.len));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .CANCELED => return error.Canceled,
            .AGAIN => {
                const thread: *Thread = .current();
                const fiber = thread.currentFiber();
                const ident: u32 = @bitCast(fd);
                const filter = std.c.EVFILT.READ;
                const gop = thread.wait_queues.getOrPut(k.gpa, .{
                    .ident = ident,
                    .filter = filter,
                }) catch return error.SystemResources;
                if (gop.found_existing) {
                    const tail_fiber = gop.value_ptr.*;
                    assert(tail_fiber.queue_next == null);
                    tail_fiber.queue_next = fiber;
                    gop.value_ptr.* = fiber;
                } else {
                    gop.value_ptr.* = fiber;
                    const changes = [_]posix.Kevent{
                        .{
                            .ident = ident,
                            .filter = filter,
                            .flags = std.c.EV.ADD | std.c.EV.ONESHOT,
                            .fflags = 0,
                            .data = 0,
                            .udata = @intFromPtr(fiber),
                        },
                    };
                    assert(0 == (posix.kevent(thread.kq_fd, &changes, &.{}, null) catch |err| {
                        @panic(@errorName(err)); // TODO
                    }));
                }
                yield(k, null, .nothing);
                continue;
            },

            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.Timeout,
            .PIPE => return error.SocketUnconnected,
            .NETDOWN => return error.NetworkDown,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn netWrite(userdata: ?*anyopaque, dest: net.Socket.Handle, header: []const u8, data: []const []const u8, splat: usize) net.Stream.Writer.Error!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dest;
    _ = header;
    _ = data;
    _ = splat;
    @panic("TODO");
}
fn netClose(userdata: ?*anyopaque, handle: net.Socket.Handle) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = handle;
    @panic("TODO");
}
fn netInterfaceNameResolve(
    userdata: ?*anyopaque,
    name: *const net.Interface.Name,
) net.Interface.Name.ResolveError!net.Interface {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = name;
    @panic("TODO");
}
fn netInterfaceName(userdata: ?*anyopaque, interface: net.Interface) net.Interface.NameError!net.Interface.Name {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = interface;
    @panic("TODO");
}
fn netLookup(
    userdata: ?*anyopaque,
    host_name: net.HostName,
    result: *Io.Queue(net.HostName.LookupResult),
    options: net.HostName.LookupOptions,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = host_name;
    _ = result;
    _ = options;
    @panic("TODO");
}

fn openSocketPosix(
    k: *Kqueue,
    family: posix.sa_family_t,
    options: IpAddress.BindOptions,
) error{
    AddressFamilyUnsupported,
    ProtocolUnsupportedBySystem,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    SystemResources,
    ProtocolUnsupportedByAddressFamily,
    SocketModeUnsupported,
    OptionUnsupported,
    Unexpected,
    Canceled,
}!posix.socket_t {
    const mode = Io.Threaded.posixSocketMode(options.mode);
    const protocol = Io.Threaded.posixProtocol(options.protocol);
    const socket_fd = while (true) {
        try k.checkCancel();
        const flags: u32 = mode | if (Io.Threaded.socket_flags_unsupported) 0 else posix.SOCK.CLOEXEC;
        const socket_rc = posix.system.socket(family, flags, protocol);
        switch (posix.errno(socket_rc)) {
            .SUCCESS => {
                const fd: posix.fd_t = @intCast(socket_rc);
                errdefer posix.close(fd);
                if (Io.Threaded.socket_flags_unsupported) {
                    while (true) {
                        try k.checkCancel();
                        switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC)))) {
                            .SUCCESS => break,
                            .INTR => continue,
                            .CANCELED => return error.Canceled,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    }

                    var fl_flags: usize = while (true) {
                        try k.checkCancel();
                        const rc = posix.system.fcntl(fd, posix.F.GETFL, @as(usize, 0));
                        switch (posix.errno(rc)) {
                            .SUCCESS => break @intCast(rc),
                            .INTR => continue,
                            .CANCELED => return error.Canceled,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    };
                    fl_flags |= @as(usize, 1 << @bitOffsetOf(posix.O, "NONBLOCK"));
                    while (true) {
                        try k.checkCancel();
                        switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFL, fl_flags))) {
                            .SUCCESS => break,
                            .INTR => continue,
                            .CANCELED => return error.Canceled,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    }
                }
                break fd;
            },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .INVAL => return error.ProtocolUnsupportedBySystem,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .PROTONOSUPPORT => return error.ProtocolUnsupportedByAddressFamily,
            .PROTOTYPE => return error.SocketModeUnsupported,
            else => |err| return posix.unexpectedErrno(err),
        }
    };
    errdefer posix.close(socket_fd);

    if (options.ip6_only) {
        if (posix.IPV6 == void) return error.OptionUnsupported;
        try setSocketOption(k, socket_fd, posix.IPPROTO.IPV6, posix.IPV6.V6ONLY, 0);
    }

    return socket_fd;
}

fn posixBind(
    k: *Kqueue,
    socket_fd: posix.socket_t,
    addr: *const posix.sockaddr,
    addr_len: posix.socklen_t,
) !void {
    while (true) {
        try k.checkCancel();
        switch (posix.errno(posix.system.bind(socket_fd, addr, addr_len))) {
            .SUCCESS => break,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ADDRINUSE => return error.AddressInUse,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .INVAL => |err| return errnoBug(err), // invalid parameters
            .NOTSOCK => |err| return errnoBug(err), // invalid `sockfd`
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .ADDRNOTAVAIL => return error.AddressUnavailable,
            .FAULT => |err| return errnoBug(err), // invalid `addr` pointer
            .NOMEM => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn posixGetSockName(k: *Kqueue, socket_fd: posix.fd_t, addr: *posix.sockaddr, addr_len: *posix.socklen_t) !void {
    while (true) {
        try k.checkCancel();
        switch (posix.errno(posix.system.getsockname(socket_fd, addr, addr_len))) {
            .SUCCESS => break,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err), // invalid parameters
            .NOTSOCK => |err| return errnoBug(err), // always a race condition
            .NOBUFS => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn setSocketOption(k: *Kqueue, fd: posix.fd_t, level: i32, opt_name: u32, option: u32) !void {
    const o: []const u8 = @ptrCast(&option);
    while (true) {
        try k.checkCancel();
        switch (posix.errno(posix.system.setsockopt(fd, level, opt_name, o.ptr, @intCast(o.len)))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOTSOCK => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn checkCancel(k: *Kqueue) error{Canceled}!void {
    if (cancelRequested(k)) return error.Canceled;
}

const Condition = struct {
    tail: *Fiber,
    event: union(enum) {
        queued,
        wake: Io.Condition.Wake,
    },
};
