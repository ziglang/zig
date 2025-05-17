/*	$NetBSD: kcore.h,v 1.7 2020/04/25 15:26:17 bouyer Exp $	*/

/*
 * Copyright (c) 1996 Carnegie-Mellon University.
 * All rights reserved.
 *
 * Author: Chris G. Demetriou
 *
 * Permission to use, copy, modify and distribute this software and
 * its documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND
 * FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie the
 * rights to redistribute these changes.
 */

/*
 * Modified for NetBSD/i386 by Jason R. Thorpe, Numerical Aerospace
 * Simulation Facility, NASA Ames Research Center.
 */

#ifndef _I386_KCORE_H_
#define _I386_KCORE_H_

typedef struct cpu_kcore_hdr {
	uint32_t	pdppaddr;		/* PA of PDP */
	uint32_t	nmemsegs;		/* Number of RAM segments */
#if 0
	phys_ram_seg_t  memsegs[];		/* RAM segments */
#endif
} cpu_kcore_hdr_t;

/*
 * Used to indicate that PAE should be used for virtual address
 * translation. As PDPpaddr is expected to be PAGE_SIZE aligned,
 * this can be safely OR'ed in pdppaddr.
 * To avoid any kind of conflict with existing MMU bits, we chose one
 * ignored by hardware
 */
#define I386_KCORE_PAE	PTE_AVL1

#ifdef _KERNEL
void	dumpsys(void);

extern struct pcb dumppcb;
extern int	sparse_dump;
#endif

#endif /* _I386_KCORE_H_ */