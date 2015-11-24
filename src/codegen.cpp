#include "codegen.hpp"
#include "hash_map.hpp"

#include <stdio.h>

#include <llvm-c/Core.h>

struct CodeGen {
    AstNode *root;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> fn_decls;
    ZigList<ErrorMsg> errors;
    LLVMBuilderRef builder;
    HashMap<Buf *, LLVMValueRef, buf_hash, buf_eql_buf> external_fns;
};

struct ExpressionNode {
    AstNode *type_node;
};

struct CodeGenNode {
    union {
        LLVMTypeRef type_ref; // for NodeTypeType
        ExpressionNode expr; // for NodeTypeExpression
    } data;
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
            node->codegen_node = allocate<CodeGenNode>(1);
            switch (node->data.type.type) {
                case AstNodeTypeTypePrimitive:
                    {
                        Buf *name = &node->data.type.primitive_name;
                        if (buf_eql_str(name, "u8")) {
                            node->codegen_node->data.type_ref = LLVMInt8Type();
                        } else if (buf_eql_str(name, "i32")) {
                            node->codegen_node->data.type_ref = LLVMInt32Type();
                        } else {
                            add_node_error(g, node,
                                    buf_sprintf("invalid type name: '%s'", buf_ptr(name)));
                        }
                        break;
                    }
                case AstNodeTypeTypePointer:
                    {
                        analyze_node(g, node->data.type.child_type);
                        node->codegen_node->data.type_ref = LLVMPointerType(
                                node->data.type.child_type->codegen_node->data.type_ref, 0);
                        break;
                    }
            }
            break;
        case NodeTypeBlock:
            for (int i = 0; i < node->data.block.statements.length; i += 1) {
                AstNode *child = node->data.block.statements.at(i);
                analyze_node(g, child);
            }
            break;
        case NodeTypeStatement:
            switch (node->data.statement.type) {
                case AstNodeStatementTypeExpression:
                    analyze_node(g, node->data.statement.data.expr.expression);
                    break;
                case AstNodeStatementTypeReturn:
                    analyze_node(g, node->data.statement.data.retrn.expression);
                    break;
            }
            break;
        case NodeTypeExpression:
            switch (node->data.expression.type) {
                case AstNodeExpressionTypeNumber:
                    break;
                case AstNodeExpressionTypeString:
                    break;
                case AstNodeExpressionTypeFnCall:
                    analyze_node(g, node->data.expression.data.fn_call);
                    break;
            }
            break;
        case NodeTypeFnCall:
            for (int i = 0; i < node->data.fn_call.params.length; i += 1) {
                AstNode *child = node->data.fn_call.params.at(i);
                analyze_node(g, child);
            }
            break;
    }
}


/* TODO external fn
    LLVMTypeRef puts_param_types[] = {LLVMPointerType(LLVMInt8Type(), 0)};
    LLVMTypeRef puts_type = LLVMFunctionType(LLVMInt32Type(), puts_param_types, 1, 0);
    LLVMValueRef puts_fn = LLVMAddFunction(mod, "puts", puts_type);
    LLVMSetLinkage(puts_fn, LLVMExternalLinkage);
    */

void semantic_analyze(CodeGen *g) {
    // Pass 1.
    analyze_node(g, g->root);
}

static LLVMTypeRef to_llvm_type(AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);

    return type_node->codegen_node->data.type_ref;
}

static LLVMValueRef gen_fn_call(CodeGen *g, AstNode *fn_call_node) {
    assert(fn_call_node->type == NodeTypeFnCall);

    zig_panic("TODO support external fn declarations");
    //LLVMTypeRef fn_type =  LLVMFunctionType(LLVMVoidType(), );

    // resolve function name
    //LLVMValueRef result = LLVMBuildCall(g->builder, 


    //return value;
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *expr_node) {
    assert(expr_node->type == NodeTypeExpression);
    switch (expr_node->data.expression.type) {
        case AstNodeExpressionTypeNumber:
            zig_panic("TODO number expr");
            break;
        case AstNodeExpressionTypeString:
            zig_panic("TODO string expr");
            break;
        case AstNodeExpressionTypeFnCall:
            return gen_fn_call(g, expr_node->data.expression.data.fn_call);
    }
    zig_unreachable();
}

static void gen_block(CodeGen *g, AstNode *block_node) {
    assert(block_node->type == NodeTypeBlock);

    for (int i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        assert(statement_node->type == NodeTypeStatement);
        switch (statement_node->data.statement.type) {
            case AstNodeStatementTypeReturn:
                {
                    AstNode *expr_node = statement_node->data.statement.data.retrn.expression;
                    LLVMValueRef value = gen_expr(g, expr_node);
                    LLVMBuildRet(g->builder, value);
                    break;
                }
            case AstNodeStatementTypeExpression:
                {
                    AstNode *expr_node = statement_node->data.statement.data.expr.expression;
                    gen_expr(g, expr_node);
                    break;
                }
        }
    }
}

void code_gen(CodeGen *g) {
    LLVMModuleRef mod = LLVMModuleCreateWithName("ZigModule");
    g->builder = LLVMCreateBuilder();


    for (int fn_decl_i = 0; fn_decl_i < g->root->data.root.fn_decls.length; fn_decl_i += 1) {
        AstNode *fn_decl_node = g->root->data.root.fn_decls.at(fn_decl_i);
        AstNodeFnDecl *fn_decl = &fn_decl_node->data.fn_decl;

        LLVMTypeRef ret_type = to_llvm_type(fn_decl->return_type);
        LLVMTypeRef *param_types = allocate<LLVMTypeRef>(fn_decl->params.length);
        for (int param_decl_i = 0; param_decl_i < fn_decl->params.length; param_decl_i += 1) {
            AstNode *param_node = fn_decl->params.at(param_decl_i);
            assert(param_node->type == NodeTypeParamDecl);
            AstNode *type_node = param_node->data.param_decl.type;
            param_types[param_decl_i] = to_llvm_type(type_node);
        }
        LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, fn_decl->params.length, 0);
        LLVMValueRef fn = LLVMAddFunction(mod, buf_ptr(&fn_decl->name), function_type);

        LLVMBasicBlockRef entry = LLVMAppendBasicBlock(fn, "entry");
        LLVMPositionBuilderAtEnd(g->builder, entry);

        gen_block(g, fn_decl->body);
    }

    LLVMDumpModule(mod);
}

ZigList<ErrorMsg> *codegen_error_messages(CodeGen *g) {
    return &g->errors;
}
