/*-
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
 */

#ifndef	_SYS_CDEFS_H_
#define	_SYS_CDEFS_H_

#if defined(_KERNEL) && defined(_STANDALONE)
#error "_KERNEL and _STANDALONE are mutually exclusive"
#endif

/*
 * Provide clang-compatible testing macros. All supported versions of gcc (10+)
 * provide all of these except has_feature and has_extension which are new in
 * gcc 14. Keep the older ifndefs, though, for non-gcc compilers that may lack
 * them like tcc and pcc.
 */
#ifndef	__has_attribute
#define	__has_attribute(x)	0
#endif
#ifndef	__has_extension
#define	__has_extension		__has_feature
#endif
#ifndef	__has_feature
#define	__has_feature(x)	0
#endif
#ifndef	__has_include
#define	__has_include(x)	0
#endif
#ifndef	__has_builtin
#define	__has_builtin(x)	0
#endif

#if defined(__cplusplus)
#define	__BEGIN_DECLS	extern "C" {
#define	__END_DECLS	}
#else
#define	__BEGIN_DECLS
#define	__END_DECLS
#endif

/*
 * This code has been put in place to help reduce the addition of
 * compiler specific defines in FreeBSD code.  It helps to aid in
 * having a compiler-agnostic source tree.
 */

/*
 * Macro to test if we're using a specific version of gcc or later.
 */
#if defined(__GNUC__)
#define	__GNUC_PREREQ__(ma, mi)	\
	(__GNUC__ > (ma) || __GNUC__ == (ma) && __GNUC_MINOR__ >= (mi))
#else
#define	__GNUC_PREREQ__(ma, mi)	0
#endif

#if defined(__GNUC__)

/*
 * Compiler memory barriers, specific to gcc and clang.
 */
#define	__compiler_membar()	__asm __volatile(" " : : : "memory")

#define	__CC_SUPPORTS___INLINE 1
#define	__CC_SUPPORTS_SYMVER 1

#endif /* __GNUC__ */

/*
 * TinyC pretends to be gcc 9.3. This is generally good enough to support
 * everything FreeBSD... except for the .symver assembler directive.
 */
#ifdef __TINYC__
#undef	__CC_SUPPORTS_SYMVER
#endif

/*
 * The __CONCAT macro is used to concatenate parts of symbol names, e.g.
 * with "#define OLD(foo) __CONCAT(old,foo)", OLD(foo) produces oldfoo.
 * The __CONCAT macro is a bit tricky to use if it must work in non-ANSI
 * mode -- there must be no spaces between its arguments, and for nested
 * __CONCAT's, all the __CONCAT's must be at the left.  __CONCAT can also
 * concatenate double-quoted strings produced by the __STRING macro, but
 * this only works with ANSI C.
 *
 * __XSTRING is like __STRING, but it expands any macros in its argument
 * first.  It is only available with ANSI C.
 */
#if defined(__STDC__) || defined(__cplusplus)
#define	__P(protos)	protos		/* full-blown ANSI C */
#define	__CONCAT1(x,y)	x ## y
#define	__CONCAT(x,y)	__CONCAT1(x,y)
#define	__STRING(x)	#x		/* stringify without expanding x */
#define	__XSTRING(x)	__STRING(x)	/* expand x, then stringify */

#define	__volatile	volatile
#if defined(__cplusplus)
#define	__inline	inline		/* convert to C++ keyword */
#else
#if !(defined(__CC_SUPPORTS___INLINE))
#define	__inline			/* delete GCC keyword */
#endif /* ! __CC_SUPPORTS___INLINE */
#endif /* !__cplusplus */

#else	/* !(__STDC__ || __cplusplus) */
#define	__P(protos)	()		/* traditional C preprocessor */
#define	__CONCAT(x,y)	x/**/y
#define	__STRING(x)	"x"
#if !defined(__CC_SUPPORTS___INLINE)
/* Just delete these in a K&R environment */
#define	__inline
#define	__volatile
#endif	/* !__CC_SUPPORTS___INLINE */
#endif	/* !(__STDC__ || __cplusplus) */

