/*	$NetBSD: pmap_pv.h,v 1.17 2020/03/17 22:29:19 ad Exp $	*/

/*-
 * Copyright (c)2008 YAMAMOTO Takashi,
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

#ifndef _X86_PMAP_PV_H_
#define	_X86_PMAP_PV_H_

#include <sys/mutex.h>
#include <sys/queue.h>
#include <sys/rbtree.h>

struct vm_page;
struct pmap_page;

/*
 * structures to track P->V mapping
 *
 * this file is intended to be minimum as it's included by <machine/vmparam.h>.
 */

/*
 * pv_pte: describe a pte
 */

struct pv_pte {
	struct vm_page *pte_ptp;	/* PTP; NULL for pmap_kernel() */
	vaddr_t pte_va;			/* VA */
};

/*
 * pv_entry: plug pv_pte into lists.  32 bytes on i386, 64 on amd64.
 */

struct pv_entry {
	struct pv_pte pve_pte;		/* should be the first member */
	LIST_ENTRY(pv_entry) pve_list;	/* on pmap_page::pp_pvlist */
	rb_node_t pve_rb;		/* red-black tree node */
	struct pmap_page *pve_pp;	/* backpointer to mapped page */
};
#define	pve_next	pve_list.le_next

/*
 * pmap_page: a structure which is embedded in each vm_page.
 */

struct pmap_page {
	union {
		/* PTPs */
		rb_tree_t rb;

		/* PTPs, when being freed */
		LIST_ENTRY(vm_page) link;

		/* Non-PTPs (i.e. normal pages) */
		struct {
			struct pv_pte pte;
			LIST_HEAD(, pv_entry) pvlist;
			uint8_t attrs;
		} s;
	} pp_u;
	kmutex_t	pp_lock;
#define	pp_rb		pp_u.rb
#define	pp_link		pp_u.link
#define	pp_pte		pp_u.s.pte
#define pp_pvlist	pp_u.s.pvlist
#define	pp_attrs	pp_u.s.attrs
};

#define PP_ATTRS_D	0x01	/* Dirty */
#define PP_ATTRS_A	0x02	/* Accessed */
#define PP_ATTRS_W	0x04	/* Writable */

#define	PMAP_PAGE_INIT(pp) \
do { \
	LIST_INIT(&(pp)->pp_pvlist); \
	mutex_init(&(pp)->pp_lock, MUTEX_NODEBUG, IPL_VM); \
} while (/* CONSTCOND */ 0);

#endif /* !_X86_PMAP_PV_H_ */