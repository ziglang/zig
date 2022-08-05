//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_MAX_ELEMENT_H
#define _LIBCPP___ALGORITHM_MAX_ELEMENT_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__config>
#include <__iterator/iterator_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _ForwardIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 _ForwardIterator
__max_element(_ForwardIterator __first, _ForwardIterator __last, _Compare __comp)
{
    static_assert(__is_cpp17_forward_iterator<_ForwardIterator>::value,
        "std::max_element requires a ForwardIterator");
    if (__first != __last)
    {
        _ForwardIterator __i = __first;
        while (++__i != __last)
            if (__comp(*__first, *__i))
                __first = __i;
    }
    return __first;
}

template <class _ForwardIterator, class _Compare>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 _ForwardIterator
max_element(_ForwardIterator __first, _ForwardIterator __last, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    return _VSTD::__max_element<_Comp_ref>(__first, __last, __comp);
}


template <class _ForwardIterator>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 _ForwardIterator
max_element(_ForwardIterator __first, _ForwardIterator __last)
{
    return _VSTD::max_element(__first, __last,
              __less<typename iterator_traits<_ForwardIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_MAX_ELEMENT_H
