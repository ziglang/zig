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
    ImportTableEntry *owner;
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

ATTRIBUTE_PRINTF(3, 4)
ATTRIBUTE_NORETURN
static void ast_error(ParseContext *pc, Token *token, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);


    ErrorMsg *err = err_msg_create_with_line(pc->owner->path, token->start_line, token->start_column,
            pc->owner->source_code, pc->owner->line_offsets, msg);
    err->line_start = token->start_line;
    err->column_start = token->start_column;

    print_err_msg(err, pc->err_color);
    exit(EXIT_FAILURE);
}

static Buf ast_token_str(Buf *input, Token *token) {
    Buf str = BUF_INIT;
    buf_init_from_mem(&str, buf_ptr(input) + token->start_pos, token->end_pos - token->start_pos);
    return str;
}

ATTRIBUTE_NORETURN
static void ast_invalid_token_error(ParseContext *pc, Token *token) {
    Buf token_value = ast_token_str(pc->buf, token);
    ast_error(pc, token, "invalid token: '%s'", buf_ptr(&token_value));
}

static AstNode *ast_create_node_no_line_info(ParseContext *pc, NodeType type) {
    AstNode *node = allocate<AstNode>(1);
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
    if (res->id == id)
        ast_error(pc, res, "expected token '%s', found '%s'", token_name(id), token_name(res->id));

    return res;
}

static void put_back_token(ParseContext *pc) {
    pc->current_token -= 1;
}

static Buf *token_buf(Token *token) {
    assert(token->id == TokenIdStringLiteral || token->id == TokenIdSymbol);
    return &token->data.str_lit.str;
}

