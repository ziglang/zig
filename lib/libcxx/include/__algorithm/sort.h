//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_SORT_H
#define _LIBCPP___ALGORITHM_SORT_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/iterator_operations.h>
#include <__algorithm/min_element.h>
#include <__algorithm/partial_sort.h>
#include <__algorithm/unwrap_iter.h>
#include <__bits>
#include <__config>
#include <__debug>
#include <__debug_utils/randomize_range.h>
#include <__functional/operations.h>
#include <__functional/ranges_operations.h>
#include <__iterator/iterator_traits.h>
#include <climits>
#include <memory>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// Wraps an algorithm policy tag and a comparator in a single struct, used to pass the policy tag around without
// changing the number of template arguments (to keep the ABI stable). This is only used for the "range" policy tag.
//
// To create an object of this type, use `_WrapAlgPolicy<T, C>::type` -- see the specialization below for the rationale.
template <class _PolicyT, class _CompT, class = void>
struct _WrapAlgPolicy {
  using type = _WrapAlgPolicy;

  using _AlgPolicy = _PolicyT;
  using _Comp = _CompT;
  _Comp& __comp;

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
  _WrapAlgPolicy(_Comp& __c) : __comp(__c) {}
};

// Specialization for the "classic" policy tag that avoids creating a struct and simply defines an alias for the
// comparator. When unwrapping, a pristine comparator is always considered to have the "classic" tag attached. Passing
// the pristine comparator where possible allows using template instantiations from the dylib.
template <class _PolicyT, class _CompT>
struct _WrapAlgPolicy<_PolicyT, _CompT, __enable_if_t<std::is_same<_PolicyT, _ClassicAlgPolicy>::value> > {
  using type = _CompT;
};

// Unwraps a pristine functor (e.g. `std::less`) as if it were wrapped using `_WrapAlgPolicy`. The policy tag is always
// set to "classic".
template <class _CompT>
struct _UnwrapAlgPolicy {
  using _AlgPolicy = _ClassicAlgPolicy;
  using _Comp = _CompT;

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 static
  _Comp __get_comp(_Comp __comp) { return __comp; }
};

// Unwraps a `_WrapAlgPolicy` struct.
template <class... _Ts>
struct _UnwrapAlgPolicy<_WrapAlgPolicy<_Ts...> > {
  using _Wrapped = _WrapAlgPolicy<_Ts...>;
  using _AlgPolicy = typename _Wrapped::_AlgPolicy;
  using _Comp = typename _Wrapped::_Comp;

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 static
  _Comp __get_comp(_Wrapped& __w) { return __w.__comp; }
};

// stable, 2-3 compares, 0-2 swaps

template <class _AlgPolicy, class _Compare, class _ForwardIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 unsigned __sort3(_ForwardIterator __x, _ForwardIterator __y, _ForwardIterator __z,
                                               _Compare __c) {
  using _Ops = _IterOps<_AlgPolicy>;

  unsigned __r = 0;
  if (!__c(*__y, *__x))   // if x <= y
  {
    if (!__c(*__z, *__y)) // if y <= z
      return __r;         // x <= y && y <= z
                          // x <= y && y > z
    _Ops::iter_swap(__y, __z);     // x <= z && y < z
    __r = 1;
    if (__c(*__y, *__x))  // if x > y
    {
      _Ops::iter_swap(__x, __y);   // x < y && y <= z
      __r = 2;
    }
    return __r;           // x <= y && y < z
  }
  if (__c(*__z, *__y))    // x > y, if y > z
  {
    _Ops::iter_swap(__x, __z);     // x < y && y < z
    __r = 1;
    return __r;
  }
  _Ops::iter_swap(__x, __y);       // x > y && y <= z
  __r = 1;                // x < y && x <= z
  if (__c(*__z, *__y))    // if y > z
  {
    _Ops::iter_swap(__y, __z);     // x <= y && y < z
    __r = 2;
  }
  return __r;
}                         // x <= y && y <= z

// stable, 3-6 compares, 0-5 swaps

