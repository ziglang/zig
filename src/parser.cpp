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

struct ContainerMembers {
    ZigList<AstNode *> fields;
    ZigList<AstNode *> decls;
};

struct FnCC {
    CallingConvention cc;
    AstNode *async_allocator_type;
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

struct IfPrefix {
    Token *if_token;
    AstNode *condition;
    Optional<PtrPayload> payload;
};

struct WhilePrefix {
    Token *label;
    Token *inline_token;
    Token *while_token;
    AstNode *condition;
    Optional<PtrPayload> payload;
    AstNode *continue_expr;
};

struct ForPrefix {
    Token *label;
    Token *inline_token;
    Token *for_token;
    AstNode *condition;
    Optional<PtrIndexPayload> payload;
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
static ZigList<AstNode *> ast_list(ParseContext *pc, TokenId sep, AstNode *(*parser)(ParseContext*)) {
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

static AstNode *ast_parse_root(ParseContext *pc);
static ContainerMembers ast_parse_container_members(ParseContext *pc);
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
static AstNode *ast_parse_init_list(ParseContext *pc);
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
static AstNode *ast_parse_asm_output(ParseContext *pc);
static AstNode *ast_parse_asm_output_item(ParseContext *pc);
static AstNode *ast_parse_asm_input(ParseContext *pc);
static AstNode *ast_parse_asm_input_item(ParseContext *pc);
static AstNode *ast_parse_asm_cloppers(ParseContext *pc);
static AstNode *ast_parse_break_label(ParseContext *pc);
static AstNode *ast_parse_block_label(ParseContext *pc);
static AstNode *ast_parse_field_init(ParseContext *pc);
static AstNode *ast_parse_while_continue_expr(ParseContext *pc);
static AstNode *ast_parse_section(ParseContext *pc);
static FnCC ast_parse_fn_cc(ParseContext *pc);
static AstNode *ast_parse_param_decl(ParseContext *pc);
static AstNode *ast_parse_param_type(ParseContext *pc);
static Optional<IfPrefix> ast_parse_if_prefix(ParseContext *pc);
static Optional<WhilePrefix> ast_parse_while_prefix(ParseContext *pc);
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
static AstNode *ast_parse_suffix_op(ParseContext *pc);
static AstNode *ast_parse_async_prefix(ParseContext *pc);
static AstNode *ast_parse_fn_call_argumnets(ParseContext *pc);
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
    ContainerMembers members = ast_parse_container_members(pc);
    if (pc->current_token != pc->tokens->length - 1)
        ast_invalid_token_error(pc, peek_token(pc));

    AstNode *node = ast_create_node(pc, NodeTypeContainerDecl, first);
    node->data.container_decl.layout = ContainerLayoutAuto;
    node->data.container_decl.kind = ContainerKindStruct;
    node->data.container_decl.decls = members.decls;
    node->data.container_decl.fields = members.fields;

    return node;
}

// ContainerMembers
//     <- TestDecl ContainerMembers
//      / TopLevelComptime ContainerMembers
//      / KEYWORD_pub? TopLevelDecl ContainerMembers
//      / KEYWORD_pub? ContainerField COMMA ContainerMembers
//      / KEYWORD_pub? ContainerField
//      /
static ContainerMembers ast_parse_container_members(ParseContext *pc) {
    ContainerMembers res = {0};
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
        AstNode *res = ast_create_node_no_line_info(pc, NodeTypeFnDef);
        res->line = fn_proto->line;
        res->column = fn_proto->column;
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
        AstNode *res = ast_create_node_no_line_info(pc, NodeTypeFnDef);
        res->line = fn_proto->line;
        res->column = fn_proto->column;
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
    FnCC fn_cc = ast_parse_fn_cc(pc);
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
    ZigList<AstNode *> params = ast_list(pc, TokenIdComma, ast_parse_param_decl);
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
    IfPrefix prefix;
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

    PtrPayload payload;
    bool var_is_ptr = false;
    Buf *var_symbol = nullptr;
    if (prefix.payload.unwrap(&payload)) {
        var_is_ptr = payload.asterisk != nullptr;
        if (payload.payload != nullptr)
            var_symbol = token_buf(payload.payload);
    }


    if (err_payload != nullptr) {
        AstNode *res = ast_create_node(pc, NodeTypeIfErrorExpr, prefix.if_token);
        res->data.if_err_expr.target_node = prefix.condition;
        res->data.if_err_expr.var_is_ptr = var_is_ptr;
        res->data.if_err_expr.var_symbol = var_symbol;
        res->data.if_err_expr.then_node = body;
        res->data.if_err_expr.err_symbol = token_buf(err_payload);
        res->data.if_err_expr.else_node = else_body;
        return res;
    }

    if (prefix.payload.is_some) {
        AstNode *res = ast_create_node(pc, NodeTypeTestExpr, prefix.if_token);
        res->data.test_expr.target_node = prefix.condition;
        res->data.test_expr.var_is_ptr = var_is_ptr;
        res->data.test_expr.var_symbol = var_symbol;
        res->data.test_expr.then_node = body;
        res->data.test_expr.else_node = else_body;
        return res;
    }

    AstNode *res = ast_create_node(pc, NodeTypeIfBoolExpr, prefix.if_token);
    res->data.if_bool_expr.condition = prefix.condition;
    res->data.if_bool_expr.then_block = body;
    res->data.if_bool_expr.else_node = else_body;
    return res;
}

// WhileStatement
//     <- WhilePrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
static AstNode *ast_parse_while_statement(ParseContext *pc) {
    WhilePrefix prefix;
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

    PtrPayload payload;
    AstNode *res = ast_create_node(pc, NodeTypeWhileExpr, prefix.while_token);
    res->data.while_expr.name = token_buf(prefix.label);
    res->data.while_expr.is_inline = prefix.inline_token != nullptr;
    res->data.while_expr.condition = prefix.condition;
    if (prefix.payload.unwrap(&payload)) {
        res->data.while_expr.var_is_ptr = payload.asterisk != nullptr;
        res->data.while_expr.var_symbol = token_buf(payload.payload);
    }
    res->data.while_expr.continue_expr = prefix.continue_expr;
    res->data.while_expr.body = body;
    res->data.while_expr.err_symbol = token_buf(err_payload);
    res->data.while_expr.else_node = else_body;
    return res;
}

// ForStatement
//     <- ForPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / ForPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
static AstNode *ast_parse_for_statement(ParseContext *pc) {
    return nullptr;
}


// BlockExprStatement
//     <- BlockExpr
//      / AssignExpr SEMICOLON
static AstNode *ast_parse_block_expr_statement(ParseContext *pc) {
    return nullptr; // TODO
}

// AssignExpr <- Expr (AssignOp Expr)?
static AstNode *ast_parse_assign_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// Expr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*
static AstNode *ast_parse_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*
static AstNode *ast_parse_bool_and_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)?
static AstNode *ast_parse_compare_expr(ParseContext *pc) {
    return nullptr; // TODO
}

//BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)*
static AstNode *ast_parse_bitwise_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)*
static AstNode *ast_parse_bit_shit_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*
static AstNode *ast_parse_addition_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// MultiplyExpr <- CurlySuffixExpr (MultiplyOp CurlySuffixExpr)*
static AstNode *ast_parse_multiply_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// CurlySuffixExpr <- TypeExpr (LBRACE InitList RBRACE)?
static AstNode *ast_parse_curly_suffix_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// InitList
//     <- Expr (COMMA Expr)* COMMA?
//      / FieldInit (COMMA FieldInit)* COMMA?
//      /
static AstNode *ast_parse_init_list(ParseContext *pc) {
    return nullptr; // TODO
}

