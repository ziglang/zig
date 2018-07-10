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
#include "ir.hpp"
#include "ir_print.hpp"
#include "os.hpp"
#include "parser.hpp"
#include "softfloat.hpp"
#include "zig_llvm.h"


static const size_t default_backward_branch_quota = 1000;

static void resolve_enum_type(CodeGen *g, TypeTableEntry *enum_type);
static void resolve_struct_type(CodeGen *g, TypeTableEntry *struct_type);

static void resolve_struct_zero_bits(CodeGen *g, TypeTableEntry *struct_type);
static void resolve_enum_zero_bits(CodeGen *g, TypeTableEntry *enum_type);
static void resolve_union_zero_bits(CodeGen *g, TypeTableEntry *union_type);
static void analyze_fn_body(CodeGen *g, FnTableEntry *fn_table_entry);

ErrorMsg *add_node_error(CodeGen *g, AstNode *node, Buf *msg) {
    if (node->owner->c_import_node != nullptr) {
        // if this happens, then translate_c generated code that
        // failed semantic analysis, which isn't supposed to happen
        ErrorMsg *err = add_node_error(g, node->owner->c_import_node,
            buf_sprintf("compiler bug: @cImport generated invalid zig code"));

        add_error_note(g, err, node, msg);

        g->errors.append(err);
        return err;
    }

    ErrorMsg *err = err_msg_create_with_line(node->owner->path, node->line, node->column,
            node->owner->source_code, node->owner->line_offsets, msg);

    g->errors.append(err);
    return err;
}

ErrorMsg *add_error_note(CodeGen *g, ErrorMsg *parent_msg, AstNode *node, Buf *msg) {
    if (node->owner->c_import_node != nullptr) {
        // if this happens, then translate_c generated code that
        // failed semantic analysis, which isn't supposed to happen

        Buf *note_path = buf_create_from_str("?.c");
        Buf *note_source = buf_create_from_str("TODO: remember C source location to display here ");
        ZigList<size_t> note_line_offsets = {0};
        note_line_offsets.append(0);
        ErrorMsg *note = err_msg_create_with_line(note_path, 0, 0,
                note_source, &note_line_offsets, msg);

        err_msg_add_note(parent_msg, note);
        return note;
    }

    ErrorMsg *err = err_msg_create_with_line(node->owner->path, node->line, node->column,
            node->owner->source_code, node->owner->line_offsets, msg);

    err_msg_add_note(parent_msg, err);
    return err;
}

TypeTableEntry *new_type_table_entry(TypeTableEntryId id) {
    TypeTableEntry *entry = allocate<TypeTableEntry>(1);
    entry->id = id;
    return entry;
}

static ScopeDecls **get_container_scope_ptr(TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdStruct) {
        return &type_entry->data.structure.decls_scope;
    } else if (type_entry->id == TypeTableEntryIdEnum) {
        return &type_entry->data.enumeration.decls_scope;
    } else if (type_entry->id == TypeTableEntryIdUnion) {
        return &type_entry->data.unionation.decls_scope;
    }
    zig_unreachable();
}

ScopeDecls *get_container_scope(TypeTableEntry *type_entry) {
    return *get_container_scope_ptr(type_entry);
}

void init_scope(Scope *dest, ScopeId id, AstNode *source_node, Scope *parent) {
    dest->id = id;
    dest->source_node = source_node;
    dest->parent = parent;
}

ScopeDecls *create_decls_scope(AstNode *node, Scope *parent, TypeTableEntry *container_type, ImportTableEntry *import) {
    assert(node == nullptr || node->type == NodeTypeRoot || node->type == NodeTypeContainerDecl || node->type == NodeTypeFnCallExpr);
    ScopeDecls *scope = allocate<ScopeDecls>(1);
    init_scope(&scope->base, ScopeIdDecls, node, parent);
    scope->decl_table.init(4);
    scope->container_type = container_type;
    scope->import = import;
    return scope;
}

ScopeBlock *create_block_scope(AstNode *node, Scope *parent) {
    assert(node->type == NodeTypeBlock);
    ScopeBlock *scope = allocate<ScopeBlock>(1);
    init_scope(&scope->base, ScopeIdBlock, node, parent);
    scope->name = node->data.block.name;
    return scope;
}

ScopeDefer *create_defer_scope(AstNode *node, Scope *parent) {
    assert(node->type == NodeTypeDefer);
    ScopeDefer *scope = allocate<ScopeDefer>(1);
    init_scope(&scope->base, ScopeIdDefer, node, parent);
    return scope;
}

ScopeDeferExpr *create_defer_expr_scope(AstNode *node, Scope *parent) {
    assert(node->type == NodeTypeDefer);
    ScopeDeferExpr *scope = allocate<ScopeDeferExpr>(1);
    init_scope(&scope->base, ScopeIdDeferExpr, node, parent);
    return scope;
}

Scope *create_var_scope(AstNode *node, Scope *parent, VariableTableEntry *var) {
    ScopeVarDecl *scope = allocate<ScopeVarDecl>(1);
    init_scope(&scope->base, ScopeIdVarDecl, node, parent);
    scope->var = var;
    return &scope->base;
}

ScopeCImport *create_cimport_scope(AstNode *node, Scope *parent) {
    assert(node->type == NodeTypeFnCallExpr);
    ScopeCImport *scope = allocate<ScopeCImport>(1);
    init_scope(&scope->base, ScopeIdCImport, node, parent);
    buf_resize(&scope->buf, 0);
    return scope;
}

ScopeLoop *create_loop_scope(AstNode *node, Scope *parent) {
    ScopeLoop *scope = allocate<ScopeLoop>(1);
    init_scope(&scope->base, ScopeIdLoop, node, parent);
    if (node->type == NodeTypeWhileExpr) {
        scope->name = node->data.while_expr.name;
    } else if (node->type == NodeTypeForExpr) {
        scope->name = node->data.for_expr.name;
    } else {
        zig_unreachable();
    }
    return scope;
}

ScopeSuspend *create_suspend_scope(AstNode *node, Scope *parent) {
    assert(node->type == NodeTypeSuspend);
    ScopeSuspend *scope = allocate<ScopeSuspend>(1);
    init_scope(&scope->base, ScopeIdSuspend, node, parent);
    scope->name = node->data.suspend.name;
    return scope;
}

ScopeFnDef *create_fndef_scope(AstNode *node, Scope *parent, FnTableEntry *fn_entry) {
    ScopeFnDef *scope = allocate<ScopeFnDef>(1);
    init_scope(&scope->base, ScopeIdFnDef, node, parent);
    scope->fn_entry = fn_entry;
    return scope;
}

Scope *create_comptime_scope(AstNode *node, Scope *parent) {
    assert(node->type == NodeTypeCompTime || node->type == NodeTypeSwitchExpr);
    ScopeCompTime *scope = allocate<ScopeCompTime>(1);
    init_scope(&scope->base, ScopeIdCompTime, node, parent);
    return &scope->base;
}

Scope *create_coro_prelude_scope(AstNode *node, Scope *parent) {
    ScopeCoroPrelude *scope = allocate<ScopeCoroPrelude>(1);
    init_scope(&scope->base, ScopeIdCoroPrelude, node, parent);
    return &scope->base;
}

ImportTableEntry *get_scope_import(Scope *scope) {
    while (scope) {
        if (scope->id == ScopeIdDecls) {
            ScopeDecls *decls_scope = (ScopeDecls *)scope;
            assert(decls_scope->import);
            return decls_scope->import;
        }
        scope = scope->parent;
    }
    zig_unreachable();
}

static TypeTableEntry *new_container_type_entry(TypeTableEntryId id, AstNode *source_node, Scope *parent_scope) {
    TypeTableEntry *entry = new_type_table_entry(id);
    *get_container_scope_ptr(entry) = create_decls_scope(source_node, parent_scope, entry, get_scope_import(parent_scope));
    return entry;
}

static uint8_t bits_needed_for_unsigned(uint64_t x) {
    if (x == 0) {
        return 0;
    }
    uint8_t base = log2_u64(x);
    uint64_t upper = (((uint64_t)1) << base) - 1;
    return (upper >= x) ? base : (base + 1);
}

AstNode *type_decl_node(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdStruct:
            return type_entry->data.structure.decl_node;
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.decl_node;
        case TypeTableEntryIdUnion:
            return type_entry->data.unionation.decl_node;
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdPromise:
            return nullptr;
    }
    zig_unreachable();
}

bool type_is_complete(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdStruct:
            return type_entry->data.structure.complete;
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.complete;
        case TypeTableEntryIdUnion:
            return type_entry->data.unionation.complete;
        case TypeTableEntryIdOpaque:
            return false;
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdPromise:
            return true;
    }
    zig_unreachable();
}

bool type_has_zero_bits_known(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdStruct:
            return type_entry->data.structure.zero_bits_known;
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.zero_bits_known;
        case TypeTableEntryIdUnion:
            return type_entry->data.unionation.zero_bits_known;
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdPromise:
            return true;
    }
    zig_unreachable();
}


uint64_t type_size(CodeGen *g, TypeTableEntry *type_entry) {
    assert(type_is_complete(type_entry));

    if (!type_has_bits(type_entry))
        return 0;

    if (type_entry->id == TypeTableEntryIdStruct && type_entry->data.structure.layout == ContainerLayoutPacked) {
        uint64_t size_in_bits = type_size_bits(g, type_entry);
        return (size_in_bits + 7) / 8;
    } else if (type_entry->id == TypeTableEntryIdArray) {
        TypeTableEntry *child_type = type_entry->data.array.child_type;
        if (child_type->id == TypeTableEntryIdStruct &&
            child_type->data.structure.layout == ContainerLayoutPacked)
        {
            uint64_t size_in_bits = type_size_bits(g, type_entry);
            return (size_in_bits + 7) / 8;
        }
    }

    return LLVMStoreSizeOfType(g->target_data_ref, type_entry->type_ref);
}

uint64_t type_size_bits(CodeGen *g, TypeTableEntry *type_entry) {
    assert(type_is_complete(type_entry));

    if (!type_has_bits(type_entry))
        return 0;

    if (type_entry->id == TypeTableEntryIdStruct && type_entry->data.structure.layout == ContainerLayoutPacked) {
        uint64_t result = 0;
        for (size_t i = 0; i < type_entry->data.structure.src_field_count; i += 1) {
            result += type_size_bits(g, type_entry->data.structure.fields[i].type_entry);
        }
        return result;
    } else if (type_entry->id == TypeTableEntryIdArray) {
        TypeTableEntry *child_type = type_entry->data.array.child_type;
        if (child_type->id == TypeTableEntryIdStruct &&
            child_type->data.structure.layout == ContainerLayoutPacked)
        {
            return type_entry->data.array.len * type_size_bits(g, child_type);
        }
    }

    return LLVMSizeOfTypeInBits(g->target_data_ref, type_entry->type_ref);
}

bool type_is_copyable(CodeGen *g, TypeTableEntry *type_entry) {
    type_ensure_zero_bits_known(g, type_entry);
    if (!type_has_bits(type_entry))
        return true;

    if (!handle_is_ptr(type_entry))
        return true;

    ensure_complete_type(g, type_entry);
    return type_entry->is_copyable;
}

static bool is_slice(TypeTableEntry *type) {
    return type->id == TypeTableEntryIdStruct && type->data.structure.is_slice;
}

TypeTableEntry *get_smallest_unsigned_int_type(CodeGen *g, uint64_t x) {
    return get_int_type(g, false, bits_needed_for_unsigned(x));
}

TypeTableEntry *get_promise_type(CodeGen *g, TypeTableEntry *result_type) {
    if (result_type != nullptr && result_type->promise_parent != nullptr) {
        return result_type->promise_parent;
    } else if (result_type == nullptr && g->builtin_types.entry_promise != nullptr) {
        return g->builtin_types.entry_promise;
    }

    TypeTableEntry *u8_ptr_type = get_pointer_to_type(g, g->builtin_types.entry_u8, false);
    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdPromise);
    entry->type_ref = u8_ptr_type->type_ref;
    entry->zero_bits = false;
    entry->data.promise.result_type = result_type;
    buf_init_from_str(&entry->name, "promise");
    if (result_type != nullptr) {
        buf_appendf(&entry->name, "->%s", buf_ptr(&result_type->name));
    }
    entry->di_type = u8_ptr_type->di_type;

    if (result_type != nullptr) {
        result_type->promise_parent = entry;
    } else if (result_type == nullptr) {
        g->builtin_types.entry_promise = entry;
    }
    return entry;
}

TypeTableEntry *get_pointer_to_type_extra(CodeGen *g, TypeTableEntry *child_type, bool is_const,
        bool is_volatile, PtrLen ptr_len, uint32_t byte_alignment, uint32_t bit_offset, uint32_t unaligned_bit_count)
{
    assert(!type_is_invalid(child_type));
    assert(ptr_len == PtrLenSingle || child_type->id != TypeTableEntryIdOpaque);

    TypeId type_id = {};
    TypeTableEntry **parent_pointer = nullptr;
    uint32_t abi_alignment = get_abi_alignment(g, child_type);
    if (unaligned_bit_count != 0 || is_volatile || byte_alignment != abi_alignment || ptr_len != PtrLenSingle) {
        type_id.id = TypeTableEntryIdPointer;
        type_id.data.pointer.child_type = child_type;
        type_id.data.pointer.is_const = is_const;
        type_id.data.pointer.is_volatile = is_volatile;
        type_id.data.pointer.alignment = byte_alignment;
        type_id.data.pointer.bit_offset = bit_offset;
        type_id.data.pointer.unaligned_bit_count = unaligned_bit_count;
        type_id.data.pointer.ptr_len = ptr_len;

        auto existing_entry = g->type_table.maybe_get(type_id);
        if (existing_entry)
            return existing_entry->value;
    } else {
        assert(bit_offset == 0);
        parent_pointer = &child_type->pointer_parent[(is_const ? 1 : 0)];
        if (*parent_pointer) {
            assert((*parent_pointer)->data.pointer.alignment == byte_alignment);
            return *parent_pointer;
        }
    }

    type_ensure_zero_bits_known(g, child_type);

    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdPointer);
    entry->is_copyable = true;

    const char *star_str = ptr_len == PtrLenSingle ? "*" : "[*]";
    const char *const_str = is_const ? "const " : "";
    const char *volatile_str = is_volatile ? "volatile " : "";
    buf_resize(&entry->name, 0);
    if (unaligned_bit_count == 0 && byte_alignment == abi_alignment) {
        buf_appendf(&entry->name, "%s%s%s%s", star_str, const_str, volatile_str, buf_ptr(&child_type->name));
    } else if (unaligned_bit_count == 0) {
        buf_appendf(&entry->name, "%salign(%" PRIu32 ") %s%s%s", star_str, byte_alignment,
                const_str, volatile_str, buf_ptr(&child_type->name));
    } else {
        buf_appendf(&entry->name, "%salign(%" PRIu32 ":%" PRIu32 ":%" PRIu32 ") %s%s%s", star_str, byte_alignment,
                bit_offset, bit_offset + unaligned_bit_count, const_str, volatile_str, buf_ptr(&child_type->name));
    }

    assert(child_type->id != TypeTableEntryIdInvalid);

    entry->zero_bits = !type_has_bits(child_type);

    if (!entry->zero_bits) {
        assert(byte_alignment > 0);
        if (is_const || is_volatile || unaligned_bit_count != 0 || byte_alignment != abi_alignment ||
            ptr_len != PtrLenSingle)
        {
            TypeTableEntry *peer_type = get_pointer_to_type(g, child_type, false);
            entry->type_ref = peer_type->type_ref;
            entry->di_type = peer_type->di_type;
        } else {
            entry->type_ref = LLVMPointerType(child_type->type_ref, 0);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, entry->type_ref);
            assert(child_type->di_type);
            entry->di_type = ZigLLVMCreateDebugPointerType(g->dbuilder, child_type->di_type,
                    debug_size_in_bits, debug_align_in_bits, buf_ptr(&entry->name));
        }
    } else {
        assert(byte_alignment == 0);
        entry->di_type = g->builtin_types.entry_void->di_type;
    }

    entry->data.pointer.ptr_len = ptr_len;
    entry->data.pointer.child_type = child_type;
    entry->data.pointer.is_const = is_const;
    entry->data.pointer.is_volatile = is_volatile;
    entry->data.pointer.alignment = byte_alignment;
    entry->data.pointer.bit_offset = bit_offset;
    entry->data.pointer.unaligned_bit_count = unaligned_bit_count;

    if (parent_pointer) {
        *parent_pointer = entry;
    } else {
        g->type_table.put(type_id, entry);
    }
    return entry;
}

TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const) {
    return get_pointer_to_type_extra(g, child_type, is_const, false, PtrLenSingle,
            get_abi_alignment(g, child_type), 0, 0);
}

TypeTableEntry *get_promise_frame_type(CodeGen *g, TypeTableEntry *return_type) {
    if (return_type->promise_frame_parent != nullptr) {
        return return_type->promise_frame_parent;
    }

    TypeTableEntry *awaiter_handle_type = get_optional_type(g, g->builtin_types.entry_promise);
    TypeTableEntry *result_ptr_type = get_pointer_to_type(g, return_type, false);

    ZigList<const char *> field_names = {};
    field_names.append(AWAITER_HANDLE_FIELD_NAME);
    field_names.append(RESULT_FIELD_NAME);
    field_names.append(RESULT_PTR_FIELD_NAME);
    if (g->have_err_ret_tracing) {
        field_names.append(ERR_RET_TRACE_PTR_FIELD_NAME);
        field_names.append(ERR_RET_TRACE_FIELD_NAME);
        field_names.append(RETURN_ADDRESSES_FIELD_NAME);
    }

    ZigList<TypeTableEntry *> field_types = {};
    field_types.append(awaiter_handle_type);
    field_types.append(return_type);
    field_types.append(result_ptr_type);
    if (g->have_err_ret_tracing) {
        field_types.append(get_ptr_to_stack_trace_type(g));
        field_types.append(g->stack_trace_type);
        field_types.append(get_array_type(g, g->builtin_types.entry_usize, stack_trace_ptr_count));
    }

    assert(field_names.length == field_types.length);
    Buf *name = buf_sprintf("AsyncFramePromise(%s)", buf_ptr(&return_type->name));
    TypeTableEntry *entry = get_struct_type(g, buf_ptr(name), field_names.items, field_types.items, field_names.length);

    return_type->promise_frame_parent = entry;
    return entry;
}

TypeTableEntry *get_optional_type(CodeGen *g, TypeTableEntry *child_type) {
    if (child_type->optional_parent) {
        TypeTableEntry *entry = child_type->optional_parent;
        return entry;
    } else {
        ensure_complete_type(g, child_type);

        TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdOptional);
        assert(child_type->type_ref || child_type->zero_bits);
        entry->is_copyable = type_is_copyable(g, child_type);

        buf_resize(&entry->name, 0);
        buf_appendf(&entry->name, "?%s", buf_ptr(&child_type->name));

        if (child_type->zero_bits) {
            entry->type_ref = LLVMInt1Type();
            entry->di_type = g->builtin_types.entry_bool->di_type;
        } else if (type_is_codegen_pointer(child_type)) {
            assert(child_type->di_type);
            // this is an optimization but also is necessary for calling C
            // functions where all pointers are maybe pointers
            // function types are technically pointers
            entry->type_ref = child_type->type_ref;
            entry->di_type = child_type->di_type;
        } else {
            assert(child_type->di_type);
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
                        0, bool_type->di_type),
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

        child_type->optional_parent = entry;
        return entry;
    }
}

TypeTableEntry *get_error_union_type(CodeGen *g, TypeTableEntry *err_set_type, TypeTableEntry *payload_type) {
    assert(err_set_type->id == TypeTableEntryIdErrorSet);
    assert(!type_is_invalid(payload_type));

    TypeId type_id = {};
    type_id.id = TypeTableEntryIdErrorUnion;
    type_id.data.error_union.err_set_type = err_set_type;
    type_id.data.error_union.payload_type = payload_type;

    auto existing_entry = g->type_table.maybe_get(type_id);
    if (existing_entry) {
        return existing_entry->value;
    }

    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdErrorUnion);
    entry->is_copyable = true;
    assert(payload_type->di_type);
    ensure_complete_type(g, payload_type);

    buf_resize(&entry->name, 0);
    buf_appendf(&entry->name, "%s!%s", buf_ptr(&err_set_type->name), buf_ptr(&payload_type->name));

    entry->data.error_union.err_set_type = err_set_type;
    entry->data.error_union.payload_type = payload_type;

    if (!type_has_bits(payload_type)) {
        if (type_has_bits(err_set_type)) {
            entry->type_ref = err_set_type->type_ref;
            entry->di_type = err_set_type->di_type;
            g->error_di_types.append(&entry->di_type);
        } else {
            entry->zero_bits = true;
            entry->di_type = g->builtin_types.entry_void->di_type;
        }
    } else if (!type_has_bits(err_set_type)) {
        entry->type_ref = payload_type->type_ref;
        entry->di_type = payload_type->di_type;
    } else {
        LLVMTypeRef elem_types[] = {
            err_set_type->type_ref,
            payload_type->type_ref,
        };
        entry->type_ref = LLVMStructType(elem_types, 2, false);

        ZigLLVMDIScope *compile_unit_scope = ZigLLVMCompileUnitToScope(g->compile_unit);
        ZigLLVMDIFile *di_file = nullptr;
        unsigned line = 0;
        entry->di_type = ZigLLVMCreateReplaceableCompositeType(g->dbuilder,
            ZigLLVMTag_DW_structure_type(), buf_ptr(&entry->name),
            compile_unit_scope, di_file, line);

        uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, err_set_type->type_ref);
        uint64_t tag_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, err_set_type->type_ref);
        uint64_t tag_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, err_union_err_index);

        uint64_t value_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, payload_type->type_ref);
        uint64_t value_debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, payload_type->type_ref);
        uint64_t value_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref,
                err_union_payload_index);

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

        ZigLLVMDIType *di_element_types[] = {
            ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                    "tag", di_file, line,
                    tag_debug_size_in_bits,
                    tag_debug_align_in_bits,
                    tag_offset_in_bits,
                    0, err_set_type->di_type),
            ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                    "value", di_file, line,
                    value_debug_size_in_bits,
                    value_debug_align_in_bits,
                    value_offset_in_bits,
                    0, payload_type->di_type),
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

    g->type_table.put(type_id, entry);
    return entry;
}

TypeTableEntry *get_array_type(CodeGen *g, TypeTableEntry *child_type, uint64_t array_size) {
    TypeId type_id = {};
    type_id.id = TypeTableEntryIdArray;
    type_id.data.array.child_type = child_type;
    type_id.data.array.size = array_size;
    auto existing_entry = g->type_table.maybe_get(type_id);
    if (existing_entry) {
        TypeTableEntry *entry = existing_entry->value;
        return entry;
    }

    ensure_complete_type(g, child_type);

    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdArray);
    entry->zero_bits = (array_size == 0) || child_type->zero_bits;
    entry->is_copyable = false;

    buf_resize(&entry->name, 0);
    buf_appendf(&entry->name, "[%" ZIG_PRI_u64 "]%s", array_size, buf_ptr(&child_type->name));

    if (entry->zero_bits) {
        entry->di_type = ZigLLVMCreateDebugArrayType(g->dbuilder, 0,
                0, child_type->di_type, 0);
    } else {
        entry->type_ref = child_type->type_ref ? LLVMArrayType(child_type->type_ref,
                (unsigned int)array_size) : nullptr;

        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, entry->type_ref);

        entry->di_type = ZigLLVMCreateDebugArrayType(g->dbuilder, debug_size_in_bits,
                debug_align_in_bits, child_type->di_type, (int)array_size);
    }
    entry->data.array.child_type = child_type;
    entry->data.array.len = array_size;

    g->type_table.put(type_id, entry);
    return entry;
}

static void slice_type_common_init(CodeGen *g, TypeTableEntry *pointer_type, TypeTableEntry *entry) {
    unsigned element_count = 2;
    Buf *ptr_field_name = buf_create_from_str("ptr");
    Buf *len_field_name = buf_create_from_str("len");

    entry->data.structure.layout = ContainerLayoutAuto;
    entry->data.structure.is_slice = true;
    entry->data.structure.src_field_count = element_count;
    entry->data.structure.gen_field_count = element_count;
    entry->data.structure.fields = allocate<TypeStructField>(element_count);
    entry->data.structure.fields_by_name.init(element_count);
    entry->data.structure.fields[slice_ptr_index].name = ptr_field_name;
    entry->data.structure.fields[slice_ptr_index].type_entry = pointer_type;
    entry->data.structure.fields[slice_ptr_index].src_index = slice_ptr_index;
    entry->data.structure.fields[slice_ptr_index].gen_index = 0;
    entry->data.structure.fields[slice_len_index].name = len_field_name;
    entry->data.structure.fields[slice_len_index].type_entry = g->builtin_types.entry_usize;
    entry->data.structure.fields[slice_len_index].src_index = slice_len_index;
    entry->data.structure.fields[slice_len_index].gen_index = 1;

    entry->data.structure.fields_by_name.put(ptr_field_name, &entry->data.structure.fields[slice_ptr_index]);
    entry->data.structure.fields_by_name.put(len_field_name, &entry->data.structure.fields[slice_len_index]);

    assert(type_has_zero_bits_known(pointer_type->data.pointer.child_type));
    if (pointer_type->data.pointer.child_type->zero_bits) {
        entry->data.structure.gen_field_count = 1;
        entry->data.structure.fields[slice_ptr_index].gen_index = SIZE_MAX;
        entry->data.structure.fields[slice_len_index].gen_index = 0;
    }
}

TypeTableEntry *get_slice_type(CodeGen *g, TypeTableEntry *ptr_type) {
    assert(ptr_type->id == TypeTableEntryIdPointer);
    assert(ptr_type->data.pointer.ptr_len == PtrLenUnknown);

    TypeTableEntry **parent_pointer = &ptr_type->data.pointer.slice_parent;
    if (*parent_pointer) {
        return *parent_pointer;
    }

    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdStruct);
    entry->is_copyable = true;

    // replace the & with [] to go from a ptr type name to a slice type name
    buf_resize(&entry->name, 0);
    size_t name_offset = (ptr_type->data.pointer.ptr_len == PtrLenSingle) ? 1 : 3;
    buf_appendf(&entry->name, "[]%s", buf_ptr(&ptr_type->name) + name_offset);

    TypeTableEntry *child_type = ptr_type->data.pointer.child_type;
    uint32_t abi_alignment = get_abi_alignment(g, child_type);
    if (ptr_type->data.pointer.is_const || ptr_type->data.pointer.is_volatile ||
        ptr_type->data.pointer.alignment != abi_alignment)
    {
        TypeTableEntry *peer_ptr_type = get_pointer_to_type_extra(g, child_type, false, false,
                PtrLenUnknown, abi_alignment, 0, 0);
        TypeTableEntry *peer_slice_type = get_slice_type(g, peer_ptr_type);

        slice_type_common_init(g, ptr_type, entry);

        entry->type_ref = peer_slice_type->type_ref;
        entry->di_type = peer_slice_type->di_type;
        entry->data.structure.complete = true;
        entry->data.structure.zero_bits_known = true;
        entry->data.structure.abi_alignment = peer_slice_type->data.structure.abi_alignment;

        *parent_pointer = entry;
        return entry;
    }

    // If the child type is []const T then we need to make sure the type ref
    // and debug info is the same as if the child type were []T.
    if (is_slice(child_type)) {
        TypeTableEntry *child_ptr_type = child_type->data.structure.fields[slice_ptr_index].type_entry;
        assert(child_ptr_type->id == TypeTableEntryIdPointer);
        TypeTableEntry *grand_child_type = child_ptr_type->data.pointer.child_type;
        if (child_ptr_type->data.pointer.is_const || child_ptr_type->data.pointer.is_volatile ||
            child_ptr_type->data.pointer.alignment != get_abi_alignment(g, grand_child_type))
        {
            TypeTableEntry *bland_child_ptr_type = get_pointer_to_type_extra(g, grand_child_type, false, false,
                    PtrLenUnknown, get_abi_alignment(g, grand_child_type), 0, 0);
            TypeTableEntry *bland_child_slice = get_slice_type(g, bland_child_ptr_type);
            TypeTableEntry *peer_ptr_type = get_pointer_to_type_extra(g, bland_child_slice, false, false,
                    PtrLenUnknown, get_abi_alignment(g, bland_child_slice), 0, 0);
            TypeTableEntry *peer_slice_type = get_slice_type(g, peer_ptr_type);

            entry->type_ref = peer_slice_type->type_ref;
            entry->di_type = peer_slice_type->di_type;
            entry->data.structure.abi_alignment = peer_slice_type->data.structure.abi_alignment;
        }
    }

    slice_type_common_init(g, ptr_type, entry);

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

            TypeTableEntry *usize_type = g->builtin_types.entry_usize;
            uint64_t len_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 0);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, entry->type_ref);

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

            entry->data.structure.abi_alignment = LLVMABIAlignmentOfType(g->target_data_ref, usize_type->type_ref);
        } else {
            unsigned element_count = 2;
            LLVMTypeRef element_types[] = {
                ptr_type->type_ref,
                g->builtin_types.entry_usize->type_ref,
            };
            LLVMStructSetBody(entry->type_ref, element_types, element_count, false);


            uint64_t ptr_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, ptr_type->type_ref);
            uint64_t ptr_debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, ptr_type->type_ref);
            uint64_t ptr_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 0);

            TypeTableEntry *usize_type = g->builtin_types.entry_usize;
            uint64_t len_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, usize_type->type_ref);
            uint64_t len_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, entry->type_ref, 1);

            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, entry->type_ref);

            ZigLLVMDIType *di_element_types[] = {
                ZigLLVMCreateDebugMemberType(g->dbuilder, ZigLLVMTypeToScope(entry->di_type),
                        "ptr", di_file, line,
                        ptr_debug_size_in_bits,
                        ptr_debug_align_in_bits,
                        ptr_offset_in_bits,
                        0, ptr_type->di_type),
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

            entry->data.structure.abi_alignment = LLVMABIAlignmentOfType(g->target_data_ref, entry->type_ref);
        }
    }


    entry->data.structure.complete = true;
    entry->data.structure.zero_bits_known = true;

    *parent_pointer = entry;
    return entry;
}

