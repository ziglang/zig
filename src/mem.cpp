/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "config.h"
#include "mem.hpp"
#include "heap.hpp"

namespace mem {

void init() {
    heap::bootstrap_allocator_state.init("heap::bootstrap_allocator");
    heap::c_allocator_state.init("heap::c_allocator");
}

void deinit() {
    heap::c_allocator_state.deinit();
    heap::bootstrap_allocator_state.deinit();
}

} // namespace mem
