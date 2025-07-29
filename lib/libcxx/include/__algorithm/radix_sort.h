// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_RADIX_SORT_H
#define _LIBCPP___ALGORITHM_RADIX_SORT_H

// This is an implementation of classic LSD radix sort algorithm, running in linear time and using `O(max(N, M))`
// additional memory, where `N` is size of an input range, `M` - maximum value of
// a radix of the sorted integer type. Type of the radix and its maximum value are determined at compile time
// based on type returned by function `__radix`. The default radix is uint8.

// The algorithm is equivalent to several consecutive calls of counting sort for each
// radix of the sorted numbers from low to high byte.
// The algorithm uses a temporary buffer of size equal to size of the input range. Each `i`-th pass
// of the algorithm sorts values by `i`-th radix and moves values to the temporary buffer (for each even `i`, counted
// from zero), or moves them back to the initial range (for each odd `i`). If there is only one radix in sorted integers
// (e.g. int8), the sorted values are placed to the buffer, and then moved back to the initial range.

// The implementation also has several optimizations:
// - the counters for the counting sort are calculated in one pass for all radices;
// - if all values of a radix are the same, we do not sort that radix, and just move items to the buffer;
// - if two consecutive radices satisfies condition above, we do nothing for these two radices.

#include <__algorithm/for_each.h>
#include <__algorithm/move.h>
#include <__bit/bit_log2.h>
#include <__bit/countl.h>
#include <__config>
#include <__functional/identity.h>
#include <__iterator/distance.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/move_iterator.h>
#include <__iterator/next.h>
#include <__iterator/reverse_iterator.h>
#include <__numeric/partial_sum.h>
#include <__type_traits/decay.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/invoke.h>
#include <__type_traits/is_assignable.h>
#include <__type_traits/is_integral.h>
#include <__type_traits/is_unsigned.h>
#include <__type_traits/make_unsigned.h>
#include <__utility/forward.h>
#include <__utility/integer_sequence.h>
#include <__utility/move.h>
#include <__utility/pair.h>
#include <climits>
#include <cstdint>
#include <initializer_list>
#include <limits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 14

template <class _InputIterator, class _OutputIterator>
_LIBCPP_HIDE_FROM_ABI pair<_OutputIterator, __iter_value_type<_InputIterator>>
__partial_sum_max(_InputIterator __first, _InputIterator __last, _OutputIterator __result) {
  if (__first == __last)
    return {__result, 0};

  auto __max                              = *__first;
  __iter_value_type<_InputIterator> __sum = *__first;
  *__result                               = __sum;

  while (++__first != __last) {
    if (__max < *__first) {
      __max = *__first;
    }
    __sum       = std::move(__sum) + *__first;
    *++__result = __sum;
  }
  return {++__result, __max};
}

template <class _Value, class _Map, class _Radix>
struct __radix_sort_traits {
  using __image_type _LIBCPP_NODEBUG = decay_t<__invoke_result_t<_Map, _Value>>;
  static_assert(is_unsigned<__image_type>::value);

  using __radix_type _LIBCPP_NODEBUG = decay_t<__invoke_result_t<_Radix, __image_type>>;
  static_assert(is_integral<__radix_type>::value);

  static constexpr auto __radix_value_range = numeric_limits<__radix_type>::max() + 1;
  static constexpr auto __radix_size        = std::__bit_log2<uint64_t>(__radix_value_range);
  static constexpr auto __radix_count       = sizeof(__image_type) * CHAR_BIT / __radix_size;
};

template <class _Value, class _Map>
struct __counting_sort_traits {
  using __image_type _LIBCPP_NODEBUG = decay_t<__invoke_result_t<_Map, _Value>>;
  static_assert(is_unsigned<__image_type>::value);

  static constexpr const auto __value_range = numeric_limits<__image_type>::max() + 1;
  static constexpr auto __radix_size        = std::__bit_log2<uint64_t>(__value_range);
};

template <class _Radix, class _Integer>
_LIBCPP_HIDE_FROM_ABI auto __nth_radix(size_t __radix_number, _Radix __radix, _Integer __n) {
  static_assert(is_unsigned<_Integer>::value);
  using __traits = __counting_sort_traits<_Integer, _Radix>;

  return __radix(static_cast<_Integer>(__n >> __traits::__radix_size * __radix_number));
}

