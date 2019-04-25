/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_AST_RENDER_HPP
#define ZIG_AST_RENDER_HPP

#include "all_types.hpp"
#include "parser.hpp"

#include <stdio.h>

void ast_print(FILE *f, AstNode *node, int indent);

void ast_render(FILE *f, AstNode *node, int indent_size);

#endif