/*
 * Compiler-dependent macros to help declare dead (non-returning) and pure (no
 * side effects) functions, and unused variables. These attributes are supported
 * by all current compilers, even pcc.
 */
#define	__weak_symbol	__attribute__((__weak__))
#define	__dead2		__attribute__((__noreturn__))
#define	__pure2		__attribute__((__const__))
#define	__unused	__attribute__((__unused__))
#define	__used		__attribute__((__used__))
#define __deprecated	__attribute__((__deprecated__))
#define __deprecated1(msg)	__attribute__((__deprecated__(msg)))
#define	__packed	__attribute__((__packed__))
#define	__aligned(x)	__attribute__((__aligned__(x)))
#define	__section(x)	__attribute__((__section__(x)))
#define	__writeonly	__unused
#define	__alloc_size(x)	__attribute__((__alloc_size__(x)))
#define	__alloc_size2(n, x)	__attribute__((__alloc_size__(n, x)))
#define	__alloc_align(x)	__attribute__((__alloc_align__(x)))

/*
 * Keywords added in C11.
 */

#if !defined(__STDC_VERSION__) || __STDC_VERSION__ < 201112L

#if !__has_extension(c_alignas)
#if (defined(__cplusplus) && __cplusplus >= 201103L) || \
    __has_extension(cxx_alignas)
#define	_Alignas(x)		alignas(x)
#else
/* XXX: Only emulates _Alignas(constant-expression); not _Alignas(type-name). */
#define	_Alignas(x)		__aligned(x)
#endif
#endif

#if defined(__cplusplus) && __cplusplus >= 201103L
#define	_Alignof(x)		alignof(x)
#else
#define	_Alignof(x)		__alignof(x)
#endif

#if defined(__cplusplus) && __cplusplus >= 201103L
#define	_Noreturn		[[noreturn]]
#else
#define	_Noreturn		__dead2
#endif

#if !__has_extension(c_static_assert)
#if (defined(__cplusplus) && __cplusplus >= 201103L) || \
    __has_extension(cxx_static_assert)
#define	_Static_assert(x, y)	static_assert(x, y)
#endif
#endif

#if !__has_extension(c_thread_local)
#if (defined(__cplusplus) && __cplusplus >= 201103L) || \
    __has_extension(cxx_thread_local)
#define	_Thread_local		thread_local
#else
#define	_Thread_local		__thread
#endif
#endif

#endif /* __STDC_VERSION__ || __STDC_VERSION__ < 201112L */

/*
 * Emulation of C11 _Generic().  Unlike the previously defined C11
 * keywords, it is not possible to implement this using exactly the same
 * syntax.  Therefore implement something similar under the name
 * __generic().  Unlike _Generic(), this macro can only distinguish
 * between a single type, so it requires nested invocations to
 * distinguish multiple cases.
 *
 * Note that the comma operator is used to force expr to decay in
 * order to match _Generic().
 */

#if (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L) || \
    __has_extension(c_generic_selections)
#define	__generic(expr, t, yes, no)					\
	_Generic(expr, t: yes, default: no)
#elif !defined(__cplusplus)
#define	__generic(expr, t, yes, no)					\
	__builtin_choose_expr(__builtin_types_compatible_p(		\
	    __typeof(((void)0, (expr))), t), yes, no)
#endif

/*
 * C99 Static array indices in function parameter declarations.  Syntax such as:
 * void bar(int myArray[static 10]);
 * is allowed in C99 but not in C++.  Define __min_size appropriately so
 * headers using it can be compiled in either language.  Use like this:
 * void bar(int myArray[__min_size(10)]);
 */
#if !defined(__cplusplus) && \
    (!defined(__STDC_VERSION__) || (__STDC_VERSION__ >= 199901))
#define __min_size(x)	static (x)
#else
#define __min_size(x)	(x)
#endif

