/*	$NetBSD: intr.h,v 1.14 2021/01/24 07:36:54 mrg Exp $ */

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Paul Kranenburg.
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
 * Device class interrupt levels
 * Note: sun4 and sun4c hardware only has software interrupt available
 *	 on level 1, 4 or 6. This limits the choice of the various
 * 	 IPL_SOFT* symbols to one of those three values.
 */
#define IPL_NONE	0	/* nothing */
#define IPL_SOFTCLOCK	1	/* timeouts */
#define IPL_SOFTNET	1	/* protocol stack */
#define IPL_SOFTBIO	1	/* block I/O */
#define IPL_SOFTAUDIO	4	/* second-level audio */
#define IPL_SOFTFDC	4	/* second-level floppy */
#define IPL_SOFTSERIAL	6	/* serial */
#define IPL_VM		7	/* memory allocation */
#define IPL_SCHED	11	/* scheduler */
#define IPL_HIGH	15	/* everything */

/*
 * fd hardware, ts102, and tadpole microcontroller interrupts are at level 11
 */

#define	IPL_FD		IPL_SCHED
#define	IPL_TS102	IPL_SCHED

/*
 * zs hardware interrupts are at level 12
 * su (com) hardware interrupts are at level 13
 * IPL_SERIAL must protect them all.
 */

#define	IPL_ZS		IPL_HIGH

/*
 * IPL_SAFEPRI is a safe priority for sleep to set for a spin-wait
 * during autoconfiguration or after a panic.
 */
#define	IPL_SAFEPRI	0

#if defined(_KERNEL) && !defined(_LOCORE)
void *
sparc_softintr_establish(int level, void (*fun)(void *), void *arg);

void
sparc_softintr_disestablish(void *cookie);

/*
 * NB that sparc_softintr_schedule() casts the cookie to an int *.
 * This is to get the sic_pilreq member of the softintr_cookie
 * structure, which is otherwise internal to intr.c.
 */
#if defined(SUN4M) || defined(SUN4D)
extern int (*moduleerr_handler)(void);
extern int (*memerr_handler)(void);
extern void	raise(int, int);
#if !(defined(SUN4) || defined(SUN4C))
#define sparc_softintr_schedule(cookie)	raise(0, *((int *) (cookie)))
#else /* both defined */
#define sparc_softintr_schedule(cookie) do {		\
	if (CPU_ISSUN4M || CPU_ISSUN4D)		\
		raise(0, *((int *)(cookie)));	\
	else					\
		ienab_bis(*((int *)(cookie)));	\
} while (0)
#endif	/* SUN4  || SUN4C */
#else	/* SUN4M || SUN4D */
#define sparc_softintr_schedule(cookie)	ienab_bis(*((int *) (cookie)))
#endif	/* SUN4M || SUN4D */

#if 0
void sparc_softintr_schedule(void *cookie);
#endif
#endif /* KERNEL && !_LOCORE */