#include "analyze.hpp"
#include "ir.hpp"
#include "error.hpp"

struct IrGen {
    CodeGen *codegen;
    AstNode *node;
    IrBasicBlock *current_basic_block;
    IrExecutable *exec;
};

struct IrAnalyze {
    CodeGen *codegen;
    IrExecutable *exec;
    IrBasicBlock *current_basic_block;
};

static IrInstruction *ir_gen_node(IrGen *irg, AstNode *node, BlockContext *scope);

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

static void ir_instruction_insert(IrBasicBlock *basic_block,
        IrInstruction *before_instruction, IrInstruction *after_instruction,
        IrInstruction *new_instruction)
{
    assert(before_instruction || after_instruction);
    assert(!before_instruction || !after_instruction);

    if (before_instruction) {
        IrInstruction *displaced_instruction = before_instruction->prev;
        before_instruction->prev = new_instruction;
        new_instruction->prev = displaced_instruction;
        new_instruction->next = before_instruction;
        if (basic_block->first == before_instruction)
            basic_block->first = new_instruction;
    } else {
        IrInstruction *displaced_instruction = after_instruction->next;
        after_instruction->next = new_instruction;
        new_instruction->prev = after_instruction;
        new_instruction->next = displaced_instruction;
        if (basic_block->last == after_instruction)
            basic_block->last = new_instruction;
    }
}

static size_t exec_next_debug_id(IrExecutable *exec) {
    size_t result = exec->next_debug_id;
    exec->next_debug_id += 1;
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

static constexpr IrInstructionId ir_instruction_id(IrInstructionCast *) {
    return IrInstructionIdCast;
}

template<typename T>
static T *ir_create_instruction(IrExecutable *exec, AstNode *source_node) {
    T *special_instruction = allocate<T>(1);
    special_instruction->base.id = ir_instruction_id(special_instruction);
    special_instruction->base.source_node = source_node;
    special_instruction->base.debug_id = exec_next_debug_id(exec);
    return special_instruction;
}

template<typename T>
static T *ir_build_instruction(IrGen *irg, AstNode *source_node) {
    T *special_instruction = ir_create_instruction<T>(irg->exec, source_node);
    ir_instruction_append(irg->current_basic_block, &special_instruction->base);
    return special_instruction;
}

static IrInstruction *ir_insert_const_type(IrAnalyze *ira, IrInstruction *before_instruction,
        IrInstruction *after_instruction, TypeTableEntry *type_entry)
{
    IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(ira->exec,
            before_instruction->source_node);
    const_instruction->base.type_entry = ira->codegen->builtin_types.entry_type;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_type = type_entry;
    ir_instruction_insert(ira->current_basic_block, before_instruction, after_instruction, &const_instruction->base);
    return &const_instruction->base;
}

static IrInstruction *ir_insert_cast(IrAnalyze *ira,
        IrInstruction *before_instruction, IrInstruction *after_instruction,
        IrInstruction *dest_type, IrInstruction *value, bool is_implicit)
{
    IrInstructionCast *cast_instruction = ir_create_instruction<IrInstructionCast>(ira->exec,
            before_instruction->source_node);
    cast_instruction->dest_type = dest_type;
    cast_instruction->value = value;
    cast_instruction->is_implicit = is_implicit;
    ir_instruction_insert(ira->current_basic_block, before_instruction, after_instruction, &cast_instruction->base);
    return &cast_instruction->base;
}

static IrInstruction *ir_build_return(IrGen *irg, AstNode *source_node, IrInstruction *return_value) {
    IrInstructionReturn *return_instruction = ir_build_instruction<IrInstructionReturn>(irg, source_node);
    return_instruction->base.type_entry = irg->codegen->builtin_types.entry_unreachable;
    return_instruction->base.static_value.ok = true;
    return_instruction->value = return_value;
    return &return_instruction->base;
}

static IrInstruction *ir_build_const_void(IrGen *irg, AstNode *source_node) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irg, source_node);
    const_instruction->base.type_entry = irg->codegen->builtin_types.entry_void;
    const_instruction->base.static_value.ok = true;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_bignum(IrGen *irg, AstNode *source_node, BigNum *bignum) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irg, source_node);
    const_instruction->base.type_entry = (bignum->kind == BigNumKindInt) ?
        irg->codegen->builtin_types.entry_num_lit_int : irg->codegen->builtin_types.entry_num_lit_float;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_bignum = *bignum;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_type(IrGen *irg, AstNode *source_node, TypeTableEntry *type_entry) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irg, source_node);
    const_instruction->base.type_entry = irg->codegen->builtin_types.entry_type;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_type = type_entry;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_fn(IrGen *irg, AstNode *source_node, FnTableEntry *fn_entry) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irg, source_node);
    const_instruction->base.type_entry = fn_entry->type_entry;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_fn = fn_entry;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_generic_fn(IrGen *irg, AstNode *source_node, TypeTableEntry *fn_type) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irg, source_node);
    const_instruction->base.type_entry = fn_type;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_type = fn_type;
    return &const_instruction->base;
}

