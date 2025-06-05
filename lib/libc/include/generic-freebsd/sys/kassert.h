/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1999 Eivind Eklund <eivind@FreeBSD.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
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
 */

#ifndef _SYS_KASSERT_H_
#define	_SYS_KASSERT_H_

#include <sys/cdefs.h>

#ifdef _KERNEL
extern const char *panicstr;	/* panic message */
extern bool panicked;
#define	KERNEL_PANICKED()	__predict_false(panicked)

#ifdef	INVARIANTS		/* The option is always available */
#define	VNASSERT(exp, vp, msg) do {					\
	if (__predict_false(!(exp))) {					\
		vn_printf(vp, "VNASSERT failed: %s not true at %s:%d (%s)\n",\
		   #exp, __FILE__, __LINE__, __func__);	 		\
		kassert_panic msg;					\
	}								\
} while (0)
#define	MPASSERT(exp, mp, msg) do {					\
	if (__predict_false(!(exp))) {					\
		printf("MPASSERT mp %p failed: %s not true at %s:%d (%s)\n",\
		    (mp), #exp, __FILE__, __LINE__, __func__);		\
		kassert_panic msg;					\
	}								\
} while (0)
#define	VNPASS(exp, vp)	do {						\
	const char *_exp = #exp;					\
	VNASSERT(exp, vp, ("condition %s not met at %s:%d (%s)",	\
	    _exp, __FILE__, __LINE__, __func__));			\
} while (0)
#define	MPPASS(exp, mp)	do {						\
	const char *_exp = #exp;					\
	MPASSERT(exp, mp, ("condition %s not met at %s:%d (%s)",	\
	    _exp, __FILE__, __LINE__, __func__));			\
} while (0)
#define	__assert_unreachable() \
	panic("executing segment marked as unreachable at %s:%d (%s)\n", \
	    __FILE__, __LINE__, __func__)
#else	/* INVARIANTS */
#define	VNASSERT(exp, vp, msg) do { \
} while (0)
#define	MPASSERT(exp, mp, msg) do { \
} while (0)
#define	VNPASS(exp, vp) do { \
} while (0)
#define	MPPASS(exp, mp) do { \
} while (0)
#define	__assert_unreachable()	__unreachable()
#endif	/* INVARIANTS */

#ifndef CTASSERT	/* Allow lint to override */
#define	CTASSERT(x)	_Static_assert(x, "compile-time assertion failed")
#endif

/*
 * These functions need to be declared before the KASSERT macro is invoked in
 * !KASSERT_PANIC_OPTIONAL builds, so their declarations are sort of out of
 * place compared to other function definitions in this header.  On the other
 * hand, this header is a bit disorganized anyway.
 */
void	panic(const char *, ...) __dead2 __printflike(1, 2);
void	vpanic(const char *, __va_list) __dead2 __printflike(1, 0);
#endif	/* _KERNEL */

#if defined(_STANDALONE)
/*
 * Until we have more experience with KASSERTS that are called
 * from the boot loader, they are off. The bootloader does this
 * a little differently than the kernel (we just call printf atm).
 * we avoid most of the common functions in the boot loader, so
 * declare printf() here too.
 */
int	printf(const char *, ...) __printflike(1, 2);
#  define kassert_panic printf
#else /* !_STANDALONE */
#  if defined(WITNESS) || defined(INVARIANT_SUPPORT)
#    ifdef KASSERT_PANIC_OPTIONAL
void	kassert_panic(const char *fmt, ...)  __printflike(1, 2);
#    else
#      define kassert_panic	panic
#    endif /* KASSERT_PANIC_OPTIONAL */
#  endif /* defined(WITNESS) || defined(INVARIANT_SUPPORT) */
#endif /* _STANDALONE */

/*
 * Kernel assertion; see KASSERT(9) for details.
 */
#if (defined(_KERNEL) && defined(INVARIANTS)) || defined(_STANDALONE)
#define	KASSERT(exp,msg) do {						\
	if (__predict_false(!(exp)))					\
		kassert_panic msg;					\
} while (0)
#else /* !(KERNEL && INVARIANTS) && !_STANDALONE */
#define	KASSERT(exp,msg) do { \
} while (0)
#endif /* (_KERNEL && INVARIANTS) || _STANDALONE */

#ifdef _KERNEL
/*
 * Macros for generating panic messages based on the exact condition text.
 *
 * NOTE: Use these with care, as the resulting message might omit key
 * information required to understand the assertion failure. Consult the
 * MPASS(9) man page for guidance.
 */
#define MPASS(ex)		MPASS4(ex, #ex, __FILE__, __LINE__)
#define MPASS2(ex, what)	MPASS4(ex, what, __FILE__, __LINE__)
#define MPASS3(ex, file, line)	MPASS4(ex, #ex, file, line)
#define MPASS4(ex, what, file, line)					\
	KASSERT((ex), ("Assertion %s failed at %s:%d", what, file, line))

/*
 * Assert that a pointer can be loaded from memory atomically.
 *
 * This assertion enforces stronger alignment than necessary.  For example,
 * on some architectures, atomicity for unaligned loads will depend on
 * whether or not the load spans multiple cache lines.
 */
#define	ASSERT_ATOMIC_LOAD_PTR(var, msg)				\
	KASSERT(sizeof(var) == sizeof(void *) &&			\
	    ((uintptr_t)&(var) & (sizeof(void *) - 1)) == 0, msg)
/*
 * Assert that a thread is in critical(9) section.
 */
#define	CRITICAL_ASSERT(td)						\
	KASSERT((td)->td_critnest >= 1, ("Not in critical section"))

#endif /* _KERNEL */

#endif	/* _SYS_KASSERT_H_ */