const std = @import("../std.zig");
const wasi = std.os.wasi;
const FDFLAG = wasi.FDFLAG;

extern threadlocal var errno: c_int;

pub fn _errno() *c_int {
    return &errno;
}

pub const AT = wasi.AT;
pub const CLOCK = wasi.CLOCK;
pub const E = wasi.E;
pub const IOV_MAX = wasi.IOV_MAX;
pub const LOCK = wasi.LOCK;
pub const S = wasi.S;
pub const STDERR_FILENO = wasi.STDERR_FILENO;
pub const STDIN_FILENO = wasi.STDIN_FILENO;
pub const STDOUT_FILENO = wasi.STDOUT_FILENO;
pub const fd_t = wasi.fd_t;
pub const pid_t = c_int;
pub const uid_t = u32;
pub const gid_t = u32;
pub const off_t = i64;
pub const ino_t = wasi.ino_t;
pub const mode_t = wasi.mode_t;
pub const time_t = wasi.time_t;
pub const timespec = wasi.timespec;

pub const Stat = extern struct {
    dev: i32,
    ino: ino_t,
    nlink: u64,

    mode: mode_t,
    uid: uid_t,
    gid: gid_t,
    __pad0: isize,
    rdev: i32,
    size: off_t,
    blksize: i32,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,

    pub fn atime(self: @This()) timespec {
        return self.atim;
    }

    pub fn mtime(self: @This()) timespec {
        return self.mtim;
    }

    pub fn ctime(self: @This()) timespec {
        return self.ctim;
    }
};

/// Derived from
/// https://github.com/WebAssembly/wasi-libc/blob/main/expected/wasm32-wasi/predefined-macros.txt
pub const O = struct {
    pub const ACCMODE = (EXEC | RDWR | SEARCH);
    pub const APPEND = @as(u32, FDFLAG.APPEND);
    pub const CLOEXEC = (0);
    pub const CREAT = ((1 << 0) << 12); // = __WASI_OFLAGS_CREAT << 12
    pub const DIRECTORY = ((1 << 1) << 12); // = __WASI_OFLAGS_DIRECTORY << 12
    pub const DSYNC = @as(u32, FDFLAG.DSYNC);
    pub const EXCL = ((1 << 2) << 12); // = __WASI_OFLAGS_EXCL << 12
    pub const EXEC = (0x02000000);
    pub const NOCTTY = (0);
    pub const NOFOLLOW = (0x01000000);
    pub const NONBLOCK = @as(u32, FDFLAG.NONBLOCK);
    pub const RDONLY = (0x04000000);
    pub const RDWR = (RDONLY | WRONLY);
    pub const RSYNC = @as(u32, FDFLAG.RSYNC);
    pub const SEARCH = (0x08000000);
    pub const SYNC = @as(u32, FDFLAG.SYNC);
    pub const TRUNC = ((1 << 3) << 12); // = __WASI_OFLAGS_TRUNC << 12
    pub const TTY_INIT = (0);
    pub const WRONLY = (0x10000000);
};

pub const F = struct {
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
};

pub const FD_CLOEXEC = 1;

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const SEEK = struct {
    pub const SET: wasi.whence_t = .SET;
    pub const CUR: wasi.whence_t = .CUR;
    pub const END: wasi.whence_t = .END;
};

pub const nfds_t = usize;

pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const POLL = struct {
    pub const RDNORM = 0x1;
    pub const WRNORM = 0x2;
    pub const IN = RDNORM;
    pub const OUT = WRNORM;
    pub const ERR = 0x1000;
    pub const HUP = 0x2000;
    pub const NVAL = 0x4000;
};
