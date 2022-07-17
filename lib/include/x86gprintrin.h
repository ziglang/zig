/*===--------------- x86gprintrin.h - X86 GPR intrinsics ------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __X86GPRINTRIN_H
#define __X86GPRINTRIN_H

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__HRESET__)
#include <hresetintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__UINTR__)
#include <uintrintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__CRC32__)
#include <crc32intrin.h>
#endif

#define __SSC_MARK(Tag)                                                        \
  __asm__ __volatile__("mov {%%ebx, %%eax|eax, ebx}; "                      \
                       "mov {%0, %%ebx|ebx, %0}; "                          \
                       ".byte 0x64, 0x67, 0x90; "                              \
                       "mov {%%eax, %%ebx|ebx, eax};" ::"i"(Tag)            \
                       : "%eax");

#endif /* __X86GPRINTRIN_H */
