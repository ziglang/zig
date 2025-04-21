/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright 2004 by Peter Grehan. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _MACHINE_TLS_H_
#define	_MACHINE_TLS_H_

#include <sys/_tls_variant_i.h>

#define	TLS_DTV_OFFSET	0x8000
#define	TLS_TCB_ALIGN	TLS_TCB_SIZE
#define	TLS_TP_OFFSET	0x7000

static __inline void
_tcb_set(struct tcb *tcb)
{
#ifdef __powerpc64__
	__asm __volatile("mr 13,%0" ::
	    "r" ((uint8_t *)tcb + TLS_TP_OFFSET + TLS_TCB_SIZE));
#else
	__asm __volatile("mr 2,%0" ::
	    "r" ((uint8_t *)tcb + TLS_TP_OFFSET + TLS_TCB_SIZE));
#endif
}

static __inline struct tcb *
_tcb_get(void)
{
	struct tcb *tcb;

#ifdef __powerpc64__
	__asm __volatile("addi %0,13,%1" : "=r" (tcb) :
	    "i" (-(TLS_TP_OFFSET + TLS_TCB_SIZE)));
#else
	__asm __volatile("addi %0,2,%1" : "=r" (tcb) :
	    "i" (-(TLS_TP_OFFSET + TLS_TCB_SIZE)));
#endif
	return (tcb);
}

#endif /* !_MACHINE_TLS_H_ */