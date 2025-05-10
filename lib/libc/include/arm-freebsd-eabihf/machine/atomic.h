/* $NetBSD: atomic.h,v 1.1 2002/10/19 12:22:34 bsh Exp $ */

/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (C) 2003-2004 Olivier Houchard
 * Copyright (C) 1994-1997 Mark Brinicombe
 * Copyright (C) 1994 Brini
 * All rights reserved.
 *
 * This code is derived from software written for Brini by Mark Brinicombe
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Brini.
 * 4. The name of Brini may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRINI ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL BRINI BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_MACHINE_ATOMIC_H_
#define	_MACHINE_ATOMIC_H_

#include <sys/atomic_common.h>

#if __ARM_ARCH >= 7
#define isb()  __asm __volatile("isb" : : : "memory")
#define dsb()  __asm __volatile("dsb" : : : "memory")
#define dmb()  __asm __volatile("dmb" : : : "memory")
#else
#define isb()  __asm __volatile("mcr p15, 0, %0, c7, c5, 4" : : "r" (0) : "memory")
#define dsb()  __asm __volatile("mcr p15, 0, %0, c7, c10, 4" : : "r" (0) : "memory")
#define dmb()  __asm __volatile("mcr p15, 0, %0, c7, c10, 5" : : "r" (0) : "memory")
#endif

#define mb()   dmb()
#define wmb()  dmb()
#define rmb()  dmb()

#define	ARM_HAVE_ATOMIC64

#define ATOMIC_ACQ_REL_LONG(NAME)					\
static __inline void							\
atomic_##NAME##_acq_long(__volatile u_long *p, u_long v)		\
{									\
	atomic_##NAME##_long(p, v);					\
	dmb();								\
}									\
									\
static __inline  void							\
atomic_##NAME##_rel_long(__volatile u_long *p, u_long v)		\
{									\
	dmb();								\
	atomic_##NAME##_long(p, v);					\
}

#define	ATOMIC_ACQ_REL(NAME, WIDTH)					\
static __inline  void							\
atomic_##NAME##_acq_##WIDTH(__volatile uint##WIDTH##_t *p, uint##WIDTH##_t v)\
{									\
	atomic_##NAME##_##WIDTH(p, v);					\
	dmb();								\
}									\
									\
static __inline  void							\
atomic_##NAME##_rel_##WIDTH(__volatile uint##WIDTH##_t *p, uint##WIDTH##_t v)\
{									\
	dmb();								\
	atomic_##NAME##_##WIDTH(p, v);					\
}

static __inline void
atomic_add_32(volatile uint32_t *p, uint32_t val)
{
	uint32_t tmp = 0, tmp2 = 0;

	__asm __volatile(
	    "1: ldrex	%0, [%2]	\n"
	    "   add	%0, %0, %3	\n"
	    "   strex	%1, %0, [%2]	\n"
	    "   cmp	%1, #0		\n"
	    "   it	ne		\n"
	    "   bne	1b		\n"
	    : "=&r" (tmp), "+r" (tmp2)
	    ,"+r" (p), "+r" (val) : : "cc", "memory");
}

static __inline void
atomic_add_64(volatile uint64_t *p, uint64_t val)
{
	uint64_t tmp;
	uint32_t exflag;

	__asm __volatile(
	    "1:							\n"
	    "   ldrexd	%Q[tmp], %R[tmp], [%[ptr]]		\n"
	    "   adds	%Q[tmp], %Q[val]			\n"
	    "   adc	%R[tmp], %R[tmp], %R[val]		\n"
	    "   strexd	%[exf], %Q[tmp], %R[tmp], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [exf] "=&r" (exflag),
	      [tmp] "=&r" (tmp)
	    : [ptr] "r"   (p),
	      [val] "r"   (val)
	    : "cc", "memory");
}

static __inline void
atomic_add_long(volatile u_long *p, u_long val)
{

	atomic_add_32((volatile uint32_t *)p, val);
}

ATOMIC_ACQ_REL(add, 32)
ATOMIC_ACQ_REL(add, 64)
ATOMIC_ACQ_REL_LONG(add)

