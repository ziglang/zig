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
#ifndef _ASM_SIGCONTEXT_H
#define _ASM_SIGCONTEXT_H
#include <linux/types.h>
#include <asm/sgidefs.h>
#define USED_FP (1 << 0)
#define USED_FR1 (1 << 1)
#define USED_HYBRID_FPRS (1 << 2)
#define USED_EXTCONTEXT (1 << 3)
#if _MIPS_SIM == _MIPS_SIM_ABI32
struct sigcontext {
  unsigned int sc_regmask;
  unsigned int sc_status;
  unsigned long long sc_pc;
  unsigned long long sc_regs[32];
  unsigned long long sc_fpregs[32];
  unsigned int sc_acx;
  unsigned int sc_fpc_csr;
  unsigned int sc_fpc_eir;
  unsigned int sc_used_math;
  unsigned int sc_dsp;
  unsigned long long sc_mdhi;
  unsigned long long sc_mdlo;
  unsigned long sc_hi1;
  unsigned long sc_lo1;
  unsigned long sc_hi2;
  unsigned long sc_lo2;
  unsigned long sc_hi3;
  unsigned long sc_lo3;
};
#endif
#if _MIPS_SIM == _MIPS_SIM_ABI64 || _MIPS_SIM == _MIPS_SIM_NABI32
#include <linux/posix_types.h>
struct sigcontext {
  __u64 sc_regs[32];
  __u64 sc_fpregs[32];
  __u64 sc_mdhi;
  __u64 sc_hi1;
  __u64 sc_hi2;
  __u64 sc_hi3;
  __u64 sc_mdlo;
  __u64 sc_lo1;
  __u64 sc_lo2;
  __u64 sc_lo3;
  __u64 sc_pc;
  __u32 sc_fpc_csr;
  __u32 sc_used_math;
  __u32 sc_dsp;
  __u32 sc_reserved;
};
#endif
#endif