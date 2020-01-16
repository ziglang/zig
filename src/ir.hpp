/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_IR_HPP
#define ZIG_IR_HPP

#include "all_types.hpp"

enum IrPass {
    IrPassSrc,
    IrPassGen,
};

bool ir_gen(CodeGen *g, AstNode *node, Scope *scope, IrExecutable *ir_executable);
bool ir_gen_fn(CodeGen *g, ZigFn *fn_entry);

ZigValue *ir_eval_const_value(CodeGen *codegen, Scope *scope, AstNode *node,
        ZigType *expected_type, size_t *backward_branch_count, size_t *backward_branch_quota,
        ZigFn *fn_entry, Buf *c_import_buf, AstNode *source_node, Buf *exec_name,
        IrExecutable *parent_exec, AstNode *expected_type_source_node, UndefAllowed undef);

Error ir_resolve_lazy(CodeGen *codegen, AstNode *source_node, ZigValue *val);

ZigType *ir_analyze(CodeGen *g, IrExecutable *old_executable, IrExecutable *new_executable,
        ZigType *expected_type, AstNode *expected_type_source_node);

bool ir_has_side_effects(IrInstruction *instruction);

struct IrAnalyze;
ZigValue *const_ptr_pointee(IrAnalyze *ira, CodeGen *codegen, ZigValue *const_val,
        AstNode *source_node);
const char *float_op_to_name(BuiltinFnId op);

// for debugging purposes
void dbg_ir_break(const char *src_file, uint32_t line);
void dbg_ir_clear(void);

#endif
