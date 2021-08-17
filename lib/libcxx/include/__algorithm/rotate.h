//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_ROTATE_H
#define _LIBCPP___ALGORITHM_ROTATE_H

#include <__algorithm/move.h>
#include <__algorithm/move_backward.h>
#include <__algorithm/swap_ranges.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__iterator/next.h>
#include <__iterator/prev.h>
#include <__utility/swap.h>
#include <iterator>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _ForwardIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 _ForwardIterator
__rotate_left(_ForwardIterator __first, _ForwardIterator __last)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type value_type;
    value_type __tmp = _VSTD::move(*__first);
    _ForwardIterator __lm1 = _VSTD::move(_VSTD::next(__first), __last, __first);
    *__lm1 = _VSTD::move(__tmp);
    return __lm1;
}

template <class _BidirectionalIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 _BidirectionalIterator
__rotate_right(_BidirectionalIterator __first, _BidirectionalIterator __last)
{
    typedef typename iterator_traits<_BidirectionalIterator>::value_type value_type;
    _BidirectionalIterator __lm1 = _VSTD::prev(__last);
    value_type __tmp = _VSTD::move(*__lm1);
    _BidirectionalIterator __fp1 = _VSTD::move_backward(__first, __lm1, __last);
    *__first = _VSTD::move(__tmp);
    return __fp1;
}

template <class _ForwardIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX14 _ForwardIterator
__rotate_forward(_ForwardIterator __first, _ForwardIterator __middle, _ForwardIterator __last)
{
    _ForwardIterator __i = __middle;
    while (true)
    {
        swap(*__first, *__i);
        ++__first;
        if (++__i == __last)
            break;
        if (__first == __middle)
            __middle = __i;
    }
    _ForwardIterator __r = __first;
    if (__first != __middle)
    {
        __i = __middle;
        while (true)
        {
            swap(*__first, *__i);
            ++__first;
            if (++__i == __last)
            {
                if (__first == __middle)
                    break;
                __i = __middle;
            }
            else if (__first == __middle)
                __middle = __i;
        }
    }
    return __r;
}

template<typename _Integral>
inline _LIBCPP_INLINE_VISIBILITY
_LIBCPP_CONSTEXPR_AFTER_CXX14 _Integral
__algo_gcd(_Integral __x, _Integral __y)
{
    do
    {
        _Integral __t = __x % __y;
        __x = __y;
        __y = __t;
    } while (__y);
    return __x;
}

template<typename _RandomAccessIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX14 _RandomAccessIterator
__rotate_gcd(_RandomAccessIterator __first, _RandomAccessIterator __middle, _RandomAccessIterator __last)
{
    typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;

    const difference_type __m1 = __middle - __first;
    const difference_type __m2 = __last - __middle;
    if (__m1 == __m2)
    {
        _VSTD::swap_ranges(__first, __middle, __middle);
        return __middle;
    }
    const difference_type __g = _VSTD::__algo_gcd(__m1, __m2);
    for (_RandomAccessIterator __p = __first + __g; __p != __first;)
    {
        value_type __t(_VSTD::move(*--__p));
        _RandomAccessIterator __p1 = __p;
        _RandomAccessIterator __p2 = __p1 + __m1;
        do
        {
            *__p1 = _VSTD::move(*__p2);
            __p1 = __p2;
            const difference_type __d = __last - __p2;
            if (__m1 < __d)
                __p2 += __m1;
            else
                __p2 = __first + (__m1 - __d);
        } while (__p2 != __p);
        *__p1 = _VSTD::move(__t);
    }
    return __first + __m2;
}

template <class _ForwardIterator>
inline _LIBCPP_INLINE_VISIBILITY
_LIBCPP_CONSTEXPR_AFTER_CXX11 _ForwardIterator
__rotate(_ForwardIterator __first, _ForwardIterator __middle, _ForwardIterator __last,
         _VSTD::forward_iterator_tag)
{
    typedef typename iterator_traits<_ForwardIterator>::value_type value_type;
    if (is_trivially_move_assignable<value_type>::value)
    {
        if (_VSTD::next(__first) == __middle)
            return _VSTD::__rotate_left(__first, __last);
    }
    return _VSTD::__rotate_forward(__first, __middle, __last);
}

template <class _BidirectionalIterator>
inline _LIBCPP_INLINE_VISIBILITY
_LIBCPP_CONSTEXPR_AFTER_CXX11 _BidirectionalIterator
__rotate(_BidirectionalIterator __first, _BidirectionalIterator __middle, _BidirectionalIterator __last,
         bidirectional_iterator_tag)
{
    typedef typename iterator_traits<_BidirectionalIterator>::value_type value_type;
    if (is_trivially_move_assignable<value_type>::value)
    {
        if (_VSTD::next(__first) == __middle)
            return _VSTD::__rotate_left(__first, __last);
        if (_VSTD::next(__middle) == __last)
            return _VSTD::__rotate_right(__first, __last);
    }
    return _VSTD::__rotate_forward(__first, __middle, __last);
}

template <class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY
_LIBCPP_CONSTEXPR_AFTER_CXX11 _RandomAccessIterator
__rotate(_RandomAccessIterator __first, _RandomAccessIterator __middle, _RandomAccessIterator __last,
         random_access_iterator_tag)
{
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    if (is_trivially_move_assignable<value_type>::value)
    {
        if (_VSTD::next(__first) == __middle)
            return _VSTD::__rotate_left(__first, __last);
        if (_VSTD::next(__middle) == __last)
            return _VSTD::__rotate_right(__first, __last);
        return _VSTD::__rotate_gcd(__first, __middle, __last);
    }
    return _VSTD::__rotate_forward(__first, __middle, __last);
}

template <class _ForwardIterator>
inline _LIBCPP_INLINE_VISIBILITY
_LIBCPP_CONSTEXPR_AFTER_CXX17 _ForwardIterator
rotate(_ForwardIterator __first, _ForwardIterator __middle, _ForwardIterator __last)
{
    if (__first == __middle)
        return __last;
    if (__middle == __last)
        return __first;
    return _VSTD::__rotate(__first, __middle, __last,
                           typename iterator_traits<_ForwardIterator>::iterator_category());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_ROTATE_H
