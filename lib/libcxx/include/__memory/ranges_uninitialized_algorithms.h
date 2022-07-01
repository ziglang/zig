// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_RANGES_UNINITIALIZED_ALGORITHMS_H
#define _LIBCPP___MEMORY_RANGES_UNINITIALIZED_ALGORITHMS_H

#include <__algorithm/in_out_result.h>
#include <__concepts/constructible.h>
#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iter_move.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/readable_traits.h>
#include <__memory/concepts.h>
#include <__memory/uninitialized_algorithms.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/dangling.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges {

// uninitialized_default_construct

namespace __uninitialized_default_construct {

struct __fn {
  template <__nothrow_forward_iterator _ForwardIterator,
            __nothrow_sentinel_for<_ForwardIterator> _Sentinel>
    requires default_initializable<iter_value_t<_ForwardIterator>>
  _ForwardIterator operator()(_ForwardIterator __first, _Sentinel __last) const {
    using _ValueType = remove_reference_t<iter_reference_t<_ForwardIterator>>;
    return _VSTD::__uninitialized_default_construct<_ValueType>(
        _VSTD::move(__first), _VSTD::move(__last));
  }

  template <__nothrow_forward_range _ForwardRange>
    requires default_initializable<range_value_t<_ForwardRange>>
  borrowed_iterator_t<_ForwardRange> operator()(_ForwardRange&& __range) const {
    return (*this)(ranges::begin(__range), ranges::end(__range));
  }
};

} // namespace __uninitialized_default_construct

inline namespace __cpo {
  inline constexpr auto uninitialized_default_construct = __uninitialized_default_construct::__fn{};
} // namespace __cpo

// uninitialized_default_construct_n

namespace __uninitialized_default_construct_n {

struct __fn {
  template <__nothrow_forward_iterator _ForwardIterator>
    requires default_initializable<iter_value_t<_ForwardIterator>>
  _ForwardIterator operator()(_ForwardIterator __first,
                              iter_difference_t<_ForwardIterator> __n) const {
    using _ValueType = remove_reference_t<iter_reference_t<_ForwardIterator>>;
    return _VSTD::__uninitialized_default_construct_n<_ValueType>(_VSTD::move(__first), __n);
  }
};

} // namespace __uninitialized_default_construct_n

inline namespace __cpo {
  inline constexpr auto uninitialized_default_construct_n = __uninitialized_default_construct_n::__fn{};
} // namespace __cpo

// uninitialized_value_construct

namespace __uninitialized_value_construct {

struct __fn {
  template <__nothrow_forward_iterator _ForwardIterator,
            __nothrow_sentinel_for<_ForwardIterator> _Sentinel>
    requires default_initializable<iter_value_t<_ForwardIterator>>
  _ForwardIterator operator()(_ForwardIterator __first, _Sentinel __last) const {
    using _ValueType = remove_reference_t<iter_reference_t<_ForwardIterator>>;
    return _VSTD::__uninitialized_value_construct<_ValueType>(
        _VSTD::move(__first), _VSTD::move(__last));
  }

  template <__nothrow_forward_range _ForwardRange>
    requires default_initializable<range_value_t<_ForwardRange>>
  borrowed_iterator_t<_ForwardRange> operator()(_ForwardRange&& __range) const {
    return (*this)(ranges::begin(__range), ranges::end(__range));
  }
};

} // namespace __uninitialized_value_construct

inline namespace __cpo {
  inline constexpr auto uninitialized_value_construct = __uninitialized_value_construct::__fn{};
} // namespace __cpo

// uninitialized_value_construct_n

namespace __uninitialized_value_construct_n {

struct __fn {
  template <__nothrow_forward_iterator _ForwardIterator>
    requires default_initializable<iter_value_t<_ForwardIterator>>
  _ForwardIterator operator()(_ForwardIterator __first,
                              iter_difference_t<_ForwardIterator> __n) const {
    using _ValueType = remove_reference_t<iter_reference_t<_ForwardIterator>>;
    return _VSTD::__uninitialized_value_construct_n<_ValueType>(_VSTD::move(__first), __n);
  }
};

} // namespace __uninitialized_value_construct_n

inline namespace __cpo {
  inline constexpr auto uninitialized_value_construct_n = __uninitialized_value_construct_n::__fn{};
} // namespace __cpo

// uninitialized_fill

