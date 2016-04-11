/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_EVAL_HPP
#define ZIG_EVAL_HPP

#include "all_types.hpp"

bool eval_fn(CodeGen *g, AstNode *node, FnTableEntry *fn, ConstExprValue *out_val, int branch_quota,
        AstNode *struct_node);

bool const_values_equal(ConstExprValue *a, ConstExprValue *b, TypeTableEntry *type_entry);
void eval_const_expr_bin_op(ConstExprValue *op1_val, TypeTableEntry *op1_type,
        BinOpType bin_op, ConstExprValue *op2_val, TypeTableEntry *op2_type, ConstExprValue *out_val);

void eval_const_expr_implicit_cast(CastOp cast_op,
        ConstExprValue *other_val, TypeTableEntry *other_type,
        ConstExprValue *const_val);

#endif
