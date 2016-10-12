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
    fprintf(irp->f, "#%-3zu| ", instruction->debug_id);
}

static void ir_print_return(IrPrint *irp, IrInstructionReturn *return_instruction) {
    ir_print_prefix(irp, &return_instruction->base);
    assert(return_instruction->value);
    fprintf(irp->f, "return #%zu\n", return_instruction->value->debug_id);
}

static void ir_print_const(IrPrint *irp, IrInstructionConst *const_instruction) {
    ir_print_prefix(irp, &const_instruction->base);
    TypeTableEntry *type_entry = const_instruction->base.type_entry;
    fprintf(irp->f, "%s ", buf_ptr(&type_entry->name));
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdVoid:
            fprintf(irp->f, "%s\n", "void");
            break;
        case TypeTableEntryIdNumLitFloat:
            fprintf(irp->f, "%f\n", const_instruction->base.static_value.data.x_bignum.data.x_float);
            break;
        case TypeTableEntryIdNumLitInt:
            {
                BigNum *bignum = &const_instruction->base.static_value.data.x_bignum;
                const char *negative_str = bignum->is_negative ? "-" : "";
                fprintf(irp->f, "%s%llu\n", negative_str, bignum->data.x_uint);
                break;
            }
        case TypeTableEntryIdMetaType:
            fprintf(irp->f, "%s\n", buf_ptr(&const_instruction->base.static_value.data.x_type->name));
            break;
        case TypeTableEntryIdInt:
            {
                BigNum *bignum = &const_instruction->base.static_value.data.x_bignum;
                assert(bignum->kind == BigNumKindInt);
                const char *negative_str = bignum->is_negative ? "-" : "";
                fprintf(irp->f, "%s%llu\n", negative_str, bignum->data.x_uint);
            }
            break;
        case TypeTableEntryIdVar:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
            zig_panic("TODO render more constant types in IR printer");
    }
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
    ir_print_prefix(irp, &un_op_instruction->base);
    fprintf(irp->f, "%s #%zu\n",
            ir_un_op_id_str(un_op_instruction->op_id),
            un_op_instruction->value->debug_id);
}

static void ir_print_bin_op(IrPrint *irp, IrInstructionBinOp *bin_op_instruction) {
    ir_print_prefix(irp, &bin_op_instruction->base);
    fprintf(irp->f, "#%zu %s #%zu\n",
            bin_op_instruction->op1->debug_id,
            ir_bin_op_id_str(bin_op_instruction->op_id),
            bin_op_instruction->op2->debug_id);
}

static void ir_print_load_var(IrPrint *irp, IrInstructionLoadVar *load_var_instruction) {
    ir_print_prefix(irp, &load_var_instruction->base);
    fprintf(irp->f, "%s\n",
            buf_ptr(&load_var_instruction->var->name));
}

static void ir_print_cast(IrPrint *irp, IrInstructionCast *cast_instruction) {
    ir_print_prefix(irp, &cast_instruction->base);
    fprintf(irp->f, "cast #%zu to #%zu\n",
            cast_instruction->value->debug_id,
            cast_instruction->dest_type->debug_id);
}

static void ir_print_call(IrPrint *irp, IrInstructionCall *call_instruction) {
    ir_print_prefix(irp, &call_instruction->base);
    fprintf(irp->f, "#%zu(", call_instruction->fn->debug_id);
    for (size_t i = 0; i < call_instruction->arg_count; i += 1) {
        IrInstruction *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        fprintf(irp->f, "#%zu", arg->debug_id);
    }
    fprintf(irp->f, ")\n");
}

static void ir_print_builtin_call(IrPrint *irp, IrInstructionBuiltinCall *call_instruction) {
    ir_print_prefix(irp, &call_instruction->base);
    fprintf(irp->f, "@%s(", buf_ptr(&call_instruction->fn->name));
    for (size_t i = 0; i < call_instruction->fn->param_count; i += 1) {
        IrInstruction *arg = call_instruction->args[i];
        if (i != 0)
            fprintf(irp->f, ", ");
        fprintf(irp->f, "#%zu", arg->debug_id);
    }
    fprintf(irp->f, ")\n");
}


static void ir_print_cond_br(IrPrint *irp, IrInstructionCondBr *cond_br_instruction) {
    ir_print_prefix(irp, &cond_br_instruction->base);
    fprintf(irp->f, "if #%zu then $%s_%zu else $%s_%zu\n",
            cond_br_instruction->condition->debug_id,
            cond_br_instruction->then_block->name_hint, cond_br_instruction->then_block->debug_id,
            cond_br_instruction->else_block->name_hint, cond_br_instruction->else_block->debug_id);
}

static void ir_print_br(IrPrint *irp, IrInstructionBr *br_instruction) {
    ir_print_prefix(irp, &br_instruction->base);
    fprintf(irp->f, "goto $%s_%zu\n",
            br_instruction->dest_block->name_hint, br_instruction->dest_block->debug_id);
}

static void ir_print_phi(IrPrint *irp, IrInstructionPhi *phi_instruction) {
    ir_print_prefix(irp, &phi_instruction->base);
    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        IrBasicBlock *incoming_block = phi_instruction->incoming_blocks[i];
        IrInstruction *incoming_value = phi_instruction->incoming_values[i];
        if (i != 0)
            fprintf(irp->f, " ");
        fprintf(irp->f, "$%s_%zu:#%zu",
                incoming_block->name_hint, incoming_block->debug_id,
                incoming_value->debug_id);
    }
    fprintf(irp->f, "\n");
}

static void ir_print_instruction(IrPrint *irp, IrInstruction *instruction) {
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
        case IrInstructionIdLoadVar:
            ir_print_load_var(irp, (IrInstructionLoadVar *)instruction);
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
        case IrInstructionIdSwitchBr:
        case IrInstructionIdStoreVar:
            zig_panic("TODO print more IR instructions");
    }
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
