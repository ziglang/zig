/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "codegen.hpp"
#include "hash_map.hpp"
#include "zig_llvm.hpp"
#include "os.hpp"
#include "config.h"

#include <stdio.h>

#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/DIBuilder.h>
#include <llvm/IR/DiagnosticInfo.h>
#include <llvm/IR/DiagnosticPrinter.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Support/TargetParser.h>

struct FnTableEntry {
    LLVMValueRef fn_value;
    AstNode *proto_node;
    AstNode *fn_def_node;
    bool is_extern;
    bool internal_linkage;
    unsigned calling_convention;
};

enum TypeId {
    TypeIdUserDefined,
    TypeIdPointer,
    TypeIdU8,
    TypeIdI32,
    TypeIdVoid,
    TypeIdUnreachable,
};

struct TypeTableEntry {
    TypeId id;
    LLVMTypeRef type_ref;
    llvm::DIType *di_type;

    TypeTableEntry *pointer_child;
    bool pointer_is_const;
    int user_defined_id;
    Buf name;
    TypeTableEntry *pointer_const_parent;
    TypeTableEntry *pointer_mut_parent;
};

struct CodeGen {
    LLVMModuleRef module;
    AstNode *root;
    ZigList<ErrorMsg> errors;
    LLVMBuilderRef builder;
    llvm::DIBuilder *dbuilder;
    llvm::DICompileUnit *compile_unit;
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;
    HashMap<Buf *, LLVMValueRef, buf_hash, buf_eql_buf> str_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> type_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> link_table;
    TypeTableEntry *invalid_type_entry;
    LLVMTargetDataRef target_data_ref;
    unsigned pointer_size_bytes;
    bool is_static;
    bool strip_debug_symbols;
    CodeGenBuildType build_type;
    LLVMTargetMachineRef target_machine;
    bool is_native_target;
    Buf in_file;
    Buf in_dir;
    ZigList<llvm::DIScope *> block_scopes;
    llvm::DIFile *di_file;
    ZigList<FnTableEntry *> fn_defs;
    Buf *out_name;
    OutType out_type;
    LLVMValueRef cur_fn;
};

struct TypeNode {
    TypeTableEntry *entry;
};

struct FnDefNode {
    bool add_implicit_return;
    bool skip;
};

struct CodeGenNode {
    union {
        TypeNode type_node; // for NodeTypeType
        FnDefNode fn_def_node; // for NodeTypeFnDef
    } data;
};

CodeGen *create_codegen(AstNode *root, Buf *in_full_path) {
    CodeGen *g = allocate<CodeGen>(1);
    g->root = root;
    g->fn_table.init(32);
    g->str_table.init(32);
    g->type_table.init(32);
    g->link_table.init(32);
    g->is_static = false;
    g->build_type = CodeGenBuildTypeDebug;
    g->strip_debug_symbols = false;
    g->out_name = nullptr;
    g->out_type = OutTypeUnknown;

    os_path_split(in_full_path, &g->in_dir, &g->in_file);
    return g;
}

void codegen_set_build_type(CodeGen *g, CodeGenBuildType build_type) {
    g->build_type = build_type;
}

void codegen_set_is_static(CodeGen *g, bool is_static) {
    g->is_static = is_static;
}

void codegen_set_strip(CodeGen *g, bool strip) {
    g->strip_debug_symbols = strip;
}

void codegen_set_out_type(CodeGen *g, OutType out_type) {
    g->out_type = out_type;
}

void codegen_set_out_name(CodeGen *g, Buf *out_name) {
    g->out_name = out_name;
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
    assert(type_node->codegen_node->data.type_node.entry);

    return type_node->codegen_node->data.type_node.entry->type_ref;
}

static llvm::DIType *to_llvm_debug_type(AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);
    assert(type_node->codegen_node->data.type_node.entry);

    return type_node->codegen_node->data.type_node.entry->di_type;
}


static bool type_is_unreachable(AstNode *type_node) {
    assert(type_node->type == NodeTypeType);
    assert(type_node->codegen_node);
    assert(type_node->codegen_node->data.type_node.entry);
    return type_node->codegen_node->data.type_node.entry->id == TypeIdUnreachable;
}

static void find_declarations(CodeGen *g, AstNode *node);

static void resolve_type_and_recurse(CodeGen *g, AstNode *node) {
    assert(!node->codegen_node);
    node->codegen_node = allocate<CodeGenNode>(1);
    TypeNode *type_node = &node->codegen_node->data.type_node;
    switch (node->data.type.type) {
        case AstNodeTypeTypePrimitive:
            {
                Buf *name = &node->data.type.primitive_name;
                auto table_entry = g->type_table.maybe_get(name);
                if (table_entry) {
                    type_node->entry = table_entry->value;
                } else {
                    add_node_error(g, node,
                            buf_sprintf("invalid type name: '%s'", buf_ptr(name)));
                    type_node->entry = g->invalid_type_entry;
                }
                break;
            }
        case AstNodeTypeTypePointer:
            {
                find_declarations(g, node->data.type.child_type);
                TypeNode *child_type_node = &node->data.type.child_type->codegen_node->data.type_node;
                if (child_type_node->entry->id == TypeIdUnreachable) {
                    add_node_error(g, node,
                            buf_create_from_str("pointer to unreachable not allowed"));
                }
                TypeTableEntry **parent_pointer = node->data.type.is_const ?
                    &child_type_node->entry->pointer_const_parent :
                    &child_type_node->entry->pointer_mut_parent;
                const char *const_or_mut_str = node->data.type.is_const ? "const" : "mut";
                if (*parent_pointer) {
                    type_node->entry = *parent_pointer;
                } else {
                    TypeTableEntry *entry = allocate<TypeTableEntry>(1);
                    entry->id = TypeIdPointer;
                    entry->type_ref = LLVMPointerType(child_type_node->entry->type_ref, 0);
                    buf_resize(&entry->name, 0);
                    buf_appendf(&entry->name, "*%s %s", const_or_mut_str, buf_ptr(&child_type_node->entry->name));
                    entry->di_type = g->dbuilder->createPointerType(child_type_node->entry->di_type,
                            g->pointer_size_bytes * 8, g->pointer_size_bytes * 8, buf_ptr(&entry->name));
                    g->type_table.put(&entry->name, entry);
                    type_node->entry = entry;
                    *parent_pointer = entry;
                }
                break;
            }
    }
}