template <class _AlgPolicy, class _Compare, class _ForwardIterator>
unsigned __sort4(_ForwardIterator __x1, _ForwardIterator __x2, _ForwardIterator __x3, _ForwardIterator __x4,
                 _Compare __c) {
  using _Ops = _IterOps<_AlgPolicy>;

  unsigned __r = std::__sort3<_AlgPolicy, _Compare>(__x1, __x2, __x3, __c);
  if (__c(*__x4, *__x3)) {
    _Ops::iter_swap(__x3, __x4);
    ++__r;
    if (__c(*__x3, *__x2)) {
      _Ops::iter_swap(__x2, __x3);
      ++__r;
      if (__c(*__x2, *__x1)) {
        _Ops::iter_swap(__x1, __x2);
        ++__r;
      }
    }
  }
  return __r;
}

// stable, 4-10 compares, 0-9 swaps

template <class _WrappedComp, class _ForwardIterator>
_LIBCPP_HIDDEN unsigned __sort5(_ForwardIterator __x1, _ForwardIterator __x2, _ForwardIterator __x3,
                                _ForwardIterator __x4, _ForwardIterator __x5, _WrappedComp __wrapped_comp) {
  using _Unwrap = _UnwrapAlgPolicy<_WrappedComp>;
  using _AlgPolicy = typename _Unwrap::_AlgPolicy;
  using _Ops = _IterOps<_AlgPolicy>;

  using _Compare = typename _Unwrap::_Comp;
  _Compare __c = _Unwrap::__get_comp(__wrapped_comp);

  unsigned __r = std::__sort4<_AlgPolicy, _Compare>(__x1, __x2, __x3, __x4, __c);
  if (__c(*__x5, *__x4)) {
    _Ops::iter_swap(__x4, __x5);
    ++__r;
    if (__c(*__x4, *__x3)) {
      _Ops::iter_swap(__x3, __x4);
      ++__r;
      if (__c(*__x3, *__x2)) {
        _Ops::iter_swap(__x2, __x3);
        ++__r;
        if (__c(*__x2, *__x1)) {
          _Ops::iter_swap(__x1, __x2);
          ++__r;
        }
      }
    }
  }
  return __r;
}

template <class _AlgPolicy, class _Compare, class _ForwardIterator>
_LIBCPP_HIDDEN unsigned __sort5_wrap_policy(
    _ForwardIterator __x1, _ForwardIterator __x2, _ForwardIterator __x3, _ForwardIterator __x4, _ForwardIterator __x5,
    _Compare __c) {
  using _WrappedComp = typename _WrapAlgPolicy<_AlgPolicy, _Compare>::type;
  _WrappedComp __wrapped_comp(__c);
  return std::__sort5<_WrappedComp>(
      std::move(__x1), std::move(__x2), std::move(__x3), std::move(__x4), std::move(__x5), __wrapped_comp);
}

// The comparator being simple is a prerequisite for using the branchless optimization.
template <class _Tp>
struct __is_simple_comparator : false_type {};
template <class _Tp>
struct __is_simple_comparator<__less<_Tp>&> : true_type {};
template <class _Tp>
struct __is_simple_comparator<less<_Tp>&> : true_type {};
template <class _Tp>
struct __is_simple_comparator<greater<_Tp>&> : true_type {};
#if _LIBCPP_STD_VER > 17
template <>
struct __is_simple_comparator<ranges::less&> : true_type {};
template <>
struct __is_simple_comparator<ranges::greater&> : true_type {};
#endif

template <class _Compare, class _Iter, class _Tp = typename iterator_traits<_Iter>::value_type>
using __use_branchless_sort =
    integral_constant<bool, __is_cpp17_contiguous_iterator<_Iter>::value && sizeof(_Tp) <= sizeof(void*) &&
                                is_arithmetic<_Tp>::value && __is_simple_comparator<_Compare>::value>;

// Ensures that __c(*__x, *__y) is true by swapping *__x and *__y if necessary.
template <class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI void __cond_swap(_RandomAccessIterator __x, _RandomAccessIterator __y, _Compare __c) {
  // Note: this function behaves correctly even with proxy iterators (because it relies on `value_type`).
  using value_type = typename iterator_traits<_RandomAccessIterator>::value_type;
  bool __r = __c(*__x, *__y);
  value_type __tmp = __r ? *__x : *__y;
  *__y = __r ? *__y : *__x;
  *__x = __tmp;
}

