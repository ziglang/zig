/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "semantic_info.hpp"
#include "error.hpp"
#include "zig_llvm.hpp"
#include "os.hpp"

void add_node_error(CodeGen *g, AstNode *node, Buf *msg) {
    ErrorMsg *err = allocate<ErrorMsg>(1);
    err->line_start = node->line;
    err->column_start = node->column;
    err->line_end = -1;
    err->column_end = -1;
    err->msg = msg;
    err->path = node->owner->path;
    err->source = node->owner->source_code;
    err->line_offsets = node->owner->line_offsets;

    g->errors.append(err);
}

static int parse_version_string(Buf *buf, int *major, int *minor, int *patch) {
    char *dot1 = strstr(buf_ptr(buf), ".");
    if (!dot1)
        return ErrorInvalidFormat;
    char *dot2 = strstr(dot1 + 1, ".");
    if (!dot2)
        return ErrorInvalidFormat;

    *major = (int)strtol(buf_ptr(buf), nullptr, 10);
    *minor = (int)strtol(dot1 + 1, nullptr, 10);
    *patch = (int)strtol(dot2 + 1, nullptr, 10);

    return ErrorNone;
}

static void set_root_export_version(CodeGen *g, Buf *version_buf, AstNode *node) {
    int err;
    if ((err = parse_version_string(version_buf, &g->version_major, &g->version_minor, &g->version_patch))) {
        add_node_error(g, node,
                buf_sprintf("invalid version string"));
    }
}

TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const) {
    TypeTableEntry **parent_pointer = is_const ?
        &child_type->pointer_const_parent :
        &child_type->pointer_mut_parent;
    const char *const_or_mut_str = is_const ? "const" : "mut";
    if (*parent_pointer) {
        return *parent_pointer;
    } else {
        TypeTableEntry *entry = allocate<TypeTableEntry>(1);
        entry->type_ref = LLVMPointerType(child_type->type_ref, 0);
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "*%s %s", const_or_mut_str, buf_ptr(&child_type->name));
        entry->di_type = LLVMZigCreateDebugPointerType(g->dbuilder, child_type->di_type,
                g->pointer_size_bytes * 8, g->pointer_size_bytes * 8, buf_ptr(&entry->name));
        g->type_table.put(&entry->name, entry);
        *parent_pointer = entry;
        return entry;
    }
}

static TypeTableEntry *resolve_type(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeType);
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
                    type_node->entry = g->builtin_types.entry_invalid;
                }
                return type_node->entry;
            }
        case AstNodeTypeTypePointer:
            {
                resolve_type(g, node->data.type.child_type);
                TypeTableEntry *child_type = node->data.type.child_type->codegen_node->data.type_node.entry;
                if (child_type == g->builtin_types.entry_unreachable) {
                    add_node_error(g, node,
                            buf_create_from_str("pointer to unreachable not allowed"));
                }
                type_node->entry = get_pointer_to_type(g, child_type, node->data.type.is_const);
                return type_node->entry;
            }
    }
    zig_unreachable();
}

