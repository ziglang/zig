const Threaded = @This();

const builtin = @import("builtin");
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;
const windows = std.os.windows;
const ws2_32 = std.os.windows.ws2_32;
const is_debug = builtin.mode == .Debug;

const std = @import("../std.zig");
const Io = std.Io;
const net = std.Io.net;
const HostName = std.Io.net.HostName;
const IpAddress = std.Io.net.IpAddress;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const assert = std.debug.assert;
const posix = std.posix;

/// Thread-safe.
allocator: Allocator,
mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
run_queue: std.SinglyLinkedList = .{},
join_requested: bool = false,
stack_size: usize,
/// All threads are spawned detached; this is how we wait until they all exit.
wait_group: std.Thread.WaitGroup = .{},
/// Maximum thread pool size (excluding main thread) when dispatching async
/// tasks. Until this limit, calls to `Io.async` when all threads are busy will
/// cause a new thread to be spawned and permanently added to the pool. After
/// this limit, calls to `Io.async` when all threads are busy run the task
/// immediately.
///
/// Defaults to a number equal to logical CPU cores.
///
/// Protected by `mutex` once the I/O instance is already in use. See
/// `setAsyncLimit`.
async_limit: Io.Limit,
/// Maximum thread pool size (excluding main thread) for dispatching concurrent
/// tasks. Until this limit, calls to `Io.concurrent` will increase the thread
/// pool size.
///
/// concurrent tasks. After this number, calls to `Io.concurrent` return
/// `error.ConcurrencyUnavailable`.
concurrent_limit: Io.Limit = .unlimited,
/// Error from calling `std.Thread.getCpuCount` in `init`.
cpu_count_error: ?std.Thread.CpuCountError,
/// Number of threads that are unavailable to take tasks. To calculate
/// available count, subtract this from either `async_limit` or
/// `concurrent_limit`.
busy_count: usize = 0,

wsa: if (is_windows) Wsa else struct {} = .{},

have_signal_handler: bool,
old_sig_io: if (have_sig_io) posix.Sigaction else void,
old_sig_pipe: if (have_sig_pipe) posix.Sigaction else void,

threadlocal var current_closure: ?*Closure = null;

const max_iovecs_len = 8;
const splat_buffer_size = 64;

comptime {
    if (@TypeOf(posix.IOV_MAX) != void) assert(max_iovecs_len <= posix.IOV_MAX);
}

const CancelId = enum(usize) {
    none = 0,
    canceling = std.math.maxInt(usize),
    _,

    const ThreadId = if (std.Thread.use_pthreads) std.c.pthread_t else std.Thread.Id;

    fn currentThread() CancelId {
        if (std.Thread.use_pthreads) {
            return @enumFromInt(@intFromPtr(std.c.pthread_self()));
        } else {
            return @enumFromInt(std.Thread.getCurrentId());
        }
    }

    fn toThreadId(cancel_id: CancelId) ThreadId {
        if (std.Thread.use_pthreads) {
            return @ptrFromInt(@intFromEnum(cancel_id));
        } else {
            return @intCast(@intFromEnum(cancel_id));
        }
    }
};

const Closure = struct {
    start: Start,
    node: std.SinglyLinkedList.Node = .{},
    cancel_tid: CancelId,

    const Start = *const fn (*Closure) void;

    fn requestCancel(closure: *Closure) void {
        switch (@atomicRmw(CancelId, &closure.cancel_tid, .Xchg, .canceling, .acq_rel)) {
            .none, .canceling => {},
            else => |tid| {
                if (std.Thread.use_pthreads) {
                    const rc = std.c.pthread_kill(tid.toThreadId(), .IO);
                    if (is_debug) assert(rc == 0);
                } else if (native_os == .linux) {
                    _ = std.os.linux.tgkill(std.os.linux.getpid(), @bitCast(tid.toThreadId()), .IO);
                }
            },
        }
    }
};

/// Related:
/// * `init_single_threaded`
pub fn init(
    /// Must be threadsafe. Only used for the following functions:
    /// * `Io.VTable.async`
    /// * `Io.VTable.concurrent`
    /// * `Io.VTable.groupAsync`
    /// * `Io.VTable.groupConcurrent`
    /// If these functions are avoided, then `Allocator.failing` may be passed
    /// here.
    gpa: Allocator,
) Threaded {
    if (builtin.single_threaded) return .init_single_threaded;

    const cpu_count = std.Thread.getCpuCount();

    var t: Threaded = .{
        .allocator = gpa,
        .stack_size = std.Thread.SpawnConfig.default_stack_size,
        .async_limit = if (cpu_count) |n| .limited(n - 1) else |_| .nothing,
        .cpu_count_error = if (cpu_count) |_| null else |e| e,
        .old_sig_io = undefined,
        .old_sig_pipe = undefined,
        .have_signal_handler = false,
    };

    if (posix.Sigaction != void) {
        // This causes sending `posix.SIG.IO` to thread to interrupt blocking
        // syscalls, returning `posix.E.INTR`.
        const act: posix.Sigaction = .{
            .handler = .{ .handler = doNothingSignalHandler },
            .mask = posix.sigemptyset(),
            .flags = 0,
        };
        if (have_sig_io) posix.sigaction(.IO, &act, &t.old_sig_io);
        if (have_sig_pipe) posix.sigaction(.PIPE, &act, &t.old_sig_pipe);
        t.have_signal_handler = true;
    }

    return t;
}

/// Statically initialize such that calls to `Io.VTable.concurrent` will fail
/// with `error.ConcurrencyUnavailable`.
///
/// When initialized this way:
/// * cancel requests have no effect.
/// * `deinit` is safe, but unnecessary to call.
pub const init_single_threaded: Threaded = .{
    .allocator = .failing,
    .stack_size = std.Thread.SpawnConfig.default_stack_size,
    .async_limit = .nothing,
    .cpu_count_error = null,
    .concurrent_limit = .nothing,
    .old_sig_io = undefined,
    .old_sig_pipe = undefined,
    .have_signal_handler = false,
};

pub fn setAsyncLimit(t: *Threaded, new_limit: Io.Limit) void {
    t.mutex.lock();
    defer t.mutex.unlock();
    t.async_limit = new_limit;
}

pub fn deinit(t: *Threaded) void {
    t.join();
    if (is_windows and t.wsa.status == .initialized) {
        if (ws2_32.WSACleanup() != 0) recoverableOsBugDetected();
    }
    if (posix.Sigaction != void and t.have_signal_handler) {
        if (have_sig_io) posix.sigaction(.IO, &t.old_sig_io, null);
        if (have_sig_pipe) posix.sigaction(.PIPE, &t.old_sig_pipe, null);
    }
    t.* = undefined;
}

fn join(t: *Threaded) void {
    if (builtin.single_threaded) return;
    {
        t.mutex.lock();
        defer t.mutex.unlock();
        t.join_requested = true;
    }
    t.cond.broadcast();
    t.wait_group.wait();
}

fn worker(t: *Threaded) void {
    defer t.wait_group.finish();

    t.mutex.lock();
    defer t.mutex.unlock();

    while (true) {
        while (t.run_queue.popFirst()) |closure_node| {
            t.mutex.unlock();
            const closure: *Closure = @fieldParentPtr("node", closure_node);
            closure.start(closure);
            t.mutex.lock();
            t.busy_count -= 1;
        }
        if (t.join_requested) break;
        t.cond.wait(&t.mutex);
    }
}

pub fn io(t: *Threaded) Io {
    return .{
        .userdata = t,
        .vtable = &.{
            .async = async,
            .concurrent = concurrent,
            .await = await,
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .select = select,

            .groupAsync = groupAsync,
            .groupConcurrent = groupConcurrent,
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

            .netListenIp = switch (native_os) {
                .windows => netListenIpWindows,
                else => netListenIpPosix,
            },
            .netListenUnix = switch (native_os) {
                .windows => netListenUnixWindows,
                else => netListenUnixPosix,
            },
            .netAccept = switch (native_os) {
                .windows => netAcceptWindows,
                else => netAcceptPosix,
            },
            .netBindIp = switch (native_os) {
                .windows => netBindIpWindows,
                else => netBindIpPosix,
            },
            .netConnectIp = switch (native_os) {
                .windows => netConnectIpWindows,
                else => netConnectIpPosix,
            },
            .netConnectUnix = switch (native_os) {
                .windows => netConnectUnixWindows,
                else => netConnectUnixPosix,
            },
            .netClose = netClose,
            .netRead = switch (native_os) {
                .windows => netReadWindows,
                else => netReadPosix,
            },
            .netWrite = switch (native_os) {
                .windows => netWriteWindows,
                else => netWritePosix,
            },
            .netSend = switch (native_os) {
                .windows => netSendWindows,
                else => netSendPosix,
            },
            .netReceive = switch (native_os) {
                .windows => netReceiveWindows,
                else => netReceivePosix,
            },
            .netInterfaceNameResolve = netInterfaceNameResolve,
            .netInterfaceName = netInterfaceName,
            .netLookup = netLookup,
        },
    };
}

/// Same as `io` but disables all networking functionality, which has
/// an additional dependency on Windows (ws2_32).
pub fn ioBasic(t: *Threaded) Io {
    return .{
        .userdata = t,
        .vtable = &.{
            .async = async,
            .concurrent = concurrent,
            .await = await,
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .select = select,

            .groupAsync = groupAsync,
            .groupConcurrent = groupConcurrent,
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

            .netListenIp = netListenIpUnavailable,
            .netListenUnix = netListenUnixUnavailable,
            .netAccept = netAcceptUnavailable,
            .netBindIp = netBindIpUnavailable,
            .netConnectIp = netConnectIpUnavailable,
            .netConnectUnix = netConnectUnixUnavailable,
            .netClose = netCloseUnavailable,
            .netRead = netReadUnavailable,
            .netWrite = netWriteUnavailable,
            .netSend = netSendUnavailable,
            .netReceive = netReceiveUnavailable,
            .netInterfaceNameResolve = netInterfaceNameResolveUnavailable,
            .netInterfaceName = netInterfaceNameUnavailable,
            .netLookup = netLookupUnavailable,
        },
    };
}

pub const socket_flags_unsupported = native_os.isDarwin() or native_os == .haiku;
const have_accept4 = !socket_flags_unsupported;
const have_flock_open_flags = @hasField(posix.O, "EXLOCK");
const have_networking = native_os != .wasi;
const have_flock = @TypeOf(posix.system.flock) != void;
const have_sendmmsg = native_os == .linux;
const have_futex = switch (builtin.cpu.arch) {
    .wasm32, .wasm64 => builtin.cpu.has(.wasm, .atomics),
    else => true,
};
const have_preadv = switch (native_os) {
    .windows, .haiku => false,
    else => true,
};
const have_sig_io = posix.SIG != void and @hasField(posix.SIG, "IO");
const have_sig_pipe = posix.SIG != void and @hasField(posix.SIG, "PIPE");

const openat_sym = if (posix.lfs64_abi) posix.system.openat64 else posix.system.openat;
const fstat_sym = if (posix.lfs64_abi) posix.system.fstat64 else posix.system.fstat;
const fstatat_sym = if (posix.lfs64_abi) posix.system.fstatat64 else posix.system.fstatat;
const lseek_sym = if (posix.lfs64_abi) posix.system.lseek64 else posix.system.lseek;
const preadv_sym = if (posix.lfs64_abi) posix.system.preadv64 else posix.system.preadv;

/// Trailing data:
/// 1. context
/// 2. result
const AsyncClosure = struct {
    closure: Closure,
    func: *const fn (context: *anyopaque, result: *anyopaque) void,
    reset_event: ResetEvent,
    select_condition: ?*ResetEvent,
    context_alignment: Alignment,
    result_offset: usize,
    alloc_len: usize,

    const done_reset_event: *ResetEvent = @ptrFromInt(@alignOf(ResetEvent));

    fn start(closure: *Closure) void {
        const ac: *AsyncClosure = @alignCast(@fieldParentPtr("closure", closure));
        const tid: CancelId = .currentThread();
        if (@cmpxchgStrong(CancelId, &closure.cancel_tid, .none, tid, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == .canceling);
            // Even though we already know the task is canceled, we must still
            // run the closure in order to make the return value valid and in
            // case there are side effects.
        }
        current_closure = closure;
        ac.func(ac.contextPointer(), ac.resultPointer());
        current_closure = null;

        // In case a cancel happens after successful task completion, prevents
        // signal from being delivered to the thread in `requestCancel`.
        if (@cmpxchgStrong(CancelId, &closure.cancel_tid, tid, .none, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == .canceling);
        }

        if (@atomicRmw(?*ResetEvent, &ac.select_condition, .Xchg, done_reset_event, .release)) |select_reset| {
            assert(select_reset != done_reset_event);
            select_reset.set();
        }
        ac.reset_event.set();
    }

    fn resultPointer(ac: *AsyncClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(ac);
        return base + ac.result_offset;
    }

    fn contextPointer(ac: *AsyncClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(ac);
        const context_offset = ac.context_alignment.forward(@intFromPtr(ac) + @sizeOf(AsyncClosure)) - @intFromPtr(ac);
        return base + context_offset;
    }

    fn init(
        gpa: Allocator,
        result_len: usize,
        result_alignment: Alignment,
        context: []const u8,
        context_alignment: Alignment,
        func: *const fn (context: *const anyopaque, result: *anyopaque) void,
    ) Allocator.Error!*AsyncClosure {
        const max_context_misalignment = context_alignment.toByteUnits() -| @alignOf(AsyncClosure);
        const worst_case_context_offset = context_alignment.forward(@sizeOf(AsyncClosure) + max_context_misalignment);
        const worst_case_result_offset = result_alignment.forward(worst_case_context_offset + context.len);
        const alloc_len = worst_case_result_offset + result_len;

        const ac: *AsyncClosure = @ptrCast(@alignCast(try gpa.alignedAlloc(u8, .of(AsyncClosure), alloc_len)));
        errdefer comptime unreachable;

        const actual_context_addr = context_alignment.forward(@intFromPtr(ac) + @sizeOf(AsyncClosure));
        const actual_result_addr = result_alignment.forward(actual_context_addr + context.len);
        const actual_result_offset = actual_result_addr - @intFromPtr(ac);
        ac.* = .{
            .closure = .{
                .cancel_tid = .none,
                .start = start,
            },
            .func = func,
            .context_alignment = context_alignment,
            .result_offset = actual_result_offset,
            .alloc_len = alloc_len,
            .reset_event = .unset,
            .select_condition = null,
        };
        @memcpy(ac.contextPointer()[0..context.len], context);
        return ac;
    }

    fn waitAndDeinit(ac: *AsyncClosure, t: *Threaded, result: []u8) void {
        ac.reset_event.wait(t) catch |err| switch (err) {
            error.Canceled => {
                ac.closure.requestCancel();
                ac.reset_event.waitUncancelable();
            },
        };
        @memcpy(result, ac.resultPointer()[0..result.len]);
        ac.deinit(t.allocator);
    }

    fn deinit(ac: *AsyncClosure, gpa: Allocator) void {
        const base: [*]align(@alignOf(AsyncClosure)) u8 = @ptrCast(ac);
        gpa.free(base[0..ac.alloc_len]);
    }
};

fn async(
    userdata: ?*anyopaque,
    result: []u8,
    result_alignment: Alignment,
    context: []const u8,
    context_alignment: Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*Io.AnyFuture {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    if (builtin.single_threaded) {
        start(context.ptr, result.ptr);
        return null;
    }
    const gpa = t.allocator;
    const ac = AsyncClosure.init(gpa, result.len, result_alignment, context, context_alignment, start) catch {
        start(context.ptr, result.ptr);
        return null;
    };

    t.mutex.lock();

    const busy_count = t.busy_count;

    if (busy_count >= @intFromEnum(t.async_limit)) {
        t.mutex.unlock();
        ac.deinit(gpa);
        start(context.ptr, result.ptr);
        return null;
    }

    t.busy_count = busy_count + 1;

    const pool_size = t.wait_group.value();
    if (pool_size - busy_count == 0) {
        t.wait_group.start();
        const thread = std.Thread.spawn(.{ .stack_size = t.stack_size }, worker, .{t}) catch {
            t.wait_group.finish();
            t.busy_count = busy_count;
            t.mutex.unlock();
            ac.deinit(gpa);
            start(context.ptr, result.ptr);
            return null;
        };
        thread.detach();
    }

    t.run_queue.prepend(&ac.closure.node);
    t.mutex.unlock();
    t.cond.signal();
    return @ptrCast(ac);
}

fn concurrent(
    userdata: ?*anyopaque,
    result_len: usize,
    result_alignment: Alignment,
    context: []const u8,
    context_alignment: Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) Io.ConcurrentError!*Io.AnyFuture {
    if (builtin.single_threaded) return error.ConcurrencyUnavailable;

    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const gpa = t.allocator;
    const ac = AsyncClosure.init(gpa, result_len, result_alignment, context, context_alignment, start) catch
        return error.ConcurrencyUnavailable;
    errdefer ac.deinit(gpa);

    t.mutex.lock();
    defer t.mutex.unlock();

    const busy_count = t.busy_count;

    if (busy_count >= @intFromEnum(t.concurrent_limit))
        return error.ConcurrencyUnavailable;

    t.busy_count = busy_count + 1;
    errdefer t.busy_count = busy_count;

    const pool_size = t.wait_group.value();
    if (pool_size - busy_count == 0) {
        t.wait_group.start();
        errdefer t.wait_group.finish();

        const thread = std.Thread.spawn(.{ .stack_size = t.stack_size }, worker, .{t}) catch
            return error.ConcurrencyUnavailable;
        thread.detach();
    }

    t.run_queue.prepend(&ac.closure.node);
    t.cond.signal();
    return @ptrCast(ac);
}

const GroupClosure = struct {
    closure: Closure,
    t: *Threaded,
    group: *Io.Group,
    /// Points to sibling `GroupClosure`. Used for walking the group to cancel all.
    node: std.SinglyLinkedList.Node,
    func: *const fn (*Io.Group, context: *anyopaque) void,
    context_alignment: Alignment,
    alloc_len: usize,

    fn start(closure: *Closure) void {
        const gc: *GroupClosure = @alignCast(@fieldParentPtr("closure", closure));
        const tid: CancelId = .currentThread();
        const group = gc.group;
        const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
        const reset_event: *ResetEvent = @ptrCast(&group.context);
        if (@cmpxchgStrong(CancelId, &closure.cancel_tid, .none, tid, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == .canceling);
            // Even though we already know the task is canceled, we must still
            // run the closure in case there are side effects.
        }
        current_closure = closure;
        gc.func(group, gc.contextPointer());
        current_closure = null;

        // In case a cancel happens after successful task completion, prevents
        // signal from being delivered to the thread in `requestCancel`.
        if (@cmpxchgStrong(CancelId, &closure.cancel_tid, tid, .none, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == .canceling);
        }

        const prev_state = group_state.fetchSub(sync_one_pending, .acq_rel);
        assert((prev_state / sync_one_pending) > 0);
        if (prev_state == (sync_one_pending | sync_is_waiting)) reset_event.set();
    }

    fn contextPointer(gc: *GroupClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(gc);
        const context_offset = gc.context_alignment.forward(@intFromPtr(gc) + @sizeOf(GroupClosure)) - @intFromPtr(gc);
        return base + context_offset;
    }

    /// Does not initialize the `node` field.
    fn init(
        gpa: Allocator,
        t: *Threaded,
        group: *Io.Group,
        context: []const u8,
        context_alignment: Alignment,
        func: *const fn (*Io.Group, context: *const anyopaque) void,
    ) Allocator.Error!*GroupClosure {
        const max_context_misalignment = context_alignment.toByteUnits() -| @alignOf(GroupClosure);
        const worst_case_context_offset = context_alignment.forward(@sizeOf(GroupClosure) + max_context_misalignment);
        const alloc_len = worst_case_context_offset + context.len;

        const gc: *GroupClosure = @ptrCast(@alignCast(try gpa.alignedAlloc(u8, .of(GroupClosure), alloc_len)));
        errdefer comptime unreachable;

        gc.* = .{
            .closure = .{
                .cancel_tid = .none,
                .start = start,
            },
            .t = t,
            .group = group,
            .node = undefined,
            .func = func,
            .context_alignment = context_alignment,
            .alloc_len = alloc_len,
        };
        @memcpy(gc.contextPointer()[0..context.len], context);
        return gc;
    }

    fn deinit(gc: *GroupClosure, gpa: Allocator) void {
        const base: [*]align(@alignOf(GroupClosure)) u8 = @ptrCast(gc);
        gpa.free(base[0..gc.alloc_len]);
    }

    const sync_is_waiting: usize = 1 << 0;
    const sync_one_pending: usize = 1 << 1;
};

fn groupAsync(
    userdata: ?*anyopaque,
    group: *Io.Group,
    context: []const u8,
    context_alignment: Alignment,
    start: *const fn (*Io.Group, context: *const anyopaque) void,
) void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    if (builtin.single_threaded) return start(group, context.ptr);

    const gpa = t.allocator;
    const gc = GroupClosure.init(gpa, t, group, context, context_alignment, start) catch
        return start(group, context.ptr);

    t.mutex.lock();

    const busy_count = t.busy_count;

    if (busy_count >= @intFromEnum(t.async_limit)) {
        t.mutex.unlock();
        gc.deinit(gpa);
        return start(group, context.ptr);
    }

    t.busy_count = busy_count + 1;

    const pool_size = t.wait_group.value();
    if (pool_size - busy_count == 0) {
        t.wait_group.start();
        const thread = std.Thread.spawn(.{ .stack_size = t.stack_size }, worker, .{t}) catch {
            t.wait_group.finish();
            t.busy_count = busy_count;
            t.mutex.unlock();
            gc.deinit(gpa);
            return start(group, context.ptr);
        };
        thread.detach();
    }

    // Append to the group linked list inside the mutex to make `Io.Group.async` thread-safe.
    gc.node = .{ .next = @ptrCast(@alignCast(group.token)) };
    group.token = &gc.node;

    t.run_queue.prepend(&gc.closure.node);

    // This needs to be done before unlocking the mutex to avoid a race with
    // the associated task finishing.
    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    const prev_state = group_state.fetchAdd(GroupClosure.sync_one_pending, .monotonic);
    assert((prev_state / GroupClosure.sync_one_pending) < (std.math.maxInt(usize) / GroupClosure.sync_one_pending));

    t.mutex.unlock();
    t.cond.signal();
}

fn groupConcurrent(
    userdata: ?*anyopaque,
    group: *Io.Group,
    context: []const u8,
    context_alignment: Alignment,
    start: *const fn (*Io.Group, context: *const anyopaque) void,
) Io.ConcurrentError!void {
    if (builtin.single_threaded) return error.ConcurrencyUnavailable;

    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const gpa = t.allocator;
    const gc = GroupClosure.init(gpa, t, group, context, context_alignment, start) catch
        return error.ConcurrencyUnavailable;

    t.mutex.lock();
    defer t.mutex.unlock();

    const busy_count = t.busy_count;

    if (busy_count >= @intFromEnum(t.concurrent_limit))
        return error.ConcurrencyUnavailable;

    t.busy_count = busy_count + 1;
    errdefer t.busy_count = busy_count;

    const pool_size = t.wait_group.value();
    if (pool_size - busy_count == 0) {
        t.wait_group.start();
        errdefer t.wait_group.finish();

        const thread = std.Thread.spawn(.{ .stack_size = t.stack_size }, worker, .{t}) catch
            return error.ConcurrencyUnavailable;
        thread.detach();
    }

    // Append to the group linked list inside the mutex to make `Io.Group.concurrent` thread-safe.
    gc.node = .{ .next = @ptrCast(@alignCast(group.token)) };
    group.token = &gc.node;

    t.run_queue.prepend(&gc.closure.node);

    // This needs to be done before unlocking the mutex to avoid a race with
    // the associated task finishing.
    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    const prev_state = group_state.fetchAdd(GroupClosure.sync_one_pending, .monotonic);
    assert((prev_state / GroupClosure.sync_one_pending) < (std.math.maxInt(usize) / GroupClosure.sync_one_pending));

    t.cond.signal();
}

