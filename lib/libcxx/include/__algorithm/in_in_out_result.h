// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_IN_IN_OUT_RESULT_H
#define _LIBCPP___ALGORITHM_IN_IN_OUT_RESULT_H

#include <__concepts/convertible_to.h>
#include <__config>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges {

template <class _I1, class _I2, class _O1>
struct in_in_out_result {
  [[no_unique_address]] _I1 in1;
  [[no_unique_address]] _I2 in2;
  [[no_unique_address]] _O1 out;

  template <class _II1, class _II2, class _OO1>
    requires convertible_to<const _I1&, _II1> && convertible_to<const _I2&, _II2> && convertible_to<const _O1&, _OO1>
  _LIBCPP_HIDE_FROM_ABI constexpr
  operator in_in_out_result<_II1, _II2, _OO1>() const& {
    return {in1, in2, out};
  }

  template <class _II1, class _II2, class _OO1>
    requires convertible_to<_I1, _II1> && convertible_to<_I2, _II2> && convertible_to<_O1, _OO1>
  _LIBCPP_HIDE_FROM_ABI constexpr
  operator in_in_out_result<_II1, _II2, _OO1>() && {
    return {_VSTD::move(in1), _VSTD::move(in2), _VSTD::move(out)};
  }
};

} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_IN_IN_OUT_RESULT_H