// Ensures that *__x, *__y and *__z are ordered according to the comparator __c,
// under the assumption that *__y and *__z are already ordered.
template <class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI void __partially_sorted_swap(_RandomAccessIterator __x, _RandomAccessIterator __y,
                                                          _RandomAccessIterator __z, _Compare __c) {
  // Note: this function behaves correctly even with proxy iterators (because it relies on `value_type`).
  using value_type = typename iterator_traits<_RandomAccessIterator>::value_type;
  bool __r = __c(*__z, *__x);
  value_type __tmp = __r ? *__z : *__x;
  *__z = __r ? *__x : *__z;
  __r = __c(__tmp, *__y);
  *__x = __r ? *__x : *__y;
  *__y = __r ? *__y : __tmp;
}

template <class, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI __enable_if_t<__use_branchless_sort<_Compare, _RandomAccessIterator>::value, void>
__sort3_maybe_branchless(_RandomAccessIterator __x1, _RandomAccessIterator __x2, _RandomAccessIterator __x3,
                         _Compare __c) {
  _VSTD::__cond_swap<_Compare>(__x2, __x3, __c);
  _VSTD::__partially_sorted_swap<_Compare>(__x1, __x2, __x3, __c);
}

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI __enable_if_t<!__use_branchless_sort<_Compare, _RandomAccessIterator>::value, void>
__sort3_maybe_branchless(_RandomAccessIterator __x1, _RandomAccessIterator __x2, _RandomAccessIterator __x3,
                         _Compare __c) {
  std::__sort3<_AlgPolicy, _Compare>(__x1, __x2, __x3, __c);
}

template <class, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI __enable_if_t<__use_branchless_sort<_Compare, _RandomAccessIterator>::value, void>
__sort4_maybe_branchless(_RandomAccessIterator __x1, _RandomAccessIterator __x2, _RandomAccessIterator __x3,
                         _RandomAccessIterator __x4, _Compare __c) {
  _VSTD::__cond_swap<_Compare>(__x1, __x3, __c);
  _VSTD::__cond_swap<_Compare>(__x2, __x4, __c);
  _VSTD::__cond_swap<_Compare>(__x1, __x2, __c);
  _VSTD::__cond_swap<_Compare>(__x3, __x4, __c);
  _VSTD::__cond_swap<_Compare>(__x2, __x3, __c);
}

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI __enable_if_t<!__use_branchless_sort<_Compare, _RandomAccessIterator>::value, void>
__sort4_maybe_branchless(_RandomAccessIterator __x1, _RandomAccessIterator __x2, _RandomAccessIterator __x3,
                         _RandomAccessIterator __x4, _Compare __c) {
  std::__sort4<_AlgPolicy, _Compare>(__x1, __x2, __x3, __x4, __c);
}

template <class, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI __enable_if_t<__use_branchless_sort<_Compare, _RandomAccessIterator>::value, void>
__sort5_maybe_branchless(_RandomAccessIterator __x1, _RandomAccessIterator __x2, _RandomAccessIterator __x3,
                         _RandomAccessIterator __x4, _RandomAccessIterator __x5, _Compare __c) {
  _VSTD::__cond_swap<_Compare>(__x1, __x2, __c);
  _VSTD::__cond_swap<_Compare>(__x4, __x5, __c);
  _VSTD::__partially_sorted_swap<_Compare>(__x3, __x4, __x5, __c);
  _VSTD::__cond_swap<_Compare>(__x2, __x5, __c);
  _VSTD::__partially_sorted_swap<_Compare>(__x1, __x3, __x4, __c);
  _VSTD::__partially_sorted_swap<_Compare>(__x2, __x3, __x4, __c);
}

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI __enable_if_t<!__use_branchless_sort<_Compare, _RandomAccessIterator>::value, void>
__sort5_maybe_branchless(_RandomAccessIterator __x1, _RandomAccessIterator __x2, _RandomAccessIterator __x3,
                         _RandomAccessIterator __x4, _RandomAccessIterator __x5, _Compare __c) {
  std::__sort5_wrap_policy<_AlgPolicy, _Compare>(__x1, __x2, __x3, __x4, __x5, __c);
}

// Assumes size > 0
template <class _AlgPolicy, class _Compare, class _BidirectionalIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 void __selection_sort(_BidirectionalIterator __first, _BidirectionalIterator __last,
                                                    _Compare __comp) {
  _BidirectionalIterator __lm1 = __last;
  for (--__lm1; __first != __lm1; ++__first) {
    _BidirectionalIterator __i = std::__min_element<_Compare>(__first, __last, __comp);
    if (__i != __first)
      _IterOps<_AlgPolicy>::iter_swap(__first, __i);
  }
}

