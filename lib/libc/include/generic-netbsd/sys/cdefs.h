/*	$NetBSD: cdefs.h,v 1.159.4.1 2024/10/13 16:15:07 martin Exp $	*/

/* * Copyright (c) 1991, 1993
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

#ifndef	_SYS_CDEFS_H_
#define	_SYS_CDEFS_H_

/*
 * Macro to test if we're using a GNU C compiler of a specific vintage
 * or later, for e.g. features that appeared in a particular version
 * of GNU C.  Usage:
 *
 *	#if __GNUC_PREREQ__(major, minor)
 *	...cool feature...
 *	#else
 *	...delete feature...
 *	#endif
 */
#ifdef __GNUC__
#define	__GNUC_PREREQ__(x, y)						\
	((__GNUC__ == (x) && __GNUC_MINOR__ >= (y)) ||			\
	 (__GNUC__ > (x)))
#else
#define	__GNUC_PREREQ__(x, y)	0
#endif

/*
 * Macros to test Clang/LLVM features.
 * Usage:
 *
 *	#if __has_feature(safe_stack)
 *	...SafeStack specific code...
 *	#else
 *	..regular code...
 *	#endif
 */
#ifndef __has_feature
#define __has_feature(x)	0
#endif

#ifndef __has_extension
#define __has_extension		__has_feature /* Compat with pre-3.0 Clang */
#endif

#include <machine/cdefs.h>
#ifdef __ELF__
#include <sys/cdefs_elf.h>
#else
#include <sys/cdefs_aout.h>
#endif

#ifdef __GNUC__
#define	__strict_weak_alias(alias,sym)					\
	__unused static __typeof__(alias) *__weak_alias_##alias = &sym;	\
	__weak_alias(alias,sym)
#else
#define	__strict_weak_alias(alias,sym) __weak_alias(alias,sym)
#endif

/*
 * Optional marker for size-optimised MD calling convention.
 */
#ifndef __compactcall
#define	__compactcall
#endif

/*
 * The __CONCAT macro is used to concatenate parts of symbol names, e.g.
 * with "#define OLD(foo) __CONCAT(old,foo)", OLD(foo) produces oldfoo.
 * The __CONCAT macro is a bit tricky -- make sure you don't put spaces
 * in between its arguments.  __CONCAT can also concatenate double-quoted
 * strings produced by the __STRING macro, but this only works with ANSI C.
 */

#define	___STRING(x)	__STRING(x)
#define	___CONCAT(x,y)	__CONCAT(x,y)

#if __STDC__ || defined(__cplusplus)
#define	__P(protos)	protos		/* full-blown ANSI C */
#define	__CONCAT(x,y)	x ## y
#define	__STRING(x)	#x

#define	__const		const		/* define reserved names to standard */
#define	__signed	signed
#define	__volatile	volatile

#define	__CONCAT3(a,b,c)		a ## b ## c
#define	__CONCAT4(a,b,c,d)		a ## b ## c ## d
#define	__CONCAT5(a,b,c,d,e)		a ## b ## c ## d ## e
#define	__CONCAT6(a,b,c,d,e,f)		a ## b ## c ## d ## e ## f
#define	__CONCAT7(a,b,c,d,e,f,g)	a ## b ## c ## d ## e ## f ## g
#define	__CONCAT8(a,b,c,d,e,f,g,h)	a ## b ## c ## d ## e ## f ## g ## h

#if defined(__cplusplus) || defined(__PCC__)
#define	__inline	inline		/* convert to C++/C99 keyword */
#else
#if !defined(__GNUC__) && !defined(__lint__)
#define	__inline			/* delete GCC keyword */
#endif /* !__GNUC__  && !__lint__ */
#endif /* !__cplusplus */

#else	/* !(__STDC__ || __cplusplus) */
#define	__P(protos)	()		/* traditional C preprocessor */
#define	__CONCAT(x,y)	x/**/y
#define	__STRING(x)	"x"

