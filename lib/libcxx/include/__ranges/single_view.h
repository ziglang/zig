// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_SINGLE_VIEW_H
#define _LIBCPP___RANGES_SINGLE_VIEW_H

#include <__config>
#include <__ranges/copyable_box.h>
#include <__ranges/range_adaptor.h>
#include <__ranges/view_interface.h>
#include <__utility/forward.h>
#include <__utility/in_place.h>
#include <__utility/move.h>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges {
  template<copy_constructible _Tp>
    requires is_object_v<_Tp>
  class single_view : public view_interface<single_view<_Tp>> {
    __copyable_box<_Tp> __value_;

  public:
    _LIBCPP_HIDE_FROM_ABI
    single_view() requires default_initializable<_Tp> = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr explicit single_view(const _Tp& __t) : __value_(in_place, __t) {}

    _LIBCPP_HIDE_FROM_ABI
    constexpr explicit single_view(_Tp&& __t) : __value_(in_place, std::move(__t)) {}

    template<class... _Args>
      requires constructible_from<_Tp, _Args...>
    _LIBCPP_HIDE_FROM_ABI
    constexpr explicit single_view(in_place_t, _Args&&... __args)
      : __value_{in_place, std::forward<_Args>(__args)...} {}

    _LIBCPP_HIDE_FROM_ABI
    constexpr _Tp* begin() noexcept { return data(); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr const _Tp* begin() const noexcept { return data(); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr _Tp* end() noexcept { return data() + 1; }

    _LIBCPP_HIDE_FROM_ABI
    constexpr const _Tp* end() const noexcept { return data() + 1; }

    _LIBCPP_HIDE_FROM_ABI
    static constexpr size_t size() noexcept { return 1; }

    _LIBCPP_HIDE_FROM_ABI
    constexpr _Tp* data() noexcept { return __value_.operator->(); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr const _Tp* data() const noexcept { return __value_.operator->(); }
  };

template<class _Tp>
single_view(_Tp) -> single_view<_Tp>;

namespace views {
namespace __single_view {

struct __fn : __range_adaptor_closure<__fn> {
  template<class _Range>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI
  constexpr auto operator()(_Range&& __range) const
    noexcept(noexcept(single_view<decay_t<_Range&&>>(std::forward<_Range>(__range))))
    -> decltype(      single_view<decay_t<_Range&&>>(std::forward<_Range>(__range)))
    { return          single_view<decay_t<_Range&&>>(std::forward<_Range>(__range)); }
};
} // namespace __single_view

inline namespace __cpo {
  inline constexpr auto single = __single_view::__fn{};
} // namespace __cpo

} // namespace views
} // namespace ranges

#endif // _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___RANGES_SINGLE_VIEW_H
