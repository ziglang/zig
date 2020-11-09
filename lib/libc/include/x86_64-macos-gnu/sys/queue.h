/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*-
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)queue.h	8.5 (Berkeley) 8/20/94
 */

#ifndef _SYS_QUEUE_H_
#define _SYS_QUEUE_H_

#ifndef __improbable
#define __improbable(x) (x)             /* noop in userspace */
#endif /* __improbable */

/*
 * This file defines five types of data structures: singly-linked lists,
 * singly-linked tail queues, lists, tail queues, and circular queues.
 *
 * A singly-linked list is headed by a single forward pointer. The elements
 * are singly linked for minimum space and pointer manipulation overhead at
 * the expense of O(n) removal for arbitrary elements. New elements can be
 * added to the list after an existing element or at the head of the list.
 * Elements being removed from the head of the list should use the explicit
 * macro for this purpose for optimum efficiency. A singly-linked list may
 * only be traversed in the forward direction.  Singly-linked lists are ideal
 * for applications with large datasets and few or no removals or for
 * implementing a LIFO queue.
 *
 * A singly-linked tail queue is headed by a pair of pointers, one to the
 * head of the list and the other to the tail of the list. The elements are
 * singly linked for minimum space and pointer manipulation overhead at the
 * expense of O(n) removal for arbitrary elements. New elements can be added
 * to the list after an existing element, at the head of the list, or at the
 * end of the list. Elements being removed from the head of the tail queue
 * should use the explicit macro for this purpose for optimum efficiency.
 * A singly-linked tail queue may only be traversed in the forward direction.
 * Singly-linked tail queues are ideal for applications with large datasets
 * and few or no removals or for implementing a FIFO queue.
 *
 * A list is headed by a single forward pointer (or an array of forward
 * pointers for a hash table header). The elements are doubly linked
 * so that an arbitrary element can be removed without a need to
 * traverse the list. New elements can be added to the list before
 * or after an existing element or at the head of the list. A list
 * may only be traversed in the forward direction.
 *
 * A tail queue is headed by a pair of pointers, one to the head of the
 * list and the other to the tail of the list. The elements are doubly
 * linked so that an arbitrary element can be removed without a need to
 * traverse the list. New elements can be added to the list before or
 * after an existing element, at the head of the list, or at the end of
 * the list. A tail queue may be traversed in either direction.
 *
 * A circle queue is headed by a pair of pointers, one to the head of the
 * list and the other to the tail of the list. The elements are doubly
 * linked so that an arbitrary element can be removed without a need to
 * traverse the list. New elements can be added to the list before or after
 * an existing element, at the head of the list, or at the end of the list.
 * A circle queue may be traversed in either direction, but has a more
 * complex end of list detection.
 * Note that circle queues are deprecated, because, as the removal log
 * in FreeBSD states, "CIRCLEQs are a disgrace to everything Knuth taught
 * us in Volume 1 Chapter 2. [...] Use TAILQ instead, it provides the same
 * functionality." Code using them will continue to compile, but they
 * are no longer documented on the man page.
 *
 * For details on the use of these macros, see the queue(3) manual page.
 *
 *
 *				SLIST	LIST	STAILQ	TAILQ	CIRCLEQ
 * _HEAD			+	+	+	+	+
 * _HEAD_INITIALIZER		+	+	+	+	-
 * _ENTRY			+	+	+	+	+
 * _INIT			+	+	+	+	+
 * _EMPTY			+	+	+	+	+
 * _FIRST			+	+	+	+	+
 * _NEXT			+	+	+	+	+
 * _PREV			-	-	-	+	+
 * _LAST			-	-	+	+	+
 * _FOREACH			+	+	+	+	+
 * _FOREACH_SAFE		+	+	+	+	-
 * _FOREACH_REVERSE		-	-	-	+	-
 * _FOREACH_REVERSE_SAFE	-	-	-	+	-
 * _INSERT_HEAD			+	+	+	+	+
 * _INSERT_BEFORE		-	+	-	+	+
 * _INSERT_AFTER		+	+	+	+	+
 * _INSERT_TAIL			-	-	+	+	+
 * _CONCAT			-	-	+	+	-
 * _REMOVE_AFTER		+	-	+	-	-
 * _REMOVE_HEAD			+	-	+	-	-
 * _REMOVE_HEAD_UNTIL		-	-	+	-	-
 * _REMOVE			+	+	+	+	+
 * _SWAP			-	+	+	+	-
 *
 */
