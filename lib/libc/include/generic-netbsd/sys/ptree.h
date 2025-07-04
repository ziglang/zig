/*	$NetBSD: ptree.h,v 1.8 2012/10/06 22:15:09 matt Exp $	*/

/*-
 * Copyright (c) 2008 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas <matt@3am-software.com>
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

#ifndef _SYS_PTREE_H_
#define _SYS_PTREE_H_

#if !defined(_KERNEL) && !defined(_STANDALONE)
#include <stdbool.h>
#include <stdint.h>
#endif

typedef enum {
	PT_DESCENDING=-1,
	PT_ASCENDING=1
} pt_direction_t;

typedef unsigned int pt_slot_t;
typedef unsigned int pt_bitoff_t;
typedef unsigned int pt_bitlen_t;

typedef struct pt_node {
	uintptr_t ptn_slots[2];		/* must be first */
#define	PT_SLOT_LEFT			0u
#define	PT_SLOT_RIGHT			1u
#ifdef _PT_PRIVATE
#define	PT_SLOT_ROOT			0u
#define	PT_SLOT_OTHER			1u
#define	PT_SLOT_ODDMAN			1u
#define	PT_TYPE_LEAF			((uintptr_t)0x00000000u)
#define	PT_TYPE_BRANCH			((uintptr_t)0x00000001u)
#define	PT_TYPE_MASK			((uintptr_t)0x00000001u)
#endif /* _PT_PRIVATE */

	uint32_t ptn_nodedata;
#ifdef _PT_PRIVATE
#define	PTN_LEAF_POSITION_BITS		8u
#define	PTN_LEAF_POSITION_SHIFT		0u
#define	PTN_BRANCH_POSITION_BITS	8u
#define	PTN_BRANCH_POSITION_SHIFT	8u
#ifndef PTNOMASK
#define	PTN_MASK_BITLEN_BITS		15u
#define	PTN_MASK_BITLEN_SHIFT		16u
#define	PTN_MASK_FLAG			0x80000000u
#endif
#endif /* _PT_PRIVATE */

	uint32_t ptn_branchdata;
#ifdef _PT_PRIVATE
#define	PTN_BRANCH_BITOFF_BITS		15u
#define	PTN_BRANCH_BITOFF_SHIFT		0u
#define	PTN_BRANCH_BITLEN_BITS		8u
#define	PTN_BRANCH_BITLEN_SHIFT		16u
#if 0
#define	PTN_ORIENTATION_BITS		1u
#define	PTN_ORIENTATION_SHIFT		30u
#endif
#define	PTN_BRANCH_UNUSED		0x3f000000u
#define	PTN_XBRANCH_FLAG		0x80000000u
#endif /* _PT_PRIVATE */
} pt_node_t;

#ifdef _PT_PRIVATE
#define	PT_NODE(node)		((pt_node_t *)(node & ~PT_TYPE_MASK))
#define	PT_TYPE(node)		((node) & PT_TYPE_MASK)
#define	PT_NULL			0
#define	PT_NULL_P(node)		((node) == PT_NULL)
#define	PT_LEAF_P(node)		(PT_TYPE(node) == PT_TYPE_LEAF)
#define	PT_BRANCH_P(node)	(PT_TYPE(node) == PT_TYPE_BRANCH)
#define	PTN__TYPELESS(ptn)	(((uintptr_t)ptn) & ~PT_TYPE_MASK)
#define	PTN_LEAF(ptn)		(PTN__TYPELESS(ptn) | PT_TYPE_LEAF)
#define	PTN_BRANCH(ptn)		(PTN__TYPELESS(ptn) | PT_TYPE_BRANCH)

#ifndef PTNOMASK
#define	PTN_MARK_MASK(ptn)	((ptn)->ptn_nodedata |= PTN_MASK_FLAG)
#define	PTN_ISMASK_P(ptn)	(((ptn)->ptn_nodedata & PTN_MASK_FLAG) != 0)
#endif
#define	PTN_MARK_XBRANCH(ptn)	((ptn)->ptn_branchdata |= PTN_XBRANCH_FLAG)
#define	PTN_ISXBRANCH_P(ptn)	(((ptn)->ptn_branchdata & PTN_XBRANCH_FLAG) != 0)
#define	PTN_ISROOT_P(pt, ptn)	((ptn) == &(pt)->pt_rootnode)

#define	PTN_BRANCH_SLOT(ptn,slot)	((ptn)->ptn_slots[slot])
#define	PTN_BRANCH_ROOT_SLOT(ptn)	((ptn)->ptn_slots[PT_SLOT_ROOT])
#define	PTN_BRANCH_ODDMAN_SLOT(ptn)	((ptn)->ptn_slots[PT_SLOT_ODDMAN])
#define	PTN_COPY_BRANCH_SLOTS(dst,src)	\
	((dst)->ptn_slots[PT_SLOT_LEFT ] = (src)->ptn_slots[PT_SLOT_LEFT ], \
	 (dst)->ptn_slots[PT_SLOT_RIGHT] = (src)->ptn_slots[PT_SLOT_RIGHT])
