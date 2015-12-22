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

void codegen_set_libc_path(CodeGen *g, Buf *libc_path) {
    g->libc_path = libc_path;
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *expr_node);
static LLVMValueRef gen_lvalue(CodeGen *g, AstNode *expr_node, AstNode *node, TypeTableEntry **out_type_entry);
static LLVMValueRef gen_field_access_expr(CodeGen *g, AstNode *node, bool is_lvalue);
    

static TypeTableEntry *get_type_for_type_node(CodeGen *g, AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);
    assert(type_node->codegen_node->data.type_node.entry);
    return type_node->codegen_node->data.type_node.entry;
}

static LLVMTypeRef fn_proto_type_from_type_node(CodeGen *g, AstNode *type_node) {
    TypeTableEntry *type_entry = get_type_for_type_node(g, type_node);

    if (type_entry->id == TypeTableEntryIdStruct || type_entry->id == TypeTableEntryIdArray) {
        return get_pointer_to_type(g, type_entry, true)->type_ref;
    } else {
        return type_entry->type_ref;
    }
}

static LLVMZigDIType *to_llvm_debug_type(CodeGen *g, AstNode *type_node) {
    TypeTableEntry *type_entry = get_type_for_type_node(g, type_node);
    return type_entry->di_type;
}


static bool type_is_unreachable(CodeGen *g, AstNode *type_node) {
    return get_type_for_type_node(g, type_node)->id == TypeTableEntryIdUnreachable;
}

static bool is_param_decl_type_void(CodeGen *g, AstNode *param_decl_node) {
    assert(param_decl_node->type == NodeTypeParamDecl);
    return get_type_for_type_node(g, param_decl_node->data.param_decl.type)->id == TypeTableEntryIdVoid;
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
    if (!g->cur_block_context)
        return;
    LLVMZigSetCurrentDebugLocation(g->builder, node->line + 1, node->column + 1,
            g->cur_block_context->di_scope);
}

static LLVMValueRef find_or_create_string(CodeGen *g, Buf *str, bool c) {
    auto entry = g->str_table.maybe_get(str);
    if (entry) {
        return entry->value;
    }
    LLVMValueRef text = LLVMConstString(buf_ptr(str), buf_len(str), !c);
    LLVMValueRef global_value = LLVMAddGlobal(g->module, LLVMTypeOf(text), "");
    LLVMSetLinkage(global_value, LLVMPrivateLinkage);
    LLVMSetInitializer(global_value, text);
    LLVMSetGlobalConstant(global_value, true);
    LLVMSetUnnamedAddr(global_value, true);
    g->str_table.put(str, global_value);

    return global_value;
}

static TypeTableEntry *get_expr_type(AstNode *node) {
    TypeTableEntry *cast_type = node->codegen_node->expr_node.implicit_cast.type;
    return cast_type ? cast_type : node->codegen_node->expr_node.type_entry;
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
    AstNodeFnProto *fn_proto_data = &fn_table_entry->proto_node->data.fn_proto;

    int expected_param_count = fn_proto_data->params.length;
    int actual_param_count = node->data.fn_call_expr.params.length;
    bool is_var_args = fn_proto_data->is_var_args;
    assert((is_var_args && actual_param_count >= expected_param_count) ||
            actual_param_count == expected_param_count);

    // don't really include void values
    int gen_param_count;
    if (is_var_args) {
        gen_param_count = actual_param_count;
    } else {
        gen_param_count = count_non_void_params(g, &fn_table_entry->proto_node->data.fn_proto.params);
    }
    LLVMValueRef *gen_param_values = allocate<LLVMValueRef>(gen_param_count);

    int loop_end = max(gen_param_count, actual_param_count);

    int gen_param_index = 0;
    for (int i = 0; i < loop_end; i += 1) {
        AstNode *expr_node = node->data.fn_call_expr.params.at(i);
        LLVMValueRef param_value = gen_expr(g, expr_node);
        if (is_var_args ||
            !is_param_decl_type_void(g, fn_table_entry->proto_node->data.fn_proto.params.at(i)))
        {
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

static LLVMValueRef gen_array_ptr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeArrayAccessExpr);

    // TODO gen_lvalue
    LLVMValueRef array_ref_value = gen_expr(g, node->data.array_access_expr.array_ref_expr);
    LLVMValueRef subscript_value = gen_expr(g, node->data.array_access_expr.subscript);

    assert(array_ref_value);
    assert(subscript_value);

    LLVMValueRef indices[] = {
        LLVMConstInt(LLVMInt32Type(), 0, false),
        subscript_value
    };
    add_debug_source_node(g, node);
    return LLVMBuildInBoundsGEP(g->builder, array_ref_value, indices, 2, "");
}

static LLVMValueRef gen_field_ptr(CodeGen *g, AstNode *node, TypeTableEntry **out_type_entry) {
    assert(node->type == NodeTypeFieldAccessExpr);

    AstNode *struct_expr_node = node->data.field_access_expr.struct_expr;

    LLVMValueRef struct_ptr;
    if (struct_expr_node->type == NodeTypeSymbol) {
        VariableTableEntry *var = find_variable(struct_expr_node->codegen_node->expr_node.block_context,
                &struct_expr_node->data.symbol);
        assert(var);

        if (var->is_ptr && var->type->id == TypeTableEntryIdPointer) {
            add_debug_source_node(g, node);
            struct_ptr = LLVMBuildLoad(g->builder, var->value_ref, "");
        } else {
            struct_ptr = var->value_ref;
        }
    } else if (struct_expr_node->type == NodeTypeFieldAccessExpr) {
        struct_ptr = gen_field_access_expr(g, struct_expr_node, true);
        TypeTableEntry *field_type = get_expr_type(struct_expr_node);
        if (field_type->id == TypeTableEntryIdPointer) {
            // we have a double pointer so we must dereference it once
            add_debug_source_node(g, node);
            struct_ptr = LLVMBuildLoad(g->builder, struct_ptr, "");
        }
    } else {
        struct_ptr = gen_expr(g, struct_expr_node);
    }

    assert(LLVMGetTypeKind(LLVMTypeOf(struct_ptr)) == LLVMPointerTypeKind);
    assert(LLVMGetTypeKind(LLVMGetElementType(LLVMTypeOf(struct_ptr))) == LLVMStructTypeKind);

    FieldAccessNode *codegen_field_access = &node->codegen_node->data.field_access_node;

    assert(codegen_field_access->field_index >= 0);

    *out_type_entry = codegen_field_access->type_struct_field->type_entry;

    add_debug_source_node(g, node);
    return LLVMBuildStructGEP(g->builder, struct_ptr, codegen_field_access->field_index, "");
}

static LLVMValueRef gen_array_access_expr(CodeGen *g, AstNode *node, bool is_lvalue) {
    assert(node->type == NodeTypeArrayAccessExpr);

    LLVMValueRef ptr = gen_array_ptr(g, node);

    if (is_lvalue) {
        return ptr;
    } else {
        add_debug_source_node(g, node);
        return LLVMBuildLoad(g->builder, ptr, "");
    }
}

static LLVMValueRef gen_field_access_expr(CodeGen *g, AstNode *node, bool is_lvalue) {
    assert(node->type == NodeTypeFieldAccessExpr);

    TypeTableEntry *struct_type = get_expr_type(node->data.field_access_expr.struct_expr);
    Buf *name = &node->data.field_access_expr.field_name;

    if (struct_type->id == TypeTableEntryIdArray) {
        if (buf_eql_str(name, "len")) {
            return LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                    struct_type->data.array.len, false);
        } else {
            zig_panic("gen_field_access_expr bad array field");
        }
    } else if (struct_type->id == TypeTableEntryIdStruct || (struct_type->id == TypeTableEntryIdPointer &&
               struct_type->data.pointer.child_type->id == TypeTableEntryIdStruct))
    {
        TypeTableEntry *type_entry;
        LLVMValueRef ptr = gen_field_ptr(g, node, &type_entry);
        if (is_lvalue) {
            return ptr;
        } else {
            add_debug_source_node(g, node);
            return LLVMBuildLoad(g->builder, ptr, "");
        }
    } else {
        zig_panic("gen_field_access_expr bad struct type");
    }
}

