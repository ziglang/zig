/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "parser.hpp"
#include "error.hpp"
#include "zig_llvm.hpp"
#include "os.hpp"

static TypeTableEntry * analyze_expression(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node);
static VariableTableEntry *analyze_variable_declaration(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, TypeTableEntry *expected_type, AstNode *node);
static void resolve_struct_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *struct_type);
static TypeTableEntry *unwrapped_node_type(AstNode *node);

static AstNode *first_executing_node(AstNode *node) {
    switch (node->type) {
        case NodeTypeFnCallExpr:
            return first_executing_node(node->data.fn_call_expr.fn_ref_expr);
        case NodeTypeBinOpExpr:
            return first_executing_node(node->data.bin_op_expr.op1);
        case NodeTypeArrayAccessExpr:
            return first_executing_node(node->data.array_access_expr.array_ref_expr);
        case NodeTypeSliceExpr:
            return first_executing_node(node->data.slice_expr.array_ref_expr);
        case NodeTypeFieldAccessExpr:
            return first_executing_node(node->data.field_access_expr.struct_expr);
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeBlock:
        case NodeTypeExternBlock:
        case NodeTypeDirective:
        case NodeTypeReturnExpr:
        case NodeTypeVariableDeclaration:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeUse:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeAsmExpr:
        case NodeTypeStructDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeWhileExpr:
        case NodeTypeContainerInitExpr:
        case NodeTypeArrayType:
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

    switch (id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdNumberLiteral:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdFn:
            // nothing to init
            break;
        case TypeTableEntryIdStruct:
            entry->data.structure.fn_table.init(8);
            break;
        case TypeTableEntryIdEnum:
            entry->data.enumeration.fn_table.init(8);
            break;

    }

    return entry;
}

static NumLit get_number_literal_kind_unsigned(uint64_t x) {
    if (x <= UINT8_MAX) {
        return NumLitU8;
    } else if (x <= UINT16_MAX) {
        return NumLitU16;
    } else if (x <= UINT32_MAX) {
        return NumLitU32;
    } else {
        return NumLitU64;
    }
}

static TypeTableEntry *get_number_literal_type_unsigned(CodeGen *g, uint64_t x) {
    return g->num_lit_types[get_number_literal_kind_unsigned(x)];
}

static TypeTableEntry *get_int_type_unsigned(CodeGen *g, uint64_t x) {
    return get_int_type(g, false, num_lit_bit_count(get_number_literal_kind_unsigned(x)));
}

TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const) {
    assert(child_type->id != TypeTableEntryIdInvalid);
    TypeTableEntry **parent_pointer = &child_type->pointer_parent[(is_const ? 1 : 0)];
    if (*parent_pointer) {
        return *parent_pointer;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdPointer);
        entry->type_ref = LLVMPointerType(child_type->type_ref, 0);

        const char *const_str = is_const ? "const " : "";
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "&%s%s", const_str, buf_ptr(&child_type->name));

        entry->size_in_bits = g->pointer_size_bytes * 8;
        entry->align_in_bits = g->pointer_size_bytes * 8;
        assert(child_type->di_type);
        entry->di_type = LLVMZigCreateDebugPointerType(g->dbuilder, child_type->di_type,
                entry->size_in_bits, entry->align_in_bits, buf_ptr(&entry->name));
        entry->data.pointer.child_type = child_type;
        entry->data.pointer.is_const = is_const;

        *parent_pointer = entry;
        return entry;
    }
}

static TypeTableEntry *get_maybe_type(CodeGen *g, TypeTableEntry *child_type) {
    if (child_type->maybe_parent) {
        TypeTableEntry *entry = child_type->maybe_parent;
        return entry;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdMaybe);
        // create a struct with a boolean whether this is the null value
        assert(child_type->type_ref);
        LLVMTypeRef elem_types[] = {
            child_type->type_ref,
            LLVMInt1Type(),
        };
        entry->type_ref = LLVMStructType(elem_types, 2, false);
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "?%s", buf_ptr(&child_type->name));
        entry->size_in_bits = child_type->size_in_bits + 8;
        entry->align_in_bits = child_type->align_in_bits;
        assert(child_type->di_type);


        LLVMZigDIScope *compile_unit_scope = LLVMZigCompileUnitToScope(g->compile_unit);
        LLVMZigDIFile *di_file = nullptr;
        unsigned line = 0;
        entry->di_type = LLVMZigCreateReplaceableCompositeType(g->dbuilder,
            LLVMZigTag_DW_structure_type(), buf_ptr(&entry->name),
            compile_unit_scope, di_file, line);

        LLVMZigDIType *di_element_types[] = {
            LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                    "val", di_file, line, child_type->size_in_bits, child_type->align_in_bits, 0, 0,
                    child_type->di_type),
            LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                    "maybe", di_file, line, 8, 8, 8, 0,
                    child_type->di_type),
        };
        LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                compile_unit_scope,
                buf_ptr(&entry->name),
                di_file, line, entry->size_in_bits, entry->align_in_bits, 0,
                nullptr, di_element_types, 2, 0, nullptr, "");

        LLVMZigReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
        entry->di_type = replacement_di_type;

        entry->data.maybe.child_type = child_type;

        child_type->maybe_parent = entry;
        return entry;
    }
}

static TypeTableEntry *get_array_type(CodeGen *g, ImportTableEntry *import,
        TypeTableEntry *child_type, uint64_t array_size)
{
    auto existing_entry = child_type->arrays_by_size.maybe_get(array_size);
    if (existing_entry) {
        TypeTableEntry *entry = existing_entry->value;
        return entry;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdArray);
        entry->type_ref = LLVMArrayType(child_type->type_ref, array_size);
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[%" PRIu64 "]%s", array_size, buf_ptr(&child_type->name));

        entry->size_in_bits = child_type->size_in_bits * array_size;
        entry->align_in_bits = child_type->align_in_bits;

        entry->di_type = LLVMZigCreateDebugArrayType(g->dbuilder, entry->size_in_bits,
                entry->align_in_bits, child_type->di_type, array_size);
        entry->data.array.child_type = child_type;
        entry->data.array.len = array_size;

        child_type->arrays_by_size.put(array_size, entry);
        return entry;
    }
}

static TypeTableEntry *get_unknown_size_array_type(CodeGen *g, ImportTableEntry *import,
        TypeTableEntry *child_type, bool is_const)
{
    assert(child_type->id != TypeTableEntryIdInvalid);
    TypeTableEntry **parent_pointer = &child_type->unknown_size_array_parent[(is_const ? 1 : 0)];
    if (*parent_pointer) {
        return *parent_pointer;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdStruct);

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[]%s", buf_ptr(&child_type->name));
        entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), buf_ptr(&entry->name));

        TypeTableEntry *pointer_type = get_pointer_to_type(g, child_type, is_const);

        unsigned element_count = 2;
        LLVMTypeRef element_types[] = {
            pointer_type->type_ref,
            g->builtin_types.entry_usize->type_ref,
        };
        LLVMStructSetBody(entry->type_ref, element_types, element_count, false);

        entry->size_in_bits = g->pointer_size_bytes * 2 * 8;
        entry->align_in_bits = g->pointer_size_bytes * 8;
        entry->data.structure.is_packed = false;
        entry->data.structure.is_unknown_size_array = true;
        entry->data.structure.field_count = element_count;
        entry->data.structure.fields = allocate<TypeStructField>(element_count);
        entry->data.structure.fields[0].name = buf_create_from_str("ptr");
        entry->data.structure.fields[0].type_entry = pointer_type;
        entry->data.structure.fields[0].src_index = 0;
        entry->data.structure.fields[0].gen_index = 0;
        entry->data.structure.fields[1].name = buf_create_from_str("len");
        entry->data.structure.fields[1].type_entry = g->builtin_types.entry_usize;
        entry->data.structure.fields[1].src_index = 1;
        entry->data.structure.fields[1].gen_index = 1;

        LLVMZigDIType *di_element_types[] = {
            pointer_type->di_type,
            g->builtin_types.entry_usize->di_type,
        };
        LLVMZigDIScope *compile_unit_scope = LLVMZigCompileUnitToScope(g->compile_unit);
        entry->di_type = LLVMZigCreateDebugStructType(g->dbuilder, compile_unit_scope,
                buf_ptr(&entry->name), g->dummy_di_file, 0, entry->size_in_bits, entry->align_in_bits, 0,
                nullptr, di_element_types, element_count, 0, nullptr, "");

        *parent_pointer = entry;
        return entry;
    }
}

// If the node does not have a constant expression value with a metatype, generates an error
// and returns invalid type. Otherwise, returns the type of the constant expression value.
// Must be called after analyze_expression on the same node.
static TypeTableEntry *resolve_type(CodeGen *g, AstNode *node) {
    Expr *expr = get_resolved_expr(node);
    assert(expr->type_entry);
    if (expr->type_entry->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    } else if (expr->type_entry->id == TypeTableEntryIdMetaType) {
        // OK
    } else {
        add_node_error(g, node, buf_sprintf("expected type, found expression"));
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *const_val = &expr->const_val;
    if (!const_val->ok) {
        add_node_error(g, node, buf_sprintf("unable to resolve constant expression"));
        return g->builtin_types.entry_invalid;
    }

    return const_val->data.x_type;
}

// Calls analyze_expression on node, and then resolve_type.
static TypeTableEntry *analyze_type_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    analyze_expression(g, import, context, nullptr, node);
    return resolve_type(g, node);
}

static void resolve_function_proto(CodeGen *g, AstNode *node, FnTableEntry *fn_table_entry,
        ImportTableEntry *import)
{
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

    int param_count = node->data.fn_proto.params.length;

    TypeTableEntry *fn_type = new_type_table_entry(TypeTableEntryIdFn);
    fn_type->data.fn.param_count = param_count;
    fn_type->data.fn.param_types = allocate<TypeTableEntry*>(param_count);

    fn_table_entry->type_entry = fn_type;

    buf_resize(&fn_type->name, 0);
    buf_appendf(&fn_type->name, "fn(");
    for (int i = 0; i < param_count; i += 1) {
        AstNode *child = node->data.fn_proto.params.at(i);
        assert(child->type == NodeTypeParamDecl);
        TypeTableEntry *type_entry = analyze_type_expr(g, import, import->block_context,
                child->data.param_decl.type);
        fn_table_entry->type_entry->data.fn.param_types[i] = type_entry;

        buf_appendf(&fn_type->name, "%s", buf_ptr(&type_entry->name));

        if (i + 1 < param_count) {
            buf_appendf(&fn_type->name, ", ");
        }

        if (type_entry->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, child->data.param_decl.type,
                buf_sprintf("parameter of type 'unreachable' not allowed"));
        } else if (type_entry->id == TypeTableEntryIdVoid) {
            if (node->data.fn_proto.visib_mod == VisibModExport) {
                add_node_error(g, child->data.param_decl.type,
                    buf_sprintf("parameter of type 'void' not allowed on exported functions"));
            }
        }
    }

    TypeTableEntry *return_type = analyze_type_expr(g, import, import->block_context,
            node->data.fn_proto.return_type);
    fn_table_entry->type_entry->data.fn.return_type = return_type;

    buf_appendf(&fn_type->name, ")");
    if (return_type->id != TypeTableEntryIdVoid) {
        buf_appendf(&fn_type->name, " %s", buf_ptr(&return_type->name));
    }
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

        label_node->data.label.label_entry = label_entry;
    }
}

static void resolve_enum_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *enum_type) {
    assert(enum_type->id == TypeTableEntryIdEnum);

    AstNode *decl_node = enum_type->data.enumeration.decl_node;

    if (enum_type->data.enumeration.embedded_in_current) {
        if (!enum_type->data.enumeration.reported_infinite_err) {
            enum_type->data.enumeration.reported_infinite_err = true;
            add_node_error(g, decl_node, buf_sprintf("enum has infinite size"));
        }
        return;
    }

    if (enum_type->data.enumeration.fields) {
        // we already resolved this type. skip
        return;
    }

    assert(enum_type->di_type);

    uint32_t field_count = decl_node->data.struct_decl.fields.length;

    enum_type->data.enumeration.field_count = field_count;
    enum_type->data.enumeration.fields = allocate<TypeEnumField>(field_count);
    LLVMZigDIEnumerator **di_enumerators = allocate<LLVMZigDIEnumerator*>(field_count);

    // we possibly allocate too much here since gen_field_count can be lower than field_count.
    // the only problem is potential wasted space though.
    LLVMZigDIType **union_inner_di_types = allocate<LLVMZigDIType*>(field_count);

    TypeTableEntry *biggest_union_member = nullptr;
    uint64_t biggest_align_in_bits = 0;
    uint64_t biggest_union_member_size_in_bits = 0;

    // set temporary flag
    enum_type->data.enumeration.embedded_in_current = true;

    int gen_field_index = 0;
    for (uint32_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.struct_decl.fields.at(i);
        TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[i];
        type_enum_field->name = &field_node->data.struct_field.name;
        type_enum_field->type_entry = analyze_type_expr(g, import, import->block_context,
                field_node->data.struct_field.type);
        type_enum_field->value = i;

        di_enumerators[i] = LLVMZigCreateDebugEnumerator(g->dbuilder, buf_ptr(type_enum_field->name), i);

        if (type_enum_field->type_entry->id == TypeTableEntryIdStruct) {
            resolve_struct_type(g, import, type_enum_field->type_entry);
        } else if (type_enum_field->type_entry->id == TypeTableEntryIdEnum) {
            resolve_enum_type(g, import, type_enum_field->type_entry);
        } else if (type_enum_field->type_entry->id == TypeTableEntryIdInvalid) {
            enum_type->data.enumeration.is_invalid = true;
            continue;
        } else if (type_enum_field->type_entry->id == TypeTableEntryIdVoid) {
            continue;
        }

        union_inner_di_types[gen_field_index] = LLVMZigCreateDebugMemberType(g->dbuilder,
                LLVMZigTypeToScope(enum_type->di_type), buf_ptr(type_enum_field->name),
                import->di_file, field_node->line + 1,
                type_enum_field->type_entry->size_in_bits,
                type_enum_field->type_entry->align_in_bits,
                0, 0, type_enum_field->type_entry->di_type);

        biggest_align_in_bits = max(biggest_align_in_bits, type_enum_field->type_entry->align_in_bits);

        if (!biggest_union_member ||
            type_enum_field->type_entry->size_in_bits > biggest_union_member->size_in_bits)
        {
            biggest_union_member = type_enum_field->type_entry;
            biggest_union_member_size_in_bits = biggest_union_member->size_in_bits;
        }

        gen_field_index += 1;
    }

    // unset temporary flag
    enum_type->data.enumeration.embedded_in_current = false;

    if (!enum_type->data.enumeration.is_invalid) {
        enum_type->data.enumeration.gen_field_count = gen_field_index;

        uint64_t tag_size_in_bits = num_lit_bit_count(get_number_literal_kind_unsigned(field_count));
        enum_type->align_in_bits = tag_size_in_bits;
        enum_type->size_in_bits = tag_size_in_bits + biggest_union_member_size_in_bits;
        TypeTableEntry *tag_type_entry = get_int_type_unsigned(g, field_count);
        enum_type->data.enumeration.tag_type = tag_type_entry;

        if (biggest_union_member) {
            // create llvm type for union
            LLVMTypeRef union_element_type = biggest_union_member->type_ref;
            LLVMTypeRef union_type_ref = LLVMStructType(&union_element_type, 1, false);

            // create llvm type for root struct
            LLVMTypeRef root_struct_element_types[] = {
                tag_type_entry->type_ref,
                union_type_ref,
            };
            LLVMStructSetBody(enum_type->type_ref, root_struct_element_types, 2, false);

            // create debug type for tag
            LLVMZigDIType *tag_di_type = LLVMZigCreateDebugEnumerationType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "AnonEnum", import->di_file, decl_node->line + 1,
                    tag_type_entry->size_in_bits, tag_type_entry->align_in_bits, di_enumerators, field_count,
                    tag_type_entry->di_type, "");

            // create debug type for union
            LLVMZigDIType *union_di_type = LLVMZigCreateDebugUnionType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "AnonUnion", import->di_file, decl_node->line + 1,
                    biggest_union_member->size_in_bits, biggest_align_in_bits, 0, union_inner_di_types,
                    gen_field_index, 0, "");

            // create debug types for members of root struct
            LLVMZigDIType *tag_member_di_type = LLVMZigCreateDebugMemberType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "tag_field",
                    import->di_file, decl_node->line + 1,
                    tag_type_entry->size_in_bits,
                    tag_type_entry->align_in_bits,
                    0, 0, tag_di_type);
            LLVMZigDIType *union_member_di_type = LLVMZigCreateDebugMemberType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "union_field",
                    import->di_file, decl_node->line + 1,
                    biggest_union_member->size_in_bits,
                    biggest_align_in_bits,
                    tag_type_entry->size_in_bits, 0, union_di_type);

            // create debug type for root struct
            LLVMZigDIType *di_root_members[] = {
                tag_member_di_type,
                union_member_di_type,
            };


            LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                    LLVMZigFileToScope(import->di_file),
                    buf_ptr(&decl_node->data.struct_decl.name),
                    import->di_file, decl_node->line + 1, enum_type->size_in_bits, enum_type->align_in_bits, 0,
                    nullptr, di_root_members, 2, 0, nullptr, "");

            LLVMZigReplaceTemporary(g->dbuilder, enum_type->di_type, replacement_di_type);
            enum_type->di_type = replacement_di_type;
        } else {
            // create llvm type for root struct
            enum_type->type_ref = tag_type_entry->type_ref;

            // create debug type for tag
            LLVMZigDIType *tag_di_type = LLVMZigCreateDebugEnumerationType(g->dbuilder,
                    LLVMZigFileToScope(import->di_file), buf_ptr(&decl_node->data.struct_decl.name),
                    import->di_file, decl_node->line + 1,
                    tag_type_entry->size_in_bits, tag_type_entry->align_in_bits, di_enumerators, field_count,
                    tag_type_entry->di_type, "");

            LLVMZigReplaceTemporary(g->dbuilder, enum_type->di_type, tag_di_type);
            enum_type->di_type = tag_di_type;

        }

    }
}

