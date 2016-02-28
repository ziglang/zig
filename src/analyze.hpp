/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ANALYZE_HPP
#define ZIG_ANALYZE_HPP

#include "all_types.hpp"

void semantic_analyze(CodeGen *g);
ErrorMsg *add_node_error(CodeGen *g, AstNode *node, Buf *msg);
ErrorMsg *add_error_note(CodeGen *g, ErrorMsg *parent_msg, AstNode *node, Buf *msg);
TypeTableEntry *new_type_table_entry(TypeTableEntryId id);
TypeTableEntry *get_pointer_to_type(CodeGen *g, TypeTableEntry *child_type, bool is_const);
BlockContext *new_block_context(AstNode *node, BlockContext *parent);
Expr *get_resolved_expr(AstNode *node);
bool is_node_void_expr(AstNode *node);
TypeTableEntry **get_int_type_ptr(CodeGen *g, bool is_signed, int size_in_bits);
TypeTableEntry *get_int_type(CodeGen *g, bool is_signed, int size_in_bits);
TypeTableEntry **get_c_int_type_ptr(CodeGen *g, CIntType c_int_type);
TypeTableEntry *get_c_int_type(CodeGen *g, CIntType c_int_type);
TypeTableEntry *get_typedecl_type(CodeGen *g, const char *name, TypeTableEntry *child_type);
TypeTableEntry *get_fn_type(CodeGen *g, FnTypeId *fn_type_id);
TypeTableEntry *get_maybe_type(CodeGen *g, TypeTableEntry *child_type);
TypeTableEntry *get_array_type(CodeGen *g, TypeTableEntry *child_type, uint64_t array_size);
TypeTableEntry *get_partial_container_type(CodeGen *g, ImportTableEntry *import,
        ContainerKind kind, AstNode *decl_node, const char *name);
TypeTableEntry *get_smallest_unsigned_int_type(CodeGen *g, uint64_t x);
bool handle_is_ptr(TypeTableEntry *type_entry);
void find_libc_include_path(CodeGen *g);
void find_libc_lib_path(CodeGen *g);

TypeTableEntry *get_underlying_type(TypeTableEntry *type_entry);
bool type_has_bits(TypeTableEntry *type_entry);
uint64_t get_memcpy_align(CodeGen *g, TypeTableEntry *type_entry);


ImportTableEntry *add_source_file(CodeGen *g, PackageTableEntry *package,
        Buf *abs_full_path, Buf *src_dirname, Buf *src_basename, Buf *source_code);

#endif