#define	__malloc_like	__attribute__((__malloc__))
#define	__pure		__attribute__((__pure__))

#define	__always_inline	__inline __attribute__((__always_inline__))
#define	__noinline	__attribute__ ((__noinline__))
#define	__fastcall	__attribute__((__fastcall__))
#define	__result_use_check	__attribute__((__warn_unused_result__))
#define	__returns_twice	__attribute__((__returns_twice__))

#define	__unreachable()	__builtin_unreachable()

#if !defined(__STRICT_ANSI__) || __STDC_VERSION__ >= 199901
#define	__LONG_LONG_SUPPORTED
#endif

/* C++11 exposes a load of C99 stuff */
#if defined(__cplusplus) && __cplusplus >= 201103L
#define	__LONG_LONG_SUPPORTED
#ifndef	__STDC_LIMIT_MACROS
#define	__STDC_LIMIT_MACROS
#endif
#ifndef	__STDC_CONSTANT_MACROS
#define	__STDC_CONSTANT_MACROS
#endif
#endif

/*
 * noexcept keyword added in C++11.
 */
#if defined(__cplusplus) && __cplusplus >= 201103L
#define __noexcept noexcept
#define __noexcept_if(__c) noexcept(__c)
#else
#define __noexcept
#define __noexcept_if(__c)
#endif

/*
 * nodiscard attribute added in C++17 and C23, but supported by both LLVM and
 * GCC in earlier language versions, so we use __has_c{,pp}_attribute to test
 * for it.
 *
 * __nodiscard may be used on a function:
 * 	__nodiscard int f();
 *
 * or on a struct, union or enum:
 * 	struct __nodiscard S{};
 * 	struct S f();
 *
 * or in C++, on an object constructor.
 */

#if defined(__cplusplus) && defined(__has_cpp_attribute)
#if __has_cpp_attribute(nodiscard)
#define	__nodiscard	[[nodiscard]]
#endif
#elif defined(__STDC_VERSION__) && defined(__has_c_attribute)
#if __has_c_attribute(__nodiscard__)
#define	__nodiscard	[[__nodiscard__]]
#endif
#endif

#ifndef __nodiscard
/*
 * LLVM 16 and earlier don't support [[nodiscard]] in C, but they do support
 * __warn_unused_result__ with the same semantics, so fall back to that.
 * We can't do this for GCC because the semantics are different.
 */
#ifdef __clang__
#define	__nodiscard	__attribute__((__warn_unused_result__))
#else
#define	__nodiscard
#endif
#endif

/*
 * We use `__restrict' as a way to define the `restrict' type qualifier
 * without disturbing older software that is unaware of C99 keywords.
 * GCC also provides `__restrict' as an extension to support C99-style
 * restricted pointers in other language modes.
 */
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901
#define	__restrict	restrict
#endif

/*
 * All modern compilers have explicit branch prediction so that the CPU back-end
 * can hint to the processor and also so that code blocks can be reordered such
 * that the predicted path sees a more linear flow, thus improving cache
 * behavior, etc. Use sparingly, except in performance critical code where
 * they make things measurably faster.
 */
#define	__predict_true(exp)     __builtin_expect((exp), 1)
#define	__predict_false(exp)    __builtin_expect((exp), 0)

#define	__null_sentinel	__attribute__((__sentinel__))
#define	__exported	__attribute__((__visibility__("default")))
#define	__hidden	__attribute__((__visibility__("hidden")))

/*
 * We define this here since <stddef.h>, <sys/queue.h>, and <sys/types.h>
 * require it.
 */
#define	__offsetof(type, field)	 __builtin_offsetof(type, field)
#define	__rangeof(type, start, end) \
	(__offsetof(type, end) - __offsetof(type, start))

/*
 * Given the pointer x to the member m of the struct s, return
 * a pointer to the containing structure.  When using GCC, we first
 * assign pointer x to a local variable, to check that its type is
 * compatible with member m.
 */