// (Rule SEP)* Rule?
static ZigList<AstNode *> ast_parse_list(ParseContext *pc, TokenId sep, AstNode *(*parser)(ParseContext*)) {
    ZigList<AstNode *> res = {0};
    while (true) {
        AstNode *curr = parser(pc);
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

// Child (Op Child)(*/?)
static AstNode *ast_parse_bin_op(
    ParseContext *pc,
    BinOpChain chain,
    Optional<BinOpType> (*op_parse)(ParseContext*),
    AstNode *(*child_parse)(ParseContext*)
) {
    AstNode *res = child_parse(pc);
    if (res == nullptr)
        return nullptr;

    do {
        Token *op_token = peek_token(pc);
        BinOpType op;
        if (!op_parse(pc).unwrap(&op))
            break;

        AstNode *left = res;
        AstNode *right = ast_expect(pc, child_parse);
        res = ast_create_node(pc, NodeTypeBinOpExpr, op_token);
        res->data.bin_op_expr.op1 = left;
        res->data.bin_op_expr.bin_op = op;
        res->data.bin_op_expr.op2 = right;
    } while (chain == BinOpChainInf);

    return res;
}

static AstNode *ast_parse_root(ParseContext *pc);
static AstNodeContainerDecl ast_parse_container_members(ParseContext *pc);
static AstNode *ast_parse_test_decl(ParseContext *pc);
static AstNode *ast_parse_top_level_comptime(ParseContext *pc);
static AstNode *ast_parse_top_level_decl(ParseContext *pc, VisibMod visib_mod);
static AstNode *ast_parse_fn_proto(ParseContext *pc);
static AstNode *ast_parse_var_decl(ParseContext *pc);
static AstNode *ast_parse_container_field(ParseContext *pc);
static AstNode *ast_parse_statement(ParseContext *pc);
static AstNode *ast_parse_if_statement(ParseContext *pc);
static AstNode *ast_parse_while_statement(ParseContext *pc);
static AstNode *ast_parse_for_statement(ParseContext *pc);
static AstNode *ast_parse_block_expr_statement(ParseContext *pc);
static AstNode *ast_parse_assign_expr(ParseContext *pc);
static AstNode *ast_parse_expr(ParseContext *pc);
static AstNode *ast_parse_bool_and_expr(ParseContext *pc);
static AstNode *ast_parse_compare_expr(ParseContext *pc);
static AstNode *ast_parse_bitwise_expr(ParseContext *pc);
static AstNode *ast_parse_bit_shit_expr(ParseContext *pc);
static AstNode *ast_parse_addition_expr(ParseContext *pc);
static AstNode *ast_parse_multiply_expr(ParseContext *pc);
static AstNode *ast_parse_curly_suffix_expr(ParseContext *pc);
static AstNodeContainerInitExpr ast_parse_init_list(ParseContext *pc);
static AstNode *ast_parse_type_expr(ParseContext *pc);
static AstNode *ast_parse_prefix_expr(ParseContext *pc);
static AstNode *ast_parse_suffix_expr(ParseContext *pc);
static AstNode *ast_parse_primary_expr(ParseContext *pc);
static AstNode *ast_parse_block_expr(ParseContext *pc);
static AstNode *ast_parse_block(ParseContext *pc);
static AstNode *ast_parse_container_decl(ParseContext *pc);
static AstNode *ast_parse_error_set_decl(ParseContext *pc);
static AstNode *ast_parse_for_expr(ParseContext *pc);
static AstNode *ast_parse_grouped_expr(ParseContext *pc);
static AstNode *ast_parse_if_expr(ParseContext *pc);
static AstNode *ast_parse_switch_expr(ParseContext *pc);
static AstNode *ast_parse_while_expr(ParseContext *pc);
static AstNode *ast_parse_asm_expr(ParseContext *pc);
static Optional<AstNodeAsmExpr> ast_parse_asm_output(ParseContext *pc);
static AstNode *ast_parse_asm_output_item(ParseContext *pc);
static AstNode *ast_parse_asm_input(ParseContext *pc);
static AstNode *ast_parse_asm_input_item(ParseContext *pc);
static AstNode *ast_parse_asm_cloppers(ParseContext *pc);
static Token * ast_parse_break_label(ParseContext *pc);
static Token *ast_parse_block_label(ParseContext *pc);
static AstNode *ast_parse_field_init(ParseContext *pc);
static AstNode *ast_parse_while_continue_expr(ParseContext *pc);
static AstNode *ast_parse_section(ParseContext *pc);
static AstNodeFnProto ast_parse_fn_cc(ParseContext *pc);
static AstNode *ast_parse_param_decl(ParseContext *pc);
static AstNode *ast_parse_param_type(ParseContext *pc);
static Optional<AstNodeTestExpr> ast_parse_if_prefix(ParseContext *pc);
static Optional<AstNodeWhileExpr> ast_parse_while_prefix(ParseContext *pc);
static Optional<AstNodeForExpr> ast_parse_for_prefix(ParseContext *pc);
static Token *ast_parse_payload(ParseContext *pc);
static Optional<PtrPayload> ast_parse_ptr_payload(ParseContext *pc);
static Optional<PtrIndexPayload> ast_parse_ptr_index_payload(ParseContext *pc);
static AstNode *ast_parse_switch_prong(ParseContext *pc);
static AstNode *ast_parse_switch_case(ParseContext *pc);
static AstNode *ast_parse_switch_item(ParseContext *pc);
static Optional<BinOpType> ast_parse_assign_op(ParseContext *pc);
static Optional<BinOpType> ast_parse_compare_op(ParseContext *pc);
static Optional<BinOpType> ast_parse_bitwise_op(ParseContext *pc);
static Optional<BinOpType> ast_parse_bit_shift_op(ParseContext *pc);
static Optional<BinOpType> ast_parse_addition_op(ParseContext *pc);
static Optional<BinOpType> ast_parse_multiply_op(ParseContext *pc);
static AstNode *ast_parse_prefix_op(ParseContext *pc);
static AstNode *ast_parse_suffix_op(ParseContext *pc);
static Optional<AstNodeFnCallExpr> ast_parse_async_prefix(ParseContext *pc);
static Optional<ZigList<AstNode *>> ast_parse_fn_call_argumnets(ParseContext *pc);
static AstNode *ast_parse_ptr_start(ParseContext *pc);
static AstNode *ast_parse_ptr_attribute(ParseContext *pc);
static AstNode *ast_parse_container_decl_auto(ParseContext *pc);
static AstNode *ast_parse_container_decl_type(ParseContext *pc);
static AstNode *ast_parse_byte_align(ParseContext *pc);
static AstNode *ast_parse_bit_align(ParseContext *pc);


AstNode *ast_parse(Buf *buf, ZigList<Token> *tokens, ImportTableEntry *owner,
        ErrColor err_color)
{
    ParseContext pc = {0};
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
    node->data.container_decl = members;
    node->data.container_decl.layout = ContainerLayoutAuto;
    node->data.container_decl.kind = ContainerKindStruct;

    return node;
}

// ContainerMembers
//     <- TestDecl ContainerMembers
//      / TopLevelComptime ContainerMembers
//      / KEYWORD_pub? TopLevelDecl ContainerMembers
//      / KEYWORD_pub? ContainerField COMMA ContainerMembers
//      / KEYWORD_pub? ContainerField
//      /
static AstNodeContainerDecl ast_parse_container_members(ParseContext *pc) {
    AstNodeContainerDecl res = {};
    for (;;) {
        AstNode *test_decl = ast_parse_test_decl(pc);
        if (test_decl != nullptr) {
            res.decls.append(test_decl);
            continue;
        }

        AstNode *top_level_comptime = ast_parse_top_level_comptime(pc);
        if (top_level_comptime != nullptr) {
            res.decls.append(top_level_comptime);
            continue;
        }

        Token *visib_token = eat_token_if(pc, TokenIdKeywordPub);
        VisibMod visib_mod = visib_token != nullptr ? VisibModPub : VisibModPrivate;

        AstNode *top_level_decl = ast_parse_top_level_decl(pc, visib_mod);
        if (top_level_decl != nullptr) {
            res.decls.append(top_level_decl);
            continue;
        }

        AstNode *container_field = ast_parse_container_field(pc);
        if (container_field != nullptr) {
            assert(container_field->type == NodeTypeStructField);
            container_field->data.struct_field.visib_mod = visib_mod;
            res.decls.append(container_field);
            if (eat_token_if(pc, TokenIdComma) != nullptr) {
                continue;
            } else {
                break;
            }
        }

        // We visib_token wasn't eaten, then we haven't consumed the first token in this rule yet.
        // It is therefore safe to return and let the caller continue parsing.
        if (visib_token == nullptr)
            break;

        ast_invalid_token_error(pc, peek_token(pc));
    }

    return res;
}

// TestDecl <- KEYWORD_test STRINGLITERAL Block
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

    AstNode *block = ast_expect(pc, ast_parse_block_expr);
    AstNode *res = ast_create_node(pc, NodeTypeCompTime, comptime);
    res->data.comptime_expr.expr = block;
    return res;
}

// TopLevelDecl
//     <- VarDecl
//      / FnProto (SEMICOLON / Block)
//      / (KEYWORD_inline / KEYWORD_export) FnProto Block
//      / KEYWORD_export VarDecl
//      / KEYWORD_extern STRINGLITERAL? FnProto SEMICOLON
//      / KEYWORD_extern STRINGLITERAL? VarDecl
//      / KEYWORD_use Expr SEMICOLON
static AstNode *ast_parse_top_level_decl(ParseContext *pc, VisibMod visib_mod) {
    AstNode *var_decl = ast_parse_var_decl(pc);
    if (var_decl != nullptr) {
        assert(var_decl->type == NodeTypeVariableDeclaration);
        var_decl->data.variable_declaration.visib_mod = visib_mod;
        return var_decl;
    }

    AstNode *fn_proto = ast_parse_fn_proto(pc);
    if (fn_proto != nullptr) {
        if (eat_token_if(pc, TokenIdSemicolon) != nullptr) {
            assert(fn_proto->type == NodeTypeFnProto);
            fn_proto->data.fn_proto.visib_mod = visib_mod;
            return fn_proto;
        }

        AstNode *block = ast_expect(pc, ast_parse_block);
        AstNode *res = ast_create_node_copy_line_info(pc, NodeTypeFnDef, fn_proto);
        res->data.fn_def.fn_proto = fn_proto;
        res->data.fn_def.body = block;
        fn_proto->data.fn_proto.fn_def_node = res;
        return res;
    }

    Token *export_inline = eat_token_if(pc, TokenIdKeywordExport);
    if (export_inline == nullptr)
        export_inline = eat_token_if(pc, TokenIdKeywordInline);
    if (export_inline != nullptr) {
        if (export_inline->id == TokenIdKeywordExport) {
            AstNode *var_decl = ast_parse_var_decl(pc);
            if (var_decl != nullptr) {
                assert(var_decl->type == NodeTypeVariableDeclaration);
                var_decl->data.variable_declaration.visib_mod = visib_mod;
                var_decl->data.variable_declaration.is_export = true;
                return var_decl;
            }
        }

        AstNode *fn_proto = ast_expect(pc, ast_parse_fn_proto);
        AstNode *block = ast_expect(pc, ast_parse_block);
        AstNode *res = ast_create_node_copy_line_info(pc, NodeTypeFnDef, fn_proto);
        res->data.fn_def.fn_proto = fn_proto;
        res->data.fn_def.body = block;
        fn_proto->data.fn_proto.fn_def_node = res;
        fn_proto->data.fn_proto.is_export = export_inline->id == TokenIdKeywordExport;
        fn_proto->data.fn_proto.is_inline = export_inline->id == TokenIdKeywordInline;
        return res;
    }

    Token *extern_token = eat_token_if(pc, TokenIdKeywordExtern);
    if (extern_token != nullptr) {
        Token *string = eat_token_if(pc, TokenIdStringLiteral);
        Buf *lib_name = nullptr;
        if (string != nullptr)
            lib_name = token_buf(string);

        AstNode *fn_proto = ast_parse_fn_proto(pc);
        if (fn_proto != nullptr) {
            expect_token(pc, TokenIdSemicolon);
            assert(fn_proto->type == NodeTypeFnProto);
            fn_proto->data.fn_proto.visib_mod = visib_mod;
            var_decl->data.fn_proto.is_extern = true;
            var_decl->data.fn_proto.lib_name = lib_name;
            return fn_proto;
        }

        AstNode *var_decl = ast_expect(pc, ast_parse_var_decl);
        assert(var_decl->type == NodeTypeVariableDeclaration);
        var_decl->data.variable_declaration.visib_mod = visib_mod;
        var_decl->data.variable_declaration.is_extern = true;
        var_decl->data.variable_declaration.lib_name = lib_name;
        return var_decl;
    }

    Token *use = eat_token_if(pc, TokenIdKeywordExtern);
    if (use != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_expr);
        expect_token(pc, TokenIdSemicolon);

        AstNode *res = ast_create_node(pc, NodeTypeUse, use);
        res->data.use.visib_mod = visib_mod;
        res->data.use.expr = expr;
        return res;
    }

    return nullptr;
}

