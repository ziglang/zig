/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <stdio.h>

FILE* fopen64 (const char* filename, const char* mode)
{
  return fopen (filename, mode);
}
