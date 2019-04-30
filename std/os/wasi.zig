pub use @import("wasi/core.zig");

// Based on https://github.com/CraneStation/wasi-sysroot/blob/wasi/libc-bottom-half/headers/public/wasi/core.h
// and https://github.com/WebAssembly/WASI/blob/master/design/WASI-core.md

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const ESUCCESS = 0;
pub const E2BIG = 1;
pub const EACCES = 2;
pub const EADDRINUSE = 3;
pub const EADDRNOTAVAIL = 4;
pub const EAFNOSUPPORT = 5;
pub const EAGAIN = 6;
pub const EALREADY = 7;
pub const EBADF = 8;
pub const EBADMSG = 9;
pub const EBUSY = 10;
pub const ECANCELED = 11;
pub const ECHILD = 12;
pub const ECONNABORTED = 13;
pub const ECONNREFUSED = 14;
pub const ECONNRESET = 15;
pub const EDEADLK = 16;
pub const EDESTADDRREQ = 17;
pub const EDOM = 18;
pub const EDQUOT = 19;
pub const EEXIST = 20;
pub const EFAULT = 21;
pub const EFBIG = 22;
pub const EHOSTUNREACH = 23;
pub const EIDRM = 24;
pub const EILSEQ = 25;
pub const EINPROGRESS = 26;
pub const EINTR = 27;
pub const EINVAL = 28;
pub const EIO = 29;
pub const EISCONN = 30;
pub const EISDIR = 31;
pub const ELOOP = 32;
pub const EMFILE = 33;
pub const EMLINK = 34;
pub const EMSGSIZE = 35;
pub const EMULTIHOP = 36;
pub const ENAMETOOLONG = 37;
pub const ENETDOWN = 38;
pub const ENETRESET = 39;
pub const ENETUNREACH = 40;
pub const ENFILE = 41;
pub const ENOBUFS = 42;
pub const ENODEV = 43;
pub const ENOENT = 44;
pub const ENOEXEC = 45;
pub const ENOLCK = 46;
pub const ENOLINK = 47;
pub const ENOMEM = 48;
pub const ENOMSG = 49;
pub const ENOPROTOOPT = 50;
pub const ENOSPC = 51;
pub const ENOSYS = 52;
pub const ENOTCONN = 53;
pub const ENOTDIR = 54;
pub const ENOTEMPTY = 55;
pub const ENOTRECOVERABLE = 56;
pub const ENOTSOCK = 57;
pub const ENOTSUP = 58;
pub const ENOTTY = 59;
pub const ENXIO = 60;
pub const EOVERFLOW = 61;
pub const EOWNERDEAD = 62;
pub const EPERM = 63;
pub const EPIPE = 64;
pub const EPROTO = 65;
pub const EPROTONOSUPPORT = 66;
pub const EPROTOTYPE = 67;
pub const ERANGE = 68;
pub const EROFS = 69;
pub const ESPIPE = 70;
pub const ESRCH = 71;
pub const ESTALE = 72;
pub const ETIMEDOUT = 73;
pub const ETXTBSY = 74;
pub const EXDEV = 75;
pub const ENOTCAPABLE = 76;

// TODO: implement this like darwin does
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn exit(status: i32) noreturn {
    proc_exit(@bitCast(exitcode_t, isize(status)));
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    var nwritten: usize = undefined;

    const iovs = []ciovec_t{ciovec_t{
        .buf = buf,
        .buf_len = count,
    }};

    _ = fd_write(@bitCast(fd_t, isize(fd)), &iovs[0], iovs.len, &nwritten);
    return nwritten;
}
