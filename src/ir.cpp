#include "analyze.hpp"
#include "ir.hpp"
#include "error.hpp"

struct IrGen {
    CodeGen *codegen;
    AstNode *node;
    IrBasicBlock *current_basic_block;
    IrExecutable *exec;
};

static IrInstruction *ir_gen_node(IrGen *ir, AstNode *node, BlockContext *block_context);

static void ir_instruction_append(IrBasicBlock *basic_block, IrInstruction *instruction) {
    if (!basic_block->last) {
        basic_block->first = instruction;
        basic_block->last = instruction;
        instruction->prev = nullptr;
        instruction->next = nullptr;
    } else {
        basic_block->last->next = instruction;
        instruction->prev = basic_block->last;
        instruction->next = nullptr;
        basic_block->last = instruction;
    }
}

static size_t exec_next_debug_id(IrGen *ir) {
    size_t result = ir->exec->next_debug_id;
    ir->exec->next_debug_id += 1;
    return result;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCondBr *) {
    return IrInstructionIdCondBr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSwitchBr *) {
    return IrInstructionIdSwitchBr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionPhi *) {
    return IrInstructionIdPhi;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionBinOp *) {
    return IrInstructionIdBinOp;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionLoadVar *) {
    return IrInstructionIdLoadVar;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionStoreVar *) {
    return IrInstructionIdStoreVar;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCall *) {
    return IrInstructionIdCall;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionBuiltinCall *) {
    return IrInstructionIdBuiltinCall;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionConst *) {
    return IrInstructionIdConst;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionReturn *) {
    return IrInstructionIdReturn;
}

template<typename T>
static T *ir_build_instruction(IrGen *ir, AstNode *source_node) {
    T *special_instruction = allocate<T>(1);
    special_instruction->base.id = ir_instruction_id(special_instruction);
    special_instruction->base.source_node = source_node;
    special_instruction->base.type_entry = ir->codegen->builtin_types.entry_unreachable;
    special_instruction->base.debug_id = exec_next_debug_id(ir);
    ir_instruction_append(ir->current_basic_block, &special_instruction->base);
    return special_instruction;
}

static IrInstruction *ir_build_return(IrGen *ir, AstNode *source_node, IrInstruction *return_value) {
    IrInstructionReturn *return_instruction = ir_build_instruction<IrInstructionReturn>(ir, source_node);
    return_instruction->base.type_entry = ir->codegen->builtin_types.entry_unreachable;
    return_instruction->base.static_value.ok = true;
    return_instruction->value = return_value;
    return &return_instruction->base;
}

static IrInstruction *ir_build_void(IrGen *ir, AstNode *source_node) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(ir, source_node);
    const_instruction->base.type_entry = ir->codegen->builtin_types.entry_void;
    const_instruction->base.static_value.ok = true;
    return &const_instruction->base;
}

//static size_t get_conditional_defer_count(BlockContext *inner_block, BlockContext *outer_block) {
//    size_t result = 0;
//    while (inner_block != outer_block) {
//        if (inner_block->node->type == NodeTypeDefer &&
//           (inner_block->node->data.defer.kind == ReturnKindError ||
//            inner_block->node->data.defer.kind == ReturnKindMaybe))
//        {
//            result += 1;
//        }
//        inner_block = inner_block->parent;
//    }
//    return result;
//}

static void ir_gen_defers_for_block(IrGen *ir, BlockContext *inner_block, BlockContext *outer_block,
        bool gen_error_defers, bool gen_maybe_defers)
{
    while (inner_block != outer_block) {
        if (inner_block->node->type == NodeTypeDefer &&
           ((inner_block->node->data.defer.kind == ReturnKindUnconditional) ||
            (gen_error_defers && inner_block->node->data.defer.kind == ReturnKindError) ||
            (gen_maybe_defers && inner_block->node->data.defer.kind == ReturnKindMaybe)))
        {
            AstNode *defer_expr_node = inner_block->node->data.defer.expr;
            ir_gen_node(ir, defer_expr_node, defer_expr_node->block_context);
        }
        inner_block = inner_block->parent;
    }
}

//static IrInstruction *ir_gen_return(IrGen *ir, AstNode *source_node, IrInstruction *value, ReturnKnowledge rk) {
//    BlockContext *defer_inner_block = source_node->block_context;
//    BlockContext *defer_outer_block = ir->node->block_context;
//    if (rk == ReturnKnowledgeUnknown) {
//        if (get_conditional_defer_count(defer_inner_block, defer_outer_block) > 0) {
//            // generate branching code that checks the return value and generates defers
//            // if the return value is error
//            zig_panic("TODO");
//        }
//    } else if (rk != ReturnKnowledgeSkipDefers) {
//        ir_gen_defers_for_block(ir, defer_inner_block, defer_outer_block,
//                rk == ReturnKnowledgeKnownError, rk == ReturnKnowledgeKnownNull);
//    }
//
//    return ir_build_return(ir, source_node, value);
//}

