/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ast_render.hpp"
#include "error.hpp"
#include "ir.hpp"
#include "ir_print.hpp"
#include "os.hpp"
#include "parseh.hpp"

struct IrExecContext {
    ConstExprValue *mem_slot_list;
    size_t mem_slot_count;
};

struct LoopStackItem {
    IrBasicBlock *break_block;
    IrBasicBlock *continue_block;
    IrInstruction *is_comptime;
};

struct IrBuilder {
    CodeGen *codegen;
    IrExecutable *exec;
    IrBasicBlock *current_basic_block;
    ZigList<LoopStackItem> loop_stack;
};

struct IrAnalyze {
    CodeGen *codegen;
    IrBuilder old_irb;
    IrBuilder new_irb;
    IrExecContext exec_context;
    ZigList<IrBasicBlock *> old_bb_queue;
    size_t block_queue_index;
    size_t instruction_index;
    TypeTableEntry *explicit_return_type;
    ZigList<IrInstruction *> implicit_return_type_list;
    IrBasicBlock *const_predecessor_bb;
};

static const LVal LVAL_NONE = { false, false, false };
static const LVal LVAL_PTR = { true, false, false };

static LVal make_lval_addr(bool is_const, bool is_volatile) {
    return { true, is_const, is_volatile };
}

static IrInstruction *ir_gen_node(IrBuilder *irb, AstNode *node, Scope *scope);
static IrInstruction *ir_gen_node_extra(IrBuilder *irb, AstNode *node, Scope *scope, LVal lval);
static TypeTableEntry *ir_analyze_instruction(IrAnalyze *ira, IrInstruction *instruction);
static IrInstruction *ir_implicit_cast(IrAnalyze *ira, IrInstruction *value, TypeTableEntry *expected_type);

ConstExprValue *const_ptr_pointee(ConstExprValue *const_val) {
    assert(const_val->type->id == TypeTableEntryIdPointer);
    assert(const_val->special == ConstValSpecialStatic);
    switch (const_val->data.x_ptr.special) {
        case ConstPtrSpecialInvalid:
            zig_unreachable();
        case ConstPtrSpecialRef:
            return const_val->data.x_ptr.data.ref.pointee;
        case ConstPtrSpecialBaseArray:
            return &const_val->data.x_ptr.data.base_array.array_val->data.x_array.elements[
                const_val->data.x_ptr.data.base_array.elem_index];
        case ConstPtrSpecialBaseStruct:
            return &const_val->data.x_ptr.data.base_struct.struct_val->data.x_struct.fields[
                const_val->data.x_ptr.data.base_struct.field_index];
        case ConstPtrSpecialHardCodedAddr:
            zig_unreachable();
        case ConstPtrSpecialDiscard:
            zig_unreachable();
    }
    zig_unreachable();
}

static bool ir_should_inline(IrExecutable *exec, Scope *scope) {
    if (exec->is_inline)
        return true;

    while (scope != nullptr) {
        if (scope->id == ScopeIdCompTime)
            return true;
        scope = scope->parent;
    }
    return false;
}

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

static size_t exec_next_mem_slot(IrExecutable *exec) {
    size_t result = exec->mem_slot_count;
    exec->mem_slot_count += 1;
    return result;
}

static FnTableEntry *exec_fn_entry(IrExecutable *exec) {
    return exec->fn_entry;
}

static Buf *exec_c_import_buf(IrExecutable *exec) {
    return exec->c_import_buf;
}

static bool value_is_comptime(ConstExprValue *const_val) {
    return const_val->special != ConstValSpecialRuntime;
}

static bool instr_is_comptime(IrInstruction *instruction) {
    return value_is_comptime(&instruction->value);
}

static bool instr_is_unreachable(IrInstruction *instruction) {
    return instruction->value.type && instruction->value.type->id == TypeTableEntryIdUnreachable;
}

static void ir_link_new_instruction(IrInstruction *new_instruction, IrInstruction *old_instruction) {
    new_instruction->other = old_instruction;
    old_instruction->other = new_instruction;
}

static void ir_link_new_bb(IrBasicBlock *new_bb, IrBasicBlock *old_bb) {
    new_bb->other = old_bb;
    old_bb->other = new_bb;
}

static void ir_ref_bb(IrBasicBlock *bb) {
    bb->ref_count += 1;
}

static void ir_ref_instruction(IrInstruction *instruction, IrBasicBlock *cur_bb) {
    assert(instruction->id != IrInstructionIdInvalid);
    instruction->ref_count += 1;
    if (instruction->owner_bb != cur_bb && !instr_is_comptime(instruction))
        ir_ref_bb(instruction->owner_bb);
}

static void ir_ref_var(VariableTableEntry *var) {
    var->ref_count += 1;
}

static IrBasicBlock *ir_create_basic_block(IrBuilder *irb, Scope *scope, const char *name_hint) {
    IrBasicBlock *result = allocate<IrBasicBlock>(1);
    result->scope = scope;
    result->name_hint = name_hint;
    result->debug_id = exec_next_debug_id(irb->exec);
    return result;
}

static IrBasicBlock *ir_build_basic_block(IrBuilder *irb, Scope *scope, const char *name_hint) {
    IrBasicBlock *result = ir_create_basic_block(irb, scope, name_hint);
    irb->exec->basic_block_list.append(result);
    return result;
}

static IrBasicBlock *ir_build_bb_from(IrBuilder *irb, IrBasicBlock *other_bb) {
    IrBasicBlock *new_bb = ir_create_basic_block(irb, other_bb->scope, other_bb->name_hint);
    ir_link_new_bb(new_bb, other_bb);
    return new_bb;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCondBr *) {
    return IrInstructionIdCondBr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionBr *) {
    return IrInstructionIdBr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSwitchBr *) {
    return IrInstructionIdSwitchBr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSwitchVar *) {
    return IrInstructionIdSwitchVar;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSwitchTarget *) {
    return IrInstructionIdSwitchTarget;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionPhi *) {
    return IrInstructionIdPhi;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionUnOp *) {
    return IrInstructionIdUnOp;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionBinOp *) {
    return IrInstructionIdBinOp;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionDeclVar *) {
    return IrInstructionIdDeclVar;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionLoadPtr *) {
    return IrInstructionIdLoadPtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionStorePtr *) {
    return IrInstructionIdStorePtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionFieldPtr *) {
    return IrInstructionIdFieldPtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionStructFieldPtr *) {
    return IrInstructionIdStructFieldPtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionEnumFieldPtr *) {
    return IrInstructionIdEnumFieldPtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionElemPtr *) {
    return IrInstructionIdElemPtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionVarPtr *) {
    return IrInstructionIdVarPtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCall *) {
    return IrInstructionIdCall;
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

static constexpr IrInstructionId ir_instruction_id(IrInstructionContainerInitList *) {
    return IrInstructionIdContainerInitList;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionContainerInitFields *) {
    return IrInstructionIdContainerInitFields;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionUnreachable *) {
    return IrInstructionIdUnreachable;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionTypeOf *) {
    return IrInstructionIdTypeOf;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionToPtrType *) {
    return IrInstructionIdToPtrType;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionPtrTypeChild *) {
    return IrInstructionIdPtrTypeChild;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSetDebugSafety *) {
    return IrInstructionIdSetDebugSafety;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionArrayType *) {
    return IrInstructionIdArrayType;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSliceType *) {
    return IrInstructionIdSliceType;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionAsm *) {
    return IrInstructionIdAsm;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCompileVar *) {
    return IrInstructionIdCompileVar;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSizeOf *) {
    return IrInstructionIdSizeOf;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionTestNonNull *) {
    return IrInstructionIdTestNonNull;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionUnwrapMaybe *) {
    return IrInstructionIdUnwrapMaybe;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionClz *) {
    return IrInstructionIdClz;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCtz *) {
    return IrInstructionIdCtz;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionEnumTag *) {
    return IrInstructionIdEnumTag;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionGeneratedCode *) {
    return IrInstructionIdGeneratedCode;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionImport *) {
    return IrInstructionIdImport;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCImport *) {
    return IrInstructionIdCImport;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCInclude *) {
    return IrInstructionIdCInclude;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCDefine *) {
    return IrInstructionIdCDefine;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCUndef *) {
    return IrInstructionIdCUndef;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionArrayLen *) {
    return IrInstructionIdArrayLen;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionRef *) {
    return IrInstructionIdRef;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionStructInit *) {
    return IrInstructionIdStructInit;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionMinValue *) {
    return IrInstructionIdMinValue;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionMaxValue *) {
    return IrInstructionIdMaxValue;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCompileErr *) {
    return IrInstructionIdCompileErr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCompileLog *) {
    return IrInstructionIdCompileLog;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionErrName *) {
    return IrInstructionIdErrName;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionEmbedFile *) {
    return IrInstructionIdEmbedFile;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCmpxchg *) {
    return IrInstructionIdCmpxchg;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionFence *) {
    return IrInstructionIdFence;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionDivExact *) {
    return IrInstructionIdDivExact;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionTruncate *) {
    return IrInstructionIdTruncate;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionIntType *) {
    return IrInstructionIdIntType;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionBoolNot *) {
    return IrInstructionIdBoolNot;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionMemset *) {
    return IrInstructionIdMemset;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionMemcpy *) {
    return IrInstructionIdMemcpy;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSlice *) {
    return IrInstructionIdSlice;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionMemberCount *) {
    return IrInstructionIdMemberCount;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionBreakpoint *) {
    return IrInstructionIdBreakpoint;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionReturnAddress *) {
    return IrInstructionIdReturnAddress;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionFrameAddress *) {
    return IrInstructionIdFrameAddress;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionAlignOf *) {
    return IrInstructionIdAlignOf;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionOverflowOp *) {
    return IrInstructionIdOverflowOp;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionTestErr *) {
    return IrInstructionIdTestErr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionUnwrapErrCode *) {
    return IrInstructionIdUnwrapErrCode;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionUnwrapErrPayload *) {
    return IrInstructionIdUnwrapErrPayload;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionMaybeWrap *) {
    return IrInstructionIdMaybeWrap;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionErrWrapPayload *) {
    return IrInstructionIdErrWrapPayload;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionErrWrapCode *) {
    return IrInstructionIdErrWrapCode;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionFnProto *) {
    return IrInstructionIdFnProto;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionTestComptime *) {
    return IrInstructionIdTestComptime;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionInitEnum *) {
    return IrInstructionIdInitEnum;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionPtrCast *) {
    return IrInstructionIdPtrCast;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionWidenOrShorten *) {
    return IrInstructionIdWidenOrShorten;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionPtrToInt *) {
    return IrInstructionIdPtrToInt;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionIntToPtr *) {
    return IrInstructionIdIntToPtr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionIntToEnum *) {
    return IrInstructionIdIntToEnum;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionIntToErr *) {
    return IrInstructionIdIntToErr;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionErrToInt *) {
    return IrInstructionIdErrToInt;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCheckSwitchProngs *) {
    return IrInstructionIdCheckSwitchProngs;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionTestType *) {
    return IrInstructionIdTestType;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionTypeName *) {
    return IrInstructionIdTypeName;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionCanImplicitCast *) {
    return IrInstructionIdCanImplicitCast;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSetGlobalAlign *) {
    return IrInstructionIdSetGlobalAlign;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSetGlobalSection *) {
    return IrInstructionIdSetGlobalSection;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSetGlobalLinkage *) {
    return IrInstructionIdSetGlobalLinkage;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionDeclRef *) {
    return IrInstructionIdDeclRef;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionPanic *) {
    return IrInstructionIdPanic;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionEnumTagName *) {
    return IrInstructionIdEnumTagName;
}

static constexpr IrInstructionId ir_instruction_id(IrInstructionSetFnRefInline *) {
    return IrInstructionIdSetFnRefInline;
}

template<typename T>
static T *ir_create_instruction(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    T *special_instruction = allocate<T>(1);
    special_instruction->base.id = ir_instruction_id(special_instruction);
    special_instruction->base.scope = scope;
    special_instruction->base.source_node = source_node;
    special_instruction->base.debug_id = exec_next_debug_id(irb->exec);
    special_instruction->base.owner_bb = irb->current_basic_block;
    return special_instruction;
}

template<typename T>
static T *ir_build_instruction(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    T *special_instruction = ir_create_instruction<T>(irb, scope, source_node);
    ir_instruction_append(irb->current_basic_block, &special_instruction->base);
    return special_instruction;
}

static IrInstruction *ir_build_cast(IrBuilder *irb, Scope *scope, AstNode *source_node, TypeTableEntry *dest_type,
    IrInstruction *value, CastOp cast_op)
{
    IrInstructionCast *cast_instruction = ir_build_instruction<IrInstructionCast>(irb, scope, source_node);
    cast_instruction->dest_type = dest_type;
    cast_instruction->value = value;
    cast_instruction->cast_op = cast_op;

    ir_ref_instruction(value, irb->current_basic_block);

    return &cast_instruction->base;
}

static IrInstruction *ir_build_cond_br(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *condition,
        IrBasicBlock *then_block, IrBasicBlock *else_block, IrInstruction *is_comptime)
{
    IrInstructionCondBr *cond_br_instruction = ir_build_instruction<IrInstructionCondBr>(irb, scope, source_node);
    cond_br_instruction->base.value.type = irb->codegen->builtin_types.entry_unreachable;
    cond_br_instruction->base.value.special = ConstValSpecialStatic;
    cond_br_instruction->condition = condition;
    cond_br_instruction->then_block = then_block;
    cond_br_instruction->else_block = else_block;
    cond_br_instruction->is_comptime = is_comptime;

    ir_ref_instruction(condition, irb->current_basic_block);
    ir_ref_bb(then_block);
    ir_ref_bb(else_block);
    if (is_comptime) ir_ref_instruction(is_comptime, irb->current_basic_block);

    return &cond_br_instruction->base;
}

static IrInstruction *ir_build_cond_br_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *condition, IrBasicBlock *then_block, IrBasicBlock *else_block, IrInstruction *is_comptime)
{
    IrInstruction *new_instruction = ir_build_cond_br(irb, old_instruction->scope, old_instruction->source_node,
            condition, then_block, else_block, is_comptime);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_return(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *return_value) {
    IrInstructionReturn *return_instruction = ir_build_instruction<IrInstructionReturn>(irb, scope, source_node);
    return_instruction->base.value.type = irb->codegen->builtin_types.entry_unreachable;
    return_instruction->base.value.special = ConstValSpecialStatic;
    return_instruction->value = return_value;

    ir_ref_instruction(return_value, irb->current_basic_block);

    return &return_instruction->base;
}

static IrInstruction *ir_build_return_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *return_value)
{
    IrInstruction *new_instruction = ir_build_return(irb, old_instruction->scope, old_instruction->source_node, return_value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_create_const(IrBuilder *irb, Scope *scope, AstNode *source_node,
    TypeTableEntry *type_entry)
{
    assert(type_entry);
    IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = type_entry;
    const_instruction->base.value.special = ConstValSpecialStatic;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_void(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_void;
    const_instruction->base.value.special = ConstValSpecialStatic;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_undefined(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.special = ConstValSpecialUndef;
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_undef;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_uint(IrBuilder *irb, Scope *scope, AstNode *source_node, uint64_t value) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_num_lit_int;
    const_instruction->base.value.special = ConstValSpecialStatic;
    bignum_init_unsigned(&const_instruction->base.value.data.x_bignum, value);
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_bignum(IrBuilder *irb, Scope *scope, AstNode *source_node, BigNum *bignum) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = (bignum->kind == BigNumKindInt) ?
        irb->codegen->builtin_types.entry_num_lit_int : irb->codegen->builtin_types.entry_num_lit_float;
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_bignum = *bignum;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_null(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_null;
    const_instruction->base.value.special = ConstValSpecialStatic;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_usize(IrBuilder *irb, Scope *scope, AstNode *source_node, uint64_t value) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_usize;
    const_instruction->base.value.special = ConstValSpecialStatic;
    bignum_init_unsigned(&const_instruction->base.value.data.x_bignum, value);
    return &const_instruction->base;
}

static IrInstruction *ir_create_const_type(IrBuilder *irb, Scope *scope, AstNode *source_node,
        TypeTableEntry *type_entry)
{
    IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_type;
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_type = type_entry;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_type(IrBuilder *irb, Scope *scope, AstNode *source_node,
        TypeTableEntry *type_entry)
{
    IrInstruction *instruction = ir_create_const_type(irb, scope, source_node, type_entry);
    ir_instruction_append(irb->current_basic_block, instruction);
    return instruction;
}

static IrInstruction *ir_create_const_fn(IrBuilder *irb, Scope *scope, AstNode *source_node, FnTableEntry *fn_entry) {
    IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = fn_entry->type_entry;
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_fn.fn_entry = fn_entry;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_fn(IrBuilder *irb, Scope *scope, AstNode *source_node, FnTableEntry *fn_entry) {
    IrInstruction *instruction = ir_create_const_fn(irb, scope, source_node, fn_entry);
    ir_instruction_append(irb->current_basic_block, instruction);
    return instruction;
}

static IrInstruction *ir_build_const_import(IrBuilder *irb, Scope *scope, AstNode *source_node, ImportTableEntry *import) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_namespace;
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_import = import;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_scope(IrBuilder *irb, Scope *parent_scope, AstNode *source_node,
        Scope *target_scope)
{
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, parent_scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_block;
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_block = target_scope;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_bool(IrBuilder *irb, Scope *scope, AstNode *source_node, bool value) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = irb->codegen->builtin_types.entry_bool;
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_bool = value;
    return &const_instruction->base;
}

static IrInstruction *ir_build_const_bound_fn(IrBuilder *irb, Scope *scope, AstNode *source_node,
    FnTableEntry *fn_entry, IrInstruction *first_arg)
{
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    const_instruction->base.value.type = get_bound_fn_type(irb->codegen, fn_entry);
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_bound_fn.fn = fn_entry;
    const_instruction->base.value.data.x_bound_fn.first_arg = first_arg;
    return &const_instruction->base;
}

static IrInstruction *ir_create_const_str_lit(IrBuilder *irb, Scope *scope, AstNode *source_node, Buf *str) {
    IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(irb, scope, source_node);
    init_const_str_lit(irb->codegen, &const_instruction->base.value, str);

    return &const_instruction->base;
}
static IrInstruction *ir_build_const_str_lit(IrBuilder *irb, Scope *scope, AstNode *source_node, Buf *str) {
    IrInstruction *instruction = ir_create_const_str_lit(irb, scope, source_node, str);
    ir_instruction_append(irb->current_basic_block, instruction);
    return instruction;
}

static IrInstruction *ir_build_const_c_str_lit(IrBuilder *irb, Scope *scope, AstNode *source_node, Buf *str) {
    IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, source_node);
    init_const_c_str_lit(irb->codegen, &const_instruction->base.value, str);
    return &const_instruction->base;
}

static IrInstruction *ir_build_bin_op(IrBuilder *irb, Scope *scope, AstNode *source_node, IrBinOp op_id,
        IrInstruction *op1, IrInstruction *op2, bool safety_check_on)
{
    IrInstructionBinOp *bin_op_instruction = ir_build_instruction<IrInstructionBinOp>(irb, scope, source_node);
    bin_op_instruction->op_id = op_id;
    bin_op_instruction->op1 = op1;
    bin_op_instruction->op2 = op2;
    bin_op_instruction->safety_check_on = safety_check_on;

    ir_ref_instruction(op1, irb->current_basic_block);
    ir_ref_instruction(op2, irb->current_basic_block);

    return &bin_op_instruction->base;
}

static IrInstruction *ir_build_bin_op_from(IrBuilder *irb, IrInstruction *old_instruction, IrBinOp op_id,
        IrInstruction *op1, IrInstruction *op2, bool safety_check_on)
{
    IrInstruction *new_instruction = ir_build_bin_op(irb, old_instruction->scope,
            old_instruction->source_node, op_id, op1, op2, safety_check_on);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_var_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node,
        VariableTableEntry *var, bool is_const, bool is_volatile)
{
    IrInstructionVarPtr *instruction = ir_build_instruction<IrInstructionVarPtr>(irb, scope, source_node);
    instruction->var = var;
    instruction->is_const = is_const;
    instruction->is_volatile = is_volatile;

    ir_ref_var(var);

    return &instruction->base;
}

static IrInstruction *ir_build_elem_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *array_ptr,
        IrInstruction *elem_index, bool safety_check_on)
{
    IrInstructionElemPtr *instruction = ir_build_instruction<IrInstructionElemPtr>(irb, scope, source_node);
    instruction->array_ptr = array_ptr;
    instruction->elem_index = elem_index;
    instruction->safety_check_on = safety_check_on;

    ir_ref_instruction(array_ptr, irb->current_basic_block);
    ir_ref_instruction(elem_index, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_elem_ptr_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *array_ptr, IrInstruction *elem_index, bool safety_check_on)
{
    IrInstruction *new_instruction = ir_build_elem_ptr(irb, old_instruction->scope,
            old_instruction->source_node, array_ptr, elem_index, safety_check_on);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_field_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *container_ptr, Buf *field_name)
{
    IrInstructionFieldPtr *instruction = ir_build_instruction<IrInstructionFieldPtr>(irb, scope, source_node);
    instruction->container_ptr = container_ptr;
    instruction->field_name = field_name;

    ir_ref_instruction(container_ptr, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_struct_field_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *struct_ptr, TypeStructField *field)
{
    IrInstructionStructFieldPtr *instruction = ir_build_instruction<IrInstructionStructFieldPtr>(irb, scope, source_node);
    instruction->struct_ptr = struct_ptr;
    instruction->field = field;

    ir_ref_instruction(struct_ptr, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_struct_field_ptr_from(IrBuilder *irb, IrInstruction *old_instruction,
    IrInstruction *struct_ptr, TypeStructField *type_struct_field)
{
    IrInstruction *new_instruction = ir_build_struct_field_ptr(irb, old_instruction->scope,
            old_instruction->source_node, struct_ptr, type_struct_field);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_enum_field_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *enum_ptr, TypeEnumField *field)
{
    IrInstructionEnumFieldPtr *instruction = ir_build_instruction<IrInstructionEnumFieldPtr>(irb, scope, source_node);
    instruction->enum_ptr = enum_ptr;
    instruction->field = field;

    ir_ref_instruction(enum_ptr, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_enum_field_ptr_from(IrBuilder *irb, IrInstruction *old_instruction,
    IrInstruction *enum_ptr, TypeEnumField *type_enum_field)
{
    IrInstruction *new_instruction = ir_build_enum_field_ptr(irb, old_instruction->scope,
            old_instruction->source_node, enum_ptr, type_enum_field);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_call(IrBuilder *irb, Scope *scope, AstNode *source_node,
        FnTableEntry *fn_entry, IrInstruction *fn_ref, size_t arg_count, IrInstruction **args,
        bool is_comptime, bool is_inline)
{
    IrInstructionCall *call_instruction = ir_build_instruction<IrInstructionCall>(irb, scope, source_node);
    call_instruction->fn_entry = fn_entry;
    call_instruction->fn_ref = fn_ref;
    call_instruction->is_comptime = is_comptime;
    call_instruction->is_inline = is_inline;
    call_instruction->args = args;
    call_instruction->arg_count = arg_count;

    if (fn_ref)
        ir_ref_instruction(fn_ref, irb->current_basic_block);
    for (size_t i = 0; i < arg_count; i += 1)
        ir_ref_instruction(args[i], irb->current_basic_block);

    return &call_instruction->base;
}

static IrInstruction *ir_build_call_from(IrBuilder *irb, IrInstruction *old_instruction,
        FnTableEntry *fn_entry, IrInstruction *fn_ref, size_t arg_count, IrInstruction **args,
        bool is_comptime, bool is_inline)
{
    IrInstruction *new_instruction = ir_build_call(irb, old_instruction->scope,
            old_instruction->source_node, fn_entry, fn_ref, arg_count, args, is_comptime, is_inline);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_phi(IrBuilder *irb, Scope *scope, AstNode *source_node,
        size_t incoming_count, IrBasicBlock **incoming_blocks, IrInstruction **incoming_values)
{
    assert(incoming_count != 0);
    assert(incoming_count != SIZE_MAX);

    IrInstructionPhi *phi_instruction = ir_build_instruction<IrInstructionPhi>(irb, scope, source_node);
    phi_instruction->incoming_count = incoming_count;
    phi_instruction->incoming_blocks = incoming_blocks;
    phi_instruction->incoming_values = incoming_values;

    for (size_t i = 0; i < incoming_count; i += 1) {
        ir_ref_bb(incoming_blocks[i]);
        ir_ref_instruction(incoming_values[i], irb->current_basic_block);
    }

    return &phi_instruction->base;
}

static IrInstruction *ir_build_phi_from(IrBuilder *irb, IrInstruction *old_instruction,
        size_t incoming_count, IrBasicBlock **incoming_blocks, IrInstruction **incoming_values)
{
    IrInstruction *new_instruction = ir_build_phi(irb, old_instruction->scope, old_instruction->source_node,
            incoming_count, incoming_blocks, incoming_values);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_create_br(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrBasicBlock *dest_block, IrInstruction *is_comptime)
{
    IrInstructionBr *br_instruction = ir_create_instruction<IrInstructionBr>(irb, scope, source_node);
    br_instruction->base.value.type = irb->codegen->builtin_types.entry_unreachable;
    br_instruction->base.value.special = ConstValSpecialStatic;
    br_instruction->dest_block = dest_block;
    br_instruction->is_comptime = is_comptime;

    ir_ref_bb(dest_block);
    if (is_comptime) ir_ref_instruction(is_comptime, irb->current_basic_block);

    return &br_instruction->base;
}

static IrInstruction *ir_build_br(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrBasicBlock *dest_block, IrInstruction *is_comptime)
{
    IrInstruction *instruction = ir_create_br(irb, scope, source_node, dest_block, is_comptime);
    ir_instruction_append(irb->current_basic_block, instruction);
    return instruction;
}

static IrInstruction *ir_build_br_from(IrBuilder *irb, IrInstruction *old_instruction, IrBasicBlock *dest_block) {
    IrInstruction *new_instruction = ir_build_br(irb, old_instruction->scope, old_instruction->source_node, dest_block, nullptr);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_un_op(IrBuilder *irb, Scope *scope, AstNode *source_node, IrUnOp op_id, IrInstruction *value) {
    IrInstructionUnOp *br_instruction = ir_build_instruction<IrInstructionUnOp>(irb, scope, source_node);
    br_instruction->op_id = op_id;
    br_instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &br_instruction->base;
}

static IrInstruction *ir_build_un_op_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrUnOp op_id, IrInstruction *value)
{
    IrInstruction *new_instruction = ir_build_un_op(irb, old_instruction->scope,
            old_instruction->source_node, op_id, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_container_init_list(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *container_type, size_t item_count, IrInstruction **items)
{
    IrInstructionContainerInitList *container_init_list_instruction =
        ir_build_instruction<IrInstructionContainerInitList>(irb, scope, source_node);
    container_init_list_instruction->container_type = container_type;
    container_init_list_instruction->item_count = item_count;
    container_init_list_instruction->items = items;

    ir_ref_instruction(container_type, irb->current_basic_block);
    for (size_t i = 0; i < item_count; i += 1) {
        ir_ref_instruction(items[i], irb->current_basic_block);
    }

    return &container_init_list_instruction->base;
}

static IrInstruction *ir_build_container_init_list_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *container_type, size_t item_count, IrInstruction **items)
{
    IrInstruction *new_instruction = ir_build_container_init_list(irb, old_instruction->scope,
            old_instruction->source_node, container_type, item_count, items);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_container_init_fields(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *container_type, size_t field_count, IrInstructionContainerInitFieldsField *fields)
{
    IrInstructionContainerInitFields *container_init_fields_instruction =
        ir_build_instruction<IrInstructionContainerInitFields>(irb, scope, source_node);
    container_init_fields_instruction->container_type = container_type;
    container_init_fields_instruction->field_count = field_count;
    container_init_fields_instruction->fields = fields;

    ir_ref_instruction(container_type, irb->current_basic_block);
    for (size_t i = 0; i < field_count; i += 1) {
        ir_ref_instruction(fields[i].value, irb->current_basic_block);
    }

    return &container_init_fields_instruction->base;
}

static IrInstruction *ir_build_struct_init(IrBuilder *irb, Scope *scope, AstNode *source_node,
        TypeTableEntry *struct_type, size_t field_count, IrInstructionStructInitField *fields)
{
    IrInstructionStructInit *struct_init_instruction = ir_build_instruction<IrInstructionStructInit>(irb, scope, source_node);
    struct_init_instruction->struct_type = struct_type;
    struct_init_instruction->field_count = field_count;
    struct_init_instruction->fields = fields;

    for (size_t i = 0; i < field_count; i += 1)
        ir_ref_instruction(fields[i].value, irb->current_basic_block);

    return &struct_init_instruction->base;
}

static IrInstruction *ir_build_struct_init_from(IrBuilder *irb, IrInstruction *old_instruction,
        TypeTableEntry *struct_type, size_t field_count, IrInstructionStructInitField *fields)
{
    IrInstruction *new_instruction = ir_build_struct_init(irb, old_instruction->scope,
            old_instruction->source_node, struct_type, field_count, fields);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_unreachable(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionUnreachable *unreachable_instruction =
        ir_build_instruction<IrInstructionUnreachable>(irb, scope, source_node);
    unreachable_instruction->base.value.special = ConstValSpecialStatic;
    unreachable_instruction->base.value.type = irb->codegen->builtin_types.entry_unreachable;
    return &unreachable_instruction->base;
}

static IrInstruction *ir_build_unreachable_from(IrBuilder *irb, IrInstruction *old_instruction) {
    IrInstruction *new_instruction = ir_build_unreachable(irb, old_instruction->scope, old_instruction->source_node);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_store_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *ptr, IrInstruction *value)
{
    IrInstructionStorePtr *instruction = ir_build_instruction<IrInstructionStorePtr>(irb, scope, source_node);
    instruction->base.value.special = ConstValSpecialStatic;
    instruction->base.value.type = irb->codegen->builtin_types.entry_void;
    instruction->ptr = ptr;
    instruction->value = value;

    ir_ref_instruction(ptr, irb->current_basic_block);
    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_store_ptr_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *ptr, IrInstruction *value)
{
    IrInstruction *new_instruction = ir_build_store_ptr(irb, old_instruction->scope,
            old_instruction->source_node, ptr, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_var_decl(IrBuilder *irb, Scope *scope, AstNode *source_node,
        VariableTableEntry *var, IrInstruction *var_type, IrInstruction *init_value)
{
    IrInstructionDeclVar *decl_var_instruction = ir_build_instruction<IrInstructionDeclVar>(irb, scope, source_node);
    decl_var_instruction->base.value.special = ConstValSpecialStatic;
    decl_var_instruction->base.value.type = irb->codegen->builtin_types.entry_void;
    decl_var_instruction->var = var;
    decl_var_instruction->var_type = var_type;
    decl_var_instruction->init_value = init_value;

    if (var_type) ir_ref_instruction(var_type, irb->current_basic_block);
    ir_ref_instruction(init_value, irb->current_basic_block);

    return &decl_var_instruction->base;
}

static IrInstruction *ir_build_var_decl_from(IrBuilder *irb, IrInstruction *old_instruction,
        VariableTableEntry *var, IrInstruction *var_type, IrInstruction *init_value)
{
    IrInstruction *new_instruction = ir_build_var_decl(irb, old_instruction->scope,
            old_instruction->source_node, var, var_type, init_value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_load_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *ptr) {
    IrInstructionLoadPtr *instruction = ir_build_instruction<IrInstructionLoadPtr>(irb, scope, source_node);
    instruction->ptr = ptr;

    ir_ref_instruction(ptr, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_load_ptr_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *ptr) {
    IrInstruction *new_instruction = ir_build_load_ptr(irb, old_instruction->scope,
            old_instruction->source_node, ptr);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_typeof(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionTypeOf *instruction = ir_build_instruction<IrInstructionTypeOf>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_to_ptr_type(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionToPtrType *instruction = ir_build_instruction<IrInstructionToPtrType>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_ptr_type_child(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *value)
{
    IrInstructionPtrTypeChild *instruction = ir_build_instruction<IrInstructionPtrTypeChild>(
        irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_set_debug_safety(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *scope_value, IrInstruction *debug_safety_on)
{
    IrInstructionSetDebugSafety *instruction = ir_build_instruction<IrInstructionSetDebugSafety>(irb, scope, source_node);
    instruction->scope_value = scope_value;
    instruction->debug_safety_on = debug_safety_on;

    ir_ref_instruction(scope_value, irb->current_basic_block);
    ir_ref_instruction(debug_safety_on, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_array_type(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *size,
        IrInstruction *child_type)
{
    IrInstructionArrayType *instruction = ir_build_instruction<IrInstructionArrayType>(irb, scope, source_node);
    instruction->size = size;
    instruction->child_type = child_type;

    ir_ref_instruction(size, irb->current_basic_block);
    ir_ref_instruction(child_type, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_slice_type(IrBuilder *irb, Scope *scope, AstNode *source_node, bool is_const,
        IrInstruction *child_type)
{
    IrInstructionSliceType *instruction = ir_build_instruction<IrInstructionSliceType>(irb, scope, source_node);
    instruction->is_const = is_const;
    instruction->child_type = child_type;

    ir_ref_instruction(child_type, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_asm(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction **input_list,
        IrInstruction **output_types, VariableTableEntry **output_vars, size_t return_count, bool has_side_effects)
{
    IrInstructionAsm *instruction = ir_build_instruction<IrInstructionAsm>(irb, scope, source_node);
    instruction->input_list = input_list;
    instruction->output_types = output_types;
    instruction->output_vars = output_vars;
    instruction->return_count = return_count;
    instruction->has_side_effects = has_side_effects;

    assert(source_node->type == NodeTypeAsmExpr);
    for (size_t i = 0; i < source_node->data.asm_expr.output_list.length; i += 1) {
        IrInstruction *output_type = output_types[i];
        if (output_type) ir_ref_instruction(output_type, irb->current_basic_block);
    }

    for (size_t i = 0; i < source_node->data.asm_expr.input_list.length; i += 1) {
        IrInstruction *input_value = input_list[i];
        ir_ref_instruction(input_value, irb->current_basic_block);
    }

    return &instruction->base;
}

static IrInstruction *ir_build_asm_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction **input_list,
        IrInstruction **output_types, VariableTableEntry **output_vars, size_t return_count, bool has_side_effects)
{
    IrInstruction *new_instruction = ir_build_asm(irb, old_instruction->scope,
            old_instruction->source_node, input_list, output_types, output_vars, return_count, has_side_effects);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_compile_var(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *name) {
    IrInstructionCompileVar *instruction = ir_build_instruction<IrInstructionCompileVar>(irb, scope, source_node);
    instruction->name = name;

    ir_ref_instruction(name, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_size_of(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *type_value) {
    IrInstructionSizeOf *instruction = ir_build_instruction<IrInstructionSizeOf>(irb, scope, source_node);
    instruction->type_value = type_value;

    ir_ref_instruction(type_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_test_nonnull(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionTestNonNull *instruction = ir_build_instruction<IrInstructionTestNonNull>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_test_nonnull_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *value)
{
    IrInstruction *new_instruction = ir_build_test_nonnull(irb, old_instruction->scope,
            old_instruction->source_node, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_unwrap_maybe(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value,
        bool safety_check_on)
{
    IrInstructionUnwrapMaybe *instruction = ir_build_instruction<IrInstructionUnwrapMaybe>(irb, scope, source_node);
    instruction->value = value;
    instruction->safety_check_on = safety_check_on;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_unwrap_maybe_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *value, bool safety_check_on)
{
    IrInstruction *new_instruction = ir_build_unwrap_maybe(irb, old_instruction->scope, old_instruction->source_node,
            value, safety_check_on);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_maybe_wrap(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionMaybeWrap *instruction = ir_build_instruction<IrInstructionMaybeWrap>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_err_wrap_payload(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionErrWrapPayload *instruction = ir_build_instruction<IrInstructionErrWrapPayload>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_err_wrap_code(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionErrWrapCode *instruction = ir_build_instruction<IrInstructionErrWrapCode>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_clz(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionClz *instruction = ir_build_instruction<IrInstructionClz>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_clz_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *value) {
    IrInstruction *new_instruction = ir_build_clz(irb, old_instruction->scope, old_instruction->source_node, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_ctz(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionCtz *instruction = ir_build_instruction<IrInstructionCtz>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_ctz_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *value) {
    IrInstruction *new_instruction = ir_build_ctz(irb, old_instruction->scope, old_instruction->source_node, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_switch_br(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *target_value,
        IrBasicBlock *else_block, size_t case_count, IrInstructionSwitchBrCase *cases, IrInstruction *is_comptime)
{
    IrInstructionSwitchBr *instruction = ir_build_instruction<IrInstructionSwitchBr>(irb, scope, source_node);
    instruction->base.value.type = irb->codegen->builtin_types.entry_unreachable;
    instruction->base.value.special = ConstValSpecialStatic;
    instruction->target_value = target_value;
    instruction->else_block = else_block;
    instruction->case_count = case_count;
    instruction->cases = cases;
    instruction->is_comptime = is_comptime;

    ir_ref_instruction(target_value, irb->current_basic_block);
    if (is_comptime) ir_ref_instruction(is_comptime, irb->current_basic_block);
    ir_ref_bb(else_block);

    for (size_t i = 0; i < case_count; i += 1) {
        ir_ref_instruction(cases[i].value, irb->current_basic_block);
        ir_ref_bb(cases[i].block);
    }

    return &instruction->base;
}

static IrInstruction *ir_build_switch_br_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrInstruction *target_value, IrBasicBlock *else_block, size_t case_count,
        IrInstructionSwitchBrCase *cases, IrInstruction *is_comptime)
{
    IrInstruction *new_instruction = ir_build_switch_br(irb, old_instruction->scope, old_instruction->source_node,
            target_value, else_block, case_count, cases, is_comptime);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_switch_target(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target_value_ptr)
{
    IrInstructionSwitchTarget *instruction = ir_build_instruction<IrInstructionSwitchTarget>(irb, scope, source_node);
    instruction->target_value_ptr = target_value_ptr;

    ir_ref_instruction(target_value_ptr, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_switch_var(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target_value_ptr, IrInstruction *prong_value)
{
    IrInstructionSwitchVar *instruction = ir_build_instruction<IrInstructionSwitchVar>(irb, scope, source_node);
    instruction->target_value_ptr = target_value_ptr;
    instruction->prong_value = prong_value;

    ir_ref_instruction(target_value_ptr, irb->current_basic_block);
    ir_ref_instruction(prong_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_enum_tag(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionEnumTag *instruction = ir_build_instruction<IrInstructionEnumTag>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_enum_tag_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *value) {
    IrInstruction *new_instruction = ir_build_enum_tag(irb, old_instruction->scope,
            old_instruction->source_node, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_generated_code(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *value)
{
    IrInstructionGeneratedCode *instruction = ir_build_instruction<IrInstructionGeneratedCode>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_import(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *name) {
    IrInstructionImport *instruction = ir_build_instruction<IrInstructionImport>(irb, scope, source_node);
    instruction->name = name;

    ir_ref_instruction(name, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_array_len(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *array_value) {
    IrInstructionArrayLen *instruction = ir_build_instruction<IrInstructionArrayLen>(irb, scope, source_node);
    instruction->array_value = array_value;

    ir_ref_instruction(array_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_ref(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value,
        bool is_const, bool is_volatile)
{
    IrInstructionRef *instruction = ir_build_instruction<IrInstructionRef>(irb, scope, source_node);
    instruction->value = value;
    instruction->is_const = is_const;
    instruction->is_volatile = is_volatile;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_min_value(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionMinValue *instruction = ir_build_instruction<IrInstructionMinValue>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_max_value(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionMaxValue *instruction = ir_build_instruction<IrInstructionMaxValue>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_compile_err(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *msg) {
    IrInstructionCompileErr *instruction = ir_build_instruction<IrInstructionCompileErr>(irb, scope, source_node);
    instruction->msg = msg;

    ir_ref_instruction(msg, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_compile_log(IrBuilder *irb, Scope *scope, AstNode *source_node,
        size_t msg_count, IrInstruction **msg_list)
{
    IrInstructionCompileLog *instruction = ir_build_instruction<IrInstructionCompileLog>(irb, scope, source_node);
    instruction->msg_count = msg_count;
    instruction->msg_list = msg_list;

    for (size_t i = 0; i < msg_count; i += 1) {
        ir_ref_instruction(msg_list[i], irb->current_basic_block);
    }

    return &instruction->base;
}

static IrInstruction *ir_build_err_name(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionErrName *instruction = ir_build_instruction<IrInstructionErrName>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_err_name_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *value) {
    IrInstruction *new_instruction = ir_build_err_name(irb, old_instruction->scope,
            old_instruction->source_node, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_c_import(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionCImport *instruction = ir_build_instruction<IrInstructionCImport>(irb, scope, source_node);
    return &instruction->base;
}

static IrInstruction *ir_build_c_include(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *name) {
    IrInstructionCInclude *instruction = ir_build_instruction<IrInstructionCInclude>(irb, scope, source_node);
    instruction->name = name;

    ir_ref_instruction(name, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_c_define(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *name, IrInstruction *value) {
    IrInstructionCDefine *instruction = ir_build_instruction<IrInstructionCDefine>(irb, scope, source_node);
    instruction->name = name;
    instruction->value = value;

    ir_ref_instruction(name, irb->current_basic_block);
    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_c_undef(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *name) {
    IrInstructionCUndef *instruction = ir_build_instruction<IrInstructionCUndef>(irb, scope, source_node);
    instruction->name = name;

    ir_ref_instruction(name, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_embed_file(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *name) {
    IrInstructionEmbedFile *instruction = ir_build_instruction<IrInstructionEmbedFile>(irb, scope, source_node);
    instruction->name = name;

    ir_ref_instruction(name, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_cmpxchg(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *ptr,
    IrInstruction *cmp_value, IrInstruction *new_value, IrInstruction *success_order_value, IrInstruction *failure_order_value,
    AtomicOrder success_order, AtomicOrder failure_order)
{
    IrInstructionCmpxchg *instruction = ir_build_instruction<IrInstructionCmpxchg>(irb, scope, source_node);
    instruction->ptr = ptr;
    instruction->cmp_value = cmp_value;
    instruction->new_value = new_value;
    instruction->success_order_value = success_order_value;
    instruction->failure_order_value = failure_order_value;
    instruction->success_order = success_order;
    instruction->failure_order = failure_order;

    ir_ref_instruction(ptr, irb->current_basic_block);
    ir_ref_instruction(cmp_value, irb->current_basic_block);
    ir_ref_instruction(new_value, irb->current_basic_block);
    ir_ref_instruction(success_order_value, irb->current_basic_block);
    ir_ref_instruction(failure_order_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_cmpxchg_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *ptr,
    IrInstruction *cmp_value, IrInstruction *new_value, IrInstruction *success_order_value, IrInstruction *failure_order_value,
    AtomicOrder success_order, AtomicOrder failure_order)
{
    IrInstruction *new_instruction = ir_build_cmpxchg(irb, old_instruction->scope, old_instruction->source_node,
        ptr, cmp_value, new_value, success_order_value, failure_order_value, success_order, failure_order);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_fence(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *order_value, AtomicOrder order) {
    IrInstructionFence *instruction = ir_build_instruction<IrInstructionFence>(irb, scope, source_node);
    instruction->order_value = order_value;
    instruction->order = order;

    ir_ref_instruction(order_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_fence_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *order_value, AtomicOrder order) {
    IrInstruction *new_instruction = ir_build_fence(irb, old_instruction->scope, old_instruction->source_node, order_value, order);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_div_exact(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *op1, IrInstruction *op2) {
    IrInstructionDivExact *instruction = ir_build_instruction<IrInstructionDivExact>(irb, scope, source_node);
    instruction->op1 = op1;
    instruction->op2 = op2;

    ir_ref_instruction(op1, irb->current_basic_block);
    ir_ref_instruction(op2, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_div_exact_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *op1, IrInstruction *op2) {
    IrInstruction *new_instruction = ir_build_div_exact(irb, old_instruction->scope, old_instruction->source_node, op1, op2);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_truncate(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *dest_type, IrInstruction *target) {
    IrInstructionTruncate *instruction = ir_build_instruction<IrInstructionTruncate>(irb, scope, source_node);
    instruction->dest_type = dest_type;
    instruction->target = target;

    ir_ref_instruction(dest_type, irb->current_basic_block);
    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_truncate_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *dest_type, IrInstruction *target) {
    IrInstruction *new_instruction = ir_build_truncate(irb, old_instruction->scope, old_instruction->source_node, dest_type, target);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_int_type(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *is_signed, IrInstruction *bit_count) {
    IrInstructionIntType *instruction = ir_build_instruction<IrInstructionIntType>(irb, scope, source_node);
    instruction->is_signed = is_signed;
    instruction->bit_count = bit_count;

    ir_ref_instruction(is_signed, irb->current_basic_block);
    ir_ref_instruction(bit_count, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_bool_not(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionBoolNot *instruction = ir_build_instruction<IrInstructionBoolNot>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_bool_not_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *value) {
    IrInstruction *new_instruction = ir_build_bool_not(irb, old_instruction->scope, old_instruction->source_node, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_memset(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *dest_ptr, IrInstruction *byte, IrInstruction *count)
{
    IrInstructionMemset *instruction = ir_build_instruction<IrInstructionMemset>(irb, scope, source_node);
    instruction->dest_ptr = dest_ptr;
    instruction->byte = byte;
    instruction->count = count;

    ir_ref_instruction(dest_ptr, irb->current_basic_block);
    ir_ref_instruction(byte, irb->current_basic_block);
    ir_ref_instruction(count, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_memset_from(IrBuilder *irb, IrInstruction *old_instruction,
    IrInstruction *dest_ptr, IrInstruction *byte, IrInstruction *count)
{
    IrInstruction *new_instruction = ir_build_memset(irb, old_instruction->scope, old_instruction->source_node, dest_ptr, byte, count);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_memcpy(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *dest_ptr, IrInstruction *src_ptr, IrInstruction *count)
{
    IrInstructionMemcpy *instruction = ir_build_instruction<IrInstructionMemcpy>(irb, scope, source_node);
    instruction->dest_ptr = dest_ptr;
    instruction->src_ptr = src_ptr;
    instruction->count = count;

    ir_ref_instruction(dest_ptr, irb->current_basic_block);
    ir_ref_instruction(src_ptr, irb->current_basic_block);
    ir_ref_instruction(count, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_memcpy_from(IrBuilder *irb, IrInstruction *old_instruction,
    IrInstruction *dest_ptr, IrInstruction *src_ptr, IrInstruction *count)
{
    IrInstruction *new_instruction = ir_build_memcpy(irb, old_instruction->scope, old_instruction->source_node, dest_ptr, src_ptr, count);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_slice(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *ptr, IrInstruction *start, IrInstruction *end, bool is_const, bool safety_check_on)
{
    IrInstructionSlice *instruction = ir_build_instruction<IrInstructionSlice>(irb, scope, source_node);
    instruction->ptr = ptr;
    instruction->start = start;
    instruction->end = end;
    instruction->is_const = is_const;
    instruction->safety_check_on = safety_check_on;

    ir_ref_instruction(ptr, irb->current_basic_block);
    ir_ref_instruction(start, irb->current_basic_block);
    if (end) ir_ref_instruction(end, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_slice_from(IrBuilder *irb, IrInstruction *old_instruction,
    IrInstruction *ptr, IrInstruction *start, IrInstruction *end, bool is_const, bool safety_check_on)
{
    IrInstruction *new_instruction = ir_build_slice(irb, old_instruction->scope,
            old_instruction->source_node, ptr, start, end, is_const, safety_check_on);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_member_count(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *container) {
    IrInstructionMemberCount *instruction = ir_build_instruction<IrInstructionMemberCount>(irb, scope, source_node);
    instruction->container = container;

    ir_ref_instruction(container, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_breakpoint(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionBreakpoint *instruction = ir_build_instruction<IrInstructionBreakpoint>(irb, scope, source_node);
    return &instruction->base;
}

static IrInstruction *ir_build_breakpoint_from(IrBuilder *irb, IrInstruction *old_instruction) {
    IrInstruction *new_instruction = ir_build_breakpoint(irb, old_instruction->scope, old_instruction->source_node);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_return_address(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionReturnAddress *instruction = ir_build_instruction<IrInstructionReturnAddress>(irb, scope, source_node);
    return &instruction->base;
}

static IrInstruction *ir_build_return_address_from(IrBuilder *irb, IrInstruction *old_instruction) {
    IrInstruction *new_instruction = ir_build_return_address(irb, old_instruction->scope, old_instruction->source_node);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_frame_address(IrBuilder *irb, Scope *scope, AstNode *source_node) {
    IrInstructionFrameAddress *instruction = ir_build_instruction<IrInstructionFrameAddress>(irb, scope, source_node);
    return &instruction->base;
}

static IrInstruction *ir_build_frame_address_from(IrBuilder *irb, IrInstruction *old_instruction) {
    IrInstruction *new_instruction = ir_build_frame_address(irb, old_instruction->scope, old_instruction->source_node);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_overflow_op(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrOverflowOp op, IrInstruction *type_value, IrInstruction *op1, IrInstruction *op2,
        IrInstruction *result_ptr, TypeTableEntry *result_ptr_type)
{
    IrInstructionOverflowOp *instruction = ir_build_instruction<IrInstructionOverflowOp>(irb, scope, source_node);
    instruction->op = op;
    instruction->type_value = type_value;
    instruction->op1 = op1;
    instruction->op2 = op2;
    instruction->result_ptr = result_ptr;
    instruction->result_ptr_type = result_ptr_type;

    ir_ref_instruction(type_value, irb->current_basic_block);
    ir_ref_instruction(op1, irb->current_basic_block);
    ir_ref_instruction(op2, irb->current_basic_block);
    ir_ref_instruction(result_ptr, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_overflow_op_from(IrBuilder *irb, IrInstruction *old_instruction,
        IrOverflowOp op, IrInstruction *type_value, IrInstruction *op1, IrInstruction *op2,
        IrInstruction *result_ptr, TypeTableEntry *result_ptr_type)
{
    IrInstruction *new_instruction = ir_build_overflow_op(irb, old_instruction->scope, old_instruction->source_node,
            op, type_value, op1, op2, result_ptr, result_ptr_type);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_alignof(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *type_value) {
    IrInstructionAlignOf *instruction = ir_build_instruction<IrInstructionAlignOf>(irb, scope, source_node);
    instruction->type_value = type_value;

    ir_ref_instruction(type_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_test_err(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *value)
{
    IrInstructionTestErr *instruction = ir_build_instruction<IrInstructionTestErr>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_test_err_from(IrBuilder *irb, IrInstruction *old_instruction, IrInstruction *value) {
    IrInstruction *new_instruction = ir_build_test_err(irb, old_instruction->scope, old_instruction->source_node,
            value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_unwrap_err_code(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *value)
{
    IrInstructionUnwrapErrCode *instruction = ir_build_instruction<IrInstructionUnwrapErrCode>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_unwrap_err_code_from(IrBuilder *irb, IrInstruction *old_instruction,
    IrInstruction *value)
{
    IrInstruction *new_instruction = ir_build_unwrap_err_code(irb, old_instruction->scope,
        old_instruction->source_node, value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_unwrap_err_payload(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction *value, bool safety_check_on)
{
    IrInstructionUnwrapErrPayload *instruction = ir_build_instruction<IrInstructionUnwrapErrPayload>(irb, scope, source_node);
    instruction->value = value;
    instruction->safety_check_on = safety_check_on;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_unwrap_err_payload_from(IrBuilder *irb, IrInstruction *old_instruction,
    IrInstruction *value, bool safety_check_on)
{
    IrInstruction *new_instruction = ir_build_unwrap_err_payload(irb, old_instruction->scope,
        old_instruction->source_node, value, safety_check_on);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_fn_proto(IrBuilder *irb, Scope *scope, AstNode *source_node,
    IrInstruction **param_types, IrInstruction *return_type)
{
    IrInstructionFnProto *instruction = ir_build_instruction<IrInstructionFnProto>(irb, scope, source_node);
    instruction->param_types = param_types;
    instruction->return_type = return_type;

    assert(source_node->type == NodeTypeFnProto);
    for (size_t i = 0; i < source_node->data.fn_proto.params.length; i += 1) {
        ir_ref_instruction(param_types[i], irb->current_basic_block);
    }
    ir_ref_instruction(return_type, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_test_comptime(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *value) {
    IrInstructionTestComptime *instruction = ir_build_instruction<IrInstructionTestComptime>(irb, scope, source_node);
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_init_enum(IrBuilder *irb, Scope *scope, AstNode *source_node,
        TypeTableEntry *enum_type, TypeEnumField *field, IrInstruction *init_value)
{
    IrInstructionInitEnum *instruction = ir_build_instruction<IrInstructionInitEnum>(irb, scope, source_node);
    instruction->enum_type = enum_type;
    instruction->field = field;
    instruction->init_value = init_value;

    ir_ref_instruction(init_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_init_enum_from(IrBuilder *irb, IrInstruction *old_instruction,
    TypeTableEntry *enum_type, TypeEnumField *field, IrInstruction *init_value)
{
    IrInstruction *new_instruction = ir_build_init_enum(irb, old_instruction->scope, old_instruction->source_node,
            enum_type, field, init_value);
    ir_link_new_instruction(new_instruction, old_instruction);
    return new_instruction;
}

static IrInstruction *ir_build_ptr_cast(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *dest_type, IrInstruction *ptr)
{
    IrInstructionPtrCast *instruction = ir_build_instruction<IrInstructionPtrCast>(
            irb, scope, source_node);
    instruction->dest_type = dest_type;
    instruction->ptr = ptr;

    if (dest_type) ir_ref_instruction(dest_type, irb->current_basic_block);
    ir_ref_instruction(ptr, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_widen_or_shorten(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target)
{
    IrInstructionWidenOrShorten *instruction = ir_build_instruction<IrInstructionWidenOrShorten>(
            irb, scope, source_node);
    instruction->target = target;

    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_int_to_ptr(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *dest_type, IrInstruction *target)
{
    IrInstructionIntToPtr *instruction = ir_build_instruction<IrInstructionIntToPtr>(
            irb, scope, source_node);
    instruction->dest_type = dest_type;
    instruction->target = target;

    if (dest_type) ir_ref_instruction(dest_type, irb->current_basic_block);
    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_ptr_to_int(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target)
{
    IrInstructionPtrToInt *instruction = ir_build_instruction<IrInstructionPtrToInt>(
            irb, scope, source_node);
    instruction->target = target;

    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_int_to_enum(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target)
{
    IrInstructionIntToEnum *instruction = ir_build_instruction<IrInstructionIntToEnum>(
            irb, scope, source_node);
    instruction->target = target;

    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_int_to_err(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target)
{
    IrInstructionIntToErr *instruction = ir_build_instruction<IrInstructionIntToErr>(
            irb, scope, source_node);
    instruction->target = target;

    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_err_to_int(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target)
{
    IrInstructionErrToInt *instruction = ir_build_instruction<IrInstructionErrToInt>(
            irb, scope, source_node);
    instruction->target = target;

    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_check_switch_prongs(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target_value, IrInstructionCheckSwitchProngsRange *ranges, size_t range_count)
{
    IrInstructionCheckSwitchProngs *instruction = ir_build_instruction<IrInstructionCheckSwitchProngs>(
            irb, scope, source_node);
    instruction->target_value = target_value;
    instruction->ranges = ranges;
    instruction->range_count = range_count;

    ir_ref_instruction(target_value, irb->current_basic_block);
    for (size_t i = 0; i < range_count; i += 1) {
        ir_ref_instruction(ranges[i].start, irb->current_basic_block);
        ir_ref_instruction(ranges[i].end, irb->current_basic_block);
    }

    return &instruction->base;
}

static IrInstruction *ir_build_test_type(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *type_value, TypeTableEntryId type_id)
{
    IrInstructionTestType *instruction = ir_build_instruction<IrInstructionTestType>(
            irb, scope, source_node);
    instruction->type_value = type_value;
    instruction->type_id = type_id;

    ir_ref_instruction(type_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_type_name(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *type_value)
{
    IrInstructionTypeName *instruction = ir_build_instruction<IrInstructionTypeName>(
            irb, scope, source_node);
    instruction->type_value = type_value;

    ir_ref_instruction(type_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_can_implicit_cast(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *type_value, IrInstruction *target_value)
{
    IrInstructionCanImplicitCast *instruction = ir_build_instruction<IrInstructionCanImplicitCast>(
            irb, scope, source_node);
    instruction->type_value = type_value;
    instruction->target_value = target_value;

    ir_ref_instruction(type_value, irb->current_basic_block);
    ir_ref_instruction(target_value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_set_global_align(IrBuilder *irb, Scope *scope, AstNode *source_node,
        Tld *tld, IrInstruction *value)
{
    IrInstructionSetGlobalAlign *instruction = ir_build_instruction<IrInstructionSetGlobalAlign>(
            irb, scope, source_node);
    instruction->tld = tld;
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_set_global_section(IrBuilder *irb, Scope *scope, AstNode *source_node,
        Tld *tld, IrInstruction *value)
{
    IrInstructionSetGlobalSection *instruction = ir_build_instruction<IrInstructionSetGlobalSection>(
            irb, scope, source_node);
    instruction->tld = tld;
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_set_global_linkage(IrBuilder *irb, Scope *scope, AstNode *source_node,
        Tld *tld, IrInstruction *value)
{
    IrInstructionSetGlobalLinkage *instruction = ir_build_instruction<IrInstructionSetGlobalLinkage>(
            irb, scope, source_node);
    instruction->tld = tld;
    instruction->value = value;

    ir_ref_instruction(value, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_decl_ref(IrBuilder *irb, Scope *scope, AstNode *source_node,
        Tld *tld, LVal lval)
{
    IrInstructionDeclRef *instruction = ir_build_instruction<IrInstructionDeclRef>(
            irb, scope, source_node);
    instruction->tld = tld;
    instruction->lval = lval;

    return &instruction->base;
}

static IrInstruction *ir_build_panic(IrBuilder *irb, Scope *scope, AstNode *source_node, IrInstruction *msg) {
    IrInstructionPanic *instruction = ir_build_instruction<IrInstructionPanic>(irb, scope, source_node);
    instruction->base.value.special = ConstValSpecialStatic;
    instruction->base.value.type = irb->codegen->builtin_types.entry_unreachable;
    instruction->msg = msg;

    ir_ref_instruction(msg, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_enum_tag_name(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *target)
{
    IrInstructionEnumTagName *instruction = ir_build_instruction<IrInstructionEnumTagName>(irb, scope, source_node);
    instruction->target = target;

    ir_ref_instruction(target, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_build_set_fn_ref_inline(IrBuilder *irb, Scope *scope, AstNode *source_node,
        IrInstruction *fn_ref)
{
    IrInstructionSetFnRefInline *instruction = ir_build_instruction<IrInstructionSetFnRefInline>(
            irb, scope, source_node);
    instruction->fn_ref = fn_ref;

    ir_ref_instruction(fn_ref, irb->current_basic_block);

    return &instruction->base;
}

static IrInstruction *ir_instruction_br_get_dep(IrInstructionBr *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_condbr_get_dep(IrInstructionCondBr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->condition;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_switchbr_get_dep(IrInstructionSwitchBr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target_value;
    }
    size_t case_index = index - 2;
    if (case_index < instruction->case_count) return instruction->cases[case_index].value;
    return nullptr;
}

static IrInstruction *ir_instruction_switchvar_get_dep(IrInstructionSwitchVar *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target_value_ptr;
        case 1: return instruction->prong_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_switchtarget_get_dep(IrInstructionSwitchTarget *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target_value_ptr;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_phi_get_dep(IrInstructionPhi *instruction, size_t index) {
    if (index < instruction->incoming_count) return instruction->incoming_values[index];
    return nullptr;
}

static IrInstruction *ir_instruction_unop_get_dep(IrInstructionUnOp *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_binop_get_dep(IrInstructionBinOp *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->op1;
        case 1: return instruction->op2;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_declvar_get_dep(IrInstructionDeclVar *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->init_value;
        case 1: return instruction->var_type;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_loadptr_get_dep(IrInstructionLoadPtr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->ptr;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_storeptr_get_dep(IrInstructionStorePtr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->ptr;
        case 1: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_fieldptr_get_dep(IrInstructionFieldPtr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->container_ptr;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_structfieldptr_get_dep(IrInstructionStructFieldPtr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->struct_ptr;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_enumfieldptr_get_dep(IrInstructionEnumFieldPtr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->enum_ptr;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_elemptr_get_dep(IrInstructionElemPtr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->array_ptr;
        case 1: return instruction->elem_index;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_varptr_get_dep(IrInstructionVarPtr *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_call_get_dep(IrInstructionCall *instruction, size_t index) {
    if (index == 0) return instruction->fn_ref;
    size_t arg_index = index - 1;
    if (arg_index < instruction->arg_count) return instruction->args[arg_index];
    return nullptr;
}

static IrInstruction *ir_instruction_const_get_dep(IrInstructionConst *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_return_get_dep(IrInstructionReturn *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_cast_get_dep(IrInstructionCast *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_containerinitlist_get_dep(IrInstructionContainerInitList *instruction,
        size_t index)
{
    if (index == 0) return instruction->container_type;
    size_t item_index = index - 1;
    if (item_index < instruction->item_count) return instruction->items[item_index];
    return nullptr;
}

static IrInstruction *ir_instruction_containerinitfields_get_dep(IrInstructionContainerInitFields *instruction,
        size_t index)
{
    if (index == 0) return instruction->container_type;
    size_t field_index = index - 1;
    if (field_index < instruction->field_count) return instruction->fields[field_index].value;
    return nullptr;
}

static IrInstruction *ir_instruction_structinit_get_dep(IrInstructionStructInit *instruction, size_t index) {
    if (index < instruction->field_count) return instruction->fields[index].value;
    return nullptr;
}

static IrInstruction *ir_instruction_unreachable_get_dep(IrInstructionUnreachable *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_typeof_get_dep(IrInstructionTypeOf *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_toptrtype_get_dep(IrInstructionToPtrType *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_ptrtypechild_get_dep(IrInstructionPtrTypeChild *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_setdebugsafety_get_dep(IrInstructionSetDebugSafety *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->scope_value;
        case 1: return instruction->debug_safety_on;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_arraytype_get_dep(IrInstructionArrayType *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->size;
        case 1: return instruction->child_type;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_slicetype_get_dep(IrInstructionSliceType *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->child_type;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_asm_get_dep(IrInstructionAsm *instruction, size_t index) {
    AstNode *asm_node = instruction->base.source_node;
    if (index < asm_node->data.asm_expr.output_list.length) return instruction->output_types[index];
    size_t input_index = index - asm_node->data.asm_expr.output_list.length;
    if (input_index < asm_node->data.asm_expr.input_list.length) return instruction->input_list[input_index];
    return nullptr;
}

static IrInstruction *ir_instruction_compilevar_get_dep(IrInstructionCompileVar *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->name;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_sizeof_get_dep(IrInstructionSizeOf *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->type_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_testnonnull_get_dep(IrInstructionTestNonNull *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_unwrapmaybe_get_dep(IrInstructionUnwrapMaybe *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_maybewrap_get_dep(IrInstructionMaybeWrap *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_enumtag_get_dep(IrInstructionEnumTag *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_clz_get_dep(IrInstructionClz *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_ctz_get_dep(IrInstructionCtz *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_generatedcode_get_dep(IrInstructionGeneratedCode *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_import_get_dep(IrInstructionImport *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->name;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_cimport_get_dep(IrInstructionCImport *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_cinclude_get_dep(IrInstructionCInclude *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->name;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_cdefine_get_dep(IrInstructionCDefine *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->name;
        case 1: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_cundef_get_dep(IrInstructionCUndef *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->name;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_arraylen_get_dep(IrInstructionArrayLen *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->array_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_ref_get_dep(IrInstructionRef *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_minvalue_get_dep(IrInstructionMinValue *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_maxvalue_get_dep(IrInstructionMaxValue *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_compileerr_get_dep(IrInstructionCompileErr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->msg;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_compilelog_get_dep(IrInstructionCompileLog *instruction, size_t index) {
    if (index < instruction->msg_count)
        return instruction->msg_list[index];
    return nullptr;
}

static IrInstruction *ir_instruction_errname_get_dep(IrInstructionErrName *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_embedfile_get_dep(IrInstructionEmbedFile *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->name;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_cmpxchg_get_dep(IrInstructionCmpxchg *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->ptr;
        case 1: return instruction->cmp_value;
        case 2: return instruction->new_value;
        case 3: return instruction->success_order_value;
        case 4: return instruction->failure_order_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_fence_get_dep(IrInstructionFence *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->order_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_divexact_get_dep(IrInstructionDivExact *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->op1;
        case 1: return instruction->op2;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_truncate_get_dep(IrInstructionTruncate *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->dest_type;
        case 1: return instruction->target;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_inttype_get_dep(IrInstructionIntType *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->is_signed;
        case 1: return instruction->bit_count;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_boolnot_get_dep(IrInstructionBoolNot *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_memset_get_dep(IrInstructionMemset *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->dest_ptr;
        case 1: return instruction->byte;
        case 2: return instruction->count;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_memcpy_get_dep(IrInstructionMemcpy *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->dest_ptr;
        case 1: return instruction->src_ptr;
        case 2: return instruction->count;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_slice_get_dep(IrInstructionSlice *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->ptr;
        case 1: return instruction->start;
        case 2: return instruction->end;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_membercount_get_dep(IrInstructionMemberCount *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->container;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_breakpoint_get_dep(IrInstructionBreakpoint *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_returnaddress_get_dep(IrInstructionReturnAddress *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_frameaddress_get_dep(IrInstructionFrameAddress *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_alignof_get_dep(IrInstructionAlignOf *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->type_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_overflowop_get_dep(IrInstructionOverflowOp *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->type_value;
        case 1: return instruction->op1;
        case 2: return instruction->op2;
        case 3: return instruction->result_ptr;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_testerr_get_dep(IrInstructionTestErr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_unwraperrcode_get_dep(IrInstructionUnwrapErrCode *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_unwraperrpayload_get_dep(IrInstructionUnwrapErrPayload *instruction,
        size_t index)
{
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_errwrapcode_get_dep(IrInstructionErrWrapCode *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_errwrappayload_get_dep(IrInstructionErrWrapPayload *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_fnproto_get_dep(IrInstructionFnProto *instruction, size_t index) {
    if (index == 0) return instruction->return_type;
    size_t param_index = index - 1;
    if (param_index < instruction->base.source_node->data.fn_proto.params.length) {
        return instruction->param_types[param_index];
    }
    return nullptr;
}

static IrInstruction *ir_instruction_testcomptime_get_dep(IrInstructionTestComptime *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_initenum_get_dep(IrInstructionInitEnum *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->init_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_ptrcast_get_dep(IrInstructionPtrCast *instruction,
        size_t index)
{
    switch (index) {
        case 0: return instruction->ptr;
        case 1: return instruction->dest_type;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_widenorshorten_get_dep(IrInstructionWidenOrShorten *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_inttoptr_get_dep(IrInstructionIntToPtr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target;
        case 1: return instruction->dest_type;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_ptrtoint_get_dep(IrInstructionPtrToInt *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_inttoenum_get_dep(IrInstructionIntToEnum *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_inttoerr_get_dep(IrInstructionIntToErr *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_errtoint_get_dep(IrInstructionErrToInt *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_checkswitchprongs_get_dep(IrInstructionCheckSwitchProngs *instruction,
        size_t index)
{
    if (index == 0) return instruction->target_value;
    size_t range_index = index - 1;
    if (range_index < instruction->range_count * 2) {
        IrInstructionCheckSwitchProngsRange *range = &instruction->ranges[range_index / 2];
        return (range_index % 2 == 0) ? range->start : range->end;
    }
    return nullptr;
}

static IrInstruction *ir_instruction_testtype_get_dep(IrInstructionTestType *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->type_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_typename_get_dep(IrInstructionTypeName *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->type_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_canimplicitcast_get_dep(IrInstructionCanImplicitCast *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->type_value;
        case 1: return instruction->target_value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_setglobalalign_get_dep(IrInstructionSetGlobalAlign *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_setglobalsection_get_dep(IrInstructionSetGlobalSection *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_setgloballinkage_get_dep(IrInstructionSetGlobalLinkage *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->value;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_declref_get_dep(IrInstructionDeclRef *instruction, size_t index) {
    return nullptr;
}

static IrInstruction *ir_instruction_panic_get_dep(IrInstructionPanic *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->msg;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_enumtagname_get_dep(IrInstructionEnumTagName *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->target;
        default: return nullptr;
    }
}

static IrInstruction *ir_instruction_setfnrefinline_get_dep(IrInstructionSetFnRefInline *instruction, size_t index) {
    switch (index) {
        case 0: return instruction->fn_ref;
        default: return nullptr;
    }
}


static IrInstruction *ir_instruction_get_dep(IrInstruction *instruction, size_t index) {
    switch (instruction->id) {
        case IrInstructionIdInvalid:
            zig_unreachable();
        case IrInstructionIdBr:
            return ir_instruction_br_get_dep((IrInstructionBr *) instruction, index);
        case IrInstructionIdCondBr:
            return ir_instruction_condbr_get_dep((IrInstructionCondBr *) instruction, index);
        case IrInstructionIdSwitchBr:
            return ir_instruction_switchbr_get_dep((IrInstructionSwitchBr *) instruction, index);
        case IrInstructionIdSwitchVar:
            return ir_instruction_switchvar_get_dep((IrInstructionSwitchVar *) instruction, index);
        case IrInstructionIdSwitchTarget:
            return ir_instruction_switchtarget_get_dep((IrInstructionSwitchTarget *) instruction, index);
        case IrInstructionIdPhi:
            return ir_instruction_phi_get_dep((IrInstructionPhi *) instruction, index);
        case IrInstructionIdUnOp:
            return ir_instruction_unop_get_dep((IrInstructionUnOp *) instruction, index);
        case IrInstructionIdBinOp:
            return ir_instruction_binop_get_dep((IrInstructionBinOp *) instruction, index);
        case IrInstructionIdDeclVar:
            return ir_instruction_declvar_get_dep((IrInstructionDeclVar *) instruction, index);
        case IrInstructionIdLoadPtr:
            return ir_instruction_loadptr_get_dep((IrInstructionLoadPtr *) instruction, index);
        case IrInstructionIdStorePtr:
            return ir_instruction_storeptr_get_dep((IrInstructionStorePtr *) instruction, index);
        case IrInstructionIdFieldPtr:
            return ir_instruction_fieldptr_get_dep((IrInstructionFieldPtr *) instruction, index);
        case IrInstructionIdStructFieldPtr:
            return ir_instruction_structfieldptr_get_dep((IrInstructionStructFieldPtr *) instruction, index);
        case IrInstructionIdEnumFieldPtr:
            return ir_instruction_enumfieldptr_get_dep((IrInstructionEnumFieldPtr *) instruction, index);
        case IrInstructionIdElemPtr:
            return ir_instruction_elemptr_get_dep((IrInstructionElemPtr *) instruction, index);
        case IrInstructionIdVarPtr:
            return ir_instruction_varptr_get_dep((IrInstructionVarPtr *) instruction, index);
        case IrInstructionIdCall:
            return ir_instruction_call_get_dep((IrInstructionCall *) instruction, index);
        case IrInstructionIdConst:
            return ir_instruction_const_get_dep((IrInstructionConst *) instruction, index);
        case IrInstructionIdReturn:
            return ir_instruction_return_get_dep((IrInstructionReturn *) instruction, index);
        case IrInstructionIdCast:
            return ir_instruction_cast_get_dep((IrInstructionCast *) instruction, index);
        case IrInstructionIdContainerInitList:
            return ir_instruction_containerinitlist_get_dep((IrInstructionContainerInitList *) instruction, index);
        case IrInstructionIdContainerInitFields:
            return ir_instruction_containerinitfields_get_dep((IrInstructionContainerInitFields *) instruction, index);
        case IrInstructionIdStructInit:
            return ir_instruction_structinit_get_dep((IrInstructionStructInit *) instruction, index);
        case IrInstructionIdUnreachable:
            return ir_instruction_unreachable_get_dep((IrInstructionUnreachable *) instruction, index);
        case IrInstructionIdTypeOf:
            return ir_instruction_typeof_get_dep((IrInstructionTypeOf *) instruction, index);
        case IrInstructionIdToPtrType:
            return ir_instruction_toptrtype_get_dep((IrInstructionToPtrType *) instruction, index);
        case IrInstructionIdPtrTypeChild:
            return ir_instruction_ptrtypechild_get_dep((IrInstructionPtrTypeChild *) instruction, index);
        case IrInstructionIdSetDebugSafety:
            return ir_instruction_setdebugsafety_get_dep((IrInstructionSetDebugSafety *) instruction, index);
        case IrInstructionIdArrayType:
            return ir_instruction_arraytype_get_dep((IrInstructionArrayType *) instruction, index);
        case IrInstructionIdSliceType:
            return ir_instruction_slicetype_get_dep((IrInstructionSliceType *) instruction, index);
        case IrInstructionIdAsm:
            return ir_instruction_asm_get_dep((IrInstructionAsm *) instruction, index);
        case IrInstructionIdCompileVar:
            return ir_instruction_compilevar_get_dep((IrInstructionCompileVar *) instruction, index);
        case IrInstructionIdSizeOf:
            return ir_instruction_sizeof_get_dep((IrInstructionSizeOf *) instruction, index);
        case IrInstructionIdTestNonNull:
            return ir_instruction_testnonnull_get_dep((IrInstructionTestNonNull *) instruction, index);
        case IrInstructionIdUnwrapMaybe:
            return ir_instruction_unwrapmaybe_get_dep((IrInstructionUnwrapMaybe *) instruction, index);
        case IrInstructionIdMaybeWrap:
            return ir_instruction_maybewrap_get_dep((IrInstructionMaybeWrap *) instruction, index);
        case IrInstructionIdEnumTag:
            return ir_instruction_enumtag_get_dep((IrInstructionEnumTag *) instruction, index);
        case IrInstructionIdClz:
            return ir_instruction_clz_get_dep((IrInstructionClz *) instruction, index);
        case IrInstructionIdCtz:
            return ir_instruction_ctz_get_dep((IrInstructionCtz *) instruction, index);
        case IrInstructionIdGeneratedCode:
            return ir_instruction_generatedcode_get_dep((IrInstructionGeneratedCode *) instruction, index);
        case IrInstructionIdImport:
            return ir_instruction_import_get_dep((IrInstructionImport *) instruction, index);
        case IrInstructionIdCImport:
            return ir_instruction_cimport_get_dep((IrInstructionCImport *) instruction, index);
        case IrInstructionIdCInclude:
            return ir_instruction_cinclude_get_dep((IrInstructionCInclude *) instruction, index);
        case IrInstructionIdCDefine:
            return ir_instruction_cdefine_get_dep((IrInstructionCDefine *) instruction, index);
        case IrInstructionIdCUndef:
            return ir_instruction_cundef_get_dep((IrInstructionCUndef *) instruction, index);
        case IrInstructionIdArrayLen:
            return ir_instruction_arraylen_get_dep((IrInstructionArrayLen *) instruction, index);
        case IrInstructionIdRef:
            return ir_instruction_ref_get_dep((IrInstructionRef *) instruction, index);
        case IrInstructionIdMinValue:
            return ir_instruction_minvalue_get_dep((IrInstructionMinValue *) instruction, index);
        case IrInstructionIdMaxValue:
            return ir_instruction_maxvalue_get_dep((IrInstructionMaxValue *) instruction, index);
        case IrInstructionIdCompileErr:
            return ir_instruction_compileerr_get_dep((IrInstructionCompileErr *) instruction, index);
        case IrInstructionIdCompileLog:
            return ir_instruction_compilelog_get_dep((IrInstructionCompileLog *) instruction, index);
        case IrInstructionIdErrName:
            return ir_instruction_errname_get_dep((IrInstructionErrName *) instruction, index);
        case IrInstructionIdEmbedFile:
            return ir_instruction_embedfile_get_dep((IrInstructionEmbedFile *) instruction, index);
        case IrInstructionIdCmpxchg:
            return ir_instruction_cmpxchg_get_dep((IrInstructionCmpxchg *) instruction, index);
        case IrInstructionIdFence:
            return ir_instruction_fence_get_dep((IrInstructionFence *) instruction, index);
        case IrInstructionIdDivExact:
            return ir_instruction_divexact_get_dep((IrInstructionDivExact *) instruction, index);
        case IrInstructionIdTruncate:
            return ir_instruction_truncate_get_dep((IrInstructionTruncate *) instruction, index);
        case IrInstructionIdIntType:
            return ir_instruction_inttype_get_dep((IrInstructionIntType *) instruction, index);
        case IrInstructionIdBoolNot:
            return ir_instruction_boolnot_get_dep((IrInstructionBoolNot *) instruction, index);
        case IrInstructionIdMemset:
            return ir_instruction_memset_get_dep((IrInstructionMemset *) instruction, index);
        case IrInstructionIdMemcpy:
            return ir_instruction_memcpy_get_dep((IrInstructionMemcpy *) instruction, index);
        case IrInstructionIdSlice:
            return ir_instruction_slice_get_dep((IrInstructionSlice *) instruction, index);
        case IrInstructionIdMemberCount:
            return ir_instruction_membercount_get_dep((IrInstructionMemberCount *) instruction, index);
        case IrInstructionIdBreakpoint:
            return ir_instruction_breakpoint_get_dep((IrInstructionBreakpoint *) instruction, index);
        case IrInstructionIdReturnAddress:
            return ir_instruction_returnaddress_get_dep((IrInstructionReturnAddress *) instruction, index);
        case IrInstructionIdFrameAddress:
            return ir_instruction_frameaddress_get_dep((IrInstructionFrameAddress *) instruction, index);
        case IrInstructionIdAlignOf:
            return ir_instruction_alignof_get_dep((IrInstructionAlignOf *) instruction, index);
        case IrInstructionIdOverflowOp:
            return ir_instruction_overflowop_get_dep((IrInstructionOverflowOp *) instruction, index);
        case IrInstructionIdTestErr:
            return ir_instruction_testerr_get_dep((IrInstructionTestErr *) instruction, index);
        case IrInstructionIdUnwrapErrCode:
            return ir_instruction_unwraperrcode_get_dep((IrInstructionUnwrapErrCode *) instruction, index);
        case IrInstructionIdUnwrapErrPayload:
            return ir_instruction_unwraperrpayload_get_dep((IrInstructionUnwrapErrPayload *) instruction, index);
        case IrInstructionIdErrWrapCode:
            return ir_instruction_errwrapcode_get_dep((IrInstructionErrWrapCode *) instruction, index);
        case IrInstructionIdErrWrapPayload:
            return ir_instruction_errwrappayload_get_dep((IrInstructionErrWrapPayload *) instruction, index);
        case IrInstructionIdFnProto:
            return ir_instruction_fnproto_get_dep((IrInstructionFnProto *) instruction, index);
        case IrInstructionIdTestComptime:
            return ir_instruction_testcomptime_get_dep((IrInstructionTestComptime *) instruction, index);
        case IrInstructionIdInitEnum:
            return ir_instruction_initenum_get_dep((IrInstructionInitEnum *) instruction, index);
        case IrInstructionIdPtrCast:
            return ir_instruction_ptrcast_get_dep((IrInstructionPtrCast *) instruction, index);
        case IrInstructionIdWidenOrShorten:
            return ir_instruction_widenorshorten_get_dep((IrInstructionWidenOrShorten *) instruction, index);
        case IrInstructionIdIntToPtr:
            return ir_instruction_inttoptr_get_dep((IrInstructionIntToPtr *) instruction, index);
        case IrInstructionIdPtrToInt:
            return ir_instruction_ptrtoint_get_dep((IrInstructionPtrToInt *) instruction, index);
        case IrInstructionIdIntToEnum:
            return ir_instruction_inttoenum_get_dep((IrInstructionIntToEnum *) instruction, index);
        case IrInstructionIdIntToErr:
            return ir_instruction_inttoerr_get_dep((IrInstructionIntToErr *) instruction, index);
        case IrInstructionIdErrToInt:
            return ir_instruction_errtoint_get_dep((IrInstructionErrToInt *) instruction, index);
        case IrInstructionIdCheckSwitchProngs:
            return ir_instruction_checkswitchprongs_get_dep((IrInstructionCheckSwitchProngs *) instruction, index);
        case IrInstructionIdTestType:
            return ir_instruction_testtype_get_dep((IrInstructionTestType *) instruction, index);
        case IrInstructionIdTypeName:
            return ir_instruction_typename_get_dep((IrInstructionTypeName *) instruction, index);
        case IrInstructionIdCanImplicitCast:
            return ir_instruction_canimplicitcast_get_dep((IrInstructionCanImplicitCast *) instruction, index);
        case IrInstructionIdSetGlobalAlign:
            return ir_instruction_setglobalalign_get_dep((IrInstructionSetGlobalAlign *) instruction, index);
        case IrInstructionIdSetGlobalSection:
            return ir_instruction_setglobalsection_get_dep((IrInstructionSetGlobalSection *) instruction, index);
        case IrInstructionIdSetGlobalLinkage:
            return ir_instruction_setgloballinkage_get_dep((IrInstructionSetGlobalLinkage *) instruction, index);
        case IrInstructionIdDeclRef:
            return ir_instruction_declref_get_dep((IrInstructionDeclRef *) instruction, index);
        case IrInstructionIdPanic:
            return ir_instruction_panic_get_dep((IrInstructionPanic *) instruction, index);
        case IrInstructionIdEnumTagName:
            return ir_instruction_enumtagname_get_dep((IrInstructionEnumTagName *) instruction, index);
        case IrInstructionIdSetFnRefInline:
            return ir_instruction_setfnrefinline_get_dep((IrInstructionSetFnRefInline *) instruction, index);
    }
    zig_unreachable();
}

static void ir_count_defers(IrBuilder *irb, Scope *inner_scope, Scope *outer_scope, size_t *results) {
    results[ReturnKindUnconditional] = 0;
    results[ReturnKindError] = 0;
    results[ReturnKindMaybe] = 0;

    while (inner_scope != outer_scope) {
        assert(inner_scope);
        if (inner_scope->id == ScopeIdDefer) {
            AstNode *defer_node = inner_scope->source_node;
            assert(defer_node->type == NodeTypeDefer);
            ReturnKind defer_kind = defer_node->data.defer.kind;
            results[defer_kind] += 1;

        }
        inner_scope = inner_scope->parent;
    }
}

static IrInstruction *ir_mark_gen(IrInstruction *instruction) {
    instruction->is_gen = true;
    return instruction;
}

static bool ir_gen_defers_for_block(IrBuilder *irb, Scope *inner_scope, Scope *outer_scope,
        bool gen_error_defers, bool gen_maybe_defers)
{
    Scope *scope = inner_scope;
    while (scope != outer_scope) {
        if (!scope)
            return false;

        if (scope->id == ScopeIdDefer) {
            AstNode *defer_node = scope->source_node;
            assert(defer_node->type == NodeTypeDefer);
            ReturnKind defer_kind = defer_node->data.defer.kind;
            if (defer_kind == ReturnKindUnconditional ||
                (gen_error_defers && defer_kind == ReturnKindError) ||
                (gen_maybe_defers && defer_kind == ReturnKindMaybe))
            {
                AstNode *defer_expr_node = defer_node->data.defer.expr;
                ir_gen_node(irb, defer_expr_node, defer_node->data.defer.expr_scope);
            }

        }
        scope = scope->parent;
    }
    return true;
}

static void ir_set_cursor_at_end(IrBuilder *irb, IrBasicBlock *basic_block) {
    assert(basic_block);

    irb->current_basic_block = basic_block;
}

static ScopeDeferExpr *get_scope_defer_expr(Scope *scope) {
    while (scope) {
        if (scope->id == ScopeIdDeferExpr)
            return (ScopeDeferExpr *)scope;
        if (scope->id == ScopeIdFnDef)
            return nullptr;

        scope = scope->parent;
    }
    return nullptr;
}

static IrInstruction *ir_gen_return(IrBuilder *irb, Scope *scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypeReturnExpr);

    FnTableEntry *fn_entry = exec_fn_entry(irb->exec);
    if (!fn_entry) {
        add_node_error(irb->codegen, node, buf_sprintf("return expression outside function definition"));
        return irb->codegen->invalid_instruction;
    }

    ScopeDeferExpr *scope_defer_expr = get_scope_defer_expr(scope);
    if (scope_defer_expr) {
        if (!scope_defer_expr->reported_err) {
            add_node_error(irb->codegen, node, buf_sprintf("cannot return from defer expression"));
            scope_defer_expr->reported_err = true;
        }
        return irb->codegen->invalid_instruction;
    }

    Scope *outer_scope = irb->exec->begin_scope;

    AstNode *expr_node = node->data.return_expr.expr;
    switch (node->data.return_expr.kind) {
        case ReturnKindUnconditional:
            {
                IrInstruction *return_value;
                if (expr_node) {
                    return_value = ir_gen_node(irb, expr_node, scope);
                    if (return_value == irb->codegen->invalid_instruction)
                        return irb->codegen->invalid_instruction;
                } else {
                    return_value = ir_build_const_void(irb, scope, node);
                }

                size_t defer_counts[3];
                ir_count_defers(irb, scope, outer_scope, defer_counts);
                if (defer_counts[ReturnKindError] > 0) {
                    IrBasicBlock *err_block = ir_build_basic_block(irb, scope, "ErrRetErr");
                    IrBasicBlock *ok_block = ir_build_basic_block(irb, scope, "ErrRetOk");

                    IrInstruction *is_err = ir_build_test_err(irb, scope, node, return_value);

                    IrInstruction *is_comptime;
                    if (ir_should_inline(irb->exec, scope)) {
                        is_comptime = ir_build_const_bool(irb, scope, node, true);
                    } else {
                        is_comptime = ir_build_test_comptime(irb, scope, node, is_err);
                    }

                    ir_mark_gen(ir_build_cond_br(irb, scope, node, is_err, err_block, ok_block, is_comptime));

                    ir_set_cursor_at_end(irb, err_block);
                    ir_gen_defers_for_block(irb, scope, outer_scope, true, false);
                    ir_build_return(irb, scope, node, return_value);

                    ir_set_cursor_at_end(irb, ok_block);
                    ir_gen_defers_for_block(irb, scope, outer_scope, false, false);
                    return ir_build_return(irb, scope, node, return_value);
                } else if (defer_counts[ReturnKindMaybe] > 0) {
                    IrBasicBlock *null_block = ir_build_basic_block(irb, scope, "MaybeRetNull");
                    IrBasicBlock *ok_block = ir_build_basic_block(irb, scope, "MaybeRetOk");

                    IrInstruction *is_non_null = ir_build_test_nonnull(irb, scope, node, return_value);

                    IrInstruction *is_comptime;
                    if (ir_should_inline(irb->exec, scope)) {
                        is_comptime = ir_build_const_bool(irb, scope, node, true);
                    } else {
                        is_comptime = ir_build_test_comptime(irb, scope, node, is_non_null);
                    }

                    ir_mark_gen(ir_build_cond_br(irb, scope, node, is_non_null, ok_block, null_block, is_comptime));

                    ir_set_cursor_at_end(irb, null_block);
                    ir_gen_defers_for_block(irb, scope, outer_scope, false, true);
                    ir_build_return(irb, scope, node, return_value);

                    ir_set_cursor_at_end(irb, ok_block);
                    ir_gen_defers_for_block(irb, scope, outer_scope, false, false);
                    return ir_build_return(irb, scope, node, return_value);
                } else {
                    // generate unconditional defers
                    ir_gen_defers_for_block(irb, scope, outer_scope, false, false);
                    return ir_build_return(irb, scope, node, return_value);
                }
            }
        case ReturnKindError:
            {
                assert(expr_node);
                IrInstruction *err_union_ptr = ir_gen_node_extra(irb, expr_node, scope, LVAL_PTR);
                if (err_union_ptr == irb->codegen->invalid_instruction)
                    return irb->codegen->invalid_instruction;
                IrInstruction *err_union_val = ir_build_load_ptr(irb, scope, node, err_union_ptr);
                IrInstruction *is_err_val = ir_build_test_err(irb, scope, node, err_union_val);

                IrBasicBlock *return_block = ir_build_basic_block(irb, scope, "ErrRetReturn");
                IrBasicBlock *continue_block = ir_build_basic_block(irb, scope, "ErrRetContinue");
                IrInstruction *is_comptime = ir_build_const_bool(irb, scope, node, ir_should_inline(irb->exec, scope));
                ir_mark_gen(ir_build_cond_br(irb, scope, node, is_err_val, return_block, continue_block, is_comptime));

                ir_set_cursor_at_end(irb, return_block);
                ir_gen_defers_for_block(irb, scope, outer_scope, true, false);
                IrInstruction *err_val = ir_build_unwrap_err_code(irb, scope, node, err_union_ptr);
                ir_build_return(irb, scope, node, err_val);

                ir_set_cursor_at_end(irb, continue_block);
                IrInstruction *unwrapped_ptr = ir_build_unwrap_err_payload(irb, scope, node, err_union_ptr, false);
                if (lval.is_ptr)
                    return unwrapped_ptr;
                else
                    return ir_build_load_ptr(irb, scope, node, unwrapped_ptr);
            }
        case ReturnKindMaybe:
            {
                assert(expr_node);
                IrInstruction *maybe_val_ptr = ir_gen_node_extra(irb, expr_node, scope, LVAL_PTR);
                if (maybe_val_ptr == irb->codegen->invalid_instruction)
                    return irb->codegen->invalid_instruction;
                IrInstruction *maybe_val = ir_build_load_ptr(irb, scope, node, maybe_val_ptr);
                IrInstruction *is_non_null = ir_build_test_nonnull(irb, scope, node, maybe_val);

                IrBasicBlock *return_block = ir_build_basic_block(irb, scope, "MaybeRetReturn");
                IrBasicBlock *continue_block = ir_build_basic_block(irb, scope, "MaybeRetContinue");
                IrInstruction *is_comptime = ir_build_const_bool(irb, scope, node, ir_should_inline(irb->exec, scope));
                ir_mark_gen(ir_build_cond_br(irb, scope, node, is_non_null, continue_block, return_block, is_comptime));

                ir_set_cursor_at_end(irb, return_block);
                ir_gen_defers_for_block(irb, scope, outer_scope, false, true);
                IrInstruction *null = ir_build_const_null(irb, scope, node);
                ir_build_return(irb, scope, node, null);

                ir_set_cursor_at_end(irb, continue_block);
                IrInstruction *unwrapped_ptr = ir_build_unwrap_maybe(irb, scope, node, maybe_val_ptr, false);
                if (lval.is_ptr)
                    return unwrapped_ptr;
                else
                    return ir_build_load_ptr(irb, scope, node, unwrapped_ptr);
            }
    }
    zig_unreachable();
}

static VariableTableEntry *create_local_var(CodeGen *codegen, AstNode *node, Scope *parent_scope,
        Buf *name, bool src_is_const, bool gen_is_const, bool is_shadowable, IrInstruction *is_comptime)
{
    VariableTableEntry *variable_entry = allocate<VariableTableEntry>(1);
    variable_entry->parent_scope = parent_scope;
    variable_entry->shadowable = is_shadowable;
    variable_entry->mem_slot_index = SIZE_MAX;
    variable_entry->is_comptime = is_comptime;
    variable_entry->src_arg_index = SIZE_MAX;
    variable_entry->value = allocate<ConstExprValue>(1);

    if (name) {
        buf_init_from_buf(&variable_entry->name, name);

        VariableTableEntry *existing_var = find_variable(codegen, parent_scope, name);
        if (existing_var && !existing_var->shadowable) {
            ErrorMsg *msg = add_node_error(codegen, node,
                    buf_sprintf("redeclaration of variable '%s'", buf_ptr(name)));
            add_error_note(codegen, msg, existing_var->decl_node, buf_sprintf("previous declaration is here"));
            variable_entry->value->type = codegen->builtin_types.entry_invalid;
        } else {
            auto primitive_table_entry = codegen->primitive_type_table.maybe_get(name);
            if (primitive_table_entry) {
                TypeTableEntry *type = primitive_table_entry->value;
                add_node_error(codegen, node,
                        buf_sprintf("variable shadows type '%s'", buf_ptr(&type->name)));
                variable_entry->value->type = codegen->builtin_types.entry_invalid;
            } else {
                Tld *tld = find_decl(codegen, parent_scope, name);
                if (tld != nullptr) {
                    ErrorMsg *msg = add_node_error(codegen, node,
                            buf_sprintf("redefinition of '%s'", buf_ptr(name)));
                    add_error_note(codegen, msg, tld->source_node, buf_sprintf("previous definition is here"));
                    variable_entry->value->type = codegen->builtin_types.entry_invalid;
                }
            }
        }

    } else {
        assert(is_shadowable);
        // TODO make this name not actually be in scope. user should be able to make a variable called "_anon"
        // might already be solved, let's just make sure it has test coverage
        // maybe we put a prefix on this so the debug info doesn't clobber user debug info for same named variables
        buf_init_from_str(&variable_entry->name, "_anon");
    }

    variable_entry->src_is_const = src_is_const;
    variable_entry->gen_is_const = gen_is_const;
    variable_entry->decl_node = node;
    variable_entry->child_scope = create_var_scope(node, parent_scope, variable_entry);

    return variable_entry;
}

// Set name to nullptr to make the variable anonymous (not visible to programmer).
// After you call this function var->child_scope has the variable in scope
static VariableTableEntry *ir_create_var(IrBuilder *irb, AstNode *node, Scope *scope, Buf *name,
        bool src_is_const, bool gen_is_const, bool is_shadowable, IrInstruction *is_comptime)
{
    VariableTableEntry *var = create_local_var(irb->codegen, node, scope, name, src_is_const, gen_is_const, is_shadowable, is_comptime);
    if (is_comptime != nullptr || gen_is_const)
        var->mem_slot_index = exec_next_mem_slot(irb->exec);
    assert(var->child_scope);
    return var;
}

static LabelTableEntry *find_label(IrExecutable *exec, Scope *scope, Buf *name) {
    while (scope) {
        if (scope->id == ScopeIdBlock) {
            ScopeBlock *block_scope = (ScopeBlock *)scope;
            auto entry = block_scope->label_table.maybe_get(name);
            if (entry)
                return entry->value;
        }
        scope = scope->parent;
    }

    return nullptr;
}

static ScopeBlock *find_block_scope(IrExecutable *exec, Scope *scope) {
    while (scope) {
        if (scope->id == ScopeIdBlock)
            return (ScopeBlock *)scope;
        scope = scope->parent;
    }
    return nullptr;
}

static IrInstruction *ir_gen_block(IrBuilder *irb, Scope *parent_scope, AstNode *block_node) {
    assert(block_node->type == NodeTypeBlock);

    ScopeBlock *scope_block = create_block_scope(block_node, parent_scope);
    Scope *outer_block_scope = &scope_block->base;
    Scope *child_scope = outer_block_scope;

    FnTableEntry *fn_entry = scope_fn_entry(parent_scope);
    if (fn_entry && fn_entry->child_scope == parent_scope) {
        fn_entry->def_scope = scope_block;
    }

    if (block_node->data.block.statements.length == 0) {
        // {}
        return ir_mark_gen(ir_build_const_void(irb, child_scope, block_node));
    }

    IrInstruction *return_value = nullptr;
    for (size_t i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);

        if (statement_node->type == NodeTypeLabel) {
            Buf *label_name = statement_node->data.label.name;
            IrBasicBlock *label_block = ir_build_basic_block(irb, child_scope, buf_ptr(label_name));
            LabelTableEntry *label = allocate<LabelTableEntry>(1);
            label->decl_node = statement_node;
            label->bb = label_block;
            irb->exec->all_labels.append(label);

            LabelTableEntry *existing_label = find_label(irb->exec, child_scope, label_name);
            if (existing_label) {
                ErrorMsg *msg = add_node_error(irb->codegen, statement_node,
                    buf_sprintf("duplicate label name '%s'", buf_ptr(label_name)));
                add_error_note(irb->codegen, msg, existing_label->decl_node, buf_sprintf("other label here"));
                return irb->codegen->invalid_instruction;
            } else {
                ScopeBlock *scope_block = find_block_scope(irb->exec, child_scope);
                scope_block->label_table.put(label_name, label);
            }

            if (!(return_value && instr_is_unreachable(return_value))) {
                // fall through into new labeled basic block
                IrInstruction *is_comptime = ir_mark_gen(ir_build_const_bool(irb, child_scope, statement_node,
                        ir_should_inline(irb->exec, child_scope)));
                ir_mark_gen(ir_build_br(irb, child_scope, statement_node, label_block, is_comptime));
            }
            ir_set_cursor_at_end(irb, label_block);

            return_value = nullptr;
            continue;
        }

        if (return_value && instr_is_unreachable(return_value)) {
            if (is_node_void_expr(statement_node))
                continue;
            add_node_error(irb->codegen, statement_node, buf_sprintf("unreachable code"));
        }

        return_value = ir_gen_node(irb, statement_node, child_scope);
        if (statement_node->type == NodeTypeDefer && return_value != irb->codegen->invalid_instruction) {
            // defer starts a new scope
            child_scope = statement_node->data.defer.child_scope;
            assert(child_scope);
        } else if (return_value->id == IrInstructionIdDeclVar) {
            // variable declarations start a new scope
            IrInstructionDeclVar *decl_var_instruction = (IrInstructionDeclVar *)return_value;
            child_scope = decl_var_instruction->var->child_scope;
        }
    }

    // labels are never the last statement
    assert(return_value != nullptr);

    if (!instr_is_unreachable(return_value))
        ir_gen_defers_for_block(irb, child_scope, outer_block_scope, false, false);

    return return_value;
}

static IrInstruction *ir_gen_bin_op_id(IrBuilder *irb, Scope *scope, AstNode *node, IrBinOp op_id) {
    IrInstruction *op1 = ir_gen_node(irb, node->data.bin_op_expr.op1, scope);
    IrInstruction *op2 = ir_gen_node(irb, node->data.bin_op_expr.op2, scope);

    if (op1 == irb->codegen->invalid_instruction || op2 == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    return ir_build_bin_op(irb, scope, node, op_id, op1, op2, true);
}

static IrInstruction *ir_gen_assign(IrBuilder *irb, Scope *scope, AstNode *node) {
    IrInstruction *lvalue = ir_gen_node_extra(irb, node->data.bin_op_expr.op1, scope, LVAL_PTR);
    IrInstruction *rvalue = ir_gen_node(irb, node->data.bin_op_expr.op2, scope);

    if (lvalue == irb->codegen->invalid_instruction || rvalue == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    ir_build_store_ptr(irb, scope, node, lvalue, rvalue);
    return ir_build_const_void(irb, scope, node);
}

static IrInstruction *ir_gen_assign_op(IrBuilder *irb, Scope *scope, AstNode *node, IrBinOp op_id) {
    IrInstruction *lvalue = ir_gen_node_extra(irb, node->data.bin_op_expr.op1, scope, LVAL_PTR);
    if (lvalue == irb->codegen->invalid_instruction)
        return lvalue;
    IrInstruction *op1 = ir_build_load_ptr(irb, scope, node->data.bin_op_expr.op1, lvalue);
    IrInstruction *op2 = ir_gen_node(irb, node->data.bin_op_expr.op2, scope);
    if (op2 == irb->codegen->invalid_instruction)
        return op2;
    IrInstruction *result = ir_build_bin_op(irb, scope, node, op_id, op1, op2, true);
    ir_build_store_ptr(irb, scope, node, lvalue, result);
    return ir_build_const_void(irb, scope, node);
}

static IrInstruction *ir_gen_bool_or(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    IrInstruction *val1 = ir_gen_node(irb, node->data.bin_op_expr.op1, scope);
    if (val1 == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;
    IrBasicBlock *post_val1_block = irb->current_basic_block;

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, scope, node, val1);
    }

    // block for when val1 == false
    IrBasicBlock *false_block = ir_build_basic_block(irb, scope, "BoolOrFalse");
    // block for when val1 == true (don't even evaluate the second part)
    IrBasicBlock *true_block = ir_build_basic_block(irb, scope, "BoolOrTrue");

    ir_build_cond_br(irb, scope, node, val1, true_block, false_block, is_comptime);

    ir_set_cursor_at_end(irb, false_block);
    IrInstruction *val2 = ir_gen_node(irb, node->data.bin_op_expr.op2, scope);
    if (val2 == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;
    IrBasicBlock *post_val2_block = irb->current_basic_block;

    ir_build_br(irb, scope, node, true_block, is_comptime);

    ir_set_cursor_at_end(irb, true_block);

    IrInstruction **incoming_values = allocate<IrInstruction *>(2);
    incoming_values[0] = val1;
    incoming_values[1] = val2;
    IrBasicBlock **incoming_blocks = allocate<IrBasicBlock *>(2);
    incoming_blocks[0] = post_val1_block;
    incoming_blocks[1] = post_val2_block;

    return ir_build_phi(irb, scope, node, 2, incoming_blocks, incoming_values);
}

static IrInstruction *ir_gen_bool_and(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    IrInstruction *val1 = ir_gen_node(irb, node->data.bin_op_expr.op1, scope);
    if (val1 == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;
    IrBasicBlock *post_val1_block = irb->current_basic_block;

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, scope, node, val1);
    }

    // block for when val1 == true
    IrBasicBlock *true_block = ir_build_basic_block(irb, scope, "BoolAndTrue");
    // block for when val1 == false (don't even evaluate the second part)
    IrBasicBlock *false_block = ir_build_basic_block(irb, scope, "BoolAndFalse");

    ir_build_cond_br(irb, scope, node, val1, true_block, false_block, is_comptime);

    ir_set_cursor_at_end(irb, true_block);
    IrInstruction *val2 = ir_gen_node(irb, node->data.bin_op_expr.op2, scope);
    if (val2 == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;
    IrBasicBlock *post_val2_block = irb->current_basic_block;

    ir_build_br(irb, scope, node, false_block, is_comptime);

    ir_set_cursor_at_end(irb, false_block);

    IrInstruction **incoming_values = allocate<IrInstruction *>(2);
    incoming_values[0] = val1;
    incoming_values[1] = val2;
    IrBasicBlock **incoming_blocks = allocate<IrBasicBlock *>(2);
    incoming_blocks[0] = post_val1_block;
    incoming_blocks[1] = post_val2_block;

    return ir_build_phi(irb, scope, node, 2, incoming_blocks, incoming_values);
}

static IrInstruction *ir_gen_maybe_ok_or(IrBuilder *irb, Scope *parent_scope, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    AstNode *op1_node = node->data.bin_op_expr.op1;
    AstNode *op2_node = node->data.bin_op_expr.op2;

    IrInstruction *maybe_ptr = ir_gen_node_extra(irb, op1_node, parent_scope, LVAL_PTR);
    if (maybe_ptr == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *maybe_val = ir_build_load_ptr(irb, parent_scope, node, maybe_ptr);
    IrInstruction *is_non_null = ir_build_test_nonnull(irb, parent_scope, node, maybe_val);

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, parent_scope)) {
        is_comptime = ir_build_const_bool(irb, parent_scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, parent_scope, node, is_non_null);
    }

    IrBasicBlock *ok_block = ir_build_basic_block(irb, parent_scope, "MaybeNonNull");
    IrBasicBlock *null_block = ir_build_basic_block(irb, parent_scope, "MaybeNull");
    IrBasicBlock *end_block = ir_build_basic_block(irb, parent_scope, "MaybeEnd");
    ir_build_cond_br(irb, parent_scope, node, is_non_null, ok_block, null_block, is_comptime);

    ir_set_cursor_at_end(irb, null_block);
    IrInstruction *null_result = ir_gen_node(irb, op2_node, parent_scope);
    if (null_result == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;
    IrBasicBlock *after_null_block = irb->current_basic_block;
    if (!instr_is_unreachable(null_result))
        ir_mark_gen(ir_build_br(irb, parent_scope, node, end_block, is_comptime));

    ir_set_cursor_at_end(irb, ok_block);
    IrInstruction *unwrapped_ptr = ir_build_unwrap_maybe(irb, parent_scope, node, maybe_ptr, false);
    IrInstruction *unwrapped_payload = ir_build_load_ptr(irb, parent_scope, node, unwrapped_ptr);
    IrBasicBlock *after_ok_block = irb->current_basic_block;
    ir_build_br(irb, parent_scope, node, end_block, is_comptime);

    ir_set_cursor_at_end(irb, end_block);
    IrInstruction **incoming_values = allocate<IrInstruction *>(2);
    incoming_values[0] = null_result;
    incoming_values[1] = unwrapped_payload;
    IrBasicBlock **incoming_blocks = allocate<IrBasicBlock *>(2);
    incoming_blocks[0] = after_null_block;
    incoming_blocks[1] = after_ok_block;
    return ir_build_phi(irb, parent_scope, node, 2, incoming_blocks, incoming_values);
}

static IrInstruction *ir_gen_bin_op(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    BinOpType bin_op_type = node->data.bin_op_expr.bin_op;
    switch (bin_op_type) {
        case BinOpTypeInvalid:
            zig_unreachable();
        case BinOpTypeAssign:
            return ir_gen_assign(irb, scope, node);
        case BinOpTypeAssignTimes:
            return ir_gen_assign_op(irb, scope, node, IrBinOpMult);
        case BinOpTypeAssignTimesWrap:
            return ir_gen_assign_op(irb, scope, node, IrBinOpMultWrap);
        case BinOpTypeAssignDiv:
            return ir_gen_assign_op(irb, scope, node, IrBinOpDiv);
        case BinOpTypeAssignMod:
            return ir_gen_assign_op(irb, scope, node, IrBinOpRem);
        case BinOpTypeAssignPlus:
            return ir_gen_assign_op(irb, scope, node, IrBinOpAdd);
        case BinOpTypeAssignPlusWrap:
            return ir_gen_assign_op(irb, scope, node, IrBinOpAddWrap);
        case BinOpTypeAssignMinus:
            return ir_gen_assign_op(irb, scope, node, IrBinOpSub);
        case BinOpTypeAssignMinusWrap:
            return ir_gen_assign_op(irb, scope, node, IrBinOpSubWrap);
        case BinOpTypeAssignBitShiftLeft:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBitShiftLeft);
        case BinOpTypeAssignBitShiftLeftWrap:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBitShiftLeftWrap);
        case BinOpTypeAssignBitShiftRight:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBitShiftRight);
        case BinOpTypeAssignBitAnd:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBinAnd);
        case BinOpTypeAssignBitXor:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBinXor);
        case BinOpTypeAssignBitOr:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBinOr);
        case BinOpTypeAssignBoolAnd:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBoolAnd);
        case BinOpTypeAssignBoolOr:
            return ir_gen_assign_op(irb, scope, node, IrBinOpBoolOr);
        case BinOpTypeBoolOr:
            return ir_gen_bool_or(irb, scope, node);
        case BinOpTypeBoolAnd:
            return ir_gen_bool_and(irb, scope, node);
        case BinOpTypeCmpEq:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpCmpEq);
        case BinOpTypeCmpNotEq:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpCmpNotEq);
        case BinOpTypeCmpLessThan:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpCmpLessThan);
        case BinOpTypeCmpGreaterThan:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpCmpGreaterThan);
        case BinOpTypeCmpLessOrEq:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpCmpLessOrEq);
        case BinOpTypeCmpGreaterOrEq:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpCmpGreaterOrEq);
        case BinOpTypeBinOr:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpBinOr);
        case BinOpTypeBinXor:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpBinXor);
        case BinOpTypeBinAnd:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpBinAnd);
        case BinOpTypeBitShiftLeft:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpBitShiftLeft);
        case BinOpTypeBitShiftLeftWrap:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpBitShiftLeftWrap);
        case BinOpTypeBitShiftRight:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpBitShiftRight);
        case BinOpTypeAdd:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpAdd);
        case BinOpTypeAddWrap:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpAddWrap);
        case BinOpTypeSub:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpSub);
        case BinOpTypeSubWrap:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpSubWrap);
        case BinOpTypeMult:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpMult);
        case BinOpTypeMultWrap:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpMultWrap);
        case BinOpTypeDiv:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpDiv);
        case BinOpTypeMod:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpRem);
        case BinOpTypeArrayCat:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpArrayCat);
        case BinOpTypeArrayMult:
            return ir_gen_bin_op_id(irb, scope, node, IrBinOpArrayMult);
        case BinOpTypeUnwrapMaybe:
            return ir_gen_maybe_ok_or(irb, scope, node);
    }
    zig_unreachable();
}

static IrInstruction *ir_gen_num_lit(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeNumberLiteral);

    if (node->data.number_literal.overflow) {
        add_node_error(irb->codegen, node, buf_sprintf("number literal too large to be represented in any type"));
        return irb->codegen->invalid_instruction;
    }

    return ir_build_const_bignum(irb, scope, node, node->data.number_literal.bignum);
}

static IrInstruction *ir_gen_char_lit(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeCharLiteral);

    return ir_build_const_uint(irb, scope, node, node->data.char_literal.value);
}

static IrInstruction *ir_gen_null_literal(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeNullLiteral);

    return ir_build_const_null(irb, scope, node);
}

static IrInstruction *ir_gen_var_literal(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeVarLiteral);

    return ir_build_const_type(irb, scope, node, irb->codegen->builtin_types.entry_var);
}

static IrInstruction *ir_gen_symbol(IrBuilder *irb, Scope *scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypeSymbol);

    Buf *variable_name = node->data.symbol_expr.symbol;

    if (buf_eql_str(variable_name, "_") && lval.is_ptr) {
        IrInstructionConst *const_instruction = ir_build_instruction<IrInstructionConst>(irb, scope, node);
        const_instruction->base.value.type = get_pointer_to_type(irb->codegen,
                irb->codegen->builtin_types.entry_void, false);
        const_instruction->base.value.special = ConstValSpecialStatic;
        const_instruction->base.value.data.x_ptr.special = ConstPtrSpecialDiscard;
        return &const_instruction->base;
    }

    auto primitive_table_entry = irb->codegen->primitive_type_table.maybe_get(variable_name);
    if (primitive_table_entry) {
        IrInstruction *value = ir_build_const_type(irb, scope, node, primitive_table_entry->value);
        if (lval.is_ptr) {
            return ir_build_ref(irb, scope, node, value, lval.is_const, lval.is_volatile);
        } else {
            return value;
        }
    }

    VariableTableEntry *var = find_variable(irb->codegen, scope, variable_name);
    if (var) {
        IrInstruction *var_ptr = ir_build_var_ptr(irb, scope, node, var,
                !lval.is_ptr || lval.is_const, lval.is_ptr && lval.is_volatile);
        if (lval.is_ptr)
            return var_ptr;
        else
            return ir_build_load_ptr(irb, scope, node, var_ptr);
    }

    Tld *tld = find_decl(irb->codegen, scope, variable_name);
    if (tld)
        return ir_build_decl_ref(irb, scope, node, tld, lval);

    if (node->owner->any_imports_failed) {
        // skip the error message since we had a failing import in this file
        // if an import breaks we don't need redundant undeclared identifier errors
        return irb->codegen->invalid_instruction;
    }

    // TODO put a variable of same name with invalid type in global scope
    // so that future references to this same name will find a variable with an invalid type
    add_node_error(irb->codegen, node, buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
    return irb->codegen->invalid_instruction;
}

static IrInstruction *ir_gen_array_access(IrBuilder *irb, Scope *scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypeArrayAccessExpr);

    AstNode *array_ref_node = node->data.array_access_expr.array_ref_expr;
    IrInstruction *array_ref_instruction = ir_gen_node_extra(irb, array_ref_node, scope, LVAL_PTR);
    if (array_ref_instruction == irb->codegen->invalid_instruction)
        return array_ref_instruction;

    AstNode *subscript_node = node->data.array_access_expr.subscript;
    IrInstruction *subscript_instruction = ir_gen_node(irb, subscript_node, scope);
    if (subscript_instruction == irb->codegen->invalid_instruction)
        return subscript_instruction;

    IrInstruction *ptr_instruction = ir_build_elem_ptr(irb, scope, node, array_ref_instruction,
            subscript_instruction, true);
    if (lval.is_ptr)
        return ptr_instruction;

    return ir_build_load_ptr(irb, scope, node, ptr_instruction);
}

static IrInstruction *ir_gen_field_access(IrBuilder *irb, Scope *scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypeFieldAccessExpr);

    AstNode *container_ref_node = node->data.field_access_expr.struct_expr;
    Buf *field_name = node->data.field_access_expr.field_name;

    IrInstruction *container_ref_instruction = ir_gen_node_extra(irb, container_ref_node, scope, LVAL_PTR);
    if (container_ref_instruction == irb->codegen->invalid_instruction)
        return container_ref_instruction;

    IrInstruction *ptr_instruction = ir_build_field_ptr(irb, scope, node, container_ref_instruction, field_name);
    if (lval.is_ptr)
        return ptr_instruction;

    return ir_build_load_ptr(irb, scope, node, ptr_instruction);
}

static IrInstruction *ir_gen_overflow_op(IrBuilder *irb, Scope *scope, AstNode *node, IrOverflowOp op) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *type_node = node->data.fn_call_expr.params.at(0);
    AstNode *op1_node = node->data.fn_call_expr.params.at(1);
    AstNode *op2_node = node->data.fn_call_expr.params.at(2);
    AstNode *result_ptr_node = node->data.fn_call_expr.params.at(3);


    IrInstruction *type_value = ir_gen_node(irb, type_node, scope);
    if (type_value == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *op1 = ir_gen_node(irb, op1_node, scope);
    if (op1 == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *op2 = ir_gen_node(irb, op2_node, scope);
    if (op2 == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *result_ptr = ir_gen_node(irb, result_ptr_node, scope);
    if (result_ptr == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    return ir_build_overflow_op(irb, scope, node, op, type_value, op1, op2, result_ptr, nullptr);
}

static IrInstruction *ir_gen_test_type(IrBuilder *irb, Scope *scope, AstNode *node, TypeTableEntryId type_id) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *type_node = node->data.fn_call_expr.params.at(0);

    IrInstruction *type_value = ir_gen_node(irb, type_node, scope);
    if (type_value == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    return ir_build_test_type(irb, scope, node, type_value, type_id);
}

static IrInstruction *ir_gen_builtin_fn_call(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
    Buf *name = fn_ref_expr->data.symbol_expr.symbol;
    auto entry = irb->codegen->builtin_fn_table.maybe_get(name);

    if (!entry) {
        add_node_error(irb->codegen, node,
                buf_sprintf("invalid builtin function: '%s'", buf_ptr(name)));
        return irb->codegen->invalid_instruction;
    }

    BuiltinFnEntry *builtin_fn = entry->value;
    size_t actual_param_count = node->data.fn_call_expr.params.length;

    if (builtin_fn->param_count != SIZE_MAX && builtin_fn->param_count != actual_param_count) {
        add_node_error(irb->codegen, node,
                buf_sprintf("expected %zu arguments, found %zu",
                    builtin_fn->param_count, actual_param_count));
        return irb->codegen->invalid_instruction;
    }

    builtin_fn->ref_count += 1;

    switch (builtin_fn->id) {
        case BuiltinFnIdInvalid:
            zig_unreachable();
        case BuiltinFnIdTypeof:
            {
                AstNode *arg_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg = ir_gen_node(irb, arg_node, scope);
                if (arg == irb->codegen->invalid_instruction)
                    return arg;
                return ir_build_typeof(irb, scope, node, arg);
            }
        case BuiltinFnIdSetDebugSafety:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                return ir_build_set_debug_safety(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdCompileVar:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_compile_var(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdSizeof:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_size_of(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdCtz:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_ctz(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdClz:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_clz(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdGeneratedCode:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_generated_code(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdImport:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_import(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdCImport:
            {
                return ir_build_c_import(irb, scope, node);
            }
        case BuiltinFnIdCInclude:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                if (!exec_c_import_buf(irb->exec)) {
                    add_node_error(irb->codegen, node, buf_sprintf("C include valid only inside C import block"));
                    return irb->codegen->invalid_instruction;
                }

                return ir_build_c_include(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdCDefine:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                if (!exec_c_import_buf(irb->exec)) {
                    add_node_error(irb->codegen, node, buf_sprintf("C define valid only inside C import block"));
                    return irb->codegen->invalid_instruction;
                }

                return ir_build_c_define(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdCUndef:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                if (!exec_c_import_buf(irb->exec)) {
                    add_node_error(irb->codegen, node, buf_sprintf("C undef valid only inside C import block"));
                    return irb->codegen->invalid_instruction;
                }

                return ir_build_c_undef(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdMaxValue:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_max_value(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdMinValue:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_min_value(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdCompileErr:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_compile_err(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdCompileLog:
            {
                IrInstruction **args = allocate<IrInstruction*>(actual_param_count);

                for (size_t i = 0; i < actual_param_count; i += 1) {
                    AstNode *arg_node = node->data.fn_call_expr.params.at(i);
                    args[i] = ir_gen_node(irb, arg_node, scope);
                    if (args[i] == irb->codegen->invalid_instruction)
                        return irb->codegen->invalid_instruction;
                }

                return ir_build_compile_log(irb, scope, node, actual_param_count, args);
            }
        case BuiltinFnIdErrName:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_err_name(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdEmbedFile:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_embed_file(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdCmpExchange:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                AstNode *arg2_node = node->data.fn_call_expr.params.at(2);
                IrInstruction *arg2_value = ir_gen_node(irb, arg2_node, scope);
                if (arg2_value == irb->codegen->invalid_instruction)
                    return arg2_value;

                AstNode *arg3_node = node->data.fn_call_expr.params.at(3);
                IrInstruction *arg3_value = ir_gen_node(irb, arg3_node, scope);
                if (arg3_value == irb->codegen->invalid_instruction)
                    return arg3_value;

                AstNode *arg4_node = node->data.fn_call_expr.params.at(4);
                IrInstruction *arg4_value = ir_gen_node(irb, arg4_node, scope);
                if (arg4_value == irb->codegen->invalid_instruction)
                    return arg4_value;

                return ir_build_cmpxchg(irb, scope, node, arg0_value, arg1_value,
                    arg2_value, arg3_value, arg4_value,
                    AtomicOrderUnordered, AtomicOrderUnordered);
            }
        case BuiltinFnIdFence:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_fence(irb, scope, node, arg0_value, AtomicOrderUnordered);
            }
        case BuiltinFnIdDivExact:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                return ir_build_div_exact(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdTruncate:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                return ir_build_truncate(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdIntType:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                return ir_build_int_type(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdMemcpy:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                AstNode *arg2_node = node->data.fn_call_expr.params.at(2);
                IrInstruction *arg2_value = ir_gen_node(irb, arg2_node, scope);
                if (arg2_value == irb->codegen->invalid_instruction)
                    return arg2_value;

                return ir_build_memcpy(irb, scope, node, arg0_value, arg1_value, arg2_value);
            }
        case BuiltinFnIdMemset:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                AstNode *arg2_node = node->data.fn_call_expr.params.at(2);
                IrInstruction *arg2_value = ir_gen_node(irb, arg2_node, scope);
                if (arg2_value == irb->codegen->invalid_instruction)
                    return arg2_value;

                return ir_build_memset(irb, scope, node, arg0_value, arg1_value, arg2_value);
            }
        case BuiltinFnIdMemberCount:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_member_count(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdBreakpoint:
            return ir_build_breakpoint(irb, scope, node);
        case BuiltinFnIdReturnAddress:
            return ir_build_return_address(irb, scope, node);
        case BuiltinFnIdFrameAddress:
            return ir_build_frame_address(irb, scope, node);
        case BuiltinFnIdAlignof:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_alignof(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdAddWithOverflow:
            return ir_gen_overflow_op(irb, scope, node, IrOverflowOpAdd);
        case BuiltinFnIdSubWithOverflow:
            return ir_gen_overflow_op(irb, scope, node, IrOverflowOpSub);
        case BuiltinFnIdMulWithOverflow:
            return ir_gen_overflow_op(irb, scope, node, IrOverflowOpMul);
        case BuiltinFnIdShlWithOverflow:
            return ir_gen_overflow_op(irb, scope, node, IrOverflowOpShl);
        case BuiltinFnIdTypeName:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_type_name(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdIsInteger:
            return ir_gen_test_type(irb, scope, node, TypeTableEntryIdInt);
        case BuiltinFnIdIsFloat:
            return ir_gen_test_type(irb, scope, node, TypeTableEntryIdFloat);
        case BuiltinFnIdCanImplicitCast:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                return ir_build_can_implicit_cast(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdSetGlobalAlign:
        case BuiltinFnIdSetGlobalSection:
        case BuiltinFnIdSetGlobalLinkage:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                if (arg0_node->type != NodeTypeSymbol) {
                    add_node_error(irb->codegen, arg0_node, buf_sprintf("expected identifier"));
                    return irb->codegen->invalid_instruction;
                }
                Buf *variable_name = arg0_node->data.symbol_expr.symbol;
                Tld *tld = find_decl(irb->codegen, scope, variable_name);
                if (!tld) {
                    add_node_error(irb->codegen, node, buf_sprintf("use of undeclared identifier '%s'",
                                buf_ptr(variable_name)));
                    return irb->codegen->invalid_instruction;
                }
                if (tld->id != TldIdVar && tld->id != TldIdFn) {
                    add_node_error(irb->codegen, node, buf_sprintf("'%s' must be global variable or function",
                                buf_ptr(variable_name)));
                    return irb->codegen->invalid_instruction;
                }
                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                if (builtin_fn->id == BuiltinFnIdSetGlobalAlign) {
                    return ir_build_set_global_align(irb, scope, node, tld, arg1_value);
                } else if (builtin_fn->id == BuiltinFnIdSetGlobalSection) {
                    return ir_build_set_global_section(irb, scope, node, tld, arg1_value);
                } else if (builtin_fn->id == BuiltinFnIdSetGlobalLinkage) {
                    return ir_build_set_global_linkage(irb, scope, node, tld, arg1_value);
                } else {
                    zig_unreachable();
                }
            }
        case BuiltinFnIdPanic:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                return ir_build_panic(irb, scope, node, arg0_value);
            }
        case BuiltinFnIdPtrCast:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                return ir_build_ptr_cast(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdIntToPtr:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                AstNode *arg1_node = node->data.fn_call_expr.params.at(1);
                IrInstruction *arg1_value = ir_gen_node(irb, arg1_node, scope);
                if (arg1_value == irb->codegen->invalid_instruction)
                    return arg1_value;

                return ir_build_int_to_ptr(irb, scope, node, arg0_value, arg1_value);
            }
        case BuiltinFnIdEnumTagName:
            {
                AstNode *arg0_node = node->data.fn_call_expr.params.at(0);
                IrInstruction *arg0_value = ir_gen_node(irb, arg0_node, scope);
                if (arg0_value == irb->codegen->invalid_instruction)
                    return arg0_value;

                IrInstruction *actual_tag = ir_build_enum_tag(irb, scope, node, arg0_value);
                return ir_build_enum_tag_name(irb, scope, node, actual_tag);
            }
    }
    zig_unreachable();
}

static IrInstruction *ir_gen_fn_call(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeFnCallExpr);

    if (node->data.fn_call_expr.is_builtin)
        return ir_gen_builtin_fn_call(irb, scope, node);

    AstNode *fn_ref_node = node->data.fn_call_expr.fn_ref_expr;
    IrInstruction *fn_ref = ir_gen_node(irb, fn_ref_node, scope);
    if (fn_ref == irb->codegen->invalid_instruction)
        return fn_ref;

    size_t arg_count = node->data.fn_call_expr.params.length;
    IrInstruction **args = allocate<IrInstruction*>(arg_count);
    for (size_t i = 0; i < arg_count; i += 1) {
        AstNode *arg_node = node->data.fn_call_expr.params.at(i);
        args[i] = ir_gen_node(irb, arg_node, scope);
        if (args[i] == irb->codegen->invalid_instruction)
            return args[i];
    }

    return ir_build_call(irb, scope, node, nullptr, fn_ref, arg_count, args, false, false);
}

static IrInstruction *ir_gen_if_bool_expr(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeIfBoolExpr);

    IrInstruction *condition = ir_gen_node(irb, node->data.if_bool_expr.condition, scope);
    if (condition == irb->codegen->invalid_instruction)
        return condition;

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, scope, node, condition);
    }

    AstNode *then_node = node->data.if_bool_expr.then_block;
    AstNode *else_node = node->data.if_bool_expr.else_node;

    IrBasicBlock *then_block = ir_build_basic_block(irb, scope, "Then");
    IrBasicBlock *else_block = ir_build_basic_block(irb, scope, "Else");
    IrBasicBlock *endif_block = ir_build_basic_block(irb, scope, "EndIf");

    ir_build_cond_br(irb, scope, condition->source_node, condition, then_block, else_block, is_comptime);

    ir_set_cursor_at_end(irb, then_block);
    IrInstruction *then_expr_result = ir_gen_node(irb, then_node, scope);
    if (then_expr_result == irb->codegen->invalid_instruction)
        return then_expr_result;
    IrBasicBlock *after_then_block = irb->current_basic_block;
    if (!instr_is_unreachable(then_expr_result))
        ir_mark_gen(ir_build_br(irb, scope, node, endif_block, is_comptime));

    ir_set_cursor_at_end(irb, else_block);
    IrInstruction *else_expr_result;
    if (else_node) {
        else_expr_result = ir_gen_node(irb, else_node, scope);
        if (else_expr_result == irb->codegen->invalid_instruction)
            return else_expr_result;
    } else {
        else_expr_result = ir_build_const_void(irb, scope, node);
    }
    IrBasicBlock *after_else_block = irb->current_basic_block;
    if (!instr_is_unreachable(else_expr_result))
        ir_mark_gen(ir_build_br(irb, scope, node, endif_block, is_comptime));

    ir_set_cursor_at_end(irb, endif_block);
    IrInstruction **incoming_values = allocate<IrInstruction *>(2);
    incoming_values[0] = then_expr_result;
    incoming_values[1] = else_expr_result;
    IrBasicBlock **incoming_blocks = allocate<IrBasicBlock *>(2);
    incoming_blocks[0] = after_then_block;
    incoming_blocks[1] = after_else_block;

    return ir_build_phi(irb, scope, node, 2, incoming_blocks, incoming_values);
}

static IrInstruction *ir_gen_prefix_op_id_lval(IrBuilder *irb, Scope *scope, AstNode *node, IrUnOp op_id, LVal lval) {
    assert(node->type == NodeTypePrefixOpExpr);
    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;

    IrInstruction *value = ir_gen_node_extra(irb, expr_node, scope, lval);
    if (value == irb->codegen->invalid_instruction)
        return value;

    return ir_build_un_op(irb, scope, node, op_id, value);
}

static IrInstruction *ir_gen_prefix_op_id(IrBuilder *irb, Scope *scope, AstNode *node, IrUnOp op_id) {
    return ir_gen_prefix_op_id_lval(irb, scope, node, op_id, LVAL_NONE);
}

static IrInstruction *ir_lval_wrap(IrBuilder *irb, Scope *scope, IrInstruction *value, LVal lval) {
    if (!lval.is_ptr)
        return value;
    if (value == irb->codegen->invalid_instruction)
        return value;

    // We needed a pointer to a value, but we got a value. So we create
    // an instruction which just makes a const pointer of it.
    return ir_build_ref(irb, scope, value->source_node, value, lval.is_const, lval.is_volatile);
}

static IrInstruction *ir_gen_address_of(IrBuilder *irb, Scope *scope, AstNode *node,
        bool is_const, bool is_volatile, LVal lval)
{
    assert(node->type == NodeTypePrefixOpExpr);
    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;

    IrInstruction *value = ir_gen_node_extra(irb, expr_node, scope, make_lval_addr(is_const, is_volatile));
    if (value == irb->codegen->invalid_instruction)
        return value;

    return ir_lval_wrap(irb, scope, value, lval);
}

static IrInstruction *ir_gen_err_assert_ok(IrBuilder *irb, Scope *scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypePrefixOpExpr);
    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;

    IrInstruction *err_union_ptr = ir_gen_node_extra(irb, expr_node, scope, LVAL_PTR);
    if (err_union_ptr == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *payload_ptr = ir_build_unwrap_err_payload(irb, scope, node, err_union_ptr, true);
    if (payload_ptr == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    if (lval.is_ptr)
        return payload_ptr;

    return ir_build_load_ptr(irb, scope, node, payload_ptr);
}

static IrInstruction *ir_gen_maybe_assert_ok(IrBuilder *irb, Scope *scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypePrefixOpExpr);
    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;

    IrInstruction *maybe_ptr = ir_gen_node_extra(irb, expr_node, scope, LVAL_PTR);
    if (maybe_ptr == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *unwrapped_ptr = ir_build_unwrap_maybe(irb, scope, node, maybe_ptr, true);
    if (lval.is_ptr)
        return unwrapped_ptr;

    return ir_build_load_ptr(irb, scope, node, unwrapped_ptr);
}

static IrInstruction *ir_gen_bool_not(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypePrefixOpExpr);
    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;

    IrInstruction *value = ir_gen_node(irb, expr_node, scope);
    if (value == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    return ir_build_bool_not(irb, scope, node, value);
}

static IrInstruction *ir_gen_prefix_op_expr(IrBuilder *irb, Scope *scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypePrefixOpExpr);

    PrefixOp prefix_op = node->data.prefix_op_expr.prefix_op;

    switch (prefix_op) {
        case PrefixOpInvalid:
            zig_unreachable();
        case PrefixOpBoolNot:
            return ir_lval_wrap(irb, scope, ir_gen_bool_not(irb, scope, node), lval);
        case PrefixOpBinNot:
            return ir_lval_wrap(irb, scope, ir_gen_prefix_op_id(irb, scope, node, IrUnOpBinNot), lval);
        case PrefixOpNegation:
            return ir_lval_wrap(irb, scope, ir_gen_prefix_op_id(irb, scope, node, IrUnOpNegation), lval);
        case PrefixOpNegationWrap:
            return ir_lval_wrap(irb, scope, ir_gen_prefix_op_id(irb, scope, node, IrUnOpNegationWrap), lval);
        case PrefixOpAddressOf:
            return ir_gen_address_of(irb, scope, node, false, false, lval);
        case PrefixOpConstAddressOf:
            return ir_gen_address_of(irb, scope, node, true, false, lval);
        case PrefixOpVolatileAddressOf:
            return ir_gen_address_of(irb, scope, node, false, true, lval);
        case PrefixOpConstVolatileAddressOf:
            return ir_gen_address_of(irb, scope, node, true, true, lval);
        case PrefixOpDereference:
            return ir_gen_prefix_op_id_lval(irb, scope, node, IrUnOpDereference, lval);
        case PrefixOpMaybe:
            return ir_lval_wrap(irb, scope, ir_gen_prefix_op_id(irb, scope, node, IrUnOpMaybe), lval);
        case PrefixOpError:
            return ir_lval_wrap(irb, scope, ir_gen_prefix_op_id(irb, scope, node, IrUnOpError), lval);
        case PrefixOpUnwrapError:
            return ir_gen_err_assert_ok(irb, scope, node, lval);
        case PrefixOpUnwrapMaybe:
            return ir_gen_maybe_assert_ok(irb, scope, node, lval);
    }
    zig_unreachable();
}

static IrInstruction *ir_gen_container_init_expr(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeContainerInitExpr);

    AstNodeContainerInitExpr *container_init_expr = &node->data.container_init_expr;
    ContainerInitKind kind = container_init_expr->kind;

    IrInstruction *container_type = ir_gen_node(irb, container_init_expr->type, scope);
    if (container_type == irb->codegen->invalid_instruction)
        return container_type;

    if (kind == ContainerInitKindStruct) {
        size_t field_count = container_init_expr->entries.length;
        IrInstructionContainerInitFieldsField *fields = allocate<IrInstructionContainerInitFieldsField>(field_count);
        for (size_t i = 0; i < field_count; i += 1) {
            AstNode *entry_node = container_init_expr->entries.at(i);
            assert(entry_node->type == NodeTypeStructValueField);

            Buf *name = entry_node->data.struct_val_field.name;
            AstNode *expr_node = entry_node->data.struct_val_field.expr;
            IrInstruction *expr_value = ir_gen_node(irb, expr_node, scope);
            if (expr_value == irb->codegen->invalid_instruction)
                return expr_value;

            fields[i].name = name;
            fields[i].value = expr_value;
            fields[i].source_node = entry_node;
        }
        return ir_build_container_init_fields(irb, scope, node, container_type, field_count, fields);
    } else if (kind == ContainerInitKindArray) {
        size_t item_count = container_init_expr->entries.length;
        IrInstruction **values = allocate<IrInstruction *>(item_count);
        for (size_t i = 0; i < item_count; i += 1) {
            AstNode *expr_node = container_init_expr->entries.at(i);
            IrInstruction *expr_value = ir_gen_node(irb, expr_node, scope);
            if (expr_value == irb->codegen->invalid_instruction)
                return expr_value;

            values[i] = expr_value;
        }
        return ir_build_container_init_list(irb, scope, node, container_type, item_count, values);
    } else {
        zig_unreachable();
    }
}

static IrInstruction *ir_gen_var_decl(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeVariableDeclaration);

    AstNodeVariableDeclaration *variable_declaration = &node->data.variable_declaration;

    IrInstruction *type_instruction;
    if (variable_declaration->type != nullptr) {
        type_instruction = ir_gen_node(irb, variable_declaration->type, scope);
        if (type_instruction == irb->codegen->invalid_instruction)
            return type_instruction;
    } else {
        type_instruction = nullptr;
    }

    bool is_shadowable = false;
    bool is_const = variable_declaration->is_const;
    bool is_extern = variable_declaration->is_extern;
    IrInstruction *is_comptime = ir_build_const_bool(irb, scope, node,
        ir_should_inline(irb->exec, scope) || variable_declaration->is_inline);
    VariableTableEntry *var = ir_create_var(irb, node, scope, variable_declaration->symbol,
        is_const, is_const, is_shadowable, is_comptime);
    // we detect IrInstructionIdDeclVar in gen_block to make sure the next node
    // is inside var->child_scope

    if (!is_extern && !variable_declaration->expr) {
        var->value->type = irb->codegen->builtin_types.entry_invalid;
        add_node_error(irb->codegen, node, buf_sprintf("variables must be initialized"));
        return irb->codegen->invalid_instruction;
    }

    IrInstruction *init_value = ir_gen_node(irb, variable_declaration->expr, scope);
    if (init_value == irb->codegen->invalid_instruction)
        return init_value;

    return ir_build_var_decl(irb, scope, node, var, type_instruction, init_value);
}

static IrInstruction *ir_gen_while_expr(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeWhileExpr);

    AstNode *continue_expr_node = node->data.while_expr.continue_expr;

    IrBasicBlock *cond_block = ir_build_basic_block(irb, scope, "WhileCond");
    IrBasicBlock *body_block = ir_build_basic_block(irb, scope, "WhileBody");
    IrBasicBlock *continue_block = continue_expr_node ?
        ir_build_basic_block(irb, scope, "WhileContinue") : cond_block;
    IrBasicBlock *end_block = ir_build_basic_block(irb, scope, "WhileEnd");

    IrInstruction *is_comptime = ir_build_const_bool(irb, scope, node,
        ir_should_inline(irb->exec, scope) || node->data.while_expr.is_inline);
    ir_build_br(irb, scope, node, cond_block, is_comptime);

    if (continue_expr_node) {
        ir_set_cursor_at_end(irb, continue_block);
        IrInstruction *expr_result = ir_gen_node(irb, continue_expr_node, scope);
        if (expr_result == irb->codegen->invalid_instruction)
            return expr_result;
        if (!instr_is_unreachable(expr_result))
            ir_mark_gen(ir_build_br(irb, scope, node, cond_block, is_comptime));
    }

    ir_set_cursor_at_end(irb, cond_block);
    IrInstruction *cond_val = ir_gen_node(irb, node->data.while_expr.condition, scope);
    if (cond_val == irb->codegen->invalid_instruction)
        return cond_val;
    if (!instr_is_unreachable(cond_val)) {
        ir_mark_gen(ir_build_cond_br(irb, scope, node->data.while_expr.condition, cond_val,
                    body_block, end_block, is_comptime));
    }

    ir_set_cursor_at_end(irb, body_block);

    LoopStackItem *loop_stack_item = irb->loop_stack.add_one();
    loop_stack_item->break_block = end_block;
    loop_stack_item->continue_block = continue_block;
    loop_stack_item->is_comptime = is_comptime;
    IrInstruction *body_result = ir_gen_node(irb, node->data.while_expr.body, scope);
    if (body_result == irb->codegen->invalid_instruction)
        return body_result;
    irb->loop_stack.pop();

    if (!instr_is_unreachable(body_result))
        ir_mark_gen(ir_build_br(irb, scope, node, continue_block, is_comptime));
    ir_set_cursor_at_end(irb, end_block);

    return ir_build_const_void(irb, scope, node);
}

static IrInstruction *ir_gen_for_expr(IrBuilder *irb, Scope *parent_scope, AstNode *node) {
    assert(node->type == NodeTypeForExpr);

    AstNode *array_node = node->data.for_expr.array_expr;
    AstNode *elem_node = node->data.for_expr.elem_node;
    AstNode *index_node = node->data.for_expr.index_node;
    AstNode *body_node = node->data.for_expr.body;

    if (!elem_node) {
        add_node_error(irb->codegen, node, buf_sprintf("for loop expression missing element parameter"));
        return irb->codegen->invalid_instruction;
    }
    assert(elem_node->type == NodeTypeSymbol);

    IrInstruction *array_val_ptr = ir_gen_node_extra(irb, array_node, parent_scope, LVAL_PTR);
    if (array_val_ptr == irb->codegen->invalid_instruction)
        return array_val_ptr;

    IrInstruction *array_val = ir_build_load_ptr(irb, parent_scope, array_node, array_val_ptr);

    IrInstruction *pointer_type = ir_build_to_ptr_type(irb, parent_scope, array_node, array_val);
    IrInstruction *elem_var_type;
    if (node->data.for_expr.elem_is_ptr) {
        elem_var_type = pointer_type;
    } else {
        elem_var_type = ir_build_ptr_type_child(irb, parent_scope, elem_node, pointer_type);
    }

    IrInstruction *is_comptime = ir_build_const_bool(irb, parent_scope, node,
        ir_should_inline(irb->exec, parent_scope) || node->data.for_expr.is_inline);

    Scope *child_scope = create_loop_scope(node, parent_scope);

    // TODO make it an error to write to element variable or i variable.
    Buf *elem_var_name = elem_node->data.symbol_expr.symbol;
    VariableTableEntry *elem_var = ir_create_var(irb, elem_node, child_scope, elem_var_name, true, false, false, is_comptime);
    child_scope = elem_var->child_scope;

    IrInstruction *undefined_value = ir_build_const_undefined(irb, child_scope, elem_node);
    ir_build_var_decl(irb, child_scope, elem_node, elem_var, elem_var_type, undefined_value);
    IrInstruction *elem_var_ptr = ir_build_var_ptr(irb, child_scope, node, elem_var, false, false);

    AstNode *index_var_source_node;
    VariableTableEntry *index_var;
    if (index_node) {
        index_var_source_node = index_node;
        Buf *index_var_name = index_node->data.symbol_expr.symbol;
        index_var = ir_create_var(irb, index_node, child_scope, index_var_name, true, false, false, is_comptime);
    } else {
        index_var_source_node = node;
        index_var = ir_create_var(irb, node, child_scope, nullptr, true, false, true, is_comptime);
    }
    child_scope = index_var->child_scope;

    IrInstruction *usize = ir_build_const_type(irb, child_scope, node, irb->codegen->builtin_types.entry_usize);
    IrInstruction *zero = ir_build_const_usize(irb, child_scope, node, 0);
    IrInstruction *one = ir_build_const_usize(irb, child_scope, node, 1);
    ir_build_var_decl(irb, child_scope, index_var_source_node, index_var, usize, zero);
    IrInstruction *index_ptr = ir_build_var_ptr(irb, child_scope, node, index_var, false, false);


    IrBasicBlock *cond_block = ir_build_basic_block(irb, child_scope, "ForCond");
    IrBasicBlock *body_block = ir_build_basic_block(irb, child_scope, "ForBody");
    IrBasicBlock *end_block = ir_build_basic_block(irb, child_scope, "ForEnd");
    IrBasicBlock *continue_block = ir_build_basic_block(irb, child_scope, "ForContinue");

    IrInstruction *len_val = ir_build_array_len(irb, child_scope, node, array_val);
    ir_build_br(irb, child_scope, node, cond_block, is_comptime);

    ir_set_cursor_at_end(irb, cond_block);
    IrInstruction *index_val = ir_build_load_ptr(irb, child_scope, node, index_ptr);
    IrInstruction *cond = ir_build_bin_op(irb, child_scope, node, IrBinOpCmpLessThan, index_val, len_val, false);
    ir_mark_gen(ir_build_cond_br(irb, child_scope, node, cond, body_block, end_block, is_comptime));

    ir_set_cursor_at_end(irb, body_block);
    IrInstruction *elem_ptr = ir_build_elem_ptr(irb, child_scope, node, array_val_ptr, index_val, false);
    IrInstruction *elem_val;
    if (node->data.for_expr.elem_is_ptr) {
        elem_val = elem_ptr;
    } else {
        elem_val = ir_build_load_ptr(irb, child_scope, node, elem_ptr);
    }
    ir_mark_gen(ir_build_store_ptr(irb, child_scope, node, elem_var_ptr, elem_val));

    LoopStackItem *loop_stack_item = irb->loop_stack.add_one();
    loop_stack_item->break_block = end_block;
    loop_stack_item->continue_block = continue_block;
    loop_stack_item->is_comptime = is_comptime;
    IrInstruction *body_result = ir_gen_node(irb, body_node, child_scope);
    irb->loop_stack.pop();

    if (!instr_is_unreachable(body_result))
        ir_mark_gen(ir_build_br(irb, child_scope, node, continue_block, is_comptime));

    ir_set_cursor_at_end(irb, continue_block);
    IrInstruction *new_index_val = ir_build_bin_op(irb, child_scope, node, IrBinOpAdd, index_val, one, false);
    ir_mark_gen(ir_build_store_ptr(irb, child_scope, node, index_ptr, new_index_val));
    ir_build_br(irb, child_scope, node, cond_block, is_comptime);

    ir_set_cursor_at_end(irb, end_block);
    return ir_build_const_void(irb, child_scope, node);

}

static IrInstruction *ir_gen_this_literal(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeThisLiteral);

    if (!scope->parent)
        return ir_build_const_import(irb, scope, node, node->owner);

    FnTableEntry *fn_entry = scope_get_fn_if_root(scope);
    if (fn_entry)
        return ir_build_const_fn(irb, scope, node, fn_entry);

    while (scope->id != ScopeIdBlock && scope->id != ScopeIdDecls) {
        scope = scope->parent;
    }

    if (scope->id == ScopeIdDecls) {
        ScopeDecls *decls_scope = (ScopeDecls *)scope;
        TypeTableEntry *container_type = decls_scope->container_type;
        assert(container_type);
        return ir_build_const_type(irb, scope, node, container_type);
    }

    if (scope->id == ScopeIdBlock)
        return ir_build_const_scope(irb, scope, node, scope);

    zig_unreachable();
}

static IrInstruction *ir_gen_bool_literal(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeBoolLiteral);
    return ir_build_const_bool(irb, scope, node, node->data.bool_literal.value);
}

static IrInstruction *ir_gen_string_literal(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeStringLiteral);

    if (node->data.string_literal.c) {
        return ir_build_const_c_str_lit(irb, scope, node, node->data.string_literal.buf);
    } else {
        return ir_build_const_str_lit(irb, scope, node, node->data.string_literal.buf);
    }
}

static IrInstruction *ir_gen_array_type(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeArrayType);

    AstNode *size_node = node->data.array_type.size;
    AstNode *child_type_node = node->data.array_type.child_type;
    bool is_const = node->data.array_type.is_const;

    if (size_node) {
        if (is_const) {
            add_node_error(irb->codegen, node, buf_create_from_str("const qualifier invalid on array type"));
            return irb->codegen->invalid_instruction;
        }

        IrInstruction *size_value = ir_gen_node(irb, size_node, scope);
        if (size_value == irb->codegen->invalid_instruction)
            return size_value;

        IrInstruction *child_type = ir_gen_node(irb, child_type_node, scope);
        if (child_type == irb->codegen->invalid_instruction)
            return child_type;

        return ir_build_array_type(irb, scope, node, size_value, child_type);
    } else {
        IrInstruction *child_type = ir_gen_node(irb, child_type_node, scope);
        if (child_type == irb->codegen->invalid_instruction)
            return child_type;

        return ir_build_slice_type(irb, scope, node, is_const, child_type);
    }
}

static IrInstruction *ir_gen_undefined_literal(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeUndefinedLiteral);
    return ir_build_const_undefined(irb, scope, node);
}

static IrInstruction *ir_gen_asm_expr(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeAsmExpr);

    IrInstruction **input_list = allocate<IrInstruction *>(node->data.asm_expr.input_list.length);
    IrInstruction **output_types = allocate<IrInstruction *>(node->data.asm_expr.output_list.length);
    VariableTableEntry **output_vars = allocate<VariableTableEntry *>(node->data.asm_expr.output_list.length);
    size_t return_count = 0;
    bool is_volatile = node->data.asm_expr.is_volatile;
    if (!is_volatile && node->data.asm_expr.output_list.length == 0) {
        add_node_error(irb->codegen, node,
                buf_sprintf("assembly expression with no output must be marked volatile"));
        return irb->codegen->invalid_instruction;
    }
    for (size_t i = 0; i < node->data.asm_expr.output_list.length; i += 1) {
        AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
        if (asm_output->return_type) {
            return_count += 1;

            IrInstruction *return_type = ir_gen_node(irb, asm_output->return_type, scope);
            if (return_type == irb->codegen->invalid_instruction)
                return irb->codegen->invalid_instruction;
            if (return_count > 1) {
                add_node_error(irb->codegen, node,
                        buf_sprintf("inline assembly allows up to one output value"));
                return irb->codegen->invalid_instruction;
            }
            output_types[i] = return_type;
        } else {
            Buf *variable_name = asm_output->variable_name;
            VariableTableEntry *var = find_variable(irb->codegen, scope, variable_name);
            if (var) {
                output_vars[i] = var;
            } else {
                add_node_error(irb->codegen, node,
                        buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
                return irb->codegen->invalid_instruction;
            }
        }
    }
    for (size_t i = 0; i < node->data.asm_expr.input_list.length; i += 1) {
        AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
        IrInstruction *input_value = ir_gen_node(irb, asm_input->expr, scope);
        if (input_value == irb->codegen->invalid_instruction)
            return irb->codegen->invalid_instruction;

        input_list[i] = input_value;
    }

    return ir_build_asm(irb, scope, node, input_list, output_types, output_vars, return_count, is_volatile);
}

static IrInstruction *ir_gen_if_var_expr(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeIfVarExpr);

    AstNodeVariableDeclaration *var_decl = &node->data.if_var_expr.var_decl;
    AstNode *expr_node = var_decl->expr;
    AstNode *then_node = node->data.if_var_expr.then_block;
    AstNode *else_node = node->data.if_var_expr.else_node;
    bool var_is_ptr = node->data.if_var_expr.var_is_ptr;

    IrInstruction *maybe_val_ptr = ir_gen_node_extra(irb, expr_node, scope, LVAL_PTR);
    if (maybe_val_ptr == irb->codegen->invalid_instruction)
        return maybe_val_ptr;

    IrInstruction *maybe_val = ir_build_load_ptr(irb, scope, node, maybe_val_ptr);
    IrInstruction *is_non_null = ir_build_test_nonnull(irb, scope, node, maybe_val);

    IrBasicBlock *then_block = ir_build_basic_block(irb, scope, "MaybeThen");
    IrBasicBlock *else_block = ir_build_basic_block(irb, scope, "MaybeElse");
    IrBasicBlock *endif_block = ir_build_basic_block(irb, scope, "MaybeEndIf");

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, scope, node, is_non_null);
    }
    ir_build_cond_br(irb, scope, node, is_non_null, then_block, else_block, is_comptime);

    ir_set_cursor_at_end(irb, then_block);
    IrInstruction *var_type = nullptr;
    if (var_decl->type) {
        var_type = ir_gen_node(irb, var_decl->type, scope);
        if (var_type == irb->codegen->invalid_instruction)
            return irb->codegen->invalid_instruction;
    }
    bool is_shadowable = false;
    bool is_const = var_decl->is_const;
    VariableTableEntry *var = ir_create_var(irb, node, scope,
            var_decl->symbol, is_const, is_const, is_shadowable, is_comptime);

    IrInstruction *var_ptr_value = ir_build_unwrap_maybe(irb, scope, node, maybe_val_ptr, false);
    IrInstruction *var_value = var_is_ptr ? var_ptr_value : ir_build_load_ptr(irb, scope, node, var_ptr_value);
    ir_build_var_decl(irb, scope, node, var, var_type, var_value);
    IrInstruction *then_expr_result = ir_gen_node(irb, then_node, var->child_scope);
    if (then_expr_result == irb->codegen->invalid_instruction)
        return then_expr_result;
    IrBasicBlock *after_then_block = irb->current_basic_block;
    if (!instr_is_unreachable(then_expr_result))
        ir_mark_gen(ir_build_br(irb, scope, node, endif_block, is_comptime));

    ir_set_cursor_at_end(irb, else_block);
    IrInstruction *else_expr_result;
    if (else_node) {
        else_expr_result = ir_gen_node(irb, else_node, scope);
        if (else_expr_result == irb->codegen->invalid_instruction)
            return else_expr_result;
    } else {
        else_expr_result = ir_build_const_void(irb, scope, node);
    }
    IrBasicBlock *after_else_block = irb->current_basic_block;
    if (!instr_is_unreachable(else_expr_result))
        ir_mark_gen(ir_build_br(irb, scope, node, endif_block, is_comptime));

    ir_set_cursor_at_end(irb, endif_block);
    IrInstruction **incoming_values = allocate<IrInstruction *>(2);
    incoming_values[0] = then_expr_result;
    incoming_values[1] = else_expr_result;
    IrBasicBlock **incoming_blocks = allocate<IrBasicBlock *>(2);
    incoming_blocks[0] = after_then_block;
    incoming_blocks[1] = after_else_block;

    return ir_build_phi(irb, scope, node, 2, incoming_blocks, incoming_values);
}

static IrInstruction *ir_gen_try_expr(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeTryExpr);

    AstNode *target_node = node->data.try_expr.target_node;
    AstNode *then_node = node->data.try_expr.then_node;
    AstNode *else_node = node->data.try_expr.else_node;
    bool var_is_ptr = node->data.try_expr.var_is_ptr;
    bool var_is_const = node->data.try_expr.var_is_const;
    Buf *var_symbol = node->data.try_expr.var_symbol;
    Buf *err_symbol = node->data.try_expr.err_symbol;

    IrInstruction *err_val_ptr = ir_gen_node_extra(irb, target_node, scope, LVAL_PTR);
    if (err_val_ptr == irb->codegen->invalid_instruction)
        return err_val_ptr;

    IrInstruction *err_val = ir_build_load_ptr(irb, scope, node, err_val_ptr);
    IrInstruction *is_err = ir_build_test_err(irb, scope, node, err_val);

    IrBasicBlock *ok_block = ir_build_basic_block(irb, scope, "TryOk");
    IrBasicBlock *else_block = ir_build_basic_block(irb, scope, "TryElse");
    IrBasicBlock *endif_block = ir_build_basic_block(irb, scope, "TryEnd");

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, scope, node, is_err);
    }
    ir_build_cond_br(irb, scope, node, is_err, else_block, ok_block, is_comptime);

    ir_set_cursor_at_end(irb, ok_block);

    Scope *var_scope;
    if (var_symbol) {
        IrInstruction *var_type = nullptr;
        bool is_shadowable = false;
        VariableTableEntry *var = ir_create_var(irb, node, scope,
                var_symbol, var_is_const, var_is_const, is_shadowable, is_comptime);

        IrInstruction *var_ptr_value = ir_build_unwrap_err_payload(irb, scope, node, err_val_ptr, false);
        IrInstruction *var_value = var_is_ptr ? var_ptr_value : ir_build_load_ptr(irb, scope, node, var_ptr_value);
        ir_build_var_decl(irb, scope, node, var, var_type, var_value);
        var_scope = var->child_scope;
    } else {
        var_scope = scope;
    }
    IrInstruction *then_expr_result = ir_gen_node(irb, then_node, var_scope);
    if (then_expr_result == irb->codegen->invalid_instruction)
        return then_expr_result;
    IrBasicBlock *after_then_block = irb->current_basic_block;
    if (!instr_is_unreachable(then_expr_result))
        ir_mark_gen(ir_build_br(irb, scope, node, endif_block, is_comptime));

    ir_set_cursor_at_end(irb, else_block);

    IrInstruction *else_expr_result;
    if (else_node) {
        Scope *err_var_scope;
        if (err_symbol) {
            IrInstruction *var_type = nullptr;
            bool is_shadowable = false;
            bool is_const = true;
            VariableTableEntry *var = ir_create_var(irb, node, scope,
                    err_symbol, is_const, is_const, is_shadowable, is_comptime);

            IrInstruction *var_value = ir_build_unwrap_err_code(irb, scope, node, err_val_ptr);
            ir_build_var_decl(irb, scope, node, var, var_type, var_value);
            err_var_scope = var->child_scope;
        } else {
            err_var_scope = scope;
        }
        else_expr_result = ir_gen_node(irb, else_node, err_var_scope);
        if (else_expr_result == irb->codegen->invalid_instruction)
            return else_expr_result;
    } else {
        else_expr_result = ir_build_const_void(irb, scope, node);
    }
    IrBasicBlock *after_else_block = irb->current_basic_block;
    if (!instr_is_unreachable(else_expr_result))
        ir_mark_gen(ir_build_br(irb, scope, node, endif_block, is_comptime));

    ir_set_cursor_at_end(irb, endif_block);
    IrInstruction **incoming_values = allocate<IrInstruction *>(2);
    incoming_values[0] = then_expr_result;
    incoming_values[1] = else_expr_result;
    IrBasicBlock **incoming_blocks = allocate<IrBasicBlock *>(2);
    incoming_blocks[0] = after_then_block;
    incoming_blocks[1] = after_else_block;

    return ir_build_phi(irb, scope, node, 2, incoming_blocks, incoming_values);
}

static bool ir_gen_switch_prong_expr(IrBuilder *irb, Scope *scope, AstNode *switch_node, AstNode *prong_node,
        IrBasicBlock *end_block, IrInstruction *is_comptime, IrInstruction *target_value_ptr, IrInstruction *prong_value,
        ZigList<IrBasicBlock *> *incoming_blocks, ZigList<IrInstruction *> *incoming_values)
{
    assert(switch_node->type == NodeTypeSwitchExpr);
    assert(prong_node->type == NodeTypeSwitchProng);

    AstNode *expr_node = prong_node->data.switch_prong.expr;
    AstNode *var_symbol_node = prong_node->data.switch_prong.var_symbol;
    Scope *child_scope;
    if (var_symbol_node) {
        assert(var_symbol_node->type == NodeTypeSymbol);
        Buf *var_name = var_symbol_node->data.symbol_expr.symbol;
        bool var_is_ptr = prong_node->data.switch_prong.var_is_ptr;

        bool is_shadowable = false;
        bool is_const = true;
        VariableTableEntry *var = ir_create_var(irb, var_symbol_node, scope,
                var_name, is_const, is_const, is_shadowable, is_comptime);
        child_scope = var->child_scope;
        IrInstruction *var_value;
        if (prong_value) {
            IrInstruction *var_ptr_value = ir_build_switch_var(irb, scope, var_symbol_node, target_value_ptr, prong_value);
            var_value = var_is_ptr ? var_ptr_value : ir_build_load_ptr(irb, scope, var_symbol_node, var_ptr_value);
        } else {
            var_value = var_is_ptr ? target_value_ptr : ir_build_load_ptr(irb, scope, var_symbol_node, target_value_ptr);
        }
        IrInstruction *var_type = nullptr; // infer the type
        ir_build_var_decl(irb, scope, var_symbol_node, var, var_type, var_value);
    } else {
        child_scope = scope;
    }

    IrInstruction *expr_result = ir_gen_node(irb, expr_node, child_scope);
    if (expr_result == irb->codegen->invalid_instruction)
        return false;
    if (!instr_is_unreachable(expr_result))
        ir_mark_gen(ir_build_br(irb, scope, switch_node, end_block, is_comptime));
    incoming_blocks->append(irb->current_basic_block);
    incoming_values->append(expr_result);
    return true;
}

static IrInstruction *ir_gen_switch_expr(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeSwitchExpr);

    AstNode *target_node = node->data.switch_expr.expr;
    IrInstruction *target_value_ptr = ir_gen_node_extra(irb, target_node, scope, LVAL_PTR);
    if (target_value_ptr == irb->codegen->invalid_instruction)
        return target_value_ptr;
    IrInstruction *target_value = ir_build_switch_target(irb, scope, node, target_value_ptr);

    IrBasicBlock *else_block = ir_build_basic_block(irb, scope, "SwitchElse");
    IrBasicBlock *end_block = ir_build_basic_block(irb, scope, "SwitchEnd");

    size_t prong_count = node->data.switch_expr.prongs.length;
    ZigList<IrInstructionSwitchBrCase> cases = {0};

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, scope, node, target_value);
    }

    ZigList<IrInstruction *> incoming_values = {0};
    ZigList<IrBasicBlock *> incoming_blocks = {0};
    ZigList<IrInstructionCheckSwitchProngsRange> check_ranges = {0};

    Scope *comptime_scope = create_comptime_scope(node, scope);
    AstNode *else_prong = nullptr;
    for (size_t prong_i = 0; prong_i < prong_count; prong_i += 1) {
        AstNode *prong_node = node->data.switch_expr.prongs.at(prong_i);
        size_t prong_item_count = prong_node->data.switch_prong.items.length;
        if (prong_item_count == 0) {
            if (else_prong) {
                ErrorMsg *msg = add_node_error(irb->codegen, prong_node,
                        buf_sprintf("multiple else prongs in switch expression"));
                add_error_note(irb->codegen, msg, else_prong,
                        buf_sprintf("previous else prong is here"));
                return irb->codegen->invalid_instruction;
            }
            else_prong = prong_node;

            IrBasicBlock *prev_block = irb->current_basic_block;
            ir_set_cursor_at_end(irb, else_block);
            if (!ir_gen_switch_prong_expr(irb, scope, node, prong_node, end_block,
                is_comptime, target_value_ptr, nullptr, &incoming_blocks, &incoming_values))
            {
                return irb->codegen->invalid_instruction;
            }
            ir_set_cursor_at_end(irb, prev_block);
        } else {
            if (prong_node->data.switch_prong.any_items_are_range) {
                IrInstruction *ok_bit = nullptr;
                AstNode *last_item_node = nullptr;
                for (size_t item_i = 0; item_i < prong_item_count; item_i += 1) {
                    AstNode *item_node = prong_node->data.switch_prong.items.at(item_i);
                    last_item_node = item_node;
                    if (item_node->type == NodeTypeSwitchRange) {
                        AstNode *start_node = item_node->data.switch_range.start;
                        AstNode *end_node = item_node->data.switch_range.end;

                        IrInstruction *start_value = ir_gen_node(irb, start_node, comptime_scope);
                        if (start_value == irb->codegen->invalid_instruction)
                            return irb->codegen->invalid_instruction;

                        IrInstruction *end_value = ir_gen_node(irb, end_node, comptime_scope);
                        if (end_value == irb->codegen->invalid_instruction)
                            return irb->codegen->invalid_instruction;

                        IrInstructionCheckSwitchProngsRange *check_range = check_ranges.add_one();
                        check_range->start = start_value;
                        check_range->end = end_value;

                        IrInstruction *lower_range_ok = ir_build_bin_op(irb, scope, item_node, IrBinOpCmpGreaterOrEq,
                                target_value, start_value, false);
                        IrInstruction *upper_range_ok = ir_build_bin_op(irb, scope, item_node, IrBinOpCmpLessOrEq,
                                target_value, end_value, false);
                        IrInstruction *both_ok = ir_build_bin_op(irb, scope, item_node, IrBinOpBoolAnd,
                                lower_range_ok, upper_range_ok, false);
                        if (ok_bit) {
                            ok_bit = ir_build_bin_op(irb, scope, item_node, IrBinOpBoolOr, both_ok, ok_bit, false);
                        } else {
                            ok_bit = both_ok;
                        }
                    } else {
                        IrInstruction *item_value = ir_gen_node(irb, item_node, comptime_scope);
                        if (item_value == irb->codegen->invalid_instruction)
                            return irb->codegen->invalid_instruction;

                        IrInstructionCheckSwitchProngsRange *check_range = check_ranges.add_one();
                        check_range->start = item_value;
                        check_range->end = item_value;

                        IrInstruction *cmp_ok = ir_build_bin_op(irb, scope, item_node, IrBinOpCmpEq,
                                item_value, target_value, false);
                        if (ok_bit) {
                            ok_bit = ir_build_bin_op(irb, scope, item_node, IrBinOpBoolOr, cmp_ok, ok_bit, false);
                        } else {
                            ok_bit = cmp_ok;
                        }
                    }
                }

                IrBasicBlock *range_block_yes = ir_build_basic_block(irb, scope, "SwitchRangeYes");
                IrBasicBlock *range_block_no = ir_build_basic_block(irb, scope, "SwitchRangeNo");

                assert(ok_bit);
                assert(last_item_node);
                ir_mark_gen(ir_build_cond_br(irb, scope, last_item_node, ok_bit, range_block_yes,
                            range_block_no, is_comptime));

                ir_set_cursor_at_end(irb, range_block_yes);
                if (!ir_gen_switch_prong_expr(irb, scope, node, prong_node, end_block,
                    is_comptime, target_value_ptr, nullptr, &incoming_blocks, &incoming_values))
                {
                    return irb->codegen->invalid_instruction;
                }

                ir_set_cursor_at_end(irb, range_block_no);
            } else {
                IrBasicBlock *prong_block = ir_build_basic_block(irb, scope, "SwitchProng");
                IrInstruction *last_item_value = nullptr;

                for (size_t item_i = 0; item_i < prong_item_count; item_i += 1) {
                    AstNode *item_node = prong_node->data.switch_prong.items.at(item_i);
                    assert(item_node->type != NodeTypeSwitchRange);

                    IrInstruction *item_value = ir_gen_node(irb, item_node, comptime_scope);
                    if (item_value == irb->codegen->invalid_instruction)
                        return irb->codegen->invalid_instruction;

                    IrInstructionCheckSwitchProngsRange *check_range = check_ranges.add_one();
                    check_range->start = item_value;
                    check_range->end = item_value;

                    IrInstructionSwitchBrCase *this_case = cases.add_one();
                    this_case->value = item_value;
                    this_case->block = prong_block;

                    last_item_value = item_value;
                }
                IrInstruction *only_item_value = (prong_item_count == 1) ? last_item_value : nullptr;

                IrBasicBlock *prev_block = irb->current_basic_block;
                ir_set_cursor_at_end(irb, prong_block);
                if (!ir_gen_switch_prong_expr(irb, scope, node, prong_node, end_block,
                    is_comptime, target_value_ptr, only_item_value, &incoming_blocks, &incoming_values))
                {
                    return irb->codegen->invalid_instruction;
                }

                ir_set_cursor_at_end(irb, prev_block);

            }
        }
    }

    if (!else_prong) {
        ir_build_check_switch_prongs(irb, scope, node, target_value, check_ranges.items, check_ranges.length);
    }

    if (cases.length == 0) {
        ir_build_br(irb, scope, node, else_block, is_comptime);
    } else {
        ir_build_switch_br(irb, scope, node, target_value, else_block, cases.length, cases.items, is_comptime);
    }

    if (!else_prong) {
        ir_set_cursor_at_end(irb, else_block);
        ir_build_unreachable(irb, scope, node);
    }

    ir_set_cursor_at_end(irb, end_block);
    assert(incoming_blocks.length == incoming_values.length);
    return ir_build_phi(irb, scope, node, incoming_blocks.length, incoming_blocks.items, incoming_values.items);
}

static IrInstruction *ir_gen_goto(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeGoto);

    // make a placeholder unreachable statement and a note to come back and
    // replace the instruction with a branch instruction
    IrGotoItem *goto_item = irb->exec->goto_list.add_one();
    goto_item->bb = irb->current_basic_block;
    goto_item->instruction_index = irb->current_basic_block->instruction_list.length;
    goto_item->source_node = node;
    goto_item->scope = scope;

    // we don't know if we need to generate defer expressions yet
    // we do that later when we find out which label we're jumping to.
    return ir_build_unreachable(irb, scope, node);
}

static IrInstruction *ir_gen_comptime(IrBuilder *irb, Scope *parent_scope, AstNode *node, LVal lval) {
    assert(node->type == NodeTypeCompTime);

    Scope *child_scope = create_comptime_scope(node, parent_scope);
    return ir_gen_node_extra(irb, node->data.comptime_expr.expr, child_scope, lval);
}

static IrInstruction *ir_gen_break(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeBreak);

    if (irb->loop_stack.length == 0) {
        add_node_error(irb->codegen, node,
            buf_sprintf("'break' expression outside loop"));
        return irb->codegen->invalid_instruction;
    }

    LoopStackItem *loop_stack_item = &irb->loop_stack.last();

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = loop_stack_item->is_comptime;
    }

    IrBasicBlock *dest_block = loop_stack_item->break_block;
    ir_gen_defers_for_block(irb, scope, dest_block->scope, false, false);
    return ir_build_br(irb, scope, node, dest_block, is_comptime);
}

static IrInstruction *ir_gen_continue(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeContinue);

    if (irb->loop_stack.length == 0) {
        add_node_error(irb->codegen, node,
            buf_sprintf("'continue' expression outside loop"));
        return irb->codegen->invalid_instruction;
    }

    LoopStackItem *loop_stack_item = &irb->loop_stack.last();

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, scope)) {
        is_comptime = ir_build_const_bool(irb, scope, node, true);
    } else {
        is_comptime = loop_stack_item->is_comptime;
    }

    IrBasicBlock *dest_block = loop_stack_item->continue_block;
    ir_gen_defers_for_block(irb, scope, dest_block->scope, false, false);
    return ir_build_br(irb, scope, node, dest_block, is_comptime);
}

static IrInstruction *ir_gen_type_literal(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeTypeLiteral);
    return ir_build_const_type(irb, scope, node, irb->codegen->builtin_types.entry_type);
}

static IrInstruction *ir_gen_error_type(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeErrorType);
    return ir_build_const_type(irb, scope, node, irb->codegen->builtin_types.entry_pure_error);
}

static IrInstruction *ir_gen_defer(IrBuilder *irb, Scope *parent_scope, AstNode *node) {
    assert(node->type == NodeTypeDefer);

    ScopeDefer *defer_child_scope = create_defer_scope(node, parent_scope);
    node->data.defer.child_scope = &defer_child_scope->base;

    ScopeDeferExpr *defer_expr_scope = create_defer_expr_scope(node, parent_scope);
    node->data.defer.expr_scope = &defer_expr_scope->base;

    return ir_build_const_void(irb, parent_scope, node);
}

static IrInstruction *ir_gen_slice(IrBuilder *irb, Scope *scope, AstNode *node) {
    assert(node->type == NodeTypeSliceExpr);

    AstNodeSliceExpr *slice_expr = &node->data.slice_expr;
    AstNode *array_node = slice_expr->array_ref_expr;
    AstNode *start_node = slice_expr->start;
    AstNode *end_node = slice_expr->end;

    IrInstruction *ptr_value = ir_gen_node_extra(irb, array_node, scope, LVAL_PTR);
    if (ptr_value == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *start_value = ir_gen_node(irb, start_node, scope);
    if (start_value == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *end_value;
    if (end_node) {
        end_value = ir_gen_node(irb, end_node, scope);
        if (end_value == irb->codegen->invalid_instruction)
            return irb->codegen->invalid_instruction;
    } else {
        end_value = nullptr;
    }

    return ir_build_slice(irb, scope, node, ptr_value, start_value, end_value, slice_expr->is_const, true);
}

static IrInstruction *ir_gen_err_ok_or(IrBuilder *irb, Scope *parent_scope, AstNode *node) {
    assert(node->type == NodeTypeUnwrapErrorExpr);

    AstNode *op1_node = node->data.unwrap_err_expr.op1;
    AstNode *op2_node = node->data.unwrap_err_expr.op2;
    AstNode *var_node = node->data.unwrap_err_expr.symbol;

    IrInstruction *err_union_ptr = ir_gen_node_extra(irb, op1_node, parent_scope, LVAL_PTR);
    if (err_union_ptr == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    IrInstruction *err_union_val = ir_build_load_ptr(irb, parent_scope, node, err_union_ptr);
    IrInstruction *is_err = ir_build_test_err(irb, parent_scope, node, err_union_val);

    IrInstruction *is_comptime;
    if (ir_should_inline(irb->exec, parent_scope)) {
        is_comptime = ir_build_const_bool(irb, parent_scope, node, true);
    } else {
        is_comptime = ir_build_test_comptime(irb, parent_scope, node, is_err);
    }

    IrBasicBlock *ok_block = ir_build_basic_block(irb, parent_scope, "UnwrapErrOk");
    IrBasicBlock *err_block = ir_build_basic_block(irb, parent_scope, "UnwrapErrError");
    IrBasicBlock *end_block = ir_build_basic_block(irb, parent_scope, "UnwrapErrEnd");
    ir_build_cond_br(irb, parent_scope, node, is_err, err_block, ok_block, is_comptime);

    ir_set_cursor_at_end(irb, err_block);
    Scope *err_scope;
    if (var_node) {
        assert(var_node->type == NodeTypeSymbol);
        IrInstruction *var_type = ir_build_const_type(irb, parent_scope, node,
            irb->codegen->builtin_types.entry_pure_error);
        Buf *var_name = var_node->data.symbol_expr.symbol;
        bool is_const = true;
        bool is_shadowable = false;
        VariableTableEntry *var = ir_create_var(irb, node, parent_scope, var_name,
            is_const, is_const, is_shadowable, is_comptime);
        err_scope = var->child_scope;
        IrInstruction *err_val = ir_build_unwrap_err_code(irb, err_scope, node, err_union_ptr);
        ir_build_var_decl(irb, err_scope, var_node, var, var_type, err_val);
    } else {
        err_scope = parent_scope;
    }
    IrInstruction *err_result = ir_gen_node(irb, op2_node, err_scope);
    if (err_result == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;
    IrBasicBlock *after_err_block = irb->current_basic_block;
    if (!instr_is_unreachable(err_result))
        ir_mark_gen(ir_build_br(irb, err_scope, node, end_block, is_comptime));

    ir_set_cursor_at_end(irb, ok_block);
    IrInstruction *unwrapped_ptr = ir_build_unwrap_err_payload(irb, parent_scope, node, err_union_ptr, false);
    IrInstruction *unwrapped_payload = ir_build_load_ptr(irb, parent_scope, node, unwrapped_ptr);
    IrBasicBlock *after_ok_block = irb->current_basic_block;
    ir_build_br(irb, parent_scope, node, end_block, is_comptime);

    ir_set_cursor_at_end(irb, end_block);
    IrInstruction **incoming_values = allocate<IrInstruction *>(2);
    incoming_values[0] = err_result;
    incoming_values[1] = unwrapped_payload;
    IrBasicBlock **incoming_blocks = allocate<IrBasicBlock *>(2);
    incoming_blocks[0] = after_err_block;
    incoming_blocks[1] = after_ok_block;
    return ir_build_phi(irb, parent_scope, node, 2, incoming_blocks, incoming_values);
}

static bool render_instance_name_recursive(Buf *name, Scope *outer_scope, Scope *inner_scope) {
    if (inner_scope == nullptr || inner_scope == outer_scope) return false;
    bool need_comma = render_instance_name_recursive(name, outer_scope, inner_scope->parent);
    if (inner_scope->id != ScopeIdVarDecl)
        return need_comma;

    ScopeVarDecl *var_scope = (ScopeVarDecl *)inner_scope;
    if (need_comma)
        buf_append_char(name, ',');
    render_const_value(name, var_scope->var->value);
    return true;
}

static IrInstruction *ir_gen_container_decl(IrBuilder *irb, Scope *parent_scope, AstNode *node) {
    assert(node->type == NodeTypeContainerDecl);

    ContainerKind kind = node->data.container_decl.kind;
    Buf *name;
    if (irb->exec->name) {
        name = irb->exec->name;
    } else {
        FnTableEntry *fn_entry = exec_fn_entry(irb->exec);
        if (fn_entry) {
            name = buf_alloc();
            buf_append_buf(name, &fn_entry->symbol_name);
            buf_appendf(name, "(");
            render_instance_name_recursive(name, &fn_entry->fndef_scope->base, irb->exec->begin_scope);
            buf_appendf(name, ")");
        } else {
            name = buf_sprintf("(anonymous %s at %s:%zu:%zu)", container_string(kind),
                buf_ptr(node->owner->path), node->line + 1, node->column + 1);
        }
    }


    VisibMod visib_mod = VisibModPub;
    TldContainer *tld_container = allocate<TldContainer>(1);
    init_tld(&tld_container->base, TldIdContainer, name, visib_mod, node, parent_scope);

    ContainerLayout layout = node->data.container_decl.layout;
    TypeTableEntry *container_type = get_partial_container_type(irb->codegen, parent_scope,
            kind, node, buf_ptr(name), layout);
    ScopeDecls *child_scope = get_container_scope(container_type);

    tld_container->type_entry = container_type;
    tld_container->decls_scope = child_scope;

    for (size_t i = 0; i < node->data.container_decl.decls.length; i += 1) {
        AstNode *child_node = node->data.container_decl.decls.at(i);
        scan_decls(irb->codegen, child_scope, child_node);
    }
    irb->codegen->resolve_queue.append(&tld_container->base);

    return ir_build_const_type(irb, parent_scope, node, container_type);
}

static IrInstruction *ir_gen_fn_proto(IrBuilder *irb, Scope *parent_scope, AstNode *node) {
    assert(node->type == NodeTypeFnProto);

    size_t param_count = node->data.fn_proto.params.length;
    IrInstruction **param_types = allocate<IrInstruction*>(param_count);

    for (size_t i = 0; i < param_count; i += 1) {
        AstNode *param_node = node->data.fn_proto.params.at(i);
        AstNode *type_node = param_node->data.param_decl.type;
        IrInstruction *type_value = ir_gen_node(irb, type_node, parent_scope);
        if (type_value == irb->codegen->invalid_instruction)
            return irb->codegen->invalid_instruction;
        param_types[i] = type_value;
    }

    IrInstruction *return_type = ir_gen_node(irb, node->data.fn_proto.return_type, parent_scope);
    if (return_type == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    return ir_build_fn_proto(irb, parent_scope, node, param_types, return_type);
}

static IrInstruction *ir_gen_inline_expr(IrBuilder *irb, Scope *parent_scope, AstNode *node) {
    assert(node->type == NodeTypeInlineExpr);

    AstNode *body_node = node->data.inline_expr.body;

    IrInstruction *fn_ptr = ir_gen_node(irb, body_node, parent_scope);
    if (fn_ptr == irb->codegen->invalid_instruction)
        return irb->codegen->invalid_instruction;

    return ir_build_set_fn_ref_inline(irb, parent_scope, node, fn_ptr);
}


static IrInstruction *ir_gen_node_raw(IrBuilder *irb, AstNode *node, Scope *scope,
        LVal lval)
{
    assert(scope);
    switch (node->type) {
        case NodeTypeStructValueField:
        case NodeTypeRoot:
        case NodeTypeParamDecl:
        case NodeTypeUse:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeStructField:
        case NodeTypeLabel:
            zig_unreachable();
        case NodeTypeBlock:
            return ir_lval_wrap(irb, scope, ir_gen_block(irb, scope, node), lval);
        case NodeTypeBinOpExpr:
            return ir_lval_wrap(irb, scope, ir_gen_bin_op(irb, scope, node), lval);
        case NodeTypeNumberLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_num_lit(irb, scope, node), lval);
        case NodeTypeCharLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_char_lit(irb, scope, node), lval);
        case NodeTypeSymbol:
            return ir_gen_symbol(irb, scope, node, lval);
        case NodeTypeFnCallExpr:
            return ir_lval_wrap(irb, scope, ir_gen_fn_call(irb, scope, node), lval);
        case NodeTypeIfBoolExpr:
            return ir_lval_wrap(irb, scope, ir_gen_if_bool_expr(irb, scope, node), lval);
        case NodeTypePrefixOpExpr:
            return ir_gen_prefix_op_expr(irb, scope, node, lval);
        case NodeTypeContainerInitExpr:
            return ir_lval_wrap(irb, scope, ir_gen_container_init_expr(irb, scope, node), lval);
        case NodeTypeVariableDeclaration:
            return ir_lval_wrap(irb, scope, ir_gen_var_decl(irb, scope, node), lval);
        case NodeTypeWhileExpr:
            return ir_lval_wrap(irb, scope, ir_gen_while_expr(irb, scope, node), lval);
        case NodeTypeForExpr:
            return ir_lval_wrap(irb, scope, ir_gen_for_expr(irb, scope, node), lval);
        case NodeTypeArrayAccessExpr:
            return ir_gen_array_access(irb, scope, node, lval);
        case NodeTypeReturnExpr:
            return ir_gen_return(irb, scope, node, lval);
        case NodeTypeFieldAccessExpr:
            return ir_gen_field_access(irb, scope, node, lval);
        case NodeTypeThisLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_this_literal(irb, scope, node), lval);
        case NodeTypeBoolLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_bool_literal(irb, scope, node), lval);
        case NodeTypeArrayType:
            return ir_lval_wrap(irb, scope, ir_gen_array_type(irb, scope, node), lval);
        case NodeTypeStringLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_string_literal(irb, scope, node), lval);
        case NodeTypeUndefinedLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_undefined_literal(irb, scope, node), lval);
        case NodeTypeAsmExpr:
            return ir_lval_wrap(irb, scope, ir_gen_asm_expr(irb, scope, node), lval);
        case NodeTypeNullLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_null_literal(irb, scope, node), lval);
        case NodeTypeVarLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_var_literal(irb, scope, node), lval);
        case NodeTypeIfVarExpr:
            return ir_lval_wrap(irb, scope, ir_gen_if_var_expr(irb, scope, node), lval);
        case NodeTypeTryExpr:
            return ir_lval_wrap(irb, scope, ir_gen_try_expr(irb, scope, node), lval);
        case NodeTypeSwitchExpr:
            return ir_lval_wrap(irb, scope, ir_gen_switch_expr(irb, scope, node), lval);
        case NodeTypeGoto:
            return ir_lval_wrap(irb, scope, ir_gen_goto(irb, scope, node), lval);
        case NodeTypeCompTime:
            return ir_gen_comptime(irb, scope, node, lval);
        case NodeTypeTypeLiteral:
            return ir_lval_wrap(irb, scope, ir_gen_type_literal(irb, scope, node), lval);
        case NodeTypeErrorType:
            return ir_lval_wrap(irb, scope, ir_gen_error_type(irb, scope, node), lval);
        case NodeTypeBreak:
            return ir_lval_wrap(irb, scope, ir_gen_break(irb, scope, node), lval);
        case NodeTypeContinue:
            return ir_lval_wrap(irb, scope, ir_gen_continue(irb, scope, node), lval);
        case NodeTypeUnreachable:
            return ir_lval_wrap(irb, scope, ir_build_unreachable(irb, scope, node), lval);
        case NodeTypeDefer:
            return ir_lval_wrap(irb, scope, ir_gen_defer(irb, scope, node), lval);
        case NodeTypeSliceExpr:
            return ir_lval_wrap(irb, scope, ir_gen_slice(irb, scope, node), lval);
        case NodeTypeUnwrapErrorExpr:
            return ir_lval_wrap(irb, scope, ir_gen_err_ok_or(irb, scope, node), lval);
        case NodeTypeContainerDecl:
            return ir_lval_wrap(irb, scope, ir_gen_container_decl(irb, scope, node), lval);
        case NodeTypeFnProto:
            return ir_lval_wrap(irb, scope, ir_gen_fn_proto(irb, scope, node), lval);
        case NodeTypeInlineExpr:
            return ir_lval_wrap(irb, scope, ir_gen_inline_expr(irb, scope, node), lval);
        case NodeTypeFnDef:
            zig_panic("TODO IR gen NodeTypeFnDef");
        case NodeTypeFnDecl:
            zig_panic("TODO IR gen NodeTypeFnDecl");
        case NodeTypeErrorValueDecl:
            zig_panic("TODO IR gen NodeTypeErrorValueDecl");
        case NodeTypeTypeDecl:
            zig_panic("TODO IR gen NodeTypeTypeDecl");
        case NodeTypeTestDecl:
            zig_panic("TODO IR gen NodeTypeTestDecl");
    }
    zig_unreachable();
}

static IrInstruction *ir_gen_node_extra(IrBuilder *irb, AstNode *node, Scope *scope, LVal lval) {
    IrInstruction *result = ir_gen_node_raw(irb, node, scope, lval);
    irb->exec->invalid = irb->exec->invalid || (result == irb->codegen->invalid_instruction);
    return result;
}

static IrInstruction *ir_gen_node(IrBuilder *irb, AstNode *node, Scope *scope) {
    return ir_gen_node_extra(irb, node, scope, LVAL_NONE);
}

static bool ir_goto_pass2(IrBuilder *irb) {
    for (size_t i = 0; i < irb->exec->goto_list.length; i += 1) {
        IrGotoItem *goto_item = &irb->exec->goto_list.at(i);
        AstNode *source_node = goto_item->source_node;

        // Since a goto will always end a basic block, we move the "current instruction"
        // index back to over the placeholder unreachable instruction and begin overwriting
        irb->current_basic_block = goto_item->bb;
        irb->current_basic_block->instruction_list.resize(goto_item->instruction_index);

        Buf *label_name = source_node->data.goto_expr.name;
        LabelTableEntry *label = find_label(irb->exec, goto_item->scope, label_name);
        if (!label) {
            add_node_error(irb->codegen, source_node,
                buf_sprintf("no label in scope named '%s'", buf_ptr(label_name)));
            return false;
        }
        label->used = true;

        IrInstruction *is_comptime = ir_build_const_bool(irb, goto_item->scope, source_node,
            ir_should_inline(irb->exec, goto_item->scope) || source_node->data.goto_expr.is_inline);
        if (!ir_gen_defers_for_block(irb, goto_item->scope, label->bb->scope, false, false)) {
            add_node_error(irb->codegen, source_node,
                buf_sprintf("no label in scope named '%s'", buf_ptr(label_name)));
            return false;
        }
        ir_build_br(irb, goto_item->scope, source_node, label->bb, is_comptime);
    }

    for (size_t i = 0; i < irb->exec->all_labels.length; i += 1) {
        LabelTableEntry *label = irb->exec->all_labels.at(i);
        if (!label->used) {
            add_node_error(irb->codegen, label->decl_node,
                    buf_sprintf("label '%s' defined but not used",
                        buf_ptr(label->decl_node->data.label.name)));
            return false;
        }
    }

    return true;
}

bool ir_gen(CodeGen *codegen, AstNode *node, Scope *scope, IrExecutable *ir_executable) {
    assert(node->owner);

    IrBuilder ir_builder = {0};
    IrBuilder *irb = &ir_builder;

    irb->codegen = codegen;
    irb->exec = ir_executable;

    irb->current_basic_block = ir_build_basic_block(irb, scope, "Entry");
    // Entry block gets a reference because we enter it to begin.
    ir_ref_bb(irb->current_basic_block);

    IrInstruction *result = ir_gen_node_extra(irb, node, scope, LVAL_NONE);
    assert(result);
    if (irb->exec->invalid)
        return false;

    if (!instr_is_unreachable(result)) {
        ir_mark_gen(ir_build_return(irb, scope, result->source_node, result));
    }

    if (!ir_goto_pass2(irb)) {
        irb->exec->invalid = true;
        return false;
    }

    return true;
}

bool ir_gen_fn(CodeGen *codegen, FnTableEntry *fn_entry) {
    assert(fn_entry);

    IrExecutable *ir_executable = &fn_entry->ir_executable;
    AstNode *body_node = fn_entry->body_node;

    assert(fn_entry->child_scope);

    return ir_gen(codegen, body_node, fn_entry->child_scope, ir_executable);
}

static void add_call_stack_errors(CodeGen *codegen, IrExecutable *exec, ErrorMsg *err_msg, int limit) {
    if (!exec || !exec->source_node || limit < 0) return;
    add_error_note(codegen, err_msg, exec->source_node, buf_sprintf("called from here"));

    add_call_stack_errors(codegen, exec->parent_exec, err_msg, limit - 1);
}

static ErrorMsg *exec_add_error_node(CodeGen *codegen, IrExecutable *exec, AstNode *source_node, Buf *msg) {
    exec->invalid = true;
    ErrorMsg *err_msg = add_node_error(codegen, source_node, msg);
    if (exec->parent_exec) {
        add_call_stack_errors(codegen, exec, err_msg, 10);
    }
    return err_msg;
}

static ErrorMsg *ir_add_error_node(IrAnalyze *ira, AstNode *source_node, Buf *msg) {
    return exec_add_error_node(ira->codegen, ira->new_irb.exec, source_node, msg);
}

static ErrorMsg *ir_add_error(IrAnalyze *ira, IrInstruction *source_instruction, Buf *msg) {
    return ir_add_error_node(ira, source_instruction->source_node, msg);
}

static void ir_add_typedef_err_note(IrAnalyze *ira, ErrorMsg *msg, TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdTypeDecl) {
        // requires tracking source_node in the typedecl type
        zig_panic("TODO add error note about typedecls");
    }
}

static IrInstruction *ir_exec_const_result(CodeGen *codegen, IrExecutable *exec) {
    IrBasicBlock *bb = exec->basic_block_list.at(0);
    for (size_t i = 0; i < bb->instruction_list.length; i += 1) {
        IrInstruction *instruction = bb->instruction_list.at(i);
        if (instruction->id == IrInstructionIdReturn) {
            IrInstructionReturn *ret_inst = (IrInstructionReturn *)instruction;
            IrInstruction *value = ret_inst->value;
            if (value->value.special == ConstValSpecialRuntime) {
                exec_add_error_node(codegen, exec, value->source_node,
                        buf_sprintf("unable to evaluate constant expression"));
                return codegen->invalid_instruction;
            }
            return value;
        } else if (ir_has_side_effects(instruction)) {
            exec_add_error_node(codegen, exec, instruction->source_node,
                    buf_sprintf("unable to evaluate constant expression"));
            return codegen->invalid_instruction;
        }
    }
    zig_unreachable();
}

static bool ir_emit_global_runtime_side_effect(IrAnalyze *ira, IrInstruction *source_instruction) {
    if (ir_should_inline(ira->new_irb.exec, source_instruction->scope)) {
        ir_add_error(ira, source_instruction, buf_sprintf("unable to evaluate constant expression"));
        return false;
    }
    return true;
}

static bool ir_num_lit_fits_in_other_type(IrAnalyze *ira, IrInstruction *instruction, TypeTableEntry *other_type) {
    TypeTableEntry *other_type_underlying = get_underlying_type(other_type);

    if (type_is_invalid(other_type_underlying)) {
        return false;
    }

    ConstExprValue *const_val = &instruction->value;
    assert(const_val->special != ConstValSpecialRuntime);
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

    ir_add_error(ira, instruction,
        buf_sprintf("%s value %s cannot be implicitly casted to type '%s'",
            num_lit_str,
            buf_ptr(bignum_to_buf(&const_val->data.x_bignum)),
            buf_ptr(&other_type->name)));
    return false;
}

static bool is_slice(TypeTableEntry *type) {
    return type->id == TypeTableEntryIdStruct && type->data.structure.is_slice;
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

    // implicit conversion from anything to var
    if (expected_type->id == TypeTableEntryIdVar) {
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
        actual_type->id == TypeTableEntryIdArray)
    {
        TypeTableEntry *ptr_type = expected_type->data.structure.fields[slice_ptr_index].type_entry;
        assert(ptr_type->id == TypeTableEntryIdPointer);

        if ((ptr_type->data.pointer.is_const || actual_type->data.array.len == 0) &&
            types_match_const_cast_only(ptr_type->data.pointer.child_type, actual_type->data.array.child_type))
        {
            return ImplicitCastMatchResultYes;
        }
    }

    // implicit [N]T to &const []const N
    if (expected_type->id == TypeTableEntryIdPointer &&
        expected_type->data.pointer.is_const &&
        is_slice(expected_type->data.pointer.child_type) &&
        actual_type->id == TypeTableEntryIdArray)
    {
        TypeTableEntry *ptr_type =
            expected_type->data.pointer.child_type->data.structure.fields[slice_ptr_index].type_entry;
        assert(ptr_type->id == TypeTableEntryIdPointer);
        if ((ptr_type->data.pointer.is_const || actual_type->data.array.len == 0) &&
                types_match_const_cast_only(ptr_type->data.pointer.child_type, actual_type->data.array.child_type))
        {
            return ImplicitCastMatchResultYes;
        }
    }

    // implicit number literal to typed number
    // implicit number literal to &const integer
    if (actual_type->id == TypeTableEntryIdNumLitFloat ||
         actual_type->id == TypeTableEntryIdNumLitInt)
    {
        if (expected_type->id == TypeTableEntryIdPointer &&
            expected_type->data.pointer.is_const)
        {
            if (ir_num_lit_fits_in_other_type(ira, value, expected_type->data.pointer.child_type)) {
                return ImplicitCastMatchResultYes;
            } else {
                return ImplicitCastMatchResultReportedError;
            }
        } else if (ir_num_lit_fits_in_other_type(ira, value, expected_type)) {
            return ImplicitCastMatchResultYes;
        } else {
            return ImplicitCastMatchResultReportedError;
        }
    }

    // implicit typed number to integer or float literal.
    // works when the number is known
    if (value->value.special == ConstValSpecialStatic) {
        if (actual_type->id == TypeTableEntryIdInt && expected_type->id == TypeTableEntryIdNumLitInt) {
            return ImplicitCastMatchResultYes;
        } else if (actual_type->id == TypeTableEntryIdFloat && expected_type->id == TypeTableEntryIdNumLitFloat) {
            return ImplicitCastMatchResultYes;
        }
    }

    // implicit undefined literal to anything
    if (actual_type->id == TypeTableEntryIdUndefLit) {
        return ImplicitCastMatchResultYes;
    }

    // implicitly take a const pointer to something
    if (!type_requires_comptime(actual_type)) {
        TypeTableEntry *const_ptr_actual = get_pointer_to_type(ira->codegen, actual_type, true);
        if (types_match_const_cast_only(expected_type, const_ptr_actual)) {
            return ImplicitCastMatchResultYes;
        }
    }

    return ImplicitCastMatchResultNo;
}

static TypeTableEntry *ir_resolve_peer_types(IrAnalyze *ira, AstNode *source_node, IrInstruction **instructions, size_t instruction_count) {
    assert(instruction_count >= 1);
    IrInstruction *prev_inst = instructions[0];
    if (type_is_invalid(prev_inst->value.type)) {
        return ira->codegen->builtin_types.entry_invalid;
    }
    bool any_are_pure_error = (prev_inst->value.type->id == TypeTableEntryIdPureError);
    bool any_are_null = (prev_inst->value.type->id == TypeTableEntryIdNullLit);
    bool convert_to_const_slice = false;
    for (size_t i = 1; i < instruction_count; i += 1) {
        IrInstruction *cur_inst = instructions[i];
        TypeTableEntry *cur_type = cur_inst->value.type;
        TypeTableEntry *prev_type = prev_inst->value.type;
        if (type_is_invalid(cur_type)) {
            return cur_type;
        } else if (prev_type->id == TypeTableEntryIdUnreachable) {
            prev_inst = cur_inst;
        } else if (cur_type->id == TypeTableEntryIdUnreachable) {
            continue;
        } else if (prev_type->id == TypeTableEntryIdPureError) {
            prev_inst = cur_inst;
            continue;
        } else if (prev_type->id == TypeTableEntryIdNullLit) {
            prev_inst = cur_inst;
            continue;
        } else if (cur_type->id == TypeTableEntryIdPureError) {
            any_are_pure_error = true;
            continue;
        } else if (cur_type->id == TypeTableEntryIdNullLit) {
            any_are_null = true;
            continue;
        } else if (types_match_const_cast_only(prev_type, cur_type)) {
            continue;
        } else if (types_match_const_cast_only(cur_type, prev_type)) {
            prev_inst = cur_inst;
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
        } else if (cur_type->id == TypeTableEntryIdArray && prev_type->id == TypeTableEntryIdArray &&
                cur_type->data.array.len != prev_type->data.array.len &&
                types_match_const_cast_only(cur_type->data.array.child_type, prev_type->data.array.child_type))
        {
            convert_to_const_slice = true;
            prev_inst = cur_inst;
            continue;
        } else if (cur_type->id == TypeTableEntryIdArray && prev_type->id == TypeTableEntryIdArray &&
                cur_type->data.array.len != prev_type->data.array.len &&
                types_match_const_cast_only(prev_type->data.array.child_type, cur_type->data.array.child_type))
        {
            convert_to_const_slice = true;
            continue;
        } else if (cur_type->id == TypeTableEntryIdArray && is_slice(prev_type) &&
                prev_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.is_const &&
                types_match_const_cast_only(prev_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.child_type,
                    cur_type->data.array.child_type))
        {
            convert_to_const_slice = false;
            continue;
        } else if (prev_type->id == TypeTableEntryIdArray && is_slice(cur_type) &&
                cur_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.is_const &&
                types_match_const_cast_only(cur_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.child_type,
                    prev_type->data.array.child_type))
        {
            prev_inst = cur_inst;
            convert_to_const_slice = false;
            continue;
        } else {
            ErrorMsg *msg = ir_add_error_node(ira, source_node,
                buf_sprintf("incompatible types: '%s' and '%s'",
                    buf_ptr(&prev_type->name), buf_ptr(&cur_type->name)));
            add_error_note(ira->codegen, msg, prev_inst->source_node,
                buf_sprintf("type '%s' here", buf_ptr(&prev_type->name)));
            add_error_note(ira->codegen, msg, cur_inst->source_node,
                buf_sprintf("type '%s' here", buf_ptr(&cur_type->name)));

            return ira->codegen->builtin_types.entry_invalid;
        }
    }
    if (convert_to_const_slice) {
        assert(prev_inst->value.type->id == TypeTableEntryIdArray);
        return get_slice_type(ira->codegen, prev_inst->value.type->data.array.child_type, true);
    } else if (any_are_pure_error && prev_inst->value.type->id != TypeTableEntryIdPureError) {
        if (prev_inst->value.type->id == TypeTableEntryIdNumLitInt ||
            prev_inst->value.type->id == TypeTableEntryIdNumLitFloat)
        {
            ir_add_error_node(ira, source_node,
                buf_sprintf("unable to make error union out of number literal"));
            return ira->codegen->builtin_types.entry_invalid;
        } else if (prev_inst->value.type->id == TypeTableEntryIdNullLit) {
            ir_add_error_node(ira, source_node,
                buf_sprintf("unable to make error union out of null literal"));
            return ira->codegen->builtin_types.entry_invalid;
        } else if (prev_inst->value.type->id == TypeTableEntryIdErrorUnion) {
            return prev_inst->value.type;
        } else {
            return get_error_type(ira->codegen, prev_inst->value.type);
        }
    } else if (any_are_null && prev_inst->value.type->id != TypeTableEntryIdNullLit) {
        if (prev_inst->value.type->id == TypeTableEntryIdNumLitInt ||
            prev_inst->value.type->id == TypeTableEntryIdNumLitFloat)
        {
            ir_add_error_node(ira, source_node,
                buf_sprintf("unable to make maybe out of number literal"));
            return ira->codegen->builtin_types.entry_invalid;
        } else if (prev_inst->value.type->id == TypeTableEntryIdMaybe) {
            return prev_inst->value.type;
        } else {
            return get_maybe_type(ira->codegen, prev_inst->value.type);
        }
    } else {
        return prev_inst->value.type;
    }
}

static void ir_add_alloca(IrAnalyze *ira, IrInstruction *instruction, TypeTableEntry *type_entry) {
    if (type_has_bits(type_entry) && handle_is_ptr(type_entry)) {
        FnTableEntry *fn_entry = exec_fn_entry(ira->new_irb.exec);
        assert(fn_entry);
        fn_entry->alloca_list.append(instruction);
    }
}

static void eval_const_expr_implicit_cast(CastOp cast_op,
        ConstExprValue *other_val, TypeTableEntry *other_type,
        ConstExprValue *const_val, TypeTableEntry *new_type)
{
    const_val->special = other_val->special;

    assert(other_val != const_val);
    switch (cast_op) {
        case CastOpNoCast:
            zig_unreachable();
        case CastOpNoop:
            *const_val = *other_val;
            const_val->type = new_type;
            break;
        case CastOpResizeSlice:
        case CastOpBytesToSlice:
            // can't do it
            break;
        case CastOpIntToFloat:
            bignum_cast_to_float(&const_val->data.x_bignum, &other_val->data.x_bignum);
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpFloatToInt:
            bignum_cast_to_int(&const_val->data.x_bignum, &other_val->data.x_bignum);
            const_val->special = ConstValSpecialStatic;
            break;
        case CastOpBoolToInt:
            bignum_init_unsigned(&const_val->data.x_bignum, other_val->data.x_bool ? 1 : 0);
            const_val->special = ConstValSpecialStatic;
            break;
    }
}
static IrInstruction *ir_resolve_cast(IrAnalyze *ira, IrInstruction *source_instr, IrInstruction *value,
        TypeTableEntry *wanted_type, CastOp cast_op, bool need_alloca)
{
    if (value->value.special != ConstValSpecialRuntime) {
        IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                source_instr->source_node, wanted_type);
        eval_const_expr_implicit_cast(cast_op, &value->value, value->value.type,
                &result->value, wanted_type);
        return result;
    } else {
        IrInstruction *result = ir_build_cast(&ira->new_irb, source_instr->scope, source_instr->source_node, wanted_type, value, cast_op);
        result->value.type = wanted_type;
        if (need_alloca) {
            FnTableEntry *fn_entry = exec_fn_entry(ira->new_irb.exec);
            if (fn_entry)
                fn_entry->alloca_list.append(result);
        }
        return result;
    }
}

static bool is_container(TypeTableEntry *type) {
    return type->id == TypeTableEntryIdStruct ||
        type->id == TypeTableEntryIdEnum ||
        type->id == TypeTableEntryIdUnion;
}

static bool is_u8(TypeTableEntry *type) {
    return type->id == TypeTableEntryIdInt &&
        !type->data.integral.is_signed && type->data.integral.bit_count == 8;
}

static IrBasicBlock *ir_get_new_bb(IrAnalyze *ira, IrBasicBlock *old_bb, IrInstruction *ref_old_instruction) {
    assert(old_bb);

    if (old_bb->other) {
        if (ref_old_instruction == nullptr || old_bb->other->ref_instruction != ref_old_instruction)
            return old_bb->other;
    }

    IrBasicBlock *new_bb = ir_build_bb_from(&ira->new_irb, old_bb);
    new_bb->ref_instruction = ref_old_instruction;

    // We are about to enqueue old_bb for analysis. Before we do so, look over old_bb's
    // instructions and make sure we have enqueued first the blocks which contain
    // instructions old_bb depends on.
    for (size_t instr_i = 0; instr_i < old_bb->instruction_list.length; instr_i += 1) {
        IrInstruction *instruction = old_bb->instruction_list.at(instr_i);

        for (size_t dep_i = 0; ; dep_i += 1) {
            IrInstruction *dep_instruction = ir_instruction_get_dep(instruction, dep_i);
            if (dep_instruction == nullptr)
                break;
            if (dep_instruction->other)
                continue;
            if (dep_instruction->owner_bb == old_bb)
                continue;
            ir_get_new_bb(ira, dep_instruction->owner_bb, nullptr);
        }
    }
    ira->old_bb_queue.append(old_bb);

    return new_bb;
}

static void ir_start_bb(IrAnalyze *ira, IrBasicBlock *old_bb, IrBasicBlock *const_predecessor_bb) {
    ira->instruction_index = 0;
    ira->old_irb.current_basic_block = old_bb;
    ira->const_predecessor_bb = const_predecessor_bb;

    if (!const_predecessor_bb && old_bb->other)
        ira->new_irb.exec->basic_block_list.append(old_bb->other);
}

static void ir_finish_bb(IrAnalyze *ira) {
    ira->instruction_index += 1;
    while (ira->instruction_index < ira->old_irb.current_basic_block->instruction_list.length) {
        IrInstruction *next_instruction = ira->old_irb.current_basic_block->instruction_list.at(ira->instruction_index);
        if (!next_instruction->is_gen) {
            ir_add_error(ira, next_instruction, buf_sprintf("unreachable code"));
            break;
        }
        ira->instruction_index += 1;
    }

    ira->block_queue_index += 1;

    if (ira->block_queue_index < ira->old_bb_queue.length) {
        IrBasicBlock *old_bb = ira->old_bb_queue.at(ira->block_queue_index);
        assert(old_bb->other);
        ira->new_irb.current_basic_block = old_bb->other;

        ir_start_bb(ira, old_bb, nullptr);
    }
}

static TypeTableEntry *ir_unreach_error(IrAnalyze *ira) {
    ira->block_queue_index = SIZE_MAX;
    ira->new_irb.exec->invalid = true;
    return ira->codegen->builtin_types.entry_unreachable;
}

static bool ir_emit_backward_branch(IrAnalyze *ira, IrInstruction *source_instruction) {
    size_t *bbc = ira->new_irb.exec->backward_branch_count;
    size_t quota = ira->new_irb.exec->backward_branch_quota;

    // If we're already over quota, we've already given an error message for this.
    if (*bbc > quota)
        return false;

    *bbc += 1;
    if (*bbc > quota) {
        ir_add_error(ira, source_instruction, buf_sprintf("evaluation exceeded %zu backwards branches", quota));
        return false;
    }
    return true;
}

static TypeTableEntry *ir_inline_bb(IrAnalyze *ira, IrInstruction *source_instruction, IrBasicBlock *old_bb) {
    if (old_bb->debug_id <= ira->old_irb.current_basic_block->debug_id) {
        if (!ir_emit_backward_branch(ira, source_instruction))
            return ir_unreach_error(ira);
    }

    old_bb->other = ira->old_irb.current_basic_block->other;
    ir_start_bb(ira, old_bb, ira->old_irb.current_basic_block);
    return ira->codegen->builtin_types.entry_unreachable;
}

static TypeTableEntry *ir_finish_anal(IrAnalyze *ira, TypeTableEntry *result_type) {
    if (result_type->id == TypeTableEntryIdUnreachable)
        ir_finish_bb(ira);
    return result_type;
}

static IrInstruction *ir_get_const(IrAnalyze *ira, IrInstruction *old_instruction) {
    IrInstruction *new_instruction;
    if (old_instruction->id == IrInstructionIdVarPtr) {
        IrInstructionVarPtr *old_var_ptr_instruction = (IrInstructionVarPtr *)old_instruction;
        IrInstructionVarPtr *var_ptr_instruction = ir_create_instruction<IrInstructionVarPtr>(&ira->new_irb,
                old_instruction->scope, old_instruction->source_node);
        var_ptr_instruction->var = old_var_ptr_instruction->var;
        new_instruction = &var_ptr_instruction->base;
    } else if (old_instruction->id == IrInstructionIdFieldPtr) {
        IrInstructionFieldPtr *field_ptr_instruction = ir_create_instruction<IrInstructionFieldPtr>(&ira->new_irb,
                old_instruction->scope, old_instruction->source_node);
        new_instruction = &field_ptr_instruction->base;
    } else if (old_instruction->id == IrInstructionIdElemPtr) {
        IrInstructionElemPtr *elem_ptr_instruction = ir_create_instruction<IrInstructionElemPtr>(&ira->new_irb,
                old_instruction->scope, old_instruction->source_node);
        new_instruction = &elem_ptr_instruction->base;
    } else {
        IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(&ira->new_irb,
                old_instruction->scope, old_instruction->source_node);
        new_instruction = &const_instruction->base;
    }
    new_instruction->value.special = ConstValSpecialStatic;
    return new_instruction;
}

static ConstExprValue *ir_build_const_from(IrAnalyze *ira, IrInstruction *old_instruction) {
    IrInstruction *new_instruction = ir_get_const(ira, old_instruction);
    ir_link_new_instruction(new_instruction, old_instruction);
    return &new_instruction->value;
}

static TypeTableEntry *ir_analyze_void(IrAnalyze *ira, IrInstruction *instruction) {
    ir_build_const_from(ira, instruction);
    return ira->codegen->builtin_types.entry_void;
}

static IrInstruction *ir_get_const_ptr(IrAnalyze *ira, IrInstruction *instruction,
        ConstExprValue *pointee, TypeTableEntry *pointee_type,
        ConstPtrMut ptr_mut, bool ptr_is_const, bool ptr_is_volatile)
{
    if (pointee_type->id == TypeTableEntryIdMetaType) {
        TypeTableEntry *type_entry = pointee->data.x_type;
        if (type_entry->id == TypeTableEntryIdUnreachable) {
            ir_add_error(ira, instruction, buf_sprintf("pointer to unreachable not allowed"));
            return ira->codegen->invalid_instruction;
        }

        IrInstruction *const_instr = ir_get_const(ira, instruction);
        ConstExprValue *const_val = &const_instr->value;
        const_val->type = pointee_type;
        type_ensure_zero_bits_known(ira->codegen, type_entry);
        const_val->data.x_type = get_pointer_to_type_extra(ira->codegen, type_entry,
                ptr_is_const, ptr_is_volatile, 0, 0);
        return const_instr;
    } else {
        TypeTableEntry *ptr_type = get_pointer_to_type_extra(ira->codegen, pointee_type,
                ptr_is_const, ptr_is_volatile, 0, 0);
        IrInstruction *const_instr = ir_get_const(ira, instruction);
        ConstExprValue *const_val = &const_instr->value;
        const_val->type = ptr_type;
        const_val->data.x_ptr.special = ConstPtrSpecialRef;
        const_val->data.x_ptr.mut = ptr_mut;
        const_val->data.x_ptr.data.ref.pointee = pointee;
        return const_instr;
    }
}

static TypeTableEntry *ir_analyze_const_ptr(IrAnalyze *ira, IrInstruction *instruction,
        ConstExprValue *pointee, TypeTableEntry *pointee_type,
        ConstPtrMut ptr_mut, bool ptr_is_const, bool ptr_is_volatile)
{
    IrInstruction *const_instr = ir_get_const_ptr(ira, instruction, pointee,
            pointee_type, ptr_mut, ptr_is_const, ptr_is_volatile);
    ir_link_new_instruction(const_instr, instruction);
    return const_instr->value.type;
}

static TypeTableEntry *ir_analyze_const_usize(IrAnalyze *ira, IrInstruction *instruction, uint64_t value) {
    ConstExprValue *const_val = ir_build_const_from(ira, instruction);
    bignum_init_unsigned(&const_val->data.x_bignum, value);
    return ira->codegen->builtin_types.entry_usize;
}

enum UndefAllowed {
    UndefOk,
    UndefBad,
};

static ConstExprValue *ir_resolve_const(IrAnalyze *ira, IrInstruction *value, UndefAllowed undef_allowed) {
    switch (value->value.special) {
        case ConstValSpecialStatic:
            return &value->value;
        case ConstValSpecialRuntime:
            ir_add_error(ira, value, buf_sprintf("unable to evaluate constant expression"));
            return nullptr;
        case ConstValSpecialUndef:
            if (undef_allowed == UndefOk) {
                return &value->value;
            } else {
                ir_add_error(ira, value, buf_sprintf("use of undefined value"));
                return nullptr;
            }
    }
    zig_unreachable();
}

IrInstruction *ir_eval_const_value(CodeGen *codegen, Scope *scope, AstNode *node,
        TypeTableEntry *expected_type, size_t *backward_branch_count, size_t backward_branch_quota,
        FnTableEntry *fn_entry, Buf *c_import_buf, AstNode *source_node, Buf *exec_name,
        IrExecutable *parent_exec)
{
    IrExecutable ir_executable = {0};
    ir_executable.source_node = source_node;
    ir_executable.parent_exec = parent_exec;
    ir_executable.name = exec_name;
    ir_executable.is_inline = true;
    ir_executable.fn_entry = fn_entry;
    ir_executable.c_import_buf = c_import_buf;
    ir_executable.begin_scope = scope;
    ir_gen(codegen, node, scope, &ir_executable);

    if (ir_executable.invalid)
        return codegen->invalid_instruction;

    if (codegen->verbose) {
        fprintf(stderr, "\nSource: ");
        ast_render(stderr, node, 4);
        fprintf(stderr, "\n{ // (IR)\n");
        ir_print(stderr, &ir_executable, 4);
        fprintf(stderr, "}\n");
    }
    IrExecutable analyzed_executable = {0};
    analyzed_executable.source_node = source_node;
    analyzed_executable.parent_exec = parent_exec;
    analyzed_executable.name = exec_name;
    analyzed_executable.is_inline = true;
    analyzed_executable.fn_entry = fn_entry;
    analyzed_executable.c_import_buf = c_import_buf;
    analyzed_executable.backward_branch_count = backward_branch_count;
    analyzed_executable.backward_branch_quota = backward_branch_quota;
    analyzed_executable.begin_scope = scope;
    TypeTableEntry *result_type = ir_analyze(codegen, &ir_executable, &analyzed_executable, expected_type, node);
    if (type_is_invalid(result_type))
        return codegen->invalid_instruction;

    if (codegen->verbose) {
        fprintf(stderr, "{ // (analyzed)\n");
        ir_print(stderr, &analyzed_executable, 4);
        fprintf(stderr, "}\n");
    }

    return ir_exec_const_result(codegen, &analyzed_executable);
}

static TypeTableEntry *ir_resolve_type(IrAnalyze *ira, IrInstruction *type_value) {
    if (type_is_invalid(type_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (type_value->value.type->id != TypeTableEntryIdMetaType) {
        ir_add_error(ira, type_value,
                buf_sprintf("expected type 'type', found '%s'", buf_ptr(&type_value->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    ConstExprValue *const_val = ir_resolve_const(ira, type_value, UndefBad);
    if (!const_val)
        return ira->codegen->builtin_types.entry_invalid;

    return const_val->data.x_type;
}

static FnTableEntry *ir_resolve_fn(IrAnalyze *ira, IrInstruction *fn_value, bool *is_inline) {
    if (fn_value == ira->codegen->invalid_instruction)
        return nullptr;

    if (type_is_invalid(fn_value->value.type))
        return nullptr;

    if (fn_value->value.type->id != TypeTableEntryIdFn) {
        ir_add_error_node(ira, fn_value->source_node,
                buf_sprintf("expected function type, found '%s'", buf_ptr(&fn_value->value.type->name)));
        return nullptr;
    }

    ConstExprValue *const_val = ir_resolve_const(ira, fn_value, UndefBad);
    if (!const_val)
        return nullptr;

    *is_inline = const_val->data.x_fn.is_inline;
    return const_val->data.x_fn.fn_entry;
}

static IrInstruction *ir_analyze_maybe_wrap(IrAnalyze *ira, IrInstruction *source_instr, IrInstruction *value, TypeTableEntry *wanted_type) {
    assert(wanted_type->id == TypeTableEntryIdMaybe);

    if (instr_is_comptime(value)) {
        TypeTableEntry *payload_type = wanted_type->data.maybe.child_type;
        IrInstruction *casted_payload = ir_implicit_cast(ira, value, payload_type);
        if (type_is_invalid(casted_payload->value.type))
            return ira->codegen->invalid_instruction;

        ConstExprValue *val = ir_resolve_const(ira, casted_payload, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;

        IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(&ira->new_irb,
                source_instr->scope, source_instr->source_node);
        const_instruction->base.value.type = wanted_type;
        const_instruction->base.value.special = ConstValSpecialStatic;
        const_instruction->base.value.data.x_maybe = val;
        return &const_instruction->base;
    }

    IrInstruction *result = ir_build_maybe_wrap(&ira->new_irb, source_instr->scope, source_instr->source_node, value);
    result->value.type = wanted_type;
    result->value.data.rh_maybe = RuntimeHintMaybeNonNull;
    ir_add_alloca(ira, result, wanted_type);
    return result;
}

static IrInstruction *ir_analyze_err_wrap_payload(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *value, TypeTableEntry *wanted_type)
{
    assert(wanted_type->id == TypeTableEntryIdErrorUnion);

    if (instr_is_comptime(value)) {
        TypeTableEntry *payload_type = wanted_type->data.error.child_type;
        IrInstruction *casted_payload = ir_implicit_cast(ira, value, payload_type);
        if (type_is_invalid(casted_payload->value.type))
            return ira->codegen->invalid_instruction;

        ConstExprValue *val = ir_resolve_const(ira, casted_payload, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;

        IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(&ira->new_irb,
                source_instr->scope, source_instr->source_node);
        const_instruction->base.value.type = wanted_type;
        const_instruction->base.value.special = ConstValSpecialStatic;
        const_instruction->base.value.data.x_err_union.err = nullptr;
        const_instruction->base.value.data.x_err_union.payload = val;
        return &const_instruction->base;
    }

    IrInstruction *result = ir_build_err_wrap_payload(&ira->new_irb, source_instr->scope, source_instr->source_node, value);
    result->value.type = wanted_type;
    result->value.data.rh_error_union = RuntimeHintErrorUnionNonError;
    ir_add_alloca(ira, result, wanted_type);
    return result;
}

static IrInstruction *ir_analyze_err_wrap_code(IrAnalyze *ira, IrInstruction *source_instr, IrInstruction *value, TypeTableEntry *wanted_type) {
    assert(wanted_type->id == TypeTableEntryIdErrorUnion);

    if (instr_is_comptime(value)) {
        ConstExprValue *val = ir_resolve_const(ira, value, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;

        IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(&ira->new_irb,
                source_instr->scope, source_instr->source_node);
        const_instruction->base.value.type = wanted_type;
        const_instruction->base.value.special = ConstValSpecialStatic;
        const_instruction->base.value.data.x_err_union.err = val->data.x_pure_err;
        const_instruction->base.value.data.x_err_union.payload = nullptr;
        return &const_instruction->base;
    }

    IrInstruction *result = ir_build_err_wrap_code(&ira->new_irb, source_instr->scope, source_instr->source_node, value);
    result->value.type = wanted_type;
    result->value.data.rh_error_union = RuntimeHintErrorUnionError;
    ir_add_alloca(ira, result, wanted_type);
    return result;
}

static IrInstruction *ir_analyze_cast_ref(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *value, TypeTableEntry *wanted_type)
{
    if (instr_is_comptime(value)) {
        ConstExprValue *val = ir_resolve_const(ira, value, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;

        IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(&ira->new_irb,
                source_instr->scope, source_instr->source_node);
        const_instruction->base.value.type = wanted_type;
        const_instruction->base.value.special = ConstValSpecialStatic;
        const_instruction->base.value.data.x_ptr.special = ConstPtrSpecialRef;
        const_instruction->base.value.data.x_ptr.data.ref.pointee = val;
        return &const_instruction->base;
    }

    if (value->id == IrInstructionIdLoadPtr) {
        IrInstructionLoadPtr *load_ptr_inst = (IrInstructionLoadPtr *)value;
        return load_ptr_inst->ptr;
    } else {
        IrInstruction *new_instruction = ir_build_ref(&ira->new_irb, source_instr->scope,
                source_instr->source_node, value, true, false);
        new_instruction->value.type = wanted_type;

        TypeTableEntry *child_type = wanted_type->data.pointer.child_type;
        if (type_has_bits(child_type)) {
            FnTableEntry *fn_entry = exec_fn_entry(ira->new_irb.exec);
            assert(fn_entry);
            fn_entry->alloca_list.append(new_instruction);
        }
        return new_instruction;
    }
}

static IrInstruction *ir_analyze_null_to_maybe(IrAnalyze *ira, IrInstruction *source_instr, IrInstruction *value, TypeTableEntry *wanted_type) {
    assert(wanted_type->id == TypeTableEntryIdMaybe);
    assert(instr_is_comptime(value));

    ConstExprValue *val = ir_resolve_const(ira, value, UndefBad);
    assert(val);

    IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(&ira->new_irb, source_instr->scope, source_instr->source_node);
    const_instruction->base.value.type = wanted_type;
    const_instruction->base.value.special = ConstValSpecialStatic;
    const_instruction->base.value.data.x_maybe = nullptr;
    return &const_instruction->base;
}

static IrInstruction *ir_get_ref(IrAnalyze *ira, IrInstruction *source_instruction, IrInstruction *value,
        bool is_const, bool is_volatile)
{
    if (type_is_invalid(value->value.type))
        return ira->codegen->invalid_instruction;

    if (value->id == IrInstructionIdLoadPtr) {
        IrInstructionLoadPtr *load_ptr_inst = (IrInstructionLoadPtr *) value;
        if (load_ptr_inst->ptr->value.type->data.pointer.is_const) {
            return load_ptr_inst->ptr;
        }
    }

    if (instr_is_comptime(value)) {
        ConstExprValue *val = ir_resolve_const(ira, value, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;
        return ir_get_const_ptr(ira, source_instruction, val, value->value.type,
                ConstPtrMutComptimeConst, is_const, is_volatile);
    }

    TypeTableEntry *ptr_type = get_pointer_to_type_extra(ira->codegen, value->value.type, is_const, is_volatile, 0, 0);
    FnTableEntry *fn_entry = exec_fn_entry(ira->new_irb.exec);
    assert(fn_entry);
    IrInstruction *new_instruction = ir_build_ref(&ira->new_irb, source_instruction->scope,
            source_instruction->source_node, value, is_const, is_volatile);
    new_instruction->value.type = ptr_type;
    fn_entry->alloca_list.append(new_instruction);
    return new_instruction;
}

static IrInstruction *ir_analyze_array_to_slice(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *array, TypeTableEntry *wanted_type)
{
    assert(is_slice(wanted_type));

    TypeTableEntry *array_type = array->value.type;
    assert(array_type->id == TypeTableEntryIdArray);

    if (instr_is_comptime(array)) {
        IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                source_instr->source_node, wanted_type);
        init_const_slice(ira->codegen, &result->value, &array->value, 0, array_type->data.array.len, true);
        return result;
    }

    IrInstruction *start = ir_create_const(&ira->new_irb, source_instr->scope,
            source_instr->source_node, ira->codegen->builtin_types.entry_usize);
    init_const_usize(ira->codegen, &start->value, 0);

    IrInstruction *end = ir_create_const(&ira->new_irb, source_instr->scope,
            source_instr->source_node, ira->codegen->builtin_types.entry_usize);
    init_const_usize(ira->codegen, &end->value, array_type->data.array.len);

    IrInstruction *array_ptr = ir_get_ref(ira, source_instr, array, true, false);

    IrInstruction *result = ir_build_slice(&ira->new_irb, source_instr->scope,
            source_instr->source_node, array_ptr, start, end, false, false);
    TypeTableEntry *child_type = array_type->data.array.child_type;
    result->value.type = get_slice_type(ira->codegen, child_type, true);
    ir_add_alloca(ira, result, result->value.type);

    return result;
}

static IrInstruction *ir_analyze_enum_to_int(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *target, TypeTableEntry *wanted_type)
{
    assert(wanted_type->id == TypeTableEntryIdInt);

    if (instr_is_comptime(target)) {
        ConstExprValue *val = ir_resolve_const(ira, target, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;
        IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                source_instr->source_node, wanted_type);
        init_const_unsigned_negative(&result->value, wanted_type, val->data.x_enum.tag, false);
        return result;
    }

    IrInstruction *result = ir_build_widen_or_shorten(&ira->new_irb, source_instr->scope,
            source_instr->source_node, target);
    result->value.type = wanted_type;
    return result;
}

static IrInstruction *ir_analyze_undefined_to_anything(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *target, TypeTableEntry *wanted_type)
{
    IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
            source_instr->source_node, wanted_type);
    init_const_undefined(ira->codegen, &result->value);
    return result;
}

static IrInstruction *ir_analyze_widen_or_shorten(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *target, TypeTableEntry *wanted_type)
{
    assert(wanted_type->id == TypeTableEntryIdInt || wanted_type->id == TypeTableEntryIdFloat);

    if (instr_is_comptime(target)) {
        ConstExprValue *val = ir_resolve_const(ira, target, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;
        IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                source_instr->source_node, wanted_type);
        result->value = *val;
        result->value.type = wanted_type;
        return result;
    }

    IrInstruction *result = ir_build_widen_or_shorten(&ira->new_irb, source_instr->scope,
            source_instr->source_node, target);
    result->value.type = wanted_type;
    return result;
}

static IrInstruction *ir_analyze_ptr_to_int(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *target, TypeTableEntry *wanted_type)
{
    assert(wanted_type->id == TypeTableEntryIdInt);

    if (instr_is_comptime(target)) {
        ConstExprValue *val = ir_resolve_const(ira, target, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;
        if (val->data.x_ptr.special == ConstPtrSpecialHardCodedAddr) {
            IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                    source_instr->source_node, wanted_type);
            bignum_init_unsigned(&result->value.data.x_bignum, val->data.x_ptr.data.hard_coded_addr.addr);
            return result;
        }
    }

    IrInstruction *result = ir_build_ptr_to_int(&ira->new_irb, source_instr->scope,
            source_instr->source_node, target);
    result->value.type = wanted_type;
    return result;
}


static IrInstruction *ir_analyze_int_to_enum(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *target, TypeTableEntry *wanted_type)
{
    assert(wanted_type->id == TypeTableEntryIdEnum);

    if (instr_is_comptime(target)) {
        ConstExprValue *val = ir_resolve_const(ira, target, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;
        IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                source_instr->source_node, wanted_type);
        result->value.data.x_enum.tag = val->data.x_bignum.data.x_uint;
        return result;
    }

    IrInstruction *result = ir_build_int_to_enum(&ira->new_irb, source_instr->scope,
            source_instr->source_node, target);
    result->value.type = wanted_type;
    return result;
}

static IrInstruction *ir_analyze_number_to_literal(IrAnalyze *ira, IrInstruction *source_instr,
        IrInstruction *target, TypeTableEntry *wanted_type)
{
    ConstExprValue *val = ir_resolve_const(ira, target, UndefBad);
    if (!val)
        return ira->codegen->invalid_instruction;

    IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
            source_instr->source_node, wanted_type);
    bignum_init_bignum(&result->value.data.x_bignum, &val->data.x_bignum);
    return result;
}

static IrInstruction *ir_analyze_int_to_err(IrAnalyze *ira, IrInstruction *source_instr, IrInstruction *target) {
    assert(target->value.type->id == TypeTableEntryIdInt);
    assert(!target->value.type->data.integral.is_signed);

    if (instr_is_comptime(target)) {
        ConstExprValue *val = ir_resolve_const(ira, target, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;

        IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                source_instr->source_node, ira->codegen->builtin_types.entry_pure_error);

        uint64_t index = val->data.x_bignum.data.x_uint;
        if (index == 0 || index >= ira->codegen->error_decls.length) {
            ir_add_error(ira, source_instr,
                buf_sprintf("integer value %" PRIu64 " represents no error", index));
            return ira->codegen->invalid_instruction;
        }

        AstNode *error_decl_node = ira->codegen->error_decls.at(index);
        result->value.data.x_pure_err = error_decl_node->data.error_value_decl.err;
        return result;
    }

    IrInstruction *result = ir_build_int_to_err(&ira->new_irb, source_instr->scope, source_instr->source_node, target);
    result->value.type = ira->codegen->builtin_types.entry_pure_error;
    return result;
}

static IrInstruction *ir_analyze_err_to_int(IrAnalyze *ira, IrInstruction *source_instr, IrInstruction *target,
        TypeTableEntry *wanted_type)
{
    assert(wanted_type->id == TypeTableEntryIdInt);

    TypeTableEntry *err_type = target->value.type;

    if (instr_is_comptime(target)) {
        ConstExprValue *val = ir_resolve_const(ira, target, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;

        IrInstruction *result = ir_create_const(&ira->new_irb, source_instr->scope,
                source_instr->source_node, wanted_type);

        ErrorTableEntry *err;
        if (err_type->id == TypeTableEntryIdErrorUnion) {
            err = val->data.x_err_union.err;
        } else if (err_type->id == TypeTableEntryIdPureError) {
            err = val->data.x_pure_err;
        } else {
            zig_unreachable();
        }
        result->value.type = wanted_type;
        uint64_t err_value = err ? err->value : 0;
        bignum_init_unsigned(&result->value.data.x_bignum, err_value);

        if (!bignum_fits_in_bits(&result->value.data.x_bignum,
            wanted_type->data.integral.bit_count, wanted_type->data.integral.is_signed))
        {
            ir_add_error_node(ira, source_instr->source_node,
                    buf_sprintf("error code '%s' does not fit in '%s'",
                        buf_ptr(&err->name), buf_ptr(&wanted_type->name)));
            return ira->codegen->invalid_instruction;
        }

        return result;
    }

    BigNum bn;
    bignum_init_unsigned(&bn, ira->codegen->error_decls.length);
    if (!bignum_fits_in_bits(&bn, wanted_type->data.integral.bit_count, wanted_type->data.integral.is_signed)) {
        ir_add_error_node(ira, source_instr->source_node,
                buf_sprintf("too many error values to fit in '%s'", buf_ptr(&wanted_type->name)));
        return ira->codegen->invalid_instruction;
    }

    IrInstruction *result = ir_build_err_to_int(&ira->new_irb, source_instr->scope, source_instr->source_node, target);
    result->value.type = wanted_type;
    return result;
}

static IrInstruction *ir_analyze_cast(IrAnalyze *ira, IrInstruction *source_instr,
    TypeTableEntry *wanted_type, IrInstruction *value)
{
    TypeTableEntry *actual_type = value->value.type;
    TypeTableEntry *wanted_type_canon = get_underlying_type(wanted_type);
    TypeTableEntry *actual_type_canon = get_underlying_type(actual_type);

    TypeTableEntry *usize_type = ira->codegen->builtin_types.entry_usize;

    if (type_is_invalid(wanted_type_canon) || type_is_invalid(actual_type_canon)) {
        return ira->codegen->invalid_instruction;
    }

    if (wanted_type->id == TypeTableEntryIdVar)
        return value;

    // explicit match or non-const to const
    if (types_match_const_cast_only(wanted_type, actual_type)) {
        return ir_resolve_cast(ira, source_instr, value, wanted_type, CastOpNoop, false);
    }

    // explicit cast from bool to int
    if (wanted_type_canon->id == TypeTableEntryIdInt &&
        actual_type_canon->id == TypeTableEntryIdBool)
    {
        return ir_resolve_cast(ira, source_instr, value, wanted_type, CastOpBoolToInt, false);
    }

    // explicit cast from pointer to usize
    if (wanted_type_canon == usize_type && type_is_codegen_pointer(actual_type_canon)) {
        return ir_analyze_ptr_to_int(ira, source_instr, value, wanted_type);
    }

    // explicit widening or shortening cast
    if ((wanted_type_canon->id == TypeTableEntryIdInt &&
        actual_type_canon->id == TypeTableEntryIdInt) ||
        (wanted_type_canon->id == TypeTableEntryIdFloat &&
        actual_type_canon->id == TypeTableEntryIdFloat))
    {
        return ir_analyze_widen_or_shorten(ira, source_instr, value, wanted_type);
    }

    // explicit cast from int to float
    if (wanted_type_canon->id == TypeTableEntryIdFloat &&
        actual_type_canon->id == TypeTableEntryIdInt)
    {
        return ir_resolve_cast(ira, source_instr, value, wanted_type, CastOpIntToFloat, false);
    }

    // explicit cast from float to int
    if (wanted_type_canon->id == TypeTableEntryIdInt &&
        actual_type_canon->id == TypeTableEntryIdFloat)
    {
        return ir_resolve_cast(ira, source_instr, value, wanted_type, CastOpFloatToInt, false);
    }

    // explicit cast from [N]T to []const T
    if (is_slice(wanted_type) && actual_type->id == TypeTableEntryIdArray) {
        TypeTableEntry *ptr_type = wanted_type->data.structure.fields[slice_ptr_index].type_entry;
        assert(ptr_type->id == TypeTableEntryIdPointer);
        if ((ptr_type->data.pointer.is_const || actual_type->data.array.len == 0) &&
            types_match_const_cast_only(ptr_type->data.pointer.child_type, actual_type->data.array.child_type))
        {
            return ir_analyze_array_to_slice(ira, source_instr, value, wanted_type);
        }
    }

    // explicit cast from [N]T to &const []const N
    if (wanted_type->id == TypeTableEntryIdPointer &&
        wanted_type->data.pointer.is_const &&
        is_slice(wanted_type->data.pointer.child_type) &&
        actual_type->id == TypeTableEntryIdArray)
    {
        TypeTableEntry *ptr_type =
            wanted_type->data.pointer.child_type->data.structure.fields[slice_ptr_index].type_entry;
        assert(ptr_type->id == TypeTableEntryIdPointer);
        if ((ptr_type->data.pointer.is_const || actual_type->data.array.len == 0) &&
                types_match_const_cast_only(ptr_type->data.pointer.child_type, actual_type->data.array.child_type))
        {
            IrInstruction *cast1 = ir_analyze_cast(ira, source_instr, wanted_type->data.pointer.child_type, value);
            if (type_is_invalid(cast1->value.type))
                return ira->codegen->invalid_instruction;

            IrInstruction *cast2 = ir_analyze_cast(ira, source_instr, wanted_type, cast1);
            if (type_is_invalid(cast2->value.type))
                return ira->codegen->invalid_instruction;

            return cast2;
        }
    }

    // explicit cast from []T to []u8 or []u8 to []T
    if (is_slice(wanted_type) && is_slice(actual_type) &&
        (is_u8(wanted_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.child_type) ||
        is_u8(actual_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.child_type)) &&
        (wanted_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.is_const ||
         !actual_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.is_const))
    {
        if (!ir_emit_global_runtime_side_effect(ira, source_instr))
            return ira->codegen->invalid_instruction;
        return ir_resolve_cast(ira, source_instr, value, wanted_type, CastOpResizeSlice, true);
    }

    // explicit cast from [N]u8 to []const T
    if (is_slice(wanted_type) &&
        wanted_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.is_const &&
        actual_type->id == TypeTableEntryIdArray &&
        is_u8(actual_type->data.array.child_type))
    {
        if (!ir_emit_global_runtime_side_effect(ira, source_instr))
            return ira->codegen->invalid_instruction;
        uint64_t child_type_size = type_size(ira->codegen,
                wanted_type->data.structure.fields[0].type_entry->data.pointer.child_type);
        if (actual_type->data.array.len % child_type_size == 0) {
            return ir_resolve_cast(ira, source_instr, value, wanted_type, CastOpBytesToSlice, true);
        } else {
            ir_add_error_node(ira, source_instr->source_node,
                    buf_sprintf("unable to convert %s to %s: size mismatch",
                        buf_ptr(&actual_type->name), buf_ptr(&wanted_type->name)));
            return ira->codegen->invalid_instruction;
        }
    }

    // explicit cast from child type of maybe type to maybe type
    if (wanted_type->id == TypeTableEntryIdMaybe) {
        if (types_match_const_cast_only(wanted_type->data.maybe.child_type, actual_type)) {
            return ir_analyze_maybe_wrap(ira, source_instr, value, wanted_type);
        } else if (actual_type->id == TypeTableEntryIdNumLitInt ||
                   actual_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (ir_num_lit_fits_in_other_type(ira, value, wanted_type->data.maybe.child_type)) {
                return ir_analyze_maybe_wrap(ira, source_instr, value, wanted_type);
            } else {
                return ira->codegen->invalid_instruction;
            }
        }
    }

    // explicit cast from null literal to maybe type
    if (wanted_type->id == TypeTableEntryIdMaybe &&
        actual_type->id == TypeTableEntryIdNullLit)
    {
        return ir_analyze_null_to_maybe(ira, source_instr, value, wanted_type);
    }

    // explicit cast from child type of error type to error type
    if (wanted_type->id == TypeTableEntryIdErrorUnion) {
        if (types_match_const_cast_only(wanted_type->data.error.child_type, actual_type)) {
            return ir_analyze_err_wrap_payload(ira, source_instr, value, wanted_type);
        } else if (actual_type->id == TypeTableEntryIdNumLitInt ||
                   actual_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (ir_num_lit_fits_in_other_type(ira, value, wanted_type->data.error.child_type)) {
                return ir_analyze_err_wrap_payload(ira, source_instr, value, wanted_type);
            } else {
                return ira->codegen->invalid_instruction;
            }
        }
    }

    // explicit cast from pure error to error union type
    if (wanted_type->id == TypeTableEntryIdErrorUnion &&
        actual_type->id == TypeTableEntryIdPureError)
    {
        return ir_analyze_err_wrap_code(ira, source_instr, value, wanted_type);
    }

    // explicit cast from number literal to another type
    // explicit cast from number literal to &const integer
    if (actual_type->id == TypeTableEntryIdNumLitFloat ||
        actual_type->id == TypeTableEntryIdNumLitInt)
    {
        if (wanted_type->id == TypeTableEntryIdPointer &&
            wanted_type->data.pointer.is_const)
        {
            IrInstruction *cast1 = ir_analyze_cast(ira, source_instr, wanted_type->data.pointer.child_type, value);
            if (type_is_invalid(cast1->value.type))
                return ira->codegen->invalid_instruction;

            IrInstruction *cast2 = ir_analyze_cast(ira, source_instr, wanted_type, cast1);
            if (type_is_invalid(cast2->value.type))
                return ira->codegen->invalid_instruction;

            return cast2;
        } else if (ir_num_lit_fits_in_other_type(ira, value, wanted_type_canon)) {
            CastOp op;
            if ((actual_type->id == TypeTableEntryIdNumLitFloat &&
                 wanted_type_canon->id == TypeTableEntryIdFloat) ||
                (actual_type->id == TypeTableEntryIdNumLitInt &&
                 wanted_type_canon->id == TypeTableEntryIdInt))
            {
                op = CastOpNoop;
            } else if (wanted_type_canon->id == TypeTableEntryIdInt) {
                op = CastOpFloatToInt;
            } else if (wanted_type_canon->id == TypeTableEntryIdFloat) {
                op = CastOpIntToFloat;
            } else {
                zig_unreachable();
            }
            return ir_resolve_cast(ira, source_instr, value, wanted_type, op, false);
        } else {
            return ira->codegen->invalid_instruction;
        }
    }

    // explicit cast from typed number to integer or float literal.
    // works when the number is known at compile time
    if (instr_is_comptime(value) &&
        ((actual_type->id == TypeTableEntryIdInt && wanted_type->id == TypeTableEntryIdNumLitInt) ||
        (actual_type->id == TypeTableEntryIdFloat && wanted_type->id == TypeTableEntryIdNumLitFloat)))
    {
        return ir_analyze_number_to_literal(ira, source_instr, value, wanted_type);
    }

    // explicit cast from %void to integer type which can fit it
    bool actual_type_is_void_err = actual_type->id == TypeTableEntryIdErrorUnion &&
        !type_has_bits(actual_type->data.error.child_type);
    bool actual_type_is_pure_err = actual_type->id == TypeTableEntryIdPureError;
    if ((actual_type_is_void_err || actual_type_is_pure_err) &&
        wanted_type->id == TypeTableEntryIdInt)
    {
        return ir_analyze_err_to_int(ira, source_instr, value, wanted_type);
    }

    // explicit cast from integer to pure error
    if (wanted_type->id == TypeTableEntryIdPureError && actual_type->id == TypeTableEntryIdInt &&
        !actual_type->data.integral.is_signed)
    {
        return ir_analyze_int_to_err(ira, source_instr, value);
    }

    // explicit cast from integer to enum type with no payload
    if (actual_type->id == TypeTableEntryIdInt &&
        wanted_type->id == TypeTableEntryIdEnum &&
        wanted_type->data.enumeration.gen_field_count == 0)
    {
        return ir_analyze_int_to_enum(ira, source_instr, value, wanted_type);
    }

    // explicit cast from enum type with no payload to integer
    if (wanted_type->id == TypeTableEntryIdInt &&
        actual_type->id == TypeTableEntryIdEnum &&
        actual_type->data.enumeration.gen_field_count == 0)
    {
        return ir_analyze_enum_to_int(ira, source_instr, value, wanted_type);
    }

    // explicit cast from undefined to anything
    if (actual_type->id == TypeTableEntryIdUndefLit) {
        return ir_analyze_undefined_to_anything(ira, source_instr, value, wanted_type);
    }

    // explicit cast from something to const pointer of it
    if (!type_requires_comptime(actual_type)) {
        TypeTableEntry *const_ptr_actual = get_pointer_to_type(ira->codegen, actual_type, true);
        if (types_match_const_cast_only(wanted_type, const_ptr_actual)) {
            return ir_analyze_cast_ref(ira, source_instr, value, wanted_type);
        }
    }

    ir_add_error_node(ira, source_instr->source_node,
        buf_sprintf("invalid cast from type '%s' to '%s'",
            buf_ptr(&actual_type->name),
            buf_ptr(&wanted_type->name)));
    return ira->codegen->invalid_instruction;
}

static IrInstruction *ir_implicit_cast(IrAnalyze *ira, IrInstruction *value, TypeTableEntry *expected_type) {
    assert(value);
    assert(value != ira->codegen->invalid_instruction);
    assert(!expected_type || !type_is_invalid(expected_type));
    assert(value->value.type);
    assert(!type_is_invalid(value->value.type));
    if (expected_type == nullptr)
        return value; // anything will do
    if (expected_type == value->value.type)
        return value; // match
    if (value->value.type->id == TypeTableEntryIdUnreachable)
        return value;

    ImplicitCastMatchResult result = ir_types_match_with_implicit_cast(ira, expected_type, value->value.type, value);
    switch (result) {
        case ImplicitCastMatchResultNo:
            ir_add_error(ira, value,
                buf_sprintf("expected type '%s', found '%s'",
                    buf_ptr(&expected_type->name),
                    buf_ptr(&value->value.type->name)));
            return ira->codegen->invalid_instruction;

        case ImplicitCastMatchResultYes:
            return ir_analyze_cast(ira, value, expected_type, value);
        case ImplicitCastMatchResultReportedError:
            return ira->codegen->invalid_instruction;
    }

    zig_unreachable();
}

static IrInstruction *ir_get_deref(IrAnalyze *ira, IrInstruction *source_instruction, IrInstruction *ptr) {
    TypeTableEntry *type_entry = ptr->value.type;
    if (type_is_invalid(type_entry)) {
        return ira->codegen->invalid_instruction;
    } else if (type_entry->id == TypeTableEntryIdPointer) {
        TypeTableEntry *child_type = type_entry->data.pointer.child_type;
        if (instr_is_comptime(ptr)) {
            if (ptr->value.data.x_ptr.mut == ConstPtrMutComptimeConst ||
                ptr->value.data.x_ptr.mut == ConstPtrMutComptimeVar)
            {
                ConstExprValue *pointee = const_ptr_pointee(&ptr->value);
                if (pointee->special != ConstValSpecialRuntime) {
                    IrInstruction *result = ir_create_const(&ira->new_irb, source_instruction->scope,
                        source_instruction->source_node, child_type);
                    result->value = *pointee;
                    return result;
                }
            }
        }
        // TODO if the instruction is a const ref instruction we can skip it
        IrInstruction *load_ptr_instruction = ir_build_load_ptr(&ira->new_irb, source_instruction->scope,
                source_instruction->source_node, ptr);
        load_ptr_instruction->value.type = child_type;
        return load_ptr_instruction;
    } else if (type_entry->id == TypeTableEntryIdMetaType) {
        ConstExprValue *ptr_val = ir_resolve_const(ira, ptr, UndefBad);
        if (!ptr_val)
            return ira->codegen->invalid_instruction;

        TypeTableEntry *ptr_type = ptr_val->data.x_type;
        if (ptr_type->id == TypeTableEntryIdPointer) {
            TypeTableEntry *child_type = ptr_type->data.pointer.child_type;
            return ir_create_const_type(&ira->new_irb, source_instruction->scope,
                    source_instruction->source_node, child_type);
        } else {
            ir_add_error(ira, source_instruction,
                buf_sprintf("attempt to dereference non pointer type '%s'", buf_ptr(&ptr_type->name)));
            return ira->codegen->invalid_instruction;
        }
    } else {
        ir_add_error_node(ira, source_instruction->source_node,
            buf_sprintf("attempt to dereference non pointer type '%s'",
                buf_ptr(&type_entry->name)));
        return ira->codegen->invalid_instruction;
    }
}

static TypeTableEntry *ir_analyze_ref(IrAnalyze *ira, IrInstruction *source_instruction, IrInstruction *value,
        bool is_const, bool is_volatile)
{
    IrInstruction *result = ir_get_ref(ira, source_instruction, value, is_const, is_volatile);
    ir_link_new_instruction(result, source_instruction);
    return result->value.type;
}

static bool ir_resolve_usize(IrAnalyze *ira, IrInstruction *value, uint64_t *out) {
    if (type_is_invalid(value->value.type))
        return false;

    IrInstruction *casted_value = ir_implicit_cast(ira, value, ira->codegen->builtin_types.entry_usize);
    if (type_is_invalid(casted_value->value.type))
        return false;

    ConstExprValue *const_val = ir_resolve_const(ira, casted_value, UndefBad);
    if (!const_val)
        return false;

    *out = const_val->data.x_bignum.data.x_uint;
    return true;
}

static bool ir_resolve_bool(IrAnalyze *ira, IrInstruction *value, bool *out) {
    if (type_is_invalid(value->value.type))
        return false;

    IrInstruction *casted_value = ir_implicit_cast(ira, value, ira->codegen->builtin_types.entry_bool);
    if (type_is_invalid(casted_value->value.type))
        return false;

    ConstExprValue *const_val = ir_resolve_const(ira, casted_value, UndefBad);
    if (!const_val)
        return false;

    *out = const_val->data.x_bool;
    return true;
}

static bool ir_resolve_comptime(IrAnalyze *ira, IrInstruction *value, bool *out) {
    if (!value) {
        *out = false;
        return true;
    }
    return ir_resolve_bool(ira, value, out);
}

static bool ir_resolve_atomic_order(IrAnalyze *ira, IrInstruction *value, AtomicOrder *out) {
    if (type_is_invalid(value->value.type))
        return false;

    IrInstruction *casted_value = ir_implicit_cast(ira, value, ira->codegen->builtin_types.entry_atomic_order_enum);
    if (type_is_invalid(casted_value->value.type))
        return false;

    ConstExprValue *const_val = ir_resolve_const(ira, casted_value, UndefBad);
    if (!const_val)
        return false;

    *out = (AtomicOrder)const_val->data.x_enum.tag;
    return true;
}

static bool ir_resolve_global_linkage(IrAnalyze *ira, IrInstruction *value, GlobalLinkageId *out) {
    if (type_is_invalid(value->value.type))
        return false;

    IrInstruction *casted_value = ir_implicit_cast(ira, value, ira->codegen->builtin_types.entry_global_linkage_enum);
    if (type_is_invalid(casted_value->value.type))
        return false;

    ConstExprValue *const_val = ir_resolve_const(ira, casted_value, UndefBad);
    if (!const_val)
        return false;

    *out = (GlobalLinkageId)const_val->data.x_enum.tag;
    return true;
}


static Buf *ir_resolve_str(IrAnalyze *ira, IrInstruction *value) {
    if (type_is_invalid(value->value.type))
        return nullptr;

    TypeTableEntry *str_type = get_slice_type(ira->codegen, ira->codegen->builtin_types.entry_u8, true);
    IrInstruction *casted_value = ir_implicit_cast(ira, value, str_type);
    if (type_is_invalid(casted_value->value.type))
        return nullptr;

    ConstExprValue *const_val = ir_resolve_const(ira, casted_value, UndefBad);
    if (!const_val)
        return nullptr;

    ConstExprValue *ptr_field = &const_val->data.x_struct.fields[slice_ptr_index];
    ConstExprValue *len_field = &const_val->data.x_struct.fields[slice_len_index];

    assert(ptr_field->data.x_ptr.special == ConstPtrSpecialBaseArray);
    ConstExprValue *array_val = ptr_field->data.x_ptr.data.base_array.array_val;
    size_t len = len_field->data.x_bignum.data.x_uint;
    Buf *result = buf_alloc();
    buf_resize(result, len);
    for (size_t i = 0; i < len; i += 1) {
        size_t new_index = ptr_field->data.x_ptr.data.base_array.elem_index + i;
        ConstExprValue *char_val = &array_val->data.x_array.elements[new_index];
        uint64_t big_c = char_val->data.x_bignum.data.x_uint;
        assert(big_c <= UINT8_MAX);
        uint8_t c = (uint8_t)big_c;
        buf_ptr(result)[i] = c;
    }
    return result;
}

static TypeTableEntry *ir_analyze_instruction_return(IrAnalyze *ira,
    IrInstructionReturn *return_instruction)
{
    IrInstruction *value = return_instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ir_unreach_error(ira);
    ira->implicit_return_type_list.append(value);

    IrInstruction *casted_value = ir_implicit_cast(ira, value, ira->explicit_return_type);
    if (casted_value == ira->codegen->invalid_instruction)
        return ir_unreach_error(ira);

    ir_build_return_from(&ira->new_irb, &return_instruction->base, casted_value);
    return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
}

static TypeTableEntry *ir_analyze_instruction_const(IrAnalyze *ira, IrInstructionConst *const_instruction) {
    ConstExprValue *out_val = ir_build_const_from(ira, &const_instruction->base);
    *out_val = const_instruction->base.value;
    return const_instruction->base.value.type;
}

static TypeTableEntry *ir_analyze_bin_op_bool(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrInstruction *op1 = bin_op_instruction->op1->other;
    if (type_is_invalid(op1->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *op2 = bin_op_instruction->op2->other;
    if (type_is_invalid(op2->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *bool_type = ira->codegen->builtin_types.entry_bool;

    IrInstruction *casted_op1 = ir_implicit_cast(ira, op1, bool_type);
    if (casted_op1 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op2 = ir_implicit_cast(ira, op2, bool_type);
    if (casted_op2 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *op1_val = &casted_op1->value;
    ConstExprValue *op2_val = &casted_op2->value;
    if (op1_val->special != ConstValSpecialRuntime && op2_val->special != ConstValSpecialRuntime) {
        ConstExprValue *out_val = ir_build_const_from(ira, &bin_op_instruction->base);

        assert(casted_op1->value.type->id == TypeTableEntryIdBool);
        assert(casted_op2->value.type->id == TypeTableEntryIdBool);
        if (bin_op_instruction->op_id == IrBinOpBoolOr) {
            out_val->data.x_bool = op1_val->data.x_bool || op2_val->data.x_bool;
        } else if (bin_op_instruction->op_id == IrBinOpBoolAnd) {
            out_val->data.x_bool = op1_val->data.x_bool && op2_val->data.x_bool;
        } else {
            zig_unreachable();
        }
        return bool_type;
    }

    ir_build_bin_op_from(&ira->new_irb, &bin_op_instruction->base, bin_op_instruction->op_id,
            casted_op1, casted_op2, bin_op_instruction->safety_check_on);
    return bool_type;
}

static TypeTableEntry *ir_analyze_bin_op_cmp(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrInstruction *op1 = bin_op_instruction->op1->other;
    IrInstruction *op2 = bin_op_instruction->op2->other;

    IrBinOp op_id = bin_op_instruction->op_id;
    bool is_equality_cmp = (op_id == IrBinOpCmpEq || op_id == IrBinOpCmpNotEq);
    if (is_equality_cmp &&
        ((op1->value.type->id == TypeTableEntryIdNullLit && op2->value.type->id == TypeTableEntryIdMaybe) ||
        (op2->value.type->id == TypeTableEntryIdNullLit && op1->value.type->id == TypeTableEntryIdMaybe) ||
        (op1->value.type->id == TypeTableEntryIdNullLit && op2->value.type->id == TypeTableEntryIdNullLit)))
    {
        if (op1->value.type->id == TypeTableEntryIdNullLit && op2->value.type->id == TypeTableEntryIdNullLit) {
            ConstExprValue *out_val = ir_build_const_from(ira, &bin_op_instruction->base);
            out_val->data.x_bool = (op_id == IrBinOpCmpEq);
            return ira->codegen->builtin_types.entry_bool;
        }
        IrInstruction *maybe_op;
        if (op1->value.type->id == TypeTableEntryIdNullLit) {
            maybe_op = op2;
        } else if (op2->value.type->id == TypeTableEntryIdNullLit) {
            maybe_op = op1;
        } else {
            zig_unreachable();
        }
        if (instr_is_comptime(maybe_op)) {
            ConstExprValue *maybe_val = ir_resolve_const(ira, maybe_op, UndefBad);
            if (!maybe_val)
                return ira->codegen->builtin_types.entry_invalid;
            bool is_null = (maybe_val->data.x_maybe == nullptr);
            ConstExprValue *out_val = ir_build_const_from(ira, &bin_op_instruction->base);
            out_val->data.x_bool = (op_id == IrBinOpCmpEq) ? is_null : !is_null;
            return ira->codegen->builtin_types.entry_bool;
        }

        IrInstruction *is_non_null = ir_build_test_nonnull(&ira->new_irb, bin_op_instruction->base.scope,
            bin_op_instruction->base.source_node, maybe_op);
        is_non_null->value.type = ira->codegen->builtin_types.entry_bool;

        if (op_id == IrBinOpCmpEq) {
            ir_build_bool_not_from(&ira->new_irb, &bin_op_instruction->base, is_non_null);
        } else {
            ir_link_new_instruction(is_non_null, &bin_op_instruction->base);
        }
        return ira->codegen->builtin_types.entry_bool;
    }

    IrInstruction *instructions[] = {op1, op2};
    TypeTableEntry *resolved_type = ir_resolve_peer_types(ira, bin_op_instruction->base.source_node, instructions, 2);
    if (type_is_invalid(resolved_type))
        return resolved_type;

    AstNode *source_node = bin_op_instruction->base.source_node;
    switch (resolved_type->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable(); // handled above

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
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
            if (!is_equality_cmp) {
                ir_add_error_node(ira, source_node,
                    buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
                return ira->codegen->builtin_types.entry_invalid;
            }
            break;

        case TypeTableEntryIdEnum:
            if (!is_equality_cmp || resolved_type->data.enumeration.gen_field_count != 0) {
                ir_add_error_node(ira, source_node,
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
            ir_add_error_node(ira, source_node,
                buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
            return ira->codegen->builtin_types.entry_invalid;

        case TypeTableEntryIdEnumTag:
            zig_panic("TODO implement comparison for enum tag type");

        case TypeTableEntryIdVar:
            zig_unreachable();
    }

    IrInstruction *casted_op1 = ir_implicit_cast(ira, op1, resolved_type);
    if (casted_op1 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op2 = ir_implicit_cast(ira, op2, resolved_type);
    if (casted_op2 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *op1_val = &casted_op1->value;
    ConstExprValue *op2_val = &casted_op2->value;
    if ((value_is_comptime(op1_val) && value_is_comptime(op2_val)) || resolved_type->id == TypeTableEntryIdVoid) {
        bool type_can_gt_lt_cmp = (resolved_type->id == TypeTableEntryIdNumLitFloat ||
                resolved_type->id == TypeTableEntryIdNumLitInt ||
                resolved_type->id == TypeTableEntryIdFloat ||
                resolved_type->id == TypeTableEntryIdInt);
        bool answer;
        if (type_can_gt_lt_cmp) {
            bool (*bignum_cmp)(BigNum *, BigNum *);
            if (op_id == IrBinOpCmpEq) {
                bignum_cmp = bignum_cmp_eq;
            } else if (op_id == IrBinOpCmpNotEq) {
                bignum_cmp = bignum_cmp_neq;
            } else if (op_id == IrBinOpCmpLessThan) {
                bignum_cmp = bignum_cmp_lt;
            } else if (op_id == IrBinOpCmpGreaterThan) {
                bignum_cmp = bignum_cmp_gt;
            } else if (op_id == IrBinOpCmpLessOrEq) {
                bignum_cmp = bignum_cmp_lte;
            } else if (op_id == IrBinOpCmpGreaterOrEq) {
                bignum_cmp = bignum_cmp_gte;
            } else {
                zig_unreachable();
            }

            answer = bignum_cmp(&op1_val->data.x_bignum, &op2_val->data.x_bignum);
        } else {
            bool are_equal = resolved_type->id == TypeTableEntryIdVoid || const_values_equal(op1_val, op2_val);
            if (op_id == IrBinOpCmpEq) {
                answer = are_equal;
            } else if (op_id == IrBinOpCmpNotEq) {
                answer = !are_equal;
            } else {
                zig_unreachable();
            }
        }

        ConstExprValue *out_val = ir_build_const_from(ira, &bin_op_instruction->base);
        out_val->data.x_bool = answer;
        return ira->codegen->builtin_types.entry_bool;
    }

    // some comparisons with unsigned numbers can be evaluated
    if (resolved_type->id == TypeTableEntryIdInt && !resolved_type->data.integral.is_signed) {
        ConstExprValue *known_left_val;
        IrBinOp flipped_op_id;
        if (value_is_comptime(op1_val)) {
            known_left_val = op1_val;
            flipped_op_id = op_id;
        } else if (value_is_comptime(op2_val)) {
            known_left_val = op2_val;
            if (op_id == IrBinOpCmpLessThan) {
                flipped_op_id = IrBinOpCmpGreaterThan;
            } else if (op_id == IrBinOpCmpGreaterThan) {
                flipped_op_id = IrBinOpCmpLessThan;
            } else if (op_id == IrBinOpCmpLessOrEq) {
                flipped_op_id = IrBinOpCmpGreaterOrEq;
            } else if (op_id == IrBinOpCmpGreaterOrEq) {
                flipped_op_id = IrBinOpCmpLessOrEq;
            } else {
                flipped_op_id = op_id;
            }
        } else {
            known_left_val = nullptr;
        }
        if (known_left_val != nullptr && known_left_val->data.x_bignum.data.x_uint == 0 &&
            (flipped_op_id == IrBinOpCmpLessOrEq || flipped_op_id == IrBinOpCmpGreaterThan))
        {
            bool answer = (flipped_op_id == IrBinOpCmpLessOrEq);
            ConstExprValue *out_val = ir_build_const_from(ira, &bin_op_instruction->base);
            out_val->data.x_bool = answer;
            return ira->codegen->builtin_types.entry_bool;
        }
    }

    ir_build_bin_op_from(&ira->new_irb, &bin_op_instruction->base, op_id,
            casted_op1, casted_op2, bin_op_instruction->safety_check_on);

    return ira->codegen->builtin_types.entry_bool;
}

static int ir_eval_bignum(ConstExprValue *op1_val, ConstExprValue *op2_val,
        ConstExprValue *out_val, bool (*bignum_fn)(BigNum *, BigNum *, BigNum *),
        TypeTableEntry *type, bool wrapping_op)
{
    bool is_int = false;
    bool is_float = false;
    if (bignum_fn == bignum_div || bignum_fn == bignum_rem) {
        if (type->id == TypeTableEntryIdInt ||
            type->id == TypeTableEntryIdNumLitInt)
        {
            is_int = true;
        } else if (type->id == TypeTableEntryIdFloat ||
                   type->id == TypeTableEntryIdNumLitFloat)
        {
            is_float = true;
        }
        if ((is_int && op2_val->data.x_bignum.data.x_uint == 0) ||
            (is_float && op2_val->data.x_bignum.data.x_float == 0.0))
        {
            return ErrorDivByZero;
        }
    }

    bool overflow = bignum_fn(&out_val->data.x_bignum, &op1_val->data.x_bignum, &op2_val->data.x_bignum);
    if (overflow) {
        return ErrorOverflow;
    }

    if (type->id == TypeTableEntryIdInt && !bignum_fits_in_bits(&out_val->data.x_bignum,
                type->data.integral.bit_count, type->data.integral.is_signed))
    {
        if (wrapping_op) {
            if (type->data.integral.is_signed) {
                out_val->data.x_bignum.data.x_uint = max_unsigned_val(type) - out_val->data.x_bignum.data.x_uint + 1;
                out_val->data.x_bignum.is_negative = !out_val->data.x_bignum.is_negative;
            } else if (out_val->data.x_bignum.is_negative) {
                out_val->data.x_bignum.data.x_uint = max_unsigned_val(type) - out_val->data.x_bignum.data.x_uint + 1;
                out_val->data.x_bignum.is_negative = false;
            } else {
                bignum_truncate(&out_val->data.x_bignum, type->data.integral.bit_count);
            }
        } else {
            return ErrorOverflow;
        }
    }

    out_val->special = ConstValSpecialStatic;
    return 0;
}

static int ir_eval_math_op(TypeTableEntry *canon_type, ConstExprValue *op1_val,
        IrBinOp op_id, ConstExprValue *op2_val, ConstExprValue *out_val)
{
    switch (op_id) {
        case IrBinOpInvalid:
        case IrBinOpBoolOr:
        case IrBinOpBoolAnd:
        case IrBinOpCmpEq:
        case IrBinOpCmpNotEq:
        case IrBinOpCmpLessThan:
        case IrBinOpCmpGreaterThan:
        case IrBinOpCmpLessOrEq:
        case IrBinOpCmpGreaterOrEq:
        case IrBinOpArrayCat:
        case IrBinOpArrayMult:
            zig_unreachable();
        case IrBinOpBinOr:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_or, canon_type, false);
        case IrBinOpBinXor:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_xor, canon_type, false);
        case IrBinOpBinAnd:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_and, canon_type, false);
        case IrBinOpBitShiftLeft:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_shl, canon_type, false);
        case IrBinOpBitShiftLeftWrap:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_shl, canon_type, true);
        case IrBinOpBitShiftRight:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_shr, canon_type, false);
        case IrBinOpAdd:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_add, canon_type, false);
        case IrBinOpAddWrap:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_add, canon_type, true);
        case IrBinOpSub:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_sub, canon_type, false);
        case IrBinOpSubWrap:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_sub, canon_type, true);
        case IrBinOpMult:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_mul, canon_type, false);
        case IrBinOpMultWrap:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_mul, canon_type, true);
        case IrBinOpDiv:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_div, canon_type, false);
        case IrBinOpRem:
            return ir_eval_bignum(op1_val, op2_val, out_val, bignum_rem, canon_type, false);
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_bin_op_math(IrAnalyze *ira, IrInstructionBinOp *bin_op_instruction) {
    IrInstruction *op1 = bin_op_instruction->op1->other;
    IrInstruction *op2 = bin_op_instruction->op2->other;
    IrInstruction *instructions[] = {op1, op2};
    TypeTableEntry *resolved_type = ir_resolve_peer_types(ira, bin_op_instruction->base.source_node, instructions, 2);
    if (type_is_invalid(resolved_type))
        return resolved_type;
    TypeTableEntry *canon_resolved_type = get_underlying_type(resolved_type);
    IrBinOp op_id = bin_op_instruction->op_id;

    if (canon_resolved_type->id == TypeTableEntryIdInt ||
        canon_resolved_type->id == TypeTableEntryIdNumLitInt)
    {
        // int
    } else if ((canon_resolved_type->id == TypeTableEntryIdFloat ||
                canon_resolved_type->id == TypeTableEntryIdNumLitFloat) &&
        (op_id == IrBinOpAdd ||
            op_id == IrBinOpSub ||
            op_id == IrBinOpMult ||
            op_id == IrBinOpDiv ||
            op_id == IrBinOpRem))
    {
        // float
    } else {
        AstNode *source_node = bin_op_instruction->base.source_node;
        ir_add_error_node(ira, source_node,
            buf_sprintf("invalid operands to binary expression: '%s' and '%s'",
                buf_ptr(&op1->value.type->name),
                buf_ptr(&op2->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *casted_op1 = ir_implicit_cast(ira, op1, resolved_type);
    if (casted_op1 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op2 = ir_implicit_cast(ira, op2, resolved_type);
    if (casted_op2 == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;


    if (casted_op1->value.special != ConstValSpecialRuntime && casted_op2->value.special != ConstValSpecialRuntime) {
        ConstExprValue *op1_val = &casted_op1->value;
        ConstExprValue *op2_val = &casted_op2->value;
        ConstExprValue *out_val = &bin_op_instruction->base.value;

        bin_op_instruction->base.other = &bin_op_instruction->base;

        int err;
        if ((err = ir_eval_math_op(canon_resolved_type, op1_val, op_id, op2_val, out_val))) {
            if (err == ErrorDivByZero) {
                ir_add_error_node(ira, bin_op_instruction->base.source_node,
                        buf_sprintf("division by zero is undefined"));
                return ira->codegen->builtin_types.entry_invalid;
            } else if (err == ErrorOverflow) {
                ir_add_error_node(ira, bin_op_instruction->base.source_node,
                        buf_sprintf("operation caused overflow"));
                return ira->codegen->builtin_types.entry_invalid;
            }
            return ira->codegen->builtin_types.entry_invalid;
        }

        ir_num_lit_fits_in_other_type(ira, &bin_op_instruction->base, resolved_type);
        return resolved_type;

    }

    ir_build_bin_op_from(&ira->new_irb, &bin_op_instruction->base, op_id,
            casted_op1, casted_op2, bin_op_instruction->safety_check_on);
    return resolved_type;
}

static TypeTableEntry *ir_analyze_array_cat(IrAnalyze *ira, IrInstructionBinOp *instruction) {
    IrInstruction *op1 = instruction->op1->other;
    TypeTableEntry *op1_canon_type = get_underlying_type(op1->value.type);
    if (type_is_invalid(op1_canon_type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *op2 = instruction->op2->other;
    TypeTableEntry *op2_canon_type = get_underlying_type(op2->value.type);
    if (type_is_invalid(op2_canon_type))
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *op1_val = ir_resolve_const(ira, op1, UndefBad);
    if (!op1_val)
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *op2_val = ir_resolve_const(ira, op2, UndefBad);
    if (!op2_val)
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *op1_array_val;
    size_t op1_array_index;
    size_t op1_array_end;
    TypeTableEntry *child_type;
    if (op1_canon_type->id == TypeTableEntryIdArray) {
        child_type = op1_canon_type->data.array.child_type;
        op1_array_val = op1_val;
        op1_array_index = 0;
        op1_array_end = op1_canon_type->data.array.len;
    } else if (op1_canon_type->id == TypeTableEntryIdPointer &&
        op1_canon_type->data.pointer.child_type == ira->codegen->builtin_types.entry_u8 &&
        op1_val->data.x_ptr.special == ConstPtrSpecialBaseArray &&
        op1_val->data.x_ptr.data.base_array.is_cstr)
    {
        child_type = op1_canon_type->data.pointer.child_type;
        op1_array_val = op1_val->data.x_ptr.data.base_array.array_val;
        op1_array_index = op1_val->data.x_ptr.data.base_array.elem_index;
        op1_array_end = op1_array_val->type->data.array.len - 1;
    } else if (is_slice(op1_canon_type)) {
        TypeTableEntry *ptr_type = op1_canon_type->data.structure.fields[slice_ptr_index].type_entry;
        child_type = ptr_type->data.pointer.child_type;
        ConstExprValue *ptr_val = &op1_val->data.x_struct.fields[slice_ptr_index];
        assert(ptr_val->data.x_ptr.special == ConstPtrSpecialBaseArray);
        op1_array_val = ptr_val->data.x_ptr.data.base_array.array_val;
        op1_array_index = ptr_val->data.x_ptr.data.base_array.elem_index;
        op1_array_end = op1_array_val->type->data.array.len;
    } else {
        ir_add_error(ira, op1,
            buf_sprintf("expected array or C string literal, found '%s'", buf_ptr(&op1->value.type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    }

    ConstExprValue *op2_array_val;
    size_t op2_array_index;
    size_t op2_array_end;
    if (op2_canon_type->id == TypeTableEntryIdArray) {
        if (op2_canon_type->data.array.child_type != child_type) {
            ir_add_error(ira, op2, buf_sprintf("expected array of type '%s', found '%s'",
                        buf_ptr(&child_type->name),
                        buf_ptr(&op2->value.type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
        op2_array_val = op2_val;
        op2_array_index = 0;
        op2_array_end = op2_array_val->type->data.array.len;
    } else if (op2_canon_type->id == TypeTableEntryIdPointer &&
        op2_canon_type->data.pointer.child_type == ira->codegen->builtin_types.entry_u8 &&
        op2_val->data.x_ptr.special == ConstPtrSpecialBaseArray &&
        op2_val->data.x_ptr.data.base_array.is_cstr)
    {
        if (child_type != ira->codegen->builtin_types.entry_u8) {
            ir_add_error(ira, op2, buf_sprintf("expected array of type '%s', found '%s'",
                        buf_ptr(&child_type->name),
                        buf_ptr(&op2->value.type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
        op2_array_val = op2_val->data.x_ptr.data.base_array.array_val;
        op2_array_index = op2_val->data.x_ptr.data.base_array.elem_index;
        op2_array_end = op2_array_val->type->data.array.len - 1;
    } else if (is_slice(op2_canon_type)) {
        TypeTableEntry *ptr_type = op2_canon_type->data.structure.fields[slice_ptr_index].type_entry;
        if (ptr_type->data.pointer.child_type != child_type) {
            ir_add_error(ira, op2, buf_sprintf("expected array of type '%s', found '%s'",
                        buf_ptr(&child_type->name),
                        buf_ptr(&op2->value.type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
        ConstExprValue *ptr_val = &op2_val->data.x_struct.fields[slice_ptr_index];
        assert(ptr_val->data.x_ptr.special == ConstPtrSpecialBaseArray);
        op2_array_val = ptr_val->data.x_ptr.data.base_array.array_val;
        op2_array_index = ptr_val->data.x_ptr.data.base_array.elem_index;
        op2_array_end = op2_array_val->type->data.array.len;
    } else {
        ir_add_error(ira, op2,
            buf_sprintf("expected array or C string literal, found '%s'", buf_ptr(&op2->value.type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    }

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);

    TypeTableEntry *result_type;
    ConstExprValue *out_array_val;
    size_t new_len = (op1_array_end - op1_array_index) + (op2_array_end - op2_array_index);
    if (op1_canon_type->id == TypeTableEntryIdArray || op2_canon_type->id == TypeTableEntryIdArray) {
        result_type = get_array_type(ira->codegen, child_type, new_len);

        out_array_val = out_val;
    } else {
        new_len += 1; // null byte

        result_type = get_pointer_to_type(ira->codegen, child_type, true);

        out_array_val = allocate<ConstExprValue>(1);
        out_array_val->special = ConstValSpecialStatic;
        out_array_val->type = get_array_type(ira->codegen, child_type, new_len);
        out_val->data.x_ptr.special = ConstPtrSpecialBaseArray;
        out_val->data.x_ptr.data.base_array.is_cstr = true;
        out_val->data.x_ptr.data.base_array.array_val = out_array_val;
        out_val->data.x_ptr.data.base_array.elem_index = 0;
    }
    out_array_val->data.x_array.elements = allocate<ConstExprValue>(new_len);

    size_t next_index = 0;
    for (size_t i = op1_array_index; i < op1_array_end; i += 1, next_index += 1) {
        out_array_val->data.x_array.elements[next_index] = op1_array_val->data.x_array.elements[i];
    }
    for (size_t i = op2_array_index; i < op2_array_end; i += 1, next_index += 1) {
        out_array_val->data.x_array.elements[next_index] = op2_array_val->data.x_array.elements[i];
    }
    if (next_index < new_len) {
        ConstExprValue *null_byte = &out_array_val->data.x_array.elements[next_index];
        init_const_unsigned_negative(null_byte, child_type, 0, false);
        next_index += 1;
    }
    assert(next_index == new_len);

    return result_type;
}

static TypeTableEntry *ir_analyze_array_mult(IrAnalyze *ira, IrInstructionBinOp *instruction) {
    IrInstruction *op1 = instruction->op1->other;
    if (type_is_invalid(op1->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *op2 = instruction->op2->other;
    if (type_is_invalid(op2->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *array_val = ir_resolve_const(ira, op1, UndefBad);
    if (!array_val)
        return ira->codegen->builtin_types.entry_invalid;

    uint64_t mult_amt;
    if (!ir_resolve_usize(ira, op2, &mult_amt))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *array_canon_type = get_underlying_type(op1->value.type);
    if (array_canon_type->id != TypeTableEntryIdArray) {
        ir_add_error(ira, op1, buf_sprintf("expected array type, found '%s'", buf_ptr(&op1->value.type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    }

    uint64_t old_array_len = array_canon_type->data.array.len;

    BigNum array_len;
    bignum_init_unsigned(&array_len, old_array_len);
    if (bignum_multiply_by_scalar(&array_len, mult_amt)) {
        ir_add_error(ira, &instruction->base, buf_sprintf("operation results in overflow"));
        return ira->codegen->builtin_types.entry_invalid;
    }

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);

    uint64_t new_array_len = array_len.data.x_uint;
    out_val->data.x_array.elements = allocate<ConstExprValue>(new_array_len);

    uint64_t i = 0;
    for (uint64_t x = 0; x < mult_amt; x += 1) {
        for (uint64_t y = 0; y < old_array_len; y += 1) {
            out_val->data.x_array.elements[i] = array_val->data.x_array.elements[y];
            i += 1;
        }
    }
    assert(i == new_array_len);

    TypeTableEntry *child_type = array_canon_type->data.array.child_type;
    return get_array_type(ira->codegen, child_type, new_array_len);
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
        case IrBinOpRem:
            return ir_analyze_bin_op_math(ira, bin_op_instruction);
        case IrBinOpArrayCat:
            return ir_analyze_array_cat(ira, bin_op_instruction);
        case IrBinOpArrayMult:
            return ir_analyze_array_mult(ira, bin_op_instruction);
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_decl_var(IrAnalyze *ira, IrInstructionDeclVar *decl_var_instruction) {
    VariableTableEntry *var = decl_var_instruction->var;

    IrInstruction *init_value = decl_var_instruction->init_value->other;
    if (type_is_invalid(init_value->value.type)) {
        var->value->type = ira->codegen->builtin_types.entry_invalid;
        return var->value->type;
    }

    AstNodeVariableDeclaration *variable_declaration = &var->decl_node->data.variable_declaration;
    bool is_export = (variable_declaration->visib_mod == VisibModExport);
    bool is_extern = variable_declaration->is_extern;

    var->ref_count = 0;

    TypeTableEntry *explicit_type = nullptr;
    IrInstruction *var_type = nullptr;
    if (decl_var_instruction->var_type != nullptr) {
        var_type = decl_var_instruction->var_type->other;
        TypeTableEntry *proposed_type = ir_resolve_type(ira, var_type);
        explicit_type = validate_var_type(ira->codegen, var_type->source_node, proposed_type);
        if (type_is_invalid(explicit_type)) {
            var->value->type = ira->codegen->builtin_types.entry_invalid;
            return var->value->type;
        }
    }

    AstNode *source_node = decl_var_instruction->base.source_node;

    IrInstruction *casted_init_value = ir_implicit_cast(ira, init_value, explicit_type);
    TypeTableEntry *result_type = get_underlying_type(casted_init_value->value.type);
    if (type_is_invalid(result_type)) {
        result_type = ira->codegen->builtin_types.entry_invalid;
    }

    bool is_comptime_var = ir_get_var_is_comptime(var);

    switch (result_type->id) {
        case TypeTableEntryIdTypeDecl:
            zig_unreachable();
        case TypeTableEntryIdInvalid:
            break; // handled above
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
            if (is_export || is_extern || (!var->src_is_const && !is_comptime_var)) {
                ir_add_error_node(ira, source_node, buf_sprintf("unable to infer variable type"));
                result_type = ira->codegen->builtin_types.entry_invalid;
            }
            break;
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdNullLit:
            ir_add_error_node(ira, source_node,
                buf_sprintf("variable of type '%s' not allowed", buf_ptr(&result_type->name)));
            result_type = ira->codegen->builtin_types.entry_invalid;
            break;
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdNamespace:
            if (casted_init_value->value.special == ConstValSpecialRuntime) {
                ir_add_error_node(ira, source_node,
                    buf_sprintf("variable of type '%s' must be constant", buf_ptr(&result_type->name)));
                result_type = ira->codegen->builtin_types.entry_invalid;
            }
            break;
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdEnumTag:
        case TypeTableEntryIdArgTuple:
            // OK
            break;
    }

    var->value->type = result_type;
    assert(var->value->type);

    if (type_is_invalid(result_type)) {
        decl_var_instruction->base.other = &decl_var_instruction->base;
        return ira->codegen->builtin_types.entry_void;
    }

    bool is_comptime = ir_get_var_is_comptime(var);

    if (casted_init_value->value.special != ConstValSpecialRuntime) {
        if (var->mem_slot_index != SIZE_MAX) {
            assert(var->mem_slot_index < ira->exec_context.mem_slot_count);
            ConstExprValue *mem_slot = &ira->exec_context.mem_slot_list[var->mem_slot_index];
            *mem_slot = casted_init_value->value;

            if (is_comptime) {
                ir_build_const_from(ira, &decl_var_instruction->base);
                return ira->codegen->builtin_types.entry_void;
            }
        }
    } else if (is_comptime) {
        ir_add_error(ira, &decl_var_instruction->base,
                buf_sprintf("cannot store runtime value in compile time variable"));
        var->value->type = ira->codegen->builtin_types.entry_invalid;
        return ira->codegen->builtin_types.entry_invalid;
    }

    ir_build_var_decl_from(&ira->new_irb, &decl_var_instruction->base, var, var_type, casted_init_value);

    FnTableEntry *fn_entry = exec_fn_entry(ira->new_irb.exec);
    if (fn_entry)
        fn_entry->variable_list.append(var);

    return ira->codegen->builtin_types.entry_void;
}

static bool ir_analyze_fn_call_inline_arg(IrAnalyze *ira, AstNode *fn_proto_node,
    IrInstruction *arg, Scope **exec_scope, size_t *next_proto_i)
{
    AstNode *param_decl_node = fn_proto_node->data.fn_proto.params.at(*next_proto_i);
    assert(param_decl_node->type == NodeTypeParamDecl);
    AstNode *param_type_node = param_decl_node->data.param_decl.type;
    TypeTableEntry *param_type = analyze_type_expr(ira->codegen, *exec_scope, param_type_node);
    if (type_is_invalid(param_type))
        return false;

    IrInstruction *casted_arg = ir_implicit_cast(ira, arg, param_type);
    if (type_is_invalid(casted_arg->value.type))
        return false;

    ConstExprValue *arg_val = ir_resolve_const(ira, casted_arg, UndefBad);
    if (!arg_val)
        return false;

    Buf *param_name = param_decl_node->data.param_decl.name;
    VariableTableEntry *var = add_variable(ira->codegen, param_decl_node,
        *exec_scope, param_name, true, arg_val, nullptr);
    *exec_scope = var->child_scope;
    *next_proto_i += 1;

    return true;
}

static bool ir_analyze_fn_call_generic_arg(IrAnalyze *ira, AstNode *fn_proto_node,
    IrInstruction *arg, Scope **child_scope, size_t *next_proto_i,
    GenericFnTypeId *generic_id, FnTypeId *fn_type_id, IrInstruction **casted_args,
    FnTableEntry *impl_fn)
{
    AstNode *param_decl_node = fn_proto_node->data.fn_proto.params.at(*next_proto_i);
    assert(param_decl_node->type == NodeTypeParamDecl);
    bool is_var_args = param_decl_node->data.param_decl.is_var_args;
    bool arg_part_of_generic_id = false;
    IrInstruction *casted_arg;
    if (is_var_args) {
        arg_part_of_generic_id = true;
        casted_arg = arg;
    } else {
        AstNode *param_type_node = param_decl_node->data.param_decl.type;
        TypeTableEntry *param_type = analyze_type_expr(ira->codegen, *child_scope, param_type_node);
        if (type_is_invalid(param_type))
            return false;

        bool is_var_type = (param_type->id == TypeTableEntryIdVar);
        if (is_var_type) {
            arg_part_of_generic_id = true;
            casted_arg = arg;
        } else {
            casted_arg = ir_implicit_cast(ira, arg, param_type);
            if (type_is_invalid(casted_arg->value.type))
                return false;
        }
    }

    bool comptime_arg = param_decl_node->data.param_decl.is_inline;

    ConstExprValue *arg_val;

    if (comptime_arg) {
        arg_part_of_generic_id = true;
        arg_val = ir_resolve_const(ira, casted_arg, UndefBad);
        if (!arg_val)
            return false;
    } else {
        arg_val = create_const_runtime(casted_arg->value.type);
    }
    if (arg_part_of_generic_id) {
        generic_id->params[generic_id->param_count] = *arg_val;
        generic_id->param_count += 1;
    }

    Buf *param_name = param_decl_node->data.param_decl.name;
    if (!is_var_args) {
        VariableTableEntry *var = add_variable(ira->codegen, param_decl_node,
            *child_scope, param_name, true, arg_val, nullptr);
        *child_scope = var->child_scope;
        var->shadowable = !comptime_arg;

        *next_proto_i += 1;
    }

    if (!comptime_arg) {
        if (type_requires_comptime(casted_arg->value.type)) {
            ir_add_error(ira, casted_arg,
                buf_sprintf("parameter of type '%s' requires comptime", buf_ptr(&casted_arg->value.type->name)));
            return false;
        }

        casted_args[fn_type_id->param_count] = casted_arg;
        FnTypeParamInfo *param_info = &fn_type_id->param_info[fn_type_id->param_count];
        param_info->type = casted_arg->value.type;
        param_info->is_noalias = param_decl_node->data.param_decl.is_noalias;
        impl_fn->param_source_nodes[fn_type_id->param_count] = param_decl_node;
        fn_type_id->param_count += 1;
    }

    return true;
}

static VariableTableEntry *get_fn_var_by_index(FnTableEntry *fn_entry, size_t index) {
    size_t next_var_i = 0;
    FnGenParamInfo *gen_param_info = fn_entry->type_entry->data.fn.gen_param_info;
    for (size_t param_i = 0; param_i < index; param_i += 1) {
        FnGenParamInfo *info = &gen_param_info[param_i];
        if (info->gen_index == SIZE_MAX)
            continue;

        next_var_i += 1;
    }
    FnGenParamInfo *info = &gen_param_info[index];
    if (info->gen_index == SIZE_MAX)
        return nullptr;

    return fn_entry->variable_list.at(next_var_i);
}

static IrInstruction *ir_get_var_ptr(IrAnalyze *ira, IrInstruction *instruction,
        VariableTableEntry *var, bool is_const_ptr, bool is_volatile_ptr)
{
    assert(var->value->type);
    if (type_is_invalid(var->value->type))
        return ira->codegen->invalid_instruction;

    bool comptime_var_mem = ir_get_var_is_comptime(var);

    ConstExprValue *mem_slot = nullptr;
    if (var->value->special == ConstValSpecialStatic) {
        mem_slot = var->value;
    } else {
        // TODO once the analyze code is fully ported over to IR we won't need this SIZE_MAX thing.
        if (var->mem_slot_index != SIZE_MAX && (comptime_var_mem || var->gen_is_const))
            mem_slot = &ira->exec_context.mem_slot_list[var->mem_slot_index];
    }

    bool is_const = (var->value->type->id == TypeTableEntryIdMetaType) ? is_const_ptr : var->src_is_const;
    bool is_volatile = (var->value->type->id == TypeTableEntryIdMetaType) ? is_volatile_ptr : false;
    if (mem_slot && mem_slot->special != ConstValSpecialRuntime) {
        ConstPtrMut ptr_mut;
        if (comptime_var_mem) {
            ptr_mut = ConstPtrMutComptimeVar;
        } else if (var->gen_is_const) {
            ptr_mut = ConstPtrMutComptimeConst;
        } else {
            assert(!comptime_var_mem);
            ptr_mut = ConstPtrMutRuntimeVar;
        }
        return ir_get_const_ptr(ira, instruction, mem_slot, var->value->type,
                ptr_mut, is_const, is_volatile);
    } else {
        IrInstruction *var_ptr_instruction = ir_build_var_ptr(&ira->new_irb,
                instruction->scope, instruction->source_node, var, is_const, is_volatile);
        var_ptr_instruction->value.type = get_pointer_to_type(ira->codegen, var->value->type, var->src_is_const);
        type_ensure_zero_bits_known(ira->codegen, var->value->type);
        return var_ptr_instruction;
    }
}

static TypeTableEntry *ir_analyze_fn_call(IrAnalyze *ira, IrInstructionCall *call_instruction,
    FnTableEntry *fn_entry, TypeTableEntry *fn_type, IrInstruction *fn_ref,
    IrInstruction *first_arg_ptr, bool comptime_fn_call, bool inline_fn_call)
{
    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;
    size_t first_arg_1_or_0 = first_arg_ptr ? 1 : 0;
    size_t var_args_1_or_0 = fn_type_id->is_var_args ? 1 : 0;
    size_t src_param_count = fn_type_id->param_count - var_args_1_or_0;
    size_t call_param_count = call_instruction->arg_count + first_arg_1_or_0;
    AstNode *source_node = call_instruction->base.source_node;

    AstNode *fn_proto_node = fn_entry ? fn_entry->proto_node : nullptr;;

    if (fn_type_id->is_var_args) {
        if (call_param_count < src_param_count) {
            ErrorMsg *msg = ir_add_error_node(ira, source_node,
                buf_sprintf("expected at least %zu arguments, found %zu", src_param_count, call_param_count));
            if (fn_proto_node) {
                add_error_note(ira->codegen, msg, fn_proto_node,
                    buf_sprintf("declared here"));
            }
            return ira->codegen->builtin_types.entry_invalid;
        }
    } else if (src_param_count != call_param_count) {
        ErrorMsg *msg = ir_add_error_node(ira, source_node,
            buf_sprintf("expected %zu arguments, found %zu", src_param_count, call_param_count));
        if (fn_proto_node) {
            add_error_note(ira->codegen, msg, fn_proto_node,
                buf_sprintf("declared here"));
        }
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (comptime_fn_call) {
        // No special handling is needed for compile time evaluation of generic functions.
        if (!fn_entry || fn_entry->type_entry->data.fn.fn_type_id.is_extern) {
            ir_add_error(ira, fn_ref, buf_sprintf("unable to evaluate constant expression"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        if (!ir_emit_backward_branch(ira, &call_instruction->base))
            return ira->codegen->builtin_types.entry_invalid;

        // Fork a scope of the function with known values for the parameters.
        Scope *exec_scope = &fn_entry->fndef_scope->base;

        size_t next_proto_i = 0;
        if (first_arg_ptr) {
            IrInstruction *first_arg;
            assert(first_arg_ptr->value.type->id == TypeTableEntryIdPointer);
            if (handle_is_ptr(first_arg_ptr->value.type->data.pointer.child_type)) {
                first_arg = first_arg_ptr;
            } else {
                first_arg = ir_get_deref(ira, first_arg_ptr, first_arg_ptr);
                if (type_is_invalid(first_arg->value.type))
                    return ira->codegen->builtin_types.entry_invalid;
            }

            if (!ir_analyze_fn_call_inline_arg(ira, fn_proto_node, first_arg, &exec_scope, &next_proto_i))
                return ira->codegen->builtin_types.entry_invalid;
        }

        if (fn_proto_node->data.fn_proto.is_var_args) {
            ir_add_error(ira, &call_instruction->base,
                    buf_sprintf("compiler bug: unable to call var args function at compile time. https://github.com/andrewrk/zig/issues/313"));
            return ira->codegen->builtin_types.entry_invalid;
        }


        for (size_t call_i = 0; call_i < call_instruction->arg_count; call_i += 1) {
            IrInstruction *old_arg = call_instruction->args[call_i]->other;
            if (type_is_invalid(old_arg->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            if (!ir_analyze_fn_call_inline_arg(ira, fn_proto_node, old_arg, &exec_scope, &next_proto_i))
                return ira->codegen->builtin_types.entry_invalid;
        }

        AstNode *return_type_node = fn_proto_node->data.fn_proto.return_type;
        TypeTableEntry *return_type = analyze_type_expr(ira->codegen, exec_scope, return_type_node);
        if (type_is_invalid(return_type))
            return ira->codegen->builtin_types.entry_invalid;

        IrInstruction *result;

        auto entry = ira->codegen->memoized_fn_eval_table.maybe_get(exec_scope);
        if (entry) {
            result = entry->value;
        } else {
            // Analyze the fn body block like any other constant expression.
            AstNode *body_node = fn_entry->body_node;
            result = ir_eval_const_value(ira->codegen, exec_scope, body_node, return_type,
                ira->new_irb.exec->backward_branch_count, ira->new_irb.exec->backward_branch_quota, fn_entry,
                nullptr, call_instruction->base.source_node, nullptr, ira->new_irb.exec);
            if (type_is_invalid(result->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            ira->codegen->memoized_fn_eval_table.put(exec_scope, result);
        }

        ConstExprValue *out_val = ir_build_const_from(ira, &call_instruction->base);
        *out_val = result->value;
        return ir_finish_anal(ira, return_type);
    }

    if (fn_type->data.fn.is_generic) {
        assert(fn_entry);

        // Count the arguments of the function type id we are creating
        size_t new_fn_arg_count = first_arg_1_or_0;
        for (size_t call_i = 0; call_i < call_instruction->arg_count; call_i += 1) {
            IrInstruction *arg = call_instruction->args[call_i]->other;
            if (type_is_invalid(arg->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            if (arg->value.type->id == TypeTableEntryIdArgTuple) {
                new_fn_arg_count += arg->value.data.x_arg_tuple.end_index - arg->value.data.x_arg_tuple.start_index;
            } else {
                new_fn_arg_count += 1;
            }
        }

        IrInstruction **casted_args = allocate<IrInstruction *>(new_fn_arg_count);

        // Fork a scope of the function with known values for the parameters.
        Scope *parent_scope = fn_entry->fndef_scope->base.parent;
        FnTableEntry *impl_fn = create_fn(fn_proto_node);
        impl_fn->param_source_nodes = allocate<AstNode *>(new_fn_arg_count);
        buf_init_from_buf(&impl_fn->symbol_name, &fn_entry->symbol_name);
        impl_fn->fndef_scope = create_fndef_scope(impl_fn->body_node, parent_scope, impl_fn);
        impl_fn->child_scope = &impl_fn->fndef_scope->base;
        FnTypeId inst_fn_type_id = {0};
        init_fn_type_id(&inst_fn_type_id, fn_proto_node, new_fn_arg_count);
        inst_fn_type_id.param_count = 0;
        inst_fn_type_id.is_var_args = false;

        // TODO maybe GenericFnTypeId can be replaced with using the child_scope directly
        // as the key in generic_table
        GenericFnTypeId *generic_id = allocate<GenericFnTypeId>(1);
        generic_id->fn_entry = fn_entry;
        generic_id->param_count = 0;
        generic_id->params = allocate<ConstExprValue>(new_fn_arg_count);
        size_t next_proto_i = 0;

        if (first_arg_ptr) {
            IrInstruction *first_arg;
            assert(first_arg_ptr->value.type->id == TypeTableEntryIdPointer);
            if (handle_is_ptr(first_arg_ptr->value.type->data.pointer.child_type)) {
                first_arg = first_arg_ptr;
            } else {
                first_arg = ir_get_deref(ira, first_arg_ptr, first_arg_ptr);
                if (type_is_invalid(first_arg->value.type))
                    return ira->codegen->builtin_types.entry_invalid;
            }

            if (!ir_analyze_fn_call_generic_arg(ira, fn_proto_node, first_arg, &impl_fn->child_scope,
                &next_proto_i, generic_id, &inst_fn_type_id, casted_args, impl_fn))
            {
                return ira->codegen->builtin_types.entry_invalid;
            }
        }

        bool found_first_var_arg = false;
        size_t first_var_arg;

        FnTableEntry *parent_fn_entry = exec_fn_entry(ira->new_irb.exec);
        assert(parent_fn_entry);
        for (size_t call_i = 0; call_i < call_instruction->arg_count; call_i += 1) {
            IrInstruction *arg = call_instruction->args[call_i]->other;
            if (type_is_invalid(arg->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            AstNode *param_decl_node = fn_proto_node->data.fn_proto.params.at(next_proto_i);
            assert(param_decl_node->type == NodeTypeParamDecl);
            bool is_var_args = param_decl_node->data.param_decl.is_var_args;
            if (is_var_args && !found_first_var_arg) {
                first_var_arg = inst_fn_type_id.param_count;
                found_first_var_arg = true;
            }

            if (arg->value.type->id == TypeTableEntryIdArgTuple) {
                for (size_t arg_tuple_i = arg->value.data.x_arg_tuple.start_index;
                    arg_tuple_i < arg->value.data.x_arg_tuple.end_index; arg_tuple_i += 1)
                {
                    VariableTableEntry *arg_var = get_fn_var_by_index(parent_fn_entry, arg_tuple_i);
                    assert(arg_var != nullptr);
                    IrInstruction *arg_var_ptr_inst = ir_get_var_ptr(ira, arg, arg_var, true, false);
                    if (type_is_invalid(arg_var_ptr_inst->value.type))
                        return ira->codegen->builtin_types.entry_invalid;

                    IrInstruction *arg_tuple_arg = ir_get_deref(ira, arg, arg_var_ptr_inst);
                    if (type_is_invalid(arg_tuple_arg->value.type))
                        return ira->codegen->builtin_types.entry_invalid;

                    if (!ir_analyze_fn_call_generic_arg(ira, fn_proto_node, arg_tuple_arg, &impl_fn->child_scope,
                        &next_proto_i, generic_id, &inst_fn_type_id, casted_args, impl_fn))
                    {
                        return ira->codegen->builtin_types.entry_invalid;
                    }
                }
            } else if (!ir_analyze_fn_call_generic_arg(ira, fn_proto_node, arg, &impl_fn->child_scope,
                &next_proto_i, generic_id, &inst_fn_type_id, casted_args, impl_fn))
            {
                return ira->codegen->builtin_types.entry_invalid;
            }
        }

        if (fn_proto_node->data.fn_proto.is_var_args) {
            AstNode *param_decl_node = fn_proto_node->data.fn_proto.params.at(next_proto_i);
            Buf *param_name = param_decl_node->data.param_decl.name;

            if (!found_first_var_arg) {
                first_var_arg = inst_fn_type_id.param_count;
            }

            ConstExprValue *var_args_val = create_const_arg_tuple(ira->codegen,
                    first_var_arg, inst_fn_type_id.param_count);
            VariableTableEntry *var = add_variable(ira->codegen, param_decl_node,
                impl_fn->child_scope, param_name, true, var_args_val, nullptr);
            impl_fn->child_scope = var->child_scope;
        }
        {
            AstNode *return_type_node = fn_proto_node->data.fn_proto.return_type;
            TypeTableEntry *return_type = analyze_type_expr(ira->codegen, impl_fn->child_scope, return_type_node);
            if (type_is_invalid(return_type))
                return ira->codegen->builtin_types.entry_invalid;
            inst_fn_type_id.return_type = return_type;

            if (type_requires_comptime(return_type)) {
                // Throw out our work and call the function as if it were comptime.
                return ir_analyze_fn_call(ira, call_instruction, fn_entry, fn_type, fn_ref, first_arg_ptr, true, false);
            }
        }

        auto existing_entry = ira->codegen->generic_table.put_unique(generic_id, impl_fn);
        if (existing_entry) {
            // throw away all our work and use the existing function
            impl_fn = existing_entry->value;
        } else {
            // finish instantiating the function
            impl_fn->type_entry = get_fn_type(ira->codegen, &inst_fn_type_id);
            if (type_is_invalid(impl_fn->type_entry))
                return ira->codegen->builtin_types.entry_invalid;

            impl_fn->ir_executable.source_node = call_instruction->base.source_node;
            impl_fn->ir_executable.parent_exec = ira->new_irb.exec;
            impl_fn->analyzed_executable.source_node = call_instruction->base.source_node;
            impl_fn->analyzed_executable.parent_exec = ira->new_irb.exec;

            ira->codegen->fn_protos.append(impl_fn);
            ira->codegen->fn_defs.append(impl_fn);
        }

        size_t impl_param_count = impl_fn->type_entry->data.fn.fn_type_id.param_count;
        IrInstruction *new_call_instruction = ir_build_call_from(&ira->new_irb, &call_instruction->base,
                impl_fn, nullptr, impl_param_count, casted_args, false, inline_fn_call);

        TypeTableEntry *return_type = impl_fn->type_entry->data.fn.fn_type_id.return_type;
        ir_add_alloca(ira, new_call_instruction, return_type);

        return ir_finish_anal(ira, return_type);
    }

    IrInstruction **casted_args = allocate<IrInstruction *>(call_param_count);
    size_t next_arg_index = 0;
    if (first_arg_ptr) {
        IrInstruction *first_arg;
        assert(first_arg_ptr->value.type->id == TypeTableEntryIdPointer);
        if (handle_is_ptr(first_arg_ptr->value.type->data.pointer.child_type)) {
            first_arg = first_arg_ptr;
        } else {
            first_arg = ir_get_deref(ira, first_arg_ptr, first_arg_ptr);
            if (type_is_invalid(first_arg->value.type))
                return ira->codegen->builtin_types.entry_invalid;
        }

        TypeTableEntry *param_type = fn_type_id->param_info[next_arg_index].type;
        if (type_is_invalid(param_type))
            return ira->codegen->builtin_types.entry_invalid;

        IrInstruction *casted_arg = ir_implicit_cast(ira, first_arg, param_type);
        if (type_is_invalid(casted_arg->value.type))
            return ira->codegen->builtin_types.entry_invalid;

        casted_args[next_arg_index] = casted_arg;
        next_arg_index += 1;
    }
    for (size_t call_i = 0; call_i < call_instruction->arg_count; call_i += 1) {
        IrInstruction *old_arg = call_instruction->args[call_i]->other;
        if (type_is_invalid(old_arg->value.type))
            return ira->codegen->builtin_types.entry_invalid;
        IrInstruction *casted_arg;
        if (next_arg_index < src_param_count) {
            TypeTableEntry *param_type = fn_type_id->param_info[next_arg_index].type;
            if (type_is_invalid(param_type))
                return ira->codegen->builtin_types.entry_invalid;
            casted_arg = ir_implicit_cast(ira, old_arg, param_type);
            if (type_is_invalid(casted_arg->value.type))
                return ira->codegen->builtin_types.entry_invalid;
        } else {
            casted_arg = old_arg;
        }

        casted_args[next_arg_index] = casted_arg;
        next_arg_index += 1;
    }

    assert(next_arg_index == call_param_count);

    TypeTableEntry *return_type = fn_type_id->return_type;
    if (type_is_invalid(return_type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *new_call_instruction = ir_build_call_from(&ira->new_irb, &call_instruction->base,
            fn_entry, fn_ref, call_param_count, casted_args, false, inline_fn_call);

    ir_add_alloca(ira, new_call_instruction, return_type);
    return ir_finish_anal(ira, return_type);
}

static TypeTableEntry *ir_analyze_instruction_call(IrAnalyze *ira, IrInstructionCall *call_instruction) {
    IrInstruction *fn_ref = call_instruction->fn_ref->other;
    if (type_is_invalid(fn_ref->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    bool is_comptime = call_instruction->is_comptime ||
        ir_should_inline(ira->new_irb.exec, call_instruction->base.scope);

    if (is_comptime || instr_is_comptime(fn_ref)) {
        if (fn_ref->value.type->id == TypeTableEntryIdMetaType) {
            TypeTableEntry *dest_type = ir_resolve_type(ira, fn_ref);
            if (type_is_invalid(dest_type))
                return ira->codegen->builtin_types.entry_invalid;

            size_t actual_param_count = call_instruction->arg_count;

            if (actual_param_count != 1) {
                ir_add_error_node(ira, call_instruction->base.source_node,
                        buf_sprintf("cast expression expects exactly one parameter"));
                return ira->codegen->builtin_types.entry_invalid;
            }

            IrInstruction *arg = call_instruction->args[0]->other;

            IrInstruction *cast_instruction = ir_analyze_cast(ira, &call_instruction->base, dest_type, arg);
            if (type_is_invalid(cast_instruction->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            ir_link_new_instruction(cast_instruction, &call_instruction->base);
            return ir_finish_anal(ira, cast_instruction->value.type);
        } else if (fn_ref->value.type->id == TypeTableEntryIdFn) {
            bool is_inline;
            FnTableEntry *fn_table_entry = ir_resolve_fn(ira, fn_ref, &is_inline);
            return ir_analyze_fn_call(ira, call_instruction, fn_table_entry, fn_table_entry->type_entry,
                fn_ref, nullptr, is_comptime, is_inline);
        } else if (fn_ref->value.type->id == TypeTableEntryIdBoundFn) {
            assert(fn_ref->value.special == ConstValSpecialStatic);
            FnTableEntry *fn_table_entry = fn_ref->value.data.x_bound_fn.fn;
            IrInstruction *first_arg_ptr = fn_ref->value.data.x_bound_fn.first_arg;
            bool is_inline = fn_ref->value.data.x_bound_fn.is_inline;
            return ir_analyze_fn_call(ira, call_instruction, fn_table_entry, fn_table_entry->type_entry,
                nullptr, first_arg_ptr, is_comptime, is_inline);
        } else {
            ir_add_error_node(ira, fn_ref->source_node,
                buf_sprintf("type '%s' not a function", buf_ptr(&fn_ref->value.type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    }

    if (fn_ref->value.type->id == TypeTableEntryIdFn) {
        return ir_analyze_fn_call(ira, call_instruction, nullptr, fn_ref->value.type,
            fn_ref, nullptr, false, false);
    } else {
        ir_add_error_node(ira, fn_ref->source_node,
            buf_sprintf("type '%s' not a function", buf_ptr(&fn_ref->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_unary_prefix_op_err(IrAnalyze *ira, IrInstructionUnOp *un_op_instruction) {
    assert(un_op_instruction->op_id == IrUnOpError);
    IrInstruction *value = un_op_instruction->value->other;

    TypeTableEntry *meta_type = ir_resolve_type(ira, value);
    TypeTableEntry *underlying_meta_type = get_underlying_type(meta_type);

    if (type_is_invalid(underlying_meta_type))
        return ira->codegen->builtin_types.entry_invalid;


    switch (underlying_meta_type->id) {
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdInvalid: // handled above
            zig_unreachable();

        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdEnumTag:
            {
                ConstExprValue *out_val = ir_build_const_from(ira, &un_op_instruction->base);
                TypeTableEntry *result_type = get_error_type(ira->codegen, meta_type);
                out_val->data.x_type = result_type;
                return ira->codegen->builtin_types.entry_type;
            }
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdArgTuple:
            ir_add_error_node(ira, un_op_instruction->base.source_node,
                    buf_sprintf("unable to wrap type '%s' in error type", buf_ptr(&meta_type->name)));
            // TODO if meta_type is type decl, add note pointing to type decl declaration
            return ira->codegen->builtin_types.entry_invalid;
    }
    zig_unreachable();
}


static TypeTableEntry *ir_analyze_dereference(IrAnalyze *ira, IrInstructionUnOp *un_op_instruction) {
    IrInstruction *value = un_op_instruction->value->other;

    TypeTableEntry *ptr_type = value->value.type;
    TypeTableEntry *child_type;
    if (type_is_invalid(ptr_type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (ptr_type->id == TypeTableEntryIdPointer) {
        child_type = ptr_type->data.pointer.child_type;
    } else {
        ir_add_error_node(ira, un_op_instruction->base.source_node,
            buf_sprintf("attempt to dereference non-pointer type '%s'",
                buf_ptr(&ptr_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    // this dereference is always an rvalue because in the IR gen we identify lvalue and emit
    // one of the ptr instructions

    if (instr_is_comptime(value)) {
        ConstExprValue *pointee = const_ptr_pointee(&value->value);
        if (pointee->type == child_type) {
            ConstExprValue *out_val = ir_build_const_from(ira, &un_op_instruction->base);
            *out_val = *pointee;
            return child_type;
        }
    }

    ir_build_load_ptr_from(&ira->new_irb, &un_op_instruction->base, value);
    return child_type;
}

static TypeTableEntry *ir_analyze_maybe(IrAnalyze *ira, IrInstructionUnOp *un_op_instruction) {
    IrInstruction *value = un_op_instruction->value->other;
    TypeTableEntry *type_entry = ir_resolve_type(ira, value);
    TypeTableEntry *canon_type = get_underlying_type(type_entry);
    if (type_is_invalid(canon_type))
        return ira->codegen->builtin_types.entry_invalid;
    switch (canon_type->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdTypeDecl:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
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
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdEnumTag:
        case TypeTableEntryIdArgTuple:
            {
                ConstExprValue *out_val = ir_build_const_from(ira, &un_op_instruction->base);
                out_val->data.x_type = get_maybe_type(ira->codegen, type_entry);
                return ira->codegen->builtin_types.entry_type;
            }
        case TypeTableEntryIdUnreachable:
            ir_add_error_node(ira, un_op_instruction->base.source_node,
                    buf_sprintf("type '%s' not nullable", buf_ptr(&type_entry->name)));
            // TODO if it's a type decl, put an error note here pointing to the decl
            return ira->codegen->builtin_types.entry_invalid;
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_negation(IrAnalyze *ira, IrInstructionUnOp *un_op_instruction) {
    IrInstruction *value = un_op_instruction->value->other;
    TypeTableEntry *expr_type = value->value.type;
    if (type_is_invalid(expr_type))
        return ira->codegen->builtin_types.entry_invalid;

    bool is_wrap_op = (un_op_instruction->op_id == IrUnOpNegationWrap);

    if ((expr_type->id == TypeTableEntryIdInt && expr_type->data.integral.is_signed) ||
        expr_type->id == TypeTableEntryIdNumLitInt ||
        ((expr_type->id == TypeTableEntryIdFloat || expr_type->id == TypeTableEntryIdNumLitFloat) && !is_wrap_op))
    {
        if (instr_is_comptime(value)) {
            ConstExprValue *target_const_val = ir_resolve_const(ira, value, UndefBad);
            if (!target_const_val)
                return ira->codegen->builtin_types.entry_invalid;

            ConstExprValue *out_val = ir_build_const_from(ira, &un_op_instruction->base);
            bignum_negate(&out_val->data.x_bignum, &target_const_val->data.x_bignum);
            if (expr_type->id == TypeTableEntryIdFloat ||
                expr_type->id == TypeTableEntryIdNumLitFloat ||
                expr_type->id == TypeTableEntryIdNumLitInt)
            {
                return expr_type;
            }

            bool overflow = !bignum_fits_in_bits(&out_val->data.x_bignum, expr_type->data.integral.bit_count, true);
            if (is_wrap_op) {
                if (overflow)
                    out_val->data.x_bignum.is_negative = true;
            } else if (overflow) {
                ir_add_error(ira, &un_op_instruction->base, buf_sprintf("negation caused overflow"));
                return ira->codegen->builtin_types.entry_invalid;
            }
            return expr_type;
        }

        ir_build_un_op_from(&ira->new_irb, &un_op_instruction->base, un_op_instruction->op_id, value);
        return expr_type;
    }

    const char *fmt = is_wrap_op ? "invalid wrapping negation type: '%s'" : "invalid negation type: '%s'";
    ir_add_error(ira, &un_op_instruction->base, buf_sprintf(fmt, buf_ptr(&expr_type->name)));
    return ira->codegen->builtin_types.entry_invalid;
}

static TypeTableEntry *ir_analyze_bin_not(IrAnalyze *ira, IrInstructionUnOp *instruction) {
    IrInstruction *value = instruction->value->other;
    TypeTableEntry *expr_type = value->value.type;
    if (type_is_invalid(expr_type))
        return ira->codegen->builtin_types.entry_invalid;

    if (expr_type->id == TypeTableEntryIdInt) {
        if (instr_is_comptime(value)) {
            ConstExprValue *target_const_val = ir_resolve_const(ira, value, UndefBad);
            if (!target_const_val)
                return ira->codegen->builtin_types.entry_invalid;

            ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
            bignum_not(&out_val->data.x_bignum, &target_const_val->data.x_bignum,
                    expr_type->data.integral.bit_count, expr_type->data.integral.is_signed);
            return expr_type;
        }

        ir_build_un_op_from(&ira->new_irb, &instruction->base, IrUnOpBinNot, value);
        return expr_type;
    }

    ir_add_error(ira, &instruction->base,
            buf_sprintf("unable to perform binary not operation on type '%s'", buf_ptr(&expr_type->name)));
    return ira->codegen->builtin_types.entry_invalid;
}

static TypeTableEntry *ir_analyze_instruction_un_op(IrAnalyze *ira, IrInstructionUnOp *un_op_instruction) {
    IrUnOp op_id = un_op_instruction->op_id;
    switch (op_id) {
        case IrUnOpInvalid:
            zig_unreachable();
        case IrUnOpBinNot:
            return ir_analyze_bin_not(ira, un_op_instruction);
        case IrUnOpNegation:
        case IrUnOpNegationWrap:
            return ir_analyze_negation(ira, un_op_instruction);
        case IrUnOpDereference:
            return ir_analyze_dereference(ira, un_op_instruction);
        case IrUnOpMaybe:
            return ir_analyze_maybe(ira, un_op_instruction);
        case IrUnOpError:
            return ir_analyze_unary_prefix_op_err(ira, un_op_instruction);
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_br(IrAnalyze *ira, IrInstructionBr *br_instruction) {
    IrBasicBlock *old_dest_block = br_instruction->dest_block;

    bool is_comptime;
    if (!ir_resolve_comptime(ira, br_instruction->is_comptime->other, &is_comptime))
        return ir_unreach_error(ira);

    if (is_comptime || old_dest_block->ref_count == 1)
        return ir_inline_bb(ira, &br_instruction->base, old_dest_block);

    IrBasicBlock *new_bb = ir_get_new_bb(ira, old_dest_block, &br_instruction->base);

    if (new_bb->must_be_comptime_source_instr) {
        ErrorMsg *msg = ir_add_error(ira, &br_instruction->base,
            buf_sprintf("control flow attempts to use compile-time variable at runtime"));
        add_error_note(ira->codegen, msg, new_bb->must_be_comptime_source_instr->source_node,
                buf_sprintf("compile-time variable assigned here"));
        return ir_unreach_error(ira);
    }

    ir_build_br_from(&ira->new_irb, &br_instruction->base, new_bb);
    return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
}

static TypeTableEntry *ir_analyze_instruction_cond_br(IrAnalyze *ira, IrInstructionCondBr *cond_br_instruction) {
    IrInstruction *condition = cond_br_instruction->condition->other;
    if (type_is_invalid(condition->value.type))
        return ir_unreach_error(ira);

    bool is_comptime;
    if (!ir_resolve_comptime(ira, cond_br_instruction->is_comptime->other, &is_comptime))
        return ir_unreach_error(ira);

    if (is_comptime || instr_is_comptime(condition)) {
        bool cond_is_true;
        if (!ir_resolve_bool(ira, condition, &cond_is_true))
            return ir_unreach_error(ira);

        IrBasicBlock *old_dest_block = cond_is_true ?
            cond_br_instruction->then_block : cond_br_instruction->else_block;

        if (is_comptime || old_dest_block->ref_count == 1)
            return ir_inline_bb(ira, &cond_br_instruction->base, old_dest_block);

        IrBasicBlock *new_dest_block = ir_get_new_bb(ira, old_dest_block, &cond_br_instruction->base);
        ir_build_br_from(&ira->new_irb, &cond_br_instruction->base, new_dest_block);
        return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
    }

    TypeTableEntry *bool_type = ira->codegen->builtin_types.entry_bool;
    IrInstruction *casted_condition = ir_implicit_cast(ira, condition, bool_type);
    if (casted_condition == ira->codegen->invalid_instruction)
        return ir_unreach_error(ira);

    assert(cond_br_instruction->then_block != cond_br_instruction->else_block);
    IrBasicBlock *new_then_block = ir_get_new_bb(ira, cond_br_instruction->then_block, &cond_br_instruction->base);
    IrBasicBlock *new_else_block = ir_get_new_bb(ira, cond_br_instruction->else_block, &cond_br_instruction->base);
    ir_build_cond_br_from(&ira->new_irb, &cond_br_instruction->base,
            casted_condition, new_then_block, new_else_block, nullptr);
    return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
}

static TypeTableEntry *ir_analyze_instruction_unreachable(IrAnalyze *ira,
        IrInstructionUnreachable *unreachable_instruction)
{
    ir_build_unreachable_from(&ira->new_irb, &unreachable_instruction->base);
    return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
}

static TypeTableEntry *ir_analyze_instruction_phi(IrAnalyze *ira, IrInstructionPhi *phi_instruction) {
    if (ira->const_predecessor_bb) {
        for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
            IrBasicBlock *predecessor = phi_instruction->incoming_blocks[i];
            if (predecessor != ira->const_predecessor_bb)
                continue;
            IrInstruction *value = phi_instruction->incoming_values[i]->other;
            assert(value->value.type);
            if (type_is_invalid(value->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            if (value->value.special != ConstValSpecialRuntime) {
                ConstExprValue *out_val = ir_build_const_from(ira, &phi_instruction->base);
                *out_val = value->value;
            } else {
                phi_instruction->base.other = value;
            }
            return value->value.type;
        }
        zig_unreachable();
    }

    ZigList<IrBasicBlock*> new_incoming_blocks = {0};
    ZigList<IrInstruction*> new_incoming_values = {0};

    for (size_t i = 0; i < phi_instruction->incoming_count; i += 1) {
        IrBasicBlock *predecessor = phi_instruction->incoming_blocks[i];
        if (predecessor->ref_count == 0)
            continue;


        IrInstruction *old_value = phi_instruction->incoming_values[i];
        assert(old_value);
        IrInstruction *new_value = old_value->other;
        if (!new_value || new_value->value.type->id == TypeTableEntryIdUnreachable)
            continue;

        if (type_is_invalid(new_value->value.type))
            return ira->codegen->builtin_types.entry_invalid;


        assert(predecessor->other);
        new_incoming_blocks.append(predecessor->other);
        new_incoming_values.append(new_value);
    }

    if (new_incoming_blocks.length == 0) {
        ir_build_const_from(ira, &phi_instruction->base);
        return ira->codegen->builtin_types.entry_void;
    }

    if (new_incoming_blocks.length == 1) {
        IrInstruction *first_value = new_incoming_values.at(0);
        phi_instruction->base.other = first_value;
        return first_value->value.type;
    }

    TypeTableEntry *resolved_type = ir_resolve_peer_types(ira, phi_instruction->base.source_node,
            new_incoming_values.items, new_incoming_values.length);
    if (type_is_invalid(resolved_type))
        return resolved_type;

    if (resolved_type->id == TypeTableEntryIdNumLitFloat ||
        resolved_type->id == TypeTableEntryIdNumLitInt ||
        resolved_type->id == TypeTableEntryIdNullLit ||
        resolved_type->id == TypeTableEntryIdUndefLit)
    {
        ir_add_error_node(ira, phi_instruction->base.source_node,
                buf_sprintf("unable to infer expression type"));
        return ira->codegen->builtin_types.entry_invalid;
    }

    // cast all values to the resolved type. however we can't put cast instructions in front of the phi instruction.
    // so we go back and insert the casts as the last instruction in the corresponding predecessor blocks, and
    // then make sure the branch instruction is preserved.
    IrBasicBlock *cur_bb = ira->new_irb.current_basic_block;
    for (size_t i = 0; i < new_incoming_values.length; i += 1) {
        IrInstruction *new_value = new_incoming_values.at(i);
        IrBasicBlock *predecessor = new_incoming_blocks.at(i);
        IrInstruction *branch_instruction = predecessor->instruction_list.pop();
        ir_set_cursor_at_end(&ira->new_irb, predecessor);
        IrInstruction *casted_value = ir_implicit_cast(ira, new_value, resolved_type);
        new_incoming_values.items[i] = casted_value;
        predecessor->instruction_list.append(branch_instruction);
    }
    ir_set_cursor_at_end(&ira->new_irb, cur_bb);

    ir_build_phi_from(&ira->new_irb, &phi_instruction->base, new_incoming_blocks.length,
            new_incoming_blocks.items, new_incoming_values.items);

    return resolved_type;
}

static TypeTableEntry *ir_analyze_var_ptr(IrAnalyze *ira, IrInstruction *instruction,
        VariableTableEntry *var, bool is_const_ptr, bool is_volatile_ptr)
{
    IrInstruction *result = ir_get_var_ptr(ira, instruction, var, is_const_ptr, is_volatile_ptr);
    ir_link_new_instruction(result, instruction);
    return result->value.type;
}

static TypeTableEntry *ir_analyze_instruction_var_ptr(IrAnalyze *ira, IrInstructionVarPtr *var_ptr_instruction) {
    VariableTableEntry *var = var_ptr_instruction->var;
    return ir_analyze_var_ptr(ira, &var_ptr_instruction->base, var, var_ptr_instruction->is_const,
            var_ptr_instruction->is_volatile);
}

static TypeTableEntry *ir_analyze_instruction_elem_ptr(IrAnalyze *ira, IrInstructionElemPtr *elem_ptr_instruction) {
    IrInstruction *array_ptr = elem_ptr_instruction->array_ptr->other;
    if (type_is_invalid(array_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *elem_index = elem_ptr_instruction->elem_index->other;
    if (type_is_invalid(elem_index->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    // This will be a pointer type because elem ptr IR instruction operates on a pointer to a thing.
    TypeTableEntry *ptr_type = array_ptr->value.type;
    assert(ptr_type->id == TypeTableEntryIdPointer);

    TypeTableEntry *array_type = ptr_type->data.pointer.child_type;
    TypeTableEntry *return_type;

    if (type_is_invalid(array_type)) {
        return array_type;
    } else if (array_type->id == TypeTableEntryIdArray) {
        if (array_type->data.array.len == 0) {
            ir_add_error_node(ira, elem_ptr_instruction->base.source_node,
                    buf_sprintf("index 0 outside array of size 0"));
        }
        TypeTableEntry *child_type = array_type->data.array.child_type;
        if (ptr_type->data.pointer.unaligned_bit_count == 0) {
            return_type = get_pointer_to_type_extra(ira->codegen, child_type,
                    ptr_type->data.pointer.is_const, ptr_type->data.pointer.is_volatile, 0, 0);
        } else {
            ConstExprValue *elem_val = ir_resolve_const(ira, elem_index, UndefBad);
            if (!elem_val)
                return ira->codegen->builtin_types.entry_invalid;

            size_t bit_width = type_size_bits(ira->codegen, child_type);
            size_t bit_offset = bit_width * elem_val->data.x_bignum.data.x_uint;

            return_type = get_pointer_to_type_extra(ira->codegen, child_type,
                    ptr_type->data.pointer.is_const, ptr_type->data.pointer.is_volatile,
                    (uint32_t)bit_offset, (uint32_t)bit_width);
        }
    } else if (array_type->id == TypeTableEntryIdPointer) {
        return_type = array_type;
    } else if (is_slice(array_type)) {
        return_type = array_type->data.structure.fields[0].type_entry;
    } else if (array_type->id == TypeTableEntryIdArgTuple) {
        ConstExprValue *ptr_val = ir_resolve_const(ira, array_ptr, UndefBad);
        if (!ptr_val)
            return ira->codegen->builtin_types.entry_invalid;
        ConstExprValue *args_val = const_ptr_pointee(ptr_val);
        size_t start = args_val->data.x_arg_tuple.start_index;
        size_t end = args_val->data.x_arg_tuple.end_index;
        ConstExprValue *elem_index_val = ir_resolve_const(ira, elem_index, UndefBad);
        if (!elem_index_val)
            return ira->codegen->builtin_types.entry_invalid;
        size_t index = bignum_to_twos_complement(&elem_index_val->data.x_bignum);
        size_t len = end - start;
        if (index >= len) {
            ir_add_error(ira, &elem_ptr_instruction->base,
                buf_sprintf("index %zu outside argument list of size %zu", index, len));
            return ira->codegen->builtin_types.entry_invalid;
        }
        size_t abs_index = start + index;
        FnTableEntry *fn_entry = exec_fn_entry(ira->new_irb.exec);
        assert(fn_entry);
        VariableTableEntry *var = get_fn_var_by_index(fn_entry, abs_index);
        bool is_const = true;
        bool is_volatile = false;
        if (var) {
            return ir_analyze_var_ptr(ira, &elem_ptr_instruction->base, var,
                    is_const, is_volatile);
        } else {
            return ir_analyze_const_ptr(ira, &elem_ptr_instruction->base, &ira->codegen->const_void_val,
                    ira->codegen->builtin_types.entry_void, ConstPtrMutComptimeConst, is_const, is_volatile);
        }
    } else {
        ir_add_error_node(ira, elem_ptr_instruction->base.source_node,
                buf_sprintf("array access of non-array type '%s'", buf_ptr(&array_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    TypeTableEntry *usize = ira->codegen->builtin_types.entry_usize;
    IrInstruction *casted_elem_index = ir_implicit_cast(ira, elem_index, usize);
    if (casted_elem_index == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    bool safety_check_on = elem_ptr_instruction->safety_check_on;
    if (instr_is_comptime(casted_elem_index)) {
        uint64_t index = casted_elem_index->value.data.x_bignum.data.x_uint;
        if (array_type->id == TypeTableEntryIdArray) {
            uint64_t array_len = array_type->data.array.len;
            if (index >= array_len) {
                ir_add_error_node(ira, elem_ptr_instruction->base.source_node,
                    buf_sprintf("index %" PRIu64 " outside array of size %" PRIu64,
                            index, array_len));
                return ira->codegen->builtin_types.entry_invalid;
            }
            safety_check_on = false;
        }

        ConstExprValue *array_ptr_val;
        if (array_ptr->value.special != ConstValSpecialRuntime &&
            array_ptr->value.data.x_ptr.mut != ConstPtrMutRuntimeVar &&
            (array_ptr_val = const_ptr_pointee(&array_ptr->value)) &&
            array_ptr_val->special != ConstValSpecialRuntime &&
            (array_type->id != TypeTableEntryIdPointer ||
                array_ptr_val->data.x_ptr.special != ConstPtrSpecialHardCodedAddr))
        {
            ConstExprValue *out_val = ir_build_const_from(ira, &elem_ptr_instruction->base);
            if (array_type->id == TypeTableEntryIdPointer) {
                out_val->data.x_ptr.mut = array_ptr_val->data.x_ptr.mut;
                size_t new_index;
                size_t mem_size;
                size_t old_size;
                switch (array_ptr_val->data.x_ptr.special) {
                    case ConstPtrSpecialInvalid:
                    case ConstPtrSpecialDiscard:
                        zig_unreachable();
                    case ConstPtrSpecialRef:
                        mem_size = 1;
                        old_size = 1;
                        new_index = index;

                        out_val->data.x_ptr.special = ConstPtrSpecialRef;
                        out_val->data.x_ptr.data.ref.pointee = array_ptr_val->data.x_ptr.data.ref.pointee;
                        break;
                    case ConstPtrSpecialBaseArray:
                        {
                            size_t offset = array_ptr_val->data.x_ptr.data.base_array.elem_index;
                            new_index = offset + index;
                            mem_size = array_ptr_val->data.x_ptr.data.base_array.array_val->type->data.array.len;
                            old_size = mem_size - offset;

                            assert(array_ptr_val->data.x_ptr.data.base_array.array_val);

                            out_val->data.x_ptr.special = ConstPtrSpecialBaseArray;
                            out_val->data.x_ptr.data.base_array.array_val =
                                array_ptr_val->data.x_ptr.data.base_array.array_val;
                            out_val->data.x_ptr.data.base_array.elem_index = new_index;
                            out_val->data.x_ptr.data.base_array.is_cstr =
                                array_ptr_val->data.x_ptr.data.base_array.is_cstr;

                            break;
                        }
                    case ConstPtrSpecialBaseStruct:
                        zig_panic("TODO elem ptr on a const inner struct");
                    case ConstPtrSpecialHardCodedAddr:
                        zig_unreachable();
                }
                if (new_index >= mem_size) {
                    ir_add_error_node(ira, elem_ptr_instruction->base.source_node,
                        buf_sprintf("index %" PRIu64 " outside pointer of size %zu", index, old_size));
                    return ira->codegen->builtin_types.entry_invalid;
                }
            } else if (is_slice(array_type)) {
                ConstExprValue *ptr_field = &array_ptr_val->data.x_struct.fields[slice_ptr_index];
                ConstExprValue *len_field = &array_ptr_val->data.x_struct.fields[slice_len_index];
                uint64_t slice_len = len_field->data.x_bignum.data.x_uint;
                if (index >= slice_len) {
                    ir_add_error_node(ira, elem_ptr_instruction->base.source_node,
                        buf_sprintf("index %" PRIu64 " outside slice of size %" PRIu64,
                            index, slice_len));
                    return ira->codegen->builtin_types.entry_invalid;
                }
                out_val->data.x_ptr.mut = ptr_field->data.x_ptr.mut;
                switch (ptr_field->data.x_ptr.special) {
                    case ConstPtrSpecialInvalid:
                    case ConstPtrSpecialDiscard:
                        zig_unreachable();
                    case ConstPtrSpecialRef:
                        out_val->data.x_ptr.special = ConstPtrSpecialRef;
                        out_val->data.x_ptr.data.ref.pointee = ptr_field->data.x_ptr.data.ref.pointee;
                        break;
                    case ConstPtrSpecialBaseArray:
                        {
                            size_t offset = ptr_field->data.x_ptr.data.base_array.elem_index;
                            uint64_t new_index = offset + index;
                            assert(new_index < ptr_field->data.x_ptr.data.base_array.array_val->type->data.array.len);
                            out_val->data.x_ptr.special = ConstPtrSpecialBaseArray;
                            out_val->data.x_ptr.data.base_array.array_val =
                                ptr_field->data.x_ptr.data.base_array.array_val;
                            out_val->data.x_ptr.data.base_array.elem_index = new_index;
                            out_val->data.x_ptr.data.base_array.is_cstr =
                                ptr_field->data.x_ptr.data.base_array.is_cstr;
                            break;
                        }
                    case ConstPtrSpecialBaseStruct:
                        zig_panic("TODO elem ptr on a slice backed by const inner struct");
                    case ConstPtrSpecialHardCodedAddr:
                        zig_unreachable();
                }
            } else if (array_type->id == TypeTableEntryIdArray) {
                out_val->data.x_ptr.special = ConstPtrSpecialBaseArray;
                out_val->data.x_ptr.mut = array_ptr->value.data.x_ptr.mut;
                out_val->data.x_ptr.data.base_array.array_val = array_ptr_val;
                out_val->data.x_ptr.data.base_array.elem_index = index;
            } else {
                zig_unreachable();
            }
            return return_type;
        }

    }

    ir_build_elem_ptr_from(&ira->new_irb, &elem_ptr_instruction->base, array_ptr,
            casted_elem_index, safety_check_on);
    return return_type;
}

static TypeTableEntry *ir_analyze_container_member_access_inner(IrAnalyze *ira,
    TypeTableEntry *bare_struct_type, Buf *field_name, IrInstructionFieldPtr *field_ptr_instruction,
    IrInstruction *container_ptr, TypeTableEntry *container_type)
{
    if (!is_slice(bare_struct_type)) {
        ScopeDecls *container_scope = get_container_scope(bare_struct_type);
        auto entry = container_scope->decl_table.maybe_get(field_name);
        Tld *tld = entry ? entry->value : nullptr;
        if (tld && tld->id == TldIdFn) {
            resolve_top_level_decl(ira->codegen, tld, false);
            if (tld->resolution == TldResolutionInvalid)
                return ira->codegen->builtin_types.entry_invalid;
            TldFn *tld_fn = (TldFn *)tld;
            FnTableEntry *fn_entry = tld_fn->fn_entry;
            if (type_is_invalid(fn_entry->type_entry))
                return ira->codegen->builtin_types.entry_invalid;

            IrInstruction *bound_fn_value = ir_build_const_bound_fn(&ira->new_irb, field_ptr_instruction->base.scope,
                field_ptr_instruction->base.source_node, fn_entry, container_ptr);
            return ir_analyze_ref(ira, &field_ptr_instruction->base, bound_fn_value, true, false);
        }
    }
    ir_add_error_node(ira, field_ptr_instruction->base.source_node,
        buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name), buf_ptr(&bare_struct_type->name)));
    return ira->codegen->builtin_types.entry_invalid;
}


static TypeTableEntry *ir_analyze_container_field_ptr(IrAnalyze *ira, Buf *field_name,
    IrInstructionFieldPtr *field_ptr_instruction, IrInstruction *container_ptr, TypeTableEntry *container_type)
{
    TypeTableEntry *bare_type = container_ref_type(container_type);
    ensure_complete_type(ira->codegen, bare_type);

    assert(container_ptr->value.type->id == TypeTableEntryIdPointer);
    bool is_const = container_ptr->value.type->data.pointer.is_const;
    bool is_volatile = container_ptr->value.type->data.pointer.is_volatile;
    if (bare_type->id == TypeTableEntryIdStruct) {
        if (bare_type->data.structure.is_invalid)
            return ira->codegen->builtin_types.entry_invalid;

        TypeStructField *field = find_struct_type_field(bare_type, field_name);
        if (field) {
            if (instr_is_comptime(container_ptr)) {
                ConstExprValue *ptr_val = ir_resolve_const(ira, container_ptr, UndefBad);
                if (!ptr_val)
                    return ira->codegen->builtin_types.entry_invalid;

                if (ptr_val->data.x_ptr.special != ConstPtrSpecialHardCodedAddr) {
                    ConstExprValue *struct_val = const_ptr_pointee(ptr_val);
                    ConstExprValue *field_val = &struct_val->data.x_struct.fields[field->src_index];
                    TypeTableEntry *ptr_type = get_pointer_to_type_extra(ira->codegen, field_val->type,
                            is_const, is_volatile, 0, 0);
                    ConstExprValue *const_val = ir_build_const_from(ira, &field_ptr_instruction->base);
                    const_val->data.x_ptr.special = ConstPtrSpecialBaseStruct;
                    const_val->data.x_ptr.mut = container_ptr->value.data.x_ptr.mut;
                    const_val->data.x_ptr.data.base_struct.struct_val = struct_val;
                    const_val->data.x_ptr.data.base_struct.field_index = field->src_index;
                    return ptr_type;
                }
            }
            size_t ptr_bit_offset = container_ptr->value.type->data.pointer.bit_offset;
            size_t ptr_unaligned_bit_count = container_ptr->value.type->data.pointer.unaligned_bit_count;
            size_t unaligned_bit_count_for_result_type = (ptr_unaligned_bit_count == 0) ?
                field->unaligned_bit_count : type_size_bits(ira->codegen, field->type_entry);
            ir_build_struct_field_ptr_from(&ira->new_irb, &field_ptr_instruction->base, container_ptr, field);
            return get_pointer_to_type_extra(ira->codegen, field->type_entry, is_const, is_volatile,
                    (uint32_t)(ptr_bit_offset + field->packed_bits_offset),
                    (uint32_t)unaligned_bit_count_for_result_type);
        } else {
            return ir_analyze_container_member_access_inner(ira, bare_type, field_name,
                field_ptr_instruction, container_ptr, container_type);
        }
    } else if (bare_type->id == TypeTableEntryIdEnum) {
        if (bare_type->data.enumeration.is_invalid)
            return ira->codegen->builtin_types.entry_invalid;

        TypeEnumField *field = find_enum_type_field(bare_type, field_name);
        if (field) {
            ir_build_enum_field_ptr_from(&ira->new_irb, &field_ptr_instruction->base, container_ptr, field);
            return get_pointer_to_type_extra(ira->codegen, field->type_entry, is_const, is_volatile, 0, 0);
        } else {
            return ir_analyze_container_member_access_inner(ira, bare_type, field_name,
                field_ptr_instruction, container_ptr, container_type);
        }
    } else if (bare_type->id == TypeTableEntryIdUnion) {
        zig_panic("TODO");
    } else {
        zig_unreachable();
    }
}

static TypeTableEntry *ir_analyze_decl_ref(IrAnalyze *ira, IrInstruction *source_instruction, Tld *tld) {
    bool pointer_only = false;
    resolve_top_level_decl(ira->codegen, tld, pointer_only);
    if (tld->resolution == TldResolutionInvalid)
        return ira->codegen->builtin_types.entry_invalid;

    switch (tld->id) {
        case TldIdContainer:
        case TldIdCompTime:
            zig_unreachable();
        case TldIdVar:
        {
            TldVar *tld_var = (TldVar *)tld;
            VariableTableEntry *var = tld_var->var;
            return ir_analyze_var_ptr(ira, source_instruction, var, false, false);
        }
        case TldIdFn:
        {
            TldFn *tld_fn = (TldFn *)tld;
            FnTableEntry *fn_entry = tld_fn->fn_entry;
            assert(fn_entry->type_entry);

            if (type_is_invalid(fn_entry->type_entry))
                return ira->codegen->builtin_types.entry_invalid;

            // TODO instead of allocating this every time, put it in the tld value and we can reference
            // the same one every time
            ConstExprValue *const_val = allocate<ConstExprValue>(1);
            const_val->special = ConstValSpecialStatic;
            const_val->type = fn_entry->type_entry;
            const_val->data.x_fn.fn_entry = fn_entry;

            bool ptr_is_const = true;
            bool ptr_is_volatile = false;
            return ir_analyze_const_ptr(ira, source_instruction, const_val, fn_entry->type_entry,
                    ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
        }
        case TldIdTypeDef:
        {
            TldTypeDef *tld_typedef = (TldTypeDef *)tld;
            assert(tld_typedef->type_entry);

            // TODO instead of allocating this every time, put it in the tld value and we can reference
            // the same one every time
            ConstExprValue *const_val = allocate<ConstExprValue>(1);
            const_val->special = ConstValSpecialStatic;
            const_val->type = ira->codegen->builtin_types.entry_type;
            const_val->data.x_type = tld_typedef->type_entry;

            bool ptr_is_const = true;
            bool ptr_is_volatile = false;
            return ir_analyze_const_ptr(ira, source_instruction, const_val, ira->codegen->builtin_types.entry_type,
                    ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
        }
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_field_ptr(IrAnalyze *ira, IrInstructionFieldPtr *field_ptr_instruction) {
    IrInstruction *container_ptr = field_ptr_instruction->container_ptr->other;
    if (type_is_invalid(container_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *container_type;
    if (container_ptr->value.type->id == TypeTableEntryIdPointer) {
        container_type = container_ptr->value.type->data.pointer.child_type;
    } else if (container_ptr->value.type->id == TypeTableEntryIdMetaType) {
        container_type = container_ptr->value.type;
    } else {
        zig_unreachable();
    }

    Buf *field_name = field_ptr_instruction->field_name;
    AstNode *source_node = field_ptr_instruction->base.source_node;

    if (type_is_invalid(container_type)) {
        return container_type;
    } else if (is_container_ref(container_type)) {
        assert(container_ptr->value.type->id == TypeTableEntryIdPointer);
        if (container_type->id == TypeTableEntryIdPointer) {
            TypeTableEntry *bare_type = container_ref_type(container_type);
            IrInstruction *container_child = ir_get_deref(ira, &field_ptr_instruction->base, container_ptr);
            return ir_analyze_container_field_ptr(ira, field_name, field_ptr_instruction, container_child, bare_type);
        } else {
            return ir_analyze_container_field_ptr(ira, field_name, field_ptr_instruction, container_ptr, container_type);
        }
    } else if (container_type->id == TypeTableEntryIdArray) {
        if (buf_eql_str(field_name, "len")) {
            ConstExprValue *len_val = allocate<ConstExprValue>(1);
            init_const_usize(ira->codegen, len_val, container_type->data.array.len);

            TypeTableEntry *usize = ira->codegen->builtin_types.entry_usize;
            bool ptr_is_const = true;
            bool ptr_is_volatile = false;
            return ir_analyze_const_ptr(ira, &field_ptr_instruction->base, len_val,
                    usize, ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
        } else {
            ir_add_error_node(ira, source_node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name),
                    buf_ptr(&container_type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    } else if (container_type->id == TypeTableEntryIdArgTuple) {
        ConstExprValue *container_ptr_val = ir_resolve_const(ira, container_ptr, UndefBad);
        if (!container_ptr_val)
            return ira->codegen->builtin_types.entry_invalid;

        assert(container_ptr->value.type->id == TypeTableEntryIdPointer);
        ConstExprValue *child_val = const_ptr_pointee(container_ptr_val);

        if (buf_eql_str(field_name, "len")) {
            ConstExprValue *len_val = allocate<ConstExprValue>(1);
            size_t len = child_val->data.x_arg_tuple.end_index - child_val->data.x_arg_tuple.start_index;
            init_const_usize(ira->codegen, len_val, len);

            TypeTableEntry *usize = ira->codegen->builtin_types.entry_usize;
            bool ptr_is_const = true;
            bool ptr_is_volatile = false;
            return ir_analyze_const_ptr(ira, &field_ptr_instruction->base, len_val,
                    usize, ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
        } else {
            ir_add_error_node(ira, source_node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name),
                    buf_ptr(&container_type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    } else if (container_type->id == TypeTableEntryIdMetaType) {
        ConstExprValue *container_ptr_val = ir_resolve_const(ira, container_ptr, UndefBad);
        if (!container_ptr_val)
            return ira->codegen->builtin_types.entry_invalid;

        TypeTableEntry *child_type;
        if (container_ptr->value.type->id == TypeTableEntryIdMetaType) {
            TypeTableEntry *ptr_type = container_ptr_val->data.x_type;
            assert(ptr_type->id == TypeTableEntryIdPointer);
            child_type = ptr_type->data.pointer.child_type;
        } else if (container_ptr->value.type->id == TypeTableEntryIdPointer) {
            ConstExprValue *child_val = const_ptr_pointee(container_ptr_val);
            child_type = child_val->data.x_type;
        } else {
            zig_unreachable();
        }

        if (type_is_invalid(child_type)) {
            return ira->codegen->builtin_types.entry_invalid;
        } else if (is_container(child_type)) {
            if (child_type->id == TypeTableEntryIdEnum) {
                ensure_complete_type(ira->codegen, child_type);
                if (child_type->data.enumeration.is_invalid)
                    return ira->codegen->builtin_types.entry_invalid;

                TypeEnumField *field = find_enum_type_field(child_type, field_name);
                if (field) {
                    if (field->type_entry->id == TypeTableEntryIdVoid) {
                        bool ptr_is_const = true;
                        bool ptr_is_volatile = false;
                        return ir_analyze_const_ptr(ira, &field_ptr_instruction->base,
                                create_const_enum_tag(child_type, field->value), child_type,
                                ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
                    } else {
                        bool ptr_is_const = true;
                        bool ptr_is_volatile = false;
                        return ir_analyze_const_ptr(ira, &field_ptr_instruction->base,
                            create_const_unsigned_negative(child_type->data.enumeration.tag_type, field->value, false),
                            child_type->data.enumeration.tag_type,
                            ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
                    }
                }
            }
            ScopeDecls *container_scope = get_container_scope(child_type);
            if (container_scope != nullptr) {
                auto entry = container_scope->decl_table.maybe_get(field_name);
                Tld *tld = entry ? entry->value : nullptr;
                if (tld) {
                    return ir_analyze_decl_ref(ira, &field_ptr_instruction->base, tld);
                }
            }
            ir_add_error(ira, &field_ptr_instruction->base,
                buf_sprintf("container '%s' has no member called '%s'",
                    buf_ptr(&child_type->name), buf_ptr(field_name)));
            return ira->codegen->builtin_types.entry_invalid;
        } else if (child_type->id == TypeTableEntryIdPureError) {
            auto err_table_entry = ira->codegen->error_table.maybe_get(field_name);
            if (err_table_entry) {
                ConstExprValue *const_val = allocate<ConstExprValue>(1);
                const_val->special = ConstValSpecialStatic;
                const_val->type = child_type;
                const_val->data.x_pure_err = err_table_entry->value;

                bool ptr_is_const = true;
                bool ptr_is_volatile = false;
                return ir_analyze_const_ptr(ira, &field_ptr_instruction->base, const_val,
                        child_type, ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
            }

            ir_add_error(ira, &field_ptr_instruction->base,
                buf_sprintf("use of undeclared error value '%s'", buf_ptr(field_name)));
            return ira->codegen->builtin_types.entry_invalid;
        } else if (child_type->id == TypeTableEntryIdInt) {
            if (buf_eql_str(field_name, "bit_count")) {
                bool ptr_is_const = true;
                bool ptr_is_volatile = false;
                return ir_analyze_const_ptr(ira, &field_ptr_instruction->base,
                    create_const_unsigned_negative(ira->codegen->builtin_types.entry_num_lit_int,
                        child_type->data.integral.bit_count, false),
                    ira->codegen->builtin_types.entry_num_lit_int,
                    ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
            } else if (buf_eql_str(field_name, "is_signed")) {
                bool ptr_is_const = true;
                bool ptr_is_volatile = false;
                return ir_analyze_const_ptr(ira, &field_ptr_instruction->base,
                    create_const_bool(ira->codegen, child_type->data.integral.is_signed),
                    ira->codegen->builtin_types.entry_bool,
                    ConstPtrMutComptimeConst, ptr_is_const, ptr_is_volatile);
            } else {
                ir_add_error(ira, &field_ptr_instruction->base,
                    buf_sprintf("type '%s' has no member called '%s'",
                        buf_ptr(&child_type->name), buf_ptr(field_name)));
                return ira->codegen->builtin_types.entry_invalid;
            }
        } else {
            ir_add_error(ira, &field_ptr_instruction->base,
                buf_sprintf("type '%s' does not support field access", buf_ptr(&child_type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    } else if (container_type->id == TypeTableEntryIdNamespace) {
        assert(container_ptr->value.type->id == TypeTableEntryIdPointer);
        ConstExprValue *container_ptr_val = ir_resolve_const(ira, container_ptr, UndefBad);
        if (!container_ptr_val)
            return ira->codegen->builtin_types.entry_invalid;

        ConstExprValue *namespace_val = const_ptr_pointee(container_ptr_val);
        assert(namespace_val->special == ConstValSpecialStatic);

        ImportTableEntry *namespace_import = namespace_val->data.x_import;

        Tld *tld = find_decl(ira->codegen, &namespace_import->decls_scope->base, field_name);
        if (tld) {
            if (tld->visib_mod == VisibModPrivate &&
                tld->import != source_node->owner)
            {
                ErrorMsg *msg = ir_add_error_node(ira, source_node,
                    buf_sprintf("'%s' is private", buf_ptr(field_name)));
                add_error_note(ira->codegen, msg, tld->source_node, buf_sprintf("declared here"));
                return ira->codegen->builtin_types.entry_invalid;
            }
            return ir_analyze_decl_ref(ira, &field_ptr_instruction->base, tld);
        } else {
            const char *import_name = namespace_import->path ? buf_ptr(namespace_import->path) : "(C import)";
            ir_add_error_node(ira, source_node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name), import_name));
            return ira->codegen->builtin_types.entry_invalid;
        }
    } else {
        ir_add_error_node(ira, field_ptr_instruction->base.source_node,
            buf_sprintf("type '%s' does not support field access", buf_ptr(&container_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_instruction_load_ptr(IrAnalyze *ira, IrInstructionLoadPtr *load_ptr_instruction) {
    IrInstruction *ptr = load_ptr_instruction->ptr->other;
    IrInstruction *result = ir_get_deref(ira, &load_ptr_instruction->base, ptr);
    ir_link_new_instruction(result, &load_ptr_instruction->base);
    assert(result->value.type);
    return result->value.type;
}

static TypeTableEntry *ir_analyze_instruction_store_ptr(IrAnalyze *ira, IrInstructionStorePtr *store_ptr_instruction) {
    IrInstruction *ptr = store_ptr_instruction->ptr->other;
    if (type_is_invalid(ptr->value.type))
        return ptr->value.type;

    IrInstruction *value = store_ptr_instruction->value->other;
    if (type_is_invalid(value->value.type))
        return value->value.type;

    if (ptr->value.type->id != TypeTableEntryIdPointer) {
        ir_add_error(ira, ptr,
            buf_sprintf("attempt to dereference non pointer type '%s'", buf_ptr(&ptr->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (ptr->value.data.x_ptr.special == ConstPtrSpecialDiscard) {
        return ir_analyze_void(ira, &store_ptr_instruction->base);
    }

    if (ptr->value.type->data.pointer.is_const && !store_ptr_instruction->base.is_gen) {
        ir_add_error(ira, &store_ptr_instruction->base, buf_sprintf("cannot assign to constant"));
        return ira->codegen->builtin_types.entry_invalid;
    }

    TypeTableEntry *child_type = ptr->value.type->data.pointer.child_type;
    IrInstruction *casted_value = ir_implicit_cast(ira, value, child_type);
    if (casted_value == ira->codegen->invalid_instruction)
        return ira->codegen->builtin_types.entry_invalid;

    if (instr_is_comptime(ptr) && ptr->value.data.x_ptr.special != ConstPtrSpecialHardCodedAddr) {
        if (ptr->value.data.x_ptr.mut == ConstPtrMutComptimeConst) {
            ir_add_error(ira, &store_ptr_instruction->base, buf_sprintf("cannot assign to constant"));
            return ira->codegen->builtin_types.entry_invalid;
        }
        if (ptr->value.data.x_ptr.mut == ConstPtrMutComptimeVar) {
            if (instr_is_comptime(casted_value)) {
                ConstExprValue *dest_val = const_ptr_pointee(&ptr->value);
                if (dest_val->special != ConstValSpecialRuntime) {
                    *dest_val = casted_value->value;
                    if (!ira->new_irb.current_basic_block->must_be_comptime_source_instr) {
                        ira->new_irb.current_basic_block->must_be_comptime_source_instr = &store_ptr_instruction->base;
                    }
                    return ir_analyze_void(ira, &store_ptr_instruction->base);
                }
            }
            ir_add_error(ira, &store_ptr_instruction->base,
                    buf_sprintf("cannot store runtime value in compile time variable"));
            return ira->codegen->builtin_types.entry_invalid;
        }
    }

    ir_build_store_ptr_from(&ira->new_irb, &store_ptr_instruction->base, ptr, casted_value);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_typeof(IrAnalyze *ira, IrInstructionTypeOf *typeof_instruction) {
    IrInstruction *expr_value = typeof_instruction->value->other;
    TypeTableEntry *type_entry = expr_value->value.type;
    if (type_is_invalid(type_entry))
        return ira->codegen->builtin_types.entry_invalid;
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable(); // handled above
        case TypeTableEntryIdVar:
            ir_add_error_node(ira, expr_value->source_node,
                    buf_sprintf("type '%s' not eligible for @typeOf", buf_ptr(&type_entry->name)));
            return ira->codegen->builtin_types.entry_invalid;
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdEnumTag:
        case TypeTableEntryIdArgTuple:
            {
                ConstExprValue *out_val = ir_build_const_from(ira, &typeof_instruction->base);
                out_val->data.x_type = type_entry;

                return ira->codegen->builtin_types.entry_type;
            }
    }

    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_to_ptr_type(IrAnalyze *ira,
        IrInstructionToPtrType *to_ptr_type_instruction)
{
    IrInstruction *value = to_ptr_type_instruction->value->other;
    TypeTableEntry *type_entry = value->value.type;
    if (type_is_invalid(type_entry))
        return type_entry;

    TypeTableEntry *ptr_type;
    if (type_entry->id == TypeTableEntryIdArray) {
        ptr_type = get_pointer_to_type(ira->codegen, type_entry->data.array.child_type, false);
    } else if (is_slice(type_entry)) {
        ptr_type = type_entry->data.structure.fields[0].type_entry;
    } else if (type_entry->id == TypeTableEntryIdArgTuple) {
        ConstExprValue *arg_tuple_val = ir_resolve_const(ira, value, UndefBad);
        if (!arg_tuple_val)
            return ira->codegen->builtin_types.entry_invalid;
        zig_panic("TODO for loop on var args");
    } else {
        ir_add_error_node(ira, to_ptr_type_instruction->base.source_node,
                buf_sprintf("expected array type, found '%s'", buf_ptr(&type_entry->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    ConstExprValue *out_val = ir_build_const_from(ira, &to_ptr_type_instruction->base);
    out_val->data.x_type = ptr_type;
    return ira->codegen->builtin_types.entry_type;
}

static TypeTableEntry *ir_analyze_instruction_ptr_type_child(IrAnalyze *ira,
        IrInstructionPtrTypeChild *ptr_type_child_instruction)
{
    IrInstruction *type_value = ptr_type_child_instruction->value->other;
    TypeTableEntry *type_entry = ir_resolve_type(ira, type_value);
    if (type_is_invalid(type_entry))
        return type_entry;

    // TODO handle typedefs
    if (type_entry->id != TypeTableEntryIdPointer) {
        ir_add_error_node(ira, ptr_type_child_instruction->base.source_node,
                buf_sprintf("expected pointer type, found '%s'", buf_ptr(&type_entry->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    ConstExprValue *out_val = ir_build_const_from(ira, &ptr_type_child_instruction->base);
    out_val->data.x_type = type_entry->data.pointer.child_type;
    return ira->codegen->builtin_types.entry_type;
}

static TypeTableEntry *ir_analyze_instruction_set_global_align(IrAnalyze *ira,
        IrInstructionSetGlobalAlign *instruction)
{
    Tld *tld = instruction->tld;
    IrInstruction *align_value = instruction->value->other;

    uint64_t scalar_align;
    if (!ir_resolve_usize(ira, align_value, &scalar_align))
        return ira->codegen->builtin_types.entry_invalid;

    if (!is_power_of_2(scalar_align)) {
        ir_add_error(ira, instruction->value, buf_sprintf("alignment value must be power of 2"));
        return ira->codegen->builtin_types.entry_invalid;
    }

    AstNode **set_global_align_node;
    uint32_t *alignment_ptr;
    if (tld->id == TldIdVar) {
        TldVar *tld_var = (TldVar *)tld;
        set_global_align_node = &tld_var->set_global_align_node;
        alignment_ptr = &tld_var->alignment;
    } else if (tld->id == TldIdFn) {
        TldFn *tld_fn = (TldFn *)tld;
        FnTableEntry *fn_entry = tld_fn->fn_entry;
        set_global_align_node = &fn_entry->set_global_align_node;
        alignment_ptr = &fn_entry->alignment;
    } else {
        // error is caught in pass1 IR gen
        zig_unreachable();
    }

    AstNode *source_node = instruction->base.source_node;
    if (*set_global_align_node) {
        ErrorMsg *msg = ir_add_error_node(ira, source_node,
                buf_sprintf("alignment set twice"));
        add_error_note(ira->codegen, msg, *set_global_align_node, buf_sprintf("first set here"));
        return ira->codegen->builtin_types.entry_invalid;
    }
    *set_global_align_node = source_node;
    *alignment_ptr = (uint32_t)scalar_align;

    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_set_global_section(IrAnalyze *ira,
        IrInstructionSetGlobalSection *instruction)
{
    Tld *tld = instruction->tld;
    IrInstruction *section_value = instruction->value->other;

    Buf *section_name = ir_resolve_str(ira, section_value);
    if (!section_name)
        return ira->codegen->builtin_types.entry_invalid;

    AstNode **set_global_section_node;
    Buf **section_name_ptr;
    if (tld->id == TldIdVar) {
        TldVar *tld_var = (TldVar *)tld;
        set_global_section_node = &tld_var->set_global_section_node;
        section_name_ptr = &tld_var->section_name;
    } else if (tld->id == TldIdFn) {
        TldFn *tld_fn = (TldFn *)tld;
        FnTableEntry *fn_entry = tld_fn->fn_entry;
        set_global_section_node = &fn_entry->set_global_section_node;
        section_name_ptr = &fn_entry->section_name;
    } else {
        // error is caught in pass1 IR gen
        zig_unreachable();
    }

    AstNode *source_node = instruction->base.source_node;
    if (*set_global_section_node) {
        ErrorMsg *msg = ir_add_error_node(ira, source_node, buf_sprintf("section set twice"));
        add_error_note(ira->codegen, msg, *set_global_section_node, buf_sprintf("first set here"));
        return ira->codegen->builtin_types.entry_invalid;
    }
    *set_global_section_node = source_node;
    *section_name_ptr = section_name;

    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_set_global_linkage(IrAnalyze *ira,
        IrInstructionSetGlobalLinkage *instruction)
{
    Tld *tld = instruction->tld;
    IrInstruction *linkage_value = instruction->value->other;

    GlobalLinkageId linkage_scalar;
    if (!ir_resolve_global_linkage(ira, linkage_value, &linkage_scalar))
        return ira->codegen->builtin_types.entry_invalid;

    AstNode **set_global_linkage_node;
    GlobalLinkageId *dest_linkage_ptr;
    if (tld->id == TldIdVar) {
        TldVar *tld_var = (TldVar *)tld;
        set_global_linkage_node = &tld_var->set_global_linkage_node;
        dest_linkage_ptr = &tld_var->linkage;
    } else if (tld->id == TldIdFn) {
        TldFn *tld_fn = (TldFn *)tld;
        FnTableEntry *fn_entry = tld_fn->fn_entry;
        set_global_linkage_node = &fn_entry->set_global_linkage_node;
        dest_linkage_ptr = &fn_entry->linkage;
    } else {
        // error is caught in pass1 IR gen
        zig_unreachable();
    }

    AstNode *source_node = instruction->base.source_node;
    if (*set_global_linkage_node) {
        ErrorMsg *msg = ir_add_error_node(ira, source_node, buf_sprintf("linkage set twice"));
        add_error_note(ira->codegen, msg, *set_global_linkage_node, buf_sprintf("first set here"));
        return ira->codegen->builtin_types.entry_invalid;
    }
    *set_global_linkage_node = source_node;
    *dest_linkage_ptr = linkage_scalar;

    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_set_debug_safety(IrAnalyze *ira,
        IrInstructionSetDebugSafety *set_debug_safety_instruction)
{
    IrInstruction *target_instruction = set_debug_safety_instruction->scope_value->other;
    TypeTableEntry *target_type = target_instruction->value.type;
    if (type_is_invalid(target_type))
        return ira->codegen->builtin_types.entry_invalid;
    ConstExprValue *target_val = ir_resolve_const(ira, target_instruction, UndefBad);
    if (!target_val)
        return ira->codegen->builtin_types.entry_invalid;

    if (ira->new_irb.exec->is_inline) {
        // ignore setDebugSafety when running functions at compile time
        ir_build_const_from(ira, &set_debug_safety_instruction->base);
        return ira->codegen->builtin_types.entry_void;
    }

    bool *safety_off_ptr;
    AstNode **safety_set_node_ptr;
    if (target_type->id == TypeTableEntryIdBlock) {
        ScopeBlock *block_scope = (ScopeBlock *)target_val->data.x_block;
        safety_off_ptr = &block_scope->safety_off;
        safety_set_node_ptr = &block_scope->safety_set_node;
    } else if (target_type->id == TypeTableEntryIdFn) {
        FnTableEntry *target_fn = target_val->data.x_fn.fn_entry;
        assert(target_fn->def_scope);
        safety_off_ptr = &target_fn->def_scope->safety_off;
        safety_set_node_ptr = &target_fn->def_scope->safety_set_node;
    } else if (target_type->id == TypeTableEntryIdMetaType) {
        ScopeDecls *decls_scope;
        TypeTableEntry *type_arg = target_val->data.x_type;
        if (type_arg->id == TypeTableEntryIdStruct) {
            decls_scope = type_arg->data.structure.decls_scope;
        } else if (type_arg->id == TypeTableEntryIdEnum) {
            decls_scope = type_arg->data.enumeration.decls_scope;
        } else if (type_arg->id == TypeTableEntryIdUnion) {
            decls_scope = type_arg->data.unionation.decls_scope;
        } else {
            ir_add_error_node(ira, target_instruction->source_node,
                buf_sprintf("expected scope reference, found type '%s'", buf_ptr(&type_arg->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
        safety_off_ptr = &decls_scope->safety_off;
        safety_set_node_ptr = &decls_scope->safety_set_node;
    } else {
        ir_add_error_node(ira, target_instruction->source_node,
            buf_sprintf("expected scope reference, found type '%s'", buf_ptr(&target_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *debug_safety_on_value = set_debug_safety_instruction->debug_safety_on->other;
    bool want_debug_safety;
    if (!ir_resolve_bool(ira, debug_safety_on_value, &want_debug_safety))
        return ira->codegen->builtin_types.entry_invalid;

    AstNode *source_node = set_debug_safety_instruction->base.source_node;
    if (*safety_set_node_ptr) {
        ErrorMsg *msg = ir_add_error_node(ira, source_node,
                buf_sprintf("function test attribute set twice"));
        add_error_note(ira->codegen, msg, *safety_set_node_ptr, buf_sprintf("first set here"));
        return ira->codegen->builtin_types.entry_invalid;
    }
    *safety_set_node_ptr = source_node;
    *safety_off_ptr = !want_debug_safety;

    ir_build_const_from(ira, &set_debug_safety_instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_slice_type(IrAnalyze *ira,
        IrInstructionSliceType *slice_type_instruction)
{
    IrInstruction *child_type = slice_type_instruction->child_type->other;
    if (type_is_invalid(child_type->value.type))
        return ira->codegen->builtin_types.entry_invalid;
    bool is_const = slice_type_instruction->is_const;

    TypeTableEntry *resolved_child_type = ir_resolve_type(ira, child_type);
    TypeTableEntry *canon_child_type = get_underlying_type(resolved_child_type);
    if (type_is_invalid(canon_child_type))
        return ira->codegen->builtin_types.entry_invalid;

    switch (canon_child_type->id) {
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdInvalid: // handled above
            zig_unreachable();
        case TypeTableEntryIdVar:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdArgTuple:
            ir_add_error_node(ira, slice_type_instruction->base.source_node,
                    buf_sprintf("slice of type '%s' not allowed", buf_ptr(&resolved_child_type->name)));
            // TODO if this is a typedecl, add error note showing the declaration of the type decl
            return ira->codegen->builtin_types.entry_invalid;
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdEnumTag:
            {
                type_ensure_zero_bits_known(ira->codegen, resolved_child_type);
                TypeTableEntry *result_type = get_slice_type(ira->codegen, resolved_child_type, is_const);
                ConstExprValue *out_val = ir_build_const_from(ira, &slice_type_instruction->base);
                out_val->data.x_type = result_type;
                return ira->codegen->builtin_types.entry_type;
            }
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_asm(IrAnalyze *ira, IrInstructionAsm *asm_instruction) {
    assert(asm_instruction->base.source_node->type == NodeTypeAsmExpr);

    AstNodeAsmExpr *asm_expr = &asm_instruction->base.source_node->data.asm_expr;

    bool global_scope = (scope_fn_entry(asm_instruction->base.scope) == nullptr);
    if (global_scope) {
        if (asm_expr->output_list.length != 0 || asm_expr->input_list.length != 0 ||
            asm_expr->clobber_list.length != 0)
        {
            ir_add_error(ira, &asm_instruction->base,
                buf_sprintf("global assembly cannot have inputs, outputs, or clobbers"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        buf_append_char(&ira->codegen->global_asm, '\n');
        buf_append_buf(&ira->codegen->global_asm, asm_expr->asm_template);

        ir_build_const_from(ira, &asm_instruction->base);
        return ira->codegen->builtin_types.entry_void;
    }

    if (!ir_emit_global_runtime_side_effect(ira, &asm_instruction->base))
        return ira->codegen->builtin_types.entry_invalid;

    // TODO validate the output types and variable types

    IrInstruction **input_list = allocate<IrInstruction *>(asm_expr->input_list.length);
    IrInstruction **output_types = allocate<IrInstruction *>(asm_expr->output_list.length);

    TypeTableEntry *return_type = ira->codegen->builtin_types.entry_void;
    for (size_t i = 0; i < asm_expr->output_list.length; i += 1) {
        AsmOutput *asm_output = asm_expr->output_list.at(i);
        if (asm_output->return_type) {
            output_types[i] = asm_instruction->output_types[i]->other;
            return_type = ir_resolve_type(ira, output_types[i]);
            if (type_is_invalid(return_type))
                return ira->codegen->builtin_types.entry_invalid;
        }
    }

    for (size_t i = 0; i < asm_expr->input_list.length; i += 1) {
        input_list[i] = asm_instruction->input_list[i]->other;
        if (type_is_invalid(input_list[i]->value.type))
            return ira->codegen->builtin_types.entry_invalid;
    }

    ir_build_asm_from(&ira->new_irb, &asm_instruction->base, input_list, output_types,
        asm_instruction->output_vars, asm_instruction->return_count, asm_instruction->has_side_effects);
    return return_type;
}

static TypeTableEntry *ir_analyze_instruction_array_type(IrAnalyze *ira,
        IrInstructionArrayType *array_type_instruction)
{
    IrInstruction *size_value = array_type_instruction->size->other;
    uint64_t size;
    if (!ir_resolve_usize(ira, size_value, &size))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *child_type_value = array_type_instruction->child_type->other;
    TypeTableEntry *child_type = ir_resolve_type(ira, child_type_value);
    TypeTableEntry *canon_child_type = get_underlying_type(child_type);
    if (type_is_invalid(canon_child_type))
        return ira->codegen->builtin_types.entry_invalid;
    switch (canon_child_type->id) {
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdInvalid: // handled above
            zig_unreachable();
        case TypeTableEntryIdVar:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdArgTuple:
            ir_add_error_node(ira, array_type_instruction->base.source_node,
                    buf_sprintf("array of type '%s' not allowed", buf_ptr(&child_type->name)));
            // TODO if this is a typedecl, add error note showing the declaration of the type decl
            return ira->codegen->builtin_types.entry_invalid;
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdEnumTag:
            {
                TypeTableEntry *result_type = get_array_type(ira->codegen, child_type, size);
                ConstExprValue *out_val = ir_build_const_from(ira, &array_type_instruction->base);
                out_val->data.x_type = result_type;
                return ira->codegen->builtin_types.entry_type;
            }
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_compile_var(IrAnalyze *ira,
        IrInstructionCompileVar *compile_var_instruction)
{
    IrInstruction *name_value = compile_var_instruction->name->other;
    Buf *var_name = ir_resolve_str(ira, name_value);
    if (!var_name)
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *out_val = ir_build_const_from(ira, &compile_var_instruction->base);
    auto entry = ira->codegen->compile_vars.maybe_get(var_name);
    if (entry) {
        *out_val = *entry->value;
        return out_val->type;
    } else {
        ir_add_error_node(ira, name_value->source_node,
            buf_sprintf("unrecognized compile variable: '%s'", buf_ptr(var_name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_size_of(IrAnalyze *ira,
        IrInstructionSizeOf *size_of_instruction)
{
    IrInstruction *type_value = size_of_instruction->type_value->other;
    TypeTableEntry *type_entry = ir_resolve_type(ira, type_value);
    TypeTableEntry *canon_type_entry = get_underlying_type(type_entry);

    ensure_complete_type(ira->codegen, type_entry);
    if (type_is_invalid(canon_type_entry))
        return ira->codegen->builtin_types.entry_invalid;

    switch (canon_type_entry->id) {
        case TypeTableEntryIdInvalid: // handled above
        case TypeTableEntryIdTypeDecl:
            zig_unreachable();
        case TypeTableEntryIdVar:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdArgTuple:
            ir_add_error_node(ira, size_of_instruction->base.source_node,
                    buf_sprintf("no size available for type '%s'", buf_ptr(&type_entry->name)));
            // TODO if this is a typedecl, add error note showing the declaration of the type decl
            return ira->codegen->builtin_types.entry_invalid;
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdEnumTag:
        case TypeTableEntryIdFn:
            {
                uint64_t size_in_bytes = type_size(ira->codegen, type_entry);
                ConstExprValue *out_val = ir_build_const_from(ira, &size_of_instruction->base);
                bignum_init_unsigned(&out_val->data.x_bignum, size_in_bytes);
                return ira->codegen->builtin_types.entry_num_lit_int;
            }
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_test_non_null(IrAnalyze *ira, IrInstructionTestNonNull *instruction) {
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *type_entry = value->value.type;

    if (type_entry->id == TypeTableEntryIdMaybe) {
        if (instr_is_comptime(value)) {
            ConstExprValue *maybe_val = ir_resolve_const(ira, value, UndefBad);
            if (!maybe_val)
                return ira->codegen->builtin_types.entry_invalid;

            ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
            out_val->data.x_bool = (maybe_val->data.x_maybe != nullptr);
            return ira->codegen->builtin_types.entry_bool;
        }

        ir_build_test_nonnull_from(&ira->new_irb, &instruction->base, value);
        return ira->codegen->builtin_types.entry_bool;
    } else if (type_entry->id == TypeTableEntryIdNullLit) {
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        out_val->data.x_bool = false;
        return ira->codegen->builtin_types.entry_bool;
    } else {
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        out_val->data.x_bool = true;
        return ira->codegen->builtin_types.entry_bool;
    }
}

static TypeTableEntry *ir_analyze_instruction_unwrap_maybe(IrAnalyze *ira,
        IrInstructionUnwrapMaybe *unwrap_maybe_instruction)
{
    IrInstruction *value = unwrap_maybe_instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *ptr_type = value->value.type;
    if (ptr_type->id == TypeTableEntryIdMetaType) {
        // surprise! actually this is just ??T not an unwrap maybe instruction
        TypeTableEntry *ptr_type_ptr = ir_resolve_type(ira, value);
        assert(ptr_type_ptr->id == TypeTableEntryIdPointer);
        TypeTableEntry *child_type = ptr_type_ptr->data.pointer.child_type;
        type_ensure_zero_bits_known(ira->codegen, child_type);
        TypeTableEntry *layer1 = get_maybe_type(ira->codegen, child_type);
        TypeTableEntry *layer2 = get_maybe_type(ira->codegen, layer1);
        TypeTableEntry *result_type = get_pointer_to_type(ira->codegen, layer2, true);

        IrInstruction *const_instr = ir_build_const_type(&ira->new_irb, unwrap_maybe_instruction->base.scope,
                unwrap_maybe_instruction->base.source_node, result_type);
        ir_link_new_instruction(const_instr, &unwrap_maybe_instruction->base);
        return const_instr->value.type;
    }

    assert(ptr_type->id == TypeTableEntryIdPointer);

    TypeTableEntry *type_entry = ptr_type->data.pointer.child_type;
    // TODO handle typedef
    if (type_is_invalid(type_entry)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (type_entry->id != TypeTableEntryIdMaybe) {
        ir_add_error_node(ira, unwrap_maybe_instruction->value->source_node,
                buf_sprintf("expected nullable type, found '%s'", buf_ptr(&type_entry->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
    TypeTableEntry *child_type = type_entry->data.maybe.child_type;
    TypeTableEntry *result_type = get_pointer_to_type_extra(ira->codegen, child_type,
            ptr_type->data.pointer.is_const, ptr_type->data.pointer.is_volatile, 0, 0);

    if (instr_is_comptime(value)) {
        ConstExprValue *val = ir_resolve_const(ira, value, UndefBad);
        if (!val)
            return ira->codegen->builtin_types.entry_invalid;
        assert(val->data.x_ptr.special == ConstPtrSpecialRef);
        ConstExprValue *maybe_val = val->data.x_ptr.data.ref.pointee;

        if (maybe_val->special != ConstValSpecialRuntime) {
            if (!maybe_val->data.x_maybe) {
                ir_add_error(ira, &unwrap_maybe_instruction->base, buf_sprintf("unable to unwrap null"));
                return ira->codegen->builtin_types.entry_invalid;
            }
            ConstExprValue *out_val = ir_build_const_from(ira, &unwrap_maybe_instruction->base);
            out_val->data.x_ptr.special = ConstPtrSpecialRef;
            out_val->data.x_ptr.data.ref.pointee = maybe_val->data.x_maybe;
            return result_type;
        }
    }

    ir_build_unwrap_maybe_from(&ira->new_irb, &unwrap_maybe_instruction->base, value,
            unwrap_maybe_instruction->safety_check_on);
    return result_type;
}

static TypeTableEntry *ir_analyze_instruction_ctz(IrAnalyze *ira, IrInstructionCtz *ctz_instruction) {
    IrInstruction *value = ctz_instruction->value->other;
    if (type_is_invalid(value->value.type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (value->value.type->id == TypeTableEntryIdInt) {
        if (value->value.special != ConstValSpecialRuntime) {
            uint32_t result = bignum_ctz(&value->value.data.x_bignum,
                    value->value.type->data.integral.bit_count);
            ConstExprValue *out_val = ir_build_const_from(ira, &ctz_instruction->base);
            bignum_init_unsigned(&out_val->data.x_bignum, result);
            return value->value.type;
        }

        ir_build_ctz_from(&ira->new_irb, &ctz_instruction->base, value);
        return value->value.type;
    } else {
        ir_add_error_node(ira, ctz_instruction->base.source_node,
            buf_sprintf("expected integer type, found '%s'", buf_ptr(&value->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_instruction_clz(IrAnalyze *ira, IrInstructionClz *clz_instruction) {
    IrInstruction *value = clz_instruction->value->other;
    if (type_is_invalid(value->value.type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (value->value.type->id == TypeTableEntryIdInt) {
        if (value->value.special != ConstValSpecialRuntime) {
            uint32_t result = bignum_clz(&value->value.data.x_bignum,
                    value->value.type->data.integral.bit_count);
            ConstExprValue *out_val = ir_build_const_from(ira, &clz_instruction->base);
            bignum_init_unsigned(&out_val->data.x_bignum, result);
            return value->value.type;
        }

        ir_build_clz_from(&ira->new_irb, &clz_instruction->base, value);
        return value->value.type;
    } else {
        ir_add_error_node(ira, clz_instruction->base.source_node,
            buf_sprintf("expected integer type, found '%s'", buf_ptr(&value->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static IrInstruction *ir_analyze_enum_tag(IrAnalyze *ira, IrInstruction *source_instr, IrInstruction *value) {
    if (type_is_invalid(value->value.type))
        return ira->codegen->invalid_instruction;

    if (value->value.type->id != TypeTableEntryIdEnum) {
        ir_add_error(ira, source_instr,
            buf_sprintf("expected enum type, found '%s'", buf_ptr(&value->value.type->name)));
        return ira->codegen->invalid_instruction;
    }

    TypeTableEntry *tag_type = value->value.type->data.enumeration.tag_type;

    if (instr_is_comptime(value)) {
        ConstExprValue *val = ir_resolve_const(ira, value, UndefBad);
        if (!val)
            return ira->codegen->invalid_instruction;

        IrInstructionConst *const_instruction = ir_create_instruction<IrInstructionConst>(&ira->new_irb,
                source_instr->scope, source_instr->source_node);
        const_instruction->base.value.type = tag_type;
        const_instruction->base.value.special = ConstValSpecialStatic;
        bignum_init_unsigned(&const_instruction->base.value.data.x_bignum, val->data.x_enum.tag);
        return &const_instruction->base;
    }

    IrInstruction *result = ir_build_enum_tag(&ira->new_irb, source_instr->scope, source_instr->source_node, value);
    result->value.type = tag_type;
    return result;
}

static TypeTableEntry *ir_analyze_instruction_switch_br(IrAnalyze *ira,
        IrInstructionSwitchBr *switch_br_instruction)
{
    IrInstruction *target_value = switch_br_instruction->target_value->other;
    if (type_is_invalid(target_value->value.type))
        return ir_unreach_error(ira);

    size_t case_count = switch_br_instruction->case_count;

    bool is_comptime;
    if (!ir_resolve_comptime(ira, switch_br_instruction->is_comptime->other, &is_comptime))
        return ira->codegen->builtin_types.entry_invalid;

    if (is_comptime || instr_is_comptime(target_value)) {
        ConstExprValue *target_val = ir_resolve_const(ira, target_value, UndefBad);
        if (!target_val)
            return ir_unreach_error(ira);

        IrBasicBlock *old_dest_block = switch_br_instruction->else_block;
        for (size_t i = 0; i < case_count; i += 1) {
            IrInstructionSwitchBrCase *old_case = &switch_br_instruction->cases[i];
            IrInstruction *case_value = old_case->value->other;
            if (type_is_invalid(case_value->value.type))
                return ir_unreach_error(ira);

            if (case_value->value.type->id == TypeTableEntryIdEnum) {
                case_value = ir_analyze_enum_tag(ira, &switch_br_instruction->base, case_value);
                if (type_is_invalid(case_value->value.type))
                    return ir_unreach_error(ira);
            }

            IrInstruction *casted_case_value = ir_implicit_cast(ira, case_value, target_value->value.type);
            if (type_is_invalid(casted_case_value->value.type))
                return ir_unreach_error(ira);

            ConstExprValue *case_val = ir_resolve_const(ira, casted_case_value, UndefBad);
            if (!case_val)
                return ir_unreach_error(ira);

            if (const_values_equal(target_val, case_val)) {
                old_dest_block = old_case->block;
                break;
            }
        }

        if (is_comptime || old_dest_block->ref_count == 1) {
            return ir_inline_bb(ira, &switch_br_instruction->base, old_dest_block);
        } else {
            IrBasicBlock *new_dest_block = ir_get_new_bb(ira, old_dest_block, &switch_br_instruction->base);
            ir_build_br_from(&ira->new_irb, &switch_br_instruction->base, new_dest_block);
            return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
        }
    }

    IrInstructionSwitchBrCase *cases = allocate<IrInstructionSwitchBrCase>(case_count);
    for (size_t i = 0; i < case_count; i += 1) {
        IrInstructionSwitchBrCase *old_case = &switch_br_instruction->cases[i];
        IrInstructionSwitchBrCase *new_case = &cases[i];
        new_case->block = ir_get_new_bb(ira, old_case->block, &switch_br_instruction->base);
        new_case->value = ira->codegen->invalid_instruction;

        // Calling ir_get_new_bb set the ref_instruction on the new basic block.
        // However a switch br may branch to the same basic block which would trigger an
        // incorrect re-generation of the block. So we set it to null here and assign
        // it back after the loop.
        new_case->block->ref_instruction = nullptr;

        IrInstruction *old_value = old_case->value;
        IrInstruction *new_value = old_value->other;
        if (type_is_invalid(new_value->value.type))
            continue;

        if (new_value->value.type->id == TypeTableEntryIdEnum) {
            new_value = ir_analyze_enum_tag(ira, &switch_br_instruction->base, new_value);
            if (type_is_invalid(new_value->value.type))
                continue;
        }

        IrInstruction *casted_new_value = ir_implicit_cast(ira, new_value, target_value->value.type);
        if (type_is_invalid(casted_new_value->value.type))
            continue;

        if (!ir_resolve_const(ira, casted_new_value, UndefBad))
            continue;

        new_case->value = casted_new_value;
    }

    for (size_t i = 0; i < case_count; i += 1) {
        IrInstructionSwitchBrCase *new_case = &cases[i];
        if (new_case->value == ira->codegen->invalid_instruction)
            return ir_unreach_error(ira);
        new_case->block->ref_instruction = &switch_br_instruction->base;
    }

    IrBasicBlock *new_else_block = ir_get_new_bb(ira, switch_br_instruction->else_block, &switch_br_instruction->base);
    ir_build_switch_br_from(&ira->new_irb, &switch_br_instruction->base,
            target_value, new_else_block, case_count, cases, nullptr);
    return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
}

static TypeTableEntry *ir_analyze_instruction_switch_target(IrAnalyze *ira,
        IrInstructionSwitchTarget *switch_target_instruction)
{
    IrInstruction *target_value_ptr = switch_target_instruction->target_value_ptr->other;
    if (type_is_invalid(target_value_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (target_value_ptr->value.type->id == TypeTableEntryIdMetaType) {
        assert(instr_is_comptime(target_value_ptr));
        TypeTableEntry *ptr_type = target_value_ptr->value.data.x_type;
        assert(ptr_type->id == TypeTableEntryIdPointer);
        ConstExprValue *out_val = ir_build_const_from(ira, &switch_target_instruction->base);
        out_val->type = ira->codegen->builtin_types.entry_type;
        out_val->data.x_type = ptr_type->data.pointer.child_type;
        return out_val->type;
    }

    assert(target_value_ptr->value.type->id == TypeTableEntryIdPointer);

    TypeTableEntry *target_type = target_value_ptr->value.type->data.pointer.child_type;
    ConstExprValue *pointee_val = nullptr;
    if (instr_is_comptime(target_value_ptr)) {
        pointee_val = const_ptr_pointee(&target_value_ptr->value);
        if (pointee_val->special == ConstValSpecialRuntime)
            pointee_val = nullptr;
    }
    TypeTableEntry *canon_target_type = get_underlying_type(target_type);
    ensure_complete_type(ira->codegen, target_type);
    if (type_is_invalid(canon_target_type))
        return ira->codegen->builtin_types.entry_invalid;

    switch (canon_target_type->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdTypeDecl:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdPureError:
            if (pointee_val) {
                ConstExprValue *out_val = ir_build_const_from(ira, &switch_target_instruction->base);
                *out_val = *pointee_val;
                out_val->type = target_type;
                return target_type;
            }

            ir_build_load_ptr_from(&ira->new_irb, &switch_target_instruction->base, target_value_ptr);
            return target_type;
        case TypeTableEntryIdEnum:
            {
                TypeTableEntry *tag_type = target_type->data.enumeration.tag_type;
                if (pointee_val) {
                    ConstExprValue *out_val = ir_build_const_from(ira, &switch_target_instruction->base);
                    bignum_init_unsigned(&out_val->data.x_bignum, pointee_val->data.x_enum.tag);
                    return tag_type;
                }

                IrInstruction *enum_value = ir_build_load_ptr(&ira->new_irb, switch_target_instruction->base.scope,
                    switch_target_instruction->base.source_node, target_value_ptr);
                enum_value->value.type = target_type;
                ir_build_enum_tag_from(&ira->new_irb, &switch_target_instruction->base, enum_value);
                return tag_type;
            }
        case TypeTableEntryIdErrorUnion:
            // see https://github.com/andrewrk/zig/issues/83
            zig_panic("TODO switch on error union");
        case TypeTableEntryIdEnumTag:
            zig_panic("TODO switch on enum tag type");
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
            ir_add_error(ira, &switch_target_instruction->base,
                buf_sprintf("invalid switch target type '%s'", buf_ptr(&target_type->name)));
            // TODO if this is a typedecl, add error note showing the declaration of the type decl
            return ira->codegen->builtin_types.entry_invalid;
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_switch_var(IrAnalyze *ira, IrInstructionSwitchVar *instruction) {
    IrInstruction *target_value_ptr = instruction->target_value_ptr->other;
    if (type_is_invalid(target_value_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *prong_value = instruction->prong_value->other;
    if (type_is_invalid(prong_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    assert(target_value_ptr->value.type->id == TypeTableEntryIdPointer);
    TypeTableEntry *target_type = target_value_ptr->value.type->data.pointer.child_type;
    if (target_type->id == TypeTableEntryIdEnum) {
        ConstExprValue *prong_val = ir_resolve_const(ira, prong_value, UndefBad);
        if (!prong_val)
            return ira->codegen->builtin_types.entry_invalid;

        TypeEnumField *field = &target_type->data.enumeration.fields[prong_val->data.x_bignum.data.x_uint];
        if (prong_value->value.type->id == TypeTableEntryIdEnumTag) {
            field = &target_type->data.enumeration.fields[prong_val->data.x_bignum.data.x_uint];
        } else if (prong_value->value.type->id == TypeTableEntryIdEnum) {
            field = &target_type->data.enumeration.fields[prong_val->data.x_enum.tag];
        } else {
            zig_unreachable();
        }

        if (instr_is_comptime(target_value_ptr)) {
            ConstExprValue *target_val_ptr = ir_resolve_const(ira, target_value_ptr, UndefBad);
            if (!target_value_ptr)
                return ira->codegen->builtin_types.entry_invalid;

            ConstExprValue *pointee_val = const_ptr_pointee(target_val_ptr);
            if (pointee_val->type->id == TypeTableEntryIdEnum) {
                ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
                out_val->data.x_ptr.special = ConstPtrSpecialRef;
                out_val->data.x_ptr.data.ref.pointee = pointee_val->data.x_enum.payload;
                return get_pointer_to_type(ira->codegen, pointee_val->type,
                        target_value_ptr->value.type->data.pointer.is_const);
            } else {
                zig_panic("TODO comptime switch var");
            }
        }

        ir_build_enum_field_ptr_from(&ira->new_irb, &instruction->base, target_value_ptr, field);
        return get_pointer_to_type(ira->codegen, field->type_entry,
                target_value_ptr->value.type->data.pointer.is_const);
    } else {
        ErrorMsg *msg = ir_add_error(ira, &instruction->base,
            buf_sprintf("switch on type '%s' provides no expression parameter", buf_ptr(&target_type->name)));
        ir_add_typedef_err_note(ira, msg, target_type);
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_instruction_enum_tag(IrAnalyze *ira, IrInstructionEnumTag *enum_tag_instruction) {
    IrInstruction *value = enum_tag_instruction->value->other;
    IrInstruction *new_instruction = ir_analyze_enum_tag(ira, &enum_tag_instruction->base, value);
    ir_link_new_instruction(new_instruction, &enum_tag_instruction->base);
    return new_instruction->value.type;
}

static TypeTableEntry *ir_analyze_instruction_generated_code(IrAnalyze *ira, IrInstructionGeneratedCode *instruction) {
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (instr_is_comptime(value)) {
        ConstExprValue *val = ir_resolve_const(ira, value, UndefOk);
        if (!val)
            return ira->codegen->builtin_types.entry_invalid;

        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        *out_val = *val;
        return value->value.type;
    }

    instruction->base.other = value;
    return value->value.type;
}

static TypeTableEntry *ir_analyze_instruction_import(IrAnalyze *ira, IrInstructionImport *import_instruction) {
    IrInstruction *name_value = import_instruction->name->other;
    Buf *import_target_str = ir_resolve_str(ira, name_value);
    if (!import_target_str)
        return ira->codegen->builtin_types.entry_invalid;

    AstNode *source_node = import_instruction->base.source_node;
    ImportTableEntry *import = source_node->owner;

    Buf *import_target_path;
    Buf *search_dir;
    assert(import->package);
    PackageTableEntry *target_package;
    auto package_entry = import->package->package_table.maybe_get(import_target_str);
    if (package_entry) {
        target_package = package_entry->value;
        import_target_path = &target_package->root_src_path;
        search_dir = &target_package->root_src_dir;
    } else {
        // try it as a filename
        target_package = import->package;
        import_target_path = import_target_str;

        // search relative to importing file
        search_dir = buf_alloc();
        os_path_dirname(import->path, search_dir);
    }

    Buf full_path = BUF_INIT;
    os_path_join(search_dir, import_target_path, &full_path);

    Buf *import_code = buf_alloc();
    Buf *abs_full_path = buf_alloc();
    int err;
    if ((err = os_path_real(&full_path, abs_full_path))) {
        if (err == ErrorFileNotFound) {
            ir_add_error_node(ira, source_node,
                    buf_sprintf("unable to find '%s'", buf_ptr(import_target_path)));
            return ira->codegen->builtin_types.entry_invalid;
        } else {
            ira->codegen->error_during_imports = true;
            ir_add_error_node(ira, source_node,
                    buf_sprintf("unable to open '%s': %s", buf_ptr(&full_path), err_str(err)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    }

    auto import_entry = ira->codegen->import_table.maybe_get(abs_full_path);
    if (import_entry) {
        ConstExprValue *out_val = ir_build_const_from(ira, &import_instruction->base);
        out_val->data.x_import = import_entry->value;
        return ira->codegen->builtin_types.entry_namespace;
    }

    if ((err = os_fetch_file_path(abs_full_path, import_code))) {
        if (err == ErrorFileNotFound) {
            ir_add_error_node(ira, source_node,
                    buf_sprintf("unable to find '%s'", buf_ptr(import_target_path)));
            return ira->codegen->builtin_types.entry_invalid;
        } else {
            ir_add_error_node(ira, source_node,
                    buf_sprintf("unable to open '%s': %s", buf_ptr(&full_path), err_str(err)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    }
    ImportTableEntry *target_import = add_source_file(ira->codegen, target_package,
            abs_full_path, search_dir, import_target_path, import_code);

    scan_decls(ira->codegen, target_import->decls_scope, target_import->root);

    ConstExprValue *out_val = ir_build_const_from(ira, &import_instruction->base);
    out_val->data.x_import = target_import;
    return ira->codegen->builtin_types.entry_namespace;

}

static TypeTableEntry *ir_analyze_instruction_array_len(IrAnalyze *ira,
        IrInstructionArrayLen *array_len_instruction)
{
    IrInstruction *array_value = array_len_instruction->array_value->other;
    TypeTableEntry *canon_type = get_underlying_type(array_value->value.type);
    if (type_is_invalid(canon_type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (canon_type->id == TypeTableEntryIdArray) {
        return ir_analyze_const_usize(ira, &array_len_instruction->base,
                canon_type->data.array.len);
    } else if (is_slice(canon_type)) {
        if (array_value->value.special != ConstValSpecialRuntime) {
            ConstExprValue *len_val = &array_value->value.data.x_struct.fields[slice_len_index];
            if (len_val->special != ConstValSpecialRuntime) {
                return ir_analyze_const_usize(ira, &array_len_instruction->base,
                        len_val->data.x_bignum.data.x_uint);
            }
        }
        TypeStructField *field = &canon_type->data.structure.fields[slice_len_index];
        IrInstruction *len_ptr = ir_build_struct_field_ptr(&ira->new_irb, array_len_instruction->base.scope,
                array_len_instruction->base.source_node, array_value, field);
        len_ptr->value.type = get_pointer_to_type(ira->codegen, ira->codegen->builtin_types.entry_usize, true);
        ir_build_load_ptr_from(&ira->new_irb, &array_len_instruction->base, len_ptr);
        return ira->codegen->builtin_types.entry_usize;
    } else {
        ir_add_error_node(ira, array_len_instruction->base.source_node,
            buf_sprintf("type '%s' has no field 'len'", buf_ptr(&array_value->value.type->name)));
        // TODO if this is a typedecl, add error note showing the declaration of the type decl
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_instruction_ref(IrAnalyze *ira, IrInstructionRef *ref_instruction) {
    IrInstruction *value = ref_instruction->value->other;
    return ir_analyze_ref(ira, &ref_instruction->base, value, ref_instruction->is_const, ref_instruction->is_volatile);
}

static TypeTableEntry *ir_analyze_container_init_fields(IrAnalyze *ira, IrInstruction *instruction,
    TypeTableEntry *container_type, size_t instr_field_count, IrInstructionContainerInitFieldsField *fields)
{
    if (container_type->id != TypeTableEntryIdStruct || is_slice(container_type)) {
        ir_add_error(ira, instruction,
            buf_sprintf("type '%s' does not support struct initialization syntax",
                buf_ptr(&container_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (!type_is_complete(container_type))
        resolve_container_type(ira->codegen, container_type);

    size_t actual_field_count = container_type->data.structure.src_field_count;

    IrInstruction *first_non_const_instruction = nullptr;

    AstNode **field_assign_nodes = allocate<AstNode *>(actual_field_count);

    IrInstructionStructInitField *new_fields = allocate<IrInstructionStructInitField>(actual_field_count);

    bool is_comptime = ir_should_inline(ira->new_irb.exec, instruction->scope);

    ConstExprValue const_val = {};
    const_val.special = ConstValSpecialStatic;
    const_val.type = container_type;
    const_val.data.x_struct.fields = allocate<ConstExprValue>(actual_field_count);
    for (size_t i = 0; i < instr_field_count; i += 1) {
        IrInstructionContainerInitFieldsField *field = &fields[i];

        IrInstruction *field_value = field->value->other;
        if (type_is_invalid(field_value->value.type))
            return ira->codegen->builtin_types.entry_invalid;

        TypeStructField *type_field = find_struct_type_field(container_type, field->name);
        if (!type_field) {
            ir_add_error_node(ira, field->source_node,
                buf_sprintf("no member named '%s' in '%s'",
                    buf_ptr(field->name), buf_ptr(&container_type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }

        if (type_is_invalid(type_field->type_entry))
            return ira->codegen->builtin_types.entry_invalid;

        IrInstruction *casted_field_value = ir_implicit_cast(ira, field_value, type_field->type_entry);
        if (casted_field_value == ira->codegen->invalid_instruction)
            return ira->codegen->builtin_types.entry_invalid;

        size_t field_index = type_field->src_index;
        AstNode *existing_assign_node = field_assign_nodes[field_index];
        if (existing_assign_node) {
            ErrorMsg *msg = ir_add_error_node(ira, field->source_node, buf_sprintf("duplicate field"));
            add_error_note(ira->codegen, msg, existing_assign_node, buf_sprintf("other field here"));
            return ira->codegen->builtin_types.entry_invalid;
        }
        field_assign_nodes[field_index] = field->source_node;

        new_fields[field_index].value = casted_field_value;
        new_fields[field_index].type_struct_field = type_field;

        if (const_val.special == ConstValSpecialStatic) {
            if (is_comptime || casted_field_value->value.special != ConstValSpecialRuntime) {
                ConstExprValue *field_val = ir_resolve_const(ira, casted_field_value, UndefOk);
                if (!field_val)
                    return ira->codegen->builtin_types.entry_invalid;

                const_val.data.x_struct.fields[field_index] = *field_val;
            } else {
                first_non_const_instruction = casted_field_value;
                const_val.special = ConstValSpecialRuntime;
            }
        }
    }

    bool any_missing = false;
    for (size_t i = 0; i < actual_field_count; i += 1) {
        if (!field_assign_nodes[i]) {
            ir_add_error_node(ira, instruction->source_node,
                buf_sprintf("missing field: '%s'", buf_ptr(container_type->data.structure.fields[i].name)));
            any_missing = true;
        }
    }
    if (any_missing)
        return ira->codegen->builtin_types.entry_invalid;

    if (const_val.special == ConstValSpecialStatic) {
        ConstExprValue *out_val = ir_build_const_from(ira, instruction);
        *out_val = const_val;

        for (size_t i = 0; i < instr_field_count; i += 1) {
            ConstExprValue *field_val = &out_val->data.x_struct.fields[i];
            ConstParent *parent = get_const_val_parent(field_val);
            if (parent != nullptr) {
                parent->id = ConstParentIdStruct;
                parent->data.p_struct.field_index = i;
                parent->data.p_struct.struct_val = out_val;
            }
        }

        return container_type;
    }

    if (is_comptime) {
        ir_add_error_node(ira, first_non_const_instruction->source_node,
            buf_sprintf("unable to evaluate constant expression"));
        return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *new_instruction = ir_build_struct_init_from(&ira->new_irb, instruction,
        container_type, actual_field_count, new_fields);

    ir_add_alloca(ira, new_instruction, container_type);
    return container_type;
}

static TypeTableEntry *ir_analyze_instruction_container_init_list(IrAnalyze *ira,
        IrInstructionContainerInitList *instruction)
{
    IrInstruction *container_type_value = instruction->container_type->other;
    if (type_is_invalid(container_type_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    size_t elem_count = instruction->item_count;
    if (container_type_value->value.type->id == TypeTableEntryIdMetaType) {
        TypeTableEntry *container_type = ir_resolve_type(ira, container_type_value);
        if (type_is_invalid(container_type))
            return ira->codegen->builtin_types.entry_invalid;

        if (container_type->id == TypeTableEntryIdStruct && !is_slice(container_type) && elem_count == 0) {
            return ir_analyze_container_init_fields(ira, &instruction->base, container_type,
                    0, nullptr);
        } else if (is_slice(container_type)) {
            TypeTableEntry *pointer_type = container_type->data.structure.fields[slice_ptr_index].type_entry;
            assert(pointer_type->id == TypeTableEntryIdPointer);
            TypeTableEntry *child_type = pointer_type->data.pointer.child_type;
            TypeTableEntry *fixed_size_array_type = get_array_type(ira->codegen, child_type, elem_count);

            ConstExprValue const_val = {};
            const_val.special = ConstValSpecialStatic;
            const_val.type = fixed_size_array_type;
            const_val.data.x_array.elements = allocate<ConstExprValue>(elem_count);

            bool is_comptime = ir_should_inline(ira->new_irb.exec, instruction->base.scope);

            IrInstruction **new_items = allocate<IrInstruction *>(elem_count);

            IrInstruction *first_non_const_instruction = nullptr;

            for (size_t i = 0; i < elem_count; i += 1) {
                IrInstruction *arg_value = instruction->items[i]->other;
                if (type_is_invalid(arg_value->value.type))
                    return ira->codegen->builtin_types.entry_invalid;

                IrInstruction *casted_arg = ir_implicit_cast(ira, arg_value, child_type);
                if (casted_arg == ira->codegen->invalid_instruction)
                    return ira->codegen->builtin_types.entry_invalid;

                new_items[i] = casted_arg;

                if (const_val.special == ConstValSpecialStatic) {
                    if (is_comptime || casted_arg->value.special != ConstValSpecialRuntime) {
                        ConstExprValue *elem_val = ir_resolve_const(ira, casted_arg, UndefBad);
                        if (!elem_val)
                            return ira->codegen->builtin_types.entry_invalid;

                        const_val.data.x_array.elements[i] = *elem_val;
                    } else {
                        first_non_const_instruction = casted_arg;
                        const_val.special = ConstValSpecialRuntime;
                    }
                }
            }

            if (const_val.special == ConstValSpecialStatic) {
                ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
                *out_val = const_val;
                for (size_t i = 0; i < elem_count; i += 1) {
                    ConstExprValue *elem_val = &out_val->data.x_array.elements[i];
                    ConstParent *parent = get_const_val_parent(elem_val);
                    if (parent != nullptr) {
                        parent->id = ConstParentIdArray;
                        parent->data.p_array.array_val = out_val;
                        parent->data.p_array.elem_index = i;
                    }
                }
                return fixed_size_array_type;
            }

            if (is_comptime) {
                ir_add_error_node(ira, first_non_const_instruction->source_node,
                    buf_sprintf("unable to evaluate constant expression"));
                return ira->codegen->builtin_types.entry_invalid;
            }

            IrInstruction *new_instruction = ir_build_container_init_list_from(&ira->new_irb, &instruction->base,
                container_type_value, elem_count, new_items);
            ir_add_alloca(ira, new_instruction, fixed_size_array_type);
            return fixed_size_array_type;
        } else if (container_type->id == TypeTableEntryIdArray) {
            // same as slice init but we make a compile error if the length is wrong
            zig_panic("TODO array container init");
        } else if (container_type->id == TypeTableEntryIdVoid) {
            if (elem_count != 0) {
                ir_add_error_node(ira, instruction->base.source_node,
                    buf_sprintf("void expression expects no arguments"));
                return ira->codegen->builtin_types.entry_invalid;
            }
            return ir_analyze_void(ira, &instruction->base);
        } else {
            ir_add_error_node(ira, instruction->base.source_node,
                buf_sprintf("type '%s' does not support array initialization",
                    buf_ptr(&container_type->name)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    } else if (container_type_value->value.type->id == TypeTableEntryIdEnumTag) {
        if (elem_count != 1) {
            ir_add_error(ira, &instruction->base, buf_sprintf("enum initialization requires exactly one element"));
            return ira->codegen->builtin_types.entry_invalid;
        }
        ConstExprValue *tag_value = ir_resolve_const(ira, container_type_value, UndefBad);
        if (!tag_value)
            return ira->codegen->builtin_types.entry_invalid;

        TypeTableEntry *enum_type = container_type_value->value.type->data.enum_tag.enum_type;

        uint64_t tag_uint = tag_value->data.x_bignum.data.x_uint;
        TypeEnumField *field = &enum_type->data.enumeration.fields[tag_uint];
        TypeTableEntry *this_field_type = field->type_entry;

        IrInstruction *init_value = instruction->items[0]->other;
        if (type_is_invalid(init_value->value.type))
            return ira->codegen->builtin_types.entry_invalid;

        IrInstruction *casted_init_value = ir_implicit_cast(ira, init_value, this_field_type);
        if (casted_init_value == ira->codegen->invalid_instruction)
            return ira->codegen->builtin_types.entry_invalid;

        if (instr_is_comptime(casted_init_value)) {
            ConstExprValue *init_val = ir_resolve_const(ira, casted_init_value, UndefOk);
            if (!init_val)
                return ira->codegen->builtin_types.entry_invalid;
            ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
            out_val->data.x_enum.tag = tag_uint;
            out_val->data.x_enum.payload = init_val;
            return enum_type;
        }

        IrInstruction *new_instruction = ir_build_init_enum_from(&ira->new_irb, &instruction->base,
                enum_type, field, casted_init_value);
        ir_add_alloca(ira, new_instruction, enum_type);
        return enum_type;
    } else {
        ir_add_error(ira, container_type_value,
            buf_sprintf("expected type, found '%s'", buf_ptr(&container_type_value->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_instruction_container_init_fields(IrAnalyze *ira, IrInstructionContainerInitFields *instruction) {
    IrInstruction *container_type_value = instruction->container_type->other;
    TypeTableEntry *container_type = ir_resolve_type(ira, container_type_value);
    if (type_is_invalid(container_type))
        return ira->codegen->builtin_types.entry_invalid;

    return ir_analyze_container_init_fields(ira, &instruction->base, container_type,
        instruction->field_count, instruction->fields);
}

static TypeTableEntry *ir_analyze_min_max(IrAnalyze *ira, IrInstruction *source_instruction,
        IrInstruction *target_type_value, bool is_max)
{
    TypeTableEntry *target_type = ir_resolve_type(ira, target_type_value);
    TypeTableEntry *canon_type = get_underlying_type(target_type);
    if (type_is_invalid(canon_type))
        return ira->codegen->builtin_types.entry_invalid;
    switch (canon_type->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdInt:
            {
                ConstExprValue *out_val = ir_build_const_from(ira, source_instruction);
                eval_min_max_value(ira->codegen, canon_type, out_val, is_max);
                return ira->codegen->builtin_types.entry_num_lit_int;
            }
        case TypeTableEntryIdFloat:
            {
                ConstExprValue *out_val = ir_build_const_from(ira, source_instruction);
                eval_min_max_value(ira->codegen, canon_type, out_val, is_max);
                return ira->codegen->builtin_types.entry_num_lit_float;
            }
        case TypeTableEntryIdBool:
        case TypeTableEntryIdVoid:
            {
                ConstExprValue *out_val = ir_build_const_from(ira, source_instruction);
                eval_min_max_value(ira->codegen, canon_type, out_val, is_max);
                return target_type;
            }
        case TypeTableEntryIdEnumTag:
            zig_panic("TODO min/max value for enum tag type");
        case TypeTableEntryIdVar:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdUnreachable:
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
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
            {
                const char *err_format = is_max ?
                    "no max value available for type '%s'" :
                    "no min value available for type '%s'";
                ir_add_error(ira, source_instruction,
                        buf_sprintf(err_format, buf_ptr(&target_type->name)));
                // TODO if this is a typedecl, add error note showing the declaration of the type decl
                return ira->codegen->builtin_types.entry_invalid;
            }
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_min_value(IrAnalyze *ira,
        IrInstructionMinValue *instruction)
{
    return ir_analyze_min_max(ira, &instruction->base, instruction->value->other, false);
}

static TypeTableEntry *ir_analyze_instruction_max_value(IrAnalyze *ira,
        IrInstructionMaxValue *instruction)
{
    return ir_analyze_min_max(ira, &instruction->base, instruction->value->other, true);
}

static TypeTableEntry *ir_analyze_instruction_compile_err(IrAnalyze *ira,
        IrInstructionCompileErr *instruction)
{
    IrInstruction *msg_value = instruction->msg->other;
    Buf *msg_buf = ir_resolve_str(ira, msg_value);
    if (!msg_buf)
        return ira->codegen->builtin_types.entry_invalid;

    ir_add_error(ira, &instruction->base, msg_buf);
    return ira->codegen->builtin_types.entry_invalid;
}

static TypeTableEntry *ir_analyze_instruction_compile_log(IrAnalyze *ira, IrInstructionCompileLog *instruction) {
    Buf buf = BUF_INIT;
    fprintf(stderr, "| ");
    for (size_t i = 0; i < instruction->msg_count; i += 1) {
        IrInstruction *msg = instruction->msg_list[i]->other;
        if (type_is_invalid(msg->value.type))
            return ira->codegen->builtin_types.entry_invalid;
        buf_resize(&buf, 0);
        render_const_value(&buf, &msg->value);
        const char *comma_str = (i != 0) ? ", " : "";
        fprintf(stderr, "%s%s", comma_str, buf_ptr(&buf));
    }
    fprintf(stderr, "\n");

    ir_add_error(ira, &instruction->base, buf_sprintf("found compile log statement"));

    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_err_name(IrAnalyze *ira, IrInstructionErrName *instruction) {
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_value = ir_implicit_cast(ira, value, value->value.type);
    if (type_is_invalid(casted_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *str_type = get_slice_type(ira->codegen, ira->codegen->builtin_types.entry_u8, true);
    if (casted_value->value.special == ConstValSpecialStatic) {
        ErrorTableEntry *err = casted_value->value.data.x_pure_err;
        if (!err->cached_error_name_val) {
            ConstExprValue *array_val = create_const_str_lit(ira->codegen, &err->name);
            err->cached_error_name_val = create_const_slice(ira->codegen, array_val, 0, buf_len(&err->name), true);
        }
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        *out_val = *err->cached_error_name_val;
        return str_type;
    }

    ira->codegen->generate_error_name_table = true;
    ir_build_err_name_from(&ira->new_irb, &instruction->base, value);
    return str_type;
}

static TypeTableEntry *ir_analyze_instruction_enum_tag_name(IrAnalyze *ira, IrInstructionEnumTagName *instruction) {
    IrInstruction *target = instruction->target->other;
    if (type_is_invalid(target->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    assert(target->value.type->id == TypeTableEntryIdEnumTag);

    if (instr_is_comptime(target)) {
        TypeTableEntry *enum_type = target->value.type->data.enum_tag.enum_type;
        uint64_t tag_value = target->value.data.x_bignum.data.x_uint;
        TypeEnumField *field = &enum_type->data.enumeration.fields[tag_value];
        ConstExprValue *array_val = create_const_str_lit(ira->codegen, field->name);
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        init_const_slice(ira->codegen, out_val, array_val, 0, buf_len(field->name), true);
        return out_val->type;
    }

    if (!target->value.type->data.enum_tag.generate_name_table) {
        target->value.type->data.enum_tag.generate_name_table = true;
        ira->codegen->name_table_enums.append(target->value.type);
    }

    IrInstruction *result = ir_build_enum_tag_name(&ira->new_irb, instruction->base.scope,
            instruction->base.source_node, target);
    ir_link_new_instruction(result, &instruction->base);
    result->value.type = get_slice_type(ira->codegen, ira->codegen->builtin_types.entry_u8, true);
    return result->value.type;
}

static TypeTableEntry *ir_analyze_instruction_set_fn_ref_inline(IrAnalyze *ira,
        IrInstructionSetFnRefInline *instruction)
{
    IrInstruction *fn_ref = instruction->fn_ref->other;
    if (type_is_invalid(fn_ref->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (fn_ref->value.type->id == TypeTableEntryIdFn) {
        ConstExprValue *fn_ref_val = ir_resolve_const(ira, fn_ref, UndefBad);
        if (!fn_ref_val)
            return ira->codegen->builtin_types.entry_invalid;

        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        *out_val = *fn_ref_val;
        out_val->data.x_fn.is_inline = true;
        return out_val->type;
    } else if (fn_ref->value.type->id == TypeTableEntryIdBoundFn) {
        ConstExprValue *fn_ref_val = ir_resolve_const(ira, fn_ref, UndefBad);
        if (!fn_ref_val)
            return ira->codegen->builtin_types.entry_invalid;

        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        *out_val = *fn_ref_val;
        out_val->data.x_bound_fn.is_inline = true;
        return out_val->type;
    } else {
        ir_add_error(ira, &instruction->base,
                buf_sprintf("expected function type, found '%s'", buf_ptr(&fn_ref->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_instruction_type_name(IrAnalyze *ira, IrInstructionTypeName *instruction) {
    IrInstruction *type_value = instruction->type_value->other;
    TypeTableEntry *type_entry = ir_resolve_type(ira, type_value);
    if (type_is_invalid(type_entry))
        return ira->codegen->builtin_types.entry_invalid;

    if (!type_entry->cached_const_name_val) {
        type_entry->cached_const_name_val = create_const_str_lit(ira->codegen, &type_entry->name);
    }
    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    *out_val = *type_entry->cached_const_name_val;
    return out_val->type;
}

static TypeTableEntry *ir_analyze_instruction_c_import(IrAnalyze *ira, IrInstructionCImport *instruction) {
    AstNode *node = instruction->base.source_node;
    assert(node->type == NodeTypeFnCallExpr);
    AstNode *block_node = node->data.fn_call_expr.params.at(0);

    ScopeCImport *cimport_scope = create_cimport_scope(node, instruction->base.scope);

    // Execute the C import block like an inline function
    TypeTableEntry *void_type = ira->codegen->builtin_types.entry_void;
    IrInstruction *result = ir_eval_const_value(ira->codegen, &cimport_scope->base, block_node, void_type,
        ira->new_irb.exec->backward_branch_count, ira->new_irb.exec->backward_branch_quota, nullptr,
        &cimport_scope->buf, block_node, nullptr, nullptr);
    if (type_is_invalid(result->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    find_libc_include_path(ira->codegen);

    ImportTableEntry *child_import = allocate<ImportTableEntry>(1);
    child_import->decls_scope = create_decls_scope(node, nullptr, nullptr, child_import);
    child_import->c_import_node = node;

    ZigList<ErrorMsg *> errors = {0};

    int err;
    if ((err = parse_h_buf(child_import, &errors, &cimport_scope->buf, ira->codegen, node))) {
        zig_panic("unable to parse h file: %s\n", err_str(err));
    }

    if (errors.length > 0) {
        ErrorMsg *parent_err_msg = ir_add_error_node(ira, node, buf_sprintf("C import failed"));
        for (size_t i = 0; i < errors.length; i += 1) {
            ErrorMsg *err_msg = errors.at(i);
            err_msg_add_note(parent_err_msg, err_msg);
        }

        return ira->codegen->builtin_types.entry_invalid;
    }

    if (ira->codegen->verbose) {
        fprintf(stderr, "\nC imports:\n");
        fprintf(stderr, "-----------\n");
        ast_render_decls(stderr, 4, child_import);
    }

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    out_val->data.x_import = child_import;
    return ira->codegen->builtin_types.entry_namespace;
}

static TypeTableEntry *ir_analyze_instruction_c_include(IrAnalyze *ira, IrInstructionCInclude *instruction) {
    IrInstruction *name_value = instruction->name->other;
    if (type_is_invalid(name_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    Buf *include_name = ir_resolve_str(ira, name_value);
    if (!include_name)
        return ira->codegen->builtin_types.entry_invalid;

    Buf *c_import_buf = exec_c_import_buf(ira->new_irb.exec);
    // We check for this error in pass1
    assert(c_import_buf);

    buf_appendf(c_import_buf, "#include <%s>\n", buf_ptr(include_name));

    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_c_define(IrAnalyze *ira, IrInstructionCDefine *instruction) {
    IrInstruction *name = instruction->name->other;
    if (type_is_invalid(name->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    Buf *define_name = ir_resolve_str(ira, name);
    if (!define_name)
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    Buf *define_value = ir_resolve_str(ira, value);
    if (!define_value)
        return ira->codegen->builtin_types.entry_invalid;

    Buf *c_import_buf = exec_c_import_buf(ira->new_irb.exec);
    // We check for this error in pass1
    assert(c_import_buf);

    buf_appendf(c_import_buf, "#define %s %s\n", buf_ptr(define_name), buf_ptr(define_value));

    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_c_undef(IrAnalyze *ira, IrInstructionCUndef *instruction) {
    IrInstruction *name = instruction->name->other;
    if (type_is_invalid(name->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    Buf *undef_name = ir_resolve_str(ira, name);
    if (!undef_name)
        return ira->codegen->builtin_types.entry_invalid;

    Buf *c_import_buf = exec_c_import_buf(ira->new_irb.exec);
    // We check for this error in pass1
    assert(c_import_buf);

    buf_appendf(c_import_buf, "#undef %s\n", buf_ptr(undef_name));

    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_embed_file(IrAnalyze *ira, IrInstructionEmbedFile *instruction) {
    IrInstruction *name = instruction->name->other;
    if (type_is_invalid(name->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    Buf *rel_file_path = ir_resolve_str(ira, name);
    if (!rel_file_path)
        return ira->codegen->builtin_types.entry_invalid;

    ImportTableEntry *import = get_scope_import(instruction->base.scope);
    // figure out absolute path to resource
    Buf source_dir_path = BUF_INIT;
    os_path_dirname(import->path, &source_dir_path);

    Buf file_path = BUF_INIT;
    os_path_resolve(&source_dir_path, rel_file_path, &file_path);

    // load from file system into const expr
    Buf file_contents = BUF_INIT;
    int err;
    if ((err = os_fetch_file_path(&file_path, &file_contents))) {
        if (err == ErrorFileNotFound) {
            ir_add_error(ira, instruction->name, buf_sprintf("unable to find '%s'", buf_ptr(&file_path)));
            return ira->codegen->builtin_types.entry_invalid;
        } else {
            ir_add_error(ira, instruction->name, buf_sprintf("unable to open '%s': %s", buf_ptr(&file_path), err_str(err)));
            return ira->codegen->builtin_types.entry_invalid;
        }
    }

    // TODO add dependency on the file we embedded so that we know if it changes
    // we'll have to invalidate the cache

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    init_const_str_lit(ira->codegen, out_val, &file_contents);

    return get_array_type(ira->codegen, ira->codegen->builtin_types.entry_u8, buf_len(&file_contents));
}

static TypeTableEntry *ir_analyze_instruction_cmpxchg(IrAnalyze *ira, IrInstructionCmpxchg *instruction) {
    IrInstruction *ptr = instruction->ptr->other;
    if (type_is_invalid(ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *cmp_value = instruction->cmp_value->other;
    if (type_is_invalid(cmp_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *new_value = instruction->new_value->other;
    if (type_is_invalid(new_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *success_order_value = instruction->success_order_value->other;
    if (type_is_invalid(success_order_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    AtomicOrder success_order;
    if (!ir_resolve_atomic_order(ira, success_order_value, &success_order))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *failure_order_value = instruction->failure_order_value->other;
    if (type_is_invalid(failure_order_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    AtomicOrder failure_order;
    if (!ir_resolve_atomic_order(ira, failure_order_value, &failure_order))
        return ira->codegen->builtin_types.entry_invalid;

    if (ptr->value.type->id != TypeTableEntryIdPointer) {
        ir_add_error(ira, instruction->ptr,
            buf_sprintf("expected pointer argument, found '%s'", buf_ptr(&ptr->value.type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    TypeTableEntry *child_type = ptr->value.type->data.pointer.child_type;

    IrInstruction *casted_cmp_value = ir_implicit_cast(ira, cmp_value, child_type);
    if (type_is_invalid(casted_cmp_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_new_value = ir_implicit_cast(ira, new_value, child_type);
    if (type_is_invalid(casted_new_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (success_order < AtomicOrderMonotonic) {
        ir_add_error(ira, success_order_value,
                buf_sprintf("success atomic ordering must be Monotonic or stricter"));
        return ira->codegen->builtin_types.entry_invalid;
    }
    if (failure_order < AtomicOrderMonotonic) {
        ir_add_error(ira, failure_order_value,
                buf_sprintf("failure atomic ordering must be Monotonic or stricter"));
        return ira->codegen->builtin_types.entry_invalid;
    }
    if (failure_order > success_order) {
        ir_add_error(ira, failure_order_value,
                buf_sprintf("failure atomic ordering must be no stricter than success"));
        return ira->codegen->builtin_types.entry_invalid;
    }
    if (failure_order == AtomicOrderRelease || failure_order == AtomicOrderAcqRel) {
        ir_add_error(ira, failure_order_value,
                buf_sprintf("failure atomic ordering must not be Release or AcqRel"));
        return ira->codegen->builtin_types.entry_invalid;
    }

    ir_build_cmpxchg_from(&ira->new_irb, &instruction->base, ptr, casted_cmp_value, casted_new_value,
        success_order_value, failure_order_value, success_order, failure_order);
    return ira->codegen->builtin_types.entry_bool;
}

static TypeTableEntry *ir_analyze_instruction_fence(IrAnalyze *ira, IrInstructionFence *instruction) {
    IrInstruction *order_value = instruction->order_value->other;
    if (type_is_invalid(order_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    AtomicOrder order;
    if (!ir_resolve_atomic_order(ira, order_value, &order))
        return ira->codegen->builtin_types.entry_invalid;

    ir_build_fence_from(&ira->new_irb, &instruction->base, order_value, order);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_div_exact(IrAnalyze *ira, IrInstructionDivExact *instruction) {
    IrInstruction *op1 = instruction->op1->other;
    if (type_is_invalid(op1->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *op2 = instruction->op2->other;
    if (type_is_invalid(op2->value.type))
        return ira->codegen->builtin_types.entry_invalid;


    IrInstruction *peer_instructions[] = { op1, op2 };
    TypeTableEntry *result_type = ir_resolve_peer_types(ira, instruction->base.source_node, peer_instructions, 2);

    if (type_is_invalid(result_type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *canon_type = get_underlying_type(result_type);

    if (canon_type->id != TypeTableEntryIdInt &&
        canon_type->id != TypeTableEntryIdNumLitInt)
    {
        ir_add_error(ira, &instruction->base,
                buf_sprintf("expected integer type, found '%s'", buf_ptr(&result_type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *casted_op1 = ir_implicit_cast(ira, op1, result_type);
    if (type_is_invalid(casted_op1->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op2 = ir_implicit_cast(ira, op2, result_type);
    if (type_is_invalid(casted_op2->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (casted_op1->value.special == ConstValSpecialStatic &&
        casted_op2->value.special == ConstValSpecialStatic)
    {
        ConstExprValue *op1_val = ir_resolve_const(ira, casted_op1, UndefBad);
        ConstExprValue *op2_val = ir_resolve_const(ira, casted_op2, UndefBad);
        assert(op1_val);
        assert(op2_val);

        if (op1_val->data.x_bignum.data.x_uint == 0) {
            ir_add_error(ira, &instruction->base, buf_sprintf("division by zero"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        BigNum remainder;
        if (bignum_rem(&remainder, &op1_val->data.x_bignum, &op2_val->data.x_bignum)) {
            ir_add_error(ira, &instruction->base, buf_sprintf("integer overflow"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        if (remainder.data.x_uint != 0) {
            ir_add_error(ira, &instruction->base, buf_sprintf("exact division had a remainder"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        bignum_div(&out_val->data.x_bignum, &op1_val->data.x_bignum, &op2_val->data.x_bignum);
        return result_type;
    }

    ir_build_div_exact_from(&ira->new_irb, &instruction->base, casted_op1, casted_op2);
    return result_type;
}

static TypeTableEntry *ir_analyze_instruction_truncate(IrAnalyze *ira, IrInstructionTruncate *instruction) {
    IrInstruction *dest_type_value = instruction->dest_type->other;
    TypeTableEntry *dest_type = ir_resolve_type(ira, dest_type_value);
    TypeTableEntry *canon_dest_type = get_underlying_type(dest_type);

    if (type_is_invalid(canon_dest_type))
        return ira->codegen->builtin_types.entry_invalid;

    if (canon_dest_type->id != TypeTableEntryIdInt &&
        canon_dest_type->id != TypeTableEntryIdNumLitInt)
    {
        ir_add_error(ira, dest_type_value, buf_sprintf("expected integer type, found '%s'", buf_ptr(&dest_type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *target = instruction->target->other;
    TypeTableEntry *src_type = target->value.type;
    TypeTableEntry *canon_src_type = get_underlying_type(src_type);
    if (type_is_invalid(canon_src_type))
        return ira->codegen->builtin_types.entry_invalid;

    if (canon_src_type->id != TypeTableEntryIdInt &&
        canon_src_type->id != TypeTableEntryIdNumLitInt)
    {
        ir_add_error(ira, target, buf_sprintf("expected integer type, found '%s'", buf_ptr(&src_type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (canon_src_type->data.integral.is_signed != canon_dest_type->data.integral.is_signed) {
        const char *sign_str = canon_dest_type->data.integral.is_signed ? "signed" : "unsigned";
        ir_add_error(ira, target, buf_sprintf("expected %s integer type, found '%s'", sign_str, buf_ptr(&src_type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    } else if (canon_src_type->data.integral.bit_count < canon_dest_type->data.integral.bit_count) {
        ir_add_error(ira, target, buf_sprintf("type '%s' has fewer bits than destination type '%s'",
                    buf_ptr(&src_type->name), buf_ptr(&dest_type->name)));
        // TODO if meta_type is type decl, add note pointing to type decl declaration
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (target->value.special == ConstValSpecialStatic) {
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        bignum_init_bignum(&out_val->data.x_bignum, &target->value.data.x_bignum);
        bignum_truncate(&out_val->data.x_bignum, canon_dest_type->data.integral.bit_count);
        return dest_type;
    }

    ir_build_truncate_from(&ira->new_irb, &instruction->base, dest_type_value, target);
    return dest_type;
}

static TypeTableEntry *ir_analyze_instruction_int_type(IrAnalyze *ira, IrInstructionIntType *instruction) {
    IrInstruction *is_signed_value = instruction->is_signed->other;
    bool is_signed;
    if (!ir_resolve_bool(ira, is_signed_value, &is_signed))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *bit_count_value = instruction->bit_count->other;
    uint64_t bit_count;
    if (!ir_resolve_usize(ira, bit_count_value, &bit_count))
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    out_val->data.x_type = get_int_type(ira->codegen, is_signed, (uint32_t)bit_count);
    return ira->codegen->builtin_types.entry_type;
}

static TypeTableEntry *ir_analyze_instruction_bool_not(IrAnalyze *ira, IrInstructionBoolNot *instruction) {
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *bool_type = ira->codegen->builtin_types.entry_bool;

    IrInstruction *casted_value = ir_implicit_cast(ira, value, bool_type);
    if (type_is_invalid(casted_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (casted_value->value.special != ConstValSpecialRuntime) {
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        out_val->data.x_bool = !casted_value->value.data.x_bool;
        return bool_type;
    }

    ir_build_bool_not_from(&ira->new_irb, &instruction->base, casted_value);
    return bool_type;
}

static TypeTableEntry *ir_analyze_instruction_memset(IrAnalyze *ira, IrInstructionMemset *instruction) {
    IrInstruction *dest_ptr = instruction->dest_ptr->other;
    if (type_is_invalid(dest_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *byte_value = instruction->byte->other;
    if (type_is_invalid(byte_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *count_value = instruction->count->other;
    if (type_is_invalid(count_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *dest_uncasted_type = get_underlying_type(dest_ptr->value.type);
    bool dest_is_volatile = (dest_uncasted_type->id == TypeTableEntryIdPointer) &&
        dest_uncasted_type->data.pointer.is_volatile;

    TypeTableEntry *usize = ira->codegen->builtin_types.entry_usize;
    TypeTableEntry *u8 = ira->codegen->builtin_types.entry_u8;
    TypeTableEntry *u8_ptr = get_pointer_to_type_extra(ira->codegen, u8, false, dest_is_volatile, 0, 0);

    IrInstruction *casted_dest_ptr = ir_implicit_cast(ira, dest_ptr, u8_ptr);
    if (type_is_invalid(casted_dest_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_byte = ir_implicit_cast(ira, byte_value, u8);
    if (type_is_invalid(casted_byte->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_count = ir_implicit_cast(ira, count_value, usize);
    if (type_is_invalid(casted_count->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (casted_dest_ptr->value.special == ConstValSpecialStatic &&
        casted_byte->value.special == ConstValSpecialStatic &&
        casted_count->value.special == ConstValSpecialStatic &&
        casted_dest_ptr->value.data.x_ptr.special != ConstPtrSpecialHardCodedAddr)
    {
        ConstExprValue *dest_ptr_val = &casted_dest_ptr->value;

        ConstExprValue *dest_elements;
        size_t start;
        size_t bound_end;
        switch (dest_ptr_val->data.x_ptr.special) {
            case ConstPtrSpecialInvalid:
            case ConstPtrSpecialDiscard:
                zig_unreachable();
            case ConstPtrSpecialRef:
                dest_elements = dest_ptr_val->data.x_ptr.data.ref.pointee;
                start = 0;
                bound_end = 1;
                break;
            case ConstPtrSpecialBaseArray:
                {
                    ConstExprValue *array_val = dest_ptr_val->data.x_ptr.data.base_array.array_val;
                    dest_elements = array_val->data.x_array.elements;
                    start = dest_ptr_val->data.x_ptr.data.base_array.elem_index;
                    bound_end = array_val->type->data.array.len;
                    break;
                }
            case ConstPtrSpecialBaseStruct:
                zig_panic("TODO memset on const inner struct");
            case ConstPtrSpecialHardCodedAddr:
                zig_unreachable();
        }

        size_t count = casted_count->value.data.x_bignum.data.x_uint;
        size_t end = start + count;
        if (end > bound_end) {
            ir_add_error(ira, count_value, buf_sprintf("out of bounds pointer access"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        ConstExprValue *byte_val = &casted_byte->value;
        for (size_t i = start; i < end; i += 1) {
            dest_elements[i] = *byte_val;
        }

        ir_build_const_from(ira, &instruction->base);
        return ira->codegen->builtin_types.entry_void;
    }

    ir_build_memset_from(&ira->new_irb, &instruction->base, casted_dest_ptr, casted_byte, casted_count);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_memcpy(IrAnalyze *ira, IrInstructionMemcpy *instruction) {
    IrInstruction *dest_ptr = instruction->dest_ptr->other;
    if (type_is_invalid(dest_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *src_ptr = instruction->src_ptr->other;
    if (type_is_invalid(src_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *count_value = instruction->count->other;
    if (type_is_invalid(count_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *dest_uncasted_type = get_underlying_type(dest_ptr->value.type);
    TypeTableEntry *src_uncasted_type = get_underlying_type(src_ptr->value.type);
    bool dest_is_volatile = (dest_uncasted_type->id == TypeTableEntryIdPointer) &&
        dest_uncasted_type->data.pointer.is_volatile;
    bool src_is_volatile = (src_uncasted_type->id == TypeTableEntryIdPointer) &&
        src_uncasted_type->data.pointer.is_volatile;

    TypeTableEntry *usize = ira->codegen->builtin_types.entry_usize;
    TypeTableEntry *u8 = ira->codegen->builtin_types.entry_u8;
    TypeTableEntry *u8_ptr_mut = get_pointer_to_type_extra(ira->codegen, u8, false, dest_is_volatile, 0, 0);
    TypeTableEntry *u8_ptr_const = get_pointer_to_type_extra(ira->codegen, u8, true, src_is_volatile, 0, 0);

    IrInstruction *casted_dest_ptr = ir_implicit_cast(ira, dest_ptr, u8_ptr_mut);
    if (type_is_invalid(casted_dest_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_src_ptr = ir_implicit_cast(ira, src_ptr, u8_ptr_const);
    if (type_is_invalid(casted_src_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_count = ir_implicit_cast(ira, count_value, usize);
    if (type_is_invalid(casted_count->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (casted_dest_ptr->value.special == ConstValSpecialStatic &&
        casted_src_ptr->value.special == ConstValSpecialStatic &&
        casted_count->value.special == ConstValSpecialStatic &&
        casted_dest_ptr->value.data.x_ptr.special != ConstPtrSpecialHardCodedAddr)
    {
        size_t count = casted_count->value.data.x_bignum.data.x_uint;

        ConstExprValue *dest_ptr_val = &casted_dest_ptr->value;
        ConstExprValue *dest_elements;
        size_t dest_start;
        size_t dest_end;
        switch (dest_ptr_val->data.x_ptr.special) {
            case ConstPtrSpecialInvalid:
            case ConstPtrSpecialDiscard:
                zig_unreachable();
            case ConstPtrSpecialRef:
                dest_elements = dest_ptr_val->data.x_ptr.data.ref.pointee;
                dest_start = 0;
                dest_end = 1;
                break;
            case ConstPtrSpecialBaseArray:
                {
                    ConstExprValue *array_val = dest_ptr_val->data.x_ptr.data.base_array.array_val;
                    dest_elements = array_val->data.x_array.elements;
                    dest_start = dest_ptr_val->data.x_ptr.data.base_array.elem_index;
                    dest_end = array_val->type->data.array.len;
                    break;
                }
            case ConstPtrSpecialBaseStruct:
                zig_panic("TODO memcpy on const inner struct");
            case ConstPtrSpecialHardCodedAddr:
                zig_unreachable();
        }

        if (dest_start + count > dest_end) {
            ir_add_error(ira, &instruction->base, buf_sprintf("out of bounds pointer access"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        ConstExprValue *src_ptr_val = &casted_src_ptr->value;
        ConstExprValue *src_elements;
        size_t src_start;
        size_t src_end;

        switch (src_ptr_val->data.x_ptr.special) {
            case ConstPtrSpecialInvalid:
            case ConstPtrSpecialDiscard:
                zig_unreachable();
            case ConstPtrSpecialRef:
                src_elements = src_ptr_val->data.x_ptr.data.ref.pointee;
                src_start = 0;
                src_end = 1;
                break;
            case ConstPtrSpecialBaseArray:
                {
                    ConstExprValue *array_val = src_ptr_val->data.x_ptr.data.base_array.array_val;
                    src_elements = array_val->data.x_array.elements;
                    src_start = src_ptr_val->data.x_ptr.data.base_array.elem_index;
                    src_end = array_val->type->data.array.len;
                    break;
                }
            case ConstPtrSpecialBaseStruct:
                zig_panic("TODO memcpy on const inner struct");
            case ConstPtrSpecialHardCodedAddr:
                zig_unreachable();
        }

        if (src_start + count > src_end) {
            ir_add_error(ira, &instruction->base, buf_sprintf("out of bounds pointer access"));
            return ira->codegen->builtin_types.entry_invalid;
        }

        // TODO check for noalias violations - this should be generalized to work for any function

        for (size_t i = 0; i < count; i += 1) {
            dest_elements[dest_start + i] = src_elements[src_start + i];
        }

        ir_build_const_from(ira, &instruction->base);
        return ira->codegen->builtin_types.entry_void;
    }

    ir_build_memcpy_from(&ira->new_irb, &instruction->base, casted_dest_ptr, casted_src_ptr, casted_count);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_slice(IrAnalyze *ira, IrInstructionSlice *instruction) {
    IrInstruction *ptr_ptr = instruction->ptr->other;
    if (type_is_invalid(ptr_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *ptr_type = ptr_ptr->value.type;
    assert(ptr_type->id == TypeTableEntryIdPointer);
    TypeTableEntry *non_canon_array_type = ptr_type->data.pointer.child_type;
    TypeTableEntry *canon_array_type = get_underlying_type(non_canon_array_type);

    IrInstruction *start = instruction->start->other;
    if (type_is_invalid(start->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *usize = ira->codegen->builtin_types.entry_usize;
    IrInstruction *casted_start = ir_implicit_cast(ira, start, usize);
    if (type_is_invalid(casted_start->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *end;
    if (instruction->end) {
        end = instruction->end->other;
        if (type_is_invalid(end->value.type))
            return ira->codegen->builtin_types.entry_invalid;
        end = ir_implicit_cast(ira, end, usize);
        if (type_is_invalid(end->value.type))
            return ira->codegen->builtin_types.entry_invalid;
    } else {
        end = nullptr;
    }

    TypeTableEntry *return_type;

    if (canon_array_type->id == TypeTableEntryIdArray) {
        return_type = get_slice_type(ira->codegen, canon_array_type->data.array.child_type, instruction->is_const);
    } else if (canon_array_type->id == TypeTableEntryIdPointer) {
        return_type = get_slice_type(ira->codegen, canon_array_type->data.pointer.child_type, instruction->is_const);
        if (!end) {
            ir_add_error(ira, &instruction->base, buf_sprintf("slice of pointer must include end value"));
            return ira->codegen->builtin_types.entry_invalid;
        }
    } else if (is_slice(canon_array_type)) {
        return_type = get_slice_type(ira->codegen,
                canon_array_type->data.structure.fields[slice_ptr_index].type_entry->data.pointer.child_type,
                instruction->is_const);
    } else {
        ir_add_error(ira, &instruction->base,
            buf_sprintf("slice of non-array type '%s'", buf_ptr(&non_canon_array_type->name)));
        // TODO if this is a typedecl, add error note showing the declaration of the type decl
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (instr_is_comptime(ptr_ptr) &&
        value_is_comptime(&casted_start->value) &&
        (!end || value_is_comptime(&end->value)))
    {
        ConstExprValue *array_val;
        ConstExprValue *parent_ptr;
        size_t abs_offset;
        size_t rel_end;
        if (canon_array_type->id == TypeTableEntryIdArray) {
            array_val = const_ptr_pointee(&ptr_ptr->value);
            abs_offset = 0;
            rel_end = canon_array_type->data.array.len;
            parent_ptr = nullptr;
        } else if (canon_array_type->id == TypeTableEntryIdPointer) {
            parent_ptr = const_ptr_pointee(&ptr_ptr->value);
            switch (parent_ptr->data.x_ptr.special) {
                case ConstPtrSpecialInvalid:
                case ConstPtrSpecialDiscard:
                    zig_unreachable();
                case ConstPtrSpecialRef:
                    array_val = nullptr;
                    abs_offset = SIZE_MAX;
                    rel_end = 1;
                    break;
                case ConstPtrSpecialBaseArray:
                    array_val = parent_ptr->data.x_ptr.data.base_array.array_val;
                    abs_offset = parent_ptr->data.x_ptr.data.base_array.elem_index;
                    rel_end = array_val->type->data.array.len - abs_offset;
                    break;
                case ConstPtrSpecialBaseStruct:
                    zig_panic("TODO slice const inner struct");
                case ConstPtrSpecialHardCodedAddr:
                    array_val = nullptr;
                    break;
            }
        } else if (is_slice(canon_array_type)) {
            ConstExprValue *slice_ptr = const_ptr_pointee(&ptr_ptr->value);
            parent_ptr = &slice_ptr->data.x_struct.fields[slice_ptr_index];
            ConstExprValue *len_val = &slice_ptr->data.x_struct.fields[slice_len_index];

            switch (parent_ptr->data.x_ptr.special) {
                case ConstPtrSpecialInvalid:
                case ConstPtrSpecialDiscard:
                    zig_unreachable();
                case ConstPtrSpecialRef:
                    array_val = nullptr;
                    abs_offset = SIZE_MAX;
                    rel_end = 1;
                    break;
                case ConstPtrSpecialBaseArray:
                    array_val = parent_ptr->data.x_ptr.data.base_array.array_val;
                    abs_offset = parent_ptr->data.x_ptr.data.base_array.elem_index;
                    rel_end = len_val->data.x_bignum.data.x_uint;
                    break;
                case ConstPtrSpecialBaseStruct:
                    zig_panic("TODO slice const inner struct");
                case ConstPtrSpecialHardCodedAddr:
                    array_val = nullptr;
                    break;
            }
        } else {
            zig_unreachable();
        }

        if (array_val || parent_ptr->data.x_ptr.special != ConstPtrSpecialHardCodedAddr) {
            uint64_t start_scalar = casted_start->value.data.x_bignum.data.x_uint;
            if (start_scalar > rel_end) {
                ir_add_error(ira, &instruction->base, buf_sprintf("out of bounds slice"));
                return ira->codegen->builtin_types.entry_invalid;
            }

            uint64_t end_scalar;
            if (end) {
                end_scalar = end->value.data.x_bignum.data.x_uint;
            } else {
                end_scalar = rel_end;
            }
            if (end_scalar > rel_end) {
                ir_add_error(ira, &instruction->base, buf_sprintf("out of bounds slice"));
                return ira->codegen->builtin_types.entry_invalid;
            }
            if (start_scalar > end_scalar) {
                ir_add_error(ira, &instruction->base, buf_sprintf("slice start is greater than end"));
                return ira->codegen->builtin_types.entry_invalid;
            }

            ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
            out_val->data.x_struct.fields = allocate<ConstExprValue>(2);

            ConstExprValue *ptr_val = &out_val->data.x_struct.fields[slice_ptr_index];

            if (array_val) {
                size_t index = abs_offset + start_scalar;
                init_const_ptr_array(ira->codegen, ptr_val, array_val, index, instruction->is_const);
                if (canon_array_type->id == TypeTableEntryIdArray) {
                    ptr_val->data.x_ptr.mut = ptr_ptr->value.data.x_ptr.mut;
                }
            } else {
                switch (parent_ptr->data.x_ptr.special) {
                    case ConstPtrSpecialInvalid:
                    case ConstPtrSpecialDiscard:
                        zig_unreachable();
                    case ConstPtrSpecialRef:
                        init_const_ptr_ref(ira->codegen, ptr_val,
                                parent_ptr->data.x_ptr.data.ref.pointee, instruction->is_const);
                        break;
                    case ConstPtrSpecialBaseArray:
                        zig_unreachable();
                    case ConstPtrSpecialBaseStruct:
                        zig_panic("TODO");
                    case ConstPtrSpecialHardCodedAddr:
                        zig_unreachable();
                }
            }

            ConstExprValue *len_val = &out_val->data.x_struct.fields[slice_len_index];
            init_const_usize(ira->codegen, len_val, end_scalar - start_scalar);

            return return_type;
        }
    }

    IrInstruction *new_instruction = ir_build_slice_from(&ira->new_irb, &instruction->base, ptr_ptr,
            casted_start, end, instruction->is_const, instruction->safety_check_on);
    ir_add_alloca(ira, new_instruction, return_type);

    return return_type;
}

static TypeTableEntry *ir_analyze_instruction_member_count(IrAnalyze *ira, IrInstructionMemberCount *instruction) {
    IrInstruction *container = instruction->container->other;
    if (type_is_invalid(container->value.type))
        return ira->codegen->builtin_types.entry_invalid;
    TypeTableEntry *container_type = ir_resolve_type(ira, container);
    TypeTableEntry *canon_type = get_underlying_type(container_type);

    uint64_t result;
    if (type_is_invalid(canon_type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (canon_type->id == TypeTableEntryIdEnum) {
        result = canon_type->data.enumeration.src_field_count;
    } else if (canon_type->id == TypeTableEntryIdStruct) {
        result = canon_type->data.structure.src_field_count;
    } else if (canon_type->id == TypeTableEntryIdUnion) {
        result = canon_type->data.unionation.src_field_count;
    } else {
        ir_add_error(ira, &instruction->base, buf_sprintf("no value count available for type '%s'", buf_ptr(&container_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    bignum_init_unsigned(&out_val->data.x_bignum, result);
    return ira->codegen->builtin_types.entry_num_lit_int;
}

static TypeTableEntry *ir_analyze_instruction_breakpoint(IrAnalyze *ira, IrInstructionBreakpoint *instruction) {
    ir_build_breakpoint_from(&ira->new_irb, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_return_address(IrAnalyze *ira, IrInstructionReturnAddress *instruction) {
    ir_build_return_address_from(&ira->new_irb, &instruction->base);

    TypeTableEntry *u8 = ira->codegen->builtin_types.entry_u8;
    TypeTableEntry *u8_ptr_const = get_pointer_to_type(ira->codegen, u8, true);
    return u8_ptr_const;
}

static TypeTableEntry *ir_analyze_instruction_frame_address(IrAnalyze *ira, IrInstructionFrameAddress *instruction) {
    ir_build_frame_address_from(&ira->new_irb, &instruction->base);

    TypeTableEntry *u8 = ira->codegen->builtin_types.entry_u8;
    TypeTableEntry *u8_ptr_const = get_pointer_to_type(ira->codegen, u8, true);
    return u8_ptr_const;
}

static TypeTableEntry *ir_analyze_instruction_alignof(IrAnalyze *ira, IrInstructionAlignOf *instruction) {
    IrInstruction *type_value = instruction->type_value->other;
    if (type_is_invalid(type_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;
    TypeTableEntry *type_entry = ir_resolve_type(ira, type_value);

    if (type_is_invalid(type_entry)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (type_entry->id == TypeTableEntryIdUnreachable) {
        ir_add_error(ira, instruction->type_value,
                buf_sprintf("no align available for type '%s'", buf_ptr(&type_entry->name)));
        return ira->codegen->builtin_types.entry_invalid;
    } else {
        uint64_t align_in_bytes = LLVMABISizeOfType(ira->codegen->target_data_ref, type_entry->type_ref);
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        bignum_init_unsigned(&out_val->data.x_bignum, align_in_bytes);
        return ira->codegen->builtin_types.entry_num_lit_int;
    }
}

static TypeTableEntry *ir_analyze_instruction_overflow_op(IrAnalyze *ira, IrInstructionOverflowOp *instruction) {
    IrInstruction *type_value = instruction->type_value->other;
    if (type_is_invalid(type_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;
    TypeTableEntry *dest_type = ir_resolve_type(ira, type_value);
    TypeTableEntry *canon_type = get_underlying_type(dest_type);
    if (type_is_invalid(canon_type))
        return ira->codegen->builtin_types.entry_invalid;

    if (canon_type->id != TypeTableEntryIdInt) {
        ir_add_error(ira, type_value,
            buf_sprintf("expected integer type, found '%s'", buf_ptr(&dest_type->name)));
        // TODO if this is a typedecl, add error note showing the declaration of the type decl
        return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *op1 = instruction->op1->other;
    if (type_is_invalid(op1->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op1 = ir_implicit_cast(ira, op1, dest_type);
    if (type_is_invalid(casted_op1->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *op2 = instruction->op2->other;
    if (type_is_invalid(op2->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_op2 = ir_implicit_cast(ira, op2, dest_type);
    if (type_is_invalid(casted_op2->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *result_ptr = instruction->result_ptr->other;
    if (type_is_invalid(result_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *expected_ptr_type = get_pointer_to_type(ira->codegen, dest_type, false);
    IrInstruction *casted_result_ptr = ir_implicit_cast(ira, result_ptr, expected_ptr_type);
    if (type_is_invalid(casted_result_ptr->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (casted_op1->value.special == ConstValSpecialStatic &&
        casted_op2->value.special == ConstValSpecialStatic &&
        casted_result_ptr->value.special == ConstValSpecialStatic)
    {
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        BigNum *op1_bignum = &casted_op1->value.data.x_bignum;
        BigNum *op2_bignum = &casted_op2->value.data.x_bignum;
        ConstExprValue *pointee_val = const_ptr_pointee(&casted_result_ptr->value);
        BigNum *dest_bignum = &pointee_val->data.x_bignum;
        switch (instruction->op) {
            case IrOverflowOpAdd:
                out_val->data.x_bool = bignum_add(dest_bignum, op1_bignum, op2_bignum);
                break;
            case IrOverflowOpSub:
                out_val->data.x_bool = bignum_sub(dest_bignum, op1_bignum, op2_bignum);
                break;
            case IrOverflowOpMul:
                out_val->data.x_bool = bignum_mul(dest_bignum, op1_bignum, op2_bignum);
                break;
            case IrOverflowOpShl:
                out_val->data.x_bool = bignum_shl(dest_bignum, op1_bignum, op2_bignum);
                break;
        }
        if (!bignum_fits_in_bits(dest_bignum, canon_type->data.integral.bit_count,
            canon_type->data.integral.is_signed))
        {
            out_val->data.x_bool = true;
            bignum_truncate(dest_bignum, canon_type->data.integral.bit_count);
        }
        pointee_val->special = ConstValSpecialStatic;
        return ira->codegen->builtin_types.entry_bool;
    }

    ir_build_overflow_op_from(&ira->new_irb, &instruction->base, instruction->op, type_value,
        casted_op1, casted_op2, casted_result_ptr, dest_type);
    return ira->codegen->builtin_types.entry_bool;
}

static TypeTableEntry *ir_analyze_instruction_test_err(IrAnalyze *ira, IrInstructionTestErr *instruction) {
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *non_canon_type = value->value.type;

    TypeTableEntry *canon_type = get_underlying_type(non_canon_type);
    if (type_is_invalid(canon_type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (canon_type->id == TypeTableEntryIdErrorUnion) {
        if (instr_is_comptime(value)) {
            ConstExprValue *err_union_val = ir_resolve_const(ira, value, UndefBad);
            if (!err_union_val)
                return ira->codegen->builtin_types.entry_invalid;

            if (err_union_val->special != ConstValSpecialRuntime) {
                ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
                out_val->data.x_bool = (err_union_val->data.x_err_union.err != nullptr);
                return ira->codegen->builtin_types.entry_bool;
            }
        }

        ir_build_test_err_from(&ira->new_irb, &instruction->base, value);
        return ira->codegen->builtin_types.entry_bool;
    } else if (canon_type->id == TypeTableEntryIdPureError) {
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        out_val->data.x_bool = true;
        return ira->codegen->builtin_types.entry_bool;
    } else {
        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        out_val->data.x_bool = false;
        return ira->codegen->builtin_types.entry_bool;
    }
}

static TypeTableEntry *ir_analyze_instruction_unwrap_err_code(IrAnalyze *ira,
    IrInstructionUnwrapErrCode *instruction)
{
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;
    TypeTableEntry *ptr_type = value->value.type;

    // This will be a pointer type because unwrap err payload IR instruction operates on a pointer to a thing.
    assert(ptr_type->id == TypeTableEntryIdPointer);

    TypeTableEntry *non_canon_type = ptr_type->data.pointer.child_type;
    TypeTableEntry *canon_type = get_underlying_type(non_canon_type);
    if (type_is_invalid(canon_type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (canon_type->id == TypeTableEntryIdErrorUnion) {
        if (instr_is_comptime(value)) {
            ConstExprValue *ptr_val = ir_resolve_const(ira, value, UndefBad);
            if (!ptr_val)
                return ira->codegen->builtin_types.entry_invalid;
            ConstExprValue *err_union_val = const_ptr_pointee(ptr_val);
            if (err_union_val->special != ConstValSpecialRuntime) {
                ErrorTableEntry *err = err_union_val->data.x_err_union.err;
                assert(err);

                ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
                out_val->data.x_pure_err = err;
                return ira->codegen->builtin_types.entry_pure_error;
            }
        }

        ir_build_unwrap_err_code_from(&ira->new_irb, &instruction->base, value);
        return ira->codegen->builtin_types.entry_pure_error;
    } else {
        ir_add_error(ira, value,
            buf_sprintf("expected error union type, found '%s'", buf_ptr(&non_canon_type->name)));
        // TODO if this is a typedecl, add error note showing the declaration of the type decl
        return ira->codegen->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *ir_analyze_instruction_unwrap_err_payload(IrAnalyze *ira,
    IrInstructionUnwrapErrPayload *instruction)
{
    assert(instruction->value->other);
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;
    TypeTableEntry *ptr_type = value->value.type;

    // This will be a pointer type because unwrap err payload IR instruction operates on a pointer to a thing.
    assert(ptr_type->id == TypeTableEntryIdPointer);

    TypeTableEntry *non_canon_type = ptr_type->data.pointer.child_type;
    TypeTableEntry *canon_type = get_underlying_type(non_canon_type);
    if (type_is_invalid(canon_type)) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (canon_type->id == TypeTableEntryIdErrorUnion) {
        TypeTableEntry *child_type = canon_type->data.error.child_type;
        TypeTableEntry *result_type = get_pointer_to_type_extra(ira->codegen, child_type,
                ptr_type->data.pointer.is_const, ptr_type->data.pointer.is_volatile, 0, 0);
        if (instr_is_comptime(value)) {
            ConstExprValue *ptr_val = ir_resolve_const(ira, value, UndefBad);
            if (!ptr_val)
                return ira->codegen->builtin_types.entry_invalid;
            ConstExprValue *err_union_val = const_ptr_pointee(ptr_val);
            if (err_union_val->special != ConstValSpecialRuntime) {
                ErrorTableEntry *err = err_union_val->data.x_err_union.err;
                if (err != nullptr) {
                    ir_add_error(ira, &instruction->base,
                        buf_sprintf("unable to unwrap error '%s'", buf_ptr(&err->name)));
                    return ira->codegen->builtin_types.entry_invalid;
                }

                ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
                out_val->data.x_ptr.special = ConstPtrSpecialRef;
                out_val->data.x_ptr.data.ref.pointee = err_union_val->data.x_err_union.payload;
                return result_type;
            }
        }

        ir_build_unwrap_err_payload_from(&ira->new_irb, &instruction->base, value, instruction->safety_check_on);
        return result_type;
    } else {
        ir_add_error(ira, value,
            buf_sprintf("expected error union type, found '%s'", buf_ptr(&non_canon_type->name)));
        // TODO if this is a typedecl, add error note showing the declaration of the type decl
        return ira->codegen->builtin_types.entry_invalid;
    }

}

static TypeTableEntry *ir_analyze_instruction_fn_proto(IrAnalyze *ira, IrInstructionFnProto *instruction) {
    AstNode *proto_node = instruction->base.source_node;
    assert(proto_node->type == NodeTypeFnProto);

    FnTypeId fn_type_id = {0};
    init_fn_type_id(&fn_type_id, proto_node, proto_node->data.fn_proto.params.length);

    for (; fn_type_id.next_param_index < fn_type_id.param_count; fn_type_id.next_param_index += 1) {
        AstNode *param_node = proto_node->data.fn_proto.params.at(fn_type_id.next_param_index);
        assert(param_node->type == NodeTypeParamDecl);

        IrInstruction *param_type_value = instruction->param_types[fn_type_id.next_param_index]->other;

        FnTypeParamInfo *param_info = &fn_type_id.param_info[fn_type_id.next_param_index];
        param_info->is_noalias = param_node->data.param_decl.is_noalias;
        param_info->type = ir_resolve_type(ira, param_type_value);
        if (type_is_invalid(param_info->type))
            return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *return_type_value = instruction->return_type->other;
    fn_type_id.return_type = ir_resolve_type(ira, return_type_value);
    if (type_is_invalid(fn_type_id.return_type))
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    out_val->data.x_type = get_fn_type(ira->codegen, &fn_type_id);
    return ira->codegen->builtin_types.entry_type;
}

static TypeTableEntry *ir_analyze_instruction_test_comptime(IrAnalyze *ira, IrInstructionTestComptime *instruction) {
    IrInstruction *value = instruction->value->other;
    if (type_is_invalid(value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    out_val->data.x_bool = instr_is_comptime(value);
    return ira->codegen->builtin_types.entry_bool;
}

static TypeTableEntry *ir_analyze_instruction_check_switch_prongs(IrAnalyze *ira,
        IrInstructionCheckSwitchProngs *instruction)
{
    IrInstruction *target_value = instruction->target_value->other;
    TypeTableEntry *switch_type = target_value->value.type;
    if (type_is_invalid(switch_type))
        return ira->codegen->builtin_types.entry_invalid;

    if (switch_type->id == TypeTableEntryIdEnumTag) {
        TypeTableEntry *enum_type = switch_type->data.enum_tag.enum_type;
        size_t *field_use_counts = allocate<size_t>(enum_type->data.enumeration.src_field_count);
        for (size_t range_i = 0; range_i < instruction->range_count; range_i += 1) {
            IrInstructionCheckSwitchProngsRange *range = &instruction->ranges[range_i];

            IrInstruction *start_value = range->start->other;
            if (type_is_invalid(start_value->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            IrInstruction *end_value = range->end->other;
            if (type_is_invalid(end_value->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            size_t start_index;
            size_t end_index;
            if (start_value->value.type->id == TypeTableEntryIdEnumTag) {
                start_index = start_value->value.data.x_bignum.data.x_uint;
            } else if (start_value->value.type->id == TypeTableEntryIdEnum) {
                start_index = start_value->value.data.x_enum.tag;
            } else {
                zig_unreachable();
            }
            if (end_value->value.type->id == TypeTableEntryIdEnumTag) {
                end_index = end_value->value.data.x_bignum.data.x_uint;
            } else if (end_value->value.type->id == TypeTableEntryIdEnum) {
                end_index = end_value->value.data.x_enum.tag;
            } else {
                zig_unreachable();
            }

            for (size_t field_index = start_index; field_index <= end_index; field_index += 1) {
                field_use_counts[field_index] += 1;
                if (field_use_counts[field_index] > 1) {
                    TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[field_index];
                    ir_add_error(ira, start_value,
                        buf_sprintf("duplicate switch value: '%s.%s'", buf_ptr(&enum_type->name),
                            buf_ptr(type_enum_field->name)));
                }
            }
        }
        for (uint32_t i = 0; i < enum_type->data.enumeration.src_field_count; i += 1) {
            if (field_use_counts[i] == 0) {
                ir_add_error(ira, &instruction->base,
                    buf_sprintf("enumeration value '%s.%s' not handled in switch", buf_ptr(&enum_type->name),
                        buf_ptr(enum_type->data.enumeration.fields[i].name)));
            }
        }
    } else {
        // TODO check prongs of types other than enumtag
    }
    ir_build_const_from(ira, &instruction->base);
    return ira->codegen->builtin_types.entry_void;
}

static TypeTableEntry *ir_analyze_instruction_test_type(IrAnalyze *ira, IrInstructionTestType *instruction) {
    IrInstruction *type_value = instruction->type_value->other;
    TypeTableEntry *type_entry = ir_resolve_type(ira, type_value);
    if (type_is_invalid(type_entry))
        return ira->codegen->builtin_types.entry_invalid;

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    out_val->data.x_bool = (type_entry->id == instruction->type_id);
    return ira->codegen->builtin_types.entry_bool;
}

static TypeTableEntry *ir_analyze_instruction_can_implicit_cast(IrAnalyze *ira,
        IrInstructionCanImplicitCast *instruction)
{
    IrInstruction *type_value = instruction->type_value->other;
    TypeTableEntry *type_entry = ir_resolve_type(ira, type_value);
    if (type_is_invalid(type_entry))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *target_value = instruction->target_value->other;
    if (type_is_invalid(target_value->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    ImplicitCastMatchResult result = ir_types_match_with_implicit_cast(ira, type_entry, target_value->value.type,
            target_value);

    if (result == ImplicitCastMatchResultReportedError) {
        zig_panic("TODO refactor implicit cast tester to return bool without reporting errors");
    }

    ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
    out_val->data.x_bool = (result == ImplicitCastMatchResultYes);
    return ira->codegen->builtin_types.entry_bool;
}

static TypeTableEntry *ir_analyze_instruction_panic(IrAnalyze *ira, IrInstructionPanic *instruction) {
    IrInstruction *msg = instruction->msg->other;
    if (type_is_invalid(msg->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    TypeTableEntry *str_type = get_slice_type(ira->codegen, ira->codegen->builtin_types.entry_u8, true);
    IrInstruction *casted_msg = ir_implicit_cast(ira, msg, str_type);
    if (type_is_invalid(casted_msg->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *new_instruction = ir_build_panic(&ira->new_irb, instruction->base.scope,
            instruction->base.source_node, casted_msg);
    ir_link_new_instruction(new_instruction, &instruction->base);
    return ir_finish_anal(ira, ira->codegen->builtin_types.entry_unreachable);
}

static TypeTableEntry *ir_analyze_instruction_ptr_cast(IrAnalyze *ira, IrInstructionPtrCast *instruction) {
    IrInstruction *dest_type_value = instruction->dest_type->other;
    TypeTableEntry *dest_type = ir_resolve_type(ira, dest_type_value);
    if (type_is_invalid(dest_type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *ptr = instruction->ptr->other;
    TypeTableEntry *src_type = ptr->value.type;
    if (type_is_invalid(src_type))
        return ira->codegen->builtin_types.entry_invalid;

    if (!type_is_codegen_pointer(src_type)) {
        ir_add_error(ira, ptr, buf_sprintf("expected pointer, found '%s'", buf_ptr(&src_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (!type_is_codegen_pointer(dest_type)) {
        ir_add_error(ira, dest_type_value,
                buf_sprintf("expected pointer, found '%s'", buf_ptr(&dest_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    if (instr_is_comptime(ptr)) {
        ConstExprValue *val = ir_resolve_const(ira, ptr, UndefOk);
        if (!val)
            return ira->codegen->builtin_types.entry_invalid;

        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        *out_val = *val;
        out_val->type = dest_type;
        return dest_type;
    }

    IrInstruction *result = ir_build_ptr_cast(&ira->new_irb, instruction->base.scope,
            instruction->base.source_node, nullptr, ptr);
    ir_link_new_instruction(result, &instruction->base);
    result->value.type = dest_type;
    return dest_type;
}

static TypeTableEntry *ir_analyze_instruction_int_to_ptr(IrAnalyze *ira, IrInstructionIntToPtr *instruction) {
    IrInstruction *dest_type_value = instruction->dest_type->other;
    TypeTableEntry *dest_type = ir_resolve_type(ira, dest_type_value);
    if (type_is_invalid(dest_type))
        return ira->codegen->builtin_types.entry_invalid;

    if (!type_is_codegen_pointer(dest_type)) {
        ir_add_error(ira, dest_type_value, buf_sprintf("expected pointer, found '%s'", buf_ptr(&dest_type->name)));
        return ira->codegen->builtin_types.entry_invalid;
    }

    IrInstruction *target = instruction->target->other;
    if (type_is_invalid(target->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    IrInstruction *casted_int = ir_implicit_cast(ira, target, ira->codegen->builtin_types.entry_usize);
    if (type_is_invalid(casted_int->value.type))
        return ira->codegen->builtin_types.entry_invalid;

    if (instr_is_comptime(casted_int)) {
        ConstExprValue *val = ir_resolve_const(ira, casted_int, UndefBad);
        if (!val)
            return ira->codegen->builtin_types.entry_invalid;

        ConstExprValue *out_val = ir_build_const_from(ira, &instruction->base);
        out_val->data.x_ptr.special = ConstPtrSpecialHardCodedAddr;
        out_val->data.x_ptr.data.hard_coded_addr.addr = bignum_to_twos_complement(&val->data.x_bignum);
        return dest_type;
    }

    IrInstruction *result = ir_build_int_to_ptr(&ira->new_irb, instruction->base.scope,
            instruction->base.source_node, nullptr, casted_int);
    ir_link_new_instruction(result, &instruction->base);
    return dest_type;
}

static TypeTableEntry *ir_analyze_instruction_decl_ref(IrAnalyze *ira,
        IrInstructionDeclRef *instruction)
{
    Tld *tld = instruction->tld;
    LVal lval = instruction->lval;

    resolve_top_level_decl(ira->codegen, tld, lval.is_ptr);
    if (tld->resolution == TldResolutionInvalid)
        return ira->codegen->builtin_types.entry_invalid;

    switch (tld->id) {
        case TldIdContainer:
        case TldIdCompTime:
            zig_unreachable();
        case TldIdVar:
        {
            TldVar *tld_var = (TldVar *)tld;
            VariableTableEntry *var = tld_var->var;

            IrInstruction *var_ptr = ir_get_var_ptr(ira, &instruction->base, var,
                    !lval.is_ptr || lval.is_const, lval.is_ptr && lval.is_volatile);
            if (type_is_invalid(var_ptr->value.type))
                return ira->codegen->builtin_types.entry_invalid;

            if (lval.is_ptr) {
                ir_link_new_instruction(var_ptr, &instruction->base);
                return var_ptr->value.type;
            } else {
                IrInstruction *loaded_instr = ir_get_deref(ira, &instruction->base, var_ptr);
                ir_link_new_instruction(loaded_instr, &instruction->base);
                return loaded_instr->value.type;
            }
        }
        case TldIdFn:
        {
            TldFn *tld_fn = (TldFn *)tld;
            FnTableEntry *fn_entry = tld_fn->fn_entry;
            assert(fn_entry->type_entry);

            IrInstruction *ref_instruction = ir_create_const_fn(&ira->new_irb, instruction->base.scope,
                    instruction->base.source_node, fn_entry);
            if (lval.is_ptr) {
                IrInstruction *ptr_instr = ir_get_ref(ira, &instruction->base, ref_instruction, true, false);
                ir_link_new_instruction(ptr_instr, &instruction->base);
                return ptr_instr->value.type;
            } else {
                ir_link_new_instruction(ref_instruction, &instruction->base);
                return ref_instruction->value.type;
            }
        }
        case TldIdTypeDef:
        {
            TldTypeDef *tld_typedef = (TldTypeDef *)tld;
            TypeTableEntry *typedef_type = tld_typedef->type_entry;

            IrInstruction *ref_instruction = ir_create_const_type(&ira->new_irb, instruction->base.scope,
                    instruction->base.source_node, typedef_type);
            if (lval.is_ptr) {
                IrInstruction *ptr_inst = ir_get_ref(ira, &instruction->base, ref_instruction, true, false);
                ir_link_new_instruction(ptr_inst, &instruction->base);
                return ptr_inst->value.type;
            } else {
                ir_link_new_instruction(ref_instruction, &instruction->base);
                return ref_instruction->value.type;
            }
        }
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction_nocast(IrAnalyze *ira, IrInstruction *instruction) {
    switch (instruction->id) {
        case IrInstructionIdInvalid:
        case IrInstructionIdWidenOrShorten:
        case IrInstructionIdIntToEnum:
        case IrInstructionIdIntToErr:
        case IrInstructionIdErrToInt:
        case IrInstructionIdStructInit:
        case IrInstructionIdStructFieldPtr:
        case IrInstructionIdEnumFieldPtr:
        case IrInstructionIdInitEnum:
        case IrInstructionIdPtrToInt:
            zig_unreachable();
        case IrInstructionIdReturn:
            return ir_analyze_instruction_return(ira, (IrInstructionReturn *)instruction);
        case IrInstructionIdConst:
            return ir_analyze_instruction_const(ira, (IrInstructionConst *)instruction);
        case IrInstructionIdUnOp:
            return ir_analyze_instruction_un_op(ira, (IrInstructionUnOp *)instruction);
        case IrInstructionIdBinOp:
            return ir_analyze_instruction_bin_op(ira, (IrInstructionBinOp *)instruction);
        case IrInstructionIdDeclVar:
            return ir_analyze_instruction_decl_var(ira, (IrInstructionDeclVar *)instruction);
        case IrInstructionIdLoadPtr:
            return ir_analyze_instruction_load_ptr(ira, (IrInstructionLoadPtr *)instruction);
        case IrInstructionIdStorePtr:
            return ir_analyze_instruction_store_ptr(ira, (IrInstructionStorePtr *)instruction);
        case IrInstructionIdElemPtr:
            return ir_analyze_instruction_elem_ptr(ira, (IrInstructionElemPtr *)instruction);
        case IrInstructionIdVarPtr:
            return ir_analyze_instruction_var_ptr(ira, (IrInstructionVarPtr *)instruction);
        case IrInstructionIdFieldPtr:
            return ir_analyze_instruction_field_ptr(ira, (IrInstructionFieldPtr *)instruction);
        case IrInstructionIdCall:
            return ir_analyze_instruction_call(ira, (IrInstructionCall *)instruction);
        case IrInstructionIdBr:
            return ir_analyze_instruction_br(ira, (IrInstructionBr *)instruction);
        case IrInstructionIdCondBr:
            return ir_analyze_instruction_cond_br(ira, (IrInstructionCondBr *)instruction);
        case IrInstructionIdUnreachable:
            return ir_analyze_instruction_unreachable(ira, (IrInstructionUnreachable *)instruction);
        case IrInstructionIdPhi:
            return ir_analyze_instruction_phi(ira, (IrInstructionPhi *)instruction);
        case IrInstructionIdTypeOf:
            return ir_analyze_instruction_typeof(ira, (IrInstructionTypeOf *)instruction);
        case IrInstructionIdToPtrType:
            return ir_analyze_instruction_to_ptr_type(ira, (IrInstructionToPtrType *)instruction);
        case IrInstructionIdPtrTypeChild:
            return ir_analyze_instruction_ptr_type_child(ira, (IrInstructionPtrTypeChild *)instruction);
        case IrInstructionIdSetGlobalAlign:
            return ir_analyze_instruction_set_global_align(ira, (IrInstructionSetGlobalAlign *)instruction);
        case IrInstructionIdSetGlobalSection:
            return ir_analyze_instruction_set_global_section(ira, (IrInstructionSetGlobalSection *)instruction);
        case IrInstructionIdSetGlobalLinkage:
            return ir_analyze_instruction_set_global_linkage(ira, (IrInstructionSetGlobalLinkage *)instruction);
        case IrInstructionIdSetDebugSafety:
            return ir_analyze_instruction_set_debug_safety(ira, (IrInstructionSetDebugSafety *)instruction);
        case IrInstructionIdSliceType:
            return ir_analyze_instruction_slice_type(ira, (IrInstructionSliceType *)instruction);
        case IrInstructionIdAsm:
            return ir_analyze_instruction_asm(ira, (IrInstructionAsm *)instruction);
        case IrInstructionIdArrayType:
            return ir_analyze_instruction_array_type(ira, (IrInstructionArrayType *)instruction);
        case IrInstructionIdCompileVar:
            return ir_analyze_instruction_compile_var(ira, (IrInstructionCompileVar *)instruction);
        case IrInstructionIdSizeOf:
            return ir_analyze_instruction_size_of(ira, (IrInstructionSizeOf *)instruction);
        case IrInstructionIdTestNonNull:
            return ir_analyze_instruction_test_non_null(ira, (IrInstructionTestNonNull *)instruction);
        case IrInstructionIdUnwrapMaybe:
            return ir_analyze_instruction_unwrap_maybe(ira, (IrInstructionUnwrapMaybe *)instruction);
        case IrInstructionIdClz:
            return ir_analyze_instruction_clz(ira, (IrInstructionClz *)instruction);
        case IrInstructionIdCtz:
            return ir_analyze_instruction_ctz(ira, (IrInstructionCtz *)instruction);
        case IrInstructionIdSwitchBr:
            return ir_analyze_instruction_switch_br(ira, (IrInstructionSwitchBr *)instruction);
        case IrInstructionIdSwitchTarget:
            return ir_analyze_instruction_switch_target(ira, (IrInstructionSwitchTarget *)instruction);
        case IrInstructionIdSwitchVar:
            return ir_analyze_instruction_switch_var(ira, (IrInstructionSwitchVar *)instruction);
        case IrInstructionIdEnumTag:
            return ir_analyze_instruction_enum_tag(ira, (IrInstructionEnumTag *)instruction);
        case IrInstructionIdGeneratedCode:
            return ir_analyze_instruction_generated_code(ira, (IrInstructionGeneratedCode *)instruction);
        case IrInstructionIdImport:
            return ir_analyze_instruction_import(ira, (IrInstructionImport *)instruction);
        case IrInstructionIdArrayLen:
            return ir_analyze_instruction_array_len(ira, (IrInstructionArrayLen *)instruction);
        case IrInstructionIdRef:
            return ir_analyze_instruction_ref(ira, (IrInstructionRef *)instruction);
        case IrInstructionIdContainerInitList:
            return ir_analyze_instruction_container_init_list(ira, (IrInstructionContainerInitList *)instruction);
        case IrInstructionIdContainerInitFields:
            return ir_analyze_instruction_container_init_fields(ira, (IrInstructionContainerInitFields *)instruction);
        case IrInstructionIdMinValue:
            return ir_analyze_instruction_min_value(ira, (IrInstructionMinValue *)instruction);
        case IrInstructionIdMaxValue:
            return ir_analyze_instruction_max_value(ira, (IrInstructionMaxValue *)instruction);
        case IrInstructionIdCompileErr:
            return ir_analyze_instruction_compile_err(ira, (IrInstructionCompileErr *)instruction);
        case IrInstructionIdCompileLog:
            return ir_analyze_instruction_compile_log(ira, (IrInstructionCompileLog *)instruction);
        case IrInstructionIdErrName:
            return ir_analyze_instruction_err_name(ira, (IrInstructionErrName *)instruction);
        case IrInstructionIdTypeName:
            return ir_analyze_instruction_type_name(ira, (IrInstructionTypeName *)instruction);
        case IrInstructionIdCImport:
            return ir_analyze_instruction_c_import(ira, (IrInstructionCImport *)instruction);
        case IrInstructionIdCInclude:
            return ir_analyze_instruction_c_include(ira, (IrInstructionCInclude *)instruction);
        case IrInstructionIdCDefine:
            return ir_analyze_instruction_c_define(ira, (IrInstructionCDefine *)instruction);
        case IrInstructionIdCUndef:
            return ir_analyze_instruction_c_undef(ira, (IrInstructionCUndef *)instruction);
        case IrInstructionIdEmbedFile:
            return ir_analyze_instruction_embed_file(ira, (IrInstructionEmbedFile *)instruction);
        case IrInstructionIdCmpxchg:
            return ir_analyze_instruction_cmpxchg(ira, (IrInstructionCmpxchg *)instruction);
        case IrInstructionIdFence:
            return ir_analyze_instruction_fence(ira, (IrInstructionFence *)instruction);
        case IrInstructionIdDivExact:
            return ir_analyze_instruction_div_exact(ira, (IrInstructionDivExact *)instruction);
        case IrInstructionIdTruncate:
            return ir_analyze_instruction_truncate(ira, (IrInstructionTruncate *)instruction);
        case IrInstructionIdIntType:
            return ir_analyze_instruction_int_type(ira, (IrInstructionIntType *)instruction);
        case IrInstructionIdBoolNot:
            return ir_analyze_instruction_bool_not(ira, (IrInstructionBoolNot *)instruction);
        case IrInstructionIdMemset:
            return ir_analyze_instruction_memset(ira, (IrInstructionMemset *)instruction);
        case IrInstructionIdMemcpy:
            return ir_analyze_instruction_memcpy(ira, (IrInstructionMemcpy *)instruction);
        case IrInstructionIdSlice:
            return ir_analyze_instruction_slice(ira, (IrInstructionSlice *)instruction);
        case IrInstructionIdMemberCount:
            return ir_analyze_instruction_member_count(ira, (IrInstructionMemberCount *)instruction);
        case IrInstructionIdBreakpoint:
            return ir_analyze_instruction_breakpoint(ira, (IrInstructionBreakpoint *)instruction);
        case IrInstructionIdReturnAddress:
            return ir_analyze_instruction_return_address(ira, (IrInstructionReturnAddress *)instruction);
        case IrInstructionIdFrameAddress:
            return ir_analyze_instruction_frame_address(ira, (IrInstructionFrameAddress *)instruction);
        case IrInstructionIdAlignOf:
            return ir_analyze_instruction_alignof(ira, (IrInstructionAlignOf *)instruction);
        case IrInstructionIdOverflowOp:
            return ir_analyze_instruction_overflow_op(ira, (IrInstructionOverflowOp *)instruction);
        case IrInstructionIdTestErr:
            return ir_analyze_instruction_test_err(ira, (IrInstructionTestErr *)instruction);
        case IrInstructionIdUnwrapErrCode:
            return ir_analyze_instruction_unwrap_err_code(ira, (IrInstructionUnwrapErrCode *)instruction);
        case IrInstructionIdUnwrapErrPayload:
            return ir_analyze_instruction_unwrap_err_payload(ira, (IrInstructionUnwrapErrPayload *)instruction);
        case IrInstructionIdFnProto:
            return ir_analyze_instruction_fn_proto(ira, (IrInstructionFnProto *)instruction);
        case IrInstructionIdTestComptime:
            return ir_analyze_instruction_test_comptime(ira, (IrInstructionTestComptime *)instruction);
        case IrInstructionIdCheckSwitchProngs:
            return ir_analyze_instruction_check_switch_prongs(ira, (IrInstructionCheckSwitchProngs *)instruction);
        case IrInstructionIdTestType:
            return ir_analyze_instruction_test_type(ira, (IrInstructionTestType *)instruction);
        case IrInstructionIdCanImplicitCast:
            return ir_analyze_instruction_can_implicit_cast(ira, (IrInstructionCanImplicitCast *)instruction);
        case IrInstructionIdDeclRef:
            return ir_analyze_instruction_decl_ref(ira, (IrInstructionDeclRef *)instruction);
        case IrInstructionIdPanic:
            return ir_analyze_instruction_panic(ira, (IrInstructionPanic *)instruction);
        case IrInstructionIdPtrCast:
            return ir_analyze_instruction_ptr_cast(ira, (IrInstructionPtrCast *)instruction);
        case IrInstructionIdIntToPtr:
            return ir_analyze_instruction_int_to_ptr(ira, (IrInstructionIntToPtr *)instruction);
        case IrInstructionIdEnumTagName:
            return ir_analyze_instruction_enum_tag_name(ira, (IrInstructionEnumTagName *)instruction);
        case IrInstructionIdSetFnRefInline:
            return ir_analyze_instruction_set_fn_ref_inline(ira, (IrInstructionSetFnRefInline *)instruction);
        case IrInstructionIdMaybeWrap:
        case IrInstructionIdErrWrapCode:
        case IrInstructionIdErrWrapPayload:
        case IrInstructionIdCast:
            zig_panic("TODO analyze more instructions");
    }
    zig_unreachable();
}

static TypeTableEntry *ir_analyze_instruction(IrAnalyze *ira, IrInstruction *instruction) {
    TypeTableEntry *instruction_type = ir_analyze_instruction_nocast(ira, instruction);
    instruction->value.type = instruction_type;
    if (instruction->other) {
        instruction->other->value.type = instruction_type;
    } else {
        assert(instruction_type->id == TypeTableEntryIdInvalid ||
               instruction_type->id == TypeTableEntryIdUnreachable);
        instruction->other = instruction;
    }
    if (instruction_type->id != TypeTableEntryIdInvalid &&
        instruction_type->id != TypeTableEntryIdVoid &&
        instruction_type->id != TypeTableEntryIdUnreachable &&
        instruction->ref_count == 0)
    {
        ir_add_error(ira, instruction, buf_sprintf("return value ignored"));
    }

    return instruction_type;
}

// This function attempts to evaluate IR code while doing type checking and other analysis.
// It emits a new IrExecutable which is partially evaluated IR code.
TypeTableEntry *ir_analyze(CodeGen *codegen, IrExecutable *old_exec, IrExecutable *new_exec,
        TypeTableEntry *expected_type, AstNode *expected_type_source_node)
{
    assert(!old_exec->invalid);

    IrAnalyze ir_analyze_data = {};
    IrAnalyze *ira = &ir_analyze_data;
    ira->codegen = codegen;
    ira->explicit_return_type = expected_type;

    ira->old_irb.codegen = codegen;
    ira->old_irb.exec = old_exec;

    ira->new_irb.codegen = codegen;
    ira->new_irb.exec = new_exec;

    ira->exec_context.mem_slot_count = ira->old_irb.exec->mem_slot_count;
    ira->exec_context.mem_slot_list = allocate<ConstExprValue>(ira->exec_context.mem_slot_count);

    IrBasicBlock *old_entry_bb = ira->old_irb.exec->basic_block_list.at(0);
    IrBasicBlock *new_entry_bb = ir_get_new_bb(ira, old_entry_bb, nullptr);
    ir_ref_bb(new_entry_bb);
    ira->new_irb.current_basic_block = new_entry_bb;
    ira->block_queue_index = 0;

    ir_start_bb(ira, old_entry_bb, nullptr);

    while (ira->block_queue_index < ira->old_bb_queue.length) {
        IrInstruction *old_instruction = ira->old_irb.current_basic_block->instruction_list.at(ira->instruction_index);

        if (old_instruction->ref_count == 0 && !ir_has_side_effects(old_instruction)) {
            ira->instruction_index += 1;
            continue;
        }

        TypeTableEntry *return_type = ir_analyze_instruction(ira, old_instruction);

        // unreachable instructions do their own control flow.
        if (return_type->id == TypeTableEntryIdUnreachable)
            continue;

        ira->instruction_index += 1;
    }

    if (new_exec->invalid) {
        return ira->codegen->builtin_types.entry_invalid;
    } else if (ira->implicit_return_type_list.length == 0) {
        return codegen->builtin_types.entry_unreachable;
    } else {
        return ir_resolve_peer_types(ira, expected_type_source_node, ira->implicit_return_type_list.items,
                ira->implicit_return_type_list.length);
    }
}

bool ir_has_side_effects(IrInstruction *instruction) {
    switch (instruction->id) {
        case IrInstructionIdInvalid:
            zig_unreachable();
        case IrInstructionIdBr:
        case IrInstructionIdCondBr:
        case IrInstructionIdSwitchBr:
        case IrInstructionIdDeclVar:
        case IrInstructionIdStorePtr:
        case IrInstructionIdCall:
        case IrInstructionIdReturn:
        case IrInstructionIdUnreachable:
        case IrInstructionIdSetDebugSafety:
        case IrInstructionIdImport:
        case IrInstructionIdCompileErr:
        case IrInstructionIdCompileLog:
        case IrInstructionIdCImport:
        case IrInstructionIdCInclude:
        case IrInstructionIdCDefine:
        case IrInstructionIdCUndef:
        case IrInstructionIdCmpxchg:
        case IrInstructionIdFence:
        case IrInstructionIdMemset:
        case IrInstructionIdMemcpy:
        case IrInstructionIdBreakpoint:
        case IrInstructionIdOverflowOp: // TODO when we support multiple returns this can be side effect free
        case IrInstructionIdCheckSwitchProngs:
        case IrInstructionIdSetGlobalAlign:
        case IrInstructionIdSetGlobalSection:
        case IrInstructionIdSetGlobalLinkage:
        case IrInstructionIdPanic:
            return true;
        case IrInstructionIdPhi:
        case IrInstructionIdUnOp:
        case IrInstructionIdBinOp:
        case IrInstructionIdLoadPtr:
        case IrInstructionIdConst:
        case IrInstructionIdCast:
        case IrInstructionIdContainerInitList:
        case IrInstructionIdContainerInitFields:
        case IrInstructionIdStructInit:
        case IrInstructionIdFieldPtr:
        case IrInstructionIdElemPtr:
        case IrInstructionIdVarPtr:
        case IrInstructionIdTypeOf:
        case IrInstructionIdToPtrType:
        case IrInstructionIdPtrTypeChild:
        case IrInstructionIdArrayLen:
        case IrInstructionIdStructFieldPtr:
        case IrInstructionIdEnumFieldPtr:
        case IrInstructionIdArrayType:
        case IrInstructionIdSliceType:
        case IrInstructionIdCompileVar:
        case IrInstructionIdSizeOf:
        case IrInstructionIdTestNonNull:
        case IrInstructionIdUnwrapMaybe:
        case IrInstructionIdClz:
        case IrInstructionIdCtz:
        case IrInstructionIdSwitchVar:
        case IrInstructionIdSwitchTarget:
        case IrInstructionIdEnumTag:
        case IrInstructionIdGeneratedCode:
        case IrInstructionIdRef:
        case IrInstructionIdMinValue:
        case IrInstructionIdMaxValue:
        case IrInstructionIdEmbedFile:
        case IrInstructionIdDivExact:
        case IrInstructionIdTruncate:
        case IrInstructionIdIntType:
        case IrInstructionIdBoolNot:
        case IrInstructionIdSlice:
        case IrInstructionIdMemberCount:
        case IrInstructionIdAlignOf:
        case IrInstructionIdReturnAddress:
        case IrInstructionIdFrameAddress:
        case IrInstructionIdTestErr:
        case IrInstructionIdUnwrapErrCode:
        case IrInstructionIdMaybeWrap:
        case IrInstructionIdErrWrapCode:
        case IrInstructionIdErrWrapPayload:
        case IrInstructionIdFnProto:
        case IrInstructionIdTestComptime:
        case IrInstructionIdInitEnum:
        case IrInstructionIdPtrCast:
        case IrInstructionIdWidenOrShorten:
        case IrInstructionIdPtrToInt:
        case IrInstructionIdIntToPtr:
        case IrInstructionIdIntToEnum:
        case IrInstructionIdIntToErr:
        case IrInstructionIdErrToInt:
        case IrInstructionIdTestType:
        case IrInstructionIdCanImplicitCast:
        case IrInstructionIdDeclRef:
        case IrInstructionIdErrName:
        case IrInstructionIdTypeName:
        case IrInstructionIdEnumTagName:
        case IrInstructionIdSetFnRefInline:
            return false;
        case IrInstructionIdAsm:
            {
                IrInstructionAsm *asm_instruction = (IrInstructionAsm *)instruction;
                return asm_instruction->has_side_effects;
            }
        case IrInstructionIdUnwrapErrPayload:
            {
                IrInstructionUnwrapErrPayload *unwrap_err_payload_instruction =
                    (IrInstructionUnwrapErrPayload *)instruction;
                return unwrap_err_payload_instruction->safety_check_on;
            }
    }
    zig_unreachable();
}

FnTableEntry *ir_create_inline_fn(CodeGen *codegen, Buf *fn_name, VariableTableEntry *var, Scope *parent_scope) {
    FnTableEntry *fn_entry = create_fn_raw(FnInlineAuto, GlobalLinkageIdInternal);
    buf_init_from_buf(&fn_entry->symbol_name, fn_name);

    fn_entry->fndef_scope = create_fndef_scope(nullptr, parent_scope, fn_entry);
    fn_entry->child_scope = &fn_entry->fndef_scope->base;

    assert(var->value->type->id == TypeTableEntryIdMaybe);
    TypeTableEntry *src_fn_type = var->value->type->data.maybe.child_type;
    assert(src_fn_type->id == TypeTableEntryIdFn);

    FnTypeId new_fn_type = src_fn_type->data.fn.fn_type_id;
    new_fn_type.is_extern = false;

    fn_entry->type_entry = get_fn_type(codegen, &new_fn_type);

    IrBuilder ir_builder = {0};
    IrBuilder *irb = &ir_builder;

    irb->codegen = codegen;
    irb->exec = &fn_entry->ir_executable;

    AstNode *source_node = parent_scope->source_node;

    size_t arg_count = fn_entry->type_entry->data.fn.fn_type_id.param_count;
    IrInstruction **args = allocate<IrInstruction *>(arg_count);
    VariableTableEntry **arg_vars = allocate<VariableTableEntry *>(arg_count);

    define_local_param_variables(codegen, fn_entry, arg_vars);
    Scope *scope = fn_entry->child_scope;

    irb->current_basic_block = ir_build_basic_block(irb, scope, "Entry");
    // Entry block gets a reference because we enter it to begin.
    ir_ref_bb(irb->current_basic_block);

    IrInstruction *maybe_fn_ptr = ir_build_var_ptr(irb, scope, source_node, var, true, false);
    IrInstruction *unwrapped_fn_ptr = ir_build_unwrap_maybe(irb, scope, source_node, maybe_fn_ptr, true);
    IrInstruction *fn_ref_instruction = ir_build_load_ptr(irb, scope, source_node, unwrapped_fn_ptr);

    for (size_t i = 0; i < arg_count; i += 1) {
        IrInstruction *var_ptr_instruction = ir_build_var_ptr(irb, scope, source_node, arg_vars[i], true, false);
        args[i] = ir_build_load_ptr(irb, scope, source_node, var_ptr_instruction);
    }

    IrInstruction *call_instruction = ir_build_call(irb, scope, source_node, nullptr, fn_ref_instruction,
            arg_count, args, false, false);
    ir_build_return(irb, scope, source_node, call_instruction);

    if (codegen->verbose) {
        fprintf(stderr, "{\n");
        ir_print(stderr, &fn_entry->ir_executable, 4);
        fprintf(stderr, "}\n");
    }

    analyze_fn_ir(codegen, fn_entry, nullptr);

    codegen->fn_defs.append(fn_entry);

    return fn_entry;
}

