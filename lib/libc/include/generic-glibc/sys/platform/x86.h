/* Data structure for x86 CPU features.
   This file is part of the GNU C Library.
   Copyright (C) 2008-2021 Free Software Foundation, Inc.

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
#define _SYS_PLATFORM_X86_H

#include <features.h>
#include <stdbool.h>
#include <bits/platform/x86.h>

__BEGIN_DECLS

/* Get a pointer to the CPU feature structure.  */
extern const struct cpuid_feature *__x86_get_cpuid_feature_leaf (unsigned int)
     __attribute__ ((pure));

static __inline__ _Bool
x86_cpu_has_feature (unsigned int __index)
{
  const struct cpuid_feature *__ptr = __x86_get_cpuid_feature_leaf
    (__index / (8 * sizeof (unsigned int) * 4));
  unsigned int __reg
     = __index & (8 * sizeof (unsigned int) * 4 - 1);
  unsigned int __bit = __reg & (8 * sizeof (unsigned int) - 1);
  __reg /= 8 * sizeof (unsigned int);

  return __ptr->cpuid_array[__reg] & (1 << __bit);
}

static __inline__ _Bool
x86_cpu_is_usable (unsigned int __index)
{
  const struct cpuid_feature *__ptr = __x86_get_cpuid_feature_leaf
    (__index / (8 * sizeof (unsigned int) * 4));
  unsigned int __reg
     = __index & (8 * sizeof (unsigned int) * 4 - 1);
  unsigned int __bit = __reg & (8 * sizeof (unsigned int) - 1);
  __reg /= 8 * sizeof (unsigned int);

  return __ptr->usable_array[__reg] & (1 << __bit);
}

/* HAS_CPU_FEATURE evaluates to true if CPU supports the feature.  */
#define HAS_CPU_FEATURE(name) x86_cpu_has_feature (x86_cpu_##name)
/* CPU_FEATURE_USABLE evaluates to true if the feature is usable.  */
#define CPU_FEATURE_USABLE(name) x86_cpu_is_usable (x86_cpu_##name)

__END_DECLS

#endif  /* _SYS_PLATFORM_X86_H */