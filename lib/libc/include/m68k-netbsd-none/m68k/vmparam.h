/*	$NetBSD: vmparam.h,v 1.1 2020/02/01 19:41:48 tsutsui Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1982, 1986, 1990, 1993
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
 * from: Utah $Hdr: vmparam.h 1.16 91/01/18$
 *
 *	@(#)vmparam.h	8.2 (Berkeley) 4/19/94
 */

#ifndef _M68K_VMPARAM_H_
#define	_M68K_VMPARAM_H_

/*
 * Common constants for m68k ports
 */

/*
 * hp300 pmap derived m68k ports can use 4K or 8K pages.
 * (except HPMMU machines, that support only 4K page)
 * sun3 and sun3x use 8K pages.
 * The page size is specified by PGSHIFT in <machine/param.h>.
 * Override the PAGE_* definitions to be compile-time constants.
 */
#define	PAGE_SHIFT	PGSHIFT
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

/* Some implemantations like jemalloc(3) require physical page size details. */
/*
 * XXX:
 * <uvm/uvm_param.h> assumes PAGE_SIZE is not a constant macro
 * but a variable (*uvmexp_pagesize) on MODULE builds in case of
 * (MIN_PAGE_SIZE != MAX_PAGE_SIZE).  For now we define these macros
 * for m68k ports only on !_KERNEL (currently just for jemalloc) builds.
 */
#if !defined(_KERNEL)
#define	MIN_PAGE_SHIFT	12
#define	MAX_PAGE_SHIFT	13
#define	MIN_PAGE_SIZE	(1 << MIN_PAGE_SHIFT)
#define	MAX_PAGE_SIZE	(1 << MAX_PAGE_SHIFT)
#endif /* !_KERNEL */

#endif /* _M68K_VMPARAM_H_ */