// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_LOCALE_H
#define _LIBCPP_LOCALE_H

/*
    locale.h synopsis

Macros:

    LC_ALL
    LC_COLLATE
    LC_CTYPE
    LC_MONETARY
    LC_NUMERIC
    LC_TIME

Types:

    lconv

Functions:

   setlocale
   localeconv

*/

#include <__config>

#if defined(_LIBCPP_HAS_NO_LOCALIZATION)
#   error "The Localization library is not supported since libc++ has been configured with LIBCXX_ENABLE_LOCALIZATION disabled"
#endif

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#   pragma GCC system_header
#endif

#include_next <locale.h>

#endif // _LIBCPP_LOCALE_H
