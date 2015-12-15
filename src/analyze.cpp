/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "error.hpp"
#include "zig_llvm.hpp"
#include "os.hpp"

static TypeTableEntry * analyze_expression(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node);

static void alloc_codegen_node(AstNode *node) {
    assert(!node->codegen_node);
    node->codegen_node = allocate<CodeGenNode>(1);
}

static AstNode *first_executing_node(AstNode *node) {
    switch (node->type) {
        case NodeTypeFnCallExpr:
            return first_executing_node(node->data.fn_call_expr.fn_ref_expr);
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeType:
        case NodeTypeBlock:
        case NodeTypeExternBlock:
        case NodeTypeDirective:
        case NodeTypeReturnExpr:
        case NodeTypeVariableDeclaration:
        case NodeTypeBinOpExpr:
        case NodeTypeCastExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeUnreachable:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeUse:
        case NodeTypeVoid:
        case NodeTypeBoolLiteral:
        case NodeTypeIfExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeStructDecl:
        case NodeTypeStructField:
            return node;
    }
    zig_panic("unreachable");
}

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

TypeTableEntry *new_type_table_entry(TypeTableEntryId id) {
    TypeTableEntry *entry = allocate<TypeTableEntry>(1);
    entry->arrays_by_size.init(2);
    entry->id = id;
    return entry;
}

TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const) {
    TypeTableEntry **parent_pointer = is_const ?
        &child_type->pointer_const_parent :
        &child_type->pointer_mut_parent;
    if (*parent_pointer) {
        return *parent_pointer;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdPointer);
        entry->type_ref = LLVMPointerType(child_type->type_ref, 0);
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "&%s%s", is_const ? "const " : "", buf_ptr(&child_type->name));
        entry->size_in_bits = g->pointer_size_bytes * 8;
        entry->align_in_bits = g->pointer_size_bytes * 8;
        entry->di_type = LLVMZigCreateDebugPointerType(g->dbuilder, child_type->di_type,
                entry->size_in_bits, entry->align_in_bits, buf_ptr(&entry->name));
        g->type_table.put(&entry->name, entry);
        *parent_pointer = entry;
        return entry;
    }
}

static TypeTableEntry *get_array_type(CodeGen *g, TypeTableEntry *child_type, uint64_t array_size) {
    auto existing_entry = child_type->arrays_by_size.maybe_get(array_size);
    if (existing_entry) {
        return existing_entry->value;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdArray);
        entry->type_ref = LLVMArrayType(child_type->type_ref, array_size);
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[%s; %" PRIu64 "]", buf_ptr(&child_type->name), array_size);

        entry->size_in_bits = child_type->size_in_bits * array_size;
        entry->align_in_bits = child_type->align_in_bits;
        entry->di_type = LLVMZigCreateDebugArrayType(g->dbuilder, entry->size_in_bits,
                entry->align_in_bits, child_type->di_type, array_size);
        entry->data.array.child_type = child_type;
        entry->data.array.len = array_size;

        g->type_table.put(&entry->name, entry);
        child_type->arrays_by_size.put(array_size, entry);
        return entry;
    }
}

