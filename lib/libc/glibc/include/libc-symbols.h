/* Support macros for making weak and strong aliases for symbols,
   and for using symbol sets and linker warnings with GNU ld.
   Copyright (C) 1995-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _LIBC_SYMBOLS_H
#define _LIBC_SYMBOLS_H	1

/* This file is included implicitly in the compilation of every source file,
   using -include.  It includes config.h.  */

/* Enable declarations of GNU extensions, since we are compiling them.  */
#define _GNU_SOURCE 1

#ifdef MODULE_NAME

/* Use `#if IS_IN (module)` to detect what component is being compiled.  */
#define PASTE_NAME1(a,b) a##b
#define PASTE_NAME(a,b)	 PASTE_NAME1 (a,b)
#define IN_MODULE	 PASTE_NAME (MODULE_, MODULE_NAME)
#define IS_IN(lib)	 (IN_MODULE == MODULE_##lib)

/* True if the current module is a versioned library.  Versioned
   library names culled from shlib-versions files are assigned a
   MODULE_* value greater than MODULE_LIBS_BEGIN.  */
#define IS_IN_LIB	 (IN_MODULE > MODULE_LIBS_BEGIN)

/* The testsuite, and some other ancillary code, should be compiled against
   as close an approximation to the installed headers as possible.
   Defining this symbol disables most internal-use-only declarations
   provided by this header, and all those provided by other internal
   wrapper headers.  */
#if IS_IN (testsuite) || defined IS_IN_build || defined __cplusplus
# define _ISOMAC 1
#endif

#else
/* The generation process for a few files created very early in the
   build (notably libc-modules.h itself) involves preprocessing this
   header without defining MODULE_NAME.  Under these conditions,
   internal declarations (especially from config.h) must be visible,
   but IS_IN should always evaluate as false.  */
# define IS_IN(lib) 0
# define IS_IN_LIB 0
# define IN_MODULE (-1)
#endif

#include <libc-misc.h>

#ifndef _ISOMAC

/* This is defined for the compilation of all C library code.  features.h
   tests this to avoid inclusion of stubs.h while compiling the library,
   before stubs.h has been generated.  Some library code that is shared
   with other packages also tests this symbol to see if it is being
   compiled as part of the C library.  We must define this before including
   config.h, because it makes some definitions conditional on whether libc
   itself is being compiled, or just some generator program.  */
#define _LIBC	1

/* Some files must be compiled with optimization on.  */
#if !defined __ASSEMBLER__ && !defined __OPTIMIZE__
# error "glibc cannot be compiled without optimization"
#endif

/* -ffast-math cannot be applied to the C library, as it alters the ABI.
   Some test components that use -ffast-math are currently not part of
   IS_IN (testsuite) for technical reasons, so we have a secondary override.  */
#if defined __FAST_MATH__ && !defined TEST_FAST_MATH
# error "glibc must not be compiled with -ffast-math"
#endif

/* Obtain the definition of symbol_version_reference.  */
#include <libc-symver.h>

/* When PIC is defined and SHARED isn't defined, we are building PIE
   by default.  */
#if defined PIC && !defined SHARED
# define BUILD_PIE_DEFAULT 1
#else
# define BUILD_PIE_DEFAULT 0
#endif

/* Define this for the benefit of portable GNU code that wants to check it.
   Code that checks with #if will not #include <config.h> again, since we've
   already done it (and this file is implicitly included in every compile,
   via -include).  Code that checks with #ifdef will #include <config.h>,
   but that file should always be idempotent (i.e., it's just #define/#undef
   and nothing else anywhere should be changing the macro state it touches),
   so it's harmless.  */
#define HAVE_CONFIG_H	0

/* Define these macros for the benefit of portable GNU code that wants to check
   them.  Of course, STDC_HEADERS is never false when building libc!  */
#define STDC_HEADERS	1
#define HAVE_MBSTATE_T	1
#define HAVE_MBSRTOWCS	1
#define HAVE_LIBINTL_H	1
#define HAVE_WCTYPE_H	1
#define HAVE_ISWCTYPE	1
#define ENABLE_NLS	1

/* The symbols in all the user (non-_) macros are C symbols.  */

#ifndef __SYMBOL_PREFIX
# define __SYMBOL_PREFIX
#endif

#ifndef C_SYMBOL_NAME
# define C_SYMBOL_NAME(name) name
#endif

