// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_BIND_BACK_H
#define _LIBCPP___FUNCTIONAL_BIND_BACK_H

#include <__config>
#include <__functional/invoke.h>
#include <__functional/perfect_forward.h>
#include <__type_traits/decay.h>
#include <__utility/forward.h>
#include <__utility/integer_sequence.h>
#include <tuple>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 20

template <size_t _NBound, class = make_index_sequence<_NBound>>
struct __bind_back_op;

template <size_t _NBound, size_t ..._Ip>
struct __bind_back_op<_NBound, index_sequence<_Ip...>> {
    template <class _Fn, class _BoundArgs, class... _Args>
    _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Fn&& __f, _BoundArgs&& __bound_args, _Args&&... __args) const
        noexcept(noexcept(_VSTD::invoke(_VSTD::forward<_Fn>(__f), _VSTD::forward<_Args>(__args)..., _VSTD::get<_Ip>(_VSTD::forward<_BoundArgs>(__bound_args))...)))
        -> decltype(      _VSTD::invoke(_VSTD::forward<_Fn>(__f), _VSTD::forward<_Args>(__args)..., _VSTD::get<_Ip>(_VSTD::forward<_BoundArgs>(__bound_args))...))
        { return          _VSTD::invoke(_VSTD::forward<_Fn>(__f), _VSTD::forward<_Args>(__args)..., _VSTD::get<_Ip>(_VSTD::forward<_BoundArgs>(__bound_args))...); }
};

template <class _Fn, class _BoundArgs>
struct __bind_back_t : __perfect_forward<__bind_back_op<tuple_size_v<_BoundArgs>>, _Fn, _BoundArgs> {
    using __perfect_forward<__bind_back_op<tuple_size_v<_BoundArgs>>, _Fn, _BoundArgs>::__perfect_forward;
};

template <class _Fn, class ..._Args, class = enable_if_t<
    _And<
        is_constructible<decay_t<_Fn>, _Fn>,
        is_move_constructible<decay_t<_Fn>>,
        is_constructible<decay_t<_Args>, _Args>...,
        is_move_constructible<decay_t<_Args>>...
    >::value
>>
_LIBCPP_HIDE_FROM_ABI
constexpr auto __bind_back(_Fn&& __f, _Args&&... __args)
    noexcept(noexcept(__bind_back_t<decay_t<_Fn>, tuple<decay_t<_Args>...>>(_VSTD::forward<_Fn>(__f), _VSTD::forward_as_tuple(_VSTD::forward<_Args>(__args)...))))
    -> decltype(      __bind_back_t<decay_t<_Fn>, tuple<decay_t<_Args>...>>(_VSTD::forward<_Fn>(__f), _VSTD::forward_as_tuple(_VSTD::forward<_Args>(__args)...)))
    { return          __bind_back_t<decay_t<_Fn>, tuple<decay_t<_Args>...>>(_VSTD::forward<_Fn>(__f), _VSTD::forward_as_tuple(_VSTD::forward<_Args>(__args)...)); }

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_BIND_BACK_H