namespace __uninitialized_fill {

struct __fn {
  template <__nothrow_forward_iterator _ForwardIterator,
            __nothrow_sentinel_for<_ForwardIterator> _Sentinel,
            class _Tp>
    requires constructible_from<iter_value_t<_ForwardIterator>, const _Tp&>
  _ForwardIterator operator()(_ForwardIterator __first, _Sentinel __last, const _Tp& __x) const {
    using _ValueType = remove_reference_t<iter_reference_t<_ForwardIterator>>;
    return _VSTD::__uninitialized_fill<_ValueType>(_VSTD::move(__first), _VSTD::move(__last), __x);
  }

  template <__nothrow_forward_range _ForwardRange, class _Tp>
    requires constructible_from<range_value_t<_ForwardRange>, const _Tp&>
  borrowed_iterator_t<_ForwardRange> operator()(_ForwardRange&& __range, const _Tp& __x) const {
    return (*this)(ranges::begin(__range), ranges::end(__range), __x);
  }
};

} // namespace __uninitialized_fill

inline namespace __cpo {
  inline constexpr auto uninitialized_fill = __uninitialized_fill::__fn{};
} // namespace __cpo

// uninitialized_fill_n

namespace __uninitialized_fill_n {

struct __fn {
  template <__nothrow_forward_iterator _ForwardIterator, class _Tp>
    requires constructible_from<iter_value_t<_ForwardIterator>, const _Tp&>
  _ForwardIterator operator()(_ForwardIterator __first,
                              iter_difference_t<_ForwardIterator> __n,
                              const _Tp& __x) const {
    using _ValueType = remove_reference_t<iter_reference_t<_ForwardIterator>>;
    return _VSTD::__uninitialized_fill_n<_ValueType>(_VSTD::move(__first), __n, __x);
  }
};

} // namespace __uninitialized_fill_n

inline namespace __cpo {
  inline constexpr auto uninitialized_fill_n = __uninitialized_fill_n::__fn{};
} // namespace __cpo

// uninitialized_copy

template <class _InputIterator, class _OutputIterator>
using uninitialized_copy_result = in_out_result<_InputIterator, _OutputIterator>;

namespace __uninitialized_copy {

struct __fn {
  template <input_iterator _InputIterator,
            sentinel_for<_InputIterator> _Sentinel1,
            __nothrow_forward_iterator _OutputIterator,
            __nothrow_sentinel_for<_OutputIterator> _Sentinel2>
    requires constructible_from<iter_value_t<_OutputIterator>, iter_reference_t<_InputIterator>>
  uninitialized_copy_result<_InputIterator, _OutputIterator>
  operator()(_InputIterator __ifirst, _Sentinel1 __ilast, _OutputIterator __ofirst, _Sentinel2 __olast) const {
    using _ValueType = remove_reference_t<iter_reference_t<_OutputIterator>>;

    auto __result = _VSTD::__uninitialized_copy<_ValueType>(_VSTD::move(__ifirst), _VSTD::move(__ilast),
                                                            _VSTD::move(__ofirst), _VSTD::move(__olast));
    return {_VSTD::move(__result.first), _VSTD::move(__result.second)};
  }

  template <input_range _InputRange, __nothrow_forward_range _OutputRange>
    requires constructible_from<range_value_t<_OutputRange>, range_reference_t<_InputRange>>
  uninitialized_copy_result<borrowed_iterator_t<_InputRange>, borrowed_iterator_t<_OutputRange>>
  operator()( _InputRange&& __in_range, _OutputRange&& __out_range) const {
    return (*this)(ranges::begin(__in_range), ranges::end(__in_range),
                   ranges::begin(__out_range), ranges::end(__out_range));
  }
};

} // namespace __uninitialized_copy

inline namespace __cpo {
  inline constexpr auto uninitialized_copy = __uninitialized_copy::__fn{};
} // namespace __cpo

// uninitialized_copy_n

template <class _InputIterator, class _OutputIterator>
using uninitialized_copy_n_result = in_out_result<_InputIterator, _OutputIterator>;

