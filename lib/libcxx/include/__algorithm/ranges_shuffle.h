//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_RANGES_SHUFFLE_H
#define _LIBCPP___ALGORITHM_RANGES_SHUFFLE_H

#include <__algorithm/iterator_operations.h>
#include <__algorithm/shuffle.h>
#include <__config>
#include <__functional/invoke.h>
#include <__functional/ranges_operations.h>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/next.h>
#include <__iterator/permutable.h>
#include <__random/uniform_random_bit_generator.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/dangling.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

namespace ranges {
namespace __shuffle {

struct __fn {
  // `std::shuffle` is more constrained than `std::ranges::shuffle`. `std::ranges::shuffle` only requires the given
  // generator to satisfy the `std::uniform_random_bit_generator` concept. `std::shuffle` requires the given
  // generator to meet the uniform random bit generator requirements; these requirements include satisfying
  // `std::uniform_random_bit_generator` and add a requirement for the generator to provide a nested `result_type`
  // typedef (see `[rand.req.urng]`).
  //
  // To reuse the implementation from `std::shuffle`, make the given generator meet the classic requirements by wrapping
  // it into an adaptor type that forwards all of its interface and adds the required typedef.
  template <class _Gen>
  class _ClassicGenAdaptor {
  private:
    // The generator is not required to be copyable or movable, so it has to be stored as a reference.
    _Gen& __gen;

  public:
    using result_type = invoke_result_t<_Gen&>;

    _LIBCPP_HIDE_FROM_ABI
    static constexpr auto min() { return __uncvref_t<_Gen>::min(); }
    _LIBCPP_HIDE_FROM_ABI
    static constexpr auto max() { return __uncvref_t<_Gen>::max(); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr explicit _ClassicGenAdaptor(_Gen& __g) : __gen(__g) {}

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto operator()() const { return __gen(); }
  };

  template <random_access_iterator _Iter, sentinel_for<_Iter> _Sent, class _Gen>
  requires permutable<_Iter> && uniform_random_bit_generator<remove_reference_t<_Gen>>
  _LIBCPP_HIDE_FROM_ABI
  _Iter operator()(_Iter __first, _Sent __last, _Gen&& __gen) const {
    _ClassicGenAdaptor<_Gen> __adapted_gen(__gen);
    return std::__shuffle<_RangeAlgPolicy>(std::move(__first), std::move(__last), __adapted_gen);
  }

  template<random_access_range _Range, class _Gen>
  requires permutable<iterator_t<_Range>> && uniform_random_bit_generator<remove_reference_t<_Gen>>
  _LIBCPP_HIDE_FROM_ABI
  borrowed_iterator_t<_Range> operator()(_Range&& __range, _Gen&& __gen) const {
    return (*this)(ranges::begin(__range), ranges::end(__range), std::forward<_Gen>(__gen));
  }

};

} // namespace __shuffle

inline namespace __cpo {
  inline constexpr auto shuffle = __shuffle::__fn{};
} // namespace __cpo
} // namespace ranges

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

#endif // _LIBCPP___ALGORITHM_RANGES_SHUFFLE_H