static IrInstruction *ir_gen_block(IrGen *ir, AstNode *block_node) {
    assert(block_node->type == NodeTypeBlock);

    BlockContext *parent_context = block_node->block_context;
    BlockContext *outer_block_context = new_block_context(block_node, parent_context);
    BlockContext *child_context = outer_block_context;

    IrInstruction *return_value = nullptr;
    for (size_t i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        return_value = ir_gen_node(ir, statement_node, child_context);
        if (statement_node->type == NodeTypeDefer && return_value != ir->codegen->invalid_instruction) {
            // defer starts a new block context
            child_context = statement_node->data.defer.child_block;
            assert(child_context);
        }
    }

    if (!return_value)
        return_value = ir_build_void(ir, block_node);

    ir_gen_defers_for_block(ir, child_context, outer_block_context, false, false);

    return return_value;
}

static IrInstruction *ir_gen_node(IrGen *ir, AstNode *node, BlockContext *block_context) {
    node->block_context = block_context;

    switch (node->type) {
        case NodeTypeBlock:
            return ir_gen_block(ir, node);
        case NodeTypeBinOpExpr:
        case NodeTypeUnwrapErrorExpr:
        case NodeTypeReturnExpr:
        case NodeTypeDefer:
        case NodeTypeVariableDeclaration:
        case NodeTypePrefixOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeForExpr:
        case NodeTypeAsmExpr:
        case NodeTypeSymbol:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeLabel:
        case NodeTypeContainerInitExpr:
        case NodeTypeSwitchExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeZeroesLiteral:
        case NodeTypeThisLiteral:
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
        case NodeTypeArrayType:
        case NodeTypeVarLiteral:
        case NodeTypeRoot:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeUse:
        case NodeTypeContainerDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeErrorValueDecl:
        case NodeTypeTypeDecl:
            zig_panic("TODO more IR gen");
    }
    zig_unreachable();
}

static IrInstruction *ir_gen_add_return(CodeGen *g, AstNode *node, BlockContext *scope,
        IrExecutable *ir_executable, bool add_return)
{
    assert(node->owner);

    IrGen ir_gen = {0};
    IrGen *ir = &ir_gen;

    ir->codegen = g;
    ir->node = node;
    ir->exec = ir_executable;

    ir->exec->basic_block_list = allocate<IrBasicBlock*>(1);
    ir->exec->basic_block_count = 1;

    IrBasicBlock *entry_basic_block = allocate<IrBasicBlock>(1);
    ir->current_basic_block = entry_basic_block;
    ir->exec->basic_block_list[0] = entry_basic_block;

    IrInstruction *result = ir_gen_node(ir, node, scope);
    assert(result);

    if (result == g->invalid_instruction)
        return result;

    if (add_return)
        return ir_build_return(ir, result->source_node, result);

    return result;
}

IrInstruction *ir_gen(CodeGen *g, AstNode *node, BlockContext *scope, IrExecutable *ir_executable) {
    return ir_gen_add_return(g, node, scope, ir_executable, false);
}

IrInstruction *ir_gen_fn(CodeGen *g, FnTableEntry *fn_entry) {
    assert(fn_entry);

    IrExecutable *ir_executable = &fn_entry->ir_executable;
    AstNode *fn_def_node = fn_entry->fn_def_node;
    assert(fn_def_node->type == NodeTypeFnDef);

    AstNode *body_node = fn_def_node->data.fn_def.body;
    BlockContext *scope = fn_def_node->data.fn_def.block_context;

    bool add_return_yes = true;
    return ir_gen_add_return(g, body_node, scope, ir_executable, add_return_yes);
}

/*
static void analyze_goto_pass2(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeGoto);
    Buf *label_name = node->data.goto_expr.name;
    BlockContext *context = node->block_context;
    assert(context);
    LabelTableEntry *label = find_label(g, context, label_name);

    if (!label) {
        add_node_error(g, node, buf_sprintf("no label in scope named '%s'", buf_ptr(label_name)));
        return;
    }

    label->used = true;
    node->data.goto_expr.label_entry = label;
}

    for (size_t i = 0; i < fn_table_entry->goto_list.length; i += 1) {
        AstNode *goto_node = fn_table_entry->goto_list.at(i);
        assert(goto_node->type == NodeTypeGoto);
        analyze_goto_pass2(g, import, goto_node);
    }

    for (size_t i = 0; i < fn_table_entry->all_labels.length; i += 1) {
        LabelTableEntry *label = fn_table_entry->all_labels.at(i);
        if (!label->used) {
            add_node_error(g, label->decl_node,
                    buf_sprintf("label '%s' defined but not used",
                        buf_ptr(label->decl_node->data.label.name)));
        }
    }
*/

