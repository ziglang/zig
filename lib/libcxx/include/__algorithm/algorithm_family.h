//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_ALGORITHM_FAMILY_H
#define _LIBCPP___ALGORITHM_ALGORITHM_FAMILY_H

#include <__algorithm/iterator_operations.h>
#include <__algorithm/move.h>
#include <__algorithm/ranges_move.h>
#include <__config>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _AlgPolicy>
struct _AlgFamily;

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

template <>
struct _AlgFamily<_RangeAlgPolicy> {
  static constexpr auto __move = ranges::move;
};

#endif

template <>
struct _AlgFamily<_ClassicAlgPolicy> {

  // move
  template <class _InputIterator, class _OutputIterator>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 static _OutputIterator
  __move(_InputIterator __first, _InputIterator __last, _OutputIterator __result) {
    return std::move(
        std::move(__first),
        std::move(__last),
        std::move(__result));
  }
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_ALGORITHM_FAMILY_H
