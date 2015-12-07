/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "codegen.hpp"
#include "hash_map.hpp"
#include "zig_llvm.hpp"
#include "os.hpp"
#include "config.h"
#include "error.hpp"
#include "semantic_info.hpp"
#include "analyze.hpp"
#include "errmsg.hpp"

#include <stdio.h>
#include <errno.h>

CodeGen *codegen_create(Buf *root_source_dir) {
    CodeGen *g = allocate<CodeGen>(1);
    g->fn_table.init(32);
    g->str_table.init(32);
    g->type_table.init(32);
    g->link_table.init(32);
    g->import_table.init(32);
    g->build_type = CodeGenBuildTypeDebug;
    g->root_source_dir = root_source_dir;
    return g;
}

void codegen_set_build_type(CodeGen *g, CodeGenBuildType build_type) {
    g->build_type = build_type;
}

void codegen_set_is_static(CodeGen *g, bool is_static) {
    g->is_static = is_static;
}

void codegen_set_verbose(CodeGen *g, bool verbose) {
    g->verbose = verbose;
}

void codegen_set_errmsg_color(CodeGen *g, ErrColor err_color) {
    g->err_color = err_color;
}

void codegen_set_strip(CodeGen *g, bool strip) {
    g->strip_debug_symbols = strip;
}

void codegen_set_out_type(CodeGen *g, OutType out_type) {
    g->out_type = out_type;
}

void codegen_set_out_name(CodeGen *g, Buf *out_name) {
    g->root_out_name = out_name;
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *expr_node);

static LLVMTypeRef to_llvm_type(AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);
    assert(type_node->codegen_node->data.type_node.entry);

    return type_node->codegen_node->data.type_node.entry->type_ref;
}

static LLVMZigDIType *to_llvm_debug_type(AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);
    assert(type_node->codegen_node->data.type_node.entry);

    return type_node->codegen_node->data.type_node.entry->di_type;
}

static TypeTableEntry *get_type_for_type_node(CodeGen *g, AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);
    assert(type_node->codegen_node->data.type_node.entry);
    return type_node->codegen_node->data.type_node.entry;
}

static bool type_is_unreachable(CodeGen *g, AstNode *type_node) {
    return get_type_for_type_node(g, type_node) == g->builtin_types.entry_unreachable;
}

static bool is_param_decl_type_void(CodeGen *g, AstNode *param_decl_node) {
    assert(param_decl_node->type == NodeTypeParamDecl);
    return get_type_for_type_node(g, param_decl_node->data.param_decl.type) == g->builtin_types.entry_void;
}

static int count_non_void_params(CodeGen *g, ZigList<AstNode *> *params) {
    int result = 0;
    for (int i = 0; i < params->length; i += 1) {
        if (!is_param_decl_type_void(g, params->at(i)))
            result += 1;
    }
    return result;
}

static void add_debug_source_node(CodeGen *g, AstNode *node) {
    // TODO g->block_scopes.last() is not always correct and should probably integrate with BlockContext
    LLVMZigSetCurrentDebugLocation(g->builder, node->line + 1, node->column + 1, g->block_scopes.last());
}

static LLVMValueRef find_or_create_string(CodeGen *g, Buf *str) {
    auto entry = g->str_table.maybe_get(str);
    if (entry) {
        return entry->value;
    }
    LLVMValueRef text = LLVMConstString(buf_ptr(str), buf_len(str), false);
    LLVMValueRef global_value = LLVMAddGlobal(g->module, LLVMTypeOf(text), "");
    LLVMSetLinkage(global_value, LLVMPrivateLinkage);
    LLVMSetInitializer(global_value, text);
    LLVMSetGlobalConstant(global_value, true);
    LLVMSetUnnamedAddr(global_value, true);
    g->str_table.put(str, global_value);

    return global_value;
}

static TypeTableEntry *get_expr_type(AstNode *node) {
    return node->codegen_node->expr_node.type_entry;
}

static LLVMValueRef gen_fn_call_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    Buf *name = hack_get_fn_call_name(g, node->data.fn_call_expr.fn_ref_expr);

    FnTableEntry *fn_table_entry;
    auto entry = g->cur_fn->import_entry->fn_table.maybe_get(name);
    if (entry)
        fn_table_entry = entry->value;
    else
        fn_table_entry = g->fn_table.get(name);

    assert(fn_table_entry->proto_node->type == NodeTypeFnProto);
    int expected_param_count = fn_table_entry->proto_node->data.fn_proto.params.length;
    int actual_param_count = node->data.fn_call_expr.params.length;
    assert(expected_param_count == actual_param_count);

    // don't really include void values
    int gen_param_count = count_non_void_params(g, &fn_table_entry->proto_node->data.fn_proto.params);
    LLVMValueRef *gen_param_values = allocate<LLVMValueRef>(gen_param_count);

    int gen_param_index = 0;
    for (int i = 0; i < actual_param_count; i += 1) {
        AstNode *expr_node = node->data.fn_call_expr.params.at(i);
        LLVMValueRef param_value = gen_expr(g, expr_node);
        if (!is_param_decl_type_void(g, fn_table_entry->proto_node->data.fn_proto.params.at(i))) {
            gen_param_values[gen_param_index] = param_value;
            gen_param_index += 1;
        }
    }

    add_debug_source_node(g, node);
    LLVMValueRef result = LLVMZigBuildCall(g->builder, fn_table_entry->fn_value,
            gen_param_values, gen_param_count, fn_table_entry->calling_convention, "");

    if (type_is_unreachable(g, fn_table_entry->proto_node->data.fn_proto.return_type)) {
        return LLVMBuildUnreachable(g->builder);
    } else {
        return result;
    }
}

