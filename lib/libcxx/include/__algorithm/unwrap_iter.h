//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_UNWRAP_ITER_H
#define _LIBCPP___ALGORITHM_UNWRAP_ITER_H

#include <__config>
#include <__memory/pointer_traits.h>
#include <iterator>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// The job of __unwrap_iter is to lower contiguous iterators (such as
// vector<T>::iterator) into pointers, to reduce the number of template
// instantiations and to enable pointer-based optimizations e.g. in std::copy.
// For iterators that are not contiguous, it must be a no-op.
// In debug mode, we don't do this.
//
// __unwrap_iter is non-constexpr for user-defined iterators whose
// `to_address` and/or `operator->` is non-constexpr. This is okay; but we
// try to avoid doing __unwrap_iter in constant-evaluated contexts anyway.
//
// Some algorithms (e.g. std::copy, but not std::sort) need to convert an
// "unwrapped" result back into a contiguous iterator. Since contiguous iterators
// are random-access, we can do this portably using iterator arithmetic; this
// is the job of __rewrap_iter.

template <class _Iter, bool = __is_cpp17_contiguous_iterator<_Iter>::value>
struct __unwrap_iter_impl {
    static _LIBCPP_CONSTEXPR _Iter
    __apply(_Iter __i) _NOEXCEPT {
        return __i;
    }
};

#if _LIBCPP_DEBUG_LEVEL < 2

template <class _Iter>
struct __unwrap_iter_impl<_Iter, true> {
    static _LIBCPP_CONSTEXPR decltype(_VSTD::__to_address(declval<_Iter>()))
    __apply(_Iter __i) _NOEXCEPT {
        return _VSTD::__to_address(__i);
    }
};

#endif // _LIBCPP_DEBUG_LEVEL < 2

template<class _Iter, class _Impl = __unwrap_iter_impl<_Iter> >
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR
decltype(_Impl::__apply(declval<_Iter>()))
__unwrap_iter(_Iter __i) _NOEXCEPT
{
    return _Impl::__apply(__i);
}

template<class _OrigIter>
_LIBCPP_HIDE_FROM_ABI
_OrigIter __rewrap_iter(_OrigIter, _OrigIter __result)
{
    return __result;
}

template<class _OrigIter, class _UnwrappedIter>
_LIBCPP_HIDE_FROM_ABI
_OrigIter __rewrap_iter(_OrigIter __first, _UnwrappedIter __result)
{
    // Precondition: __result is reachable from __first
    // Precondition: _OrigIter is a contiguous iterator
    return __first + (__result - _VSTD::__unwrap_iter(__first));
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_UNWRAP_ITER_H