#define	__containerof(x, s, m) ({					\
	const volatile __typeof(((s *)0)->m) *__x = (x);		\
	__DEQUALIFY(s *, (const volatile char *)__x - __offsetof(s, m));\
})

/*
 * Compiler-dependent macros to declare that functions take printf-like
 * or scanf-like arguments.
 */
#define	__printflike(fmtarg, firstvararg) \
	    __attribute__((__format__ (__printf__, fmtarg, firstvararg)))
#define	__scanflike(fmtarg, firstvararg) \
	    __attribute__((__format__ (__scanf__, fmtarg, firstvararg)))
#define	__format_arg(fmtarg)	__attribute__((__format_arg__ (fmtarg)))
#define	__strfmonlike(fmtarg, firstvararg) \
	    __attribute__((__format__ (__strfmon__, fmtarg, firstvararg)))
#define	__strftimelike(fmtarg, firstvararg) \
	    __attribute__((__format__ (__strftime__, fmtarg, firstvararg)))

/*
 * Like __printflike, but allows fmtarg to be NULL. FreeBSD invented 'printf0'
 * for this because older versions of gcc issued warnings for NULL first args.
 * Clang has always had printf and printf0 as aliases. gcc 11.0 now follows
 * clang. So now this is an alias for __printflike, or nothing. In the future
 * _Nullable or _Nonnull will replace this.
 * XXX Except that doesn't work, so for now revert to printf0 for clang and
 * the FreeBSD gcc until I can work this out.
 */
#if defined(__clang__) || (defined(__GNUC__) && defined (__FreeBSD_cc_version))
#define	__printf0like(fmtarg, firstvararg) \
	    __attribute__((__format__ (__printf0__, fmtarg, firstvararg)))
#else
#define	__printf0like(fmtarg, firstvararg)
#endif

