//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_COUNT_H
#define _LIBCPP___ALGORITHM_PSTL_COUNT_H

#include <__algorithm/count.h>
#include <__algorithm/for_each.h>
#include <__algorithm/pstl_backend.h>
#include <__algorithm/pstl_for_each.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__atomic/atomic.h>
#include <__config>
#include <__functional/operations.h>
#include <__iterator/iterator_traits.h>
#include <__numeric/pstl_transform_reduce.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/move.h>
#include <__utility/terminate_on_exception.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class>
void __pstl_count_if(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Predicate,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI __iter_diff_t<_ForwardIterator>
count_if(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  using __diff_t = __iter_diff_t<_ForwardIterator>;
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_count_if),
      [&](_ForwardIterator __g_first, _ForwardIterator __g_last, _Predicate __g_pred) {
        return std::transform_reduce(
            __policy,
            std::move(__g_first),
            std::move(__g_last),
            __diff_t(),
            std::plus{},
            [&](__iter_reference<_ForwardIterator> __element) -> bool { return __g_pred(__element); });
      },
      std::move(__first),
      std::move(__last),
      std::move(__pred));
}

template <class>
void __pstl_count(); // declaration needed for the frontend dispatch below

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Tp,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI __iter_diff_t<_ForwardIterator>
count(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last, const _Tp& __value) {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_count),
      [&](_ForwardIterator __g_first, _ForwardIterator __g_last, const _Tp& __g_value) {
        return std::count_if(__policy, __g_first, __g_last, [&](__iter_reference<_ForwardIterator> __v) {
          return __v == __g_value;
        });
      },
      std::move(__first),
      std::move(__last),
      __value);
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_COUNT_H