static LLVMValueRef gen_prefix_op_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypePrefixOpExpr);
    assert(node->data.prefix_op_expr.primary_expr);

    LLVMValueRef expr = gen_expr(g, node->data.prefix_op_expr.primary_expr);

    switch (node->data.prefix_op_expr.prefix_op) {
        case PrefixOpNegation:
            add_debug_source_node(g, node);
            return LLVMBuildNeg(g->builder, expr, "");
        case PrefixOpBoolNot:
            {
                LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(expr));
                add_debug_source_node(g, node);
                return LLVMBuildICmp(g->builder, LLVMIntEQ, expr, zero, "");
            }
        case PrefixOpBinNot:
            add_debug_source_node(g, node);
            return LLVMBuildNot(g->builder, expr, "");
        case PrefixOpInvalid:
            zig_unreachable();
    }
    zig_unreachable();
}

static LLVMValueRef gen_cast_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeCastExpr);

    LLVMValueRef expr = gen_expr(g, node->data.cast_expr.prefix_op_expr);

    if (!node->data.cast_expr.type)
        return expr;

    zig_panic("TODO cast expression");
}

static LLVMValueRef gen_arithmetic_bin_op_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeAssign:
            zig_panic("TODO assignment");
        case BinOpTypeBinOr:
            add_debug_source_node(g, node);
            return LLVMBuildOr(g->builder, val1, val2, "");
        case BinOpTypeBinXor:
            add_debug_source_node(g, node);
            return LLVMBuildXor(g->builder, val1, val2, "");
        case BinOpTypeBinAnd:
            add_debug_source_node(g, node);
            return LLVMBuildAnd(g->builder, val1, val2, "");
        case BinOpTypeBitShiftLeft:
            add_debug_source_node(g, node);
            return LLVMBuildShl(g->builder, val1, val2, "");
        case BinOpTypeBitShiftRight:
            // TODO implement type system so that we know whether to do
            // logical or arithmetic shifting here.
            // signed -> arithmetic, unsigned -> logical
            add_debug_source_node(g, node);
            return LLVMBuildLShr(g->builder, val1, val2, "");
        case BinOpTypeAdd:
            add_debug_source_node(g, node);
            return LLVMBuildAdd(g->builder, val1, val2, "");
        case BinOpTypeSub:
            add_debug_source_node(g, node);
            return LLVMBuildSub(g->builder, val1, val2, "");
        case BinOpTypeMult:
            // TODO types so we know float vs int
            add_debug_source_node(g, node);
            return LLVMBuildMul(g->builder, val1, val2, "");
        case BinOpTypeDiv:
            // TODO types so we know float vs int and signed vs unsigned
            add_debug_source_node(g, node);
            return LLVMBuildSDiv(g->builder, val1, val2, "");
        case BinOpTypeMod:
            // TODO types so we know float vs int and signed vs unsigned
            add_debug_source_node(g, node);
            return LLVMBuildSRem(g->builder, val1, val2, "");
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
        case BinOpTypeInvalid:
            zig_unreachable();
    }
    zig_unreachable();
}

static LLVMIntPredicate cmp_op_to_int_predicate(BinOpType cmp_op, bool is_signed) {
    switch (cmp_op) {
        case BinOpTypeCmpEq:
            return LLVMIntEQ;
        case BinOpTypeCmpNotEq:
            return LLVMIntNE;
        case BinOpTypeCmpLessThan:
            return is_signed ? LLVMIntSLT : LLVMIntULT;
        case BinOpTypeCmpGreaterThan:
            return is_signed ? LLVMIntSGT : LLVMIntUGT;
        case BinOpTypeCmpLessOrEq:
            return is_signed ? LLVMIntSLE : LLVMIntULE;
        case BinOpTypeCmpGreaterOrEq:
            return is_signed ? LLVMIntSGE : LLVMIntUGE;
        default:
            zig_unreachable();
    }
}

static LLVMValueRef gen_cmp_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    // TODO implement type system so that we know whether to do signed or unsigned comparison here
    LLVMIntPredicate pred = cmp_op_to_int_predicate(node->data.bin_op_expr.bin_op, true);
    add_debug_source_node(g, node);
    return LLVMBuildICmp(g->builder, pred, val1, val2, "");
}