#ifdef QUEUE_MACRO_DEBUG
/* Store the last 2 places the queue element or head was altered */
struct qm_trace {
	char * lastfile;
	int lastline;
	char * prevfile;
	int prevline;
};

#define TRACEBUF        struct qm_trace trace;
#define TRASHIT(x)      do {(x) = (void *)-1;} while (0)

#define QMD_TRACE_HEAD(head) do {                                       \
	(head)->trace.prevline = (head)->trace.lastline;                \
	(head)->trace.prevfile = (head)->trace.lastfile;                \
	(head)->trace.lastline = __LINE__;                              \
	(head)->trace.lastfile = __FILE__;                              \
} while (0)

#define QMD_TRACE_ELEM(elem) do {                                       \
	(elem)->trace.prevline = (elem)->trace.lastline;                \
	(elem)->trace.prevfile = (elem)->trace.lastfile;                \
	(elem)->trace.lastline = __LINE__;                              \
	(elem)->trace.lastfile = __FILE__;                              \
} while (0)

#else
#define QMD_TRACE_ELEM(elem)
#define QMD_TRACE_HEAD(head)
#define TRACEBUF
#define TRASHIT(x)
#endif  /* QUEUE_MACRO_DEBUG */

/*
 * Horrible macros to enable use of code that was meant to be C-specific
 *   (and which push struct onto type) in C++; without these, C++ code
 *   that uses these macros in the context of a class will blow up
 *   due to "struct" being preprended to "type" by the macros, causing
 *   inconsistent use of tags.
 *
 * This approach is necessary because these are macros; we have to use
 *   these on a per-macro basis (because the queues are implemented as
 *   macros, disabling this warning in the scope of the header file is
 *   insufficient), whuch means we can't use #pragma, and have to use
 *   _Pragma.  We only need to use these for the queue macros that
 *   prepend "struct" to "type" and will cause C++ to blow up.
 */
#if defined(__clang__) && defined(__cplusplus)
#define __MISMATCH_TAGS_PUSH                                            \
	_Pragma("clang diagnostic push")                                \
	_Pragma("clang diagnostic ignored \"-Wmismatched-tags\"")
#define __MISMATCH_TAGS_POP                                             \
	_Pragma("clang diagnostic pop")
#else
#define __MISMATCH_TAGS_PUSH
#define __MISMATCH_TAGS_POP
#endif

/*!
 * Ensures that these macros can safely be used in structs when compiling with
 * clang. The macros do not allow for nullability attributes to be specified due
 * to how they are expanded. For example:
 *
 *     SLIST_HEAD(, foo _Nullable) bar;
 *
 * expands to
 *
 *     struct {
 *         struct foo _Nullable *slh_first;
 *     }
 *
 * which is not valid because the nullability specifier has to apply to the
 * pointer. So just ignore nullability completeness in all the places where this
 * is an issue.
 */
#if defined(__clang__)
#define __NULLABILITY_COMPLETENESS_PUSH \
	_Pragma("clang diagnostic push") \
	_Pragma("clang diagnostic ignored \"-Wnullability-completeness\"")
#define __NULLABILITY_COMPLETENESS_POP \
	_Pragma("clang diagnostic pop")
#else
#define __NULLABILITY_COMPLETENESS_PUSH
#define __NULLABILITY_COMPLETENESS_POP
#endif

/*
 * Singly-linked List declarations.
 */
#define SLIST_HEAD(name, type)                                          \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct name {                                                           \
	struct type *slh_first; /* first element */                     \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

#define SLIST_HEAD_INITIALIZER(head)                                    \
	{ NULL }

#define SLIST_ENTRY(type)                                               \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct {                                                                \
	struct type *sle_next;  /* next element */                      \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

/*
 * Singly-linked List functions.
 */
#define SLIST_EMPTY(head)       ((head)->slh_first == NULL)

#define SLIST_FIRST(head)       ((head)->slh_first)

#define SLIST_FOREACH(var, head, field)                                 \
	for ((var) = SLIST_FIRST((head));                               \
	    (var);                                                      \
	    (var) = SLIST_NEXT((var), field))

