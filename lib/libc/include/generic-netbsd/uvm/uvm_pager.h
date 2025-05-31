/*	$NetBSD: uvm_pager.h,v 1.49 2020/05/19 22:22:15 ad Exp $	*/

/*
 * Copyright (c) 1997 Charles D. Cranor and Washington University.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * from: Id: uvm_pager.h,v 1.1.2.14 1998/01/13 19:00:50 chuck Exp
 */

/*
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
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
 *	@(#)vm_pager.h	8.5 (Berkeley) 7/7/94
 */

/*
 * Copyright (c) 1990 University of Utah.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
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
 *	@(#)vm_pager.h	8.5 (Berkeley) 7/7/94
 */

#ifndef _UVM_UVM_PAGER_H_
#define _UVM_UVM_PAGER_H_

/*
 * uvm_pager.h
 */

/*
 * forward structure declarations
 */

struct uvm_faultinfo;
struct uvm_object;

/*
 * pager ops
 */

struct uvm_pagerops {

	/* init pager */
	void	(*pgo_init)(void);

	/* add reference to obj */
	void	(*pgo_reference)(struct uvm_object *);

	/* drop reference to obj */
	void	(*pgo_detach)(struct uvm_object *);

	/* special non-standard fault processing */
	int	(*pgo_fault)(struct uvm_faultinfo *, vaddr_t, struct vm_page **,
			     int, int, vm_prot_t, int);

	/* get/read pages */
	int	(*pgo_get)(struct uvm_object *, voff_t, struct vm_page **,
			   int *, int, vm_prot_t, int, int);

	/* put/write pages */
	int	(*pgo_put)(struct uvm_object *, voff_t, voff_t, int);

	/* mark object dirty */
	void	(*pgo_markdirty)(struct uvm_object *);
};

/* pager flags [mostly for flush] */

#define PGO_CLEANIT	0x001	/* write dirty pages to backing store */
#define PGO_SYNCIO	0x002	/* use sync I/O */
#define PGO_DEACTIVATE	0x004	/* deactivate flushed pages */
#define PGO_FREE	0x008	/* free flushed pages */
/* if PGO_FREE is not set then the pages stay where they are. */

#define PGO_ALLPAGES	0x010	/* flush whole object [put] */
#define PGO_JOURNALLOCKED 0x020	/* journal is already locked [get/put] */
#define PGO_LOCKED	0x040	/* fault data structures are locked [get] */
#define PGO_BUSYFAIL	0x080	/* fail if a page is busy [put] */
#define PGO_OVERWRITE	0x200	/* pages will be overwritten before unlocked */
#define PGO_PASTEOF	0x400	/* allow allocation of pages past EOF */
#define PGO_NOBLOCKALLOC 0x800	/* backing block allocation is not needed */
#define PGO_NOTIMESTAMP 0x1000	/* don't mark object accessed/modified */
#define PGO_RECLAIM	0x2000	/* object is being reclaimed */
#define PGO_GLOCKHELD	0x4000	/* genfs_node's lock is already held */
#define PGO_LAZY	0x8000	/* equivalent of MNT_LAZY / FSYNC_LAZY */

/* page we are not interested in getting */
#define PGO_DONTCARE ((struct vm_page *) -1L)	/* [get only] */

#ifdef _KERNEL

/*
 * prototypes
 */

void	uvm_pager_init(void);
void	uvm_pager_realloc_emerg(void);
struct vm_page *uvm_pageratop(vaddr_t);
vaddr_t	uvm_pagermapin(struct vm_page **, int, int);
void	uvm_pagermapout(vaddr_t, int);

extern size_t pager_map_size;

/* Flags to uvm_pagermapin() */
#define	UVMPAGER_MAPIN_WAITOK	0x01	/* it's okay to wait */
#define	UVMPAGER_MAPIN_READ	0x02	/* device -> host */
#define	UVMPAGER_MAPIN_WRITE	0x00	/* host -> device (pseudo flag) */

#endif /* _KERNEL */

#endif /* _UVM_UVM_PAGER_H_ */