static void resolve_function_proto(CodeGen *g, AstNode *node, FnTableEntry *fn_table_entry) {
    assert(node->type == NodeTypeFnProto);

    for (int i = 0; i < node->data.fn_proto.directives->length; i += 1) {
        AstNode *directive_node = node->data.fn_proto.directives->at(i);
        Buf *name = &directive_node->data.directive.name;
        add_node_error(g, directive_node,
                buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
    }

    for (int i = 0; i < node->data.fn_proto.params.length; i += 1) {
        AstNode *child = node->data.fn_proto.params.at(i);
        assert(child->type == NodeTypeParamDecl);
        TypeTableEntry *type_entry = resolve_type(g, child->data.param_decl.type);
        if (type_entry == g->builtin_types.entry_unreachable) {
            add_node_error(g, child->data.param_decl.type,
                buf_sprintf("parameter of type 'unreachable' not allowed"));
        } else if (type_entry == g->builtin_types.entry_void) {
            if (node->data.fn_proto.visib_mod == FnProtoVisibModExport) {
                add_node_error(g, child->data.param_decl.type,
                    buf_sprintf("parameter of type 'void' not allowed on exported functions"));
            }
        }
    }

    resolve_type(g, node->data.fn_proto.return_type);
}

static void preview_function_labels(CodeGen *g, AstNode *node, FnTableEntry *fn_table_entry) {
    assert(node->type == NodeTypeBlock);

    for (int i = 0; i < node->data.block.statements.length; i += 1) {
        AstNode *label_node = node->data.block.statements.at(i);
        if (label_node->type != NodeTypeLabel)
            continue;

        LabelTableEntry *label_entry = allocate<LabelTableEntry>(1);
        label_entry->label_node = label_node;
        Buf *name = &label_node->data.label.name;
        fn_table_entry->label_table.put(name, label_entry);

        assert(!label_node->codegen_node);
        label_node->codegen_node = allocate<CodeGenNode>(1);
        label_node->codegen_node->data.label_entry = label_entry;
    }
}

static void preview_function_declarations(CodeGen *g, ImportTableEntry *import, AstNode *node) {
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
                bool is_pub = (fn_proto->data.fn_proto.visib_mod == FnProtoVisibModPub);

                FnTableEntry *fn_table_entry = allocate<FnTableEntry>(1);
                fn_table_entry->proto_node = fn_proto;
                fn_table_entry->is_extern = true;
                fn_table_entry->calling_convention = LLVMCCallConv;
                fn_table_entry->import_entry = import;
                fn_table_entry->label_table.init(8);

                resolve_function_proto(g, fn_proto, fn_table_entry);

                Buf *name = &fn_proto->data.fn_proto.name;
                g->fn_protos.append(fn_table_entry);
                import->fn_table.put(name, fn_table_entry);
                if (is_pub) {
                    g->fn_table.put(name, fn_table_entry);
                }

                assert(!fn_proto->codegen_node);
                fn_proto->codegen_node = allocate<CodeGenNode>(1);
                fn_proto->codegen_node->data.fn_proto_node.fn_table_entry = fn_table_entry;
            }
            break;
        case NodeTypeFnDef:
            {
                AstNode *proto_node = node->data.fn_def.fn_proto;
                assert(proto_node->type == NodeTypeFnProto);
                Buf *proto_name = &proto_node->data.fn_proto.name;
                auto entry = import->fn_table.maybe_get(proto_name);
                bool skip = false;
                bool is_internal = (proto_node->data.fn_proto.visib_mod != FnProtoVisibModExport);
                bool is_pub = (proto_node->data.fn_proto.visib_mod == FnProtoVisibModPub);
                if (entry) {
                    add_node_error(g, node,
                            buf_sprintf("redefinition of '%s'", buf_ptr(proto_name)));
                    assert(!node->codegen_node);
                    node->codegen_node = allocate<CodeGenNode>(1);
                    node->codegen_node->data.fn_def_node.skip = true;
                    skip = true;
                } else if (is_pub) {
                    auto entry = g->fn_table.maybe_get(proto_name);
                    if (entry) {
                        add_node_error(g, node,
                                buf_sprintf("redefinition of '%s'", buf_ptr(proto_name)));
                        assert(!node->codegen_node);
                        node->codegen_node = allocate<CodeGenNode>(1);
                        node->codegen_node->data.fn_def_node.skip = true;
                        skip = true;
                    }
                }
                if (!skip) {
                    FnTableEntry *fn_table_entry = allocate<FnTableEntry>(1);
                    fn_table_entry->import_entry = import;
                    fn_table_entry->proto_node = proto_node;
                    fn_table_entry->fn_def_node = node;
                    fn_table_entry->internal_linkage = is_internal;
                    fn_table_entry->calling_convention = is_internal ? LLVMFastCallConv : LLVMCCallConv;
                    fn_table_entry->label_table.init(8);

                    g->fn_protos.append(fn_table_entry);
                    g->fn_defs.append(fn_table_entry);

                    import->fn_table.put(proto_name, fn_table_entry);
                    if (is_pub) {
                        g->fn_table.put(proto_name, fn_table_entry);
                    }

                    resolve_function_proto(g, proto_node, fn_table_entry);

                    assert(!proto_node->codegen_node);
                    proto_node->codegen_node = allocate<CodeGenNode>(1);
                    proto_node->codegen_node->data.fn_proto_node.fn_table_entry = fn_table_entry;

                    preview_function_labels(g, node->data.fn_def.body, fn_table_entry);
                }
            }
            break;
        case NodeTypeRootExportDecl:
            if (import == g->root_import) {
                for (int i = 0; i < node->data.root_export_decl.directives->length; i += 1) {
                    AstNode *directive_node = node->data.root_export_decl.directives->at(i);
                    Buf *name = &directive_node->data.directive.name;
                    Buf *param = &directive_node->data.directive.param;
                    if (buf_eql_str(name, "version")) {
                        set_root_export_version(g, param, directive_node);
                    } else {
                        add_node_error(g, directive_node,
                                buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
                    }
                }

                if (g->root_export_decl) {
                    add_node_error(g, node,
                            buf_sprintf("only one root export declaration allowed"));
                } else {
                    g->root_export_decl = node;

                    if (!g->root_out_name)
                        g->root_out_name = &node->data.root_export_decl.name;

                    Buf *out_type = &node->data.root_export_decl.type;
                    OutType export_out_type;
                    if (buf_eql_str(out_type, "executable")) {
                        export_out_type = OutTypeExe;
                    } else if (buf_eql_str(out_type, "library")) {
                        export_out_type = OutTypeLib;
                    } else if (buf_eql_str(out_type, "object")) {
                        export_out_type = OutTypeObj;
                    } else {
                        add_node_error(g, node,
                                buf_sprintf("invalid export type: '%s'", buf_ptr(out_type)));
                    }
                    if (g->out_type == OutTypeUnknown)
                        g->out_type = export_out_type;
                }
            } else {
                add_node_error(g, node,
                        buf_sprintf("root export declaration only valid in root source file"));
            }
            break;
        case NodeTypeUse:
            // nothing to do here
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnProto:
        case NodeTypeType:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeVariableDeclaration:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeUnreachable:
        case NodeTypeVoid:
        case NodeTypeBoolLiteral:
        case NodeTypeSymbol:
        case NodeTypeCastExpr:
        case NodeTypePrefixOpExpr:
        case NodeTypeIfExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
            zig_unreachable();
    }
}

