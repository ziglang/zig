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
#ifndef _UAPI__ASM_PTRACE_H
#define _UAPI__ASM_PTRACE_H
#include <linux/types.h>
#include <asm/hwcap.h>
#include <asm/sve_context.h>
#define PSR_MODE_EL0t 0x00000000
#define PSR_MODE_EL1t 0x00000004
#define PSR_MODE_EL1h 0x00000005
#define PSR_MODE_EL2t 0x00000008
#define PSR_MODE_EL2h 0x00000009
#define PSR_MODE_EL3t 0x0000000c
#define PSR_MODE_EL3h 0x0000000d
#define PSR_MODE_MASK 0x0000000f
#define PSR_MODE32_BIT 0x00000010
#define PSR_F_BIT 0x00000040
#define PSR_I_BIT 0x00000080
#define PSR_A_BIT 0x00000100
#define PSR_D_BIT 0x00000200
#define PSR_BTYPE_MASK 0x00000c00
#define PSR_SSBS_BIT 0x00001000
#define PSR_PAN_BIT 0x00400000
#define PSR_UAO_BIT 0x00800000
#define PSR_DIT_BIT 0x01000000
#define PSR_TCO_BIT 0x02000000
#define PSR_V_BIT 0x10000000
#define PSR_C_BIT 0x20000000
#define PSR_Z_BIT 0x40000000
#define PSR_N_BIT 0x80000000
#define PSR_BTYPE_SHIFT 10
#define PSR_f 0xff000000
#define PSR_s 0x00ff0000
#define PSR_x 0x0000ff00
#define PSR_c 0x000000ff
#define PSR_BTYPE_NONE (0b00 << PSR_BTYPE_SHIFT)
#define PSR_BTYPE_JC (0b01 << PSR_BTYPE_SHIFT)
#define PSR_BTYPE_C (0b10 << PSR_BTYPE_SHIFT)
#define PSR_BTYPE_J (0b11 << PSR_BTYPE_SHIFT)
#define PTRACE_SYSEMU 31
#define PTRACE_SYSEMU_SINGLESTEP 32
#define PTRACE_PEEKMTETAGS 33
#define PTRACE_POKEMTETAGS 34
#ifndef __ASSEMBLY__
struct user_pt_regs {
  __u64 regs[31];
  __u64 sp;
  __u64 pc;
  __u64 pstate;
};
struct user_fpsimd_state {
  __uint128_t vregs[32];
  __u32 fpsr;
  __u32 fpcr;
  __u32 __reserved[2];
};
struct user_hwdebug_state {
  __u32 dbg_info;
  __u32 pad;
  struct {
    __u64 addr;
    __u32 ctrl;
    __u32 pad;
  } dbg_regs[16];
};
struct user_sve_header {
  __u32 size;
  __u32 max_size;
  __u16 vl;
  __u16 max_vl;
  __u16 flags;
  __u16 __reserved;
};
#define SVE_PT_REGS_MASK (1 << 0)
#define SVE_PT_REGS_FPSIMD 0
#define SVE_PT_REGS_SVE SVE_PT_REGS_MASK
#define SVE_PT_VL_INHERIT ((1 << 17) >> 16)
#define SVE_PT_VL_ONEXEC ((1 << 18) >> 16)
#define SVE_PT_REGS_OFFSET ((sizeof(struct user_sve_header) + (__SVE_VQ_BYTES - 1)) / __SVE_VQ_BYTES * __SVE_VQ_BYTES)
#define SVE_PT_FPSIMD_OFFSET SVE_PT_REGS_OFFSET
#define SVE_PT_FPSIMD_SIZE(vq,flags) (sizeof(struct user_fpsimd_state))
#define SVE_PT_SVE_ZREG_SIZE(vq) __SVE_ZREG_SIZE(vq)
#define SVE_PT_SVE_PREG_SIZE(vq) __SVE_PREG_SIZE(vq)
#define SVE_PT_SVE_FFR_SIZE(vq) __SVE_FFR_SIZE(vq)
#define SVE_PT_SVE_FPSR_SIZE sizeof(__u32)
#define SVE_PT_SVE_FPCR_SIZE sizeof(__u32)
#define SVE_PT_SVE_OFFSET SVE_PT_REGS_OFFSET
#define SVE_PT_SVE_ZREGS_OFFSET (SVE_PT_REGS_OFFSET + __SVE_ZREGS_OFFSET)
#define SVE_PT_SVE_ZREG_OFFSET(vq,n) (SVE_PT_REGS_OFFSET + __SVE_ZREG_OFFSET(vq, n))
#define SVE_PT_SVE_ZREGS_SIZE(vq) (SVE_PT_SVE_ZREG_OFFSET(vq, __SVE_NUM_ZREGS) - SVE_PT_SVE_ZREGS_OFFSET)
#define SVE_PT_SVE_PREGS_OFFSET(vq) (SVE_PT_REGS_OFFSET + __SVE_PREGS_OFFSET(vq))
#define SVE_PT_SVE_PREG_OFFSET(vq,n) (SVE_PT_REGS_OFFSET + __SVE_PREG_OFFSET(vq, n))
#define SVE_PT_SVE_PREGS_SIZE(vq) (SVE_PT_SVE_PREG_OFFSET(vq, __SVE_NUM_PREGS) - SVE_PT_SVE_PREGS_OFFSET(vq))
#define SVE_PT_SVE_FFR_OFFSET(vq) (SVE_PT_REGS_OFFSET + __SVE_FFR_OFFSET(vq))
#define SVE_PT_SVE_FPSR_OFFSET(vq) ((SVE_PT_SVE_FFR_OFFSET(vq) + SVE_PT_SVE_FFR_SIZE(vq) + (__SVE_VQ_BYTES - 1)) / __SVE_VQ_BYTES * __SVE_VQ_BYTES)
#define SVE_PT_SVE_FPCR_OFFSET(vq) (SVE_PT_SVE_FPSR_OFFSET(vq) + SVE_PT_SVE_FPSR_SIZE)
#define SVE_PT_SVE_SIZE(vq,flags) ((SVE_PT_SVE_FPCR_OFFSET(vq) + SVE_PT_SVE_FPCR_SIZE - SVE_PT_SVE_OFFSET + (__SVE_VQ_BYTES - 1)) / __SVE_VQ_BYTES * __SVE_VQ_BYTES)
#define SVE_PT_SIZE(vq,flags) (((flags) & SVE_PT_REGS_MASK) == SVE_PT_REGS_SVE ? SVE_PT_SVE_OFFSET + SVE_PT_SVE_SIZE(vq, flags) : SVE_PT_FPSIMD_OFFSET + SVE_PT_FPSIMD_SIZE(vq, flags))
struct user_pac_mask {
  __u64 data_mask;
  __u64 insn_mask;
};
struct user_pac_address_keys {
  __uint128_t apiakey;
  __uint128_t apibkey;
  __uint128_t apdakey;
  __uint128_t apdbkey;
};
struct user_pac_generic_keys {
  __uint128_t apgakey;
};
#endif
#endif