#define SLIST_FOREACH_SAFE(var, head, field, tvar)                      \
	for ((var) = SLIST_FIRST((head));                               \
	    (var) && ((tvar) = SLIST_NEXT((var), field), 1);            \
	    (var) = (tvar))

#define SLIST_FOREACH_PREVPTR(var, varp, head, field)                   \
	for ((varp) = &SLIST_FIRST((head));                             \
	    ((var) = *(varp)) != NULL;                                  \
	    (varp) = &SLIST_NEXT((var), field))

#define SLIST_INIT(head) do {                                           \
	SLIST_FIRST((head)) = NULL;                                     \
} while (0)

#define SLIST_INSERT_AFTER(slistelm, elm, field) do {                   \
	SLIST_NEXT((elm), field) = SLIST_NEXT((slistelm), field);       \
	SLIST_NEXT((slistelm), field) = (elm);                          \
} while (0)

#define SLIST_INSERT_HEAD(head, elm, field) do {                        \
	SLIST_NEXT((elm), field) = SLIST_FIRST((head));                 \
	SLIST_FIRST((head)) = (elm);                                    \
} while (0)

#define SLIST_NEXT(elm, field)  ((elm)->field.sle_next)

#define SLIST_REMOVE(head, elm, type, field)                            \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
do {                                                                    \
	if (SLIST_FIRST((head)) == (elm)) {                             \
	        SLIST_REMOVE_HEAD((head), field);                       \
	}                                                               \
	else {                                                          \
	        struct type *curelm = SLIST_FIRST((head));              \
	        while (SLIST_NEXT(curelm, field) != (elm))              \
	                curelm = SLIST_NEXT(curelm, field);             \
	        SLIST_REMOVE_AFTER(curelm, field);                      \
	}                                                               \
	TRASHIT((elm)->field.sle_next);                                 \
} while (0)                                                             \
__NULLABILITY_COMPLETENESS_POP                                      \
__MISMATCH_TAGS_POP

#define SLIST_REMOVE_AFTER(elm, field) do {                             \
	SLIST_NEXT(elm, field) =                                        \
	    SLIST_NEXT(SLIST_NEXT(elm, field), field);                  \
} while (0)

#define SLIST_REMOVE_HEAD(head, field) do {                             \
	SLIST_FIRST((head)) = SLIST_NEXT(SLIST_FIRST((head)), field);   \
} while (0)

/*
 * Singly-linked Tail queue declarations.
 */
#define STAILQ_HEAD(name, type)                                         \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct name {                                                           \
	struct type *stqh_first;/* first element */                     \
	struct type **stqh_last;/* addr of last next element */         \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

#define STAILQ_HEAD_INITIALIZER(head)                                   \
	{ NULL, &(head).stqh_first }

#define STAILQ_ENTRY(type)                                              \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct {                                                                \
	struct type *stqe_next; /* next element */                      \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                         \
__MISMATCH_TAGS_POP

/*
 * Singly-linked Tail queue functions.
 */
#define STAILQ_CONCAT(head1, head2) do {                                \
	if (!STAILQ_EMPTY((head2))) {                                   \
	        *(head1)->stqh_last = (head2)->stqh_first;              \
	        (head1)->stqh_last = (head2)->stqh_last;                \
	        STAILQ_INIT((head2));                                   \
	}                                                               \
} while (0)

#define STAILQ_EMPTY(head)      ((head)->stqh_first == NULL)

#define STAILQ_FIRST(head)      ((head)->stqh_first)

#define STAILQ_FOREACH(var, head, field)                                \
	for((var) = STAILQ_FIRST((head));                               \
	   (var);                                                       \
	   (var) = STAILQ_NEXT((var), field))


#define STAILQ_FOREACH_SAFE(var, head, field, tvar)                     \
	for ((var) = STAILQ_FIRST((head));                              \
	    (var) && ((tvar) = STAILQ_NEXT((var), field), 1);           \
	    (var) = (tvar))

#define STAILQ_INIT(head) do {                                          \
	STAILQ_FIRST((head)) = NULL;                                    \
	(head)->stqh_last = &STAILQ_FIRST((head));                      \
} while (0)

#define STAILQ_INSERT_AFTER(head, tqelm, elm, field) do {               \
	if ((STAILQ_NEXT((elm), field) = STAILQ_NEXT((tqelm), field)) == NULL)\
	        (head)->stqh_last = &STAILQ_NEXT((elm), field);         \
	STAILQ_NEXT((tqelm), field) = (elm);                            \
} while (0)

