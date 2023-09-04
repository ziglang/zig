//! This struct represents a kernel thread, and acts as a namespace for concurrency
//! primitives that operate on kernel threads. For concurrency primitives that support
//! both evented I/O and async I/O, see the respective names in the top level std namespace.

const std = @import("std.zig");
const builtin = @import("builtin");
const math = std.math;
const os = std.os;
const assert = std.debug.assert;
const target = builtin.target;
const Atomic = std.atomic.Atomic;

pub const Futex = @import("Thread/Futex.zig");
pub const ResetEvent = @import("Thread/ResetEvent.zig");
pub const Mutex = @import("Thread/Mutex.zig");
pub const Semaphore = @import("Thread/Semaphore.zig");
pub const Condition = @import("Thread/Condition.zig");
pub const RwLock = @import("Thread/RwLock.zig");
pub const Pool = @import("Thread/Pool.zig");
pub const WaitGroup = @import("Thread/WaitGroup.zig");

pub const use_pthreads = target.os.tag != .windows and target.os.tag != .wasi and builtin.link_libc;

const Thread = @This();
const Impl = if (target.os.tag == .windows)
    WindowsThreadImpl
else if (use_pthreads)
    PosixThreadImpl
else if (target.os.tag == .linux)
    LinuxThreadImpl
else if (target.os.tag == .wasi)
    WasiThreadImpl
else
    UnsupportedImpl;

impl: Impl,

pub const max_name_len = switch (target.os.tag) {
    .linux => 15,
    .windows => 31,
    .macos, .ios, .watchos, .tvos => 63,
    .netbsd => 31,
    .freebsd => 15,
    .openbsd => 23,
    .dragonfly => 1023,
    .solaris => 31,
    else => 0,
};

pub const SetNameError = error{
    NameTooLong,
    Unsupported,
    Unexpected,
} || os.PrctlError || os.WriteError || std.fs.File.OpenError || std.fmt.BufPrintError;

