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

void ir_print_src(CodeGen *codegen, FILE *f, IrExecutableSrc *executable, int indent_size);
void ir_print_gen(CodeGen *codegen, FILE *f, IrExecutableGen *executable, int indent_size);
void ir_print_inst_src(CodeGen *codegen, FILE *f, IrInstSrc *inst, int indent_size);
void ir_print_inst_gen(CodeGen *codegen, FILE *f, IrInstGen *inst, int indent_size);
void ir_print_basic_block_src(CodeGen *codegen, FILE *f, IrBasicBlockSrc *bb, int indent_size);
void ir_print_basic_block_gen(CodeGen *codegen, FILE *f, IrBasicBlockGen *bb, int indent_size);

const char* ir_inst_src_type_str(IrInstSrcId id);
const char* ir_inst_gen_type_str(IrInstGenId id);

#endif