static __inline void
atomic_clear_32(volatile uint32_t *address, uint32_t setmask)
{
	uint32_t tmp = 0, tmp2 = 0;

	__asm __volatile(
	    "1: ldrex	%0, [%2]	\n"
	    "   bic	%0, %0, %3	\n"
	    "   strex	%1, %0, [%2]	\n"
	    "   cmp	%1, #0		\n"
	    "   it	ne		\n"
	    "   bne	1b		\n"
	    : "=&r" (tmp), "+r" (tmp2), "+r" (address), "+r" (setmask)
	    : : "cc", "memory");
}

static __inline void
atomic_clear_64(volatile uint64_t *p, uint64_t val)
{
	uint64_t tmp;
	uint32_t exflag;

	__asm __volatile(
	    "1:							\n"
	    "   ldrexd	%Q[tmp], %R[tmp], [%[ptr]]		\n"
	    "   bic	%Q[tmp], %Q[val]			\n"
	    "   bic	%R[tmp], %R[val]			\n"
	    "   strexd	%[exf], %Q[tmp], %R[tmp], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [exf] "=&r" (exflag),
	      [tmp] "=&r" (tmp)
	    : [ptr] "r"   (p),
	      [val] "r"   (val)
	    : "cc", "memory");
}

static __inline void
atomic_clear_long(volatile u_long *address, u_long setmask)
{

	atomic_clear_32((volatile uint32_t *)address, setmask);
}

ATOMIC_ACQ_REL(clear, 32)
ATOMIC_ACQ_REL(clear, 64)
ATOMIC_ACQ_REL_LONG(clear)

#define ATOMIC_FCMPSET_CODE(RET, TYPE, SUF)                   \
    {                                                         \
	TYPE tmp;                                             \
                                                              \
	__asm __volatile(                                     \
	    "1: ldrex" SUF "   %[tmp], [%[ptr]]          \n"  \
	    "   ldr" SUF "     %[ret], [%[oldv]]         \n"  \
	    "   teq            %[tmp], %[ret]            \n"  \
	    "   ittee          ne                        \n"  \
	    "   str" SUF "ne   %[tmp], [%[oldv]]         \n"  \
	    "   movne          %[ret], #0                \n"  \
	    "   strex" SUF "eq %[ret], %[newv], [%[ptr]] \n"  \
	    "   eorseq         %[ret], #1                \n"  \
	    "   beq            1b                        \n"  \
	    : [ret] "=&r" (RET),                              \
	      [tmp] "=&r" (tmp)                               \
	    : [ptr] "r"   (_ptr),                             \
	      [oldv] "r"  (_old),                             \
	      [newv] "r"  (_new)                              \
	    : "cc", "memory");                                \
    }

#define ATOMIC_FCMPSET_CODE64(RET)                                 \
    {                                                              \
	uint64_t cmp, tmp;                                         \
                                                                   \
	__asm __volatile(                                          \
	    "1: ldrexd   %Q[tmp], %R[tmp], [%[ptr]]           \n"  \
	    "   ldrd     %Q[cmp], %R[cmp], [%[oldv]]          \n"  \
	    "   teq      %Q[tmp], %Q[cmp]                     \n"  \
	    "   it       eq                                   \n"  \
	    "   teqeq    %R[tmp], %R[cmp]                     \n"  \
	    "   ittee    ne                                   \n"  \
	    "   movne    %[ret], #0                           \n"  \
	    "   strdne   %[cmp], [%[oldv]]                    \n"  \
	    "   strexdeq %[ret], %Q[newv], %R[newv], [%[ptr]] \n"  \
	    "   eorseq   %[ret], #1                           \n"  \
	    "   beq      1b                                   \n"  \
	    : [ret] "=&r" (RET),                                   \
	      [cmp] "=&r" (cmp),                                   \
	      [tmp] "=&r" (tmp)                                    \
	    : [ptr] "r"   (_ptr),                                  \
	      [oldv] "r"  (_old),                                  \
	      [newv] "r"  (_new)                                   \
	    : "cc", "memory");                                     \
    }

static __inline int
atomic_fcmpset_8(volatile uint8_t *_ptr, uint8_t *_old, uint8_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, uint8_t, "b");
	return (ret);
}
#define	atomic_fcmpset_8	atomic_fcmpset_8

