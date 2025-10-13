/*	$NetBSD: specialreg.h,v 1.198.2.6 2024/10/03 12:00:57 martin Exp $	*/

/*
 * Copyright (c) 2014-2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright (c) 1991 The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)specialreg.h	7.1 (Berkeley) 5/9/91
 */

/*
 * CR0
 */
#define CR0_PE	0x00000001	/* Protected mode Enable */
#define CR0_MP	0x00000002	/* "Math" Present (NPX or NPX emulator) */
#define CR0_EM	0x00000004	/* EMulate non-NPX coproc. (trap ESC only) */
#define CR0_TS	0x00000008	/* Task Switched (if MP, trap ESC and WAIT) */
#define CR0_ET	0x00000010	/* Extension Type (387 (if set) vs 287) */
#define CR0_NE	0x00000020	/* Numeric Error enable (EX16 vs IRQ13) */
#define CR0_WP	0x00010000	/* Write Protect (honor PTE_W in all modes) */
#define CR0_AM	0x00040000	/* Alignment Mask (set to enable AC flag) */
#define CR0_NW	0x20000000	/* Not Write-through */
#define CR0_CD	0x40000000	/* Cache Disable */
#define CR0_PG	0x80000000	/* PaGing enable */

/*
 * Cyrix 486 DLC special registers, accessible as IO ports
 */
#define CCR0		0xc0	/* configuration control register 0 */
#define CCR0_NC0	0x01	/* first 64K of each 1M memory region is non-cacheable */
#define CCR0_NC1	0x02	/* 640K-1M region is non-cacheable */
#define CCR0_A20M	0x04	/* enables A20M# input pin */
#define CCR0_KEN	0x08	/* enables KEN# input pin */
#define CCR0_FLUSH	0x10	/* enables FLUSH# input pin */
#define CCR0_BARB	0x20	/* flushes internal cache when entering hold state */
#define CCR0_CO		0x40	/* cache org: 1=direct mapped, 0=2x set assoc */
#define CCR0_SUSPEND	0x80	/* enables SUSP# and SUSPA# pins */
#define CCR1		0xc1	/* configuration control register 1 */
#define CCR1_RPL	0x01	/* enables RPLSET and RPLVAL# pins */

/*
 * CR3
 */
#define CR3_PCID		__BITS(11,0)
#define CR3_PA			__BITS(62,12)
#define CR3_NO_TLB_FLUSH	__BIT(63)

/*
 * CR4
 */
#define CR4_VME		0x00000001 /* Virtual 8086 mode extension enable */
#define CR4_PVI		0x00000002 /* Protected mode virtual interrupt enable */
#define CR4_TSD		0x00000004 /* Restrict RDTSC instruction to cpl 0 */
#define CR4_DE		0x00000008 /* Debugging extension */
#define CR4_PSE		0x00000010 /* Large (4MB) page size enable */
#define CR4_PAE		0x00000020 /* Physical address extension enable */
#define CR4_MCE		0x00000040 /* Machine check enable */
#define CR4_PGE		0x00000080 /* Page global enable */
#define CR4_PCE		0x00000100 /* Enable RDPMC instruction for all cpls */
#define CR4_OSFXSR	0x00000200 /* Enable fxsave/fxrestor and SSE */
#define CR4_OSXMMEXCPT	0x00000400 /* Enable unmasked SSE exceptions */
#define CR4_UMIP	0x00000800 /* User Mode Instruction Prevention */
#define CR4_LA57	0x00001000 /* 57-bit linear addresses */
#define CR4_VMXE	0x00002000 /* Enable VMX operations */
#define CR4_SMXE	0x00004000 /* Enable SMX operations */
#define CR4_FSGSBASE	0x00010000 /* Enable *FSBASE and *GSBASE instructions */
#define CR4_PCIDE	0x00020000 /* Enable Process Context IDentifiers */
#define CR4_OSXSAVE	0x00040000 /* Enable xsave and xrestore */
#define CR4_SMEP	0x00100000 /* Enable SMEP support */
#define CR4_SMAP	0x00200000 /* Enable SMAP support */
#define CR4_PKE		0x00400000 /* Enable Protection Keys for user pages */
#define CR4_CET		0x00800000 /* Enable CET */
#define CR4_PKS		0x01000000 /* Enable Protection Keys for kern pages */

/*
 * Extended Control Register XCR0
 */
#define XCR0_X87	__BIT(0)	/* x87 FPU/MMX state */
#define XCR0_SSE	__BIT(1)	/* SSE state */
#define XCR0_YMM_Hi128	__BIT(2)	/* AVX-256 (ymmn registers) */
#define XCR0_BNDREGS	__BIT(3)	/* Memory protection ext bounds */
#define XCR0_BNDCSR	__BIT(4)	/* Memory protection ext state */
#define XCR0_Opmask	__BIT(5)	/* AVX-512 Opmask */
#define XCR0_ZMM_Hi256	__BIT(6)	/* AVX-512 upper 256 bits low regs */
#define XCR0_Hi16_ZMM	__BIT(7)	/* AVX-512 512 bits upper registers */
#define XCR0_PT		__BIT(8)	/* Processor Trace state */
#define XCR0_PKRU	__BIT(9)	/* Protection Key state */
#define XCR0_CET_U	__BIT(11)	/* User CET state */
#define XCR0_CET_S	__BIT(12)	/* Kern CET state */
#define XCR0_HDC	__BIT(13)	/* Hardware Duty Cycle state */
#define XCR0_LBR	__BIT(15)	/* Last Branch Record */
#define XCR0_HWP	__BIT(16)	/* Hardware P-states */

#define XCR0_FLAGS1	"\20"						  \
	"\1" "x87"	"\2" "SSE"	"\3" "AVX"	"\4" "BNDREGS"	  \
	"\5" "BNDCSR"	"\6" "Opmask"	"\7" "ZMM_Hi256" "\10" "Hi16_ZMM" \
	"\11" "PT"	"\12" "PKRU"			"\14" "CET_U"	  \
	"\15" "CET_S"	"\16" "HDC"			"\20" "LBR"	  \
	"\21" "HWP"

/*
 * Known FPU bits, only these get enabled. The save area is sized for all the
 * fields below.
 */
#define XCR0_FPU	(XCR0_X87 | XCR0_SSE | XCR0_YMM_Hi128 | \
			 XCR0_Opmask | XCR0_ZMM_Hi256 | XCR0_Hi16_ZMM)

/*
 * XSAVE component indices, internal to NetBSD.
 */
#define XSAVE_X87	0
#define XSAVE_SSE	1
#define XSAVE_YMM_Hi128	2
#define XSAVE_BNDREGS	3
#define XSAVE_BNDCSR	4
#define XSAVE_Opmask	5
#define XSAVE_ZMM_Hi256	6
#define XSAVE_Hi16_ZMM	7

/*
 * Highest XSAVE component enabled by XCR0_FPU.
 */
#define XSAVE_MAX_COMPONENT XSAVE_Hi16_ZMM

/*
 * "features" bits.
 * CPUID Fn00000001
 */
/* %edx */
#define CPUID_FPU	0x00000001	/* processor has an FPU? */
#define CPUID_VME	0x00000002	/* has virtual mode (%cr4's VME/PVI) */
#define CPUID_DE	0x00000004	/* has debugging extension */
#define CPUID_PSE	0x00000008	/* has 4MB page size extension */
#define CPUID_TSC	0x00000010	/* has time stamp counter */
#define CPUID_MSR	0x00000020	/* has model specific registers */
#define CPUID_PAE	0x00000040	/* has physical address extension */
#define CPUID_MCE	0x00000080	/* has machine check exception */
#define CPUID_CX8	0x00000100	/* has CMPXCHG8B instruction */
#define CPUID_APIC	0x00000200	/* has enabled APIC */
#define CPUID_SEP	0x00000800	/* has SYSENTER/SYSEXIT extension */
#define CPUID_MTRR	0x00001000	/* has memory type range register */
#define CPUID_PGE	0x00002000	/* has page global extension */
#define CPUID_MCA	0x00004000	/* has machine check architecture */
#define CPUID_CMOV	0x00008000	/* has CMOVcc instruction */
#define CPUID_PAT	0x00010000	/* Page Attribute Table */
#define CPUID_PSE36	0x00020000	/* 36-bit PSE */
#define CPUID_PSN	0x00040000	/* Processor Serial Number */
#define CPUID_CLFSH	0x00080000	/* CLFLUSH instruction supported */
#define CPUID_DS	0x00200000	/* Debug Store */
#define CPUID_ACPI	0x00400000	/* ACPI performance modulation regs */
#define CPUID_MMX	0x00800000	/* MMX supported */
#define CPUID_FXSR	0x01000000	/* Fast FP/MMX Save/Restore */
#define CPUID_SSE	0x02000000	/* Streaming SIMD Extensions */
#define CPUID_SSE2	0x04000000	/* Streaming SIMD Extensions #2 */
#define CPUID_SS	0x08000000	/* Self-Snoop */
#define CPUID_HTT	0x10000000	/* Hyper-Threading Technology */
#define CPUID_TM	0x20000000	/* Thermal Monitor (TCC) */
#define CPUID_PBE	0x80000000	/* Pending Break Enable */

#define CPUID_FLAGS1	"\20"						\
	"\1" "FPU"	"\2" "VME"	"\3" "DE"	"\4" "PSE"	\
	"\5" "TSC"	"\6" "MSR"	"\7" "PAE"	"\10" "MCE"	\
	"\11" "CX8"	"\12" "APIC"	"\13" "B10"	"\14" "SEP"	\
	"\15" "MTRR"	"\16" "PGE"	"\17" "MCA"	"\20" "CMOV"	\
	"\21" "PAT"	"\22" "PSE36"	"\23" "PN"	"\24" "CLFSH"	\
	"\25" "B20"	"\26" "DS"	"\27" "ACPI"	"\30" "MMX"	\
	"\31" "FXSR"	"\32" "SSE"	"\33" "SSE2"	"\34" "SS"	\
	"\35" "HTT"	"\36" "TM"	"\37" "IA64"	"\40" "PBE"

/* Blacklists of CPUID flags - used to mask certain features */
#ifdef XENPV
#define CPUID_FEAT_BLACKLIST	 (CPUID_PGE|CPUID_PSE|CPUID_MTRR)
#else
#define CPUID_FEAT_BLACKLIST	 0
#endif

