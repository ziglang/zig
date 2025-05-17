/* $NetBSD: gcq.h,v 1.3 2018/04/19 21:19:07 christos Exp $ */
/*
 * Not (c) 2007 Matthew Orgass
 * This file is public domain, meaning anyone can make any use of part or all 
 * of this file including copying into other works without credit.  Any use, 
 * modified or not, is solely the responsibility of the user.  If this file is 
 * part of a collection then use in the collection is governed by the terms of 
 * the collection.
 */

/*
 * Generic Circular Queues: Pointer arithmetic is used to recover the 
 * enclosing object.  Merge operation is provided.  Items can be multiply 
 * removed, but queue traversal requires separate knowledge of the queue head.
 */

#ifndef _GCQ_H
#define _GCQ_H

#ifdef _KERNEL
#include <sys/types.h>
#include <sys/null.h>
#include <lib/libkern/libkern.h>
#else
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <assert.h>
#endif

#ifdef GCQ_USE_ASSERT
#define GCQ_ASSERT(x) assert(x)
#else
#ifdef _KERNEL
#define GCQ_ASSERT(x) KASSERT(x)
#else
#define GCQ_ASSERT(x) _DIAGASSERT(x)
#endif
#endif

struct gcq {
	struct gcq *q_next;
	struct gcq *q_prev;
};

struct gcq_head {
	struct gcq hq;
};

#define GCQ_INIT(q) { &(q), &(q) }
#define GCQ_INIT_HEAD(head) { GCQ_INIT((head).hq) }

__attribute__((nonnull, always_inline)) static __inline void
gcq_init(struct gcq *q)
{
	q->q_next = q->q_prev = q;
}

__attribute__((nonnull, const, warn_unused_result, always_inline)) 
static __inline struct gcq *
gcq_q(struct gcq *q)
{
	return q;
}

__attribute__((nonnull, const, warn_unused_result, always_inline)) 
static __inline struct gcq *
gcq_hq(struct gcq_head *head)
{
	return (struct gcq *)head;
}

