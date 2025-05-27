/*	$NetBSD: rwlock.h,v 1.17.2.1 2023/08/09 17:42:01 martin Exp $	*/

/*-
 * Copyright (c) 2002, 2006, 2007, 2008, 2019, 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe and Andrew Doran.
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

#ifndef _SYS_RWLOCK_H_
#define	_SYS_RWLOCK_H_

/*
 * The rwlock provides exclusive access when held as a "writer",
 * and shared access when held as a "reader".
 *
 * Architectures may optionally provide stubs for the following functions to
 * implement the easy (unlocked, no waiters) cases.  If these stubs are
 * provided, __HAVE_RW_STUBS should be defined.
 *
 *	rw_enter()
 *	rw_exit()
 *	rw_tryenter()
 */

#if !defined(_KERNEL)
#include <sys/types.h>
#include <sys/inttypes.h>
#endif

typedef enum krw_t {
	RW_READER = 0,
	RW_WRITER = 1
} krw_t;

typedef struct krwlock krwlock_t;

#ifdef __RWLOCK_PRIVATE
#include <sys/stdbool.h>
/*
 * Bits in the owner field of the lock that indicate lock state.  If the
 * WRITE_LOCKED bit is clear, then the owner field is actually a count of
 * the number of readers.  The rw_owner field is laid out like so:
 *
 *  N                     5        4        3        2        1        0
 *  +------------------------------------------------------------------+
 *  | owner or read count | nodbug | <free> | wrlock | wrwant |  wait  |
 *  +------------------------------------------------------------------+
 */
#define	RW_HAS_WAITERS		0x01UL	/* lock has waiters */
#define	RW_WRITE_WANTED		0x02UL	/* >= 1 waiter is a writer */
#define	RW_WRITE_LOCKED		0x04UL	/* lock is currently write locked */
#define	RW_NODEBUG		0x10UL	/* LOCKDEBUG disabled */

#define	RW_READ_COUNT_SHIFT	5
#define	RW_READ_INCR		(1UL << RW_READ_COUNT_SHIFT)
#define	RW_THREAD		((uintptr_t)-RW_READ_INCR)
#define	RW_OWNER(rw)		((rw)->rw_owner & RW_THREAD)
#define	RW_COUNT(rw)		((rw)->rw_owner & RW_THREAD)
#define	RW_FLAGS(rw)		((rw)->rw_owner & ~RW_THREAD)

void	rw_vector_enter(krwlock_t *, const krw_t);
void	rw_vector_exit(krwlock_t *);
int	rw_vector_tryenter(krwlock_t *, const krw_t);
bool	rw_owner_running(const krwlock_t *);
#endif	/* __RWLOCK_PRIVATE */

struct krwlock {
	volatile uintptr_t	rw_owner;
};

#ifdef _KERNEL

void	_rw_init(krwlock_t *, uintptr_t);
void	rw_init(krwlock_t *);
void	rw_destroy(krwlock_t *);

int	rw_tryenter(krwlock_t *, const krw_t);
int	rw_tryupgrade(krwlock_t *);
void	rw_downgrade(krwlock_t *);

int	rw_read_held(krwlock_t *);
int	rw_write_held(krwlock_t *);
int	rw_lock_held(krwlock_t *);
krw_t	rw_lock_op(krwlock_t *);

void	rw_enter(krwlock_t *, const krw_t);
void	rw_exit(krwlock_t *);

void	rw_obj_init(void);
krwlock_t *rw_obj_alloc(void);
void	rw_obj_hold(krwlock_t *);
bool	rw_obj_free(krwlock_t *);
u_int	rw_obj_refcnt(krwlock_t *);
krwlock_t *rw_obj_tryalloc(void);

#endif	/* _KERNEL */

#endif /* _SYS_RWLOCK_H_ */