// FnProto <- FnCC? KEYWORD_fn IDENTIFIER? LPAREN ParamDecls RPAREN ByteAlign? Section? EXCLAMATIONMARK? ReturnType
static AstNode *ast_parse_fn_proto(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeFnProto fn_cc = ast_parse_fn_cc(pc);
    Token *fn = eat_token_if(pc, TokenIdKeywordFn);
    if (fn == nullptr) {
        // If CC is Unspecified, then we didn't consume the first token
        // so we can safely return null.
        if (fn_cc.cc == CallingConventionUnspecified)
            return nullptr;
        // Because the 'extern' keyword is also used for container decls,
        // we have to put this token back, and return null.
        if (fn_cc.cc == CallingConventionC) {
            put_back_token(pc);
            return nullptr;
        }

        // This should always fail.
        expect_token(pc, TokenIdKeywordFn);
        zig_unreachable();
    }

    Token *identifier = eat_token_if(pc, TokenIdSymbol);
    expect_token(pc, TokenIdLParen);
    ZigList<AstNode *> params = ast_parse_list(pc, TokenIdComma, ast_parse_param_decl);
    expect_token(pc, TokenIdRParen);

    AstNode *align_expr = ast_parse_byte_align(pc);
    AstNode *section_expr = ast_parse_section(pc);
    Token *var = eat_token_if(pc, TokenIdKeywordVar);
    Token *exmark = nullptr;
    AstNode *return_type = nullptr;
    if (var == nullptr) {
        exmark = eat_token_if(pc, TokenIdBang);
        return_type = ast_parse_type_expr(pc);
    }

    AstNode *res = ast_create_node(pc, NodeTypeFnProto, first);
    res->data.fn_proto.cc = fn_cc.cc;
    res->data.fn_proto.async_allocator_type = fn_cc.async_allocator_type;
    res->data.fn_proto.name = identifier != nullptr ? token_buf(identifier) : nullptr;
    res->data.fn_proto.params = params;
    res->data.fn_proto.align_expr = align_expr;
    res->data.fn_proto.section_expr = section_expr;
    res->data.fn_proto.return_var_token = var;
    res->data.fn_proto.auto_err_set = exmark != nullptr;
    res->data.fn_proto.return_type = return_type;

    // It seems that the Zig compiler expects varargs to be the
    // last parameter in the decl list. This is not encoded in
    // the grammar, which allows varargs anywhere in the decl.
    // Since varargs is gonna be removed at some point, I'm not
    // gonna encode this "varargs is always last" rule in the
    // grammar, and just enforce it here, until varargs is removed.
    for (size_t i = 0; i < params.length; i++) {
        AstNode *param_decl = params.at(i);
        assert(param_decl->type == NodeTypeParamDecl);
        if (param_decl->data.param_decl.is_var_args)
            res->data.fn_proto.is_var_args = true;
        if (i != params.length - 1 && res->data.fn_proto.is_var_args)
            ast_error(pc, first, "Function prototype have varargs as a none last paramter.");
    }
    return res;
}

// VarDecl <- (KEYWORD_const / KEYWORD_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? Section? (EQUAL Expr)? SEMICOLON
static AstNode *ast_parse_var_decl(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordConst);
    if (first == nullptr)
        first = eat_token_if(pc, TokenIdKeywordVar);
    if (first == nullptr)
        return nullptr;

    Token *identifier = expect_token(pc, TokenIdSymbol);
    AstNode *type_expr = nullptr;
    if (eat_token_if(pc, TokenIdColon) != nullptr)
        type_expr = ast_expect(pc, ast_parse_type_expr);

    AstNode *align_expr = ast_parse_byte_align(pc);
    AstNode *section_expr = ast_parse_byte_align(pc);
    AstNode *expr = nullptr;
    if (eat_token_if(pc, TokenIdEq) != nullptr)
        expr = ast_expect(pc, ast_parse_expr);

    expect_token(pc, TokenIdSemicolon);

    AstNode *res = ast_create_node(pc, NodeTypeVariableDeclaration, first);
    res->data.variable_declaration.is_const = first->id == TokenIdKeywordConst;
    res->data.variable_declaration.symbol = token_buf(identifier);
    res->data.variable_declaration.type = type_expr;
    res->data.variable_declaration.align_expr = align_expr;
    res->data.variable_declaration.section_expr = section_expr;
    res->data.variable_declaration.expr = expr;
    return res;
}

// ContainerField <- IDENTIFIER (COLON TypeExpr)? (EQUAL Expr)?
static AstNode *ast_parse_container_field(ParseContext *pc) {
    Token *identifier = eat_token_if(pc, TokenIdSymbol);
    if (identifier == nullptr)
        return nullptr;

    AstNode *type_expr = nullptr;
    if (eat_token_if(pc, TokenIdColon) != nullptr)
        type_expr = ast_expect(pc, ast_parse_type_expr);
    AstNode *expr = nullptr;
    if (eat_token_if(pc, TokenIdEq) != nullptr)
        type_expr = ast_expect(pc, ast_parse_expr);


    AstNode *res = ast_create_node(pc, NodeTypeStructField, identifier);
    res->data.struct_field.name = token_buf(identifier);
    res->data.struct_field.type = type_expr;
    res->data.struct_field.value = expr;
    return res;
}

// Statement
//     <- KEYWORD_comptime? VarDecl
//      / KEYWORD_comptime BlockExprStatement
//      / KEYWORD_suspend (SEMICOLON / BlockExprStatement)
//      / KEYWORD_defer BlockExprStatement
//      / KEYWORD_errdefer BlockExprStatement
//      / IfStatement
//      / WhileStatement
//      / ForStatement
//      / SwitchExpr
//      / BlockExprStatement
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
        AstNode *statement = ast_expect(pc, ast_parse_block_expr_statement);
        AstNode *res = ast_create_node(pc, NodeTypeDefer, defer);
        res->data.defer.kind = ReturnKindUnconditional;
        res->data.defer.expr = statement;
        if (defer->id == TokenIdKeywordErrdefer)
            res->data.defer.kind = ReturnKindError;
        return res;
    }

    AstNode *if_statement = ast_parse_if_statement(pc);
    if (if_statement != nullptr)
        return if_statement;

    AstNode *while_statement = ast_parse_while_statement(pc);
    if (while_statement != nullptr)
        return while_statement;

    AstNode *for_statement = ast_parse_for_statement(pc);
    if (for_statement != nullptr)
        return for_statement;

    AstNode *switch_expr = ast_parse_switch_expr(pc);
    if (switch_expr != nullptr)
        return switch_expr;

    AstNode *statement = ast_parse_block_expr_statement(pc);
    if (statement != nullptr)
        return statement;

    return nullptr;
}

