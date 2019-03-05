/* Details about the machine's stack: wrapper header.
   Copyright (C) 2014-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

#ifndef _INCLUDE_STACKINFO_H
#define _INCLUDE_STACKINFO_H	1

/* A sysdeps/.../stackinfo.h file defines details for the CPU.
   It is obliged to define either _STACK_GROWS_DOWN or _STACK_GROWS_UP.  */
#include_next <stackinfo.h>

#if defined _STACK_GROWS_DOWN && _STACK_GROWS_DOWN
# ifdef _STACK_GROWS_UP
#  error "stackinfo.h should not define both!"
# else
#  define _STACK_GROWS_UP	0
# endif
#elif defined _STACK_GROWS_UP && _STACK_GROWS_UP
# ifdef _STACK_GROWS_DOWN
#  error "stackinfo.h should not define both!"
# else
#  define _STACK_GROWS_DOWN	0
# endif
#else
# error "stackinfo.h must define _STACK_GROWS_UP or _STACK_GROWS_DOWN!"
#endif

#endif  /* include/stackinfo.h */
