/*	$NetBSD: gdt.h,v 1.1 2021/04/30 15:37:05 christos Exp $	*/

/*-
 * Copyright (c) 1996, 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by John T. Kohl and Charles M. Hannum.
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

#ifndef _X86_GDT_H_
#define _X86_GDT_H_

#if !defined(_LOCORE)

struct cpu_info;
void gdt_init(void);
void gdt_init_cpu(struct cpu_info *);
void gdt_alloc_cpu(struct cpu_info *);

#ifdef _LP64
struct x86_64_tss;
int tss_alloc(struct x86_64_tss *);
#else
struct i386tss;
int tss_alloc(const struct i386tss *);
#endif

void tss_free(int); 
int ldt_alloc(void *, size_t);
void ldt_free(int);

#endif /* LOCORE */


#ifndef MAXGDTSIZ
# define MAXGDTSIZ		65536	/* XXX: see <x86/pmap.h> */
#endif

#ifndef MAX_USERLDT_SIZE
# define MAX_USERLDT_SIZE	65536	/* XXX: see <x86/pmap.h> */
#endif

#define MAX_USERLDT_SLOTS	(int)(MAX_USERLDT_SIZE / sizeof(union descriptor))

#endif /* _X86_GDT_H_ */