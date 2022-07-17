// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMAT_TO_N_RESULT_H
#define _LIBCPP___FORMAT_FORMAT_TO_N_RESULT_H

#include <__config>
#include <__iterator/incrementable_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

template <class _OutIt>
struct _LIBCPP_TEMPLATE_VIS format_to_n_result {
  _OutIt out;
  iter_difference_t<_OutIt> size;
};

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)
#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_FORMAT_TO_N_RESULT_H
