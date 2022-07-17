//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CONCEPTS_SWAPPABLE_H
#define _LIBCPP___CONCEPTS_SWAPPABLE_H

#include <__concepts/assignable.h>
#include <__concepts/class_or_enum.h>
#include <__concepts/common_reference_with.h>
#include <__concepts/constructible.h>
#include <__config>
#include <__utility/exchange.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

// [concept.swappable]

namespace ranges {
namespace __swap {

  template<class _Tp>
  void swap(_Tp&, _Tp&) = delete;

  template<class _Tp, class _Up>
  concept __unqualified_swappable_with =
    (__class_or_enum<remove_cvref_t<_Tp>> || __class_or_enum<remove_cvref_t<_Up>>) &&
    requires(_Tp&& __t, _Up&& __u) {
      swap(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u));
    };

  struct __fn;

  template<class _Tp, class _Up, size_t _Size>
  concept __swappable_arrays =
    !__unqualified_swappable_with<_Tp(&)[_Size], _Up(&)[_Size]> &&
    extent_v<_Tp> == extent_v<_Up> &&
    requires(_Tp(& __t)[_Size], _Up(& __u)[_Size], const __fn& __swap) {
      __swap(__t[0], __u[0]);
    };

  template<class _Tp>
  concept __exchangeable =
    !__unqualified_swappable_with<_Tp&, _Tp&> &&
    move_constructible<_Tp> &&
    assignable_from<_Tp&, _Tp>;

  struct __fn {
    // 2.1   `S` is `(void)swap(E1, E2)`* if `E1` or `E2` has class or enumeration type and...
    // *The name `swap` is used here unqualified.
    template<class _Tp, class _Up>
      requires __unqualified_swappable_with<_Tp, _Up>
    constexpr void operator()(_Tp&& __t, _Up&& __u) const
      noexcept(noexcept(swap(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u))))
    {
      swap(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u));
    }

    // 2.2   Otherwise, if `E1` and `E2` are lvalues of array types with equal extent and...
    template<class _Tp, class _Up, size_t _Size>
      requires __swappable_arrays<_Tp, _Up, _Size>
    constexpr void operator()(_Tp(& __t)[_Size], _Up(& __u)[_Size]) const
      noexcept(noexcept((*this)(*__t, *__u)))
    {
      // TODO(cjdb): replace with `ranges::swap_ranges`.
      for (size_t __i = 0; __i < _Size; ++__i) {
        (*this)(__t[__i], __u[__i]);
      }
    }

    // 2.3   Otherwise, if `E1` and `E2` are lvalues of the same type `T` that models...
    template<__exchangeable _Tp>
    constexpr void operator()(_Tp& __x, _Tp& __y) const
      noexcept(is_nothrow_move_constructible_v<_Tp> && is_nothrow_move_assignable_v<_Tp>)
    {
      __y = _VSTD::exchange(__x, _VSTD::move(__y));
    }
  };
} // namespace __swap

inline namespace __cpo {
  inline constexpr auto swap = __swap::__fn{};
} // namespace __cpo
} // namespace ranges

template<class _Tp>
concept swappable = requires(_Tp& __a, _Tp& __b) { ranges::swap(__a, __b); };

template<class _Tp, class _Up>
concept swappable_with =
  common_reference_with<_Tp, _Up> &&
  requires(_Tp&& __t, _Up&& __u) {
    ranges::swap(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Tp>(__t));
    ranges::swap(_VSTD::forward<_Up>(__u), _VSTD::forward<_Up>(__u));
    ranges::swap(_VSTD::forward<_Tp>(__t), _VSTD::forward<_Up>(__u));
    ranges::swap(_VSTD::forward<_Up>(__u), _VSTD::forward<_Tp>(__t));
  };

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___CONCEPTS_SWAPPABLE_H