static void find_declarations(CodeGen *g, AstNode *node) {
    switch (node->type) {
        case NodeTypeExternBlock:
            for (int i = 0; i < node->data.extern_block.directives->length; i += 1) {
                AstNode *directive_node = node->data.extern_block.directives->at(i);
                Buf *name = &directive_node->data.directive.name;
                Buf *param = &directive_node->data.directive.param;
                if (buf_eql_str(name, "link")) {
                    g->link_table.put(param, true);
                } else {
                    add_node_error(g, directive_node,
                            buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
                }
            }

            for (int fn_decl_i = 0; fn_decl_i < node->data.extern_block.fn_decls.length; fn_decl_i += 1) {
                AstNode *fn_decl = node->data.extern_block.fn_decls.at(fn_decl_i);
                assert(fn_decl->type == NodeTypeFnDecl);
                AstNode *fn_proto = fn_decl->data.fn_decl.fn_proto;
                find_declarations(g, fn_proto);
                Buf *name = &fn_proto->data.fn_proto.name;

                FnTableEntry *fn_table_entry = allocate<FnTableEntry>(1);
                fn_table_entry->proto_node = fn_proto;
                fn_table_entry->is_extern = true;
                fn_table_entry->calling_convention = LLVMCCallConv;
                g->fn_table.put(name, fn_table_entry);
            }
            break;
        case NodeTypeFnDef:
            {
                AstNode *proto_node = node->data.fn_def.fn_proto;
                assert(proto_node->type == NodeTypeFnProto);
                Buf *proto_name = &proto_node->data.fn_proto.name;
                auto entry = g->fn_table.maybe_get(proto_name);
                if (entry) {
                    add_node_error(g, node,
                            buf_sprintf("redefinition of '%s'", buf_ptr(proto_name)));
                    assert(!node->codegen_node);
                    node->codegen_node = allocate<CodeGenNode>(1);
                    node->codegen_node->data.fn_def_node.skip = true;
                } else {
                    FnTableEntry *fn_table_entry = allocate<FnTableEntry>(1);
                    fn_table_entry->proto_node = proto_node;
                    fn_table_entry->fn_def_node = node;
                    fn_table_entry->internal_linkage = proto_node->data.fn_proto.visib_mod != FnProtoVisibModExport;
                    if (fn_table_entry->internal_linkage) {
                        fn_table_entry->calling_convention = LLVMFastCallConv;
                    } else {
                        fn_table_entry->calling_convention = LLVMCCallConv;
                    }
                    g->fn_table.put(proto_name, fn_table_entry);
                    g->fn_defs.append(fn_table_entry);

                    find_declarations(g, proto_node);
                }
                break;
            }
        case NodeTypeFnProto:
            {
                for (int i = 0; i < node->data.fn_proto.directives->length; i += 1) {
                    AstNode *directive_node = node->data.fn_proto.directives->at(i);
                    Buf *name = &directive_node->data.directive.name;
                    add_node_error(g, directive_node,
                            buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
                }
                for (int i = 0; i < node->data.fn_proto.params.length; i += 1) {
                    AstNode *child = node->data.fn_proto.params.at(i);
                    find_declarations(g, child);
                }
                find_declarations(g, node->data.fn_proto.return_type);
                break;
            }
            break;
        case NodeTypeParamDecl:
            find_declarations(g, node->data.param_decl.type);
            break;
        case NodeTypeType:
            resolve_type_and_recurse(g, node);
            break;
        case NodeTypeDirective:
            // we handled directives in the parent function
            break;
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCall:
        case NodeTypeRootExportDecl:
        case NodeTypeCastExpr:
        case NodeTypePrimaryExpr:
        case NodeTypeGroupedExpr:
            zig_unreachable();
    }
}

static void check_fn_def_control_flow(CodeGen *g, AstNode *node) {
    // Follow the execution flow and make sure the code returns appropriately.
    // * A `return` statement in an unreachable type function should be an error.
    // * Control flow should not be able to reach the end of an unreachable type function.
    // * Functions that have a type other than void should not return without a value.
    // * void functions without explicit return statements at the end need the
    //   add_implicit_return flag set on the codegen node.
    assert(node->type == NodeTypeFnDef);
    AstNode *proto_node = node->data.fn_def.fn_proto;
    assert(proto_node->type == NodeTypeFnProto);
    AstNode *return_type_node = proto_node->data.fn_proto.return_type;
    assert(return_type_node->type == NodeTypeType);

    node->codegen_node = allocate<CodeGenNode>(1);
    FnDefNode *codegen_fn_def = &node->codegen_node->data.fn_def_node;

    assert(return_type_node->codegen_node);
    TypeTableEntry *type_entry = return_type_node->codegen_node->data.type_node.entry;
    assert(type_entry);
    TypeId type_id = type_entry->id;

    AstNode *body_node = node->data.fn_def.body;
    assert(body_node->type == NodeTypeBlock);

    // TODO once we understand types, do this pass after type checking, and
    // if an expression has an unreachable value then stop looking at statements after
    // it. then we can remove the check to `unreachable` in the end of this function.
    bool prev_statement_return = false;
    for (int i = 0; i < body_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = body_node->data.block.statements.at(i);
        if (statement_node->type == NodeTypeReturnExpr) {
            if (type_id == TypeIdUnreachable) {
                add_node_error(g, statement_node,
                        buf_sprintf("return statement in function with unreachable return type"));
                return;
            } else {
                prev_statement_return = true;
            }
        } else if (prev_statement_return) {
            add_node_error(g, statement_node,
                    buf_sprintf("unreachable code"));
        }
    }

    if (!prev_statement_return) {
        if (type_id == TypeIdVoid) {
            codegen_fn_def->add_implicit_return = true;
        } else if (type_id != TypeIdUnreachable) {
            add_node_error(g, node,
                    buf_sprintf("control reaches end of non-void function"));
        }
    }
}

static void analyze_node(CodeGen *g, AstNode *node) {
    switch (node->type) {
        case NodeTypeRoot:
            {
                AstNode *root_export_decl_node = node->data.root.root_export_decl;
                if (root_export_decl_node) {
                    assert(root_export_decl_node->type == NodeTypeRootExportDecl);
                    if (!g->out_name)
                        g->out_name = &root_export_decl_node->data.root_export_decl.name;

                    Buf *out_type = &root_export_decl_node->data.root_export_decl.type;
                    OutType export_out_type;
                    if (buf_eql_str(out_type, "executable")) {
                        export_out_type = OutTypeExe;
                    } else if (buf_eql_str(out_type, "library")) {
                        export_out_type = OutTypeLib;
                    } else if (buf_eql_str(out_type, "object")) {
                        export_out_type = OutTypeObj;
                    } else {
                        add_node_error(g, root_export_decl_node,
                                buf_sprintf("invalid export type: '%s'", buf_ptr(out_type)));
                    }
                    if (g->out_type == OutTypeUnknown)
                        g->out_type = export_out_type;
                } else {
                    if (!g->out_name) {
                        add_node_error(g, node,
                                buf_sprintf("missing export declaration and output name not provided"));
                    } else if (g->out_type == OutTypeUnknown) {
                        add_node_error(g, node,
                                buf_sprintf("missing export declaration and export type not provided"));
                    }
                }

                // Iterate once over the top level declarations to build the function table
                for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                    AstNode *child = node->data.root.top_level_decls.at(i);
                    find_declarations(g, child);
                }
                for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                    AstNode *child = node->data.root.top_level_decls.at(i);
                    analyze_node(g, child);
                }
                break;
            }
        case NodeTypeRootExportDecl:
            // handled in parent
            break;
        case NodeTypeExternBlock:
            for (int fn_decl_i = 0; fn_decl_i < node->data.extern_block.fn_decls.length; fn_decl_i += 1) {
                AstNode *fn_decl = node->data.extern_block.fn_decls.at(fn_decl_i);
                analyze_node(g, fn_decl);
            }
            break;
        case NodeTypeFnDef:
            {
                if (node->codegen_node && node->codegen_node->data.fn_def_node.skip) {
                    // we detected an error with this function definition which prevents us
                    // from further analyzing it.
                    break;
                }

                AstNode *proto_node = node->data.fn_def.fn_proto;
                assert(proto_node->type == NodeTypeFnProto);
                analyze_node(g, proto_node);

                check_fn_def_control_flow(g, node);
                analyze_node(g, node->data.fn_def.body);
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
            // ignore; we handled types with find_declarations
            break;
        case NodeTypeBlock:
            for (int i = 0; i < node->data.block.statements.length; i += 1) {
                AstNode *child = node->data.block.statements.at(i);
                analyze_node(g, child);
            }
            break;
        case NodeTypeReturnExpr:
            if (node->data.return_expr.expr) {
                analyze_node(g, node->data.return_expr.expr);
            }
            break;
        case NodeTypeBinOpExpr:
            analyze_node(g, node->data.bin_op_expr.op1);
            analyze_node(g, node->data.bin_op_expr.op2);
            break;
        case NodeTypeFnCall:
            {
                Buf *name = &node->data.fn_call.name;

                auto entry = g->fn_table.maybe_get(name);
                if (!entry) {
                    add_node_error(g, node,
                            buf_sprintf("undefined function: '%s'", buf_ptr(name)));
                } else {
                    FnTableEntry *fn_table_entry = entry->value;
                    assert(fn_table_entry->proto_node->type == NodeTypeFnProto);
                    int expected_param_count = fn_table_entry->proto_node->data.fn_proto.params.length;
                    int actual_param_count = node->data.fn_call.params.length;
                    if (expected_param_count != actual_param_count) {
                        add_node_error(g, node,
                                buf_sprintf("wrong number of arguments. Expected %d, got %d.",
                                    expected_param_count, actual_param_count));
                    }
                }

                for (int i = 0; i < node->data.fn_call.params.length; i += 1) {
                    AstNode *child = node->data.fn_call.params.at(i);
                    analyze_node(g, child);
                }
                break;
            }
        case NodeTypeDirective:
            // we looked at directives in the parent node
            break;
        case NodeTypeCastExpr:
            zig_panic("TODO");
            break;
        case NodeTypePrimaryExpr:
            switch (node->data.primary_expr.type) {
                case PrimaryExprTypeNumber:
                case PrimaryExprTypeString:
                case PrimaryExprTypeUnreachable:
                    // nothing to do
                    break;
                case PrimaryExprTypeFnCall:
                    analyze_node(g, node->data.primary_expr.data.fn_call);
                    break;
                case PrimaryExprTypeGroupedExpr:
                    analyze_node(g, node->data.primary_expr.data.grouped_expr);
                    break;
                case PrimaryExprTypeBlock:
                    analyze_node(g, node->data.primary_expr.data.block);
                    break;
            }
            break;
        case NodeTypeGroupedExpr:
            zig_panic("TODO");
            break;
    }
}

static void add_types(CodeGen *g) {
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->id = TypeIdU8;
        entry->type_ref = LLVMInt8Type();
        buf_init_from_str(&entry->name, "u8");
        entry->di_type = g->dbuilder->createBasicType(buf_ptr(&entry->name), 8, 8, llvm::dwarf::DW_ATE_unsigned);
        g->type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->id = TypeIdI32;
        entry->type_ref = LLVMInt32Type();
        buf_init_from_str(&entry->name, "i32");
        entry->di_type = g->dbuilder->createBasicType(buf_ptr(&entry->name), 32, 32,
                llvm::dwarf::DW_ATE_signed);
        g->type_table.put(&entry->name, entry);
    }
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->id = TypeIdVoid;
        entry->type_ref = LLVMVoidType();
        buf_init_from_str(&entry->name, "void");
        entry->di_type = g->dbuilder->createBasicType(buf_ptr(&entry->name), 0, 0,
                llvm::dwarf::DW_ATE_unsigned);
        g->type_table.put(&entry->name, entry);

        // invalid types are void
        g->invalid_type_entry = entry;
    }
    {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->id = TypeIdUnreachable;
        entry->type_ref = LLVMVoidType();
        buf_init_from_str(&entry->name, "unreachable");
        entry->di_type = g->invalid_type_entry->di_type;
        g->type_table.put(&entry->name, entry);
    }
}


