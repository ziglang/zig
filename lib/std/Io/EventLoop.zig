const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const EventLoop = @This();
const Alignment = std.mem.Alignment;
const IoUring = std.os.linux.IoUring;

gpa: Allocator,
mutex: std.Thread.Mutex,
queue: std.DoublyLinkedList(void),
/// Atomic copy of queue.len
queue_len: u32,
free: std.DoublyLinkedList(void),
main_fiber: Fiber,
idle_count: usize,
threads: std.ArrayListUnmanaged(Thread),
exiting: bool,

threadlocal var thread_index: u32 = undefined;

/// Empirically saw >128KB being used by the self-hosted backend to panic.
const idle_stack_size = 256 * 1024;

const io_uring_entries = 64;

const Thread = struct {
    thread: std.Thread,
    idle_context: Context,
    current_context: *Context,
    io_uring: IoUring,

    fn currentFiber(thread: *Thread) *Fiber {
        return @fieldParentPtr("context", thread.current_context);
    }
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
            .createFile = createFile,
            .openFile = openFile,
            .closeFile = closeFile,
            .read = read,
            .write = write,
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
        .mutex = .{},
        .queue = .{},
        .queue_len = 0,
        .free = .{},
        .main_fiber = undefined,
        .idle_count = 0,
        .threads = .initBuffer(@ptrCast(allocated_slice[0..threads_size])),
        .exiting = false,
    };
    thread_index = 0;
    const main_thread = el.threads.addOneAssumeCapacity();
    main_thread.io_uring = try IoUring.init(io_uring_entries, 0);
    const idle_stack_end: [*]usize = @alignCast(@ptrCast(allocated_slice[idle_stack_end_offset..].ptr));
    (idle_stack_end - 1)[0..1].* = .{@intFromPtr(el)};
    main_thread.idle_context = .{
        .rsp = @intFromPtr(idle_stack_end - 1),
        .rbp = 0,
        .rip = @intFromPtr(&mainIdleEntry),
    };
    std.log.debug("created main idle {*}", .{&main_thread.idle_context});
    std.log.debug("created main {*}", .{&el.main_fiber});
    main_thread.current_context = &el.main_fiber.context;
}

pub fn deinit(el: *EventLoop) void {
    assert(el.queue.len == 0); // pending async
    el.yield(null, .exit);
    while (el.free.pop()) |free_node| {
        const free_fiber: *Fiber = @alignCast(@fieldParentPtr("queue_node", free_node));
        el.gpa.free(free_fiber.allocatedSlice());
    }
    const idle_stack_end_offset = std.mem.alignForward(usize, el.threads.capacity * @sizeOf(Thread) + idle_stack_size, std.heap.page_size_max);
    const allocated_ptr: [*]align(@alignOf(Thread)) u8 = @alignCast(@ptrCast(el.threads.items.ptr));
    for (el.threads.items[1..]) |*thread| thread.thread.join();
    el.gpa.free(allocated_ptr[0..idle_stack_end_offset]);
    el.* = undefined;
}

