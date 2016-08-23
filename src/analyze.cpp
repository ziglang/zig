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
#include "parseh.hpp"
#include "config.h"
#include "ast_render.hpp"
#include "eval.hpp"

static TypeTableEntry *analyze_expression(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node);
static TypeTableEntry *analyze_expression_pointer_only(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, TypeTableEntry *expected_type, AstNode *node, bool pointer_only);
static VariableTableEntry *analyze_variable_declaration(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, TypeTableEntry *expected_type, AstNode *node);
static void resolve_struct_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *struct_type);
static TypeTableEntry *unwrapped_node_type(AstNode *node);
static TypeTableEntry *analyze_cast_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node);
static TypeTableEntry *analyze_error_literal_expr(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node, Buf *err_name);
static TypeTableEntry *analyze_block_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node);
static TypeTableEntry *resolve_expr_const_val_as_void(CodeGen *g, AstNode *node);
static TypeTableEntry *resolve_expr_const_val_as_fn(CodeGen *g, AstNode *node, FnTableEntry *fn,
        bool depends_on_compile_var);
static TypeTableEntry *resolve_expr_const_val_as_generic_fn(CodeGen *g, AstNode *node,
        TypeTableEntry *type_entry, bool depends_on_compile_var);
static TypeTableEntry *resolve_expr_const_val_as_type(CodeGen *g, AstNode *node, TypeTableEntry *type,
        bool depends_on_compile_var);
static TypeTableEntry *resolve_expr_const_val_as_unsigned_num_lit(CodeGen *g, AstNode *node,
        TypeTableEntry *expected_type, uint64_t x, bool depends_on_compile_var);
static TypeTableEntry *resolve_expr_const_val_as_bool(CodeGen *g, AstNode *node, bool value,
        bool depends_on_compile_var);
static AstNode *find_decl(BlockContext *context, Buf *name);
static TypeTableEntry *analyze_decl_ref(CodeGen *g, AstNode *source_node, AstNode *decl_node,
        bool pointer_only, BlockContext *block_context, bool depends_on_compile_var);
static TopLevelDecl *get_as_top_level_decl(AstNode *node);
static VariableTableEntry *analyze_variable_declaration_raw(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *source_node,
        AstNodeVariableDeclaration *variable_declaration,
        bool expr_is_maybe, AstNode *decl_node, bool var_is_ptr);
static void scan_decls(CodeGen *g, ImportTableEntry *import, BlockContext *context, AstNode *node);
static void analyze_fn_body(CodeGen *g, FnTableEntry *fn_table_entry);
static void resolve_use_decl(CodeGen *g, AstNode *node);
static void preview_use_decl(CodeGen *g, AstNode *node);

static AstNode *first_executing_node(AstNode *node) {
    switch (node->type) {
        case NodeTypeFnCallExpr:
            return first_executing_node(node->data.fn_call_expr.fn_ref_expr);
        case NodeTypeBinOpExpr:
            return first_executing_node(node->data.bin_op_expr.op1);
        case NodeTypeUnwrapErrorExpr:
            return first_executing_node(node->data.unwrap_err_expr.op1);
        case NodeTypeArrayAccessExpr:
            return first_executing_node(node->data.array_access_expr.array_ref_expr);
        case NodeTypeSliceExpr:
            return first_executing_node(node->data.slice_expr.array_ref_expr);
        case NodeTypeFieldAccessExpr:
            return first_executing_node(node->data.field_access_expr.struct_expr);
        case NodeTypeSwitchRange:
            return first_executing_node(node->data.switch_range.start);
        case NodeTypeRoot:
        case NodeTypeFnProto:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeBlock:
        case NodeTypeDirective:
        case NodeTypeReturnExpr:
        case NodeTypeDefer:
        case NodeTypeVariableDeclaration:
        case NodeTypeTypeDecl:
        case NodeTypeErrorValueDecl:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeUse:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeZeroesLiteral:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeAsmExpr:
        case NodeTypeContainerDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeWhileExpr:
        case NodeTypeForExpr:
        case NodeTypeSwitchExpr:
        case NodeTypeSwitchProng:
        case NodeTypeArrayType:
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
        case NodeTypeContainerInitExpr:
            return node;
    }
    zig_unreachable();
}

static void mark_impure_fn(CodeGen *g, BlockContext *context, AstNode *node) {
    if (!context->fn_entry) return;
    if (!context->fn_entry->is_pure) return;

    context->fn_entry->is_pure = false;
    if (context->fn_entry->want_pure == WantPureTrue) {
        context->fn_entry->proto_node->data.fn_proto.skip = true;

        ErrorMsg *msg = add_node_error(g, context->fn_entry->proto_node,
            buf_sprintf("failed to evaluate function at compile time"));

        add_error_note(g, msg, node,
            buf_sprintf("unable to evaluate this expression at compile time"));

        if (context->fn_entry->want_pure_attr_node) {
            add_error_note(g, msg, context->fn_entry->want_pure_attr_node,
                buf_sprintf("required to be compile-time function here"));
        }

        if (context->fn_entry->want_pure_return_type) {
            add_error_note(g, msg, context->fn_entry->want_pure_return_type,
                buf_sprintf("required to be compile-time function because of return type '%s'",
                buf_ptr(&context->fn_entry->type_entry->data.fn.fn_type_id.return_type->name)));
        }
    }
}

ErrorMsg *add_node_error(CodeGen *g, AstNode *node, Buf *msg) {
    // if this assert fails, then parseh generated code that
    // failed semantic analysis, which isn't supposed to happen
    assert(!node->owner->c_import_node);

    // if an error occurs in a function then it becomes impure
    if (node->block_context) {
        FnTableEntry *fn_entry = node->block_context->fn_entry;
        if (fn_entry) {
            fn_entry->is_pure = false;
        }
    }

    ErrorMsg *err = err_msg_create_with_line(node->owner->path, node->line, node->column,
            node->owner->source_code, node->owner->line_offsets, msg);

    g->errors.append(err);
    return err;
}

ErrorMsg *add_error_note(CodeGen *g, ErrorMsg *parent_msg, AstNode *node, Buf *msg) {
    // if this assert fails, then parseh generated code that
    // failed semantic analysis, which isn't supposed to happen
    assert(!node->owner->c_import_node);

    ErrorMsg *err = err_msg_create_with_line(node->owner->path, node->line, node->column,
            node->owner->source_code, node->owner->line_offsets, msg);

    err_msg_add_note(parent_msg, err);
    return err;
}

TypeTableEntry *new_type_table_entry(TypeTableEntryId id) {
    TypeTableEntry *entry = allocate<TypeTableEntry>(1);
    entry->arrays_by_size.init(2);
    entry->id = id;
    return entry;
}

static BlockContext **get_container_block_context_ptr(TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdStruct) {
        return &type_entry->data.structure.block_context;
    } else if (type_entry->id == TypeTableEntryIdEnum) {
        return &type_entry->data.enumeration.block_context;
    } else if (type_entry->id == TypeTableEntryIdUnion) {
        return &type_entry->data.unionation.block_context;
    }
    zig_unreachable();
}

static BlockContext *get_container_block_context(TypeTableEntry *type_entry) {
    return *get_container_block_context_ptr(type_entry);
}

static TypeTableEntry *new_container_type_entry(TypeTableEntryId id, AstNode *source_node,
        BlockContext *parent_context)
{
    TypeTableEntry *entry = new_type_table_entry(id);
    *get_container_block_context_ptr(entry) = new_block_context(source_node, parent_context);
    return entry;
}


static int bits_needed_for_unsigned(uint64_t x) {
    if (x <= UINT8_MAX) {
        return 8;
    } else if (x <= UINT16_MAX) {
        return 16;
    } else if (x <= UINT32_MAX) {
        return 32;
    } else {
        return 64;
    }
}

static bool type_is_complete(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdStruct:
            return type_entry->data.structure.complete;
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.complete;
        case TypeTableEntryIdUnion:
            return type_entry->data.unionation.complete;
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdGenericFn:
            return true;
    }
    zig_unreachable();
}

uint64_t type_size(CodeGen *g, TypeTableEntry *type_entry) {
    if (type_has_bits(type_entry)) {
        return LLVMStoreSizeOfType(g->target_data_ref, type_entry->type_ref);
    } else {
        return 0;
    }
}

static bool is_u8(TypeTableEntry *type) {
    return type->id == TypeTableEntryIdInt &&
        !type->data.integral.is_signed && type->data.integral.bit_count == 8;
}

static bool is_slice(TypeTableEntry *type) {
    return type->id == TypeTableEntryIdStruct && type->data.structure.is_slice;
}

TypeTableEntry *get_smallest_unsigned_int_type(CodeGen *g, uint64_t x) {
    return get_int_type(g, false, bits_needed_for_unsigned(x));
}

static TypeTableEntry *get_generic_fn_type(CodeGen *g, AstNode *decl_node) {
    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdGenericFn);
    buf_init_from_str(&entry->name, "(generic function)");
    entry->deep_const = true;
    entry->zero_bits = true;
    entry->data.generic_fn.decl_node = decl_node;
    return entry;
}

TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const) {
    assert(child_type->id != TypeTableEntryIdInvalid);
    TypeTableEntry **parent_pointer = &child_type->pointer_parent[(is_const ? 1 : 0)];
    if (*parent_pointer) {
        return *parent_pointer;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdPointer);

        entry->deep_const = is_const && child_type->deep_const;

        const char *const_str = is_const ? "const " : "";
        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "&%s%s", const_str, buf_ptr(&child_type->name));

        TypeTableEntry *canon_child_type = get_underlying_type(child_type);
        assert(canon_child_type->id != TypeTableEntryIdInvalid);


        if (type_is_complete(canon_child_type)) {
            entry->zero_bits = !type_has_bits(canon_child_type);
        } else {
            entry->zero_bits = false;
        }

        if (!entry->zero_bits) {
            entry->type_ref = LLVMPointerType(child_type->type_ref, 0);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);
            assert(child_type->di_type);
            entry->di_type = LLVMZigCreateDebugPointerType(g->dbuilder, child_type->di_type,
                    debug_size_in_bits, debug_align_in_bits, buf_ptr(&entry->name));
        }

        entry->data.pointer.child_type = child_type;
        entry->data.pointer.is_const = is_const;

        *parent_pointer = entry;
        return entry;
    }
}

TypeTableEntry *get_maybe_type(CodeGen *g, TypeTableEntry *child_type) {
    if (child_type->maybe_parent) {
        TypeTableEntry *entry = child_type->maybe_parent;
        return entry;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdMaybe);
        assert(child_type->type_ref);
        assert(child_type->di_type);

        entry->deep_const = child_type->deep_const;

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "?%s", buf_ptr(&child_type->name));

        if (child_type->id == TypeTableEntryIdPointer ||
            child_type->id == TypeTableEntryIdFn)
        {
            // this is an optimization but also is necessary for calling C
            // functions where all pointers are maybe pointers
            // function types are technically pointers
            entry->type_ref = child_type->type_ref;
            entry->di_type = child_type->di_type;
        } else {
            // create a struct with a boolean whether this is the null value
            LLVMTypeRef elem_types[] = {
                child_type->type_ref,
                LLVMInt1Type(),
            };
            entry->type_ref = LLVMStructType(elem_types, 2, false);


            LLVMZigDIScope *compile_unit_scope = LLVMZigCompileUnitToScope(g->compile_unit);
            LLVMZigDIFile *di_file = nullptr;
            unsigned line = 0;
            entry->di_type = LLVMZigCreateReplaceableCompositeType(g->dbuilder,
                LLVMZigTag_DW_structure_type(), buf_ptr(&entry->name),
                compile_unit_scope, di_file, line);

            uint64_t val_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, child_type->type_ref);
            uint64_t val_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, child_type->type_ref);
            uint64_t val_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 0);

            TypeTableEntry *bool_type = g->builtin_types.entry_bool;
            uint64_t maybe_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, bool_type->type_ref);
            uint64_t maybe_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, bool_type->type_ref);
            uint64_t maybe_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 1);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

            LLVMZigDIType *di_element_types[] = {
                LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                        "val", di_file, line,
                        val_debug_size_in_bits,
                        val_debug_align_in_bits,
                        val_offset_in_bits,
                        0, child_type->di_type),
                LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                        "maybe", di_file, line,
                        maybe_debug_size_in_bits,
                        maybe_debug_align_in_bits,
                        maybe_offset_in_bits,
                        0, child_type->di_type),
            };
            LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                    compile_unit_scope,
                    buf_ptr(&entry->name),
                    di_file, line, debug_size_in_bits, debug_align_in_bits, 0,
                    nullptr, di_element_types, 2, 0, nullptr, "");

            LLVMZigReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
            entry->di_type = replacement_di_type;
        }

        entry->data.maybe.child_type = child_type;

        child_type->maybe_parent = entry;
        return entry;
    }
}

static TypeTableEntry *get_error_type(CodeGen *g, TypeTableEntry *child_type) {
    if (child_type->error_parent) {
        return child_type->error_parent;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdErrorUnion);
        assert(child_type->type_ref);
        assert(child_type->di_type);

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "%%%s", buf_ptr(&child_type->name));

        entry->data.error.child_type = child_type;

        entry->deep_const = child_type->deep_const;

        if (!type_has_bits(child_type)) {
            entry->type_ref = g->err_tag_type->type_ref;
            entry->di_type = g->err_tag_type->di_type;

        } else {
            LLVMTypeRef elem_types[] = {
                g->err_tag_type->type_ref,
                child_type->type_ref,
            };
            entry->type_ref = LLVMStructType(elem_types, 2, false);

            LLVMZigDIScope *compile_unit_scope = LLVMZigCompileUnitToScope(g->compile_unit);
            LLVMZigDIFile *di_file = nullptr;
            unsigned line = 0;
            entry->di_type = LLVMZigCreateReplaceableCompositeType(g->dbuilder,
                LLVMZigTag_DW_structure_type(), buf_ptr(&entry->name),
                compile_unit_scope, di_file, line);

            uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, g->err_tag_type->type_ref);
            uint64_t tag_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, g->err_tag_type->type_ref);
            uint64_t tag_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 0);

            uint64_t value_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, child_type->type_ref);
            uint64_t value_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, child_type->type_ref);
            uint64_t value_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 1);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

            LLVMZigDIType *di_element_types[] = {
                LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                        "tag", di_file, line,
                        tag_debug_size_in_bits,
                        tag_debug_align_in_bits,
                        tag_offset_in_bits,
                        0, child_type->di_type),
                LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                        "value", di_file, line,
                        value_debug_size_in_bits,
                        value_debug_align_in_bits,
                        value_offset_in_bits,
                        0, child_type->di_type),
            };

            LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                    compile_unit_scope,
                    buf_ptr(&entry->name),
                    di_file, line,
                    debug_size_in_bits,
                    debug_align_in_bits,
                    0,
                    nullptr, di_element_types, 2, 0, nullptr, "");

            LLVMZigReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
            entry->di_type = replacement_di_type;
        }

        child_type->error_parent = entry;
        return entry;
    }
}

TypeTableEntry *get_array_type(CodeGen *g, TypeTableEntry *child_type, uint64_t array_size) {
    auto existing_entry = child_type->arrays_by_size.maybe_get(array_size);
    if (existing_entry) {
        TypeTableEntry *entry = existing_entry->value;
        return entry;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdArray);
        entry->type_ref = LLVMArrayType(child_type->type_ref, array_size);
        entry->zero_bits = (array_size == 0) || child_type->zero_bits;
        entry->deep_const = child_type->deep_const;

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[%" PRIu64 "]%s", array_size, buf_ptr(&child_type->name));

        if (!entry->zero_bits) {
            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

            entry->di_type = LLVMZigCreateDebugArrayType(g->dbuilder, debug_size_in_bits,
                    debug_align_in_bits, child_type->di_type, array_size);
        }
        entry->data.array.child_type = child_type;
        entry->data.array.len = array_size;

        child_type->arrays_by_size.put(array_size, entry);
        return entry;
    }
}

static void slice_type_common_init(CodeGen *g, TypeTableEntry *child_type,
        bool is_const, TypeTableEntry *entry)
{
    TypeTableEntry *pointer_type = get_pointer_to_type(g, child_type, is_const);

    unsigned element_count = 2;
    entry->data.structure.is_packed = false;
    entry->data.structure.is_slice = true;
    entry->data.structure.src_field_count = element_count;
    entry->data.structure.gen_field_count = element_count;
    entry->data.structure.fields = allocate<TypeStructField>(element_count);
    entry->data.structure.fields[0].name = buf_create_from_str("ptr");
    entry->data.structure.fields[0].type_entry = pointer_type;
    entry->data.structure.fields[0].src_index = 0;
    entry->data.structure.fields[0].gen_index = 0;
    entry->data.structure.fields[1].name = buf_create_from_str("len");
    entry->data.structure.fields[1].type_entry = g->builtin_types.entry_usize;
    entry->data.structure.fields[1].src_index = 1;
    entry->data.structure.fields[1].gen_index = 1;
}

TypeTableEntry *get_slice_type(CodeGen *g, TypeTableEntry *child_type, bool is_const) {
    assert(child_type->id != TypeTableEntryIdInvalid);
    TypeTableEntry **parent_pointer = &child_type->unknown_size_array_parent[(is_const ? 1 : 0)];

    if (*parent_pointer) {
        return *parent_pointer;
    } else if (is_const) {
        TypeTableEntry *var_peer = get_slice_type(g, child_type, false);
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdStruct);

        entry->deep_const = child_type->deep_const;

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[]const %s", buf_ptr(&child_type->name));

        slice_type_common_init(g, child_type, is_const, entry);

        entry->type_ref = var_peer->type_ref;
        entry->di_type = var_peer->di_type;
        entry->data.structure.complete = true;

        *parent_pointer = entry;
        return entry;
    } else {
        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdStruct);

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[]%s", buf_ptr(&child_type->name));
        entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), buf_ptr(&entry->name));

        LLVMZigDIScope *compile_unit_scope = LLVMZigCompileUnitToScope(g->compile_unit);
        LLVMZigDIFile *di_file = nullptr;
        unsigned line = 0;
        entry->di_type = LLVMZigCreateReplaceableCompositeType(g->dbuilder,
            LLVMZigTag_DW_structure_type(), buf_ptr(&entry->name),
            compile_unit_scope, di_file, line);

        if (child_type->zero_bits) {
            LLVMTypeRef element_types[] = {
                g->builtin_types.entry_usize->type_ref,
            };
            LLVMStructSetBody(entry->type_ref, element_types, 1, false);

            slice_type_common_init(g, child_type, is_const, entry);

            entry->data.structure.gen_field_count = 1;
            entry->data.structure.fields[0].gen_index = -1;
            entry->data.structure.fields[1].gen_index = 0;

            TypeTableEntry *usize_type = g->builtin_types.entry_usize;
            uint64_t len_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 0);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

            LLVMZigDIType *di_element_types[] = {
                LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                        "len", di_file, line,
                        len_debug_size_in_bits,
                        len_debug_align_in_bits,
                        len_offset_in_bits,
                        0, usize_type->di_type),
            };
            LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                    compile_unit_scope,
                    buf_ptr(&entry->name),
                    di_file, line, debug_size_in_bits, debug_align_in_bits, 0,
                    nullptr, di_element_types, 1, 0, nullptr, "");

            LLVMZigReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
            entry->di_type = replacement_di_type;
        } else {
            TypeTableEntry *pointer_type = get_pointer_to_type(g, child_type, is_const);

            unsigned element_count = 2;
            LLVMTypeRef element_types[] = {
                pointer_type->type_ref,
                g->builtin_types.entry_usize->type_ref,
            };
            LLVMStructSetBody(entry->type_ref, element_types, element_count, false);

            slice_type_common_init(g, child_type, is_const, entry);


            uint64_t ptr_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, pointer_type->type_ref);
            uint64_t ptr_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, pointer_type->type_ref);
            uint64_t ptr_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 0);

            TypeTableEntry *usize_type = g->builtin_types.entry_usize;
            uint64_t len_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 1);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

            LLVMZigDIType *di_element_types[] = {
                LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                        "ptr", di_file, line,
                        ptr_debug_size_in_bits,
                        ptr_debug_align_in_bits,
                        ptr_offset_in_bits,
                        0, pointer_type->di_type),
                LLVMZigCreateDebugMemberType(g->dbuilder, LLVMZigTypeToScope(entry->di_type),
                        "len", di_file, line,
                        len_debug_size_in_bits,
                        len_debug_align_in_bits,
                        len_offset_in_bits,
                        0, usize_type->di_type),
            };
            LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                    compile_unit_scope,
                    buf_ptr(&entry->name),
                    di_file, line, debug_size_in_bits, debug_align_in_bits, 0,
                    nullptr, di_element_types, 2, 0, nullptr, "");

            LLVMZigReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
            entry->di_type = replacement_di_type;
        }


        entry->data.structure.complete = true;

        *parent_pointer = entry;
        return entry;
    }
}

TypeTableEntry *get_typedecl_type(CodeGen *g, const char *name, TypeTableEntry *child_type) {
    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdTypeDecl);

    buf_init_from_str(&entry->name, name);

    entry->deep_const = child_type->deep_const;
    entry->type_ref = child_type->type_ref;
    entry->di_type = child_type->di_type;
    entry->zero_bits = child_type->zero_bits;

    entry->data.type_decl.child_type = child_type;

    if (child_type->id == TypeTableEntryIdTypeDecl) {
        entry->data.type_decl.canonical_type = child_type->data.type_decl.canonical_type;
    } else {
        entry->data.type_decl.canonical_type = child_type;
    }

    return entry;
}

// accepts ownership of fn_type_id memory
TypeTableEntry *get_fn_type(CodeGen *g, FnTypeId *fn_type_id, bool gen_debug_info) {
    auto table_entry = g->fn_type_table.maybe_get(fn_type_id);
    if (table_entry) {
        return table_entry->value;
    }

    TypeTableEntry *fn_type = new_type_table_entry(TypeTableEntryIdFn);
    fn_type->deep_const = true;
    fn_type->data.fn.fn_type_id = *fn_type_id;
    if (fn_type_id->param_info == &fn_type_id->prealloc_param_info[0]) {
        fn_type->data.fn.fn_type_id.param_info = &fn_type->data.fn.fn_type_id.prealloc_param_info[0];
    }

    if (fn_type_id->is_cold) {
        fn_type->data.fn.calling_convention = LLVMColdCallConv;
    } else if (fn_type_id->is_extern) {
        fn_type->data.fn.calling_convention = LLVMCCallConv;
    } else {
        fn_type->data.fn.calling_convention = LLVMFastCallConv;
    }

    // populate the name of the type
    buf_resize(&fn_type->name, 0);
    const char *extern_str = fn_type_id->is_extern ? "extern " : "";
    const char *naked_str = fn_type_id->is_naked ? "naked " : "";
    const char *cold_str = fn_type_id->is_cold ? "cold " : "";
    buf_appendf(&fn_type->name, "%s%s%sfn(", extern_str, naked_str, cold_str);
    for (int i = 0; i < fn_type_id->param_count; i += 1) {
        FnTypeParamInfo *param_info = &fn_type_id->param_info[i];

        TypeTableEntry *param_type = param_info->type;
        const char *comma = (i == 0) ? "" : ", ";
        const char *noalias_str = param_info->is_noalias ? "noalias " : "";
        buf_appendf(&fn_type->name, "%s%s%s", comma, noalias_str, buf_ptr(&param_type->name));
    }

    if (fn_type_id->is_var_args) {
        const char *comma = (fn_type_id->param_count == 0) ? "" : ", ";
        buf_appendf(&fn_type->name, "%s...", comma);
    }
    buf_appendf(&fn_type->name, ")");
    if (fn_type_id->return_type->id != TypeTableEntryIdVoid) {
        buf_appendf(&fn_type->name, " -> %s", buf_ptr(&fn_type_id->return_type->name));
    }

    if (gen_debug_info) {
        // next, loop over the parameters again and compute debug information
        // and codegen information
        bool first_arg_return = !fn_type_id->is_extern && handle_is_ptr(fn_type_id->return_type);
        // +1 for maybe making the first argument the return value
        LLVMTypeRef *gen_param_types = allocate<LLVMTypeRef>(1 + fn_type_id->param_count);
        // +1 because 0 is the return type and +1 for maybe making first arg ret val
        LLVMZigDIType **param_di_types = allocate<LLVMZigDIType*>(2 + fn_type_id->param_count);
        param_di_types[0] = fn_type_id->return_type->di_type;
        int gen_param_index = 0;
        TypeTableEntry *gen_return_type;
        if (!type_has_bits(fn_type_id->return_type)) {
            gen_return_type = g->builtin_types.entry_void;
        } else if (first_arg_return) {
            TypeTableEntry *gen_type = get_pointer_to_type(g, fn_type_id->return_type, false);
            gen_param_types[gen_param_index] = gen_type->type_ref;
            gen_param_index += 1;
            // after the gen_param_index += 1 because 0 is the return type
            param_di_types[gen_param_index] = gen_type->di_type;
            gen_return_type = g->builtin_types.entry_void;
        } else {
            gen_return_type = fn_type_id->return_type;
        }
        fn_type->data.fn.gen_return_type = gen_return_type;

        fn_type->data.fn.gen_param_info = allocate<FnGenParamInfo>(fn_type_id->param_count);
        for (int i = 0; i < fn_type_id->param_count; i += 1) {
            FnTypeParamInfo *src_param_info = &fn_type->data.fn.fn_type_id.param_info[i];
            TypeTableEntry *type_entry = src_param_info->type;
            FnGenParamInfo *gen_param_info = &fn_type->data.fn.gen_param_info[i];

            gen_param_info->src_index = i;
            gen_param_info->gen_index = -1;

            assert(type_is_complete(type_entry));
            if (type_has_bits(type_entry)) {
                TypeTableEntry *gen_type;
                if (handle_is_ptr(type_entry)) {
                    gen_type = get_pointer_to_type(g, type_entry, true);
                    gen_param_info->is_byval = true;
                } else {
                    gen_type = type_entry;
                }
                gen_param_types[gen_param_index] = gen_type->type_ref;
                gen_param_info->gen_index = gen_param_index;
                gen_param_info->type = gen_type;

                gen_param_index += 1;

                // after the gen_param_index += 1 because 0 is the return type
                param_di_types[gen_param_index] = gen_type->di_type;
            }
        }

        fn_type->data.fn.gen_param_count = gen_param_index;

        fn_type->data.fn.raw_type_ref = LLVMFunctionType(gen_return_type->type_ref,
                gen_param_types, gen_param_index, fn_type_id->is_var_args);
        fn_type->type_ref = LLVMPointerType(fn_type->data.fn.raw_type_ref, 0);
        fn_type->di_type = LLVMZigCreateSubroutineType(g->dbuilder, param_di_types, gen_param_index + 1, 0);
    }

    g->fn_type_table.put(&fn_type->data.fn.fn_type_id, fn_type);

    return fn_type;
}

static TypeTableEntryId container_to_type(ContainerKind kind) {
    switch (kind) {
        case ContainerKindStruct:
            return TypeTableEntryIdStruct;
        case ContainerKindEnum:
            return TypeTableEntryIdEnum;
        case ContainerKindUnion:
            return TypeTableEntryIdUnion;
    }
    zig_unreachable();
}

TypeTableEntry *get_partial_container_type(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        ContainerKind kind, AstNode *decl_node, const char *name)
{
    TypeTableEntryId type_id = container_to_type(kind);
    TypeTableEntry *entry = new_container_type_entry(type_id, decl_node, context);

    switch (kind) {
        case ContainerKindStruct:
            entry->data.structure.decl_node = decl_node;
            break;
        case ContainerKindEnum:
            entry->data.enumeration.decl_node = decl_node;
            break;
        case ContainerKindUnion:
            entry->data.unionation.decl_node = decl_node;
            break;
    }

    unsigned line = decl_node ? decl_node->line : 0;

    entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), name);
    entry->di_type = LLVMZigCreateReplaceableCompositeType(g->dbuilder,
        LLVMZigTag_DW_structure_type(), name,
        LLVMZigFileToScope(import->di_file), import->di_file, line + 1);

    buf_init_from_str(&entry->name, name);

    return entry;
}


TypeTableEntry *get_underlying_type(TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdTypeDecl) {
        return type_entry->data.type_decl.canonical_type;
    } else {
        return type_entry;
    }
}

// If the node does not have a constant expression value with a metatype, generates an error
// and returns invalid type. Otherwise, returns the type of the constant expression value.
// Must be called after analyze_expression on the same node.
static TypeTableEntry *resolve_type(CodeGen *g, AstNode *node) {
    if (node->type == NodeTypeSymbol && node->data.symbol_expr.override_type_entry) {
        return node->data.symbol_expr.override_type_entry;
    }
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
        add_node_error(g, node, buf_sprintf("unable to evaluate constant expression"));
        return g->builtin_types.entry_invalid;
    }

    return const_val->data.x_type;
}

static TypeTableEntry *analyze_type_expr_pointer_only(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node, bool pointer_only)
{
    AstNode **node_ptr = node->parent_field;
    analyze_expression_pointer_only(g, import, context, nullptr, *node_ptr, pointer_only);
    return resolve_type(g, *node_ptr);
}

// Calls analyze_expression on node, and then resolve_type.
static TypeTableEntry *analyze_type_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    return analyze_type_expr_pointer_only(g, import, context, node, false);
}

static bool fn_wants_full_static_eval(FnTableEntry *fn_table_entry) {
    assert(fn_table_entry);
    AstNodeFnProto *fn_proto = &fn_table_entry->proto_node->data.fn_proto;
    return fn_proto->inline_arg_count == fn_proto->params.length && fn_table_entry->want_pure == WantPureTrue;
}

