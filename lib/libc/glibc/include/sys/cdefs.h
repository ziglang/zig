#ifndef _SYS_CDEFS_H

/* This is outside of _ISOMAC to enforce that _Static_assert always
   uses the two-argument form.  This can be removed once the minimum
   GCC version used to compile glibc is GCC 9.1.  */
#ifndef __cplusplus
# define _Static_assert(expr, diagnostic) _Static_assert (expr, diagnostic)
#endif

#include <misc/sys/cdefs.h>

#ifndef _ISOMAC
/* The compiler will optimize based on the knowledge the parameter is
   not NULL.  This will omit tests.  A robust implementation cannot allow
   this so when compiling glibc itself we ignore this attribute.  */
# undef __nonnull
# define __nonnull(params)

extern void __chk_fail (void) __attribute__ ((__noreturn__));
libc_hidden_proto (__chk_fail)
rtld_hidden_proto (__chk_fail)

/* If we are using redirects internally to support long double,
   we need to tweak some macros to ensure the PLT bypass tricks
   continue to work in libc. */
#if __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 1 && IS_IN (libc) && defined SHARED

# undef __LDBL_REDIR_DECL
# define __LDBL_REDIR_DECL(func) \
   extern __typeof(func) func __asm (__ASMNAME ("__GI____ieee128_" #func));

# undef libc_hidden_ldbl_proto
# define libc_hidden_ldbl_proto(func, attrs...) \
   extern __typeof(func) ___ieee128_ ## func; \
   libc_hidden_proto (___ieee128_ ## func, ##attrs);

# undef __LDBL_REDIR2_DECL
# define __LDBL_REDIR2_DECL(func) \
   extern __typeof(__ ## func) __ ## func __asm (__ASMNAME ("__GI____ieee128___" #func));

#endif

#if defined SHARED
#if IS_IN (libc) && __USE_FORTIFY_LEVEL > 0 && defined __fortify_function

#undef __REDIRECT_FORTIFY
#define __REDIRECT_FORTIFY(name, proto, alias) \
  __REDIRECT(name, proto, __GI_##alias)

#undef __REDIRECT_FORTIFY_NTH
#define __REDIRECT_FORTIFY_NTH(name, proto, alias) \
  __REDIRECT_NTH(name, proto, __GI_##alias)

#endif
#endif /* defined SHARED */

#endif /* !defined _ISOMAC */

/*  Prevents a function from being considered for inlining and cloning.  */
#ifdef __clang__
# define __attribute_optimization_barrier__ __attribute__ ((optnone))
#else
# define __attribute_optimization_barrier__ __attribute__ ((noinline, noclone))
#endif

#endif