#ifndef __GNUC__
#define	__const				/* delete pseudo-ANSI C keywords */
#define	__inline
#define	__signed
#define	__volatile
#endif	/* !__GNUC__ */

/*
 * In non-ANSI C environments, new programs will want ANSI-only C keywords
 * deleted from the program and old programs will want them left alone.
 * Programs using the ANSI C keywords const, inline etc. as normal
 * identifiers should define -DNO_ANSI_KEYWORDS.
 */
#ifndef	NO_ANSI_KEYWORDS
#define	const		__const		/* convert ANSI C keywords */
#define	inline		__inline
#define	signed		__signed
#define	volatile	__volatile
#endif /* !NO_ANSI_KEYWORDS */
#endif	/* !(__STDC__ || __cplusplus) */

/*
 * Used for internal auditing of the NetBSD source tree.
 */
#ifdef __AUDIT__
#define	__aconst	__const
#else
#define	__aconst
#endif

/*
 * Compile Time Assertion.
 */
#ifdef __COUNTER__
#define	__CTASSERT(x)		__CTASSERT0(x, __ctassert, __COUNTER__)
#else
#define	__CTASSERT(x)		__CTASSERT99(x, __INCLUDE_LEVEL__, __LINE__)
#define	__CTASSERT99(x, a, b)	__CTASSERT0(x, __CONCAT(__ctassert,a), \
					       __CONCAT(_,b))
#endif
#define	__CTASSERT0(x, y, z)	__CTASSERT1(x, y, z)
#define	__CTASSERT1(x, y, z)	\
	struct y ## z ## _struct { \
		unsigned int y ## z : /*CONSTCOND*/(x) ? 1 : -1; \
	}

/*
 * The following macro is used to remove const cast-away warnings
 * from gcc -Wcast-qual; it should be used with caution because it
 * can hide valid errors; in particular most valid uses are in
 * situations where the API requires it, not to cast away string
 * constants. We don't use *intptr_t on purpose here and we are
 * explicit about unsigned long so that we don't have additional
 * dependencies.
 */
#define __UNCONST(a)	((void *)(unsigned long)(const void *)(a))

/*
 * The following macro is used to remove the volatile cast-away warnings
 * from gcc -Wcast-qual; as above it should be used with caution
 * because it can hide valid errors or warnings.  Valid uses include
 * making it possible to pass a volatile pointer to memset().
 * For the same reasons as above, we use unsigned long and not intptr_t.
 */
#define __UNVOLATILE(a)	((void *)(unsigned long)(volatile void *)(a))

/*
 * The following macro is used to remove the the function type cast warnings
 * from gcc -Wcast-function-type and as above should be used with caution.
 */
#define __FPTRCAST(t, f)	((t)(void *)(f))

/*
 * GCC2 provides __extension__ to suppress warnings for various GNU C
 * language extensions under "-ansi -pedantic".
 */
#if !__GNUC_PREREQ__(2, 0)
#define	__extension__		/* delete __extension__ if non-gcc or gcc1 */
#endif

/*
 * GCC1 and some versions of GCC2 declare dead (non-returning) and
 * pure (no side effects) functions using "volatile" and "const";
 * unfortunately, these then cause warnings under "-ansi -pedantic".
 * GCC2 uses a new, peculiar __attribute__((attrs)) style.  All of
 * these work for GNU C++ (modulo a slight glitch in the C++ grammar
 * in the distribution version of 2.5.5).
 *
 * GCC defines a pure function as depending only on its arguments and
 * global variables.  Typical examples are strlen and sqrt.
 *
 * GCC defines a const function as depending only on its arguments.
 * Therefore calling a const function again with identical arguments
 * will always produce the same result.
 *
 * Rounding modes for floating point operations are considered global
 * variables and prevent sqrt from being a const function.
 *
 * Calls to const functions can be optimised away and moved around
 * without limitations.
 */
#if !__GNUC_PREREQ__(2, 0) && !defined(__lint__)
#define __attribute__(x)
#endif

