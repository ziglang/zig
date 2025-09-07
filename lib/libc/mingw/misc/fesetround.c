/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <fenv.h>
#include <internal.h>

 /* 7.6.3.2
    The fesetround function establishes the rounding direction
    represented by its argument round. If the argument is not equal
    to the value of a rounding direction macro, the rounding direction
    is not changed.  */

int fesetround(int round_mode)
{
    if (round_mode & (~_MCW_RC))
        return 1;
    __mingw_controlfp(round_mode, _MCW_RC);
    return 0;
}