// IfStatement
//     <- IfPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / IfPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
static AstNode *ast_parse_if_statement(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeTestExpr prefix;
    if (!ast_parse_if_prefix(pc).unwrap(&prefix))
        return nullptr;

    AstNode *body = ast_parse_block_expr(pc);
    bool requires_semi = false;
    if (body == nullptr) {
        requires_semi = true;
        body = ast_parse_assign_expr(pc);
    }

    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, ast_parse_statement);
    }

    if (requires_semi && else_body == nullptr)
        expect_token(pc, TokenIdSemicolon);

    if (err_payload != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeIfErrorExpr, first);
        res->data.if_err_expr.target_node = prefix.target_node;
        res->data.if_err_expr.var_is_ptr = prefix.var_is_ptr;
        res->data.if_err_expr.var_symbol = prefix.var_symbol;
        res->data.if_err_expr.then_node = body;
        res->data.if_err_expr.err_symbol = token_buf(err_payload);
        res->data.if_err_expr.else_node = else_body;
        return res;
    }

    if (prefix.var_symbol != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeTestExpr, first);
        res->data.test_expr = prefix;
        res->data.test_expr.then_node = body;
        res->data.test_expr.else_node = else_body;
        return res;
    }

    AstNode *res = ast_create_node(pc, NodeTypeIfBoolExpr, first);
    res->data.if_bool_expr.condition = prefix.target_node;
    res->data.if_bool_expr.then_block = body;
    res->data.if_bool_expr.else_node = else_body;
    return res;
}

// WhileStatement
//     <- WhilePrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
static AstNode *ast_parse_while_statement(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeWhileExpr prefix;
    if (!ast_parse_while_prefix(pc).unwrap(&prefix))
        return nullptr;

    AstNode *body = ast_parse_block_expr(pc);
    bool requires_semi = false;
    if (body == nullptr) {
        requires_semi = true;
        body = ast_parse_assign_expr(pc);
    }

    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, ast_parse_statement);
    }

    if (requires_semi && else_body == nullptr)
        expect_token(pc, TokenIdSemicolon);

    AstNode *res = ast_create_node(pc, NodeTypeWhileExpr, first);
    res->data.while_expr = prefix;
    res->data.while_expr.body = body;
    res->data.while_expr.err_symbol = token_buf(err_payload);
    res->data.while_expr.else_node = else_body;
    return res;
}

// ForStatement
//     <- ForPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / ForPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
static AstNode *ast_parse_for_statement(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeForExpr prefix;
    if (!ast_parse_for_prefix(pc).unwrap(&prefix))
        return nullptr;

    AstNode *body = ast_parse_block_expr(pc);
    bool requires_semi = false;
    if (body == nullptr) {
        requires_semi = true;
        body = ast_parse_assign_expr(pc);
    }

    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        else_body = ast_expect(pc, ast_parse_statement);
    }

    if (requires_semi && else_body == nullptr)
        expect_token(pc, TokenIdSemicolon);

    AstNode *res = ast_create_node(pc, NodeTypeForExpr, first);
    res->data.for_expr = prefix;
    res->data.for_expr.body = body;
    res->data.for_expr.else_node = else_body;
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

// AssignExpr <- Expr (AssignOp Expr)?
static AstNode *ast_parse_assign_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainOnce, ast_parse_assign_op, ast_parse_expr);
}

// Expr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*
static AstNode *ast_parse_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainInf, [](ParseContext *pc) {
        if (eat_token_if(pc, TokenIdKeywordOr) != nullptr)
            return Optional<BinOpType>::some(BinOpTypeBoolOr);

        return Optional<BinOpType>::none();
    }, ast_parse_bool_and_expr);
}

// BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*
static AstNode *ast_parse_bool_and_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainInf, [](ParseContext *pc) {
        if (eat_token_if(pc, TokenIdKeywordAnd) != nullptr)
            return Optional<BinOpType>::some(BinOpTypeBoolAnd);

        return Optional<BinOpType>::none();
    }, ast_parse_compare_expr);
}

// CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)?
static AstNode *ast_parse_compare_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainInf, ast_parse_compare_op, ast_parse_bitwise_expr);
}

//BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)*
static AstNode *ast_parse_bitwise_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainInf, ast_parse_bitwise_op, ast_parse_bit_shit_expr);
}

// BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)*
static AstNode *ast_parse_bit_shit_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainInf, ast_parse_bit_shift_op, ast_parse_addition_expr);
}

// AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*
static AstNode *ast_parse_addition_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainInf, ast_parse_addition_op, ast_parse_multiply_expr);
}

// MultiplyExpr <- CurlySuffixExpr (MultiplyOp CurlySuffixExpr)*
static AstNode *ast_parse_multiply_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainInf, ast_parse_multiply_op, ast_parse_curly_suffix_expr);
}

// CurlySuffixExpr <- TypeExpr (LBRACE InitList RBRACE)?
static AstNode *ast_parse_curly_suffix_expr(ParseContext *pc) {
    AstNode *type_expr = ast_parse_type_expr(pc);
    if (type_expr == nullptr)
        return type_expr;

    Token *lbrace = eat_token_if(pc, TokenIdLBrace);
    if (lbrace == nullptr)
        return type_expr;

    AstNodeContainerInitExpr list = ast_parse_init_list(pc);
    expect_token(pc, TokenIdRBrace);

    AstNode *res = ast_create_node(pc, NodeTypeContainerInitExpr, lbrace);
    res->data.container_init_expr = list;
    res->data.container_init_expr.type = type_expr;
    return res;
}

// InitList
//     <- FieldInit (COMMA FieldInit)* COMMA?
//      / Expr (COMMA Expr)* COMMA?
//      /
static AstNodeContainerInitExpr ast_parse_init_list(ParseContext *pc) {
    AstNode *first = ast_parse_field_init(pc);
    if (first != nullptr) {
        AstNodeContainerInitExpr res = {};
        res.kind = ContainerInitKindStruct;
        res.entries.append(first);

        while (eat_token_if(pc, TokenIdComma) != nullptr) {
            res.entries.append(ast_expect(pc, ast_parse_field_init));
        }

        eat_token_if(pc, TokenIdComma);
        return res;
    }

    AstNodeContainerInitExpr res = {};
    res.kind = ContainerInitKindArray;

    first = ast_parse_expr(pc);
    if (first != nullptr) {
        res.entries.append(first);

        while (eat_token_if(pc, TokenIdComma) != nullptr) {
            res.entries.append(ast_expect(pc, ast_parse_expr));
        }

        eat_token_if(pc, TokenIdComma);
        return res;
    }

    return res;
}

