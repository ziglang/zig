/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2005 Peter Grehan
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

#ifndef _MACHINE_MMUVAR_H_
#define _MACHINE_MMUVAR_H_

typedef	void	(*pmap_bootstrap_t)(vm_offset_t, vm_offset_t);
typedef	void	(*pmap_cpu_bootstrap_t)(int);
typedef	void	(*pmap_kenter_t)(vm_offset_t, vm_paddr_t pa);
typedef	void	(*pmap_kenter_attr_t)(vm_offset_t, vm_paddr_t, vm_memattr_t);
typedef	void	(*pmap_kremove_t)(vm_offset_t);
typedef	void	*(*pmap_mapdev_t)(vm_paddr_t, vm_size_t);
typedef	void	*(*pmap_mapdev_attr_t)(vm_paddr_t, vm_size_t, vm_memattr_t);
typedef	void	(*pmap_unmapdev_t)(void *, vm_size_t);
typedef	void	(*pmap_page_set_memattr_t)(vm_page_t, vm_memattr_t);
typedef	int	(*pmap_change_attr_t)(vm_offset_t, vm_size_t, vm_memattr_t);
typedef	int	(*pmap_map_user_ptr_t)(pmap_t, volatile const void *,
 		    void **, size_t, size_t *);
typedef	int	(*pmap_decode_kernel_ptr_t)(vm_offset_t, int *, vm_offset_t *);
typedef	vm_paddr_t	(*pmap_kextract_t)(vm_offset_t);
typedef	int	(*pmap_dev_direct_mapped_t)(vm_paddr_t, vm_size_t);

typedef	void	(*pmap_page_array_startup_t)(long);
typedef	void	(*pmap_advise_t)(pmap_t, vm_offset_t, vm_offset_t, int);
typedef	void	(*pmap_clear_modify_t)(vm_page_t);
typedef	void	(*pmap_remove_write_t)(vm_page_t);
typedef	void	(*pmap_copy_t)(pmap_t, pmap_t, vm_offset_t, vm_size_t, vm_offset_t);
typedef	void	(*pmap_copy_page_t)(vm_page_t, vm_page_t);
typedef	void	(*pmap_copy_pages_t)(vm_page_t *, vm_offset_t,
		    vm_page_t *, vm_offset_t, int);
typedef	int	(*pmap_enter_t)(pmap_t, vm_offset_t, vm_page_t, vm_prot_t,
		    u_int, int8_t);
typedef	void	(*pmap_enter_object_t)(pmap_t, vm_offset_t, vm_offset_t,
		    vm_page_t, vm_prot_t);
typedef	void	(*pmap_enter_quick_t)(pmap_t, vm_offset_t, vm_page_t, vm_prot_t);
typedef	vm_paddr_t	(*pmap_extract_t)(pmap_t, vm_offset_t);
typedef	vm_page_t	(*pmap_extract_and_hold_t)(pmap_t, vm_offset_t, vm_prot_t);
typedef	void	(*pmap_growkernel_t)(vm_offset_t);
typedef	void	(*pmap_init_t)(void);
typedef	boolean_t	(*pmap_is_modified_t)(vm_page_t);
typedef	boolean_t	(*pmap_is_prefaultable_t)(pmap_t, vm_offset_t);
typedef	boolean_t	(*pmap_is_referenced_t)(vm_page_t);
typedef	int	(*pmap_ts_referenced_t)(vm_page_t);
typedef	vm_offset_t	(*pmap_map_t)(vm_offset_t *, vm_paddr_t, vm_paddr_t, int);
typedef	void	(*pmap_object_init_pt_t)(pmap_t, vm_offset_t, vm_object_t,
		    vm_pindex_t, vm_size_t);
