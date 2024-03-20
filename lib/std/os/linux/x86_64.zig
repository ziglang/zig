const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const linux = std.os.linux;
const SYS = linux.SYS;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;

const pid_t = linux.pid_t;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const clock_t = linux.clock_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const timespec = linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
        : "rcx", "r11", "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
        : "rcx", "r11", "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
        : "rcx", "r11", "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
        : "rcx", "r11", "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
        : "rcx", "r11", "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
        : "rcx", "r11", "memory"
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
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
          [arg6] "{r9}" (arg6),
        : "rcx", "r11", "memory"
    );
}

const CloneFn = *const fn (arg: usize) callconv(.C) u8;

/// This matches the libc clone function.
pub extern fn clone(func: CloneFn, stack: usize, flags: usize, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) noreturn {
    switch (@import("builtin").zig_backend) {
        .stage2_c => asm volatile (
            \\ movl %[number], %%eax
            \\ syscall
            :
            : [number] "i" (@intFromEnum(SYS.rt_sigreturn)),
            : "rcx", "r11", "memory"
        ),
        else => asm volatile (
            \\ syscall
            :
            : [number] "{rax}" (@intFromEnum(SYS.rt_sigreturn)),
            : "rcx", "r11", "memory"
        ),
    }
}

pub const mode_t = usize;
pub const time_t = isize;
pub const nlink_t = usize;
pub const blksize_t = isize;
pub const blkcnt_t = isize;

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const GETLK = 5;
    pub const SETLK = 6;
    pub const SETLKW = 7;
    pub const SETOWN = 8;
    pub const GETOWN = 9;
    pub const SETSIG = 10;
    pub const GETSIG = 11;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;
    pub const GETOWNER_UIDS = 17;

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;
};

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";

    pub const GETCPU_SYM = "__vdso_getcpu";
    pub const GETCPU_VER = "LINUX_2.6";
};

pub const ARCH = struct {
    pub const SET_GS = 0x1001;
    pub const SET_FS = 0x1002;
    pub const GET_FS = 0x1003;
    pub const GET_GS = 0x1004;
};

pub const REG = struct {
    pub const R8 = 0;
    pub const R9 = 1;
    pub const R10 = 2;
    pub const R11 = 3;
    pub const R12 = 4;
    pub const R13 = 5;
    pub const R14 = 6;
    pub const R15 = 7;
    pub const RDI = 8;
    pub const RSI = 9;
    pub const RBP = 10;
    pub const RBX = 11;
    pub const RDX = 12;
    pub const RAX = 13;
    pub const RCX = 14;
    pub const RSP = 15;
    pub const RIP = 16;
    pub const EFL = 17;
    pub const CSGSFS = 18;
    pub const ERR = 19;
    pub const TRAPNO = 20;
    pub const OLDMASK = 21;
    pub const CR2 = 22;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

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
    __pad1: i32 = 0,
    control: ?*anyopaque,
    controllen: socklen_t,
    __pad2: socklen_t = 0,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: i32,
    __pad1: i32 = 0,
    control: ?*const anyopaque,
    controllen: socklen_t,
    __pad2: socklen_t = 0,
    flags: i32,
};

pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    nlink: usize,

    mode: u32,
    uid: uid_t,
    gid: gid_t,
    __pad0: u32,
    rdev: dev_t,
    size: off_t,
    blksize: isize,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [3]isize,

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
    tv_sec: isize,
    tv_usec: isize,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const Elf_Symndx = u32;

pub const greg_t = usize;
pub const gregset_t = [23]greg_t;
pub const fpstate = extern struct {
    cwd: u16,
    swd: u16,
    ftw: u16,
    fop: u16,
    rip: usize,
    rdp: usize,
    mxcsr: u32,
    mxcr_mask: u32,
    st: [8]extern struct {
        significand: [4]u16,
        exponent: u16,
        padding: [3]u16 = undefined,
    },
    xmm: [16]extern struct {
        element: [4]u32,
    },
    padding: [24]u32 = undefined,
};
pub const fpregset_t = *fpstate;
pub const sigcontext = extern struct {
    r8: usize,
    r9: usize,
    r10: usize,
    r11: usize,
    r12: usize,
    r13: usize,
    r14: usize,
    r15: usize,

    rdi: usize,
    rsi: usize,
    rbp: usize,
    rbx: usize,
    rdx: usize,
    rax: usize,
    rcx: usize,
    rsp: usize,
    rip: usize,
    eflags: usize,

    cs: u16,
    gs: u16,
    fs: u16,
    pad0: u16 = undefined,

    err: usize,
    trapno: usize,
    oldmask: usize,
    cr2: usize,

    fpstate: *fpstate,
    reserved1: [8]usize = undefined,
};

pub const mcontext_t = extern struct {
    gregs: gregset_t,
    fpregs: fpregset_t,
    reserved1: [8]usize = undefined,
};

pub const ucontext_t = extern struct {
    flags: usize,
    link: ?*ucontext_t,
    stack: stack_t,
    mcontext: mcontext_t,
    sigmask: sigset_t,
    fpregs_mem: [64]usize,
};

fn gpRegisterOffset(comptime reg_index: comptime_int) usize {
    return @offsetOf(ucontext_t, "mcontext") + @offsetOf(mcontext_t, "gregs") + @sizeOf(usize) * reg_index;
}

