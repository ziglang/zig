// -*- C++ -*-
//===--------------------- __ranges/concepts.h ----------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_CONCEPTS_H
#define _LIBCPP___RANGES_CONCEPTS_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iter_move.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/readable_traits.h>
#include <__ranges/access.h>
#include <__ranges/enable_borrowed_range.h>
#include <__ranges/data.h>
#include <__ranges/enable_view.h>
#include <__ranges/size.h>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

// clang-format off

#if !defined(_LIBCPP_HAS_NO_RANGES)

namespace ranges {
  // [range.range]
  template <class _Tp>
  concept range = requires(_Tp& __t) {
    ranges::begin(__t); // sometimes equality-preserving
    ranges::end(__t);
  };

  template<class _Range>
  concept borrowed_range = range<_Range> &&
    (is_lvalue_reference_v<_Range> || enable_borrowed_range<remove_cvref_t<_Range>>);

  // `iterator_t` defined in <__ranges/access.h>

  template <range _Rp>
  using sentinel_t = decltype(ranges::end(declval<_Rp&>()));

  template <range _Rp>
  using range_difference_t = iter_difference_t<iterator_t<_Rp>>;

  template <range _Rp>
  using range_value_t = iter_value_t<iterator_t<_Rp>>;

  template <range _Rp>
  using range_reference_t = iter_reference_t<iterator_t<_Rp>>;

  template <range _Rp>
  using range_rvalue_reference_t = iter_rvalue_reference_t<iterator_t<_Rp>>;

  // [range.sized]
  template <class _Tp>
  concept sized_range = range<_Tp> && requires(_Tp& __t) { ranges::size(__t); };

  template<sized_range _Rp>
  using range_size_t = decltype(ranges::size(declval<_Rp&>()));

  // `disable_sized_range` defined in `<__ranges/size.h>`

  // [range.view], views

  // `enable_view` defined in <__ranges/enable_view.h>
  // `view_base` defined in <__ranges/enable_view.h>

  template <class _Tp>
  concept view =
    range<_Tp> &&
    movable<_Tp> &&
    enable_view<_Tp>;

  template<class _Range>
  concept __simple_view =
    view<_Range> && range<const _Range> &&
    same_as<iterator_t<_Range>, iterator_t<const _Range>> &&
    same_as<sentinel_t<_Range>, iterator_t<const _Range>>;

  // [range.refinements], other range refinements
  template <class _Rp, class _Tp>
  concept output_range = range<_Rp> && output_iterator<iterator_t<_Rp>, _Tp>;

  template <class _Tp>
  concept input_range = range<_Tp> && input_iterator<iterator_t<_Tp>>;

  template <class _Tp>
  concept forward_range = input_range<_Tp> && forward_iterator<iterator_t<_Tp>>;

  template <class _Tp>
  concept bidirectional_range = forward_range<_Tp> && bidirectional_iterator<iterator_t<_Tp>>;

  template <class _Tp>
  concept random_access_range =
      bidirectional_range<_Tp> && random_access_iterator<iterator_t<_Tp>>;

  template<class _Tp>
  concept contiguous_range =
    random_access_range<_Tp> &&
    contiguous_iterator<iterator_t<_Tp>> &&
    requires(_Tp& __t) {
      { ranges::data(__t) } -> same_as<add_pointer_t<range_reference_t<_Tp>>>;
    };

  template <class _Tp>
  concept common_range = range<_Tp> && same_as<iterator_t<_Tp>, sentinel_t<_Tp>>;

  template<class _Tp>
  concept viewable_range =
    range<_Tp> && (
      (view<remove_cvref_t<_Tp>> && constructible_from<remove_cvref_t<_Tp>, _Tp>) ||
      (!view<remove_cvref_t<_Tp>> && borrowed_range<_Tp>)
    );
} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

// clang-format on

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_CONCEPTS_H
