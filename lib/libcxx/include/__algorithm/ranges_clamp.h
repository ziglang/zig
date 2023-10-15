//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_RANGES_CLAMP_H
#define _LIBCPP___ALGORITHM_RANGES_CLAMP_H

#include <__assert>
#include <__config>
#include <__functional/identity.h>
#include <__functional/invoke.h>
#include <__functional/ranges_operations.h>
#include <__iterator/concepts.h>
#include <__iterator/projected.h>
#include <__utility/forward.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_STD_VER >= 20

_LIBCPP_BEGIN_NAMESPACE_STD

namespace ranges {
namespace __clamp {
struct __fn {
  template <class _Type,
            class _Proj                                                      = identity,
            indirect_strict_weak_order<projected<const _Type*, _Proj>> _Comp = ranges::less>
  _LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI constexpr const _Type& operator()(
      const _Type& __value, const _Type& __low, const _Type& __high, _Comp __comp = {}, _Proj __proj = {}) const {
    _LIBCPP_ASSERT_UNCATEGORIZED(!bool(std::invoke(__comp, std::invoke(__proj, __high), std::invoke(__proj, __low))),
                                 "Bad bounds passed to std::ranges::clamp");

    if (std::invoke(__comp, std::invoke(__proj, __value), std::invoke(__proj, __low)))
      return __low;
    else if (std::invoke(__comp, std::invoke(__proj, __high), std::invoke(__proj, __value)))
      return __high;
    else
      return __value;
  }
};
} // namespace __clamp

inline namespace __cpo {
inline constexpr auto clamp = __clamp::__fn{};
} // namespace __cpo
} // namespace ranges

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_STD_VER >= 20

#endif // _LIBCPP___ALGORITHM_RANGES_CLAMP_H
