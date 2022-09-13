/*===---- stdnoreturn.h - Standard header for noreturn macro ---------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __STDNORETURN_H
#define __STDNORETURN_H

#define noreturn _Noreturn
#define __noreturn_is_defined 1

#if __STDC_VERSION__ > 201710L &&                                              \
    !defined(_CLANG_DISABLE_CRT_DEPRECATION_WARNINGS)
/* The noreturn macro is deprecated in C2x. We do not mark it as such because
   including the header file in C2x is also deprecated and we do not want to
   issue a confusing diagnostic for code which includes <stdnoreturn.h>
   followed by code that writes [[noreturn]]. The issue with such code is not
   with the attribute, or the use of 'noreturn', but the inclusion of the
   header. */
/* FIXME: We should be issuing a deprecation warning here, but cannot yet due
 * to system headers which include this header file unconditionally.
 */
#endif

#endif /* __STDNORETURN_H */
