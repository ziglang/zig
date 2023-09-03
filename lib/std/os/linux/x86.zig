const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const linux = std.os.linux;
const SYS = linux.SYS;
const socklen_t = linux.socklen_t;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const pid_t = linux.pid_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;
const sockaddr = linux.sockaddr;
const timespec = linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(number)),
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
          [arg5] "{edi}" (arg5),
        : "memory"
    );
}

pub fn syscall6(
    number: SYS,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
) usize {
    // The 6th argument is passed via memory as we're out of registers if ebp is
    // used as frame pointer. We push arg6 value on the stack before changing
    // ebp or esp as the compiler may reference it as an offset relative to one
    // of those two registers.
    return asm volatile (
        \\ push %[arg6]
        \\ push %%ebp
        \\ mov  4(%%esp), %%ebp
        \\ int  $0x80
        \\ pop  %%ebp
        \\ add  $4, %%esp
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
          [arg5] "{edi}" (arg5),
          [arg6] "rm" (arg6),
        : "memory"
    );
}

pub fn socketcall(call: usize, args: [*]const usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize),
        : [number] "{eax}" (@intFromEnum(SYS.socketcall)),
          [arg1] "{ebx}" (call),
          [arg2] "{ecx}" (@intFromPtr(args)),
        : "memory"
    );
}

const CloneFn = *const fn (arg: usize) callconv(.C) u8;