static LLVMValueRef gen_lvalue(CodeGen *g, AstNode *expr_node, AstNode *node,
        TypeTableEntry **out_type_entry)
{
    LLVMValueRef target_ref;

    if (node->type == NodeTypeSymbol) {
        VariableTableEntry *var = find_variable(expr_node->codegen_node->expr_node.block_context,
                &node->data.symbol);
        assert(var);
        // semantic checking ensures no variables are constant
        assert(!var->is_const);

        *out_type_entry = var->type;
        target_ref = var->value_ref;
    } else if (node->type == NodeTypeArrayAccessExpr) {
        TypeTableEntry *array_type = get_expr_type(node->data.array_access_expr.array_ref_expr);
        assert(array_type->id == TypeTableEntryIdArray);
        *out_type_entry = array_type->data.array.child_type;
        target_ref = gen_array_ptr(g, node);
    } else if (node->type == NodeTypeFieldAccessExpr) {
        target_ref = gen_field_ptr(g, node, out_type_entry);
    } else {
        zig_panic("bad assign target");
    }

    return target_ref;
}

static LLVMValueRef gen_prefix_op_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypePrefixOpExpr);
    assert(node->data.prefix_op_expr.primary_expr);

    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;

    switch (node->data.prefix_op_expr.prefix_op) {
        case PrefixOpInvalid:
            zig_unreachable();
        case PrefixOpNegation:
            {
                LLVMValueRef expr = gen_expr(g, expr_node);
                add_debug_source_node(g, node);
                return LLVMBuildNeg(g->builder, expr, "");
            }
        case PrefixOpBoolNot:
            {
                LLVMValueRef expr = gen_expr(g, expr_node);
                LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(expr));
                add_debug_source_node(g, node);
                return LLVMBuildICmp(g->builder, LLVMIntEQ, expr, zero, "");
            }
        case PrefixOpBinNot:
            {
                LLVMValueRef expr = gen_expr(g, expr_node);
                add_debug_source_node(g, node);
                return LLVMBuildNot(g->builder, expr, "");
            }
        case PrefixOpAddressOf:
        case PrefixOpConstAddressOf:
            {
                add_debug_source_node(g, node);
                TypeTableEntry *lvalue_type;
                return gen_lvalue(g, node, expr_node, &lvalue_type);
            }

    }
    zig_unreachable();
}

static LLVMValueRef gen_bare_cast(CodeGen *g, AstNode *node, LLVMValueRef expr_val,
        TypeTableEntry *actual_type, TypeTableEntry *wanted_type, CastNode *cast_node)
{
    switch (cast_node->op) {
        case CastOpNothing:
            return expr_val;
        case CastOpPtrToInt:
            return LLVMBuildPtrToInt(g->builder, expr_val, wanted_type->type_ref, "");
        case CastOpIntWidenOrShorten:
            if (actual_type->size_in_bits == wanted_type->size_in_bits) {
                return expr_val;
            } else if (actual_type->size_in_bits < wanted_type->size_in_bits) {
                if (actual_type->data.integral.is_signed && wanted_type->data.integral.is_signed) {
                    return LLVMBuildSExt(g->builder, expr_val, wanted_type->type_ref, "");
                } else if (!actual_type->data.integral.is_signed && !wanted_type->data.integral.is_signed) {
                    return LLVMBuildZExt(g->builder, expr_val, wanted_type->type_ref, "");
                } else {
                    zig_panic("TODO gen_cast_expr mixing of signness");
                }
            } else {
                assert(actual_type->size_in_bits > wanted_type->size_in_bits);

                if (actual_type->data.integral.is_signed && wanted_type->data.integral.is_signed) {
                    return LLVMBuildTrunc(g->builder, expr_val, wanted_type->type_ref, "");
                } else {
                    zig_panic("TODO gen_cast_expr shorten unsigned");
                }
            }
        case CastOpArrayToString:
            {
                assert(cast_node->ptr);

                add_debug_source_node(g, node);

                LLVMValueRef ptr_ptr = LLVMBuildStructGEP(g->builder, cast_node->ptr, 0, "");
                LLVMBuildStore(g->builder, expr_val, ptr_ptr);

                LLVMValueRef len_ptr = LLVMBuildStructGEP(g->builder, cast_node->ptr, 1, "");
                LLVMValueRef len_val = LLVMConstInt(g->builtin_types.entry_usize->type_ref,
                        actual_type->data.array.len, false);
                LLVMBuildStore(g->builder, len_val, len_ptr);

                return cast_node->ptr;
            }
    }
    zig_unreachable();
}

static LLVMValueRef gen_cast_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeCastExpr);

    LLVMValueRef expr_val = gen_expr(g, node->data.cast_expr.expr);

    TypeTableEntry *actual_type = get_expr_type(node->data.cast_expr.expr);
    TypeTableEntry *wanted_type = get_expr_type(node);

    CastNode *cast_node = &node->codegen_node->data.cast_node;

    return gen_bare_cast(g, node, expr_val, actual_type, wanted_type, cast_node);

}

