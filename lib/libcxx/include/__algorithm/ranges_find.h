//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_RANGES_FIND_H
#define _LIBCPP___ALGORITHM_RANGES_FIND_H

#include <__algorithm/ranges_find_if.h>
#include <__config>
#include <__functional/identity.h>
#include <__functional/invoke.h>
#include <__functional/ranges_operations.h>
#include <__iterator/concepts.h>
#include <__iterator/projected.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/dangling.h>
#include <__utility/forward.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_STD_VER > 17

_LIBCPP_BEGIN_NAMESPACE_STD

namespace ranges {
namespace __find {
struct __fn {
  template <input_iterator _Ip, sentinel_for<_Ip> _Sp, class _Tp, class _Proj = identity>
    requires indirect_binary_predicate<ranges::equal_to, projected<_Ip, _Proj>, const _Tp*>
  _LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI constexpr
  _Ip operator()(_Ip __first, _Sp __last, const _Tp& __value, _Proj __proj = {}) const {
    auto __pred = [&](auto&& __e) { return std::forward<decltype(__e)>(__e) == __value; };
    return ranges::__find_if_impl(std::move(__first), std::move(__last), __pred, __proj);
  }

  template <input_range _Rp, class _Tp, class _Proj = identity>
    requires indirect_binary_predicate<ranges::equal_to, projected<iterator_t<_Rp>, _Proj>, const _Tp*>
  _LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI constexpr
  borrowed_iterator_t<_Rp> operator()(_Rp&& __r, const _Tp& __value, _Proj __proj = {}) const {
    auto __pred = [&](auto&& __e) { return std::forward<decltype(__e)>(__e) == __value; };
    return ranges::__find_if_impl(ranges::begin(__r), ranges::end(__r), __pred, __proj);
  }
};
} // namespace __find

inline namespace __cpo {
  inline constexpr auto find = __find::__fn{};
} // namespace __cpo
} // namespace ranges

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_STD_VER > 17

#endif // _LIBCPP___ALGORITHM_RANGES_FIND_H