void semantic_analyze(CodeGen *g) {
    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetMCs();
    LLVMInitializeAllAsmPrinters();
    LLVMInitializeAllAsmParsers();
    LLVMInitializeNativeTarget();

    g->is_native_target = true;
    char *native_triple = LLVMGetDefaultTargetTriple();

    LLVMTargetRef target_ref;
    char *err_msg = nullptr;
    if (LLVMGetTargetFromTriple(native_triple, &target_ref, &err_msg)) {
        zig_panic("unable to get target from triple: %s", err_msg);
    }

    char *native_cpu = LLVMZigGetHostCPUName();
    char *native_features = LLVMZigGetNativeFeatures();

    LLVMCodeGenOptLevel opt_level = (g->build_type == CodeGenBuildTypeDebug) ?
        LLVMCodeGenLevelNone : LLVMCodeGenLevelAggressive;

    LLVMRelocMode reloc_mode = g->is_static ? LLVMRelocStatic : LLVMRelocPIC;

    g->target_machine = LLVMCreateTargetMachine(target_ref, native_triple,
            native_cpu, native_features, opt_level, reloc_mode, LLVMCodeModelDefault);

    g->target_data_ref = LLVMGetTargetMachineData(g->target_machine);


    g->module = LLVMModuleCreateWithName("ZigModule");

    g->pointer_size_bytes = LLVMPointerSize(g->target_data_ref);

    g->builder = LLVMCreateBuilder();
    g->dbuilder = new llvm::DIBuilder(*llvm::unwrap(g->module), true);


    add_types(g);

    analyze_node(g, g->root);
}

