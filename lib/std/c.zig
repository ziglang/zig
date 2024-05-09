const std = @import("std");
const builtin = @import("builtin");
const c = @This();
const page_size = std.mem.page_size;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const wasi = @import("c/wasi.zig");
const native_abi = builtin.abi;
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;
const linux = std.os.linux;

/// If not linking libc, returns false.
/// If linking musl libc, returns true.
/// If linking gnu libc (glibc), returns true if the target version is greater
/// than or equal to `glibc_version`.
/// If linking a libc other than these, returns `false`.
pub inline fn versionCheck(comptime glibc_version: std.SemanticVersion) bool {
    return comptime blk: {
        if (!builtin.link_libc) break :blk false;
        if (native_abi.isMusl()) break :blk true;
        if (builtin.target.isGnuLibC()) {
            const ver = builtin.os.version_range.linux.glibc;
            const order = ver.order(glibc_version);
            break :blk switch (order) {
                .gt, .eq => true,
                .lt => false,
            };
        } else {
            break :blk false;
        }
    };
}

pub usingnamespace switch (native_os) {
    .linux => @import("c/linux.zig"),
    .windows => @import("c/windows.zig"),
    .macos, .ios, .tvos, .watchos, .visionos => @import("c/darwin.zig"),
    .freebsd, .kfreebsd => @import("c/freebsd.zig"),
    .netbsd => @import("c/netbsd.zig"),
    .dragonfly => @import("c/dragonfly.zig"),
    .openbsd => @import("c/openbsd.zig"),
    .haiku => @import("c/haiku.zig"),
    .solaris, .illumos => @import("c/solaris.zig"),
    .emscripten => @import("c/emscripten.zig"),
    .wasi => wasi,
    else => struct {},
};

pub const pthread_mutex_t = switch (native_os) {
    .linux, .minix => extern struct {
        data: [data_len]u8 align(@alignOf(usize)) = [_]u8{0} ** data_len,

        const data_len = switch (native_abi) {
            .musl, .musleabi, .musleabihf => if (@sizeOf(usize) == 8) 40 else 24,
            .gnu, .gnuabin32, .gnuabi64, .gnueabi, .gnueabihf, .gnux32 => switch (native_arch) {
                .aarch64 => 48,
                .x86_64 => if (native_abi == .gnux32) 40 else 32,
                .mips64, .powerpc64, .powerpc64le, .sparc64 => 40,
                else => if (@sizeOf(usize) == 8) 40 else 24,
            },
            .android => if (@sizeOf(usize) == 8) 40 else 4,
            else => @compileError("unsupported ABI"),
        };
    },
    .macos, .ios, .tvos, .watchos, .visionos => extern struct {
        sig: c_long = 0x32AAABA7,
        data: [data_len]u8 = [_]u8{0} ** data_len,

        const data_len = if (@sizeOf(usize) == 8) 56 else 40;
    },
    .freebsd, .kfreebsd, .dragonfly, .openbsd => extern struct {
        inner: ?*anyopaque = null,
    },
    .hermit => extern struct {
        ptr: usize = std.math.maxInt(usize),
    },
    .netbsd => extern struct {
        magic: u32 = 0x33330003,
        errorcheck: c.padded_pthread_spin_t = 0,
        ceiling: c.padded_pthread_spin_t = 0,
        owner: usize = 0,
        waiters: ?*u8 = null,
        recursed: u32 = 0,
        spare2: ?*anyopaque = null,
    },
    .haiku => extern struct {
        flags: u32 = 0,
        lock: i32 = 0,
        unused: i32 = -42,
        owner: i32 = -1,
        owner_count: i32 = 0,
    },
    .solaris, .illumos => extern struct {
        flag1: u16 = 0,
        flag2: u8 = 0,
        ceiling: u8 = 0,
        type: u16 = 0,
        magic: u16 = 0x4d58,
        lock: u64 = 0,
        data: u64 = 0,
    },
    .fuchsia => extern struct {
        data: [40]u8 align(@alignOf(usize)) = [_]u8{0} ** 40,
    },
    .emscripten => extern struct {
        data: [24]u8 align(4) = [_]u8{0} ** 24,
    },
    else => @compileError("target libc does not have pthread_mutex_t"),
};

pub const pthread_cond_t = switch (native_os) {
    .linux => extern struct {
        data: [48]u8 align(@alignOf(usize)) = [_]u8{0} ** 48,
    },
    .macos, .ios, .tvos, .watchos, .visionos => extern struct {
        sig: c_long = 0x3CB0B1BB,
        data: [data_len]u8 = [_]u8{0} ** data_len,
        const data_len = if (@sizeOf(usize) == 8) 40 else 24;
    },
    .freebsd, .kfreebsd, .dragonfly, .openbsd => extern struct {
        inner: ?*anyopaque = null,
    },
    .hermit => extern struct {
        ptr: usize = std.math.maxInt(usize),
    },
    .netbsd => extern struct {
        magic: u32 = 0x55550005,
        lock: c.pthread_spin_t = 0,
        waiters_first: ?*u8 = null,
        waiters_last: ?*u8 = null,
        mutex: ?*pthread_mutex_t = null,
        private: ?*anyopaque = null,
    },
    .haiku => extern struct {
        flags: u32 = 0,
        unused: i32 = -42,
        mutex: ?*anyopaque = null,
        waiter_count: i32 = 0,
        lock: i32 = 0,
    },
    .solaris, .illumos => extern struct {
        flag: [4]u8 = [_]u8{0} ** 4,
        type: u16 = 0,
        magic: u16 = 0x4356,
        data: u64 = 0,
    },
    .fuchsia, .minix, .emscripten => extern struct {
        data: [48]u8 align(@alignOf(usize)) = [_]u8{0} ** 48,
    },
    else => @compileError("target libc does not have pthread_cond_t"),
};

pub const pthread_rwlock_t = switch (native_os) {
    .linux => switch (native_abi) {
        .android => switch (@sizeOf(usize)) {
            4 => extern struct {
                data: [40]u8 align(@alignOf(usize)) = [_]u8{0} ** 40,
            },
            8 => extern struct {
                data: [56]u8 align(@alignOf(usize)) = [_]u8{0} ** 56,
            },
            else => @compileError("impossible pointer size"),
        },
        else => extern struct {
            data: [56]u8 align(@alignOf(usize)) = [_]u8{0} ** 56,
        },
    },
    .macos, .ios, .tvos, .watchos, .visionos => extern struct {
        sig: c_long = 0x2DA8B3B4,
        data: [192]u8 = [_]u8{0} ** 192,
    },
    .freebsd, .kfreebsd, .dragonfly, .openbsd => extern struct {
        ptr: ?*anyopaque = null,
    },
    .hermit => extern struct {
        ptr: usize = std.math.maxInt(usize),
    },
    .netbsd => extern struct {
        magic: c_uint = 0x99990009,
        interlock: switch (builtin.cpu.arch) {
            .aarch64, .sparc, .x86_64, .x86 => u8,
            .arm, .powerpc => c_int,
            else => unreachable,
        } = 0,
        rblocked_first: ?*u8 = null,
        rblocked_last: ?*u8 = null,
        wblocked_first: ?*u8 = null,
        wblocked_last: ?*u8 = null,
        nreaders: c_uint = 0,
        owner: ?pthread_t = null,
        private: ?*anyopaque = null,
    },
    .solaris, .illumos => extern struct {
        readers: i32 = 0,
        type: u16 = 0,
        magic: u16 = 0x5257,
        mutex: pthread_mutex_t = .{},
        readercv: pthread_cond_t = .{},
        writercv: pthread_cond_t = .{},
    },
    .fuchsia => extern struct {
        size: [56]u8 align(@alignOf(usize)) = [_]u8{0} ** 56,
    },
    .emscripten => extern struct {
        size: [32]u8 align(4) = [_]u8{0} ** 32,
    },
    else => @compileError("target libc does not have pthread_rwlock_t"),
};

