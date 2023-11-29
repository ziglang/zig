//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <cstdlib>
#include <new>

namespace std { // purposefully not versioned

#ifndef __GLIBCXX__
const nothrow_t nothrow{};
#endif

#ifndef LIBSTDCXX

void __throw_bad_alloc() {
#  ifndef _LIBCPP_HAS_NO_EXCEPTIONS
  throw bad_alloc();
#  else
  std::abort();
#  endif
}

#endif // !LIBSTDCXX

} // namespace std