/* %ecx */
#define CPUID2_SSE3	__BIT(0)	/* Streaming SIMD Extensions 3 */
#define CPUID2_PCLMULQDQ __BIT(1)	/* PCLMULQDQ instructions */
#define CPUID2_DTES64	__BIT(2)	/* 64-bit Debug Trace */
#define CPUID2_MONITOR	__BIT(3)	/* MONITOR/MWAIT instructions */
#define CPUID2_DS_CPL	__BIT(4)	/* CPL Qualified Debug Store */
#define CPUID2_VMX	__BIT(5)	/* Virtual Machine eXtensions */
#define CPUID2_SMX	__BIT(6)	/* Safer Mode eXtensions */
#define CPUID2_EST	__BIT(7)	/* Enhanced SpeedStep Technology */
#define CPUID2_TM2	__BIT(8)	/* Thermal Monitor 2 */
#define CPUID2_SSSE3	__BIT(9)	/* Supplemental SSE3 */
#define CPUID2_CNXTID	__BIT(10)	/* Context ID */
#define CPUID2_SDBG	__BIT(11)	/* Silicon Debug */
#define CPUID2_FMA	__BIT(12)	/* Fused Multiply Add */
#define CPUID2_CX16	__BIT(13)	/* CMPXCHG16B instruction */
#define CPUID2_XTPR	__BIT(14)	/* Task Priority Messages disabled? */
#define CPUID2_PDCM	__BIT(15)	/* Perf/Debug Capability MSR */
/* bit 16 unused	__BIT(16) */
#define CPUID2_PCID	__BIT(17)	/* Process Context ID */
#define CPUID2_DCA	__BIT(18)	/* Direct Cache Access */
#define CPUID2_SSE41	__BIT(19)	/* Streaming SIMD Extensions 4.1 */
#define CPUID2_SSE42	__BIT(20)	/* Streaming SIMD Extensions 4.2 */
#define CPUID2_X2APIC	__BIT(21)	/* xAPIC Extensions */
#define CPUID2_MOVBE	__BIT(22)	/* MOVBE (move after byteswap) */
#define CPUID2_POPCNT	__BIT(23)	/* POPCNT instruction available */
#define CPUID2_DEADLINE	__BIT(24)	/* APIC Timer supports TSC Deadline */
#define CPUID2_AESNI	__BIT(25)	/* AES instructions */
#define CPUID2_XSAVE	__BIT(26)	/* XSAVE instructions */
#define CPUID2_OSXSAVE	__BIT(27)	/* XGETBV/XSETBV instructions */
#define CPUID2_AVX	__BIT(28)	/* AVX instructions */
#define CPUID2_F16C	__BIT(29)	/* half precision conversion */
#define CPUID2_RDRAND	__BIT(30)	/* RDRAND (hardware random number) */
#define CPUID2_RAZ	__BIT(31)	/* RAZ. Indicates guest state. */

#define CPUID2_FLAGS1	"\20"						\
	"\1" "SSE3"	"\2" "PCLMULQDQ" "\3" "DTES64"	"\4" "MONITOR"	\
	"\5" "DS-CPL"	"\6" "VMX"	"\7" "SMX"	"\10" "EST"	\
	"\11" "TM2"	"\12" "SSSE3"	"\13" "CID"	"\14" "SDBG"	\
	"\15" "FMA"	"\16" "CX16"	"\17" "xTPR"	"\20" "PDCM"	\
	"\21" "B16"	"\22" "PCID"	"\23" "DCA"	"\24" "SSE41"	\
	"\25" "SSE42"	"\26" "X2APIC"	"\27" "MOVBE"	"\30" "POPCNT"	\
	"\31" "DEADLINE" "\32" "AES"	"\33" "XSAVE"	"\34" "OSXSAVE"	\
	"\35" "AVX"	"\36" "F16C"	"\37" "RDRAND"	"\40" "RAZ"

/* %eax */
#define CPUID_TO_BASEFAMILY(cpuid)	(((cpuid) >> 8) & 0xf)
#define CPUID_TO_BASEMODEL(cpuid)	(((cpuid) >> 4) & 0xf)
#define CPUID_TO_STEPPING(cpuid)	((cpuid) & 0xf)

/*
 * The Extended family bits should only be inspected when CPUID_TO_BASEFAMILY()
 * returns 15. They are use to encode family value 16 to 270 (add 15).
 * The Extended model bits are the high 4 bits of the model.
 * They are only valid for family >= 15 or family 6 (intel, but all amd
 * family 6 are documented to return zero bits for them).
 */
#define CPUID_TO_EXTFAMILY(cpuid)	(((cpuid) >> 20) & 0xff)
#define CPUID_TO_EXTMODEL(cpuid)	(((cpuid) >> 16) & 0xf)

/* The macros for the Display Family and the Display Model */
#define CPUID_TO_FAMILY(cpuid)	(CPUID_TO_BASEFAMILY(cpuid)	\
	    + ((CPUID_TO_BASEFAMILY(cpuid) != 0x0f)		\
		? 0 : CPUID_TO_EXTFAMILY(cpuid)))
#define CPUID_TO_MODEL(cpuid)	(CPUID_TO_BASEMODEL(cpuid)	\
	    | ((CPUID_TO_BASEFAMILY(cpuid) != 0x0f)		\
		&& (CPUID_TO_BASEFAMILY(cpuid) != 0x06)		\
		? 0 : (CPUID_TO_EXTMODEL(cpuid) << 4)))

/* %ebx */
#define CPUID_BRAND_INDEX	__BITS(7,0)
#define CPUID_CLFLUSH_SIZE	__BITS(15,8)
#define CPUID_HTT_CORES		__BITS(23,16)
#define CPUID_LOCAL_APIC_ID	__BITS(31,24)

/*
 * Intel Deterministic Cache Parameter.
 * CPUID Fn0000_0004
 */

/* %eax */
#define CPUID_DCP_CACHETYPE	__BITS(4, 0)	/* Cache type */
#define CPUID_DCP_CACHETYPE_N	0		/*   NULL */
#define CPUID_DCP_CACHETYPE_D	1		/*   Data cache */
#define CPUID_DCP_CACHETYPE_I	2		/*   Instruction cache */
#define CPUID_DCP_CACHETYPE_U	3		/*   Unified cache */
#define CPUID_DCP_CACHELEVEL	__BITS(7, 5)	/* Cache level (start at 1) */
#define CPUID_DCP_SELFINITCL	__BIT(8)	/* Self initializing cachelvl*/
#define CPUID_DCP_FULLASSOC	__BIT(9)	/* Full associative */
#define CPUID_DCP_SHARING	__BITS(25, 14)	/* sharing */
#define CPUID_DCP_CORE_P_PKG	__BITS(31, 26)	/* Cores/package */

/* %ebx */
#define CPUID_DCP_LINESIZE	__BITS(11, 0)	/* System coherency linesize */
#define CPUID_DCP_PARTITIONS	__BITS(21, 12)	/* Physical line partitions */
#define CPUID_DCP_WAYS		__BITS(31, 22)	/* Ways of associativity */

/* %ecx: Number of sets */

/* %edx */
#define CPUID_DCP_INVALIDATE	__BIT(0)	/* WB invalidate/invalidate */
#define CPUID_DCP_INCLUSIVE	__BIT(1)	/* Cache inclusiveness */
#define CPUID_DCP_COMPLEX	__BIT(2)	/* Complex cache indexing */

/*
 * Intel/AMD MONITOR/MWAIT.
 * CPUID Fn0000_0005
 */
/* %eax */
#define CPUID_MON_MINSIZE	__BITS(15, 0)  /* Smallest monitor-line size */
/* %ebx */
#define CPUID_MON_MAXSIZE	__BITS(15, 0)  /* Largest monitor-line size */
/* %ecx */
#define CPUID_MON_EMX		__BIT(0)       /* MONITOR/MWAIT Extensions */
#define CPUID_MON_IBE		__BIT(1)       /* Interrupt as Break Event */

#define CPUID_MON_FLAGS	"\20" \
	"\1" "EMX"	"\2" "IBE"

/* %edx: number of substates for specific C-state */
#define CPUID_MON_SUBSTATE(edx, cstate) (((edx) >> (cstate * 4)) & 0x0000000f)

/*
 * Intel/AMD Digital Thermal Sensor and Power Management.
 * CPUID Fn0000_0006
 */
/* %eax */
#define CPUID_DSPM_DTS	      __BIT(0)	/* Digital Thermal Sensor */
#define CPUID_DSPM_IDA	      __BIT(1)	/* Intel Dynamic Acceleration */
#define CPUID_DSPM_ARAT	      __BIT(2)	/* Always Running APIC Timer */
#define CPUID_DSPM_PLN	      __BIT(4)	/* Power Limit Notification */
#define CPUID_DSPM_ECMD	      __BIT(5)	/* Clock Modulation Extension */
#define CPUID_DSPM_PTM	      __BIT(6)	/* Package Level Thermal Management */
#define CPUID_DSPM_HWP	      __BIT(7)	/* HWP */
#define CPUID_DSPM_HWP_NOTIFY __BIT(8)	/* HWP Notification */
#define CPUID_DSPM_HWP_ACTWIN __BIT(9)	/* HWP Activity Window */
#define CPUID_DSPM_HWP_EPP    __BIT(10)	/* HWP Energy Performance Preference */
#define CPUID_DSPM_HWP_PLR    __BIT(11)	/* HWP Package Level Request */
#define CPUID_DSPM_HDC	      __BIT(13)	/* Hardware Duty Cycling */
#define CPUID_DSPM_TBMT3      __BIT(14)	/* Turbo Boost Max Technology 3.0 */
#define CPUID_DSPM_HWP_CAP    __BIT(15)	/* HWP Capabilities */
#define CPUID_DSPM_HWP_PECI   __BIT(16)	/* HWP PECI override */
#define CPUID_DSPM_HWP_FLEX   __BIT(17)	/* Flexible HWP */
#define CPUID_DSPM_HWP_FAST   __BIT(18)	/* Fast access for IA32_HWP_REQUEST */
#define CPUID_DSPM_HFI	      __BIT(19) /* Hardware Feedback Interface */
#define CPUID_DSPM_HWP_IGNIDL __BIT(20)	/* Ignore Idle Logical Processor HWP */
#define CPUID_DSPM_TD	      __BIT(23)	/* Thread Director */
#define CPUID_DSPM_THERMI_HFN __BIT(24) /* THERM_INTERRUPT MSR HFN bit */

#define CPUID_DSPM_FLAGS	"\20"					      \
	"\1" "DTS"	"\2" "IDA"	"\3" "ARAT" 			      \
	"\5" "PLN"	"\6" "ECMD"	"\7" "PTM"	"\10" "HWP"	      \
	"\11" "HWP_NOTIFY" "\12" "HWP_ACTWIN" "\13" "HWP_EPP" "\14" "HWP_PLR" \
			"\16" "HDC"	"\17" "TBM3"	"\20" "HWP_CAP"       \
	"\21" "HWP_PECI" "\22" "HWP_FLEX" "\23" "HWP_FAST" "\24HFI"	      \
	"\25" "HWP_IGNIDL"				"\30" "TD"	      \
	"\31" "THERMI_HFN"

/* %ecx */
#define CPUID_DSPM_HWF	__BIT(0)	/* MSR_APERF/MSR_MPERF available */
#define CPUID_DSPM_EPB	__BIT(3)	/* Energy Performance Bias */
#define CPUID_DSPM_NTDC	__BITS(15, 8)	/* Number of Thread Director Classes */

#define CPUID_DSPM_FLAGS1	"\177\20"				\
	"b\0HWF\0"					"b\3EPB\0"	\
	"f\10\10NTDC\0"

/*
 * Intel/AMD Structured Extended Feature.
 * CPUID Fn0000_0007
 * %ecx == 0: Subleaf 0
 *	%eax: The Maximum input value for supported subleaf.
 *	%ebx: Feature bits.
 *	%ecx: Feature bits.
 *	%edx: Feature bits.
 *
 * %ecx == 1: Structure Extendede Feature Enumeration Sub-leaf
 *	%eax: See below.
 */

