//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_SAMPLE_H
#define _LIBCPP___ALGORITHM_SAMPLE_H

#include <__algorithm/min.h>
#include <__config>
#include <__debug>
#include <__random/uniform_int_distribution.h>
#include <iterator>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _PopulationIterator, class _SampleIterator, class _Distance,
          class _UniformRandomNumberGenerator>
_LIBCPP_INLINE_VISIBILITY
_SampleIterator __sample(_PopulationIterator __first,
                         _PopulationIterator __last, _SampleIterator __output_iter,
                         _Distance __n,
                         _UniformRandomNumberGenerator & __g,
                         input_iterator_tag) {

  _Distance __k = 0;
  for (; __first != __last && __k < __n; ++__first, (void) ++__k)
    __output_iter[__k] = *__first;
  _Distance __sz = __k;
  for (; __first != __last; ++__first, (void) ++__k) {
    _Distance __r = uniform_int_distribution<_Distance>(0, __k)(__g);
    if (__r < __sz)
      __output_iter[__r] = *__first;
  }
  return __output_iter + _VSTD::min(__n, __k);
}

template <class _PopulationIterator, class _SampleIterator, class _Distance,
          class _UniformRandomNumberGenerator>
_LIBCPP_INLINE_VISIBILITY
_SampleIterator __sample(_PopulationIterator __first,
                         _PopulationIterator __last, _SampleIterator __output_iter,
                         _Distance __n,
                         _UniformRandomNumberGenerator& __g,
                         forward_iterator_tag) {
  _Distance __unsampled_sz = _VSTD::distance(__first, __last);
  for (__n = _VSTD::min(__n, __unsampled_sz); __n != 0; ++__first) {
    _Distance __r = uniform_int_distribution<_Distance>(0, --__unsampled_sz)(__g);
    if (__r < __n) {
      *__output_iter++ = *__first;
      --__n;
    }
  }
  return __output_iter;
}

template <class _PopulationIterator, class _SampleIterator, class _Distance,
          class _UniformRandomNumberGenerator>
_LIBCPP_INLINE_VISIBILITY
_SampleIterator __sample(_PopulationIterator __first,
                         _PopulationIterator __last, _SampleIterator __output_iter,
                         _Distance __n, _UniformRandomNumberGenerator& __g) {
  typedef typename iterator_traits<_PopulationIterator>::iterator_category
        _PopCategory;
  typedef typename iterator_traits<_PopulationIterator>::difference_type
        _Difference;
  static_assert(__is_cpp17_forward_iterator<_PopulationIterator>::value ||
                __is_cpp17_random_access_iterator<_SampleIterator>::value,
                "SampleIterator must meet the requirements of RandomAccessIterator");
  typedef typename common_type<_Distance, _Difference>::type _CommonType;
  _LIBCPP_ASSERT(__n >= 0, "N must be a positive number.");
  return _VSTD::__sample(
      __first, __last, __output_iter, _CommonType(__n),
      __g, _PopCategory());
}

#if _LIBCPP_STD_VER > 14
template <class _PopulationIterator, class _SampleIterator, class _Distance,
          class _UniformRandomNumberGenerator>
inline _LIBCPP_INLINE_VISIBILITY
_SampleIterator sample(_PopulationIterator __first,
                       _PopulationIterator __last, _SampleIterator __output_iter,
                       _Distance __n, _UniformRandomNumberGenerator&& __g) {
    return _VSTD::__sample(__first, __last, __output_iter, __n, __g);
}
#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_SAMPLE_H