static __inline int
atomic_fcmpset_acq_8(volatile uint8_t *_ptr, uint8_t *_old, uint8_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, uint8_t, "b");
	dmb();
	return (ret);
}

static __inline int
atomic_fcmpset_rel_8(volatile uint8_t *_ptr, uint8_t *_old, uint8_t _new)
{
	int ret;

	dmb();
	ATOMIC_FCMPSET_CODE(ret, uint8_t, "b");
	return (ret);
}

static __inline int
atomic_fcmpset_16(volatile uint16_t *_ptr, uint16_t *_old, uint16_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, uint16_t, "h");
	return (ret);
}
#define	atomic_fcmpset_16	atomic_fcmpset_16

static __inline int
atomic_fcmpset_acq_16(volatile uint16_t *_ptr, uint16_t *_old, uint16_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, uint16_t, "h");
	dmb();
	return (ret);
}

static __inline int
atomic_fcmpset_rel_16(volatile uint16_t *_ptr, uint16_t *_old, uint16_t _new)
{
	int ret;

	dmb();
	ATOMIC_FCMPSET_CODE(ret, uint16_t, "h");
	return (ret);
}

static __inline int
atomic_fcmpset_32(volatile uint32_t *_ptr, uint32_t *_old, uint32_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, uint32_t, "");
	return (ret);
}

static __inline int
atomic_fcmpset_acq_32(volatile uint32_t *_ptr, uint32_t *_old, uint32_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, uint32_t, "");
	dmb();
	return (ret);
}

static __inline int
atomic_fcmpset_rel_32(volatile uint32_t *_ptr, uint32_t *_old, uint32_t _new)
{
	int ret;

	dmb();
	ATOMIC_FCMPSET_CODE(ret, uint32_t, "");
	return (ret);
}

static __inline int
atomic_fcmpset_long(volatile u_long *_ptr, u_long *_old, u_long _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, u_long, "");
	return (ret);
}

static __inline int
atomic_fcmpset_acq_long(volatile u_long *_ptr, u_long *_old, u_long _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE(ret, u_long, "");
	dmb();
	return (ret);
}

static __inline int
atomic_fcmpset_rel_long(volatile u_long *_ptr, u_long *_old, u_long _new)
{
	int ret;

	dmb();
	ATOMIC_FCMPSET_CODE(ret, u_long, "");
	return (ret);
}

static __inline int
atomic_fcmpset_64(volatile uint64_t *_ptr, uint64_t *_old, uint64_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE64(ret);
	return (ret);
}

static __inline int
atomic_fcmpset_acq_64(volatile uint64_t *_ptr, uint64_t *_old, uint64_t _new)
{
	int ret;

	ATOMIC_FCMPSET_CODE64(ret);
	dmb();
	return (ret);
}

static __inline int
atomic_fcmpset_rel_64(volatile uint64_t *_ptr, uint64_t *_old, uint64_t _new)
{
	int ret;

	dmb();
	ATOMIC_FCMPSET_CODE64(ret);
	return (ret);
}

#define ATOMIC_CMPSET_CODE(RET, SUF)                         \
    {                                                        \
	__asm __volatile(                                    \
	    "1: ldrex" SUF "   %[ret], [%[ptr]]          \n" \
	    "   teq            %[ret], %[oldv]           \n" \
	    "   itee           ne                        \n" \
	    "   movne          %[ret], #0                \n" \
	    "   strex" SUF "eq %[ret], %[newv], [%[ptr]] \n" \
	    "   eorseq         %[ret], #1                \n" \
	    "   beq            1b                        \n" \
	    : [ret] "=&r" (RET)                              \
	    : [ptr] "r"   (_ptr),                            \
	      [oldv] "r"  (_old),                            \
	      [newv] "r"  (_new)                             \
	    : "cc", "memory");                               \
    }