static void resolve_struct_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *struct_type) {
    assert(struct_type->id == TypeTableEntryIdStruct);

    AstNode *decl_node = struct_type->data.structure.decl_node;

    if (struct_type->data.structure.embedded_in_current) {
        if (!struct_type->data.structure.reported_infinite_err) {
            struct_type->data.structure.reported_infinite_err = true;
            add_node_error(g, decl_node,
                    buf_sprintf("struct has infinite size"));
        }
        return;
    }

    if (struct_type->data.structure.fields) {
        // we already resolved this type. skip
        return;
    }


    assert(struct_type->di_type);

    int field_count = decl_node->data.struct_decl.fields.length;

    struct_type->data.structure.field_count = field_count;
    struct_type->data.structure.fields = allocate<TypeStructField>(field_count);

    // we possibly allocate too much here since gen_field_count can be lower than field_count.
    // the only problem is potential wasted space though.
    LLVMTypeRef *element_types = allocate<LLVMTypeRef>(field_count);
    LLVMZigDIType **di_element_types = allocate<LLVMZigDIType*>(field_count);

    uint64_t total_size_in_bits = 0;
    uint64_t first_field_align_in_bits = 0;
    uint64_t offset_in_bits = 0;

    // this field should be set to true only during the recursive calls to resolve_struct_type
    struct_type->data.structure.embedded_in_current = true;

    int gen_field_index = 0;
    for (int i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.struct_decl.fields.at(i);
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        type_struct_field->name = &field_node->data.struct_field.name;
        type_struct_field->type_entry = analyze_type_expr(g, import, import->block_context,
                field_node->data.struct_field.type);
        type_struct_field->src_index = i;
        type_struct_field->gen_index = -1;

        if (type_struct_field->type_entry->id == TypeTableEntryIdStruct) {
            resolve_struct_type(g, import, type_struct_field->type_entry);
        } else if (type_struct_field->type_entry->id == TypeTableEntryIdEnum) {
            resolve_enum_type(g, import, type_struct_field->type_entry);
        } else if (type_struct_field->type_entry->id == TypeTableEntryIdInvalid) {
            struct_type->data.structure.is_invalid = true;
            continue;
        } else if (type_struct_field->type_entry->id == TypeTableEntryIdVoid) {
            continue;
        }

        type_struct_field->gen_index = gen_field_index;

        di_element_types[gen_field_index] = LLVMZigCreateDebugMemberType(g->dbuilder,
                LLVMZigTypeToScope(struct_type->di_type), buf_ptr(type_struct_field->name),
                import->di_file, field_node->line + 1,
                type_struct_field->type_entry->size_in_bits,
                type_struct_field->type_entry->align_in_bits,
                offset_in_bits, 0, type_struct_field->type_entry->di_type);

        element_types[gen_field_index] = type_struct_field->type_entry->type_ref;
        assert(di_element_types[gen_field_index]);
        assert(element_types[gen_field_index]);

        total_size_in_bits += type_struct_field->type_entry->size_in_bits;
        if (first_field_align_in_bits == 0) {
            first_field_align_in_bits = type_struct_field->type_entry->align_in_bits;
        }
        offset_in_bits += type_struct_field->type_entry->size_in_bits;

        gen_field_index += 1;
    }
    struct_type->data.structure.embedded_in_current = false;

    if (!struct_type->data.structure.is_invalid) {

        LLVMStructSetBody(struct_type->type_ref, element_types, gen_field_index, false);

        struct_type->align_in_bits = first_field_align_in_bits;
        struct_type->size_in_bits = total_size_in_bits;

        LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                LLVMZigFileToScope(import->di_file),
                buf_ptr(&decl_node->data.struct_decl.name),
                import->di_file, decl_node->line + 1, struct_type->size_in_bits, struct_type->align_in_bits, 0,
                nullptr, di_element_types, gen_field_index, 0, nullptr, "");

        LLVMZigReplaceTemporary(g->dbuilder, struct_type->di_type, replacement_di_type);
        struct_type->di_type = replacement_di_type;
    }
}

static void preview_fn_proto(CodeGen *g, ImportTableEntry *import,
        AstNode *proto_node)
{
    AstNode *fn_def_node = proto_node->data.fn_proto.fn_def_node;
    AstNode *extern_node = proto_node->data.fn_proto.extern_node;
    AstNode *struct_node = proto_node->data.fn_proto.struct_node;
    TypeTableEntry *struct_type;
    if (struct_node) {
        assert(struct_node->type == NodeTypeStructDecl);
        struct_type = struct_node->data.struct_decl.type_entry;
    } else {
        struct_type = nullptr;
    }

    Buf *proto_name = &proto_node->data.fn_proto.name;

    auto fn_table = struct_type ? &struct_type->data.structure.fn_table : &import->fn_table;

    auto entry = fn_table->maybe_get(proto_name);
    bool skip = false;
    bool is_internal = (proto_node->data.fn_proto.visib_mod != VisibModExport);
    bool is_c_compat = !is_internal || extern_node;
    bool is_pub = (proto_node->data.fn_proto.visib_mod != VisibModPrivate);
    if (entry) {
        add_node_error(g, proto_node,
                buf_sprintf("redefinition of '%s'", buf_ptr(proto_name)));
        proto_node->data.fn_proto.skip = true;
        skip = true;
    } else if (is_pub) {
        // TODO is this else if branch a mistake?
        auto entry = fn_table->maybe_get(proto_name);
        if (entry) {
            add_node_error(g, proto_node, buf_sprintf("redefinition of '%s'", buf_ptr(proto_name)));
            proto_node->data.fn_proto.skip = true;
            skip = true;
        }
    }
    if (!extern_node && proto_node->data.fn_proto.is_var_args) {
        add_node_error(g, proto_node,
                buf_sprintf("variadic arguments only allowed in extern functions"));
    }
    if (skip) {
        return;
    }

    FnTableEntry *fn_table_entry = allocate<FnTableEntry>(1);
    fn_table_entry->import_entry = import;
    fn_table_entry->proto_node = proto_node;
    fn_table_entry->fn_def_node = fn_def_node;
    fn_table_entry->internal_linkage = !is_c_compat;
    fn_table_entry->is_extern = extern_node;
    fn_table_entry->calling_convention = is_c_compat ? LLVMCCallConv : LLVMFastCallConv;
    fn_table_entry->label_table.init(8);
    fn_table_entry->member_of_struct = struct_type;

    if (struct_type) {
        buf_resize(&fn_table_entry->symbol_name, 0);
        buf_appendf(&fn_table_entry->symbol_name, "%s_%s",
                buf_ptr(&struct_type->name),
                buf_ptr(proto_name));
    } else {
        buf_init_from_buf(&fn_table_entry->symbol_name, proto_name);
    }

    g->fn_protos.append(fn_table_entry);

    if (!extern_node) {
        g->fn_defs.append(fn_table_entry);
    }

    fn_table->put(proto_name, fn_table_entry);

    if (!struct_type &&
        g->bootstrap_import &&
        import == g->root_import && buf_eql_str(proto_name, "main"))
    {
        g->bootstrap_import->fn_table.put(proto_name, fn_table_entry);
    }

    resolve_function_proto(g, proto_node, fn_table_entry, import);


    proto_node->data.fn_proto.fn_table_entry = fn_table_entry;

    if (fn_def_node) {
        preview_function_labels(g, fn_def_node->data.fn_def.body, fn_table_entry);
    }

    if (is_pub && !struct_type) {
        for (int i = 0; i < import->importers.length; i += 1) {
            ImporterInfo importer = import->importers.at(i);
            auto table_entry = importer.import->fn_table.maybe_get(proto_name);
            if (table_entry) {
                add_node_error(g, importer.source_node,
                    buf_sprintf("import of function '%s' overrides existing definition",
                        buf_ptr(proto_name)));
            } else {
                importer.import->fn_table.put(proto_name, fn_table_entry);
            }
        }
    }
}

static void resolve_top_level_decl(CodeGen *g, ImportTableEntry *import, AstNode *node) {
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
            break;
        case NodeTypeFnProto:
            preview_fn_proto(g, import, node);
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
                TypeTableEntry *type_entry = node->data.struct_decl.type_entry;

                // struct/enum member fns will get resolved independently

                switch (node->data.struct_decl.kind) {
                    case ContainerKindStruct:
                        resolve_struct_type(g, import, type_entry);
                        break;
                    case ContainerKindEnum:
                        resolve_enum_type(g, import, type_entry);
                        break;
                }

                break;
            }
        case NodeTypeVariableDeclaration:
            {
                VariableTableEntry *var = analyze_variable_declaration(g, import, import->block_context,
                        nullptr, node);
                g->global_vars.append(var);
                break;
            }
        case NodeTypeUse:
            // nothing to do here
            break;
        case NodeTypeFnDef:
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeContainerInitExpr:
        case NodeTypeArrayType:
            zig_unreachable();
    }
}

static FnTableEntry *get_context_fn_entry(BlockContext *context) {
    assert(context->fn_entry);
    return context->fn_entry;
}

static TypeTableEntry *unwrapped_node_type(AstNode *node) {
    Expr *expr = get_resolved_expr(node);
    if (expr->type_entry->id == TypeTableEntryIdInvalid) {
        return expr->type_entry;
    }
    assert(expr->type_entry->id == TypeTableEntryIdMetaType);
    ConstExprValue *const_val = &expr->const_val;
    assert(const_val->ok);
    return const_val->data.x_type;
}

static TypeTableEntry *get_return_type(BlockContext *context) {
    FnTableEntry *fn_entry = get_context_fn_entry(context);
    AstNode *fn_proto_node = fn_entry->proto_node;
    assert(fn_proto_node->type == NodeTypeFnProto);
    AstNode *return_type_node = fn_proto_node->data.fn_proto.return_type;
    return unwrapped_node_type(return_type_node);
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
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdFn:
            return false;
        case TypeTableEntryIdInt:
            if (is_num_lit_unsigned(num_lit)) {
                return lit_size_in_bits <= other_type->size_in_bits;
            } else {
                return false;
            }
        case TypeTableEntryIdFloat:
            if (is_num_lit_float(num_lit)) {
                return lit_size_in_bits <= other_type->size_in_bits;
            } else if (other_type->size_in_bits == 32) {
                return lit_size_in_bits < 24;
            } else if (other_type->size_in_bits == 64) {
                return lit_size_in_bits < 53;
            } else {
                return false;
            }
        case TypeTableEntryIdMaybe:
            return false;
    }
    zig_unreachable();
}

static TypeTableEntry *resolve_rhs_number_literal(CodeGen *g, AstNode *non_literal_node,
        TypeTableEntry *non_literal_type, AstNode *literal_node, TypeTableEntry *literal_type)
{
    NumLitCodeGen *num_lit_codegen = get_resolved_num_lit(literal_node);

    if (non_literal_type && num_lit_fits_in_other_type(g, literal_type, non_literal_type)) {
        assert(!num_lit_codegen->resolved_type);
        num_lit_codegen->resolved_type = non_literal_type;
        return non_literal_type;
    } else {
        return nullptr;
    }
}

