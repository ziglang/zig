/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1995, 1997 Apple Computer, Inc. All Rights Reserved */
/*-
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)param.h	8.3 (Berkeley) 4/4/95
 */

#ifndef _SYS_PARAM_H_
#define _SYS_PARAM_H_

#define BSD     199506          /* System version (year & month). */
#define BSD4_3  1
#define BSD4_4  1

#define NeXTBSD 1995064         /* NeXTBSD version (year, month, release) */
#define NeXTBSD4_0 0            /* NeXTBSD 4.0 */

#include <sys/_types.h>
#include <sys/_types/_null.h>

#ifndef LOCORE
#include <sys/types.h>
#endif

/*
 * Machine-independent constants (some used in following include files).
 * Redefined constants are from POSIX 1003.1 limits file.
 *
 * MAXCOMLEN should be >= sizeof(ac_comm) (see <acct.h>)
 * MAXLOGNAME should be >= UT_NAMESIZE (see <utmp.h>)
 */
#include <sys/syslimits.h>

#define MAXCOMLEN       16              /* max command name remembered */
#define MAXINTERP       64              /* max interpreter file name length */
#define MAXLOGNAME      255             /* max login name length */
#define MAXUPRC         CHILD_MAX       /* max simultaneous processes */
#define NCARGS          ARG_MAX         /* max bytes for an exec function */
#define NGROUPS         NGROUPS_MAX     /* max number groups */
#define NOFILE          256             /* default max open files per process */
#define NOGROUP         65535           /* marker for empty group set member */
#define MAXHOSTNAMELEN  256             /* max hostname size */
#define MAXDOMNAMELEN   256             /* maximum domain name length */

/* Machine type dependent parameters. */
#include <machine/param.h>

/* More types and definitions used throughout the kernel. */
#include <limits.h>

/* Signals. */
#include <sys/signal.h>

/*
 * Priorities.  Note that with 32 run queues, differences less than 4 are
 * insignificant.
 */
#define PSWP    0
#define PVM     4
#define PINOD   8
#define PRIBIO  16
#define PVFS    20
#define PZERO   22              /* No longer magic, shouldn't be here.  XXX */
#define PSOCK   24
#define PWAIT   32
#define PLOCK   36
#define PPAUSE  40
#define PUSER   50
#define MAXPRI  127             /* Priorities range from 0 through MAXPRI. */

#define PRIMASK 0x0ff
#define PCATCH  0x100           /* OR'd with pri for tsleep to check signals */
#define PTTYBLOCK 0x200         /* for tty SIGTTOU and SIGTTIN blocking */
#define PDROP   0x400           /* OR'd with pri to stop re-aquistion of mutex upon wakeup */
#define PSPIN   0x800           /* OR'd with pri to require mutex in spin mode upon wakeup */

#define NBPW    sizeof(int)     /* number of bytes per word (integer) */

#define CMASK   022             /* default file mask: S_IWGRP|S_IWOTH */
#define NODEV   (dev_t)(-1)     /* non-existent device */

/*
 * Clustering of hardware pages on machines with ridiculously small
 * page sizes is done here.  The paging subsystem deals with units of
 * CLSIZE pte's describing NBPG (from machine/param.h) pages each.
 */
#define CLBYTES         (CLSIZE*NBPG)
#define CLOFSET         (CLSIZE*NBPG-1) /* for clusters, like PGOFSET */
#define claligned(x)    ((((int)(x))&CLOFSET)==0)
#define CLOFF           CLOFSET
#define CLSHIFT         (PGSHIFT+CLSIZELOG2)

#if CLSIZE == 1
#define clbase(i)       (i)
#define clrnd(i)        (i)
#else
/* Give the base virtual address (first of CLSIZE). */
#define clbase(i)       ((i) &~ (CLSIZE-1))
/* Round a number of clicks up to a whole cluster. */
#define clrnd(i)        (((i) + (CLSIZE-1)) &~ (CLSIZE-1))
#endif

#define CBLOCK  64              /* Clist block size, must be a power of 2. */
#define CBQSIZE (CBLOCK/NBBY)   /* Quote bytes/cblock - can do better. */
                                /* Data chars/clist. */
