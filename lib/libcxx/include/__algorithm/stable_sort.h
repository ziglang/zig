//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_STABLE_SORT_H
#define _LIBCPP___ALGORITHM_STABLE_SORT_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/inplace_merge.h>
#include <__algorithm/iterator_operations.h>
#include <__algorithm/radix_sort.h>
#include <__algorithm/sort.h>
#include <__config>
#include <__cstddef/ptrdiff_t.h>
#include <__debug_utils/strict_weak_ordering_check.h>
#include <__iterator/iterator_traits.h>
#include <__memory/construct_at.h>
#include <__memory/destruct_n.h>
#include <__memory/unique_ptr.h>
#include <__memory/unique_temporary_buffer.h>
#include <__type_traits/desugars_to.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_integral.h>
#include <__type_traits/is_same.h>
#include <__type_traits/is_trivially_assignable.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/move.h>
#include <__utility/pair.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _AlgPolicy, class _Compare, class _BidirectionalIterator>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX26 void __insertion_sort_move(
    _BidirectionalIterator __first1,
    _BidirectionalIterator __last1,
    typename iterator_traits<_BidirectionalIterator>::value_type* __first2,
    _Compare __comp) {
  using _Ops = _IterOps<_AlgPolicy>;

  typedef typename iterator_traits<_BidirectionalIterator>::value_type value_type;
  if (__first1 != __last1) {
    __destruct_n __d(0);
    unique_ptr<value_type, __destruct_n&> __h(__first2, __d);
    value_type* __last2 = __first2;
    std::__construct_at(__last2, _Ops::__iter_move(__first1));
    __d.template __incr<value_type>();
    for (++__last2; ++__first1 != __last1; ++__last2) {
      value_type* __j2 = __last2;
      value_type* __i2 = __j2;
      if (__comp(*__first1, *--__i2)) {
        std::__construct_at(__j2, std::move(*__i2));
        __d.template __incr<value_type>();
        for (--__j2; __i2 != __first2 && __comp(*__first1, *--__i2); --__j2)
          *__j2 = std::move(*__i2);
        *__j2 = _Ops::__iter_move(__first1);
      } else {
        std::__construct_at(__j2, _Ops::__iter_move(__first1));
        __d.template __incr<value_type>();
      }
    }
    __h.release();
  }
}

template <class _AlgPolicy, class _Compare, class _InputIterator1, class _InputIterator2>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX26 void __merge_move_construct(
    _InputIterator1 __first1,
    _InputIterator1 __last1,
    _InputIterator2 __first2,
    _InputIterator2 __last2,
    typename iterator_traits<_InputIterator1>::value_type* __result,
    _Compare __comp) {
  using _Ops = _IterOps<_AlgPolicy>;

  typedef typename iterator_traits<_InputIterator1>::value_type value_type;
  __destruct_n __d(0);
  unique_ptr<value_type, __destruct_n&> __h(__result, __d);
  for (; true; ++__result) {
    if (__first1 == __last1) {
      for (; __first2 != __last2; ++__first2, (void)++__result, __d.template __incr<value_type>())
        std::__construct_at(__result, _Ops::__iter_move(__first2));
      __h.release();
      return;
    }
    if (__first2 == __last2) {
      for (; __first1 != __last1; ++__first1, (void)++__result, __d.template __incr<value_type>())
        std::__construct_at(__result, _Ops::__iter_move(__first1));
      __h.release();
      return;
    }
    if (__comp(*__first2, *__first1)) {
      std::__construct_at(__result, _Ops::__iter_move(__first2));
      __d.template __incr<value_type>();
      ++__first2;
    } else {
      std::__construct_at(__result, _Ops::__iter_move(__first1));
      __d.template __incr<value_type>();
      ++__first1;
    }
  }
}

