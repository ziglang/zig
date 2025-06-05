/*	$NetBSD: swap.h,v 1.8 2009/01/14 02:20:45 mrg Exp $	*/

/*
 * Copyright (c) 1995, 1996, 1998, 2009 Matthew R. Green
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_SWAP_H_
#define _SYS_SWAP_H_

#include <sys/syslimits.h>

/* Thise structure is used to return swap information for userland */

struct swapent {
	dev_t	se_dev;			/* device id */
	int	se_flags;		/* flags */
	int	se_nblks;		/* total blocks */
	int	se_inuse;		/* blocks in use */
	int	se_priority;		/* priority of this device */
	char	se_path[PATH_MAX+1];	/* path name */
};

#define SWAP_ON		1		/* begin swapping on device */
#define SWAP_OFF	2		/* stop swapping on device */
#define SWAP_NSWAP	3		/* how many swap devices ? */
#define SWAP_STATS13	4		/* old SWAP_STATS, no se_path */
#define SWAP_CTL	5		/* change priority on device */
#define SWAP_STATS50	6		/* old SWAP_STATS, 32 bit dev_t */
#define SWAP_DUMPDEV	7		/* use this device as dump device */
#define SWAP_GETDUMPDEV	8		/* use this device as dump device */
#define SWAP_DUMPOFF	9		/* stop using the dump device */
#define SWAP_STATS	10		/* get device info */

#define SWF_INUSE	0x00000001	/* in use: we have swapped here */
#define SWF_ENABLE	0x00000002	/* enabled: we can swap here */
#define SWF_BUSY	0x00000004	/* busy: I/O happening here */
#define SWF_FAKE	0x00000008	/* fake: still being built */

#endif /* _SYS_SWAP_H_ */