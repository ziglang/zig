//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//
//===----------------------------------------------------------------------===//

#ifndef LIBUNWIND_CET_UNWIND_H
#define LIBUNWIND_CET_UNWIND_H

#include "libunwind.h"

// Currently, CET is implemented on Linux x86 platforms.
#if defined(_LIBUNWIND_TARGET_LINUX) && defined(__CET__) && defined(__SHSTK__)
#define _LIBUNWIND_USE_CET 1
#endif

#if defined(_LIBUNWIND_USE_CET)
#include <cet.h>
#include <immintrin.h>

#define _LIBUNWIND_POP_CET_SSP(x)                                              \
  do {                                                                         \
    unsigned long ssp = _get_ssp();                                            \
    if (ssp != 0) {                                                            \
      unsigned int tmp = (x);                                                  \
      while (tmp > 255) {                                                      \
        _inc_ssp(255);                                                         \
        tmp -= 255;                                                            \
      }                                                                        \
      _inc_ssp(tmp);                                                           \
    }                                                                          \
  } while (0)
#endif

extern void *__libunwind_cet_get_registers(unw_cursor_t *);
extern void *__libunwind_cet_get_jump_target();

#endif
