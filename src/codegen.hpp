/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_CODEGEN_HPP
#define ZIG_CODEGEN_HPP

#include "parser.hpp"

struct CodeGen;

struct ErrorMsg {
    int line_start;
    int column_start;
    int line_end;
    int column_end;
    Buf *msg;
};


CodeGen *create_codegen(AstNode *root);

void semantic_analyze(CodeGen *g);

void code_gen(CodeGen *g);

void code_gen_link(CodeGen *g, bool is_static, const char *out_file);

ZigList<ErrorMsg> *codegen_error_messages(CodeGen *g);

#endif