static LLVMValueRef gen_expr(CodeGen *g, AstNode *expr_node);

static void add_debug_source_node(CodeGen *g, AstNode *node) {
    llvm::unwrap(g->builder)->SetCurrentDebugLocation(llvm::DebugLoc::get(
                node->line + 1, node->column + 1,
                g->block_scopes.last()));
}

static LLVMValueRef gen_fn_call(CodeGen *g, AstNode *fn_call_node) {
    assert(fn_call_node->type == NodeTypeFnCall);

    Buf *name = &fn_call_node->data.fn_call.name;
    FnTableEntry *fn_table_entry = g->fn_table.get(name);
    assert(fn_table_entry->proto_node->type == NodeTypeFnProto);
    int expected_param_count = fn_table_entry->proto_node->data.fn_proto.params.length;
    int actual_param_count = fn_call_node->data.fn_call.params.length;
    assert(expected_param_count == actual_param_count);

    LLVMValueRef *param_values = allocate<LLVMValueRef>(actual_param_count);
    for (int i = 0; i < actual_param_count; i += 1) {
        AstNode *expr_node = fn_call_node->data.fn_call.params.at(i);
        param_values[i] = gen_expr(g, expr_node);
    }

    add_debug_source_node(g, fn_call_node);
    LLVMValueRef result = LLVMZigBuildCall(g->builder, fn_table_entry->fn_value,
            param_values, actual_param_count, fn_table_entry->calling_convention, "");

    if (type_is_unreachable(fn_table_entry->proto_node->data.fn_proto.return_type)) {
        return LLVMBuildUnreachable(g->builder);
    } else {
        return result;
    }
}

static LLVMValueRef find_or_create_string(CodeGen *g, Buf *str) {
    auto entry = g->str_table.maybe_get(str);
    if (entry) {
        return entry->value;
    }
    LLVMValueRef text = LLVMConstString(buf_ptr(str), buf_len(str), false);
    LLVMValueRef global_value = LLVMAddGlobal(g->module, LLVMTypeOf(text), "");
    LLVMSetLinkage(global_value, LLVMPrivateLinkage);
    LLVMSetInitializer(global_value, text);
    LLVMSetGlobalConstant(global_value, true);
    LLVMSetUnnamedAddr(global_value, true);
    g->str_table.put(str, global_value);

    return global_value;
}