/* %ecx = 0, %ebx */
#define CPUID_SEF_FSGSBASE    __BIT(0)  /* {RD,WR}{FS,GS}BASE */
#define CPUID_SEF_TSC_ADJUST  __BIT(1)  /* IA32_TSC_ADJUST MSR support */
#define CPUID_SEF_SGX	      __BIT(2)  /* Software Guard Extensions */
#define CPUID_SEF_BMI1	      __BIT(3)  /* Advanced bit manipulation ext. 1st grp */
#define CPUID_SEF_HLE	      __BIT(4)  /* Hardware Lock Elision */
#define CPUID_SEF_AVX2	      __BIT(5)  /* Advanced Vector Extensions 2 */
#define CPUID_SEF_FDPEXONLY   __BIT(6)  /* x87FPU Data ptr updated only on x87exp */
#define CPUID_SEF_SMEP	      __BIT(7)  /* Supervisor-Mode Execution Prevention */
#define CPUID_SEF_BMI2	      __BIT(8)  /* Advanced bit manipulation ext. 2nd grp */
#define CPUID_SEF_ERMS	      __BIT(9)  /* Enhanced REP MOVSB/STOSB */
#define CPUID_SEF_INVPCID     __BIT(10) /* INVPCID instruction */
#define CPUID_SEF_RTM	      __BIT(11) /* Restricted Transactional Memory */
#define CPUID_SEF_QM	      __BIT(12) /* Resource Director Technology Monitoring */
#define CPUID_SEF_FPUCSDS     __BIT(13) /* Deprecate FPU CS and FPU DS values */
#define CPUID_SEF_MPX	      __BIT(14) /* Memory Protection Extensions */
#define CPUID_SEF_PQE	      __BIT(15) /* Resource Director Technology Allocation */
#define CPUID_SEF_AVX512F     __BIT(16) /* AVX-512 Foundation */
#define CPUID_SEF_AVX512DQ    __BIT(17) /* AVX-512 Double/Quadword */
#define CPUID_SEF_RDSEED      __BIT(18) /* RDSEED instruction */
#define CPUID_SEF_ADX	      __BIT(19) /* ADCX/ADOX instructions */
#define CPUID_SEF_SMAP	      __BIT(20) /* Supervisor-Mode Access Prevention */
#define CPUID_SEF_AVX512_IFMA __BIT(21) /* AVX-512 Integer Fused Multiply Add */
/* Bit 22 was PCOMMIT */
#define CPUID_SEF_CLFLUSHOPT  __BIT(23) /* Cache Line FLUSH OPTimized */
#define CPUID_SEF_CLWB	      __BIT(24) /* Cache Line Write Back */
#define CPUID_SEF_PT	      __BIT(25) /* Processor Trace */
#define CPUID_SEF_AVX512PF    __BIT(26) /* AVX-512 PreFetch */
#define CPUID_SEF_AVX512ER    __BIT(27) /* AVX-512 Exponential and Reciprocal */
#define CPUID_SEF_AVX512CD    __BIT(28) /* AVX-512 Conflict Detection */
#define CPUID_SEF_SHA	      __BIT(29) /* SHA Extensions */
#define CPUID_SEF_AVX512BW    __BIT(30) /* AVX-512 Byte and Word */
#define CPUID_SEF_AVX512VL    __BIT(31) /* AVX-512 Vector Length */

#define CPUID_SEF_FLAGS	"\20"						   \
	"\1" "FSGSBASE"	"\2" "TSCADJUST" "\3" "SGX"	"\4" "BMI1"	   \
	"\5" "HLE"	"\6" "AVX2"	"\7" "FDPEXONLY" "\10" "SMEP"	   \
	"\11" "BMI2"	"\12" "ERMS"	"\13" "INVPCID"	"\14" "RTM"	   \
	"\15" "QM"	"\16" "FPUCSDS"	"\17" "MPX"    	"\20" "PQE"	   \
	"\21" "AVX512F"	"\22" "AVX512DQ" "\23" "RDSEED"	"\24" "ADX"	   \
	"\25" "SMAP"	"\26" "AVX512_IFMA"		"\30" "CLFLUSHOPT" \
	"\31" "CLWB"	"\32" "PT"	"\33" "AVX512PF" "\34" "AVX512ER"  \
	"\35" "AVX512CD""\36" "SHA"	"\37" "AVX512BW" "\40" "AVX512VL"

/* %ecx = 0, %ecx */
#define CPUID_SEF_PREFETCHWT1	__BIT(0)  /* PREFETCHWT1 instruction */
#define CPUID_SEF_AVX512_VBMI	__BIT(1)  /* AVX-512 Vector Byte Manipulation */
#define CPUID_SEF_UMIP		__BIT(2)  /* User-Mode Instruction prevention */
#define CPUID_SEF_PKU		__BIT(3)  /* Protection Keys for User-mode pages */
#define CPUID_SEF_OSPKE		__BIT(4)  /* OS has set CR4.PKE to ena. protec. keys */
#define CPUID_SEF_WAITPKG	__BIT(5)  /* TPAUSE,UMONITOR,UMWAIT */
#define CPUID_SEF_AVX512_VBMI2	__BIT(6)  /* AVX-512 Vector Byte Manipulation 2 */
#define CPUID_SEF_CET_SS	__BIT(7)  /* CET Shadow Stack */
#define CPUID_SEF_GFNI		__BIT(8)  /* Galois Field instructions */
#define CPUID_SEF_VAES		__BIT(9)  /* Vector AES instruction set */
#define CPUID_SEF_VPCLMULQDQ	__BIT(10) /* CLMUL instruction set */
#define CPUID_SEF_AVX512_VNNI	__BIT(11) /* Vector Neural Network Instruction */
#define CPUID_SEF_AVX512_BITALG	__BIT(12) /* BITALG instructions */
#define CPUID_SEF_TME_EN	__BIT(13) /* Total Memory Encryption */
#define CPUID_SEF_AVX512_VPOPCNTDQ __BIT(14) /* Vector Population Count D/Q */
#define CPUID_SEF_LA57		__BIT(16) /* 57bit linear addr & 5LVL paging */
#define CPUID_SEF_MAWAU		__BITS(21, 17) /* MAWAU for BND{LD,ST}X */
#define CPUID_SEF_RDPID		__BIT(22) /* RDPID and IA32_TSC_AUX */
#define CPUID_SEF_KL		__BIT(23) /* Key Locker */
#define CPUID_SEF_BUS_LOCK_DETECT __BIT(24) /* OS bus-lock detection */
#define CPUID_SEF_CLDEMOTE	__BIT(25) /* Cache line demote */
#define CPUID_SEF_MOVDIRI	__BIT(27) /* MOVDIRI instruction */
#define CPUID_SEF_MOVDIR64B	__BIT(28) /* MOVDIR64B instruction */
#define CPUID_SEF_ENQCMD	__BIT(29) /* Enqueue Stores */
#define CPUID_SEF_SGXLC		__BIT(30) /* SGX Launch Configuration */
#define CPUID_SEF_PKS		__BIT(31) /* Protection Keys for kern-mode pages */

#define CPUID_SEF_FLAGS1	"\177\20"				      \
	"b\0PREFETCHWT1\0" "b\1AVX512_VBMI\0" "b\2UMIP\0" "b\3PKU\0"	      \
	"b\4OSPKE\0"	"b\5WAITPKG\0"	"b\6AVX512_VBMI2\0" "b\7CET_SS\0"     \
	"b\10GFNI\0"	"b\11VAES\0"	"b\12VPCLMULQDQ\0" "b\13AVX512_VNNI\0"\
	"b\14AVX512_BITALG\0" "b\15TME_EN\0" "b\16AVX512_VPOPCNTDQ\0"	      \
	"b\20LA57\0"							      \
	"f\21\5MAWAU\0"			"b\26RDPID\0"	"b\27KL\0"	      \
	"b\30BUS_LOCK_DETECT\0" "b\31CLDEMOTE\0"	"b\33MOVDIRI\0"	      \
	"b\34MOVDIR64B\0" "b\35ENQCMD\0" "b\36SGXLC\0"	"b\37PKS\0"

/* %ecx = 0, %edx */
#define CPUID_SEF_SGX_KEYS	__BIT(1)  /* Attestation support for SGX */
#define CPUID_SEF_AVX512_4VNNIW	__BIT(2)  /* AVX512 4-reg Neural Network ins */
#define CPUID_SEF_AVX512_4FMAPS	__BIT(3)  /* AVX512 4-reg Mult Accum Single precision */
#define CPUID_SEF_FSRM		__BIT(4)  /* Fast Short Rep Move */
#define CPUID_SEF_UINTR		__BIT(5)  /* User Interrupts */
#define CPUID_SEF_AVX512_VP2INTERSECT __BIT(8) /* AVX512 VP2INTERSECT */
#define CPUID_SEF_SRBDS_CTRL	__BIT(9)  /* IA32_MCU_OPT_CTRL */
#define CPUID_SEF_MD_CLEAR	__BIT(10) /* VERW clears CPU buffers */
#define CPUID_SEF_RTM_ALWAYS_ABORT __BIT(11) /* XBEGIN immediately abort */
#define CPUID_SEF_RTM_FORCE_ABORT __BIT(13) /* MSR_TSX_FORCE_ABORT bit 0 */
#define CPUID_SEF_SERIALIZE	__BIT(14) /* SERIALIZE instruction */
#define CPUID_SEF_HYBRID	__BIT(15) /* Hybrid part */
#define CPUID_SEF_TSXLDTRK	__BIT(16) /* TSX suspend load addr tracking */
#define CPUID_SEF_PCONFIG	__BIT(18) /* Platform CONFIGuration */
#define CPUID_SEF_ARCH_LBR	__BIT(19) /* Architectural LBR */
#define CPUID_SEF_CET_IBT	__BIT(20) /* CET Indirect Branch Tracking */
#define CPUID_SEF_AMX_BF16	__BIT(22) /* AMX bfloat16 */
#define CPUID_SEF_AVX512_FP16	__BIT(23) /* AVX512 FP16 */
#define CPUID_SEF_AMX_TILE	__BIT(24) /* Tile architecture */
#define CPUID_SEF_AMX_INT8	__BIT(25) /* AMX 8bit interger */
#define CPUID_SEF_IBRS		__BIT(26) /* IBRS / IBPB Speculation Control */
#define CPUID_SEF_STIBP		__BIT(27) /* STIBP Speculation Control */
#define CPUID_SEF_L1D_FLUSH	__BIT(28) /* IA32_FLUSH_CMD MSR */
#define CPUID_SEF_ARCH_CAP	__BIT(29) /* IA32_ARCH_CAPABILITIES */
#define CPUID_SEF_CORE_CAP	__BIT(30) /* IA32_CORE_CAPABILITIES */
#define CPUID_SEF_SSBD		__BIT(31) /* Speculative Store Bypass Disable */

#define CPUID_SEF_FLAGS2	"\20"					      \
			"\2SGX_KEYS" "\3AVX512_4VNNIW"	"\4AVX512_4FMAPS"     \
	"\5FSRM"	"\6UINTR"					      \
	"\11VP2INTERSECT" "\12SRBDS_CTRL" "\13MD_CLEAR"	"\14RTM_ALWAYS_ABORT" \
			"\16RTM_FORCE_ABORT" "\17SERIALIZE" "\20HYBRID"	      \
	"\21" "TSXLDTRK"		"\23" "PCONFIG"	"\24" "ARCH_LBR"      \
	"\25CET_IBT"			"\27AMX_BF16"	"\30AVX512_FP16"      \
	"\31AMX_TILE"	"\32AMX_INT8"	"\33IBRS"	"\34STIBP"	      \
	"\35" "L1D_FLUSH" "\36" "ARCH_CAP" "\37CORE_CAP" "\40" "SSBD"

/* %ecx = 1, %eax */
#define CPUID_SEF_AVXVNNI	__BIT(4)  /* AVX version of VNNI */
#define CPUID_SEF_AVX512_BF16	__BIT(5)
#define CPUID_SEF_FZLRMS	__BIT(10) /* fast zero-length REP MOVSB */
#define CPUID_SEF_FSRSB		__BIT(11) /* fast short REP STOSB */
#define CPUID_SEF_FSRCS		__BIT(12) /* fast short REP CMPSB, REP SCASB */
#define CPUID_SEF_HRESET	__BIT(22) /* HREST & IA32_HRESET_ENABLE MSR */
#define CPUID_SEF_LAM		__BIT(26) /* Linear Address Masking */