// fn_table_entry is populated if and only if there is a function definition for this prototype
static TypeTableEntry *analyze_fn_proto_type(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node, bool is_naked, bool is_cold, FnTableEntry *fn_table_entry)
{
    assert(node->type == NodeTypeFnProto);
    AstNodeFnProto *fn_proto = &node->data.fn_proto;

    if (fn_proto->skip) {
        return g->builtin_types.entry_invalid;
    }

    FnTypeId fn_type_id = {0};
    fn_type_id.is_extern = fn_proto->is_extern || (fn_proto->top_level_decl.visib_mod == VisibModExport);
    fn_type_id.is_naked = is_naked;
    fn_type_id.is_cold = is_cold;
    fn_type_id.param_count = fn_proto->params.length;

    if (fn_type_id.param_count > fn_type_id_prealloc_param_info_count) {
        fn_type_id.param_info = allocate_nonzero<FnTypeParamInfo>(fn_type_id.param_count);
    } else {
        fn_type_id.param_info = &fn_type_id.prealloc_param_info[0];
    }

    fn_type_id.is_var_args = fn_proto->is_var_args;
    fn_type_id.return_type = analyze_type_expr(g, import, context, fn_proto->return_type);

    switch (fn_type_id.return_type->id) {
        case TypeTableEntryIdInvalid:
            fn_proto->skip = true;
            break;
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdGenericFn:
            fn_proto->skip = true;
            add_node_error(g, fn_proto->return_type,
                buf_sprintf("return type '%s' not allowed", buf_ptr(&fn_type_id.return_type->name)));
            break;
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
            break;
    }

    for (int i = 0; i < fn_type_id.param_count; i += 1) {
        AstNode *child = fn_proto->params.at(i);
        assert(child->type == NodeTypeParamDecl);

        TypeTableEntry *type_entry = analyze_type_expr(g, import, context,
                child->data.param_decl.type);
        switch (type_entry->id) {
            case TypeTableEntryIdInvalid:
                fn_proto->skip = true;
                break;
            case TypeTableEntryIdNumLitFloat:
            case TypeTableEntryIdNumLitInt:
            case TypeTableEntryIdUndefLit:
            case TypeTableEntryIdUnreachable:
            case TypeTableEntryIdNamespace:
            case TypeTableEntryIdGenericFn:
                fn_proto->skip = true;
                add_node_error(g, child->data.param_decl.type,
                    buf_sprintf("parameter of type '%s' not allowed", buf_ptr(&type_entry->name)));
                break;
            case TypeTableEntryIdMetaType:
                if (!child->data.param_decl.is_inline) {
                    fn_proto->skip = true;
                    add_node_error(g, child->data.param_decl.type,
                        buf_sprintf("parameter of type '%s' must be declared inline",
                        buf_ptr(&type_entry->name)));
                }
                break;
            case TypeTableEntryIdVoid:
            case TypeTableEntryIdBool:
            case TypeTableEntryIdInt:
            case TypeTableEntryIdFloat:
            case TypeTableEntryIdPointer:
            case TypeTableEntryIdArray:
            case TypeTableEntryIdStruct:
            case TypeTableEntryIdMaybe:
            case TypeTableEntryIdErrorUnion:
            case TypeTableEntryIdPureError:
            case TypeTableEntryIdEnum:
            case TypeTableEntryIdUnion:
            case TypeTableEntryIdFn:
            case TypeTableEntryIdTypeDecl:
                break;
        }
        if (type_entry->id == TypeTableEntryIdInvalid) {
            fn_proto->skip = true;
        }
        FnTypeParamInfo *param_info = &fn_type_id.param_info[i];
        param_info->type = type_entry;
        param_info->is_noalias = child->data.param_decl.is_noalias;
    }

    if (fn_proto->skip) {
        return g->builtin_types.entry_invalid;
    }

    if (fn_table_entry && fn_type_id.return_type->id == TypeTableEntryIdMetaType) {
        fn_table_entry->want_pure = WantPureTrue;
        fn_table_entry->want_pure_return_type = fn_proto->return_type;

        ErrorMsg *err_msg = nullptr;
        for (int i = 0; i < fn_proto->params.length; i += 1) {
            AstNode *param_decl_node = fn_proto->params.at(i);
            assert(param_decl_node->type == NodeTypeParamDecl);
            if (!param_decl_node->data.param_decl.is_inline) {
                if (!err_msg) {
                    err_msg = add_node_error(g, fn_proto->return_type,
                        buf_sprintf("function with return type '%s' must declare all parameters inline",
                        buf_ptr(&fn_type_id.return_type->name)));
                }
                add_error_note(g, err_msg, param_decl_node,
                    buf_sprintf("non-inline parameter here"));
            }
        }
        if (err_msg) {
            fn_proto->skip = true;
            return g->builtin_types.entry_invalid;
        }
    }


    bool gen_debug_info = !(fn_table_entry && fn_wants_full_static_eval(fn_table_entry));
    return get_fn_type(g, &fn_type_id, gen_debug_info);
}

static Buf *resolve_const_expr_str(CodeGen *g, ImportTableEntry *import, BlockContext *context, AstNode **node) {
    TypeTableEntry *str_type = get_slice_type(g, g->builtin_types.entry_u8, true);
    TypeTableEntry *resolved_type = analyze_expression(g, import, context, str_type, *node);

    if (resolved_type->id == TypeTableEntryIdInvalid) {
        return nullptr;
    }

    ConstExprValue *const_str_val = &get_resolved_expr(*node)->const_val;

    if (!const_str_val->ok) {
        add_node_error(g, *node, buf_sprintf("unable to evaluate constant expression"));
        return nullptr;
    }

    ConstExprValue *ptr_field = const_str_val->data.x_struct.fields[0];
    uint64_t len = ptr_field->data.x_ptr.len;
    Buf *result = buf_alloc();
    for (uint64_t i = 0; i < len; i += 1) {
        ConstExprValue *char_val = ptr_field->data.x_ptr.ptr[i];
        uint64_t big_c = char_val->data.x_bignum.data.x_uint;
        assert(big_c <= UINT8_MAX);
        uint8_t c = big_c;
        buf_append_char(result, c);
    }
    return result;
}

static bool resolve_const_expr_bool(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode **node, bool *value)
{
    TypeTableEntry *resolved_type = analyze_expression(g, import, context, g->builtin_types.entry_bool, *node);

    if (resolved_type->id == TypeTableEntryIdInvalid) {
        return false;
    }

    ConstExprValue *const_bool_val = &get_resolved_expr(*node)->const_val;

    if (!const_bool_val->ok) {
        add_node_error(g, *node, buf_sprintf("unable to evaluate constant expression"));
        return false;
    }

    *value = const_bool_val->data.x_bool;
    return true;
}

static void resolve_function_proto(CodeGen *g, AstNode *node, FnTableEntry *fn_table_entry,
        ImportTableEntry *import, BlockContext *containing_context)
{
    assert(node->type == NodeTypeFnProto);
    AstNodeFnProto *fn_proto = &node->data.fn_proto;

    if (fn_proto->skip) {
        return;
    }

    bool is_cold = false;
    bool is_naked = false;
    bool is_test = false;
    bool is_noinline = false;

    if (fn_proto->top_level_decl.directives) {
        for (int i = 0; i < fn_proto->top_level_decl.directives->length; i += 1) {
            AstNode *directive_node = fn_proto->top_level_decl.directives->at(i);
            Buf *name = directive_node->data.directive.name;

            if (buf_eql_str(name, "attribute")) {
                if (fn_table_entry->fn_def_node) {
                    Buf *attr_name = resolve_const_expr_str(g, import, import->block_context,
                            &directive_node->data.directive.expr);
                    if (attr_name) {
                        if (buf_eql_str(attr_name, "naked")) {
                            is_naked = true;
                        } else if (buf_eql_str(attr_name, "noinline")) {
                            is_noinline = true;
                        } else if (buf_eql_str(attr_name, "cold")) {
                            is_cold = true;
                        } else if (buf_eql_str(attr_name, "test")) {
                            is_test = true;
                            g->test_fn_count += 1;
                        } else {
                            add_node_error(g, directive_node,
                                    buf_sprintf("invalid function attribute: '%s'", buf_ptr(name)));
                        }
                    }
                } else {
                    add_node_error(g, directive_node,
                            buf_sprintf("invalid function attribute: '%s'", buf_ptr(name)));
                }
            } else if (buf_eql_str(name, "debug_safety")) {
                if (!fn_table_entry->fn_def_node) {
                    add_node_error(g, directive_node,
                        buf_sprintf("#debug_safety valid only on function definitions"));
                } else {
                    bool enable;
                    bool ok = resolve_const_expr_bool(g, import, import->block_context,
                            &directive_node->data.directive.expr, &enable);
                    if (ok && !enable) {
                        fn_table_entry->safety_off = true;
                    }
                }
            } else if (buf_eql_str(name, "condition")) {
                if (fn_proto->top_level_decl.visib_mod == VisibModExport) {
                    bool include;
                    bool ok = resolve_const_expr_bool(g, import, import->block_context,
                            &directive_node->data.directive.expr, &include);
                    if (ok && !include) {
                        fn_proto->top_level_decl.visib_mod = VisibModPub;
                    }
                } else {
                    add_node_error(g, directive_node,
                        buf_sprintf("#condition valid only on exported symbols"));
                }
            } else if (buf_eql_str(name, "static_eval_enable")) {
                if (!fn_table_entry->fn_def_node) {
                    add_node_error(g, directive_node,
                        buf_sprintf("#static_val_enable valid only on function definitions"));
                } else {
                    bool enable;
                    bool ok = resolve_const_expr_bool(g, import, import->block_context,
                            &directive_node->data.directive.expr, &enable);
                    if (!ok || !enable) {
                        fn_table_entry->want_pure = WantPureFalse;
                    } else if (ok && enable) {
                        fn_table_entry->want_pure = WantPureTrue;
                        fn_table_entry->want_pure_attr_node = directive_node->data.directive.expr;
                    }
                }
            } else {
                add_node_error(g, directive_node,
                        buf_sprintf("invalid directive: '%s'", buf_ptr(name)));
            }
        }
    }

    bool is_internal = (fn_proto->top_level_decl.visib_mod != VisibModExport);
    bool is_c_compat = !is_internal || fn_proto->is_extern;
    fn_table_entry->internal_linkage = !is_c_compat;



    TypeTableEntry *fn_type = analyze_fn_proto_type(g, import, containing_context, nullptr, node,
            is_naked, is_cold, fn_table_entry);

    fn_table_entry->type_entry = fn_type;
    fn_table_entry->is_test = is_test;

    if (fn_type->id == TypeTableEntryIdInvalid) {
        fn_proto->skip = true;
        return;
    }

    if (fn_proto->is_inline && is_noinline) {
        add_node_error(g, node, buf_sprintf("function is both inline and noinline"));
        fn_proto->skip = true;
        return;
    } else if (fn_proto->is_inline) {
        fn_table_entry->fn_inline = FnInlineAlways;
    } else if (is_noinline) {
        fn_table_entry->fn_inline = FnInlineNever;
    }


    Buf *symbol_name;
    if (is_c_compat) {
        symbol_name = &fn_table_entry->symbol_name;
    } else {
        symbol_name = buf_sprintf("_%s", buf_ptr(&fn_table_entry->symbol_name));
    }

    if (fn_table_entry->fn_def_node) {
        BlockContext *context = new_block_context(fn_table_entry->fn_def_node, containing_context);
        fn_table_entry->fn_def_node->data.fn_def.block_context = context;
    }

    if (!fn_wants_full_static_eval(fn_table_entry)) {
        fn_table_entry->fn_value = LLVMAddFunction(g->module, buf_ptr(symbol_name), fn_type->data.fn.raw_type_ref);

        switch (fn_table_entry->fn_inline) {
            case FnInlineAlways:
                LLVMAddFunctionAttr(fn_table_entry->fn_value, LLVMAlwaysInlineAttribute);
                break;
            case FnInlineNever:
                LLVMAddFunctionAttr(fn_table_entry->fn_value, LLVMNoInlineAttribute);
                break;
            case FnInlineAuto:
                break;
        }
        if (fn_type->data.fn.fn_type_id.is_naked) {
            LLVMAddFunctionAttr(fn_table_entry->fn_value, LLVMNakedAttribute);
        }

        LLVMSetLinkage(fn_table_entry->fn_value, fn_table_entry->internal_linkage ?
                LLVMInternalLinkage : LLVMExternalLinkage);

        if (fn_type->data.fn.fn_type_id.return_type->id == TypeTableEntryIdUnreachable) {
            LLVMAddFunctionAttr(fn_table_entry->fn_value, LLVMNoReturnAttribute);
        }
        LLVMSetFunctionCallConv(fn_table_entry->fn_value, fn_type->data.fn.calling_convention);
        if (!fn_table_entry->is_extern) {
            LLVMAddFunctionAttr(fn_table_entry->fn_value, LLVMNoUnwindAttribute);
        }
        if (!g->is_release_build && !fn_proto->is_inline) {
            ZigLLVMAddFunctionAttr(fn_table_entry->fn_value, "no-frame-pointer-elim", "true");
            ZigLLVMAddFunctionAttr(fn_table_entry->fn_value, "no-frame-pointer-elim-non-leaf", nullptr);
        }

        if (fn_table_entry->fn_def_node) {
            // Add debug info.
            unsigned line_number = node->line + 1;
            unsigned scope_line = line_number;
            bool is_definition = fn_table_entry->fn_def_node != nullptr;
            unsigned flags = 0;
            bool is_optimized = g->is_release_build;
            LLVMZigDISubprogram *subprogram = LLVMZigCreateFunction(g->dbuilder,
                containing_context->di_scope, buf_ptr(&fn_table_entry->symbol_name), "",
                import->di_file, line_number,
                fn_type->di_type, fn_table_entry->internal_linkage,
                is_definition, scope_line, flags, is_optimized, nullptr);

            fn_table_entry->fn_def_node->data.fn_def.block_context->di_scope = LLVMZigSubprogramToScope(subprogram);
            ZigLLVMFnSetSubprogram(fn_table_entry->fn_value, subprogram);
        }
    }
}

static void resolve_enum_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *enum_type) {
    // if you change this logic you likely must also change similar logic in parseh.cpp
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

    assert(decl_node->type == NodeTypeContainerDecl);
    assert(enum_type->di_type);

    enum_type->deep_const = true;

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

    BlockContext *context = enum_type->data.enumeration.block_context;

    // set temporary flag
    enum_type->data.enumeration.embedded_in_current = true;

    int gen_field_index = 0;
    for (uint32_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.struct_decl.fields.at(i);
        TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[i];
        type_enum_field->name = field_node->data.struct_field.name;
        TypeTableEntry *field_type = analyze_type_expr(g, import, context,
                field_node->data.struct_field.type);
        type_enum_field->type_entry = field_type;
        type_enum_field->value = i;

        if (!field_type->deep_const) {
            enum_type->deep_const = false;
        }


        di_enumerators[i] = LLVMZigCreateDebugEnumerator(g->dbuilder, buf_ptr(type_enum_field->name), i);

        if (field_type->id == TypeTableEntryIdStruct) {
            resolve_struct_type(g, import, field_type);
        } else if (field_type->id == TypeTableEntryIdEnum) {
            resolve_enum_type(g, import, field_type);
        } else if (field_type->id == TypeTableEntryIdInvalid) {
            enum_type->data.enumeration.is_invalid = true;
            continue;
        } else if (!type_has_bits(field_type)) {
            continue;
        }

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, field_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, field_type->type_ref);

        union_inner_di_types[gen_field_index] = LLVMZigCreateDebugMemberType(g->dbuilder,
                LLVMZigTypeToScope(enum_type->di_type), buf_ptr(type_enum_field->name),
                import->di_file, field_node->line + 1,
                debug_size_in_bits,
                debug_align_in_bits,
                0,
                0, field_type->di_type);

        biggest_align_in_bits = max(biggest_align_in_bits, debug_align_in_bits);

        if (!biggest_union_member ||
            debug_size_in_bits > biggest_union_member_size_in_bits)
        {
            biggest_union_member = field_type;
            biggest_union_member_size_in_bits = debug_size_in_bits;
        }

        gen_field_index += 1;
    }

    // unset temporary flag
    enum_type->data.enumeration.embedded_in_current = false;
    enum_type->data.enumeration.complete = true;

    if (!enum_type->data.enumeration.is_invalid) {
        enum_type->data.enumeration.gen_field_count = gen_field_index;
        enum_type->data.enumeration.union_type = biggest_union_member;

        TypeTableEntry *tag_type_entry = get_smallest_unsigned_int_type(g, field_count);
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
            uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, tag_type_entry->type_ref);
            uint64_t tag_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, tag_type_entry->type_ref);
            LLVMZigDIType *tag_di_type = LLVMZigCreateDebugEnumerationType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "AnonEnum", import->di_file, decl_node->line + 1,
                    tag_debug_size_in_bits, tag_debug_align_in_bits, di_enumerators, field_count,
                    tag_type_entry->di_type, "");

            // create debug type for union
            LLVMZigDIType *union_di_type = LLVMZigCreateDebugUnionType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "AnonUnion", import->di_file, decl_node->line + 1,
                    biggest_union_member_size_in_bits, biggest_align_in_bits, 0, union_inner_di_types,
                    gen_field_index, 0, "");

            // create debug types for members of root struct
            uint64_t tag_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, enum_type->type_ref, 0);
            LLVMZigDIType *tag_member_di_type = LLVMZigCreateDebugMemberType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "tag_field",
                    import->di_file, decl_node->line + 1,
                    tag_debug_size_in_bits,
                    tag_debug_align_in_bits,
                    tag_offset_in_bits,
                    0, tag_di_type);

            uint64_t union_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, enum_type->type_ref, 1);
            LLVMZigDIType *union_member_di_type = LLVMZigCreateDebugMemberType(g->dbuilder,
                    LLVMZigTypeToScope(enum_type->di_type), "union_field",
                    import->di_file, decl_node->line + 1,
                    biggest_union_member_size_in_bits,
                    biggest_align_in_bits,
                    union_offset_in_bits,
                    0, union_di_type);

            // create debug type for root struct
            LLVMZigDIType *di_root_members[] = {
                tag_member_di_type,
                union_member_di_type,
            };


            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, enum_type->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, enum_type->type_ref);
            LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
                    LLVMZigFileToScope(import->di_file),
                    buf_ptr(decl_node->data.struct_decl.name),
                    import->di_file, decl_node->line + 1,
                    debug_size_in_bits,
                    debug_align_in_bits,
                    0, nullptr, di_root_members, 2, 0, nullptr, "");

            LLVMZigReplaceTemporary(g->dbuilder, enum_type->di_type, replacement_di_type);
            enum_type->di_type = replacement_di_type;
        } else {
            // create llvm type for root struct
            enum_type->type_ref = tag_type_entry->type_ref;

            // create debug type for tag
            uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, tag_type_entry->type_ref);
            uint64_t tag_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, tag_type_entry->type_ref);
            LLVMZigDIType *tag_di_type = LLVMZigCreateDebugEnumerationType(g->dbuilder,
                    LLVMZigFileToScope(import->di_file), buf_ptr(decl_node->data.struct_decl.name),
                    import->di_file, decl_node->line + 1,
                    tag_debug_size_in_bits,
                    tag_debug_align_in_bits,
                    di_enumerators, field_count,
                    tag_type_entry->di_type, "");

            LLVMZigReplaceTemporary(g->dbuilder, enum_type->di_type, tag_di_type);
            enum_type->di_type = tag_di_type;

        }

    }
}

static void resolve_struct_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *struct_type) {
    // if you change the logic of this function likely you must make a similar change in
    // parseh.cpp
    assert(struct_type->id == TypeTableEntryIdStruct);

    AstNode *decl_node = struct_type->data.structure.decl_node;

    if (struct_type->data.structure.embedded_in_current) {
        struct_type->data.structure.is_invalid = true;
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

    assert(decl_node->type == NodeTypeContainerDecl);
    assert(struct_type->di_type);

    struct_type->deep_const = true;

    int field_count = decl_node->data.struct_decl.fields.length;

    struct_type->data.structure.src_field_count = field_count;
    struct_type->data.structure.fields = allocate<TypeStructField>(field_count);

    // we possibly allocate too much here since gen_field_count can be lower than field_count.
    // the only problem is potential wasted space though.
    LLVMTypeRef *element_types = allocate<LLVMTypeRef>(field_count);

    // this field should be set to true only during the recursive calls to resolve_struct_type
    struct_type->data.structure.embedded_in_current = true;

    BlockContext *context = struct_type->data.structure.block_context;

    int gen_field_index = 0;
    for (int i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.struct_decl.fields.at(i);
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        type_struct_field->name = field_node->data.struct_field.name;
        TypeTableEntry *field_type = analyze_type_expr(g, import, context,
                field_node->data.struct_field.type);
        type_struct_field->type_entry = field_type;
        type_struct_field->src_index = i;
        type_struct_field->gen_index = -1;

        if (!field_type->deep_const) {
            struct_type->deep_const = false;
        }

        if (field_type->id == TypeTableEntryIdStruct) {
            resolve_struct_type(g, import, field_type);
        } else if (field_type->id == TypeTableEntryIdEnum) {
            resolve_enum_type(g, import, field_type);
        } else if (field_type->id == TypeTableEntryIdInvalid) {
            struct_type->data.structure.is_invalid = true;
            continue;
        } else if (!type_has_bits(field_type)) {
            continue;
        }

        type_struct_field->gen_index = gen_field_index;

        element_types[gen_field_index] = field_type->type_ref;
        assert(element_types[gen_field_index]);

        gen_field_index += 1;
    }
    struct_type->data.structure.embedded_in_current = false;

    struct_type->data.structure.gen_field_count = gen_field_index;
    struct_type->data.structure.complete = true;

    if (struct_type->data.structure.is_invalid) {
        return;
    }

    int gen_field_count = gen_field_index;
    LLVMStructSetBody(struct_type->type_ref, element_types, gen_field_count, false);

    LLVMZigDIType **di_element_types = allocate<LLVMZigDIType*>(gen_field_count);

    for (int i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.struct_decl.fields.at(i);
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        gen_field_index = type_struct_field->gen_index;
        if (gen_field_index == -1) {
            continue;
        }

        TypeTableEntry *field_type = type_struct_field->type_entry;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, field_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, field_type->type_ref);
        uint64_t debug_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, struct_type->type_ref,
                gen_field_index);
        di_element_types[gen_field_index] = LLVMZigCreateDebugMemberType(g->dbuilder,
                LLVMZigTypeToScope(struct_type->di_type), buf_ptr(type_struct_field->name),
                import->di_file, field_node->line + 1,
                debug_size_in_bits,
                debug_align_in_bits,
                debug_offset_in_bits,
                0, field_type->di_type);

        assert(di_element_types[gen_field_index]);
    }


    uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, struct_type->type_ref);
    uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, struct_type->type_ref);
    LLVMZigDIType *replacement_di_type = LLVMZigCreateDebugStructType(g->dbuilder,
            LLVMZigFileToScope(import->di_file),
            buf_ptr(decl_node->data.struct_decl.name),
            import->di_file, decl_node->line + 1,
            debug_size_in_bits,
            debug_align_in_bits,
            0, nullptr, di_element_types, gen_field_count, 0, nullptr, "");

    LLVMZigReplaceTemporary(g->dbuilder, struct_type->di_type, replacement_di_type);
    struct_type->di_type = replacement_di_type;

    struct_type->zero_bits = (debug_size_in_bits == 0);
}

static void resolve_union_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *enum_type) {
    zig_panic("TODO");
}

static void get_fully_qualified_decl_name(Buf *buf, AstNode *decl_node, uint8_t sep) {
    TopLevelDecl *tld = get_as_top_level_decl(decl_node);
    AstNode *parent_decl = tld->parent_decl;

    if (parent_decl) {
        get_fully_qualified_decl_name(buf, parent_decl, sep);
        buf_append_char(buf, sep);
        buf_append_buf(buf, tld->name);
    } else {
        buf_init_from_buf(buf, tld->name);
    }
}

static void preview_generic_fn_proto(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeContainerDecl);

    if (node->data.struct_decl.generic_params_is_var_args) {
        add_node_error(g, node, buf_sprintf("generic parameters cannot be var args"));
        node->data.struct_decl.skip = true;
        node->data.struct_decl.generic_fn_type = g->builtin_types.entry_invalid;
        return;
    }

    node->data.struct_decl.generic_fn_type = get_generic_fn_type(g, node);
}

static void preview_fn_proto_instance(CodeGen *g, ImportTableEntry *import, AstNode *proto_node,
        BlockContext *containing_context)
{
    assert(proto_node->type == NodeTypeFnProto);

    if (proto_node->data.fn_proto.skip) {
        return;
    }

    bool is_generic_instance = proto_node->data.fn_proto.generic_proto_node;
    bool is_generic_fn = proto_node->data.fn_proto.inline_arg_count > 0;
    assert(!is_generic_instance || !is_generic_fn);

    AstNode *parent_decl = proto_node->data.fn_proto.top_level_decl.parent_decl;
    Buf *proto_name = proto_node->data.fn_proto.name;

    AstNode *fn_def_node = proto_node->data.fn_proto.fn_def_node;
    bool is_extern = proto_node->data.fn_proto.is_extern;

    assert(!is_extern || !is_generic_instance);

    if (fn_def_node && proto_node->data.fn_proto.is_var_args) {
        add_node_error(g, proto_node,
                buf_sprintf("variadic arguments only allowed in extern function declarations"));
    }

    FnTableEntry *fn_table_entry = allocate<FnTableEntry>(1);
    fn_table_entry->import_entry = import;
    fn_table_entry->proto_node = proto_node;
    fn_table_entry->fn_def_node = fn_def_node;
    fn_table_entry->is_extern = is_extern;
    fn_table_entry->is_pure = fn_def_node != nullptr;

    get_fully_qualified_decl_name(&fn_table_entry->symbol_name, proto_node, '_');

    proto_node->data.fn_proto.fn_table_entry = fn_table_entry;

    if (is_generic_fn) {
        fn_table_entry->type_entry = get_generic_fn_type(g, proto_node);

        if (is_extern || proto_node->data.fn_proto.top_level_decl.visib_mod == VisibModExport) {
            for (int i = 0; i < proto_node->data.fn_proto.params.length; i += 1) {
                AstNode *param_decl_node = proto_node->data.fn_proto.params.at(i);
                if (param_decl_node->data.param_decl.is_inline) {
                    proto_node->data.fn_proto.skip = true;
                    add_node_error(g, param_decl_node,
                            buf_sprintf("inline parameter not allowed in extern function"));
                }
            }
        }


    } else {
        resolve_function_proto(g, proto_node, fn_table_entry, import, containing_context);

        if (!fn_wants_full_static_eval(fn_table_entry)) {
            g->fn_protos.append(fn_table_entry);

            if (fn_def_node) {
                g->fn_defs.append(fn_table_entry);
            }

            bool is_main_fn = !is_generic_instance &&
                !parent_decl && (import == g->root_import) &&
                buf_eql_str(proto_name, "main");
            if (is_main_fn) {
                g->main_fn = fn_table_entry;
            }

            if (is_main_fn && !g->link_libc) {
                TypeTableEntry *err_void = get_error_type(g, g->builtin_types.entry_void);
                TypeTableEntry *actual_return_type = fn_table_entry->type_entry->data.fn.fn_type_id.return_type;
                if (actual_return_type != err_void) {
                    AstNode *return_type_node = fn_table_entry->proto_node->data.fn_proto.return_type;
                    add_node_error(g, return_type_node,
                            buf_sprintf("expected return type of main to be '%%void', instead is '%s'",
                                buf_ptr(&actual_return_type->name)));
                }
            }
        }
    }
}

static void scan_struct_decl(CodeGen *g, ImportTableEntry *import, BlockContext *context, AstNode *node) {
    assert(node->type == NodeTypeContainerDecl);

    if (node->data.struct_decl.type_entry) {
        // already scanned; we can ignore. This can happen from importing from an .h file.
        return;
    }

    Buf *name = node->data.struct_decl.name;
    TypeTableEntry *container_type = get_partial_container_type(g, import, context,
            node->data.struct_decl.kind, node, buf_ptr(name));
    node->data.struct_decl.type_entry = container_type;

    // handle the member function definitions independently
    for (int i = 0; i < node->data.struct_decl.decls.length; i += 1) {
        AstNode *child_node = node->data.struct_decl.decls.at(i);
        get_as_top_level_decl(child_node)->parent_decl = node;
        BlockContext *child_context = get_container_block_context(container_type);
        scan_decls(g, import, child_context, child_node);
    }
}

static void resolve_struct_instance(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    TypeTableEntry *type_entry = node->data.struct_decl.type_entry;
    assert(type_entry);

    // struct/enum member fns will get resolved independently

    switch (node->data.struct_decl.kind) {
        case ContainerKindStruct:
            resolve_struct_type(g, import, type_entry);
            break;
        case ContainerKindEnum:
            resolve_enum_type(g, import, type_entry);
            break;
        case ContainerKindUnion:
            resolve_union_type(g, import, type_entry);
            break;
    }
}

static void resolve_struct_decl(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    if (node->data.struct_decl.generic_params.length > 0) {
        return preview_generic_fn_proto(g, import, node);
    } else {
        return resolve_struct_instance(g, import, node);
    }
}

static void preview_error_value_decl(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeErrorValueDecl);

    ErrorTableEntry *err = allocate<ErrorTableEntry>(1);

    err->decl_node = node;
    buf_init_from_buf(&err->name, node->data.error_value_decl.name);

    auto existing_entry = g->error_table.maybe_get(&err->name);
    if (existing_entry) {
        // duplicate error definitions allowed and they get the same value
        err->value = existing_entry->value->value;
    } else {
        int error_value_count = g->error_decls.length;
        assert((uint32_t)error_value_count < (((uint32_t)1) << (uint32_t)g->err_tag_type->data.integral.bit_count));
        err->value = error_value_count;
        g->error_decls.append(node);
        g->error_table.put(&err->name, err);
    }

    node->data.error_value_decl.err = err;
    node->data.error_value_decl.top_level_decl.resolution = TldResolutionOk;
}

static void resolve_top_level_decl(CodeGen *g, AstNode *node, bool pointer_only) {
    TopLevelDecl *tld = get_as_top_level_decl(node);
    if (tld->resolution != TldResolutionUnresolved) {
        return;
    }
    if (pointer_only && node->type == NodeTypeContainerDecl) {
        return;
    }

    ImportTableEntry *import = tld->import;
    assert(import);

    if (tld->dep_loop_flag) {
        add_node_error(g, node, buf_sprintf("'%s' depends on itself", buf_ptr(tld->name)));
        tld->resolution = TldResolutionInvalid;
        return;
    } else {
        tld->dep_loop_flag = true;
    }

    switch (node->type) {
        case NodeTypeFnProto:
            preview_fn_proto_instance(g, import, node, node->block_context);
            break;
        case NodeTypeContainerDecl:
            resolve_struct_decl(g, import, node);
            break;
        case NodeTypeVariableDeclaration:
            {
                AstNodeVariableDeclaration *variable_declaration = &node->data.variable_declaration;
                VariableTableEntry *var = analyze_variable_declaration_raw(g, import, node->block_context,
                        node, variable_declaration, false, node, false);

                g->global_vars.append(var);
                break;
            }
        case NodeTypeTypeDecl:
            {
                AstNode *type_node = node->data.type_decl.child_type;
                Buf *decl_name = node->data.type_decl.symbol;

                TypeTableEntry *entry;
                if (node->data.type_decl.override_type) {
                    entry = node->data.type_decl.override_type;
                } else {
                    TypeTableEntry *child_type = analyze_type_expr(g, import, import->block_context, type_node);
                    if (child_type->id == TypeTableEntryIdInvalid) {
                        entry = child_type;
                    } else {
                        entry = get_typedecl_type(g, buf_ptr(decl_name), child_type);
                    }
                }
                node->data.type_decl.child_type_entry = entry;
                break;
            }
        case NodeTypeErrorValueDecl:
            break;
        case NodeTypeUse:
            zig_panic("TODO resolve_top_level_decl NodeTypeUse");
            break;
        case NodeTypeFnDef:
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeDefer:
        case NodeTypeRoot:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeUnwrapErrorExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeZeroesLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeForExpr:
        case NodeTypeSwitchExpr:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
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
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
            zig_unreachable();
    }

    tld->resolution = TldResolutionOk;
    tld->dep_loop_flag = false;
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

static bool type_has_codegen_value(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdGenericFn:
            return false;

        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
            return true;

        case TypeTableEntryIdTypeDecl:
            return type_has_codegen_value(type_entry->data.type_decl.canonical_type);
    }
    zig_unreachable();
}

