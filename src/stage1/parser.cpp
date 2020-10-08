/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "parser.hpp"
#include "errmsg.hpp"
#include "analyze.hpp"

#include <stdarg.h>
#include <stdio.h>
#include <limits.h>
#include <errno.h>

struct ParseContext {
    Buf *buf;
    size_t current_token;
    ZigList<Token> *tokens;
    ZigType *owner;
    ErrColor err_color;
};

struct PtrPayload {
    Token *asterisk;
    Token *payload;
};

struct PtrIndexPayload {
    Token *asterisk;
    Token *payload;
    Token *index;
};

static AstNode *ast_parse_root(ParseContext *pc);
static AstNodeContainerDecl ast_parse_container_members(ParseContext *pc);
static AstNode *ast_parse_test_decl(ParseContext *pc);
static AstNode *ast_parse_top_level_comptime(ParseContext *pc);
static AstNode *ast_parse_top_level_decl(ParseContext *pc, VisibMod visib_mod, Buf *doc_comments);
static AstNode *ast_parse_fn_proto(ParseContext *pc);
static AstNode *ast_parse_var_decl(ParseContext *pc);
static AstNode *ast_parse_container_field(ParseContext *pc);
static AstNode *ast_parse_statement(ParseContext *pc);
static AstNode *ast_parse_if_statement(ParseContext *pc);
static AstNode *ast_parse_labeled_statement(ParseContext *pc);
static AstNode *ast_parse_loop_statement(ParseContext *pc);
static AstNode *ast_parse_for_statement(ParseContext *pc);
static AstNode *ast_parse_while_statement(ParseContext *pc);
static AstNode *ast_parse_block_expr_statement(ParseContext *pc);
static AstNode *ast_parse_block_expr(ParseContext *pc);
static AstNode *ast_parse_assign_expr(ParseContext *pc);
static AstNode *ast_parse_expr(ParseContext *pc);
static AstNode *ast_parse_bool_or_expr(ParseContext *pc);
static AstNode *ast_parse_bool_and_expr(ParseContext *pc);
static AstNode *ast_parse_compare_expr(ParseContext *pc);
static AstNode *ast_parse_bitwise_expr(ParseContext *pc);
static AstNode *ast_parse_bit_shift_expr(ParseContext *pc);
static AstNode *ast_parse_addition_expr(ParseContext *pc);
static AstNode *ast_parse_multiply_expr(ParseContext *pc);
static AstNode *ast_parse_prefix_expr(ParseContext *pc);
static AstNode *ast_parse_primary_expr(ParseContext *pc);
static AstNode *ast_parse_if_expr(ParseContext *pc);
static AstNode *ast_parse_block(ParseContext *pc);
static AstNode *ast_parse_loop_expr(ParseContext *pc);
static AstNode *ast_parse_for_expr(ParseContext *pc);
static AstNode *ast_parse_while_expr(ParseContext *pc);
static AstNode *ast_parse_curly_suffix_expr(ParseContext *pc);
static AstNode *ast_parse_init_list(ParseContext *pc);
static AstNode *ast_parse_type_expr(ParseContext *pc);
static AstNode *ast_parse_error_union_expr(ParseContext *pc);
static AstNode *ast_parse_suffix_expr(ParseContext *pc);
static AstNode *ast_parse_primary_type_expr(ParseContext *pc);
static AstNode *ast_parse_container_decl(ParseContext *pc);
static AstNode *ast_parse_error_set_decl(ParseContext *pc);
static AstNode *ast_parse_grouped_expr(ParseContext *pc);
static AstNode *ast_parse_if_type_expr(ParseContext *pc);
static AstNode *ast_parse_labeled_type_expr(ParseContext *pc);
static AstNode *ast_parse_loop_type_expr(ParseContext *pc);
static AstNode *ast_parse_for_type_expr(ParseContext *pc);
static AstNode *ast_parse_while_type_expr(ParseContext *pc);
static AstNode *ast_parse_switch_expr(ParseContext *pc);
static AstNode *ast_parse_asm_expr(ParseContext *pc);
static AstNode *ast_parse_anon_lit(ParseContext *pc);
static AstNode *ast_parse_asm_output(ParseContext *pc);
static AsmOutput *ast_parse_asm_output_item(ParseContext *pc);
static AstNode *ast_parse_asm_input(ParseContext *pc);
static AsmInput *ast_parse_asm_input_item(ParseContext *pc);
static AstNode *ast_parse_asm_clobbers(ParseContext *pc);
static Token *ast_parse_break_label(ParseContext *pc);
static Token *ast_parse_block_label(ParseContext *pc);
static AstNode *ast_parse_field_init(ParseContext *pc);
static AstNode *ast_parse_while_continue_expr(ParseContext *pc);
static AstNode *ast_parse_link_section(ParseContext *pc);
static AstNode *ast_parse_callconv(ParseContext *pc);
static AstNode *ast_parse_param_decl(ParseContext *pc);
static AstNode *ast_parse_param_type(ParseContext *pc);
static AstNode *ast_parse_if_prefix(ParseContext *pc);
static AstNode *ast_parse_while_prefix(ParseContext *pc);
static AstNode *ast_parse_for_prefix(ParseContext *pc);
static Token *ast_parse_payload(ParseContext *pc);
static Optional<PtrPayload> ast_parse_ptr_payload(ParseContext *pc);
static Optional<PtrIndexPayload> ast_parse_ptr_index_payload(ParseContext *pc);
static AstNode *ast_parse_switch_prong(ParseContext *pc);
static AstNode *ast_parse_switch_case(ParseContext *pc);
static AstNode *ast_parse_switch_item(ParseContext *pc);
static AstNode *ast_parse_assign_op(ParseContext *pc);
static AstNode *ast_parse_compare_op(ParseContext *pc);
static AstNode *ast_parse_bitwise_op(ParseContext *pc);
static AstNode *ast_parse_bit_shift_op(ParseContext *pc);
static AstNode *ast_parse_addition_op(ParseContext *pc);
static AstNode *ast_parse_multiply_op(ParseContext *pc);
static AstNode *ast_parse_prefix_op(ParseContext *pc);
static AstNode *ast_parse_prefix_type_op(ParseContext *pc);
static AstNode *ast_parse_suffix_op(ParseContext *pc);
static AstNode *ast_parse_fn_call_arguments(ParseContext *pc);
static AstNode *ast_parse_array_type_start(ParseContext *pc);
static AstNode *ast_parse_ptr_type_start(ParseContext *pc);
static AstNode *ast_parse_container_decl_auto(ParseContext *pc);
static AstNode *ast_parse_container_decl_type(ParseContext *pc);
static AstNode *ast_parse_byte_align(ParseContext *pc);

ATTRIBUTE_PRINTF(3, 4)
ATTRIBUTE_NORETURN
static void ast_error(ParseContext *pc, Token *token, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);


    ErrorMsg *err = err_msg_create_with_line(pc->owner->data.structure.root_struct->path,
            token->start_line, token->start_column,
            pc->owner->data.structure.root_struct->source_code,
            pc->owner->data.structure.root_struct->line_offsets, msg);
    err->line_start = token->start_line;
    err->column_start = token->start_column;

    print_err_msg(err, pc->err_color);
    exit(EXIT_FAILURE);
}

ATTRIBUTE_NORETURN
static void ast_invalid_token_error(ParseContext *pc, Token *token) {
    ast_error(pc, token, "invalid token: '%s'", token_name(token->id));
}

static AstNode *ast_create_node_no_line_info(ParseContext *pc, NodeType type) {
    AstNode *node = heap::c_allocator.create<AstNode>();
    node->type = type;
    node->owner = pc->owner;
    return node;
}

static AstNode *ast_create_node(ParseContext *pc, NodeType type, Token *first_token) {
    assert(first_token);
    AstNode *node = ast_create_node_no_line_info(pc, type);
    node->line = first_token->start_line;
    node->column = first_token->start_column;
    return node;
}

static AstNode *ast_create_node_copy_line_info(ParseContext *pc, NodeType type, AstNode *from) {
    assert(from);
    AstNode *node = ast_create_node_no_line_info(pc, type);
    node->line = from->line;
    node->column = from->column;
    return node;
}

static Token *peek_token_i(ParseContext *pc, size_t i) {
    return &pc->tokens->at(pc->current_token + i);
}

static Token *peek_token(ParseContext *pc) {
    return peek_token_i(pc, 0);
}

static Token *eat_token(ParseContext *pc) {
    Token *res = peek_token(pc);
    pc->current_token += 1;
    return res;
}

static Token *eat_token_if(ParseContext *pc, TokenId id) {
    Token *res = peek_token(pc);
    if (res->id == id)
        return eat_token(pc);

    return nullptr;
}

static Token *expect_token(ParseContext *pc, TokenId id) {
    Token *res = eat_token(pc);
    if (res->id != id)
        ast_error(pc, res, "expected token '%s', found '%s'", token_name(id), token_name(res->id));

    return res;
}

static void put_back_token(ParseContext *pc) {
    pc->current_token -= 1;
}

static Buf *token_buf(Token *token) {
    if (token == nullptr)
        return nullptr;
    assert(token->id == TokenIdStringLiteral || token->id == TokenIdMultilineStringLiteral || token->id == TokenIdSymbol);
    return &token->data.str_lit.str;
}

static BigInt *token_bigint(Token *token) {
    assert(token->id == TokenIdIntLiteral);
    return &token->data.int_lit.bigint;
}

static AstNode *token_symbol(ParseContext *pc, Token *token) {
    assert(token->id == TokenIdSymbol);
    AstNode *res = ast_create_node(pc, NodeTypeSymbol, token);
    res->data.symbol_expr.symbol = token_buf(token);
    return res;
}

// (Rule SEP)* Rule?
template<typename T>
static ZigList<T *> ast_parse_list(ParseContext *pc, TokenId sep, T *(*parser)(ParseContext*)) {
    ZigList<T *> res = {};
    while (true) {
        T *curr = parser(pc);
        if (curr == nullptr)
            break;

        res.append(curr);
        if (eat_token_if(pc, sep) == nullptr)
            break;
    }

    return res;
}

static AstNode *ast_expect(ParseContext *pc, AstNode *(*parser)(ParseContext*)) {
    AstNode *res = parser(pc);
    if (res == nullptr)
        ast_invalid_token_error(pc, peek_token(pc));
    return res;
}

enum BinOpChain {
    BinOpChainOnce,
    BinOpChainInf,
};

// Op* Child
static AstNode *ast_parse_prefix_op_expr(
    ParseContext *pc,
    AstNode *(*op_parser)(ParseContext *),
    AstNode *(*child_parser)(ParseContext *)
) {
    AstNode *res = nullptr;
    AstNode **right = &res;
    while (true) {
        AstNode *prefix = op_parser(pc);
        if (prefix == nullptr)
            break;

        *right = prefix;
        switch (prefix->type) {
            case NodeTypePrefixOpExpr:
                right = &prefix->data.prefix_op_expr.primary_expr;
                break;
            case NodeTypeReturnExpr:
                right = &prefix->data.return_expr.expr;
                break;
            case NodeTypeAwaitExpr:
                right = &prefix->data.await_expr.expr;
                break;
            case NodeTypeAnyFrameType:
                right = &prefix->data.anyframe_type.payload_type;
                break;
            case NodeTypeArrayType:
                right = &prefix->data.array_type.child_type;
                break;
            case NodeTypeInferredArrayType:
                right = &prefix->data.inferred_array_type.child_type;
                break;
            case NodeTypePointerType: {
                // We might get two pointers from *_ptr_type_start
                AstNode *child = prefix->data.pointer_type.op_expr;
                if (child == nullptr)
                    child = prefix;
                right = &child->data.pointer_type.op_expr;
                break;
            }
            default:
                zig_unreachable();
        }
    }

    // If we have already consumed a token, and determined that
    // this node is a prefix op, then we expect that the node has
    // a child.
    if (res != nullptr) {
        *right = ast_expect(pc, child_parser);
    } else {
        // Otherwise, if we didn't consume a token, then we can return
        // null, if the child expr did.
        *right = child_parser(pc);
        if (*right == nullptr)
            return nullptr;
    }

    return res;
}

// Child (Op Child)(*/?)
static AstNode *ast_parse_bin_op_expr(
    ParseContext *pc,
    BinOpChain chain,
    AstNode *(*op_parse)(ParseContext*),
    AstNode *(*child_parse)(ParseContext*)
) {
    AstNode *res = child_parse(pc);
    if (res == nullptr)
        return nullptr;

    do {
        AstNode *op = op_parse(pc);
        if (op == nullptr)
            break;

        AstNode *left = res;
        AstNode *right = ast_expect(pc, child_parse);
        res = op;
        switch (op->type) {
            case NodeTypeBinOpExpr:
                op->data.bin_op_expr.op1 = left;
                op->data.bin_op_expr.op2 = right;
                break;
            case NodeTypeCatchExpr:
                op->data.unwrap_err_expr.op1 = left;
                op->data.unwrap_err_expr.op2 = right;
                break;
            default:
                zig_unreachable();
        }
    } while (chain == BinOpChainInf);

    return res;
}

// IfPrefix Body (KEYWORD_else Payload? Body)?
static AstNode *ast_parse_if_expr_helper(ParseContext *pc, AstNode *(*body_parser)(ParseContext*)) {
    AstNode *res = ast_parse_if_prefix(pc);
    if (res == nullptr)
        return nullptr;

    AstNode *body = ast_expect(pc, body_parser);
    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, body_parser);
    }

    assert(res->type == NodeTypeIfOptional);
    if (err_payload != nullptr) {
        AstNodeTestExpr old = res->data.test_expr;
        res->type = NodeTypeIfErrorExpr;
        res->data.if_err_expr.target_node = old.target_node;
        res->data.if_err_expr.var_is_ptr = old.var_is_ptr;
        res->data.if_err_expr.var_symbol = old.var_symbol;
        res->data.if_err_expr.then_node = body;
        res->data.if_err_expr.err_symbol = token_buf(err_payload);
        res->data.if_err_expr.else_node = else_body;
        return res;
    }

    if (res->data.test_expr.var_symbol != nullptr) {
        res->data.test_expr.then_node = body;
        res->data.test_expr.else_node = else_body;
        return res;
    }

    AstNodeTestExpr old = res->data.test_expr;
    res->type = NodeTypeIfBoolExpr;
    res->data.if_bool_expr.condition = old.target_node;
    res->data.if_bool_expr.then_block = body;
    res->data.if_bool_expr.else_node = else_body;
    return res;
}