TypeTableEntry *get_opaque_type(CodeGen *g, Scope *scope, AstNode *source_node, const char *name) {
    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdOpaque);

    buf_init_from_str(&entry->name, name);

    ImportTableEntry *import = scope ? get_scope_import(scope) : nullptr;
    unsigned line = source_node ? (unsigned)(source_node->line + 1) : 0;

    entry->is_copyable = false;
    entry->type_ref = LLVMInt8Type();
    entry->di_type = ZigLLVMCreateDebugForwardDeclType(g->dbuilder,
        ZigLLVMTag_DW_structure_type(), buf_ptr(&entry->name),
        import ? ZigLLVMFileToScope(import->di_file) : nullptr,
        import ? import->di_file : nullptr,
        line);
    entry->zero_bits = false;

    return entry;
}

TypeTableEntry *get_bound_fn_type(CodeGen *g, FnTableEntry *fn_entry) {
    TypeTableEntry *fn_type = fn_entry->type_entry;
    assert(fn_type->id == TypeTableEntryIdFn);
    if (fn_type->data.fn.bound_fn_parent)
        return fn_type->data.fn.bound_fn_parent;

    TypeTableEntry *bound_fn_type = new_type_table_entry(TypeTableEntryIdBoundFn);
    bound_fn_type->is_copyable = false;
    bound_fn_type->data.bound_fn.fn_type = fn_type;
    bound_fn_type->zero_bits = true;

    buf_resize(&bound_fn_type->name, 0);
    buf_appendf(&bound_fn_type->name, "(bound %s)", buf_ptr(&fn_type->name));

    fn_type->data.fn.bound_fn_parent = bound_fn_type;
    return bound_fn_type;
}

bool calling_convention_does_first_arg_return(CallingConvention cc) {
    return cc == CallingConventionUnspecified;
}

static const char *calling_convention_name(CallingConvention cc) {
    switch (cc) {
        case CallingConventionUnspecified: return "undefined";
        case CallingConventionC: return "ccc";
        case CallingConventionCold: return "coldcc";
        case CallingConventionNaked: return "nakedcc";
        case CallingConventionStdcall: return "stdcallcc";
        case CallingConventionAsync: return "async";
    }
    zig_unreachable();
}

static const char *calling_convention_fn_type_str(CallingConvention cc) {
    switch (cc) {
        case CallingConventionUnspecified: return "";
        case CallingConventionC: return "extern ";
        case CallingConventionCold: return "coldcc ";
        case CallingConventionNaked: return "nakedcc ";
        case CallingConventionStdcall: return "stdcallcc ";
        case CallingConventionAsync: return "async ";
    }
    zig_unreachable();
}

static bool calling_convention_allows_zig_types(CallingConvention cc) {
    switch (cc) {
        case CallingConventionUnspecified:
        case CallingConventionAsync:
            return true;
        case CallingConventionC:
        case CallingConventionCold:
        case CallingConventionNaked:
        case CallingConventionStdcall:
            return false;
    }
    zig_unreachable();
}

TypeTableEntry *get_ptr_to_stack_trace_type(CodeGen *g) {
    if (g->stack_trace_type == nullptr) {
        ConstExprValue *stack_trace_type_val = get_builtin_value(g, "StackTrace");
        assert(stack_trace_type_val->type->id == TypeTableEntryIdMetaType);
        g->stack_trace_type = stack_trace_type_val->data.x_type;
        g->ptr_to_stack_trace_type = get_pointer_to_type(g, g->stack_trace_type, false);
    }
    return g->ptr_to_stack_trace_type;
}

TypeTableEntry *get_fn_type(CodeGen *g, FnTypeId *fn_type_id) {
    auto table_entry = g->fn_type_table.maybe_get(fn_type_id);
    if (table_entry) {
        return table_entry->value;
    }
    if (fn_type_id->return_type != nullptr) {
        ensure_complete_type(g, fn_type_id->return_type);
        if (type_is_invalid(fn_type_id->return_type))
            return g->builtin_types.entry_invalid;
        assert(fn_type_id->return_type->id != TypeTableEntryIdOpaque);
    } else {
        zig_panic("TODO implement inferred return types https://github.com/ziglang/zig/issues/447");
    }

    TypeTableEntry *fn_type = new_type_table_entry(TypeTableEntryIdFn);
    fn_type->is_copyable = true;
    fn_type->data.fn.fn_type_id = *fn_type_id;

    bool skip_debug_info = false;

    // populate the name of the type
    buf_resize(&fn_type->name, 0);
    if (fn_type->data.fn.fn_type_id.cc == CallingConventionAsync) {
        assert(fn_type_id->async_allocator_type != nullptr);
        buf_appendf(&fn_type->name, "async<%s> ", buf_ptr(&fn_type_id->async_allocator_type->name));
    } else {
        const char *cc_str = calling_convention_fn_type_str(fn_type->data.fn.fn_type_id.cc);
        buf_appendf(&fn_type->name, "%s", cc_str);
    }
    buf_appendf(&fn_type->name, "fn(");
    for (size_t i = 0; i < fn_type_id->param_count; i += 1) {
        FnTypeParamInfo *param_info = &fn_type_id->param_info[i];

        TypeTableEntry *param_type = param_info->type;
        const char *comma = (i == 0) ? "" : ", ";
        const char *noalias_str = param_info->is_noalias ? "noalias " : "";
        buf_appendf(&fn_type->name, "%s%s%s", comma, noalias_str, buf_ptr(&param_type->name));

        skip_debug_info = skip_debug_info || !param_type->di_type;
    }

    if (fn_type_id->is_var_args) {
        const char *comma = (fn_type_id->param_count == 0) ? "" : ", ";
        buf_appendf(&fn_type->name, "%s...", comma);
    }
    buf_appendf(&fn_type->name, ")");
    if (fn_type_id->alignment != 0) {
        buf_appendf(&fn_type->name, " align(%" PRIu32 ")", fn_type_id->alignment);
    }
    buf_appendf(&fn_type->name, " %s", buf_ptr(&fn_type_id->return_type->name));
    skip_debug_info = skip_debug_info || !fn_type_id->return_type->di_type;

    // next, loop over the parameters again and compute debug information
    // and codegen information
    if (!skip_debug_info) {
        bool first_arg_return = calling_convention_does_first_arg_return(fn_type_id->cc) &&
            handle_is_ptr(fn_type_id->return_type);
        bool is_async = fn_type_id->cc == CallingConventionAsync;
        bool prefix_arg_error_return_trace = g->have_err_ret_tracing && fn_type_can_fail(fn_type_id);
        // +1 for maybe making the first argument the return value
        // +1 for maybe first argument the error return trace
        // +2 for maybe arguments async allocator and error code pointer
        LLVMTypeRef *gen_param_types = allocate<LLVMTypeRef>(4 + fn_type_id->param_count);
        // +1 because 0 is the return type and
        // +1 for maybe making first arg ret val and
        // +1 for maybe first argument the error return trace
        // +2 for maybe arguments async allocator and error code pointer
        ZigLLVMDIType **param_di_types = allocate<ZigLLVMDIType*>(5 + fn_type_id->param_count);
        param_di_types[0] = fn_type_id->return_type->di_type;
        size_t gen_param_index = 0;
        TypeTableEntry *gen_return_type;
        if (is_async) {
            gen_return_type = get_pointer_to_type(g, g->builtin_types.entry_u8, false);
        } else if (!type_has_bits(fn_type_id->return_type)) {
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

        if (prefix_arg_error_return_trace) {
            TypeTableEntry *gen_type = get_ptr_to_stack_trace_type(g);
            gen_param_types[gen_param_index] = gen_type->type_ref;
            gen_param_index += 1;
            // after the gen_param_index += 1 because 0 is the return type
            param_di_types[gen_param_index] = gen_type->di_type;
        }
        if (is_async) {
            {
                // async allocator param
                TypeTableEntry *gen_type = fn_type_id->async_allocator_type;
                gen_param_types[gen_param_index] = gen_type->type_ref;
                gen_param_index += 1;
                // after the gen_param_index += 1 because 0 is the return type
                param_di_types[gen_param_index] = gen_type->di_type;
            }

            {
                // error code pointer
                TypeTableEntry *gen_type = get_pointer_to_type(g, g->builtin_types.entry_global_error_set, false);
                gen_param_types[gen_param_index] = gen_type->type_ref;
                gen_param_index += 1;
                // after the gen_param_index += 1 because 0 is the return type
                param_di_types[gen_param_index] = gen_type->di_type;
            }
        }

        fn_type->data.fn.gen_param_info = allocate<FnGenParamInfo>(fn_type_id->param_count);
        for (size_t i = 0; i < fn_type_id->param_count; i += 1) {
            FnTypeParamInfo *src_param_info = &fn_type->data.fn.fn_type_id.param_info[i];
            TypeTableEntry *type_entry = src_param_info->type;
            FnGenParamInfo *gen_param_info = &fn_type->data.fn.gen_param_info[i];

            gen_param_info->src_index = i;
            gen_param_info->gen_index = SIZE_MAX;

            ensure_complete_type(g, type_entry);
            if (type_is_invalid(type_entry))
                return g->builtin_types.entry_invalid;

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
                gen_param_types, (unsigned int)gen_param_index, fn_type_id->is_var_args);
        fn_type->type_ref = LLVMPointerType(fn_type->data.fn.raw_type_ref, 0);
        fn_type->di_type = ZigLLVMCreateSubroutineType(g->dbuilder, param_di_types, (int)(gen_param_index + 1), 0);
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

TypeTableEntry *get_partial_container_type(CodeGen *g, Scope *scope, ContainerKind kind,
        AstNode *decl_node, const char *name, ContainerLayout layout)
{
    TypeTableEntryId type_id = container_to_type(kind);
    TypeTableEntry *entry = new_container_type_entry(type_id, decl_node, scope);

    switch (kind) {
        case ContainerKindStruct:
            entry->data.structure.decl_node = decl_node;
            entry->data.structure.layout = layout;
            break;
        case ContainerKindEnum:
            entry->data.enumeration.decl_node = decl_node;
            entry->data.enumeration.layout = layout;
            break;
        case ContainerKindUnion:
            entry->data.unionation.decl_node = decl_node;
            entry->data.unionation.layout = layout;
            break;
    }

    size_t line = decl_node ? decl_node->line : 0;
    unsigned dwarf_kind = ZigLLVMTag_DW_structure_type();

    ImportTableEntry *import = get_scope_import(scope);
    entry->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), name);
    entry->di_type = ZigLLVMCreateReplaceableCompositeType(g->dbuilder,
        dwarf_kind, name,
        ZigLLVMFileToScope(import->di_file), import->di_file, (unsigned)(line + 1));

    buf_init_from_str(&entry->name, name);

    return entry;
}

static IrInstruction *analyze_const_value(CodeGen *g, Scope *scope, AstNode *node, TypeTableEntry *type_entry, Buf *type_name) {
    size_t backward_branch_count = 0;
    return ir_eval_const_value(g, scope, node, type_entry,
            &backward_branch_count, default_backward_branch_quota,
            nullptr, nullptr, node, type_name, nullptr);
}

TypeTableEntry *analyze_type_expr(CodeGen *g, Scope *scope, AstNode *node) {
    IrInstruction *result = analyze_const_value(g, scope, node, g->builtin_types.entry_type, nullptr);
    if (result->value.type->id == TypeTableEntryIdInvalid)
        return g->builtin_types.entry_invalid;

    assert(result->value.special != ConstValSpecialRuntime);
    return result->value.data.x_type;
}

TypeTableEntry *get_generic_fn_type(CodeGen *g, FnTypeId *fn_type_id) {
    TypeTableEntry *fn_type = new_type_table_entry(TypeTableEntryIdFn);
    fn_type->is_copyable = false;
    buf_resize(&fn_type->name, 0);
    if (fn_type->data.fn.fn_type_id.cc == CallingConventionAsync) {
        const char *async_allocator_type_str = (fn_type->data.fn.fn_type_id.async_allocator_type == nullptr) ?
            "var" : buf_ptr(&fn_type_id->async_allocator_type->name);
        buf_appendf(&fn_type->name, "async(%s) ", async_allocator_type_str);
    } else {
        const char *cc_str = calling_convention_fn_type_str(fn_type->data.fn.fn_type_id.cc);
        buf_appendf(&fn_type->name, "%s", cc_str);
    }
    buf_appendf(&fn_type->name, "fn(");
    size_t i = 0;
    for (; i < fn_type_id->next_param_index; i += 1) {
        const char *comma_str = (i == 0) ? "" : ",";
        buf_appendf(&fn_type->name, "%s%s", comma_str,
            buf_ptr(&fn_type_id->param_info[i].type->name));
    }
    for (; i < fn_type_id->param_count; i += 1) {
        const char *comma_str = (i == 0) ? "" : ",";
        buf_appendf(&fn_type->name, "%svar", comma_str);
    }
    buf_appendf(&fn_type->name, ")var");

    fn_type->data.fn.fn_type_id = *fn_type_id;
    fn_type->data.fn.is_generic = true;
    fn_type->zero_bits = true;
    return fn_type;
}

void init_fn_type_id(FnTypeId *fn_type_id, AstNode *proto_node, size_t param_count_alloc) {
    assert(proto_node->type == NodeTypeFnProto);
    AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

    if (fn_proto->cc == CallingConventionUnspecified) {
        bool extern_abi = fn_proto->is_extern || fn_proto->is_export;
        fn_type_id->cc = extern_abi ? CallingConventionC : CallingConventionUnspecified;
    } else {
        fn_type_id->cc = fn_proto->cc;
    }

    fn_type_id->param_count = fn_proto->params.length;
    fn_type_id->param_info = allocate<FnTypeParamInfo>(param_count_alloc);
    fn_type_id->next_param_index = 0;
    fn_type_id->is_var_args = fn_proto->is_var_args;
}

static bool analyze_const_align(CodeGen *g, Scope *scope, AstNode *node, uint32_t *result) {
    IrInstruction *align_result = analyze_const_value(g, scope, node, get_align_amt_type(g), nullptr);
    if (type_is_invalid(align_result->value.type))
        return false;

    uint32_t align_bytes = bigint_as_unsigned(&align_result->value.data.x_bigint);
    if (align_bytes == 0) {
        add_node_error(g, node, buf_sprintf("alignment must be >= 1"));
        return false;
    }
    if (!is_power_of_2(align_bytes)) {
        add_node_error(g, node, buf_sprintf("alignment value %" PRIu32 " is not a power of 2", align_bytes));
        return false;
    }

    *result = align_bytes;
    return true;
}

static bool analyze_const_string(CodeGen *g, Scope *scope, AstNode *node, Buf **out_buffer) {
    TypeTableEntry *ptr_type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0);
    TypeTableEntry *str_type = get_slice_type(g, ptr_type);
    IrInstruction *instr = analyze_const_value(g, scope, node, str_type, nullptr);
    if (type_is_invalid(instr->value.type))
        return false;

    ConstExprValue *ptr_field = &instr->value.data.x_struct.fields[slice_ptr_index];
    ConstExprValue *len_field = &instr->value.data.x_struct.fields[slice_len_index];

    assert(ptr_field->data.x_ptr.special == ConstPtrSpecialBaseArray);
    ConstExprValue *array_val = ptr_field->data.x_ptr.data.base_array.array_val;
    expand_undef_array(g, array_val);
    size_t len = bigint_as_unsigned(&len_field->data.x_bigint);
    Buf *result = buf_alloc();
    buf_resize(result, len);
    for (size_t i = 0; i < len; i += 1) {
        size_t new_index = ptr_field->data.x_ptr.data.base_array.elem_index + i;
        ConstExprValue *char_val = &array_val->data.x_array.s_none.elements[new_index];
        if (char_val->special == ConstValSpecialUndef) {
            add_node_error(g, node, buf_sprintf("use of undefined value"));
            return false;
        }
        uint64_t big_c = bigint_as_unsigned(&char_val->data.x_bigint);
        assert(big_c <= UINT8_MAX);
        uint8_t c = (uint8_t)big_c;
        buf_ptr(result)[i] = c;
    }
    *out_buffer = result;
    return true;
}

static bool type_allowed_in_packed_struct(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdPromise:
            return false;
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdFn:
            return true;
        case TypeTableEntryIdStruct:
            return type_entry->data.structure.layout == ContainerLayoutPacked;
        case TypeTableEntryIdUnion:
            return type_entry->data.unionation.layout == ContainerLayoutPacked;
        case TypeTableEntryIdOptional:
            {
                TypeTableEntry *child_type = type_entry->data.maybe.child_type;
                return type_is_codegen_pointer(child_type);
            }
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.decl_node->data.container_decl.init_arg_expr != nullptr;
    }
    zig_unreachable();
}

static bool type_allowed_in_extern(CodeGen *g, TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdPromise:
            return false;
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
            return true;
        case TypeTableEntryIdInt:
            switch (type_entry->data.integral.bit_count) {
                case 8:
                case 16:
                case 32:
                case 64:
                case 128:
                    return true;
                default:
                    return false;
            }
        case TypeTableEntryIdFloat:
            return true;
        case TypeTableEntryIdArray:
            return type_allowed_in_extern(g, type_entry->data.array.child_type);
        case TypeTableEntryIdFn:
            return type_entry->data.fn.fn_type_id.cc == CallingConventionC;
        case TypeTableEntryIdPointer:
            return type_allowed_in_extern(g, type_entry->data.pointer.child_type);
        case TypeTableEntryIdStruct:
            return type_entry->data.structure.layout == ContainerLayoutExtern || type_entry->data.structure.layout == ContainerLayoutPacked;
        case TypeTableEntryIdOptional:
            {
                TypeTableEntry *child_type = type_entry->data.maybe.child_type;
                return child_type->id == TypeTableEntryIdPointer || child_type->id == TypeTableEntryIdFn;
            }
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.layout == ContainerLayoutExtern || type_entry->data.enumeration.layout == ContainerLayoutPacked;
        case TypeTableEntryIdUnion:
            return type_entry->data.unionation.layout == ContainerLayoutExtern || type_entry->data.unionation.layout == ContainerLayoutPacked;
    }
    zig_unreachable();
}

TypeTableEntry *get_auto_err_set_type(CodeGen *g, FnTableEntry *fn_entry) {
    TypeTableEntry *err_set_type = new_type_table_entry(TypeTableEntryIdErrorSet);
    buf_resize(&err_set_type->name, 0);
    buf_appendf(&err_set_type->name, "@typeOf(%s).ReturnType.ErrorSet", buf_ptr(&fn_entry->symbol_name));
    err_set_type->is_copyable = true;
    err_set_type->type_ref = g->builtin_types.entry_global_error_set->type_ref;
    err_set_type->di_type = g->builtin_types.entry_global_error_set->di_type;
    err_set_type->data.error_set.err_count = 0;
    err_set_type->data.error_set.errors = nullptr;
    err_set_type->data.error_set.infer_fn = fn_entry;

    g->error_di_types.append(&err_set_type->di_type);

    return err_set_type;
}

static TypeTableEntry *analyze_fn_type(CodeGen *g, AstNode *proto_node, Scope *child_scope, FnTableEntry *fn_entry) {
    assert(proto_node->type == NodeTypeFnProto);
    AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

    FnTypeId fn_type_id = {0};
    init_fn_type_id(&fn_type_id, proto_node, proto_node->data.fn_proto.params.length);

    for (; fn_type_id.next_param_index < fn_type_id.param_count; fn_type_id.next_param_index += 1) {
        AstNode *param_node = fn_proto->params.at(fn_type_id.next_param_index);
        assert(param_node->type == NodeTypeParamDecl);

        bool param_is_comptime = param_node->data.param_decl.is_inline;
        bool param_is_var_args = param_node->data.param_decl.is_var_args;

        if (param_is_comptime) {
            if (!calling_convention_allows_zig_types(fn_type_id.cc)) {
                add_node_error(g, param_node,
                        buf_sprintf("comptime parameter not allowed in function with calling convention '%s'",
                            calling_convention_name(fn_type_id.cc)));
                return g->builtin_types.entry_invalid;
            }
            if (param_node->data.param_decl.type != nullptr) {
                TypeTableEntry *type_entry = analyze_type_expr(g, child_scope, param_node->data.param_decl.type);
                if (type_is_invalid(type_entry)) {
                    return g->builtin_types.entry_invalid;
                }
                FnTypeParamInfo *param_info = &fn_type_id.param_info[fn_type_id.next_param_index];
                param_info->type = type_entry;
                param_info->is_noalias = param_node->data.param_decl.is_noalias;
                fn_type_id.next_param_index += 1;
            }

            return get_generic_fn_type(g, &fn_type_id);
        } else if (param_is_var_args) {
            if (fn_type_id.cc == CallingConventionC) {
                fn_type_id.param_count = fn_type_id.next_param_index;
                continue;
            } else if (calling_convention_allows_zig_types(fn_type_id.cc)) {
                return get_generic_fn_type(g, &fn_type_id);
            } else {
                add_node_error(g, param_node,
                        buf_sprintf("var args not allowed in function with calling convention '%s'",
                            calling_convention_name(fn_type_id.cc)));
                return g->builtin_types.entry_invalid;
            }
        } else if (param_node->data.param_decl.var_token != nullptr) {
            if (!calling_convention_allows_zig_types(fn_type_id.cc)) {
                add_node_error(g, param_node->data.param_decl.type,
                        buf_sprintf("parameter of type 'var' not allowed in function with calling convention '%s'",
                            calling_convention_name(fn_type_id.cc)));
                return g->builtin_types.entry_invalid;
            }
            return get_generic_fn_type(g, &fn_type_id);
        }

        TypeTableEntry *type_entry = analyze_type_expr(g, child_scope, param_node->data.param_decl.type);
        if (type_is_invalid(type_entry)) {
            return g->builtin_types.entry_invalid;
        }
        if (!calling_convention_allows_zig_types(fn_type_id.cc)) {
            type_ensure_zero_bits_known(g, type_entry);
            if (!type_has_bits(type_entry)) {
                add_node_error(g, param_node->data.param_decl.type,
                    buf_sprintf("parameter of type '%s' has 0 bits; not allowed in function with calling convention '%s'",
                        buf_ptr(&type_entry->name), calling_convention_name(fn_type_id.cc)));
                return g->builtin_types.entry_invalid;
            }
        }

        if (!calling_convention_allows_zig_types(fn_type_id.cc) && !type_allowed_in_extern(g, type_entry)) {
            add_node_error(g, param_node->data.param_decl.type,
                    buf_sprintf("parameter of type '%s' not allowed in function with calling convention '%s'",
                        buf_ptr(&type_entry->name),
                        calling_convention_name(fn_type_id.cc)));
            return g->builtin_types.entry_invalid;
        }

        switch (type_entry->id) {
            case TypeTableEntryIdInvalid:
                return g->builtin_types.entry_invalid;
            case TypeTableEntryIdUnreachable:
            case TypeTableEntryIdUndefined:
            case TypeTableEntryIdNull:
            case TypeTableEntryIdArgTuple:
            case TypeTableEntryIdOpaque:
                add_node_error(g, param_node->data.param_decl.type,
                    buf_sprintf("parameter of type '%s' not allowed", buf_ptr(&type_entry->name)));
                return g->builtin_types.entry_invalid;
            case TypeTableEntryIdComptimeFloat:
            case TypeTableEntryIdComptimeInt:
            case TypeTableEntryIdNamespace:
            case TypeTableEntryIdBlock:
            case TypeTableEntryIdBoundFn:
            case TypeTableEntryIdMetaType:
                add_node_error(g, param_node->data.param_decl.type,
                    buf_sprintf("parameter of type '%s' must be declared comptime",
                    buf_ptr(&type_entry->name)));
                return g->builtin_types.entry_invalid;
            case TypeTableEntryIdVoid:
            case TypeTableEntryIdBool:
            case TypeTableEntryIdInt:
            case TypeTableEntryIdFloat:
            case TypeTableEntryIdPointer:
            case TypeTableEntryIdArray:
            case TypeTableEntryIdStruct:
            case TypeTableEntryIdOptional:
            case TypeTableEntryIdErrorUnion:
            case TypeTableEntryIdErrorSet:
            case TypeTableEntryIdEnum:
            case TypeTableEntryIdUnion:
            case TypeTableEntryIdFn:
            case TypeTableEntryIdPromise:
                break;
        }
        FnTypeParamInfo *param_info = &fn_type_id.param_info[fn_type_id.next_param_index];
        param_info->type = type_entry;
        param_info->is_noalias = param_node->data.param_decl.is_noalias;
    }

    if (fn_proto->align_expr != nullptr) {
        if (!analyze_const_align(g, child_scope, fn_proto->align_expr, &fn_type_id.alignment)) {
            return g->builtin_types.entry_invalid;
        }
    }

    if (fn_proto->return_var_token != nullptr) {
        if (!calling_convention_allows_zig_types(fn_type_id.cc)) {
            add_node_error(g, fn_proto->return_type,
                buf_sprintf("return type 'var' not allowed in function with calling convention '%s'",
                calling_convention_name(fn_type_id.cc)));
            return g->builtin_types.entry_invalid;
        }
        add_node_error(g, proto_node,
            buf_sprintf("TODO implement inferred return types https://github.com/ziglang/zig/issues/447"));
        return g->builtin_types.entry_invalid;
        //return get_generic_fn_type(g, &fn_type_id);
    }

    TypeTableEntry *specified_return_type = analyze_type_expr(g, child_scope, fn_proto->return_type);
    if (type_is_invalid(specified_return_type)) {
        fn_type_id.return_type = g->builtin_types.entry_invalid;
        return g->builtin_types.entry_invalid;
    }

    if (fn_proto->auto_err_set) {
        TypeTableEntry *inferred_err_set_type = get_auto_err_set_type(g, fn_entry);
        fn_type_id.return_type = get_error_union_type(g, inferred_err_set_type, specified_return_type);
    } else {
        fn_type_id.return_type = specified_return_type;
    }

    if (!calling_convention_allows_zig_types(fn_type_id.cc) && !type_allowed_in_extern(g, fn_type_id.return_type)) {
        add_node_error(g, fn_proto->return_type,
                buf_sprintf("return type '%s' not allowed in function with calling convention '%s'",
                    buf_ptr(&fn_type_id.return_type->name),
                    calling_convention_name(fn_type_id.cc)));
        return g->builtin_types.entry_invalid;
    }

    switch (fn_type_id.return_type->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();

        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
            add_node_error(g, fn_proto->return_type,
                buf_sprintf("return type '%s' not allowed", buf_ptr(&fn_type_id.return_type->name)));
            return g->builtin_types.entry_invalid;

        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdMetaType:
            if (!calling_convention_allows_zig_types(fn_type_id.cc)) {
                add_node_error(g, fn_proto->return_type,
                    buf_sprintf("return type '%s' not allowed in function with calling convention '%s'",
                    buf_ptr(&fn_type_id.return_type->name),
                    calling_convention_name(fn_type_id.cc)));
                return g->builtin_types.entry_invalid;
            }
            return get_generic_fn_type(g, &fn_type_id);
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdPromise:
            break;
    }

    if (fn_type_id.cc == CallingConventionAsync) {
        if (fn_proto->async_allocator_type == nullptr) {
            return get_generic_fn_type(g, &fn_type_id);
        }
        fn_type_id.async_allocator_type = analyze_type_expr(g, child_scope, fn_proto->async_allocator_type);
        if (type_is_invalid(fn_type_id.async_allocator_type)) {
            return g->builtin_types.entry_invalid;
        }
    }

    return get_fn_type(g, &fn_type_id);
}

