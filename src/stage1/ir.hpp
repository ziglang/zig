/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_IR_HPP
#define ZIG_IR_HPP

#include "all_types.hpp"

Stage1AirInst *ir_create_alloca(CodeGen *g, Scope *scope, AstNode *source_node, ZigFn *fn,
        ZigType *var_type, const char *name_hint);

Error ir_eval_const_value(CodeGen *codegen, Scope *scope, AstNode *node,
        ZigValue *return_ptr, size_t *backward_branch_count, size_t *backward_branch_quota,
        ZigFn *fn_entry, Buf *c_import_buf, AstNode *source_node, Buf *exec_name,
        Stage1Air *parent_exec, AstNode *expected_type_source_node, UndefAllowed undef);

Error ir_resolve_lazy(CodeGen *codegen, AstNode *source_node, ZigValue *val);

ZigType *ir_analyze(CodeGen *codegen, Stage1Zir *stage1_zir, Stage1Air *stage1_air,
        size_t *backward_branch_count, size_t *backward_branch_quota,
        ZigType *expected_type, AstNode *expected_type_source_node, ZigValue *result_ptr,
        ZigFn *fn);

bool ir_inst_gen_has_side_effects(Stage1AirInst *inst);

struct IrAnalyze;
ZigValue *const_ptr_pointee(IrAnalyze *ira, CodeGen *codegen, ZigValue *const_val,
        AstNode *source_node);

#endif
