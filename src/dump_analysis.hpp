/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_DUMP_ANALYSIS_HPP
#define ZIG_DUMP_ANALYSIS_HPP

#include "all_types.hpp"
#include <stdio.h>

void zig_print_stack_report(CodeGen *g, FILE *f);
void zig_print_analysis_dump(CodeGen *g, FILE *f, const char *one_indent, const char *nl);

#endif
