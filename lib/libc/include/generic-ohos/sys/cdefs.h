/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Berkeley Software Design, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)cdefs.h	8.8 (Berkeley) 1/9/95
 */

#ifndef CDEFS_H
#define CDEFS_H

#if defined(__cplusplus)
#define	__BEGIN_EXTERN_C    extern "C" {
#define	__END_EXTERN_C		}
#ifndef __BEGIN_DECLS
#define __BEGIN_DECLS    extern "C" {
#endif
#ifndef __END_DECLS
#define __END_DECLS		 }
#endif
#else
#define	__BEGIN_EXTERN_C
#define	__END_EXTERN_C
#ifndef __BEGIN_DECLS
#define __BEGIN_DECLS
#endif
#ifndef __END_DECLS
#define __END_DECLS
#endif
#endif

#define	__P(protos)	protos		/* full-blown ANSI C */
#define	__CONCAT(x,y)	x ## y
#define	__STRING(x)	#x

#define __aligned(x) __attribute__((__aligned__(x)))
#define __section(x) __attribute__((__section__(x)))

#define __always_inline __attribute__((__always_inline__))
#define __attribute_const__ __attribute__((__const__))
#define __attribute_pure__ __attribute__((__pure__))
#define __dead __attribute__((__noreturn__))
#define __noreturn __attribute__((__noreturn__))
#define __mallocfunc  __attribute__((__malloc__))
#define __packed __attribute__((__packed__))
#define __returns_twice __attribute__((__returns_twice__))
#define __unused __attribute__((__unused__))
#define __used __attribute__((__used__))

#define __printflike(x, y) __attribute__((__format__(printf, x, y)))
#define __scanflike(x, y) __attribute__((__format__(scanf, x, y)))
#define __strftimelike(x) __attribute__((__format__(strftime, x, 0)))


#if defined(__cplusplus)
#define __CAST(_k,_t,_v) (_k<_t>(_v))
#else
#define __CAST(_k,_t,_v) ((_t) (_v))
#endif

#define __ALIGN(value, alignment) (((value) + (alignment)-1) & ~((alignment)-1))

#define __GLOBL(sym) __asm__(".globl " __STRING(sym))
#define __WEAK(sym) __asm__(".weak " __STRING(sym))

#endif