const std = @import("../std.zig");
const wasi = std.os.wasi;
const FDFLAG = wasi.FDFLAG;

extern threadlocal var errno: c_int;

pub fn _errno() *c_int {
    return &errno;
}

pub const fd_t = wasi.fd_t;
pub const pid_t = c_int;
pub const uid_t = u32;
pub const gid_t = u32;
pub const off_t = i64;
pub const ino_t = wasi.ino_t;
pub const mode_t = wasi.mode_t;
pub const time_t = wasi.time_t;
pub const timespec = wasi.timespec;
pub const STDERR_FILENO = wasi.STDERR_FILENO;
pub const STDIN_FILENO = wasi.STDIN_FILENO;
pub const STDOUT_FILENO = wasi.STDOUT_FILENO;
pub const E = wasi.E;
pub const CLOCK = wasi.CLOCK;
pub const S = wasi.S;
pub const IOV_MAX = wasi.IOV_MAX;
pub const AT = wasi.AT;

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

    atimesec: time_t,
    atimensec: isize,
    mtimesec: time_t,
    mtimensec: isize,
    ctimesec: time_t,
    ctimensec: isize,

    pub fn atime(self: @This()) timespec {
        return timespec{
            .tv_sec = self.atimesec,
            .tv_nsec = self.atimensec,
        };
    }

    pub fn mtime(self: @This()) timespec {
        return timespec{
            .tv_sec = self.mtimesec,
            .tv_nsec = self.mtimensec,
        };
    }

    pub fn ctime(self: @This()) timespec {
        return timespec{
            .tv_sec = self.ctimesec,
            .tv_nsec = self.ctimensec,
        };
    }
};

/// Derived from
/// https://github.com/WebAssembly/wasi-libc/blob/main/expected/wasm32-wasi/predefined-macros.txt
pub const O = struct {
    pub const ACCMODE = (EXEC | RDWR | SEARCH);
    pub const APPEND = FDFLAG.APPEND;
    pub const CLOEXEC = (0);
    pub const CREAT = ((1 << 0) << 12); // = __WASI_OFLAGS_CREAT << 12
    pub const DIRECTORY = ((1 << 1) << 12); // = __WASI_OFLAGS_DIRECTORY << 12
    pub const DSYNC = FDFLAG.DSYNC;
    pub const EXCL = ((1 << 2) << 12); // = __WASI_OFLAGS_EXCL << 12
    pub const EXEC = (0x02000000);
    pub const NOCTTY = (0);
    pub const NOFOLLOW = (0x01000000);
    pub const NONBLOCK = (1 << FDFLAG.NONBLOCK);
    pub const RDONLY = (0x04000000);
    pub const RDWR = (RDONLY | WRONLY);
    pub const RSYNC = (1 << FDFLAG.RSYNC);
    pub const SEARCH = (0x08000000);
    pub const SYNC = (1 << FDFLAG.SYNC);
    pub const TRUNC = ((1 << 3) << 12); // = __WASI_OFLAGS_TRUNC << 12
    pub const TTY_INIT = (0);
    pub const WRONLY = (0x10000000);
};

pub const SEEK = struct {
    pub const SET: wasi.whence_t = .SET;
    pub const CUR: wasi.whence_t = .CUR;
    pub const END: wasi.whence_t = .END;
};