static LLVMValueRef gen_primary_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypePrimaryExpr);

    AstNodePrimaryExpr *prim_expr = &node->data.primary_expr;

    switch (node->data.primary_expr.type) {
        case PrimaryExprTypeNumber:
            {
                Buf *number_str = &prim_expr->data.number;
                LLVMTypeRef number_type = LLVMInt32Type();
                LLVMValueRef number_val = LLVMConstIntOfStringAndSize(number_type,
                        buf_ptr(number_str), buf_len(number_str), 10);
                return number_val;
            }
        case PrimaryExprTypeString:
            {
                Buf *str = &prim_expr->data.string;
                LLVMValueRef str_val = find_or_create_string(g, str);
                LLVMValueRef indices[] = {
                    LLVMConstInt(LLVMInt32Type(), 0, false),
                    LLVMConstInt(LLVMInt32Type(), 0, false)
                };
                LLVMValueRef ptr_val = LLVMBuildInBoundsGEP(g->builder, str_val, indices, 2, "");
                return ptr_val;
            }
        case PrimaryExprTypeUnreachable:
            add_debug_source_node(g, node);
            return LLVMBuildUnreachable(g->builder);
        case PrimaryExprTypeFnCall:
            return gen_fn_call(g, prim_expr->data.fn_call);
        case PrimaryExprTypeGroupedExpr:
            return gen_expr(g, prim_expr->data.grouped_expr);
        case PrimaryExprTypeBlock:
            break;
    }

    zig_unreachable();
}

static LLVMValueRef gen_cast_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeCastExpr);

    LLVMValueRef expr = gen_primary_expr(g, node->data.cast_expr.primary_expr);

    if (!node->data.cast_expr.type)
        return expr;

    zig_panic("TODO cast expression");
}

static LLVMValueRef gen_mult_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeMult:
            // TODO types so we know float vs int
            add_debug_source_node(g, node);
            return LLVMBuildMul(g->builder, val1, val2, "");
        case BinOpTypeDiv:
            // TODO types so we know float vs int and signed vs unsigned
            add_debug_source_node(g, node);
            return LLVMBuildSDiv(g->builder, val1, val2, "");
        case BinOpTypeMod:
            // TODO types so we know float vs int and signed vs unsigned
            add_debug_source_node(g, node);
            return LLVMBuildSRem(g->builder, val1, val2, "");
        default:
            zig_unreachable();
    }
    zig_unreachable();
}

static LLVMValueRef gen_add_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeAdd:
            add_debug_source_node(g, node);
            return LLVMBuildAdd(g->builder, val1, val2, "");
        case BinOpTypeSub:
            add_debug_source_node(g, node);
            return LLVMBuildSub(g->builder, val1, val2, "");
        default:
            zig_unreachable();
    }
    zig_unreachable();
}

static LLVMValueRef gen_bit_shift_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeBitShiftLeft:
            add_debug_source_node(g, node);
            return LLVMBuildShl(g->builder, val1, val2, "");
        case BinOpTypeBitShiftRight:
            // TODO implement type system so that we know whether to do
            // logical or arithmetic shifting here.
            // signed -> arithmetic, unsigned -> logical
            add_debug_source_node(g, node);
            return LLVMBuildLShr(g->builder, val1, val2, "");
        default:
            zig_unreachable();
    }
    zig_unreachable();
}

static LLVMValueRef gen_bin_and_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    add_debug_source_node(g, node);
    return LLVMBuildAnd(g->builder, val1, val2, "");
}

static LLVMValueRef gen_bin_xor_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    add_debug_source_node(g, node);
    return LLVMBuildXor(g->builder, val1, val2, "");
}

static LLVMValueRef gen_bin_or_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    add_debug_source_node(g, node);
    return LLVMBuildOr(g->builder, val1, val2, "");
}

static LLVMIntPredicate cmp_op_to_int_predicate(BinOpType cmp_op, bool is_signed) {
    switch (cmp_op) {
        case BinOpTypeInvalid:
            zig_unreachable();
        case BinOpTypeCmpEq:
            return LLVMIntEQ;
        case BinOpTypeCmpNotEq:
            return LLVMIntNE;
        case BinOpTypeCmpLessThan:
            return is_signed ? LLVMIntSLT : LLVMIntULT;
        case BinOpTypeCmpGreaterThan:
            return is_signed ? LLVMIntSGT : LLVMIntUGT;
        case BinOpTypeCmpLessOrEq:
            return is_signed ? LLVMIntSLE : LLVMIntULE;
        case BinOpTypeCmpGreaterOrEq:
            return is_signed ? LLVMIntSGE : LLVMIntUGE;
        default:
            zig_unreachable();
    }
}

static LLVMValueRef gen_cmp_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);

    // TODO implement type system so that we know whether to do signed or unsigned comparison here
    LLVMIntPredicate pred = cmp_op_to_int_predicate(node->data.bin_op_expr.bin_op, true);
    add_debug_source_node(g, node);
    return LLVMBuildICmp(g->builder, pred, val1, val2, "");
}