namespace __uninitialized_copy_n {

struct __fn {
  template <input_iterator _InputIterator,
           __nothrow_forward_iterator _OutputIterator,
           __nothrow_sentinel_for<_OutputIterator> _Sentinel>
    requires constructible_from<iter_value_t<_OutputIterator>, iter_reference_t<_InputIterator>>
  uninitialized_copy_n_result<_InputIterator, _OutputIterator>
  operator()(_InputIterator __ifirst, iter_difference_t<_InputIterator> __n,
             _OutputIterator __ofirst, _Sentinel __olast) const {
    using _ValueType = remove_reference_t<iter_reference_t<_OutputIterator>>;
    auto __result = _VSTD::__uninitialized_copy_n<_ValueType>(_VSTD::move(__ifirst), __n,
                                                              _VSTD::move(__ofirst), _VSTD::move(__olast));
    return {_VSTD::move(__result.first), _VSTD::move(__result.second)};
  }
};

} // namespace __uninitialized_copy_n

inline namespace __cpo {
  inline constexpr auto uninitialized_copy_n = __uninitialized_copy_n::__fn{};
} // namespace __cpo

// uninitialized_move

template <class _InputIterator, class _OutputIterator>
using uninitialized_move_result = in_out_result<_InputIterator, _OutputIterator>;

namespace __uninitialized_move {

struct __fn {
  template <input_iterator _InputIterator,
            sentinel_for<_InputIterator> _Sentinel1,
            __nothrow_forward_iterator _OutputIterator,
            __nothrow_sentinel_for<_OutputIterator> _Sentinel2>
    requires constructible_from<iter_value_t<_OutputIterator>, iter_reference_t<_InputIterator>>
  uninitialized_move_result<_InputIterator, _OutputIterator>
  operator()(_InputIterator __ifirst, _Sentinel1 __ilast, _OutputIterator __ofirst, _Sentinel2 __olast) const {
    using _ValueType = remove_reference_t<iter_reference_t<_OutputIterator>>;
    auto __iter_move = [](auto&& __iter) -> decltype(auto) { return ranges::iter_move(__iter); };
    auto __result = _VSTD::__uninitialized_move<_ValueType>(_VSTD::move(__ifirst), _VSTD::move(__ilast),
                                                            _VSTD::move(__ofirst), _VSTD::move(__olast), __iter_move);
    return {_VSTD::move(__result.first), _VSTD::move(__result.second)};
  }

  template <input_range _InputRange, __nothrow_forward_range _OutputRange>
    requires constructible_from<range_value_t<_OutputRange>, range_reference_t<_InputRange>>
  uninitialized_move_result<borrowed_iterator_t<_InputRange>, borrowed_iterator_t<_OutputRange>>
  operator()(_InputRange&& __in_range, _OutputRange&& __out_range) const {
    return (*this)(ranges::begin(__in_range), ranges::end(__in_range),
                   ranges::begin(__out_range), ranges::end(__out_range));
  }
};

} // namespace __uninitialized_move

inline namespace __cpo {
  inline constexpr auto uninitialized_move = __uninitialized_move::__fn{};
} // namespace __cpo

// uninitialized_move_n

template <class _InputIterator, class _OutputIterator>
using uninitialized_move_n_result = in_out_result<_InputIterator, _OutputIterator>;

namespace __uninitialized_move_n {

struct __fn {
  template <input_iterator _InputIterator,
           __nothrow_forward_iterator _OutputIterator,
           __nothrow_sentinel_for<_OutputIterator> _Sentinel>
    requires constructible_from<iter_value_t<_OutputIterator>, iter_reference_t<_InputIterator>>
  uninitialized_move_n_result<_InputIterator, _OutputIterator>
  operator()(_InputIterator __ifirst, iter_difference_t<_InputIterator> __n,
             _OutputIterator __ofirst, _Sentinel __olast) const {
    using _ValueType = remove_reference_t<iter_reference_t<_OutputIterator>>;
    auto __iter_move = [](auto&& __iter) -> decltype(auto) { return ranges::iter_move(__iter); };
    auto __result = _VSTD::__uninitialized_move_n<_ValueType>(_VSTD::move(__ifirst), __n,
                                                              _VSTD::move(__ofirst), _VSTD::move(__olast), __iter_move);
    return {_VSTD::move(__result.first), _VSTD::move(__result.second)};
  }
};

} // namespace __uninitialized_move_n

inline namespace __cpo {
  inline constexpr auto uninitialized_move_n = __uninitialized_move_n::__fn{};
} // namespace __cpo

} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___MEMORY_RANGES_UNINITIALIZED_ALGORITHMS_H
