//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_SHIFT_RIGHT_H
#define _LIBCPP___ALGORITHM_SHIFT_RIGHT_H

#include <__algorithm/move.h>
#include <__algorithm/move_backward.h>
#include <__algorithm/swap_ranges.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__utility/swap.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

template <class _ForwardIterator>
inline _LIBCPP_INLINE_VISIBILITY constexpr
_ForwardIterator
shift_right(_ForwardIterator __first, _ForwardIterator __last,
            typename iterator_traits<_ForwardIterator>::difference_type __n)
{
    if (__n == 0) {
        return __first;
    }

    if constexpr (__is_cpp17_random_access_iterator<_ForwardIterator>::value) {
        decltype(__n) __d = __last - __first;
        if (__n >= __d) {
            return __last;
        }
        _ForwardIterator __m = __first + (__d - __n);
        return _VSTD::move_backward(__first, __m, __last);
    } else if constexpr (__is_cpp17_bidirectional_iterator<_ForwardIterator>::value) {
        _ForwardIterator __m = __last;
        for (; __n > 0; --__n) {
            if (__m == __first) {
                return __last;
            }
            --__m;
        }
        return _VSTD::move_backward(__first, __m, __last);
    } else {
        _ForwardIterator __ret = __first;
        for (; __n > 0; --__n) {
            if (__ret == __last) {
                return __last;
            }
            ++__ret;
        }

        // We have an __n-element scratch space from __first to __ret.
        // Slide an __n-element window [__trail, __lead) from left to right.
        // We're essentially doing swap_ranges(__first, __ret, __trail, __lead)
        // over and over; but once __lead reaches __last we needn't bother
        // to save the values of elements [__trail, __last).

        auto __trail = __first;
        auto __lead = __ret;
        while (__trail != __ret) {
            if (__lead == __last) {
                _VSTD::move(__first, __trail, __ret);
                return __ret;
            }
            ++__trail;
            ++__lead;
        }

        _ForwardIterator __mid = __first;
        while (true) {
            if (__lead == __last) {
                __trail = _VSTD::move(__mid, __ret, __trail);
                _VSTD::move(__first, __mid, __trail);
                return __ret;
            }
            swap(*__mid, *__trail);
            ++__mid;
            ++__trail;
            ++__lead;
            if (__mid == __ret) {
                __mid = __first;
            }
        }
    }
}

#endif // _LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_SHIFT_RIGHT_H