bool type_is_invalid(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            return true;
        case TypeTableEntryIdStruct:
            return type_entry->data.structure.is_invalid;
        case TypeTableEntryIdEnum:
            return type_entry->data.enumeration.is_invalid;
        case TypeTableEntryIdUnion:
            return type_entry->data.unionation.is_invalid;
        default:
            return false;
    }
    zig_unreachable();
}


static void resolve_enum_type(CodeGen *g, TypeTableEntry *enum_type) {
    assert(enum_type->id == TypeTableEntryIdEnum);

    if (enum_type->data.enumeration.complete)
        return;

    resolve_enum_zero_bits(g, enum_type);
    if (type_is_invalid(enum_type))
        return;

    AstNode *decl_node = enum_type->data.enumeration.decl_node;

    if (enum_type->data.enumeration.embedded_in_current) {
        if (!enum_type->data.enumeration.reported_infinite_err) {
            enum_type->data.enumeration.reported_infinite_err = true;
            add_node_error(g, decl_node, buf_sprintf("enum '%s' contains itself", buf_ptr(&enum_type->name)));
        }
        return;
    }

    assert(!enum_type->data.enumeration.zero_bits_loop_flag);
    assert(decl_node->type == NodeTypeContainerDecl);
    assert(enum_type->di_type);

    uint32_t field_count = enum_type->data.enumeration.src_field_count;

    assert(enum_type->data.enumeration.fields);
    ZigLLVMDIEnumerator **di_enumerators = allocate<ZigLLVMDIEnumerator*>(field_count);

    Scope *scope = &enum_type->data.enumeration.decls_scope->base;
    ImportTableEntry *import = get_scope_import(scope);

    // set temporary flag
    enum_type->data.enumeration.embedded_in_current = true;

    for (uint32_t i = 0; i < field_count; i += 1) {
        TypeEnumField *enum_field = &enum_type->data.enumeration.fields[i];

        // TODO send patch to LLVM to support APInt in createEnumerator instead of int64_t
        // http://lists.llvm.org/pipermail/llvm-dev/2017-December/119456.html
        di_enumerators[i] = ZigLLVMCreateDebugEnumerator(g->dbuilder, buf_ptr(enum_field->name),
                bigint_as_signed(&enum_field->value));
    }

    // unset temporary flag
    enum_type->data.enumeration.embedded_in_current = false;
    enum_type->data.enumeration.complete = true;

    if (enum_type->data.enumeration.is_invalid)
        return;

    if (enum_type->zero_bits) {
        enum_type->type_ref = LLVMVoidType();

        uint64_t debug_size_in_bits = 0;
        uint64_t debug_align_in_bits = 0;
        ZigLLVMDIType **di_root_members = nullptr;
        size_t debug_member_count = 0;
        ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
                ZigLLVMFileToScope(import->di_file),
                buf_ptr(&enum_type->name),
                import->di_file, (unsigned)(decl_node->line + 1),
                debug_size_in_bits,
                debug_align_in_bits,
                0, nullptr, di_root_members, (int)debug_member_count, 0, nullptr, "");

        ZigLLVMReplaceTemporary(g->dbuilder, enum_type->di_type, replacement_di_type);
        enum_type->di_type = replacement_di_type;
        return;
    }

    TypeTableEntry *tag_int_type = enum_type->data.enumeration.tag_int_type;

    // create debug type for tag
    uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, tag_int_type->type_ref);
    uint64_t tag_debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, tag_int_type->type_ref);
    ZigLLVMDIType *tag_di_type = ZigLLVMCreateDebugEnumerationType(g->dbuilder,
            ZigLLVMFileToScope(import->di_file), buf_ptr(&enum_type->name),
            import->di_file, (unsigned)(decl_node->line + 1),
            tag_debug_size_in_bits,
            tag_debug_align_in_bits,
            di_enumerators, field_count,
            tag_int_type->di_type, "");

    ZigLLVMReplaceTemporary(g->dbuilder, enum_type->di_type, tag_di_type);
    enum_type->di_type = tag_di_type;
}


TypeTableEntry *get_struct_type(CodeGen *g, const char *type_name, const char *field_names[],
        TypeTableEntry *field_types[], size_t field_count)
{
    TypeTableEntry *struct_type = new_type_table_entry(TypeTableEntryIdStruct);

    buf_init_from_str(&struct_type->name, type_name);

    struct_type->data.structure.src_field_count = field_count;
    struct_type->data.structure.gen_field_count = 0;
    struct_type->data.structure.zero_bits_known = true;
    struct_type->data.structure.complete = true;
    struct_type->data.structure.fields = allocate<TypeStructField>(field_count);
    struct_type->data.structure.fields_by_name.init(field_count);

    ZigLLVMDIType **di_element_types = allocate<ZigLLVMDIType*>(field_count);
    LLVMTypeRef *element_types = allocate<LLVMTypeRef>(field_count);
    for (size_t i = 0; i < field_count; i += 1) {
        element_types[struct_type->data.structure.gen_field_count] = field_types[i]->type_ref;

        TypeStructField *field = &struct_type->data.structure.fields[i];
        field->name = buf_create_from_str(field_names[i]);
        field->type_entry = field_types[i];
        field->src_index = i;

        if (type_has_bits(field->type_entry)) {
            field->gen_index = struct_type->data.structure.gen_field_count;
            struct_type->data.structure.gen_field_count += 1;
        } else {
            field->gen_index = SIZE_MAX;
        }

        auto prev_entry = struct_type->data.structure.fields_by_name.put_unique(field->name, field);
        assert(prev_entry == nullptr);
    }

    struct_type->type_ref = LLVMStructCreateNamed(LLVMGetGlobalContext(), type_name);
    LLVMStructSetBody(struct_type->type_ref, element_types, struct_type->data.structure.gen_field_count, false);

    struct_type->di_type = ZigLLVMCreateReplaceableCompositeType(g->dbuilder,
        ZigLLVMTag_DW_structure_type(), type_name,
        ZigLLVMCompileUnitToScope(g->compile_unit), nullptr, 0);

    for (size_t i = 0; i < field_count; i += 1) {
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        if (type_struct_field->gen_index == SIZE_MAX) {
            continue;
        }
        TypeTableEntry *field_type = type_struct_field->type_entry;
        uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, field_type->type_ref);
        uint64_t debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, field_type->type_ref);
        uint64_t debug_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, struct_type->type_ref, type_struct_field->gen_index);
        di_element_types[type_struct_field->gen_index] = ZigLLVMCreateDebugMemberType(g->dbuilder,
                ZigLLVMTypeToScope(struct_type->di_type), buf_ptr(type_struct_field->name),
                nullptr, 0,
                debug_size_in_bits,
                debug_align_in_bits,
                debug_offset_in_bits,
                0, field_type->di_type);

        assert(di_element_types[type_struct_field->gen_index]);
    }

    uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, struct_type->type_ref);
    uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, struct_type->type_ref);
    ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
            ZigLLVMCompileUnitToScope(g->compile_unit),
            type_name, nullptr, 0,
            debug_size_in_bits,
            debug_align_in_bits,
            0,
            nullptr, di_element_types, struct_type->data.structure.gen_field_count, 0, nullptr, "");

    ZigLLVMReplaceTemporary(g->dbuilder, struct_type->di_type, replacement_di_type);
    struct_type->di_type = replacement_di_type;
    struct_type->data.structure.abi_alignment = LLVMABIAlignmentOfType(g->target_data_ref, struct_type->type_ref);

    return struct_type;
}

static void resolve_struct_type(CodeGen *g, TypeTableEntry *struct_type) {
    assert(struct_type->id == TypeTableEntryIdStruct);

    if (struct_type->data.structure.complete)
        return;

    resolve_struct_zero_bits(g, struct_type);
    if (struct_type->data.structure.is_invalid)
        return;

    AstNode *decl_node = struct_type->data.structure.decl_node;

    if (struct_type->data.structure.embedded_in_current) {
        struct_type->data.structure.is_invalid = true;
        if (!struct_type->data.structure.reported_infinite_err) {
            struct_type->data.structure.reported_infinite_err = true;
            add_node_error(g, decl_node,
                    buf_sprintf("struct '%s' contains itself", buf_ptr(&struct_type->name)));
        }
        return;
    }

    assert(!struct_type->data.structure.zero_bits_loop_flag);
    assert(struct_type->data.structure.fields || struct_type->data.structure.src_field_count == 0);
    assert(decl_node->type == NodeTypeContainerDecl);

    size_t field_count = struct_type->data.structure.src_field_count;

    size_t gen_field_count = struct_type->data.structure.gen_field_count;
    LLVMTypeRef *element_types = allocate<LLVMTypeRef>(gen_field_count);

    // this field should be set to true only during the recursive calls to resolve_struct_type
    struct_type->data.structure.embedded_in_current = true;

    Scope *scope = &struct_type->data.structure.decls_scope->base;

    size_t gen_field_index = 0;
    bool packed = (struct_type->data.structure.layout == ContainerLayoutPacked);
    size_t packed_bits_offset = 0;
    size_t first_packed_bits_offset_misalign = SIZE_MAX;
    size_t debug_field_count = 0;

    for (size_t i = 0; i < field_count; i += 1) {
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        TypeTableEntry *field_type = type_struct_field->type_entry;

        ensure_complete_type(g, field_type);
        if (type_is_invalid(field_type)) {
            struct_type->data.structure.is_invalid = true;
            break;
        }

        if (!type_has_bits(field_type))
            continue;

        type_struct_field->gen_index = gen_field_index;

        if (packed) {
            if (!type_allowed_in_packed_struct(field_type)) {
                AstNode *field_source_node = decl_node->data.container_decl.fields.at(i);
                add_node_error(g, field_source_node,
                        buf_sprintf("packed structs cannot contain fields of type '%s'",
                            buf_ptr(&field_type->name)));
                struct_type->data.structure.is_invalid = true;
                break;
            }

            size_t field_size_in_bits = type_size_bits(g, field_type);
            size_t next_packed_bits_offset = packed_bits_offset + field_size_in_bits;

            type_struct_field->packed_bits_size = field_size_in_bits;

            if (first_packed_bits_offset_misalign != SIZE_MAX) {
                // this field is not byte-aligned; it is part of the previous field with a bit offset
                type_struct_field->packed_bits_offset = packed_bits_offset - first_packed_bits_offset_misalign;
                type_struct_field->unaligned_bit_count = field_size_in_bits;

                size_t full_bit_count = next_packed_bits_offset - first_packed_bits_offset_misalign;
                LLVMTypeRef int_type_ref = LLVMIntType((unsigned)(full_bit_count));
                if (8 * LLVMStoreSizeOfType(g->target_data_ref, int_type_ref) == full_bit_count) {
                    // next field recovers store alignment
                    element_types[gen_field_index] = int_type_ref;
                    gen_field_index += 1;

                    first_packed_bits_offset_misalign = SIZE_MAX;
                }
            } else if (8 * LLVMStoreSizeOfType(g->target_data_ref, field_type->type_ref) != field_size_in_bits) {
                first_packed_bits_offset_misalign = packed_bits_offset;
                type_struct_field->packed_bits_offset = 0;
                type_struct_field->unaligned_bit_count = field_size_in_bits;
            } else {
                // This is a byte-aligned field (both start and end) in a packed struct.
                element_types[gen_field_index] = field_type->type_ref;
                type_struct_field->packed_bits_offset = 0;
                type_struct_field->unaligned_bit_count = 0;
                gen_field_index += 1;
            }
            packed_bits_offset = next_packed_bits_offset;
        } else {
            element_types[gen_field_index] = field_type->type_ref;
            assert(element_types[gen_field_index]);

            gen_field_index += 1;
        }
        debug_field_count += 1;
    }
    if (first_packed_bits_offset_misalign != SIZE_MAX) {
        size_t full_bit_count = packed_bits_offset - first_packed_bits_offset_misalign;
        LLVMTypeRef int_type_ref = LLVMIntType((unsigned)full_bit_count);
        size_t store_bit_count = 8 * LLVMStoreSizeOfType(g->target_data_ref, int_type_ref);
        element_types[gen_field_index] = LLVMIntType((unsigned)store_bit_count);
        gen_field_index += 1;
    }

    struct_type->data.structure.embedded_in_current = false;
    struct_type->data.structure.complete = true;

    if (struct_type->data.structure.is_invalid)
        return;

    if (struct_type->zero_bits) {
        struct_type->type_ref = LLVMVoidType();

        ImportTableEntry *import = get_scope_import(scope);
        uint64_t debug_size_in_bits = 0;
        uint64_t debug_align_in_bits = 0;
        ZigLLVMDIType **di_element_types = nullptr;
        size_t debug_field_count = 0;
        ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
                ZigLLVMFileToScope(import->di_file),
                buf_ptr(&struct_type->name),
                import->di_file, (unsigned)(decl_node->line + 1),
                debug_size_in_bits,
                debug_align_in_bits,
                0, nullptr, di_element_types, (int)debug_field_count, 0, nullptr, "");
        ZigLLVMReplaceTemporary(g->dbuilder, struct_type->di_type, replacement_di_type);
        struct_type->di_type = replacement_di_type;
        return;
    }
    assert(struct_type->di_type);


    // the count may have been adjusting from packing bit fields
    gen_field_count = gen_field_index;
    struct_type->data.structure.gen_field_count = (uint32_t)gen_field_count;

    LLVMStructSetBody(struct_type->type_ref, element_types, (unsigned)gen_field_count, packed);

    // if you hit this assert then probably this type or a related type didn't
    // get ensure_complete_type called on it before using it with something that
    // requires a complete type
    assert(LLVMStoreSizeOfType(g->target_data_ref, struct_type->type_ref) > 0);

    ZigLLVMDIType **di_element_types = allocate<ZigLLVMDIType*>(debug_field_count);

    ImportTableEntry *import = get_scope_import(scope);
    size_t debug_field_index = 0;
    for (size_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.container_decl.fields.at(i);
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        size_t gen_field_index = type_struct_field->gen_index;
        if (gen_field_index == SIZE_MAX) {
            continue;
        }

        TypeTableEntry *field_type = type_struct_field->type_entry;

        // if the field is a function, actually the debug info should be a pointer.
        ZigLLVMDIType *field_di_type;
        if (field_type->id == TypeTableEntryIdFn) {
            TypeTableEntry *field_ptr_type = get_pointer_to_type(g, field_type, true);
            uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, field_ptr_type->type_ref);
            uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, field_ptr_type->type_ref);
            field_di_type = ZigLLVMCreateDebugPointerType(g->dbuilder, field_type->di_type,
                    debug_size_in_bits, debug_align_in_bits, buf_ptr(&field_ptr_type->name));
        } else {
            field_di_type = field_type->di_type;
        }

        assert(field_type->type_ref);
        assert(struct_type->type_ref);
        assert(struct_type->data.structure.complete);
        uint64_t debug_size_in_bits;
        uint64_t debug_align_in_bits;
        uint64_t debug_offset_in_bits;
        if (packed) {
            debug_size_in_bits = type_struct_field->packed_bits_size;
            debug_align_in_bits = 1;
            debug_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, struct_type->type_ref,
                    (unsigned)gen_field_index) + type_struct_field->packed_bits_offset;
        } else {
            debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, field_type->type_ref);
            debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, field_type->type_ref);
            debug_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, struct_type->type_ref,
                    (unsigned)gen_field_index);
        }
        di_element_types[debug_field_index] = ZigLLVMCreateDebugMemberType(g->dbuilder,
                ZigLLVMTypeToScope(struct_type->di_type), buf_ptr(type_struct_field->name),
                import->di_file, (unsigned)(field_node->line + 1),
                debug_size_in_bits,
                debug_align_in_bits,
                debug_offset_in_bits,
                0, field_di_type);
        assert(di_element_types[debug_field_index]);
        debug_field_index += 1;
    }


    uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, struct_type->type_ref);
    uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, struct_type->type_ref);
    ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
            ZigLLVMFileToScope(import->di_file),
            buf_ptr(&struct_type->name),
            import->di_file, (unsigned)(decl_node->line + 1),
            debug_size_in_bits,
            debug_align_in_bits,
            0, nullptr, di_element_types, (int)debug_field_count, 0, nullptr, "");

    ZigLLVMReplaceTemporary(g->dbuilder, struct_type->di_type, replacement_di_type);
    struct_type->di_type = replacement_di_type;
}

static void resolve_union_type(CodeGen *g, TypeTableEntry *union_type) {
    assert(union_type->id == TypeTableEntryIdUnion);

    if (union_type->data.unionation.complete)
        return;

    resolve_union_zero_bits(g, union_type);
    if (type_is_invalid(union_type))
        return;

    AstNode *decl_node = union_type->data.unionation.decl_node;

    if (union_type->data.unionation.embedded_in_current) {
        if (!union_type->data.unionation.reported_infinite_err) {
            union_type->data.unionation.reported_infinite_err = true;
            union_type->data.unionation.is_invalid = true;
            add_node_error(g, decl_node, buf_sprintf("union '%s' contains itself", buf_ptr(&union_type->name)));
        }
        return;
    }

    assert(!union_type->data.unionation.zero_bits_loop_flag);
    assert(decl_node->type == NodeTypeContainerDecl);
    assert(union_type->di_type);

    uint32_t field_count = union_type->data.unionation.src_field_count;

    assert(union_type->data.unionation.fields);

    uint32_t gen_field_count = union_type->data.unionation.gen_field_count;
    ZigLLVMDIType **union_inner_di_types = allocate<ZigLLVMDIType*>(gen_field_count);

    TypeTableEntry *most_aligned_union_member = nullptr;
    uint64_t size_of_most_aligned_member_in_bits = 0;
    uint64_t biggest_align_in_bits = 0;
    uint64_t biggest_size_in_bits = 0;

    Scope *scope = &union_type->data.unionation.decls_scope->base;
    ImportTableEntry *import = get_scope_import(scope);

    // set temporary flag
    union_type->data.unionation.embedded_in_current = true;


    for (uint32_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.container_decl.fields.at(i);
        TypeUnionField *union_field = &union_type->data.unionation.fields[i];
        TypeTableEntry *field_type = union_field->type_entry;

        ensure_complete_type(g, field_type);
        if (type_is_invalid(field_type)) {
            union_type->data.unionation.is_invalid = true;
            continue;
        }

        if (!type_has_bits(field_type))
            continue;

        uint64_t store_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, field_type->type_ref);
        uint64_t abi_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, field_type->type_ref);

        assert(store_size_in_bits > 0);
        assert(abi_align_in_bits > 0);

        union_inner_di_types[union_field->gen_index] = ZigLLVMCreateDebugMemberType(g->dbuilder,
                ZigLLVMTypeToScope(union_type->di_type), buf_ptr(union_field->enum_field->name),
                import->di_file, (unsigned)(field_node->line + 1),
                store_size_in_bits,
                abi_align_in_bits,
                0,
                0, field_type->di_type);

        biggest_size_in_bits = max(biggest_size_in_bits, store_size_in_bits);

        if (!most_aligned_union_member || abi_align_in_bits > biggest_align_in_bits) {
            most_aligned_union_member = field_type;
            biggest_align_in_bits = abi_align_in_bits;
            size_of_most_aligned_member_in_bits = store_size_in_bits;
        }
    }


    // unset temporary flag
    union_type->data.unionation.embedded_in_current = false;
    union_type->data.unionation.complete = true;
    union_type->data.unionation.union_size_bytes = biggest_size_in_bits / 8;
    union_type->data.unionation.most_aligned_union_member = most_aligned_union_member;

    if (union_type->data.unionation.is_invalid)
        return;

    if (union_type->zero_bits) {
        union_type->type_ref = LLVMVoidType();

        uint64_t debug_size_in_bits = 0;
        uint64_t debug_align_in_bits = 0;
        ZigLLVMDIType **di_root_members = nullptr;
        size_t debug_member_count = 0;
        ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugUnionType(g->dbuilder,
                ZigLLVMFileToScope(import->di_file),
                buf_ptr(&union_type->name),
                import->di_file, (unsigned)(decl_node->line + 1),
                debug_size_in_bits,
                debug_align_in_bits,
                0, di_root_members, (int)debug_member_count, 0, "");

        ZigLLVMReplaceTemporary(g->dbuilder, union_type->di_type, replacement_di_type);
        union_type->di_type = replacement_di_type;
        return;
    }

    uint64_t padding_in_bits = biggest_size_in_bits - size_of_most_aligned_member_in_bits;

    TypeTableEntry *tag_type = union_type->data.unionation.tag_type;
    if (tag_type == nullptr || tag_type->zero_bits) {
        assert(most_aligned_union_member != nullptr);

        if (padding_in_bits > 0) {
            TypeTableEntry *u8_type = get_int_type(g, false, 8);
            TypeTableEntry *padding_array = get_array_type(g, u8_type, padding_in_bits / 8);
            LLVMTypeRef union_element_types[] = {
                most_aligned_union_member->type_ref,
                padding_array->type_ref,
            };
            LLVMStructSetBody(union_type->type_ref, union_element_types, 2, false);
        } else {
            LLVMStructSetBody(union_type->type_ref, &most_aligned_union_member->type_ref, 1, false);
        }
        union_type->data.unionation.union_type_ref = union_type->type_ref;
        union_type->data.unionation.gen_tag_index = SIZE_MAX;
        union_type->data.unionation.gen_union_index = SIZE_MAX;

        assert(8*LLVMABIAlignmentOfType(g->target_data_ref, union_type->type_ref) >= biggest_align_in_bits);
        assert(8*LLVMStoreSizeOfType(g->target_data_ref, union_type->type_ref) >= biggest_size_in_bits);

        // create debug type for union
        ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugUnionType(g->dbuilder,
            ZigLLVMFileToScope(import->di_file), buf_ptr(&union_type->name),
            import->di_file, (unsigned)(decl_node->line + 1),
            biggest_size_in_bits, biggest_align_in_bits, 0, union_inner_di_types,
            gen_field_count, 0, "");

        ZigLLVMReplaceTemporary(g->dbuilder, union_type->di_type, replacement_di_type);
        union_type->di_type = replacement_di_type;
        return;
    }

    LLVMTypeRef union_type_ref;
    if (padding_in_bits > 0) {
        TypeTableEntry *u8_type = get_int_type(g, false, 8);
        TypeTableEntry *padding_array = get_array_type(g, u8_type, padding_in_bits / 8);
        LLVMTypeRef union_element_types[] = {
            most_aligned_union_member->type_ref,
            padding_array->type_ref,
        };
        union_type_ref = LLVMStructType(union_element_types, 2, false);
    } else if (most_aligned_union_member == nullptr) {
        union_type->data.unionation.gen_tag_index = SIZE_MAX;
        union_type->data.unionation.gen_union_index = SIZE_MAX;
        union_type->type_ref = tag_type->type_ref;

        ZigLLVMReplaceTemporary(g->dbuilder, union_type->di_type, tag_type->di_type);
        union_type->di_type = tag_type->di_type;
        return;
    } else {
        union_type_ref = most_aligned_union_member->type_ref;
    }
    union_type->data.unionation.union_type_ref = union_type_ref;

    assert(8*LLVMABIAlignmentOfType(g->target_data_ref, union_type_ref) >= biggest_align_in_bits);
    assert(8*LLVMStoreSizeOfType(g->target_data_ref, union_type_ref) >= biggest_size_in_bits);

    // create llvm type for root struct
    TypeTableEntry *tag_int_type = tag_type->data.enumeration.tag_int_type;
    uint64_t align_of_tag_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, tag_int_type->type_ref);

    if (align_of_tag_in_bits >= biggest_align_in_bits) {
        union_type->data.unionation.gen_tag_index = 0;
        union_type->data.unionation.gen_union_index = 1;
    } else {
        union_type->data.unionation.gen_union_index = 0;
        union_type->data.unionation.gen_tag_index = 1;
    }

    LLVMTypeRef root_struct_element_types[2];
    root_struct_element_types[union_type->data.unionation.gen_tag_index] = tag_type->type_ref;
    root_struct_element_types[union_type->data.unionation.gen_union_index] = union_type_ref;
    LLVMStructSetBody(union_type->type_ref, root_struct_element_types, 2, false);


    // create debug type for union
    ZigLLVMDIType *union_di_type = ZigLLVMCreateDebugUnionType(g->dbuilder,
            ZigLLVMTypeToScope(union_type->di_type), "AnonUnion",
            import->di_file, (unsigned)(decl_node->line + 1),
            biggest_size_in_bits, biggest_align_in_bits, 0, union_inner_di_types,
            gen_field_count, 0, "");

    uint64_t union_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, union_type->type_ref,
            union_type->data.unionation.gen_union_index);
    uint64_t tag_offset_in_bits = 8*LLVMOffsetOfElement(g->target_data_ref, union_type->type_ref,
            union_type->data.unionation.gen_tag_index);

    ZigLLVMDIType *union_member_di_type = ZigLLVMCreateDebugMemberType(g->dbuilder,
            ZigLLVMTypeToScope(union_type->di_type), "payload",
            import->di_file, (unsigned)(decl_node->line + 1),
            biggest_size_in_bits,
            biggest_align_in_bits,
            union_offset_in_bits,
            0, union_di_type);

    uint64_t tag_debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, tag_type->type_ref);
    uint64_t tag_debug_align_in_bits = 8*LLVMABIAlignmentOfType(g->target_data_ref, tag_type->type_ref);

    ZigLLVMDIType *tag_member_di_type = ZigLLVMCreateDebugMemberType(g->dbuilder,
            ZigLLVMTypeToScope(union_type->di_type), "tag",
            import->di_file, (unsigned)(decl_node->line + 1),
            tag_debug_size_in_bits,
            tag_debug_align_in_bits,
            tag_offset_in_bits,
            0, tag_type->di_type);

    ZigLLVMDIType *di_root_members[2];
    di_root_members[union_type->data.unionation.gen_tag_index] = tag_member_di_type;
    di_root_members[union_type->data.unionation.gen_union_index] = union_member_di_type;

    uint64_t debug_size_in_bits = 8*LLVMStoreSizeOfType(g->target_data_ref, union_type->type_ref);
    uint64_t debug_align_in_bits = 8*LLVMABISizeOfType(g->target_data_ref, union_type->type_ref);
    ZigLLVMDIType *replacement_di_type = ZigLLVMCreateDebugStructType(g->dbuilder,
            ZigLLVMFileToScope(import->di_file),
            buf_ptr(&union_type->name),
            import->di_file, (unsigned)(decl_node->line + 1),
            debug_size_in_bits,
            debug_align_in_bits,
            0, nullptr, di_root_members, 2, 0, nullptr, "");

    ZigLLVMReplaceTemporary(g->dbuilder, union_type->di_type, replacement_di_type);
    union_type->di_type = replacement_di_type;
}

