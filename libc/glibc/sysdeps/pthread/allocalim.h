/* Determine whether block of given size can be allocated on the stack or not.
   Copyright (C) 2002-2019 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License as
   published by the Free Software Foundation; either version 2.1 of the
   License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; see the file COPYING.LIB.  If
   not, see <http://www.gnu.org/licenses/>.  */

#include <alloca.h>
#include <limits.h>


extern __always_inline
int
__libc_use_alloca (size_t size)
{
  return (__glibc_likely (__libc_alloca_cutoff (size))
#ifdef PTHREAD_STACK_MIN
          || __glibc_likely (size <= PTHREAD_STACK_MIN / 4)
#endif
	  );
}
