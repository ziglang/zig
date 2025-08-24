/*	$NetBSD: vmparam.h,v 1.26.4.1 2023/12/29 20:21:39 martin Exp $	*/

#ifndef _POWERPC_VMPARAM_H_
#define _POWERPC_VMPARAM_H_

#ifdef _KERNEL_OPT
#include "opt_modular.h"
#include "opt_ppcarch.h"
#endif

/*
 * These are common for BOOKE, IBM4XX, and OEA
 */
#define	VM_FREELIST_DEFAULT	0
#define	VM_FREELIST_DIRECT_MAPPED	1
#define	VM_FREELIST_FIRST16	2
#define	VM_NFREELIST		3

#define	VM_PHYSSEG_MAX		16

/*
 * The address to which unspecified mapping requests default
 * Put the stack in its own segment and start mmaping at the
 * top of the next lower segment.
 */
#define	__USE_TOPDOWN_VM
#define VM_DEFAULT_ADDRESS_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)maxdmap)

#if defined(MODULAR) || defined(_MODULE) || !defined(_KERNEL)
/*
 * If we are a module or a modular kernel, then we need to defined the range
 * of our variable page sizes since BOOKE and OEA use 4KB pages while IBM4XX
 * use 16KB pages.
 * This is also required for userland by jemalloc.
 */
#define MIN_PAGE_SHIFT	12			/* BOOKE/OEA */
#define MAX_PAGE_SHIFT	14			/* IBM4XX */
#define	MIN_PAGE_SIZE	(1 << MIN_PAGE_SHIFT)
#define	MAX_PAGE_SIZE	(1 << MAX_PAGE_SHIFT)
#endif /* MODULAR || _MODULE || !_KERNEL */

#if defined(_MODULE)
#if defined(_RUMPKERNEL)
/*
 * Safe definitions for RUMP kernels
 */
#define	VM_MAXUSER_ADDRESS	0x7fff8000
#define	VM_MIN_ADDRESS		0x00000000
#define	VM_MAX_ADDRESS		VM_MAXUSER_ADDRESS
#define	MAXDSIZ			(1024*1024*1024)
#define	MAXSSIZ			(32*1024*1024)
#define	MAXTSIZ			(256*1024*1024)
#else /* !_RUMPKERNEL */
/*
 * Some modules need some of the constants but those vary between the variants
 * so those constants are exported as linker symbols so they don't take up any
 * space but also avoid an extra load to put into a register.
 */
extern const char __USRSTACK;		/* let the linker resolve it */

#define USRSTACK	((vaddr_t)(uintptr_t)&__USRSTACK)
#endif /* !_RUMPKERNEL */

#else /* !_MODULE */

#if defined(PPC_BOOKE)
#include <powerpc/booke/vmparam.h>
#elif defined(PPC_IBM4XX)
#include <powerpc/ibm4xx/vmparam.h>
#elif defined(PPC_OEA) || defined (PPC_OEA64) || defined (PPC_OEA64_BRIDGE)
#include <powerpc/oea/vmparam.h>
#elif defined(_KERNEL)
#error unknown PPC variant
#endif

#endif /* !_MODULE */

#if defined(MODULAR) || defined(_MODULE)
/*
 * If we are a module or support modules, we need to define a compatible
 * pmap_physseg since IBM4XX uses one.  This will waste a tiny of space
 * but is needed for compatibility.
 */
#ifndef __HAVE_PMAP_PHYSSEG
#define	__HAVE_PMAP_PHYSSEG
struct pmap_physseg {
	uintptr_t pmseg_dummy[2];
};
#endif

__CTASSERT(sizeof(struct pmap_physseg) == sizeof(uintptr_t) * 2);
#endif /* MODULAR || _MODULE */

#endif /* !_POWERPC_VMPARAM_H_ */