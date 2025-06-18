/*	$NetBSD: callback.h,v 1.3 2007/07/09 21:11:32 ad Exp $	*/

/*-
 * Copyright (c)2006 YAMAMOTO Takashi,
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

#ifndef _SYS_CALLBACK_H_
#define	_SYS_CALLBACK_H_

#include <sys/queue.h>
#include <sys/mutex.h>
#include <sys/condvar.h>

struct callback_entry {
	TAILQ_ENTRY(callback_entry) ce_q;
	int (*ce_func)(struct callback_entry *, void *, void *);
	void *ce_obj;
};

struct callback_head {
	kmutex_t ch_lock;
	kcondvar_t ch_cv;
	TAILQ_HEAD(, callback_entry) ch_q;
	struct callback_entry *ch_next;
	int ch_nentries;
	int ch_running;
	int ch_flags;
};

/* return values of ce_func */
#define	CALLBACK_CHAIN_CONTINUE	0
#define	CALLBACK_CHAIN_ABORT	1

int callback_run_roundrobin(struct callback_head *, void *);
void callback_register(struct callback_head *, struct callback_entry *,
    void *, int (*)(struct callback_entry *, void *, void *));
void callback_unregister(struct callback_head *, struct callback_entry *);
void callback_head_init(struct callback_head *, int);
void callback_head_destroy(struct callback_head *);

#endif /* !_SYS_CALLBACK_H_ */