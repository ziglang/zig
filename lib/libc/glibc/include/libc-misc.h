/* Miscellaneous definitions for both glibc build and test.
   Copyright (C) 2024-2025 Free Software Foundation, Inc.
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

#ifndef _INCLUDE_MISC_H
#define _INCLUDE_MISC_H

#include <config.h>

/* Add the compiler optimization to inhibit loop transformation to library
   calls.  This is used to avoid recursive calls in memset and memmove
   default implementations in tests.  */
#ifdef HAVE_CC_INHIBIT_LOOP_TO_LIBCALL
# define inhibit_loop_to_libcall \
    __attribute__ ((__optimize__ ("-fno-tree-loop-distribute-patterns")))
#else
# define inhibit_loop_to_libcall
#endif

#ifdef HAVE_TEST_CC_INHIBIT_LOOP_TO_LIBCALL
# define test_cc_inhibit_loop_to_libcall \
    __attribute__ ((__optimize__ ("-fno-tree-loop-distribute-patterns")))
#else
# define test_cc_inhibit_loop_to_libcall
#endif

/* Used to disable stack protection in sensitive places, like ifunc
   resolvers and early static TLS init.  */
#ifdef __clang__
# define cc_inhibit_stack_protector \
    __attribute__((no_stack_protector))
#else
# define cc_inhibit_stack_protector \
   __attribute__ ((__optimize__ ("-fno-stack-protector")))
#endif

#if IS_IN (testsuite) || IS_IN (testsuite_internal)
# ifdef HAVE_TEST_CC_NO_STACK_PROTECTOR
#  define test_inhibit_stack_protector cc_inhibit_stack_protector
#  define inhibit_stack_protector cc_inhibit_stack_protector
# else
#  define test_inhibit_stack_protector
#  define inhibit_stack_protector
# endif
#else
# ifdef HAVE_CC_NO_STACK_PROTECTOR
#  define inhibit_stack_protector cc_inhibit_stack_protector
# else
#  define inhibit_stack_protector
# endif
#endif

#endif
