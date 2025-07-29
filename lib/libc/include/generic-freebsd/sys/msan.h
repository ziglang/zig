/*	$NetBSD: msan.h,v 1.2 2020/09/09 16:29:59 maxv Exp $	*/

/*
 * Copyright (c) 2019-2020 Maxime Villard, m00nbsd.net
 * All rights reserved.
 *
 * This code is part of the KMSAN subsystem of the NetBSD kernel.
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

#ifndef _SYS_MSAN_H_
#define _SYS_MSAN_H_

#ifdef KMSAN
#include <sys/_bus_dma.h>
#include <sys/types.h>

#define KMSAN_STATE_UNINIT	0xFF
#define KMSAN_STATE_INITED	0x00

#define KMSAN_TYPE_STACK	0
#define KMSAN_TYPE_KMEM		1
#define KMSAN_TYPE_MALLOC	2
#define KMSAN_TYPE_UMA		3
#define KMSAN_TYPE_MAX		3

#define KMSAN_RET_ADDR		(uintptr_t)__builtin_return_address(0)

union ccb;
struct bio;
struct mbuf;
struct memdesc;
struct uio;

void kmsan_init(void);

void kmsan_shadow_map(vm_offset_t, size_t);

void kmsan_thread_alloc(struct thread *);
void kmsan_thread_free(struct thread *);

void kmsan_bus_dmamap_sync(struct memdesc *, bus_dmasync_op_t);

void kmsan_orig(const void *, size_t, int, uintptr_t);
void kmsan_mark(const void *, size_t, uint8_t);
void kmsan_mark_bio(const struct bio *, uint8_t);
void kmsan_mark_mbuf(const struct mbuf *, uint8_t);

void kmsan_check(const void *, size_t, const char *);
void kmsan_check_bio(const struct bio *, const char *);
void kmsan_check_ccb(const union ccb *, const char *);
void kmsan_check_mbuf(const struct mbuf *, const char *);
void kmsan_check_uio(const struct uio *, const char *);

#else
#define kmsan_init(u)
#define kmsan_shadow_map(a, s)
#define kmsan_thread_alloc(td)
#define kmsan_thread_free(l)
#define kmsan_dma_sync(m, a, s, o)
#define kmsan_dma_load(m, b, s, o)
#define kmsan_orig(p, l, c, a)
#define kmsan_mark(p, l, c)
#define kmsan_mark_bio(b, c)
#define kmsan_mark_mbuf(m, c)
#define kmsan_check(b, s, d)
#define kmsan_check_bio(b, d)
#define kmsan_check_ccb(c, d)
#define kmsan_check_mbuf(m, d)
#define kmsan_check_uio(u, d)
#define	kmsan_bus_dmamap_sync(d, op)
#endif

#endif /* !_SYS_MSAN_H_ */