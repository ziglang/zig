// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_CONCEPTS_H
#define _LIBCPP___MEMORY_CONCEPTS_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/readable_traits.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges {

// [special.mem.concepts]

// This concept ensures that uninitialized algorithms can construct an object
// at the address pointed-to by the iterator, which requires an lvalue.
template <class _Ip>
concept __nothrow_input_iterator =
    input_iterator<_Ip> &&
    is_lvalue_reference_v<iter_reference_t<_Ip>> &&
    same_as<remove_cvref_t<iter_reference_t<_Ip>>, iter_value_t<_Ip>>;

template <class _Sp, class _Ip>
concept __nothrow_sentinel_for = sentinel_for<_Sp, _Ip>;

template <class _Rp>
concept __nothrow_input_range =
    range<_Rp> &&
    __nothrow_input_iterator<iterator_t<_Rp>> &&
    __nothrow_sentinel_for<sentinel_t<_Rp>, iterator_t<_Rp>>;

template <class _Ip>
concept __nothrow_forward_iterator =
    __nothrow_input_iterator<_Ip> &&
    forward_iterator<_Ip> &&
    __nothrow_sentinel_for<_Ip, _Ip>;

template <class _Rp>
concept __nothrow_forward_range =
    __nothrow_input_range<_Rp> &&
    __nothrow_forward_iterator<iterator_t<_Rp>>;

} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___MEMORY_CONCEPTS_H
