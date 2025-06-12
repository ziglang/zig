/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2013 EMC Corp.
 * Copyright (c) 2011 Jeffrey Roberson <jeff@freebsd.org>
 * Copyright (c) 2008 Mayur Shardul <mayur.shardul@gmail.com>
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

#ifndef _SYS_PCTRIE_H_
#define _SYS_PCTRIE_H_

#include <sys/_pctrie.h>
#include <sys/_smr.h>

#ifdef _KERNEL

#define	PCTRIE_DEFINE_SMR(name, type, field, allocfn, freefn, smr)	\
    PCTRIE_DEFINE(name, type, field, allocfn, freefn)			\
									\
static __inline struct type *						\
name##_PCTRIE_LOOKUP_UNLOCKED(struct pctrie *ptree, uint64_t key)	\
{									\
									\
	return name##_PCTRIE_VAL2PTR(pctrie_lookup_unlocked(ptree,	\
	    key, (smr)));						\
}									\

#define	PCTRIE_DEFINE(name, type, field, allocfn, freefn)		\
									\
CTASSERT(sizeof(((struct type *)0)->field) == sizeof(uint64_t));	\
/*									\
 * XXX This assert protects flag bits, it does not enforce natural	\
 * alignment.  32bit architectures do not naturally align 64bit fields.	\
 */									\
CTASSERT((__offsetof(struct type, field) & (sizeof(uint32_t) - 1)) == 0); \
									\
static __inline struct type *						\
name##_PCTRIE_VAL2PTR(uint64_t *val)					\
{									\
									\
	if (val == NULL)						\
		return (NULL);						\
	return (struct type *)						\
	    ((uintptr_t)val - __offsetof(struct type, field));		\
}									\
									\
static __inline uint64_t *						\
name##_PCTRIE_PTR2VAL(struct type *ptr)					\
{									\
									\
	return &ptr->field;						\
}									\
									\
static __inline int							\
name##_PCTRIE_INSERT(struct pctrie *ptree, struct type *ptr)		\
{									\
	struct pctrie_node *parent;					\
	void *parentp;							\
	uint64_t *val = name##_PCTRIE_PTR2VAL(ptr);			\
									\
	parentp = pctrie_insert_lookup(ptree, val);			\
	if (parentp == NULL)						\
		return (0);						\
	parent = allocfn(ptree);					\
	if (parent == NULL)						\
		return (ENOMEM);					\
	pctrie_insert_node(parentp, parent, val);			\
	return (0);							\
}									\
									\
static __inline __unused struct type *					\
name##_PCTRIE_LOOKUP(struct pctrie *ptree, uint64_t key)		\
{									\
									\
	return name##_PCTRIE_VAL2PTR(pctrie_lookup(ptree, key));	\
}									\
									\
static __inline __unused struct type *					\
name##_PCTRIE_LOOKUP_LE(struct pctrie *ptree, uint64_t key)		\
{									\
									\
	return name##_PCTRIE_VAL2PTR(pctrie_lookup_le(ptree, key));	\
}									\
									\
static __inline __unused struct type *					\
name##_PCTRIE_LOOKUP_GE(struct pctrie *ptree, uint64_t key)		\
{									\
									\
	return name##_PCTRIE_VAL2PTR(pctrie_lookup_ge(ptree, key));	\
}									\
									\
static __inline __unused void						\
name##_PCTRIE_RECLAIM(struct pctrie *ptree)				\
{									\
	struct pctrie_node *freenode, *node;				\
									\
	for (freenode = pctrie_reclaim_begin(&node, ptree);		\
	    freenode != NULL;						\
	    freenode = pctrie_reclaim_resume(&node))			\
		freefn(ptree, freenode);				\
}									\
									\
static __inline __unused struct type *					\
name##_PCTRIE_REPLACE(struct pctrie *ptree, struct type *ptr)		\
{									\
									\
	return name##_PCTRIE_VAL2PTR(					\
	    pctrie_replace(ptree, name##_PCTRIE_PTR2VAL(ptr)));		\
}									\
									\
static __inline __unused void						\
name##_PCTRIE_REMOVE(struct pctrie *ptree, uint64_t key)		\
{									\
	uint64_t *val;							\
	struct pctrie_node *freenode;					\
									\
	val = pctrie_remove_lookup(ptree, key, &freenode);		\
	if (val == NULL)						\
		panic("%s: key not found", __func__);			\
	if (freenode != NULL)						\
		freefn(ptree, freenode);				\
}									\
									\
static __inline __unused struct type *					\
name##_PCTRIE_REMOVE_LOOKUP(struct pctrie *ptree, uint64_t key)		\
{									\
	uint64_t *val;							\
	struct pctrie_node *freenode;					\
									\
	val = pctrie_remove_lookup(ptree, key, &freenode);		\
	if (freenode != NULL)						\
		freefn(ptree, freenode);				\
	return name##_PCTRIE_VAL2PTR(val);				\
}

void		*pctrie_insert_lookup(struct pctrie *ptree, uint64_t *val);
void		pctrie_insert_node(void *parentp,
		    struct pctrie_node *parent, uint64_t *val);
uint64_t	*pctrie_lookup(struct pctrie *ptree, uint64_t key);
uint64_t	*pctrie_lookup_ge(struct pctrie *ptree, uint64_t key);
uint64_t	*pctrie_lookup_le(struct pctrie *ptree, uint64_t key);
uint64_t	*pctrie_lookup_unlocked(struct pctrie *ptree, uint64_t key,
		    smr_t smr);
struct pctrie_node *pctrie_reclaim_begin(struct pctrie_node **pnode,
		    struct pctrie *ptree);
struct pctrie_node *pctrie_reclaim_resume(struct pctrie_node **pnode);
uint64_t	*pctrie_remove_lookup(struct pctrie *ptree, uint64_t index,
		    struct pctrie_node **killnode);
uint64_t	*pctrie_replace(struct pctrie *ptree, uint64_t *newval);
size_t		pctrie_node_size(void);
int		pctrie_zone_init(void *mem, int size, int flags);

/*
 * Each search path in the trie terminates at a leaf, which is a pointer to a
 * value marked with a set 1-bit.  A leaf may be associated with a null pointer
 * to indicate no value there.
 */
#define	PCTRIE_ISLEAF	0x1
#define PCTRIE_NULL (struct pctrie_node *)PCTRIE_ISLEAF

static __inline void
pctrie_init(struct pctrie *ptree)
{
	ptree->pt_root = PCTRIE_NULL;
}

static __inline bool
pctrie_is_empty(struct pctrie *ptree)
{
	return (ptree->pt_root == PCTRIE_NULL);
}

/* Set of all flag bits stored in node pointers. */
#define	PCTRIE_FLAGS	(PCTRIE_ISLEAF)
/* Minimum align parameter for uma_zcreate. */
#define	PCTRIE_PAD	PCTRIE_FLAGS

/*
 * These widths should allow the pointers to a node's children to fit within
 * a single cache line.  The extra levels from a narrow width should not be
 * a problem thanks to path compression.
 */
#ifdef __LP64__
#define	PCTRIE_WIDTH	4
#else
#define	PCTRIE_WIDTH	3
#endif

#define	PCTRIE_COUNT	(1 << PCTRIE_WIDTH)

#endif /* _KERNEL */
#endif /* !_SYS_PCTRIE_H_ */