/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2013 Ian Lepore <ian@freebsd.org>
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

#ifndef	_SYS_DEVMAP_H_
#define	_SYS_DEVMAP_H_

#ifndef _KERNEL
#error "no user-serviceable parts inside"
#endif

#ifdef __HAVE_STATIC_DEVMAP
/*
 * This structure is used by MD code to describe static mappings of devices
 * which are established as part of bringing up the MMU early in the boot.
 */
struct devmap_entry {
	vm_offset_t	pd_va;		/* virtual address */
	vm_paddr_t	pd_pa;		/* physical address */
	vm_size_t	pd_size;	/* size of region */
};

/*
 * Return the lowest KVA address used in any entry in the registered devmap
 * table.  This works with whatever table is registered, including the internal
 * table used by devmap_add_entry() if that routine was used. Platforms can
 * implement platform_lastaddr() by calling this if static device mappings are
 * their only use of high KVA space.
 */
vm_offset_t devmap_lastaddr(void);

/*
 * Automatically allocate KVA (from the top of the address space downwards) and
 * make static device mapping entries in an internal table.  The internal table
 * is automatically registered on the first call to this.
 */
void devmap_add_entry(vm_paddr_t pa, vm_size_t sz);

/*
 * Register a platform-local table to be bootstrapped by the generic
 * platform-specific init function in <ARCH>/machdep.c.  This is used by newer
 * code that allocates and fills in its own local table but does not have its
 * own platform-specific init routine.
 */
void devmap_register_table(const struct devmap_entry * _table);

/*
 * Establish mappings for all the entries in the table.  This is called
 * automatically from the common platform-specific init function in
 * <ARCH>/machdep.c, and also from the custom platform-specific init routines
 * in older code.  This function only has an effect when a table was installed
 * previously by devmap_register_table().
 */
void devmap_bootstrap(void);

/* Print the static mapping table; used for bootverbose output. */
void devmap_print_table(void);
#endif

#endif /* !_SYS_DEVMAP_H_ */