static void add_global_const_expr(CodeGen *g, AstNode *expr_node) {
    Expr *expr = get_resolved_expr(expr_node);
    if (expr->const_val.ok &&
        type_has_codegen_value(expr->type_entry) &&
        !expr->has_global_const &&
        type_has_bits(expr->type_entry))
    {
        g->global_const_list.append(expr_node);
        expr->has_global_const = true;
    }
}

static bool num_lit_fits_in_other_type(CodeGen *g, AstNode *literal_node, TypeTableEntry *other_type) {
    TypeTableEntry *other_type_underlying = get_underlying_type(other_type);

    if (other_type_underlying->id == TypeTableEntryIdInvalid) {
        return false;
    }

    Expr *expr = get_resolved_expr(literal_node);
    ConstExprValue *const_val = &expr->const_val;
    assert(const_val->ok);
    if (other_type_underlying->id == TypeTableEntryIdFloat) {
        return true;
    } else if (other_type_underlying->id == TypeTableEntryIdInt &&
               const_val->data.x_bignum.kind == BigNumKindInt)
    {
        if (bignum_fits_in_bits(&const_val->data.x_bignum, other_type_underlying->data.integral.bit_count,
                    other_type_underlying->data.integral.is_signed))
        {
            return true;
        }
    } else if ((other_type_underlying->id == TypeTableEntryIdNumLitFloat &&
                const_val->data.x_bignum.kind == BigNumKindFloat) ||
               (other_type_underlying->id == TypeTableEntryIdNumLitInt &&
                const_val->data.x_bignum.kind == BigNumKindInt))
    {
        return true;
    }

    const char *num_lit_str = (const_val->data.x_bignum.kind == BigNumKindFloat) ? "float" : "integer";

    add_node_error(g, literal_node,
        buf_sprintf("%s value %s cannot be implicitly casted to type '%s'",
            num_lit_str,
            buf_ptr(bignum_to_buf(&const_val->data.x_bignum)),
            buf_ptr(&other_type->name)));
    return false;
}

static bool types_match_const_cast_only(TypeTableEntry *expected_type, TypeTableEntry *actual_type) {
    if (expected_type == actual_type)
        return true;

    // pointer const
    if (expected_type->id == TypeTableEntryIdPointer &&
        actual_type->id == TypeTableEntryIdPointer &&
        (!actual_type->data.pointer.is_const || expected_type->data.pointer.is_const))
    {
        return types_match_const_cast_only(expected_type->data.pointer.child_type,
                actual_type->data.pointer.child_type);
    }

    // unknown size array const
    if (expected_type->id == TypeTableEntryIdStruct &&
        actual_type->id == TypeTableEntryIdStruct &&
        expected_type->data.structure.is_slice &&
        actual_type->data.structure.is_slice &&
        (!actual_type->data.structure.fields[0].type_entry->data.pointer.is_const ||
          expected_type->data.structure.fields[0].type_entry->data.pointer.is_const))
    {
        return types_match_const_cast_only(
                expected_type->data.structure.fields[0].type_entry->data.pointer.child_type,
                actual_type->data.structure.fields[0].type_entry->data.pointer.child_type);
    }

    // maybe
    if (expected_type->id == TypeTableEntryIdMaybe &&
        actual_type->id == TypeTableEntryIdMaybe)
    {
        return types_match_const_cast_only(
                expected_type->data.maybe.child_type,
                actual_type->data.maybe.child_type);
    }

    // error
    if (expected_type->id == TypeTableEntryIdErrorUnion &&
        actual_type->id == TypeTableEntryIdErrorUnion)
    {
        return types_match_const_cast_only(
                expected_type->data.error.child_type,
                actual_type->data.error.child_type);
    }

    // fn
    if (expected_type->id == TypeTableEntryIdFn &&
        actual_type->id == TypeTableEntryIdFn)
    {
        if (expected_type->data.fn.fn_type_id.is_extern != actual_type->data.fn.fn_type_id.is_extern) {
            return false;
        }
        if (expected_type->data.fn.fn_type_id.is_naked != actual_type->data.fn.fn_type_id.is_naked) {
            return false;
        }
        if (expected_type->data.fn.fn_type_id.is_cold != actual_type->data.fn.fn_type_id.is_cold) {
            return false;
        }
        if (actual_type->data.fn.fn_type_id.return_type->id != TypeTableEntryIdUnreachable &&
            !types_match_const_cast_only(
                expected_type->data.fn.fn_type_id.return_type,
                actual_type->data.fn.fn_type_id.return_type))
        {
            return false;
        }
        if (expected_type->data.fn.fn_type_id.param_count != actual_type->data.fn.fn_type_id.param_count) {
            return false;
        }
        for (int i = 0; i < expected_type->data.fn.fn_type_id.param_count; i += 1) {
            // note it's reversed for parameters
            FnTypeParamInfo *actual_param_info = &actual_type->data.fn.fn_type_id.param_info[i];
            FnTypeParamInfo *expected_param_info = &expected_type->data.fn.fn_type_id.param_info[i];

            if (!types_match_const_cast_only(actual_param_info->type, expected_param_info->type)) {
                return false;
            }

            if (expected_param_info->is_noalias != actual_param_info->is_noalias) {
                return false;
            }
        }
        return true;
    }


    return false;
}

static TypeTableEntry *determine_peer_type_compatibility(CodeGen *g, AstNode *parent_source_node,
        AstNode **child_nodes, TypeTableEntry **child_types, int child_count)
{
    TypeTableEntry *prev_type = child_types[0];
    AstNode *prev_node = child_nodes[0];
    if (prev_type->id == TypeTableEntryIdInvalid) {
        return prev_type;
    }
    for (int i = 1; i < child_count; i += 1) {
        TypeTableEntry *cur_type = child_types[i];
        AstNode *cur_node = child_nodes[i];
        if (cur_type->id == TypeTableEntryIdInvalid) {
            return cur_type;
        } else if (types_match_const_cast_only(prev_type, cur_type)) {
            continue;
        } else if (types_match_const_cast_only(cur_type, prev_type)) {
            prev_type = cur_type;
            prev_node = cur_node;
            continue;
        } else if (prev_type->id == TypeTableEntryIdUnreachable) {
            prev_type = cur_type;
            prev_node = cur_node;
        } else if (cur_type->id == TypeTableEntryIdUnreachable) {
            continue;
        } else if (prev_type->id == TypeTableEntryIdInt &&
                   cur_type->id == TypeTableEntryIdInt &&
                   prev_type->data.integral.is_signed == cur_type->data.integral.is_signed)
        {
            if (cur_type->data.integral.bit_count > prev_type->data.integral.bit_count) {
                prev_type = cur_type;
                prev_node = cur_node;
            }
            continue;
        } else if (prev_type->id == TypeTableEntryIdFloat &&
                   cur_type->id == TypeTableEntryIdFloat)
        {
            if (cur_type->data.floating.bit_count > prev_type->data.floating.bit_count) {
                prev_type = cur_type;
                prev_node = cur_node;
            }
        } else if (prev_type->id == TypeTableEntryIdErrorUnion &&
                   types_match_const_cast_only(prev_type->data.error.child_type, cur_type))
        {
            continue;
        } else if (cur_type->id == TypeTableEntryIdErrorUnion &&
                   types_match_const_cast_only(cur_type->data.error.child_type, prev_type))
        {
            prev_type = cur_type;
            prev_node = cur_node;
            continue;
        } else if (prev_type->id == TypeTableEntryIdNumLitInt ||
                    prev_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (num_lit_fits_in_other_type(g, prev_node, cur_type)) {
                prev_type = cur_type;
                prev_node = cur_node;
                continue;
            } else {
                return g->builtin_types.entry_invalid;
            }
        } else if (cur_type->id == TypeTableEntryIdNumLitInt ||
                   cur_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (num_lit_fits_in_other_type(g, cur_node, prev_type)) {
                continue;
            } else {
                return g->builtin_types.entry_invalid;
            }
        } else {
            add_node_error(g, parent_source_node,
                buf_sprintf("incompatible types: '%s' and '%s'",
                    buf_ptr(&prev_type->name), buf_ptr(&cur_type->name)));

            return g->builtin_types.entry_invalid;
        }
    }
    return prev_type;
}

static bool types_match_with_implicit_cast(CodeGen *g, TypeTableEntry *expected_type,
        TypeTableEntry *actual_type, AstNode *literal_node, bool *reported_err)
{
    if (types_match_const_cast_only(expected_type, actual_type)) {
        return true;
    }

    // implicit conversion from non maybe type to maybe type
    if (expected_type->id == TypeTableEntryIdMaybe &&
        types_match_with_implicit_cast(g, expected_type->data.maybe.child_type, actual_type,
            literal_node, reported_err))
    {
        return true;
    }

    // implicit conversion from error child type to error type
    if (expected_type->id == TypeTableEntryIdErrorUnion &&
        types_match_with_implicit_cast(g, expected_type->data.error.child_type, actual_type,
            literal_node, reported_err))
    {
        return true;
    }

    // implicit conversion from pure error to error union type
    if (expected_type->id == TypeTableEntryIdErrorUnion &&
        actual_type->id == TypeTableEntryIdPureError)
    {
        return true;
    }

    // implicit widening conversion
    if (expected_type->id == TypeTableEntryIdInt &&
        actual_type->id == TypeTableEntryIdInt &&
        expected_type->data.integral.is_signed == actual_type->data.integral.is_signed &&
        expected_type->data.integral.bit_count >= actual_type->data.integral.bit_count)
    {
        return true;
    }

    // small enough unsigned ints can get casted to large enough signed ints
    if (expected_type->id == TypeTableEntryIdInt && expected_type->data.integral.is_signed &&
        actual_type->id == TypeTableEntryIdInt && !actual_type->data.integral.is_signed &&
        expected_type->data.integral.bit_count > actual_type->data.integral.bit_count)
    {
        return true;
    }

    // implicit float widening conversion
    if (expected_type->id == TypeTableEntryIdFloat &&
        actual_type->id == TypeTableEntryIdFloat &&
        expected_type->data.floating.bit_count >= actual_type->data.floating.bit_count)
    {
        return true;
    }

    // implicit array to slice conversion
    if (expected_type->id == TypeTableEntryIdStruct &&
        expected_type->data.structure.is_slice &&
        actual_type->id == TypeTableEntryIdArray &&
        types_match_const_cast_only(
            expected_type->data.structure.fields[0].type_entry->data.pointer.child_type,
            actual_type->data.array.child_type))
    {
        return true;
    }

    // implicit number literal to typed number
    if ((actual_type->id == TypeTableEntryIdNumLitFloat ||
         actual_type->id == TypeTableEntryIdNumLitInt))
    {
        if (num_lit_fits_in_other_type(g, literal_node, expected_type)) {
            return true;
        } else {
            *reported_err = true;
        }
    }


    return false;
}

static AstNode *create_ast_node(CodeGen *g, ImportTableEntry *import, NodeType kind, AstNode *source_node) {
    AstNode *node = allocate<AstNode>(1);
    node->type = kind;
    node->owner = import;
    node->create_index = g->next_node_index;
    g->next_node_index += 1;
    node->line = source_node->line;
    node->column = source_node->column;
    return node;
}

static AstNode *create_ast_type_node(CodeGen *g, ImportTableEntry *import, TypeTableEntry *type_entry,
        AstNode *source_node)
{
    AstNode *node = create_ast_node(g, import, NodeTypeSymbol, source_node);
    node->data.symbol_expr.override_type_entry = type_entry;
    return node;
}

static AstNode *create_ast_void_node(CodeGen *g, ImportTableEntry *import, AstNode *source_node) {
    AstNode *node = create_ast_node(g, import, NodeTypeContainerInitExpr, source_node);
    node->data.container_init_expr.kind = ContainerInitKindArray;
    node->data.container_init_expr.type = create_ast_type_node(g, import, g->builtin_types.entry_void,
            source_node);
    normalize_parent_ptrs(node);
    return node;
}

static TypeTableEntry *create_and_analyze_cast_node(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, TypeTableEntry *cast_to_type, AstNode *node)
{
    AstNode *new_parent_node = create_ast_node(g, import, NodeTypeFnCallExpr, node);
    *node->parent_field = new_parent_node;
    new_parent_node->parent_field = node->parent_field;

    new_parent_node->data.fn_call_expr.fn_ref_expr = create_ast_type_node(g, import, cast_to_type, node);
    new_parent_node->data.fn_call_expr.params.append(node);
    normalize_parent_ptrs(new_parent_node);

    return analyze_expression(g, import, context, cast_to_type, new_parent_node);
}

static TypeTableEntry *resolve_type_compatibility(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node,
        TypeTableEntry *expected_type, TypeTableEntry *actual_type)
{
    if (expected_type == nullptr)
        return actual_type; // anything will do
    if (expected_type == actual_type)
        return expected_type; // match
    if (expected_type->id == TypeTableEntryIdInvalid || actual_type->id == TypeTableEntryIdInvalid)
        return g->builtin_types.entry_invalid;
    if (actual_type->id == TypeTableEntryIdUnreachable)
        return actual_type;

    bool reported_err = false;
    if (types_match_with_implicit_cast(g, expected_type, actual_type, node, &reported_err)) {
        return create_and_analyze_cast_node(g, import, context, expected_type, node);
    }

    if (!reported_err) {
        add_node_error(g, first_executing_node(node),
            buf_sprintf("expected type '%s', got '%s'",
                buf_ptr(&expected_type->name),
                buf_ptr(&actual_type->name)));
    }

    return g->builtin_types.entry_invalid;
}

static TypeTableEntry *resolve_peer_type_compatibility(CodeGen *g, ImportTableEntry *import,
        BlockContext *block_context, AstNode *parent_source_node,
        AstNode **child_nodes, TypeTableEntry **child_types, int child_count)
{
    assert(child_count > 0);

    TypeTableEntry *expected_type = determine_peer_type_compatibility(g, parent_source_node,
            child_nodes, child_types, child_count);

    if (expected_type->id == TypeTableEntryIdInvalid) {
        return expected_type;
    }

    for (int i = 0; i < child_count; i += 1) {
        if (!child_nodes[i]) {
            continue;
        }
        AstNode **child_node = child_nodes[i]->parent_field;
        TypeTableEntry *resolved_type = resolve_type_compatibility(g, import, block_context,
                *child_node, expected_type, child_types[i]);
        Expr *expr = get_resolved_expr(*child_node);
        expr->type_entry = resolved_type;
        add_global_const_expr(g, *child_node);
    }

    return expected_type;
}

BlockContext *new_block_context(AstNode *node, BlockContext *parent) {
    BlockContext *context = allocate<BlockContext>(1);
    context->node = node;
    context->parent = parent;
    context->decl_table.init(1);
    context->var_table.init(1);
    context->label_table.init(1);

    if (parent) {
        context->parent_loop_node = parent->parent_loop_node;
        context->c_import_buf = parent->c_import_buf;
        context->codegen_excluded = parent->codegen_excluded;
        context->safety_off = parent->safety_off;
    }

    if (node && node->type == NodeTypeFnDef) {
        AstNode *fn_proto_node = node->data.fn_def.fn_proto;
        context->fn_entry = fn_proto_node->data.fn_proto.fn_table_entry;
        context->safety_off = context->fn_entry->safety_off;
    } else if (parent) {
        context->fn_entry = parent->fn_entry;
    }

    if (context->fn_entry) {
        context->fn_entry->all_block_contexts.append(context);
    }

    return context;
}

static AstNode *find_decl(BlockContext *context, Buf *name) {
    while (context) {
        auto entry = context->decl_table.maybe_get(name);
        if (entry) {
            return entry->value;
        }
        context = context->parent;
    }
    return nullptr;
}

static VariableTableEntry *find_variable(CodeGen *g, BlockContext *orig_context, Buf *name) {
    BlockContext *context = orig_context;
    while (context) {
        auto entry = context->var_table.maybe_get(name);
        if (entry) {
            return entry->value;
        }
        context = context->parent;
    }

    return nullptr;
}

static LabelTableEntry *find_label(CodeGen *g, BlockContext *orig_context, Buf *name) {
    BlockContext *context = orig_context;
    while (context && context->fn_entry) {
        auto entry = context->label_table.maybe_get(name);
        if (entry) {
            return entry->value;
        }
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

static TypeTableEntry *analyze_enum_value_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *field_access_node, AstNode *value_node, TypeTableEntry *enum_type, Buf *field_name,
        AstNode *out_node)
{
    assert(field_access_node->type == NodeTypeFieldAccessExpr);

    TypeEnumField *type_enum_field = get_enum_field(enum_type, field_name);
    field_access_node->data.field_access_expr.type_enum_field = type_enum_field;

    if (type_enum_field) {
        if (value_node) {
            AstNode **value_node_ptr = value_node->parent_field;
            TypeTableEntry *value_type = analyze_expression(g, import, context,
                    type_enum_field->type_entry, value_node);

            if (value_type->id == TypeTableEntryIdInvalid) {
                return g->builtin_types.entry_invalid;
            }

            StructValExprCodeGen *codegen = &field_access_node->data.field_access_expr.resolved_struct_val_expr;
            codegen->type_entry = enum_type;
            codegen->source_node = field_access_node;

            ConstExprValue *value_const_val = &get_resolved_expr(*value_node_ptr)->const_val;
            if (value_const_val->ok) {
                ConstExprValue *const_val = &get_resolved_expr(out_node)->const_val;
                const_val->ok = true;
                const_val->data.x_enum.tag = type_enum_field->value;
                const_val->data.x_enum.payload = value_const_val;
            } else {
                if (context->fn_entry) {
                    context->fn_entry->struct_val_expr_alloca_list.append(codegen);
                } else {
                    add_node_error(g, *value_node_ptr, buf_sprintf("unable to evaluate constant expression"));
                    return g->builtin_types.entry_invalid;
                }
            }
        } else if (type_enum_field->type_entry->id != TypeTableEntryIdVoid) {
            add_node_error(g, field_access_node,
                buf_sprintf("enum value '%s.%s' requires parameter of type '%s'",
                    buf_ptr(&enum_type->name),
                    buf_ptr(field_name),
                    buf_ptr(&type_enum_field->type_entry->name)));
        } else {
            Expr *expr = get_resolved_expr(out_node);
            expr->const_val.ok = true;
            expr->const_val.data.x_enum.tag = type_enum_field->value;
            expr->const_val.data.x_enum.payload = nullptr;
        }
    } else {
        add_node_error(g, field_access_node,
            buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name),
                buf_ptr(&enum_type->name)));
    }
    return enum_type;
}

static TypeStructField *find_struct_type_field(TypeTableEntry *type_entry, Buf *name) {
    assert(type_entry->id == TypeTableEntryIdStruct);
    assert(type_entry->data.structure.complete);
    for (uint32_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
        TypeStructField *field = &type_entry->data.structure.fields[i];
        if (buf_eql_buf(field->name, name)) {
            return field;
        }
    }
    return nullptr;
}

static const char *err_container_init_syntax_name(ContainerInitKind kind) {
    switch (kind) {
        case ContainerInitKindStruct:
            return "struct";
        case ContainerInitKindArray:
            return "array";
    }
    zig_unreachable();
}

static TypeTableEntry *analyze_container_init_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeContainerInitExpr);

    AstNodeContainerInitExpr *container_init_expr = &node->data.container_init_expr;

    ContainerInitKind kind = container_init_expr->kind;

    if (container_init_expr->type->type == NodeTypeFieldAccessExpr) {
        container_init_expr->type->data.field_access_expr.container_init_expr_node = node;
    }

    TypeTableEntry *container_meta_type = analyze_expression(g, import, context, nullptr,
            container_init_expr->type);

    if (container_meta_type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    }

    if (node->data.container_init_expr.enum_type) {
        get_resolved_expr(node)->const_val = get_resolved_expr(container_init_expr->type)->const_val;
        return node->data.container_init_expr.enum_type;
    }

    TypeTableEntry *container_type = resolve_type(g, container_init_expr->type);

    if (container_type->id == TypeTableEntryIdInvalid) {
        return container_type;
    } else if (container_type->id == TypeTableEntryIdStruct &&
               !container_type->data.structure.is_slice &&
               (kind == ContainerInitKindStruct || (kind == ContainerInitKindArray &&
                                                    container_init_expr->entries.length == 0)))
    {
        StructValExprCodeGen *codegen = &container_init_expr->resolved_struct_val_expr;
        codegen->type_entry = container_type;
        codegen->source_node = node;


        int expr_field_count = container_init_expr->entries.length;
        int actual_field_count = container_type->data.structure.src_field_count;

        AstNode *non_const_expr_culprit = nullptr;

        int *field_use_counts = allocate<int>(actual_field_count);
        ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
        const_val->ok = true;
        const_val->data.x_struct.fields = allocate<ConstExprValue*>(actual_field_count);
        for (int i = 0; i < expr_field_count; i += 1) {
            AstNode *val_field_node = container_init_expr->entries.at(i);
            assert(val_field_node->type == NodeTypeStructValueField);

            val_field_node->block_context = context;

            TypeStructField *type_field = find_struct_type_field(container_type,
                    val_field_node->data.struct_val_field.name);

            if (!type_field) {
                add_node_error(g, val_field_node,
                    buf_sprintf("no member named '%s' in '%s'",
                        buf_ptr(val_field_node->data.struct_val_field.name), buf_ptr(&container_type->name)));
                continue;
            }

            if (type_field->type_entry->id == TypeTableEntryIdInvalid) {
                return g->builtin_types.entry_invalid;
            }

            int field_index = type_field->src_index;
            field_use_counts[field_index] += 1;
            if (field_use_counts[field_index] > 1) {
                add_node_error(g, val_field_node, buf_sprintf("duplicate field"));
                continue;
            }

            val_field_node->data.struct_val_field.type_struct_field = type_field;

            analyze_expression(g, import, context, type_field->type_entry,
                    val_field_node->data.struct_val_field.expr);

            if (const_val->ok) {
                ConstExprValue *field_val =
                    &get_resolved_expr(val_field_node->data.struct_val_field.expr)->const_val;
                if (field_val->ok) {
                    const_val->data.x_struct.fields[field_index] = field_val;
                    const_val->depends_on_compile_var = const_val->depends_on_compile_var || field_val->depends_on_compile_var;
                } else {
                    const_val->ok = false;
                    non_const_expr_culprit = val_field_node->data.struct_val_field.expr;
                }
            }
        }
        if (!const_val->ok) {
            assert(non_const_expr_culprit);
            if (context->fn_entry) {
                context->fn_entry->struct_val_expr_alloca_list.append(codegen);
            } else {
                add_node_error(g, non_const_expr_culprit, buf_sprintf("unable to evaluate constant expression"));
            }
        }

        for (int i = 0; i < actual_field_count; i += 1) {
            if (field_use_counts[i] == 0) {
                add_node_error(g, node,
                    buf_sprintf("missing field: '%s'", buf_ptr(container_type->data.structure.fields[i].name)));
            }
        }
        return container_type;
    } else if (container_type->id == TypeTableEntryIdStruct &&
               container_type->data.structure.is_slice &&
               kind == ContainerInitKindArray)
    {
        int elem_count = container_init_expr->entries.length;

        TypeTableEntry *pointer_type = container_type->data.structure.fields[0].type_entry;
        assert(pointer_type->id == TypeTableEntryIdPointer);
        TypeTableEntry *child_type = pointer_type->data.pointer.child_type;

        ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
        const_val->ok = true;
        const_val->data.x_array.fields = allocate<ConstExprValue*>(elem_count);

        for (int i = 0; i < elem_count; i += 1) {
            AstNode **elem_node = &container_init_expr->entries.at(i);
            analyze_expression(g, import, context, child_type, *elem_node);

            if (const_val->ok) {
                ConstExprValue *elem_const_val = &get_resolved_expr(*elem_node)->const_val;
                if (elem_const_val->ok) {
                    const_val->data.x_array.fields[i] = elem_const_val;
                    const_val->depends_on_compile_var = const_val->depends_on_compile_var ||
                        elem_const_val->depends_on_compile_var;
                } else {
                    const_val->ok = false;
                }
            }
        }

        TypeTableEntry *fixed_size_array_type = get_array_type(g, child_type, elem_count);

        StructValExprCodeGen *codegen = &container_init_expr->resolved_struct_val_expr;
        codegen->type_entry = fixed_size_array_type;
        codegen->source_node = node;
        if (!const_val->ok) {
            context->fn_entry->struct_val_expr_alloca_list.append(codegen);
        }

        return fixed_size_array_type;
    } else if (container_type->id == TypeTableEntryIdArray) {
        zig_panic("TODO array container init");
        return container_type;
    } else if (container_type->id == TypeTableEntryIdVoid) {
        if (container_init_expr->entries.length != 0) {
            add_node_error(g, node, buf_sprintf("void expression expects no arguments"));
            return g->builtin_types.entry_invalid;
        } else {
            return resolve_expr_const_val_as_void(g, node);
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
            buf_sprintf("type '%s' does not support %s initialization syntax",
                buf_ptr(&container_type->name), err_container_init_syntax_name(kind)));
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *analyze_field_access_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeFieldAccessExpr);

    AstNode **struct_expr_node = &node->data.field_access_expr.struct_expr;
    TypeTableEntry *struct_type = analyze_expression(g, import, context, nullptr, *struct_expr_node);
    Buf *field_name = node->data.field_access_expr.field_name;

    bool wrapped_in_fn_call = node->data.field_access_expr.is_fn_call;

    if (struct_type->id == TypeTableEntryIdInvalid) {
        return struct_type;
    } else if (struct_type->id == TypeTableEntryIdStruct || (struct_type->id == TypeTableEntryIdPointer &&
         struct_type->data.pointer.child_type->id == TypeTableEntryIdStruct))
    {
        TypeTableEntry *bare_struct_type = (struct_type->id == TypeTableEntryIdStruct) ?
            struct_type : struct_type->data.pointer.child_type;

        if (!bare_struct_type->data.structure.complete) {
            resolve_struct_type(g, bare_struct_type->data.structure.decl_node->owner, bare_struct_type);
        }

        node->data.field_access_expr.bare_struct_type = bare_struct_type;
        node->data.field_access_expr.type_struct_field = find_struct_type_field(bare_struct_type, field_name);
        if (node->data.field_access_expr.type_struct_field) {
            return node->data.field_access_expr.type_struct_field->type_entry;
        } else if (wrapped_in_fn_call && !is_slice(bare_struct_type)) {
            BlockContext *container_block_context = get_container_block_context(bare_struct_type);
            assert(container_block_context);
            auto entry = container_block_context->decl_table.maybe_get(field_name);
            AstNode *fn_decl_node = entry ? entry->value : nullptr;
            if (fn_decl_node && fn_decl_node->type == NodeTypeFnProto) {
                resolve_top_level_decl(g, fn_decl_node, false);
                TopLevelDecl *tld = get_as_top_level_decl(fn_decl_node);
                if (tld->resolution == TldResolutionInvalid) {
                    return g->builtin_types.entry_invalid;
                }

                node->data.field_access_expr.is_member_fn = true;
                FnTableEntry *fn_entry = fn_decl_node->data.fn_proto.fn_table_entry;
                if (fn_entry->type_entry->id == TypeTableEntryIdGenericFn) {
                    return resolve_expr_const_val_as_generic_fn(g, node, fn_entry->type_entry, false);
                } else {
                    return resolve_expr_const_val_as_fn(g, node, fn_entry, false);
                }
            } else {
                add_node_error(g, node, buf_sprintf("no function named '%s' in '%s'",
                    buf_ptr(field_name), buf_ptr(&bare_struct_type->name)));
                return g->builtin_types.entry_invalid;
            }
        } else {
            add_node_error(g, node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name), buf_ptr(&struct_type->name)));
            return g->builtin_types.entry_invalid;
        }
    } else if (struct_type->id == TypeTableEntryIdArray) {
        if (buf_eql_str(field_name, "len")) {
            return resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type,
                    struct_type->data.array.len, false);
        } else {
            add_node_error(g, node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name),
                    buf_ptr(&struct_type->name)));
            return g->builtin_types.entry_invalid;
        }
    } else if (struct_type->id == TypeTableEntryIdMetaType) {
        TypeTableEntry *child_type = resolve_type(g, *struct_expr_node);

        if (child_type->id == TypeTableEntryIdInvalid) {
            return g->builtin_types.entry_invalid;
        } else if (child_type->id == TypeTableEntryIdEnum) {
            AstNode *container_init_node = node->data.field_access_expr.container_init_expr_node;
            AstNode *value_node;
            if (container_init_node) {
                assert(container_init_node->type == NodeTypeContainerInitExpr);
                int param_count = container_init_node->data.container_init_expr.entries.length;
                if (param_count > 1) {
                    AstNode *first_invalid_node = container_init_node->data.container_init_expr.entries.at(1);
                    add_node_error(g, first_executing_node(first_invalid_node),
                            buf_sprintf("enum values accept only one parameter"));
                    return child_type;
                } else {
                    if (param_count == 1) {
                        value_node = container_init_node->data.container_init_expr.entries.at(0);
                    } else {
                        value_node = nullptr;
                    }
                    container_init_node->data.container_init_expr.enum_type = child_type;
                }
            } else {
                value_node = nullptr;
            }
            return analyze_enum_value_expr(g, import, context, node, value_node, child_type, field_name, node);
        } else if (child_type->id == TypeTableEntryIdStruct) {
            BlockContext *container_block_context = get_container_block_context(child_type);
            auto entry = container_block_context->decl_table.maybe_get(field_name);
            AstNode *decl_node = entry ? entry->value : nullptr;
            if (decl_node) {
                bool pointer_only = false;
                return analyze_decl_ref(g, node, decl_node, pointer_only, context, false);
            } else {
                add_node_error(g, node,
                    buf_sprintf("container '%s' has no member called '%s'",
                        buf_ptr(&child_type->name), buf_ptr(field_name)));
                return g->builtin_types.entry_invalid;
            }
        } else if (child_type->id == TypeTableEntryIdPureError) {
            return analyze_error_literal_expr(g, import, context, node, field_name);
        } else if (child_type->id == TypeTableEntryIdInt) {
            bool depends_on_compile_var =
                get_resolved_expr(*struct_expr_node)->const_val.depends_on_compile_var;
            if (buf_eql_str(field_name, "bit_count")) {
                return resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type,
                        child_type->data.integral.bit_count, depends_on_compile_var);
            } else if (buf_eql_str(field_name, "is_signed")) {
                return resolve_expr_const_val_as_bool(g, node, child_type->data.integral.is_signed,
                        depends_on_compile_var);
            } else {
                add_node_error(g, node,
                    buf_sprintf("type '%s' has no member called '%s'",
                        buf_ptr(&child_type->name), buf_ptr(field_name)));
                return g->builtin_types.entry_invalid;
            }
        } else if (wrapped_in_fn_call) { // this branch should go last, before the error in the else case
            return resolve_expr_const_val_as_type(g, node, child_type, false);
        } else {
            add_node_error(g, node,
                buf_sprintf("type '%s' does not support field access", buf_ptr(&struct_type->name)));
            return g->builtin_types.entry_invalid;
        }
    } else if (struct_type->id == TypeTableEntryIdNamespace) {
        ConstExprValue *const_val = &get_resolved_expr(*struct_expr_node)->const_val;
        assert(const_val->ok);
        ImportTableEntry *namespace_import = const_val->data.x_import;
        AstNode *decl_node = find_decl(namespace_import->block_context, field_name);
        if (!decl_node) {
            // we must now resolve all the use decls
            for (int i = 0; i < namespace_import->use_decls.length; i += 1) {
                AstNode *use_decl_node = namespace_import->use_decls.at(i);
                if (!get_resolved_expr(use_decl_node->data.use.expr)->type_entry) {
                    preview_use_decl(g, use_decl_node);
                }
                resolve_use_decl(g, use_decl_node);
            }
            decl_node = find_decl(namespace_import->block_context, field_name);
        }
        if (decl_node) {
            TopLevelDecl *tld = get_as_top_level_decl(decl_node);
            if (tld->visib_mod == VisibModPrivate) {
                ErrorMsg *msg = add_node_error(g, node,
                    buf_sprintf("'%s' is private", buf_ptr(field_name)));
                add_error_note(g, msg, decl_node, buf_sprintf("declared here"));
            }
            bool pointer_only = false;
            return analyze_decl_ref(g, node, decl_node, pointer_only, context,
                    const_val->depends_on_compile_var);
        } else {
            const char *import_name = namespace_import->path ? buf_ptr(namespace_import->path) : "(C import)";
            add_node_error(g, node,
                buf_sprintf("no member named '%s' in '%s'", buf_ptr(field_name), import_name));
            return g->builtin_types.entry_invalid;
        }
    } else {
        add_node_error(g, node,
            buf_sprintf("type '%s' does not support field access", buf_ptr(&struct_type->name)));
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
        return_type = get_slice_type(g, array_type->data.array.child_type,
                node->data.slice_expr.is_const);
    } else if (array_type->id == TypeTableEntryIdPointer) {
        return_type = get_slice_type(g, array_type->data.pointer.child_type,
                node->data.slice_expr.is_const);
    } else if (array_type->id == TypeTableEntryIdStruct &&
               array_type->data.structure.is_slice)
    {
        return_type = get_slice_type(g,
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
        context->fn_entry->struct_val_expr_alloca_list.append(&node->data.slice_expr.resolved_struct_val_expr);
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
        if (array_type->data.array.len == 0) {
            add_node_error(g, node, buf_sprintf("out of bounds array access"));
        }
        return_type = array_type->data.array.child_type;
    } else if (array_type->id == TypeTableEntryIdPointer) {
        return_type = array_type->data.pointer.child_type;
    } else if (array_type->id == TypeTableEntryIdStruct &&
               array_type->data.structure.is_slice)
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

static TypeTableEntry *resolve_expr_const_val_as_void(CodeGen *g, AstNode *node) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    return g->builtin_types.entry_void;
}