#define CBSIZE  (CBLOCK - sizeof(struct cblock *) - CBQSIZE)
#define CROUND  (CBLOCK - 1)    /* Clist rounding. */

/*
 * File system parameters and macros.
 *
 * The file system is made out of blocks of at most MAXPHYS units, with
 * smaller units (fragments) only in the last direct block.  MAXBSIZE
 * primarily determines the size of buffers in the buffer pool.  It may be
 * made larger than MAXPHYS without any effect on existing file systems;
 * however making it smaller may make some file systems unmountable.
 * We set this to track the value of MAX_UPL_TRANSFER_BYTES from
 * osfmk/mach/memory_object_types.h to bound it at the maximum UPL size.
 */
#define MAXBSIZE        (256 * 4096)
#define MAXPHYSIO       MAXPHYS
#define MAXFRAG         8

#define MAXPHYSIO_WIRED (16 * 1024 * 1024)

/*
 * MAXPATHLEN defines the longest permissable path length after expanding
 * symbolic links. It is used to allocate a temporary buffer from the buffer
 * pool in which to do the name expansion, hence should be a power of two,
 * and must be less than or equal to MAXBSIZE.  MAXSYMLINKS defines the
 * maximum number of symbolic links that may be expanded in a path name.
 * It should be set high enough to allow all legitimate uses, but halt
 * infinite loops reasonably quickly.
 */
#define MAXPATHLEN      PATH_MAX
#define MAXSYMLINKS     32

/* Bit map related macros. */
#define setbit(a, i)     (((char *)(a))[(i)/NBBY] |= 1<<((i)%NBBY))
#define clrbit(a, i)     (((char *)(a))[(i)/NBBY] &= ~(1<<((i)%NBBY)))
#define isset(a, i)      (((char *)(a))[(i)/NBBY] & (1<<((i)%NBBY)))
#define isclr(a, i)      ((((char *)(a))[(i)/NBBY] & (1<<((i)%NBBY))) == 0)

/* Macros for counting and rounding. */
#ifndef howmany
#define howmany(x, y)   ((((x) % (y)) == 0) ? ((x) / (y)) : (((x) / (y)) + 1))
#endif
#define roundup(x, y)   ((((x) % (y)) == 0) ? \
	                (x) : ((x) + ((y) - ((x) % (y)))))
#define powerof2(x)     ((((x)-1)&(x))==0)

/* Macros for min/max. */
#ifndef MIN
#define MIN(a, b) (((a)<(b))?(a):(b))
#endif /* MIN */
#ifndef MAX
#define MAX(a, b) (((a)>(b))?(a):(b))
#endif  /* MAX */

/*
 * Constants for setting the parameters of the kernel memory allocator.
 *
 * 2 ** MINBUCKET is the smallest unit of memory that will be
 * allocated. It must be at least large enough to hold a pointer.
 *
 * Units of memory less or equal to MAXALLOCSAVE will permanently
 * allocate physical memory; requests for these size pieces of
 * memory are quite fast. Allocations greater than MAXALLOCSAVE must
 * always allocate and free physical memory; requests for these
 * size allocations should be done infrequently as they will be slow.
 *
 * Constraints: CLBYTES <= MAXALLOCSAVE <= 2 ** (MINBUCKET + 14), and
 * MAXALLOCSIZE must be a power of two.
 */
#define MINBUCKET       4               /* 4 => min allocation of 16 bytes */
#define MAXALLOCSAVE    (2 * CLBYTES)

/*
 * Scale factor for scaled integers used to count %cpu time and load avgs.
 *
 * The number of CPU `tick's that map to a unique `%age' can be expressed
 * by the formula (1 / (2 ^ (FSHIFT - 11))).  The maximum load average that
 * can be calculated (assuming 32 bits) can be closely approximated using
 * the formula (2 ^ (2 * (16 - FSHIFT))) for (FSHIFT < 15).
 *
 * For the scheduler to maintain a 1:1 mapping of CPU `tick' to `%age',
 * FSHIFT must be at least 11; this gives us a maximum load avg of ~1024.
 */
#define FSHIFT  11              /* bits to right of fixed binary point */
#define FSCALE  (1<<FSHIFT)

#endif  /* _SYS_PARAM_H_ */