#define	__strong_reference(sym,aliassym)	\
	extern __typeof (sym) aliassym __attribute__ ((__alias__ (#sym)))
#ifdef __STDC__
#define	__weak_reference(sym,alias)	\
	__asm__(".weak " #alias);	\
	__asm__(".equ "  #alias ", " #sym)
#define	__warn_references(sym,msg)	\
	__asm__(".section .gnu.warning." #sym);	\
	__asm__(".asciz \"" msg "\"");	\
	__asm__(".previous")
#ifdef	__CC_SUPPORTS_SYMVER
#define	__sym_compat(sym,impl,verid)	\
	__asm__(".symver " #impl ", " #sym "@" #verid)
#define	__sym_default(sym,impl,verid)	\
	__asm__(".symver " #impl ", " #sym "@@@" #verid)
#endif
#else
#define	__weak_reference(sym,alias)	\
	__asm__(".weak alias");		\
	__asm__(".equ alias, sym")
#define	__warn_references(sym,msg)	\
	__asm__(".section .gnu.warning.sym"); \
	__asm__(".asciz \"msg\"");	\
	__asm__(".previous")
#ifdef	__CC_SUPPORTS_SYMVER
#define	__sym_compat(sym,impl,verid)	\
	__asm__(".symver impl, sym@verid")
#define	__sym_default(impl,sym,verid)	\
	__asm__(".symver impl, sym@@@verid")
#endif
#endif	/* __STDC__ */

#define	__GLOBL(sym)	__asm__(".globl " __XSTRING(sym))
#define	__WEAK(sym)	__asm__(".weak " __XSTRING(sym))

#define	__IDSTRING(name,string)	__asm__(".ident\t\"" string "\"")

/*
 * Embed the rcs id of a source file in the resulting library.  Note that in
 * more recent ELF binutils, we use .ident allowing the ID to be stripped.
 * Usage:
 */
#ifndef	__FBSDID
#if !defined(STRIP_FBSDID)
#define	__FBSDID(s)	__IDSTRING(__CONCAT(__rcsid_,__LINE__),s)
#else
#define	__FBSDID(s)	struct __hack
#endif
#endif

#ifndef	__RCSID
#ifndef	NO__RCSID
#define	__RCSID(s)	__IDSTRING(__CONCAT(__rcsid_,__LINE__),s)
#else
#define	__RCSID(s)	struct __hack
#endif
#endif

#ifndef	__RCSID_SOURCE
#ifndef	NO__RCSID_SOURCE
#define	__RCSID_SOURCE(s)	__IDSTRING(__CONCAT(__rcsid_source_,__LINE__),s)
#else
#define	__RCSID_SOURCE(s)	struct __hack
#endif
#endif

#ifndef	__SCCSID
#ifndef	NO__SCCSID
#define	__SCCSID(s)	__IDSTRING(__CONCAT(__sccsid_,__LINE__),s)
#else
#define	__SCCSID(s)	struct __hack
#endif
#endif

#ifndef	__COPYRIGHT
#ifndef	NO__COPYRIGHT
#define	__COPYRIGHT(s)	__IDSTRING(__CONCAT(__copyright_,__LINE__),s)
#else
#define	__COPYRIGHT(s)	struct __hack
#endif
#endif

#ifndef	__DECONST
#define	__DECONST(type, var)	((type)(__uintptr_t)(const void *)(var))
#endif

#ifndef	__DEVOLATILE
#define	__DEVOLATILE(type, var)	((type)(__uintptr_t)(volatile void *)(var))
#endif

#ifndef	__DEQUALIFY
#define	__DEQUALIFY(type, var)	((type)(__uintptr_t)(const volatile void *)(var))
#endif

#if !defined(_STANDALONE) && !defined(_KERNEL)
#define	__RENAME(x)	__asm(__STRING(x))
#else /* _STANDALONE || _KERNEL */
#define	__RENAME(x)	no renaming in kernel/standalone environment
#endif

#include <sys/_visible.h>

/*
 * Nullability qualifiers: currently only supported by Clang.
 */
#if !(defined(__clang__) && __has_feature(nullability))
#define	_Nonnull
#define	_Nullable
#define	_Null_unspecified
#define	__NULLABILITY_PRAGMA_PUSH
#define	__NULLABILITY_PRAGMA_POP
#else
#define	__NULLABILITY_PRAGMA_PUSH _Pragma("clang diagnostic push")	\
	_Pragma("clang diagnostic ignored \"-Wnullability-completeness\"")
#define	__NULLABILITY_PRAGMA_POP _Pragma("clang diagnostic pop")
#endif

/*
 * Type Safety Checking
 *
 * Clang provides additional attributes to enable checking type safety
 * properties that cannot be enforced by the C type system. 
 */

#if __has_attribute(__argument_with_type_tag__) && \
    __has_attribute(__type_tag_for_datatype__)
#define	__arg_type_tag(arg_kind, arg_idx, type_tag_idx) \
	    __attribute__((__argument_with_type_tag__(arg_kind, arg_idx, type_tag_idx)))
#define	__datatype_type_tag(kind, type) \
	    __attribute__((__type_tag_for_datatype__(kind, type)))
#else
#define	__arg_type_tag(arg_kind, arg_idx, type_tag_idx)
#define	__datatype_type_tag(kind, type)
#endif

/*
 * Lock annotations.
 *
 * Clang provides support for doing basic thread-safety tests at
 * compile-time, by marking which locks will/should be held when
 * entering/leaving a functions.
 *
 * Furthermore, it is also possible to annotate variables and structure
 * members to enforce that they are only accessed when certain locks are
 * held.
 */

#if __has_extension(c_thread_safety_attributes)
#define	__lock_annotate(x)	__attribute__((x))
#else
#define	__lock_annotate(x)
#endif

/* Structure implements a lock. */
#define	__lockable		__lock_annotate(lockable)

/* Function acquires an exclusive or shared lock. */
#define	__locks_exclusive(...) \
	__lock_annotate(exclusive_lock_function(__VA_ARGS__))
#define	__locks_shared(...) \
	__lock_annotate(shared_lock_function(__VA_ARGS__))

/* Function attempts to acquire an exclusive or shared lock. */
#define	__trylocks_exclusive(...) \
	__lock_annotate(exclusive_trylock_function(__VA_ARGS__))
#define	__trylocks_shared(...) \
	__lock_annotate(shared_trylock_function(__VA_ARGS__))

/* Function releases a lock. */
#define	__unlocks(...)		__lock_annotate(unlock_function(__VA_ARGS__))

/* Function asserts that an exclusive or shared lock is held. */
#define	__asserts_exclusive(...) \
	__lock_annotate(assert_exclusive_lock(__VA_ARGS__))
#define	__asserts_shared(...) \
	__lock_annotate(assert_shared_lock(__VA_ARGS__))

/* Function requires that an exclusive or shared lock is or is not held. */
#define	__requires_exclusive(...) \
	__lock_annotate(exclusive_locks_required(__VA_ARGS__))
#define	__requires_shared(...) \
	__lock_annotate(shared_locks_required(__VA_ARGS__))
#define	__requires_unlocked(...) \
	__lock_annotate(locks_excluded(__VA_ARGS__))

/* Function should not be analyzed. */
#define	__no_lock_analysis	__lock_annotate(no_thread_safety_analysis)

/*
 * Function or variable should not be sanitized, e.g., by AddressSanitizer.
 * GCC has the nosanitize attribute, but as a function attribute only, and
 * warns on use as a variable attribute.
 */
#if __has_feature(address_sanitizer) && defined(__clang__)
#ifdef _KERNEL
#define	__nosanitizeaddress	__attribute__((no_sanitize("kernel-address")))
#else
#define	__nosanitizeaddress	__attribute__((no_sanitize("address")))
#endif
#else
#define	__nosanitizeaddress
#endif
#if __has_feature(coverage_sanitizer) && defined(__clang__)
#define	__nosanitizecoverage	__attribute__((no_sanitize("coverage")))
#else
#define	__nosanitizecoverage
#endif
#if __has_feature(memory_sanitizer) && defined(__clang__)
#ifdef _KERNEL
#define	__nosanitizememory	__attribute__((no_sanitize("kernel-memory")))
#else
#define	__nosanitizememory	__attribute__((no_sanitize("memory")))
#endif
#else
#define	__nosanitizememory
#endif
#if __has_feature(thread_sanitizer) && defined(__clang__)
#define	__nosanitizethread	__attribute__((no_sanitize("thread")))
#else
#define	__nosanitizethread
#endif

/*
 * Make it possible to opt out of stack smashing protection.
 */
#if __has_attribute(no_stack_protector)
#define	__nostackprotector	__attribute__((no_stack_protector))
#else
#define	__nostackprotector	\
	__attribute__((__optimize__("-fno-stack-protector")))
#endif

/* Guard variables and structure members by lock. */
#define	__guarded_by(x)		__lock_annotate(guarded_by(x))
#define	__pt_guarded_by(x)	__lock_annotate(pt_guarded_by(x))

/* Alignment builtins for better type checking and improved code generation. */
/* Provide fallback versions for other compilers (GCC/Clang < 10): */
#if !__has_builtin(__builtin_is_aligned)
#define __builtin_is_aligned(x, align)	\
	(((__uintptr_t)(x) & ((align) - 1)) == 0)
#endif
#if !__has_builtin(__builtin_align_up)
#define __builtin_align_up(x, align)	\
	((__typeof__(x))(((__uintptr_t)(x)+((align)-1))&(~((align)-1))))
#endif
#if !__has_builtin(__builtin_align_down)
#define __builtin_align_down(x, align)	\
	((__typeof__(x))((x)&(~((align)-1))))
#endif

#define __align_up(x, y) __builtin_align_up(x, y)
#define __align_down(x, y) __builtin_align_down(x, y)
#define __is_aligned(x, y) __builtin_is_aligned(x, y)

#endif /* !_SYS_CDEFS_H_ */