template <class _AlgPolicy, class _Compare, class _BidirectionalIterator>
void __insertion_sort(_BidirectionalIterator __first, _BidirectionalIterator __last, _Compare __comp) {
  using _Ops = _IterOps<_AlgPolicy>;

  typedef typename iterator_traits<_BidirectionalIterator>::value_type value_type;
  if (__first != __last) {
    _BidirectionalIterator __i = __first;
    for (++__i; __i != __last; ++__i) {
      _BidirectionalIterator __j = __i;
      value_type __t(_Ops::__iter_move(__j));
      for (_BidirectionalIterator __k = __i; __k != __first && __comp(__t, *--__k); --__j)
        *__j = _Ops::__iter_move(__k);
      *__j = _VSTD::move(__t);
    }
  }
}

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
void __insertion_sort_3(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  using _Ops = _IterOps<_AlgPolicy>;

  typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
  typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
  _RandomAccessIterator __j = __first + difference_type(2);
  std::__sort3_maybe_branchless<_AlgPolicy, _Compare>(__first, __first + difference_type(1), __j, __comp);
  for (_RandomAccessIterator __i = __j + difference_type(1); __i != __last; ++__i) {
    if (__comp(*__i, *__j)) {
      value_type __t(_Ops::__iter_move(__i));
      _RandomAccessIterator __k = __j;
      __j = __i;
      do {
        *__j = _Ops::__iter_move(__k);
        __j = __k;
      } while (__j != __first && __comp(__t, *--__k));
      *__j = _VSTD::move(__t);
    }
    __j = __i;
  }
}

template <class _WrappedComp, class _RandomAccessIterator>
bool __insertion_sort_incomplete(
    _RandomAccessIterator __first, _RandomAccessIterator __last, _WrappedComp __wrapped_comp) {
  using _Unwrap = _UnwrapAlgPolicy<_WrappedComp>;
  using _AlgPolicy = typename _Unwrap::_AlgPolicy;
  using _Ops = _IterOps<_AlgPolicy>;

  using _Compare = typename _Unwrap::_Comp;
  _Compare __comp = _Unwrap::__get_comp(__wrapped_comp);

  typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
  switch (__last - __first) {
  case 0:
  case 1:
    return true;
  case 2:
    if (__comp(*--__last, *__first))
      _IterOps<_AlgPolicy>::iter_swap(__first, __last);
    return true;
  case 3:
    std::__sort3_maybe_branchless<_AlgPolicy, _Compare>(__first, __first + difference_type(1), --__last, __comp);
    return true;
  case 4:
    std::__sort4_maybe_branchless<_AlgPolicy, _Compare>(
        __first, __first + difference_type(1), __first + difference_type(2), --__last, __comp);
    return true;
  case 5:
    std::__sort5_maybe_branchless<_AlgPolicy, _Compare>(
        __first, __first + difference_type(1), __first + difference_type(2), __first + difference_type(3),
        --__last, __comp);
    return true;
  }
  typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
  _RandomAccessIterator __j = __first + difference_type(2);
  std::__sort3_maybe_branchless<_AlgPolicy, _Compare>(__first, __first + difference_type(1), __j, __comp);
  const unsigned __limit = 8;
  unsigned __count = 0;
  for (_RandomAccessIterator __i = __j + difference_type(1); __i != __last; ++__i) {
    if (__comp(*__i, *__j)) {
      value_type __t(_Ops::__iter_move(__i));
      _RandomAccessIterator __k = __j;
      __j = __i;
      do {
        *__j = _Ops::__iter_move(__k);
        __j = __k;
      } while (__j != __first && __comp(__t, *--__k));
      *__j = _VSTD::move(__t);
      if (++__count == __limit)
        return ++__i == __last;
    }
    __j = __i;
  }
  return true;
}