static IrInstruction *ir_build_bin_op(IrGen *irg, AstNode *source_node, IrBinOp op_id,
        IrInstruction *op1, IrInstruction *op2)
{
    IrInstructionBinOp *bin_op_instruction = ir_build_instruction<IrInstructionBinOp>(irg, source_node);
    bin_op_instruction->op_id = op_id;
    bin_op_instruction->op1 = op1;
    bin_op_instruction->op2 = op2;
    return &bin_op_instruction->base;
}

static IrInstruction *ir_build_load_var(IrGen *irg, AstNode *source_node, VariableTableEntry *var) {
    IrInstructionLoadVar *load_var_instruction = ir_build_instruction<IrInstructionLoadVar>(irg, source_node);
    load_var_instruction->base.type_entry = var->type;
    load_var_instruction->var = var;
    return &load_var_instruction->base;
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

static void ir_gen_defers_for_block(IrGen *irg, BlockContext *inner_block, BlockContext *outer_block,
        bool gen_error_defers, bool gen_maybe_defers)
{
    while (inner_block != outer_block) {
        if (inner_block->node->type == NodeTypeDefer &&
           ((inner_block->node->data.defer.kind == ReturnKindUnconditional) ||
            (gen_error_defers && inner_block->node->data.defer.kind == ReturnKindError) ||
            (gen_maybe_defers && inner_block->node->data.defer.kind == ReturnKindMaybe)))
        {
            AstNode *defer_expr_node = inner_block->node->data.defer.expr;
            ir_gen_node(irg, defer_expr_node, defer_expr_node->block_context);
        }
        inner_block = inner_block->parent;
    }
}

//static IrInstruction *ir_gen_return(IrGen *irg, AstNode *source_node, IrInstruction *value, ReturnKnowledge rk) {
//    BlockContext *defer_inner_block = source_node->block_context;
//    BlockContext *defer_outer_block = irg->node->block_context;
//    if (rk == ReturnKnowledgeUnknown) {
//        if (get_conditional_defer_count(defer_inner_block, defer_outer_block) > 0) {
//            // generate branching code that checks the return value and generates defers
//            // if the return value is error
//            zig_panic("TODO");
//        }
//    } else if (rk != ReturnKnowledgeSkipDefers) {
//        ir_gen_defers_for_block(irg, defer_inner_block, defer_outer_block,
//                rk == ReturnKnowledgeKnownError, rk == ReturnKnowledgeKnownNull);
//    }
//
//    return ir_build_return(irg, source_node, value);
//}

static IrInstruction *ir_gen_block(IrGen *irg, AstNode *block_node) {
    assert(block_node->type == NodeTypeBlock);

    BlockContext *parent_context = block_node->block_context;
    BlockContext *outer_block_context = new_block_context(block_node, parent_context);
    BlockContext *child_context = outer_block_context;

    IrInstruction *return_value = nullptr;
    for (size_t i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        return_value = ir_gen_node(irg, statement_node, child_context);
        if (statement_node->type == NodeTypeDefer && return_value != irg->codegen->invalid_instruction) {
            // defer starts a new block context
            child_context = statement_node->data.defer.child_block;
            assert(child_context);
        }
    }

    if (!return_value)
        return_value = ir_build_const_void(irg, block_node);

    ir_gen_defers_for_block(irg, child_context, outer_block_context, false, false);

    return return_value;
}

static IrInstruction *ir_gen_bin_op_id(IrGen *irg, AstNode *node, IrBinOp op_id) {
    IrInstruction *op1 = ir_gen_node(irg, node->data.bin_op_expr.op1, node->block_context);
    IrInstruction *op2 = ir_gen_node(irg, node->data.bin_op_expr.op2, node->block_context);
    return ir_build_bin_op(irg, node, op_id, op1, op2);
}

static IrInstruction *ir_gen_bin_op(IrGen *irg, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    BinOpType bin_op_type = node->data.bin_op_expr.bin_op;
    switch (bin_op_type) {
        case BinOpTypeInvalid:
            zig_unreachable();
        case BinOpTypeAssign:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignTimesWrap:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignPlusWrap:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignMinusWrap:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftLeftWrap:
        case BinOpTypeAssignBitShiftRight:
        case BinOpTypeAssignBitAnd:
        case BinOpTypeAssignBitXor:
        case BinOpTypeAssignBitOr:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            zig_panic("TODO gen IR for assignment");
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
            // note: this is not a direct mapping to IrBinOpBoolOr/And
            // because of the control flow
            zig_panic("TODO gen IR for bool or/and");
        case BinOpTypeCmpEq:
            return ir_gen_bin_op_id(irg, node, IrBinOpCmpEq);
        case BinOpTypeCmpNotEq:
            return ir_gen_bin_op_id(irg, node, IrBinOpCmpNotEq);
        case BinOpTypeCmpLessThan:
            return ir_gen_bin_op_id(irg, node, IrBinOpCmpLessThan);
        case BinOpTypeCmpGreaterThan:
            return ir_gen_bin_op_id(irg, node, IrBinOpCmpGreaterThan);
        case BinOpTypeCmpLessOrEq:
            return ir_gen_bin_op_id(irg, node, IrBinOpCmpLessOrEq);
        case BinOpTypeCmpGreaterOrEq:
            return ir_gen_bin_op_id(irg, node, IrBinOpCmpGreaterOrEq);
        case BinOpTypeBinOr:
            return ir_gen_bin_op_id(irg, node, IrBinOpBinOr);
        case BinOpTypeBinXor:
            return ir_gen_bin_op_id(irg, node, IrBinOpBinXor);
        case BinOpTypeBinAnd:
            return ir_gen_bin_op_id(irg, node, IrBinOpBinAnd);
        case BinOpTypeBitShiftLeft:
            return ir_gen_bin_op_id(irg, node, IrBinOpBitShiftLeft);
        case BinOpTypeBitShiftLeftWrap:
            return ir_gen_bin_op_id(irg, node, IrBinOpBitShiftLeftWrap);
        case BinOpTypeBitShiftRight:
            return ir_gen_bin_op_id(irg, node, IrBinOpBitShiftRight);
        case BinOpTypeAdd:
            return ir_gen_bin_op_id(irg, node, IrBinOpAdd);
        case BinOpTypeAddWrap:
            return ir_gen_bin_op_id(irg, node, IrBinOpAddWrap);
        case BinOpTypeSub:
            return ir_gen_bin_op_id(irg, node, IrBinOpSub);
        case BinOpTypeSubWrap:
            return ir_gen_bin_op_id(irg, node, IrBinOpSubWrap);
        case BinOpTypeMult:
            return ir_gen_bin_op_id(irg, node, IrBinOpMult);
        case BinOpTypeMultWrap:
            return ir_gen_bin_op_id(irg, node, IrBinOpMultWrap);
        case BinOpTypeDiv:
            return ir_gen_bin_op_id(irg, node, IrBinOpDiv);
        case BinOpTypeMod:
            return ir_gen_bin_op_id(irg, node, IrBinOpMod);
        case BinOpTypeArrayCat:
            return ir_gen_bin_op_id(irg, node, IrBinOpArrayCat);
        case BinOpTypeArrayMult:
            return ir_gen_bin_op_id(irg, node, IrBinOpArrayMult);
        case BinOpTypeUnwrapMaybe:
            zig_panic("TODO gen IR for unwrap maybe");
    }
    zig_unreachable();
}

static IrInstruction *ir_gen_num_lit(IrGen *irg, AstNode *node) {
    assert(node->type == NodeTypeNumberLiteral);

    if (node->data.number_literal.overflow) {
        add_node_error(irg->codegen, node, buf_sprintf("number literal too large to be represented in any type"));
        return irg->codegen->invalid_instruction;
    }

    return ir_build_const_bignum(irg, node, node->data.number_literal.bignum);
}

static IrInstruction *ir_gen_decl_ref(IrGen *irg, AstNode *source_node, AstNode *decl_node,
        bool pointer_only, BlockContext *scope)
{
    resolve_top_level_decl(irg->codegen, decl_node, pointer_only);
    TopLevelDecl *tld = get_as_top_level_decl(decl_node);
    if (tld->resolution == TldResolutionInvalid)
        return irg->codegen->invalid_instruction;

    if (decl_node->type == NodeTypeVariableDeclaration) {
        VariableTableEntry *var = decl_node->data.variable_declaration.variable;
        return ir_build_load_var(irg, source_node, var);
    } else if (decl_node->type == NodeTypeFnProto) {
        FnTableEntry *fn_entry = decl_node->data.fn_proto.fn_table_entry;
        assert(fn_entry->type_entry);
        if (fn_entry->type_entry->id == TypeTableEntryIdGenericFn) {
            return ir_build_const_generic_fn(irg, source_node, fn_entry->type_entry);
        } else {
            return ir_build_const_fn(irg, source_node, fn_entry);
        }
    } else if (decl_node->type == NodeTypeContainerDecl) {
        if (decl_node->data.struct_decl.generic_params.length > 0) {
            TypeTableEntry *type_entry = decl_node->data.struct_decl.generic_fn_type;
            assert(type_entry);
            return ir_build_const_generic_fn(irg, source_node, type_entry);
        } else {
            return ir_build_const_type(irg, source_node, decl_node->data.struct_decl.type_entry);
        }
    } else if (decl_node->type == NodeTypeTypeDecl) {
        return ir_build_const_type(irg, source_node, decl_node->data.type_decl.child_type_entry);
    } else {
        zig_unreachable();
    }
}

static IrInstruction *ir_gen_symbol(IrGen *irg, AstNode *node, bool pointer_only) {
    assert(node->type == NodeTypeSymbol);

    if (node->data.symbol_expr.override_type_entry)
        return ir_build_const_type(irg, node, node->data.symbol_expr.override_type_entry);

    Buf *variable_name = node->data.symbol_expr.symbol;

    auto primitive_table_entry = irg->codegen->primitive_type_table.maybe_get(variable_name);
    if (primitive_table_entry)
        return ir_build_const_type(irg, node, primitive_table_entry->value);

    VariableTableEntry *var = find_variable(irg->codegen, node->block_context, variable_name);
    if (var)
        return ir_build_load_var(irg, node, var);

    AstNode *decl_node = find_decl(node->block_context, variable_name);
    if (decl_node)
        return ir_gen_decl_ref(irg, node, decl_node, pointer_only, node->block_context);

    if (node->owner->any_imports_failed) {
        // skip the error message since we had a failing import in this file
        // if an import breaks we don't need redundant undeclared identifier errors
        return irg->codegen->invalid_instruction;
    }

    add_node_error(irg->codegen, node, buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
    return irg->codegen->invalid_instruction;
}

static IrInstruction *ir_gen_node_extra(IrGen *irg, AstNode *node, BlockContext *block_context,
        bool pointer_only)
{
    node->block_context = block_context;

    switch (node->type) {
        case NodeTypeBlock:
            return ir_gen_block(irg, node);
        case NodeTypeBinOpExpr:
            return ir_gen_bin_op(irg, node);
        case NodeTypeNumberLiteral:
            return ir_gen_num_lit(irg, node);
        case NodeTypeSymbol:
            return ir_gen_symbol(irg, node, pointer_only);
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
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeLabel:
        case NodeTypeContainerInitExpr:
        case NodeTypeSwitchExpr:
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

static IrInstruction *ir_gen_node(IrGen *irg, AstNode *node, BlockContext *scope) {
    bool pointer_only_no = false;
    return ir_gen_node_extra(irg, node, scope, pointer_only_no);
}

static IrInstruction *ir_gen_add_return(CodeGen *g, AstNode *node, BlockContext *scope,
        IrExecutable *ir_executable, bool add_return, bool pointer_only)
{
    assert(node->owner);

    IrGen ir_gen = {0};
    IrGen *irg = &ir_gen;

    irg->codegen = g;
    irg->node = node;
    irg->exec = ir_executable;

    irg->exec->basic_block_list = allocate<IrBasicBlock*>(1);
    irg->exec->basic_block_count = 1;

    IrBasicBlock *entry_basic_block = allocate<IrBasicBlock>(1);
    irg->current_basic_block = entry_basic_block;
    irg->exec->basic_block_list[0] = entry_basic_block;

    IrInstruction *result = ir_gen_node_extra(irg, node, scope, pointer_only);
    assert(result);

    if (result == g->invalid_instruction)
        return result;

    if (add_return)
        return ir_build_return(irg, result->source_node, result);

    return result;
}

IrInstruction *ir_gen(CodeGen *codegen, AstNode *node, BlockContext *scope, IrExecutable *ir_executable) {
    bool add_return_no = false;
    bool pointer_only_no = false;
    return ir_gen_add_return(codegen, node, scope, ir_executable, add_return_no, pointer_only_no);
}

IrInstruction *ir_gen_fn(CodeGen *codegn, FnTableEntry *fn_entry) {
    assert(fn_entry);

    IrExecutable *ir_executable = &fn_entry->ir_executable;
    AstNode *fn_def_node = fn_entry->fn_def_node;
    assert(fn_def_node->type == NodeTypeFnDef);

    AstNode *body_node = fn_def_node->data.fn_def.body;
    BlockContext *scope = fn_def_node->data.fn_def.block_context;

    bool add_return_yes = true;
    bool pointer_only_no = false;
    return ir_gen_add_return(codegn, body_node, scope, ir_executable, add_return_yes, pointer_only_no);
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

static bool ir_num_lit_fits_in_other_type(IrAnalyze *ira, IrInstruction *instruction, TypeTableEntry *other_type) {
    TypeTableEntry *other_type_underlying = get_underlying_type(other_type);

    if (other_type_underlying->id == TypeTableEntryIdInvalid) {
        return false;
    }

    ConstExprValue *const_val = &instruction->static_value;
    assert(const_val->ok);
    if (other_type_underlying->id == TypeTableEntryIdFloat) {
        return true;
    } else if (other_type_underlying->id == TypeTableEntryIdInt &&
               const_val->data.x_bignum.kind == BigNumKindInt)
    {
        if (bignum_fits_in_bits(&const_val->data.x_bignum, other_type_underlying->data.integral.bit_count,
                    other_type_underlying->data.integral.is_signed))
        {
            return true;
        }
    } else if ((other_type_underlying->id == TypeTableEntryIdNumLitFloat &&
                const_val->data.x_bignum.kind == BigNumKindFloat) ||
               (other_type_underlying->id == TypeTableEntryIdNumLitInt &&
                const_val->data.x_bignum.kind == BigNumKindInt))
    {
        return true;
    }

    const char *num_lit_str = (const_val->data.x_bignum.kind == BigNumKindFloat) ? "float" : "integer";

    add_node_error(ira->codegen, instruction->source_node,
        buf_sprintf("%s value %s cannot be implicitly casted to type '%s'",
            num_lit_str,
            buf_ptr(bignum_to_buf(&const_val->data.x_bignum)),
            buf_ptr(&other_type->name)));
    return false;
}

static TypeTableEntry *ir_determine_peer_types(IrAnalyze *ira, IrInstruction *parent_instruction,
        IrInstruction **instructions, size_t instruction_count)
{
    assert(instruction_count >= 1);
    IrInstruction *prev_inst = instructions[0];
    if (prev_inst->type_entry->id == TypeTableEntryIdInvalid) {
        return ira->codegen->builtin_types.entry_invalid;
    }
    for (size_t i = 1; i < instruction_count; i += 1) {
        IrInstruction *cur_inst = instructions[i];
        TypeTableEntry *cur_type = cur_inst->type_entry;
        TypeTableEntry *prev_type = prev_inst->type_entry;
        if (cur_type->id == TypeTableEntryIdInvalid) {
            return cur_type;
        } else if (types_match_const_cast_only(prev_type, cur_type)) {
            continue;
        } else if (types_match_const_cast_only(cur_type, prev_type)) {
            prev_inst = cur_inst;
            continue;
        } else if (prev_type->id == TypeTableEntryIdUnreachable) {
            prev_inst = cur_inst;
        } else if (cur_type->id == TypeTableEntryIdUnreachable) {
            continue;
        } else if (prev_type->id == TypeTableEntryIdInt &&
                   cur_type->id == TypeTableEntryIdInt &&
                   prev_type->data.integral.is_signed == cur_type->data.integral.is_signed)
        {
            if (cur_type->data.integral.bit_count > prev_type->data.integral.bit_count) {
                prev_inst = cur_inst;
            }
            continue;
        } else if (prev_type->id == TypeTableEntryIdFloat &&
                   cur_type->id == TypeTableEntryIdFloat)
        {
            if (cur_type->data.floating.bit_count > prev_type->data.floating.bit_count) {
                prev_inst = cur_inst;
            }
        } else if (prev_type->id == TypeTableEntryIdErrorUnion &&
                   types_match_const_cast_only(prev_type->data.error.child_type, cur_type))
        {
            continue;
        } else if (cur_type->id == TypeTableEntryIdErrorUnion &&
                   types_match_const_cast_only(cur_type->data.error.child_type, prev_type))
        {
            prev_inst = cur_inst;
            continue;
        } else if (prev_type->id == TypeTableEntryIdNumLitInt ||
                    prev_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (ir_num_lit_fits_in_other_type(ira, prev_inst, cur_type)) {
                prev_inst = cur_inst;
                continue;
            } else {
                return ira->codegen->builtin_types.entry_invalid;
            }
        } else if (cur_type->id == TypeTableEntryIdNumLitInt ||
                   cur_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (ir_num_lit_fits_in_other_type(ira, cur_inst, prev_type)) {
                continue;
            } else {
                return ira->codegen->builtin_types.entry_invalid;
            }
        } else {
            add_node_error(ira->codegen, parent_instruction->source_node,
                buf_sprintf("incompatible types: '%s' and '%s'",
                    buf_ptr(&prev_type->name), buf_ptr(&cur_type->name)));

            return ira->codegen->builtin_types.entry_invalid;
        }
    }
    return prev_inst->type_entry;
}

enum ImplicitCastMatchResult {
    ImplicitCastMatchResultNo,
    ImplicitCastMatchResultYes,
    ImplicitCastMatchResultReportedError,
};

static ImplicitCastMatchResult ir_types_match_with_implicit_cast(IrAnalyze *ira, TypeTableEntry *expected_type,
        TypeTableEntry *actual_type, IrInstruction *value)
{
    if (types_match_const_cast_only(expected_type, actual_type)) {
        return ImplicitCastMatchResultYes;
    }

    // implicit conversion from non maybe type to maybe type
    if (expected_type->id == TypeTableEntryIdMaybe &&
        ir_types_match_with_implicit_cast(ira, expected_type->data.maybe.child_type, actual_type, value))
    {
        return ImplicitCastMatchResultYes;
    }

    // implicit conversion from null literal to maybe type
    if (expected_type->id == TypeTableEntryIdMaybe &&
        actual_type->id == TypeTableEntryIdNullLit)
    {
        return ImplicitCastMatchResultYes;
    }

    // implicit conversion from error child type to error type
    if (expected_type->id == TypeTableEntryIdErrorUnion &&
        ir_types_match_with_implicit_cast(ira, expected_type->data.error.child_type, actual_type, value))
    {
        return ImplicitCastMatchResultYes;
    }

    // implicit conversion from pure error to error union type
    if (expected_type->id == TypeTableEntryIdErrorUnion &&
        actual_type->id == TypeTableEntryIdPureError)
    {
        return ImplicitCastMatchResultYes;
    }

    // implicit widening conversion
    if (expected_type->id == TypeTableEntryIdInt &&
        actual_type->id == TypeTableEntryIdInt &&
        expected_type->data.integral.is_signed == actual_type->data.integral.is_signed &&
        expected_type->data.integral.bit_count >= actual_type->data.integral.bit_count)
    {
        return ImplicitCastMatchResultYes;
    }

    // small enough unsigned ints can get casted to large enough signed ints
    if (expected_type->id == TypeTableEntryIdInt && expected_type->data.integral.is_signed &&
        actual_type->id == TypeTableEntryIdInt && !actual_type->data.integral.is_signed &&
        expected_type->data.integral.bit_count > actual_type->data.integral.bit_count)
    {
        return ImplicitCastMatchResultYes;
    }

    // implicit float widening conversion
    if (expected_type->id == TypeTableEntryIdFloat &&
        actual_type->id == TypeTableEntryIdFloat &&
        expected_type->data.floating.bit_count >= actual_type->data.floating.bit_count)
    {
        return ImplicitCastMatchResultYes;
    }

    // implicit array to slice conversion
    if (expected_type->id == TypeTableEntryIdStruct &&
        expected_type->data.structure.is_slice &&
        actual_type->id == TypeTableEntryIdArray &&
        types_match_const_cast_only(
            expected_type->data.structure.fields[0].type_entry->data.pointer.child_type,
            actual_type->data.array.child_type))
    {
        return ImplicitCastMatchResultYes;
    }

    // implicit number literal to typed number
    if ((actual_type->id == TypeTableEntryIdNumLitFloat ||
         actual_type->id == TypeTableEntryIdNumLitInt))
    {
        if (ir_num_lit_fits_in_other_type(ira, value, expected_type)) {
            return ImplicitCastMatchResultYes;
        } else {
            return ImplicitCastMatchResultReportedError;
        }
    }

    return ImplicitCastMatchResultNo;
}

static TypeTableEntry *ir_resolve_peer_types(IrAnalyze *ira, IrInstruction *parent_instruction,
        IrInstruction **instructions, size_t instruction_count)
{
    return ir_determine_peer_types(ira, parent_instruction, instructions, instruction_count);
}

static IrInstruction *ir_get_casted_value(IrAnalyze *ira, IrInstruction *value,
        TypeTableEntry *expected_type,
        IrInstruction *before_instruction, IrInstruction *after_instruction)
{
    assert(value);
    assert(before_instruction || after_instruction);
    assert(!before_instruction || !after_instruction);
    assert(value != ira->codegen->invalid_instruction);
    assert(!expected_type || expected_type->id != TypeTableEntryIdInvalid);
    assert(value->type_entry);
    assert(value->type_entry->id != TypeTableEntryIdInvalid);
    if (expected_type == nullptr)
        return value; // anything will do
    if (expected_type == value->type_entry)
        return value; // match
    if (value->type_entry->id == TypeTableEntryIdUnreachable)
        return value;

    ImplicitCastMatchResult result = ir_types_match_with_implicit_cast(ira, expected_type, value->type_entry, value);
    switch (result) {
        case ImplicitCastMatchResultNo:
            add_node_error(ira->codegen, first_executing_node(value->source_node),
                buf_sprintf("expected type '%s', got '%s'",
                    buf_ptr(&expected_type->name),
                    buf_ptr(&value->type_entry->name)));
            return ira->codegen->invalid_instruction;

        case ImplicitCastMatchResultYes:
            {
                IrInstruction *dest_type = ir_insert_const_type(ira, before_instruction,
                        after_instruction, expected_type);
                bool is_implicit = true;
                IrInstruction *cast_instruction = ir_insert_cast(ira, nullptr, dest_type,
                        dest_type, value, is_implicit);
                return cast_instruction;
            }
        case ImplicitCastMatchResultReportedError:
            return ira->codegen->invalid_instruction;
    }

    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_return(IrAnalyze *ira, IrInstructionReturn *return_instruction) {
    AstNode *source_node = return_instruction->base.source_node;
    BlockContext *scope = source_node->block_context;
    if (!scope->fn_entry) {
        add_node_error(ira->codegen, source_node, buf_sprintf("return expression outside function definition"));
        return ira->codegen->builtin_types.entry_invalid;
    }

    TypeTableEntry *expected_return_type = scope->fn_entry->type_entry->data.fn.fn_type_id.return_type;
    if (expected_return_type->id == TypeTableEntryIdVoid && !return_instruction->value) {
        return ira->codegen->builtin_types.entry_unreachable;
    }

    return_instruction->value = ir_get_casted_value(ira,
            return_instruction->value, expected_return_type, &return_instruction->base, nullptr);
    if (return_instruction->value == ira->codegen->invalid_instruction) {
        return ira->codegen->builtin_types.entry_invalid;
    }
    return ira->codegen->builtin_types.entry_unreachable;
}

static TypeTableEntry *ir_analyze_instruction_const(IrAnalyze *ira, IrInstructionConst *const_instruction) {
    return const_instruction->base.type_entry;
}

static TypeTableEntry *ir_analyze_bin_op_bool(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrInstruction *op1 = bin_op_instruction->op1;
    IrInstruction *op2 = bin_op_instruction->op2;

    IrInstruction *casted_op1 = ir_get_casted_value(ira, op1, ira->codegen->builtin_types.entry_bool,
            &bin_op_instruction->base, nullptr);
    if (casted_op1 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op2 = ir_get_casted_value(ira, op2, ira->codegen->builtin_types.entry_bool,
            &bin_op_instruction->base, nullptr);
    if (casted_op2 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    return ira->codegen->builtin_types.entry_bool;
}

static TypeTableEntry *ir_analyze_bin_op_cmp(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrInstruction *op1 = bin_op_instruction->op1;
    IrInstruction *op2 = bin_op_instruction->op2;
    IrInstruction *instructions[] = {op1, op2};
    TypeTableEntry *resolved_type = ir_resolve_peer_types(ira, &bin_op_instruction->base, instructions, 2);
    if (resolved_type->id == TypeTableEntryIdInvalid)
        return resolved_type;
    IrBinOp op_id = bin_op_instruction->op_id;

    bool is_equality_cmp = (op_id == IrBinOpCmpEq || op_id == IrBinOpCmpNotEq);
    AstNode *source_node = bin_op_instruction->base.source_node;
    switch (resolved_type->id) {
        case TypeTableEntryIdInvalid:
            return ira->codegen->builtin_types.entry_invalid;

        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
            break;

        case TypeTableEntryIdBool:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
            if (!is_equality_cmp) {
                add_node_error(ira->codegen, source_node,
                    buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
                return ira->codegen->builtin_types.entry_invalid;
            }
            break;

        case TypeTableEntryIdEnum:
            if (!is_equality_cmp || resolved_type->data.enumeration.gen_field_count != 0) {
                add_node_error(ira->codegen, source_node,
                    buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
                return ira->codegen->builtin_types.entry_invalid;
            }
            break;

        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdUnion:
            add_node_error(ira->codegen, source_node,
                buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
            return ira->codegen->builtin_types.entry_invalid;

        case TypeTableEntryIdVar:
            zig_unreachable();
    }

    return ira->codegen->builtin_types.entry_bool;
}

static TypeTableEntry *ir_analyze_bin_op_math(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrInstruction *op1 = bin_op_instruction->op1;
    IrInstruction *op2 = bin_op_instruction->op2;
    IrInstruction *instructions[] = {op1, op2};
    TypeTableEntry *resolved_type = ir_resolve_peer_types(ira, &bin_op_instruction->base, instructions, 2);
    if (resolved_type->id == TypeTableEntryIdInvalid)
        return resolved_type;
    IrBinOp op_id = bin_op_instruction->op_id;

    if (resolved_type->id == TypeTableEntryIdInt ||
        resolved_type->id == TypeTableEntryIdNumLitInt)
    {
        // int
    } else if ((resolved_type->id == TypeTableEntryIdFloat ||
                resolved_type->id == TypeTableEntryIdNumLitFloat) &&
        (op_id == IrBinOpAdd ||
            op_id == IrBinOpSub ||
            op_id == IrBinOpMult ||
            op_id == IrBinOpDiv ||
            op_id == IrBinOpMod))
    {
        // float
    } else {
        AstNode *source_node = bin_op_instruction->base.source_node;
        add_node_error(ira->codegen, source_node, buf_sprintf("invalid operands to binary expression: '%s' and '%s'",
                buf_ptr(&op1->type_entry->name),
                buf_ptr(&op2->type_entry->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    return resolved_type;
}


static TypeTableEntry *ir_analyze_instruction_bin_op(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrBinOp op_id = bin_op_instruction->op_id;
    switch (op_id) {
        case IrBinOpInvalid:
            zig_unreachable();
        case IrBinOpBoolOr:
        case IrBinOpBoolAnd:
            return ir_analyze_bin_op_bool(ira, bin_op_instruction);
        case IrBinOpCmpEq:
        case IrBinOpCmpNotEq:
        case IrBinOpCmpLessThan:
        case IrBinOpCmpGreaterThan:
        case IrBinOpCmpLessOrEq:
        case IrBinOpCmpGreaterOrEq:
            return ir_analyze_bin_op_cmp(ira, bin_op_instruction);
        case IrBinOpBinOr:
        case IrBinOpBinXor:
        case IrBinOpBinAnd:
        case IrBinOpBitShiftLeft:
        case IrBinOpBitShiftLeftWrap:
        case IrBinOpBitShiftRight:
        case IrBinOpAdd:
        case IrBinOpAddWrap:
        case IrBinOpSub:
        case IrBinOpSubWrap:
        case IrBinOpMult:
        case IrBinOpMultWrap:
        case IrBinOpDiv:
        case IrBinOpMod:
            return ir_analyze_bin_op_math(ira, bin_op_instruction);
        case IrBinOpArrayCat:
        case IrBinOpArrayMult:
            zig_panic("TODO analyze more binary operations");
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_load_var(IrAnalyze *ira, IrInstructionLoadVar *load_var_instruction) {
    return load_var_instruction->var->type;
}

static TypeTableEntry *ir_analyze_instruction_nocast(IrAnalyze *ira, IrInstruction *instruction) {
    switch (instruction->id) {
        case IrInstructionIdInvalid:
            zig_unreachable();
        case IrInstructionIdReturn:
            return ir_analyze_instruction_return(ira, (IrInstructionReturn *)instruction);
        case IrInstructionIdConst:
            return ir_analyze_instruction_const(ira, (IrInstructionConst *)instruction);
        case IrInstructionIdBinOp:
            return ir_analyze_instruction_bin_op(ira, (IrInstructionBinOp *)instruction);
        case IrInstructionIdLoadVar:
            return ir_analyze_instruction_load_var(ira, (IrInstructionLoadVar *)instruction);
        case IrInstructionIdCondBr:
        case IrInstructionIdSwitchBr:
        case IrInstructionIdPhi:
        case IrInstructionIdStoreVar:
        case IrInstructionIdCall:
        case IrInstructionIdBuiltinCall:
        case IrInstructionIdCast:
            zig_panic("TODO analyze more instructions");
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction(IrAnalyze *ira, IrInstruction *instruction,
        TypeTableEntry *expected_type)
{
    TypeTableEntry *instruction_type = ir_analyze_instruction_nocast(ira, instruction);
    instruction->type_entry = instruction_type;

    IrInstruction *casted_instruction = ir_get_casted_value(ira, instruction, expected_type,
            nullptr, instruction);
    return casted_instruction->type_entry;
}

TypeTableEntry *ir_analyze(CodeGen *codegen, IrExecutable *executable, TypeTableEntry *expected_type) {
    IrAnalyze ir_analyze_data = {};
    IrAnalyze *ira = &ir_analyze_data;
    ira->codegen = codegen;
    ira->exec = executable;

    TypeTableEntry *return_type = ira->codegen->builtin_types.entry_void;

    for (size_t i = 0; i < executable->basic_block_count; i += 1) {
        ira->current_basic_block = executable->basic_block_list[i];

        for (IrInstruction *instruction = ira->current_basic_block->first; instruction != nullptr;
                instruction = instruction->next)
        {
            if (return_type->id == TypeTableEntryIdUnreachable) {
                add_node_error(ira->codegen, first_executing_node(instruction->source_node),
                        buf_sprintf("unreachable code"));
                break;
            }
            bool is_last = (instruction == ira->current_basic_block->last);
            TypeTableEntry *passed_expected_type = is_last ? expected_type : nullptr;
            return_type = ir_analyze_instruction(ira, instruction, passed_expected_type);
        }
    }

    return return_type;
}
