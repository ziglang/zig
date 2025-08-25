/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2023 Colin Percival
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

#ifndef _SYS_QUEUE_MERGESORT_H_
#define	_SYS_QUEUE_MERGESORT_H_

/*
 * This file defines macros for performing mergesorts on singly-linked lists,
 * single-linked tail queues, lists, and tail queues as implemented in
 * <sys/queue.h>.
 */

/*
 * Shims to work around _CONCAT and _INSERT_AFTER taking different numbers of
 * arguments for different types of linked lists.
 */
#define STAILQ_CONCAT_4(head1, head2, type, field)				\
	STAILQ_CONCAT(head1, head2)
#define TAILQ_CONCAT_4(head1, head2, type, field)				\
	TAILQ_CONCAT(head1, head2, field)
#define SLIST_INSERT_AFTER_4(head, slistelm, elm, field)			\
	SLIST_INSERT_AFTER(slistelm, elm, field)
#define LIST_INSERT_AFTER_4(head, slistelm, elm, field)				\
	LIST_INSERT_AFTER(slistelm, elm, field)

/*
 * Generic macros which apply to all types of lists.
 */
#define SYSQUEUE_MERGE(sqms_list1, sqms_list2, thunk, sqms_cmp, TYPE, NAME,	\
    M_FIRST, M_INSERT_AFTER, M_INSERT_HEAD, M_NEXT, M_REMOVE_HEAD)		\
do {										\
	struct TYPE *sqms_elm1;							\
	struct TYPE *sqms_elm1_prev;						\
	struct TYPE *sqms_elm2;							\
										\
	/* Start at the beginning of list1; _prev is the previous node. */	\
	sqms_elm1_prev = NULL;							\
	sqms_elm1 = M_FIRST(sqms_list1);					\
										\
	/* Pull entries from list2 and insert them into list1. */		\
	while ((sqms_elm2 = M_FIRST(sqms_list2)) != NULL) {			\
		/* Remove from list2. */					\
		M_REMOVE_HEAD(sqms_list2, NAME);				\
										\
		/* Advance until we find the right place to insert it. */	\
		while ((sqms_elm1 != NULL) &&					\
		    (sqms_cmp)(sqms_elm2, sqms_elm1, thunk) >= 0) {		\
			sqms_elm1_prev = sqms_elm1;				\
			sqms_elm1 = M_NEXT(sqms_elm1, NAME);			\
		}								\
										\
		/* Insert into list1. */					\
		if (sqms_elm1_prev == NULL)					\
			M_INSERT_HEAD(sqms_list1, sqms_elm2, NAME);		\
		else								\
			M_INSERT_AFTER(sqms_list1, sqms_elm1_prev,		\
			    sqms_elm2, NAME);					\
		sqms_elm1_prev = sqms_elm2;					\
	}									\
} while (0)

#define SYSQUEUE_MERGE_SUBL(sqms_sorted, sqms_len1, sqms_len2, sqms_melm,	\
    sqms_mpos, thunk, sqms_cmp, TYPE, NAME,					\
    M_FIRST, M_NEXT, M_REMOVE_HEAD, M_INSERT_AFTER)				\
do {										\
	struct TYPE *sqms_curelm;						\
	size_t sqms_i;								\
										\
	/* Find the element before the start of the second sorted region. */	\
	while ((sqms_mpos) < (sqms_len1)) {					\
		(sqms_melm) = M_NEXT((sqms_melm), NAME);			\
		(sqms_mpos)++;							\
	}									\
										\
	/* Pull len1 entries off the list and insert in the right place. */	\
	for (sqms_i = 0; sqms_i < (sqms_len1); sqms_i++) {			\
		/* Grab the first element. */					\
		sqms_curelm = M_FIRST(&(sqms_sorted));				\
										\
		/* Advance until we find the right place to insert it. */	\
		while (((sqms_mpos) < (sqms_len1) + (sqms_len2)) &&		\
		    ((sqms_cmp)(sqms_curelm, M_NEXT((sqms_melm), NAME),		\
			thunk) >= 0)) {						\
			(sqms_melm) = M_NEXT((sqms_melm), NAME);		\
			(sqms_mpos)++;						\
		}								\
										\
		/* Move the element in the right place if not already there. */	\
		if (sqms_curelm != (sqms_melm)) {				\
			M_REMOVE_HEAD(&(sqms_sorted), NAME);			\
			M_INSERT_AFTER(&(sqms_sorted), (sqms_melm),		\
			    sqms_curelm, NAME);					\
			(sqms_melm) = sqms_curelm;				\
		}								\
	}									\
} while (0)

