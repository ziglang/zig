/* $NetBSD: crt0.S,v 1.4 2018/11/26 17:37:45 joerg Exp $ */

/*-
 * Copyright (c) 2013 The NetBSD Foundation, Inc.
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

#include <mips/asm.h>

RCSID("$NetBSD: crt0.S,v 1.4 2018/11/26 17:37:45 joerg Exp $")

STRONG_ALIAS(_start,__start)

/*
 *	Assumes kernel (or ld_elf.so) passes the following parameters to
 *	user-space in registers:
 *
 *	a0      stack pointer (0 if setregs didn't fill this in)
 *	a1      cleanup
 *	a2      Obj_Entry
 *	a3      ps_strings
 *
 *      XXX Does this violate the ABI?
 *      as well as the usual registers (pc, sp, and t9 == pc for ABI).
 */

NESTED_NOPROFILE(__start, CALLFRAME_SIZ, ra)
	SETUP_GP
	SETUP_GP64(t3, __start)
	move	a0, a1		/* cleanup */
	PTR_L	t9,%call16(_C_LABEL(___start))(gp)
	 move	a1, a3		/* ps_strings */
	.reloc  1f,R_MIPS_JALR,___start
1:	jr	t9
END(__start)
