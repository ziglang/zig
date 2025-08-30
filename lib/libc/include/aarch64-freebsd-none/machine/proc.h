/*-
 * Copyright (c) 1991 Regents of the University of California.
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
 *      from: @(#)proc.h        7.1 (Berkeley) 5/15/91
 *	from: FreeBSD: src/sys/i386/include/proc.h,v 1.11 2001/06/29
 */

#ifdef __arm__
#include <arm/proc.h>
#else /* !__arm__ */

#ifndef	_MACHINE_PROC_H_
#define	_MACHINE_PROC_H_

struct ptrauth_key {
	uint64_t pa_key_lo;
	uint64_t pa_key_hi;
};

struct mdthread {
	int	md_spinlock_count;	/* (k) */
	register_t md_saved_daif;	/* (k) */
	uintptr_t md_canary;

	/*
	 * The pointer authentication keys. These are shared within a process,
	 * however this may change for some keys as the PAuth ABI Extension to
	 * ELF for the Arm 64-bit Architecture [1] is currently (July 2021) at
	 * an Alpha release quality so may change.
	 *
	 * [1] https://github.com/ARM-software/abi-aa/blob/main/pauthabielf64/pauthabielf64.rst
	 */
	struct {
		struct ptrauth_key apia;
		struct ptrauth_key apib;
		struct ptrauth_key apda;
		struct ptrauth_key apdb;
		struct ptrauth_key apga;
	} md_ptrauth_user;

	struct {
		struct ptrauth_key apia;
	} md_ptrauth_kern;

	uint64_t md_reserved[4];
};

struct mdproc {
	long	md_dummy;
};

#define	KINFO_PROC_SIZE	1088
#define	KINFO_PROC32_SIZE 816

#endif /* !_MACHINE_PROC_H_ */

#endif /* !__arm__ */