static LLVMValueRef gen_bool_and_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, node->data.bin_op_expr.op1);

    // block for when val1 == true
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn, "BoolAndTrue");
    // block for when val1 == false (don't even evaluate the second part)
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn, "BoolAndFalse");

    LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(val1));
    add_debug_source_node(g, node);
    LLVMValueRef val1_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, zero, "");
    LLVMBuildCondBr(g->builder, val1_i1, false_block, true_block);

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    LLVMValueRef val2 = gen_expr(g, node->data.bin_op_expr.op2);
    add_debug_source_node(g, node);
    LLVMValueRef val2_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    add_debug_source_node(g, node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef one_i1 = LLVMConstAllOnes(LLVMInt1Type());
    LLVMValueRef incoming_values[2] = {one_i1, val2_i1};
    LLVMBasicBlockRef incoming_blocks[2] = {LLVMGetInsertBlock(g->builder), true_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_bool_or_expr(CodeGen *g, AstNode *expr_node) {
    assert(expr_node->type == NodeTypeBinOpExpr);

    LLVMValueRef val1 = gen_expr(g, expr_node->data.bin_op_expr.op1);

    // block for when val1 == false
    LLVMBasicBlockRef false_block = LLVMAppendBasicBlock(g->cur_fn, "BoolOrFalse");
    // block for when val1 == true (don't even evaluate the second part)
    LLVMBasicBlockRef true_block = LLVMAppendBasicBlock(g->cur_fn, "BoolOrTrue");

    LLVMValueRef zero = LLVMConstNull(LLVMTypeOf(val1));
    add_debug_source_node(g, expr_node);
    LLVMValueRef val1_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val1, zero, "");
    LLVMBuildCondBr(g->builder, val1_i1, false_block, true_block);

    LLVMPositionBuilderAtEnd(g->builder, false_block);
    LLVMValueRef val2 = gen_expr(g, expr_node->data.bin_op_expr.op2);
    add_debug_source_node(g, expr_node);
    LLVMValueRef val2_i1 = LLVMBuildICmp(g->builder, LLVMIntEQ, val2, zero, "");

    LLVMPositionBuilderAtEnd(g->builder, true_block);
    add_debug_source_node(g, expr_node);
    LLVMValueRef phi = LLVMBuildPhi(g->builder, LLVMInt1Type(), "");
    LLVMValueRef one_i1 = LLVMConstAllOnes(LLVMInt1Type());
    LLVMValueRef incoming_values[2] = {one_i1, val2_i1};
    LLVMBasicBlockRef incoming_blocks[2] = {LLVMGetInsertBlock(g->builder), false_block};
    LLVMAddIncoming(phi, incoming_values, incoming_blocks, 2);

    return phi;
}

static LLVMValueRef gen_bin_op_expr(CodeGen *g, AstNode *node) {
    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeInvalid:
            zig_unreachable();
        case BinOpTypeBoolOr:
            return gen_bool_or_expr(g, node);
        case BinOpTypeBoolAnd:
            return gen_bool_and_expr(g, node);
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
            return gen_cmp_expr(g, node);
        case BinOpTypeBinOr:
            return gen_bin_or_expr(g, node);
        case BinOpTypeBinXor:
            return gen_bin_xor_expr(g, node);
        case BinOpTypeBinAnd:
            return gen_bin_and_expr(g, node);
        case BinOpTypeBitShiftLeft:
        case BinOpTypeBitShiftRight:
            return gen_bit_shift_expr(g, node);
        case BinOpTypeAdd:
        case BinOpTypeSub:
            return gen_add_expr(g, node);
        case BinOpTypeMult:
        case BinOpTypeDiv:
        case BinOpTypeMod:
            return gen_mult_expr(g, node);
    }
    zig_unreachable();
}

static LLVMValueRef gen_return_expr(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeReturnExpr);
    AstNode *param_node = node->data.return_expr.expr;
    if (param_node) {
        LLVMValueRef value = gen_expr(g, param_node);

        add_debug_source_node(g, node);
        return LLVMBuildRet(g->builder, value);
    } else {
        add_debug_source_node(g, node);
        return LLVMBuildRetVoid(g->builder);
    }
}
/*
Expression : BoolOrExpression | ReturnExpression
*/
static LLVMValueRef gen_expr(CodeGen *g, AstNode *node) {
    switch (node->type) {
        case NodeTypeBinOpExpr:
            return gen_bin_op_expr(g, node);
        case NodeTypeReturnExpr:
            return gen_return_expr(g, node);
        case NodeTypeCastExpr:
            return gen_cast_expr(g, node);
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeType:
        case NodeTypeBlock:
        case NodeTypeFnCall:
        case NodeTypeExternBlock:
        case NodeTypeDirective:
        case NodeTypePrimaryExpr:
            return gen_primary_expr(g, node);
        case NodeTypeGroupedExpr:
            zig_unreachable();
    }
    zig_unreachable();
}

static void gen_block(CodeGen *g, AstNode *block_node, bool add_implicit_return) {
    assert(block_node->type == NodeTypeBlock);

    llvm::DILexicalBlock *di_block = g->dbuilder->createLexicalBlock(g->block_scopes.last(),
            g->di_file, block_node->line + 1, block_node->column + 1);
    g->block_scopes.append(di_block);

    add_debug_source_node(g, block_node);

    for (int i = 0; i < block_node->data.block.statements.length; i += 1) {
        AstNode *statement_node = block_node->data.block.statements.at(i);
        gen_expr(g, statement_node);
    }

    if (add_implicit_return) {
        LLVMBuildRetVoid(g->builder);
    }

    g->block_scopes.pop();
}

static llvm::DISubroutineType *create_di_function_type(CodeGen *g, AstNodeFnProto *fn_proto,
        llvm::DIFile *di_file)
{
    llvm::SmallVector<llvm::Metadata *, 8> types;

    llvm::DIType *return_type = to_llvm_debug_type(fn_proto->return_type);
    types.push_back(return_type);

    for (int i = 0; i < fn_proto->params.length; i += 1) {
        AstNode *param_node = fn_proto->params.at(i);
        llvm::DIType *param_type = to_llvm_debug_type(param_node);
        types.push_back(param_type);
    }

    return g->dbuilder->createSubroutineType(di_file, g->dbuilder->getOrCreateTypeArray(types));
}