static LLVMValueRef gen_arithmetic_bin_op(CodeGen *g,
    LLVMValueRef val1, LLVMValueRef val2,
    TypeTableEntry *op1_type, TypeTableEntry *op2_type,
    AstNode *node)
{
    assert(node->type == NodeTypeBinOpExpr);
    assert(op1_type == op2_type);

    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeBinOr:
        case BinOpTypeAssignBitOr:
            add_debug_source_node(g, node);
            return LLVMBuildOr(g->builder, val1, val2, "");
        case BinOpTypeBinXor:
        case BinOpTypeAssignBitXor:
            add_debug_source_node(g, node);
            return LLVMBuildXor(g->builder, val1, val2, "");
        case BinOpTypeBinAnd:
        case BinOpTypeAssignBitAnd:
            add_debug_source_node(g, node);
            return LLVMBuildAnd(g->builder, val1, val2, "");
        case BinOpTypeBitShiftLeft:
        case BinOpTypeAssignBitShiftLeft:
            add_debug_source_node(g, node);
            return LLVMBuildShl(g->builder, val1, val2, "");
        case BinOpTypeBitShiftRight:
        case BinOpTypeAssignBitShiftRight:
            add_debug_source_node(g, node);
            if (op1_type->id == TypeTableEntryIdInt) {
                return LLVMBuildAShr(g->builder, val1, val2, "");
            } else {
                return LLVMBuildLShr(g->builder, val1, val2, "");
            }
        case BinOpTypeAdd:
        case BinOpTypeAssignPlus:
            add_debug_source_node(g, node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFAdd(g->builder, val1, val2, "");
            } else {
                return LLVMBuildNSWAdd(g->builder, val1, val2, "");
            }
        case BinOpTypeSub:
        case BinOpTypeAssignMinus:
            add_debug_source_node(g, node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFSub(g->builder, val1, val2, "");
            } else {
                return LLVMBuildNSWSub(g->builder, val1, val2, "");
            }
        case BinOpTypeMult:
        case BinOpTypeAssignTimes:
            add_debug_source_node(g, node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFMul(g->builder, val1, val2, "");
            } else {
                return LLVMBuildNSWMul(g->builder, val1, val2, "");
            }
        case BinOpTypeDiv:
        case BinOpTypeAssignDiv:
            add_debug_source_node(g, node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFDiv(g->builder, val1, val2, "");
            } else {
                assert(op1_type->id == TypeTableEntryIdInt);
                if (op1_type->data.integral.is_signed) {
                    return LLVMBuildSDiv(g->builder, val1, val2, "");
                } else {
                    return LLVMBuildUDiv(g->builder, val1, val2, "");
                }
            }
        case BinOpTypeMod:
        case BinOpTypeAssignMod:
            add_debug_source_node(g, node);
            if (op1_type->id == TypeTableEntryIdFloat) {
                return LLVMBuildFRem(g->builder, val1, val2, "");
            } else {
                assert(op1_type->id == TypeTableEntryIdInt);
                if (op1_type->data.integral.is_signed) {
                    return LLVMBuildSRem(g->builder, val1, val2, "");
                } else {
                    return LLVMBuildURem(g->builder, val1, val2, "");
                }
            }
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
        case BinOpTypeInvalid:
        case BinOpTypeAssign:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            zig_unreachable();
    }
    zig_unreachable();
}
static LLVMValueRef gen_arithmetic_bin_op_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    TypeTableEntry *op1_type = get_expr_type(node->data.bin_op_expr.op1);
    TypeTableEntry *op2_type = get_expr_type(node->data.bin_op_expr.op2);
    return gen_arithmetic_bin_op(g, val1, val2, op1_type, op2_type, node);

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

static LLVMRealPredicate cmp_op_to_real_predicate(BinOpType cmp_op) {
    switch (cmp_op) {
        case BinOpTypeCmpEq:
            return LLVMRealOEQ;
        case BinOpTypeCmpNotEq:
            return LLVMRealONE;
        case BinOpTypeCmpLessThan:
            return LLVMRealOLT;
        case BinOpTypeCmpGreaterThan:
            return LLVMRealOGT;
        case BinOpTypeCmpLessOrEq:
            return LLVMRealOLE;
        case BinOpTypeCmpGreaterOrEq:
            return LLVMRealOGE;
        default:
            zig_unreachable();
    }
}

static LLVMValueRef gen_cmp_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    TypeTableEntry *op1_type = get_expr_type(node->data.bin_op_expr.op1);
    TypeTableEntry *op2_type = get_expr_type(node->data.bin_op_expr.op2);
    assert(op1_type == op2_type);

    add_debug_source_node(g, node);
    if (op1_type->id == TypeTableEntryIdFloat) {
        LLVMRealPredicate pred = cmp_op_to_real_predicate(node->data.bin_op_expr.bin_op);
        return LLVMBuildFCmp(g->builder, pred, val1, val2, "");
    } else {
        assert(op1_type->id == TypeTableEntryIdInt);
        LLVMIntPredicate pred = cmp_op_to_int_predicate(node->data.bin_op_expr.bin_op,
                op1_type->data.integral.is_signed);
        return LLVMBuildICmp(g->builder, pred, val1, val2, "");
    }
}