static LLVMValueRef gen_bool_and_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);

    LLVMBasicBlockRef orig_block = LLVMGetInsertBlock(g->builder);
    // block for when val1 == true
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolAndTrue");
    // block for when val1 == false (don't even evaluate the second part)
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolAndFalse");

    LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(val1));
    add_debug_source_node(g, node);
    LLVMValueRef val1_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, zero, "");
    LLVMBuildCondBr(g->builder, val1_i1, false_block, true_block);

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);
    add_debug_source_node(g, node);
    LLVMValueRef val2_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");
    LLVMBuildBr(g->builder, false_block);

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    add_debug_source_node(g, node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef one_i1 = LLVMConstAllOnes(LLVMInt1Type());
    LLVMValueRef incoming_values[2] = {one_i1, val2_i1};
    LLVMBasicBlockRef incoming_blocks[2] = {orig_block, true_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_bool_or_expr(CodeGen *g, AstNode *expr_node) {
    assert(expr_node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, expr_node->data.bin_op_expr.op1);

    LLVMBasicBlockRef orig_block = LLVMGetInsertBlock(g->builder);

    // block for when val1 == false
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolOrFalse");
    // block for when val1 == true (don't even evaluate the second part)
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolOrTrue");

    LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(val1));
    add_debug_source_node(g, expr_node);
    LLVMValueRef val1_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, zero, "");
    LLVMBuildCondBr(g->builder, val1_i1, false_block, true_block);

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    LLVMValueRef val2 = gen_expr(g, expr_node->data.bin_op_expr.op2);
    add_debug_source_node(g, expr_node);
    LLVMValueRef val2_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");
    LLVMBuildBr(g->builder, true_block);

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    add_debug_source_node(g, expr_node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef one_i1 = LLVMConstAllOnes(LLVMInt1Type());
    LLVMValueRef incoming_values[2] = {one_i1, val2_i1};
    LLVMBasicBlockRef incoming_blocks[2] = {orig_block, false_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_assign_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    AstNode *symbol_node = node->data.bin_op_expr.op1;
    assert(symbol_node->type == NodeTypeSymbol);

    LocalVariableTableEntry *var = find_local_variable(node->codegen_node->expr_node.block_context,
            &symbol_node->data.symbol);

    // semantic checking ensures no variables are constant
    assert(!var->is_const);

    LLVMValueRef value = gen_expr(g, node->data.bin_op_expr.op2);

    add_debug_source_node(g, node);
    return LLVMBuildStore(g->builder, value, var->value_ref);
}

static LLVMValueRef gen_bin_op_expr(CodeGen *g, AstNode *node) {
    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeAssign:
            return gen_assign_expr(g, node);
        case BinOpTypeInvalid:
            zig_unreachable();
        case BinOpTypeBoolOr:
            return gen_bool_or_expr(g, node);
        case BinOpTypeBoolAnd:
            return gen_bool_and_expr(g, node);
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
            return gen_cmp_expr(g, node);
        case BinOpTypeBinOr:
        case BinOpTypeBinXor:
        case BinOpTypeBinAnd:
        case BinOpTypeBitShiftLeft:
        case BinOpTypeBitShiftRight:
        case BinOpTypeAdd:
        case BinOpTypeSub:
        case BinOpTypeMult:
        case BinOpTypeDiv:
        case BinOpTypeMod:
            return gen_arithmetic_bin_op_expr(g, node);
    }
    zig_unreachable();
}

static LLVMValueRef gen_return_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeReturnExpr);
    AstNode *param_node = node->data.return_expr.expr;
    if (param_node) {
        LLVMValueRef value = gen_expr(g, param_node);

        add_debug_source_node(g, node);
        return LLVMBuildRet(g->builder, value);
    } else {
        add_debug_source_node(g, node);
        return LLVMBuildRetVoid(g->builder);
    }
}

static LLVMValueRef gen_if_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeIfExpr);
    assert(node->data.if_expr.condition);
    assert(node->data.if_expr.then_block);

    LLVMValueRef cond_value = gen_expr(g, node->data.if_expr.condition);

    TypeTableEntry *then_type = get_expr_type(node->data.if_expr.then_block);
    bool use_expr_value = (then_type != g->builtin_types.entry_unreachable &&
                           then_type != g->builtin_types.entry_void);

    if (node->data.if_expr.else_node) {
        LLVMBasicBlockRef then_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "Then");
        LLVMBasicBlockRef else_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "Else");
        LLVMBasicBlockRef endif_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "EndIf");

        LLVMBuildCondBr(g->builder, cond_value, then_block, else_block);

        LLVMPositionBuilderAtEnd(g->builder, then_block);
        LLVMValueRef then_expr_result = gen_expr(g, node->data.if_expr.then_block);
        if (get_expr_type(node->data.if_expr.then_block) != g->builtin_types.entry_unreachable)
            LLVMBuildBr(g->builder, endif_block);

        LLVMPositionBuilderAtEnd(g->builder, else_block);
        LLVMValueRef else_expr_result = gen_expr(g, node->data.if_expr.else_node);
        if (get_expr_type(node->data.if_expr.else_node) != g->builtin_types.entry_unreachable)
            LLVMBuildBr(g->builder, endif_block);

        LLVMPositionBuilderAtEnd(g->builder, endif_block);
        if (use_expr_value) {
            LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMTypeOf(then_expr_result), "");
            LLVMValueRef incoming_values[2] = {then_expr_result, else_expr_result};
            LLVMBasicBlockRef incoming_blocks[2] = {then_block, else_block};
            LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

            return phi;
        }

        return nullptr;
    }

    assert(!use_expr_value);

    LLVMBasicBlockRef then_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "Then");
    LLVMBasicBlockRef endif_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "EndIf");

    LLVMBuildCondBr(g->builder, cond_value, then_block, endif_block);

    LLVMPositionBuilderAtEnd(g->builder, then_block);
    gen_expr(g, node->data.if_expr.then_block);
    if (get_expr_type(node->data.if_expr.then_block) != g->builtin_types.entry_unreachable)
        LLVMBuildBr(g->builder, endif_block);

    LLVMPositionBuilderAtEnd(g->builder, endif_block);
    return nullptr;
}