#define ATOMIC_CMPSET_CODE64(RET)                                 \
    {                                                             \
	uint64_t tmp;                                             \
	                                                          \
	__asm __volatile(                                         \
	    "1: ldrexd   %Q[tmp], %R[tmp], [%[ptr]]           \n" \
	    "   teq      %Q[tmp], %Q[oldv]                    \n" \
	    "   it       eq                                   \n" \
	    "   teqeq    %R[tmp], %R[oldv]                    \n" \
	    "   itee     ne                                   \n" \
	    "   movne    %[ret], #0                           \n" \
	    "   strexdeq %[ret], %Q[newv], %R[newv], [%[ptr]] \n" \
	    "   eorseq   %[ret], #1                           \n" \
	    "   beq      1b                                   \n" \
	    : [ret] "=&r" (RET),                                  \
	      [tmp] "=&r" (tmp)                                   \
	    : [ptr] "r"   (_ptr),                                 \
	      [oldv] "r"  (_old),                                 \
	      [newv] "r"  (_new)                                  \
	    : "cc", "memory");                                    \
    }

static __inline int
atomic_cmpset_8(volatile uint8_t *_ptr, uint8_t _old, uint8_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "b");
	return (ret);
}
#define	atomic_cmpset_8		atomic_cmpset_8

static __inline int
atomic_cmpset_acq_8(volatile uint8_t *_ptr, uint8_t _old, uint8_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "b");
	dmb();
	return (ret);
}

static __inline int
atomic_cmpset_rel_8(volatile uint8_t *_ptr, uint8_t _old, uint8_t _new)
{
	int ret;

	dmb();
	ATOMIC_CMPSET_CODE(ret, "b");
	return (ret);
}

static __inline int
atomic_cmpset_16(volatile uint16_t *_ptr, uint16_t _old, uint16_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "h");
	return (ret);
}
#define	atomic_cmpset_16	atomic_cmpset_16

static __inline int
atomic_cmpset_acq_16(volatile uint16_t *_ptr, uint16_t _old, uint16_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "h");
	dmb();
	return (ret);
}

static __inline int
atomic_cmpset_rel_16(volatile uint16_t *_ptr, uint16_t _old, uint16_t _new)
{
	int ret;

	dmb();
	ATOMIC_CMPSET_CODE(ret, "h");
	return (ret);
}

static __inline int
atomic_cmpset_32(volatile uint32_t *_ptr, uint32_t _old, uint32_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "");
	return (ret);
}

static __inline int
atomic_cmpset_acq_32(volatile uint32_t *_ptr, uint32_t _old, uint32_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "");
	dmb();
	return (ret);
}

static __inline int
atomic_cmpset_rel_32(volatile uint32_t *_ptr, uint32_t _old, uint32_t _new)
{
	int ret;

	dmb();
	ATOMIC_CMPSET_CODE(ret, "");
	return (ret);
}

static __inline int
atomic_cmpset_long(volatile u_long *_ptr, u_long _old, u_long _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "");
	return (ret);
}

static __inline int
atomic_cmpset_acq_long(volatile u_long *_ptr, u_long _old, u_long _new)
{
	int ret;

	ATOMIC_CMPSET_CODE(ret, "");
	dmb();
	return (ret);
}

static __inline int
atomic_cmpset_rel_long(volatile u_long *_ptr, u_long _old, u_long _new)
{
	int ret;

	dmb();
	ATOMIC_CMPSET_CODE(ret, "");
	return (ret);
}

static __inline int
atomic_cmpset_64(volatile uint64_t *_ptr, uint64_t _old, uint64_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE64(ret);
	return (ret);
}

static __inline int
atomic_cmpset_acq_64(volatile uint64_t *_ptr, uint64_t _old, uint64_t _new)
{
	int ret;

	ATOMIC_CMPSET_CODE64(ret);
	dmb();
	return (ret);
}

static __inline int
atomic_cmpset_rel_64(volatile uint64_t *_ptr, uint64_t _old, uint64_t _new)
{
	int ret;

	dmb();
	ATOMIC_CMPSET_CODE64(ret);
	return (ret);
}