#if __GNUC_PREREQ__(2, 5) || defined(__lint__)
#define	__dead		__attribute__((__noreturn__))
#elif defined(__GNUC__)
#define	__dead		__volatile
#else
#define	__dead
#endif

#if __GNUC_PREREQ__(2, 96) || defined(__lint__)
#define	__pure		__attribute__((__pure__))
#elif defined(__GNUC__)
#define	__pure		__const
#else
#define	__pure
#endif

#if __GNUC_PREREQ__(2, 5) || defined(__lint__)
#define	__constfunc	__attribute__((__const__))
#else
#define	__constfunc
#endif

#if __GNUC_PREREQ__(3, 0) || defined(__lint__)
#define	__noinline	__attribute__((__noinline__))
#else
#define	__noinline	/* nothing */
#endif

#if __GNUC_PREREQ__(3, 0) || defined(__lint__)
#define	__always_inline	__attribute__((__always_inline__))
#else
#define	__always_inline	/* nothing */
#endif

#if __GNUC_PREREQ__(4, 0) || defined(__lint__)
#define	__null_sentinel	__attribute__((__sentinel__))
#else
#define	__null_sentinel	/* nothing */
#endif

#if __GNUC_PREREQ__(4, 1) || defined(__lint__)
#define	__returns_twice	__attribute__((__returns_twice__))
#else
#define	__returns_twice	/* nothing */
#endif

#if __GNUC_PREREQ__(4, 5) || defined(__lint__)
#define	__noclone	__attribute__((__noclone__))
#else
#define	__noclone	/* nothing */
#endif

/*
 * __unused: Note that item or function might be unused.
 */
#if __GNUC_PREREQ__(2, 7) || defined(__lint__)
#define	__unused	__attribute__((__unused__))
#else
#define	__unused	/* delete */
#endif

/*
 * __used: Note that item is needed, even if it appears to be unused.
 */
#if __GNUC_PREREQ__(3, 1) || defined(__lint__)
#define	__used		__attribute__((__used__))
#else
#define	__used		__unused
#endif

/*
 * __diagused: Note that item is used in diagnostic code, but may be
 * unused in non-diagnostic code.
 */
#if (defined(_KERNEL) && defined(DIAGNOSTIC)) \
 || (!defined(_KERNEL) && !defined(NDEBUG))
#define	__diagused	/* empty */
#else
#define	__diagused	__unused
#endif

/*
 * __debugused: Note that item is used in debug code, but may be
 * unused in non-debug code.
 */
#if defined(DEBUG)
#define	__debugused	/* empty */
#else
#define	__debugused	__unused
#endif

#if __GNUC_PREREQ__(3, 1) || defined(__lint__)
#define	__noprofile	__attribute__((__no_instrument_function__))
#else
#define	__noprofile	/* nothing */
#endif

#if __GNUC_PREREQ__(4, 6) || defined(__clang__) || defined(__lint__)
#define	__unreachable()	__builtin_unreachable()
#else
#define	__unreachable()	do {} while (/*CONSTCOND*/0)
#endif

#if defined(_KERNEL) || defined(_RUMPKERNEL)
#if defined(__clang__) && __has_feature(address_sanitizer)
#define	__noasan	__attribute__((no_sanitize("kernel-address", "address")))
#elif __GNUC_PREREQ__(4, 9) && defined(__SANITIZE_ADDRESS__)
#define	__noasan	__attribute__((no_sanitize_address))
#else
#define	__noasan	/* nothing */
#endif

#if defined(__clang__) && __has_feature(thread_sanitizer)
#define	__nocsan	__attribute__((no_sanitize("thread")))
#elif __GNUC_PREREQ__(4, 9) && defined(__SANITIZE_THREAD__)
#define	__nocsan	__attribute__((no_sanitize_thread))
#else
#define	__nocsan	/* nothing */
#endif

#if defined(__clang__) && __has_feature(memory_sanitizer)
#define	__nomsan	__attribute__((no_sanitize("kernel-memory", "memory")))
#else
#define	__nomsan	/* nothing */
#endif