typedef	boolean_t	(*pmap_page_exists_quick_t)(pmap_t, vm_page_t);
typedef	boolean_t	(*pmap_page_is_mapped_t)(vm_page_t);
typedef	void	(*pmap_page_init_t)(vm_page_t);
typedef	int	(*pmap_page_wired_mappings_t)(vm_page_t);
typedef	void	(*pmap_pinit0_t)(pmap_t);
typedef	void	(*pmap_protect_t)(pmap_t, vm_offset_t, vm_offset_t, vm_prot_t);
typedef	void	(*pmap_qenter_t)(vm_offset_t, vm_page_t *, int);
typedef	void	(*pmap_qremove_t)(vm_offset_t, int);
typedef	void	(*pmap_release_t)(pmap_t);
typedef	void	(*pmap_remove_t)(pmap_t, vm_offset_t, vm_offset_t);
typedef	void	(*pmap_remove_all_t)(vm_page_t);
typedef	void	(*pmap_remove_pages_t)(pmap_t);
typedef	void	(*pmap_unwire_t)(pmap_t, vm_offset_t, vm_offset_t);
typedef	void	(*pmap_zero_page_t)(vm_page_t);
typedef	void	(*pmap_zero_page_area_t)(vm_page_t, int, int);
typedef	int	(*pmap_mincore_t)(pmap_t, vm_offset_t, vm_paddr_t *);
typedef	void	(*pmap_activate_t)(struct thread	*);
typedef void	(*pmap_deactivate_t)(struct thread	*);
typedef	void	(*pmap_align_superpage_t)(vm_object_t, vm_ooffset_t,
		    vm_offset_t *, vm_size_t);

typedef	void	(*pmap_sync_icache_t)(pmap_t, vm_offset_t, vm_size_t);
typedef	void	(*pmap_dumpsys_map_chunk_t)(vm_paddr_t, size_t, void **);
typedef	void	(*pmap_dumpsys_unmap_chunk_t)(vm_paddr_t, size_t, void *);
typedef	void	(*pmap_dumpsys_pa_init_t)(void);
typedef	size_t	(*pmap_dumpsys_scan_pmap_t)(struct bitset *dump_bitset);
typedef	void	*(*pmap_dumpsys_dump_pmap_init_t)(unsigned);
typedef	void	*(*pmap_dumpsys_dump_pmap_t)(void *, void *, u_long *);
typedef	vm_offset_t	(*pmap_quick_enter_page_t)(vm_page_t);
typedef	void	(*pmap_quick_remove_page_t)(vm_offset_t);
typedef	bool	(*pmap_ps_enabled_t)(pmap_t);
typedef	void	(*pmap_tlbie_all_t)(void);
typedef void	(*pmap_installer_t)(void);