static TypeTableEntry * get_return_type(BlockContext *context) {
    AstNode *fn_def_node = context->root->node;
    assert(fn_def_node->type == NodeTypeFnDef);
    AstNode *fn_proto_node = fn_def_node->data.fn_def.fn_proto;
    assert(fn_proto_node->type == NodeTypeFnProto);
    AstNode *return_type_node = fn_proto_node->data.fn_proto.return_type;
    assert(return_type_node->codegen_node);
    return return_type_node->codegen_node->data.type_node.entry;
}

static FnTableEntry *get_context_fn_entry(BlockContext *context) {
    AstNode *fn_def_node = context->root->node;
    assert(fn_def_node->type == NodeTypeFnDef);
    AstNode *fn_proto_node = fn_def_node->data.fn_def.fn_proto;
    assert(fn_proto_node->type == NodeTypeFnProto);
    assert(fn_proto_node->codegen_node);
    assert(fn_proto_node->codegen_node->data.fn_proto_node.fn_table_entry);
    return fn_proto_node->codegen_node->data.fn_proto_node.fn_table_entry;
}

static void check_type_compatibility(CodeGen *g, AstNode *node, TypeTableEntry *expected_type, TypeTableEntry *actual_type) {
    if (expected_type == nullptr)
        return; // anything will do
    if (expected_type == actual_type)
        return; // match
    if (expected_type == g->builtin_types.entry_invalid || actual_type == g->builtin_types.entry_invalid)
        return; // already complained
    if (actual_type == g->builtin_types.entry_unreachable)
        return; // sorry toots; gotta run. good luck with that expected type.

    add_node_error(g, node,
        buf_sprintf("type mismatch. expected %s. got %s",
            buf_ptr(&expected_type->name),
            buf_ptr(&actual_type->name)));
}

