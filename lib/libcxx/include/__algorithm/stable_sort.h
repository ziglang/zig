//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_STABLE_SORT_H
#define _LIBCPP___ALGORITHM_STABLE_SORT_H

#include <__config>
#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/inplace_merge.h>
#include <__algorithm/sort.h>
#include <__iterator/iterator_traits.h>
#include <__utility/swap.h>
#include <memory>
#include <type_traits> // swap

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Compare, class _InputIterator1, class _InputIterator2>
void
__merge_move_construct(_InputIterator1 __first1, _InputIterator1 __last1,
        _InputIterator2 __first2, _InputIterator2 __last2,
        typename iterator_traits<_InputIterator1>::value_type* __result, _Compare __comp)
{
    typedef typename iterator_traits<_InputIterator1>::value_type value_type;
    __destruct_n __d(0);
    unique_ptr<value_type, __destruct_n&> __h(__result, __d);
    for (; true; ++__result)
    {
        if (__first1 == __last1)
        {
            for (; __first2 != __last2; ++__first2, ++__result, (void)__d.template __incr<value_type>())
                ::new ((void*)__result) value_type(_VSTD::move(*__first2));
            __h.release();
            return;
        }
        if (__first2 == __last2)
        {
            for (; __first1 != __last1; ++__first1, ++__result, (void)__d.template __incr<value_type>())
                ::new ((void*)__result) value_type(_VSTD::move(*__first1));
            __h.release();
            return;
        }
        if (__comp(*__first2, *__first1))
        {
            ::new ((void*)__result) value_type(_VSTD::move(*__first2));
            __d.template __incr<value_type>();
            ++__first2;
        }
        else
        {
            ::new ((void*)__result) value_type(_VSTD::move(*__first1));
            __d.template __incr<value_type>();
            ++__first1;
        }
    }
}

template <class _Compare, class _InputIterator1, class _InputIterator2, class _OutputIterator>
void
__merge_move_assign(_InputIterator1 __first1, _InputIterator1 __last1,
        _InputIterator2 __first2, _InputIterator2 __last2,
        _OutputIterator __result, _Compare __comp)
{
    for (; __first1 != __last1; ++__result)
    {
        if (__first2 == __last2)
        {
            for (; __first1 != __last1; ++__first1, (void) ++__result)
                *__result = _VSTD::move(*__first1);
            return;
        }
        if (__comp(*__first2, *__first1))
        {
            *__result = _VSTD::move(*__first2);
            ++__first2;
        }
        else
        {
            *__result = _VSTD::move(*__first1);
            ++__first1;
        }
    }
    for (; __first2 != __last2; ++__first2, (void) ++__result)
        *__result = _VSTD::move(*__first2);
}

template <class _Compare, class _RandomAccessIterator>
void
__stable_sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp,
              typename iterator_traits<_RandomAccessIterator>::difference_type __len,
              typename iterator_traits<_RandomAccessIterator>::value_type* __buff, ptrdiff_t __buff_size);

template <class _Compare, class _RandomAccessIterator>
void
__stable_sort_move(_RandomAccessIterator __first1, _RandomAccessIterator __last1, _Compare __comp,
                   typename iterator_traits<_RandomAccessIterator>::difference_type __len,
                   typename iterator_traits<_RandomAccessIterator>::value_type* __first2)
{
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    switch (__len)
    {
    case 0:
        return;
    case 1:
        ::new ((void*)__first2) value_type(_VSTD::move(*__first1));
        return;
    case 2:
        __destruct_n __d(0);
        unique_ptr<value_type, __destruct_n&> __h2(__first2, __d);
        if (__comp(*--__last1, *__first1))
        {
            ::new ((void*)__first2) value_type(_VSTD::move(*__last1));
            __d.template __incr<value_type>();
            ++__first2;
            ::new ((void*)__first2) value_type(_VSTD::move(*__first1));
        }
        else
        {
            ::new ((void*)__first2) value_type(_VSTD::move(*__first1));
            __d.template __incr<value_type>();
            ++__first2;
            ::new ((void*)__first2) value_type(_VSTD::move(*__last1));
        }
        __h2.release();
        return;
    }
    if (__len <= 8)
    {
        _VSTD::__insertion_sort_move<_Compare>(__first1, __last1, __first2, __comp);
        return;
    }
    typename iterator_traits<_RandomAccessIterator>::difference_type __l2 = __len / 2;
    _RandomAccessIterator __m = __first1 + __l2;
    _VSTD::__stable_sort<_Compare>(__first1, __m, __comp, __l2, __first2, __l2);
    _VSTD::__stable_sort<_Compare>(__m, __last1, __comp, __len - __l2, __first2 + __l2, __len - __l2);
    _VSTD::__merge_move_construct<_Compare>(__first1, __m, __m, __last1, __first2, __comp);
}

