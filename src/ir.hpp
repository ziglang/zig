/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_IR_HPP
#define ZIG_IR_HPP

#include "all_types.hpp"

struct IrInstruction;

// A basic block contains no branching. Branches send control flow
// to another basic block.
// Phi instructions must be first in a basic block.
// The last instruction in a basic block must be an expression of type unreachable.
struct IrBasicBlock {
    ZigList<IrInstruction *> instructions;
};

enum IrInstructionId {
    IrInstructionIdCondBr,
    IrInstructionIdSwitchBr,
    IrInstructionIdPhi,
    IrInstructionIdAdd,
    IrInstructionIdBinOp,
    IrInstructionIdLoadVar,
    IrInstructionIdStoreVar,
    IrInstructionIdCall,
    IrInstructionIdBuiltinCall,
    IrInstructionIdConst,
    IrInstructionIdReturn,
};

struct IrInstruction {
    IrInstructionId id;
    AstNode *source_node;
    ConstExprValue static_value;
    TypeTableEntry *type_entry;
};

struct IrInstructionCondBr {
    IrInstruction base;

    // If the condition is null, then this is an unconditional branch.
    IrInstruction *cond;
    IrBasicBlock *dest;
};

struct IrInstructionSwitchBrCase {
    IrInstruction *value;
    IrBasicBlock *block;
};

struct IrInstructionSwitchBr {
    IrInstruction base;

    IrInstruction *target_value;
    IrBasicBlock *else_block;
    size_t case_count;
    IrInstructionSwitchBrCase *cases;
};

struct IrInstructionPhi {
    IrInstruction base;

    size_t incoming_block_count;
    IrBasicBlock **incoming_blocks;
    IrInstruction **incoming_values;
};

enum IrBinOp {
    IrBinOpInvalid,
    IrBinOpBoolOr,
    IrBinOpBoolAnd,
    IrBinOpCmpEq,
    IrBinOpCmpNotEq,
    IrBinOpCmpLessThan,
    IrBinOpCmpGreaterThan,
    IrBinOpCmpLessOrEq,
    IrBinOpCmpGreaterOrEq,
    IrBinOpBinOr,
    IrBinOpBinXor,
    IrBinOpBinAnd,
    IrBinOpBitShiftLeft,
    IrBinOpBitShiftLeftWrap,
    IrBinOpBitShiftRight,
    IrBinOpAdd,
    IrBinOpAddWrap,
    IrBinOpSub,
    IrBinOpSubWrap,
    IrBinOpMult,
    IrBinOpMultWrap,
    IrBinOpDiv,
    IrBinOpMod,
    IrBinOpArrayCat,
    IrBinOpArrayMult,
};

struct IrInstructionBinOp {
    IrInstruction base;

    IrInstruction *op1;
    IrBinOp op_id;
    IrInstruction *op2;
};

struct IrInstructionLoadVar {
    IrInstruction base;

    VariableTableEntry *var;
};

struct IrInstructionStoreVar {
    IrInstruction base;

    IrInstruction *value;
    VariableTableEntry *var;
};

struct IrInstructionCall {
    IrInstruction base;

    IrInstruction *fn;
    size_t arg_count;
    IrInstruction **args;
};

struct IrInstructionBuiltinCall {
    IrInstruction base;

    BuiltinFnId fn_id;
    size_t arg_count;
    IrInstruction **args;
};

struct IrInstructionConst {
    IrInstruction base;
};

struct IrInstructionReturn {
    IrInstruction base;

    IrInstruction *value;
};

IrBasicBlock *ir_gen(CodeGen *g, AstNode *fn_def_node, TypeTableEntry *return_type);
TypeTableEntry *ir_analyze(CodeGen *g, AstNode *fn_def_node, IrBasicBlock *entry_basic_block,
        TypeTableEntry *expected_type);

#endif
