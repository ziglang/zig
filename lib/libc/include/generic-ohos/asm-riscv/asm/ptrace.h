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
#ifndef _ASM_RISCV_PTRACE_H
#define _ASM_RISCV_PTRACE_H
#ifndef __ASSEMBLY__
#include <linux/types.h>
struct user_regs_struct {
  unsigned long pc;
  unsigned long ra;
  unsigned long sp;
  unsigned long gp;
  unsigned long tp;
  unsigned long t0;
  unsigned long t1;
  unsigned long t2;
  unsigned long s0;
  unsigned long s1;
  unsigned long a0;
  unsigned long a1;
  unsigned long a2;
  unsigned long a3;
  unsigned long a4;
  unsigned long a5;
  unsigned long a6;
  unsigned long a7;
  unsigned long s2;
  unsigned long s3;
  unsigned long s4;
  unsigned long s5;
  unsigned long s6;
  unsigned long s7;
  unsigned long s8;
  unsigned long s9;
  unsigned long s10;
  unsigned long s11;
  unsigned long t3;
  unsigned long t4;
  unsigned long t5;
  unsigned long t6;
};
struct __riscv_f_ext_state {
  __u32 f[32];
  __u32 fcsr;
};
struct __riscv_d_ext_state {
  __u64 f[32];
  __u32 fcsr;
};
struct __riscv_q_ext_state {
  __u64 f[64] __attribute__((aligned(16)));
  __u32 fcsr;
  __u32 reserved[3];
};
union __riscv_fp_state {
  struct __riscv_f_ext_state f;
  struct __riscv_d_ext_state d;
  struct __riscv_q_ext_state q;
};
#endif
#endif