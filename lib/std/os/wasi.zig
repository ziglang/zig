// wasi_snapshot_preview1 spec available (in witx format) here:
// * typenames -- https://github.com/WebAssembly/WASI/blob/master/phases/snapshot/witx/typenames.witx
// * module -- https://github.com/WebAssembly/WASI/blob/master/phases/snapshot/witx/wasi_snapshot_preview1.witx
const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;

comptime {
    assert(@alignOf(i8) == 1);
    assert(@alignOf(u8) == 1);
    assert(@alignOf(i16) == 2);
    assert(@alignOf(u16) == 2);
    assert(@alignOf(i32) == 4);
    assert(@alignOf(u32) == 4);
    // assert(@alignOf(i64) == 8);
    // assert(@alignOf(u64) == 8);
}

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const iovec_t = std.os.iovec;
pub const ciovec_t = std.os.iovec_const;

pub extern "wasi_snapshot_preview1" fn args_get(argv: [*][*:0]u8, argv_buf: [*]u8) errno_t;
pub extern "wasi_snapshot_preview1" fn args_sizes_get(argc: *usize, argv_buf_size: *usize) errno_t;

pub extern "wasi_snapshot_preview1" fn clock_res_get(clock_id: clockid_t, resolution: *timestamp_t) errno_t;
pub extern "wasi_snapshot_preview1" fn clock_time_get(clock_id: clockid_t, precision: timestamp_t, timestamp: *timestamp_t) errno_t;

pub extern "wasi_snapshot_preview1" fn environ_get(environ: [*][*:0]u8, environ_buf: [*]u8) errno_t;
pub extern "wasi_snapshot_preview1" fn environ_sizes_get(environ_count: *usize, environ_buf_size: *usize) errno_t;

