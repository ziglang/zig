/*
 * Copyright (c) 2000, 2011 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 2001-2009 Ville Laurikari <vl@iki.fi>
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 * 
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/*-
 * Copyright (c) 1992 Henry Spencer.
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Henry Spencer of the University of Toronto.
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
 *	@(#)regex.h	8.2 (Berkeley) 1/3/94
 */

#ifndef _REGEX_H_
#define	_REGEX_H_

#include <_regex.h>

/*******************/
/* regcomp() flags */
/*******************/
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define	REG_BASIC	0000	/* Basic regular expressions (synonym for 0) */
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

#define	REG_EXTENDED	0001	/* Extended regular expressions */
#define	REG_ICASE	0002	/* Compile ignoring upper/lower case */
#define	REG_NOSUB	0004	/* Compile only reporting success/failure */
#define	REG_NEWLINE	0010	/* Compile for newline-sensitive matching */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define	REG_NOSPEC	0020	/* Compile turning off all special characters */

#if __MAC_OS_X_VERSION_MIN_REQUIRED  >= __MAC_10_8 \
 || __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_6_0 \
 || defined(__DRIVERKIT_VERSION_MIN_REQUIRED)
#define	REG_LITERAL	REG_NOSPEC
#endif

#define	REG_PEND	0040	/* Use re_endp as end pointer */

#if __MAC_OS_X_VERSION_MIN_REQUIRED  >= __MAC_10_8 \
 || __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_6_0 \
 || defined(__DRIVERKIT_VERSION_MIN_REQUIRED)
#define	REG_MINIMAL	0100	/* Compile using minimal repetition */
#define	REG_UNGREEDY	REG_MINIMAL
#endif

#define	REG_DUMP	0200	/* Unused */

#if __MAC_OS_X_VERSION_MIN_REQUIRED  >= __MAC_10_8 \
 || __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_6_0 \
 || defined(__DRIVERKIT_VERSION_MIN_REQUIRED)
#define	REG_ENHANCED	0400	/* Additional (non-POSIX) features */
#endif
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

/********************/
/* regerror() flags */
/********************/
#define	REG_ENOSYS	 (-1)	/* Reserved */
#define	REG_NOMATCH	 1	/* regexec() function failed to match */
#define	REG_BADPAT	 2	/* invalid regular expression */
#define	REG_ECOLLATE	 3	/* invalid collating element */
#define	REG_ECTYPE	 4	/* invalid character class */
#define	REG_EESCAPE	 5	/* trailing backslash (\) */
#define	REG_ESUBREG	 6	/* invalid backreference number */
#define	REG_EBRACK	 7	/* brackets ([ ]) not balanced */
#define	REG_EPAREN	 8	/* parentheses not balanced */
#define	REG_EBRACE	 9	/* braces not balanced */
#define	REG_BADBR	10	/* invalid repetition count(s) */
#define	REG_ERANGE	11	/* invalid character range */
#define	REG_ESPACE	12	/* out of memory */
#define	REG_BADRPT	13	/* repetition-operator operand invalid */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define	REG_EMPTY	14	/* Unused */
#define	REG_ASSERT	15	/* Unused */
#define	REG_INVARG	16	/* invalid argument to regex routine */
#define	REG_ILLSEQ	17	/* illegal byte sequence */

#define	REG_ATOI	255	/* convert name to number (!) */
#define	REG_ITOA	0400	/* convert number to name (!) */
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

/*******************/
/* regexec() flags */
/*******************/
#define	REG_NOTBOL	00001	/* First character not at beginning of line */
#define	REG_NOTEOL	00002	/* Last character not at end of line */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define	REG_STARTEND	00004	/* String start/end in pmatch[0] */
#define	REG_TRACE	00400	/* Unused */
#define	REG_LARGE	01000	/* Unused */
#define	REG_BACKR	02000	/* force use of backref code */

#if __MAC_OS_X_VERSION_MIN_REQUIRED  >= __MAC_10_8 \
 || __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_6_0 \
 || defined(__DRIVERKIT_VERSION_MIN_REQUIRED)
#define	REG_BACKTRACKING_MATCHER	REG_BACKR
#endif
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

__BEGIN_DECLS
int	regcomp(regex_t * __restrict, const char * __restrict, int) __DARWIN_ALIAS(regcomp);
size_t	regerror(int, const regex_t * __restrict, char * __restrict, size_t) __cold;
/*
 * gcc under c99 mode won't compile "[ __restrict]" by itself.  As a workaround,
 * a dummy argument name is added.
 */
int	regexec(const regex_t * __restrict, const char * __restrict, size_t,
	    regmatch_t __pmatch[ __restrict], int);
void	regfree(regex_t *);

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL

/* Darwin extensions */
int	regncomp(regex_t * __restrict, const char * __restrict, size_t, int)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int	regnexec(const regex_t * __restrict, const char * __restrict, size_t,
	    size_t, regmatch_t __pmatch[ __restrict], int)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int	regwcomp(regex_t * __restrict, const wchar_t * __restrict, int)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int	regwexec(const regex_t * __restrict, const wchar_t * __restrict, size_t,
	    regmatch_t __pmatch[ __restrict], int)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int	regwncomp(regex_t * __restrict, const wchar_t * __restrict, size_t, int)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int	regwnexec(const regex_t * __restrict, const wchar_t * __restrict,
	    size_t, size_t, regmatch_t __pmatch[ __restrict], int)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);

#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */
__END_DECLS

#ifdef _USE_EXTENDED_LOCALES_
#include <xlocale/_regex.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#endif /* !_REGEX_H_ */