static void resolve_enum_zero_bits(CodeGen *g, TypeTableEntry *enum_type) {
    assert(enum_type->id == TypeTableEntryIdEnum);

    if (enum_type->data.enumeration.zero_bits_known)
        return;

    if (enum_type->data.enumeration.zero_bits_loop_flag) {
        add_node_error(g, enum_type->data.enumeration.decl_node,
            buf_sprintf("'%s' depends on itself", buf_ptr(&enum_type->name)));
        enum_type->data.enumeration.is_invalid = true;
        return;
    }

    enum_type->data.enumeration.zero_bits_loop_flag = true;

    AstNode *decl_node = enum_type->data.enumeration.decl_node;
    assert(decl_node->type == NodeTypeContainerDecl);
    assert(enum_type->di_type);

    assert(!enum_type->data.enumeration.fields);
    uint32_t field_count = (uint32_t)decl_node->data.container_decl.fields.length;
    if (field_count == 0) {
        add_node_error(g, decl_node, buf_sprintf("enums must have 1 or more fields"));

        enum_type->data.enumeration.src_field_count = field_count;
        enum_type->data.enumeration.fields = nullptr;
        enum_type->data.enumeration.is_invalid = true;
        enum_type->data.enumeration.zero_bits_loop_flag = false;
        enum_type->data.enumeration.zero_bits_known = true;
        return;
    }

    enum_type->data.enumeration.src_field_count = field_count;
    enum_type->data.enumeration.fields = allocate<TypeEnumField>(field_count);
    enum_type->data.enumeration.fields_by_name.init(field_count);

    Scope *scope = &enum_type->data.enumeration.decls_scope->base;

    HashMap<BigInt, AstNode *, bigint_hash, bigint_eql> occupied_tag_values = {};
    occupied_tag_values.init(field_count);

    TypeTableEntry *tag_int_type;
    if (enum_type->data.enumeration.layout == ContainerLayoutExtern) {
        tag_int_type = get_c_int_type(g, CIntTypeInt);
    } else {
        tag_int_type = get_smallest_unsigned_int_type(g, field_count - 1);
    }

    // TODO: Are extern enums allowed to have an init_arg_expr?
    if (decl_node->data.container_decl.init_arg_expr != nullptr) {
        TypeTableEntry *wanted_tag_int_type = analyze_type_expr(g, scope, decl_node->data.container_decl.init_arg_expr);
        if (type_is_invalid(wanted_tag_int_type)) {
            enum_type->data.enumeration.is_invalid = true;
        } else if (wanted_tag_int_type->id != TypeTableEntryIdInt) {
            enum_type->data.enumeration.is_invalid = true;
            add_node_error(g, decl_node->data.container_decl.init_arg_expr,
                buf_sprintf("expected integer, found '%s'", buf_ptr(&wanted_tag_int_type->name)));
        } else if (wanted_tag_int_type->data.integral.is_signed) {
            enum_type->data.enumeration.is_invalid = true;
            add_node_error(g, decl_node->data.container_decl.init_arg_expr,
                buf_sprintf("expected unsigned integer, found '%s'", buf_ptr(&wanted_tag_int_type->name)));
        } else if (wanted_tag_int_type->data.integral.bit_count < tag_int_type->data.integral.bit_count) {
            enum_type->data.enumeration.is_invalid = true;
            add_node_error(g, decl_node->data.container_decl.init_arg_expr,
                buf_sprintf("'%s' too small to hold all bits; must be at least '%s'",
                    buf_ptr(&wanted_tag_int_type->name), buf_ptr(&tag_int_type->name)));
        } else {
            tag_int_type = wanted_tag_int_type;
        }
    }
    enum_type->data.enumeration.tag_int_type = tag_int_type;
    enum_type->type_ref = tag_int_type->type_ref;

    for (uint32_t field_i = 0; field_i < field_count; field_i += 1) {
        AstNode *field_node = decl_node->data.container_decl.fields.at(field_i);
        TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[field_i];
        type_enum_field->name = field_node->data.struct_field.name;
        type_enum_field->decl_index = field_i;
        type_enum_field->decl_node = field_node;

        if (field_node->data.struct_field.type != nullptr) {
            ErrorMsg *msg = add_node_error(g, field_node->data.struct_field.type,
                buf_sprintf("structs and unions, not enums, support field types"));
            add_error_note(g, msg, decl_node,
                    buf_sprintf("consider 'union(enum)' here"));
        }

        auto field_entry = enum_type->data.enumeration.fields_by_name.put_unique(type_enum_field->name, type_enum_field);
        if (field_entry != nullptr) {
            ErrorMsg *msg = add_node_error(g, field_node,
                buf_sprintf("duplicate enum field: '%s'", buf_ptr(type_enum_field->name)));
            add_error_note(g, msg, field_entry->value->decl_node, buf_sprintf("other field here"));
            enum_type->data.enumeration.is_invalid = true;
            continue;
        }

        AstNode *tag_value = field_node->data.struct_field.value;

        // In this first pass we resolve explicit tag values.
        // In a second pass we will fill in the unspecified ones.
        if (tag_value != nullptr) {
            IrInstruction *result_inst = analyze_const_value(g, scope, tag_value, tag_int_type, nullptr);
            if (result_inst->value.type->id == TypeTableEntryIdInvalid) {
                enum_type->data.enumeration.is_invalid = true;
                continue;
            }
            assert(result_inst->value.special != ConstValSpecialRuntime);
            assert(result_inst->value.type->id == TypeTableEntryIdInt);
            auto entry = occupied_tag_values.put_unique(result_inst->value.data.x_bigint, tag_value);
            if (entry == nullptr) {
                bigint_init_bigint(&type_enum_field->value, &result_inst->value.data.x_bigint);
            } else {
                Buf *val_buf = buf_alloc();
                bigint_append_buf(val_buf, &result_inst->value.data.x_bigint, 10);

                ErrorMsg *msg = add_node_error(g, tag_value,
                        buf_sprintf("enum tag value %s already taken", buf_ptr(val_buf)));
                add_error_note(g, msg, entry->value,
                        buf_sprintf("other occurrence here"));
                enum_type->data.enumeration.is_invalid = true;
                continue;
            }
        }
    }

    // Now iterate again and populate the unspecified tag values
    uint32_t next_maybe_unoccupied_index = 0;

    for (uint32_t field_i = 0; field_i < field_count; field_i += 1) {
        AstNode *field_node = decl_node->data.container_decl.fields.at(field_i);
        TypeEnumField *type_enum_field = &enum_type->data.enumeration.fields[field_i];
        AstNode *tag_value = field_node->data.struct_field.value;

        if (tag_value == nullptr) {
            if (occupied_tag_values.size() == 0) {
                bigint_init_unsigned(&type_enum_field->value, next_maybe_unoccupied_index);
                next_maybe_unoccupied_index += 1;
            } else {
                BigInt proposed_value;
                for (;;) {
                    bigint_init_unsigned(&proposed_value, next_maybe_unoccupied_index);
                    next_maybe_unoccupied_index += 1;
                    auto entry = occupied_tag_values.put_unique(proposed_value, field_node);
                    if (entry != nullptr) {
                        continue;
                    }
                    break;
                }
                bigint_init_bigint(&type_enum_field->value, &proposed_value);
            }
        }
    }

    enum_type->data.enumeration.zero_bits_loop_flag = false;
    enum_type->zero_bits = !type_has_bits(tag_int_type);
    enum_type->data.enumeration.zero_bits_known = true;
}

static void resolve_struct_zero_bits(CodeGen *g, TypeTableEntry *struct_type) {
    assert(struct_type->id == TypeTableEntryIdStruct);

    if (struct_type->data.structure.zero_bits_known)
        return;

    if (struct_type->data.structure.zero_bits_loop_flag) {
        // If we get here it's due to recursion. This is a design flaw in the compiler,
        // we should be able to still figure out alignment, but here we give up and say that
        // the alignment is pointer width, then assert that the first field is within that
        // alignment
        struct_type->data.structure.zero_bits_known = true;
        struct_type->data.structure.zero_bits_loop_flag = false;
        if (struct_type->data.structure.abi_alignment == 0) {
            if (struct_type->data.structure.layout == ContainerLayoutPacked) {
                struct_type->data.structure.abi_alignment = 1;
            } else {
                struct_type->data.structure.abi_alignment = LLVMABIAlignmentOfType(g->target_data_ref, LLVMPointerType(LLVMInt8Type(), 0));
            }
        }
        return;
    }

    struct_type->data.structure.zero_bits_loop_flag = true;

    AstNode *decl_node = struct_type->data.structure.decl_node;
    assert(decl_node->type == NodeTypeContainerDecl);
    assert(struct_type->di_type);

    assert(!struct_type->data.structure.fields);
    size_t field_count = decl_node->data.container_decl.fields.length;
    struct_type->data.structure.src_field_count = (uint32_t)field_count;
    struct_type->data.structure.fields = allocate<TypeStructField>(field_count);
    struct_type->data.structure.fields_by_name.init(field_count);

    Scope *scope = &struct_type->data.structure.decls_scope->base;

    size_t gen_field_index = 0;
    for (size_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.container_decl.fields.at(i);
        TypeStructField *type_struct_field = &struct_type->data.structure.fields[i];
        type_struct_field->name = field_node->data.struct_field.name;
        type_struct_field->decl_node = field_node;

        if (field_node->data.struct_field.type == nullptr) {
            add_node_error(g, field_node, buf_sprintf("struct field missing type"));
            struct_type->data.structure.is_invalid = true;
            continue;
        }

        auto field_entry = struct_type->data.structure.fields_by_name.put_unique(type_struct_field->name, type_struct_field);
        if (field_entry != nullptr) {
            ErrorMsg *msg = add_node_error(g, field_node,
                buf_sprintf("duplicate struct field: '%s'", buf_ptr(type_struct_field->name)));
            add_error_note(g, msg, field_entry->value->decl_node, buf_sprintf("other field here"));
            struct_type->data.structure.is_invalid = true;
            continue;
        }

        TypeTableEntry *field_type = analyze_type_expr(g, scope, field_node->data.struct_field.type);
        type_struct_field->type_entry = field_type;
        type_struct_field->src_index = i;
        type_struct_field->gen_index = SIZE_MAX;

        if (field_node->data.struct_field.value != nullptr) {
            add_node_error(g, field_node->data.struct_field.value,
                    buf_sprintf("enums, not structs, support field assignment"));
        }

        type_ensure_zero_bits_known(g, field_type);
        if (type_is_invalid(field_type)) {
            struct_type->data.structure.is_invalid = true;
            continue;
        }

        if (type_requires_comptime(field_type)) {
            struct_type->data.structure.requires_comptime = true;
        }

        if (!type_has_bits(field_type))
            continue;

        if (gen_field_index == 0) {
            if (struct_type->data.structure.layout == ContainerLayoutPacked) {
                struct_type->data.structure.abi_alignment = 1;
            } else if (struct_type->data.structure.abi_alignment == 0) {
                // Alignment of structs is the alignment of the first field, for now.
                // TODO change this when we re-order struct fields (issue #168)
                struct_type->data.structure.abi_alignment = get_abi_alignment(g, field_type);
                assert(struct_type->data.structure.abi_alignment != 0);
            } else {
                // due to a design flaw in the compiler we assumed that alignment was
                // pointer width, so we assert that this wasn't violated.
                if (get_abi_alignment(g, field_type) > struct_type->data.structure.abi_alignment) {
                    zig_panic("compiler design flaw: incorrect alignment assumption");
                }
            }
        }

        type_struct_field->gen_index = gen_field_index;
        gen_field_index += 1;
    }

    struct_type->data.structure.zero_bits_loop_flag = false;
    struct_type->data.structure.gen_field_count = (uint32_t)gen_field_index;
    struct_type->zero_bits = (gen_field_index == 0);
    struct_type->data.structure.zero_bits_known = true;
}

static void resolve_union_zero_bits(CodeGen *g, TypeTableEntry *union_type) {
    assert(union_type->id == TypeTableEntryIdUnion);

    if (union_type->data.unionation.zero_bits_known)
        return;

    if (type_is_invalid(union_type))
        return;

    if (union_type->data.unionation.zero_bits_loop_flag) {
        // If we get here it's due to recursion. From this we conclude that the struct is
        // not zero bits, and if abi_alignment == 0 we further conclude that the first field
        // is a pointer to this very struct, or a function pointer with parameters that
        // reference such a type.
        union_type->data.unionation.zero_bits_known = true;
        union_type->data.unionation.zero_bits_loop_flag = false;
        if (union_type->data.unionation.abi_alignment == 0) {
            if (union_type->data.unionation.layout == ContainerLayoutPacked) {
                union_type->data.unionation.abi_alignment = 1;
            } else {
                union_type->data.unionation.abi_alignment = LLVMABIAlignmentOfType(g->target_data_ref,
                        LLVMPointerType(LLVMInt8Type(), 0));
            }
        }
        return;
    }

    union_type->data.unionation.zero_bits_loop_flag = true;

    AstNode *decl_node = union_type->data.unionation.decl_node;
    assert(decl_node->type == NodeTypeContainerDecl);
    assert(union_type->di_type);

    assert(!union_type->data.unionation.fields);
    uint32_t field_count = (uint32_t)decl_node->data.container_decl.fields.length;
    if (field_count == 0) {
        add_node_error(g, decl_node, buf_sprintf("unions must have 1 or more fields"));

        union_type->data.unionation.src_field_count = field_count;
        union_type->data.unionation.fields = nullptr;
        union_type->data.unionation.is_invalid = true;
        union_type->data.unionation.zero_bits_loop_flag = false;
        union_type->data.unionation.zero_bits_known = true;
        return;
    }
    union_type->data.unionation.src_field_count = field_count;
    union_type->data.unionation.fields = allocate<TypeUnionField>(field_count);
    union_type->data.unionation.fields_by_name.init(field_count);

    uint32_t biggest_align_bytes = 0;

    Scope *scope = &union_type->data.unionation.decls_scope->base;

    HashMap<BigInt, AstNode *, bigint_hash, bigint_eql> occupied_tag_values = {};

    AstNode *enum_type_node = decl_node->data.container_decl.init_arg_expr;
    union_type->data.unionation.have_explicit_tag_type = decl_node->data.container_decl.auto_enum ||
        enum_type_node != nullptr;
    bool auto_layout = (union_type->data.unionation.layout == ContainerLayoutAuto);
    bool want_safety = (field_count >= 2) && (auto_layout || enum_type_node != nullptr);
    TypeTableEntry *tag_type;
    bool create_enum_type = decl_node->data.container_decl.auto_enum || (enum_type_node == nullptr && want_safety);
    bool *covered_enum_fields;
    ZigLLVMDIEnumerator **di_enumerators;
    uint32_t abi_alignment_so_far;
    if (create_enum_type) {
        occupied_tag_values.init(field_count);

        di_enumerators = allocate<ZigLLVMDIEnumerator*>(field_count);

        TypeTableEntry *tag_int_type;
        if (enum_type_node != nullptr) {
            tag_int_type = analyze_type_expr(g, scope, enum_type_node);
            if (type_is_invalid(tag_int_type)) {
                union_type->data.unionation.is_invalid = true;
                return;
            }
            if (tag_int_type->id != TypeTableEntryIdInt) {
                add_node_error(g, enum_type_node,
                    buf_sprintf("expected integer tag type, found '%s'", buf_ptr(&tag_int_type->name)));
                union_type->data.unionation.is_invalid = true;
                return;
            }
        } else {
            tag_int_type = get_smallest_unsigned_int_type(g, field_count - 1);
        }
        abi_alignment_so_far = get_abi_alignment(g, tag_int_type);

        tag_type = new_type_table_entry(TypeTableEntryIdEnum);
        buf_resize(&tag_type->name, 0);
        buf_appendf(&tag_type->name, "@TagType(%s)", buf_ptr(&union_type->name));
        tag_type->is_copyable = true;
        tag_type->type_ref = tag_int_type->type_ref;
        tag_type->zero_bits = tag_int_type->zero_bits;

        tag_type->data.enumeration.tag_int_type = tag_int_type;
        tag_type->data.enumeration.zero_bits_known = true;
        tag_type->data.enumeration.decl_node = decl_node;
        tag_type->data.enumeration.layout = ContainerLayoutAuto;
        tag_type->data.enumeration.src_field_count = field_count;
        tag_type->data.enumeration.fields = allocate<TypeEnumField>(field_count);
        tag_type->data.enumeration.fields_by_name.init(field_count);
        tag_type->data.enumeration.decls_scope = union_type->data.unionation.decls_scope;
        tag_type->data.enumeration.complete = true;
    } else if (enum_type_node != nullptr) {
        TypeTableEntry *enum_type = analyze_type_expr(g, scope, enum_type_node);
        if (type_is_invalid(enum_type)) {
            union_type->data.unionation.is_invalid = true;
            return;
        }
        if (enum_type->id != TypeTableEntryIdEnum) {
            union_type->data.unionation.is_invalid = true;
            add_node_error(g, enum_type_node,
                buf_sprintf("expected enum tag type, found '%s'", buf_ptr(&enum_type->name)));
            return;
        }
        tag_type = enum_type;
        abi_alignment_so_far = get_abi_alignment(g, enum_type); // this populates src_field_count
        covered_enum_fields = allocate<bool>(enum_type->data.enumeration.src_field_count);
    } else {
        tag_type = nullptr;
        abi_alignment_so_far = 0;
    }
    union_type->data.unionation.tag_type = tag_type;

    uint32_t gen_field_index = 0;
    for (uint32_t i = 0; i < field_count; i += 1) {
        AstNode *field_node = decl_node->data.container_decl.fields.at(i);
        Buf *field_name = field_node->data.struct_field.name;
        TypeUnionField *union_field = &union_type->data.unionation.fields[i];
        union_field->name = field_node->data.struct_field.name;
        union_field->decl_node = field_node;

        auto field_entry = union_type->data.unionation.fields_by_name.put_unique(union_field->name, union_field);
        if (field_entry != nullptr) {
            ErrorMsg *msg = add_node_error(g, field_node,
                buf_sprintf("duplicate union field: '%s'", buf_ptr(union_field->name)));
            add_error_note(g, msg, field_entry->value->decl_node, buf_sprintf("other field here"));
            union_type->data.unionation.is_invalid = true;
            continue;
        }

        TypeTableEntry *field_type;
        if (field_node->data.struct_field.type == nullptr) {
            if (decl_node->data.container_decl.auto_enum || decl_node->data.container_decl.init_arg_expr != nullptr) {
                field_type = g->builtin_types.entry_void;
            } else {
                add_node_error(g, field_node, buf_sprintf("union field missing type"));
                union_type->data.unionation.is_invalid = true;
                continue;
            }
        } else {
            field_type = analyze_type_expr(g, scope, field_node->data.struct_field.type);
            type_ensure_zero_bits_known(g, field_type);
            if (type_is_invalid(field_type)) {
                union_type->data.unionation.is_invalid = true;
                continue;
            }
        }
        union_field->type_entry = field_type;

        if (type_requires_comptime(field_type)) {
            union_type->data.unionation.requires_comptime = true;
        }


        if (field_node->data.struct_field.value != nullptr && !decl_node->data.container_decl.auto_enum) {
            ErrorMsg *msg = add_node_error(g, field_node->data.struct_field.value,
                    buf_sprintf("non-enum union field assignment"));
            add_error_note(g, msg, decl_node,
                    buf_sprintf("consider 'union(enum)' here"));
        }

        if (create_enum_type) {
            di_enumerators[i] = ZigLLVMCreateDebugEnumerator(g->dbuilder, buf_ptr(field_name), i);
            union_field->enum_field = &tag_type->data.enumeration.fields[i];
            union_field->enum_field->name = field_name;
            union_field->enum_field->decl_index = i;
            union_field->enum_field->decl_node = field_node;

            auto prev_entry = tag_type->data.enumeration.fields_by_name.put_unique(union_field->enum_field->name, union_field->enum_field);
            assert(prev_entry == nullptr); // caught by union de-duplicator above

            AstNode *tag_value = field_node->data.struct_field.value;
            // In this first pass we resolve explicit tag values.
            // In a second pass we will fill in the unspecified ones.
            if (tag_value != nullptr) {
                TypeTableEntry *tag_int_type = tag_type->data.enumeration.tag_int_type;
                IrInstruction *result_inst = analyze_const_value(g, scope, tag_value, tag_int_type, nullptr);
                if (result_inst->value.type->id == TypeTableEntryIdInvalid) {
                    union_type->data.unionation.is_invalid = true;
                    continue;
                }
                assert(result_inst->value.special != ConstValSpecialRuntime);
                assert(result_inst->value.type->id == TypeTableEntryIdInt);
                auto entry = occupied_tag_values.put_unique(result_inst->value.data.x_bigint, tag_value);
                if (entry == nullptr) {
                    bigint_init_bigint(&union_field->enum_field->value, &result_inst->value.data.x_bigint);
                } else {
                    Buf *val_buf = buf_alloc();
                    bigint_append_buf(val_buf, &result_inst->value.data.x_bigint, 10);

                    ErrorMsg *msg = add_node_error(g, tag_value,
                            buf_sprintf("enum tag value %s already taken", buf_ptr(val_buf)));
                    add_error_note(g, msg, entry->value,
                            buf_sprintf("other occurrence here"));
                    union_type->data.unionation.is_invalid = true;
                    continue;
                }
            }
        } else if (enum_type_node != nullptr) {
            union_field->enum_field = find_enum_type_field(tag_type, field_name);
            if (union_field->enum_field == nullptr) {
                ErrorMsg *msg = add_node_error(g, field_node,
                    buf_sprintf("enum field not found: '%s'", buf_ptr(field_name)));
                add_error_note(g, msg, tag_type->data.enumeration.decl_node,
                        buf_sprintf("enum declared here"));
                union_type->data.unionation.is_invalid = true;
                continue;
            }
            covered_enum_fields[union_field->enum_field->decl_index] = true;
        } else {
            union_field->enum_field = allocate<TypeEnumField>(1);
            union_field->enum_field->name = field_name;
            union_field->enum_field->decl_index = i;
            bigint_init_unsigned(&union_field->enum_field->value, i);
        }
        assert(union_field->enum_field != nullptr);

        if (!type_has_bits(field_type))
            continue;

        union_field->gen_index = gen_field_index;
        gen_field_index += 1;

        uint32_t field_align_bytes = get_abi_alignment(g, field_type);
        if (field_align_bytes > biggest_align_bytes) {
            biggest_align_bytes = field_align_bytes;
            if (biggest_align_bytes > abi_alignment_so_far) {
                abi_alignment_so_far = biggest_align_bytes;
            }
        }
    }

    union_type->data.unionation.abi_alignment = abi_alignment_so_far;

    if (union_type->data.unionation.is_invalid)
        return;

    bool src_have_tag = decl_node->data.container_decl.auto_enum ||
        decl_node->data.container_decl.init_arg_expr != nullptr;

    if (src_have_tag && union_type->data.unionation.layout != ContainerLayoutAuto) {
        const char *qual_str;
        switch (union_type->data.unionation.layout) {
            case ContainerLayoutAuto:
                zig_unreachable();
            case ContainerLayoutPacked:
                qual_str = "packed";
                break;
            case ContainerLayoutExtern:
                qual_str = "extern";
                break;
        }
        AstNode *source_node = (decl_node->data.container_decl.init_arg_expr != nullptr) ?
            decl_node->data.container_decl.init_arg_expr : decl_node;
        add_node_error(g, source_node,
            buf_sprintf("%s union does not support enum tag type", qual_str));
        union_type->data.unionation.is_invalid = true;
        return;
    }

    if (create_enum_type) {
        // Now iterate again and populate the unspecified tag values
        uint32_t next_maybe_unoccupied_index = 0;

        for (uint32_t field_i = 0; field_i < field_count; field_i += 1) {
            AstNode *field_node = decl_node->data.container_decl.fields.at(field_i);
            TypeUnionField *union_field = &union_type->data.unionation.fields[field_i];
            AstNode *tag_value = field_node->data.struct_field.value;

            if (tag_value == nullptr) {
                if (occupied_tag_values.size() == 0) {
                    bigint_init_unsigned(&union_field->enum_field->value, next_maybe_unoccupied_index);
                    next_maybe_unoccupied_index += 1;
                } else {
                    BigInt proposed_value;
                    for (;;) {
                        bigint_init_unsigned(&proposed_value, next_maybe_unoccupied_index);
                        next_maybe_unoccupied_index += 1;
                        auto entry = occupied_tag_values.put_unique(proposed_value, field_node);
                        if (entry != nullptr) {
                            continue;
                        }
                        break;
                    }
                    bigint_init_bigint(&union_field->enum_field->value, &proposed_value);
                }
            }
        }
    } else if (enum_type_node != nullptr) {
        for (uint32_t i = 0; i < tag_type->data.enumeration.src_field_count; i += 1) {
            TypeEnumField *enum_field = &tag_type->data.enumeration.fields[i];
            if (!covered_enum_fields[i]) {
                AstNode *enum_decl_node = tag_type->data.enumeration.decl_node;
                AstNode *field_node = enum_decl_node->data.container_decl.fields.at(i);
                ErrorMsg *msg = add_node_error(g, decl_node,
                    buf_sprintf("enum field missing: '%s'", buf_ptr(enum_field->name)));
                add_error_note(g, msg, field_node,
                        buf_sprintf("declared here"));
                union_type->data.unionation.is_invalid = true;
            }
        }
    }

    if (create_enum_type) {
        ImportTableEntry *import = get_scope_import(scope);
        uint64_t tag_debug_size_in_bits = tag_type->zero_bits ? 0 :
            8*LLVMStoreSizeOfType(g->target_data_ref, tag_type->type_ref);
        uint64_t tag_debug_align_in_bits = tag_type->zero_bits ? 0 :
            8*LLVMABIAlignmentOfType(g->target_data_ref, tag_type->type_ref);
        // TODO get a more accurate debug scope
        ZigLLVMDIType *tag_di_type = ZigLLVMCreateDebugEnumerationType(g->dbuilder,
                ZigLLVMFileToScope(import->di_file), buf_ptr(&tag_type->name),
                import->di_file, (unsigned)(decl_node->line + 1),
                tag_debug_size_in_bits, tag_debug_align_in_bits, di_enumerators, field_count,
                tag_type->di_type, "");
        tag_type->di_type = tag_di_type;
    }

    union_type->data.unionation.zero_bits_loop_flag = false;
    union_type->data.unionation.gen_field_count = gen_field_index;
    union_type->zero_bits = (gen_field_index == 0 && (field_count < 2 || !src_have_tag));
    union_type->data.unionation.zero_bits_known = true;
}

static void get_fully_qualified_decl_name_internal(Buf *buf, Scope *scope, uint8_t sep) {
    if (!scope)
        return;

    if (scope->id == ScopeIdDecls) {
        get_fully_qualified_decl_name_internal(buf, scope->parent, sep);

        ScopeDecls *scope_decls = (ScopeDecls *)scope;
        if (scope_decls->container_type) {
            buf_append_buf(buf, &scope_decls->container_type->name);
            buf_append_char(buf, sep);
        }
        return;
    }

    get_fully_qualified_decl_name_internal(buf, scope->parent, sep);
}

static void get_fully_qualified_decl_name(Buf *buf, Tld *tld, uint8_t sep) {
    buf_resize(buf, 0);
    get_fully_qualified_decl_name_internal(buf, tld->parent_scope, sep);
    buf_append_buf(buf, tld->name);
}

FnTableEntry *create_fn_raw(FnInline inline_value) {
    FnTableEntry *fn_entry = allocate<FnTableEntry>(1);

    fn_entry->analyzed_executable.backward_branch_count = &fn_entry->prealloc_bbc;
    fn_entry->analyzed_executable.backward_branch_quota = default_backward_branch_quota;
    fn_entry->analyzed_executable.fn_entry = fn_entry;
    fn_entry->ir_executable.fn_entry = fn_entry;
    fn_entry->fn_inline = inline_value;

    return fn_entry;
}

FnTableEntry *create_fn(AstNode *proto_node) {
    assert(proto_node->type == NodeTypeFnProto);
    AstNodeFnProto *fn_proto = &proto_node->data.fn_proto;

    FnInline inline_value = fn_proto->is_inline ? FnInlineAlways : FnInlineAuto;
    FnTableEntry *fn_entry = create_fn_raw(inline_value);

    fn_entry->proto_node = proto_node;
    fn_entry->body_node = (proto_node->data.fn_proto.fn_def_node == nullptr) ? nullptr :
        proto_node->data.fn_proto.fn_def_node->data.fn_def.body;

    return fn_entry;
}

static bool scope_is_root_decls(Scope *scope) {
    while (scope) {
        if (scope->id == ScopeIdDecls) {
            ScopeDecls *scope_decls = (ScopeDecls *)scope;
            return (scope_decls->container_type == nullptr);
        }
        scope = scope->parent;
    }
    zig_unreachable();
}

static void wrong_panic_prototype(CodeGen *g, AstNode *proto_node, TypeTableEntry *fn_type) {
    add_node_error(g, proto_node,
            buf_sprintf("expected 'fn([]const u8, ?&builtin.StackTrace) unreachable', found '%s'",
                buf_ptr(&fn_type->name)));
}

static void typecheck_panic_fn(CodeGen *g, FnTableEntry *panic_fn) {
    AstNode *proto_node = panic_fn->proto_node;
    assert(proto_node->type == NodeTypeFnProto);
    TypeTableEntry *fn_type = panic_fn->type_entry;
    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;
    if (fn_type_id->param_count != 2) {
        return wrong_panic_prototype(g, proto_node, fn_type);
    }
    TypeTableEntry *const_u8_ptr = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0);
    TypeTableEntry *const_u8_slice = get_slice_type(g, const_u8_ptr);
    if (fn_type_id->param_info[0].type != const_u8_slice) {
        return wrong_panic_prototype(g, proto_node, fn_type);
    }

    TypeTableEntry *optional_ptr_to_stack_trace_type = get_optional_type(g, get_ptr_to_stack_trace_type(g));
    if (fn_type_id->param_info[1].type != optional_ptr_to_stack_trace_type) {
        return wrong_panic_prototype(g, proto_node, fn_type);
    }

    TypeTableEntry *actual_return_type = fn_type_id->return_type;
    if (actual_return_type != g->builtin_types.entry_unreachable) {
        return wrong_panic_prototype(g, proto_node, fn_type);
    }
}

TypeTableEntry *get_test_fn_type(CodeGen *g) {
    if (g->test_fn_type)
        return g->test_fn_type;

    FnTypeId fn_type_id = {0};
    fn_type_id.return_type = get_error_union_type(g, g->builtin_types.entry_global_error_set,
            g->builtin_types.entry_void);
    g->test_fn_type = get_fn_type(g, &fn_type_id);
    return g->test_fn_type;
}

