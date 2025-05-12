/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (C) 2003 David Xu <davidxu@freebsd.org>
 * Copyright (c) 2001 Daniel Eischen <deischen@freebsd.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Neither the name of the author nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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

#ifndef _MACHINE_TLS_H_
#define	_MACHINE_TLS_H_

#include <x86/sysarch.h>

#define	TLS_VARIANT_II

struct pthread;

/*
 * Variant II tcb, first two members are required by rtld,
 * %fs (amd64) / %gs (i386) points to the structure.
 */
struct tcb {
	struct tcb		*tcb_self;	/* required by rtld */
	uintptr_t		*tcb_dtv;	/* required by rtld */
	struct pthread		*tcb_thread;
};

#define	TLS_DTV_OFFSET	0
#ifdef __amd64__
#define	TLS_TCB_ALIGN	16
#else
#define	TLS_TCB_ALIGN	4
#endif
#define	TLS_TCB_SIZE	sizeof(struct tcb)
#define	TLS_TP_OFFSET	0

static __inline void
_tcb_set(struct tcb *tcb)
{
#ifdef __amd64__
	amd64_set_fsbase(tcb);
#else
 	i386_set_gsbase(tcb);
#endif
}

static __inline struct tcb *
_tcb_get(void)
{
	struct tcb *tcb;

#ifdef __amd64__
	__asm __volatile("movq %%fs:0, %0" : "=r" (tcb));
#else
	__asm __volatile("movl %%gs:0, %0" : "=r" (tcb));
#endif
	return (tcb);
}

#endif /* !_MACHINE_TLS_H_ */