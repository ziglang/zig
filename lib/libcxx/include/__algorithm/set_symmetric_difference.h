//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_SET_SYMMETRIC_DIFFERENCE_H
#define _LIBCPP___ALGORITHM_SET_SYMMETRIC_DIFFERENCE_H

#include <__config>
#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/copy.h>
#include <__iterator/iterator_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _InputIterator1, class _InputIterator2, class _OutputIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX17 _OutputIterator
__set_symmetric_difference(_InputIterator1 __first1, _InputIterator1 __last1,
                           _InputIterator2 __first2, _InputIterator2 __last2, _OutputIterator __result, _Compare __comp)
{
    while (__first1 != __last1)
    {
        if (__first2 == __last2)
            return _VSTD::copy(__first1, __last1, __result);
        if (__comp(*__first1, *__first2))
        {
            *__result = *__first1;
            ++__result;
            ++__first1;
        }
        else
        {
            if (__comp(*__first2, *__first1))
            {
                *__result = *__first2;
                ++__result;
            }
            else
                ++__first1;
            ++__first2;
        }
    }
    return _VSTD::copy(__first2, __last2, __result);
}

template <class _InputIterator1, class _InputIterator2, class _OutputIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_OutputIterator
set_symmetric_difference(_InputIterator1 __first1, _InputIterator1 __last1,
                         _InputIterator2 __first2, _InputIterator2 __last2, _OutputIterator __result, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    return _VSTD::__set_symmetric_difference<_Comp_ref>(__first1, __last1, __first2, __last2, __result, __comp);
}

template <class _InputIterator1, class _InputIterator2, class _OutputIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_OutputIterator
set_symmetric_difference(_InputIterator1 __first1, _InputIterator1 __last1,
                         _InputIterator2 __first2, _InputIterator2 __last2, _OutputIterator __result)
{
    return _VSTD::set_symmetric_difference(__first1, __last1, __first2, __last2, __result,
                                          __less<typename iterator_traits<_InputIterator1>::value_type,
                                                 typename iterator_traits<_InputIterator2>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_SET_SYMMETRIC_DIFFERENCE_H