#if defined(__clang__) && __has_feature(undefined_behavior_sanitizer)
#define __noubsan	__attribute__((no_sanitize("undefined")))
#elif __GNUC_PREREQ__(4, 9) && defined(__SANITIZE_UNDEFINED__)
#define __noubsan	__attribute__((no_sanitize_undefined))
#else
#define __noubsan	/* nothing */
#endif
#endif

#if defined(__COVERITY__) ||						\
    __has_feature(address_sanitizer) || defined(__SANITIZE_ADDRESS__) ||\
    __has_feature(leak_sanitizer) || defined(__SANITIZE_LEAK__)
#define	__NO_LEAKS
#endif

/*
 * To be used when an empty body is required like:
 *
 * #ifdef DEBUG
 * # define dprintf(a) printf(a)
 * #else
 * # define dprintf(a) __nothing
 * #endif
 *
 * We use ((void)0) instead of do {} while (0) so that it
 * works on , expressions.
 */
#define __nothing	(/*LINTED*/(void)0)

#if defined(__cplusplus)
#define	__BEGIN_EXTERN_C	extern "C" {
#define	__END_EXTERN_C		}
#define	__static_cast(x,y)	static_cast<x>(y)
#else
#define	__BEGIN_EXTERN_C
#define	__END_EXTERN_C
#define	__static_cast(x,y)	(x)y
#endif

#if __GNUC_PREREQ__(4, 0) || defined(__lint__)
#  define __dso_public	__attribute__((__visibility__("default")))
#  define __dso_hidden	__attribute__((__visibility__("hidden")))
#  define __BEGIN_PUBLIC_DECLS	\
	_Pragma("GCC visibility push(default)") __BEGIN_EXTERN_C
#  define __END_PUBLIC_DECLS	__END_EXTERN_C _Pragma("GCC visibility pop")
#  define __BEGIN_HIDDEN_DECLS	\
	_Pragma("GCC visibility push(hidden)") __BEGIN_EXTERN_C
#  define __END_HIDDEN_DECLS	__END_EXTERN_C _Pragma("GCC visibility pop")
#else
#  define __dso_public
#  define __dso_hidden
#  define __BEGIN_PUBLIC_DECLS	__BEGIN_EXTERN_C
#  define __END_PUBLIC_DECLS	__END_EXTERN_C
#  define __BEGIN_HIDDEN_DECLS	__BEGIN_EXTERN_C
#  define __END_HIDDEN_DECLS	__END_EXTERN_C
#endif
#if __GNUC_PREREQ__(4, 2) || defined(__lint__)
#  define __dso_protected	__attribute__((__visibility__("protected")))
#else
#  define __dso_protected
#endif

#define	__BEGIN_DECLS		__BEGIN_PUBLIC_DECLS
#define	__END_DECLS		__END_PUBLIC_DECLS

/*
 * Non-static C99 inline functions are optional bodies.  They don't
 * create global symbols if not used, but can be replaced if desirable.
 * This differs from the behavior of GCC before version 4.3.  The nearest
 * equivalent for older GCC is `extern inline'.  For newer GCC, use the
 * gnu_inline attribute additionally to get the old behavior.
 *
 * For C99 compilers other than GCC, the C99 behavior is expected.
 */
#if defined(__GNUC__) && defined(__GNUC_STDC_INLINE__)
#define	__c99inline	extern __attribute__((__gnu_inline__)) __inline
#elif defined(__GNUC__)
#define	__c99inline	extern __inline
#elif defined(__STDC_VERSION__) || defined(__lint__)
#define	__c99inline	__inline
#endif

#if defined(__lint__)
#define __thread	/* delete */
#define	__packed	__packed
#define	__aligned(x)	/* delete */
#define	__section(x)	/* delete */
#elif __GNUC_PREREQ__(2, 7) || defined(__PCC__) || defined(__lint__)
#define	__packed	__attribute__((__packed__))
#define	__aligned(x)	__attribute__((__aligned__(x)))
#define	__section(x)	__attribute__((__section__(x)))
#elif defined(_MSC_VER)
#define	__packed	/* ignore */
#else
#define	__packed	error: no __packed for this compiler
#define	__aligned(x)	error: no __aligned for this compiler
#define	__section(x)	error: no __section for this compiler
#endif

