/*	$NetBSD: pmap_motorola.h,v 1.37 2021/09/19 10:34:09 andvar Exp $	*/

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
 *	@(#)pmap.h	8.1 (Berkeley) 6/10/93
 */

/* 
 * Copyright (c) 1987 Carnegie-Mellon University
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)pmap.h	8.1 (Berkeley) 6/10/93
 */

#ifndef	_M68K_PMAP_MOTOROLA_H_
#define	_M68K_PMAP_MOTOROLA_H_

#ifdef _KERNEL_OPT
#include "opt_m68k_arch.h"
#endif

#include <machine/cpu.h>
#include <machine/pte.h>

/*
 * Pmap stuff
 */
struct pmap {
	pt_entry_t		*pm_ptab;	/* KVA of page table */
	st_entry_t		*pm_stab;	/* KVA of segment table */
	u_int			pm_stfree;	/* 040: free lev2 blocks */
	st_entry_t		*pm_stpa;	/* 040: ST phys addr */
	uint16_t		pm_sref;	/* segment table ref count */
	u_int			pm_count;	/* pmap reference count */
	struct pmap_statistics	pm_stats;	/* pmap statistics */
	int			pm_ptpages;	/* more stats: PT pages */
};

/*
 * MMU specific segment values
 *
 * We are using following segment layout in m68k pmap_motorola.c:
 * 68020/030 4KB/page: l1,l2,page    == 10,10,12	(%tc = 0x82c0aa00)
 * 68020/030 8KB/page: l1,l2,page    ==  8,11,13	(%tc = 0x82d08b00)
 * 68040/060 4KB/page: l1,l2,l3,page == 7,7,6,12	(%tc = 0x8000)
 * 68040/060 8KB/page: l1,l2,l3,page == 7,7,5,13	(%tc = 0xc000)
 *
 * 68020/030 l2 size is chosen per NPTEPG, a number of page table entries
 * per page, to use one whole page for PTEs per one segment table entry,
 * and maybe also because 68020 HP MMU machines use simlar structures.
 *
 * 68040/060 layout is defined by hardware design and not configurable,
 * as defined in <m68k/pte_motorola.h>.
 *
 * Even on 68040/060, we still appropriate 2-level ste-pte pmap structures
 * for 68020/030 (derived from 4.4BSD/hp300) to handle 040's 3-level MMU.
 * TIA_SIZE and TIB_SIZE are used to represent such pmap structures and
 * they are also referred on 040/060.
 *
 * NBSEG and SEGOFSET are used to check l2 STE of the specified VA,
 * so they have different values between 020/030 and 040/060.
 */
							/*  8KB /  4KB	*/
#define TIB_SHIFT	(PG_SHIFT - 2)			/*   11 /   10	*/
#define TIB_SIZE	(1U << TIB_SHIFT)		/* 2048 / 1024	*/
#define TIA_SHIFT	(32 - TIB_SHIFT - PG_SHIFT)	/*    8 /   10	*/
#define TIA_SIZE	(1U << TIA_SHIFT)		/*  256 / 1024	*/

#define SEGSHIFT	(TIB_SHIFT + PG_SHIFT)		/*   24 /   22	*/

#define NBSEG30		(1U << SEGSHIFT)
#define NBSEG40		(1U << SG4_SHIFT2)

#if   ( defined(M68020) ||  defined(M68030)) &&	\
      (!defined(M68040) && !defined(M68060))
#define NBSEG		NBSEG30
#elif ( defined(M68040) ||  defined(M68060)) &&	\
      (!defined(M68020) && !defined(M68030))
#define NBSEG		NBSEG40
#else
#define NBSEG		((mmutype == MMU_68040) ? NBSEG40 : NBSEG30)
#endif

#define SEGOFSET	(NBSEG - 1)	/* byte offset into segment */ 

#define	m68k_round_seg(x)	((((vaddr_t)(x)) + SEGOFSET) & ~SEGOFSET)
#define	m68k_trunc_seg(x)	((vaddr_t)(x) & ~SEGOFSET)
#define	m68k_seg_offset(x)	((vaddr_t)(x) & SEGOFSET)

/*
 * On the 040, we keep track of which level 2 blocks are already in use
 * with the pm_stfree mask.  Bits are arranged from LSB (block 0) to MSB
 * (block 31).  For convenience, the level 1 table is considered to be
 * block 0.
 *
 * MAX[KU]L2SIZE control how many pages of level 2 descriptors are allowed
 * for the kernel and users.
 * 16 or 8 implies only the initial "segment table" page is used,
 * i.e. it means PAGE_SIZE / (SG4_LEV1SIZE * sizeof(st_entry_t)).
 * WARNING: don't change MAXUL2SIZE unless you can allocate
 * physically contiguous pages for the ST in pmap_motorola.c!
 */
#define MAXKL2SIZE	32
#if PAGE_SIZE == 8192	/* NBPG / (SG4_LEV1SIZE * sizeof(st_entry_t)) */
#define MAXUL2SIZE	16
#else
#define MAXUL2SIZE	8
#endif
#define l2tobm(n)	(1U << (n))
#define bmtol2(n)	(ffs(n) - 1)

/*
 * Macros for speed
 */
#define	PMAP_ACTIVATE(pmap, loadhw)					\
{									\
	if ((loadhw))							\
		loadustp(m68k_btop((paddr_t)(pmap)->pm_stpa));		\
}

/*
 * For each struct vm_page, there is a list of all currently valid virtual
 * mappings of that page.  An entry is a pv_entry, the list is pv_table.
 */
struct pv_entry {
	struct pv_entry	*pv_next;	/* next pv_entry */
	struct pmap	*pv_pmap;	/* pmap where mapping lies */
	vaddr_t		pv_va;		/* virtual address for mapping */
	st_entry_t	*pv_ptste;	/* non-zero if VA maps a PT page */
	struct pmap	*pv_ptpmap;	/* if pv_ptste, pmap for PT page */
};

#define	active_pmap(pm) \
	((pm) == pmap_kernel() || (pm) == curproc->p_vmspace->vm_map.pmap)
#define	active_user_pmap(pm) \
	(curproc && \
	 (pm) != pmap_kernel() && (pm) == curproc->p_vmspace->vm_map.pmap)

extern struct pv_header	*pv_table;	/* array of entries, one per page */

#define	pmap_resident_count(pmap)	((pmap)->pm_stats.resident_count)
#define	pmap_wired_count(pmap)		((pmap)->pm_stats.wired_count)

#define	pmap_update(pmap)		__nothing	/* nothing (yet) */

static __inline bool
pmap_remove_all(struct pmap *pmap)
{
	/* Nothing. */
	return false;
}

extern paddr_t		Sysseg_pa;
extern st_entry_t	*Sysseg;
extern pt_entry_t	*Sysmap, *Sysptmap;
#define	SYSMAP_VA	VM_MAX_KERNEL_ADDRESS
extern vsize_t		Sysptsize;
extern vsize_t		mem_size;
extern vaddr_t		virtual_avail, virtual_end;
extern u_int		protection_codes[];
#if defined(M68040) || defined(M68060)
extern u_int		protostfree;
#endif
#ifdef CACHE_HAVE_VAC
extern u_int		pmap_aliasmask;
#endif

extern char		*vmmap;		/* map for mem, dumps, etc. */
extern void		*CADDR1, *CADDR2;
extern void		*msgbufaddr;

/* for lwp0 uarea initialization after MMU enabled */
extern vaddr_t		lwp0uarea;
void	pmap_bootstrap_finalize(void);

vaddr_t	pmap_map(vaddr_t, paddr_t, paddr_t, int);
void	pmap_procwr(struct proc *, vaddr_t, size_t);
#define	PMAP_NEED_PROCWR

#ifdef CACHE_HAVE_VAC
void	pmap_prefer(vaddr_t, vaddr_t *);
#define	PMAP_PREFER(foff, vap, sz, td)	pmap_prefer((foff), (vap))
#endif

void	_pmap_set_page_cacheable(struct pmap *, vaddr_t);
void	_pmap_set_page_cacheinhibit(struct pmap *, vaddr_t);
int	_pmap_page_is_cacheable(struct pmap *, vaddr_t);

#endif /* !_M68K_PMAP_MOTOROLA_H_ */