struct pmap_funcs {
	pmap_installer_t	install;
	pmap_bootstrap_t	bootstrap;
	pmap_cpu_bootstrap_t	cpu_bootstrap;
	pmap_kenter_t		kenter;
	pmap_kenter_attr_t	kenter_attr;
	pmap_kremove_t		kremove;
	pmap_mapdev_t		mapdev;
	pmap_mapdev_attr_t	mapdev_attr;
	pmap_unmapdev_t		unmapdev;
	pmap_page_set_memattr_t	page_set_memattr;
	pmap_change_attr_t	change_attr;
	pmap_map_user_ptr_t	map_user_ptr;
	pmap_decode_kernel_ptr_t	decode_kernel_ptr;
	pmap_kextract_t		kextract;
	pmap_dev_direct_mapped_t	dev_direct_mapped;
	pmap_advise_t		advise;
	pmap_clear_modify_t	clear_modify;
	pmap_remove_write_t	remove_write;
	pmap_copy_t	copy;
	pmap_copy_page_t	copy_page;
	pmap_copy_pages_t	copy_pages;
	pmap_enter_t	enter;
	pmap_enter_object_t	enter_object;
	pmap_enter_quick_t	enter_quick;
	pmap_extract_t	extract;
	pmap_extract_and_hold_t	extract_and_hold;
	pmap_growkernel_t	growkernel;
	pmap_init_t	init;
	pmap_is_modified_t	is_modified;
	pmap_is_prefaultable_t	is_prefaultable;
	pmap_is_referenced_t	is_referenced;
	pmap_ts_referenced_t	ts_referenced;
	pmap_page_is_mapped_t	page_is_mapped;
	pmap_ps_enabled_t	ps_enabled;
	pmap_map_t	map;
	pmap_object_init_pt_t	object_init_pt;
	pmap_page_exists_quick_t	page_exists_quick;
	pmap_page_init_t	page_init;
	pmap_page_wired_mappings_t	page_wired_mappings;
	pmap_pinit_t	pinit;
	pmap_pinit0_t	pinit0;
	pmap_protect_t	protect;
	pmap_qenter_t	qenter;
	pmap_qremove_t	qremove;
	pmap_release_t	release;
	pmap_remove_t	remove;
	pmap_remove_all_t	remove_all;
	pmap_remove_pages_t	remove_pages;
	pmap_unwire_t	unwire;
	pmap_zero_page_t	zero_page;
	pmap_zero_page_area_t	zero_page_area;
	pmap_mincore_t	mincore;
	pmap_activate_t	activate;
	pmap_deactivate_t	deactivate;
	pmap_align_superpage_t	align_superpage;
	pmap_sync_icache_t	sync_icache;
	pmap_quick_enter_page_t	quick_enter_page;
	pmap_quick_remove_page_t	quick_remove_page;
	pmap_page_array_startup_t	page_array_startup;
	pmap_dumpsys_map_chunk_t	dumpsys_map_chunk;
	pmap_dumpsys_unmap_chunk_t	dumpsys_unmap_chunk;
	pmap_dumpsys_pa_init_t	dumpsys_pa_init;
	pmap_dumpsys_scan_pmap_t	dumpsys_scan_pmap;
	pmap_dumpsys_dump_pmap_init_t	dumpsys_dump_pmap_init;
	pmap_dumpsys_dump_pmap_t	dumpsys_dump_pmap;
	pmap_tlbie_all_t	tlbie_all;

};
struct mmu_kobj {
	const char *name;
	const struct mmu_kobj *base;
	const struct pmap_funcs *funcs;
};

typedef struct mmu_kobj		*mmu_t;

/* The currently installed pmap object. */
extern mmu_t	mmu_obj;

/*
 * Resolve a given pmap function.
 * 'func' is the function name less the 'pmap_' * prefix.
 */
#define PMAP_RESOLVE_FUNC(func) 		\
	({					\
	 pmap_##func##_t f;			\
	 const struct mmu_kobj	*mmu = mmu_obj;	\
	 do {					\
	    f = mmu->funcs->func;		\
	    if (f != NULL) break;		\
	    mmu = mmu->base;			\
	} while (mmu != NULL);			\
	f;})

#define MMU_DEF(name, ident, methods)		\
						\
const struct mmu_kobj name = {		\
	ident, NULL, &methods			\
};						\
DATA_SET(mmu_set, name)

#define MMU_DEF_INHERIT(name, ident, methods, base1)	\
						\
const struct mmu_kobj name = {			\
	ident, &base1, &methods,		\
};						\
DATA_SET(mmu_set, name)

/*
 * Known MMU names
 */
#define MMU_TYPE_BOOKE	"mmu_booke"	/* Book-E MMU specification */
#define MMU_TYPE_OEA	"mmu_oea"	/* 32-bit OEA */
#define MMU_TYPE_G5	"mmu_g5"	/* 64-bit bridge (ibm 970) */
#define MMU_TYPE_RADIX	"mmu_radix"	/* 64-bit native ISA 3.0 (POWER9) radix */
#define MMU_TYPE_8xx	"mmu_8xx"	/* 8xx quicc TLB */

#endif /* _MACHINE_MMUVAR_H_ */