// TypeExpr <- PrefixExpr (EXCLAMATIONMARK PrefixExpr)?
static AstNode *ast_parse_type_expr(ParseContext *pc) {
    return ast_parse_bin_op(pc, BinOpChainOnce, [](ParseContext *pc) {
        if (eat_token_if(pc, TokenIdBang) != nullptr)
            return Optional<BinOpType>::some(BinOpTypeErrorUnion);

        return Optional<BinOpType>::none();
    }, ast_parse_compare_expr);
}

// PrefixExpr
//     <- PrefixOp PrefixExpr
//      / SuffixExpr
static AstNode *ast_parse_prefix_expr(ParseContext *pc) {
    AstNode *res = nullptr;
    AstNode **right = &res;
    while (true) {
        AstNode *prefix = ast_parse_prefix_op(pc);
        if (prefix == nullptr)
            break;

        *right = prefix;
        switch (prefix->type) {
            case NodeTypePrefixOpExpr:
                right = &prefix->data.prefix_op_expr.primary_expr;
                break;
            case NodeTypePointerType:
                right = &prefix->data.pointer_type.op_expr;
                break;
            default:
                zig_unreachable();
        }
    }

    // If we have already consumed a token, and determined that
    // this node is a prefix op, then we expect that the node has
    // a child.
    if (res != nullptr) {
        *right = ast_expect(pc, ast_parse_suffix_expr);
    } else {
        // Otherwise, if we didn't consume a token, then we can return
        // null, if the child expr did.
        *right = ast_parse_suffix_expr(pc);
        if (*right == nullptr)
            return nullptr;
    }

    return res;
}

// SuffixExpr
//     <- AsyncPrefix PrimaryExpr SuffixOp* FnCallArgumnets
//      / PrimaryExpr (SuffixOp / FnCallArgumnets)*
static AstNode *ast_parse_suffix_expr(ParseContext *pc) {
    AstNodeFnCallExpr prefix;
    if (ast_parse_async_prefix(pc).unwrap(&prefix)) {
        AstNode *child = ast_expect(pc, ast_parse_primary_expr);
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

        ZigList<AstNode *> params;
        Token *first = peek_token(pc);
        if (!ast_parse_fn_call_argumnets(pc).unwrap(&params))
            ast_invalid_token_error(pc, peek_token(pc));

        AstNode *res = ast_create_node(pc, NodeTypeFnCallExpr, first);
        res->data.fn_call_expr.fn_ref_expr = child;
        res->data.fn_call_expr.params = params;
        res->data.fn_call_expr.is_builtin = false;
        res->data.fn_call_expr.is_async = true;
        res->data.fn_call_expr.async_allocator = prefix.async_allocator;
        return res;
    }

    AstNode *res = ast_parse_prefix_expr(pc);
    if (res == nullptr)
        return nullptr;

    while (true) {
        Token *first = peek_token(pc);
        AstNode *suffix = ast_parse_suffix_op(pc);
        ZigList<AstNode *> params;
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
        } else if (ast_parse_fn_call_argumnets(pc).unwrap(&params)) {
            AstNode *call = ast_create_node(pc, NodeTypeFnCallExpr, first);
            call->data.fn_call_expr.fn_ref_expr = res;
            call->data.fn_call_expr.params = params;
            call->data.fn_call_expr.is_builtin = false;
            call->data.fn_call_expr.is_async = false;
            call->data.fn_call_expr.async_allocator = nullptr;
            res = call;
        } else {
            break;
        }
    }

    return res;

}

