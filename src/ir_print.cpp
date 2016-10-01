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
    switch (const_instruction->base.type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdVoid:
            fprintf(irp->f, "void\n");
            break;
        case TypeTableEntryIdVar:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
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

void ir_print(FILE *f, IrExecutable *executable, int indent_size) {
    IrPrint ir_print = {};
    IrPrint *irp = &ir_print;
    irp->f = f;
    irp->indent = indent_size;
    irp->indent_size = indent_size;

    for (size_t i = 0; i < executable->basic_block_count; i += 1) {
        IrBasicBlock *current_block = executable->basic_block_list[i];
        for (IrInstruction *instruction = current_block->first; instruction != nullptr;
                instruction = instruction->next)
        {
            switch (instruction->id) {
                case IrInstructionIdInvalid:
                    zig_unreachable();
                case IrInstructionIdReturn:
                    ir_print_return(irp, (IrInstructionReturn *)instruction);
                    break;
                case IrInstructionIdConst:
                    ir_print_const(irp, (IrInstructionConst *)instruction);
                    break;
                case IrInstructionIdCondBr:
                case IrInstructionIdSwitchBr:
                case IrInstructionIdPhi:
                case IrInstructionIdBinOp:
                case IrInstructionIdLoadVar:
                case IrInstructionIdStoreVar:
                case IrInstructionIdCall:
                case IrInstructionIdBuiltinCall:
                    zig_panic("TODO print more IR instructions");
            }
        }
    }
}
