/*	$NetBSD: reg.h,v 1.11 2022/05/22 11:27:33 andvar Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
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
 *	@(#)reg.h	5.5 (Berkeley) 1/18/91
 */

#ifndef _AMD64_REG_H_
#define _AMD64_REG_H_

#ifdef __x86_64__

#include <x86/fpu.h>
#include <machine/mcontext.h>

/*
 * Registers accessible to ptrace(2) syscall for debugger use.
 * Same as mcontext.__gregs (except that is 'unsigned long').
 * NB this structure is no longer the same as 'struct trapframe',
 * although the array indexes are defined in the same place.
 */
struct reg {
	long	regs[_NGREG];
};

struct fpreg {
	struct fxsave fxstate;
};

/*
 * Debug Registers
 *
 * DR0-DR3  Debug Address Registers
 * DR4-DR5  Reserved
 * DR6      Debug Status Register
 * DR7      Debug Control Register
 * DR8-DR15 Reserved
 */
struct dbreg {
	long	dr[16];
};

#else	/*	__x86_64__	*/

#include <i386/reg.h>

#endif	/*	__x86_64__	*/

#endif /* !_AMD64_REG_H_ */