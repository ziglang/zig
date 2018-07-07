/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ir.hpp"
#include "ir_print.hpp"
#include "os.hpp"

struct IrPrint {
    CodeGen *codegen;
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
        "-" : buf_ptr(buf_sprintf("%" ZIG_PRI_usize "", instruction->ref_count));
    fprintf(irp->f, "#%-3zu| %-12s| %-2s| ", instruction->debug_id, type_name, ref_count);
}

static void ir_print_const_value(IrPrint *irp, ConstExprValue *const_val) {
    Buf buf = BUF_INIT;
    buf_resize(&buf, 0);
    render_const_value(irp->codegen, &buf, const_val);
    fprintf(irp->f, "%s", buf_ptr(&buf));
}

static void ir_print_var_instruction(IrPrint *irp, IrInstruction *instruction) {
    fprintf(irp->f, "#%" ZIG_PRI_usize "", instruction->debug_id);
}

static void ir_print_other_instruction(IrPrint *irp, IrInstruction *instruction) {
    if (instruction->value.special != ConstValSpecialRuntime) {
        ir_print_const_value(irp, &instruction->value);
    } else {
        ir_print_var_instruction(irp, instruction);
    }
}

static void ir_print_other_block(IrPrint *irp, IrBasicBlock *bb) {
    fprintf(irp->f, "$%s_%" ZIG_PRI_usize "", bb->name_hint, bb->debug_id);
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
        case IrBinOpBitShiftLeftLossy:
            return "<<";
        case IrBinOpBitShiftLeftExact:
            return "@shlExact";
        case IrBinOpBitShiftRightLossy:
            return ">>";
        case IrBinOpBitShiftRightExact:
            return "@shrExact";
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
        case IrBinOpDivUnspecified:
            return "/";
        case IrBinOpDivTrunc:
            return "@divTrunc";
        case IrBinOpDivFloor:
            return "@divFloor";
        case IrBinOpDivExact:
            return "@divExact";
        case IrBinOpRemUnspecified:
            return "%";
        case IrBinOpRemRem:
            return "@rem";
        case IrBinOpRemMod:
            return "@mod";
        case IrBinOpArrayCat:
            return "++";
        case IrBinOpArrayMult:
            return "**";
        case IrBinOpMergeErrorSets:
            return "||";
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
        case IrUnOpOptional:
            return "?";
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
        fprintf(irp->f, " ");
    } else {
        fprintf(irp->f, "%s %s ", var_or_const, name);
    }
    if (decl_var_instruction->align_value) {
        fprintf(irp->f, "align ");
        ir_print_other_instruction(irp, decl_var_instruction->align_value);
        fprintf(irp->f, " ");
    }
    fprintf(irp->f, "= ");
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
    if (call_instruction->is_async) {
        fprintf(irp->f, "async");
        if (call_instruction->async_allocator != nullptr) {
            fprintf(irp->f, "<");
            ir_print_other_instruction(irp, call_instruction->async_allocator);
            fprintf(irp->f, ">");
        }
        fprintf(irp->f, " ");
    }
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
    if (instruction->item_count > 50) {
        fprintf(irp->f, "...(%" ZIG_PRI_usize " items)...", instruction->item_count);
    } else {
        for (size_t i = 0; i < instruction->item_count; i += 1) {
            IrInstruction *item = instruction->items[i];
            if (i != 0)
                fprintf(irp->f, ", ");
            ir_print_other_instruction(irp, item);
        }
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

static void ir_print_union_init(IrPrint *irp, IrInstructionUnionInit *instruction) {
    Buf *field_name = instruction->field->enum_field->name;

    fprintf(irp->f, "%s {", buf_ptr(&instruction->union_type->name));
    fprintf(irp->f, ".%s = ", buf_ptr(field_name));
    ir_print_other_instruction(irp, instruction->init_value);
    fprintf(irp->f, "} // union init");
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
    if (instruction->field_name_buffer) {
        fprintf(irp->f, "fieldptr ");
        ir_print_other_instruction(irp, instruction->container_ptr);
        fprintf(irp->f, ".%s", buf_ptr(instruction->field_name_buffer));
    } else {
        assert(instruction->field_name_expr);
        fprintf(irp->f, "@field(");
        ir_print_other_instruction(irp, instruction->container_ptr);
        fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, instruction->field_name_expr);
        fprintf(irp->f, ")");
    }
}

static void ir_print_struct_field_ptr(IrPrint *irp, IrInstructionStructFieldPtr *instruction) {
    fprintf(irp->f, "@StructFieldPtr(&");
    ir_print_other_instruction(irp, instruction->struct_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->name));
    fprintf(irp->f, ")");
}