#define	PTN_ISSLOTVALID_P(ptn,slot)	((slot) < (1 << PTN_BRANCH_BITLEN(pt)))

#define	PT__MASK(n)		((1 << n ## _BITS) - 1)  
#define	PT__SHIFT(n)		(n ## _SHIFT)
#define	PTN__EXTRACT(field, b) \
	(((field) >> PT__SHIFT(b)) & PT__MASK(b))
#define	PTN__INSERT2(field, v, shift, mask) \
	((field) = ((field) & ~((mask) << (shift))) | ((v) << (shift)))
#define	PTN__INSERT(field, b, v) \
	PTN__INSERT2(field, v, PT__SHIFT(b), PT__MASK(b))

#define	PTN_BRANCH_BITOFF(ptn)		\
	PTN__EXTRACT((ptn)->ptn_branchdata, PTN_BRANCH_BITOFF)
#define	PTN_BRANCH_BITLEN(ptn)		\
	PTN__EXTRACT((ptn)->ptn_branchdata, PTN_BRANCH_BITLEN)
#define	PTN_SET_BRANCH_BITOFF(ptn,bitoff) \
	PTN__INSERT((ptn)->ptn_branchdata, PTN_BRANCH_BITOFF, bitoff)
#define PTN_SET_BRANCH_BITLEN(ptn,bitlen) \
	PTN__INSERT((ptn)->ptn_branchdata, PTN_BRANCH_BITLEN, bitlen)

#define	PTN_LEAF_POSITION(ptn)		\
	PTN__EXTRACT((ptn)->ptn_nodedata, PTN_LEAF_POSITION)
#define	PTN_BRANCH_POSITION(ptn)	\
	PTN__EXTRACT((ptn)->ptn_nodedata, PTN_BRANCH_POSITION)
#define	PTN_SET_LEAF_POSITION(ptn,slot) \
	PTN__INSERT((ptn)->ptn_nodedata, PTN_LEAF_POSITION, slot)
#define PTN_SET_BRANCH_POSITION(ptn,slot) \
	PTN__INSERT((ptn)->ptn_nodedata, PTN_BRANCH_POSITION, slot)

#ifndef PTNOMASK
#define	PTN_MASK_BITLEN(ptn)		\
	PTN__EXTRACT((ptn)->ptn_nodedata, PTN_MASK_BITLEN)
#define PTN_SET_MASK_BITLEN(ptn,masklen) \
	PTN__INSERT((ptn)->ptn_nodedata, PTN_MASK_BITLEN, masklen)
#endif

#if 0
#define	PTN_ORIENTATION(ptn)	\
	PTN__EXTRACT((ptn)->ptn_branchdata, PTN_ORIENTATION)
#define	PTN_SET_ORIENTATION(ptn,slot) \
	PTN__INSERT((ptn)->ptn_branchdata, PTN_ORIENTATION, slot)
#endif
#endif /* _PT_PRIVATE */

typedef struct pt_tree_ops {
	bool (*ptto_matchnode)(const void *, const void *,
		pt_bitoff_t, pt_bitoff_t *, pt_slot_t *, void *);
	bool (*ptto_matchkey)(const void *, const void *,
		pt_bitoff_t, pt_bitlen_t, void *);
	pt_slot_t (*ptto_testnode)(const void *,
		pt_bitoff_t, pt_bitlen_t, void *);
	pt_slot_t (*ptto_testkey)(const void *,
		pt_bitoff_t, pt_bitlen_t, void *);
} pt_tree_ops_t;

typedef struct pt_tree {
	pt_node_t pt_rootnode;
#define	pt_root			pt_rootnode.ptn_slots[PT_SLOT_ROOT]
#define	pt_oddman		pt_rootnode.ptn_slots[PT_SLOT_ODDMAN]
	const pt_tree_ops_t *pt_ops;
	size_t pt_node_offset;
	size_t pt_key_offset;
	void *pt_context;
	uintptr_t pt_spare[3];
} pt_tree_t;

#define	PT_FILTER_MASK		0x00000001	/* node is a mask */
typedef bool (*pt_filter_t)(void *, const void *, int);

void	ptree_init(pt_tree_t *, const pt_tree_ops_t *, void *, size_t, size_t);
bool	ptree_insert_node(pt_tree_t *, void *);
bool	ptree_insert_mask_node(pt_tree_t *, void *, pt_bitlen_t);
bool	ptree_mask_node_p(pt_tree_t *, const void *, pt_bitlen_t *);
void *	ptree_find_filtered_node(pt_tree_t *, const void *, pt_filter_t, void *);
#define	ptree_find_node(pt,key)	\
	ptree_find_filtered_node((pt), (key), NULL, NULL)
void	ptree_remove_node(pt_tree_t *, void *);
void *	ptree_iterate(pt_tree_t *, const void *, pt_direction_t);

#endif /* _SYS_PTREE_H_ */