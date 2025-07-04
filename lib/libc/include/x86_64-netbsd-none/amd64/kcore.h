/*	$NetBSD: kcore.h,v 1.3 2013/06/25 15:08:43 joerg Exp $	*/

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
 *
 * And once again modified for x86-64 by Frank van der Linden of
 * Wasabi Systems, Inc.
 */

#ifndef _AMD64_KCORE_H_
#define _AMD64_KCORE_H_

typedef struct cpu_kcore_hdr {
	uint64_t	ptdpaddr;		/* PA of PML4 */
	uint64_t	nmemsegs;		/* Number of RAM segments */
#if 0
	phys_ram_seg_t  memsegs[];		/* RAM segments */
#endif
} cpu_kcore_hdr_t;

#endif /* _AMD64_KCORE_H_ */