static BlockContext *new_block_context(AstNode *node, BlockContext *parent) {
    BlockContext *context = allocate<BlockContext>(1);
    context->node = node;
    context->parent = parent;
    if (parent != nullptr)
        context->root = parent->root;
    else
        context->root = context;
    context->variable_table.init(8);

    AstNode *fn_def_node = context->root->node;
    assert(fn_def_node->type == NodeTypeFnDef);
    assert(fn_def_node->codegen_node);
    FnDefNode *fn_def_info = &fn_def_node->codegen_node->data.fn_def_node;
    fn_def_info->all_block_contexts.append(context);

    return context;
}

LocalVariableTableEntry *find_local_variable(BlockContext *context, Buf *name) {
    while (true) {
        auto entry = context->variable_table.maybe_get(name);
        if (entry != nullptr)
            return entry->value;

        context = context->parent;
        if (context == nullptr)
            return nullptr;
    }
}

static TypeTableEntry * analyze_expression(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    TypeTableEntry *return_type = nullptr;
    switch (node->type) {
        case NodeTypeBlock:
            {
                BlockContext *child_context = new_block_context(node, context);
                return_type = g->builtin_types.entry_void;
                for (int i = 0; i < node->data.block.statements.length; i += 1) {
                    AstNode *child = node->data.block.statements.at(i);
                    if (child->type == NodeTypeLabel) {
                        LabelTableEntry *label_entry = child->codegen_node->data.label_entry;
                        assert(label_entry);
                        label_entry->entered_from_fallthrough = (return_type != g->builtin_types.entry_unreachable);
                        return_type = g->builtin_types.entry_void;
                        continue;
                    }
                    if (return_type == g->builtin_types.entry_unreachable) {
                        if (child->type == NodeTypeVoid) {
                            // {unreachable;void;void} is allowed.
                            // ignore void statements once we enter unreachable land.
                            continue;
                        }
                        add_node_error(g, child, buf_sprintf("unreachable code"));
                        break;
                    }
                    return_type = analyze_expression(g, import, child_context, nullptr, child);
                }
                break;
            }

        case NodeTypeReturnExpr:
            {
                TypeTableEntry *expected_return_type = get_return_type(context);
                TypeTableEntry *actual_return_type;
                if (node->data.return_expr.expr) {
                    actual_return_type = analyze_expression(g, import, context, expected_return_type, node->data.return_expr.expr);
                } else {
                    actual_return_type = g->builtin_types.entry_void;
                }

                if (actual_return_type == g->builtin_types.entry_unreachable) {
                    // "return exit(0)" should just be "exit(0)".
                    add_node_error(g, node, buf_sprintf("returning is unreachable"));
                    actual_return_type = g->builtin_types.entry_invalid;
                }

                check_type_compatibility(g, node, expected_return_type, actual_return_type);
                return_type = g->builtin_types.entry_unreachable;
                break;
            }
        case NodeTypeVariableDeclaration:
            {
                AstNodeVariableDeclaration *variable_declaration = &node->data.variable_declaration;;

                TypeTableEntry *explicit_type = variable_declaration->type != nullptr ?
                    resolve_type(g, variable_declaration->type) : nullptr;
                if (explicit_type == g->builtin_types.entry_unreachable) {
                    add_node_error(g, variable_declaration->type,
                        buf_sprintf("variable of type 'unreachable' not allowed"));
                }

                TypeTableEntry *implicit_type = variable_declaration->expr != nullptr ?
                    analyze_expression(g, import, context, explicit_type, variable_declaration->expr) : nullptr;
                if (implicit_type == g->builtin_types.entry_unreachable) {
                    add_node_error(g, node,
                        buf_sprintf("variable initialization is unreachable"));
                }

                if (implicit_type == nullptr) {
                    add_node_error(g, node, buf_sprintf("initial values are required for variable declaration"));
                }

                TypeTableEntry *type = explicit_type != nullptr ? explicit_type : implicit_type;
                assert(type != nullptr); // should have been caught by the parser

                LocalVariableTableEntry *existing_variable = find_local_variable(context, &variable_declaration->symbol);
                if (existing_variable) {
                    add_node_error(g, node,
                        buf_sprintf("redeclaration of variable '%s'", buf_ptr(&variable_declaration->symbol)));
                } else {
                    LocalVariableTableEntry *variable_entry = allocate<LocalVariableTableEntry>(1);
                    buf_init_from_buf(&variable_entry->name, &variable_declaration->symbol);
                    variable_entry->type = type;
                    variable_entry->is_const = variable_declaration->is_const;
                    variable_entry->decl_node = node;
                    context->variable_table.put(&variable_entry->name, variable_entry);
                }
                return_type = g->builtin_types.entry_void;
                break;
            }

        case NodeTypeGoto:
            {
                FnTableEntry *fn_table_entry = get_context_fn_entry(context);
                auto table_entry = fn_table_entry->label_table.maybe_get(&node->data.go_to.name);
                if (table_entry) {
                    assert(!node->codegen_node);
                    node->codegen_node = allocate<CodeGenNode>(1);
                    node->codegen_node->data.label_entry = table_entry->value;
                    table_entry->value->used = true;
                } else {
                    add_node_error(g, node,
                            buf_sprintf("use of undeclared label '%s'", buf_ptr(&node->data.go_to.name)));
                }
                return_type = g->builtin_types.entry_unreachable;
                break;
            }
        case NodeTypeBinOpExpr:
            {
                switch (node->data.bin_op_expr.bin_op) {
                    case BinOpTypeAssign:
                        {
                            AstNode *lhs_node = node->data.bin_op_expr.op1;
                            if (lhs_node->type == NodeTypeSymbol) {
                                Buf *name = &lhs_node->data.symbol;
                                LocalVariableTableEntry *var = find_local_variable(context, name);
                                if (var) {
                                    if (var->is_const) {
                                        add_node_error(g, lhs_node,
                                            buf_sprintf("cannot assign to constant variable"));
                                    } else {
                                        analyze_expression(g, import, context, var->type,
                                                node->data.bin_op_expr.op2);
                                    }
                                } else {
                                    add_node_error(g, lhs_node,
                                            buf_sprintf("use of undeclared identifier '%s'", buf_ptr(name)));
                                }

                            } else {
                                add_node_error(g, lhs_node,
                                        buf_sprintf("expected a bare identifier"));
                            }
                            return_type = g->builtin_types.entry_void;
                            break;
                        }
                    case BinOpTypeBoolOr:
                    case BinOpTypeBoolAnd:
                        analyze_expression(g, import, context, g->builtin_types.entry_bool,
                                node->data.bin_op_expr.op1);
                        analyze_expression(g, import, context, g->builtin_types.entry_bool,
                                node->data.bin_op_expr.op2);
                        return_type = g->builtin_types.entry_bool;
                        break;
                    case BinOpTypeCmpEq:
                    case BinOpTypeCmpNotEq:
                    case BinOpTypeCmpLessThan:
                    case BinOpTypeCmpGreaterThan:
                    case BinOpTypeCmpLessOrEq:
                    case BinOpTypeCmpGreaterOrEq:
                        // TODO think how should type checking for these work?
                        analyze_expression(g, import, context, g->builtin_types.entry_i32,
                                node->data.bin_op_expr.op1);
                        analyze_expression(g, import, context, g->builtin_types.entry_i32,
                                node->data.bin_op_expr.op2);
                        return_type = g->builtin_types.entry_bool;
                        break;
                    case BinOpTypeBinOr:
                        zig_panic("TODO bin or type");
                        break;
                    case BinOpTypeBinXor:
                        zig_panic("TODO bin xor type");
                        break;
                    case BinOpTypeBinAnd:
                        zig_panic("TODO bin and type");
                        break;
                    case BinOpTypeBitShiftLeft:
                        zig_panic("TODO bit shift left type");
                        break;
                    case BinOpTypeBitShiftRight:
                        zig_panic("TODO bit shift right type");
                        break;
                    case BinOpTypeAdd:
                    case BinOpTypeSub:
                        // TODO think how should type checking for these work?
                        analyze_expression(g, import, context, g->builtin_types.entry_i32,
                                node->data.bin_op_expr.op1);
                        analyze_expression(g, import, context, g->builtin_types.entry_i32,
                                node->data.bin_op_expr.op2);
                        return_type = g->builtin_types.entry_i32;
                        break;
                    case BinOpTypeMult:
                        zig_panic("TODO mult type");
                        break;
                    case BinOpTypeDiv:
                        zig_panic("TODO div type");
                        break;
                    case BinOpTypeMod:
                        zig_panic("TODO modulus type");
                        break;
                    case BinOpTypeInvalid:
                        zig_unreachable();
                }
                break;
            }

        case NodeTypeFnCallExpr:
            {
                Buf *name = hack_get_fn_call_name(g, node->data.fn_call_expr.fn_ref_expr);

                auto entry = import->fn_table.maybe_get(name);
                if (!entry)
                    entry = g->fn_table.maybe_get(name);

                if (!entry) {
                    add_node_error(g, node,
                            buf_sprintf("undefined function: '%s'", buf_ptr(name)));
                    // still analyze the parameters, even though we don't know what to expect
                    for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                        AstNode *child = node->data.fn_call_expr.params.at(i);
                        analyze_expression(g, import, context, nullptr, child);
                    }

                    return_type = g->builtin_types.entry_invalid;
                } else {
                    FnTableEntry *fn_table_entry = entry->value;
                    assert(fn_table_entry->proto_node->type == NodeTypeFnProto);
                    AstNodeFnProto *fn_proto = &fn_table_entry->proto_node->data.fn_proto;

                    // count parameters
                    int expected_param_count = fn_proto->params.length;
                    int actual_param_count = node->data.fn_call_expr.params.length;
                    if (expected_param_count != actual_param_count) {
                        add_node_error(g, node,
                                buf_sprintf("wrong number of arguments. Expected %d, got %d.",
                                    expected_param_count, actual_param_count));
                    }

                    // analyze each parameter
                    for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                        AstNode *child = node->data.fn_call_expr.params.at(i);
                        // determine the expected type for each parameter
                        TypeTableEntry *expected_param_type = nullptr;
                        if (i < fn_proto->params.length) {
                            AstNode *param_decl_node = fn_proto->params.at(i);
                            assert(param_decl_node->type == NodeTypeParamDecl);
                            AstNode *param_type_node = param_decl_node->data.param_decl.type;
                            if (param_type_node->codegen_node)
                                expected_param_type = param_type_node->codegen_node->data.type_node.entry;
                        }
                        analyze_expression(g, import, context, expected_param_type, child);
                    }

                    return_type = fn_proto->return_type->codegen_node->data.type_node.entry;
                }
                break;
            }

        case NodeTypeNumberLiteral:
            // TODO: generic literal int type
            return_type = g->builtin_types.entry_i32;
            break;

        case NodeTypeStringLiteral:
            return_type = g->builtin_types.entry_string_literal;
            break;

        case NodeTypeUnreachable:
            return_type = g->builtin_types.entry_unreachable;
            break;

        case NodeTypeVoid:
            return_type = g->builtin_types.entry_void;
            break;

        case NodeTypeBoolLiteral:
            return_type = g->builtin_types.entry_bool;
            break;

        case NodeTypeSymbol:
            {
                Buf *symbol_name = &node->data.symbol;
                LocalVariableTableEntry *local_variable = find_local_variable(context, symbol_name);
                if (local_variable) {
                    return_type = local_variable->type;
                } else {
                    // TODO: check global variables also
                    add_node_error(g, node,
                            buf_sprintf("use of undeclared identifier '%s'", buf_ptr(symbol_name)));
                    return_type = g->builtin_types.entry_invalid;
                }
                break;
            }
        case NodeTypeCastExpr:
            zig_panic("TODO analyze_expression cast expr");
            break;

        case NodeTypePrefixOpExpr:
            switch (node->data.prefix_op_expr.prefix_op) {
                case PrefixOpBoolNot:
                    analyze_expression(g, import, context, g->builtin_types.entry_bool,
                            node->data.prefix_op_expr.primary_expr);
                    return_type = g->builtin_types.entry_bool;
                    break;
                case PrefixOpBinNot:
                    zig_panic("TODO type check bin not");
                    break;
                case PrefixOpNegation:
                    zig_panic("TODO type check negation");
                    break;
                case PrefixOpInvalid:
                    zig_unreachable();
            }
            break;
        case NodeTypeIfExpr:
            {
                analyze_expression(g, import, context, g->builtin_types.entry_bool, node->data.if_expr.condition);

                TypeTableEntry *then_type = analyze_expression(g, import, context, expected_type,
                        node->data.if_expr.then_block);

                TypeTableEntry *else_type;
                if (node->data.if_expr.else_node) {
                    else_type = analyze_expression(g, import, context, expected_type, node->data.if_expr.else_node);
                } else {
                    else_type = g->builtin_types.entry_void;
                }


                TypeTableEntry *primary_type;
                TypeTableEntry *other_type;
                if (then_type == g->builtin_types.entry_unreachable) {
                    primary_type = else_type;
                    other_type = then_type;
                } else {
                    primary_type = then_type;
                    other_type = else_type;
                }

                check_type_compatibility(g, node, primary_type, other_type);
                check_type_compatibility(g, node, expected_type, other_type);
                return_type = primary_type;
                break;
            }
        case NodeTypeDirective:
        case NodeTypeFnDecl:
        case NodeTypeFnProto:
        case NodeTypeParamDecl:
        case NodeTypeType:
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeExternBlock:
        case NodeTypeFnDef:
        case NodeTypeUse:
        case NodeTypeLabel:
            zig_unreachable();
    }
    assert(return_type);
    check_type_compatibility(g, node, expected_type, return_type);

    if (node->codegen_node) {
        assert(node->type == NodeTypeGoto);
    } else {
        assert(node->type != NodeTypeGoto);
        node->codegen_node = allocate<CodeGenNode>(1);
    }
    node->codegen_node->expr_node.type_entry = return_type;
    node->codegen_node->expr_node.block_context = context;

    return return_type;
}

