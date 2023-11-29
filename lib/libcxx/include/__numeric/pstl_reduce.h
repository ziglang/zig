//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___NUMERIC_PSTL_REDUCE_H
#define _LIBCPP___NUMERIC_PSTL_REDUCE_H

#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
#include <__functional/identity.h>
#include <__iterator/iterator_traits.h>
#include <__numeric/pstl_transform_reduce.h>
#include <__type_traits/is_execution_policy.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class>
void __pstl_reduce();

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _Tp,
          class _BinaryOperation                              = plus<>,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _Tp
reduce(_ExecutionPolicy&& __policy,
       _ForwardIterator __first,
       _ForwardIterator __last,
       _Tp __init,
       _BinaryOperation __op = {}) {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_reduce),
      [&__policy](_ForwardIterator __g_first, _ForwardIterator __g_last, _Tp __g_init, _BinaryOperation __g_op) {
        return std::transform_reduce(
            __policy, std::move(__g_first), std::move(__g_last), std::move(__g_init), std::move(__g_op), __identity{});
      },
      std::move(__first),
      std::move(__last),
      std::move(__init),
      std::move(__op));
}

template <class _ExecutionPolicy,
          class _ForwardIterator,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI __iter_value_type<_ForwardIterator>
reduce(_ExecutionPolicy&& __policy, _ForwardIterator __first, _ForwardIterator __last) {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_reduce),
      [&__policy](_ForwardIterator __g_first, _ForwardIterator __g_last) {
        return std::reduce(__policy, __g_first, __g_last, __iter_value_type<_ForwardIterator>());
      },
      std::move(__first),
      std::move(__last));
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___NUMERIC_PSTL_REDUCE_H
