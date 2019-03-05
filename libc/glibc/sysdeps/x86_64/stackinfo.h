/* Copyright (C) 2001-2019 Free Software Foundation, Inc.
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

/* This file contains a bit of information about the stack allocation
   of the processor.  */

#ifndef _STACKINFO_H
#define _STACKINFO_H	1

#include <elf.h>

/* On x86_64 the stack grows down.  */
#define _STACK_GROWS_DOWN	1

/* Default to an executable stack.  PF_X can be overridden if PT_GNU_STACK is
 * present, but it is presumed absent.  */
#define DEFAULT_STACK_PERMS (PF_R|PF_W|PF_X)

/* Access to the stack pointer.  The macros are used in alloca_account
   for which they need to act as barriers as well, hence the additional
   (unnecessary) parameters.  */
#define stackinfo_get_sp() \
  ({ void *p__; asm volatile ("mov %%" RSP_LP ", %0" : "=r" (p__)); p__; })
#define stackinfo_sub_sp(ptr) \
  ({ ptrdiff_t d__;						\
     asm volatile ("sub %%" RSP_LP " , %0" : "=r" (d__) : "0" (ptr));	\
     d__; })

#endif	/* stackinfo.h */
