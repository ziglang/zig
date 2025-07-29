/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2002-2006 Rice University
 * Copyright (c) 2007 Alan L. Cox <alc@cs.rice.edu>
 * All rights reserved.
 *
 * This software was developed for the FreeBSD Project by Alan L. Cox,
 * Olivier Crameri, Peter Druschel, Sitaram Iyer, and Juan Navarro.
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
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
 * HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 * WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	__VM_PHYS_H_
#define	__VM_PHYS_H_

#include <machine/vmparam.h>

#ifndef VM_NFREEORDER_MAX
#define	VM_NFREEORDER_MAX	VM_NFREEORDER
#endif

struct vm_page;
#ifndef VM_PAGE_HAVE_PGLIST
TAILQ_HEAD(pglist, vm_page);
#define VM_PAGE_HAVE_PGLIST
#endif

struct vm_freelist {
	struct pglist pl;
	int lcnt;
};

struct vm_phys_seg {
	vm_paddr_t	start;
	vm_paddr_t	end;
	vm_page_t	first_page;
#if VM_NRESERVLEVEL > 0
	vm_reserv_t	first_reserv;
#endif
#ifdef __aarch64__
	void		*md_first;
#endif
	int		domain;
	struct vm_freelist (*free_queues)[VM_NFREEPOOL][VM_NFREEORDER_MAX];
};

extern struct vm_phys_seg vm_phys_segs[];
extern int vm_phys_nsegs;

#endif /* !__VM_PHYS_H_ */