/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "analyze.hpp"
#include "ast_render.hpp"
#include "config.h"
#include "error.hpp"
#include "eval.hpp"
#include "ir.hpp"
#include "ir_print.hpp"
#include "os.hpp"
#include "parseh.hpp"
#include "parser.hpp"
#include "zig_llvm.hpp"

static void resolve_enum_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *enum_type);
static void resolve_struct_type(CodeGen *g, ImportTableEntry *import, TypeTableEntry *struct_type);
static void scan_decls(CodeGen *g, ImportTableEntry *import, BlockContext *context, AstNode *node);

AstNode *first_executing_node(AstNode *node) {
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
        case NodeTypeThisLiteral:
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
        case NodeTypeVarLiteral:
            return node;
    }
    zig_unreachable();
}

void mark_impure_fn(CodeGen *g, BlockContext *context, AstNode *node) {
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

BlockContext *get_container_block_context(TypeTableEntry *type_entry) {
    return *get_container_block_context_ptr(type_entry);
}

static TypeTableEntry *new_container_type_entry(TypeTableEntryId id, AstNode *source_node,
        BlockContext *parent_context)
{
    TypeTableEntry *entry = new_type_table_entry(id);
    *get_container_block_context_ptr(entry) = new_block_context(source_node, parent_context);
    return entry;
}


static size_t bits_needed_for_unsigned(uint64_t x) {
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

bool type_is_complete(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdVar:
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
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
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
            entry->di_type = ZigLLVMCreateDebugPointerType(g->dbuilder, child_type->di_type,
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


            ZigLLVMDIScope *compile_unit_scope = ZigLLVMCompileUnitToScope(g->compile_unit);
            ZigLLVMDIFile *di_file = nullptr;
            unsigned line = 0;
            entry->di_type = ZigLLVMCreateReplaceableCompositeType(g->dbuilder,
                ZigLLVMTag_DW_structure_type(), buf_ptr(&entry->name),
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

            ZigLLVMDIType *di_element_types[] = {
                ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                        "val", di_file, line,
                        val_debug_size_in_bits,
                        val_debug_align_in_bits,
                        val_offset_in_bits,
                        0, child_type->di_type),
                ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                        "maybe", di_file, line,
                        maybe_debug_size_in_bits,
                        maybe_debug_align_in_bits,
                        maybe_offset_in_bits,
                        0, child_type->di_type),
            };
            ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
                    compile_unit_scope,
                    buf_ptr(&entry->name),
                    di_file, line, debug_size_in_bits, debug_align_in_bits, 0,
                    nullptr, di_element_types, 2, 0, nullptr, "");

            ZigLLVMReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
            entry->di_type = replacement_di_type;
        }

        entry->data.maybe.child_type = child_type;

        child_type->maybe_parent = entry;
        return entry;
    }
}

