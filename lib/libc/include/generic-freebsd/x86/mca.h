/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2009 Hudson River Trading LLC
 * Written by: John H. Baldwin <jhb@FreeBSD.org>
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

#ifndef __X86_MCA_H__
#define	__X86_MCA_H__

struct mca_record {
	uint64_t	mr_status;
	uint64_t	mr_addr;
	uint64_t	mr_misc;
	uint64_t	mr_tsc;
	int		mr_apic_id;
	int		mr_bank;
	uint64_t	mr_mcg_cap;
	uint64_t	mr_mcg_status;
	int		mr_cpu_id;
	int		mr_cpu_vendor_id;
	int		mr_cpu;
};

enum mca_stat_types {
	MCA_T_NONE = 0,
	MCA_T_UNCLASSIFIED,
	MCA_T_UCODE_ROM_PARITY,
	MCA_T_EXTERNAL,
	MCA_T_FRC,
	MCA_T_INTERNAL_PARITY,
	MCA_T_SMM_HANDLER,
	MCA_T_INTERNAL_TIMER,
	MCA_T_GENERIC_IO,
	MCA_T_INTERNAL,
	MCA_T_MEMORY,
	MCA_T_TLB,
	MCA_T_MEMCONTROLLER_GEN,
	MCA_T_MEMCONTROLLER_RD,
	MCA_T_MEMCONTROLLER_WR,
	MCA_T_MEMCONTROLLER_AC,
	MCA_T_MEMCONTROLLER_MS,
	MCA_T_MEMCONTROLLER_OTHER,
	MCA_T_CACHE,
	MCA_T_BUS,
	MCA_T_UNKNOWN,
	MCA_T_COUNT /* Must stay last */
};

#ifdef _KERNEL

void	cmc_intr(void);
void	mca_init(void);
void	mca_intr(void);
void	mca_resume(void);

#endif

#endif /* !__X86_MCA_H__ */