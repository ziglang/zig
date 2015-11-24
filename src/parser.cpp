#include "parser.hpp"

#include <stdarg.h>
#include <stdio.h>

void ast_error(Token *token, const char *format, ...) {
    int line = token->start_line + 1;
    int column = token->start_column + 1;

    va_list ap;
    va_start(ap, format);
    fprintf(stderr, "Error: Line %d, column %d: ", line, column);
    vfprintf(stderr, format, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(EXIT_FAILURE);
}

const char *node_type_str(NodeType node_type) {
    switch (node_type) {
        case NodeTypeRoot:
            return "Root";
        case NodeTypeFnDecl:
            return "FnDecl";
        case NodeTypeParamDecl:
            return "ParamDecl";
        case NodeTypeType:
            return "Type";
        case NodeTypePointerType:
            return "PointerType";
        case NodeTypeBlock:
            return "Block";
        case NodeTypeStatement:
            return "Statement";
        case NodeTypeExpressionStatement:
            return "ExpressionStatement";
        case NodeTypeReturnStatement:
            return "ReturnStatement";
        case NodeTypeExpression:
            return "Expression";
        case NodeTypeFnCall:
            return "FnCall";
    }
    zig_unreachable();
}

void ast_print(AstNode *node, int indent) {
    for (int i = 0; i < indent; i += 1) {
        fprintf(stderr, " ");
    }

    switch (node->type) {
        case NodeTypeRoot:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            for (int i = 0; i < node->data.root.fn_decls.length; i += 1) {
                AstNode *child = node->data.root.fn_decls.at(i);
                ast_print(child, indent + 2);
            }
            break;
        case NodeTypeFnDecl:
            {
                Buf *name_buf = &node->data.fn_decl.name;
                fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                for (int i = 0; i < node->data.fn_decl.params.length; i += 1) {
                    AstNode *child = node->data.fn_decl.params.at(i);
                    ast_print(child, indent + 2);
                }

                ast_print(node->data.fn_decl.return_type, indent + 2);

                ast_print(node->data.fn_decl.body, indent + 2);

                break;
            }
        default:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            break;
    }
}

struct ParseContext {
    Buf *buf;
    AstNode *root;
    ZigList<Token> *tokens;
};

static AstNode *ast_create_node(NodeType type) {
    AstNode *node = allocate<AstNode>(1);
    node->type = type;
    return node;
}

static void ast_buf_from_token(ParseContext *pc, Token *token, Buf *buf) {
    buf_init_from_mem(buf, buf_ptr(pc->buf) + token->start_pos, token->end_pos - token->start_pos);
}

static void ast_invalid_token_error(ParseContext *pc, Token *token) {
    Buf token_value = {0};
    ast_buf_from_token(pc, token, &token_value);
    ast_error(token, "invalid token: '%s'", buf_ptr(&token_value));
}

static AstNode *ast_parse_expression(ParseContext *pc, int token_index, int *new_token_index);


static void ast_expect_token(ParseContext *pc, Token *token, TokenId token_id) {
    if (token->id != token_id) {
        ast_invalid_token_error(pc, token);
    }
}

/*
Type : token(Symbol) | PointerType;
PointerType : token(Star) token(Const) Type  | token(Star) token(Mut) Type;
*/
static AstNode *ast_parse_type(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *node = ast_create_node(NodeTypeType);

    Token *token = &pc->tokens->at(token_index);
    token_index += 1;

    if (token->id == TokenIdSymbol) {
        node->data.type.type = AstNodeTypeTypePrimitive;
        ast_buf_from_token(pc, token, &node->data.type.primitive_name);
    } else if (token->id == TokenIdStar) {
        Token *const_or_mut = &pc->tokens->at(token_index);
        token_index += 1;
        if (const_or_mut->id == TokenIdKeywordMut) {
            node->data.type.is_const = false;
        } else if (const_or_mut->id == TokenIdKeywordConst) {
            node->data.type.is_const = true;
        } else {
            ast_invalid_token_error(pc, const_or_mut);
        }

        node->data.type.child_type = ast_parse_type(pc, token_index, &token_index);
    } else {
        ast_invalid_token_error(pc, token);
    }

    *new_token_index = token_index;
    return node;
}

/*
ParamDecl<node> : token(Symbol) token(Colon) Type {
};
*/
static AstNode *ast_parse_param_decl(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *node = ast_create_node(NodeTypeParamDecl);

    Token *param_name = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, param_name, TokenIdSymbol);

    ast_buf_from_token(pc, param_name, &node->data.param_decl.name);

    Token *colon = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, colon, TokenIdColon);

    node->data.param_decl.type = ast_parse_type(pc, token_index, &token_index);

    *new_token_index = token_index;
    return node;
}


