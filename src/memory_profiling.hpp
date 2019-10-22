/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_MEMORY_PROFILING_HPP
#define ZIG_MEMORY_PROFILING_HPP

#include "config.h"

#include <stddef.h>
#include <stdio.h>

void memprof_init(void);

void memprof_alloc(const char *name, size_t item_count, size_t type_size);
void memprof_dealloc(const char *name, size_t item_count, size_t type_size);

void memprof_dump_stats(FILE *file);
#endif