#define STAILQ_INSERT_HEAD(head, elm, field) do {                       \
	if ((STAILQ_NEXT((elm), field) = STAILQ_FIRST((head))) == NULL) \
	        (head)->stqh_last = &STAILQ_NEXT((elm), field);         \
	STAILQ_FIRST((head)) = (elm);                                   \
} while (0)

#define STAILQ_INSERT_TAIL(head, elm, field) do {                       \
	STAILQ_NEXT((elm), field) = NULL;                               \
	*(head)->stqh_last = (elm);                                     \
	(head)->stqh_last = &STAILQ_NEXT((elm), field);                 \
} while (0)

#define STAILQ_LAST(head, type, field)                                  \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
	(STAILQ_EMPTY((head)) ?                                         \
	        NULL :                                                  \
	        ((struct type *)(void *)                                \
	        ((char *)((head)->stqh_last) - __offsetof(struct type, field))))\
__NULLABILITY_COMPLETENESS_POP                                         \
__MISMATCH_TAGS_POP

#define STAILQ_NEXT(elm, field) ((elm)->field.stqe_next)

#define STAILQ_REMOVE(head, elm, type, field)                           \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
do {                                                                    \
	if (STAILQ_FIRST((head)) == (elm)) {                            \
	        STAILQ_REMOVE_HEAD((head), field);                      \
	}                                                               \
	else {                                                          \
	        struct type *curelm = STAILQ_FIRST((head));             \
	        while (STAILQ_NEXT(curelm, field) != (elm))             \
	                curelm = STAILQ_NEXT(curelm, field);            \
	        STAILQ_REMOVE_AFTER(head, curelm, field);               \
	}                                                               \
	TRASHIT((elm)->field.stqe_next);                                \
} while (0)                                                             \
__NULLABILITY_COMPLETENESS_POP                                      \
__MISMATCH_TAGS_POP

#define STAILQ_REMOVE_HEAD(head, field) do {                            \
	if ((STAILQ_FIRST((head)) =                                     \
	     STAILQ_NEXT(STAILQ_FIRST((head)), field)) == NULL)         \
	        (head)->stqh_last = &STAILQ_FIRST((head));              \
} while (0)

#define STAILQ_REMOVE_HEAD_UNTIL(head, elm, field) do {                 \
       if ((STAILQ_FIRST((head)) = STAILQ_NEXT((elm), field)) == NULL) \
	       (head)->stqh_last = &STAILQ_FIRST((head));              \
} while (0)

#define STAILQ_REMOVE_AFTER(head, elm, field) do {                      \
	if ((STAILQ_NEXT(elm, field) =                                  \
	     STAILQ_NEXT(STAILQ_NEXT(elm, field), field)) == NULL)      \
	        (head)->stqh_last = &STAILQ_NEXT((elm), field);         \
} while (0)

#define STAILQ_SWAP(head1, head2, type)                                 \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
do {                                                                    \
	struct type *swap_first = STAILQ_FIRST(head1);                  \
	struct type **swap_last = (head1)->stqh_last;                   \
	STAILQ_FIRST(head1) = STAILQ_FIRST(head2);                      \
	(head1)->stqh_last = (head2)->stqh_last;                        \
	STAILQ_FIRST(head2) = swap_first;                               \
	(head2)->stqh_last = swap_last;                                 \
	if (STAILQ_EMPTY(head1))                                        \
	        (head1)->stqh_last = &STAILQ_FIRST(head1);              \
	if (STAILQ_EMPTY(head2))                                        \
	        (head2)->stqh_last = &STAILQ_FIRST(head2);              \
} while (0)                                                             \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP


/*
 * List declarations.
 */
#define LIST_HEAD(name, type)                                           \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct name {                                                           \
	struct type *lh_first;  /* first element */                     \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

#define LIST_HEAD_INITIALIZER(head)                                     \
	{ NULL }

#define LIST_ENTRY(type)                                                \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct {                                                                \
	struct type *le_next;   /* next element */                      \
	struct type **le_prev;  /* address of previous next element */  \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

/*
 * List functions.
 */

#define LIST_CHECK_HEAD(head, field)
#define LIST_CHECK_NEXT(elm, field)
#define LIST_CHECK_PREV(elm, field)