void add_fn_export(CodeGen *g, FnTableEntry *fn_table_entry, Buf *symbol_name, GlobalLinkageId linkage, bool ccc) {
    if (ccc) {
        if (buf_eql_str(symbol_name, "main") && g->libc_link_lib != nullptr) {
            g->have_c_main = true;
            g->windows_subsystem_windows = false;
            g->windows_subsystem_console = true;
        } else if (buf_eql_str(symbol_name, "WinMain") &&
            g->zig_target.os == OsWindows)
        {
            g->have_winmain = true;
            g->windows_subsystem_windows = true;
            g->windows_subsystem_console = false;
        } else if (buf_eql_str(symbol_name, "WinMainCRTStartup") &&
            g->zig_target.os == OsWindows)
        {
            g->have_winmain_crt_startup = true;
        } else if (buf_eql_str(symbol_name, "DllMainCRTStartup") &&
            g->zig_target.os == OsWindows)
        {
            g->have_dllmain_crt_startup = true;
        }
    }
    FnExport *fn_export = fn_table_entry->export_list.add_one();
    memset(fn_export, 0, sizeof(FnExport));
    buf_init_from_buf(&fn_export->name, symbol_name);
    fn_export->linkage = linkage;
}

static void resolve_decl_fn(CodeGen *g, TldFn *tld_fn) {
    ImportTableEntry *import = tld_fn->base.import;
    AstNode *source_node = tld_fn->base.source_node;
    if (source_node->type == NodeTypeFnProto) {
        AstNodeFnProto *fn_proto = &source_node->data.fn_proto;

        AstNode *fn_def_node = fn_proto->fn_def_node;

        FnTableEntry *fn_table_entry = create_fn(source_node);
        get_fully_qualified_decl_name(&fn_table_entry->symbol_name, &tld_fn->base, '_');

        if (fn_proto->is_export) {
            bool ccc = (fn_proto->cc == CallingConventionUnspecified || fn_proto->cc == CallingConventionC);
            add_fn_export(g, fn_table_entry, &fn_table_entry->symbol_name, GlobalLinkageIdStrong, ccc);
        }

        tld_fn->fn_entry = fn_table_entry;

        if (fn_table_entry->body_node) {
            fn_table_entry->fndef_scope = create_fndef_scope(
                fn_table_entry->body_node, tld_fn->base.parent_scope, fn_table_entry);

            for (size_t i = 0; i < fn_proto->params.length; i += 1) {
                AstNode *param_node = fn_proto->params.at(i);
                assert(param_node->type == NodeTypeParamDecl);
                if (param_node->data.param_decl.name == nullptr) {
                    add_node_error(g, param_node, buf_sprintf("missing parameter name"));
                }
            }
        } else {
            g->external_prototypes.put_unique(tld_fn->base.name, &tld_fn->base);
        }

        Scope *child_scope = fn_table_entry->fndef_scope ? &fn_table_entry->fndef_scope->base : tld_fn->base.parent_scope;

        fn_table_entry->type_entry = analyze_fn_type(g, source_node, child_scope, fn_table_entry);

        if (fn_proto->section_expr != nullptr) {
            if (fn_table_entry->body_node == nullptr) {
                add_node_error(g, fn_proto->section_expr,
                    buf_sprintf("cannot set section of external function '%s'", buf_ptr(&fn_table_entry->symbol_name)));
            } else {
                analyze_const_string(g, child_scope, fn_proto->section_expr, &fn_table_entry->section_name);
            }
        }

        if (fn_table_entry->type_entry->id == TypeTableEntryIdInvalid) {
            tld_fn->base.resolution = TldResolutionInvalid;
            return;
        }

        if (!fn_table_entry->type_entry->data.fn.is_generic) {
            if (fn_def_node)
                g->fn_defs.append(fn_table_entry);

            if (scope_is_root_decls(tld_fn->base.parent_scope) &&
                (import == g->root_import || import->package == g->panic_package))
            {
                if (g->have_pub_main && buf_eql_str(&fn_table_entry->symbol_name, "main")) {
                    g->main_fn = fn_table_entry;
                } else if ((import->package == g->panic_package || g->have_pub_panic) &&
                        buf_eql_str(&fn_table_entry->symbol_name, "panic"))
                {
                    g->panic_fn = fn_table_entry;
                    typecheck_panic_fn(g, fn_table_entry);
                }
            }
        }
    } else if (source_node->type == NodeTypeTestDecl) {
        FnTableEntry *fn_table_entry = create_fn_raw(FnInlineAuto);

        get_fully_qualified_decl_name(&fn_table_entry->symbol_name, &tld_fn->base, '_');

        tld_fn->fn_entry = fn_table_entry;

        fn_table_entry->proto_node = source_node;
        fn_table_entry->fndef_scope = create_fndef_scope(source_node, tld_fn->base.parent_scope, fn_table_entry);
        fn_table_entry->type_entry = get_test_fn_type(g);
        fn_table_entry->body_node = source_node->data.test_decl.body;
        fn_table_entry->is_test = true;

        g->fn_defs.append(fn_table_entry);
        g->test_fns.append(fn_table_entry);

    } else {
        zig_unreachable();
    }
}

static void resolve_decl_comptime(CodeGen *g, TldCompTime *tld_comptime) {
    assert(tld_comptime->base.source_node->type == NodeTypeCompTime);
    AstNode *expr_node = tld_comptime->base.source_node->data.comptime_expr.expr;
    analyze_const_value(g, tld_comptime->base.parent_scope, expr_node, g->builtin_types.entry_void, nullptr);
}

static void add_top_level_decl(CodeGen *g, ScopeDecls *decls_scope, Tld *tld) {
    bool is_export = false;
    if (tld->id == TldIdVar) {
        assert(tld->source_node->type == NodeTypeVariableDeclaration);
        is_export = tld->source_node->data.variable_declaration.is_export;
    } else if (tld->id == TldIdFn) {
        assert(tld->source_node->type == NodeTypeFnProto);
        is_export = tld->source_node->data.fn_proto.is_export;
    }
    if (is_export) {
        g->resolve_queue.append(tld);

        auto entry = g->exported_symbol_names.put_unique(tld->name, tld->source_node);
        if (entry) {
            AstNode *other_source_node = entry->value;
            ErrorMsg *msg = add_node_error(g, tld->source_node,
                    buf_sprintf("exported symbol collision: '%s'", buf_ptr(tld->name)));
            add_error_note(g, msg, other_source_node, buf_sprintf("other symbol here"));
        }
    }

    {
        auto entry = decls_scope->decl_table.put_unique(tld->name, tld);
        if (entry) {
            Tld *other_tld = entry->value;
            ErrorMsg *msg = add_node_error(g, tld->source_node, buf_sprintf("redefinition of '%s'", buf_ptr(tld->name)));
            add_error_note(g, msg, other_tld->source_node, buf_sprintf("previous definition is here"));
            return;
        }
    }

    {
        auto entry = g->primitive_type_table.maybe_get(tld->name);
        if (entry) {
            TypeTableEntry *type = entry->value;
            add_node_error(g, tld->source_node,
                    buf_sprintf("declaration shadows type '%s'", buf_ptr(&type->name)));
        }
    }
}

static void preview_test_decl(CodeGen *g, AstNode *node, ScopeDecls *decls_scope) {
    assert(node->type == NodeTypeTestDecl);

    if (!g->is_test_build)
        return;

    ImportTableEntry *import = get_scope_import(&decls_scope->base);
    if (import->package != g->root_package)
        return;

    Buf *decl_name_buf = node->data.test_decl.name;

    Buf *test_name = g->test_name_prefix ?
        buf_sprintf("%s%s", buf_ptr(g->test_name_prefix), buf_ptr(decl_name_buf)) : decl_name_buf;

    if (g->test_filter != nullptr && strstr(buf_ptr(test_name), buf_ptr(g->test_filter)) == nullptr) {
        return;
    }

    TldFn *tld_fn = allocate<TldFn>(1);
    init_tld(&tld_fn->base, TldIdFn, test_name, VisibModPrivate, node, &decls_scope->base);
    g->resolve_queue.append(&tld_fn->base);
}

static void preview_comptime_decl(CodeGen *g, AstNode *node, ScopeDecls *decls_scope) {
    assert(node->type == NodeTypeCompTime);

    TldCompTime *tld_comptime = allocate<TldCompTime>(1);
    init_tld(&tld_comptime->base, TldIdCompTime, nullptr, VisibModPrivate, node, &decls_scope->base);
    g->resolve_queue.append(&tld_comptime->base);
}

void init_tld(Tld *tld, TldId id, Buf *name, VisibMod visib_mod, AstNode *source_node,
    Scope *parent_scope)
{
    tld->id = id;
    tld->name = name;
    tld->visib_mod = visib_mod;
    tld->source_node = source_node;
    tld->import = source_node ? source_node->owner : nullptr;
    tld->parent_scope = parent_scope;
}

void update_compile_var(CodeGen *g, Buf *name, ConstExprValue *value) {
    Tld *tld = g->compile_var_import->decls_scope->decl_table.get(name);
    resolve_top_level_decl(g, tld, false, tld->source_node);
    assert(tld->id == TldIdVar);
    TldVar *tld_var = (TldVar *)tld;
    tld_var->var->value = value;
    tld_var->var->align_bytes = get_abi_alignment(g, value->type);
}

void scan_decls(CodeGen *g, ScopeDecls *decls_scope, AstNode *node) {
    switch (node->type) {
        case NodeTypeRoot:
            for (size_t i = 0; i < node->data.root.top_level_decls.length; i += 1) {
                AstNode *child = node->data.root.top_level_decls.at(i);
                scan_decls(g, decls_scope, child);
            }
            break;
        case NodeTypeFnDef:
            scan_decls(g, decls_scope, node->data.fn_def.fn_proto);
            break;
        case NodeTypeVariableDeclaration:
            {
                Buf *name = node->data.variable_declaration.symbol;
                VisibMod visib_mod = node->data.variable_declaration.visib_mod;
                TldVar *tld_var = allocate<TldVar>(1);
                init_tld(&tld_var->base, TldIdVar, name, visib_mod, node, &decls_scope->base);
                tld_var->extern_lib_name = node->data.variable_declaration.lib_name;
                add_top_level_decl(g, decls_scope, &tld_var->base);
                break;
            }
        case NodeTypeFnProto:
            {
                // if the name is missing, we immediately announce an error
                Buf *fn_name = node->data.fn_proto.name;
                if (fn_name == nullptr) {
                    add_node_error(g, node, buf_sprintf("missing function name"));
                    break;
                }

                VisibMod visib_mod = node->data.fn_proto.visib_mod;
                TldFn *tld_fn = allocate<TldFn>(1);
                init_tld(&tld_fn->base, TldIdFn, fn_name, visib_mod, node, &decls_scope->base);
                tld_fn->extern_lib_name = node->data.fn_proto.lib_name;
                add_top_level_decl(g, decls_scope, &tld_fn->base);

                break;
            }
        case NodeTypeUse:
            {
                g->use_queue.append(node);
                ImportTableEntry *import = get_scope_import(&decls_scope->base);
                import->use_decls.append(node);
                break;
            }
        case NodeTypeTestDecl:
            preview_test_decl(g, node, decls_scope);
            break;
        case NodeTypeCompTime:
            preview_comptime_decl(g, node, decls_scope);
            break;
        case NodeTypeContainerDecl:
        case NodeTypeParamDecl:
        case NodeTypeReturnExpr:
        case NodeTypeDefer:
        case NodeTypeBlock:
        case NodeTypeGroupedExpr:
        case NodeTypeBinOpExpr:
        case NodeTypeUnwrapErrorExpr:
        case NodeTypeFnCallExpr:
        case NodeTypeArrayAccessExpr:
        case NodeTypeSliceExpr:
        case NodeTypeFloatLiteral:
        case NodeTypeIntLiteral:
        case NodeTypeStringLiteral:
        case NodeTypeCharLiteral:
        case NodeTypeBoolLiteral:
        case NodeTypeNullLiteral:
        case NodeTypeUndefinedLiteral:
        case NodeTypeThisLiteral:
        case NodeTypeSymbol:
        case NodeTypePrefixOpExpr:
        case NodeTypePointerType:
        case NodeTypeIfBoolExpr:
        case NodeTypeWhileExpr:
        case NodeTypeForExpr:
        case NodeTypeSwitchExpr:
        case NodeTypeSwitchProng:
        case NodeTypeSwitchRange:
        case NodeTypeBreak:
        case NodeTypeContinue:
        case NodeTypeUnreachable:
        case NodeTypeAsmExpr:
        case NodeTypeFieldAccessExpr:
        case NodeTypePtrDeref:
        case NodeTypeUnwrapOptional:
        case NodeTypeStructField:
        case NodeTypeContainerInitExpr:
        case NodeTypeStructValueField:
        case NodeTypeArrayType:
        case NodeTypeErrorType:
        case NodeTypeIfErrorExpr:
        case NodeTypeTestExpr:
        case NodeTypeErrorSetDecl:
        case NodeTypeCancel:
        case NodeTypeResume:
        case NodeTypeAwaitExpr:
        case NodeTypeSuspend:
        case NodeTypePromiseType:
            zig_unreachable();
    }
}

static void resolve_decl_container(CodeGen *g, TldContainer *tld_container) {
    TypeTableEntry *type_entry = tld_container->type_entry;
    assert(type_entry);

    switch (type_entry->id) {
        case TypeTableEntryIdStruct:
            resolve_struct_type(g, tld_container->type_entry);
            return;
        case TypeTableEntryIdEnum:
            resolve_enum_type(g, tld_container->type_entry);
            return;
        case TypeTableEntryIdUnion:
            resolve_union_type(g, tld_container->type_entry);
            return;
        default:
            zig_unreachable();
    }
}

TypeTableEntry *validate_var_type(CodeGen *g, AstNode *source_node, TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
            return g->builtin_types.entry_invalid;
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
            add_node_error(g, source_node, buf_sprintf("variable of type '%s' not allowed",
                buf_ptr(&type_entry->name)));
            return g->builtin_types.entry_invalid;
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdPromise:
            return type_entry;
    }
    zig_unreachable();
}

// Set name to nullptr to make the variable anonymous (not visible to programmer).
// TODO merge with definition of add_local_var in ir.cpp
VariableTableEntry *add_variable(CodeGen *g, AstNode *source_node, Scope *parent_scope, Buf *name,
    bool is_const, ConstExprValue *value, Tld *src_tld)
{
    assert(value);

    VariableTableEntry *variable_entry = allocate<VariableTableEntry>(1);
    variable_entry->value = value;
    variable_entry->parent_scope = parent_scope;
    variable_entry->shadowable = false;
    variable_entry->mem_slot_index = SIZE_MAX;
    variable_entry->src_arg_index = SIZE_MAX;
    variable_entry->align_bytes = get_abi_alignment(g, value->type);

    assert(name);

    buf_init_from_buf(&variable_entry->name, name);

    if (value->type->id != TypeTableEntryIdInvalid) {
        VariableTableEntry *existing_var = find_variable(g, parent_scope, name);
        if (existing_var && !existing_var->shadowable) {
            ErrorMsg *msg = add_node_error(g, source_node,
                    buf_sprintf("redeclaration of variable '%s'", buf_ptr(name)));
            add_error_note(g, msg, existing_var->decl_node, buf_sprintf("previous declaration is here"));
            variable_entry->value->type = g->builtin_types.entry_invalid;
        } else {
            auto primitive_table_entry = g->primitive_type_table.maybe_get(name);
            if (primitive_table_entry) {
                TypeTableEntry *type = primitive_table_entry->value;
                add_node_error(g, source_node,
                        buf_sprintf("variable shadows type '%s'", buf_ptr(&type->name)));
                variable_entry->value->type = g->builtin_types.entry_invalid;
            } else {
                Scope *search_scope = nullptr;
                if (src_tld == nullptr) {
                    search_scope = parent_scope;
                } else if (src_tld->parent_scope != nullptr && src_tld->parent_scope->parent != nullptr) {
                    search_scope = src_tld->parent_scope->parent;
                }
                if (search_scope != nullptr) {
                    Tld *tld = find_decl(g, search_scope, name);
                    if (tld != nullptr) {
                        ErrorMsg *msg = add_node_error(g, source_node,
                                buf_sprintf("redefinition of '%s'", buf_ptr(name)));
                        add_error_note(g, msg, tld->source_node, buf_sprintf("previous definition is here"));
                        variable_entry->value->type = g->builtin_types.entry_invalid;
                    }
                }
            }
        }
    }

    Scope *child_scope;
    if (source_node && source_node->type == NodeTypeParamDecl) {
        child_scope = create_var_scope(source_node, parent_scope, variable_entry);
    } else {
        // it's already in the decls table
        child_scope = parent_scope;
    }


    variable_entry->src_is_const = is_const;
    variable_entry->gen_is_const = is_const;
    variable_entry->decl_node = source_node;
    variable_entry->child_scope = child_scope;


    return variable_entry;
}

