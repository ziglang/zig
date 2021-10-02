// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_INVOKE_H
#define _LIBCPP___FUNCTIONAL_INVOKE_H

#include <__config>
#include <__functional/weak_result_type.h>
#include <__utility/forward.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Ret, bool = is_void<_Ret>::value>
struct __invoke_void_return_wrapper
{
#ifndef _LIBCPP_CXX03_LANG
    template <class ..._Args>
    static _Ret __call(_Args&&... __args) {
        return _VSTD::__invoke(_VSTD::forward<_Args>(__args)...);
    }
#else
    template <class _Fn>
    static _Ret __call(_Fn __f) {
        return _VSTD::__invoke(__f);
    }

    template <class _Fn, class _A0>
    static _Ret __call(_Fn __f, _A0& __a0) {
        return _VSTD::__invoke(__f, __a0);
    }

    template <class _Fn, class _A0, class _A1>
    static _Ret __call(_Fn __f, _A0& __a0, _A1& __a1) {
        return _VSTD::__invoke(__f, __a0, __a1);
    }

    template <class _Fn, class _A0, class _A1, class _A2>
    static _Ret __call(_Fn __f, _A0& __a0, _A1& __a1, _A2& __a2){
        return _VSTD::__invoke(__f, __a0, __a1, __a2);
    }
#endif
};

template <class _Ret>
struct __invoke_void_return_wrapper<_Ret, true>
{
#ifndef _LIBCPP_CXX03_LANG
    template <class ..._Args>
    static void __call(_Args&&... __args) {
        _VSTD::__invoke(_VSTD::forward<_Args>(__args)...);
    }
#else
    template <class _Fn>
    static void __call(_Fn __f) {
        _VSTD::__invoke(__f);
    }

    template <class _Fn, class _A0>
    static void __call(_Fn __f, _A0& __a0) {
        _VSTD::__invoke(__f, __a0);
    }

    template <class _Fn, class _A0, class _A1>
    static void __call(_Fn __f, _A0& __a0, _A1& __a1) {
        _VSTD::__invoke(__f, __a0, __a1);
    }

    template <class _Fn, class _A0, class _A1, class _A2>
    static void __call(_Fn __f, _A0& __a0, _A1& __a1, _A2& __a2) {
        _VSTD::__invoke(__f, __a0, __a1, __a2);
    }
#endif
};

#if _LIBCPP_STD_VER > 14

template <class _Fn, class ..._Args>
_LIBCPP_CONSTEXPR_AFTER_CXX17 invoke_result_t<_Fn, _Args...>
invoke(_Fn&& __f, _Args&&... __args)
    noexcept(is_nothrow_invocable_v<_Fn, _Args...>)
{
    return _VSTD::__invoke(_VSTD::forward<_Fn>(__f), _VSTD::forward<_Args>(__args)...);
}

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_INVOKE_H