fn getContextInternal() callconv(.Naked) usize {
    // TODO: Read GS/FS registers?
    asm volatile (
        \\ movq $0, %[flags_offset:c](%%rdi)
        \\ movq $0, %[link_offset:c](%%rdi)
        \\ movq %%r8, %[r8_offset:c](%%rdi)
        \\ movq %%r9, %[r9_offset:c](%%rdi)
        \\ movq %%r10, %[r10_offset:c](%%rdi)
        \\ movq %%r11, %[r11_offset:c](%%rdi)
        \\ movq %%r12, %[r12_offset:c](%%rdi)
        \\ movq %%r13, %[r13_offset:c](%%rdi)
        \\ movq %%r14, %[r14_offset:c](%%rdi)
        \\ movq %%r15, %[r15_offset:c](%%rdi)
        \\ movq %%rdi, %[rdi_offset:c](%%rdi)
        \\ movq %%rsi, %[rsi_offset:c](%%rdi)
        \\ movq %%rbp, %[rbp_offset:c](%%rdi)
        \\ movq %%rbx, %[rbx_offset:c](%%rdi)
        \\ movq %%rdx, %[rdx_offset:c](%%rdi)
        \\ movq %%rax, %[rax_offset:c](%%rdi)
        \\ movq %%rcx, %[rcx_offset:c](%%rdi)
        \\ movq (%%rsp), %%rcx
        \\ movq %%rcx, %[rip_offset:c](%%rdi)
        \\ leaq 8(%%rsp), %%rcx
        \\ movq %%rcx, %[rsp_offset:c](%%rdi)
        \\ pushfq
        \\ popq %[efl_offset:c](%%rdi)
        \\ leaq %[fpmem_offset:c](%%rdi), %%rcx
        \\ movq %%rcx, %[fpstate_offset:c](%%rdi)
        \\ fnstenv (%%rcx)
        \\ fldenv (%%rcx)
        \\ stmxcsr %[mxcsr_offset:c](%%rdi)
        \\ leaq %[stack_offset:c](%%rdi), %%rsi
        \\ movq %%rdi, %%r8
        \\ xorl %%edi, %%edi
        \\ movl %[sigaltstack], %%eax
        \\ syscall
        \\ testq %%rax, %%rax
        \\ jnz 0f
        \\ movl %[sigprocmask], %%eax
        \\ xorl %%esi, %%esi
        \\ leaq %[sigmask_offset:c](%%r8), %%rdx
        \\ movl %[sigset_size], %%r10d
        \\ syscall
        \\0:
        \\ retq
        :
        : [flags_offset] "i" (@offsetOf(ucontext_t, "flags")),
          [link_offset] "i" (@offsetOf(ucontext_t, "link")),
          [r8_offset] "i" (comptime gpRegisterOffset(REG.R8)),
          [r9_offset] "i" (comptime gpRegisterOffset(REG.R9)),
          [r10_offset] "i" (comptime gpRegisterOffset(REG.R10)),
          [r11_offset] "i" (comptime gpRegisterOffset(REG.R11)),
          [r12_offset] "i" (comptime gpRegisterOffset(REG.R12)),
          [r13_offset] "i" (comptime gpRegisterOffset(REG.R13)),
          [r14_offset] "i" (comptime gpRegisterOffset(REG.R14)),
          [r15_offset] "i" (comptime gpRegisterOffset(REG.R15)),
          [rdi_offset] "i" (comptime gpRegisterOffset(REG.RDI)),
          [rsi_offset] "i" (comptime gpRegisterOffset(REG.RSI)),
          [rbp_offset] "i" (comptime gpRegisterOffset(REG.RBP)),
          [rbx_offset] "i" (comptime gpRegisterOffset(REG.RBX)),
          [rdx_offset] "i" (comptime gpRegisterOffset(REG.RDX)),
          [rax_offset] "i" (comptime gpRegisterOffset(REG.RAX)),
          [rcx_offset] "i" (comptime gpRegisterOffset(REG.RCX)),
          [rsp_offset] "i" (comptime gpRegisterOffset(REG.RSP)),
          [rip_offset] "i" (comptime gpRegisterOffset(REG.RIP)),
          [efl_offset] "i" (comptime gpRegisterOffset(REG.EFL)),
          [fpstate_offset] "i" (@offsetOf(ucontext_t, "mcontext") + @offsetOf(mcontext_t, "fpregs")),
          [fpmem_offset] "i" (@offsetOf(ucontext_t, "fpregs_mem")),
          [mxcsr_offset] "i" (@offsetOf(ucontext_t, "fpregs_mem") + @offsetOf(fpstate, "mxcsr")),
          [sigaltstack] "i" (@intFromEnum(linux.SYS.sigaltstack)),
          [stack_offset] "i" (@offsetOf(ucontext_t, "stack")),
          [sigprocmask] "i" (@intFromEnum(linux.SYS.rt_sigprocmask)),
          [sigmask_offset] "i" (@offsetOf(ucontext_t, "sigmask")),
          [sigset_size] "i" (linux.NSIG / 8),
        : "cc", "memory", "rax", "rcx", "rdx", "rdi", "rsi", "r8", "r10", "r11"
    );
}

pub inline fn getcontext(context: *ucontext_t) usize {
    // This method is used so that getContextInternal can control
    // its prologue in order to read RSP from a constant offset
    // An aligned stack is not needed for getContextInternal.
    var clobber_rdi: usize = undefined;
    return asm volatile (
        \\ callq %[getContextInternal:P]
        : [_] "={rax}" (-> usize),
          [_] "={rdi}" (clobber_rdi),
        : [_] "{rdi}" (context),
          [getContextInternal] "X" (&getContextInternal),
        : "cc", "memory", "rcx", "rdx", "rsi", "r8", "r10", "r11"
    );
}