static LLVMValueRef gen_bool_and_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMBasicBlockRef post_val1_block = LLVMGetInsertBlock(g->builder);

    // block for when val1 == true
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolAndTrue");
    // block for when val1 == false (don't even evaluate the second part)
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolAndFalse");

    add_debug_source_node(g, node);
    LLVMBuildCondBr(g->builder, val1, true_block, false_block);

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);
    LLVMBasicBlockRef post_val2_block = LLVMGetInsertBlock(g->builder);

    add_debug_source_node(g, node);
    LLVMBuildBr(g->builder, false_block);

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    add_debug_source_node(g, node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef incoming_values[2] = {val1, val2};
    LLVMBasicBlockRef incoming_blocks[2] = {post_val1_block, post_val2_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_bool_or_expr(CodeGen *g, AstNode *expr_node) {
    assert(expr_node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, expr_node->data.bin_op_expr.op1);
    LLVMBasicBlockRef post_val1_block = LLVMGetInsertBlock(g->builder);

    // block for when val1 == false
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolOrFalse");
    // block for when val1 == true (don't even evaluate the second part)
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "BoolOrTrue");

    add_debug_source_node(g, expr_node);
    LLVMBuildCondBr(g->builder, val1, true_block, false_block);

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    LLVMValueRef val2 = gen_expr(g, expr_node->data.bin_op_expr.op2);

    LLVMBasicBlockRef post_val2_block = LLVMGetInsertBlock(g->builder);

    add_debug_source_node(g, expr_node);
    LLVMBuildBr(g->builder, true_block);

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    add_debug_source_node(g, expr_node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef incoming_values[2] = {val1, val2};
    LLVMBasicBlockRef incoming_blocks[2] = {post_val1_block, post_val2_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_assign_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    AstNode *lhs_node = node->data.bin_op_expr.op1;

    TypeTableEntry *op1_type;

    LLVMValueRef target_ref = gen_lvalue(g, node, lhs_node, &op1_type);

    LLVMValueRef value = gen_expr(g, node->data.bin_op_expr.op2);

    if (node->data.bin_op_expr.bin_op == BinOpTypeAssign) {
        // value is ready as is
    } else {
        add_debug_source_node(g, node->data.bin_op_expr.op1);
        LLVMValueRef left_value = LLVMBuildLoad(g->builder, target_ref, "");

        TypeTableEntry *op2_type = get_expr_type(node->data.bin_op_expr.op2);
        value = gen_arithmetic_bin_op(g, left_value, value, op1_type, op2_type, node);
    }

    add_debug_source_node(g, node);
    return LLVMBuildStore(g->builder, value, target_ref);
}

static LLVMValueRef gen_bin_op_expr(CodeGen *g, AstNode *node) {
    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeInvalid:
            zig_unreachable();
        case BinOpTypeAssign:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftRight:
        case BinOpTypeAssignBitAnd:
        case BinOpTypeAssignBitXor:
        case BinOpTypeAssignBitOr:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            return gen_assign_expr(g, node);
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
    bool use_expr_value = (then_type->id != TypeTableEntryIdUnreachable &&
                           then_type->id != TypeTableEntryIdVoid);

    if (node->data.if_expr.else_node) {
        LLVMBasicBlockRef then_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "Then");
        LLVMBasicBlockRef else_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "Else");
        LLVMBasicBlockRef endif_block = LLVMAppendBasicBlock(g->cur_fn->fn_value, "EndIf");

        LLVMBuildCondBr(g->builder, cond_value, then_block, else_block);

        LLVMPositionBuilderAtEnd(g->builder, then_block);
        LLVMValueRef then_expr_result = gen_expr(g, node->data.if_expr.then_block);
        if (get_expr_type(node->data.if_expr.then_block)->id != TypeTableEntryIdUnreachable)
            LLVMBuildBr(g->builder, endif_block);

        LLVMPositionBuilderAtEnd(g->builder, else_block);
        LLVMValueRef else_expr_result = gen_expr(g, node->data.if_expr.else_node);
        if (get_expr_type(node->data.if_expr.else_node)->id != TypeTableEntryIdUnreachable)
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
    if (get_expr_type(node->data.if_expr.then_block)->id != TypeTableEntryIdUnreachable)
        LLVMBuildBr(g->builder, endif_block);

    LLVMPositionBuilderAtEnd(g->builder, endif_block);
    return nullptr;
}

static LLVMValueRef gen_block(CodeGen *g, AstNode *block_node, TypeTableEntry *implicit_return_type) {
    assert(block_node->type == NodeTypeBlock);

    BlockContext *old_block_context = g->cur_block_context;
    g->cur_block_context = block_node->codegen_node->data.block_node.block_context;

    LLVMValueRef return_value;
    for (int i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        return_value = gen_expr(g, statement_node);
    }

    if (implicit_return_type) {
        add_debug_source_node(g, block_node);
        if (implicit_return_type->id == TypeTableEntryIdVoid) {
            LLVMBuildRetVoid(g->builder);
        } else if (implicit_return_type->id != TypeTableEntryIdUnreachable) {
            LLVMBuildRet(g->builder, return_value);
        }
    }

    g->cur_block_context = old_block_context;

    return return_value;
}

static int find_asm_index(CodeGen *g, AstNode *node, AsmToken *tok) {
    const char *ptr = buf_ptr(&node->data.asm_expr.asm_template) + tok->start + 2;
    int len = tok->end - tok->start - 2;
    int result = 0;
    for (int i = 0; i < node->data.asm_expr.output_list.length; i += 1, result += 1) {
        AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
        if (buf_eql_mem(&asm_output->asm_symbolic_name, ptr, len)) {
            return result;
        }
    }
    for (int i = 0; i < node->data.asm_expr.input_list.length; i += 1, result += 1) {
        AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
        if (buf_eql_mem(&asm_input->asm_symbolic_name, ptr, len)) {
            return result;
        }
    }
    return -1;
}

static LLVMValueRef gen_asm_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeAsmExpr);

    AstNodeAsmExpr *asm_expr = &node->data.asm_expr;

    Buf *src_template = &asm_expr->asm_template;

    Buf llvm_template = BUF_INIT;
    buf_resize(&llvm_template, 0);

    for (int token_i = 0; token_i < asm_expr->token_list.length; token_i += 1) {
        AsmToken *asm_token = &asm_expr->token_list.at(token_i);
        switch (asm_token->id) {
            case AsmTokenIdTemplate:
                for (int offset = asm_token->start; offset < asm_token->end; offset += 1) {
                    uint8_t c = *((uint8_t*)(buf_ptr(src_template) + offset));
                    if (c == '$') {
                        buf_append_str(&llvm_template, "$$");
                    } else {
                        buf_append_char(&llvm_template, c);
                    }
                }
                break;
            case AsmTokenIdPercent:
                buf_append_char(&llvm_template, '%');
                break;
            case AsmTokenIdVar:
                int index = find_asm_index(g, node, asm_token);
                assert(index >= 0);
                buf_appendf(&llvm_template, "$%d", index);
                break;
        }
    }

    Buf constraint_buf = BUF_INIT;
    buf_resize(&constraint_buf, 0);

    assert(asm_expr->return_count == 0 || asm_expr->return_count == 1);

    int total_constraint_count = asm_expr->output_list.length +
                                 asm_expr->input_list.length +
                                 asm_expr->clobber_list.length;
    int input_and_output_count = asm_expr->output_list.length +
                                 asm_expr->input_list.length -
                                 asm_expr->return_count;
    int total_index = 0;
    int param_index = 0;
    LLVMTypeRef *param_types = allocate<LLVMTypeRef>(input_and_output_count);
    LLVMValueRef *param_values = allocate<LLVMValueRef>(input_and_output_count);
    for (int i = 0; i < asm_expr->output_list.length; i += 1, total_index += 1) {
        AsmOutput *asm_output = asm_expr->output_list.at(i);
        bool is_return = (asm_output->return_type != nullptr);
        assert(*buf_ptr(&asm_output->constraint) == '=');
        if (is_return) {
            buf_appendf(&constraint_buf, "=%s", buf_ptr(&asm_output->constraint) + 1);
        } else {
            buf_appendf(&constraint_buf, "=*%s", buf_ptr(&asm_output->constraint) + 1);
        }
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        if (!is_return) {
            VariableTableEntry *variable = find_variable(
                    node->codegen_node->expr_node.block_context,
                    &asm_output->variable_name);
            assert(variable);
            param_types[param_index] = LLVMTypeOf(variable->value_ref);
            param_values[param_index] = variable->value_ref;
            param_index += 1;
        }
    }
    for (int i = 0; i < asm_expr->input_list.length; i += 1, total_index += 1, param_index += 1) {
        AsmInput *asm_input = asm_expr->input_list.at(i);
        buf_append_buf(&constraint_buf, &asm_input->constraint);
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }

        TypeTableEntry *expr_type = get_expr_type(asm_input->expr);
        param_types[param_index] = expr_type->type_ref;
        param_values[param_index] = gen_expr(g, asm_input->expr);
    }
    for (int i = 0; i < asm_expr->clobber_list.length; i += 1, total_index += 1) {
        Buf *clobber_buf = asm_expr->clobber_list.at(i);
        buf_appendf(&constraint_buf, "~{%s}", buf_ptr(clobber_buf));
        if (total_index + 1 < total_constraint_count) {
            buf_append_char(&constraint_buf, ',');
        }
    }

    LLVMTypeRef ret_type;
    if (asm_expr->return_count == 0) {
        ret_type = LLVMVoidType();
    } else {
        ret_type = get_expr_type(node)->type_ref;
    }
    LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, input_and_output_count, false);

    bool is_volatile = asm_expr->is_volatile || (asm_expr->output_list.length == 0);
    LLVMValueRef asm_fn = LLVMConstInlineAsm(function_type, buf_ptr(&llvm_template),
            buf_ptr(&constraint_buf), is_volatile, false);

    add_debug_source_node(g, node);
    return LLVMBuildCall(g->builder, asm_fn, param_values, input_and_output_count, "");
}

