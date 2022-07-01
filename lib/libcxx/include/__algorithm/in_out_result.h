// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_IN_OUT_RESULT_H
#define _LIBCPP___ALGORITHM_IN_OUT_RESULT_H

#include <__concepts/convertible_to.h>
#include <__config>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges {

template<class _InputIterator, class _OutputIterator>
struct in_out_result {
  [[no_unique_address]] _InputIterator in;
  [[no_unique_address]] _OutputIterator out;

  template <class _InputIterator2, class _OutputIterator2>
    requires convertible_to<const _InputIterator&, _InputIterator2> && convertible_to<const _OutputIterator&,
                           _OutputIterator2>
  _LIBCPP_HIDE_FROM_ABI
  constexpr operator in_out_result<_InputIterator2, _OutputIterator2>() const & {
    return {in, out};
  }

  template <class _InputIterator2, class _OutputIterator2>
    requires convertible_to<_InputIterator, _InputIterator2> && convertible_to<_OutputIterator, _OutputIterator2>
  _LIBCPP_HIDE_FROM_ABI
  constexpr operator in_out_result<_InputIterator2, _OutputIterator2>() && {
    return {_VSTD::move(in), _VSTD::move(out)};
  }
};

} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_IN_OUT_RESULT_H
