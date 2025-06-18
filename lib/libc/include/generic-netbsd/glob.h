/*	$NetBSD: glob.h,v 1.27 2019/05/29 01:21:33 christos Exp $	*/

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
 */

#ifndef _GLOB_H_
#define	_GLOB_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifndef __gl_size_t
#define __gl_size_t	size_t
#endif
#ifndef __gl_stat_t
#define __gl_stat_t	struct stat
#endif

typedef struct {
	__gl_size_t gl_pathc;	/* Count of total paths so far. */
	__gl_size_t gl_matchc;	/* Count of paths matching pattern. */
	__gl_size_t gl_offs;	/* Reserved at beginning of gl_pathv. */
	int gl_flags;		/* Copy of flags parameter to glob. */
	char **gl_pathv;	/* List of paths matching pattern. */
				/* Copy of errfunc parameter to glob. */
	int (*gl_errfunc)(const char *, int);

	/*
	 * Alternate filesystem access methods for glob; replacement
	 * versions of closedir(3), readdir(3), opendir(3), stat(2)
	 * and lstat(2).
	 */
	void (*gl_closedir)(void *);
	struct dirent *(*gl_readdir)(void *);	
	void *(*gl_opendir)(const char *);
	int (*gl_lstat)(const char *, __gl_stat_t *);
	int (*gl_stat)(const char *, __gl_stat_t *);
} glob_t;

#define	GLOB_APPEND	 0x00001 /* Append to output from previous call. */
#define	GLOB_DOOFFS	 0x00002 /* Use gl_offs. */
#define	GLOB_ERR	 0x00004 /* Return on error. */
#define	GLOB_MARK	 0x00008 /* Append / to matching directories. */
#define	GLOB_NOCHECK	 0x00010 /* Return pattern itself if nothing matches. */
#define	GLOB_NOSORT	 0x00020 /* Don't sort. */
#define	GLOB_NOESCAPE	 0x01000 /* Disable backslash escaping. */

#define	GLOB_NOSPACE	 (-1)	 /* Malloc call failed. */
#define	GLOB_ABORTED	 (-2)	 /* Unignored error. */
#define	GLOB_NOMATCH	 (-3)	 /* No match, and GLOB_NOCHECK was not set. */
#define	GLOB_NOSYS	 (-4)	 /* Implementation does not support function. */

#if defined(_NETBSD_SOURCE) || defined(HAVE_NBTOOL_CONFIG_H)
#define	GLOB_ALTDIRFUNC	 0x00040 /* Use alternately specified directory funcs. */
#define	GLOB_BRACE	 0x00080 /* Expand braces ala csh. */
#define	GLOB_MAGCHAR	 0x00100 /* Pattern had globbing characters. */
#define	GLOB_NOMAGIC	 0x00200 /* GLOB_NOCHECK without magic chars (csh). */
#define	GLOB_LIMIT	 0x00400 /* Limit memory used by matches to ARG_MAX */
#define	GLOB_TILDE	 0x00800 /* Expand tilde names from the passwd file. */
/*	GLOB_NOESCAPE	 0x01000 above */
#define	GLOB_PERIOD	 0x02000 /* Allow metachars to match leading periods. */
#define	GLOB_NO_DOTDIRS	 0x04000 /* Make . and .. vanish from wildcards. */
#define	GLOB_STAR	 0x08000 /* Use glob ** to recurse directories */
#define	GLOB_TILDE_CHECK 0x10000 /* Expand tilde names from the passwd file. */
#define	GLOB_QUOTE	 0	 /* source compatibility */

#define	GLOB_ABEND	GLOB_ABORTED	/* source compatibility */
#endif

__BEGIN_DECLS
#ifndef __LIBC12_SOURCE__
int	glob(const char * __restrict, int,
    int (*)(const char *, int), glob_t * __restrict)	 __RENAME(__glob30);
void	globfree(glob_t *)				 __RENAME(__globfree30);
#endif
#ifdef _NETBSD_SOURCE
int	glob_pattern_p(const char *, int);
#endif
__END_DECLS

#endif /* !_GLOB_H_ */