/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_METADATA_RENDER_HPP
#define ZIG_METADATA_RENDER_HPP

#include "all_types.hpp"
#include "parser.hpp"

#include <stdio.h>

void metadata_print(CodeGen* codegen, FILE *f, AstNode *node, const char* filename);

#endif