/*
 * C99 defines the restrict type qualifier keyword, which was made available
 * in GCC 2.92.
 */
#if __STDC_VERSION__ >= 199901L
#define	__restrict	restrict
#elif __GNUC_PREREQ__(2, 92)
#define	__restrict	__restrict__
#else
#define	__restrict	/* delete __restrict when not supported */
#endif

/*
 * C99 and C++11 define __func__ predefined identifier, which was made
 * available in GCC 2.95.
 */
#if !(__STDC_VERSION__ >= 199901L) && !(__cplusplus - 0 >= 201103L)
#if __GNUC_PREREQ__(2, 4) || defined(__lint__)
#define	__func__	__FUNCTION__
#else
#define	__func__	""
#endif
#endif /* !(__STDC_VERSION__ >= 199901L) && !(__cplusplus - 0 >= 201103L) */

#if defined(_KERNEL) && defined(NO_KERNEL_RCSIDS)
#undef	__KERNEL_RCSID
#define	__KERNEL_RCSID(_n, _s)	/* nothing */
#undef	__RCSID
#define	__RCSID(_s)		/* nothing */
#endif

#if !defined(_STANDALONE) && !defined(_KERNEL)
#if defined(__GNUC__) || defined(__PCC__)
#define	__RENAME(x)	___RENAME(x)
#elif defined(__lint__)
#define	__RENAME(x)	__symbolrename(x)
#else
#error "No function renaming possible"
#endif /* __GNUC__ */
#else /* _STANDALONE || _KERNEL */
#define	__RENAME(x)	no renaming in kernel/standalone environment
#endif

/*
 * A barrier to stop the optimizer from moving code or assume live
 * register values. This is gcc specific, the version is more or less
 * arbitrary, might work with older compilers.
 */
#if __GNUC_PREREQ__(2, 95) || defined(__lint__)
#define	__insn_barrier()	__asm __volatile("":::"memory")
#else
#define	__insn_barrier()	/* */
#endif

/*
 * GNU C version 2.96 adds explicit branch prediction so that
 * the CPU back-end can hint the processor and also so that
 * code blocks can be reordered such that the predicted path
 * sees a more linear flow, thus improving cache behavior, etc.
 *
 * The following two macros provide us with a way to use this
 * compiler feature.  Use __predict_true() if you expect the expression
 * to evaluate to true, and __predict_false() if you expect the
 * expression to evaluate to false.
 *
 * A few notes about usage:
 *
 *	* Generally, __predict_false() error condition checks (unless
 *	  you have some _strong_ reason to do otherwise, in which case
 *	  document it), and/or __predict_true() `no-error' condition
 *	  checks, assuming you want to optimize for the no-error case.
 *
 *	* Other than that, if you don't know the likelihood of a test
 *	  succeeding from empirical or other `hard' evidence, don't
 *	  make predictions.
 *
 *	* These are meant to be used in places that are run `a lot'.
 *	  It is wasteful to make predictions in code that is run
 *	  seldomly (e.g. at subsystem initialization time) as the
 *	  basic block reordering that this affects can often generate
 *	  larger code.
 */
#if __GNUC_PREREQ__(2, 96) || defined(__lint__)
#define	__predict_true(exp)	__builtin_expect((exp) != 0, 1)
#define	__predict_false(exp)	__builtin_expect((exp) != 0, 0)
#else
#define	__predict_true(exp)	(exp)
#define	__predict_false(exp)	(exp)
#endif

/*
 * Compiler-dependent macros to declare that functions take printf-like
 * or scanf-like arguments.  They are null except for versions of gcc
 * that are known to support the features properly (old versions of gcc-2
 * didn't permit keeping the keywords out of the application namespace).
 */
