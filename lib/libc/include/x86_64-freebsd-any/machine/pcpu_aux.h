/*-
 * SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 *
 * Copyright (c) 2019 The FreeBSD Foundation
 *
 * This software was developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD$
 */

#ifndef _MACHINE_PCPU_AUX_H_
#define	_MACHINE_PCPU_AUX_H_

#ifndef _KERNEL
#error "Not for userspace"
#endif

#ifndef _SYS_PCPU_H_
#error "Do not include machine/pcpu_aux.h directly"
#endif

/* Required for counters(9) to work on x86. */
_Static_assert(sizeof(struct pcpu) == UMA_PCPU_ALLOC_SIZE, "fix pcpu size");

extern struct pcpu *__pcpu;
extern struct pcpu temp_bsp_pcpu;

static __inline __pure2 struct thread *
__curthread(void)
{
	struct thread *td;

	__asm("movq %%gs:%P1,%0" : "=r" (td) : "n" (offsetof(struct pcpu,
	    pc_curthread)));
	return (td);
}
#define	curthread		(__curthread())
#define	curpcb			(&curthread->td_md.md_pcb)

#endif	/* _MACHINE_PCPU_AUX_H_ */