#define LIST_EMPTY(head)        ((head)->lh_first == NULL)

#define LIST_FIRST(head)        ((head)->lh_first)

#define LIST_FOREACH(var, head, field)                                  \
	for ((var) = LIST_FIRST((head));                                \
	    (var);                                                      \
	    (var) = LIST_NEXT((var), field))

#define LIST_FOREACH_SAFE(var, head, field, tvar)                       \
	for ((var) = LIST_FIRST((head));                                \
	    (var) && ((tvar) = LIST_NEXT((var), field), 1);             \
	    (var) = (tvar))

#define LIST_INIT(head) do {                                            \
	LIST_FIRST((head)) = NULL;                                      \
} while (0)

#define LIST_INSERT_AFTER(listelm, elm, field) do {                     \
	LIST_CHECK_NEXT(listelm, field);                                \
	if ((LIST_NEXT((elm), field) = LIST_NEXT((listelm), field)) != NULL)\
	        LIST_NEXT((listelm), field)->field.le_prev =            \
	            &LIST_NEXT((elm), field);                           \
	LIST_NEXT((listelm), field) = (elm);                            \
	(elm)->field.le_prev = &LIST_NEXT((listelm), field);            \
} while (0)

#define LIST_INSERT_BEFORE(listelm, elm, field) do {                    \
	LIST_CHECK_PREV(listelm, field);                                \
	(elm)->field.le_prev = (listelm)->field.le_prev;                \
	LIST_NEXT((elm), field) = (listelm);                            \
	*(listelm)->field.le_prev = (elm);                              \
	(listelm)->field.le_prev = &LIST_NEXT((elm), field);            \
} while (0)

#define LIST_INSERT_HEAD(head, elm, field) do {                         \
	LIST_CHECK_HEAD((head), field);                         \
	if ((LIST_NEXT((elm), field) = LIST_FIRST((head))) != NULL)     \
	        LIST_FIRST((head))->field.le_prev = &LIST_NEXT((elm), field);\
	LIST_FIRST((head)) = (elm);                                     \
	(elm)->field.le_prev = &LIST_FIRST((head));                     \
} while (0)

#define LIST_NEXT(elm, field)   ((elm)->field.le_next)

#define LIST_REMOVE(elm, field) do {                                    \
	LIST_CHECK_NEXT(elm, field);                            \
	LIST_CHECK_PREV(elm, field);                            \
	if (LIST_NEXT((elm), field) != NULL)                            \
	        LIST_NEXT((elm), field)->field.le_prev =                \
	            (elm)->field.le_prev;                               \
	*(elm)->field.le_prev = LIST_NEXT((elm), field);                \
	TRASHIT((elm)->field.le_next);                                  \
	TRASHIT((elm)->field.le_prev);                                  \
} while (0)

#define LIST_SWAP(head1, head2, type, field)                            \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
do {                                                                    \
	struct type *swap_tmp = LIST_FIRST((head1));                    \
	LIST_FIRST((head1)) = LIST_FIRST((head2));                      \
	LIST_FIRST((head2)) = swap_tmp;                                 \
	if ((swap_tmp = LIST_FIRST((head1))) != NULL)                   \
	        swap_tmp->field.le_prev = &LIST_FIRST((head1));         \
	if ((swap_tmp = LIST_FIRST((head2))) != NULL)                   \
	        swap_tmp->field.le_prev = &LIST_FIRST((head2));         \
} while (0)                                                             \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

/*
 * Tail queue declarations.
 */
#define TAILQ_HEAD(name, type)                                          \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct name {                                                           \
	struct type *tqh_first; /* first element */                     \
	struct type **tqh_last; /* addr of last next element */         \
	TRACEBUF                                                        \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

#define TAILQ_HEAD_INITIALIZER(head)                                    \
	{ NULL, &(head).tqh_first }

#define TAILQ_ENTRY(type)                                               \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct {                                                                \
	struct type *tqe_next;  /* next element */                      \
	struct type **tqe_prev; /* address of previous next element */  \
	TRACEBUF                                                        \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

/*
 * Tail queue functions.
 */
#define TAILQ_CHECK_HEAD(head, field)
#define TAILQ_CHECK_NEXT(elm, field)
#define TAILQ_CHECK_PREV(elm, field)