template <class _ForwardIterator, class _Map, class _RandomAccessIterator>
_LIBCPP_HIDE_FROM_ABI void
__collect(_ForwardIterator __first, _ForwardIterator __last, _Map __map, _RandomAccessIterator __counters) {
  using __value_type = __iter_value_type<_ForwardIterator>;
  using __traits     = __counting_sort_traits<__value_type, _Map>;

  std::for_each(__first, __last, [&__counters, &__map](const auto& __preimage) { ++__counters[__map(__preimage)]; });

  const auto __counters_end = __counters + __traits::__value_range;
  std::partial_sum(__counters, __counters_end, __counters);
}

template <class _ForwardIterator, class _RandomAccessIterator1, class _Map, class _RandomAccessIterator2>
_LIBCPP_HIDE_FROM_ABI void
__dispose(_ForwardIterator __first,
          _ForwardIterator __last,
          _RandomAccessIterator1 __result,
          _Map __map,
          _RandomAccessIterator2 __counters) {
  std::for_each(__first, __last, [&__result, &__counters, &__map](auto&& __preimage) {
    auto __index      = __counters[__map(__preimage)]++;
    __result[__index] = std::move(__preimage);
  });
}

template <class _ForwardIterator,
          class _Map,
          class _Radix,
          class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          size_t... _Radices>
_LIBCPP_HIDE_FROM_ABI bool __collect_impl(
    _ForwardIterator __first,
    _ForwardIterator __last,
    _Map __map,
    _Radix __radix,
    _RandomAccessIterator1 __counters,
    _RandomAccessIterator2 __maximums,
    index_sequence<_Radices...>) {
  using __value_type                 = __iter_value_type<_ForwardIterator>;
  constexpr auto __radix_value_range = __radix_sort_traits<__value_type, _Map, _Radix>::__radix_value_range;

  auto __previous  = numeric_limits<__invoke_result_t<_Map, __value_type>>::min();
  auto __is_sorted = true;
  std::for_each(__first, __last, [&__counters, &__map, &__radix, &__previous, &__is_sorted](const auto& __value) {
    auto __current = __map(__value);
    __is_sorted &= (__current >= __previous);
    __previous = __current;

    (++__counters[_Radices][std::__nth_radix(_Radices, __radix, __current)], ...);
  });

  ((__maximums[_Radices] =
        std::__partial_sum_max(__counters[_Radices], __counters[_Radices] + __radix_value_range, __counters[_Radices])
            .second),
   ...);

  return __is_sorted;
}

template <class _ForwardIterator, class _Map, class _Radix, class _RandomAccessIterator1, class _RandomAccessIterator2>
_LIBCPP_HIDE_FROM_ABI bool
__collect(_ForwardIterator __first,
          _ForwardIterator __last,
          _Map __map,
          _Radix __radix,
          _RandomAccessIterator1 __counters,
          _RandomAccessIterator2 __maximums) {
  using __value_type           = __iter_value_type<_ForwardIterator>;
  constexpr auto __radix_count = __radix_sort_traits<__value_type, _Map, _Radix>::__radix_count;
  return std::__collect_impl(
      __first, __last, __map, __radix, __counters, __maximums, make_index_sequence<__radix_count>());
}

template <class _BidirectionalIterator, class _RandomAccessIterator1, class _Map, class _RandomAccessIterator2>
_LIBCPP_HIDE_FROM_ABI void __dispose_backward(
    _BidirectionalIterator __first,
    _BidirectionalIterator __last,
    _RandomAccessIterator1 __result,
    _Map __map,
    _RandomAccessIterator2 __counters) {
  std::for_each(std::make_reverse_iterator(__last),
                std::make_reverse_iterator(__first),
                [&__result, &__counters, &__map](auto&& __preimage) {
                  auto __index      = --__counters[__map(__preimage)];
                  __result[__index] = std::move(__preimage);
                });
}

template <class _ForwardIterator, class _RandomAccessIterator, class _Map>
_LIBCPP_HIDE_FROM_ABI _RandomAccessIterator
__counting_sort_impl(_ForwardIterator __first, _ForwardIterator __last, _RandomAccessIterator __result, _Map __map) {
  using __value_type = __iter_value_type<_ForwardIterator>;
  using __traits     = __counting_sort_traits<__value_type, _Map>;

  __iter_diff_t<_RandomAccessIterator> __counters[__traits::__value_range + 1] = {0};

  std::__collect(__first, __last, __map, std::next(std::begin(__counters)));
  std::__dispose(__first, __last, __result, __map, std::begin(__counters));

  return __result + __counters[__traits::__value_range];
}

template <class _RandomAccessIterator1,
          class _RandomAccessIterator2,
          class _Map,
          class _Radix,
          enable_if_t< __radix_sort_traits<__iter_value_type<_RandomAccessIterator1>, _Map, _Radix>::__radix_count == 1,
                       int> = 0>