static LLVMValueRef gen_expr_no_cast(CodeGen *g, AstNode *node) {
    switch (node->type) {
        case NodeTypeBinOpExpr:
            return gen_bin_op_expr(g, node);
        case NodeTypeReturnExpr:
            return gen_return_expr(g, node);
        case NodeTypeVariableDeclaration:
            {
                VariableTableEntry *variable = find_variable(
                        node->codegen_node->expr_node.block_context,
                        &node->data.variable_declaration.symbol);

                assert(variable);
                assert(variable->is_ptr);

                LLVMValueRef value;
                if (node->data.variable_declaration.expr) {
                    value = gen_expr(g, node->data.variable_declaration.expr);
                } else {
                    value = LLVMConstNull(variable->type->type_ref);
                }
                if (variable->type->id == TypeTableEntryIdVoid) {
                    return nullptr;
                } else {
                    add_debug_source_node(g, node);
                    LLVMValueRef store_instr = LLVMBuildStore(g->builder, value, variable->value_ref);

                    LLVMZigDILocation *debug_loc = LLVMZigGetDebugLoc(node->line + 1, node->column + 1,
                            g->cur_block_context->di_scope);
                    LLVMZigInsertDeclare(g->dbuilder, variable->value_ref, variable->di_loc_var,
                            debug_loc, store_instr);
                    return nullptr;
                }
            }
        case NodeTypeCastExpr:
            return gen_cast_expr(g, node);
        case NodeTypePrefixOpExpr:
            return gen_prefix_op_expr(g, node);
        case NodeTypeFnCallExpr:
            return gen_fn_call_expr(g, node);
        case NodeTypeArrayAccessExpr:
            return gen_array_access_expr(g, node, false);
        case NodeTypeFieldAccessExpr:
            return gen_field_access_expr(g, node, false);
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
        case NodeTypeAsmExpr:
            return gen_asm_expr(g, node);
        case NodeTypeNumberLiteral:
            {
                NumberLiteralNode *codegen_num_lit = &node->codegen_node->data.num_lit_node;
                assert(codegen_num_lit);
                TypeTableEntry *type_entry = codegen_num_lit->resolved_type;
                assert(type_entry);

                // TODO this is kinda iffy. make sure josh is on board with this
                node->codegen_node->expr_node.type_entry = type_entry;

                if (type_entry->id == TypeTableEntryIdInt) {
                    // here the union has int64_t and uint64_t and we purposefully read
                    // the uint64_t value in either case, because we want the twos
                    // complement representation

                    return LLVMConstInt(type_entry->type_ref,
                            node->data.number_literal.data.x_uint,
                            type_entry->data.integral.is_signed);
                } else if (type_entry->id == TypeTableEntryIdFloat) {

                    return LLVMConstReal(type_entry->type_ref,
                            node->data.number_literal.data.x_float);
                } else {
                    zig_panic("bad number literal type");
                }
            }
        case NodeTypeStringLiteral:
            {
                Buf *str = &node->data.string_literal.buf;
                LLVMValueRef str_val = find_or_create_string(g, str, node->data.string_literal.c);
                LLVMValueRef indices[] = {
                    LLVMConstInt(LLVMInt32Type(), 0, false),
                    LLVMConstInt(LLVMInt32Type(), 0, false)
                };
                LLVMValueRef ptr_val = LLVMBuildInBoundsGEP(g->builder, str_val, indices, 2, "");
                return ptr_val;
            }
        case NodeTypeSymbol:
            {
                VariableTableEntry *variable = find_variable(
                        node->codegen_node->expr_node.block_context,
                        &node->data.symbol);
                assert(variable);
                if (variable->type->id == TypeTableEntryIdVoid) {
                    return nullptr;
                } else if (variable->is_ptr) {
                    assert(variable->value_ref);
                    if (variable->type->id == TypeTableEntryIdArray) {
                        return variable->value_ref;
                    } else if (variable->type->id == TypeTableEntryIdStruct) {
                        return variable->value_ref;
                    } else {
                        add_debug_source_node(g, node);
                        return LLVMBuildLoad(g->builder, variable->value_ref, "");
                    }
                } else {
                    return variable->value_ref;
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
        case NodeTypeStructDecl:
        case NodeTypeStructField:
            zig_unreachable();
    }
    zig_unreachable();
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *node) {
    LLVMValueRef val = gen_expr_no_cast(g, node);

    if (node->type == NodeTypeVoid) {
        return val;
    }

    assert(node->codegen_node);

    TypeTableEntry *actual_type = node->codegen_node->expr_node.type_entry;
    TypeTableEntry *cast_type = node->codegen_node->expr_node.implicit_cast.type;

    return cast_type ? gen_bare_cast(g, node, val, actual_type, cast_type,
            &node->codegen_node->expr_node.implicit_cast) : val;
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
    types[0] = to_llvm_debug_type(g, fn_proto->return_type);
    int types_len = fn_proto->params.length + 1;
    for (int i = 0; i < fn_proto->params.length; i += 1) {
        AstNode *param_node = fn_proto->params.at(i);
        assert(param_node->type == NodeTypeParamDecl);
        LLVMZigDIType *param_type = to_llvm_debug_type(g, param_node->data.param_decl.type);
        types[i + 1] = param_type;
    }
    return LLVMZigCreateSubroutineType(g->dbuilder, di_file, types, types_len, 0);
}

static LLVMAttribute to_llvm_fn_attr(FnAttrId attr_id) {
    switch (attr_id) {
        case FnAttrIdNaked:
            return LLVMNakedAttribute;
        case FnAttrIdAlwaysInline:
            return LLVMAlwaysInlineAttribute;
    }
    zig_unreachable();
}

static void do_code_gen(CodeGen *g) {
    assert(!g->errors.length);

    // Generate module level variables
    for (int i = 0; i < g->global_vars.length; i += 1) {
        VariableTableEntry *var = g->global_vars.at(i);

        // TODO if the global is exported, set external linkage
        LLVMValueRef global_value = LLVMAddGlobal(g->module, var->type->type_ref, "");
        LLVMSetLinkage(global_value, LLVMPrivateLinkage);

        if (var->is_const) {
            LLVMValueRef init_val = gen_expr(g, var->decl_node->data.variable_declaration.expr);
            LLVMSetInitializer(global_value, init_val);
        } else {
            LLVMSetInitializer(global_value, LLVMConstNull(var->type->type_ref));
        }
        LLVMSetGlobalConstant(global_value, var->is_const);
        LLVMSetUnnamedAddr(global_value, true);

        var->value_ref = global_value;
    }

    // Generate function prototypes
    for (int fn_proto_i = 0; fn_proto_i < g->fn_protos.length; fn_proto_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_protos.at(fn_proto_i);

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        LLVMTypeRef ret_type = get_type_for_type_node(g, fn_proto->return_type)->type_ref;
        int param_count = count_non_void_params(g, &fn_proto->params);
        LLVMTypeRef *param_types = allocate<LLVMTypeRef>(param_count);
        int gen_param_index = 0;
        for (int param_decl_i = 0; param_decl_i < fn_proto->params.length; param_decl_i += 1) {
            AstNode *param_node = fn_proto->params.at(param_decl_i);
            assert(param_node->type == NodeTypeParamDecl);
            if (is_param_decl_type_void(g, param_node))
                continue;
            AstNode *type_node = param_node->data.param_decl.type;
            param_types[gen_param_index] = fn_proto_type_from_type_node(g, type_node);
            gen_param_index += 1;
        }
        LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, param_count, fn_proto->is_var_args);
        LLVMValueRef fn = LLVMAddFunction(g->module, buf_ptr(&fn_proto->name), function_type);

        for (int attr_i = 0; attr_i < fn_table_entry->fn_attr_list.length; attr_i += 1) {
            FnAttrId attr_id = fn_table_entry->fn_attr_list.at(attr_i);
            LLVMAddFunctionAttr(fn, to_llvm_fn_attr(attr_id));
        }

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
    for (int fn_i = 0; fn_i < g->fn_defs.length; fn_i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(fn_i);
        ImportTableEntry *import = fn_table_entry->import_entry;
        AstNode *fn_def_node = fn_table_entry->fn_def_node;
        LLVMValueRef fn = fn_table_entry->fn_value;
        g->cur_fn = fn_table_entry;

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        // Add debug info.
        unsigned line_number = fn_def_node->line + 1;
        unsigned scope_line = line_number;
        bool is_definition = true;
        unsigned flags = 0;
        bool is_optimized = g->build_type == CodeGenBuildTypeRelease;
        LLVMZigDISubprogram *subprogram = LLVMZigCreateFunction(g->dbuilder,
            import->block_context->di_scope, buf_ptr(&fn_proto->name), "", import->di_file, line_number,
            create_di_function_type(g, fn_proto, import->di_file), fn_table_entry->internal_linkage, 
            is_definition, scope_line, flags, is_optimized, fn);

        LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn, "entry");
        LLVMPositionBuilderAtEnd(g->builder, entry_block);

        CodeGenNode *codegen_node = fn_def_node->codegen_node;
        assert(codegen_node);

        FnDefNode *codegen_fn_def = &codegen_node->data.fn_def_node;
        assert(codegen_fn_def);

        codegen_fn_def->block_context->di_scope = LLVMZigSubprogramToScope(subprogram);

        int non_void_param_count = count_non_void_params(g, &fn_proto->params);
        assert(non_void_param_count == (int)LLVMCountParams(fn));
        LLVMValueRef *params = allocate<LLVMValueRef>(non_void_param_count);
        LLVMGetParams(fn, params);

        int non_void_index = 0;
        for (int param_i = 0; param_i < fn_proto->params.length; param_i += 1) {
            AstNode *param_decl = fn_proto->params.at(param_i);
            assert(param_decl->type == NodeTypeParamDecl);
            if (is_param_decl_type_void(g, param_decl))
                continue;
            VariableTableEntry *parameter_variable = fn_def_node->codegen_node->data.fn_def_node.block_context->variable_table.get(&param_decl->data.param_decl.name);
            parameter_variable->value_ref = params[non_void_index];
            non_void_index += 1;
        }

        build_label_blocks(g, fn_def_node->data.fn_def.body);

        // Set up debug info for blocks and variables and
        // allocate all local variables
        for (int bc_i = 0; bc_i < fn_table_entry->all_block_contexts.length; bc_i += 1) {
            BlockContext *block_context = fn_table_entry->all_block_contexts.at(bc_i);

            if (!block_context->di_scope) {
                LLVMZigDILexicalBlock *di_block = LLVMZigCreateLexicalBlock(g->dbuilder,
                    block_context->parent->di_scope,
                    import->di_file,
                    block_context->node->line + 1,
                    block_context->node->column + 1);
                block_context->di_scope = LLVMZigLexicalBlockToScope(di_block);
            }

            g->cur_block_context = block_context;

            auto it = block_context->variable_table.entry_iterator();
            for (;;) {
                auto *entry = it.next();
                if (!entry)
                    break;

                VariableTableEntry *var = entry->value;
                if (var->type->id == TypeTableEntryIdVoid)
                    continue;

                unsigned tag;
                unsigned arg_no;
                if (block_context->node->type == NodeTypeFnDef) {
                    tag = LLVMZigTag_DW_arg_variable();
                    arg_no = var->arg_index + 1;
                } else {
                    tag = LLVMZigTag_DW_auto_variable();
                    arg_no = 0;

                    add_debug_source_node(g, var->decl_node);
                    var->value_ref = LLVMBuildAlloca(g->builder, var->type->type_ref, buf_ptr(&var->name));
                }

                var->di_loc_var = LLVMZigCreateLocalVariable(g->dbuilder, tag,
                        block_context->di_scope, buf_ptr(&var->name),
                        import->di_file, var->decl_node->line + 1,
                        var->type->di_type, !g->strip_debug_symbols, 0, arg_no);
            }

            // allocate structs which are the result of casts
            for (int cea_i = 0; cea_i < block_context->cast_expr_alloca_list.length; cea_i += 1) {
                CastNode *cast_node = block_context->cast_expr_alloca_list.at(cea_i);
                add_debug_source_node(g, cast_node->source_node);
                cast_node->ptr = LLVMBuildAlloca(g->builder, cast_node->type->type_ref, "");
            }
        }

        TypeTableEntry *implicit_return_type = codegen_fn_def->implicit_return_type;
        gen_block(g, fn_def_node->data.fn_def.body, implicit_return_type);

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

static const NumLit num_lit_kinds[] = {
    NumLitF32,
    NumLitF64,
    NumLitF128,
    NumLitU8,
    NumLitU16,
    NumLitU32,
    NumLitU64,
};

static void define_builtin_types(CodeGen *g) {
    {
        // if this type is anywhere in the AST, we should never hit codegen.
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInvalid);
        buf_init_from_str(&entry->name, "(invalid)");
        g->builtin_types.entry_invalid = entry;
    }

    assert(NumLitCount == array_length(num_lit_kinds));
    for (int i = 0; i < NumLitCount; i += 1) {
        NumLit num_lit_kind = num_lit_kinds[i];
        // This type should just create a constant with whatever actual number
        // type is expected at the time.
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdNumberLiteral);
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "(%s literal)", num_lit_str(num_lit_kind));
        entry->data.num_lit.kind = num_lit_kind;
        g->num_lit_types[i] = entry;
    }

    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdBool);
        entry->type_ref = LLVMInt1Type();
        buf_init_from_str(&entry->name, "bool");
        entry->size_in_bits = 1;
        entry->align_in_bits = 8;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_bool = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMInt8Type();
        buf_init_from_str(&entry->name, "u8");
        entry->size_in_bits = 8;
        entry->align_in_bits = 8;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_u8 = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMInt32Type();
        buf_init_from_str(&entry->name, "u32");
        entry->size_in_bits = 32;
        entry->align_in_bits = 32;
        entry->data.integral.is_signed = false;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_u32 = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMInt64Type();
        buf_init_from_str(&entry->name, "u64");
        entry->size_in_bits = 64;
        entry->align_in_bits = 64;
        entry->data.integral.is_signed = false;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_u64 = entry;
    }
    g->builtin_types.entry_c_string_literal = get_pointer_to_type(g, g->builtin_types.entry_u8, true);
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMInt8Type();
        buf_init_from_str(&entry->name, "i8");
        entry->size_in_bits = 8;
        entry->align_in_bits = 8;
        entry->data.integral.is_signed = true;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_signed());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_i8 = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMInt32Type();
        buf_init_from_str(&entry->name, "i32");
        entry->size_in_bits = 32;
        entry->align_in_bits = 32;
        entry->data.integral.is_signed = true;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_signed());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_i32 = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMInt64Type();
        buf_init_from_str(&entry->name, "i64");
        entry->size_in_bits = 64;
        entry->align_in_bits = 64;
        entry->data.integral.is_signed = true;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_signed());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_i64 = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMIntType(g->pointer_size_bytes * 8);
        buf_init_from_str(&entry->name, "isize");
        entry->size_in_bits = g->pointer_size_bytes * 8;
        entry->align_in_bits = g->pointer_size_bytes * 8;
        entry->data.integral.is_signed = true;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_signed());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_isize = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
        entry->type_ref = LLVMIntType(g->pointer_size_bytes * 8);
        buf_init_from_str(&entry->name, "usize");
        entry->size_in_bits = g->pointer_size_bytes * 8;
        entry->align_in_bits = g->pointer_size_bytes * 8;
        entry->data.integral.is_signed = false;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_usize = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->type_ref = LLVMFloatType();
        buf_init_from_str(&entry->name, "f32");
        entry->size_in_bits = 32;
        entry->align_in_bits = 32;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_float());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_f32 = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdFloat);
        entry->type_ref = LLVMDoubleType();
        buf_init_from_str(&entry->name, "f64");
        entry->size_in_bits = 64;
        entry->align_in_bits = 64;
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_float());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_f64 = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdVoid);
        entry->type_ref = LLVMVoidType();
        buf_init_from_str(&entry->name, "void");
        entry->di_type = LLVMZigCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name),
                entry->size_in_bits, entry->align_in_bits,
                LLVMZigEncoding_DW_ATE_unsigned());
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_void = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdUnreachable);
        entry->type_ref = LLVMVoidType();
        buf_init_from_str(&entry->name, "unreachable");
        entry->di_type = g->builtin_types.entry_void->di_type;
        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_unreachable = entry;
    }
    {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdStruct);

        TypeTableEntry *const_pointer_to_u8 = get_pointer_to_type(g, g->builtin_types.entry_u8, true);

        unsigned element_count = 2;
        LLVMTypeRef element_types[] = {
            const_pointer_to_u8->type_ref,
            g->builtin_types.entry_usize->type_ref
        };
        entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), "string");
        LLVMStructSetBody(entry->type_ref, element_types, element_count, false);

        buf_init_from_str(&entry->name, "string");
        entry->size_in_bits = g->pointer_size_bytes * 2 * 8;
        entry->align_in_bits = g->pointer_size_bytes;
        entry->data.structure.is_packed = false;
        entry->data.structure.field_count = element_count;
        entry->data.structure.fields = allocate<TypeStructField>(element_count);
        entry->data.structure.fields[0].name = buf_create_from_str("ptr");
        entry->data.structure.fields[0].type_entry = const_pointer_to_u8;
        entry->data.structure.fields[1].name = buf_create_from_str("len");
        entry->data.structure.fields[1].type_entry = g->builtin_types.entry_usize;

        LLVMZigDIType *di_element_types[] = {
            const_pointer_to_u8->di_type,
            g->builtin_types.entry_usize->di_type
        };
        LLVMZigDIScope *compile_unit_scope = LLVMZigCompileUnitToScope(g->compile_unit);
        entry->di_type = LLVMZigCreateDebugStructType(g->dbuilder, compile_unit_scope,
                "string", g->dummy_di_file, 0, entry->size_in_bits, entry->align_in_bits, 0,
                nullptr, di_element_types, element_count, 0, nullptr, "");

        g->type_table.put(&entry->name, entry);
        g->builtin_types.entry_string = entry;
    }
}



