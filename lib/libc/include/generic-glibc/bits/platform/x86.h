/* Constants and data structures for x86 CPU features.
   This file is part of the GNU C Library.
   Copyright (C) 2008-2024 Free Software Foundation, Inc.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_PLATFORM_X86_H
# error "Never include <bits/platform/x86.h> directly; use <sys/platform/x86.h> instead."
#endif

enum
{
  CPUID_INDEX_1 = 0,
  CPUID_INDEX_7,
  CPUID_INDEX_80000001,
  CPUID_INDEX_D_ECX_1,
  CPUID_INDEX_80000007,
  CPUID_INDEX_80000008,
  CPUID_INDEX_7_ECX_1,
  CPUID_INDEX_19,
  CPUID_INDEX_14_ECX_0,
  CPUID_INDEX_24_ECX_0
};

struct cpuid_feature
{
  unsigned int cpuid_array[4];
  unsigned int active_array[4];
};

enum cpuid_register_index
{
  cpuid_register_index_eax = 0,
  cpuid_register_index_ebx,
  cpuid_register_index_ecx,
  cpuid_register_index_edx
};

/* CPU features.  */

enum
{
  x86_cpu_index_1_ecx
    = (CPUID_INDEX_1 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ecx * 8 * sizeof (unsigned int)),

  x86_cpu_SSE3			= x86_cpu_index_1_ecx,
  x86_cpu_PCLMULQDQ		= x86_cpu_index_1_ecx + 1,
  x86_cpu_DTES64		= x86_cpu_index_1_ecx + 2,
  x86_cpu_MONITOR		= x86_cpu_index_1_ecx + 3,
  x86_cpu_DS_CPL		= x86_cpu_index_1_ecx + 4,
  x86_cpu_VMX			= x86_cpu_index_1_ecx + 5,
  x86_cpu_SMX			= x86_cpu_index_1_ecx + 6,
  x86_cpu_EIST			= x86_cpu_index_1_ecx + 7,
  x86_cpu_TM2			= x86_cpu_index_1_ecx + 8,
  x86_cpu_SSSE3			= x86_cpu_index_1_ecx + 9,
  x86_cpu_CNXT_ID		= x86_cpu_index_1_ecx + 10,
  x86_cpu_SDBG			= x86_cpu_index_1_ecx + 11,
  x86_cpu_FMA			= x86_cpu_index_1_ecx + 12,
  x86_cpu_CMPXCHG16B		= x86_cpu_index_1_ecx + 13,
  x86_cpu_XTPRUPDCTRL		= x86_cpu_index_1_ecx + 14,
  x86_cpu_PDCM			= x86_cpu_index_1_ecx + 15,
  x86_cpu_INDEX_1_ECX_16	= x86_cpu_index_1_ecx + 16,
  x86_cpu_PCID			= x86_cpu_index_1_ecx + 17,
  x86_cpu_DCA			= x86_cpu_index_1_ecx + 18,
  x86_cpu_SSE4_1		= x86_cpu_index_1_ecx + 19,
  x86_cpu_SSE4_2		= x86_cpu_index_1_ecx + 20,
  x86_cpu_X2APIC		= x86_cpu_index_1_ecx + 21,
  x86_cpu_MOVBE			= x86_cpu_index_1_ecx + 22,
  x86_cpu_POPCNT		= x86_cpu_index_1_ecx + 23,
  x86_cpu_TSC_DEADLINE		= x86_cpu_index_1_ecx + 24,
  x86_cpu_AES			= x86_cpu_index_1_ecx + 25,
  x86_cpu_XSAVE			= x86_cpu_index_1_ecx + 26,
  x86_cpu_OSXSAVE		= x86_cpu_index_1_ecx + 27,
  x86_cpu_AVX			= x86_cpu_index_1_ecx + 28,
  x86_cpu_F16C			= x86_cpu_index_1_ecx + 29,
  x86_cpu_RDRAND		= x86_cpu_index_1_ecx + 30,
  x86_cpu_INDEX_1_ECX_31	= x86_cpu_index_1_ecx + 31,

  x86_cpu_index_1_edx
    = (CPUID_INDEX_1 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_edx * 8 * sizeof (unsigned int)),

