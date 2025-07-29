/* $NetBSD: ptrace.h,v 1.3 2019/06/18 21:18:12 kamil Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifndef _RISCV_PTRACE_H_
#define _RISCV_PTRACE_H_

/*
 * RISCV-dependent ptrace definitions.
 * Note that PT_STEP is _not_ supported.
 */
#define PT_GETREGS	(PT_FIRSTMACH + 0)
#define PT_SETREGS	(PT_FIRSTMACH + 1)
#define PT_GETFPREGS	(PT_FIRSTMACH + 2)
#define PT_SETFPREGS	(PT_FIRSTMACH + 3)

#define PT_MACHDEP_STRINGS \
	"PT_GETREGS", \
	"PT_SETREGS", \
	"PT_GETFPREGS", \
	"PT_SETFPREGS"

#include <machine/reg.h>
#define PTRACE_REG_PC(r)	(r)->r_pc
#define PTRACE_REG_FP(r)	(r)->r_reg[7]
#define PTRACE_REG_SET_PC(r, v)	(r)->r_pc = (v)
#define PTRACE_REG_SP(r)	(r)->r_reg[1]
#define PTRACE_REG_INTRV(r)	(r)->r_reg[9]

#endif /* _RISCV_PTRACE_H_ */