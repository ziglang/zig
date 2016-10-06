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
    fprintf(irp->f, "return #%zu;\n", return_instruction->value->debug_id);
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
        case TypeTableEntryIdVar:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
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
        case IrInstructionIdCondBr:
        case IrInstructionIdSwitchBr:
        case IrInstructionIdPhi:
        case IrInstructionIdStoreVar:
        case IrInstructionIdCall:
        case IrInstructionIdBuiltinCall:
        case IrInstructionIdCast:
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
        for (size_t instr_i = 0; instr_i < current_block->instruction_list.length; instr_i += 1) {
            IrInstruction *instruction = current_block->instruction_list.at(instr_i);
            ir_print_instruction(irp, instruction);
        }
    }
}
