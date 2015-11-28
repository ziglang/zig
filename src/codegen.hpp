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

enum OutType {
    OutTypeUnknown,
    OutTypeExe,
    OutTypeLib,
    OutTypeObj,
};


struct ErrorMsg {
    int line_start;
    int column_start;
    int line_end;
    int column_end;
    Buf *msg;
};


CodeGen *create_codegen(AstNode *root, Buf *in_file);

enum CodeGenBuildType {
    CodeGenBuildTypeDebug,
    CodeGenBuildTypeRelease,
};
void codegen_set_build_type(CodeGen *codegen, CodeGenBuildType build_type);
void codegen_set_is_static(CodeGen *codegen, bool is_static);
void codegen_set_strip(CodeGen *codegen, bool strip);
void codegen_set_out_type(CodeGen *codegen, OutType out_type);
void codegen_set_out_name(CodeGen *codegen, Buf *out_name);

void semantic_analyze(CodeGen *g);

void code_gen_optimize(CodeGen *g);

void code_gen(CodeGen *g);

void code_gen_link(CodeGen *g, const char *out_file);

ZigList<ErrorMsg> *codegen_error_messages(CodeGen *g);

#endif
