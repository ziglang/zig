//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_SORT_H
#define _LIBCPP___ALGORITHM_SORT_H

#include <__config>
#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/min_element.h>
#include <__algorithm/partial_sort.h>
#include <__algorithm/unwrap_iter.h>
#include <__utility/swap.h>
#include <memory>
#include <type_traits> // swap

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

// stable, 2-3 compares, 0-2 swaps

template <class _Compare, class _ForwardIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 unsigned
__sort3(_ForwardIterator __x, _ForwardIterator __y, _ForwardIterator __z, _Compare __c)
{
    unsigned __r = 0;
    if (!__c(*__y, *__x))          // if x <= y
    {
        if (!__c(*__z, *__y))      // if y <= z
            return __r;            // x <= y && y <= z
                                   // x <= y && y > z
        swap(*__y, *__z);          // x <= z && y < z
        __r = 1;
        if (__c(*__y, *__x))       // if x > y
        {
            swap(*__x, *__y);      // x < y && y <= z
            __r = 2;
        }
        return __r;                // x <= y && y < z
    }
    if (__c(*__z, *__y))           // x > y, if y > z
    {
        swap(*__x, *__z);          // x < y && y < z
        __r = 1;
        return __r;
    }
    swap(*__x, *__y);              // x > y && y <= z
    __r = 1;                       // x < y && x <= z
    if (__c(*__z, *__y))           // if y > z
    {
        swap(*__y, *__z);          // x <= y && y < z
        __r = 2;
    }
    return __r;
}                                  // x <= y && y <= z

// stable, 3-6 compares, 0-5 swaps

template <class _Compare, class _ForwardIterator>
unsigned
__sort4(_ForwardIterator __x1, _ForwardIterator __x2, _ForwardIterator __x3,
            _ForwardIterator __x4, _Compare __c)
{
    unsigned __r = _VSTD::__sort3<_Compare>(__x1, __x2, __x3, __c);
    if (__c(*__x4, *__x3))
    {
        swap(*__x3, *__x4);
        ++__r;
        if (__c(*__x3, *__x2))
        {
            swap(*__x2, *__x3);
            ++__r;
            if (__c(*__x2, *__x1))
            {
                swap(*__x1, *__x2);
                ++__r;
            }
        }
    }
    return __r;
}

// stable, 4-10 compares, 0-9 swaps

template <class _Compare, class _ForwardIterator>
_LIBCPP_HIDDEN
unsigned
__sort5(_ForwardIterator __x1, _ForwardIterator __x2, _ForwardIterator __x3,
            _ForwardIterator __x4, _ForwardIterator __x5, _Compare __c)
{
    unsigned __r = _VSTD::__sort4<_Compare>(__x1, __x2, __x3, __x4, __c);
    if (__c(*__x5, *__x4))
    {
        swap(*__x4, *__x5);
        ++__r;
        if (__c(*__x4, *__x3))
        {
            swap(*__x3, *__x4);
            ++__r;
            if (__c(*__x3, *__x2))
            {
                swap(*__x2, *__x3);
                ++__r;
                if (__c(*__x2, *__x1))
                {
                    swap(*__x1, *__x2);
                    ++__r;
                }
            }
        }
    }
    return __r;
}

// Assumes size > 0
template <class _Compare, class _BidirectionalIterator>
_LIBCPP_CONSTEXPR_AFTER_CXX11 void
__selection_sort(_BidirectionalIterator __first, _BidirectionalIterator __last, _Compare __comp)
{
    _BidirectionalIterator __lm1 = __last;
    for (--__lm1; __first != __lm1; ++__first)
    {
        _BidirectionalIterator __i = _VSTD::min_element<_BidirectionalIterator,
                                                        typename add_lvalue_reference<_Compare>::type>
                                                       (__first, __last, __comp);
        if (__i != __first)
            swap(*__first, *__i);
    }
}

template <class _Compare, class _BidirectionalIterator>
void
__insertion_sort(_BidirectionalIterator __first, _BidirectionalIterator __last, _Compare __comp)
{
    typedef typename iterator_traits<_BidirectionalIterator>::value_type value_type;
    if (__first != __last)
    {
        _BidirectionalIterator __i = __first;
        for (++__i; __i != __last; ++__i)
        {
            _BidirectionalIterator __j = __i;
            value_type __t(_VSTD::move(*__j));
            for (_BidirectionalIterator __k = __i; __k != __first && __comp(__t,  *--__k); --__j)
                *__j = _VSTD::move(*__k);
            *__j = _VSTD::move(__t);
        }
    }
}

