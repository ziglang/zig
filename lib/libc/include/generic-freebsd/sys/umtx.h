/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2002, Jeffrey Roberson <jeff@freebsd.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef _SYS_UMTX_H_
#define	_SYS_UMTX_H_

#include <sys/_umtx.h>

#define	UMTX_UNOWNED		0x0
#define	UMTX_CONTESTED		LONG_MIN

/* Common lock flags */
#define USYNC_PROCESS_SHARED	0x0001	/* Process shared sync objs */

/* umutex flags */
#define	UMUTEX_PRIO_INHERIT	0x0004	/* Priority inherited mutex */
#define	UMUTEX_PRIO_PROTECT	0x0008	/* Priority protect mutex */
#define	UMUTEX_ROBUST		0x0010	/* Robust mutex */
#define	UMUTEX_NONCONSISTENT	0x0020	/* Robust locked but not consistent */

/*
 * The umutex.m_lock values and bits.  The m_owner is the word which
 * serves as the lock.  Its high bit is the contention indicator and
 * rest of bits records the owner TID.  TIDs values start with PID_MAX
 * + 2 and end by INT32_MAX.  The low range [1..PID_MAX] is guaranteed
 * to be useable as the special markers.
 */
#define	UMUTEX_UNOWNED		0x0
#define	UMUTEX_CONTESTED	0x80000000U
#define	UMUTEX_RB_OWNERDEAD	(UMUTEX_CONTESTED | 0x10)
#define	UMUTEX_RB_NOTRECOV	(UMUTEX_CONTESTED | 0x11)

/* urwlock flags */
#define URWLOCK_PREFER_READER	0x0002

#define URWLOCK_WRITE_OWNER	0x80000000U
#define URWLOCK_WRITE_WAITERS	0x40000000U
#define URWLOCK_READ_WAITERS	0x20000000U
#define URWLOCK_MAX_READERS	0x1fffffffU
#define URWLOCK_READER_COUNT(c)	((c) & URWLOCK_MAX_READERS)

/* _usem flags */
#define SEM_NAMED	0x0002

/* _usem2 count field */
#define	USEM_HAS_WAITERS	0x80000000U
#define	USEM_MAX_COUNT		0x7fffffffU
#define	USEM_COUNT(c)		((c) & USEM_MAX_COUNT)

/* op code for _umtx_op */
#define	UMTX_OP_LOCK		0	/* COMPAT10 */
#define	UMTX_OP_UNLOCK		1	/* COMPAT10 */
#define	UMTX_OP_WAIT		2
#define	UMTX_OP_WAKE		3
#define	UMTX_OP_MUTEX_TRYLOCK	4
#define	UMTX_OP_MUTEX_LOCK	5
#define	UMTX_OP_MUTEX_UNLOCK	6
#define	UMTX_OP_SET_CEILING	7
#define	UMTX_OP_CV_WAIT		8
#define	UMTX_OP_CV_SIGNAL	9
#define	UMTX_OP_CV_BROADCAST	10
#define	UMTX_OP_WAIT_UINT	11
#define	UMTX_OP_RW_RDLOCK	12
#define	UMTX_OP_RW_WRLOCK	13
#define	UMTX_OP_RW_UNLOCK	14
#define	UMTX_OP_WAIT_UINT_PRIVATE	15
#define	UMTX_OP_WAKE_PRIVATE	16
#define	UMTX_OP_MUTEX_WAIT	17
#define	UMTX_OP_MUTEX_WAKE	18	/* deprecated */
#define	UMTX_OP_SEM_WAIT	19	/* deprecated */
#define	UMTX_OP_SEM_WAKE	20	/* deprecated */
#define	UMTX_OP_NWAKE_PRIVATE   21
#define	UMTX_OP_MUTEX_WAKE2	22
#define	UMTX_OP_SEM2_WAIT	23
#define	UMTX_OP_SEM2_WAKE	24
#define	UMTX_OP_SHM		25
#define	UMTX_OP_ROBUST_LISTS	26
#define	UMTX_OP_GET_MIN_TIMEOUT	27
#define	UMTX_OP_SET_MIN_TIMEOUT	28

/*
 * Flags for ops; the double-underbar convention must be maintained for future
 * additions for the sake of libsysdecode.
 */
#define	UMTX_OP__I386		0x40000000
#define	UMTX_OP__32BIT		0x80000000

/* Flags for UMTX_OP_CV_WAIT */
#define	CVWAIT_CHECK_UNPARKING	0x01
#define	CVWAIT_ABSTIME		0x02
#define	CVWAIT_CLOCKID		0x04

#define	UMTX_ABSTIME		0x01

#define	UMTX_CHECK_UNPARKING	CVWAIT_CHECK_UNPARKING

/* Flags for UMTX_OP_SHM */
#define	UMTX_SHM_CREAT		0x0001
#define	UMTX_SHM_LOOKUP		0x0002
#define	UMTX_SHM_DESTROY	0x0004
#define	UMTX_SHM_ALIVE		0x0008

struct umtx_robust_lists_params {
	uintptr_t	robust_list_offset;
	uintptr_t	robust_priv_list_offset;
	uintptr_t	robust_inact_offset;
};

__BEGIN_DECLS

int _umtx_op(void *obj, int op, u_long val, void *uaddr, void *uaddr2);

__END_DECLS

#endif /* !_SYS_UMTX_H_ */