#define CPUID_SEF1_FLAGS_A	"\20"					\
	"\5" "AVXVNNI"	"\6" "AVX512_BF16"				\
					"\13" "FZLRMS"	"\14" "FSRSB"	\
	"\15" "FSRCS"			"\27" "HRESET"			\
	"\31" "LAM"

/* %ecx = 1, %ebx */
#define CPUID_SEF_INTEL_PPIN	__BIT(0)  /* IA32_PPIN & IA32_PPIN_CTL MSRs */

#define CPUID_SEF1_FLAGS_B	"\20"				\
				"\1" "PPIN"

/* %ecx = 1, %edx */
#define CPUID_SEF_CET_SSS	__BIT(18)  /* CET Supervisor Shadow Stack */

#define CPUID_SEF1_FLAGS_D	"\20"				\
				"\23CET_SSS"

/* %ecx = 2, %edx */
#define CPUID_SEF_PSFD		__BIT(0)  /* Fast Forwarding Predictor Dis. */
#define CPUID_SEF_IPRED_CTRL	__BIT(1)  /* IPRED_DIS */
#define CPUID_SEF_RRSBA_CTRL	__BIT(2)  /* RRSBA for CPL3 */
#define CPUID_SEF_DDPD_U	__BIT(3)  /* Data Dependent Prefetcher */
#define CPUID_SEF_BHI_CTRL	__BIT(4)  /* BHI_DIS_S */
#define CPUID_SEF_MCDT_NO	__BIT(5)  /* !MXCSR Config Dependent Timing */

#define CPUID_SEF2_FLAGS_D	"\20"				\
	"\1PSFD"	"\2IPRED_CTRL"	"\3RRSBA_CTRL"	"\4DDPD_U"	\
	"\5BHI_CTRL"	"\6MCDT_NO"

/*
 * Intel CPUID Architectural Performance Monitoring.
 * CPUID Fn0000000a
 *
 * See also src/usr.sbin/tprof/arch/tprof_x86.c
 */

/* %eax */
#define CPUID_PERF_VERSION	__BITS(7, 0)   /* Version ID */
#define CPUID_PERF_NGPPC	__BITS(15, 8)  /* Num of G.P. perf counter */
#define CPUID_PERF_NBWGPPC	__BITS(23, 16) /* Bit width of G.P. perfcnt */
#define CPUID_PERF_BVECLEN	__BITS(31, 24) /* Length of EBX bit vector */

#define CPUID_PERF_FLAGS0	"\177\20"	\
	"f\0\10VERSION\0" "f\10\10GPCounter\0"	\
	"f\20\10GPBitwidth\0" "f\30\10Vectorlen\0"

/* %ebx */
#define CPUID_PERF_CORECYCL	__BIT(0)       /* No core cycle */
#define CPUID_PERF_INSTRETRY	__BIT(1)       /* No instruction retried */
#define CPUID_PERF_REFCYCL	__BIT(2)       /* No reference cycles */
#define CPUID_PERF_LLCREF	__BIT(3)       /* No LLCache reference */
#define CPUID_PERF_LLCMISS	__BIT(4)       /* No LLCache miss */
#define CPUID_PERF_BRINSRETR	__BIT(5)       /* No branch inst. retried */
#define CPUID_PERF_BRMISPRRETR	__BIT(6)       /* No branch mispredict retry */
#define CPUID_PERF_TOPDOWNSLOT	__BIT(7)       /* No top-down slots */

#define CPUID_PERF_FLAGS1	"\177\20"				      \
	"b\0CORECYCL\0"	"b\1INST\0"	"b\2REFCYCL\0"	"b\3LLCREF\0"	      \
	"b\4LLCMISS\0"	"b\5BRINST\0"	"b\6BRMISPR\0"	"b\7TOPDOWNSLOT\0"

/* %ecx */

#define CPUID_PERF_FLAGS2	"\177\20"				      \
	"b\0INST\0" "b\1CLK_CORETHREAD\0" "b\2CLK_REF_TSC\0" "b\3TOPDOWNSLOT\0"

/* %edx */
#define CPUID_PERF_NFFPC	__BITS(4, 0)   /* Num of fixed-funct perfcnt */
#define CPUID_PERF_NBWFFPC	__BITS(12, 5)  /* Bit width of fixed-func pc */
#define CPUID_PERF_ANYTHREADDEPR __BIT(15)     /* Any Thread deprecation */

#define CPUID_PERF_FLAGS3	"\177\20"				\
	"f\0\5FixedFunc\0" "f\5\10FFBitwidth\0" "b\17ANYTHREADDEPR\0"

/*
 * Intel/AMD CPUID Extended Topology Enumeration.
 * CPUID Fn0000000b
 * %ecx == level number
 *	%eax: See below.
 *	%ebx: Number of logical processors at this level.
 *	%ecx: See below.
 *	%edx: x2APIC ID of the current logical processor.
 */
/* %eax */
#define CPUID_TOP_SHIFTNUM	__BITS(4, 0) /* Topology ID shift value */
/* %ecx */
#define CPUID_TOP_LVLNUM	__BITS(7, 0) /* Level number */
#define CPUID_TOP_LVLTYPE	__BITS(15, 8) /* Level type */
#define CPUID_TOP_LVLTYPE_INVAL	0	 	/* Invalid */
#define CPUID_TOP_LVLTYPE_SMT	1	 	/* SMT */
#define CPUID_TOP_LVLTYPE_CORE	2	 	/* Core */

/*
 * Intel/AMD CPUID Processor extended state Enumeration.
 * CPUID Fn0000000d
 *
 * %ecx == 0: supported features info:
 *	%eax: Valid bits of lower 32bits of XCR0
 *	%ebx: Maximum save area size for features enabled in XCR0
 *	%ecx: Maximum save area size for all cpu features
 *	%edx: Valid bits of upper 32bits of XCR0
 *
 * %ecx == 1:
 *	%eax: See below
 *	%ebx: Save area size for features enabled by XCR0 | IA32_XSS
 *	%ecx: Valid bits of lower 32bits of IA32_XSS
 *	%edx: Valid bits of upper 32bits of IA32_XSS
 *
 * %ecx >= 2: Save area details for XCR0 bit n
 *	%eax: size of save area for this feature
 *	%ebx: offset of save area for this feature
 *	%ecx, %edx: reserved
 *	All of %eax, %ebx, %ecx and %edx are zero for unsupported features.
 */

/* %ecx = 1, %eax */
#define CPUID_PES1_XSAVEOPT	__BIT(0)	/* xsaveopt instruction */
#define CPUID_PES1_XSAVEC	__BIT(1)	/* xsavec & compacted XRSTOR */
#define CPUID_PES1_XGETBV	__BIT(2)	/* xgetbv with ECX = 1 */
#define CPUID_PES1_XSAVES	__BIT(3)	/* xsaves/xrstors, IA32_XSS */
#define CPUID_PES1_XFD		__BIT(4)	/* eXtened Feature Disable */

#define CPUID_PES1_FLAGS	"\20"					\
	"\1XSAVEOPT"	"\2XSAVEC"	"\3XGETBV"	"\4XSAVES"	\
	"\5XFD"

/*
 * Intel Deterministic Address Translation Parameter.
 * CPUID Fn0000_0018
 */

/* %ecx=0 %eax __BITS(31, 0): the maximum input value of supported sub-leaf */

/* %ebx */
#define CPUID_DATP_PGSIZE	__BITS(3, 0)	/* page size */
#define CPUID_DATP_PGSIZE_4KB	__BIT(0)	/* 4KB page support */
#define CPUID_DATP_PGSIZE_2MB	__BIT(1)	/* 2MB page support */
#define CPUID_DATP_PGSIZE_4MB	__BIT(2)	/* 4MB page support */
#define CPUID_DATP_PGSIZE_1GB	__BIT(3)	/* 1GB page support */
#define CPUID_DATP_PARTITIONING	__BITS(10, 8)	/* Partitioning */
#define CPUID_DATP_WAYS		__BITS(31, 16)	/* Ways of associativity */

/* Number of sets: %ecx */

/* %edx */
#define CPUID_DATP_TCTYPE	__BITS(4, 0)	/* Translation Cache type */
#define CPUID_DATP_TCTYPE_N	0		/*   NULL (not valid) */
#define CPUID_DATP_TCTYPE_D	1		/*   Data TLB */
#define CPUID_DATP_TCTYPE_I	2		/*   Instruction TLB */
#define CPUID_DATP_TCTYPE_U	3		/*   Unified TLB */
#define CPUID_DATP_TCTYPE_L	4		/*   Load only TLB */
#define CPUID_DATP_TCTYPE_S	5		/*   Store only TLB */
#define CPUID_DATP_TCLEVEL	__BITS(7, 5)	/* TLB level (start at 1) */
#define CPUID_DATP_FULLASSOC	__BIT(8)	/* Full associative */
#define CPUID_DATP_SHARING	__BITS(25, 14)	/* sharing */

/*
 * Intel Native Model ID Information Enumeration.
 * CPUID Fn0000_001a
 */
/* %eax */
#define CPUID_HYBRID_NATIVEID	__BITS(23, 0)	/* Native model ID */
#define CPUID_HYBRID_CORETYPE	__BITS(31, 24)	/* Core type */
#define   CPUID_HYBRID_CORETYPE_ATOM	0x20		/* Atom */
#define   CPUID_HYBRID_CORETYPE_CORE	0x40		/* Core */

/*
 * Intel Tile Information
 * CPUID Fn0000_001d
 * %ecx == 0: Main leaf
 *	%eax: max_palette
 * %ecx == 1: Tile Palette1 Sub-leaf
 *	Tile palette 1
 */

/* %ecx */
#define CPUID_TILE_P1_TOTAL_B	__BITS(15, 0)
#define CPUID_TILE_P1_B_PERTILE	__BITS(31, 16)
#define CPUID_TILE_P1_B_PERLOW	__BITS(15, 0)
#define CPUID_TILE_P1_MAXNAMES	__BITS(31, 16)
#define CPUID_TILE_P1_MAXROWS	__BITS(15, 0)

/*
 * Intel TMUL Information
 * CPUID Fn0000_001e
 */

/* %ebx */
#define CPUID_TMUL_MAXK	__BITS(7, 0)	/* Rows or columns */
#define CPUID_TMUL_MAXN	__BITS(23, 8)	/* Column bytes */

/*
 * Intel extended features.
 * CPUID Fn80000001
 */
/* %edx */
#define CPUID_SYSCALL	__BIT(11)	/* SYSCALL/SYSRET */
#define CPUID_XD	__BIT(20)	/* Execute Disable (like CPUID_NOX) */
#define CPUID_PAGE1GB	__BIT(26)	/* 1GB Large Page Support */
#define CPUID_RDTSCP	__BIT(27)	/* Read TSC Pair Instruction */
#define CPUID_EM64T	__BIT(29)	/* Intel EM64T */

#define CPUID_INTEL_EXT_FLAGS	"\20"			     \
	"\14" "SYSCALL/SYSRET"	"\25" "XD"	"\33" "P1GB" \
	"\34" "RDTSCP"	"\36" "EM64T"

/* %ecx */
#define CPUID_LAHF	__BIT(0)       /* LAHF/SAHF in IA-32e mode, 64bit sub*/
		/*	__BIT(5) */	/* LZCNT. Same as AMD's CPUID_ABM */
