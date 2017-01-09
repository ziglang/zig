/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ir.hpp"
#include "ir_print.hpp"

struct IrPrint {
    FILE *f;
    int indent;
    int indent_size;
};

static void ir_print_other_instruction(IrPrint *irp, IrInstruction *instruction);

static void ir_print_indent(IrPrint *irp) {
    for (int i = 0; i < irp->indent; i += 1) {
        fprintf(irp->f, " ");
    }
}

static void ir_print_prefix(IrPrint *irp, IrInstruction *instruction) {
    ir_print_indent(irp);
    const char *type_name = instruction->value.type ? buf_ptr(&instruction->value.type->name) : "(unknown)";
    const char *ref_count = ir_has_side_effects(instruction) ?
        "-" : buf_ptr(buf_sprintf("%zu", instruction->ref_count));
    fprintf(irp->f, "#%-3zu| %-12s| %-2s| ", instruction->debug_id, type_name, ref_count);
}

static void ir_print_const_value(IrPrint *irp, ConstExprValue *const_val) {
    Buf buf = BUF_INIT;
    buf_resize(&buf, 0);
    render_const_value(&buf, const_val);
    fprintf(irp->f, "%s", buf_ptr(&buf));
}

static void ir_print_var_instruction(IrPrint *irp, IrInstruction *instruction) {
    fprintf(irp->f, "#%zu", instruction->debug_id);
}

static void ir_print_other_instruction(IrPrint *irp, IrInstruction *instruction) {
    if (instruction->value.special != ConstValSpecialRuntime) {
        ir_print_const_value(irp, &instruction->value);
    } else {
        ir_print_var_instruction(irp, instruction);
    }
}

static void ir_print_other_block(IrPrint *irp, IrBasicBlock *bb) {
    fprintf(irp->f, "$%s_%zu", bb->name_hint, bb->debug_id);
}

static void ir_print_return(IrPrint *irp, IrInstructionReturn *return_instruction) {
    assert(return_instruction->value);
    fprintf(irp->f, "return ");
    ir_print_other_instruction(irp, return_instruction->value);
}

static void ir_print_const(IrPrint *irp, IrInstructionConst *const_instruction) {
    ir_print_const_value(irp, &const_instruction->base.value);
}

static const char *ir_bin_op_id_str(IrBinOp op_id) {
    switch (op_id) {
        case IrBinOpInvalid:
            zig_unreachable();
        case IrBinOpBoolOr:
            return "BoolOr";
        case IrBinOpBoolAnd:
            return "BoolAnd";
        case IrBinOpCmpEq:
            return "==";
        case IrBinOpCmpNotEq:
            return "!=";
        case IrBinOpCmpLessThan:
            return "<";
        case IrBinOpCmpGreaterThan:
            return ">";
        case IrBinOpCmpLessOrEq:
            return "<=";
        case IrBinOpCmpGreaterOrEq:
            return ">=";
        case IrBinOpBinOr:
            return "|";
        case IrBinOpBinXor:
            return "^";
        case IrBinOpBinAnd:
            return "&";
        case IrBinOpBitShiftLeft:
            return "<<";
        case IrBinOpBitShiftLeftWrap:
            return "<<%";
        case IrBinOpBitShiftRight:
            return ">>";
        case IrBinOpAdd:
            return "+";
        case IrBinOpAddWrap:
            return "+%";
        case IrBinOpSub:
            return "-";
        case IrBinOpSubWrap:
            return "-%";
        case IrBinOpMult:
            return "*";
        case IrBinOpMultWrap:
            return "*%";
        case IrBinOpDiv:
            return "/";
        case IrBinOpMod:
            return "%";
        case IrBinOpArrayCat:
            return "++";
        case IrBinOpArrayMult:
            return "**";
    }
    zig_unreachable();
}

static const char *ir_un_op_id_str(IrUnOp op_id) {
    switch (op_id) {
        case IrUnOpInvalid:
            zig_unreachable();
        case IrUnOpBinNot:
            return "~";
        case IrUnOpNegation:
            return "-";
        case IrUnOpNegationWrap:
            return "-%";
        case IrUnOpDereference:
            return "*";
        case IrUnOpMaybe:
            return "?";
        case IrUnOpError:
            return "%";
    }
    zig_unreachable();
}

static void ir_print_un_op(IrPrint *irp, IrInstructionUnOp *un_op_instruction) {
    fprintf(irp->f, "%s ", ir_un_op_id_str(un_op_instruction->op_id));
    ir_print_other_instruction(irp, un_op_instruction->value);
}