static __inline uint32_t
atomic_fetchadd_32(volatile uint32_t *p, uint32_t val)
{
	uint32_t tmp = 0, tmp2 = 0, ret = 0;

	__asm __volatile(
	    "1: ldrex	%0, [%3]	\n"
	    "   add	%1, %0, %4	\n"
	    "   strex	%2, %1, [%3]	\n"
	    "   cmp	%2, #0		\n"
	    "   it	ne		\n"
	    "   bne	1b		\n"
	    : "+r" (ret), "=&r" (tmp), "+r" (tmp2), "+r" (p), "+r" (val)
	    : : "cc", "memory");
	return (ret);
}

static __inline uint64_t
atomic_fetchadd_64(volatile uint64_t *p, uint64_t val)
{
	uint64_t ret, tmp;
	uint32_t exflag;

	__asm __volatile(
	    "1:							\n"
	    "   ldrexd	%Q[ret], %R[ret], [%[ptr]]		\n"
	    "   adds	%Q[tmp], %Q[ret], %Q[val]		\n"
	    "   adc	%R[tmp], %R[ret], %R[val]		\n"
	    "   strexd	%[exf], %Q[tmp], %R[tmp], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [ret] "=&r" (ret),
	      [exf] "=&r" (exflag),
	      [tmp] "=&r" (tmp)
	    : [ptr] "r"   (p),
	      [val] "r"   (val)
	    : "cc", "memory");
	return (ret);
}

static __inline u_long
atomic_fetchadd_long(volatile u_long *p, u_long val)
{

	return (atomic_fetchadd_32((volatile uint32_t *)p, val));
}

static __inline uint32_t
atomic_load_acq_32(volatile uint32_t *p)
{
	uint32_t v;

	v = *p;
	dmb();
	return (v);
}

static __inline uint64_t
atomic_load_64(volatile uint64_t *p)
{
	uint64_t ret;

	/*
	 * The only way to atomically load 64 bits is with LDREXD which puts the
	 * exclusive monitor into the exclusive state, so reset it to open state
	 * with CLREX because we don't actually need to store anything.
	 */
	__asm __volatile(
	    "ldrexd	%Q[ret], %R[ret], [%[ptr]]	\n"
	    "clrex					\n"
	    : [ret] "=&r" (ret)
	    : [ptr] "r"   (p)
	    : "cc", "memory");
	return (ret);
}

static __inline uint64_t
atomic_load_acq_64(volatile uint64_t *p)
{
	uint64_t ret;

	ret = atomic_load_64(p);
	dmb();
	return (ret);
}

static __inline u_long
atomic_load_acq_long(volatile u_long *p)
{
	u_long v;

	v = *p;
	dmb();
	return (v);
}

static __inline uint32_t
atomic_readandclear_32(volatile uint32_t *p)
{
	uint32_t ret, tmp = 0, tmp2 = 0;

	__asm __volatile(
	    "1: ldrex	%0, [%3]	\n"
	    "   mov	%1, #0		\n"
	    "   strex	%2, %1, [%3]	\n"
	    "   cmp	%2, #0		\n"
	    "   it	ne		\n"
	    "   bne	1b		\n"
	    : "=r" (ret), "=&r" (tmp), "+r" (tmp2), "+r" (p)
	    : : "cc", "memory");
	return (ret);
}

static __inline uint64_t
atomic_readandclear_64(volatile uint64_t *p)
{
	uint64_t ret, tmp;
	uint32_t exflag;

	__asm __volatile(
	    "1:							\n"
	    "   ldrexd	%Q[ret], %R[ret], [%[ptr]]		\n"
	    "   mov	%Q[tmp], #0				\n"
	    "   mov	%R[tmp], #0				\n"
	    "   strexd	%[exf], %Q[tmp], %R[tmp], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [ret] "=&r" (ret),
	      [exf] "=&r" (exflag),
	      [tmp] "=&r" (tmp)
	    : [ptr] "r"   (p)
	    : "cc", "memory");
	return (ret);
}

static __inline u_long
atomic_readandclear_long(volatile u_long *p)
{

	return (atomic_readandclear_32((volatile uint32_t *)p));
}