// KEYWORD_inline? (ForLoop / WhileLoop)
static AstNode *ast_parse_loop_expr_helper(
    ParseContext *pc,
    AstNode *(*for_parser)(ParseContext *),
    AstNode *(*while_parser)(ParseContext *)
) {
    Token *inline_token = eat_token_if(pc, TokenIdKeywordInline);
    AstNode *for_expr = for_parser(pc);
    if (for_expr != nullptr) {
        assert(for_expr->type == NodeTypeForExpr);
        for_expr->data.for_expr.is_inline = inline_token != nullptr;
        return for_expr;
    }

    AstNode *while_expr = while_parser(pc);
    if (while_expr != nullptr) {
        assert(while_expr->type == NodeTypeWhileExpr);
        while_expr->data.while_expr.is_inline = inline_token != nullptr;
        return while_expr;
    }

    if (inline_token != nullptr)
        ast_invalid_token_error(pc, peek_token(pc));
    return nullptr;
}

// ForPrefix Body (KEYWORD_else Body)?
static AstNode *ast_parse_for_expr_helper(ParseContext *pc, AstNode *(*body_parser)(ParseContext*)) {
    AstNode *res = ast_parse_for_prefix(pc);
    if (res == nullptr)
        return nullptr;

    AstNode *body = ast_expect(pc, body_parser);
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr)
        else_body = ast_expect(pc, body_parser);

    assert(res->type == NodeTypeForExpr);
    res->data.for_expr.body = body;
    res->data.for_expr.else_node = else_body;
    return res;
}

// WhilePrefix Body (KEYWORD_else Payload? Body)?
static AstNode *ast_parse_while_expr_helper(ParseContext *pc, AstNode *(*body_parser)(ParseContext*)) {
    AstNode *res = ast_parse_while_prefix(pc);
    if (res == nullptr)
        return nullptr;

    AstNode *body = ast_expect(pc, body_parser);
    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, body_parser);
    }

    assert(res->type == NodeTypeWhileExpr);
    res->data.while_expr.body = body;
    res->data.while_expr.err_symbol = token_buf(err_payload);
    res->data.while_expr.else_node = else_body;
    return res;
}

template<TokenId id, BinOpType op>
AstNode *ast_parse_bin_op_simple(ParseContext *pc) {
    Token *op_token = eat_token_if(pc, id);
    if (op_token == nullptr)
        return nullptr;

    AstNode *res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
    res->data.bin_op_expr.bin_op = op;
    return res;
}

AstNode *ast_parse(Buf *buf, ZigList<Token> *tokens, ZigType *owner, ErrColor err_color) {
    ParseContext pc = {};
    pc.err_color = err_color;
    pc.owner = owner;
    pc.buf = buf;
    pc.tokens = tokens;
    return ast_parse_root(&pc);
}

// Root <- skip ContainerMembers eof
static AstNode *ast_parse_root(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeContainerDecl members = ast_parse_container_members(pc);
    if (pc->current_token != pc->tokens->length - 1)
        ast_invalid_token_error(pc, peek_token(pc));

    AstNode *node = ast_create_node(pc, NodeTypeContainerDecl, first);
    node->data.container_decl.fields = members.fields;
    node->data.container_decl.decls = members.decls;
    node->data.container_decl.layout = ContainerLayoutAuto;
    node->data.container_decl.kind = ContainerKindStruct;
    node->data.container_decl.is_root = true;
    if (buf_len(&members.doc_comments) != 0) {
        node->data.container_decl.doc_comments = members.doc_comments;
    }

    return node;
}

static Token *ast_parse_doc_comments(ParseContext *pc, Buf *buf) {
    Token *first_doc_token = nullptr;
    Token *doc_token = nullptr;
    while ((doc_token = eat_token_if(pc, TokenIdDocComment))) {
        if (first_doc_token == nullptr) {
            first_doc_token = doc_token;
        }
        if (buf->list.length == 0) {
            buf_resize(buf, 0);
        }
        // chops off '///' but leaves '\n'
        buf_append_mem(buf, buf_ptr(pc->buf) + doc_token->start_pos + 3,
                doc_token->end_pos - doc_token->start_pos - 3);
    }
    return first_doc_token;
}

static void ast_parse_container_doc_comments(ParseContext *pc, Buf *buf) {
    if (buf_len(buf) != 0 && peek_token(pc)->id == TokenIdContainerDocComment) {
        buf_append_char(buf, '\n');
    }
    Token *doc_token = nullptr;
    while ((doc_token = eat_token_if(pc, TokenIdContainerDocComment))) {
        if (buf->list.length == 0) {
            buf_resize(buf, 0);
        }
        // chops off '//!' but leaves '\n'
        buf_append_mem(buf, buf_ptr(pc->buf) + doc_token->start_pos + 3,
                doc_token->end_pos - doc_token->start_pos - 3);
    }
}

enum ContainerFieldState {
    // no fields have been seen
    ContainerFieldStateNone,
    // currently parsing fields
    ContainerFieldStateSeen,
    // saw fields and then a declaration after them
    ContainerFieldStateEnd,
};

// ContainerMembers
//     <- TestDecl ContainerMembers
//      / TopLevelComptime ContainerMembers
//      / KEYWORD_pub? TopLevelDecl ContainerMembers
//      / ContainerField COMMA ContainerMembers
//      / ContainerField
//      /
static AstNodeContainerDecl ast_parse_container_members(ParseContext *pc) {
    AstNodeContainerDecl res = {};
    Buf tld_doc_comment_buf = BUF_INIT;
    buf_resize(&tld_doc_comment_buf, 0);
    ContainerFieldState field_state = ContainerFieldStateNone;
    Token *first_token = nullptr;
    for (;;) {
        ast_parse_container_doc_comments(pc, &tld_doc_comment_buf);

        Token *peeked_token = peek_token(pc);

        AstNode *test_decl = ast_parse_test_decl(pc);
        if (test_decl != nullptr) {
            if (field_state == ContainerFieldStateSeen) {
                field_state = ContainerFieldStateEnd;
                first_token = peeked_token;
            }
            res.decls.append(test_decl);
            continue;
        }

        AstNode *top_level_comptime = ast_parse_top_level_comptime(pc);
        if (top_level_comptime != nullptr) {
            if (field_state == ContainerFieldStateSeen) {
                field_state = ContainerFieldStateEnd;
                first_token = peeked_token;
            }
            res.decls.append(top_level_comptime);
            continue;
        }

        Buf doc_comment_buf = BUF_INIT;
        ast_parse_doc_comments(pc, &doc_comment_buf);

        peeked_token = peek_token(pc);

        Token *visib_token = eat_token_if(pc, TokenIdKeywordPub);
        VisibMod visib_mod = visib_token != nullptr ? VisibModPub : VisibModPrivate;

        AstNode *top_level_decl = ast_parse_top_level_decl(pc, visib_mod, &doc_comment_buf);
        if (top_level_decl != nullptr) {
            if (field_state == ContainerFieldStateSeen) {
                field_state = ContainerFieldStateEnd;
                first_token = peeked_token;
            }
            res.decls.append(top_level_decl);
            continue;
        }

        if (visib_token != nullptr) {
            ast_error(pc, peek_token(pc), "expected function or variable declaration after pub");
        }

        Token *comptime_token = eat_token_if(pc, TokenIdKeywordCompTime);

        AstNode *container_field = ast_parse_container_field(pc);
        if (container_field != nullptr) {
            switch (field_state) {
                case ContainerFieldStateNone:
                    field_state = ContainerFieldStateSeen;
                    break;
                case ContainerFieldStateSeen:
                    break;
                case ContainerFieldStateEnd:
                    ast_error(pc, first_token, "declarations are not allowed between container fields");                    
            }

            assert(container_field->type == NodeTypeStructField);
            container_field->data.struct_field.doc_comments = doc_comment_buf;
            container_field->data.struct_field.comptime_token = comptime_token;
            res.fields.append(container_field);
            if (eat_token_if(pc, TokenIdComma) != nullptr) {
                continue;
            } else {
                break;
            }
        }

        break;
    }
    res.doc_comments = tld_doc_comment_buf;
    return res;
}

// TestDecl <- KEYWORD_test STRINGLITERALSINGLE Block
static AstNode *ast_parse_test_decl(ParseContext *pc) {
    Token *test = eat_token_if(pc, TokenIdKeywordTest);
    if (test == nullptr)
        return nullptr;

    Token *name = expect_token(pc, TokenIdStringLiteral);
    AstNode *block = ast_expect(pc, ast_parse_block);
    AstNode *res = ast_create_node(pc, NodeTypeTestDecl, test);
    res->data.test_decl.name = token_buf(name);
    res->data.test_decl.body = block;
    return res;
}

// TopLevelComptime <- KEYWORD_comptime BlockExpr
static AstNode *ast_parse_top_level_comptime(ParseContext *pc) {
    Token *comptime = eat_token_if(pc, TokenIdKeywordCompTime);
    if (comptime == nullptr)
        return nullptr;

    // 1 token lookahead because it could be a comptime struct field
    Token *lbrace = peek_token(pc);
    if (lbrace->id != TokenIdLBrace) {
        put_back_token(pc);
        return nullptr;
    }

    AstNode *block = ast_expect(pc, ast_parse_block_expr);
    AstNode *res = ast_create_node(pc, NodeTypeCompTime, comptime);
    res->data.comptime_expr.expr = block;
    return res;
}

// TopLevelDecl
//     <- (KEYWORD_export / KEYWORD_extern STRINGLITERALSINGLE? / (KEYWORD_inline / KEYWORD_noinline))? FnProto (SEMICOLON / Block)
//      / (KEYWORD_export / KEYWORD_extern STRINGLITERALSINGLE?)? KEYWORD_threadlocal? VarDecl
//      / KEYWORD_use Expr SEMICOLON
static AstNode *ast_parse_top_level_decl(ParseContext *pc, VisibMod visib_mod, Buf *doc_comments) {
    Token *first = eat_token_if(pc, TokenIdKeywordExport);
    if (first == nullptr)
        first = eat_token_if(pc, TokenIdKeywordExtern);
    if (first == nullptr)
        first = eat_token_if(pc, TokenIdKeywordInline);
    if (first == nullptr)
        first = eat_token_if(pc, TokenIdKeywordNoInline);
    if (first != nullptr) {
        Token *lib_name = nullptr;
        if (first->id == TokenIdKeywordExtern)
            lib_name = eat_token_if(pc, TokenIdStringLiteral);

        if (first->id != TokenIdKeywordInline && first->id != TokenIdKeywordNoInline) {
            Token *thread_local_kw = eat_token_if(pc, TokenIdKeywordThreadLocal);
            AstNode *var_decl = ast_parse_var_decl(pc);
            if (var_decl != nullptr) {
                assert(var_decl->type == NodeTypeVariableDeclaration);
                if (first->id == TokenIdKeywordExtern && var_decl->data.variable_declaration.expr != nullptr) {
                    ast_error(pc, first, "extern variables have no initializers");
                }
                var_decl->line = first->start_line;
                var_decl->column = first->start_column;
                var_decl->data.variable_declaration.threadlocal_tok = thread_local_kw;
                var_decl->data.variable_declaration.visib_mod = visib_mod;
                var_decl->data.variable_declaration.doc_comments = *doc_comments;
                var_decl->data.variable_declaration.is_extern = first->id == TokenIdKeywordExtern;
                var_decl->data.variable_declaration.is_export = first->id == TokenIdKeywordExport;
                var_decl->data.variable_declaration.lib_name = token_buf(lib_name);
                return var_decl;
            }

            if (thread_local_kw != nullptr)
                put_back_token(pc);
        }

        AstNode *fn_proto = ast_parse_fn_proto(pc);
        if (fn_proto != nullptr) {
            AstNode *body = ast_parse_block(pc);
            if (body == nullptr)
                expect_token(pc, TokenIdSemicolon);

            assert(fn_proto->type == NodeTypeFnProto);
            fn_proto->line = first->start_line;
            fn_proto->column = first->start_column;
            fn_proto->data.fn_proto.visib_mod = visib_mod;
            fn_proto->data.fn_proto.doc_comments = *doc_comments;
            if (!fn_proto->data.fn_proto.is_extern)
                fn_proto->data.fn_proto.is_extern = first->id == TokenIdKeywordExtern;
            fn_proto->data.fn_proto.is_export = first->id == TokenIdKeywordExport;
            switch (first->id) {
                case TokenIdKeywordInline:
                    fn_proto->data.fn_proto.fn_inline = FnInlineAlways;
                    break;
                case TokenIdKeywordNoInline:
                    fn_proto->data.fn_proto.fn_inline = FnInlineNever;
                    break;
                default:
                    fn_proto->data.fn_proto.fn_inline = FnInlineAuto;
                    break;
            }
            fn_proto->data.fn_proto.lib_name = token_buf(lib_name);

            AstNode *res = fn_proto;
            if (body != nullptr) {
                if (fn_proto->data.fn_proto.is_extern) {
                    ast_error(pc, first, "extern functions have no body");
                }
                res = ast_create_node_copy_line_info(pc, NodeTypeFnDef, fn_proto);
                res->data.fn_def.fn_proto = fn_proto;
                res->data.fn_def.body = body;
                fn_proto->data.fn_proto.fn_def_node = res;
            }

            return res;
        }

        ast_invalid_token_error(pc, peek_token(pc));
    }

    Token *thread_local_kw = eat_token_if(pc, TokenIdKeywordThreadLocal);
    AstNode *var_decl = ast_parse_var_decl(pc);
    if (var_decl != nullptr) {
        assert(var_decl->type == NodeTypeVariableDeclaration);
        var_decl->data.variable_declaration.visib_mod = visib_mod;
        var_decl->data.variable_declaration.doc_comments = *doc_comments;
        var_decl->data.variable_declaration.threadlocal_tok = thread_local_kw;
        return var_decl;
    }

    if (thread_local_kw != nullptr)
        put_back_token(pc);

    AstNode *fn_proto = ast_parse_fn_proto(pc);
    if (fn_proto != nullptr) {
        AstNode *body = ast_parse_block(pc);
        if (body == nullptr)
            expect_token(pc, TokenIdSemicolon);

        assert(fn_proto->type == NodeTypeFnProto);
        fn_proto->data.fn_proto.visib_mod = visib_mod;
        fn_proto->data.fn_proto.doc_comments = *doc_comments;
        AstNode *res = fn_proto;
        if (body != nullptr) {
            res = ast_create_node_copy_line_info(pc, NodeTypeFnDef, fn_proto);
            res->data.fn_def.fn_proto = fn_proto;
            res->data.fn_def.body = body;
            fn_proto->data.fn_proto.fn_def_node = res;
        }

        return res;
    }

    Token *usingnamespace = eat_token_if(pc, TokenIdKeywordUsingNamespace);
    if (usingnamespace != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_expr);
        expect_token(pc, TokenIdSemicolon);

        AstNode *res = ast_create_node(pc, NodeTypeUsingNamespace, usingnamespace);
        res->data.using_namespace.visib_mod = visib_mod;
        res->data.using_namespace.expr = expr;
        return res;
    }

    return nullptr;
}

