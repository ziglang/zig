// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

pub const PR = extern enum(i32) {
    SET_PDEATHSIG = 1,
    GET_PDEATHSIG = 2,

    GET_DUMPABLE = 3,
    SET_DUMPABLE = 4,

    GET_UNALIGN = 5,
    SET_UNALIGN = 6,

    GET_KEEPCAPS = 7,
    SET_KEEPCAPS = 8,

    GET_FPEMU = 9,
    SET_FPEMU = 10,

    GET_FPEXC = 11,
    SET_FPEXC = 12,

    GET_TIMING = 13,
    SET_TIMING = 14,

    SET_NAME = 15,
    GET_NAME = 16,

    GET_ENDIAN = 19,
    SET_ENDIAN = 20,

    GET_SECCOMP = 21,
    SET_SECCOMP = 22,

    CAPBSET_READ = 23,
    CAPBSET_DROP = 24,

    GET_TSC = 25,
    SET_TSC = 26,

    GET_SECUREBITS = 27,
    SET_SECUREBITS = 28,

    SET_TIMERSLACK = 29,
    GET_TIMERSLACK = 30,

    TASK_PERF_EVENTS_DISABLE = 31,
    TASK_PERF_EVENTS_ENABLE = 32,

    MCE_KILL = 33,

    MCE_KILL_GET = 34,

    SET_MM = 35,

    SET_PTRACER = 0x59616d61,

    SET_CHILD_SUBREAPER = 36,
    GET_CHILD_SUBREAPER = 37,

    SET_NO_NEW_PRIVS = 38,
    GET_NO_NEW_PRIVS = 39,

    GET_TID_ADDRESS = 40,

    SET_THP_DISABLE = 41,
    GET_THP_DISABLE = 42,

    MPX_ENABLE_MANAGEMENT = 43,
    MPX_DISABLE_MANAGEMENT = 44,

    SET_FP_MODE = 45,
    GET_FP_MODE = 46,

    CAP_AMBIENT = 47,

    SVE_SET_VL = 50,
    SVE_GET_VL = 51,

    GET_SPECULATION_CTRL = 52,
    SET_SPECULATION_CTRL = 53,

    _,
};

pub const PR_SET_PDEATHSIG = @enumToInt(PR.SET_PDEATHSIG);
pub const PR_GET_PDEATHSIG = @enumToInt(PR.GET_PDEATHSIG);

pub const PR_GET_DUMPABLE = @enumToInt(PR.GET_DUMPABLE);
pub const PR_SET_DUMPABLE = @enumToInt(PR.SET_DUMPABLE);

pub const PR_GET_UNALIGN = @enumToInt(PR.GET_UNALIGN);
pub const PR_SET_UNALIGN = @enumToInt(PR.SET_UNALIGN);
pub const PR_UNALIGN_NOPRINT = 1;
pub const PR_UNALIGN_SIGBUS = 2;

pub const PR_GET_KEEPCAPS = @enumToInt(PR.GET_KEEPCAPS);
pub const PR_SET_KEEPCAPS = @enumToInt(PR.SET_KEEPCAPS);

pub const PR_GET_FPEMU = @enumToInt(PR.GET_FPEMU);
pub const PR_SET_FPEMU = @enumToInt(PR.SET_FPEMU);
pub const PR_FPEMU_NOPRINT = 1;
pub const PR_FPEMU_SIGFPE = 2;

pub const PR_GET_FPEXC = @enumToInt(PR.GET_FPEXC);
pub const PR_SET_FPEXC = @enumToInt(PR.SET_FPEXC);
pub const PR_FP_EXC_SW_ENABLE = 0x80;
pub const PR_FP_EXC_DIV = 0x010000;
pub const PR_FP_EXC_OVF = 0x020000;
pub const PR_FP_EXC_UND = 0x040000;
pub const PR_FP_EXC_RES = 0x080000;
pub const PR_FP_EXC_INV = 0x100000;
pub const PR_FP_EXC_DISABLED = 0;
pub const PR_FP_EXC_NONRECOV = 1;
pub const PR_FP_EXC_ASYNC = 2;
pub const PR_FP_EXC_PRECISE = 3;

pub const PR_GET_TIMING = @enumToInt(PR.GET_TIMING);
pub const PR_SET_TIMING = @enumToInt(PR.SET_TIMING);
pub const PR_TIMING_STATISTICAL = 0;
pub const PR_TIMING_TIMESTAMP = 1;

pub const PR_SET_NAME = @enumToInt(PR.SET_NAME);
pub const PR_GET_NAME = @enumToInt(PR.GET_NAME);

pub const PR_GET_ENDIAN = @enumToInt(PR.GET_ENDIAN);
pub const PR_SET_ENDIAN = @enumToInt(PR.SET_ENDIAN);
pub const PR_ENDIAN_BIG = 0;
pub const PR_ENDIAN_LITTLE = 1;
pub const PR_ENDIAN_PPC_LITTLE = 2;

pub const PR_GET_SECCOMP = @enumToInt(PR.GET_SECCOMP);
pub const PR_SET_SECCOMP = @enumToInt(PR.SET_SECCOMP);

pub const PR_CAPBSET_READ = @enumToInt(PR.CAPBSET_READ);
pub const PR_CAPBSET_DROP = @enumToInt(PR.CAPBSET_DROP);

pub const PR_GET_TSC = @enumToInt(PR.GET_TSC);
pub const PR_SET_TSC = @enumToInt(PR.SET_TSC);
pub const PR_TSC_ENABLE = 1;
pub const PR_TSC_SIGSEGV = 2;

