/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_CODEGEN_HPP
#define ZIG_CODEGEN_HPP

#include "parser.hpp"
#include "errmsg.hpp"

CodeGen *codegen_create(Buf *root_source_dir);

void codegen_set_build_type(CodeGen *codegen, CodeGenBuildType build_type);
void codegen_set_is_static(CodeGen *codegen, bool is_static);
void codegen_set_strip(CodeGen *codegen, bool strip);
void codegen_set_verbose(CodeGen *codegen, bool verbose);
void codegen_set_errmsg_color(CodeGen *codegen, ErrColor err_color);
void codegen_set_out_type(CodeGen *codegen, OutType out_type);
void codegen_set_out_name(CodeGen *codegen, Buf *out_name);
void codegen_set_libc_path(CodeGen *codegen, Buf *libc_path);

void codegen_add_root_code(CodeGen *g, Buf *source_dir, Buf *source_basename, Buf *source_code);

void codegen_link(CodeGen *g, const char *out_file);

#endif
