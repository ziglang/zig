/* Inline functions for x86 CPU features.
   This file is part of the GNU C Library.
   Copyright (C) 2024 Free Software Foundation, Inc.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_PLATFORM_X86_H
# error "Never include <bits/platform/features.h> directly; use <sys/platform/x86.h> instead."
#endif

/* Bits in the feature_1 field in TCB.  */

enum
{
  x86_feature_1_ibt		= 1U << 0,
  x86_feature_1_shstk		= 1U << 1
};

static __inline__ _Bool
x86_cpu_cet_active (unsigned int __index)
{
#ifdef __x86_64__
  unsigned int __feature_1;
# ifdef __LP64__
  __asm__ ("mov %%fs:72, %0" : "=r" (__feature_1));
# else
  __asm__ ("mov %%fs:40, %0" : "=r" (__feature_1));
# endif
  if (__index == x86_cpu_IBT)
    return __feature_1 & x86_feature_1_ibt;
  else
    return __feature_1 & x86_feature_1_shstk;
#else
  return false;
#endif
}