const std = @import("std.zig");
const builtin = std.builtin;
const os = std.os;
const mem = std.mem;
const windows = std.os.windows;
const c = std.c;
const assert = std.debug.assert;

const bad_startfn_ret = "expected return type of startFn to be 'u8', 'noreturn', 'void', or '!void'";

pub const Thread = struct {
    data: Data,

    pub const use_pthreads = std.Target.current.os.tag != .windows and builtin.link_libc;

    /// Represents a kernel thread handle.
    /// May be an integer or a pointer depending on the platform.
    /// On Linux and POSIX, this is the same as Id.
    pub const Handle = if (use_pthreads)
        c.pthread_t
    else switch (std.Target.current.os.tag) {
        .linux => i32,
        .windows => windows.HANDLE,
        else => void,
    };

    /// Represents a unique ID per thread.
    /// May be an integer or pointer depending on the platform.
    /// On Linux and POSIX, this is the same as Handle.
    pub const Id = switch (std.Target.current.os.tag) {
        .windows => windows.DWORD,
        else => Handle,
    };

    pub const Data = if (use_pthreads)
        struct {
            handle: Thread.Handle,
            memory: []align(mem.page_size) u8,
        }
    else switch (std.Target.current.os.tag) {
        .linux => struct {
            handle: Thread.Handle,
            memory: []align(mem.page_size) u8,
        },
        .windows => struct {
            handle: Thread.Handle,
            alloc_start: *c_void,
            heap_handle: windows.HANDLE,
        },
        else => struct {},
    };

    /// Returns the ID of the calling thread.
    /// Makes a syscall every time the function is called.
    /// On Linux and POSIX, this Id is the same as a Handle.
    pub fn getCurrentId() Id {
        if (use_pthreads) {
            return c.pthread_self();
        } else
            return switch (std.Target.current.os.tag) {
            .linux => os.linux.gettid(),
            .windows => windows.kernel32.GetCurrentThreadId(),
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
            os.munmap(self.data.memory);
        } else switch (std.Target.current.os.tag) {
            .linux => {
                while (true) {
                    const pid_value = @atomicLoad(i32, &self.data.handle, .SeqCst);
                    if (pid_value == 0) break;
                    const rc = os.linux.futex_wait(&self.data.handle, os.linux.FUTEX_WAIT, pid_value, null);
                    switch (os.linux.getErrno(rc)) {
                        0 => continue,
                        os.EINTR => continue,
                        os.EAGAIN => continue,
                        else => unreachable,
                    }
                }
                os.munmap(self.data.memory);
            },
            .windows => {
                windows.WaitForSingleObjectEx(self.data.handle, windows.INFINITE, false) catch unreachable;
                windows.CloseHandle(self.data.handle);
                windows.HeapFree(self.data.heap_handle, 0, self.data.alloc_start);
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

        /// `mlockall` is enabled, and the memory needed to spawn the thread
        /// would exceed the limit.
        LockedMemoryLimitExceeded,

        Unexpected,
    };

    /// caller must call wait on the returned thread
    /// fn startFn(@TypeOf(context)) T
    /// where T is u8, noreturn, void, or !void
    /// caller must call wait on the returned thread
    pub fn spawn(context: anytype, comptime startFn: anytype) SpawnError!*Thread {
        if (builtin.single_threaded) @compileError("cannot spawn thread when building in single-threaded mode");
        // TODO compile-time call graph analysis to determine stack upper bound
        // https://github.com/ziglang/zig/issues/157
        const default_stack_size = 16 * 1024 * 1024;

        const Context = @TypeOf(context);
        comptime assert(@typeInfo(@TypeOf(startFn)).Fn.args[0].arg_type.? == Context);

        if (std.Target.current.os.tag == .windows) {
            const WinThread = struct {
                const OuterContext = struct {
                    thread: Thread,
                    inner: Context,
                };
                fn threadMain(raw_arg: windows.LPVOID) callconv(.C) windows.DWORD {
                    const arg = if (@sizeOf(Context) == 0) {} else @ptrCast(*Context, @alignCast(@alignOf(Context), raw_arg)).*;

                    switch (@typeInfo(@TypeOf(startFn).ReturnType)) {
                        .NoReturn => {
                            startFn(arg);
                        },
                        .Void => {
                            startFn(arg);
                            return 0;
                        },
                        .Int => |info| {
                            if (info.bits != 8) {
                                @compileError(bad_startfn_ret);
                            }
                            return startFn(arg);
                        },
                        .ErrorUnion => |info| {
                            if (info.payload != void) {
                                @compileError(bad_startfn_ret);
                            }
                            startFn(arg) catch |err| {
                                std.debug.warn("error: {}\n", .{@errorName(err)});
                                if (@errorReturnTrace()) |trace| {
                                    std.debug.dumpStackTrace(trace.*);
                                }
                            };
                            return 0;
                        },
                        else => @compileError(bad_startfn_ret),
                    }
                }
            };

            const heap_handle = windows.kernel32.GetProcessHeap() orelse return error.OutOfMemory;
            const byte_count = @alignOf(WinThread.OuterContext) + @sizeOf(WinThread.OuterContext);
            const bytes_ptr = windows.kernel32.HeapAlloc(heap_handle, 0, byte_count) orelse return error.OutOfMemory;
            errdefer assert(windows.kernel32.HeapFree(heap_handle, 0, bytes_ptr) != 0);
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
            outer_context.thread.data.handle = windows.kernel32.CreateThread(null, default_stack_size, WinThread.threadMain, parameter, 0, null) orelse {
                switch (windows.kernel32.GetLastError()) {
                    else => |err| return windows.unexpectedError(err),
                }
            };
            return &outer_context.thread;
        }

        const MainFuncs = struct {
            fn linuxThreadMain(ctx_addr: usize) callconv(.C) u8 {
                const arg = if (@sizeOf(Context) == 0) {} else @intToPtr(*const Context, ctx_addr).*;

                switch (@typeInfo(@TypeOf(startFn).ReturnType)) {
                    .NoReturn => {
                        startFn(arg);
                    },
                    .Void => {
                        startFn(arg);
                        return 0;
                    },
                    .Int => |info| {
                        if (info.bits != 8) {
                            @compileError(bad_startfn_ret);
                        }
                        return startFn(arg);
                    },
                    .ErrorUnion => |info| {
                        if (info.payload != void) {
                            @compileError(bad_startfn_ret);
                        }
                        startFn(arg) catch |err| {
                            std.debug.warn("error: {}\n", .{@errorName(err)});
                            if (@errorReturnTrace()) |trace| {
                                std.debug.dumpStackTrace(trace.*);
                            }
                        };
                        return 0;
                    },
                    else => @compileError(bad_startfn_ret),
                }
            }
            fn posixThreadMain(ctx: ?*c_void) callconv(.C) ?*c_void {
                const arg = if (@sizeOf(Context) == 0) {} else @ptrCast(*Context, @alignCast(@alignOf(Context), ctx)).*;

                switch (@typeInfo(@TypeOf(startFn).ReturnType)) {
                    .NoReturn => {
                        startFn(arg);
                    },
                    .Void => {
                        startFn(arg);
                        return null;
                    },
                    .Int => |info| {
                        if (info.bits != 8) {
                            @compileError(bad_startfn_ret);
                        }
                        // pthreads don't support exit status, ignore value
                        _ = startFn(arg);
                        return null;
                    },
                    .ErrorUnion => |info| {
                        if (info.payload != void) {
                            @compileError(bad_startfn_ret);
                        }
                        startFn(arg) catch |err| {
                            std.debug.warn("error: {}\n", .{@errorName(err)});
                            if (@errorReturnTrace()) |trace| {
                                std.debug.dumpStackTrace(trace.*);
                            }
                        };
                        return null;
                    },
                    else => @compileError(bad_startfn_ret),
                }
            }
        };

        var guard_end_offset: usize = undefined;
        var stack_end_offset: usize = undefined;
        var thread_start_offset: usize = undefined;
        var context_start_offset: usize = undefined;
        var tls_start_offset: usize = undefined;
        const mmap_len = blk: {
            var l: usize = mem.page_size;
            // Allocate a guard page right after the end of the stack region
            guard_end_offset = l;
            // The stack itself, which grows downwards.
            l = mem.alignForward(l + default_stack_size, mem.page_size);
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
                l = mem.alignForward(l, os.linux.tls.tls_image.alloc_align);
                tls_start_offset = l;
                l += os.linux.tls.tls_image.alloc_size;
            }
            // Round the size to the page size.
            break :blk mem.alignForward(l, mem.page_size);
        };

        const mmap_slice = mem: {
            if (std.Target.current.os.tag != .netbsd) {
                // Map the whole stack with no rw permissions to avoid
                // committing the whole region right away
                const mmap_slice = os.mmap(
                    null,
                    mmap_len,
                    os.PROT_NONE,
                    os.MAP_PRIVATE | os.MAP_ANONYMOUS,
                    -1,
                    0,
                ) catch |err| switch (err) {
                    error.MemoryMappingNotSupported => unreachable,
                    error.AccessDenied => unreachable,
                    error.PermissionDenied => unreachable,
                    else => |e| return e,
                };
                errdefer os.munmap(mmap_slice);

                // Map everything but the guard page as rw
                os.mprotect(
                    mmap_slice[guard_end_offset..],
                    os.PROT_READ | os.PROT_WRITE,
                ) catch |err| switch (err) {
                    error.AccessDenied => unreachable,
                    else => |e| return e,
                };

                break :mem mmap_slice;
            } else {
                // NetBSD mprotect is very strict and doesn't allow to "upgrade"
                // a PROT_NONE mapping to a RW one so let's allocate everything
                // right away
                const mmap_slice = os.mmap(
                    null,
                    mmap_len,
                    os.PROT_READ | os.PROT_WRITE,
                    os.MAP_PRIVATE | os.MAP_ANONYMOUS,
                    -1,
                    0,
                ) catch |err| switch (err) {
                    error.MemoryMappingNotSupported => unreachable,
                    error.AccessDenied => unreachable,
                    error.PermissionDenied => unreachable,
                    else => |e| return e,
                };
                errdefer os.munmap(mmap_slice);

                // Remap the guard page with no permissions
                os.mprotect(
                    mmap_slice[0..guard_end_offset],
                    os.PROT_NONE,
                ) catch |err| switch (err) {
                    error.AccessDenied => unreachable,
                    else => |e| return e,
                };

                break :mem mmap_slice;
            }
        };

        const mmap_addr = @ptrToInt(mmap_slice.ptr);

        const thread_ptr = @alignCast(@alignOf(Thread), @intToPtr(*Thread, mmap_addr + thread_start_offset));
        thread_ptr.data.memory = mmap_slice;

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

            // Tell pthread where the effective stack start is and its size
            assert(c.pthread_attr_setstack(
                &attr,
                mmap_slice.ptr + guard_end_offset,
                stack_end_offset - guard_end_offset,
            ) == 0);
            // Even though pthread's man pages state that the guard size is
            // ignored when the stack address is explicitly given, on some
            // plaforms such as NetBSD we still have to zero it to prevent
            // random crashes in pthread_join calls
            assert(c.pthread_attr_setguardsize(&attr, 0) == 0);

            const err = c.pthread_create(&thread_ptr.data.handle, &attr, MainFuncs.posixThreadMain, @intToPtr(*c_void, arg));
            switch (err) {
                0 => return thread_ptr,
                os.EAGAIN => return error.SystemResources,
                os.EPERM => unreachable,
                os.EINVAL => unreachable,
                else => return os.unexpectedErrno(@intCast(usize, err)),
            }
        } else if (std.Target.current.os.tag == .linux) {
            const flags: u32 = os.CLONE_VM | os.CLONE_FS | os.CLONE_FILES |
                os.CLONE_SIGHAND | os.CLONE_THREAD | os.CLONE_SYSVSEM |
                os.CLONE_PARENT_SETTID | os.CLONE_CHILD_CLEARTID |
                os.CLONE_DETACHED | os.CLONE_SETTLS;
            // This structure is only needed when targeting i386
            var user_desc: if (std.Target.current.cpu.arch == .i386) os.linux.user_desc else void = undefined;

            const tls_area = mmap_slice[tls_start_offset..];
            const tp_value = os.linux.tls.prepareTLS(tls_area);

            const newtls = blk: {
                if (std.Target.current.cpu.arch == .i386) {
                    user_desc = os.linux.user_desc{
                        .entry_number = os.linux.tls.tls_image.gdt_entry_number,
                        .base_addr = tp_value,
                        .limit = 0xfffff,
                        .seg_32bit = 1,
                        .contents = 0, // Data
                        .read_exec_only = 0,
                        .limit_in_pages = 1,
                        .seg_not_present = 0,
                        .useable = 1,
                    };
                    break :blk @ptrToInt(&user_desc);
                } else {
                    break :blk tp_value;
                }
            };

            const rc = os.linux.clone(
                MainFuncs.linuxThreadMain,
                mmap_addr + stack_end_offset,
                flags,
                arg,
                &thread_ptr.data.handle,
                newtls,
                &thread_ptr.data.handle,
            );
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
        PermissionDenied,
        SystemResources,
        Unexpected,
    };

    pub fn cpuCount() CpuCountError!usize {
        if (std.Target.current.os.tag == .linux) {
            const cpu_set = try os.sched_getaffinity(0);
            return @as(usize, os.CPU_COUNT(cpu_set)); // TODO should not need this usize cast
        }
        if (std.Target.current.os.tag == .windows) {
            return os.windows.peb().NumberOfProcessors;
        }
        var count: c_int = undefined;
        var count_len: usize = @sizeOf(c_int);
        const name = if (comptime std.Target.current.isDarwin()) "hw.logicalcpu" else "hw.ncpu";
        os.sysctlbynameZ(name, &count, &count_len, null, 0) catch |err| switch (err) {
            error.NameTooLong, error.UnknownName => unreachable,
            else => |e| return e,
        };
        return @intCast(usize, count);
    }
};
