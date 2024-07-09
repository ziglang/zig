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
#ifndef _UAPI_ASM_X86_PROCESSOR_FLAGS_H
#define _UAPI_ASM_X86_PROCESSOR_FLAGS_H
#include <linux/const.h>
#define X86_EFLAGS_CF_BIT 0
#define X86_EFLAGS_CF _BITUL(X86_EFLAGS_CF_BIT)
#define X86_EFLAGS_FIXED_BIT 1
#define X86_EFLAGS_FIXED _BITUL(X86_EFLAGS_FIXED_BIT)
#define X86_EFLAGS_PF_BIT 2
#define X86_EFLAGS_PF _BITUL(X86_EFLAGS_PF_BIT)
#define X86_EFLAGS_AF_BIT 4
#define X86_EFLAGS_AF _BITUL(X86_EFLAGS_AF_BIT)
#define X86_EFLAGS_ZF_BIT 6
#define X86_EFLAGS_ZF _BITUL(X86_EFLAGS_ZF_BIT)
#define X86_EFLAGS_SF_BIT 7
#define X86_EFLAGS_SF _BITUL(X86_EFLAGS_SF_BIT)
#define X86_EFLAGS_TF_BIT 8
#define X86_EFLAGS_TF _BITUL(X86_EFLAGS_TF_BIT)
#define X86_EFLAGS_IF_BIT 9
#define X86_EFLAGS_IF _BITUL(X86_EFLAGS_IF_BIT)
#define X86_EFLAGS_DF_BIT 10
#define X86_EFLAGS_DF _BITUL(X86_EFLAGS_DF_BIT)
#define X86_EFLAGS_OF_BIT 11
#define X86_EFLAGS_OF _BITUL(X86_EFLAGS_OF_BIT)
#define X86_EFLAGS_IOPL_BIT 12
#define X86_EFLAGS_IOPL (_AC(3, UL) << X86_EFLAGS_IOPL_BIT)
#define X86_EFLAGS_NT_BIT 14
#define X86_EFLAGS_NT _BITUL(X86_EFLAGS_NT_BIT)
#define X86_EFLAGS_RF_BIT 16
#define X86_EFLAGS_RF _BITUL(X86_EFLAGS_RF_BIT)
#define X86_EFLAGS_VM_BIT 17
#define X86_EFLAGS_VM _BITUL(X86_EFLAGS_VM_BIT)
#define X86_EFLAGS_AC_BIT 18
#define X86_EFLAGS_AC _BITUL(X86_EFLAGS_AC_BIT)
#define X86_EFLAGS_VIF_BIT 19
#define X86_EFLAGS_VIF _BITUL(X86_EFLAGS_VIF_BIT)
#define X86_EFLAGS_VIP_BIT 20
#define X86_EFLAGS_VIP _BITUL(X86_EFLAGS_VIP_BIT)
#define X86_EFLAGS_ID_BIT 21
#define X86_EFLAGS_ID _BITUL(X86_EFLAGS_ID_BIT)
#define X86_CR0_PE_BIT 0
#define X86_CR0_PE _BITUL(X86_CR0_PE_BIT)
#define X86_CR0_MP_BIT 1
#define X86_CR0_MP _BITUL(X86_CR0_MP_BIT)
#define X86_CR0_EM_BIT 2
#define X86_CR0_EM _BITUL(X86_CR0_EM_BIT)
#define X86_CR0_TS_BIT 3
#define X86_CR0_TS _BITUL(X86_CR0_TS_BIT)
#define X86_CR0_ET_BIT 4
#define X86_CR0_ET _BITUL(X86_CR0_ET_BIT)
#define X86_CR0_NE_BIT 5
#define X86_CR0_NE _BITUL(X86_CR0_NE_BIT)
#define X86_CR0_WP_BIT 16
#define X86_CR0_WP _BITUL(X86_CR0_WP_BIT)
#define X86_CR0_AM_BIT 18
#define X86_CR0_AM _BITUL(X86_CR0_AM_BIT)
#define X86_CR0_NW_BIT 29
#define X86_CR0_NW _BITUL(X86_CR0_NW_BIT)
#define X86_CR0_CD_BIT 30
#define X86_CR0_CD _BITUL(X86_CR0_CD_BIT)
#define X86_CR0_PG_BIT 31
#define X86_CR0_PG _BITUL(X86_CR0_PG_BIT)
#define X86_CR3_PWT_BIT 3
#define X86_CR3_PWT _BITUL(X86_CR3_PWT_BIT)
#define X86_CR3_PCD_BIT 4
#define X86_CR3_PCD _BITUL(X86_CR3_PCD_BIT)
#define X86_CR3_PCID_BITS 12
#define X86_CR3_PCID_MASK (_AC((1UL << X86_CR3_PCID_BITS) - 1, UL))
#define X86_CR3_PCID_NOFLUSH_BIT 63
#define X86_CR3_PCID_NOFLUSH _BITULL(X86_CR3_PCID_NOFLUSH_BIT)
#define X86_CR4_VME_BIT 0
#define X86_CR4_VME _BITUL(X86_CR4_VME_BIT)
#define X86_CR4_PVI_BIT 1
#define X86_CR4_PVI _BITUL(X86_CR4_PVI_BIT)
#define X86_CR4_TSD_BIT 2
#define X86_CR4_TSD _BITUL(X86_CR4_TSD_BIT)
#define X86_CR4_DE_BIT 3
#define X86_CR4_DE _BITUL(X86_CR4_DE_BIT)
#define X86_CR4_PSE_BIT 4
#define X86_CR4_PSE _BITUL(X86_CR4_PSE_BIT)
#define X86_CR4_PAE_BIT 5
#define X86_CR4_PAE _BITUL(X86_CR4_PAE_BIT)
#define X86_CR4_MCE_BIT 6
#define X86_CR4_MCE _BITUL(X86_CR4_MCE_BIT)
#define X86_CR4_PGE_BIT 7
#define X86_CR4_PGE _BITUL(X86_CR4_PGE_BIT)
#define X86_CR4_PCE_BIT 8
#define X86_CR4_PCE _BITUL(X86_CR4_PCE_BIT)
#define X86_CR4_OSFXSR_BIT 9
#define X86_CR4_OSFXSR _BITUL(X86_CR4_OSFXSR_BIT)
#define X86_CR4_OSXMMEXCPT_BIT 10
#define X86_CR4_OSXMMEXCPT _BITUL(X86_CR4_OSXMMEXCPT_BIT)
#define X86_CR4_UMIP_BIT 11
#define X86_CR4_UMIP _BITUL(X86_CR4_UMIP_BIT)
#define X86_CR4_LA57_BIT 12
#define X86_CR4_LA57 _BITUL(X86_CR4_LA57_BIT)
#define X86_CR4_VMXE_BIT 13
#define X86_CR4_VMXE _BITUL(X86_CR4_VMXE_BIT)
#define X86_CR4_SMXE_BIT 14
#define X86_CR4_SMXE _BITUL(X86_CR4_SMXE_BIT)
#define X86_CR4_FSGSBASE_BIT 16
#define X86_CR4_FSGSBASE _BITUL(X86_CR4_FSGSBASE_BIT)
#define X86_CR4_PCIDE_BIT 17
#define X86_CR4_PCIDE _BITUL(X86_CR4_PCIDE_BIT)
#define X86_CR4_OSXSAVE_BIT 18
#define X86_CR4_OSXSAVE _BITUL(X86_CR4_OSXSAVE_BIT)
#define X86_CR4_SMEP_BIT 20
#define X86_CR4_SMEP _BITUL(X86_CR4_SMEP_BIT)
#define X86_CR4_SMAP_BIT 21
#define X86_CR4_SMAP _BITUL(X86_CR4_SMAP_BIT)
#define X86_CR4_PKE_BIT 22
#define X86_CR4_PKE _BITUL(X86_CR4_PKE_BIT)
#define X86_CR8_TPR _AC(0x0000000f, UL)
#define CX86_PCR0 0x20
#define CX86_GCR 0xb8
#define CX86_CCR0 0xc0
#define CX86_CCR1 0xc1
#define CX86_CCR2 0xc2
#define CX86_CCR3 0xc3
#define CX86_CCR4 0xe8
#define CX86_CCR5 0xe9
#define CX86_CCR6 0xea
#define CX86_CCR7 0xeb
#define CX86_PCR1 0xf0
#define CX86_DIR0 0xfe
#define CX86_DIR1 0xff
#define CX86_ARR_BASE 0xc4
#define CX86_RCR_BASE 0xdc
#define CR0_STATE (X86_CR0_PE | X86_CR0_MP | X86_CR0_ET | X86_CR0_NE | X86_CR0_WP | X86_CR0_AM | X86_CR0_PG)
#endif
