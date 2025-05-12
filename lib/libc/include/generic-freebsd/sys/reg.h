/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (C) 2014,2019 Andrew Turner
 * Copyright (c) 2014-2015 The FreeBSD Foundation
 *
 * This software was developed by Andrew Turner under
 * sponsorship from the FreeBSD Foundation.
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

#ifndef	_SYS_REG_H_
#define	_SYS_REG_H_

#include <machine/reg.h>

#ifdef _KERNEL
#include <sys/linker_set.h>

struct sbuf;
struct regset;

typedef bool (regset_get)(struct regset *, struct thread *, void *,
    size_t *);
typedef bool (regset_set)(struct regset *, struct thread *, void *, size_t);

struct regset {
	int		note;
	size_t		size;
	regset_get	*get;
	regset_set	*set;
};

#if defined(__ELF_WORD_SIZE)
SET_DECLARE(__elfN(regset), struct regset);
#define	ELF_REGSET(_regset)	DATA_SET(__elfN(regset), _regset)
#endif
#ifdef COMPAT_FREEBSD32
SET_DECLARE(elf32_regset, struct regset);
#define	ELF32_REGSET(_regset)	DATA_SET(elf32_regset, _regset)
#endif

int	fill_regs(struct thread *, struct reg *);
int	set_regs(struct thread *, struct reg *);
int	fill_fpregs(struct thread *, struct fpreg *);
int	set_fpregs(struct thread *, struct fpreg *);
int	fill_dbregs(struct thread *, struct dbreg *);
int	set_dbregs(struct thread *, struct dbreg *);
#ifdef COMPAT_FREEBSD32
int	fill_regs32(struct thread *, struct reg32 *);
int	set_regs32(struct thread *, struct reg32 *);
#ifndef fill_fpregs32
int	fill_fpregs32(struct thread *, struct fpreg32 *);
#endif
#ifndef set_fpregs32
int	set_fpregs32(struct thread *, struct fpreg32 *);
#endif
#ifndef fill_dbregs32
int	fill_dbregs32(struct thread *, struct dbreg32 *);
#endif
#ifndef set_dbregs32
int	set_dbregs32(struct thread *, struct dbreg32 *);
#endif
#endif
#endif

#endif