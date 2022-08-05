//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_RANGES_REPLACE_COPY_H
#define _LIBCPP___ALGORITHM_RANGES_REPLACE_COPY_H

#include <__algorithm/in_out_result.h>
#include <__algorithm/make_projected.h>
#include <__algorithm/replace_copy.h>
#include <__config>
#include <__functional/identity.h>
#include <__functional/invoke.h>
#include <__functional/ranges_operations.h>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/projected.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/dangling.h>
#include <__utility/forward.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_BEGIN_NAMESPACE_STD

namespace ranges {

template <class _InIter, class _OutIter>
using replace_copy_result = in_out_result<_InIter, _OutIter>;

namespace __replace_copy {

struct __fn {

  template <input_iterator _InIter, sentinel_for<_InIter> _Sent, class _Type1, class _Type2,
            output_iterator<const _Type2&> _OutIter, class _Proj = identity>
  requires indirectly_copyable<_InIter, _OutIter> &&
           indirect_binary_predicate<ranges::equal_to, projected<_InIter, _Proj>, const _Type1*>
  _LIBCPP_HIDE_FROM_ABI constexpr
  replace_copy_result<_InIter, _OutIter>
  operator()(_InIter __first, _Sent __last, _OutIter __result, const _Type1& __old_value, const _Type2& __new_value,
               _Proj __proj = {}) const {
    // TODO: implement
    (void)__first; (void)__last; (void)__result; (void)__old_value; (void)__new_value; (void)__proj;
    return {};
  }

  template <input_range _Range, class _Type1, class _Type2, output_iterator<const _Type2&> _OutIter,
            class _Proj = identity>
  requires indirectly_copyable<iterator_t<_Range>, _OutIter> &&
           indirect_binary_predicate<ranges::equal_to, projected<iterator_t<_Range>, _Proj>, const _Type1*>
  _LIBCPP_HIDE_FROM_ABI constexpr
  replace_copy_result<borrowed_iterator_t<_Range>, _OutIter>
  operator()(_Range&& __range, _OutIter __result, const _Type1& __old_value, const _Type2& __new_value,
               _Proj __proj = {}) const {
    // TODO: implement
    (void)__range; (void)__result; (void)__old_value; (void)__new_value; (void)__proj;
    return {};
  }

};

} // namespace __replace_copy

inline namespace __cpo {
  inline constexpr auto replace_copy = __replace_copy::__fn{};
} // namespace __cpo
} // namespace ranges

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

#endif // _LIBCPP___ALGORITHM_RANGES_REPLACE_COPY_H
