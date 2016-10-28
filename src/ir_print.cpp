#include "ir.hpp"
#include "ir_print.hpp"

struct IrPrint {
    FILE *f;
    int indent;
    int indent_size;
};

static void ir_print_indent(IrPrint *irp) {
    for (int i = 0; i < irp->indent; i += 1) {
        fprintf(irp->f, " ");
    }
}

static void ir_print_prefix(IrPrint *irp, IrInstruction *instruction) {
    ir_print_indent(irp);
    const char *type_name = instruction->type_entry ? buf_ptr(&instruction->type_entry->name) : "(unknown)";
    const char *ref_count = ir_has_side_effects(instruction) ?
        "-" : buf_ptr(buf_sprintf("%zu", instruction->ref_count));
    fprintf(irp->f, "#%-3zu| %-12s| %-2s| ", instruction->debug_id, type_name, ref_count);
}

static void ir_print_const_value(IrPrint *irp, TypeTableEntry *type_entry, ConstExprValue *const_val) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdVoid:
            fprintf(irp->f, "{}");
            break;
        case TypeTableEntryIdNumLitFloat:
            fprintf(irp->f, "%f", const_val->data.x_bignum.data.x_float);
            break;
        case TypeTableEntryIdNumLitInt:
            {
                BigNum *bignum = &const_val->data.x_bignum;
                const char *negative_str = bignum->is_negative ? "-" : "";
                fprintf(irp->f, "%s%llu", negative_str, bignum->data.x_uint);
                break;
            }
        case TypeTableEntryIdMetaType:
            fprintf(irp->f, "%s", buf_ptr(&const_val->data.x_type->name));
            break;
        case TypeTableEntryIdInt:
            {
                BigNum *bignum = &const_val->data.x_bignum;
                assert(bignum->kind == BigNumKindInt);
                const char *negative_str = bignum->is_negative ? "-" : "";
                fprintf(irp->f, "%s%llu", negative_str, bignum->data.x_uint);
            }
            break;
        case TypeTableEntryIdUnreachable:
            fprintf(irp->f, "@unreachable()");
            break;
        case TypeTableEntryIdBool:
            {
                const char *value = const_val->data.x_bool ? "true" : "false";
                fprintf(irp->f, "%s", value);
                break;
            }
        case TypeTableEntryIdPointer:
            fprintf(irp->f, "&");
            ir_print_const_value(irp, type_entry->data.pointer.child_type, const_val->data.x_ptr.ptr[0]);
            break;
        case TypeTableEntryIdFn:
            {
                FnTableEntry *fn_entry = const_val->data.x_fn;
                fprintf(irp->f, "%s", buf_ptr(&fn_entry->symbol_name));
                break;
            }
        case TypeTableEntryIdVar:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
            zig_panic("TODO render more constant types in IR printer");
    }
}

static void ir_print_const_instruction(IrPrint *irp, IrInstruction *instruction) {
    TypeTableEntry *type_entry = instruction->type_entry;
    ConstExprValue *const_val = &instruction->static_value;
    ir_print_const_value(irp, type_entry, const_val);
}

static void ir_print_var_instruction(IrPrint *irp, IrInstruction *instruction) {
    fprintf(irp->f, "#%zu", instruction->debug_id);
}

static void ir_print_other_instruction(IrPrint *irp, IrInstruction *instruction) {
    if (instruction->static_value.ok) {
        ir_print_const_instruction(irp, instruction);
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
    ir_print_const_instruction(irp, &const_instruction->base);
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
        case IrUnOpBoolNot:
            return "!";
        case IrUnOpBinNot:
            return "~";
        case IrUnOpNegation:
            return "-";
        case IrUnOpNegationWrap:
            return "-%";
        case IrUnOpAddressOf:
            return "&";
        case IrUnOpConstAddressOf:
            return "&const";
        case IrUnOpDereference:
            return "*";
        case IrUnOpMaybe:
            return "?";
        case IrUnOpError:
            return "%";
        case IrUnOpUnwrapError:
            return "%%";
        case IrUnOpUnwrapMaybe:
            return "??";
        case IrUnOpMaybeReturn:
            return "?return";
        case IrUnOpErrorReturn:
            return "%return";
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
}

static void ir_print_decl_var(IrPrint *irp, IrInstructionDeclVar *decl_var_instruction) {
    const char *var_or_const = decl_var_instruction->var->is_const ? "const" : "var";
    const char *name = buf_ptr(&decl_var_instruction->var->name);
    if (decl_var_instruction->var_type) {
        fprintf(irp->f, "%s %s: ", var_or_const, name);
        ir_print_other_instruction(irp, decl_var_instruction->var_type);
        fprintf(irp->f, " = ");
    } else {
        fprintf(irp->f, "%s %s = ", var_or_const, name);
    }
    ir_print_other_instruction(irp, decl_var_instruction->init_value);
}

static void ir_print_cast(IrPrint *irp, IrInstructionCast *cast_instruction) {
    fprintf(irp->f, "cast ");
    ir_print_other_instruction(irp, cast_instruction->value);
    fprintf(irp->f, " to ");
    ir_print_other_instruction(irp, cast_instruction->dest_type);
}

static void ir_print_call(IrPrint *irp, IrInstructionCall *call_instruction) {
    ir_print_other_instruction(irp, call_instruction->fn);
    fprintf(irp->f, "(");
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        IrInstruction *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        ir_print_other_instruction(irp, arg);
    }
    fprintf(irp->f, ")");
}

static void ir_print_builtin_call(IrPrint *irp, IrInstructionBuiltinCall *call_instruction) {
    fprintf(irp->f, "@%s(", buf_ptr(&call_instruction->fn->name));
    for (size_t i = 0; i < call_instruction->fn->param_count; i += 1) {
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
}

static void ir_print_br(IrPrint *irp, IrInstructionBr *br_instruction) {
    fprintf(irp->f, "goto ");
    ir_print_other_block(irp, br_instruction->dest_block);
}

static void ir_print_phi(IrPrint *irp, IrInstructionPhi *phi_instruction) {
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
        Buf *name = instruction->field_names[i];
        IrInstruction *field_value = instruction->field_values[i];
        const char *comma = (i == 0) ? "" : ", ";
        fprintf(irp->f, "%s.%s = ", comma, buf_ptr(name));
        ir_print_other_instruction(irp, field_value);
    }
    fprintf(irp->f, "}");
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
        case IrInstructionIdBuiltinCall:
            ir_print_builtin_call(irp, (IrInstructionBuiltinCall *)instruction);
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
        case IrInstructionIdSwitchBr:
        case IrInstructionIdFieldPtr:
            zig_panic("TODO print more IR instructions");
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
