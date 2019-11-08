const std = @import("std.zig");
const builtin = @import("builtin");
const time = std.time;
const testing = std.testing;
const assert = std.debug.assert;
const SpinLock = std.SpinLock;
const linux = std.os.linux;
const windows = std.os.windows;

pub const ThreadParker = switch (builtin.os) {
    .macosx,
    .tvos,
    .ios,
    .watchos,
    .netbsd,
    .openbsd,
    .freebsd,
    .kfreebsd,
    .dragonfly,
    .haiku,
    .hermit,
    .solaris,
    .minix,
    .fuchsia,
    .emscripten => if (builtin.link_libc) PosixParker else SpinParker,
    .linux => if (builtin.link_libc) PosixParker else LinuxParker,
    .windows => WindowsParker,
    else => SpinParker,
};

const SpinParker = struct {
    pub fn init() SpinParker {
        return SpinParker{};
    }
    pub fn deinit(self: *SpinParker) void {}

    pub fn unpark(self: *SpinParker, ptr: *const u32) void {}

    pub fn park(self: *SpinParker, ptr: *const u32, expected: u32) void {
        var backoff = SpinLock.Backoff.init();
        while (@atomicLoad(u32, ptr, .Acquire) == expected)
            backoff.yield();
    }
};

const LinuxParker = struct {
    pub fn init() LinuxParker {
        return LinuxParker{};
    }
    pub fn deinit(self: *LinuxParker) void {}

    pub fn unpark(self: *LinuxParker, ptr: *const u32) void {
        const rc = linux.futex_wake(@ptrCast(*const i32, ptr), linux.FUTEX_WAKE | linux.FUTEX_PRIVATE_FLAG, 1);
        assert(linux.getErrno(rc) == 0);
    }

    pub fn park(self: *LinuxParker, ptr: *const u32, expected: u32) void {
        const value = @intCast(i32, expected);
        while (@atomicLoad(u32, ptr, .Acquire) == expected) {
            const rc = linux.futex_wait(@ptrCast(*const i32, ptr), linux.FUTEX_WAIT | linux.FUTEX_PRIVATE_FLAG, value, null);
            switch (linux.getErrno(rc)) {
                0, linux.EAGAIN => return,
                linux.EINTR => continue,
                linux.EINVAL => unreachable,
                else => unreachable,
            }
        }
    }
};

const WindowsParker = struct {
    waiters: u32,

    pub fn init() WindowsParker {
        return WindowsParker{ .waiters = 0 };
    }
    pub fn deinit(self: *WindowsParker) void {}

    pub fn unpark(self: *WindowsParker, ptr: *const u32) void {
        const key = @ptrCast(*const c_void, ptr);
        const handle_ptr = getEventHandlePtr() orelse return;

        var waiting = @atomicLoad(u32, &self.waiters, .Monotonic);
        while (waiting != 0) {
            waiting = @cmpxchgWeak(u32, &self.waiters, waiting, waiting - 1, .Acquire, .Monotonic) orelse {
                const rc = windows.ntdll.NtReleaseKeyedEvent(handle_ptr.*, key, windows.FALSE, null);
                assert(rc == 0);
                return;
            };
        }
    }

    pub fn park(self: *WindowsParker, ptr: *const u32, expected: u32) void {
        var spin = SpinLock.Backoff.init();
        const key = @ptrCast(*const c_void, ptr);
        
        while (@atomicLoad(u32, ptr, .Acquire) == expected) {
            if (getEventHandlePtr()) |handle_ptr| {
                _ = @atomicRmw(u32, &self.waiters, .Add, 1, .Release);
                const rc = windows.ntdll.NtWaitForKeyedEvent(handle_ptr.*, key, windows.FALSE, null);
                assert(rc == 0);
            } else {
                spin.yield();
            }
        }
    }

    var event_handle = std.lazyInit(windows.HANDLE);

    fn getEventHandlePtr() ?*const windows.HANDLE {
        return event_handle.get() orelse {
            const access_mask = windows.GENERIC_READ | windows.GENERIC_WRITE;
            if (windows.ntdll.NtCreateKeyedEvent(&event_handle.data, access_mask, null, 0) != 0)
                return null;
            event_handle.resolve();
            return &event_handle.data;
        };
    }
};