pub const AT = switch (native_os) {
    .linux => linux.AT,
    .windows => struct {
        /// Remove directory instead of unlinking file
        pub const REMOVEDIR = 0x200;
    },
    .macos, .ios, .tvos, .watchos, .visionos => struct {
        pub const FDCWD = -2;
        /// Use effective ids in access check
        pub const EACCESS = 0x0010;
        /// Act on the symlink itself not the target
        pub const SYMLINK_NOFOLLOW = 0x0020;
        /// Act on target of symlink
        pub const SYMLINK_FOLLOW = 0x0040;
        /// Path refers to directory
        pub const REMOVEDIR = 0x0080;
    },
    .freebsd, .kfreebsd => struct {
        /// Magic value that specify the use of the current working directory
        /// to determine the target of relative file paths in the openat() and
        /// similar syscalls.
        pub const FDCWD = -100;
        /// Check access using effective user and group ID
        pub const EACCESS = 0x0100;
        /// Do not follow symbolic links
        pub const SYMLINK_NOFOLLOW = 0x0200;
        /// Follow symbolic link
        pub const SYMLINK_FOLLOW = 0x0400;
        /// Remove directory instead of file
        pub const REMOVEDIR = 0x0800;
        /// Fail if not under dirfd
        pub const BENEATH = 0x1000;
    },
    .netbsd => struct {
        /// Magic value that specify the use of the current working directory
        /// to determine the target of relative file paths in the openat() and
        /// similar syscalls.
        pub const FDCWD = -100;
        /// Check access using effective user and group ID
        pub const EACCESS = 0x0100;
        /// Do not follow symbolic links
        pub const SYMLINK_NOFOLLOW = 0x0200;
        /// Follow symbolic link
        pub const SYMLINK_FOLLOW = 0x0400;
        /// Remove directory instead of file
        pub const REMOVEDIR = 0x0800;
    },
    .dragonfly => struct {
        pub const FDCWD = -328243;
        pub const SYMLINK_NOFOLLOW = 1;
        pub const REMOVEDIR = 2;
        pub const EACCESS = 4;
        pub const SYMLINK_FOLLOW = 8;
    },
    .openbsd => struct {
        /// Magic value that specify the use of the current working directory
        /// to determine the target of relative file paths in the openat() and
        /// similar syscalls.
        pub const FDCWD = -100;
        /// Check access using effective user and group ID
        pub const EACCESS = 0x01;
        /// Do not follow symbolic links
        pub const SYMLINK_NOFOLLOW = 0x02;
        /// Follow symbolic link
        pub const SYMLINK_FOLLOW = 0x04;
        /// Remove directory instead of file
        pub const REMOVEDIR = 0x08;
    },
    .haiku => struct {
        pub const FDCWD = -1;
        pub const SYMLINK_NOFOLLOW = 0x01;
        pub const SYMLINK_FOLLOW = 0x02;
        pub const REMOVEDIR = 0x04;
        pub const EACCESS = 0x08;
    },
    .solaris, .illumos => struct {
        /// Magic value that specify the use of the current working directory
        /// to determine the target of relative file paths in the openat() and
        /// similar syscalls.
        pub const FDCWD: c.fd_t = @bitCast(@as(u32, 0xffd19553));
        /// Do not follow symbolic links
        pub const SYMLINK_NOFOLLOW = 0x1000;
        /// Follow symbolic link
        pub const SYMLINK_FOLLOW = 0x2000;
        /// Remove directory instead of file
        pub const REMOVEDIR = 0x1;
        pub const TRIGGER = 0x2;
        /// Check access using effective user and group ID
        pub const EACCESS = 0x4;
    },
    .emscripten => struct {
        pub const FDCWD = -100;
        pub const SYMLINK_NOFOLLOW = 0x100;
        pub const REMOVEDIR = 0x200;
        pub const SYMLINK_FOLLOW = 0x400;
        pub const NO_AUTOMOUNT = 0x800;
        pub const EMPTY_PATH = 0x1000;
        pub const STATX_SYNC_TYPE = 0x6000;
        pub const STATX_SYNC_AS_STAT = 0x0000;
        pub const STATX_FORCE_SYNC = 0x2000;
        pub const STATX_DONT_SYNC = 0x4000;
        pub const RECURSIVE = 0x8000;
    },
    .wasi => struct {
        pub const SYMLINK_NOFOLLOW = 0x100;
        pub const SYMLINK_FOLLOW = 0x400;
        pub const REMOVEDIR: u32 = 0x4;
        /// When linking libc, we follow their convention and use -2 for current working directory.
        /// However, without libc, Zig does a different convention: it assumes the
        /// current working directory is the first preopen. This behavior can be
        /// overridden with a public function called `wasi_cwd` in the root source
        /// file.
        pub const FDCWD: c.fd_t = if (builtin.link_libc) -2 else 3;
    },

    else => @compileError("target libc does not have AT"),
};

pub const O = switch (native_os) {
    .linux => linux.O,
    .emscripten => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        _2: u4 = 0,
        CREAT: bool = false,
        EXCL: bool = false,
        NOCTTY: bool = false,
        TRUNC: bool = false,
        APPEND: bool = false,
        NONBLOCK: bool = false,
        DSYNC: bool = false,
        ASYNC: bool = false,
        DIRECT: bool = false,
        LARGEFILE: bool = false,
        DIRECTORY: bool = false,
        NOFOLLOW: bool = false,
        NOATIME: bool = false,
        CLOEXEC: bool = false,
        SYNC: bool = false,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u9 = 0,
    },
    .wasi => packed struct(u32) {
        APPEND: bool = false,
        DSYNC: bool = false,
        NONBLOCK: bool = false,
        RSYNC: bool = false,
        SYNC: bool = false,
        _5: u7 = 0,
        CREAT: bool = false,
        DIRECTORY: bool = false,
        EXCL: bool = false,
        TRUNC: bool = false,
        _16: u8 = 0,
        NOFOLLOW: bool = false,
        EXEC: bool = false,
        read: bool = false,
        SEARCH: bool = false,
        write: bool = false,
        _: u3 = 0,
    },
    .solaris, .illumos => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        NDELAY: bool = false,
        APPEND: bool = false,
        SYNC: bool = false,
        _5: u1 = 0,
        DSYNC: bool = false,
        NONBLOCK: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        NOCTTY: bool = false,
        _12: u1 = 0,
        LARGEFILE: bool = false,
        XATTR: bool = false,
        RSYNC: bool = false,
        _16: u1 = 0,
        NOFOLLOW: bool = false,
        NOLINKS: bool = false,
        _19: u2 = 0,
        SEARCH: bool = false,
        EXEC: bool = false,
        CLOEXEC: bool = false,
        DIRECTORY: bool = false,
        DIRECT: bool = false,
        _: u6 = 0,
    },
    .netbsd => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        NONBLOCK: bool = false,
        APPEND: bool = false,
        SHLOCK: bool = false,
        EXLOCK: bool = false,
        ASYNC: bool = false,
        SYNC: bool = false,
        NOFOLLOW: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        _12: u3 = 0,
        NOCTTY: bool = false,
        DSYNC: bool = false,
        RSYNC: bool = false,
        ALT_IO: bool = false,
        DIRECT: bool = false,
        _20: u1 = 0,
        DIRECTORY: bool = false,
        CLOEXEC: bool = false,
        SEARCH: bool = false,
        _: u8 = 0,
    },
    .openbsd => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        NONBLOCK: bool = false,
        APPEND: bool = false,
        SHLOCK: bool = false,
        EXLOCK: bool = false,
        ASYNC: bool = false,
        SYNC: bool = false,
        NOFOLLOW: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        _12: u3 = 0,
        NOCTTY: bool = false,
        CLOEXEC: bool = false,
        DIRECTORY: bool = false,
        _: u14 = 0,
    },
    .haiku => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        _2: u4 = 0,
        CLOEXEC: bool = false,
        NONBLOCK: bool = false,
        EXCL: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        APPEND: bool = false,
        NOCTTY: bool = false,
        NOTRAVERSE: bool = false,
        _14: u2 = 0,
        SYNC: bool = false,
        RSYNC: bool = false,
        DSYNC: bool = false,
        NOFOLLOW: bool = false,
        DIRECT: bool = false,
        DIRECTORY: bool = false,
        _: u10 = 0,
    },
    .macos, .ios, .tvos, .watchos, .visionos => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        NONBLOCK: bool = false,
        APPEND: bool = false,
        SHLOCK: bool = false,
        EXLOCK: bool = false,
        ASYNC: bool = false,
        SYNC: bool = false,
        NOFOLLOW: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        _12: u3 = 0,
        EVTONLY: bool = false,
        _16: u1 = 0,
        NOCTTY: bool = false,
        _18: u2 = 0,
        DIRECTORY: bool = false,
        SYMLINK: bool = false,
        DSYNC: bool = false,
        _23: u1 = 0,
        CLOEXEC: bool = false,
        _25: u4 = 0,
        ALERT: bool = false,
        _30: u1 = 0,
        POPUP: bool = false,
    },
    .dragonfly => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        NONBLOCK: bool = false,
        APPEND: bool = false,
        SHLOCK: bool = false,
        EXLOCK: bool = false,
        ASYNC: bool = false,
        SYNC: bool = false,
        NOFOLLOW: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        _12: u3 = 0,
        NOCTTY: bool = false,
        DIRECT: bool = false,
        CLOEXEC: bool = false,
        FBLOCKING: bool = false,
        FNONBLOCKING: bool = false,
        FAPPEND: bool = false,
        FOFFSET: bool = false,
        FSYNCWRITE: bool = false,
        FASYNCWRITE: bool = false,
        _24: u3 = 0,
        DIRECTORY: bool = false,
        _: u4 = 0,
    },
    .freebsd => packed struct(u32) {
        ACCMODE: std.posix.ACCMODE = .RDONLY,
        NONBLOCK: bool = false,
        APPEND: bool = false,
        SHLOCK: bool = false,
        EXLOCK: bool = false,
        ASYNC: bool = false,
        SYNC: bool = false,
        NOFOLLOW: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        DSYNC: bool = false,
        _13: u2 = 0,
        NOCTTY: bool = false,
        DIRECT: bool = false,
        DIRECTORY: bool = false,
        NOATIME: bool = false,
        _19: u1 = 0,
        CLOEXEC: bool = false,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u9 = 0,
    },
    else => @compileError("target libc does not have O"),
};

