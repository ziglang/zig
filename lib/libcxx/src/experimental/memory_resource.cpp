//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <experimental/memory_resource>

#ifndef _LIBCPP_HAS_NO_ATOMIC_HEADER
#  include <atomic>
#elif !defined(_LIBCPP_HAS_NO_THREADS)
#  include <mutex>
#  if defined(__ELF__) && defined(_LIBCPP_LINK_PTHREAD_LIB)
#    pragma comment(lib, "pthread")
#  endif
#endif

_LIBCPP_BEGIN_NAMESPACE_LFTS_PMR

// memory_resource

//memory_resource::~memory_resource() {}

// new_delete_resource()

class _LIBCPP_TYPE_VIS __new_delete_memory_resource_imp
    : public memory_resource
{
    void *do_allocate(size_t size, size_t align) override {
#ifdef _LIBCPP_HAS_NO_ALIGNED_ALLOCATION
        if (__is_overaligned_for_new(align))
            __throw_bad_alloc();
#endif
        return _VSTD::__libcpp_allocate(size, align);
    }

    void do_deallocate(void *p, size_t n, size_t align) override {
      _VSTD::__libcpp_deallocate(p, n, align);
    }

    bool do_is_equal(memory_resource const & other) const noexcept override
        { return &other == this; }

public:
    ~__new_delete_memory_resource_imp() override = default;
};

// null_memory_resource()

class _LIBCPP_TYPE_VIS __null_memory_resource_imp
    : public memory_resource
{
public:
    ~__null_memory_resource_imp() = default;

protected:
    virtual void* do_allocate(size_t, size_t) {
        __throw_bad_alloc();
    }
    virtual void do_deallocate(void *, size_t, size_t) {}
    virtual bool do_is_equal(memory_resource const & __other) const noexcept
    { return &__other == this; }
};

namespace {

union ResourceInitHelper {
  struct {
    __new_delete_memory_resource_imp new_delete_res;
    __null_memory_resource_imp       null_res;
  } resources;
  char dummy;
  _LIBCPP_CONSTEXPR_AFTER_CXX11 ResourceInitHelper() : resources() {}
  ~ResourceInitHelper() {}
};

// Pretend we're inside a system header so the compiler doesn't flag the use of the init_priority
// attribute with a value that's reserved for the implementation (we're the implementation).
#include "memory_resource_init_helper.h"

} // end namespace


memory_resource * new_delete_resource() noexcept {
    return &res_init.resources.new_delete_res;
}

memory_resource * null_memory_resource() noexcept {
    return &res_init.resources.null_res;
}

// default_memory_resource()

static memory_resource *
__default_memory_resource(bool set = false, memory_resource * new_res = nullptr) noexcept
{
#ifndef _LIBCPP_HAS_NO_ATOMIC_HEADER
    static constinit atomic<memory_resource*> __res{&res_init.resources.new_delete_res};
    if (set) {
        new_res = new_res ? new_res : new_delete_resource();
        // TODO: Can a weaker ordering be used?
        return _VSTD::atomic_exchange_explicit(
            &__res, new_res, memory_order_acq_rel);
    }
    else {
        return _VSTD::atomic_load_explicit(
            &__res, memory_order_acquire);
    }
#elif !defined(_LIBCPP_HAS_NO_THREADS)
    static constinit memory_resource *res = &res_init.resources.new_delete_res;
    static mutex res_lock;
    if (set) {
        new_res = new_res ? new_res : new_delete_resource();
        lock_guard<mutex> guard(res_lock);
        memory_resource * old_res = res;
        res = new_res;
        return old_res;
    } else {
        lock_guard<mutex> guard(res_lock);
        return res;
    }
#else
    static constinit memory_resource *res = &res_init.resources.new_delete_res;
    if (set) {
        new_res = new_res ? new_res : new_delete_resource();
        memory_resource * old_res = res;
        res = new_res;
        return old_res;
    } else {
        return res;
    }
#endif
}

memory_resource * get_default_resource() noexcept
{
    return __default_memory_resource();
}

memory_resource * set_default_resource(memory_resource * __new_res) noexcept
{
    return __default_memory_resource(true, __new_res);
}

_LIBCPP_END_NAMESPACE_LFTS_PMR