fn yield(el: *EventLoop, optional_fiber: ?*Fiber, pending_task: SwitchMessage.PendingTask) void {
    const thread: *Thread = &el.threads.items[thread_index];
    const ready_context: *Context = ready_context: {
        const ready_fiber: *Fiber = optional_fiber orelse if (ready_node: {
            el.mutex.lock();
            defer el.mutex.unlock();
            const expected_queue_len = std.math.lossyCast(u32, el.queue.len);
            const ready_node = el.queue.pop();
            _ = @cmpxchgStrong(u32, &el.queue_len, expected_queue_len, std.math.lossyCast(u32, el.queue.len), .monotonic, .monotonic);
            break :ready_node ready_node;
        }) |ready_node|
            @alignCast(@fieldParentPtr("queue_node", ready_node))
        else
            break :ready_context &thread.idle_context;
        break :ready_context &ready_fiber.context;
    };
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

fn schedule(el: *EventLoop, fiber: *Fiber) void {
    std.log.debug("scheduling {*}", .{fiber});
    if (idle_count: {
        el.mutex.lock();
        defer el.mutex.unlock();
        const expected_queue_len = std.math.lossyCast(u32, el.queue.len);
        el.queue.append(&fiber.queue_node);
        _ = @cmpxchgStrong(u32, &el.queue_len, expected_queue_len, std.math.lossyCast(u32, el.queue.len), .monotonic, .monotonic);
        break :idle_count el.idle_count;
    } > 0) {
        _ = std.os.linux.futex2_wake(&el.queue_len, std.math.maxInt(u32), 1, std.os.linux.FUTEX2.SIZE_U32 | std.os.linux.FUTEX2.PRIVATE); // TODO: io_uring
        return;
    }
    if (el.threads.items.len == el.threads.capacity) return;
    const thread = el.threads.addOneAssumeCapacity();
    thread.thread = std.Thread.spawn(.{
        .stack_size = idle_stack_size,
        .allocator = el.gpa,
    }, threadEntry, .{ el, el.threads.items.len - 1 }) catch {
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
    el.idle();
    el.yield(&el.main_fiber, .nothing);
    unreachable; // switched to dead fiber
}

fn threadEntry(el: *EventLoop, index: usize) void {
    thread_index = @intCast(index);
    const thread: *Thread = &el.threads.items[index];
    std.log.debug("created thread idle {*}", .{&thread.idle_context});
    thread.io_uring = IoUring.init(io_uring_entries, 0) catch |err| {
        std.log.warn("exiting worker thread during init due to io_uring init failure: {s}", .{@errorName(err)});
        return;
    };
    thread.current_context = &thread.idle_context;
    el.idle();
}

const CompletionKey = enum(u64) {
    queue_len_futex_wait = 1,
    _,
};

fn idle(el: *EventLoop) void {
    const thread: *Thread = &el.threads.items[thread_index];
    const iou = &thread.io_uring;
    var cqes_buffer: [io_uring_entries]std.os.linux.io_uring_cqe = undefined;
    var queue_len_futex_is_scheduled: bool = false;

    while (true) {
        el.yield(null, .nothing);
        if (@atomicLoad(bool, &el.exiting, .acquire)) return;
        if (!queue_len_futex_is_scheduled) {
            const sqe = getSqe(&thread.io_uring);
            sqe.prep_rw(.FUTEX_WAIT, std.os.linux.FUTEX2.SIZE_U32 | std.os.linux.FUTEX2.PRIVATE, @intFromPtr(&el.queue_len), 0, 0);
            sqe.addr3 = std.math.maxInt(u32);
            sqe.user_data = @intFromEnum(CompletionKey.queue_len_futex_wait);
            queue_len_futex_is_scheduled = true;
        }
        _ = iou.submit_and_wait(1) catch |err| switch (err) {
            error.SignalInterrupt => std.log.debug("submit_and_wait: SignalInterrupt", .{}),
            else => @panic(@errorName(err)),
        };
        for (cqes_buffer[0 .. iou.copy_cqes(&cqes_buffer, 1) catch |err| switch (err) {
            error.SignalInterrupt => cqes_len: {
                std.log.debug("copy_cqes: SignalInterrupt", .{});
                break :cqes_len 0;
            },
            else => @panic(@errorName(err)),
        }]) |cqe| switch (@as(CompletionKey, @enumFromInt(cqe.user_data))) {
            .queue_len_futex_wait => {
                switch (errno(cqe.res)) {
                    .SUCCESS, .AGAIN => {},
                    .INVAL => unreachable,
                    else => |err| {
                        std.posix.unexpectedErrno(err) catch {};
                        @panic("unexpected");
                    },
                }
                std.log.debug("{*} woken up with queue size of {d}", .{
                    &thread.idle_context,
                    @atomicLoad(u32, &el.queue_len, .unordered),
                });
                queue_len_futex_is_scheduled = false;
            },
            _ => {
                const fiber: *Fiber = @ptrFromInt(cqe.user_data);
                const res: *i32 = @ptrCast(@alignCast(fiber.resultPointer()));
                res.* = cqe.res;
                el.schedule(fiber);
            },
        };
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
        register_awaiter: *?*Fiber,
        exit,
    };

    fn handle(message: *const SwitchMessage, el: *EventLoop) void {
        const thread: *Thread = &el.threads.items[thread_index];
        thread.current_context = message.contexts.ready;
        switch (message.pending_task) {
            .nothing => {},
            .register_awaiter => |awaiter| {
                const prev_fiber: *Fiber = @alignCast(@fieldParentPtr("context", message.contexts.prev));
                if (@atomicRmw(?*Fiber, awaiter, .Xchg, prev_fiber, .acq_rel) == Fiber.finished) el.schedule(prev_fiber);
            },
            .exit => {
                @atomicStore(bool, &el.exiting, true, .unordered);
                @atomicStore(u32, &el.queue_len, std.math.maxInt(u32), .release);
                _ = std.os.linux.futex2_wake(&el.queue_len, std.math.maxInt(u32), std.math.maxInt(i32), std.os.linux.FUTEX2.SIZE_U32 | std.os.linux.FUTEX2.PRIVATE); // TODO: use io_uring
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
        closure.event_loop.yield(awaiter, .nothing);
        unreachable; // switched to dead fiber
    }
};

pub fn @"await"(userdata: ?*anyopaque, any_future: *std.Io.AnyFuture, result: []u8) void {
    const event_loop: *EventLoop = @alignCast(@ptrCast(userdata));
    const future_fiber: *Fiber = @alignCast(@ptrCast(any_future));
    if (@atomicLoad(?*Fiber, &future_fiber.awaiter, .acquire) != Fiber.finished) event_loop.yield(null, .{ .register_awaiter = &future_fiber.awaiter });
    @memcpy(result, future_fiber.resultPointer());
    event_loop.recycle(future_fiber);
}

pub fn createFile(userdata: ?*anyopaque, dir: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.CreateFlags) std.fs.File.OpenError!std.fs.File {
    const el: *EventLoop = @ptrCast(@alignCast(userdata));

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

    const thread: *Thread = &el.threads.items[thread_index];
    const iou = &thread.io_uring;
    const sqe = getSqe(iou);
    const fiber = thread.currentFiber();

    sqe.prep_openat(dir.fd, &sub_path_c, os_flags, flags.mode);
    sqe.user_data = @intFromPtr(fiber);

    el.yield(null, .nothing);

    const result: *i32 = @alignCast(@ptrCast(fiber.resultPointer()[0..@sizeOf(posix.fd_t)]));
    const rc = result.*;
    switch (errno(rc)) {
        .SUCCESS => return .{ .handle = rc },
        .INTR => @panic("TODO is this reachable?"),
        .CANCELED => @panic("TODO figure out how this error code fits into things"),

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

pub fn openFile(userdata: ?*anyopaque, dir: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.OpenFlags) std.fs.File.OpenError!std.fs.File {
    const el: *EventLoop = @ptrCast(@alignCast(userdata));

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

    const thread: *Thread = &el.threads.items[thread_index];
    const iou = &thread.io_uring;
    const sqe = getSqe(iou);
    const fiber = thread.currentFiber();

    sqe.prep_openat(dir.fd, &sub_path_c, os_flags, 0);
    sqe.user_data = @intFromPtr(fiber);

    el.yield(null, .nothing);

    const result: *i32 = @alignCast(@ptrCast(fiber.resultPointer()[0..@sizeOf(posix.fd_t)]));
    const rc = result.*;
    switch (errno(rc)) {
        .SUCCESS => return .{ .handle = rc },
        .INTR => @panic("TODO is this reachable?"),
        .CANCELED => @panic("TODO figure out how this error code fits into things"),

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

fn errno(signed: i32) std.posix.E {
    const int = if (signed > -4096 and signed < 0) -signed else 0;
    return @enumFromInt(int);
}

fn getSqe(iou: *IoUring) *std.os.linux.io_uring_sqe {
    return iou.get_sqe() catch @panic("TODO: handle submission queue full");
}

pub fn closeFile(userdata: ?*anyopaque, file: std.fs.File) void {
    const el: *EventLoop = @ptrCast(@alignCast(userdata));

    const posix = std.posix;

    const thread: *Thread = &el.threads.items[thread_index];
    const iou = &thread.io_uring;
    const sqe = getSqe(iou);
    const fiber = thread.currentFiber();

    sqe.prep_close(file.handle);
    sqe.user_data = @intFromPtr(fiber);

    el.yield(null, .nothing);

    const result: *i32 = @alignCast(@ptrCast(fiber.resultPointer()[0..@sizeOf(posix.fd_t)]));
    const rc = result.*;
    switch (errno(rc)) {
        .SUCCESS => return,
        .INTR => @panic("TODO is this reachable?"),
        .CANCELED => @panic("TODO figure out how this error code fits into things"),

        .BADF => unreachable, // Always a race condition.
        else => return,
    }
}

pub fn read(userdata: ?*anyopaque, file: std.fs.File, buffer: []u8) std.fs.File.ReadError!usize {
    const el: *EventLoop = @ptrCast(@alignCast(userdata));

    const posix = std.posix;

    const thread: *Thread = &el.threads.items[thread_index];
    const iou = &thread.io_uring;
    const sqe = getSqe(iou);
    const fiber = thread.currentFiber();

    sqe.prep_read(file.handle, buffer, std.math.maxInt(u64));
    sqe.user_data = @intFromPtr(fiber);

    el.yield(null, .nothing);

    const result: *i32 = @alignCast(@ptrCast(fiber.resultPointer()[0..@sizeOf(posix.fd_t)]));
    const rc = result.*;
    switch (errno(rc)) {
        .SUCCESS => return @as(u32, @bitCast(rc)),
        .INTR => @panic("TODO is this reachable?"),
        .CANCELED => @panic("TODO figure out how this error code fits into things"),

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
        else => |err| return posix.unexpectedErrno(err),
    }
}

pub fn write(userdata: ?*anyopaque, file: std.fs.File, buffer: []const u8) std.fs.File.WriteError!usize {
    const el: *EventLoop = @ptrCast(@alignCast(userdata));

    const posix = std.posix;

    const thread: *Thread = &el.threads.items[thread_index];
    const iou = &thread.io_uring;
    const sqe = getSqe(iou);
    const fiber = thread.currentFiber();

    sqe.prep_write(file.handle, buffer, std.math.maxInt(u64));
    sqe.user_data = @intFromPtr(fiber);

    el.yield(null, .nothing);

    const result: *i32 = @alignCast(@ptrCast(fiber.resultPointer()[0..@sizeOf(posix.fd_t)]));
    const rc = result.*;
    switch (errno(rc)) {
        .SUCCESS => return @as(u32, @bitCast(rc)),
        .INTR => @panic("TODO is this reachable?"),
        .CANCELED => @panic("TODO figure out how this error code fits into things"),

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
        .CONNRESET => return error.ConnectionResetByPeer,
        .BUSY => return error.DeviceBusy,
        .NXIO => return error.NoDevice,
        .MSGSIZE => return error.MessageTooBig,
        else => |err| return posix.unexpectedErrno(err),
    }
}