static __inline void
atomic_set_32(volatile uint32_t *address, uint32_t setmask)
{
	uint32_t tmp = 0, tmp2 = 0;

	__asm __volatile(
	    "1: ldrex	%0, [%2]	\n"
	    "   orr	%0, %0, %3	\n"
	    "   strex	%1, %0, [%2]	\n"
	    "   cmp	%1, #0		\n"
	    "   it	ne		\n"
	    "   bne	1b		\n"
	    : "=&r" (tmp), "+r" (tmp2), "+r" (address), "+r" (setmask)
	    : : "cc", "memory");
}

static __inline void
atomic_set_64(volatile uint64_t *p, uint64_t val)
{
	uint64_t tmp;
	uint32_t exflag;

	__asm __volatile(
	    "1:							\n"
	    "   ldrexd	%Q[tmp], %R[tmp], [%[ptr]]		\n"
	    "   orr	%Q[tmp], %Q[val]			\n"
	    "   orr	%R[tmp], %R[val]			\n"
	    "   strexd	%[exf], %Q[tmp], %R[tmp], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [exf] "=&r" (exflag),
	      [tmp] "=&r" (tmp)
	    : [ptr] "r"   (p),
	      [val] "r"   (val)
	    : "cc", "memory");
}

static __inline void
atomic_set_long(volatile u_long *address, u_long setmask)
{

	atomic_set_32((volatile uint32_t *)address, setmask);
}

ATOMIC_ACQ_REL(set, 32)
ATOMIC_ACQ_REL(set, 64)
ATOMIC_ACQ_REL_LONG(set)

static __inline void
atomic_subtract_32(volatile uint32_t *p, uint32_t val)
{
	uint32_t tmp = 0, tmp2 = 0;

	__asm __volatile(
	    "1: ldrex	%0, [%2]	\n"
	    "   sub	%0, %0, %3	\n"
	    "   strex	%1, %0, [%2]	\n"
	    "   cmp	%1, #0		\n"
	    "   it	ne		\n"
	    "   bne	1b		\n"
	    : "=&r" (tmp), "+r" (tmp2), "+r" (p), "+r" (val)
	    : : "cc", "memory");
}

static __inline void
atomic_subtract_64(volatile uint64_t *p, uint64_t val)
{
	uint64_t tmp;
	uint32_t exflag;

	__asm __volatile(
	    "1:							\n"
	    "   ldrexd	%Q[tmp], %R[tmp], [%[ptr]]		\n"
	    "   subs	%Q[tmp], %Q[val]			\n"
	    "   sbc	%R[tmp], %R[tmp], %R[val]		\n"
	    "   strexd	%[exf], %Q[tmp], %R[tmp], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [exf] "=&r" (exflag),
	      [tmp] "=&r" (tmp)
	    : [ptr] "r"   (p),
	      [val] "r"   (val)
	    : "cc", "memory");
}

static __inline void
atomic_subtract_long(volatile u_long *p, u_long val)
{

	atomic_subtract_32((volatile uint32_t *)p, val);
}

ATOMIC_ACQ_REL(subtract, 32)
ATOMIC_ACQ_REL(subtract, 64)
ATOMIC_ACQ_REL_LONG(subtract)

static __inline void
atomic_store_64(volatile uint64_t *p, uint64_t val)
{
	uint64_t tmp;
	uint32_t exflag;

	/*
	 * The only way to atomically store 64 bits is with STREXD, which will
	 * succeed only if paired up with a preceeding LDREXD using the same
	 * address, so we read and discard the existing value before storing.
	 */
	__asm __volatile(
	    "1:							\n"
	    "   ldrexd	%Q[tmp], %R[tmp], [%[ptr]]		\n"
	    "   strexd	%[exf], %Q[val], %R[val], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [tmp] "=&r" (tmp),
	      [exf] "=&r" (exflag)
	    : [ptr] "r"   (p),
	      [val] "r"   (val)
	    : "cc", "memory");
}

static __inline void
atomic_store_rel_32(volatile uint32_t *p, uint32_t v)
{

	dmb();
	*p = v;
}

static __inline void
atomic_store_rel_64(volatile uint64_t *p, uint64_t val)
{

	dmb();
	atomic_store_64(p, val);
}

static __inline void
atomic_store_rel_long(volatile u_long *p, u_long v)
{

	dmb();
	*p = v;
}