static TypeTableEntry * resolve_number_literals(CodeGen *g, AstNode *node1, AstNode *node2,
        TypeTableEntry *type1, TypeTableEntry *type2)
{
    if (type1->id == TypeTableEntryIdNumberLiteral &&
        type2->id == TypeTableEntryIdNumberLiteral)
    {
        NumLitCodeGen *codegen_num_lit_1 = get_resolved_num_lit(node1);
        NumLitCodeGen *codegen_num_lit_2 = get_resolved_num_lit(node2);

        assert(!codegen_num_lit_1->resolved_type);
        assert(!codegen_num_lit_2->resolved_type);

        if (is_num_lit_float(type1->data.num_lit.kind) &&
            is_num_lit_float(type2->data.num_lit.kind))
        {
            codegen_num_lit_1->resolved_type = g->builtin_types.entry_f64;
            codegen_num_lit_2->resolved_type = g->builtin_types.entry_f64;
            return g->builtin_types.entry_f64;
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

static TypeTableEntry *determine_peer_type_compatibility(CodeGen *g, AstNode *node,
        TypeTableEntry *type1, TypeTableEntry *type2, AstNode *node1, AstNode *node2)
{
    if (type1->id == TypeTableEntryIdInvalid ||
        type2->id == TypeTableEntryIdInvalid)
    {
        return type1;
    } else if (type1->id == TypeTableEntryIdUnreachable) {
        return type2;
    } else if (type2->id == TypeTableEntryIdUnreachable) {
        return type1;
    } else if (type1->id == TypeTableEntryIdInt &&
        type2->id == TypeTableEntryIdInt &&
        type1->data.integral.is_signed == type2->data.integral.is_signed)
    {
        return (type1->size_in_bits > type2->size_in_bits) ? type1 : type2;
    } else if (type1->id == TypeTableEntryIdFloat &&
               type2->id == TypeTableEntryIdFloat)
    {
        return (type1->size_in_bits > type2->size_in_bits) ? type1 : type2;
    } else if (type1->id == TypeTableEntryIdArray &&
               type2->id == TypeTableEntryIdArray &&
               type1 == type2)
    {
        return type1;
    } else if (type1->id == TypeTableEntryIdNumberLiteral ||
               type2->id == TypeTableEntryIdNumberLiteral)
    {
        TypeTableEntry *resolved_type = resolve_number_literals(g, node1, node2, type1, type2);
        if (resolved_type)
            return resolved_type;
    } else if (type1 == type2) {
        return type1;
    }

    add_node_error(g, node,
        buf_sprintf("incompatible types: '%s' and '%s'",
            buf_ptr(&type1->name), buf_ptr(&type2->name)));

    return g->builtin_types.entry_invalid;
}

static TypeTableEntry *resolve_type_compatibility(CodeGen *g, BlockContext *context, AstNode *node,
        TypeTableEntry *expected_type, TypeTableEntry *actual_type)
{
    if (expected_type == nullptr)
        return actual_type; // anything will do
    if (expected_type == actual_type)
        return expected_type; // match
    if (expected_type->id == TypeTableEntryIdInvalid || actual_type->id == TypeTableEntryIdInvalid)
        return expected_type; // already complained
    if (actual_type->id == TypeTableEntryIdUnreachable)
        return actual_type; // sorry toots; gotta run. good luck with that expected type.

    if (actual_type->id == TypeTableEntryIdNumberLiteral &&
        num_lit_fits_in_other_type(g, actual_type, expected_type))
    {
        NumLitCodeGen *num_lit_code_gen = get_resolved_num_lit(node);
        assert(!num_lit_code_gen->resolved_type ||
                num_lit_code_gen->resolved_type == expected_type);
        num_lit_code_gen->resolved_type = expected_type;
        return expected_type;
    }

    if (expected_type->id == TypeTableEntryIdMaybe &&
        actual_type->id == TypeTableEntryIdMaybe)
    {
        TypeTableEntry *expected_child = expected_type->data.maybe.child_type;
        TypeTableEntry *actual_child = actual_type->data.maybe.child_type;
        return resolve_type_compatibility(g, context, node, expected_child, actual_child);
    }

    // implicit conversion from non maybe type to maybe type
    if (expected_type->id == TypeTableEntryIdMaybe) {
        TypeTableEntry *resolved_type = resolve_type_compatibility(g, context, node,
                expected_type->data.maybe.child_type, actual_type);
        if (resolved_type->id == TypeTableEntryIdInvalid) {
            return resolved_type;
        }
        Expr *expr = get_resolved_expr(node);
        expr->implicit_maybe_cast.op = CastOpMaybeWrap;
        expr->implicit_maybe_cast.after_type = expected_type;
        expr->implicit_maybe_cast.source_node = node;
        context->cast_expr_alloca_list.append(&expr->implicit_maybe_cast);
        return expected_type;
    }

    // implicit widening conversion
    if (expected_type->id == TypeTableEntryIdInt &&
        actual_type->id == TypeTableEntryIdInt &&
        expected_type->data.integral.is_signed == actual_type->data.integral.is_signed &&
        expected_type->size_in_bits > actual_type->size_in_bits)
    {
        Expr *expr = get_resolved_expr(node);
        expr->implicit_cast.after_type = expected_type;
        expr->implicit_cast.op = CastOpIntWidenOrShorten;
        expr->implicit_cast.source_node = node;
        return expected_type;
    }

    // implicit constant sized array to unknown size array conversion
    if (expected_type->id == TypeTableEntryIdStruct &&
        expected_type->data.structure.is_unknown_size_array &&
        actual_type->id == TypeTableEntryIdArray &&
        actual_type->data.array.child_type == expected_type->data.structure.fields[0].type_entry->data.pointer.child_type)
    {
        Expr *expr = get_resolved_expr(node);
        expr->implicit_cast.after_type = expected_type;
        expr->implicit_cast.op = CastOpToUnknownSizeArray;
        expr->implicit_cast.source_node = node;
        context->cast_expr_alloca_list.append(&expr->implicit_cast);
        return expected_type;
    }

    // implicit non-const to const and ignore noalias
    if (expected_type->id == TypeTableEntryIdPointer &&
        actual_type->id == TypeTableEntryIdPointer &&
        (!actual_type->data.pointer.is_const || expected_type->data.pointer.is_const))
    {
        TypeTableEntry *resolved_type = resolve_type_compatibility(g, context, node,
                expected_type->data.pointer.child_type,
                actual_type->data.pointer.child_type);
        if (resolved_type->id == TypeTableEntryIdInvalid) {
            return resolved_type;
        }
        return expected_type;
    }

    add_node_error(g, first_executing_node(node),
        buf_sprintf("expected type '%s', got '%s'",
            buf_ptr(&expected_type->name),
            buf_ptr(&actual_type->name)));

    return g->builtin_types.entry_invalid;
}

static TypeTableEntry *resolve_peer_type_compatibility(CodeGen *g, BlockContext *block_context,
        AstNode *parent_node,
        AstNode *child1, AstNode *child2,
        TypeTableEntry *type1, TypeTableEntry *type2)
{
    assert(type1);
    assert(type2);

    TypeTableEntry *parent_type = determine_peer_type_compatibility(g, parent_node, type1, type2, child1, child2);

    if (parent_type->id == TypeTableEntryIdInvalid) {
        return parent_type;
    }

    resolve_type_compatibility(g, block_context, child1, parent_type, type1);
    resolve_type_compatibility(g, block_context, child2, parent_type, type2);

    return parent_type;
}

BlockContext *new_block_context(AstNode *node, BlockContext *parent) {
    BlockContext *context = allocate<BlockContext>(1);
    context->node = node;
    context->parent = parent;
    context->variable_table.init(8);
    context->type_table.init(8);

    if (parent) {
        if (parent->next_child_parent_loop_node) {
            context->parent_loop_node = parent->next_child_parent_loop_node;
            parent->next_child_parent_loop_node = nullptr;
        } else {
            context->parent_loop_node = parent->parent_loop_node;
        }
    }

    if (node && node->type == NodeTypeFnDef) {
        AstNode *fn_proto_node = node->data.fn_def.fn_proto;
        context->fn_entry = fn_proto_node->data.fn_proto.fn_table_entry;
    } else if (parent) {
        context->fn_entry = parent->fn_entry;
    }

    if (context->fn_entry) {
        context->fn_entry->all_block_contexts.append(context);
    }

    return context;
}

static VariableTableEntry *find_local_variable(BlockContext *context, Buf *name) {
    while (context && context->fn_entry) {
        auto entry = context->variable_table.maybe_get(name);
        if (entry != nullptr)
            return entry->value;

        context = context->parent;
    }
    return nullptr;
}

VariableTableEntry *find_variable(BlockContext *context, Buf *name) {
    while (context) {
        auto entry = context->variable_table.maybe_get(name);
        if (entry != nullptr)
            return entry->value;

        context = context->parent;
    }
    return nullptr;
}

TypeTableEntry *find_container(BlockContext *context, Buf *name) {
    while (context) {
        auto entry = context->type_table.maybe_get(name);
        if (entry != nullptr)
            return entry->value;

        context = context->parent;
    }
    return nullptr;
}

static TypeEnumField *get_enum_field(TypeTableEntry *enum_type, Buf *name) {
    for (uint32_t i = 0; i < enum_type->data.enumeration.field_count; i += 1) {
        TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[i];
        if (buf_eql_buf(type_enum_field->name, name)) {
            return type_enum_field;
        }
    }
    return nullptr;
}

static TypeStructField *get_struct_field(TypeTableEntry *struct_type, Buf *name) {
    for (uint32_t i = 0; i < struct_type->data.structure.field_count; i += 1) {
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        if (buf_eql_buf(type_struct_field->name, name)) {
            return type_struct_field;
        }
    }
    return nullptr;
}

static TypeTableEntry *analyze_enum_value_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *field_access_node, AstNode *value_node, TypeTableEntry *enum_type, Buf *field_name)
{
    assert(field_access_node->type == NodeTypeFieldAccessExpr);

    TypeEnumField *type_enum_field = get_enum_field(enum_type, field_name);
    field_access_node->data.field_access_expr.type_enum_field = type_enum_field;

    if (type_enum_field) {
        if (value_node) {
            analyze_expression(g, import, context, type_enum_field->type_entry, value_node);

            StructValExprCodeGen *codegen = &field_access_node->data.field_access_expr.resolved_struct_val_expr;
            codegen->type_entry = enum_type;
            codegen->source_node = field_access_node;
            context->struct_val_expr_alloca_list.append(codegen);
        } else if (type_enum_field->type_entry->id != TypeTableEntryIdVoid) {
            add_node_error(g, field_access_node,
                buf_sprintf("enum value '%s.%s' requires parameter of type '%s'",
                    buf_ptr(&enum_type->name),
                    buf_ptr(field_name),
                    buf_ptr(&type_enum_field->type_entry->name)));
        }
    } else {
        add_node_error(g, field_access_node,
            buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name),
                buf_ptr(&enum_type->name)));
    }
    return enum_type;
}

static TypeStructField *find_struct_type_field(TypeTableEntry *type_entry, Buf *name, int *index) {
    assert(type_entry->id == TypeTableEntryIdStruct);
    for (int i = 0; i < type_entry->data.structure.field_count; i += 1) {
        TypeStructField *field = &type_entry->data.structure.fields[i];
        if (buf_eql_buf(field->name, name)) {
            *index = i;
            return field;
        }
    }
    return nullptr;
}

static TypeTableEntry *analyze_container_init_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeContainerInitExpr);

    AstNodeContainerInitExpr *container_init_expr = &node->data.container_init_expr;

    ContainerInitKind kind = container_init_expr->kind;

    TypeTableEntry *container_type = analyze_type_expr(g, import, context, container_init_expr->type);

    if (container_type->id == TypeTableEntryIdInvalid) {
        return container_type;
    } else if (container_type->id == TypeTableEntryIdStruct) {
        switch (kind) {
            case ContainerInitKindStruct:
                {
                    StructValExprCodeGen *codegen = &container_init_expr->resolved_struct_val_expr;
                    codegen->type_entry = container_type;
                    codegen->source_node = node;
                    context->struct_val_expr_alloca_list.append(codegen);


                    int expr_field_count = container_init_expr->entries.length;
                    int actual_field_count = container_type->data.structure.field_count;

                    int *field_use_counts = allocate<int>(actual_field_count);
                    for (int i = 0; i < expr_field_count; i += 1) {
                        AstNode *val_field_node = container_init_expr->entries.at(i);
                        assert(val_field_node->type == NodeTypeStructValueField);

                        int field_index;
                        TypeStructField *type_field = find_struct_type_field(container_type,
                                &val_field_node->data.struct_val_field.name, &field_index);

                        if (!type_field) {
                            add_node_error(g, val_field_node,
                                buf_sprintf("no member named '%s' in '%s'",
                                    buf_ptr(&val_field_node->data.struct_val_field.name), buf_ptr(&container_type->name)));
                            continue;
                        }

                        field_use_counts[field_index] += 1;
                        if (field_use_counts[field_index] > 1) {
                            add_node_error(g, val_field_node, buf_sprintf("duplicate field"));
                            continue;
                        }

                        val_field_node->data.struct_val_field.type_struct_field = type_field;

                        analyze_expression(g, import, context, type_field->type_entry,
                                val_field_node->data.struct_val_field.expr);
                    }

                    for (int i = 0; i < actual_field_count; i += 1) {
                        if (field_use_counts[i] == 0) {
                            add_node_error(g, node,
                                buf_sprintf("missing field: '%s'", buf_ptr(container_type->data.structure.fields[i].name)));
                        }
                    }
                    break;
                }
            case ContainerInitKindArray:
                add_node_error(g, node,
                    buf_sprintf("struct '%s' does not support array initialization syntax",
                        buf_ptr(&container_type->name)));
                break;
        }
        return container_type;
    } else if (container_type->id == TypeTableEntryIdArray) {
        zig_panic("TODO array container init");
        return container_type;
    } else if (container_type->id == TypeTableEntryIdEnum) {
        zig_panic("TODO enum container init");
        return container_type;
    } else if (container_type->id == TypeTableEntryIdVoid) {
        if (container_init_expr->entries.length != 0) {
            add_node_error(g, node, buf_sprintf("void expression expects no arguments"));
            return g->builtin_types.entry_invalid;
        } else {
            return container_type;
        }
    } else if (container_type->id == TypeTableEntryIdUnreachable) {
        if (container_init_expr->entries.length != 0) {
            add_node_error(g, node, buf_sprintf("unreachable expression expects no arguments"));
            return g->builtin_types.entry_invalid;
        } else {
            return container_type;
        }
    } else {
        add_node_error(g, node,
            buf_sprintf("type '%s' does not support initialization syntax", buf_ptr(&container_type->name)));
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *analyze_field_access_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeFieldAccessExpr);

    AstNode *struct_expr_node = node->data.field_access_expr.struct_expr;
    TypeTableEntry *struct_type = analyze_expression(g, import, context, nullptr, struct_expr_node);

    if (struct_type->id == TypeTableEntryIdStruct || (struct_type->id == TypeTableEntryIdPointer &&
         struct_type->data.pointer.child_type->id == TypeTableEntryIdStruct))
    {
        Buf *field_name = &node->data.field_access_expr.field_name;

        TypeTableEntry *bare_struct_type = (struct_type->id == TypeTableEntryIdStruct) ?
            struct_type : struct_type->data.pointer.child_type;

        node->data.field_access_expr.type_struct_field = get_struct_field(bare_struct_type, field_name);
        if (node->data.field_access_expr.type_struct_field) {
            return node->data.field_access_expr.type_struct_field->type_entry;
        } else {
            add_node_error(g, node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name), buf_ptr(&struct_type->name)));
            return g->builtin_types.entry_invalid;
        }
    } else if (struct_type->id == TypeTableEntryIdArray) {
        Buf *name = &node->data.field_access_expr.field_name;
        if (buf_eql_str(name, "len")) {
            return g->builtin_types.entry_usize;
        } else if (buf_eql_str(name, "ptr")) {
            // TODO determine whether the pointer should be const
            return get_pointer_to_type(g, struct_type->data.array.child_type, false);
        } else {
            add_node_error(g, node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(name),
                    buf_ptr(&struct_type->name)));
            return g->builtin_types.entry_invalid;
        }
    } else if (struct_type->id == TypeTableEntryIdMetaType) {
        TypeTableEntry *enum_type = resolve_type(g, struct_expr_node);

        if (enum_type->id == TypeTableEntryIdInvalid) {
            return g->builtin_types.entry_invalid;
        } else if (enum_type->id == TypeTableEntryIdEnum) {
            Buf *field_name = &node->data.field_access_expr.field_name;
            return analyze_enum_value_expr(g, import, context, node, nullptr, enum_type, field_name);
        } else {
            add_node_error(g, node,
                buf_sprintf("type '%s' does not support field access", buf_ptr(&struct_type->name)));
            return g->builtin_types.entry_invalid;
        }
    } else {
        if (struct_type->id != TypeTableEntryIdInvalid) {
            add_node_error(g, node,
                buf_sprintf("type '%s' does not support field access", buf_ptr(&struct_type->name)));
        }
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *analyze_slice_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeSliceExpr);

    TypeTableEntry *array_type = analyze_expression(g, import, context, nullptr,
            node->data.slice_expr.array_ref_expr);

    TypeTableEntry *return_type;

    if (array_type->id == TypeTableEntryIdInvalid) {
        return_type = g->builtin_types.entry_invalid;
    } else if (array_type->id == TypeTableEntryIdArray) {
        return_type = get_unknown_size_array_type(g, import, array_type->data.array.child_type,
                node->data.slice_expr.is_const);
    } else if (array_type->id == TypeTableEntryIdPointer) {
        return_type = get_unknown_size_array_type(g, import, array_type->data.pointer.child_type,
                node->data.slice_expr.is_const);
    } else if (array_type->id == TypeTableEntryIdStruct &&
               array_type->data.structure.is_unknown_size_array)
    {
        return_type = get_unknown_size_array_type(g, import,
                array_type->data.structure.fields[0].type_entry->data.pointer.child_type,
                node->data.slice_expr.is_const);
    } else {
        add_node_error(g, node,
            buf_sprintf("slice of non-array type '%s'", buf_ptr(&array_type->name)));
        return_type = g->builtin_types.entry_invalid;
    }

    if (return_type->id != TypeTableEntryIdInvalid) {
        node->data.slice_expr.resolved_struct_val_expr.type_entry = return_type;
        node->data.slice_expr.resolved_struct_val_expr.source_node = node;
        context->struct_val_expr_alloca_list.append(&node->data.slice_expr.resolved_struct_val_expr);
    }

    analyze_expression(g, import, context, g->builtin_types.entry_usize, node->data.slice_expr.start);

    if (node->data.slice_expr.end) {
        analyze_expression(g, import, context, g->builtin_types.entry_usize, node->data.slice_expr.end);
    }

    return return_type;
}