// PrimaryExpr
//     <- AsmExpr
//      / BlockExpr
//      / ContainerDecl
//      / ErrorSetDecl
//      / FnProto
//      / ForExpr
//      / GroupedExpr
//      / IfExpr
//      / SwitchExpr
//      / WhileExpr
//      / BUILTININDENTIFIER FnCallArgumnets
//      / CHAR_LITERAL
//      / FLOAT
//      / IDENTIFIER
//      / INTEGER
//      / KEYWORD_anyerror
//      / KEYWORD_break BreakLabel? Expr?
//      / KEYWORD_cancel Expr
//      / KEYWORD_comptime Expr
//      / KEYWORD_continue BreakLabel?
//      / KEYWORD_error DOT IDENTIFIER
//      / KEYWORD_false
//      / KEYWORD_null
//      / KEYWORD_promise
//      / KEYWORD_resume Expr
//      / KEYWORD_return Expr?
//      / KEYWORD_true
//      / KEYWORD_undefined
//      / KEYWORD_unreachable
//      / STRINGLITERAL
static AstNode *ast_parse_primary_expr(ParseContext *pc) {
    AstNode *asm_expr = ast_parse_asm_expr(pc);
    if (asm_expr != nullptr)
        return asm_expr;

    AstNode *block_expr = ast_parse_block_expr(pc);
    if (block_expr != nullptr)
        return block_expr;

    AstNode *container_decl = ast_parse_container_decl(pc);
    if (container_decl != nullptr)
        return container_decl;

    AstNode *error_set_decl = ast_parse_error_set_decl(pc);
    if (error_set_decl != nullptr)
        return error_set_decl;

    AstNode *fn_proto = ast_parse_fn_proto(pc);
    if (fn_proto != nullptr)
        return fn_proto;

    AstNode *for_expr = ast_parse_for_expr(pc);
    if (for_expr != nullptr)
        return for_expr;

    AstNode *grouped_expr = ast_parse_grouped_expr(pc);
    if (grouped_expr != nullptr)
        return grouped_expr;

    AstNode *if_expr = ast_parse_if_expr(pc);
    if (if_expr != nullptr)
        return if_expr;

    AstNode *switch_expr = ast_parse_switch_expr(pc);
    if (switch_expr != nullptr)
        return switch_expr;

    AstNode *while_expr = ast_parse_while_expr(pc);
    if (while_expr != nullptr)
        return while_expr;

    // TODO: This is not in line with the grammar.
    //       Because the prev stage 1 tokenizer does not parse
    //       @[a-zA-Z_][a-zA-Z0-9_] as one token, it has to do a
    //       hack, where it accepts '@' (IDENTIFIER / KEYWORD_export).
    //       I'd say that it's better if '@' is part of the builtin
    //       identifier token.
    if (eat_token_if(pc, TokenIdAtSign) != nullptr) {
        Token *name = eat_token_if(pc, TokenIdKeywordExport);
        if (name == nullptr)
            name = expect_token(pc, TokenIdSymbol);

        ZigList<AstNode *> params;
        Token *first = peek_token(pc);
        if (!ast_parse_fn_call_argumnets(pc).unwrap(&params))
            ast_invalid_token_error(pc, peek_token(pc));

        AstNode *name_node = ast_create_node(pc, NodeTypeSymbol, name);
        name_node->data.symbol_expr.symbol = token_buf(name);

        AstNode *res = ast_create_node(pc, NodeTypeFnCallExpr, first);
        res->data.fn_call_expr.fn_ref_expr = name_node;
        res->data.fn_call_expr.params = params;
        res->data.fn_call_expr.is_builtin = true;
        res->data.fn_call_expr.is_async = false;
        res->data.fn_call_expr.async_allocator = nullptr;
        return res;
    }

    Token *char_lit = eat_token_if(pc, TokenIdCharLiteral);
    if (char_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeCharLiteral, char_lit);
        res->data.char_literal.value = char_lit->data.char_lit.c;
        return res;
    }

    Token *float_lit = eat_token_if(pc, TokenIdFloatLiteral);
    if (float_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeFloatLiteral, float_lit);
        res->data.float_literal.bigfloat = &float_lit->data.float_lit.bigfloat;
        res->data.float_literal.overflow = float_lit->data.float_lit.overflow;
        return res;
    }

    Token *identifier = eat_token_if(pc, TokenIdSymbol);
    if (identifier != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeSymbol, identifier);
        res->data.symbol_expr.symbol = token_buf(identifier);
        return res;
    }

    Token *int_lit = eat_token_if(pc, TokenIdIntLiteral);
    if (int_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeIntLiteral, int_lit);
        res->data.int_literal.bigint = &int_lit->data.int_lit.bigint;
        return res;
    }

    Token *error_type = eat_token_if(pc, TokenIdKeywordAnyerror);
    if (error_type != nullptr)
        return ast_create_node(pc, NodeTypeErrorType, error_type);

    Token *break_token = eat_token_if(pc, TokenIdKeywordBreak);
    if (break_token != nullptr) {
        Token *label = ast_parse_break_label(pc);
        AstNode *expr = ast_parse_expr(pc);

        AstNode *res = ast_create_node(pc, NodeTypeBreak, break_token);
        res->data.break_expr.name = token_buf(label);
        res->data.break_expr.expr = expr;
        return res;
    }

    Token *cancel = eat_token_if(pc, TokenIdKeywordCancel);
    if (cancel != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_expr);
        AstNode *res = ast_create_node(pc, NodeTypeCancel, cancel);
        res->data.cancel_expr.expr = expr;
        return res;
    }

    Token *comptime = eat_token_if(pc, TokenIdKeywordCompTime);
    if (comptime != nullptr) {
        AstNode *expr = ast_expect(pc, ast_parse_expr);
        AstNode *res = ast_create_node(pc, NodeTypeCompTime, comptime);
        res->data.comptime_expr.expr = expr;
        return res;
    }

    Token *continue_token = eat_token_if(pc, TokenIdKeywordBreak);
    if (continue_token != nullptr) {
        Token *label = ast_parse_break_label(pc);
        AstNode *res = ast_create_node(pc, NodeTypeContinue, continue_token);
        res->data.continue_expr.name = token_buf(label);
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

    Token *promise = eat_token_if(pc, TokenIdKeywordPromise);
    if (null != nullptr)
        return ast_create_node(pc, NodeTypePromiseType, promise);

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
    if (string_lit != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeStringLiteral, string_lit);
        res->data.string_literal.buf = token_buf(string_lit);
        res->data.string_literal.c = string_lit->data.str_lit.is_c_str;
        return res;
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

// Block <- LBRACE Statement* RBRACE
static AstNode *ast_parse_block(ParseContext *pc) {
    Token *lbrace = eat_token_if(pc, TokenIdLBrace);
    if (lbrace == nullptr)
        return nullptr;

    ZigList<AstNode *> statements = {0};
    AstNode *statement;
    while ((statement = ast_parse_statement(pc)) != nullptr)
        statements.append(statement);

    expect_token(pc, TokenIdRBrace);

    AstNode *res = ast_create_node(pc, NodeTypeBlock, lbrace);
    res->data.block.statements = statements;
    return res;
}

// ContainerDecl <- (KEYWORD_extern / KEYWORD_packed)? ContainerDeclAuto
static AstNode *ast_parse_container_decl(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordExtern);
    if (first == nullptr)
        first = eat_token_if(pc, TokenIdKeywordPacked);
    if (first != nullptr) {
        AstNode *res = ast_expect(pc, ast_parse_container_decl_auto);
        assert(res->type == NodeTypeContainerDecl);
        res->data.container_decl.layout = first->id == TokenIdKeywordExtern
            ? ContainerLayoutExtern
            : ContainerLayoutPacked;
        return res;
    }

    return ast_parse_container_decl_auto(pc);
}

// ErrorSetDecl <- KEYWORD_error LBRACE IdentifierList RBRACE
static AstNode *ast_parse_error_set_decl(ParseContext *pc) {
    Token *first = eat_token_if(pc, TokenIdKeywordError);
    if (first == nullptr)
        return nullptr;

    expect_token(pc, TokenIdLBrace);
    ZigList<AstNode *> decls = ast_parse_list(pc, TokenIdComma, [](ParseContext *context) {
        Token *ident = eat_token_if(context, TokenIdSymbol);
        if (ident == nullptr)
            return (AstNode*)nullptr;

        AstNode *res = ast_create_node(context, NodeTypeSymbol, ident);
        res->data.symbol_expr.symbol = token_buf(ident);
        return res;
    });
    expect_token(pc, TokenIdRBrace);

    AstNode *res = ast_create_node(pc, NodeTypeErrorSetDecl, first);
    res->data.err_set_decl.decls = decls;
    return res;
}

// ForExpr <- ForPrefix Expr (KEYWORD_else Expr)?
static AstNode *ast_parse_for_expr(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeForExpr prefix;
    if (!ast_parse_for_prefix(pc).unwrap(&prefix))
        return nullptr;

    AstNode *body = ast_expect(pc, ast_parse_expr);
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr)
        else_body = ast_expect(pc, ast_parse_expr);

    AstNode *res = ast_create_node(pc, NodeTypeForExpr, first);
    res->data.for_expr = prefix;
    res->data.for_expr.body = body;
    res->data.for_expr.else_node = else_body;
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

// IfExpr <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
static AstNode *ast_parse_if_expr(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeTestExpr prefix;
    if (!ast_parse_if_prefix(pc).unwrap(&prefix))
        return nullptr;

    AstNode *body = ast_expect(pc, ast_parse_expr);

    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, ast_parse_expr);
    }

    if (err_payload != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeIfErrorExpr, first);
        res->data.if_err_expr.target_node = prefix.target_node;
        res->data.if_err_expr.var_is_ptr = prefix.var_is_ptr;
        res->data.if_err_expr.var_symbol = prefix.var_symbol;
        res->data.if_err_expr.then_node = body;
        res->data.if_err_expr.err_symbol = token_buf(err_payload);
        res->data.if_err_expr.else_node = else_body;
        return res;
    }

    if (prefix.var_symbol != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeTestExpr, first);
        res->data.test_expr = prefix;
        res->data.test_expr.then_node = body;
        res->data.test_expr.else_node = else_body;
        return res;
    }

    AstNode *res = ast_create_node(pc, NodeTypeIfBoolExpr, first);
    res->data.if_bool_expr.condition = prefix.target_node;
    res->data.if_bool_expr.then_block = body;
    res->data.if_bool_expr.else_node = else_body;
    return res;
}