// FnProto <- KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? EXCLAMATIONMARK? (KEYWORD_anytype / TypeExpr)
static AstNode *ast_parse_fn_proto(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordFn);
    if (first == nullptr) {
        return nullptr;
    }

    Token *identifier = eat_token_if(pc, TokenIdSymbol);
    expect_token(pc, TokenIdLParen);
    ZigList<AstNode *> params = ast_parse_list(pc, TokenIdComma, ast_parse_param_decl);
    expect_token(pc, TokenIdRParen);

    AstNode *align_expr = ast_parse_byte_align(pc);
    AstNode *section_expr = ast_parse_link_section(pc);
    AstNode *callconv_expr = ast_parse_callconv(pc);
    Token *anytype = eat_token_if(pc, TokenIdKeywordAnyType);
    Token *exmark = nullptr;
    AstNode *return_type = nullptr;
    if (anytype == nullptr) {
        exmark = eat_token_if(pc, TokenIdBang);
        return_type = ast_expect(pc, ast_parse_type_expr);
    }

    AstNode *res = ast_create_node(pc, NodeTypeFnProto, first);
    res->data.fn_proto = {};
    res->data.fn_proto.name = token_buf(identifier);
    res->data.fn_proto.params = params;
    res->data.fn_proto.align_expr = align_expr;
    res->data.fn_proto.section_expr = section_expr;
    res->data.fn_proto.callconv_expr = callconv_expr;
    res->data.fn_proto.return_anytype_token = anytype;
    res->data.fn_proto.auto_err_set = exmark != nullptr;
    res->data.fn_proto.return_type = return_type;

    for (size_t i = 0; i < params.length; i++) {
        AstNode *param_decl = params.at(i);
        assert(param_decl->type == NodeTypeParamDecl);
        if (param_decl->data.param_decl.is_var_args)
            res->data.fn_proto.is_var_args = true;
        if (i != params.length - 1 && res->data.fn_proto.is_var_args)
            ast_error(pc, first, "Function prototype have varargs as a none last parameter.");
    }
    return res;
}

// VarDecl <- (KEYWORD_const / KEYWORD_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? LinkSection? (EQUAL Expr)? SEMICOLON
static AstNode *ast_parse_var_decl(ParseContext *pc) {
    Token *mut_kw = eat_token_if(pc, TokenIdKeywordConst);
    if (mut_kw == nullptr)
        mut_kw = eat_token_if(pc, TokenIdKeywordVar);
    if (mut_kw == nullptr)
        return nullptr;

    Token *identifier = expect_token(pc, TokenIdSymbol);
    AstNode *type_expr = nullptr;
    if (eat_token_if(pc, TokenIdColon) != nullptr)
        type_expr = ast_expect(pc, ast_parse_type_expr);

    AstNode *align_expr = ast_parse_byte_align(pc);
    AstNode *section_expr = ast_parse_link_section(pc);
    AstNode *expr = nullptr;
    if (eat_token_if(pc, TokenIdEq) != nullptr)
        expr = ast_expect(pc, ast_parse_expr);

    expect_token(pc, TokenIdSemicolon);

    AstNode *res = ast_create_node(pc, NodeTypeVariableDeclaration, mut_kw);
    res->data.variable_declaration.is_const = mut_kw->id == TokenIdKeywordConst;
    res->data.variable_declaration.symbol = token_buf(identifier);
    res->data.variable_declaration.type = type_expr;
    res->data.variable_declaration.align_expr = align_expr;
    res->data.variable_declaration.section_expr = section_expr;
    res->data.variable_declaration.expr = expr;
    return res;
}

// ContainerField <- KEYWORD_comptime? IDENTIFIER (COLON TypeExpr ByteAlign?)? (EQUAL Expr)?
static AstNode *ast_parse_container_field(ParseContext *pc) {
    Token *identifier = eat_token_if(pc, TokenIdSymbol);
    if (identifier == nullptr)
        return nullptr;

    AstNode *type_expr = nullptr;
    if (eat_token_if(pc, TokenIdColon) != nullptr) {
        Token *anytype_tok = eat_token_if(pc, TokenIdKeywordAnyType);
        if (anytype_tok != nullptr) {
            type_expr = ast_create_node(pc, NodeTypeAnyTypeField, anytype_tok);
        } else {
            type_expr = ast_expect(pc, ast_parse_type_expr);
        }
    }
    AstNode *align_expr = ast_parse_byte_align(pc);
    AstNode *expr = nullptr;
    if (eat_token_if(pc, TokenIdEq) != nullptr)
        expr = ast_expect(pc, ast_parse_expr);

    AstNode *res = ast_create_node(pc, NodeTypeStructField, identifier);
    res->data.struct_field.name = token_buf(identifier);
    res->data.struct_field.type = type_expr;
    res->data.struct_field.value = expr;
    res->data.struct_field.align_expr = align_expr;
    return res;
}

// Statement
//     <- KEYWORD_comptime? VarDecl
//      / KEYWORD_comptime BlockExprStatement
//      / KEYWORD_nosuspend BlockExprStatement
//      / KEYWORD_suspend (SEMICOLON / BlockExprStatement)
//      / KEYWORD_defer BlockExprStatement
//      / KEYWORD_errdefer Payload? BlockExprStatement
//      / IfStatement
//      / LabeledStatement
//      / SwitchExpr
//      / AssignExpr SEMICOLON
static AstNode *ast_parse_statement(ParseContext *pc) {
    Token *comptime = eat_token_if(pc, TokenIdKeywordCompTime);
    AstNode *var_decl = ast_parse_var_decl(pc);
    if (var_decl != nullptr) {
        assert(var_decl->type == NodeTypeVariableDeclaration);
        var_decl->data.variable_declaration.is_comptime = comptime != nullptr;
        return var_decl;
    }

    if (comptime != nullptr) {
        AstNode *statement = ast_expect(pc, ast_parse_block_expr_statement);
        AstNode *res = ast_create_node(pc, NodeTypeCompTime, comptime);
        res->data.comptime_expr.expr = statement;
        return res;
    }

    Token *nosuspend = eat_token_if(pc, TokenIdKeywordNoSuspend);
    if (nosuspend != nullptr) {
        AstNode *statement = ast_expect(pc, ast_parse_block_expr_statement);
        AstNode *res = ast_create_node(pc, NodeTypeNoSuspend, nosuspend);
        res->data.nosuspend_expr.expr = statement;
        return res;
    }

    Token *suspend = eat_token_if(pc, TokenIdKeywordSuspend);
    if (suspend != nullptr) {
        AstNode *statement = nullptr;
        if (eat_token_if(pc, TokenIdSemicolon) == nullptr)
            statement = ast_expect(pc, ast_parse_block_expr_statement);

        AstNode *res = ast_create_node(pc, NodeTypeSuspend, suspend);
        res->data.suspend.block = statement;
        return res;
    }

    Token *defer = eat_token_if(pc, TokenIdKeywordDefer);
    if (defer == nullptr)
        defer = eat_token_if(pc, TokenIdKeywordErrdefer);
    if (defer != nullptr) {
        Token *payload = (defer->id == TokenIdKeywordErrdefer) ?
            ast_parse_payload(pc) : nullptr;
        AstNode *statement = ast_expect(pc, ast_parse_block_expr_statement);
        AstNode *res = ast_create_node(pc, NodeTypeDefer, defer);

        res->data.defer.kind = ReturnKindUnconditional;
        res->data.defer.expr = statement;
        if (defer->id == TokenIdKeywordErrdefer) {
            res->data.defer.kind = ReturnKindError;
            if (payload != nullptr)
                res->data.defer.err_payload = token_symbol(pc, payload);
        }
        return res;
    }

    AstNode *if_statement = ast_parse_if_statement(pc);
    if (if_statement != nullptr)
        return if_statement;

    AstNode *labeled_statement = ast_parse_labeled_statement(pc);
    if (labeled_statement != nullptr)
        return labeled_statement;

    AstNode *switch_expr = ast_parse_switch_expr(pc);
    if (switch_expr != nullptr)
        return switch_expr;

    AstNode *assign = ast_parse_assign_expr(pc);
    if (assign != nullptr) {
        expect_token(pc, TokenIdSemicolon);
        return assign;
    }

    return nullptr;
}

// IfStatement
//     <- IfPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / IfPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
static AstNode *ast_parse_if_statement(ParseContext *pc) {
    AstNode *res = ast_parse_if_prefix(pc);
    if (res == nullptr)
        return nullptr;

    AstNode *body = ast_parse_block_expr(pc);
    bool requires_semi = false;
    if (body == nullptr) {
        requires_semi = true;
        body = ast_parse_assign_expr(pc);
    }

    if (body == nullptr) {
        Token *tok = eat_token(pc);
        ast_error(pc, tok, "expected if body, found '%s'", token_name(tok->id));
    }

    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, ast_parse_statement);
    }

    if (requires_semi && else_body == nullptr)
        expect_token(pc, TokenIdSemicolon);

    assert(res->type == NodeTypeIfOptional);
    if (err_payload != nullptr) {
        AstNodeTestExpr old = res->data.test_expr;
        res->type = NodeTypeIfErrorExpr;
        res->data.if_err_expr.target_node = old.target_node;
        res->data.if_err_expr.var_is_ptr = old.var_is_ptr;
        res->data.if_err_expr.var_symbol = old.var_symbol;
        res->data.if_err_expr.then_node = body;
        res->data.if_err_expr.err_symbol = token_buf(err_payload);
        res->data.if_err_expr.else_node = else_body;
        return res;
    }

    if (res->data.test_expr.var_symbol != nullptr) {
        res->data.test_expr.then_node = body;
        res->data.test_expr.else_node = else_body;
        return res;
    }

    AstNodeTestExpr old = res->data.test_expr;
    res->type = NodeTypeIfBoolExpr;
    res->data.if_bool_expr.condition = old.target_node;
    res->data.if_bool_expr.then_block = body;
    res->data.if_bool_expr.else_node = else_body;
    return res;
}

// LabeledStatement <- BlockLabel? (Block / LoopStatement)
static AstNode *ast_parse_labeled_statement(ParseContext *pc) {
    Token *label = ast_parse_block_label(pc);
    AstNode *block = ast_parse_block(pc);
    if (block != nullptr) {
        assert(block->type == NodeTypeBlock);
        block->data.block.name = token_buf(label);
        return block;
    }

    AstNode *loop = ast_parse_loop_statement(pc);
    if (loop != nullptr) {
        switch (loop->type) {
            case NodeTypeForExpr:
                loop->data.for_expr.name = token_buf(label);
                break;
            case NodeTypeWhileExpr:
                loop->data.while_expr.name = token_buf(label);
                break;
            default:
                zig_unreachable();
        }
        return loop;
    }

    if (label != nullptr)
        ast_invalid_token_error(pc, peek_token(pc));
    return nullptr;
}

// LoopStatement <- KEYWORD_inline? (ForStatement / WhileStatement)
static AstNode *ast_parse_loop_statement(ParseContext *pc) {
    Token *inline_token = eat_token_if(pc, TokenIdKeywordInline);
    AstNode *for_statement = ast_parse_for_statement(pc);
    if (for_statement != nullptr) {
        assert(for_statement->type == NodeTypeForExpr);
        for_statement->data.for_expr.is_inline = inline_token != nullptr;
        return for_statement;
    }

    AstNode *while_statement = ast_parse_while_statement(pc);
    if (while_statement != nullptr) {
        assert(while_statement->type == NodeTypeWhileExpr);
        while_statement->data.while_expr.is_inline = inline_token != nullptr;
        return while_statement;
    }

    if (inline_token != nullptr)
        ast_invalid_token_error(pc, peek_token(pc));
    return nullptr;
}

// ForStatement
//     <- ForPrefix BlockExpr ( KEYWORD_else Statement )?
//      / ForPrefix AssignExpr ( SEMICOLON / KEYWORD_else Statement )
static AstNode *ast_parse_for_statement(ParseContext *pc) {
    AstNode *res = ast_parse_for_prefix(pc);
    if (res == nullptr)
        return nullptr;

    AstNode *body = ast_parse_block_expr(pc);
    bool requires_semi = false;
    if (body == nullptr) {
        requires_semi = true;
        body = ast_parse_assign_expr(pc);
    }

    if (body == nullptr) {
        Token *tok = eat_token(pc);
        ast_error(pc, tok, "expected loop body, found '%s'", token_name(tok->id));
    }

    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        else_body = ast_expect(pc, ast_parse_statement);
    }

    if (requires_semi && else_body == nullptr)
        expect_token(pc, TokenIdSemicolon);

    assert(res->type == NodeTypeForExpr);
    res->data.for_expr.body = body;
    res->data.for_expr.else_node = else_body;
    return res;
}

// WhileStatement
//     <- WhilePrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
static AstNode *ast_parse_while_statement(ParseContext *pc) {
    AstNode *res = ast_parse_while_prefix(pc);
    if (res == nullptr)
        return nullptr;

    AstNode *body = ast_parse_block_expr(pc);
    bool requires_semi = false;
    if (body == nullptr) {
        requires_semi = true;
        body = ast_parse_assign_expr(pc);
    }

    if (body == nullptr) {
        Token *tok = eat_token(pc);
        ast_error(pc, tok, "expected loop body, found '%s'", token_name(tok->id));
    }

    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, ast_parse_statement);
    }

    if (requires_semi && else_body == nullptr)
        expect_token(pc, TokenIdSemicolon);

    assert(res->type == NodeTypeWhileExpr);
    res->data.while_expr.body = body;
    res->data.while_expr.err_symbol = token_buf(err_payload);
    res->data.while_expr.else_node = else_body;
    return res;
}


// BlockExprStatement
//     <- BlockExpr
//      / AssignExpr SEMICOLON
static AstNode *ast_parse_block_expr_statement(ParseContext *pc) {
    AstNode *block = ast_parse_block_expr(pc);
    if (block != nullptr)
        return block;

    AstNode *assign_expr = ast_parse_assign_expr(pc);
    if (assign_expr != nullptr) {
        expect_token(pc, TokenIdSemicolon);
        return assign_expr;
    }

    return nullptr;
}