#if __GNUC_PREREQ__(2, 7) || defined(__lint__)
#define __printflike(fmtarg, firstvararg)	\
	    __attribute__((__format__ (__printf__, fmtarg, firstvararg)))
#ifndef __syslog_attribute__
#define __syslog__ __printf__
#endif
#define __sysloglike(fmtarg, firstvararg)	\
	    __attribute__((__format__ (__syslog__, fmtarg, firstvararg)))
#define __scanflike(fmtarg, firstvararg)	\
	    __attribute__((__format__ (__scanf__, fmtarg, firstvararg)))
#define __format_arg(fmtarg)    __attribute__((__format_arg__ (fmtarg)))
#else
#define __printflike(fmtarg, firstvararg)	/* nothing */
#define __scanflike(fmtarg, firstvararg)	/* nothing */
#define __sysloglike(fmtarg, firstvararg)	/* nothing */
#define __format_arg(fmtarg)			/* nothing */
#endif

/*
 * Macros for manipulating "link sets".  Link sets are arrays of pointers
 * to objects, which are gathered up by the linker.
 *
 * Object format-specific code has provided us with the following macros:
 *
 *	__link_set_add_text(set, sym)
 *		Add a reference to the .text symbol `sym' to `set'.
 *
 *	__link_set_add_rodata(set, sym)
 *		Add a reference to the .rodata symbol `sym' to `set'.
 *
 *	__link_set_add_data(set, sym)
 *		Add a reference to the .data symbol `sym' to `set'.
 *
 *	__link_set_add_bss(set, sym)
 *		Add a reference to the .bss symbol `sym' to `set'.
 *
 *	__link_set_decl(set, ptype)
 *		Provide an extern declaration of the set `set', which
 *		contains an array of pointers to type `ptype'.  This
 *		macro must be used by any code which wishes to reference
 *		the elements of a link set.
 *
 *	__link_set_start(set)
 *		This points to the first slot in the link set.
 *
 *	__link_set_end(set)
 *		This points to the (non-existent) slot after the last
 *		entry in the link set.
 *
 *	__link_set_count(set)
 *		Count the number of entries in link set `set'.
 *
 * In addition, we provide the following macros for accessing link sets:
 *
 *	__link_set_foreach(pvar, set)
 *		Iterate over the link set `set'.  Because a link set is
 *		an array of pointers, pvar must be declared as "type **pvar",
 *		and the actual entry accessed as "*pvar".
 *
 *	__link_set_entry(set, idx)
 *		Access the link set entry at index `idx' from set `set'.
 */
#define	__link_set_foreach(pvar, set)					\
	for (pvar = __link_set_start(set); pvar < __link_set_end(set); pvar++)

#define	__link_set_entry(set, idx)	(__link_set_start(set)[idx])

/*
 * Return the natural alignment in bytes for the given type
 */
#if __GNUC_PREREQ__(4, 1) || defined(__lint__)
#define	__alignof(__t)  __alignof__(__t)
#else
#define __alignof(__t) (sizeof(struct { char __x; __t __y; }) - sizeof(__t))
#endif

/*
 * Return the number of elements in a statically-allocated array,
 * __x.
 */
#define	__arraycount(__x)	(sizeof(__x) / sizeof(__x[0]))

#ifndef __ASSEMBLER__
/* __BIT(n): nth bit, where __BIT(0) == 0x1. */
#define	__BIT(__n)							      \
	(((__UINTMAX_TYPE__)(__n) >= __CHAR_BIT__ * sizeof(__UINTMAX_TYPE__)) \
	    ? 0								      \
	    : ((__UINTMAX_TYPE__)1 <<					      \
		(__UINTMAX_TYPE__)((__n) &				      \
		    (__CHAR_BIT__ * sizeof(__UINTMAX_TYPE__) - 1))))

/* __MASK(n): first n bits all set, where __MASK(4) == 0b1111. */
#define	__MASK(__n)	(__BIT(__n) - 1)

