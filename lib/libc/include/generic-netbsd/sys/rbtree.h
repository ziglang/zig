/*	$NetBSD: rbtree.h,v 1.5.30.2 2024/10/14 04:47:55 martin Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas <matt@3am-software.com>.
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

#ifndef _SYS_RBTREE_H_
#define	_SYS_RBTREE_H_

#include <sys/types.h>
#include <sys/queue.h>
#include <sys/endian.h>

#if !defined(_KERNEL) && !defined(_STANDALONE) && defined(RBDEBUG)
#include <stdbool.h>
#endif

__BEGIN_DECLS

typedef struct rb_node {
	struct rb_node *rb_nodes[2];
#define	RB_DIR_LEFT		0
#define	RB_DIR_RIGHT		1
#define	RB_DIR_OTHER		1
#define	rb_left			rb_nodes[RB_DIR_LEFT]
#define	rb_right		rb_nodes[RB_DIR_RIGHT]

	/*
	 * rb_info contains the two flags and the parent back pointer.
	 * We put the two flags in the low two bits since we know that
	 * rb_node will have an alignment of 4 or 8 bytes.
	 */
	uintptr_t rb_info;
#define	RB_FLAG_POSITION	(uintptr_t)0x2
#define	RB_FLAG_RED		(uintptr_t)0x1
#define	RB_FLAG_MASK		(RB_FLAG_POSITION|RB_FLAG_RED)
#define	RB_FATHER(rb) \
    ((struct rb_node *)((rb)->rb_info & ~RB_FLAG_MASK))
#define	RB_SET_FATHER(rb, father) \
    ((void)((rb)->rb_info = (uintptr_t)(father)|((rb)->rb_info & RB_FLAG_MASK)))

#define	RB_SENTINEL_P(rb)	((rb) == NULL)
#define	RB_LEFT_SENTINEL_P(rb)	RB_SENTINEL_P((rb)->rb_left)
#define	RB_RIGHT_SENTINEL_P(rb)	RB_SENTINEL_P((rb)->rb_right)
#define	RB_FATHER_SENTINEL_P(rb) RB_SENTINEL_P(RB_FATHER((rb)))
#define	RB_CHILDLESS_P(rb) \
    (RB_SENTINEL_P(rb) || (RB_LEFT_SENTINEL_P(rb) && RB_RIGHT_SENTINEL_P(rb)))
#define	RB_TWOCHILDREN_P(rb) \
    (!RB_SENTINEL_P(rb) && !RB_LEFT_SENTINEL_P(rb) && !RB_RIGHT_SENTINEL_P(rb))

#define	RB_POSITION(rb)	\
    (((rb)->rb_info & RB_FLAG_POSITION) ? RB_DIR_RIGHT : RB_DIR_LEFT)
#define	RB_RIGHT_P(rb)		(RB_POSITION(rb) == RB_DIR_RIGHT)
#define	RB_LEFT_P(rb)		(RB_POSITION(rb) == RB_DIR_LEFT)
#define	RB_RED_P(rb) 		(!RB_SENTINEL_P(rb) && ((rb)->rb_info & RB_FLAG_RED) != 0)
#define	RB_BLACK_P(rb) 		(RB_SENTINEL_P(rb) || ((rb)->rb_info & RB_FLAG_RED) == 0)
#define	RB_MARK_RED(rb) 	((void)((rb)->rb_info |= RB_FLAG_RED))
#define	RB_MARK_BLACK(rb) 	((void)((rb)->rb_info &= ~RB_FLAG_RED))
#define	RB_INVERT_COLOR(rb) 	((void)((rb)->rb_info ^= RB_FLAG_RED))
#define	RB_ROOT_P(rbt, rb)	((rbt)->rbt_root == (rb))
#define	RB_SET_POSITION(rb, position) \
    ((void)((position) ? ((rb)->rb_info |= RB_FLAG_POSITION) : \
    ((rb)->rb_info &= ~RB_FLAG_POSITION)))
#define	RB_ZERO_PROPERTIES(rb)	((void)((rb)->rb_info &= ~RB_FLAG_MASK))
#define	RB_COPY_PROPERTIES(dst, src) \
    ((void)((dst)->rb_info ^= ((dst)->rb_info ^ (src)->rb_info) & RB_FLAG_MASK))
#define RB_SWAP_PROPERTIES(a, b) do { \
    uintptr_t xorinfo = ((a)->rb_info ^ (b)->rb_info) & RB_FLAG_MASK; \
    (a)->rb_info ^= xorinfo; \
    (b)->rb_info ^= xorinfo; \
  } while (/*CONSTCOND*/ 0)
#ifdef RBDEBUG
	TAILQ_ENTRY(rb_node) rb_link;
#endif
} rb_node_t;

