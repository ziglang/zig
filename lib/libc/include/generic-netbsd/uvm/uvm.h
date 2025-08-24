/*	$NetBSD: uvm.h,v 1.77 2020/05/17 15:11:57 ad Exp $	*/

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
 * from: Id: uvm.h,v 1.1.2.14 1998/02/02 20:07:19 chuck Exp
 */

#ifndef _UVM_UVM_H_
#define _UVM_UVM_H_

#if defined(_KERNEL_OPT)
#include "opt_lockdebug.h"
#include "opt_multiprocessor.h"
#include "opt_uvmhist.h"
#include "opt_uvm_page_trkown.h"
#endif

#include <uvm/uvm_extern.h>

#ifdef _KERNEL
#include <uvm/uvm_stat.h>
#endif

/*
 * pull in prototypes
 */

#include <uvm/uvm_amap.h>
#include <uvm/uvm_aobj.h>
#include <uvm/uvm_fault.h>
#include <uvm/uvm_glue.h>
#include <uvm/uvm_km.h>
#include <uvm/uvm_loan.h>
#include <uvm/uvm_map.h>
#include <uvm/uvm_object.h>
#include <uvm/uvm_page.h>
#include <uvm/uvm_pager.h>
#include <uvm/uvm_pdaemon.h>
#include <uvm/uvm_swap.h>

#ifdef _KERNEL

#include <uvm/uvm_physseg.h>
#include <sys/rndsource.h>

/*
 * pull in VM_NFREELIST
 */
#include <machine/vmparam.h>

struct workqueue;
struct pgflcache;

/*
 * per-cpu data
 */

struct uvm_cpu {
	/* allocator */
	struct pgflcache *pgflcache[VM_NFREELIST];/* cpu-local cached pages */
	void		*pgflcachemem;		/* pointer to allocated mem */
	size_t		pgflcachememsz;		/* size of allocated memory */
	u_int		pgflcolor;		/* next color to allocate */
	u_int		pgflbucket;		/* where to send our pages */

	/* entropy */
	krndsource_t 	rs;			/* entropy source */

	/* uvmpdpol: queue of intended page status changes. */
	struct vm_page	**pdq;			/* queue entries */
	u_int		pdqhead;		/* current queue head */
	u_int		pdqtail;		/* maximum number entries */
	int		pdqtime;		/* last time queue cleared */
};

/*
 * uvm structure (vm global state: collected in one structure for ease
 * of reference...)
 */

struct uvm {
	/* vm_page related parameters */

		/* vm_page queues */
	struct pgfreelist page_free[VM_NFREELIST]; /* unallocated pages */
	u_int	bucketcount;
	bool	page_init_done;		/* true if uvm_page_init() finished */

		/* page daemon trigger */
	int pagedaemon;			/* daemon sleeps on this */
	struct lwp *pagedaemon_lwp;	/* daemon's lid */
};

/*
 * kernel object: to support anonymous pageable kernel memory
 */
extern struct uvm_object *uvm_kernel_object;

/*
 * locks (made globals for lockstat).
 */

extern kmutex_t uvm_kentry_lock;

#endif /* _KERNEL */

/*
 * vm_map_entry etype bits:
 */

#define UVM_ET_OBJ		0x01	/* it is a uvm_object */
#define UVM_ET_SUBMAP		0x02	/* it is a vm_map submap */
#define UVM_ET_COPYONWRITE 	0x04	/* copy_on_write */
#define UVM_ET_NEEDSCOPY	0x08	/* needs_copy */

#define UVM_ET_ISOBJ(E)		(((E)->etype & UVM_ET_OBJ) != 0)
#define UVM_ET_ISSUBMAP(E)	(((E)->etype & UVM_ET_SUBMAP) != 0)
#define UVM_ET_ISCOPYONWRITE(E)	(((E)->etype & UVM_ET_COPYONWRITE) != 0)
#define UVM_ET_ISNEEDSCOPY(E)	(((E)->etype & UVM_ET_NEEDSCOPY) != 0)

#ifdef _KERNEL

/*
 * holds all the internal UVM data
 */
extern struct uvm uvm;

/*
 * historys
 */

#ifdef UVMHIST
UVMHIST_DECL(maphist);
UVMHIST_DECL(pdhist);
UVMHIST_DECL(ubchist);
UVMHIST_DECL(loanhist);
#endif

extern struct evcnt uvm_ra_total;
extern struct evcnt uvm_ra_hit;
extern struct evcnt uvm_ra_miss;

/*
 * UVM_UNLOCK_AND_WAIT: atomic unlock+wait... wrapper around the
 * interlocked tsleep() function.
 */

#define	UVM_UNLOCK_AND_WAIT(event, slock, intr, msg, timo)		\
do {									\
	(void) mtsleep(event, PVM | PNORELOCK | (intr ? PCATCH : 0),	\
	    msg, timo, slock);						\
} while (/*CONSTCOND*/ 0)

void uvm_kick_pdaemon(void);

/*
 * UVM_PAGE_OWN: track page ownership (only if UVM_PAGE_TRKOWN)
 */

#if defined(UVM_PAGE_TRKOWN)
#define UVM_PAGE_OWN(PG, TAG) uvm_page_own(PG, TAG)
#else
#define UVM_PAGE_OWN(PG, TAG) /* nothing */
#endif /* UVM_PAGE_TRKOWN */

#include <uvm/uvm_fault_i.h>

#endif /* _KERNEL */

#endif /* _UVM_UVM_H_ */