static void init(CodeGen *g, Buf *source_path) {
    g->lib_search_paths.append(g->root_source_dir);
    g->lib_search_paths.append(buf_create_from_str(ZIG_STD_DIR));

    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetMCs();
    LLVMInitializeAllAsmPrinters();
    LLVMInitializeAllAsmParsers();
    LLVMInitializeNativeTarget();

    g->is_native_target = true;
    char *native_triple = LLVMGetDefaultTargetTriple();

    g->module = LLVMModuleCreateWithName(buf_ptr(source_path));

    LLVMSetTarget(g->module, native_triple);

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

    char *layout_str = LLVMCopyStringRepOfTargetData(g->target_data_ref);
    LLVMSetDataLayout(g->module, layout_str);


    g->pointer_size_bytes = LLVMPointerSize(g->target_data_ref);

    g->builder = LLVMCreateBuilder();
    g->dbuilder = LLVMZigCreateDIBuilder(g->module, true);

    LLVMZigSetFastMath(g->builder, true);


    Buf *producer = buf_sprintf("zig %s", ZIG_VERSION_STRING);
    bool is_optimized = g->build_type == CodeGenBuildTypeRelease;
    const char *flags = "";
    unsigned runtime_version = 0;
    g->compile_unit = LLVMZigCreateCompileUnit(g->dbuilder, LLVMZigLang_DW_LANG_C99(),
            buf_ptr(source_path), buf_ptr(g->root_source_dir),
            buf_ptr(producer), is_optimized, flags, runtime_version,
            "", 0, !g->strip_debug_symbols);

    // This is for debug stuff that doesn't have a real file.
    g->dummy_di_file = nullptr; //LLVMZigCreateFile(g->dbuilder, "", "");

    define_builtin_types(g);

}

