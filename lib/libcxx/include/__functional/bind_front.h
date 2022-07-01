// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_BIND_FRONT_H
#define _LIBCPP___FUNCTIONAL_BIND_FRONT_H

#include <__config>
#include <__functional/invoke.h>
#include <__functional/perfect_forward.h>
#include <type_traits>
#include <utility>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

struct __bind_front_op {
    template <class ..._Args>
    _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()(_Args&& ...__args) const
        noexcept(noexcept(_VSTD::invoke(_VSTD::forward<_Args>(__args)...)))
        -> decltype(      _VSTD::invoke(_VSTD::forward<_Args>(__args)...))
        { return          _VSTD::invoke(_VSTD::forward<_Args>(__args)...); }
};

template <class _Fn, class ..._BoundArgs>
struct __bind_front_t : __perfect_forward<__bind_front_op, _Fn, _BoundArgs...> {
    using __perfect_forward<__bind_front_op, _Fn, _BoundArgs...>::__perfect_forward;
};

template <class _Fn, class... _Args, class = enable_if_t<
    _And<
        is_constructible<decay_t<_Fn>, _Fn>,
        is_move_constructible<decay_t<_Fn>>,
        is_constructible<decay_t<_Args>, _Args>...,
        is_move_constructible<decay_t<_Args>>...
    >::value
>>
_LIBCPP_HIDE_FROM_ABI
constexpr auto bind_front(_Fn&& __f, _Args&&... __args) {
    return __bind_front_t<decay_t<_Fn>, decay_t<_Args>...>(_VSTD::forward<_Fn>(__f), _VSTD::forward<_Args>(__args)...);
}

#endif // _LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_BIND_FRONT_H