fn groupWait(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const gpa = t.allocator;

    if (builtin.single_threaded) return;

    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    const reset_event: *ResetEvent = @ptrCast(&group.context);
    const prev_state = group_state.fetchAdd(GroupClosure.sync_is_waiting, .acquire);
    assert(prev_state & GroupClosure.sync_is_waiting == 0);
    if ((prev_state / GroupClosure.sync_one_pending) > 0) reset_event.wait(t) catch |err| switch (err) {
        error.Canceled => {
            var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
            while (true) {
                const gc: *GroupClosure = @fieldParentPtr("node", node);
                gc.closure.requestCancel();
                node = node.next orelse break;
            }
            reset_event.waitUncancelable();
        },
    };

    var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
    while (true) {
        const gc: *GroupClosure = @fieldParentPtr("node", node);
        const node_next = node.next;
        gc.deinit(gpa);
        node = node_next orelse break;
    }
}

fn groupCancel(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const gpa = t.allocator;

    if (builtin.single_threaded) return;

    {
        var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
        while (true) {
            const gc: *GroupClosure = @fieldParentPtr("node", node);
            gc.closure.requestCancel();
            node = node.next orelse break;
        }
    }

    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    const reset_event: *ResetEvent = @ptrCast(&group.context);
    const prev_state = group_state.fetchAdd(GroupClosure.sync_is_waiting, .acquire);
    assert(prev_state & GroupClosure.sync_is_waiting == 0);
    if ((prev_state / GroupClosure.sync_one_pending) > 0) reset_event.waitUncancelable();

    {
        var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
        while (true) {
            const gc: *GroupClosure = @fieldParentPtr("node", node);
            const node_next = node.next;
            gc.deinit(gpa);
            node = node_next orelse break;
        }
    }
}

fn await(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: Alignment,
) void {
    _ = result_alignment;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const closure: *AsyncClosure = @ptrCast(@alignCast(any_future));
    closure.waitAndDeinit(t, result);
}

fn cancel(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: Alignment,
) void {
    _ = result_alignment;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const ac: *AsyncClosure = @ptrCast(@alignCast(any_future));
    ac.closure.requestCancel();
    ac.waitAndDeinit(t, result);
}

fn cancelRequested(userdata: ?*anyopaque) bool {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    const closure = current_closure orelse return false;
    return @atomicLoad(CancelId, &closure.cancel_tid, .acquire) == .canceling;
}

fn checkCancel(t: *Threaded) error{Canceled}!void {
    if (cancelRequested(t)) return error.Canceled;
}

fn mutexLock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) Io.Cancelable!void {
    if (builtin.single_threaded) unreachable; // Interface should have prevented this.
    if (native_os == .netbsd) @panic("TODO");
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    if (prev_state == .contended) {
        try futexWait(t, @ptrCast(&mutex.state), @intFromEnum(Io.Mutex.State.contended));
    }
    while (@atomicRmw(Io.Mutex.State, &mutex.state, .Xchg, .contended, .acquire) != .unlocked) {
        try futexWait(t, @ptrCast(&mutex.state), @intFromEnum(Io.Mutex.State.contended));
    }
}

fn mutexLockUncancelable(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    if (builtin.single_threaded) unreachable; // Interface should have prevented this.
    if (native_os == .netbsd) @panic("TODO");
    _ = userdata;
    if (prev_state == .contended) {
        futexWaitUncancelable(@ptrCast(&mutex.state), @intFromEnum(Io.Mutex.State.contended));
    }
    while (@atomicRmw(Io.Mutex.State, &mutex.state, .Xchg, .contended, .acquire) != .unlocked) {
        futexWaitUncancelable(@ptrCast(&mutex.state), @intFromEnum(Io.Mutex.State.contended));
    }
}

fn mutexUnlock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    if (builtin.single_threaded) unreachable; // Interface should have prevented this.
    if (native_os == .netbsd) @panic("TODO");
    _ = userdata;
    _ = prev_state;
    if (@atomicRmw(Io.Mutex.State, &mutex.state, .Xchg, .unlocked, .release) == .contended) {
        futexWake(@ptrCast(&mutex.state), 1);
    }
}

fn conditionWaitUncancelable(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) void {
    if (builtin.single_threaded) unreachable; // Deadlock.
    if (native_os == .netbsd) @panic("TODO");
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    comptime assert(@TypeOf(cond.state) == u64);
    const ints: *[2]std.atomic.Value(u32) = @ptrCast(&cond.state);
    const cond_state = &ints[0];
    const cond_epoch = &ints[1];
    const one_waiter = 1;
    const waiter_mask = 0xffff;
    const one_signal = 1 << 16;
    const signal_mask = 0xffff << 16;
    var epoch = cond_epoch.load(.acquire);
    var state = cond_state.fetchAdd(one_waiter, .monotonic);
    assert(state & waiter_mask != waiter_mask);
    state += one_waiter;

    mutex.unlock(t_io);
    defer mutex.lockUncancelable(t_io);

    while (true) {
        futexWaitUncancelable(cond_epoch, epoch);
        epoch = cond_epoch.load(.acquire);
        state = cond_state.load(.monotonic);
        while (state & signal_mask != 0) {
            const new_state = state - one_waiter - one_signal;
            state = cond_state.cmpxchgWeak(state, new_state, .acquire, .monotonic) orelse return;
        }
    }
}

fn conditionWait(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) Io.Cancelable!void {
    if (builtin.single_threaded) unreachable; // Deadlock.
    if (native_os == .netbsd) @panic("TODO");
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    comptime assert(@TypeOf(cond.state) == u64);
    const ints: *[2]std.atomic.Value(u32) = @ptrCast(&cond.state);
    const cond_state = &ints[0];
    const cond_epoch = &ints[1];
    const one_waiter = 1;
    const waiter_mask = 0xffff;
    const one_signal = 1 << 16;
    const signal_mask = 0xffff << 16;
    // Observe the epoch, then check the state again to see if we should wake up.
    // The epoch must be observed before we check the state or we could potentially miss a wake() and deadlock:
    //
    // - T1: s = LOAD(&state)
    // - T2: UPDATE(&s, signal)
    // - T2: UPDATE(&epoch, 1) + FUTEX_WAKE(&epoch)
    // - T1: e = LOAD(&epoch) (was reordered after the state load)
    // - T1: s & signals == 0 -> FUTEX_WAIT(&epoch, e) (missed the state update + the epoch change)
    //
    // Acquire barrier to ensure the epoch load happens before the state load.
    var epoch = cond_epoch.load(.acquire);
    var state = cond_state.fetchAdd(one_waiter, .monotonic);
    assert(state & waiter_mask != waiter_mask);
    state += one_waiter;

    mutex.unlock(t_io);
    defer mutex.lockUncancelable(t_io);

    while (true) {
        try futexWait(t, cond_epoch, epoch);

        epoch = cond_epoch.load(.acquire);
        state = cond_state.load(.monotonic);

        // Try to wake up by consuming a signal and decremented the waiter we
        // added previously. Acquire barrier ensures code before the wake()
        // which added the signal happens before we decrement it and return.
        while (state & signal_mask != 0) {
            const new_state = state - one_waiter - one_signal;
            state = cond_state.cmpxchgWeak(state, new_state, .acquire, .monotonic) orelse return;
        }
    }
}

fn conditionWake(userdata: ?*anyopaque, cond: *Io.Condition, wake: Io.Condition.Wake) void {
    if (builtin.single_threaded) unreachable; // Nothing to wake up.
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    comptime assert(@TypeOf(cond.state) == u64);
    const ints: *[2]std.atomic.Value(u32) = @ptrCast(&cond.state);
    const cond_state = &ints[0];
    const cond_epoch = &ints[1];
    const one_waiter = 1;
    const waiter_mask = 0xffff;
    const one_signal = 1 << 16;
    const signal_mask = 0xffff << 16;
    var state = cond_state.load(.monotonic);
    while (true) {
        const waiters = (state & waiter_mask) / one_waiter;
        const signals = (state & signal_mask) / one_signal;

        // Reserves which waiters to wake up by incrementing the signals count.
        // Therefore, the signals count is always less than or equal to the
        // waiters count. We don't need to Futex.wake if there's nothing to
        // wake up or if other wake() threads have reserved to wake up the
        // current waiters.
        const wakeable = waiters - signals;
        if (wakeable == 0) {
            return;
        }

        const to_wake = switch (wake) {
            .one => 1,
            .all => wakeable,
        };

        // Reserve the amount of waiters to wake by incrementing the signals
        // count. Release barrier ensures code before the wake() happens before
        // the signal it posted and consumed by the wait() threads.
        const new_state = state + (one_signal * to_wake);
        state = cond_state.cmpxchgWeak(state, new_state, .release, .monotonic) orelse {
            // Wake up the waiting threads we reserved above by changing the epoch value.
            //
            // A waiting thread could miss a wake up if *exactly* ((1<<32)-1)
            // wake()s happen between it observing the epoch and sleeping on
            // it. This is very unlikely due to how many precise amount of
            // Futex.wake() calls that would be between the waiting thread's
            // potential preemption.
            //
            // Release barrier ensures the signal being added to the state
            // happens before the epoch is changed. If not, the waiting thread
            // could potentially deadlock from missing both the state and epoch
            // change:
            //
            // - T2: UPDATE(&epoch, 1) (reordered before the state change)
            // - T1: e = LOAD(&epoch)
            // - T1: s = LOAD(&state)
            // - T2: UPDATE(&state, signal) + FUTEX_WAKE(&epoch)
            // - T1: s & signals == 0 -> FUTEX_WAIT(&epoch, e) (missed both epoch change and state change)
            _ = cond_epoch.fetchAdd(1, .release);
            if (native_os == .netbsd) @panic("TODO");
            futexWake(cond_epoch, to_wake);
            return;
        };
    }
}

const dirMake = switch (native_os) {
    .windows => dirMakeWindows,
    .wasi => dirMakeWasi,
    else => dirMakePosix,
};

fn dirMakePosix(userdata: ?*anyopaque, dir: Io.Dir, sub_path: []const u8, mode: Io.Dir.Mode) Io.Dir.MakeError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.mkdirat(dir.handle, sub_path_posix, mode))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ACCES => return error.AccessDenied,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .PERM => return error.PermissionDenied,
            .DQUOT => return error.DiskQuota,
            .EXIST => return error.PathAlreadyExists,
            .FAULT => |err| return errnoBug(err),
            .LOOP => return error.SymLinkLoop,
            .MLINK => return error.LinkQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOSPC => return error.NoSpaceLeft,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            // dragonfly: when dir_fd is unlinked from filesystem
            .NOTCONN => return error.FileNotFound,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn dirMakeWasi(userdata: ?*anyopaque, dir: Io.Dir, sub_path: []const u8, mode: Io.Dir.Mode) Io.Dir.MakeError!void {
    if (builtin.link_libc) return dirMakePosix(userdata, dir, sub_path, mode);
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    while (true) {
        try t.checkCancel();
        switch (std.os.wasi.path_create_directory(dir.handle, sub_path.ptr, sub_path.len)) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ACCES => return error.AccessDenied,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .PERM => return error.PermissionDenied,
            .DQUOT => return error.DiskQuota,
            .EXIST => return error.PathAlreadyExists,
            .FAULT => |err| return errnoBug(err),
            .LOOP => return error.SymLinkLoop,
            .MLINK => return error.LinkQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOSPC => return error.NoSpaceLeft,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            .NOTCAPABLE => return error.AccessDenied,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn dirMakeWindows(userdata: ?*anyopaque, dir: Io.Dir, sub_path: []const u8, mode: Io.Dir.Mode) Io.Dir.MakeError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    try t.checkCancel();

    const sub_path_w = try windows.sliceToPrefixedFileW(dir.handle, sub_path);
    _ = mode;
    const sub_dir_handle = windows.OpenFile(sub_path_w.span(), .{
        .dir = dir.handle,
        .access_mask = windows.GENERIC_READ | windows.SYNCHRONIZE,
        .creation = windows.FILE_CREATE,
        .filter = .dir_only,
    }) catch |err| switch (err) {
        error.IsDir => return error.Unexpected,
        error.PipeBusy => return error.Unexpected,
        error.NoDevice => return error.Unexpected,
        error.WouldBlock => return error.Unexpected,
        error.AntivirusInterference => return error.Unexpected,
        else => |e| return e,
    };
    windows.CloseHandle(sub_dir_handle);
}

const dirMakePath = switch (native_os) {
    .windows => dirMakePathWindows,
    else => dirMakePathPosix,
};

fn dirMakePathPosix(userdata: ?*anyopaque, dir: Io.Dir, sub_path: []const u8, mode: Io.Dir.Mode) Io.Dir.MakeError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    _ = dir;
    _ = sub_path;
    _ = mode;
    @panic("TODO implement dirMakePathPosix");
}

fn dirMakePathWindows(userdata: ?*anyopaque, dir: Io.Dir, sub_path: []const u8, mode: Io.Dir.Mode) Io.Dir.MakeError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    _ = dir;
    _ = sub_path;
    _ = mode;
    @panic("TODO implement dirMakePathWindows");
}

const dirMakeOpenPath = switch (native_os) {
    .windows => dirMakeOpenPathWindows,
    .wasi => dirMakeOpenPathWasi,
    else => dirMakeOpenPathPosix,
};

fn dirMakeOpenPathPosix(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.OpenOptions,
) Io.Dir.MakeOpenPathError!Io.Dir {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    return dirOpenDirPosix(t, dir, sub_path, options) catch |err| switch (err) {
        error.FileNotFound => {
            try dir.makePath(t_io, sub_path);
            return dirOpenDirPosix(t, dir, sub_path, options);
        },
        else => |e| return e,
    };
}

fn dirMakeOpenPathWindows(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.OpenOptions,
) Io.Dir.MakeOpenPathError!Io.Dir {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const w = windows;
    const access_mask = w.STANDARD_RIGHTS_READ | w.FILE_READ_ATTRIBUTES | w.FILE_READ_EA |
        w.SYNCHRONIZE | w.FILE_TRAVERSE |
        (if (options.iterate) w.FILE_LIST_DIRECTORY else @as(u32, 0));

    var it = std.fs.path.componentIterator(sub_path);
    // If there are no components in the path, then create a dummy component with the full path.
    var component: std.fs.path.NativeComponentIterator.Component = it.last() orelse .{
        .name = "",
        .path = sub_path,
    };

    while (true) {
        try t.checkCancel();

        const sub_path_w_array = try w.sliceToPrefixedFileW(dir.handle, component.path);
        const sub_path_w = sub_path_w_array.span();
        const is_last = it.peekNext() == null;
        const create_disposition: u32 = if (is_last) w.FILE_OPEN_IF else w.FILE_CREATE;

        var result: Io.Dir = .{ .handle = undefined };

        const path_len_bytes: u16 = @intCast(sub_path_w.len * 2);
        var nt_name: w.UNICODE_STRING = .{
            .Length = path_len_bytes,
            .MaximumLength = path_len_bytes,
            .Buffer = @constCast(sub_path_w.ptr),
        };
        var attr: w.OBJECT_ATTRIBUTES = .{
            .Length = @sizeOf(w.OBJECT_ATTRIBUTES),
            .RootDirectory = if (std.fs.path.isAbsoluteWindowsWtf16(sub_path_w)) null else dir.handle,
            .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
            .ObjectName = &nt_name,
            .SecurityDescriptor = null,
            .SecurityQualityOfService = null,
        };
        const open_reparse_point: w.DWORD = if (!options.follow_symlinks) w.FILE_OPEN_REPARSE_POINT else 0x0;
        var io_status_block: w.IO_STATUS_BLOCK = undefined;
        const rc = w.ntdll.NtCreateFile(
            &result.handle,
            access_mask,
            &attr,
            &io_status_block,
            null,
            w.FILE_ATTRIBUTE_NORMAL,
            w.FILE_SHARE_READ | w.FILE_SHARE_WRITE | w.FILE_SHARE_DELETE,
            create_disposition,
            w.FILE_DIRECTORY_FILE | w.FILE_SYNCHRONOUS_IO_NONALERT | w.FILE_OPEN_FOR_BACKUP_INTENT | open_reparse_point,
            null,
            0,
        );

        switch (rc) {
            .SUCCESS => {
                component = it.next() orelse return result;
                w.CloseHandle(result.handle);
                continue;
            },
            .OBJECT_NAME_INVALID => return error.BadPathName,
            .OBJECT_NAME_COLLISION => {
                assert(!is_last);
                // stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                check_dir: {
                    // workaround for windows, see https://github.com/ziglang/zig/issues/16738
                    const fstat = dirStatPathWindows(t, dir, component.path, .{
                        .follow_symlinks = options.follow_symlinks,
                    }) catch |stat_err| switch (stat_err) {
                        error.IsDir => break :check_dir,
                        else => |e| return e,
                    };
                    if (fstat.kind != .directory) return error.NotDir;
                }

                component = it.next().?;
                continue;
            },

            .OBJECT_NAME_NOT_FOUND,
            .OBJECT_PATH_NOT_FOUND,
            => {
                component = it.previous() orelse return error.FileNotFound;
                continue;
            },

            .NOT_A_DIRECTORY => return error.NotDir,
            // This can happen if the directory has 'List folder contents' permission set to 'Deny'
            // and the directory is trying to be opened for iteration.
            .ACCESS_DENIED => return error.AccessDenied,
            .INVALID_PARAMETER => |err| return w.statusBug(err),
            else => return w.unexpectedStatus(rc),
        }
    }
}

fn dirMakeOpenPathWasi(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.OpenOptions,
) Io.Dir.MakeOpenPathError!Io.Dir {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    return dirOpenDirWasi(t, dir, sub_path, options) catch |err| switch (err) {
        error.FileNotFound => {
            try dir.makePath(t_io, sub_path);
            return dirOpenDirWasi(t, dir, sub_path, options);
        },
        else => |e| return e,
    };
}

fn dirStat(userdata: ?*anyopaque, dir: Io.Dir) Io.Dir.StatError!Io.Dir.Stat {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    try t.checkCancel();

    _ = dir;
    @panic("TODO implement dirStat");
}

const dirStatPath = switch (native_os) {
    .linux => dirStatPathLinux,
    .windows => dirStatPathWindows,
    .wasi => dirStatPathWasi,
    else => dirStatPathPosix,
};

