/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


#ifndef ZIG_PARSEH_HPP
#define ZIG_PARSEH_HPP

#include "buffer.hpp"

#include <stdio.h>

void parse_h_file(const char *target_path, ZigList<const char *> *clang_argv, FILE *f);

#endif
