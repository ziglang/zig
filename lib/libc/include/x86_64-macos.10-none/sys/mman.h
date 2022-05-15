/*
 * Copyright (c) 2000-2019 Apple Computer, Inc. All rights reserved.
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
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*-
 * Copyright (c) 1982, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)mman.h	8.1 (Berkeley) 6/2/93
 */

/*
 * Currently unsupported:
 *
 * [TYM]	POSIX_TYPED_MEM_ALLOCATE
 * [TYM]	POSIX_TYPED_MEM_ALLOCATE_CONTIG
 * [TYM]	POSIX_TYPED_MEM_MAP_ALLOCATABLE
 * [TYM]	struct posix_typed_mem_info
 * [TYM]	posix_mem_offset()
 * [TYM]	posix_typed_mem_get_info()
 * [TYM]	posix_typed_mem_open()
 */

#ifndef _SYS_MMAN_H_
#define _SYS_MMAN_H_

#include <sys/appleapiopts.h>
#include <sys/cdefs.h>

#include <sys/_types.h>

/*
 * [various] The mode_t, off_t, and size_t types shall be defined as
 * described in <sys/types.h>
 */
#include <sys/_types/_mode_t.h>
#include <sys/_types/_off_t.h>
#include <sys/_types/_size_t.h>

/*
 * Protections are chosen from these bits, or-ed together
 */
#define PROT_NONE       0x00    /* [MC2] no permissions */
#define PROT_READ       0x01    /* [MC2] pages can be read */
#define PROT_WRITE      0x02    /* [MC2] pages can be written */
#define PROT_EXEC       0x04    /* [MC2] pages can be executed */

/*
 * Flags contain sharing type and options.
 * Sharing types; choose one.
 */
#define MAP_SHARED      0x0001          /* [MF|SHM] share changes */
#define MAP_PRIVATE     0x0002          /* [MF|SHM] changes are private */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define MAP_COPY        MAP_PRIVATE     /* Obsolete */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Other flags
 */
#define MAP_FIXED        0x0010 /* [MF|SHM] interpret addr exactly */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define MAP_RENAME       0x0020 /* Sun: rename private pages to file */
#define MAP_NORESERVE    0x0040 /* Sun: don't reserve needed swap area */
#define MAP_RESERVED0080 0x0080 /* previously unimplemented MAP_INHERIT */
#define MAP_NOEXTEND     0x0100 /* for MAP_FILE, don't change file size */
#define MAP_HASSEMAPHORE 0x0200 /* region may contain semaphores */
#define MAP_NOCACHE      0x0400 /* don't cache pages for this mapping */
#define MAP_JIT          0x0800 /* Allocate a region that will be used for JIT purposes */

/*
 * Mapping type
 */
#define MAP_FILE        0x0000  /* map from file (default) */
#define MAP_ANON        0x1000  /* allocated from memory, swap space */
#define MAP_ANONYMOUS   MAP_ANON

/*
 * The MAP_RESILIENT_* flags can be used when the caller wants to map some
 * possibly unreliable memory and be able to access it safely, possibly
 * getting the wrong contents rather than raising any exception.
 * For safety reasons, such mappings have to be read-only (PROT_READ access
 * only).
 *
 * MAP_RESILIENT_CODESIGN:
 *      accessing this mapping will not generate code-signing violations,
 *	even if the contents are tainted.
 * MAP_RESILIENT_MEDIA:
 *	accessing this mapping will not generate an exception if the contents
 *	are not available (unreachable removable or remote media, access beyond
 *	end-of-file, ...).  Missing contents will be replaced with zeroes.
 */
#define MAP_RESILIENT_CODESIGN  0x2000 /* no code-signing failures */
#define MAP_RESILIENT_MEDIA     0x4000 /* no backing-store failures */

#if !defined(CONFIG_EMBEDDED)
#define MAP_32BIT       0x8000          /* Return virtual addresses <4G only: Requires entitlement */
#endif  /* !defined(CONFIG_EMBEDDED) */

