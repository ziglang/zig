#include "analyze.hpp"
#include "ir.hpp"
#include "error.hpp"

struct IrVarSlot {
    ConstExprValue value;
    bool runtime;
};

struct IrExecContext {
    IrVarSlot *var_slot_list;
    size_t var_slot_count;
};

struct IrBuilder {
    CodeGen *codegen;
    IrExecutable *exec;
    IrBasicBlock *current_basic_block;
};

struct IrAnalyze {
    CodeGen *codegen;
    IrBuilder old_irb;
    IrBuilder new_irb;
    IrExecContext exec_context;
};

static IrInstruction *ir_gen_node(IrBuilder *irb, AstNode *node, BlockContext *scope);

static void ir_instruction_append(IrBasicBlock *basic_block, IrInstruction *instruction) {
    assert(basic_block);
    assert(instruction);
    basic_block->instruction_list.append(instruction);
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
static T *ir_build_instruction(IrBuilder *irb, AstNode *source_node) {
    T *special_instruction = ir_create_instruction<T>(irb->exec, source_node);
    ir_instruction_append(irb->current_basic_block, &special_instruction->base);
    return special_instruction;
}

static IrInstruction *ir_build_cast(IrBuilder *irb, AstNode *source_node, IrInstruction *dest_type,
        IrInstruction *value, bool is_implicit)
{
    IrInstructionCast *cast_instruction = ir_build_instruction<IrInstructionCast>(irb, source_node);
    cast_instruction->dest_type = dest_type;
    cast_instruction->value = value;
    cast_instruction->is_implicit = is_implicit;
    return &cast_instruction->base;
}

static IrInstruction *ir_build_return(IrBuilder *irb, AstNode *source_node, IrInstruction *return_value) {
    IrInstructionReturn *return_instruction = ir_build_instruction<IrInstructionReturn>(irb, source_node);
    return_instruction->base.type_entry = irb->codegen->builtin_types.entry_unreachable;
    return_instruction->base.static_value.ok = true;
    return_instruction->value = return_value;
    return &return_instruction->base;
}

static IrInstruction *ir_build_const_void(IrBuilder *irb, AstNode *source_node) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, source_node);
    const_instruction->base.type_entry = irb->codegen->builtin_types.entry_void;
    const_instruction->base.static_value.ok = true;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_bignum(IrBuilder *irb, AstNode *source_node, BigNum *bignum) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, source_node);
    const_instruction->base.type_entry = (bignum->kind == BigNumKindInt) ?
        irb->codegen->builtin_types.entry_num_lit_int : irb->codegen->builtin_types.entry_num_lit_float;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_bignum = *bignum;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_type(IrBuilder *irb, AstNode *source_node, TypeTableEntry *type_entry) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, source_node);
    const_instruction->base.type_entry = irb->codegen->builtin_types.entry_type;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_type = type_entry;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_fn(IrBuilder *irb, AstNode *source_node, FnTableEntry *fn_entry) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, source_node);
    const_instruction->base.type_entry = fn_entry->type_entry;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_fn = fn_entry;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_generic_fn(IrBuilder *irb, AstNode *source_node, TypeTableEntry *fn_type) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, source_node);
    const_instruction->base.type_entry = fn_type;
    const_instruction->base.static_value.ok = true;
    const_instruction->base.static_value.data.x_type = fn_type;
    return &const_instruction->base;
}

static IrInstruction *ir_build_bin_op(IrBuilder *irb, AstNode *source_node, IrBinOp op_id,
        IrInstruction *op1, IrInstruction *op2)
{
    IrInstructionBinOp *bin_op_instruction = ir_build_instruction<IrInstructionBinOp>(irb, source_node);
    bin_op_instruction->op_id = op_id;
    bin_op_instruction->op1 = op1;
    bin_op_instruction->op2 = op2;
    return &bin_op_instruction->base;
}