// BlockExpr <- BlockLabel? Block
static AstNode *ast_parse_block_expr(ParseContext *pc) {
    Token *label = ast_parse_block_label(pc);
    if (label != nullptr) {
        AstNode *res = ast_expect(pc, ast_parse_block);
        assert(res->type == NodeTypeBlock);
        res->data.block.name = token_buf(label);
        return res;
    }

    return ast_parse_block(pc);
}

// AssignExpr <- Expr (AssignOp Expr)?
static AstNode *ast_parse_assign_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(pc, BinOpChainOnce, ast_parse_assign_op, ast_parse_expr);
}

// Expr <- KEYWORD_try* BoolOrExpr
static AstNode *ast_parse_expr(ParseContext *pc) {
    return ast_parse_prefix_op_expr(
        pc,
        [](ParseContext *context) {
            Token *try_token = eat_token_if(context, TokenIdKeywordTry);
            if (try_token != nullptr) {
                AstNode *res = ast_create_node(context, NodeTypeReturnExpr, try_token);
                res->data.return_expr.kind = ReturnKindError;
                return res;
            }

            return (AstNode*)nullptr;
        },
        ast_parse_bool_or_expr
    );
}

// BoolOrExpr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*
static AstNode *ast_parse_bool_or_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(
        pc,
        BinOpChainInf,
        ast_parse_bin_op_simple<TokenIdKeywordOr, BinOpTypeBoolOr>,
        ast_parse_bool_and_expr
    );
}

// BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*
static AstNode *ast_parse_bool_and_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(
        pc,
        BinOpChainInf,
        ast_parse_bin_op_simple<TokenIdKeywordAnd, BinOpTypeBoolAnd>,
        ast_parse_compare_expr
    );
}

// CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)?
static AstNode *ast_parse_compare_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(pc, BinOpChainOnce, ast_parse_compare_op, ast_parse_bitwise_expr);
}

// BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)*
static AstNode *ast_parse_bitwise_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(pc, BinOpChainInf, ast_parse_bitwise_op, ast_parse_bit_shift_expr);
}

// BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)*
static AstNode *ast_parse_bit_shift_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(pc, BinOpChainInf, ast_parse_bit_shift_op, ast_parse_addition_expr);
}

// AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*
static AstNode *ast_parse_addition_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(pc, BinOpChainInf, ast_parse_addition_op, ast_parse_multiply_expr);
}

// MultiplyExpr <- PrefixExpr (MultiplyOp PrefixExpr)*
static AstNode *ast_parse_multiply_expr(ParseContext *pc) {
    return ast_parse_bin_op_expr(pc, BinOpChainInf, ast_parse_multiply_op, ast_parse_prefix_expr);
}

// PrefixExpr <- PrefixOp* PrimaryExpr
static AstNode *ast_parse_prefix_expr(ParseContext *pc) {
    return ast_parse_prefix_op_expr(
        pc,
        ast_parse_prefix_op,
        ast_parse_primary_expr
    );
}

// PrimaryExpr
//     <- AsmExpr
//      / IfExpr
//      / KEYWORD_break BreakLabel? Expr?
//      / KEYWORD_comptime Expr
//      / KEYWORD_nosuspend Expr
//      / KEYWORD_continue BreakLabel?
//      / KEYWORD_resume Expr
//      / KEYWORD_return Expr?
//      / BlockLabel? LoopExpr
//      / Block
//      / CurlySuffixExpr
static AstNode *ast_parse_primary_expr(ParseContext *pc) {
    AstNode *asm_expr = ast_parse_asm_expr(pc);
    if (asm_expr != nullptr)
        return asm_expr;

    AstNode *if_expr = ast_parse_if_expr(pc);
    if (if_expr != nullptr)
        return if_expr;

    Token *break_token = eat_token_if(pc, TokenIdKeywordBreak);
    if (break_token != nullptr) {
        Token *label = ast_parse_break_label(pc);
        AstNode *expr = ast_parse_expr(pc);

        AstNode *res = ast_create_node(pc, NodeTypeBreak, break_token);
        res->data.break_expr.name = token_buf(label);
        res->data.break_expr.expr = expr;
        return res;
    }

    Token *comptime = eat_token_if(pc, TokenIdKeywordCompTime);
    if (comptime != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_expr);
        AstNode *res = ast_create_node(pc, NodeTypeCompTime, comptime);
        res->data.comptime_expr.expr = expr;
        return res;
    }

    Token *nosuspend = eat_token_if(pc, TokenIdKeywordNoSuspend);
    if (nosuspend != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_expr);
        AstNode *res = ast_create_node(pc, NodeTypeNoSuspend, nosuspend);
        res->data.nosuspend_expr.expr = expr;
        return res;
    }

    Token *continue_token = eat_token_if(pc, TokenIdKeywordContinue);
    if (continue_token != nullptr) {
        Token *label = ast_parse_break_label(pc);
        AstNode *res = ast_create_node(pc, NodeTypeContinue, continue_token);
        res->data.continue_expr.name = token_buf(label);
        return res;
    }

    Token *resume = eat_token_if(pc, TokenIdKeywordResume);
    if (resume != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_expr);
        AstNode *res = ast_create_node(pc, NodeTypeResume, resume);
        res->data.resume_expr.expr = expr;
        return res;
    }

    Token *return_token = eat_token_if(pc, TokenIdKeywordReturn);
    if (return_token != nullptr) {
        AstNode *expr = ast_parse_expr(pc);
        AstNode *res = ast_create_node(pc, NodeTypeReturnExpr, return_token);
        res->data.return_expr.expr = expr;
        return res;
    }

    Token *label = ast_parse_block_label(pc);
    AstNode *loop = ast_parse_loop_expr(pc);
    if (loop != nullptr) {
        switch (loop->type) {
            case NodeTypeForExpr:
                loop->data.for_expr.name = token_buf(label);
                break;
            case NodeTypeWhileExpr:
                loop->data.while_expr.name = token_buf(label);
                break;
            default:
                zig_unreachable();
        }
        return loop;
    } else if (label != nullptr) {
        // Restore the tokens that we eaten by ast_parse_block_label.
        put_back_token(pc);
        put_back_token(pc);
    }

    AstNode *block = ast_parse_block(pc);
    if (block != nullptr)
        return block;

    AstNode *curly_suffix = ast_parse_curly_suffix_expr(pc);
    if (curly_suffix != nullptr)
        return curly_suffix;

    return nullptr;
}

// IfExpr <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
static AstNode *ast_parse_if_expr(ParseContext *pc) {
    return ast_parse_if_expr_helper(pc, ast_parse_expr);
}

// Block <- LBRACE Statement* RBRACE
static AstNode *ast_parse_block(ParseContext *pc) {
    Token *lbrace = eat_token_if(pc, TokenIdLBrace);
    if (lbrace == nullptr)
        return nullptr;

    ZigList<AstNode *> statements = {};
    AstNode *statement;
    while ((statement = ast_parse_statement(pc)) != nullptr)
        statements.append(statement);

    expect_token(pc, TokenIdRBrace);

    AstNode *res = ast_create_node(pc, NodeTypeBlock, lbrace);
    res->data.block.statements = statements;
    return res;
}

// LoopExpr <- KEYWORD_inline? (ForExpr / WhileExpr)
static AstNode *ast_parse_loop_expr(ParseContext *pc) {
    return ast_parse_loop_expr_helper(
        pc,
        ast_parse_for_expr,
        ast_parse_while_expr
    );
}

// ForExpr <- ForPrefix Expr (KEYWORD_else Expr)?
static AstNode *ast_parse_for_expr(ParseContext *pc) {
    return ast_parse_for_expr_helper(pc, ast_parse_expr);
}

// WhileExpr <- WhilePrefix Expr (KEYWORD_else Payload? Expr)?
static AstNode *ast_parse_while_expr(ParseContext *pc) {
    return ast_parse_while_expr_helper(pc, ast_parse_expr);
}

// CurlySuffixExpr <- TypeExpr InitList?
static AstNode *ast_parse_curly_suffix_expr(ParseContext *pc) {
    AstNode *type_expr = ast_parse_type_expr(pc);
    if (type_expr == nullptr)
        return nullptr;

    AstNode *res = ast_parse_init_list(pc);
    if (res == nullptr)
        return type_expr;

    assert(res->type == NodeTypeContainerInitExpr);
    res->data.container_init_expr.type = type_expr;
    return res;
}

// InitList
//     <- LBRACE FieldInit (COMMA FieldInit)* COMMA? RBRACE
//      / LBRACE Expr (COMMA Expr)* COMMA? RBRACE
//      / LBRACE RBRACE
static AstNode *ast_parse_init_list(ParseContext *pc) {
    Token *lbrace = eat_token_if(pc, TokenIdLBrace);
    if (lbrace == nullptr)
        return nullptr;

    AstNode *first = ast_parse_field_init(pc);
    if (first != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeContainerInitExpr, lbrace);
        res->data.container_init_expr.kind = ContainerInitKindStruct;
        res->data.container_init_expr.entries.append(first);

        while (eat_token_if(pc, TokenIdComma) != nullptr) {
            AstNode *field_init = ast_parse_field_init(pc);
            if (field_init == nullptr)
                break;
            res->data.container_init_expr.entries.append(field_init);
        }

        expect_token(pc, TokenIdRBrace);
        return res;
    }

    AstNode *res = ast_create_node(pc, NodeTypeContainerInitExpr, lbrace);
    res->data.container_init_expr.kind = ContainerInitKindArray;

    first = ast_parse_expr(pc);
    if (first != nullptr) {
        res->data.container_init_expr.entries.append(first);

        while (eat_token_if(pc, TokenIdComma) != nullptr) {
            AstNode *expr = ast_parse_expr(pc);
            if (expr == nullptr)
                break;
            res->data.container_init_expr.entries.append(expr);
        }

        expect_token(pc, TokenIdRBrace);
        return res;
    }

    expect_token(pc, TokenIdRBrace);
    return res;
}

// TypeExpr <- PrefixTypeOp* ErrorUnionExpr
static AstNode *ast_parse_type_expr(ParseContext *pc) {
    return ast_parse_prefix_op_expr(
        pc,
        ast_parse_prefix_type_op,
        ast_parse_error_union_expr
    );
}

// ErrorUnionExpr <- SuffixExpr (EXCLAMATIONMARK TypeExpr)?
static AstNode *ast_parse_error_union_expr(ParseContext *pc) {
    AstNode *res = ast_parse_suffix_expr(pc);
    if (res == nullptr)
        return nullptr;

    AstNode *op = ast_parse_bin_op_simple<TokenIdBang, BinOpTypeErrorUnion>(pc);
    if (op == nullptr)
        return res;

    AstNode *right = ast_expect(pc, ast_parse_type_expr);
    assert(op->type == NodeTypeBinOpExpr);
    op->data.bin_op_expr.op1 = res;
    op->data.bin_op_expr.op2 = right;
    return op;
}

// SuffixExpr
//     <- KEYWORD_async   PrimaryTypeExpr SuffixOp* FnCallArguments
//      / PrimaryTypeExpr (SuffixOp / FnCallArguments)*
static AstNode *ast_parse_suffix_expr(ParseContext *pc) {
    Token *async_token = eat_token_if(pc, TokenIdKeywordAsync);
    if (async_token) {
        AstNode *child = ast_expect(pc, ast_parse_primary_type_expr);
        while (true) {
            AstNode *suffix = ast_parse_suffix_op(pc);
            if (suffix == nullptr)
                break;

            switch (suffix->type) {
                case NodeTypeSliceExpr:
                    suffix->data.slice_expr.array_ref_expr = child;
                    break;
                case NodeTypeArrayAccessExpr:
                    suffix->data.array_access_expr.array_ref_expr = child;
                    break;
                case NodeTypeFieldAccessExpr:
                    suffix->data.field_access_expr.struct_expr = child;
                    break;
                case NodeTypeUnwrapOptional:
                    suffix->data.unwrap_optional.expr = child;
                    break;
                case NodeTypePtrDeref:
                    suffix->data.ptr_deref_expr.target = child;
                    break;
                default:
                    zig_unreachable();
            }
            child = suffix;
        }

        // TODO: Both *_async_prefix and *_fn_call_arguments returns an
        //       AstNode *. All we really want here is the arguments of
        //       the call we parse. We therefor "leak" the node for now.
        //       Wait till we get async rework to fix this.
        AstNode *args = ast_parse_fn_call_arguments(pc);
        if (args == nullptr)
            ast_invalid_token_error(pc, peek_token(pc));

        assert(args->type == NodeTypeFnCallExpr);

        AstNode *res = ast_create_node(pc, NodeTypeFnCallExpr, async_token);
        res->data.fn_call_expr.modifier = CallModifierAsync;
        res->data.fn_call_expr.seen = false;
        res->data.fn_call_expr.fn_ref_expr = child;
        res->data.fn_call_expr.params = args->data.fn_call_expr.params;
        return res;
    }

    AstNode *res = ast_parse_primary_type_expr(pc);
    if (res == nullptr)
        return nullptr;

    while (true) {
        AstNode *suffix = ast_parse_suffix_op(pc);
        if (suffix != nullptr) {
            switch (suffix->type) {
                case NodeTypeSliceExpr:
                    suffix->data.slice_expr.array_ref_expr = res;
                    break;
                case NodeTypeArrayAccessExpr:
                    suffix->data.array_access_expr.array_ref_expr = res;
                    break;
                case NodeTypeFieldAccessExpr:
                    suffix->data.field_access_expr.struct_expr = res;
                    break;
                case NodeTypeUnwrapOptional:
                    suffix->data.unwrap_optional.expr = res;
                    break;
                case NodeTypePtrDeref:
                    suffix->data.ptr_deref_expr.target = res;
                    break;
                default:
                    zig_unreachable();
            }
            res = suffix;
            continue;
        }

        AstNode * call = ast_parse_fn_call_arguments(pc);
        if (call != nullptr) {
            assert(call->type == NodeTypeFnCallExpr);
            call->data.fn_call_expr.fn_ref_expr = res;
            res = call;
            continue;
        }

        break;
    }

    return res;

}

