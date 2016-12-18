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
bool is_node_void_expr(AstNode *node);
uint64_t type_size(CodeGen *g, TypeTableEntry *type_entry);
TypeTableEntry **get_int_type_ptr(CodeGen *g, bool is_signed, size_t size_in_bits);
TypeTableEntry *get_int_type(CodeGen *g, bool is_signed, size_t size_in_bits);
TypeTableEntry **get_c_int_type_ptr(CodeGen *g, CIntType c_int_type);
TypeTableEntry *get_c_int_type(CodeGen *g, CIntType c_int_type);
TypeTableEntry *get_typedecl_type(CodeGen *g, const char *name, TypeTableEntry *child_type);
TypeTableEntry *get_fn_type(CodeGen *g, FnTypeId *fn_type_id);
TypeTableEntry *get_maybe_type(CodeGen *g, TypeTableEntry *child_type);
TypeTableEntry *get_array_type(CodeGen *g, TypeTableEntry *child_type, uint64_t array_size);
TypeTableEntry *get_slice_type(CodeGen *g, TypeTableEntry *child_type, bool is_const);
TypeTableEntry *get_partial_container_type(CodeGen *g, ImportTableEntry *import, Scope *scope,
        ContainerKind kind, AstNode *decl_node, const char *name);
TypeTableEntry *get_smallest_unsigned_int_type(CodeGen *g, uint64_t x);
TypeTableEntry *get_error_type(CodeGen *g, TypeTableEntry *child_type);
TypeTableEntry *get_bound_fn_type(CodeGen *g, FnTableEntry *fn_entry);
bool handle_is_ptr(TypeTableEntry *type_entry);
void find_libc_include_path(CodeGen *g);
void find_libc_lib_path(CodeGen *g);

TypeTableEntry *get_underlying_type(TypeTableEntry *type_entry);
bool type_has_bits(TypeTableEntry *type_entry);
uint64_t get_memcpy_align(CodeGen *g, TypeTableEntry *type_entry);


ImportTableEntry *add_source_file(CodeGen *g, PackageTableEntry *package,
        Buf *abs_full_path, Buf *src_dirname, Buf *src_basename, Buf *source_code);

AstNode *first_executing_node(AstNode *node);


// TODO move these over, these used to be static
bool types_match_const_cast_only(TypeTableEntry *expected_type, TypeTableEntry *actual_type);
VariableTableEntry *find_variable(CodeGen *g, Scope *orig_context, Buf *name);
Tld *find_decl(Scope *scope, Buf *name);
void resolve_top_level_decl(CodeGen *g, Tld *tld, bool pointer_only);
bool type_is_codegen_pointer(TypeTableEntry *type);
TypeTableEntry *validate_var_type(CodeGen *g, AstNode *source_node, TypeTableEntry *type_entry);
TypeTableEntry *container_ref_type(TypeTableEntry *type_entry);
bool type_is_complete(TypeTableEntry *type_entry);
void resolve_container_type(CodeGen *g, TypeTableEntry *type_entry);
TypeStructField *find_struct_type_field(TypeTableEntry *type_entry, Buf *name);
ScopeDecls *get_container_scope(TypeTableEntry *type_entry);
TypeEnumField *find_enum_type_field(TypeTableEntry *enum_type, Buf *name);
bool is_container_ref(TypeTableEntry *type_entry);
void scan_decls(CodeGen *g, ImportTableEntry *import, ScopeDecls *decls_scope, AstNode *node, Tld *parent_tld);
void preview_use_decl(CodeGen *g, AstNode *node);
void resolve_use_decl(CodeGen *g, AstNode *node);
FnTableEntry *scope_fn_entry(Scope *scope);
ImportTableEntry *get_scope_import(Scope *scope);
void init_tld(Tld *tld, TldId id, Buf *name, VisibMod visib_mod, AstNode *source_node,
    Scope *parent_scope, Tld *parent_tld);
VariableTableEntry *add_variable(CodeGen *g, AstNode *source_node, Scope *parent_scope, Buf *name,
    TypeTableEntry *type_entry, bool is_const, ConstExprValue *init_value);
TypeTableEntry *analyze_type_expr(CodeGen *g, Scope *scope, AstNode *node);
FnTableEntry *create_fn(AstNode *proto_node);
FnTableEntry *create_fn_raw(FnInline inline_value, bool internal_linkage);
void init_fn_type_id(FnTypeId *fn_type_id, AstNode *proto_node);
AstNode *get_param_decl_node(FnTableEntry *fn_entry, size_t index);
FnTableEntry *scope_get_fn_if_root(Scope *scope);
bool type_requires_comptime(TypeTableEntry *type_entry);

ScopeBlock *create_block_scope(AstNode *node, Scope *parent);
ScopeDefer *create_defer_scope(AstNode *node, Scope *parent);
Scope *create_var_scope(AstNode *node, Scope *parent, VariableTableEntry *var);
ScopeCImport *create_cimport_scope(AstNode *node, Scope *parent);
Scope *create_loop_scope(AstNode *node, Scope *parent);
ScopeFnDef *create_fndef_scope(AstNode *node, Scope *parent, FnTableEntry *fn_entry);
ScopeDecls *create_decls_scope(AstNode *node, Scope *parent, TypeTableEntry *container_type, ImportTableEntry *import);

void init_const_str_lit(ConstExprValue *const_val, Buf *str);
ConstExprValue *create_const_str_lit(Buf *str);

void init_const_unsigned_negative(ConstExprValue *const_val, uint64_t x, bool negative);
ConstExprValue *create_const_unsigned_negative(uint64_t x, bool negative);

void init_const_signed(ConstExprValue *const_val, int64_t x);
ConstExprValue *create_const_signed(int64_t x);

void init_const_float(ConstExprValue *const_val, double value);
ConstExprValue *create_const_float(double value);

void init_const_enum_tag(ConstExprValue *const_val, uint64_t tag);
ConstExprValue *create_const_enum_tag(uint64_t tag);

void init_const_bool(ConstExprValue *const_val, bool value);
ConstExprValue *create_const_bool(bool value);

#endif