static IrInstruction *ir_build_load_var(IrBuilder *irb, AstNode *source_node, VariableTableEntry *var) {
    IrInstructionLoadVar *load_var_instruction = ir_build_instruction<IrInstructionLoadVar>(irb, source_node);
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

static void ir_gen_defers_for_block(IrBuilder *irb, BlockContext *inner_block, BlockContext *outer_block,
        bool gen_error_defers, bool gen_maybe_defers)
{
    while (inner_block != outer_block) {
        if (inner_block->node->type == NodeTypeDefer &&
           ((inner_block->node->data.defer.kind == ReturnKindUnconditional) ||
            (gen_error_defers && inner_block->node->data.defer.kind == ReturnKindError) ||
            (gen_maybe_defers && inner_block->node->data.defer.kind == ReturnKindMaybe)))
        {
            AstNode *defer_expr_node = inner_block->node->data.defer.expr;
            ir_gen_node(irb, defer_expr_node, defer_expr_node->block_context);
        }
        inner_block = inner_block->parent;
    }
}

//static IrInstruction *ir_gen_return(IrBuilder *irb, AstNode *source_node, IrInstruction *value, ReturnKnowledge rk) {
//    BlockContext *defer_inner_block = source_node->block_context;
//    BlockContext *defer_outer_block = irb->node->block_context;
//    if (rk == ReturnKnowledgeUnknown) {
//        if (get_conditional_defer_count(defer_inner_block, defer_outer_block) > 0) {
//            // generate branching code that checks the return value and generates defers
//            // if the return value is error
//            zig_panic("TODO");
//        }
//    } else if (rk != ReturnKnowledgeSkipDefers) {
//        ir_gen_defers_for_block(irb, defer_inner_block, defer_outer_block,
//                rk == ReturnKnowledgeKnownError, rk == ReturnKnowledgeKnownNull);
//    }
//
//    return ir_build_return(irb, source_node, value);
//}

static IrInstruction *ir_gen_block(IrBuilder *irb, AstNode *block_node) {
    assert(block_node->type == NodeTypeBlock);

    BlockContext *parent_context = block_node->block_context;
    BlockContext *outer_block_context = new_block_context(block_node, parent_context);
    BlockContext *child_context = outer_block_context;

    IrInstruction *return_value = nullptr;
    for (size_t i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        return_value = ir_gen_node(irb, statement_node, child_context);
        if (statement_node->type == NodeTypeDefer && return_value != irb->codegen->invalid_instruction) {
            // defer starts a new block context
            child_context = statement_node->data.defer.child_block;
            assert(child_context);
        }
    }

    if (!return_value)
        return_value = ir_build_const_void(irb, block_node);

    ir_gen_defers_for_block(irb, child_context, outer_block_context, false, false);

    return return_value;
}

static IrInstruction *ir_gen_bin_op_id(IrBuilder *irb, AstNode *node, IrBinOp op_id) {
    IrInstruction *op1 = ir_gen_node(irb, node->data.bin_op_expr.op1, node->block_context);
    IrInstruction *op2 = ir_gen_node(irb, node->data.bin_op_expr.op2, node->block_context);
    return ir_build_bin_op(irb, node, op_id, op1, op2);
}

static IrInstruction *ir_gen_bin_op(IrBuilder *irb, AstNode *node) {
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
            return ir_gen_bin_op_id(irb, node, IrBinOpCmpEq);
        case BinOpTypeCmpNotEq:
            return ir_gen_bin_op_id(irb, node, IrBinOpCmpNotEq);
        case BinOpTypeCmpLessThan:
            return ir_gen_bin_op_id(irb, node, IrBinOpCmpLessThan);
        case BinOpTypeCmpGreaterThan:
            return ir_gen_bin_op_id(irb, node, IrBinOpCmpGreaterThan);
        case BinOpTypeCmpLessOrEq:
            return ir_gen_bin_op_id(irb, node, IrBinOpCmpLessOrEq);
        case BinOpTypeCmpGreaterOrEq:
            return ir_gen_bin_op_id(irb, node, IrBinOpCmpGreaterOrEq);
        case BinOpTypeBinOr:
            return ir_gen_bin_op_id(irb, node, IrBinOpBinOr);
        case BinOpTypeBinXor:
            return ir_gen_bin_op_id(irb, node, IrBinOpBinXor);
        case BinOpTypeBinAnd:
            return ir_gen_bin_op_id(irb, node, IrBinOpBinAnd);
        case BinOpTypeBitShiftLeft:
            return ir_gen_bin_op_id(irb, node, IrBinOpBitShiftLeft);
        case BinOpTypeBitShiftLeftWrap:
            return ir_gen_bin_op_id(irb, node, IrBinOpBitShiftLeftWrap);
        case BinOpTypeBitShiftRight:
            return ir_gen_bin_op_id(irb, node, IrBinOpBitShiftRight);
        case BinOpTypeAdd:
            return ir_gen_bin_op_id(irb, node, IrBinOpAdd);
        case BinOpTypeAddWrap:
            return ir_gen_bin_op_id(irb, node, IrBinOpAddWrap);
        case BinOpTypeSub:
            return ir_gen_bin_op_id(irb, node, IrBinOpSub);
        case BinOpTypeSubWrap:
            return ir_gen_bin_op_id(irb, node, IrBinOpSubWrap);
        case BinOpTypeMult:
            return ir_gen_bin_op_id(irb, node, IrBinOpMult);
        case BinOpTypeMultWrap:
            return ir_gen_bin_op_id(irb, node, IrBinOpMultWrap);
        case BinOpTypeDiv:
            return ir_gen_bin_op_id(irb, node, IrBinOpDiv);
        case BinOpTypeMod:
            return ir_gen_bin_op_id(irb, node, IrBinOpMod);
        case BinOpTypeArrayCat:
            return ir_gen_bin_op_id(irb, node, IrBinOpArrayCat);
        case BinOpTypeArrayMult:
            return ir_gen_bin_op_id(irb, node, IrBinOpArrayMult);
        case BinOpTypeUnwrapMaybe:
            zig_panic("TODO gen IR for unwrap maybe");
    }
    zig_unreachable();
}