template <class _Compare, class _RandomAccessIterator>
void
__insertion_sort_3(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    _RandomAccessIterator __j = __first+2;
    _VSTD::__sort3<_Compare>(__first, __first+1, __j, __comp);
    for (_RandomAccessIterator __i = __j+1; __i != __last; ++__i)
    {
        if (__comp(*__i, *__j))
        {
            value_type __t(_VSTD::move(*__i));
            _RandomAccessIterator __k = __j;
            __j = __i;
            do
            {
                *__j = _VSTD::move(*__k);
                __j = __k;
            } while (__j != __first && __comp(__t, *--__k));
            *__j = _VSTD::move(__t);
        }
        __j = __i;
    }
}

template <class _Compare, class _RandomAccessIterator>
bool
__insertion_sort_incomplete(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    switch (__last - __first)
    {
    case 0:
    case 1:
        return true;
    case 2:
        if (__comp(*--__last, *__first))
            swap(*__first, *__last);
        return true;
    case 3:
        _VSTD::__sort3<_Compare>(__first, __first+1, --__last, __comp);
        return true;
    case 4:
        _VSTD::__sort4<_Compare>(__first, __first+1, __first+2, --__last, __comp);
        return true;
    case 5:
        _VSTD::__sort5<_Compare>(__first, __first+1, __first+2, __first+3, --__last, __comp);
        return true;
    }
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    _RandomAccessIterator __j = __first+2;
    _VSTD::__sort3<_Compare>(__first, __first+1, __j, __comp);
    const unsigned __limit = 8;
    unsigned __count = 0;
    for (_RandomAccessIterator __i = __j+1; __i != __last; ++__i)
    {
        if (__comp(*__i, *__j))
        {
            value_type __t(_VSTD::move(*__i));
            _RandomAccessIterator __k = __j;
            __j = __i;
            do
            {
                *__j = _VSTD::move(*__k);
                __j = __k;
            } while (__j != __first && __comp(__t, *--__k));
            *__j = _VSTD::move(__t);
            if (++__count == __limit)
                return ++__i == __last;
        }
        __j = __i;
    }
    return true;
}

template <class _Compare, class _BidirectionalIterator>
void
__insertion_sort_move(_BidirectionalIterator __first1, _BidirectionalIterator __last1,
                      typename iterator_traits<_BidirectionalIterator>::value_type* __first2, _Compare __comp)
{
    typedef typename iterator_traits<_BidirectionalIterator>::value_type value_type;
    if (__first1 != __last1)
    {
        __destruct_n __d(0);
        unique_ptr<value_type, __destruct_n&> __h(__first2, __d);
        value_type* __last2 = __first2;
        ::new ((void*)__last2) value_type(_VSTD::move(*__first1));
        __d.template __incr<value_type>();
        for (++__last2; ++__first1 != __last1; ++__last2)
        {
            value_type* __j2 = __last2;
            value_type* __i2 = __j2;
            if (__comp(*__first1, *--__i2))
            {
                ::new ((void*)__j2) value_type(_VSTD::move(*__i2));
                __d.template __incr<value_type>();
                for (--__j2; __i2 != __first2 && __comp(*__first1,  *--__i2); --__j2)
                    *__j2 = _VSTD::move(*__i2);
                *__j2 = _VSTD::move(*__first1);
            }
            else
            {
                ::new ((void*)__j2) value_type(_VSTD::move(*__first1));
                __d.template __incr<value_type>();
            }
        }
        __h.release();
    }
}

