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
#ifndef _UAPI__ASM_ARM_PTRACE_H
#define _UAPI__ASM_ARM_PTRACE_H
#include <asm/hwcap.h>
#define PTRACE_GETREGS 12
#define PTRACE_SETREGS 13
#define PTRACE_GETFPREGS 14
#define PTRACE_SETFPREGS 15
#define PTRACE_GETWMMXREGS 18
#define PTRACE_SETWMMXREGS 19
#define PTRACE_OLDSETOPTIONS 21
#define PTRACE_GET_THREAD_AREA 22
#define PTRACE_SET_SYSCALL 23
#define PTRACE_GETCRUNCHREGS 25
#define PTRACE_SETCRUNCHREGS 26
#define PTRACE_GETVFPREGS 27
#define PTRACE_SETVFPREGS 28
#define PTRACE_GETHBPREGS 29
#define PTRACE_SETHBPREGS 30
#define PTRACE_GETFDPIC 31
#define PTRACE_GETFDPIC_EXEC 0
#define PTRACE_GETFDPIC_INTERP 1
#define USR26_MODE 0x00000000
#define FIQ26_MODE 0x00000001
#define IRQ26_MODE 0x00000002
#define SVC26_MODE 0x00000003
#define USR_MODE 0x00000010
#define SVC_MODE 0x00000013
#define FIQ_MODE 0x00000011
#define IRQ_MODE 0x00000012
#define MON_MODE 0x00000016
#define ABT_MODE 0x00000017
#define HYP_MODE 0x0000001a
#define UND_MODE 0x0000001b
#define SYSTEM_MODE 0x0000001f
#define MODE32_BIT 0x00000010
#define MODE_MASK 0x0000001f
#define V4_PSR_T_BIT 0x00000020
#define V7M_PSR_T_BIT 0x01000000
#define PSR_T_BIT V4_PSR_T_BIT
#define PSR_F_BIT 0x00000040
#define PSR_I_BIT 0x00000080
#define PSR_A_BIT 0x00000100
#define PSR_E_BIT 0x00000200
#define PSR_J_BIT 0x01000000
#define PSR_Q_BIT 0x08000000
#define PSR_V_BIT 0x10000000
#define PSR_C_BIT 0x20000000
#define PSR_Z_BIT 0x40000000
#define PSR_N_BIT 0x80000000
#define PSR_f 0xff000000
#define PSR_s 0x00ff0000
#define PSR_x 0x0000ff00
#define PSR_c 0x000000ff
#define APSR_MASK 0xf80f0000
#define PSR_ISET_MASK 0x01000010
#define PSR_IT_MASK 0x0600fc00
#define PSR_ENDIAN_MASK 0x00000200
#define PSR_ENDSTATE 0
#define PT_TEXT_ADDR 0x10000
#define PT_DATA_ADDR 0x10004
#define PT_TEXT_END_ADDR 0x10008
#ifndef __ASSEMBLY__
struct pt_regs {
  long uregs[18];
};
#define ARM_cpsr uregs[16]
#define ARM_pc uregs[15]
#define ARM_lr uregs[14]
#define ARM_sp uregs[13]
#define ARM_ip uregs[12]
#define ARM_fp uregs[11]
#define ARM_r10 uregs[10]
#define ARM_r9 uregs[9]
#define ARM_r8 uregs[8]
#define ARM_r7 uregs[7]
#define ARM_r6 uregs[6]
#define ARM_r5 uregs[5]
#define ARM_r4 uregs[4]
#define ARM_r3 uregs[3]
#define ARM_r2 uregs[2]
#define ARM_r1 uregs[1]
#define ARM_r0 uregs[0]
#define ARM_ORIG_r0 uregs[17]
#define ARM_VFPREGS_SIZE (32 * 8 + 4)
#endif
#endif