pub const MAP = switch (native_os) {
    .linux => linux.MAP,
    .emscripten => packed struct(u32) {
        TYPE: enum(u4) {
            SHARED = 0x01,
            PRIVATE = 0x02,
            SHARED_VALIDATE = 0x03,
        },
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        _6: u2 = 0,
        GROWSDOWN: bool = false,
        _9: u2 = 0,
        DENYWRITE: bool = false,
        EXECUTABLE: bool = false,
        LOCKED: bool = false,
        NORESERVE: bool = false,
        POPULATE: bool = false,
        NONBLOCK: bool = false,
        STACK: bool = false,
        HUGETLB: bool = false,
        SYNC: bool = false,
        FIXED_NOREPLACE: bool = false,
        _: u11 = 0,
    },
    .solaris, .illumos => packed struct(u32) {
        TYPE: enum(u4) {
            SHARED = 0x01,
            PRIVATE = 0x02,
        },
        FIXED: bool = false,
        RENAME: bool = false,
        NORESERVE: bool = false,
        @"32BIT": bool = false,
        ANONYMOUS: bool = false,
        ALIGN: bool = false,
        TEXT: bool = false,
        INITDATA: bool = false,
        _: u20 = 0,
    },
    .netbsd => packed struct(u32) {
        TYPE: enum(u2) {
            SHARED = 0x01,
            PRIVATE = 0x02,
        },
        REMAPDUP: bool = false,
        _3: u1 = 0,
        FIXED: bool = false,
        RENAME: bool = false,
        NORESERVE: bool = false,
        INHERIT: bool = false,
        _8: u1 = 0,
        HASSEMAPHORE: bool = false,
        TRYFIXED: bool = false,
        WIRED: bool = false,
        ANONYMOUS: bool = false,
        STACK: bool = false,
        _: u18 = 0,
    },
    .openbsd => packed struct(u32) {
        TYPE: enum(u4) {
            SHARED = 0x01,
            PRIVATE = 0x02,
        },
        FIXED: bool = false,
        _5: u7 = 0,
        ANONYMOUS: bool = false,
        _13: u1 = 0,
        STACK: bool = false,
        CONCEAL: bool = false,
        _: u16 = 0,
    },
    .haiku => packed struct(u32) {
        TYPE: enum(u2) {
            SHARED = 0x01,
            PRIVATE = 0x02,
        },
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        NORESERVE: bool = false,
        _: u27 = 0,
    },
    .macos, .ios, .tvos, .watchos, .visionos => packed struct(u32) {
        TYPE: enum(u4) {
            SHARED = 0x01,
            PRIVATE = 0x02,
        },
        FIXED: bool = false,
        _5: u1 = 0,
        NORESERVE: bool = false,
        _7: u2 = 0,
        HASSEMAPHORE: bool = false,
        NOCACHE: bool = false,
        _11: u1 = 0,
        ANONYMOUS: bool = false,
        _: u19 = 0,
    },
    .dragonfly => packed struct(u32) {
        TYPE: enum(u4) {
            SHARED = 0x01,
            PRIVATE = 0x02,
        },
        FIXED: bool = false,
        RENAME: bool = false,
        NORESERVE: bool = false,
        INHERIT: bool = false,
        NOEXTEND: bool = false,
        HASSEMAPHORE: bool = false,
        STACK: bool = false,
        NOSYNC: bool = false,
        ANONYMOUS: bool = false,
        VPAGETABLE: bool = false,
        _14: u2 = 0,
        TRYFIXED: bool = false,
        NOCORE: bool = false,
        SIZEALIGN: bool = false,
        _: u13 = 0,
    },
    .freebsd => packed struct(u32) {
        TYPE: enum(u4) {
            SHARED = 0x01,
            PRIVATE = 0x02,
        },
        FIXED: bool = false,
        _5: u5 = 0,
        STACK: bool = false,
        NOSYNC: bool = false,
        ANONYMOUS: bool = false,
        GUARD: bool = false,
        EXCL: bool = false,
        _15: u2 = 0,
        NOCORE: bool = false,
        PREFAULT_READ: bool = false,
        @"32BIT": bool = false,
        _: u12 = 0,
    },
    else => @compileError("target libc does not have MAP"),
};

/// Used by libc to communicate failure. Not actually part of the underlying syscall.
pub const MAP_FAILED: *anyopaque = @ptrFromInt(std.math.maxInt(usize));

pub const cc_t = u8;

/// Indices into the `cc` array in the `termios` struct.
pub const V = switch (native_os) {
    .linux => linux.V,
    .macos, .ios, .tvos, .watchos, .visionos, .netbsd, .openbsd => enum {
        EOF,
        EOL,
        EOL2,
        ERASE,
        WERASE,
        KILL,
        REPRINT,
        reserved,
        INTR,
        QUIT,
        SUSP,
        DSUSP,
        START,
        STOP,
        LNEXT,
        DISCARD,
        MIN,
        TIME,
        STATUS,
    },
    .freebsd, .kfreebsd => enum {
        EOF,
        EOL,
        EOL2,
        ERASE,
        WERASE,
        KILL,
        REPRINT,
        ERASE2,
        INTR,
        QUIT,
        SUSP,
        DSUSP,
        START,
        STOP,
        LNEXT,
        DISCARD,
        MIN,
        TIME,
        STATUS,
    },
    .haiku => enum {
        INTR,
        QUIT,
        ERASE,
        KILL,
        EOF,
        EOL,
        EOL2,
        SWTCH,
        START,
        STOP,
        SUSP,
    },
    .solaris, .illumos => enum {
        INTR,
        QUIT,
        ERASE,
        KILL,
        EOF,
        EOL,
        EOL2,
        SWTCH,
        START,
        STOP,
        SUSP,
        DSUSP,
        REPRINT,
        DISCARD,
        WERASE,
        LNEXT,
        STATUS,
        ERASE2,
    },
    .emscripten, .wasi => enum {
        INTR,
        QUIT,
        ERASE,
        KILL,
        EOF,
        TIME,
        MIN,
        SWTC,
        START,
        STOP,
        SUSP,
        EOL,
        REPRINT,
        DISCARD,
        WERASE,
        LNEXT,
        EOL2,
    },
    else => @compileError("target libc does not have cc_t"),
};

pub const NCCS = switch (native_os) {
    .linux => linux.NCCS,
    .macos, .ios, .tvos, .watchos, .visionos, .freebsd, .kfreebsd, .netbsd, .openbsd, .dragonfly => 20,
    .haiku => 11,
    .solaris, .illumos => 19,
    .emscripten, .wasi => 32,
    else => @compileError("target libc does not have NCCS"),
};

pub const termios = switch (native_os) {
    .linux => linux.termios,
    .macos, .ios, .tvos, .watchos, .visionos => extern struct {
        iflag: tc_iflag_t,
        oflag: tc_oflag_t,
        cflag: tc_cflag_t,
        lflag: tc_lflag_t,
        cc: [NCCS]cc_t,
        ispeed: speed_t align(8),
        ospeed: speed_t,
    },
    .freebsd, .kfreebsd, .netbsd, .dragonfly, .openbsd => extern struct {
        iflag: tc_iflag_t,
        oflag: tc_oflag_t,
        cflag: tc_cflag_t,
        lflag: tc_lflag_t,
        cc: [NCCS]cc_t,
        ispeed: speed_t,
        ospeed: speed_t,
    },
    .haiku => extern struct {
        iflag: tc_iflag_t,
        oflag: tc_oflag_t,
        cflag: tc_cflag_t,
        lflag: tc_lflag_t,
        line: cc_t,
        ispeed: speed_t,
        ospeed: speed_t,
        cc: [NCCS]cc_t,
    },
    .solaris, .illumos => extern struct {
        iflag: tc_iflag_t,
        oflag: tc_oflag_t,
        cflag: tc_cflag_t,
        lflag: tc_lflag_t,
        cc: [NCCS]cc_t,
    },
    .emscripten, .wasi => extern struct {
        iflag: tc_iflag_t,
        oflag: tc_oflag_t,
        cflag: tc_cflag_t,
        lflag: tc_lflag_t,
        line: std.c.cc_t,
        cc: [NCCS]cc_t,
        ispeed: speed_t,
        ospeed: speed_t,
    },
    else => @compileError("target libc does not have termios"),
};