template <class _Compare, class _RandomAccessIterator>
void
__sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    typedef typename iterator_traits<_RandomAccessIterator>::difference_type difference_type;
    typedef typename iterator_traits<_RandomAccessIterator>::value_type value_type;
    const difference_type __limit = is_trivially_copy_constructible<value_type>::value &&
                                    is_trivially_copy_assignable<value_type>::value ? 30 : 6;
    while (true)
    {
    __restart:
        difference_type __len = __last - __first;
        switch (__len)
        {
        case 0:
        case 1:
            return;
        case 2:
            if (__comp(*--__last, *__first))
                swap(*__first, *__last);
            return;
        case 3:
            _VSTD::__sort3<_Compare>(__first, __first+1, --__last, __comp);
            return;
        case 4:
            _VSTD::__sort4<_Compare>(__first, __first+1, __first+2, --__last, __comp);
            return;
        case 5:
            _VSTD::__sort5<_Compare>(__first, __first+1, __first+2, __first+3, --__last, __comp);
            return;
        }
        if (__len <= __limit)
        {
            _VSTD::__insertion_sort_3<_Compare>(__first, __last, __comp);
            return;
        }
        // __len > 5
        _RandomAccessIterator __m = __first;
        _RandomAccessIterator __lm1 = __last;
        --__lm1;
        unsigned __n_swaps;
        {
        difference_type __delta;
        if (__len >= 1000)
        {
            __delta = __len/2;
            __m += __delta;
            __delta /= 2;
            __n_swaps = _VSTD::__sort5<_Compare>(__first, __first + __delta, __m, __m+__delta, __lm1, __comp);
        }
        else
        {
            __delta = __len/2;
            __m += __delta;
            __n_swaps = _VSTD::__sort3<_Compare>(__first, __m, __lm1, __comp);
        }
        }
        // *__m is median
        // partition [__first, __m) < *__m and *__m <= [__m, __last)
        // (this inhibits tossing elements equivalent to __m around unnecessarily)
        _RandomAccessIterator __i = __first;
        _RandomAccessIterator __j = __lm1;
        // j points beyond range to be tested, *__m is known to be <= *__lm1
        // The search going up is known to be guarded but the search coming down isn't.
        // Prime the downward search with a guard.
        if (!__comp(*__i, *__m))  // if *__first == *__m
        {
            // *__first == *__m, *__first doesn't go in first part
            // manually guard downward moving __j against __i
            while (true)
            {
                if (__i == --__j)
                {
                    // *__first == *__m, *__m <= all other elements
                    // Parition instead into [__first, __i) == *__first and *__first < [__i, __last)
                    ++__i;  // __first + 1
                    __j = __last;
                    if (!__comp(*__first, *--__j))  // we need a guard if *__first == *(__last-1)
                    {
                        while (true)
                        {
                            if (__i == __j)
                                return;  // [__first, __last) all equivalent elements
                            if (__comp(*__first, *__i))
                            {
                                swap(*__i, *__j);
                                ++__n_swaps;
                                ++__i;
                                break;
                            }
                            ++__i;
                        }
                    }
                    // [__first, __i) == *__first and *__first < [__j, __last) and __j == __last - 1
                    if (__i == __j)
                        return;
                    while (true)
                    {
                        while (!__comp(*__first, *__i))
                            ++__i;
                        while (__comp(*__first, *--__j))
                            ;
                        if (__i >= __j)
                            break;
                        swap(*__i, *__j);
                        ++__n_swaps;
                        ++__i;
                    }
                    // [__first, __i) == *__first and *__first < [__i, __last)
                    // The first part is sorted, sort the second part
                    // _VSTD::__sort<_Compare>(__i, __last, __comp);
                    __first = __i;
                    goto __restart;
                }
                if (__comp(*__j, *__m))
                {
                    swap(*__i, *__j);
                    ++__n_swaps;
                    break;  // found guard for downward moving __j, now use unguarded partition
                }
            }
        }
        // It is known that *__i < *__m
        ++__i;
        // j points beyond range to be tested, *__m is known to be <= *__lm1
        // if not yet partitioned...
        if (__i < __j)
        {
            // known that *(__i - 1) < *__m
            // known that __i <= __m
            while (true)
            {
                // __m still guards upward moving __i
                while (__comp(*__i, *__m))
                    ++__i;
                // It is now known that a guard exists for downward moving __j
                while (!__comp(*--__j, *__m))
                    ;
                if (__i > __j)
                    break;
                swap(*__i, *__j);
                ++__n_swaps;
                // It is known that __m != __j
                // If __m just moved, follow it
                if (__m == __i)
                    __m = __j;
                ++__i;
            }
        }
        // [__first, __i) < *__m and *__m <= [__i, __last)
        if (__i != __m && __comp(*__m, *__i))
        {
            swap(*__i, *__m);
            ++__n_swaps;
        }
        // [__first, __i) < *__i and *__i <= [__i+1, __last)
        // If we were given a perfect partition, see if insertion sort is quick...
        if (__n_swaps == 0)
        {
            bool __fs = _VSTD::__insertion_sort_incomplete<_Compare>(__first, __i, __comp);
            if (_VSTD::__insertion_sort_incomplete<_Compare>(__i+1, __last, __comp))
            {
                if (__fs)
                    return;
                __last = __i;
                continue;
            }
            else
            {
                if (__fs)
                {
                    __first = ++__i;
                    continue;
                }
            }
        }
        // sort smaller range with recursive call and larger with tail recursion elimination
        if (__i - __first < __last - __i)
        {
            _VSTD::__sort<_Compare>(__first, __i, __comp);
            // _VSTD::__sort<_Compare>(__i+1, __last, __comp);
            __first = ++__i;
        }
        else
        {
            _VSTD::__sort<_Compare>(__i+1, __last, __comp);
            // _VSTD::__sort<_Compare>(__first, __i, __comp);
            __last = __i;
        }
    }
}