static LLVMValueRef gen_block(CodeGen *g, AstNode *block_node, TypeTableEntry *implicit_return_type) {
    assert(block_node->type == NodeTypeBlock);

    ImportTableEntry *import = g->cur_fn->import_entry;

    LLVMZigDILexicalBlock *di_block = LLVMZigCreateLexicalBlock(g->dbuilder, g->block_scopes.last(),
            import->di_file, block_node->line + 1, block_node->column + 1);
    g->block_scopes.append(LLVMZigLexicalBlockToScope(di_block));

    add_debug_source_node(g, block_node);

    LLVMValueRef return_value;
    for (int i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        return_value = gen_expr(g, statement_node);
    }

    if (implicit_return_type) {
        if (implicit_return_type == g->builtin_types.entry_void) {
            LLVMBuildRetVoid(g->builder);
        } else if (implicit_return_type != g->builtin_types.entry_unreachable) {
            LLVMBuildRet(g->builder, return_value);
        }
    }

    g->block_scopes.pop();

    return return_value;
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *node) {
    switch (node->type) {
        case NodeTypeBinOpExpr:
            return gen_bin_op_expr(g, node);
        case NodeTypeReturnExpr:
            return gen_return_expr(g, node);
        case NodeTypeVariableDeclaration:
            {
                LocalVariableTableEntry *variable = find_local_variable(node->codegen_node->expr_node.block_context, &node->data.variable_declaration.symbol);
                if (variable->is_const) {
                    assert(node->data.variable_declaration.expr);
                    variable->value_ref = gen_expr(g, node->data.variable_declaration.expr);
                    return nullptr;
                } else {
                    if (node->data.variable_declaration.expr) {
                        LLVMValueRef value = gen_expr(g, node->data.variable_declaration.expr);

                        add_debug_source_node(g, node);
                        return LLVMBuildStore(g->builder, value, variable->value_ref);
                    } else {

                    }
                }
            }
        case NodeTypeCastExpr:
            return gen_cast_expr(g, node);
        case NodeTypePrefixOpExpr:
            return gen_prefix_op_expr(g, node);
        case NodeTypeFnCallExpr:
            return gen_fn_call_expr(g, node);
        case NodeTypeUnreachable:
            add_debug_source_node(g, node);
            return LLVMBuildUnreachable(g->builder);
        case NodeTypeVoid:
            return nullptr;
        case NodeTypeBoolLiteral:
            if (node->data.bool_literal)
                return LLVMConstAllOnes(LLVMInt1Type());
            else
                return LLVMConstNull(LLVMInt1Type());
        case NodeTypeIfExpr:
            return gen_if_expr(g, node);
        case NodeTypeNumberLiteral:
            {
                Buf *number_str = &node->data.number;
                LLVMTypeRef number_type = LLVMInt32Type();
                LLVMValueRef number_val = LLVMConstIntOfStringAndSize(number_type,
                        buf_ptr(number_str), buf_len(number_str), 10);
                return number_val;
            }
        case NodeTypeStringLiteral:
            {
                Buf *str = &node->data.string;
                LLVMValueRef str_val = find_or_create_string(g, str);
                LLVMValueRef indices[] = {
                    LLVMConstInt(LLVMInt32Type(), 0, false),
                    LLVMConstInt(LLVMInt32Type(), 0, false)
                };
                LLVMValueRef ptr_val = LLVMBuildInBoundsGEP(g->builder, str_val, indices, 2, "");
                return ptr_val;
            }
        case NodeTypeSymbol:
            {
                LocalVariableTableEntry *variable = find_local_variable(node->codegen_node->expr_node.block_context, &node->data.symbol);
                if (variable->is_const) {
                    return variable->value_ref;
                } else {
                    return LLVMBuildLoad(g->builder, variable->value_ref, "");
                }
            }
        case NodeTypeBlock:
            return gen_block(g, node, nullptr);
        case NodeTypeGoto:
            add_debug_source_node(g, node);
            return LLVMBuildBr(g->builder, node->codegen_node->data.label_entry->basic_block);
        case NodeTypeLabel:
            {
                LabelTableEntry *label_entry = node->codegen_node->data.label_entry;
                assert(label_entry);
                LLVMBasicBlockRef basic_block = label_entry->basic_block;
                if (label_entry->entered_from_fallthrough) {
                    add_debug_source_node(g, node);
                    LLVMBuildBr(g->builder, basic_block);
                }
                LLVMPositionBuilderAtEnd(g->builder, basic_block);
                return nullptr;
            }
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeType:
        case NodeTypeExternBlock:
        case NodeTypeDirective:
        case NodeTypeUse:
            zig_unreachable();
    }
    zig_unreachable();
}

static void build_label_blocks(CodeGen *g, AstNode *block_node) {
    assert(block_node->type == NodeTypeBlock);
    for (int i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *label_node = block_node->data.block.statements.at(i);
        if (label_node->type != NodeTypeLabel)
            continue;

        Buf *name = &label_node->data.label.name;
        label_node->codegen_node->data.label_entry->basic_block = LLVMAppendBasicBlock(
                g->cur_fn->fn_value, buf_ptr(name));
    }

}

