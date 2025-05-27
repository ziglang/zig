/* 	$NetBSD: footbridge_intr.h,v 1.22 2021/08/13 11:40:43 skrll Exp $	*/

/*
 * Copyright (c) 2001, 2002 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Jason R. Thorpe for Wasabi Systems, Inc.
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
 *	This product includes software developed for the NetBSD Project by
 *	Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _FOOTBRIDGE_INTR_H_
#define _FOOTBRIDGE_INTR_H_

#ifndef _LOCORE
typedef uint8_t ipl_t;
typedef struct {
	ipl_t _ipl;
} ipl_cookie_t;

#include <arm/mutex.h>
#endif
#include <arm/cpu.h>
#include <arm/armreg.h>

#define IPL_NONE	0	/* nothing */
#define IPL_SOFTCLOCK	1	/* clock soft interrupts */
#define IPL_SOFTBIO	2	/* block i/o */
#define IPL_SOFTNET	3	/* network software interrupts */
#define IPL_SOFTSERIAL	4	/* serial software interrupts */
#define IPL_VM		5	/* memory allocation */
#define IPL_SCHED	6	/* clock */
#define IPL_HIGH	7	/* everything */

#define NIPL		8

#define	IST_UNUSABLE	-1	/* interrupt cannot be used */
#define	IST_NONE	0	/* none (dummy) */
#define	IST_PULSE	1	/* pulsed */
#define	IST_EDGE	2	/* edge-triggered */
#define	IST_LEVEL	3	/* level-triggered */

#define	ARM_IRQ_HANDLER	_C_LABEL(footbridge_intr_dispatch)

#ifndef _LOCORE
#include <arm/cpufunc.h>

#include <arm/footbridge/dc21285mem.h>
#include <arm/footbridge/dc21285reg.h>

#define INT_SWMASK							\
	((1U << IRQ_SOFTINT) | (1U << IRQ_RESERVED0) |			\
	 (1U << IRQ_RESERVED1) | (1U << IRQ_RESERVED2))
#define ICU_INT_HWMASK	(0xffffffff & ~(INT_SWMASK |  (1U << IRQ_RESERVED3)))

/* only call this with interrupts off */
static inline void __attribute__((__unused__))
footbridge_set_intrmask(void)
{
	extern volatile uint32_t intr_enabled;
	volatile uint32_t * const dc21285_armcsr_vbase =
	    (volatile uint32_t *)(DC21285_ARMCSR_VBASE);

	/* fetch once so we write the same number to both registers */
	uint32_t tmp = intr_enabled & ICU_INT_HWMASK;

	dc21285_armcsr_vbase[IRQ_ENABLE_SET>>2] = tmp;
	dc21285_armcsr_vbase[IRQ_ENABLE_CLEAR>>2] = ~tmp;
}

static inline void __attribute__((__unused__))
footbridge_splx(int ipl)
{
	extern int footbridge_imask[];
	extern volatile uint32_t intr_enabled;
	extern volatile int footbridge_ipending;
	int oldirqstate, hwpend;

	/* Don't let the compiler re-order this code with preceding code */
	__insn_barrier();

	set_curcpl(ipl);

	hwpend = footbridge_ipending & ICU_INT_HWMASK & ~footbridge_imask[ipl];
	if (hwpend != 0) {
		oldirqstate = disable_interrupts(I32_bit);
		intr_enabled |= hwpend;
		footbridge_set_intrmask();
		restore_interrupts(oldirqstate);
	}

#ifdef __HAVE_FAST_SOFTINTS
	cpu_dosoftints();
#endif
}

static inline int __attribute__((__unused__))
footbridge_splraise(int ipl)
{
	int	old;

	old = curcpl();
	set_curcpl(ipl);

	/* Don't let the compiler re-order this code with subsequent code */
	__insn_barrier();

	return (old);
}

static inline int __attribute__((__unused__))
footbridge_spllower(int ipl)
{
	int old = curcpl();

	footbridge_splx(ipl);
	return(old);
}

/* should only be defined in footbridge_intr.c */
#if !defined(ARM_SPL_NOINLINE)

#define splx(newspl)		footbridge_splx(newspl)
#define	_spllower(ipl)		footbridge_spllower(ipl)
#define	_splraise(ipl)		footbridge_splraise(ipl)

#else

int	_splraise(int);
int	_spllower(int);
void	splx(int);

#endif /* ! ARM_SPL_NOINLINE */

#include <sys/evcnt.h>
#include <sys/queue.h>
#include <machine/irqhandler.h>

#define	splsoft()	_splraise(IPL_SOFT)

#define	spl0()		(void)_spllower(IPL_NONE)
#define	spllowersoftclock() (void)_spllower(IPL_SOFTCLOCK)


static inline ipl_cookie_t
makeiplcookie(ipl_t ipl)
{

	return (ipl_cookie_t){._ipl = ipl};
}

static inline int
splraiseipl(ipl_cookie_t icookie)
{

	return _splraise(icookie._ipl);
}

#include <sys/spl.h>

/* footbridge has 32 interrupt lines */
#define	NIRQ		32

struct intrhand {
	TAILQ_ENTRY(intrhand) ih_list;	/* link on intrq list */
	int (*ih_func)(void *);		/* handler */
	void *ih_arg;			/* arg for handler */
	int ih_ipl;			/* IPL_* */
	int ih_irq;			/* IRQ number */
};

#define	IRQNAMESIZE	sizeof("footbridge irq 31")

struct intrq {
	TAILQ_HEAD(, intrhand) iq_list;	/* handler list */
	struct evcnt iq_ev;		/* event counter */
	int iq_mask;			/* IRQs to mask while handling */
	int iq_levels;			/* IPL_*'s this IRQ has */
	int iq_ist;			/* share type */
	int iq_ipl;			/* max ipl */
	char iq_name[IRQNAMESIZE];	/* interrupt name */
};

#endif /* _LOCORE */

#endif	/* _FOOTBRIDGE_INTR_H */