#define CPUID_PREFETCHW	__BIT(8)	/* PREFETCHW */

#define CPUID_INTEL_FLAGS4	"\20"				\
	"\1" "LAHF"	"\02" "B01"	"\03" "B02"		\
			"\06" "LZCNT"				\
	"\11" "PREFETCHW"


/*
 * AMD/VIA extended features.
 * CPUID Fn80000001
 */
/* %edx */
/*	CPUID_SYSCALL			   SYSCALL/SYSRET */
#define CPUID_MPC	0x00080000	/* Multiprocessing Capable */
#define CPUID_NOX	0x00100000	/* No Execute Page Protection */
#define CPUID_MMXX	0x00400000	/* AMD MMX Extensions */
/*	CPUID_MMX			   MMX supported */
/*	CPUID_FXSR			   fast FP/MMX save/restore */
#define CPUID_FFXSR	0x02000000	/* FXSAVE/FXSTOR Extensions */
/*	CPUID_PAGE1GB			   1GB Large Page Support */
/*	CPUID_RDTSCP			   Read TSC Pair Instruction */
/*	CPUID_EM64T			   Long mode */
#define CPUID_3DNOW2	0x40000000	/* 3DNow! Instruction Extension */
#define CPUID_3DNOW	0x80000000	/* 3DNow! Instructions */

#define CPUID_EXT_FLAGS	"\20"						\
						"\14" "SYSCALL/SYSRET"	\
							"\24" "MPC"	\
	"\25" "NOX"			"\27" "MMXX"	"\30" "MMX"	\
	"\31" "FXSR"	"\32" "FFXSR"	"\33" "P1GB"	"\34" "RDTSCP"	\
			"\36" "LONG"	"\37" "3DNOW2"	"\40" "3DNOW"

/* %ecx (AMD) */
/* 	CPUID_LAHF			   LAHF/SAHF instruction */
#define CPUID_CMPLEGACY	  __BIT(1)	/* Compare Legacy */
#define CPUID_SVM	  __BIT(2)	/* Secure Virtual Machine */
#define CPUID_EAPIC	  __BIT(3)	/* Extended APIC space */
#define CPUID_ALTMOVCR0	  __BIT(4)	/* Lock Mov Cr0 */
#define CPUID_ABM	  __BIT(5)	/* LZCNT instruction */
#define CPUID_SSE4A	  __BIT(6)	/* SSE4A instruction set */
#define CPUID_MISALIGNSSE __BIT(7)	/* Misaligned SSE */
#define CPUID_3DNOWPF	  __BIT(8)	/* 3DNow Prefetch */
#define CPUID_OSVW	  __BIT(9)	/* OS visible workarounds */
#define CPUID_IBS	  __BIT(10)	/* Instruction Based Sampling */
#define CPUID_XOP	  __BIT(11)	/* XOP instruction set */
#define CPUID_SKINIT	  __BIT(12)	/* SKINIT */
#define CPUID_WDT	  __BIT(13)	/* watchdog timer support */
#define CPUID_LWP	  __BIT(15)	/* Light Weight Profiling */
#define CPUID_FMA4	  __BIT(16)	/* FMA4 instructions */
#define CPUID_TCE	  __BIT(17)	/* Translation cache Extension */
#define CPUID_NODEID	  __BIT(19)	/* NodeID MSR available */
#define CPUID_TBM	  __BIT(21)	/* TBM instructions */
#define CPUID_TOPOEXT	  __BIT(22)	/* cpuid Topology Extension */
#define CPUID_PCEC	  __BIT(23)	/* Perf Ctr Ext Core */
#define CPUID_PCENB	  __BIT(24)	/* Perf Ctr Ext NB */
#define CPUID_SPM	  __BIT(25)	/* Stream Perf Mon */
#define CPUID_DBE	  __BIT(26)	/* Data Breakpoint Extension */
#define CPUID_PTSC	  __BIT(27)	/* PerfTsc */
#define CPUID_L2IPERFC	  __BIT(28)	/* L2I performance counter Extension */
#define CPUID_MWAITX	  __BIT(29)	/* MWAITX/MONITORX support */
#define CPUID_ADDRMASKEXT __BIT(30)	/* Breakpoint Addressing Mask ext. */

#define CPUID_AMD_FLAGS4	"\20"					    \
	"\1" "LAHF"	"\2" "CMPLEGACY" "\3" "SVM"	"\4" "EAPIC"	    \
	"\5" "ALTMOVCR0" "\6" "LZCNT"	"\7" "SSE4A"	"\10" "MISALIGNSSE" \
	"\11" "3DNOWPREFETCH"						    \
			"\12" "OSVW"	"\13" "IBS"	"\14" "XOP"	    \
	"\15" "SKINIT"	"\16" "WDT"	"\17" "B14"	"\20" "LWP"	    \
	"\21" "FMA4"	"\22" "TCE"	"\23" "B18"	"\24" "NodeID"	    \
	"\25" "B20"	"\26" "TBM"	"\27" "TopoExt"	"\30" "PCExtC"	    \
	"\31" "PCExtNB"	"\32" "StrmPM"	"\33" "DBExt"	"\34" "PerfTsc"	    \
	"\35" "L2IPERFC" "\36" "MWAITX"	"\37" "AddrMaskExt" "\40" "B31"

/*
 * Advanced Power Management and RAS.
 * CPUID Fn8000_0007
 *
 * Only ITSC is for both Intel and AMD. Others are only for AMD.
 *
 *	%ebx: RAS capabilities. See below.
 *	%ecx: Processor Power Monitoring Interface.
 *	%edx: See below.
 *
 */
/* %ebx */
#define CPUID_RAS_OVFL_RECOV __BIT(0) /* MCA Overflow Recovery */
#define CPUID_RAS_SUCCOR  __BIT(1) /* Sw UnCorr. err. COntainment & Recovery */
#define CPUID_RAS_MCAX	  __BIT(3) /* MCA Extension */

#define CPUID_RAS_FLAGS		"\20"					      \
	"\1OVFL_RECOV"	"\2SUCCOR"		"\4" "MCAX"

/* %edx */
#define CPUID_APM_TS	   __BIT(0)	/* Temperature Sensor */
#define CPUID_APM_FID	   __BIT(1)	/* Frequency ID control */
#define CPUID_APM_VID	   __BIT(2)	/* Voltage ID control */
#define CPUID_APM_TTP	   __BIT(3)	/* THERMTRIP (PCI F3xE4 register) */
#define CPUID_APM_HTC	   __BIT(4)	/* Hardware thermal control (HTC) */
#define CPUID_APM_STC	   __BIT(5)	/* Software thermal control (STC) */
#define CPUID_APM_100	   __BIT(6)	/* 100MHz multiplier control */
#define CPUID_APM_HWP	   __BIT(7)	/* HW P-State control */
#define CPUID_APM_ITSC	   __BIT(8)	/* Invariant TSC */
#define CPUID_APM_CPB	   __BIT(9)	/* Core Performance Boost */
#define CPUID_APM_EFF	   __BIT(10)	/* Effective Frequency (read-only) */
#define CPUID_APM_PROCFI   __BIT(11)	/* Processor Feedback Interface */
#define CPUID_APM_PROCPR   __BIT(12)	/* Processor Power Reporting */
#define CPUID_APM_CONNSTBY __BIT(13)	/* Connected Standby */
#define CPUID_APM_RAPL	   __BIT(14)	/* Running Average Power Limit */

#define CPUID_APM_FLAGS		"\20"					      \
	"\1" "TS"	"\2" "FID"	"\3" "VID"	"\4" "TTP"	      \
	"\5" "HTC"	"\6" "STC"	"\7" "100"	"\10" "HWP"	      \
	"\11" "ITSC"	"\12" "CPB"	"\13" "EffFreq"	"\14" "PROCFI"	      \
	"\15" "PROCPR"	"\16" "CONNSTBY" "\17" "RAPL"

/*
 * AMD Processor Capacity Parameters and Extended Features.
 * CPUID Fn8000_0008
 * %eax: Long Mode Size Identifiers
 * %ebx: Extended Feature Identifiers
 * %ecx: Size Identifiers
 * %edx: RDPRU Register Identifier Range
 */

/* %ebx */
#define CPUID_CAPEX_CLZERO	   __BIT(0)  /* CLZERO instruction */
#define CPUID_CAPEX_IRPERF	   __BIT(1)  /* InstRetCntMsr */
#define CPUID_CAPEX_XSAVEERPTR	   __BIT(2)  /* RstrFpErrPtrs by XRSTOR */
#define CPUID_CAPEX_INVLPGB	   __BIT(3)  /* INVLPGB instruction */
#define CPUID_CAPEX_RDPRU	   __BIT(4)  /* RDPRU instruction */
#define CPUID_CAPEX_MBE		   __BIT(6)  /* Memory Bandwidth Enforcement */
#define CPUID_CAPEX_MCOMMIT	   __BIT(8)  /* MCOMMIT instruction */
#define CPUID_CAPEX_WBNOINVD	   __BIT(9)  /* WBNOINVD instruction */
#define CPUID_CAPEX_IBPB	   __BIT(12) /* Speculation Control IBPB */
#define CPUID_CAPEX_INT_WBINVD	   __BIT(13) /* Interruptable WB[NO]INVD */
#define CPUID_CAPEX_IBRS	   __BIT(14) /* Speculation Control IBRS */
#define CPUID_CAPEX_STIBP	   __BIT(15) /* Speculation Control STIBP */
#define CPUID_CAPEX_IBRS_ALWAYSON  __BIT(16) /* IBRS always on mode */
#define CPUID_CAPEX_STIBP_ALWAYSON __BIT(17) /* STIBP always on mode */
#define CPUID_CAPEX_PREFER_IBRS	   __BIT(18) /* IBRS preferred */
#define CPUID_CAPEX_IBRS_SAMEMODE  __BIT(19) /* IBRS same speculation limits */
#define CPUID_CAPEX_EFER_LSMSLE_UN __BIT(20) /* EFER.LMSLE is unsupported */
#define CPUID_CAPEX_AMD_PPIN	   __BIT(23) /* Protected Processor Inventory Number */
#define CPUID_CAPEX_SSBD	   __BIT(24) /* Speculation Control SSBD */
#define CPUID_CAPEX_VIRT_SSBD	   __BIT(25) /* Virt Spec Control SSBD */
#define CPUID_CAPEX_SSB_NO	   __BIT(26) /* SSBD not required */
#define CPUID_CAPEX_CPPC	   __BIT(27) /* Collaborative Processor Perf. Control */
#define CPUID_CAPEX_PSFD	   __BIT(28) /* Predictive Store Forward Dis */
#define CPUID_CAPEX_BTC_NO	   __BIT(29) /* Branch Type Confusion NO */
#define CPUID_CAPEX_IBPB_RET	   __BIT(30) /* Clear RET address predictor */

#define CPUID_CAPEX_FLAGS	"\20"					   \
	"\1CLZERO"	"\2IRPERF"	"\3XSAVEERPTR"	"\4INVLPGB"	   \
	"\5RDPRU"			"\7MBE"				   \
	"\11MCOMMIT"	"\12WBNOINVD"	"\13B10"			   \
	"\15IBPB"	"\16INT_WBINVD"	"\17IBRS"	"\20STIBP"	   \
	"\21IBRS_ALWAYSON" "\22STIBP_ALWAYSON" "\23PREFER_IBRS"		   \
							"\24IBRS_SAMEMODE" \
	"\25EFER_LSMSLE_UN"				"\30PPIN"	   \
	"\31SSBD"	"\32VIRT_SSBD"	"\33SSB_NO"	"\34CPPC"	   \
	"\35PSFD"	"\36BTC_NO"	"\37IBPB_RET"

