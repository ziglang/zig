/* Macros to test for CPU features on ARM.  Generic ARM version.
   Copyright (C) 2012-2024 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _ARM_ARM_FEATURES_H
#define _ARM_ARM_FEATURES_H 1

/* An OS-specific arm-features.h file should define ARM_HAVE_VFP to
   an appropriate expression for testing at runtime whether the VFP
   hardware is present.  We'll then redefine it to a constant if we
   know at compile time that we can assume VFP.  */

#ifndef __SOFTFP__
/* The compiler is generating VFP instructions, so we're already
   assuming the hardware exists.  */
# undef ARM_HAVE_VFP
# define ARM_HAVE_VFP	1
#endif

/* An OS-specific arm-features.h file may define ARM_ASSUME_NO_IWMMXT
   to indicate at compile time that iWMMXt hardware is never present
   at runtime (or that we never care about its state) and so need not
   be checked for.  */

/* A more-specific arm-features.h file may define ARM_ALWAYS_BX to indicate
   that instructions using pc as a destination register must never be used,
   so a "bx" (or "blx") instruction is always required.  */

/* The log2 of the minimum alignment required for an address that
   is the target of a computed branch (i.e. a "bx" instruction).
   A more-specific arm-features.h file may define this to set a more
   stringent requirement.

   Using this only makes sense for code in ARM mode (where instructions
   always have a fixed size of four bytes), or for Thumb-mode code that is
   specifically aligning all the related branch targets to match (since
   Thumb instructions might be either two or four bytes).  */
#ifndef ARM_BX_ALIGN_LOG2
# define ARM_BX_ALIGN_LOG2	2
#endif

/* An OS-specific arm-features.h file may define ARM_NO_INDEX_REGISTER to
   indicate that the two-register addressing modes must never be used.  */

#endif  /* arm-features.h */
