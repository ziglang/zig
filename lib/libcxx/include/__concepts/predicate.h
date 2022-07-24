//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CONCEPTS_PREDICATE_H
#define _LIBCPP___CONCEPTS_PREDICATE_H

#include <__concepts/boolean_testable.h>
#include <__concepts/invocable.h>
#include <__config>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

// [concept.predicate]

template<class _Fn, class... _Args>
concept predicate =
  regular_invocable<_Fn, _Args...> && __boolean_testable<invoke_result_t<_Fn, _Args...>>;

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___CONCEPTS_PREDICATE_H
