/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


#ifndef ZIG_PARSEH_HPP
#define ZIG_PARSEH_HPP

#include "all_types.hpp"

int parse_h_file(ImportTableEntry *out_import, ZigList<ErrorMsg *> *out_errs,
        ZigList<const char *> *clang_argv, bool warnings_on, uint32_t *next_node_index);
int parse_h_buf(ImportTableEntry *out_import, ZigList<ErrorMsg *> *out_errs,
        Buf *source, const char **args, int args_len, const char *libc_include_path,
        bool warnings_on, uint32_t *next_node_index);

#endif