static LLVMZigDISubroutineType *create_di_function_type(CodeGen *g, AstNodeFnProto *fn_proto,
        LLVMZigDIFile *di_file)
{
    LLVMZigDIType **types = allocate<LLVMZigDIType*>(1 + fn_proto->params.length);
    types[0] = to_llvm_debug_type(fn_proto->return_type);
    int types_len = fn_proto->params.length + 1;
    for (int i = 0; i < fn_proto->params.length; i += 1) {
        AstNode *param_node = fn_proto->params.at(i);
        assert(param_node->type == NodeTypeParamDecl);
        LLVMZigDIType *param_type = to_llvm_debug_type(param_node->data.param_decl.type);
        types[i + 1] = param_type;
    }
    return LLVMZigCreateSubroutineType(g->dbuilder, di_file, types, types_len, 0);
}

static void do_code_gen(CodeGen *g) {
    assert(!g->errors.length);

    g->block_scopes.append(LLVMZigCompileUnitToScope(g->compile_unit));


    // Generate function prototypes
    for (int i = 0; i < g->fn_protos.length; i += 1) {
        FnTableEntry *fn_table_entry = g->fn_protos.at(i);

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        LLVMTypeRef ret_type = to_llvm_type(fn_proto->return_type);
        int param_count = count_non_void_params(g, &fn_proto->params);
        LLVMTypeRef *param_types = allocate<LLVMTypeRef>(param_count);
        int gen_param_index = 0;
        for (int param_decl_i = 0; param_decl_i < fn_proto->params.length; param_decl_i += 1) {
            AstNode *param_node = fn_proto->params.at(param_decl_i);
            assert(param_node->type == NodeTypeParamDecl);
            if (is_param_decl_type_void(g, param_node))
                continue;
            AstNode *type_node = param_node->data.param_decl.type;
            param_types[gen_param_index] = to_llvm_type(type_node);
            gen_param_index += 1;
        }
        LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, param_count, 0);
        LLVMValueRef fn = LLVMAddFunction(g->module, buf_ptr(&fn_proto->name), function_type);

        LLVMSetLinkage(fn, fn_table_entry->internal_linkage ? LLVMInternalLinkage : LLVMExternalLinkage);

        if (type_is_unreachable(g, fn_proto->return_type)) {
            LLVMAddFunctionAttr(fn, LLVMNoReturnAttribute);
        }
        LLVMSetFunctionCallConv(fn, fn_table_entry->calling_convention);
        if (!fn_table_entry->is_extern) {
            LLVMAddFunctionAttr(fn, LLVMNoUnwindAttribute);
        }

        fn_table_entry->fn_value = fn;
    }

    // Generate function definitions.
    for (int i = 0; i < g->fn_defs.length; i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(i);
        ImportTableEntry *import = fn_table_entry->import_entry;
        AstNode *fn_def_node = fn_table_entry->fn_def_node;
        LLVMValueRef fn = fn_table_entry->fn_value;
        g->cur_fn = fn_table_entry;

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        // Add debug info.
        LLVMZigDIScope *fn_scope = LLVMZigFileToScope(import->di_file);
        unsigned line_number = fn_def_node->line + 1;
        unsigned scope_line = line_number;
        bool is_definition = true;
        unsigned flags = 0;
        bool is_optimized = g->build_type == CodeGenBuildTypeRelease;
        LLVMZigDISubprogram *subprogram = LLVMZigCreateFunction(g->dbuilder,
            fn_scope, buf_ptr(&fn_proto->name), "", import->di_file, line_number,
            create_di_function_type(g, fn_proto, import->di_file), fn_table_entry->internal_linkage, 
            is_definition, scope_line, flags, is_optimized, fn);

        g->block_scopes.append(LLVMZigSubprogramToScope(subprogram));

        LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn, "entry");
        LLVMPositionBuilderAtEnd(g->builder, entry_block);

        CodeGenNode *codegen_node = fn_def_node->codegen_node;
        assert(codegen_node);

        FnDefNode *codegen_fn_def = &codegen_node->data.fn_def_node;
        assert(codegen_fn_def);
        int non_void_param_count = count_non_void_params(g, &fn_proto->params);
        assert(non_void_param_count == (int)LLVMCountParams(fn));
        LLVMValueRef *params = allocate<LLVMValueRef>(non_void_param_count);
        LLVMGetParams(fn, params);

        int non_void_index = 0;
        for (int i = 0; i < fn_proto->params.length; i += 1) {
            AstNode *param_decl = fn_proto->params.at(i);
            assert(param_decl->type == NodeTypeParamDecl);
            if (is_param_decl_type_void(g, param_decl))
                continue;
            LocalVariableTableEntry *parameter_variable = fn_def_node->codegen_node->data.fn_def_node.block_context->variable_table.get(&param_decl->data.param_decl.name);
            parameter_variable->value_ref = params[non_void_index];
            non_void_index += 1;
        }

        build_label_blocks(g, fn_def_node->data.fn_def.body);

        // allocate all local variables
        for (int i = 0; i < codegen_fn_def->all_block_contexts.length; i += 1) {
            BlockContext *block_context = codegen_fn_def->all_block_contexts.at(i);

            auto it = block_context->variable_table.entry_iterator();
            for (;;) {
                auto *entry = it.next();
                if (!entry)
                    break;

                LocalVariableTableEntry *var = entry->value;
                if (!var->is_const) {
                    add_debug_source_node(g, var->decl_node);
                    var->value_ref = LLVMBuildAlloca(g->builder, var->type->type_ref, buf_ptr(&var->name));
                }
            }
        }

        TypeTableEntry *implicit_return_type = codegen_fn_def->implicit_return_type;
        gen_block(g, fn_def_node->data.fn_def.body, implicit_return_type);

        g->block_scopes.pop();

    }
    assert(!g->errors.length);

    LLVMZigDIBuilderFinalize(g->dbuilder);

    if (g->verbose) {
        LLVMDumpModule(g->module);
    }

    // in release mode, we're sooooo confident that we've generated correct ir,
    // that we skip the verify module step in order to get better performance.
