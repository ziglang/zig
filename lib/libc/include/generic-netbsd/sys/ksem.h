/*	$NetBSD: ksem.h,v 1.15.30.1 2023/08/09 17:42:01 martin Exp $	*/

/*
 * Copyright (c) 2002 Alfred Perlstein <alfred@FreeBSD.org>
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
 */

#ifndef _SYS_KSEM_H_
#define _SYS_KSEM_H_

#include <sys/cdefs.h>

#include <sys/types.h>

struct timespec;

#ifdef _KERNEL

#include <sys/condvar.h>
#include <sys/mutex.h>
#include <sys/queue.h>

#ifndef _KMEMUSER		/* XXX hack for fstat(8) */
#include <sys/systm.h>
#endif

struct lwp;
struct proc;

#define	KSEM_MAX	128

typedef struct ksem {
	LIST_ENTRY(ksem)	ks_entry;	/* global list entry */
	struct proc *		ks_pshared_proc;/* owner of pshared sem */
	intptr_t		ks_pshared_id;	/* global id for pshared sem */
	kmutex_t		ks_lock;	/* lock on this ksem */
	kcondvar_t		ks_cv;		/* condition variable */
	u_int			ks_pshared_fd;	/* fd in owning proc */
	u_int			ks_ref;		/* number of references */
	u_int			ks_value;	/* current value */
	u_int			ks_waiters;	/* number of waiters */
	char *			ks_name;	/* name, if named */
	size_t			ks_namelen;	/* length of name */
	int			ks_flags;	/* for KS_UNLINKED */
	mode_t			ks_mode;	/* protection bits */
	uid_t			ks_uid;		/* creator uid */
	gid_t			ks_gid;		/* creator gid */
} ksem_t;

int do_ksem_init(struct lwp *, unsigned int, intptr_t *, copyin_t, copyout_t);
int do_ksem_open(struct lwp *, const char *, int, mode_t, unsigned int,
    intptr_t *, copyout_t);
int do_ksem_wait(struct lwp *, intptr_t, bool, struct timespec *);

extern int	ksem_max;
#endif /* _KERNEL */

#if defined(_KERNEL) || defined(_LIBC)
#define	KSEM_PSHARED		0x50535244U	/* 'PSRD' */

#define	KSEM_MARKER_MASK	0xff000001U
#define	KSEM_MARKER_MIN		0x01000001U
#define	KSEM_PSHARED_MARKER	0x70000001U	/* 'p' << 24 | 1 */
#endif /* _KERNEL || _LIBC */

#ifdef _LIBC
__BEGIN_DECLS
int _ksem_close(intptr_t);
int _ksem_destroy(intptr_t);
int _ksem_getvalue(intptr_t, int *);
int _ksem_init(unsigned int, intptr_t *);
int _ksem_open(const char *, int, mode_t, unsigned int, intptr_t *);
int _ksem_post(intptr_t);
int _ksem_timedwait(intptr_t, const struct timespec * __restrict);
int _ksem_trywait(intptr_t);
int _ksem_unlink(const char *);
int _ksem_wait(intptr_t);
__END_DECLS
#endif /* _LIBC */

#endif /* _SYS_KSEM_H_ */