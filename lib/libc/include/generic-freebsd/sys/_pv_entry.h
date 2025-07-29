/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 2003 Peter Wemm.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department and William Jolitz of UUNET Technologies Inc.
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
 */

#ifndef __SYS__PV_ENTRY_H__
#define	__SYS__PV_ENTRY_H__

#include <sys/param.h>

struct pmap;

/*
 * For each vm_page_t, there is a list of all currently valid virtual
 * mappings of that page.  An entry is a pv_entry_t, the list is pv_list.
 */
typedef struct pv_entry {
	vm_offset_t	pv_va;		/* virtual address for mapping */
	TAILQ_ENTRY(pv_entry)	pv_next;
} *pv_entry_t;

/*
 * pv_entries are allocated in chunks per-process.  This avoids the
 * need to track per-pmap assignments.  Each chunk is the size of a
 * single page.
 *
 * Chunks store a bitmap in pc_map[] to track which entries in the
 * bitmap are free (1) or used (0).  PC_FREEL is the value of the last
 * entry in the pc_map[] array when a chunk is completely free.  PC_FREEN
 * is the value of all the other entries in the pc_map[] array when a
 * chunk is completely free.
 */
#if PAGE_SIZE == 4 * 1024
#ifdef __LP64__
#define	_NPCPV	168
#define	_NPAD	0
#else
#define	_NPCPV	336
#define	_NPAD	0
#endif
#elif PAGE_SIZE == 16 * 1024
#ifdef __LP64__
#define	_NPCPV	677
#define	_NPAD	1
#endif
#endif

#ifndef _NPCPV
#error Unsupported page size
#endif

/* Support clang < 14 */
#ifndef __LONG_WIDTH__
#define	__LONG_WIDTH__	(__CHAR_BIT__ * __SIZEOF_LONG__)
#endif

#define	_NPCM		howmany(_NPCPV, __LONG_WIDTH__)
#define	PC_FREEN	~0ul
#define	PC_FREEL	((1ul << (_NPCPV % __LONG_WIDTH__)) - 1)

#define	PV_CHUNK_HEADER							\
	struct pmap		*pc_pmap;				\
	TAILQ_ENTRY(pv_chunk)	pc_list;				\
	unsigned long		pc_map[_NPCM];	/* bitmap; 1 = free */	\
	TAILQ_ENTRY(pv_chunk)	pc_lru;

struct pv_chunk_header {
	PV_CHUNK_HEADER
};

struct pv_chunk {
	PV_CHUNK_HEADER
	struct pv_entry		pc_pventry[_NPCPV];
	unsigned long		pc_pad[_NPAD];
};

_Static_assert(sizeof(struct pv_chunk) == PAGE_SIZE,
    "PV entry chunk size mismatch");

#ifdef _KERNEL
static __inline bool
pc_is_full(struct pv_chunk *pc)
{
	for (u_int i = 0; i < _NPCM; i++) {
		if (pc->pc_map[i] != 0)
			return (false);
	}
	return (true);
}

static __inline bool
pc_is_free(struct pv_chunk *pc)
{
	for (u_int i = 0; i < _NPCM - 1; i++) {
		if (pc->pc_map[i] != PC_FREEN)
			return (false);
	}
	return (pc->pc_map[_NPCM - 1] == PC_FREEL);
}

static __inline struct pv_chunk *
pv_to_chunk(pv_entry_t pv)
{
	return ((struct pv_chunk *)((uintptr_t)pv & ~(uintptr_t)PAGE_MASK));
}

#define PV_PMAP(pv) (pv_to_chunk(pv)->pc_pmap)
#endif

#endif /* !__SYS__PV_ENTRY_H__ */