static TypeTableEntry *analyze_array_access_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    TypeTableEntry *array_type = analyze_expression(g, import, context, nullptr,
            node->data.array_access_expr.array_ref_expr);

    TypeTableEntry *return_type;

    if (array_type->id == TypeTableEntryIdInvalid) {
        return_type = g->builtin_types.entry_invalid;
    } else if (array_type->id == TypeTableEntryIdArray) {
        return_type = array_type->data.array.child_type;
    } else if (array_type->id == TypeTableEntryIdPointer) {
        return_type = array_type->data.pointer.child_type;
    } else if (array_type->id == TypeTableEntryIdStruct &&
               array_type->data.structure.is_unknown_size_array)
    {
        return_type = array_type->data.structure.fields[0].type_entry->data.pointer.child_type;
    } else {
        add_node_error(g, node,
                buf_sprintf("array access of non-array type '%s'", buf_ptr(&array_type->name)));
        return_type = g->builtin_types.entry_invalid;
    }

    analyze_expression(g, import, context, g->builtin_types.entry_usize, node->data.array_access_expr.subscript);

    return return_type;
}

static TypeTableEntry *resolve_expr_const_val_as_type(CodeGen *g, AstNode *node, TypeTableEntry *type) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_type = type;
    return g->builtin_types.entry_type;
}

static TypeTableEntry *resolve_expr_const_val_as_other_expr(CodeGen *g, AstNode *node, AstNode *other) {
    Expr *expr = get_resolved_expr(node);
    Expr *other_expr = get_resolved_expr(other);
    expr->const_val = other_expr->const_val;
    return other_expr->type_entry;
}

static TypeTableEntry *resolve_expr_const_val_as_fn(CodeGen *g, AstNode *node, FnTableEntry *fn) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_fn = fn;
    return fn->type_entry;
}

static TypeTableEntry *resolve_expr_const_val_as_bool(CodeGen *g, AstNode *node, bool value) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_bool = value;
    return g->builtin_types.entry_bool;
}

static TypeTableEntry *resolve_expr_const_val_as_null(CodeGen *g, AstNode *node, TypeTableEntry *type) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_maybe = nullptr;
    return type;
}

static TypeTableEntry *resolve_expr_const_val_as_unsigned_num_lit(CodeGen *g, AstNode *node,
        TypeTableEntry *expected_type, uint64_t x)
{
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_uint = x;
    TypeTableEntry *num_lit_type = get_number_literal_type_unsigned(g, x);
    TypeTableEntry *resolved_type = resolve_rhs_number_literal(g, nullptr, expected_type, node, num_lit_type);
    return resolved_type ? resolved_type : num_lit_type;
}

static TypeTableEntry *analyze_symbol_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    Buf *variable_name = &node->data.symbol_expr.symbol;

    auto primitive_table_entry = g->primitive_type_table.maybe_get(variable_name);
    if (primitive_table_entry) {
        return resolve_expr_const_val_as_type(g, node, primitive_table_entry->value);
    }

    VariableTableEntry *var = find_variable(context, variable_name);
    if (var) {
        node->data.symbol_expr.variable = var;
        if (var->is_const) {
            AstNode *decl_node = var->decl_node;
            if (decl_node->type == NodeTypeVariableDeclaration) {
                AstNode *expr_node = decl_node->data.variable_declaration.expr;
                ConstExprValue *const_val = &get_resolved_expr(expr_node)->const_val;
                if (const_val->ok) {
                    return resolve_expr_const_val_as_other_expr(g, node, expr_node);
                }
            }
        }
        return var->type;
    }

    TypeTableEntry *container_type = find_container(context, variable_name);
    if (container_type) {
        return resolve_expr_const_val_as_type(g, node, container_type);
    }

    auto fn_table_entry = import->fn_table.maybe_get(variable_name);
    if (fn_table_entry) {
        return resolve_expr_const_val_as_fn(g, node, fn_table_entry->value);
    }

    add_node_error(g, node, buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
    return g->builtin_types.entry_invalid;
}

static TypeTableEntry *analyze_variable_name(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node, Buf *variable_name)
{
    VariableTableEntry *var = find_variable(context, variable_name);
    if (var) {
        return var->type;
    } else {
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
            return type->id == TypeTableEntryIdInt || type->id == TypeTableEntryIdFloat;
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignMinus:
            return type->id == TypeTableEntryIdInt ||
                   type->id == TypeTableEntryIdFloat ||
                   type->id == TypeTableEntryIdPointer;
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
        case BinOpTypeUnwrapMaybe:
            zig_unreachable();
    }
    zig_unreachable();
}

enum LValPurpose {
    LValPurposeAssign,
    LValPurposeAddressOf,
};

static TypeTableEntry *analyze_lvalue(CodeGen *g, ImportTableEntry *import, BlockContext *block_context,
        AstNode *lhs_node, LValPurpose purpose, bool is_ptr_const)
{
    TypeTableEntry *expected_rhs_type = nullptr;
    if (lhs_node->type == NodeTypeSymbol) {
        Buf *name = &lhs_node->data.symbol_expr.symbol;
        if (purpose == LValPurposeAddressOf) {
            expected_rhs_type = analyze_symbol_expr(g, import, block_context, nullptr, lhs_node);
        } else {
            VariableTableEntry *var = find_variable(block_context, name);
            if (var) {
                if (var->is_const) {
                    add_node_error(g, lhs_node, buf_sprintf("cannot assign to constant"));
                    expected_rhs_type = g->builtin_types.entry_invalid;
                } else {
                    expected_rhs_type = var->type;
                }
            } else {
                add_node_error(g, lhs_node,
                        buf_sprintf("use of undeclared identifier '%s'", buf_ptr(name)));
                expected_rhs_type = g->builtin_types.entry_invalid;
            }
        }
    } else if (lhs_node->type == NodeTypeArrayAccessExpr) {
        expected_rhs_type = analyze_array_access_expr(g, import, block_context, lhs_node);
    } else if (lhs_node->type == NodeTypeFieldAccessExpr) {
        expected_rhs_type = analyze_field_access_expr(g, import, block_context, lhs_node);
    } else if (lhs_node->type == NodeTypePrefixOpExpr &&
            lhs_node->data.prefix_op_expr.prefix_op == PrefixOpDereference)
    {
        assert(purpose == LValPurposeAssign);
        AstNode *target_node = lhs_node->data.prefix_op_expr.primary_expr;
        TypeTableEntry *type_entry = analyze_expression(g, import, block_context, nullptr, target_node);
        if (type_entry->id == TypeTableEntryIdInvalid) {
            expected_rhs_type = type_entry;
        } else if (type_entry->id == TypeTableEntryIdPointer) {
            expected_rhs_type = type_entry->data.pointer.child_type;
        } else {
            add_node_error(g, target_node,
                buf_sprintf("indirection requires pointer operand ('%s' invalid)",
                    buf_ptr(&type_entry->name)));
            expected_rhs_type = g->builtin_types.entry_invalid;
        }
    } else {
        if (purpose == LValPurposeAssign) {
            add_node_error(g, lhs_node, buf_sprintf("invalid assignment target"));
            expected_rhs_type = g->builtin_types.entry_invalid;
        } else if (purpose == LValPurposeAddressOf) {
            TypeTableEntry *type_entry = analyze_expression(g, import, block_context, nullptr, lhs_node);
            if (type_entry->id == TypeTableEntryIdInvalid) {
                expected_rhs_type = g->builtin_types.entry_invalid;
            } else if (type_entry->id == TypeTableEntryIdMetaType) {
                expected_rhs_type = type_entry;
            } else {
                add_node_error(g, lhs_node, buf_sprintf("invalid addressof target"));
                expected_rhs_type = g->builtin_types.entry_invalid;
            }
        }
    }
    assert(expected_rhs_type);
    return expected_rhs_type;
}

static bool eval_bool_bin_op_bool(bool a, BinOpType bin_op, bool b) {
    if (bin_op == BinOpTypeBoolOr) {
        return a || b;
    } else if (bin_op == BinOpTypeBoolAnd) {
        return a && b;
    } else {
        zig_unreachable();
    }
}

static bool eval_bool_bin_op_signed(int64_t a, BinOpType bin_op, int64_t b) {
    if (bin_op == BinOpTypeCmpEq) {
        return a == b;
    } else if (bin_op == BinOpTypeCmpNotEq) {
        return a != b;
    } else if (bin_op == BinOpTypeCmpLessThan) {
        return a < b;
    } else if (bin_op == BinOpTypeCmpGreaterThan) {
        return a > b;
    } else if (bin_op == BinOpTypeCmpLessOrEq) {
        return a <= b;
    } else if (bin_op == BinOpTypeCmpGreaterOrEq) {
        return a >= b;
    } else {
        zig_unreachable();
    }
}

static bool eval_bool_bin_op_unsigned(uint64_t a, BinOpType bin_op, uint64_t b) {
    if (bin_op == BinOpTypeCmpEq) {
        return a == b;
    } else if (bin_op == BinOpTypeCmpNotEq) {
        return a != b;
    } else if (bin_op == BinOpTypeCmpLessThan) {
        return a < b;
    } else if (bin_op == BinOpTypeCmpGreaterThan) {
        return a > b;
    } else if (bin_op == BinOpTypeCmpLessOrEq) {
        return a <= b;
    } else if (bin_op == BinOpTypeCmpGreaterOrEq) {
        return a >= b;
    } else {
        zig_unreachable();
    }
}

static bool eval_bool_bin_op_float(double a, BinOpType bin_op, double b) {
    if (bin_op == BinOpTypeCmpEq) {
        return a == b;
    } else if (bin_op == BinOpTypeCmpNotEq) {
        return a != b;
    } else if (bin_op == BinOpTypeCmpLessThan) {
        return a < b;
    } else if (bin_op == BinOpTypeCmpGreaterThan) {
        return a > b;
    } else if (bin_op == BinOpTypeCmpLessOrEq) {
        return a <= b;
    } else if (bin_op == BinOpTypeCmpGreaterOrEq) {
        return a >= b;
    } else {
        zig_unreachable();
    }
}

static TypeTableEntry *analyze_bool_bin_op_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeBinOpExpr);
    BinOpType bin_op_type = node->data.bin_op_expr.bin_op;

    AstNode *op1 = node->data.bin_op_expr.op1;
    AstNode *op2 = node->data.bin_op_expr.op2;
    TypeTableEntry *op1_type = analyze_expression(g, import, context, nullptr, op1);
    TypeTableEntry *op2_type = analyze_expression(g, import, context, nullptr, op2);

    TypeTableEntry *resolved_type = resolve_peer_type_compatibility(g, context, node,
            op1, op2, op1_type, op2_type);

    if (resolved_type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *op1_val = &get_resolved_expr(op1)->const_val;
    ConstExprValue *op2_val = &get_resolved_expr(op2)->const_val;
    if (!op1_val->ok || !op2_val->ok) {
        return g->builtin_types.entry_bool;
    }

    bool answer;
    if (resolved_type->id == TypeTableEntryIdInt) {
        if (op1_type->data.integral.is_signed &&
            op2_type->data.integral.is_signed)
        {
            answer = eval_bool_bin_op_signed(op1_val->data.x_int, bin_op_type, op2_val->data.x_int);
        } else if (!op1_type->data.integral.is_signed &&
                   !op2_type->data.integral.is_signed)
        {
            answer = eval_bool_bin_op_unsigned(op1_val->data.x_uint, bin_op_type, op2_val->data.x_uint);
        } else {
            zig_unreachable();
        }
    } else if (resolved_type->id == TypeTableEntryIdFloat) {
        answer = eval_bool_bin_op_float(op1_val->data.x_float, bin_op_type, op2_val->data.x_float);
    } else {
        zig_unreachable();
    }

    return resolve_expr_const_val_as_bool(g, node, answer);
}

static TypeTableEntry *analyze_logic_bin_op_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeBinOpExpr);
    BinOpType bin_op_type = node->data.bin_op_expr.bin_op;

    AstNode *op1 = node->data.bin_op_expr.op1;
    AstNode *op2 = node->data.bin_op_expr.op2;
    TypeTableEntry *op1_type = analyze_expression(g, import, context, g->builtin_types.entry_bool, op1);
    TypeTableEntry *op2_type = analyze_expression(g, import, context, g->builtin_types.entry_bool, op2);

    if (op1_type->id == TypeTableEntryIdInvalid ||
        op2_type->id == TypeTableEntryIdInvalid)
    {
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *op1_val = &get_resolved_expr(op1)->const_val;
    ConstExprValue *op2_val = &get_resolved_expr(op2)->const_val;
    if (!op1_val->ok || !op2_val->ok) {
        return g->builtin_types.entry_bool;
    }

    bool answer = eval_bool_bin_op_bool(op1_val->data.x_bool, bin_op_type, op2_val->data.x_bool);
    return resolve_expr_const_val_as_bool(g, node, answer);
}