  x86_cpu_FPU			= x86_cpu_index_1_edx,
  x86_cpu_VME			= x86_cpu_index_1_edx + 1,
  x86_cpu_DE			= x86_cpu_index_1_edx + 2,
  x86_cpu_PSE			= x86_cpu_index_1_edx + 3,
  x86_cpu_TSC			= x86_cpu_index_1_edx + 4,
  x86_cpu_MSR			= x86_cpu_index_1_edx + 5,
  x86_cpu_PAE			= x86_cpu_index_1_edx + 6,
  x86_cpu_MCE			= x86_cpu_index_1_edx + 7,
  x86_cpu_CX8			= x86_cpu_index_1_edx + 8,
  x86_cpu_APIC			= x86_cpu_index_1_edx + 9,
  x86_cpu_INDEX_1_EDX_10	= x86_cpu_index_1_edx + 10,
  x86_cpu_SEP			= x86_cpu_index_1_edx + 11,
  x86_cpu_MTRR			= x86_cpu_index_1_edx + 12,
  x86_cpu_PGE			= x86_cpu_index_1_edx + 13,
  x86_cpu_MCA			= x86_cpu_index_1_edx + 14,
  x86_cpu_CMOV			= x86_cpu_index_1_edx + 15,
  x86_cpu_PAT			= x86_cpu_index_1_edx + 16,
  x86_cpu_PSE_36		= x86_cpu_index_1_edx + 17,
  x86_cpu_PSN			= x86_cpu_index_1_edx + 18,
  x86_cpu_CLFSH			= x86_cpu_index_1_edx + 19,
  x86_cpu_INDEX_1_EDX_20	= x86_cpu_index_1_edx + 20,
  x86_cpu_DS			= x86_cpu_index_1_edx + 21,
  x86_cpu_ACPI			= x86_cpu_index_1_edx + 22,
  x86_cpu_MMX			= x86_cpu_index_1_edx + 23,
  x86_cpu_FXSR			= x86_cpu_index_1_edx + 24,
  x86_cpu_SSE			= x86_cpu_index_1_edx + 25,
  x86_cpu_SSE2			= x86_cpu_index_1_edx + 26,
  x86_cpu_SS			= x86_cpu_index_1_edx + 27,
  x86_cpu_HTT			= x86_cpu_index_1_edx + 28,
  x86_cpu_TM			= x86_cpu_index_1_edx + 29,
  x86_cpu_INDEX_1_EDX_30	= x86_cpu_index_1_edx + 30,
  x86_cpu_PBE			= x86_cpu_index_1_edx + 31,

  x86_cpu_index_7_ebx
    = (CPUID_INDEX_7 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ebx * 8 * sizeof (unsigned int)),

  x86_cpu_FSGSBASE		= x86_cpu_index_7_ebx,
  x86_cpu_TSC_ADJUST		= x86_cpu_index_7_ebx + 1,
  x86_cpu_SGX			= x86_cpu_index_7_ebx + 2,
  x86_cpu_BMI1			= x86_cpu_index_7_ebx + 3,
  x86_cpu_HLE			= x86_cpu_index_7_ebx + 4,
  x86_cpu_AVX2			= x86_cpu_index_7_ebx + 5,
  x86_cpu_INDEX_7_EBX_6		= x86_cpu_index_7_ebx + 6,
  x86_cpu_SMEP			= x86_cpu_index_7_ebx + 7,
  x86_cpu_BMI2			= x86_cpu_index_7_ebx + 8,
  x86_cpu_ERMS			= x86_cpu_index_7_ebx + 9,
  x86_cpu_INVPCID		= x86_cpu_index_7_ebx + 10,
  x86_cpu_RTM			= x86_cpu_index_7_ebx + 11,
  x86_cpu_RDT_M			= x86_cpu_index_7_ebx + 12,
  x86_cpu_DEPR_FPU_CS_DS	= x86_cpu_index_7_ebx + 13,
  x86_cpu_MPX			= x86_cpu_index_7_ebx + 14,
  x86_cpu_RDT_A			= x86_cpu_index_7_ebx + 15,
  x86_cpu_AVX512F		= x86_cpu_index_7_ebx + 16,
  x86_cpu_AVX512DQ		= x86_cpu_index_7_ebx + 17,
  x86_cpu_RDSEED		= x86_cpu_index_7_ebx + 18,
  x86_cpu_ADX			= x86_cpu_index_7_ebx + 19,
  x86_cpu_SMAP			= x86_cpu_index_7_ebx + 20,
  x86_cpu_AVX512_IFMA		= x86_cpu_index_7_ebx + 21,
  x86_cpu_INDEX_7_EBX_22	= x86_cpu_index_7_ebx + 22,
  x86_cpu_CLFLUSHOPT		= x86_cpu_index_7_ebx + 23,
  x86_cpu_CLWB			= x86_cpu_index_7_ebx + 24,
  x86_cpu_TRACE			= x86_cpu_index_7_ebx + 25,
  x86_cpu_AVX512PF		= x86_cpu_index_7_ebx + 26,
  x86_cpu_AVX512ER		= x86_cpu_index_7_ebx + 27,
  x86_cpu_AVX512CD		= x86_cpu_index_7_ebx + 28,
  x86_cpu_SHA			= x86_cpu_index_7_ebx + 29,
  x86_cpu_AVX512BW		= x86_cpu_index_7_ebx + 30,
  x86_cpu_AVX512VL		= x86_cpu_index_7_ebx + 31,

