//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_TRANSFORM_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_TRANSFORM_H

#include <__algorithm/pstl_backends/cpu_backends/backend.h>
#include <__algorithm/transform.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/terminate_on_exception.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Iterator1, class _DifferenceType, class _Iterator2, class _Function>
_LIBCPP_HIDE_FROM_ABI _Iterator2
__simd_walk_2(_Iterator1 __first1, _DifferenceType __n, _Iterator2 __first2, _Function __f) noexcept {
  _PSTL_PRAGMA_SIMD
  for (_DifferenceType __i = 0; __i < __n; ++__i)
    __f(__first1[__i], __first2[__i]);
  return __first2 + __n;
}

template <class _ExecutionPolicy, class _ForwardIterator, class _ForwardOutIterator, class _UnaryOperation>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator __pstl_transform(
    __cpu_backend_tag,
    _ForwardIterator __first,
    _ForwardIterator __last,
    _ForwardOutIterator __result,
    _UnaryOperation __op) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator>::value &&
                __has_random_access_iterator_category<_ForwardOutIterator>::value) {
    std::__terminate_on_exception([&] {
      std::__par_backend::__parallel_for(
          __first, __last, [__op, __first, __result](_ForwardIterator __brick_first, _ForwardIterator __brick_last) {
            return std::__pstl_transform<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{}, __brick_first, __brick_last, __result + (__brick_first - __first), __op);
          });
    });
    return __result + (__last - __first);
  } else if constexpr (__is_unsequenced_execution_policy_v<_ExecutionPolicy> &&
                       __has_random_access_iterator_category<_ForwardIterator>::value &&
                       __has_random_access_iterator_category<_ForwardOutIterator>::value) {
    return std::__simd_walk_2(
        __first,
        __last - __first,
        __result,
        [&](__iter_reference<_ForwardIterator> __in_value, __iter_reference<_ForwardOutIterator> __out_value) {
          __out_value = __op(__in_value);
        });
  } else {
    return std::transform(__first, __last, __result, __op);
  }
}

template <class _Iterator1, class _DifferenceType, class _Iterator2, class _Iterator3, class _Function>
_LIBCPP_HIDE_FROM_ABI _Iterator3 __simd_walk_3(
    _Iterator1 __first1, _DifferenceType __n, _Iterator2 __first2, _Iterator3 __first3, _Function __f) noexcept {
  _PSTL_PRAGMA_SIMD
  for (_DifferenceType __i = 0; __i < __n; ++__i)
    __f(__first1[__i], __first2[__i], __first3[__i]);
  return __first3 + __n;
}
template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _ForwardOutIterator,
          class _BinaryOperation,
          enable_if_t<is_execution_policy_v<__remove_cvref_t<_ExecutionPolicy>>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _ForwardOutIterator __pstl_transform(
    __cpu_backend_tag,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _ForwardOutIterator __result,
    _BinaryOperation __op) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator1>::value &&
                __has_random_access_iterator_category<_ForwardIterator2>::value &&
                __has_random_access_iterator_category<_ForwardOutIterator>::value) {
    std::__terminate_on_exception([&] {
      std::__par_backend::__parallel_for(
          __first1,
          __last1,
          [__op, __first1, __first2, __result](_ForwardIterator1 __brick_first, _ForwardIterator1 __brick_last) {
            return std::__pstl_transform<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{},
                __brick_first,
                __brick_last,
                __first2 + (__brick_first - __first1),
                __result + (__brick_first - __first1),
                __op);
          });
    });
    return __result + (__last1 - __first1);
  } else if constexpr (__is_unsequenced_execution_policy_v<_ExecutionPolicy> &&
                       __has_random_access_iterator_category<_ForwardIterator1>::value &&
                       __has_random_access_iterator_category<_ForwardIterator2>::value &&
                       __has_random_access_iterator_category<_ForwardOutIterator>::value) {
    return std::__simd_walk_3(
        __first1,
        __last1 - __first1,
        __first2,
        __result,
        [&](__iter_reference<_ForwardIterator1> __in1,
            __iter_reference<_ForwardIterator2> __in2,
            __iter_reference<_ForwardOutIterator> __out_value) { __out_value = __op(__in1, __in2); });
  } else {
    return std::transform(__first1, __last1, __first2, __result, __op);
  }
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_TRANSFORM_H