#ifndef ASM_LINE_SEP
# define ASM_LINE_SEP ;
#endif

#ifndef __attribute_copy__
/* Provide an empty definition when cdefs.h is not included.  */
# define __attribute_copy__(arg)
#endif

#ifndef __ASSEMBLER__
/* GCC understands weak symbols and aliases; use its interface where
   possible, instead of embedded assembly language.  */

/* Define ALIASNAME as a strong alias for NAME.  */
# define strong_alias(name, aliasname) _strong_alias(name, aliasname)
# define _strong_alias(name, aliasname) \
  extern __typeof (name) aliasname __attribute__ ((alias (#name))) \
    __attribute_copy__ (name);

/* This comes between the return type and function name in
   a function definition to make that definition weak.  */
# define weak_function __attribute__ ((weak))
# define weak_const_function __attribute__ ((weak, __const__))

/* Define ALIASNAME as a weak alias for NAME.
   If weak aliases are not available, this defines a strong alias.  */
# define weak_alias(name, aliasname) _weak_alias (name, aliasname)
# define _weak_alias(name, aliasname) \
  extern __typeof (name) aliasname __attribute__ ((weak, alias (#name))) \
    __attribute_copy__ (name);

/* Zig patch.  weak_hidden_alias was removed from glibc v2.36 (v2.37?), Zig
   needs it for the v2.32 and earlier {f,l,}stat wrappers, so only include
   in this header for 2.32 and earlier. */
#if (__GLIBC__ == 2 && __GLIBC_MINOR__ <= 32) || __GLIBC__ < 2
# define weak_hidden_alias(name, aliasname) \
  _weak_hidden_alias (name, aliasname)
# define _weak_hidden_alias(name, aliasname) \
  extern __typeof (name) aliasname \
    __attribute__ ((weak, alias (#name), __visibility__ ("hidden"))) \
    __attribute_copy__ (name);
#endif

/* Declare SYMBOL as weak undefined symbol (resolved to 0 if not defined).  */
# define weak_extern(symbol) _weak_extern (weak symbol)
# define _weak_extern(expr) _Pragma (#expr)

/* In shared builds, the expression call_function_static_weak
   (FUNCTION-SYMBOL, ARGUMENTS) invokes FUNCTION-SYMBOL (an
   identifier) unconditionally, with the (potentially empty) argument
   list ARGUMENTS.  In static builds, if FUNCTION-SYMBOL has a
   definition, the function is invoked as before; if FUNCTION-SYMBOL
   is NULL, no call is performed.  */
# ifdef SHARED
#  define call_function_static_weak(func, ...) func (__VA_ARGS__)
# else	/* !SHARED */
#  define call_function_static_weak(func, ...)		\
  ({							\
    extern __typeof__ (func) func weak_function;	\
    (func != NULL ? func (__VA_ARGS__) : (void)0);	\
  })
# endif

#else /* __ASSEMBLER__ */

# ifdef HAVE_ASM_SET_DIRECTIVE
#  define strong_alias(original, alias)				\
  .globl C_SYMBOL_NAME (alias) ASM_LINE_SEP		\
  .set C_SYMBOL_NAME (alias),C_SYMBOL_NAME (original)
#  define strong_data_alias(original, alias) strong_alias(original, alias)
# else
#  define strong_alias(original, alias)				\
  .globl C_SYMBOL_NAME (alias) ASM_LINE_SEP		\
  C_SYMBOL_NAME (alias) = C_SYMBOL_NAME (original)
#  define strong_data_alias(original, alias) strong_alias(original, alias)
# endif

# define weak_alias(original, alias)					\
  .weak C_SYMBOL_NAME (alias) ASM_LINE_SEP				\
  C_SYMBOL_NAME (alias) = C_SYMBOL_NAME (original)

# define weak_extern(symbol)						\
  .weak C_SYMBOL_NAME (symbol)

#endif /* __ASSEMBLER__ */

/* Determine the return address.  */
#define RETURN_ADDRESS(nr) \
  __builtin_extract_return_addr (__builtin_return_address (nr))

/* When a reference to SYMBOL is encountered, the linker will emit a
   warning message MSG.  */
/* We want the .gnu.warning.SYMBOL section to be unallocated.  */
#define __make_section_unallocated(section_string)	\
  asm (".section " section_string "\n\t.previous");

/* Tacking on "\n\t#" to the section name makes gcc put it's bogus
   section attributes on what looks like a comment to the assembler.  */
#ifdef HAVE_SECTION_QUOTES
# define __sec_comment "\"\n\t#\""
#else
# define __sec_comment "\n\t#"
#endif
#define link_warning(symbol, msg) \
  __make_section_unallocated (".gnu.warning." #symbol) \
  static const char __evoke_link_warning_##symbol[]	\
    __attribute__ ((used, section (".gnu.warning." #symbol __sec_comment))) \
    = msg;

/* A canned warning for sysdeps/stub functions.  */
#define	stub_warning(name) \
  __make_section_unallocated (".gnu.glibc-stub." #name) \
  link_warning (name, #name " is not implemented and will always fail")

/* Warning for linking functions calling dlopen into static binaries.  */
#ifdef SHARED
#define static_link_warning(name)
#else
#define static_link_warning(name) static_link_warning1(name)
#define static_link_warning1(name) \
  link_warning(name, "Using '" #name "' in statically linked applications \
requires at runtime the shared libraries from the glibc version used \
for linking")
#endif

/* Declare SYMBOL to be TYPE (`function' or `object') of SIZE bytes
   alias to ORIGINAL, when the assembler supports such declarations
   (such as in ELF).
   This is only necessary when defining something in assembly, or playing
   funny alias games where the size should be other than what the compiler
   thinks it is.  */
#define declare_object_symbol_alias(symbol, original, size) \
  declare_object_symbol_alias_1 (symbol, original, size)
#ifdef __ASSEMBLER__
# define declare_object_symbol_alias_1(symbol, original, s_size) \
   strong_alias (original, symbol) ASM_LINE_SEP \
   .type C_SYMBOL_NAME (symbol), %object ASM_LINE_SEP \
   .size C_SYMBOL_NAME (symbol), s_size ASM_LINE_SEP
#else /* Not __ASSEMBLER__.  */
# ifdef HAVE_ASM_SET_DIRECTIVE
#  define declare_object_symbol_alias_1(symbol, original, size) \
     asm (".global " __SYMBOL_PREFIX # symbol "\n" \
	  ".type " __SYMBOL_PREFIX # symbol ", %object\n" \
	  ".set " __SYMBOL_PREFIX #symbol ", " __SYMBOL_PREFIX original "\n" \
	  ".size " __SYMBOL_PREFIX #symbol ", " #size "\n");
# else
#  define declare_object_symbol_alias_1(symbol, original, size) \
     asm (".global " __SYMBOL_PREFIX # symbol "\n" \
	  ".type " __SYMBOL_PREFIX # symbol ", %object\n" \
	  __SYMBOL_PREFIX #symbol " = " __SYMBOL_PREFIX original "\n" \
	  ".size " __SYMBOL_PREFIX #symbol ", " #size "\n");
# endif /* HAVE_ASM_SET_DIRECTIVE */
#endif /* __ASSEMBLER__ */


/*

*/

#ifdef HAVE_GNU_RETAIN
# define attribute_used_retain __attribute__ ((__used__, __retain__))
#else
# define attribute_used_retain __attribute__ ((__used__))
#endif

/* Symbol set support macros.  */

/* Make SYMBOL, which is in the text segment, an element of SET.  */
#define text_set_element(set, symbol)	_elf_set_element(set, symbol)
/* Make SYMBOL, which is in the data segment, an element of SET.  */
#define data_set_element(set, symbol)	_elf_set_element(set, symbol)
/* Make SYMBOL, which is in the bss segment, an element of SET.  */
#define bss_set_element(set, symbol)	_elf_set_element(set, symbol)

/* These are all done the same way in ELF.
   There is a new section created for each set.  */
#ifdef SHARED
/* When building a shared library, make the set section writable,
   because it will need to be relocated at run time anyway.  */
# define _elf_set_element(set, symbol) \
    static const void *__elf_set_##set##_element_##symbol##__ \
      attribute_used_retain __attribute__ ((section (#set))) = &(symbol)
#else
# define _elf_set_element(set, symbol) \
    static const void *const __elf_set_##set##_element_##symbol##__ \
      attribute_used_retain __attribute__ ((section (#set))) = &(symbol)
#endif

/* Define SET as a symbol set.  This may be required (it is in a.out) to
   be able to use the set's contents.  */
#define symbol_set_define(set)	symbol_set_declare(set)

/* Declare SET for use in this module, if defined in another module.
   In a shared library, this is always local to that shared object.
   For static linking, the set might be wholly absent and so we use
   weak references.  */
#define symbol_set_declare(set) \
  extern char const __start_##set[] __symbol_set_attribute; \
  extern char const __stop_##set[] __symbol_set_attribute;
#ifdef SHARED
# define __symbol_set_attribute attribute_hidden
#else
# define __symbol_set_attribute __attribute__ ((weak))
#endif

/* Return a pointer (void *const *) to the first element of SET.  */
#define symbol_set_first_element(set)	((void *const *) (&__start_##set))

/* Return true iff PTR (a void *const *) has been incremented
   past the last element in SET.  */
#define symbol_set_end_p(set, ptr) ((ptr) >= (void *const *) &__stop_##set)

#ifdef SHARED
# define symbol_version(real, name, version) \
  symbol_version_reference(real, name, version)
# define default_symbol_version(real, name, version) \
     _default_symbol_version(real, name, version)
/* See <libc-symver.h>.  */
# ifdef __ASSEMBLER__
#  define _default_symbol_version(real, name, version) \
  _set_symbol_version (real, name@@version)
# else
#  define _default_symbol_version(real, name, version) \
  _set_symbol_version (real, #name "@@" #version)
# endif

/* Evaluates to a string literal for VERSION in LIB.  */
# define symbol_version_string(lib, version) \
  _symbol_version_stringify_1 (VERSION_##lib##_##version)
# define _symbol_version_stringify_1(arg) _symbol_version_stringify_2 (arg)
# define _symbol_version_stringify_2(arg) #arg

#else /* !SHARED */
# define symbol_version(real, name, version)
# define default_symbol_version(real, name, version) \
  strong_alias(real, name)
#endif

#if defined SHARED || defined LIBC_NONSHARED \
  || (BUILD_PIE_DEFAULT && IS_IN (libc))
# define attribute_hidden __attribute__ ((visibility ("hidden")))
#else
# define attribute_hidden
#endif

#define attribute_tls_model_ie __attribute__ ((tls_model ("initial-exec")))

#define attribute_relro __attribute__ ((section (".data.rel.ro")))


/* The following macros are used for PLT bypassing within libc.so
   (and if needed other libraries similarly).
   First of all, you need to have the function prototyped somewhere,
   say in foo/foo.h:

   int foo (int __bar);

   If calls to foo within libc.so should always go to foo defined in libc.so,
   then in include/foo.h you add:

   libc_hidden_proto (foo)

   line and after the foo function definition:

   int foo (int __bar)
   {
     return __bar;
   }
   libc_hidden_def (foo)

   or

   int foo (int __bar)
   {
     return __bar;
   }
   libc_hidden_weak (foo)

   Similarly for global data.  If references to foo within libc.so should
   always go to foo defined in libc.so, then in include/foo.h you add:

   libc_hidden_proto (foo)

   line and after foo's definition:

   int foo = INITIAL_FOO_VALUE;
   libc_hidden_data_def (foo)

   or

   int foo = INITIAL_FOO_VALUE;
   libc_hidden_data_weak (foo)

   If foo is normally just an alias (strong or weak) to some other function,
   you should use the normal strong_alias first, then add libc_hidden_def
   or libc_hidden_weak:

   int baz (int __bar)
   {
     return __bar;
   }
   strong_alias (baz, foo)
   libc_hidden_weak (foo)

   If the function should be internal to multiple objects, say ld.so and
   libc.so, the best way is to use:

   #if IS_IN (libc) || IS_IN (rtld)
   hidden_proto (foo)
   #endif

   in include/foo.h and the normal macros at all function definitions
   depending on what DSO they belong to.

   If versioned_symbol macro is used to define foo,
   libc_hidden_ver macro should be used, as in:

   int __real_foo (int __bar)
   {
     return __bar;
   }
   versioned_symbol (libc, __real_foo, foo, GLIBC_2_1);
   libc_hidden_ver (__real_foo, foo)  */

#if defined SHARED && !defined NO_HIDDEN
# ifndef __ASSEMBLER__
#  define __hidden_proto_hiddenattr(attrs...) \
  __attribute__ ((visibility ("hidden"), ##attrs))
#  define hidden_proto(name, attrs...) \
  __hidden_proto (name, , __GI_##name, ##attrs)
#  define hidden_proto_alias(name, alias, attrs...) \
  __hidden_proto_alias (name, , alias, ##attrs)
#  define hidden_tls_proto(name, attrs...) \
  __hidden_proto (name, __thread, __GI_##name, ##attrs)
#  define __hidden_proto(name, thread, internal, attrs...)	     \
  extern thread __typeof (name) name __asm__ (__hidden_asmname (#internal)) \
  __hidden_proto_hiddenattr (attrs);
#  define __hidden_proto_alias(name, thread, internal, attrs...)	     \
  extern thread __typeof (name) internal __hidden_proto_hiddenattr (attrs);
#  define __hidden_asmname(name) \
  __hidden_asmname1 (__USER_LABEL_PREFIX__, name)
#  define __hidden_asmname1(prefix, name) __hidden_asmname2(prefix, name)
#  define __hidden_asmname2(prefix, name) #prefix name
#  define __hidden_ver1(local, internal, name) \
  __hidden_ver2 (, local, internal, name)
#  define __hidden_ver2(thread, local, internal, name)			\
  extern thread __typeof (name) __EI_##name \
    __asm__(__hidden_asmname (#internal));  \
  extern thread __typeof (name) __EI_##name \
    __attribute__((alias (__hidden_asmname (#local))))	\
    __attribute_copy__ (name)
#  define hidden_ver(local, name)	__hidden_ver1(local, __GI_##name, name);
#  define hidden_def(name)		__hidden_ver1(__GI_##name, name, name);
#  define hidden_def_alias(name, internal) \
  strong_alias (name, internal)
#  define hidden_data_def(name)		hidden_def(name)
#  define hidden_data_def_alias(name, alias) hidden_def_alias(name, alias)
#  define hidden_tls_def(name)				\
  __hidden_ver2 (__thread, __GI_##name, name, name);
#  define hidden_weak(name) \
	__hidden_ver1(__GI_##name, name, name) __attribute__((weak));
#  define hidden_data_weak(name)	hidden_weak(name)
#  define hidden_nolink(name, lib, version) \
  __hidden_nolink1 (__GI_##name, __EI_##name, name, VERSION_##lib##_##version)
#  define __hidden_nolink1(local, internal, name, version) \
  __hidden_nolink2 (local, internal, name, version)
#  define __hidden_nolink2(local, internal, name, version) \
  extern __typeof (name) internal __attribute__ ((alias (#local)))	\
    __attribute_copy__ (name);						\
  __hidden_nolink3 (local, internal, #name "@" #version)
#  define __hidden_nolink3(local, internal, vername) \
  __asm__ (".symver " #internal ", " vername);
# else
/* For assembly, we need to do the opposite of what we do in C:
   in assembly gcc __REDIRECT stuff is not in place, so functions
   are defined by its normal name and we need to create the
   __GI_* alias to it, in C __REDIRECT causes the function definition
   to use __GI_* name and we need to add alias to the real name.
   There is no reason to use hidden_weak over hidden_def in assembly,
   but we provide it for consistency with the C usage.
   hidden_proto doesn't make sense for assembly but the equivalent
   is to call via the HIDDEN_JUMPTARGET macro instead of JUMPTARGET.  */
#  define hidden_def(name)	strong_alias (name, __GI_##name)
#  define hidden_def_alias(name, alias) strong_alias (name, alias)
#  define hidden_weak(name)	hidden_def (name)
#  define hidden_ver(local, name) strong_alias (local, __GI_##name)
#  define hidden_data_def(name)	strong_data_alias (name, __GI_##name)
#  define hidden_data_def_alias(name, alias) strong_data_alias (name, alias)
#  define hidden_tls_def(name)	hidden_data_def (name)
#  define hidden_data_weak(name)	hidden_data_def (name)
#  define HIDDEN_JUMPTARGET(name) __GI_##name
# endif
#else
# ifndef __ASSEMBLER__
#  if !defined SHARED && IS_IN (libc) && !defined LIBC_NONSHARED \
      && (!defined PIC || !defined NO_HIDDEN_EXTERN_FUNC_IN_PIE) \
      && !defined NO_HIDDEN
#   define __hidden_proto_hiddenattr(attrs...) \
  __attribute__ ((visibility ("hidden"), ##attrs))
#   define hidden_proto(name, attrs...) \
  __hidden_proto (name, , name, ##attrs)
#  define hidden_proto_alias(name, alias, attrs...) \
  __hidden_proto_alias (name, , alias, ##attrs)
#   define hidden_tls_proto(name, attrs...) \
  __hidden_proto (name, __thread, name, ##attrs)
#  define __hidden_proto(name, thread, internal, attrs...)	     \
  extern thread __typeof (name) name __hidden_proto_hiddenattr (attrs);
#  define __hidden_proto_alias(name, thread, internal, attrs...)     \
  extern thread __typeof (name) internal __hidden_proto_hiddenattr (attrs);
# else
#   define hidden_proto(name, attrs...)
#   define hidden_proto_alias(name, alias, attrs...)
#   define hidden_tls_proto(name, attrs...)
# endif
# else
#  define HIDDEN_JUMPTARGET(name) JUMPTARGET(name)
# endif /* Not  __ASSEMBLER__ */
# define hidden_weak(name)
# define hidden_def(name)
# define hidden_def_alias(name, alias)
# define hidden_ver(local, name)
# define hidden_data_weak(name)
# define hidden_data_def(name)
# define hidden_data_def_alias(name, alias)
# define hidden_tls_def(name)
# define hidden_nolink(name, lib, version)
#endif

#if IS_IN (libc)
# define libc_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define libc_hidden_proto_alias(name, alias, attrs...) \
   hidden_proto_alias (name, alias, ##attrs)
# define libc_hidden_tls_proto(name, attrs...) hidden_tls_proto (name, ##attrs)
# define libc_hidden_def(name) hidden_def (name)
# define libc_hidden_weak(name) hidden_weak (name)
# define libc_hidden_nolink_sunrpc(name, version) hidden_nolink (name, libc, version)
# define libc_hidden_ver(local, name) hidden_ver (local, name)
# define libc_hidden_data_def(name) hidden_data_def (name)
# define libc_hidden_data_def_alias(name, alias) hidden_data_def_alias (name, alias)
# define libc_hidden_tls_def(name) hidden_tls_def (name)
# define libc_hidden_data_weak(name) hidden_data_weak (name)
#else
# define libc_hidden_proto(name, attrs...)
# define libc_hidden_proto_alias(name, alias, attrs...)
# define libc_hidden_tls_proto(name, attrs...)
# define libc_hidden_def(name)
# define libc_hidden_weak(name)
# define libc_hidden_ver(local, name)
# define libc_hidden_data_def(name)
# define libc_hidden_data_def_alias(name, alias)
# define libc_hidden_tls_def(name)
# define libc_hidden_data_weak(name)
#endif

#if IS_IN (rtld)
# define rtld_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define rtld_hidden_def(name) hidden_def (name)
# define rtld_hidden_weak(name) hidden_weak (name)
# define rtld_hidden_data_def(name) hidden_data_def (name)
#else
# define rtld_hidden_proto(name, attrs...)
# define rtld_hidden_def(name)
# define rtld_hidden_weak(name)
# define rtld_hidden_data_def(name)
#endif

#if IS_IN (libm)
# define libm_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define libm_hidden_def(name) hidden_def (name)
# define libm_hidden_weak(name) hidden_weak (name)
# define libm_hidden_ver(local, name) hidden_ver (local, name)
#else
# define libm_hidden_proto(name, attrs...)
# define libm_hidden_def(name)
# define libm_hidden_weak(name)
# define libm_hidden_ver(local, name)
#endif

#if IS_IN (libmvec)
# define libmvec_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define libmvec_hidden_def(name) hidden_def (name)
#else
# define libmvec_hidden_proto(name, attrs...)
# define libmvec_hidden_def(name)
#endif

#if IS_IN (libresolv)
# define libresolv_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define libresolv_hidden_def(name) hidden_def (name)
# define libresolv_hidden_data_def(name) hidden_data_def (name)
#else
# define libresolv_hidden_proto(name, attrs...)
# define libresolv_hidden_def(name)
# define libresolv_hidden_data_def(name)
#endif

#if IS_IN (libpthread)
# define libpthread_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define libpthread_hidden_def(name) hidden_def (name)
#else
# define libpthread_hidden_proto(name, attrs...)
# define libpthread_hidden_def(name)
#endif

#if IS_IN (librt)
# define librt_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define librt_hidden_ver(local, name) hidden_ver (local, name)
#else
# define librt_hidden_proto(name, attrs...)
# define librt_hidden_ver(local, name)
#endif

#if IS_IN (libnsl)
# define libnsl_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
# define libnsl_hidden_nolink_def(name, version) hidden_nolink (name, libnsl, version)
#else
# define libnsl_hidden_proto(name, attrs...)
#endif

#define libc_hidden_builtin_proto(name, attrs...) libc_hidden_proto (name, ##attrs)
#define libc_hidden_builtin_def(name) libc_hidden_def (name)

#define libc_hidden_ldbl_proto(name, attrs...) libc_hidden_proto (name, ##attrs)
#ifdef __ASSEMBLER__
# define HIDDEN_BUILTIN_JUMPTARGET(name) HIDDEN_JUMPTARGET(name)
#endif

#if IS_IN (libanl)
# define libanl_hidden_proto(name, attrs...) hidden_proto (name, ##attrs)
#else
# define libanl_hidden_proto(name, attrs...)
#endif

/* Get some dirty hacks.  */
#include <symbol-hacks.h>

/* Move compatibility symbols out of the way by placing them all in a
   special section.  */
#ifndef __ASSEMBLER__
# define attribute_compat_text_section \
    __attribute__ ((section (".text.compat")))
#else
# define compat_text_section .section ".text.compat", "ax";
#endif

/* Helper / base  macros for indirect function symbols.  */
#define __ifunc_resolver(type_name, name, expr, init, classifier, ...)	\
  classifier inhibit_stack_protector					\
  __typeof (type_name) *name##_ifunc (__VA_ARGS__)			\
  {									\
    init ();								\
    __typeof (type_name) *res = expr;					\
    return res;								\
  }

#ifdef HAVE_GCC_IFUNC
# define __ifunc_args(type_name, name, expr, init, ...)			\
  extern __typeof (type_name) name __attribute__			\
			      ((ifunc (#name "_ifunc")));		\
  __ifunc_resolver (type_name, name, expr, init, static, __VA_ARGS__)

# define __ifunc_args_hidden(type_name, name, expr, init, ...)		\
  __ifunc_args (type_name, name, expr, init, __VA_ARGS__)
#else
/* Gcc does not support __attribute__ ((ifunc (...))).  Use the old behaviour
   as fallback.  But keep in mind that the debug information for the ifunc
   resolver functions is not correct.  It contains the ifunc'ed function as
   DW_AT_linkage_name.  E.g. lldb uses this field and an inferior function
   call of the ifunc'ed function will fail due to "no matching function for
   call to ..." because the ifunc'ed function and the resolver function have
   different signatures.  (Gcc support is disabled at least on a ppc64le
   Ubuntu 14.04 system.)  */

# define __ifunc_args(type_name, name, expr, init, ...)			\
  extern __typeof (type_name) name;					\
  __typeof (type_name) *name##_ifunc (__VA_ARGS__) __asm__ (#name);	\
  __ifunc_resolver (type_name, name, expr, init, , __VA_ARGS__)		\
 __asm__ (".type " #name ", %gnu_indirect_function");

# define __ifunc_args_hidden(type_name, name, expr, init, ...)		\
  extern __typeof (type_name) __libc_##name;				\
  __ifunc (type_name, __libc_##name, expr, __VA_ARGS__, init)		\
  strong_alias (__libc_##name, name);
#endif /* !HAVE_GCC_IFUNC  */

#define __ifunc(type_name, name, expr, arg, init)			\
  __ifunc_args (type_name, name, expr, init, arg)

#define __ifunc_hidden(type_name, name, expr, arg, init)		\
  __ifunc_args_hidden (type_name, name, expr, init, arg)

/* The following macros are used for indirect function symbols in libc.so.
   First of all, you need to have the function prototyped somewhere,
   say in foo.h:

   int foo (int __bar);

   If you have an implementation for foo which e.g. uses a special hardware
   feature which isn't available on all machines where this libc.so will be
   used but decidable if available at runtime e.g. via hwcaps, you can provide
   two or multiple implementations of foo:

   int __foo_default (int __bar)
   {
     return __bar;
   }

   int __foo_special (int __bar)
   {
     return __bar;
   }

   If your function foo has no libc_hidden_proto (foo) defined for PLT
   bypassing, you can use:

   #define INIT_ARCH() unsigned long int hwcap = __GLRO(dl_hwcap);

   libc_ifunc (foo, (hwcap & HWCAP_SPECIAL) ? __foo_special : __foo_default);

   This will define a resolver function for foo which returns __foo_special or
   __foo_default depending on your specified expression.  Please note that you
   have to define a macro function INIT_ARCH before using libc_ifunc macro as
   it is called by the resolver function before evaluating the specified
   expression.  In this example it is used to prepare the hwcap variable.
   The resolver function is assigned to an ifunc'ed symbol foo.  Calls to foo
   from inside or outside of libc.so will be indirected by a PLT call.

   If your function foo has a libc_hidden_proto (foo) defined for PLT bypassing
   and calls to foo within libc.so should always go to one specific
   implementation of foo e.g. __foo_default then you have to add:

   __hidden_ver1 (__foo_default, __GI_foo, __foo_default);

   or a tweaked definition of libc_hidden_def macro after the __foo_default
   function definition.  Calls to foo within libc.so will always go directly to
   __foo_default.  Calls to foo from outside libc.so will be indirected by a
   PLT call to ifunc'ed symbol foo which you have to define in a separate
   compile unit:

   #define foo __redirect_foo
   #include <foo.h>
   #undef foo

   extern __typeof (__redirect_foo) __foo_default attribute_hidden;
   extern __typeof (__redirect_foo) __foo_special attribute_hidden;

   libc_ifunc_redirected (__redirect_foo, foo,
			  (hwcap & HWCAP_SPECIAL)
			  ? __foo_special
			  : __foo_default);

   This will define the ifunc'ed symbol foo like above.  The redirection of foo
   in header file is needed to omit an additional definition of __GI_foo which
   would end in a linker error while linking libc.so.  You have to specify
   __redirect_foo as first parameter which is used within libc_ifunc_redirected
   macro in conjunction with typeof to define the ifunc'ed symbol foo.

   If your function foo has a libc_hidden_proto (foo) defined and calls to foo
   within or from outside libc.so should go via ifunc'ed symbol, then you have
   to use:

   libc_ifunc_hidden (foo, foo,
		      (hwcap & HWCAP_SPECIAL)
		      ? __foo_special
		      : __foo_default);
   libc_hidden_def (foo)

   The first parameter foo of libc_ifunc_hidden macro is used in the same way
   as for libc_ifunc_redirected macro.  */

#define libc_ifunc(name, expr) __ifunc (name, name, expr, void, INIT_ARCH)

#define libc_ifunc_redirected(redirected_name, name, expr)	\
  __ifunc (redirected_name, name, expr, void, INIT_ARCH)

#define libc_ifunc_hidden(redirected_name, name, expr)			\
  __ifunc_hidden (redirected_name, name, expr, void, INIT_ARCH)

/* The body of the function is supposed to use __get_cpu_features
   which will, if necessary, initialize the data first.  */
#define libm_ifunc_init()
#define libm_ifunc(name, expr)				\
  __ifunc (name, name, expr, void, libm_ifunc_init)

/* These macros facilitate sharing source files with gnulib.

   They are here instead of sys/cdefs.h because they should not be
   used in public header files.

   Their definitions should be kept consistent with the definitions in
   gnulib-common.m4, but it is not necessary to cater to old non-GCC
   compilers, since they will only be used while building glibc itself.
   (Note that _GNUC_PREREQ cannot be used in this file.)  */

/* Define as a marker that can be attached to declarations that might not
    be used.  This helps to reduce warnings, such as from
    GCC -Wunused-parameter.  */
#if __GNUC__ >= 3 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 7)
# define _GL_UNUSED __attribute__ ((__unused__))
#else
# define _GL_UNUSED
#endif

/* gcc supports the "unused" attribute on possibly unused labels, and
   g++ has since version 4.5.  Note to support C++ as well as C,
   _GL_UNUSED_LABEL should be used with a trailing ;  */
#if !defined __cplusplus || __GNUC__ > 4 \
    || (__GNUC__ == 4 && __GNUC_MINOR__ >= 5)
# define _GL_UNUSED_LABEL _GL_UNUSED
#else
# define _GL_UNUSED_LABEL
#endif

/* The __pure__ attribute was added in gcc 2.96.  */
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 96)
# define _GL_ATTRIBUTE_PURE __attribute__ ((__pure__))
#else
# define _GL_ATTRIBUTE_PURE /* empty */
#endif

/* The __const__ attribute was added in gcc 2.95.  */
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 95)
# define _GL_ATTRIBUTE_CONST __attribute__ ((__const__))
#else
# define _GL_ATTRIBUTE_CONST /* empty */
#endif

#endif /* !_ISOMAC */
#endif /* libc-symbols.h */
