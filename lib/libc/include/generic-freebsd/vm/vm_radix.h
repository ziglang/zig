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

#ifndef _VM_RADIX_H_
#define _VM_RADIX_H_

#include <vm/_vm_radix.h>

#ifdef _KERNEL
#include <sys/pctrie.h>
#include <vm/vm_page.h>
#include <vm/vm.h>

void		vm_radix_wait(void);
void		vm_radix_zinit(void);
void		*vm_radix_node_alloc(struct pctrie *ptree);
void		vm_radix_node_free(struct pctrie *ptree, void *node);
extern smr_t	vm_radix_smr;

static __inline void
vm_radix_init(struct vm_radix *rtree)
{
	pctrie_init(&rtree->rt_trie);
}

static __inline bool
vm_radix_is_empty(struct vm_radix *rtree)
{
	return (pctrie_is_empty(&rtree->rt_trie));
}

PCTRIE_DEFINE_SMR(VM_RADIX, vm_page, pindex, vm_radix_node_alloc,
    vm_radix_node_free, vm_radix_smr);

/*
 * Inserts the key-value pair into the trie, starting search from root.
 * Panics if the key already exists.
 */
static __inline int
vm_radix_insert(struct vm_radix *rtree, vm_page_t page)
{
	return (VM_RADIX_PCTRIE_INSERT(&rtree->rt_trie, page));
}

/*
 * Inserts the key-value pair into the trie, starting search from iterator.
 * Panics if the key already exists.
 */
static __inline int
vm_radix_iter_insert(struct pctrie_iter *pages, vm_page_t page)
{
	return (VM_RADIX_PCTRIE_ITER_INSERT(pages, page));
}

/*
 * Returns the value stored at the index assuming there is an external lock.
 *
 * If the index is not present, NULL is returned.
 */
static __inline vm_page_t
vm_radix_lookup(struct vm_radix *rtree, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_LOOKUP(&rtree->rt_trie, index));
}

/*
 * Returns the value stored at the index without requiring an external lock.
 *
 * If the index is not present, NULL is returned.
 */
static __inline vm_page_t
vm_radix_lookup_unlocked(struct vm_radix *rtree, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_LOOKUP_UNLOCKED(&rtree->rt_trie, index));
}

/*
 * Returns the number of contiguous, non-NULL pages read into the ma[]
 * array, without requiring an external lock.
 */
static __inline int
vm_radix_lookup_range_unlocked(struct vm_radix *rtree, vm_pindex_t index,
    vm_page_t ma[], int count)
{
	return (VM_RADIX_PCTRIE_LOOKUP_RANGE_UNLOCKED(&rtree->rt_trie, index,
	    ma, count));
}

/*
 * Returns the number of contiguous, non-NULL pages read into the ma[]
 * array, without requiring an external lock.
 */
static __inline int
vm_radix_iter_lookup_range(struct pctrie_iter *pages, vm_pindex_t index,
    vm_page_t ma[], int count)
{
	return (VM_RADIX_PCTRIE_ITER_LOOKUP_RANGE(pages, index, ma, count));
}

/*
 * Initialize an iterator for vm_radix.
 */
static __inline void
vm_radix_iter_init(struct pctrie_iter *pages, struct vm_radix *rtree)
{
	pctrie_iter_init(pages, &rtree->rt_trie);
}

/*
 * Initialize an iterator for vm_radix.
 */
static __inline void
vm_radix_iter_limit_init(struct pctrie_iter *pages, struct vm_radix *rtree,
    vm_pindex_t limit)
{
	pctrie_iter_limit_init(pages, &rtree->rt_trie, limit);
}

/*
 * Returns the value stored at the index.
 * Requires that access be externally synchronized by a lock.
 *
 * If the index is not present, NULL is returned.
 */
static __inline vm_page_t
vm_radix_iter_lookup(struct pctrie_iter *pages, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_ITER_LOOKUP(pages, index));
}

/*
 * Returns the value stored 'stride' steps beyond the current position.
 * Requires that access be externally synchronized by a lock.
 *
 * If the index is not present, NULL is returned.
 */
static __inline vm_page_t
vm_radix_iter_stride(struct pctrie_iter *pages, int stride)
{
	return (VM_RADIX_PCTRIE_ITER_STRIDE(pages, stride));
}

/*
 * Returns the page with the least pindex that is greater than or equal to the
 * specified pindex, or NULL if there are no such pages.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_lookup_ge(struct vm_radix *rtree, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_LOOKUP_GE(&rtree->rt_trie, index));
}

/*
 * Returns the page with the greatest pindex that is less than or equal to the
 * specified pindex, or NULL if there are no such pages.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_lookup_le(struct vm_radix *rtree, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_LOOKUP_LE(&rtree->rt_trie, index));
}

/*
 * Remove the specified index from the trie, and return the value stored at
 * that index.  If the index is not present, return NULL.
 */
