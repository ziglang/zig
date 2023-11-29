/*===---- stdalign.h - Standard header for alignment ------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __STDALIGN_H
#define __STDALIGN_H

/* FIXME: This is using the placeholder dates Clang produces for these macros
   in C2x mode; switch to the correct values once they've been published. */
#if defined(__cplusplus) ||                                                    \
    (defined(__STDC_VERSION__) && __STDC_VERSION__ < 202000L)
#ifndef __cplusplus
#define alignas _Alignas
#define alignof _Alignof
#endif

#define __alignas_is_defined 1
#define __alignof_is_defined 1
#endif /* __STDC_VERSION__ */

#endif /* __STDALIGN_H */