#define TAILQ_CONCAT(head1, head2, field) do {                          \
	if (!TAILQ_EMPTY(head2)) {                                      \
	        *(head1)->tqh_last = (head2)->tqh_first;                \
	        (head2)->tqh_first->field.tqe_prev = (head1)->tqh_last; \
	        (head1)->tqh_last = (head2)->tqh_last;                  \
	        TAILQ_INIT((head2));                                    \
	        QMD_TRACE_HEAD(head1);                                  \
	        QMD_TRACE_HEAD(head2);                                  \
	}                                                               \
} while (0)

#define TAILQ_EMPTY(head)       ((head)->tqh_first == NULL)

#define TAILQ_FIRST(head)       ((head)->tqh_first)

#define TAILQ_FOREACH(var, head, field)                                 \
	for ((var) = TAILQ_FIRST((head));                               \
	    (var);                                                      \
	    (var) = TAILQ_NEXT((var), field))

#define TAILQ_FOREACH_SAFE(var, head, field, tvar)                      \
	for ((var) = TAILQ_FIRST((head));                               \
	    (var) && ((tvar) = TAILQ_NEXT((var), field), 1);            \
	    (var) = (tvar))

#define TAILQ_FOREACH_REVERSE(var, head, headname, field)               \
	for ((var) = TAILQ_LAST((head), headname);                      \
	    (var);                                                      \
	    (var) = TAILQ_PREV((var), headname, field))

#define TAILQ_FOREACH_REVERSE_SAFE(var, head, headname, field, tvar)    \
	for ((var) = TAILQ_LAST((head), headname);                      \
	    (var) && ((tvar) = TAILQ_PREV((var), headname, field), 1);  \
	    (var) = (tvar))


#define TAILQ_INIT(head) do {                                           \
	TAILQ_FIRST((head)) = NULL;                                     \
	(head)->tqh_last = &TAILQ_FIRST((head));                        \
	QMD_TRACE_HEAD(head);                                           \
} while (0)


#define TAILQ_INSERT_AFTER(head, listelm, elm, field) do {              \
	TAILQ_CHECK_NEXT(listelm, field);                               \
	if ((TAILQ_NEXT((elm), field) = TAILQ_NEXT((listelm), field)) != NULL)\
	        TAILQ_NEXT((elm), field)->field.tqe_prev =              \
	            &TAILQ_NEXT((elm), field);                          \
	else {                                                          \
	        (head)->tqh_last = &TAILQ_NEXT((elm), field);           \
	        QMD_TRACE_HEAD(head);                                   \
	}                                                               \
	TAILQ_NEXT((listelm), field) = (elm);                           \
	(elm)->field.tqe_prev = &TAILQ_NEXT((listelm), field);          \
	QMD_TRACE_ELEM(&(elm)->field);                                  \
	QMD_TRACE_ELEM(&listelm->field);                                \
} while (0)

#define TAILQ_INSERT_BEFORE(listelm, elm, field) do {                   \
	TAILQ_CHECK_PREV(listelm, field);                               \
	(elm)->field.tqe_prev = (listelm)->field.tqe_prev;              \
	TAILQ_NEXT((elm), field) = (listelm);                           \
	*(listelm)->field.tqe_prev = (elm);                             \
	(listelm)->field.tqe_prev = &TAILQ_NEXT((elm), field);          \
	QMD_TRACE_ELEM(&(elm)->field);                                  \
	QMD_TRACE_ELEM(&listelm->field);                                \
} while (0)

#define TAILQ_INSERT_HEAD(head, elm, field) do {                        \
	TAILQ_CHECK_HEAD(head, field);                                  \
	if ((TAILQ_NEXT((elm), field) = TAILQ_FIRST((head))) != NULL)   \
	        TAILQ_FIRST((head))->field.tqe_prev =                   \
	            &TAILQ_NEXT((elm), field);                          \
	else                                                            \
	        (head)->tqh_last = &TAILQ_NEXT((elm), field);           \
	TAILQ_FIRST((head)) = (elm);                                    \
	(elm)->field.tqe_prev = &TAILQ_FIRST((head));                   \
	QMD_TRACE_HEAD(head);                                           \
	QMD_TRACE_ELEM(&(elm)->field);                                  \
} while (0)

