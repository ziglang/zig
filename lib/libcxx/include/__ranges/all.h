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
#include <__ranges/ref_view.h>
#include <__ranges/subrange.h>
#include <__utility/__decay_copy.h>
#include <__utility/declval.h>
#include <__utility/forward.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_RANGES)

namespace views {

namespace __all {
  struct __fn {
    template<class _Tp>
      requires ranges::view<decay_t<_Tp>>
    _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()(_Tp&& __t) const
      noexcept(noexcept(_VSTD::__decay_copy(_VSTD::forward<_Tp>(__t))))
    {
      return _VSTD::forward<_Tp>(__t);
    }

    template<class _Tp>
      requires (!ranges::view<decay_t<_Tp>>) &&
               requires (_Tp&& __t) { ranges::ref_view{_VSTD::forward<_Tp>(__t)}; }
    _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()(_Tp&& __t) const
      noexcept(noexcept(ranges::ref_view{_VSTD::forward<_Tp>(__t)}))
    {
      return ranges::ref_view{_VSTD::forward<_Tp>(__t)};
    }

    template<class _Tp>
      requires (!ranges::view<decay_t<_Tp>> &&
                !requires (_Tp&& __t) { ranges::ref_view{_VSTD::forward<_Tp>(__t)}; } &&
                 requires (_Tp&& __t) { ranges::subrange{_VSTD::forward<_Tp>(__t)}; })
    _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()(_Tp&& __t) const
      noexcept(noexcept(ranges::subrange{_VSTD::forward<_Tp>(__t)}))
    {
      return ranges::subrange{_VSTD::forward<_Tp>(__t)};
    }
  };
}

inline namespace __cpo {
  inline constexpr auto all = __all::__fn{};
} // namespace __cpo

template<ranges::viewable_range _Range>
using all_t = decltype(views::all(declval<_Range>()));

} // namespace views

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_ALL_H
