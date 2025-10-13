/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2007-2009 Kip Macy <kmacy@freebsd.org>
 * All rights reserved.
 * Copyright (c) 2024 Arm Ltd
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
 */

#ifndef	_SYS_BUF_RING_H_
#define	_SYS_BUF_RING_H_

#include <sys/param.h>
#include <sys/kassert.h>
#include <machine/atomic.h>
#include <machine/cpu.h>

#if defined(DEBUG_BUFRING) && defined(_KERNEL)
#include <sys/lock.h>
#include <sys/mutex.h>
#endif

/*
 * We only apply the mask to the head and tail values when calculating the
 * index into br_ring to access. This means the upper bits can be used as
 * epoch to reduce the chance the atomic_cmpset succeedes when it should
 * fail, e.g. when the head wraps while the CPU is in an interrupt. This
 * is a probablistic fix as there is still a very unlikely chance the
 * value wraps back to the expected value.
 *
 */
struct buf_ring {
	volatile uint32_t	br_prod_head;
	volatile uint32_t	br_prod_tail;	
	int              	br_prod_size;
	int              	br_prod_mask;
	uint64_t		br_drops;
	volatile uint32_t	br_cons_head __aligned(CACHE_LINE_SIZE);
	volatile uint32_t	br_cons_tail;
	int		 	br_cons_size;
	int              	br_cons_mask;
#if defined(DEBUG_BUFRING) && defined(_KERNEL)
	struct mtx		*br_lock;
#endif	
	void			*br_ring[0] __aligned(CACHE_LINE_SIZE);
};

/*
 * multi-producer safe lock-free ring buffer enqueue
 *
 */
static __inline int
buf_ring_enqueue(struct buf_ring *br, void *buf)
{
	uint32_t prod_head, prod_next, prod_idx;
	uint32_t cons_tail, mask;

	mask = br->br_prod_mask;
#ifdef DEBUG_BUFRING
	/*
	 * Note: It is possible to encounter an mbuf that was removed
	 * via drbr_peek(), and then re-added via drbr_putback() and
	 * trigger a spurious panic.
	 */
	for (uint32_t i = br->br_cons_head; i != br->br_prod_head; i++)
		if (br->br_ring[i & mask] == buf)
			panic("buf=%p already enqueue at %d prod=%d cons=%d",
			    buf, i, br->br_prod_tail, br->br_cons_tail);
#endif	
	critical_enter();
	do {
		/*
		 * br->br_prod_head needs to be read before br->br_cons_tail.
		 * If not then we could perform the dequeue and enqueue
		 * between reading br_cons_tail and reading br_prod_head. This
		 * could give us values where br_cons_head == br_prod_tail
		 * (after masking).
		 *
		 * To work around this us a load acquire. This is just to
		 * ensure ordering within this thread.
		 */
		prod_head = atomic_load_acq_32(&br->br_prod_head);
		prod_next = prod_head + 1;
		cons_tail = atomic_load_acq_32(&br->br_cons_tail);

		if ((int32_t)(cons_tail + br->br_prod_size - prod_next) < 1) {
			rmb();
			if (prod_head == br->br_prod_head &&
			    cons_tail == br->br_cons_tail) {
				br->br_drops++;
				critical_exit();
				return (ENOBUFS);
			}
			continue;
		}
	} while (!atomic_cmpset_acq_32(&br->br_prod_head, prod_head, prod_next));
	prod_idx = prod_head & mask;
#ifdef DEBUG_BUFRING
	if (br->br_ring[prod_idx] != NULL)
		panic("dangling value in enqueue");
#endif	
	br->br_ring[prod_idx] = buf;

	/*
	 * If there are other enqueues in progress
	 * that preceded us, we need to wait for them
	 * to complete 
	 */   
	while (br->br_prod_tail != prod_head)
		cpu_spinwait();
	atomic_store_rel_32(&br->br_prod_tail, prod_next);
	critical_exit();
	return (0);
}

/*
 * multi-consumer safe dequeue 
 *
 */
static __inline void *
buf_ring_dequeue_mc(struct buf_ring *br)
{
	uint32_t cons_head, cons_next, cons_idx;
	uint32_t prod_tail, mask;
	void *buf;

	critical_enter();
	mask = br->br_cons_mask;
	do {
		/*
		 * As with buf_ring_enqueue ensure we read the head before
		 * the tail. If we read them in the wrong order we may
		 * think the bug_ring is full when it is empty.
		 */
		cons_head = atomic_load_acq_32(&br->br_cons_head);
		cons_next = cons_head + 1;
		prod_tail = atomic_load_acq_32(&br->br_prod_tail);

		if (cons_head == prod_tail) {
			critical_exit();
			return (NULL);
		}
	} while (!atomic_cmpset_acq_32(&br->br_cons_head, cons_head, cons_next));
	cons_idx = cons_head & mask;

	buf = br->br_ring[cons_idx];
#ifdef DEBUG_BUFRING
	br->br_ring[cons_idx] = NULL;
#endif
	/*
	 * If there are other dequeues in progress
	 * that preceded us, we need to wait for them
	 * to complete 
	 */   
	while (br->br_cons_tail != cons_head)
		cpu_spinwait();

	atomic_store_rel_32(&br->br_cons_tail, cons_next);
	critical_exit();

	return (buf);
}

/*
 * single-consumer dequeue 
 * use where dequeue is protected by a lock
 * e.g. a network driver's tx queue lock
 */
