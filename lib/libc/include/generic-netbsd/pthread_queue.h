/*	$NetBSD: pthread_queue.h,v 1.7 2022/04/19 20:32:17 rillig Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Nathan J. Williams.
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

#ifndef _LIB_PTHREAD_QUEUE_H
#define _LIB_PTHREAD_QUEUE_H

/*
 * Definition of a queue interface for the pthread library.
 * Style modeled on the sys/queue.h macros; implementation taken from
 * the tail queue, with the added property of static initializability
 * (and a corresponding extra cost in the _INSERT_TAIL() function.
*/

/*
 * Queue definitions.
 */

#define PTQ_HEAD(name, type)						\
struct name {								\
	struct type *ptqh_first;/* first element */			\
	struct type **ptqh_last;/* addr of last next element */		\
}

#define PTQ_HEAD_INITIALIZER { NULL, NULL }

#define PTQ_ENTRY(type)							\
struct {								\
	struct type *ptqe_next;	/* next element */			\
	struct type **ptqe_prev;/* address of previous next element */	\
}

/*
 * Queue functions.
 */

#define	PTQ_INIT(head) do {						\
	(head)->ptqh_first = NULL;					\
	(head)->ptqh_last = &(head)->ptqh_first;			\
} while (0)

#define	PTQ_INSERT_HEAD(head, elm, field) do {				\
	if (((elm)->field.ptqe_next = (head)->ptqh_first) != NULL)	\
		(head)->ptqh_first->field.ptqe_prev =			\
		    &(elm)->field.ptqe_next;				\
	else								\
		(head)->ptqh_last = &(elm)->field.ptqe_next;		\
	(head)->ptqh_first = (elm);					\
	(elm)->field.ptqe_prev = &(head)->ptqh_first;			\
} while (0)

#define	PTQ_INSERT_TAIL(head, elm, field) do {				\
	(elm)->field.ptqe_next = NULL;					\
	if ((head)->ptqh_last == NULL)					\
		(head)->ptqh_last = &(head)->ptqh_first;		\
	(elm)->field.ptqe_prev = (head)->ptqh_last;			\
	*(head)->ptqh_last = (elm);					\
	(head)->ptqh_last = &(elm)->field.ptqe_next;			\
} while (0)

#define	PTQ_INSERT_AFTER(head, listelm, elm, field) do {		\
	if (((elm)->field.ptqe_next = (listelm)->field.ptqe_next) != NULL)\
		(elm)->field.ptqe_next->field.ptqe_prev = 		\
		    &(elm)->field.ptqe_next;				\
	else								\
		(head)->ptqh_last = &(elm)->field.ptqe_next;		\
	(listelm)->field.ptqe_next = (elm);				\
	(elm)->field.ptqe_prev = &(listelm)->field.ptqe_next;		\
} while (0)

#define	PTQ_INSERT_BEFORE(listelm, elm, field) do {			\
	(elm)->field.ptqe_prev = (listelm)->field.ptqe_prev;		\
	(elm)->field.ptqe_next = (listelm);				\
	*(listelm)->field.ptqe_prev = (elm);				\
	(listelm)->field.ptqe_prev = &(elm)->field.ptqe_next;		\
} while (0)

#define	PTQ_REMOVE(head, elm, field) do {				\
	if (((elm)->field.ptqe_next) != NULL)				\
		(elm)->field.ptqe_next->field.ptqe_prev = 		\
		    (elm)->field.ptqe_prev;				\
	else								\
		(head)->ptqh_last = (elm)->field.ptqe_prev;		\
	*(elm)->field.ptqe_prev = (elm)->field.ptqe_next;		\
} while (0)

/*
 * Queue access methods.
 */

#define	PTQ_EMPTY(head)			((head)->ptqh_first == NULL)
#define	PTQ_FIRST(head)			((head)->ptqh_first)
#define	PTQ_NEXT(elm, field)		((elm)->field.ptqe_next)

#define	PTQ_LAST(head, headname)					\
	(*(((struct headname *)(void *)((head)->ptqh_last))->ptqh_last))
#define	PTQ_PREV(elm, headname, field)					\
	(*(((struct headname *)(void *)((elm)->field.ptqe_prev))->ptqh_last))

#define	PTQ_FOREACH(var, head, field)					\
	for ((var) = ((head)->ptqh_first);				\
		(var);							\
		(var) = ((var)->field.ptqe_next))

#define	PTQ_FOREACH_REVERSE(var, head, headname, field)			\
	for ((var) = (*(((struct headname *)(void *)((head)->ptqh_last))->ptqh_last));	\
		(var);							\
		(var) = (*(((struct headname *)(void *)((var)->field.ptqe_prev))->ptqh_last)))

#endif /* _LIB_PTHREAD_QUEUE_H */