  x86_cpu_index_7_ecx
    = (CPUID_INDEX_7 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ecx * 8 * sizeof (unsigned int)),

  x86_cpu_PREFETCHWT1		= x86_cpu_index_7_ecx,
  x86_cpu_AVX512_VBMI		= x86_cpu_index_7_ecx + 1,
  x86_cpu_UMIP			= x86_cpu_index_7_ecx + 2,
  x86_cpu_PKU			= x86_cpu_index_7_ecx + 3,
  x86_cpu_OSPKE			= x86_cpu_index_7_ecx + 4,
  x86_cpu_WAITPKG		= x86_cpu_index_7_ecx + 5,
  x86_cpu_AVX512_VBMI2		= x86_cpu_index_7_ecx + 6,
  x86_cpu_SHSTK			= x86_cpu_index_7_ecx + 7,
  x86_cpu_GFNI			= x86_cpu_index_7_ecx + 8,
  x86_cpu_VAES			= x86_cpu_index_7_ecx + 9,
  x86_cpu_VPCLMULQDQ		= x86_cpu_index_7_ecx + 10,
  x86_cpu_AVX512_VNNI		= x86_cpu_index_7_ecx + 11,
  x86_cpu_AVX512_BITALG		= x86_cpu_index_7_ecx + 12,
  x86_cpu_INDEX_7_ECX_13	= x86_cpu_index_7_ecx + 13,
  x86_cpu_AVX512_VPOPCNTDQ	= x86_cpu_index_7_ecx + 14,
  x86_cpu_INDEX_7_ECX_15	= x86_cpu_index_7_ecx + 15,
  x86_cpu_LA57			= x86_cpu_index_7_ecx + 16,
/* Note: Bits 17-21: The value of MAWAU used by the BNDLDX and BNDSTX
   instructions in 64-bit mode.  */
  x86_cpu_RDPID			= x86_cpu_index_7_ecx + 22,
  x86_cpu_KL			= x86_cpu_index_7_ecx + 23,
  x86_cpu_BUS_LOCK_DETECT	= x86_cpu_index_7_ecx + 24,
  x86_cpu_CLDEMOTE		= x86_cpu_index_7_ecx + 25,
  x86_cpu_INDEX_7_ECX_26	= x86_cpu_index_7_ecx + 26,
  x86_cpu_MOVDIRI		= x86_cpu_index_7_ecx + 27,
  x86_cpu_MOVDIR64B		= x86_cpu_index_7_ecx + 28,
  x86_cpu_ENQCMD		= x86_cpu_index_7_ecx + 29,
  x86_cpu_SGX_LC		= x86_cpu_index_7_ecx + 30,
  x86_cpu_PKS			= x86_cpu_index_7_ecx + 31,

  x86_cpu_index_7_edx
    = (CPUID_INDEX_7 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_edx * 8 * sizeof (unsigned int)),

