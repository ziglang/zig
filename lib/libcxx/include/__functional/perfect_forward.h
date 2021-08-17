// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FUNCTIONAL_PERFECT_FORWARD_H
#define _LIBCPP___FUNCTIONAL_PERFECT_FORWARD_H

#include <__config>
#include <tuple>
#include <type_traits>
#include <utility>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14

template<class _Op, class _Tuple,
         class _Idxs = typename __make_tuple_indices<tuple_size<_Tuple>::value>::type>
struct __perfect_forward_impl;

template<class _Op, class... _Bound, size_t... _Idxs>
struct __perfect_forward_impl<_Op, __tuple_types<_Bound...>, __tuple_indices<_Idxs...>>
{
    tuple<_Bound...> __bound_;

    template<class... _Args>
    _LIBCPP_INLINE_VISIBILITY constexpr auto operator()(_Args&&... __args) &
    noexcept(noexcept(_Op::__call(_VSTD::get<_Idxs>(__bound_)..., _VSTD::forward<_Args>(__args)...)))
    -> decltype(      _Op::__call(_VSTD::get<_Idxs>(__bound_)..., _VSTD::forward<_Args>(__args)...))
    {return           _Op::__call(_VSTD::get<_Idxs>(__bound_)..., _VSTD::forward<_Args>(__args)...);}

    template<class... _Args>
    _LIBCPP_INLINE_VISIBILITY constexpr auto operator()(_Args&&... __args) const&
    noexcept(noexcept(_Op::__call(_VSTD::get<_Idxs>(__bound_)..., _VSTD::forward<_Args>(__args)...)))
    -> decltype(      _Op::__call(_VSTD::get<_Idxs>(__bound_)..., _VSTD::forward<_Args>(__args)...))
    {return           _Op::__call(_VSTD::get<_Idxs>(__bound_)..., _VSTD::forward<_Args>(__args)...);}

    template<class... _Args>
    _LIBCPP_INLINE_VISIBILITY constexpr auto operator()(_Args&&... __args) &&
    noexcept(noexcept(_Op::__call(_VSTD::get<_Idxs>(_VSTD::move(__bound_))...,
                                  _VSTD::forward<_Args>(__args)...)))
    -> decltype(      _Op::__call(_VSTD::get<_Idxs>(_VSTD::move(__bound_))...,
                                  _VSTD::forward<_Args>(__args)...))
    {return           _Op::__call(_VSTD::get<_Idxs>(_VSTD::move(__bound_))...,
                                  _VSTD::forward<_Args>(__args)...);}

    template<class... _Args>
    _LIBCPP_INLINE_VISIBILITY constexpr auto operator()(_Args&&... __args) const&&
    noexcept(noexcept(_Op::__call(_VSTD::get<_Idxs>(_VSTD::move(__bound_))...,
                                  _VSTD::forward<_Args>(__args)...)))
    -> decltype(      _Op::__call(_VSTD::get<_Idxs>(_VSTD::move(__bound_))...,
                                  _VSTD::forward<_Args>(__args)...))
    {return           _Op::__call(_VSTD::get<_Idxs>(_VSTD::move(__bound_))...,
                                  _VSTD::forward<_Args>(__args)...);}

    template<class _Fn = typename tuple_element<0, tuple<_Bound...>>::type,
             class = _EnableIf<is_copy_constructible_v<_Fn>>>
    constexpr __perfect_forward_impl(__perfect_forward_impl const& __other)
        : __bound_(__other.__bound_) {}

    template<class _Fn = typename tuple_element<0, tuple<_Bound...>>::type,
             class = _EnableIf<is_move_constructible_v<_Fn>>>
    constexpr __perfect_forward_impl(__perfect_forward_impl && __other)
        : __bound_(_VSTD::move(__other.__bound_)) {}

    template<class... _BoundArgs>
    explicit constexpr __perfect_forward_impl(_BoundArgs&&... __bound) :
        __bound_(_VSTD::forward<_BoundArgs>(__bound)...) { }
};

template<class _Op, class... _Args>
using __perfect_forward =
    __perfect_forward_impl<_Op, __tuple_types<decay_t<_Args>...>>;

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_PERFECT_FORWARD_H
