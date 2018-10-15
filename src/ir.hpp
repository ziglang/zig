/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_IR_HPP
#define ZIG_IR_HPP

#include "all_types.hpp"

bool ir_gen(CodeGen *g, AstNode *node, Scope *scope, IrExecutable *ir_executable);
bool ir_gen_fn(CodeGen *g, ZigFn *fn_entry);

IrInstruction *ir_eval_const_value(CodeGen *codegen, Scope *scope, AstNode *node,
        ZigType *expected_type, size_t *backward_branch_count, size_t backward_branch_quota,
        ZigFn *fn_entry, Buf *c_import_buf, AstNode *source_node, Buf *exec_name,
        IrExecutable *parent_exec);

ZigType *ir_analyze(CodeGen *g, IrExecutable *old_executable, IrExecutable *new_executable,
        ZigType *expected_type, AstNode *expected_type_source_node);

bool ir_has_side_effects(IrInstruction *instruction);
ConstExprValue *const_ptr_pointee(CodeGen *codegen, ConstExprValue *const_val);

IrResultLocation *ir_get_result_location(IrInstruction *base);

#endif