/// This matches the libc clone function.
pub extern fn clone(func: CloneFn, stack: usize, flags: u32, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub fn restore() callconv(.Naked) noreturn {
    switch (@import("builtin").zig_backend) {
        .stage2_c => asm volatile (
            \\ movl %[number], %%eax
            \\ int $0x80
            :
            : [number] "i" (@intFromEnum(SYS.sigreturn)),
            : "memory"
        ),
        else => asm volatile (
            \\ int $0x80
            :
            : [number] "{eax}" (@intFromEnum(SYS.sigreturn)),
            : "memory"
        ),
    }
}

pub fn restore_rt() callconv(.Naked) noreturn {
    switch (@import("builtin").zig_backend) {
        .stage2_c => asm volatile (
            \\ movl %[number], %%eax
            \\ int $0x80
            :
            : [number] "i" (@intFromEnum(SYS.rt_sigreturn)),
            : "memory"
        ),
        else => asm volatile (
            \\ int $0x80
            :
            : [number] "{eax}" (@intFromEnum(SYS.rt_sigreturn)),
            : "memory"
        ),
    }
}

pub const O = struct {
    pub const CREAT = 0o100;
    pub const EXCL = 0o200;
    pub const NOCTTY = 0o400;
    pub const TRUNC = 0o1000;
    pub const APPEND = 0o2000;
    pub const NONBLOCK = 0o4000;
    pub const DSYNC = 0o10000;
    pub const SYNC = 0o4010000;
    pub const RSYNC = 0o4010000;
    pub const DIRECTORY = 0o200000;
    pub const NOFOLLOW = 0o400000;
    pub const CLOEXEC = 0o2000000;

    pub const ASYNC = 0o20000;
    pub const DIRECT = 0o40000;
    pub const LARGEFILE = 0o100000;
    pub const NOATIME = 0o1000000;
    pub const PATH = 0o10000000;
    pub const TMPFILE = 0o20200000;
    pub const NDELAY = NONBLOCK;
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const SETOWN = 8;
    pub const GETOWN = 9;
    pub const SETSIG = 10;
    pub const GETSIG = 11;
    pub const GETLK = 12;
    pub const SETLK = 13;
    pub const SETLKW = 14;
    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;
    pub const GETOWNER_UIDS = 17;

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

pub const MAP = struct {
    pub const NORESERVE = 0x4000;
    pub const GROWSDOWN = 0x0100;
    pub const DENYWRITE = 0x0800;
    pub const EXECUTABLE = 0x1000;
    pub const LOCKED = 0x2000;
    pub const @"32BIT" = 0x40;
};

pub const MMAP2_UNIT = 4096;

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";
};

pub const ARCH = struct {};

pub const Flock = extern struct {
    type: i16,
    whence: i16,
    start: off_t,
    len: off_t,
    pid: pid_t,
};

pub const msghdr = extern struct {
    name: ?*sockaddr,
    namelen: socklen_t,
    iov: [*]iovec,
    iovlen: i32,
    control: ?*anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: i32,
    control: ?*const anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = isize;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    __dev_padding: u32,
    __ino_truncated: u32,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __rdev_padding: u32,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    ino: ino_t,

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

pub const timeval = extern struct {
    tv_sec: i32,
    tv_usec: i32,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const mcontext_t = extern struct {
    gregs: [19]usize,
    fpregs: [*]u8,
    oldmask: usize,
    cr2: usize,
};

pub const REG = struct {
    pub const GS = 0;
    pub const FS = 1;
    pub const ES = 2;
    pub const DS = 3;
    pub const EDI = 4;
    pub const ESI = 5;
    pub const EBP = 6;
    pub const ESP = 7;
    pub const EBX = 8;
    pub const EDX = 9;
    pub const ECX = 10;
    pub const EAX = 11;
    pub const TRAPNO = 12;
    pub const ERR = 13;
    pub const EIP = 14;
    pub const CS = 15;
    pub const EFL = 16;
    pub const UESP = 17;
    pub const SS = 18;
};

pub const ucontext_t = extern struct {
    flags: usize,
    link: ?*ucontext_t,
    stack: stack_t,
    mcontext: mcontext_t,
    sigmask: sigset_t,
    regspace: [64]u64,
};

pub const Elf_Symndx = u32;

pub const user_desc = extern struct {
    entry_number: u32,
    base_addr: u32,
    limit: u32,
    flags: packed struct(u32) {
        seg_32bit: u1,
        contents: u2,
        read_exec_only: u1,
        limit_in_pages: u1,
        seg_not_present: u1,
        useable: u1,
        _: u25 = undefined,
    },
};

/// socketcall() call numbers
pub const SC = struct {
    pub const socket = 1;
    pub const bind = 2;
    pub const connect = 3;
    pub const listen = 4;
    pub const accept = 5;
    pub const getsockname = 6;
    pub const getpeername = 7;
    pub const socketpair = 8;
    pub const send = 9;
    pub const recv = 10;
    pub const sendto = 11;
    pub const recvfrom = 12;
    pub const shutdown = 13;
    pub const setsockopt = 14;
    pub const getsockopt = 15;
    pub const sendmsg = 16;
    pub const recvmsg = 17;
    pub const accept4 = 18;
    pub const recvmmsg = 19;
    pub const sendmmsg = 20;
};

fn gpRegisterOffset(comptime reg_index: comptime_int) usize {
    return @offsetOf(ucontext_t, "mcontext") + @offsetOf(mcontext_t, "gregs") + @sizeOf(usize) * reg_index;
}

noinline fn getContextReturnAddress() usize {
    return @returnAddress();
}

pub fn getContextInternal() callconv(.Naked) usize {
    asm volatile (
        \\ movl $0, %[flags_offset:c](%%edx)
        \\ movl $0, %[link_offset:c](%%edx)
        \\ movl %%edi, %[edi_offset:c](%%edx)
        \\ movl %%esi, %[esi_offset:c](%%edx)
        \\ movl %%ebp, %[ebp_offset:c](%%edx)
        \\ movl %%ebx, %[ebx_offset:c](%%edx)
        \\ movl %%edx, %[edx_offset:c](%%edx)
        \\ movl %%ecx, %[ecx_offset:c](%%edx)
        \\ movl %%eax, %[eax_offset:c](%%edx)
        \\ movl (%%esp), %%ecx
        \\ movl %%ecx, %[eip_offset:c](%%edx)
        \\ leal 4(%%esp), %%ecx
        \\ movl %%ecx, %[esp_offset:c](%%edx)
        \\ xorl %%ecx, %%ecx
        \\ movw %%fs, %%cx
        \\ movl %%ecx, %[fs_offset:c](%%edx)
        \\ leal %[regspace_offset:c](%%edx), %%ecx
        \\ movl %%ecx, %[fpregs_offset:c](%%edx)
        \\ fnstenv (%%ecx)
        \\ fldenv (%%ecx)
        \\ pushl %%ebx
        \\ pushl %%esi
        \\ xorl %%ebx, %%ebx
        \\ movl %[sigaltstack], %%eax
        \\ leal %[stack_offset:c](%%edx), %%ecx
        \\ int $0x80
        \\ testl %%eax, %%eax
        \\ jnz 0f
        \\ movl %[sigprocmask], %%eax
        \\ xorl %%ecx, %%ecx
        \\ leal %[sigmask_offset:c](%%edx), %%edx
        \\ movl %[sigset_size], %%esi
        \\ int $0x80
        \\0:
        \\ popl %%esi
        \\ popl %%ebx
        \\ retl
        :
        : [flags_offset] "i" (@offsetOf(ucontext_t, "flags")),
          [link_offset] "i" (@offsetOf(ucontext_t, "link")),
          [edi_offset] "i" (comptime gpRegisterOffset(REG.EDI)),
          [esi_offset] "i" (comptime gpRegisterOffset(REG.ESI)),
          [ebp_offset] "i" (comptime gpRegisterOffset(REG.EBP)),
          [esp_offset] "i" (comptime gpRegisterOffset(REG.ESP)),
          [ebx_offset] "i" (comptime gpRegisterOffset(REG.EBX)),
          [edx_offset] "i" (comptime gpRegisterOffset(REG.EDX)),
          [ecx_offset] "i" (comptime gpRegisterOffset(REG.ECX)),
          [eax_offset] "i" (comptime gpRegisterOffset(REG.EAX)),
          [eip_offset] "i" (comptime gpRegisterOffset(REG.EIP)),
          [fs_offset] "i" (comptime gpRegisterOffset(REG.FS)),
          [fpregs_offset] "i" (@offsetOf(ucontext_t, "mcontext") + @offsetOf(mcontext_t, "fpregs")),
          [regspace_offset] "i" (@offsetOf(ucontext_t, "regspace")),
          [sigaltstack] "i" (@intFromEnum(linux.SYS.sigaltstack)),
          [stack_offset] "i" (@offsetOf(ucontext_t, "stack")),
          [sigprocmask] "i" (@intFromEnum(linux.SYS.rt_sigprocmask)),
          [sigmask_offset] "i" (@offsetOf(ucontext_t, "sigmask")),
          [sigset_size] "i" (linux.NSIG / 8),
        : "cc", "memory", "eax", "ecx", "edx"
    );
}

pub inline fn getcontext(context: *ucontext_t) usize {
    // This method is used so that getContextInternal can control
    // its prologue in order to read ESP from a constant offset.
    // An aligned stack is not needed for getContextInternal.
    var clobber_edx: usize = undefined;
    return asm volatile (
        \\ calll %[getContextInternal:P]
        : [_] "={eax}" (-> usize),
          [_] "={edx}" (clobber_edx),
        : [_] "{edx}" (context),
          [getContextInternal] "X" (&getContextInternal),
        : "cc", "memory", "ecx"
    );
}
