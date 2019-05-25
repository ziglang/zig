const builtin = @import("builtin");
const std = @import("std.zig");
const os = std.os;
const windows = std.os.windows;
const c = std.c;

pub const Thread = struct {
    data: Data,

    pub const use_pthreads = !windows.is_the_target and builtin.link_libc;

    /// Represents a kernel thread handle.
    /// May be an integer or a pointer depending on the platform.
    /// On Linux and POSIX, this is the same as Id.
    pub const Handle = if (use_pthreads)
        c.pthread_t
    else switch (builtin.os) {
        .linux => i32,
        .windows => windows.HANDLE,
        else => @compileError("Unsupported OS"),
    };

    /// Represents a unique ID per thread.
    /// May be an integer or pointer depending on the platform.
    /// On Linux and POSIX, this is the same as Handle.
    pub const Id = switch (builtin.os) {
        .windows => windows.DWORD,
        else => Handle,
    };

    pub const Data = if (use_pthreads)
        struct {
            handle: Thread.Handle,
            mmap_addr: usize,
            mmap_len: usize,
        }
    else switch (builtin.os) {
        .linux => struct {
            handle: Thread.Handle,
            mmap_addr: usize,
            mmap_len: usize,
        },
        .windows => struct {
            handle: Thread.Handle,
            alloc_start: *c_void,
            heap_handle: windows.HANDLE,
        },
        else => @compileError("Unsupported OS"),
    };

    /// Returns the ID of the calling thread.
    /// Makes a syscall every time the function is called.
    /// On Linux and POSIX, this Id is the same as a Handle.
    pub fn getCurrentId() Id {
        if (use_pthreads) {
            return c.pthread_self();
        } else
            return switch (builtin.os) {
            .linux => linux.gettid(),
            .windows => windows.GetCurrentThreadId(),
            else => @compileError("Unsupported OS"),
        };
    }

    /// Returns the handle of this thread.
    /// On Linux and POSIX, this is the same as Id.
    /// On Linux, it is possible that the thread spawned with `spawn`
    /// finishes executing entirely before the clone syscall completes. In this
    /// case, this function will return 0 rather than the no-longer-existing thread's
    /// pid.
    pub fn handle(self: Thread) Handle {
        return self.data.handle;
    }

    pub fn wait(self: *const Thread) void {
        if (use_pthreads) {
            const err = c.pthread_join(self.data.handle, null);
            switch (err) {
                0 => {},
                os.EINVAL => unreachable,
                os.ESRCH => unreachable,
                os.EDEADLK => unreachable,
                else => unreachable,
            }
            os.munmap(self.data.mmap_addr, self.data.mmap_len);
        } else switch (builtin.os) {
            .linux => {
                while (true) {
                    const pid_value = @atomicLoad(i32, &self.data.handle, .SeqCst);
                    if (pid_value == 0) break;
                    const rc = linux.futex_wait(&self.data.handle, linux.FUTEX_WAIT, pid_value, null);
                    switch (linux.getErrno(rc)) {
                        0 => continue,
                        os.EINTR => continue,
                        os.EAGAIN => continue,
                        else => unreachable,
                    }
                }
                os.munmap(self.data.mmap_addr, self.data.mmap_len);
            },
            .windows => {
                assert(windows.WaitForSingleObject(self.data.handle, windows.INFINITE) == windows.WAIT_OBJECT_0);
                assert(windows.CloseHandle(self.data.handle) != 0);
                assert(windows.HeapFree(self.data.heap_handle, 0, self.data.alloc_start) != 0);
            },
            else => @compileError("Unsupported OS"),
        }
    }

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

        Unexpected,
    };

    /// caller must call wait on the returned thread
    /// fn startFn(@typeOf(context)) T
    /// where T is u8, noreturn, void, or !void
    /// caller must call wait on the returned thread
    pub fn spawn(context: var, comptime startFn: var) SpawnError!*Thread {
        if (builtin.single_threaded) @compileError("cannot spawn thread when building in single-threaded mode");
        // TODO compile-time call graph analysis to determine stack upper bound
        // https://github.com/ziglang/zig/issues/157
        const default_stack_size = 8 * 1024 * 1024;

        const Context = @typeOf(context);
        comptime assert(@ArgType(@typeOf(startFn), 0) == Context);

        if (builtin.os == builtin.Os.windows) {
            const WinThread = struct {
                const OuterContext = struct {
                    thread: Thread,
                    inner: Context,
                };
                extern fn threadMain(raw_arg: windows.LPVOID) windows.DWORD {
                    const arg = if (@sizeOf(Context) == 0) {} else @ptrCast(*Context, @alignCast(@alignOf(Context), raw_arg)).*;
                    switch (@typeId(@typeOf(startFn).ReturnType)) {
                        .Int => {
                            return startFn(arg);
                        },
                        .Void => {
                            startFn(arg);
                            return 0;
                        },
                        else => @compileError("expected return type of startFn to be 'u8', 'noreturn', 'void', or '!void'"),
                    }
                }
            };

            const heap_handle = windows.GetProcessHeap() orelse return error.OutOfMemory;
            const byte_count = @alignOf(WinThread.OuterContext) + @sizeOf(WinThread.OuterContext);
            const bytes_ptr = windows.HeapAlloc(heap_handle, 0, byte_count) orelse return error.OutOfMemory;
            errdefer assert(windows.HeapFree(heap_handle, 0, bytes_ptr) != 0);
            const bytes = @ptrCast([*]u8, bytes_ptr)[0..byte_count];
            const outer_context = std.heap.FixedBufferAllocator.init(bytes).allocator.create(WinThread.OuterContext) catch unreachable;
            outer_context.* = WinThread.OuterContext{
                .thread = Thread{
                    .data = Thread.Data{
                        .heap_handle = heap_handle,
                        .alloc_start = bytes_ptr,
                        .handle = undefined,
                    },
                },
                .inner = context,
            };

            const parameter = if (@sizeOf(Context) == 0) null else @ptrCast(*c_void, &outer_context.inner);
            outer_context.thread.data.handle = windows.CreateThread(null, default_stack_size, WinThread.threadMain, parameter, 0, null) orelse {
                switch (windows.GetLastError()) {
                    else => |err| windows.unexpectedError(err),
                }
            };
            return &outer_context.thread;
        }

        const MainFuncs = struct {
            extern fn linuxThreadMain(ctx_addr: usize) u8 {
                const arg = if (@sizeOf(Context) == 0) {} else @intToPtr(*const Context, ctx_addr).*;

                switch (@typeId(@typeOf(startFn).ReturnType)) {
                    .Int => {
                        return startFn(arg);
                    },
                    .Void => {
                        startFn(arg);
                        return 0;
                    },
                    else => @compileError("expected return type of startFn to be 'u8', 'noreturn', 'void', or '!void'"),
                }
            }
            extern fn posixThreadMain(ctx: ?*c_void) ?*c_void {
                if (@sizeOf(Context) == 0) {
                    _ = startFn({});
                    return null;
                } else {
                    _ = startFn(@ptrCast(*const Context, @alignCast(@alignOf(Context), ctx)).*);
                    return null;
                }
            }
        };

        const MAP_GROWSDOWN = if (builtin.os == .linux) linux.MAP_GROWSDOWN else 0;

        var stack_end_offset: usize = undefined;
        var thread_start_offset: usize = undefined;
        var context_start_offset: usize = undefined;
        var tls_start_offset: usize = undefined;
        const mmap_len = blk: {
            // First in memory will be the stack, which grows downwards.
            var l: usize = mem.alignForward(default_stack_size, os.page_size);
            stack_end_offset = l;
            // Above the stack, so that it can be in the same mmap call, put the Thread object.
            l = mem.alignForward(l, @alignOf(Thread));
            thread_start_offset = l;
            l += @sizeOf(Thread);
            // Next, the Context object.
            if (@sizeOf(Context) != 0) {
                l = mem.alignForward(l, @alignOf(Context));
                context_start_offset = l;
                l += @sizeOf(Context);
            }
            // Finally, the Thread Local Storage, if any.
            if (!Thread.use_pthreads) {
                if (linux.tls.tls_image) |tls_img| {
                    l = mem.alignForward(l, @alignOf(usize));
                    tls_start_offset = l;
                    l += tls_img.alloc_size;
                }
            }
            break :blk l;
        };
        const mmap_addr = try os.mmap(null, mmap_len, os.PROT_READ | os.PROT_WRITE, os.MAP_PRIVATE | os.MAP_ANONYMOUS | MAP_GROWSDOWN, -1, 0);
        errdefer os.munmap(mmap_addr, mmap_len);

        const thread_ptr = @alignCast(@alignOf(Thread), @intToPtr(*Thread, mmap_addr + thread_start_offset));
        thread_ptr.data.mmap_addr = mmap_addr;
        thread_ptr.data.mmap_len = mmap_len;

        var arg: usize = undefined;
        if (@sizeOf(Context) != 0) {
            arg = mmap_addr + context_start_offset;
            const context_ptr = @alignCast(@alignOf(Context), @intToPtr(*Context, arg));
            context_ptr.* = context;
        }

        if (Thread.use_pthreads) {
            // use pthreads
            var attr: c.pthread_attr_t = undefined;
            if (c.pthread_attr_init(&attr) != 0) return error.SystemResources;
            defer assert(c.pthread_attr_destroy(&attr) == 0);

            assert(c.pthread_attr_setstack(&attr, @intToPtr(*c_void, mmap_addr), stack_end_offset) == 0);

            const err = c.pthread_create(&thread_ptr.data.handle, &attr, MainFuncs.posixThreadMain, @intToPtr(*c_void, arg));
            switch (err) {
                0 => return thread_ptr,
                os.EAGAIN => return error.SystemResources,
                os.EPERM => unreachable,
                os.EINVAL => unreachable,
                else => return os.unexpectedErrno(@intCast(usize, err)),
            }
        } else if (builtin.os == .linux) {
            var flags: u32 = os.CLONE_VM | os.CLONE_FS | os.CLONE_FILES | os.CLONE_SIGHAND |
                os.CLONE_THREAD | os.CLONE_SYSVSEM | os.CLONE_PARENT_SETTID | os.CLONE_CHILD_CLEARTID |
                os.CLONE_DETACHED;
            var newtls: usize = undefined;
            if (linux.tls.tls_image) |tls_img| {
                newtls = linux.tls.copyTLS(mmap_addr + tls_start_offset);
                flags |= os.CLONE_SETTLS;
            }
            const rc = os.linux.clone(MainFuncs.linuxThreadMain, mmap_addr + stack_end_offset, flags, arg, &thread_ptr.data.handle, newtls, &thread_ptr.data.handle);
            switch (os.errno(rc)) {
                0 => return thread_ptr,
                os.EAGAIN => return error.ThreadQuotaExceeded,
                os.EINVAL => unreachable,
                os.ENOMEM => return error.SystemResources,
                os.ENOSPC => unreachable,
                os.EPERM => unreachable,
                os.EUSERS => unreachable,
                else => |err| return os.unexpectedErrno(err),
            }
        } else {
            @compileError("Unsupported OS");
        }
    }

    pub const CpuCountError = error{
        OutOfMemory,
        PermissionDenied,
        Unexpected,
    };

    pub fn cpuCount() CpuCountError!usize {
        if (os.linux.is_the_target) {
            const cpu_set = try os.sched_getaffinity(0);
            return os.CPU_COUNT(cpu_set);
        }
        if (os.windows.is_the_target) {
            var system_info: windows.SYSTEM_INFO = undefined;
            windows.GetSystemInfo(&system_info);
            return @intCast(usize, system_info.dwNumberOfProcessors);
        }
        var count: c_int = undefined;
        var count_len: usize = @sizeOf(c_int);
        const name = if (os.darwin.is_the_target) c"hw.logicalcpu" else c"hw.ncpu";
        try os.sysctlbyname(name, @ptrCast(*c_void, &count), &count_len, null, 0);
        return @intCast(usize, count);
    }
};
