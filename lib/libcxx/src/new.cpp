//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <stdlib.h>

#include "new"
#include "include/atomic_support.h"

#if defined(_LIBCPP_ABI_MICROSOFT)
#   if !defined(_LIBCPP_ABI_VCRUNTIME)
#       include "support/runtime/new_handler_fallback.ipp"
#   endif
#elif defined(LIBCXX_BUILDING_LIBCXXABI)
#   include <cxxabi.h>
#elif defined(LIBCXXRT)
#   include <cxxabi.h>
#   include "support/runtime/new_handler_fallback.ipp"
#elif defined(__GLIBCXX__)
    // nothing to do
#else
#   include "support/runtime/new_handler_fallback.ipp"
#endif

namespace std
{

#ifndef __GLIBCXX__
const nothrow_t nothrow{};
#endif

#ifndef LIBSTDCXX

void
__throw_bad_alloc()
{
#ifndef _LIBCPP_NO_EXCEPTIONS
    throw bad_alloc();
#else
    _VSTD::abort();
#endif
}

#endif // !LIBSTDCXX

}  // std

#if !defined(__GLIBCXX__) &&                                                   \
    !defined(_LIBCPP_ABI_VCRUNTIME) &&      \
    !defined(_LIBCPP_DISABLE_NEW_DELETE_DEFINITIONS)

// Implement all new and delete operators as weak definitions
// in this shared library, so that they can be overridden by programs
// that define non-weak copies of the functions.

_LIBCPP_WEAK
void *
operator new(std::size_t size) _THROW_BAD_ALLOC
{
    if (size == 0)
        size = 1;
    void* p;
    while ((p = ::malloc(size)) == nullptr)
    {
        // If malloc fails and there is a new_handler,
        // call it to try free up memory.
        std::new_handler nh = std::get_new_handler();
        if (nh)
            nh();
        else
#ifndef _LIBCPP_NO_EXCEPTIONS
            throw std::bad_alloc();
#else
            break;
#endif
    }
    return p;
}

_LIBCPP_WEAK
void*
operator new(size_t size, const std::nothrow_t&) noexcept
{
    void* p = nullptr;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try
    {
#endif // _LIBCPP_NO_EXCEPTIONS
        p = ::operator new(size);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
    }
#endif // _LIBCPP_NO_EXCEPTIONS
    return p;
}

_LIBCPP_WEAK
void*
operator new[](size_t size) _THROW_BAD_ALLOC
{
    return ::operator new(size);
}

_LIBCPP_WEAK
void*
operator new[](size_t size, const std::nothrow_t&) noexcept
{
    void* p = nullptr;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try
    {
#endif // _LIBCPP_NO_EXCEPTIONS
        p = ::operator new[](size);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
    }
#endif // _LIBCPP_NO_EXCEPTIONS
    return p;
}

_LIBCPP_WEAK
void
operator delete(void* ptr) noexcept
{
    ::free(ptr);
}

_LIBCPP_WEAK
void
operator delete(void* ptr, const std::nothrow_t&) noexcept
{
    ::operator delete(ptr);
}

_LIBCPP_WEAK
void
operator delete(void* ptr, size_t) noexcept
{
    ::operator delete(ptr);
}

_LIBCPP_WEAK
void
operator delete[] (void* ptr) noexcept
{
    ::operator delete(ptr);
}

_LIBCPP_WEAK
void
operator delete[] (void* ptr, const std::nothrow_t&) noexcept
{
    ::operator delete[](ptr);
}

_LIBCPP_WEAK
void
operator delete[] (void* ptr, size_t) noexcept
{
    ::operator delete[](ptr);
}

#if !defined(_LIBCPP_HAS_NO_LIBRARY_ALIGNED_ALLOCATION)

_LIBCPP_WEAK
void *
operator new(std::size_t size, std::align_val_t alignment) _THROW_BAD_ALLOC
{
    if (size == 0)
        size = 1;
    if (static_cast<size_t>(alignment) < sizeof(void*))
      alignment = std::align_val_t(sizeof(void*));

    // Try allocating memory. If allocation fails and there is a new_handler,
    // call it to try free up memory, and try again until it succeeds, or until
    // the new_handler decides to terminate.
    //
    // If allocation fails and there is no new_handler, we throw bad_alloc
    // (or return nullptr if exceptions are disabled).
    void* p;
    while ((p = std::__libcpp_aligned_alloc(static_cast<std::size_t>(alignment), size)) == nullptr)
    {
        std::new_handler nh = std::get_new_handler();
        if (nh)
            nh();
        else {
#ifndef _LIBCPP_NO_EXCEPTIONS
            throw std::bad_alloc();
#else
            break;
#endif
        }
    }
    return p;
}

_LIBCPP_WEAK
void*
operator new(size_t size, std::align_val_t alignment, const std::nothrow_t&) noexcept
{
    void* p = nullptr;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try
    {
#endif // _LIBCPP_NO_EXCEPTIONS
        p = ::operator new(size, alignment);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
    }
#endif // _LIBCPP_NO_EXCEPTIONS
    return p;
}

_LIBCPP_WEAK
void*
operator new[](size_t size, std::align_val_t alignment) _THROW_BAD_ALLOC
{
    return ::operator new(size, alignment);
}

_LIBCPP_WEAK
void*
operator new[](size_t size, std::align_val_t alignment, const std::nothrow_t&) noexcept
{
    void* p = nullptr;
#ifndef _LIBCPP_NO_EXCEPTIONS
    try
    {
#endif // _LIBCPP_NO_EXCEPTIONS
        p = ::operator new[](size, alignment);
#ifndef _LIBCPP_NO_EXCEPTIONS
    }
    catch (...)
    {
    }
#endif // _LIBCPP_NO_EXCEPTIONS
    return p;
}

_LIBCPP_WEAK
void
operator delete(void* ptr, std::align_val_t) noexcept
{
    std::__libcpp_aligned_free(ptr);
}

_LIBCPP_WEAK
void
operator delete(void* ptr, std::align_val_t alignment, const std::nothrow_t&) noexcept
{
    ::operator delete(ptr, alignment);
}

_LIBCPP_WEAK
void
operator delete(void* ptr, size_t, std::align_val_t alignment) noexcept
{
    ::operator delete(ptr, alignment);
}

_LIBCPP_WEAK
void
operator delete[] (void* ptr, std::align_val_t alignment) noexcept
{
    ::operator delete(ptr, alignment);
}

_LIBCPP_WEAK
void
operator delete[] (void* ptr, std::align_val_t alignment, const std::nothrow_t&) noexcept
{
    ::operator delete[](ptr, alignment);
}

_LIBCPP_WEAK
void
operator delete[] (void* ptr, size_t, std::align_val_t alignment) noexcept
{
    ::operator delete[](ptr, alignment);
}

#endif // !_LIBCPP_HAS_NO_LIBRARY_ALIGNED_ALLOCATION
#endif // !__GLIBCXX__ && !_LIBCPP_ABI_VCRUNTIME && !_LIBCPP_DISABLE_NEW_DELETE_DEFINITIONS