const PosixParker = struct {
    cond: pthread_cond_t,
    mutex: pthread_mutex_t,

    pub fn init() PosixParker {
        return PosixParker{
            .cond = PTHREAD_COND_INITIALIZER,
            .mutex = PTHREAD_MUTEX_INITIALIZER,
        };
    }

    pub fn deinit(self: *PosixParker) void {
        // On dragonfly, the destroy functions return EINVAL if they were initialized statically.
        const retm = pthread_mutex_destroy(&self.mutex);
        assert(retm == 0 or retm == (if (builtin.os == .dragonfly) os.EINVAL else 0));
        const retc = pthread_cond_destroy(&self.cond);
        assert(retc == 0 or retc == (if (builtin.os == .dragonfly) os.EINVAL else 0));
    }

    pub fn unpark(self: *PosixParker, ptr: *const u32) void {
        assert(pthread_mutex_lock(&self.mutex) == 0);
        defer assert(pthread_mutex_unlock(&self.mutex) == 0);
        assert(pthread_cond_signal(&self.cond) == 0);
    }

    pub fn park(self: *PosixParker, ptr: *const u32, expected: u32) void {
        assert(pthread_mutex_lock(&self.mutex) == 0);
        defer assert(pthread_mutex_unlock(&self.mutex) == 0);
        while (@atomicLoad(u32, ptr, .Acquire) == expected)
            assert(pthread_cond_wait(&self.cond, &self.mutex) == 0);
    }

    const PTHREAD_MUTEX_INITIALIZER = pthread_mutex_t{};
    extern "c" fn pthread_mutex_lock(mutex: *pthread_mutex_t) c_int;
    extern "c" fn pthread_mutex_unlock(mutex: *pthread_mutex_t) c_int;
    extern "c" fn pthread_mutex_destroy(mutex: *pthread_mutex_t) c_int;

    const PTHREAD_COND_INITIALIZER = pthread_cond_t{};
    extern "c" fn pthread_cond_wait(noalias cond: *pthread_cond_t, noalias mutex: *pthread_mutex_t) c_int;
    extern "c" fn pthread_cond_signal(cond: *pthread_cond_t) c_int;
    extern "c" fn pthread_cond_destroy(cond: *pthread_cond_t) c_int;

    // https://github.com/rust-lang/libc
    usingnamespace switch (builtin.os) {
        .macosx, .tvos, .ios, .watchos => struct {
            pub const pthread_mutex_t = extern struct {
                __sig: c_long = 0x32AAABA7,
                __opaque: [__PTHREAD_MUTEX_SIZE__]u8 = [_]u8{0} ** __PTHREAD_MUTEX_SIZE__,
            };
            pub const pthread_cond_t = extern struct {
                __sig: c_long = 0x3CB0B1BB,
                __opaque: [__PTHREAD_COND_SIZE__]u8 = [_]u8{0} ** __PTHREAD_COND_SIZE__,
            };
            const __PTHREAD_MUTEX_SIZE__ = if (@sizeOf(usize) == 8) 56 else 40;
            const __PTHREAD_COND_SIZE__ = if (@sizeOf(usize) == 8) 40 else 24;
        },
        .netbsd => struct {
            pub const pthread_mutex_t = extern struct {
                ptm_magic: c_uint = 0x33330003,
                ptm_errorcheck: padded_spin_t = 0,
                ptm_unused: padded_spin_t = 0,
                ptm_owner: usize = 0,
                ptm_waiters: ?*u8 = null,
                ptm_recursed: c_uint = 0,
                ptm_spare2: ?*c_void = null,
            };
            pub const pthread_cond_t = extern struct {
                ptc_magic: c_uint = 0x55550005,
                ptc_lock: pthread_spin_t = 0,
                ptc_waiters_first: ?*u8 = null,
                ptc_waiters_last: ?*u8 = null,
                ptc_mutex: ?*pthread_mutex_t = null,
                ptc_private: ?*c_void = null,
            };
            const pthread_spin_t = if (builtin.arch == .arm or .arch == .powerpc) c_int else u8;
            const padded_spin_t = switch (builtin.arch) {
                .sparc, .sparcel, .sparcv9, .i386, .x86_64, .le64 => u32,
                else => spin_t,
            };
        },
        .openbsd, .freebsd, .kfreebsd, .dragonfly => struct {
            pub const pthread_mutex_t = extern struct {
                inner: ?*c_void = null,
            };
            pub const pthread_cond_t = extern struct {
                inner: ?*c_void = null,
            };
        },
        .haiku => struct {
            pub const pthread_mutex_t = extern struct {
                flags: u32 = 0,
                lock: i32 = 0,
                unused: i32 = -42,
                owner: i32 = -1,
                owner_count: i32 = 0,
            };
            pub const pthread_cond_t = extern struct {
                flags: u32 = 0,
                unused: i32 = -42,
                mutex: ?*c_void = null,
                waiter_count: i32 = 0,
                lock: i32 = 0,
            };
        },
        .hermit => struct {
            pub const pthread_mutex_t = extern struct {
                inner: usize = ~usize(0),
            };
            pub const pthread_cond_t = extern struct {
                inner: usize = ~usize(0),
            };
        },
        .solaris => struct {
            pub const pthread_mutex_t = extern struct {
                __pthread_mutex_flag1: u16 = 0,
                __pthread_mutex_flag2: u8 = 0,
                __pthread_mutex_ceiling: u8 = 0,
                __pthread_mutex_type: u16 = 0,
                __pthread_mutex_magic: u16 = 0x4d58,
                __pthread_mutex_lock: u64 = 0,
                __pthread_mutex_data: u64 = 0,
            };
            pub const pthread_cond_t = extern struct {
                __pthread_cond_flag: u32 = 0,
                __pthread_cond_type: u16 = 0,
                __pthread_cond_magic: u16 = 0x4356,
                __pthread_cond_data: u64 = 0,
            };
        },
        .fuchsia, .minix, .linux => struct {
            pub const pthread_mutex_t = extern struct {
                size: [__SIZEOF_PTHREAD_MUTEX_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_MUTEX_T,
            };
            pub const pthread_cond_t = extern struct {
                size: [__SIZEOF_PTHREAD_COND_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_COND_T,
            };
            const __SIZEOF_PTHREAD_COND_T = 48;
            const __SIZEOF_PTHREAD_MUTEX_T = if (builtin.os == .fuchsia) 40 else switch (builtin.abi) {
                .musl, .musleabi, .musleabihf => if (@sizeOf(usize) == 8) 40 else 24,
                .gnu, .gnuabin32, .gnuabi64, .gnueabi, .gnueabihf, .gnux32 => switch (builtin.arch) {
                    .aarch64 => 48,
                    .x86_64 => if (builtin.abi == .gnux32) 40 else 32,
                    .mips64, .powerpc64, .powerpc64le, .sparcv9 => 40,
                    else => if (@sizeOf(usize) == 8) 40 else 24,
                },
                else => unreachable,
            };
        },
        .emscripten => struct {
            pub const pthread_mutex_t = extern struct {
                size: [__SIZEOF_PTHREAD_MUTEX_T]u8 align(4) = [_]u8{0} ** __SIZEOF_PTHREAD_MUTEX_T,
            };
            pub const pthread_cond_t = extern struct {
                size: [__SIZEOF_PTHREAD_COND_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_COND_T,
            };
            const __SIZEOF_PTHREAD_COND_T = 48;
            const __SIZEOF_PTHREAD_MUTEX_T = 28;
        },
        else => unreachable,
    };
};

test "std.ThreadParker" {
    if (builtin.single_threaded)
        return error.SkipZigTest;
        
    const Context = struct {
        parker: ThreadParker,
        data: u32,

        fn receiver(self: *@This()) void {
            self.parker.park(&self.data, 0);                                // receives 1
            assert(@atomicRmw(u32, &self.data, .Xchg, 2, .SeqCst) == 1);    // sends 2
            self.parker.unpark(&self.data);                                 // wakes up waiters on 2
            self.parker.park(&self.data, 2);                                // receives 3
            assert(@atomicRmw(u32, &self.data, .Xchg, 4, .SeqCst) == 3);    // sends 4
            self.parker.unpark(&self.data);                                 // wakes up waiters on 4
        }

        fn sender(self: *@This()) void {
            assert(@atomicRmw(u32, &self.data, .Xchg, 1, .SeqCst) == 0);    // sends 1
            self.parker.unpark(&self.data);                                 // wakes up waiters on 1
            self.parker.park(&self.data, 1);                                // receives 2
            assert(@atomicRmw(u32, &self.data, .Xchg, 3, .SeqCst) == 2);    // sends 3
            self.parker.unpark(&self.data);                                 // wakes up waiters on 3
            self.parker.park(&self.data, 3);                                // receives 4
        }
    };

    var context = Context{
        .parker = ThreadParker.init(),
        .data = 0,
    };
    defer context.parker.deinit();
    
    var receiver = try std.Thread.spawn(&context, Context.receiver);
    defer receiver.wait();

    context.sender();
}