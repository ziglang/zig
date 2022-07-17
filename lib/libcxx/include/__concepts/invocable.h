//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CONCEPTS_INVOCABLE_H
#define _LIBCPP___CONCEPTS_INVOCABLE_H

#include <__config>
#include <__functional/invoke.h>
#include <__utility/forward.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

// [concept.invocable]

template<class _Fn, class... _Args>
concept invocable = requires(_Fn&& __fn, _Args&&... __args) {
  _VSTD::invoke(_VSTD::forward<_Fn>(__fn), _VSTD::forward<_Args>(__args)...); // not required to be equality preserving
};

// [concept.regular.invocable]

template<class _Fn, class... _Args>
concept regular_invocable = invocable<_Fn, _Args...>;

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___CONCEPTS_INVOCABLE_H
