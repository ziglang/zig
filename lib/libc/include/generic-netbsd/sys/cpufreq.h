/*	$NetBSD: cpufreq.h,v 1.5 2011/10/27 05:13:04 jruoho Exp $ */

/*-
 * Copyright (c) 2011 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jukka Ruohonen.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
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
#ifndef	_SYS_CPUFREQ_H_
#define	_SYS_CPUFREQ_H_

#ifndef _KERNEL
#include <stdbool.h>
#endif

#ifdef _KERNEL
#ifndef _SYS_XCALL_H_
#include <sys/xcall.h>
#endif
#endif

#define CPUFREQ_NAME_MAX	 16
#define CPUFREQ_STATE_MAX	 32
#define CPUFREQ_LATENCY_MAX	 UINT32_MAX

#define CPUFREQ_STATE_ENABLED	 UINT32_MAX
#define CPUFREQ_STATE_DISABLED	 UINT32_MAX - 1

struct cpufreq_state {
	uint32_t		 cfs_freq;	  /* MHz  */
	uint32_t		 cfs_power;	  /* mW   */
	uint32_t		 cfs_latency;	  /* usec */
	uint32_t		 cfs_index;
	uint32_t		 cfs_reserved[5];
};

struct cpufreq {
	char			 cf_name[CPUFREQ_NAME_MAX];
	uint32_t		 cf_state_count;
	uint32_t		 cf_state_target;
	uint32_t		 cf_state_current;
	uint32_t		 cf_reserved[5];
	u_int			 cf_index;

#ifdef _KERNEL
	bool			 cf_mp;
	bool			 cf_init;
	void			*cf_cookie;
	xcfunc_t		 cf_get_freq;
	xcfunc_t		 cf_set_freq;
	uint32_t		 cf_state_saved;
	struct cpufreq_state	 cf_state[CPUFREQ_STATE_MAX];
#endif	/* _KERNEL */
};

#ifdef _KERNEL
void		cpufreq_init(void);
int		cpufreq_register(struct cpufreq *);
void		cpufreq_deregister(void);
void		cpufreq_suspend(struct cpu_info *);
void		cpufreq_resume(struct cpu_info *);
uint32_t	cpufreq_get(struct cpu_info *);
int		cpufreq_get_backend(struct cpufreq *);
int		cpufreq_get_state(uint32_t, struct cpufreq_state *);
int		cpufreq_get_state_index(uint32_t, struct cpufreq_state *);
void		cpufreq_set(struct cpu_info *, uint32_t);
void		cpufreq_set_all(uint32_t);
#endif	/* _KERNEL */

#endif /* _SYS_CPUFREQ_H_ */