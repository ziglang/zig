/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw.h>

unsigned int alarm(unsigned int);

unsigned int alarm(unsigned int __UNUSED_PARAM(seconds))
{
  return 0;
}