static __inline int
atomic_testandclear_32(volatile uint32_t *ptr, u_int bit)
{
	int newv, oldv, result;

	__asm __volatile(
	    "   mov     ip, #1					\n"
	    "   lsl     ip, ip, %[bit]				\n"
	    /*  Done with %[bit] as input, reuse below as output. */
	    "1:							\n"
	    "   ldrex	%[oldv], [%[ptr]]			\n"
	    "   bic     %[newv], %[oldv], ip			\n"
	    "   strex	%[bit], %[newv], [%[ptr]]		\n"
	    "   teq	%[bit], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    "   ands	%[bit], %[oldv], ip			\n"
	    "   it	ne					\n"
	    "   movne   %[bit], #1                              \n"
	    : [bit]  "=&r"   (result),
	      [oldv] "=&r"   (oldv),
	      [newv] "=&r"   (newv)
	    : [ptr]  "r"     (ptr),
	             "[bit]" (bit & 0x1f)
	    : "cc", "ip", "memory");

	return (result);
}

static __inline int
atomic_testandclear_int(volatile u_int *p, u_int v)
{

	return (atomic_testandclear_32((volatile uint32_t *)p, v));
}

static __inline int
atomic_testandclear_long(volatile u_long *p, u_int v)
{

	return (atomic_testandclear_32((volatile uint32_t *)p, v));
}
#define	atomic_testandclear_long	atomic_testandclear_long


static __inline int
atomic_testandclear_64(volatile uint64_t *p, u_int v)
{
	volatile uint32_t *p32;

	p32 = (volatile uint32_t *)p;
	/*
	 * Assume little-endian,
	 * atomic_testandclear_32() uses only last 5 bits of v
	 */
	if ((v & 0x20) != 0)
		p32++;
	return (atomic_testandclear_32(p32, v));
}

static __inline int
atomic_testandset_32(volatile uint32_t *ptr, u_int bit)
{
	int newv, oldv, result;

	__asm __volatile(
	    "   mov     ip, #1					\n"
	    "   lsl     ip, ip, %[bit]				\n"
	    /*  Done with %[bit] as input, reuse below as output. */
	    "1:							\n"
	    "   ldrex	%[oldv], [%[ptr]]			\n"
	    "   orr     %[newv], %[oldv], ip			\n"
	    "   strex	%[bit], %[newv], [%[ptr]]		\n"
	    "   teq	%[bit], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    "   ands	%[bit], %[oldv], ip			\n"
	    "   it	ne					\n"
	    "   movne   %[bit], #1                              \n"
	    : [bit]  "=&r"   (result),
	      [oldv] "=&r"   (oldv),
	      [newv] "=&r"   (newv)
	    : [ptr]  "r"     (ptr),
	             "[bit]" (bit & 0x1f)
	    : "cc", "ip", "memory");

	return (result);
}

static __inline int
atomic_testandset_int(volatile u_int *p, u_int v)
{

	return (atomic_testandset_32((volatile uint32_t *)p, v));
}

static __inline int
atomic_testandset_long(volatile u_long *p, u_int v)
{

	return (atomic_testandset_32((volatile uint32_t *)p, v));
}
#define	atomic_testandset_long	atomic_testandset_long

static __inline int
atomic_testandset_64(volatile uint64_t *p, u_int v)
{
	volatile uint32_t *p32;

	p32 = (volatile uint32_t *)p;
	/*
	 * Assume little-endian,
	 * atomic_testandset_32() uses only last 5 bits of v
	 */
	if ((v & 0x20) != 0)
		p32++;
	return (atomic_testandset_32(p32, v));
}

static __inline uint32_t
atomic_swap_32(volatile uint32_t *p, uint32_t v)
{
	uint32_t ret, exflag;

	__asm __volatile(
	    "1: ldrex	%[ret], [%[ptr]]		\n"
	    "   strex	%[exf], %[val], [%[ptr]]	\n"
	    "   teq	%[exf], #0			\n"
	    "   it	ne				\n"
	    "   bne	1b				\n"
	    : [ret] "=&r"  (ret),
	      [exf] "=&r" (exflag)
	    : [val] "r"  (v),
	      [ptr] "r"  (p)
	    : "cc", "memory");
	return (ret);
}