static __inline vm_page_t
vm_radix_remove(struct vm_radix *rtree, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_REMOVE_LOOKUP(&rtree->rt_trie, index));
}

/*
 * Remove the current page from the trie.
 */
static __inline void
vm_radix_iter_remove(struct pctrie_iter *pages)
{
	VM_RADIX_PCTRIE_ITER_REMOVE(pages);
}
 
/*
 * Reclaim all the interior nodes of the trie, and invoke the callback
 * on all the pages, in order.
 */
static __inline void
vm_radix_reclaim_callback(struct vm_radix *rtree,
    void (*page_cb)(vm_page_t, void *), void *arg)
{
	VM_RADIX_PCTRIE_RECLAIM_CALLBACK(&rtree->rt_trie, page_cb, arg);
}

/*
 * Initialize an iterator pointing to the page with the least pindex that is
 * greater than or equal to the specified pindex, or NULL if there are no such
 * pages.  Return the page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_lookup_ge(struct pctrie_iter *pages, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_ITER_LOOKUP_GE(pages, index));
}

/*
 * Update the iterator to point to the page with the least pindex that is 'jump'
 * or more greater than or equal to the current pindex, or NULL if there are no
 * such pages.  Return the page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_jump(struct pctrie_iter *pages, vm_pindex_t jump)
{
	return (VM_RADIX_PCTRIE_ITER_JUMP_GE(pages, jump));
}

/*
 * Update the iterator to point to the page with the least pindex that is one or
 * more greater than the current pindex, or NULL if there are no such pages.
 * Return the page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_step(struct pctrie_iter *pages)
{
	return (VM_RADIX_PCTRIE_ITER_STEP_GE(pages));
}

/*
 * Iterate over each non-NULL page from page 'start' to the end of the object.
 */
#define VM_RADIX_FOREACH_FROM(m, pages, start)				\
	for (m = vm_radix_iter_lookup_ge(pages, start); m != NULL;	\
	    m = vm_radix_iter_step(pages))

/*
 * Iterate over each non-NULL page from the beginning to the end of the object.
 */
#define VM_RADIX_FOREACH(m, pages) VM_RADIX_FOREACH_FROM(m, pages, 0)

/*
 * Initialize an iterator pointing to the page with the greatest pindex that is
 * less than or equal to the specified pindex, or NULL if there are no such
 * pages.  Return the page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_lookup_le(struct pctrie_iter *pages, vm_pindex_t index)
{
	return (VM_RADIX_PCTRIE_ITER_LOOKUP_LE(pages, index));
}

/*
 * Initialize an iterator pointing to the page with the greatest pindex that is
 * less than to the specified pindex, or NULL if there are no such
 * pages.  Return the page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_lookup_lt(struct pctrie_iter *pages, vm_pindex_t index)
{
	return (index == 0 ? NULL : vm_radix_iter_lookup_le(pages, index - 1));
}

/*
 * Update the iterator to point to the page with the pindex that is one greater
 * than the current pindex, or NULL if there is no such page.  Return the page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_next(struct pctrie_iter *pages)
{
	return (VM_RADIX_PCTRIE_ITER_NEXT(pages));
}

/*
 * Iterate over consecutive non-NULL pages from position 'start' to first NULL
 * page.
 */
#define VM_RADIX_FORALL_FROM(m, pages, start)				\
	for (m = vm_radix_iter_lookup(pages, start); m != NULL;		\
	    m = vm_radix_iter_next(pages))

/*
 * Iterate over consecutive non-NULL pages from the beginning to first NULL
 * page.
 */
#define VM_RADIX_FORALL(m, pages) VM_RADIX_FORALL_FROM(m, pages, 0)

/*
 * Update the iterator to point to the page with the pindex that is one less
 * than the current pindex, or NULL if there is no such page.  Return the page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_prev(struct pctrie_iter *pages)
{
	return (VM_RADIX_PCTRIE_ITER_PREV(pages));
}

/*
 * Return the current page.
 *
 * Requires that access be externally synchronized by a lock.
 */
static __inline vm_page_t
vm_radix_iter_page(struct pctrie_iter *pages)
{
	return (VM_RADIX_PCTRIE_ITER_VALUE(pages));
}

/*
 * Replace an existing page in the trie with another one.
 * Panics if there is not an old page in the trie at the new page's index.
 */
static __inline vm_page_t
vm_radix_replace(struct vm_radix *rtree, vm_page_t newpage)
{
	return (VM_RADIX_PCTRIE_REPLACE(&rtree->rt_trie, newpage));
}

#endif /* _KERNEL */
#endif /* !_VM_RADIX_H_ */