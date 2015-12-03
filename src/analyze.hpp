/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ANALYZE_HPP
#define ZIG_ANALYZE_HPP

struct CodeGen;
struct AstNode;
struct Buf;

struct TypeTableEntry;
struct LocalVariableTableEntry;
struct BlockContext;

void semantic_analyze(CodeGen *g);
void add_node_error(CodeGen *g, AstNode *node, Buf *msg);
TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const);
LocalVariableTableEntry *find_local_variable(BlockContext *context, Buf *name);

#endif
