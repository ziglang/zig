/*===---- mwaitxintrin.h - MONITORX/MWAITX intrinsics ----------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __X86INTRIN_H
#error "Never use <mwaitxintrin.h> directly; include <x86intrin.h> instead."
#endif

#ifndef __MWAITXINTRIN_H
#define __MWAITXINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__,  __target__("mwaitx")))
static __inline__ void __DEFAULT_FN_ATTRS
_mm_monitorx(void const * __p, unsigned __extensions, unsigned __hints)
{
  __builtin_ia32_monitorx((void *)__p, __extensions, __hints);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mwaitx(unsigned __extensions, unsigned __hints, unsigned __clock)
{
  __builtin_ia32_mwaitx(__extensions, __hints, __clock);
}

#undef __DEFAULT_FN_ATTRS

#endif /* __MWAITXINTRIN_H */