static TypeTableEntry *resolve_expr_const_val_as_type(CodeGen *g, AstNode *node, TypeTableEntry *type,
        bool depends_on_compile_var)
{
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_type = type;
    expr->const_val.depends_on_compile_var = depends_on_compile_var;
    return g->builtin_types.entry_type;
}

static TypeTableEntry *resolve_expr_const_val_as_other_expr(CodeGen *g, AstNode *node, AstNode *other,
        bool depends_on_compile_var)
{
    Expr *expr = get_resolved_expr(node);
    Expr *other_expr = get_resolved_expr(other);
    expr->const_val = other_expr->const_val;
    expr->const_val.depends_on_compile_var = expr->const_val.depends_on_compile_var ||
        depends_on_compile_var;
    return other_expr->type_entry;
}

static TypeTableEntry *resolve_expr_const_val_as_fn(CodeGen *g, AstNode *node, FnTableEntry *fn,
        bool depends_on_compile_var)
{
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_fn = fn;
    expr->const_val.depends_on_compile_var = depends_on_compile_var;
    return fn->type_entry;
}

static TypeTableEntry *resolve_expr_const_val_as_generic_fn(CodeGen *g, AstNode *node,
        TypeTableEntry *type_entry, bool depends_on_compile_var)
{
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_type = type_entry;
    expr->const_val.depends_on_compile_var = depends_on_compile_var;
    return type_entry;
}


static TypeTableEntry *resolve_expr_const_val_as_err(CodeGen *g, AstNode *node, ErrorTableEntry *err) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_err.err = err;
    return g->builtin_types.entry_pure_error;
}

static TypeTableEntry *resolve_expr_const_val_as_bool(CodeGen *g, AstNode *node, bool value,
        bool depends_on_compile_var)
{
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.depends_on_compile_var = depends_on_compile_var;
    expr->const_val.data.x_bool = value;
    return g->builtin_types.entry_bool;
}

static TypeTableEntry *resolve_expr_const_val_as_null(CodeGen *g, AstNode *node, TypeTableEntry *type) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_maybe = nullptr;
    return type;
}

static TypeTableEntry *resolve_expr_const_val_as_non_null(CodeGen *g, AstNode *node,
        TypeTableEntry *type, ConstExprValue *other_val)
{
    assert(other_val->ok);
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_maybe = other_val;
    return type;
}

static TypeTableEntry *resolve_expr_const_val_as_c_string_lit(CodeGen *g, AstNode *node, Buf *str) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;

    int len_with_null = buf_len(str) + 1;
    expr->const_val.data.x_ptr.ptr = allocate<ConstExprValue*>(len_with_null);
    expr->const_val.data.x_ptr.len = len_with_null;
    expr->const_val.data.x_ptr.is_c_str = true;

    ConstExprValue *all_chars = allocate<ConstExprValue>(len_with_null);
    for (int i = 0; i < buf_len(str); i += 1) {
        ConstExprValue *this_char = &all_chars[i];
        this_char->ok = true;
        bignum_init_unsigned(&this_char->data.x_bignum, buf_ptr(str)[i]);
        expr->const_val.data.x_ptr.ptr[i] = this_char;
    }

    ConstExprValue *null_char = &all_chars[len_with_null - 1];
    null_char->ok = true;
    bignum_init_unsigned(&null_char->data.x_bignum, 0);
    expr->const_val.data.x_ptr.ptr[len_with_null - 1] = null_char;

    return get_pointer_to_type(g, g->builtin_types.entry_u8, true);
}

static TypeTableEntry *resolve_expr_const_val_as_string_lit(CodeGen *g, AstNode *node, Buf *str) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_array.fields = allocate<ConstExprValue*>(buf_len(str));

    ConstExprValue *all_chars = allocate<ConstExprValue>(buf_len(str));
    for (int i = 0; i < buf_len(str); i += 1) {
        ConstExprValue *this_char = &all_chars[i];
        this_char->ok = true;
        bignum_init_unsigned(&this_char->data.x_bignum, buf_ptr(str)[i]);
        expr->const_val.data.x_array.fields[i] = this_char;
    }
    return get_array_type(g, g->builtin_types.entry_u8, buf_len(str));
}

static TypeTableEntry *resolve_expr_const_val_as_bignum(CodeGen *g, AstNode *node,
        TypeTableEntry *expected_type, BigNum *bignum, bool depends_on_compile_var)
{
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.depends_on_compile_var = depends_on_compile_var;

    bignum_init_bignum(&expr->const_val.data.x_bignum, bignum);
    if (bignum->kind == BigNumKindInt) {
        return g->builtin_types.entry_num_lit_int;
    } else if (bignum->kind == BigNumKindFloat) {
        return g->builtin_types.entry_num_lit_float;
    } else {
        zig_unreachable();
    }
}

static TypeTableEntry *resolve_expr_const_val_as_unsigned_num_lit(CodeGen *g, AstNode *node,
        TypeTableEntry *expected_type, uint64_t x, bool depends_on_compile_var)
{
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.depends_on_compile_var = depends_on_compile_var;

    bignum_init_unsigned(&expr->const_val.data.x_bignum, x);

    return g->builtin_types.entry_num_lit_int;
}

static TypeTableEntry *analyze_error_literal_expr(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node, Buf *err_name)
{
    auto err_table_entry = g->error_table.maybe_get(err_name);

    if (err_table_entry) {
        return resolve_expr_const_val_as_err(g, node, err_table_entry->value);
    }

    add_node_error(g, node,
            buf_sprintf("use of undeclared error value '%s'", buf_ptr(err_name)));

    return g->builtin_types.entry_invalid;
}

static bool var_is_pure(VariableTableEntry *var, BlockContext *context) {
    if (var->block_context->fn_entry == context->fn_entry) {
        // variable was declared in the current function, so it's OK.
        return true;
    }
    return var->is_const && var->type->deep_const;
}

static TypeTableEntry *analyze_var_ref(CodeGen *g, AstNode *source_node, VariableTableEntry *var,
        BlockContext *context, bool depends_on_compile_var)
{
    get_resolved_expr(source_node)->variable = var;
    if (!var_is_pure(var, context)) {
        mark_impure_fn(g, context, source_node);
    }
    if (var->is_const && var->val_node) {
        ConstExprValue *other_const_val = &get_resolved_expr(var->val_node)->const_val;
        if (other_const_val->ok) {
            return resolve_expr_const_val_as_other_expr(g, source_node, var->val_node,
                    depends_on_compile_var || var->force_depends_on_compile_var);
        }
    }
    return var->type;
}

static TypeTableEntry *analyze_decl_ref(CodeGen *g, AstNode *source_node, AstNode *decl_node,
        bool pointer_only, BlockContext *block_context, bool depends_on_compile_var)
{
    resolve_top_level_decl(g, decl_node, pointer_only);
    TopLevelDecl *tld = get_as_top_level_decl(decl_node);
    if (tld->resolution == TldResolutionInvalid) {
        return g->builtin_types.entry_invalid;
    }

    if (decl_node->type == NodeTypeVariableDeclaration) {
        VariableTableEntry *var = decl_node->data.variable_declaration.variable;
        return analyze_var_ref(g, source_node, var, block_context, depends_on_compile_var);
    } else if (decl_node->type == NodeTypeFnProto) {
        FnTableEntry *fn_entry = decl_node->data.fn_proto.fn_table_entry;
        assert(fn_entry->type_entry);
        if (fn_entry->type_entry->id == TypeTableEntryIdGenericFn) {
            return resolve_expr_const_val_as_generic_fn(g, source_node, fn_entry->type_entry, depends_on_compile_var);
        } else {
            return resolve_expr_const_val_as_fn(g, source_node, fn_entry, depends_on_compile_var);
        }
    } else if (decl_node->type == NodeTypeContainerDecl) {
        if (decl_node->data.struct_decl.generic_params.length > 0) {
            TypeTableEntry *type_entry = decl_node->data.struct_decl.generic_fn_type;
            assert(type_entry);
            return resolve_expr_const_val_as_generic_fn(g, source_node, type_entry, depends_on_compile_var);
        } else {
            return resolve_expr_const_val_as_type(g, source_node, decl_node->data.struct_decl.type_entry,
                    depends_on_compile_var);
        }
    } else if (decl_node->type == NodeTypeTypeDecl) {
        return resolve_expr_const_val_as_type(g, source_node, decl_node->data.type_decl.child_type_entry,
                depends_on_compile_var);
    } else {
        zig_unreachable();
    }
}

