/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_PARSER_HPP
#define ZIG_PARSER_HPP

#include "all_types.hpp"
#include "tokenizer.hpp"
#include "errmsg.hpp"

AstNode * ast_parse(Buf *buf, ZigType *owner, ErrColor err_color);

void ast_print(AstNode *node, int indent);

void ast_visit_node_children(AstNode *node, void (*visit)(AstNode **, void *context), void *context);

Buf *node_identifier_buf(AstNode *node);

Buf *token_identifier_buf(RootStruct *root_struct, TokenIndex token);

void token_number_literal_bigint(RootStruct *root_struct, BigInt *result, TokenIndex token);

Error source_string_literal_buf(const char *source, Buf *out, size_t *bad_index);
Error source_char_literal(const char *source, uint32_t *out, size_t *bad_index);

#endif