TypeTableEntry *get_error_type(CodeGen *g, TypeTableEntry *child_type) {
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

            ZigLLVMDIScope *compile_unit_scope = ZigLLVMCompileUnitToScope(g->compile_unit);
            ZigLLVMDIFile *di_file = nullptr;
            unsigned line = 0;
            entry->di_type = ZigLLVMCreateReplaceableCompositeType(g->dbuilder,
                ZigLLVMTag_DW_structure_type(), buf_ptr(&entry->name),
                compile_unit_scope, di_file, line);

            uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, g->err_tag_type->type_ref);
            uint64_t tag_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, g->err_tag_type->type_ref);
            uint64_t tag_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 0);

            uint64_t value_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, child_type->type_ref);
            uint64_t value_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, child_type->type_ref);
            uint64_t value_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 1);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

            ZigLLVMDIType *di_element_types[] = {
                ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                        "tag", di_file, line,
                        tag_debug_size_in_bits,
                        tag_debug_align_in_bits,
                        tag_offset_in_bits,
                        0, child_type->di_type),
                ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                        "value", di_file, line,
                        value_debug_size_in_bits,
                        value_debug_align_in_bits,
                        value_offset_in_bits,
                        0, child_type->di_type),
            };

            ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
                    compile_unit_scope,
                    buf_ptr(&entry->name),
                    di_file, line,
                    debug_size_in_bits,
                    debug_align_in_bits,
                    0,
                    nullptr, di_element_types, 2, 0, nullptr, "");

            ZigLLVMReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
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
        entry->type_ref = child_type->type_ref ? LLVMArrayType(child_type->type_ref, array_size) : nullptr;
        entry->zero_bits = (array_size == 0) || child_type->zero_bits;
        entry->deep_const = child_type->deep_const;

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[%" PRIu64 "]%s", array_size, buf_ptr(&child_type->name));

        if (!entry->zero_bits) {
            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

            entry->di_type = ZigLLVMCreateDebugArrayType(g->dbuilder, debug_size_in_bits,
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

        // If the child type is []const T then we need to make sure the type ref
        // and debug info is the same as if the child type were []T.
        if (is_slice(child_type)) {
            TypeTableEntry *ptr_type = child_type->data.structure.fields[0].type_entry;
            assert(ptr_type->id == TypeTableEntryIdPointer);
            if (ptr_type->data.pointer.is_const) {
                TypeTableEntry *non_const_child_type = get_slice_type(g,
                    ptr_type->data.pointer.child_type, false);
                TypeTableEntry *var_peer = get_slice_type(g, non_const_child_type, false);

                entry->type_ref = var_peer->type_ref;
                entry->di_type = var_peer->di_type;
            }
        }

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "[]%s", buf_ptr(&child_type->name));

        slice_type_common_init(g, child_type, is_const, entry);
        if (child_type->zero_bits) {
            entry->data.structure.gen_field_count = 1;
            entry->data.structure.fields[0].gen_index = SIZE_MAX;
            entry->data.structure.fields[1].gen_index = 0;
        }

        if (!entry->type_ref) {
            entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), buf_ptr(&entry->name));

            ZigLLVMDIScope *compile_unit_scope = ZigLLVMCompileUnitToScope(g->compile_unit);
            ZigLLVMDIFile *di_file = nullptr;
            unsigned line = 0;
            entry->di_type = ZigLLVMCreateReplaceableCompositeType(g->dbuilder,
                ZigLLVMTag_DW_structure_type(), buf_ptr(&entry->name),
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

                ZigLLVMDIType *di_element_types[] = {
                    ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                            "len", di_file, line,
                            len_debug_size_in_bits,
                            len_debug_align_in_bits,
                            len_offset_in_bits,
                            0, usize_type->di_type),
                };
                ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
                        compile_unit_scope,
                        buf_ptr(&entry->name),
                        di_file, line, debug_size_in_bits, debug_align_in_bits, 0,
                        nullptr, di_element_types, 1, 0, nullptr, "");

                ZigLLVMReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
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

                ZigLLVMDIType *di_element_types[] = {
                    ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                            "ptr", di_file, line,
                            ptr_debug_size_in_bits,
                            ptr_debug_align_in_bits,
                            ptr_offset_in_bits,
                            0, pointer_type->di_type),
                    ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                            "len", di_file, line,
                            len_debug_size_in_bits,
                            len_debug_align_in_bits,
                            len_offset_in_bits,
                            0, usize_type->di_type),
                };
                ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
                        compile_unit_scope,
                        buf_ptr(&entry->name),
                        di_file, line, debug_size_in_bits, debug_align_in_bits, 0,
                        nullptr, di_element_types, 2, 0, nullptr, "");

                ZigLLVMReplaceTemporary(g->dbuilder, entry->di_type, replacement_di_type);
                entry->di_type = replacement_di_type;
            }
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
    for (size_t i = 0; i < fn_type_id->param_count; i += 1) {
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
        ZigLLVMDIType **param_di_types = allocate<ZigLLVMDIType*>(2 + fn_type_id->param_count);
        param_di_types[0] = fn_type_id->return_type->di_type;
        size_t gen_param_index = 0;
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
        for (size_t i = 0; i < fn_type_id->param_count; i += 1) {
            FnTypeParamInfo *src_param_info = &fn_type->data.fn.fn_type_id.param_info[i];
            TypeTableEntry *type_entry = src_param_info->type;
            FnGenParamInfo *gen_param_info = &fn_type->data.fn.gen_param_info[i];

            gen_param_info->src_index = i;
            gen_param_info->gen_index = SIZE_MAX;

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
        fn_type->di_type = ZigLLVMCreateSubroutineType(g->dbuilder, param_di_types, gen_param_index + 1, 0);
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
    entry->di_type = ZigLLVMCreateReplaceableCompositeType(g->dbuilder,
        ZigLLVMTag_DW_structure_type(), name,
        ZigLLVMFileToScope(import->di_file), import->di_file, line + 1);

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

static IrInstruction *analyze_const_value(CodeGen *g, BlockContext *scope, AstNode *node,
        TypeTableEntry *expected_type)
{
    IrExecutable ir_executable = {0};
    IrExecutable analyzed_executable = {0};
    IrInstruction *pass1 = ir_gen(g, node, scope, &ir_executable);

    if (pass1->type_entry->id == TypeTableEntryIdInvalid)
        return g->invalid_instruction;

    if (g->verbose) {
        fprintf(stderr, "\nSource: ");
        ast_render(stderr, node, 4);
        fprintf(stderr, "\n{ // (IR)\n");
        ir_print(stderr, &ir_executable, 4);
        fprintf(stderr, "}\n");
    }
    TypeTableEntry *result_type = ir_analyze(g, &ir_executable, &analyzed_executable, expected_type, node);
    if (result_type->id == TypeTableEntryIdInvalid)
        return g->invalid_instruction;

    if (g->verbose) {
        fprintf(stderr, "{ // (analyzed)\n");
        ir_print(stderr, &analyzed_executable, 4);
        fprintf(stderr, "}\n");
    }

    IrInstruction *result = ir_exec_const_result(&analyzed_executable);
    if (!result) {
        add_node_error(g, node, buf_sprintf("unable to evaluate constant expression"));
        return g->invalid_instruction;
    }

    return result;
}

static TypeTableEntry *analyze_type_expr_pointer_only(CodeGen *g, ImportTableEntry *import,
        BlockContext *context, AstNode *node, bool pointer_only)
{
    if (pointer_only)
        zig_panic("TODO");

    IrInstruction *result = analyze_const_value(g, context, node, g->builtin_types.entry_type);
    if (result->type_entry->id == TypeTableEntryIdInvalid)
        return g->builtin_types.entry_invalid;

    assert(result->static_value.special != ConstValSpecialRuntime);
    return result->static_value.data.x_type;
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

    for (size_t i = 0; i < fn_type_id.param_count; i += 1) {
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
            case TypeTableEntryIdNullLit:
            case TypeTableEntryIdUnreachable:
            case TypeTableEntryIdNamespace:
            case TypeTableEntryIdBlock:
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
            case TypeTableEntryIdVar:
                // var types are treated as generic functions; if we get to this code we should
                // already be an instantiated function.
                zig_unreachable();
        }
        if (type_entry->id == TypeTableEntryIdInvalid) {
            fn_proto->skip = true;
        }
        FnTypeParamInfo *param_info = &fn_type_id.param_info[i];
        param_info->type = type_entry;
        param_info->is_noalias = child->data.param_decl.is_noalias;
    }

    switch (fn_type_id.return_type->id) {
        case TypeTableEntryIdInvalid:
            fn_proto->skip = true;
            break;
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdVar:
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


    if (fn_proto->skip) {
        return g->builtin_types.entry_invalid;
    }

    if (fn_table_entry && fn_type_id.return_type->id == TypeTableEntryIdMetaType) {
        fn_table_entry->want_pure = WantPureTrue;
        fn_table_entry->want_pure_return_type = fn_proto->return_type;

        ErrorMsg *err_msg = nullptr;
        for (size_t i = 0; i < fn_proto->params.length; i += 1) {
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

static void resolve_function_proto(CodeGen *g, AstNode *node, FnTableEntry *fn_table_entry,
        ImportTableEntry *import, BlockContext *containing_context)
{
    assert(node->type == NodeTypeFnProto);
    AstNodeFnProto *fn_proto = &node->data.fn_proto;

    if (fn_proto->skip) {
        return;
    }

    bool is_internal = (fn_proto->top_level_decl.visib_mod != VisibModExport);
    bool is_c_compat = !is_internal || fn_proto->is_extern;
    fn_table_entry->internal_linkage = !is_c_compat;



    TypeTableEntry *fn_type = analyze_fn_proto_type(g, import, containing_context, nullptr, node,
            fn_proto->is_nakedcc, fn_proto->is_coldcc, fn_table_entry);

    fn_table_entry->type_entry = fn_type;

    if (fn_type->id == TypeTableEntryIdInvalid) {
        fn_proto->skip = true;
        return;
    }

    if (fn_proto->is_inline) {
        fn_table_entry->fn_inline = FnInlineAlways;
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
        if (!g->is_release_build && fn_table_entry->fn_inline != FnInlineAlways) {
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
            ZigLLVMDISubprogram *subprogram = ZigLLVMCreateFunction(g->dbuilder,
                containing_context->di_scope, buf_ptr(&fn_table_entry->symbol_name), "",
                import->di_file, line_number,
                fn_type->di_type, fn_table_entry->internal_linkage,
                is_definition, scope_line, flags, is_optimized, nullptr);

            fn_table_entry->fn_def_node->data.fn_def.block_context->di_scope = ZigLLVMSubprogramToScope(subprogram);
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

    enum_type->data.enumeration.src_field_count = field_count;
    enum_type->data.enumeration.fields = allocate<TypeEnumField>(field_count);
    ZigLLVMDIEnumerator **di_enumerators = allocate<ZigLLVMDIEnumerator*>(field_count);

    // we possibly allocate too much here since gen_field_count can be lower than field_count.
    // the only problem is potential wasted space though.
    ZigLLVMDIType **union_inner_di_types = allocate<ZigLLVMDIType*>(field_count);

    TypeTableEntry *biggest_union_member = nullptr;
    uint64_t biggest_align_in_bits = 0;
    uint64_t biggest_union_member_size_in_bits = 0;

    BlockContext *context = enum_type->data.enumeration.block_context;

    // set temporary flag
    enum_type->data.enumeration.embedded_in_current = true;

    size_t gen_field_index = 0;
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


        di_enumerators[i] = ZigLLVMCreateDebugEnumerator(g->dbuilder, buf_ptr(type_enum_field->name), i);

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

        union_inner_di_types[gen_field_index] = ZigLLVMCreateDebugMemberType(g->dbuilder,
                ZigLLVMTypeToScope(enum_type->di_type), buf_ptr(type_enum_field->name),
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
            ZigLLVMDIType *tag_di_type = ZigLLVMCreateDebugEnumerationType(g->dbuilder,
                    ZigLLVMTypeToScope(enum_type->di_type), "AnonEnum", import->di_file, decl_node->line + 1,
                    tag_debug_size_in_bits, tag_debug_align_in_bits, di_enumerators, field_count,
                    tag_type_entry->di_type, "");

            // create debug type for union
            ZigLLVMDIType *union_di_type = ZigLLVMCreateDebugUnionType(g->dbuilder,
                    ZigLLVMTypeToScope(enum_type->di_type), "AnonUnion", import->di_file, decl_node->line + 1,
                    biggest_union_member_size_in_bits, biggest_align_in_bits, 0, union_inner_di_types,
                    gen_field_index, 0, "");

            // create debug types for members of root struct
            uint64_t tag_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, enum_type->type_ref, 0);
            ZigLLVMDIType *tag_member_di_type = ZigLLVMCreateDebugMemberType(g->dbuilder,
                    ZigLLVMTypeToScope(enum_type->di_type), "tag_field",
                    import->di_file, decl_node->line + 1,
                    tag_debug_size_in_bits,
                    tag_debug_align_in_bits,
                    tag_offset_in_bits,
                    0, tag_di_type);

            uint64_t union_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, enum_type->type_ref, 1);
            ZigLLVMDIType *union_member_di_type = ZigLLVMCreateDebugMemberType(g->dbuilder,
                    ZigLLVMTypeToScope(enum_type->di_type), "union_field",
                    import->di_file, decl_node->line + 1,
                    biggest_union_member_size_in_bits,
                    biggest_align_in_bits,
                    union_offset_in_bits,
                    0, union_di_type);

            // create debug type for root struct
            ZigLLVMDIType *di_root_members[] = {
                tag_member_di_type,
                union_member_di_type,
            };


            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, enum_type->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, enum_type->type_ref);
            ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
                    ZigLLVMFileToScope(import->di_file),
                    buf_ptr(decl_node->data.struct_decl.name),
                    import->di_file, decl_node->line + 1,
                    debug_size_in_bits,
                    debug_align_in_bits,
                    0, nullptr, di_root_members, 2, 0, nullptr, "");

            ZigLLVMReplaceTemporary(g->dbuilder, enum_type->di_type, replacement_di_type);
            enum_type->di_type = replacement_di_type;
        } else {
            // create llvm type for root struct
            enum_type->type_ref = tag_type_entry->type_ref;

            // create debug type for tag
            uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, tag_type_entry->type_ref);
            uint64_t tag_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, tag_type_entry->type_ref);
            ZigLLVMDIType *tag_di_type = ZigLLVMCreateDebugEnumerationType(g->dbuilder,
                    ZigLLVMFileToScope(import->di_file), buf_ptr(decl_node->data.struct_decl.name),
                    import->di_file, decl_node->line + 1,
                    tag_debug_size_in_bits,
                    tag_debug_align_in_bits,
                    di_enumerators, field_count,
                    tag_type_entry->di_type, "");

            ZigLLVMReplaceTemporary(g->dbuilder, enum_type->di_type, tag_di_type);
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

    size_t field_count = decl_node->data.struct_decl.fields.length;

    struct_type->data.structure.src_field_count = field_count;
    struct_type->data.structure.fields = allocate<TypeStructField>(field_count);

    // we possibly allocate too much here since gen_field_count can be lower than field_count.
    // the only problem is potential wasted space though.
    LLVMTypeRef *element_types = allocate<LLVMTypeRef>(field_count);

    // this field should be set to true only during the recursive calls to resolve_struct_type
    struct_type->data.structure.embedded_in_current = true;

    BlockContext *context = struct_type->data.structure.block_context;

    size_t gen_field_index = 0;
    for (size_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.struct_decl.fields.at(i);
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        type_struct_field->name = field_node->data.struct_field.name;
        TypeTableEntry *field_type = analyze_type_expr(g, import, context,
                field_node->data.struct_field.type);
        type_struct_field->type_entry = field_type;
        type_struct_field->src_index = i;
        type_struct_field->gen_index = SIZE_MAX;

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

    size_t gen_field_count = gen_field_index;
    LLVMStructSetBody(struct_type->type_ref, element_types, gen_field_count, false);

    ZigLLVMDIType **di_element_types = allocate<ZigLLVMDIType*>(gen_field_count);

    for (size_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.struct_decl.fields.at(i);
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        gen_field_index = type_struct_field->gen_index;
        if (gen_field_index == SIZE_MAX) {
            continue;
        }

        TypeTableEntry *field_type = type_struct_field->type_entry;

        assert(field_type->type_ref);
        assert(struct_type->type_ref);
        assert(struct_type->data.structure.complete);
        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, field_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, field_type->type_ref);
        uint64_t debug_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, struct_type->type_ref,
                gen_field_index);
        di_element_types[gen_field_index] = ZigLLVMCreateDebugMemberType(g->dbuilder,
                ZigLLVMTypeToScope(struct_type->di_type), buf_ptr(type_struct_field->name),
                import->di_file, field_node->line + 1,
                debug_size_in_bits,
                debug_align_in_bits,
                debug_offset_in_bits,
                0, field_type->di_type);

        assert(di_element_types[gen_field_index]);
    }


    uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, struct_type->type_ref);
    uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, struct_type->type_ref);
    ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
            ZigLLVMFileToScope(import->di_file),
            buf_ptr(decl_node->data.struct_decl.name),
            import->di_file, decl_node->line + 1,
            debug_size_in_bits,
            debug_align_in_bits,
            0, nullptr, di_element_types, gen_field_count, 0, nullptr, "");

    ZigLLVMReplaceTemporary(g->dbuilder, struct_type->di_type, replacement_di_type);
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