static void analyze_top_level_declaration(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    switch (node->type) {
        case NodeTypeFnDef:
            {
                if (node->codegen_node && node->codegen_node->data.fn_def_node.skip) {
                    // we detected an error with this function definition which prevents us
                    // from further analyzing it.
                    break;
                }

                AstNode *fn_proto_node = node->data.fn_def.fn_proto;
                assert(fn_proto_node->type == NodeTypeFnProto);

                assert(!node->codegen_node);
                node->codegen_node = allocate<CodeGenNode>(1);
                BlockContext *context = new_block_context(node, nullptr);
                node->codegen_node->data.fn_def_node.block_context = context;

                AstNodeFnProto *fn_proto = &fn_proto_node->data.fn_proto;
                for (int i = 0; i < fn_proto->params.length; i += 1) {
                    AstNode *param_decl_node = fn_proto->params.at(i);
                    assert(param_decl_node->type == NodeTypeParamDecl);

                    // define local variables for parameters
                    AstNodeParamDecl *param_decl = &param_decl_node->data.param_decl;
                    assert(param_decl->type->type == NodeTypeType);
                    TypeTableEntry *type = param_decl->type->codegen_node->data.type_node.entry;

                    LocalVariableTableEntry *variable_entry = allocate<LocalVariableTableEntry>(1);
                    buf_init_from_buf(&variable_entry->name, &param_decl->name);
                    variable_entry->type = type;
                    variable_entry->is_const = true;
                    variable_entry->decl_node = param_decl_node;

                    LocalVariableTableEntry *existing_entry = find_local_variable(context, &variable_entry->name);
                    if (!existing_entry) {
                        // unique definition
                        context->variable_table.put(&variable_entry->name, variable_entry);
                    } else {
                        add_node_error(g, node,
                            buf_sprintf("redeclaration of parameter '%s'.", buf_ptr(&existing_entry->name)));
                        if (existing_entry->type == variable_entry->type) {
                            // types agree, so the type is probably good enough for the rest of analysis
                        } else {
                            // types disagree. don't trust either one of them.
                            existing_entry->type = g->builtin_types.entry_invalid;;
                        }
                    }
                }

                TypeTableEntry *expected_type = fn_proto->return_type->codegen_node->data.type_node.entry;
                TypeTableEntry *block_return_type = analyze_expression(g, import, context, expected_type, node->data.fn_def.body);

                node->codegen_node->data.fn_def_node.implicit_return_type = block_return_type;

                {
                    FnTableEntry *fn_table_entry = fn_proto_node->codegen_node->data.fn_proto_node.fn_table_entry;
                    auto it = fn_table_entry->label_table.entry_iterator();
                    for (;;) {
                        auto *entry = it.next();
                        if (!entry)
                            break;

                        LabelTableEntry *label_entry = entry->value;
                        if (!label_entry->used) {
                            add_node_error(g, label_entry->label_node,
                                buf_sprintf("label '%s' defined but not used",
                                    buf_ptr(&label_entry->label_node->data.label.name)));
                        }
                    }
                }
            }
            break;

        case NodeTypeRootExportDecl:
        case NodeTypeExternBlock:
            // already looked at these in the preview pass
            break;
        case NodeTypeUse:
            for (int i = 0; i < node->data.use.directives->length; i += 1) {
                AstNode *directive_node = node->data.use.directives->at(i);
                Buf *name = &directive_node->data.directive.name;
                add_node_error(g, directive_node,
                        buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
            }
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnProto:
        case NodeTypeType:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeVariableDeclaration:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeUnreachable:
        case NodeTypeVoid:
        case NodeTypeBoolLiteral:
        case NodeTypeSymbol:
        case NodeTypeCastExpr:
        case NodeTypePrefixOpExpr:
        case NodeTypeIfExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
            zig_unreachable();
    }
}

static void find_function_declarations_root(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeRoot);

    for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
        AstNode *child = node->data.root.top_level_decls.at(i);
        preview_function_declarations(g, import, child);
    }

}

static void analyze_top_level_decls_root(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeRoot);

    for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
        AstNode *child = node->data.root.top_level_decls.at(i);
        analyze_top_level_declaration(g, import, child);
    }
}

void semantic_analyze(CodeGen *g) {
    {
        auto it = g->import_table.entry_iterator();
        for (;;) {
            auto *entry = it.next();
            if (!entry)
                break;

            ImportTableEntry *import = entry->value;
            find_function_declarations_root(g, import, import->root);
        }
    }
    {
        auto it = g->import_table.entry_iterator();
        for (;;) {
            auto *entry = it.next();
            if (!entry)
                break;

            ImportTableEntry *import = entry->value;
            analyze_top_level_decls_root(g, import, import->root);
        }
    }


    if (!g->root_out_name) {
        add_node_error(g, g->root_import->root,
                buf_sprintf("missing export declaration and output name not provided"));
    } else if (g->out_type == OutTypeUnknown) {
        add_node_error(g, g->root_import->root,
                buf_sprintf("missing export declaration and export type not provided"));
    }
}
