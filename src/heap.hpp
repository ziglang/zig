/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_HEAP_HPP
#define ZIG_HEAP_HPP

#include "config.h"
#include "util_base.hpp"
#include "mem.hpp"

namespace heap {

struct BootstrapAllocator final : mem::Allocator {
    void init(const char *name);
    void deinit();
    void destruct(Allocator *allocator) {}

private:
    ATTRIBUTE_RETURNS_NOALIAS void *internal_allocate(const mem::TypeInfo &info, size_t count) final;
    ATTRIBUTE_RETURNS_NOALIAS void *internal_allocate_nonzero(const mem::TypeInfo &info, size_t count) final;
    void *internal_reallocate(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) final;
    void *internal_reallocate_nonzero(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) final;
    void internal_deallocate(const mem::TypeInfo &info, void *ptr, size_t count) final;
};

struct CAllocator final : mem::Allocator {
    void init(const char *name);
    void deinit();

    static CAllocator *construct(mem::Allocator *allocator, const char *name);
    void destruct(mem::Allocator *allocator) final;


private:
    ATTRIBUTE_RETURNS_NOALIAS void *internal_allocate(const mem::TypeInfo &info, size_t count) final;
    ATTRIBUTE_RETURNS_NOALIAS void *internal_allocate_nonzero(const mem::TypeInfo &info, size_t count) final;
    void *internal_reallocate(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) final;
    void *internal_reallocate_nonzero(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) final;
    void internal_deallocate(const mem::TypeInfo &info, void *ptr, size_t count) final;

};

//
// arena allocator
//
// - allocations are backed by the underlying allocator's memory
// - allocations are N:1 relationship to underlying allocations
// - dellocations are noops
// - deinit() releases all underlying memory
//
struct ArenaAllocator final : mem::Allocator {
    void init(Allocator *backing, const char *name);
    void deinit();

    static ArenaAllocator *construct(mem::Allocator *allocator, mem::Allocator *backing, const char *name);
    void destruct(mem::Allocator *allocator) final;


private:
    ATTRIBUTE_RETURNS_NOALIAS void *internal_allocate(const mem::TypeInfo &info, size_t count) final;
    ATTRIBUTE_RETURNS_NOALIAS void *internal_allocate_nonzero(const mem::TypeInfo &info, size_t count) final;
    void *internal_reallocate(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) final;
    void *internal_reallocate_nonzero(const mem::TypeInfo &info, void *old_ptr, size_t old_count, size_t new_count) final;
    void internal_deallocate(const mem::TypeInfo &info, void *ptr, size_t count) final;

    struct Impl;
    Impl *impl;
};

extern BootstrapAllocator bootstrap_allocator_state;
extern mem::Allocator &bootstrap_allocator;

extern CAllocator c_allocator_state;
extern mem::Allocator &c_allocator;

} // namespace heap

#endif