template <class _AlgPolicy, class _Compare, class _BidirectionalIterator>
void __insertion_sort_move(_BidirectionalIterator __first1, _BidirectionalIterator __last1,
                           typename iterator_traits<_BidirectionalIterator>::value_type* __first2, _Compare __comp) {
  using _Ops = _IterOps<_AlgPolicy>;

  typedef typename iterator_traits<_BidirectionalIterator>::value_type value_type;
  if (__first1 != __last1) {
    __destruct_n __d(0);
    unique_ptr<value_type, __destruct_n&> __h(__first2, __d);
    value_type* __last2 = __first2;
    ::new ((void*)__last2) value_type(_Ops::__iter_move(__first1));
    __d.template __incr<value_type>();
    for (++__last2; ++__first1 != __last1; ++__last2) {
      value_type* __j2 = __last2;
      value_type* __i2 = __j2;
      if (__comp(*__first1, *--__i2)) {
        ::new ((void*)__j2) value_type(std::move(*__i2));
        __d.template __incr<value_type>();
        for (--__j2; __i2 != __first2 && __comp(*__first1, *--__i2); --__j2)
          *__j2 = std::move(*__i2);
        *__j2 = _Ops::__iter_move(__first1);
      } else {
        ::new ((void*)__j2) value_type(_Ops::__iter_move(__first1));
        __d.template __incr<value_type>();
      }
    }
    __h.release();
  }
}

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
void __introsort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp,
                 typename iterator_traits<_RandomAccessIterator>::difference_type __depth) {
  using _Ops = _IterOps<_AlgPolicy>;

  typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
  typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
  const difference_type __limit =
      is_trivially_copy_constructible<value_type>::value && is_trivially_copy_assignable<value_type>::value ? 30 : 6;
  while (true) {
  __restart:
    difference_type __len = __last - __first;
    switch (__len) {
    case 0:
    case 1:
      return;
    case 2:
      if (__comp(*--__last, *__first))
        _IterOps<_AlgPolicy>::iter_swap(__first, __last);
      return;
    case 3:
      std::__sort3_maybe_branchless<_AlgPolicy, _Compare>(__first, __first + difference_type(1), --__last, __comp);
      return;
    case 4:
      std::__sort4_maybe_branchless<_AlgPolicy, _Compare>(
          __first, __first + difference_type(1), __first + difference_type(2), --__last, __comp);
      return;
    case 5:
      std::__sort5_maybe_branchless<_AlgPolicy, _Compare>(
          __first, __first + difference_type(1), __first + difference_type(2), __first + difference_type(3),
          --__last, __comp);
      return;
    }
    if (__len <= __limit) {
      std::__insertion_sort_3<_AlgPolicy, _Compare>(__first, __last, __comp);
      return;
    }
    // __len > 5
    if (__depth == 0) {
      // Fallback to heap sort as Introsort suggests.
      std::__partial_sort<_AlgPolicy, _Compare>(__first, __last, __last, __comp);
      return;
    }
    --__depth;
    _RandomAccessIterator __m = __first;
    _RandomAccessIterator __lm1 = __last;
    --__lm1;
    unsigned __n_swaps;
    {
      difference_type __delta;
      if (__len >= 1000) {
        __delta = __len / 2;
        __m += __delta;
        __delta /= 2;
        __n_swaps = std::__sort5_wrap_policy<_AlgPolicy, _Compare>(
            __first, __first + __delta, __m, __m + __delta, __lm1, __comp);
      } else {
        __delta = __len / 2;
        __m += __delta;
        __n_swaps = std::__sort3<_AlgPolicy, _Compare>(__first, __m, __lm1, __comp);
      }
    }
    // *__m is median
    // partition [__first, __m) < *__m and *__m <= [__m, __last)
    // (this inhibits tossing elements equivalent to __m around unnecessarily)
    _RandomAccessIterator __i = __first;
    _RandomAccessIterator __j = __lm1;
    // j points beyond range to be tested, *__m is known to be <= *__lm1
    // The search going up is known to be guarded but the search coming down isn't.
    // Prime the downward search with a guard.
    if (!__comp(*__i, *__m)) // if *__first == *__m
    {
      // *__first == *__m, *__first doesn't go in first part
      // manually guard downward moving __j against __i
      while (true) {
        if (__i == --__j) {
          // *__first == *__m, *__m <= all other elements
          // Parition instead into [__first, __i) == *__first and *__first < [__i, __last)
          ++__i; // __first + 1
          __j = __last;
          if (!__comp(*__first, *--__j)) // we need a guard if *__first == *(__last-1)
          {
            while (true) {
              if (__i == __j)
                return; // [__first, __last) all equivalent elements
              if (__comp(*__first, *__i)) {
                _Ops::iter_swap(__i, __j);
                ++__n_swaps;
                ++__i;
                break;
              }
              ++__i;
            }
          }
          // [__first, __i) == *__first and *__first < [__j, __last) and __j == __last - 1
          if (__i == __j)
            return;
          while (true) {
            while (!__comp(*__first, *__i))
              ++__i;
            while (__comp(*__first, *--__j))
              ;
            if (__i >= __j)
              break;
            _Ops::iter_swap(__i, __j);
            ++__n_swaps;
            ++__i;
          }
          // [__first, __i) == *__first and *__first < [__i, __last)
          // The first part is sorted, sort the second part
          // _VSTD::__sort<_Compare>(__i, __last, __comp);
          __first = __i;
          goto __restart;
        }
        if (__comp(*__j, *__m)) {
          _Ops::iter_swap(__i, __j);
          ++__n_swaps;
          break; // found guard for downward moving __j, now use unguarded partition
        }
      }
    }
    // It is known that *__i < *__m
    ++__i;
    // j points beyond range to be tested, *__m is known to be <= *__lm1
    // if not yet partitioned...
    if (__i < __j) {
      // known that *(__i - 1) < *__m
      // known that __i <= __m
      while (true) {
        // __m still guards upward moving __i
        while (__comp(*__i, *__m))
          ++__i;
        // It is now known that a guard exists for downward moving __j
        while (!__comp(*--__j, *__m))
          ;
        if (__i > __j)
          break;
        _Ops::iter_swap(__i, __j);
        ++__n_swaps;
        // It is known that __m != __j
        // If __m just moved, follow it
        if (__m == __i)
          __m = __j;
        ++__i;
      }
    }
    // [__first, __i) < *__m and *__m <= [__i, __last)
    if (__i != __m && __comp(*__m, *__i)) {
      _Ops::iter_swap(__i, __m);
      ++__n_swaps;
    }
    // [__first, __i) < *__i and *__i <= [__i+1, __last)
    // If we were given a perfect partition, see if insertion sort is quick...
    if (__n_swaps == 0) {
      using _WrappedComp = typename _WrapAlgPolicy<_AlgPolicy, _Compare>::type;
      _WrappedComp __wrapped_comp(__comp);
      bool __fs = std::__insertion_sort_incomplete<_WrappedComp>(__first, __i, __wrapped_comp);
      if (std::__insertion_sort_incomplete<_WrappedComp>(__i + difference_type(1), __last, __wrapped_comp)) {
        if (__fs)
          return;
        __last = __i;
        continue;
      } else {
        if (__fs) {
          __first = ++__i;
          continue;
        }
      }
    }
    // sort smaller range with recursive call and larger with tail recursion elimination
    if (__i - __first < __last - __i) {
      std::__introsort<_AlgPolicy, _Compare>(__first, __i, __comp, __depth);
      __first = ++__i;
    } else {
      std::__introsort<_AlgPolicy, _Compare>(__i + difference_type(1), __last, __comp, __depth);
      __last = __i;
    }
  }
}