#ifndef NDEBUG
    char *error = nullptr;
    LLVMVerifyModule(g->module, LLVMAbortProcessAction, &error);
#endif
}

static void define_primitive_types(CodeGen *g) {
    {
        // if this type is anywhere in the AST, we should never hit codegen.
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        buf_init_from_str(&entry->name, "(invalid)");
        g->builtin_types.entry_invalid = entry;
    }
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->type_ref = LLVMInt1Type();
        buf_init_from_str(&entry->name, "bool");
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name), 1, 8,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_bool = entry;
    }
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->type_ref = LLVMInt8Type();
        buf_init_from_str(&entry->name, "u8");
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name), 8, 8,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_u8 = entry;
    }
    g->builtin_types.entry_string_literal = get_pointer_to_type(g, g->builtin_types.entry_u8, true);
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->type_ref = LLVMInt32Type();
        buf_init_from_str(&entry->name, "i32");
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name), 32, 32,
                LLVMZigEncoding_DW_ATE_signed());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_i32 = entry;
    }
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->type_ref = LLVMVoidType();
        buf_init_from_str(&entry->name, "void");
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name), 0, 0,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_void = entry;
    }
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->type_ref = LLVMVoidType();
        buf_init_from_str(&entry->name, "unreachable");
        entry->di_type = g->builtin_types.entry_void->di_type;
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_unreachable = entry;
    }
}



static void init(CodeGen *g, Buf *source_path) {
    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetMCs();
    LLVMInitializeAllAsmPrinters();
    LLVMInitializeAllAsmParsers();
    LLVMInitializeNativeTarget();

    g->is_native_target = true;
    char *native_triple = LLVMGetDefaultTargetTriple();

    LLVMTargetRef target_ref;
    char *err_msg = nullptr;
    if (LLVMGetTargetFromTriple(native_triple, &target_ref, &err_msg)) {
        zig_panic("unable to get target from triple: %s", err_msg);
    }

    char *native_cpu = LLVMZigGetHostCPUName();
    char *native_features = LLVMZigGetNativeFeatures();

    LLVMCodeGenOptLevel opt_level = (g->build_type == CodeGenBuildTypeDebug) ?
        LLVMCodeGenLevelNone : LLVMCodeGenLevelAggressive;

    LLVMRelocMode reloc_mode = g->is_static ? LLVMRelocStatic : LLVMRelocPIC;

    g->target_machine = LLVMCreateTargetMachine(target_ref, native_triple,
            native_cpu, native_features, opt_level, reloc_mode, LLVMCodeModelDefault);

    g->target_data_ref = LLVMGetTargetMachineData(g->target_machine);


    g->module = LLVMModuleCreateWithName("ZigModule");

    g->pointer_size_bytes = LLVMPointerSize(g->target_data_ref);

    g->builder = LLVMCreateBuilder();
    g->dbuilder = LLVMZigCreateDIBuilder(g->module, true);


    define_primitive_types(g);

    Buf *producer = buf_sprintf("zig %s", ZIG_VERSION_STRING);
    bool is_optimized = g->build_type == CodeGenBuildTypeRelease;
    const char *flags = "";
    unsigned runtime_version = 0;
    g->compile_unit = LLVMZigCreateCompileUnit(g->dbuilder, LLVMZigLang_DW_LANG_C99(),
            buf_ptr(source_path), buf_ptr(g->root_source_dir),
            buf_ptr(producer), is_optimized, flags, runtime_version,
            "", 0, !g->strip_debug_symbols);


}