static void resolve_decl_var(CodeGen *g, TldVar *tld_var) {
    AstNode *source_node = tld_var->base.source_node;
    AstNodeVariableDeclaration *var_decl = &source_node->data.variable_declaration;

    bool is_const = var_decl->is_const;
    bool is_extern = var_decl->is_extern;
    bool is_export = var_decl->is_export;

    TypeTableEntry *explicit_type = nullptr;
    if (var_decl->type) {
        TypeTableEntry *proposed_type = analyze_type_expr(g, tld_var->base.parent_scope, var_decl->type);
        explicit_type = validate_var_type(g, var_decl->type, proposed_type);
    }

    assert(!is_export || !is_extern);

    VarLinkage linkage;
    if (is_export) {
        linkage = VarLinkageExport;
    } else if (is_extern) {
        linkage = VarLinkageExternal;
    } else {
        linkage = VarLinkageInternal;
    }

    IrInstruction *init_value = nullptr;

    // TODO more validation for types that can't be used for export/extern variables
    TypeTableEntry *implicit_type = nullptr;
    if (explicit_type && explicit_type->id == TypeTableEntryIdInvalid) {
        implicit_type = explicit_type;
    } else if (var_decl->expr) {
        init_value = analyze_const_value(g, tld_var->base.parent_scope, var_decl->expr, explicit_type, var_decl->symbol);
        assert(init_value);
        implicit_type = init_value->value.type;

        if (implicit_type->id == TypeTableEntryIdUnreachable) {
            add_node_error(g, source_node, buf_sprintf("variable initialization is unreachable"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if ((!is_const || linkage == VarLinkageExternal) &&
                (implicit_type->id == TypeTableEntryIdComptimeFloat ||
                implicit_type->id == TypeTableEntryIdComptimeInt))
        {
            add_node_error(g, source_node, buf_sprintf("unable to infer variable type"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if (implicit_type->id == TypeTableEntryIdNull) {
            add_node_error(g, source_node, buf_sprintf("unable to infer variable type"));
            implicit_type = g->builtin_types.entry_invalid;
        } else if (implicit_type->id == TypeTableEntryIdMetaType && !is_const) {
            add_node_error(g, source_node, buf_sprintf("variable of type 'type' must be constant"));
            implicit_type = g->builtin_types.entry_invalid;
        }
        assert(implicit_type->id == TypeTableEntryIdInvalid || init_value->value.special != ConstValSpecialRuntime);
    } else if (linkage != VarLinkageExternal) {
        add_node_error(g, source_node, buf_sprintf("variables must be initialized"));
        implicit_type = g->builtin_types.entry_invalid;
    }

    TypeTableEntry *type = explicit_type ? explicit_type : implicit_type;
    assert(type != nullptr); // should have been caught by the parser

    ConstExprValue *init_val = init_value ? &init_value->value : create_const_runtime(type);

    tld_var->var = add_variable(g, source_node, tld_var->base.parent_scope, var_decl->symbol,
            is_const, init_val, &tld_var->base);
    tld_var->var->linkage = linkage;

    if (implicit_type != nullptr && type_is_invalid(implicit_type)) {
        tld_var->var->value->type = g->builtin_types.entry_invalid;
    }

    if (var_decl->align_expr != nullptr) {
        if (!analyze_const_align(g, tld_var->base.parent_scope, var_decl->align_expr, &tld_var->var->align_bytes)) {
            tld_var->var->value->type = g->builtin_types.entry_invalid;
        }
    }

    if (var_decl->section_expr != nullptr) {
        if (var_decl->is_extern) {
            add_node_error(g, var_decl->section_expr,
                buf_sprintf("cannot set section of external variable '%s'", buf_ptr(var_decl->symbol)));
        } else if (!analyze_const_string(g, tld_var->base.parent_scope, var_decl->section_expr, &tld_var->section_name)) {
            tld_var->section_name = nullptr;
        }
    }

    g->global_vars.append(tld_var);
}

void resolve_top_level_decl(CodeGen *g, Tld *tld, bool pointer_only, AstNode *source_node) {
    if (tld->resolution != TldResolutionUnresolved)
        return;

    if (tld->dep_loop_flag) {
        add_node_error(g, tld->source_node, buf_sprintf("'%s' depends on itself", buf_ptr(tld->name)));
        tld->resolution = TldResolutionInvalid;
        return;
    }

    tld->dep_loop_flag = true;
    g->tld_ref_source_node_stack.append(source_node);

    switch (tld->id) {
        case TldIdVar:
            {
                TldVar *tld_var = (TldVar *)tld;
                resolve_decl_var(g, tld_var);
                break;
            }
        case TldIdFn:
            {
                TldFn *tld_fn = (TldFn *)tld;
                resolve_decl_fn(g, tld_fn);
                break;
            }
        case TldIdContainer:
            {
                TldContainer *tld_container = (TldContainer *)tld;
                resolve_decl_container(g, tld_container);
                break;
            }
        case TldIdCompTime:
            {
                TldCompTime *tld_comptime = (TldCompTime *)tld;
                resolve_decl_comptime(g, tld_comptime);
                break;
            }
    }

    tld->resolution = TldResolutionOk;
    tld->dep_loop_flag = false;
    g->tld_ref_source_node_stack.pop();
}

Tld *find_decl(CodeGen *g, Scope *scope, Buf *name) {
    // we must resolve all the use decls
    ImportTableEntry *import = get_scope_import(scope);
    for (size_t i = 0; i < import->use_decls.length; i += 1) {
        AstNode *use_decl_node = import->use_decls.at(i);
        if (use_decl_node->data.use.resolution == TldResolutionUnresolved) {
            preview_use_decl(g, use_decl_node);
            resolve_use_decl(g, use_decl_node);
        }
    }

    while (scope) {
        if (scope->id == ScopeIdDecls) {
            ScopeDecls *decls_scope = (ScopeDecls *)scope;
            auto entry = decls_scope->decl_table.maybe_get(name);
            if (entry)
                return entry->value;
        }
        scope = scope->parent;
    }
    return nullptr;
}

VariableTableEntry *find_variable(CodeGen *g, Scope *scope, Buf *name) {
    while (scope) {
        if (scope->id == ScopeIdVarDecl) {
            ScopeVarDecl *var_scope = (ScopeVarDecl *)scope;
            if (buf_eql_buf(name, &var_scope->var->name))
                return var_scope->var;
        } else if (scope->id == ScopeIdDecls) {
            ScopeDecls *decls_scope = (ScopeDecls *)scope;
            auto entry = decls_scope->decl_table.maybe_get(name);
            if (entry) {
                Tld *tld = entry->value;
                if (tld->id == TldIdVar) {
                    TldVar *tld_var = (TldVar *)tld;
                    if (tld_var->var)
                        return tld_var->var;
                }
            }
        }
        scope = scope->parent;
    }

    return nullptr;
}

FnTableEntry *scope_fn_entry(Scope *scope) {
    while (scope) {
        if (scope->id == ScopeIdFnDef) {
            ScopeFnDef *fn_scope = (ScopeFnDef *)scope;
            return fn_scope->fn_entry;
        }
        scope = scope->parent;
    }
    return nullptr;
}

FnTableEntry *scope_get_fn_if_root(Scope *scope) {
    assert(scope);
    scope = scope->parent;
    while (scope) {
        switch (scope->id) {
            case ScopeIdBlock:
                return nullptr;
            case ScopeIdDecls:
            case ScopeIdDefer:
            case ScopeIdDeferExpr:
            case ScopeIdVarDecl:
            case ScopeIdCImport:
            case ScopeIdLoop:
            case ScopeIdSuspend:
            case ScopeIdCompTime:
            case ScopeIdCoroPrelude:
                scope = scope->parent;
                continue;
            case ScopeIdFnDef:
                ScopeFnDef *fn_scope = (ScopeFnDef *)scope;
                return fn_scope->fn_entry;
        }
        zig_unreachable();
    }
    return nullptr;
}

TypeEnumField *find_enum_type_field(TypeTableEntry *enum_type, Buf *name) {
    assert(enum_type->id == TypeTableEntryIdEnum);
    if (enum_type->data.enumeration.src_field_count == 0)
        return nullptr;
    auto entry = enum_type->data.enumeration.fields_by_name.maybe_get(name);
    if (entry == nullptr)
        return nullptr;
    return entry->value;
}

TypeStructField *find_struct_type_field(TypeTableEntry *type_entry, Buf *name) {
    assert(type_entry->id == TypeTableEntryIdStruct);
    assert(type_entry->data.structure.complete);
    if (type_entry->data.structure.src_field_count == 0)
        return nullptr;
    auto entry = type_entry->data.structure.fields_by_name.maybe_get(name);
    if (entry == nullptr)
        return nullptr;
    return entry->value;
}

TypeUnionField *find_union_type_field(TypeTableEntry *type_entry, Buf *name) {
    assert(type_entry->id == TypeTableEntryIdUnion);
    assert(type_entry->data.unionation.zero_bits_known);
    if (type_entry->data.unionation.src_field_count == 0)
        return nullptr;
    auto entry = type_entry->data.unionation.fields_by_name.maybe_get(name);
    if (entry == nullptr)
        return nullptr;
    return entry->value;
}

TypeUnionField *find_union_field_by_tag(TypeTableEntry *type_entry, const BigInt *tag) {
    assert(type_entry->id == TypeTableEntryIdUnion);
    assert(type_entry->data.unionation.zero_bits_known);
    for (uint32_t i = 0; i < type_entry->data.unionation.src_field_count; i += 1) {
        TypeUnionField *field = &type_entry->data.unionation.fields[i];
        if (bigint_cmp(&field->enum_field->value, tag) == CmpEQ) {
            return field;
        }
    }
    return nullptr;
}

TypeEnumField *find_enum_field_by_tag(TypeTableEntry *enum_type, const BigInt *tag) {
    assert(enum_type->data.enumeration.zero_bits_known);
    for (uint32_t i = 0; i < enum_type->data.enumeration.src_field_count; i += 1) {
        TypeEnumField *field = &enum_type->data.enumeration.fields[i];
        if (bigint_cmp(&field->value, tag) == CmpEQ) {
            return field;
        }
    }
    return nullptr;
}


static bool is_container(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
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
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdPromise:
            return false;
    }
    zig_unreachable();
}

bool is_ref(TypeTableEntry *type_entry) {
    return type_entry->id == TypeTableEntryIdPointer && type_entry->data.pointer.ptr_len == PtrLenSingle;
}

bool is_array_ref(TypeTableEntry *type_entry) {
    TypeTableEntry *array = is_ref(type_entry) ?
        type_entry->data.pointer.child_type : type_entry;
    return array->id == TypeTableEntryIdArray;
}

bool is_container_ref(TypeTableEntry *type_entry) {
    return is_ref(type_entry) ?
        is_container(type_entry->data.pointer.child_type) : is_container(type_entry);
}

TypeTableEntry *container_ref_type(TypeTableEntry *type_entry) {
    assert(is_container_ref(type_entry));
    return is_ref(type_entry) ?
        type_entry->data.pointer.child_type : type_entry;
}

void resolve_container_type(CodeGen *g, TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdStruct:
            resolve_struct_type(g, type_entry);
            break;
        case TypeTableEntryIdEnum:
            resolve_enum_type(g, type_entry);
            break;
        case TypeTableEntryIdUnion:
            resolve_union_type(g, type_entry);
            break;
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdArray:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorUnion:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdPromise:
            zig_unreachable();
    }
}

TypeTableEntry *get_codegen_ptr_type(TypeTableEntry *type) {
    if (type->id == TypeTableEntryIdPointer) return type;
    if (type->id == TypeTableEntryIdFn) return type;
    if (type->id == TypeTableEntryIdPromise) return type;
    if (type->id == TypeTableEntryIdOptional) {
        if (type->data.maybe.child_type->id == TypeTableEntryIdPointer) return type->data.maybe.child_type;
        if (type->data.maybe.child_type->id == TypeTableEntryIdFn) return type->data.maybe.child_type;
        if (type->data.maybe.child_type->id == TypeTableEntryIdPromise) return type->data.maybe.child_type;
    }
    return nullptr;
}

bool type_is_codegen_pointer(TypeTableEntry *type) {
    return get_codegen_ptr_type(type) == type;
}

uint32_t get_ptr_align(TypeTableEntry *type) {
    TypeTableEntry *ptr_type = get_codegen_ptr_type(type);
    if (ptr_type->id == TypeTableEntryIdPointer) {
        return ptr_type->data.pointer.alignment;
    } else if (ptr_type->id == TypeTableEntryIdFn) {
        return (ptr_type->data.fn.fn_type_id.alignment == 0) ? 1 : ptr_type->data.fn.fn_type_id.alignment;
    } else if (ptr_type->id == TypeTableEntryIdPromise) {
        return 1;
    } else {
        zig_unreachable();
    }
}

bool get_ptr_const(TypeTableEntry *type) {
    TypeTableEntry *ptr_type = get_codegen_ptr_type(type);
    if (ptr_type->id == TypeTableEntryIdPointer) {
        return ptr_type->data.pointer.is_const;
    } else if (ptr_type->id == TypeTableEntryIdFn) {
        return true;
    } else if (ptr_type->id == TypeTableEntryIdPromise) {
        return true;
    } else {
        zig_unreachable();
    }
}

AstNode *get_param_decl_node(FnTableEntry *fn_entry, size_t index) {
    if (fn_entry->param_source_nodes)
        return fn_entry->param_source_nodes[index];
    else if (fn_entry->proto_node)
        return fn_entry->proto_node->data.fn_proto.params.at(index);
    else
        return nullptr;
}

static void define_local_param_variables(CodeGen *g, FnTableEntry *fn_table_entry, VariableTableEntry **arg_vars) {
    TypeTableEntry *fn_type = fn_table_entry->type_entry;
    assert(!fn_type->data.fn.is_generic);
    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;
    for (size_t i = 0; i < fn_type_id->param_count; i += 1) {
        FnTypeParamInfo *param_info = &fn_type_id->param_info[i];
        AstNode *param_decl_node = get_param_decl_node(fn_table_entry, i);
        Buf *param_name;
        bool is_var_args = param_decl_node && param_decl_node->data.param_decl.is_var_args;
        if (param_decl_node && !is_var_args) {
            param_name = param_decl_node->data.param_decl.name;
        } else {
            param_name = buf_sprintf("arg%" ZIG_PRI_usize "", i);
        }
        if (param_name == nullptr) {
            continue;
        }

        TypeTableEntry *param_type = param_info->type;
        bool is_noalias = param_info->is_noalias;

        if (is_noalias && get_codegen_ptr_type(param_type) == nullptr) {
            add_node_error(g, param_decl_node, buf_sprintf("noalias on non-pointer parameter"));
        }

        VariableTableEntry *var = add_variable(g, param_decl_node, fn_table_entry->child_scope,
                param_name, true, create_const_runtime(param_type), nullptr);
        var->src_arg_index = i;
        fn_table_entry->child_scope = var->child_scope;
        var->shadowable = var->shadowable || is_var_args;

        if (type_has_bits(param_type)) {
            fn_table_entry->variable_list.append(var);
        }

        if (fn_type->data.fn.gen_param_info) {
            var->gen_arg_index = fn_type->data.fn.gen_param_info[i].gen_index;
        }

        if (arg_vars) {
            arg_vars[i] = var;
        }
    }
}

bool resolve_inferred_error_set(CodeGen *g, TypeTableEntry *err_set_type, AstNode *source_node) {
    FnTableEntry *infer_fn = err_set_type->data.error_set.infer_fn;
    if (infer_fn != nullptr) {
        if (infer_fn->anal_state == FnAnalStateInvalid) {
            return false;
        } else if (infer_fn->anal_state == FnAnalStateReady) {
            analyze_fn_body(g, infer_fn);
            if (err_set_type->data.error_set.infer_fn != nullptr) {
                assert(g->errors.length != 0);
                return false;
            }
        } else {
            add_node_error(g, source_node,
                buf_sprintf("cannot resolve inferred error set '%s': function '%s' not fully analyzed yet",
                    buf_ptr(&err_set_type->name), buf_ptr(&err_set_type->data.error_set.infer_fn->symbol_name)));
            return false;
        }
    }
    return true;
}

void analyze_fn_ir(CodeGen *g, FnTableEntry *fn_table_entry, AstNode *return_type_node) {
    TypeTableEntry *fn_type = fn_table_entry->type_entry;
    assert(!fn_type->data.fn.is_generic);
    FnTypeId *fn_type_id = &fn_type->data.fn.fn_type_id;

    TypeTableEntry *block_return_type = ir_analyze(g, &fn_table_entry->ir_executable,
            &fn_table_entry->analyzed_executable, fn_type_id->return_type, return_type_node);
    fn_table_entry->src_implicit_return_type = block_return_type;

    if (type_is_invalid(block_return_type) || fn_table_entry->analyzed_executable.invalid) {
        assert(g->errors.length > 0);
        fn_table_entry->anal_state = FnAnalStateInvalid;
        return;
    }

    if (fn_type_id->return_type->id == TypeTableEntryIdErrorUnion) {
        TypeTableEntry *return_err_set_type = fn_type_id->return_type->data.error_union.err_set_type;
        if (return_err_set_type->data.error_set.infer_fn != nullptr) {
            TypeTableEntry *inferred_err_set_type;
            if (fn_table_entry->src_implicit_return_type->id == TypeTableEntryIdErrorSet) {
                inferred_err_set_type = fn_table_entry->src_implicit_return_type;
            } else if (fn_table_entry->src_implicit_return_type->id == TypeTableEntryIdErrorUnion) {
                inferred_err_set_type = fn_table_entry->src_implicit_return_type->data.error_union.err_set_type;
            } else {
                add_node_error(g, return_type_node,
                        buf_sprintf("function with inferred error set must return at least one possible error"));
                fn_table_entry->anal_state = FnAnalStateInvalid;
                return;
            }

            if (inferred_err_set_type->data.error_set.infer_fn != nullptr) {
                if (!resolve_inferred_error_set(g, inferred_err_set_type, return_type_node)) {
                    fn_table_entry->anal_state = FnAnalStateInvalid;
                    return;
                }
            }

            return_err_set_type->data.error_set.infer_fn = nullptr;
            if (type_is_global_error_set(inferred_err_set_type)) {
                return_err_set_type->data.error_set.err_count = UINT32_MAX;
            } else {
                return_err_set_type->data.error_set.err_count = inferred_err_set_type->data.error_set.err_count;
                if (inferred_err_set_type->data.error_set.err_count > 0) {
                    return_err_set_type->data.error_set.errors = allocate<ErrorTableEntry *>(inferred_err_set_type->data.error_set.err_count);
                    for (uint32_t i = 0; i < inferred_err_set_type->data.error_set.err_count; i += 1) {
                        return_err_set_type->data.error_set.errors[i] = inferred_err_set_type->data.error_set.errors[i];
                    }
                }
            }
        }
    }

    if (g->verbose_ir) {
        fprintf(stderr, "{ // (analyzed)\n");
        ir_print(g, stderr, &fn_table_entry->analyzed_executable, 4);
        fprintf(stderr, "}\n");
    }

    fn_table_entry->anal_state = FnAnalStateComplete;
}

static void analyze_fn_body(CodeGen *g, FnTableEntry *fn_table_entry) {
    assert(fn_table_entry->anal_state != FnAnalStateProbing);
    if (fn_table_entry->anal_state != FnAnalStateReady)
        return;

    fn_table_entry->anal_state = FnAnalStateProbing;

    AstNode *return_type_node = (fn_table_entry->proto_node != nullptr) ?
        fn_table_entry->proto_node->data.fn_proto.return_type : fn_table_entry->fndef_scope->base.source_node;

    assert(fn_table_entry->fndef_scope);
    if (!fn_table_entry->child_scope)
        fn_table_entry->child_scope = &fn_table_entry->fndef_scope->base;

    define_local_param_variables(g, fn_table_entry, nullptr);

    TypeTableEntry *fn_type = fn_table_entry->type_entry;
    assert(!fn_type->data.fn.is_generic);

    ir_gen_fn(g, fn_table_entry);
    if (fn_table_entry->ir_executable.invalid) {
        fn_table_entry->anal_state = FnAnalStateInvalid;
        return;
    }
    if (g->verbose_ir) {
        fprintf(stderr, "\n");
        ast_render(g, stderr, fn_table_entry->body_node, 4);
        fprintf(stderr, "\n{ // (IR)\n");
        ir_print(g, stderr, &fn_table_entry->ir_executable, 4);
        fprintf(stderr, "}\n");
    }

    analyze_fn_ir(g, fn_table_entry, return_type_node);
}

static void add_symbols_from_import(CodeGen *g, AstNode *src_use_node, AstNode *dst_use_node) {
    if (src_use_node->data.use.resolution == TldResolutionUnresolved) {
        preview_use_decl(g, src_use_node);
    }

    IrInstruction *use_target_value = src_use_node->data.use.value;
    if (use_target_value->value.type->id == TypeTableEntryIdInvalid) {
        dst_use_node->owner->any_imports_failed = true;
        return;
    }

    dst_use_node->data.use.resolution = TldResolutionOk;

    ConstExprValue *const_val = &use_target_value->value;
    assert(const_val->special != ConstValSpecialRuntime);

    ImportTableEntry *target_import = const_val->data.x_import;
    assert(target_import);

    if (target_import->any_imports_failed) {
        dst_use_node->owner->any_imports_failed = true;
    }

    auto it = target_import->decls_scope->decl_table.entry_iterator();
    for (;;) {
        auto *entry = it.next();
        if (!entry)
            break;

        Tld *target_tld = entry->value;
        if (target_tld->import != target_import ||
            target_tld->visib_mod == VisibModPrivate)
        {
            continue;
        }

        Buf *target_tld_name = entry->key;

        auto existing_entry = dst_use_node->owner->decls_scope->decl_table.put_unique(target_tld_name, target_tld);
        if (existing_entry) {
            Tld *existing_decl = existing_entry->value;
            if (existing_decl != target_tld) {
                ErrorMsg *msg = add_node_error(g, dst_use_node,
                        buf_sprintf("import of '%s' overrides existing definition",
                            buf_ptr(target_tld_name)));
                add_error_note(g, msg, existing_decl->source_node, buf_sprintf("previous definition here"));
                add_error_note(g, msg, target_tld->source_node, buf_sprintf("imported definition here"));
            }
        }
    }

    for (size_t i = 0; i < target_import->use_decls.length; i += 1) {
        AstNode *use_decl_node = target_import->use_decls.at(i);
        if (use_decl_node->data.use.visib_mod != VisibModPrivate)
            add_symbols_from_import(g, use_decl_node, dst_use_node);
    }
}

void resolve_use_decl(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeUse);

    if (node->data.use.resolution == TldResolutionOk ||
        node->data.use.resolution == TldResolutionInvalid)
    {
        return;
    }
    add_symbols_from_import(g, node, node);
}

void preview_use_decl(CodeGen *g, AstNode *node) {
    assert(node->type == NodeTypeUse);

    if (node->data.use.resolution == TldResolutionOk ||
        node->data.use.resolution == TldResolutionInvalid)
    {
        return;
    }

    node->data.use.resolution = TldResolutionResolving;
    IrInstruction *result = analyze_const_value(g, &node->owner->decls_scope->base,
        node->data.use.expr, g->builtin_types.entry_namespace, nullptr);

    if (result->value.type->id == TypeTableEntryIdInvalid)
        node->owner->any_imports_failed = true;

    node->data.use.value = result;
}

ImportTableEntry *add_source_file(CodeGen *g, PackageTableEntry *package, Buf *abs_full_path, Buf *source_code) {
    if (g->verbose_tokenize) {
        fprintf(stderr, "\nOriginal Source (%s):\n", buf_ptr(abs_full_path));
        fprintf(stderr, "----------------\n");
        fprintf(stderr, "%s\n", buf_ptr(source_code));

        fprintf(stderr, "\nTokens:\n");
        fprintf(stderr, "---------\n");
    }

    Tokenization tokenization = {0};
    tokenize(source_code, &tokenization);

    if (tokenization.err) {
        ErrorMsg *err = err_msg_create_with_line(abs_full_path, tokenization.err_line, tokenization.err_column,
                source_code, tokenization.line_offsets, tokenization.err);

        print_err_msg(err, g->err_color);
        exit(1);
    }

    if (g->verbose_tokenize) {
        print_tokens(source_code, tokenization.tokens);

        fprintf(stderr, "\nAST:\n");
        fprintf(stderr, "------\n");
    }

    ImportTableEntry *import_entry = allocate<ImportTableEntry>(1);
    import_entry->package = package;
    import_entry->source_code = source_code;
    import_entry->line_offsets = tokenization.line_offsets;
    import_entry->path = abs_full_path;

    import_entry->root = ast_parse(source_code, tokenization.tokens, import_entry, g->err_color);
    assert(import_entry->root);
    if (g->verbose_ast) {
        ast_print(stderr, import_entry->root, 0);
    }

    Buf *src_dirname = buf_alloc();
    Buf *src_basename = buf_alloc();
    os_path_split(abs_full_path, src_dirname, src_basename);

    import_entry->di_file = ZigLLVMCreateFile(g->dbuilder, buf_ptr(src_basename), buf_ptr(src_dirname));
    g->import_table.put(abs_full_path, import_entry);
    g->import_queue.append(import_entry);

    import_entry->decls_scope = create_decls_scope(import_entry->root, nullptr, nullptr, import_entry);


    assert(import_entry->root->type == NodeTypeRoot);
    for (size_t decl_i = 0; decl_i < import_entry->root->data.root.top_level_decls.length; decl_i += 1) {
        AstNode *top_level_decl = import_entry->root->data.root.top_level_decls.at(decl_i);

        if (top_level_decl->type == NodeTypeFnDef) {
            AstNode *proto_node = top_level_decl->data.fn_def.fn_proto;
            assert(proto_node->type == NodeTypeFnProto);
            Buf *proto_name = proto_node->data.fn_proto.name;

            bool is_pub = (proto_node->data.fn_proto.visib_mod == VisibModPub);
            bool ok_cc = (proto_node->data.fn_proto.cc == CallingConventionUnspecified ||
                    proto_node->data.fn_proto.cc == CallingConventionCold);

            if (is_pub && ok_cc) {
                if (buf_eql_str(proto_name, "main")) {
                    g->have_pub_main = true;
                    g->windows_subsystem_windows = false;
                    g->windows_subsystem_console = true;
                } else if (buf_eql_str(proto_name, "panic")) {
                    g->have_pub_panic = true;
                }
            }
        }
    }

    return import_entry;
}

void scan_import(CodeGen *g, ImportTableEntry *import) {
    if (!import->scanned) {
        import->scanned = true;
        scan_decls(g, import->decls_scope, import->root);
    }
}

void semantic_analyze(CodeGen *g) {
    for (; g->import_queue_index < g->import_queue.length; g->import_queue_index += 1) {
        ImportTableEntry *import = g->import_queue.at(g->import_queue_index);
        scan_import(g, import);
    }

    for (; g->use_queue_index < g->use_queue.length; g->use_queue_index += 1) {
        AstNode *use_decl_node = g->use_queue.at(g->use_queue_index);
        preview_use_decl(g, use_decl_node);
    }

    for (size_t i = 0; i < g->use_queue.length; i += 1) {
        AstNode *use_decl_node = g->use_queue.at(i);
        resolve_use_decl(g, use_decl_node);
    }

    while (g->resolve_queue_index < g->resolve_queue.length ||
           g->fn_defs_index < g->fn_defs.length)
    {
        for (; g->resolve_queue_index < g->resolve_queue.length; g->resolve_queue_index += 1) {
            Tld *tld = g->resolve_queue.at(g->resolve_queue_index);
            bool pointer_only = false;
            AstNode *source_node = nullptr;
            resolve_top_level_decl(g, tld, pointer_only, source_node);
        }

        for (; g->fn_defs_index < g->fn_defs.length; g->fn_defs_index += 1) {
            FnTableEntry *fn_entry = g->fn_defs.at(g->fn_defs_index);
            analyze_fn_body(g, fn_entry);
        }
    }
}

TypeTableEntry **get_int_type_ptr(CodeGen *g, bool is_signed, uint32_t size_in_bits) {
    size_t index;
    if (size_in_bits == 2) {
        index = 0;
    } else if (size_in_bits == 3) {
        index = 1;
    } else if (size_in_bits == 4) {
        index = 2;
    } else if (size_in_bits == 5) {
        index = 3;
    } else if (size_in_bits == 6) {
        index = 4;
    } else if (size_in_bits == 7) {
        index = 5;
    } else if (size_in_bits == 8) {
        index = 6;
    } else if (size_in_bits == 16) {
        index = 7;
    } else if (size_in_bits == 29) {
        index = 8;
    } else if (size_in_bits == 32) {
        index = 9;
    } else if (size_in_bits == 64) {
        index = 10;
    } else if (size_in_bits == 128) {
        index = 11;
    } else {
        return nullptr;
    }
    return &g->builtin_types.entry_int[is_signed ? 0 : 1][index];
}

TypeTableEntry *get_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits) {
    TypeTableEntry **common_entry = get_int_type_ptr(g, is_signed, size_in_bits);
    if (common_entry)
        return *common_entry;

    TypeId type_id = {};
    type_id.id = TypeTableEntryIdInt;
    type_id.data.integer.is_signed = is_signed;
    type_id.data.integer.bit_count = size_in_bits;

    {
        auto entry = g->type_table.maybe_get(type_id);
        if (entry)
            return entry->value;
    }

    TypeTableEntry *new_entry = make_int_type(g, is_signed, size_in_bits);
    g->type_table.put(type_id, new_entry);
    return new_entry;
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
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
             zig_unreachable();
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdPromise:
             return false;
        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
             return type_has_bits(type_entry);
        case TypeTableEntryIdErrorUnion:
             return type_has_bits(type_entry->data.error_union.payload_type);
        case TypeTableEntryIdOptional:
             return type_has_bits(type_entry->data.maybe.child_type) &&
                    !type_is_codegen_pointer(type_entry->data.maybe.child_type);
        case TypeTableEntryIdUnion:
             assert(type_entry->data.unionation.complete);
             if (type_entry->data.unionation.gen_field_count == 0)
                 return false;
             if (!type_has_bits(type_entry))
                 return false;
             return true;

    }
    zig_unreachable();
}

static ZigWindowsSDK *get_windows_sdk(CodeGen *g) {
    if (g->win_sdk == nullptr) {
        if (os_find_windows_sdk(&g->win_sdk)) {
            fprintf(stderr, "unable to determine windows sdk path\n");
            exit(1);
        }
    }
    assert(g->win_sdk != nullptr);
    return g->win_sdk;
}


Buf *get_linux_libc_lib_path(const char *o_file) {
    const char *cc_exe = getenv("CC");
    cc_exe = (cc_exe == nullptr) ? "cc" : cc_exe;
    ZigList<const char *> args = {};
    args.append(buf_ptr(buf_sprintf("-print-file-name=%s", o_file)));
    Termination term;
    Buf *out_stderr = buf_alloc();
    Buf *out_stdout = buf_alloc();
    int err;
    if ((err = os_exec_process(cc_exe, args, &term, out_stderr, out_stdout))) {
        zig_panic("unable to determine libc lib path: executing C compiler: %s", err_str(err));
    }
    if (term.how != TerminationIdClean || term.code != 0) {
        zig_panic("unable to determine libc lib path: executing C compiler command failed");
    }
    if (buf_ends_with_str(out_stdout, "\n")) {
        buf_resize(out_stdout, buf_len(out_stdout) - 1);
    }
    if (buf_len(out_stdout) == 0 || buf_eql_str(out_stdout, o_file)) {
        zig_panic("unable to determine libc lib path: C compiler could not find %s", o_file);
    }
    Buf *result = buf_alloc();
    os_path_dirname(out_stdout, result);
    return result;
}

Buf *get_linux_libc_include_path(void) {
    const char *cc_exe = getenv("CC");
    cc_exe = (cc_exe == nullptr) ? "cc" : cc_exe;
    ZigList<const char *> args = {};
    args.append("-E");
    args.append("-Wp,-v");
    args.append("-xc");
    args.append("/dev/null");
    Termination term;
    Buf *out_stderr = buf_alloc();
    Buf *out_stdout = buf_alloc();
    int err;
    if ((err = os_exec_process(cc_exe, args, &term, out_stderr, out_stdout))) {
        zig_panic("unable to determine libc include path: executing C compiler: %s", err_str(err));
    }
    if (term.how != TerminationIdClean || term.code != 0) {
        zig_panic("unable to determine libc include path: executing C compiler command failed");
    }
    char *prev_newline = buf_ptr(out_stderr);
    ZigList<const char *> search_paths = {};
    for (;;) {
        char *newline = strchr(prev_newline, '\n');
        if (newline == nullptr) {
            break;
        }
        *newline = 0;
        if (prev_newline[0] == ' ') {
            search_paths.append(prev_newline);
        }
        prev_newline = newline + 1;
    }
    if (search_paths.length == 0) {
        zig_panic("unable to determine libc include path: even C compiler does not know where libc headers are");
    }
    for (size_t i = 0; i < search_paths.length; i += 1) {
        // search in reverse order
        const char *search_path = search_paths.items[search_paths.length - i - 1];
        // cut off spaces
        while (*search_path == ' ') {
            search_path += 1;
        }
        Buf *stdlib_path = buf_sprintf("%s/stdlib.h", search_path);
        bool exists;
        if ((err = os_file_exists(stdlib_path, &exists))) {
            exists = false;
        }
        if (exists) {
            return buf_create_from_str(search_path);
        }
    }
    zig_panic("unable to determine libc include path: stdlib.h not found in C compiler search paths");
}

void find_libc_include_path(CodeGen *g) {
    if (g->libc_include_dir == nullptr) {

        if (g->zig_target.os == OsWindows) {
            ZigWindowsSDK *sdk = get_windows_sdk(g);
            g->libc_include_dir = buf_alloc();
            if (os_get_win32_ucrt_include_path(sdk, g->libc_include_dir)) {
                fprintf(stderr, "Unable to determine libc include path. --libc-include-dir");
                exit(1);
            }
        } else if (g->zig_target.os == OsLinux) {
            g->libc_include_dir = get_linux_libc_include_path();
        } else if (g->zig_target.os == OsMacOSX) {
            g->libc_include_dir = buf_create_from_str("/usr/include");
        } else {
            // TODO find libc at runtime for other operating systems
            zig_panic("Unable to determine libc include path.");
        }
    }
    assert(buf_len(g->libc_include_dir) != 0);
}

void find_libc_lib_path(CodeGen *g) {
    // later we can handle this better by reporting an error via the normal mechanism
    if (g->libc_lib_dir == nullptr ||
        (g->zig_target.os == OsWindows && (g->msvc_lib_dir == nullptr || g->kernel32_lib_dir == nullptr)))
    {
        if (g->zig_target.os == OsWindows) {
            ZigWindowsSDK *sdk = get_windows_sdk(g);

            if (g->msvc_lib_dir == nullptr) {
                Buf* vc_lib_dir = buf_alloc();
                if (os_get_win32_vcruntime_path(vc_lib_dir, g->zig_target.arch.arch)) {
                    fprintf(stderr, "Unable to determine vcruntime path. --msvc-lib-dir");
                    exit(1);
                }
                g->msvc_lib_dir = vc_lib_dir;
            }

            if (g->libc_lib_dir == nullptr) {
                Buf* ucrt_lib_path = buf_alloc();
                if (os_get_win32_ucrt_lib_path(sdk, ucrt_lib_path, g->zig_target.arch.arch)) {
                    fprintf(stderr, "Unable to determine ucrt path. --libc-lib-dir");
                    exit(1);
                }
                g->libc_lib_dir = ucrt_lib_path;
            }

            if (g->kernel32_lib_dir == nullptr) {
                Buf* kern_lib_path = buf_alloc();
                if (os_get_win32_kern32_path(sdk, kern_lib_path, g->zig_target.arch.arch)) {
                    fprintf(stderr, "Unable to determine kernel32 path. --kernel32-lib-dir");
                    exit(1);
                }
                g->kernel32_lib_dir = kern_lib_path;
            }

        } else if (g->zig_target.os == OsLinux) {
            g->libc_lib_dir = get_linux_libc_lib_path("crt1.o");
        } else {
            zig_panic("Unable to determine libc lib path.");
        }
    } else {
        assert(buf_len(g->libc_lib_dir) != 0);
    }

    if (g->libc_static_lib_dir == nullptr) {
        if ((g->zig_target.os == OsWindows) && (g->msvc_lib_dir != NULL)) {
            return;
        } else if (g->zig_target.os == OsLinux) {
            g->libc_static_lib_dir = get_linux_libc_lib_path("crtbegin.o");
        } else {
            zig_panic("Unable to determine libc static lib path.");
        }
    } else {
        assert(buf_len(g->libc_static_lib_dir) != 0);
    }
}

static uint32_t hash_ptr(void *ptr) {
    return (uint32_t)(((uintptr_t)ptr) % UINT32_MAX);
}

static uint32_t hash_size(size_t x) {
    return (uint32_t)(x % UINT32_MAX);
}

uint32_t fn_table_entry_hash(FnTableEntry* value) {
    return ptr_hash(value);
}

bool fn_table_entry_eql(FnTableEntry *a, FnTableEntry *b) {
    return ptr_eq(a, b);
}

uint32_t fn_type_id_hash(FnTypeId *id) {
    uint32_t result = 0;
    result += ((uint32_t)(id->cc)) * (uint32_t)3349388391;
    result += id->is_var_args ? (uint32_t)1931444534 : 0;
    result += hash_ptr(id->return_type);
    result += hash_ptr(id->async_allocator_type);
    result += id->alignment * 0xd3b3f3e2;
    for (size_t i = 0; i < id->param_count; i += 1) {
        FnTypeParamInfo *info = &id->param_info[i];
        result += info->is_noalias ? (uint32_t)892356923 : 0;
        result += hash_ptr(info->type);
    }
    return result;
}

bool fn_type_id_eql(FnTypeId *a, FnTypeId *b) {
    if (a->cc != b->cc ||
        a->return_type != b->return_type ||
        a->is_var_args != b->is_var_args ||
        a->param_count != b->param_count ||
        a->alignment != b->alignment ||
        a->async_allocator_type != b->async_allocator_type)
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

static uint32_t hash_const_val_ptr(ConstExprValue *const_val) {
    uint32_t hash_val = 0;
    switch (const_val->data.x_ptr.mut) {
        case ConstPtrMutRuntimeVar:
            hash_val += (uint32_t)3500721036;
            break;
        case ConstPtrMutComptimeConst:
            hash_val += (uint32_t)4214318515;
            break;
        case ConstPtrMutComptimeVar:
            hash_val += (uint32_t)1103195694;
            break;
    }
    switch (const_val->data.x_ptr.special) {
        case ConstPtrSpecialInvalid:
            zig_unreachable();
        case ConstPtrSpecialRef:
            hash_val += (uint32_t)2478261866;
            hash_val += hash_ptr(const_val->data.x_ptr.data.ref.pointee);
            return hash_val;
        case ConstPtrSpecialBaseArray:
            hash_val += (uint32_t)1764906839;
            hash_val += hash_ptr(const_val->data.x_ptr.data.base_array.array_val);
            hash_val += hash_size(const_val->data.x_ptr.data.base_array.elem_index);
            hash_val += const_val->data.x_ptr.data.base_array.is_cstr ? 1297263887 : 200363492;
            return hash_val;
        case ConstPtrSpecialBaseStruct:
            hash_val += (uint32_t)3518317043;
            hash_val += hash_ptr(const_val->data.x_ptr.data.base_struct.struct_val);
            hash_val += hash_size(const_val->data.x_ptr.data.base_struct.field_index);
            return hash_val;
        case ConstPtrSpecialHardCodedAddr:
            hash_val += (uint32_t)4048518294;
            hash_val += hash_size(const_val->data.x_ptr.data.hard_coded_addr.addr);
            return hash_val;
        case ConstPtrSpecialDiscard:
            hash_val += 2010123162;
            return hash_val;
        case ConstPtrSpecialFunction:
            hash_val += (uint32_t)2590901619;
            hash_val += hash_ptr(const_val->data.x_ptr.data.fn.fn_entry);
            return hash_val;
    }
    zig_unreachable();
}

static uint32_t hash_const_val(ConstExprValue *const_val) {
    assert(const_val->special == ConstValSpecialStatic);
    switch (const_val->type->id) {
        case TypeTableEntryIdOpaque:
            zig_unreachable();
        case TypeTableEntryIdBool:
            return const_val->data.x_bool ? (uint32_t)127863866 : (uint32_t)215080464;
        case TypeTableEntryIdMetaType:
            return hash_ptr(const_val->data.x_type);
        case TypeTableEntryIdVoid:
            return (uint32_t)4149439618;
        case TypeTableEntryIdInt:
        case TypeTableEntryIdComptimeInt:
            {
                uint32_t result = 1331471175;
                for (size_t i = 0; i < const_val->data.x_bigint.digit_count; i += 1) {
                    uint64_t digit = bigint_ptr(&const_val->data.x_bigint)[i];
                    result ^= ((uint32_t)(digit >> 32)) ^ (uint32_t)(result);
                }
                return result;
            }
        case TypeTableEntryIdEnum:
            {
                uint32_t result = 31643936;
                for (size_t i = 0; i < const_val->data.x_enum_tag.digit_count; i += 1) {
                    uint64_t digit = bigint_ptr(&const_val->data.x_enum_tag)[i];
                    result ^= ((uint32_t)(digit >> 32)) ^ (uint32_t)(result);
                }
                return result;
            }
        case TypeTableEntryIdFloat:
            switch (const_val->type->data.floating.bit_count) {
                case 16:
                    {
                        uint16_t result;
                        static_assert(sizeof(result) == sizeof(const_val->data.x_f16), "");
                        memcpy(&result, &const_val->data.x_f16, sizeof(result));
                        return result * 65537u;
                    }
                case 32:
                    {
                        uint32_t result;
                        memcpy(&result, &const_val->data.x_f32, 4);
                        return result ^ 4084870010;
                    }
                case 64:
                    {
                        uint32_t ints[2];
                        memcpy(&ints[0], &const_val->data.x_f64, 8);
                        return ints[0] ^ ints[1] ^ 0x22ed43c6;
                    }
                case 128:
                    {
                        uint32_t ints[4];
                        memcpy(&ints[0], &const_val->data.x_f128, 16);
                        return ints[0] ^ ints[1] ^ ints[2] ^ ints[3] ^ 0xb5ffef27;
                    }
                default:
                    zig_unreachable();
            }
        case TypeTableEntryIdComptimeFloat:
            {
                float128_t f128 = bigfloat_to_f128(&const_val->data.x_bigfloat);
                uint32_t ints[4];
                memcpy(&ints[0], &f128, 16);
                return ints[0] ^ ints[1] ^ ints[2] ^ ints[3] ^ 0xed8b3dfb;
            }
        case TypeTableEntryIdArgTuple:
            return (uint32_t)const_val->data.x_arg_tuple.start_index * (uint32_t)281907309 +
                (uint32_t)const_val->data.x_arg_tuple.end_index * (uint32_t)2290442768;
        case TypeTableEntryIdFn:
            assert(const_val->data.x_ptr.mut == ConstPtrMutComptimeConst);
            assert(const_val->data.x_ptr.special == ConstPtrSpecialFunction);
            return 3677364617 ^ hash_ptr(const_val->data.x_ptr.data.fn.fn_entry);
        case TypeTableEntryIdPointer:
            return hash_const_val_ptr(const_val);
        case TypeTableEntryIdPromise:
            // TODO better hashing algorithm
            return 223048345;
        case TypeTableEntryIdUndefined:
            return 162837799;
        case TypeTableEntryIdNull:
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
        case TypeTableEntryIdOptional:
            if (get_codegen_ptr_type(const_val->type) != nullptr) {
                return hash_const_val(const_val) * 1992916303;
            } else {
                if (const_val->data.x_optional) {
                    return hash_const_val(const_val->data.x_optional) * 1992916303;
                } else {
                    return 4016830364;
                }
            }
        case TypeTableEntryIdErrorUnion:
            // TODO better hashing algorithm
            return 3415065496;
        case TypeTableEntryIdErrorSet:
            assert(const_val->data.x_err_set != nullptr);
            return const_val->data.x_err_set->value ^ 2630160122;
        case TypeTableEntryIdNamespace:
            return hash_ptr(const_val->data.x_import);
        case TypeTableEntryIdBlock:
            return hash_ptr(const_val->data.x_block);
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdUnreachable:
            zig_unreachable();
    }
    zig_unreachable();
}

uint32_t generic_fn_type_id_hash(GenericFnTypeId *id) {
    uint32_t result = 0;
    result += hash_ptr(id->fn_entry);
    for (size_t i = 0; i < id->param_count; i += 1) {
        ConstExprValue *generic_param = &id->params[i];
        if (generic_param->special != ConstValSpecialRuntime) {
            result += hash_const_val(generic_param);
            result += hash_ptr(generic_param->type);
        }
    }
    return result;
}

bool generic_fn_type_id_eql(GenericFnTypeId *a, GenericFnTypeId *b) {
    assert(a->fn_entry);
    if (a->fn_entry != b->fn_entry) return false;
    if (a->param_count != b->param_count) return false;
    for (size_t i = 0; i < a->param_count; i += 1) {
        ConstExprValue *a_val = &a->params[i];
        ConstExprValue *b_val = &b->params[i];
        if (a_val->type != b_val->type) return false;
        if (a_val->special != ConstValSpecialRuntime && b_val->special != ConstValSpecialRuntime) {
            assert(a_val->special == ConstValSpecialStatic);
            assert(b_val->special == ConstValSpecialStatic);
            if (!const_values_equal(a_val, b_val)) {
                return false;
            }
        } else {
            assert(a_val->special == ConstValSpecialRuntime && b_val->special == ConstValSpecialRuntime);
        }
    }
    return true;
}

static bool can_mutate_comptime_var_state(ConstExprValue *value) {
    assert(value != nullptr);
    switch (value->type->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdPromise:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdEnum:
            return false;

        case TypeTableEntryIdPointer:
            return value->data.x_ptr.mut == ConstPtrMutComptimeVar;

        case TypeTableEntryIdArray:
            if (value->type->data.array.len == 0)
                return false;
            if (value->data.x_array.special == ConstArraySpecialUndef)
                return false;
            for (uint32_t i = 0; i < value->type->data.array.len; i += 1) {
                if (can_mutate_comptime_var_state(&value->data.x_array.s_none.elements[i]))
                    return true;
            }
            return false;

        case TypeTableEntryIdStruct:
            for (uint32_t i = 0; i < value->type->data.structure.src_field_count; i += 1) {
                if (can_mutate_comptime_var_state(&value->data.x_struct.fields[i]))
                    return true;
            }
            return false;

        case TypeTableEntryIdOptional:
            if (get_codegen_ptr_type(value->type) != nullptr)
                return value->data.x_ptr.mut == ConstPtrMutComptimeVar;
            if (value->data.x_optional == nullptr)
                return false;
            return can_mutate_comptime_var_state(value->data.x_optional);

        case TypeTableEntryIdErrorUnion:
            if (value->data.x_err_union.err != nullptr)
                return false;
            assert(value->data.x_err_union.payload != nullptr);
            return can_mutate_comptime_var_state(value->data.x_err_union.payload);

        case TypeTableEntryIdUnion:
            return can_mutate_comptime_var_state(value->data.x_union.payload);

        case TypeTableEntryIdArgTuple:
            zig_panic("TODO var args at comptime is currently not supported");
    }
    zig_unreachable();
}

static bool return_type_is_cacheable(TypeTableEntry *return_type) {
    switch (return_type->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdPromise:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdPointer:
            return true;

        case TypeTableEntryIdArray:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdUnion:
            return false;

        case TypeTableEntryIdOptional:
            return return_type_is_cacheable(return_type->data.maybe.child_type);

        case TypeTableEntryIdErrorUnion:
            return return_type_is_cacheable(return_type->data.error_union.payload_type);

        case TypeTableEntryIdArgTuple:
            zig_panic("TODO var args at comptime is currently not supported");
    }
    zig_unreachable();
}

bool fn_eval_cacheable(Scope *scope, TypeTableEntry *return_type) {
    if (!return_type_is_cacheable(return_type))
        return false;
    while (scope) {
        if (scope->id == ScopeIdVarDecl) {
            ScopeVarDecl *var_scope = (ScopeVarDecl *)scope;
            if (can_mutate_comptime_var_state(var_scope->var->value))
                return false;
        } else if (scope->id == ScopeIdFnDef) {
            return true;
        } else {
            zig_unreachable();
        }

        scope = scope->parent;
    }
    zig_unreachable();
}

uint32_t fn_eval_hash(Scope* scope) {
    uint32_t result = 0;
    while (scope) {
        if (scope->id == ScopeIdVarDecl) {
            ScopeVarDecl *var_scope = (ScopeVarDecl *)scope;
            result += hash_const_val(var_scope->var->value);
        } else if (scope->id == ScopeIdFnDef) {
            ScopeFnDef *fn_scope = (ScopeFnDef *)scope;
            result += hash_ptr(fn_scope->fn_entry);
            return result;
        } else {
            zig_unreachable();
        }

        scope = scope->parent;
    }
    zig_unreachable();
}

bool fn_eval_eql(Scope *a, Scope *b) {
    while (a && b) {
        if (a->id != b->id)
            return false;

        if (a->id == ScopeIdVarDecl) {
            ScopeVarDecl *a_var_scope = (ScopeVarDecl *)a;
            ScopeVarDecl *b_var_scope = (ScopeVarDecl *)b;
            if (a_var_scope->var->value->type != b_var_scope->var->value->type)
                return false;
            if (!const_values_equal(a_var_scope->var->value, b_var_scope->var->value))
                return false;
        } else if (a->id == ScopeIdFnDef) {
            ScopeFnDef *a_fn_scope = (ScopeFnDef *)a;
            ScopeFnDef *b_fn_scope = (ScopeFnDef *)b;
            if (a_fn_scope->fn_entry != b_fn_scope->fn_entry)
                return false;

            return true;
        } else {
            zig_unreachable();
        }

        a = a->parent;
        b = b->parent;
    }
    return false;
}

bool type_has_bits(TypeTableEntry *type_entry) {
    assert(type_entry);
    assert(type_entry->id != TypeTableEntryIdInvalid);
    assert(type_has_zero_bits_known(type_entry));
    return !type_entry->zero_bits;
}

bool type_requires_comptime(TypeTableEntry *type_entry) {
    switch (type_entry->id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdOpaque:
            zig_unreachable();
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
            return true;
        case TypeTableEntryIdArray:
            return type_requires_comptime(type_entry->data.array.child_type);
        case TypeTableEntryIdStruct:
            assert(type_has_zero_bits_known(type_entry));
            return type_entry->data.structure.requires_comptime;
        case TypeTableEntryIdUnion:
            assert(type_has_zero_bits_known(type_entry));
            return type_entry->data.unionation.requires_comptime;
        case TypeTableEntryIdOptional:
            return type_requires_comptime(type_entry->data.maybe.child_type);
        case TypeTableEntryIdErrorUnion:
            return type_requires_comptime(type_entry->data.error_union.payload_type);
        case TypeTableEntryIdPointer:
            if (type_entry->data.pointer.child_type->id == TypeTableEntryIdOpaque) {
                return false;
            } else {
                return type_requires_comptime(type_entry->data.pointer.child_type);
            }
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdInt:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdPromise:
            return false;
    }
    zig_unreachable();
}

void init_const_str_lit(CodeGen *g, ConstExprValue *const_val, Buf *str) {
    auto entry = g->string_literals_table.maybe_get(str);
    if (entry != nullptr) {
        *const_val = *entry->value;
        return;
    }

    const_val->special = ConstValSpecialStatic;
    const_val->type = get_array_type(g, g->builtin_types.entry_u8, buf_len(str));
    const_val->data.x_array.s_none.elements = create_const_vals(buf_len(str));

    for (size_t i = 0; i < buf_len(str); i += 1) {
        ConstExprValue *this_char = &const_val->data.x_array.s_none.elements[i];
        this_char->special = ConstValSpecialStatic;
        this_char->type = g->builtin_types.entry_u8;
        bigint_init_unsigned(&this_char->data.x_bigint, (uint8_t)buf_ptr(str)[i]);
    }

    g->string_literals_table.put(str, const_val);
}

ConstExprValue *create_const_str_lit(CodeGen *g, Buf *str) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_str_lit(g, const_val, str);
    return const_val;
}

void init_const_c_str_lit(CodeGen *g, ConstExprValue *const_val, Buf *str) {
    // first we build the underlying array
    size_t len_with_null = buf_len(str) + 1;
    ConstExprValue *array_val = create_const_vals(1);
    array_val->special = ConstValSpecialStatic;
    array_val->type = get_array_type(g, g->builtin_types.entry_u8, len_with_null);
    array_val->data.x_array.s_none.elements = create_const_vals(len_with_null);
    for (size_t i = 0; i < buf_len(str); i += 1) {
        ConstExprValue *this_char = &array_val->data.x_array.s_none.elements[i];
        this_char->special = ConstValSpecialStatic;
        this_char->type = g->builtin_types.entry_u8;
        bigint_init_unsigned(&this_char->data.x_bigint, (uint8_t)buf_ptr(str)[i]);
    }
    ConstExprValue *null_char = &array_val->data.x_array.s_none.elements[len_with_null - 1];
    null_char->special = ConstValSpecialStatic;
    null_char->type = g->builtin_types.entry_u8;
    bigint_init_unsigned(&null_char->data.x_bigint, 0);

    // then make the pointer point to it
    const_val->special = ConstValSpecialStatic;
    // TODO make this `[*]null u8` instead of `[*]u8`
    const_val->type = get_pointer_to_type_extra(g, g->builtin_types.entry_u8, true, false,
            PtrLenUnknown, get_abi_alignment(g, g->builtin_types.entry_u8), 0, 0);
    const_val->data.x_ptr.special = ConstPtrSpecialBaseArray;
    const_val->data.x_ptr.data.base_array.array_val = array_val;
    const_val->data.x_ptr.data.base_array.elem_index = 0;
    const_val->data.x_ptr.data.base_array.is_cstr = true;
}
ConstExprValue *create_const_c_str_lit(CodeGen *g, Buf *str) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_c_str_lit(g, const_val, str);
    return const_val;
}