#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Process memory locking
 */
#define MCL_CURRENT     0x0001  /* [ML] Lock only current memory */
#define MCL_FUTURE      0x0002  /* [ML] Lock all future memory as well */

/*
 * Error return from mmap()
 */
#define MAP_FAILED      ((void *)-1)    /* [MF|SHM] mmap failed */

/*
 * msync() flags
 */
#define MS_ASYNC        0x0001  /* [MF|SIO] return immediately */
#define MS_INVALIDATE   0x0002  /* [MF|SIO] invalidate all cached data */
#define MS_SYNC         0x0010  /* [MF|SIO] msync synchronously */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define MS_KILLPAGES    0x0004  /* invalidate pages, leave mapped */
#define MS_DEACTIVATE   0x0008  /* deactivate pages, leave mapped */

#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */


/*
 * Advice to madvise
 */
#define POSIX_MADV_NORMAL       0       /* [MC1] no further special treatment */
#define POSIX_MADV_RANDOM       1       /* [MC1] expect random page refs */
#define POSIX_MADV_SEQUENTIAL   2       /* [MC1] expect sequential page refs */
#define POSIX_MADV_WILLNEED     3       /* [MC1] will need these pages */
#define POSIX_MADV_DONTNEED     4       /* [MC1] dont need these pages */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define MADV_NORMAL             POSIX_MADV_NORMAL
#define MADV_RANDOM             POSIX_MADV_RANDOM
#define MADV_SEQUENTIAL         POSIX_MADV_SEQUENTIAL
#define MADV_WILLNEED           POSIX_MADV_WILLNEED
#define MADV_DONTNEED           POSIX_MADV_DONTNEED
#define MADV_FREE               5       /* pages unneeded, discard contents */
#define MADV_ZERO_WIRED_PAGES   6       /* zero the wired pages that have not been unwired before the entry is deleted */
#define MADV_FREE_REUSABLE      7       /* pages can be reused (by anyone) */
#define MADV_FREE_REUSE         8       /* caller wants to reuse those pages */
#define MADV_CAN_REUSE          9
#define MADV_PAGEOUT            10      /* page out now (internal only) */

/*
 * Return bits from mincore
 */
#define MINCORE_INCORE           0x1     /* Page is incore */
#define MINCORE_REFERENCED       0x2     /* Page has been referenced by us */
#define MINCORE_MODIFIED         0x4     /* Page has been modified by us */
#define MINCORE_REFERENCED_OTHER 0x8     /* Page has been referenced */
#define MINCORE_MODIFIED_OTHER  0x10     /* Page has been modified */
#define MINCORE_PAGED_OUT       0x20     /* Page has been paged out */
#define MINCORE_COPIED          0x40     /* Page has been copied */
#define MINCORE_ANONYMOUS       0x80     /* Page belongs to an anonymous object */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */



__BEGIN_DECLS
/* [ML] */
int     mlockall(int);
int     munlockall(void);
/* [MR] */
int     mlock(const void *, size_t);
#ifndef _MMAP
#define _MMAP
/* [MC3]*/
void *  mmap(void *, size_t, int, int, int, off_t) __DARWIN_ALIAS(mmap);
#endif
/* [MPR] */
int     mprotect(void *, size_t, int) __DARWIN_ALIAS(mprotect);
/* [MF|SIO] */
int     msync(void *, size_t, int) __DARWIN_ALIAS_C(msync);
/* [MR] */
int     munlock(const void *, size_t);
/* [MC3]*/
int     munmap(void *, size_t) __DARWIN_ALIAS(munmap);
/* [SHM] */
int     shm_open(const char *, int, ...);
int     shm_unlink(const char *);
/* [ADV] */
int     posix_madvise(void *, size_t, int);

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
int     madvise(void *, size_t, int);
int     mincore(const void *, size_t, char *);
int     minherit(void *, size_t, int);
#endif


__END_DECLS

#endif /* !_SYS_MMAN_H_ */