static bool get_is_generic_fn(AstNode *proto_node) {
    assert(proto_node->type == NodeTypeFnProto);
    return proto_node->data.fn_proto.inline_or_var_type_arg_count > 0;
}

static void preview_fn_proto_instance(CodeGen *g, ImportTableEntry *import, AstNode *proto_node,
        BlockContext *containing_context)
{
    assert(proto_node->type == NodeTypeFnProto);

    if (proto_node->data.fn_proto.skip) {
        return;
    }

    bool is_generic_instance = proto_node->data.fn_proto.generic_proto_node;
    bool is_generic_fn = get_is_generic_fn(proto_node);
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
            for (size_t i = 0; i < proto_node->data.fn_proto.params.length; i += 1) {
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
                !proto_node->data.fn_proto.skip &&
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
    for (size_t i = 0; i < node->data.struct_decl.decls.length; i += 1) {
        AstNode *child_node = node->data.struct_decl.decls.at(i);
        get_as_top_level_decl(child_node)->parent_decl = node;
        BlockContext *child_context = get_container_block_context(container_type);
        scan_decls(g, import, child_context, child_node);
    }
}

static void count_inline_and_var_args(AstNode *proto_node) {
    assert(proto_node->type == NodeTypeFnProto);

    size_t *inline_arg_count = &proto_node->data.fn_proto.inline_arg_count;
    size_t *inline_or_var_type_arg_count = &proto_node->data.fn_proto.inline_or_var_type_arg_count;

    *inline_arg_count = 0;
    *inline_or_var_type_arg_count = 0;

    // TODO run these nodes through the type analysis system rather than looking for
    // specialized ast nodes. this would get fooled by `{var}` instead of `var` which
    // is supposed to be equivalent
    for (size_t i = 0; i < proto_node->data.fn_proto.params.length; i += 1) {
        AstNode *param_node = proto_node->data.fn_proto.params.at(i);
        assert(param_node->type == NodeTypeParamDecl);
        if (param_node->data.param_decl.is_inline) {
            *inline_arg_count += 1;
            *inline_or_var_type_arg_count += 1;
        } else if (param_node->data.param_decl.type->type == NodeTypeVarLiteral) {
            *inline_or_var_type_arg_count += 1;
        }
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
        size_t error_value_count = g->error_decls.length;
        assert((uint32_t)error_value_count < (((uint32_t)1) << (uint32_t)g->err_tag_type->data.integral.bit_count));
        err->value = error_value_count;
        g->error_decls.append(node);
        g->error_table.put(&err->name, err);
    }

    node->data.error_value_decl.err = err;
    node->data.error_value_decl.top_level_decl.resolution = TldResolutionOk;
}

static void scan_decls(CodeGen *g, ImportTableEntry *import, BlockContext *context, AstNode *node) {
    switch (node->type) {
        case NodeTypeRoot:
            for (size_t i = 0; i < import->root->data.root.top_level_decls.length; i += 1) {
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
                count_inline_and_var_args(node);

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
        case NodeTypeThisLiteral:
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
        case NodeTypeVarLiteral:
            zig_unreachable();
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

TypeTableEntry *validate_var_type(CodeGen *g, AstNode *source_node, TypeTableEntry *type_entry) {
    TypeTableEntry *underlying_type = get_underlying_type(type_entry);
    switch (underlying_type->id) {
        case TypeTableEntryIdTypeDecl:
            zig_unreachable();
        case TypeTableEntryIdInvalid:
            return g->builtin_types.entry_invalid;
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVar:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdBlock:
            add_node_error(g, source_node, buf_sprintf("variable of type '%s' not allowed",
                buf_ptr(&underlying_type->name)));
            return g->builtin_types.entry_invalid;
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdMetaType:
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
        case TypeTableEntryIdGenericFn:
            return type_entry;
    }
    zig_unreachable();
}

// Set name to nullptr to make the variable anonymous (not visible to programmer).
// TODO merge with definition of add_local_var in ir.cpp
static VariableTableEntry *add_local_var_shadowable(CodeGen *g, AstNode *source_node, ImportTableEntry *import,
        BlockContext *context, Buf *name, TypeTableEntry *type_entry, bool is_const, AstNode *val_node,
        bool shadowable)
{
    VariableTableEntry *variable_entry = allocate<VariableTableEntry>(1);
    variable_entry->type = type_entry;
    variable_entry->block_context = context;
    variable_entry->import = import;
    variable_entry->shadowable = shadowable;
    variable_entry->mem_slot_index = SIZE_MAX;

    if (name) {
        buf_init_from_buf(&variable_entry->name, name);

        if (type_entry->id != TypeTableEntryIdInvalid) {
            VariableTableEntry *existing_var = find_variable(g, context, name);
            if (existing_var && !existing_var->shadowable) {
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

    variable_entry->src_is_const = is_const;
    variable_entry->gen_is_const = is_const;
    variable_entry->decl_node = source_node;
    variable_entry->val_node = val_node;


    return variable_entry;
}

static VariableTableEntry *add_local_var(CodeGen *g, AstNode *source_node, ImportTableEntry *import,
        BlockContext *context, Buf *name, TypeTableEntry *type_entry, bool is_const, AstNode *val_node)
{
    return add_local_var_shadowable(g, source_node, import, context, name, type_entry, is_const, val_node, false);
}

static void resolve_var_decl(CodeGen *g, ImportTableEntry *import, AstNode *node) {
    assert(node->type == NodeTypeVariableDeclaration);

    AstNodeVariableDeclaration *var_decl = &node->data.variable_declaration;
    BlockContext *scope = node->block_context;
    bool is_const = var_decl->is_const;
    bool is_export = (var_decl->top_level_decl.visib_mod == VisibModExport);
    bool is_extern = var_decl->is_extern;

    assert(!scope->fn_entry);

    TypeTableEntry *explicit_type = nullptr;
    if (var_decl->type) {
        TypeTableEntry *proposed_type = analyze_type_expr(g, import, scope, var_decl->type);
        explicit_type = validate_var_type(g, var_decl->type, proposed_type);
    }

    TypeTableEntry *implicit_type = nullptr;
    if (explicit_type && explicit_type->id == TypeTableEntryIdInvalid) {
        implicit_type = explicit_type;
    } else if (var_decl->expr) {
        IrInstruction *result = analyze_const_value(g, scope, var_decl->expr, explicit_type);
        assert(result);
        implicit_type = result->type_entry;

        if (implicit_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, node, buf_sprintf("variable initialization is unreachable"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if ((!is_const || is_export) &&
                (implicit_type->id == TypeTableEntryIdNumLitFloat ||
                implicit_type->id == TypeTableEntryIdNumLitInt))
        {
            add_node_error(g, node, buf_sprintf("unable to infer variable type"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if (implicit_type->id == TypeTableEntryIdMetaType && !is_const) {
            add_node_error(g, node, buf_sprintf("variable of type 'type' must be constant"));
            implicit_type = g->builtin_types.entry_invalid;
        }
        if (implicit_type->id != TypeTableEntryIdInvalid) {
            Expr *expr = get_resolved_expr(var_decl->expr);
            assert(result->static_value.special != ConstValSpecialRuntime);
            expr->instruction = result;
        }
    } else if (!is_extern) {
        add_node_error(g, node, buf_sprintf("variables must be initialized"));
        implicit_type = g->builtin_types.entry_invalid;
    }

    TypeTableEntry *type = explicit_type ? explicit_type : implicit_type;
    assert(type != nullptr); // should have been caught by the parser

    VariableTableEntry *var = add_local_var(g, node, import, scope,
            var_decl->symbol, type, is_const, var_decl->expr);

    var_decl->variable = var;

    g->global_vars.append(var);
}

void resolve_top_level_decl(CodeGen *g, AstNode *node, bool pointer_only) {
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
            resolve_var_decl(g, import, node);
            break;
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
        case NodeTypeThisLiteral:
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
        case NodeTypeVarLiteral:
            zig_unreachable();
    }

    tld->resolution = TldResolutionOk;
    tld->dep_loop_flag = false;
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
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
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

        case TypeTableEntryIdVar:
            zig_unreachable();
    }
    zig_unreachable();
}

static bool num_lit_fits_in_other_type(CodeGen *g, AstNode *literal_node, TypeTableEntry *other_type) {
    TypeTableEntry *other_type_underlying = get_underlying_type(other_type);

    if (other_type_underlying->id == TypeTableEntryIdInvalid) {
        return false;
    }

    Expr *expr = get_resolved_expr(literal_node);
    ConstExprValue *const_val = &expr->instruction->static_value;
    assert(const_val->special != ConstValSpecialRuntime);
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

bool types_match_const_cast_only(TypeTableEntry *expected_type, TypeTableEntry *actual_type) {
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
        for (size_t i = 0; i < expected_type->data.fn.fn_type_id.param_count; i += 1) {
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

    // implicit conversion from null literal to maybe type
    if (expected_type->id == TypeTableEntryIdMaybe &&
        actual_type->id == TypeTableEntryIdNullLit)
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

AstNode *find_decl(BlockContext *context, Buf *name) {
    while (context) {
        auto entry = context->decl_table.maybe_get(name);
        if (entry) {
            return entry->value;
        }
        context = context->parent;
    }
    return nullptr;
}

VariableTableEntry *find_variable(CodeGen *g, BlockContext *orig_context, Buf *name) {
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

TypeEnumField *find_enum_type_field(TypeTableEntry *enum_type, Buf *name) {
    for (uint32_t i = 0; i < enum_type->data.enumeration.src_field_count; i += 1) {
        TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[i];
        if (buf_eql_buf(type_enum_field->name, name)) {
            return type_enum_field;
        }
    }
    return nullptr;
}

TypeStructField *find_struct_type_field(TypeTableEntry *type_entry, Buf *name) {
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

static bool is_container(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdVar:
            zig_unreachable();
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
            return true;
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
            return false;
    }
    zig_unreachable();
}

bool is_container_ref(TypeTableEntry *type_entry) {
    return (type_entry->id == TypeTableEntryIdPointer) ?
        is_container(type_entry->data.pointer.child_type) : is_container(type_entry);
}

TypeTableEntry *container_ref_type(TypeTableEntry *type_entry) {
    assert(is_container_ref(type_entry));
    return (type_entry->id == TypeTableEntryIdPointer) ?
        type_entry->data.pointer.child_type : type_entry;
}

void resolve_container_type(CodeGen *g, TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdStruct:
            resolve_struct_type(g, type_entry->data.structure.decl_node->owner, type_entry);
            break;
        case TypeTableEntryIdEnum:
            resolve_enum_type(g, type_entry->data.enumeration.decl_node->owner, type_entry);
            break;
        case TypeTableEntryIdUnion:
            resolve_union_type(g, type_entry->data.unionation.decl_node->owner, type_entry);
            break;
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdNumLitFloat:
        case TypeTableEntryIdNumLitInt:
        case TypeTableEntryIdUndefLit:
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdMaybe:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdPureError:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdTypeDecl:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdVar:
            zig_unreachable();
    }
}

bool type_is_codegen_pointer(TypeTableEntry *type) {
    if (type->id == TypeTableEntryIdPointer) return true;
    if (type->id == TypeTableEntryIdFn) return true;
    if (type->id == TypeTableEntryIdMaybe) {
        if (type->data.maybe.child_type->id == TypeTableEntryIdPointer) return true;
        if (type->data.maybe.child_type->id == TypeTableEntryIdFn) return true;
    }
    return false;
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
    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;
    AstNodeFnProto *fn_proto = &fn_proto_node->data.fn_proto;
    for (size_t i = 0; i < fn_proto->params.length; i += 1) {
        AstNode *param_decl_node = fn_proto->params.at(i);
        assert(param_decl_node->type == NodeTypeParamDecl);

        // define local variables for parameters
        AstNodeParamDecl *param_decl = &param_decl_node->data.param_decl;
        TypeTableEntry *type = fn_type_id->param_info[i].type;

        if (param_decl->is_noalias && !type_is_codegen_pointer(type)) {
            add_node_error(g, param_decl_node, buf_sprintf("noalias on non-pointer parameter"));
        }

        if (fn_type->data.fn.fn_type_id.is_extern && handle_is_ptr(type)) {
            add_node_error(g, param_decl_node,
                buf_sprintf("byvalue types not yet supported on extern function parameters"));
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

    if (fn_type->data.fn.fn_type_id.is_extern && handle_is_ptr(expected_type)) {
        add_node_error(g, fn_proto_node->data.fn_proto.return_type,
            buf_sprintf("byvalue types not yet supported on extern function return values"));
    }

    IrInstruction *result = ir_gen_fn(g, fn_table_entry);
    if (result == g->invalid_instruction) {
        fn_proto_node->data.fn_proto.skip = true;
        fn_table_entry->anal_state = FnAnalStateSkipped;
        return;
    }
    if (g->verbose) {
        fprintf(stderr, "\n");
        ast_render(stderr, fn_table_entry->fn_def_node, 4);
        fprintf(stderr, "\n{ // (IR)\n");
        ir_print(stderr, &fn_table_entry->ir_executable, 4);
        fprintf(stderr, "}\n");
    }

    TypeTableEntry *block_return_type = ir_analyze(g, &fn_table_entry->ir_executable,
            &fn_table_entry->analyzed_executable, expected_type, fn_proto->return_type);
    node->data.fn_def.implicit_return_type = block_return_type;

    if (block_return_type->id != TypeTableEntryIdInvalid && g->verbose) {
        fprintf(stderr, "{ // (analyzed)\n");
        ir_print(stderr, &fn_table_entry->analyzed_executable, 4);
        fprintf(stderr, "}\n");
    }

    fn_table_entry->anal_state = FnAnalStateComplete;
}

static void add_symbols_from_import(CodeGen *g, AstNode *src_use_node, AstNode *dst_use_node) {
    TopLevelDecl *tld = get_as_top_level_decl(dst_use_node);
    AstNode *use_target_node = src_use_node->data.use.expr;
    Expr *expr = get_resolved_expr(use_target_node);

    if (expr->instruction->type_entry->id == TypeTableEntryIdInvalid) {
        tld->import->any_imports_failed = true;
        return;
    }

    tld->resolution = TldResolutionOk;

    ConstExprValue *const_val = &expr->instruction->static_value;
    assert(const_val->special != ConstValSpecialRuntime);

    ImportTableEntry *target_import = const_val->data.x_import;
    assert(target_import);

    if (target_import->any_imports_failed) {
        tld->import->any_imports_failed = true;
    }

    for (size_t i = 0; i < target_import->root->data.root.top_level_decls.length; i += 1) {
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

    for (size_t i = 0; i < target_import->use_decls.length; i += 1) {
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

    IrInstruction *result = analyze_const_value(g, tld->import->block_context, node->data.use.expr,
            g->builtin_types.entry_namespace);
    if (result->type_entry->id == TypeTableEntryIdInvalid)
        tld->import->any_imports_failed = true;
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

    import_entry->di_file = ZigLLVMCreateFile(g->dbuilder, buf_ptr(src_basename), buf_ptr(src_dirname));
    g->import_table.put(abs_full_path, import_entry);
    g->import_queue.append(import_entry);

    import_entry->block_context = new_block_context(import_entry->root, nullptr);
    import_entry->block_context->di_scope = ZigLLVMFileToScope(import_entry->di_file);


    assert(import_entry->root->type == NodeTypeRoot);
    for (size_t decl_i = 0; decl_i < import_entry->root->data.root.top_level_decls.length; decl_i += 1) {
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

    for (size_t i = 0; i < g->use_queue.length; i += 1) {
        AstNode *use_decl_node = g->use_queue.at(i);
        resolve_use_decl(g, use_decl_node);
    }

    for (; g->resolve_queue_index < g->resolve_queue.length; g->resolve_queue_index += 1) {
        AstNode *decl_node = g->resolve_queue.at(g->resolve_queue_index);
        bool pointer_only = false;
        resolve_top_level_decl(g, decl_node, pointer_only);
    }

    for (size_t i = 0; i < g->fn_defs.length; i += 1) {
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
        case NodeTypeThisLiteral:
            return &node->data.this_literal.resolved_expr;
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
        case NodeTypeVarLiteral:
            return &node->data.var_literal.resolved_expr;
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeRoot:
        case NodeTypeFnDef:
        case NodeTypeFnDecl:
        case NodeTypeParamDecl:
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

TopLevelDecl *get_as_top_level_decl(AstNode *node) {
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
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeSymbol:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeZeroesLiteral:
        case NodeTypeThisLiteral:
        case NodeTypeLabel:
        case NodeTypeGoto:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeStructField:
        case NodeTypeStructValueField:
        case NodeTypeArrayType:
        case NodeTypeErrorType:
        case NodeTypeTypeLiteral:
        case NodeTypeVarLiteral:
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

TypeTableEntry **get_int_type_ptr(CodeGen *g, bool is_signed, size_t size_in_bits) {
    size_t index;
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

TypeTableEntry *get_int_type(CodeGen *g, bool is_signed, size_t size_in_bits) {
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
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdVar:
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
    return ((uintptr_t)ptr) % UINT32_MAX;
}

static uint32_t hash_size(size_t x) {
    return x % UINT32_MAX;
}

uint32_t fn_type_id_hash(FnTypeId *id) {
    uint32_t result = 0;
    result += id->is_extern ? 3349388391 : 0;
    result += id->is_naked ? 608688877 : 0;
    result += id->is_cold ? 3605523458 : 0;
    result += id->is_var_args ? 1931444534 : 0;
    result += hash_ptr(id->return_type);
    for (size_t i = 0; i < id->param_count; i += 1) {
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
    for (size_t i = 0; i < a->param_count; i += 1) {
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
            return hash_ptr(const_val->data.x_ptr.base_ptr) + hash_size(const_val->data.x_ptr.index);
        case TypeTableEntryIdUndefLit:
            return 162837799;
        case TypeTableEntryIdNullLit:
            return 844854567;
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
        case TypeTableEntryIdBlock:
            return hash_ptr(const_val->data.x_block);
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVar:
            zig_unreachable();
    }
    zig_unreachable();
}

uint32_t generic_fn_type_id_hash(GenericFnTypeId *id) {
    uint32_t result = 0;
    result += hash_ptr(id->decl_node);
    for (size_t i = 0; i < id->generic_param_count; i += 1) {
        GenericParamValue *generic_param = &id->generic_params[i];
        if (generic_param->node) {
            ConstExprValue *const_val = &get_resolved_expr(generic_param->node)->instruction->static_value;
            assert(const_val->special != ConstValSpecialRuntime);
            result += hash_const_val(generic_param->type, const_val);
        }
        result += hash_ptr(generic_param->type);
    }
    return result;
}

bool generic_fn_type_id_eql(GenericFnTypeId *a, GenericFnTypeId *b) {
    if (a->decl_node != b->decl_node) return false;
    assert(a->generic_param_count == b->generic_param_count);
    for (size_t i = 0; i < a->generic_param_count; i += 1) {
        GenericParamValue *a_val = &a->generic_params[i];
        GenericParamValue *b_val = &b->generic_params[i];
        if (a_val->type != b_val->type) return false;
        if (a_val->node && b_val->node) {
            ConstExprValue *a_const_val = &get_resolved_expr(a_val->node)->instruction->static_value;
            ConstExprValue *b_const_val = &get_resolved_expr(b_val->node)->instruction->static_value;
            assert(a_const_val->special != ConstValSpecialRuntime);
            assert(b_const_val->special != ConstValSpecialRuntime);
            if (!const_values_equal(a_const_val, b_const_val, a_val->type)) {
                return false;
            }
        } else {
            assert(!a_val->node && !b_val->node);
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
        case TypeTableEntryIdNullLit:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdGenericFn:
        case TypeTableEntryIdVar:
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