pub const tc_iflag_t = switch (native_os) {
    .linux => linux.tc_iflag_t,
    .macos, .ios, .tvos, .watchos, .visionos => packed struct(u64) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IXON: bool = false,
        IXOFF: bool = false,
        IXANY: bool = false,
        _12: u1 = 0,
        IMAXBEL: bool = false,
        IUTF8: bool = false,
        _: u49 = 0,
    },
    .netbsd, .freebsd, .kfreebsd, .dragonfly => packed struct(u32) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IXON: bool = false,
        IXOFF: bool = false,
        IXANY: bool = false,
        _12: u1 = 0,
        IMAXBEL: bool = false,
        _: u18 = 0,
    },
    .openbsd => packed struct(u32) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IXON: bool = false,
        IXOFF: bool = false,
        IXANY: bool = false,
        IUCLC: bool = false,
        IMAXBEL: bool = false,
        _: u18 = 0,
    },
    .haiku => packed struct(u32) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IUCLC: bool = false,
        IXON: bool = false,
        IXANY: bool = false,
        IXOFF: bool = false,
        _: u19 = 0,
    },
    .solaris, .illumos => packed struct(u32) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IUCLC: bool = false,
        IXON: bool = false,
        IXANY: bool = false,
        _12: u1 = 0,
        IMAXBEL: bool = false,
        _14: u1 = 0,
        DOSMODE: bool = false,
        _: u16 = 0,
    },
    .emscripten, .wasi => packed struct(u32) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IUCLC: bool = false,
        IXON: bool = false,
        IXANY: bool = false,
        IXOFF: bool = false,
        IMAXBEL: bool = false,
        IUTF8: bool = false,
        _: u17 = 0,
    },
    else => @compileError("target libc does not have tc_iflag_t"),
};

pub const tc_oflag_t = switch (native_os) {
    .linux => linux.tc_oflag_t,
    .macos, .ios, .tvos, .watchos, .visionos => packed struct(u64) {
        OPOST: bool = false,
        ONLCR: bool = false,
        OXTABS: bool = false,
        ONOEOT: bool = false,
        OCRNL: bool = false,
        ONOCR: bool = false,
        ONLRET: bool = false,
        OFILL: bool = false,
        NLDLY: u2 = 0,
        TABDLY: u2 = 0,
        CRDLY: u2 = 0,
        FFDLY: u1 = 0,
        BSDLY: u1 = 0,
        VTDLY: u1 = 0,
        OFDEL: bool = false,
        _: u46 = 0,
    },
    .netbsd => packed struct(u32) {
        OPOST: bool = false,
        ONLCR: bool = false,
        OXTABS: bool = false,
        ONOEOT: bool = false,
        OCRNL: bool = false,
        _5: u1 = 0,
        ONOCR: bool = false,
        ONLRET: bool = false,
        _: u24 = 0,
    },
    .openbsd => packed struct(u32) {
        OPOST: bool = false,
        ONLCR: bool = false,
        OXTABS: bool = false,
        ONOEOT: bool = false,
        OCRNL: bool = false,
        OLCUC: bool = false,
        ONOCR: bool = false,
        ONLRET: bool = false,
        _: u24 = 0,
    },
    .freebsd, .kfreebsd, .dragonfly => packed struct(u32) {
        OPOST: bool = false,
        ONLCR: bool = false,
        _2: u1 = 0,
        ONOEOT: bool = false,
        OCRNL: bool = false,
        ONOCR: bool = false,
        ONLRET: bool = false,
        _: u25 = 0,
    },
    .solaris, .illumos => packed struct(u32) {
        OPOST: bool = false,
        OLCUC: bool = false,
        ONLCR: bool = false,
        OCRNL: bool = false,
        ONOCR: bool = false,
        ONLRET: bool = false,
        OFILL: bool = false,
        OFDEL: bool = false,
        NLDLY: u1 = 0,
        CRDLY: u2 = 0,
        TABDLY: u2 = 0,
        BSDLY: u1 = 0,
        VTDLY: u1 = 0,
        FFDLY: u1 = 0,
        PAGEOUT: bool = false,
        WRAP: bool = false,
        _: u14 = 0,
    },
    .haiku, .wasi, .emscripten => packed struct(u32) {
        OPOST: bool = false,
        OLCUC: bool = false,
        ONLCR: bool = false,
        OCRNL: bool = false,
        ONOCR: bool = false,
        ONLRET: bool = false,
        OFILL: bool = false,
        OFDEL: bool = false,
        NLDLY: u1 = 0,
        CRDLY: u2 = 0,
        TABDLY: u2 = 0,
        BSDLY: u1 = 0,
        VTDLY: u1 = 0,
        FFDLY: u1 = 0,
        _: u16 = 0,
    },
    else => @compileError("target libc does not have tc_oflag_t"),
};

pub const CSIZE = switch (native_os) {
    .linux => linux.CSIZE,
    .haiku => enum(u1) { CS7, CS8 },
    else => enum(u2) { CS5, CS6, CS7, CS8 },
};

pub const tc_cflag_t = switch (native_os) {
    .linux => linux.tc_cflag_t,
    .macos, .ios, .tvos, .watchos, .visionos => packed struct(u64) {
        CIGNORE: bool = false,
        _1: u5 = 0,
        CSTOPB: bool = false,
        _7: u1 = 0,
        CSIZE: CSIZE = .CS5,
        _10: u1 = 0,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        CCTS_OFLOW: bool = false,
        CRTS_IFLOW: bool = false,
        CDTR_IFLOW: bool = false,
        CDSR_OFLOW: bool = false,
        CCAR_OFLOW: bool = false,
        _: u43 = 0,
    },
    .freebsd, .kfreebsd => packed struct(u32) {
        CIGNORE: bool = false,
        _1: u7 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        CCTS_OFLOW: bool = false,
        CRTS_IFLOW: bool = false,
        CDTR_IFLOW: bool = false,
        CDSR_OFLOW: bool = false,
        CCAR_OFLOW: bool = false,
        CNO_RTSDTR: bool = false,
        _: u10 = 0,
    },
    .netbsd => packed struct(u32) {
        CIGNORE: bool = false,
        _1: u7 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        CRTSCTS: bool = false,
        CDTRCTS: bool = false,
        _18: u2 = 0,
        MDMBUF: bool = false,
        _: u11 = 0,
    },
    .dragonfly => packed struct(u32) {
        CIGNORE: bool = false,
        _1: u7 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        CCTS_OFLOW: bool = false,
        CRTS_IFLOW: bool = false,
        CDTR_IFLOW: bool = false,
        CDSR_OFLOW: bool = false,
        CCAR_OFLOW: bool = false,
        _: u11 = 0,
    },
    .openbsd => packed struct(u32) {
        CIGNORE: bool = false,
        _1: u7 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        CRTSCTS: bool = false,
        _17: u3 = 0,
        MDMBUF: bool = false,
        _: u11 = 0,
    },
    .haiku => packed struct(u32) {
        _0: u5 = 0,
        CSIZE: CSIZE = .CS7,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        XLOBLK: bool = false,
        CTSFLOW: bool = false,
        RTSFLOW: bool = false,
        _: u17 = 0,
    },
    .solaris, .illumos => packed struct(u32) {
        _0: u4 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        RCV1EN: bool = false,
        XMT1EN: bool = false,
        LOBLK: bool = false,
        XCLUDE: bool = false,
        _16: u4 = 0,
        PAREXT: bool = false,
        CBAUDEXT: bool = false,
        CIBAUDEXT: bool = false,
        _23: u7 = 0,
        CRTSXOFF: bool = false,
        CRTSCTS: bool = false,
    },
    .wasi, .emscripten => packed struct(u32) {
        _0: u4 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        _: u20 = 0,
    },
    else => @compileError("target libc does not have tc_cflag_t"),
};