static void ir_print_union_field_ptr(IrPrint *irp, IrInstructionUnionFieldPtr *instruction) {
    fprintf(irp->f, "@UnionFieldPtr(&");
    ir_print_other_instruction(irp, instruction->union_ptr);
    fprintf(irp->f, ".%s", buf_ptr(instruction->field->enum_field->name));
    fprintf(irp->f, ")");
}

static void ir_print_set_cold(IrPrint *irp, IrInstructionSetCold *instruction) {
    fprintf(irp->f, "@setCold(");
    ir_print_other_instruction(irp, instruction->is_cold);
    fprintf(irp->f, ")");
}

static void ir_print_set_runtime_safety(IrPrint *irp, IrInstructionSetRuntimeSafety *instruction) {
    fprintf(irp->f, "@setRuntimeSafety(");
    ir_print_other_instruction(irp, instruction->safety_on);
    fprintf(irp->f, ")");
}

static void ir_print_set_float_mode(IrPrint *irp, IrInstructionSetFloatMode *instruction) {
    fprintf(irp->f, "@setFloatMode(");
    ir_print_other_instruction(irp, instruction->scope_value);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->mode_value);
    fprintf(irp->f, ")");
}

static void ir_print_array_type(IrPrint *irp, IrInstructionArrayType *instruction) {
    fprintf(irp->f, "[");
    ir_print_other_instruction(irp, instruction->size);
    fprintf(irp->f, "]");
    ir_print_other_instruction(irp, instruction->child_type);
}

