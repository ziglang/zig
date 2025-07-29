/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <internal.h>

/* 7.6.4.1
   The fegetenv function stores the current floating-point environment
   in the object pointed to by envp.  */

int fegetenv(fenv_t *env)
{
#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
    unsigned int x87, sse;
    __mingw_control87_2(0, 0, &x87, &sse);
    env->_Fe_ctl = fenv_encode(x87, sse);
    __mingw_setfp(NULL, 0, &x87, 0);
    __mingw_setfp_sse(NULL, 0, &sse, 0);
    env->_Fe_stat = fenv_encode(x87, sse);
#else
    env->_Fe_ctl = fenv_encode(0, __mingw_controlfp(0, 0));
    env->_Fe_stat = fenv_encode(0, __mingw_statusfp());
#endif
  return 0;
}