/* %ecx */
#define CPUID_CAPEX_PerfTscSize	__BITS(17,16)	/* Perf. tstamp counter size */
#define CPUID_CAPEX_ApicIdSize	__BITS(15,12)	/* APIC ID Size */
#define CPUID_CAPEX_NC		__BITS(7,0)	/* Number of threads - 1 */

/*
 * AMD SVM Revision and Feature.
 * CPUID Fn8000_000a
 */

/* %eax: SVM revision */
#define CPUID_AMD_SVM_REV		__BITS(7,0)

/* %edx: SVM features */
#define CPUID_AMD_SVM_NP	      __BIT(0)  /* Nested Paging */
#define CPUID_AMD_SVM_LbrVirt	      __BIT(1)  /* LBR virtualization */
#define CPUID_AMD_SVM_SVML	      __BIT(2)  /* SVM Lock */
#define CPUID_AMD_SVM_NRIPS	      __BIT(3)  /* NRIP Save on #VMEXIT */
#define CPUID_AMD_SVM_TSCRateCtrl     __BIT(4)  /* MSR-based TSC rate ctrl */
#define CPUID_AMD_SVM_VMCBCleanBits   __BIT(5)  /* VMCB Clean Bits support */
#define CPUID_AMD_SVM_FlushByASID     __BIT(6)  /* Flush by ASID */
#define CPUID_AMD_SVM_DecodeAssist    __BIT(7)  /* Decode Assists support */
#define CPUID_AMD_SVM_PauseFilter     __BIT(10) /* PAUSE intercept filter */
#define CPUID_AMD_SVM_PFThreshold     __BIT(12) /* PAUSE filter threshold */
#define CPUID_AMD_SVM_AVIC	      __BIT(13) /* Advanced Virt. Intr. Ctrl */
#define CPUID_AMD_SVM_V_VMSAVE_VMLOAD __BIT(15) /* Virtual VM{SAVE/LOAD} */
#define CPUID_AMD_SVM_vGIF	      __BIT(16) /* Virtualized GIF */
#define CPUID_AMD_SVM_GMET	      __BIT(17) /* Guest Mode Execution Trap */
#define CPUID_AMD_SVM_X2AVIC	      __BIT(18) /* Virt. Intr. Ctrl 4 x2APIC */
#define CPUID_AMD_SVM_SSSCHECK	      __BIT(19)  /* Shadow Stack restrictions */
#define CPUID_AMD_SVM_SPEC_CTRL	      __BIT(20) /* SPEC_CTRL virtualization */
#define CPUID_AMD_SVM_ROGPT	      __BIT(21) /* Read-Only Guest PTable */
#define CPUID_AMD_SVM_HOST_MCE_OVERRIDE __BIT(23) /* #MC intercept */
#define CPUID_AMD_SVM_TLBICTL	      __BIT(24) /* TLB Intercept Control */
#define CPUID_AMD_SVM_VNMI	      __BIT(25) /* NMI Virtualization */
#define CPUID_AMD_SVM_IBSVIRT	      __BIT(26) /* IBS Virtualization */
#define CPUID_AMD_SVM_XLVTOFFFLTCHG   __BIT(27) /* Ext LVToffset FLT changed */
#define CPUID_AMD_SVM_VMCBADRCHKCHG   __BIT(28) /* VMCB addr check changed */
#define CPUID_AMD_SVM_BUSLOCKTHRESH   __BIT(29) /* Bus Lock Threshold */


#define CPUID_AMD_SVM_FLAGS	 "\20"					\
	"\1" "NP"	"\2" "LbrVirt"	"\3" "SVML"	"\4" "NRIPS"	\
	"\5" "TSCRate"	"\6" "VMCBCleanBits" 				\
			        "\7" "FlushByASID" "\10" "DecodeAssist"	\
	"\11" "B08"	"\12" "B09"	"\13" "PauseFilter" "\14" "B11"	\
	"\15" "PFThreshold" "\16" "AVIC" "\17" "B14"			\
						"\20" "V_VMSAVE_VMLOAD"	\
	"\21" "VGIF"	"\22" "GMET"	"\23x2AVIC"	"\24SSSCHECK"	\
	"\25" "SPEC_CTRL" "\26" "ROGPT"		"\30HOST_MCE_OVERRIDE"	\
	"\31" "TLBICTL"	"\32VNMI" "\33IBSVIRT" "\34ExtLvtOffsetFaultChg" \
	"\35VmcbAddrChkChg" "\36BusLockThreshold"

/*
 * AMD Instruction-Based Sampling Capabilities.
 * CPUID Fn8000_001b
 */
/* %eax */
#define CPUID_IBS_FFV		__BIT(0)  /* Feature Flags Valid */
#define CPUID_IBS_FETCHSUM	__BIT(1)  /* Fetch Sampling */
#define CPUID_IBS_OPSAM		__BIT(2)  /* execution SAMpling */
#define CPUID_IBS_RDWROPCNT	__BIT(3)  /* Read Write of Op Counter */
#define CPUID_IBS_OPCNT		__BIT(4)  /* OP CouNTing mode */
#define CPUID_IBS_BRNTRGT	__BIT(5)  /* Branch Target */
#define CPUID_IBS_OPCNTEXT	__BIT(6)  /* OpCurCnt and OpMaxCnt extended */
#define CPUID_IBS_RIPINVALIDCHK	__BIT(7)  /* Invalid RIP indication */
#define CPUID_IBS_OPBRNFUSE	__BIT(8)  /* Fused branch micro-op indicate */
#define CPUID_IBS_FETCHCTLEXTD	__BIT(9)  /* IC_IBS_EXTD_CTL MSR */
#define CPUID_IBS_OPDATA4	__BIT(10) /* IBS op data 4 MSR */
#define CPUID_IBS_L3MISSFILT	__BIT(11) /* L3 Miss Filtering */

#define CPUID_IBS_FLAGS	 "\20"						   \
	"\1IBSFFV"	"\2FetchSam"	"\3OpSam"	"\4RdWrOpCnt"	   \
	"\5OpCnt"	"\6BrnTrgt"	"\7OpCntExt"	"\10RipInvalidChk" \
	"\11OpBrnFuse" "\12IbsFetchCtlExtd" "\13IbsOpData4"		   \
						   "\14IbsL3MissFiltering"

/*
 * AMD Cache Topology Information.
 * CPUID Fn8000_001d
 * It's almost the same as Intel Deterministic Cache Parameter Leaf(0x04)
 * except the following:
 *	No Cores/package (%eax bit 31..26)
 *	No Complex cache indexing (%edx bit 2)
 */

/*
 * AMD Processor Topology Information.
 * CPUID Fn8000_001e
 * %eax: Extended APIC ID.
 * %ebx: Core Identifiers.
 * %ecx: Node Identifiers.
 */

/* %ebx */
#define CPUID_AMD_PROCT_COREID		   __BITS(7,0)	/* Core ID */
#define CPUID_AMD_PROCT_THREADS_PER_CORE   __BITS(15,8)	/* Threads/Core - 1 */

/* %ecx */
#define CPUID_AMD_PROCT_NODEID		   __BITS(7,0)	/* Node ID */
#define CPUID_AMD_PROCT_NODE_PER_PROCESSOR __BITS(10,8)	/* Node/Processor -1 */

/*
 * AMD Encrypted Memory Capabilities.
 * CPUID Fn8000_001f
 * %eax: flags
 * %ebx:  5-0: Cbit Position
 *       11-6: PhysAddrReduction
 *      15-12: NumVMPL
 * %ecx: 31-0: NumEncryptedGuests
 * %edx: 31-0: MinSevNoEsAsid
 */
#define CPUID_AMD_ENCMEM_SME	__BIT(0)   /* Secure Memory Encryption */
#define CPUID_AMD_ENCMEM_SEV	__BIT(1)   /* Secure Encrypted Virtualiz. */
#define CPUID_AMD_ENCMEM_PGFLMSR __BIT(2)  /* Page Flush MSR */
#define CPUID_AMD_ENCMEM_SEVES	__BIT(3)   /* SEV Encrypted State */
#define CPUID_AMD_ENCMEM_SEV_SNP __BIT(4)  /* Secure Nested Paging */
#define CPUID_AMD_ENCMEM_VMPL	__BIT(5)   /* Virtual Machine Privilege Lvl */
#define CPUID_AMD_ENCMEM_RMPQUERY __BIT(6) /* RMPQUERY instruction */
#define CPUID_AMD_ENCMEM_VMPLSSS __BIT(7)  /* VMPL Secure Shadow Stack */
#define CPUID_AMD_ENCMEM_SECTSC	__BIT(8)   /* Secure TSC */
#define CPUID_AMD_ENCMEM_TSCAUX_V __BIT(9)  /* TSC AUX Virtualization */
#define CPUID_AMD_ENCMEM_HECC	__BIT(10) /* HW Enf Cache Coh across enc dom */
#define CPUID_AMD_ENCMEM_64BH	__BIT(11)  /* 64Bit Host */
#define CPUID_AMD_ENCMEM_RSTRINJ __BIT(12) /* Restricted Injection */
#define CPUID_AMD_ENCMEM_ALTINJ	__BIT(13)  /* Alternate Injection */
#define CPUID_AMD_ENCMEM_DBGSWAP __BIT(14) /* Debug Swap */
#define CPUID_AMD_ENCMEM_PREVHOSTIBS __BIT(15) /* Prevent Host IBS */
#define CPUID_AMD_ENCMEM_VTE	__BIT(16)  /* Virtual Transparent Encryption */

#define CPUID_AMD_ENCMEM_VMGEXITP __BIT(17) /* VMGEXIT Parameter */
#define CPUID_AMD_ENCMEM_VIRTTOM __BIT(18)  /* Virtual TOM MSR */
#define CPUID_AMD_ENCMEM_IBSVGUEST __BIT(19) /* IBS Virt. for SEV-ES guest */
#define CPUID_AMD_ENCMEM_VMSA_REGPROT __BIT(24) /* VmsaRegProt */
#define CPUID_AMD_ENCMEM_SMTPROTECT __BIT(25) /* SMT Protection */
#define CPUID_AMD_ENCMEM_SVSM_COMMPAGE __BIT(28) /* SVSM Communication Page */
#define CPUID_AMD_ENCMEM_NESTED_VSMP __BIT(29) /* VIRT_{RMPUPDATE,PSMASH} */

#define CPUID_AMD_ENCMEM_FLAGS	 "\20"					      \
	"\1" "SME"	"\2" "SEV"	"\3" "PageFlushMsr"	"\4" "SEV-ES" \
	"\5" "SEV-SNP"	"\6" "VMPL"	"\7RMPQUERY"	"\10VmplSSS"	      \
	"\11SecureTSC"	"\12TscAuxVirt"	"\13HwEnfCacheCoh"  "\14" "64BitHost" \
	"\15" "RSTRINJ"	"\16" "ALTINJ"	"\17" "DebugSwap" "\20PreventHostIbs" \
	"\21VTE"      "\22VmgexitParam" "\23VirtualTomMsr" "\24IbsVirtGuest"  \
	"\31VmsaRegProt" "\32SmtProtection"				      \
	"\35SvsmCommPageMSR" "\36NestedVirtSnpMsr"

/*
 * AMD Extended Features 2.
 * CPUID Fn8000_0021
 */

