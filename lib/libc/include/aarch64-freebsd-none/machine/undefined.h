/*-
 * Copyright (c) 2017 Andrew Turner
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
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

#ifndef _MACHINE__UNDEFINED_H_
#define	_MACHINE__UNDEFINED_H_

#ifdef _KERNEL

typedef int (*undef_handler_t)(vm_offset_t, uint32_t, struct trapframe *,
    uint32_t);

static inline int
mrs_Op0(uint32_t insn)
{

	/* op0 is encoded without the top bit in a mrs instruction */
	return (2 | ((insn & MRS_Op0_MASK) >> MRS_Op0_SHIFT));
}

#define	MRS_GET(op)						\
static inline int						\
mrs_##op(uint32_t insn)						\
{								\
								\
	return ((insn & MRS_##op##_MASK) >> MRS_##op##_SHIFT);	\
}
MRS_GET(Op1)
MRS_GET(CRn)
MRS_GET(CRm)
MRS_GET(Op2)

void undef_init(void);
void *install_undef_handler(bool, undef_handler_t);
void remove_undef_handler(void *);
int undef_insn(u_int, struct trapframe *);

#endif /* _KERNEL */

#endif