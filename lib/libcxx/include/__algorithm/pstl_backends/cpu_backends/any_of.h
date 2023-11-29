//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKEND_ANY_OF_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKEND_ANY_OF_H

#include <__algorithm/any_of.h>
#include <__algorithm/find_if.h>
#include <__algorithm/pstl_backends/cpu_backends/backend.h>
#include <__atomic/atomic.h>
#include <__atomic/memory_order.h>
#include <__config>
#include <__functional/operations.h>
#include <__iterator/iterator_traits.h>
#include <__type_traits/is_execution_policy.h>
#include <__utility/pair.h>
#include <__utility/terminate_on_exception.h>
#include <cstdint>

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Index, class _Brick>
_LIBCPP_HIDE_FROM_ABI bool __parallel_or(_Index __first, _Index __last, _Brick __f) {
  std::atomic<bool> __found(false);
  __par_backend::__parallel_for(__first, __last, [__f, &__found](_Index __i, _Index __j) {
    if (!__found.load(std::memory_order_relaxed) && __f(__i, __j)) {
      __found.store(true, std::memory_order_relaxed);
      __par_backend::__cancel_execution();
    }
  });
  return __found;
}

// TODO: check whether __simd_first() can be used here
template <class _Index, class _DifferenceType, class _Pred>
_LIBCPP_HIDE_FROM_ABI bool __simd_or(_Index __first, _DifferenceType __n, _Pred __pred) noexcept {
  _DifferenceType __block_size = 4 < __n ? 4 : __n;
  const _Index __last          = __first + __n;
  while (__last != __first) {
    int32_t __flag = 1;
    _PSTL_PRAGMA_SIMD_REDUCTION(& : __flag)
    for (_DifferenceType __i = 0; __i < __block_size; ++__i)
      if (__pred(*(__first + __i)))
        __flag = 0;
    if (!__flag)
      return true;

    __first += __block_size;
    if (__last - __first >= __block_size << 1) {
      // Double the block _Size.  Any unnecessary iterations can be amortized against work done so far.
      __block_size <<= 1;
    } else {
      __block_size = __last - __first;
    }
  }
  return false;
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Predicate>
_LIBCPP_HIDE_FROM_ABI bool
__pstl_any_of(__cpu_backend_tag, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator>::value) {
    return std::__terminate_on_exception([&] {
      return std::__parallel_or(
          __first, __last, [&__pred](_ForwardIterator __brick_first, _ForwardIterator __brick_last) {
            return std::__pstl_any_of<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{}, __brick_first, __brick_last, __pred);
          });
    });
  } else if constexpr (__is_unsequenced_execution_policy_v<_ExecutionPolicy> &&
                       __has_random_access_iterator_category<_ForwardIterator>::value) {
    return std::__simd_or(__first, __last - __first, __pred);
  } else {
    return std::any_of(__first, __last, __pred);
  }
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKEND_ANY_OF_H