#define SYSQUEUE_MERGESORT(sqms_head, thunk, sqms_cmp, TYPE, NAME, M_HEAD,	\
    M_HEAD_INITIALIZER, M_EMPTY, M_FIRST, M_NEXT, M_INSERT_HEAD,		\
    M_INSERT_AFTER, M_CONCAT, M_REMOVE_HEAD)					\
do {										\
	/*									\
	 * Invariant: If sqms_slen = 2^a + 2^b + ... + 2^z with a < b < ... < z	\
	 * then sqms_sorted is a sequence of 2^a sorted entries followed by a	\
	 * list of 2^b sorted entries ... followed by a list of 2^z sorted	\
	 * entries.								\
	 */									\
	M_HEAD(, TYPE) sqms_sorted = M_HEAD_INITIALIZER(sqms_sorted);		\
	struct TYPE *sqms_elm;							\
	size_t sqms_slen = 0;							\
	size_t sqms_sortmask;							\
	size_t sqms_mpos;							\
										\
	/* Move everything from the input list to sqms_sorted. */		\
	while (!M_EMPTY(sqms_head)) {						\
		/* Pull the head off the input list. */				\
		sqms_elm = M_FIRST(sqms_head);					\
		M_REMOVE_HEAD(sqms_head, NAME);					\
										\
		/* Push it onto sqms_sorted. */					\
		M_INSERT_HEAD(&sqms_sorted, sqms_elm, NAME);			\
		sqms_slen++;							\
										\
		/* Restore sorting invariant. */				\
		sqms_mpos = 1;							\
		for (sqms_sortmask = 1;						\
		    sqms_sortmask & ~sqms_slen;					\
		    sqms_sortmask <<= 1)					\
			SYSQUEUE_MERGE_SUBL(sqms_sorted, sqms_sortmask,		\
			    sqms_sortmask, sqms_elm, sqms_mpos, thunk, sqms_cmp,\
			    TYPE, NAME, M_FIRST, M_NEXT, M_REMOVE_HEAD,		\
			    M_INSERT_AFTER);					\
	}									\
										\
	/* Merge the remaining sublists. */					\
	sqms_elm = M_FIRST(&sqms_sorted);					\
	sqms_mpos = 1;								\
	for (sqms_sortmask = 2;							\
	    sqms_sortmask < sqms_slen;						\
	    sqms_sortmask <<= 1)						\
		if (sqms_slen & sqms_sortmask)					\
			SYSQUEUE_MERGE_SUBL(sqms_sorted,			\
			    sqms_slen & (sqms_sortmask - 1), sqms_sortmask,	\
			    sqms_elm, sqms_mpos, thunk, sqms_cmp,		\
			    TYPE, NAME, M_FIRST, M_NEXT, M_REMOVE_HEAD,		\
			    M_INSERT_AFTER);					\
										\
	/* Move the sorted list back to the input list. */			\
	M_CONCAT(sqms_head, &sqms_sorted, TYPE, NAME);				\
} while (0)

