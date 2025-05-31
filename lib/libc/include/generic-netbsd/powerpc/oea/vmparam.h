/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas <matt@3am-softwre.com> of Allegro Networks, Inc.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _POWERPC_OEA_VMPARAM_H_
#define _POWERPC_OEA_VMPARAM_H_

#include <sys/queue.h>

/*
 * Most of the definitions in this can be overridden by a machine-specific
 * vmparam.h if required.  Otherwise a port can just include this file
 * get the right thing to happen.
 */

/*
 * OEA processors have 4K pages.  Override the PAGE_* definitions
 * to be compile-time constants.
 */
#define	PAGE_SHIFT	12
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

#ifndef	USRSTACK
#define	USRSTACK	VM_MAXUSER_ADDRESS
#endif

#ifndef	USRSTACK32
#define	USRSTACK32	VM_MAXUSER_ADDRESS32
#endif

#ifndef	MAXTSIZ
#define	MAXTSIZ		(256*1024*1024)		/* maximum text size */
#endif

#ifndef	MAXDSIZ
#define	MAXDSIZ		(1024*1024*1024)	/* maximum data size */
#endif

#ifndef	MAXDSIZ32
#define	MAXDSIZ32	(1024*1024*1024)	/* maximum data size */
#endif

#ifndef	MAXSSIZ
#define	MAXSSIZ		(32*1024*1024)		/* maximum stack size */
#endif

#ifndef	MAXSSIZ32
#define	MAXSSIZ32	(32*1024*1024)		/* maximum stack size */
#endif

#ifndef	DFLDSIZ
#define	DFLDSIZ		(256*1024*1024)		/* default data size */
#endif

#ifndef	DFLDSIZ32
#define	DFLSSIZ32	(256*1024*1024)
#endif

#ifndef	DFLSSIZ
#define	DFLSSIZ		(2*1024*1024)		/* default stack size */
#endif

#ifndef	DFLSSIZ32
#define	DFLSSIZ32	(2*1024*1024)		/* default stack size */
#endif

/*
 * Default number of pages in the user raw I/O map.
 */
#ifndef USRIOSIZE
#define	USRIOSIZE	1024
#endif

/*
 * The number of seconds for a process to be blocked before being
 * considered very swappable.
 */
#ifndef MAXSLP
#define	MAXSLP		20
#endif

/*
 * Segment handling stuff
 */
#define	SEGMENT_LENGTH	( 0x10000000L)
#define	SEGMENT_MASK	(~0x0fffffffL)

/*
 * Macros to manipulate VSIDs
 */
#if 0
/*
 * Move the SR# to the top bits to make the lower bits entirely random
 * so to give better PTE distribution.
 */
#define	VSID__KEYSHFT		(SR_VSID_WIDTH - SR_KEY_LEN)
#define	VSID_SR_INCREMENT	((1L << VSID__KEYSHFT) - 1)
#define VSID__HASHMASK		(VSID_SR_INCREMENT - 1)
#define	VSID_MAKE(sr, hash) \
	(( \
	    (((sr) << VSID__KEYSHFT) | ((hash) & VSID__HASMASK))
	    << SR_VSID_SHFT) & SR_VSID)
#define	VSID_TO_SR(vsid) \
	(((vsid) & SR_VSID) >> (SR_VSID_SHFT + VSID__KEYSHFT))
#define	VSID_TO_HASH(vsid) \
	(((vsid) & SR_VSID) >> SR_VSID_SHFT) & VSID__HASHMASK)
#else
#define	VSID__HASHSHFT		(SR_KEY_LEN)
#define	VSID_SR_INCREMENT	(1L << 0)
#define	VSID__KEYMASK		((1L << VSID__HASHSHFT) - 1)
#define	VSID_MAKE(sr, hash) \
	(( \
	    (((hash) << VSID__HASHSHFT) | ((sr) & VSID__KEYMASK)) \
	     << SR_VSID_SHFT) & SR_VSID)
#define	VSID_TO_SR(vsid) \
	(((vsid) >> SR_VSID_SHFT) & VSID__KEYMASK)
#define	VSID_TO_HASH(vsid) \
	(((vsid) & SR_VSID) >> (SR_VSID_SHFT + VSID__HASHSHFT))
#endif /*0*/

#ifndef _LP64
/*
 * Fixed segments
 */
#ifndef USER_SR
#define	USER_SR			12
#endif
#ifndef KERNEL_SR
#define	KERNEL_SR		13
#endif
#ifndef KERNEL2_SR
#define	KERNEL2_SR		14
#endif
#define	KERNEL2_SEGMENT		VSID_MAKE(KERNEL2_SR, KERNEL_VSIDBITS)
#endif
#define	KERNEL_VSIDBITS		0xfffff
#define	PHYSMAP_VSIDBITS	0xffffe
#define	PHYSMAPN_SEGMENT(s)	VSID_MAKE(s, PHYSMAP_VSIDBITS)
#define	KERNEL_SEGMENT		VSID_MAKE(KERNEL_SR, KERNEL_VSIDBITS)
#define	KERNELN_SEGMENT(s)	VSID_MAKE(s, KERNEL_VSIDBITS)
/* XXXSL: need something here that will never be mapped */
#define	EMPTY_SEGMENT		VSID_MAKE(0, 0xffffe)
#define	USER_ADDR		((void *)(USER_SR << ADDR_SR_SHFT))

/*
 * Some system constants
 */
#ifndef	NPMAPS
#define	NPMAPS		32768	/* Number of pmaps in system */
#endif

#define	VM_MIN_ADDRESS		((vaddr_t) 0)
#define	VM_MAXUSER_ADDRESS32	((vaddr_t) (uint32_t) ~0xfffL)
#ifdef _LP64
#define	VM_MAXUSER_ADDRESS	((vaddr_t) 1UL << 48) /* 256TB */
#else
#define	VM_MAXUSER_ADDRESS	VM_MAXUSER_ADDRESS32
#endif
#define	VM_MAX_ADDRESS		VM_MAXUSER_ADDRESS
#ifdef _LP64
#define	VM_MIN_KERNEL_ADDRESS	((vaddr_t) 0xffffffUL << 40) /* top 1TB */
#define	VM_MAX_KERNEL_ADDRESS	((vaddr_t) -32768)
#else
#define	VM_MIN_KERNEL_ADDRESS	((vaddr_t) (KERNEL_SR << ADDR_SR_SHFT))
#define	VM_MAX_KERNEL_ADDRESS	(VM_MIN_KERNEL_ADDRESS + 2*SEGMENT_LENGTH)
#endif

#define	VM_PHYSSEG_STRAT	VM_PSTRAT_BIGFIRST

#ifndef VM_PHYS_SIZE
#define	VM_PHYS_SIZE		(USRIOSIZE * PAGE_SIZE)
#endif

#endif /* _POWERPC_OEA_VMPARAM_H_ */