static IrInstruction *ir_gen_num_lit(IrBuilder *irb, AstNode *node) {
    assert(node->type == NodeTypeNumberLiteral);

    if (node->data.number_literal.overflow) {
        add_node_error(irb->codegen, node, buf_sprintf("number literal too large to be represented in any type"));
        return irb->codegen->invalid_instruction;
    }

    return ir_build_const_bignum(irb, node, node->data.number_literal.bignum);
}

static IrInstruction *ir_gen_decl_ref(IrBuilder *irb, AstNode *source_node, AstNode *decl_node,
        bool pointer_only, BlockContext *scope)
{
    resolve_top_level_decl(irb->codegen, decl_node, pointer_only);
    TopLevelDecl *tld = get_as_top_level_decl(decl_node);
    if (tld->resolution == TldResolutionInvalid)
        return irb->codegen->invalid_instruction;

    if (decl_node->type == NodeTypeVariableDeclaration) {
        VariableTableEntry *var = decl_node->data.variable_declaration.variable;
        return ir_build_load_var(irb, source_node, var);
    } else if (decl_node->type == NodeTypeFnProto) {
        FnTableEntry *fn_entry = decl_node->data.fn_proto.fn_table_entry;
        assert(fn_entry->type_entry);
        if (fn_entry->type_entry->id == TypeTableEntryIdGenericFn) {
            return ir_build_const_generic_fn(irb, source_node, fn_entry->type_entry);
        } else {
            return ir_build_const_fn(irb, source_node, fn_entry);
        }
    } else if (decl_node->type == NodeTypeContainerDecl) {
        if (decl_node->data.struct_decl.generic_params.length > 0) {
            TypeTableEntry *type_entry = decl_node->data.struct_decl.generic_fn_type;
            assert(type_entry);
            return ir_build_const_generic_fn(irb, source_node, type_entry);
        } else {
            return ir_build_const_type(irb, source_node, decl_node->data.struct_decl.type_entry);
        }
    } else if (decl_node->type == NodeTypeTypeDecl) {
        return ir_build_const_type(irb, source_node, decl_node->data.type_decl.child_type_entry);
    } else {
        zig_unreachable();
    }
}

