// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_ADVANCE_H
#define _LIBCPP___ITERATOR_ADVANCE_H

#include <__config>
#include <__debug>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iterator_traits.h>
#include <__utility/move.h>
#include <concepts>
#include <cstdlib>
#include <limits>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIter>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
void __advance(_InputIter& __i, typename iterator_traits<_InputIter>::difference_type __n, input_iterator_tag) {
  for (; __n > 0; --__n)
    ++__i;
}

template <class _BiDirIter>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
void __advance(_BiDirIter& __i, typename iterator_traits<_BiDirIter>::difference_type __n, bidirectional_iterator_tag) {
  if (__n >= 0)
    for (; __n > 0; --__n)
      ++__i;
  else
    for (; __n < 0; ++__n)
      --__i;
}

template <class _RandIter>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
void __advance(_RandIter& __i, typename iterator_traits<_RandIter>::difference_type __n, random_access_iterator_tag) {
  __i += __n;
}

template <
    class _InputIter, class _Distance,
    class _IntegralDistance = decltype(_VSTD::__convert_to_integral(declval<_Distance>())),
    class = __enable_if_t<is_integral<_IntegralDistance>::value> >
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
void advance(_InputIter& __i, _Distance __orig_n) {
  typedef typename iterator_traits<_InputIter>::difference_type _Difference;
  _Difference __n = static_cast<_Difference>(_VSTD::__convert_to_integral(__orig_n));
  _LIBCPP_ASSERT(__n >= 0 || __is_cpp17_bidirectional_iterator<_InputIter>::value,
                 "Attempt to advance(it, n) with negative n on a non-bidirectional iterator");
  _VSTD::__advance(__i, __n, typename iterator_traits<_InputIter>::iterator_category());
}

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

// [range.iter.op.advance]

namespace ranges {
namespace __advance {

struct __fn {
private:
  template <class _Ip>
  _LIBCPP_HIDE_FROM_ABI
  static constexpr void __advance_forward(_Ip& __i, iter_difference_t<_Ip> __n) {
    while (__n > 0) {
      --__n;
      ++__i;
    }
  }

  template <class _Ip>
  _LIBCPP_HIDE_FROM_ABI
  static constexpr void __advance_backward(_Ip& __i, iter_difference_t<_Ip> __n) {
    while (__n < 0) {
      ++__n;
      --__i;
    }
  }

public:
  // Preconditions: If `I` does not model `bidirectional_iterator`, `n` is not negative.
  template <input_or_output_iterator _Ip>
  _LIBCPP_HIDE_FROM_ABI
  constexpr void operator()(_Ip& __i, iter_difference_t<_Ip> __n) const {
    _LIBCPP_ASSERT(__n >= 0 || bidirectional_iterator<_Ip>,
                   "If `n < 0`, then `bidirectional_iterator<I>` must be true.");

    // If `I` models `random_access_iterator`, equivalent to `i += n`.
    if constexpr (random_access_iterator<_Ip>) {
      __i += __n;
      return;
    } else if constexpr (bidirectional_iterator<_Ip>) {
      // Otherwise, if `n` is non-negative, increments `i` by `n`.
      __advance_forward(__i, __n);
      // Otherwise, decrements `i` by `-n`.
      __advance_backward(__i, __n);
      return;
    } else {
      // Otherwise, if `n` is non-negative, increments `i` by `n`.
      __advance_forward(__i, __n);
      return;
    }
  }

  // Preconditions: Either `assignable_from<I&, S> || sized_sentinel_for<S, I>` is modeled, or [i, bound) denotes a range.
  template <input_or_output_iterator _Ip, sentinel_for<_Ip> _Sp>
  _LIBCPP_HIDE_FROM_ABI
  constexpr void operator()(_Ip& __i, _Sp __bound) const {
    // If `I` and `S` model `assignable_from<I&, S>`, equivalent to `i = std::move(bound)`.
    if constexpr (assignable_from<_Ip&, _Sp>) {
      __i = _VSTD::move(__bound);
    }
    // Otherwise, if `S` and `I` model `sized_sentinel_for<S, I>`, equivalent to `ranges::advance(i, bound - i)`.
    else if constexpr (sized_sentinel_for<_Sp, _Ip>) {
      (*this)(__i, __bound - __i);
    }
    // Otherwise, while `bool(i != bound)` is true, increments `i`.
    else {
      while (__i != __bound) {
        ++__i;
      }
    }
  }

  // Preconditions:
  //   * If `n > 0`, [i, bound) denotes a range.
  //   * If `n == 0`, [i, bound) or [bound, i) denotes a range.
  //   * If `n < 0`, [bound, i) denotes a range, `I` models `bidirectional_iterator`, and `I` and `S` model `same_as<I, S>`.
  // Returns: `n - M`, where `M` is the difference between the the ending and starting position.
  template <input_or_output_iterator _Ip, sentinel_for<_Ip> _Sp>
  _LIBCPP_HIDE_FROM_ABI
  constexpr iter_difference_t<_Ip> operator()(_Ip& __i, iter_difference_t<_Ip> __n, _Sp __bound) const {
    _LIBCPP_ASSERT((__n >= 0) || (bidirectional_iterator<_Ip> && same_as<_Ip, _Sp>),
                   "If `n < 0`, then `bidirectional_iterator<I> && same_as<I, S>` must be true.");
    // If `S` and `I` model `sized_sentinel_for<S, I>`:
    if constexpr (sized_sentinel_for<_Sp, _Ip>) {
      // If |n| >= |bound - i|, equivalent to `ranges::advance(i, bound)`.
      // __magnitude_geq(a, b) returns |a| >= |b|, assuming they have the same sign.
      auto __magnitude_geq = [](auto __a, auto __b) {
        return __a == 0 ? __b == 0 :
               __a > 0  ? __a >= __b :
                          __a <= __b;
      };
      if (const auto __M = __bound - __i; __magnitude_geq(__n, __M)) {
        (*this)(__i, __bound);
        return __n - __M;
      }

      // Otherwise, equivalent to `ranges::advance(i, n)`.
      (*this)(__i, __n);
      return 0;
    } else {
      // Otherwise, if `n` is non-negative, while `bool(i != bound)` is true, increments `i` but at
      // most `n` times.
      while (__i != __bound && __n > 0) {
        ++__i;
        --__n;
      }

      // Otherwise, while `bool(i != bound)` is true, decrements `i` but at most `-n` times.
      if constexpr (bidirectional_iterator<_Ip> && same_as<_Ip, _Sp>) {
        while (__i != __bound && __n < 0) {
          --__i;
          ++__n;
        }
      }
      return __n;
    }

    _LIBCPP_UNREACHABLE();
  }
};

} // namespace __advance

inline namespace __cpo {
  inline constexpr auto advance = __advance::__fn{};
} // namespace __cpo
} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_ADVANCE_H
