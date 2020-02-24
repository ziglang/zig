/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_MEM_PROFILE_HPP
#define ZIG_MEM_PROFILE_HPP

#include "config.h"

#ifdef ZIG_ENABLE_MEM_PROFILE

#include <stdio.h>

#include "mem.hpp"
#include "mem_hash_map.hpp"
#include "util.hpp"

namespace mem {

struct Profile {
    void init(const char *name, const char *kind);
    void deinit();

    void record_alloc(const TypeInfo &info, size_t count);
    void record_dealloc(const TypeInfo &info, size_t count);

    void print_report(FILE *file = nullptr);

    struct Entry {
        TypeInfo info;

        struct Use {
            size_t calls;
            size_t objects;
        } alloc, dealloc;
    };

private:
    const char *name;
    const char *kind;

    struct UsageKey {
        const char *name_ptr;
        size_t name_len;
    };

    static uint32_t usage_hash(UsageKey key);
    static bool usage_equal(UsageKey a, UsageKey b);

    HashMap<UsageKey, Entry, usage_hash, usage_equal> usage_table;
};

struct InternCounters {
    size_t x_undefined;
    size_t x_void;
    size_t x_null;
    size_t x_unreachable;
    size_t zero_byte;

    void print_report(FILE *file = nullptr);
};

extern InternCounters intern_counters;

} // namespace mem

#endif
#endif