static ImportTableEntry *codegen_add_code(CodeGen *g, Buf *source_path, Buf *source_code) {
    int err;
    Buf full_path = BUF_INIT;
    os_path_join(g->root_source_dir, source_path, &full_path);

    Buf dirname = BUF_INIT;
    Buf basename = BUF_INIT;
    os_path_split(&full_path, &dirname, &basename);

    if (g->verbose) {
        fprintf(stderr, "\nOriginal Source (%s):\n", buf_ptr(source_path));
        fprintf(stderr, "----------------\n");
        fprintf(stderr, "%s\n", buf_ptr(source_code));

        fprintf(stderr, "\nTokens:\n");
        fprintf(stderr, "---------\n");
    }

    Tokenization tokenization = {0};
    tokenize(source_code, &tokenization);

    if (tokenization.err) {
        ErrorMsg *err = allocate<ErrorMsg>(1);
        err->line_start = tokenization.err_line;
        err->column_start = tokenization.err_column;
        err->line_end = -1;
        err->column_end = -1;
        err->msg = tokenization.err;
        err->path = source_path;
        err->source = source_code;
        err->line_offsets = tokenization.line_offsets;

        print_err_msg(err, g->err_color);
        exit(1);
    }

    if (g->verbose) {
        print_tokens(source_code, tokenization.tokens);

        fprintf(stderr, "\nAST:\n");
        fprintf(stderr, "------\n");
    }

    ImportTableEntry *import_entry = allocate<ImportTableEntry>(1);
    import_entry->source_code = source_code;
    import_entry->line_offsets = tokenization.line_offsets;
    import_entry->path = source_path;
    import_entry->fn_table.init(32);
    import_entry->root = ast_parse(source_code, tokenization.tokens, import_entry, g->err_color);
    assert(import_entry->root);
    if (g->verbose) {
        ast_print(import_entry->root, 0);
    }

    import_entry->di_file = LLVMZigCreateFile(g->dbuilder, buf_ptr(&basename), buf_ptr(&dirname));
    g->import_table.put(source_path, import_entry);


    assert(import_entry->root->type == NodeTypeRoot);
    for (int decl_i = 0; decl_i < import_entry->root->data.root.top_level_decls.length; decl_i += 1) {
        AstNode *top_level_decl = import_entry->root->data.root.top_level_decls.at(decl_i);
        if (top_level_decl->type != NodeTypeUse)
            continue;

        auto entry = g->import_table.maybe_get(&top_level_decl->data.use.path);
        if (!entry) {
            Buf full_path = BUF_INIT;
            os_path_join(g->root_source_dir, &top_level_decl->data.use.path, &full_path);
            Buf *import_code = buf_alloc();
            if ((err = os_fetch_file_path(&full_path, import_code))) {
                add_node_error(g, top_level_decl,
                        buf_sprintf("unable to open '%s': %s", buf_ptr(&full_path), err_str(err)));
                break;
            }
            codegen_add_code(g, &top_level_decl->data.use.path, import_code);
        }
    }

    return import_entry;
}

void codegen_add_root_code(CodeGen *g, Buf *source_path, Buf *source_code) {
    init(g, source_path);

    g->root_import = codegen_add_code(g, source_path, source_code);

    if (g->verbose) {
        fprintf(stderr, "\nSemantic Analysis:\n");
        fprintf(stderr, "--------------------\n");
    }
    semantic_analyze(g);

    if (g->errors.length == 0) {
        if (g->verbose) {
            fprintf(stderr, "OK\n");
        }
    } else {
        for (int i = 0; i < g->errors.length; i += 1) {
            ErrorMsg *err = g->errors.at(i);
            print_err_msg(err, g->err_color);
        }
        exit(1);
    }

    if (g->verbose) {
        fprintf(stderr, "\nCode Generation:\n");
        fprintf(stderr, "------------------\n");
    }

    do_code_gen(g);
}

static void to_c_type(CodeGen *g, AstNode *type_node, Buf *out_buf) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);

    TypeTableEntry *type_entry = type_node->codegen_node->data.type_node.entry;
    assert(type_entry);

    if (type_entry == g->builtin_types.entry_u8) {
        g->c_stdint_used = true;
        buf_init_from_str(out_buf, "uint8_t");
    } else if (type_entry == g->builtin_types.entry_i32) {
        g->c_stdint_used = true;
        buf_init_from_str(out_buf, "int32_t");
    } else if (type_entry == g->builtin_types.entry_unreachable) {
        buf_init_from_str(out_buf, "__attribute__((__noreturn__)) void");
    } else if (type_entry == g->builtin_types.entry_bool) {
        buf_init_from_str(out_buf, "unsigned char");
    } else if (type_entry == g->builtin_types.entry_void) {
        buf_init_from_str(out_buf, "void");
    } else {
        zig_panic("TODO to_c_type");
    }
}