__attribute__((nonnull, const, warn_unused_result, always_inline)) 
static __inline struct gcq_head *
gcq_head(struct gcq *q)
{
	return (struct gcq_head *)q;
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_init_head(struct gcq_head *head)
{
	gcq_init(gcq_hq(head));
}

__attribute__((nonnull, pure, warn_unused_result, always_inline))
static __inline bool
gcq_onlist(struct gcq *q)
{
	return (q->q_next != q);
}

__attribute__((nonnull, pure, warn_unused_result, always_inline))
static __inline bool
gcq_empty(struct gcq_head *head)
{
	return (!gcq_onlist(gcq_hq(head)));
}

__attribute__((nonnull, pure, warn_unused_result, always_inline))
static __inline bool
gcq_linked(struct gcq *prev, struct gcq *next)
{
	return (prev->q_next == next && next->q_prev == prev);
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_insert_after(struct gcq *on, struct gcq *off)
{
	struct gcq *on_next;
	GCQ_ASSERT(off->q_next == off && off->q_prev == off);
	on_next = on->q_next;

	off->q_prev = on;
	off->q_next = on_next;
	on_next->q_prev = off;
	on->q_next = off;
}

__attribute__((nonnull)) static __inline void
gcq_insert_before(struct gcq *on, struct gcq *off)
{
	struct gcq *on_prev;
	GCQ_ASSERT(off->q_next == off && off->q_prev == off);
	on_prev = on->q_prev;

	off->q_next = on;
	off->q_prev = on_prev;
	on_prev->q_next = off;
	on->q_prev = off;
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_insert_head(struct gcq_head *head, struct gcq *q)
{
	gcq_insert_after(gcq_hq(head), q);
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_insert_tail(struct gcq_head *head, struct gcq *q)
{
	gcq_insert_before(gcq_hq(head), q);
}

__attribute__((nonnull)) static __inline void
gcq_tie(struct gcq *dst, struct gcq *src)
{
	struct gcq *dst_next, *src_prev;
	dst_next = dst->q_next;
	src_prev = src->q_prev;

	src_prev->q_next = dst_next;
	dst_next->q_prev = src_prev;
	src->q_prev = dst;
	dst->q_next = src;
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_tie_after(struct gcq *dst, struct gcq *src)
{
	GCQ_ASSERT(dst != src && dst->q_prev != src);
	gcq_tie(dst, src);
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_tie_before(struct gcq *dst, struct gcq *src)
{
	gcq_tie_after(dst->q_prev, src);
}

__attribute__((nonnull)) static __inline struct gcq *
gcq_remove(struct gcq *q)
{
	struct gcq *next, *prev;
	next = q->q_next;
	prev = q->q_prev;

	prev->q_next = next;
	next->q_prev = prev;
	gcq_init(q);
	return q;
}

#ifdef GCQ_UNCONDITIONAL_MERGE
__attribute__((nonnull)) static __inline void
gcq_merge(struct gcq *dst, struct gcq *src)
{
	GCQ_ASSERT(dst != src && dst->q_prev != src);
	gcq_tie(dst, src);
	gcq_tie(src, src);
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_merge_head(struct gcq_head *dst, struct gcq_head *src)
{
	gcq_merge(gcq_hq(dst), gcq_hq(src));
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_merge_tail(struct gcq_head *dst, struct gcq_head *src)
{
	gcq_merge(gcq_hq(dst)->q_prev, gcq_hq(src));
}
#else
__attribute__((nonnull)) static __inline void
gcq_merge(struct gcq *dst, struct gcq *src)
{
	struct gcq *dst_next, *src_prev, *src_next;
	GCQ_ASSERT(dst != src && dst->q_prev != src);

	if (gcq_onlist(src)) {
		dst_next = dst->q_next;
		src_prev = src->q_prev;
		src_next = src->q_next;

		dst_next->q_prev = src_prev;
		src_prev->q_next = dst_next;
		dst->q_next = src_next;
		src_next->q_prev = dst;
		gcq_init(src);
	}
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_merge_head(struct gcq_head *dst, struct gcq_head *src)
{
	gcq_merge(gcq_hq(dst), gcq_hq(src));
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_merge_tail(struct gcq_head *dst, struct gcq_head *src)
{
	gcq_merge(gcq_hq(dst)->q_prev, gcq_hq(src));
}
#endif

__attribute__((nonnull)) static __inline void
gcq_clear(struct gcq *q)
{
	struct gcq *nq, *next;
	nq=q;
	do {
		next = nq->q_next;
		gcq_init(nq);
		nq = next;
	} while (next != q);
}

__attribute__((nonnull, always_inline)) static __inline void
gcq_remove_all(struct gcq_head *head)
{
	gcq_clear(gcq_hq(head));
}

__attribute__((nonnull, always_inline)) static __inline struct gcq *
_gcq_next(struct gcq *current, struct gcq_head *head, struct gcq *start)
{
	struct gcq *q, *hq;
	hq = gcq_hq(head);
	q = current->q_next;
	if (hq != start && q == hq)
		q = hq->q_next;
	if (current != start)
		GCQ_ASSERT(gcq_onlist(current));
	return q;
}

__attribute__((nonnull, always_inline)) static __inline struct gcq *
_gcq_prev(struct gcq *current, struct gcq_head *head, struct gcq *start)
{
	struct gcq *q, *hq;
	hq = gcq_hq(head);
	q = current->q_prev;
	if (hq != start && q == hq)
		q = hq->q_prev;
	if (current != start)
		GCQ_ASSERT(gcq_onlist(current));
	return q;
}


#define GCQ_ITEM(q, type, name) 					\
    ((type *)(void *)((uint8_t *)gcq_q(q) - offsetof(type, name)))


#define _GCQ_GDQ(var, h, ptr, fn) (gcq_hq(h)->ptr != gcq_hq(h) ?	\
    (var = fn(gcq_hq(h)->ptr), true) : (var = NULL, false))
#define _GCQ_GDQ_TYPED(tvar, h, type, name, ptr, fn)			\
    (gcq_hq(h)->ptr != gcq_hq(h) ? (tvar = GCQ_ITEM(fn(gcq_hq(h)->ptr),	\
    type, name), true) : (tvar = NULL, false))
#define _GCQ_NP(var, current, head, start, np, fn)			\
    (np(current, head, start) != (start) ? 				\
    (var = fn(np(current, head, start)), true) : (var = NULL, false))
#define _GCQ_NP_TYPED(tvar, current, head, start, type, name, np, fn) 	\
    (np(current, head, start) != (start) ? 				\
    (tvar = GCQ_ITEM(fn(np(current, head, start)), type, name), true) :	\
    (tvar = NULL, false))

#define _GCQ_GDQ_COND(var, h, ptr, rem, cond)				\
    (gcq_hq(h)->ptr != gcq_hq(h) ? (var = gcq_hq(h)->ptr, 		\
    ((cond) ? (rem, true) : (var = NULL, false))) : 			\
    (var = NULL, false))
#define _GCQ_GDQ_COND_TYPED(tvar, h, type, name, ptr, rem, cond)  	\
    (gcq_hq(h)->ptr != gcq_hq(h) ? (tvar = GCQ_ITEM(gcq_hq(h)->ptr,	\
    type, name), ((cond) ? (rem, true) : (tvar = NULL, false))) : 	\
    (tvar = NULL, false))
#define _GCQ_NP_COND(var, current, head, start, np, rem, cond) 		\
    (np(current, head, start) != (start) ? 				\
    (var = fn(np(current, head, start)), ((cond) ? (rem), true) : 	\
    (var = NULL, false))) : (var = NULL, false))
#define _GCQ_NP_COND_TYPED(tvar, current, head, start, type, name, np, 	\
    rem, cond) (np(current, head, start) != (start) ? 			\
    (tvar = GCQ_ITEM(fn(np(current, head, start)), type, name), 	\
    ((cond) ? (rem, true) : (var = NULL, false))) : 			\
    (tvar = NULL, false))

#define GCQ_GOT_FIRST(var, h) _GCQ_GDQ(var, h, q_next, gcq_q)
#define GCQ_GOT_LAST(var, h) _GCQ_GDQ(var, h, q_prev, gcq_q)
#define GCQ_DEQUEUED_FIRST(var, h) _GCQ_GDQ(var, h, q_next, gcq_remove)
#define GCQ_DEQUEUED_LAST(var, h) _GCQ_GDQ(var, h, q_prev, gcq_remove)
#define GCQ_GOT_FIRST_TYPED(tvar, h, type, name)  			\
    _GCQ_GDQ_TYPED(tvar, h, type, name, q_next, gcq_q)
#define GCQ_GOT_LAST_TYPED(tvar, h, type, name)  			\
    _GCQ_GDQ_TYPED(tvar, h, type, name, q_prev, gcq_q)
#define GCQ_DEQUEUED_FIRST_TYPED(tvar, h, type, name)			\
    _GCQ_GDQ_TYPED(tvar, h, type, name, q_next, gcq_remove)
#define GCQ_DEQUEUED_LAST_TYPED(tvar, h, type, name)			\
    _GCQ_GDQ_TYPED(tvar, h, type, name, q_prev, gcq_remove)
#define GCQ_GOT_NEXT(var, current, head, start)				\
    _GCQ_NP(var, current, head, start, _gcq_next, gcq_q)
#define GCQ_GOT_PREV(var, current, head, start)				\
    _GCQ_NP(var, current, head, start, _gcq_prev, gcq_q)
#define GCQ_DEQUEUED_NEXT(var, current, head, start)			\
    _GCQ_NP(var, current, head, start, _gcq_next, gcq_remove)
#define GCQ_DEQUEUED_PREV(var, current, head, start)			\
    _GCQ_NP(var, current, head, start, _gcq_prev, gcq_remove)
#define GCQ_GOT_NEXT_TYPED(tvar, current, head, start, type, name)	\
    _GCQ_NP_TYPED(tvar, current, head, start, type, name,		\
    _gcq_next, gcq_q)
#define GCQ_GOT_PREV_TYPED(tvar, current, head, start, type, name)	\
    _GCQ_NP_TYPED(tvar, current, head, start, type, name,		\
    _gcq_prev, gcq_q)
#define GCQ_DEQUEUED_NEXT_TYPED(tvar, current, head, start, type, name)	\
    _GCQ_NP_TYPED(tvar, current, head, start, type, name,		\
    _gcq_next, gcq_remove)
#define GCQ_DEQUEUED_PREV_TYPED(tvar, current, head, start, type, name)	\
    _GCQ_NP_TYPED(tvar, current, head, start, type, name,		\
    _gcq_prev, gcq_remove)

#define GCQ_GOT_FIRST_COND(var, h, cond)				\
    _GCQ_GDQ_COND(var, h, q_next, ((void)0), cond)
#define GCQ_GOT_LAST_COND(var, h, cond) 				\
    _GCQ_GDQ_COND(var, h, q_prev, ((void)0), cond)
#define GCQ_DEQUEUED_FIRST_COND(var, h, cond) 				\
    _GCQ_GDQ_COND(var, h, q_next, gcq_remove(var), cond)
#define GCQ_DEQUEUED_LAST_COND(var, h, cond)				\
    _GCQ_GDQ_COND(var, h, q_prev, gcq_remove(var), cond)
#define GCQ_GOT_FIRST_COND_TYPED(tvar, h, type, name, cond)  		\
    _GCQ_GDQ_COND_TYPED(tvar, h, type, name, q_next, ((void)0), cond)
#define GCQ_GOT_LAST_COND_TYPED(tvar, h, type, name, cond)  		\
    _GCQ_GDQ_COND_TYPED(tvar, h, type, name, q_prev, ((void)0), cond)
#define GCQ_DEQUEUED_FIRST_COND_TYPED(tvar, h, type, name, cond)	\
    _GCQ_GDQ_COND_TYPED(tvar, h, type, name, q_next, 			\
    gcq_remove(&(tvar)->name), cond)
#define GCQ_DEQUEUED_LAST_COND_TYPED(tvar, h, type, name, cond)		\
    _GCQ_GDQ_COND_TYPED(tvar, h, type, name, q_prev, 			\
    gcq_remove(&(tvar)->name), cond)
#define GCQ_GOT_NEXT_COND(var, current, head, start, cond)		\
    _GCQ_NP_COND(var, current, head, start, _gcq_next, ((void)0), cond)
#define GCQ_GOT_PREV_COND(var, current, head, start, cond)		\
    _GCQ_NP_COND(var, current, head, start, _gcq_prev, ((void)0), cond)
#define GCQ_DEQUEUED_NEXT_COND(var, current, head, start, cond)		\
    _GCQ_NP_COND(var, current, head, start, _gcq_next, gcq_remove(var), \
    cond)
#define GCQ_DEQUEUED_PREV_COND(var, current, head, start, cond)		\
    _GCQ_NP_COND(var, current, head, start, _gcq_prev, gcq_remove(var), \
    cond)
#define GCQ_GOT_NEXT_COND_TYPED(tvar, current, head, start, type, name, \
    cond) _GCQ_NP_COND_TYPED(tvar, current, head, start, type, name,	\
    _gcq_next, ((void)0), cond)
#define GCQ_GOT_PREV_COND_TYPED(tvar, current, head, start, type, name, \
    cond) _GCQ_NP_COND_TYPED(tvar, current, head, start, type, name,	\
    _gcq_prev, ((void)0), cond)
#define GCQ_DEQUEUED_NEXT_COND_TYPED(tvar, current, head, start, type, 	\
    name, cond) _GCQ_NP_COND_TYPED(tvar, current, head, start, type, 	\
    name, _gcq_next, gcq_remove(&(tvar)->name), cond)
#define GCQ_DEQUEUED_PREV_COND_TYPED(tvar, current, head, start, type, 	\
    name, cond) _GCQ_NP_COND_TYPED(tvar, current, head, start, type, 	\
    name, _gcq_prev, gcq_remove(&(tvar)->name), cond)


#define _GCQ_FOREACH(var, h, tnull, item, ptr) 				\
    for ((var)=gcq_hq(h)->ptr; ((var) != gcq_hq(h) && 			\
    (GCQ_ASSERT(gcq_onlist(var)), item, true)) ||			\
    (tnull, false); (var)=(var)->ptr)
#define _GCQ_FOREACH_NVAR(var, nvar, h, tnull, item, ptr, ol, rem, ro) 	\
    for ((nvar)=gcq_hq(h)->ptr; (((var)=(nvar), (nvar) != gcq_hq(h)) &&	\
    (ol, (nvar)=(nvar)->ptr, rem, item, true)) || (tnull, false); ro)

#define GCQ_FOREACH(var, h)						\
    _GCQ_FOREACH(var, h, ((void)0), ((void)0), q_next)
#define GCQ_FOREACH_REV(var, h)						\
    _GCQ_FOREACH(var, h, ((void)0), ((void)0), q_prev)
#define GCQ_FOREACH_NVAR(var, nvar, h) 					\
    _GCQ_FOREACH_NVAR(var, nvar, h, ((void)0), ((void)0),		\
    q_next, GCQ_ASSERT(gcq_onlist(nvar)), ((void)0), ((void)0))
#define GCQ_FOREACH_NVAR_REV(var, nvar, h) 				\
    _GCQ_FOREACH_NVAR(var, nvar, h, ((void)0), ((void)0),		\
    q_prev, GCQ_ASSERT(gcq_onlist(nvar)), ((void)0), ((void)0))
#define GCQ_FOREACH_RO(var, nvar, h)					\
    _GCQ_FOREACH_NVAR(var, nvar, h, ((void)0), ((void)0),		\
    q_next, ((void)0), ((void)0), GCQ_ASSERT(gcq_linked(var, nvar)))
#define GCQ_FOREACH_RO_REV(var, nvar, h)				\
    _GCQ_FOREACH_NVAR(var, nvar, h, ((void)0), ((void)0),		\
    q_prev, ((void)0), ((void)0), GCQ_ASSERT(gcq_linked(nvar, var)))
#define GCQ_FOREACH_DEQUEUED(var, nvar, h)				\
    _GCQ_FOREACH_NVAR(var, nvar, h, ((void)0), ((void)0),		\
    q_next, GCQ_ASSERT(gcq_onlist(nvar)), gcq_remove(var), ((void)0)
#define GCQ_FOREACH_DEQUEUED_REV(var, nvar, h)				\
    _GCQ_FOREACH_NVAR(var, nvar, h, ((void)0), ((void)0),		\
    q_prev, GCQ_ASSERT(gcq_onlist(nvar)), gcq_remove(var), ((void)0)

#define GCQ_FOREACH_TYPED(var, h, tvar, type, name)			\
    _GCQ_FOREACH(var, h, (tvar)=NULL, (tvar)=GCQ_ITEM(var, type, name), \
    q_next)
#define GCQ_FOREACH_TYPED_REV(var, h, tvar, type, name)			\
    _GCQ_FOREACH(var, h, (tvar)=NULL, (tvar)=GCQ_ITEM(var, type, name), \
    q_prev)
#define GCQ_FOREACH_NVAR_TYPED(var, nvar, h, tvar, type, name)		\
    _GCQ_FOREACH_NVAR(var, nvar, h, (tvar)=NULL, 			\
    (tvar)=GCQ_ITEM(var, type, name),					\
    q_next, GCQ_ASSERT(gcq_onlist(nvar)), ((void)0), ((void)0))
#define GCQ_FOREACH_NVAR_REV_TYPED(var, nvar, h, tvar, type, name)	\
    _GCQ_FOREACH_NVAR(var, nvar, h, (tvar)=NULL, 			\
    (tvar)=GCQ_ITEM(var, type, name),					\
    q_prev, GCQ_ASSERT(gcq_onlist(nvar)), ((void)0), ((void)0))
#define GCQ_FOREACH_RO_TYPED(var, nvar, h, tvar, type, name)		\
    _GCQ_FOREACH_NVAR(var, nvar, h, (tvar)=NULL, 			\
    (tvar)=GCQ_ITEM(var, type, name),					\
    q_next, ((void)0), ((void)0), GCQ_ASSERT(gcq_lined(var, nvar)))
#define GCQ_FOREACH_RO_REV_TYPED(var, nvar, h, tvar, type, name)	\
    _GCQ_FOREACH_NVAR(var, nvar, h, (tvar)=NULL, 			\
    (tvar)=GCQ_ITEM(var, type, name),					\
    q_prev, ((void)0), ((void)0), GCQ_ASSERT(gcq_linked(nvar, var)))
#define GCQ_FOREACH_DEQUEUED_TYPED(var, nvar, h, tvar, type, name)	\
    _GCQ_FOREACH_NVAR(var, nvar, h, (tvar)=NULL, 			\
    (tvar)=GCQ_ITEM(var, type, name),					\
    q_next, GCQ_ASSERT(gcq_onlist(nvar)), gcq_remove(var), ((void)0))
#define GCQ_FOREACH_DEQUEUED_REV_TYPED(var, nvar, h, tvar, type, name)	\
    _GCQ_FOREACH_NVAR(var, nvar, h, (tvar)=NULL, 			\
    (tvar)=GCQ_ITEM(var, type, name),					\
    q_prev, GCQ_ASSERT(gcq_onlist(nvar)), gcq_remove(var), ((void)0))

#define _GCQ_COND(fe, cond) do { fe { if (cond) break; } } while (0)

#define GCQ_FIND(var, h, cond) _GCQ_COND(GCQ_FOREACH(var, h), cond)
#define GCQ_FIND_REV(var, h, cond) _GCQ_COND(GCQ_FOREACH_REV(var, h), cond)
#define GCQ_FIND_TYPED(var, h, tvar, type, name, cond) 			\
    _GCQ_COND(GCQ_FOREACH_TYPED(var, h, tvar, type, name), cond)
#define GCQ_FIND_TYPED_REV(var, h, tvar, type, name, cond) 		\
    _GCQ_COND(GCQ_FOREACH_REV_TYPED(var, h, tvar, type, name), cond)

#endif /* _GCQ_H */