void code_gen(CodeGen *g) {
    assert(!g->errors.length);

    Buf *producer = buf_sprintf("zig %s", ZIG_VERSION_STRING);
    bool is_optimized = g->build_type == CodeGenBuildTypeRelease;
    const char *flags = "";
    unsigned runtime_version = 0;
    g->compile_unit = g->dbuilder->createCompileUnit(llvm::dwarf::DW_LANG_C99,
            buf_ptr(&g->in_file), buf_ptr(&g->in_dir),
            buf_ptr(producer), is_optimized, flags, runtime_version,
            "", llvm::DIBuilder::FullDebug, 0, !g->strip_debug_symbols);

    g->block_scopes.append(g->compile_unit);

    g->di_file = g->dbuilder->createFile(g->compile_unit->getFilename(), g->compile_unit->getDirectory());


    // Generate function prototypes
    auto it = g->fn_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        FnTableEntry *fn_table_entry = entry->value;

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        LLVMTypeRef ret_type = to_llvm_type(fn_proto->return_type);
        LLVMTypeRef *param_types = allocate<LLVMTypeRef>(fn_proto->params.length);
        for (int param_decl_i = 0; param_decl_i < fn_proto->params.length; param_decl_i += 1) {
            AstNode *param_node = fn_proto->params.at(param_decl_i);
            assert(param_node->type == NodeTypeParamDecl);
            AstNode *type_node = param_node->data.param_decl.type;
            param_types[param_decl_i] = to_llvm_type(type_node);
        }
        LLVMTypeRef function_type = LLVMFunctionType(ret_type, param_types, fn_proto->params.length, 0);
        LLVMValueRef fn = LLVMAddFunction(g->module, buf_ptr(&fn_proto->name), function_type);

        LLVMSetLinkage(fn, fn_table_entry->internal_linkage ? LLVMInternalLinkage : LLVMExternalLinkage);

        if (type_is_unreachable(fn_proto->return_type)) {
            LLVMAddFunctionAttr(fn, LLVMNoReturnAttribute);
        }
        LLVMSetFunctionCallConv(fn, fn_table_entry->calling_convention);
        if (!fn_table_entry->is_extern) {
            LLVMAddFunctionAttr(fn, LLVMNoUnwindAttribute);
        }

        fn_table_entry->fn_value = fn;
    }

    // Generate function definitions.
    for (int i = 0; i < g->fn_defs.length; i += 1) {
        FnTableEntry *fn_table_entry = g->fn_defs.at(i);
        AstNode *fn_def_node = fn_table_entry->fn_def_node;
        LLVMValueRef fn = fn_table_entry->fn_value;
        g->cur_fn = fn;

        AstNode *proto_node = fn_table_entry->proto_node;
        assert(proto_node->type == NodeTypeFnProto);
        AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

        // Add debug info.
        llvm::DIScope *fn_scope = g->di_file;
        unsigned line_number = fn_def_node->line + 1;
        unsigned scope_line = line_number;
        bool is_definition = true;
        unsigned flags = 0;
        llvm::Function *unwrapped_function = reinterpret_cast<llvm::Function*>(llvm::unwrap(fn));
        llvm::DISubprogram *subprogram = g->dbuilder->createFunction(
            fn_scope, buf_ptr(&fn_proto->name), "", g->di_file, line_number,
            create_di_function_type(g, fn_proto, g->di_file), fn_table_entry->internal_linkage, 
            is_definition, scope_line, flags, is_optimized, unwrapped_function);

        g->block_scopes.append(subprogram);

        LLVMBasicBlockRef entry_block = LLVMAppendBasicBlock(fn, "entry");
        LLVMPositionBuilderAtEnd(g->builder, entry_block);

        CodeGenNode *codegen_node = fn_def_node->codegen_node;
        assert(codegen_node);
        bool add_implicit_return = codegen_node->data.fn_def_node.add_implicit_return;
        gen_block(g, fn_def_node->data.fn_def.body, add_implicit_return);

        g->block_scopes.pop();
    }
    assert(!g->errors.length);

    g->dbuilder->finalize();

    LLVMDumpModule(g->module);

    // in release mode, we're sooooo confident that we've generated correct ir,
    // that we skip the verify module step in order to get better performance.
#ifndef NDEBUG
    char *error = nullptr;
    LLVMVerifyModule(g->module, LLVMAbortProcessAction, &error);
#endif
}

void code_gen_optimize(CodeGen *g) {
    LLVMZigOptimizeModule(g->target_machine, g->module);
    LLVMDumpModule(g->module);
}

ZigList<ErrorMsg> *codegen_error_messages(CodeGen *g) {
    return &g->errors;
}

enum FloatAbi {
    FloatAbiHard,
    FloatAbiSoft,
    FloatAbiSoftFp,
};


static int get_arm_sub_arch_version(const llvm::Triple &triple) {
    return llvm::ARMTargetParser::parseArchVersion(triple.getArchName());
}

static FloatAbi get_float_abi(const llvm::Triple &triple) {
    switch (triple.getOS()) {
        case llvm::Triple::Darwin:
        case llvm::Triple::MacOSX:
        case llvm::Triple::IOS:
            if (get_arm_sub_arch_version(triple) == 6 ||
                get_arm_sub_arch_version(triple) == 7)
            {
                return FloatAbiSoftFp;
            } else {
                return FloatAbiSoft;
            }
        case llvm::Triple::Win32:
            return FloatAbiHard;
        case llvm::Triple::FreeBSD:
            switch (triple.getEnvironment()) {
                case llvm::Triple::GNUEABIHF:
                    return FloatAbiHard;
                default:
                    return FloatAbiSoft;
            }
        default:
            switch (triple.getEnvironment()) {
                case llvm::Triple::GNUEABIHF:
                    return FloatAbiHard;
                case llvm::Triple::GNUEABI:
                    return FloatAbiSoftFp;
                case llvm::Triple::EABIHF:
                    return FloatAbiHard;
                case llvm::Triple::EABI:
                    return FloatAbiSoftFp;
                case llvm::Triple::Android:
                    if (get_arm_sub_arch_version(triple) == 7) {
                        return FloatAbiSoftFp;
                    } else {
                        return FloatAbiSoft;
                    }
                default:
                    return FloatAbiSoft;
            }
    }
}