/**
 * Macros for each of the individual data types.  They are all invoked as
 * FOO_MERGESORT(head, thunk, compar, TYPE, NAME)
 * and
 * FOO_MERGE(list1, list2, thunk, compar, TYPE, NAME)
 * where the compar function operates as in qsort_r, i.e. compar(a, b, thunk)
 * returns an integer less than, equal to, or greater than zero if a is
 * considered to be respectively less than, equal to, or greater than b.
 */
#define SLIST_MERGESORT(head, thunk, cmp, TYPE, NAME)				\
    SYSQUEUE_MERGESORT((head), (thunk), (cmp), TYPE, NAME, SLIST_HEAD,		\
    SLIST_HEAD_INITIALIZER, SLIST_EMPTY, SLIST_FIRST, SLIST_NEXT,		\
    SLIST_INSERT_HEAD, SLIST_INSERT_AFTER_4, SLIST_CONCAT, SLIST_REMOVE_HEAD)
#define SLIST_MERGE(list1, list2, thunk, cmp, TYPE, NAME)			\
    SYSQUEUE_MERGE((list1), (list2), (thunk), (cmp), TYPE, NAME, SLIST_FIRST,	\
    SLIST_INSERT_AFTER_4, SLIST_INSERT_HEAD, SLIST_NEXT, SLIST_REMOVE_HEAD)

#define LIST_MERGESORT(head, thunk, cmp, TYPE, NAME)				\
    SYSQUEUE_MERGESORT((head), (thunk), (cmp), TYPE, NAME, LIST_HEAD,		\
    LIST_HEAD_INITIALIZER, LIST_EMPTY, LIST_FIRST, LIST_NEXT,			\
    LIST_INSERT_HEAD, LIST_INSERT_AFTER_4, LIST_CONCAT, LIST_REMOVE_HEAD)
#define LIST_MERGE(list1, list2, thunk, cmp, TYPE, NAME)			\
    SYSQUEUE_MERGE((list1), (list2), (thunk), (cmp), TYPE, NAME, LIST_FIRST,	\
    LIST_INSERT_AFTER_4, LIST_INSERT_HEAD, LIST_NEXT, LIST_REMOVE_HEAD)

#define STAILQ_MERGESORT(head, thunk, cmp, TYPE, NAME)				\
    SYSQUEUE_MERGESORT((head), (thunk), (cmp), TYPE, NAME, STAILQ_HEAD,		\
    STAILQ_HEAD_INITIALIZER, STAILQ_EMPTY, STAILQ_FIRST, STAILQ_NEXT,		\
    STAILQ_INSERT_HEAD, STAILQ_INSERT_AFTER, STAILQ_CONCAT_4, STAILQ_REMOVE_HEAD)
#define STAILQ_MERGE(list1, list2, thunk, cmp, TYPE, NAME)			\
    SYSQUEUE_MERGE((list1), (list2), (thunk), (cmp), TYPE, NAME, STAILQ_FIRST,	\
    STAILQ_INSERT_AFTER, STAILQ_INSERT_HEAD, STAILQ_NEXT, STAILQ_REMOVE_HEAD)

#define TAILQ_MERGESORT(head, thunk, cmp, TYPE, NAME)				\
    SYSQUEUE_MERGESORT((head), (thunk), (cmp), TYPE, NAME, TAILQ_HEAD,		\
    TAILQ_HEAD_INITIALIZER, TAILQ_EMPTY, TAILQ_FIRST, TAILQ_NEXT,		\
    TAILQ_INSERT_HEAD, TAILQ_INSERT_AFTER, TAILQ_CONCAT_4, TAILQ_REMOVE_HEAD)
#define TAILQ_MERGE(list1, list2, thunk, cmp, TYPE, NAME)			\
    SYSQUEUE_MERGE((list1), (list2), (thunk), (cmp), TYPE, NAME, TAILQ_FIRST,	\
    TAILQ_INSERT_AFTER, TAILQ_INSERT_HEAD, TAILQ_NEXT, TAILQ_REMOVE_HEAD)

#endif /* !_SYS_QUEUE_MERGESORT_H_ */