pub const tc_lflag_t = switch (native_os) {
    .linux => linux.tc_lflag_t,
    .macos, .ios, .tvos, .watchos, .visionos => packed struct(u64) {
        ECHOKE: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHO: bool = false,
        ECHONL: bool = false,
        ECHOPRT: bool = false,
        ECHOCTL: bool = false,
        ISIG: bool = false,
        ICANON: bool = false,
        ALTWERASE: bool = false,
        IEXTEN: bool = false,
        EXTPROC: bool = false,
        _12: u10 = 0,
        TOSTOP: bool = false,
        FLUSHO: bool = false,
        _24: u1 = 0,
        NOKERNINFO: bool = false,
        _26: u3 = 0,
        PENDIN: bool = false,
        _30: u1 = 0,
        NOFLSH: bool = false,
        _: u32 = 0,
    },
    .netbsd, .freebsd, .kfreebsd, .dragonfly => packed struct(u32) {
        ECHOKE: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHO: bool = false,
        ECHONL: bool = false,
        ECHOPRT: bool = false,
        ECHOCTL: bool = false,
        ISIG: bool = false,
        ICANON: bool = false,
        ALTWERASE: bool = false,
        IEXTEN: bool = false,
        EXTPROC: bool = false,
        _12: u10 = 0,
        TOSTOP: bool = false,
        FLUSHO: bool = false,
        _24: u1 = 0,
        NOKERNINFO: bool = false,
        _26: u3 = 0,
        PENDIN: bool = false,
        _30: u1 = 0,
        NOFLSH: bool = false,
    },
    .openbsd => packed struct(u32) {
        ECHOKE: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHO: bool = false,
        ECHONL: bool = false,
        ECHOPRT: bool = false,
        ECHOCTL: bool = false,
        ISIG: bool = false,
        ICANON: bool = false,
        ALTWERASE: bool = false,
        IEXTEN: bool = false,
        EXTPROC: bool = false,
        _12: u10 = 0,
        TOSTOP: bool = false,
        FLUSHO: bool = false,
        XCASE: bool = false,
        NOKERNINFO: bool = false,
        _26: u3 = 0,
        PENDIN: bool = false,
        _30: u1 = 0,
        NOFLSH: bool = false,
    },
    .haiku => packed struct(u32) {
        ISIG: bool = false,
        ICANON: bool = false,
        XCASE: bool = false,
        ECHO: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHONL: bool = false,
        NOFLSH: bool = false,
        TOSTOP: bool = false,
        IEXTEN: bool = false,
        ECHOCTL: bool = false,
        ECHOPRT: bool = false,
        ECHOKE: bool = false,
        FLUSHO: bool = false,
        PENDIN: bool = false,
        _: u17 = 0,
    },
    .solaris, .illumos => packed struct(u32) {
        ISIG: bool = false,
        ICANON: bool = false,
        XCASE: bool = false,
        ECHO: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHONL: bool = false,
        NOFLSH: bool = false,
        TOSTOP: bool = false,
        ECHOCTL: bool = false,
        ECHOPRT: bool = false,
        ECHOKE: bool = false,
        DEFECHO: bool = false,
        FLUSHO: bool = false,
        PENDIN: bool = false,
        IEXTEN: bool = false,
        _: u16 = 0,
    },
    .wasi, .emscripten => packed struct(u32) {
        ISIG: bool = false,
        ICANON: bool = false,
        _2: u1 = 0,
        ECHO: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHONL: bool = false,
        NOFLSH: bool = false,
        TOSTOP: bool = false,
        _9: u6 = 0,
        IEXTEN: bool = false,
        _: u16 = 0,
    },
    else => @compileError("target libc does not have tc_lflag_t"),
};

pub const speed_t = switch (native_os) {
    .linux => linux.speed_t,
    .macos, .ios, .tvos, .watchos, .visionos, .openbsd => enum(u64) {
        B0 = 0,
        B50 = 50,
        B75 = 75,
        B110 = 110,
        B134 = 134,
        B150 = 150,
        B200 = 200,
        B300 = 300,
        B600 = 600,
        B1200 = 1200,
        B1800 = 1800,
        B2400 = 2400,
        B4800 = 4800,
        B9600 = 9600,
        B19200 = 19200,
        B38400 = 38400,
        B7200 = 7200,
        B14400 = 14400,
        B28800 = 28800,
        B57600 = 57600,
        B76800 = 76800,
        B115200 = 115200,
        B230400 = 230400,
    },
    .freebsd, .kfreebsd, .netbsd => enum(c_uint) {
        B0 = 0,
        B50 = 50,
        B75 = 75,
        B110 = 110,
        B134 = 134,
        B150 = 150,
        B200 = 200,
        B300 = 300,
        B600 = 600,
        B1200 = 1200,
        B1800 = 1800,
        B2400 = 2400,
        B4800 = 4800,
        B9600 = 9600,
        B19200 = 19200,
        B38400 = 38400,
        B7200 = 7200,
        B14400 = 14400,
        B28800 = 28800,
        B57600 = 57600,
        B76800 = 76800,
        B115200 = 115200,
        B230400 = 230400,
        B460800 = 460800,
        B500000 = 500000,
        B921600 = 921600,
        B1000000 = 1000000,
        B1500000 = 1500000,
        B2000000 = 2000000,
        B2500000 = 2500000,
        B3000000 = 3000000,
        B3500000 = 3500000,
        B4000000 = 4000000,
    },
    .dragonfly => enum(c_uint) {
        B0 = 0,
        B50 = 50,
        B75 = 75,
        B110 = 110,
        B134 = 134,
        B150 = 150,
        B200 = 200,
        B300 = 300,
        B600 = 600,
        B1200 = 1200,
        B1800 = 1800,
        B2400 = 2400,
        B4800 = 4800,
        B9600 = 9600,
        B19200 = 19200,
        B38400 = 38400,
        B7200 = 7200,
        B14400 = 14400,
        B28800 = 28800,
        B57600 = 57600,
        B76800 = 76800,
        B115200 = 115200,
        B230400 = 230400,
        B460800 = 460800,
        B921600 = 921600,
    },
    .haiku => enum(u8) {
        B0 = 0x00,
        B50 = 0x01,
        B75 = 0x02,
        B110 = 0x03,
        B134 = 0x04,
        B150 = 0x05,
        B200 = 0x06,
        B300 = 0x07,
        B600 = 0x08,
        B1200 = 0x09,
        B1800 = 0x0A,
        B2400 = 0x0B,
        B4800 = 0x0C,
        B9600 = 0x0D,
        B19200 = 0x0E,
        B38400 = 0x0F,
        B57600 = 0x10,
        B115200 = 0x11,
        B230400 = 0x12,
        B31250 = 0x13,
    },
    .solaris, .illumos => enum(c_uint) {
        B0 = 0,
        B50 = 1,
        B75 = 2,
        B110 = 3,
        B134 = 4,
        B150 = 5,
        B200 = 6,
        B300 = 7,
        B600 = 8,
        B1200 = 9,
        B1800 = 10,
        B2400 = 11,
        B4800 = 12,
        B9600 = 13,
        B19200 = 14,
        B38400 = 15,
        B57600 = 16,
        B76800 = 17,
        B115200 = 18,
        B153600 = 19,
        B230400 = 20,
        B307200 = 21,
        B460800 = 22,
        B921600 = 23,
        B1000000 = 24,
        B1152000 = 25,
        B1500000 = 26,
        B2000000 = 27,
        B2500000 = 28,
        B3000000 = 29,
        B3500000 = 30,
        B4000000 = 31,
    },
    .emscripten, .wasi => enum(u32) {
        B0 = 0o0000000,
        B50 = 0o0000001,
        B75 = 0o0000002,
        B110 = 0o0000003,
        B134 = 0o0000004,
        B150 = 0o0000005,
        B200 = 0o0000006,
        B300 = 0o0000007,
        B600 = 0o0000010,
        B1200 = 0o0000011,
        B1800 = 0o0000012,
        B2400 = 0o0000013,
        B4800 = 0o0000014,
        B9600 = 0o0000015,
        B19200 = 0o0000016,
        B38400 = 0o0000017,

        B57600 = 0o0010001,
        B115200 = 0o0010002,
        B230400 = 0o0010003,
        B460800 = 0o0010004,
        B500000 = 0o0010005,
        B576000 = 0o0010006,
        B921600 = 0o0010007,
        B1000000 = 0o0010010,
        B1152000 = 0o0010011,
        B1500000 = 0o0010012,
        B2000000 = 0o0010013,
        B2500000 = 0o0010014,
        B3000000 = 0o0010015,
        B3500000 = 0o0010016,
        B4000000 = 0o0010017,
    },
    else => @compileError("target libc does not have speed_t"),
};

pub const whence_t = if (native_os == .wasi) std.os.wasi.whence_t else c_int;

// Unix-like systems
pub const DIR = opaque {};
pub extern "c" fn opendir(pathname: [*:0]const u8) ?*DIR;
pub extern "c" fn fdopendir(fd: c_int) ?*DIR;
pub extern "c" fn rewinddir(dp: *DIR) void;
pub extern "c" fn closedir(dp: *DIR) c_int;
pub extern "c" fn telldir(dp: *DIR) c_long;
pub extern "c" fn seekdir(dp: *DIR, loc: c_long) void;

pub extern "c" fn sigwait(set: ?*c.sigset_t, sig: ?*c_int) c_int;

pub extern "c" fn alarm(seconds: c_uint) c_uint;

pub const clock_getres = switch (native_os) {
    .netbsd => private.__clock_getres50,
    else => private.clock_getres,
};

pub const clock_gettime = switch (native_os) {
    .netbsd => private.__clock_gettime50,
    else => private.clock_gettime,
};

pub const fstat = switch (native_os) {
    .macos => switch (native_arch) {
        .x86_64 => private.@"fstat$INODE64",
        else => private.fstat,
    },
    .netbsd => private.__fstat50,
    else => private.fstat,
};

