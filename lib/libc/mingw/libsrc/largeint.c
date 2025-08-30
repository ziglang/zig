#if 0
/*
  largeint.c

  Large (64 bits) integer arithmetics library

  Written by Anders Norlander <anorland@hem2.passagen.se>

  This file is part of a free library for the Win32 API.
  
  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

*/

#define __COMPILING_LARGEINT

#include <largeint.h>

__int64 WINAPI
LargeIntegerAdd (__int64 i1, __int64 i2)
{
  return i1 + i2;
}

__int64 WINAPI
LargeIntegerSubtract (__int64 i1, __int64 i2)
{
  return i1 - i2;
}

__int64 WINAPI
LargeIntegerArithmeticShift (__int64 i, int n)
{
  return i >> n;
}

__int64 WINAPI
LargeIntegerShiftLeft (__int64 i, int n)
{
  return i << n;
}

__int64 WINAPI
LargeIntegerShiftRight (__int64 i, int n)
{
  return i >> n;
}

__int64 WINAPI
LargeIntegerNegate (__int64 i)
{
  return -i;
}

__int64 WINAPI
ConvertLongToLargeInteger (LONG l)
{
  return (__int64) l;
}

__int64 WINAPI
ConvertUlongToLargeInteger (ULONG ul)
{
  return _toi(_toui(ul));
}

__int64 WINAPI
EnlargedIntegerMultiply (LONG l1, LONG l2)
{
  return _toi(l1) * _toi(l2);
}

__int64 WINAPI
EnlargedUnsignedMultiply (ULONG ul1, ULONG ul2)
{
  return _toi(_toui(ul1) * _toui(ul2));
}

__int64 WINAPI
ExtendedIntegerMultiply (__int64 i, LONG l)
{
  return i * _toi(l);
}

__int64 WINAPI
LargeIntegerMultiply (__int64 i1, __int64 i2)
{
  return i1 * i2;
}

__int64 WINAPI LargeIntegerDivide (__int64 i1, __int64 i2, __int64 *remainder)
{
  if (remainder)
    *remainder = i1 % i2;
  return i1 / i2;
}

ULONG WINAPI
EnlargedUnsignedDivide (unsigned __int64 i1, ULONG i2, PULONG remainder)
{
  if (remainder)
    *remainder = i1 % _toi(i2);
  return i1 / _toi(i2);
}
__int64 WINAPI
ExtendedLargeIntegerDivide (__int64 i1, ULONG i2, PULONG remainder)
{
  if (remainder)
    *remainder = i1 % _toi(i2);
  return i1 / _toi(i2);
}

/* FIXME: what is this function supposed to do? */
__int64 WINAPI ExtendedMagicDivide (__int64 i1, __int64 i2, int n)
{
  return 0;
}
#endif