  x86_cpu_INDEX_7_EDX_0		= x86_cpu_index_7_edx,
  x86_cpu_SGX_KEYS		= x86_cpu_index_7_edx + 1,
  x86_cpu_AVX512_4VNNIW		= x86_cpu_index_7_edx + 2,
  x86_cpu_AVX512_4FMAPS		= x86_cpu_index_7_edx + 3,
  x86_cpu_FSRM			= x86_cpu_index_7_edx + 4,
  x86_cpu_UINTR			= x86_cpu_index_7_edx + 5,
  x86_cpu_INDEX_7_EDX_6		= x86_cpu_index_7_edx + 6,
  x86_cpu_INDEX_7_EDX_7		= x86_cpu_index_7_edx + 7,
  x86_cpu_AVX512_VP2INTERSECT	= x86_cpu_index_7_edx + 8,
  x86_cpu_INDEX_7_EDX_9		= x86_cpu_index_7_edx + 9,
  x86_cpu_MD_CLEAR		= x86_cpu_index_7_edx + 10,
  x86_cpu_RTM_ALWAYS_ABORT	= x86_cpu_index_7_edx + 11,
  x86_cpu_INDEX_7_EDX_12	= x86_cpu_index_7_edx + 12,
  x86_cpu_RTM_FORCE_ABORT	= x86_cpu_index_7_edx + 13,
  x86_cpu_SERIALIZE		= x86_cpu_index_7_edx + 14,
  x86_cpu_HYBRID		= x86_cpu_index_7_edx + 15,
  x86_cpu_TSXLDTRK		= x86_cpu_index_7_edx + 16,
  x86_cpu_INDEX_7_EDX_17	= x86_cpu_index_7_edx + 17,
  x86_cpu_PCONFIG		= x86_cpu_index_7_edx + 18,
  x86_cpu_LBR			= x86_cpu_index_7_edx + 19,
  x86_cpu_IBT			= x86_cpu_index_7_edx + 20,
  x86_cpu_INDEX_7_EDX_21	= x86_cpu_index_7_edx + 21,
  x86_cpu_AMX_BF16		= x86_cpu_index_7_edx + 22,
  x86_cpu_AVX512_FP16		= x86_cpu_index_7_edx + 23,
  x86_cpu_AMX_TILE		= x86_cpu_index_7_edx + 24,
  x86_cpu_AMX_INT8		= x86_cpu_index_7_edx + 25,
  x86_cpu_IBRS_IBPB		= x86_cpu_index_7_edx + 26,
  x86_cpu_STIBP			= x86_cpu_index_7_edx + 27,
  x86_cpu_L1D_FLUSH		= x86_cpu_index_7_edx + 28,
  x86_cpu_ARCH_CAPABILITIES	= x86_cpu_index_7_edx + 29,
  x86_cpu_CORE_CAPABILITIES	= x86_cpu_index_7_edx + 30,
  x86_cpu_SSBD			= x86_cpu_index_7_edx + 31,

  x86_cpu_index_80000001_ecx
    = (CPUID_INDEX_80000001 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ecx * 8 * sizeof (unsigned int)),

  x86_cpu_LAHF64_SAHF64		= x86_cpu_index_80000001_ecx,
  x86_cpu_SVM			= x86_cpu_index_80000001_ecx + 2,
  x86_cpu_LZCNT			= x86_cpu_index_80000001_ecx + 5,
  x86_cpu_SSE4A			= x86_cpu_index_80000001_ecx + 6,
  x86_cpu_PREFETCHW		= x86_cpu_index_80000001_ecx + 8,
  x86_cpu_XOP			= x86_cpu_index_80000001_ecx + 11,
  x86_cpu_LWP			= x86_cpu_index_80000001_ecx + 15,
  x86_cpu_FMA4			= x86_cpu_index_80000001_ecx + 16,
  x86_cpu_TBM			= x86_cpu_index_80000001_ecx + 21,

  x86_cpu_index_80000001_edx
    = (CPUID_INDEX_80000001 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_edx * 8 * sizeof (unsigned int)),

  x86_cpu_SYSCALL_SYSRET	= x86_cpu_index_80000001_edx + 11,
  x86_cpu_NX			= x86_cpu_index_80000001_edx + 20,
  x86_cpu_PAGE1GB		= x86_cpu_index_80000001_edx + 26,
  x86_cpu_RDTSCP		= x86_cpu_index_80000001_edx + 27,
  x86_cpu_LM			= x86_cpu_index_80000001_edx + 29,

  x86_cpu_index_d_ecx_1_eax
    = (CPUID_INDEX_D_ECX_1 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_eax * 8 * sizeof (unsigned int)),

  x86_cpu_XSAVEOPT		= x86_cpu_index_d_ecx_1_eax,
  x86_cpu_XSAVEC		= x86_cpu_index_d_ecx_1_eax + 1,
  x86_cpu_XGETBV_ECX_1		= x86_cpu_index_d_ecx_1_eax + 2,
  x86_cpu_XSAVES		= x86_cpu_index_d_ecx_1_eax + 3,
  x86_cpu_XFD			= x86_cpu_index_d_ecx_1_eax + 4,

  x86_cpu_index_80000007_edx
    = (CPUID_INDEX_80000007 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_edx * 8 * sizeof (unsigned int)),

