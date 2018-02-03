const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const linux = std.os.linux;
const math = std.math;
const mem = std.mem;
const os = std.os;

use @import("linux_errno.zig");

const arch = switch (builtin.arch) {
    builtin.Arch.x86_64 => @import("linux_x86_64.zig"),
    builtin.Arch.i386 => @import("linux_i386.zig"),
    else => @compileError("unsupported arch"),
};

const Method = enum {
    Syscall,
    Sysctl,
    Urandom,
};

const Callback = fn(&i32, []u8) usize;

const Context = struct {
    syscall: Callback,
    sysctl: Callback,
    urandom: Callback,
};

pub fn getRandomBytes(buf: []u8) usize {
    const ctx = Context {
        .syscall = syscall,
        .sysctl = sysctl,
        .urandom = urandom,
    };
    return withContext(ctx, buf);
}

fn withContext(comptime ctx: Context, buf: []u8) usize {
    if (buf.len == 0) return 0;

    var fd: i32 = -1;
    defer if (fd != -1) {
        const _ = linux.close(fd);  // Ignore errors, can't do anything sensible.
    };

    // TODO(bnoordhuis) Remember the method across invocations so we don't make
    // unnecessary system calls that are going to fail with ENOSYS anyway.
    var method = Method.Syscall;
    var i: usize = 0;
    while (i < buf.len) {
        const rc = switch (method) {
            Method.Syscall => ctx.syscall(&fd, buf[i..]),
            Method.Sysctl => ctx.sysctl(&fd, buf[i..]),
            Method.Urandom => ctx.urandom(&fd, buf[i..]),
        };
        if (rc == 0) return usize(-EIO);  // Can't really happen.
        if (!isErr(rc)) {
            i += rc;
            continue;
        }
        if (rc == usize(-EINTR)) continue;
        if (rc == usize(-ENOSYS) and method == Method.Syscall) {
            method = Method.Urandom;
            continue;
        }
        if (method == Method.Urandom) {
            method = Method.Sysctl;
            continue;
        }
        return rc;  // Unexpected error.
    }

    return i;
}

fn syscall(_: &i32, buf: []u8) usize {
    return arch.syscall3(arch.SYS_getrandom, @ptrToInt(&buf[0]), buf.len, 0);
}

// Note: reads only 14 bytes at a time.
fn sysctl(_: &i32, buf: []u8) usize {
    const __sysctl_args = extern struct {
        name: &c_int,
        nlen: c_int,
        oldval: &u8,
        oldlenp: &usize,
        newval: ?&u8,
        newlen: usize,
        unused: [4]usize,
    };

    var name = [3]c_int { 1, 40, 6 };  // { CTL_KERN, KERN_RANDOM, RANDOM_UUID }
    var uuid: [16]u8 = undefined;

    const expected: usize = @sizeOf(@typeOf(uuid));
    var len = expected;

    var args = __sysctl_args {
        .name = &name[0],
        .nlen = c_int(name.len),
        .oldval = &uuid[0],
        .oldlenp = &len,
        .newval = null,
        .newlen = 0,
        .unused = []usize {0} ** 4,
    };

    const rc = arch.syscall1(arch.SYS__sysctl, @ptrToInt(&args));
    if (rc != 0) return rc;
    if (len != expected) return 0;  // Can't happen.

    // uuid[] is now a type 4 UUID; bytes 6 and 8 (counting from zero)
    // contain 4 and 5 bits of entropy, respectively.  For ease of use,
    // we skip those and only use 14 of the 16 bytes.
    uuid[6] = uuid[14];
    uuid[8] = uuid[15];

    const n = math.min(buf.len, usize(14));
    @memcpy(&buf[0], &uuid[0], n);
    return n;
}

fn urandom(fd: &i32, buf: []u8) usize {
    if (*fd == -1) {
        const flags = linux.O_CLOEXEC|linux.O_RDONLY;
        const rc = linux.open(c"/dev/urandom", flags, 0);
        if (isErr(rc)) return rc;
        *fd = i32(rc);
    }
    // read() doesn't like reads > INT_MAX.
    const n = math.min(buf.len, usize(0x7FFFFFFF));
    return linux.read(*fd, &buf[0], n);
}

fn isErr(rc: usize) bool {
    return rc > usize(-4096);
}

test "os.linux.getRandomBytes" {
    try check(42, getRandomBytesTrampoline);
}

test "os.linux.getRandomBytes syscall" {
    try check(42, syscall);
}

test "os.linux.getRandomBytes sysctl" {
    try check(14, sysctl);
}

test "os.linux.getRandomBytes /dev/urandom" {
    try check(42, urandom);
}

test "os.linux.getRandomBytes state machine" {
    const ctx = Context {
        .syscall = fortytwo,
        .urandom = fail,
        .sysctl = fail,
    };
    var buf = []u8 {0};
    assert(1 == withContext(ctx, buf[0..]));
    assert(42 == buf[0]);
}

test "os.linux.getRandomBytes no-syscall state machine" {
    const ctx = Context {
        .syscall = enosys,
        .urandom = fortytwo,
        .sysctl = fail,
    };
    var buf = []u8 {0};
    assert(1 == withContext(ctx, buf[0..]));
    assert(42 == buf[0]);
}

test "os.linux.getRandomBytes no-urandom state machine" {
    const ctx = Context {
        .syscall = enosys,
        .urandom = einval,
        .sysctl = fortytwo,
    };
    var buf = []u8 {0};
    assert(1 == withContext(ctx, buf[0..]));
    assert(42 == buf[0]);
}

test "os.linux.getRandomBytes no-sysctl state machine" {
    const ctx = Context {
        .syscall = enosys,
        .urandom = einval,
        .sysctl = einval,
    };
    var buf = []u8 {0};
    assert(usize(-EINVAL) == withContext(ctx, buf[0..]));
    assert(0 == buf[0]);
}

fn einval(_: &i32, buf: []u8) usize {
    return usize(-EINVAL);
}

fn enosys(_: &i32, buf: []u8) usize {
    return usize(-ENOSYS);
}

fn fail(_: &i32, buf: []u8) usize {
    os.abort();
}

fn fortytwo(_: &i32, buf: []u8) usize {
    assert(buf.len == 1);
    buf[0] = 42;
    return 1;
}

fn check(comptime N: usize, cb: Callback) %void {
    if (builtin.os == builtin.Os.linux) {
        var fd: i32 = -1;
        defer if (fd != -1) {
            const _ = linux.close(fd);  // Ignore errors, can't do anything sensible.
        };

        var bufs = [3][N]u8 {
            []u8 {0} ** N,
            []u8 {0} ** N,
            []u8 {0} ** N,
        };

        for (bufs) |*buf| {
            const err = cb(&fd, (*buf)[0..]);
            assert(err == N);
        }

        for (bufs) |*a|
            for (bufs) |*b|
                if (a != b)
                    assert(!mem.eql(u8, *a, *b));
    }
}

fn getRandomBytesTrampoline(_: &i32, buf: []u8) usize {
    return getRandomBytes(buf);
}