template <class _Compare, class _Tp>
inline _LIBCPP_INLINE_VISIBILITY
void
__sort(_Tp** __first, _Tp** __last, __less<_Tp*>&)
{
    __less<uintptr_t> __comp;
    _VSTD::__sort<__less<uintptr_t>&, uintptr_t*>((uintptr_t*)__first, (uintptr_t*)__last, __comp);
}

_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<char>&, char*>(char*, char*, __less<char>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<wchar_t>&, wchar_t*>(wchar_t*, wchar_t*, __less<wchar_t>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<signed char>&, signed char*>(signed char*, signed char*, __less<signed char>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<unsigned char>&, unsigned char*>(unsigned char*, unsigned char*, __less<unsigned char>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<short>&, short*>(short*, short*, __less<short>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<unsigned short>&, unsigned short*>(unsigned short*, unsigned short*, __less<unsigned short>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<int>&, int*>(int*, int*, __less<int>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<unsigned>&, unsigned*>(unsigned*, unsigned*, __less<unsigned>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<long>&, long*>(long*, long*, __less<long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<unsigned long>&, unsigned long*>(unsigned long*, unsigned long*, __less<unsigned long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<long long>&, long long*>(long long*, long long*, __less<long long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<unsigned long long>&, unsigned long long*>(unsigned long long*, unsigned long long*, __less<unsigned long long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<float>&, float*>(float*, float*, __less<float>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<double>&, double*>(double*, double*, __less<double>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS void __sort<__less<long double>&, long double*>(long double*, long double*, __less<long double>&))

_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<char>&, char*>(char*, char*, __less<char>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<wchar_t>&, wchar_t*>(wchar_t*, wchar_t*, __less<wchar_t>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<signed char>&, signed char*>(signed char*, signed char*, __less<signed char>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned char>&, unsigned char*>(unsigned char*, unsigned char*, __less<unsigned char>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<short>&, short*>(short*, short*, __less<short>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned short>&, unsigned short*>(unsigned short*, unsigned short*, __less<unsigned short>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<int>&, int*>(int*, int*, __less<int>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned>&, unsigned*>(unsigned*, unsigned*, __less<unsigned>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<long>&, long*>(long*, long*, __less<long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned long>&, unsigned long*>(unsigned long*, unsigned long*, __less<unsigned long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<long long>&, long long*>(long long*, long long*, __less<long long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<unsigned long long>&, unsigned long long*>(unsigned long long*, unsigned long long*, __less<unsigned long long>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<float>&, float*>(float*, float*, __less<float>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<double>&, double*>(double*, double*, __less<double>&))
_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS bool __insertion_sort_incomplete<__less<long double>&, long double*>(long double*, long double*, __less<long double>&))

_LIBCPP_EXTERN_TEMPLATE(_LIBCPP_FUNC_VIS unsigned __sort5<__less<long double>&, long double*>(long double*, long double*, long double*, long double*, long double*, __less<long double>&))

template <class _RandomAccessIterator, class _Compare>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
sort(_RandomAccessIterator __first, _RandomAccessIterator __last, _Compare __comp)
{
    typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
    if (__libcpp_is_constant_evaluated()) {
        _VSTD::__partial_sort<_Comp_ref>(__first, __last, __last, _Comp_ref(__comp));
    } else {
        _VSTD::__sort<_Comp_ref>(_VSTD::__unwrap_iter(__first), _VSTD::__unwrap_iter(__last), _Comp_ref(__comp));
    }
}

template <class _RandomAccessIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
void
sort(_RandomAccessIterator __first, _RandomAccessIterator __last)
{
    _VSTD::sort(__first, __last, __less<typename iterator_traits<_RandomAccessIterator>::value_type>());
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_SORT_H
