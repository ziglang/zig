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

#ifndef _SYS_UMTXVAR_H_
#define	_SYS_UMTXVAR_H_

#ifdef _KERNEL

#include <sys/_timespec.h>

/*
 * The umtx_key structure is used by both the Linux futex code and the
 * umtx implementation to map userland addresses to unique keys.
 */
enum {
	TYPE_SIMPLE_WAIT,
	TYPE_CV,
	TYPE_SEM,
	TYPE_SIMPLE_LOCK,
	TYPE_NORMAL_UMUTEX,
	TYPE_PI_UMUTEX,
	TYPE_PP_UMUTEX,
	TYPE_RWLOCK,
	TYPE_FUTEX,
	TYPE_SHM,
	TYPE_PI_ROBUST_UMUTEX,
	TYPE_PP_ROBUST_UMUTEX,
	TYPE_PI_FUTEX,
};

/* Key to represent a unique userland synchronous object */
struct umtx_key {
	int	hash;
	int	type;
	int	shared;
	union {
		struct {
			struct vm_object *object;
			uintptr_t	offset;
		} shared;
		struct {
			struct vmspace	*vs;
			uintptr_t	addr;
		} private;
		struct {
			void		*a;
			uintptr_t	b;
		} both;
	} info;
};

#define THREAD_SHARE		0
#define PROCESS_SHARE		1
#define AUTO_SHARE		2

struct umtx_abs_timeout {
	int clockid;
	bool is_abs_real;	/* TIMER_ABSTIME && CLOCK_REALTIME* */
	struct timespec cur;
	struct timespec end;
};

struct thread;

/* Priority inheritance mutex info. */
struct umtx_pi {
	/* Owner thread */
	struct thread		*pi_owner;

	/* Reference count */
	int			pi_refcount;

	/* List entry to link umtx holding by thread */
	TAILQ_ENTRY(umtx_pi)	pi_link;

	/* List entry in hash */
	TAILQ_ENTRY(umtx_pi)	pi_hashlink;

	/* List for waiters */
	TAILQ_HEAD(,umtx_q)	pi_blocked;

	/* Identify a userland lock object */
	struct umtx_key		pi_key;
};

/* A userland synchronous object user. */
struct umtx_q {
	/* Linked list for the hash. */
	TAILQ_ENTRY(umtx_q)	uq_link;

	/* Umtx key. */
	struct umtx_key		uq_key;

	/* Umtx flags. */
	int			uq_flags;
#define UQF_UMTXQ	0x0001

	/* Futex bitset mask */
	u_int			uq_bitset;

	/* The thread waits on. */
	struct thread		*uq_thread;

	/*
	 * Blocked on PI mutex. read can use chain lock
	 * or umtx_lock, write must have both chain lock and
	 * umtx_lock being hold.
	 */
	struct umtx_pi		*uq_pi_blocked;

	/* On blocked list */
	TAILQ_ENTRY(umtx_q)	uq_lockq;

	/* Thread contending with us */
	TAILQ_HEAD(,umtx_pi)	uq_pi_contested;

	/* Inherited priority from PP mutex */
	u_char			uq_inherited_pri;

	/* Spare queue ready to be reused */
	struct umtxq_queue	*uq_spare_queue;

	/* The queue we on */
	struct umtxq_queue	*uq_cur_queue;
};

TAILQ_HEAD(umtxq_head, umtx_q);

/* Per-key wait-queue */
struct umtxq_queue {
	struct umtxq_head	head;
	struct umtx_key		key;
	LIST_ENTRY(umtxq_queue)	link;
	int			length;
};

LIST_HEAD(umtxq_list, umtxq_queue);

/* Userland lock object's wait-queue chain */
struct umtxq_chain {
	/* Lock for this chain. */
	struct mtx		uc_lock;

	/* List of sleep queues. */
	struct umtxq_list	uc_queue[2];
#define UMTX_SHARED_QUEUE	0
#define UMTX_EXCLUSIVE_QUEUE	1

	LIST_HEAD(, umtxq_queue) uc_spare_queue;

	/* Busy flag */
	char			uc_busy;

	/* Chain lock waiters */
	int			uc_waiters;

	/* All PI in the list */
	TAILQ_HEAD(,umtx_pi)	uc_pi_list;

#ifdef UMTX_PROFILING
	u_int			length;
	u_int			max_length;
#endif
};

static inline int
umtx_key_match(const struct umtx_key *k1, const struct umtx_key *k2)
{

	return (k1->type == k2->type &&
	    k1->info.both.a == k2->info.both.a &&
	    k1->info.both.b == k2->info.both.b);
}

void umtx_abs_timeout_init(struct umtx_abs_timeout *, int, int,
    const struct timespec *);
int umtx_copyin_timeout(const void *, struct timespec *);
void umtx_exec(struct proc *p);
int umtx_key_get(const void *, int, int, struct umtx_key *);
void umtx_key_release(struct umtx_key *);
struct umtx_q *umtxq_alloc(void);
void umtxq_busy(struct umtx_key *);
int umtxq_count(struct umtx_key *);
void umtxq_free(struct umtx_q *);
struct umtxq_chain *umtxq_getchain(struct umtx_key *);
void umtxq_insert_queue(struct umtx_q *, int);
void umtxq_remove_queue(struct umtx_q *, int);
int umtxq_requeue(struct umtx_key *, int, struct umtx_key *, int);
int umtxq_signal_mask(struct umtx_key *, int, u_int);
int umtxq_sleep(struct umtx_q *, const char *,
    struct umtx_abs_timeout *);
int umtxq_sleep_pi(struct umtx_q *, struct umtx_pi *, uint32_t,
    const char *, struct umtx_abs_timeout *, bool);
void umtxq_unbusy(struct umtx_key *);
void umtxq_unbusy_unlocked(struct umtx_key *);
int kern_umtx_wake(struct thread *, void *, int, int);
void umtx_pi_adjust(struct thread *, u_char);
struct umtx_pi *umtx_pi_alloc(int);
int umtx_pi_claim(struct umtx_pi *, struct thread *);
int umtx_pi_drop(struct thread *, struct umtx_key *, bool, int *);
void umtx_pi_free(struct umtx_pi *);
void umtx_pi_insert(struct umtx_pi *);
struct umtx_pi *umtx_pi_lookup(struct umtx_key *);
void umtx_pi_ref(struct umtx_pi *);
void umtx_pi_unref(struct umtx_pi *);
void umtx_thread_init(struct thread *);
void umtx_thread_fini(struct thread *);
void umtx_thread_alloc(struct thread *);
void umtx_thread_exit(struct thread *);

#define umtxq_insert(uq)	umtxq_insert_queue((uq), UMTX_SHARED_QUEUE)
#define umtxq_remove(uq)	umtxq_remove_queue((uq), UMTX_SHARED_QUEUE)

/*
 * Lock a chain.
 *
 * The code is a macro so that file/line information is taken from the caller.
 */
#define umtxq_lock(key) do {		\
	struct umtx_key *_key = (key);	\
	struct umtxq_chain *_uc;	\
					\
	_uc = umtxq_getchain(_key);	\
	mtx_lock(&_uc->uc_lock);	\
} while (0)

/*
 * Unlock a chain.
 */
static inline void
umtxq_unlock(struct umtx_key *key)
{
	struct umtxq_chain *uc;

	uc = umtxq_getchain(key);
	mtx_unlock(&uc->uc_lock);
}

#endif /* _KERNEL */
#endif /* !_SYS_UMTXVAR_H_ */