  x86_cpu_INVARIANT_TSC		= x86_cpu_index_80000007_edx + 8,

  x86_cpu_index_80000008_ebx
    = (CPUID_INDEX_80000008 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ebx * 8 * sizeof (unsigned int)),

  x86_cpu_WBNOINVD		= x86_cpu_index_80000008_ebx + 9,
  x86_cpu_AMD_IBPB	        = x86_cpu_index_80000008_ebx + 12,
  x86_cpu_AMD_IBRS	        = x86_cpu_index_80000008_ebx + 14,
  x86_cpu_AMD_STIBP	        = x86_cpu_index_80000008_ebx + 15,
  x86_cpu_AMD_SSBD	        = x86_cpu_index_80000008_ebx + 24,
  x86_cpu_AMD_VIRT_SSBD	        = x86_cpu_index_80000008_ebx + 25,

  x86_cpu_index_7_ecx_1_eax
    = (CPUID_INDEX_7_ECX_1 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_eax * 8 * sizeof (unsigned int)),

  x86_cpu_RAO_INT		= x86_cpu_index_7_ecx_1_eax + 3,
  x86_cpu_AVX_VNNI		= x86_cpu_index_7_ecx_1_eax + 4,
  x86_cpu_AVX512_BF16		= x86_cpu_index_7_ecx_1_eax + 5,
  x86_cpu_LASS			= x86_cpu_index_7_ecx_1_eax + 6,
  x86_cpu_CMPCCXADD		= x86_cpu_index_7_ecx_1_eax + 7,
  x86_cpu_ArchPerfmonExt	= x86_cpu_index_7_ecx_1_eax + 8,
  x86_cpu_FZLRM			= x86_cpu_index_7_ecx_1_eax + 10,
  x86_cpu_FSRS			= x86_cpu_index_7_ecx_1_eax + 11,
  x86_cpu_FSRCS			= x86_cpu_index_7_ecx_1_eax + 12,
  x86_cpu_WRMSRNS		= x86_cpu_index_7_ecx_1_eax + 19,
  x86_cpu_AMX_FP16		= x86_cpu_index_7_ecx_1_eax + 21,
  x86_cpu_HRESET		= x86_cpu_index_7_ecx_1_eax + 22,
  x86_cpu_AVX_IFMA		= x86_cpu_index_7_ecx_1_eax + 23,
  x86_cpu_LAM			= x86_cpu_index_7_ecx_1_eax + 26,
  x86_cpu_MSRLIST		= x86_cpu_index_7_ecx_1_eax + 27,

  x86_cpu_index_7_ecx_1_edx
    = (CPUID_INDEX_7_ECX_1 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_edx * 8 * sizeof (unsigned int)),

  x86_cpu_AVX_VNNI_INT8		= x86_cpu_index_7_ecx_1_edx + 4,
  x86_cpu_AVX_NE_CONVERT	= x86_cpu_index_7_ecx_1_edx + 5,
  x86_cpu_AMX_COMPLEX		= x86_cpu_index_7_ecx_1_edx + 8,
  x86_cpu_PREFETCHI		= x86_cpu_index_7_ecx_1_edx + 14,
  x86_cpu_AVX10			= x86_cpu_index_7_ecx_1_edx + 19,
  x86_cpu_APX_F			= x86_cpu_index_7_ecx_1_edx + 21,

  x86_cpu_index_19_ebx
    = (CPUID_INDEX_19 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ebx * 8 * sizeof (unsigned int)),

  x86_cpu_AESKLE		= x86_cpu_index_19_ebx,
  x86_cpu_WIDE_KL		= x86_cpu_index_19_ebx + 2,

  x86_cpu_index_14_ecx_0_ebx
    = (CPUID_INDEX_14_ECX_0 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ebx * 8 * sizeof (unsigned int)),

  x86_cpu_PTWRITE		= x86_cpu_index_14_ecx_0_ebx + 4,

  x86_cpu_index_24_ecx_0_ebx
    = (CPUID_INDEX_24_ECX_0 * 8 * 4 * sizeof (unsigned int)
       + cpuid_register_index_ebx * 8 * sizeof (unsigned int)),

  x86_cpu_AVX10_XMM = x86_cpu_index_24_ecx_0_ebx + 16,
  x86_cpu_AVX10_YMM = x86_cpu_index_24_ecx_0_ebx + 17,
  x86_cpu_AVX10_ZMM = x86_cpu_index_24_ecx_0_ebx + 18,
};