template <class _AlgPolicy, class _Compare, class _InputIterator1, class _InputIterator2, class _OutputIterator>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX26 void __merge_move_assign(
    _InputIterator1 __first1,
    _InputIterator1 __last1,
    _InputIterator2 __first2,
    _InputIterator2 __last2,
    _OutputIterator __result,
    _Compare __comp) {
  using _Ops = _IterOps<_AlgPolicy>;

  for (; __first1 != __last1; ++__result) {
    if (__first2 == __last2) {
      for (; __first1 != __last1; ++__first1, (void)++__result)
        *__result = _Ops::__iter_move(__first1);
      return;
    }
    if (__comp(*__first2, *__first1)) {
      *__result = _Ops::__iter_move(__first2);
      ++__first2;
    } else {
      *__result = _Ops::__iter_move(__first1);
      ++__first1;
    }
  }
  for (; __first2 != __last2; ++__first2, (void)++__result)
    *__result = _Ops::__iter_move(__first2);
}

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
_LIBCPP_CONSTEXPR_SINCE_CXX26 void __stable_sort(
    _RandomAccessIterator __first,
    _RandomAccessIterator __last,
    _Compare __comp,
    typename iterator_traits<_RandomAccessIterator>::difference_type __len,
    typename iterator_traits<_RandomAccessIterator>::value_type* __buff,
    ptrdiff_t __buff_size);

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
_LIBCPP_CONSTEXPR_SINCE_CXX26 void __stable_sort_move(
    _RandomAccessIterator __first1,
    _RandomAccessIterator __last1,
    _Compare __comp,
    typename iterator_traits<_RandomAccessIterator>::difference_type __len,
    typename iterator_traits<_RandomAccessIterator>::value_type* __first2) {
  using _Ops = _IterOps<_AlgPolicy>;

  typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
  switch (__len) {
  case 0:
    return;
  case 1:
    std::__construct_at(__first2, _Ops::__iter_move(__first1));
    return;
  case 2:
    __destruct_n __d(0);
    unique_ptr<value_type, __destruct_n&> __h2(__first2, __d);
    if (__comp(*--__last1, *__first1)) {
      std::__construct_at(__first2, _Ops::__iter_move(__last1));
      __d.template __incr<value_type>();
      ++__first2;
      std::__construct_at(__first2, _Ops::__iter_move(__first1));
    } else {
      std::__construct_at(__first2, _Ops::__iter_move(__first1));
      __d.template __incr<value_type>();
      ++__first2;
      std::__construct_at(__first2, _Ops::__iter_move(__last1));
    }
    __h2.release();
    return;
  }
  if (__len <= 8) {
    std::__insertion_sort_move<_AlgPolicy, _Compare>(__first1, __last1, __first2, __comp);
    return;
  }
  typename iterator_traits<_RandomAccessIterator>::difference_type __l2 = __len / 2;
  _RandomAccessIterator __m                                             = __first1 + __l2;
  std::__stable_sort<_AlgPolicy, _Compare>(__first1, __m, __comp, __l2, __first2, __l2);
  std::__stable_sort<_AlgPolicy, _Compare>(__m, __last1, __comp, __len - __l2, __first2 + __l2, __len - __l2);
  std::__merge_move_construct<_AlgPolicy, _Compare>(__first1, __m, __m, __last1, __first2, __comp);
}

template <class _Tp>
struct __stable_sort_switch {
  static const unsigned value = 128 * is_trivially_copy_assignable<_Tp>::value;
};

