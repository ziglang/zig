/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2008 Joseph Koshy
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _DEV_HWPMC_CORE_H_
#define	_DEV_HWPMC_CORE_H_ 1

#define	IA32_PERF_CAPABILITIES		0x345
#define	PERFCAP_LBR_FORMAT		0x003f
#define	PERFCAP_PEBS_TRAP		0x0040
#define	PERFCAP_PEBS_SAVEARCH		0x0080
#define	PERFCAP_PEBS_RECFORMAT		0x0f00
#define	PERFCAP_SMM_FREEZE		0x1000
#define	PERFCAP_FW_WRITE		0x2000	/* full width write aliases */

#define	IAF_OS		0x1
#define	IAF_USR		0x2
#define	IAF_ANY		0x4
#define	IAF_PMI		0x8

/*
 * Programmable PMCs.
 */
struct pmc_md_iap_op_pmcallocate {
	uint64_t	pm_iap_config;
	uint64_t	pm_iap_rsp;
};

#define	IAP_EVSEL(C)	((C) & 0xFF)
#define	IAP_UMASK(C)	(((C) & 0xFF) << 8)
#define	IAP_USR		(1 << 16)
#define	IAP_OS		(1 << 17)
#define	IAP_EDGE	(1 << 18)
#define	IAP_INT		(1 << 20)
#define	IAP_ANY		(1 << 21)
#define	IAP_EN		(1 << 22)
#define	IAP_INV		(1 << 23)
#define	IAP_CMASK(C)	(((C) & 0xFF) << 24)

#define	IAP_EVSEL_GET(C)	((C) & 0xFF)
#define	IAP_UMASK_GET(C)	(((C) & 0xFF00) >> 8)

#define	IA_OFFCORE_RSP_MASK_I7WM	0x000000F7FF
#define	IA_OFFCORE_RSP_MASK_SBIB	0x3F807F8FFF

#ifdef	_KERNEL

/*
 * Fixed-function counters.
 */

#define	IAF_MASK				0x000000010000000f

#define	IAF_CTR0				0x309
#define	IAF_CTR1				0x30A
#define	IAF_CTR2				0x30B

/*
 * The IAF_CTRL MSR is laid out in the following way.
 *
 * Bit Position    Use
 * 63 - 45         Reserved (do not touch)
 * 44              Ctr 3 Adaptive Record (v5)
 * 43 - 41         Reserved (do not touch)
 * 40              Ctr 2 Adaptive Record (v5)
 * 39 - 37         Reserved (do not touch)
 * 36              Ctr 1 Adaptive Record (v5)
 * 35 - 33         Reserved (do not touch)
 * 32              Ctr 0 Adaptive Record (v5)
 * 15              Ctr 3 PMI
 * 14              Ctr 3 Any Thread (v3)
 * 13-12           Ctr 3 Enable
 * 11              Ctr 2 PMI
 * 10              Ctr 2 Any Thread (v3)
 * 9-8             Ctr 2 Enable
 * 7               Ctr 1 PMI
 * 6               Ctr 1 Any Thread (v3)
 * 5-4             Ctr 1 Enable
 * 3               Ctr 0 PMI
 * 2               Ctr 0 Any Thread (v3)
 * 1-0             Ctr 0 Enable (3: All Levels, 2: User, 1: OS, 0: Disable)
 */

#define	IAF_OFFSET				32
#define	IAF_CTRL				0x38D

/*
 * Programmable counters.
 */

#define	IAP_PMC0				0x0C1
#define	IAP_A_PMC0				0x4C1

/*
 * IAP_EVSEL(n) is laid out in the following way.
 *
 * Bit Position    Use
 * 63-35           Reserved (do not touch)
 * 34              Adaptive Record (v5)
 * 33              IN_TX (v3)
 * 32              IN_TXCP (v3)
 * 31-24           Counter Mask
 * 23              Invert
 * 22              Enable
 * 21              Any Thread (v3)
 * 20              APIC Interrupt Enable
 * 19              Pin Control
 * 18              Edge Detect
 * 17              OS
 * 16              User
 * 15-8            Unit Mask
 * 7-0             Event Select
 */

#define	IAP_EVSEL0				0x186

/*
 * Simplified programming interface in Intel Performance Architecture
 * v2 and later.
 */

#define	IA_GLOBAL_STATUS			0x38E
#define	IA_GLOBAL_CTRL				0x38F

/*
 * IA_GLOBAL_CTRL is laid out in the following way.
 * 
 * Bit Position    Use
 * 63-49           Reserved (do not touch)
 * 48              Perf Metrics Enable (v5)
 * 47-36           Reserved (do not touch)
 * 35              IAF Counter 3 Enable
 * 34              IAF Counter 2 Enable
 * 33              IAF Counter 1 Enable
 * 32              IAF Counter 0 Enable
 * 31-0            Depends on programmable counters
 */

#define	IA_GLOBAL_OVF_CTRL			0x390
#define	IA_GLOBAL_STATUS_RESET			0x390
#define	IA_GLOBAL_STATUS_SET			0x391		/* v4 */

#define	IA_GLOBAL_STATUS_FLAG_CONDCHG		(1ULL << 63)
#define	IA_GLOBAL_STATUS_FLAG_OVFBUF		(1ULL << 62)
#define	IA_GLOBAL_STATUS_FLAG_OVFUNCORE		(1ULL << 61)	/* v3 */
#define	IA_GLOBAL_STATUS_FLAG_ASCI		(1ULL << 60)	/* v4 */
#define	IA_GLOBAL_STATUS_FLAG_CTR_FRZ		(1ULL << 59)	/* v4 */
#define	IA_GLOBAL_STATUS_FLAG_LBP_FRZ		(1ULL << 58)	/* v4 */
#define	IA_GLOBAL_STATUS_FLAG_TRACETOPAPMI	(1ULL << 55)	/* v4 */

#define	IA_GLOBAL_INUSE				0x392		/* v4 */

/*
 * Offcore response configuration.
 */
#define	IA_OFFCORE_RSP0				0x1A6
#define	IA_OFFCORE_RSP1				0x1A7

struct pmc_md_iaf_pmc {
	uint64_t	pm_iaf_ctrl;
};

struct pmc_md_iap_pmc {
	uint64_t	pm_iap_evsel;
	uint64_t	pm_iap_rsp;
};

/*
 * Prototypes.
 */

int	pmc_core_initialize(struct pmc_mdep *_md, int _maxcpu,
	    int _version_override);
void	pmc_core_finalize(struct pmc_mdep *_md);

int	pmc_iaf_initialize(struct pmc_mdep *_md, int _maxcpu, int _npmc, int _width);
void	pmc_iaf_finalize(struct pmc_mdep *_md);

int	pmc_iap_initialize(struct pmc_mdep *_md, int _maxcpu, int _npmc, int _width,
	    int _flags);
void	pmc_iap_finalize(struct pmc_mdep *_md);

#endif	/* _KERNEL */
#endif	/* _DEV_HWPMC_CORE_H */