// SwitchExpr <- KEYWORD_switch GroupedExpr LBRACE SwitchProngList RBRACE
static AstNode *ast_parse_switch_expr(ParseContext *pc) {
    Token *switch_token = eat_token_if(pc, TokenIdKeywordSwitch);
    if (switch_token == nullptr)
        return nullptr;

    AstNode *expr = ast_expect(pc, ast_parse_grouped_expr);
    expect_token(pc, TokenIdLBrace);
    ZigList<AstNode *> prongs = ast_parse_list(pc, TokenIdComma, ast_parse_switch_prong);
    expect_token(pc, TokenIdRBrace);

    AstNode *res = ast_create_node(pc, NodeTypeSwitchExpr, switch_token);
    res->data.switch_expr.expr = expr;
    res->data.switch_expr.prongs = prongs;
    return res;
}

// WhileExpr <- WhilePrefix Expr (KEYWORD_else Payload? Expr)?
static AstNode *ast_parse_while_expr(ParseContext *pc) {
    Token *first = peek_token(pc);
    AstNodeWhileExpr prefix;
    if (!ast_parse_while_prefix(pc).unwrap(&prefix))
        return nullptr;

    AstNode *body = ast_expect(pc, ast_parse_expr);
    Token *err_payload = nullptr;
    AstNode *else_body = nullptr;
    if (eat_token_if(pc, TokenIdKeywordElse) != nullptr) {
        err_payload = ast_parse_payload(pc);
        else_body = ast_expect(pc, ast_parse_expr);
    }

    AstNode *res = ast_create_node(pc, NodeTypeWhileExpr, first);
    res->data.while_expr = prefix;
    res->data.while_expr.body = body;
    res->data.while_expr.err_symbol = token_buf(err_payload);
    res->data.while_expr.else_node = else_body;
    return res;
}

// AsmExpr <- KEYWORD_asm KEYWORD_volatile? LPAREN STRINGLITERAL AsmOutput? RPAREN
static AstNode *ast_parse_asm_expr(ParseContext *pc) {
    Token *asm_token = eat_token_if(pc, TokenIdKeywordAsm);
    if (asm_token == nullptr)
        return nullptr;

    Token *volatile_token = eat_token_if(pc, TokenIdKeywordVolatile);
    expect_token(pc, TokenIdLParen);
    Token *asm_template = expect_token(pc, TokenIdStringLiteral);
    AstNodeAsmExpr asm_expr;
    if (!ast_parse_asm_output(pc).unwrap(&asm_expr))
        asm_expr = {0};
    expect_token(pc, TokenIdRParen);

    AstNode *res = ast_create_node(pc, NodeTypeAsmExpr, asm_token);
    res->data.asm_expr = asm_expr;
    res->data.asm_expr.is_volatile = volatile_token != nullptr;
    res->data.asm_expr.asm_template = token_buf(asm_template);
    return res;
}

// AsmOutput <- COLON AsmOutputList AsmInput?
static Optional<AstNodeAsmExpr> ast_parse_asm_output(ParseContext *pc) {
    return {}; // TODO
}

// AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
static AstNode *ast_parse_asm_output_item(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmInput <- COLON AsmInputList AsmCloppers?
static AstNode *ast_parse_asm_input(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
static AstNode *ast_parse_asm_input_item(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmCloppers <- COLON StringList
static AstNode *ast_parse_asm_cloppers(ParseContext *pc) {
    return nullptr; // TODO
}

// BreakLabel <- COLON IDENTIFIER
static Token *ast_parse_break_label(ParseContext *pc) {
    return nullptr; // TODO
}

// BlockLabel <- IDENTIFIER COLON
static Token *ast_parse_block_label(ParseContext *pc) {
    return nullptr; // TODO
}

// FieldInit <- DOT IDENTIFIER EQUAL Expr
static AstNode *ast_parse_field_init(ParseContext *pc) {
    return nullptr; // TODO
}

// WhileContinueExpr <- COLON LPAREN AssignExpr RPAREN
static AstNode *ast_parse_while_continue_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// Section <- KEYWORD_section GroupedExpr
static AstNode *ast_parse_section(ParseContext *pc) {
    return nullptr; // TODO
}

// FnCC
//     <- KEYWORD_nakedcc
//      / KEYWORD_stdcallcc
//      / KEYWORD_extern
//      / KEYWORD_async (LARROW TypeExpr RARROW)?
static AstNodeFnProto ast_parse_fn_cc(ParseContext *pc) {
    return {}; // TODO
}

// ParamDecl <- (KEYWORD_noalias / KEYWORD_comptime)? (IDENTIFIER COLON)? ParamType
static AstNode *ast_parse_param_decl(ParseContext *pc) {
    return nullptr; // TODO
}

// ParamType
//     <- KEYWORD_var
//      / DOT3
//      / TypeExpr
static AstNode *ast_parse_param_type(ParseContext *pc) {
    return nullptr; // TODO
}

// IfPrefix <- KEYWORD_if GroupedExpr PtrPayload?
static Optional<AstNodeTestExpr> ast_parse_if_prefix(ParseContext *pc) {
    return {}; // TODO
}

// WhilePrefix <- BlockLabel? KEYWORD_inline? KEYWORD_while GroupedExpr PtrPayload? WhileContinueExpr?
static Optional<AstNodeWhileExpr> ast_parse_while_prefix(ParseContext *pc) {
    return {}; // TODO
}

// ForPrefix <- BlockLabel? KEYWORD_inline? KEYWORD_for GroupedExpr PtrIndexPayload?
static Optional<AstNodeForExpr> ast_parse_for_prefix(ParseContext *pc) {
    return {}; // TODO
}

// Payload <- PIPE IDENTIFIER PIPE
static Token *ast_parse_payload(ParseContext *pc) {
    return nullptr; // TODO
}

// PtrPayload
//     <- PIPE ASTERISK IDENTIFIER PIPE
//      / Payload
static Optional<PtrPayload> ast_parse_ptr_payload(ParseContext *pc) {
    return {}; // TODO
}

// PtrIndexPayload
//     <- PIPE ASTERISK IDENTIFIER COMMA IDENTIFIER PIPE
//      / PIPE IDENTIFIER COMMA IDENTIFIER PIPE
//      / PtrPayload
static Optional<PtrIndexPayload> ast_parse_ptr_index_payload(ParseContext *pc) {
    return {}; // TODO
}

// SwitchProng <- SwitchCase EQUALRARROW PtrPayload? AssignExpr
static AstNode *ast_parse_switch_prong(ParseContext *pc) {
    return nullptr; // TODO
}

// SwitchCase
//     <- SwitchItem (COMMA SwitchItem)* COMMA?
//      / KEYWORD_else
static AstNode *ast_parse_switch_case(ParseContext *pc) {
    return nullptr; // TODO
}

// SwitchItem
//     <- Expr DOT3 Expr
//      / Expr
static AstNode *ast_parse_switch_item(ParseContext *pc) {
    return nullptr; // TODO
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
static Optional<BinOpType> ast_parse_assign_op(ParseContext *pc) {
    return {}; // TODO
}

// CompareOp
//     <- EQUALEQUAL
//      / EXCLAMATIONMARKEQUAL
//      / LARROW
//      / RARROW
//      / LARROWEQUAL
//      / RARROWEQUAL
static Optional<BinOpType> ast_parse_compare_op(ParseContext *pc) {
    return {}; // TODO
}

// BitwiseOp
//     <- AMPERSAND
//      / CARET
//      / PIPE
//      / KEYWORD_orelse
//      / KEYWORD_catch Payload?
static Optional<BinOpType> ast_parse_bitwise_op(ParseContext *pc) {
    return {}; // TODO
}

// BitShiftOp
//     <- LARROW2
//      / RARROW2
static Optional<BinOpType> ast_parse_bit_shift_op(ParseContext *pc) {
    return {}; // TODO
}

// AdditionOp
//     <- PLUS
//      / MINUS
//      / PLUS2
//      / PLUSPERCENT
//      / MINUSPERCENT
static Optional<BinOpType> ast_parse_addition_op(ParseContext *pc) {
    return {}; // TODO
}

// MultiplyOp
//     <- PIPE2
//      / ASTERISK
//      / SLASH
//      / PERCENT
//      / ASTERISK2
//      / ASTERISKPERCENT
static Optional<BinOpType> ast_parse_multiply_op(ParseContext *pc) {
    return {}; // TODO
}

// PrefixOp
//     <- EXCLAMATIONMARK
//      / MINUS
//      / TILDE
//      / MINUSPERCENT
//      / AMPERSAND
//      / QUESTIONMARK
//      / KEYWORD_try
//      / KEYWORD_await
//      / KEYWORD_promise MINUSRARROW
//      / PtrStart PtrAttribute*
static AstNode *ast_parse_prefix_op(ParseContext *pc) {
    return nullptr; // TODO
}

// SuffixOp
//     <- LBRACKET Expr DOT2 Expr RBRACKET
//      / LBRACKET Expr DOT2 RBRACKET
//      / LBRACKET Expr RBRACKET
//      / DOT IDENTIFIER
//      / DOTASTERISK
//      / DOTQUESTIONMARK
static AstNode *ast_parse_suffix_op(ParseContext *pc) {
    return nullptr; // TODO
}

// AsyncPrefix
//     <- KEYWORD_async LARROW TypeExpr RARROW
//      / KEYWORD_async
static Optional<AstNodeFnCallExpr> ast_parse_async_prefix(ParseContext *pc) {
    return {}; // TODO
}

// FnCallArgumnets <- LPAREN ExprList RPAREN
static Optional<ZigList<AstNode *>> ast_parse_fn_call_argumnets(ParseContext *pc) {
    return {}; // TODO
}

// PtrStart
//     <- ASTERISK
//      / ASTERISK2
//      / LBRACKET RBRACKET
//      / LBRACKET ASTERISK RBRACKET
//      / LBRACKET Expr RBRACKET
static AstNode *ast_parse_ptr_start(ParseContext *pc) {
    return nullptr; // TODO
}

// PtrAttribute
//     <- BitAlign
//      / ByteAlign
//      / KEYWORD_const
//      / KEYWORD_volatile
static AstNode *ast_parse_ptr_attribute(ParseContext *pc) {
    return nullptr; // TODO
}

// ContainerDeclAuto <- ContainerDeclType LBRACE ContainerMembers RBRACE
static AstNode *ast_parse_container_decl_auto(ParseContext *pc) {
    return nullptr; // TODO
}

// ContainerDeclType
//     <- KEYWORD_struct GroupedExpr?
//      / KEYWORD_union LPAREN KEYWORD_enum GroupedExpr? RPAREN
//      / KEYWORD_union GroupedExpr?
//      / KEYWORD_enum GroupedExpr?
static AstNode *ast_parse_container_decl_type(ParseContext *pc) {
    return nullptr; // TODO
}

// ByteAlign <- KEYWORD_align GroupedExpr
static AstNode *ast_parse_byte_align(ParseContext *pc) {
    return nullptr; // TODO
}

// BitAlign <- KEYWORD_align LPAREN Expr COLON INTEGER COLON INTEGER RPAREN
static AstNode *ast_parse_bit_align(ParseContext *pc) {
    return nullptr; // TODO
}

// IdentifierList <- (IDENTIFIER COMMA)* IDENTIFIER?
static AstNode *ast_parse_identifier_list(ParseContext *pc) {
    return nullptr; // TODO
}

// SwitchProngList <- (SwitchProng COMMA)* SwitchProng?
static AstNode *ast_parse_switch_prong_list(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmOutputList <- (AsmOutputItem COMMA)* AsmOutputItem?
static AstNode *ast_parse_asm_output_list(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmInputList <- (AsmInputItem COMMA)* AsmInputItem?
static AstNode *ast_parse_asm_input_list(ParseContext *pc) {
    return nullptr; // TODO
}

// StringList <- (STRINGLITERAL COMMA)* STRINGLITERAL?
static AstNode *ast_parse_string_list(ParseContext *pc) {
    return nullptr; // TODO
}

// ParamDeclList <- (ParamDecl COMMA)* ParamDecl?
static AstNode *ast_parse_param_decl_list(ParseContext *pc) {
    return nullptr; // TODO
}

//ExprList <- (Expr COMMA)* Expr?
static AstNode *ast_parse_expr_list(ParseContext *pc) {
    return nullptr; // TODO
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
        case NodeTypeRoot:
            visit_node_list(&node->data.root.top_level_decls, visit, context);
            break;
        case NodeTypeFnProto:
            visit_field(&node->data.fn_proto.return_type, visit, context);
            visit_node_list(&node->data.fn_proto.params, visit, context);
            visit_field(&node->data.fn_proto.align_expr, visit, context);
            visit_field(&node->data.fn_proto.section_expr, visit, context);
            visit_field(&node->data.fn_proto.async_allocator_type, visit, context);
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
        case NodeTypeUnwrapErrorExpr:
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
            visit_field(&node->data.fn_call_expr.async_allocator, visit, context);
            break;
        case NodeTypeArrayAccessExpr:
            visit_field(&node->data.array_access_expr.array_ref_expr, visit, context);
            visit_field(&node->data.array_access_expr.subscript, visit, context);
            break;
        case NodeTypeSliceExpr:
            visit_field(&node->data.slice_expr.array_ref_expr, visit, context);
            visit_field(&node->data.slice_expr.start, visit, context);
            visit_field(&node->data.slice_expr.end, visit, context);
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
        case NodeTypeUse:
            visit_field(&node->data.use.expr, visit, context);
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
        case NodeTypeTestExpr:
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
            visit_field(&node->data.array_type.child_type, visit, context);
            visit_field(&node->data.array_type.align_expr, visit, context);
            break;
        case NodeTypePromiseType:
            visit_field(&node->data.promise_type.payload_type, visit, context);
            break;
        case NodeTypeErrorType:
            // none
            break;
        case NodeTypePointerType:
            visit_field(&node->data.pointer_type.align_expr, visit, context);
            visit_field(&node->data.pointer_type.op_expr, visit, context);
            break;
        case NodeTypeErrorSetDecl:
            visit_node_list(&node->data.err_set_decl.decls, visit, context);
            break;
        case NodeTypeCancel:
            visit_field(&node->data.cancel_expr.expr, visit, context);
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
    }
}