template <typename _Number>
inline _LIBCPP_HIDE_FROM_ABI _Number __log2i(_Number __n) {
  if (__n == 0)
    return 0;
  if (sizeof(__n) <= sizeof(unsigned))
    return sizeof(unsigned) * CHAR_BIT - 1 - __libcpp_clz(static_cast<unsigned>(__n));
  if (sizeof(__n) <= sizeof(unsigned long))
    return sizeof(unsigned long) * CHAR_BIT - 1 - __libcpp_clz(static_cast<unsigned long>(__n));
  if (sizeof(__n) <= sizeof(unsigned long long))
    return sizeof(unsigned long long) * CHAR_BIT - 1 - __libcpp_clz(static_cast<unsigned long long>(__n));

  _Number __log2 = 0;
  while (__n > 1) {
    __log2++;
    __n >>= 1;
  }
  return __log2;
}

template <class _WrappedComp, class _RandomAccessIterator>
void __sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _WrappedComp __wrapped_comp) {
  typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
  difference_type __depth_limit = 2 * __log2i(__last - __first);

  using _Unwrap = _UnwrapAlgPolicy<_WrappedComp>;
  using _AlgPolicy = typename _Unwrap::_AlgPolicy;
  using _Compare = typename _Unwrap::_Comp;
  _Compare __comp = _Unwrap::__get_comp(__wrapped_comp);
  std::__introsort<_AlgPolicy, _Compare>(__first, __last, __comp, __depth_limit);
}

