/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_IR_PRINT_HPP
#define ZIG_IR_PRINT_HPP

#include "all_types.hpp"

#include <stdio.h>

void ir_print(FILE *f, IrExecutable *executable, int indent_size);

#endif
