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
#include "stage2.h"

#include <stdio.h>

CodeGen *codegen_create(Buf *main_pkg_path, Buf *root_src_path, const ZigTarget *target,
    BuildMode build_mode, Buf *zig_lib_dir, bool is_test_build);

void codegen_build_object(CodeGen *g);
void codegen_destroy(CodeGen *);

void codegen_add_time_event(CodeGen *g, const char *name);
void codegen_print_timing_report(CodeGen *g, FILE *f);

ZigPackage *codegen_create_package(CodeGen *g, const char *root_src_dir, const char *root_src_path,
        const char *pkg_path);

TargetSubsystem detect_subsystem(CodeGen *g);

bool codegen_fn_has_err_ret_tracing_arg(CodeGen *g, ZigType *return_type);
bool codegen_fn_has_err_ret_tracing_stack(CodeGen *g, ZigFn *fn, bool is_async);

ATTRIBUTE_NORETURN
void codegen_report_errors_and_exit(CodeGen *g);

void codegen_switch_sub_prog_node(CodeGen *g, Stage2ProgressNode *node);

#endif
