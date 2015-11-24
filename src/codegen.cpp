#include "codegen.hpp"
#include "hash_map.hpp"

#include <stdio.h>

#include <llvm-c/Core.h>
#include <llvm-c/Analysis.h>

struct FnTableEntry {
    LLVMValueRef fn_value;
    AstNode *proto_node;
};

struct CodeGen {
    LLVMModuleRef mod;
    AstNode *root;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> fn_defs;
    ZigList<ErrorMsg> errors;
    LLVMBuilderRef builder;
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;
    HashMap<Buf *, LLVMValueRef, buf_hash, buf_eql_buf> str_table;
};

struct CodeGenNode {
    union {
        LLVMTypeRef type_ref; // for NodeTypeType
    } data;
};

CodeGen *create_codegen(AstNode *root) {
    CodeGen *g = allocate<CodeGen>(1);
    g->root = root;
    g->fn_defs.init(32);
    g->fn_table.init(32);
    g->str_table.init(32);
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

static LLVMTypeRef to_llvm_type(AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);

    return type_node->codegen_node->data.type_ref;
}

static void analyze_node(CodeGen *g, AstNode *node) {
    switch (node->type) {
        case NodeTypeRoot:
            for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                AstNode *child = node->data.root.top_level_decls.at(i);
                analyze_node(g, child);
            }
            break;
        case NodeTypeExternBlock:
            for (int fn_decl_i = 0; fn_decl_i < node->data.extern_block.fn_decls.length; fn_decl_i += 1) {
                AstNode *fn_decl = node->data.extern_block.fn_decls.at(fn_decl_i);
                analyze_node(g, fn_decl);

                AstNode *fn_proto = fn_decl->data.fn_decl.fn_proto;
                Buf *name = &fn_proto->data.fn_proto.name;
                ZigList<AstNode *> *params = &fn_proto->data.fn_proto.params;

                LLVMTypeRef *fn_param_values = allocate<LLVMTypeRef>(params->length);
                for (int param_i = 0; param_i < params->length; param_i += 1) {
                    AstNode *param_node = params->at(param_i);
                    assert(param_node->type == NodeTypeParamDecl);
                    AstNode *param_type = param_node->data.param_decl.type;
                    fn_param_values[param_i] = to_llvm_type(param_type);
                }
                LLVMTypeRef return_type = to_llvm_type(fn_proto->data.fn_proto.return_type);

                LLVMTypeRef fn_type = LLVMFunctionType(return_type, fn_param_values, params->length, 0);
                LLVMValueRef fn_val = LLVMAddFunction(g->mod, buf_ptr(name), fn_type);
                LLVMSetLinkage(fn_val, LLVMExternalLinkage);
                LLVMSetFunctionCallConv(fn_val, LLVMCCallConv);

                FnTableEntry *fn_table_entry = allocate<FnTableEntry>(1);
                fn_table_entry->fn_value = fn_val;
                fn_table_entry->proto_node = fn_proto;
                g->fn_table.put(name, fn_table_entry);
            }
            break;
        case NodeTypeFnDef:
            {
                AstNode *proto_node = node->data.fn_def.fn_proto;
                assert(proto_node->type = NodeTypeFnProto);
                Buf *proto_name = &proto_node->data.fn_proto.name;
                auto entry = g->fn_defs.maybe_get(proto_name);
                if (entry) {
                    add_node_error(g, node,
                            buf_sprintf("redefinition of '%s'", buf_ptr(proto_name)));
                } else {
                    g->fn_defs.put(proto_name, node);
                    analyze_node(g, proto_node);
                }
                break;
            }
        case NodeTypeFnDecl:
            {
                AstNode *proto_node = node->data.fn_decl.fn_proto;
                assert(proto_node->type == NodeTypeFnProto);
                analyze_node(g, proto_node);
                break;
            }
        case NodeTypeFnProto:
            {
                for (int i = 0; i < node->data.fn_proto.params.length; i += 1) {
                    AstNode *child = node->data.fn_proto.params.at(i);
                    analyze_node(g, child);
                }
                analyze_node(g, node->data.fn_proto.return_type);
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


void semantic_analyze(CodeGen *g) {
    g->mod = LLVMModuleCreateWithName("ZigModule");

    // Pass 1.
    analyze_node(g, g->root);
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *expr_node);

static LLVMValueRef gen_fn_call(CodeGen *g, AstNode *fn_call_node) {
    assert(fn_call_node->type == NodeTypeFnCall);

    Buf *name = &fn_call_node->data.fn_call.name;

    auto entry = g->fn_table.maybe_get(name);
    if (!entry) {
        add_node_error(g, fn_call_node,
                buf_sprintf("undefined function: '%s'", buf_ptr(name)));
        return LLVMConstNull(LLVMInt32Type());
    }
    FnTableEntry *fn_table_entry = entry->value;
    assert(fn_table_entry->proto_node->type == NodeTypeFnProto);
    int expected_param_count = fn_table_entry->proto_node->data.fn_proto.params.length;
    int actual_param_count = fn_call_node->data.fn_call.params.length;
    if (expected_param_count != actual_param_count) {
        add_node_error(g, fn_call_node,
                buf_sprintf("wrong number of arguments. Expected %d, got %d.",
                    expected_param_count, actual_param_count));
        return LLVMConstNull(LLVMInt32Type());
    }

    LLVMValueRef *param_values = allocate<LLVMValueRef>(actual_param_count);
    for (int i = 0; i < actual_param_count; i += 1) {
        AstNode *expr_node = fn_call_node->data.fn_call.params.at(i);
        param_values[i] = gen_expr(g, expr_node);
    }

    LLVMValueRef result = LLVMBuildCall(g->builder, fn_table_entry->fn_value,
            param_values, actual_param_count, "");

    return result;
}

static LLVMValueRef find_or_create_string(CodeGen *g, Buf *str) {
    auto entry = g->str_table.maybe_get(str);
    if (entry) {
        return entry->value;
    }
    LLVMValueRef text = LLVMConstString(buf_ptr(str), buf_len(str), false);
    LLVMValueRef global_value = LLVMAddGlobal(g->mod, LLVMTypeOf(text), "");
    LLVMSetLinkage(global_value, LLVMPrivateLinkage);
    LLVMSetInitializer(global_value, text);
    LLVMSetGlobalConstant(global_value, true);
    LLVMSetUnnamedAddr(global_value, true);
    g->str_table.put(str, global_value);

    return global_value;
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *expr_node) {
    assert(expr_node->type == NodeTypeExpression);
    switch (expr_node->data.expression.type) {
        case AstNodeExpressionTypeNumber:
            {
                Buf *number_str = &expr_node->data.expression.data.number;
                LLVMTypeRef number_type = LLVMInt32Type();
                LLVMValueRef number_val = LLVMConstIntOfStringAndSize(number_type,
                        buf_ptr(number_str), buf_len(number_str), 10);
                return number_val;
            }
        case AstNodeExpressionTypeString:
            {
                Buf *str = &expr_node->data.expression.data.string;
                LLVMValueRef str_val = find_or_create_string(g, str);
                LLVMValueRef indices[] = {
                    LLVMConstInt(LLVMInt32Type(), 0, false),
                    LLVMConstInt(LLVMInt32Type(), 0, false)
                };
                LLVMValueRef ptr_val = LLVMBuildInBoundsGEP(g->builder, str_val,
                        indices, 2, "");

                return ptr_val;
            }
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
    g->builder = LLVMCreateBuilder();

    auto it = g->fn_defs.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        AstNode *fn_def_node = entry->value;
        AstNodeFnDef *fn_def = &fn_def_node->data.fn_def;
        assert(fn_def->fn_proto->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &fn_def->fn_proto->data.fn_proto;

        LLVMTypeRef ret_type = to_llvm_type(fn_proto->return_type);
        LLVMTypeRef *param_types = allocate<LLVMTypeRef>(fn_proto->params.length);
        for (int param_decl_i = 0; param_decl_i < fn_proto->params.length; param_decl_i += 1) {
            AstNode *param_node = fn_proto->params.at(param_decl_i);
            assert(param_node->type == NodeTypeParamDecl);
            AstNode *type_node = param_node->data.param_decl.type;
            param_types[param_decl_i] = to_llvm_type(type_node);
        }
        LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, fn_proto->params.length, 0);
        LLVMValueRef fn = LLVMAddFunction(g->mod, buf_ptr(&fn_proto->name), function_type);

        LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn, "entry");
        LLVMPositionBuilderAtEnd(g->builder, entry_block);

        gen_block(g, fn_def->body);
    }

    LLVMDumpModule(g->mod);

    char *error = nullptr;
    LLVMVerifyModule(g->mod, LLVMAbortProcessAction, &error);
}

ZigList<ErrorMsg> *codegen_error_messages(CodeGen *g) {
    return &g->errors;
}