template <class _Compare, class _Tp>
inline _LIBCPP_INLINE_VISIBILITY void __sort(_Tp** __first, _Tp** __last, __less<_Tp*>&) {
  __less<uintptr_t> __comp;
  std::__sort<__less<uintptr_t>&, uintptr_t*>((uintptr_t*)__first, (uintptr_t*)__last, __comp);
}

extern template _LIBCPP_FUNC_VIS void __sort<__less<char>&, char*>(char*, char*, __less<char>&);
#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
extern template _LIBCPP_FUNC_VIS void __sort<__less<wchar_t>&, wchar_t*>(wchar_t*, wchar_t*, __less<wchar_t>&);
#endif
extern template _LIBCPP_FUNC_VIS void __sort<__less<signed char>&, signed char*>(signed char*, signed char*, __less<signed char>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<unsigned char>&, unsigned char*>(unsigned char*, unsigned char*, __less<unsigned char>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<short>&, short*>(short*, short*, __less<short>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<unsigned short>&, unsigned short*>(unsigned short*, unsigned short*, __less<unsigned short>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<int>&, int*>(int*, int*, __less<int>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<unsigned>&, unsigned*>(unsigned*, unsigned*, __less<unsigned>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<long>&, long*>(long*, long*, __less<long>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<unsigned long>&, unsigned long*>(unsigned long*, unsigned long*, __less<unsigned long>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<long long>&, long long*>(long long*, long long*, __less<long long>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<unsigned long long>&, unsigned long long*>(unsigned long long*, unsigned long long*, __less<unsigned long long>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<float>&, float*>(float*, float*, __less<float>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<double>&, double*>(double*, double*, __less<double>&);
extern template _LIBCPP_FUNC_VIS void __sort<__less<long double>&, long double*>(long double*, long double*, __less<long double>&);

extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<char>&, char*>(char*, char*, __less<char>&);
#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<wchar_t>&, wchar_t*>(wchar_t*, wchar_t*, __less<wchar_t>&);
#endif
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<signed char>&, signed char*>(signed char*, signed char*, __less<signed char>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned char>&, unsigned char*>(unsigned char*, unsigned char*, __less<unsigned char>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<short>&, short*>(short*, short*, __less<short>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned short>&, unsigned short*>(unsigned short*, unsigned short*, __less<unsigned short>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<int>&, int*>(int*, int*, __less<int>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned>&, unsigned*>(unsigned*, unsigned*, __less<unsigned>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<long>&, long*>(long*, long*, __less<long>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned long>&, unsigned long*>(unsigned long*, unsigned long*, __less<unsigned long>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<long long>&, long long*>(long long*, long long*, __less<long long>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned long long>&, unsigned long long*>(unsigned long long*, unsigned long long*, __less<unsigned long long>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<float>&, float*>(float*, float*, __less<float>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<double>&, double*>(double*, double*, __less<double>&);
extern template _LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<long double>&, long double*>(long double*, long double*, __less<long double>&);

extern template _LIBCPP_FUNC_VIS unsigned __sort5<__less<long double>&, long double*>(long double*, long double*, long double*, long double*, long double*, __less<long double>&);

template <class _AlgPolicy, class _RandomAccessIterator, class _Comp>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void __sort_impl(_RandomAccessIterator __first, _RandomAccessIterator __last, _Comp& __comp) {
  std::__debug_randomize_range<_AlgPolicy>(__first, __last);

  using _Comp_ref = typename __comp_ref_type<_Comp>::type;
  if (__libcpp_is_constant_evaluated()) {
    std::__partial_sort<_AlgPolicy>(__first, __last, __last, __comp);

  } else {
    using _WrappedComp = typename _WrapAlgPolicy<_AlgPolicy, _Comp_ref>::type;
    _Comp_ref __comp_ref(__comp);
    _WrappedComp __wrapped_comp(__comp_ref);
    std::__sort<_WrappedComp>(std::__unwrap_iter(__first), std::__unwrap_iter(__last), __wrapped_comp);
  }
}

template <class _RandomAccessIterator, class _Comp>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Comp __comp) {
  std::__sort_impl<_ClassicAlgPolicy>(std::move(__first), std::move(__last), __comp);
}

template <class _RandomAccessIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
void sort(_RandomAccessIterator __first, _RandomAccessIterator __last) {
  std::sort(__first, __last, __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_SORT_H