static TypeTableEntry *resolve_type(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeType);
    alloc_codegen_node(node);
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
                assert(child_type);
                if (child_type->id == TypeTableEntryIdUnreachable) {
                    add_node_error(g, node,
                            buf_create_from_str("pointer to unreachable not allowed"));
                } else if (child_type->id == TypeTableEntryIdInvalid) {
                    return child_type;
                }
                type_node->entry = get_pointer_to_type(g, child_type, node->data.type.is_const);
                return type_node->entry;
            }
        case AstNodeTypeTypeArray:
            {
                resolve_type(g, node->data.type.child_type);
                TypeTableEntry *child_type = node->data.type.child_type->codegen_node->data.type_node.entry;
                if (child_type->id == TypeTableEntryIdUnreachable) {
                    add_node_error(g, node,
                            buf_create_from_str("array of unreachable not allowed"));
                }

                AstNode *size_node = node->data.type.array_size;
                if (size_node->type == NodeTypeNumberLiteral &&
                    is_num_lit_unsigned(size_node->data.number_literal.kind))
                {
                    type_node->entry = get_array_type(g, child_type, size_node->data.number_literal.data.x_uint);
                } else {
                    add_node_error(g, size_node,
                        buf_create_from_str("array size must be literal unsigned integer"));
                    type_node->entry = g->builtin_types.entry_invalid;
                }
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

        if (buf_eql_str(name, "attribute")) {
            Buf *attr_name = &directive_node->data.directive.param;
            if (fn_table_entry->fn_def_node) {
                if (buf_eql_str(attr_name, "naked")) {
                    fn_table_entry->fn_attr_list.append(FnAttrIdNaked);
                } else if (buf_eql_str(attr_name, "alwaysinline")) {
                    fn_table_entry->fn_attr_list.append(FnAttrIdAlwaysInline);
                } else {
                    add_node_error(g, directive_node,
                            buf_sprintf("invalid function attribute: '%s'", buf_ptr(name)));
                }
            } else {
                add_node_error(g, directive_node,
                        buf_sprintf("invalid function attribute: '%s'", buf_ptr(name)));
            }
        } else {
            add_node_error(g, directive_node,
                    buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
        }
    }

    for (int i = 0; i < node->data.fn_proto.params.length; i += 1) {
        AstNode *child = node->data.fn_proto.params.at(i);
        assert(child->type == NodeTypeParamDecl);
        TypeTableEntry *type_entry = resolve_type(g, child->data.param_decl.type);
        if (type_entry->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, child->data.param_decl.type,
                buf_sprintf("parameter of type 'unreachable' not allowed"));
        } else if (type_entry->id == TypeTableEntryIdVoid) {
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

        alloc_codegen_node(label_node);
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

                alloc_codegen_node(fn_proto);
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
                    alloc_codegen_node(node);
                    node->codegen_node->data.fn_def_node.skip = true;
                    skip = true;
                } else if (is_pub) {
                    auto entry = g->fn_table.maybe_get(proto_name);
                    if (entry) {
                        add_node_error(g, node,
                                buf_sprintf("redefinition of '%s'", buf_ptr(proto_name)));
                        alloc_codegen_node(node);
                        node->codegen_node->data.fn_def_node.skip = true;
                        skip = true;
                    }
                }
                if (proto_node->data.fn_proto.is_var_args) {
                    add_node_error(g, node,
                            buf_sprintf("variadic arguments only allowed in extern functions"));
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


                    alloc_codegen_node(proto_node);
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
        case NodeTypeStructDecl:
            {
                StructDeclNode *struct_codegen = &node->codegen_node->data.struct_decl_node;
                TypeTableEntry *type_entry = struct_codegen->type_entry;

                int field_count = node->data.struct_decl.fields.length;;
                type_entry->data.structure.field_count = field_count;
                type_entry->data.structure.fields = allocate<TypeStructField>(field_count);

                LLVMTypeRef *element_types = allocate<LLVMTypeRef>(field_count);
                LLVMZigDIType **di_element_types = allocate<LLVMZigDIType*>(field_count);

                uint64_t total_size_in_bits = 0;

                for (int i = 0; i < field_count; i += 1) {
                    AstNode *field_node = node->data.struct_decl.fields.at(i);
                    TypeStructField *type_struct_field = &type_entry->data.structure.fields[i];
                    type_struct_field->name = &field_node->data.struct_field.name;
                    type_struct_field->type_entry = resolve_type(g, field_node->data.struct_field.type);

                    total_size_in_bits = type_struct_field->type_entry->size_in_bits;
                    di_element_types[i] = type_struct_field->type_entry->di_type;

                    element_types[i] = type_struct_field->type_entry->type_ref;
                }
                LLVMStructSetBody(type_entry->type_ref, element_types, field_count, false);

                // TODO re-evaluate this align in bits and size in bits
                type_entry->align_in_bits = 0;
                type_entry->size_in_bits = total_size_in_bits;
                type_entry->di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                        LLVMZigFileToScope(import->di_file),
                        buf_ptr(&node->data.struct_decl.name),
                        import->di_file, node->line + 1, type_entry->size_in_bits, type_entry->align_in_bits, 0,
                        nullptr, di_element_types, field_count, 0, nullptr, "");

                break;
            }
        case NodeTypeUse:
        case NodeTypeVariableDeclaration:
            // nothing to do here
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnProto:
        case NodeTypeType:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
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
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeStructField:
            zig_unreachable();
    }
}

static void preview_types(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    switch (node->type) {
        case NodeTypeStructDecl:
            {
                alloc_codegen_node(node);
                StructDeclNode *struct_codegen = &node->codegen_node->data.struct_decl_node;

                Buf *name = &node->data.struct_decl.name;
                auto table_entry = g->type_table.maybe_get(name);
                if (table_entry) {
                    struct_codegen->type_entry = table_entry->value;
                    add_node_error(g, node,
                            buf_sprintf("redefinition of '%s'", buf_ptr(name)));
                } else {
                    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdStruct);
                    entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), buf_ptr(name));
                    buf_init_from_buf(&entry->name, name);
                    // put off adding the debug type until we do the full struct body
                    // this type is incomplete until we do another pass
                    g->type_table.put(&entry->name, entry);
                    struct_codegen->type_entry = entry;
                }
                break;
            }
        case NodeTypeExternBlock:
        case NodeTypeFnDef:
        case NodeTypeRootExportDecl:
        case NodeTypeUse:
        case NodeTypeVariableDeclaration:
            // nothing to do
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnProto:
        case NodeTypeType:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
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
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeStructField:
            zig_unreachable();
    }
}

