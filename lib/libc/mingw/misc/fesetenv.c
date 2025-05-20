/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <internal.h>

/* The FE_DFL_ENV macro is required by standard.
   fesetenv will use the environment set at app startup.*/
const fenv_t __mingw_fe_dfl_env = { 0, 0 };

/* The C99 standard (7.6.9) allows us to define implementation-specific macros for
   different fp environments */
#if defined(__i386__) || defined(__x86_64__)

/* The default Intel x87 floating point environment (64-bit mantissa) */
const fenv_t __mingw_fe_pc64_env = { 0x3f3f003f, 0 };

/* The floating point environment set by MSVCRT _fpreset (53-bit mantissa) */
const fenv_t __mingw_fe_pc53_env = { 0x3f3f103f, 0 };

#endif

/* 7.6.4.3
   The fesetenv function establishes the floating-point environment
   represented by the object pointed to by envp. The argument envp
   points to an object set by a call to fegetenv or feholdexcept, or
   equal the macro FE_DFL_ENV or an implementation-defined environment
   macro. Note that fesetenv merely installs the state of the exception
   flags represented through its argument, and does not raise these
   exceptions.
 */

extern void (* __MINGW_IMP_SYMBOL(_fpreset))(void);
extern void _fpreset(void);

int fesetenv(const fenv_t *env)
{
    unsigned int x87_cw, cw, x87_stat, stat;
    unsigned int mask = ~0u;

    if (!env->_Fe_ctl && !env->_Fe_stat) {
        _fpreset();
        return 0;
    }

    if (!fenv_decode(env->_Fe_ctl, &x87_cw, &cw))
        return 1;
    if (!fenv_decode(env->_Fe_stat, &x87_stat, &stat))
        return 1;

#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
    __mingw_setfp(&x87_cw, mask, &x87_stat, ~0);
    if (__mingw_has_sse())
        __mingw_setfp_sse(&cw, mask, &stat, ~0);
#else
    __mingw_setfp(&cw, mask, &stat, ~0);
#endif
    return 0;
}
