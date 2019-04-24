pub const REG_BP = 6; // ebp
pub const REG_SP = 7; // esp
pub const REG_IP = 14; // eip

const clock_t = c_long;
const uid_t = c_uint;
const pid_t = c_int;

const sigval_t = extern union {
    sival_int: c_int,
    sival_ptr: ?*c_void,
};

pub const sigset_t = extern struct {
    __val: [32]c_ulong,
};

pub const siginfo_t = extern struct {
    si_signo: c_int,
    si_errno: c_int,
    si_code: c_int,
    _si_fields: extern union {
        _pad: [29]c_int,
        _kill: extern struct {
            si_pid: pid_t,
            si_uid: uid_t,
        },
        _timer: extern struct {
            si_tid: c_int,
            si_overrun: c_int,
            si_sigval: sigval_t,
        },
        _rt: extern struct {
            si_pid: pid_t,
            si_uid: uid_t,
            si_sigval: sigval_t,
        },
        _sigchld: extern struct {
            si_pid: pid_t,
            si_uid: uid_t,
            si_status: c_int,
            si_utime: clock_t,
            si_stime: clock_t,
        },
        _sigfault: extern struct {
            si_addr: ?*c_void,
            si_addr_lsb: c_short,
            _bounds: extern union {
                _addr_bnd: extern struct {
                    _lower: ?*c_void,
                    _upper: ?*c_void,
                },
                _pkey: c_uint,
            },
        },
        _sigpoll: extern struct {
            si_band: c_long,
            si_fd: c_int,
        },
        _sigsys: extern struct {
            _call_addr: ?*c_void,
            _syscall: c_int,
            _arch: c_uint,
        },
    },
};

const _libc_fpreg = extern struct {
    significand: [4]c_ushort,
    exponent: c_ushort,
};

pub const _libc_fpstate = extern struct {
    cw: c_ulong,
    sw: c_ulong,
    tag: c_ulong,
    ipoff: c_ulong,
    cssel: c_ulong,
    dataoff: c_ulong,
    datasel: c_ulong,
    _st: [8]_libc_fpreg,
    status: c_ulong,
};

const greg_t = c_int;
const gregset_t = [19]greg_t;
const fpregset_t = [*c]_libc_fpstate;

pub const mcontext_t = extern struct {
    gregs: gregset_t,
    fpregs: fpregset_t,
    oldmask: c_ulong,
    cr2: c_ulong,
};

pub const __ssp_type = c_ulong;