#if _LIBCPP_STD_VER >= 17
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI constexpr unsigned __radix_sort_min_bound() {
  static_assert(is_integral<_Tp>::value);
  if constexpr (sizeof(_Tp) == 1) {
    return 1 << 8;
  }

  return 1 << 10;
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI constexpr unsigned __radix_sort_max_bound() {
  static_assert(is_integral<_Tp>::value);
  if constexpr (sizeof(_Tp) >= 8) {
    return 1 << 15;
  }

  return 1 << 16;
}
#endif // _LIBCPP_STD_VER >= 17

template <class _AlgPolicy, class _Compare, class _RandomAccessIterator>
_LIBCPP_CONSTEXPR_SINCE_CXX26 void __stable_sort(
    _RandomAccessIterator __first,
    _RandomAccessIterator __last,
    _Compare __comp,
    typename iterator_traits<_RandomAccessIterator>::difference_type __len,
    typename iterator_traits<_RandomAccessIterator>::value_type* __buff,
    ptrdiff_t __buff_size) {
  typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
  typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
  switch (__len) {
  case 0:
  case 1:
    return;
  case 2:
    if (__comp(*--__last, *__first))
      _IterOps<_AlgPolicy>::iter_swap(__first, __last);
    return;
  }
  if (__len <= static_cast<difference_type>(__stable_sort_switch<value_type>::value)) {
    std::__insertion_sort<_AlgPolicy, _Compare>(__first, __last, __comp);
    return;
  }

#if _LIBCPP_STD_VER >= 17
  constexpr auto __default_comp =
      __desugars_to_v<__totally_ordered_less_tag, __remove_cvref_t<_Compare>, value_type, value_type >;
  constexpr auto __integral_value =
      is_integral_v<value_type > && is_same_v< value_type&, __iter_reference<_RandomAccessIterator>>;
  constexpr auto __allowed_radix_sort = __default_comp && __integral_value;
  if constexpr (__allowed_radix_sort) {
    if (__len <= __buff_size && __len >= static_cast<difference_type>(__radix_sort_min_bound<value_type>()) &&
        __len <= static_cast<difference_type>(__radix_sort_max_bound<value_type>())) {
      std::__radix_sort(__first, __last, __buff);
      return;
    }
  }
#endif // _LIBCPP_STD_VER >= 17

  typename iterator_traits<_RandomAccessIterator>::difference_type __l2 = __len / 2;
  _RandomAccessIterator __m                                             = __first + __l2;
  if (__len <= __buff_size) {
    __destruct_n __d(0);
    unique_ptr<value_type, __destruct_n&> __h2(__buff, __d);
    std::__stable_sort_move<_AlgPolicy, _Compare>(__first, __m, __comp, __l2, __buff);
    __d.__set(__l2, (value_type*)nullptr);
    std::__stable_sort_move<_AlgPolicy, _Compare>(__m, __last, __comp, __len - __l2, __buff + __l2);
    __d.__set(__len, (value_type*)nullptr);
    std::__merge_move_assign<_AlgPolicy, _Compare>(
        __buff, __buff + __l2, __buff + __l2, __buff + __len, __first, __comp);
    //         std::__merge<_Compare>(move_iterator<value_type*>(__buff),
    //                                  move_iterator<value_type*>(__buff + __l2),
    //                                  move_iterator<_RandomAccessIterator>(__buff + __l2),
    //                                  move_iterator<_RandomAccessIterator>(__buff + __len),
    //                                  __first, __comp);
    return;
  }
  std::__stable_sort<_AlgPolicy, _Compare>(__first, __m, __comp, __l2, __buff, __buff_size);
  std::__stable_sort<_AlgPolicy, _Compare>(__m, __last, __comp, __len - __l2, __buff, __buff_size);
  std::__inplace_merge<_AlgPolicy>(__first, __m, __last, __comp, __l2, __len - __l2, __buff, __buff_size);
}

template <class _AlgPolicy, class _RandomAccessIterator, class _Compare>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX26 void
__stable_sort_impl(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare& __comp) {
  using value_type      = typename iterator_traits<_RandomAccessIterator>::value_type;
  using difference_type = typename iterator_traits<_RandomAccessIterator>::difference_type;

  difference_type __len = __last - __first;
  __unique_temporary_buffer<value_type> __unique_buf;
  pair<value_type*, ptrdiff_t> __buf(0, 0);
  if (__len > static_cast<difference_type>(__stable_sort_switch<value_type>::value)) {
    __unique_buf = std::__allocate_unique_temporary_buffer<value_type>(__len);
    __buf.first  = __unique_buf.get();
    __buf.second = __unique_buf.get_deleter().__count_;
  }

  std::__stable_sort<_AlgPolicy, __comp_ref_type<_Compare> >(__first, __last, __comp, __len, __buf.first, __buf.second);
  std::__check_strict_weak_ordering_sorted(__first, __last, __comp);
}

template <class _RandomAccessIterator, class _Compare>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX26 void
stable_sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp) {
  std::__stable_sort_impl<_ClassicAlgPolicy>(std::move(__first), std::move(__last), __comp);
}

template <class _RandomAccessIterator>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX26 void
stable_sort(_RandomAccessIterator __first, _RandomAccessIterator __last) {
  std::stable_sort(__first, __last, __less<>());
}

_LIBCPP_END_NAMESPACE_STD
_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_STABLE_SORT_H
