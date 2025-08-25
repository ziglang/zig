/*	$NetBSD: wordexp.h,v 1.2 2008/04/01 19:23:28 drochner Exp $	*/

/*-
 * Copyright (c) 2002 Tim J. Robbins.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD: /repoman/r/ncvs/src/include/wordexp.h,v 1.4 2003/01/03 12:03:38 tjr Exp $
 */

#ifndef _WORDEXP_H_
#define	_WORDEXP_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <machine/ansi.h>

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif


typedef struct {
	size_t	we_wordc;		/* count of words matched */
	char		**we_wordv;	/* pointer to list of words */
	size_t	we_offs;		/* slots to reserve in we_wordv */
					/* following are internals */
	char		*we_strings;	/* storage for wordv strings */
	size_t	we_nbytes;		/* size of we_strings */
} wordexp_t;

/*
 * Flags for wordexp().
 */
#define	WRDE_APPEND	0x1		/* append to previously generated */
#define	WRDE_DOOFFS	0x2		/* we_offs member is valid */
#define	WRDE_NOCMD	0x4		/* disallow command substitution */
#define	WRDE_REUSE	0x8		/* reuse wordexp_t */
#define	WRDE_SHOWERR	0x10		/* don't redirect stderr to /dev/null */
#define	WRDE_UNDEF	0x20		/* disallow undefined shell vars */

/*
 * Return values from wordexp().
 */
#define	WRDE_BADCHAR	1		/* unquoted special character */
#define	WRDE_BADVAL	2		/* undefined variable */
#define	WRDE_CMDSUB	3		/* command substitution not allowed */
#define	WRDE_NOSPACE	4		/* no memory for result */
#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
#define	WRDE_NOSYS	5		/* obsolete, reserved */
#endif
#define	WRDE_SYNTAX	6		/* shell syntax error */
#define WRDE_ERRNO	7		/* other errors see errno */

__BEGIN_DECLS
int	wordexp(const char * __restrict, wordexp_t * __restrict, int);
void	wordfree(wordexp_t *);
__END_DECLS

#endif /* !_WORDEXP_H_ */