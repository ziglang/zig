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
#include <__utility/declval.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <tuple>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14

template <class _Op, class _Indices, class ..._Bound>
struct __perfect_forward_impl;

template <class _Op, size_t ..._Idx, class ..._Bound>
struct __perfect_forward_impl<_Op, index_sequence<_Idx...>, _Bound...> {
private:
    tuple<_Bound...> __bound_;

public:
    template <class ..._BoundArgs, class = enable_if_t<
        is_constructible_v<tuple<_Bound...>, _BoundArgs&&...>
    >>
    explicit constexpr __perfect_forward_impl(_BoundArgs&& ...__bound)
        : __bound_(_VSTD::forward<_BoundArgs>(__bound)...)
    { }

    __perfect_forward_impl(__perfect_forward_impl const&) = default;
    __perfect_forward_impl(__perfect_forward_impl&&) = default;

    __perfect_forward_impl& operator=(__perfect_forward_impl const&) = default;
    __perfect_forward_impl& operator=(__perfect_forward_impl&&) = default;

    template <class ..._Args, class = enable_if_t<is_invocable_v<_Op, _Bound&..., _Args...>>>
    _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Args&&... __args) &
        noexcept(noexcept(_Op()(_VSTD::get<_Idx>(__bound_)..., _VSTD::forward<_Args>(__args)...)))
        -> decltype(      _Op()(_VSTD::get<_Idx>(__bound_)..., _VSTD::forward<_Args>(__args)...))
        { return          _Op()(_VSTD::get<_Idx>(__bound_)..., _VSTD::forward<_Args>(__args)...); }

    template <class ..._Args, class = enable_if_t<!is_invocable_v<_Op, _Bound&..., _Args...>>>
    auto operator()(_Args&&...) & = delete;

    template <class ..._Args, class = enable_if_t<is_invocable_v<_Op, _Bound const&..., _Args...>>>
    _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Args&&... __args) const&
        noexcept(noexcept(_Op()(_VSTD::get<_Idx>(__bound_)..., _VSTD::forward<_Args>(__args)...)))
        -> decltype(      _Op()(_VSTD::get<_Idx>(__bound_)..., _VSTD::forward<_Args>(__args)...))
        { return          _Op()(_VSTD::get<_Idx>(__bound_)..., _VSTD::forward<_Args>(__args)...); }

    template <class ..._Args, class = enable_if_t<!is_invocable_v<_Op, _Bound const&..., _Args...>>>
    auto operator()(_Args&&...) const& = delete;

    template <class ..._Args, class = enable_if_t<is_invocable_v<_Op, _Bound..., _Args...>>>
    _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Args&&... __args) &&
        noexcept(noexcept(_Op()(_VSTD::get<_Idx>(_VSTD::move(__bound_))..., _VSTD::forward<_Args>(__args)...)))
        -> decltype(      _Op()(_VSTD::get<_Idx>(_VSTD::move(__bound_))..., _VSTD::forward<_Args>(__args)...))
        { return          _Op()(_VSTD::get<_Idx>(_VSTD::move(__bound_))..., _VSTD::forward<_Args>(__args)...); }

    template <class ..._Args, class = enable_if_t<!is_invocable_v<_Op, _Bound..., _Args...>>>
    auto operator()(_Args&&...) && = delete;

    template <class ..._Args, class = enable_if_t<is_invocable_v<_Op, _Bound const..., _Args...>>>
    _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Args&&... __args) const&&
        noexcept(noexcept(_Op()(_VSTD::get<_Idx>(_VSTD::move(__bound_))..., _VSTD::forward<_Args>(__args)...)))
        -> decltype(      _Op()(_VSTD::get<_Idx>(_VSTD::move(__bound_))..., _VSTD::forward<_Args>(__args)...))
        { return          _Op()(_VSTD::get<_Idx>(_VSTD::move(__bound_))..., _VSTD::forward<_Args>(__args)...); }

    template <class ..._Args, class = enable_if_t<!is_invocable_v<_Op, _Bound const..., _Args...>>>
    auto operator()(_Args&&...) const&& = delete;
};

// __perfect_forward implements a perfect-forwarding call wrapper as explained in [func.require].
template <class _Op, class ..._Args>
using __perfect_forward = __perfect_forward_impl<_Op, index_sequence_for<_Args...>, _Args...>;

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FUNCTIONAL_PERFECT_FORWARD_H
