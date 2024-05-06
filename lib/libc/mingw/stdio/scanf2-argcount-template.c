/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stddef.h>

size_t FUNC(const TYPE *format);
size_t FUNC(const TYPE *format)
{
  size_t count = 0;
  for (; *format; format++) {
    if (*format == (TYPE)'%')
      count++;
  }
  return count;
}
