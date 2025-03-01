//! wasi_snapshot_preview1 spec available (in witx format) here:
//! * typenames -- https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/witx/typenames.witx
//! * module -- https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/witx/wasi_snapshot_preview1.witx
//! Note that libc API does *not* go in this file. wasi libc API goes into std/c.zig instead.
const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;

comptime {
    if (builtin.os.tag == .wasi) {
        assert(@alignOf(i8) == 1);
        assert(@alignOf(u8) == 1);
        assert(@alignOf(i16) == 2);
        assert(@alignOf(u16) == 2);
        assert(@alignOf(i32) == 4);
        assert(@alignOf(u32) == 4);
        assert(@alignOf(i64) == 8);
        assert(@alignOf(u64) == 8);
    }
}

pub const iovec_t = std.posix.iovec;
pub const ciovec_t = std.posix.iovec_const;

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
pub extern "wasi_snapshot_preview1" fn sock_recv(sock: fd_t, ri_data: [*]iovec_t, ri_data_len: usize, ri_flags: riflags_t, ro_datalen: *usize, ro_flags: *roflags_t) errno_t;
pub extern "wasi_snapshot_preview1" fn sock_send(sock: fd_t, si_data: [*]const ciovec_t, si_data_len: usize, si_flags: siflags_t, so_datalen: *usize) errno_t;
pub extern "wasi_snapshot_preview1" fn sock_shutdown(sock: fd_t, how: sdflags_t) errno_t;

// As defined in the wasi_snapshot_preview1 spec file:
// https://github.com/WebAssembly/WASI/blob/master/phases/snapshot/witx/typenames.witx
pub const advice_t = enum(u8) {
    NORMAL = 0,
    SEQUENTIAL = 1,
    RANDOM = 2,
    WILLNEED = 3,
    DONTNEED = 4,
    NOREUSE = 5,
};

pub const clockid_t = enum(u32) {
    REALTIME = 0,
    MONOTONIC = 1,
    PROCESS_CPUTIME_ID = 2,
    THREAD_CPUTIME_ID = 3,
};

pub const device_t = u64;

pub const dircookie_t = u64;
pub const DIRCOOKIE_START: dircookie_t = 0;

pub const dirnamlen_t = u32;

