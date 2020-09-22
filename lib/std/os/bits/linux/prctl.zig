// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

pub const PR_SET_PDEATHSIG = 1;
pub const PR_GET_PDEATHSIG = 2;

pub const PR_GET_DUMPABLE = 3;
pub const PR_SET_DUMPABLE = 4;

pub const PR_GET_UNALIGN = 5;
pub const PR_SET_UNALIGN = 6;
pub const PR_UNALIGN_NOPRINT = 1;
pub const PR_UNALIGN_SIGBUS = 2;

pub const PR_GET_KEEPCAPS = 7;
pub const PR_SET_KEEPCAPS = 8;

pub const PR_GET_FPEMU = 9;
pub const PR_SET_FPEMU = 10;
pub const PR_FPEMU_NOPRINT = 1;
pub const PR_FPEMU_SIGFPE = 2;

pub const PR_GET_FPEXC = 11;
pub const PR_SET_FPEXC = 12;
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

pub const PR_GET_TIMING = 13;
pub const PR_SET_TIMING = 14;
pub const PR_TIMING_STATISTICAL = 0;
pub const PR_TIMING_TIMESTAMP = 1;

pub const PR_SET_NAME = 15;
pub const PR_GET_NAME = 16;

pub const PR_GET_ENDIAN = 19;
pub const PR_SET_ENDIAN = 20;
pub const PR_ENDIAN_BIG = 0;
pub const PR_ENDIAN_LITTLE = 1;
pub const PR_ENDIAN_PPC_LITTLE = 2;

pub const PR_GET_SECCOMP = 21;
pub const PR_SET_SECCOMP = 22;

pub const PR_CAPBSET_READ = 23;
pub const PR_CAPBSET_DROP = 24;

pub const PR_GET_TSC = 25;
pub const PR_SET_TSC = 26;
pub const PR_TSC_ENABLE = 1;
pub const PR_TSC_SIGSEGV = 2;

pub const PR_GET_SECUREBITS = 27;
pub const PR_SET_SECUREBITS = 28;

pub const PR_SET_TIMERSLACK = 29;
pub const PR_GET_TIMERSLACK = 30;

pub const PR_TASK_PERF_EVENTS_DISABLE = 31;
pub const PR_TASK_PERF_EVENTS_ENABLE = 32;

pub const PR_MCE_KILL = 33;
pub const PR_MCE_KILL_CLEAR = 0;
pub const PR_MCE_KILL_SET = 1;

pub const PR_MCE_KILL_LATE = 0;
pub const PR_MCE_KILL_EARLY = 1;
pub const PR_MCE_KILL_DEFAULT = 2;

pub const PR_MCE_KILL_GET = 34;

pub const PR_SET_MM = 35;
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

pub const PR_SET_PTRACER = 0x59616d61;
pub const PR_SET_PTRACER_ANY = std.math.maxInt(c_ulong);

pub const PR_SET_CHILD_SUBREAPER = 36;
pub const PR_GET_CHILD_SUBREAPER = 37;

pub const PR_SET_NO_NEW_PRIVS = 38;
pub const PR_GET_NO_NEW_PRIVS = 39;

pub const PR_GET_TID_ADDRESS = 40;

pub const PR_SET_THP_DISABLE = 41;
pub const PR_GET_THP_DISABLE = 42;

pub const PR_MPX_ENABLE_MANAGEMENT = 43;
pub const PR_MPX_DISABLE_MANAGEMENT = 44;

pub const PR_SET_FP_MODE = 45;
pub const PR_GET_FP_MODE = 46;
pub const PR_FP_MODE_FR = 1 << 0;
pub const PR_FP_MODE_FRE = 1 << 1;

pub const PR_CAP_AMBIENT = 47;
pub const PR_CAP_AMBIENT_IS_SET = 1;
pub const PR_CAP_AMBIENT_RAISE = 2;
pub const PR_CAP_AMBIENT_LOWER = 3;
pub const PR_CAP_AMBIENT_CLEAR_ALL = 4;

pub const PR_SVE_SET_VL = 50;
pub const PR_SVE_SET_VL_ONEXEC = 1 << 18;
pub const PR_SVE_GET_VL = 51;
pub const PR_SVE_VL_LEN_MASK = 0xffff;
pub const PR_SVE_VL_INHERIT = 1 << 17;

pub const PR_GET_SPECULATION_CTRL = 52;
pub const PR_SET_SPECULATION_CTRL = 53;
pub const PR_SPEC_STORE_BYPASS = 0;
pub const PR_SPEC_NOT_AFFECTED = 0;
pub const PR_SPEC_PRCTL = 1 << 0;
pub const PR_SPEC_ENABLE = 1 << 1;
pub const PR_SPEC_DISABLE = 1 << 2;
pub const PR_SPEC_FORCE_DISABLE = 1 << 3;