static TypeTableEntry *analyze_bin_op_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    BinOpType bin_op_type = node->data.bin_op_expr.bin_op;
    switch (bin_op_type) {
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

                TypeTableEntry *expected_rhs_type = analyze_lvalue(g, import, context, lhs_node,
                        LValPurposeAssign, false);
                if (!is_op_allowed(expected_rhs_type, node->data.bin_op_expr.bin_op)) {
                    if (expected_rhs_type->id != TypeTableEntryIdInvalid) {
                        add_node_error(g, lhs_node,
                            buf_sprintf("operator not allowed for type '%s'",
                                buf_ptr(&expected_rhs_type->name)));
                    }
                }

                analyze_expression(g, import, context, expected_rhs_type, node->data.bin_op_expr.op2);
                return g->builtin_types.entry_void;
            }
        case BinOpTypeBoolOr:
        case BinOpTypeBoolAnd:
            return analyze_logic_bin_op_expr(g, import, context, node);
        case BinOpTypeCmpEq:
        case BinOpTypeCmpNotEq:
        case BinOpTypeCmpLessThan:
        case BinOpTypeCmpGreaterThan:
        case BinOpTypeCmpLessOrEq:
        case BinOpTypeCmpGreaterOrEq:
            return analyze_bool_bin_op_expr(g, import, context, node);
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
            {
                AstNode *op1 = node->data.bin_op_expr.op1;
                AstNode *op2 = node->data.bin_op_expr.op2;
                TypeTableEntry *lhs_type = analyze_expression(g, import, context, expected_type, op1);
                TypeTableEntry *rhs_type = analyze_expression(g, import, context, expected_type, op2);

                return resolve_peer_type_compatibility(g, context, node, op1, op2, lhs_type, rhs_type);
            }
        case BinOpTypeUnwrapMaybe:
            {
                AstNode *op1 = node->data.bin_op_expr.op1;
                AstNode *op2 = node->data.bin_op_expr.op2;
                TypeTableEntry *lhs_type = analyze_expression(g, import, context, nullptr, op1);

                if (lhs_type->id == TypeTableEntryIdInvalid) {
                    return lhs_type;
                } else if (lhs_type->id == TypeTableEntryIdMaybe) {
                    TypeTableEntry *child_type = lhs_type->data.maybe.child_type;
                    analyze_expression(g, import, context, child_type, op2);
                    return child_type;
                } else {
                    add_node_error(g, op1,
                        buf_sprintf("expected maybe type, got '%s'",
                            buf_ptr(&lhs_type->name)));
                }
            }
        case BinOpTypeInvalid:
            zig_unreachable();
    }
    zig_unreachable();
}

static VariableTableEntry *analyze_variable_declaration_raw(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *source_node,
        AstNodeVariableDeclaration *variable_declaration,
        bool expr_is_maybe)
{
    TypeTableEntry *explicit_type = nullptr;
    if (variable_declaration->type != nullptr) {
        explicit_type = analyze_type_expr(g, import, context, variable_declaration->type);
        if (explicit_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, variable_declaration->type,
                buf_sprintf("variable of type 'unreachable' not allowed"));
            explicit_type = g->builtin_types.entry_invalid;
        }
    }

    TypeTableEntry *implicit_type = nullptr;
    if (variable_declaration->expr != nullptr) {
        implicit_type = analyze_expression(g, import, context, explicit_type, variable_declaration->expr);
        if (implicit_type->id == TypeTableEntryIdInvalid) {
            // ignore the poison value
        } else if (expr_is_maybe) {
            if (implicit_type->id == TypeTableEntryIdMaybe) {
                implicit_type = implicit_type->data.maybe.child_type;
            } else {
                add_node_error(g, variable_declaration->expr, buf_sprintf("expected maybe type"));
                implicit_type = g->builtin_types.entry_invalid;
            }
        } else if (implicit_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, source_node,
                buf_sprintf("variable initialization is unreachable"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if (implicit_type->id == TypeTableEntryIdNumberLiteral) {
            add_node_error(g, source_node,
                buf_sprintf("unable to infer variable type"));
            implicit_type = g->builtin_types.entry_invalid;
        }
    }

    if (implicit_type == nullptr && variable_declaration->is_const) {
        add_node_error(g, source_node, buf_sprintf("const variable missing initialization"));
        implicit_type = g->builtin_types.entry_invalid;
    }

    TypeTableEntry *type = explicit_type != nullptr ? explicit_type : implicit_type;
    assert(type != nullptr); // should have been caught by the parser

    VariableTableEntry *existing_variable = find_local_variable(context, &variable_declaration->symbol);
    if (existing_variable) {
        add_node_error(g, source_node,
            buf_sprintf("redeclaration of variable '%s'", buf_ptr(&variable_declaration->symbol)));
    } else {
        VariableTableEntry *variable_entry = allocate<VariableTableEntry>(1);
        buf_init_from_buf(&variable_entry->name, &variable_declaration->symbol);
        variable_entry->type = type;
        variable_entry->is_const = variable_declaration->is_const;
        variable_entry->is_ptr = true;
        variable_entry->decl_node = source_node;
        context->variable_table.put(&variable_entry->name, variable_entry);

        bool is_pub = (variable_declaration->visib_mod != VisibModPrivate);
        if (is_pub) {
            for (int i = 0; i < import->importers.length; i += 1) {
                ImporterInfo importer = import->importers.at(i);
                auto table_entry = importer.import->block_context->variable_table.maybe_get(&variable_entry->name);
                if (table_entry) {
                    add_node_error(g, importer.source_node,
                        buf_sprintf("import of variable '%s' overrides existing definition",
                            buf_ptr(&variable_entry->name)));
                } else {
                    importer.import->block_context->variable_table.put(&variable_entry->name, variable_entry);
                }
            }
        }


        return variable_entry;
    }
    return nullptr;
}

static VariableTableEntry *analyze_variable_declaration(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, TypeTableEntry *expected_type, AstNode *node)
{
    AstNodeVariableDeclaration *variable_declaration = &node->data.variable_declaration;
    return analyze_variable_declaration_raw(g, import, context, node, variable_declaration, false);
}

static TypeTableEntry *analyze_null_literal_expr(CodeGen *g, ImportTableEntry *import,
        BlockContext *block_context, TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeNullLiteral);

    if (!expected_type) {
        add_node_error(g, node,
                buf_sprintf("unable to determine null type"));
        return g->builtin_types.entry_invalid;
    }

    assert(expected_type->id == TypeTableEntryIdMaybe);

    node->data.null_literal.resolved_struct_val_expr.type_entry = expected_type;
    node->data.null_literal.resolved_struct_val_expr.source_node = node;
    block_context->struct_val_expr_alloca_list.append(&node->data.null_literal.resolved_struct_val_expr);

    return resolve_expr_const_val_as_null(g, node, expected_type);
}

static TypeTableEntry *analyze_number_literal_expr(CodeGen *g, ImportTableEntry *import,
        BlockContext *block_context, TypeTableEntry *expected_type, AstNode *node)
{
    if (node->data.number_literal.overflow) {
        add_node_error(g, node, buf_sprintf("number literal too large to be represented in any type"));
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
    const_val->ok = true;
    if (is_num_lit_unsigned(node->data.number_literal.kind)) {
        const_val->data.x_uint = node->data.number_literal.data.x_uint;
    } else if (is_num_lit_float(node->data.number_literal.kind)) {
        const_val->data.x_float = node->data.number_literal.data.x_float;
    } else {
        zig_unreachable();
    }

    TypeTableEntry *num_lit_type = g->num_lit_types[node->data.number_literal.kind];
    if (expected_type) {
        NumLitCodeGen *codegen_num_lit = get_resolved_num_lit(node);
        assert(!codegen_num_lit->resolved_type);
        TypeTableEntry *after_implicit_cast_resolved_type =
            resolve_type_compatibility(g, block_context, node, expected_type, num_lit_type);
        assert(codegen_num_lit->resolved_type ||
                after_implicit_cast_resolved_type->id == TypeTableEntryIdInvalid);
        return after_implicit_cast_resolved_type;
    } else {
        return num_lit_type;
    }
}

static TypeTableEntry *analyze_array_type(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    AstNode *size_node = node->data.array_type.size;

    TypeTableEntry *child_type = analyze_type_expr(g, import, context, node->data.array_type.child_type);

    if (child_type->id == TypeTableEntryIdUnreachable) {
        add_node_error(g, node, buf_create_from_str("array of unreachable not allowed"));
        return g->builtin_types.entry_invalid;
    } else if (child_type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    }

    if (size_node) {
        TypeTableEntry *size_type = analyze_expression(g, import, context,
                g->builtin_types.entry_usize, size_node);
        if (size_type->id == TypeTableEntryIdInvalid) {
            return g->builtin_types.entry_invalid;
        }

        ConstExprValue *const_val = &get_resolved_expr(size_node)->const_val;
        if (const_val->ok) {
            return resolve_expr_const_val_as_type(g, node,
                    get_array_type(g, import, child_type, const_val->data.x_uint));
        } else {
            add_node_error(g, size_node, buf_create_from_str("unable to resolve constant expression"));
            return g->builtin_types.entry_invalid;
        }
    } else {
        return resolve_expr_const_val_as_type(g, node,
                get_unknown_size_array_type(g, import, child_type, node->data.array_type.is_const));
    }
}

static TypeTableEntry *analyze_while_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeWhileExpr);

    AstNode *condition_node = node->data.while_expr.condition;
    AstNode *while_body_node = node->data.while_expr.body;
    TypeTableEntry *condition_type = analyze_expression(g, import, context,
            g->builtin_types.entry_bool, condition_node);

    context->next_child_parent_loop_node = node;
    analyze_expression(g, import, context, g->builtin_types.entry_void, while_body_node);


    TypeTableEntry *expr_return_type = g->builtin_types.entry_void;

    if (condition_type->id == TypeTableEntryIdInvalid) {
        expr_return_type = g->builtin_types.entry_invalid;
    } else {
        // if the condition is a simple constant expression and there are no break statements
        // then the return type is unreachable
        ConstExprValue *const_val = &get_resolved_expr(condition_node)->const_val;
        if (const_val->ok) {
            if (const_val->data.x_bool) {
                node->data.while_expr.condition_always_true = true;
                if (!node->data.while_expr.contains_break) {
                    expr_return_type = g->builtin_types.entry_unreachable;
                }
            }
        }
    }

    return expr_return_type;
}

static TypeTableEntry *analyze_break_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeBreak);

    AstNode *loop_node = context->parent_loop_node;
    if (loop_node) {
        assert(loop_node->type == NodeTypeWhileExpr);
        loop_node->data.while_expr.contains_break = true;
    } else {
        add_node_error(g, node, buf_sprintf("'break' expression outside loop"));
    }
    return g->builtin_types.entry_unreachable;
}

static TypeTableEntry *analyze_continue_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    if (!context->parent_loop_node) {
        add_node_error(g, node, buf_sprintf("'continue' expression outside loop"));
    }
    return g->builtin_types.entry_unreachable;
}

static TypeTableEntry *analyze_if_then_else(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *then_block, AstNode *else_node, AstNode *parent_node)
{
    TypeTableEntry *then_type = analyze_expression(g, import, context, expected_type, then_block);

    TypeTableEntry *else_type;
    if (else_node) {
        else_type = analyze_expression(g, import, context, expected_type, else_node);
    } else {
        else_type = g->builtin_types.entry_void;
        else_type = resolve_type_compatibility(g, context, parent_node, expected_type, else_type);
    }


    if (expected_type) {
        return (then_type->id == TypeTableEntryIdUnreachable) ? else_type : then_type;
    } else {
        return resolve_peer_type_compatibility(g, context, parent_node,
                then_block, else_node,
                then_type, else_type);
    }
}

static TypeTableEntry *analyze_if_bool_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    analyze_expression(g, import, context, g->builtin_types.entry_bool, node->data.if_bool_expr.condition);

    return analyze_if_then_else(g, import, context, expected_type,
            node->data.if_bool_expr.then_block,
            node->data.if_bool_expr.else_node,
            node);
}

static TypeTableEntry *analyze_if_var_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeIfVarExpr);

    BlockContext *child_context = new_block_context(node, context);
    node->data.if_var_expr.block_context = child_context;

    analyze_variable_declaration_raw(g, import, child_context, node, &node->data.if_var_expr.var_decl, true);

    return analyze_if_then_else(g, import, child_context, expected_type,
            node->data.if_var_expr.then_block, node->data.if_var_expr.else_node, node);
}

static TypeTableEntry *analyze_min_max_value(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node, const char *err_format, bool is_max)
{
    assert(node->type == NodeTypeFnCallExpr);
    assert(node->data.fn_call_expr.params.length == 1);

    AstNode *type_node = node->data.fn_call_expr.params.at(0);
    TypeTableEntry *type_entry = analyze_type_expr(g, import, context, type_node);
    if (type_entry->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    } else if (type_entry->id == TypeTableEntryIdInt) {
        // TODO const expr eval for min/max int
        return type_entry;
    } else if (type_entry->id == TypeTableEntryIdFloat) {
        // TODO const expr eval for min/max float
        return type_entry;
    } else if (type_entry->id == TypeTableEntryIdBool) {
        return resolve_expr_const_val_as_bool(g, node, is_max);
    } else {
        add_node_error(g, node,
                buf_sprintf(err_format, buf_ptr(&type_entry->name)));
        return g->builtin_types.entry_invalid;
    }
}

static void eval_const_expr_implicit_cast(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node, Cast *cast, AstNode *expr_node)
{
    switch (cast->op) {
        case CastOpNothing:
        case CastOpPtrToInt:
        case CastOpIntWidenOrShorten:
        case CastOpPointerReinterpret:
            {
                ConstExprValue *other_val = &get_resolved_expr(expr_node)->const_val;
                ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
                if (other_val != const_val) {
                    *const_val = *other_val;
                }
                break;
            }
        case CastOpToUnknownSizeArray:
            // TODO eval const expr
            break;
        case CastOpMaybeWrap:
            {
                ConstExprValue *other_val = &get_resolved_expr(expr_node)->const_val;
                ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
                if (!other_val->ok) {
                    break;
                } else if (const_val == other_val) {
                    ConstExprValue *new_val = allocate<ConstExprValue>(1);
                    memcpy(new_val, other_val, sizeof(ConstExprValue));
                    other_val = new_val;
                }

                const_val->data.x_maybe = other_val;
                const_val->ok = true;
                break;
            }
    }
}