pub extern "wasi_snapshot_preview1" fn fd_advise(fd: fd_t, offset: filesize_t, len: filesize_t, advice: advice_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_allocate(fd: fd_t, offset: filesize_t, len: filesize_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_close(fd: fd_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_datasync(fd: fd_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_pread(fd: fd_t, iovs: [*]const iovec_t, iovs_len: usize, offset: filesize_t, nread: *usize) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_pwrite(fd: fd_t, iovs: [*]const ciovec_t, iovs_len: usize, offset: filesize_t, nwritten: *usize) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_read(fd: fd_t, iovs: [*]const iovec_t, iovs_len: usize, nread: *usize) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_readdir(fd: fd_t, buf: [*]u8, buf_len: usize, cookie: dircookie_t, bufused: *usize) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_renumber(from: fd_t, to: fd_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_seek(fd: fd_t, offset: filedelta_t, whence: whence_t, newoffset: *filesize_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_sync(fd: fd_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_tell(fd: fd_t, newoffset: *filesize_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_write(fd: fd_t, iovs: [*]const ciovec_t, iovs_len: usize, nwritten: *usize) errno_t;

pub extern "wasi_snapshot_preview1" fn fd_fdstat_get(fd: fd_t, buf: *fdstat_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_fdstat_set_flags(fd: fd_t, flags: fdflags_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_fdstat_set_rights(fd: fd_t, fs_rights_base: rights_t, fs_rights_inheriting: rights_t) errno_t;

pub extern "wasi_snapshot_preview1" fn fd_filestat_get(fd: fd_t, buf: *filestat_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_filestat_set_size(fd: fd_t, st_size: filesize_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_filestat_set_times(fd: fd_t, st_atim: timestamp_t, st_mtim: timestamp_t, fstflags: fstflags_t) errno_t;

pub extern "wasi_snapshot_preview1" fn fd_prestat_get(fd: fd_t, buf: *prestat_t) errno_t;
pub extern "wasi_snapshot_preview1" fn fd_prestat_dir_name(fd: fd_t, path: [*]u8, path_len: usize) errno_t;

pub extern "wasi_snapshot_preview1" fn path_create_directory(fd: fd_t, path: [*]const u8, path_len: usize) errno_t;
pub extern "wasi_snapshot_preview1" fn path_filestat_get(fd: fd_t, flags: lookupflags_t, path: [*]const u8, path_len: usize, buf: *filestat_t) errno_t;
pub extern "wasi_snapshot_preview1" fn path_filestat_set_times(fd: fd_t, flags: lookupflags_t, path: [*]const u8, path_len: usize, st_atim: timestamp_t, st_mtim: timestamp_t, fstflags: fstflags_t) errno_t;
pub extern "wasi_snapshot_preview1" fn path_link(old_fd: fd_t, old_flags: lookupflags_t, old_path: [*]const u8, old_path_len: usize, new_fd: fd_t, new_path: [*]const u8, new_path_len: usize) errno_t;
pub extern "wasi_snapshot_preview1" fn path_open(dirfd: fd_t, dirflags: lookupflags_t, path: [*]const u8, path_len: usize, oflags: oflags_t, fs_rights_base: rights_t, fs_rights_inheriting: rights_t, fs_flags: fdflags_t, fd: *fd_t) errno_t;
pub extern "wasi_snapshot_preview1" fn path_readlink(fd: fd_t, path: [*]const u8, path_len: usize, buf: [*]u8, buf_len: usize, bufused: *usize) errno_t;
pub extern "wasi_snapshot_preview1" fn path_remove_directory(fd: fd_t, path: [*]const u8, path_len: usize) errno_t;
pub extern "wasi_snapshot_preview1" fn path_rename(old_fd: fd_t, old_path: [*]const u8, old_path_len: usize, new_fd: fd_t, new_path: [*]const u8, new_path_len: usize) errno_t;
pub extern "wasi_snapshot_preview1" fn path_symlink(old_path: [*]const u8, old_path_len: usize, fd: fd_t, new_path: [*]const u8, new_path_len: usize) errno_t;
pub extern "wasi_snapshot_preview1" fn path_unlink_file(fd: fd_t, path: [*]const u8, path_len: usize) errno_t;

pub extern "wasi_snapshot_preview1" fn poll_oneoff(in: *const subscription_t, out: *event_t, nsubscriptions: usize, nevents: *usize) errno_t;

pub extern "wasi_snapshot_preview1" fn proc_exit(rval: exitcode_t) noreturn;

pub extern "wasi_snapshot_preview1" fn random_get(buf: [*]u8, buf_len: usize) errno_t;

pub extern "wasi_snapshot_preview1" fn sched_yield() errno_t;

pub extern "wasi_snapshot_preview1" fn sock_accept(sock: fd_t, flags: fdflags_t, result_fd: *fd_t) errno_t;
pub extern "wasi_snapshot_preview1" fn sock_recv(sock: fd_t, ri_data: *const iovec_t, ri_data_len: usize, ri_flags: riflags_t, ro_datalen: *usize, ro_flags: *roflags_t) errno_t;
pub extern "wasi_snapshot_preview1" fn sock_send(sock: fd_t, si_data: *const ciovec_t, si_data_len: usize, si_flags: siflags_t, so_datalen: *usize) errno_t;
pub extern "wasi_snapshot_preview1" fn sock_shutdown(sock: fd_t, how: sdflags_t) errno_t;

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: errno_t) errno_t {
    return r;
}

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const mode_t = u32;

pub const time_t = i64; // match https://github.com/CraneStation/wasi-libc

pub const timespec = extern struct {
    tv_sec: time_t,
    tv_nsec: isize,

    pub fn fromTimestamp(tm: timestamp_t) timespec {
        const tv_sec: timestamp_t = tm / 1_000_000_000;
        const tv_nsec = tm - tv_sec * 1_000_000_000;
        return timespec{
            .tv_sec = @as(time_t, @intCast(tv_sec)),
            .tv_nsec = @as(isize, @intCast(tv_nsec)),
        };
    }

    pub fn toTimestamp(ts: timespec) timestamp_t {
        const tm = @as(timestamp_t, @intCast(ts.tv_sec * 1_000_000_000)) + @as(timestamp_t, @intCast(ts.tv_nsec));
        return tm;
    }
};

pub const Stat = struct {
    dev: device_t,
    ino: inode_t,
    mode: mode_t,
    filetype: filetype_t,
    nlink: linkcount_t,
    size: filesize_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,

    const Self = @This();

    pub fn fromFilestat(stat: filestat_t) Self {
        return Self{
            .dev = stat.dev,
            .ino = stat.ino,
            .mode = 0,
            .filetype = stat.filetype,
            .nlink = stat.nlink,
            .size = stat.size,
            .atim = stat.atime(),
            .mtim = stat.mtime(),
            .ctim = stat.ctime(),
        };
    }

    pub fn atime(self: Self) timespec {
        return self.atim;
    }

    pub fn mtime(self: Self) timespec {
        return self.mtim;
    }

    pub fn ctime(self: Self) timespec {
        return self.ctim;
    }
};

pub const IOV_MAX = 1024;

pub const AT = struct {
    pub const REMOVEDIR: u32 = 0x4;
    /// When linking libc, we follow their convention and use -2 for current working directory.
    /// However, without libc, Zig does a different convention: it assumes the
    /// current working directory is the first preopen. This behavior can be
    /// overridden with a public function called `wasi_cwd` in the root source
    /// file.
    pub const FDCWD: fd_t = if (builtin.link_libc) -2 else 3;
};

// As defined in the wasi_snapshot_preview1 spec file:
// https://github.com/WebAssembly/WASI/blob/master/phases/snapshot/witx/typenames.witx
pub const advice_t = u8;
pub const ADVICE_NORMAL: advice_t = 0;
pub const ADVICE_SEQUENTIAL: advice_t = 1;
pub const ADVICE_RANDOM: advice_t = 2;
pub const ADVICE_WILLNEED: advice_t = 3;
pub const ADVICE_DONTNEED: advice_t = 4;
pub const ADVICE_NOREUSE: advice_t = 5;

pub const clockid_t = u32;
pub const CLOCK = struct {
    pub const REALTIME: clockid_t = 0;
    pub const MONOTONIC: clockid_t = 1;
    pub const PROCESS_CPUTIME_ID: clockid_t = 2;
    pub const THREAD_CPUTIME_ID: clockid_t = 3;
};

pub const device_t = u64;

pub const dircookie_t = u64;
pub const DIRCOOKIE_START: dircookie_t = 0;

pub const dirnamlen_t = u32;

pub const dirent_t = extern struct {
    d_next: dircookie_t,
    d_ino: inode_t,
    d_namlen: dirnamlen_t,
    d_type: filetype_t,
};

pub const errno_t = enum(u16) {
    SUCCESS = 0,
    @"2BIG" = 1,
    ACCES = 2,
    ADDRINUSE = 3,
    ADDRNOTAVAIL = 4,
    AFNOSUPPORT = 5,
    /// This is also the error code used for `WOULDBLOCK`.
    AGAIN = 6,
    ALREADY = 7,
    BADF = 8,
    BADMSG = 9,
    BUSY = 10,
    CANCELED = 11,
    CHILD = 12,
    CONNABORTED = 13,
    CONNREFUSED = 14,
    CONNRESET = 15,
    DEADLK = 16,
    DESTADDRREQ = 17,
    DOM = 18,
    DQUOT = 19,
    EXIST = 20,
    FAULT = 21,
    FBIG = 22,
    HOSTUNREACH = 23,
    IDRM = 24,
    ILSEQ = 25,
    INPROGRESS = 26,
    INTR = 27,
    INVAL = 28,
    IO = 29,
    ISCONN = 30,
    ISDIR = 31,
    LOOP = 32,
    MFILE = 33,
    MLINK = 34,
    MSGSIZE = 35,
    MULTIHOP = 36,
    NAMETOOLONG = 37,
    NETDOWN = 38,
    NETRESET = 39,
    NETUNREACH = 40,
    NFILE = 41,
    NOBUFS = 42,
    NODEV = 43,
    NOENT = 44,
    NOEXEC = 45,
    NOLCK = 46,
    NOLINK = 47,
    NOMEM = 48,
    NOMSG = 49,
    NOPROTOOPT = 50,
    NOSPC = 51,
    NOSYS = 52,
    NOTCONN = 53,
    NOTDIR = 54,
    NOTEMPTY = 55,
    NOTRECOVERABLE = 56,
    NOTSOCK = 57,
    /// This is also the code used for `NOTSUP`.
    OPNOTSUPP = 58,
    NOTTY = 59,
    NXIO = 60,
    OVERFLOW = 61,
    OWNERDEAD = 62,
    PERM = 63,
    PIPE = 64,
    PROTO = 65,
    PROTONOSUPPORT = 66,
    PROTOTYPE = 67,
    RANGE = 68,
    ROFS = 69,
    SPIPE = 70,
    SRCH = 71,
    STALE = 72,
    TIMEDOUT = 73,
    TXTBSY = 74,
    XDEV = 75,
    NOTCAPABLE = 76,
    _,
};
pub const E = errno_t;

pub const event_t = extern struct {
    userdata: userdata_t,
    @"error": errno_t,
    type: eventtype_t,
    fd_readwrite: eventfdreadwrite_t,
};

pub const eventfdreadwrite_t = extern struct {
    nbytes: filesize_t,
    flags: eventrwflags_t,
};

pub const eventrwflags_t = u16;
pub const EVENT_FD_READWRITE_HANGUP: eventrwflags_t = 0x0001;

pub const eventtype_t = u8;
pub const EVENTTYPE_CLOCK: eventtype_t = 0;
pub const EVENTTYPE_FD_READ: eventtype_t = 1;
pub const EVENTTYPE_FD_WRITE: eventtype_t = 2;

pub const exitcode_t = u32;

pub const fd_t = i32;

pub const fdflags_t = u16;
pub const FDFLAG = struct {
    pub const APPEND: fdflags_t = 0x0001;
    pub const DSYNC: fdflags_t = 0x0002;
    pub const NONBLOCK: fdflags_t = 0x0004;
    pub const RSYNC: fdflags_t = 0x0008;
    pub const SYNC: fdflags_t = 0x0010;
};

pub const fdstat_t = extern struct {
    fs_filetype: filetype_t,
    fs_flags: fdflags_t,
    fs_rights_base: rights_t,
    fs_rights_inheriting: rights_t,
};

pub const filedelta_t = i64;

pub const filesize_t = u64;

pub const filestat_t = extern struct {
    dev: device_t,
    ino: inode_t,
    filetype: filetype_t,
    nlink: linkcount_t,
    size: filesize_t,
    atim: timestamp_t,
    mtim: timestamp_t,
    ctim: timestamp_t,

    pub fn atime(self: filestat_t) timespec {
        return timespec.fromTimestamp(self.atim);
    }

    pub fn mtime(self: filestat_t) timespec {
        return timespec.fromTimestamp(self.mtim);
    }

    pub fn ctime(self: filestat_t) timespec {
        return timespec.fromTimestamp(self.ctim);
    }
};

/// Also known as `FILETYPE`.
pub const filetype_t = enum(u8) {
    UNKNOWN,
    BLOCK_DEVICE,
    CHARACTER_DEVICE,
    DIRECTORY,
    REGULAR_FILE,
    SOCKET_DGRAM,
    SOCKET_STREAM,
    SYMBOLIC_LINK,
    _,
};

pub const fstflags_t = u16;
pub const FILESTAT_SET_ATIM: fstflags_t = 0x0001;
pub const FILESTAT_SET_ATIM_NOW: fstflags_t = 0x0002;
pub const FILESTAT_SET_MTIM: fstflags_t = 0x0004;
pub const FILESTAT_SET_MTIM_NOW: fstflags_t = 0x0008;

pub const inode_t = u64;
pub const ino_t = inode_t;

pub const linkcount_t = u64;

pub const lookupflags_t = u32;
pub const LOOKUP_SYMLINK_FOLLOW: lookupflags_t = 0x00000001;

pub const oflags_t = u16;
pub const O = struct {
    pub const CREAT: oflags_t = 0x0001;
    pub const DIRECTORY: oflags_t = 0x0002;
    pub const EXCL: oflags_t = 0x0004;
    pub const TRUNC: oflags_t = 0x0008;
};

pub const preopentype_t = u8;
pub const PREOPENTYPE_DIR: preopentype_t = 0;

pub const prestat_t = extern struct {
    pr_type: preopentype_t,
    u: prestat_u_t,
};

pub const prestat_dir_t = extern struct {
    pr_name_len: usize,
};

pub const prestat_u_t = extern union {
    dir: prestat_dir_t,
};

pub const riflags_t = u16;
pub const roflags_t = u16;

pub const SOCK = struct {
    pub const RECV_PEEK: riflags_t = 0x0001;
    pub const RECV_WAITALL: riflags_t = 0x0002;

    pub const RECV_DATA_TRUNCATED: roflags_t = 0x0001;
};

pub const rights_t = u64;
pub const RIGHT = struct {
    pub const FD_DATASYNC: rights_t = 0x0000000000000001;
    pub const FD_READ: rights_t = 0x0000000000000002;
    pub const FD_SEEK: rights_t = 0x0000000000000004;
    pub const FD_FDSTAT_SET_FLAGS: rights_t = 0x0000000000000008;
    pub const FD_SYNC: rights_t = 0x0000000000000010;
    pub const FD_TELL: rights_t = 0x0000000000000020;
    pub const FD_WRITE: rights_t = 0x0000000000000040;
    pub const FD_ADVISE: rights_t = 0x0000000000000080;
    pub const FD_ALLOCATE: rights_t = 0x0000000000000100;
    pub const PATH_CREATE_DIRECTORY: rights_t = 0x0000000000000200;
    pub const PATH_CREATE_FILE: rights_t = 0x0000000000000400;
    pub const PATH_LINK_SOURCE: rights_t = 0x0000000000000800;
    pub const PATH_LINK_TARGET: rights_t = 0x0000000000001000;
    pub const PATH_OPEN: rights_t = 0x0000000000002000;
    pub const FD_READDIR: rights_t = 0x0000000000004000;
    pub const PATH_READLINK: rights_t = 0x0000000000008000;
    pub const PATH_RENAME_SOURCE: rights_t = 0x0000000000010000;
    pub const PATH_RENAME_TARGET: rights_t = 0x0000000000020000;
    pub const PATH_FILESTAT_GET: rights_t = 0x0000000000040000;
    pub const PATH_FILESTAT_SET_SIZE: rights_t = 0x0000000000080000;
    pub const PATH_FILESTAT_SET_TIMES: rights_t = 0x0000000000100000;
    pub const FD_FILESTAT_GET: rights_t = 0x0000000000200000;
    pub const FD_FILESTAT_SET_SIZE: rights_t = 0x0000000000400000;
    pub const FD_FILESTAT_SET_TIMES: rights_t = 0x0000000000800000;
    pub const PATH_SYMLINK: rights_t = 0x0000000001000000;
    pub const PATH_REMOVE_DIRECTORY: rights_t = 0x0000000002000000;
    pub const PATH_UNLINK_FILE: rights_t = 0x0000000004000000;
    pub const POLL_FD_READWRITE: rights_t = 0x0000000008000000;
    pub const SOCK_SHUTDOWN: rights_t = 0x0000000010000000;
    pub const SOCK_ACCEPT: rights_t = 0x0000000020000000;
    pub const ALL: rights_t = FD_DATASYNC |
        FD_READ |
        FD_SEEK |
        FD_FDSTAT_SET_FLAGS |
        FD_SYNC |
        FD_TELL |
        FD_WRITE |
        FD_ADVISE |
        FD_ALLOCATE |
        PATH_CREATE_DIRECTORY |
        PATH_CREATE_FILE |
        PATH_LINK_SOURCE |
        PATH_LINK_TARGET |
        PATH_OPEN |
        FD_READDIR |
        PATH_READLINK |
        PATH_RENAME_SOURCE |
        PATH_RENAME_TARGET |
        PATH_FILESTAT_GET |
        PATH_FILESTAT_SET_SIZE |
        PATH_FILESTAT_SET_TIMES |
        FD_FILESTAT_GET |
        FD_FILESTAT_SET_SIZE |
        FD_FILESTAT_SET_TIMES |
        PATH_SYMLINK |
        PATH_REMOVE_DIRECTORY |
        PATH_UNLINK_FILE |
        POLL_FD_READWRITE |
        SOCK_SHUTDOWN |
        SOCK_ACCEPT;
};

pub const sdflags_t = u8;
pub const SHUT = struct {
    pub const RD: sdflags_t = 0x01;
    pub const WR: sdflags_t = 0x02;
};

pub const siflags_t = u16;

pub const signal_t = u8;
pub const SIGNONE: signal_t = 0;
pub const SIGHUP: signal_t = 1;
pub const SIGINT: signal_t = 2;
pub const SIGQUIT: signal_t = 3;
pub const SIGILL: signal_t = 4;
pub const SIGTRAP: signal_t = 5;
pub const SIGABRT: signal_t = 6;
pub const SIGBUS: signal_t = 7;
pub const SIGFPE: signal_t = 8;
pub const SIGKILL: signal_t = 9;
pub const SIGUSR1: signal_t = 10;
pub const SIGSEGV: signal_t = 11;
pub const SIGUSR2: signal_t = 12;
pub const SIGPIPE: signal_t = 13;
pub const SIGALRM: signal_t = 14;
pub const SIGTERM: signal_t = 15;
pub const SIGCHLD: signal_t = 16;
pub const SIGCONT: signal_t = 17;
pub const SIGSTOP: signal_t = 18;
pub const SIGTSTP: signal_t = 19;
pub const SIGTTIN: signal_t = 20;
pub const SIGTTOU: signal_t = 21;
pub const SIGURG: signal_t = 22;
pub const SIGXCPU: signal_t = 23;
pub const SIGXFSZ: signal_t = 24;
pub const SIGVTALRM: signal_t = 25;
pub const SIGPROF: signal_t = 26;
pub const SIGWINCH: signal_t = 27;
pub const SIGPOLL: signal_t = 28;
pub const SIGPWR: signal_t = 29;
pub const SIGSYS: signal_t = 30;

pub const subclockflags_t = u16;
pub const SUBSCRIPTION_CLOCK_ABSTIME: subclockflags_t = 0x0001;

pub const subscription_t = extern struct {
    userdata: userdata_t,
    u: subscription_u_t,
};

pub const subscription_clock_t = extern struct {
    id: clockid_t,
    timeout: timestamp_t,
    precision: timestamp_t,
    flags: subclockflags_t,
};

pub const subscription_fd_readwrite_t = extern struct {
    fd: fd_t,
};

pub const subscription_u_t = extern struct {
    tag: eventtype_t,
    u: subscription_u_u_t,
};

pub const subscription_u_u_t = extern union {
    clock: subscription_clock_t,
    fd_read: subscription_fd_readwrite_t,
    fd_write: subscription_fd_readwrite_t,
};

pub const timestamp_t = u64;

pub const userdata_t = u64;

/// Also known as `WHENCE`.
pub const whence_t = enum(u8) { SET, CUR, END };

pub const S = struct {
    pub const IEXEC = @compileError("TODO audit this");
    pub const IFBLK = 0x6000;
    pub const IFCHR = 0x2000;
    pub const IFDIR = 0x4000;
    pub const IFIFO = 0xc000;
    pub const IFLNK = 0xa000;
    pub const IFMT = IFBLK | IFCHR | IFDIR | IFIFO | IFLNK | IFREG | IFSOCK;
    pub const IFREG = 0x8000;
    // There's no concept of UNIX domain socket but we define this value here in order to line with other OSes.
    pub const IFSOCK = 0x1;
};

pub const LOCK = struct {
    pub const SH = 0x1;
    pub const EX = 0x2;
    pub const NB = 0x4;
    pub const UN = 0x8;
};
