/*-
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <phk@FreeBSD.org> wrote this file.  As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return.   Poul-Henning Kamp
 * ----------------------------------------------------------------------------
 *
 */

#ifndef _MACHINE_SMP_H_
#define _MACHINE_SMP_H_

#ifdef _KERNEL

#ifdef SMP

#ifndef LOCORE

#include <x86/x86_smp.h>

/* global symbols in mpboot.S */
extern char			mptramp_start[];
extern u_int32_t		mptramp_pagetables;

/* IPI handlers */
inthand_t
	IDTVEC(justreturn),	/* interrupt CPU with minimum overhead */
	IDTVEC(justreturn1_pti),
	IDTVEC(invlop_pti),
	IDTVEC(invlop),
	IDTVEC(ipi_intr_bitmap_handler_pti),
	IDTVEC(ipi_swi_pti),
	IDTVEC(cpustop_pti),
	IDTVEC(cpususpend_pti),
	IDTVEC(rendezvous_pti);

void	invlop_handler(void);
int	start_all_aps(void);

#endif /* !LOCORE */
#endif /* SMP */

#endif /* _KERNEL */
#endif /* _MACHINE_SMP_H_ */