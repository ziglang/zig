/* Definition of PTHREAD_STACK_MIN, possibly dynamic.
   Copyright (C) 2021-2023 Free Software Foundation, Inc.
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

#ifndef PTHREAD_STACK_MIN
# if defined __USE_DYNAMIC_STACK_SIZE && __USE_DYNAMIC_STACK_SIZE
#  ifndef __ASSEMBLER__
#   define __SC_THREAD_STACK_MIN_VALUE 75
__BEGIN_DECLS
extern long int __sysconf (int __name) __THROW;
__END_DECLS
#   define PTHREAD_STACK_MIN __sysconf (__SC_THREAD_STACK_MIN_VALUE)
#  endif
# else
#  include <bits/pthread_stack_min.h>
# endif
#endif