static bool directives_contains_link_libc(ZigList<AstNode*> *directives) {
    for (int i = 0; i < directives->length; i += 1) {
        AstNode *directive_node = directives->at(i);
        if (buf_eql_str(&directive_node->data.directive.name, "link") &&
            buf_eql_str(&directive_node->data.directive.param, "c"))
        {
            return true;
        }
    }
    return false;
}

static ImportTableEntry *codegen_add_code(CodeGen *g, Buf *abs_full_path,
        Buf *src_dirname, Buf *src_basename, Buf *source_code)
{
    int err;
    Buf *full_path = buf_alloc();
    os_path_join(src_dirname, src_basename, full_path);

    if (g->verbose) {
        fprintf(stderr, "\nOriginal Source (%s):\n", buf_ptr(full_path));
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
        err->path = full_path;
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
    import_entry->path = full_path;
    import_entry->fn_table.init(32);
    import_entry->root = ast_parse(source_code, tokenization.tokens, import_entry, g->err_color);
    assert(import_entry->root);
    if (g->verbose) {
        ast_print(import_entry->root, 0);
    }

    import_entry->di_file = LLVMZigCreateFile(g->dbuilder, buf_ptr(src_basename), buf_ptr(src_dirname));
    g->import_table.put(abs_full_path, import_entry);

    import_entry->block_context = new_block_context(import_entry->root, nullptr);
    import_entry->block_context->di_scope = LLVMZigFileToScope(import_entry->di_file);


    assert(import_entry->root->type == NodeTypeRoot);
    for (int decl_i = 0; decl_i < import_entry->root->data.root.top_level_decls.length; decl_i += 1) {
        AstNode *top_level_decl = import_entry->root->data.root.top_level_decls.at(decl_i);

        if (top_level_decl->type == NodeTypeUse) {
            Buf *import_target_path = &top_level_decl->data.use.path;
            Buf full_path = BUF_INIT;
            Buf *import_code = buf_alloc();
            bool found_it = false;

            for (int path_i = 0; path_i < g->lib_search_paths.length; path_i += 1) {
                Buf *search_path = g->lib_search_paths.at(path_i);
                os_path_join(search_path, import_target_path, &full_path);

                Buf *abs_full_path = buf_alloc();
                if ((err = os_path_real(&full_path, abs_full_path))) {
                    if (err == ErrorFileNotFound) {
                        continue;
                    } else {
                        add_node_error(g, top_level_decl,
                                buf_sprintf("unable to open '%s': %s", buf_ptr(&full_path), err_str(err)));
                        goto done_looking_at_imports;
                    }
                }

                auto entry = g->import_table.maybe_get(abs_full_path);
                if (entry) {
                    found_it = true;
                } else {
                    if ((err = os_fetch_file_path(abs_full_path, import_code))) {
                        if (err == ErrorFileNotFound) {
                            continue;
                        } else {
                            add_node_error(g, top_level_decl,
                                    buf_sprintf("unable to open '%s': %s", buf_ptr(&full_path), err_str(err)));
                            goto done_looking_at_imports;
                        }
                    }
                    codegen_add_code(g, abs_full_path, search_path, &top_level_decl->data.use.path, import_code);
                    found_it = true;
                }
                break;
            }
            if (!found_it) {
                add_node_error(g, top_level_decl,
                        buf_sprintf("unable to find '%s'", buf_ptr(import_target_path)));
            }
        } else if (top_level_decl->type == NodeTypeFnDef) {
            AstNode *proto_node = top_level_decl->data.fn_def.fn_proto;
            assert(proto_node->type == NodeTypeFnProto);
            Buf *proto_name = &proto_node->data.fn_proto.name;

            bool is_private = (proto_node->data.fn_proto.visib_mod == FnProtoVisibModPrivate);

            if (buf_eql_str(proto_name, "main") && !is_private) {
                g->have_exported_main = true;
            }
        } else if (top_level_decl->type == NodeTypeExternBlock) {
            g->link_libc = directives_contains_link_libc(top_level_decl->data.extern_block.directives);
        }
    }

done_looking_at_imports:

    return import_entry;
}

void codegen_add_root_code(CodeGen *g, Buf *src_dir, Buf *src_basename, Buf *source_code) {
    Buf source_path = BUF_INIT;
    os_path_join(src_dir, src_basename, &source_path);
    init(g, &source_path);

    Buf *abs_full_path = buf_alloc();
    int err;
    if ((err = os_path_real(&source_path, abs_full_path))) {
        zig_panic("unable to open '%s': %s", buf_ptr(&source_path), err_str(err));
    }

    g->root_import = codegen_add_code(g, abs_full_path, src_dir, src_basename, source_code);

    if (g->have_exported_main && !g->link_libc && g->out_type != OutTypeLib) {
        Buf *bootstrap_dir = buf_create_from_str(ZIG_STD_DIR);
        Buf *bootstrap_basename = buf_create_from_str("bootstrap.zig");
        Buf path_to_bootstrap_src = BUF_INIT;
        os_path_join(bootstrap_dir, bootstrap_basename, &path_to_bootstrap_src);
        Buf *abs_full_path = buf_alloc();
        if ((err = os_path_real(&path_to_bootstrap_src, abs_full_path))) {
            zig_panic("unable to open '%s': %s", buf_ptr(&path_to_bootstrap_src), err_str(err));
        }
        Buf *import_code = buf_alloc();
        int err;
        if ((err = os_fetch_file_path(abs_full_path, import_code))) {
            zig_panic("unable to open '%s': %s", buf_ptr(&path_to_bootstrap_src), err_str(err));
        }

        codegen_add_code(g, abs_full_path, bootstrap_dir, bootstrap_basename, import_code);
    }

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
    } else if (type_entry == g->builtin_types.entry_isize) {
        g->c_stdint_used = true;
        buf_init_from_str(out_buf, "intptr_t");
    } else if (type_entry == g->builtin_types.entry_f32) {
        buf_init_from_str(out_buf, "float");
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

static void find_libc_path(CodeGen *g) {
    if (g->libc_path && buf_len(g->libc_path))
        return;
    g->libc_path = buf_create_from_str(ZIG_LIBC_DIR);
    if (g->libc_path && buf_len(g->libc_path))
        return;
    fprintf(stderr, "Unable to determine libc path. Consider using `--libc-path [path]`\n");
    exit(1);
}

static const char *get_libc_file(CodeGen *g, const char *file) {
    Buf *out_buf = buf_alloc();
    os_path_join(g->libc_path, buf_create_from_str(file), out_buf);
    return buf_ptr(out_buf);
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
        if (g->verbose) {
            fprintf(stderr, "OK\n");
        }
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
    const char *crt1o;
    if (g->is_static) {
        args.append("-static");
        crt1o = "crt1.o";
    } else {
        crt1o = "Scrt1.o";
    }

    // TODO don't pass this parameter unless linking with libc
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

    bool link_in_crt = (g->link_libc && g->out_type == OutTypeExe);

    if (link_in_crt) {
        find_libc_path(g);

        args.append(get_libc_file(g, crt1o));
        args.append(get_libc_file(g, "crti.o"));
    }

    args.append((const char *)buf_ptr(&out_file_o));

    if (link_in_crt) {
        args.append(get_libc_file(g, "crtn.o"));
    }

    auto it = g->link_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        Buf *arg = buf_sprintf("-l%s", buf_ptr(entry->key));
        args.append(buf_ptr(arg));
    }

    if (g->verbose) {
        fprintf(stderr, "ld");
        for (int i = 0; i < args.length; i += 1) {
            fprintf(stderr, " %s", args.at(i));
        }
        fprintf(stderr, "\n");
    }

    int return_code;
    Buf ld_stderr = BUF_INIT;
    Buf ld_stdout = BUF_INIT;
    os_exec_process("ld", args, &return_code, &ld_stderr, &ld_stdout);

    if (return_code != 0) {
        fprintf(stderr, "ld failed with return code %d\n", return_code);
        fprintf(stderr, "%s\n", buf_ptr(&ld_stderr));
        exit(1);
    } else if (buf_len(&ld_stderr)) {
        fprintf(stderr, "%s\n", buf_ptr(&ld_stderr));
    }

    if (g->out_type == OutTypeLib) {
        generate_h_file(g);
    }

    if (g->verbose) {
        fprintf(stderr, "OK\n");
    }
}
