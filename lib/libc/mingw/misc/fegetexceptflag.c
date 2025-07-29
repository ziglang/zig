/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <fenv.h>
#include <internal.h>

/* 7.6.2.2
   The fegetexceptflag function stores an implementation-defined
   representation of the exception flags indicated by the argument
   excepts in the object pointed to by the argument flagp.  */

int fegetexceptflag(fexcept_t *status, int excepts)
{
#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
    unsigned int x87, sse;
    __mingw_setfp(NULL, 0, &x87, 0);
    __mingw_setfp_sse(NULL, 0, &sse, 0);
    *status = fenv_encode(x87 & excepts, sse & excepts);
#else
    *status = fenv_encode(0, __mingw_statusfp() & excepts);
#endif
    return 0;
}