// TypeExpr <- PrefixExpr (EXCLAMATIONMARK PrefixExpr)?
static AstNode *ast_parse_type_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// PrefixExpr
//     <- PrefixOp PrefixExpr
//      / SuffixExpr
static AstNode *ast_parse_prefix_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// SuffixExpr
//     <- AsyncPrefix PrimaryExpr SuffixOp* FnCallArgumnets
//      / PrimaryExpr (SuffixOp / FnCallArgumnets)*
static AstNode *ast_parse_suffix_expr(ParseContext *pc) {
    return nullptr; // TODO
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
//      / KEYWORD_break BreakLabel? Expr?
//      / KEYWORD_cancel Expr
//      / KEYWORD_comptime Expr
//      / KEYWORD_continue BreakLabel?
//      / KEYWORD_resume Expr
//      / KEYWORD_return Expr?
//      / SwitchExpr
//      / WhileExpr
//      / BUILTININDENTIFIER FnCallArgumnets
//      / CHAR_LITERAL
//      / STRINGLITERAL
//      / IDENTIFIER
//      / KEYWORD_anyerror
//      / KEYWORD_error DOT IDENTIFIER
//      / KEYWORD_false
//      / KEYWORD_null
//      / KEYWORD_promise
//      / KEYWORD_true
//      / KEYWORD_undefined
//      / KEYWORD_unreachable
//      / FLOAT
//      / INTEGER
static AstNode *ast_parse_primary_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// BlockExpr  <- BlockLabel? Block
static AstNode *ast_parse_block_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// Block  <- LBRACE Statement* RBRACE
static AstNode *ast_parse_block(ParseContext *pc) {
    return nullptr; // TODO
}

// ContainerDecl  <- (KEYWORD_extern / KEYWORD_packed)? ContainerDeclAuto
static AstNode *ast_parse_container_decl(ParseContext *pc) {
    return nullptr; // TODO
}

// ErrorSetDecl  <- KEYWORD_error LBRACE IdentifierList RBRACE
static AstNode *ast_parse_error_set_decl(ParseContext *pc) {
    return nullptr; // TODO
}

// ForExpr  <- ForPrefix Expr (KEYWORD_else Expr)?
static AstNode *ast_parse_for_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// GroupedExpr  <- LPAREN Expr RPAREN
static AstNode *ast_parse_grouped_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// IfExpr  <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
static AstNode *ast_parse_if_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// SwitchExpr  <- KEYWORD_switch GroupedExpr LBRACE SwitchProngList RBRACE
static AstNode *ast_parse_switch_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// WhileExpr  <- WhilePrefix Expr (KEYWORD_else Payload? Expr)?
static AstNode *ast_parse_while_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmExpr  <- KEYWORD_asm KEYWORD_volatile? LPAREN STRINGLITERAL AsmOutput? RPAREN
static AstNode *ast_parse_asm_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmOutput  <- COLON AsmOutputList AsmInput?
static AstNode *ast_parse_asm_output(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmOutputItem  <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
static AstNode *ast_parse_asm_output_item(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmInput  <- COLON AsmInputList AsmCloppers?
static AstNode *ast_parse_asm_input(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmInputItem  <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
static AstNode *ast_parse_asm_input_item(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmCloppers  <- COLON StringList
static AstNode *ast_parse_asm_cloppers(ParseContext *pc) {
    return nullptr; // TODO
}

// BreakLabel  <- COLON IDENTIFIER
static AstNode *ast_parse_break_label(ParseContext *pc) {
    return nullptr; // TODO
}

// BlockLabel  <- IDENTIFIER COLON
static AstNode *ast_parse_block_label(ParseContext *pc) {
    return nullptr; // TODO
}

// FieldInit  <- DOT IDENTIFIER EQUAL Expr
static AstNode *ast_parse_field_init(ParseContext *pc) {
    return nullptr; // TODO
}

// WhileContinueExpr  <- COLON LPAREN AssignExpr RPAREN
static AstNode *ast_parse_while_continue_expr(ParseContext *pc) {
    return nullptr; // TODO
}

// Section  <- KEYWORD_section GroupedExpr
static AstNode *ast_parse_section(ParseContext *pc) {
    return nullptr; // TODO
}

// FnCC
//     <- KEYWORD_nakedcc
//      / KEYWORD_stdcallcc
//      / KEYWORD_extern
//      / KEYWORD_async (LARROW TypeExpr RARROW)?
static FnCC ast_parse_fn_cc(ParseContext *pc) {
    return {}; // TODO
}

// ParamDecl  <- (KEYWORD_noalias / KEYWORD_comptime)? (IDENTIFIER COLON)? ParamType
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

// IfPrefix  <- KEYWORD_if GroupedExpr PtrPayload?
static Optional<IfPrefix> ast_parse_if_prefix(ParseContext *pc) {
    return {}; // TODO
}

// WhilePrefix  <- BlockLabel? KEYWORD_inline? KEYWORD_while GroupedExpr PtrPayload? WhileContinueExpr?
static Optional<WhilePrefix> ast_parse_while_prefix(ParseContext *pc) {
    return {}; // TODO
}

// ForPrefix  <- BlockLabel? KEYWORD_inline? KEYWORD_for GroupedExpr PtrIndexPayload?
static AstNode *ast_parse_for_prefix(ParseContext *pc) {
    return nullptr; // TODO
}

// Payload  <- PIPE IDENTIFIER PIPE
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

// SwitchProng  <- SwitchCase EQUALRARROW PtrPayload? AssignExpr
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
static AstNode *ast_parse_assign_op(ParseContext *pc) {
    return nullptr; // TODO
}

// CompareOp
//     <- EQUALEQUAL
//      / EXCLAMATIONMARKEQUAL
//      / LARROW
//      / RARROW
//      / LARROWEQUAL
//      / RARROWEQUAL
static AstNode *ast_parse_compare_op(ParseContext *pc) {
    return nullptr; // TODO
}

// BitwiseOp
//     <- AMPERSAND
//      / CARET
//      / PIPE
//      / KEYWORD_orelse
//      / KEYWORD_catch Payload?
static AstNode *ast_parse_bitwise_op(ParseContext *pc) {
    return nullptr; // TODO
}

// BitShiftOp
//     <- LARROW2
//      / RARROW2
static AstNode *ast_parse_bit_shift_op(ParseContext *pc) {
    return nullptr; // TODO
}

// AdditionOp
//     <- PLUS
//      / MINUS
//      / PLUS2
//      / PLUSPERCENT
//      / MINUSPERCENT
static AstNode *ast_parse_addition_op(ParseContext *pc) {
    return nullptr; // TODO
}

// MultiplyOp
//     <- PIPE2
//      / ASTERISK
//      / SLASH
//      / PERCENT
//      / ASTERISK2
//      / ASTERISKPERCENT
static AstNode *ast_parse_multiply_op(ParseContext *pc) {
    return nullptr; // TODO
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
static AstNode *ast_parse_async_prefix(ParseContext *pc) {
    return nullptr; // TODO
}

// FnCallArgumnets  <- LPAREN ExprList RPAREN
static AstNode *ast_parse_fn_call_argumnets(ParseContext *pc) {
    return nullptr; // TODO
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

// ContainerDeclAuto  <- ContainerDeclType LBRACE ContainerMembers RBRACE
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

// ByteAlign  <- KEYWORD_align GroupedExpr
static AstNode *ast_parse_byte_align(ParseContext *pc) {
    return nullptr; // TODO
}

// BitAlign  <- KEYWORD_align LPAREN Expr COLON INTEGER COLON INTEGER RPAREN
static AstNode *ast_parse_bit_align(ParseContext *pc) {
    return nullptr; // TODO
}

// IdentifierList  <- (IDENTIFIER COMMA)* IDENTIFIER?
static AstNode *ast_parse_identifier_list(ParseContext *pc) {
    return nullptr; // TODO
}

// SwitchProngList  <- (SwitchProng COMMA)* SwitchProng?
static AstNode *ast_parse_switch_prong_list(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmOutputList  <- (AsmOutputItem COMMA)* AsmOutputItem?
static AstNode *ast_parse_asm_output_list(ParseContext *pc) {
    return nullptr; // TODO
}

// AsmInputList  <- (AsmInputItem COMMA)* AsmInputItem?
static AstNode *ast_parse_asm_input_list(ParseContext *pc) {
    return nullptr; // TODO
}

// StringList  <- (STRINGLITERAL COMMA)* STRINGLITERAL?
static AstNode *ast_parse_string_list(ParseContext *pc) {
    return nullptr; // TODO
}

// ParamDeclList  <- (ParamDecl COMMA)* ParamDecl?
static AstNode *ast_parse_param_decl_list(ParseContext *pc) {
    return nullptr; // TODO
}

//ExprList  <- (Expr COMMA)* Expr?
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