pub fn setName(self: Thread, name: []const u8) SetNameError!void {
    if (name.len > max_name_len) return error.NameTooLong;

    const name_with_terminator = blk: {
        var name_buf: [max_name_len:0]u8 = undefined;
        @memcpy(name_buf[0..name.len], name);
        name_buf[name.len] = 0;
        break :blk name_buf[0..name.len :0];
    };

    switch (target.os.tag) {
        .linux => if (use_pthreads) {
            if (self.getHandle() == std.c.pthread_self()) {
                // Set the name of the calling thread (no thread id required).
                const err = try os.prctl(.SET_NAME, .{@intFromPtr(name_with_terminator.ptr)});
                switch (@as(os.E, @enumFromInt(err))) {
                    .SUCCESS => return,
                    else => |e| return os.unexpectedErrno(e),
                }
            } else {
                const err = std.c.pthread_setname_np(self.getHandle(), name_with_terminator.ptr);
                switch (err) {
                    .SUCCESS => return,
                    .RANGE => unreachable,
                    else => |e| return os.unexpectedErrno(e),
                }
            }
        } else {
            var buf: [32]u8 = undefined;
            const path = try std.fmt.bufPrint(&buf, "/proc/self/task/{d}/comm", .{self.getHandle()});

            const file = try std.fs.cwd().openFile(path, .{ .mode = .write_only });
            defer file.close();

            try file.writer().writeAll(name);
            return;
        },
        .windows => {
            var buf: [max_name_len]u16 = undefined;
            const len = try std.unicode.utf8ToUtf16Le(&buf, name);
            const byte_len = math.cast(c_ushort, len * 2) orelse return error.NameTooLong;

            // Note: NT allocates its own copy, no use-after-free here.
            const unicode_string = os.windows.UNICODE_STRING{
                .Length = byte_len,
                .MaximumLength = byte_len,
                .Buffer = &buf,
            };

            switch (os.windows.ntdll.NtSetInformationThread(
                self.getHandle(),
                .ThreadNameInformation,
                &unicode_string,
                @sizeOf(os.windows.UNICODE_STRING),
            )) {
                .SUCCESS => return,
                .NOT_IMPLEMENTED => return error.Unsupported,
                else => |err| return os.windows.unexpectedStatus(err),
            }
        },
        .macos, .ios, .watchos, .tvos => if (use_pthreads) {
            // There doesn't seem to be a way to set the name for an arbitrary thread, only the current one.
            if (self.getHandle() != std.c.pthread_self()) return error.Unsupported;

            const err = std.c.pthread_setname_np(name_with_terminator.ptr);
            switch (err) {
                .SUCCESS => return,
                else => |e| return os.unexpectedErrno(e),
            }
        },
        .netbsd, .solaris => if (use_pthreads) {
            const err = std.c.pthread_setname_np(self.getHandle(), name_with_terminator.ptr, null);
            switch (err) {
                .SUCCESS => return,
                .INVAL => unreachable,
                .SRCH => unreachable,
                .NOMEM => unreachable,
                else => |e| return os.unexpectedErrno(e),
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
            switch (err) {
                .SUCCESS => return,
                .INVAL => unreachable,
                .FAULT => unreachable,
                .NAMETOOLONG => unreachable, // already checked
                .SRCH => unreachable,
                else => |e| return os.unexpectedErrno(e),
            }
        },
        else => {},
    }
    return error.Unsupported;
}

pub const GetNameError = error{
    // For Windows, the name is converted from UTF16 to UTF8
    CodepointTooLarge,
    Utf8CannotEncodeSurrogateHalf,
    DanglingSurrogateHalf,
    ExpectedSecondSurrogateHalf,
    UnexpectedSecondSurrogateHalf,

    Unsupported,
    Unexpected,
} || os.PrctlError || os.ReadError || std.fs.File.OpenError || std.fmt.BufPrintError;

pub fn getName(self: Thread, buffer_ptr: *[max_name_len:0]u8) GetNameError!?[]const u8 {
    buffer_ptr[max_name_len] = 0;
    var buffer: [:0]u8 = buffer_ptr;

    switch (target.os.tag) {
        .linux => if (use_pthreads) {
            if (self.getHandle() == std.c.pthread_self()) {
                // Get the name of the calling thread (no thread id required).
                const err = try os.prctl(.GET_NAME, .{@intFromPtr(buffer.ptr)});
                switch (@as(os.E, @enumFromInt(err))) {
                    .SUCCESS => return std.mem.sliceTo(buffer, 0),
                    else => |e| return os.unexpectedErrno(e),
                }
            } else {
                const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
                switch (err) {
                    .SUCCESS => return std.mem.sliceTo(buffer, 0),
                    .RANGE => unreachable,
                    else => |e| return os.unexpectedErrno(e),
                }
            }
        } else {
            var buf: [32]u8 = undefined;
            const path = try std.fmt.bufPrint(&buf, "/proc/self/task/{d}/comm", .{self.getHandle()});

            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            const data_len = try file.reader().readAll(buffer_ptr[0 .. max_name_len + 1]);

            return if (data_len >= 1) buffer[0 .. data_len - 1] else null;
        },
        .windows => {
            const buf_capacity = @sizeOf(os.windows.UNICODE_STRING) + (@sizeOf(u16) * max_name_len);
            var buf: [buf_capacity]u8 align(@alignOf(os.windows.UNICODE_STRING)) = undefined;

            switch (os.windows.ntdll.NtQueryInformationThread(
                self.getHandle(),
                .ThreadNameInformation,
                &buf,
                buf_capacity,
                null,
            )) {
                .SUCCESS => {
                    const string = @as(*const os.windows.UNICODE_STRING, @ptrCast(&buf));
                    const len = try std.unicode.utf16leToUtf8(buffer, string.Buffer[0 .. string.Length / 2]);
                    return if (len > 0) buffer[0..len] else null;
                },
                .NOT_IMPLEMENTED => return error.Unsupported,
                else => |err| return os.windows.unexpectedStatus(err),
            }
        },
        .macos, .ios, .watchos, .tvos => if (use_pthreads) {
            const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
            switch (err) {
                .SUCCESS => return std.mem.sliceTo(buffer, 0),
                .SRCH => unreachable,
                else => |e| return os.unexpectedErrno(e),
            }
        },
        .netbsd, .solaris => if (use_pthreads) {
            const err = std.c.pthread_getname_np(self.getHandle(), buffer.ptr, max_name_len + 1);
            switch (err) {
                .SUCCESS => return std.mem.sliceTo(buffer, 0),
                .INVAL => unreachable,
                .SRCH => unreachable,
                else => |e| return os.unexpectedErrno(e),
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
            switch (err) {
                .SUCCESS => return std.mem.sliceTo(buffer, 0),
                .INVAL => unreachable,
                .FAULT => unreachable,
                .SRCH => unreachable,
                else => |e| return os.unexpectedErrno(e),
            }
        },
        else => {},
    }
    return error.Unsupported;
}

/// Represents an ID per thread guaranteed to be unique only within a process.
pub const Id = switch (target.os.tag) {
    .linux,
    .dragonfly,
    .netbsd,
    .freebsd,
    .openbsd,
    .haiku,
    .wasi,
    => u32,
    .macos, .ios, .watchos, .tvos => u64,
    .windows => os.windows.DWORD,
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
    Unexpected,
};

/// Returns the platforms view on the number of logical CPU cores available.
pub fn getCpuCount() CpuCountError!usize {
    return Impl.getCpuCount();
}

/// Configuration options for hints on how to spawn threads.
pub const SpawnConfig = struct {
    // TODO compile-time call graph analysis to determine stack upper bound
    // https://github.com/ziglang/zig/issues/157

    /// Size in bytes of the Thread's stack
    stack_size: usize = 16 * 1024 * 1024,
    /// The allocator to be used to allocate memory for the to-be-spawned thread
    allocator: ?std.mem.Allocator = null,
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
/// `config` can be used as hints to the platform for now to spawn and execute the `function`.
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
    if (builtin.os.tag == .windows) {
        // The return value has to do with how many other threads there are; it is not
        // an error condition on Windows.
        _ = os.windows.kernel32.SwitchToThread();
        return;
    }
    switch (os.errno(os.system.sched_yield())) {
        .SUCCESS => return,
        .NOSYS => return error.SystemCannotYield,
        else => return error.SystemCannotYield,
    }
}

/// State to synchronize detachment of spawner thread to spawned thread
const Completion = Atomic(enum(u8) {
    running,
    detached,
    completed,
});

/// Used by the Thread implementations to call the spawned function with the arguments.
fn callFn(comptime f: anytype, args: anytype) switch (Impl) {
    WindowsThreadImpl => std.os.windows.DWORD,
    LinuxThreadImpl => u8,
    PosixThreadImpl => ?*anyopaque,
    else => unreachable,
} {
    const default_value = if (Impl == PosixThreadImpl) null else 0;
    const bad_fn_ret = "expected return type of startFn to be 'u8', 'noreturn', 'void', or '!void'";

    switch (@typeInfo(@typeInfo(@TypeOf(f)).Fn.return_type.?)) {
        .NoReturn => {
            @call(.auto, f, args);
        },
        .Void => {
            @call(.auto, f, args);
            return default_value;
        },
        .Int => |info| {
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
        .ErrorUnion => |info| {
            if (info.payload != void) {
                @compileError(bad_fn_ret);
            }

            @call(.auto, f, args) catch |err| {
                std.debug.print("error: {s}\n", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
            };

            return default_value;
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
        @compileError("Unsupported operating system " ++ @tagName(target.os.tag));
    }
};

const WindowsThreadImpl = struct {
    const windows = os.windows;

    pub const ThreadHandle = windows.HANDLE;

    fn getCurrentId() windows.DWORD {
        return windows.kernel32.GetCurrentThreadId();
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

            fn entryFn(raw_ptr: windows.PVOID) callconv(.C) windows.DWORD {
                const self: *@This() = @ptrCast(@alignCast(raw_ptr));
                defer switch (self.thread.completion.swap(.completed, .SeqCst)) {
                    .running => {},
                    .completed => unreachable,
                    .detached => self.thread.free(),
                };
                return callFn(f, self.fn_args);
            }
        };

        const heap_handle = windows.kernel32.GetProcessHeap() orelse return error.OutOfMemory;
        const alloc_bytes = @alignOf(Instance) + @sizeOf(Instance);
        const alloc_ptr = windows.kernel32.HeapAlloc(heap_handle, 0, alloc_bytes) orelse return error.OutOfMemory;
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
            @as(*anyopaque, @ptrCast(instance)),
            0,
            null,
        ) orelse {
            const errno = windows.kernel32.GetLastError();
            return windows.unexpectedError(errno);
        };

        return Impl{ .thread = &instance.thread };
    }

    fn getHandle(self: Impl) ThreadHandle {
        return self.thread.thread_handle;
    }

    fn detach(self: Impl) void {
        windows.CloseHandle(self.thread.thread_handle);
        switch (self.thread.completion.swap(.detached, .SeqCst)) {
            .running => {},
            .completed => self.thread.free(),
            .detached => unreachable,
        }
    }

    fn join(self: Impl) void {
        windows.WaitForSingleObjectEx(self.thread.thread_handle, windows.INFINITE, false) catch unreachable;
        windows.CloseHandle(self.thread.thread_handle);
        assert(self.thread.completion.load(.SeqCst) == .completed);
        self.thread.free();
    }
};

const PosixThreadImpl = struct {
    const c = std.c;

    pub const ThreadHandle = c.pthread_t;

    fn getCurrentId() Id {
        switch (target.os.tag) {
            .linux => {
                return LinuxThreadImpl.getCurrentId();
            },
            .macos, .ios, .watchos, .tvos => {
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
            else => {
                return @intFromPtr(c.pthread_self());
            },
        }
    }

    fn getCpuCount() !usize {
        switch (target.os.tag) {
            .linux => {
                return LinuxThreadImpl.getCpuCount();
            },
            .openbsd => {
                var count: c_int = undefined;
                var count_size: usize = @sizeOf(c_int);
                const mib = [_]c_int{ os.CTL.HW, os.system.HW.NCPUONLINE };
                os.sysctl(&mib, &count, &count_size, null, 0) catch |err| switch (err) {
                    error.NameTooLong, error.UnknownName => unreachable,
                    else => |e| return e,
                };
                return @as(usize, @intCast(count));
            },
            .solaris => {
                // The "proper" way to get the cpu count would be to query
                // /dev/kstat via ioctls, and traverse a linked list for each
                // cpu.
                const rc = c.sysconf(os._SC.NPROCESSORS_ONLN);
                return switch (os.errno(rc)) {
                    .SUCCESS => @as(usize, @intCast(rc)),
                    else => |err| os.unexpectedErrno(err),
                };
            },
            .haiku => {
                var system_info: os.system.system_info = undefined;
                const rc = os.system.get_system_info(&system_info); // always returns B_OK
                return switch (os.errno(rc)) {
                    .SUCCESS => @as(usize, @intCast(system_info.cpu_count)),
                    else => |err| os.unexpectedErrno(err),
                };
            },
            else => {
                var count: c_int = undefined;
                var count_len: usize = @sizeOf(c_int);
                const name = if (comptime target.isDarwin()) "hw.logicalcpu" else "hw.ncpu";
                os.sysctlbynameZ(name, &count, &count_len, null, 0) catch |err| switch (err) {
                    error.NameTooLong, error.UnknownName => unreachable,
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
            fn entryFn(raw_arg: ?*anyopaque) callconv(.C) ?*anyopaque {
                // @alignCast() below doesn't support zero-sized-types (ZST)
                if (@sizeOf(Args) < 1) {
                    return callFn(f, @as(Args, undefined));
                }

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
        assert(c.pthread_attr_setguardsize(&attr, std.mem.page_size) == .SUCCESS);

        var handle: c.pthread_t = undefined;
        switch (c.pthread_create(
            &handle,
            &attr,
            Instance.entryFn,
            if (@sizeOf(Args) > 1) @as(*anyopaque, @ptrCast(args_ptr)) else undefined,
        )) {
            .SUCCESS => return Impl{ .handle = handle },
            .AGAIN => return error.SystemResources,
            .PERM => unreachable,
            .INVAL => unreachable,
            else => |err| return os.unexpectedErrno(err),
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
        tid: Atomic(i32) = Atomic(i32).init(0),
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

    const State = Atomic(enum(u8) { running, completed, detached });

    fn getCurrentId() Id {
        return tls_thread_id;
    }

    fn getHandle(self: Impl) ThreadHandle {
        return self.thread.tid.load(.SeqCst);
    }

    fn detach(self: Impl) void {
        switch (self.thread.state.swap(.detached, .SeqCst)) {
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

        var spin: u8 = 10;
        while (true) {
            const tid = self.thread.tid.load(.SeqCst);
            if (tid == 0) {
                break;
            }

            if (spin > 0) {
                spin -= 1;
                std.atomic.spinLoopHint();
                continue;
            }

            const result = asm (
                \\ local.get %[ptr]
                \\ local.get %[expected]
                \\ i64.const -1 # infinite
                \\ memory.atomic.wait32 0
                \\ local.set %[ret]
                : [ret] "=r" (-> u32),
                : [ptr] "r" (&self.thread.tid.value),
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

    fn spawn(config: std.Thread.SpawnConfig, comptime f: anytype, args: anytype) !WasiThreadImpl {
        if (config.allocator == null) return error.OutOfMemory; // an allocator is required to spawn a WASI-thread

        // Wrapping struct required to hold the user-provided function arguments.
        const Wrapper = struct {
            args: @TypeOf(args),
            fn entry(ptr: usize) void {
                const w: *@This() = @ptrFromInt(ptr);
                @call(.auto, f, w.args);
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
        instance.thread.tid.store(tid, .SeqCst);

        return .{ .thread = &instance.thread };
    }

    /// Bootstrap procedure, called by the host environment after thread creation.
    export fn wasi_thread_start(tid: i32, arg: *Instance) void {
        if (builtin.single_threaded) {
            // ensure function is not analyzed in single-threaded mode
            return;
        }
        __set_stack_pointer(arg.thread.memory.ptr + arg.stack_offset);
        __wasm_init_tls(arg.thread.memory.ptr + arg.tls_offset);
        @atomicStore(u32, &WasiThreadImpl.tls_thread_id, @intCast(tid), .SeqCst);

        // Finished bootstrapping, call user's procedure.
        arg.call_back(arg.raw_ptr);

        switch (arg.thread.state.swap(.completed, .SeqCst)) {
            .running => {
                // reset the Thread ID
                asm volatile (
                    \\ local.get %[ptr]
                    \\ i32.const 0
                    \\ i32.atomic.store 0
                    :
                    : [ptr] "r" (&arg.thread.tid.value),
                );

                // Wake the main thread listening to this thread
                asm volatile (
                    \\ local.get %[ptr]
                    \\ i32.const 1 # waiters
                    \\ memory.atomic.notify 0
                    \\ drop # no need to know the waiters
                    :
                    : [ptr] "r" (&arg.thread.tid.value),
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
    const linux = os.linux;

    pub const ThreadHandle = i32;

    threadlocal var tls_thread_id: ?Id = null;

    fn getCurrentId() Id {
        return tls_thread_id orelse {
            const tid = @as(u32, @bitCast(linux.gettid()));
            tls_thread_id = tid;
            return tid;
        };
    }

    fn getCpuCount() !usize {
        const cpu_set = try os.sched_getaffinity(0);
        // TODO: should not need this usize cast
        return @as(usize, os.CPU_COUNT(cpu_set));
    }

    thread: *ThreadCompletion,

    const ThreadCompletion = struct {
        completion: Completion = Completion.init(.running),
        child_tid: Atomic(i32) = Atomic(i32).init(1),
        parent_tid: i32 = undefined,
        mapped: []align(std.mem.page_size) u8,

        /// Calls `munmap(mapped.ptr, mapped.len)` then `exit(1)` without touching the stack (which lives in `mapped.ptr`).
        /// Ported over from musl libc's pthread detached implementation:
        /// https://github.com/ifduyue/musl/search?q=__unmapself
        fn freeAndExit(self: *ThreadCompletion) noreturn {
            switch (target.cpu.arch) {
                .x86 => asm volatile (
                    \\  movl $91, %%eax
                    \\  movl %[ptr], %%ebx
                    \\  movl %[len], %%ecx
                    \\  int $128
                    \\  movl $1, %%eax
                    \\  movl $0, %%ebx
                    \\  int $128
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                .x86_64 => asm volatile (
                    \\  movq $11, %%rax
                    \\  syscall
                    \\  movq $60, %%rax
                    \\  movq $1, %%rdi
                    \\  syscall
                    :
                    : [ptr] "{rdi}" (@intFromPtr(self.mapped.ptr)),
                      [len] "{rsi}" (self.mapped.len),
                ),
                .arm, .armeb, .thumb, .thumbeb => asm volatile (
                    \\  mov r7, #91
                    \\  mov r0, %[ptr]
                    \\  mov r1, %[len]
                    \\  svc 0
                    \\  mov r7, #1
                    \\  mov r0, #0
                    \\  svc 0
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                .aarch64, .aarch64_be, .aarch64_32 => asm volatile (
                    \\  mov x8, #215
                    \\  mov x0, %[ptr]
                    \\  mov x1, %[len]
                    \\  svc 0
                    \\  mov x8, #93
                    \\  mov x0, #0
                    \\  svc 0
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                .mips, .mipsel => asm volatile (
                    \\  move $sp, $25
                    \\  li $2, 4091
                    \\  move $4, %[ptr]
                    \\  move $5, %[len]
                    \\  syscall
                    \\  li $2, 4001
                    \\  li $4, 0
                    \\  syscall
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                .mips64, .mips64el => asm volatile (
                    \\  li $2, 4091
                    \\  move $4, %[ptr]
                    \\  move $5, %[len]
                    \\  syscall
                    \\  li $2, 4001
                    \\  li $4, 0
                    \\  syscall
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => asm volatile (
                    \\  li 0, 91
                    \\  mr %[ptr], 3
                    \\  mr %[len], 4
                    \\  sc
                    \\  li 0, 1
                    \\  li 3, 0
                    \\  sc
                    \\  blr
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                .riscv64 => asm volatile (
                    \\  li a7, 215
                    \\  mv a0, %[ptr]
                    \\  mv a1, %[len]
                    \\  ecall
                    \\  li a7, 93
                    \\  mv a0, zero
                    \\  ecall
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                .sparc64 => asm volatile (
                    \\ # SPARCs really don't like it when active stack frames
                    \\ # is unmapped (it will result in a segfault), so we
                    \\ # force-deactivate it by running `restore` until
                    \\ # all frames are cleared.
                    \\  1:
                    \\  cmp %%fp, 0
                    \\  beq 2f
                    \\  nop
                    \\  ba 1b
                    \\  restore
                    \\  2:
                    \\  mov 73, %%g1
                    \\  mov %[ptr], %%o0
                    \\  mov %[len], %%o1
                    \\  # Flush register window contents to prevent background
                    \\  # memory access before unmapping the stack.
                    \\  flushw
                    \\  t 0x6d
                    \\  mov 1, %%g1
                    \\  mov 1, %%o0
                    \\  t 0x6d
                    :
                    : [ptr] "r" (@intFromPtr(self.mapped.ptr)),
                      [len] "r" (self.mapped.len),
                    : "memory"
                ),
                else => |cpu_arch| @compileError("Unsupported linux arch: " ++ @tagName(cpu_arch)),
            }
            unreachable;
        }
    };

    fn spawn(config: SpawnConfig, comptime f: anytype, args: anytype) !Impl {
        const page_size = std.mem.page_size;
        const Args = @TypeOf(args);
        const Instance = struct {
            fn_args: Args,
            thread: ThreadCompletion,

            fn entryFn(raw_arg: usize) callconv(.C) u8 {
                const self = @as(*@This(), @ptrFromInt(raw_arg));
                defer switch (self.thread.completion.swap(.completed, .SeqCst)) {
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

            bytes = std.mem.alignForward(usize, bytes, linux.tls.tls_image.alloc_align);
            tls_offset = bytes;
            bytes += linux.tls.tls_image.alloc_size;

            bytes = std.mem.alignForward(usize, bytes, @alignOf(Instance));
            instance_offset = bytes;
            bytes += @sizeOf(Instance);

            bytes = std.mem.alignForward(usize, bytes, page_size);
            break :blk bytes;
        };

        // map all memory needed without read/write permissions
        // to avoid committing the whole region right away
        // anonymous mapping ensures file descriptor limits are not exceeded
        const mapped = os.mmap(
            null,
            map_bytes,
            os.PROT.NONE,
            os.MAP.PRIVATE | os.MAP.ANONYMOUS,
            -1,
            0,
        ) catch |err| switch (err) {
            error.MemoryMappingNotSupported => unreachable,
            error.AccessDenied => unreachable,
            error.PermissionDenied => unreachable,
            error.ProcessFdQuotaExceeded => unreachable,
            error.SystemFdQuotaExceeded => unreachable,
            else => |e| return e,
        };
        assert(mapped.len >= map_bytes);
        errdefer os.munmap(mapped);

        // map everything but the guard page as read/write
        os.mprotect(
            @alignCast(mapped[guard_offset..]),
            os.PROT.READ | os.PROT.WRITE,
        ) catch |err| switch (err) {
            error.AccessDenied => unreachable,
            else => |e| return e,
        };

        // Prepare the TLS segment and prepare a user_desc struct when needed on x86
        var tls_ptr = os.linux.tls.prepareTLS(mapped[tls_offset..]);
        var user_desc: if (target.cpu.arch == .x86) os.linux.user_desc else void = undefined;
        if (target.cpu.arch == .x86) {
            defer tls_ptr = @intFromPtr(&user_desc);
            user_desc = .{
                .entry_number = os.linux.tls.tls_image.gdt_entry_number,
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

        switch (linux.getErrno(linux.clone(
            Instance.entryFn,
            @intFromPtr(&mapped[stack_offset]),
            flags,
            @intFromPtr(instance),
            &instance.thread.parent_tid,
            tls_ptr,
            &instance.thread.child_tid.value,
        ))) {
            .SUCCESS => return Impl{ .thread = &instance.thread },
            .AGAIN => return error.ThreadQuotaExceeded,
            .INVAL => unreachable,
            .NOMEM => return error.SystemResources,
            .NOSPC => unreachable,
            .PERM => unreachable,
            .USERS => unreachable,
            else => |err| return os.unexpectedErrno(err),
        }
    }

    fn getHandle(self: Impl) ThreadHandle {
        return self.thread.parent_tid;
    }

    fn detach(self: Impl) void {
        switch (self.thread.completion.swap(.detached, .SeqCst)) {
            .running => {},
            .completed => self.join(),
            .detached => unreachable,
        }
    }

    fn join(self: Impl) void {
        defer os.munmap(self.thread.mapped);

        var spin: u8 = 10;
        while (true) {
            const tid = self.thread.child_tid.load(.SeqCst);
            if (tid == 0) {
                break;
            }

            if (spin > 0) {
                spin -= 1;
                std.atomic.spinLoopHint();
                continue;
            }

            switch (linux.getErrno(linux.futex_wait(
                &self.thread.child_tid.value,
                linux.FUTEX.WAIT,
                tid,
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
        start_wait_event: ResetEvent = .{},
        test_done_event: ResetEvent = .{},
        thread_done_event: ResetEvent = .{},

        done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
        thread: Thread = undefined,

        pub fn run(ctx: *@This()) !void {
            // Wait for the main thread to have set the thread field in the context.
            ctx.start_wait_event.wait();

            switch (target.os.tag) {
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

    switch (target.os.tag) {
        .macos, .ios, .watchos, .tvos => {
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
    // Doesn't use testing.refAllDecls() since that would pull in the compileError spinLoopHint.
    _ = Futex;
    _ = ResetEvent;
    _ = Mutex;
    _ = Semaphore;
    _ = Condition;
    _ = RwLock;
}

fn testIncrementNotify(value: *usize, event: *ResetEvent) void {
    value.* += 1;
    event.set();
}

test "Thread.join" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var value: usize = 0;
    var event = ResetEvent{};

    const thread = try Thread.spawn(.{}, testIncrementNotify, .{ &value, &event });
    thread.join();

    try std.testing.expectEqual(value, 1);
}

test "Thread.detach" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var value: usize = 0;
    var event = ResetEvent{};

    const thread = try Thread.spawn(.{}, testIncrementNotify, .{ &value, &event });
    thread.detach();

    event.wait();
    try std.testing.expectEqual(value, 1);
}
