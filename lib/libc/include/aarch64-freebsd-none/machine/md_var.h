/*-
 * Copyright (c) 1995 Bruce D. Evans.
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
 * 3. Neither the name of the author nor the names of contributors
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
 *
 *	from: FreeBSD: src/sys/i386/include/md_var.h,v 1.40 2001/07/12
 */

#ifndef	_MACHINE_MD_VAR_H_
#define	_MACHINE_MD_VAR_H_

extern long Maxmem;
extern char sigcode[];
extern int szsigcode;
extern u_long elf_hwcap;
extern u_long elf_hwcap2;
extern u_long linux_elf_hwcap;
extern u_long linux_elf_hwcap2;
#ifdef COMPAT_FREEBSD32
extern u_long elf32_hwcap;
extern u_long elf32_hwcap2;
#endif

struct dumperinfo;
struct minidumpstate;

int cpu_minidumpsys(struct dumperinfo *, const struct minidumpstate *);
void generic_bs_fault(void) __asm(__STRING(generic_bs_fault));
void generic_bs_peek_1(void) __asm(__STRING(generic_bs_peek_1));
void generic_bs_peek_2(void) __asm(__STRING(generic_bs_peek_2));
void generic_bs_peek_4(void) __asm(__STRING(generic_bs_peek_4));
void generic_bs_peek_8(void) __asm(__STRING(generic_bs_peek_8));
void generic_bs_poke_1(void) __asm(__STRING(generic_bs_poke_1));
void generic_bs_poke_2(void) __asm(__STRING(generic_bs_poke_2));
void generic_bs_poke_4(void) __asm(__STRING(generic_bs_poke_4));
void generic_bs_poke_8(void) __asm(__STRING(generic_bs_poke_8));

#ifdef _MD_WANT_SWAPWORD
/*
 * XXX These are implemented primarily for swp/swpb emulation at the moment, and
 * should be used sparingly with consideration -- they aren't implemented for
 * any other platform.  If we use them anywhere else, at a minimum they need
 * KASAN/KMSAN interceptors added.
 */
int	swapueword8(volatile uint8_t *base, uint8_t *val);
int	swapueword32(volatile uint32_t *base, uint32_t *val);
#endif

#endif /* !_MACHINE_MD_VAR_H_ */