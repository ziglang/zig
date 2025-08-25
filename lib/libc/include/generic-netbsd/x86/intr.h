/*	$NetBSD: intr.h,v 1.66 2022/09/07 00:40:18 knakahara Exp $	*/

/*-
 * Copyright (c) 1998, 2001, 2006, 2007, 2008, 2019 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Charles M. Hannum, and by Jason R. Thorpe.
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

#ifndef _X86_INTR_H_
#define _X86_INTR_H_

#define	__HAVE_FAST_SOFTINTS
#if !defined(NO_PREEMPTION)
#define	__HAVE_PREEMPTION
#endif /* !defined(NO_PREEMPTION) */

#ifdef _KERNEL
#include <sys/types.h>
#include <sys/kcpuset.h>
#else
#include <stdbool.h>
#endif

#include <sys/evcnt.h>
#include <sys/queue.h>
#include <machine/intrdefs.h>

#ifdef XEN
#include <xen/include/public/xen.h>
#include <xen/include/public/event_channel.h>
#endif /* XEN */

#ifndef _LOCORE
#include <machine/pic.h>

/*
 * Struct describing an interrupt source for a CPU. struct cpu_info
 * has an array of MAX_INTR_SOURCES of these. The index in the array
 * is equal to the stub number of the stubcode as present in vector.s
 *
 * The primary CPU's array of interrupt sources has its first 16
 * entries reserved for legacy ISA irq handlers. This means that
 * they have a 1:1 mapping for arrayindex:irq_num. This is not
 * true for interrupts that come in through IO APICs, to find
 * their source, go through ci->ci_isources[index].is_pic
 *
 * It's possible to always maintain a 1:1 mapping, but that means
 * limiting the total number of interrupt sources to MAX_INTR_SOURCES
 * (32), instead of 32 per CPU. It also would mean that having multiple
 * IO APICs which deliver interrupts from an equal pin number would
 * overlap if they were to be sent to the same CPU.
 */

struct intrstub {
	void *ist_entry;
	void *ist_recurse;
	void *ist_resume;
};

struct percpu_evcnt {
	cpuid_t cpuid;
	uint64_t count;
};

struct intrsource {
	int is_maxlevel;		/* max. IPL for this source */
	int is_pin;			/* IRQ for legacy; pin for IO APIC,
					   -1 for MSI */
	struct intrhand *is_handlers;	/* handler chain */
	struct pic *is_pic;		/* originating PIC */
	void *is_recurse;		/* entry for spllower */
	void *is_resume;		/* entry for doreti */
	lwp_t *is_lwp;			/* for soft interrupts */
#if defined(XEN)
	u_long ipl_evt_mask1;	/* pending events for this IPL */
	u_long ipl_evt_mask2[NR_EVENT_CHANNELS];
#endif
	struct evcnt is_evcnt;		/* interrupt counter per cpu */
	/*
	 * is_mask_count requires special handling; it can only be modified
	 * or examined on the CPU that owns the interrupt source, and such
	 * references need to be protected by disabling interrupts.  This
	 * is because intr_mask() can be called from an interrupt handler.
	 * is_distribute_pending does not require such special handling
	 * because intr_unmask() cannot be called from an interrupt handler.
	 */
	u_int is_mask_count;		/* masked? (nested) [see above] */
	int is_distribute_pending;	/* ci<->ci move pending [cpu_lock] */
	int is_flags;			/* see below */
	int is_type;			/* level, edge */
	int is_idtvec;
	int is_minlevel;
	char is_evname[32];		/* event counter name */
	char is_intrid[INTRIDBUF];	/* intrid created by create_intrid() */
	char is_xname[INTRDEVNAMEBUF];	/* device names */
	cpuid_t is_active_cpu;		/* active cpuid */
	struct percpu_evcnt *is_saved_evcnt;	/* interrupt count of deactivated cpus */
	SIMPLEQ_ENTRY(intrsource) is_list;	/* link of intrsources */
};

#define IS_LEGACY	0x0001		/* legacy ISA irq source */
#define IS_IPI		0x0002
#define IS_LOG		0x0004

/*
 * Interrupt handler chains.  *_intr_establish() insert a handler into
 * the list.  The handler is called with its (single) argument.
 */

struct intrhand {
	struct pic *ih_pic;
	int	(*ih_fun)(void *);
	void	*ih_arg;
	int	ih_level;
	int	(*ih_realfun)(void *);
	void	*ih_realarg;
	struct	intrhand *ih_next;
	struct	intrhand **ih_prevp;
	int	ih_pin;
	int	ih_slot;
#if defined(XEN)
	int	ih_pending;
	struct	intrhand *ih_evt_next;
#endif
	struct cpu_info *ih_cpu;
	char	ih_xname[INTRDEVNAMEBUF];
};

#ifdef _KERNEL

void Xspllower(int);
void spllower(int);
int splraise(int);
void softintr(int);

/*
 * Convert spl level to local APIC level
 */

#define APIC_LEVEL(l)   ((l) << 4)

/*
 * Miscellaneous
 */

#define SPL_ASSERT_BELOW(x) KDASSERT(curcpu()->ci_ilevel < (x))
#define	spl0()		spllower(IPL_NONE)
#define	splx(x)		spllower(x)

typedef uint8_t ipl_t;
typedef struct {
	ipl_t _ipl;
} ipl_cookie_t;

static inline ipl_cookie_t
makeiplcookie(ipl_t ipl)
{

	return (ipl_cookie_t){._ipl = ipl};
}

static inline int
splraiseipl(ipl_cookie_t icookie)
{

	return splraise(icookie._ipl);
}

#include <sys/spl.h>

/*
 * Stub declarations.
 */

void Xsoftintr(void);
void Xrecurse_preempt(void);
void Xresume_preempt(void);

extern struct intrstub legacy_stubs[];
extern struct intrstub ioapic_edge_stubs[];
extern struct intrstub ioapic_level_stubs[];
extern struct intrstub x2apic_edge_stubs[];
extern struct intrstub x2apic_level_stubs[];

struct cpu_info;

struct pcibus_attach_args;

typedef uint64_t intr_handle_t;

void intr_default_setup(void);
void x86_nmi(void);
void *intr_establish_xname(int, struct pic *, int, int, int, int (*)(void *),
			   void *, bool, const char *);
void *intr_establish(int, struct pic *, int, int, int, int (*)(void *), void *, bool);
void intr_mask(struct intrhand *);
void intr_unmask(struct intrhand *);
void intr_disestablish(struct intrhand *);
void intr_add_pcibus(struct pcibus_attach_args *);
const char *intr_string(intr_handle_t, char *, size_t);
void cpu_intr_init(struct cpu_info *);
int intr_find_mpmapping(int, int, intr_handle_t *);
struct pic *intr_findpic(int);
void intr_printconfig(void);

const char *intr_create_intrid(int, struct pic *, int, char *, size_t);
struct intrsource *intr_allocate_io_intrsource(const char *);
void intr_free_io_intrsource(const char *);

void x86_init_preempt(struct cpu_info *);
void x86_intr_calculatemasks(struct cpu_info *);

int x86_send_ipi(struct cpu_info *, int);
void x86_broadcast_ipi(int);
void x86_ipi_handler(void);

void x86_intr_get_devname(const char *, char *, size_t);
void x86_intr_get_assigned(const char *, kcpuset_t *);
uint64_t x86_intr_get_count(const char *, u_int);

#ifndef XENPV
extern void (* const ipifunc[X86_NIPI])(struct cpu_info *);
#endif

#endif /* _KERNEL */

#endif /* !_LOCORE */

#endif /* !_X86_INTR_H_ */