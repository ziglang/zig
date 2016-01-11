/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ANALYZE_HPP
#define ZIG_ANALYZE_HPP

#include "all_types.hpp"

void semantic_analyze(CodeGen *g);
void add_node_error(CodeGen *g, AstNode *node, Buf *msg);
TypeTableEntry *new_type_table_entry(TypeTableEntryId id);
TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const, bool is_noalias);
VariableTableEntry *find_variable(BlockContext *context, Buf *name);
TypeTableEntry *find_container(BlockContext *context, Buf *name);
BlockContext *new_block_context(AstNode *node, BlockContext *parent);
Expr *get_resolved_expr(AstNode *node);
NumLitCodeGen *get_resolved_num_lit(AstNode *node);
TopLevelDecl *get_resolved_top_level_decl(AstNode *node);

#endif
