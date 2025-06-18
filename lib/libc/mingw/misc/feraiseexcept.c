/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <internal.h>

/* 7.6.2.3
   The feraiseexcept function raises the supported exceptions
   represented by its argument The order in which these exceptions
   are raised is unspecified, except as stated in F.7.6.
   Whether the feraiseexcept function additionally raises
   the inexact exception whenever it raises the overflow
   or underflow exception is implementation-defined. */

int feraiseexcept(int flags)
{
    fenv_t env;

    flags &= FE_ALL_EXCEPT;
    fegetenv(&env);
    env._Fe_stat |= fenv_encode(flags, flags);
    fesetenv(&env);
#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
    __asm__ volatile ("fwait\n\t");
#endif
    return 0;
}
