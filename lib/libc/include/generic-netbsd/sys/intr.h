/*	$NetBSD: intr.h,v 1.21 2020/05/17 14:11:30 ad Exp $	*/

/*-
 * Copyright (c) 2007, 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Andrew Doran.
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

#ifndef _SYS_INTR_H_
#define	_SYS_INTR_H_

#define INTRIDBUF 64
#define INTRDEVNAMEBUF 256

#ifdef _KERNEL

#include <sys/types.h>

struct cpu_info;

/* Public interface. */
void	*softint_establish(u_int, void (*)(void *), void *);
void	softint_disestablish(void *);
void	softint_schedule(void *);
void	softint_schedule_cpu(void *, struct cpu_info *);

/* MI hooks. */
void	softint_init(struct cpu_info *);
lwp_t	*softint_picklwp(void);
void	softint_block(lwp_t *);

/* MD-MI interface. */
void	softint_init_md(lwp_t *, u_int, uintptr_t *);
#ifndef __HAVE_MD_SOFTINT_TRIGGER
void	softint_trigger(uintptr_t);
#endif
void	softint_dispatch(lwp_t *, int);

/* Flags for softint_establish(). */
#define	SOFTINT_BIO	0x0000
#define	SOFTINT_CLOCK	0x0001
#define	SOFTINT_SERIAL	0x0002
#define	SOFTINT_NET	0x0003
#define	SOFTINT_MPSAFE	0x0100
#define	SOFTINT_RCPU	0x0200

/* Implementation private flags. */
#define	SOFTINT_PENDING	0x1000

#define	SOFTINT_COUNT	0x0004
#define	SOFTINT_LVLMASK	0x00ff
#define	SOFTINT_IMPMASK	0xf000

extern u_int	softint_timing;

/*
 * Historical aliases.
 */
#define	IPL_BIO		IPL_VM
#define	IPL_NET		IPL_VM
#define	IPL_TTY		IPL_VM
#define	IPL_AUDIO	IPL_SCHED
#define	IPL_CLOCK	IPL_SCHED
#define	IPL_SERIAL	IPL_HIGH

#define	splbio()	splvm()
#define	splnet()	splvm()
#define	spltty()	splvm()
#define	splaudio()	splsched()
#define	splclock()	splsched()
#define	splserial()	splhigh()

#include <machine/intr.h>

#elif defined(_KMEMUSER)
#define	SOFTINT_COUNT	0x0004
#endif	/* _KERNEL */

#endif	/* _SYS_INTR_H_ */