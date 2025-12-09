/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2001 Jake Burkholder <jake@FreeBSD.org>
 * All rights reserved.
 * Copyright (c) 2024 The FreeBSD Foundation
 *
 * Portions of this software were developed by Olivier Certner
 * <olce.freebsd@certner.fr> at Kumacom SARL under sponsorship from the FreeBSD
 * Foundation.
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

#ifndef	_RUNQ_H_
#define	_RUNQ_H_

#ifndef _KERNEL
#error "no user-serviceable parts inside"
#endif

#include <sys/types.h>		/* For bool. */
#include <sys/_param.h>
#include <sys/libkern.h>
#include <sys/queue.h>

struct thread;

/*
 * Run queue parameters.
 */

#define	RQ_MAX_PRIO	(255)	/* Maximum priority (minimum is 0). */
#define	RQ_PPQ		(1)	/* Priorities per queue. */

/*
 * Deduced from the above parameters and machine ones.
 */
#define	RQ_NQS	(howmany(RQ_MAX_PRIO + 1, RQ_PPQ)) /* Number of run queues. */
#define	RQ_PRI_TO_QUEUE_IDX(pri) ((pri) / RQ_PPQ) /* Priority to queue index. */

typedef unsigned long	rqsw_t;		/* runq's status words type. */
#define	RQSW_BPW	(sizeof(rqsw_t) * NBBY) /* Bits per runq word. */
#define RQSW_PRI	"%#lx"		/* printf() directive. */

/* Number of status words to cover RQ_NQS queues. */
#define	RQSW_NB			(howmany(RQ_NQS, RQSW_BPW))
#define	RQSW_IDX(idx)		((idx) / RQSW_BPW)
#define	RQSW_BIT_IDX(idx)	((idx) % RQSW_BPW)
#define	RQSW_BIT(idx)		(1ul << RQSW_BIT_IDX(idx))
#define	RQSW_BSF(word)		__extension__ ({			\
	int _res = ffsl((long)(word)); /* Assumes two-complement. */	\
	MPASS(_res > 0);						\
	_res - 1;							\
})
#define	RQSW_TO_QUEUE_IDX(word_idx, bit_idx)				\
	(((word_idx) * RQSW_BPW) + (bit_idx))
#define	RQSW_FIRST_QUEUE_IDX(word_idx, word)				\
	RQSW_TO_QUEUE_IDX(word_idx, RQSW_BSF(word))


/*
 * The queue for a given index as a list of threads.
 */
TAILQ_HEAD(rq_queue, thread);

/*
 * Bit array which maintains the status of a run queue.  When a queue is
 * non-empty the bit corresponding to the queue number will be set.
 */
struct rq_status {
	rqsw_t rq_sw[RQSW_NB];
};

/*
 * Run queue structure.  Contains an array of run queues on which processes
 * are placed, and a structure to maintain the status of each queue.
 */
struct runq {
	struct rq_status	rq_status;
	struct rq_queue		rq_queues[RQ_NQS];
};

void	runq_init(struct runq *);
bool	runq_is_queue_empty(struct runq *, int _idx);
void	runq_add(struct runq *, struct thread *, int _flags);
void	runq_add_idx(struct runq *, struct thread *, int _idx, int _flags);
bool	runq_remove(struct runq *, struct thread *);

/*
 * Implementation helpers for common and scheduler-specific runq_choose*()
 * functions.
 */
typedef bool	 runq_pred_t(int _idx, struct rq_queue *, void *_data);
int		 runq_findq(struct runq *const rq, const int lvl_min,
		    const int lvl_max,
		    runq_pred_t *const pred, void *const pred_data);
struct thread	*runq_first_thread_range(struct runq *const rq,
		    const int lvl_min, const int lvl_max);

bool		 runq_not_empty(struct runq *);
struct thread	*runq_choose(struct runq *);
struct thread	*runq_choose_fuzz(struct runq *, int _fuzz);

#endif