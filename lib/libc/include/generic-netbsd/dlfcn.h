/*	$NetBSD: dlfcn.h,v 1.25 2017/07/11 15:21:35 joerg Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Paul Kranenburg.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _DLFCN_H_
#define _DLFCN_H_

#include <sys/featuretest.h>
#include <sys/cdefs.h>
#include <machine/ansi.h>

#ifdef	_BSD_SSIZE_T_
typedef	_BSD_SSIZE_T_	ssize_t;
#undef	_BSD_SSIZE_T_
#endif

#if defined(_NETBSD_SOURCE)
typedef struct _dl_info {
	const char	*dli_fname;	/* File defining the symbol */
	void		*dli_fbase;	/* Base address */
	const char	*dli_sname;	/* Symbol name */
	const void	*dli_saddr;	/* Symbol address */
} Dl_info;
#endif /* defined(_NETBSD_SOURCE) */

/*
 * User interface to the run-time linker.
 */
__BEGIN_DECLS
void *_dlauxinfo(void) __pure;

void	*dlopen(const char *, int);
int	dlclose(void *);
void	*dlsym(void * __restrict, const char * __restrict);
#if defined(_NETBSD_SOURCE)
int	dladdr(const void * __restrict, Dl_info * __restrict);
int	dlctl(void *, int, void *);
int	dlinfo(void *, int, void *);
void	*dlvsym(void * __restrict, const char * __restrict,
	    const char * __restrict);
void	__dl_cxa_refcount(void *, ssize_t);
#endif
__aconst char *dlerror(void);
__END_DECLS

/* Values for dlopen `mode'. */
#define RTLD_LAZY	1
#define RTLD_NOW	2
#define RTLD_GLOBAL	0x100		/* Allow global searches in object */
#define RTLD_LOCAL	0x200
#define RTLD_NODELETE	0x01000		/* Do not remove members. */
#define RTLD_NOLOAD	0x02000		/* Do not load if not already loaded. */
#if defined(_NETBSD_SOURCE)
#define DL_LAZY		RTLD_LAZY	/* Compat */
#endif

/* 
 * Special handle arguments for dlsym().
 */   
#define	RTLD_NEXT	((void *) -1)	/* Search subsequent objects. */
#define	RTLD_DEFAULT	((void *) -2)	/* Use default search algorithm. */
#define	RTLD_SELF	((void *) -3)	/* Search the caller itself. */

/*
 * dlctl() commands
 */
#if defined(_NETBSD_SOURCE)
#define DL_GETERRNO	1
#define DL_GETSYMBOL	2
#if 0
#define DL_SETSRCHPATH	x
#define DL_GETLIST	x
#define DL_GETREFCNT	x
#define DL_GETLOADADDR	x
#endif /* 0 */
#endif /* defined(_NETBSD_SOURCE) */

/*
 * dlinfo() commands
 *
 * From Solaris: http://docs.sun.com/app/docs/doc/816-5168/dlinfo-3c?a=view
 */
#if defined(_NETBSD_SOURCE)
#define RTLD_DI_LINKMAP		3
#if 0
#define RTLD_DI_ARGSINFO	1
#define RTLD_DI_CONFIGADDR	2
#define RTLD_DI_LMID		4
#define RTLD_DI_SERINFO		5
#define RTLD_DI_SERINFOSIZE	6
#define RTLD_DI_ORIGIN		7
#define RTLD_DI_GETSIGNAL	8
#define RTLD_DI_SETSIGNAL	9
#endif
#endif /* _NETBSD_SOURCE */

#endif /* !defined(_DLFCN_H_) */