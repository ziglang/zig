/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "config.h"
#include "mem.hpp"
#include "mem_profile.hpp"
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

#ifdef ZIG_ENABLE_MEM_PROFILE
void print_report(FILE *file) {
    heap::c_allocator_state.print_report(file);
    intern_counters.print_report(file);
}
#endif

#ifdef ZIG_ENABLE_MEM_PROFILE
bool report_print = false;
FILE *report_file{nullptr};
#endif

} // namespace mem