template <class _Tp>
struct __stable_sort_switch
{
    static const unsigned value = 128*is_trivially_copy_assignable<_Tp>::value;
};

template <class _Compare, class _RandomAccessIterator>
void
__stable_sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp,
              typename iterator_traits<_RandomAccessIterator>::difference_type __len,
              typename iterator_traits<_RandomAccessIterator>::value_type* __buff, ptrdiff_t __buff_size)
{
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
    switch (__len)
    {
    case 0:
    case 1:
        return;
    case 2:
        if (__comp(*--__last, *__first))
            swap(*__first, *__last);
        return;
    }
    if (__len <= static_cast<difference_type>(__stable_sort_switch<value_type>::value))
    {
        _VSTD::__insertion_sort<_Compare>(__first, __last, __comp);
        return;
    }
    typename iterator_traits<_RandomAccessIterator>::difference_type __l2 = __len / 2;
    _RandomAccessIterator __m = __first + __l2;
    if (__len <= __buff_size)
    {
        __destruct_n __d(0);
        unique_ptr<value_type, __destruct_n&> __h2(__buff, __d);
        _VSTD::__stable_sort_move<_Compare>(__first, __m, __comp, __l2, __buff);
        __d.__set(__l2, (value_type*)nullptr);
        _VSTD::__stable_sort_move<_Compare>(__m, __last, __comp, __len - __l2, __buff + __l2);
        __d.__set(__len, (value_type*)nullptr);
        _VSTD::__merge_move_assign<_Compare>(__buff, __buff + __l2, __buff + __l2, __buff + __len, __first, __comp);
//         _VSTD::__merge<_Compare>(move_iterator<value_type*>(__buff),
//                                  move_iterator<value_type*>(__buff + __l2),
//                                  move_iterator<_RandomAccessIterator>(__buff + __l2),
//                                  move_iterator<_RandomAccessIterator>(__buff + __len),
//                                  __first, __comp);
        return;
    }
    _VSTD::__stable_sort<_Compare>(__first, __m, __comp, __l2, __buff, __buff_size);
    _VSTD::__stable_sort<_Compare>(__m, __last, __comp, __len - __l2, __buff, __buff_size);
    _VSTD::__inplace_merge<_Compare>(__first, __m, __last, __comp, __l2, __len - __l2, __buff, __buff_size);
}

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY
void
stable_sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
    difference_type __len = __last - __first;
    pair<value_type*, ptrdiff_t> __buf(0, 0);
    unique_ptr<value_type, __return_temporary_buffer> __h;
    if (__len > static_cast<difference_type>(__stable_sort_switch<value_type>::value))
    {
        __buf = _VSTD::get_temporary_buffer<value_type>(__len);
        __h.reset(__buf.first);
    }
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    _VSTD::__stable_sort<_Comp_ref>(__first, __last, __comp, __len, __buf.first, __buf.second);
}

template <class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY
void
stable_sort(_RandomAccessIterator __first, _RandomAccessIterator __last)
{
    _VSTD::stable_sort(__first, __last, __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_STABLE_SORT_H
