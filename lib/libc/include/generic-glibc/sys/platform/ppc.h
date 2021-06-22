/* Facilities specific to the PowerPC architecture
   Copyright (C) 2012-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

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

#ifndef _SYS_PLATFORM_PPC_H
#define _SYS_PLATFORM_PPC_H	1

#include <features.h>
#include <stdint.h>
#include <bits/ppc.h>

/* Read the Time Base Register.   */
static __inline__ uint64_t
__ppc_get_timebase (void)
{
#if __GNUC_PREREQ (4, 8)
  return __builtin_ppc_get_timebase ();
#else
# ifdef __powerpc64__
  uint64_t __tb;
  /* "volatile" is necessary here, because the user expects this assembly
     isn't moved after an optimization.  */
  __asm__ volatile ("mfspr %0, 268" : "=r" (__tb));
  return __tb;
# else  /* not __powerpc64__ */
  uint32_t __tbu, __tbl, __tmp; \
  __asm__ volatile ("0:\n\t"
		    "mftbu %0\n\t"
		    "mftbl %1\n\t"
		    "mftbu %2\n\t"
		    "cmpw %0, %2\n\t"
		    "bne- 0b"
		    : "=r" (__tbu), "=r" (__tbl), "=r" (__tmp));
  return (((uint64_t) __tbu << 32) | __tbl);
# endif  /* not __powerpc64__ */
#endif
}

/* The following functions provide hints about the usage of shared processor
   resources, as defined in ISA 2.06 and newer. */

/* Provides a hint that performance will probably be improved if shared
   resources dedicated to the executing processor are released for use by other
   processors.  */
static __inline__ void
__ppc_yield (void)
{
  __asm__ volatile ("or 27,27,27");
}

/* Provides a hint that performance will probably be improved if shared
   resources dedicated to the executing processor are released until
   all outstanding storage accesses to caching-inhibited storage have been
   completed.  */
static __inline__ void
__ppc_mdoio (void)
{
  __asm__ volatile ("or 29,29,29");
}

/* Provides a hint that performance will probably be improved if shared
   resources dedicated to the executing processor are released until all
   outstanding storage accesses to cacheable storage for which the data is not
   in the cache have been completed.  */
static __inline__ void
__ppc_mdoom (void)
{
  __asm__ volatile ("or 30,30,30");
}


/* ISA 2.05 and beyond support the Program Priority Register (PPR) to adjust
   thread priorities based on lock acquisition, wait and release. The ISA
   defines the use of form 'or Rx,Rx,Rx' as the way to modify the PRI field.
   The unprivileged priorities are:
     Rx = 1 (low)
     Rx = 2 (medium)
     Rx = 6 (medium-low/normal)
   The 'or' instruction form is a nop in previous hardware, so it is safe to
   use unguarded. The default value is 'medium'.
 */

static __inline__ void
__ppc_set_ppr_med (void)
{
  __asm__ volatile ("or 2,2,2");
}

static __inline__ void
__ppc_set_ppr_med_low (void)
{
  __asm__ volatile ("or 6,6,6");
}

static __inline__ void
__ppc_set_ppr_low (void)
{
  __asm__ volatile ("or 1,1,1");
}

/* Power ISA 2.07 (Book II, Chapter 3) extends the priorities that can be set
   to the Program Priority Register (PPR).  The form 'or Rx,Rx,Rx' is used to
   modify the PRI field of the PPR, the same way as described above.
   The new priority levels are:
     Rx = 31 (very low)
     Rx = 5 (medium high)
   Any program can set the priority to very low, low, medium low, and medium,
   as these are unprivileged.
   The medium high priority, on the other hand, is privileged, and may only be
   set during certain time intervals by problem-state programs.  If the program
   priority is medium high when the time interval expires or if an attempt is
   made to set the priority to medium high when it is not allowed, the PRI
   field is set to medium.
 */

#ifdef _ARCH_PWR8

static __inline__ void
__ppc_set_ppr_very_low (void)
{
  __asm__ volatile ("or 31,31,31");
}

static __inline__ void
__ppc_set_ppr_med_high (void)
{
  __asm__ volatile ("or 5,5,5");
}

#endif

#endif  /* sys/platform/ppc.h */