#define TAILQ_INSERT_TAIL(head, elm, field) do {                        \
	TAILQ_NEXT((elm), field) = NULL;                                \
	(elm)->field.tqe_prev = (head)->tqh_last;                       \
	*(head)->tqh_last = (elm);                                      \
	(head)->tqh_last = &TAILQ_NEXT((elm), field);                   \
	QMD_TRACE_HEAD(head);                                           \
	QMD_TRACE_ELEM(&(elm)->field);                                  \
} while (0)

#define TAILQ_LAST(head, headname)                                      \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
	(*(((struct headname *)((head)->tqh_last))->tqh_last))          \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

#define TAILQ_NEXT(elm, field) ((elm)->field.tqe_next)

#define TAILQ_PREV(elm, headname, field)                                \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
	(*(((struct headname *)((elm)->field.tqe_prev))->tqh_last))     \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

#define TAILQ_REMOVE(head, elm, field) do {                             \
	TAILQ_CHECK_NEXT(elm, field);                                   \
	TAILQ_CHECK_PREV(elm, field);                                   \
	if ((TAILQ_NEXT((elm), field)) != NULL)                         \
	        TAILQ_NEXT((elm), field)->field.tqe_prev =              \
	            (elm)->field.tqe_prev;                              \
	else {                                                          \
	        (head)->tqh_last = (elm)->field.tqe_prev;               \
	        QMD_TRACE_HEAD(head);                                   \
	}                                                               \
	*(elm)->field.tqe_prev = TAILQ_NEXT((elm), field);              \
	TRASHIT((elm)->field.tqe_next);                                 \
	TRASHIT((elm)->field.tqe_prev);                                 \
	QMD_TRACE_ELEM(&(elm)->field);                                  \
} while (0)

/*
 * Why did they switch to spaces for this one macro?
 */
#define TAILQ_SWAP(head1, head2, type, field)                           \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
do {                                                                    \
	struct type *swap_first = (head1)->tqh_first;                   \
	struct type **swap_last = (head1)->tqh_last;                    \
	(head1)->tqh_first = (head2)->tqh_first;                        \
	(head1)->tqh_last = (head2)->tqh_last;                          \
	(head2)->tqh_first = swap_first;                                \
	(head2)->tqh_last = swap_last;                                  \
	if ((swap_first = (head1)->tqh_first) != NULL)                  \
	        swap_first->field.tqe_prev = &(head1)->tqh_first;       \
	else                                                            \
	        (head1)->tqh_last = &(head1)->tqh_first;                \
	if ((swap_first = (head2)->tqh_first) != NULL)                  \
	        swap_first->field.tqe_prev = &(head2)->tqh_first;       \
	else                                                            \
	        (head2)->tqh_last = &(head2)->tqh_first;                \
} while (0)                                                             \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

/*
 * Circular queue definitions.
 */
#define CIRCLEQ_HEAD(name, type)                                        \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct name {                                                           \
	struct type *cqh_first;         /* first element */             \
	struct type *cqh_last;          /* last element */              \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                          \
__MISMATCH_TAGS_POP

#define CIRCLEQ_ENTRY(type)                                             \
__MISMATCH_TAGS_PUSH                                                    \
__NULLABILITY_COMPLETENESS_PUSH                                         \
struct {                                                                \
	struct type *cqe_next;          /* next element */              \
	struct type *cqe_prev;          /* previous element */          \
}                                                                       \
__NULLABILITY_COMPLETENESS_POP                                         \
__MISMATCH_TAGS_POP

/*
 * Circular queue functions.
 */
#define CIRCLEQ_CHECK_HEAD(head, field)
#define CIRCLEQ_CHECK_NEXT(head, elm, field)
#define CIRCLEQ_CHECK_PREV(head, elm, field)

#define CIRCLEQ_EMPTY(head) ((head)->cqh_first == (void *)(head))

#define CIRCLEQ_FIRST(head) ((head)->cqh_first)

#define CIRCLEQ_FOREACH(var, head, field)                               \
	for((var) = (head)->cqh_first;                                  \
	    (var) != (void *)(head);                                    \
	    (var) = (var)->field.cqe_next)

#define CIRCLEQ_INIT(head) do {                                         \
	(head)->cqh_first = (void *)(head);                             \
	(head)->cqh_last = (void *)(head);                              \
} while (0)

