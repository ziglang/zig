//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_FIND_IF_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_FIND_IF_H

#include <__algorithm/find_if.h>
#include <__algorithm/pstl_backends/cpu_backends/backend.h>
#include <__atomic/atomic.h>
#include <__config>
#include <__functional/operations.h>
#include <__iterator/iterator_traits.h>
#include <__type_traits/is_execution_policy.h>
#include <__utility/pair.h>
#include <__utility/terminate_on_exception.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Index, class _Brick, class _Compare>
_LIBCPP_HIDE_FROM_ABI _Index
__parallel_find(_Index __first, _Index __last, _Brick __f, _Compare __comp, bool __b_first) {
  typedef typename std::iterator_traits<_Index>::difference_type _DifferenceType;
  const _DifferenceType __n      = __last - __first;
  _DifferenceType __initial_dist = __b_first ? __n : -1;
  std::atomic<_DifferenceType> __extremum(__initial_dist);
  // TODO: find out what is better here: parallel_for or parallel_reduce
  __par_backend::__parallel_for(__first, __last, [__comp, __f, __first, &__extremum](_Index __i, _Index __j) {
    // See "Reducing Contention Through Priority Updates", PPoPP '13, for discussion of
    // why using a shared variable scales fairly well in this situation.
    if (__comp(__i - __first, __extremum)) {
      _Index __res = __f(__i, __j);
      // If not '__last' returned then we found what we want so put this to extremum
      if (__res != __j) {
        const _DifferenceType __k = __res - __first;
        for (_DifferenceType __old = __extremum; __comp(__k, __old); __old = __extremum) {
          __extremum.compare_exchange_weak(__old, __k);
        }
      }
    }
  });
  return __extremum != __initial_dist ? __first + __extremum : __last;
}

template <class _Index, class _DifferenceType, class _Compare>
_LIBCPP_HIDE_FROM_ABI _Index
__simd_first(_Index __first, _DifferenceType __begin, _DifferenceType __end, _Compare __comp) noexcept {
  // Experiments show good block sizes like this
  const _DifferenceType __block_size                        = 8;
  alignas(__lane_size) _DifferenceType __lane[__block_size] = {0};
  while (__end - __begin >= __block_size) {
    _DifferenceType __found = 0;
    _PSTL_PRAGMA_SIMD_REDUCTION(| : __found) for (_DifferenceType __i = __begin; __i < __begin + __block_size; ++__i) {
      const _DifferenceType __t = __comp(__first, __i);
      __lane[__i - __begin]     = __t;
      __found |= __t;
    }
    if (__found) {
      _DifferenceType __i;
      // This will vectorize
      for (__i = 0; __i < __block_size; ++__i) {
        if (__lane[__i]) {
          break;
        }
      }
      return __first + __begin + __i;
    }
    __begin += __block_size;
  }

  // Keep remainder scalar
  while (__begin != __end) {
    if (__comp(__first, __begin)) {
      return __first + __begin;
    }
    ++__begin;
  }
  return __first + __end;
}

template <class _ExecutionPolicy, class _ForwardIterator, class _Predicate>
_LIBCPP_HIDE_FROM_ABI _ForwardIterator
__pstl_find_if(__cpu_backend_tag, _ForwardIterator __first, _ForwardIterator __last, _Predicate __pred) {
  if constexpr (__is_parallel_execution_policy_v<_ExecutionPolicy> &&
                __has_random_access_iterator_category<_ForwardIterator>::value) {
    return std::__terminate_on_exception([&] {
      return std::__parallel_find(
          __first,
          __last,
          [&__pred](_ForwardIterator __brick_first, _ForwardIterator __brick_last) {
            return std::__pstl_find_if<__remove_parallel_policy_t<_ExecutionPolicy>>(
                __cpu_backend_tag{}, __brick_first, __brick_last, __pred);
          },
          less<>{},
          true);
    });
  } else if constexpr (__is_unsequenced_execution_policy_v<_ExecutionPolicy> &&
                       __has_random_access_iterator_category<_ForwardIterator>::value) {
    using __diff_t = __iter_diff_t<_ForwardIterator>;
    return std::__simd_first(__first, __diff_t(0), __last - __first, [&__pred](_ForwardIterator __iter, __diff_t __i) {
      return __pred(__iter[__i]);
    });
  } else {
    return std::find_if(__first, __last, __pred);
  }
}

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_PSTL) && _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKENDS_FIND_IF_H