static void generate_h_file(CodeGen *g) {
    Buf *h_file_out_path = buf_sprintf("%s.h", buf_ptr(g->root_out_name));
    FILE *out_h = fopen(buf_ptr(h_file_out_path), "wb");
    if (!out_h)
        zig_panic("unable to open %s: %s", buf_ptr(h_file_out_path), strerror(errno));

    Buf *export_macro = buf_sprintf("%s_EXPORT", buf_ptr(g->root_out_name));
    buf_upcase(export_macro);

    Buf *extern_c_macro = buf_sprintf("%s_EXTERN_C", buf_ptr(g->root_out_name));
    buf_upcase(extern_c_macro);

    Buf h_buf = BUF_INIT;
    buf_resize(&h_buf, 0);
    for (int fn_def_i = 0; fn_def_i < g->fn_defs.length; fn_def_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(fn_def_i);
        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        if (fn_proto->visib_mod != FnProtoVisibModExport)
            continue;

        Buf return_type_c = BUF_INIT;
        to_c_type(g, fn_proto->return_type, &return_type_c);

        buf_appendf(&h_buf, "%s %s %s(",
                buf_ptr(export_macro),
                buf_ptr(&return_type_c),
                buf_ptr(&fn_proto->name));

        Buf param_type_c = BUF_INIT;
        if (fn_proto->params.length) {
            for (int param_i = 0; param_i < fn_proto->params.length; param_i += 1) {
                AstNode *param_decl_node = fn_proto->params.at(param_i);
                AstNode *param_type = param_decl_node->data.param_decl.type;
                to_c_type(g, param_type, &param_type_c);
                buf_appendf(&h_buf, "%s %s",
                        buf_ptr(&param_type_c),
                        buf_ptr(&param_decl_node->data.param_decl.name));
                if (param_i < fn_proto->params.length - 1)
                    buf_appendf(&h_buf, ", ");
            }
            buf_appendf(&h_buf, ")");
        } else {
            buf_appendf(&h_buf, "void)");
        }

        buf_appendf(&h_buf, ";\n");

    }

    Buf *ifdef_dance_name = buf_sprintf("%s_%s_H",
            buf_ptr(g->root_out_name), buf_ptr(g->root_out_name));
    buf_upcase(ifdef_dance_name);

    fprintf(out_h, "#ifndef %s\n", buf_ptr(ifdef_dance_name));
    fprintf(out_h, "#define %s\n\n", buf_ptr(ifdef_dance_name));

    if (g->c_stdint_used)
        fprintf(out_h, "#include <stdint.h>\n");

    fprintf(out_h, "\n");

    fprintf(out_h, "#ifdef __cplusplus\n");
    fprintf(out_h, "#define %s extern \"C\"\n", buf_ptr(extern_c_macro));
    fprintf(out_h, "#else\n");
    fprintf(out_h, "#define %s\n", buf_ptr(extern_c_macro));
    fprintf(out_h, "#endif\n");
    fprintf(out_h, "\n");
    fprintf(out_h, "#if defined(_WIN32)\n");
    fprintf(out_h, "#define %s %s __declspec(dllimport)\n", buf_ptr(export_macro), buf_ptr(extern_c_macro));
    fprintf(out_h, "#else\n");
    fprintf(out_h, "#define %s %s __attribute__((visibility (\"default\")))\n",
            buf_ptr(export_macro), buf_ptr(extern_c_macro));
    fprintf(out_h, "#endif\n");
    fprintf(out_h, "\n");

    fprintf(out_h, "%s", buf_ptr(&h_buf));

    fprintf(out_h, "\n#endif\n");

    if (fclose(out_h))
        zig_panic("unable to close h file: %s", strerror(errno));
}

void codegen_link(CodeGen *g, const char *out_file) {
    bool is_optimized = (g->build_type == CodeGenBuildTypeRelease);
    if (is_optimized) {
        if (g->verbose) {
            fprintf(stderr, "\nOptimization:\n");
            fprintf(stderr, "---------------\n");
        }

        LLVMZigOptimizeModule(g->target_machine, g->module);

        if (g->verbose) {
            LLVMDumpModule(g->module);
        }
    }
    if (g->verbose) {
        fprintf(stderr, "\nLink:\n");
        fprintf(stderr, "-------\n");
    }

    if (!out_file) {
        out_file = buf_ptr(g->root_out_name);
    }

    Buf out_file_o = BUF_INIT;
    buf_init_from_str(&out_file_o, out_file);

    if (g->out_type != OutTypeObj) {
        buf_append_str(&out_file_o, ".o");
    }

    char *err_msg = nullptr;
    if (LLVMTargetMachineEmitToFile(g->target_machine, g->module, buf_ptr(&out_file_o),
                LLVMObjectFile, &err_msg))
    {
        zig_panic("unable to write object file: %s", err_msg);
    }

    if (g->out_type == OutTypeObj) {
        return;
    }

    if (g->out_type == OutTypeLib && g->is_static) {
        // invoke `ar`
        // example:
        // # static link into libfoo.a
        // ar cq libfoo.a foo1.o foo2.o 
        zig_panic("TODO invoke ar");
        return;
    }

    // invoke `ld`
    ZigList<const char *> args = {0};
    if (g->is_static) {
        args.append("-static");
    }

    char *ZIG_NATIVE_DYNAMIC_LINKER = getenv("ZIG_NATIVE_DYNAMIC_LINKER");
    if (g->is_native_target && ZIG_NATIVE_DYNAMIC_LINKER) {
        if (ZIG_NATIVE_DYNAMIC_LINKER[0] != 0) {
            args.append("-dynamic-linker");
            args.append(ZIG_NATIVE_DYNAMIC_LINKER);
        }
    } else {
        args.append("-dynamic-linker");
        args.append(buf_ptr(get_dynamic_linker(g->target_machine)));
    }

    if (g->out_type == OutTypeLib) {
        Buf *out_lib_so = buf_sprintf("lib%s.so.%d.%d.%d",
                buf_ptr(g->root_out_name), g->version_major, g->version_minor, g->version_patch);
        Buf *soname = buf_sprintf("lib%s.so.%d", buf_ptr(g->root_out_name), g->version_major);
        args.append("-shared");
        args.append("-soname");
        args.append(buf_ptr(soname));
        out_file = buf_ptr(out_lib_so);
    }

    args.append("-o");
    args.append(out_file);

    args.append((const char *)buf_ptr(&out_file_o));

    auto it = g->link_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        Buf *arg = buf_sprintf("-l%s", buf_ptr(entry->key));
        args.append(buf_ptr(arg));
    }

    os_spawn_process("ld", args, false);

    if (g->out_type == OutTypeLib) {
        generate_h_file(g);
    }

    if (g->verbose) {
        fprintf(stderr, "OK\n");
    }
}
