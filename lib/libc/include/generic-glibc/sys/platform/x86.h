/* Data structure for x86 CPU features.
   This file is part of the GNU C Library.
   Copyright (C) 2008-2025 Free Software Foundation, Inc.

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
#include <bits/platform/features.h>

__BEGIN_DECLS

/* Get a pointer to the CPU feature structure.  */
extern const struct cpuid_feature *__x86_get_cpuid_feature_leaf (unsigned int)
     __attribute__ ((pure));

static __inline__ bool
x86_cpu_present (unsigned int __index)
{
  const struct cpuid_feature *__ptr = __x86_get_cpuid_feature_leaf
    (__index / (8 * sizeof (unsigned int) * 4));
  unsigned int __reg
     = __index & (8 * sizeof (unsigned int) * 4 - 1);
  unsigned int __bit = __reg & (8 * sizeof (unsigned int) - 1);
  __reg /= 8 * sizeof (unsigned int);

  return __ptr->cpuid_array[__reg] & (1 << __bit);
}

static __inline__ bool
x86_cpu_active (unsigned int __index)
{
  if (__index == x86_cpu_IBT || __index == x86_cpu_SHSTK)
    return x86_cpu_cet_active (__index);

  const struct cpuid_feature *__ptr = __x86_get_cpuid_feature_leaf
    (__index / (8 * sizeof (unsigned int) * 4));
  unsigned int __reg
     = __index & (8 * sizeof (unsigned int) * 4 - 1);
  unsigned int __bit = __reg & (8 * sizeof (unsigned int) - 1);
  __reg /= 8 * sizeof (unsigned int);

  return __ptr->active_array[__reg] & (1 << __bit);
}

/* CPU_FEATURE_PRESENT evaluates to true if CPU supports the feature.  */
#define CPU_FEATURE_PRESENT(name) x86_cpu_present (x86_cpu_##name)
/* CPU_FEATURE_ACTIVE evaluates to true if the feature is active.  */
#define CPU_FEATURE_ACTIVE(name) x86_cpu_active (x86_cpu_##name)

__END_DECLS

#endif  /* _SYS_PLATFORM_X86_H */