static void ir_print_bin_op(IrPrint *irp, IrInstructionBinOp *bin_op_instruction) {
    ir_print_other_instruction(irp, bin_op_instruction->op1);
    fprintf(irp->f, " %s ", ir_bin_op_id_str(bin_op_instruction->op_id));
    ir_print_other_instruction(irp, bin_op_instruction->op2);
    if (!bin_op_instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_decl_var(IrPrint *irp, IrInstructionDeclVar *decl_var_instruction) {
    const char *var_or_const = decl_var_instruction->var->gen_is_const ? "const" : "var";
    const char *name = buf_ptr(&decl_var_instruction->var->name);
    if (decl_var_instruction->var_type) {
        fprintf(irp->f, "%s %s: ", var_or_const, name);
        ir_print_other_instruction(irp, decl_var_instruction->var_type);
        fprintf(irp->f, " = ");
    } else {
        fprintf(irp->f, "%s %s = ", var_or_const, name);
    }
    ir_print_other_instruction(irp, decl_var_instruction->init_value);
    if (decl_var_instruction->var->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, decl_var_instruction->var->is_comptime);
    }
}

static void ir_print_cast(IrPrint *irp, IrInstructionCast *cast_instruction) {
    fprintf(irp->f, "cast ");
    ir_print_other_instruction(irp, cast_instruction->value);
    fprintf(irp->f, " to %s", buf_ptr(&cast_instruction->dest_type->name));
}

static void ir_print_call(IrPrint *irp, IrInstructionCall *call_instruction) {
    if (call_instruction->fn_entry) {
        fprintf(irp->f, "%s", buf_ptr(&call_instruction->fn_entry->symbol_name));
    } else {
        assert(call_instruction->fn_ref);
        ir_print_other_instruction(irp, call_instruction->fn_ref);
    }
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        IrInstruction *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, arg);
    }
    fprintf(irp->f, ")");
}

static void ir_print_cond_br(IrPrint *irp, IrInstructionCondBr *cond_br_instruction) {
    fprintf(irp->f, "if (");
    ir_print_other_instruction(irp, cond_br_instruction->condition);
    fprintf(irp->f, ") ");
    ir_print_other_block(irp, cond_br_instruction->then_block);
    fprintf(irp->f, " else ");
    ir_print_other_block(irp, cond_br_instruction->else_block);
    if (cond_br_instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, cond_br_instruction->is_comptime);
    }
}

static void ir_print_br(IrPrint *irp, IrInstructionBr *br_instruction) {
    fprintf(irp->f, "goto ");
    ir_print_other_block(irp, br_instruction->dest_block);
    if (br_instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, br_instruction->is_comptime);
    }
}

static void ir_print_phi(IrPrint *irp, IrInstructionPhi *phi_instruction) {
    assert(phi_instruction->incoming_count != 0);
    assert(phi_instruction->incoming_count != SIZE_MAX);
    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        IrBasicBlock *incoming_block = phi_instruction->incoming_blocks[i];
        IrInstruction *incoming_value = phi_instruction->incoming_values[i];
        if (i != 0)
            fprintf(irp->f, " ");
        ir_print_other_block(irp, incoming_block);
        fprintf(irp->f, ":");
        ir_print_other_instruction(irp, incoming_value);
    }
}

static void ir_print_container_init_list(IrPrint *irp, IrInstructionContainerInitList *instruction) {
    ir_print_other_instruction(irp, instruction->container_type);
    fprintf(irp->f, "{");
    for (size_t i = 0; i < instruction->item_count; i += 1) {
        IrInstruction *item = instruction->items[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, item);
    }
    fprintf(irp->f, "}");
}

static void ir_print_container_init_fields(IrPrint *irp, IrInstructionContainerInitFields *instruction) {
    ir_print_other_instruction(irp, instruction->container_type);
    fprintf(irp->f, "{");
    for (size_t i = 0; i < instruction->field_count; i += 1) {
        IrInstructionContainerInitFieldsField *field = &instruction->fields[i];
        const char *comma = (i == 0) ? "" : ", ";
        fprintf(irp->f, "%s.%s = ", comma, buf_ptr(field->name));
        ir_print_other_instruction(irp, field->value);
    }
    fprintf(irp->f, "} // container init");
}

static void ir_print_struct_init(IrPrint *irp, IrInstructionStructInit *instruction) {
    fprintf(irp->f, "%s {", buf_ptr(&instruction->struct_type->name));
    for (size_t i = 0; i < instruction->field_count; i += 1) {
        IrInstructionStructInitField *field = &instruction->fields[i];
        Buf *field_name = field->type_struct_field->name;
        const char *comma = (i == 0) ? "" : ", ";
        fprintf(irp->f, "%s.%s = ", comma, buf_ptr(field_name));
        ir_print_other_instruction(irp, field->value);
    }
    fprintf(irp->f, "} // struct init");
}

static void ir_print_unreachable(IrPrint *irp, IrInstructionUnreachable *instruction) {
    fprintf(irp->f, "unreachable");
}

static void ir_print_elem_ptr(IrPrint *irp, IrInstructionElemPtr *instruction) {
    fprintf(irp->f, "&");
    ir_print_other_instruction(irp, instruction->array_ptr);
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->elem_index);
    fprintf(irp->f, "]");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_var_ptr(IrPrint *irp, IrInstructionVarPtr *instruction) {
    fprintf(irp->f, "&%s", buf_ptr(&instruction->var->name));
}

