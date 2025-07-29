/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 Ampere Computing LLC
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

#ifndef _DEV_HWPMC_PMU_DMC620_REG_H_
#define	_DEV_HWPMC_PMU_DMC620_REG_H_

#define	DMC620_UNIT_PER_SOCKET	8
#define	DMC620_MAX_SOCKET	2
#define	DMC620_UNIT_MAX		(DMC620_UNIT_PER_SOCKET * DMC620_MAX_SOCKET)

#define	DMC620_SNAPSHOT_REQ		0x000 /* WO */
#define	DMC620_SNAPSHOT_ACK		0x004 /* RO */
#define	DMC620_OVERFLOW_STATUS_CLKDIV2	0x008 /* RW */
#define	DMC620_OVERFLOW_STATUS_CLK	0x00C /* RW */

#define	DMC620_COUNTER_MASK_LO		0x000 /* RW */
#define	DMC620_COUNTER_MASK_HI		0x004 /* RW */
#define	DMC620_COUNTER_MATCH_LO		0x008 /* RW */
#define	DMC620_COUNTER_MATCH_HI		0x00C /* RW */
#define	DMC620_COUNTER_CONTROL		0x010 /* RW */
#define		DMC620_COUNTER_CONTROL_ENABLE		(1 << 0)
#define		DMC620_COUNTER_CONTROL_INVERT		(1 << 1)
#define		DMC620_COUNTER_CONTROL_EVENT_SHIFT	2
#define		DMC620_COUNTER_CONTROL_EVENT_MASK	(0x1f << 2)
#define		DMC620_COUNTER_CONTROL_INCR_SHIFT	7
#define		DMC620_COUNTER_CONTROL_INCR_MASK	(0x3 << 7)
#define	DMC620_COUNTER_SNAPSHOT_VALUE_LO 0x018 /* RO */
#define	DMC620_COUNTER_VALUE_LO		0x020 /* RW */

#define	DMC620_CLKDIV2_COUNTERS_BASE	0x010
#define	DMC620_CLKDIV2_COUNTERS_OFF	0x28
#define	DMC620_CLKDIV2_COUNTERS_N	8
#define	DMC620_CLKDIV2_REG(u, r)	(DMC620_CLKDIV2_COUNTERS_BASE +	\
    (DMC620_CLKDIV2_COUNTERS_OFF * (u)) + (r))

#define DMC620_CLK_COUNTERS_BASE	0x150
#define	DMC620_CLK_COUNTERS_OFF		0x28
#define	DMC620_CLK_COUNTERS_N		2
#define	DMC620_CLK_REG(u, r)		(DMC620_CLK_COUNTERS_BASE +	\
    (DMC620_CLK_COUNTERS_OFF * (u)) + (r))

/* CLK counters continue registers set. */
#define	DMC620_REG(u, r)		(DMC620_CLKDIV2_COUNTERS_BASE +	\
    (DMC620_CLKDIV2_COUNTERS_OFF * (u)) + (r))

#define	DMC620_PMU_DEFAULT_UNITS_N	8

#define	DMC620_COUNTERS_N	(DMC620_CLKDIV2_COUNTERS_N + \
    DMC620_CLK_COUNTERS_N)

/* IO from HWPMC module to driver. */
uint32_t pmu_dmc620_rd4(void *arg, u_int cntr, off_t reg);
void pmu_dmc620_wr4(void *arg, u_int cntr, off_t reg, uint32_t val);

/* Driver's interrupt notification to HWPMC module. */
int dmc620_intr(struct trapframe *tf, int c, int unit, int ri);

/* Registration of counters pool. */
void dmc620_pmc_register(int unit, void *argi, int domain);
void dmc620_pmc_unregister(int unit);

#endif /*_DEV_HWPMC_PMU_DMC620_REG_H_ */