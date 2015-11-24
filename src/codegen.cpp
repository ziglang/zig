#include "codegen.hpp"
#include "hash_map.hpp"

#include <stdio.h>

struct CodeGen {
    AstNode *root;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> fn_decls;
    ZigList<ErrorMsg> errors;
};

CodeGen *create_codegen(AstNode *root) {
    CodeGen *g = allocate<CodeGen>(1);
    g->root = root;
    g->fn_decls.init(32);
    return g;
}

static void add_node_error(CodeGen *g, AstNode *node, Buf *msg) {
    g->errors.add_one();
    ErrorMsg *last_msg = &g->errors.last();
    last_msg->line_start = node->line;
    last_msg->column_start = node->column;
    last_msg->line_end = -1;
    last_msg->column_end = -1;
    last_msg->msg = msg;
}

static void analyze_node(CodeGen *g, AstNode *node) {
    switch (node->type) {
        case NodeTypeRoot:
            for (int i = 0; i < node->data.root.fn_decls.length; i += 1) {
                AstNode *child = node->data.root.fn_decls.at(i);
                analyze_node(g, child);
            }
            break;
        case NodeTypeFnDecl:
            {
                auto entry = g->fn_decls.maybe_get(&node->data.fn_decl.name);
                if (entry) {
                    add_node_error(g, node,
                            buf_sprintf("redefinition of '%s'", buf_ptr(&node->data.fn_decl.name)));
                } else {
                    g->fn_decls.put(&node->data.fn_decl.name, node);
                    for (int i = 0; i < node->data.fn_decl.params.length; i += 1) {
                        AstNode *child = node->data.fn_decl.params.at(i);
                        analyze_node(g, child);
                    }
                    analyze_node(g, node->data.fn_decl.return_type);
                    analyze_node(g, node->data.fn_decl.body);
                }
                break;
            }
        case NodeTypeParamDecl:
            analyze_node(g, node->data.param_decl.type);
            break;
        case NodeTypeType:
            break;
        case NodeTypePointerType:
            break;
        case NodeTypeBlock:
            break;
        case NodeTypeStatement:
            break;
        case NodeTypeExpressionStatement:
            break;
        case NodeTypeReturnStatement:
            break;
        case NodeTypeExpression:
            break;
        case NodeTypeFnCall:
            break;
    }
}

void semantic_analyze(CodeGen *g) {
    // Pass 1.
    analyze_node(g, g->root);
}

void code_gen(CodeGen *g) {

}

ZigList<ErrorMsg> *codegen_error_messages(CodeGen *g) {
    return &g->errors;
}