pub const dirent_t = extern struct {
    next: dircookie_t,
    ino: inode_t,
    namlen: dirnamlen_t,
    type: filetype_t,
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

pub const eventtype_t = enum(u8) {
    CLOCK = 0,
    FD_READ = 1,
    FD_WRITE = 2,
};

pub const exitcode_t = u32;

pub const fd_t = i32;

pub const fdflags_t = packed struct(u16) {
    APPEND: bool = false,
    DSYNC: bool = false,
    NONBLOCK: bool = false,
    RSYNC: bool = false,
    SYNC: bool = false,
    _: u11 = 0,
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
};

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

pub const fstflags_t = packed struct(u16) {
    ATIM: bool = false,
    ATIM_NOW: bool = false,
    MTIM: bool = false,
    MTIM_NOW: bool = false,
    _: u12 = 0,
};

pub const inode_t = u64;

pub const linkcount_t = u64;

pub const lookupflags_t = packed struct(u32) {
    SYMLINK_FOLLOW: bool = false,
    _: u31 = 0,
};

pub const oflags_t = packed struct(u16) {
    CREAT: bool = false,
    DIRECTORY: bool = false,
    EXCL: bool = false,
    TRUNC: bool = false,
    _: u12 = 0,
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

pub const rights_t = packed struct(u64) {
    /// The right to invoke fd_datasync. If PATH_OPEN is set, includes the right to invoke
    /// path_open with fdflags_t.dsync.
    FD_DATASYNC: bool = false,
    /// The right to invoke fd_read and sock_recv. If FD_SEEK is set, includes the right to invoke
    /// fd_pread.
    FD_READ: bool = false,
    /// The right to invoke fd_seek. This flag implies FD_TELL.
    FD_SEEK: bool = false,
    /// The right to invoke fd_fdstat_set_flags.
    FD_FDSTAT_SET_FLAGS: bool = false,
    /// The right to invoke fd_sync. If PATH_OPEN is set, includes the right to invoke path_open
    /// with fdflags_t.RSYNC and fdflags_t.DSYNC.
    FD_SYNC: bool = false,
    /// The right to invoke fd_seek in such a way that the file offset remains unaltered (i.e.
    /// whence_t.CUR with offset zero), or to invoke fd_tell.
    FD_TELL: bool = false,
    /// The right to invoke fd_write and sock_send. If FD_SEEK is set, includes the right to invoke
    /// fd_pwrite.
    FD_WRITE: bool = false,
    /// The right to invoke fd_advise.
    FD_ADVISE: bool = false,
    /// The right to invoke fd_allocate.
    FD_ALLOCATE: bool = false,
    /// The right to invoke path_create_directory.
    PATH_CREATE_DIRECTORY: bool = false,
    /// If PATH_OPEN is set, the right to invoke path_open with oflags_t.CREAT.
    PATH_CREATE_FILE: bool = false,
    /// The right to invoke path_link with the file descriptor as the source directory.
    PATH_LINK_SOURCE: bool = false,
    /// The right to invoke path_link with the file descriptor as the target directory.
    PATH_LINK_TARGET: bool = false,
    /// The right to invoke path_open.
    PATH_OPEN: bool = false,
    /// The right to invoke fd_readdir.
    FD_READDIR: bool = false,
    /// The right to invoke path_readlink.
    PATH_READLINK: bool = false,
    /// The right to invoke path_rename with the file descriptor as the source directory.
    PATH_RENAME_SOURCE: bool = false,
    /// The right to invoke path_rename with the file descriptor as the target directory.
    PATH_RENAME_TARGET: bool = false,
    /// The right to invoke path_filestat_get.
    PATH_FILESTAT_GET: bool = false,
    /// The right to change a file's size. If PATH_OPEN is set, includes the right to invoke
    /// path_open with oflags_t.TRUNC. Note: there is no function named path_filestat_set_size.
    /// This follows POSIX design, which only has ftruncate and does not provide ftruncateat. While
    /// such function would be desirable from the API design perspective, there are virtually no
    /// use cases for it since no code written for POSIX systems would use it. Moreover,
    /// implementing it would require multiple syscalls, leading to inferior performance.
    PATH_FILESTAT_SET_SIZE: bool = false,
    /// The right to invoke path_filestat_set_times.
    PATH_FILESTAT_SET_TIMES: bool = false,
    /// The right to invoke fd_filestat_get.
    FD_FILESTAT_GET: bool = false,
    /// The right to invoke fd_filestat_set_size.
    FD_FILESTAT_SET_SIZE: bool = false,
    /// The right to invoke fd_filestat_set_times.
    FD_FILESTAT_SET_TIMES: bool = false,
    /// The right to invoke path_symlink.
    PATH_SYMLINK: bool = false,
    /// The right to invoke path_remove_directory.
    PATH_REMOVE_DIRECTORY: bool = false,
    /// The right to invoke path_unlink_file.
    PATH_UNLINK_FILE: bool = false,
    /// If FD_READ is set, includes the right to invoke poll_oneoff to subscribe to
    /// eventtype_t.FD_READ. If FD_WRITE is set, includes the right to invoke poll_oneoff to
    /// subscribe to eventtype_t.FD_WRITE.
    POLL_FD_READWRITE: bool = false,
    /// The right to invoke sock_shutdown.
    SOCK_SHUTDOWN: bool = false,
    /// The right to invoke sock_accept.
    SOCK_ACCEPT: bool = false,
    _: u34 = 0,
};

pub const sdflags_t = packed struct(u8) {
    RD: bool = false,
    WR: bool = false,
    _: u6 = 0,
};

pub const siflags_t = u16;

pub const signal_t = enum(u8) {
    NONE = 0,
    HUP = 1,
    INT = 2,
    QUIT = 3,
    ILL = 4,
    TRAP = 5,
    ABRT = 6,
    BUS = 7,
    FPE = 8,
    KILL = 9,
    USR1 = 10,
    SEGV = 11,
    USR2 = 12,
    PIPE = 13,
    ALRM = 14,
    TERM = 15,
    CHLD = 16,
    CONT = 17,
    STOP = 18,
    TSTP = 19,
    TTIN = 20,
    TTOU = 21,
    URG = 22,
    XCPU = 23,
    XFSZ = 24,
    VTALRM = 25,
    PROF = 26,
    WINCH = 27,
    POLL = 28,
    PWR = 29,
    SYS = 30,
};

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

/// Nanoseconds.
pub const timestamp_t = u64;

pub const userdata_t = u64;

pub const whence_t = enum(u8) { SET, CUR, END };
