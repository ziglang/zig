/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <stdio.h>

_off64_t
ftello64 (FILE * stream)
{
  fpos_t pos;
  if (fgetpos(stream, &pos))
    return  -1LL;
  else
   return ((off64_t) pos);
}
