/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include "internal.h"

#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
/* Internal MinGW version of _control87_2 */
int __mingw_control87_2( unsigned int newval, unsigned int mask,
                         unsigned int *x86_cw, unsigned int *sse2_cw )
{
    if (x86_cw)
    {
        *x86_cw = newval;
        __mingw_setfp(x86_cw, mask, NULL, 0);
    }

    if (!sse2_cw) return 1;

    if (__mingw_has_sse())
    {
        *sse2_cw = newval;
        __mingw_setfp_sse(sse2_cw, mask, NULL, 0);
    }
    else *sse2_cw = 0;

    return 1;
}
#endif

/* Internal MinGW version of _control87 */
unsigned int __mingw_controlfp(unsigned int newval, unsigned int mask)
{
    unsigned int flags = 0;
#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
    unsigned int sse2_cw;

    __mingw_control87_2( newval, mask, &flags, &sse2_cw );

    if (__mingw_has_sse())
    {
        if ((flags ^ sse2_cw) & (_MCW_EM | _MCW_RC)) flags |= _EM_AMBIGUOUS;
        flags |= sse2_cw;
    }
#else
    flags = newval;
    __mingw_setfp(&flags, mask, NULL, 0);
#endif
    return flags;
}