fn dirStatPathLinux(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.StatPathOptions,
) Io.Dir.StatPathError!Io.File.Stat {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const linux = std.os.linux;

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

    const flags: u32 = linux.AT.NO_AUTOMOUNT |
        @as(u32, if (!options.follow_symlinks) linux.AT.SYMLINK_NOFOLLOW else 0);

    while (true) {
        try t.checkCancel();
        var statx = std.mem.zeroes(linux.Statx);
        const rc = linux.statx(
            dir.handle,
            sub_path_posix,
            flags,
            linux.STATX_INO | linux.STATX_SIZE | linux.STATX_TYPE | linux.STATX_MODE | linux.STATX_ATIME | linux.STATX_MTIME | linux.STATX_CTIME,
            &statx,
        );
        switch (linux.errno(rc)) {
            .SUCCESS => return statFromLinux(&statx),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ACCES => return error.AccessDenied,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err),
            .LOOP => return error.SymLinkLoop,
            .NAMETOOLONG => |err| return errnoBug(err), // Handled by pathToPosix() above.
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.NotDir,
            .NOMEM => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn dirStatPathPosix(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.StatPathOptions,
) Io.Dir.StatPathError!Io.File.Stat {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

    const flags: u32 = if (!options.follow_symlinks) posix.AT.SYMLINK_NOFOLLOW else 0;

    while (true) {
        try t.checkCancel();
        var stat = std.mem.zeroes(posix.Stat);
        switch (posix.errno(fstatat_sym(dir.handle, sub_path_posix, &stat, flags))) {
            .SUCCESS => return statFromPosix(&stat),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOMEM => return error.SystemResources,
            .ACCES => return error.AccessDenied,
            .PERM => return error.PermissionDenied,
            .FAULT => |err| return errnoBug(err),
            .NAMETOOLONG => return error.NameTooLong,
            .LOOP => return error.SymLinkLoop,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.FileNotFound,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn dirStatPathWindows(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.StatPathOptions,
) Io.Dir.StatPathError!Io.File.Stat {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const file = try dirOpenFileWindows(t, dir, sub_path, .{
        .follow_symlinks = options.follow_symlinks,
    });
    defer windows.CloseHandle(file.handle);
    return fileStatWindows(t, file);
}

fn dirStatPathWasi(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.StatPathOptions,
) Io.Dir.StatPathError!Io.File.Stat {
    if (builtin.link_libc) return dirStatPathPosix(userdata, dir, sub_path, options);
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const wasi = std.os.wasi;
    const flags: wasi.lookupflags_t = .{
        .SYMLINK_FOLLOW = options.follow_symlinks,
    };
    var stat: wasi.filestat_t = undefined;
    while (true) {
        try t.checkCancel();
        switch (wasi.path_filestat_get(dir.handle, flags, sub_path.ptr, sub_path.len, &stat)) {
            .SUCCESS => return statFromWasi(&stat),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOMEM => return error.SystemResources,
            .ACCES => return error.AccessDenied,
            .FAULT => |err| return errnoBug(err),
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.FileNotFound,
            .NOTCAPABLE => return error.AccessDenied,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

const fileStat = switch (native_os) {
    .linux => fileStatLinux,
    .windows => fileStatWindows,
    .wasi => fileStatWasi,
    else => fileStatPosix,
};

fn fileStatPosix(userdata: ?*anyopaque, file: Io.File) Io.File.StatError!Io.File.Stat {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    if (posix.Stat == void) return error.Streaming;

    while (true) {
        try t.checkCancel();
        var stat = std.mem.zeroes(posix.Stat);
        switch (posix.errno(fstat_sym(file.handle, &stat))) {
            .SUCCESS => return statFromPosix(&stat),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOMEM => return error.SystemResources,
            .ACCES => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn fileStatLinux(userdata: ?*anyopaque, file: Io.File) Io.File.StatError!Io.File.Stat {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const linux = std.os.linux;
    while (true) {
        try t.checkCancel();
        var statx = std.mem.zeroes(linux.Statx);
        const rc = linux.statx(
            file.handle,
            "",
            linux.AT.EMPTY_PATH,
            linux.STATX_INO | linux.STATX_SIZE | linux.STATX_TYPE | linux.STATX_MODE | linux.STATX_ATIME | linux.STATX_MTIME | linux.STATX_CTIME,
            &statx,
        );
        switch (linux.errno(rc)) {
            .SUCCESS => return statFromLinux(&statx),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ACCES => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err),
            .LOOP => |err| return errnoBug(err),
            .NAMETOOLONG => |err| return errnoBug(err),
            .NOENT => |err| return errnoBug(err),
            .NOMEM => return error.SystemResources,
            .NOTDIR => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn fileStatWindows(userdata: ?*anyopaque, file: Io.File) Io.File.StatError!Io.File.Stat {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    try t.checkCancel();

    var io_status_block: windows.IO_STATUS_BLOCK = undefined;
    var info: windows.FILE_ALL_INFORMATION = undefined;
    const rc = windows.ntdll.NtQueryInformationFile(file.handle, &io_status_block, &info, @sizeOf(windows.FILE_ALL_INFORMATION), .FileAllInformation);
    switch (rc) {
        .SUCCESS => {},
        // Buffer overflow here indicates that there is more information available than was able to be stored in the buffer
        // size provided. This is treated as success because the type of variable-length information that this would be relevant for
        // (name, volume name, etc) we don't care about.
        .BUFFER_OVERFLOW => {},
        .INVALID_PARAMETER => unreachable,
        .ACCESS_DENIED => return error.AccessDenied,
        else => return windows.unexpectedStatus(rc),
    }
    return .{
        .inode = info.InternalInformation.IndexNumber,
        .size = @as(u64, @bitCast(info.StandardInformation.EndOfFile)),
        .mode = 0,
        .kind = if (info.BasicInformation.FileAttributes & windows.FILE_ATTRIBUTE_REPARSE_POINT != 0) reparse_point: {
            var tag_info: windows.FILE_ATTRIBUTE_TAG_INFO = undefined;
            const tag_rc = windows.ntdll.NtQueryInformationFile(file.handle, &io_status_block, &tag_info, @sizeOf(windows.FILE_ATTRIBUTE_TAG_INFO), .FileAttributeTagInformation);
            switch (tag_rc) {
                .SUCCESS => {},
                // INFO_LENGTH_MISMATCH and ACCESS_DENIED are the only documented possible errors
                // https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/d295752f-ce89-4b98-8553-266d37c84f0e
                .INFO_LENGTH_MISMATCH => unreachable,
                .ACCESS_DENIED => return error.AccessDenied,
                else => return windows.unexpectedStatus(rc),
            }
            if (tag_info.ReparseTag & windows.reparse_tag_name_surrogate_bit != 0) {
                break :reparse_point .sym_link;
            }
            // Unknown reparse point
            break :reparse_point .unknown;
        } else if (info.BasicInformation.FileAttributes & windows.FILE_ATTRIBUTE_DIRECTORY != 0)
            .directory
        else
            .file,
        .atime = windows.fromSysTime(info.BasicInformation.LastAccessTime),
        .mtime = windows.fromSysTime(info.BasicInformation.LastWriteTime),
        .ctime = windows.fromSysTime(info.BasicInformation.ChangeTime),
    };
}

fn fileStatWasi(userdata: ?*anyopaque, file: Io.File) Io.File.StatError!Io.File.Stat {
    if (builtin.link_libc) return fileStatPosix(userdata, file);
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    while (true) {
        try t.checkCancel();
        var stat: std.os.wasi.filestat_t = undefined;
        switch (std.os.wasi.fd_filestat_get(file.handle, &stat)) {
            .SUCCESS => return statFromWasi(&stat),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOMEM => return error.SystemResources,
            .ACCES => return error.AccessDenied,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

const dirAccess = switch (native_os) {
    .windows => dirAccessWindows,
    .wasi => dirAccessWasi,
    else => dirAccessPosix,
};

fn dirAccessPosix(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.AccessOptions,
) Io.Dir.AccessError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

    const flags: u32 = @as(u32, if (!options.follow_symlinks) posix.AT.SYMLINK_NOFOLLOW else 0);

    const mode: u32 =
        @as(u32, if (options.read) posix.R_OK else 0) |
        @as(u32, if (options.write) posix.W_OK else 0) |
        @as(u32, if (options.execute) posix.X_OK else 0);

    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.faccessat(dir.handle, sub_path_posix, mode, flags))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ACCES => return error.AccessDenied,
            .PERM => return error.PermissionDenied,
            .ROFS => return error.ReadOnlyFileSystem,
            .LOOP => return error.SymLinkLoop,
            .TXTBSY => return error.FileBusy,
            .NOTDIR => return error.FileNotFound,
            .NOENT => return error.FileNotFound,
            .NAMETOOLONG => return error.NameTooLong,
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .IO => return error.InputOutput,
            .NOMEM => return error.SystemResources,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn dirAccessWasi(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.AccessOptions,
) Io.Dir.AccessError!void {
    if (builtin.link_libc) return dirAccessPosix(userdata, dir, sub_path, options);
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const wasi = std.os.wasi;
    const flags: wasi.lookupflags_t = .{
        .SYMLINK_FOLLOW = options.follow_symlinks,
    };
    var stat: wasi.filestat_t = undefined;
    while (true) {
        try t.checkCancel();
        switch (wasi.path_filestat_get(dir.handle, flags, sub_path.ptr, sub_path.len, &stat)) {
            .SUCCESS => break,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOMEM => return error.SystemResources,
            .ACCES => return error.AccessDenied,
            .FAULT => |err| return errnoBug(err),
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.FileNotFound,
            .NOTCAPABLE => return error.AccessDenied,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    if (!options.read and !options.write and !options.execute)
        return;

    var directory: wasi.fdstat_t = undefined;
    if (wasi.fd_fdstat_get(dir.handle, &directory) != .SUCCESS)
        return error.AccessDenied;

    var rights: wasi.rights_t = .{};
    if (options.read) {
        if (stat.filetype == .DIRECTORY) {
            rights.FD_READDIR = true;
        } else {
            rights.FD_READ = true;
        }
    }
    if (options.write)
        rights.FD_WRITE = true;

    // No validation for execution.

    // https://github.com/ziglang/zig/issues/18882
    const rights_int: u64 = @bitCast(rights);
    const inheriting_int: u64 = @bitCast(directory.fs_rights_inheriting);
    if ((rights_int & inheriting_int) != rights_int)
        return error.AccessDenied;
}

fn dirAccessWindows(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.AccessOptions,
) Io.Dir.AccessError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    try t.checkCancel();

    _ = options; // TODO

    const sub_path_w_array = try windows.sliceToPrefixedFileW(dir.handle, sub_path);
    const sub_path_w = sub_path_w_array.span();

    if (sub_path_w[0] == '.' and sub_path_w[1] == 0) return;
    if (sub_path_w[0] == '.' and sub_path_w[1] == '.' and sub_path_w[2] == 0) return;

    const path_len_bytes = std.math.cast(u16, std.mem.sliceTo(sub_path_w, 0).len * 2) orelse
        return error.NameTooLong;
    var nt_name: windows.UNICODE_STRING = .{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(sub_path_w.ptr),
    };
    var attr = windows.OBJECT_ATTRIBUTES{
        .Length = @sizeOf(windows.OBJECT_ATTRIBUTES),
        .RootDirectory = if (std.fs.path.isAbsoluteWindowsWtf16(sub_path_w)) null else dir.handle,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    var basic_info: windows.FILE_BASIC_INFORMATION = undefined;
    switch (windows.ntdll.NtQueryAttributesFile(&attr, &basic_info)) {
        .SUCCESS => return,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .OBJECT_NAME_INVALID => |err| return windows.statusBug(err),
        .INVALID_PARAMETER => |err| return windows.statusBug(err),
        .ACCESS_DENIED => return error.AccessDenied,
        .OBJECT_PATH_SYNTAX_BAD => |err| return windows.statusBug(err),
        else => |rc| return windows.unexpectedStatus(rc),
    }
}

const dirCreateFile = switch (native_os) {
    .windows => dirCreateFileWindows,
    .wasi => dirCreateFileWasi,
    else => dirCreateFilePosix,
};

fn dirCreateFilePosix(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.CreateFlags,
) Io.File.OpenError!Io.File {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

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
    if (have_flock_open_flags) switch (flags.lock) {
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

    const fd: posix.fd_t = while (true) {
        try t.checkCancel();
        const rc = openat_sym(dir.handle, sub_path_posix, os_flags, flags.mode);
        switch (posix.errno(rc)) {
            .SUCCESS => break @intCast(rc),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .FAULT => |err| return errnoBug(err),
            .INVAL => return error.BadPathName,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
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
            .SRCH => return error.ProcessNotFound,
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
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    };
    errdefer posix.close(fd);

    if (have_flock and !have_flock_open_flags and flags.lock != .none) {
        const lock_nonblocking: i32 = if (flags.lock_nonblocking) posix.LOCK.NB else 0;
        const lock_flags = switch (flags.lock) {
            .none => unreachable,
            .shared => posix.LOCK.SH | lock_nonblocking,
            .exclusive => posix.LOCK.EX | lock_nonblocking,
        };
        while (true) {
            try t.checkCancel();
            switch (posix.errno(posix.system.flock(fd, lock_flags))) {
                .SUCCESS => break,
                .INTR => continue,
                .CANCELED => return error.Canceled,

                .BADF => |err| return errnoBug(err), // File descriptor used after closed.
                .INVAL => |err| return errnoBug(err), // invalid parameters
                .NOLCK => return error.SystemResources,
                .AGAIN => return error.WouldBlock,
                .OPNOTSUPP => return error.FileLocksNotSupported,
                else => |err| return posix.unexpectedErrno(err),
            }
        }
    }

    if (have_flock_open_flags and flags.lock_nonblocking) {
        var fl_flags: usize = while (true) {
            try t.checkCancel();
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
            try t.checkCancel();
            switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFL, fl_flags))) {
                .SUCCESS => break,
                .INTR => continue,
                .CANCELED => return error.Canceled,
                else => |err| return posix.unexpectedErrno(err),
            }
        }
    }

    return .{ .handle = fd };
}

fn dirCreateFileWindows(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.CreateFlags,
) Io.File.OpenError!Io.File {
    const w = windows;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    try t.checkCancel();

    const sub_path_w_array = try w.sliceToPrefixedFileW(dir.handle, sub_path);
    const sub_path_w = sub_path_w_array.span();

    const read_flag = if (flags.read) @as(u32, w.GENERIC_READ) else 0;
    const handle = try w.OpenFile(sub_path_w, .{
        .dir = dir.handle,
        .access_mask = w.SYNCHRONIZE | w.GENERIC_WRITE | read_flag,
        .creation = if (flags.exclusive)
            @as(u32, w.FILE_CREATE)
        else if (flags.truncate)
            @as(u32, w.FILE_OVERWRITE_IF)
        else
            @as(u32, w.FILE_OPEN_IF),
    });
    errdefer w.CloseHandle(handle);
    var io_status_block: w.IO_STATUS_BLOCK = undefined;
    const range_off: w.LARGE_INTEGER = 0;
    const range_len: w.LARGE_INTEGER = 1;
    const exclusive = switch (flags.lock) {
        .none => return .{ .handle = handle },
        .shared => false,
        .exclusive => true,
    };
    try w.LockFile(
        handle,
        null,
        null,
        null,
        &io_status_block,
        &range_off,
        &range_len,
        null,
        @intFromBool(flags.lock_nonblocking),
        @intFromBool(exclusive),
    );
    return .{ .handle = handle };
}

fn dirCreateFileWasi(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.CreateFlags,
) Io.File.OpenError!Io.File {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const wasi = std.os.wasi;
    const lookup_flags: wasi.lookupflags_t = .{};
    const oflags: wasi.oflags_t = .{
        .CREAT = true,
        .TRUNC = flags.truncate,
        .EXCL = flags.exclusive,
    };
    const fdflags: wasi.fdflags_t = .{};
    const base: wasi.rights_t = .{
        .FD_READ = flags.read,
        .FD_WRITE = true,
        .FD_DATASYNC = true,
        .FD_SEEK = true,
        .FD_TELL = true,
        .FD_FDSTAT_SET_FLAGS = true,
        .FD_SYNC = true,
        .FD_ALLOCATE = true,
        .FD_ADVISE = true,
        .FD_FILESTAT_SET_TIMES = true,
        .FD_FILESTAT_SET_SIZE = true,
        .FD_FILESTAT_GET = true,
        // POLL_FD_READWRITE only grants extra rights if the corresponding FD_READ and/or
        // FD_WRITE is also set.
        .POLL_FD_READWRITE = true,
    };
    const inheriting: wasi.rights_t = .{};
    var fd: posix.fd_t = undefined;
    while (true) {
        try t.checkCancel();
        switch (wasi.path_open(dir.handle, lookup_flags, sub_path.ptr, sub_path.len, oflags, base, inheriting, fdflags, &fd)) {
            .SUCCESS => return .{ .handle = fd },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .FAULT => |err| return errnoBug(err),
            .INVAL => return error.BadPathName,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
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
            .NOTCAPABLE => return error.AccessDenied,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

const dirOpenFile = switch (native_os) {
    .windows => dirOpenFileWindows,
    .wasi => dirOpenFileWasi,
    else => dirOpenFilePosix,
};

fn dirOpenFilePosix(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.OpenFlags,
) Io.File.OpenError!Io.File {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

    var os_flags: posix.O = switch (native_os) {
        .wasi => .{
            .read = flags.mode != .write_only,
            .write = flags.mode != .read_only,
        },
        else => .{
            .ACCMODE = switch (flags.mode) {
                .read_only => .RDONLY,
                .write_only => .WRONLY,
                .read_write => .RDWR,
            },
        },
    };
    if (@hasField(posix.O, "CLOEXEC")) os_flags.CLOEXEC = true;
    if (@hasField(posix.O, "LARGEFILE")) os_flags.LARGEFILE = true;
    if (@hasField(posix.O, "NOCTTY")) os_flags.NOCTTY = !flags.allow_ctty;

    // Use the O locking flags if the os supports them to acquire the lock
    // atomically. Note that the NONBLOCK flag is removed after the openat()
    // call is successful.
    if (have_flock_open_flags) switch (flags.lock) {
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

    const fd: posix.fd_t = while (true) {
        try t.checkCancel();
        const rc = openat_sym(dir.handle, sub_path_posix, os_flags, @as(posix.mode_t, 0));
        switch (posix.errno(rc)) {
            .SUCCESS => break @intCast(rc),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .FAULT => |err| return errnoBug(err),
            .INVAL => return error.BadPathName,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
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
            .SRCH => return error.ProcessNotFound,
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
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    };
    errdefer posix.close(fd);

    if (have_flock and !have_flock_open_flags and flags.lock != .none) {
        const lock_nonblocking: i32 = if (flags.lock_nonblocking) posix.LOCK.NB else 0;
        const lock_flags = switch (flags.lock) {
            .none => unreachable,
            .shared => posix.LOCK.SH | lock_nonblocking,
            .exclusive => posix.LOCK.EX | lock_nonblocking,
        };
        while (true) {
            try t.checkCancel();
            switch (posix.errno(posix.system.flock(fd, lock_flags))) {
                .SUCCESS => break,
                .INTR => continue,
                .CANCELED => return error.Canceled,

                .BADF => |err| return errnoBug(err), // File descriptor used after closed.
                .INVAL => |err| return errnoBug(err), // invalid parameters
                .NOLCK => return error.SystemResources,
                .AGAIN => return error.WouldBlock,
                .OPNOTSUPP => return error.FileLocksNotSupported,
                else => |err| return posix.unexpectedErrno(err),
            }
        }
    }

    if (have_flock_open_flags and flags.lock_nonblocking) {
        var fl_flags: usize = while (true) {
            try t.checkCancel();
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
            try t.checkCancel();
            switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFL, fl_flags))) {
                .SUCCESS => break,
                .INTR => continue,
                .CANCELED => return error.Canceled,
                else => |err| return posix.unexpectedErrno(err),
            }
        }
    }

    return .{ .handle = fd };
}

fn dirOpenFileWindows(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.OpenFlags,
) Io.File.OpenError!Io.File {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const sub_path_w_array = try windows.sliceToPrefixedFileW(dir.handle, sub_path);
    const sub_path_w = sub_path_w_array.span();
    const dir_handle = if (std.fs.path.isAbsoluteWindowsWtf16(sub_path_w)) null else dir.handle;
    return dirOpenFileWtf16(t, dir_handle, sub_path_w, flags);
}

pub fn dirOpenFileWtf16(
    t: *Threaded,
    dir_handle: ?windows.HANDLE,
    sub_path_w: [:0]const u16,
    flags: Io.File.OpenFlags,
) Io.File.OpenError!Io.File {
    if (std.mem.eql(u16, sub_path_w, &.{'.'})) return error.IsDir;
    if (std.mem.eql(u16, sub_path_w, &.{ '.', '.' })) return error.IsDir;
    const path_len_bytes = std.math.cast(u16, sub_path_w.len * 2) orelse return error.NameTooLong;

    const w = windows;

    var nt_name: w.UNICODE_STRING = .{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(sub_path_w.ptr),
    };
    var attr: w.OBJECT_ATTRIBUTES = .{
        .Length = @sizeOf(w.OBJECT_ATTRIBUTES),
        .RootDirectory = dir_handle,
        .Attributes = 0,
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    var io_status_block: w.IO_STATUS_BLOCK = undefined;
    const blocking_flag: w.ULONG = w.FILE_SYNCHRONOUS_IO_NONALERT;
    const file_or_dir_flag: w.ULONG = w.FILE_NON_DIRECTORY_FILE;
    // If we're not following symlinks, we need to ensure we don't pass in any
    // synchronization flags such as FILE_SYNCHRONOUS_IO_NONALERT.
    const create_file_flags: w.ULONG = file_or_dir_flag |
        if (flags.follow_symlinks) blocking_flag else w.FILE_OPEN_REPARSE_POINT;

    // There are multiple kernel bugs being worked around with retries.
    const max_attempts = 13;
    var attempt: u5 = 0;

    const handle = while (true) {
        try t.checkCancel();

        var result: w.HANDLE = undefined;
        const rc = w.ntdll.NtCreateFile(
            &result,
            w.SYNCHRONIZE |
                (if (flags.isRead()) @as(u32, w.GENERIC_READ) else 0) |
                (if (flags.isWrite()) @as(u32, w.GENERIC_WRITE) else 0),
            &attr,
            &io_status_block,
            null,
            w.FILE_ATTRIBUTE_NORMAL,
            w.FILE_SHARE_WRITE | w.FILE_SHARE_READ | w.FILE_SHARE_DELETE,
            w.FILE_OPEN,
            create_file_flags,
            null,
            0,
        );
        switch (rc) {
            .SUCCESS => break result,
            .OBJECT_NAME_INVALID => return error.BadPathName,
            .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
            .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
            .BAD_NETWORK_PATH => return error.NetworkNotFound, // \\server was not found
            .BAD_NETWORK_NAME => return error.NetworkNotFound, // \\server was found but \\server\share wasn't
            .NO_MEDIA_IN_DEVICE => return error.NoDevice,
            .INVALID_PARAMETER => |err| return w.statusBug(err),
            .SHARING_VIOLATION => {
                // This occurs if the file attempting to be opened is a running
                // executable. However, there's a kernel bug: the error may be
                // incorrectly returned for an indeterminate amount of time
                // after an executable file is closed. Here we work around the
                // kernel bug with retry attempts.
                if (max_attempts - attempt == 0) return error.SharingViolation;
                _ = w.kernel32.SleepEx((@as(u32, 1) << attempt) >> 1, w.TRUE);
                attempt += 1;
                continue;
            },
            .ACCESS_DENIED => return error.AccessDenied,
            .PIPE_BUSY => return error.PipeBusy,
            .PIPE_NOT_AVAILABLE => return error.NoDevice,
            .OBJECT_PATH_SYNTAX_BAD => |err| return w.statusBug(err),
            .OBJECT_NAME_COLLISION => return error.PathAlreadyExists,
            .FILE_IS_A_DIRECTORY => return error.IsDir,
            .NOT_A_DIRECTORY => return error.NotDir,
            .USER_MAPPED_FILE => return error.AccessDenied,
            .INVALID_HANDLE => |err| return w.statusBug(err),
            .DELETE_PENDING => {
                // This error means that there *was* a file in this location on
                // the file system, but it was deleted. However, the OS is not
                // finished with the deletion operation, and so this CreateFile
                // call has failed. Here, we simulate the kernel bug being
                // fixed by sleeping and retrying until the error goes away.
                if (max_attempts - attempt == 0) return error.SharingViolation;
                _ = w.kernel32.SleepEx((@as(u32, 1) << attempt) >> 1, w.TRUE);
                attempt += 1;
                continue;
            },
            .VIRUS_INFECTED, .VIRUS_DELETED => return error.AntivirusInterference,
            else => return w.unexpectedStatus(rc),
        }
    };
    errdefer w.CloseHandle(handle);

    const range_off: w.LARGE_INTEGER = 0;
    const range_len: w.LARGE_INTEGER = 1;
    const exclusive = switch (flags.lock) {
        .none => return .{ .handle = handle },
        .shared => false,
        .exclusive => true,
    };
    try w.LockFile(
        handle,
        null,
        null,
        null,
        &io_status_block,
        &range_off,
        &range_len,
        null,
        @intFromBool(flags.lock_nonblocking),
        @intFromBool(exclusive),
    );
    return .{ .handle = handle };
}

fn dirOpenFileWasi(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.OpenFlags,
) Io.File.OpenError!Io.File {
    if (builtin.link_libc) return dirOpenFilePosix(userdata, dir, sub_path, flags);
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const wasi = std.os.wasi;
    var base: std.os.wasi.rights_t = .{};
    // POLL_FD_READWRITE only grants extra rights if the corresponding FD_READ and/or FD_WRITE
    // is also set.
    if (flags.isRead()) {
        base.FD_READ = true;
        base.FD_TELL = true;
        base.FD_SEEK = true;
        base.FD_FILESTAT_GET = true;
        base.POLL_FD_READWRITE = true;
    }
    if (flags.isWrite()) {
        base.FD_WRITE = true;
        base.FD_TELL = true;
        base.FD_SEEK = true;
        base.FD_DATASYNC = true;
        base.FD_FDSTAT_SET_FLAGS = true;
        base.FD_SYNC = true;
        base.FD_ALLOCATE = true;
        base.FD_ADVISE = true;
        base.FD_FILESTAT_SET_TIMES = true;
        base.FD_FILESTAT_SET_SIZE = true;
        base.POLL_FD_READWRITE = true;
    }
    const lookup_flags: wasi.lookupflags_t = .{};
    const oflags: wasi.oflags_t = .{};
    const inheriting: wasi.rights_t = .{};
    const fdflags: wasi.fdflags_t = .{};
    var fd: posix.fd_t = undefined;
    while (true) {
        try t.checkCancel();
        switch (wasi.path_open(dir.handle, lookup_flags, sub_path.ptr, sub_path.len, oflags, base, inheriting, fdflags, &fd)) {
            .SUCCESS => return .{ .handle = fd },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .FAULT => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .ACCES => return error.AccessDenied,
            .FBIG => return error.FileTooBig,
            .OVERFLOW => return error.FileTooBig,
            .ISDIR => return error.IsDir,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NODEV => return error.NoDevice,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .PERM => return error.PermissionDenied,
            .BUSY => return error.DeviceBusy,
            .NOTCAPABLE => return error.AccessDenied,
            .NAMETOOLONG => return error.NameTooLong,
            .INVAL => return error.BadPathName,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

const dirOpenDir = switch (native_os) {
    .wasi => dirOpenDirWasi,
    .haiku => dirOpenDirHaiku,
    else => dirOpenDirPosix,
};

/// This function is also used for WASI when libc is linked.
fn dirOpenDirPosix(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.OpenOptions,
) Io.Dir.OpenError!Io.Dir {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    if (is_windows) {
        const sub_path_w = try windows.sliceToPrefixedFileW(dir.handle, sub_path);
        return dirOpenDirWindows(t, dir, sub_path_w.span(), options);
    }

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

    var flags: posix.O = switch (native_os) {
        .wasi => .{
            .read = true,
            .NOFOLLOW = !options.follow_symlinks,
            .DIRECTORY = true,
        },
        else => .{
            .ACCMODE = .RDONLY,
            .NOFOLLOW = !options.follow_symlinks,
            .DIRECTORY = true,
            .CLOEXEC = true,
        },
    };

    if (@hasField(posix.O, "PATH") and !options.iterate)
        flags.PATH = true;

    while (true) {
        try t.checkCancel();
        const rc = openat_sym(dir.handle, sub_path_posix, flags, @as(usize, 0));
        switch (posix.errno(rc)) {
            .SUCCESS => return .{ .handle = @intCast(rc) },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .FAULT => |err| return errnoBug(err),
            .INVAL => return error.BadPathName,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .ACCES => return error.AccessDenied,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NODEV => return error.NoDevice,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .PERM => return error.PermissionDenied,
            .BUSY => return error.DeviceBusy,
            .NXIO => return error.NoDevice,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn dirOpenDirHaiku(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.OpenOptions,
) Io.Dir.OpenError!Io.Dir {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var path_buffer: [posix.PATH_MAX]u8 = undefined;
    const sub_path_posix = try pathToPosix(sub_path, &path_buffer);

    _ = options;

    while (true) {
        try t.checkCancel();
        const rc = posix.system._kern_open_dir(dir.handle, sub_path_posix);
        if (rc >= 0) return .{ .handle = rc };
        switch (@as(posix.E, @enumFromInt(rc))) {
            .INTR => continue,
            .CANCELED => return error.Canceled,
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .ACCES => return error.AccessDenied,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NODEV => return error.NoDevice,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .PERM => return error.PermissionDenied,
            .BUSY => return error.DeviceBusy,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

pub fn dirOpenDirWindows(
    t: *Io.Threaded,
    dir: Io.Dir,
    sub_path_w: [:0]const u16,
    options: Io.Dir.OpenOptions,
) Io.Dir.OpenError!Io.Dir {
    const w = windows;
    // TODO remove some of these flags if options.access_sub_paths is false
    const base_flags = w.STANDARD_RIGHTS_READ | w.FILE_READ_ATTRIBUTES | w.FILE_READ_EA |
        w.SYNCHRONIZE | w.FILE_TRAVERSE;
    const access_mask: u32 = if (options.iterate) base_flags | w.FILE_LIST_DIRECTORY else base_flags;

    const path_len_bytes: u16 = @intCast(sub_path_w.len * 2);
    var nt_name: w.UNICODE_STRING = .{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(sub_path_w.ptr),
    };
    var attr: w.OBJECT_ATTRIBUTES = .{
        .Length = @sizeOf(w.OBJECT_ATTRIBUTES),
        .RootDirectory = if (std.fs.path.isAbsoluteWindowsWtf16(sub_path_w)) null else dir.handle,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    const open_reparse_point: w.DWORD = if (!options.follow_symlinks) w.FILE_OPEN_REPARSE_POINT else 0x0;
    var io_status_block: w.IO_STATUS_BLOCK = undefined;
    var result: Io.Dir = .{ .handle = undefined };
    try t.checkCancel();
    const rc = w.ntdll.NtCreateFile(
        &result.handle,
        access_mask,
        &attr,
        &io_status_block,
        null,
        w.FILE_ATTRIBUTE_NORMAL,
        w.FILE_SHARE_READ | w.FILE_SHARE_WRITE | w.FILE_SHARE_DELETE,
        w.FILE_OPEN,
        w.FILE_DIRECTORY_FILE | w.FILE_SYNCHRONOUS_IO_NONALERT | w.FILE_OPEN_FOR_BACKUP_INTENT | open_reparse_point,
        null,
        0,
    );

    switch (rc) {
        .SUCCESS => return result,
        .OBJECT_NAME_INVALID => return error.BadPathName,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_NAME_COLLISION => |err| return w.statusBug(err),
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .NOT_A_DIRECTORY => return error.NotDir,
        // This can happen if the directory has 'List folder contents' permission set to 'Deny'
        // and the directory is trying to be opened for iteration.
        .ACCESS_DENIED => return error.AccessDenied,
        .INVALID_PARAMETER => |err| return w.statusBug(err),
        else => return w.unexpectedStatus(rc),
    }
}

const MakeOpenDirAccessMaskWOptions = struct {
    no_follow: bool,
    create_disposition: u32,
};

fn dirClose(userdata: ?*anyopaque, dir: Io.Dir) void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    posix.close(dir.handle);
}

fn dirOpenDirWasi(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    options: Io.Dir.OpenOptions,
) Io.Dir.OpenError!Io.Dir {
    if (builtin.link_libc) return dirOpenDirPosix(userdata, dir, sub_path, options);
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const wasi = std.os.wasi;

    var base: std.os.wasi.rights_t = .{
        .FD_FILESTAT_GET = true,
        .FD_FDSTAT_SET_FLAGS = true,
        .FD_FILESTAT_SET_TIMES = true,
    };
    if (options.access_sub_paths) {
        base.FD_READDIR = true;
        base.PATH_CREATE_DIRECTORY = true;
        base.PATH_CREATE_FILE = true;
        base.PATH_LINK_SOURCE = true;
        base.PATH_LINK_TARGET = true;
        base.PATH_OPEN = true;
        base.PATH_READLINK = true;
        base.PATH_RENAME_SOURCE = true;
        base.PATH_RENAME_TARGET = true;
        base.PATH_FILESTAT_GET = true;
        base.PATH_FILESTAT_SET_SIZE = true;
        base.PATH_FILESTAT_SET_TIMES = true;
        base.PATH_SYMLINK = true;
        base.PATH_REMOVE_DIRECTORY = true;
        base.PATH_UNLINK_FILE = true;
    }

    const lookup_flags: wasi.lookupflags_t = .{ .SYMLINK_FOLLOW = options.follow_symlinks };
    const oflags: wasi.oflags_t = .{ .DIRECTORY = true };
    const fdflags: wasi.fdflags_t = .{};
    var fd: posix.fd_t = undefined;

    while (true) {
        try t.checkCancel();
        switch (wasi.path_open(dir.handle, lookup_flags, sub_path.ptr, sub_path.len, oflags, base, base, fdflags, &fd)) {
            .SUCCESS => return .{ .handle = fd },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .FAULT => |err| return errnoBug(err),
            .INVAL => return error.BadPathName,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .ACCES => return error.AccessDenied,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NODEV => return error.NoDevice,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .PERM => return error.PermissionDenied,
            .BUSY => return error.DeviceBusy,
            .NOTCAPABLE => return error.AccessDenied,
            .ILSEQ => return error.BadPathName,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn fileClose(userdata: ?*anyopaque, file: Io.File) void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    posix.close(file.handle);
}

const fileReadStreaming = switch (native_os) {
    .windows => fileReadStreamingWindows,
    else => fileReadStreamingPosix,
};

fn fileReadStreamingPosix(userdata: ?*anyopaque, file: Io.File, data: [][]u8) Io.File.Reader.Error!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

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

    if (native_os == .wasi and !builtin.link_libc) while (true) {
        try t.checkCancel();
        var nread: usize = undefined;
        switch (std.os.wasi.fd_read(file.handle, dest.ptr, dest.len, &nread)) {
            .SUCCESS => return nread,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .BADF => return error.NotOpenForReading, // File operation on directory.
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.Timeout,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    while (true) {
        try t.checkCancel();
        const rc = posix.system.readv(file.handle, dest.ptr, @intCast(dest.len));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => |err| {
                if (native_os == .wasi) return error.NotOpenForReading; // File operation on directory.
                return errnoBug(err); // File descriptor used after closed.
            },
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.Timeout,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn fileReadStreamingWindows(userdata: ?*anyopaque, file: Io.File, data: [][]u8) Io.File.Reader.Error!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const DWORD = windows.DWORD;
    var index: usize = 0;
    while (data[index].len == 0) index += 1;
    const buffer = data[index];
    const want_read_count: DWORD = @min(std.math.maxInt(DWORD), buffer.len);

    while (true) {
        try t.checkCancel();
        var n: DWORD = undefined;
        if (windows.kernel32.ReadFile(file.handle, buffer.ptr, want_read_count, &n, null) != 0)
            return n;
        switch (windows.GetLastError()) {
            .IO_PENDING => |err| return windows.errorBug(err),
            .OPERATION_ABORTED => continue,
            .BROKEN_PIPE => return 0,
            .HANDLE_EOF => return 0,
            .NETNAME_DELETED => return error.ConnectionResetByPeer,
            .LOCK_VIOLATION => return error.LockViolation,
            .ACCESS_DENIED => return error.AccessDenied,
            .INVALID_HANDLE => return error.NotOpenForReading,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

fn fileReadPositionalPosix(userdata: ?*anyopaque, file: Io.File, data: [][]u8, offset: u64) Io.File.ReadPositionalError!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    if (!have_preadv) @compileError("TODO");

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

    if (native_os == .wasi and !builtin.link_libc) while (true) {
        try t.checkCancel();
        var nread: usize = undefined;
        switch (std.os.wasi.fd_pread(file.handle, dest.ptr, dest.len, offset, &nread)) {
            .SUCCESS => return nread,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .AGAIN => |err| return errnoBug(err),
            .BADF => return error.NotOpenForReading, // File operation on directory.
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.Timeout,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    while (true) {
        try t.checkCancel();
        const rc = preadv_sym(file.handle, dest.ptr, @intCast(dest.len), @bitCast(offset));
        switch (posix.errno(rc)) {
            .SUCCESS => return @bitCast(rc),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => |err| {
                if (native_os == .wasi) return error.NotOpenForReading; // File operation on directory.
                return errnoBug(err); // File descriptor used after closed.
            },
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.Timeout,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

const fileReadPositional = switch (native_os) {
    .windows => fileReadPositionalWindows,
    else => fileReadPositionalPosix,
};

fn fileReadPositionalWindows(userdata: ?*anyopaque, file: Io.File, data: [][]u8, offset: u64) Io.File.ReadPositionalError!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const DWORD = windows.DWORD;

    var index: usize = 0;
    while (data[index].len == 0) index += 1;
    const buffer = data[index];
    const want_read_count: DWORD = @min(std.math.maxInt(DWORD), buffer.len);

    var overlapped: windows.OVERLAPPED = .{
        .Internal = 0,
        .InternalHigh = 0,
        .DUMMYUNIONNAME = .{
            .DUMMYSTRUCTNAME = .{
                .Offset = @truncate(offset),
                .OffsetHigh = @truncate(offset >> 32),
            },
        },
        .hEvent = null,
    };

    while (true) {
        try t.checkCancel();
        var n: DWORD = undefined;
        if (windows.kernel32.ReadFile(file.handle, buffer.ptr, want_read_count, &n, &overlapped) != 0)
            return n;
        switch (windows.GetLastError()) {
            .IO_PENDING => |err| return windows.errorBug(err),
            .OPERATION_ABORTED => continue,
            .BROKEN_PIPE => return 0,
            .HANDLE_EOF => return 0,
            .NETNAME_DELETED => return error.ConnectionResetByPeer,
            .LOCK_VIOLATION => return error.LockViolation,
            .ACCESS_DENIED => return error.AccessDenied,
            .INVALID_HANDLE => return error.NotOpenForReading,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

fn fileSeekBy(userdata: ?*anyopaque, file: Io.File, offset: i64) Io.File.SeekError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    try t.checkCancel();

    _ = file;
    _ = offset;
    @panic("TODO implement fileSeekBy");
}

fn fileSeekTo(userdata: ?*anyopaque, file: Io.File, offset: u64) Io.File.SeekError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const fd = file.handle;

    if (native_os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) while (true) {
        try t.checkCancel();
        var result: u64 = undefined;
        switch (posix.errno(posix.system.llseek(fd, offset, &result, posix.SEEK.SET))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    if (native_os == .windows) {
        try t.checkCancel();
        return windows.SetFilePointerEx_BEGIN(fd, offset);
    }

    if (native_os == .wasi and !builtin.link_libc) while (true) {
        try t.checkCancel();
        var new_offset: std.os.wasi.filesize_t = undefined;
        switch (std.os.wasi.fd_seek(fd, @bitCast(offset), .SET, &new_offset)) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    if (posix.SEEK == void) return error.Unseekable;

    while (true) {
        try t.checkCancel();
        switch (posix.errno(lseek_sym(fd, @bitCast(offset), posix.SEEK.SET))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn openSelfExe(userdata: ?*anyopaque, flags: Io.File.OpenFlags) Io.File.OpenSelfExeError!Io.File {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    switch (native_os) {
        .linux, .serenity => return dirOpenFilePosix(t, .{ .handle = posix.AT.FDCWD }, "/proc/self/exe", flags),
        .windows => {
            // If ImagePathName is a symlink, then it will contain the path of the symlink,
            // not the path that the symlink points to. However, because we are opening
            // the file, we can let the openFileW call follow the symlink for us.
            const image_path_unicode_string = &windows.peb().ProcessParameters.ImagePathName;
            const image_path_name = image_path_unicode_string.Buffer.?[0 .. image_path_unicode_string.Length / 2 :0];
            const prefixed_path_w = try windows.wToPrefixedFileW(null, image_path_name);
            return dirOpenFileWtf16(t, null, prefixed_path_w.span(), flags);
        },
        else => @panic("TODO implement openSelfExe"),
    }
}

fn fileWritePositional(
    userdata: ?*anyopaque,
    file: Io.File,
    buffer: [][]const u8,
    offset: u64,
) Io.File.WritePositionalError!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    while (true) {
        try t.checkCancel();
        _ = file;
        _ = buffer;
        _ = offset;
        @panic("TODO implement fileWritePositional");
    }
}

fn fileWriteStreaming(userdata: ?*anyopaque, file: Io.File, buffer: [][]const u8) Io.File.WriteStreamingError!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    while (true) {
        try t.checkCancel();
        _ = file;
        _ = buffer;
        @panic("TODO implement fileWriteStreaming");
    }
}

fn nowPosix(userdata: ?*anyopaque, clock: Io.Clock) Io.Clock.Error!Io.Timestamp {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    const clock_id: posix.clockid_t = clockToPosix(clock);
    var tp: posix.timespec = undefined;
    switch (posix.errno(posix.system.clock_gettime(clock_id, &tp))) {
        .SUCCESS => return timestampFromPosix(&tp),
        .INVAL => return error.UnsupportedClock,
        else => |err| return posix.unexpectedErrno(err),
    }
}

const now = switch (native_os) {
    .windows => nowWindows,
    .wasi => nowWasi,
    else => nowPosix,
};

fn nowWindows(userdata: ?*anyopaque, clock: Io.Clock) Io.Clock.Error!Io.Timestamp {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    switch (clock) {
        .real => {
            // RtlGetSystemTimePrecise() has a granularity of 100 nanoseconds
            // and uses the NTFS/Windows epoch, which is 1601-01-01.
            const epoch_ns = std.time.epoch.windows * std.time.ns_per_s;
            return .{ .nanoseconds = @as(i96, windows.ntdll.RtlGetSystemTimePrecise()) * 100 + epoch_ns };
        },
        .awake, .boot => {
            // QPC on windows doesn't fail on >= XP/2000 and includes time suspended.
            const qpc = windows.QueryPerformanceCounter();
            // We don't need to cache QPF as it's internally just a memory read to KUSER_SHARED_DATA
            // (a read-only page of info updated and mapped by the kernel to all processes):
            // https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/ntddk/ns-ntddk-kuser_shared_data
            // https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
            const qpf = windows.QueryPerformanceFrequency();

            // 10Mhz (1 qpc tick every 100ns) is a common enough QPF value that we can optimize on it.
            // https://github.com/microsoft/STL/blob/785143a0c73f030238ef618890fd4d6ae2b3a3a0/stl/inc/chrono#L694-L701
            const common_qpf = 10_000_000;
            if (qpf == common_qpf) return .{ .nanoseconds = qpc * (std.time.ns_per_s / common_qpf) };

            // Convert to ns using fixed point.
            const scale = @as(u64, std.time.ns_per_s << 32) / @as(u32, @intCast(qpf));
            const result = (@as(u96, qpc) * scale) >> 32;
            return .{ .nanoseconds = @intCast(result) };
        },
        .cpu_process,
        .cpu_thread,
        => return error.UnsupportedClock,
    }
}

fn nowWasi(userdata: ?*anyopaque, clock: Io.Clock) Io.Clock.Error!Io.Timestamp {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    var ns: std.os.wasi.timestamp_t = undefined;
    const err = std.os.wasi.clock_time_get(clockToWasi(clock), 1, &ns);
    if (err != .SUCCESS) return error.Unexpected;
    return .fromNanoseconds(ns);
}

const sleep = switch (native_os) {
    .windows => sleepWindows,
    .wasi => sleepWasi,
    .linux => sleepLinux,
    else => sleepPosix,
};

fn sleepLinux(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const clock_id: posix.clockid_t = clockToPosix(switch (timeout) {
        .none => .awake,
        .duration => |d| d.clock,
        .deadline => |d| d.clock,
    });
    const deadline_nanoseconds: i96 = switch (timeout) {
        .none => std.math.maxInt(i96),
        .duration => |duration| duration.raw.nanoseconds,
        .deadline => |deadline| deadline.raw.nanoseconds,
    };
    var timespec: posix.timespec = timestampToPosix(deadline_nanoseconds);
    while (true) {
        try t.checkCancel();
        switch (std.os.linux.errno(std.os.linux.clock_nanosleep(clock_id, .{ .ABSTIME = switch (timeout) {
            .none, .duration => false,
            .deadline => true,
        } }, &timespec, &timespec))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,
            .INVAL => return error.UnsupportedClock,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn sleepWindows(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    try t.checkCancel();
    const ms = ms: {
        const d = (try timeout.toDurationFromNow(t_io)) orelse
            break :ms std.math.maxInt(windows.DWORD);
        break :ms std.math.lossyCast(windows.DWORD, d.raw.toMilliseconds());
    };
    // TODO: alertable true with checkCancel in a loop plus deadline
    _ = windows.kernel32.SleepEx(ms, windows.FALSE);
}

fn sleepWasi(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    try t.checkCancel();

    const w = std.os.wasi;

    const clock: w.subscription_clock_t = if (try timeout.toDurationFromNow(t_io)) |d| .{
        .id = clockToWasi(d.clock),
        .timeout = std.math.lossyCast(u64, d.raw.nanoseconds),
        .precision = 0,
        .flags = 0,
    } else .{
        .id = .MONOTONIC,
        .timeout = std.math.maxInt(u64),
        .precision = 0,
        .flags = 0,
    };
    const in: w.subscription_t = .{
        .userdata = 0,
        .u = .{
            .tag = .CLOCK,
            .u = .{ .clock = clock },
        },
    };
    var event: w.event_t = undefined;
    var nevents: usize = undefined;
    _ = w.poll_oneoff(&in, &event, 1, &nevents);
}

fn sleepPosix(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    const sec_type = @typeInfo(posix.timespec).@"struct".fields[0].type;
    const nsec_type = @typeInfo(posix.timespec).@"struct".fields[1].type;

    var timespec: posix.timespec = t: {
        const d = (try timeout.toDurationFromNow(t_io)) orelse break :t .{
            .sec = std.math.maxInt(sec_type),
            .nsec = std.math.maxInt(nsec_type),
        };
        break :t timestampToPosix(d.raw.toNanoseconds());
    };
    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.nanosleep(&timespec, &timespec))) {
            .INTR => continue,
            .CANCELED => return error.Canceled,
            else => return, // This prong handles success as well as unexpected errors.
        }
    }
}

fn select(userdata: ?*anyopaque, futures: []const *Io.AnyFuture) Io.Cancelable!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var reset_event: ResetEvent = .unset;

    for (futures, 0..) |future, i| {
        const closure: *AsyncClosure = @ptrCast(@alignCast(future));
        if (@atomicRmw(?*ResetEvent, &closure.select_condition, .Xchg, &reset_event, .seq_cst) == AsyncClosure.done_reset_event) {
            for (futures[0..i]) |cleanup_future| {
                const cleanup_closure: *AsyncClosure = @ptrCast(@alignCast(cleanup_future));
                if (@atomicRmw(?*ResetEvent, &cleanup_closure.select_condition, .Xchg, null, .seq_cst) == AsyncClosure.done_reset_event) {
                    cleanup_closure.reset_event.waitUncancelable(); // Ensure no reference to our stack-allocated reset_event.
                }
            }
            return i;
        }
    }

    try reset_event.wait(t);

    var result: ?usize = null;
    for (futures, 0..) |future, i| {
        const closure: *AsyncClosure = @ptrCast(@alignCast(future));
        if (@atomicRmw(?*ResetEvent, &closure.select_condition, .Xchg, null, .seq_cst) == AsyncClosure.done_reset_event) {
            closure.reset_event.waitUncancelable(); // Ensure no reference to our stack-allocated reset_event.
            if (result == null) result = i; // In case multiple are ready, return first.
        }
    }
    return result.?;
}

fn netListenIpPosix(
    userdata: ?*anyopaque,
    address: IpAddress,
    options: IpAddress.ListenOptions,
) IpAddress.ListenError!net.Server {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(&address);
    const socket_fd = try openSocketPosix(t, family, .{
        .mode = options.mode,
        .protocol = options.protocol,
    });
    errdefer posix.close(socket_fd);

    if (options.reuse_address) {
        try setSocketOption(t, socket_fd, posix.SOL.SOCKET, posix.SO.REUSEADDR, 1);
        if (@hasDecl(posix.SO, "REUSEPORT"))
            try setSocketOption(t, socket_fd, posix.SOL.SOCKET, posix.SO.REUSEPORT, 1);
    }

    var storage: PosixAddress = undefined;
    var addr_len = addressToPosix(&address, &storage);
    try posixBind(t, socket_fd, &storage.any, addr_len);

    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.listen(socket_fd, options.kernel_backlog))) {
            .SUCCESS => break,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    try posixGetSockName(t, socket_fd, &storage.any, &addr_len);
    return .{
        .socket = .{
            .handle = socket_fd,
            .address = addressFromPosix(&storage),
        },
    };
}

fn netListenIpWindows(
    userdata: ?*anyopaque,
    address: IpAddress,
    options: IpAddress.ListenOptions,
) IpAddress.ListenError!net.Server {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(&address);
    const socket_handle = try openSocketWsa(t, family, .{
        .mode = options.mode,
        .protocol = options.protocol,
    });
    errdefer closeSocketWindows(socket_handle);

    if (options.reuse_address)
        try setSocketOptionWsa(t, socket_handle, posix.SOL.SOCKET, posix.SO.REUSEADDR, 1);

    var storage: WsaAddress = undefined;
    var addr_len = addressToWsa(&address, &storage);

    while (true) {
        try t.checkCancel();
        const rc = ws2_32.bind(socket_handle, &storage.any, addr_len);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .EADDRINUSE => return error.AddressInUse,
            .EADDRNOTAVAIL => return error.AddressUnavailable,
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EFAULT => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .ENOBUFS => return error.SystemResources,
            .ENETDOWN => return error.NetworkDown,
            else => |err| return windows.unexpectedWSAError(err),
        }
    }

    while (true) {
        try t.checkCancel();
        const rc = ws2_32.listen(socket_handle, options.kernel_backlog);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .ENETDOWN => return error.NetworkDown,
            .EADDRINUSE => return error.AddressInUse,
            .EISCONN => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .EMFILE, .ENOBUFS => return error.SystemResources,
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EOPNOTSUPP => |err| return wsaErrorBug(err),
            .EINPROGRESS => |err| return wsaErrorBug(err),
            else => |err| return windows.unexpectedWSAError(err),
        }
    }

    try wsaGetSockName(t, socket_handle, &storage.any, &addr_len);

    return .{
        .socket = .{
            .handle = socket_handle,
            .address = addressFromWsa(&storage),
        },
    };
}

fn netListenIpUnavailable(
    userdata: ?*anyopaque,
    address: IpAddress,
    options: IpAddress.ListenOptions,
) IpAddress.ListenError!net.Server {
    _ = userdata;
    _ = address;
    _ = options;
    return error.NetworkDown;
}

fn netListenUnixPosix(
    userdata: ?*anyopaque,
    address: *const net.UnixAddress,
    options: net.UnixAddress.ListenOptions,
) net.UnixAddress.ListenError!net.Socket.Handle {
    if (!net.has_unix_sockets) return error.AddressFamilyUnsupported;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const socket_fd = openSocketPosix(t, posix.AF.UNIX, .{ .mode = .stream }) catch |err| switch (err) {
        error.ProtocolUnsupportedBySystem => return error.AddressFamilyUnsupported,
        error.ProtocolUnsupportedByAddressFamily => return error.AddressFamilyUnsupported,
        error.SocketModeUnsupported => return error.AddressFamilyUnsupported,
        error.OptionUnsupported => return error.Unexpected,
        else => |e| return e,
    };
    errdefer posix.close(socket_fd);

    var storage: UnixAddress = undefined;
    const addr_len = addressUnixToPosix(address, &storage);
    try posixBindUnix(t, socket_fd, &storage.any, addr_len);

    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.listen(socket_fd, options.kernel_backlog))) {
            .SUCCESS => break,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    return socket_fd;
}

fn netListenUnixWindows(
    userdata: ?*anyopaque,
    address: *const net.UnixAddress,
    options: net.UnixAddress.ListenOptions,
) net.UnixAddress.ListenError!net.Socket.Handle {
    if (!net.has_unix_sockets) return error.AddressFamilyUnsupported;
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const socket_handle = openSocketWsa(t, posix.AF.UNIX, .{ .mode = .stream }) catch |err| switch (err) {
        error.ProtocolUnsupportedByAddressFamily => return error.AddressFamilyUnsupported,
        else => |e| return e,
    };
    errdefer closeSocketWindows(socket_handle);

    var storage: WsaAddress = undefined;
    const addr_len = addressUnixToWsa(address, &storage);

    while (true) {
        try t.checkCancel();
        const rc = ws2_32.bind(socket_handle, &storage.any, addr_len);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .EADDRINUSE => return error.AddressInUse,
            .EADDRNOTAVAIL => return error.AddressUnavailable,
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EFAULT => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .ENOBUFS => return error.SystemResources,
            .ENETDOWN => return error.NetworkDown,
            else => |err| return windows.unexpectedWSAError(err),
        }
    }

    while (true) {
        try t.checkCancel();
        const rc = ws2_32.listen(socket_handle, options.kernel_backlog);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .ENETDOWN => return error.NetworkDown,
            .EADDRINUSE => return error.AddressInUse,
            .EISCONN => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .EMFILE, .ENOBUFS => return error.SystemResources,
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EOPNOTSUPP => |err| return wsaErrorBug(err),
            .EINPROGRESS => |err| return wsaErrorBug(err),
            else => |err| return windows.unexpectedWSAError(err),
        }
    }

    return socket_handle;
}

fn netListenUnixUnavailable(
    userdata: ?*anyopaque,
    address: *const net.UnixAddress,
    options: net.UnixAddress.ListenOptions,
) net.UnixAddress.ListenError!net.Socket.Handle {
    _ = userdata;
    _ = address;
    _ = options;
    return error.AddressFamilyUnsupported;
}

fn posixBindUnix(t: *Threaded, fd: posix.socket_t, addr: *const posix.sockaddr, addr_len: posix.socklen_t) !void {
    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.bind(fd, addr, addr_len))) {
            .SUCCESS => break,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ACCES => return error.AccessDenied,
            .ADDRINUSE => return error.AddressInUse,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .ADDRNOTAVAIL => return error.AddressUnavailable,
            .NOMEM => return error.SystemResources,

            .LOOP => return error.SymLinkLoop,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            .PERM => return error.PermissionDenied,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .INVAL => |err| return errnoBug(err), // invalid parameters
            .NOTSOCK => |err| return errnoBug(err), // invalid `sockfd`
            .FAULT => |err| return errnoBug(err), // invalid `addr` pointer
            .NAMETOOLONG => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn posixBind(t: *Threaded, socket_fd: posix.socket_t, addr: *const posix.sockaddr, addr_len: posix.socklen_t) !void {
    while (true) {
        try t.checkCancel();
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

fn posixConnect(t: *Threaded, socket_fd: posix.socket_t, addr: *const posix.sockaddr, addr_len: posix.socklen_t) !void {
    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.connect(socket_fd, addr, addr_len))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ADDRNOTAVAIL => return error.AddressUnavailable,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .AGAIN, .INPROGRESS => return error.WouldBlock,
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

fn posixConnectUnix(t: *Threaded, fd: posix.socket_t, addr: *const posix.sockaddr, addr_len: posix.socklen_t) !void {
    while (true) {
        try t.checkCancel();
        switch (posix.errno(posix.system.connect(fd, addr, addr_len))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .AGAIN => return error.WouldBlock,
            .INPROGRESS => return error.WouldBlock,
            .ACCES => return error.AccessDenied,

            .LOOP => return error.SymLinkLoop,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            .PERM => return error.PermissionDenied,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .CONNABORTED => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .ISCONN => |err| return errnoBug(err),
            .NOTSOCK => |err| return errnoBug(err),
            .PROTOTYPE => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn posixGetSockName(t: *Threaded, socket_fd: posix.fd_t, addr: *posix.sockaddr, addr_len: *posix.socklen_t) !void {
    while (true) {
        try t.checkCancel();
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

fn wsaGetSockName(t: *Threaded, handle: ws2_32.SOCKET, addr: *ws2_32.sockaddr, addr_len: *i32) !void {
    while (true) {
        try t.checkCancel();
        const rc = ws2_32.getsockname(handle, addr, addr_len);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .ENETDOWN => return error.NetworkDown,
            .EFAULT => |err| return wsaErrorBug(err),
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            else => |err| return windows.unexpectedWSAError(err),
        }
    }
}

fn setSocketOption(t: *Threaded, fd: posix.fd_t, level: i32, opt_name: u32, option: u32) !void {
    const o: []const u8 = @ptrCast(&option);
    while (true) {
        try t.checkCancel();
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

fn setSocketOptionWsa(t: *Threaded, socket: Io.net.Socket.Handle, level: i32, opt_name: u32, option: u32) !void {
    const o: []const u8 = @ptrCast(&option);
    const rc = ws2_32.setsockopt(socket, level, @bitCast(opt_name), o.ptr, @intCast(o.len));
    while (true) {
        if (rc != ws2_32.SOCKET_ERROR) return;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .ENETDOWN => return error.NetworkDown,
            .EFAULT => |err| return wsaErrorBug(err),
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            else => |err| return windows.unexpectedWSAError(err),
        }
    }
}

fn netConnectIpPosix(
    userdata: ?*anyopaque,
    address: *const IpAddress,
    options: IpAddress.ConnectOptions,
) IpAddress.ConnectError!net.Stream {
    if (!have_networking) return error.NetworkDown;
    if (options.timeout != .none) @panic("TODO implement netConnectIpPosix with timeout");
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(address);
    const socket_fd = try openSocketPosix(t, family, .{
        .mode = options.mode,
        .protocol = options.protocol,
    });
    errdefer posix.close(socket_fd);
    var storage: PosixAddress = undefined;
    var addr_len = addressToPosix(address, &storage);
    try posixConnect(t, socket_fd, &storage.any, addr_len);
    try posixGetSockName(t, socket_fd, &storage.any, &addr_len);
    return .{ .socket = .{
        .handle = socket_fd,
        .address = addressFromPosix(&storage),
    } };
}

fn netConnectIpWindows(
    userdata: ?*anyopaque,
    address: *const IpAddress,
    options: IpAddress.ConnectOptions,
) IpAddress.ConnectError!net.Stream {
    if (!have_networking) return error.NetworkDown;
    if (options.timeout != .none) @panic("TODO implement netConnectIpWindows with timeout");
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(address);
    const socket_handle = try openSocketWsa(t, family, .{
        .mode = options.mode,
        .protocol = options.protocol,
    });
    errdefer closeSocketWindows(socket_handle);

    var storage: WsaAddress = undefined;
    var addr_len = addressToWsa(address, &storage);

    while (true) {
        const rc = ws2_32.connect(socket_handle, &storage.any, addr_len);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },

            .EADDRNOTAVAIL => return error.AddressUnavailable,
            .ECONNREFUSED => return error.ConnectionRefused,
            .ECONNRESET => return error.ConnectionResetByPeer,
            .ETIMEDOUT => return error.Timeout,
            .EHOSTUNREACH => return error.HostUnreachable,
            .ENETUNREACH => return error.NetworkUnreachable,
            .EFAULT => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .EISCONN => |err| return wsaErrorBug(err),
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EWOULDBLOCK => return error.WouldBlock,
            .EACCES => return error.AccessDenied,
            .ENOBUFS => return error.SystemResources,
            .EAFNOSUPPORT => return error.AddressFamilyUnsupported,
            else => |err| return windows.unexpectedWSAError(err),
        }
    }

    try wsaGetSockName(t, socket_handle, &storage.any, &addr_len);

    return .{ .socket = .{
        .handle = socket_handle,
        .address = addressFromWsa(&storage),
    } };
}

fn netConnectIpUnavailable(
    userdata: ?*anyopaque,
    address: *const IpAddress,
    options: IpAddress.ConnectOptions,
) IpAddress.ConnectError!net.Stream {
    _ = userdata;
    _ = address;
    _ = options;
    return error.NetworkDown;
}

fn netConnectUnixPosix(
    userdata: ?*anyopaque,
    address: *const net.UnixAddress,
) net.UnixAddress.ConnectError!net.Socket.Handle {
    if (!net.has_unix_sockets) return error.AddressFamilyUnsupported;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const socket_fd = openSocketPosix(t, posix.AF.UNIX, .{ .mode = .stream }) catch |err| switch (err) {
        error.OptionUnsupported => return error.Unexpected,
        else => |e| return e,
    };
    errdefer posix.close(socket_fd);
    var storage: UnixAddress = undefined;
    const addr_len = addressUnixToPosix(address, &storage);
    try posixConnectUnix(t, socket_fd, &storage.any, addr_len);
    return socket_fd;
}

fn netConnectUnixWindows(
    userdata: ?*anyopaque,
    address: *const net.UnixAddress,
) net.UnixAddress.ConnectError!net.Socket.Handle {
    if (!net.has_unix_sockets) return error.AddressFamilyUnsupported;
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const socket_handle = try openSocketWsa(t, posix.AF.UNIX, .{ .mode = .stream });
    errdefer closeSocketWindows(socket_handle);
    var storage: WsaAddress = undefined;
    const addr_len = addressUnixToWsa(address, &storage);

    while (true) {
        const rc = ws2_32.connect(socket_handle, &storage.any, addr_len);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },

            .ECONNREFUSED => return error.FileNotFound,
            .EFAULT => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .EISCONN => |err| return wsaErrorBug(err),
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EWOULDBLOCK => return error.WouldBlock,
            .EACCES => return error.AccessDenied,
            .ENOBUFS => return error.SystemResources,
            .EAFNOSUPPORT => return error.AddressFamilyUnsupported,
            else => |err| return windows.unexpectedWSAError(err),
        }
    }

    return socket_handle;
}

fn netConnectUnixUnavailable(
    userdata: ?*anyopaque,
    address: *const net.UnixAddress,
) net.UnixAddress.ConnectError!net.Socket.Handle {
    _ = userdata;
    _ = address;
    return error.AddressFamilyUnsupported;
}

fn netBindIpPosix(
    userdata: ?*anyopaque,
    address: *const IpAddress,
    options: IpAddress.BindOptions,
) IpAddress.BindError!net.Socket {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(address);
    const socket_fd = try openSocketPosix(t, family, options);
    errdefer posix.close(socket_fd);
    var storage: PosixAddress = undefined;
    var addr_len = addressToPosix(address, &storage);
    try posixBind(t, socket_fd, &storage.any, addr_len);
    try posixGetSockName(t, socket_fd, &storage.any, &addr_len);
    return .{
        .handle = socket_fd,
        .address = addressFromPosix(&storage),
    };
}

fn netBindIpWindows(
    userdata: ?*anyopaque,
    address: *const IpAddress,
    options: IpAddress.BindOptions,
) IpAddress.BindError!net.Socket {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(address);
    const socket_handle = try openSocketWsa(t, family, .{
        .mode = options.mode,
        .protocol = options.protocol,
    });
    errdefer closeSocketWindows(socket_handle);

    var storage: WsaAddress = undefined;
    var addr_len = addressToWsa(address, &storage);

    while (true) {
        try t.checkCancel();
        const rc = ws2_32.bind(socket_handle, &storage.any, addr_len);
        if (rc != ws2_32.SOCKET_ERROR) break;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .EADDRINUSE => return error.AddressInUse,
            .EADDRNOTAVAIL => return error.AddressUnavailable,
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EFAULT => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .ENOBUFS => return error.SystemResources,
            .ENETDOWN => return error.NetworkDown,
            else => |err| return windows.unexpectedWSAError(err),
        }
    }

    try wsaGetSockName(t, socket_handle, &storage.any, &addr_len);

    return .{
        .handle = socket_handle,
        .address = addressFromWsa(&storage),
    };
}

fn netBindIpUnavailable(
    userdata: ?*anyopaque,
    address: *const IpAddress,
    options: IpAddress.BindOptions,
) IpAddress.BindError!net.Socket {
    _ = userdata;
    _ = address;
    _ = options;
    return error.NetworkDown;
}

fn openSocketPosix(
    t: *Threaded,
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
    const mode = posixSocketMode(options.mode);
    const protocol = posixProtocol(options.protocol);
    const socket_fd = while (true) {
        try t.checkCancel();
        const flags: u32 = mode | if (socket_flags_unsupported) 0 else posix.SOCK.CLOEXEC;
        const socket_rc = posix.system.socket(family, flags, protocol);
        switch (posix.errno(socket_rc)) {
            .SUCCESS => {
                const fd: posix.fd_t = @intCast(socket_rc);
                errdefer posix.close(fd);
                if (socket_flags_unsupported) while (true) {
                    try t.checkCancel();
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC)))) {
                        .SUCCESS => break,
                        .INTR => continue,
                        .CANCELED => return error.Canceled,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                };
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
        try setSocketOption(t, socket_fd, posix.IPPROTO.IPV6, posix.IPV6.V6ONLY, 0);
    }

    return socket_fd;
}

fn openSocketWsa(t: *Threaded, family: posix.sa_family_t, options: IpAddress.BindOptions) !ws2_32.SOCKET {
    const mode = posixSocketMode(options.mode);
    const protocol = posixProtocol(options.protocol);
    const flags: u32 = ws2_32.WSA_FLAG_OVERLAPPED | ws2_32.WSA_FLAG_NO_HANDLE_INHERIT;
    while (true) {
        try t.checkCancel();
        const rc = ws2_32.WSASocketW(family, @bitCast(mode), @bitCast(protocol), null, 0, flags);
        if (rc != ws2_32.INVALID_SOCKET) return rc;
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .EAFNOSUPPORT => return error.AddressFamilyUnsupported,
            .EMFILE => return error.ProcessFdQuotaExceeded,
            .ENOBUFS => return error.SystemResources,
            .EPROTONOSUPPORT => return error.ProtocolUnsupportedByAddressFamily,
            else => |err| return windows.unexpectedWSAError(err),
        }
    }
}

fn netAcceptPosix(userdata: ?*anyopaque, listen_fd: net.Socket.Handle) net.Server.AcceptError!net.Stream {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    var storage: PosixAddress = undefined;
    var addr_len: posix.socklen_t = @sizeOf(PosixAddress);
    const fd = while (true) {
        try t.checkCancel();
        const rc = if (have_accept4)
            posix.system.accept4(listen_fd, &storage.any, &addr_len, posix.SOCK.CLOEXEC)
        else
            posix.system.accept(listen_fd, &storage.any, &addr_len);
        switch (posix.errno(rc)) {
            .SUCCESS => {
                const fd: posix.fd_t = @intCast(rc);
                errdefer posix.close(fd);
                if (!have_accept4) while (true) {
                    try t.checkCancel();
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC)))) {
                        .SUCCESS => break,
                        .INTR => continue,
                        .CANCELED => return error.Canceled,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                };
                break fd;
            },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .AGAIN => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .CONNABORTED => return error.ConnectionAborted,
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err),
            .NOTSOCK => |err| return errnoBug(err),
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .OPNOTSUPP => |err| return errnoBug(err),
            .PROTO => return error.ProtocolFailure,
            .PERM => return error.BlockedByFirewall,
            else => |err| return posix.unexpectedErrno(err),
        }
    };
    return .{ .socket = .{
        .handle = fd,
        .address = addressFromPosix(&storage),
    } };
}

fn netAcceptWindows(userdata: ?*anyopaque, listen_handle: net.Socket.Handle) net.Server.AcceptError!net.Stream {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    var storage: WsaAddress = undefined;
    var addr_len: i32 = @sizeOf(WsaAddress);
    while (true) {
        try t.checkCancel();
        const rc = ws2_32.accept(listen_handle, &storage.any, &addr_len);
        if (rc != ws2_32.INVALID_SOCKET) return .{ .socket = .{
            .handle = rc,
            .address = addressFromWsa(&storage),
        } };
        switch (ws2_32.WSAGetLastError()) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },
            .ECONNRESET => return error.ConnectionAborted,
            .EFAULT => |err| return wsaErrorBug(err),
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EINVAL => |err| return wsaErrorBug(err),
            .EMFILE => return error.ProcessFdQuotaExceeded,
            .ENETDOWN => return error.NetworkDown,
            .ENOBUFS => return error.SystemResources,
            .EOPNOTSUPP => |err| return wsaErrorBug(err),
            else => |err| return windows.unexpectedWSAError(err),
        }
    }
}

fn netAcceptUnavailable(userdata: ?*anyopaque, listen_handle: net.Socket.Handle) net.Server.AcceptError!net.Stream {
    _ = userdata;
    _ = listen_handle;
    return error.NetworkDown;
}

fn netReadPosix(userdata: ?*anyopaque, fd: net.Socket.Handle, data: [][]u8) net.Stream.Reader.Error!usize {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));

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

    if (native_os == .wasi and !builtin.link_libc) while (true) {
        try t.checkCancel();
        var n: usize = undefined;
        switch (std.os.wasi.fd_read(fd, dest.ptr, dest.len, &n)) {
            .SUCCESS => return n,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .AGAIN => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.Timeout,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    while (true) {
        try t.checkCancel();
        const rc = posix.system.readv(fd, dest.ptr, @intCast(dest.len));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .AGAIN => |err| return errnoBug(err),
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

fn netReadWindows(userdata: ?*anyopaque, handle: net.Socket.Handle, data: [][]u8) net.Stream.Reader.Error!usize {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const bufs = b: {
        var iovec_buffer: [max_iovecs_len]ws2_32.WSABUF = undefined;
        var i: usize = 0;
        var n: usize = 0;
        for (data) |buf| {
            if (iovec_buffer.len - i == 0) break;
            if (buf.len == 0) continue;
            if (std.math.cast(u32, buf.len)) |len| {
                iovec_buffer[i] = .{ .buf = buf.ptr, .len = len };
                i += 1;
                n += len;
                continue;
            }
            iovec_buffer[i] = .{ .buf = buf.ptr, .len = std.math.maxInt(u32) };
            i += 1;
            n += std.math.maxInt(u32);
            break;
        }

        const bufs = iovec_buffer[0..i];
        assert(bufs[0].len != 0);

        break :b bufs;
    };

    while (true) {
        try t.checkCancel();

        var flags: u32 = 0;
        var overlapped: windows.OVERLAPPED = std.mem.zeroes(windows.OVERLAPPED);
        var n: u32 = undefined;
        const rc = ws2_32.WSARecv(handle, bufs.ptr, @intCast(bufs.len), &n, &flags, &overlapped, null);
        if (rc != ws2_32.SOCKET_ERROR) return n;
        const wsa_error: ws2_32.WinsockError = switch (ws2_32.WSAGetLastError()) {
            .IO_PENDING => e: {
                var result_flags: u32 = undefined;
                const overlapped_rc = ws2_32.WSAGetOverlappedResult(
                    handle,
                    &overlapped,
                    &n,
                    windows.TRUE,
                    &result_flags,
                );
                if (overlapped_rc == windows.FALSE) {
                    break :e ws2_32.WSAGetLastError();
                } else {
                    return n;
                }
            },
            else => |err| err,
        };
        switch (wsa_error) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },

            .ECONNRESET => return error.ConnectionResetByPeer,
            .EFAULT => unreachable, // a pointer is not completely contained in user address space.
            .EINVAL => |err| return wsaErrorBug(err),
            .EMSGSIZE => |err| return wsaErrorBug(err),
            .ENETDOWN => return error.NetworkDown,
            .ENETRESET => return error.ConnectionResetByPeer,
            .ENOTCONN => return error.SocketUnconnected,
            else => |err| return windows.unexpectedWSAError(err),
        }
    }
}

fn netReadUnavailable(userdata: ?*anyopaque, fd: net.Socket.Handle, data: [][]u8) net.Stream.Reader.Error!usize {
    _ = userdata;
    _ = fd;
    _ = data;
    return error.NetworkDown;
}

fn netSendPosix(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    messages: []net.OutgoingMessage,
    flags: net.SendFlags,
) struct { ?net.Socket.SendError, usize } {
    if (!have_networking) return .{ error.NetworkDown, 0 };
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    const posix_flags: u32 =
        @as(u32, if (@hasDecl(posix.MSG, "CONFIRM") and flags.confirm) posix.MSG.CONFIRM else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "DONTROUTE") and flags.dont_route) posix.MSG.DONTROUTE else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "EOR") and flags.eor) posix.MSG.EOR else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "OOB") and flags.oob) posix.MSG.OOB else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "FASTOPEN") and flags.fastopen) posix.MSG.FASTOPEN else 0) |
        posix.MSG.NOSIGNAL;

    var i: usize = 0;
    while (messages.len - i != 0) {
        if (have_sendmmsg) {
            i += netSendMany(t, handle, messages[i..], posix_flags) catch |err| return .{ err, i };
            continue;
        }
        netSendOne(t, handle, &messages[i], posix_flags) catch |err| return .{ err, i };
        i += 1;
    }
    return .{ null, i };
}

fn netSendWindows(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    messages: []net.OutgoingMessage,
    flags: net.SendFlags,
) struct { ?net.Socket.SendError, usize } {
    if (!have_networking) return .{ error.NetworkDown, 0 };
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    _ = handle;
    _ = messages;
    _ = flags;
    @panic("TODO netSendWindows");
}

fn netSendUnavailable(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    messages: []net.OutgoingMessage,
    flags: net.SendFlags,
) struct { ?net.Socket.SendError, usize } {
    _ = userdata;
    _ = handle;
    _ = messages;
    _ = flags;
    return .{ error.NetworkDown, 0 };
}

fn netSendOne(
    t: *Threaded,
    handle: net.Socket.Handle,
    message: *net.OutgoingMessage,
    flags: u32,
) net.Socket.SendError!void {
    var addr: PosixAddress = undefined;
    var iovec: posix.iovec_const = .{ .base = @constCast(message.data_ptr), .len = message.data_len };
    const msg: posix.msghdr_const = .{
        .name = &addr.any,
        .namelen = addressToPosix(message.address, &addr),
        .iov = (&iovec)[0..1],
        .iovlen = 1,
        // OS returns EINVAL if this pointer is invalid even if controllen is zero.
        .control = if (message.control.len == 0) null else @constCast(message.control.ptr),
        .controllen = @intCast(message.control.len),
        .flags = 0,
    };
    while (true) {
        try t.checkCancel();
        const rc = posix.system.sendmsg(handle, &msg, flags);
        if (is_windows) {
            if (rc == ws2_32.SOCKET_ERROR) {
                switch (ws2_32.WSAGetLastError()) {
                    .EINTR => continue,
                    .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
                    .NOTINITIALISED => {
                        try initializeWsa(t);
                        continue;
                    },
                    .EACCES => return error.AccessDenied,
                    .EADDRNOTAVAIL => return error.AddressUnavailable,
                    .ECONNRESET => return error.ConnectionResetByPeer,
                    .EMSGSIZE => return error.MessageOversize,
                    .ENOBUFS => return error.SystemResources,
                    .ENOTSOCK => return error.FileDescriptorNotASocket,
                    .EAFNOSUPPORT => return error.AddressFamilyUnsupported,
                    .EDESTADDRREQ => unreachable, // A destination address is required.
                    .EFAULT => unreachable, // The lpBuffers, lpTo, lpOverlapped, lpNumberOfBytesSent, or lpCompletionRoutine parameters are not part of the user address space, or the lpTo parameter is too small.
                    .EHOSTUNREACH => return error.NetworkUnreachable,
                    .EINVAL => unreachable,
                    .ENETDOWN => return error.NetworkDown,
                    .ENETRESET => return error.ConnectionResetByPeer,
                    .ENETUNREACH => return error.NetworkUnreachable,
                    .ENOTCONN => return error.SocketUnconnected,
                    .ESHUTDOWN => |err| return wsaErrorBug(err),
                    else => |err| return windows.unexpectedWSAError(err),
                }
            } else {
                message.data_len = @intCast(rc);
                return;
            }
        }
        switch (posix.errno(rc)) {
            .SUCCESS => {
                message.data_len = @intCast(rc);
                return;
            },
            .INTR => continue,
            .CANCELED => return error.Canceled,

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

fn netSendMany(
    t: *Threaded,
    handle: net.Socket.Handle,
    messages: []net.OutgoingMessage,
    flags: u32,
) net.Socket.SendError!usize {
    var msg_buffer: [64]std.os.linux.mmsghdr = undefined;
    var addr_buffer: [msg_buffer.len]PosixAddress = undefined;
    var iovecs_buffer: [msg_buffer.len]posix.iovec = undefined;
    const min_len: usize = @min(messages.len, msg_buffer.len);
    const clamped_messages = messages[0..min_len];
    const clamped_msgs = (&msg_buffer)[0..min_len];
    const clamped_addrs = (&addr_buffer)[0..min_len];
    const clamped_iovecs = (&iovecs_buffer)[0..min_len];

    for (clamped_messages, clamped_msgs, clamped_addrs, clamped_iovecs) |*message, *msg, *addr, *iovec| {
        iovec.* = .{ .base = @constCast(message.data_ptr), .len = message.data_len };
        msg.* = .{
            .hdr = .{
                .name = &addr.any,
                .namelen = addressToPosix(message.address, addr),
                .iov = iovec[0..1],
                .iovlen = 1,
                .control = @constCast(message.control.ptr),
                .controllen = message.control.len,
                .flags = 0,
            },
            .len = undefined, // Populated by calling sendmmsg below.
        };
    }

    while (true) {
        try t.checkCancel();
        const rc = posix.system.sendmmsg(handle, clamped_msgs.ptr, @intCast(clamped_msgs.len), flags);
        switch (posix.errno(rc)) {
            .SUCCESS => {
                const n: usize = @intCast(rc);
                for (clamped_messages[0..n], clamped_msgs[0..n]) |*message, *msg| {
                    message.data_len = msg.len;
                }
                return n;
            },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .AGAIN => |err| return errnoBug(err),
            .ALREADY => return error.FastOpenAlreadyInProgress,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .CONNRESET => return error.ConnectionResetByPeer,
            .DESTADDRREQ => |err| return errnoBug(err), // The socket is not connection-mode, and no peer address is set.
            .FAULT => |err| return errnoBug(err), // An invalid user space address was specified for an argument.
            .INVAL => |err| return errnoBug(err), // Invalid argument passed.
            .ISCONN => |err| return errnoBug(err), // connection-mode socket was connected already but a recipient was specified
            .MSGSIZE => return error.MessageOversize,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTSOCK => |err| return errnoBug(err), // The file descriptor sockfd does not refer to a socket.
            .OPNOTSUPP => |err| return errnoBug(err), // Some bit in the flags argument is inappropriate for the socket type.
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

fn netReceivePosix(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    message_buffer: []net.IncomingMessage,
    data_buffer: []u8,
    flags: net.ReceiveFlags,
    timeout: Io.Timeout,
) struct { ?net.Socket.ReceiveTimeoutError, usize } {
    if (!have_networking) return .{ error.NetworkDown, 0 };
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = io(t);

    // recvmmsg is useless, here's why:
    // * [timeout bug](https://bugzilla.kernel.org/show_bug.cgi?id=75371)
    // * it wants iovecs for each message but we have a better API: one data
    //   buffer to handle all the messages. The better API cannot be lowered to
    //   the split vectors though because reducing the buffer size might make
    //   some messages unreceivable.

    // So the strategy instead is to use non-blocking recvmsg calls, calling
    // poll() with timeout if the first one returns EAGAIN.
    const posix_flags: u32 =
        @as(u32, if (flags.oob) posix.MSG.OOB else 0) |
        @as(u32, if (flags.peek) posix.MSG.PEEK else 0) |
        @as(u32, if (flags.trunc) posix.MSG.TRUNC else 0) |
        posix.MSG.DONTWAIT | posix.MSG.NOSIGNAL;

    var poll_fds: [1]posix.pollfd = .{
        .{
            .fd = handle,
            .events = posix.POLL.IN,
            .revents = undefined,
        },
    };
    var message_i: usize = 0;
    var data_i: usize = 0;

    const deadline = timeout.toDeadline(t_io) catch |err| return .{ err, message_i };

    recv: while (true) {
        t.checkCancel() catch |err| return .{ err, message_i };

        if (message_buffer.len - message_i == 0) return .{ null, message_i };
        const message = &message_buffer[message_i];
        const remaining_data_buffer = data_buffer[data_i..];
        var storage: PosixAddress = undefined;
        var iov: posix.iovec = .{ .base = remaining_data_buffer.ptr, .len = remaining_data_buffer.len };
        var msg: posix.msghdr = .{
            .name = &storage.any,
            .namelen = @sizeOf(PosixAddress),
            .iov = (&iov)[0..1],
            .iovlen = 1,
            .control = message.control.ptr,
            .controllen = @intCast(message.control.len),
            .flags = undefined,
        };

        const recv_rc = posix.system.recvmsg(handle, &msg, posix_flags);
        switch (posix.errno(recv_rc)) {
            .SUCCESS => {
                const data = remaining_data_buffer[0..@intCast(recv_rc)];
                data_i += data.len;
                message.* = .{
                    .from = addressFromPosix(&storage),
                    .data = data,
                    .control = if (msg.control) |ptr| @as([*]u8, @ptrCast(ptr))[0..msg.controllen] else message.control,
                    .flags = .{
                        .eor = (msg.flags & posix.MSG.EOR) != 0,
                        .trunc = (msg.flags & posix.MSG.TRUNC) != 0,
                        .ctrunc = (msg.flags & posix.MSG.CTRUNC) != 0,
                        .oob = (msg.flags & posix.MSG.OOB) != 0,
                        .errqueue = if (@hasDecl(posix.MSG, "ERRQUEUE")) (msg.flags & posix.MSG.ERRQUEUE) != 0 else false,
                    },
                };
                message_i += 1;
                continue;
            },
            .AGAIN => while (true) {
                t.checkCancel() catch |err| return .{ err, message_i };
                if (message_i != 0) return .{ null, message_i };

                const max_poll_ms = std.math.maxInt(u31);
                const timeout_ms: u31 = if (deadline) |d| t: {
                    const duration = d.durationFromNow(t_io) catch |err| return .{ err, message_i };
                    if (duration.raw.nanoseconds <= 0) return .{ error.Timeout, message_i };
                    break :t @intCast(@min(max_poll_ms, duration.raw.toMilliseconds()));
                } else max_poll_ms;

                const poll_rc = posix.system.poll(&poll_fds, poll_fds.len, timeout_ms);
                switch (posix.errno(poll_rc)) {
                    .SUCCESS => {
                        if (poll_rc == 0) {
                            // Although spurious timeouts are OK, when no deadline
                            // is passed we must not return `error.Timeout`.
                            if (deadline == null) continue;
                            return .{ error.Timeout, message_i };
                        }
                        continue :recv;
                    },
                    .INTR => continue,
                    .CANCELED => return .{ error.Canceled, message_i },

                    .FAULT => |err| return .{ errnoBug(err), message_i },
                    .INVAL => |err| return .{ errnoBug(err), message_i },
                    .NOMEM => return .{ error.SystemResources, message_i },
                    else => |err| return .{ posix.unexpectedErrno(err), message_i },
                }
            },
            .INTR => continue,
            .CANCELED => return .{ error.Canceled, message_i },

            .BADF => |err| return .{ errnoBug(err), message_i },
            .NFILE => return .{ error.SystemFdQuotaExceeded, message_i },
            .MFILE => return .{ error.ProcessFdQuotaExceeded, message_i },
            .FAULT => |err| return .{ errnoBug(err), message_i },
            .INVAL => |err| return .{ errnoBug(err), message_i },
            .NOBUFS => return .{ error.SystemResources, message_i },
            .NOMEM => return .{ error.SystemResources, message_i },
            .NOTCONN => return .{ error.SocketUnconnected, message_i },
            .NOTSOCK => |err| return .{ errnoBug(err), message_i },
            .MSGSIZE => return .{ error.MessageOversize, message_i },
            .PIPE => return .{ error.SocketUnconnected, message_i },
            .OPNOTSUPP => |err| return .{ errnoBug(err), message_i },
            .CONNRESET => return .{ error.ConnectionResetByPeer, message_i },
            .NETDOWN => return .{ error.NetworkDown, message_i },
            else => |err| return .{ posix.unexpectedErrno(err), message_i },
        }
    }
}

fn netReceiveWindows(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    message_buffer: []net.IncomingMessage,
    data_buffer: []u8,
    flags: net.ReceiveFlags,
    timeout: Io.Timeout,
) struct { ?net.Socket.ReceiveTimeoutError, usize } {
    if (!have_networking) return .{ error.NetworkDown, 0 };
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    _ = handle;
    _ = message_buffer;
    _ = data_buffer;
    _ = flags;
    _ = timeout;
    @panic("TODO implement netReceiveWindows");
}

fn netReceiveUnavailable(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    message_buffer: []net.IncomingMessage,
    data_buffer: []u8,
    flags: net.ReceiveFlags,
    timeout: Io.Timeout,
) struct { ?net.Socket.ReceiveTimeoutError, usize } {
    _ = userdata;
    _ = handle;
    _ = message_buffer;
    _ = data_buffer;
    _ = flags;
    _ = timeout;
    return .{ error.NetworkDown, 0 };
}

fn netWritePosix(
    userdata: ?*anyopaque,
    fd: net.Socket.Handle,
    header: []const u8,
    data: []const []const u8,
    splat: usize,
) net.Stream.Writer.Error!usize {
    if (!have_networking) return error.NetworkDown;
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    var iovecs: [max_iovecs_len]posix.iovec_const = undefined;
    var msg: posix.msghdr_const = .{
        .name = null,
        .namelen = 0,
        .iov = &iovecs,
        .iovlen = 0,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    addBuf(&iovecs, &msg.iovlen, header);
    for (data[0 .. data.len - 1]) |bytes| addBuf(&iovecs, &msg.iovlen, bytes);
    const pattern = data[data.len - 1];
    if (iovecs.len - msg.iovlen != 0) switch (splat) {
        0 => {},
        1 => addBuf(&iovecs, &msg.iovlen, pattern),
        else => switch (pattern.len) {
            0 => {},
            1 => {
                var backup_buffer: [splat_buffer_size]u8 = undefined;
                const splat_buffer = &backup_buffer;
                const memset_len = @min(splat_buffer.len, splat);
                const buf = splat_buffer[0..memset_len];
                @memset(buf, pattern[0]);
                addBuf(&iovecs, &msg.iovlen, buf);
                var remaining_splat = splat - buf.len;
                while (remaining_splat > splat_buffer.len and iovecs.len - msg.iovlen != 0) {
                    assert(buf.len == splat_buffer.len);
                    addBuf(&iovecs, &msg.iovlen, splat_buffer);
                    remaining_splat -= splat_buffer.len;
                }
                addBuf(&iovecs, &msg.iovlen, splat_buffer[0..remaining_splat]);
            },
            else => for (0..@min(splat, iovecs.len - msg.iovlen)) |_| {
                addBuf(&iovecs, &msg.iovlen, pattern);
            },
        },
    };
    const flags = posix.MSG.NOSIGNAL;
    while (true) {
        try t.checkCancel();
        const rc = posix.system.sendmsg(fd, &msg, flags);
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ACCES => |err| return errnoBug(err),
            .AGAIN => |err| return errnoBug(err),
            .ALREADY => return error.FastOpenAlreadyInProgress,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .CONNRESET => return error.ConnectionResetByPeer,
            .DESTADDRREQ => |err| return errnoBug(err), // The socket is not connection-mode, and no peer address is set.
            .FAULT => |err| return errnoBug(err), // An invalid user space address was specified for an argument.
            .INVAL => |err| return errnoBug(err), // Invalid argument passed.
            .ISCONN => |err| return errnoBug(err), // connection-mode socket was connected already but a recipient was specified
            .MSGSIZE => |err| return errnoBug(err),
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTSOCK => |err| return errnoBug(err), // The file descriptor sockfd does not refer to a socket.
            .OPNOTSUPP => |err| return errnoBug(err), // Some bit in the flags argument is inappropriate for the socket type.
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

fn netWriteWindows(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    header: []const u8,
    data: []const []const u8,
    splat: usize,
) net.Stream.Writer.Error!usize {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    comptime assert(native_os == .windows);

    var iovecs: [max_iovecs_len]ws2_32.WSABUF = undefined;
    var len: u32 = 0;
    addWsaBuf(&iovecs, &len, header);
    for (data[0 .. data.len - 1]) |bytes| addWsaBuf(&iovecs, &len, bytes);
    const pattern = data[data.len - 1];
    if (iovecs.len - len != 0) switch (splat) {
        0 => {},
        1 => addWsaBuf(&iovecs, &len, pattern),
        else => switch (pattern.len) {
            0 => {},
            1 => {
                var backup_buffer: [64]u8 = undefined;
                const splat_buffer = &backup_buffer;
                const memset_len = @min(splat_buffer.len, splat);
                const buf = splat_buffer[0..memset_len];
                @memset(buf, pattern[0]);
                addWsaBuf(&iovecs, &len, buf);
                var remaining_splat = splat - buf.len;
                while (remaining_splat > splat_buffer.len and len < iovecs.len) {
                    addWsaBuf(&iovecs, &len, splat_buffer);
                    remaining_splat -= splat_buffer.len;
                }
                addWsaBuf(&iovecs, &len, splat_buffer[0..remaining_splat]);
            },
            else => for (0..@min(splat, iovecs.len - len)) |_| {
                addWsaBuf(&iovecs, &len, pattern);
            },
        },
    };

    while (true) {
        try t.checkCancel();

        var n: u32 = undefined;
        var overlapped: windows.OVERLAPPED = std.mem.zeroes(windows.OVERLAPPED);
        const rc = ws2_32.WSASend(handle, &iovecs, len, &n, 0, &overlapped, null);
        if (rc != ws2_32.SOCKET_ERROR) return n;
        const wsa_error: ws2_32.WinsockError = switch (ws2_32.WSAGetLastError()) {
            .IO_PENDING => e: {
                var result_flags: u32 = undefined;
                const overlapped_rc = ws2_32.WSAGetOverlappedResult(
                    handle,
                    &overlapped,
                    &n,
                    windows.TRUE,
                    &result_flags,
                );
                if (overlapped_rc == windows.FALSE) {
                    break :e ws2_32.WSAGetLastError();
                } else {
                    return n;
                }
            },
            else => |err| err,
        };
        switch (wsa_error) {
            .EINTR => continue,
            .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
            .NOTINITIALISED => {
                try initializeWsa(t);
                continue;
            },

            .ECONNABORTED => return error.ConnectionResetByPeer,
            .ECONNRESET => return error.ConnectionResetByPeer,
            .EINVAL => return error.SocketUnconnected,
            .ENETDOWN => return error.NetworkDown,
            .ENETRESET => return error.ConnectionResetByPeer,
            .ENOBUFS => return error.SystemResources,
            .ENOTCONN => return error.SocketUnconnected,
            .ENOTSOCK => |err| return wsaErrorBug(err),
            .EOPNOTSUPP => |err| return wsaErrorBug(err),
            .ESHUTDOWN => |err| return wsaErrorBug(err),
            else => |err| return windows.unexpectedWSAError(err),
        }
    }
}

fn addWsaBuf(v: []ws2_32.WSABUF, i: *u32, bytes: []const u8) void {
    const cap = std.math.maxInt(u32);
    var remaining = bytes;
    while (remaining.len > cap) {
        if (v.len - i.* == 0) return;
        v[i.*] = .{ .buf = @constCast(remaining.ptr), .len = cap };
        i.* += 1;
        remaining = remaining[cap..];
    } else {
        @branchHint(.likely);
        if (v.len - i.* == 0) return;
        v[i.*] = .{ .buf = @constCast(remaining.ptr), .len = @intCast(remaining.len) };
        i.* += 1;
    }
}

fn netWriteUnavailable(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    header: []const u8,
    data: []const []const u8,
    splat: usize,
) net.Stream.Writer.Error!usize {
    _ = userdata;
    _ = handle;
    _ = header;
    _ = data;
    _ = splat;
    return error.NetworkDown;
}

fn addBuf(v: []posix.iovec_const, i: *@FieldType(posix.msghdr_const, "iovlen"), bytes: []const u8) void {
    // OS checks ptr addr before length so zero length vectors must be omitted.
    if (bytes.len == 0) return;
    if (v.len - i.* == 0) return;
    v[i.*] = .{ .base = bytes.ptr, .len = bytes.len };
    i.* += 1;
}

fn netClose(userdata: ?*anyopaque, handle: net.Socket.Handle) void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    _ = t;
    switch (native_os) {
        .windows => closeSocketWindows(handle),
        else => posix.close(handle),
    }
}

fn netCloseUnavailable(userdata: ?*anyopaque, handle: net.Socket.Handle) void {
    _ = userdata;
    _ = handle;
    unreachable; // How you gonna close something that was impossible to open?
}

fn netInterfaceNameResolve(
    userdata: ?*anyopaque,
    name: *const net.Interface.Name,
) net.Interface.Name.ResolveError!net.Interface {
    if (!have_networking) return error.InterfaceNotFound;
    const t: *Threaded = @ptrCast(@alignCast(userdata));

    if (native_os == .linux) {
        const sock_fd = openSocketPosix(t, posix.AF.UNIX, .{ .mode = .dgram }) catch |err| switch (err) {
            error.ProcessFdQuotaExceeded => return error.SystemResources,
            error.SystemFdQuotaExceeded => return error.SystemResources,
            error.AddressFamilyUnsupported => return error.Unexpected,
            error.ProtocolUnsupportedBySystem => return error.Unexpected,
            error.ProtocolUnsupportedByAddressFamily => return error.Unexpected,
            error.SocketModeUnsupported => return error.Unexpected,
            error.OptionUnsupported => return error.Unexpected,
            else => |e| return e,
        };
        defer posix.close(sock_fd);

        var ifr: posix.ifreq = .{
            .ifrn = .{ .name = @bitCast(name.bytes) },
            .ifru = undefined,
        };

        while (true) {
            try t.checkCancel();
            switch (posix.errno(posix.system.ioctl(sock_fd, posix.SIOCGIFINDEX, @intFromPtr(&ifr)))) {
                .SUCCESS => return .{ .index = @bitCast(ifr.ifru.ivalue) },
                .INTR => continue,
                .CANCELED => return error.Canceled,

                .INVAL => |err| return errnoBug(err), // Bad parameters.
                .NOTTY => |err| return errnoBug(err),
                .NXIO => |err| return errnoBug(err),
                .BADF => |err| return errnoBug(err), // File descriptor used after closed.
                .FAULT => |err| return errnoBug(err), // Bad pointer parameter.
                .IO => |err| return errnoBug(err), // sock_fd is not a file descriptor
                .NODEV => return error.InterfaceNotFound,
                else => |err| return posix.unexpectedErrno(err),
            }
        }
    }

    if (native_os == .windows) {
        try t.checkCancel();
        @panic("TODO implement netInterfaceNameResolve for Windows");
    }

    if (builtin.link_libc) {
        try t.checkCancel();
        const index = std.c.if_nametoindex(&name.bytes);
        if (index == 0) return error.InterfaceNotFound;
        return .{ .index = @bitCast(index) };
    }

    @panic("unimplemented");
}

fn netInterfaceNameResolveUnavailable(
    userdata: ?*anyopaque,
    name: *const net.Interface.Name,
) net.Interface.Name.ResolveError!net.Interface {
    _ = userdata;
    _ = name;
    return error.InterfaceNotFound;
}

fn netInterfaceName(userdata: ?*anyopaque, interface: net.Interface) net.Interface.NameError!net.Interface.Name {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    try t.checkCancel();

    if (native_os == .linux) {
        _ = interface;
        @panic("TODO implement netInterfaceName for linux");
    }

    if (native_os == .windows) {
        @panic("TODO implement netInterfaceName for windows");
    }

    if (builtin.link_libc) {
        @panic("TODO implement netInterfaceName for libc");
    }

    @panic("unimplemented");
}

fn netInterfaceNameUnavailable(userdata: ?*anyopaque, interface: net.Interface) net.Interface.NameError!net.Interface.Name {
    _ = userdata;
    _ = interface;
    return error.Unexpected;
}

fn netLookup(
    userdata: ?*anyopaque,
    host_name: HostName,
    resolved: *Io.Queue(HostName.LookupResult),
    options: HostName.LookupOptions,
) void {
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = io(t);
    resolved.putOneUncancelable(t_io, .{ .end = netLookupFallible(t, host_name, resolved, options) });
}

fn netLookupUnavailable(
    userdata: ?*anyopaque,
    host_name: HostName,
    resolved: *Io.Queue(HostName.LookupResult),
    options: HostName.LookupOptions,
) void {
    _ = host_name;
    _ = options;
    const t: *Threaded = @ptrCast(@alignCast(userdata));
    const t_io = ioBasic(t);
    resolved.putOneUncancelable(t_io, .{ .end = error.NetworkDown });
}

fn netLookupFallible(
    t: *Threaded,
    host_name: HostName,
    resolved: *Io.Queue(HostName.LookupResult),
    options: HostName.LookupOptions,
) !void {
    if (!have_networking) return error.NetworkDown;
    const t_io = io(t);
    const name = host_name.bytes;
    assert(name.len <= HostName.max_len);

    if (is_windows) {
        var name_buffer: [HostName.max_len + 1]u16 = undefined;
        const name_len = std.unicode.wtf8ToWtf16Le(&name_buffer, host_name.bytes) catch
            unreachable; // HostName is prevalidated.
        name_buffer[name_len] = 0;
        const name_w = name_buffer[0..name_len :0];

        var port_buffer: [8]u8 = undefined;
        var port_buffer_wide: [8]u16 = undefined;
        const port = std.fmt.bufPrint(&port_buffer, "{d}", .{options.port}) catch
            unreachable; // `port_buffer` is big enough for decimal u16.
        for (port, port_buffer_wide[0..port.len]) |byte, *wide|
            wide.* = std.mem.nativeToLittle(u16, byte);
        port_buffer_wide[port.len] = 0;
        const port_w = port_buffer_wide[0..port.len :0];

        const hints: ws2_32.ADDRINFOEXW = .{
            .flags = .{ .NUMERICSERV = true },
            .family = if (options.family) |f| switch (f) {
                .ip4 => posix.AF.INET,
                .ip6 => posix.AF.INET6,
            } else posix.AF.UNSPEC,
            .socktype = posix.SOCK.STREAM,
            .protocol = posix.IPPROTO.TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .blob = null,
            .bloblen = 0,
            .provider = null,
            .next = null,
        };
        const cancel_handle: ?*windows.HANDLE = null;
        var res: *ws2_32.ADDRINFOEXW = undefined;
        const timeout: ?*ws2_32.timeval = null;
        while (true) {
            try t.checkCancel(); // TODO make requestCancel call GetAddrInfoExCancel
            // TODO make this append to the queue eagerly rather than blocking until
            // the whole thing finishes
            const rc: ws2_32.WinsockError = @enumFromInt(ws2_32.GetAddrInfoExW(name_w, port_w, .DNS, null, &hints, &res, timeout, null, null, cancel_handle));
            switch (rc) {
                @as(ws2_32.WinsockError, @enumFromInt(0)) => break,
                .EINTR => continue,
                .ECANCELLED, .E_CANCELLED, .OPERATION_ABORTED => return error.Canceled,
                .NOTINITIALISED => {
                    try initializeWsa(t);
                    continue;
                },
                .TRY_AGAIN => return error.NameServerFailure,
                .EINVAL => |err| return wsaErrorBug(err),
                .NO_RECOVERY => return error.NameServerFailure,
                .EAFNOSUPPORT => return error.AddressFamilyUnsupported,
                .NOT_ENOUGH_MEMORY => return error.SystemResources,
                .HOST_NOT_FOUND => return error.UnknownHostName,
                .TYPE_NOT_FOUND => return error.ProtocolUnsupportedByAddressFamily,
                .ESOCKTNOSUPPORT => return error.ProtocolUnsupportedBySystem,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        defer ws2_32.FreeAddrInfoExW(res);

        var it: ?*ws2_32.ADDRINFOEXW = res;
        var canon_name: ?[*:0]const u16 = null;
        while (it) |info| : (it = info.next) {
            const addr = info.addr orelse continue;
            const storage: WsaAddress = .{ .any = addr.* };
            try resolved.putOne(t_io, .{ .address = addressFromWsa(&storage) });

            if (info.canonname) |n| {
                if (canon_name == null) {
                    canon_name = n;
                }
            }
        }
        if (canon_name) |n| {
            const len = std.unicode.wtf16LeToWtf8(options.canonical_name_buffer, std.mem.sliceTo(n, 0));
            try resolved.putOne(t_io, .{ .canonical_name = .{
                .bytes = options.canonical_name_buffer[0..len],
            } });
        }
        return;
    }

    // On Linux, glibc provides getaddrinfo_a which is capable of supporting our semantics.
    // However, musl's POSIX-compliant getaddrinfo is not, so we bypass it.

    if (builtin.target.isGnuLibC()) {
        // TODO use getaddrinfo_a / gai_cancel
    }

    if (native_os == .linux) {
        if (options.family != .ip4) {
            if (IpAddress.parseIp6(name, options.port)) |addr| {
                try resolved.putAll(t_io, &.{
                    .{ .address = addr },
                    .{ .canonical_name = copyCanon(options.canonical_name_buffer, name) },
                });
                return;
            } else |_| {}
        }

        if (options.family != .ip6) {
            if (IpAddress.parseIp4(name, options.port)) |addr| {
                try resolved.putAll(t_io, &.{
                    .{ .address = addr },
                    .{ .canonical_name = copyCanon(options.canonical_name_buffer, name) },
                });
                return;
            } else |_| {}
        }

        lookupHosts(t, host_name, resolved, options) catch |err| switch (err) {
            error.UnknownHostName => {},
            else => |e| return e,
        };

        // RFC 6761 Section 6.3.3
        // Name resolution APIs and libraries SHOULD recognize
        // localhost names as special and SHOULD always return the IP
        // loopback address for address queries and negative responses
        // for all other query types.

        // Check for equal to "localhost(.)" or ends in ".localhost(.)"
        const localhost = if (name[name.len - 1] == '.') "localhost." else "localhost";
        if (std.mem.endsWith(u8, name, localhost) and
            (name.len == localhost.len or name[name.len - localhost.len] == '.'))
        {
            var results_buffer: [3]HostName.LookupResult = undefined;
            var results_index: usize = 0;
            if (options.family != .ip4) {
                results_buffer[results_index] = .{ .address = .{ .ip6 = .loopback(options.port) } };
                results_index += 1;
            }
            if (options.family != .ip6) {
                results_buffer[results_index] = .{ .address = .{ .ip4 = .loopback(options.port) } };
                results_index += 1;
            }
            const canon_name = "localhost";
            const canon_name_dest = options.canonical_name_buffer[0..canon_name.len];
            canon_name_dest.* = canon_name.*;
            results_buffer[results_index] = .{ .canonical_name = .{ .bytes = canon_name_dest } };
            results_index += 1;
            try resolved.putAll(t_io, results_buffer[0..results_index]);
            return;
        }

        return lookupDnsSearch(t, host_name, resolved, options);
    }

    if (native_os == .openbsd) {
        // TODO use getaddrinfo_async / asr_abort
    }

    if (native_os == .freebsd) {
        // TODO use dnsres_getaddrinfo
    }

    if (native_os.isDarwin()) {
        // TODO use CFHostStartInfoResolution / CFHostCancelInfoResolution
    }

    if (builtin.link_libc) {
        // This operating system lacks a way to resolve asynchronously. We are
        // stuck with getaddrinfo.
        var name_buffer: [HostName.max_len + 1]u8 = undefined;
        @memcpy(name_buffer[0..host_name.bytes.len], host_name.bytes);
        name_buffer[host_name.bytes.len] = 0;
        const name_c = name_buffer[0..host_name.bytes.len :0];

        var port_buffer: [8]u8 = undefined;
        const port_c = std.fmt.bufPrintZ(&port_buffer, "{d}", .{options.port}) catch unreachable;

        const hints: posix.addrinfo = .{
            .flags = .{ .NUMERICSERV = true },
            .family = posix.AF.UNSPEC,
            .socktype = posix.SOCK.STREAM,
            .protocol = posix.IPPROTO.TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .next = null,
        };
        var res: ?*posix.addrinfo = null;
        while (true) {
            try t.checkCancel();
            switch (posix.system.getaddrinfo(name_c.ptr, port_c.ptr, &hints, &res)) {
                @as(posix.system.EAI, @enumFromInt(0)) => break,
                .ADDRFAMILY => return error.AddressFamilyUnsupported,
                .AGAIN => return error.NameServerFailure,
                .FAIL => return error.NameServerFailure,
                .FAMILY => return error.AddressFamilyUnsupported,
                .MEMORY => return error.SystemResources,
                .NODATA => return error.UnknownHostName,
                .NONAME => return error.UnknownHostName,
                .SYSTEM => switch (posix.errno(-1)) {
                    .INTR => continue,
                    .CANCELED => return error.Canceled,
                    else => |e| return posix.unexpectedErrno(e),
                },
                else => return error.Unexpected,
            }
        }
        defer if (res) |some| posix.system.freeaddrinfo(some);

        var it = res;
        var canon_name: ?[*:0]const u8 = null;
        while (it) |info| : (it = info.next) {
            const addr = info.addr orelse continue;
            const storage: PosixAddress = .{ .any = addr.* };
            try resolved.putOne(t_io, .{ .address = addressFromPosix(&storage) });

            if (info.canonname) |n| {
                if (canon_name == null) {
                    canon_name = n;
                }
            }
        }
        if (canon_name) |n| {
            try resolved.putOne(t_io, .{
                .canonical_name = copyCanon(options.canonical_name_buffer, std.mem.sliceTo(n, 0)),
            });
        }
        return;
    }

    return error.OptionUnsupported;
}

pub const PosixAddress = extern union {
    any: posix.sockaddr,
    in: posix.sockaddr.in,
    in6: posix.sockaddr.in6,
};

const UnixAddress = extern union {
    any: posix.sockaddr,
    un: posix.sockaddr.un,
};

const WsaAddress = extern union {
    any: ws2_32.sockaddr,
    in: ws2_32.sockaddr.in,
    in6: ws2_32.sockaddr.in6,
    un: ws2_32.sockaddr.un,
};

pub fn posixAddressFamily(a: *const IpAddress) posix.sa_family_t {
    return switch (a.*) {
        .ip4 => posix.AF.INET,
        .ip6 => posix.AF.INET6,
    };
}

pub fn addressFromPosix(posix_address: *const PosixAddress) IpAddress {
    return switch (posix_address.any.family) {
        posix.AF.INET => .{ .ip4 = address4FromPosix(&posix_address.in) },
        posix.AF.INET6 => .{ .ip6 = address6FromPosix(&posix_address.in6) },
        else => .{ .ip4 = .loopback(0) },
    };
}

fn addressFromWsa(wsa_address: *const WsaAddress) IpAddress {
    return switch (wsa_address.any.family) {
        posix.AF.INET => .{ .ip4 = address4FromWsa(&wsa_address.in) },
        posix.AF.INET6 => .{ .ip6 = address6FromWsa(&wsa_address.in6) },
        else => .{ .ip4 = .loopback(0) },
    };
}

pub fn addressToPosix(a: *const IpAddress, storage: *PosixAddress) posix.socklen_t {
    return switch (a.*) {
        .ip4 => |ip4| {
            storage.in = address4ToPosix(ip4);
            return @sizeOf(posix.sockaddr.in);
        },
        .ip6 => |*ip6| {
            storage.in6 = address6ToPosix(ip6);
            return @sizeOf(posix.sockaddr.in6);
        },
    };
}

fn addressToWsa(a: *const IpAddress, storage: *WsaAddress) i32 {
    return switch (a.*) {
        .ip4 => |ip4| {
            storage.in = address4ToPosix(ip4);
            return @sizeOf(posix.sockaddr.in);
        },
        .ip6 => |*ip6| {
            storage.in6 = address6ToPosix(ip6);
            return @sizeOf(posix.sockaddr.in6);
        },
    };
}

fn addressUnixToPosix(a: *const net.UnixAddress, storage: *UnixAddress) posix.socklen_t {
    @memcpy(storage.un.path[0..a.path.len], a.path);
    storage.un.family = posix.AF.UNIX;
    storage.un.path[a.path.len] = 0;
    return @sizeOf(posix.sockaddr.un);
}

fn addressUnixToWsa(a: *const net.UnixAddress, storage: *WsaAddress) i32 {
    @memcpy(storage.un.path[0..a.path.len], a.path);
    storage.un.family = posix.AF.UNIX;
    storage.un.path[a.path.len] = 0;
    return @sizeOf(posix.sockaddr.un);
}

fn address4FromPosix(in: *const posix.sockaddr.in) net.Ip4Address {
    return .{
        .port = std.mem.bigToNative(u16, in.port),
        .bytes = @bitCast(in.addr),
    };
}

fn address6FromPosix(in6: *const posix.sockaddr.in6) net.Ip6Address {
    return .{
        .port = std.mem.bigToNative(u16, in6.port),
        .bytes = in6.addr,
        .flow = in6.flowinfo,
        .interface = .{ .index = in6.scope_id },
    };
}

fn address4FromWsa(in: *const ws2_32.sockaddr.in) net.Ip4Address {
    return .{
        .port = std.mem.bigToNative(u16, in.port),
        .bytes = @bitCast(in.addr),
    };
}

fn address6FromWsa(in6: *const ws2_32.sockaddr.in6) net.Ip6Address {
    return .{
        .port = std.mem.bigToNative(u16, in6.port),
        .bytes = in6.addr,
        .flow = in6.flowinfo,
        .interface = .{ .index = in6.scope_id },
    };
}

fn address4ToPosix(a: net.Ip4Address) posix.sockaddr.in {
    return .{
        .port = std.mem.nativeToBig(u16, a.port),
        .addr = @bitCast(a.bytes),
    };
}

fn address6ToPosix(a: *const net.Ip6Address) posix.sockaddr.in6 {
    return .{
        .port = std.mem.nativeToBig(u16, a.port),
        .flowinfo = a.flow,
        .addr = a.bytes,
        .scope_id = a.interface.index,
    };
}

pub fn errnoBug(err: posix.E) Io.UnexpectedError {
    if (is_debug) std.debug.panic("programmer bug caused syscall error: {t}", .{err});
    return error.Unexpected;
}

fn wsaErrorBug(err: ws2_32.WinsockError) Io.UnexpectedError {
    if (is_debug) std.debug.panic("programmer bug caused syscall error: {t}", .{err});
    return error.Unexpected;
}

pub fn posixSocketMode(mode: net.Socket.Mode) u32 {
    return switch (mode) {
        .stream => posix.SOCK.STREAM,
        .dgram => posix.SOCK.DGRAM,
        .seqpacket => posix.SOCK.SEQPACKET,
        .raw => posix.SOCK.RAW,
        .rdm => posix.SOCK.RDM,
    };
}

pub fn posixProtocol(protocol: ?net.Protocol) u32 {
    return @intFromEnum(protocol orelse return 0);
}

fn recoverableOsBugDetected() void {
    if (is_debug) unreachable;
}

fn clockToPosix(clock: Io.Clock) posix.clockid_t {
    return switch (clock) {
        .real => posix.CLOCK.REALTIME,
        .awake => switch (native_os) {
            .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => posix.CLOCK.UPTIME_RAW,
            else => posix.CLOCK.MONOTONIC,
        },
        .boot => switch (native_os) {
            .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => posix.CLOCK.MONOTONIC_RAW,
            // On freebsd derivatives, use MONOTONIC_FAST as currently there's
            // no precision tradeoff.
            .freebsd, .dragonfly => posix.CLOCK.MONOTONIC_FAST,
            // On linux, use BOOTTIME instead of MONOTONIC as it ticks while
            // suspended.
            .linux => posix.CLOCK.BOOTTIME,
            // On other posix systems, MONOTONIC is generally the fastest and
            // ticks while suspended.
            else => posix.CLOCK.MONOTONIC,
        },
        .cpu_process => posix.CLOCK.PROCESS_CPUTIME_ID,
        .cpu_thread => posix.CLOCK.THREAD_CPUTIME_ID,
    };
}

fn clockToWasi(clock: Io.Clock) std.os.wasi.clockid_t {
    return switch (clock) {
        .real => .REALTIME,
        .awake => .MONOTONIC,
        .boot => .MONOTONIC,
        .cpu_process => .PROCESS_CPUTIME_ID,
        .cpu_thread => .THREAD_CPUTIME_ID,
    };
}

fn statFromLinux(stx: *const std.os.linux.Statx) Io.File.Stat {
    const atime = stx.atime;
    const mtime = stx.mtime;
    const ctime = stx.ctime;
    return .{
        .inode = stx.ino,
        .size = stx.size,
        .mode = stx.mode,
        .kind = switch (stx.mode & std.os.linux.S.IFMT) {
            std.os.linux.S.IFDIR => .directory,
            std.os.linux.S.IFCHR => .character_device,
            std.os.linux.S.IFBLK => .block_device,
            std.os.linux.S.IFREG => .file,
            std.os.linux.S.IFIFO => .named_pipe,
            std.os.linux.S.IFLNK => .sym_link,
            std.os.linux.S.IFSOCK => .unix_domain_socket,
            else => .unknown,
        },
        .atime = .{ .nanoseconds = @intCast(@as(i128, atime.sec) * std.time.ns_per_s + atime.nsec) },
        .mtime = .{ .nanoseconds = @intCast(@as(i128, mtime.sec) * std.time.ns_per_s + mtime.nsec) },
        .ctime = .{ .nanoseconds = @intCast(@as(i128, ctime.sec) * std.time.ns_per_s + ctime.nsec) },
    };
}

fn statFromPosix(st: *const posix.Stat) Io.File.Stat {
    const atime = st.atime();
    const mtime = st.mtime();
    const ctime = st.ctime();
    return .{
        .inode = st.ino,
        .size = @bitCast(st.size),
        .mode = st.mode,
        .kind = k: {
            const m = st.mode & posix.S.IFMT;
            switch (m) {
                posix.S.IFBLK => break :k .block_device,
                posix.S.IFCHR => break :k .character_device,
                posix.S.IFDIR => break :k .directory,
                posix.S.IFIFO => break :k .named_pipe,
                posix.S.IFLNK => break :k .sym_link,
                posix.S.IFREG => break :k .file,
                posix.S.IFSOCK => break :k .unix_domain_socket,
                else => {},
            }
            if (native_os == .illumos) switch (m) {
                posix.S.IFDOOR => break :k .door,
                posix.S.IFPORT => break :k .event_port,
                else => {},
            };

            break :k .unknown;
        },
        .atime = timestampFromPosix(&atime),
        .mtime = timestampFromPosix(&mtime),
        .ctime = timestampFromPosix(&ctime),
    };
}

fn statFromWasi(st: *const std.os.wasi.filestat_t) Io.File.Stat {
    return .{
        .inode = st.ino,
        .size = @bitCast(st.size),
        .mode = 0,
        .kind = switch (st.filetype) {
            .BLOCK_DEVICE => .block_device,
            .CHARACTER_DEVICE => .character_device,
            .DIRECTORY => .directory,
            .SYMBOLIC_LINK => .sym_link,
            .REGULAR_FILE => .file,
            .SOCKET_STREAM, .SOCKET_DGRAM => .unix_domain_socket,
            else => .unknown,
        },
        .atime = .fromNanoseconds(st.atim),
        .mtime = .fromNanoseconds(st.mtim),
        .ctime = .fromNanoseconds(st.ctim),
    };
}

fn timestampFromPosix(timespec: *const posix.timespec) Io.Timestamp {
    return .{ .nanoseconds = @intCast(@as(i128, timespec.sec) * std.time.ns_per_s + timespec.nsec) };
}

fn timestampToPosix(nanoseconds: i96) posix.timespec {
    return .{
        .sec = @intCast(@divFloor(nanoseconds, std.time.ns_per_s)),
        .nsec = @intCast(@mod(nanoseconds, std.time.ns_per_s)),
    };
}

fn pathToPosix(file_path: []const u8, buffer: *[posix.PATH_MAX]u8) Io.Dir.PathNameError![:0]u8 {
    if (std.mem.containsAtLeastScalar2(u8, file_path, 0, 1)) return error.BadPathName;
    // >= rather than > to make room for the null byte
    if (file_path.len >= buffer.len) return error.NameTooLong;
    @memcpy(buffer[0..file_path.len], file_path);
    buffer[file_path.len] = 0;
    return buffer[0..file_path.len :0];
}

fn lookupDnsSearch(
    t: *Threaded,
    host_name: HostName,
    resolved: *Io.Queue(HostName.LookupResult),
    options: HostName.LookupOptions,
) HostName.LookupError!void {
    const t_io = io(t);
    const rc = HostName.ResolvConf.init(t_io) catch return error.ResolvConfParseFailed;

    // Count dots, suppress search when >=ndots or name ends in
    // a dot, which is an explicit request for global scope.
    const dots = std.mem.countScalar(u8, host_name.bytes, '.');
    const search_len = if (dots >= rc.ndots or std.mem.endsWith(u8, host_name.bytes, ".")) 0 else rc.search_len;
    const search = rc.search_buffer[0..search_len];

    var canon_name = host_name.bytes;

    // Strip final dot for canon, fail if multiple trailing dots.
    if (std.mem.endsWith(u8, canon_name, ".")) canon_name.len -= 1;
    if (std.mem.endsWith(u8, canon_name, ".")) return error.UnknownHostName;

    // Name with search domain appended is set up in `canon_name`. This
    // both provides the desired default canonical name (if the requested
    // name is not a CNAME record) and serves as a buffer for passing the
    // full requested name to `lookupDns`.
    @memcpy(options.canonical_name_buffer[0..canon_name.len], canon_name);
    options.canonical_name_buffer[canon_name.len] = '.';
    var it = std.mem.tokenizeAny(u8, search, " \t");
    while (it.next()) |token| {
        @memcpy(options.canonical_name_buffer[canon_name.len + 1 ..][0..token.len], token);
        const lookup_canon_name = options.canonical_name_buffer[0 .. canon_name.len + 1 + token.len];
        if (lookupDns(t, lookup_canon_name, &rc, resolved, options)) |result| {
            return result;
        } else |err| switch (err) {
            error.UnknownHostName => continue,
            else => |e| return e,
        }
    }

    const lookup_canon_name = options.canonical_name_buffer[0..canon_name.len];
    return lookupDns(t, lookup_canon_name, &rc, resolved, options);
}

fn lookupDns(
    t: *Threaded,
    lookup_canon_name: []const u8,
    rc: *const HostName.ResolvConf,
    resolved: *Io.Queue(HostName.LookupResult),
    options: HostName.LookupOptions,
) HostName.LookupError!void {
    const t_io = io(t);
    const family_records: [2]struct { af: IpAddress.Family, rr: HostName.DnsRecord } = .{
        .{ .af = .ip6, .rr = .A },
        .{ .af = .ip4, .rr = .AAAA },
    };
    var query_buffers: [2][280]u8 = undefined;
    var answer_buffer: [2 * 512]u8 = undefined;
    var queries_buffer: [2][]const u8 = undefined;
    var answers_buffer: [2][]const u8 = undefined;
    var nq: usize = 0;
    var answer_buffer_i: usize = 0;

    for (family_records) |fr| {
        if (options.family != fr.af) {
            const entropy = std.crypto.random.array(u8, 2);
            const len = writeResolutionQuery(&query_buffers[nq], 0, lookup_canon_name, 1, fr.rr, entropy);
            queries_buffer[nq] = query_buffers[nq][0..len];
            nq += 1;
        }
    }

    var ip4_mapped_buffer: [HostName.ResolvConf.max_nameservers]IpAddress = undefined;
    const ip4_mapped = ip4_mapped_buffer[0..rc.nameservers_len];
    var any_ip6 = false;
    for (rc.nameservers(), ip4_mapped) |*ns, *m| {
        m.* = .{ .ip6 = .fromAny(ns.*) };
        any_ip6 = any_ip6 or ns.* == .ip6;
    }
    var socket = s: {
        if (any_ip6) ip6: {
            const ip6_addr: IpAddress = .{ .ip6 = .unspecified(0) };
            const socket = ip6_addr.bind(t_io, .{ .ip6_only = true, .mode = .dgram }) catch |err| switch (err) {
                error.AddressFamilyUnsupported => break :ip6,
                else => |e| return e,
            };
            break :s socket;
        }
        any_ip6 = false;
        const ip4_addr: IpAddress = .{ .ip4 = .unspecified(0) };
        const socket = try ip4_addr.bind(t_io, .{ .mode = .dgram });
        break :s socket;
    };
    defer socket.close(t_io);

    const mapped_nameservers = if (any_ip6) ip4_mapped else rc.nameservers();
    const queries = queries_buffer[0..nq];
    const answers = answers_buffer[0..queries.len];
    var answers_remaining = answers.len;
    for (answers) |*answer| answer.len = 0;

    // boot clock is chosen because time the computer is suspended should count
    // against time spent waiting for external messages to arrive.
    const clock: Io.Clock = .boot;
    var now_ts = try clock.now(t_io);
    const final_ts = now_ts.addDuration(.fromSeconds(rc.timeout_seconds));
    const attempt_duration: Io.Duration = .{
        .nanoseconds = (std.time.ns_per_s / rc.attempts) * @as(i96, rc.timeout_seconds),
    };

    send: while (now_ts.nanoseconds < final_ts.nanoseconds) : (now_ts = try clock.now(t_io)) {
        const max_messages = queries_buffer.len * HostName.ResolvConf.max_nameservers;
        {
            var message_buffer: [max_messages]Io.net.OutgoingMessage = undefined;
            var message_i: usize = 0;
            for (queries, answers) |query, *answer| {
                if (answer.len != 0) continue;
                for (mapped_nameservers) |*ns| {
                    message_buffer[message_i] = .{
                        .address = ns,
                        .data_ptr = query.ptr,
                        .data_len = query.len,
                    };
                    message_i += 1;
                }
            }
            _ = netSendPosix(t, socket.handle, message_buffer[0..message_i], .{});
        }

        const timeout: Io.Timeout = .{ .deadline = .{
            .raw = now_ts.addDuration(attempt_duration),
            .clock = clock,
        } };

        while (true) {
            var message_buffer: [max_messages]Io.net.IncomingMessage = @splat(.init);
            const buf = answer_buffer[answer_buffer_i..];
            const recv_err, const recv_n = socket.receiveManyTimeout(t_io, &message_buffer, buf, .{}, timeout);
            for (message_buffer[0..recv_n]) |*received_message| {
                const reply = received_message.data;
                // Ignore non-identifiable packets.
                if (reply.len < 4) continue;

                // Ignore replies from addresses we didn't send to.
                const ns = for (mapped_nameservers) |*ns| {
                    if (received_message.from.eql(ns)) break ns;
                } else {
                    continue;
                };

                // Find which query this answer goes with, if any.
                const query, const answer = for (queries, answers) |query, *answer| {
                    if (reply[0] == query[0] and reply[1] == query[1]) break .{ query, answer };
                } else {
                    continue;
                };
                if (answer.len != 0) continue;

                // Only accept positive or negative responses; retry immediately on
                // server failure, and ignore all other codes such as refusal.
                switch (reply[3] & 15) {
                    0, 3 => {
                        answer.* = reply;
                        answer_buffer_i += reply.len;
                        answers_remaining -= 1;
                        if (answer_buffer.len - answer_buffer_i == 0) break :send;
                        if (answers_remaining == 0) break :send;
                    },
                    2 => {
                        var retry_message: Io.net.OutgoingMessage = .{
                            .address = ns,
                            .data_ptr = query.ptr,
                            .data_len = query.len,
                        };
                        _ = netSendPosix(t, socket.handle, (&retry_message)[0..1], .{});
                        continue;
                    },
                    else => continue,
                }
            }
            if (recv_err) |err| switch (err) {
                error.Canceled => return error.Canceled,
                error.Timeout => continue :send,
                else => continue,
            };
        }
    } else {
        return error.NameServerFailure;
    }

    var addresses_len: usize = 0;
    var canonical_name: ?HostName = null;

    for (answers) |answer| {
        var it = HostName.DnsResponse.init(answer) catch {
            // Here we could potentially add diagnostics to the results queue.
            continue;
        };
        while (it.next() catch {
            // Here we could potentially add diagnostics to the results queue.
            continue;
        }) |record| switch (record.rr) {
            .A => {
                const data = record.packet[record.data_off..][0..record.data_len];
                if (data.len != 4) return error.InvalidDnsARecord;
                try resolved.putOne(t_io, .{ .address = .{ .ip4 = .{
                    .bytes = data[0..4].*,
                    .port = options.port,
                } } });
                addresses_len += 1;
            },
            .AAAA => {
                const data = record.packet[record.data_off..][0..record.data_len];
                if (data.len != 16) return error.InvalidDnsAAAARecord;
                try resolved.putOne(t_io, .{ .address = .{ .ip6 = .{
                    .bytes = data[0..16].*,
                    .port = options.port,
                } } });
                addresses_len += 1;
            },
            .CNAME => {
                _, canonical_name = HostName.expand(record.packet, record.data_off, options.canonical_name_buffer) catch
                    return error.InvalidDnsCnameRecord;
            },
            _ => continue,
        };
    }

    try resolved.putOne(t_io, .{ .canonical_name = canonical_name orelse .{ .bytes = lookup_canon_name } });
    if (addresses_len == 0) return error.NameServerFailure;
}

fn lookupHosts(
    t: *Threaded,
    host_name: HostName,
    resolved: *Io.Queue(HostName.LookupResult),
    options: HostName.LookupOptions,
) !void {
    const t_io = io(t);
    const file = Io.File.openAbsolute(t_io, "/etc/hosts", .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return error.UnknownHostName,

        error.Canceled => |e| return e,

        else => {
            // Here we could add more detailed diagnostics to the results queue.
            return error.DetectingNetworkConfigurationFailed;
        },
    };
    defer file.close(t_io);

    var line_buf: [512]u8 = undefined;
    var file_reader = file.reader(t_io, &line_buf);
    return lookupHostsReader(t, host_name, resolved, options, &file_reader.interface) catch |err| switch (err) {
        error.ReadFailed => switch (file_reader.err.?) {
            error.Canceled => |e| return e,
            else => {
                // Here we could add more detailed diagnostics to the results queue.
                return error.DetectingNetworkConfigurationFailed;
            },
        },
        error.Canceled => |e| return e,
        error.UnknownHostName => |e| return e,
    };
}

fn lookupHostsReader(
    t: *Threaded,
    host_name: HostName,
    resolved: *Io.Queue(HostName.LookupResult),
    options: HostName.LookupOptions,
    reader: *Io.Reader,
) error{ ReadFailed, Canceled, UnknownHostName }!void {
    const t_io = io(t);
    var addresses_len: usize = 0;
    var canonical_name: ?HostName = null;
    while (true) {
        const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.StreamTooLong => {
                // Skip lines that are too long.
                _ = reader.discardDelimiterInclusive('\n') catch |e| switch (e) {
                    error.EndOfStream => break,
                    error.ReadFailed => return error.ReadFailed,
                };
                continue;
            },
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => break,
        };
        reader.toss(1);
        var split_it = std.mem.splitScalar(u8, line, '#');
        const no_comment_line = split_it.first();

        var line_it = std.mem.tokenizeAny(u8, no_comment_line, " \t");
        const ip_text = line_it.next() orelse continue;
        var first_name_text: ?[]const u8 = null;
        while (line_it.next()) |name_text| {
            if (std.mem.eql(u8, name_text, host_name.bytes)) {
                if (first_name_text == null) first_name_text = name_text;
                break;
            }
        } else continue;

        if (canonical_name == null) {
            if (HostName.init(first_name_text.?)) |name_text| {
                if (name_text.bytes.len <= options.canonical_name_buffer.len) {
                    const canonical_name_dest = options.canonical_name_buffer[0..name_text.bytes.len];
                    @memcpy(canonical_name_dest, name_text.bytes);
                    canonical_name = .{ .bytes = canonical_name_dest };
                }
            } else |_| {}
        }

        if (options.family != .ip6) {
            if (IpAddress.parseIp4(ip_text, options.port)) |addr| {
                try resolved.putOne(t_io, .{ .address = addr });
                addresses_len += 1;
            } else |_| {}
        }
        if (options.family != .ip4) {
            if (IpAddress.parseIp6(ip_text, options.port)) |addr| {
                try resolved.putOne(t_io, .{ .address = addr });
                addresses_len += 1;
            } else |_| {}
        }
    }

    if (canonical_name) |canon_name| try resolved.putOne(t_io, .{ .canonical_name = canon_name });
    if (addresses_len == 0) return error.UnknownHostName;
}

/// Writes DNS resolution query packet data to `w`; at most 280 bytes.
fn writeResolutionQuery(q: *[280]u8, op: u4, dname: []const u8, class: u8, ty: HostName.DnsRecord, entropy: [2]u8) usize {
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    var name = dname;
    if (std.mem.endsWith(u8, name, ".")) name.len -= 1;
    assert(name.len <= 253);
    const n = 17 + name.len + @intFromBool(name.len != 0);

    // Construct query template - ID will be filled later
    q[0..2].* = entropy;
    @memset(q[2..n], 0);
    q[2] = @as(u8, op) * 8 + 1;
    q[5] = 1;
    @memcpy(q[13..][0..name.len], name);
    var i: usize = 13;
    var j: usize = undefined;
    while (q[i] != 0) : (i = j + 1) {
        j = i;
        while (q[j] != 0 and q[j] != '.') : (j += 1) {}
        // TODO determine the circumstances for this and whether or
        // not this should be an error.
        if (j - i - 1 > 62) unreachable;
        q[i - 1] = @intCast(j - i);
    }
    q[i + 1] = @intFromEnum(ty);
    q[i + 3] = class;
    return n;
}

fn copyCanon(canonical_name_buffer: *[HostName.max_len]u8, name: []const u8) HostName {
    const dest = canonical_name_buffer[0..name.len];
    @memcpy(dest, name);
    return .{ .bytes = dest };
}

/// Darwin XNU 7195.50.7.100.1 introduced __ulock_wait2 and migrated code paths (notably pthread_cond_t) towards it:
/// https://github.com/apple/darwin-xnu/commit/d4061fb0260b3ed486147341b72468f836ed6c8f#diff-08f993cc40af475663274687b7c326cc6c3031e0db3ac8de7b24624610616be6
///
/// This XNU version appears to correspond to 11.0.1:
/// https://kernelshaman.blogspot.com/2021/01/building-xnu-for-macos-big-sur-1101.html
///
/// ulock_wait() uses 32-bit micro-second timeouts where 0 = INFINITE or no-timeout
/// ulock_wait2() uses 64-bit nano-second timeouts (with the same convention)
const darwin_supports_ulock_wait2 = builtin.os.version_range.semver.min.major >= 11;

fn futexWait(t: *Threaded, ptr: *const std.atomic.Value(u32), expect: u32) Io.Cancelable!void {
    @branchHint(.cold);

    if (builtin.cpu.arch.isWasm()) {
        comptime assert(builtin.cpu.has(.wasm, .atomics));
        try t.checkCancel();
        const timeout: i64 = -1;
        const signed_expect: i32 = @bitCast(expect);
        const result = asm volatile (
            \\local.get %[ptr]
            \\local.get %[expected]
            \\local.get %[timeout]
            \\memory.atomic.wait32 0
            \\local.set %[ret]
            : [ret] "=r" (-> u32),
            : [ptr] "r" (&ptr.raw),
              [expected] "r" (signed_expect),
              [timeout] "r" (timeout),
        );
        switch (result) {
            0 => {}, // ok
            1 => {}, // expected != loaded
            2 => assert(!is_debug), // timeout
            else => assert(!is_debug),
        }
    } else switch (native_os) {
        .linux => {
            const linux = std.os.linux;
            try t.checkCancel();
            const rc = linux.futex_4arg(ptr, .{ .cmd = .WAIT, .private = true }, expect, null);
            if (is_debug) switch (linux.errno(rc)) {
                .SUCCESS => {}, // notified by `wake()`
                .INTR => {}, // gives caller a chance to check cancellation
                .AGAIN => {}, // ptr.* != expect
                .INVAL => {}, // possibly timeout overflow
                .TIMEDOUT => unreachable,
                .FAULT => unreachable, // ptr was invalid
                else => unreachable,
            };
        },
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => {
            const c = std.c;
            const flags: c.UL = .{
                .op = .COMPARE_AND_WAIT,
                .NO_ERRNO = true,
            };
            try t.checkCancel();
            const status = if (darwin_supports_ulock_wait2)
                c.__ulock_wait2(flags, ptr, expect, 0, 0)
            else
                c.__ulock_wait(flags, ptr, expect, 0);

            if (status >= 0) return;

            if (is_debug) switch (@as(c.E, @enumFromInt(-status))) {
                .INTR => {}, // spurious wake
                // Address of the futex was paged out. This is unlikely, but possible in theory, and
                // pthread/libdispatch on darwin bother to handle it. In this case we'll return
                // without waiting, but the caller should retry anyway.
                .FAULT => {},
                .TIMEDOUT => unreachable,
                else => unreachable,
            };
        },
        .windows => {
            try t.checkCancel();
            switch (windows.ntdll.RtlWaitOnAddress(ptr, &expect, @sizeOf(@TypeOf(expect)), null)) {
                .SUCCESS => {},
                .CANCELLED => return error.Canceled,
                else => recoverableOsBugDetected(),
            }
        },
        .freebsd => {
            const flags = @intFromEnum(std.c.UMTX_OP.WAIT_UINT_PRIVATE);
            try t.checkCancel();
            const rc = std.c._umtx_op(@intFromPtr(&ptr.raw), flags, @as(c_ulong, expect), 0, 0);
            if (is_debug) switch (posix.errno(rc)) {
                .SUCCESS => {},
                .FAULT => unreachable, // one of the args points to invalid memory
                .INVAL => unreachable, // arguments should be correct
                .TIMEDOUT => unreachable, // no timeout provided
                .INTR => {}, // spurious wake
                else => unreachable,
            };
        },
        else => @compileError("unimplemented: futexWait"),
    }
}

pub fn futexWaitUncancelable(ptr: *const std.atomic.Value(u32), expect: u32) void {
    @branchHint(.cold);

    if (builtin.cpu.arch.isWasm()) {
        comptime assert(builtin.cpu.has(.wasm, .atomics));
        const timeout: i64 = -1;
        const signed_expect: i32 = @bitCast(expect);
        const result = asm volatile (
            \\local.get %[ptr]
            \\local.get %[expected]
            \\local.get %[timeout]
            \\memory.atomic.wait32 0
            \\local.set %[ret]
            : [ret] "=r" (-> u32),
            : [ptr] "r" (&ptr.raw),
              [expected] "r" (signed_expect),
              [timeout] "r" (timeout),
        );
        switch (result) {
            0 => {}, // ok
            1 => {}, // expected != loaded
            2 => recoverableOsBugDetected(), // timeout
            else => recoverableOsBugDetected(),
        }
    } else switch (native_os) {
        .linux => {
            const linux = std.os.linux;
            const rc = linux.futex_4arg(ptr, .{ .cmd = .WAIT, .private = true }, expect, null);
            switch (linux.errno(rc)) {
                .SUCCESS => {}, // notified by `wake()`
                .INTR => {}, // gives caller a chance to check cancellation
                .AGAIN => {}, // ptr.* != expect
                .INVAL => {}, // possibly timeout overflow
                .TIMEDOUT => recoverableOsBugDetected(),
                .FAULT => recoverableOsBugDetected(), // ptr was invalid
                else => recoverableOsBugDetected(),
            }
        },
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => {
            const c = std.c;
            const flags: c.UL = .{
                .op = .COMPARE_AND_WAIT,
                .NO_ERRNO = true,
            };
            const status = if (darwin_supports_ulock_wait2)
                c.__ulock_wait2(flags, ptr, expect, 0, 0)
            else
                c.__ulock_wait(flags, ptr, expect, 0);

            if (status >= 0) return;

            switch (@as(c.E, @enumFromInt(-status))) {
                // Wait was interrupted by the OS or other spurious signalling.
                .INTR => {},
                // Address of the futex was paged out. This is unlikely, but possible in theory, and
                // pthread/libdispatch on darwin bother to handle it. In this case we'll return
                // without waiting, but the caller should retry anyway.
                .FAULT => {},
                .TIMEDOUT => recoverableOsBugDetected(),
                else => recoverableOsBugDetected(),
            }
        },
        .windows => {
            switch (windows.ntdll.RtlWaitOnAddress(ptr, &expect, @sizeOf(@TypeOf(expect)), null)) {
                .SUCCESS, .CANCELLED => {},
                else => recoverableOsBugDetected(),
            }
        },
        .freebsd => {
            const flags = @intFromEnum(std.c.UMTX_OP.WAIT_UINT_PRIVATE);
            const rc = std.c._umtx_op(@intFromPtr(&ptr.raw), flags, @as(c_ulong, expect), 0, 0);
            switch (posix.errno(rc)) {
                .SUCCESS => {},
                .INTR => {}, // spurious wake
                .FAULT => recoverableOsBugDetected(), // one of the args points to invalid memory
                .INVAL => recoverableOsBugDetected(), // arguments should be correct
                .TIMEDOUT => recoverableOsBugDetected(), // no timeout provided
                else => recoverableOsBugDetected(),
            }
        },
        else => @compileError("unimplemented: futexWaitUncancelable"),
    }
}

pub fn futexWaitDurationUncancelable(ptr: *const std.atomic.Value(u32), expect: u32, timeout: Io.Duration) void {
    @branchHint(.cold);

    if (native_os == .linux) {
        const linux = std.os.linux;
        var ts = timestampToPosix(timeout.toNanoseconds());
        const rc = linux.futex_4arg(ptr, .{ .cmd = .WAIT, .private = true }, expect, &ts);
        if (is_debug) switch (linux.errno(rc)) {
            .SUCCESS => {}, // notified by `wake()`
            .INTR => {}, // gives caller a chance to check cancellation
            .AGAIN => {}, // ptr.* != expect
            .TIMEDOUT => {},
            .INVAL => {}, // possibly timeout overflow
            .FAULT => unreachable, // ptr was invalid
            else => unreachable,
        };
        return;
    } else {
        @compileError("TODO");
    }
}

pub fn futexWake(ptr: *const std.atomic.Value(u32), max_waiters: u32) void {
    @branchHint(.cold);

    if (builtin.cpu.arch.isWasm()) {
        comptime assert(builtin.cpu.has(.wasm, .atomics));
        assert(max_waiters != 0);
        const woken_count = asm volatile (
            \\local.get %[ptr]
            \\local.get %[waiters]
            \\memory.atomic.notify 0
            \\local.set %[ret]
            : [ret] "=r" (-> u32),
            : [ptr] "r" (&ptr.raw),
              [waiters] "r" (max_waiters),
        );
        _ = woken_count; // can be 0 when linker flag 'shared-memory' is not enabled
    } else switch (native_os) {
        .linux => {
            const linux = std.os.linux;
            switch (linux.errno(linux.futex_3arg(
                &ptr.raw,
                .{ .cmd = .WAKE, .private = true },
                @min(max_waiters, std.math.maxInt(i32)),
            ))) {
                .SUCCESS => return, // successful wake up
                .INVAL => return, // invalid futex_wait() on ptr done elsewhere
                .FAULT => return, // pointer became invalid while doing the wake
                else => return recoverableOsBugDetected(), // deadlock due to operating system bug
            }
        },
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => {
            const c = std.c;
            const flags: c.UL = .{
                .op = .COMPARE_AND_WAIT,
                .NO_ERRNO = true,
                .WAKE_ALL = max_waiters > 1,
            };
            while (true) {
                const status = c.__ulock_wake(flags, ptr, 0);
                if (status >= 0) return;
                switch (@as(c.E, @enumFromInt(-status))) {
                    .INTR, .CANCELED => continue, // spurious wake()
                    .FAULT => unreachable, // __ulock_wake doesn't generate EFAULT according to darwin pthread_cond_t
                    .NOENT => return, // nothing was woken up
                    .ALREADY => unreachable, // only for UL.Op.WAKE_THREAD
                    else => unreachable, // deadlock due to operating system bug
                }
            }
        },
        .windows => {
            assert(max_waiters != 0);
            switch (max_waiters) {
                1 => windows.ntdll.RtlWakeAddressSingle(ptr),
                else => windows.ntdll.RtlWakeAddressAll(ptr),
            }
        },
        .freebsd => {
            const rc = std.c._umtx_op(
                @intFromPtr(&ptr.raw),
                @intFromEnum(std.c.UMTX_OP.WAKE_PRIVATE),
                @as(c_ulong, max_waiters),
                0, // there is no timeout struct
                0, // there is no timeout struct pointer
            );
            switch (posix.errno(rc)) {
                .SUCCESS => {},
                .FAULT => {}, // it's ok if the ptr doesn't point to valid memory
                .INVAL => unreachable, // arguments should be correct
                else => unreachable, // deadlock due to operating system bug
            }
        },
        else => @compileError("unimplemented: futexWake"),
    }
}

/// A thread-safe logical boolean value which can be `set` and `unset`.
///
/// It can also block threads until the value is set with cancelation via timed
/// waits. Statically initializable; four bytes on all targets.
pub const ResetEvent = switch (native_os) {
    .illumos, .netbsd => ResetEventPosix,
    else => ResetEventFutex,
};

/// A `ResetEvent` implementation based on futexes.
const ResetEventFutex = enum(u32) {
    unset = 0,
    waiting = 1,
    is_set = 2,

    /// Returns whether the logical boolean is `set`.
    ///
    /// Once `reset` is called, this returns false until the next `set`.
    ///
    /// The memory accesses before the `set` can be said to happen before
    /// `isSet` returns true.
    pub fn isSet(ref: *const ResetEventFutex) bool {
        if (builtin.single_threaded) return switch (ref.*) {
            .unset => false,
            .waiting => unreachable,
            .is_set => true,
        };
        // Acquire barrier ensures memory accesses before `set` happen before
        // returning true.
        return @atomicLoad(ResetEventFutex, ref, .acquire) == .is_set;
    }

    /// Blocks the calling thread until `set` is called.
    ///
    /// This is effectively a more efficient version of `while (!isSet()) {}`.
    ///
    /// The memory accesses before the `set` can be said to happen before `wait` returns.
    pub fn wait(ref: *ResetEventFutex, t: *Threaded) Io.Cancelable!void {
        if (builtin.single_threaded) switch (ref.*) {
            .unset => unreachable, // Deadlock, no other threads to wake us up.
            .waiting => unreachable, // Invalid state.
            .is_set => return,
        };
        // Try to set the state from `unset` to `waiting` to indicate to the
        // `set` thread that others are blocked on the ResetEventFutex. Avoid using
        // any strict barriers until we know the ResetEventFutex is set.
        var state = @atomicLoad(ResetEventFutex, ref, .acquire);
        if (state == .is_set) {
            @branchHint(.likely);
            return;
        }
        if (state == .unset) {
            state = @cmpxchgStrong(ResetEventFutex, ref, state, .waiting, .acquire, .acquire) orelse .waiting;
        }
        while (state == .waiting) {
            try futexWait(t, @ptrCast(ref), @intFromEnum(ResetEventFutex.waiting));
            state = @atomicLoad(ResetEventFutex, ref, .acquire);
        }
        assert(state == .is_set);
    }

    /// Same as `wait` except uninterruptible.
    pub fn waitUncancelable(ref: *ResetEventFutex) void {
        if (builtin.single_threaded) switch (ref.*) {
            .unset => unreachable, // Deadlock, no other threads to wake us up.
            .waiting => unreachable, // Invalid state.
            .is_set => return,
        };
        // Try to set the state from `unset` to `waiting` to indicate to the
        // `set` thread that others are blocked on the ResetEventFutex. Avoid using
        // any strict barriers until we know the ResetEventFutex is set.
        var state = @atomicLoad(ResetEventFutex, ref, .acquire);
        if (state == .is_set) {
            @branchHint(.likely);
            return;
        }
        if (state == .unset) {
            state = @cmpxchgStrong(ResetEventFutex, ref, state, .waiting, .acquire, .acquire) orelse .waiting;
        }
        while (state == .waiting) {
            futexWaitUncancelable(@ptrCast(ref), @intFromEnum(ResetEventFutex.waiting));
            state = @atomicLoad(ResetEventFutex, ref, .acquire);
        }
        assert(state == .is_set);
    }

    /// Marks the logical boolean as `set` and unblocks any threads in `wait`
    /// or `timedWait` to observe the new state.
    ///
    /// The logical boolean stays `set` until `reset` is called, making future
    /// `set` calls do nothing semantically.
    ///
    /// The memory accesses before `set` can be said to happen before `isSet`
    /// returns true or `wait`/`timedWait` return successfully.
    pub fn set(ref: *ResetEventFutex) void {
        if (builtin.single_threaded) {
            ref.* = .is_set;
            return;
        }
        if (@atomicRmw(ResetEventFutex, ref, .Xchg, .is_set, .release) == .waiting) {
            futexWake(@ptrCast(ref), std.math.maxInt(u32));
        }
    }

    /// Unmarks the ResetEventFutex as if `set` was never called.
    ///
    /// Assumes no threads are blocked in `wait` or `timedWait`. Concurrent
    /// calls to `set`, `isSet` and `reset` are allowed.
    pub fn reset(ref: *ResetEventFutex) void {
        if (builtin.single_threaded) {
            ref.* = .unset;
            return;
        }
        @atomicStore(ResetEventFutex, ref, .unset, .monotonic);
    }
};

/// A `ResetEvent` implementation based on pthreads API.
const ResetEventPosix = struct {
    cond: std.c.pthread_cond_t,
    mutex: std.c.pthread_mutex_t,
    state: ResetEventFutex,

    pub const unset: ResetEventPosix = .{
        .cond = std.c.PTHREAD_COND_INITIALIZER,
        .mutex = std.c.PTHREAD_MUTEX_INITIALIZER,
        .state = .unset,
    };

    pub fn isSet(rep: *const ResetEventPosix) bool {
        if (builtin.single_threaded) return switch (rep.state) {
            .unset => false,
            .waiting => unreachable,
            .is_set => true,
        };
        return @atomicLoad(ResetEventFutex, &rep.state, .acquire) == .is_set;
    }

    pub fn wait(rep: *ResetEventPosix, t: *Threaded) Io.Cancelable!void {
        if (builtin.single_threaded) switch (rep.*) {
            .unset => unreachable, // Deadlock, no other threads to wake us up.
            .waiting => unreachable, // Invalid state.
            .is_set => return,
        };
        assert(std.c.pthread_mutex_lock(&rep.mutex) == .SUCCESS);
        defer assert(std.c.pthread_mutex_unlock(&rep.mutex) == .SUCCESS);
        sw: switch (rep.state) {
            .unset => {
                rep.state = .waiting;
                continue :sw .waiting;
            },
            .waiting => {
                try t.checkCancel();
                assert(std.c.pthread_cond_wait(&rep.cond, &rep.mutex) == .SUCCESS);
                continue :sw rep.state;
            },
            .is_set => return,
        }
    }

    pub fn waitUncancelable(rep: *ResetEventPosix) void {
        if (builtin.single_threaded) switch (rep.*) {
            .unset => unreachable, // Deadlock, no other threads to wake us up.
            .waiting => unreachable, // Invalid state.
            .is_set => return,
        };
        assert(std.c.pthread_mutex_lock(&rep.mutex) == .SUCCESS);
        defer assert(std.c.pthread_mutex_unlock(&rep.mutex) == .SUCCESS);
        sw: switch (rep.state) {
            .unset => {
                rep.state = .waiting;
                continue :sw .waiting;
            },
            .waiting => {
                assert(std.c.pthread_cond_wait(&rep.cond, &rep.mutex) == .SUCCESS);
                continue :sw rep.state;
            },
            .is_set => return,
        }
    }

    pub fn set(rep: *ResetEventPosix) void {
        if (builtin.single_threaded) {
            rep.* = .is_set;
            return;
        }
        if (@atomicRmw(ResetEventFutex, &rep.state, .Xchg, .is_set, .release) == .waiting) {
            assert(std.c.pthread_cond_broadcast(&rep.cond) == .SUCCESS);
        }
    }

    pub fn reset(rep: *ResetEventPosix) void {
        if (builtin.single_threaded) {
            rep.* = .unset;
            return;
        }
        @atomicStore(ResetEventFutex, &rep.state, .unset, .monotonic);
    }
};

fn closeSocketWindows(s: ws2_32.SOCKET) void {
    const rc = ws2_32.closesocket(s);
    if (is_debug) switch (rc) {
        0 => {},
        ws2_32.SOCKET_ERROR => switch (ws2_32.WSAGetLastError()) {
            else => recoverableOsBugDetected(),
        },
        else => recoverableOsBugDetected(),
    };
}

const Wsa = struct {
    status: Status = .uninitialized,
    mutex: Io.Mutex = .init,
    init_error: ?Wsa.InitError = null,

    const Status = enum { uninitialized, initialized, failure };

    const InitError = error{
        ProcessFdQuotaExceeded,
        NetworkDown,
        VersionUnsupported,
        BlockingOperationInProgress,
    } || Io.UnexpectedError;
};

fn initializeWsa(t: *Threaded) error{NetworkDown}!void {
    const t_io = io(t);
    const wsa = &t.wsa;
    wsa.mutex.lockUncancelable(t_io);
    defer wsa.mutex.unlock(t_io);
    switch (wsa.status) {
        .uninitialized => {
            var wsa_data: ws2_32.WSADATA = undefined;
            const minor_version = 2;
            const major_version = 2;
            switch (ws2_32.WSAStartup((@as(windows.WORD, minor_version) << 8) | major_version, &wsa_data)) {
                0 => {
                    wsa.status = .initialized;
                    return;
                },
                else => |err_int| switch (@as(ws2_32.WinsockError, @enumFromInt(@as(u16, @intCast(err_int))))) {
                    .SYSNOTREADY => wsa.init_error = error.NetworkDown,
                    .VERNOTSUPPORTED => wsa.init_error = error.VersionUnsupported,
                    .EINPROGRESS => wsa.init_error = error.BlockingOperationInProgress,
                    .EPROCLIM => wsa.init_error = error.ProcessFdQuotaExceeded,
                    else => |err| wsa.init_error = windows.unexpectedWSAError(err),
                },
            }
        },
        .initialized => return,
        .failure => {},
    }
    return error.NetworkDown;
}

fn doNothingSignalHandler(_: posix.SIG) callconv(.c) void {}

test {
    _ = @import("Threaded/test.zig");
}
