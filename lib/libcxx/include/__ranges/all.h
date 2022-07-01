// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_ALL_H
#define _LIBCPP___RANGES_ALL_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/owning_view.h>
#include <__ranges/range_adaptor.h>
#include <__ranges/ref_view.h>
#include <__utility/auto_cast.h>
#include <__utility/declval.h>
#include <__utility/forward.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges::views {

namespace __all {
  struct __fn : __range_adaptor_closure<__fn> {
    template<class _Tp>
      requires ranges::view<decay_t<_Tp>>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()(_Tp&& __t) const
      noexcept(noexcept(_LIBCPP_AUTO_CAST(_VSTD::forward<_Tp>(__t))))
    {
      return _LIBCPP_AUTO_CAST(_VSTD::forward<_Tp>(__t));
    }

    template<class _Tp>
      requires (!ranges::view<decay_t<_Tp>>) &&
               requires (_Tp&& __t) { ranges::ref_view{_VSTD::forward<_Tp>(__t)}; }
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()(_Tp&& __t) const
      noexcept(noexcept(ranges::ref_view{_VSTD::forward<_Tp>(__t)}))
    {
      return ranges::ref_view{_VSTD::forward<_Tp>(__t)};
    }

    template<class _Tp>
      requires (!ranges::view<decay_t<_Tp>> &&
                !requires (_Tp&& __t) { ranges::ref_view{_VSTD::forward<_Tp>(__t)}; } &&
                 requires (_Tp&& __t) { ranges::owning_view{_VSTD::forward<_Tp>(__t)}; })
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()(_Tp&& __t) const
      noexcept(noexcept(ranges::owning_view{_VSTD::forward<_Tp>(__t)}))
    {
      return ranges::owning_view{_VSTD::forward<_Tp>(__t)};
    }
  };
} // namespace __all

inline namespace __cpo {
  inline constexpr auto all = __all::__fn{};
} // namespace __cpo

template<ranges::viewable_range _Range>
using all_t = decltype(views::all(declval<_Range>()));

} // namespace ranges::views

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___RANGES_ALL_H