pub const PR_GET_SECUREBITS = @enumToInt(PR.GET_SECUREBITS);
pub const PR_SET_SECUREBITS = @enumToInt(PR.SET_SECUREBITS);

pub const PR_SET_TIMERSLACK = @enumToInt(PR.SET_TIMERSLACK);
pub const PR_GET_TIMERSLACK = @enumToInt(PR.GET_TIMERSLACK);

pub const PR_TASK_PERF_EVENTS_DISABLE = @enumToInt(PR.TASK_PERF_EVENTS_DISABLE);
pub const PR_TASK_PERF_EVENTS_ENABLE = @enumToInt(PR.TASK_PERF_EVENTS_ENABLE);

pub const PR_MCE_KILL = @enumToInt(PR.MCE_KILL);
pub const PR_MCE_KILL_CLEAR = 0;
pub const PR_MCE_KILL_SET = 1;

pub const PR_MCE_KILL_LATE = 0;
pub const PR_MCE_KILL_EARLY = 1;
pub const PR_MCE_KILL_DEFAULT = 2;

pub const PR_MCE_KILL_GET = @enumToInt(PR.MCE_KILL_GET);

pub const PR_SET_MM = @enumToInt(PR.SET_MM);
pub const PR_SET_MM_START_CODE = 1;
pub const PR_SET_MM_END_CODE = 2;
pub const PR_SET_MM_START_DATA = 3;
pub const PR_SET_MM_END_DATA = 4;
pub const PR_SET_MM_START_STACK = 5;
pub const PR_SET_MM_START_BRK = 6;
pub const PR_SET_MM_BRK = 7;
pub const PR_SET_MM_ARG_START = 8;
pub const PR_SET_MM_ARG_END = 9;
pub const PR_SET_MM_ENV_START = 10;
pub const PR_SET_MM_ENV_END = 11;
pub const PR_SET_MM_AUXV = 12;
pub const PR_SET_MM_EXE_FILE = 13;
pub const PR_SET_MM_MAP = 14;
pub const PR_SET_MM_MAP_SIZE = 15;

pub const prctl_mm_map = extern struct {
    start_code: u64,
    end_code: u64,
    start_data: u64,
    end_data: u64,
    start_brk: u64,
    brk: u64,
    start_stack: u64,
    arg_start: u64,
    arg_end: u64,
    env_start: u64,
    env_end: u64,
    auxv: *u64,
    auxv_size: u32,
    exe_fd: u32,
};

pub const PR_SET_PTRACER = @enumToInt(PR.SET_PTRACER);
pub const PR_SET_PTRACER_ANY = std.math.maxInt(c_ulong);

pub const PR_SET_CHILD_SUBREAPER = @enumToInt(PR.SET_CHILD_SUBREAPER);
pub const PR_GET_CHILD_SUBREAPER = @enumToInt(PR.GET_CHILD_SUBREAPER);

pub const PR_SET_NO_NEW_PRIVS = @enumToInt(PR.SET_NO_NEW_PRIVS);
pub const PR_GET_NO_NEW_PRIVS = @enumToInt(PR.GET_NO_NEW_PRIVS);

pub const PR_GET_TID_ADDRESS = @enumToInt(PR.GET_TID_ADDRESS);

pub const PR_SET_THP_DISABLE = @enumToInt(PR.SET_THP_DISABLE);
pub const PR_GET_THP_DISABLE = @enumToInt(PR.GET_THP_DISABLE);

pub const PR_MPX_ENABLE_MANAGEMENT = @enumToInt(PR.MPX_ENABLE_MANAGEMENT);
pub const PR_MPX_DISABLE_MANAGEMENT = @enumToInt(PR.MPX_DISABLE_MANAGEMENT);

pub const PR_SET_FP_MODE = @enumToInt(PR.SET_FP_MODE);
pub const PR_GET_FP_MODE = @enumToInt(PR.GET_FP_MODE);
pub const PR_FP_MODE_FR = 1 << 0;
pub const PR_FP_MODE_FRE = 1 << 1;

pub const PR_CAP_AMBIENT = @enumToInt(PR.CAP_AMBIENT);
pub const PR_CAP_AMBIENT_IS_SET = 1;
pub const PR_CAP_AMBIENT_RAISE = 2;
pub const PR_CAP_AMBIENT_LOWER = 3;
pub const PR_CAP_AMBIENT_CLEAR_ALL = 4;

pub const PR_SVE_SET_VL = @enumToInt(PR.SVE_SET_VL);
pub const PR_SVE_SET_VL_ONEXEC = 1 << 18;
pub const PR_SVE_GET_VL = @enumToInt(PR.SVE_GET_VL);
pub const PR_SVE_VL_LEN_MASK = 0xffff;
pub const PR_SVE_VL_INHERIT = 1 << 17;

pub const PR_GET_SPECULATION_CTRL = @enumToInt(PR.GET_SPECULATION_CTRL);
pub const PR_SET_SPECULATION_CTRL = @enumToInt(PR.SET_SPECULATION_CTRL);
pub const PR_SPEC_STORE_BYPASS = 0;
pub const PR_SPEC_NOT_AFFECTED = 0;
pub const PR_SPEC_PRCTL = 1 << 0;
pub const PR_SPEC_ENABLE = 1 << 1;
pub const PR_SPEC_DISABLE = 1 << 2;
pub const PR_SPEC_FORCE_DISABLE = 1 << 3;