/* %eax */
#define CPUID_AMDEXT2_NONESTEDDBP __BIT(0) /* No nested data breakpoints */
#define CPUID_AMDEXT2_FGKBNOSERIAL __BIT(1) /* {FS,GS,K}BASE WRMSR !serializ */
#define CPUID_AMDEXT2_LFENCESERIAL __BIT(2) /* LFENCE always serializing */
#define CPUID_AMDEXT2_SMMPGCFGLCK __BIT(3) /* SMM Paging configuration lock */
#define CPUID_AMDEXT2_NULLSELCLRB __BIT(6) /* Null segment selector clr base */
#define CPUID_AMDEXT2_UPADDRIGN	  __BIT(7) /* Upper Address Ignore */
#define CPUID_AMDEXT2_AUTOIBRS	  __BIT(8) /* Automatic IBRS */
#define CPUID_AMDEXT2_NOSMMCTL	  __BIT(9) /* SMM_CTL MSR is not supported */
#define CPUID_AMDEXT2_FSRS	  __BIT(10) /* Fast Short Rep Stosb */
#define CPUID_AMDEXT2_FSRC	  __BIT(11) /* Fast Short Rep Cmpsb */
#define CPUID_AMDEXT2_PREFETCHCTL __BIT(13) /* Prefetch control MSR */
#define CPUID_AMDEXT2_CPUIDUSRDIS __BIT(17) /* CPUID dis. for non-priv. soft */
#define CPUID_AMDEXT2_EPSF	  __BIT(18) /* Enhanced Predictive Store Fwd */

#define CPUID_AMDEXT2_FLAGS	 "\20"					      \
	"\1NoNestedDataBp" "\2FsGsKernelGsBaseNonSerializing"		      \
				"\3LfenceAlwaysSerialize" "\4SmmPgCfgLock"    \
			     "\7NullSelectClearsBase" "\10UpperAddressIgnore" \
	"\11AutomaticIBRS" "\12NoSmmCtlMSR"	"\13FSRS"	"\14FSRC"     \
			"\16PrefetchCtlMSR"				      \
			"\22CpuidUserDis"	"\23EPSF"

/*
 * AMD Extended Performance Monitoring and Debug
 * CPUID Fn8000_0022
 */

/* %eax */
#define CPUID_AXPERF_PERFMONV2	__BIT(0)  /* Version 2 */
#define CPUID_AXPERF_LBRSTACK	__BIT(1)  /* Last Branch Record Stack */
#define CPUID_AXPERF_LBRPMCFREEZE __BIT(2) /* Freezing LBR and PMC */

#define CPUID_AXPERF_FLAGS	 "\20"					      \
	"\1PerfMonV2"	"\2LbrStack"	"\3LbrAndPmcFreeze"

/* %ebx */
#define CPUID_AXPERF_NCPC      __BITS(3, 0)	/* Num of Core PMC counters */
#define CPUID_AXPERF_NLBRSTACK __BITS(9, 4)	/* Num of LBR Stack entries */
#define CPUID_AXPERF_NNBPC     __BITS(15, 10)	/* Num of NorthBridge PMCs */
#define CPUID_AXPERF_NUMCPC    __BITS(21, 16)	/* Num of UMC PMCs */

/*
 * Centaur Extended Feature flags.
 * CPUID FnC000_0001 (VIA "Nehemiah" or later)
 */
#define CPUID_VIA_HAS_AIS	__BIT(0)	/* Alternate Instruction Set supported */
						/* (VIA "Nehemiah" only) */
#define CPUID_VIA_DO_AIS	__BIT(1)	/* Alternate Instruction Set enabled */
						/* (VIA "Nehemiah" only) */
#define CPUID_VIA_HAS_RNG	__BIT(2)	/* Random number generator */
#define CPUID_VIA_DO_RNG	__BIT(3)
#define CPUID_VIA_HAS_ACE	__BIT(6)	/* AES Encryption */
#define CPUID_VIA_DO_ACE	__BIT(7)
#define CPUID_VIA_HAS_ACE2	__BIT(8)	/* AES+CTR instructions */
#define CPUID_VIA_DO_ACE2	__BIT(9)
#define CPUID_VIA_HAS_PHE	__BIT(10)	/* SHA1+SHA256 HMAC */
#define CPUID_VIA_DO_PHE	__BIT(11)
#define CPUID_VIA_HAS_PMM	__BIT(12)	/* RSA Instructions */
#define CPUID_VIA_DO_PMM	__BIT(13)

#define CPUID_FLAGS_PADLOCK	"\20"					    \
	"\3" "RNG"	"\7" "AES"	"\11" "AES/CTR"	"\13" "SHA1/SHA256" \
	"\15" "RSA"

/*
 * Model-Specific Registers
 */
#define MSR_TSC			0x010
#define MSR_IA32_PLATFORM_ID	0x017
#define MSR_APICBASE		0x01b
#define 	APICBASE_BSP		0x00000100	/* boot processor */
#define 	APICBASE_EXTD		0x00000400	/* x2APIC mode */
#define 	APICBASE_EN		0x00000800	/* software enable */
/*
 * APICBASE_PHYSADDR is actually variable-sized on some CPUs. But we're
 * only interested in the initial value, which is guaranteed to fit the
 * first 32 bits. So this macro is fine.
 */
#define 	APICBASE_PHYSADDR	0xfffff000	/* physical address */
#define MSR_EBL_CR_POWERON	0x02a
#define MSR_EBC_FREQUENCY_ID	0x02c	/* PIV only */
#define MSR_IA32_SPEC_CTRL	0x048
#define 	IA32_SPEC_CTRL_IBRS	0x01
#define 	IA32_SPEC_CTRL_STIBP	0x02
#define 	IA32_SPEC_CTRL_SSBD	0x04
#define MSR_IA32_PRED_CMD	0x049
#define 	IA32_PRED_CMD_IBPB	0x01
#define MSR_BIOS_UPDT_TRIG	0x079
#define MSR_BIOS_SIGN		0x08b
#define MSR_PERFCTR0		0x0c1
#define MSR_PERFCTR1		0x0c2
#define MSR_FSB_FREQ		0x0cd	/* Core Duo/Solo only */
#define MSR_MPERF		0x0e7
#define MSR_APERF		0x0e8
#define MSR_IA32_EXT_CONFIG	0x0ee	/* Undocumented. Core Solo/Duo only */
#define MSR_MTRRcap		0x0fe
#define MSR_IA32_ARCH_CAPABILITIES 0x10a
#define 	IA32_ARCH_RDCL_NO	0x01
#define 	IA32_ARCH_IBRS_ALL	0x02
#define 	IA32_ARCH_RSBA		0x04
#define 	IA32_ARCH_SKIP_L1DFL_VMENTRY 0x08
#define 	IA32_ARCH_SSB_NO	0x10
#define 	IA32_ARCH_MDS_NO	0x20
#define 	IA32_ARCH_IF_PSCHANGE_MC_NO 0x40
#define 	IA32_ARCH_TSX_CTRL	0x80
#define 	IA32_ARCH_TAA_NO	0x100
#define MSR_IA32_FLUSH_CMD	0x10b
#define 	IA32_FLUSH_CMD_L1D_FLUSH 0x01
#define MSR_TSX_FORCE_ABORT	0x10f
#define MSR_IA32_TSX_CTRL	0x122
#define 	IA32_TSX_CTRL_RTM_DISABLE	__BIT(0)
#define 	IA32_TSX_CTRL_TSX_CPUID_CLEAR	__BIT(1)
#define MSR_SYSENTER_CS		0x174	/* PII+ only */
#define MSR_SYSENTER_ESP	0x175	/* PII+ only */
#define MSR_SYSENTER_EIP	0x176	/* PII+ only */
#define MSR_MCG_CAP		0x179
#define MSR_MCG_STATUS		0x17a
#define MSR_MCG_CTL		0x17b
#define MSR_EVNTSEL0		0x186
#define MSR_EVNTSEL1		0x187
#define MSR_PERF_STATUS		0x198	/* Pentium M */
#define MSR_PERF_CTL		0x199	/* Pentium M */
#define MSR_THERM_CONTROL	0x19a
#define MSR_THERM_INTERRUPT	0x19b
#define MSR_THERM_STATUS	0x19c
#define MSR_THERM2_CTL		0x19d	/* Pentium M */
#define MSR_MISC_ENABLE		0x1a0
#define 	IA32_MISC_FAST_STR_EN	__BIT(0)
#define 	IA32_MISC_ATCC_EN	__BIT(3)
#define 	IA32_MISC_PERFMON_EN	__BIT(7)
#define 	IA32_MISC_BTS_UNAVAIL	__BIT(11)
#define 	IA32_MISC_PEBS_UNAVAIL	__BIT(12)
#define 	IA32_MISC_EISST_EN	__BIT(16)
#define 	IA32_MISC_MWAIT_EN	__BIT(18)
#define 	IA32_MISC_LIMIT_CPUID	__BIT(22)
#define 	IA32_MISC_XTPR_DIS	__BIT(23)
#define 	IA32_MISC_XD_DIS	__BIT(34)
#define MSR_TEMPERATURE_TARGET	0x1a2
#define MSR_DEBUGCTLMSR		0x1d9
#define MSR_LASTBRANCHFROMIP	0x1db
#define MSR_LASTBRANCHTOIP	0x1dc
#define MSR_LASTINTFROMIP	0x1dd
#define MSR_LASTINTTOIP		0x1de
#define MSR_ROB_CR_BKUPTMPDR6	0x1e0
#define MSR_MTRRphysBase0	0x200
#define MSR_MTRRphysMask0	0x201
#define MSR_MTRRphysBase1	0x202
#define MSR_MTRRphysMask1	0x203
#define MSR_MTRRphysBase2	0x204
#define MSR_MTRRphysMask2	0x205
#define MSR_MTRRphysBase3	0x206
#define MSR_MTRRphysMask3	0x207
#define MSR_MTRRphysBase4	0x208
#define MSR_MTRRphysMask4	0x209
#define MSR_MTRRphysBase5	0x20a
#define MSR_MTRRphysMask5	0x20b
#define MSR_MTRRphysBase6	0x20c
#define MSR_MTRRphysMask6	0x20d
#define MSR_MTRRphysBase7	0x20e
#define MSR_MTRRphysMask7	0x20f
#define MSR_MTRRphysBase8	0x210
#define MSR_MTRRphysMask8	0x211
#define MSR_MTRRphysBase9	0x212
#define MSR_MTRRphysMask9	0x213
#define MSR_MTRRphysBase10	0x214
#define MSR_MTRRphysMask10	0x215
#define MSR_MTRRphysBase11	0x216
#define MSR_MTRRphysMask11	0x217
#define MSR_MTRRphysBase12	0x218
#define MSR_MTRRphysMask12	0x219
#define MSR_MTRRphysBase13	0x21a
#define MSR_MTRRphysMask13	0x21b
#define MSR_MTRRphysBase14	0x21c
#define MSR_MTRRphysMask14	0x21d
#define MSR_MTRRphysBase15	0x21e
#define MSR_MTRRphysMask15	0x21f
#define MSR_MTRRfix64K_00000	0x250
#define MSR_MTRRfix16K_80000	0x258
#define MSR_MTRRfix16K_A0000	0x259
#define MSR_MTRRfix4K_C0000	0x268
#define MSR_MTRRfix4K_C8000	0x269
#define MSR_MTRRfix4K_D0000	0x26a
#define MSR_MTRRfix4K_D8000	0x26b
#define MSR_MTRRfix4K_E0000	0x26c
#define MSR_MTRRfix4K_E8000	0x26d
#define MSR_MTRRfix4K_F0000	0x26e
#define MSR_MTRRfix4K_F8000	0x26f
#define MSR_CR_PAT		0x277
#define MSR_MTRRdefType		0x2ff
#define MSR_MC0_CTL		0x400
#define MSR_MC0_STATUS		0x401
#define MSR_MC0_ADDR		0x402
#define MSR_MC0_MISC		0x403
#define MSR_MC1_CTL		0x404
#define MSR_MC1_STATUS		0x405
#define MSR_MC1_ADDR		0x406
#define MSR_MC1_MISC		0x407
#define MSR_MC2_CTL		0x408
#define MSR_MC2_STATUS		0x409
#define MSR_MC2_ADDR		0x40a
#define MSR_MC2_MISC		0x40b
#define MSR_MC3_CTL		0x40c
#define MSR_MC3_STATUS		0x40d
#define MSR_MC3_ADDR		0x40e
#define MSR_MC3_MISC		0x40f
#define MSR_MC4_CTL		0x410
#define MSR_MC4_STATUS		0x411
#define MSR_MC4_ADDR		0x412
#define MSR_MC4_MISC		0x413
				/* 0x480 - 0x490 VMX */
