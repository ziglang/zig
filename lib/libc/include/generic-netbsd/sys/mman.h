/*	$NetBSD: mman.h,v 1.62 2019/12/06 19:37:43 christos Exp $	*/

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
 * 3. Neither the name of the University nor the names of its contributors
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
 *	@(#)mman.h	8.2 (Berkeley) 1/9/95
 */

#ifndef _SYS_MMAN_H_
#define _SYS_MMAN_H_

#include <sys/featuretest.h>

#include <machine/ansi.h>

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif

#include <sys/ansi.h>

#ifndef	mode_t
typedef	__mode_t	mode_t;
#define	mode_t		__mode_t
#endif

#ifndef	off_t
typedef	__off_t		off_t;		/* file offset */
#define	off_t		__off_t
#endif


/*
 * Protections are chosen from these bits, or-ed together
 */
#define	PROT_NONE	0x00	/* no permissions */
#define	PROT_READ	0x01	/* pages can be read */
#define	PROT_WRITE	0x02	/* pages can be written */
#define	PROT_EXEC	0x04	/* pages can be executed */

#ifdef _NETBSD_SOURCE
/*
 * PAX mprotect prohibits setting protection bits
 * missing from the original mmap call unless explicitly
 * requested with PROT_MPROTECT.
 */
#define        PROT_MPROTECT(x)                ((x) << 3)
#define        PROT_MPROTECT_EXTRACT(x)        (((x) >> 3) & 0x7)
#endif

/*
 * Flags contain sharing type and options.
 * Sharing types; choose one.
 */
#define	MAP_SHARED	0x0001	/* share changes */
#define	MAP_PRIVATE	0x0002	/* changes are private */
	/* old MAP_COPY	0x0004	   "copy" region at mmap time */

/*
 * Other flags
 */
#define	MAP_REMAPDUP	 0x0004	/* mremap only: duplicate the mapping */
#define	MAP_FIXED	 0x0010	/* map addr must be exactly as requested */
#define	MAP_RENAME	 0x0020	/* Sun: rename private pages to file */
#define	MAP_NORESERVE	 0x0040	/* Sun: don't reserve needed swap area */
#define	MAP_INHERIT	 0x0080	/* region is retained after exec */
#define	MAP_HASSEMAPHORE 0x0200	/* region may contain semaphores */
#define	MAP_TRYFIXED     0x0400 /* attempt hint address, even within break */
#define	MAP_WIRED	 0x0800	/* mlock() mapping when it is established */

/*
 * Mapping type
 */
#define	MAP_FILE	0x0000	/* map from file (default) */
#define	MAP_ANONYMOUS	0x1000	/* allocated from memory, swap space */
#define	MAP_ANON	MAP_ANONYMOUS
#define	MAP_STACK	0x2000	/* allocated from memory, swap space (stack) */

/*
 * Alignment (expressed in log2).  Must be >= log2(PAGE_SIZE) and
 * < # bits in a pointer (32 or 64).
 */
#define	MAP_ALIGNED(n)	((int)((unsigned int)(n) << MAP_ALIGNMENT_SHIFT))
#define	MAP_ALIGNMENT_SHIFT	24
#define	MAP_ALIGNMENT_MASK	MAP_ALIGNED(0xff)
#define	MAP_ALIGNMENT_64KB	MAP_ALIGNED(16)	/* 2^16 */
#define	MAP_ALIGNMENT_16MB	MAP_ALIGNED(24)	/* 2^24 */
#define	MAP_ALIGNMENT_4GB	MAP_ALIGNED(32)	/* 2^32 */
#define	MAP_ALIGNMENT_1TB	MAP_ALIGNED(40)	/* 2^40 */
#define	MAP_ALIGNMENT_256TB	MAP_ALIGNED(48)	/* 2^48 */
#define	MAP_ALIGNMENT_64PB	MAP_ALIGNED(56)	/* 2^56 */

#ifdef _NETBSD_SOURCE
#define MAP_FMT	"\177\020"			\
	"b\0"  "SHARED\0"			\
	"b\1"  "PRIVATE\0"			\
	"b\2"  "COPY\0"				\
	"b\4"  "FIXED\0"			\
	"b\5"  "RENAME\0"			\
	"b\6"  "NORESERVE\0"			\
	"b\7"  "INHERIT\0"			\
	"b\11" "HASSEMAPHORE\0"			\
	"b\12" "TRYFIXED\0"			\
	"b\13" "WIRED\0"			\
	"F\14\1\0"				\
		":\0" "FILE\0"			\
		":\1" "ANONYMOUS\0"		\
	"b\15" "STACK\0"			\
	"F\30\010\0"				\
		":\000" "ALIGN=NONE\0"		\
		":\012" "ALIGN=1KB\0"		\
		":\013" "ALIGN=2KB\0"		\
		":\014" "ALIGN=4KB\0"		\
		":\015" "ALIGN=8KB\0"		\
		":\016" "ALIGN=16KB\0"		\
		":\017" "ALIGN=32KB\0"		\
		":\020" "ALIGN=64KB\0"		\
		":\021" "ALIGN=128KB\0"		\
		":\022" "ALIGN=256KB\0"		\
		":\023" "ALIGN=512KB\0"		\
		":\024" "ALIGN=1MB\0"		\
		":\025" "ALIGN=2MB\0"		\
		":\026" "ALIGN=4MB\0"		\
		":\027" "ALIGN=8MB\0"		\
		":\030" "ALIGN=16MB\0"		\
		":\034" "ALIGN=256MB\0"		\
		":\040" "ALIGN=4GB\0"		\
		":\044" "ALIGN=64GB\0"		\
		":\050" "ALIGN=1TB\0"		\
		":\054" "ALIGN=16TB\0"		\
		":\060" "ALIGN=256TB\0"		\
		":\064" "ALIGN=4PB\0"		\
		":\070" "ALIGN=64PB\0"		\
		":\074" "ALIGN=256PB\0"		\
		"*"	"ALIGN=2^%ju\0"
#endif

/*
 * Error indicator returned by mmap(2)
 */
#define	MAP_FAILED	((void *) -1)	/* mmap() failed */

/*
 * Flags to msync
 */
#define	MS_ASYNC	0x01	/* perform asynchronous writes */
#define	MS_INVALIDATE	0x02	/* invalidate cached data */
#define	MS_SYNC		0x04	/* perform synchronous writes */

/*
 * Flags to mlockall
 */
#define	MCL_CURRENT	0x01	/* lock all pages currently mapped */
#define	MCL_FUTURE	0x02	/* lock all pages mapped in the future */

/*
 * POSIX memory advisory values.
 * Note: keep consistent with the original definitions below.
 */
#define	POSIX_MADV_NORMAL	0	/* No further special treatment */
#define	POSIX_MADV_RANDOM	1	/* Expect random page references */
#define	POSIX_MADV_SEQUENTIAL	2	/* Expect sequential page references */
#define	POSIX_MADV_WILLNEED	3	/* Will need these pages */
#define	POSIX_MADV_DONTNEED	4	/* Don't need these pages */

#if defined(_NETBSD_SOURCE)
/*
 * Original advice values, equivalent to POSIX definitions,
 * and few implementation-specific ones.
 */
#define	MADV_NORMAL		POSIX_MADV_NORMAL
#define	MADV_RANDOM		POSIX_MADV_RANDOM
#define	MADV_SEQUENTIAL		POSIX_MADV_SEQUENTIAL
#define	MADV_WILLNEED		POSIX_MADV_WILLNEED
#define	MADV_DONTNEED		POSIX_MADV_DONTNEED
#define	MADV_SPACEAVAIL		5	/* Insure that resources are reserved */
#define	MADV_FREE		6	/* Pages are empty, free them */

/*
 * Flags to minherit
 */
#define	MAP_INHERIT_SHARE	0	/* share with child */
#define	MAP_INHERIT_COPY	1	/* copy into child */
#define	MAP_INHERIT_NONE	2	/* absent from child */
#define	MAP_INHERIT_DONATE_COPY	3	/* copy and delete -- not
					   implemented in UVM */
#define	MAP_INHERIT_ZERO	4	/* zero in child */
#define	MAP_INHERIT_DEFAULT	MAP_INHERIT_COPY
#endif

#ifndef _KERNEL

#include <sys/cdefs.h>

__BEGIN_DECLS
void *	mmap(void *, size_t, int, int, int, off_t);
int	munmap(void *, size_t);
int	mprotect(void *, size_t, int);
#ifndef __LIBC12_SOURCE__
int	msync(void *, size_t, int) __RENAME(__msync13);
#endif
int	mlock(const void *, size_t);
int	munlock(const void *, size_t);
int	mlockall(int);
int	munlockall(void);
#if defined(_NETBSD_SOURCE)
int	madvise(void *, size_t, int);
int	mincore(void *, size_t, char *);
int	minherit(void *, size_t, int);
void *	mremap(void *, size_t, void *, size_t, int);
#endif
int	posix_madvise(void *, size_t, int);
int	shm_open(const char *, int, mode_t);
int	shm_unlink(const char *);
__END_DECLS

#endif /* !_KERNEL */

#endif /* !_SYS_MMAN_H_ */