static void ast_parse_param_decl_list(ParseContext *pc, int token_index, int *new_token_index,
        ZigList<AstNode *> *params)
{
    Token *l_paren = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, l_paren, TokenIdLParen);

    Token *token = &pc->tokens->at(token_index);
    if (token->id == TokenIdRParen) {
        token_index += 1;
        *new_token_index = token_index;
        return;
    }

    for (;;) {
        AstNode *param_decl_node = ast_parse_param_decl(pc, token_index, &token_index);
        params->append(param_decl_node);

        Token *token = &pc->tokens->at(token_index);
        token_index += 1;
        if (token->id == TokenIdRParen) {
            *new_token_index = token_index;
            return;
        } else {
            ast_expect_token(pc, token, TokenIdComma);
        }
    }
    zig_unreachable();
}

static void ast_parse_fn_call_param_list(ParseContext *pc, int token_index, int *new_token_index,
        ZigList<AstNode*> *params)
{
    Token *l_paren = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, l_paren, TokenIdLParen);

    Token *token = &pc->tokens->at(token_index);
    if (token->id == TokenIdRParen) {
        token_index += 1;
        *new_token_index = token_index;
        return;
    }

    for (;;) {
        AstNode *expr = ast_parse_expression(pc, token_index, &token_index);
        params->append(expr);

        Token *token = &pc->tokens->at(token_index);
        token_index += 1;
        if (token->id == TokenIdRParen) {
            *new_token_index = token_index;
            return;
        } else {
            ast_expect_token(pc, token, TokenIdComma);
        }
    }
    zig_unreachable();
}

/*
FnCall : token(Symbol) token(LParen) list(Expression, token(Comma)) token(RParen) ;
*/
static AstNode *ast_parse_fn_call(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *node = ast_create_node(NodeTypeFnCall);

    Token *fn_name = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, fn_name, TokenIdSymbol);

    ast_buf_from_token(pc, fn_name, &node->data.fn_call.name);

    ast_parse_fn_call_param_list(pc, token_index, &token_index, &node->data.fn_call.params);

    *new_token_index = token_index;
    return node;
}

static AstNode *ast_parse_expression(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *node = ast_create_node(NodeTypeExpression);

    Token *token = &pc->tokens->at(token_index);
    if (token->id == TokenIdSymbol) {
        node->data.expression.type = AstNodeExpressionTypeFnCall;
        node->data.expression.data.fn_call = ast_parse_fn_call(pc, token_index, &token_index);
    } else if (token->id == TokenIdNumberLiteral) {
        node->data.expression.type = AstNodeExpressionTypeNumber;
        ast_buf_from_token(pc, token, &node->data.expression.data.number);
        token_index += 1;
    } else if (token->id == TokenIdStringLiteral) {
        node->data.expression.type = AstNodeExpressionTypeString;
        ast_buf_from_token(pc, token, &node->data.expression.data.string);
        token_index += 1;
    } else {
        ast_invalid_token_error(pc, token);
    }

    *new_token_index = token_index;
    return node;
}