// PrimaryTypeExpr
//     <- BUILTINIDENTIFIER FnCallArguments
//      / CHAR_LITERAL
//      / ContainerDecl
//      / DOT IDENTIFIER
//      / ErrorSetDecl
//      / FLOAT
//      / FnProto
//      / GroupedExpr
//      / LabeledTypeExpr
//      / IDENTIFIER
//      / IfTypeExpr
//      / INTEGER
//      / KEYWORD_comptime TypeExpr
//      / KEYWORD_error DOT IDENTIFIER
//      / KEYWORD_false
//      / KEYWORD_null
//      / KEYWORD_promise
//      / KEYWORD_true
//      / KEYWORD_undefined
//      / KEYWORD_unreachable
//      / STRINGLITERAL
//      / SwitchExpr
static AstNode *ast_parse_primary_type_expr(ParseContext *pc) {
    // TODO: This is not in line with the grammar.
    //       Because the prev stage 1 tokenizer does not parse
    //       @[a-zA-Z_][a-zA-Z0-9_] as one token, it has to do a
    //       hack, where it accepts '@' (IDENTIFIER / KEYWORD_export).
    //       I'd say that it's better if '@' is part of the builtin
    //       identifier token.
    Token *at_sign = eat_token_if(pc, TokenIdAtSign);
    if (at_sign != nullptr) {
        Buf *name;
        Token *token = eat_token_if(pc, TokenIdKeywordExport);
        if (token == nullptr) {
            token = expect_token(pc, TokenIdSymbol);
            name = token_buf(token);
        } else {
            name = buf_create_from_str("export");
        }

        AstNode *res = ast_expect(pc, ast_parse_fn_call_arguments);
        AstNode *name_sym = ast_create_node(pc, NodeTypeSymbol, token);
        name_sym->data.symbol_expr.symbol = name;

        assert(res->type == NodeTypeFnCallExpr);
        res->line = at_sign->start_line;
        res->column = at_sign->start_column;
        res->data.fn_call_expr.fn_ref_expr = name_sym;
        res->data.fn_call_expr.modifier = CallModifierBuiltin;
        return res;
    }

    Token *char_lit = eat_token_if(pc, TokenIdCharLiteral);
    if (char_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeCharLiteral, char_lit);
        res->data.char_literal.value = char_lit->data.char_lit.c;
        return res;
    }

    AstNode *container_decl = ast_parse_container_decl(pc);
    if (container_decl != nullptr)
        return container_decl;

    AstNode *anon_lit = ast_parse_anon_lit(pc);
    if (anon_lit != nullptr)
        return anon_lit;

    AstNode *error_set_decl = ast_parse_error_set_decl(pc);
    if (error_set_decl != nullptr)
        return error_set_decl;

    Token *float_lit = eat_token_if(pc, TokenIdFloatLiteral);
    if (float_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeFloatLiteral, float_lit);
        res->data.float_literal.bigfloat = &float_lit->data.float_lit.bigfloat;
        res->data.float_literal.overflow = float_lit->data.float_lit.overflow;
        return res;
    }

    AstNode *fn_proto = ast_parse_fn_proto(pc);
    if (fn_proto != nullptr)
        return fn_proto;

    AstNode *grouped_expr = ast_parse_grouped_expr(pc);
    if (grouped_expr != nullptr)
        return grouped_expr;

    AstNode *labeled_type_expr = ast_parse_labeled_type_expr(pc);
    if (labeled_type_expr != nullptr)
        return labeled_type_expr;

    Token *identifier = eat_token_if(pc, TokenIdSymbol);
    if (identifier != nullptr)
        return token_symbol(pc, identifier);

    AstNode *if_type_expr = ast_parse_if_type_expr(pc);
    if (if_type_expr != nullptr)
        return if_type_expr;

    Token *int_lit = eat_token_if(pc, TokenIdIntLiteral);
    if (int_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeIntLiteral, int_lit);
        res->data.int_literal.bigint = &int_lit->data.int_lit.bigint;
        return res;
    }

    Token *comptime = eat_token_if(pc, TokenIdKeywordCompTime);
    if (comptime != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_type_expr);
        AstNode *res = ast_create_node(pc, NodeTypeCompTime, comptime);
        res->data.comptime_expr.expr = expr;
        return res;
    }

    Token *error = eat_token_if(pc, TokenIdKeywordError);
    if (error != nullptr) {
        Token *dot = expect_token(pc, TokenIdDot);
        Token *name = expect_token(pc, TokenIdSymbol);
        AstNode *left = ast_create_node(pc, NodeTypeErrorType, error);
        AstNode *res = ast_create_node(pc, NodeTypeFieldAccessExpr, dot);
        res->data.field_access_expr.struct_expr = left;
        res->data.field_access_expr.field_name = token_buf(name);
        return res;
    }

    Token *false_token = eat_token_if(pc, TokenIdKeywordFalse);
    if (false_token != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeBoolLiteral, false_token);
        res->data.bool_literal.value = false;
        return res;
    }

    Token *null = eat_token_if(pc, TokenIdKeywordNull);
    if (null != nullptr)
        return ast_create_node(pc, NodeTypeNullLiteral, null);

    Token *anyframe = eat_token_if(pc, TokenIdKeywordAnyFrame);
    if (anyframe != nullptr)
        return ast_create_node(pc, NodeTypeAnyFrameType, anyframe);

    Token *true_token = eat_token_if(pc, TokenIdKeywordTrue);
    if (true_token != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeBoolLiteral, true_token);
        res->data.bool_literal.value = true;
        return res;
    }

    Token *undefined = eat_token_if(pc, TokenIdKeywordUndefined);
    if (undefined != nullptr)
        return ast_create_node(pc, NodeTypeUndefinedLiteral, undefined);

    Token *unreachable = eat_token_if(pc, TokenIdKeywordUnreachable);
    if (unreachable != nullptr)
        return ast_create_node(pc, NodeTypeUnreachable, unreachable);

    Token *string_lit = eat_token_if(pc, TokenIdStringLiteral);
    if (string_lit == nullptr)
        string_lit = eat_token_if(pc, TokenIdMultilineStringLiteral);
    if (string_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeStringLiteral, string_lit);
        res->data.string_literal.buf = token_buf(string_lit);
        return res;
    }

    AstNode *switch_expr = ast_parse_switch_expr(pc);
    if (switch_expr != nullptr)
        return switch_expr;

    return nullptr;
}

// ContainerDecl <- (KEYWORD_extern / KEYWORD_packed)? ContainerDeclAuto
static AstNode *ast_parse_container_decl(ParseContext *pc) {
    Token *layout_token = eat_token_if(pc, TokenIdKeywordExtern);
    if (layout_token == nullptr)
        layout_token = eat_token_if(pc, TokenIdKeywordPacked);

    AstNode *res = ast_parse_container_decl_auto(pc);
    if (res == nullptr) {
        if (layout_token != nullptr)
            put_back_token(pc);
        return nullptr;
    }

    assert(res->type == NodeTypeContainerDecl);
    if (layout_token != nullptr) {
        res->line = layout_token->start_line;
        res->column = layout_token->start_column;
        res->data.container_decl.layout = layout_token->id == TokenIdKeywordExtern
            ? ContainerLayoutExtern
            : ContainerLayoutPacked;
    }
    return res;
}

// ErrorSetDecl <- KEYWORD_error LBRACE IdentifierList RBRACE
static AstNode *ast_parse_error_set_decl(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordError);
    if (first == nullptr)
        return nullptr;
    if (eat_token_if(pc, TokenIdLBrace) == nullptr) {
        put_back_token(pc);
        return nullptr;
    }

    ZigList<AstNode *> decls = ast_parse_list<AstNode>(pc, TokenIdComma, [](ParseContext *context) {
        Buf doc_comment_buf = BUF_INIT;
        Token *doc_token = ast_parse_doc_comments(context, &doc_comment_buf);
        Token *ident = eat_token_if(context, TokenIdSymbol);
        if (ident == nullptr)
            return (AstNode*)nullptr;

        AstNode *symbol_node = token_symbol(context, ident);
        if (doc_token == nullptr)
            return symbol_node;

        AstNode *field_node = ast_create_node(context, NodeTypeErrorSetField, doc_token);
        field_node->data.err_set_field.field_name = symbol_node;
        field_node->data.err_set_field.doc_comments = doc_comment_buf;
        return field_node;
    });
    expect_token(pc, TokenIdRBrace);

    AstNode *res = ast_create_node(pc, NodeTypeErrorSetDecl, first);
    res->data.err_set_decl.decls = decls;
    return res;
}

// GroupedExpr <- LPAREN Expr RPAREN
static AstNode *ast_parse_grouped_expr(ParseContext *pc) {
    Token *lparen = eat_token_if(pc, TokenIdLParen);
    if (lparen == nullptr)
        return nullptr;

    AstNode *expr = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);

    AstNode *res = ast_create_node(pc, NodeTypeGroupedExpr, lparen);
    res->data.grouped_expr = expr;
    return res;
}

// IfTypeExpr <- IfPrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
static AstNode *ast_parse_if_type_expr(ParseContext *pc) {
    return ast_parse_if_expr_helper(pc, ast_parse_type_expr);
}

// LabeledTypeExpr
//     <- BlockLabel Block
//      / BlockLabel? LoopTypeExpr
static AstNode *ast_parse_labeled_type_expr(ParseContext *pc) {
    Token *label = ast_parse_block_label(pc);
    if (label != nullptr) {
        AstNode *block = ast_parse_block(pc);
        if (block != nullptr) {
            assert(block->type == NodeTypeBlock);
            block->data.block.name = token_buf(label);
            return block;
        }
    }

    AstNode *loop = ast_parse_loop_type_expr(pc);
    if (loop != nullptr) {
        switch (loop->type) {
            case NodeTypeForExpr:
                loop->data.for_expr.name = token_buf(label);
                break;
            case NodeTypeWhileExpr:
                loop->data.while_expr.name = token_buf(label);
                break;
            default:
                zig_unreachable();
        }
        return loop;
    }

    if (label != nullptr) {
        put_back_token(pc);
        put_back_token(pc);
    }
    return nullptr;
}

// LoopTypeExpr <- KEYWORD_inline? (ForTypeExpr / WhileTypeExpr)
static AstNode *ast_parse_loop_type_expr(ParseContext *pc) {
    return ast_parse_loop_expr_helper(
        pc,
        ast_parse_for_type_expr,
        ast_parse_while_type_expr
    );
}

// ForTypeExpr <- ForPrefix TypeExpr (KEYWORD_else TypeExpr)?
static AstNode *ast_parse_for_type_expr(ParseContext *pc) {
    return ast_parse_for_expr_helper(pc, ast_parse_type_expr);
}

// WhileTypeExpr <- WhilePrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
static AstNode *ast_parse_while_type_expr(ParseContext *pc) {
    return ast_parse_while_expr_helper(pc, ast_parse_type_expr);
}

// SwitchExpr <- KEYWORD_switch LPAREN Expr RPAREN LBRACE SwitchProngList RBRACE
static AstNode *ast_parse_switch_expr(ParseContext *pc) {
    Token *switch_token = eat_token_if(pc, TokenIdKeywordSwitch);
    if (switch_token == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *expr = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);
    expect_token(pc, TokenIdLBrace);
    ZigList<AstNode *> prongs = ast_parse_list(pc, TokenIdComma, ast_parse_switch_prong);
    expect_token(pc, TokenIdRBrace);

    AstNode *res = ast_create_node(pc, NodeTypeSwitchExpr, switch_token);
    res->data.switch_expr.expr = expr;
    res->data.switch_expr.prongs = prongs;
    return res;
}

// AsmExpr <- KEYWORD_asm KEYWORD_volatile? LPAREN STRINGLITERAL AsmOutput? RPAREN
static AstNode *ast_parse_asm_expr(ParseContext *pc) {
    Token *asm_token = eat_token_if(pc, TokenIdKeywordAsm);
    if (asm_token == nullptr)
        return nullptr;

    Token *volatile_token = eat_token_if(pc, TokenIdKeywordVolatile);
    expect_token(pc, TokenIdLParen);
    AstNode *asm_template = ast_expect(pc, ast_parse_expr);
    AstNode *res = ast_parse_asm_output(pc);
    if (res == nullptr)
        res = ast_create_node_no_line_info(pc, NodeTypeAsmExpr);
    expect_token(pc, TokenIdRParen);

    res->line = asm_token->start_line;
    res->column = asm_token->start_column;
    res->data.asm_expr.volatile_token = volatile_token;
    res->data.asm_expr.asm_template = asm_template;
    return res;
}

static AstNode *ast_parse_anon_lit(ParseContext *pc) {
    Token *period = eat_token_if(pc, TokenIdDot);
    if (period == nullptr)
        return nullptr;

    // anon enum literal
    Token *identifier = eat_token_if(pc, TokenIdSymbol);
    if (identifier != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeEnumLiteral, period);
        res->data.enum_literal.period = period;
        res->data.enum_literal.identifier = identifier;
        return res;
    }

    // anon container literal
    AstNode *res = ast_parse_init_list(pc);
    if (res != nullptr)
        return res;
    put_back_token(pc);
    return nullptr;
}

// AsmOutput <- COLON AsmOutputList AsmInput?
static AstNode *ast_parse_asm_output(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdColon) == nullptr)
        return nullptr;

    ZigList<AsmOutput *> output_list = ast_parse_list(pc, TokenIdComma, ast_parse_asm_output_item);
    AstNode *res = ast_parse_asm_input(pc);
    if (res == nullptr)
        res = ast_create_node_no_line_info(pc, NodeTypeAsmExpr);

    res->data.asm_expr.output_list = output_list;
    return res;
}

// AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
static AsmOutput *ast_parse_asm_output_item(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdLBracket) == nullptr)
        return nullptr;

    Token *sym_name = expect_token(pc, TokenIdSymbol);
    expect_token(pc, TokenIdRBracket);

    Token *str = eat_token_if(pc, TokenIdMultilineStringLiteral);
    if (str == nullptr)
        str = expect_token(pc, TokenIdStringLiteral);
    expect_token(pc, TokenIdLParen);

    Token *var_name = eat_token_if(pc, TokenIdSymbol);
    AstNode *return_type = nullptr;
    if (var_name == nullptr) {
        expect_token(pc, TokenIdArrow);
        return_type = ast_expect(pc, ast_parse_type_expr);
    }

    expect_token(pc, TokenIdRParen);

    AsmOutput *res = heap::c_allocator.create<AsmOutput>();
    res->asm_symbolic_name = token_buf(sym_name);
    res->constraint = token_buf(str);
    res->variable_name = token_buf(var_name);
    res->return_type = return_type;
    return res;
}

// AsmInput <- COLON AsmInputList AsmClobbers?
static AstNode *ast_parse_asm_input(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdColon) == nullptr)
        return nullptr;

    ZigList<AsmInput *> input_list = ast_parse_list(pc, TokenIdComma, ast_parse_asm_input_item);
    AstNode *res = ast_parse_asm_clobbers(pc);
    if (res == nullptr)
        res = ast_create_node_no_line_info(pc, NodeTypeAsmExpr);

    res->data.asm_expr.input_list = input_list;
    return res;
}

// AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
static AsmInput *ast_parse_asm_input_item(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdLBracket) == nullptr)
        return nullptr;

    Token *sym_name = expect_token(pc, TokenIdSymbol);
    expect_token(pc, TokenIdRBracket);

    Token *constraint = eat_token_if(pc, TokenIdMultilineStringLiteral);
    if (constraint == nullptr)
        constraint = expect_token(pc, TokenIdStringLiteral);
    expect_token(pc, TokenIdLParen);
    AstNode *expr = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);

    AsmInput *res = heap::c_allocator.create<AsmInput>();
    res->asm_symbolic_name = token_buf(sym_name);
    res->constraint = token_buf(constraint);
    res->expr = expr;
    return res;
}

// AsmClobbers <- COLON StringList
static AstNode *ast_parse_asm_clobbers(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdColon) == nullptr)
        return nullptr;

    ZigList<Buf *> clobber_list = ast_parse_list<Buf>(pc, TokenIdComma, [](ParseContext *context) {
        Token *str = eat_token_if(context, TokenIdStringLiteral);
        if (str == nullptr)
            str = eat_token_if(context, TokenIdMultilineStringLiteral);
        if (str != nullptr)
            return token_buf(str);
        return (Buf*)nullptr;
    });

    AstNode *res = ast_create_node_no_line_info(pc, NodeTypeAsmExpr);
    res->data.asm_expr.clobber_list = clobber_list;
    return res;
}

// BreakLabel <- COLON IDENTIFIER
static Token *ast_parse_break_label(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdColon) == nullptr)
        return nullptr;

    return expect_token(pc, TokenIdSymbol);
}

// BlockLabel <- IDENTIFIER COLON
static Token *ast_parse_block_label(ParseContext *pc) {
    Token *ident = eat_token_if(pc, TokenIdSymbol);
    if (ident == nullptr)
        return nullptr;

    // We do 2 token lookahead here, as we don't want to error when
    // parsing identifiers.
    if (eat_token_if(pc, TokenIdColon) == nullptr) {
        put_back_token(pc);
        return nullptr;
    }

    return ident;
}

// FieldInit <- DOT IDENTIFIER EQUAL Expr
static AstNode *ast_parse_field_init(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdDot);
    if (first == nullptr)
        return nullptr;

    Token *name = eat_token_if(pc, TokenIdSymbol);
    if (name == nullptr) {
        // Because of anon literals ".{" is also valid.
        put_back_token(pc);
        return nullptr;
    }
    if (eat_token_if(pc, TokenIdEq) == nullptr) {
        // Because ".Name" can also be intepreted as an enum literal, we should put back
        // those two tokens again so that the parser can try to parse them as the enum
        // literal later.
        put_back_token(pc);
        put_back_token(pc);
        return nullptr;
    }
    AstNode *expr = ast_expect(pc, ast_parse_expr);

    AstNode *res = ast_create_node(pc, NodeTypeStructValueField, first);
    res->data.struct_val_field.name = token_buf(name);
    res->data.struct_val_field.expr = expr;
    return res;
}

// WhileContinueExpr <- COLON LPAREN AssignExpr RPAREN
static AstNode *ast_parse_while_continue_expr(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdColon);
    if (first == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *expr = ast_expect(pc, ast_parse_assign_expr);
    expect_token(pc, TokenIdRParen);
    return expr;
}

// LinkSection <- KEYWORD_linksection LPAREN Expr RPAREN
static AstNode *ast_parse_link_section(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordLinkSection);
    if (first == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *res = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);
    return res;
}

// CallConv <- KEYWORD_callconv LPAREN Expr RPAREN
static AstNode *ast_parse_callconv(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordCallconv);
    if (first == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *res = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);
    return res;
}

// ParamDecl <- (KEYWORD_noalias / KEYWORD_comptime)? (IDENTIFIER COLON)? ParamType
static AstNode *ast_parse_param_decl(ParseContext *pc) {
    Buf doc_comments = BUF_INIT;
    ast_parse_doc_comments(pc, &doc_comments);

    Token *first = eat_token_if(pc, TokenIdKeywordNoAlias);
    if (first == nullptr)
        first = eat_token_if(pc, TokenIdKeywordCompTime);

    Token *name = eat_token_if(pc, TokenIdSymbol);
    if (name != nullptr) {
        if (eat_token_if(pc, TokenIdColon) != nullptr) {
            if (first == nullptr)
                first = name;
        } else {
            // We put back the ident, so it can be parsed as a ParamType
            // later.
            put_back_token(pc);
            name = nullptr;
        }
    }

    AstNode *res;
    if (first == nullptr) {
        first = peek_token(pc);
        res = ast_parse_param_type(pc);
    } else {
        res = ast_expect(pc, ast_parse_param_type);
    }

    if (res == nullptr)
        return nullptr;

    assert(res->type == NodeTypeParamDecl);
    res->line = first->start_line;
    res->column = first->start_column;
    res->data.param_decl.name = token_buf(name);
    res->data.param_decl.doc_comments = doc_comments;
    res->data.param_decl.is_noalias = first->id == TokenIdKeywordNoAlias;
    res->data.param_decl.is_comptime = first->id == TokenIdKeywordCompTime;
    return res;
}

// ParamType
//     <- KEYWORD_anytype
//      / DOT3
//      / TypeExpr
static AstNode *ast_parse_param_type(ParseContext *pc) {
    Token *anytype_token = eat_token_if(pc, TokenIdKeywordAnyType);
    if (anytype_token != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeParamDecl, anytype_token);
        res->data.param_decl.anytype_token = anytype_token;
        return res;
    }

    Token *dots = eat_token_if(pc, TokenIdEllipsis3);
    if (dots != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeParamDecl, dots);
        res->data.param_decl.is_var_args = true;
        return res;
    }

    AstNode *type_expr = ast_parse_type_expr(pc);
    if (type_expr != nullptr) {
        AstNode *res = ast_create_node_copy_line_info(pc, NodeTypeParamDecl, type_expr);
        res->data.param_decl.type = type_expr;
        return res;
    }

    return nullptr;
}

// IfPrefix <- KEYWORD_if LPAREN Expr RPAREN PtrPayload?
static AstNode *ast_parse_if_prefix(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordIf);
    if (first == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *condition = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);
    Optional<PtrPayload> opt_payload = ast_parse_ptr_payload(pc);

    PtrPayload payload;
    AstNode *res = ast_create_node(pc, NodeTypeIfOptional, first);
    res->data.test_expr.target_node = condition;
    if (opt_payload.unwrap(&payload)) {
        res->data.test_expr.var_symbol = token_buf(payload.payload);
        res->data.test_expr.var_is_ptr = payload.asterisk != nullptr;
    }
    return res;
}

// WhilePrefix <- KEYWORD_while LPAREN Expr RPAREN PtrPayload? WhileContinueExpr?
static AstNode *ast_parse_while_prefix(ParseContext *pc) {
    Token *while_token = eat_token_if(pc, TokenIdKeywordWhile);
    if (while_token == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *condition = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);
    Optional<PtrPayload> opt_payload = ast_parse_ptr_payload(pc);
    AstNode *continue_expr = ast_parse_while_continue_expr(pc);

    PtrPayload payload;
    AstNode *res = ast_create_node(pc, NodeTypeWhileExpr, while_token);
    res->data.while_expr.condition = condition;
    res->data.while_expr.continue_expr = continue_expr;
    if (opt_payload.unwrap(&payload)) {
        res->data.while_expr.var_symbol = token_buf(payload.payload);
        res->data.while_expr.var_is_ptr = payload.asterisk != nullptr;
    }

    return res;
}

// ForPrefix <- KEYWORD_for LPAREN Expr RPAREN PtrIndexPayload
static AstNode *ast_parse_for_prefix(ParseContext *pc) {
    Token *for_token = eat_token_if(pc, TokenIdKeywordFor);
    if (for_token == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *array_expr = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);
    PtrIndexPayload payload;
    if (!ast_parse_ptr_index_payload(pc).unwrap(&payload))
        ast_invalid_token_error(pc, peek_token(pc));

    AstNode *res = ast_create_node(pc, NodeTypeForExpr, for_token);
    res->data.for_expr.array_expr = array_expr;
    res->data.for_expr.elem_node = token_symbol(pc, payload.payload);
    res->data.for_expr.elem_is_ptr = payload.asterisk != nullptr;
    if (payload.index != nullptr)
        res->data.for_expr.index_node = token_symbol(pc, payload.index);

    return res;
}

// Payload <- PIPE IDENTIFIER PIPE
static Token *ast_parse_payload(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdBinOr) == nullptr)
        return nullptr;

    Token *res = expect_token(pc, TokenIdSymbol);
    expect_token(pc, TokenIdBinOr);
    return res;
}

// PtrPayload <- PIPE ASTERISK? IDENTIFIER PIPE
static Optional<PtrPayload> ast_parse_ptr_payload(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdBinOr) == nullptr)
        return Optional<PtrPayload>::none();

    Token *asterisk = eat_token_if(pc, TokenIdStar);
    Token *payload = expect_token(pc, TokenIdSymbol);
    expect_token(pc, TokenIdBinOr);

    PtrPayload res;
    res.asterisk = asterisk;
    res.payload = payload;
    return Optional<PtrPayload>::some(res);
}

// PtrIndexPayload <- PIPE ASTERISK? IDENTIFIER (COMMA IDENTIFIER)? PIPE
static Optional<PtrIndexPayload> ast_parse_ptr_index_payload(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdBinOr) == nullptr)
        return Optional<PtrIndexPayload>::none();

    Token *asterisk = eat_token_if(pc, TokenIdStar);
    Token *payload = expect_token(pc, TokenIdSymbol);
    Token *index = nullptr;
    if (eat_token_if(pc, TokenIdComma) != nullptr)
        index = expect_token(pc, TokenIdSymbol);
    expect_token(pc, TokenIdBinOr);

    PtrIndexPayload res;
    res.asterisk = asterisk;
    res.payload = payload;
    res.index = index;
    return Optional<PtrIndexPayload>::some(res);
}

// SwitchProng <- SwitchCase EQUALRARROW PtrPayload? AssignExpr
static AstNode *ast_parse_switch_prong(ParseContext *pc) {
    AstNode *res = ast_parse_switch_case(pc);
    if (res == nullptr)
        return nullptr;

    expect_token(pc, TokenIdFatArrow);
    Optional<PtrPayload> opt_payload = ast_parse_ptr_payload(pc);
    AstNode *expr = ast_expect(pc, ast_parse_assign_expr);

    PtrPayload payload;
    assert(res->type == NodeTypeSwitchProng);
    res->data.switch_prong.expr = expr;
    if (opt_payload.unwrap(&payload)) {
        res->data.switch_prong.var_symbol = token_symbol(pc, payload.payload);
        res->data.switch_prong.var_is_ptr = payload.asterisk != nullptr;
    }

    return res;
}

// SwitchCase
//     <- SwitchItem (COMMA SwitchItem)* COMMA?
//      / KEYWORD_else
static AstNode *ast_parse_switch_case(ParseContext *pc) {
    AstNode *first = ast_parse_switch_item(pc);
    if (first != nullptr) {
        AstNode *res = ast_create_node_copy_line_info(pc, NodeTypeSwitchProng, first);
        res->data.switch_prong.items.append(first);
        res->data.switch_prong.any_items_are_range = first->type == NodeTypeSwitchRange;

        while (eat_token_if(pc, TokenIdComma) != nullptr) {
            AstNode *item = ast_parse_switch_item(pc);
            if (item == nullptr)
                break;

            res->data.switch_prong.items.append(item);
            res->data.switch_prong.any_items_are_range |= item->type == NodeTypeSwitchRange;
        }

        return res;
    }

    Token *else_token = eat_token_if(pc, TokenIdKeywordElse);
    if (else_token != nullptr)
        return ast_create_node(pc, NodeTypeSwitchProng, else_token);

    return nullptr;
}

// SwitchItem <- Expr (DOT3 Expr)?
static AstNode *ast_parse_switch_item(ParseContext *pc) {
    AstNode *expr = ast_parse_expr(pc);
    if (expr == nullptr)
        return nullptr;

    Token *dots = eat_token_if(pc, TokenIdEllipsis3);
    if (dots != nullptr) {
        AstNode *expr2 = ast_expect(pc, ast_parse_expr);
        AstNode *res = ast_create_node(pc, NodeTypeSwitchRange, dots);
        res->data.switch_range.start = expr;
        res->data.switch_range.end = expr2;
        return res;
    }

    return expr;
}

// AssignOp
//     <- ASTERISKEQUAL
//      / SLASHEQUAL
//      / PERCENTEQUAL
//      / PLUSEQUAL
//      / MINUSEQUAL
//      / LARROW2EQUAL
//      / RARROW2EQUAL
//      / AMPERSANDEQUAL
//      / CARETEQUAL
//      / PIPEEQUAL
//      / ASTERISKPERCENTEQUAL
//      / PLUSPERCENTEQUAL
//      / MINUSPERCENTEQUAL
//      / EQUAL
static AstNode *ast_parse_assign_op(ParseContext *pc) {
    // In C, we have `T arr[N] = {[i] = T{}};` but it doesn't
    // seem to work in C++...
    BinOpType table[TokenIdCount] = {};
    table[TokenIdBarBarEq] = BinOpTypeAssignMergeErrorSets;
    table[TokenIdBitAndEq] = BinOpTypeAssignBitAnd;
    table[TokenIdBitOrEq] = BinOpTypeAssignBitOr;
    table[TokenIdBitShiftLeftEq] = BinOpTypeAssignBitShiftLeft;
    table[TokenIdBitShiftRightEq] = BinOpTypeAssignBitShiftRight;
    table[TokenIdBitXorEq] = BinOpTypeAssignBitXor;
    table[TokenIdDivEq] = BinOpTypeAssignDiv;
    table[TokenIdEq] = BinOpTypeAssign;
    table[TokenIdMinusEq] = BinOpTypeAssignMinus;
    table[TokenIdMinusPercentEq] = BinOpTypeAssignMinusWrap;
    table[TokenIdModEq] = BinOpTypeAssignMod;
    table[TokenIdPlusEq] = BinOpTypeAssignPlus;
    table[TokenIdPlusPercentEq] = BinOpTypeAssignPlusWrap;
    table[TokenIdTimesEq] = BinOpTypeAssignTimes;
    table[TokenIdTimesPercentEq] = BinOpTypeAssignTimesWrap;

    BinOpType op = table[peek_token(pc)->id];
    if (op != BinOpTypeInvalid) {
        Token *op_token = eat_token(pc);
        AstNode *res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
        res->data.bin_op_expr.bin_op = op;
        return res;
    }

    return nullptr;

}

