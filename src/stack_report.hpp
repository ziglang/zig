/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_STACK_REPORT_HPP
#define ZIG_STACK_REPORT_HPP

#include "all_types.hpp"
#include <stdio.h>

void zig_print_stack_report(CodeGen *g, FILE *f);

#endif
