/*-
 * Copyright (c) 2005 David Xu <davidxu@freebsd.org>.
 * Copyright (c) 2014 the FreeBSD Foundation
 * All rights reserved.
 *
 * Portions of this software were developed by Andrew Turner
 * under sponsorship from the FreeBSD Foundation
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef __arm__
#include <arm/tls.h>
#else /* !__arm__ */

#ifndef _MACHINE_TLS_H_
#define	_MACHINE_TLS_H_

#include <sys/_tls_variant_i.h>

#define	TLS_DTV_OFFSET	0
#define	TLS_TCB_ALIGN	16
#define	TLS_TP_OFFSET	0

static __inline void
_tcb_set(struct tcb *tcb)
{
	__asm __volatile("msr	tpidr_el0, %x0" :: "r" (tcb));
}

static __inline struct tcb *
_tcb_get(void)
{
	struct tcb *tcb;

	__asm __volatile("mrs	%x0, tpidr_el0" : "=r" (tcb));
	return (tcb);
}

#endif /* !_MACHINE_TLS_H_ */

#endif /* !__arm__ */