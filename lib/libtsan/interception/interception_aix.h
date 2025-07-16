//===-- interception_aix.h --------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of AddressSanitizer, an address sanity checker.
//
// AIX-specific interception methods.
//===----------------------------------------------------------------------===//

#if SANITIZER_AIX

#  if !defined(INCLUDED_FROM_INTERCEPTION_LIB)
#    error \
        "interception_aix.h should be included from interception library only"
#  endif

#  ifndef INTERCEPTION_AIX_H
#    define INTERCEPTION_AIX_H

namespace __interception {
bool InterceptFunction(const char *name, uptr *ptr_to_real, uptr func,
                       uptr wrapper);
}  // namespace __interception

#    define INTERCEPT_FUNCTION_AIX(func)                \
      ::__interception::InterceptFunction(              \
          #func, (::__interception::uptr *)&REAL(func), \
          (::__interception::uptr) & (func),            \
          (::__interception::uptr) & WRAP(func))

#  endif  // INTERCEPTION_AIX_H
#endif    // SANITIZER_AIX
