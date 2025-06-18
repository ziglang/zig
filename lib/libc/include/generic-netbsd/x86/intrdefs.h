/*	$NetBSD: intrdefs.h,v 1.26 2022/09/07 00:40:18 knakahara Exp $	*/

#ifndef _X86_INTRDEFS_H_
#define _X86_INTRDEFS_H_

/* Interrupt priority levels. */
#define	IPL_NONE	0x0	/* nothing */
#define	IPL_PREEMPT	0x1	/* fake, to prevent recursive preemptions */
#define	IPL_SOFTCLOCK	0x2	/* timeouts */
#define	IPL_SOFTBIO	0x3	/* block I/O passdown */
#define	IPL_SOFTNET	0x4	/* protocol stacks */
#define	IPL_SOFTSERIAL	0x5	/* serial passdown */
#define	IPL_VM		0x6	/* low I/O, memory allocation */
#define IPL_SCHED	0x7	/* medium I/O, scheduler, clock */
#define	IPL_HIGH	0x8	/* high I/O, statclock, IPIs */
#define	NIPL		9

/* Interrupt sharing types. */
#define	IST_NONE	0	/* none */
#define	IST_PULSE	1	/* pulsed */
#define	IST_EDGE	2	/* edge-triggered */
#define	IST_LEVEL	3	/* level-triggered */

/*
 * Local APIC masks and software interrupt masks, in order
 * of priority.  Must not conflict with SIR_* below.
 */
#define LIR_IPI		55
#define LIR_TIMER	54

/*
 * XXX These should be lowest numbered, but right now would
 * conflict with the legacy IRQs.  Their current position
 * means that soft interrupt take priority over hardware
 * interrupts when lowering the priority level!
 */
#define	SIR_SERIAL	29
#define	SIR_NET		28
#define	SIR_BIO		27
#define	SIR_CLOCK	26
#define	SIR_PREEMPT	25
#define	LIR_HV		24
#define	SIR_XENIPL_HIGH 23
#define	SIR_XENIPL_SCHED 22
#define	SIR_XENIPL_VM	21

#define XEN_IPL2SIR(ipl) ((ipl) + (SIR_XENIPL_VM - IPL_VM))

/*
 * Maximum # of interrupt sources per CPU. Bitmask must still fit in one quad.
 * ioapics can theoretically produce more, but it's not likely to
 * happen. For multiple ioapics, things can be routed to different
 * CPUs.
 */
#define MAX_INTR_SOURCES	56
#define NUM_LEGACY_IRQS		16

/*
 * Low and high boundaries between which interrupt gates will
 * be allocated in the IDT.
 */
#define IDT_INTR_LOW	(0x20 + NUM_LEGACY_IRQS)
#define IDT_INTR_HIGH	0xef

#ifndef XENPV

#define X86_IPI_HALT			0x00000001
#define X86_IPI_AST			0x00000002
#define X86_IPI_GENERIC			0x00000004
#define X86_IPI_SYNCH_FPU		0x00000008
#define X86_IPI_MTRR			0x00000010
#define X86_IPI_GDT			0x00000020
#define X86_IPI_XCALL			0x00000040
#define X86_IPI_ACPI_CPU_SLEEP		0x00000080
#define X86_IPI_KPREEMPT		0x00000100

#define X86_NIPI		9

#define X86_IPI_NAMES { "halt IPI", "AST IPI", "generic IPI", \
			 "FPU synch IPI", "MTRR update IPI", \
			 "GDT update IPI", "xcall IPI", \
			 "ACPI CPU sleep IPI", "kpreempt IPI" }
#endif /* XENPV */

#define IREENT_MAGIC	0x18041969

#endif /* _X86_INTRDEFS_H_ */