#define MSR_X2APIC_BASE		0x800	/* 0x800 - 0xBFF */
#define  MSR_X2APIC_ID			0x002	/* x2APIC ID. (RO) */
#define  MSR_X2APIC_VERS		0x003	/* Version. (RO) */
#define  MSR_X2APIC_TPRI		0x008	/* Task Prio. (RW) */
#define  MSR_X2APIC_PPRI		0x00a	/* Processor prio. (RO) */
#define  MSR_X2APIC_EOI			0x00b	/* End Int. (W) */
#define  MSR_X2APIC_LDR			0x00d	/* Logical dest. (RO) */
#define  MSR_X2APIC_SVR			0x00f	/* Spurious intvec (RW) */
#define  MSR_X2APIC_ISR			0x010	/* In-Service Status (RO) */
#define  MSR_X2APIC_TMR			0x018	/* Trigger Mode (RO) */
#define  MSR_X2APIC_IRR			0x020	/* Interrupt Req (RO) */
#define  MSR_X2APIC_ESR			0x028	/* Err status. (RW) */
#define  MSR_X2APIC_LVT_CMCI		0x02f	/* LVT CMCI (RW) */
#define  MSR_X2APIC_ICRLO		0x030	/* Int. cmd. (RW64) */
#define  MSR_X2APIC_LVTT		0x032	/* Loc.vec.(timer) (RW) */
#define  MSR_X2APIC_TMINT		0x033	/* Loc.vec (Thermal) (RW) */
#define  MSR_X2APIC_PCINT		0x034	/* Loc.vec (Perf Mon) (RW) */
#define  MSR_X2APIC_LVINT0		0x035	/* Loc.vec (LINT0) (RW) */
#define  MSR_X2APIC_LVINT1		0x036	/* Loc.vec (LINT1) (RW) */
#define  MSR_X2APIC_LVERR		0x037	/* Loc.vec (ERROR) (RW) */
#define  MSR_X2APIC_ICR_TIMER		0x038	/* Initial count (RW) */
#define  MSR_X2APIC_CCR_TIMER		0x039	/* Current count (RO) */
#define  MSR_X2APIC_DCR_TIMER		0x03e	/* Divisor config (RW) */
#define  MSR_X2APIC_SELF_IPI		0x03f	/* SELF IPI (W) */

/*
 * VIA "Nehemiah" or later MSRs
 */
#define MSR_VIA_RNG		0x0000110b
#define MSR_VIA_RNG_ENABLE	0x00000040
#define MSR_VIA_RNG_NOISE_MASK	0x00000300
#define MSR_VIA_RNG_NOISE_A	0x00000000
#define MSR_VIA_RNG_NOISE_B	0x00000100
#define MSR_VIA_RNG_2NOISE	0x00000300
#define MSR_VIA_FCR		0x00001107	/* Feature Control Register */
#define 	VIA_FCR_ACE_ENABLE	0x10000000	/* Enable PadLock (ex. RNG) */
#define 	VIA_FCR_CX8_REPORT	0x00000002	/* Enable CX8 CPUID reporting */
#define 	VIA_FCR_ALTINST_ENABLE	0x00000001	/* Enable ALTINST (C3 only) */

/*
 * AMD K6/K7 MSRs.
 */
#define MSR_K6_UWCCR		0xc0000085
#define MSR_K7_EVNTSEL0		0xc0010000
#define MSR_K7_EVNTSEL1		0xc0010001
#define MSR_K7_EVNTSEL2		0xc0010002
#define MSR_K7_EVNTSEL3		0xc0010003
#define MSR_K7_PERFCTR0		0xc0010004
#define MSR_K7_PERFCTR1		0xc0010005
#define MSR_K7_PERFCTR2		0xc0010006
#define MSR_K7_PERFCTR3		0xc0010007

/*
 * AMD K8 (Opteron) MSRs.
 */
#define MSR_SYSCFG	0xc0010010

#define MSR_EFER	0xc0000080		/* Extended feature enable */
#define 	EFER_SCE	0x00000001	/* SYSCALL extension */
#define 	EFER_LME	0x00000100	/* Long Mode Enable */
#define 	EFER_LMA	0x00000400	/* Long Mode Active */
#define 	EFER_NXE	0x00000800	/* No-Execute Enabled */
#define 	EFER_SVME	0x00001000	/* Secure Virtual Machine En. */
#define 	EFER_LMSLE	0x00002000	/* Long Mode Segment Limit E. */
#define 	EFER_FFXSR	0x00004000	/* Fast FXSAVE/FXRSTOR En. */
#define 	EFER_TCE	0x00008000	/* Translation Cache Ext. */

#define MSR_STAR	0xc0000081		/* 32 bit syscall gate addr */
#define MSR_LSTAR	0xc0000082		/* 64 bit syscall gate addr */
#define MSR_CSTAR	0xc0000083		/* compat syscall gate addr */
#define MSR_SFMASK	0xc0000084		/* flags to clear on syscall */

#define MSR_FSBASE	0xc0000100		/* 64bit offset for fs: */
#define MSR_GSBASE	0xc0000101		/* 64bit offset for gs: */
#define MSR_KERNELGSBASE 0xc0000102		/* storage for swapgs ins */

#define MSR_VMCR	0xc0010114	/* Virtual Machine Control Register */
#define 	VMCR_DPD	0x00000001	/* Debug port disable */
#define 	VMCR_RINIT	0x00000002	/* intercept init */
#define 	VMCR_DISA20	0x00000004	/* Disable A20 masking */
#define 	VMCR_LOCK	0x00000008	/* SVM Lock */
#define 	VMCR_SVMED	0x00000010	/* SVME Disable */
#define MSR_SVMLOCK	0xc0010118	/* SVM Lock key */

/*
 * These require a 'passcode' for access.  See cpufunc.h.
 */
#define MSR_HWCR	0xc0010015
#define 	HWCR_TLBCACHEDIS	0x00000008
#define 	HWCR_FFDIS		0x00000040

#define MSR_NB_CFG	0xc001001f
#define 	NB_CFG_DISIOREQLOCK	0x0000000000000008ULL
#define 	NB_CFG_DISDATMSK	0x0000001000000000ULL
#define 	NB_CFG_INITAPICCPUIDLO	(1ULL << 54)

/* AMD Errata 1474. */
#define MSR_CC6_CFG	0xc0010296
#define 	CC6_CFG_DISABLE_BITS	(__BIT(22) | __BIT(14) | __BIT(6))

#define MSR_LS_CFG	0xc0011020
#define 	LS_CFG_ERRATA_1033	__BIT(4)
#define 	LS_CFG_ERRATA_793	__BIT(15)
#define 	LS_CFG_ERRATA_1095	__BIT(57)
#define 	LS_CFG_DIS_LS2_SQUISH	0x02000000
#define 	LS_CFG_DIS_SSB_F15H	0x0040000000000000ULL
#define 	LS_CFG_DIS_SSB_F16H	0x0000000200000000ULL
#define 	LS_CFG_DIS_SSB_F17H	0x0000000000000400ULL

#define MSR_IC_CFG	0xc0011021
#define 	IC_CFG_DIS_SEQ_PREFETCH	0x00000800
#define 	IC_CFG_DIS_IND		0x00004000
#define 	IC_CFG_ERRATA_776	__BIT(26)

#define MSR_DC_CFG	0xc0011022
#define 	DC_CFG_DIS_CNV_WC_SSO	0x00000008
#define 	DC_CFG_DIS_SMC_CHK_BUF	0x00000400
#define 	DC_CFG_ERRATA_261	0x01000000

#define MSR_BU_CFG	0xc0011023
#define 	BU_CFG_ERRATA_298	0x0000000000000002ULL
#define 	BU_CFG_ERRATA_254	0x0000000000200000ULL
#define 	BU_CFG_ERRATA_309	0x0000000000800000ULL
#define 	BU_CFG_THRL2IDXCMPDIS	0x0000080000000000ULL
#define 	BU_CFG_WBPFSMCCHKDIS	0x0000200000000000ULL
#define 	BU_CFG_WBENHWSBDIS	0x0001000000000000ULL

#define MSR_FP_CFG	0xc0011028
#define 	FP_CFG_ERRATA_1049	__BIT(4)

#define MSR_DE_CFG	0xc0011029
#define 	DE_CFG_ERRATA_721	0x00000001
#define 	DE_CFG_LFENCE_SERIALIZE	__BIT(1)
#define 	DE_CFG_ERRATA_ZENBLEED	__BIT(9)
#define 	DE_CFG_ERRATA_1021	__BIT(13)

#define MSR_BU_CFG2	0xc001102a
#define 	BU_CFG2_CWPLUS_DIS	__BIT(24)

#define MSR_LS_CFG2	0xc001102d
#define 	LS_CFG2_ERRATA_1091	__BIT(34)

/* AMD Family10h MSRs */
#define MSR_OSVW_ID_LENGTH		0xc0010140
#define MSR_OSVW_STATUS			0xc0010141
#define MSR_UCODE_AMD_PATCHLEVEL	0x0000008b
#define MSR_UCODE_AMD_PATCHLOADER	0xc0010020

/* X86 MSRs */
#define MSR_RDTSCP_AUX			0xc0000103

/*
 * Constants related to MTRRs
 */
#define MTRR_N64K		8	/* numbers of fixed-size entries */
#define MTRR_N16K		16
#define MTRR_N4K		64

/*
 * the following four 3-byte registers control the non-cacheable regions.
 * These registers must be written as three separate bytes.
 *
 * NCRx+0: A31-A24 of starting address
 * NCRx+1: A23-A16 of starting address
 * NCRx+2: A15-A12 of starting address | NCR_SIZE_xx.
 *
 * The non-cacheable region's starting address must be aligned to the
 * size indicated by the NCR_SIZE_xx field.
 */
#define NCR1	0xc4
#define NCR2	0xc7
#define NCR3	0xca
#define NCR4	0xcd

#define NCR_SIZE_0K	0
#define NCR_SIZE_4K	1
#define NCR_SIZE_8K	2
#define NCR_SIZE_16K	3
#define NCR_SIZE_32K	4
#define NCR_SIZE_64K	5
#define NCR_SIZE_128K	6
#define NCR_SIZE_256K	7
#define NCR_SIZE_512K	8
#define NCR_SIZE_1M	9
#define NCR_SIZE_2M	10
#define NCR_SIZE_4M	11
#define NCR_SIZE_8M	12
#define NCR_SIZE_16M	13
#define NCR_SIZE_32M	14
#define NCR_SIZE_4G	15