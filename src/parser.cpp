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
    zig_panic("unreachable");
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