static void ir_print_promise_type(IrPrint *irp, IrInstructionPromiseType *instruction) {
    fprintf(irp->f, "promise");
    if (instruction->payload_type != nullptr) {
        fprintf(irp->f, "->");
        ir_print_other_instruction(irp, instruction->payload_type);
    }
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

static void ir_print_unwrap_maybe(IrPrint *irp, IrInstructionUnwrapOptional *instruction) {
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

static void ir_print_pop_count(IrPrint *irp, IrInstructionPopCount *instruction) {
    fprintf(irp->f, "@popCount(");
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

static void ir_print_union_tag(IrPrint *irp, IrInstructionUnionTag *instruction) {
    fprintf(irp->f, "uniontag ");
    ir_print_other_instruction(irp, instruction->value);
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
    const char *volatile_str = instruction->is_volatile ? "volatile " : "";
    fprintf(irp->f, "%s%sref ", const_str, volatile_str);
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

static void ir_print_compile_log(IrPrint *irp, IrInstructionCompileLog *instruction) {
    fprintf(irp->f, "@compileLog(");
    for (size_t i = 0; i < instruction->msg_count; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        IrInstruction *msg = instruction->msg_list[i];
        ir_print_other_instruction(irp, msg);
    }
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

static void ir_print_truncate(IrPrint *irp, IrInstructionTruncate *instruction) {
    fprintf(irp->f, "@truncate(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_cast(IrPrint *irp, IrInstructionIntCast *instruction) {
    fprintf(irp->f, "@intCast(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_cast(IrPrint *irp, IrInstructionFloatCast *instruction) {
    fprintf(irp->f, "@floatCast(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_err_set_cast(IrPrint *irp, IrInstructionErrSetCast *instruction) {
    fprintf(irp->f, "@errSetCast(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_from_bytes(IrPrint *irp, IrInstructionFromBytes *instruction) {
    fprintf(irp->f, "@bytesToSlice(");
    ir_print_other_instruction(irp, instruction->dest_child_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_to_bytes(IrPrint *irp, IrInstructionToBytes *instruction) {
    fprintf(irp->f, "@sliceToBytes(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_float(IrPrint *irp, IrInstructionIntToFloat *instruction) {
    fprintf(irp->f, "@intToFloat(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_float_to_int(IrPrint *irp, IrInstructionFloatToInt *instruction) {
    fprintf(irp->f, "@floatToInt(");
    ir_print_other_instruction(irp, instruction->dest_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_bool_to_int(IrPrint *irp, IrInstructionBoolToInt *instruction) {
    fprintf(irp->f, "@boolToInt(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_type(IrPrint *irp, IrInstructionIntType *instruction) {
    fprintf(irp->f, "@IntType(");
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
    fprintf(irp->f, "..");
    if (instruction->end)
        ir_print_other_instruction(irp, instruction->end);
    fprintf(irp->f, "]");
}

static void ir_print_member_count(IrPrint *irp, IrInstructionMemberCount *instruction) {
    fprintf(irp->f, "@memberCount(");
    ir_print_other_instruction(irp, instruction->container);
    fprintf(irp->f, ")");
}

static void ir_print_member_type(IrPrint *irp, IrInstructionMemberType *instruction) {
    fprintf(irp->f, "@memberType(");
    ir_print_other_instruction(irp, instruction->container_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->member_index);
    fprintf(irp->f, ")");
}

static void ir_print_member_name(IrPrint *irp, IrInstructionMemberName *instruction) {
    fprintf(irp->f, "@memberName(");
    ir_print_other_instruction(irp, instruction->container_type);
    fprintf(irp->f, ", ");
    ir_print_other_instruction(irp, instruction->member_index);
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

static void ir_print_align_of(IrPrint *irp, IrInstructionAlignOf *instruction) {
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

static void ir_print_maybe_wrap(IrPrint *irp, IrInstructionOptionalWrap *instruction) {
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
        if (instruction->is_var_args && i == instruction->base.source_node->data.fn_proto.params.length - 1) {
            fprintf(irp->f, "...");
        } else {
            ir_print_other_instruction(irp, instruction->param_types[i]);
        }
    }
    fprintf(irp->f, ")");
    if (instruction->align_value != nullptr) {
        fprintf(irp->f, " align ");
        ir_print_other_instruction(irp, instruction->align_value);
        fprintf(irp->f, " ");
    }
    fprintf(irp->f, "->");
    ir_print_other_instruction(irp, instruction->return_type);
}

static void ir_print_test_comptime(IrPrint *irp, IrInstructionTestComptime *instruction) {
    fprintf(irp->f, "@testComptime(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_ptr_cast(IrPrint *irp, IrInstructionPtrCast *instruction) {
    fprintf(irp->f, "@ptrCast(");
    if (instruction->dest_type) {
        ir_print_other_instruction(irp, instruction->dest_type);
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ")");
}

static void ir_print_bit_cast(IrPrint *irp, IrInstructionBitCast *instruction) {
    fprintf(irp->f, "@bitCast(");
    if (instruction->dest_type) {
        ir_print_other_instruction(irp, instruction->dest_type);
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->value);
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
    if (instruction->dest_type == nullptr) {
        fprintf(irp->f, "(null)");
    } else {
        ir_print_other_instruction(irp, instruction->dest_type);
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_enum(IrPrint *irp, IrInstructionIntToEnum *instruction) {
    fprintf(irp->f, "@intToEnum(");
    if (instruction->dest_type == nullptr) {
        fprintf(irp->f, "(null)");
    } else {
        ir_print_other_instruction(irp, instruction->dest_type);
    }
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_enum_to_int(IrPrint *irp, IrInstructionEnumToInt *instruction) {
    fprintf(irp->f, "@enumToInt(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_int_to_err(IrPrint *irp, IrInstructionIntToErr *instruction) {
    fprintf(irp->f, "inttoerr ");
    ir_print_other_instruction(irp, instruction->target);
}

static void ir_print_err_to_int(IrPrint *irp, IrInstructionErrToInt *instruction) {
    fprintf(irp->f, "errtoint ");
    ir_print_other_instruction(irp, instruction->target);
}

static void ir_print_check_switch_prongs(IrPrint *irp, IrInstructionCheckSwitchProngs *instruction) {
    fprintf(irp->f, "@checkSwitchProngs(");
    ir_print_other_instruction(irp, instruction->target_value);
    fprintf(irp->f, ",");
    for (size_t i = 0; i < instruction->range_count; i += 1) {
        if (i != 0)
            fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->ranges[i].start);
        fprintf(irp->f, "...");
        ir_print_other_instruction(irp, instruction->ranges[i].end);
    }
    const char *have_else_str = instruction->have_else_prong ? "yes" : "no";
    fprintf(irp->f, ")else:%s", have_else_str);
}

static void ir_print_check_statement_is_void(IrPrint *irp, IrInstructionCheckStatementIsVoid *instruction) {
    fprintf(irp->f, "@checkStatementIsVoid(");
    ir_print_other_instruction(irp, instruction->statement_value);
    fprintf(irp->f, ")");
}

static void ir_print_type_name(IrPrint *irp, IrInstructionTypeName *instruction) {
    fprintf(irp->f, "typename ");
    ir_print_other_instruction(irp, instruction->type_value);
}

static void ir_print_tag_name(IrPrint *irp, IrInstructionTagName *instruction) {
    fprintf(irp->f, "tagname ");
    ir_print_other_instruction(irp, instruction->target);
}

static void ir_print_ptr_type(IrPrint *irp, IrInstructionPtrType *instruction) {
    fprintf(irp->f, "&");
    if (instruction->align_value != nullptr) {
        fprintf(irp->f, "align(");
        ir_print_other_instruction(irp, instruction->align_value);
        fprintf(irp->f, ")");
    }
    const char *const_str = instruction->is_const ? "const " : "";
    const char *volatile_str = instruction->is_volatile ? "volatile " : "";
    fprintf(irp->f, ":%" PRIu32 ":%" PRIu32 " %s%s", instruction->bit_offset_start, instruction->bit_offset_end,
            const_str, volatile_str);
    ir_print_other_instruction(irp, instruction->child_type);
}

static void ir_print_decl_ref(IrPrint *irp, IrInstructionDeclRef *instruction) {
    const char *ptr_str = instruction->lval.is_ptr ? "ptr " : "";
    const char *const_str = instruction->lval.is_const ? "const " : "";
    const char *volatile_str = instruction->lval.is_volatile ? "volatile " : "";
    fprintf(irp->f, "declref %s%s%s%s", const_str, volatile_str, ptr_str, buf_ptr(instruction->tld->name));
}

static void ir_print_panic(IrPrint *irp, IrInstructionPanic *instruction) {
    fprintf(irp->f, "@panic(");
    ir_print_other_instruction(irp, instruction->msg);
    fprintf(irp->f, ")");
}

static void ir_print_field_parent_ptr(IrPrint *irp, IrInstructionFieldParentPtr *instruction) {
    fprintf(irp->f, "@fieldParentPtr(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_name);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_offset_of(IrPrint *irp, IrInstructionOffsetOf *instruction) {
    fprintf(irp->f, "@offset_of(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->field_name);
    fprintf(irp->f, ")");
}

static void ir_print_type_info(IrPrint *irp, IrInstructionTypeInfo *instruction) {
    fprintf(irp->f, "@typeInfo(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_type_id(IrPrint *irp, IrInstructionTypeId *instruction) {
    fprintf(irp->f, "@typeId(");
    ir_print_other_instruction(irp, instruction->type_value);
    fprintf(irp->f, ")");
}

static void ir_print_set_eval_branch_quota(IrPrint *irp, IrInstructionSetEvalBranchQuota *instruction) {
    fprintf(irp->f, "@setEvalBranchQuota(");
    ir_print_other_instruction(irp, instruction->new_quota);
    fprintf(irp->f, ")");
}

static void ir_print_align_cast(IrPrint *irp, IrInstructionAlignCast *instruction) {
    fprintf(irp->f, "@alignCast(");
    if (instruction->align_bytes == nullptr) {
        fprintf(irp->f, "null");
    } else {
        ir_print_other_instruction(irp, instruction->align_bytes);
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_opaque_type(IrPrint *irp, IrInstructionOpaqueType *instruction) {
    fprintf(irp->f, "@OpaqueType()");
}

static void ir_print_set_align_stack(IrPrint *irp, IrInstructionSetAlignStack *instruction) {
    fprintf(irp->f, "@setAlignStack(");
    ir_print_other_instruction(irp, instruction->align_bytes);
    fprintf(irp->f, ")");
}

static void ir_print_arg_type(IrPrint *irp, IrInstructionArgType *instruction) {
    fprintf(irp->f, "@ArgType(");
    ir_print_other_instruction(irp, instruction->fn_type);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->arg_index);
    fprintf(irp->f, ")");
}

static void ir_print_enum_tag_type(IrPrint *irp, IrInstructionTagType *instruction) {
    fprintf(irp->f, "@TagType(");
    ir_print_other_instruction(irp, instruction->target);
    fprintf(irp->f, ")");
}

static void ir_print_export(IrPrint *irp, IrInstructionExport *instruction) {
    if (instruction->linkage == nullptr) {
        fprintf(irp->f, "@export(");
        ir_print_other_instruction(irp, instruction->name);
        fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->target);
        fprintf(irp->f, ")");
    } else {
        fprintf(irp->f, "@exportWithLinkage(");
        ir_print_other_instruction(irp, instruction->name);
        fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->target);
        fprintf(irp->f, ",");
        ir_print_other_instruction(irp, instruction->linkage);
        fprintf(irp->f, ")");
    }
}

static void ir_print_error_return_trace(IrPrint *irp, IrInstructionErrorReturnTrace *instruction) {
    fprintf(irp->f, "@errorReturnTrace(");
    switch (instruction->optional) {
        case IrInstructionErrorReturnTrace::Null:
            fprintf(irp->f, "Null");
            break;
        case IrInstructionErrorReturnTrace::NonNull:
            fprintf(irp->f, "NonNull");
            break;
    }
    fprintf(irp->f, ")");
}

static void ir_print_error_union(IrPrint *irp, IrInstructionErrorUnion *instruction) {
    ir_print_other_instruction(irp, instruction->err_set);
    fprintf(irp->f, "!");
    ir_print_other_instruction(irp, instruction->payload);
}

static void ir_print_cancel(IrPrint *irp, IrInstructionCancel *instruction) {
    fprintf(irp->f, "cancel ");
    ir_print_other_instruction(irp, instruction->target);
}

static void ir_print_get_implicit_allocator(IrPrint *irp, IrInstructionGetImplicitAllocator *instruction) {
    fprintf(irp->f, "@getImplicitAllocator(");
    switch (instruction->id) {
        case ImplicitAllocatorIdArg:
            fprintf(irp->f, "Arg");
            break;
        case ImplicitAllocatorIdLocalVar:
            fprintf(irp->f, "LocalVar");
            break;
    }
    fprintf(irp->f, ")");
}

static void ir_print_coro_id(IrPrint *irp, IrInstructionCoroId *instruction) {
    fprintf(irp->f, "@coroId(");
    ir_print_other_instruction(irp, instruction->promise_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_coro_alloc(IrPrint *irp, IrInstructionCoroAlloc *instruction) {
    fprintf(irp->f, "@coroAlloc(");
    ir_print_other_instruction(irp, instruction->coro_id);
    fprintf(irp->f, ")");
}

static void ir_print_coro_size(IrPrint *irp, IrInstructionCoroSize *instruction) {
    fprintf(irp->f, "@coroSize()");
}

static void ir_print_coro_begin(IrPrint *irp, IrInstructionCoroBegin *instruction) {
    fprintf(irp->f, "@coroBegin(");
    ir_print_other_instruction(irp, instruction->coro_id);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->coro_mem_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_coro_alloc_fail(IrPrint *irp, IrInstructionCoroAllocFail *instruction) {
    fprintf(irp->f, "@coroAllocFail(");
    ir_print_other_instruction(irp, instruction->err_val);
    fprintf(irp->f, ")");
}

static void ir_print_coro_suspend(IrPrint *irp, IrInstructionCoroSuspend *instruction) {
    fprintf(irp->f, "@coroSuspend(");
    if (instruction->save_point != nullptr) {
        ir_print_other_instruction(irp, instruction->save_point);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->is_final);
    fprintf(irp->f, ")");
}

static void ir_print_coro_end(IrPrint *irp, IrInstructionCoroEnd *instruction) {
    fprintf(irp->f, "@coroEnd()");
}

static void ir_print_coro_free(IrPrint *irp, IrInstructionCoroFree *instruction) {
    fprintf(irp->f, "@coroFree(");
    ir_print_other_instruction(irp, instruction->coro_id);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->coro_handle);
    fprintf(irp->f, ")");
}

static void ir_print_coro_resume(IrPrint *irp, IrInstructionCoroResume *instruction) {
    fprintf(irp->f, "@coroResume(");
    ir_print_other_instruction(irp, instruction->awaiter_handle);
    fprintf(irp->f, ")");
}

static void ir_print_coro_save(IrPrint *irp, IrInstructionCoroSave *instruction) {
    fprintf(irp->f, "@coroSave(");
    ir_print_other_instruction(irp, instruction->coro_handle);
    fprintf(irp->f, ")");
}

static void ir_print_coro_promise(IrPrint *irp, IrInstructionCoroPromise *instruction) {
    fprintf(irp->f, "@coroPromise(");
    ir_print_other_instruction(irp, instruction->coro_handle);
    fprintf(irp->f, ")");
}

static void ir_print_promise_result_type(IrPrint *irp, IrInstructionPromiseResultType *instruction) {
    fprintf(irp->f, "@PromiseResultType(");
    ir_print_other_instruction(irp, instruction->promise_type);
    fprintf(irp->f, ")");
}

static void ir_print_coro_alloc_helper(IrPrint *irp, IrInstructionCoroAllocHelper *instruction) {
    fprintf(irp->f, "@coroAllocHelper(");
    ir_print_other_instruction(irp, instruction->alloc_fn);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->coro_size);
    fprintf(irp->f, ")");
}

static void ir_print_atomic_rmw(IrPrint *irp, IrInstructionAtomicRmw *instruction) {
    fprintf(irp->f, "@atomicRmw(");
    if (instruction->operand_type != nullptr) {
        ir_print_other_instruction(irp, instruction->operand_type);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ",");
    if (instruction->op != nullptr) {
        ir_print_other_instruction(irp, instruction->op);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->operand);
    fprintf(irp->f, ",");
    if (instruction->ordering != nullptr) {
        ir_print_other_instruction(irp, instruction->ordering);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ")");
}

static void ir_print_atomic_load(IrPrint *irp, IrInstructionAtomicLoad *instruction) {
    fprintf(irp->f, "@atomicLoad(");
    if (instruction->operand_type != nullptr) {
        ir_print_other_instruction(irp, instruction->operand_type);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->ptr);
    fprintf(irp->f, ",");
    if (instruction->ordering != nullptr) {
        ir_print_other_instruction(irp, instruction->ordering);
    } else {
        fprintf(irp->f, "[TODO print]");
    }
    fprintf(irp->f, ")");
}

static void ir_print_await_bookkeeping(IrPrint *irp, IrInstructionAwaitBookkeeping *instruction) {
    fprintf(irp->f, "@awaitBookkeeping(");
    ir_print_other_instruction(irp, instruction->promise_result_type);
    fprintf(irp->f, ")");
}

static void ir_print_save_err_ret_addr(IrPrint *irp, IrInstructionSaveErrRetAddr *instruction) {
    fprintf(irp->f, "@saveErrRetAddr()");
}

static void ir_print_add_implicit_return_type(IrPrint *irp, IrInstructionAddImplicitReturnType *instruction) {
    fprintf(irp->f, "@addImplicitReturnType(");
    ir_print_other_instruction(irp, instruction->value);
    fprintf(irp->f, ")");
}

static void ir_print_merge_err_ret_traces(IrPrint *irp, IrInstructionMergeErrRetTraces *instruction) {
    fprintf(irp->f, "@mergeErrRetTraces(");
    ir_print_other_instruction(irp, instruction->coro_promise_ptr);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->src_err_ret_trace_ptr);
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->dest_err_ret_trace_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_mark_err_ret_trace_ptr(IrPrint *irp, IrInstructionMarkErrRetTracePtr *instruction) {
    fprintf(irp->f, "@markErrRetTracePtr(");
    ir_print_other_instruction(irp, instruction->err_ret_trace_ptr);
    fprintf(irp->f, ")");
}

static void ir_print_sqrt(IrPrint *irp, IrInstructionSqrt *instruction) {
    fprintf(irp->f, "@sqrt(");
    if (instruction->type != nullptr) {
        ir_print_other_instruction(irp, instruction->type);
    } else {
        fprintf(irp->f, "null");
    }
    fprintf(irp->f, ",");
    ir_print_other_instruction(irp, instruction->op);
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
        case IrInstructionIdUnionInit:
            ir_print_union_init(irp, (IrInstructionUnionInit *)instruction);
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
        case IrInstructionIdUnionFieldPtr:
            ir_print_union_field_ptr(irp, (IrInstructionUnionFieldPtr *)instruction);
            break;
        case IrInstructionIdSetCold:
            ir_print_set_cold(irp, (IrInstructionSetCold *)instruction);
            break;
        case IrInstructionIdSetRuntimeSafety:
            ir_print_set_runtime_safety(irp, (IrInstructionSetRuntimeSafety *)instruction);
            break;
        case IrInstructionIdSetFloatMode:
            ir_print_set_float_mode(irp, (IrInstructionSetFloatMode *)instruction);
            break;
        case IrInstructionIdArrayType:
            ir_print_array_type(irp, (IrInstructionArrayType *)instruction);
            break;
        case IrInstructionIdPromiseType:
            ir_print_promise_type(irp, (IrInstructionPromiseType *)instruction);
            break;
        case IrInstructionIdSliceType:
            ir_print_slice_type(irp, (IrInstructionSliceType *)instruction);
            break;
        case IrInstructionIdAsm:
            ir_print_asm(irp, (IrInstructionAsm *)instruction);
            break;
        case IrInstructionIdSizeOf:
            ir_print_size_of(irp, (IrInstructionSizeOf *)instruction);
            break;
        case IrInstructionIdTestNonNull:
            ir_print_test_null(irp, (IrInstructionTestNonNull *)instruction);
            break;
        case IrInstructionIdUnwrapOptional:
            ir_print_unwrap_maybe(irp, (IrInstructionUnwrapOptional *)instruction);
            break;
        case IrInstructionIdCtz:
            ir_print_ctz(irp, (IrInstructionCtz *)instruction);
            break;
        case IrInstructionIdPopCount:
            ir_print_pop_count(irp, (IrInstructionPopCount *)instruction);
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
        case IrInstructionIdUnionTag:
            ir_print_union_tag(irp, (IrInstructionUnionTag *)instruction);
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
        case IrInstructionIdCompileLog:
            ir_print_compile_log(irp, (IrInstructionCompileLog *)instruction);
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
        case IrInstructionIdTruncate:
            ir_print_truncate(irp, (IrInstructionTruncate *)instruction);
            break;
        case IrInstructionIdIntCast:
            ir_print_int_cast(irp, (IrInstructionIntCast *)instruction);
            break;
        case IrInstructionIdFloatCast:
            ir_print_float_cast(irp, (IrInstructionFloatCast *)instruction);
            break;
        case IrInstructionIdErrSetCast:
            ir_print_err_set_cast(irp, (IrInstructionErrSetCast *)instruction);
            break;
        case IrInstructionIdFromBytes:
            ir_print_from_bytes(irp, (IrInstructionFromBytes *)instruction);
            break;
        case IrInstructionIdToBytes:
            ir_print_to_bytes(irp, (IrInstructionToBytes *)instruction);
            break;
        case IrInstructionIdIntToFloat:
            ir_print_int_to_float(irp, (IrInstructionIntToFloat *)instruction);
            break;
        case IrInstructionIdFloatToInt:
            ir_print_float_to_int(irp, (IrInstructionFloatToInt *)instruction);
            break;
        case IrInstructionIdBoolToInt:
            ir_print_bool_to_int(irp, (IrInstructionBoolToInt *)instruction);
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
        case IrInstructionIdMemberType:
            ir_print_member_type(irp, (IrInstructionMemberType *)instruction);
            break;
        case IrInstructionIdMemberName:
            ir_print_member_name(irp, (IrInstructionMemberName *)instruction);
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
            ir_print_align_of(irp, (IrInstructionAlignOf *)instruction);
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
        case IrInstructionIdOptionalWrap:
            ir_print_maybe_wrap(irp, (IrInstructionOptionalWrap *)instruction);
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
        case IrInstructionIdPtrCast:
            ir_print_ptr_cast(irp, (IrInstructionPtrCast *)instruction);
            break;
        case IrInstructionIdBitCast:
            ir_print_bit_cast(irp, (IrInstructionBitCast *)instruction);
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
        case IrInstructionIdIntToErr:
            ir_print_int_to_err(irp, (IrInstructionIntToErr *)instruction);
            break;
        case IrInstructionIdErrToInt:
            ir_print_err_to_int(irp, (IrInstructionErrToInt *)instruction);
            break;
        case IrInstructionIdCheckSwitchProngs:
            ir_print_check_switch_prongs(irp, (IrInstructionCheckSwitchProngs *)instruction);
            break;
        case IrInstructionIdCheckStatementIsVoid:
            ir_print_check_statement_is_void(irp, (IrInstructionCheckStatementIsVoid *)instruction);
            break;
        case IrInstructionIdTypeName:
            ir_print_type_name(irp, (IrInstructionTypeName *)instruction);
            break;
        case IrInstructionIdTagName:
            ir_print_tag_name(irp, (IrInstructionTagName *)instruction);
            break;
        case IrInstructionIdPtrType:
            ir_print_ptr_type(irp, (IrInstructionPtrType *)instruction);
            break;
        case IrInstructionIdDeclRef:
            ir_print_decl_ref(irp, (IrInstructionDeclRef *)instruction);
            break;
        case IrInstructionIdPanic:
            ir_print_panic(irp, (IrInstructionPanic *)instruction);
            break;
        case IrInstructionIdFieldParentPtr:
            ir_print_field_parent_ptr(irp, (IrInstructionFieldParentPtr *)instruction);
            break;
        case IrInstructionIdOffsetOf:
            ir_print_offset_of(irp, (IrInstructionOffsetOf *)instruction);
            break;
        case IrInstructionIdTypeInfo:
            ir_print_type_info(irp, (IrInstructionTypeInfo *)instruction);
            break;
        case IrInstructionIdTypeId:
            ir_print_type_id(irp, (IrInstructionTypeId *)instruction);
            break;
        case IrInstructionIdSetEvalBranchQuota:
            ir_print_set_eval_branch_quota(irp, (IrInstructionSetEvalBranchQuota *)instruction);
            break;
        case IrInstructionIdAlignCast:
            ir_print_align_cast(irp, (IrInstructionAlignCast *)instruction);
            break;
        case IrInstructionIdOpaqueType:
            ir_print_opaque_type(irp, (IrInstructionOpaqueType *)instruction);
            break;
        case IrInstructionIdSetAlignStack:
            ir_print_set_align_stack(irp, (IrInstructionSetAlignStack *)instruction);
            break;
        case IrInstructionIdArgType:
            ir_print_arg_type(irp, (IrInstructionArgType *)instruction);
            break;
        case IrInstructionIdTagType:
            ir_print_enum_tag_type(irp, (IrInstructionTagType *)instruction);
            break;
        case IrInstructionIdExport:
            ir_print_export(irp, (IrInstructionExport *)instruction);
            break;
        case IrInstructionIdErrorReturnTrace:
            ir_print_error_return_trace(irp, (IrInstructionErrorReturnTrace *)instruction);
            break;
        case IrInstructionIdErrorUnion:
            ir_print_error_union(irp, (IrInstructionErrorUnion *)instruction);
            break;
        case IrInstructionIdCancel:
            ir_print_cancel(irp, (IrInstructionCancel *)instruction);
            break;
        case IrInstructionIdGetImplicitAllocator:
            ir_print_get_implicit_allocator(irp, (IrInstructionGetImplicitAllocator *)instruction);
            break;
        case IrInstructionIdCoroId:
            ir_print_coro_id(irp, (IrInstructionCoroId *)instruction);
            break;
        case IrInstructionIdCoroAlloc:
            ir_print_coro_alloc(irp, (IrInstructionCoroAlloc *)instruction);
            break;
        case IrInstructionIdCoroSize:
            ir_print_coro_size(irp, (IrInstructionCoroSize *)instruction);
            break;
        case IrInstructionIdCoroBegin:
            ir_print_coro_begin(irp, (IrInstructionCoroBegin *)instruction);
            break;
        case IrInstructionIdCoroAllocFail:
            ir_print_coro_alloc_fail(irp, (IrInstructionCoroAllocFail *)instruction);
            break;
        case IrInstructionIdCoroSuspend:
            ir_print_coro_suspend(irp, (IrInstructionCoroSuspend *)instruction);
            break;
        case IrInstructionIdCoroEnd:
            ir_print_coro_end(irp, (IrInstructionCoroEnd *)instruction);
            break;
        case IrInstructionIdCoroFree:
            ir_print_coro_free(irp, (IrInstructionCoroFree *)instruction);
            break;
        case IrInstructionIdCoroResume:
            ir_print_coro_resume(irp, (IrInstructionCoroResume *)instruction);
            break;
        case IrInstructionIdCoroSave:
            ir_print_coro_save(irp, (IrInstructionCoroSave *)instruction);
            break;
        case IrInstructionIdCoroAllocHelper:
            ir_print_coro_alloc_helper(irp, (IrInstructionCoroAllocHelper *)instruction);
            break;
        case IrInstructionIdAtomicRmw:
            ir_print_atomic_rmw(irp, (IrInstructionAtomicRmw *)instruction);
            break;
        case IrInstructionIdCoroPromise:
            ir_print_coro_promise(irp, (IrInstructionCoroPromise *)instruction);
            break;
        case IrInstructionIdPromiseResultType:
            ir_print_promise_result_type(irp, (IrInstructionPromiseResultType *)instruction);
            break;
        case IrInstructionIdAwaitBookkeeping:
            ir_print_await_bookkeeping(irp, (IrInstructionAwaitBookkeeping *)instruction);
            break;
        case IrInstructionIdSaveErrRetAddr:
            ir_print_save_err_ret_addr(irp, (IrInstructionSaveErrRetAddr *)instruction);
            break;
        case IrInstructionIdAddImplicitReturnType:
            ir_print_add_implicit_return_type(irp, (IrInstructionAddImplicitReturnType *)instruction);
            break;
        case IrInstructionIdMergeErrRetTraces:
            ir_print_merge_err_ret_traces(irp, (IrInstructionMergeErrRetTraces *)instruction);
            break;
        case IrInstructionIdMarkErrRetTracePtr:
            ir_print_mark_err_ret_trace_ptr(irp, (IrInstructionMarkErrRetTracePtr *)instruction);
            break;
        case IrInstructionIdSqrt:
            ir_print_sqrt(irp, (IrInstructionSqrt *)instruction);
            break;
        case IrInstructionIdAtomicLoad:
            ir_print_atomic_load(irp, (IrInstructionAtomicLoad *)instruction);
            break;
        case IrInstructionIdEnumToInt:
            ir_print_enum_to_int(irp, (IrInstructionEnumToInt *)instruction);
            break;
    }
    fprintf(irp->f, "\n");
}

void ir_print(CodeGen *codegen, FILE *f, IrExecutable *executable, int indent_size) {
    IrPrint ir_print = {};
    IrPrint *irp = &ir_print;
    irp->codegen = codegen;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;

    for (size_t bb_i = 0; bb_i < executable->basic_block_list.length; bb_i += 1) {
        IrBasicBlock *current_block = executable->basic_block_list.at(bb_i);
        fprintf(irp->f, "%s_%" ZIG_PRI_usize ":\n", current_block->name_hint, current_block->debug_id);
        for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
            IrInstruction *instruction = current_block->instruction_list.at(instr_i);
            ir_print_instruction(irp, instruction);
        }
    }
}
