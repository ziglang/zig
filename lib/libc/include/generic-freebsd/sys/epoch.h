/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2018, Matthew Macy <mmacy@freebsd.org>
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

#ifndef _SYS_EPOCH_H_
#define _SYS_EPOCH_H_

#include <sys/cdefs.h>

struct epoch_context {
	void   *data[2];
} __aligned(sizeof(void *));

typedef struct epoch_context *epoch_context_t;
typedef	void epoch_callback_t(epoch_context_t);

#ifdef _KERNEL
#include <sys/lock.h>
#include <sys/pcpu.h>
#include <ck_epoch.h>

struct epoch;
typedef struct epoch *epoch_t;

#define EPOCH_PREEMPT 0x1
#define EPOCH_LOCKED 0x2

extern epoch_t global_epoch;
extern epoch_t global_epoch_preempt;

struct epoch_tracker {
	TAILQ_ENTRY(epoch_tracker) et_link;
	struct thread *et_td;
	ck_epoch_section_t et_section;
	uint8_t et_old_priority;
#ifdef EPOCH_TRACE
	struct epoch *et_epoch;
	SLIST_ENTRY(epoch_tracker) et_tlink;
	const char *et_file;
	int et_line;
	int et_flags;
#define	ET_REPORT_EXIT	0x1
#endif
}  __aligned(sizeof(void *));
typedef struct epoch_tracker *epoch_tracker_t;

epoch_t	epoch_alloc(const char *name, int flags);
void	epoch_free(epoch_t epoch);
void	epoch_wait(epoch_t epoch);
void	epoch_wait_preempt(epoch_t epoch);
void	epoch_drain_callbacks(epoch_t epoch);
void	epoch_call(epoch_t epoch, epoch_callback_t cb, epoch_context_t ctx);
int	in_epoch(epoch_t epoch);
int in_epoch_verbose(epoch_t epoch, int dump_onfail);
DPCPU_DECLARE(int, epoch_cb_count);
DPCPU_DECLARE(struct grouptask, epoch_cb_task);

#ifdef EPOCH_TRACE
#define	EPOCH_FILE_LINE	, const char *file, int line
#else
#define	EPOCH_FILE_LINE
#endif

void _epoch_enter_preempt(epoch_t epoch, epoch_tracker_t et EPOCH_FILE_LINE);
void _epoch_exit_preempt(epoch_t epoch, epoch_tracker_t et EPOCH_FILE_LINE);
#ifdef EPOCH_TRACE
void epoch_trace_list(struct thread *);
void epoch_where_report(epoch_t);
#define	epoch_enter_preempt(epoch, et)	_epoch_enter_preempt(epoch, et, __FILE__, __LINE__)
#define	epoch_exit_preempt(epoch, et)	_epoch_exit_preempt(epoch, et, __FILE__, __LINE__)
#else
#define epoch_enter_preempt(epoch, et)	_epoch_enter_preempt(epoch, et)
#define	epoch_exit_preempt(epoch, et)	_epoch_exit_preempt(epoch, et)
#endif
void epoch_enter(epoch_t epoch);
void epoch_exit(epoch_t epoch);

/*
 * Globally recognized epochs in the FreeBSD kernel.
 */
/* Network preemptible epoch, declared in sys/net/if.c. */
extern epoch_t net_epoch_preempt;
#define	NET_EPOCH_ENTER(et)	epoch_enter_preempt(net_epoch_preempt, &(et))
#define	NET_EPOCH_EXIT(et)	epoch_exit_preempt(net_epoch_preempt, &(et))
#define	NET_EPOCH_WAIT()	epoch_wait_preempt(net_epoch_preempt)
#define	NET_EPOCH_CALL(f, c)	epoch_call(net_epoch_preempt, (f), (c))
#define	NET_EPOCH_DRAIN_CALLBACKS() epoch_drain_callbacks(net_epoch_preempt)
#define	NET_EPOCH_ASSERT()	MPASS(in_epoch(net_epoch_preempt))
#define	NET_TASK_INIT(t, p, f, c) TASK_INIT_FLAGS(t, p, f, c, TASK_NETWORK)
#define	NET_GROUPTASK_INIT(gtask, prio, func, ctx)			\
	    GTASK_INIT(&(gtask)->gt_task, TASK_NETWORK, (prio), (func), (ctx))

#endif	/* _KERNEL */
#endif	/* _SYS_EPOCH_H_ */