//static LabelTableEntry *find_label(CodeGen *g, BlockContext *orig_context, Buf *name) {
//    BlockContext *context = orig_context;
//    while (context && context->fn_entry) {
//        auto entry = context->label_table.maybe_get(name);
//        if (entry) {
//            return entry->value;
//        }
//        context = context->parent;
//    }
//    return nullptr;
//}

static IrInstruction *ir_get_casted_instruction(CodeGen *g, IrInstruction *instruction,
        TypeTableEntry *expected_type)
{
    assert(instruction);
    assert(instruction != g->invalid_instruction);
    assert(!expected_type || expected_type->id != TypeTableEntryIdInvalid);
    assert(instruction->type_entry);
    assert(instruction->type_entry->id != TypeTableEntryIdInvalid);
    if (expected_type == nullptr)
        return instruction; // anything will do
    if (expected_type == instruction->type_entry)
        return instruction; // match
    if (instruction->type_entry->id == TypeTableEntryIdUnreachable)
        return instruction;

    zig_panic("TODO implicit cast instruction");
}

static TypeTableEntry *ir_analyze_instruction_return(CodeGen *g, IrInstructionReturn *return_instruction) {
    AstNode *source_node = return_instruction->base.source_node;
    BlockContext *scope = source_node->block_context;
    if (!scope->fn_entry) {
        add_node_error(g, source_node, buf_sprintf("return expression outside function definition"));
        return g->builtin_types.entry_invalid;
    }

    TypeTableEntry *expected_return_type = scope->fn_entry->type_entry->data.fn.fn_type_id.return_type;
    if (expected_return_type->id == TypeTableEntryIdVoid && !return_instruction->value) {
        return g->builtin_types.entry_unreachable;
    }

    return_instruction->value = ir_get_casted_instruction(g, return_instruction->value, expected_return_type);
    if (return_instruction->value == g->invalid_instruction) {
        return g->builtin_types.entry_invalid;
    }
    return g->builtin_types.entry_unreachable;
}

static TypeTableEntry *ir_analyze_instruction_const(CodeGen *g, IrInstructionConst *const_instruction) {
    return const_instruction->base.type_entry;
}

static TypeTableEntry *ir_analyze_instruction_nocast(CodeGen *g, IrInstruction *instruction) {
    switch (instruction->id) {
        case IrInstructionIdInvalid:
            zig_unreachable();
        case IrInstructionIdReturn:
            return ir_analyze_instruction_return(g, (IrInstructionReturn *)instruction);
        case IrInstructionIdConst:
            return ir_analyze_instruction_const(g, (IrInstructionConst *)instruction);
        case IrInstructionIdCondBr:
        case IrInstructionIdSwitchBr:
        case IrInstructionIdPhi:
        case IrInstructionIdBinOp:
        case IrInstructionIdLoadVar:
        case IrInstructionIdStoreVar:
        case IrInstructionIdCall:
        case IrInstructionIdBuiltinCall:
            zig_panic("TODO analyze more instructions");
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction(CodeGen *g, IrInstruction *instruction,
        TypeTableEntry *expected_type)
{
    TypeTableEntry *instruction_type = ir_analyze_instruction_nocast(g, instruction);
    instruction->type_entry = instruction_type;

    IrInstruction *casted_instruction = ir_get_casted_instruction(g, instruction, expected_type);
    return casted_instruction->type_entry;
}

TypeTableEntry *ir_analyze(CodeGen *g, IrExecutable *executable, TypeTableEntry *expected_type) {
    TypeTableEntry *return_type = g->builtin_types.entry_void;

    for (size_t i = 0; i < executable->basic_block_count; i += 1) {
        IrBasicBlock *current_block = executable->basic_block_list[i];

        for (IrInstruction *instruction = current_block->first; instruction != nullptr;
                instruction = instruction->next)
        {
            if (return_type->id == TypeTableEntryIdUnreachable) {
                add_node_error(g, first_executing_node(instruction->source_node),
                        buf_sprintf("unreachable code"));
                break;
            }
            bool is_last = (instruction == current_block->last);
            TypeTableEntry *passed_expected_type = is_last ? expected_type : nullptr;
            return_type = ir_analyze_instruction(g, instruction, passed_expected_type);
        }
    }

    return return_type;
}