_LIBCPP_HIDE_FROM_ABI void __radix_sort_impl(
    _RandomAccessIterator1 __first,
    _RandomAccessIterator1 __last,
    _RandomAccessIterator2 __buffer,
    _Map __map,
    _Radix __radix) {
  auto __buffer_end = std::__counting_sort_impl(__first, __last, __buffer, [&__map, &__radix](const auto& __value) {
    return __radix(__map(__value));
  });

  std::move(__buffer, __buffer_end, __first);
}

template <
    class _RandomAccessIterator1,
    class _RandomAccessIterator2,
    class _Map,
    class _Radix,
    enable_if_t< __radix_sort_traits<__iter_value_type<_RandomAccessIterator1>, _Map, _Radix>::__radix_count % 2 == 0,
                 int> = 0 >
_LIBCPP_HIDE_FROM_ABI void __radix_sort_impl(
    _RandomAccessIterator1 __first,
    _RandomAccessIterator1 __last,
    _RandomAccessIterator2 __buffer_begin,
    _Map __map,
    _Radix __radix) {
  using __value_type = __iter_value_type<_RandomAccessIterator1>;
  using __traits     = __radix_sort_traits<__value_type, _Map, _Radix>;

  __iter_diff_t<_RandomAccessIterator1> __counters[__traits::__radix_count][__traits::__radix_value_range] = {{0}};
  __iter_diff_t<_RandomAccessIterator1> __maximums[__traits::__radix_count]                                = {0};
  const auto __is_sorted = std::__collect(__first, __last, __map, __radix, __counters, __maximums);
  if (!__is_sorted) {
    const auto __range_size = std::distance(__first, __last);
    auto __buffer_end       = __buffer_begin + __range_size;
    for (size_t __radix_number = 0; __radix_number < __traits::__radix_count; __radix_number += 2) {
      const auto __n0th_is_single = __maximums[__radix_number] == __range_size;
      const auto __n1th_is_single = __maximums[__radix_number + 1] == __range_size;

      if (__n0th_is_single && __n1th_is_single) {
        continue;
      }

      if (__n0th_is_single) {
        std::move(__first, __last, __buffer_begin);
      } else {
        auto __n0th = [__radix_number, &__map, &__radix](const auto& __v) {
          return std::__nth_radix(__radix_number, __radix, __map(__v));
        };
        std::__dispose_backward(__first, __last, __buffer_begin, __n0th, __counters[__radix_number]);
      }

      if (__n1th_is_single) {
        std::move(__buffer_begin, __buffer_end, __first);
      } else {
        auto __n1th = [__radix_number, &__map, &__radix](const auto& __v) {
          return std::__nth_radix(__radix_number + 1, __radix, __map(__v));
        };
        std::__dispose_backward(__buffer_begin, __buffer_end, __first, __n1th, __counters[__radix_number + 1]);
      }
    }
  }
}

_LIBCPP_HIDE_FROM_ABI constexpr auto __shift_to_unsigned(bool __b) { return __b; }

template <class _Ip>
_LIBCPP_HIDE_FROM_ABI constexpr auto __shift_to_unsigned(_Ip __n) {
  constexpr const auto __min_value = numeric_limits<_Ip>::min();
  return static_cast<make_unsigned_t<_Ip> >(__n ^ __min_value);
}

struct __low_byte_fn {
  template <class _Ip>
  _LIBCPP_HIDE_FROM_ABI constexpr uint8_t operator()(_Ip __integer) const {
    static_assert(is_unsigned<_Ip>::value);

    return static_cast<uint8_t>(__integer & 0xff);
  }
};

template <class _RandomAccessIterator1, class _RandomAccessIterator2, class _Map, class _Radix>
_LIBCPP_HIDE_FROM_ABI void
__radix_sort(_RandomAccessIterator1 __first,
             _RandomAccessIterator1 __last,
             _RandomAccessIterator2 __buffer,
             _Map __map,
             _Radix __radix) {
  auto __map_to_unsigned = [__map = std::move(__map)](const auto& __x) { return std::__shift_to_unsigned(__map(__x)); };
  std::__radix_sort_impl(__first, __last, __buffer, __map_to_unsigned, __radix);
}

template <class _RandomAccessIterator1, class _RandomAccessIterator2>
_LIBCPP_HIDE_FROM_ABI void
__radix_sort(_RandomAccessIterator1 __first, _RandomAccessIterator1 __last, _RandomAccessIterator2 __buffer) {
  std::__radix_sort(__first, __last, __buffer, __identity{}, __low_byte_fn{});
}

#endif // _LIBCPP_STD_VER >= 14

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_RADIX_SORT_H