/*
Statement : ExpressionStatement  | ReturnStatement ;

ExpressionStatement : Expression token(Semicolon) ;

ReturnStatement : token(Return) Expression token(Semicolon) ;

Expression : token(Number)  | token(String)  | FnCall ;

FnCall : token(Symbol) token(LParen) list(Expression, token(Comma)) token(RParen) ;
*/
static AstNode *ast_parse_statement(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *node = ast_create_node(NodeTypeStatement);

    Token *token = &pc->tokens->at(token_index);
    if (token->id == TokenIdKeywordReturn) {
        token_index += 1;
        node->data.statement.type = AstNodeStatementTypeReturn;
        node->data.statement.data.retrn.expression = ast_parse_expression(pc, token_index, &token_index);

        Token *semicolon = &pc->tokens->at(token_index);
        token_index += 1;
        ast_expect_token(pc, semicolon, TokenIdSemicolon);
    } else if (token->id == TokenIdSymbol ||
               token->id == TokenIdStringLiteral ||
               token->id == TokenIdNumberLiteral)
    {
        node->data.statement.type = AstNodeStatementTypeExpression;
        node->data.statement.data.expr.expression = ast_parse_expression(pc, token_index, &token_index);

        Token *semicolon = &pc->tokens->at(token_index);
        token_index += 1;
        ast_expect_token(pc, semicolon, TokenIdSemicolon);
    } else {
        ast_invalid_token_error(pc, token);
    }

    *new_token_index = token_index;
    return node;
}

/*
Block : token(LBrace) many(Statement) token(RBrace);
*/
static AstNode *ast_parse_block(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *node = ast_create_node(NodeTypeBlock);

    Token *l_brace = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, l_brace, TokenIdLBrace);

    for (;;) {
        Token *token = &pc->tokens->at(token_index);
        if (token->id == TokenIdRBrace) {
            token_index += 1;
            *new_token_index = token_index;
            return node;
        } else {
            AstNode *statement_node = ast_parse_statement(pc, token_index, &token_index);
            node->data.block.statements.append(statement_node);
        }
    }
    zig_unreachable();
}

/*
FnDecl : token(Fn) token(Symbol) ParamDeclList option(token(Arrow) Type) Block;
*/
static AstNode *ast_parse_fn_decl(ParseContext *pc, int token_index, int *new_token_index) {
    AstNode *node = ast_create_node(NodeTypeFnDecl);

    Token *fn_token = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, fn_token, TokenIdKeywordFn);

    Token *fn_name = &pc->tokens->at(token_index);
    token_index += 1;
    ast_expect_token(pc, fn_name, TokenIdSymbol);

    ast_buf_from_token(pc, fn_name, &node->data.fn_decl.name);


    ast_parse_param_decl_list(pc, token_index, &token_index, &node->data.fn_decl.params);

    Token *arrow = &pc->tokens->at(token_index);
    token_index += 1;
    if (arrow->id == TokenIdArrow) {
        node->data.fn_decl.return_type = ast_parse_type(pc, token_index, &token_index);
    } else if (arrow->id == TokenIdLBrace) {
        node->data.fn_decl.return_type = nullptr;
    } else {
        ast_invalid_token_error(pc, arrow);
    }

    node->data.fn_decl.body = ast_parse_block(pc, token_index, &token_index);

    *new_token_index = token_index;
    return node;
}


static void ast_parse_fn_decl_list(ParseContext *pc, int token_index, ZigList<AstNode *> *fn_decls,
        int *new_token_index)
{
    for (;;) {
        Token *token = &pc->tokens->at(token_index);
        if (token->id == TokenIdKeywordFn) {
            AstNode *fn_decl_node = ast_parse_fn_decl(pc, token_index, &token_index);
            fn_decls->append(fn_decl_node);
        } else {
            *new_token_index = token_index;
            return;
        }
    }
    zig_unreachable();
}

AstNode *ast_parse(Buf *buf, ZigList<Token> *tokens) {
    ParseContext pc = {0};
    pc.buf = buf;
    pc.root = ast_create_node(NodeTypeRoot);
    pc.tokens = tokens;

    int new_token_index;
    ast_parse_fn_decl_list(&pc, 0, &pc.root->data.root.fn_decls, &new_token_index);

    if (new_token_index != tokens->length - 1) {
        ast_invalid_token_error(&pc, &tokens->at(new_token_index));
    }

    return pc.root;
}
