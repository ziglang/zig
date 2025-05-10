/*-
 * Copyright (c) 1991 Regents of the University of California.
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

#ifdef __arm__
#include <arm/pmap.h>
#else /* !__arm__ */

#ifndef _MACHINE_PMAP_H_
#define	_MACHINE_PMAP_H_

#include <machine/pte.h>

#ifndef LOCORE

#include <sys/queue.h>
#include <sys/_lock.h>
#include <sys/_mutex.h>
#include <sys/_pv_entry.h>

#include <vm/_vm_radix.h>

#ifdef _KERNEL

#define	vtophys(va)	pmap_kextract((vm_offset_t)(va))

#endif

#define	pmap_page_get_memattr(m)	((m)->md.pv_memattr)
#define	pmap_page_is_write_mapped(m)	(((m)->a.flags & PGA_WRITEABLE) != 0)
void pmap_page_set_memattr(vm_page_t m, vm_memattr_t ma);

/*
 * Pmap stuff
 */

struct md_page {
	TAILQ_HEAD(,pv_entry)	pv_list;
	int			pv_gen;
	vm_memattr_t		pv_memattr;
};

enum pmap_stage {
	PM_INVALID,
	PM_STAGE1,
	PM_STAGE2,
};

struct pmap {
	struct mtx		pm_mtx;
	struct pmap_statistics	pm_stats;	/* pmap statistics */
	uint64_t		pm_ttbr;
	vm_paddr_t		pm_l0_paddr;
	pd_entry_t		*pm_l0;
	TAILQ_HEAD(,pv_chunk)	pm_pvchunk;	/* list of mappings in pmap */
	struct vm_radix		pm_root;	/* spare page table pages */
	long			pm_cookie;	/* encodes the pmap's ASID */
	struct asid_set		*pm_asid_set;	/* The ASID/VMID set to use */
	enum pmap_stage		pm_stage;
	int			pm_levels;
	uint64_t		pm_reserved[4];
};
typedef struct pmap *pmap_t;

struct thread;

#ifdef _KERNEL
extern struct pmap	kernel_pmap_store;
#define	kernel_pmap	(&kernel_pmap_store)
#define	pmap_kernel()	kernel_pmap

#define	PMAP_ASSERT_LOCKED(pmap) \
				mtx_assert(&(pmap)->pm_mtx, MA_OWNED)
#define	PMAP_LOCK(pmap)		mtx_lock(&(pmap)->pm_mtx)
#define	PMAP_LOCK_ASSERT(pmap, type) \
				mtx_assert(&(pmap)->pm_mtx, (type))
#define	PMAP_LOCK_DESTROY(pmap)	mtx_destroy(&(pmap)->pm_mtx)
#define	PMAP_LOCK_INIT(pmap)	mtx_init(&(pmap)->pm_mtx, "pmap", \
				    NULL, MTX_DEF | MTX_DUPOK)
#define	PMAP_OWNED(pmap)	mtx_owned(&(pmap)->pm_mtx)
#define	PMAP_MTX(pmap)		(&(pmap)->pm_mtx)
#define	PMAP_TRYLOCK(pmap)	mtx_trylock(&(pmap)->pm_mtx)
#define	PMAP_UNLOCK(pmap)	mtx_unlock(&(pmap)->pm_mtx)

#define	ASID_RESERVED_FOR_PID_0	0
#define	ASID_RESERVED_FOR_EFI	1
#define	ASID_FIRST_AVAILABLE	(ASID_RESERVED_FOR_EFI + 1)
#define	ASID_TO_OPERAND(asid)	({					\
	KASSERT((asid) != -1, ("invalid ASID"));			\
	(uint64_t)(asid) << TTBR_ASID_SHIFT;			\
})

#define	PMAP_WANT_ACTIVE_CPUS_NAIVE

extern vm_offset_t virtual_avail;
extern vm_offset_t virtual_end;

/*
 * Macros to test if a mapping is mappable with an L1 Section mapping
 * or an L2 Large Page mapping.
 */
#define	L1_MAPPABLE_P(va, pa, size)					\
	((((va) | (pa)) & L1_OFFSET) == 0 && (size) >= L1_SIZE)

#define	pmap_vm_page_alloc_check(m)

void	pmap_activate_vm(pmap_t);
void	pmap_bootstrap(vm_size_t);
int	pmap_change_attr(vm_offset_t va, vm_size_t size, int mode);
int	pmap_change_prot(vm_offset_t va, vm_size_t size, vm_prot_t prot);
void	pmap_kenter(vm_offset_t sva, vm_size_t size, vm_paddr_t pa, int mode);
void	pmap_kenter_device(vm_offset_t, vm_size_t, vm_paddr_t);
bool	pmap_klookup(vm_offset_t va, vm_paddr_t *pa);
vm_paddr_t pmap_kextract(vm_offset_t va);
void	pmap_kremove(vm_offset_t);
void	pmap_kremove_device(vm_offset_t, vm_size_t);
void	*pmap_mapdev_attr(vm_paddr_t pa, vm_size_t size, vm_memattr_t ma);
bool	pmap_page_is_mapped(vm_page_t m);
int	pmap_pinit_stage(pmap_t, enum pmap_stage, int);
bool	pmap_ps_enabled(pmap_t pmap);
uint64_t pmap_to_ttbr0(pmap_t pmap);
void	pmap_disable_promotion(vm_offset_t sva, vm_size_t size);
void	pmap_map_delete(pmap_t, vm_offset_t, vm_offset_t);

void	*pmap_mapdev(vm_paddr_t, vm_size_t);
void	*pmap_mapbios(vm_paddr_t, vm_size_t);
void	pmap_unmapdev(void *, vm_size_t);
void	pmap_unmapbios(void *, vm_size_t);

bool	pmap_map_io_transient(vm_page_t *, vm_offset_t *, int, bool);
void	pmap_unmap_io_transient(vm_page_t *, vm_offset_t *, int, bool);

bool	pmap_get_tables(pmap_t, vm_offset_t, pd_entry_t **, pd_entry_t **,
    pd_entry_t **, pt_entry_t **);

int	pmap_fault(pmap_t, uint64_t, uint64_t);

struct pcb *pmap_switch(struct thread *);

extern void (*pmap_clean_stage2_tlbi)(void);
extern void (*pmap_invalidate_vpipt_icache)(void);
extern void (*pmap_stage2_invalidate_range)(uint64_t, vm_offset_t, vm_offset_t,
    bool);
extern void (*pmap_stage2_invalidate_all)(uint64_t);

static inline int
pmap_vmspace_copy(pmap_t dst_pmap __unused, pmap_t src_pmap __unused)
{

	return (0);
}

#if defined(KASAN) || defined(KMSAN)
struct arm64_bootparams;

void	pmap_bootstrap_san(void);
void	pmap_san_enter(vm_offset_t);
#endif

#endif	/* _KERNEL */

#endif	/* !LOCORE */

#endif	/* !_MACHINE_PMAP_H_ */

#endif /* !__arm__ */