static TypeTableEntry *analyze_symbol_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node, bool pointer_only)
{
    if (node->data.symbol_expr.override_type_entry) {
        return resolve_expr_const_val_as_type(g, node, node->data.symbol_expr.override_type_entry, false);
    }

    Buf *variable_name = node->data.symbol_expr.symbol;

    auto primitive_table_entry = g->primitive_type_table.maybe_get(variable_name);
    if (primitive_table_entry) {
        return resolve_expr_const_val_as_type(g, node, primitive_table_entry->value, false);
    }

    VariableTableEntry *var = find_variable(g, context, variable_name);
    if (var) {
        TypeTableEntry *var_type = analyze_var_ref(g, node, var, context, false);
        return var_type;
    }

    AstNode *decl_node = find_decl(context, variable_name);
    if (decl_node) {
        return analyze_decl_ref(g, node, decl_node, pointer_only, context, false);
    }

    if (import->any_imports_failed) {
        // skip the error message since we had a failing import in this file
        // if an import breaks we don't need 9999 undeclared identifier errors
        return g->builtin_types.entry_invalid;
    }

    mark_impure_fn(g, context, node);
    add_node_error(g, node, buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
    return g->builtin_types.entry_invalid;
}

static bool is_op_allowed(TypeTableEntry *type, BinOpType op) {
    switch (op) {
        case BinOpTypeAssign:
            return true;
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignTimesWrap:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
            return type->id == TypeTableEntryIdInt || type->id == TypeTableEntryIdFloat;
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignPlusWrap:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignMinusWrap:
            return type->id == TypeTableEntryIdInt ||
                   type->id == TypeTableEntryIdFloat ||
                   type->id == TypeTableEntryIdPointer;
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftLeftWrap:
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
        case BinOpTypeBitShiftLeftWrap:
        case BinOpTypeBitShiftRight:
        case BinOpTypeAdd:
        case BinOpTypeAddWrap:
        case BinOpTypeSub:
        case BinOpTypeSubWrap:
        case BinOpTypeMult:
        case BinOpTypeMultWrap:
        case BinOpTypeDiv:
        case BinOpTypeMod:
        case BinOpTypeUnwrapMaybe:
        case BinOpTypeArrayCat:
        case BinOpTypeArrayMult:
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
    lhs_node->block_context = block_context;
    if (lhs_node->type == NodeTypeSymbol) {
        bool pointer_only = purpose == LValPurposeAddressOf;
        expected_rhs_type = analyze_symbol_expr(g, import, block_context, nullptr, lhs_node, pointer_only);
        if (expected_rhs_type->id == TypeTableEntryIdInvalid) {
            return g->builtin_types.entry_invalid;
        }
        if (purpose != LValPurposeAddressOf) {
            Buf *name = lhs_node->data.symbol_expr.symbol;
            VariableTableEntry *var = find_variable(g, block_context, name);
            if (var) {
                if (var->is_const) {
                    add_node_error(g, lhs_node, buf_sprintf("cannot assign to constant"));
                    expected_rhs_type = g->builtin_types.entry_invalid;
                } else {
                    expected_rhs_type = var->type;
                    get_resolved_expr(lhs_node)->variable = var;
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
        expected_rhs_type = analyze_field_access_expr(g, import, block_context, nullptr, lhs_node);
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

static TypeTableEntry *analyze_bool_bin_op_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeBinOpExpr);
    BinOpType bin_op_type = node->data.bin_op_expr.bin_op;

    AstNode **op1 = &node->data.bin_op_expr.op1;
    AstNode **op2 = &node->data.bin_op_expr.op2;
    TypeTableEntry *op1_type = analyze_expression(g, import, context, nullptr, *op1);
    TypeTableEntry *op2_type = analyze_expression(g, import, context, nullptr, *op2);

    AstNode *op_nodes[] = {*op1, *op2};
    TypeTableEntry *op_types[] = {op1_type, op2_type};

    TypeTableEntry *resolved_type = resolve_peer_type_compatibility(g, import, context, node,
            op_nodes, op_types, 2);

    bool is_equality_cmp = (bin_op_type == BinOpTypeCmpEq || bin_op_type == BinOpTypeCmpNotEq);

    switch (resolved_type->id) {
        case TypeTableEntryIdInvalid:
            return g->builtin_types.entry_invalid;

        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
            break;

        case TypeTableEntryIdBool:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdGenericFn:
            if (!is_equality_cmp) {
                add_node_error(g, node,
                    buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
                return g->builtin_types.entry_invalid;
            }
            break;

        case TypeTableEntryIdEnum:
            if (!is_equality_cmp || resolved_type->data.enumeration.gen_field_count != 0) {
                add_node_error(g, node,
                    buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
                return g->builtin_types.entry_invalid;
            }
            break;

        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdUnion:
            add_node_error(g, node,
                buf_sprintf("operator not allowed for type '%s'", buf_ptr(&resolved_type->name)));
            return g->builtin_types.entry_invalid;
    }

    ConstExprValue *op1_val = &get_resolved_expr(*op1)->const_val;
    ConstExprValue *op2_val = &get_resolved_expr(*op2)->const_val;
    if (!op1_val->ok || !op2_val->ok) {
        return g->builtin_types.entry_bool;
    }


    ConstExprValue *out_val = &get_resolved_expr(node)->const_val;
    eval_const_expr_bin_op(op1_val, op1_type, bin_op_type, op2_val, op2_type, out_val);
    return g->builtin_types.entry_bool;

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

    ConstExprValue *out_val = &get_resolved_expr(node)->const_val;
    eval_const_expr_bin_op(op1_val, op1_type, bin_op_type, op2_val, op2_type, out_val);
    return g->builtin_types.entry_bool;
}

static TypeTableEntry *analyze_array_mult(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeBinOpExpr);
    assert(node->data.bin_op_expr.bin_op == BinOpTypeArrayMult);

    AstNode **op1 = node->data.bin_op_expr.op1->parent_field;
    AstNode **op2 = node->data.bin_op_expr.op2->parent_field;

    TypeTableEntry *op1_type = analyze_expression(g, import, context, nullptr, *op1);
    TypeTableEntry *op2_type = analyze_expression(g, import, context, nullptr, *op2);

    if (op1_type->id == TypeTableEntryIdInvalid ||
        op2_type->id == TypeTableEntryIdInvalid)
    {
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *op1_val = &get_resolved_expr(*op1)->const_val;
    ConstExprValue *op2_val = &get_resolved_expr(*op2)->const_val;

    AstNode *bad_node;
    if (!op1_val->ok) {
        bad_node = *op1;
    } else if (!op2_val->ok) {
        bad_node = *op2;
    } else {
        bad_node = nullptr;
    }
    if (bad_node) {
        add_node_error(g, bad_node, buf_sprintf("array multiplication requires constant expression"));
        return g->builtin_types.entry_invalid;
    }

    if (op1_type->id != TypeTableEntryIdArray) {
        add_node_error(g, *op1,
            buf_sprintf("expected array type, got '%s'", buf_ptr(&op1_type->name)));
        return g->builtin_types.entry_invalid;
    }

    if (op2_type->id != TypeTableEntryIdNumLitInt &&
        op2_type->id != TypeTableEntryIdInt)
    {
        add_node_error(g, *op2, buf_sprintf("expected integer type, got '%s'", buf_ptr(&op2_type->name)));
        return g->builtin_types.entry_invalid;
    }

    if (op2_val->data.x_bignum.is_negative) {
        add_node_error(g, *op2, buf_sprintf("expected positive number"));
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
    const_val->ok = true;
    const_val->depends_on_compile_var = op1_val->depends_on_compile_var || op2_val->depends_on_compile_var;

    TypeTableEntry *child_type = op1_type->data.array.child_type;
    BigNum old_array_len;
    bignum_init_unsigned(&old_array_len, op1_type->data.array.len);

    BigNum new_array_len;
    if (bignum_mul(&new_array_len, &old_array_len, &op2_val->data.x_bignum)) {
        add_node_error(g, node, buf_sprintf("operation results in overflow"));
        return g->builtin_types.entry_invalid;
    }

    uint64_t old_array_len_bare = op1_type->data.array.len;
    uint64_t operand_amt = op2_val->data.x_bignum.data.x_uint;

    uint64_t new_array_len_bare = new_array_len.data.x_uint;
    const_val->data.x_array.fields = allocate<ConstExprValue*>(new_array_len_bare);

    uint64_t i = 0;
    for (uint64_t x = 0; x < operand_amt; x += 1) {
        for (uint64_t y = 0; y < old_array_len_bare; y += 1) {
            const_val->data.x_array.fields[i] = op1_val->data.x_array.fields[y];
            i += 1;
        }
    }

    return get_array_type(g, child_type, new_array_len_bare);
}

static TypeTableEntry *analyze_bin_op_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeBinOpExpr);
    BinOpType bin_op_type = node->data.bin_op_expr.bin_op;
    switch (bin_op_type) {
        case BinOpTypeAssign:
        case BinOpTypeAssignTimes:
        case BinOpTypeAssignTimesWrap:
        case BinOpTypeAssignDiv:
        case BinOpTypeAssignMod:
        case BinOpTypeAssignPlus:
        case BinOpTypeAssignPlusWrap:
        case BinOpTypeAssignMinus:
        case BinOpTypeAssignMinusWrap:
        case BinOpTypeAssignBitShiftLeft:
        case BinOpTypeAssignBitShiftLeftWrap:
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
                if (expected_rhs_type->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else if (!is_op_allowed(expected_rhs_type, node->data.bin_op_expr.bin_op)) {
                    if (expected_rhs_type->id != TypeTableEntryIdInvalid) {
                        add_node_error(g, lhs_node,
                            buf_sprintf("operator not allowed for type '%s'",
                                buf_ptr(&expected_rhs_type->name)));
                    }
                }

                analyze_expression(g, import, context, expected_rhs_type, node->data.bin_op_expr.op2);
                // not const ok because expression has side effects
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
        case BinOpTypeBitShiftLeftWrap:
        case BinOpTypeBitShiftRight:
        case BinOpTypeAdd:
        case BinOpTypeAddWrap:
        case BinOpTypeSub:
        case BinOpTypeSubWrap:
        case BinOpTypeMult:
        case BinOpTypeMultWrap:
        case BinOpTypeDiv:
        case BinOpTypeMod:
            {
                AstNode **op1 = node->data.bin_op_expr.op1->parent_field;
                AstNode **op2 = node->data.bin_op_expr.op2->parent_field;
                TypeTableEntry *lhs_type = analyze_expression(g, import, context, nullptr, *op1);
                TypeTableEntry *rhs_type = analyze_expression(g, import, context, nullptr, *op2);

                AstNode *op_nodes[] = {*op1, *op2};
                TypeTableEntry *op_types[] = {lhs_type, rhs_type};

                TypeTableEntry *resolved_type = resolve_peer_type_compatibility(g, import, context, node,
                        op_nodes, op_types, 2);

                if (resolved_type->id == TypeTableEntryIdInvalid) {
                    return resolved_type;
                }

                if (resolved_type->id == TypeTableEntryIdInt ||
                    resolved_type->id == TypeTableEntryIdNumLitInt)
                {
                    // int
                } else if ((resolved_type->id == TypeTableEntryIdFloat ||
                           resolved_type->id == TypeTableEntryIdNumLitFloat) &&
                    (bin_op_type == BinOpTypeAdd ||
                     bin_op_type == BinOpTypeSub ||
                     bin_op_type == BinOpTypeMult ||
                     bin_op_type == BinOpTypeDiv ||
                     bin_op_type == BinOpTypeMod))
                {
                    // float
                } else {
                    add_node_error(g, node, buf_sprintf("invalid operands to binary expression: '%s' and '%s'",
                            buf_ptr(&lhs_type->name), buf_ptr(&rhs_type->name)));
                    return g->builtin_types.entry_invalid;
                }

                ConstExprValue *op1_val = &get_resolved_expr(*op1)->const_val;
                ConstExprValue *op2_val = &get_resolved_expr(*op2)->const_val;
                if (!op1_val->ok || !op2_val->ok) {
                    return resolved_type;
                }

                ConstExprValue *out_val = &get_resolved_expr(node)->const_val;
                int err;
                if ((err = eval_const_expr_bin_op(op1_val, resolved_type, bin_op_type,
                                op2_val, resolved_type, out_val)))
                {
                    if (err == ErrorDivByZero) {
                        add_node_error(g, node, buf_sprintf("division by zero is undefined"));
                        return g->builtin_types.entry_invalid;
                    } else if (err == ErrorOverflow) {
                        add_node_error(g, node, buf_sprintf("value cannot be represented in any integer type"));
                        return g->builtin_types.entry_invalid;
                    }
                    return g->builtin_types.entry_invalid;
                }

                num_lit_fits_in_other_type(g, node, resolved_type);
                return resolved_type;
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
                    return g->builtin_types.entry_invalid;
                }
            }
        case BinOpTypeArrayCat:
            {
                AstNode **op1 = node->data.bin_op_expr.op1->parent_field;
                AstNode **op2 = node->data.bin_op_expr.op2->parent_field;

                TypeTableEntry *op1_type = analyze_expression(g, import, context, nullptr, *op1);
                TypeTableEntry *child_type;
                if (op1_type->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else if (op1_type->id == TypeTableEntryIdArray) {
                    child_type = op1_type->data.array.child_type;
                } else if (op1_type->id == TypeTableEntryIdPointer &&
                           op1_type->data.pointer.child_type == g->builtin_types.entry_u8) {
                    child_type = op1_type->data.pointer.child_type;
                } else {
                    add_node_error(g, *op1, buf_sprintf("expected array or C string literal, got '%s'",
                                buf_ptr(&op1_type->name)));
                    return g->builtin_types.entry_invalid;
                }

                TypeTableEntry *op2_type = analyze_expression(g, import, context, nullptr, *op2);

                if (op2_type->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else if (op2_type->id == TypeTableEntryIdArray) {
                    if (op2_type->data.array.child_type != child_type) {
                        add_node_error(g, *op2, buf_sprintf("expected array of type '%s', got '%s'",
                                    buf_ptr(&child_type->name),
                                    buf_ptr(&op2_type->name)));
                        return g->builtin_types.entry_invalid;
                    }
                } else if (op2_type->id == TypeTableEntryIdPointer &&
                        op2_type->data.pointer.child_type == g->builtin_types.entry_u8) {
                } else {
                    add_node_error(g, *op2, buf_sprintf("expected array or C string literal, got '%s'",
                                buf_ptr(&op2_type->name)));
                    return g->builtin_types.entry_invalid;
                }

                ConstExprValue *op1_val = &get_resolved_expr(*op1)->const_val;
                ConstExprValue *op2_val = &get_resolved_expr(*op2)->const_val;

                AstNode *bad_node;
                if (!op1_val->ok) {
                    bad_node = *op1;
                } else if (!op2_val->ok) {
                    bad_node = *op2;
                } else {
                    bad_node = nullptr;
                }
                if (bad_node) {
                    add_node_error(g, bad_node, buf_sprintf("array concatenation requires constant expression"));
                    return g->builtin_types.entry_invalid;
                }

                ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
                const_val->ok = true;
                const_val->depends_on_compile_var = op1_val->depends_on_compile_var ||
                    op2_val->depends_on_compile_var;

                if (op1_type->id == TypeTableEntryIdArray) {
                    uint64_t new_len = op1_type->data.array.len + op2_type->data.array.len;
                    const_val->data.x_array.fields = allocate<ConstExprValue*>(new_len);
                    uint64_t next_index = 0;
                    for (uint64_t i = 0; i < op1_type->data.array.len; i += 1, next_index += 1) {
                        const_val->data.x_array.fields[next_index] = op1_val->data.x_array.fields[i];
                    }
                    for (uint64_t i = 0; i < op2_type->data.array.len; i += 1, next_index += 1) {
                        const_val->data.x_array.fields[next_index] = op2_val->data.x_array.fields[i];
                    }
                    return get_array_type(g, child_type, new_len);
                } else if (op1_type->id == TypeTableEntryIdPointer) {
                    if (!op1_val->data.x_ptr.is_c_str) {
                        add_node_error(g, *op1,
                                buf_sprintf("expected array or C string literal, got '%s'",
                                    buf_ptr(&op1_type->name)));
                        return g->builtin_types.entry_invalid;
                    } else if (!op2_val->data.x_ptr.is_c_str) {
                        add_node_error(g, *op2,
                                buf_sprintf("expected array or C string literal, got '%s'",
                                    buf_ptr(&op2_type->name)));
                        return g->builtin_types.entry_invalid;
                    }
                    const_val->data.x_ptr.is_c_str = true;
                    const_val->data.x_ptr.len = op1_val->data.x_ptr.len + op2_val->data.x_ptr.len - 1;
                    const_val->data.x_ptr.ptr = allocate<ConstExprValue*>(const_val->data.x_ptr.len);
                    uint64_t next_index = 0;
                    for (uint64_t i = 0; i < op1_val->data.x_ptr.len - 1; i += 1, next_index += 1) {
                        const_val->data.x_ptr.ptr[next_index] = op1_val->data.x_ptr.ptr[i];
                    }
                    for (uint64_t i = 0; i < op2_val->data.x_ptr.len; i += 1, next_index += 1) {
                        const_val->data.x_ptr.ptr[next_index] = op2_val->data.x_ptr.ptr[i];
                    }
                    return op1_type;
                } else {
                    zig_unreachable();
                }
            }
        case BinOpTypeArrayMult:
            return analyze_array_mult(g, import, context, expected_type, node);
        case BinOpTypeInvalid:
            zig_unreachable();
    }
    zig_unreachable();
}

// Set name to nullptr to make the variable anonymous (not visible to programmer).
static VariableTableEntry *add_local_var(CodeGen *g, AstNode *source_node, ImportTableEntry *import,
        BlockContext *context, Buf *name, TypeTableEntry *type_entry, bool is_const, AstNode *val_node)
{
    VariableTableEntry *variable_entry = allocate<VariableTableEntry>(1);
    variable_entry->type = type_entry;
    variable_entry->block_context = context;

    if (name) {
        buf_init_from_buf(&variable_entry->name, name);

        if (type_entry->id != TypeTableEntryIdInvalid) {
            VariableTableEntry *existing_var = find_variable(g, context, name);
            if (existing_var) {
                ErrorMsg *msg = add_node_error(g, source_node,
                        buf_sprintf("redeclaration of variable '%s'", buf_ptr(name)));
                add_error_note(g, msg, existing_var->decl_node, buf_sprintf("previous declaration is here"));
                variable_entry->type = g->builtin_types.entry_invalid;
            } else {
                auto primitive_table_entry = g->primitive_type_table.maybe_get(name);
                if (primitive_table_entry) {
                    TypeTableEntry *type = primitive_table_entry->value;
                    add_node_error(g, source_node,
                            buf_sprintf("variable shadows type '%s'", buf_ptr(&type->name)));
                    variable_entry->type = g->builtin_types.entry_invalid;
                } else {
                    AstNode *decl_node = find_decl(context, name);
                    if (decl_node && decl_node->type != NodeTypeVariableDeclaration) {
                        ErrorMsg *msg = add_node_error(g, source_node,
                                buf_sprintf("redefinition of '%s'", buf_ptr(name)));
                        add_error_note(g, msg, decl_node, buf_sprintf("previous definition is here"));
                        variable_entry->type = g->builtin_types.entry_invalid;
                    }
                }
            }
        }

        context->var_table.put(&variable_entry->name, variable_entry);
    } else {
        // TODO replace _anon with @anon and make sure all tests still pass
        buf_init_from_str(&variable_entry->name, "_anon");
    }
    if (context->fn_entry) {
        context->fn_entry->variable_list.append(variable_entry);
    }

    variable_entry->is_const = is_const;
    variable_entry->decl_node = source_node;
    variable_entry->val_node = val_node;


    return variable_entry;
}

static TypeTableEntry *analyze_unwrap_error_expr(CodeGen *g, ImportTableEntry *import,
        BlockContext *parent_context, TypeTableEntry *expected_type, AstNode *node)
{
    AstNode *op1 = node->data.unwrap_err_expr.op1;
    AstNode *op2 = node->data.unwrap_err_expr.op2;
    AstNode *var_node = node->data.unwrap_err_expr.symbol;

    TypeTableEntry *lhs_type = analyze_expression(g, import, parent_context, nullptr, op1);
    if (lhs_type->id == TypeTableEntryIdInvalid) {
        return lhs_type;
    } else if (lhs_type->id == TypeTableEntryIdErrorUnion) {
        TypeTableEntry *child_type = lhs_type->data.error.child_type;
        BlockContext *child_context;
        if (var_node) {
            child_context = new_block_context(node, parent_context);
            var_node->block_context = child_context;
            Buf *var_name = var_node->data.symbol_expr.symbol;
            node->data.unwrap_err_expr.var = add_local_var(g, var_node, import, child_context, var_name,
                    g->builtin_types.entry_pure_error, true, nullptr);
        } else {
            child_context = parent_context;
        }

        analyze_expression(g, import, child_context, child_type, op2);
        return child_type;
    } else {
        add_node_error(g, op1,
            buf_sprintf("expected error type, got '%s'", buf_ptr(&lhs_type->name)));
        return g->builtin_types.entry_invalid;
    }
}


static VariableTableEntry *analyze_variable_declaration_raw(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *source_node,
        AstNodeVariableDeclaration *variable_declaration,
        bool expr_is_maybe, AstNode *decl_node, bool var_is_ptr)
{
    bool is_const = variable_declaration->is_const;
    bool is_export = (variable_declaration->top_level_decl.visib_mod == VisibModExport);
    bool is_extern = variable_declaration->is_extern;

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
    if (explicit_type && explicit_type->id == TypeTableEntryIdInvalid) {
        implicit_type = explicit_type;
    } else if (variable_declaration->expr) {
        implicit_type = analyze_expression(g, import, context, explicit_type, variable_declaration->expr);
        if (implicit_type->id == TypeTableEntryIdInvalid) {
            // ignore the poison value
        } else if (expr_is_maybe) {
            if (implicit_type->id == TypeTableEntryIdMaybe) {
                if (var_is_ptr) {
                    // TODO if the expression is constant, can't get pointer to it
                    implicit_type = get_pointer_to_type(g, implicit_type->data.maybe.child_type, false);
                } else {
                    implicit_type = implicit_type->data.maybe.child_type;
                }
            } else {
                add_node_error(g, variable_declaration->expr, buf_sprintf("expected maybe type"));
                implicit_type = g->builtin_types.entry_invalid;
            }
        } else if (implicit_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, source_node,
                buf_sprintf("variable initialization is unreachable"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if ((!is_const || is_export) &&
                (implicit_type->id == TypeTableEntryIdNumLitFloat ||
                 implicit_type->id == TypeTableEntryIdNumLitInt))
        {
            add_node_error(g, source_node, buf_sprintf("unable to infer variable type"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if (implicit_type->id == TypeTableEntryIdMetaType && !is_const) {
            add_node_error(g, source_node, buf_sprintf("variable of type 'type' must be constant"));
            implicit_type = g->builtin_types.entry_invalid;
        }
        if (implicit_type->id != TypeTableEntryIdInvalid && !context->fn_entry) {
            ConstExprValue *const_val = &get_resolved_expr(variable_declaration->expr)->const_val;
            if (!const_val->ok) {
                add_node_error(g, first_executing_node(variable_declaration->expr),
                        buf_sprintf("global variable initializer requires constant expression"));
            }
        }
    } else if (!is_extern) {
        add_node_error(g, source_node, buf_sprintf("variables must be initialized"));
        implicit_type = g->builtin_types.entry_invalid;
    }

    TypeTableEntry *type = explicit_type != nullptr ? explicit_type : implicit_type;
    assert(type != nullptr); // should have been caught by the parser

    VariableTableEntry *var = add_local_var(g, source_node, import, context,
            variable_declaration->symbol, type, is_const,
            expr_is_maybe ? nullptr : variable_declaration->expr);

    variable_declaration->variable = var;

    return var;
}

static VariableTableEntry *analyze_variable_declaration(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, TypeTableEntry *expected_type, AstNode *node)
{
    AstNodeVariableDeclaration *variable_declaration = &node->data.variable_declaration;
    return analyze_variable_declaration_raw(g, import, context, node, variable_declaration,
            false, nullptr, false);
}

static TypeTableEntry *analyze_null_literal_expr(CodeGen *g, ImportTableEntry *import,
        BlockContext *block_context, TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeNullLiteral);

    if (!expected_type) {
        add_node_error(g, node, buf_sprintf("unable to determine null type"));
        return g->builtin_types.entry_invalid;
    }

    if (expected_type->id != TypeTableEntryIdMaybe) {
        add_node_error(g, node,
                buf_sprintf("expected maybe type, got '%s'", buf_ptr(&expected_type->name)));
        return g->builtin_types.entry_invalid;
    }

    node->data.null_literal.resolved_struct_val_expr.type_entry = expected_type;
    node->data.null_literal.resolved_struct_val_expr.source_node = node;

    return resolve_expr_const_val_as_null(g, node, expected_type);
}

static TypeTableEntry *analyze_undefined_literal_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    Expr *expr = get_resolved_expr(node);
    ConstExprValue *const_val = &expr->const_val;

    const_val->ok = true;
    const_val->special = ConstValSpecialUndef;

    return expected_type ? expected_type : g->builtin_types.entry_undef;
}

static TypeTableEntry *analyze_zeroes_literal_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    Expr *expr = get_resolved_expr(node);
    ConstExprValue *const_val = &expr->const_val;

    const_val->ok = true;
    const_val->special = ConstValSpecialZeroes;

    return expected_type ? expected_type : g->builtin_types.entry_undef;
}


static TypeTableEntry *analyze_number_literal_expr(CodeGen *g, ImportTableEntry *import,
        BlockContext *block_context, TypeTableEntry *expected_type, AstNode *node)
{
    if (node->data.number_literal.overflow) {
        add_node_error(g, node, buf_sprintf("number literal too large to be represented in any type"));
        return g->builtin_types.entry_invalid;
    }

    return resolve_expr_const_val_as_bignum(g, node, expected_type, node->data.number_literal.bignum, false);
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
            if (const_val->data.x_bignum.is_negative) {
                add_node_error(g, size_node,
                    buf_sprintf("array size %s is negative",
                        buf_ptr(bignum_to_buf(&const_val->data.x_bignum))));
                return g->builtin_types.entry_invalid;
            } else {
                return resolve_expr_const_val_as_type(g, node,
                        get_array_type(g, child_type, const_val->data.x_bignum.data.x_uint), false);
            }
        } else if (context->fn_entry) {
            return resolve_expr_const_val_as_type(g, node,
                    get_slice_type(g, child_type, node->data.array_type.is_const), false);
        } else {
            add_node_error(g, first_executing_node(size_node),
                    buf_sprintf("unable to evaluate constant expression"));
            return g->builtin_types.entry_invalid;
        }
    } else {
        return resolve_expr_const_val_as_type(g, node,
                get_slice_type(g, child_type, node->data.array_type.is_const), false);
    }
}

static TypeTableEntry *analyze_fn_proto_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    TypeTableEntry *type_entry = analyze_fn_proto_type(g, import, context, expected_type, node,
            false, false, nullptr);

    if (type_entry->id == TypeTableEntryIdInvalid) {
        return type_entry;
    }

    return resolve_expr_const_val_as_type(g, node, type_entry, false);
}

static TypeTableEntry *analyze_while_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeWhileExpr);

    AstNode **condition_node = &node->data.while_expr.condition;
    AstNode *while_body_node = node->data.while_expr.body;
    AstNode **continue_expr_node = &node->data.while_expr.continue_expr;

    TypeTableEntry *condition_type = analyze_expression(g, import, context,
            g->builtin_types.entry_bool, *condition_node);

    if (*continue_expr_node) {
        analyze_expression(g, import, context, g->builtin_types.entry_void, *continue_expr_node);
    }

    BlockContext *child_context = new_block_context(node, context);
    child_context->parent_loop_node = node;

    analyze_expression(g, import, child_context, g->builtin_types.entry_void, while_body_node);


    TypeTableEntry *expr_return_type = g->builtin_types.entry_void;

    if (condition_type->id == TypeTableEntryIdInvalid) {
        expr_return_type = g->builtin_types.entry_invalid;
    } else {
        // if the condition is a simple constant expression and there are no break statements
        // then the return type is unreachable
        ConstExprValue *const_val = &get_resolved_expr(*condition_node)->const_val;
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

static TypeTableEntry *analyze_for_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeForExpr);

    AstNode *array_node = node->data.for_expr.array_expr;
    TypeTableEntry *array_type = analyze_expression(g, import, context, nullptr, array_node);
    TypeTableEntry *child_type;
    if (array_type->id == TypeTableEntryIdInvalid) {
        child_type = array_type;
    } else if (array_type->id == TypeTableEntryIdArray) {
        child_type = array_type->data.array.child_type;
    } else if (array_type->id == TypeTableEntryIdStruct &&
               array_type->data.structure.is_slice)
    {
        TypeTableEntry *pointer_type = array_type->data.structure.fields[0].type_entry;
        assert(pointer_type->id == TypeTableEntryIdPointer);
        child_type = pointer_type->data.pointer.child_type;
    } else {
        add_node_error(g, node,
            buf_sprintf("iteration over non array type '%s'", buf_ptr(&array_type->name)));
        child_type = g->builtin_types.entry_invalid;
    }

    TypeTableEntry *var_type;
    if (child_type->id != TypeTableEntryIdInvalid && node->data.for_expr.elem_is_ptr) {
        var_type = get_pointer_to_type(g, child_type, false);
    } else {
        var_type = child_type;
    }

    BlockContext *child_context = new_block_context(node, context);
    child_context->parent_loop_node = node;

    AstNode *elem_var_node = node->data.for_expr.elem_node;
    elem_var_node->block_context = child_context;
    Buf *elem_var_name = elem_var_node->data.symbol_expr.symbol;
    node->data.for_expr.elem_var = add_local_var(g, elem_var_node, import, child_context, elem_var_name,
            var_type, true, nullptr);

    AstNode *index_var_node = node->data.for_expr.index_node;
    if (index_var_node) {
        Buf *index_var_name = index_var_node->data.symbol_expr.symbol;
        index_var_node->block_context = child_context;
        node->data.for_expr.index_var = add_local_var(g, index_var_node, import, child_context, index_var_name,
                g->builtin_types.entry_usize, true, nullptr);
    } else {
        node->data.for_expr.index_var = add_local_var(g, node, import, child_context, nullptr,
                g->builtin_types.entry_usize, true, nullptr);
    }

    AstNode *for_body_node = node->data.for_expr.body;
    analyze_expression(g, import, child_context, g->builtin_types.entry_void, for_body_node);


    return g->builtin_types.entry_void;
}

static TypeTableEntry *analyze_break_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeBreak);

    AstNode *loop_node = context->parent_loop_node;
    if (loop_node) {
        if (loop_node->type == NodeTypeWhileExpr) {
            loop_node->data.while_expr.contains_break = true;
        } else if (loop_node->type == NodeTypeForExpr) {
            loop_node->data.for_expr.contains_break = true;
        } else {
            zig_unreachable();
        }
    } else {
        add_node_error(g, node, buf_sprintf("'break' expression outside loop"));
    }
    return g->builtin_types.entry_unreachable;
}

static TypeTableEntry *analyze_continue_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    AstNode *loop_node = context->parent_loop_node;
    if (loop_node) {
        if (loop_node->type == NodeTypeWhileExpr) {
            loop_node->data.while_expr.contains_continue = true;
        } else if (loop_node->type == NodeTypeForExpr) {
            loop_node->data.for_expr.contains_continue = true;
        } else {
            zig_unreachable();
        }
    } else {
        add_node_error(g, node, buf_sprintf("'continue' expression outside loop"));
    }
    return g->builtin_types.entry_unreachable;
}

static TypeTableEntry *add_error_if_type_is_num_lit(CodeGen *g, TypeTableEntry *type_entry, AstNode *source_node) {
    if (type_entry->id == TypeTableEntryIdNumLitInt ||
        type_entry->id == TypeTableEntryIdNumLitFloat)
    {
        add_node_error(g, source_node, buf_sprintf("unable to infer expression type"));
        return g->builtin_types.entry_invalid;
    } else {
        return type_entry;
    }
}

static TypeTableEntry *analyze_if(CodeGen *g, ImportTableEntry *import, BlockContext *parent_context,
        TypeTableEntry *expected_type, AstNode *node,
        AstNode **then_node, AstNode **else_node, bool cond_is_const, bool cond_bool_val)
{
    if (!*else_node) {
        *else_node = create_ast_void_node(g, import, node);
        normalize_parent_ptrs(node);
    }

    BlockContext *then_context;
    BlockContext *else_context;
    if (cond_is_const) {
        if (cond_bool_val) {
            then_context = parent_context;
            else_context = new_block_context(node, parent_context);

            else_context->codegen_excluded = true;
        } else {
            then_context = new_block_context(node, parent_context);
            else_context = parent_context;

            then_context->codegen_excluded = true;
        }
    } else {
        then_context = parent_context;
        else_context = parent_context;
    }

    TypeTableEntry *then_type = nullptr;
    TypeTableEntry *else_type = nullptr;

    if (!then_context->codegen_excluded) {
        then_type = analyze_expression(g, import, then_context, expected_type, *then_node);
        if (then_type->id == TypeTableEntryIdInvalid) {
            return g->builtin_types.entry_invalid;
        }
    }
    if (!else_context->codegen_excluded) {
        else_type = analyze_expression(g, import, else_context, expected_type, *else_node);
        if (else_type->id == TypeTableEntryIdInvalid) {
            return g->builtin_types.entry_invalid;
        }
    }

    TypeTableEntry *result_type;
    if (then_context->codegen_excluded) {
        result_type = else_type;
    } else if (else_context->codegen_excluded) {
        result_type = then_type;
    } else if (expected_type) {
        result_type = (then_type->id == TypeTableEntryIdUnreachable) ? else_type : then_type;
    } else {
        AstNode *op_nodes[] = {*then_node, *else_node};
        TypeTableEntry *op_types[] = {then_type, else_type};
        result_type = resolve_peer_type_compatibility(g, import, parent_context, node, op_nodes, op_types, 2);
    }

    if (!cond_is_const) {
        return add_error_if_type_is_num_lit(g, result_type, node);
    }

    ConstExprValue *other_const_val;
    if (cond_bool_val) {
        other_const_val = &get_resolved_expr(*then_node)->const_val;
    } else {
        other_const_val = &get_resolved_expr(*else_node)->const_val;
    }
    if (!other_const_val->ok) {
        return add_error_if_type_is_num_lit(g, result_type, node);
    }

    ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
    *const_val = *other_const_val;
    // the condition depends on a compile var, so the entire if statement does too
    const_val->depends_on_compile_var = true;
    return result_type;
}

static TypeTableEntry *analyze_if_bool_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    AstNode **cond = &node->data.if_bool_expr.condition;
    TypeTableEntry *cond_type = analyze_expression(g, import, context, g->builtin_types.entry_bool, *cond);

    if (cond_type->id == TypeTableEntryIdInvalid) {
        return cond_type;
    }

    ConstExprValue *cond_val = &get_resolved_expr(*cond)->const_val;
    if (cond_val->special == ConstValSpecialUndef) {
        add_node_error(g, first_executing_node(*cond), buf_sprintf("branch on undefined value"));
        return cond_type;
    }
    if (cond_val->ok && !cond_val->depends_on_compile_var) {
        const char *str_val = cond_val->data.x_bool ? "true" : "false";
        add_node_error(g, first_executing_node(*cond),
                buf_sprintf("condition is always %s; unnecessary if statement", str_val));
    }

    bool cond_is_const = cond_val->ok;
    bool cond_bool_val = cond_val->data.x_bool;

    AstNode **then_node = &node->data.if_bool_expr.then_block;
    AstNode **else_node = &node->data.if_bool_expr.else_node;

    return analyze_if(g, import, context, expected_type, node,
            then_node, else_node, cond_is_const, cond_bool_val);
}

static TypeTableEntry *analyze_if_var_expr(CodeGen *g, ImportTableEntry *import, BlockContext *parent_context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeIfVarExpr);

    BlockContext *child_context = new_block_context(node, parent_context);

    analyze_variable_declaration_raw(g, import, child_context, node, &node->data.if_var_expr.var_decl, true,
        nullptr, node->data.if_var_expr.var_is_ptr);
    VariableTableEntry *var = node->data.if_var_expr.var_decl.variable;
    if (var->type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    }
    AstNode *var_expr_node = node->data.if_var_expr.var_decl.expr;
    ConstExprValue *var_const_val = &get_resolved_expr(var_expr_node)->const_val;
    bool cond_is_const = var_const_val->ok;
    bool cond_bool_val = cond_is_const ? (var_const_val->data.x_maybe != nullptr) : false;


    AstNode **then_node = &node->data.if_var_expr.then_block;
    AstNode **else_node = &node->data.if_var_expr.else_node;

    return analyze_if(g, import, child_context, expected_type,
            node, then_node, else_node, cond_is_const, cond_bool_val);
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
    } else if (type_entry->id == TypeTableEntryIdInt ||
            type_entry->id == TypeTableEntryIdFloat ||
            type_entry->id == TypeTableEntryIdBool)
    {
        eval_min_max_value(g, type_entry, &get_resolved_expr(node)->const_val, is_max);
        return type_entry;
    } else {
        add_node_error(g, node,
                buf_sprintf(err_format, buf_ptr(&type_entry->name)));
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *resolve_cast(CodeGen *g, BlockContext *context, AstNode *node,
        AstNode *expr_node, TypeTableEntry *wanted_type, CastOp op, bool need_alloca)
{
    node->data.fn_call_expr.cast_op = op;

    ConstExprValue *other_val = &get_resolved_expr(expr_node)->const_val;
    TypeTableEntry *other_type = get_resolved_expr(expr_node)->type_entry;
    ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
    if (other_val->ok) {
        eval_const_expr_implicit_cast(node->data.fn_call_expr.cast_op, other_val, other_type,
                const_val, wanted_type);
    }

    if (need_alloca) {
        if (context->fn_entry) {
            context->fn_entry->cast_alloca_list.append(node);
        } else {
            assert(get_resolved_expr(node)->const_val.ok);
        }
    }
    return wanted_type;
}

static bool type_is_codegen_pointer(TypeTableEntry *type) {
    if (type->id == TypeTableEntryIdPointer) return true;
    if (type->id == TypeTableEntryIdFn) return true;
    if (type->id == TypeTableEntryIdMaybe) {
        if (type->data.maybe.child_type->id == TypeTableEntryIdPointer) return true;
        if (type->data.maybe.child_type->id == TypeTableEntryIdFn) return true;
    }
    return false;
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
    TypeTableEntry *wanted_type_canon = get_underlying_type(wanted_type);
    TypeTableEntry *actual_type_canon = get_underlying_type(actual_type);

    if (wanted_type_canon->id == TypeTableEntryIdInvalid ||
        actual_type_canon->id == TypeTableEntryIdInvalid)
    {
        return g->builtin_types.entry_invalid;
    }

    // explicit match or non-const to const
    if (types_match_const_cast_only(wanted_type, actual_type)) {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpNoop, false);
    }

    // explicit cast from bool to int
    if (wanted_type_canon->id == TypeTableEntryIdInt &&
        actual_type_canon->id == TypeTableEntryIdBool)
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpBoolToInt, false);
    }

    // explicit cast from pointer to isize or usize
    if ((wanted_type_canon == g->builtin_types.entry_isize || wanted_type_canon == g->builtin_types.entry_usize) &&
        type_is_codegen_pointer(actual_type_canon))
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpPtrToInt, false);
    }


    // explicit cast from isize or usize to pointer
    if (wanted_type_canon->id == TypeTableEntryIdPointer &&
        (actual_type_canon == g->builtin_types.entry_isize || actual_type_canon == g->builtin_types.entry_usize))
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpIntToPtr, false);
    }

    // explicit widening or shortening cast
    if ((wanted_type_canon->id == TypeTableEntryIdInt &&
        actual_type_canon->id == TypeTableEntryIdInt) ||
        (wanted_type_canon->id == TypeTableEntryIdFloat &&
        actual_type_canon->id == TypeTableEntryIdFloat))
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpWidenOrShorten, false);
    }

    // explicit cast from int to float
    if (wanted_type_canon->id == TypeTableEntryIdFloat &&
        actual_type_canon->id == TypeTableEntryIdInt)
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpIntToFloat, false);
    }

    // explicit cast from float to int
    if (wanted_type_canon->id == TypeTableEntryIdInt &&
        actual_type_canon->id == TypeTableEntryIdFloat)
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpFloatToInt, false);
    }

    // explicit cast from array to slice
    if (is_slice(wanted_type) &&
        actual_type->id == TypeTableEntryIdArray &&
        types_match_const_cast_only(
            wanted_type->data.structure.fields[0].type_entry->data.pointer.child_type,
            actual_type->data.array.child_type))
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpToUnknownSizeArray, true);
    }

    // explicit cast from []T to []u8 or []u8 to []T
    if (is_slice(wanted_type) && is_slice(actual_type) &&
        (is_u8(wanted_type->data.structure.fields[0].type_entry->data.pointer.child_type) ||
        is_u8(actual_type->data.structure.fields[0].type_entry->data.pointer.child_type)) &&
        (wanted_type->data.structure.fields[0].type_entry->data.pointer.is_const ||
         !actual_type->data.structure.fields[0].type_entry->data.pointer.is_const))
    {
        mark_impure_fn(g, context, node);
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpResizeSlice, true);
    }

    // explicit cast from [N]u8 to []T
    if (is_slice(wanted_type) &&
        actual_type->id == TypeTableEntryIdArray &&
        is_u8(actual_type->data.array.child_type))
    {
        mark_impure_fn(g, context, node);
        uint64_t child_type_size = type_size(g,
                wanted_type->data.structure.fields[0].type_entry->data.pointer.child_type);
        if (actual_type->data.array.len % child_type_size == 0) {
            return resolve_cast(g, context, node, expr_node, wanted_type, CastOpBytesToSlice, true);
        } else {
            add_node_error(g, node,
                    buf_sprintf("unable to convert %s to %s: size mismatch",
                        buf_ptr(&actual_type->name), buf_ptr(&wanted_type->name)));
            return g->builtin_types.entry_invalid;
        }
    }

    // explicit cast from pointer to another pointer
    if ((actual_type->id == TypeTableEntryIdPointer || actual_type->id == TypeTableEntryIdFn) &&
        (wanted_type->id == TypeTableEntryIdPointer || wanted_type->id == TypeTableEntryIdFn))
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpPointerReinterpret, false);
    }

    // explicit cast from maybe pointer to another maybe pointer
    if (actual_type->id == TypeTableEntryIdMaybe &&
        (actual_type->data.maybe.child_type->id == TypeTableEntryIdPointer ||
            actual_type->data.maybe.child_type->id == TypeTableEntryIdFn) &&
        wanted_type->id == TypeTableEntryIdMaybe &&
        (wanted_type->data.maybe.child_type->id == TypeTableEntryIdPointer ||
            wanted_type->data.maybe.child_type->id == TypeTableEntryIdFn))
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpPointerReinterpret, false);
    }

    // explicit cast from child type of maybe type to maybe type
    if (wanted_type->id == TypeTableEntryIdMaybe) {
        if (types_match_const_cast_only(wanted_type->data.maybe.child_type, actual_type)) {
            get_resolved_expr(node)->return_knowledge = ReturnKnowledgeKnownNonNull;
            return resolve_cast(g, context, node, expr_node, wanted_type, CastOpMaybeWrap, true);
        } else if (actual_type->id == TypeTableEntryIdNumLitInt ||
                   actual_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (num_lit_fits_in_other_type(g, expr_node, wanted_type->data.maybe.child_type)) {
                get_resolved_expr(node)->return_knowledge = ReturnKnowledgeKnownNonNull;
                return resolve_cast(g, context, node, expr_node, wanted_type, CastOpMaybeWrap, true);
            } else {
                return g->builtin_types.entry_invalid;
            }
        }
    }

    // explicit cast from child type of error type to error type
    if (wanted_type->id == TypeTableEntryIdErrorUnion) {
        if (types_match_const_cast_only(wanted_type->data.error.child_type, actual_type)) {
            get_resolved_expr(node)->return_knowledge = ReturnKnowledgeKnownNonError;
            return resolve_cast(g, context, node, expr_node, wanted_type, CastOpErrorWrap, true);
        } else if (actual_type->id == TypeTableEntryIdNumLitInt ||
                   actual_type->id == TypeTableEntryIdNumLitFloat)
        {
            if (num_lit_fits_in_other_type(g, expr_node, wanted_type->data.error.child_type)) {
                get_resolved_expr(node)->return_knowledge = ReturnKnowledgeKnownNonError;
                return resolve_cast(g, context, node, expr_node, wanted_type, CastOpErrorWrap, true);
            } else {
                return g->builtin_types.entry_invalid;
            }
        }
    }

    // explicit cast from pure error to error union type
    if (wanted_type->id == TypeTableEntryIdErrorUnion &&
        actual_type->id == TypeTableEntryIdPureError)
    {
        get_resolved_expr(node)->return_knowledge = ReturnKnowledgeKnownError;
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpPureErrorWrap, false);
    }

    // explicit cast from number literal to another type
    if (actual_type->id == TypeTableEntryIdNumLitFloat ||
        actual_type->id == TypeTableEntryIdNumLitInt)
    {
        if (num_lit_fits_in_other_type(g, expr_node, wanted_type_canon)) {
            CastOp op;
            if ((actual_type->id == TypeTableEntryIdNumLitFloat &&
                 wanted_type_canon->id == TypeTableEntryIdFloat) ||
                (actual_type->id == TypeTableEntryIdNumLitInt &&
                 wanted_type_canon->id == TypeTableEntryIdInt))
            {
                op = CastOpNoop;
            } else if (wanted_type_canon->id == TypeTableEntryIdInt) {
                op = CastOpFloatToInt;
            } else if (wanted_type_canon->id == TypeTableEntryIdFloat) {
                op = CastOpIntToFloat;
            } else {
                zig_unreachable();
            }
            return resolve_cast(g, context, node, expr_node, wanted_type, op, false);
        } else {
            return g->builtin_types.entry_invalid;
        }
    }

    // explicit cast from %void to integer type which can fit it
    bool actual_type_is_void_err = actual_type->id == TypeTableEntryIdErrorUnion &&
        !type_has_bits(actual_type->data.error.child_type);
    bool actual_type_is_pure_err = actual_type->id == TypeTableEntryIdPureError;
    if ((actual_type_is_void_err || actual_type_is_pure_err) &&
        wanted_type->id == TypeTableEntryIdInt)
    {
        BigNum bn;
        bignum_init_unsigned(&bn, g->error_decls.length);
        if (bignum_fits_in_bits(&bn, wanted_type->data.integral.bit_count,
                    wanted_type->data.integral.is_signed))
        {
            return resolve_cast(g, context, node, expr_node, wanted_type, CastOpErrToInt, false);
        } else {
            add_node_error(g, node,
                    buf_sprintf("too many error values to fit in '%s'", buf_ptr(&wanted_type->name)));
            return g->builtin_types.entry_invalid;
        }
    }

    // explicit cast from integer to enum type with no payload
    if (actual_type->id == TypeTableEntryIdInt &&
        wanted_type->id == TypeTableEntryIdEnum &&
        wanted_type->data.enumeration.gen_field_count == 0)
    {
        return resolve_cast(g, context, node, expr_node, wanted_type, CastOpIntToEnum, false);
    }

    add_node_error(g, node,
        buf_sprintf("invalid cast from type '%s' to '%s'",
            buf_ptr(&actual_type->name),
            buf_ptr(&wanted_type->name)));
    return g->builtin_types.entry_invalid;
}

static TypeTableEntry *resolve_expr_const_val_as_import(CodeGen *g, AstNode *node, ImportTableEntry *import) {
    Expr *expr = get_resolved_expr(node);
    expr->const_val.ok = true;
    expr->const_val.data.x_import = import;
    return g->builtin_types.entry_namespace;
}

static TypeTableEntry *analyze_import(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    if (context->fn_entry) {
        add_node_error(g, node, buf_sprintf("@import invalid inside function bodies"));
        return g->builtin_types.entry_invalid;
    }

    AstNode *first_param_node = node->data.fn_call_expr.params.at(0);
    Buf *import_target_str = resolve_const_expr_str(g, import, context, first_param_node->parent_field);
    if (!import_target_str) {
        return g->builtin_types.entry_invalid;
    }

    Buf *import_target_path;
    Buf *search_dir;
    assert(import->package);
    PackageTableEntry *target_package;
    auto package_entry = import->package->package_table.maybe_get(import_target_str);
    if (package_entry) {
        target_package = package_entry->value;
        import_target_path = &target_package->root_src_path;
        search_dir = &target_package->root_src_dir;
    } else {
        // try it as a filename
        target_package = import->package;
        import_target_path = import_target_str;
        search_dir = &import->package->root_src_dir;
    }

    Buf full_path = BUF_INIT;
    os_path_join(search_dir, import_target_path, &full_path);

    Buf *import_code = buf_alloc();
    Buf *abs_full_path = buf_alloc();
    int err;
    if ((err = os_path_real(&full_path, abs_full_path))) {
        if (err == ErrorFileNotFound) {
            add_node_error(g, node,
                    buf_sprintf("unable to find '%s'", buf_ptr(import_target_path)));
            return g->builtin_types.entry_invalid;
        } else {
            g->error_during_imports = true;
            add_node_error(g, node,
                    buf_sprintf("unable to open '%s': %s", buf_ptr(&full_path), err_str(err)));
            return g->builtin_types.entry_invalid;
        }
    }

    auto import_entry = g->import_table.maybe_get(abs_full_path);
    if (import_entry) {
        return resolve_expr_const_val_as_import(g, node, import_entry->value);
    }

    if ((err = os_fetch_file_path(abs_full_path, import_code))) {
        if (err == ErrorFileNotFound) {
            add_node_error(g, node,
                    buf_sprintf("unable to find '%s'", buf_ptr(import_target_path)));
            return g->builtin_types.entry_invalid;
        } else {
            add_node_error(g, node,
                    buf_sprintf("unable to open '%s': %s", buf_ptr(&full_path), err_str(err)));
            return g->builtin_types.entry_invalid;
        }
    }
    ImportTableEntry *target_import = add_source_file(g, target_package,
            abs_full_path, search_dir, import_target_path, import_code);

    scan_decls(g, target_import, target_import->block_context, target_import->root);

    return resolve_expr_const_val_as_import(g, node, target_import);
}

