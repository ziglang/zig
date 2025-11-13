//! This struct represents a kernel thread, and acts as a namespace for concurrency
//! primitives that operate on kernel threads. For concurrency primitives that support
//! both evented I/O and async I/O, see the respective names in the top level std namespace.

const std = @import("std.zig");
const builtin = @import("builtin");
const math = std.math;
const assert = std.debug.assert;
const target = builtin.target;
const native_os = builtin.os.tag;
const posix = std.posix;
const windows = std.os.windows;
const testing = std.testing;

pub const Futex = @import("Thread/Futex.zig");
pub const Mutex = @import("Thread/Mutex.zig");
pub const Semaphore = @import("Thread/Semaphore.zig");
pub const Condition = @import("Thread/Condition.zig");
pub const RwLock = @import("Thread/RwLock.zig");
pub const Pool = @import("Thread/Pool.zig");
pub const WaitGroup = @import("Thread/WaitGroup.zig");

pub const use_pthreads = native_os != .windows and native_os != .wasi and builtin.link_libc;

/// A thread-safe logical boolean value which can be `set` and `unset`.
///
/// It can also block threads until the value is set with cancelation via timed
/// waits. Statically initializable; four bytes on all targets.
pub const ResetEvent = enum(u32) {
    unset = 0,
    waiting = 1,
    is_set = 2,

    /// Returns whether the logical boolean is `set`.
    ///
    /// Once `reset` is called, this returns false until the next `set`.
    ///
    /// The memory accesses before the `set` can be said to happen before
    /// `isSet` returns true.
    pub fn isSet(re: *const ResetEvent) bool {
        if (builtin.single_threaded) return switch (re.*) {
            .unset => false,
            .waiting => unreachable,
            .is_set => true,
        };
        // Acquire barrier ensures memory accesses before `set` happen before
        // returning true.
        return @atomicLoad(ResetEvent, re, .acquire) == .is_set;
    }

    /// Blocks the calling thread until `set` is called.
    ///
    /// This is effectively a more efficient version of `while (!isSet()) {}`.
    ///
    /// The memory accesses before the `set` can be said to happen before `wait` returns.
    pub fn wait(re: *ResetEvent) void {
        if (builtin.single_threaded) switch (re.*) {
            .unset => unreachable, // Deadlock, no other threads to wake us up.
            .waiting => unreachable, // Invalid state.
            .is_set => return,
        };
        if (!re.isSet()) return timedWaitInner(re, null) catch |err| switch (err) {
            error.Timeout => unreachable, // No timeout specified.
        };
    }

    /// Blocks the calling thread until `set` is called, or until the
    /// corresponding timeout expires, returning `error.Timeout`.
    ///
    /// This is effectively a more efficient version of `while (!isSet()) {}`.
    ///
    /// The memory accesses before the set() can be said to happen before
    /// timedWait() returns without error.
    pub fn timedWait(re: *ResetEvent, timeout_ns: u64) error{Timeout}!void {
        if (builtin.single_threaded) switch (re.*) {
            .unset => return error.Timeout,
            .waiting => unreachable, // Invalid state.
            .is_set => return,
        };
        if (!re.isSet()) return timedWaitInner(re, timeout_ns);
    }

    fn timedWaitInner(re: *ResetEvent, timeout: ?u64) error{Timeout}!void {
        @branchHint(.cold);

        // Try to set the state from `unset` to `waiting` to indicate to the
        // `set` thread that others are blocked on the ResetEvent. Avoid using
        // any strict barriers until we know the ResetEvent is set.
        var state = @atomicLoad(ResetEvent, re, .acquire);
        if (state == .unset) {
            state = @cmpxchgStrong(ResetEvent, re, state, .waiting, .acquire, .acquire) orelse .waiting;
        }

        // Wait until the ResetEvent is set since the state is waiting.
        if (state == .waiting) {
            var futex_deadline = Futex.Deadline.init(timeout);
            while (true) {
                const wait_result = futex_deadline.wait(@ptrCast(re), @intFromEnum(ResetEvent.waiting));

                // Check if the ResetEvent was set before possibly reporting error.Timeout below.
                state = @atomicLoad(ResetEvent, re, .acquire);
                if (state != .waiting) break;

                try wait_result;
            }
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
    pub fn set(re: *ResetEvent) void {
        if (builtin.single_threaded) {
            re.* = .is_set;
            return;
        }
        if (@atomicRmw(ResetEvent, re, .Xchg, .is_set, .release) == .waiting) {
            Futex.wake(@ptrCast(re), std.math.maxInt(u32));
        }
    }

    /// Unmarks the ResetEvent as if `set` was never called.
    ///
    /// Assumes no threads are blocked in `wait` or `timedWait`. Concurrent
    /// calls to `set`, `isSet` and `reset` are allowed.
    pub fn reset(re: *ResetEvent) void {
        if (builtin.single_threaded) {
            re.* = .unset;
            return;
        }
        @atomicStore(ResetEvent, re, .unset, .monotonic);
    }
};

const Thread = @This();
const Impl = if (native_os == .windows)
    WindowsThreadImpl
else if (use_pthreads)
    PosixThreadImpl
else if (native_os == .linux)
    LinuxThreadImpl
else if (native_os == .wasi)
    WasiThreadImpl
else
    UnsupportedImpl;

impl: Impl,

pub const max_name_len = switch (native_os) {
    .linux => 15,
    .windows => 31,
    .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => 63,
    .netbsd => 31,
    .freebsd => 15,
    .openbsd => 23,
    .dragonfly => 1023,
    .illumos => 31,
    // https://github.com/SerenityOS/serenity/blob/6b4c300353da49d3508b5442cf61da70bd04d757/Kernel/Tasks/Thread.h#L102
    .serenity => 63,
    else => 0,
};

pub const SetNameError = error{
    NameTooLong,
    Unsupported,
    Unexpected,
    InvalidWtf8,
} || posix.PrctlError || posix.WriteError || std.fs.File.OpenError || std.fmt.BufPrintError;

pub fn setName(self: Thread, name: []const u8) SetNameError!void {
    if (name.len > max_name_len) return error.NameTooLong;

    const name_with_terminator = blk: {
        var name_buf: [max_name_len:0]u8 = undefined;
        @memcpy(name_buf[0..name.len], name);
        name_buf[name.len] = 0;
        break :blk name_buf[0..name.len :0];
    };

    switch (native_os) {
        .linux => if (use_pthreads) {
            if (self.getHandle() == std.c.pthread_self()) {
                // Set the name of the calling thread (no thread id required).
                const err = try posix.prctl(.SET_NAME, .{@intFromPtr(name_with_terminator.ptr)});
                switch (@as(posix.E, @enumFromInt(err))) {
                    .SUCCESS => return,
                    else => |e| return posix.unexpectedErrno(e),
                }
            } else {
                const err = std.c.pthread_setname_np(self.getHandle(), name_with_terminator.ptr);
                switch (@as(posix.E, @enumFromInt(err))) {
                    .SUCCESS => return,
                    .RANGE => unreachable,
                    else => |e| return posix.unexpectedErrno(e),
                }
            }
        } else {
            var buf: [32]u8 = undefined;
            const path = try std.fmt.bufPrint(&buf, "/proc/self/task/{d}/comm", .{self.getHandle()});

            const file = try std.fs.cwd().openFile(path, .{ .mode = .write_only });
            defer file.close();

            try file.writeAll(name);
            return;
        },
        .windows => {
            var buf: [max_name_len]u16 = undefined;
            const len = try std.unicode.wtf8ToWtf16Le(&buf, name);
            const byte_len = math.cast(c_ushort, len * 2) orelse return error.NameTooLong;

            // Note: NT allocates its own copy, no use-after-free here.
            const unicode_string = windows.UNICODE_STRING{
                .Length = byte_len,
                .MaximumLength = byte_len,
                .Buffer = &buf,
            };

            switch (windows.ntdll.NtSetInformationThread(
                self.getHandle(),
                .ThreadNameInformation,
                &unicode_string,
                @sizeOf(windows.UNICODE_STRING),
            )) {
                .SUCCESS => return,
                .NOT_IMPLEMENTED => return error.Unsupported,
                else => |err| return windows.unexpectedStatus(err),
            }
        },
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => if (use_pthreads) {
            // There doesn't seem to be a way to set the name for an arbitrary thread, only the current one.
            if (self.getHandle() != std.c.pthread_self()) return error.Unsupported;

            const err = std.c.pthread_setname_np(name_with_terminator.ptr);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        .serenity => if (use_pthreads) {
            const err = std.c.pthread_setname_np(self.getHandle(), name_with_terminator.ptr);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return,
                .NAMETOOLONG => unreachable,
                .SRCH => unreachable,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        .netbsd, .illumos => if (use_pthreads) {
            const err = std.c.pthread_setname_np(self.getHandle(), name_with_terminator.ptr, null);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return,
                .INVAL => unreachable,
                .SRCH => unreachable,
                .NOMEM => unreachable,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        .freebsd, .openbsd => if (use_pthreads) {
            // Use pthread_set_name_np for FreeBSD because pthread_setname_np is FreeBSD 12.2+ only.
            // TODO maybe revisit this if depending on FreeBSD 12.2+ is acceptable because
            // pthread_setname_np can return an error.

            std.c.pthread_set_name_np(self.getHandle(), name_with_terminator.ptr);
            return;
        },
        .dragonfly => if (use_pthreads) {
            const err = std.c.pthread_setname_np(self.getHandle(), name_with_terminator.ptr);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return,
                .INVAL => unreachable,
                .FAULT => unreachable,
                .NAMETOOLONG => unreachable, // already checked
                .SRCH => unreachable,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        else => {},
    }
    return error.Unsupported;
}

pub const GetNameError = error{
    Unsupported,
    Unexpected,
} || posix.PrctlError || posix.ReadError || std.fs.File.OpenError || std.fmt.BufPrintError;

/// On Windows, the result is encoded as [WTF-8](https://wtf-8.codeberg.page/).
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
pub fn getName(self: Thread, buffer_ptr: *[max_name_len:0]u8) GetNameError!?[]const u8 {
    buffer_ptr[max_name_len] = 0;
    var buffer: [:0]u8 = buffer_ptr;

    switch (native_os) {
        .linux => if (use_pthreads) {
            if (self.getHandle() == std.c.pthread_self()) {
                // Get the name of the calling thread (no thread id required).
                const err = try posix.prctl(.GET_NAME, .{@intFromPtr(buffer.ptr)});
                switch (@as(posix.E, @enumFromInt(err))) {
                    .SUCCESS => return std.mem.sliceTo(buffer, 0),
                    else => |e| return posix.unexpectedErrno(e),
                }
            } else {
                const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
                switch (@as(posix.E, @enumFromInt(err))) {
                    .SUCCESS => return std.mem.sliceTo(buffer, 0),
                    .RANGE => unreachable,
                    else => |e| return posix.unexpectedErrno(e),
                }
            }
        } else {
            var buf: [32]u8 = undefined;
            const path = try std.fmt.bufPrint(&buf, "/proc/self/task/{d}/comm", .{self.getHandle()});

            var threaded: std.Io.Threaded = .init_single_threaded;
            const io = threaded.ioBasic();

            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            var file_reader = file.readerStreaming(io, &.{});
            const data_len = file_reader.interface.readSliceShort(buffer_ptr[0 .. max_name_len + 1]) catch |err| switch (err) {
                error.ReadFailed => return file_reader.err.?,
            };
            return if (data_len >= 1) buffer[0 .. data_len - 1] else null;
        },
        .windows => {
            const buf_capacity = @sizeOf(windows.UNICODE_STRING) + (@sizeOf(u16) * max_name_len);
            var buf: [buf_capacity]u8 align(@alignOf(windows.UNICODE_STRING)) = undefined;

            switch (windows.ntdll.NtQueryInformationThread(
                self.getHandle(),
                .ThreadNameInformation,
                &buf,
                buf_capacity,
                null,
            )) {
                .SUCCESS => {
                    const string = @as(*const windows.UNICODE_STRING, @ptrCast(&buf));
                    const len = std.unicode.wtf16LeToWtf8(buffer, string.Buffer.?[0 .. string.Length / 2]);
                    return if (len > 0) buffer[0..len] else null;
                },
                .NOT_IMPLEMENTED => return error.Unsupported,
                else => |err| return windows.unexpectedStatus(err),
            }
        },
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => if (use_pthreads) {
            const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return std.mem.sliceTo(buffer, 0),
                .SRCH => unreachable,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        .serenity => if (use_pthreads) {
            const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return,
                .NAMETOOLONG => unreachable,
                .SRCH => unreachable,
                .FAULT => unreachable,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        .netbsd, .illumos => if (use_pthreads) {
            const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return std.mem.sliceTo(buffer, 0),
                .INVAL => unreachable,
                .SRCH => unreachable,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        .freebsd, .openbsd => if (use_pthreads) {
            // Use pthread_get_name_np for FreeBSD because pthread_getname_np is FreeBSD 12.2+ only.
            // TODO maybe revisit this if depending on FreeBSD 12.2+ is acceptable because pthread_getname_np can return an error.

            std.c.pthread_get_name_np(self.getHandle(), buffer.ptr, max_name_len + 1);
            return std.mem.sliceTo(buffer, 0);
        },
        .dragonfly => if (use_pthreads) {
            const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
            switch (@as(posix.E, @enumFromInt(err))) {
                .SUCCESS => return std.mem.sliceTo(buffer, 0),
                .INVAL => unreachable,
                .FAULT => unreachable,
                .SRCH => unreachable,
                else => |e| return posix.unexpectedErrno(e),
            }
        },
        else => {},
    }
    return error.Unsupported;
}

/// Represents an ID per thread guaranteed to be unique only within a process.
pub const Id = switch (native_os) {
    .linux,
    .dragonfly,
    .netbsd,
    .freebsd,
    .openbsd,
    .haiku,
    .wasi,
    .serenity,
    => u32,
    .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => u64,
    .windows => windows.DWORD,
    else => usize,
};

/// Returns the platform ID of the callers thread.
/// Attempts to use thread locals and avoid syscalls when possible.
pub fn getCurrentId() Id {
    return Impl.getCurrentId();
}

pub const CpuCountError = error{
    PermissionDenied,
    SystemResources,
    Unsupported,
    Unexpected,
};

/// Returns the platforms view on the number of logical CPU cores available.
///
/// Returned value guaranteed to be >= 1.
pub fn getCpuCount() CpuCountError!usize {
    return try Impl.getCpuCount();
}

/// Configuration options for hints on how to spawn threads.
pub const SpawnConfig = struct {
    // TODO compile-time call graph analysis to determine stack upper bound
    // https://github.com/ziglang/zig/issues/157

    /// Size in bytes of the Thread's stack
    stack_size: usize = default_stack_size,
    /// The allocator to be used to allocate memory for the to-be-spawned thread
    allocator: ?std.mem.Allocator = null,

    pub const default_stack_size = 16 * 1024 * 1024;
};

pub const SpawnError = error{
    /// A system-imposed limit on the number of threads was encountered.
    /// There are a number of limits that may trigger this error:
    /// *  the  RLIMIT_NPROC soft resource limit (set via setrlimit(2)),
    ///    which limits the number of processes and threads for  a  real
    ///    user ID, was reached;
    /// *  the kernel's system-wide limit on the number of processes and
    ///    threads,  /proc/sys/kernel/threads-max,  was   reached   (see
    ///    proc(5));
    /// *  the  maximum  number  of  PIDs, /proc/sys/kernel/pid_max, was
    ///    reached (see proc(5)); or
    /// *  the PID limit (pids.max) imposed by the cgroup "process  num‐
    ///    ber" (PIDs) controller was reached.
    ThreadQuotaExceeded,

    /// The kernel cannot allocate sufficient memory to allocate a task structure
    /// for the child, or to copy those parts of the caller's context that need to
    /// be copied.
    SystemResources,

    /// Not enough userland memory to spawn the thread.
    OutOfMemory,

    /// `mlockall` is enabled, and the memory needed to spawn the thread
    /// would exceed the limit.
    LockedMemoryLimitExceeded,

    Unexpected,
};

/// Spawns a new thread which executes `function` using `args` and returns a handle to the spawned thread.
/// `config` can be used as hints to the platform for how to spawn and execute the `function`.
/// The caller must eventually either call `join()` to wait for the thread to finish and free its resources
/// or call `detach()` to excuse the caller from calling `join()` and have the thread clean up its resources on completion.
pub fn spawn(config: SpawnConfig, comptime function: anytype, args: anytype) SpawnError!Thread {
    if (builtin.single_threaded) {
        @compileError("Cannot spawn thread when building in single-threaded mode");
    }

    const impl = try Impl.spawn(config, function, args);
    return Thread{ .impl = impl };
}

/// Represents a kernel thread handle.
/// May be an integer or a pointer depending on the platform.
pub const Handle = Impl.ThreadHandle;

/// Returns the handle of this thread
pub fn getHandle(self: Thread) Handle {
    return self.impl.getHandle();
}

/// Release the obligation of the caller to call `join()` and have the thread clean up its own resources on completion.
/// Once called, this consumes the Thread object and invoking any other functions on it is considered undefined behavior.
pub fn detach(self: Thread) void {
    return self.impl.detach();
}

/// Waits for the thread to complete, then deallocates any resources created on `spawn()`.
/// Once called, this consumes the Thread object and invoking any other functions on it is considered undefined behavior.
pub fn join(self: Thread) void {
    return self.impl.join();
}

pub const YieldError = error{
    /// The system is not configured to allow yielding
    SystemCannotYield,
};

/// Yields the current thread potentially allowing other threads to run.
pub fn yield() YieldError!void {
    if (native_os == .windows) {
        // The return value has to do with how many other threads there are; it is not
        // an error condition on Windows.
        _ = windows.kernel32.SwitchToThread();
        return;
    }
    switch (posix.errno(posix.system.sched_yield())) {
        .SUCCESS => return,
        .NOSYS => return error.SystemCannotYield,
        else => return error.SystemCannotYield,
    }
}

/// State to synchronize detachment of spawner thread to spawned thread
const Completion = std.atomic.Value(enum(if (builtin.zig_backend == .stage2_riscv64) u32 else u8) {
    running,
    detached,
    completed,
});

/// Used by the Thread implementations to call the spawned function with the arguments.
fn callFn(comptime f: anytype, args: anytype) switch (Impl) {
    WindowsThreadImpl => windows.DWORD,
    LinuxThreadImpl => u8,
    PosixThreadImpl => ?*anyopaque,
    else => unreachable,
} {
    const default_value = if (Impl == PosixThreadImpl) null else 0;
    const bad_fn_ret = "expected return type of startFn to be 'u8', 'noreturn', '!noreturn', 'void', or '!void'";

    switch (@typeInfo(@typeInfo(@TypeOf(f)).@"fn".return_type.?)) {
        .noreturn => {
            @call(.auto, f, args);
        },
        .void => {
            @call(.auto, f, args);
            return default_value;
        },
        .int => |info| {
            if (info.bits != 8) {
                @compileError(bad_fn_ret);
            }

            const status = @call(.auto, f, args);
            if (Impl != PosixThreadImpl) {
                return status;
            }

            // pthreads don't support exit status, ignore value
            return default_value;
        },
        .error_union => |info| {
            switch (info.payload) {
                void, noreturn => {
                    @call(.auto, f, args) catch |err| {
                        std.debug.print("error: {s}\n", .{@errorName(err)});
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpStackTrace(trace);
                        }
                    };

                    return default_value;
                },
                else => {
                    @compileError(bad_fn_ret);
                },
            }
        },
        else => {
            @compileError(bad_fn_ret);
        },
    }
}

/// We can't compile error in the `Impl` switch statement as its eagerly evaluated.
/// So instead, we compile-error on the methods themselves for platforms which don't support threads.
const UnsupportedImpl = struct {
    pub const ThreadHandle = void;

    fn getCurrentId() usize {
        return unsupported({});
    }

    fn getCpuCount() !usize {
        return unsupported({});
    }

    fn spawn(config: SpawnConfig, comptime f: anytype, args: anytype) !Impl {
        return unsupported(.{ config, f, args });
    }

    fn getHandle(self: Impl) ThreadHandle {
        return unsupported(self);
    }

    fn detach(self: Impl) void {
        return unsupported(self);
    }

    fn join(self: Impl) void {
        return unsupported(self);
    }

    fn unsupported(unused: anytype) noreturn {
        _ = unused;
        @compileError("Unsupported operating system " ++ @tagName(native_os));
    }
};

const WindowsThreadImpl = struct {
    pub const ThreadHandle = windows.HANDLE;

    fn getCurrentId() windows.DWORD {
        return windows.GetCurrentThreadId();
    }

    fn getCpuCount() !usize {
        // Faster than calling into GetSystemInfo(), even if amortized.
        return windows.peb().NumberOfProcessors;
    }

    thread: *ThreadCompletion,

    const ThreadCompletion = struct {
        completion: Completion,
        heap_ptr: windows.PVOID,
        heap_handle: windows.HANDLE,
        thread_handle: windows.HANDLE = undefined,

        fn free(self: ThreadCompletion) void {
            const status = windows.kernel32.HeapFree(self.heap_handle, 0, self.heap_ptr);
            assert(status != 0);
        }
    };

    fn spawn(config: SpawnConfig, comptime f: anytype, args: anytype) !Impl {
        const Args = @TypeOf(args);
        const Instance = struct {
            fn_args: Args,
            thread: ThreadCompletion,

            fn entryFn(raw_ptr: windows.PVOID) callconv(.winapi) windows.DWORD {
                const self: *@This() = @ptrCast(@alignCast(raw_ptr));
                defer switch (self.thread.completion.swap(.completed, .seq_cst)) {
                    .running => {},
                    .completed => unreachable,
                    .detached => self.thread.free(),
                };
                return callFn(f, self.fn_args);
            }
        };

        const heap_handle = windows.kernel32.GetProcessHeap() orelse return error.OutOfMemory;
        const alloc_bytes = @alignOf(Instance) + @sizeOf(Instance);
        const alloc_ptr = windows.ntdll.RtlAllocateHeap(heap_handle, 0, alloc_bytes) orelse return error.OutOfMemory;
        errdefer assert(windows.kernel32.HeapFree(heap_handle, 0, alloc_ptr) != 0);

        const instance_bytes = @as([*]u8, @ptrCast(alloc_ptr))[0..alloc_bytes];
        var fba = std.heap.FixedBufferAllocator.init(instance_bytes);
        const instance = fba.allocator().create(Instance) catch unreachable;
        instance.* = .{
            .fn_args = args,
            .thread = .{
                .completion = Completion.init(.running),
                .heap_ptr = alloc_ptr,
                .heap_handle = heap_handle,
            },
        };

        // Windows appears to only support SYSTEM_INFO.dwAllocationGranularity minimum stack size.
        // Going lower makes it default to that specified in the executable (~1mb).
        // Its also fine if the limit here is incorrect as stack size is only a hint.
        var stack_size = std.math.cast(u32, config.stack_size) orelse std.math.maxInt(u32);
        stack_size = @max(64 * 1024, stack_size);

        instance.thread.thread_handle = windows.kernel32.CreateThread(
            null,
            stack_size,
            Instance.entryFn,
            instance,
            0,
            null,
        ) orelse {
            const errno = windows.GetLastError();
            return windows.unexpectedError(errno);
        };

        return Impl{ .thread = &instance.thread };
    }

    fn getHandle(self: Impl) ThreadHandle {
        return self.thread.thread_handle;
    }

    fn detach(self: Impl) void {
        windows.CloseHandle(self.thread.thread_handle);
        switch (self.thread.completion.swap(.detached, .seq_cst)) {
            .running => {},
            .completed => self.thread.free(),
            .detached => unreachable,
        }
    }

    fn join(self: Impl) void {
        windows.WaitForSingleObjectEx(self.thread.thread_handle, windows.INFINITE, false) catch unreachable;
        windows.CloseHandle(self.thread.thread_handle);
        assert(self.thread.completion.load(.seq_cst) == .completed);
        self.thread.free();
    }
};

const PosixThreadImpl = struct {
    const c = std.c;

    pub const ThreadHandle = c.pthread_t;

    fn getCurrentId() Id {
        switch (native_os) {
            .linux => {
                return LinuxThreadImpl.getCurrentId();
            },
            .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => {
                var thread_id: u64 = undefined;
                // Pass thread=null to get the current thread ID.
                assert(c.pthread_threadid_np(null, &thread_id) == 0);
                return thread_id;
            },
            .dragonfly => {
                return @as(u32, @bitCast(c.lwp_gettid()));
            },
            .netbsd => {
                return @as(u32, @bitCast(c._lwp_self()));
            },
            .freebsd => {
                return @as(u32, @bitCast(c.pthread_getthreadid_np()));
            },
            .openbsd => {
                return @as(u32, @bitCast(c.getthrid()));
            },
            .haiku => {
                return @as(u32, @bitCast(c.find_thread(null)));
            },
            .serenity => {
                return @as(u32, @bitCast(c.pthread_self()));
            },
            else => {
                return @intFromPtr(c.pthread_self());
            },
        }
    }

    fn getCpuCount() !usize {
        switch (native_os) {
            .linux => {
                return LinuxThreadImpl.getCpuCount();
            },
            .openbsd => {
                var count: c_int = undefined;
                var count_size: usize = @sizeOf(c_int);
                const mib = [_]c_int{ std.c.CTL.HW, std.c.HW.NCPUONLINE };
                posix.sysctl(&mib, &count, &count_size, null, 0) catch |err| switch (err) {
                    error.NameTooLong, error.UnknownName => unreachable,
                    else => |e| return e,
                };
                return @as(usize, @intCast(count));
            },
            .illumos, .serenity => {
                // The "proper" way to get the cpu count would be to query
                // /dev/kstat via ioctls, and traverse a linked list for each
                // cpu. (illumos)
                const rc = c.sysconf(@intFromEnum(std.c._SC.NPROCESSORS_ONLN));
                return switch (posix.errno(rc)) {
                    .SUCCESS => @as(usize, @intCast(rc)),
                    else => |err| posix.unexpectedErrno(err),
                };
            },
            .haiku => {
                var system_info: std.c.system_info = undefined;
                const rc = std.c.get_system_info(&system_info); // always returns B_OK
                return switch (posix.errno(rc)) {
                    .SUCCESS => @as(usize, @intCast(system_info.cpu_count)),
                    else => |err| posix.unexpectedErrno(err),
                };
            },
            else => {
                var count: c_int = undefined;
                var count_len: usize = @sizeOf(c_int);
                const name = if (comptime target.os.tag.isDarwin()) "hw.logicalcpu" else "hw.ncpu";
                posix.sysctlbynameZ(name, &count, &count_len, null, 0) catch |err| switch (err) {
                    error.UnknownName => unreachable,
                    else => |e| return e,
                };
                return @as(usize, @intCast(count));
            },
        }
    }

    handle: ThreadHandle,

    fn spawn(config: SpawnConfig, comptime f: anytype, args: anytype) !Impl {
        const Args = @TypeOf(args);
        const allocator = std.heap.c_allocator;

        const Instance = struct {
            fn entryFn(raw_arg: ?*anyopaque) callconv(.c) ?*anyopaque {
                const args_ptr: *Args = @ptrCast(@alignCast(raw_arg));
                defer allocator.destroy(args_ptr);
                return callFn(f, args_ptr.*);
            }
        };

        const args_ptr = try allocator.create(Args);
        args_ptr.* = args;
        errdefer allocator.destroy(args_ptr);

        var attr: c.pthread_attr_t = undefined;
        if (c.pthread_attr_init(&attr) != .SUCCESS) return error.SystemResources;
        defer assert(c.pthread_attr_destroy(&attr) == .SUCCESS);

        // Use the same set of parameters used by the libc-less impl.
        const stack_size = @max(config.stack_size, 16 * 1024);
        assert(c.pthread_attr_setstacksize(&attr, stack_size) == .SUCCESS);
        assert(c.pthread_attr_setguardsize(&attr, std.heap.pageSize()) == .SUCCESS);

        var handle: c.pthread_t = undefined;
        switch (c.pthread_create(
            &handle,
            &attr,
            Instance.entryFn,
            @ptrCast(args_ptr),
        )) {
            .SUCCESS => return Impl{ .handle = handle },
            .AGAIN => return error.SystemResources,
            .PERM => unreachable,
            .INVAL => unreachable,
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    fn getHandle(self: Impl) ThreadHandle {
        return self.handle;
    }

    fn detach(self: Impl) void {
        switch (c.pthread_detach(self.handle)) {
            .SUCCESS => {},
            .INVAL => unreachable, // thread handle is not joinable
            .SRCH => unreachable, // thread handle is invalid
            else => unreachable,
        }
    }

    fn join(self: Impl) void {
        switch (c.pthread_join(self.handle, null)) {
            .SUCCESS => {},
            .INVAL => unreachable, // thread handle is not joinable (or another thread is already joining in)
            .SRCH => unreachable, // thread handle is invalid
            .DEADLK => unreachable, // two threads tried to join each other
            else => unreachable,
        }
    }
};

const WasiThreadImpl = struct {
    thread: *WasiThread,

    pub const ThreadHandle = i32;
    threadlocal var tls_thread_id: Id = 0;

    const WasiThread = struct {
        /// Thread ID
        tid: std.atomic.Value(i32) = std.atomic.Value(i32).init(0),
        /// Contains all memory which was allocated to bootstrap this thread, including:
        /// - Guard page
        /// - Stack
        /// - TLS segment
        /// - `Instance`
        /// All memory is freed upon call to `join`
        memory: []u8,
        /// The allocator used to allocate the thread's memory,
        /// which is also used during `join` to ensure clean-up.
        allocator: std.mem.Allocator,
        /// The current state of the thread.
        state: State = State.init(.running),
    };

    /// A meta-data structure used to bootstrap a thread
    const Instance = struct {
        thread: WasiThread,
        /// Contains the offset to the new __tls_base.
        /// The offset starting from the memory's base.
        tls_offset: usize,
        /// Contains the offset to the stack for the newly spawned thread.
        /// The offset is calculated starting from the memory's base.
        stack_offset: usize,
        /// Contains the raw pointer value to the wrapper which holds all arguments
        /// for the callback.
        raw_ptr: usize,
        /// Function pointer to a wrapping function which will call the user's
        /// function upon thread spawn. The above mentioned pointer will be passed
        /// to this function pointer as its argument.
        call_back: *const fn (usize) void,
        /// When a thread is in `detached` state, we must free all of its memory
        /// upon thread completion. However, as this is done while still within
        /// the thread, we must first jump back to the main thread's stack or else
        /// we end up freeing the stack that we're currently using.
        original_stack_pointer: [*]u8,
    };

    const State = std.atomic.Value(enum(u8) { running, completed, detached });

    fn getCurrentId() Id {
        return tls_thread_id;
    }

    fn getCpuCount() error{Unsupported}!noreturn {
        return error.Unsupported;
    }

    fn getHandle(self: Impl) ThreadHandle {
        return self.thread.tid.load(.seq_cst);
    }

    fn detach(self: Impl) void {
        switch (self.thread.state.swap(.detached, .seq_cst)) {
            .running => {},
            .completed => self.join(),
            .detached => unreachable,
        }
    }

    fn join(self: Impl) void {
        defer {
            // Create a copy of the allocator so we do not free the reference to the
            // original allocator while freeing the memory.
            var allocator = self.thread.allocator;
            allocator.free(self.thread.memory);
        }

        while (true) {
            const tid = self.thread.tid.load(.seq_cst);
            if (tid == 0) break;

            const result = asm (
                \\ local.get %[ptr]
                \\ local.get %[expected]
                \\ i64.const -1 # infinite
                \\ memory.atomic.wait32 0
                \\ local.set %[ret]
                : [ret] "=r" (-> u32),
                : [ptr] "r" (&self.thread.tid.raw),
                  [expected] "r" (tid),
            );
            switch (result) {
                0 => continue, // ok
                1 => continue, // expected =! loaded
                2 => unreachable, // timeout (infinite)
                else => unreachable,
            }
        }
    }

    fn spawn(config: std.Thread.SpawnConfig, comptime f: anytype, args: anytype) SpawnError!WasiThreadImpl {
        if (config.allocator == null) {
            @panic("an allocator is required to spawn a WASI thread");
        }

        // Wrapping struct required to hold the user-provided function arguments.
        const Wrapper = struct {
            args: @TypeOf(args),
            fn entry(ptr: usize) void {
                const w: *@This() = @ptrFromInt(ptr);
                const bad_fn_ret = "expected return type of startFn to be 'u8', 'noreturn', 'void', or '!void'";
                switch (@typeInfo(@typeInfo(@TypeOf(f)).@"fn".return_type.?)) {
                    .noreturn, .void => {
                        @call(.auto, f, w.args);
                    },
                    .int => |info| {
                        if (info.bits != 8) {
                            @compileError(bad_fn_ret);
                        }
                        _ = @call(.auto, f, w.args); // WASI threads don't support exit status, ignore value
                    },
                    .error_union => |info| {
                        if (info.payload != void) {
                            @compileError(bad_fn_ret);
                        }
                        @call(.auto, f, w.args) catch |err| {
                            std.debug.print("error: {s}\n", .{@errorName(err)});
                            if (@errorReturnTrace()) |trace| {
                                std.debug.dumpStackTrace(trace);
                            }
                        };
                    },
                    else => {
                        @compileError(bad_fn_ret);
                    },
                }
            }
        };

        var stack_offset: usize = undefined;
        var tls_offset: usize = undefined;
        var wrapper_offset: usize = undefined;
        var instance_offset: usize = undefined;

        // Calculate the bytes we have to allocate to store all thread information, including:
        // - The actual stack for the thread
        // - The TLS segment
        // - `Instance` - containing information about how to call the user's function.
        const map_bytes = blk: {
            // start with atleast a single page, which is used as a guard to prevent
            // other threads clobbering our new thread.
            // Unfortunately, WebAssembly has no notion of read-only segments, so this
            // is only a best effort.
            var bytes: usize = std.wasm.page_size;

            bytes = std.mem.alignForward(usize, bytes, 16); // align stack to 16 bytes
            stack_offset = bytes;
            bytes += @max(std.wasm.page_size, config.stack_size);

            bytes = std.mem.alignForward(usize, bytes, __tls_align());
            tls_offset = bytes;
            bytes += __tls_size();

            bytes = std.mem.alignForward(usize, bytes, @alignOf(Wrapper));
            wrapper_offset = bytes;
            bytes += @sizeOf(Wrapper);

            bytes = std.mem.alignForward(usize, bytes, @alignOf(Instance));
            instance_offset = bytes;
            bytes += @sizeOf(Instance);

            bytes = std.mem.alignForward(usize, bytes, std.wasm.page_size);
            break :blk bytes;
        };

        // Allocate the amount of memory required for all meta data.
        const allocated_memory = try config.allocator.?.alloc(u8, map_bytes);

        const wrapper: *Wrapper = @ptrCast(@alignCast(&allocated_memory[wrapper_offset]));
        wrapper.* = .{ .args = args };

        const instance: *Instance = @ptrCast(@alignCast(&allocated_memory[instance_offset]));
        instance.* = .{
            .thread = .{ .memory = allocated_memory, .allocator = config.allocator.? },
            .tls_offset = tls_offset,
            .stack_offset = stack_offset,
            .raw_ptr = @intFromPtr(wrapper),
            .call_back = &Wrapper.entry,
            .original_stack_pointer = __get_stack_pointer(),
        };

        const tid = spawnWasiThread(instance);
        // The specification says any value lower than 0 indicates an error.
        // The values of such error are unspecified. WASI-Libc treats it as EAGAIN.
        if (tid < 0) {
            return error.SystemResources;
        }
        instance.thread.tid.store(tid, .seq_cst);

        return .{ .thread = &instance.thread };
    }

    comptime {
        if (!builtin.single_threaded) {
            @export(&wasi_thread_start, .{ .name = "wasi_thread_start" });
        }
    }

    /// Called by the host environment after thread creation.
    fn wasi_thread_start(tid: i32, arg: *Instance) callconv(.c) void {
        comptime assert(!builtin.single_threaded);
        __set_stack_pointer(arg.thread.memory.ptr + arg.stack_offset);
        __wasm_init_tls(arg.thread.memory.ptr + arg.tls_offset);
        @atomicStore(u32, &WasiThreadImpl.tls_thread_id, @intCast(tid), .seq_cst);

        // Finished bootstrapping, call user's procedure.
        arg.call_back(arg.raw_ptr);

        switch (arg.thread.state.swap(.completed, .seq_cst)) {
            .running => {
                // reset the Thread ID
                asm volatile (
                    \\ local.get %[ptr]
                    \\ i32.const 0
                    \\ i32.atomic.store 0
                    :
                    : [ptr] "r" (&arg.thread.tid.raw),
                );

                // Wake the main thread listening to this thread
                asm volatile (
                    \\ local.get %[ptr]
                    \\ i32.const 1 # waiters
                    \\ memory.atomic.notify 0
                    \\ drop # no need to know the waiters
                    :
                    : [ptr] "r" (&arg.thread.tid.raw),
                );
            },
            .completed => unreachable,
            .detached => {
                // restore the original stack pointer so we can free the memory
                // without having to worry about freeing the stack
                __set_stack_pointer(arg.original_stack_pointer);
                // Ensure a copy so we don't free the allocator reference itself
                var allocator = arg.thread.allocator;
                allocator.free(arg.thread.memory);
            },
        }
    }

    /// Asks the host to create a new thread for us.
    /// Newly created thread will call `wasi_tread_start` with the thread ID as well
    /// as the input `arg` that was provided to `spawnWasiThread`
    const spawnWasiThread = @"thread-spawn";
    extern "wasi" fn @"thread-spawn"(arg: *Instance) i32;

    /// Initializes the TLS data segment starting at `memory`.
    /// This is a synthetic function, generated by the linker.
    extern fn __wasm_init_tls(memory: [*]u8) void;

    /// Returns a pointer to the base of the TLS data segment for the current thread
    inline fn __tls_base() [*]u8 {
        return asm (
            \\ .globaltype __tls_base, i32
            \\ global.get __tls_base
            \\ local.set %[ret]
            : [ret] "=r" (-> [*]u8),
        );
    }

    /// Returns the size of the TLS segment
    inline fn __tls_size() u32 {
        return asm volatile (
            \\ .globaltype __tls_size, i32, immutable
            \\ global.get __tls_size
            \\ local.set %[ret]
            : [ret] "=r" (-> u32),
        );
    }

    /// Returns the alignment of the TLS segment
    inline fn __tls_align() u32 {
        return asm (
            \\ .globaltype __tls_align, i32, immutable
            \\ global.get __tls_align
            \\ local.set %[ret]
            : [ret] "=r" (-> u32),
        );
    }

    /// Allows for setting the stack pointer in the WebAssembly module.
    inline fn __set_stack_pointer(addr: [*]u8) void {
        asm volatile (
            \\ local.get %[ptr]
            \\ global.set __stack_pointer
            :
            : [ptr] "r" (addr),
        );
    }

    /// Returns the current value of the stack pointer
    inline fn __get_stack_pointer() [*]u8 {
        return asm (
            \\ global.get __stack_pointer
            \\ local.set %[stack_ptr]
            : [stack_ptr] "=r" (-> [*]u8),
        );
    }
};

const LinuxThreadImpl = struct {
    const linux = std.os.linux;

    pub const ThreadHandle = i32;

    threadlocal var tls_thread_id: ?Id = null;

    fn getCurrentId() Id {
        return tls_thread_id orelse {
            const tid: u32 = @bitCast(linux.gettid());
            tls_thread_id = tid;
            return tid;
        };
    }

    fn getCpuCount() !usize {
        const cpu_set = try posix.sched_getaffinity(0);
        return posix.CPU_COUNT(cpu_set);
    }

    thread: *ThreadCompletion,

    const ThreadCompletion = struct {
        completion: Completion = Completion.init(.running),
        child_tid: std.atomic.Value(i32) = std.atomic.Value(i32).init(1),
        parent_tid: i32 = undefined,
        mapped: []align(std.heap.page_size_min) u8,

        /// Calls `munmap(mapped.ptr, mapped.len)` then `exit(1)` without touching the stack (which lives in `mapped.ptr`).
        /// Ported over from musl libc's pthread detached implementation:
        /// https://github.com/ifduyue/musl/search?q=__unmapself
        fn freeAndExit(self: *ThreadCompletion) noreturn {
            switch (target.cpu.arch) {
                .x86 => asm volatile (
                    \\  movl $91, %%eax # SYS_munmap
                    \\  movl %[ptr], %%ebx
                    \\  movl %[len], %%ecx
                    \\  int $128
                    \\  movl $1, %%eax # SYS_exit
                    \\  movl $0, %%ebx
                    \\  int $128
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .x86_64 => asm volatile (switch (target.abi) {
                        .gnux32, .muslx32 =>
                        \\  movl $0x4000000b, %%eax # SYS_munmap
                        \\  syscall
                        \\  movl $0x4000003c, %%eax # SYS_exit
                        \\  xor %%rdi, %%rdi
                        \\  syscall
                        ,
                        else =>
                        \\  movl $11, %%eax # SYS_munmap
                        \\  syscall
                        \\  movl $60, %%eax # SYS_exit
                        \\  xor %%rdi, %%rdi
                        \\  syscall
                        ,
                    }
                    :
                    : [ptr] "{rdi}" (@intFromPtr(self.mapped.ptr)),
                      [len] "{rsi}" (self.mapped.len),
                ),
                .arm, .armeb, .thumb, .thumbeb => asm volatile (
                    \\  mov r7, #91 // SYS_munmap
                    \\  mov r0, %[ptr]
                    \\  mov r1, %[len]
                    \\  svc 0
                    \\  mov r7, #1 // SYS_exit
                    \\  mov r0, #0
                    \\  svc 0
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .aarch64, .aarch64_be => asm volatile (
                    \\  mov x8, #215 // SYS_munmap
                    \\  mov x0, %[ptr]
                    \\  mov x1, %[len]
                    \\  svc 0
                    \\  mov x8, #93 // SYS_exit
                    \\  mov x0, #0
                    \\  svc 0
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .alpha => asm volatile (
                    \\ ldi $0, 73 # SYS_munmap
                    \\ mov %[ptr], $16
                    \\ mov %[len], $17
                    \\ callsys
                    \\ ldi $0, 1 # SYS_exit
                    \\ ldi $16, 0
                    \\ callsys
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .hexagon => asm volatile (
                    \\  r6 = #215 // SYS_munmap
                    \\  r0 = %[ptr]
                    \\  r1 = %[len]
                    \\  trap0(#1)
                    \\  r6 = #93 // SYS_exit
                    \\  r0 = #0
                    \\  trap0(#1)
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .hppa => asm volatile (
                    \\ ldi 91, %%r20 /* SYS_munmap */
                    \\ copy %[ptr], %%r26
                    \\ copy %[len], %%r25
                    \\ ble 0x100(%%sr2, %%r0)
                    \\ ldi 1, %%r20 /* SYS_exit */
                    \\ ldi 0, %%r26
                    \\ ble 0x100(%%sr2, %%r0)
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .m68k => asm volatile (
                    \\ move.l #91, %%d0 // SYS_munmap
                    \\ move.l %[ptr], %%d1
                    \\ move.l %[len], %%d2
                    \\ trap #0
                    \\ move.l #1, %%d0 // SYS_exit
                    \\ move.l #0, %%d1
                    \\ trap #0
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .microblaze, .microblazeel => asm volatile (
                    \\ ori r12, r0, 91 # SYS_munmap
                    \\ ori r5, %[ptr], 0
                    \\ ori r6, %[len], 0
                    \\ brki r14, 0x8
                    \\ ori r12, r0, 1 # SYS_exit
                    \\ or r5, r0, r0
                    \\ brki r14, 0x8
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                // We set `sp` to the address of the current function as a workaround for a Linux
                // kernel bug that caused syscalls to return EFAULT if the stack pointer is invalid.
                // The bug was introduced in 46e12c07b3b9603c60fc1d421ff18618241cb081 and fixed in
                // 7928eb0370d1133d0d8cd2f5ddfca19c309079d5.
                .mips, .mipsel => asm volatile (
                    \\ move $sp, $t9
                    \\ li $v0, 4091 # SYS_munmap
                    \\ move $a0, %[ptr]
                    \\ move $a1, %[len]
                    \\ syscall
                    \\ li $v0, 4001 # SYS_exit
                    \\ li $a0, 0
                    \\ syscall
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .mips64, .mips64el => asm volatile (switch (target.abi) {
                        .gnuabin32, .muslabin32 =>
                        \\ li $v0, 6011 # SYS_munmap
                        \\ move $a0, %[ptr]
                        \\ move $a1, %[len]
                        \\ syscall
                        \\ li $v0, 6058 # SYS_exit
                        \\ li $a0, 0
                        \\ syscall
                        ,
                        else =>
                        \\ li $v0, 5011 # SYS_munmap
                        \\ move $a0, %[ptr]
                        \\ move $a1, %[len]
                        \\ syscall
                        \\ li $v0, 5058 # SYS_exit
                        \\ li $a0, 0
                        \\ syscall
                        ,
                    }
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .or1k => asm volatile (
                    \\ l.ori r11, r0, 215 # SYS_munmap
                    \\ l.ori r3, %[ptr]
                    \\ l.ori r4, %[len]
                    \\ l.sys 1
                    \\ l.ori r11, r0, 93 # SYS_exit
                    \\ l.ori r3, r0, r0
                    \\ l.sys 1
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => asm volatile (
                    \\  li 0, 91 # SYS_munmap
                    \\  mr 3, %[ptr]
                    \\  mr 4, %[len]
                    \\  sc
                    \\  li 0, 1 # SYS_exit
                    \\  li 3, 0
                    \\  sc
                    \\  blr
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .riscv32, .riscv64 => asm volatile (
                    \\  li a7, 215 # SYS_munmap
                    \\  mv a0, %[ptr]
                    \\  mv a1, %[len]
                    \\  ecall
                    \\  li a7, 93 # SYS_exit
                    \\  mv a0, zero
                    \\  ecall
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .s390x => asm volatile (
                    \\  lgr %%r2, %[ptr]
                    \\  lgr %%r3, %[len]
                    \\  svc 91 # SYS_munmap
                    \\  lghi %%r2, 0
                    \\  svc 1 # SYS_exit
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .sh, .sheb => asm volatile (
                    \\ mov #91, r3 ! SYS_munmap
                    \\ mov %[ptr], r4
                    \\ mov %[len], r5
                    \\ trapa #31
                    \\ or r0, r0
                    \\ or r0, r0
                    \\ or r0, r0
                    \\ or r0, r0
                    \\ or r0, r0
                    \\ mov #1, r3 ! SYS_exit
                    \\ mov #0, r4
                    \\ trapa #31
                    \\ or r0, r0
                    \\ or r0, r0
                    \\ or r0, r0
                    \\ or r0, r0
                    \\ or r0, r0
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .sparc => asm volatile (
                    \\ # See sparc64 comments below.
                    \\ 1:
                    \\  cmp %%fp, 0
                    \\  beq 2f
                    \\  nop
                    \\  ba 1b
                    \\  restore
                    \\ 2:
                    \\  mov 73, %%g1 // SYS_munmap
                    \\  mov %[ptr], %%o0
                    \\  mov %[len], %%o1
                    \\  t 0x3 # ST_FLUSH_WINDOWS
                    \\  t 0x10
                    \\  mov 1, %%g1 // SYS_exit
                    \\  mov 0, %%o0
                    \\  t 0x10
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .sparc64 => asm volatile (
                    \\ # SPARCs really don't like it when active stack frames
                    \\ # is unmapped (it will result in a segfault), so we
                    \\ # force-deactivate it by running `restore` until
                    \\ # all frames are cleared.
                    \\ 1:
                    \\  cmp %%fp, 0
                    \\  beq 2f
                    \\  nop
                    \\  ba 1b
                    \\  restore
                    \\ 2:
                    \\  mov 73, %%g1 // SYS_munmap
                    \\  mov %[ptr], %%o0
                    \\  mov %[len], %%o1
                    \\  # Flush register window contents to prevent background
                    \\  # memory access before unmapping the stack.
                    \\  flushw
                    \\  t 0x6d
                    \\  mov 1, %%g1 // SYS_exit
                    \\  mov 0, %%o0
                    \\  t 0x6d
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                .loongarch32, .loongarch64 => asm volatile (
                    \\ or      $a0, $zero, %[ptr]
                    \\ or      $a1, $zero, %[len]
                    \\ ori     $a7, $zero, 215     # SYS_munmap
                    \\ syscall 0                   # call munmap
                    \\ ori     $a0, $zero, 0
                    \\ ori     $a7, $zero, 93      # SYS_exit
                    \\ syscall 0                   # call exit
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : .{ .memory = true }),
                else => |cpu_arch| @compileError("Unsupported linux arch: " ++ @tagName(cpu_arch)),
            }
            unreachable;
        }
    };

    fn spawn(config: SpawnConfig, comptime f: anytype, args: anytype) !Impl {
        const page_size = std.heap.pageSize();
        const Args = @TypeOf(args);
        const Instance = struct {
            fn_args: Args,
            thread: ThreadCompletion,

            fn entryFn(raw_arg: usize) callconv(.c) u8 {
                const self = @as(*@This(), @ptrFromInt(raw_arg));
                defer switch (self.thread.completion.swap(.completed, .seq_cst)) {
                    .running => {},
                    .completed => unreachable,
                    .detached => self.thread.freeAndExit(),
                };
                return callFn(f, self.fn_args);
            }
        };

        var guard_offset: usize = undefined;
        var stack_offset: usize = undefined;
        var tls_offset: usize = undefined;
        var instance_offset: usize = undefined;

        const map_bytes = blk: {
            var bytes: usize = page_size;
            guard_offset = bytes;

            bytes += @max(page_size, config.stack_size);
            bytes = std.mem.alignForward(usize, bytes, page_size);
            stack_offset = bytes;

            bytes = std.mem.alignForward(usize, bytes, linux.tls.area_desc.alignment);
            tls_offset = bytes;
            bytes += linux.tls.area_desc.size;

            bytes = std.mem.alignForward(usize, bytes, @alignOf(Instance));
            instance_offset = bytes;
            bytes += @sizeOf(Instance);

            bytes = std.mem.alignForward(usize, bytes, page_size);
            break :blk bytes;
        };

        // map all memory needed without read/write permissions
        // to avoid committing the whole region right away
        // anonymous mapping ensures file descriptor limits are not exceeded
        const mapped = posix.mmap(
            null,
            map_bytes,
            posix.PROT.NONE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        ) catch |err| switch (err) {
            error.MemoryMappingNotSupported => unreachable,
            error.AccessDenied => unreachable,
            error.PermissionDenied => unreachable,
            error.ProcessFdQuotaExceeded => unreachable,
            error.SystemFdQuotaExceeded => unreachable,
            error.MappingAlreadyExists => unreachable,
            else => |e| return e,
        };
        assert(mapped.len >= map_bytes);
        errdefer posix.munmap(mapped);

        // map everything but the guard page as read/write
        posix.mprotect(
            @alignCast(mapped[guard_offset..]),
            posix.PROT.READ | posix.PROT.WRITE,
        ) catch |err| switch (err) {
            error.AccessDenied => unreachable,
            else => |e| return e,
        };

        // Prepare the TLS segment and prepare a user_desc struct when needed on x86
        var tls_ptr = linux.tls.prepareArea(mapped[tls_offset..]);
        var user_desc: if (target.cpu.arch == .x86) linux.user_desc else void = undefined;
        if (target.cpu.arch == .x86) {
            defer tls_ptr = @intFromPtr(&user_desc);
            user_desc = .{
                .entry_number = linux.tls.area_desc.gdt_entry_number,
                .base_addr = tls_ptr,
                .limit = 0xfffff,
                .flags = .{
                    .seg_32bit = 1,
                    .contents = 0, // Data
                    .read_exec_only = 0,
                    .limit_in_pages = 1,
                    .seg_not_present = 0,
                    .useable = 1,
                },
            };
        }

        const instance: *Instance = @ptrCast(@alignCast(&mapped[instance_offset]));
        instance.* = .{
            .fn_args = args,
            .thread = .{ .mapped = mapped },
        };

        const flags: u32 = linux.CLONE.THREAD | linux.CLONE.DETACHED |
            linux.CLONE.VM | linux.CLONE.FS | linux.CLONE.FILES |
            linux.CLONE.PARENT_SETTID | linux.CLONE.CHILD_CLEARTID |
            linux.CLONE.SIGHAND | linux.CLONE.SYSVSEM | linux.CLONE.SETTLS;

        switch (linux.E.init(linux.clone(
            Instance.entryFn,
            @intFromPtr(&mapped[stack_offset]),
            flags,
            @intFromPtr(instance),
            &instance.thread.parent_tid,
            tls_ptr,
            &instance.thread.child_tid.raw,
        ))) {
            .SUCCESS => return Impl{ .thread = &instance.thread },
            .AGAIN => return error.ThreadQuotaExceeded,
            .INVAL => unreachable,
            .NOMEM => return error.SystemResources,
            .NOSPC => unreachable,
            .PERM => unreachable,
            .USERS => unreachable,
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    fn getHandle(self: Impl) ThreadHandle {
        return self.thread.parent_tid;
    }

    fn detach(self: Impl) void {
        switch (self.thread.completion.swap(.detached, .seq_cst)) {
            .running => {},
            .completed => self.join(),
            .detached => unreachable,
        }
    }

    fn join(self: Impl) void {
        defer posix.munmap(self.thread.mapped);

        while (true) {
            const tid = self.thread.child_tid.load(.seq_cst);
            if (tid == 0) break;

            switch (linux.E.init(linux.futex_4arg(
                &self.thread.child_tid.raw,
                .{ .cmd = .WAIT, .private = false },
                @bitCast(tid),
                null,
            ))) {
                .SUCCESS => continue,
                .INTR => continue,
                .AGAIN => continue,
                else => unreachable,
            }
        }
    }
};

fn testThreadName(thread: *Thread) !void {
    const testCases = &[_][]const u8{
        "mythread",
        "b" ** max_name_len,
    };

    inline for (testCases) |tc| {
        try thread.setName(tc);

        var name_buffer: [max_name_len:0]u8 = undefined;

        const name = try thread.getName(&name_buffer);
        if (name) |value| {
            try std.testing.expectEqual(tc.len, value.len);
            try std.testing.expectEqualStrings(tc, value);
        }
    }
}

test "setName, getName" {
    if (builtin.single_threaded) return error.SkipZigTest;

    const Context = struct {
        start_wait_event: ResetEvent = .unset,
        test_done_event: ResetEvent = .unset,
        thread_done_event: ResetEvent = .unset,

        done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
        thread: Thread = undefined,

        pub fn run(ctx: *@This()) !void {
            // Wait for the main thread to have set the thread field in the context.
            ctx.start_wait_event.wait();

            switch (native_os) {
                .windows => testThreadName(&ctx.thread) catch |err| switch (err) {
                    error.Unsupported => return error.SkipZigTest,
                    else => return err,
                },
                else => try testThreadName(&ctx.thread),
            }

            // Signal our test is done
            ctx.test_done_event.set();

            // wait for the thread to property exit
            ctx.thread_done_event.wait();
        }
    };

    var context = Context{};
    var thread = try spawn(.{}, Context.run, .{&context});

    context.thread = thread;
    context.start_wait_event.set();
    context.test_done_event.wait();

    switch (native_os) {
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => {
            const res = thread.setName("foobar");
            try std.testing.expectError(error.Unsupported, res);
        },
        .windows => testThreadName(&thread) catch |err| switch (err) {
            error.Unsupported => return error.SkipZigTest,
            else => return err,
        },
        else => try testThreadName(&thread),
    }

    context.thread_done_event.set();
    thread.join();
}

test {
    _ = Futex;
    _ = ResetEvent;
    _ = Mutex;
    _ = Semaphore;
    _ = Condition;
    _ = RwLock;
    _ = Pool;
}

fn testIncrementNotify(value: *usize, event: *ResetEvent) void {
    value.* += 1;
    event.set();
}

test join {
    if (builtin.single_threaded) return error.SkipZigTest;

    var value: usize = 0;
    var event: ResetEvent = .unset;

    const thread = try Thread.spawn(.{}, testIncrementNotify, .{ &value, &event });
    thread.join();

    try std.testing.expectEqual(value, 1);
}

test detach {
    if (builtin.single_threaded) return error.SkipZigTest;

    var value: usize = 0;
    var event: ResetEvent = .unset;

    const thread = try Thread.spawn(.{}, testIncrementNotify, .{ &value, &event });
    thread.detach();

    event.wait();
    try std.testing.expectEqual(value, 1);
}

test "Thread.getCpuCount" {
    if (native_os == .wasi) return error.SkipZigTest;

    const cpu_count = try Thread.getCpuCount();
    try std.testing.expect(cpu_count >= 1);
}

fn testThreadIdFn(thread_id: *Thread.Id) void {
    thread_id.* = Thread.getCurrentId();
}

test "Thread.getCurrentId" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var thread_current_id: Thread.Id = undefined;
    const thread = try Thread.spawn(.{}, testThreadIdFn, .{&thread_current_id});
    thread.join();
    try std.testing.expect(Thread.getCurrentId() != thread_current_id);
}

test "thread local storage" {
    if (builtin.single_threaded) return error.SkipZigTest;

    const thread1 = try Thread.spawn(.{}, testTls, .{});
    const thread2 = try Thread.spawn(.{}, testTls, .{});
    try testTls();
    thread1.join();
    thread2.join();
}

threadlocal var x: i32 = 1234;
fn testTls() !void {
    if (x != 1234) return error.TlsBadStartValue;
    x += 1;
    if (x != 1235) return error.TlsBadEndValue;
}

test "ResetEvent smoke test" {
    var event: ResetEvent = .unset;
    try testing.expectEqual(false, event.isSet());

    // make sure the event gets set
    event.set();
    try testing.expectEqual(true, event.isSet());

    // make sure the event gets unset again
    event.reset();
    try testing.expectEqual(false, event.isSet());

    // waits should timeout as there's no other thread to set the event
    try testing.expectError(error.Timeout, event.timedWait(0));
    try testing.expectError(error.Timeout, event.timedWait(std.time.ns_per_ms));

    // set the event again and make sure waits complete
    event.set();
    event.wait();
    try event.timedWait(std.time.ns_per_ms);
    try testing.expectEqual(true, event.isSet());
}

test "ResetEvent signaling" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const Context = struct {
        in: ResetEvent = .unset,
        out: ResetEvent = .unset,
        value: usize = 0,

        fn input(self: *@This()) !void {
            // wait for the value to become 1
            self.in.wait();
            self.in.reset();
            try testing.expectEqual(self.value, 1);

            // bump the value and wake up output()
            self.value = 2;
            self.out.set();

            // wait for output to receive 2, bump the value and wake us up with 3
            self.in.wait();
            self.in.reset();
            try testing.expectEqual(self.value, 3);

            // bump the value and wake up output() for it to see 4
            self.value = 4;
            self.out.set();
        }

        fn output(self: *@This()) !void {
            // start with 0 and bump the value for input to see 1
            try testing.expectEqual(self.value, 0);
            self.value = 1;
            self.in.set();

            // wait for input to receive 1, bump the value to 2 and wake us up
            self.out.wait();
            self.out.reset();
            try testing.expectEqual(self.value, 2);

            // bump the value to 3 for input to see (rhymes)
            self.value = 3;
            self.in.set();

            // wait for input to bump the value to 4 and receive no more (rhymes)
            self.out.wait();
            self.out.reset();
            try testing.expectEqual(self.value, 4);
        }
    };

    var ctx = Context{};

    const thread = try std.Thread.spawn(.{}, Context.output, .{&ctx});
    defer thread.join();

    try ctx.input();
}

test "ResetEvent broadcast" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const num_threads = 10;
    const Barrier = struct {
        event: ResetEvent = .unset,
        counter: std.atomic.Value(usize) = std.atomic.Value(usize).init(num_threads),

        fn wait(self: *@This()) void {
            if (self.counter.fetchSub(1, .acq_rel) == 1) {
                self.event.set();
            }
        }
    };

    const Context = struct {
        start_barrier: Barrier = .{},
        finish_barrier: Barrier = .{},

        fn run(self: *@This()) void {
            self.start_barrier.wait();
            self.finish_barrier.wait();
        }
    };

    var ctx = Context{};
    var threads: [num_threads - 1]std.Thread = undefined;

    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, Context.run, .{&ctx});
    defer for (threads) |t| t.join();

    ctx.run();
}
