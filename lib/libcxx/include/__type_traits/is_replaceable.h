//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_REPLACEABLE_H
#define _LIBCPP___TYPE_TRAITS_IS_REPLACEABLE_H

#include <__config>
#include <__type_traits/enable_if.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_same.h>
#include <__type_traits/is_trivially_copyable.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// A type is replaceable if, with `x` and `y` being different objects, `x = std::move(y)` is equivalent to:
//
//  std::destroy_at(&x)
//  std::construct_at(&x, std::move(y))
//
// This allows turning a move-assignment into a sequence of destroy + move-construct, which
// is often more efficient. This is especially relevant when the move-construct is in fact
// part of a trivial relocation from somewhere else, in which case there is a huge win.
//
// Note that this requires language support in order to be really effective, but we
// currently emulate the base template with something very conservative.
template <class _Tp, class = void>
struct __is_replaceable : is_trivially_copyable<_Tp> {};

template <class _Tp>
struct __is_replaceable<_Tp, __enable_if_t<is_same<_Tp, typename _Tp::__replaceable>::value> > : true_type {};

template <class _Tp>
inline const bool __is_replaceable_v = __is_replaceable<_Tp>::value;

// Determines whether an allocator member of a container is replaceable.
//
// First, we require the allocator type to be considered replaceable. If not, then something fishy might be
// happening. Assuming the allocator type is replaceable, we conclude replaceability of the allocator as a
// member of the container if the allocator always compares equal (in which case propagation doesn't matter),
// or if the allocator always propagates on assignment, which is required in order for move construction and
// assignment to be equivalent.
template <class _AllocatorTraits>
struct __container_allocator_is_replaceable
    : integral_constant<bool,
                        __is_replaceable_v<typename _AllocatorTraits::allocator_type> &&
                            (_AllocatorTraits::is_always_equal::value ||
                             (_AllocatorTraits::propagate_on_container_move_assignment::value &&
                              _AllocatorTraits::propagate_on_container_copy_assignment::value))> {};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_REPLACEABLE_H