static __inline u_long
atomic_swap_long(volatile u_long *p, u_long v)
{

	return (atomic_swap_32((volatile uint32_t *)p, v));
}

static __inline uint64_t
atomic_swap_64(volatile uint64_t *p, uint64_t v)
{
	uint64_t ret;
	uint32_t exflag;

	__asm __volatile(
	    "1: ldrexd	%Q[ret], %R[ret], [%[ptr]]		\n"
	    "   strexd	%[exf], %Q[val], %R[val], [%[ptr]]	\n"
	    "   teq	%[exf], #0				\n"
	    "   it	ne					\n"
	    "   bne	1b					\n"
	    : [ret] "=&r" (ret),
	      [exf] "=&r" (exflag)
	    : [val] "r"   (v),
	      [ptr] "r"   (p)
	    : "cc", "memory");
	return (ret);
}

#undef ATOMIC_ACQ_REL
#undef ATOMIC_ACQ_REL_LONG

static __inline void
atomic_thread_fence_acq(void)
{

	dmb();
}

static __inline void
atomic_thread_fence_rel(void)
{

	dmb();
}

static __inline void
atomic_thread_fence_acq_rel(void)
{

	dmb();
}

static __inline void
atomic_thread_fence_seq_cst(void)
{

	dmb();
}

#define atomic_clear_ptr		atomic_clear_32
#define atomic_clear_acq_ptr		atomic_clear_acq_32
#define atomic_clear_rel_ptr		atomic_clear_rel_32
#define atomic_set_ptr			atomic_set_32
#define atomic_set_acq_ptr		atomic_set_acq_32
#define atomic_set_rel_ptr		atomic_set_rel_32
#define atomic_fcmpset_ptr		atomic_fcmpset_32
#define atomic_fcmpset_rel_ptr		atomic_fcmpset_rel_32
#define atomic_fcmpset_acq_ptr		atomic_fcmpset_acq_32
#define atomic_cmpset_ptr		atomic_cmpset_32
#define atomic_cmpset_acq_ptr		atomic_cmpset_acq_32
#define atomic_cmpset_rel_ptr		atomic_cmpset_rel_32
#define atomic_load_acq_ptr		atomic_load_acq_32
#define atomic_store_rel_ptr		atomic_store_rel_32
#define atomic_swap_ptr			atomic_swap_32
#define atomic_readandclear_ptr		atomic_readandclear_32

#define atomic_add_int			atomic_add_32
#define atomic_add_acq_int		atomic_add_acq_32
#define atomic_add_rel_int		atomic_add_rel_32
#define atomic_subtract_int		atomic_subtract_32
#define atomic_subtract_acq_int		atomic_subtract_acq_32
#define atomic_subtract_rel_int		atomic_subtract_rel_32
#define atomic_clear_int		atomic_clear_32
#define atomic_clear_acq_int		atomic_clear_acq_32
#define atomic_clear_rel_int		atomic_clear_rel_32
#define atomic_set_int			atomic_set_32
#define atomic_set_acq_int		atomic_set_acq_32
#define atomic_set_rel_int		atomic_set_rel_32
#define atomic_fcmpset_int		atomic_fcmpset_32
#define atomic_fcmpset_acq_int		atomic_fcmpset_acq_32
#define atomic_fcmpset_rel_int		atomic_fcmpset_rel_32
#define atomic_cmpset_int		atomic_cmpset_32
#define atomic_cmpset_acq_int		atomic_cmpset_acq_32
#define atomic_cmpset_rel_int		atomic_cmpset_rel_32
#define atomic_fetchadd_int		atomic_fetchadd_32
#define atomic_readandclear_int		atomic_readandclear_32
#define atomic_load_acq_int		atomic_load_acq_32
#define atomic_store_rel_int		atomic_store_rel_32
#define atomic_swap_int			atomic_swap_32

/*
 * For:
 *  - atomic_load_acq_8
 *  - atomic_load_acq_16
 *  - atomic_testandset_acq_long
 */
#include <sys/_atomic_subword.h>

#endif /* _MACHINE_ATOMIC_H_ */