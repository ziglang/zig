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
#include "target.hpp"

#include <stdio.h>

CodeGen *codegen_create(Buf *root_src_path, const ZigTarget *target, OutType out_type, BuildMode build_mode,
    Buf *zig_lib_dir);
void codegen_destroy(CodeGen *codegen);

void codegen_set_clang_argv(CodeGen *codegen, const char **args, size_t len);
void codegen_set_llvm_argv(CodeGen *codegen, const char **args, size_t len);
void codegen_set_is_test(CodeGen *codegen, bool is_test);
void codegen_set_each_lib_rpath(CodeGen *codegen, bool each_lib_rpath);

void codegen_set_emit_file_type(CodeGen *g, EmitFileType emit_file_type);
void codegen_set_is_static(CodeGen *codegen, bool is_static);
void codegen_set_strip(CodeGen *codegen, bool strip);
void codegen_set_errmsg_color(CodeGen *codegen, ErrColor err_color);
void codegen_set_out_name(CodeGen *codegen, Buf *out_name);
void codegen_set_libc_lib_dir(CodeGen *codegen, Buf *libc_lib_dir);
void codegen_set_libc_static_lib_dir(CodeGen *g, Buf *libc_static_lib_dir);
void codegen_set_libc_include_dir(CodeGen *codegen, Buf *libc_include_dir);
void codegen_set_msvc_lib_dir(CodeGen *g, Buf *msvc_lib_dir);
void codegen_set_kernel32_lib_dir(CodeGen *codegen, Buf *kernel32_lib_dir);
void codegen_set_dynamic_linker(CodeGen *g, Buf *dynamic_linker);
void codegen_set_windows_subsystem(CodeGen *g, bool mwindows, bool mconsole);
void codegen_add_lib_dir(CodeGen *codegen, const char *dir);
void codegen_add_forbidden_lib(CodeGen *codegen, Buf *lib);
LinkLib *codegen_add_link_lib(CodeGen *codegen, Buf *lib);
void codegen_add_framework(CodeGen *codegen, const char *name);
void codegen_add_rpath(CodeGen *codegen, const char *name);
void codegen_set_rdynamic(CodeGen *g, bool rdynamic);
void codegen_set_mmacosx_version_min(CodeGen *g, Buf *mmacosx_version_min);
void codegen_set_mios_version_min(CodeGen *g, Buf *mios_version_min);
void codegen_set_linker_script(CodeGen *g, const char *linker_script);
void codegen_set_test_filter(CodeGen *g, Buf *filter);
void codegen_set_test_name_prefix(CodeGen *g, Buf *prefix);
void codegen_set_lib_version(CodeGen *g, size_t major, size_t minor, size_t patch);
void codegen_set_cache_dir(CodeGen *g, Buf *cache_dir);
void codegen_set_output_h_path(CodeGen *g, Buf *h_path);
void codegen_add_time_event(CodeGen *g, const char *name);
void codegen_print_timing_report(CodeGen *g, FILE *f);
void codegen_build(CodeGen *g);

PackageTableEntry *codegen_create_package(CodeGen *g, const char *root_src_dir, const char *root_src_path);
void codegen_add_assembly(CodeGen *g, Buf *path);
void codegen_add_object(CodeGen *g, Buf *object_path);

void codegen_translate_c(CodeGen *g, Buf *path);

Buf *codegen_generate_builtin_source(CodeGen *g);


#endif