static FnTableEntry *get_context_fn_entry(BlockContext *context) {
    assert(context->fn_entry);
    return context->fn_entry;
}

static TypeTableEntry *get_return_type(BlockContext *context) {
    FnTableEntry *fn_entry = get_context_fn_entry(context);
    AstNode *fn_proto_node = fn_entry->proto_node;
    assert(fn_proto_node->type == NodeTypeFnProto);
    AstNode *return_type_node = fn_proto_node->data.fn_proto.return_type;
    assert(return_type_node->codegen_node);
    return return_type_node->codegen_node->data.type_node.entry;
}

static void check_type_compatibility(CodeGen *g, AstNode *node,
        TypeTableEntry *expected_type, TypeTableEntry *actual_type)
{
    if (expected_type == nullptr)
        return; // anything will do
    if (expected_type == actual_type)
        return; // match
    if (expected_type->id == TypeTableEntryIdInvalid || actual_type->id == TypeTableEntryIdInvalid)
        return; // already complained
    if (actual_type->id == TypeTableEntryIdUnreachable)
        return; // sorry toots; gotta run. good luck with that expected type.

    add_node_error(g, node,
        buf_sprintf("expected type '%s', got '%s'",
            buf_ptr(&expected_type->name),
            buf_ptr(&actual_type->name)));
}

BlockContext *new_block_context(AstNode *node, BlockContext *parent) {
    BlockContext *context = allocate<BlockContext>(1);
    context->node = node;
    context->parent = parent;
    context->variable_table.init(8);

    if (parent) {
        context->fn_entry = parent->fn_entry;
    } else if (node && node->type == NodeTypeFnDef) {
        AstNode *fn_proto_node = node->data.fn_def.fn_proto;
        context->fn_entry = fn_proto_node->codegen_node->data.fn_proto_node.fn_table_entry;
    }

    if (context->fn_entry) {
        context->fn_entry->all_block_contexts.append(context);
    }

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

static void get_struct_field(TypeTableEntry *struct_type, Buf *name, TypeStructField **out_tsf, int *out_i) {
    for (int i = 0; i < struct_type->data.structure.field_count; i += 1) {
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        if (buf_eql_buf(type_struct_field->name, name)) {
            *out_tsf = type_struct_field;
            *out_i = i;
            return;
        }
    }
    *out_tsf = nullptr;
    *out_i = -1;
}

static bool num_lit_fits_in_other_type(CodeGen *g, TypeTableEntry *literal_type, TypeTableEntry *other_type) {
    NumLit num_lit = literal_type->data.num_lit.kind;
    uint64_t lit_size_in_bits = num_lit_bit_count(num_lit);

    switch (other_type->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdNumberLiteral:
            zig_unreachable();
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
            return false;
        case TypeTableEntryIdInt:
            if (is_num_lit_signed(num_lit)) {
                if (!other_type->data.integral.is_signed) {
                    return false;
                }

                return lit_size_in_bits <= other_type->size_in_bits;
            } else if (is_num_lit_unsigned(num_lit)) {

                return lit_size_in_bits <= other_type->size_in_bits;
            } else {
                return false;
            }
        case TypeTableEntryIdFloat:
            if (is_num_lit_float(num_lit)) {
                return lit_size_in_bits <= other_type->size_in_bits;
            } else {
                return false;
            }
    }
    zig_unreachable();
}


static TypeTableEntry *analyze_field_access_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    TypeTableEntry *struct_type = analyze_expression(g, import, context, nullptr,
            node->data.field_access_expr.struct_expr);

    TypeTableEntry *return_type;

    if (struct_type->id == TypeTableEntryIdStruct) {
        assert(node->codegen_node);
        FieldAccessNode *codegen_field_access = &node->codegen_node->data.field_access_node;
        assert(codegen_field_access);

        Buf *field_name = &node->data.field_access_expr.field_name;

        get_struct_field(struct_type, field_name,
                &codegen_field_access->type_struct_field,
                &codegen_field_access->field_index);
        if (codegen_field_access->type_struct_field) {
            return_type = codegen_field_access->type_struct_field->type_entry;
        } else {
            add_node_error(g, node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name), buf_ptr(&struct_type->name)));
            return_type = g->builtin_types.entry_invalid;
        }
    } else if (struct_type->id == TypeTableEntryIdArray) {
        Buf *name = &node->data.field_access_expr.field_name;
        if (buf_eql_str(name, "len")) {
            return_type = g->builtin_types.entry_usize;
        } else {
            add_node_error(g, node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(name),
                    buf_ptr(&struct_type->name)));
            return_type = g->builtin_types.entry_invalid;
        }
    } else {
        if (struct_type->id != TypeTableEntryIdInvalid) {
            add_node_error(g, node,
                buf_sprintf("type '%s' does not support field access", buf_ptr(&struct_type->name)));
        }
        return_type = g->builtin_types.entry_invalid;
    }

    return return_type;
}

