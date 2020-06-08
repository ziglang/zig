/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_IR_HPP
#define ZIG_IR_HPP

#include "all_types.hpp"

bool ir_gen(CodeGen *g, AstNode *node, Scope *scope, IrExecutableSrc *ir_executable);
bool ir_gen_fn(CodeGen *g, ZigFn *fn_entry);

IrInstGen *ir_create_alloca(CodeGen *g, Scope *scope, AstNode *source_node, ZigFn *fn,
        ZigType *var_type, const char *name_hint);

Error ir_eval_const_value(CodeGen *codegen, Scope *scope, AstNode *node,
        ZigValue *return_ptr, size_t *backward_branch_count, size_t *backward_branch_quota,
        ZigFn *fn_entry, Buf *c_import_buf, AstNode *source_node, Buf *exec_name,
        IrExecutableGen *parent_exec, AstNode *expected_type_source_node, UndefAllowed undef);

Error ir_resolve_lazy(CodeGen *codegen, AstNode *source_node, ZigValue *val);

ZigType *ir_analyze(CodeGen *g, IrExecutableSrc *old_executable, IrExecutableGen *new_executable,
        ZigType *expected_type, AstNode *expected_type_source_node, ZigValue *return_ptr);

bool ir_inst_gen_has_side_effects(IrInstGen *inst);
bool ir_inst_src_has_side_effects(IrInstSrc *inst);

struct IrAnalyze;
ZigValue *const_ptr_pointee(IrAnalyze *ira, CodeGen *codegen, ZigValue *const_val,
        AstNode *source_node);

// for debugging purposes
void dbg_ir_break(const char *src_file, uint32_t line);
void dbg_ir_clear(void);

#endif
