/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_IR_PRINT_HPP
#define ZIG_IR_PRINT_HPP

#include "all_types.hpp"

#include <stdio.h>

void ir_print(CodeGen *codegen, FILE *f, IrExecutable *executable, int indent_size, IrPass pass);
void ir_print_instruction(CodeGen *codegen, FILE *f, IrInstruction *instruction, int indent_size, IrPass pass);
void ir_print_const_expr(CodeGen *codegen, FILE *f, ZigValue *value, int indent_size, IrPass pass);
void ir_print_basic_block(CodeGen *codegen, FILE *f, IrBasicBlock *bb, int indent_size, IrPass pass);

const char* ir_instruction_type_str(IrInstructionId id);

#endif