#define CIRCLEQ_INSERT_AFTER(head, listelm, elm, field) do {            \
	CIRCLEQ_CHECK_NEXT(head, listelm, field);                       \
	(elm)->field.cqe_next = (listelm)->field.cqe_next;              \
	(elm)->field.cqe_prev = (listelm);                              \
	if ((listelm)->field.cqe_next == (void *)(head))                \
	        (head)->cqh_last = (elm);                               \
	else                                                            \
	        (listelm)->field.cqe_next->field.cqe_prev = (elm);      \
	(listelm)->field.cqe_next = (elm);                              \
} while (0)

#define CIRCLEQ_INSERT_BEFORE(head, listelm, elm, field) do {           \
	CIRCLEQ_CHECK_PREV(head, listelm, field);                       \
	(elm)->field.cqe_next = (listelm);                              \
	(elm)->field.cqe_prev = (listelm)->field.cqe_prev;              \
	if ((listelm)->field.cqe_prev == (void *)(head))                \
	        (head)->cqh_first = (elm);                              \
	else                                                            \
	        (listelm)->field.cqe_prev->field.cqe_next = (elm);      \
	(listelm)->field.cqe_prev = (elm);                              \
} while (0)

#define CIRCLEQ_INSERT_HEAD(head, elm, field) do {                      \
	CIRCLEQ_CHECK_HEAD(head, field);                                \
	(elm)->field.cqe_next = (head)->cqh_first;                      \
	(elm)->field.cqe_prev = (void *)(head);                         \
	if ((head)->cqh_last == (void *)(head))                         \
	        (head)->cqh_last = (elm);                               \
	else                                                            \
	        (head)->cqh_first->field.cqe_prev = (elm);              \
	(head)->cqh_first = (elm);                                      \
} while (0)

#define CIRCLEQ_INSERT_TAIL(head, elm, field) do {                      \
	(elm)->field.cqe_next = (void *)(head);                         \
	(elm)->field.cqe_prev = (head)->cqh_last;                       \
	if ((head)->cqh_first == (void *)(head))                        \
	        (head)->cqh_first = (elm);                              \
	else                                                            \
	        (head)->cqh_last->field.cqe_next = (elm);               \
	(head)->cqh_last = (elm);                                       \
} while (0)

#define CIRCLEQ_LAST(head) ((head)->cqh_last)

#define CIRCLEQ_NEXT(elm, field) ((elm)->field.cqe_next)

#define CIRCLEQ_PREV(elm, field) ((elm)->field.cqe_prev)

#define CIRCLEQ_REMOVE(head, elm, field) do {                           \
	CIRCLEQ_CHECK_NEXT(head, elm, field);                           \
	CIRCLEQ_CHECK_PREV(head, elm, field);                           \
	if ((elm)->field.cqe_next == (void *)(head))                    \
	        (head)->cqh_last = (elm)->field.cqe_prev;               \
	else                                                            \
	        (elm)->field.cqe_next->field.cqe_prev =                 \
	            (elm)->field.cqe_prev;                              \
	if ((elm)->field.cqe_prev == (void *)(head))                    \
	        (head)->cqh_first = (elm)->field.cqe_next;              \
	else                                                            \
	        (elm)->field.cqe_prev->field.cqe_next =                 \
	            (elm)->field.cqe_next;                              \
} while (0)

#ifdef _KERNEL

#if NOTFB31

/*
 * XXX insque() and remque() are an old way of handling certain queues.
 * They bogusly assumes that all queue heads look alike.
 */

struct quehead {
	struct quehead *qh_link;
	struct quehead *qh_rlink;
};

#ifdef __GNUC__
#define chkquenext(a)
#define chkqueprev(a)

static __inline void
insque(void *a, void *b)
{
	struct quehead *element = (struct quehead *)a,
	    *head = (struct quehead *)b;
	chkquenext(head);

	element->qh_link = head->qh_link;
	element->qh_rlink = head;
	head->qh_link = element;
	element->qh_link->qh_rlink = element;
}

static __inline void
remque(void *a)
{
	struct quehead *element = (struct quehead *)a;
	chkquenext(element);
	chkqueprev(element);

	element->qh_link->qh_rlink = element->qh_rlink;
	element->qh_rlink->qh_link = element->qh_link;
	element->qh_rlink = 0;
}

#else /* !__GNUC__ */

void    insque(void *a, void *b);
void    remque(void *a);

#endif /* __GNUC__ */

#endif /* NOTFB31 */
#endif /* _KERNEL */

#endif /* !_SYS_QUEUE_H_ */
