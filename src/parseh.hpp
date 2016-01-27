/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


#ifndef ZIG_PARSEH_HPP
#define ZIG_PARSEH_HPP

#include "all_types.hpp"

int parse_h_file(ParseH *parse_h, ZigList<const char *> *clang_argv);
int parse_h_buf(ParseH *parse_h, Buf *buf, const char *libc_include_path);

#endif
