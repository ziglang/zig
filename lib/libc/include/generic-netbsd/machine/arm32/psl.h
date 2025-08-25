/*	$NetBSD: psl.h,v 1.21 2016/01/23 21:39:18 christos Exp $	*/

/*
 * Copyright (c) 1995 Mark Brinicombe.
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Mark Brinicombe
 *	for the NetBSD Project.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * RiscBSD kernel project
 *
 * psl.h
 *
 * spl prototypes.
 * Eventually this will become a set of defines.
 *
 * Created      : 21/07/95
 */

#ifndef _ARM_PSL_H_
#define _ARM_PSL_H_
#include <machine/intr.h>

/*
 * These are the different SPL states
 *
 * Each state has an interrupt mask associated with it which
 * indicate which interrupts are allowed.
 */

#define spl0()		splx(IPL_NONE)
#define splsoftclock()	raisespl(IPL_SOFTCLOCK)
#define splsoftbio()	raisespl(IPL_SOFTBIO)
#define splsoftnet()	raisespl(IPL_SOFTNET)
#define splsoftserial()	raisespl(IPL_SOFTSERIAL)
#define splvm()		raisespl(IPL_VM)
#define splsched()	raisespl(IPL_SCHED)
#define splhigh()	raisespl(IPL_HIGH)

#define	IPL_SAFEPRI	IPL_NONE		/* for kern_sleepq.c */

#ifdef _KERNEL
#ifndef _LOCORE
#include <sys/types.h>

int raisespl	(int);
int lowerspl	(int);
void splx	(int);

typedef uint8_t ipl_t;
typedef struct {
	uint8_t _ipl;
} ipl_cookie_t;

static inline ipl_cookie_t
makeiplcookie(ipl_t ipl)
{

	return (ipl_cookie_t){._ipl = (uint8_t)ipl};
}

static inline int
splraiseipl(ipl_cookie_t icookie)
{

	return raisespl(icookie._ipl);
}
#endif /* _LOCORE */
#endif /* _KERNEL */

#endif /* _ARM_PSL_H_ */
/* End of psl.h */