/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _ASM_PTRACE_H
#define _ASM_PTRACE_H
#include <linux/types.h>
#define FPR_BASE 32
#define PC 64
#define CAUSE 65
#define BADVADDR 66
#define MMHI 67
#define MMLO 68
#define FPC_CSR 69
#define FPC_EIR 70
#define DSP_BASE 71
#define DSP_CONTROL 77
#define ACX 78
struct pt_regs {
  __u64 regs[32];
  __u64 lo;
  __u64 hi;
  __u64 cp0_epc;
  __u64 cp0_badvaddr;
  __u64 cp0_status;
  __u64 cp0_cause;
} __attribute__((aligned(8)));
#define PTRACE_GETREGS 12
#define PTRACE_SETREGS 13
#define PTRACE_GETFPREGS 14
#define PTRACE_SETFPREGS 15
#define PTRACE_OLDSETOPTIONS 21
#define PTRACE_GET_THREAD_AREA 25
#define PTRACE_SET_THREAD_AREA 26
#define PTRACE_PEEKTEXT_3264 0xc0
#define PTRACE_PEEKDATA_3264 0xc1
#define PTRACE_POKETEXT_3264 0xc2
#define PTRACE_POKEDATA_3264 0xc3
#define PTRACE_GET_THREAD_AREA_3264 0xc4
enum pt_watch_style {
  pt_watch_style_mips32,
  pt_watch_style_mips64
};
struct mips32_watch_regs {
  unsigned int watchlo[8];
  unsigned short watchhi[8];
  unsigned short watch_masks[8];
  unsigned int num_valid;
} __attribute__((aligned(8)));
struct mips64_watch_regs {
  unsigned long long watchlo[8];
  unsigned short watchhi[8];
  unsigned short watch_masks[8];
  unsigned int num_valid;
} __attribute__((aligned(8)));
struct pt_watch_regs {
  enum pt_watch_style style;
  union {
    struct mips32_watch_regs mips32;
    struct mips64_watch_regs mips64;
  };
};
#define PTRACE_GET_WATCH_REGS 0xd0
#define PTRACE_SET_WATCH_REGS 0xd1
#endif