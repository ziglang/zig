/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2013 Justin Hibbits
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

#ifndef _DEV_HWPMC_POWERPC_H_
#define	_DEV_HWPMC_POWERPC_H_ 1

#ifdef _KERNEL

#define	POWERPC_PMC_CAPS	(PMC_CAP_INTERRUPT | PMC_CAP_USER |     \
				 PMC_CAP_SYSTEM | PMC_CAP_EDGE |	\
				 PMC_CAP_THRESHOLD | PMC_CAP_READ |	\
				 PMC_CAP_WRITE | PMC_CAP_INVERT |	\
				 PMC_CAP_QUALIFIER)

#define POWERPC_PMC_KERNEL_ENABLE	(0x1 << 30)
#define POWERPC_PMC_USER_ENABLE		(0x1 << 31)

#define POWERPC_PMC_ENABLE	(POWERPC_PMC_KERNEL_ENABLE | POWERPC_PMC_USER_ENABLE)
#define	POWERPC_RELOAD_COUNT_TO_PERFCTR_VALUE(V)	(0x80000000-(V))
#define	POWERPC_PERFCTR_VALUE_TO_RELOAD_COUNT(P)	(0x80000000-(P))

#define	POWERPC_MAX_PMC_VALUE	0x7fffffffUL

#define	POWERPC_PMC_HAS_OVERFLOWED(n) (powerpc_pmcn_read(n) & (0x1 << 31))

/*
 * PMC value is used with OVERFLOWCNT to simulate a 64-bit counter to the
 * machine independent part of hwpmc.
 */
#define	PPC_OVERFLOWCNT(pm)	(pm)->pm_md.pm_powerpc.pm_powerpc_overflowcnt
#define	PPC_OVERFLOWCNT_MAX	0x200000000UL

struct powerpc_cpu {
	enum pmc_class	pc_class;
	struct pmc_hw	pc_ppcpmcs[];
};

struct pmc_ppc_event {
	enum pmc_event pe_event;
	uint32_t pe_flags;
#define  PMC_FLAG_PMC1	0x01
#define  PMC_FLAG_PMC2	0x02
#define  PMC_FLAG_PMC3	0x04
#define  PMC_FLAG_PMC4	0x08
#define  PMC_FLAG_PMC5	0x10
#define  PMC_FLAG_PMC6	0x20
#define  PMC_FLAG_PMC7	0x40
#define  PMC_FLAG_PMC8	0x80
	uint32_t pe_code;
};

extern struct powerpc_cpu **powerpc_pcpu;
extern struct pmc_ppc_event *ppc_event_codes;
extern size_t ppc_event_codes_size;
extern int ppc_event_first;
extern int ppc_event_last;
extern int ppc_max_pmcs;
extern enum pmc_class ppc_class;

extern void (*powerpc_set_pmc)(int cpu, int ri, int config);
extern pmc_value_t (*powerpc_pmcn_read)(unsigned int pmc);
extern void (*powerpc_pmcn_write)(unsigned int pmc, uint32_t val);
extern void (*powerpc_resume_pmc)(bool ie);

int pmc_e500_initialize(struct pmc_mdep *pmc_mdep);
int pmc_mpc7xxx_initialize(struct pmc_mdep *pmc_mdep);
int pmc_ppc970_initialize(struct pmc_mdep *pmc_mdep);
int pmc_power8_initialize(struct pmc_mdep *pmc_mdep);

int powerpc_describe(int cpu, int ri, struct pmc_info *pi, struct pmc **ppmc);
int powerpc_get_config(int cpu, int ri, struct pmc **ppm);
int powerpc_pcpu_init(struct pmc_mdep *md, int cpu);
int powerpc_pcpu_fini(struct pmc_mdep *md, int cpu);
int powerpc_allocate_pmc(int cpu, int ri, struct pmc *pm,
    const struct pmc_op_pmcallocate *a);
int powerpc_release_pmc(int cpu, int ri, struct pmc *pmc);
int powerpc_start_pmc(int cpu, int ri, struct pmc *pm);
int powerpc_stop_pmc(int cpu, int ri, struct pmc *pm);
int powerpc_config_pmc(int cpu, int ri, struct pmc *pm);
pmc_value_t powerpc_pmcn_read_default(unsigned int pmc);
void powerpc_pmcn_write_default(unsigned int pmc, uint32_t val);
int powerpc_read_pmc(int cpu, int ri, struct pmc *pm, pmc_value_t *v);
int powerpc_write_pmc(int cpu, int ri, struct pmc *pm, pmc_value_t v);
int powerpc_pmc_intr(struct trapframe *tf);

#endif /* _KERNEL */

#endif	/* _DEV_HWPMC_POWERPC_H_ */