static TypeTableEntry *analyze_cast_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
    int actual_param_count = node->data.fn_call_expr.params.length;

    if (actual_param_count != 1) {
        add_node_error(g, fn_ref_expr, buf_sprintf("cast expression expects exactly one parameter"));
        return g->builtin_types.entry_invalid;
    }

    AstNode *expr_node = node->data.fn_call_expr.params.at(0);
    TypeTableEntry *wanted_type = resolve_type(g, fn_ref_expr);
    TypeTableEntry *actual_type = analyze_expression(g, import, context, nullptr, expr_node);

    if (wanted_type->id == TypeTableEntryIdInvalid ||
        actual_type->id == TypeTableEntryIdInvalid)
    {
        return g->builtin_types.entry_invalid;
    }

    Cast *cast = &node->data.fn_call_expr.cast;
    cast->source_node = node;
    cast->after_type = wanted_type;

    if ((wanted_type == g->builtin_types.entry_isize || wanted_type == g->builtin_types.entry_usize) &&
        actual_type->id == TypeTableEntryIdPointer)
    {
        cast->op = CastOpPtrToInt;
        eval_const_expr_implicit_cast(g, import, context, node, cast, expr_node);
        return wanted_type;
    } else if (wanted_type->id == TypeTableEntryIdInt &&
                actual_type->id == TypeTableEntryIdInt)
    {
        cast->op = CastOpIntWidenOrShorten;
        eval_const_expr_implicit_cast(g, import, context, node, cast, expr_node);
        return wanted_type;
    } else if (wanted_type->id == TypeTableEntryIdStruct &&
               wanted_type->data.structure.is_unknown_size_array &&
               actual_type->id == TypeTableEntryIdArray &&
               actual_type->data.array.child_type == wanted_type->data.structure.fields[0].type_entry)
    {
        cast->op = CastOpToUnknownSizeArray;
        context->cast_expr_alloca_list.append(cast);
        eval_const_expr_implicit_cast(g, import, context, node, cast, expr_node);
        return wanted_type;
    } else if (actual_type->id == TypeTableEntryIdNumberLiteral &&
               num_lit_fits_in_other_type(g, actual_type, wanted_type))
    {
        NumLitCodeGen *codegen_num_lit = get_resolved_num_lit(expr_node);
        assert(!codegen_num_lit->resolved_type);
        codegen_num_lit->resolved_type = wanted_type;
        cast->op = CastOpNothing;
        eval_const_expr_implicit_cast(g, import, context, node, cast, expr_node);
        return wanted_type;
    } else if (actual_type->id == TypeTableEntryIdPointer &&
               wanted_type->id == TypeTableEntryIdPointer)
    {
        cast->op = CastOpPointerReinterpret;
        eval_const_expr_implicit_cast(g, import, context, node, cast, expr_node);
        return wanted_type;
    } else {
        add_node_error(g, node,
            buf_sprintf("invalid cast from type '%s' to '%s'",
                buf_ptr(&actual_type->name),
                buf_ptr(&wanted_type->name)));
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *analyze_builtin_fn_call_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
    Buf *name = &fn_ref_expr->data.symbol_expr.symbol;

    auto entry = g->builtin_fn_table.maybe_get(name);

    if (!entry) {
        add_node_error(g, node,
                buf_sprintf("invalid builtin function: '%s'", buf_ptr(name)));
        return g->builtin_types.entry_invalid;
    }

    BuiltinFnEntry *builtin_fn = entry->value;
    int actual_param_count = node->data.fn_call_expr.params.length;

    node->data.fn_call_expr.builtin_fn = builtin_fn;

    if (builtin_fn->param_count != actual_param_count) {
        add_node_error(g, node,
                buf_sprintf("expected %d arguments, got %d",
                    builtin_fn->param_count, actual_param_count));
        return g->builtin_types.entry_invalid;
    }

    switch (builtin_fn->id) {
        case BuiltinFnIdInvalid:
            zig_unreachable();
        case BuiltinFnIdAddWithOverflow:
        case BuiltinFnIdSubWithOverflow:
        case BuiltinFnIdMulWithOverflow:
            {
                AstNode *type_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *int_type = analyze_type_expr(g, import, context, type_node);
                if (int_type->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_bool;
                } else if (int_type->id == TypeTableEntryIdInt) {
                    AstNode *op1_node = node->data.fn_call_expr.params.at(1);
                    AstNode *op2_node = node->data.fn_call_expr.params.at(2);
                    AstNode *result_node = node->data.fn_call_expr.params.at(3);

                    analyze_expression(g, import, context, int_type, op1_node);
                    analyze_expression(g, import, context, int_type, op2_node);
                    analyze_expression(g, import, context, get_pointer_to_type(g, int_type, false),
                            result_node);
                } else {
                    add_node_error(g, type_node,
                        buf_sprintf("expected integer type, got '%s'", buf_ptr(&int_type->name)));
                }

                // TODO constant expression evaluation

                return g->builtin_types.entry_bool;
            }
        case BuiltinFnIdMemcpy:
            {
                AstNode *dest_node = node->data.fn_call_expr.params.at(0);
                AstNode *src_node = node->data.fn_call_expr.params.at(1);
                AstNode *len_node = node->data.fn_call_expr.params.at(2);
                TypeTableEntry *dest_type = analyze_expression(g, import, context, nullptr, dest_node);
                TypeTableEntry *src_type = analyze_expression(g, import, context, nullptr, src_node);
                analyze_expression(g, import, context, builtin_fn->param_types[2], len_node);

                if (dest_type->id != TypeTableEntryIdInvalid &&
                    dest_type->id != TypeTableEntryIdPointer)
                {
                    add_node_error(g, dest_node,
                            buf_sprintf("expected pointer argument, got '%s'", buf_ptr(&dest_type->name)));
                }

                if (src_type->id != TypeTableEntryIdInvalid &&
                    src_type->id != TypeTableEntryIdPointer)
                {
                    add_node_error(g, src_node,
                            buf_sprintf("expected pointer argument, got '%s'", buf_ptr(&src_type->name)));
                }

                if (dest_type->id == TypeTableEntryIdPointer &&
                    src_type->id == TypeTableEntryIdPointer)
                {
                    uint64_t dest_align_bits = dest_type->data.pointer.child_type->align_in_bits;
                    uint64_t src_align_bits = src_type->data.pointer.child_type->align_in_bits;
                    if (dest_align_bits != src_align_bits) {
                        add_node_error(g, dest_node, buf_sprintf(
                            "misaligned memcpy, '%s' has alignment '%" PRIu64 ", '%s' has alignment %" PRIu64,
                                    buf_ptr(&dest_type->name), dest_align_bits / 8,
                                    buf_ptr(&src_type->name), src_align_bits / 8));
                    }
                }

                return builtin_fn->return_type;
            }
        case BuiltinFnIdMemset:
            {
                AstNode *dest_node = node->data.fn_call_expr.params.at(0);
                AstNode *char_node = node->data.fn_call_expr.params.at(1);
                AstNode *len_node = node->data.fn_call_expr.params.at(2);
                TypeTableEntry *dest_type = analyze_expression(g, import, context, nullptr, dest_node);
                analyze_expression(g, import, context, builtin_fn->param_types[1], char_node);
                analyze_expression(g, import, context, builtin_fn->param_types[2], len_node);

                if (dest_type->id != TypeTableEntryIdInvalid &&
                    dest_type->id != TypeTableEntryIdPointer)
                {
                    add_node_error(g, dest_node,
                            buf_sprintf("expected pointer argument, got '%s'", buf_ptr(&dest_type->name)));
                }

                return builtin_fn->return_type;
            }
        case BuiltinFnIdSizeof:
            {
                AstNode *type_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *type_entry = analyze_type_expr(g, import, context, type_node);
                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else if (type_entry->id == TypeTableEntryIdUnreachable) {
                    add_node_error(g, first_executing_node(type_node),
                            buf_sprintf("no size available for type '%s'", buf_ptr(&type_entry->name)));
                    return g->builtin_types.entry_invalid;
                } else {
                    uint64_t size_in_bytes = type_entry->size_in_bits / 8;
                    return resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type, size_in_bytes);
                }
            }
        case BuiltinFnIdMaxValue:
            return analyze_min_max_value(g, import, context, node,
                    "no max value available for type '%s'", true);
        case BuiltinFnIdMinValue:
            return analyze_min_max_value(g, import, context, node,
                    "no min value available for type '%s'", false);
        case BuiltinFnIdValueCount:
            {
                AstNode *type_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *type_entry = analyze_type_expr(g, import, context, type_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdEnum) {
                    uint64_t value_count = type_entry->data.enumeration.field_count;
                    return resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type, value_count);
                } else {
                    add_node_error(g, node,
                            buf_sprintf("no value count available for type '%s'", buf_ptr(&type_entry->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case BuiltinFnIdTypeof:
            {
                AstNode *expr_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, expr_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else {
                    return resolve_expr_const_val_as_type(g, node, type_entry);
                }
            }

    }
    zig_unreachable();
}

static TypeTableEntry *analyze_fn_call_raw(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node, FnTableEntry *fn_table_entry, TypeTableEntry *struct_type)
{
    assert(node->type == NodeTypeFnCallExpr);

    node->data.fn_call_expr.fn_entry = fn_table_entry;
    assert(fn_table_entry->proto_node->type == NodeTypeFnProto);
    AstNodeFnProto *fn_proto = &fn_table_entry->proto_node->data.fn_proto;

    // count parameters
    int expected_param_count = fn_proto->params.length;
    int actual_param_count = node->data.fn_call_expr.params.length;

    if (struct_type) {
        actual_param_count += 1;
    }

    if (fn_proto->is_var_args) {
        if (actual_param_count < expected_param_count) {
            add_node_error(g, node,
                    buf_sprintf("expected at least %d arguments, got %d",
                        expected_param_count, actual_param_count));
        }
    } else if (expected_param_count != actual_param_count) {
        add_node_error(g, node,
                buf_sprintf("expected %d arguments, got %d",
                    expected_param_count, actual_param_count));
    }

    // analyze each parameter. in the case of a method, we already analyzed the
    // first parameter in order to figure out which struct we were calling a method on.
    for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
        AstNode *child = node->data.fn_call_expr.params.at(i);
        // determine the expected type for each parameter
        TypeTableEntry *expected_param_type = nullptr;
        int fn_proto_i = i + (struct_type ? 1 : 0);
        if (fn_proto_i < fn_proto->params.length) {
            AstNode *param_decl_node = fn_proto->params.at(fn_proto_i);
            assert(param_decl_node->type == NodeTypeParamDecl);
            AstNode *param_type_node = param_decl_node->data.param_decl.type;
            TypeTableEntry *param_type_entry = get_resolved_expr(param_type_node)->type_entry;
            if (param_type_entry) {
                expected_param_type = unwrapped_node_type(param_type_node);
            }
        }
        analyze_expression(g, import, context, expected_param_type, child);
    }

    return unwrapped_node_type(fn_proto->return_type);
}

static TypeTableEntry *analyze_fn_call_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;

    if (node->data.fn_call_expr.is_builtin) {
        return analyze_builtin_fn_call_expr(g, import, context, expected_type, node);
    }

    if (fn_ref_expr->type == NodeTypeFieldAccessExpr) {
        AstNode *first_param_expr = fn_ref_expr->data.field_access_expr.struct_expr;
        TypeTableEntry *struct_type = analyze_expression(g, import, context, nullptr, first_param_expr);
        Buf *name = &fn_ref_expr->data.field_access_expr.field_name;
        if (struct_type->id == TypeTableEntryIdStruct ||
            (struct_type->id == TypeTableEntryIdPointer &&
            struct_type->data.pointer.child_type->id == TypeTableEntryIdStruct))
        {
            TypeTableEntry *bare_struct_type = (struct_type->id == TypeTableEntryIdStruct) ?
                struct_type : struct_type->data.pointer.child_type;

            auto table_entry = bare_struct_type->data.structure.fn_table.maybe_get(name);
            if (table_entry) {
                return analyze_fn_call_raw(g, import, context, expected_type, node,
                        table_entry->value, bare_struct_type);
            } else {
                add_node_error(g, fn_ref_expr,
                        buf_sprintf("no function named '%s' in '%s'",
                            buf_ptr(name), buf_ptr(&bare_struct_type->name)));
                // still analyze the parameters, even though we don't know what to expect
                for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                    AstNode *child = node->data.fn_call_expr.params.at(i);
                    analyze_expression(g, import, context, nullptr, child);
                }

                return g->builtin_types.entry_invalid;
            }
        } else if (struct_type->id == TypeTableEntryIdInvalid) {
            return struct_type;
        } else if (struct_type->id == TypeTableEntryIdMetaType) {
            TypeTableEntry *enum_type = resolve_type(g, first_param_expr);

            if (enum_type->id == TypeTableEntryIdInvalid) {
                return g->builtin_types.entry_invalid;
            } else if (enum_type->id == TypeTableEntryIdEnum) {
                Buf *field_name = &fn_ref_expr->data.field_access_expr.field_name;
                int param_count = node->data.fn_call_expr.params.length;
                if (param_count > 1) {
                    add_node_error(g, first_executing_node(node->data.fn_call_expr.params.at(1)),
                            buf_sprintf("enum values accept only one parameter"));
                    return enum_type;
                } else {
                    AstNode *value_node;
                    if (param_count == 1) {
                        value_node = node->data.fn_call_expr.params.at(0);
                    } else {
                        value_node = nullptr;
                    }

                    return analyze_enum_value_expr(g, import, context, fn_ref_expr, value_node,
                            enum_type, field_name);
                }
            } else {
                add_node_error(g, first_param_expr, buf_sprintf("member reference base type not struct or enum"));
                return g->builtin_types.entry_invalid;
            }
        } else {
            add_node_error(g, first_param_expr, buf_sprintf("member reference base type not struct or enum"));
            return g->builtin_types.entry_invalid;
        }
    }

    TypeTableEntry *invoke_type_entry = analyze_expression(g, import, context, nullptr, fn_ref_expr);
    if (invoke_type_entry->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    }

    // use constant expression evaluator to figure out the function at compile time.
    // otherwise we treat this as a function pointer.
    ConstExprValue *const_val = &get_resolved_expr(fn_ref_expr)->const_val;

    if (!const_val->ok) {
        add_node_error(g, node, buf_sprintf("function pointers not yet supported"));
        return g->builtin_types.entry_invalid;
    }

    if (invoke_type_entry->id == TypeTableEntryIdMetaType) {
        return analyze_cast_expr(g, import, context, node);
    } else if (invoke_type_entry->id == TypeTableEntryIdFn) {
        return analyze_fn_call_raw(g, import, context, expected_type, node, const_val->data.x_fn, nullptr);
    } else {
        add_node_error(g, fn_ref_expr,
            buf_sprintf("type '%s' not a function", buf_ptr(&invoke_type_entry->name)));
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *analyze_prefix_op_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    PrefixOp prefix_op = node->data.prefix_op_expr.prefix_op;
    AstNode *expr_node = node->data.prefix_op_expr.primary_expr;
    switch (prefix_op) {
        case PrefixOpInvalid:
            zig_unreachable();
        case PrefixOpBoolNot:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, g->builtin_types.entry_bool,
                        expr_node);
                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_bool;
                }

                ConstExprValue *target_const_val = &get_resolved_expr(expr_node)->const_val;
                if (!target_const_val->ok) {
                    return g->builtin_types.entry_bool;
                }

                bool answer = target_const_val->data.x_bool;
                return resolve_expr_const_val_as_bool(g, node, answer);
            }
        case PrefixOpBinNot:
            {
                TypeTableEntry *expr_type = analyze_expression(g, import, context, expected_type,
                        expr_node);
                if (expr_type->id == TypeTableEntryIdInvalid) {
                    return expr_type;
                } else if (expr_type->id == TypeTableEntryIdInt ||
                        (expr_type->id == TypeTableEntryIdNumberLiteral &&
                            !is_num_lit_float(expr_type->data.num_lit.kind)))
                {
                    return expr_type;
                } else {
                    add_node_error(g, expr_node, buf_sprintf("invalid binary not type: '%s'",
                            buf_ptr(&expr_type->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case PrefixOpNegation:
            {
                TypeTableEntry *expr_type = analyze_expression(g, import, context, expected_type,
                        expr_node);
                if (expr_type->id == TypeTableEntryIdInvalid) {
                    return expr_type;
                } else if (expr_type->id == TypeTableEntryIdInt &&
                        expr_type->data.integral.is_signed)
                {
                    return expr_type;
                } else if (expr_type->id == TypeTableEntryIdFloat) {
                    return expr_type;
                } else if (expr_type->id == TypeTableEntryIdNumberLiteral) {
                    return expr_type;
                } else {
                    add_node_error(g, node, buf_sprintf("invalid negation type: '%s'",
                            buf_ptr(&expr_type->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case PrefixOpAddressOf:
        case PrefixOpConstAddressOf:
            {
                bool is_const = (prefix_op == PrefixOpConstAddressOf);

                TypeTableEntry *child_type = analyze_lvalue(g, import, context,
                        expr_node, LValPurposeAddressOf, is_const);

                if (child_type->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else if (child_type->id == TypeTableEntryIdMetaType) {
                    TypeTableEntry *meta_type = analyze_type_expr(g, import, context, expr_node);
                    if (meta_type->id == TypeTableEntryIdInvalid) {
                        return g->builtin_types.entry_invalid;
                    } else if (meta_type->id == TypeTableEntryIdUnreachable) {
                        add_node_error(g, node, buf_create_from_str("pointer to unreachable not allowed"));
                        return g->builtin_types.entry_invalid;
                    } else {
                        return resolve_expr_const_val_as_type(g, node,
                                get_pointer_to_type(g, meta_type, is_const));
                    }
                } else {
                    return get_pointer_to_type(g, child_type, is_const);
                }
            }
        case PrefixOpDereference:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, expr_node);
                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdPointer) {
                    return type_entry->data.pointer.child_type;
                } else {
                    add_node_error(g, expr_node,
                        buf_sprintf("indirection requires pointer operand ('%s' invalid)",
                            buf_ptr(&type_entry->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case PrefixOpMaybe:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, expr_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdMetaType) {
                    TypeTableEntry *meta_type = resolve_type(g, expr_node);
                    if (meta_type->id == TypeTableEntryIdInvalid) {
                        return g->builtin_types.entry_invalid;
                    } else if (meta_type->id == TypeTableEntryIdUnreachable) {
                        add_node_error(g, node, buf_create_from_str("maybe unreachable type not allowed"));
                        return g->builtin_types.entry_invalid;
                    } else {
                        return resolve_expr_const_val_as_type(g, node, get_maybe_type(g, meta_type));
                    }
                } else if (type_entry->id == TypeTableEntryIdUnreachable) {
                    add_node_error(g, expr_node, buf_sprintf("unable to wrap unreachable in maybe type"));
                    return g->builtin_types.entry_invalid;
                } else {
                    // TODO eval const expr
                    return get_maybe_type(g, type_entry);
                }
            }
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
                node->data.block.block_context = child_context;
                return_type = g->builtin_types.entry_void;

                for (int i = 0; i < node->data.block.statements.length; i += 1) {
                    AstNode *child = node->data.block.statements.at(i);
                    if (child->type == NodeTypeLabel) {
                        LabelTableEntry *label_entry = child->data.label.label_entry;
                        assert(label_entry);
                        label_entry->entered_from_fallthrough = (return_type->id != TypeTableEntryIdUnreachable);
                        return_type = g->builtin_types.entry_void;
                        continue;
                    }
                    if (return_type->id == TypeTableEntryIdUnreachable) {
                        if (is_node_void_expr(child)) {
                            // {unreachable;void;void} is allowed.
                            // ignore void statements once we enter unreachable land.
                            analyze_expression(g, import, context, g->builtin_types.entry_void, child);
                            continue;
                        }
                        add_node_error(g, first_executing_node(child), buf_sprintf("unreachable code"));
                        break;
                    }
                    bool is_last = (i == node->data.block.statements.length - 1);
                    TypeTableEntry *passed_expected_type = is_last ? expected_type : nullptr;
                    return_type = analyze_expression(g, import, child_context, passed_expected_type, child);
                    if (!is_last && return_type->id == TypeTableEntryIdMetaType) {
                        add_node_error(g, child, buf_sprintf("expected expression, found type"));
                    }
                }
                break;
            }

        case NodeTypeReturnExpr:
            {
                if (context->fn_entry) {
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

                    resolve_type_compatibility(g, context, node, expected_return_type, actual_return_type);
                } else {
                    add_node_error(g, node, buf_sprintf("return expression outside function definition"));
                }
                return_type = g->builtin_types.entry_unreachable;
                break;
            }
        case NodeTypeVariableDeclaration:
            analyze_variable_declaration(g, import, context, expected_type, node);
            return_type = g->builtin_types.entry_void;
            break;
        case NodeTypeGoto:
            {
                FnTableEntry *fn_table_entry = get_context_fn_entry(context);
                auto table_entry = fn_table_entry->label_table.maybe_get(&node->data.goto_expr.name);
                if (table_entry) {
                    node->data.goto_expr.label_entry = table_entry->value;
                    table_entry->value->used = true;
                } else {
                    add_node_error(g, node,
                            buf_sprintf("use of undeclared label '%s'", buf_ptr(&node->data.goto_expr.name)));
                }
                return_type = g->builtin_types.entry_unreachable;
                break;
            }
        case NodeTypeBreak:
            return_type = analyze_break_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeContinue:
            return_type = analyze_continue_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeAsmExpr:
            {
                node->data.asm_expr.return_count = 0;
                return_type = g->builtin_types.entry_void;
                for (int i = 0; i < node->data.asm_expr.output_list.length; i += 1) {
                    AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
                    if (asm_output->return_type) {
                        node->data.asm_expr.return_count += 1;
                        return_type = analyze_type_expr(g, import, context, asm_output->return_type);
                        if (node->data.asm_expr.return_count > 1) {
                            add_node_error(g, node,
                                buf_sprintf("inline assembly allows up to one output value"));
                            break;
                        }
                    } else {
                        analyze_variable_name(g, import, context, node, &asm_output->variable_name);
                    }
                }
                for (int i = 0; i < node->data.asm_expr.input_list.length; i += 1) {
                    AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
                    analyze_expression(g, import, context, nullptr, asm_input->expr);
                }

                break;
            }
        case NodeTypeBinOpExpr:
            return_type = analyze_bin_op_expr(g, import, context, expected_type, node);
            break;

        case NodeTypeFnCallExpr:
            return_type = analyze_fn_call_expr(g, import, context, expected_type, node);
            break;

        case NodeTypeArrayAccessExpr:
            // for reading array access; assignment handled elsewhere
            return_type = analyze_array_access_expr(g, import, context, node);
            break;
        case NodeTypeSliceExpr:
            return_type = analyze_slice_expr(g, import, context, node);
            break;
        case NodeTypeFieldAccessExpr:
            return_type = analyze_field_access_expr(g, import, context, node);
            break;
        case NodeTypeContainerInitExpr:
            return_type = analyze_container_init_expr(g, import, context, node);
            break;
        case NodeTypeNumberLiteral:
            return_type = analyze_number_literal_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeStringLiteral:
            if (node->data.string_literal.c) {
                return_type = g->builtin_types.entry_c_string_literal;
            } else {
                return_type = get_array_type(g, import, g->builtin_types.entry_u8,
                        buf_len(&node->data.string_literal.buf));
            }
            break;
        case NodeTypeCharLiteral:
            return_type = g->builtin_types.entry_u8;
            break;
        case NodeTypeBoolLiteral:
            return_type = resolve_expr_const_val_as_bool(g, node, node->data.bool_literal.value);
            break;

        case NodeTypeNullLiteral:
            return_type = analyze_null_literal_expr(g, import, context, expected_type, node);
            break;

        case NodeTypeSymbol:
            return_type = analyze_symbol_expr(g, import, context, expected_type, node);
            break;
        case NodeTypePrefixOpExpr:
            return_type = analyze_prefix_op_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeIfBoolExpr:
            return_type = analyze_if_bool_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeIfVarExpr:
            return_type = analyze_if_var_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeWhileExpr:
            return_type = analyze_while_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeArrayType:
            return_type = analyze_array_type(g, import, context, expected_type, node);
            break;
        case NodeTypeDirective:
        case NodeTypeFnDecl:
        case NodeTypeFnProto:
        case NodeTypeParamDecl:
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeExternBlock:
        case NodeTypeFnDef:
        case NodeTypeUse:
        case NodeTypeLabel:
        case NodeTypeStructDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
            zig_unreachable();
    }
    assert(return_type);
    resolve_type_compatibility(g, context, node, expected_type, return_type);

    Expr *expr = get_resolved_expr(node);
    expr->type_entry = return_type;
    expr->block_context = context;

    if (expr->type_entry->id == TypeTableEntryIdUnreachable) {
        return expr->type_entry;
    }

    /*
    Cast *cast_node = &expr->implicit_cast;
    if (cast_node->after_type) {
        eval_const_expr_implicit_cast(g, import, context, node, cast_node, node);
        expr->type_entry = cast_node->after_type;
    }
    */

    Cast *cast_node = &expr->implicit_maybe_cast;
    if (cast_node->after_type) {
        eval_const_expr_implicit_cast(g, import, context, node, cast_node, node);
        expr->type_entry = cast_node->after_type;
    }

    return expr->type_entry;
}

static void analyze_top_level_fn_def(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeFnDef);

    AstNode *fn_proto_node = node->data.fn_def.fn_proto;
    assert(fn_proto_node->type == NodeTypeFnProto);

    if (fn_proto_node->data.fn_proto.skip) {
        // we detected an error with this function definition which prevents us
        // from further analyzing it.
        return;
    }

    BlockContext *context = new_block_context(node, import->block_context);
    node->data.fn_def.block_context = context;

    AstNodeFnProto *fn_proto = &fn_proto_node->data.fn_proto;
    bool is_exported = (fn_proto->visib_mod == VisibModExport);
    for (int i = 0; i < fn_proto->params.length; i += 1) {
        AstNode *param_decl_node = fn_proto->params.at(i);
        assert(param_decl_node->type == NodeTypeParamDecl);

        // define local variables for parameters
        AstNodeParamDecl *param_decl = &param_decl_node->data.param_decl;
        TypeTableEntry *type = unwrapped_node_type(param_decl->type);

        if (param_decl->is_noalias && type->id != TypeTableEntryIdPointer) {
            add_node_error(g, param_decl_node,
                buf_sprintf("noalias on non-pointer parameter"));
        }

        if (is_exported && type->id == TypeTableEntryIdStruct) {
            add_node_error(g, param_decl_node,
                buf_sprintf("byvalue struct parameters not yet supported on exported functions"));
        }

        VariableTableEntry *variable_entry = allocate<VariableTableEntry>(1);
        buf_init_from_buf(&variable_entry->name, &param_decl->name);
        variable_entry->type = type;
        variable_entry->is_const = true;
        variable_entry->decl_node = param_decl_node;
        variable_entry->arg_index = i;

        param_decl_node->data.param_decl.variable = variable_entry;

        VariableTableEntry *existing_entry = find_local_variable(context, &variable_entry->name);
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

    TypeTableEntry *expected_type = unwrapped_node_type(fn_proto->return_type);
    TypeTableEntry *block_return_type = analyze_expression(g, import, context, expected_type, node->data.fn_def.body);

    node->data.fn_def.implicit_return_type = block_return_type;

    {
        FnTableEntry *fn_table_entry = fn_proto_node->data.fn_proto.fn_table_entry;
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

static void analyze_top_level_decl(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    switch (node->type) {
        case NodeTypeFnDef:
            analyze_top_level_fn_def(g, import, node);
            break;
        case NodeTypeStructDecl:
            {
                for (int i = 0; i < node->data.struct_decl.fns.length; i += 1) {
                    AstNode *fn_def_node = node->data.struct_decl.fns.at(i);
                    analyze_top_level_fn_def(g, import, fn_def_node);
                }
                break;
            }
        case NodeTypeRootExportDecl:
        case NodeTypeExternBlock:
        case NodeTypeUse:
        case NodeTypeVariableDeclaration:
            // already took care of these
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnProto:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeContainerInitExpr:
        case NodeTypeArrayType:
            zig_unreachable();
    }
}

static void collect_expr_decl_deps(CodeGen *g, ImportTableEntry *import, AstNode *node,
        TopLevelDecl *decl_node)
{
    switch (node->type) {
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
            // no dependencies on other top level declarations
            break;
        case NodeTypeSymbol:
            {
                Buf *name = &node->data.symbol_expr.symbol;
                auto table_entry = g->primitive_type_table.maybe_get(name);
                if (!table_entry) {
                    table_entry = import->block_context->type_table.maybe_get(name);
                }
                if (!table_entry) {
                    decl_node->deps.put(name, node);
                }
                break;
            }
        case NodeTypeBinOpExpr:
            collect_expr_decl_deps(g, import, node->data.bin_op_expr.op1, decl_node);
            collect_expr_decl_deps(g, import, node->data.bin_op_expr.op2, decl_node);
            break;
        case NodeTypeReturnExpr:
            collect_expr_decl_deps(g, import, node->data.return_expr.expr, decl_node);
            break;
        case NodeTypePrefixOpExpr:
            collect_expr_decl_deps(g, import, node->data.prefix_op_expr.primary_expr, decl_node);
            break;
        case NodeTypeFnCallExpr:
            collect_expr_decl_deps(g, import, node->data.fn_call_expr.fn_ref_expr, decl_node);
            for (int i = 0; i < node->data.fn_call_expr.params.length; i += 1) {
                AstNode *arg_node = node->data.fn_call_expr.params.at(i);
                collect_expr_decl_deps(g, import, arg_node, decl_node);
            }
            break;
        case NodeTypeArrayAccessExpr:
            collect_expr_decl_deps(g, import, node->data.array_access_expr.array_ref_expr, decl_node);
            collect_expr_decl_deps(g, import, node->data.array_access_expr.subscript, decl_node);
            break;
        case NodeTypeSliceExpr:
            collect_expr_decl_deps(g, import, node->data.slice_expr.array_ref_expr, decl_node);
            collect_expr_decl_deps(g, import, node->data.slice_expr.start, decl_node);
            if (node->data.slice_expr.end) {
                collect_expr_decl_deps(g, import, node->data.slice_expr.end, decl_node);
            }
            break;
        case NodeTypeFieldAccessExpr:
            collect_expr_decl_deps(g, import, node->data.field_access_expr.struct_expr, decl_node);
            break;
        case NodeTypeIfBoolExpr:
            collect_expr_decl_deps(g, import, node->data.if_bool_expr.condition, decl_node);
            collect_expr_decl_deps(g, import, node->data.if_bool_expr.then_block, decl_node);
            if (node->data.if_bool_expr.else_node) {
                collect_expr_decl_deps(g, import, node->data.if_bool_expr.else_node, decl_node);
            }
            break;
        case NodeTypeIfVarExpr:
            if (node->data.if_var_expr.var_decl.type) {
                collect_expr_decl_deps(g, import, node->data.if_var_expr.var_decl.type, decl_node);
            }
            if (node->data.if_var_expr.var_decl.expr) {
                collect_expr_decl_deps(g, import, node->data.if_var_expr.var_decl.expr, decl_node);
            }
            collect_expr_decl_deps(g, import, node->data.if_var_expr.then_block, decl_node);
            if (node->data.if_bool_expr.else_node) {
                collect_expr_decl_deps(g, import, node->data.if_var_expr.else_node, decl_node);
            }
            break;
        case NodeTypeWhileExpr:
            collect_expr_decl_deps(g, import, node->data.while_expr.condition, decl_node);
            collect_expr_decl_deps(g, import, node->data.while_expr.body, decl_node);
            break;
        case NodeTypeBlock:
            for (int i = 0; i < node->data.block.statements.length; i += 1) {
                AstNode *stmt = node->data.block.statements.at(i);
                collect_expr_decl_deps(g, import, stmt, decl_node);
            }
            break;
        case NodeTypeAsmExpr:
            for (int i = 0; i < node->data.asm_expr.output_list.length; i += 1) {
                AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
                if (asm_output->return_type) {
                    collect_expr_decl_deps(g, import, asm_output->return_type, decl_node);
                } else {
                    decl_node->deps.put(&asm_output->variable_name, node);
                }
            }
            for (int i = 0; i < node->data.asm_expr.input_list.length; i += 1) {
                AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
                collect_expr_decl_deps(g, import, asm_input->expr, decl_node);
            }
            break;
        case NodeTypeContainerInitExpr:
            collect_expr_decl_deps(g, import, node->data.container_init_expr.type, decl_node);
            for (int i = 0; i < node->data.container_init_expr.entries.length; i += 1) {
                AstNode *child_node = node->data.container_init_expr.entries.at(i);
                collect_expr_decl_deps(g, import, child_node, decl_node);
            }
            break;
        case NodeTypeStructValueField:
            collect_expr_decl_deps(g, import, node->data.struct_val_field.expr, decl_node);
            break;
        case NodeTypeArrayType:
            if (node->data.array_type.size) {
                collect_expr_decl_deps(g, import, node->data.array_type.size, decl_node);
            }
            collect_expr_decl_deps(g, import, node->data.array_type.child_type, decl_node);
            break;
        case NodeTypeVariableDeclaration:
        case NodeTypeFnProto:
        case NodeTypeExternBlock:
        case NodeTypeRootExportDecl:
        case NodeTypeFnDef:
        case NodeTypeRoot:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeDirective:
        case NodeTypeUse:
        case NodeTypeLabel:
        case NodeTypeStructDecl:
        case NodeTypeStructField:
            zig_unreachable();
    }
}

static TypeTableEntryId container_to_type(ContainerKind kind) {
    switch (kind) {
        case ContainerKindStruct:
            return TypeTableEntryIdStruct;
        case ContainerKindEnum:
            return TypeTableEntryIdEnum;
    }
    zig_unreachable();
}

static void detect_top_level_decl_deps(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    switch (node->type) {
        case NodeTypeStructDecl:
            {
                Buf *name = &node->data.struct_decl.name;
                auto table_entry = g->primitive_type_table.maybe_get(name);
                if (!table_entry) {
                    table_entry = import->block_context->type_table.maybe_get(name);
                }
                if (table_entry) {
                    node->data.struct_decl.type_entry = table_entry->value;
                    add_node_error(g, node,
                            buf_sprintf("redefinition of '%s'", buf_ptr(name)));
                } else {
                    TypeTableEntryId type_id = container_to_type(node->data.struct_decl.kind);
                    TypeTableEntry *entry = new_type_table_entry(type_id);
                    switch (node->data.struct_decl.kind) {
                        case ContainerKindStruct:
                            entry->data.structure.decl_node = node;
                            break;
                        case ContainerKindEnum:
                            entry->data.enumeration.decl_node = node;
                            break;
                    }

                    entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), buf_ptr(name));
                    entry->di_type = LLVMZigCreateReplaceableCompositeType(g->dbuilder,
                        LLVMZigTag_DW_structure_type(), buf_ptr(name),
                        LLVMZigFileToScope(import->di_file), import->di_file, node->line + 1);

                    buf_init_from_buf(&entry->name, name);
                    // put off adding the debug type until we do the full struct body
                    // this type is incomplete until we do another pass
                    import->block_context->type_table.put(&entry->name, entry);
                    node->data.struct_decl.type_entry = entry;

                    bool is_pub = (node->data.struct_decl.visib_mod != VisibModPrivate);
                    if (is_pub) {
                        for (int i = 0; i < import->importers.length; i += 1) {
                            ImporterInfo importer = import->importers.at(i);
                            auto table_entry = importer.import->block_context->type_table.maybe_get(&entry->name);
                            if (table_entry) {
                                add_node_error(g, importer.source_node,
                                    buf_sprintf("import of type '%s' overrides existing definition",
                                        buf_ptr(&entry->name)));
                            } else {
                                importer.import->block_context->type_table.put(&entry->name, entry);
                            }
                        }
                    }
                }

                // determine which other top level declarations this struct depends on.
                TopLevelDecl *decl_node = &node->data.struct_decl.top_level_decl;
                decl_node->deps.init(1);
                for (int i = 0; i < node->data.struct_decl.fields.length; i += 1) {
                    AstNode *field_node = node->data.struct_decl.fields.at(i);
                    AstNode *type_node = field_node->data.struct_field.type;
                    collect_expr_decl_deps(g, import, type_node, decl_node);
                }
                decl_node->name = name;
                decl_node->import = import;
                if (decl_node->deps.size() > 0) {
                    g->unresolved_top_level_decls.put(name, node);
                } else {
                    resolve_top_level_decl(g, import, node);
                }

                // handle the member function definitions independently
                for (int i = 0; i < node->data.struct_decl.fns.length; i += 1) {
                    AstNode *fn_def_node = node->data.struct_decl.fns.at(i);
                    AstNode *fn_proto_node = fn_def_node->data.fn_def.fn_proto;
                    fn_proto_node->data.fn_proto.struct_node = node;
                    detect_top_level_decl_deps(g, import, fn_def_node);
                }

                break;
            }
        case NodeTypeExternBlock:
            for (int fn_decl_i = 0; fn_decl_i < node->data.extern_block.fn_decls.length; fn_decl_i += 1) {
                AstNode *fn_decl = node->data.extern_block.fn_decls.at(fn_decl_i);
                assert(fn_decl->type == NodeTypeFnDecl);
                AstNode *fn_proto = fn_decl->data.fn_decl.fn_proto;
                fn_proto->data.fn_proto.extern_node = node;
                detect_top_level_decl_deps(g, import, fn_proto);
            }
            resolve_top_level_decl(g, import, node);
            break;
        case NodeTypeFnDef:
            node->data.fn_def.fn_proto->data.fn_proto.fn_def_node = node;
            detect_top_level_decl_deps(g, import, node->data.fn_def.fn_proto);
            break;
        case NodeTypeVariableDeclaration:
            {
                // determine which other top level declarations this variable declaration depends on.
                TopLevelDecl *decl_node = &node->data.variable_declaration.top_level_decl;
                decl_node->deps.init(1);
                if (node->data.variable_declaration.type) {
                    collect_expr_decl_deps(g, import, node->data.variable_declaration.type, decl_node);
                }
                if (node->data.variable_declaration.expr) {
                    collect_expr_decl_deps(g, import, node->data.variable_declaration.expr, decl_node);
                }
                Buf *name = &node->data.variable_declaration.symbol;
                decl_node->name = name;
                decl_node->import = import;
                if (decl_node->deps.size() > 0) {
                    g->unresolved_top_level_decls.put(name, node);
                } else {
                    resolve_top_level_decl(g, import, node);
                }
                break;
            }
        case NodeTypeFnProto:
            {
                // determine which other top level declarations this function prototype depends on.
                TopLevelDecl *decl_node = &node->data.fn_proto.top_level_decl;
                decl_node->deps.init(1);
                for (int i = 0; i < node->data.fn_proto.params.length; i += 1) {
                    AstNode *param_node = node->data.fn_proto.params.at(i);
                    assert(param_node->type == NodeTypeParamDecl);
                    collect_expr_decl_deps(g, import, param_node->data.param_decl.type, decl_node);
                }
                collect_expr_decl_deps(g, import, node->data.fn_proto.return_type, decl_node);

                Buf *name = &node->data.fn_proto.name;
                decl_node->name = name;
                decl_node->import = import;
                if (decl_node->deps.size() > 0) {
                    g->unresolved_top_level_decls.put(name, node);
                } else {
                    resolve_top_level_decl(g, import, node);
                }
                break;
            }
        case NodeTypeRootExportDecl:
            resolve_top_level_decl(g, import, node);
            break;
        case NodeTypeUse:
            // already taken care of
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeStructField:
        case NodeTypeContainerInitExpr:
        case NodeTypeStructValueField:
        case NodeTypeArrayType:
            zig_unreachable();
    }
}

static void recursive_resolve_decl(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    auto it = get_resolved_top_level_decl(node)->deps.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        auto unresolved_entry = g->unresolved_top_level_decls.maybe_get(entry->key);
        if (!unresolved_entry) {
            continue;
        }

        AstNode *child_node = unresolved_entry->value;

        if (get_resolved_top_level_decl(child_node)->in_current_deps) {
            // dependency loop. we'll let the fact that it's not in the respective
            // table cause an error in resolve_top_level_decl.
            continue;
        }

        // set temporary flag
        TopLevelDecl *top_level_decl = get_resolved_top_level_decl(child_node);
        top_level_decl->in_current_deps = true;

        recursive_resolve_decl(g, top_level_decl->import, child_node);

        // unset temporary flag
        top_level_decl->in_current_deps = false;
    }

    resolve_top_level_decl(g, import, node);
    g->unresolved_top_level_decls.remove(get_resolved_top_level_decl(node)->name);
}

static void resolve_top_level_declarations_root(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeRoot);

    while (g->unresolved_top_level_decls.size() > 0) {
        // for the sake of determinism, find the element with the lowest
        // insert index and resolve that one.
        AstNode *decl_node = nullptr;
        auto it = g->unresolved_top_level_decls.entry_iterator();
        for (;;) {
            auto *entry = it.next();
            if (!entry)
                break;

            AstNode *this_node = entry->value;
            if (!decl_node || this_node->create_index < decl_node->create_index) {
                decl_node = this_node;
            }

        }
        // set temporary flag
        TopLevelDecl *top_level_decl = get_resolved_top_level_decl(decl_node);
        top_level_decl->in_current_deps = true;

        recursive_resolve_decl(g, top_level_decl->import, decl_node);

        // unset temporary flag
        top_level_decl->in_current_deps = false;
    }
}

static void analyze_top_level_decls_root(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeRoot);

    for (int i = 0; i < node->data.root.top_level_decls.length; i += 1) {
        AstNode *child = node->data.root.top_level_decls.at(i);
        analyze_top_level_decl(g, import, child);
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

            for (int i = 0; i < import->root->data.root.top_level_decls.length; i += 1) {
                AstNode *child = import->root->data.root.top_level_decls.at(i);
                if (child->type == NodeTypeUse) {
                    for (int i = 0; i < child->data.use.directives->length; i += 1) {
                        AstNode *directive_node = child->data.use.directives->at(i);
                        Buf *name = &directive_node->data.directive.name;
                        add_node_error(g, directive_node,
                                buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
                    }

                    ImportTableEntry *target_import = child->data.use.import;
                    assert(target_import);

                    target_import->importers.append({import, child});
                }
            }
        }
    }
    {
        auto it = g->import_table.entry_iterator();
        for (;;) {
            auto *entry = it.next();
            if (!entry)
                break;

            ImportTableEntry *import = entry->value;

            for (int i = 0; i < import->root->data.root.top_level_decls.length; i += 1) {
                AstNode *child = import->root->data.root.top_level_decls.at(i);
                detect_top_level_decl_deps(g, import, child);
            }
        }
    }
    {
        auto it = g->import_table.entry_iterator();
        for (;;) {
            auto *entry = it.next();
            if (!entry)
                break;

            ImportTableEntry *import = entry->value;
            resolve_top_level_declarations_root(g, import, import->root);
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

Expr *get_resolved_expr(AstNode *node) {
    switch (node->type) {
        case NodeTypeReturnExpr:
            return &node->data.return_expr.resolved_expr;
        case NodeTypeBinOpExpr:
            return &node->data.bin_op_expr.resolved_expr;
        case NodeTypePrefixOpExpr:
            return &node->data.prefix_op_expr.resolved_expr;
        case NodeTypeFnCallExpr:
            return &node->data.fn_call_expr.resolved_expr;
        case NodeTypeArrayAccessExpr:
            return &node->data.array_access_expr.resolved_expr;
        case NodeTypeSliceExpr:
            return &node->data.slice_expr.resolved_expr;
        case NodeTypeFieldAccessExpr:
            return &node->data.field_access_expr.resolved_expr;
        case NodeTypeIfBoolExpr:
            return &node->data.if_bool_expr.resolved_expr;
        case NodeTypeIfVarExpr:
            return &node->data.if_var_expr.resolved_expr;
        case NodeTypeWhileExpr:
            return &node->data.while_expr.resolved_expr;
        case NodeTypeAsmExpr:
            return &node->data.asm_expr.resolved_expr;
        case NodeTypeContainerInitExpr:
            return &node->data.container_init_expr.resolved_expr;
        case NodeTypeNumberLiteral:
            return &node->data.number_literal.resolved_expr;
        case NodeTypeStringLiteral:
            return &node->data.string_literal.resolved_expr;
        case NodeTypeBlock:
            return &node->data.block.resolved_expr;
        case NodeTypeSymbol:
            return &node->data.symbol_expr.resolved_expr;
        case NodeTypeVariableDeclaration:
            return &node->data.variable_declaration.resolved_expr;
        case NodeTypeCharLiteral:
            return &node->data.char_literal.resolved_expr;
        case NodeTypeBoolLiteral:
            return &node->data.bool_literal.resolved_expr;
        case NodeTypeNullLiteral:
            return &node->data.null_literal.resolved_expr;
        case NodeTypeGoto:
            return &node->data.goto_expr.resolved_expr;
        case NodeTypeBreak:
            return &node->data.break_expr.resolved_expr;
        case NodeTypeContinue:
            return &node->data.continue_expr.resolved_expr;
        case NodeTypeLabel:
            return &node->data.label.resolved_expr;
        case NodeTypeArrayType:
            return &node->data.array_type.resolved_expr;
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeExternBlock:
        case NodeTypeDirective:
        case NodeTypeUse:
        case NodeTypeStructDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
            zig_unreachable();
    }
    zig_unreachable();
}

NumLitCodeGen *get_resolved_num_lit(AstNode *node) {
    switch (node->type) {
        case NodeTypeNumberLiteral:
            return &node->data.number_literal.codegen;
        case NodeTypeFnCallExpr:
            return &node->data.fn_call_expr.resolved_num_lit;
        case NodeTypeReturnExpr:
        case NodeTypeBinOpExpr:
        case NodeTypePrefixOpExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeAsmExpr:
        case NodeTypeContainerInitExpr:
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeBlock:
        case NodeTypeExternBlock:
        case NodeTypeDirective:
        case NodeTypeVariableDeclaration:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeSymbol:
        case NodeTypeUse:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeStructDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeArrayType:
            zig_unreachable();
    }
    zig_unreachable();
}

TopLevelDecl *get_resolved_top_level_decl(AstNode *node) {
    switch (node->type) {
        case NodeTypeVariableDeclaration:
            return &node->data.variable_declaration.top_level_decl;
        case NodeTypeFnProto:
            return &node->data.fn_proto.top_level_decl;
        case NodeTypeStructDecl:
            return &node->data.struct_decl.top_level_decl;
        case NodeTypeNumberLiteral:
        case NodeTypeReturnExpr:
        case NodeTypeBinOpExpr:
        case NodeTypePrefixOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeAsmExpr:
        case NodeTypeContainerInitExpr:
        case NodeTypeRoot:
        case NodeTypeRootExportDecl:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeBlock:
        case NodeTypeExternBlock:
        case NodeTypeDirective:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeSymbol:
        case NodeTypeUse:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeArrayType:
            zig_unreachable();
    }
    zig_unreachable();
}

bool is_node_void_expr(AstNode *node) {
    if (node->type == NodeTypeContainerInitExpr &&
        node->data.container_init_expr.kind == ContainerInitKindArray)
    {
        AstNode *type_node = node->data.container_init_expr.type;
        if (type_node->type == NodeTypeSymbol &&
            buf_eql_str(&type_node->data.symbol_expr.symbol, "void"))
        {
            return true;
        }
    }

    return false;
}

TypeTableEntry **get_int_type_ptr(CodeGen *g, bool is_signed, int size_in_bits) {
    int index;
    if (size_in_bits == 8) {
        index = 0;
    } else if (size_in_bits == 16) {
        index = 1;
    } else if (size_in_bits == 32) {
        index = 2;
    } else if (size_in_bits == 64) {
        index = 3;
    } else {
        zig_unreachable();
    }
    return &g->builtin_types.entry_int[is_signed ? 0 : 1][index];
}

TypeTableEntry *get_int_type(CodeGen *g, bool is_signed, int size_in_bits) {
    return *get_int_type_ptr(g, is_signed, size_in_bits);
}
