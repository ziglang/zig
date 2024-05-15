//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___SUPPORT_NEWLIB_XLOCALE_H
#define _LIBCPP___SUPPORT_NEWLIB_XLOCALE_H

#if defined(_NEWLIB_VERSION)

#  if !defined(__NEWLIB__) || __NEWLIB__ < 2 || __NEWLIB__ == 2 && __NEWLIB_MINOR__ < 5
#    include <__support/xlocale/__nop_locale_mgmt.h>
#    include <__support/xlocale/__posix_l_fallback.h>
#    include <__support/xlocale/__strtonum_fallback.h>
#  endif

#endif // _NEWLIB_VERSION

#endif