pub const fstatat = switch (native_os) {
    .macos => switch (native_arch) {
        .x86_64 => private.@"fstatat$INODE64",
        else => private.fstatat,
    },
    else => private.fstatat,
};

pub const getdirentries = switch (native_os) {
    .macos, .ios, .tvos, .watchos, .visionos => private.__getdirentries64,
    else => private.getdirentries,
};

pub const getrusage = switch (native_os) {
    .netbsd => private.__getrusage50,
    else => private.getrusage,
};

pub const gettimeofday = switch (native_os) {
    .netbsd => private.__gettimeofday50,
    else => private.gettimeofday,
};

pub const msync = switch (native_os) {
    .netbsd => private.__msync13,
    else => private.msync,
};

pub const nanosleep = switch (native_os) {
    .netbsd => private.__nanosleep50,
    else => private.nanosleep,
};

pub const readdir = switch (native_os) {
    .macos => switch (native_arch) {
        .x86_64 => private.@"readdir$INODE64",
        else => private.readdir,
    },
    .windows => @compileError("not available"),
    else => private.readdir,
};

pub const realpath = switch (native_os) {
    .macos, .ios, .tvos, .watchos, .visionos => private.@"realpath$DARWIN_EXTSN",
    else => private.realpath,
};

pub const sched_yield = switch (native_os) {
    .netbsd => private.__libc_thr_yield,
    else => private.sched_yield,
};

pub const sigaction = switch (native_os) {
    .netbsd => private.__sigaction14,
    else => private.sigaction,
};

pub const sigfillset = switch (native_os) {
    .netbsd => private.__sigfillset14,
    else => private.sigfillset,
};

pub const sigprocmask = switch (native_os) {
    .netbsd => private.__sigprocmask14,
    else => private.sigprocmask,
};

pub const socket = switch (native_os) {
    .netbsd => private.__socket30,
    else => private.socket,
};

pub const stat = switch (native_os) {
    .macos => switch (native_arch) {
        .x86_64 => private.@"stat$INODE64",
        else => private.stat,
    },
    else => private.stat,
};

pub extern "c" var environ: [*:null]?[*:0]u8;