#define RB_TREE_MIN(T) rb_tree_iterate((T), NULL, RB_DIR_LEFT)
#define RB_TREE_MAX(T) rb_tree_iterate((T), NULL, RB_DIR_RIGHT)
#define RB_TREE_NEXT(T, N) rb_tree_iterate((T), (N), RB_DIR_RIGHT)
#define RB_TREE_PREV(T, N) rb_tree_iterate((T), (N), RB_DIR_LEFT)
#define RB_TREE_FOREACH(N, T) \
    for ((N) = RB_TREE_MIN(T); (N); (N) = RB_TREE_NEXT((T), (N)))
#define RB_TREE_FOREACH_REVERSE(N, T) \
    for ((N) = RB_TREE_MAX(T); (N); (N) = RB_TREE_PREV((T), (N)))
#define RB_TREE_FOREACH_SAFE(N, T, S) \
    for ((N) = RB_TREE_MIN(T); \
        (N) && ((S) = RB_TREE_NEXT((T), (N)), 1); \
        (N) = (S))
#define RB_TREE_FOREACH_REVERSE_SAFE(N, T, S) \
    for ((N) = RB_TREE_MAX(T); \
        (N) && ((S) = RB_TREE_PREV((T), (N)), 1); \
        (N) = (S))

#ifdef RBDEBUG
TAILQ_HEAD(rb_node_qh, rb_node);

#define	RB_TAILQ_REMOVE(a, b, c)		TAILQ_REMOVE(a, b, c)
#define	RB_TAILQ_INIT(a)			TAILQ_INIT(a)
#define	RB_TAILQ_INSERT_HEAD(a, b, c)		TAILQ_INSERT_HEAD(a, b, c)
#define	RB_TAILQ_INSERT_BEFORE(a, b, c)		TAILQ_INSERT_BEFORE(a, b, c)
#define	RB_TAILQ_INSERT_AFTER(a, b, c, d)	TAILQ_INSERT_AFTER(a, b, c, d)
#else
#define	RB_TAILQ_REMOVE(a, b, c)		do { } while (/*CONSTCOND*/0)
#define	RB_TAILQ_INIT(a)			do { } while (/*CONSTCOND*/0)
#define	RB_TAILQ_INSERT_HEAD(a, b, c)		do { } while (/*CONSTCOND*/0)
#define	RB_TAILQ_INSERT_BEFORE(a, b, c)		do { } while (/*CONSTCOND*/0)
#define	RB_TAILQ_INSERT_AFTER(a, b, c, d)	do { } while (/*CONSTCOND*/0)
#endif /* RBDEBUG */

/*
 * rbto_compare_nodes_fn:
 *	return a positive value if the first node > the second node.
 *	return a negative value if the first node < the second node.
 *	return 0 if they are considered same.
 *
 * rbto_compare_key_fn:
 *	return a positive value if the node > the key.
 *	return a negative value if the node < the key.
 *	return 0 if they are considered same.
 */

typedef signed int (*rbto_compare_nodes_fn)(void *, const void *, const void *);
typedef signed int (*rbto_compare_key_fn)(void *, const void *, const void *);

typedef struct {
	rbto_compare_nodes_fn rbto_compare_nodes;
	rbto_compare_key_fn rbto_compare_key;
	size_t rbto_node_offset;
	void *rbto_context;
} rb_tree_ops_t;

typedef struct rb_tree {
	struct rb_node *rbt_root;
	const rb_tree_ops_t *rbt_ops;
	struct rb_node *rbt_minmax[2];
#ifdef RBDEBUG
	struct rb_node_qh rbt_nodes;
#endif
#ifdef RBSTATS
	unsigned int rbt_count;
	unsigned int rbt_insertions;
	unsigned int rbt_removals;
	unsigned int rbt_insertion_rebalance_calls;
	unsigned int rbt_insertion_rebalance_passes;
	unsigned int rbt_removal_rebalance_calls;
	unsigned int rbt_removal_rebalance_passes;
#endif
} rb_tree_t;

#ifdef RBSTATS
#define	RBSTAT_INC(v)	((void)((v)++))
#define	RBSTAT_DEC(v)	((void)((v)--))
#else
#define	RBSTAT_INC(v)	do { } while (/*CONSTCOND*/0)
#define	RBSTAT_DEC(v)	do { } while (/*CONSTCOND*/0)
#endif

void	rb_tree_init(rb_tree_t *, const rb_tree_ops_t *);
void *	rb_tree_insert_node(rb_tree_t *, void *);
void *	rb_tree_find_node(rb_tree_t *, const void *);
void *	rb_tree_find_node_geq(rb_tree_t *, const void *);
void *	rb_tree_find_node_leq(rb_tree_t *, const void *);
void	rb_tree_remove_node(rb_tree_t *, void *);
void *	rb_tree_iterate(rb_tree_t *, void *, const unsigned int);
#ifdef RBDEBUG
void	rb_tree_check(const rb_tree_t *, bool);
#endif
#ifdef RBSTATS
void	rb_tree_depths(const rb_tree_t *, size_t *);
#endif

__END_DECLS

#endif	/* _SYS_RBTREE_H_*/