static IrInstruction *ir_gen_symbol(IrBuilder *irb, AstNode *node, bool pointer_only) {
    assert(node->type == NodeTypeSymbol);

    if (node->data.symbol_expr.override_type_entry)
        return ir_build_const_type(irb, node, node->data.symbol_expr.override_type_entry);

    Buf *variable_name = node->data.symbol_expr.symbol;

    auto primitive_table_entry = irb->codegen->primitive_type_table.maybe_get(variable_name);
    if (primitive_table_entry)
        return ir_build_const_type(irb, node, primitive_table_entry->value);

    VariableTableEntry *var = find_variable(irb->codegen, node->block_context, variable_name);
    if (var)
        return ir_build_load_var(irb, node, var);

    AstNode *decl_node = find_decl(node->block_context, variable_name);
    if (decl_node)
        return ir_gen_decl_ref(irb, node, decl_node, pointer_only, node->block_context);

    if (node->owner->any_imports_failed) {
        // skip the error message since we had a failing import in this file
        // if an import breaks we don't need redundant undeclared identifier errors
        return irb->codegen->invalid_instruction;
    }

    add_node_error(irb->codegen, node, buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
    return irb->codegen->invalid_instruction;
}

static IrInstruction *ir_gen_node_extra(IrBuilder *irb, AstNode *node, BlockContext *block_context,
        bool pointer_only)
{
    node->block_context = block_context;

    switch (node->type) {
        case NodeTypeBlock:
            return ir_gen_block(irb, node);
        case NodeTypeBinOpExpr:
            return ir_gen_bin_op(irb, node);
        case NodeTypeNumberLiteral:
            return ir_gen_num_lit(irb, node);
        case NodeTypeSymbol:
            return ir_gen_symbol(irb, node, pointer_only);
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

static IrInstruction *ir_gen_node(IrBuilder *irb, AstNode *node, BlockContext *scope) {
    bool pointer_only_no = false;
    return ir_gen_node_extra(irb, node, scope, pointer_only_no);
}

static IrInstruction *ir_gen_add_return(CodeGen *g, AstNode *node, BlockContext *scope,
        IrExecutable *ir_executable, bool add_return, bool pointer_only)
{
    assert(node->owner);

    IrBuilder ir_gen = {0};
    IrBuilder *irb = &ir_gen;

    irb->codegen = g;
    irb->exec = ir_executable;

    irb->current_basic_block = allocate<IrBasicBlock>(1);
    irb->exec->basic_block_list.append(irb->current_basic_block);

    IrInstruction *result = ir_gen_node_extra(irb, node, scope, pointer_only);
    assert(result);

    if (result == g->invalid_instruction)
        return result;

    if (add_return)
        return ir_build_return(irb, result->source_node, result);

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

static void ir_link_new(IrInstruction *new_instruction, IrInstruction *old_instruction) {
    new_instruction->other = old_instruction;
    old_instruction->other = new_instruction;
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

    add_node_error(ira->old_irb.codegen, instruction->source_node,
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
        return ira->old_irb.codegen->builtin_types.entry_invalid;
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
                return ira->old_irb.codegen->builtin_types.entry_invalid;
            }
        } else if (cur_type->id == TypeTableEntryIdNumLitInt ||
                   cur_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (ir_num_lit_fits_in_other_type(ira, cur_inst, prev_type)) {
                continue;
            } else {
                return ira->old_irb.codegen->builtin_types.entry_invalid;
            }
        } else {
            add_node_error(ira->old_irb.codegen, parent_instruction->source_node,
                buf_sprintf("incompatible types: '%s' and '%s'",
                    buf_ptr(&prev_type->name), buf_ptr(&cur_type->name)));

            return ira->old_irb.codegen->builtin_types.entry_invalid;
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

static IrInstruction *ir_get_casted_value(IrAnalyze *ira, IrInstruction *value, TypeTableEntry *expected_type) {
    assert(value);
    assert(value != ira->old_irb.codegen->invalid_instruction);
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
            add_node_error(ira->old_irb.codegen, first_executing_node(value->source_node),
                buf_sprintf("expected type '%s', got '%s'",
                    buf_ptr(&expected_type->name),
                    buf_ptr(&value->type_entry->name)));
            return ira->old_irb.codegen->invalid_instruction;

        case ImplicitCastMatchResultYes:
            {
                IrInstruction *dest_type = ir_build_const_type(&ira->new_irb, value->source_node, expected_type);
                bool is_implicit = true;
                IrInstruction *cast_instruction = ir_build_cast(&ira->new_irb, value->source_node, dest_type,
                        value, is_implicit);
                return cast_instruction;
            }
        case ImplicitCastMatchResultReportedError:
            return ira->old_irb.codegen->invalid_instruction;
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

    IrInstruction *value = ir_get_casted_value(ira, return_instruction->value->other, expected_return_type);
    if (value == ira->codegen->invalid_instruction) {
        return ira->codegen->builtin_types.entry_invalid;
    }

    ir_link_new(ir_build_return(&ira->new_irb, return_instruction->base.source_node, value),
            &return_instruction->base);

    return ira->codegen->builtin_types.entry_unreachable;
}

static TypeTableEntry *ir_analyze_instruction_const(IrAnalyze *ira, IrInstructionConst *const_instruction) {
    const_instruction->base.other = &const_instruction->base;
    return const_instruction->base.type_entry;
}

static TypeTableEntry *ir_analyze_bin_op_bool(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrInstruction *op1 = bin_op_instruction->op1;
    IrInstruction *op2 = bin_op_instruction->op2;

    IrInstruction *casted_op1 = ir_get_casted_value(ira, op1->other, ira->old_irb.codegen->builtin_types.entry_bool);
    if (casted_op1 == ira->old_irb.codegen->invalid_instruction)
        return ira->old_irb.codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op2 = ir_get_casted_value(ira, op2->other, ira->old_irb.codegen->builtin_types.entry_bool);
    if (casted_op2 == ira->old_irb.codegen->invalid_instruction)
        return ira->old_irb.codegen->builtin_types.entry_invalid;

    ir_link_new(ir_build_bin_op(&ira->new_irb, bin_op_instruction->base.source_node,
                bin_op_instruction->op_id, op1->other, op2->other), &bin_op_instruction->base);

    return ira->old_irb.codegen->builtin_types.entry_bool;
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
            return ira->old_irb.codegen->builtin_types.entry_invalid;

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
                add_node_error(ira->old_irb.codegen, source_node,
                    buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
                return ira->old_irb.codegen->builtin_types.entry_invalid;
            }
            break;

        case TypeTableEntryIdEnum:
            if (!is_equality_cmp || resolved_type->data.enumeration.gen_field_count != 0) {
                add_node_error(ira->old_irb.codegen, source_node,
                    buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
                return ira->old_irb.codegen->builtin_types.entry_invalid;
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
            add_node_error(ira->old_irb.codegen, source_node,
                buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
            return ira->old_irb.codegen->builtin_types.entry_invalid;

        case TypeTableEntryIdVar:
            zig_unreachable();
    }

    ir_link_new(ir_build_bin_op(&ira->new_irb, bin_op_instruction->base.source_node,
                op_id, op1->other, op2->other), &bin_op_instruction->base);

    return ira->old_irb.codegen->builtin_types.entry_bool;
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
        add_node_error(ira->old_irb.codegen, source_node, buf_sprintf("invalid operands to binary expression: '%s' and '%s'",
                buf_ptr(&op1->type_entry->name),
                buf_ptr(&op2->type_entry->name)));
        return ira->old_irb.codegen->builtin_types.entry_invalid;
    }

    ir_link_new(ir_build_bin_op(&ira->new_irb, bin_op_instruction->base.source_node,
            op_id, op1->other, op2->other), &bin_op_instruction->base);

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
    ir_link_new(ir_build_load_var(&ira->new_irb, load_var_instruction->base.source_node,
            load_var_instruction->var), &load_var_instruction->base);
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
    if (instruction->other)
        instruction->other->type_entry = instruction_type;

    IrInstruction *casted_instruction = ir_get_casted_value(ira, instruction, expected_type);
    return casted_instruction->type_entry;
}

// This function attempts to evaluate IR code while doing type checking and other analysis.
// It emits a new IrExecutable which is partially evaluated IR code.
TypeTableEntry *ir_analyze(CodeGen *codegen, IrExecutable *old_exec, IrExecutable *new_exec,
        TypeTableEntry *expected_type)
{
    IrAnalyze ir_analyze_data = {};
    IrAnalyze *ira = &ir_analyze_data;
    ira->codegen = codegen;

    ira->old_irb.codegen = codegen;
    ira->old_irb.exec = old_exec;

    ira->new_irb.codegen = codegen;
    ira->new_irb.exec = new_exec;

    ira->exec_context.var_slot_count = ira->old_irb.exec->var_slot_count;
    ira->exec_context.var_slot_list = allocate<IrVarSlot>(ira->exec_context.var_slot_count);

    TypeTableEntry *return_type = ira->codegen->builtin_types.entry_void;

    ira->new_irb.current_basic_block = allocate<IrBasicBlock>(1);
    ira->new_irb.exec->basic_block_list.append(ira->new_irb.current_basic_block);

    ira->old_irb.current_basic_block = ira->old_irb.exec->basic_block_list.at(0);

    ira->new_irb.current_basic_block->other = ira->old_irb.current_basic_block;
    ira->old_irb.current_basic_block->other = ira->new_irb.current_basic_block;


    for (size_t i = 0; i < ira->old_irb.current_basic_block->instruction_list.length; i += 1) {
        IrInstruction *instruction = ira->old_irb.current_basic_block->instruction_list.at(i);
        if (return_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(ira->codegen, first_executing_node(instruction->source_node),
                    buf_sprintf("unreachable code"));
            break;
        }
        bool is_last = (i == ira->old_irb.current_basic_block->instruction_list.length - 1);
        TypeTableEntry *passed_expected_type = is_last ? expected_type : nullptr;
        return_type = ir_analyze_instruction(ira, instruction, passed_expected_type);
    }

    return return_type;
}