static __inline void *
buf_ring_dequeue_sc(struct buf_ring *br)
{
	uint32_t cons_head, cons_next, cons_idx;
	uint32_t prod_tail, mask;
	void *buf;

	mask = br->br_cons_mask;
	cons_head = br->br_cons_head;
	prod_tail = atomic_load_acq_32(&br->br_prod_tail);

	cons_next = cons_head + 1;

	if (cons_head == prod_tail)
		return (NULL);

	cons_idx = cons_head & mask;
	br->br_cons_head = cons_next;
	buf = br->br_ring[cons_idx];

#ifdef DEBUG_BUFRING
	br->br_ring[cons_idx] = NULL;
#ifdef _KERNEL
	if (!mtx_owned(br->br_lock))
		panic("lock not held on single consumer dequeue");
#endif
	if (br->br_cons_tail != cons_head)
		panic("inconsistent list cons_tail=%d cons_head=%d",
		    br->br_cons_tail, cons_head);
#endif
	atomic_store_rel_32(&br->br_cons_tail, cons_next);
	return (buf);
}

/*
 * single-consumer advance after a peek
 * use where it is protected by a lock
 * e.g. a network driver's tx queue lock
 */
static __inline void
buf_ring_advance_sc(struct buf_ring *br)
{
	uint32_t cons_head, cons_next, prod_tail;
#ifdef DEBUG_BUFRING
	uint32_t mask;

	mask = br->br_cons_mask;
#endif
	cons_head = br->br_cons_head;
	prod_tail = br->br_prod_tail;

	cons_next = cons_head + 1;
	if (cons_head == prod_tail)
		return;
	br->br_cons_head = cons_next;
#ifdef DEBUG_BUFRING
	br->br_ring[cons_head & mask] = NULL;
#endif
	atomic_store_rel_32(&br->br_cons_tail, cons_next);
}

/*
 * Used to return a buffer (most likely already there)
 * to the top of the ring. The caller should *not*
 * have used any dequeue to pull it out of the ring
 * but instead should have used the peek() function.
 * This is normally used where the transmit queue
 * of a driver is full, and an mbuf must be returned.
 * Most likely whats in the ring-buffer is what
 * is being put back (since it was not removed), but
 * sometimes the lower transmit function may have
 * done a pullup or other function that will have
 * changed it. As an optimization we always put it
 * back (since jhb says the store is probably cheaper),
 * if we have to do a multi-queue version we will need
 * the compare and an atomic.
 */
static __inline void
buf_ring_putback_sc(struct buf_ring *br, void *new)
{
	uint32_t mask;

	mask = br->br_cons_mask;
	KASSERT((br->br_cons_head & mask) != (br->br_prod_tail & mask),
		("Buf-Ring has none in putback")) ;
	br->br_ring[br->br_cons_head & mask] = new;
}

/*
 * return a pointer to the first entry in the ring
 * without modifying it, or NULL if the ring is empty
 * race-prone if not protected by a lock
 */
static __inline void *
buf_ring_peek(struct buf_ring *br)
{
	uint32_t cons_head, prod_tail, mask;

#if defined(DEBUG_BUFRING) && defined(_KERNEL)
	if ((br->br_lock != NULL) && !mtx_owned(br->br_lock))
		panic("lock not held on single consumer dequeue");
#endif	
	mask = br->br_cons_mask;
	prod_tail = atomic_load_acq_32(&br->br_prod_tail);
	cons_head = br->br_cons_head;

	if (cons_head == prod_tail)
		return (NULL);

	return (br->br_ring[cons_head & mask]);
}

static __inline void *
buf_ring_peek_clear_sc(struct buf_ring *br)
{
	uint32_t cons_head, prod_tail, mask;
	void *ret;

#if defined(DEBUG_BUFRING) && defined(_KERNEL)
	if (!mtx_owned(br->br_lock))
		panic("lock not held on single consumer dequeue");
#endif	

	mask = br->br_cons_mask;
	prod_tail = atomic_load_acq_32(&br->br_prod_tail);
	cons_head = br->br_cons_head;

	if (cons_head == prod_tail)
		return (NULL);

	ret = br->br_ring[cons_head & mask];
#ifdef DEBUG_BUFRING
	/*
	 * Single consumer, i.e. cons_head will not move while we are
	 * running, so atomic_swap_ptr() is not necessary here.
	 */
	br->br_ring[cons_head & mask] = NULL;
#endif
	return (ret);
}

static __inline int
buf_ring_full(struct buf_ring *br)
{

	return (br->br_prod_head == br->br_cons_tail + br->br_cons_size - 1);
}

static __inline int
buf_ring_empty(struct buf_ring *br)
{

	return (br->br_cons_head == br->br_prod_tail);
}

static __inline int
buf_ring_count(struct buf_ring *br)
{

	return ((br->br_prod_size + br->br_prod_tail - br->br_cons_tail)
	    & br->br_prod_mask);
}

#ifdef _KERNEL
struct buf_ring *buf_ring_alloc(int count, struct malloc_type *type, int flags,
    struct mtx *);
void buf_ring_free(struct buf_ring *br, struct malloc_type *type);
#else

#include <stdlib.h>

static inline struct buf_ring *
buf_ring_alloc(int count)
{
	struct buf_ring *br;

	KASSERT(powerof2(count), ("buf ring must be size power of 2"));

	br = calloc(1, sizeof(struct buf_ring) + count * sizeof(void *));
	if (br == NULL)
		return (NULL);
	br->br_prod_size = br->br_cons_size = count;
	br->br_prod_mask = br->br_cons_mask = count - 1;
	br->br_prod_head = br->br_cons_head = 0;
	br->br_prod_tail = br->br_cons_tail = 0;
	return (br);
}

static inline void
buf_ring_free(struct buf_ring *br)
{
	free(br);
}

#endif /* !_KERNEL */
#endif /* _SYS_BUF_RING_H_ */