pub extern "c" fn fopen(noalias filename: [*:0]const u8, noalias modes: [*:0]const u8) ?*FILE;
pub extern "c" fn fclose(stream: *FILE) c_int;
pub extern "c" fn fwrite(noalias ptr: [*]const u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize;
pub extern "c" fn fread(noalias ptr: [*]u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize;

pub extern "c" fn printf(format: [*:0]const u8, ...) c_int;
pub extern "c" fn abort() noreturn;
pub extern "c" fn exit(code: c_int) noreturn;
pub extern "c" fn _exit(code: c_int) noreturn;
pub extern "c" fn isatty(fd: c.fd_t) c_int;
pub extern "c" fn close(fd: c.fd_t) c_int;
pub extern "c" fn lseek(fd: c.fd_t, offset: c.off_t, whence: whence_t) c.off_t;
pub extern "c" fn open(path: [*:0]const u8, oflag: O, ...) c_int;
pub extern "c" fn openat(fd: c_int, path: [*:0]const u8, oflag: O, ...) c_int;
pub extern "c" fn ftruncate(fd: c_int, length: c.off_t) c_int;
pub extern "c" fn raise(sig: c_int) c_int;
pub extern "c" fn read(fd: c.fd_t, buf: [*]u8, nbyte: usize) isize;
pub extern "c" fn readv(fd: c_int, iov: [*]const iovec, iovcnt: c_uint) isize;
pub extern "c" fn pread(fd: c.fd_t, buf: [*]u8, nbyte: usize, offset: c.off_t) isize;
pub extern "c" fn preadv(fd: c_int, iov: [*]const iovec, iovcnt: c_uint, offset: c.off_t) isize;
pub extern "c" fn writev(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint) isize;
pub extern "c" fn pwritev(fd: c_int, iov: [*]const iovec_const, iovcnt: c_uint, offset: c.off_t) isize;
pub extern "c" fn write(fd: c.fd_t, buf: [*]const u8, nbyte: usize) isize;
pub extern "c" fn pwrite(fd: c.fd_t, buf: [*]const u8, nbyte: usize, offset: c.off_t) isize;
pub extern "c" fn mmap(addr: ?*align(page_size) anyopaque, len: usize, prot: c_uint, flags: MAP, fd: c.fd_t, offset: c.off_t) *anyopaque;
pub extern "c" fn munmap(addr: *align(page_size) const anyopaque, len: usize) c_int;
pub extern "c" fn mprotect(addr: *align(page_size) anyopaque, len: usize, prot: c_uint) c_int;
pub extern "c" fn link(oldpath: [*:0]const u8, newpath: [*:0]const u8, flags: c_int) c_int;
pub extern "c" fn linkat(oldfd: c.fd_t, oldpath: [*:0]const u8, newfd: c.fd_t, newpath: [*:0]const u8, flags: c_int) c_int;
pub extern "c" fn unlink(path: [*:0]const u8) c_int;
pub extern "c" fn unlinkat(dirfd: c.fd_t, path: [*:0]const u8, flags: c_uint) c_int;
pub extern "c" fn getcwd(buf: [*]u8, size: usize) ?[*]u8;
pub extern "c" fn waitpid(pid: c.pid_t, status: ?*c_int, options: c_int) c.pid_t;
pub extern "c" fn wait4(pid: c.pid_t, status: ?*c_int, options: c_int, ru: ?*c.rusage) c.pid_t;
pub extern "c" fn fork() c_int;
pub extern "c" fn access(path: [*:0]const u8, mode: c_uint) c_int;
pub extern "c" fn faccessat(dirfd: c.fd_t, path: [*:0]const u8, mode: c_uint, flags: c_uint) c_int;
pub extern "c" fn pipe(fds: *[2]c.fd_t) c_int;
pub extern "c" fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
pub extern "c" fn mkdirat(dirfd: c.fd_t, path: [*:0]const u8, mode: u32) c_int;
pub extern "c" fn symlink(existing: [*:0]const u8, new: [*:0]const u8) c_int;
pub extern "c" fn symlinkat(oldpath: [*:0]const u8, newdirfd: c.fd_t, newpath: [*:0]const u8) c_int;
pub extern "c" fn rename(old: [*:0]const u8, new: [*:0]const u8) c_int;
pub extern "c" fn renameat(olddirfd: c.fd_t, old: [*:0]const u8, newdirfd: c.fd_t, new: [*:0]const u8) c_int;
pub extern "c" fn chdir(path: [*:0]const u8) c_int;
pub extern "c" fn fchdir(fd: c.fd_t) c_int;
pub extern "c" fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) c_int;
pub extern "c" fn dup(fd: c.fd_t) c_int;
pub extern "c" fn dup2(old_fd: c.fd_t, new_fd: c.fd_t) c_int;
pub extern "c" fn readlink(noalias path: [*:0]const u8, noalias buf: [*]u8, bufsize: usize) isize;
pub extern "c" fn readlinkat(dirfd: c.fd_t, noalias path: [*:0]const u8, noalias buf: [*]u8, bufsize: usize) isize;
pub extern "c" fn chmod(path: [*:0]const u8, mode: c.mode_t) c_int;
pub extern "c" fn fchmod(fd: c.fd_t, mode: c.mode_t) c_int;
pub extern "c" fn fchmodat(fd: c.fd_t, path: [*:0]const u8, mode: c.mode_t, flags: c_uint) c_int;
pub extern "c" fn fchown(fd: c.fd_t, owner: c.uid_t, group: c.gid_t) c_int;
pub extern "c" fn umask(mode: c.mode_t) c.mode_t;

pub extern "c" fn rmdir(path: [*:0]const u8) c_int;
pub extern "c" fn getenv(name: [*:0]const u8) ?[*:0]u8;
pub extern "c" fn sysctl(name: [*]const c_int, namelen: c_uint, oldp: ?*anyopaque, oldlenp: ?*usize, newp: ?*anyopaque, newlen: usize) c_int;
pub extern "c" fn sysctlbyname(name: [*:0]const u8, oldp: ?*anyopaque, oldlenp: ?*usize, newp: ?*anyopaque, newlen: usize) c_int;
pub extern "c" fn sysctlnametomib(name: [*:0]const u8, mibp: ?*c_int, sizep: ?*usize) c_int;
pub extern "c" fn tcgetattr(fd: c.fd_t, termios_p: *c.termios) c_int;
pub extern "c" fn tcsetattr(fd: c.fd_t, optional_action: c.TCSA, termios_p: *const c.termios) c_int;
pub extern "c" fn fcntl(fd: c.fd_t, cmd: c_int, ...) c_int;
pub extern "c" fn flock(fd: c.fd_t, operation: c_int) c_int;
pub extern "c" fn ioctl(fd: c.fd_t, request: c_int, ...) c_int;
pub extern "c" fn uname(buf: *c.utsname) c_int;

pub extern "c" fn gethostname(name: [*]u8, len: usize) c_int;
pub extern "c" fn shutdown(socket: c.fd_t, how: c_int) c_int;
pub extern "c" fn bind(socket: c.fd_t, address: ?*const c.sockaddr, address_len: c.socklen_t) c_int;
pub extern "c" fn socketpair(domain: c_uint, sock_type: c_uint, protocol: c_uint, sv: *[2]c.fd_t) c_int;
pub extern "c" fn listen(sockfd: c.fd_t, backlog: c_uint) c_int;
pub extern "c" fn getsockname(sockfd: c.fd_t, noalias addr: *c.sockaddr, noalias addrlen: *c.socklen_t) c_int;
pub extern "c" fn getpeername(sockfd: c.fd_t, noalias addr: *c.sockaddr, noalias addrlen: *c.socklen_t) c_int;
pub extern "c" fn connect(sockfd: c.fd_t, sock_addr: *const c.sockaddr, addrlen: c.socklen_t) c_int;
pub extern "c" fn accept(sockfd: c.fd_t, noalias addr: ?*c.sockaddr, noalias addrlen: ?*c.socklen_t) c_int;
pub extern "c" fn accept4(sockfd: c.fd_t, noalias addr: ?*c.sockaddr, noalias addrlen: ?*c.socklen_t, flags: c_uint) c_int;
pub extern "c" fn getsockopt(sockfd: c.fd_t, level: i32, optname: u32, noalias optval: ?*anyopaque, noalias optlen: *c.socklen_t) c_int;
pub extern "c" fn setsockopt(sockfd: c.fd_t, level: i32, optname: u32, optval: ?*const anyopaque, optlen: c.socklen_t) c_int;
pub extern "c" fn send(sockfd: c.fd_t, buf: *const anyopaque, len: usize, flags: u32) isize;
pub extern "c" fn sendto(
    sockfd: c.fd_t,
    buf: *const anyopaque,
    len: usize,
    flags: u32,
    dest_addr: ?*const c.sockaddr,
    addrlen: c.socklen_t,
) isize;
pub extern "c" fn sendmsg(sockfd: c.fd_t, msg: *const c.msghdr_const, flags: u32) isize;

pub extern "c" fn recv(
    sockfd: c.fd_t,
    arg1: ?*anyopaque,
    arg2: usize,
    arg3: c_int,
) if (native_os == .windows) c_int else isize;
pub extern "c" fn recvfrom(
    sockfd: c.fd_t,
    noalias buf: *anyopaque,
    len: usize,
    flags: u32,
    noalias src_addr: ?*c.sockaddr,
    noalias addrlen: ?*c.socklen_t,
) if (native_os == .windows) c_int else isize;
pub extern "c" fn recvmsg(sockfd: c.fd_t, msg: *c.msghdr, flags: u32) isize;

pub extern "c" fn kill(pid: c.pid_t, sig: c_int) c_int;

pub extern "c" fn setuid(uid: c.uid_t) c_int;
pub extern "c" fn setgid(gid: c.gid_t) c_int;
pub extern "c" fn seteuid(euid: c.uid_t) c_int;
pub extern "c" fn setegid(egid: c.gid_t) c_int;
pub extern "c" fn setreuid(ruid: c.uid_t, euid: c.uid_t) c_int;
pub extern "c" fn setregid(rgid: c.gid_t, egid: c.gid_t) c_int;
pub extern "c" fn setresuid(ruid: c.uid_t, euid: c.uid_t, suid: c.uid_t) c_int;
pub extern "c" fn setresgid(rgid: c.gid_t, egid: c.gid_t, sgid: c.gid_t) c_int;

pub extern "c" fn malloc(usize) ?*anyopaque;
pub extern "c" fn realloc(?*anyopaque, usize) ?*anyopaque;
pub extern "c" fn free(?*anyopaque) void;

pub extern "c" fn futimes(fd: c.fd_t, times: *[2]c.timeval) c_int;
pub extern "c" fn utimes(path: [*:0]const u8, times: *[2]c.timeval) c_int;

pub extern "c" fn utimensat(dirfd: c.fd_t, pathname: [*:0]const u8, times: *[2]c.timespec, flags: u32) c_int;
pub extern "c" fn futimens(fd: c.fd_t, times: *const [2]c.timespec) c_int;

pub extern "c" fn pthread_create(
    noalias newthread: *pthread_t,
    noalias attr: ?*const c.pthread_attr_t,
    start_routine: *const fn (?*anyopaque) callconv(.C) ?*anyopaque,
    noalias arg: ?*anyopaque,
) c.E;
pub extern "c" fn pthread_attr_init(attr: *c.pthread_attr_t) c.E;
pub extern "c" fn pthread_attr_setstack(attr: *c.pthread_attr_t, stackaddr: *anyopaque, stacksize: usize) c.E;
pub extern "c" fn pthread_attr_setstacksize(attr: *c.pthread_attr_t, stacksize: usize) c.E;
pub extern "c" fn pthread_attr_setguardsize(attr: *c.pthread_attr_t, guardsize: usize) c.E;
pub extern "c" fn pthread_attr_destroy(attr: *c.pthread_attr_t) c.E;
pub extern "c" fn pthread_self() pthread_t;
pub extern "c" fn pthread_join(thread: pthread_t, arg_return: ?*?*anyopaque) c.E;
pub extern "c" fn pthread_detach(thread: pthread_t) c.E;
pub extern "c" fn pthread_atfork(
    prepare: ?*const fn () callconv(.C) void,
    parent: ?*const fn () callconv(.C) void,
    child: ?*const fn () callconv(.C) void,
) c_int;
pub extern "c" fn pthread_key_create(
    key: *c.pthread_key_t,
    destructor: ?*const fn (value: *anyopaque) callconv(.C) void,
) c.E;
pub extern "c" fn pthread_key_delete(key: c.pthread_key_t) c.E;
pub extern "c" fn pthread_getspecific(key: c.pthread_key_t) ?*anyopaque;
pub extern "c" fn pthread_setspecific(key: c.pthread_key_t, value: ?*anyopaque) c_int;
pub extern "c" fn pthread_sigmask(how: c_int, set: *const c.sigset_t, oldset: *c.sigset_t) c_int;
pub extern "c" fn sem_init(sem: *c.sem_t, pshared: c_int, value: c_uint) c_int;
pub extern "c" fn sem_destroy(sem: *c.sem_t) c_int;
pub extern "c" fn sem_open(name: [*:0]const u8, flag: c_int, mode: c.mode_t, value: c_uint) *c.sem_t;
pub extern "c" fn sem_close(sem: *c.sem_t) c_int;
pub extern "c" fn sem_post(sem: *c.sem_t) c_int;
pub extern "c" fn sem_wait(sem: *c.sem_t) c_int;
pub extern "c" fn sem_trywait(sem: *c.sem_t) c_int;
pub extern "c" fn sem_timedwait(sem: *c.sem_t, abs_timeout: *const c.timespec) c_int;
pub extern "c" fn sem_getvalue(sem: *c.sem_t, sval: *c_int) c_int;

pub extern "c" fn shm_open(name: [*:0]const u8, flag: c_int, mode: c.mode_t) c_int;
pub extern "c" fn shm_unlink(name: [*:0]const u8) c_int;

pub extern "c" fn kqueue() c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: [*]const c.Kevent,
    nchanges: c_int,
    eventlist: [*]c.Kevent,
    nevents: c_int,
    timeout: ?*const c.timespec,
) c_int;

pub extern "c" fn port_create() c.port_t;
pub extern "c" fn port_associate(
    port: c.port_t,
    source: u32,
    object: usize,
    events: u32,
    user_var: ?*anyopaque,
) c_int;
pub extern "c" fn port_dissociate(port: c.port_t, source: u32, object: usize) c_int;
pub extern "c" fn port_send(port: c.port_t, events: u32, user_var: ?*anyopaque) c_int;
pub extern "c" fn port_sendn(
    ports: [*]c.port_t,
    errors: []u32,
    num_ports: u32,
    events: u32,
    user_var: ?*anyopaque,
) c_int;
pub extern "c" fn port_get(port: c.port_t, event: *c.port_event, timeout: ?*c.timespec) c_int;
pub extern "c" fn port_getn(
    port: c.port_t,
    event_list: []c.port_event,
    max_events: u32,
    events_retrieved: *u32,
    timeout: ?*c.timespec,
) c_int;
pub extern "c" fn port_alert(port: c.port_t, flags: u32, events: u32, user_var: ?*anyopaque) c_int;

pub extern "c" fn getaddrinfo(
    noalias node: ?[*:0]const u8,
    noalias service: ?[*:0]const u8,
    noalias hints: ?*const c.addrinfo,
    /// On Linux, `res` will not be modified on error and `freeaddrinfo` will
    /// potentially crash if you pass it an undefined pointer
    noalias res: *?*c.addrinfo,
) c.EAI;

