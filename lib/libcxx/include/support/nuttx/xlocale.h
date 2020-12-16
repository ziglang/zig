// -*- C++ -*-
//===-------------------- support/nuttx/xlocale.h -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_SUPPORT_NUTTX_XLOCALE_H
#define _LIBCPP_SUPPORT_NUTTX_XLOCALE_H

#if defined(__NuttX__)
#include <support/xlocale/__posix_l_fallback.h>
#include <support/xlocale/__strtonum_fallback.h>
#endif // __NuttX__

#endif