static Buf *get_dynamic_linker(CodeGen *g) {
    llvm::TargetMachine *target_machine = reinterpret_cast<llvm::TargetMachine*>(g->target_machine);
    const llvm::Triple &triple = target_machine->getTargetTriple();

    const llvm::Triple::ArchType arch = triple.getArch();

    if (triple.getEnvironment() == llvm::Triple::Android) {
        if (triple.isArch64Bit()) {
            return buf_create_from_str("/system/bin/linker64");
        } else {
            return buf_create_from_str("/system/bin/linker");
        }
    } else if (arch == llvm::Triple::x86 ||
            arch == llvm::Triple::sparc ||
            arch == llvm::Triple::sparcel)
    {
        return buf_create_from_str("/lib/ld-linux.so.2");
    } else if (arch == llvm::Triple::aarch64) {
        return buf_create_from_str("/lib/ld-linux-aarch64.so.1");
    } else if (arch == llvm::Triple::aarch64_be) {
        return buf_create_from_str("/lib/ld-linux-aarch64_be.so.1");
    } else if (arch == llvm::Triple::arm || arch == llvm::Triple::thumb) {
        if (triple.getEnvironment() == llvm::Triple::GNUEABIHF ||
            get_float_abi(triple) == FloatAbiHard)
        {
            return buf_create_from_str("/lib/ld-linux-armhf.so.3");
        } else {
            return buf_create_from_str("/lib/ld-linux.so.3");
        }
    } else if (arch == llvm::Triple::armeb || arch == llvm::Triple::thumbeb) {
        if (triple.getEnvironment() == llvm::Triple::GNUEABIHF ||
            get_float_abi(triple) == FloatAbiHard)
        {
            return buf_create_from_str("/lib/ld-linux-armhf.so.3");
        } else {
            return buf_create_from_str("/lib/ld-linux.so.3");
        }
    } else if (arch == llvm::Triple::mips || arch == llvm::Triple::mipsel ||
            arch == llvm::Triple::mips64 || arch == llvm::Triple::mips64el)
    {
        // when you want to solve this TODO, grep clang codebase for
        // getLinuxDynamicLinker
        zig_panic("TODO figure out MIPS dynamic linker name");
    } else if (arch == llvm::Triple::ppc) {
        return buf_create_from_str("/lib/ld.so.1");
    } else if (arch == llvm::Triple::ppc64) {
        return buf_create_from_str("/lib64/ld64.so.2");
    } else if (arch == llvm::Triple::ppc64le) {
        return buf_create_from_str("/lib64/ld64.so.2");
    } else if (arch == llvm::Triple::systemz) {
        return buf_create_from_str("/lib64/ld64.so.1");
    } else if (arch == llvm::Triple::sparcv9) {
        return buf_create_from_str("/lib64/ld-linux.so.2");
    } else if (arch == llvm::Triple::x86_64 &&
            triple.getEnvironment() == llvm::Triple::GNUX32)
    {
        return buf_create_from_str("/libx32/ld-linux-x32.so.2");
    } else {
        return buf_create_from_str("/lib64/ld-linux-x86-64.so.2");
    }
}

/*

# static link into libfoo.a
ar cq libfoo.a foo1.o foo2.o 

# dynamic link into libfoo.so
gcc -fPIC -g -Werror -pedantic  -shared -Wl,-soname,libsoundio.so.1 -o libsoundio.so.1.0.3 foo1.o foo2.o -ljack -lpulse -lasound -lpthread 

*/
void code_gen_link(CodeGen *g, const char *out_file) {
    if (!out_file) {
        out_file = buf_ptr(g->out_name);
    }

    Buf out_file_o = BUF_INIT;
    buf_init_from_str(&out_file_o, out_file);

    if (g->out_type != OutTypeObj) {
        buf_append_str(&out_file_o, ".o");
    }

    char *err_msg = nullptr;
    if (LLVMTargetMachineEmitToFile(g->target_machine, g->module, buf_ptr(&out_file_o),
                LLVMObjectFile, &err_msg))
    {
        zig_panic("unable to write object file: %s", err_msg);
    }

    if (g->out_type == OutTypeObj) {
        return;
    }

    if (g->out_type == OutTypeLib && g->is_static) {
        // invoke `ar`
        zig_panic("TODO invoke ar");
        return;
    }

    // invoke `ld`
    ZigList<const char *> args = {0};
    if (g->is_static) {
        args.append("-static");
    }

    char *ZIG_NATIVE_DYNAMIC_LINKER = getenv("ZIG_NATIVE_DYNAMIC_LINKER");
    if (g->is_native_target && ZIG_NATIVE_DYNAMIC_LINKER) {
        if (ZIG_NATIVE_DYNAMIC_LINKER[0] != 0) {
            args.append("-dynamic-linker");
            args.append(ZIG_NATIVE_DYNAMIC_LINKER);
        }
    } else {
        args.append("-dynamic-linker");
        args.append(buf_ptr(get_dynamic_linker(g)));
    }

    args.append("-o");
    args.append(out_file);

    args.append((const char *)buf_ptr(&out_file_o));

    auto it = g->link_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        Buf *arg = buf_sprintf("-l%s", buf_ptr(entry->key));
        args.append(buf_ptr(arg));
    }

    os_spawn_process("ld", args, false);
}