// CompareOp
//     <- EQUALEQUAL
//      / EXCLAMATIONMARKEQUAL
//      / LARROW
//      / RARROW
//      / LARROWEQUAL
//      / RARROWEQUAL
static AstNode *ast_parse_compare_op(ParseContext *pc) {
    BinOpType table[TokenIdCount] = {};
    table[TokenIdCmpEq] = BinOpTypeCmpEq;
    table[TokenIdCmpNotEq] = BinOpTypeCmpNotEq;
    table[TokenIdCmpLessThan] = BinOpTypeCmpLessThan;
    table[TokenIdCmpGreaterThan] = BinOpTypeCmpGreaterThan;
    table[TokenIdCmpLessOrEq] = BinOpTypeCmpLessOrEq;
    table[TokenIdCmpGreaterOrEq] = BinOpTypeCmpGreaterOrEq;

    BinOpType op = table[peek_token(pc)->id];
    if (op != BinOpTypeInvalid) {
        Token *op_token = eat_token(pc);
        AstNode *res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
        res->data.bin_op_expr.bin_op = op;
        return res;
    }

    return nullptr;
}

// BitwiseOp
//     <- AMPERSAND
//      / CARET
//      / PIPE
//      / KEYWORD_orelse
//      / KEYWORD_catch Payload?
static AstNode *ast_parse_bitwise_op(ParseContext *pc) {
    BinOpType table[TokenIdCount] = {};
    table[TokenIdAmpersand] = BinOpTypeBinAnd;
    table[TokenIdBinXor] = BinOpTypeBinXor;
    table[TokenIdBinOr] = BinOpTypeBinOr;
    table[TokenIdKeywordOrElse] = BinOpTypeUnwrapOptional;

    BinOpType op = table[peek_token(pc)->id];
    if (op != BinOpTypeInvalid) {
        Token *op_token = eat_token(pc);
        AstNode *res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
        res->data.bin_op_expr.bin_op = op;
        return res;
    }

    Token *catch_token = eat_token_if(pc, TokenIdKeywordCatch);
    if (catch_token != nullptr) {
        Token *payload = ast_parse_payload(pc);
        AstNode *res = ast_create_node(pc, NodeTypeCatchExpr, catch_token);
        if (payload != nullptr)
            res->data.unwrap_err_expr.symbol = token_symbol(pc, payload);

        return res;
    }

    return nullptr;
}

// BitShiftOp
//     <- LARROW2
//      / RARROW2
static AstNode *ast_parse_bit_shift_op(ParseContext *pc) {
    BinOpType table[TokenIdCount] = {};
    table[TokenIdBitShiftLeft] = BinOpTypeBitShiftLeft;
    table[TokenIdBitShiftRight] = BinOpTypeBitShiftRight;

    BinOpType op = table[peek_token(pc)->id];
    if (op != BinOpTypeInvalid) {
        Token *op_token = eat_token(pc);
        AstNode *res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
        res->data.bin_op_expr.bin_op = op;
        return res;
    }

    return nullptr;
}

// AdditionOp
//     <- PLUS
//      / MINUS
//      / PLUS2
//      / PLUSPERCENT
//      / MINUSPERCENT
static AstNode *ast_parse_addition_op(ParseContext *pc) {
    BinOpType table[TokenIdCount] = {};
    table[TokenIdPlus] = BinOpTypeAdd;
    table[TokenIdDash] = BinOpTypeSub;
    table[TokenIdPlusPlus] = BinOpTypeArrayCat;
    table[TokenIdPlusPercent] = BinOpTypeAddWrap;
    table[TokenIdMinusPercent] = BinOpTypeSubWrap;

    BinOpType op = table[peek_token(pc)->id];
    if (op != BinOpTypeInvalid) {
        Token *op_token = eat_token(pc);
        AstNode *res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
        res->data.bin_op_expr.bin_op = op;
        return res;
    }

    return nullptr;
}

// MultiplyOp
//     <- PIPE2
//      / ASTERISK
//      / SLASH
//      / PERCENT
//      / ASTERISK2
//      / ASTERISKPERCENT
static AstNode *ast_parse_multiply_op(ParseContext *pc) {
    BinOpType table[TokenIdCount] = {};
    table[TokenIdBarBar] = BinOpTypeMergeErrorSets;
    table[TokenIdStar] = BinOpTypeMult;
    table[TokenIdSlash] = BinOpTypeDiv;
    table[TokenIdPercent] = BinOpTypeMod;
    table[TokenIdStarStar] = BinOpTypeArrayMult;
    table[TokenIdTimesPercent] = BinOpTypeMultWrap;

    BinOpType op = table[peek_token(pc)->id];
    if (op != BinOpTypeInvalid) {
        Token *op_token = eat_token(pc);
        AstNode *res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
        res->data.bin_op_expr.bin_op = op;
        return res;
    }

    return nullptr;
}

// PrefixOp
//     <- EXCLAMATIONMARK
//      / MINUS
//      / TILDE
//      / MINUSPERCENT
//      / AMPERSAND
//      / KEYWORD_try
//      / KEYWORD_await
static AstNode *ast_parse_prefix_op(ParseContext *pc) {
    PrefixOp table[TokenIdCount] = {};
    table[TokenIdBang] = PrefixOpBoolNot;
    table[TokenIdDash] = PrefixOpNegation;
    table[TokenIdTilde] = PrefixOpBinNot;
    table[TokenIdMinusPercent] = PrefixOpNegationWrap;
    table[TokenIdAmpersand] = PrefixOpAddrOf;

    PrefixOp op = table[peek_token(pc)->id];
    if (op != PrefixOpInvalid) {
        Token *op_token = eat_token(pc);
        AstNode *res = ast_create_node(pc, NodeTypePrefixOpExpr, op_token);
        res->data.prefix_op_expr.prefix_op = op;
        return res;
    }

    Token *try_token = eat_token_if(pc, TokenIdKeywordTry);
    if (try_token != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeReturnExpr, try_token);
        res->data.return_expr.kind = ReturnKindError;
        return res;
    }

    Token *await = eat_token_if(pc, TokenIdKeywordAwait);
    if (await != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeAwaitExpr, await);
        return res;
    }

    return nullptr;
}

// PrefixTypeOp
//     <- QUESTIONMARK
//      / KEYWORD_anyframe MINUSRARROW
//      / ArrayTypeStart (ByteAlign / KEYWORD_const / KEYWORD_volatile)*
//      / PtrTypeStart (KEYWORD_align LPAREN Expr (COLON INTEGER COLON INTEGER)? RPAREN / KEYWORD_const / KEYWORD_volatile)*
static AstNode *ast_parse_prefix_type_op(ParseContext *pc) {
    Token *questionmark = eat_token_if(pc, TokenIdQuestion);
    if (questionmark != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypePrefixOpExpr, questionmark);
        res->data.prefix_op_expr.prefix_op = PrefixOpOptional;
        return res;
    }

    Token *anyframe = eat_token_if(pc, TokenIdKeywordAnyFrame);
    if (anyframe != nullptr) {
        if (eat_token_if(pc, TokenIdArrow) != nullptr) {
            AstNode *res = ast_create_node(pc, NodeTypeAnyFrameType, anyframe);
            return res;
        }

        put_back_token(pc);
    }

    Token *arr_init_lbracket = eat_token_if(pc, TokenIdLBracket);
    if (arr_init_lbracket != nullptr) {
        Token *underscore = eat_token_if(pc, TokenIdSymbol);
        if (underscore == nullptr) {
            put_back_token(pc);
        } else if (!buf_eql_str(token_buf(underscore), "_")) {
            put_back_token(pc);
            put_back_token(pc);
        } else {
            AstNode *sentinel = nullptr;
            Token *colon = eat_token_if(pc, TokenIdColon);
            if (colon != nullptr) {
                sentinel = ast_expect(pc, ast_parse_expr);
            }
            expect_token(pc, TokenIdRBracket);
            AstNode *node = ast_create_node(pc, NodeTypeInferredArrayType, arr_init_lbracket);
            node->data.inferred_array_type.sentinel = sentinel;
            return node;
        }
    }


    AstNode *ptr = ast_parse_ptr_type_start(pc);
    if (ptr != nullptr) {
        assert(ptr->type == NodeTypePointerType);
        // We might get two pointers from *_ptr_type_start
        AstNode *child = ptr->data.pointer_type.op_expr;
        if (child == nullptr)
            child = ptr;
        while (true) {
            Token *allowzero_token = eat_token_if(pc, TokenIdKeywordAllowZero);
            if (allowzero_token != nullptr) {
                child->data.pointer_type.allow_zero_token = allowzero_token;
                continue;
            }

            if (eat_token_if(pc, TokenIdKeywordAlign) != nullptr) {
                expect_token(pc, TokenIdLParen);
                AstNode *align_expr = ast_expect(pc, ast_parse_expr);
                child->data.pointer_type.align_expr = align_expr;
                if (eat_token_if(pc, TokenIdColon) != nullptr) {
                    Token *bit_offset_start = expect_token(pc, TokenIdIntLiteral);
                    expect_token(pc, TokenIdColon);
                    Token *host_int_bytes = expect_token(pc, TokenIdIntLiteral);
                    child->data.pointer_type.bit_offset_start = token_bigint(bit_offset_start);
                    child->data.pointer_type.host_int_bytes = token_bigint(host_int_bytes);
                }
                expect_token(pc, TokenIdRParen);
                continue;
            }

            if (eat_token_if(pc, TokenIdKeywordConst) != nullptr) {
                child->data.pointer_type.is_const = true;
                continue;
            }

            if (eat_token_if(pc, TokenIdKeywordVolatile) != nullptr) {
                child->data.pointer_type.is_volatile = true;
                continue;
            }

            break;
        }

        return ptr;
    }

    AstNode *array = ast_parse_array_type_start(pc);
    if (array != nullptr) {
        assert(array->type == NodeTypeArrayType);
        while (true) {
            Token *allowzero_token = eat_token_if(pc, TokenIdKeywordAllowZero);
            if (allowzero_token != nullptr) {
                array->data.array_type.allow_zero_token = allowzero_token;
                continue;
            }

            AstNode *align_expr = ast_parse_byte_align(pc);
            if (align_expr != nullptr) {
                array->data.array_type.align_expr = align_expr;
                continue;
            }

            if (eat_token_if(pc, TokenIdKeywordConst) != nullptr) {
                array->data.array_type.is_const = true;
                continue;
            }

            if (eat_token_if(pc, TokenIdKeywordVolatile) != nullptr) {
                array->data.array_type.is_volatile = true;
                continue;
            }
            break;
        }

        return array;
    }


    return nullptr;
}

// SuffixOp
//     <- LBRACKET Expr (DOT2 (Expr (COLON Expr)?)?)? RBRACKET
//      / DOT IDENTIFIER
//      / DOTASTERISK
//      / DOTQUESTIONMARK
static AstNode *ast_parse_suffix_op(ParseContext *pc) {
    Token *lbracket = eat_token_if(pc, TokenIdLBracket);
    if (lbracket != nullptr) {
        AstNode *start = ast_expect(pc, ast_parse_expr);
        AstNode *end = nullptr;
        if (eat_token_if(pc, TokenIdEllipsis2) != nullptr) {
            AstNode *sentinel = nullptr;
            end = ast_parse_expr(pc);
            if (eat_token_if(pc, TokenIdColon) != nullptr) {
                sentinel = ast_parse_expr(pc);
            }
            expect_token(pc, TokenIdRBracket);

            AstNode *res = ast_create_node(pc, NodeTypeSliceExpr, lbracket);
            res->data.slice_expr.start = start;
            res->data.slice_expr.end = end;
            res->data.slice_expr.sentinel = sentinel;
            return res;
        }

        expect_token(pc, TokenIdRBracket);

        AstNode *res = ast_create_node(pc, NodeTypeArrayAccessExpr, lbracket);
        res->data.array_access_expr.subscript = start;
        return res;
    }

    Token *dot_asterisk = eat_token_if(pc, TokenIdDotStar);
    if (dot_asterisk != nullptr)
        return ast_create_node(pc, NodeTypePtrDeref, dot_asterisk);

    Token *dot = eat_token_if(pc, TokenIdDot);
    if (dot != nullptr) {
        if (eat_token_if(pc, TokenIdQuestion) != nullptr)
            return ast_create_node(pc, NodeTypeUnwrapOptional, dot);

        Token *ident = expect_token(pc, TokenIdSymbol);
        AstNode *res = ast_create_node(pc, NodeTypeFieldAccessExpr, dot);
        res->data.field_access_expr.field_name = token_buf(ident);
        return res;
    }

    return nullptr;
}

// FnCallArguments <- LPAREN ExprList RPAREN
static AstNode *ast_parse_fn_call_arguments(ParseContext *pc) {
    Token *paren = eat_token_if(pc, TokenIdLParen);
    if (paren == nullptr)
        return nullptr;

    ZigList<AstNode *> params = ast_parse_list(pc, TokenIdComma, ast_parse_expr);
    expect_token(pc, TokenIdRParen);

    AstNode *res = ast_create_node(pc, NodeTypeFnCallExpr, paren);
    res->data.fn_call_expr.params = params;
    res->data.fn_call_expr.seen = false;
    return res;
}

// ArrayTypeStart <- LBRACKET Expr? RBRACKET
static AstNode *ast_parse_array_type_start(ParseContext *pc) {
    Token *lbracket = eat_token_if(pc, TokenIdLBracket);
    if (lbracket == nullptr)
        return nullptr;

    AstNode *size = ast_parse_expr(pc);
    AstNode *sentinel = nullptr;
    Token *colon = eat_token_if(pc, TokenIdColon);
    if (colon != nullptr) {
        sentinel = ast_expect(pc, ast_parse_expr);
    }
    expect_token(pc, TokenIdRBracket);
    AstNode *res = ast_create_node(pc, NodeTypeArrayType, lbracket);
    res->data.array_type.size = size;
    res->data.array_type.sentinel = sentinel;
    return res;
}