static void ir_print_load_ptr(IrPrint *irp, IrInstructionLoadPtr *instruction) {
    fprintf(irp->f, "*");
    ir_print_other_instruction(irp, instruction->ptr);
}

static void ir_print_store_ptr(IrPrint *irp, IrInstructionStorePtr *instruction) {
    fprintf(irp->f, "*");
    ir_print_var_instruction(irp, instruction->ptr);
    fprintf(irp->f, " = ");
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_typeof(IrPrint *irp, IrInstructionTypeOf *instruction) {
    fprintf(irp->f, "@typeOf(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_to_ptr_type(IrPrint *irp, IrInstructionToPtrType *instruction) {
    fprintf(irp->f, "@toPtrType(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_type_child(IrPrint *irp, IrInstructionPtrTypeChild *instruction) {
    fprintf(irp->f, "@ptrTypeChild(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_field_ptr(IrPrint *irp, IrInstructionFieldPtr *instruction) {
    fprintf(irp->f, "fieldptr ");
    ir_print_other_instruction(irp, instruction->container_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field_name));
}

static void ir_print_struct_field_ptr(IrPrint *irp, IrInstructionStructFieldPtr *instruction) {
    fprintf(irp->f, "@StructFieldPtr(&");
    ir_print_other_instruction(irp, instruction->struct_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->name));
    fprintf(irp->f, ")");
}

static void ir_print_enum_field_ptr(IrPrint *irp, IrInstructionEnumFieldPtr *instruction) {
    fprintf(irp->f, "@EnumFieldPtr(&");
    ir_print_other_instruction(irp, instruction->enum_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->name));
    fprintf(irp->f, ")");
}

static void ir_print_set_fn_test(IrPrint *irp, IrInstructionSetFnTest *instruction) {
    fprintf(irp->f, "@setFnTest(");
    ir_print_other_instruction(irp, instruction->fn_value);
    fprintf(irp->f, ")");
}

static void ir_print_set_fn_visible(IrPrint *irp, IrInstructionSetFnVisible *instruction) {
    fprintf(irp->f, "@setFnVisible(");
    ir_print_other_instruction(irp, instruction->fn_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->is_visible);
    fprintf(irp->f, ")");
}

static void ir_print_set_debug_safety(IrPrint *irp, IrInstructionSetDebugSafety *instruction) {
    fprintf(irp->f, "@setDebugSafety(");
    ir_print_other_instruction(irp, instruction->scope_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->debug_safety_on);
    fprintf(irp->f, ")");
}

static void ir_print_array_type(IrPrint *irp, IrInstructionArrayType *instruction) {
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->size);
    fprintf(irp->f, "]");
    ir_print_other_instruction(irp, instruction->child_type);
}

static void ir_print_slice_type(IrPrint *irp, IrInstructionSliceType *instruction) {
    const char *const_kw = instruction->is_const ? "const " : "";
    fprintf(irp->f, "[]%s", const_kw);
    ir_print_other_instruction(irp, instruction->child_type);
}

static void ir_print_asm(IrPrint *irp, IrInstructionAsm *instruction) {
    assert(instruction->base.source_node->type == NodeTypeAsmExpr);
    AstNodeAsmExpr *asm_expr = &instruction->base.source_node->data.asm_expr;
    const char *volatile_kw = instruction->has_side_effects ? " volatile" : "";
    fprintf(irp->f, "asm%s (\"%s\") : ", volatile_kw, buf_ptr(asm_expr->asm_template));

    for (size_t i = 0; i < asm_expr->output_list.length; i += 1) {
        AsmOutput *asm_output = asm_expr->output_list.at(i);
        if (i != 0) fprintf(irp->f, ", ");

        fprintf(irp->f, "[%s] \"%s\" (",
                buf_ptr(asm_output->asm_symbolic_name),
                buf_ptr(asm_output->constraint));
        if (asm_output->return_type) {
            fprintf(irp->f, "-> ");
            ir_print_other_instruction(irp, instruction->output_types[i]);
        } else {
            fprintf(irp->f, "%s", buf_ptr(asm_output->variable_name));
        }
        fprintf(irp->f, ")");
    }

    fprintf(irp->f, " : ");
    for (size_t i = 0; i < asm_expr->input_list.length; i += 1) {
        AsmInput *asm_input = asm_expr->input_list.at(i);

        if (i != 0) fprintf(irp->f, ", ");
        fprintf(irp->f, "[%s] \"%s\" (",
                buf_ptr(asm_input->asm_symbolic_name),
                buf_ptr(asm_input->constraint));
        ir_print_other_instruction(irp, instruction->input_list[i]);
        fprintf(irp->f, ")");
    }
    fprintf(irp->f, " : ");
    for (size_t i = 0; i < asm_expr->clobber_list.length; i += 1) {
        Buf *reg_name = asm_expr->clobber_list.at(i);
        if (i != 0) fprintf(irp->f, ", ");
        fprintf(irp->f, "\"%s\"", buf_ptr(reg_name));
    }
    fprintf(irp->f, ")");
}

