/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2025 The FreeBSD Foundation
 * All rights reserved.
 *
 * This software were developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
 */

#ifndef _SYS_EXTERRVAR_H_
#define	_SYS_EXTERRVAR_H_

#include <sys/_exterr.h>
#include <sys/_uexterror.h>
#include <sys/exterr_cat.h>

#define	UEXTERROR_MAXLEN	256

#define	UEXTERROR_VER		0x10010002

#define	EXTERRCTL_ENABLE	1
#define	EXTERRCTL_DISABLE	2
#define	EXTERRCTL_UD		3

#define	EXTERRCTLF_FORCE	0x00000001

#ifdef _KERNEL

#ifndef EXTERR_CATEGORY
#error "Specify error category before including sys/exterrvar.h"
#endif

#ifdef	EXTERR_STRINGS
#define	SET_ERROR_MSG(mmsg)	(mmsg)
#else
#define	SET_ERROR_MSG(mmsg)	NULL
#endif

#define	_SET_ERROR2(eerror, mmsg, pp1, pp2)				\
	exterr_set(eerror, EXTERR_CATEGORY, SET_ERROR_MSG(mmsg),	\
	    (uintptr_t)(pp1), (uintptr_t)(pp2), __LINE__)
#define	_SET_ERROR0(eerror, mmsg)	_SET_ERROR2(eerror, mmsg, 0, 0)
#define	_SET_ERROR1(eerror, mmsg, pp1)	_SET_ERROR2(eerror, mmsg, pp1, 0)

#define	_EXTERROR_MACRO(eerror, mmsg, _1, _2, NAME, ...)		\
	NAME
#define	EXTERROR(...)							\
	_EXTERROR_MACRO(__VA_ARGS__, _SET_ERROR2, _SET_ERROR1,		\
	    _SET_ERROR0)(__VA_ARGS__)

int exterr_set(int eerror, int category, const char *mmsg, uintptr_t pp1,
    uintptr_t pp2, int line);
int exterr_to_ue(struct thread *td, struct uexterror *ue);
void ktrexterr(struct thread *td);

#else	/* _KERNEL */

#include <sys/types.h>

__BEGIN_DECLS
int exterrctl(u_int op, u_int flags, void *ptr);
__END_DECLS

#endif	/* _KERNEL */

#endif