// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_MEM_FN_H
#define _LIBCPP___FUNCTIONAL_MEM_FN_H

#include <__config>
#include <__functional/binary_function.h>
#include <__functional/invoke.h>
#include <__functional/weak_result_type.h>
#include <utility>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
class __mem_fn
#if _LIBCPP_STD_VER <= 17 || !defined(_LIBCPP_ABI_NO_BINDER_BASES)
    : public __weak_result_type<_Tp>
#endif
{
public:
    // types
    typedef _Tp type;
private:
    type __f_;

public:
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    __mem_fn(type __f) _NOEXCEPT : __f_(__f) {}

#ifndef _LIBCPP_CXX03_LANG
    // invoke
    template <class... _ArgTypes>
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
    typename __invoke_return<type, _ArgTypes...>::type
    operator() (_ArgTypes&&... __args) const {
        return _VSTD::__invoke(__f_, _VSTD::forward<_ArgTypes>(__args)...);
    }
#else

    template <class _A0>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return0<type, _A0>::type
    operator() (_A0& __a0) const {
        return _VSTD::__invoke(__f_, __a0);
    }

    template <class _A0>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return0<type, _A0 const>::type
    operator() (_A0 const& __a0) const {
        return _VSTD::__invoke(__f_, __a0);
    }

    template <class _A0, class _A1>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return1<type, _A0, _A1>::type
    operator() (_A0& __a0, _A1& __a1) const {
        return _VSTD::__invoke(__f_, __a0, __a1);
    }

    template <class _A0, class _A1>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return1<type, _A0 const, _A1>::type
    operator() (_A0 const& __a0, _A1& __a1) const {
        return _VSTD::__invoke(__f_, __a0, __a1);
    }

    template <class _A0, class _A1>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return1<type, _A0, _A1 const>::type
    operator() (_A0& __a0, _A1 const& __a1) const {
        return _VSTD::__invoke(__f_, __a0, __a1);
    }

    template <class _A0, class _A1>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return1<type, _A0 const, _A1 const>::type
    operator() (_A0 const& __a0, _A1 const& __a1) const {
        return _VSTD::__invoke(__f_, __a0, __a1);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0, _A1, _A2>::type
    operator() (_A0& __a0, _A1& __a1, _A2& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0 const, _A1, _A2>::type
    operator() (_A0 const& __a0, _A1& __a1, _A2& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0, _A1 const, _A2>::type
    operator() (_A0& __a0, _A1 const& __a1, _A2& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0, _A1, _A2 const>::type
    operator() (_A0& __a0, _A1& __a1, _A2 const& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0 const, _A1 const, _A2>::type
    operator() (_A0 const& __a0, _A1 const& __a1, _A2& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0 const, _A1, _A2 const>::type
    operator() (_A0 const& __a0, _A1& __a1, _A2 const& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0, _A1 const, _A2 const>::type
    operator() (_A0& __a0, _A1 const& __a1, _A2 const& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }

    template <class _A0, class _A1, class _A2>
    _LIBCPP_INLINE_VISIBILITY
    typename __invoke_return2<type, _A0 const, _A1 const, _A2 const>::type
    operator() (_A0 const& __a0, _A1 const& __a1, _A2 const& __a2) const {
        return _VSTD::__invoke(__f_, __a0, __a1, __a2);
    }
#endif
};

template<class _Rp, class _Tp>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
__mem_fn<_Rp _Tp::*>
mem_fn(_Rp _Tp::* __pm) _NOEXCEPT
{
    return __mem_fn<_Rp _Tp::*>(__pm);
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_MEM_FN_H