static TypeTableEntry *analyze_array_access_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    TypeTableEntry *array_type = analyze_expression(g, import, context, nullptr,
            node->data.array_access_expr.array_ref_expr);

    TypeTableEntry *return_type;

    if (array_type->id == TypeTableEntryIdArray) {
        return_type = array_type->data.array.child_type;
    } else {
        if (array_type->id != TypeTableEntryIdInvalid) {
            add_node_error(g, node, buf_sprintf("array access of non-array"));
        }
        return_type = g->builtin_types.entry_invalid;
    }

    TypeTableEntry *subscript_type = analyze_expression(g, import, context, nullptr,
            node->data.array_access_expr.subscript);
    if (subscript_type->id != TypeTableEntryIdInt &&
        subscript_type->id != TypeTableEntryIdInvalid)
    {
        add_node_error(g, node,
            buf_sprintf("array subscripts must be integers"));
    }

    return return_type;
}

static TypeTableEntry *analyze_variable_name(CodeGen *g, BlockContext *context,
        AstNode *node, Buf *variable_name)
{
    LocalVariableTableEntry *local_variable = find_local_variable(context, variable_name);
    if (local_variable) {
        return local_variable->type;
    } else {
        // TODO: check global variables also
        add_node_error(g, node,
                buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
        return g->builtin_types.entry_invalid;
    }
}

static bool is_op_allowed(TypeTableEntry *type, BinOpType op) {
    switch (op) {
        case BinOpTypeAssign:
            return true;
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignMinus:
            return type->id == TypeTableEntryIdInt || type->id == TypeTableEntryIdFloat;
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftRight:
        case BinOpTypeAssignBitAnd:
        case BinOpTypeAssignBitXor:
        case BinOpTypeAssignBitOr:
            return type->id == TypeTableEntryIdInt;
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            return type->id == TypeTableEntryIdBool;

        case BinOpTypeInvalid:
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
        case BinOpTypeBinOr:
        case BinOpTypeBinXor:
        case BinOpTypeBinAnd:
        case BinOpTypeBitShiftLeft:
        case BinOpTypeBitShiftRight:
        case BinOpTypeAdd:
        case BinOpTypeSub:
        case BinOpTypeMult:
        case BinOpTypeDiv:
        case BinOpTypeMod:
            zig_unreachable();
    }
    zig_unreachable();
}

static TypeTableEntry *analyze_cast_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    TypeTableEntry *wanted_type = resolve_type(g, node->data.cast_expr.type);
    TypeTableEntry *actual_type = analyze_expression(g, import, context, nullptr, node->data.cast_expr.expr);

    if (wanted_type->id == TypeTableEntryIdInvalid ||
        actual_type->id == TypeTableEntryIdInvalid)
    {
        return g->builtin_types.entry_invalid;
    }

    CastNode *cast_node = &node->codegen_node->data.cast_node;

    // special casing this for now, TODO think about casting and do a general solution
    if (wanted_type == g->builtin_types.entry_isize &&
        actual_type->id == TypeTableEntryIdPointer)
    {
        cast_node->op = CastOpPtrToInt;
        return wanted_type;
    } else if (wanted_type->id == TypeTableEntryIdInt &&
                actual_type->id == TypeTableEntryIdInt)
    {
        cast_node->op = CastOpIntWidenOrShorten;
        return wanted_type;
    } else if (wanted_type == g->builtin_types.entry_string &&
                actual_type->id == TypeTableEntryIdArray &&
                actual_type->data.array.child_type == g->builtin_types.entry_u8)
    {
        cast_node->op = CastOpArrayToString;
        context->cast_expr_alloca_list.append(node);
        return wanted_type;
    } else if (actual_type->id == TypeTableEntryIdNumberLiteral &&
               num_lit_fits_in_other_type(g, actual_type, wanted_type))
    {
        AstNode *literal_node = node->data.cast_expr.expr;
        assert(literal_node->codegen_node);
        NumberLiteralNode *codegen_num_lit = &literal_node->codegen_node->data.num_lit_node;
        assert(!codegen_num_lit->resolved_type);
        codegen_num_lit->resolved_type = wanted_type;
        cast_node->op = CastOpNothing;
        return wanted_type;
    } else {
        add_node_error(g, node,
            buf_sprintf("invalid cast from type '%s' to '%s'",
                buf_ptr(&actual_type->name),
                buf_ptr(&wanted_type->name)));
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry * resolve_rhs_number_literal(CodeGen *g, AstNode *non_literal_node,
        TypeTableEntry *non_literal_type, AstNode *literal_node, TypeTableEntry *literal_type)
{
    assert(literal_node->codegen_node);
    NumberLiteralNode *codegen_num_lit = &literal_node->codegen_node->data.num_lit_node;

    if (num_lit_fits_in_other_type(g, literal_type, non_literal_type)) {
        assert(!codegen_num_lit->resolved_type);
        codegen_num_lit->resolved_type = non_literal_type;
        return non_literal_type;
    } else {
        return nullptr;
    }
}

static TypeTableEntry * resolve_number_literals(CodeGen *g, AstNode *node1, AstNode *node2) {
    TypeTableEntry *type1 = node1->codegen_node->expr_node.type_entry;
    TypeTableEntry *type2 = node2->codegen_node->expr_node.type_entry;

    if (type1->id == TypeTableEntryIdNumberLiteral &&
        type2->id == TypeTableEntryIdNumberLiteral)
    {
        assert(node1->codegen_node);
        assert(node2->codegen_node);

        NumberLiteralNode *codegen_num_lit_1 = &node1->codegen_node->data.num_lit_node;
        NumberLiteralNode *codegen_num_lit_2 = &node2->codegen_node->data.num_lit_node;

        assert(!codegen_num_lit_1->resolved_type);
        assert(!codegen_num_lit_2->resolved_type);

        if (is_num_lit_float(type1->data.num_lit.kind) &&
            is_num_lit_float(type2->data.num_lit.kind))
        {
            codegen_num_lit_1->resolved_type = g->builtin_types.entry_f64;
            codegen_num_lit_2->resolved_type = g->builtin_types.entry_f64;
            return g->builtin_types.entry_f64;
        } else if (is_num_lit_signed(type1->data.num_lit.kind) &&
                   is_num_lit_signed(type2->data.num_lit.kind))
        {
            codegen_num_lit_1->resolved_type = g->builtin_types.entry_i64;
            codegen_num_lit_2->resolved_type = g->builtin_types.entry_i64;
            return g->builtin_types.entry_i64;
        } else if (is_num_lit_unsigned(type1->data.num_lit.kind) &&
                   is_num_lit_unsigned(type2->data.num_lit.kind))
        {
            codegen_num_lit_1->resolved_type = g->builtin_types.entry_u64;
            codegen_num_lit_2->resolved_type = g->builtin_types.entry_u64;
            return g->builtin_types.entry_u64;
        } else {
            return nullptr;
        }
    } else if (type1->id == TypeTableEntryIdNumberLiteral) {
        return resolve_rhs_number_literal(g, node2, type2, node1, type1);
    } else {
        assert(type2->id == TypeTableEntryIdNumberLiteral);
        return resolve_rhs_number_literal(g, node1, type1, node2, type2);
    }
}

static TypeTableEntry *analyze_bin_op_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    switch (node->data.bin_op_expr.bin_op) {
        case BinOpTypeAssign:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftRight:
        case BinOpTypeAssignBitAnd:
        case BinOpTypeAssignBitXor:
        case BinOpTypeAssignBitOr:
        case BinOpTypeAssignBoolAnd:
        case BinOpTypeAssignBoolOr:
            {
                AstNode *lhs_node = node->data.bin_op_expr.op1;
                TypeTableEntry *expected_rhs_type = nullptr;
                if (lhs_node->type == NodeTypeSymbol) {
                    Buf *name = &lhs_node->data.symbol;
                    LocalVariableTableEntry *var = find_local_variable(context, name);
                    if (var) {
                        if (var->is_const) {
                            add_node_error(g, lhs_node,
                                buf_sprintf("cannot assign to constant variable"));
                        } else {
                            if (!is_op_allowed(var->type, node->data.bin_op_expr.bin_op)) {
                                if (var->type->id != TypeTableEntryIdInvalid) {
                                    add_node_error(g, lhs_node,
                                        buf_sprintf("operator not allowed for type '%s'",
                                            buf_ptr(&var->type->name)));
                                }
                            } else {
                                expected_rhs_type = var->type;
                            }
                        }
                    } else {
                        add_node_error(g, lhs_node,
                                buf_sprintf("use of undeclared identifier '%s'", buf_ptr(name)));
                    }
                } else if (lhs_node->type == NodeTypeArrayAccessExpr) {
                    expected_rhs_type = analyze_array_access_expr(g, import, context, lhs_node);
                } else if (lhs_node->type == NodeTypeFieldAccessExpr) {
                    alloc_codegen_node(lhs_node);
                    expected_rhs_type = analyze_field_access_expr(g, import, context, lhs_node);
                } else {
                    add_node_error(g, lhs_node,
                            buf_sprintf("assignment target must be variable, field, or array element"));
                }
                analyze_expression(g, import, context, expected_rhs_type, node->data.bin_op_expr.op2);
                return g->builtin_types.entry_void;
            }
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
            analyze_expression(g, import, context, g->builtin_types.entry_bool,
                    node->data.bin_op_expr.op1);
            analyze_expression(g, import, context, g->builtin_types.entry_bool,
                    node->data.bin_op_expr.op2);
            return g->builtin_types.entry_bool;
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
            {
                AstNode *op1 = node->data.bin_op_expr.op1;
                AstNode *op2 = node->data.bin_op_expr.op2;
                TypeTableEntry *lhs_type = analyze_expression(g, import, context, nullptr, op1);
                TypeTableEntry *rhs_type = analyze_expression(g, import, context, nullptr, op2);
                bool cmp_ok = false;
                if (lhs_type->id == TypeTableEntryIdInvalid || rhs_type->id == TypeTableEntryIdInvalid) {
                    cmp_ok = true;
                } else if (lhs_type->id == TypeTableEntryIdNumberLiteral ||
                           rhs_type->id == TypeTableEntryIdNumberLiteral)
                {
                    cmp_ok = resolve_number_literals(g, op1, op2);
                } else if (lhs_type->id == TypeTableEntryIdInt) {
                    if (rhs_type->id == TypeTableEntryIdInt &&
                        lhs_type->data.integral.is_signed == rhs_type->data.integral.is_signed &&
                        lhs_type->size_in_bits == rhs_type->size_in_bits)
                    {
                        cmp_ok = true;
                    }
                } else if (lhs_type->id == TypeTableEntryIdFloat) {
                    if (rhs_type->id == TypeTableEntryIdFloat &&
                        lhs_type->size_in_bits == rhs_type->size_in_bits)
                    {
                        cmp_ok = true;
                    }
                }
                if (!cmp_ok) {
                    add_node_error(g, node, buf_sprintf("unable to compare '%s' with '%s'",
                            buf_ptr(&lhs_type->name), buf_ptr(&rhs_type->name)));
                }
                return g->builtin_types.entry_bool;
            }
        case BinOpTypeBinOr:
        case BinOpTypeBinXor:
        case BinOpTypeBinAnd:
            {
                // TODO: don't require i32
                analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.bin_op_expr.op1);
                analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.bin_op_expr.op2);
                return g->builtin_types.entry_i32;
            }
        case BinOpTypeBitShiftLeft:
        case BinOpTypeBitShiftRight:
            {
                // TODO: don't require i32
                analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.bin_op_expr.op1);
                analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.bin_op_expr.op2);
                return g->builtin_types.entry_i32;
            }
        case BinOpTypeAdd:
        case BinOpTypeSub:
            {
                AstNode *op1 = node->data.bin_op_expr.op1;
                AstNode *op2 = node->data.bin_op_expr.op2;
                TypeTableEntry *lhs_type = analyze_expression(g, import, context, nullptr, op1);
                TypeTableEntry *rhs_type = analyze_expression(g, import, context, nullptr, op2);

                TypeTableEntry *return_type = nullptr;

                if (lhs_type->id == TypeTableEntryIdInvalid || rhs_type->id == TypeTableEntryIdInvalid) {
                    return_type = g->builtin_types.entry_invalid;
                } else if (lhs_type->id == TypeTableEntryIdNumberLiteral ||
                           rhs_type->id == TypeTableEntryIdNumberLiteral)
                {
                    return_type = resolve_number_literals(g, op1, op2);
                } else if (lhs_type->id == TypeTableEntryIdInt &&
                           lhs_type == rhs_type)
                {
                    return_type = lhs_type;
                } else if (lhs_type->id == TypeTableEntryIdFloat &&
                           lhs_type == rhs_type)
                {
                    return_type = lhs_type;
                }
                if (!return_type) {
                    if (node->data.bin_op_expr.bin_op == BinOpTypeAdd) {
                        add_node_error(g, node, buf_sprintf("unable to add '%s' and '%s'",
                                buf_ptr(&lhs_type->name), buf_ptr(&rhs_type->name)));
                    } else {
                        add_node_error(g, node, buf_sprintf("unable to subtract '%s' and '%s'",
                                buf_ptr(&lhs_type->name), buf_ptr(&rhs_type->name)));
                    }
                    return g->builtin_types.entry_invalid;
                }
                return return_type;
            }
        case BinOpTypeMult:
        case BinOpTypeDiv:
        case BinOpTypeMod:
            {
                // TODO: don't require i32
                analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.bin_op_expr.op1);
                analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.bin_op_expr.op2);
                return g->builtin_types.entry_i32;
            }
        case BinOpTypeInvalid:
            zig_unreachable();
    }
    zig_unreachable();
}

