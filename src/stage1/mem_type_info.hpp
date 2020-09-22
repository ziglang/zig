/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_MEM_TYPE_INFO_HPP
#define ZIG_MEM_TYPE_INFO_HPP

#include "config.h"

namespace mem {

struct TypeInfo {
    size_t size;
    size_t alignment;

    template <typename T>
    static constexpr TypeInfo make() {
        return {sizeof(T), alignof(T)};
    }
};

} // namespace mem

#endif