// PtrTypeStart
//     <- ASTERISK
//      / ASTERISK2
//      / PTRUNKNOWN
//      / PTRC
static AstNode *ast_parse_ptr_type_start(ParseContext *pc) {
    AstNode *sentinel = nullptr;

    Token *asterisk = eat_token_if(pc, TokenIdStar);
    if (asterisk != nullptr) {
        Token *colon = eat_token_if(pc, TokenIdColon);
        if (colon != nullptr) {
            sentinel = ast_expect(pc, ast_parse_expr);
        }
        AstNode *res = ast_create_node(pc, NodeTypePointerType, asterisk);
        res->data.pointer_type.star_token = asterisk;
        res->data.pointer_type.sentinel = sentinel;
        return res;
    }

    Token *asterisk2 = eat_token_if(pc, TokenIdStarStar);
    if (asterisk2 != nullptr) {
        Token *colon = eat_token_if(pc, TokenIdColon);
        if (colon != nullptr) {
            sentinel = ast_expect(pc, ast_parse_expr);
        }
        AstNode *res = ast_create_node(pc, NodeTypePointerType, asterisk2);
        AstNode *res2 = ast_create_node(pc, NodeTypePointerType, asterisk2);
        res->data.pointer_type.star_token = asterisk2;
        res2->data.pointer_type.star_token = asterisk2;
        res2->data.pointer_type.sentinel = sentinel;
        res->data.pointer_type.op_expr = res2;
        return res;
    }

    Token *lbracket = eat_token_if(pc, TokenIdLBracket);
    if (lbracket != nullptr) {
        Token *star = eat_token_if(pc, TokenIdStar);
        if (star == nullptr) {
            put_back_token(pc);
        } else {
            Token *c_tok = eat_token_if(pc, TokenIdSymbol);
            if (c_tok != nullptr) {
                if (!buf_eql_str(token_buf(c_tok), "c")) {
                    put_back_token(pc); // c symbol
                } else {
                    expect_token(pc, TokenIdRBracket);
                    AstNode *res = ast_create_node(pc, NodeTypePointerType, lbracket);
                    res->data.pointer_type.star_token = c_tok;
                    return res;
                }
            }

            Token *colon = eat_token_if(pc, TokenIdColon);
            if (colon != nullptr) {
                sentinel = ast_expect(pc, ast_parse_expr);
            }
            expect_token(pc, TokenIdRBracket);
            AstNode *res = ast_create_node(pc, NodeTypePointerType, lbracket);
            res->data.pointer_type.star_token = lbracket;
            res->data.pointer_type.sentinel = sentinel;
            return res;
        }
    }

    return nullptr;
}

// ContainerDeclAuto <- ContainerDeclType LBRACE ContainerMembers RBRACE
static AstNode *ast_parse_container_decl_auto(ParseContext *pc) {
    AstNode *res = ast_parse_container_decl_type(pc);
    if (res == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLBrace);
    AstNodeContainerDecl members = ast_parse_container_members(pc);
    expect_token(pc, TokenIdRBrace);

    res->data.container_decl.fields = members.fields;
    res->data.container_decl.decls = members.decls;
    if (buf_len(&members.doc_comments) != 0) {
        res->data.container_decl.doc_comments = members.doc_comments;
    }
    return res;
}

// ContainerDeclType
//     <- KEYWORD_struct
//      / KEYWORD_enum (LPAREN Expr RPAREN)?
//      / KEYWORD_union (LPAREN (KEYWORD_enum (LPAREN Expr RPAREN)? / Expr) RPAREN)?
//      / KEYWORD_opaque
static AstNode *ast_parse_container_decl_type(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordStruct);
    if (first != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeContainerDecl, first);
        res->data.container_decl.init_arg_expr = nullptr;
        res->data.container_decl.kind = ContainerKindStruct;
        return res;
    }

    first = eat_token_if(pc, TokenIdKeywordOpaque);
    if (first != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeContainerDecl, first);
        res->data.container_decl.init_arg_expr = nullptr;
        res->data.container_decl.kind = ContainerKindOpaque;
        return res;
    }

    first = eat_token_if(pc, TokenIdKeywordEnum);
    if (first != nullptr) {
        AstNode *init_arg_expr = nullptr;
        if (eat_token_if(pc, TokenIdLParen) != nullptr) {
            init_arg_expr = ast_expect(pc, ast_parse_expr);
            expect_token(pc, TokenIdRParen);
        }
        AstNode *res = ast_create_node(pc, NodeTypeContainerDecl, first);
        res->data.container_decl.init_arg_expr = init_arg_expr;
        res->data.container_decl.kind = ContainerKindEnum;
        return res;
    }

    first = eat_token_if(pc, TokenIdKeywordUnion);
    if (first != nullptr) {
        AstNode *init_arg_expr = nullptr;
        bool auto_enum = false;
        if (eat_token_if(pc, TokenIdLParen) != nullptr) {
            if (eat_token_if(pc, TokenIdKeywordEnum) != nullptr) {
                auto_enum = true;
                if (eat_token_if(pc, TokenIdLParen) != nullptr) {
                    init_arg_expr = ast_expect(pc, ast_parse_expr);
                    expect_token(pc, TokenIdRParen);
                }
            } else {
                init_arg_expr = ast_expect(pc, ast_parse_expr);
            }

            expect_token(pc, TokenIdRParen);
        }

        AstNode *res = ast_create_node(pc, NodeTypeContainerDecl, first);
        res->data.container_decl.init_arg_expr = init_arg_expr;
        res->data.container_decl.auto_enum = auto_enum;
        res->data.container_decl.kind = ContainerKindUnion;
        return res;
    }

    return nullptr;
}

// ByteAlign <- KEYWORD_align LPAREN Expr RPAREN
static AstNode *ast_parse_byte_align(ParseContext *pc) {
    if (eat_token_if(pc, TokenIdKeywordAlign) == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLParen);
    AstNode *res = ast_expect(pc, ast_parse_expr);
    expect_token(pc, TokenIdRParen);
    return res;
}

static void visit_field(AstNode **node, void (*visit)(AstNode **, void *context), void *context) {
    if (*node) {
        visit(node, context);
    }
}

static void visit_node_list(ZigList<AstNode *> *list, void (*visit)(AstNode **, void *context), void *context) {
    if (list) {
        for (size_t i = 0; i < list->length; i += 1) {
            visit(&list->at(i), context);
        }
    }
}

void ast_visit_node_children(AstNode *node, void (*visit)(AstNode **, void *context), void *context) {
    switch (node->type) {
        case NodeTypeFnProto:
            visit_field(&node->data.fn_proto.return_type, visit, context);
            visit_node_list(&node->data.fn_proto.params, visit, context);
            visit_field(&node->data.fn_proto.align_expr, visit, context);
            visit_field(&node->data.fn_proto.section_expr, visit, context);
            break;
        case NodeTypeFnDef:
            visit_field(&node->data.fn_def.fn_proto, visit, context);
            visit_field(&node->data.fn_def.body, visit, context);
            break;
        case NodeTypeParamDecl:
            visit_field(&node->data.param_decl.type, visit, context);
            break;
        case NodeTypeBlock:
            visit_node_list(&node->data.block.statements, visit, context);
            break;
        case NodeTypeGroupedExpr:
            visit_field(&node->data.grouped_expr, visit, context);
            break;
        case NodeTypeReturnExpr:
            visit_field(&node->data.return_expr.expr, visit, context);
            break;
        case NodeTypeDefer:
            visit_field(&node->data.defer.expr, visit, context);
            visit_field(&node->data.defer.err_payload, visit, context);
            break;
        case NodeTypeVariableDeclaration:
            visit_field(&node->data.variable_declaration.type, visit, context);
            visit_field(&node->data.variable_declaration.expr, visit, context);
            visit_field(&node->data.variable_declaration.align_expr, visit, context);
            visit_field(&node->data.variable_declaration.section_expr, visit, context);
            break;
        case NodeTypeTestDecl:
            visit_field(&node->data.test_decl.body, visit, context);
            break;
        case NodeTypeBinOpExpr:
            visit_field(&node->data.bin_op_expr.op1, visit, context);
            visit_field(&node->data.bin_op_expr.op2, visit, context);
            break;
        case NodeTypeCatchExpr:
            visit_field(&node->data.unwrap_err_expr.op1, visit, context);
            visit_field(&node->data.unwrap_err_expr.symbol, visit, context);
            visit_field(&node->data.unwrap_err_expr.op2, visit, context);
            break;
        case NodeTypeIntLiteral:
            // none
            break;
        case NodeTypeFloatLiteral:
            // none
            break;
        case NodeTypeStringLiteral:
            // none
            break;
        case NodeTypeCharLiteral:
            // none
            break;
        case NodeTypeSymbol:
            // none
            break;
        case NodeTypePrefixOpExpr:
            visit_field(&node->data.prefix_op_expr.primary_expr, visit, context);
            break;
        case NodeTypeFnCallExpr:
            visit_field(&node->data.fn_call_expr.fn_ref_expr, visit, context);
            visit_node_list(&node->data.fn_call_expr.params, visit, context);
            break;
        case NodeTypeArrayAccessExpr:
            visit_field(&node->data.array_access_expr.array_ref_expr, visit, context);
            visit_field(&node->data.array_access_expr.subscript, visit, context);
            break;
        case NodeTypeSliceExpr:
            visit_field(&node->data.slice_expr.array_ref_expr, visit, context);
            visit_field(&node->data.slice_expr.start, visit, context);
            visit_field(&node->data.slice_expr.end, visit, context);
            visit_field(&node->data.slice_expr.sentinel, visit, context);
            break;
        case NodeTypeFieldAccessExpr:
            visit_field(&node->data.field_access_expr.struct_expr, visit, context);
            break;
        case NodeTypePtrDeref:
            visit_field(&node->data.ptr_deref_expr.target, visit, context);
            break;
        case NodeTypeUnwrapOptional:
            visit_field(&node->data.unwrap_optional.expr, visit, context);
            break;
        case NodeTypeUsingNamespace:
            visit_field(&node->data.using_namespace.expr, visit, context);
            break;
        case NodeTypeBoolLiteral:
            // none
            break;
        case NodeTypeNullLiteral:
            // none
            break;
        case NodeTypeUndefinedLiteral:
            // none
            break;
        case NodeTypeIfBoolExpr:
            visit_field(&node->data.if_bool_expr.condition, visit, context);
            visit_field(&node->data.if_bool_expr.then_block, visit, context);
            visit_field(&node->data.if_bool_expr.else_node, visit, context);
            break;
        case NodeTypeIfErrorExpr:
            visit_field(&node->data.if_err_expr.target_node, visit, context);
            visit_field(&node->data.if_err_expr.then_node, visit, context);
            visit_field(&node->data.if_err_expr.else_node, visit, context);
            break;
        case NodeTypeIfOptional:
            visit_field(&node->data.test_expr.target_node, visit, context);
            visit_field(&node->data.test_expr.then_node, visit, context);
            visit_field(&node->data.test_expr.else_node, visit, context);
            break;
        case NodeTypeWhileExpr:
            visit_field(&node->data.while_expr.condition, visit, context);
            visit_field(&node->data.while_expr.body, visit, context);
            break;
        case NodeTypeForExpr:
            visit_field(&node->data.for_expr.elem_node, visit, context);
            visit_field(&node->data.for_expr.array_expr, visit, context);
            visit_field(&node->data.for_expr.index_node, visit, context);
            visit_field(&node->data.for_expr.body, visit, context);
            break;
        case NodeTypeSwitchExpr:
            visit_field(&node->data.switch_expr.expr, visit, context);
            visit_node_list(&node->data.switch_expr.prongs, visit, context);
            break;
        case NodeTypeSwitchProng:
            visit_node_list(&node->data.switch_prong.items, visit, context);
            visit_field(&node->data.switch_prong.var_symbol, visit, context);
            visit_field(&node->data.switch_prong.expr, visit, context);
            break;
        case NodeTypeSwitchRange:
            visit_field(&node->data.switch_range.start, visit, context);
            visit_field(&node->data.switch_range.end, visit, context);
            break;
        case NodeTypeCompTime:
            visit_field(&node->data.comptime_expr.expr, visit, context);
            break;
        case NodeTypeNoSuspend:
            visit_field(&node->data.comptime_expr.expr, visit, context);
            break;
        case NodeTypeBreak:
            // none
            break;
        case NodeTypeContinue:
            // none
            break;
        case NodeTypeUnreachable:
            // none
            break;
        case NodeTypeAsmExpr:
            for (size_t i = 0; i < node->data.asm_expr.input_list.length; i += 1) {
                AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
                visit_field(&asm_input->expr, visit, context);
            }
            for (size_t i = 0; i < node->data.asm_expr.output_list.length; i += 1) {
                AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
                visit_field(&asm_output->return_type, visit, context);
            }
            break;
        case NodeTypeContainerDecl:
            visit_node_list(&node->data.container_decl.fields, visit, context);
            visit_node_list(&node->data.container_decl.decls, visit, context);
            visit_field(&node->data.container_decl.init_arg_expr, visit, context);
            break;
        case NodeTypeStructField:
            visit_field(&node->data.struct_field.type, visit, context);
            visit_field(&node->data.struct_field.value, visit, context);
            break;
        case NodeTypeContainerInitExpr:
            visit_field(&node->data.container_init_expr.type, visit, context);
            visit_node_list(&node->data.container_init_expr.entries, visit, context);
            break;
        case NodeTypeStructValueField:
            visit_field(&node->data.struct_val_field.expr, visit, context);
            break;
        case NodeTypeArrayType:
            visit_field(&node->data.array_type.size, visit, context);
            visit_field(&node->data.array_type.sentinel, visit, context);
            visit_field(&node->data.array_type.child_type, visit, context);
            visit_field(&node->data.array_type.align_expr, visit, context);
            break;
        case NodeTypeInferredArrayType:
            visit_field(&node->data.array_type.sentinel, visit, context);
            visit_field(&node->data.array_type.child_type, visit, context);
            break;
        case NodeTypeAnyFrameType:
            visit_field(&node->data.anyframe_type.payload_type, visit, context);
            break;
        case NodeTypeErrorType:
            // none
            break;
        case NodeTypePointerType:
            visit_field(&node->data.pointer_type.sentinel, visit, context);
            visit_field(&node->data.pointer_type.align_expr, visit, context);
            visit_field(&node->data.pointer_type.op_expr, visit, context);
            break;
        case NodeTypeErrorSetDecl:
            visit_node_list(&node->data.err_set_decl.decls, visit, context);
            break;
        case NodeTypeErrorSetField:
            visit_field(&node->data.err_set_field.field_name, visit, context);
            break;
        case NodeTypeResume:
            visit_field(&node->data.resume_expr.expr, visit, context);
            break;
        case NodeTypeAwaitExpr:
            visit_field(&node->data.await_expr.expr, visit, context);
            break;
        case NodeTypeSuspend:
            visit_field(&node->data.suspend.block, visit, context);
            break;
        case NodeTypeEnumLiteral:
        case NodeTypeAnyTypeField:
            break;
    }
}
