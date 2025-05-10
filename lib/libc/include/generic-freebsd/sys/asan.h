/*	$NetBSD: asan.h,v 1.15 2020/09/10 14:10:46 maxv Exp $	*/

/*
 * Copyright (c) 2018-2020 Maxime Villard, m00nbsd.net
 * All rights reserved.
 *
 * This code is part of the KASAN subsystem of the NetBSD kernel.
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

#ifndef _SYS_ASAN_H_
#define _SYS_ASAN_H_

#ifdef KASAN
#include <sys/types.h>

/* ASAN constants. Part of the compiler ABI. */
#define KASAN_SHADOW_SCALE		8
#define KASAN_SHADOW_SCALE_SHIFT	3

/* Stack redzone values. Part of the compiler ABI. */
#define KASAN_STACK_LEFT	0xF1
#define KASAN_STACK_MID		0xF2
#define KASAN_STACK_RIGHT	0xF3
#define KASAN_USE_AFTER_RET	0xF5
#define KASAN_USE_AFTER_SCOPE	0xF8

/* Our redzone values. */
#define KASAN_GENERIC_REDZONE	0xFA
#define KASAN_MALLOC_REDZONE	0xFB
#define KASAN_KMEM_REDZONE	0xFC
#define	KASAN_UMA_FREED		0xFD
#define	KASAN_KSTACK_FREED	0xFE
#define	KASAN_EXEC_ARGS_FREED	0xFF

void kasan_init(void);
void kasan_init_early(vm_offset_t, size_t);
void kasan_shadow_map(vm_offset_t, size_t);
void kasan_mark(const void *, size_t, size_t, uint8_t);
#else /* KASAN */
#define kasan_init()
#define kasan_shadow_map(a, s)
#define kasan_mark(p, s, l, c)
#endif /* !KASAN */

#endif /* !_SYS_ASAN_H_ */