static TypeTableEntry *analyze_variable_declaration(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    AstNodeVariableDeclaration *variable_declaration = &node->data.variable_declaration;

    TypeTableEntry *explicit_type = nullptr;
    if (variable_declaration->type != nullptr) {
        explicit_type = resolve_type(g, variable_declaration->type);
        if (explicit_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, variable_declaration->type,
                buf_sprintf("variable of type 'unreachable' not allowed"));
            explicit_type = g->builtin_types.entry_invalid;
        }
    }

    TypeTableEntry *implicit_type = nullptr;
    if (variable_declaration->expr != nullptr) {
        implicit_type = analyze_expression(g, import, context, explicit_type, variable_declaration->expr);
        if (implicit_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, node,
                buf_sprintf("variable initialization is unreachable"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if (implicit_type->id == TypeTableEntryIdNumberLiteral) {
            add_node_error(g, node,
                buf_sprintf("unable to infer variable type"));
            implicit_type = g->builtin_types.entry_invalid;
        }
    }

    if (implicit_type == nullptr && variable_declaration->is_const) {
        add_node_error(g, node, buf_sprintf("variables must have initial values or be declared 'mut'."));
        implicit_type = g->builtin_types.entry_invalid;
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
        variable_entry->is_ptr = true;
        variable_entry->decl_node = node;
        context->variable_table.put(&variable_entry->name, variable_entry);
    }
    return g->builtin_types.entry_void;
}

static TypeTableEntry *analyze_number_literal_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    TypeTableEntry *num_lit_type = g->num_lit_types[node->data.number_literal.kind];
    if (node->data.number_literal.overflow) {
        add_node_error(g, node,
                buf_sprintf("number literal too large to be represented in any type"));
        return g->builtin_types.entry_invalid;
    } else if (expected_type) {
        if (expected_type->id == TypeTableEntryIdInvalid) {
            return g->builtin_types.entry_invalid;
        } else if (num_lit_fits_in_other_type(g, num_lit_type, expected_type)) {
            NumberLiteralNode *codegen_num_lit = &node->codegen_node->data.num_lit_node;
            assert(!codegen_num_lit->resolved_type);
            codegen_num_lit->resolved_type = expected_type;

            return expected_type;
        } else {
            add_node_error(g, node, buf_sprintf("expected type '%s', got '%s'",
                        buf_ptr(&expected_type->name), buf_ptr(&num_lit_type->name)));
            return g->builtin_types.entry_invalid;
        }
    } else {
        return num_lit_type;
    }
}