static TypeTableEntry *analyze_c_import(CodeGen *g, ImportTableEntry *parent_import,
        BlockContext *parent_context, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    if (parent_context->fn_entry) {
        add_node_error(g, node, buf_sprintf("@c_import invalid inside function bodies"));
        return g->builtin_types.entry_invalid;
    }

    AstNode *block_node = node->data.fn_call_expr.params.at(0);

    BlockContext *child_context = new_block_context(node, parent_context);
    child_context->c_import_buf = buf_alloc();

    TypeTableEntry *resolved_type = analyze_expression(g, parent_import, child_context,
            g->builtin_types.entry_void, block_node);

    if (resolved_type->id == TypeTableEntryIdInvalid) {
        return resolved_type;
    }

    find_libc_include_path(g);

    ImportTableEntry *child_import = allocate<ImportTableEntry>(1);
    child_import->c_import_node = node;

    ZigList<ErrorMsg *> errors = {0};

    int err;
    if ((err = parse_h_buf(child_import, &errors, child_context->c_import_buf, g, node))) {
        zig_panic("unable to parse h file: %s\n", err_str(err));
    }

    if (errors.length > 0) {
        ErrorMsg *parent_err_msg = add_node_error(g, node, buf_sprintf("C import failed"));
        for (int i = 0; i < errors.length; i += 1) {
            ErrorMsg *err_msg = errors.at(i);
            err_msg_add_note(parent_err_msg, err_msg);
        }

        return g->builtin_types.entry_invalid;
    }

    if (g->verbose) {
        fprintf(stderr, "\nc_import:\n");
        fprintf(stderr, "-----------\n");
        ast_render(stderr, child_import->root, 4);
    }

    child_import->di_file = parent_import->di_file;
    child_import->block_context = new_block_context(child_import->root, nullptr);

    scan_decls(g, child_import, child_import->block_context, child_import->root);
    return resolve_expr_const_val_as_import(g, node, child_import);
}

static TypeTableEntry *analyze_err_name(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *err_value = node->data.fn_call_expr.params.at(0);
    TypeTableEntry *resolved_type = analyze_expression(g, import, context,
            g->builtin_types.entry_pure_error, err_value);

    if (resolved_type->id == TypeTableEntryIdInvalid) {
        return resolved_type;
    }

    g->generate_error_name_table = true;

    TypeTableEntry *str_type = get_slice_type(g, g->builtin_types.entry_u8, true);
    return str_type;
}

static TypeTableEntry *analyze_embed_file(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode **first_param_node = &node->data.fn_call_expr.params.at(0);
    Buf *rel_file_path = resolve_const_expr_str(g, import, context, first_param_node);
    if (!rel_file_path) {
        return g->builtin_types.entry_invalid;
    }

    // figure out absolute path to resource
    Buf source_dir_path = BUF_INIT;
    os_path_dirname(import->path, &source_dir_path);

    Buf file_path = BUF_INIT;
    os_path_resolve(&source_dir_path, rel_file_path, &file_path);

    // load from file system into const expr
    Buf file_contents = BUF_INIT;
    int err;
    if ((err = os_fetch_file_path(&file_path, &file_contents))) {
        if (err == ErrorFileNotFound) {
            add_node_error(g, node,
                    buf_sprintf("unable to find '%s'", buf_ptr(&file_path)));
            return g->builtin_types.entry_invalid;
        } else {
            add_node_error(g, node,
                    buf_sprintf("unable to open '%s': %s", buf_ptr(&file_path), err_str(err)));
            return g->builtin_types.entry_invalid;
        }
    }

    // TODO add dependency on the file we embedded so that we know if it changes
    // we'll have to invalidate the cache

    return resolve_expr_const_val_as_string_lit(g, node, &file_contents);
}

