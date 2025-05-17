/*	$NetBSD: uvm_anon.h,v 1.32 2020/03/20 19:08:54 ad Exp $	*/

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
 */

#ifndef _UVM_UVM_ANON_H_
#define _UVM_UVM_ANON_H_

/*
 * uvm_anon.h
 */

#if defined(_KERNEL_OPT)
#include "opt_vmswap.h"
#endif

/*
 * anonymous memory management
 *
 * anonymous virtual memory is short term virtual memory that goes away
 * when the processes referencing it go away.    an anonymous page of
 * virtual memory is described by the following data structure:
 */

struct vm_anon {
	krwlock_t		*an_lock;	/* Lock for an_ref */
	uintptr_t		an_ref;		/* Reference count [an_lock] */
	struct vm_page		*an_page;	/* If in RAM [an_lock] */
#if defined(VMSWAP) || 1 /* XXX libkvm */
	/*
	 * Drum swap slot # (if != 0) [an_lock.  also, it is ok to read
	 * an_swslot if we hold an_page PG_BUSY].
	 */
	int			an_swslot;
#endif
};

/*
 * for active vm_anon's the data can be in one of the following state:
 * [1] in a vm_page with no backing store allocated yet, [2] in a vm_page
 * with backing store allocated, or [3] paged out to backing store
 * (no vm_page).
 *
 * for pageout in case [2]: if the page has been modified then we must
 * flush it out to backing store, otherwise we can just dump the
 * vm_page.
 */

/*
 * anons are grouped together in anonymous memory maps, or amaps.
 * amaps are defined in uvm_amap.h.
 */

/*
 * processes reference anonymous virtual memory maps with an anonymous
 * reference structure:
 */

struct vm_aref {
	int ar_pageoff;			/* page offset into amap we start */
	struct vm_amap *ar_amap;	/* pointer to amap */
};

/*
 * the offset field indicates which part of the amap we are referencing.
 * locked by vm_map lock.
 */

#ifdef _KERNEL

/*
 * prototypes
 */

struct vm_anon *uvm_analloc(void);
void uvm_anfree(struct vm_anon *);
void uvm_anon_init(void);
struct vm_page *uvm_anon_lockloanpg(struct vm_anon *);
#if defined(VMSWAP)
void uvm_anon_dropswap(struct vm_anon *);
#else /* defined(VMSWAP) */
#define	uvm_anon_dropswap(a)	/* nothing */
#endif /* defined(VMSWAP) */
void uvm_anon_release(struct vm_anon *);
bool uvm_anon_pagein(struct vm_amap *, struct vm_anon *);
#endif /* _KERNEL */

#endif /* _UVM_UVM_ANON_H_ */