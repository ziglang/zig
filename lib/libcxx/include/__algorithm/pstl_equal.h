//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_EQUAL_H
#define _LIBCPP___ALGORITHM_PSTL_EQUAL_H

#include <__algorithm/equal.h>
#include <__algorithm/pstl_frontend_dispatch.h>
#include <__config>
#include <__functional/operations.h>
#include <__iterator/iterator_traits.h>
#include <__numeric/pstl_transform_reduce.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class>
void __pstl_equal();

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Pred,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<bool>
__equal(_ExecutionPolicy&& __policy,
        _ForwardIterator1&& __first1,
        _ForwardIterator1&& __last1,
        _ForwardIterator2&& __first2,
        _Pred&& __pred) noexcept {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_equal, _RawPolicy),
      [&__policy](
          _ForwardIterator1 __g_first1, _ForwardIterator1 __g_last1, _ForwardIterator2 __g_first2, _Pred __g_pred) {
        return std::__transform_reduce(
            __policy,
            std::move(__g_first1),
            std::move(__g_last1),
            std::move(__g_first2),
            true,
            std::logical_and{},
            std::move(__g_pred));
      },
      std::move(__first1),
      std::move(__last1),
      std::move(__first2),
      std::move(__pred));
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Pred,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI bool
equal(_ExecutionPolicy&& __policy,
      _ForwardIterator1 __first1,
      _ForwardIterator1 __last1,
      _ForwardIterator2 __first2,
      _Pred __pred) {
  auto __res = std::__equal(__policy, std::move(__first1), std::move(__last1), std::move(__first2), std::move(__pred));
  if (!__res)
    std::__throw_bad_alloc();
  return *__res;
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          enable_if_t<is_execution_policy_v<__remove_cvref_t<_ExecutionPolicy>>, int> = 0>
_LIBCPP_HIDE_FROM_ABI bool
equal(_ExecutionPolicy&& __policy, _ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2) {
  return std::equal(__policy, std::move(__first1), std::move(__last1), std::move(__first2), std::equal_to{});
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Pred,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI optional<bool>
__equal(_ExecutionPolicy&& __policy,
        _ForwardIterator1&& __first1,
        _ForwardIterator1&& __last1,
        _ForwardIterator2&& __first2,
        _ForwardIterator2&& __last2,
        _Pred&& __pred) noexcept {
  return std::__pstl_frontend_dispatch(
      _LIBCPP_PSTL_CUSTOMIZATION_POINT(__pstl_equal, _RawPolicy),
      [&__policy](_ForwardIterator1 __g_first1,
                  _ForwardIterator1 __g_last1,
                  _ForwardIterator2 __g_first2,
                  _ForwardIterator2 __g_last2,
                  _Pred __g_pred) -> optional<bool> {
        if constexpr (__has_random_access_iterator_category<_ForwardIterator1>::value &&
                      __has_random_access_iterator_category<_ForwardIterator2>::value) {
          if (__g_last1 - __g_first1 != __g_last2 - __g_first2)
            return false;
          return std::__equal(
              __policy, std::move(__g_first1), std::move(__g_last1), std::move(__g_first2), std::move(__g_pred));
        } else {
          (void)__policy; // Avoid unused lambda capture warning
          return std::equal(
              std::move(__g_first1),
              std::move(__g_last1),
              std::move(__g_first2),
              std::move(__g_last2),
              std::move(__g_pred));
        }
      },
      std::move(__first1),
      std::move(__last1),
      std::move(__first2),
      std::move(__last2),
      std::move(__pred));
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Pred,
          class _RawPolicy                                    = __remove_cvref_t<_ExecutionPolicy>,
          enable_if_t<is_execution_policy_v<_RawPolicy>, int> = 0>
_LIBCPP_HIDE_FROM_ABI bool
equal(_ExecutionPolicy&& __policy,
      _ForwardIterator1 __first1,
      _ForwardIterator1 __last1,
      _ForwardIterator2 __first2,
      _ForwardIterator2 __last2,
      _Pred __pred) {
  auto __res = std::__equal(
      __policy, std::move(__first1), std::move(__last1), std::move(__first2), std::move(__last2), std::move(__pred));
  if (!__res)
    std::__throw_bad_alloc();
  return *__res;
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          enable_if_t<is_execution_policy_v<__remove_cvref_t<_ExecutionPolicy>>, int> = 0>
_LIBCPP_HIDE_FROM_ABI bool
equal(_ExecutionPolicy&& __policy,
      _ForwardIterator1 __first1,
      _ForwardIterator1 __last1,
      _ForwardIterator2 __first2,
      _ForwardIterator2 __last2) {
  return std::equal(
      __policy, std::move(__first1), std::move(__last1), std::move(__first2), std::move(__last2), std::equal_to{});
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_PSTL_EQUAL_H
