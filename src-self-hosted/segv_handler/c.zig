const arch = switch (@import("builtin").arch) {
    .x86_64 => @import("x86_64-linux.zig"),
    .i386 => @import("i386-linux.zig"),
    else => struct {},
};

pub const SIGSEGV = 11;
pub const SA_SIGINFO = (1 << 2); // 4
pub const SA_RESTART = (1 << 28); // 268435456
pub const SA_NODEFER = (1 << 30); // 1073741824
pub const REG_BP = arch.REG_BP;
pub const REG_SP = arch.REG_SP;
pub const REG_IP = arch.REG_IP;

pub const siginfo_t = arch.siginfo_t;
pub const sigset_t = arch.sigset_t;

pub const sigaction_t = extern struct {
    sa_handler: extern union {
        sa_handler: ?extern fn(c_int) void,
        sa_sigaction: ?extern fn(c_int, ?*siginfo_t, ?*c_void) void,
    },
    sa_mask: sigset_t,
    sa_flags: c_int,
    sa_restorer: ?extern fn() void,
};

const stack_t = extern struct {
    ss_sp: ?*c_void,
    ss_flags: c_int,
    ss_size: usize,
};

pub const ucontext_t = extern struct {
    uc_flags: c_ulong,
    uc_link: [*c]ucontext_t,
    uc_stack: stack_t,
    uc_mcontext: arch.mcontext_t,
    uc_sigmask: sigset_t,
    __fpregs_mem: arch._libc_fpstate,
    __ssp: [4]arch.__ssp_type,
};

pub extern fn sigemptyset(set: *sigset_t) c_int;
pub extern fn sigaction(signum: c_int, noalias act: ?*const sigaction_t, noalias oldact: ?*sigaction_t) c_int;
