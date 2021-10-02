// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_SSO_ALLOCATOR_H
#define _LIBCPP_SSO_ALLOCATOR_H

#include <__config>
#include <memory>
#include <new>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp, size_t _Np> class _LIBCPP_HIDDEN __sso_allocator;

template <size_t _Np>
class _LIBCPP_HIDDEN __sso_allocator<void, _Np>
{
public:
    typedef const void*       const_pointer;
    typedef void              value_type;
};

template <class _Tp, size_t _Np>
class _LIBCPP_HIDDEN __sso_allocator
{
    typename aligned_storage<sizeof(_Tp) * _Np>::type buf_;
    bool __allocated_;
public:
    typedef size_t            size_type;
    typedef _Tp*              pointer;
    typedef _Tp               value_type;

    _LIBCPP_INLINE_VISIBILITY __sso_allocator() throw() : __allocated_(false) {}
    _LIBCPP_INLINE_VISIBILITY __sso_allocator(const __sso_allocator&) throw() : __allocated_(false) {}
    template <class _Up> _LIBCPP_INLINE_VISIBILITY __sso_allocator(const __sso_allocator<_Up, _Np>&) throw()
         : __allocated_(false) {}
private:
    __sso_allocator& operator=(const __sso_allocator&);
public:
    _LIBCPP_INLINE_VISIBILITY pointer allocate(size_type __n, typename __sso_allocator<void, _Np>::const_pointer = nullptr)
    {
        if (!__allocated_ && __n <= _Np)
        {
            __allocated_ = true;
            return (pointer)&buf_;
        }
        return allocator<_Tp>().allocate(__n);
    }
    _LIBCPP_INLINE_VISIBILITY void deallocate(pointer __p, size_type __n)
    {
        if (__p == (pointer)&buf_)
            __allocated_ = false;
        else
            allocator<_Tp>().deallocate(__p, __n);
    }
    _LIBCPP_INLINE_VISIBILITY size_type max_size() const throw() {return size_type(~0) / sizeof(_Tp);}

    _LIBCPP_INLINE_VISIBILITY
    bool operator==(const __sso_allocator& __a) const {return &buf_ == &__a.buf_;}
    _LIBCPP_INLINE_VISIBILITY
    bool operator!=(const __sso_allocator& __a) const {return &buf_ != &__a.buf_;}
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_SSO_ALLOCATOR_H
