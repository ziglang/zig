/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <fenv.h>
#include <internal.h>

/* 7.6.2.5
   The fetestexcept function determines which of a specified subset of
   the exception flags are currently set. The excepts argument
   specifies the exception flags to be queried.
   The fetestexcept function returns the value of the bitwise OR of the
   exception macros corresponding to the currently set exceptions
   included in excepts. */

int fetestexcept(int flags)
{
    return __mingw_statusfp() & flags;
}
