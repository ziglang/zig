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
#ifndef _ASM_X86_PERF_REGS_H
#define _ASM_X86_PERF_REGS_H
enum perf_event_x86_regs {
  PERF_REG_X86_AX,
  PERF_REG_X86_BX,
  PERF_REG_X86_CX,
  PERF_REG_X86_DX,
  PERF_REG_X86_SI,
  PERF_REG_X86_DI,
  PERF_REG_X86_BP,
  PERF_REG_X86_SP,
  PERF_REG_X86_IP,
  PERF_REG_X86_FLAGS,
  PERF_REG_X86_CS,
  PERF_REG_X86_SS,
  PERF_REG_X86_DS,
  PERF_REG_X86_ES,
  PERF_REG_X86_FS,
  PERF_REG_X86_GS,
  PERF_REG_X86_R8,
  PERF_REG_X86_R9,
  PERF_REG_X86_R10,
  PERF_REG_X86_R11,
  PERF_REG_X86_R12,
  PERF_REG_X86_R13,
  PERF_REG_X86_R14,
  PERF_REG_X86_R15,
  PERF_REG_X86_32_MAX = PERF_REG_X86_GS + 1,
  PERF_REG_X86_64_MAX = PERF_REG_X86_R15 + 1,
  PERF_REG_X86_XMM0 = 32,
  PERF_REG_X86_XMM1 = 34,
  PERF_REG_X86_XMM2 = 36,
  PERF_REG_X86_XMM3 = 38,
  PERF_REG_X86_XMM4 = 40,
  PERF_REG_X86_XMM5 = 42,
  PERF_REG_X86_XMM6 = 44,
  PERF_REG_X86_XMM7 = 46,
  PERF_REG_X86_XMM8 = 48,
  PERF_REG_X86_XMM9 = 50,
  PERF_REG_X86_XMM10 = 52,
  PERF_REG_X86_XMM11 = 54,
  PERF_REG_X86_XMM12 = 56,
  PERF_REG_X86_XMM13 = 58,
  PERF_REG_X86_XMM14 = 60,
  PERF_REG_X86_XMM15 = 62,
  PERF_REG_X86_XMM_MAX = PERF_REG_X86_XMM15 + 2,
};
#define PERF_REG_EXTENDED_MASK (~((1ULL << PERF_REG_X86_XMM0) - 1))
#endif
