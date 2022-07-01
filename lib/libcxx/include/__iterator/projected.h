// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___ITERATOR_PROJECTED_H
#define _LIBCPP___ITERATOR_PROJECTED_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

template<indirectly_readable _It, indirectly_regular_unary_invocable<_It> _Proj>
struct projected {
  using value_type = remove_cvref_t<indirect_result_t<_Proj&, _It>>;
  indirect_result_t<_Proj&, _It> operator*() const; // not defined
};

template<weakly_incrementable _It, class _Proj>
struct incrementable_traits<projected<_It, _Proj>> {
  using difference_type = iter_difference_t<_It>;
};

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_PROJECTED_H
