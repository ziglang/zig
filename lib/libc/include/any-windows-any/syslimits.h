/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/* syslimits.h stands for the system's own limits.h file.
   If we can use it ok unmodified, then we install this text.
   If fixincludes fixes it, then the fixed version is installed
   instead of this text.  */

#define _GCC_NEXT_LIMITS_H		/* tell gcc's limits.h to recurse */
#include_next <limits.h>
#undef _GCC_NEXT_LIMITS_H
