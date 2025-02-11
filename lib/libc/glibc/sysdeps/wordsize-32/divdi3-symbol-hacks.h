/* Hacks needed for divdi3 symbol manipulation.
   Copyright (C) 2004-2025 Free Software Foundation, Inc.
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

/* A very dirty trick: gcc emits references to __divdi3, __udivdi3,
   __moddi3, and __umoddi3.  These functions are exported and
   therefore we get PLTs.  Unnecessarily so.  Changing gcc is a big
   task which might not be worth it so we play tricks with the
   assembler.
   Note: in_divdi3_c is only used to avoid symbol alias on divdi3
   build itself.  */
#if !defined __ASSEMBLER__ && !defined in_divdi3_c && IS_IN (libc) \
    && defined SHARED && !defined LIBC_NONSHARED
asm ("__divdi3 = __divdi3_internal");
asm ("__udivdi3 = __udivdi3_internal");
asm ("__moddi3 = __moddi3_internal");
asm ("__umoddi3 = __umoddi3_internal");
#endif