void init_const_bigint(ConstExprValue *const_val, TypeTableEntry *type, const BigInt *bigint) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = type;
    bigint_init_bigint(&const_val->data.x_bigint, bigint);
}

ConstExprValue *create_const_bigint(TypeTableEntry *type, const BigInt *bigint) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_bigint(const_val, type, bigint);
    return const_val;
}


void init_const_unsigned_negative(ConstExprValue *const_val, TypeTableEntry *type, uint64_t x, bool negative) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = type;
    bigint_init_unsigned(&const_val->data.x_bigint, x);
    const_val->data.x_bigint.is_negative = negative;
}

ConstExprValue *create_const_unsigned_negative(TypeTableEntry *type, uint64_t x, bool negative) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_unsigned_negative(const_val, type, x, negative);
    return const_val;
}

void init_const_usize(CodeGen *g, ConstExprValue *const_val, uint64_t x) {
    return init_const_unsigned_negative(const_val, g->builtin_types.entry_usize, x, false);
}

ConstExprValue *create_const_usize(CodeGen *g, uint64_t x) {
    return create_const_unsigned_negative(g->builtin_types.entry_usize, x, false);
}

void init_const_signed(ConstExprValue *const_val, TypeTableEntry *type, int64_t x) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = type;
    bigint_init_signed(&const_val->data.x_bigint, x);
}

ConstExprValue *create_const_signed(TypeTableEntry *type, int64_t x) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_signed(const_val, type, x);
    return const_val;
}

void init_const_float(ConstExprValue *const_val, TypeTableEntry *type, double value) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = type;
    if (type->id == TypeTableEntryIdComptimeFloat) {
        bigfloat_init_64(&const_val->data.x_bigfloat, value);
    } else if (type->id == TypeTableEntryIdFloat) {
        switch (type->data.floating.bit_count) {
            case 16:
                const_val->data.x_f16 = zig_double_to_f16(value);
                break;
            case 32:
                const_val->data.x_f32 = value;
                break;
            case 64:
                const_val->data.x_f64 = value;
                break;
            case 128:
                // if we need this, we should add a function that accepts a float128_t param
                zig_unreachable();
            default:
                zig_unreachable();
        }
    } else {
        zig_unreachable();
    }
}

ConstExprValue *create_const_float(TypeTableEntry *type, double value) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_float(const_val, type, value);
    return const_val;
}

void init_const_enum(ConstExprValue *const_val, TypeTableEntry *type, const BigInt *tag) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = type;
    bigint_init_bigint(&const_val->data.x_enum_tag, tag);
}

ConstExprValue *create_const_enum(TypeTableEntry *type, const BigInt *tag) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_enum(const_val, type, tag);
    return const_val;
}


void init_const_bool(CodeGen *g, ConstExprValue *const_val, bool value) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = g->builtin_types.entry_bool;
    const_val->data.x_bool = value;
}

ConstExprValue *create_const_bool(CodeGen *g, bool value) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_bool(g, const_val, value);
    return const_val;
}

void init_const_runtime(ConstExprValue *const_val, TypeTableEntry *type) {
    const_val->special = ConstValSpecialRuntime;
    const_val->type = type;
}

ConstExprValue *create_const_runtime(TypeTableEntry *type) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_runtime(const_val, type);
    return const_val;
}

void init_const_type(CodeGen *g, ConstExprValue *const_val, TypeTableEntry *type_value) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = g->builtin_types.entry_type;
    const_val->data.x_type = type_value;
}

ConstExprValue *create_const_type(CodeGen *g, TypeTableEntry *type_value) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_type(g, const_val, type_value);
    return const_val;
}

void init_const_slice(CodeGen *g, ConstExprValue *const_val, ConstExprValue *array_val,
        size_t start, size_t len, bool is_const)
{
    assert(array_val->type->id == TypeTableEntryIdArray);

    TypeTableEntry *ptr_type = get_pointer_to_type_extra(g, array_val->type->data.array.child_type,
            is_const, false, PtrLenUnknown, get_abi_alignment(g, array_val->type->data.array.child_type),
            0, 0);

    const_val->special = ConstValSpecialStatic;
    const_val->type = get_slice_type(g, ptr_type);
    const_val->data.x_struct.fields = create_const_vals(2);

    init_const_ptr_array(g, &const_val->data.x_struct.fields[slice_ptr_index], array_val, start, is_const,
            PtrLenUnknown);
    init_const_usize(g, &const_val->data.x_struct.fields[slice_len_index], len);
}

ConstExprValue *create_const_slice(CodeGen *g, ConstExprValue *array_val, size_t start, size_t len, bool is_const) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_slice(g, const_val, array_val, start, len, is_const);
    return const_val;
}

void init_const_ptr_array(CodeGen *g, ConstExprValue *const_val, ConstExprValue *array_val,
        size_t elem_index, bool is_const, PtrLen ptr_len)
{
    assert(array_val->type->id == TypeTableEntryIdArray);
    TypeTableEntry *child_type = array_val->type->data.array.child_type;

    const_val->special = ConstValSpecialStatic;
    const_val->type = get_pointer_to_type_extra(g, child_type, is_const, false,
            ptr_len, get_abi_alignment(g, child_type), 0, 0);
    const_val->data.x_ptr.special = ConstPtrSpecialBaseArray;
    const_val->data.x_ptr.data.base_array.array_val = array_val;
    const_val->data.x_ptr.data.base_array.elem_index = elem_index;
}

ConstExprValue *create_const_ptr_array(CodeGen *g, ConstExprValue *array_val, size_t elem_index, bool is_const,
        PtrLen ptr_len)
{
    ConstExprValue *const_val = create_const_vals(1);
    init_const_ptr_array(g, const_val, array_val, elem_index, is_const, ptr_len);
    return const_val;
}

void init_const_ptr_ref(CodeGen *g, ConstExprValue *const_val, ConstExprValue *pointee_val, bool is_const) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = get_pointer_to_type(g, pointee_val->type, is_const);
    const_val->data.x_ptr.special = ConstPtrSpecialRef;
    const_val->data.x_ptr.data.ref.pointee = pointee_val;
}

ConstExprValue *create_const_ptr_ref(CodeGen *g, ConstExprValue *pointee_val, bool is_const) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_ptr_ref(g, const_val, pointee_val, is_const);
    return const_val;
}

void init_const_ptr_hard_coded_addr(CodeGen *g, ConstExprValue *const_val, TypeTableEntry *pointee_type,
        size_t addr, bool is_const)
{
    const_val->special = ConstValSpecialStatic;
    const_val->type = get_pointer_to_type(g, pointee_type, is_const);
    const_val->data.x_ptr.special = ConstPtrSpecialHardCodedAddr;
    const_val->data.x_ptr.data.hard_coded_addr.addr = addr;
}

ConstExprValue *create_const_ptr_hard_coded_addr(CodeGen *g, TypeTableEntry *pointee_type,
        size_t addr, bool is_const)
{
    ConstExprValue *const_val = create_const_vals(1);
    init_const_ptr_hard_coded_addr(g, const_val, pointee_type, addr, is_const);
    return const_val;
}

void init_const_arg_tuple(CodeGen *g, ConstExprValue *const_val, size_t arg_index_start, size_t arg_index_end) {
    const_val->special = ConstValSpecialStatic;
    const_val->type = g->builtin_types.entry_arg_tuple;
    const_val->data.x_arg_tuple.start_index = arg_index_start;
    const_val->data.x_arg_tuple.end_index = arg_index_end;
}

ConstExprValue *create_const_arg_tuple(CodeGen *g, size_t arg_index_start, size_t arg_index_end) {
    ConstExprValue *const_val = create_const_vals(1);
    init_const_arg_tuple(g, const_val, arg_index_start, arg_index_end);
    return const_val;
}


void init_const_undefined(CodeGen *g, ConstExprValue *const_val) {
    TypeTableEntry *wanted_type = const_val->type;
    if (wanted_type->id == TypeTableEntryIdArray) {
        const_val->special = ConstValSpecialStatic;
        const_val->data.x_array.special = ConstArraySpecialUndef;
    } else if (wanted_type->id == TypeTableEntryIdStruct) {
        ensure_complete_type(g, wanted_type);
        if (type_is_invalid(wanted_type)) {
            return;
        }

        const_val->special = ConstValSpecialStatic;
        size_t field_count = wanted_type->data.structure.src_field_count;
        const_val->data.x_struct.fields = create_const_vals(field_count);
        for (size_t i = 0; i < field_count; i += 1) {
            ConstExprValue *field_val = &const_val->data.x_struct.fields[i];
            field_val->type = wanted_type->data.structure.fields[i].type_entry;
            assert(field_val->type);
            init_const_undefined(g, field_val);
            ConstParent *parent = get_const_val_parent(g, field_val);
            if (parent != nullptr) {
                parent->id = ConstParentIdStruct;
                parent->data.p_struct.struct_val = const_val;
                parent->data.p_struct.field_index = i;
            }
        }
    } else {
        const_val->special = ConstValSpecialUndef;
    }
}

ConstExprValue *create_const_vals(size_t count) {
    ConstGlobalRefs *global_refs = allocate<ConstGlobalRefs>(count);
    ConstExprValue *vals = allocate<ConstExprValue>(count);
    for (size_t i = 0; i < count; i += 1) {
        vals[i].global_refs = &global_refs[i];
    }
    return vals;
}

void ensure_complete_type(CodeGen *g, TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdStruct) {
        if (!type_entry->data.structure.complete)
            resolve_struct_type(g, type_entry);
    } else if (type_entry->id == TypeTableEntryIdEnum) {
        if (!type_entry->data.enumeration.complete)
            resolve_enum_type(g, type_entry);
    } else if (type_entry->id == TypeTableEntryIdUnion) {
        if (!type_entry->data.unionation.complete)
            resolve_union_type(g, type_entry);
    }
}

void type_ensure_zero_bits_known(CodeGen *g, TypeTableEntry *type_entry) {
    if (type_entry->id == TypeTableEntryIdStruct) {
        resolve_struct_zero_bits(g, type_entry);
    } else if (type_entry->id == TypeTableEntryIdEnum) {
        resolve_enum_zero_bits(g, type_entry);
    } else if (type_entry->id == TypeTableEntryIdUnion) {
        resolve_union_zero_bits(g, type_entry);
    }
}

bool ir_get_var_is_comptime(VariableTableEntry *var) {
    if (!var->is_comptime)
        return false;
    if (var->is_comptime->other)
        return var->is_comptime->other->value.data.x_bool;
    return var->is_comptime->value.data.x_bool;
}

bool const_values_equal_ptr(ConstExprValue *a, ConstExprValue *b) {
    if (a->data.x_ptr.special != b->data.x_ptr.special)
        return false;
    if (a->data.x_ptr.mut != b->data.x_ptr.mut)
        return false;
    switch (a->data.x_ptr.special) {
        case ConstPtrSpecialInvalid:
            zig_unreachable();
        case ConstPtrSpecialRef:
            if (a->data.x_ptr.data.ref.pointee != b->data.x_ptr.data.ref.pointee)
                return false;
            return true;
        case ConstPtrSpecialBaseArray:
            if (a->data.x_ptr.data.base_array.array_val != b->data.x_ptr.data.base_array.array_val &&
                a->data.x_ptr.data.base_array.array_val->global_refs !=
                b->data.x_ptr.data.base_array.array_val->global_refs)
            {
                return false;
            }
            if (a->data.x_ptr.data.base_array.elem_index != b->data.x_ptr.data.base_array.elem_index)
                return false;
            if (a->data.x_ptr.data.base_array.is_cstr != b->data.x_ptr.data.base_array.is_cstr)
                return false;
            return true;
        case ConstPtrSpecialBaseStruct:
            if (a->data.x_ptr.data.base_struct.struct_val != b->data.x_ptr.data.base_struct.struct_val &&
                a->data.x_ptr.data.base_struct.struct_val->global_refs !=
                b->data.x_ptr.data.base_struct.struct_val->global_refs)
            {
                return false;
            }
            if (a->data.x_ptr.data.base_struct.field_index != b->data.x_ptr.data.base_struct.field_index)
                return false;
            return true;
        case ConstPtrSpecialHardCodedAddr:
            if (a->data.x_ptr.data.hard_coded_addr.addr != b->data.x_ptr.data.hard_coded_addr.addr)
                return false;
            return true;
        case ConstPtrSpecialDiscard:
            return true;
        case ConstPtrSpecialFunction:
            return a->data.x_ptr.data.fn.fn_entry == b->data.x_ptr.data.fn.fn_entry;
    }
    zig_unreachable();
}

bool const_values_equal(ConstExprValue *a, ConstExprValue *b) {
    assert(a->type->id == b->type->id);
    assert(a->special == ConstValSpecialStatic);
    assert(b->special == ConstValSpecialStatic);
    switch (a->type->id) {
        case TypeTableEntryIdOpaque:
            zig_unreachable();
        case TypeTableEntryIdEnum:
            return bigint_cmp(&a->data.x_enum_tag, &b->data.x_enum_tag) == CmpEQ;
        case TypeTableEntryIdUnion: {
            ConstUnionValue *union1 = &a->data.x_union;
            ConstUnionValue *union2 = &b->data.x_union;

            if (bigint_cmp(&union1->tag, &union2->tag) == CmpEQ) {
                TypeUnionField *field = find_union_field_by_tag(a->type, &union1->tag);
                assert(field != nullptr);
                if (type_has_bits(field->type_entry)) {
                    zig_panic("TODO const expr analyze union field value for equality");
                } else {
                    return true;
                }
            }
            return false;
        }
        case TypeTableEntryIdMetaType:
            return a->data.x_type == b->data.x_type;
        case TypeTableEntryIdVoid:
            return true;
        case TypeTableEntryIdErrorSet:
            return a->data.x_err_set->value == b->data.x_err_set->value;
        case TypeTableEntryIdBool:
            return a->data.x_bool == b->data.x_bool;
        case TypeTableEntryIdFloat:
            assert(a->type->data.floating.bit_count == b->type->data.floating.bit_count);
            switch (a->type->data.floating.bit_count) {
                case 16:
                    return f16_eq(a->data.x_f16, b->data.x_f16);
                case 32:
                    return a->data.x_f32 == b->data.x_f32;
                case 64:
                    return a->data.x_f64 == b->data.x_f64;
                case 128:
                    return f128M_eq(&a->data.x_f128, &b->data.x_f128);
                default:
                    zig_unreachable();
            }
        case TypeTableEntryIdComptimeFloat:
            return bigfloat_cmp(&a->data.x_bigfloat, &b->data.x_bigfloat) == CmpEQ;
        case TypeTableEntryIdInt:
        case TypeTableEntryIdComptimeInt:
            return bigint_cmp(&a->data.x_bigint, &b->data.x_bigint) == CmpEQ;
        case TypeTableEntryIdPointer:
        case TypeTableEntryIdFn:
            return const_values_equal_ptr(a, b);
        case TypeTableEntryIdArray: {
            assert(a->type->data.array.len == b->type->data.array.len);
            assert(a->data.x_array.special != ConstArraySpecialUndef);
            assert(b->data.x_array.special != ConstArraySpecialUndef);

            size_t len = a->type->data.array.len;
            ConstExprValue *a_elems = a->data.x_array.s_none.elements;
            ConstExprValue *b_elems = b->data.x_array.s_none.elements;

            for (size_t i = 0; i < len; ++i) {
                if (!const_values_equal(&a_elems[i], &b_elems[i]))
                    return false;
            }

            return true;
        }
        case TypeTableEntryIdStruct:
            for (size_t i = 0; i < a->type->data.structure.src_field_count; i += 1) {
                ConstExprValue *field_a = &a->data.x_struct.fields[i];
                ConstExprValue *field_b = &b->data.x_struct.fields[i];
                if (!const_values_equal(field_a, field_b))
                    return false;
            }
            return true;
        case TypeTableEntryIdUndefined:
            zig_panic("TODO");
        case TypeTableEntryIdNull:
            zig_panic("TODO");
        case TypeTableEntryIdOptional:
            if (get_codegen_ptr_type(a->type) != nullptr)
                return const_values_equal_ptr(a, b);
            if (a->data.x_optional == nullptr || b->data.x_optional == nullptr) {
                return (a->data.x_optional == nullptr && b->data.x_optional == nullptr);
            } else {
                return const_values_equal(a->data.x_optional, b->data.x_optional);
            }
        case TypeTableEntryIdErrorUnion:
            zig_panic("TODO");
        case TypeTableEntryIdNamespace:
            return a->data.x_import == b->data.x_import;
        case TypeTableEntryIdBlock:
            return a->data.x_block == b->data.x_block;
        case TypeTableEntryIdArgTuple:
            return a->data.x_arg_tuple.start_index == b->data.x_arg_tuple.start_index &&
                   a->data.x_arg_tuple.end_index == b->data.x_arg_tuple.end_index;
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdPromise:
            zig_unreachable();
    }
    zig_unreachable();
}