/* Macros for min/max. */
#define	__MIN(a,b)	((/*CONSTCOND*/(a)<=(b))?(a):(b))
#define	__MAX(a,b)	((/*CONSTCOND*/(a)>(b))?(a):(b))

/* __BITS(m, n): bits m through n, m < n. */
#define	__BITS(__m, __n)	\
	((__BIT(__MAX((__m), (__n)) + 1) - 1) ^ (__BIT(__MIN((__m), (__n))) - 1))
#endif /* !__ASSEMBLER__ */

/* find least significant bit that is set */
#define	__LOWEST_SET_BIT(__mask) ((((__mask) - 1) & (__mask)) ^ (__mask))

#define	__PRIuBIT	PRIuMAX
#define	__PRIuBITS	__PRIuBIT

#define	__PRIxBIT	PRIxMAX
#define	__PRIxBITS	__PRIxBIT

#define	__SHIFTOUT(__x, __mask)	(((__x) & (__mask)) / __LOWEST_SET_BIT(__mask))
#define	__SHIFTIN(__x, __mask) ((__x) * __LOWEST_SET_BIT(__mask))
#define	__SHIFTOUT_MASK(__mask) __SHIFTOUT((__mask), (__mask))

/*
 * Only to be used in other headers that are included from both c or c++
 * NOT to be used in code.
 */
#ifdef __cplusplus
#define __CAST(__dt, __st)	static_cast<__dt>(__st)
#else
#define __CAST(__dt, __st)	((__dt)(__st))
#endif

#define __CASTV(__dt, __st)	__CAST(__dt, __CAST(void *, __st))
#define __CASTCV(__dt, __st)	__CAST(__dt, __CAST(const void *, __st))

#define __USE(a) (/*LINTED*/(void)(a))

#define __type_mask(t) (/*LINTED*/sizeof(t) < sizeof(__INTMAX_TYPE__) ? \
    (~((1ULL << (sizeof(t) * __CHAR_BIT__)) - 1)) : 0ULL)

#ifndef __ASSEMBLER__
static __inline long long __zeroll(void) { return 0; }
static __inline unsigned long long __zeroull(void) { return 0; }
#else
#define __zeroll() (0LL)
#define __zeroull() (0ULL)
#endif

#define __negative_p(x) (!((x) > 0) && ((x) != 0))

#define __type_min_s(t) ((t)((1ULL << (sizeof(t) * __CHAR_BIT__ - 1))))
#define __type_max_s(t) ((t)~((1ULL << (sizeof(t) * __CHAR_BIT__ - 1))))
#define __type_min_u(t) ((t)0ULL)
#define __type_max_u(t) ((t)~0ULL)
#define __type_is_signed(t) (/*LINTED*/__type_min_s(t) + (t)1 < (t)1)
#define __type_min(t) (__type_is_signed(t) ? __type_min_s(t) : __type_min_u(t))
#define __type_max(t) (__type_is_signed(t) ? __type_max_s(t) : __type_max_u(t))


#define __type_fit_u(t, a)						      \
	(/*LINTED*/!__negative_p(a) &&					      \
	    ((__UINTMAX_TYPE__)((a) + __zeroull()) <=			      \
		(__UINTMAX_TYPE__)__type_max_u(t)))

#define __type_fit_s(t, a)						      \
	(/*LINTED*/__negative_p(a)					      \
	    ? ((__INTMAX_TYPE__)((a) + __zeroll()) >=			      \
		(__INTMAX_TYPE__)__type_min_s(t))			      \
	    : ((__INTMAX_TYPE__)((a) + __zeroll()) >= (__INTMAX_TYPE__)0 &&   \
		((__INTMAX_TYPE__)((a) + __zeroll()) <=			      \
		    (__INTMAX_TYPE__)__type_max_s(t))))

/*
 * return true if value 'a' fits in type 't'
 */
#define __type_fit(t, a) (__type_is_signed(t) ? \
    __type_fit_s(t, a) : __type_fit_u(t, a))

#endif /* !_SYS_CDEFS_H_ */