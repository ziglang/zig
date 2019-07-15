/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <errno.h>

errno_t __cdecl _set_errno (int _Value)
{
  errno = _Value;
  return errno;
}

errno_t __cdecl _get_errno (int *_Value)
{
  if(_Value) *_Value=errno;
  return errno;
}
