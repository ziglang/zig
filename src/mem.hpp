/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_MEM_HPP
#define ZIG_MEM_HPP

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "config.h"
#include "util_base.hpp"
#include "mem_type_info.hpp"

//
// -- Memory Allocation General Notes --
//
// `heap::c_allocator` is the preferred general allocator.
//
// `heap::bootstrap_allocator` is an implementation detail for use
// by allocators themselves when incidental heap may be required for
// profiling and statistics. It breaks the infinite recursion cycle.
//
// `mem::os` contains a raw wrapper for system malloc API used in
// preference to calling ::{malloc, free, calloc, realloc} directly.
// This isolates usage and helps with audits:
//
//      mem::os::malloc
//      mem::os::free
//      mem::os::calloc
//      mem::os::realloc
//
namespace mem {

// initialize mem module before any use
void init();

// deinitialize mem module to free memory and print report
void deinit();

// isolate system/libc allocators
namespace os {

ATTRIBUTE_RETURNS_NOALIAS
inline void *malloc(size_t size) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (size == 0)
        return nullptr;
#endif
    auto ptr = ::malloc(size);
    if (ptr == nullptr)
        zig_panic("allocation failed");
    return ptr;
}

inline void free(void *ptr) {
    ::free(ptr);
}

ATTRIBUTE_RETURNS_NOALIAS
inline void *calloc(size_t count, size_t size) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (count == 0 || size == 0)
        return nullptr;
#endif
    auto ptr = ::calloc(count, size);
    if (ptr == nullptr)
        zig_panic("allocation failed");
    return ptr;
}

inline void *realloc(void *old_ptr, size_t size) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (old_ptr == nullptr && size == 0)
        return nullptr;
#endif
    auto ptr = ::realloc(old_ptr, size);
    if (ptr == nullptr)
        zig_panic("allocation failed");
    return ptr;
}

} // namespace os

struct Allocator {
    virtual void destruct(Allocator *allocator) = 0;

    template <typename T> ATTRIBUTE_RETURNS_NOALIAS
    T *allocate(size_t count) {
        return reinterpret_cast<T *>(this->internal_allocate(TypeInfo::make<T>(), count));
    }

    template <typename T> ATTRIBUTE_RETURNS_NOALIAS
    T *allocate_nonzero(size_t count) {
        return reinterpret_cast<T *>(this->internal_allocate_nonzero(TypeInfo::make<T>(), count));
    }

    template <typename T>
    T *reallocate(T *old_ptr, size_t old_count, size_t new_count) {
        return reinterpret_cast<T *>(this->internal_reallocate(TypeInfo::make<T>(), old_ptr, old_count, new_count));
    }

    template <typename T>
    T *reallocate_nonzero(T *old_ptr, size_t old_count, size_t new_count) {
        return reinterpret_cast<T *>(this->internal_reallocate_nonzero(TypeInfo::make<T>(), old_ptr, old_count, new_count));
    }

    template<typename T>
    void deallocate(T *ptr, size_t count) {
        this->internal_deallocate(TypeInfo::make<T>(), ptr, count);
    }

    template<typename T>
    T *create() {
        return reinterpret_cast<T *>(this->internal_allocate(TypeInfo::make<T>(), 1));
    }

    template<typename T>
    void destroy(T *ptr) {
        this->internal_deallocate(TypeInfo::make<T>(), ptr, 1);
    }

protected:
    ATTRIBUTE_RETURNS_NOALIAS virtual void *internal_allocate(const TypeInfo &info, size_t count) = 0;
    ATTRIBUTE_RETURNS_NOALIAS virtual void *internal_allocate_nonzero(const TypeInfo &info, size_t count) = 0;
    virtual void *internal_reallocate(const TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) = 0;
    virtual void *internal_reallocate_nonzero(const TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) = 0;
    virtual void internal_deallocate(const TypeInfo &info, void *ptr, size_t count) = 0;
};

} // namespace mem

#endif
