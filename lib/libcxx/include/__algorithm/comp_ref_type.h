//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_COMP_REF_TYPE_H
#define _LIBCPP___ALGORITHM_COMP_REF_TYPE_H

#include <__config>
#include <__debug>
#include <__utility/declval.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare>
struct __debug_less
{
    _Compare &__comp_;
    _LIBCPP_CONSTEXPR_AFTER_CXX11
    __debug_less(_Compare& __c) : __comp_(__c) {}

    template <class _Tp, class _Up>
    _LIBCPP_CONSTEXPR_AFTER_CXX11
    bool operator()(const _Tp& __x,  const _Up& __y)
    {
        bool __r = __comp_(__x, __y);
        if (__r)
            __do_compare_assert(0, __y, __x);
        return __r;
    }

    template <class _Tp, class _Up>
    _LIBCPP_CONSTEXPR_AFTER_CXX11
    bool operator()(_Tp& __x,  _Up& __y)
    {
        bool __r = __comp_(__x, __y);
        if (__r)
            __do_compare_assert(0, __y, __x);
        return __r;
    }

    template <class _LHS, class _RHS>
    _LIBCPP_CONSTEXPR_AFTER_CXX11
    inline _LIBCPP_INLINE_VISIBILITY
    decltype((void)declval<_Compare&>()(
        declval<_LHS &>(), declval<_RHS &>()))
    __do_compare_assert(int, _LHS & __l, _RHS & __r) {
        _LIBCPP_DEBUG_ASSERT(!__comp_(__l, __r),
            "Comparator does not induce a strict weak ordering");
        (void)__l;
        (void)__r;
    }

    template <class _LHS, class _RHS>
    _LIBCPP_CONSTEXPR_AFTER_CXX11
    inline _LIBCPP_INLINE_VISIBILITY
    void __do_compare_assert(long, _LHS &, _RHS &) {}
};

template <class _Comp>
struct __comp_ref_type {
  // Pass the comparator by lvalue reference. Or in debug mode, using a
  // debugging wrapper that stores a reference.
#ifdef _LIBCPP_ENABLE_DEBUG_MODE
  typedef __debug_less<_Comp> type;
#else
  typedef _Comp& type;
#endif
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_COMP_REF_TYPE_H