static TypeTableEntry *analyze_cmpxchg(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode **ptr_arg = &node->data.fn_call_expr.params.at(0);
    AstNode **cmp_arg = &node->data.fn_call_expr.params.at(1);
    AstNode **new_arg = &node->data.fn_call_expr.params.at(2);
    AstNode **success_order_arg = &node->data.fn_call_expr.params.at(3);
    AstNode **failure_order_arg = &node->data.fn_call_expr.params.at(4);

    TypeTableEntry *ptr_type = analyze_expression(g, import, context, nullptr, *ptr_arg);
    if (ptr_type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    } else if (ptr_type->id != TypeTableEntryIdPointer) {
        add_node_error(g, *ptr_arg,
            buf_sprintf("expected pointer argument, got '%s'", buf_ptr(&ptr_type->name)));
        return g->builtin_types.entry_invalid;
    }

    TypeTableEntry *child_type = ptr_type->data.pointer.child_type;
    TypeTableEntry *cmp_type = analyze_expression(g, import, context, child_type, *cmp_arg);
    TypeTableEntry *new_type = analyze_expression(g, import, context, child_type, *new_arg);

    TypeTableEntry *success_order_type = analyze_expression(g, import, context,
            g->builtin_types.entry_atomic_order_enum, *success_order_arg);
    TypeTableEntry *failure_order_type = analyze_expression(g, import, context,
            g->builtin_types.entry_atomic_order_enum, *failure_order_arg);

    if (cmp_type->id == TypeTableEntryIdInvalid ||
        new_type->id == TypeTableEntryIdInvalid ||
        success_order_type->id == TypeTableEntryIdInvalid ||
        failure_order_type->id == TypeTableEntryIdInvalid)
    {
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *success_order_val = &get_resolved_expr(*success_order_arg)->const_val;
    ConstExprValue *failure_order_val = &get_resolved_expr(*failure_order_arg)->const_val;
    if (!success_order_val->ok) {
        add_node_error(g, *success_order_arg, buf_sprintf("unable to evaluate constant expression"));
        return g->builtin_types.entry_invalid;
    } else if (!failure_order_val->ok) {
        add_node_error(g, *failure_order_arg, buf_sprintf("unable to evaluate constant expression"));
        return g->builtin_types.entry_invalid;
    }

    if (success_order_val->data.x_enum.tag < AtomicOrderMonotonic) {
        add_node_error(g, *success_order_arg,
                buf_sprintf("success atomic ordering must be Monotonic or stricter"));
        return g->builtin_types.entry_invalid;
    }
    if (failure_order_val->data.x_enum.tag < AtomicOrderMonotonic) {
        add_node_error(g, *failure_order_arg,
                buf_sprintf("failure atomic ordering must be Monotonic or stricter"));
        return g->builtin_types.entry_invalid;
    }
    if (failure_order_val->data.x_enum.tag > success_order_val->data.x_enum.tag) {
        add_node_error(g, *failure_order_arg,
                buf_sprintf("failure atomic ordering must be no stricter than success"));
        return g->builtin_types.entry_invalid;
    }
    if (failure_order_val->data.x_enum.tag == AtomicOrderRelease ||
        failure_order_val->data.x_enum.tag == AtomicOrderAcqRel)
    {
        add_node_error(g, *failure_order_arg,
                buf_sprintf("failure atomic ordering must not be Release or AcqRel"));
        return g->builtin_types.entry_invalid;
    }

    return g->builtin_types.entry_bool;
}

static TypeTableEntry *analyze_fence(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode **atomic_order_arg = &node->data.fn_call_expr.params.at(0);
    TypeTableEntry *atomic_order_type = analyze_expression(g, import, context,
            g->builtin_types.entry_atomic_order_enum, *atomic_order_arg);

    if (atomic_order_type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *atomic_order_val = &get_resolved_expr(*atomic_order_arg)->const_val;

    if (!atomic_order_val->ok) {
        add_node_error(g, *atomic_order_arg, buf_sprintf("unable to evaluate constant expression"));
        return g->builtin_types.entry_invalid;
    }

    return g->builtin_types.entry_void;
}

static TypeTableEntry *analyze_div_exact(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode **op1 = &node->data.fn_call_expr.params.at(0);
    AstNode **op2 = &node->data.fn_call_expr.params.at(1);

    TypeTableEntry *op1_type = analyze_expression(g, import, context, nullptr, *op1);
    TypeTableEntry *op2_type = analyze_expression(g, import, context, nullptr, *op2);

    AstNode *op_nodes[] = {*op1, *op2};
    TypeTableEntry *op_types[] = {op1_type, op2_type};
    TypeTableEntry *result_type = resolve_peer_type_compatibility(g, import, context, node,
            op_nodes, op_types, 2);

    if (result_type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    } else if (result_type->id == TypeTableEntryIdInt) {
        return result_type;
    } else if (result_type->id == TypeTableEntryIdNumLitInt) {
        // check for division by zero
        // check for non exact division
        zig_panic("TODO");
    } else {
        add_node_error(g, node,
                buf_sprintf("expected integer type, got '%s'", buf_ptr(&result_type->name)));
        return g->builtin_types.entry_invalid;
    }
}

static TypeTableEntry *analyze_truncate(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode **op1 = &node->data.fn_call_expr.params.at(0);
    AstNode **op2 = &node->data.fn_call_expr.params.at(1);

    TypeTableEntry *dest_type = analyze_type_expr(g, import, context, *op1);
    TypeTableEntry *src_type = analyze_expression(g, import, context, nullptr, *op2);

    if (dest_type->id == TypeTableEntryIdInvalid || src_type->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    } else if (dest_type->id != TypeTableEntryIdInt) {
        add_node_error(g, *op1,
                buf_sprintf("expected integer type, got '%s'", buf_ptr(&dest_type->name)));
        return g->builtin_types.entry_invalid;
    } else if (src_type->id != TypeTableEntryIdInt) {
        add_node_error(g, *op2,
                buf_sprintf("expected integer type, got '%s'", buf_ptr(&src_type->name)));
        return g->builtin_types.entry_invalid;
    } else if (src_type->data.integral.is_signed != dest_type->data.integral.is_signed) {
        const char *sign_str = dest_type->data.integral.is_signed ? "signed" : "unsigned";
        add_node_error(g, *op2,
                buf_sprintf("expected %s integer type, got '%s'", sign_str, buf_ptr(&src_type->name)));
        return g->builtin_types.entry_invalid;
    } else if (src_type->data.integral.bit_count <= dest_type->data.integral.bit_count) {
        add_node_error(g, *op2,
                buf_sprintf("type '%s' has same or fewer bits than destination type '%s'",
                    buf_ptr(&src_type->name), buf_ptr(&dest_type->name)));
        return g->builtin_types.entry_invalid;
    }

    // TODO const expr eval

    return dest_type;
}

static TypeTableEntry *analyze_compile_err(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    AstNode *first_param_node = node->data.fn_call_expr.params.at(0);
    Buf *err_msg = resolve_const_expr_str(g, import, context, first_param_node->parent_field);
    if (!err_msg) {
        return g->builtin_types.entry_invalid;
    }

    add_node_error(g, node, err_msg);

    return g->builtin_types.entry_invalid;
}

static TypeTableEntry *analyze_int_type(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node)
{
    AstNode **is_signed_node = &node->data.fn_call_expr.params.at(0);
    AstNode **bit_count_node = &node->data.fn_call_expr.params.at(1);

    TypeTableEntry *bool_type = g->builtin_types.entry_bool;
    TypeTableEntry *usize_type = g->builtin_types.entry_usize;
    TypeTableEntry *is_signed_type = analyze_expression(g, import, context, bool_type, *is_signed_node);
    TypeTableEntry *bit_count_type = analyze_expression(g, import, context, usize_type, *bit_count_node);

    if (is_signed_type->id == TypeTableEntryIdInvalid ||
        bit_count_type->id == TypeTableEntryIdInvalid)
    {
        return g->builtin_types.entry_invalid;
    }

    ConstExprValue *is_signed_val = &get_resolved_expr(*is_signed_node)->const_val;
    ConstExprValue *bit_count_val = &get_resolved_expr(*bit_count_node)->const_val;

    AstNode *bad_node = nullptr;
    if (!is_signed_val->ok) {
        bad_node = *is_signed_node;
    } else if (!bit_count_val->ok) {
        bad_node = *bit_count_node;
    }
    if (bad_node) {
        add_node_error(g, bad_node, buf_sprintf("unable to evaluate constant expression"));
        return g->builtin_types.entry_invalid;
    }

    bool depends_on_compile_var = is_signed_val->depends_on_compile_var || bit_count_val->depends_on_compile_var;

    TypeTableEntry *int_type = get_int_type(g, is_signed_val->data.x_bool,
            bit_count_val->data.x_bignum.data.x_uint);
    return resolve_expr_const_val_as_type(g, node, int_type, depends_on_compile_var);

}

static TypeTableEntry *analyze_builtin_fn_call_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeFnCallExpr);

    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;
    Buf *name = fn_ref_expr->data.symbol_expr.symbol;

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

    builtin_fn->ref_count += 1;

    switch (builtin_fn->id) {
        case BuiltinFnIdInvalid:
            zig_unreachable();
        case BuiltinFnIdAddWithOverflow:
        case BuiltinFnIdSubWithOverflow:
        case BuiltinFnIdMulWithOverflow:
        case BuiltinFnIdShlWithOverflow:
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
                    uint64_t dest_align = get_memcpy_align(g, dest_type->data.pointer.child_type);
                    uint64_t src_align = get_memcpy_align(g, src_type->data.pointer.child_type);
                    if (dest_align != src_align) {
                        add_node_error(g, dest_node, buf_sprintf(
                            "misaligned memcpy, '%s' has alignment '%" PRIu64 ", '%s' has alignment %" PRIu64,
                                    buf_ptr(&dest_type->name), dest_align,
                                    buf_ptr(&src_type->name), src_align));
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
                    uint64_t size_in_bytes = type_size(g, type_entry);
                    bool depends_on_compile_var = (type_entry == g->builtin_types.entry_usize ||
                            type_entry == g->builtin_types.entry_isize);
                    return resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type,
                            size_in_bytes, depends_on_compile_var);
                }
            }
        case BuiltinFnIdAlignof:
            {
                AstNode *type_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *type_entry = analyze_type_expr(g, import, context, type_node);
                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else if (type_entry->id == TypeTableEntryIdUnreachable) {
                    add_node_error(g, first_executing_node(type_node),
                            buf_sprintf("no align available for type '%s'", buf_ptr(&type_entry->name)));
                    return g->builtin_types.entry_invalid;
                } else {
                    uint64_t align_in_bytes = LLVMABISizeOfType(g->target_data_ref, type_entry->type_ref);
                    return resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type,
                            align_in_bytes, false);
                }
            }
        case BuiltinFnIdMaxValue:
            return analyze_min_max_value(g, import, context, node,
                    "no max value available for type '%s'", true);
        case BuiltinFnIdMinValue:
            return analyze_min_max_value(g, import, context, node,
                    "no min value available for type '%s'", false);
        case BuiltinFnIdMemberCount:
            {
                AstNode *type_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *type_entry = analyze_type_expr(g, import, context, type_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdEnum) {
                    uint64_t value_count = type_entry->data.enumeration.field_count;
                    return resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type,
                            value_count, false);
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

                switch (type_entry->id) {
                    case TypeTableEntryIdInvalid:
                        return type_entry;
                    case TypeTableEntryIdNumLitFloat:
                    case TypeTableEntryIdNumLitInt:
                    case TypeTableEntryIdUndefLit:
                    case TypeTableEntryIdNamespace:
                    case TypeTableEntryIdGenericFn:
                        add_node_error(g, expr_node,
                                buf_sprintf("type '%s' not eligible for @typeOf", buf_ptr(&type_entry->name)));
                        return g->builtin_types.entry_invalid;
                    case TypeTableEntryIdMetaType:
                    case TypeTableEntryIdVoid:
                    case TypeTableEntryIdBool:
                    case TypeTableEntryIdUnreachable:
                    case TypeTableEntryIdInt:
                    case TypeTableEntryIdFloat:
                    case TypeTableEntryIdPointer:
                    case TypeTableEntryIdArray:
                    case TypeTableEntryIdStruct:
                    case TypeTableEntryIdMaybe:
                    case TypeTableEntryIdErrorUnion:
                    case TypeTableEntryIdPureError:
                    case TypeTableEntryIdEnum:
                    case TypeTableEntryIdUnion:
                    case TypeTableEntryIdFn:
                    case TypeTableEntryIdTypeDecl:
                        return resolve_expr_const_val_as_type(g, node, type_entry, false);
                }
            }
        case BuiltinFnIdCInclude:
            {
                if (!context->c_import_buf) {
                    add_node_error(g, node, buf_sprintf("@c_include valid only in c_import blocks"));
                    return g->builtin_types.entry_invalid;
                }

                AstNode **str_node = node->data.fn_call_expr.params.at(0)->parent_field;
                TypeTableEntry *str_type = get_slice_type(g, g->builtin_types.entry_u8, true);
                TypeTableEntry *resolved_type = analyze_expression(g, import, context, str_type, *str_node);

                if (resolved_type->id == TypeTableEntryIdInvalid) {
                    return resolved_type;
                }

                ConstExprValue *const_str_val = &get_resolved_expr(*str_node)->const_val;

                if (!const_str_val->ok) {
                    add_node_error(g, *str_node, buf_sprintf("@c_include requires constant expression"));
                    return g->builtin_types.entry_void;
                }

                buf_appendf(context->c_import_buf, "#include <");
                ConstExprValue *ptr_field = const_str_val->data.x_struct.fields[0];
                uint64_t len = ptr_field->data.x_ptr.len;
                for (uint64_t i = 0; i < len; i += 1) {
                    ConstExprValue *char_val = ptr_field->data.x_ptr.ptr[i];
                    uint64_t big_c = char_val->data.x_bignum.data.x_uint;
                    assert(big_c <= UINT8_MAX);
                    uint8_t c = big_c;
                    buf_append_char(context->c_import_buf, c);
                }
                buf_appendf(context->c_import_buf, ">\n");

                return g->builtin_types.entry_void;
            }
        case BuiltinFnIdCDefine:
            zig_panic("TODO");
        case BuiltinFnIdCUndef:
            zig_panic("TODO");

        case BuiltinFnIdCompileVar:
            {
                AstNode **str_node = node->data.fn_call_expr.params.at(0)->parent_field;

                Buf *var_name = resolve_const_expr_str(g, import, context, str_node);
                if (!var_name) {
                    return g->builtin_types.entry_invalid;
                }

                ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
                const_val->ok = true;
                const_val->depends_on_compile_var = true;

                if (buf_eql_str(var_name, "is_big_endian")) {
                    return resolve_expr_const_val_as_bool(g, node, g->is_big_endian, true);
                } else if (buf_eql_str(var_name, "is_release")) {
                    return resolve_expr_const_val_as_bool(g, node, g->is_release_build, true);
                } else if (buf_eql_str(var_name, "is_test")) {
                    return resolve_expr_const_val_as_bool(g, node, g->is_test_build, true);
                } else if (buf_eql_str(var_name, "os")) {
                    const_val->data.x_enum.tag = g->target_os_index;
                    return g->builtin_types.entry_os_enum;
                } else if (buf_eql_str(var_name, "arch")) {
                    const_val->data.x_enum.tag = g->target_arch_index;
                    return g->builtin_types.entry_arch_enum;
                } else if (buf_eql_str(var_name, "environ")) {
                    const_val->data.x_enum.tag = g->target_environ_index;
                    return g->builtin_types.entry_environ_enum;
                } else if (buf_eql_str(var_name, "object_format")) {
                    const_val->data.x_enum.tag = g->target_oformat_index;
                    return g->builtin_types.entry_oformat_enum;
                } else {
                    add_node_error(g, *str_node,
                        buf_sprintf("unrecognized compile variable: '%s'", buf_ptr(var_name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case BuiltinFnIdConstEval:
            {
                AstNode **expr_node = node->data.fn_call_expr.params.at(0)->parent_field;
                TypeTableEntry *resolved_type = analyze_expression(g, import, context, expected_type, *expr_node);
                if (resolved_type->id == TypeTableEntryIdInvalid) {
                    return resolved_type;
                }

                ConstExprValue *const_expr_val = &get_resolved_expr(*expr_node)->const_val;

                if (!const_expr_val->ok) {
                    add_node_error(g, *expr_node, buf_sprintf("unable to evaluate constant expression"));
                    return g->builtin_types.entry_invalid;
                }

                ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
                *const_val = *const_expr_val;

                return resolved_type;
            }
        case BuiltinFnIdCtz:
        case BuiltinFnIdClz:
            {
                AstNode *type_node = node->data.fn_call_expr.params.at(0);
                TypeTableEntry *int_type = analyze_type_expr(g, import, context, type_node);
                if (int_type->id == TypeTableEntryIdInvalid) {
                    return int_type;
                } else if (int_type->id == TypeTableEntryIdInt) {
                    AstNode **expr_node = node->data.fn_call_expr.params.at(1)->parent_field;
                    TypeTableEntry *resolved_type = analyze_expression(g, import, context, int_type, *expr_node);
                    if (resolved_type->id == TypeTableEntryIdInvalid) {
                        return resolved_type;
                    }

                    // TODO const expr eval

                    return resolved_type;
                } else {
                    add_node_error(g, type_node,
                        buf_sprintf("expected integer type, got '%s'", buf_ptr(&int_type->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case BuiltinFnIdImport:
            return analyze_import(g, import, context, node);
        case BuiltinFnIdCImport:
            return analyze_c_import(g, import, context, node);
        case BuiltinFnIdErrName:
            return analyze_err_name(g, import, context, node);
        case BuiltinFnIdBreakpoint:
            mark_impure_fn(g, context, node);
            return g->builtin_types.entry_void;
        case BuiltinFnIdReturnAddress:
        case BuiltinFnIdFrameAddress:
            mark_impure_fn(g, context, node);
            return builtin_fn->return_type;
        case BuiltinFnIdEmbedFile:
            return analyze_embed_file(g, import, context, node);
        case BuiltinFnIdCmpExchange:
            return analyze_cmpxchg(g, import, context, node);
        case BuiltinFnIdFence:
            return analyze_fence(g, import, context, node);
        case BuiltinFnIdDivExact:
            return analyze_div_exact(g, import, context, node);
        case BuiltinFnIdTruncate:
            return analyze_truncate(g, import, context, node);
        case BuiltinFnIdCompileErr:
            return analyze_compile_err(g, import, context, node);
        case BuiltinFnIdIntType:
            return analyze_int_type(g, import, context, node);
    }
    zig_unreachable();
}

// Before calling this function, set node->data.fn_call_expr.fn_table_entry if the function is known
// at compile time. Otherwise this is a function pointer call.
static TypeTableEntry *analyze_fn_call_ptr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node, TypeTableEntry *fn_type,
        AstNode *struct_node)
{
    assert(node->type == NodeTypeFnCallExpr);

    if (fn_type->id == TypeTableEntryIdInvalid) {
        return fn_type;
    }

    // The function call might include inline parameters which we need to ignore according to the
    // fn_type.
    FnTableEntry *fn_table_entry = node->data.fn_call_expr.fn_entry;
    AstNode *generic_proto_node = fn_table_entry ?
        fn_table_entry->proto_node->data.fn_proto.generic_proto_node : nullptr;

    // count parameters
    int struct_node_1_or_0 = struct_node ? 1 : 0;
    int src_param_count = fn_type->data.fn.fn_type_id.param_count +
        (generic_proto_node ? generic_proto_node->data.fn_proto.inline_arg_count : 0);
    int call_param_count = node->data.fn_call_expr.params.length;

    bool ok_invocation = true;

    if (fn_type->data.fn.fn_type_id.is_var_args) {
        if (call_param_count < src_param_count - struct_node_1_or_0) {
            ok_invocation = false;
            add_node_error(g, node,
                buf_sprintf("expected at least %d arguments, got %d", src_param_count, call_param_count));
        }
    } else if (src_param_count - struct_node_1_or_0 != call_param_count) {
        ok_invocation = false;
        add_node_error(g, node,
                buf_sprintf("expected %d arguments, got %d", src_param_count, call_param_count));
    }

    bool all_args_const_expr = true;

    if (struct_node) {
        ConstExprValue *struct_const_val = &get_resolved_expr(struct_node)->const_val;
        if (!struct_const_val->ok) {
            all_args_const_expr = false;
        }
    }

    // analyze each parameter. in the case of a method, we already analyzed the
    // first parameter in order to figure out which struct we were calling a method on.
    int next_type_i = struct_node_1_or_0;
    for (int call_i = 0; call_i < call_param_count; call_i += 1) {
        int proto_i = call_i + struct_node_1_or_0;
        AstNode **param_node = &node->data.fn_call_expr.params.at(call_i);
        // determine the expected type for each parameter
        TypeTableEntry *expected_param_type = nullptr;
        if (proto_i < src_param_count) {
            if (generic_proto_node &&
                generic_proto_node->data.fn_proto.params.at(proto_i)->data.param_decl.is_inline)
            {
                continue;
            }

            FnTypeParamInfo *param_info = &fn_type->data.fn.fn_type_id.param_info[next_type_i];
            next_type_i += 1;

            expected_param_type = param_info->type;
        }
        TypeTableEntry *param_type = analyze_expression(g, import, context, expected_param_type, *param_node);
        if (param_type->id == TypeTableEntryIdInvalid) {
            return param_type;
        }

        ConstExprValue *const_arg_val = &get_resolved_expr(*param_node)->const_val;
        if (!const_arg_val->ok) {
            all_args_const_expr = false;
        }
    }

    TypeTableEntry *return_type = fn_type->data.fn.fn_type_id.return_type;

    if (return_type->id == TypeTableEntryIdInvalid) {
        return return_type;
    }

    ConstExprValue *result_val = &get_resolved_expr(node)->const_val;
    if (ok_invocation && fn_table_entry && fn_table_entry->is_pure && fn_table_entry->want_pure != WantPureFalse) {
        if (fn_table_entry->anal_state == FnAnalStateReady) {
            analyze_fn_body(g, fn_table_entry);
            if (fn_table_entry->proto_node->data.fn_proto.skip) {
                return g->builtin_types.entry_invalid;
            }
        }
        if (all_args_const_expr) {
            if (fn_table_entry->is_pure && fn_table_entry->anal_state == FnAnalStateComplete) {
                if (eval_fn(g, node, fn_table_entry, result_val, 1000, struct_node)) {
                    // function evaluation generated an error
                    return g->builtin_types.entry_invalid;
                }
                return return_type;
            }
        }
    }
    if (!ok_invocation || !fn_table_entry || !fn_table_entry->is_pure || fn_table_entry->want_pure == WantPureFalse) {
        // calling an impure fn is impure
        mark_impure_fn(g, context, node);
        if (fn_table_entry && fn_table_entry->want_pure == WantPureTrue) {
            return g->builtin_types.entry_invalid;
        }
    }

    if (handle_is_ptr(return_type)) {
        if (context->fn_entry) {
            context->fn_entry->cast_alloca_list.append(node);
        } else if (!result_val->ok) {
            add_node_error(g, node, buf_sprintf("unable to evaluate constant expression"));
        }
    }

    return return_type;
}

static TypeTableEntry *analyze_fn_call_with_inline_args(CodeGen *g, ImportTableEntry *import,
        BlockContext *parent_context, TypeTableEntry *expected_type, AstNode *call_node,
        FnTableEntry *fn_table_entry, AstNode *struct_node)
{
    assert(call_node->type == NodeTypeFnCallExpr);
    assert(fn_table_entry);

    AstNode *decl_node = fn_table_entry->proto_node;

    // count parameters
    int struct_node_1_or_0 = (struct_node ? 1 : 0);
    int src_param_count = decl_node->data.fn_proto.params.length;
    int call_param_count = call_node->data.fn_call_expr.params.length;

    if (src_param_count != call_param_count + struct_node_1_or_0) {
        add_node_error(g, call_node,
            buf_sprintf("expected %d arguments, got %d", src_param_count, call_param_count));
        return g->builtin_types.entry_invalid;
    }

    int inline_arg_count = decl_node->data.fn_proto.inline_arg_count;
    assert(inline_arg_count > 0);

    BlockContext *child_context = decl_node->owner->block_context;
    int next_generic_param_index = 0;

    GenericFnTypeId *generic_fn_type_id = allocate<GenericFnTypeId>(1);
    generic_fn_type_id->decl_node = decl_node;
    generic_fn_type_id->generic_param_count = inline_arg_count;
    generic_fn_type_id->generic_params = allocate<GenericParamValue>(inline_arg_count);

    for (int call_i = 0; call_i < call_param_count; call_i += 1) {
        int proto_i = call_i + struct_node_1_or_0;
        AstNode *generic_param_decl_node = decl_node->data.fn_proto.params.at(proto_i);
        assert(generic_param_decl_node->type == NodeTypeParamDecl);
        bool is_inline = generic_param_decl_node->data.param_decl.is_inline;
        if (!is_inline) continue;

        AstNode **generic_param_type_node = &generic_param_decl_node->data.param_decl.type;
        TypeTableEntry *expected_param_type = analyze_type_expr(g, decl_node->owner, child_context,
                *generic_param_type_node);
        if (expected_param_type->id == TypeTableEntryIdInvalid) {
            return expected_param_type;
        }

        AstNode **param_node = &call_node->data.fn_call_expr.params.at(call_i);
        TypeTableEntry *param_type = analyze_expression(g, import, parent_context,
                expected_param_type, *param_node);
        if (param_type->id == TypeTableEntryIdInvalid) {
            return param_type;
        }

        // set child_context so that the previous param is in scope
        child_context = new_block_context(generic_param_decl_node, child_context);

        ConstExprValue *const_val = &get_resolved_expr(*param_node)->const_val;
        if (const_val->ok) {
            VariableTableEntry *var = add_local_var(g, generic_param_decl_node, decl_node->owner, child_context,
                    generic_param_decl_node->data.param_decl.name, param_type, true, *param_node);
            // This generic function instance could be called with anything, so when this variable is read it
            // needs to know that it depends on compile time variable data.
            var->force_depends_on_compile_var = true;
        } else {
            add_node_error(g, *param_node,
                    buf_sprintf("unable to evaluate constant expression for inline parameter"));

            return g->builtin_types.entry_invalid;
        }

        GenericParamValue *generic_param_value =
            &generic_fn_type_id->generic_params[next_generic_param_index];
        generic_param_value->type = param_type;
        generic_param_value->node = *param_node;
        next_generic_param_index += 1;
    }

    assert(next_generic_param_index == inline_arg_count);

    auto entry = g->generic_table.maybe_get(generic_fn_type_id);
    FnTableEntry *impl_fn;
    if (entry) {
        AstNode *impl_decl_node = entry->value;
        assert(impl_decl_node->type == NodeTypeFnProto);
        impl_fn = impl_decl_node->data.fn_proto.fn_table_entry;
    } else {
        AstNode *decl_node = generic_fn_type_id->decl_node;
        AstNode *impl_fn_def_node = ast_clone_subtree_special(decl_node->data.fn_proto.fn_def_node,
                &g->next_node_index, AstCloneSpecialOmitInlineParams);
        AstNode *impl_decl_node = impl_fn_def_node->data.fn_def.fn_proto;
        impl_decl_node->data.fn_proto.inline_arg_count = 0;
        impl_decl_node->data.fn_proto.generic_proto_node = decl_node;

        preview_fn_proto_instance(g, import, impl_decl_node, child_context);
        g->generic_table.put(generic_fn_type_id, impl_decl_node);
        impl_fn = impl_decl_node->data.fn_proto.fn_table_entry;
    }

    call_node->data.fn_call_expr.fn_entry = impl_fn;
    return analyze_fn_call_ptr(g, import, parent_context, expected_type, call_node,
            impl_fn->type_entry, struct_node);
}

static TypeTableEntry *analyze_generic_fn_call(CodeGen *g, ImportTableEntry *import, BlockContext *parent_context,
        TypeTableEntry *expected_type, AstNode *node, TypeTableEntry *generic_fn_type)
{
    assert(node->type == NodeTypeFnCallExpr);
    assert(generic_fn_type->id == TypeTableEntryIdGenericFn);

    AstNode *decl_node = generic_fn_type->data.generic_fn.decl_node;
    assert(decl_node->type == NodeTypeContainerDecl);
    ZigList<AstNode *> *generic_params = &decl_node->data.struct_decl.generic_params;

    int expected_param_count = generic_params->length;
    int actual_param_count = node->data.fn_call_expr.params.length;

    if (actual_param_count != expected_param_count) {
        add_node_error(g, first_executing_node(node),
                buf_sprintf("expected %d arguments, got %d", expected_param_count, actual_param_count));
        return g->builtin_types.entry_invalid;
    }

    GenericFnTypeId *generic_fn_type_id = allocate<GenericFnTypeId>(1);
    generic_fn_type_id->decl_node = decl_node;
    generic_fn_type_id->generic_param_count = actual_param_count;
    generic_fn_type_id->generic_params = allocate<GenericParamValue>(actual_param_count);

    BlockContext *child_context = decl_node->owner->block_context;
    for (int i = 0; i < actual_param_count; i += 1) {
        AstNode *generic_param_decl_node = generic_params->at(i);
        assert(generic_param_decl_node->type == NodeTypeParamDecl);

        AstNode **generic_param_type_node = &generic_param_decl_node->data.param_decl.type;

        TypeTableEntry *expected_param_type = analyze_type_expr(g, decl_node->owner,
                child_context, *generic_param_type_node);
        if (expected_param_type->id == TypeTableEntryIdInvalid) {
            return expected_param_type;
        }
        AstNode **param_node = &node->data.fn_call_expr.params.at(i);

        TypeTableEntry *param_type = analyze_expression(g, import, parent_context, expected_param_type,
                *param_node);
        if (param_type->id == TypeTableEntryIdInvalid) {
            return param_type;
        }

        // set child_context so that the previous param is in scope
        child_context = new_block_context(generic_param_decl_node, child_context);

        ConstExprValue *const_val = &get_resolved_expr(*param_node)->const_val;
        if (const_val->ok) {
            VariableTableEntry *var = add_local_var(g, generic_param_decl_node, decl_node->owner, child_context,
                    generic_param_decl_node->data.param_decl.name, param_type, true, *param_node);
            var->force_depends_on_compile_var = true;
        } else {
            add_node_error(g, *param_node, buf_sprintf("unable to evaluate constant expression"));

            return g->builtin_types.entry_invalid;
        }

        GenericParamValue *generic_param_value = &generic_fn_type_id->generic_params[i];
        generic_param_value->type = param_type;
        generic_param_value->node = *param_node;
    }

    auto entry = g->generic_table.maybe_get(generic_fn_type_id);
    if (entry) {
        AstNode *impl_decl_node = entry->value;
        assert(impl_decl_node->type == NodeTypeContainerDecl);
        TypeTableEntry *type_entry = impl_decl_node->data.struct_decl.type_entry;
        return resolve_expr_const_val_as_type(g, node, type_entry, false);
    }

    // make a type from the generic parameters supplied
    assert(decl_node->type == NodeTypeContainerDecl);
    AstNode *impl_decl_node = ast_clone_subtree(decl_node, &g->next_node_index);
    g->generic_table.put(generic_fn_type_id, impl_decl_node);
    scan_struct_decl(g, import, child_context, impl_decl_node);
    TypeTableEntry *type_entry = impl_decl_node->data.struct_decl.type_entry;
    resolve_struct_type(g, import, type_entry);
    return resolve_expr_const_val_as_type(g, node, type_entry, false);
}

static TypeTableEntry *analyze_fn_call_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    AstNode *fn_ref_expr = node->data.fn_call_expr.fn_ref_expr;

    if (node->data.fn_call_expr.is_builtin) {
        return analyze_builtin_fn_call_expr(g, import, context, expected_type, node);
    }

    if (fn_ref_expr->type == NodeTypeFieldAccessExpr) {
        fn_ref_expr->data.field_access_expr.is_fn_call = true;
    }

    TypeTableEntry *invoke_type_entry = analyze_expression(g, import, context, nullptr, fn_ref_expr);
    if (invoke_type_entry->id == TypeTableEntryIdInvalid) {
        return g->builtin_types.entry_invalid;
    }

    // use constant expression evaluator to figure out the function at compile time.
    // otherwise we treat this as a function pointer.
    ConstExprValue *const_val = &get_resolved_expr(fn_ref_expr)->const_val;

    if (const_val->ok) {
        if (invoke_type_entry->id == TypeTableEntryIdMetaType) {
            return analyze_cast_expr(g, import, context, node);
        } else if (invoke_type_entry->id == TypeTableEntryIdFn) {
            AstNode *struct_node;
            if (fn_ref_expr->type == NodeTypeFieldAccessExpr &&
                fn_ref_expr->data.field_access_expr.is_member_fn)
            {
                struct_node = fn_ref_expr->data.field_access_expr.struct_expr;
            } else {
                struct_node = nullptr;
            }

            FnTableEntry *fn_table_entry = const_val->data.x_fn;
            node->data.fn_call_expr.fn_entry = fn_table_entry;
            return analyze_fn_call_ptr(g, import, context, expected_type, node,
                    fn_table_entry->type_entry, struct_node);
        } else if (invoke_type_entry->id == TypeTableEntryIdGenericFn) {
            TypeTableEntry *generic_fn_type = const_val->data.x_type;
            AstNode *decl_node = generic_fn_type->data.generic_fn.decl_node;
            if (decl_node->type == NodeTypeFnProto) {
                AstNode *struct_node;
                if (fn_ref_expr->type == NodeTypeFieldAccessExpr &&
                    fn_ref_expr->data.field_access_expr.is_member_fn)
                {
                    struct_node = fn_ref_expr->data.field_access_expr.struct_expr;
                } else {
                    struct_node = nullptr;
                }

                FnTableEntry *fn_table_entry = decl_node->data.fn_proto.fn_table_entry;
                if (fn_table_entry->proto_node->data.fn_proto.skip) {
                    return g->builtin_types.entry_invalid;
                }
                return analyze_fn_call_with_inline_args(g, import, context, expected_type, node,
                        fn_table_entry, struct_node);
            } else {
                return analyze_generic_fn_call(g, import, context, expected_type, node, const_val->data.x_type);
            }
        } else {
            add_node_error(g, fn_ref_expr,
                buf_sprintf("type '%s' not a function", buf_ptr(&invoke_type_entry->name)));
            return g->builtin_types.entry_invalid;
        }
    }

    // function pointer
    if (invoke_type_entry->id == TypeTableEntryIdFn) {
        return analyze_fn_call_ptr(g, import, context, expected_type, node, invoke_type_entry, nullptr);
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
    AstNode **expr_node = &node->data.prefix_op_expr.primary_expr;
    switch (prefix_op) {
        case PrefixOpInvalid:
            zig_unreachable();
        case PrefixOpBoolNot:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, g->builtin_types.entry_bool,
                        *expr_node);
                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_bool;
                }

                ConstExprValue *target_const_val = &get_resolved_expr(*expr_node)->const_val;
                if (!target_const_val->ok) {
                    return g->builtin_types.entry_bool;
                }

                bool answer = !target_const_val->data.x_bool;
                return resolve_expr_const_val_as_bool(g, node, answer, target_const_val->depends_on_compile_var);
            }
        case PrefixOpBinNot:
            {
                TypeTableEntry *expr_type = analyze_expression(g, import, context, expected_type,
                        *expr_node);
                if (expr_type->id == TypeTableEntryIdInvalid) {
                    return expr_type;
                } else if (expr_type->id == TypeTableEntryIdInt ||
                           expr_type->id == TypeTableEntryIdNumLitInt)
                {
                    return expr_type;
                } else {
                    add_node_error(g, *expr_node, buf_sprintf("invalid binary not type: '%s'",
                            buf_ptr(&expr_type->name)));
                    return g->builtin_types.entry_invalid;
                }
                // TODO const expr eval
            }
        case PrefixOpNegation:
        case PrefixOpNegationWrap:
            {
                TypeTableEntry *expr_type = analyze_expression(g, import, context, nullptr, *expr_node);
                if (expr_type->id == TypeTableEntryIdInvalid) {
                    return expr_type;
                } else if ((expr_type->id == TypeTableEntryIdInt &&
                            expr_type->data.integral.is_signed) ||
                            expr_type->id == TypeTableEntryIdNumLitInt ||
                            ((expr_type->id == TypeTableEntryIdFloat ||
                            expr_type->id == TypeTableEntryIdNumLitFloat) &&
                            prefix_op != PrefixOpNegationWrap))
                {
                    ConstExprValue *target_const_val = &get_resolved_expr(*expr_node)->const_val;
                    if (!target_const_val->ok) {
                        return expr_type;
                    }
                    ConstExprValue *const_val = &get_resolved_expr(node)->const_val;
                    const_val->ok = true;
                    const_val->depends_on_compile_var = target_const_val->depends_on_compile_var;
                    bignum_negate(&const_val->data.x_bignum, &target_const_val->data.x_bignum);
                    if (expr_type->id == TypeTableEntryIdFloat ||
                        expr_type->id == TypeTableEntryIdNumLitFloat ||
                        expr_type->id == TypeTableEntryIdNumLitInt)
                    {
                        return expr_type;
                    }

                    bool overflow = !bignum_fits_in_bits(&const_val->data.x_bignum,
                            expr_type->data.integral.bit_count, expr_type->data.integral.is_signed);
                    if (prefix_op == PrefixOpNegationWrap) {
                        if (overflow) {
                            const_val->data.x_bignum.is_negative = true;
                        }
                    } else if (overflow) {
                        add_node_error(g, *expr_node, buf_sprintf("negation caused overflow"));
                        return g->builtin_types.entry_invalid;
                    }
                    return expr_type;
                } else {
                    const char *fmt = (prefix_op == PrefixOpNegationWrap) ?
                        "invalid wrapping negation type: '%s'" : "invalid negation type: '%s'";
                    add_node_error(g, node, buf_sprintf(fmt, buf_ptr(&expr_type->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case PrefixOpAddressOf:
        case PrefixOpConstAddressOf:
            {
                bool is_const = (prefix_op == PrefixOpConstAddressOf);

                TypeTableEntry *child_type = analyze_lvalue(g, import, context,
                        *expr_node, LValPurposeAddressOf, is_const);

                if (child_type->id == TypeTableEntryIdInvalid) {
                    return g->builtin_types.entry_invalid;
                } else if (child_type->id == TypeTableEntryIdMetaType) {
                    TypeTableEntry *meta_type = analyze_type_expr_pointer_only(g, import, context,
                            *expr_node, true);
                    if (meta_type->id == TypeTableEntryIdInvalid) {
                        return g->builtin_types.entry_invalid;
                    } else if (meta_type->id == TypeTableEntryIdUnreachable) {
                        add_node_error(g, node, buf_create_from_str("pointer to unreachable not allowed"));
                        return g->builtin_types.entry_invalid;
                    } else {
                        return resolve_expr_const_val_as_type(g, node,
                                get_pointer_to_type(g, meta_type, is_const), false);
                    }
                } else if (child_type->id == TypeTableEntryIdNumLitInt ||
                           child_type->id == TypeTableEntryIdNumLitFloat)
                {
                    add_node_error(g, *expr_node,
                        buf_sprintf("unable to get address of type '%s'", buf_ptr(&child_type->name)));
                    return g->builtin_types.entry_invalid;
                } else {
                    return get_pointer_to_type(g, child_type, is_const);
                }
            }
        case PrefixOpDereference:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, *expr_node);
                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdPointer) {
                    return type_entry->data.pointer.child_type;
                } else {
                    add_node_error(g, *expr_node,
                        buf_sprintf("indirection requires pointer operand ('%s' invalid)",
                            buf_ptr(&type_entry->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case PrefixOpMaybe:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, *expr_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdMetaType) {
                    TypeTableEntry *meta_type = resolve_type(g, *expr_node);
                    if (meta_type->id == TypeTableEntryIdInvalid) {
                        return g->builtin_types.entry_invalid;
                    } else if (meta_type->id == TypeTableEntryIdUnreachable) {
                        add_node_error(g, node, buf_create_from_str("unable to wrap unreachable in maybe type"));
                        return g->builtin_types.entry_invalid;
                    } else {
                        return resolve_expr_const_val_as_type(g, node, get_maybe_type(g, meta_type), false);
                    }
                } else if (type_entry->id == TypeTableEntryIdUnreachable) {
                    add_node_error(g, *expr_node, buf_sprintf("unable to wrap unreachable in maybe type"));
                    return g->builtin_types.entry_invalid;
                } else {
                    ConstExprValue *target_const_val = &get_resolved_expr(*expr_node)->const_val;
                    TypeTableEntry *maybe_type = get_maybe_type(g, type_entry);
                    if (!target_const_val->ok) {
                        return maybe_type;
                    }
                    return resolve_expr_const_val_as_non_null(g, node, maybe_type, target_const_val);
                }
            }
        case PrefixOpError:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, *expr_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdMetaType) {
                    TypeTableEntry *meta_type = resolve_type(g, *expr_node);
                    if (meta_type->id == TypeTableEntryIdInvalid) {
                        return meta_type;
                    } else if (meta_type->id == TypeTableEntryIdUnreachable) {
                        add_node_error(g, node, buf_create_from_str("unable to wrap unreachable in error type"));
                        return g->builtin_types.entry_invalid;
                    } else {
                        return resolve_expr_const_val_as_type(g, node, get_error_type(g, meta_type), false);
                    }
                } else if (type_entry->id == TypeTableEntryIdUnreachable) {
                    add_node_error(g, *expr_node, buf_sprintf("unable to wrap unreachable in error type"));
                    return g->builtin_types.entry_invalid;
                } else {
                    // TODO eval const expr
                    return get_error_type(g, type_entry);
                }

            }
        case PrefixOpUnwrapError:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, *expr_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdErrorUnion) {
                    return type_entry->data.error.child_type;
                } else {
                    add_node_error(g, *expr_node,
                        buf_sprintf("expected error type, got '%s'", buf_ptr(&type_entry->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case PrefixOpUnwrapMaybe:
            {
                TypeTableEntry *type_entry = analyze_expression(g, import, context, nullptr, *expr_node);

                if (type_entry->id == TypeTableEntryIdInvalid) {
                    return type_entry;
                } else if (type_entry->id == TypeTableEntryIdMaybe) {
                    return type_entry->data.maybe.child_type;
                } else {
                    add_node_error(g, *expr_node,
                        buf_sprintf("expected maybe type, got '%s'", buf_ptr(&type_entry->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
    }
    zig_unreachable();
}

static TypeTableEntry *analyze_switch_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    AstNode **expr_node = &node->data.switch_expr.expr;
    TypeTableEntry *expr_type = analyze_expression(g, import, context, nullptr, *expr_node);
    ConstExprValue *expr_val = &get_resolved_expr(*expr_node)->const_val;
    if (expr_val->ok && !expr_val->depends_on_compile_var) {
        add_node_error(g, first_executing_node(*expr_node),
                buf_sprintf("value is constant; unnecessary switch statement"));
    }
    ConstExprValue *const_val = &get_resolved_expr(node)->const_val;


    int prong_count = node->data.switch_expr.prongs.length;
    AstNode **peer_nodes = allocate<AstNode*>(prong_count);
    TypeTableEntry **peer_types = allocate<TypeTableEntry*>(prong_count);

    bool any_errors = false;
    if (expr_type->id == TypeTableEntryIdInvalid) {
        return expr_type;
    } else if (expr_type->id == TypeTableEntryIdUnreachable) {
        add_node_error(g, first_executing_node(*expr_node),
                buf_sprintf("switch on unreachable expression not allowed"));
        return g->builtin_types.entry_invalid;
    }


    int *field_use_counts = nullptr;
    HashMap<int, AstNode *, int_hash, int_eq> err_use_nodes;
    if (expr_type->id == TypeTableEntryIdEnum) {
        field_use_counts = allocate<int>(expr_type->data.enumeration.field_count);
    } else if (expr_type->id == TypeTableEntryIdErrorUnion) {
        err_use_nodes.init(10);
    }

    int *const_chosen_prong_index = &node->data.switch_expr.const_chosen_prong_index;
    *const_chosen_prong_index = -1;
    AstNode *else_prong = nullptr;
    for (int prong_i = 0; prong_i < prong_count; prong_i += 1) {
        AstNode *prong_node = node->data.switch_expr.prongs.at(prong_i);

        TypeTableEntry *var_type;
        bool var_is_target_expr;
        if (prong_node->data.switch_prong.items.length == 0) {
            if (else_prong) {
                add_node_error(g, prong_node, buf_sprintf("multiple else prongs in switch expression"));
                any_errors = true;
            } else {
                else_prong = prong_node;
            }
            var_type = expr_type;
            var_is_target_expr = true;
            if (*const_chosen_prong_index == -1 && expr_val->ok) {
                *const_chosen_prong_index = prong_i;
            }
        } else {
            bool all_agree_on_var_type = true;
            var_type = nullptr;

            for (int item_i = 0; item_i < prong_node->data.switch_prong.items.length; item_i += 1) {
                AstNode *item_node = prong_node->data.switch_prong.items.at(item_i);
                if (item_node->type == NodeTypeSwitchRange) {
                    zig_panic("TODO range in switch statement");
                }

                if (expr_type->id == TypeTableEntryIdEnum) {
                    if (item_node->type == NodeTypeSymbol) {
                        Buf *field_name = item_node->data.symbol_expr.symbol;
                        TypeEnumField *type_enum_field = get_enum_field(expr_type, field_name);
                        if (type_enum_field) {
                            item_node->data.symbol_expr.enum_field = type_enum_field;
                            if (!var_type) {
                                var_type = type_enum_field->type_entry;
                            }
                            if (type_enum_field->type_entry != var_type) {
                                all_agree_on_var_type = false;
                            }
                            uint32_t field_index = type_enum_field->value;
                            assert(field_use_counts);
                            field_use_counts[field_index] += 1;
                            if (field_use_counts[field_index] > 1) {
                                add_node_error(g, item_node,
                                    buf_sprintf("duplicate switch value: '%s'",
                                        buf_ptr(type_enum_field->name)));
                                any_errors = true;
                            }
                            if (!any_errors && expr_val->ok) {
                                if (expr_val->data.x_enum.tag == type_enum_field->value) {
                                    *const_chosen_prong_index = prong_i;
                                }
                            }
                        } else {
                            add_node_error(g, item_node,
                                    buf_sprintf("enum '%s' has no field '%s'",
                                        buf_ptr(&expr_type->name), buf_ptr(field_name)));
                            any_errors = true;
                        }
                    } else {
                        add_node_error(g, item_node, buf_sprintf("expected enum tag name"));
                        any_errors = true;
                    }
                } else if (expr_type->id == TypeTableEntryIdErrorUnion) {
                    if (item_node->type == NodeTypeSymbol) {
                        Buf *err_name = item_node->data.symbol_expr.symbol;
                        bool is_ok_case = buf_eql_str(err_name, "Ok");
                        auto err_table_entry = is_ok_case ? nullptr: g->error_table.maybe_get(err_name);
                        if (is_ok_case || err_table_entry) {
                            uint32_t err_value = is_ok_case ? 0 : err_table_entry->value->value;
                            item_node->data.symbol_expr.err_value = err_value;
                            TypeTableEntry *this_var_type;
                            if (is_ok_case) {
                                this_var_type = expr_type->data.error.child_type;
                            } else {
                                this_var_type = g->builtin_types.entry_pure_error;
                            }
                            if (!var_type) {
                                var_type = this_var_type;
                            }
                            if (this_var_type != var_type) {
                                all_agree_on_var_type = false;
                            }

                            // detect duplicate switch values
                            auto existing_entry = err_use_nodes.maybe_get(err_value);
                            if (existing_entry) {
                                add_node_error(g, existing_entry->value,
                                        buf_sprintf("duplicate switch value: '%s'", buf_ptr(err_name)));
                                any_errors = true;
                            } else {
                                err_use_nodes.put(err_value, item_node);
                            }

                            if (!any_errors && expr_val->ok) {
                                if (expr_val->data.x_err.err->value == err_value) {
                                    *const_chosen_prong_index = prong_i;
                                }
                            }
                        } else {
                            add_node_error(g, item_node,
                                    buf_sprintf("use of undeclared error value '%s'", buf_ptr(err_name)));
                            any_errors = true;
                        }
                    } else {
                        add_node_error(g, item_node, buf_sprintf("expected error value name"));
                        any_errors = true;
                    }
                } else {
                    if (!any_errors && expr_val->ok) {
                        // note: there is now a function in eval.cpp for doing const expr comparison
                        zig_panic("TODO determine if const exprs are equal");
                    }
                    TypeTableEntry *item_type = analyze_expression(g, import, context, expr_type, item_node);
                    if (item_type->id != TypeTableEntryIdInvalid) {
                        ConstExprValue *const_val = &get_resolved_expr(item_node)->const_val;
                        if (!const_val->ok) {
                            add_node_error(g, item_node,
                                buf_sprintf("unable to evaluate constant expression"));
                            any_errors = true;
                        }
                    }
                }
            }
            if (!var_type || !all_agree_on_var_type) {
                var_type = expr_type;
                var_is_target_expr = true;
            } else {
                var_is_target_expr = false;
            }
        }

        BlockContext *child_context = new_block_context(node, context);
        prong_node->data.switch_prong.block_context = child_context;
        AstNode *var_node = prong_node->data.switch_prong.var_symbol;
        if (var_node) {
            assert(var_node->type == NodeTypeSymbol);
            Buf *var_name = var_node->data.symbol_expr.symbol;
            var_node->block_context = child_context;
            prong_node->data.switch_prong.var = add_local_var(g, var_node, import,
                    child_context, var_name, var_type, true, nullptr);
            prong_node->data.switch_prong.var_is_target_expr = var_is_target_expr;
        }
    }

    for (int prong_i = 0; prong_i < prong_count; prong_i += 1) {
        AstNode *prong_node = node->data.switch_expr.prongs.at(prong_i);
        BlockContext *child_context = prong_node->data.switch_prong.block_context;
        child_context->codegen_excluded = expr_val->ok && (*const_chosen_prong_index != prong_i);

        peer_nodes[prong_i] = prong_node->data.switch_prong.expr;
        if (child_context->codegen_excluded) {
            peer_types[prong_i] = g->builtin_types.entry_unreachable;
        } else {
            peer_types[prong_i] = analyze_expression(g, import, child_context, expected_type,
                    prong_node->data.switch_prong.expr);
        }
    }

    if (expr_type->id == TypeTableEntryIdEnum && !else_prong) {
        for (uint32_t i = 0; i < expr_type->data.enumeration.field_count; i += 1) {
            if (field_use_counts[i] == 0) {
                add_node_error(g, node,
                    buf_sprintf("enumeration value '%s' not handled in switch",
                        buf_ptr(expr_type->data.enumeration.fields[i].name)));
                any_errors = true;
            }
        }
    }

    if (any_errors) {
        return g->builtin_types.entry_invalid;
    }

    if (prong_count == 0) {
        add_node_error(g, node, buf_sprintf("switch statement has no prongs"));
        return g->builtin_types.entry_invalid;
    }

    TypeTableEntry *result_type = resolve_peer_type_compatibility(g, import, context, node,
            peer_nodes, peer_types, prong_count);

    if (expr_val->ok) {
        assert(*const_chosen_prong_index != -1);

        *const_val = get_resolved_expr(peer_nodes[*const_chosen_prong_index])->const_val;
        // the target expr depends on a compile var because we have an error on unnecessary
        // switch statement, so the entire switch statement does too
        const_val->depends_on_compile_var = true;

        if (!const_val->ok) {
            return add_error_if_type_is_num_lit(g, result_type, node);
        }
    } else {
        return add_error_if_type_is_num_lit(g, result_type, node);
    }

    return result_type;
}

static TypeTableEntry *analyze_return_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    if (!context->fn_entry) {
        add_node_error(g, node, buf_sprintf("return expression outside function definition"));
        return g->builtin_types.entry_invalid;
    }

    if (!node->data.return_expr.expr) {
        node->data.return_expr.expr = create_ast_void_node(g, import, node);
        normalize_parent_ptrs(node);
    }

    TypeTableEntry *expected_return_type = get_return_type(context);

    switch (node->data.return_expr.kind) {
        case ReturnKindUnconditional:
            {
                analyze_expression(g, import, context, expected_return_type, node->data.return_expr.expr);

                return g->builtin_types.entry_unreachable;
            }
        case ReturnKindError:
            {
                TypeTableEntry *expected_err_type;
                if (expected_type) {
                    expected_err_type = get_error_type(g, expected_type);
                } else {
                    expected_err_type = nullptr;
                }
                TypeTableEntry *resolved_type = analyze_expression(g, import, context, expected_err_type,
                        node->data.return_expr.expr);
                if (resolved_type->id == TypeTableEntryIdInvalid) {
                    return resolved_type;
                } else if (resolved_type->id == TypeTableEntryIdErrorUnion) {
                    TypeTableEntry *return_type = context->fn_entry->type_entry->data.fn.fn_type_id.return_type;
                    if (return_type->id != TypeTableEntryIdErrorUnion &&
                        return_type->id != TypeTableEntryIdPureError)
                    {
                        ErrorMsg *msg = add_node_error(g, node,
                            buf_sprintf("%%return statement in function with return type '%s'",
                                buf_ptr(&return_type->name)));
                        AstNode *return_type_node = context->fn_entry->fn_def_node->data.fn_def.fn_proto->data.fn_proto.return_type;
                        add_error_note(g, msg, return_type_node, buf_sprintf("function return type here"));
                    }

                    return resolved_type->data.error.child_type;
                } else {
                    add_node_error(g, node->data.return_expr.expr,
                        buf_sprintf("expected error type, got '%s'", buf_ptr(&resolved_type->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
        case ReturnKindMaybe:
            {
                TypeTableEntry *expected_maybe_type;
                if (expected_type) {
                    expected_maybe_type = get_maybe_type(g, expected_type);
                } else {
                    expected_maybe_type = nullptr;
                }
                TypeTableEntry *resolved_type = analyze_expression(g, import, context, expected_maybe_type,
                        node->data.return_expr.expr);
                if (resolved_type->id == TypeTableEntryIdInvalid) {
                    return resolved_type;
                } else if (resolved_type->id == TypeTableEntryIdMaybe) {
                    TypeTableEntry *return_type = context->fn_entry->type_entry->data.fn.fn_type_id.return_type;
                    if (return_type->id != TypeTableEntryIdMaybe) {
                        ErrorMsg *msg = add_node_error(g, node,
                            buf_sprintf("?return statement in function with return type '%s'",
                                buf_ptr(&return_type->name)));
                        AstNode *return_type_node = context->fn_entry->fn_def_node->data.fn_def.fn_proto->data.fn_proto.return_type;
                        add_error_note(g, msg, return_type_node, buf_sprintf("function return type here"));
                    }

                    return resolved_type->data.maybe.child_type;
                } else {
                    add_node_error(g, node->data.return_expr.expr,
                        buf_sprintf("expected maybe type, got '%s'", buf_ptr(&resolved_type->name)));
                    return g->builtin_types.entry_invalid;
                }
            }
    }
    zig_unreachable();
}

static void validate_voided_expr(CodeGen *g, AstNode *source_node, TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdMetaType) {
        add_node_error(g, first_executing_node(source_node), buf_sprintf("expected expression, found type"));
    } else if (type_entry->id == TypeTableEntryIdErrorUnion) {
        add_node_error(g, first_executing_node(source_node), buf_sprintf("statement ignores error value"));
    }
}

static TypeTableEntry *analyze_defer(CodeGen *g, ImportTableEntry *import, BlockContext *parent_context,
        TypeTableEntry *expected_type, AstNode *node)
{
    if (!parent_context->fn_entry) {
        add_node_error(g, node, buf_sprintf("defer expression outside function definition"));
        return g->builtin_types.entry_invalid;
    }

    if (!node->data.defer.expr) {
        add_node_error(g, node, buf_sprintf("defer expects an expression"));
        return g->builtin_types.entry_void;
    }

    node->data.defer.child_block = new_block_context(node, parent_context);

    TypeTableEntry *resolved_type = analyze_expression(g, import, parent_context, nullptr,
            node->data.defer.expr);
    validate_voided_expr(g, node->data.defer.expr, resolved_type);

    return g->builtin_types.entry_void;
}

static TypeTableEntry *analyze_string_literal_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    if (node->data.string_literal.c) {
        return resolve_expr_const_val_as_c_string_lit(g, node, node->data.string_literal.buf);
    } else {
        return resolve_expr_const_val_as_string_lit(g, node, node->data.string_literal.buf);
    }
}

static TypeTableEntry *analyze_block_expr(CodeGen *g, ImportTableEntry *import, BlockContext *parent_context,
        TypeTableEntry *expected_type, AstNode *node)
{
    BlockContext *child_context = new_block_context(node, parent_context);
    node->data.block.child_block = child_context;
    TypeTableEntry *return_type = g->builtin_types.entry_void;

    for (int i = 0; i < node->data.block.statements.length; i += 1) {
        AstNode *child = node->data.block.statements.at(i);
        if (child->type == NodeTypeLabel) {
            FnTableEntry *fn_table_entry = child_context->fn_entry;
            assert(fn_table_entry);

            LabelTableEntry *label = allocate<LabelTableEntry>(1);
            label->decl_node = child;
            label->entered_from_fallthrough = (return_type->id != TypeTableEntryIdUnreachable);

            child->block_context = child_context;
            child->data.label.label_entry = label;
            fn_table_entry->all_labels.append(label);

            child_context->label_table.put(child->data.label.name, label);

            return_type = g->builtin_types.entry_void;
            continue;
        }
        if (return_type->id == TypeTableEntryIdUnreachable) {
            if (is_node_void_expr(child)) {
                // {unreachable;void;void} is allowed.
                // ignore void statements once we enter unreachable land.
                analyze_expression(g, import, child_context, g->builtin_types.entry_void, child);
                continue;
            }
            add_node_error(g, first_executing_node(child), buf_sprintf("unreachable code"));
            break;
        }
        bool is_last = (i == node->data.block.statements.length - 1);
        TypeTableEntry *passed_expected_type = is_last ? expected_type : nullptr;
        return_type = analyze_expression(g, import, child_context, passed_expected_type, child);
        if (child->type == NodeTypeDefer && return_type->id != TypeTableEntryIdInvalid) {
            // defer starts a new block context
            child_context = child->data.defer.child_block;
            assert(child_context);
        }
        if (!is_last) {
            validate_voided_expr(g, child, return_type);
        }
    }
    node->data.block.nested_block = child_context;

    ConstExprValue *const_val = &node->data.block.resolved_expr.const_val;
    if (node->data.block.statements.length == 0) {
        const_val->ok = true;
    } else if (node->data.block.statements.length == 1) {
        AstNode *only_node = node->data.block.statements.at(0);
        ConstExprValue *other_const_val = &get_resolved_expr(only_node)->const_val;
        if (other_const_val->ok) {
            *const_val = *other_const_val;
        }
    }

    return return_type;
}

static TypeTableEntry *analyze_asm_expr(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    mark_impure_fn(g, context, node);

    node->data.asm_expr.return_count = 0;
    TypeTableEntry *return_type = g->builtin_types.entry_void;
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
            Buf *variable_name = asm_output->variable_name;
            VariableTableEntry *var = find_variable(g, context, variable_name);
            if (var) {
                asm_output->variable = var;
                return var->type;
            } else {
                add_node_error(g, node,
                        buf_sprintf("use of undeclared identifier '%s'", buf_ptr(variable_name)));
                return g->builtin_types.entry_invalid;
            }
        }
    }
    for (int i = 0; i < node->data.asm_expr.input_list.length; i += 1) {
        AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
        analyze_expression(g, import, context, nullptr, asm_input->expr);
    }

    return return_type;
}

static TypeTableEntry *analyze_goto_pass1(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    assert(node->type == NodeTypeGoto);

    FnTableEntry *fn_table_entry = context->fn_entry;
    assert(fn_table_entry);

    fn_table_entry->goto_list.append(node);

    return g->builtin_types.entry_unreachable;
}

static void analyze_goto_pass2(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeGoto);
    Buf *label_name = node->data.goto_expr.name;
    BlockContext *context = node->block_context;
    assert(context);
    LabelTableEntry *label = find_label(g, context, label_name);

    if (!label) {
        add_node_error(g, node, buf_sprintf("no label in scope named '%s'", buf_ptr(label_name)));
        return;
    }

    label->used = true;
    node->data.goto_expr.label_entry = label;
}

static TypeTableEntry *analyze_expression_pointer_only(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, TypeTableEntry *expected_type, AstNode *node, bool pointer_only)
{
    assert(!expected_type || expected_type->id != TypeTableEntryIdInvalid);
    TypeTableEntry *return_type = nullptr;
    node->block_context = context;
    switch (node->type) {
        case NodeTypeBlock:
            return_type = analyze_block_expr(g, import, context, expected_type, node);
            break;

        case NodeTypeReturnExpr:
            return_type = analyze_return_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeDefer:
            return_type = analyze_defer(g, import, context, expected_type, node);
            break;
        case NodeTypeVariableDeclaration:
            analyze_variable_declaration(g, import, context, expected_type, node);
            return_type = g->builtin_types.entry_void;
            break;
        case NodeTypeGoto:
            return_type = analyze_goto_pass1(g, import, context, expected_type, node);
            break;
        case NodeTypeBreak:
            return_type = analyze_break_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeContinue:
            return_type = analyze_continue_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeAsmExpr:
            return_type = analyze_asm_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeBinOpExpr:
            return_type = analyze_bin_op_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeUnwrapErrorExpr:
            return_type = analyze_unwrap_error_expr(g, import, context, expected_type, node);
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
            return_type = analyze_field_access_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeContainerInitExpr:
            return_type = analyze_container_init_expr(g, import, context, node);
            break;
        case NodeTypeNumberLiteral:
            return_type = analyze_number_literal_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeStringLiteral:
            return_type = analyze_string_literal_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeCharLiteral:
            return_type = resolve_expr_const_val_as_unsigned_num_lit(g, node, expected_type,
                    node->data.char_literal.value, false);
            break;
        case NodeTypeBoolLiteral:
            return_type = resolve_expr_const_val_as_bool(g, node, node->data.bool_literal.value, false);
            break;
        case NodeTypeNullLiteral:
            return_type = analyze_null_literal_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeUndefinedLiteral:
            return_type = analyze_undefined_literal_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeZeroesLiteral:
            return_type = analyze_zeroes_literal_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeSymbol:
            return_type = analyze_symbol_expr(g, import, context, expected_type, node, pointer_only);
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
        case NodeTypeForExpr:
            return_type = analyze_for_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeArrayType:
            return_type = analyze_array_type(g, import, context, expected_type, node);
            break;
        case NodeTypeFnProto:
            return_type = analyze_fn_proto_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeErrorType:
            return_type = resolve_expr_const_val_as_type(g, node, g->builtin_types.entry_pure_error, false);
            break;
        case NodeTypeTypeLiteral:
            return_type = resolve_expr_const_val_as_type(g, node, g->builtin_types.entry_type, false);
            break;
        case NodeTypeSwitchExpr:
            return_type = analyze_switch_expr(g, import, context, expected_type, node);
            break;
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeDirective:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeRoot:
        case NodeTypeFnDef:
        case NodeTypeUse:
        case NodeTypeLabel:
        case NodeTypeContainerDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeErrorValueDecl:
        case NodeTypeTypeDecl:
            zig_unreachable();
    }
    assert(return_type);
    // resolve_type_compatibility might do implicit cast which means node is now a child
    // of the actual node that we want to return the type of.
    //AstNode **field = node->parent_field;
    TypeTableEntry *resolved_type = resolve_type_compatibility(g, import, context, node,
            expected_type, return_type);

    Expr *expr = get_resolved_expr(node);
    expr->type_entry = return_type;

    add_global_const_expr(g, node);

    return resolved_type;
}

// When you call analyze_expression, the node you pass might no longer be the child node
// you thought it was due to implicit casting rewriting the AST.
static TypeTableEntry *analyze_expression(CodeGen *g, ImportTableEntry *import, BlockContext *context,
        TypeTableEntry *expected_type, AstNode *node)
{
    return analyze_expression_pointer_only(g, import, context, expected_type, node, false);
}

static void analyze_fn_body(CodeGen *g, FnTableEntry *fn_table_entry) {
    ImportTableEntry *import = fn_table_entry->import_entry;
    AstNode *node = fn_table_entry->fn_def_node;
    assert(node->type == NodeTypeFnDef);

    AstNode *fn_proto_node = node->data.fn_def.fn_proto;
    assert(fn_proto_node->type == NodeTypeFnProto);

    if (fn_proto_node->data.fn_proto.skip) {
        // we detected an error with this function definition which prevents us
        // from further analyzing it.
        fn_table_entry->anal_state = FnAnalStateSkipped;
        return;
    }
    fn_table_entry->anal_state = FnAnalStateProbing;

    BlockContext *context = node->data.fn_def.block_context;

    TypeTableEntry *fn_type = fn_table_entry->type_entry;
    AstNodeFnProto *fn_proto = &fn_proto_node->data.fn_proto;
    for (int i = 0; i < fn_proto->params.length; i += 1) {
        AstNode *param_decl_node = fn_proto->params.at(i);
        assert(param_decl_node->type == NodeTypeParamDecl);

        // define local variables for parameters
        AstNodeParamDecl *param_decl = &param_decl_node->data.param_decl;
        TypeTableEntry *type = unwrapped_node_type(param_decl->type);

        if (param_decl->is_noalias && !type_is_codegen_pointer(type)) {
            add_node_error(g, param_decl_node, buf_sprintf("noalias on non-pointer parameter"));
        }

        if (fn_type->data.fn.fn_type_id.is_extern && type->id == TypeTableEntryIdStruct) {
            add_node_error(g, param_decl_node,
                buf_sprintf("byvalue struct parameters not yet supported on extern functions"));
        }

        if (buf_len(param_decl->name) == 0) {
            add_node_error(g, param_decl_node, buf_sprintf("missing parameter name"));
        }

        VariableTableEntry *var = add_local_var(g, param_decl_node, import, context, param_decl->name,
                type, true, nullptr);
        var->src_arg_index = i;
        param_decl_node->data.param_decl.variable = var;

        if (fn_type->data.fn.gen_param_info) {
            var->gen_arg_index = fn_type->data.fn.gen_param_info[i].gen_index;
        }

        if (!type->deep_const) {
            fn_table_entry->is_pure = false;
        }
    }

    TypeTableEntry *expected_type = fn_type->data.fn.fn_type_id.return_type;
    TypeTableEntry *block_return_type = analyze_expression(g, import, context, expected_type, node->data.fn_def.body);

    node->data.fn_def.implicit_return_type = block_return_type;

    for (int i = 0; i < fn_table_entry->goto_list.length; i += 1) {
        AstNode *goto_node = fn_table_entry->goto_list.at(i);
        assert(goto_node->type == NodeTypeGoto);
        analyze_goto_pass2(g, import, goto_node);
    }

    for (int i = 0; i < fn_table_entry->all_labels.length; i += 1) {
        LabelTableEntry *label = fn_table_entry->all_labels.at(i);
        if (!label->used) {
            add_node_error(g, label->decl_node,
                    buf_sprintf("label '%s' defined but not used",
                        buf_ptr(label->decl_node->data.label.name)));
        }
    }

    fn_table_entry->anal_state = FnAnalStateComplete;
}

static void add_top_level_decl(CodeGen *g, ImportTableEntry *import, BlockContext *block_context,
        AstNode *node, Buf *name)
{
    assert(import);

    TopLevelDecl *tld = get_as_top_level_decl(node);
    tld->import = import;
    tld->name = name;

    bool want_to_resolve = (g->check_unused || g->is_test_build || tld->visib_mod == VisibModExport);
    bool is_generic_container = (node->type == NodeTypeContainerDecl &&
            node->data.struct_decl.generic_params.length > 0);
    if (want_to_resolve && !is_generic_container) {
        g->resolve_queue.append(node);
    }

    node->block_context = block_context;

    auto entry = block_context->decl_table.maybe_get(name);
    if (entry) {
        AstNode *other_decl_node = entry->value;
        ErrorMsg *msg = add_node_error(g, node, buf_sprintf("redefinition of '%s'", buf_ptr(name)));
        add_error_note(g, msg, other_decl_node, buf_sprintf("previous definition is here"));
    } else {
        block_context->decl_table.put(name, node);
    }
}

static int fn_proto_inline_arg_count(AstNode *proto_node) {
    assert(proto_node->type == NodeTypeFnProto);
    int result = 0;
    for (int i = 0; i < proto_node->data.fn_proto.params.length; i += 1) {
        AstNode *param_node = proto_node->data.fn_proto.params.at(i);
        assert(param_node->type == NodeTypeParamDecl);
        result += param_node->data.param_decl.is_inline ? 1 : 0;
    }
    return result;
}


static void scan_decls(CodeGen *g, ImportTableEntry *import, BlockContext *context, AstNode *node) {
    switch (node->type) {
        case NodeTypeRoot:
            for (int i = 0; i < import->root->data.root.top_level_decls.length; i += 1) {
                AstNode *child = import->root->data.root.top_level_decls.at(i);
                scan_decls(g, import, context, child);
            }
            break;
        case NodeTypeContainerDecl:
            {
                Buf *name = node->data.struct_decl.name;
                add_top_level_decl(g, import, context, node, name);
                if (node->data.struct_decl.generic_params.length == 0) {
                    scan_struct_decl(g, import, context, node);
                }
            }
            break;
        case NodeTypeFnDef:
            node->data.fn_def.fn_proto->data.fn_proto.fn_def_node = node;
            scan_decls(g, import, context, node->data.fn_def.fn_proto);
            break;
        case NodeTypeVariableDeclaration:
            {
                Buf *name = node->data.variable_declaration.symbol;
                add_top_level_decl(g, import, context, node, name);
                break;
            }
        case NodeTypeTypeDecl:
            {
                Buf *name = node->data.type_decl.symbol;
                add_top_level_decl(g, import, context, node, name);
                break;
            }
        case NodeTypeFnProto:
            {
                // if the name is missing, we immediately announce an error
                Buf *fn_name = node->data.fn_proto.name;
                if (buf_len(fn_name) == 0) {
                    node->data.fn_proto.skip = true;
                    add_node_error(g, node, buf_sprintf("missing function name"));
                    break;
                }
                node->data.fn_proto.inline_arg_count = fn_proto_inline_arg_count(node);

                add_top_level_decl(g, import, context, node, fn_name);
                break;
            }
        case NodeTypeUse:
            {
                TopLevelDecl *tld = get_as_top_level_decl(node);
                tld->import = import;
                node->block_context = context;
                g->use_queue.append(node);
                tld->import->use_decls.append(node);
                break;
            }
        case NodeTypeErrorValueDecl:
            // error value declarations do not depend on other top level decls
            preview_error_value_decl(g, node);
            break;
        case NodeTypeDirective:
        case NodeTypeParamDecl:
        case NodeTypeFnDecl:
        case NodeTypeReturnExpr:
        case NodeTypeDefer:
        case NodeTypeBlock:
        case NodeTypeBinOpExpr:
        case NodeTypeUnwrapErrorExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeNumberLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeZeroesLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeForExpr:
        case NodeTypeSwitchExpr:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
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
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
            zig_unreachable();
    }
}

static void add_symbols_from_import(CodeGen *g, AstNode *src_use_node, AstNode *dst_use_node) {
    TopLevelDecl *tld = get_as_top_level_decl(dst_use_node);
    AstNode *use_target_node = src_use_node->data.use.expr;
    Expr *expr = get_resolved_expr(use_target_node);

    if (expr->type_entry->id == TypeTableEntryIdInvalid) {
        return;
    }

    tld->resolution = TldResolutionOk;

    ConstExprValue *const_val = &expr->const_val;
    assert(const_val->ok);

    ImportTableEntry *target_import = const_val->data.x_import;
    assert(target_import);

    if (target_import->any_imports_failed) {
        tld->import->any_imports_failed = true;
    }

    for (int i = 0; i < target_import->root->data.root.top_level_decls.length; i += 1) {
        AstNode *decl_node = target_import->root->data.root.top_level_decls.at(i);
        if (decl_node->type == NodeTypeFnDef) {
            decl_node = decl_node->data.fn_def.fn_proto;
        }
        TopLevelDecl *target_tld = get_as_top_level_decl(decl_node);
        if (!target_tld->name) {
            continue;
        }
        if (target_tld->visib_mod != VisibModPrivate) {
            auto existing_entry = tld->import->block_context->decl_table.maybe_get(target_tld->name);
            if (existing_entry) {
                AstNode *existing_decl = existing_entry->value;
                if (existing_decl != decl_node) {
                    ErrorMsg *msg = add_node_error(g, dst_use_node,
                            buf_sprintf("import of '%s' overrides existing definition",
                                buf_ptr(target_tld->name)));
                    add_error_note(g, msg, existing_decl, buf_sprintf("previous definition here"));
                    add_error_note(g, msg, decl_node, buf_sprintf("imported definition here"));
                }
            } else {
                tld->import->block_context->decl_table.put(target_tld->name, decl_node);
            }
        }
    }

    for (int i = 0; i < target_import->use_decls.length; i += 1) {
        AstNode *use_decl_node = target_import->use_decls.at(i);
        TopLevelDecl *target_tld = get_as_top_level_decl(use_decl_node);
        if (target_tld->visib_mod != VisibModPrivate) {
            add_symbols_from_import(g, use_decl_node, dst_use_node);
        }
    }

}

static void resolve_use_decl(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeUse);
    if (get_as_top_level_decl(node)->resolution != TldResolutionUnresolved) {
        return;
    }
    add_symbols_from_import(g, node, node);
}

static void preview_use_decl(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeUse);
    TopLevelDecl *tld = get_as_top_level_decl(node);
    TypeTableEntry *use_expr_type = analyze_expression(g, tld->import, tld->import->block_context,
            g->builtin_types.entry_namespace, node->data.use.expr);
    if (use_expr_type->id == TypeTableEntryIdInvalid) {
        tld->import->any_imports_failed = true;
    }
}

ImportTableEntry *add_source_file(CodeGen *g, PackageTableEntry *package,
        Buf *abs_full_path, Buf *src_dirname, Buf *src_basename, Buf *source_code)
{
    Buf *full_path = buf_alloc();
    os_path_join(src_dirname, src_basename, full_path);

    if (g->verbose) {
        fprintf(stderr, "\nOriginal Source (%s):\n", buf_ptr(full_path));
        fprintf(stderr, "----------------\n");
        fprintf(stderr, "%s\n", buf_ptr(source_code));

        fprintf(stderr, "\nTokens:\n");
        fprintf(stderr, "---------\n");
    }

    Tokenization tokenization = {0};
    tokenize(source_code, &tokenization);

    if (tokenization.err) {
        ErrorMsg *err = err_msg_create_with_line(full_path, tokenization.err_line, tokenization.err_column,
                source_code, tokenization.line_offsets, tokenization.err);

        print_err_msg(err, g->err_color);
        exit(1);
    }

    if (g->verbose) {
        print_tokens(source_code, tokenization.tokens);

        fprintf(stderr, "\nAST:\n");
        fprintf(stderr, "------\n");
    }

    ImportTableEntry *import_entry = allocate<ImportTableEntry>(1);
    import_entry->package = package;
    import_entry->source_code = source_code;
    import_entry->line_offsets = tokenization.line_offsets;
    import_entry->path = full_path;

    import_entry->root = ast_parse(source_code, tokenization.tokens, import_entry, g->err_color,
            &g->next_node_index);
    assert(import_entry->root);
    if (g->verbose) {
        ast_print(stderr, import_entry->root, 0);
        //fprintf(stderr, "\nReformatted Source:\n");
        //fprintf(stderr, "---------------------\n");
        //ast_render(stderr, import_entry->root, 4);
    }

    import_entry->di_file = LLVMZigCreateFile(g->dbuilder, buf_ptr(src_basename), buf_ptr(src_dirname));
    g->import_table.put(abs_full_path, import_entry);
    g->import_queue.append(import_entry);

    import_entry->block_context = new_block_context(import_entry->root, nullptr);
    import_entry->block_context->di_scope = LLVMZigFileToScope(import_entry->di_file);


    assert(import_entry->root->type == NodeTypeRoot);
    for (int decl_i = 0; decl_i < import_entry->root->data.root.top_level_decls.length; decl_i += 1) {
        AstNode *top_level_decl = import_entry->root->data.root.top_level_decls.at(decl_i);

        if (top_level_decl->type == NodeTypeFnDef) {
            AstNode *proto_node = top_level_decl->data.fn_def.fn_proto;
            assert(proto_node->type == NodeTypeFnProto);
            Buf *proto_name = proto_node->data.fn_proto.name;

            bool is_private = (proto_node->data.fn_proto.top_level_decl.visib_mod == VisibModPrivate);

            if (buf_eql_str(proto_name, "main") && !is_private) {
                g->have_exported_main = true;
            }
        }
    }

    return import_entry;
}


void semantic_analyze(CodeGen *g) {
    for (; g->import_queue_index < g->import_queue.length; g->import_queue_index += 1) {
        ImportTableEntry *import = g->import_queue.at(g->import_queue_index);
        scan_decls(g, import, import->block_context, import->root);
    }

    for (; g->use_queue_index < g->use_queue.length; g->use_queue_index += 1) {
        AstNode *use_decl_node = g->use_queue.at(g->use_queue_index);
        preview_use_decl(g, use_decl_node);
    }

    for (int i = 0; i < g->use_queue.length; i += 1) {
        AstNode *use_decl_node = g->use_queue.at(i);
        resolve_use_decl(g, use_decl_node);
    }

    for (; g->resolve_queue_index < g->resolve_queue.length; g->resolve_queue_index += 1) {
        AstNode *decl_node = g->resolve_queue.at(g->resolve_queue_index);
        bool pointer_only = false;
        resolve_top_level_decl(g, decl_node, pointer_only);
    }

    for (int i = 0; i < g->fn_defs.length; i += 1) {
        FnTableEntry *fn_entry = g->fn_defs.at(i);
        if (fn_entry->anal_state == FnAnalStateReady) {
            analyze_fn_body(g, fn_entry);
        }
    }
}

Expr *get_resolved_expr(AstNode *node) {
    switch (node->type) {
        case NodeTypeReturnExpr:
            return &node->data.return_expr.resolved_expr;
        case NodeTypeDefer:
            return &node->data.defer.resolved_expr;
        case NodeTypeBinOpExpr:
            return &node->data.bin_op_expr.resolved_expr;
        case NodeTypeUnwrapErrorExpr:
            return &node->data.unwrap_err_expr.resolved_expr;
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
        case NodeTypeForExpr:
            return &node->data.for_expr.resolved_expr;
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
        case NodeTypeUndefinedLiteral:
            return &node->data.undefined_literal.resolved_expr;
        case NodeTypeZeroesLiteral:
            return &node->data.zeroes_literal.resolved_expr;
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
        case NodeTypeErrorType:
            return &node->data.error_type.resolved_expr;
        case NodeTypeTypeLiteral:
            return &node->data.type_literal.resolved_expr;
        case NodeTypeSwitchExpr:
            return &node->data.switch_expr.resolved_expr;
        case NodeTypeFnProto:
            return &node->data.fn_proto.resolved_expr;
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeRoot:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeDirective:
        case NodeTypeUse:
        case NodeTypeContainerDecl:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeErrorValueDecl:
        case NodeTypeTypeDecl:
            zig_unreachable();
    }
    zig_unreachable();
}

static TopLevelDecl *get_as_top_level_decl(AstNode *node) {
    switch (node->type) {
        case NodeTypeVariableDeclaration:
            return &node->data.variable_declaration.top_level_decl;
        case NodeTypeFnProto:
            return &node->data.fn_proto.top_level_decl;
        case NodeTypeFnDef:
            return &node->data.fn_def.fn_proto->data.fn_proto.top_level_decl;
        case NodeTypeContainerDecl:
            return &node->data.struct_decl.top_level_decl;
        case NodeTypeErrorValueDecl:
            return &node->data.error_value_decl.top_level_decl;
        case NodeTypeUse:
            return &node->data.use.top_level_decl;
        case NodeTypeTypeDecl:
            return &node->data.type_decl.top_level_decl;
        case NodeTypeNumberLiteral:
        case NodeTypeReturnExpr:
        case NodeTypeDefer:
        case NodeTypeBinOpExpr:
        case NodeTypeUnwrapErrorExpr:
        case NodeTypePrefixOpExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypeIfBoolExpr:
        case NodeTypeIfVarExpr:
        case NodeTypeWhileExpr:
        case NodeTypeForExpr:
        case NodeTypeSwitchExpr:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeAsmExpr:
        case NodeTypeContainerInitExpr:
        case NodeTypeRoot:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
        case NodeTypeBlock:
        case NodeTypeDirective:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeSymbol:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeZeroesLiteral:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeArrayType:
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
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
            buf_eql_str(type_node->data.symbol_expr.symbol, "void"))
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

TypeTableEntry **get_c_int_type_ptr(CodeGen *g, CIntType c_int_type) {
    return &g->builtin_types.entry_c_int[c_int_type];
}

TypeTableEntry *get_c_int_type(CodeGen *g, CIntType c_int_type) {
    return *get_c_int_type_ptr(g, c_int_type);
}

bool handle_is_ptr(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdGenericFn:
             zig_unreachable();
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
             return false;
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdUnion:
             return true;
        case TypeTableEntryIdErrorUnion:
             return type_has_bits(type_entry->data.error.child_type);
        case TypeTableEntryIdEnum:
             return type_entry->data.enumeration.gen_field_count != 0;
        case TypeTableEntryIdMaybe:
             return type_entry->data.maybe.child_type->id != TypeTableEntryIdPointer &&
                    type_entry->data.maybe.child_type->id != TypeTableEntryIdFn;
        case TypeTableEntryIdTypeDecl:
             return handle_is_ptr(type_entry->data.type_decl.canonical_type);
    }
    zig_unreachable();
}

void find_libc_include_path(CodeGen *g) {
    if (!g->libc_include_dir || buf_len(g->libc_include_dir) == 0) {
        zig_panic("Unable to determine libc include path.");
    }
}

void find_libc_lib_path(CodeGen *g) {
    // later we can handle this better by reporting an error via the normal mechanism
    if (!g->libc_lib_dir || buf_len(g->libc_lib_dir) == 0) {
        zig_panic("Unable to determine libc lib path.");
    }
    if (!g->libc_static_lib_dir || buf_len(g->libc_static_lib_dir) == 0) {
        zig_panic("Unable to determine libc static lib path.");
    }
}

static uint32_t hash_ptr(void *ptr) {
    uint64_t x = (uint64_t)(uintptr_t)(ptr);
    uint32_t a = x >> 32;
    uint32_t b = x & 0xffffffff;
    return a ^ b;
}

uint32_t fn_type_id_hash(FnTypeId *id) {
    uint32_t result = 0;
    result += id->is_extern ? 3349388391 : 0;
    result += id->is_naked ? 608688877 : 0;
    result += id->is_cold ? 3605523458 : 0;
    result += id->is_var_args ? 1931444534 : 0;
    result += hash_ptr(id->return_type);
    for (int i = 0; i < id->param_count; i += 1) {
        FnTypeParamInfo *info = &id->param_info[i];
        result += info->is_noalias ? 892356923 : 0;
        result += hash_ptr(info->type);
    }
    return result;
}

bool fn_type_id_eql(FnTypeId *a, FnTypeId *b) {
    if (a->is_extern != b->is_extern ||
        a->is_naked != b->is_naked ||
        a->is_cold != b->is_cold ||
        a->return_type != b->return_type ||
        a->is_var_args != b->is_var_args ||
        a->param_count != b->param_count)
    {
        return false;
    }
    for (int i = 0; i < a->param_count; i += 1) {
        FnTypeParamInfo *a_param_info = &a->param_info[i];
        FnTypeParamInfo *b_param_info = &b->param_info[i];

        if (a_param_info->type != b_param_info->type ||
            a_param_info->is_noalias != b_param_info->is_noalias)
        {
            return false;
        }
    }
    return true;
}

static uint32_t hash_const_val(TypeTableEntry *type, ConstExprValue *const_val) {
    switch (type->id) {
        case TypeTableEntryIdBool:
            return const_val->data.x_bool ? 127863866 : 215080464;
        case TypeTableEntryIdMetaType:
            return hash_ptr(const_val->data.x_type);
        case TypeTableEntryIdVoid:
            return 4149439618;
        case TypeTableEntryIdInt:
        case TypeTableEntryIdNumLitInt:
            return ((uint32_t)(bignum_to_twos_complement(&const_val->data.x_bignum) % UINT32_MAX)) * 1331471175;
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdNumLitFloat:
            return const_val->data.x_bignum.data.x_float * UINT32_MAX;
        case TypeTableEntryIdPointer:
            return hash_ptr(const_val->data.x_ptr.ptr);
        case TypeTableEntryIdUndefLit:
            return 162837799;
        case TypeTableEntryIdArray:
            // TODO better hashing algorithm
            return 1166190605;
        case TypeTableEntryIdStruct:
            // TODO better hashing algorithm
            return 1532530855;
        case TypeTableEntryIdUnion:
            // TODO better hashing algorithm
            return 2709806591;
        case TypeTableEntryIdMaybe:
            if (const_val->data.x_maybe) {
                TypeTableEntry *child_type = type->data.maybe.child_type;
                return hash_const_val(child_type, const_val->data.x_maybe) * 1992916303;
            } else {
                return 4016830364;
            }
        case TypeTableEntryIdErrorUnion:
            // TODO better hashing algorithm
            return 3415065496;
        case TypeTableEntryIdPureError:
            // TODO better hashing algorithm
            return 2630160122;
        case TypeTableEntryIdEnum:
            // TODO better hashing algorithm
            return 31643936;
        case TypeTableEntryIdFn:
            return hash_ptr(const_val->data.x_fn);
        case TypeTableEntryIdTypeDecl:
            return hash_ptr(const_val->data.x_type);
        case TypeTableEntryIdNamespace:
            return hash_ptr(const_val->data.x_import);
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdUnreachable:
            zig_unreachable();
    }
    zig_unreachable();
}

uint32_t generic_fn_type_id_hash(GenericFnTypeId *id) {
    uint32_t result = 0;
    result += hash_ptr(id->decl_node);
    for (int i = 0; i < id->generic_param_count; i += 1) {
        GenericParamValue *generic_param = &id->generic_params[i];
        ConstExprValue *const_val = &get_resolved_expr(generic_param->node)->const_val;
        assert(const_val->ok);
        result += hash_const_val(generic_param->type, const_val);
    }
    return result;
}

bool generic_fn_type_id_eql(GenericFnTypeId *a, GenericFnTypeId *b) {
    if (a->decl_node != b->decl_node) return false;
    assert(a->generic_param_count == b->generic_param_count);
    for (int i = 0; i < a->generic_param_count; i += 1) {
        GenericParamValue *a_val = &a->generic_params[i];
        GenericParamValue *b_val = &b->generic_params[i];
        assert(a_val->type == b_val->type);
        ConstExprValue *a_const_val = &get_resolved_expr(a_val->node)->const_val;
        ConstExprValue *b_const_val = &get_resolved_expr(b_val->node)->const_val;
        assert(a_const_val->ok);
        assert(b_const_val->ok);
        if (!const_values_equal(a_const_val, b_const_val, a_val->type)) {
            return false;
        }
    }
    return true;
}

bool type_has_bits(TypeTableEntry *type_entry) {
    assert(type_entry);
    assert(type_entry->id != TypeTableEntryIdInvalid);
    return !type_entry->zero_bits;
}

static TypeTableEntry *first_struct_field_type(TypeTableEntry *type_entry) {
    assert(type_entry->id == TypeTableEntryIdStruct);
    for (uint32_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
        TypeStructField *tsf = &type_entry->data.structure.fields[i];
        if (tsf->gen_index == 0) {
            return tsf->type_entry;
        }
    }
    zig_unreachable();
}

static TypeTableEntry *type_of_first_thing_in_memory(TypeTableEntry *type_entry) {
    assert(type_has_bits(type_entry));
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdGenericFn:
            zig_unreachable();
        case TypeTableEntryIdArray:
            return type_of_first_thing_in_memory(type_entry->data.array.child_type);
        case TypeTableEntryIdStruct:
            return type_of_first_thing_in_memory(first_struct_field_type(type_entry));
        case TypeTableEntryIdUnion:
            zig_panic("TODO");
        case TypeTableEntryIdMaybe:
            return type_of_first_thing_in_memory(type_entry->data.maybe.child_type);
        case TypeTableEntryIdErrorUnion:
            return type_of_first_thing_in_memory(type_entry->data.error.child_type);
        case TypeTableEntryIdTypeDecl:
            return type_of_first_thing_in_memory(type_entry->data.type_decl.canonical_type);
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.tag_type;
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
            return type_entry;
    }
    zig_unreachable();
}

uint64_t get_memcpy_align(CodeGen *g, TypeTableEntry *type_entry) {
    TypeTableEntry *first_type_in_mem = type_of_first_thing_in_memory(type_entry);
    return LLVMABISizeOfType(g->target_data_ref, first_type_in_mem->type_ref);
}

