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

void semantic_analyze(CodeGen *g);
void add_node_error(CodeGen *g, AstNode *node, Buf *msg);

#endif