static void ir_print_compile_var(IrPrint *irp, IrInstructionCompileVar *instruction) {
    fprintf(irp->f, "@compileVar(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_size_of(IrPrint *irp, IrInstructionSizeOf *instruction) {
    fprintf(irp->f, "@sizeOf(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_test_null(IrPrint *irp, IrInstructionTestNonNull *instruction) {
    fprintf(irp->f, "*");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, " != null");
}

static void ir_print_unwrap_maybe(IrPrint *irp, IrInstructionUnwrapMaybe *instruction) {
    fprintf(irp->f, "&??*");
    ir_print_other_instruction(irp, instruction->value);
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_clz(IrPrint *irp, IrInstructionClz *instruction) {
    fprintf(irp->f, "@clz(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_ctz(IrPrint *irp, IrInstructionCtz *instruction) {
    fprintf(irp->f, "@ctz(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_switch_br(IrPrint *irp, IrInstructionSwitchBr *instruction) {
    fprintf(irp->f, "switch (");
    ir_print_other_instruction(irp, instruction->target_value);
    fprintf(irp->f, ") ");
    for (size_t i = 0; i < instruction->case_count; i += 1) {
        IrInstructionSwitchBrCase *this_case = &instruction->cases[i];
        ir_print_other_instruction(irp, this_case->value);
        fprintf(irp->f, " => ");
        ir_print_other_block(irp, this_case->block);
        fprintf(irp->f, ", ");
    }
    fprintf(irp->f, "else => ");
    ir_print_other_block(irp, instruction->else_block);
    if (instruction->is_comptime != nullptr) {
        fprintf(irp->f, " // comptime = ");
        ir_print_other_instruction(irp, instruction->is_comptime);
    }
}

static void ir_print_switch_var(IrPrint *irp, IrInstructionSwitchVar *instruction) {
    fprintf(irp->f, "switchvar ");
    ir_print_other_instruction(irp, instruction->target_value_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->prong_value);
}

static void ir_print_switch_target(IrPrint *irp, IrInstructionSwitchTarget *instruction) {
    fprintf(irp->f, "switchtarget ");
    ir_print_other_instruction(irp, instruction->target_value_ptr);
}

static void ir_print_enum_tag(IrPrint *irp, IrInstructionEnumTag *instruction) {
    fprintf(irp->f, "enumtag ");
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_static_eval(IrPrint *irp, IrInstructionStaticEval *instruction) {
    fprintf(irp->f, "@staticEval(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_generated_code(IrPrint *irp, IrInstructionGeneratedCode *instruction) {
    fprintf(irp->f, "@generatedCode(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_import(IrPrint *irp, IrInstructionImport *instruction) {
    fprintf(irp->f, "@import(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_array_len(IrPrint *irp, IrInstructionArrayLen *instruction) {
    ir_print_other_instruction(irp, instruction->array_value);
    fprintf(irp->f, ".len");
}

static void ir_print_ref(IrPrint *irp, IrInstructionRef *instruction) {
    const char *const_str = instruction->is_const ? "const " : "";
    fprintf(irp->f, "%sref ", const_str);
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_min_value(IrPrint *irp, IrInstructionMinValue *instruction) {
    fprintf(irp->f, "@minValue(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_max_value(IrPrint *irp, IrInstructionMaxValue *instruction) {
    fprintf(irp->f, "@maxValue(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_compile_err(IrPrint *irp, IrInstructionCompileErr *instruction) {
    fprintf(irp->f, "@compileError(");
    ir_print_other_instruction(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_err_name(IrPrint *irp, IrInstructionErrName *instruction) {
    fprintf(irp->f, "@errorName(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_import(IrPrint *irp, IrInstructionCImport *instruction) {
    fprintf(irp->f, "@cImport(...)");
}

static void ir_print_c_include(IrPrint *irp, IrInstructionCInclude *instruction) {
    fprintf(irp->f, "@cInclude(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_c_define(IrPrint *irp, IrInstructionCDefine *instruction) {
    fprintf(irp->f, "@cDefine(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_c_undef(IrPrint *irp, IrInstructionCUndef *instruction) {
    fprintf(irp->f, "@cUndef(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_embed_file(IrPrint *irp, IrInstructionEmbedFile *instruction) {
    fprintf(irp->f, "@embedFile(");
    ir_print_other_instruction(irp, instruction->name);
    fprintf(irp->f, ")");
}

static void ir_print_cmpxchg(IrPrint *irp, IrInstructionCmpxchg *instruction) {
    fprintf(irp->f, "@cmpxchg(");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->cmp_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->new_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->success_order_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->failure_order_value);
    fprintf(irp->f, ")");
}

static void ir_print_fence(IrPrint *irp, IrInstructionFence *instruction) {
    fprintf(irp->f, "@fence(");
    ir_print_other_instruction(irp, instruction->order_value);
    fprintf(irp->f, ")");
}

static void ir_print_div_exact(IrPrint *irp, IrInstructionDivExact *instruction) {
    fprintf(irp->f, "@divExact(");
    ir_print_other_instruction(irp, instruction->op1);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->op2);
    fprintf(irp->f, ")");
}

static void ir_print_truncate(IrPrint *irp, IrInstructionTruncate *instruction) {
    fprintf(irp->f, "@truncate(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_alloca(IrPrint *irp, IrInstructionAlloca *instruction) {
    fprintf(irp->f, "@alloca(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_int_type(IrPrint *irp, IrInstructionIntType *instruction) {
    fprintf(irp->f, "@intType(");
    ir_print_other_instruction(irp, instruction->is_signed);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->bit_count);
    fprintf(irp->f, ")");
}

static void ir_print_bool_not(IrPrint *irp, IrInstructionBoolNot *instruction) {
    fprintf(irp->f, "! ");
    ir_print_other_instruction(irp, instruction->value);
}

static void ir_print_memset(IrPrint *irp, IrInstructionMemset *instruction) {
    fprintf(irp->f, "@memset(");
    ir_print_other_instruction(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->byte);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_memcpy(IrPrint *irp, IrInstructionMemcpy *instruction) {
    fprintf(irp->f, "@memcpy(");
    ir_print_other_instruction(irp, instruction->dest_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->src_ptr);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->count);
    fprintf(irp->f, ")");
}

static void ir_print_slice(IrPrint *irp, IrInstructionSlice *instruction) {
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->start);
    fprintf(irp->f, "...");
    if (instruction->end)
        ir_print_other_instruction(irp, instruction->end);
    fprintf(irp->f, "]");
    if (instruction->is_const)
        fprintf(irp->f, "const");
}

static void ir_print_member_count(IrPrint *irp, IrInstructionMemberCount *instruction) {
    fprintf(irp->f, "@memberCount(");
    ir_print_other_instruction(irp, instruction->container);
    fprintf(irp->f, ")");
}

static void ir_print_breakpoint(IrPrint *irp, IrInstructionBreakpoint *instruction) {
    fprintf(irp->f, "@breakpoint()");
}

static void ir_print_frame_address(IrPrint *irp, IrInstructionFrameAddress *instruction) {
    fprintf(irp->f, "@frameAddress()");
}

static void ir_print_return_address(IrPrint *irp, IrInstructionReturnAddress *instruction) {
    fprintf(irp->f, "@returnAddress()");
}

static void ir_print_alignof(IrPrint *irp, IrInstructionAlignOf *instruction) {
    fprintf(irp->f, "@alignOf(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_overflow_op(IrPrint *irp, IrInstructionOverflowOp *instruction) {
    switch (instruction->op) {
        case IrOverflowOpAdd:
            fprintf(irp->f, "@addWithOverflow(");
            break;
        case IrOverflowOpSub:
            fprintf(irp->f, "@subWithOverflow(");
            break;
        case IrOverflowOpMul:
            fprintf(irp->f, "@mulWithOverflow(");
            break;
        case IrOverflowOpShl:
            fprintf(irp->f, "@shlWithOverflow(");
            break;
    }
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->op1);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->op2);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->result_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_test_err(IrPrint *irp, IrInstructionTestErr *instruction) {
    fprintf(irp->f, "@testError(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_code(IrPrint *irp, IrInstructionUnwrapErrCode *instruction) {
    fprintf(irp->f, "@unwrapErrorCode(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_unwrap_err_payload(IrPrint *irp, IrInstructionUnwrapErrPayload *instruction) {
    fprintf(irp->f, "@unwrapErrorPayload(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
    if (!instruction->safety_check_on) {
        fprintf(irp->f, " // no safety");
    }
}

static void ir_print_maybe_wrap(IrPrint *irp, IrInstructionMaybeWrap *instruction) {
    fprintf(irp->f, "@maybeWrap(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_err_wrap_code(IrPrint *irp, IrInstructionErrWrapCode *instruction) {
    fprintf(irp->f, "@errWrapCode(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_err_wrap_payload(IrPrint *irp, IrInstructionErrWrapPayload *instruction) {
    fprintf(irp->f, "@errWrapPayload(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_fn_proto(IrPrint *irp, IrInstructionFnProto *instruction) {
    fprintf(irp->f, "fn(");
    for (size_t i = 0; i < instruction->base.source_node->data.fn_proto.params.length; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->param_types[i]);
    }
    fprintf(irp->f, ")->");
    ir_print_other_instruction(irp, instruction->return_type);
}

static void ir_print_test_comptime(IrPrint *irp, IrInstructionTestComptime *instruction) {
    fprintf(irp->f, "@testComptime(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_init_enum(IrPrint *irp, IrInstructionInitEnum *instruction) {
    fprintf(irp->f, "%s.%s {", buf_ptr(&instruction->enum_type->name), buf_ptr(instruction->field->name));
    ir_print_other_instruction(irp, instruction->init_value);
    fprintf(irp->f, "}");
}

static void ir_print_pointer_reinterpret(IrPrint *irp, IrInstructionPointerReinterpret *instruction) {
    fprintf(irp->f, "@pointerReinterpret(");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_widen_or_shorten(IrPrint *irp, IrInstructionWidenOrShorten *instruction) {
    fprintf(irp->f, "@widenOrShorten(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_to_int(IrPrint *irp, IrInstructionPtrToInt *instruction) {
    fprintf(irp->f, "@ptrToInt(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_ptr(IrPrint *irp, IrInstructionIntToPtr *instruction) {
    fprintf(irp->f, "@intToPtr(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_enum(IrPrint *irp, IrInstructionIntToEnum *instruction) {
    fprintf(irp->f, "@intToEnum(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_instruction(IrPrint *irp, IrInstruction *instruction) {
    ir_print_prefix(irp, instruction);
    switch (instruction->id) {
        case IrInstructionIdInvalid:
            zig_unreachable();
        case IrInstructionIdReturn:
            ir_print_return(irp, (IrInstructionReturn *)instruction);
            break;
        case IrInstructionIdConst:
            ir_print_const(irp, (IrInstructionConst *)instruction);
            break;
        case IrInstructionIdBinOp:
            ir_print_bin_op(irp, (IrInstructionBinOp *)instruction);
            break;
        case IrInstructionIdDeclVar:
            ir_print_decl_var(irp, (IrInstructionDeclVar *)instruction);
            break;
        case IrInstructionIdCast:
            ir_print_cast(irp, (IrInstructionCast *)instruction);
            break;
        case IrInstructionIdCall:
            ir_print_call(irp, (IrInstructionCall *)instruction);
            break;
        case IrInstructionIdUnOp:
            ir_print_un_op(irp, (IrInstructionUnOp *)instruction);
            break;
        case IrInstructionIdCondBr:
            ir_print_cond_br(irp, (IrInstructionCondBr *)instruction);
            break;
        case IrInstructionIdBr:
            ir_print_br(irp, (IrInstructionBr *)instruction);
            break;
        case IrInstructionIdPhi:
            ir_print_phi(irp, (IrInstructionPhi *)instruction);
            break;
        case IrInstructionIdContainerInitList:
            ir_print_container_init_list(irp, (IrInstructionContainerInitList *)instruction);
            break;
        case IrInstructionIdContainerInitFields:
            ir_print_container_init_fields(irp, (IrInstructionContainerInitFields *)instruction);
            break;
        case IrInstructionIdStructInit:
            ir_print_struct_init(irp, (IrInstructionStructInit *)instruction);
            break;
        case IrInstructionIdUnreachable:
            ir_print_unreachable(irp, (IrInstructionUnreachable *)instruction);
            break;
        case IrInstructionIdElemPtr:
            ir_print_elem_ptr(irp, (IrInstructionElemPtr *)instruction);
            break;
        case IrInstructionIdVarPtr:
            ir_print_var_ptr(irp, (IrInstructionVarPtr *)instruction);
            break;
        case IrInstructionIdLoadPtr:
            ir_print_load_ptr(irp, (IrInstructionLoadPtr *)instruction);
            break;
        case IrInstructionIdStorePtr:
            ir_print_store_ptr(irp, (IrInstructionStorePtr *)instruction);
            break;
        case IrInstructionIdTypeOf:
            ir_print_typeof(irp, (IrInstructionTypeOf *)instruction);
            break;
        case IrInstructionIdToPtrType:
            ir_print_to_ptr_type(irp, (IrInstructionToPtrType *)instruction);
            break;
        case IrInstructionIdPtrTypeChild:
            ir_print_ptr_type_child(irp, (IrInstructionPtrTypeChild *)instruction);
            break;
        case IrInstructionIdFieldPtr:
            ir_print_field_ptr(irp, (IrInstructionFieldPtr *)instruction);
            break;
        case IrInstructionIdStructFieldPtr:
            ir_print_struct_field_ptr(irp, (IrInstructionStructFieldPtr *)instruction);
            break;
        case IrInstructionIdEnumFieldPtr:
            ir_print_enum_field_ptr(irp, (IrInstructionEnumFieldPtr *)instruction);
            break;
        case IrInstructionIdSetFnTest:
            ir_print_set_fn_test(irp, (IrInstructionSetFnTest *)instruction);
            break;
        case IrInstructionIdSetFnVisible:
            ir_print_set_fn_visible(irp, (IrInstructionSetFnVisible *)instruction);
            break;
        case IrInstructionIdSetDebugSafety:
            ir_print_set_debug_safety(irp, (IrInstructionSetDebugSafety *)instruction);
            break;
        case IrInstructionIdArrayType:
            ir_print_array_type(irp, (IrInstructionArrayType *)instruction);
            break;
        case IrInstructionIdSliceType:
            ir_print_slice_type(irp, (IrInstructionSliceType *)instruction);
            break;
        case IrInstructionIdAsm:
            ir_print_asm(irp, (IrInstructionAsm *)instruction);
            break;
        case IrInstructionIdCompileVar:
            ir_print_compile_var(irp, (IrInstructionCompileVar *)instruction);
            break;
        case IrInstructionIdSizeOf:
            ir_print_size_of(irp, (IrInstructionSizeOf *)instruction);
            break;
        case IrInstructionIdTestNonNull:
            ir_print_test_null(irp, (IrInstructionTestNonNull *)instruction);
            break;
        case IrInstructionIdUnwrapMaybe:
            ir_print_unwrap_maybe(irp, (IrInstructionUnwrapMaybe *)instruction);
            break;
        case IrInstructionIdCtz:
            ir_print_ctz(irp, (IrInstructionCtz *)instruction);
            break;
        case IrInstructionIdClz:
            ir_print_clz(irp, (IrInstructionClz *)instruction);
            break;
        case IrInstructionIdSwitchBr:
            ir_print_switch_br(irp, (IrInstructionSwitchBr *)instruction);
            break;
        case IrInstructionIdSwitchVar:
            ir_print_switch_var(irp, (IrInstructionSwitchVar *)instruction);
            break;
        case IrInstructionIdSwitchTarget:
            ir_print_switch_target(irp, (IrInstructionSwitchTarget *)instruction);
            break;
        case IrInstructionIdEnumTag:
            ir_print_enum_tag(irp, (IrInstructionEnumTag *)instruction);
            break;
        case IrInstructionIdStaticEval:
            ir_print_static_eval(irp, (IrInstructionStaticEval *)instruction);
            break;
        case IrInstructionIdGeneratedCode:
            ir_print_generated_code(irp, (IrInstructionGeneratedCode *)instruction);
            break;
        case IrInstructionIdImport:
            ir_print_import(irp, (IrInstructionImport *)instruction);
            break;
        case IrInstructionIdArrayLen:
            ir_print_array_len(irp, (IrInstructionArrayLen *)instruction);
            break;
        case IrInstructionIdRef:
            ir_print_ref(irp, (IrInstructionRef *)instruction);
            break;
        case IrInstructionIdMinValue:
            ir_print_min_value(irp, (IrInstructionMinValue *)instruction);
            break;
        case IrInstructionIdMaxValue:
            ir_print_max_value(irp, (IrInstructionMaxValue *)instruction);
            break;
        case IrInstructionIdCompileErr:
            ir_print_compile_err(irp, (IrInstructionCompileErr *)instruction);
            break;
        case IrInstructionIdErrName:
            ir_print_err_name(irp, (IrInstructionErrName *)instruction);
            break;
        case IrInstructionIdCImport:
            ir_print_c_import(irp, (IrInstructionCImport *)instruction);
            break;
        case IrInstructionIdCInclude:
            ir_print_c_include(irp, (IrInstructionCInclude *)instruction);
            break;
        case IrInstructionIdCDefine:
            ir_print_c_define(irp, (IrInstructionCDefine *)instruction);
            break;
        case IrInstructionIdCUndef:
            ir_print_c_undef(irp, (IrInstructionCUndef *)instruction);
            break;
        case IrInstructionIdEmbedFile:
            ir_print_embed_file(irp, (IrInstructionEmbedFile *)instruction);
            break;
        case IrInstructionIdCmpxchg:
            ir_print_cmpxchg(irp, (IrInstructionCmpxchg *)instruction);
            break;
        case IrInstructionIdFence:
            ir_print_fence(irp, (IrInstructionFence *)instruction);
            break;
        case IrInstructionIdDivExact:
            ir_print_div_exact(irp, (IrInstructionDivExact *)instruction);
            break;
        case IrInstructionIdTruncate:
            ir_print_truncate(irp, (IrInstructionTruncate *)instruction);
            break;
        case IrInstructionIdAlloca:
            ir_print_alloca(irp, (IrInstructionAlloca *)instruction);
            break;
        case IrInstructionIdIntType:
            ir_print_int_type(irp, (IrInstructionIntType *)instruction);
            break;
        case IrInstructionIdBoolNot:
            ir_print_bool_not(irp, (IrInstructionBoolNot *)instruction);
            break;
        case IrInstructionIdMemset:
            ir_print_memset(irp, (IrInstructionMemset *)instruction);
            break;
        case IrInstructionIdMemcpy:
            ir_print_memcpy(irp, (IrInstructionMemcpy *)instruction);
            break;
        case IrInstructionIdSlice:
            ir_print_slice(irp, (IrInstructionSlice *)instruction);
            break;
        case IrInstructionIdMemberCount:
            ir_print_member_count(irp, (IrInstructionMemberCount *)instruction);
            break;
        case IrInstructionIdBreakpoint:
            ir_print_breakpoint(irp, (IrInstructionBreakpoint *)instruction);
            break;
        case IrInstructionIdReturnAddress:
            ir_print_return_address(irp, (IrInstructionReturnAddress *)instruction);
            break;
        case IrInstructionIdFrameAddress:
            ir_print_frame_address(irp, (IrInstructionFrameAddress *)instruction);
            break;
        case IrInstructionIdAlignOf:
            ir_print_alignof(irp, (IrInstructionAlignOf *)instruction);
            break;
        case IrInstructionIdOverflowOp:
            ir_print_overflow_op(irp, (IrInstructionOverflowOp *)instruction);
            break;
        case IrInstructionIdTestErr:
            ir_print_test_err(irp, (IrInstructionTestErr *)instruction);
            break;
        case IrInstructionIdUnwrapErrCode:
            ir_print_unwrap_err_code(irp, (IrInstructionUnwrapErrCode *)instruction);
            break;
        case IrInstructionIdUnwrapErrPayload:
            ir_print_unwrap_err_payload(irp, (IrInstructionUnwrapErrPayload *)instruction);
            break;
        case IrInstructionIdMaybeWrap:
            ir_print_maybe_wrap(irp, (IrInstructionMaybeWrap *)instruction);
            break;
        case IrInstructionIdErrWrapCode:
            ir_print_err_wrap_code(irp, (IrInstructionErrWrapCode *)instruction);
            break;
        case IrInstructionIdErrWrapPayload:
            ir_print_err_wrap_payload(irp, (IrInstructionErrWrapPayload *)instruction);
            break;
        case IrInstructionIdFnProto:
            ir_print_fn_proto(irp, (IrInstructionFnProto *)instruction);
            break;
        case IrInstructionIdTestComptime:
            ir_print_test_comptime(irp, (IrInstructionTestComptime *)instruction);
            break;
        case IrInstructionIdInitEnum:
            ir_print_init_enum(irp, (IrInstructionInitEnum *)instruction);
            break;
        case IrInstructionIdPointerReinterpret:
            ir_print_pointer_reinterpret(irp, (IrInstructionPointerReinterpret *)instruction);
            break;
        case IrInstructionIdWidenOrShorten:
            ir_print_widen_or_shorten(irp, (IrInstructionWidenOrShorten *)instruction);
            break;
        case IrInstructionIdPtrToInt:
            ir_print_ptr_to_int(irp, (IrInstructionPtrToInt *)instruction);
            break;
        case IrInstructionIdIntToPtr:
            ir_print_int_to_ptr(irp, (IrInstructionIntToPtr *)instruction);
            break;
        case IrInstructionIdIntToEnum:
            ir_print_int_to_enum(irp, (IrInstructionIntToEnum *)instruction);
            break;
    }
    fprintf(irp->f, "\n");
}

void ir_print(FILE *f, IrExecutable *executable, int indent_size) {
    IrPrint ir_print = {};
    IrPrint *irp = &ir_print;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;

    for (size_t bb_i = 0; bb_i < executable->basic_block_list.length; bb_i += 1) {
        IrBasicBlock *current_block = executable->basic_block_list.at(bb_i);
        fprintf(irp->f, "%s_%zu:\n", current_block->name_hint, current_block->debug_id);
        for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
            IrInstruction *instruction = current_block->instruction_list.at(instr_i);
            ir_print_instruction(irp, instruction);
        }
    }
}

static void print_tld_var(IrPrint *irp, TldVar *tld_var) {
    const char *const_or_var = tld_var->var->src_is_const ? "const" : "var";
    fprintf(irp->f, "%s %s", const_or_var, buf_ptr(tld_var->base.name));
    bool omit_type = (tld_var->var->value.type->id == TypeTableEntryIdNumLitFloat ||
        tld_var->var->value.type->id == TypeTableEntryIdNumLitInt);
    if (!omit_type) {
        fprintf(irp->f, ": %s", buf_ptr(&tld_var->var->value.type->name));
    }
    if (tld_var->var->value.special != ConstValSpecialRuntime) {
        fprintf(irp->f, " = ");
        ir_print_const_value(irp, &tld_var->var->value);
    }
    fprintf(irp->f, ";\n");
}

static void print_tld_fn(IrPrint *irp, TldFn *tld_fn) {
    fprintf(irp->f, "// %s = TODO (function)\n", buf_ptr(tld_fn->base.name));
}

static void print_tld_container(IrPrint *irp, TldContainer *tld_container) {
    fprintf(irp->f, "// %s = TODO (container)\n", buf_ptr(tld_container->base.name));
}

static void print_tld_typedef(IrPrint *irp, TldTypeDef *tld_typedef) {
    fprintf(irp->f, "// %s = TODO (typedef)\n", buf_ptr(tld_typedef->base.name));
}

void ir_print_decls(FILE *f, ImportTableEntry *import) {
    IrPrint ir_print = {};
    IrPrint *irp = &ir_print;
    irp->f = f;
    irp->indent = 0;
    irp->indent_size = 2;

    auto it = import->decls_scope->decl_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        Tld *tld = entry->value;
        if (!buf_eql_buf(entry->key, tld->name)) {
            fprintf(f, "// alias: %s = %s\n", buf_ptr(entry->key), buf_ptr(tld->name));
            continue;
        }

        switch (tld->id) {
            case TldIdVar:
                print_tld_var(irp, (TldVar *)tld);
                continue;
            case TldIdFn:
                print_tld_fn(irp, (TldFn *)tld);
                continue;
            case TldIdContainer:
                print_tld_container(irp, (TldContainer *)tld);
                continue;
            case TldIdTypeDef:
                print_tld_typedef(irp, (TldTypeDef *)tld);
                continue;
        }
        zig_unreachable();
    }
}
