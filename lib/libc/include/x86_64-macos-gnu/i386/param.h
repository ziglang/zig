/*
 * Copyright (c) 2000-2010 Apple Inc. All rights reserved.
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
/*-
 * Copyright (c) 1990, 1993
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
 *	@(#)param.h	8.1 (Berkeley) 4/4/95
 */

/*
 * Machine dependent constants for Intel 386.
 */

#ifndef _I386_PARAM_H_
#define _I386_PARAM_H_

#include <i386/_param.h>

/*
 * Round p (pointer or byte index) up to a correctly-aligned value for all
 * data types (int, long, ...).   The result is unsigned int and must be
 * cast to any desired pointer type.
 */
#define ALIGNBYTES      __DARWIN_ALIGNBYTES
#define ALIGN(p)        __DARWIN_ALIGN(p)

#define NBPG            4096            /* bytes/page */
#define PGOFSET         (NBPG-1)        /* byte offset into page */
#define PGSHIFT         12              /* LOG2(NBPG) */

#define DEV_BSIZE       512
#define DEV_BSHIFT      9               /* log2(DEV_BSIZE) */
#define BLKDEV_IOSIZE   2048
#define MAXPHYS         (128 * 1024)    /* max raw I/O transfer size */

#define CLSIZE          1
#define CLSIZELOG2      0

/*
 * Constants related to network buffer management.
 * MCLBYTES must be no larger than CLBYTES (the software page size), and,
 * on machines that exchange pages of input or output buffers with mbuf
 * clusters (MAPPED_MBUFS), MCLBYTES must also be an integral multiple
 * of the hardware page size.
 */
#define MSIZESHIFT      8                       /* 256 */
#define MSIZE           (1 << MSIZESHIFT)       /* size of an mbuf */
#define MCLSHIFT        11                      /* 2048 */
#define MCLBYTES        (1 << MCLSHIFT)         /* size of an mbuf cluster */
#define MBIGCLSHIFT     12                      /* 4096 */
#define MBIGCLBYTES     (1 << MBIGCLSHIFT)      /* size of a big cluster */
#define M16KCLSHIFT     14                      /* 16384 */
#define M16KCLBYTES     (1 << M16KCLSHIFT)      /* size of a jumbo cluster */

#define MCLOFSET        (MCLBYTES - 1)
#ifndef NMBCLUSTERS
#define NMBCLUSTERS     ((1024 * 1024) / MCLBYTES)      /* cl map size: 1MB */
#endif

/*
 * Some macros for units conversion
 */
/* Core clicks (NeXT_page_size bytes) to segments and vice versa */
#define ctos(x) (x)
#define stoc(x) (x)

/* Core clicks (4096 bytes) to disk blocks */
#define ctod(x) ((x)<<(PGSHIFT-DEV_BSHIFT))
#define dtoc(x) ((x)>>(PGSHIFT-DEV_BSHIFT))
#define dtob(x) ((x)<<DEV_BSHIFT)

/* clicks to bytes */
#define ctob(x) ((x)<<PGSHIFT)

/* bytes to clicks */
#define btoc(x) (((unsigned)(x)+(NBPG-1))>>PGSHIFT)

#ifdef __APPLE__
#define  btodb(bytes, devBlockSize)         \
	((unsigned)(bytes) / devBlockSize)
#define  dbtob(db, devBlockSize)            \
	((unsigned)(db) * devBlockSize)
#else
#define btodb(bytes)                    /* calculates (bytes / DEV_BSIZE) */ \
	((unsigned)(bytes) >> DEV_BSHIFT)
#define dbtob(db)                       /* calculates (db * DEV_BSIZE) */ \
	((unsigned)(db) << DEV_BSHIFT)
#endif

/*
 * Map a ``block device block'' to a file system block.
 * This should be device dependent, and will be if we
 * add an entry to cdevsw/bdevsw for that purpose.
 * For now though just use DEV_BSIZE.
 */
#define bdbtofsb(bn)    ((bn) / (BLKDEV_IOSIZE/DEV_BSIZE))

/*
 * Macros to decode (and encode) processor status word.
 */
#define STATUS_WORD(rpl, ipl)   (((ipl) << 8) | (rpl))
#define USERMODE(x)             (((x) & 3) == 3)
#define BASEPRI(x)              (((x) & (255 << 8)) == 0)


#if     defined(KERNEL) || defined(STANDALONE)
#define DELAY(n) delay(n)

#else   /* defined(KERNEL) || defined(STANDALONE) */
#define DELAY(n)        { int N = (n); while (--N > 0); }
#endif  /* defined(KERNEL) || defined(STANDALONE) */

#endif /* _I386_PARAM_H_ */