static TypeTableEntry * analyze_expression(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    TypeTableEntry *return_type = nullptr;
    alloc_codegen_node(node);
    switch (node->type) {
        case NodeTypeBlock:
            {
                BlockContext *child_context = new_block_context(node, context);
                node->codegen_node->data.block_node.block_context = child_context;
                return_type = g->builtin_types.entry_void;
                for (int i = 0; i < node->data.block.statements.length; i += 1) {
                    AstNode *child = node->data.block.statements.at(i);
                    if (child->type == NodeTypeLabel) {
                        LabelTableEntry *label_entry = child->codegen_node->data.label_entry;
                        assert(label_entry);
                        label_entry->entered_from_fallthrough = (return_type->id != TypeTableEntryIdUnreachable);
                        return_type = g->builtin_types.entry_void;
                        continue;
                    }
                    if (return_type->id == TypeTableEntryIdUnreachable) {
                        if (child->type == NodeTypeVoid) {
                            // {unreachable;void;void} is allowed.
                            // ignore void statements once we enter unreachable land.
                            continue;
                        }
                        add_node_error(g, first_executing_node(child), buf_sprintf("unreachable code"));
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

                if (actual_return_type->id == TypeTableEntryIdUnreachable) {
                    // "return exit(0)" should just be "exit(0)".
                    add_node_error(g, node, buf_sprintf("returning is unreachable"));
                    actual_return_type = g->builtin_types.entry_invalid;
                }

                check_type_compatibility(g, node, expected_return_type, actual_return_type);
                return_type = g->builtin_types.entry_unreachable;
                break;
            }
        case NodeTypeVariableDeclaration:
            return_type = analyze_variable_declaration(g, import, context, expected_type, node);
            break;
        case NodeTypeGoto:
            {
                FnTableEntry *fn_table_entry = get_context_fn_entry(context);
                auto table_entry = fn_table_entry->label_table.maybe_get(&node->data.go_to.name);
                if (table_entry) {
                    node->codegen_node->data.label_entry = table_entry->value;
                    table_entry->value->used = true;
                } else {
                    add_node_error(g, node,
                            buf_sprintf("use of undeclared label '%s'", buf_ptr(&node->data.go_to.name)));
                }
                return_type = g->builtin_types.entry_unreachable;
                break;
            }
        case NodeTypeAsmExpr:
            {
                for (int i = 0; i < node->data.asm_expr.output_list.length; i += 1) {
                    AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
                    analyze_variable_name(g, context, node, &asm_output->variable_name);
                }
                for (int i = 0; i < node->data.asm_expr.input_list.length; i += 1) {
                    AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
                    analyze_expression(g, import, context, nullptr, asm_input->expr);
                }

                return_type = g->builtin_types.entry_void;
                break;
            }
        case NodeTypeBinOpExpr:
            return_type = analyze_bin_op_expr(g, import, context, expected_type, node);
            break;

        case NodeTypeFnCallExpr:
            {
                AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
                if (fn_ref_expr->type != NodeTypeSymbol) {
                    add_node_error(g, node,
                            buf_sprintf("function pointers not allowed"));
                    break;
                }

                Buf *name = &fn_ref_expr->data.symbol;

                auto entry = import->fn_table.maybe_get(name);
                if (!entry)
                    entry = g->fn_table.maybe_get(name);

                if (!entry) {
                    add_node_error(g, fn_ref_expr,
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
                    if (fn_proto->is_var_args) {
                        if (actual_param_count < expected_param_count) {
                            add_node_error(g, node,
                                    buf_sprintf("wrong number of arguments. Expected at least %d, got %d.",
                                        expected_param_count, actual_param_count));
                        }
                    } else if (expected_param_count != actual_param_count) {
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

        case NodeTypeArrayAccessExpr:
            // for reading array access; assignment handled elsewhere
            return_type = analyze_array_access_expr(g, import, context, node);
            break;
        case NodeTypeFieldAccessExpr:
            return_type = analyze_field_access_expr(g, import, context, node);
            break;
        case NodeTypeNumberLiteral:
            return_type = analyze_number_literal_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeStringLiteral:
            if (node->data.string_literal.c) {
                return_type = g->builtin_types.entry_c_string_literal;
            } else {
                return_type = get_array_type(g, g->builtin_types.entry_u8, buf_len(&node->data.string_literal.buf));
            }
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
                return_type = analyze_variable_name(g, context, node, &node->data.symbol);
                break;
            }
        case NodeTypeCastExpr:
            return_type = analyze_cast_expr(g, import, context, expected_type, node);
            break;
        case NodeTypePrefixOpExpr:
            switch (node->data.prefix_op_expr.prefix_op) {
                case PrefixOpBoolNot:
                    analyze_expression(g, import, context, g->builtin_types.entry_bool,
                            node->data.prefix_op_expr.primary_expr);
                    return_type = g->builtin_types.entry_bool;
                    break;
                case PrefixOpBinNot:
                    {
                        // TODO: don't require i32
                        analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.prefix_op_expr.primary_expr);
                        return_type = g->builtin_types.entry_i32;
                        break;
                    }
                case PrefixOpNegation:
                    {
                        // TODO: don't require i32
                        analyze_expression(g, import, context, g->builtin_types.entry_i32, node->data.prefix_op_expr.primary_expr);
                        return_type = g->builtin_types.entry_i32;
                        break;
                    }
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
                if (then_type->id == TypeTableEntryIdUnreachable) {
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
        case NodeTypeStructDecl:
        case NodeTypeStructField:
            zig_unreachable();
    }
    assert(return_type);
    check_type_compatibility(g, node, expected_type, return_type);

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

                alloc_codegen_node(node);
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
                    variable_entry->arg_index = i;

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
        case NodeTypeStructDecl:
            // nothing to do
            break;
        case NodeTypeVariableDeclaration:
            analyze_variable_declaration(g, import, import->block_context, nullptr, node);
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnProto:
        case NodeTypeType:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
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
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeStructField:
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

static void preview_types_root(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeRoot);

    for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
        AstNode *child = node->data.root.top_level_decls.at(i);
        preview_types(g, import, child);
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
            preview_types_root(g, import, import->root);
        }
    }
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