void eval_min_max_value_int(CodeGen *g, TypeTableEntry *int_type, BigInt *bigint, bool is_max) {
    assert(int_type->id == TypeTableEntryIdInt);
    if (int_type->data.integral.bit_count == 0) {
        bigint_init_unsigned(bigint, 0);
        return;
    }
    if (is_max) {
        // is_signed=true   (1 << (bit_count - 1)) - 1
        // is_signed=false  (1 << (bit_count - 0)) - 1
        BigInt one = {0};
        bigint_init_unsigned(&one, 1);

        size_t shift_amt = int_type->data.integral.bit_count - (int_type->data.integral.is_signed ? 1 : 0);
        BigInt bit_count_bi = {0};
        bigint_init_unsigned(&bit_count_bi, shift_amt);

        BigInt shifted_bi = {0};
        bigint_shl(&shifted_bi, &one, &bit_count_bi);

        bigint_sub(bigint, &shifted_bi, &one);
    } else if (int_type->data.integral.is_signed) {
        // - (1 << (bit_count - 1))
        BigInt one = {0};
        bigint_init_unsigned(&one, 1);

        BigInt bit_count_bi = {0};
        bigint_init_unsigned(&bit_count_bi, int_type->data.integral.bit_count - 1);

        BigInt shifted_bi = {0};
        bigint_shl(&shifted_bi, &one, &bit_count_bi);

        bigint_negate(bigint, &shifted_bi);
    } else {
        bigint_init_unsigned(bigint, 0);
    }
}

void eval_min_max_value(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val, bool is_max) {
    if (type_entry->id == TypeTableEntryIdInt) {
        const_val->special = ConstValSpecialStatic;
        eval_min_max_value_int(g, type_entry, &const_val->data.x_bigint, is_max);
    } else if (type_entry->id == TypeTableEntryIdFloat) {
        zig_panic("TODO analyze_min_max_value float");
    } else if (type_entry->id == TypeTableEntryIdBool) {
        const_val->special = ConstValSpecialStatic;
        const_val->data.x_bool = is_max;
    } else if (type_entry->id == TypeTableEntryIdVoid) {
        // nothing to do
    } else {
        zig_unreachable();
    }
}

void render_const_val_ptr(CodeGen *g, Buf *buf, ConstExprValue *const_val, TypeTableEntry *type_entry) {
    switch (const_val->data.x_ptr.special) {
        case ConstPtrSpecialInvalid:
            zig_unreachable();
        case ConstPtrSpecialRef:
        case ConstPtrSpecialBaseStruct:
            buf_appendf(buf, "*");
            render_const_value(g, buf, const_ptr_pointee(g, const_val));
            return;
        case ConstPtrSpecialBaseArray:
            if (const_val->data.x_ptr.data.base_array.is_cstr) {
                buf_appendf(buf, "*(c str lit)");
                return;
            } else {
                buf_appendf(buf, "*");
                render_const_value(g, buf, const_ptr_pointee(g, const_val));
                return;
            }
        case ConstPtrSpecialHardCodedAddr:
            buf_appendf(buf, "(%s)(%" ZIG_PRI_x64 ")", buf_ptr(&type_entry->name),
                    const_val->data.x_ptr.data.hard_coded_addr.addr);
            return;
        case ConstPtrSpecialDiscard:
            buf_append_str(buf, "*_");
            return;
        case ConstPtrSpecialFunction:
            {
                FnTableEntry *fn_entry = const_val->data.x_ptr.data.fn.fn_entry;
                buf_appendf(buf, "@ptrCast(%s, %s)", buf_ptr(&const_val->type->name), buf_ptr(&fn_entry->symbol_name));
                return;
            }
    }
    zig_unreachable();
}

void render_const_value(CodeGen *g, Buf *buf, ConstExprValue *const_val) {
    switch (const_val->special) {
        case ConstValSpecialRuntime:
            buf_appendf(buf, "(runtime value)");
            return;
        case ConstValSpecialUndef:
            buf_appendf(buf, "undefined");
            return;
        case ConstValSpecialStatic:
            break;
    }
    assert(const_val->type);

    TypeTableEntry *type_entry = const_val->type;
    switch (type_entry->id) {
        case TypeTableEntryIdOpaque:
            zig_unreachable();
        case TypeTableEntryIdInvalid:
            buf_appendf(buf, "(invalid)");
            return;
        case TypeTableEntryIdVoid:
            buf_appendf(buf, "{}");
            return;
        case TypeTableEntryIdComptimeFloat:
            bigfloat_append_buf(buf, &const_val->data.x_bigfloat);
            return;
        case TypeTableEntryIdFloat:
            switch (type_entry->data.floating.bit_count) {
                case 16:
                    buf_appendf(buf, "%f", zig_f16_to_double(const_val->data.x_f16));
                    return;
                case 32:
                    buf_appendf(buf, "%f", const_val->data.x_f32);
                    return;
                case 64:
                    buf_appendf(buf, "%f", const_val->data.x_f64);
                    return;
                case 128:
                    {
                        const size_t extra_len = 100;
                        size_t old_len = buf_len(buf);
                        buf_resize(buf, old_len + extra_len);
                        float64_t f64_value = f128M_to_f64(&const_val->data.x_f128);
                        double double_value;
                        memcpy(&double_value, &f64_value, sizeof(double));
                        // TODO actual f128 printing to decimal
                        int len = snprintf(buf_ptr(buf) + old_len, extra_len, "%f", double_value);
                        assert(len > 0);
                        buf_resize(buf, old_len + len);
                        return;
                    }
                default:
                    zig_unreachable();
            }
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdInt:
            bigint_append_buf(buf, &const_val->data.x_bigint, 10);
            return;
        case TypeTableEntryIdMetaType:
            buf_appendf(buf, "%s", buf_ptr(&const_val->data.x_type->name));
            return;
        case TypeTableEntryIdUnreachable:
            buf_appendf(buf, "unreachable");
            return;
        case TypeTableEntryIdBool:
            {
                const char *value = const_val->data.x_bool ? "true" : "false";
                buf_appendf(buf, "%s", value);
                return;
            }
        case TypeTableEntryIdFn:
            {
                assert(const_val->data.x_ptr.mut == ConstPtrMutComptimeConst);
                assert(const_val->data.x_ptr.special == ConstPtrSpecialFunction);
                FnTableEntry *fn_entry = const_val->data.x_ptr.data.fn.fn_entry;
                buf_appendf(buf, "%s", buf_ptr(&fn_entry->symbol_name));
                return;
            }
        case TypeTableEntryIdPointer:
            return render_const_val_ptr(g, buf, const_val, type_entry);
        case TypeTableEntryIdBlock:
            {
                AstNode *node = const_val->data.x_block->source_node;
                buf_appendf(buf, "(scope:%" ZIG_PRI_usize ":%" ZIG_PRI_usize ")", node->line + 1, node->column + 1);
                return;
            }
        case TypeTableEntryIdArray:
            {
                TypeTableEntry *child_type = type_entry->data.array.child_type;
                uint64_t len = type_entry->data.array.len;

                if (const_val->data.x_array.special == ConstArraySpecialUndef) {
                    buf_append_str(buf, "undefined");
                    return;
                }

                // if it's []u8, assume UTF-8 and output a string
                if (child_type->id == TypeTableEntryIdInt &&
                    child_type->data.integral.bit_count == 8 &&
                    !child_type->data.integral.is_signed)
                {
                    buf_append_char(buf, '"');
                    for (uint64_t i = 0; i < len; i += 1) {
                        ConstExprValue *child_value = &const_val->data.x_array.s_none.elements[i];
                        uint64_t big_c = bigint_as_unsigned(&child_value->data.x_bigint);
                        assert(big_c <= UINT8_MAX);
                        uint8_t c = (uint8_t)big_c;
                        if (c == '"') {
                            buf_append_str(buf, "\\\"");
                        } else {
                            buf_append_char(buf, c);
                        }
                    }
                    buf_append_char(buf, '"');
                    return;
                }

                buf_appendf(buf, "%s{", buf_ptr(&type_entry->name));
                for (uint64_t i = 0; i < len; i += 1) {
                    if (i != 0)
                        buf_appendf(buf, ",");
                    ConstExprValue *child_value = &const_val->data.x_array.s_none.elements[i];
                    render_const_value(g, buf, child_value);
                }
                buf_appendf(buf, "}");
                return;
            }
        case TypeTableEntryIdNull:
            {
                buf_appendf(buf, "null");
                return;
            }
        case TypeTableEntryIdUndefined:
            {
                buf_appendf(buf, "undefined");
                return;
            }
        case TypeTableEntryIdOptional:
            {
                if (get_codegen_ptr_type(const_val->type) != nullptr)
                    return render_const_val_ptr(g, buf, const_val, type_entry->data.maybe.child_type);
                if (const_val->data.x_optional) {
                    render_const_value(g, buf, const_val->data.x_optional);
                } else {
                    buf_appendf(buf, "null");
                }
                return;
            }
        case TypeTableEntryIdNamespace:
            {
                ImportTableEntry *import = const_val->data.x_import;
                if (import->c_import_node) {
                    buf_appendf(buf, "(namespace from C import)");
                } else {
                    buf_appendf(buf, "(namespace: %s)", buf_ptr(import->path));
                }
                return;
            }
        case TypeTableEntryIdBoundFn:
            {
                FnTableEntry *fn_entry = const_val->data.x_bound_fn.fn;
                buf_appendf(buf, "(bound fn %s)", buf_ptr(&fn_entry->symbol_name));
                return;
            }
        case TypeTableEntryIdStruct:
            {
                buf_appendf(buf, "(struct %s constant)", buf_ptr(&type_entry->name));
                return;
            }
        case TypeTableEntryIdEnum:
            {
                TypeEnumField *field = find_enum_field_by_tag(type_entry, &const_val->data.x_enum_tag);
                buf_appendf(buf, "%s.%s", buf_ptr(&type_entry->name), buf_ptr(field->name));
                return;
            }
        case TypeTableEntryIdErrorUnion:
            {
                buf_appendf(buf, "(error union %s constant)", buf_ptr(&type_entry->name));
                return;
            }
        case TypeTableEntryIdUnion:
            {
                buf_appendf(buf, "(union %s constant)", buf_ptr(&type_entry->name));
                return;
            }
        case TypeTableEntryIdErrorSet:
            {
                buf_appendf(buf, "%s.%s", buf_ptr(&type_entry->name), buf_ptr(&const_val->data.x_err_set->name));
                return;
            }
        case TypeTableEntryIdArgTuple:
            {
                buf_appendf(buf, "(args value)");
                return;
            }
        case TypeTableEntryIdPromise:
            zig_unreachable();
    }
    zig_unreachable();
}

TypeTableEntry *make_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits) {
    TypeTableEntry *entry = new_type_table_entry(TypeTableEntryIdInt);
    entry->is_copyable = true;
    entry->type_ref = (size_in_bits == 0) ? LLVMVoidType() : LLVMIntType(size_in_bits);
    entry->zero_bits = (size_in_bits == 0);

    const char u_or_i = is_signed ? 'i' : 'u';
    buf_resize(&entry->name, 0);
    buf_appendf(&entry->name, "%c%" PRIu32, u_or_i, size_in_bits);

    unsigned dwarf_tag;
    if (is_signed) {
        if (size_in_bits == 8) {
            dwarf_tag = ZigLLVMEncoding_DW_ATE_signed_char();
        } else {
            dwarf_tag = ZigLLVMEncoding_DW_ATE_signed();
        }
    } else {
        if (size_in_bits == 8) {
            dwarf_tag = ZigLLVMEncoding_DW_ATE_unsigned_char();
        } else {
            dwarf_tag = ZigLLVMEncoding_DW_ATE_unsigned();
        }
    }

    uint64_t debug_size_in_bits = (size_in_bits == 0) ?
        0 : (8*LLVMStoreSizeOfType(g->target_data_ref, entry->type_ref));
    entry->di_type = ZigLLVMCreateDebugBasicType(g->dbuilder, buf_ptr(&entry->name), debug_size_in_bits, dwarf_tag);
    entry->data.integral.is_signed = is_signed;
    entry->data.integral.bit_count = size_in_bits;
    return entry;
}

uint32_t type_id_hash(TypeId x) {
    switch (x.id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdOpaque:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdPromise:
            zig_unreachable();
        case TypeTableEntryIdErrorUnion:
            return hash_ptr(x.data.error_union.err_set_type) ^ hash_ptr(x.data.error_union.payload_type);
        case TypeTableEntryIdPointer:
            return hash_ptr(x.data.pointer.child_type) +
                ((x.data.pointer.ptr_len == PtrLenSingle) ? (uint32_t)1120226602 : (uint32_t)3200913342) +
                (x.data.pointer.is_const ? (uint32_t)2749109194 : (uint32_t)4047371087) +
                (x.data.pointer.is_volatile ? (uint32_t)536730450 : (uint32_t)1685612214) +
                (((uint32_t)x.data.pointer.alignment) ^ (uint32_t)0x777fbe0e) +
                (((uint32_t)x.data.pointer.bit_offset) ^ (uint32_t)2639019452) +
                (((uint32_t)x.data.pointer.unaligned_bit_count) ^ (uint32_t)529908881);
        case TypeTableEntryIdArray:
            return hash_ptr(x.data.array.child_type) +
                ((uint32_t)x.data.array.size ^ (uint32_t)2122979968);
        case TypeTableEntryIdInt:
            return (x.data.integer.is_signed ? (uint32_t)2652528194 : (uint32_t)163929201) +
                    (((uint32_t)x.data.integer.bit_count) ^ (uint32_t)2998081557);
    }
    zig_unreachable();
}

bool type_id_eql(TypeId a, TypeId b) {
    if (a.id != b.id)
        return false;
    switch (a.id) {
        case TypeTableEntryIdInvalid:
        case TypeTableEntryIdMetaType:
        case TypeTableEntryIdVoid:
        case TypeTableEntryIdBool:
        case TypeTableEntryIdUnreachable:
        case TypeTableEntryIdFloat:
        case TypeTableEntryIdStruct:
        case TypeTableEntryIdComptimeFloat:
        case TypeTableEntryIdComptimeInt:
        case TypeTableEntryIdUndefined:
        case TypeTableEntryIdNull:
        case TypeTableEntryIdOptional:
        case TypeTableEntryIdPromise:
        case TypeTableEntryIdErrorSet:
        case TypeTableEntryIdEnum:
        case TypeTableEntryIdUnion:
        case TypeTableEntryIdFn:
        case TypeTableEntryIdNamespace:
        case TypeTableEntryIdBlock:
        case TypeTableEntryIdBoundFn:
        case TypeTableEntryIdArgTuple:
        case TypeTableEntryIdOpaque:
            zig_unreachable();
        case TypeTableEntryIdErrorUnion:
            return a.data.error_union.err_set_type == b.data.error_union.err_set_type &&
                a.data.error_union.payload_type == b.data.error_union.payload_type;

        case TypeTableEntryIdPointer:
            return a.data.pointer.child_type == b.data.pointer.child_type &&
                a.data.pointer.ptr_len == b.data.pointer.ptr_len &&
                a.data.pointer.is_const == b.data.pointer.is_const &&
                a.data.pointer.is_volatile == b.data.pointer.is_volatile &&
                a.data.pointer.alignment == b.data.pointer.alignment &&
                a.data.pointer.bit_offset == b.data.pointer.bit_offset &&
                a.data.pointer.unaligned_bit_count == b.data.pointer.unaligned_bit_count;
        case TypeTableEntryIdArray:
            return a.data.array.child_type == b.data.array.child_type &&
                a.data.array.size == b.data.array.size;
        case TypeTableEntryIdInt:
            return a.data.integer.is_signed == b.data.integer.is_signed &&
                a.data.integer.bit_count == b.data.integer.bit_count;
    }
    zig_unreachable();
}

uint32_t zig_llvm_fn_key_hash(ZigLLVMFnKey x) {
    switch (x.id) {
        case ZigLLVMFnIdCtz:
            return (uint32_t)(x.data.ctz.bit_count) * (uint32_t)810453934;
        case ZigLLVMFnIdClz:
            return (uint32_t)(x.data.clz.bit_count) * (uint32_t)2428952817;
        case ZigLLVMFnIdPopCount:
            return (uint32_t)(x.data.clz.bit_count) * (uint32_t)101195049;
        case ZigLLVMFnIdFloor:
            return (uint32_t)(x.data.floating.bit_count) * (uint32_t)1899859168;
        case ZigLLVMFnIdCeil:
            return (uint32_t)(x.data.floating.bit_count) * (uint32_t)1953839089;
        case ZigLLVMFnIdSqrt:
            return (uint32_t)(x.data.floating.bit_count) * (uint32_t)2225366385;
        case ZigLLVMFnIdOverflowArithmetic:
            return ((uint32_t)(x.data.overflow_arithmetic.bit_count) * 87135777) +
                ((uint32_t)(x.data.overflow_arithmetic.add_sub_mul) * 31640542) +
                ((uint32_t)(x.data.overflow_arithmetic.is_signed) ? 1062315172 : 314955820);
    }
    zig_unreachable();
}

bool zig_llvm_fn_key_eql(ZigLLVMFnKey a, ZigLLVMFnKey b) {
    if (a.id != b.id)
        return false;
    switch (a.id) {
        case ZigLLVMFnIdCtz:
            return a.data.ctz.bit_count == b.data.ctz.bit_count;
        case ZigLLVMFnIdClz:
            return a.data.clz.bit_count == b.data.clz.bit_count;
        case ZigLLVMFnIdPopCount:
            return a.data.pop_count.bit_count == b.data.pop_count.bit_count;
        case ZigLLVMFnIdFloor:
        case ZigLLVMFnIdCeil:
        case ZigLLVMFnIdSqrt:
            return a.data.floating.bit_count == b.data.floating.bit_count;
        case ZigLLVMFnIdOverflowArithmetic:
            return (a.data.overflow_arithmetic.bit_count == b.data.overflow_arithmetic.bit_count) &&
                (a.data.overflow_arithmetic.add_sub_mul == b.data.overflow_arithmetic.add_sub_mul) &&
                (a.data.overflow_arithmetic.is_signed == b.data.overflow_arithmetic.is_signed);
    }
    zig_unreachable();
}

void expand_undef_array(CodeGen *g, ConstExprValue *const_val) {
    assert(const_val->type->id == TypeTableEntryIdArray);
    if (const_val->data.x_array.special == ConstArraySpecialUndef) {
        const_val->data.x_array.special = ConstArraySpecialNone;
        size_t elem_count = const_val->type->data.array.len;
        const_val->data.x_array.s_none.elements = create_const_vals(elem_count);
        for (size_t i = 0; i < elem_count; i += 1) {
            ConstExprValue *element_val = &const_val->data.x_array.s_none.elements[i];
            element_val->type = const_val->type->data.array.child_type;
            init_const_undefined(g, element_val);
            ConstParent *parent = get_const_val_parent(g, element_val);
            if (parent != nullptr) {
                parent->id = ConstParentIdArray;
                parent->data.p_array.array_val = const_val;
                parent->data.p_array.elem_index = i;
            }
        }
    }
}

ConstParent *get_const_val_parent(CodeGen *g, ConstExprValue *value) {
    assert(value->type);
    TypeTableEntry *type_entry = value->type;
    if (type_entry->id == TypeTableEntryIdArray) {
        expand_undef_array(g, value);
        return &value->data.x_array.s_none.parent;
    } else if (type_entry->id == TypeTableEntryIdStruct) {
        return &value->data.x_struct.parent;
    } else if (type_entry->id == TypeTableEntryIdUnion) {
        return &value->data.x_union.parent;
    }
    return nullptr;
}

static const TypeTableEntryId all_type_ids[] = {
    TypeTableEntryIdMetaType,
    TypeTableEntryIdVoid,
    TypeTableEntryIdBool,
    TypeTableEntryIdUnreachable,
    TypeTableEntryIdInt,
    TypeTableEntryIdFloat,
    TypeTableEntryIdPointer,
    TypeTableEntryIdArray,
    TypeTableEntryIdStruct,
    TypeTableEntryIdComptimeFloat,
    TypeTableEntryIdComptimeInt,
    TypeTableEntryIdUndefined,
    TypeTableEntryIdNull,
    TypeTableEntryIdOptional,
    TypeTableEntryIdErrorUnion,
    TypeTableEntryIdErrorSet,
    TypeTableEntryIdEnum,
    TypeTableEntryIdUnion,
    TypeTableEntryIdFn,
    TypeTableEntryIdNamespace,
    TypeTableEntryIdBlock,
    TypeTableEntryIdBoundFn,
    TypeTableEntryIdArgTuple,
    TypeTableEntryIdOpaque,
    TypeTableEntryIdPromise,
};

TypeTableEntryId type_id_at_index(size_t index) {
    assert(index < array_length(all_type_ids));
    return all_type_ids[index];
}

size_t type_id_len() {
    return array_length(all_type_ids);
}

size_t type_id_index(TypeTableEntry *entry) {
    switch (entry->id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
            return 0;
        case TypeTableEntryIdVoid:
            return 1;
        case TypeTableEntryIdBool:
            return 2;
        case TypeTableEntryIdUnreachable:
            return 3;
        case TypeTableEntryIdInt:
            return 4;
        case TypeTableEntryIdFloat:
            return 5;
        case TypeTableEntryIdPointer:
            return 6;
        case TypeTableEntryIdArray:
            return 7;
        case TypeTableEntryIdStruct:
            if (entry->data.structure.is_slice)
                return 6;
            return 8;
        case TypeTableEntryIdComptimeFloat:
            return 9;
        case TypeTableEntryIdComptimeInt:
            return 10;
        case TypeTableEntryIdUndefined:
            return 11;
        case TypeTableEntryIdNull:
            return 12;
        case TypeTableEntryIdOptional:
            return 13;
        case TypeTableEntryIdErrorUnion:
            return 14;
        case TypeTableEntryIdErrorSet:
            return 15;
        case TypeTableEntryIdEnum:
            return 16;
        case TypeTableEntryIdUnion:
            return 17;
        case TypeTableEntryIdFn:
            return 18;
        case TypeTableEntryIdNamespace:
            return 19;
        case TypeTableEntryIdBlock:
            return 20;
        case TypeTableEntryIdBoundFn:
            return 21;
        case TypeTableEntryIdArgTuple:
            return 22;
        case TypeTableEntryIdOpaque:
            return 23;
        case TypeTableEntryIdPromise:
            return 24;
    }
    zig_unreachable();
}

const char *type_id_name(TypeTableEntryId id) {
    switch (id) {
        case TypeTableEntryIdInvalid:
            zig_unreachable();
        case TypeTableEntryIdMetaType:
            return "Type";
        case TypeTableEntryIdVoid:
            return "Void";
        case TypeTableEntryIdBool:
            return "Bool";
        case TypeTableEntryIdUnreachable:
            return "NoReturn";
        case TypeTableEntryIdInt:
            return "Int";
        case TypeTableEntryIdFloat:
            return "Float";
        case TypeTableEntryIdPointer:
            return "Pointer";
        case TypeTableEntryIdArray:
            return "Array";
        case TypeTableEntryIdStruct:
            return "Struct";
        case TypeTableEntryIdComptimeFloat:
            return "ComptimeFloat";
        case TypeTableEntryIdComptimeInt:
            return "ComptimeInt";
        case TypeTableEntryIdUndefined:
            return "Undefined";
        case TypeTableEntryIdNull:
            return "Null";
        case TypeTableEntryIdOptional:
            return "Optional";
        case TypeTableEntryIdErrorUnion:
            return "ErrorUnion";
        case TypeTableEntryIdErrorSet:
            return "ErrorSet";
        case TypeTableEntryIdEnum:
            return "Enum";
        case TypeTableEntryIdUnion:
            return "Union";
        case TypeTableEntryIdFn:
            return "Fn";
        case TypeTableEntryIdNamespace:
            return "Namespace";
        case TypeTableEntryIdBlock:
            return "Block";
        case TypeTableEntryIdBoundFn:
            return "BoundFn";
        case TypeTableEntryIdArgTuple:
            return "ArgTuple";
        case TypeTableEntryIdOpaque:
            return "Opaque";
        case TypeTableEntryIdPromise:
            return "Promise";
    }
    zig_unreachable();
}

LinkLib *create_link_lib(Buf *name) {
    LinkLib *link_lib = allocate<LinkLib>(1);
    link_lib->name = name;
    return link_lib;
}

LinkLib *add_link_lib(CodeGen *g, Buf *name) {
    bool is_libc = buf_eql_str(name, "c");

    if (is_libc && g->libc_link_lib != nullptr)
        return g->libc_link_lib;

    for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
        LinkLib *existing_lib = g->link_libs_list.at(i);
        if (buf_eql_buf(existing_lib->name, name)) {
            return existing_lib;
        }
    }

    LinkLib *link_lib = create_link_lib(name);
    g->link_libs_list.append(link_lib);

    if (is_libc)
        g->libc_link_lib = link_lib;

    return link_lib;
}

uint32_t get_abi_alignment(CodeGen *g, TypeTableEntry *type_entry) {
    type_ensure_zero_bits_known(g, type_entry);
    if (type_entry->zero_bits) return 0;

    // We need to make this function work without requiring ensure_complete_type
    // so that we can have structs with fields that are pointers to their own type.
    if (type_entry->id == TypeTableEntryIdStruct) {
        assert(type_entry->data.structure.abi_alignment != 0);
        return type_entry->data.structure.abi_alignment;
    } else if (type_entry->id == TypeTableEntryIdUnion) {
        assert(type_entry->data.unionation.abi_alignment != 0);
        return type_entry->data.unionation.abi_alignment;
    } else if (type_entry->id == TypeTableEntryIdOpaque) {
        return 1;
    } else {
        return LLVMABIAlignmentOfType(g->target_data_ref, type_entry->type_ref);
    }
}

TypeTableEntry *get_align_amt_type(CodeGen *g) {
    if (g->align_amt_type == nullptr) {
        // according to LLVM the maximum alignment is 1 << 29.
        g->align_amt_type = get_int_type(g, false, 29);
    }
    return g->align_amt_type;
}

uint32_t type_ptr_hash(const TypeTableEntry *ptr) {
    return hash_ptr((void*)ptr);
}

bool type_ptr_eql(const TypeTableEntry *a, const TypeTableEntry *b) {
    return a == b;
}

ConstExprValue *get_builtin_value(CodeGen *codegen, const char *name) {
    Tld *tld = codegen->compile_var_import->decls_scope->decl_table.get(buf_create_from_str(name));
    resolve_top_level_decl(codegen, tld, false, nullptr);
    assert(tld->id == TldIdVar);
    TldVar *tld_var = (TldVar *)tld;
    ConstExprValue *var_value = tld_var->var->value;
    assert(var_value != nullptr);
    return var_value;
}

bool type_is_global_error_set(TypeTableEntry *err_set_type) {
    assert(err_set_type->id == TypeTableEntryIdErrorSet);
    assert(err_set_type->data.error_set.infer_fn == nullptr);
    return err_set_type->data.error_set.err_count == UINT32_MAX;
}

uint32_t get_coro_frame_align_bytes(CodeGen *g) {
    return g->pointer_size_bytes * 2;
}

bool type_can_fail(TypeTableEntry *type_entry) {
    return type_entry->id == TypeTableEntryIdErrorUnion || type_entry->id == TypeTableEntryIdErrorSet;
}

bool fn_type_can_fail(FnTypeId *fn_type_id) {
    return type_can_fail(fn_type_id->return_type) || fn_type_id->cc == CallingConventionAsync;
}
