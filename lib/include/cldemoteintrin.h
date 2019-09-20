/*===---- cldemoteintrin.h - CLDEMOTE intrinsic ----------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#if !defined __X86INTRIN_H && !defined __IMMINTRIN_H
#error "Never use <cldemoteintrin.h> directly; include <x86intrin.h> instead."
#endif

#ifndef __CLDEMOTEINTRIN_H
#define __CLDEMOTEINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS \
  __attribute__((__always_inline__, __nodebug__,  __target__("cldemote")))

static __inline__ void __DEFAULT_FN_ATTRS
_cldemote(const void * __P) {
  __builtin_ia32_cldemote(__P);
}

#undef __DEFAULT_FN_ATTRS

#endif