pub extern "c" fn freeaddrinfo(res: *c.addrinfo) void;

pub extern "c" fn getnameinfo(
    noalias addr: *const c.sockaddr,
    addrlen: c.socklen_t,
    noalias host: [*]u8,
    hostlen: c.socklen_t,
    noalias serv: [*]u8,
    servlen: c.socklen_t,
    flags: u32,
) c.EAI;

pub extern "c" fn gai_strerror(errcode: c.EAI) [*:0]const u8;

pub extern "c" fn poll(fds: [*]c.pollfd, nfds: c.nfds_t, timeout: c_int) c_int;
pub extern "c" fn ppoll(fds: [*]c.pollfd, nfds: c.nfds_t, timeout: ?*const c.timespec, sigmask: ?*const c.sigset_t) c_int;

pub extern "c" fn dn_expand(
    msg: [*:0]const u8,
    eomorig: [*:0]const u8,
    comp_dn: [*:0]const u8,
    exp_dn: [*:0]u8,
    length: c_int,
) c_int;

pub const PTHREAD_MUTEX_INITIALIZER = pthread_mutex_t{};
pub extern "c" fn pthread_mutex_lock(mutex: *pthread_mutex_t) c.E;
pub extern "c" fn pthread_mutex_unlock(mutex: *pthread_mutex_t) c.E;
pub extern "c" fn pthread_mutex_trylock(mutex: *pthread_mutex_t) c.E;
pub extern "c" fn pthread_mutex_destroy(mutex: *pthread_mutex_t) c.E;

pub const PTHREAD_COND_INITIALIZER = pthread_cond_t{};
pub extern "c" fn pthread_cond_wait(noalias cond: *pthread_cond_t, noalias mutex: *pthread_mutex_t) c.E;
pub extern "c" fn pthread_cond_timedwait(noalias cond: *pthread_cond_t, noalias mutex: *pthread_mutex_t, noalias abstime: *const c.timespec) c.E;
pub extern "c" fn pthread_cond_signal(cond: *pthread_cond_t) c.E;
pub extern "c" fn pthread_cond_broadcast(cond: *pthread_cond_t) c.E;
pub extern "c" fn pthread_cond_destroy(cond: *pthread_cond_t) c.E;

pub extern "c" fn pthread_rwlock_destroy(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_rdlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_wrlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_tryrdlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_trywrlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;
pub extern "c" fn pthread_rwlock_unlock(rwl: *c.pthread_rwlock_t) callconv(.C) c.E;

pub const pthread_t = *opaque {};
pub const FILE = opaque {};

pub extern "c" fn dlopen(path: [*:0]const u8, mode: c_int) ?*anyopaque;
pub extern "c" fn dlclose(handle: *anyopaque) c_int;
pub extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*:0]const u8) ?*anyopaque;
pub extern "c" fn dlerror() ?[*:0]u8;

pub extern "c" fn sync() void;
pub extern "c" fn syncfs(fd: c_int) c_int;
pub extern "c" fn fsync(fd: c_int) c_int;
pub extern "c" fn fdatasync(fd: c_int) c_int;

pub extern "c" fn prctl(option: c_int, ...) c_int;

pub extern "c" fn getrlimit(resource: c.rlimit_resource, rlim: *c.rlimit) c_int;
pub extern "c" fn setrlimit(resource: c.rlimit_resource, rlim: *const c.rlimit) c_int;

pub extern "c" fn fmemopen(noalias buf: ?*anyopaque, size: usize, noalias mode: [*:0]const u8) ?*FILE;

pub extern "c" fn syslog(priority: c_int, message: [*:0]const u8, ...) void;
pub extern "c" fn openlog(ident: [*:0]const u8, logopt: c_int, facility: c_int) void;
pub extern "c" fn closelog() void;
pub extern "c" fn setlogmask(maskpri: c_int) c_int;

pub extern "c" fn if_nametoindex([*:0]const u8) c_int;

pub const getcontext = if (builtin.target.isAndroid())
    @compileError("android bionic libc does not implement getcontext")
else if (native_os == .linux and builtin.target.isMusl())
    linux.getcontext
else
    struct {
        extern fn getcontext(ucp: *std.posix.ucontext_t) c_int;
    }.getcontext;

pub const max_align_t = if (native_abi == .msvc)
    f64
else if (builtin.target.isDarwin())
    c_longdouble
else
    extern struct {
        a: c_longlong,
        b: c_longdouble,
    };

const private = struct {
    extern "c" fn clock_getres(clk_id: c_int, tp: *c.timespec) c_int;
    extern "c" fn clock_gettime(clk_id: c_int, tp: *c.timespec) c_int;
    extern "c" fn fstat(fd: c.fd_t, buf: *c.Stat) c_int;
    extern "c" fn fstatat(dirfd: c.fd_t, path: [*:0]const u8, buf: *c.Stat, flag: u32) c_int;
    extern "c" fn getdirentries(fd: c.fd_t, buf_ptr: [*]u8, nbytes: usize, basep: *i64) isize;
    extern "c" fn getrusage(who: c_int, usage: *c.rusage) c_int;
    extern "c" fn gettimeofday(noalias tv: ?*c.timeval, noalias tz: ?*c.timezone) c_int;
    extern "c" fn msync(addr: *align(page_size) const anyopaque, len: usize, flags: c_int) c_int;
    extern "c" fn nanosleep(rqtp: *const c.timespec, rmtp: ?*c.timespec) c_int;
    extern "c" fn readdir(dir: *c.DIR) ?*c.dirent;
    extern "c" fn realpath(noalias file_name: [*:0]const u8, noalias resolved_name: [*]u8) ?[*:0]u8;
    extern "c" fn sched_yield() c_int;
    extern "c" fn sigaction(sig: c_int, noalias act: ?*const c.Sigaction, noalias oact: ?*c.Sigaction) c_int;
    extern "c" fn sigfillset(set: ?*c.sigset_t) void;
    extern "c" fn sigprocmask(how: c_int, noalias set: ?*const c.sigset_t, noalias oset: ?*c.sigset_t) c_int;
    extern "c" fn socket(domain: c_uint, sock_type: c_uint, protocol: c_uint) c_int;
    extern "c" fn stat(noalias path: [*:0]const u8, noalias buf: *c.Stat) c_int;

    /// macos modernized symbols.
    /// x86_64 links to $INODE64 suffix for 64-bit support.
    /// Note these are not necessary on aarch64.
    extern "c" fn @"fstat$INODE64"(fd: c.fd_t, buf: *c.Stat) c_int;
    extern "c" fn @"fstatat$INODE64"(dirfd: c.fd_t, path: [*:0]const u8, buf: *c.Stat, flag: u32) c_int;
    extern "c" fn @"readdir$INODE64"(dir: *c.DIR) ?*c.dirent;
    extern "c" fn @"stat$INODE64"(noalias path: [*:0]const u8, noalias buf: *c.Stat) c_int;

    /// macos modernized symbols.
    extern "c" fn @"realpath$DARWIN_EXTSN"(noalias file_name: [*:0]const u8, noalias resolved_name: [*]u8) ?[*:0]u8;
    extern "c" fn __getdirentries64(fd: c.fd_t, buf_ptr: [*]u8, buf_len: usize, basep: *i64) isize;

    /// netbsd modernized symbols.
    extern "c" fn __clock_getres50(clk_id: c_int, tp: *c.timespec) c_int;
    extern "c" fn __clock_gettime50(clk_id: c_int, tp: *c.timespec) c_int;
    extern "c" fn __fstat50(fd: c.fd_t, buf: *c.Stat) c_int;
    extern "c" fn __getrusage50(who: c_int, usage: *c.rusage) c_int;
    extern "c" fn __gettimeofday50(noalias tv: ?*c.timeval, noalias tz: ?*c.timezone) c_int;
    extern "c" fn __libc_thr_yield() c_int;
    extern "c" fn __msync13(addr: *align(std.mem.page_size) const anyopaque, len: usize, flags: c_int) c_int;
    extern "c" fn __nanosleep50(rqtp: *const c.timespec, rmtp: ?*c.timespec) c_int;
    extern "c" fn __sigaction14(sig: c_int, noalias act: ?*const c.Sigaction, noalias oact: ?*c.Sigaction) c_int;
    extern "c" fn __sigfillset14(set: ?*c.sigset_t) void;
    extern "c" fn __sigprocmask14(how: c_int, noalias set: ?*const c.sigset_t, noalias oset: ?*c.sigset_t) c_int;
    extern "c" fn __socket30(domain: c_uint, sock_type: c_uint, protocol: c_uint) c_int;
    extern "c" fn __stat50(path: [*:0]const u8, buf: *c.Stat) c_int;
};
