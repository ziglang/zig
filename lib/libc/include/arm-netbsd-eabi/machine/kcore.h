/*	$NetBSD: kcore.h,v 1.1 2008/01/01 14:06:43 chris Exp $	*/

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

#ifndef _ARM_KCORE_H_
#define _ARM_KCORE_H_

typedef struct cpu_kcore_hdr {
	uint32_t	version;		/* structure version */
	uint32_t	flags;			/* flags */
#define	KCORE_ARM_APX        0x0001		/* L1 tables are in APX
						   format */
	uint32_t	PAKernelL1Table;	/* PA of kernel L1 table */
	uint32_t	PAUserL1Table;		/* PA of userland L1 table */
	uint16_t	UserL1TableSize;	/* size of User L1 table */
	uint32_t	nmemsegs;		/* Number of RAM segments */
	uint32_t	omemsegs;		/* offset to memsegs */

	/*
	 * future versions will add fields here.
	 */
#if 0
	phys_ram_seg_t  memsegs[];		/* RAM segments */
#endif
} cpu_kcore_hdr_t;

#endif /* _ARM_KCORE_H_ */