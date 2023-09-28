/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Guido van Rossum.
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
 *	@(#)glob.h	8.1 (Berkeley) 6/2/93
 * $FreeBSD: /repoman/r/ncvs/src/include/glob.h,v 1.7 2002/07/17 04:58:09 mikeh Exp $
 */

#ifndef _GLOB_H_
#define	_GLOB_H_

#include <_types.h>
#include <sys/cdefs.h>
#include <Availability.h>
#include <sys/_types/_size_t.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
struct dirent;
struct stat;
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
typedef struct {
	size_t gl_pathc;	/* Count of total paths so far. */
	int gl_matchc;		/* Count of paths matching pattern. */
	size_t gl_offs;		/* Reserved at beginning of gl_pathv. */
	int gl_flags;		/* Copy of flags parameter to glob. */
	char **gl_pathv;	/* List of paths matching pattern. */
				/* Copy of errfunc parameter to glob. */
#ifdef __BLOCKS__
	union {
#endif /* __BLOCKS__ */
		int (*gl_errfunc)(const char *, int);
#ifdef __BLOCKS__
		int (^gl_errblk)(const char *, int);
	};
#endif /* __BLOCKS__ */

	/*
	 * Alternate filesystem access methods for glob; replacement
	 * versions of closedir(3), readdir(3), opendir(3), stat(2)
	 * and lstat(2).
	 */
	void (*gl_closedir)(void *);
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
	struct dirent *(*gl_readdir)(void *);
#else /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
	void *(*gl_readdir)(void *);
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
	void *(*gl_opendir)(const char *);
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
	int (*gl_lstat)(const char *, struct stat *);
	int (*gl_stat)(const char *, struct stat *);
#else /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
	int (*gl_lstat)(const char *, void *);
	int (*gl_stat)(const char *, void *);
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
} glob_t;

/* Believed to have been introduced in 1003.2-1992 */
#define	GLOB_APPEND	0x0001	/* Append to output from previous call. */
#define	GLOB_DOOFFS	0x0002	/* Use gl_offs. */
#define	GLOB_ERR	0x0004	/* Return on error. */
#define	GLOB_MARK	0x0008	/* Append / to matching directories. */
#define	GLOB_NOCHECK	0x0010	/* Return pattern itself if nothing matches. */
#define	GLOB_NOSORT	0x0020	/* Don't sort. */
#define	GLOB_NOESCAPE	0x2000	/* Disable backslash escaping. */

/* Error values returned by glob(3) */
#define	GLOB_NOSPACE	(-1)	/* Malloc call failed. */
#define	GLOB_ABORTED	(-2)	/* Unignored error. */
#define	GLOB_NOMATCH	(-3)	/* No match and GLOB_NOCHECK was not set. */
#define	GLOB_NOSYS	(-4)	/* Obsolete: source comptability only. */

#define	GLOB_ALTDIRFUNC	0x0040	/* Use alternately specified directory funcs. */
#define	GLOB_BRACE	0x0080	/* Expand braces ala csh. */
#define	GLOB_MAGCHAR	0x0100	/* Pattern had globbing characters. */
#define	GLOB_NOMAGIC	0x0200	/* GLOB_NOCHECK without magic chars (csh). */
#define	GLOB_QUOTE	0x0400	/* Quote special chars with \. */
#define	GLOB_TILDE	0x0800	/* Expand tilde names from the passwd file. */
#define	GLOB_LIMIT	0x1000	/* limit number of returned paths */
#ifdef __BLOCKS__
#define	_GLOB_ERR_BLOCK	0x80000000 /* (internal) error callback is a block */
#endif /* __BLOCKS__ */

/* source compatibility, these are the old names */
#define GLOB_MAXPATH	GLOB_LIMIT
#define	GLOB_ABEND	GLOB_ABORTED

__BEGIN_DECLS
int	glob(const char * __restrict, int, int (*)(const char *, int), 
	     glob_t * __restrict) __DARWIN_INODE64(glob);
#ifdef __BLOCKS__
#if __has_attribute(noescape)
#define __glob_noescape __attribute__((__noescape__))
#else
#define __glob_noescape
#endif
int	glob_b(const char * __restrict, int, int (^)(const char *, int) __glob_noescape,
	     glob_t * __restrict) __DARWIN_INODE64(glob_b) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */
void	globfree(glob_t *);
__END_DECLS

#endif /* !_GLOB_H_ */
