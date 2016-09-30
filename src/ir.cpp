#include "analyze.hpp"
#include "ir.hpp"

static IrInstruction *ir_gen_node(IrGen *ir, AstNode *node, BlockContext *block_context);

static const IrInstruction invalid_instruction_data;
static const IrInstruction *invalid_instruction = &invalid_instruction_data;

static const IrInstruction void_instruction_data;
static const IrInstruction *void_instruction = &void_instruction_data;

struct IrGen {
    CodeGen *codegen;
    AstNode *fn_def_node;
    IrBasicBlock *current_basic_block;
};

static IrInstruction *ir_build_return(Ir *ir, AstNode *source_node, IrInstruction *return_value) {
    IrInstruction *instructon = allocate<IrInstructionReturn>(1);
    instruction->base.id = IrInstructionIdReturn;
    instruction->base.source_node = source_node;
    instruction->base.type_entry = ir->codegen->builtin_types.entry_unreachable;
    ir->current_basic_block->instructions->append(instruction);
    return instructon;
}

static size_t get_conditional_defer_count(BlockContext *inner_block, BlockContext *outer_block) {
    size_t result = 0;
    while (inner_block != outer_block) {
        if (inner_block->node->type == NodeTypeDefer &&
           (inner_block->node->data.defer.kind == ReturnKindError ||
            inner_block->node->data.defer.kind == ReturnKindMaybe))
        {
            result += 1;
        }
        inner_block = inner_block->parent;
    }
    return result;
}

static void ir_gen_defers_for_block(Ir *ir, BlockContext *inner_block, BlockContext *outer_block,
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

static IrInstruction *ir_gen_return(Ir *ir, AstNode *source_node, IrInstruction *value, ReturnKnowledge rk) {
    BlockContext *defer_inner_block = source_node->block_context;
    BlockContext *defer_outer_block = ir->fn_def_node->block_context;
    if (rk == ReturnKnowledgeUnknown) {
        if (get_conditional_defer_count(defer_inner_block, defer_outer_block) > 0) {
            // generate branching code that checks the return value and generates defers
            // if the return value is error
            zig_panic("TODO");
        }
    } else if (rk != ReturnKnowledgeSkipDefers) {
        ir_gen_defers_for_block(g, defer_inner_block, defer_outer_block,
                rk == ReturnKnowledgeKnownError, rk == ReturnKnowledgeKnownNull);
    }

    ir_build_return(ir, source_node, value);
    return void_instruction;
}

static IrInstruction *ir_gen_block(IrGen *ir, AstNode *block_node, TypeTableEntry *implicit_return_type) {
    assert(block_node->type == NodeTypeBlock);

    BlockContext *parent_context = block_node->context;
    BlockContext *outer_block_context = new_block_context(block_node, parent_context);
    BlockContext *child_context = outer_block_context;

    IrInstruction *return_value = nullptr;
    for (size_t i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        return_value = ir_gen_node(g, statement_node, child_context);
        if (statement_node->type == NodeTypeDefer && return_value != invalid_instruction) {
            // defer starts a new block context
            child_context = statement_node->data.defer.child_block;
            assert(child_context);
        }
    }

    ir_gen_defers_for_block(ir, child_context, outer_block_context, false, false);

    return return_value;
}

static IrInstruction *ir_gen_node(IrGen *ir, AstNode *node, BlockContext *block_context) {
    node->block_context = block_context;

    switch (node->type) {
        case NodeTypeBlock:
            return ir_gen_block(ir, node, nullptr);
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

IrBasicBlock *ir_gen(CodeGen *g, AstNode *fn_def_node, TypeTableEntry *return_type) {
    assert(fn_def_node->type == NodeTypeFnDef);
    assert(fn_def_node->data.fn_def.block_context);
    assert(fn_def_node->owner);
    assert(return_type);
    assert(return_type->id != TypeTableEntryIdInvalid);

    IrGen ir_gen = {0};
    IrGen *ir = &ir_gen;

    IrBasicBlock *entry_basic_block = allocate<IrBasicBlock>(1);
    ir->current_basic_block = entry_basic_block;

    AstNode *body_node = fn_def_node->data.fn_def.body;
    body_node->block_context = fn_def_node->data.fn_def.block_context;
    IrInstruction *instruction = ir_gen_block(ir, body_node, return_type);
    return (instructon == invalid_instruction) ? nullptr : entry_basic_block;
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


TypeTableEntry *ir_analyze(CodeGen *g, AstNode *fn_def_node, IrBasicBlock *entry_basic_block,
        TypeTableEntry *expected_type)
{
    TypeTableEntry *return_type = g->builtin_types.entry_void;

    for (size_t i = 0; i < entry_basic_block->instructions.length; i += 1) {
        IrInstruction *instruction = entry_basic_block->instructions.at(i);

        if (return_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, first_executing_node(instruction->source_node),
                    buf_sprintf("unreachable code"));
            break;
        }
        bool is_last = (i == entry_basic_block->instructions.length - 1);
        TypeTableEntry *passed_expected_type = is_last ? expected_type : nullptr;
        return_type = ir_analyze_instruction(g, instruction, passed_expected_type, child);
    }
}
