//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_TRANSFORM_REDUCE_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_TRANSFORM_REDUCE_H

#include <__algorithm/pstl_backends/cpu_backends/backend.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__numeric/transform_reduce.h>
#include <__type_traits/is_arithmetic.h>
#include <__type_traits/is_execution_policy.h>
#include <__type_traits/operation_traits.h>
#include <__utility/move.h>
#include <__utility/terminate_on_exception.h>
#include <new>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <
    typename _DifferenceType,
    typename _Tp,
    typename _BinaryOperation,
    typename _UnaryOperation,
    __enable_if_t<__is_trivial_plus_operation<_BinaryOperation, _Tp, _Tp>::value && is_arithmetic_v<_Tp>, int> = 0>
_LIBCPP_HIDE_FROM_ABI _Tp
__simd_transform_reduce(_DifferenceType __n, _Tp __init, _BinaryOperation, _UnaryOperation __f) noexcept {
  _PSTL_PRAGMA_SIMD_REDUCTION(+ : __init)
  for (_DifferenceType __i = 0; __i < __n; ++__i)
    __init += __f(__i);
  return __init;
}

template <
    typename _Size,
    typename _Tp,
    typename _BinaryOperation,
    typename _UnaryOperation,
    __enable_if_t<!(__is_trivial_plus_operation<_BinaryOperation, _Tp, _Tp>::value && is_arithmetic_v<_Tp>), int> = 0>
_LIBCPP_HIDE_FROM_ABI _Tp
__simd_transform_reduce(_Size __n, _Tp __init, _BinaryOperation __binary_op, _UnaryOperation __f) noexcept {
  const _Size __block_size = __lane_size / sizeof(_Tp);
  if (__n > 2 * __block_size && __block_size > 1) {
    alignas(__lane_size) char __lane_buffer[__lane_size];
    _Tp* __lane = reinterpret_cast<_Tp*>(__lane_buffer);

    // initializer
    _PSTL_PRAGMA_SIMD
    for (_Size __i = 0; __i < __block_size; ++__i) {
      ::new (__lane + __i) _Tp(__binary_op(__f(__i), __f(__block_size + __i)));
    }
    // main loop
    _Size __i                    = 2 * __block_size;
    const _Size __last_iteration = __block_size * (__n / __block_size);
    for (; __i < __last_iteration; __i += __block_size) {
      _PSTL_PRAGMA_SIMD
      for (_Size __j = 0; __j < __block_size; ++__j) {
        __lane[__j] = __binary_op(std::move(__lane[__j]), __f(__i + __j));
      }
    }
    // remainder
    _PSTL_PRAGMA_SIMD
    for (_Size __j = 0; __j < __n - __last_iteration; ++__j) {
      __lane[__j] = __binary_op(std::move(__lane[__j]), __f(__last_iteration + __j));
    }
    // combiner
    for (_Size __j = 0; __j < __block_size; ++__j) {
      __init = __binary_op(std::move(__init), std::move(__lane[__j]));
    }
    // destroyer
    _PSTL_PRAGMA_SIMD
    for (_Size __j = 0; __j < __block_size; ++__j) {
      __lane[__j].~_Tp();
    }
  } else {
    for (_Size __i = 0; __i < __n; ++__i) {
      __init = __binary_op(std::move(__init), __f(__i));
    }
  }
  return __init;
}

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Tp,
          class _BinaryOperation1,
          class _BinaryOperation2>
_LIBCPP_HIDE_FROM_ABI _Tp __pstl_transform_reduce(
    __cpu_backend_tag,
    _ForwardIterator1 __first1,
    _ForwardIterator1 __last1,
    _ForwardIterator2 __first2,
    _Tp __init,
    _BinaryOperation1 __reduce,
    _BinaryOperation2 __transform) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator1>::value &&
                __has_random_access_iterator_category<_ForwardIterator2>::value) {
    return std::__terminate_on_exception([&] {
      return __par_backend::__parallel_transform_reduce(
          __first1,
          std::move(__last1),
          [__first1, __first2, __transform](_ForwardIterator1 __iter) {
            return __transform(*__iter, *(__first2 + (__iter - __first1)));
          },
          std::move(__init),
          std::move(__reduce),
          [__first1, __first2, __reduce, __transform](
              _ForwardIterator1 __brick_first, _ForwardIterator1 __brick_last, _Tp __brick_init) {
            return std::__pstl_transform_reduce<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{},
                __brick_first,
                std::move(__brick_last),
                __first2 + (__brick_first - __first1),
                std::move(__brick_init),
                std::move(__reduce),
                std::move(__transform));
          });
    });
  } else if constexpr (__is_unsequenced_execution_policy_v<_ExecutionPolicy> &&
                       __has_random_access_iterator_category<_ForwardIterator1>::value &&
                       __has_random_access_iterator_category<_ForwardIterator2>::value) {
    return std::__simd_transform_reduce(
        __last1 - __first1, std::move(__init), std::move(__reduce), [&](__iter_diff_t<_ForwardIterator1> __i) {
          return __transform(__first1[__i], __first2[__i]);
        });
  } else {
    return std::transform_reduce(
        std::move(__first1),
        std::move(__last1),
        std::move(__first2),
        std::move(__init),
        std::move(__reduce),
        std::move(__transform));
  }
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Tp, class _BinaryOperation, class _UnaryOperation>
_LIBCPP_HIDE_FROM_ABI _Tp __pstl_transform_reduce(
    __cpu_backend_tag,
    _ForwardIterator __first,
    _ForwardIterator __last,
    _Tp __init,
    _BinaryOperation __reduce,
    _UnaryOperation __transform) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator>::value) {
    return std::__terminate_on_exception([&] {
      return __par_backend::__parallel_transform_reduce(
          std::move(__first),
          std::move(__last),
          [__transform](_ForwardIterator __iter) { return __transform(*__iter); },
          std::move(__init),
          __reduce,
          [__transform, __reduce](auto __brick_first, auto __brick_last, _Tp __brick_init) {
            return std::__pstl_transform_reduce<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{},
                std::move(__brick_first),
                std::move(__brick_last),
                std::move(__brick_init),
                std::move(__reduce),
                std::move(__transform));
          });
    });
  } else if constexpr (__is_unsequenced_execution_policy_v<_ExecutionPolicy> &&
                       __has_random_access_iterator_category<_ForwardIterator>::value) {
    return std::__simd_transform_reduce(
        __last - __first,
        std::move(__init),
        std::move(__reduce),
        [=, &__transform](__iter_diff_t<_ForwardIterator> __i) { return __transform(__first[__i]); });
  } else {
    return std::transform_reduce(
        std::move(__first), std::move(__last), std::move(__init), std::move(__reduce), std::move(__transform));
  }
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_TRANSFORM_REDUCE_H
