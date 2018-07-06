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
TypeTableEntry *get_pointer_to_type_extra(CodeGen *g, TypeTableEntry *child_type, bool is_const,
        bool is_volatile, PtrLen ptr_len, uint32_t byte_alignment, uint32_t bit_offset, uint32_t unaligned_bit_count);
uint64_t type_size(CodeGen *g, TypeTableEntry *type_entry);
uint64_t type_size_bits(CodeGen *g, TypeTableEntry *type_entry);
TypeTableEntry **get_int_type_ptr(CodeGen *g, bool is_signed, uint32_t size_in_bits);
TypeTableEntry *get_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits);
TypeTableEntry **get_c_int_type_ptr(CodeGen *g, CIntType c_int_type);
TypeTableEntry *get_c_int_type(CodeGen *g, CIntType c_int_type);
TypeTableEntry *get_fn_type(CodeGen *g, FnTypeId *fn_type_id);
TypeTableEntry *get_optional_type(CodeGen *g, TypeTableEntry *child_type);
TypeTableEntry *get_array_type(CodeGen *g, TypeTableEntry *child_type, uint64_t array_size);
TypeTableEntry *get_slice_type(CodeGen *g, TypeTableEntry *ptr_type);
TypeTableEntry *get_partial_container_type(CodeGen *g, Scope *scope, ContainerKind kind,
        AstNode *decl_node, const char *name, ContainerLayout layout);
TypeTableEntry *get_smallest_unsigned_int_type(CodeGen *g, uint64_t x);
TypeTableEntry *get_error_union_type(CodeGen *g, TypeTableEntry *err_set_type, TypeTableEntry *payload_type);
TypeTableEntry *get_bound_fn_type(CodeGen *g, FnTableEntry *fn_entry);
TypeTableEntry *get_opaque_type(CodeGen *g, Scope *scope, AstNode *source_node, const char *name);
TypeTableEntry *get_struct_type(CodeGen *g, const char *type_name, const char *field_names[],
        TypeTableEntry *field_types[], size_t field_count);
TypeTableEntry *get_promise_type(CodeGen *g, TypeTableEntry *result_type);
TypeTableEntry *get_promise_frame_type(CodeGen *g, TypeTableEntry *return_type);
TypeTableEntry *get_test_fn_type(CodeGen *g);
bool handle_is_ptr(TypeTableEntry *type_entry);
void find_libc_include_path(CodeGen *g);
void find_libc_lib_path(CodeGen *g);

bool type_has_bits(TypeTableEntry *type_entry);


ImportTableEntry *add_source_file(CodeGen *g, PackageTableEntry *package, Buf *abs_full_path, Buf *source_code);


VariableTableEntry *find_variable(CodeGen *g, Scope *orig_context, Buf *name);
Tld *find_decl(CodeGen *g, Scope *scope, Buf *name);
void resolve_top_level_decl(CodeGen *g, Tld *tld, bool pointer_only, AstNode *source_node);
bool type_is_codegen_pointer(TypeTableEntry *type);

TypeTableEntry *get_codegen_ptr_type(TypeTableEntry *type);
uint32_t get_ptr_align(TypeTableEntry *type);
bool get_ptr_const(TypeTableEntry *type);
TypeTableEntry *validate_var_type(CodeGen *g, AstNode *source_node, TypeTableEntry *type_entry);
TypeTableEntry *container_ref_type(TypeTableEntry *type_entry);
bool type_is_complete(TypeTableEntry *type_entry);
bool type_is_invalid(TypeTableEntry *type_entry);
bool type_is_global_error_set(TypeTableEntry *err_set_type);
bool type_has_zero_bits_known(TypeTableEntry *type_entry);
void resolve_container_type(CodeGen *g, TypeTableEntry *type_entry);
ScopeDecls *get_container_scope(TypeTableEntry *type_entry);
TypeStructField *find_struct_type_field(TypeTableEntry *type_entry, Buf *name);
TypeEnumField *find_enum_type_field(TypeTableEntry *enum_type, Buf *name);
TypeUnionField *find_union_type_field(TypeTableEntry *type_entry, Buf *name);
TypeEnumField *find_enum_field_by_tag(TypeTableEntry *enum_type, const BigInt *tag);
TypeUnionField *find_union_field_by_tag(TypeTableEntry *type_entry, const BigInt *tag);

bool is_ref(TypeTableEntry *type_entry);
bool is_array_ref(TypeTableEntry *type_entry);
bool is_container_ref(TypeTableEntry *type_entry);
void scan_decls(CodeGen *g, ScopeDecls *decls_scope, AstNode *node);
void scan_import(CodeGen *g, ImportTableEntry *import);
void preview_use_decl(CodeGen *g, AstNode *node);
void resolve_use_decl(CodeGen *g, AstNode *node);
FnTableEntry *scope_fn_entry(Scope *scope);
ImportTableEntry *get_scope_import(Scope *scope);
void init_tld(Tld *tld, TldId id, Buf *name, VisibMod visib_mod, AstNode *source_node, Scope *parent_scope);
VariableTableEntry *add_variable(CodeGen *g, AstNode *source_node, Scope *parent_scope, Buf *name,
    bool is_const, ConstExprValue *init_value, Tld *src_tld);
TypeTableEntry *analyze_type_expr(CodeGen *g, Scope *scope, AstNode *node);
FnTableEntry *create_fn(AstNode *proto_node);
FnTableEntry *create_fn_raw(FnInline inline_value, GlobalLinkageId linkage);
void init_fn_type_id(FnTypeId *fn_type_id, AstNode *proto_node, size_t param_count_alloc);
AstNode *get_param_decl_node(FnTableEntry *fn_entry, size_t index);
FnTableEntry *scope_get_fn_if_root(Scope *scope);
bool type_requires_comptime(TypeTableEntry *type_entry);
void ensure_complete_type(CodeGen *g, TypeTableEntry *type_entry);
void type_ensure_zero_bits_known(CodeGen *g, TypeTableEntry *type_entry);
void complete_enum(CodeGen *g, TypeTableEntry *enum_type);
bool ir_get_var_is_comptime(VariableTableEntry *var);
bool const_values_equal(ConstExprValue *a, ConstExprValue *b);
void eval_min_max_value(CodeGen *g, TypeTableEntry *type_entry, ConstExprValue *const_val, bool is_max);
void eval_min_max_value_int(CodeGen *g, TypeTableEntry *int_type, BigInt *bigint, bool is_max);

void render_const_value(CodeGen *g, Buf *buf, ConstExprValue *const_val);
void analyze_fn_ir(CodeGen *g, FnTableEntry *fn_table_entry, AstNode *return_type_node);

ScopeBlock *create_block_scope(AstNode *node, Scope *parent);
ScopeDefer *create_defer_scope(AstNode *node, Scope *parent);
ScopeDeferExpr *create_defer_expr_scope(AstNode *node, Scope *parent);
Scope *create_var_scope(AstNode *node, Scope *parent, VariableTableEntry *var);
ScopeCImport *create_cimport_scope(AstNode *node, Scope *parent);
ScopeLoop *create_loop_scope(AstNode *node, Scope *parent);
ScopeSuspend *create_suspend_scope(AstNode *node, Scope *parent);
ScopeFnDef *create_fndef_scope(AstNode *node, Scope *parent, FnTableEntry *fn_entry);
ScopeDecls *create_decls_scope(AstNode *node, Scope *parent, TypeTableEntry *container_type, ImportTableEntry *import);
Scope *create_comptime_scope(AstNode *node, Scope *parent);
Scope *create_coro_prelude_scope(AstNode *node, Scope *parent);

void init_const_str_lit(CodeGen *g, ConstExprValue *const_val, Buf *str);
ConstExprValue *create_const_str_lit(CodeGen *g, Buf *str);

void init_const_c_str_lit(CodeGen *g, ConstExprValue *const_val, Buf *c_str);
ConstExprValue *create_const_c_str_lit(CodeGen *g, Buf *c_str);

void init_const_bigint(ConstExprValue *const_val, TypeTableEntry *type, const BigInt *bigint);
ConstExprValue *create_const_bigint(TypeTableEntry *type, const BigInt *bigint);

void init_const_unsigned_negative(ConstExprValue *const_val, TypeTableEntry *type, uint64_t x, bool negative);
ConstExprValue *create_const_unsigned_negative(TypeTableEntry *type, uint64_t x, bool negative);

void init_const_signed(ConstExprValue *const_val, TypeTableEntry *type, int64_t x);
ConstExprValue *create_const_signed(TypeTableEntry *type, int64_t x);

void init_const_usize(CodeGen *g, ConstExprValue *const_val, uint64_t x);
ConstExprValue *create_const_usize(CodeGen *g, uint64_t x);

void init_const_float(ConstExprValue *const_val, TypeTableEntry *type, double value);
ConstExprValue *create_const_float(TypeTableEntry *type, double value);

void init_const_enum(ConstExprValue *const_val, TypeTableEntry *type, const BigInt *tag);
ConstExprValue *create_const_enum(TypeTableEntry *type, const BigInt *tag);

void init_const_bool(CodeGen *g, ConstExprValue *const_val, bool value);
ConstExprValue *create_const_bool(CodeGen *g, bool value);

void init_const_type(CodeGen *g, ConstExprValue *const_val, TypeTableEntry *type_value);
ConstExprValue *create_const_type(CodeGen *g, TypeTableEntry *type_value);

void init_const_runtime(ConstExprValue *const_val, TypeTableEntry *type);
ConstExprValue *create_const_runtime(TypeTableEntry *type);

void init_const_ptr_ref(CodeGen *g, ConstExprValue *const_val, ConstExprValue *pointee_val, bool is_const);
ConstExprValue *create_const_ptr_ref(CodeGen *g, ConstExprValue *pointee_val, bool is_const);

void init_const_ptr_hard_coded_addr(CodeGen *g, ConstExprValue *const_val, TypeTableEntry *pointee_type,
        size_t addr, bool is_const);
ConstExprValue *create_const_ptr_hard_coded_addr(CodeGen *g, TypeTableEntry *pointee_type,
        size_t addr, bool is_const);

void init_const_ptr_array(CodeGen *g, ConstExprValue *const_val, ConstExprValue *array_val,
        size_t elem_index, bool is_const, PtrLen ptr_len);
ConstExprValue *create_const_ptr_array(CodeGen *g, ConstExprValue *array_val, size_t elem_index,
        bool is_const, PtrLen ptr_len);

void init_const_slice(CodeGen *g, ConstExprValue *const_val, ConstExprValue *array_val,
        size_t start, size_t len, bool is_const);
ConstExprValue *create_const_slice(CodeGen *g, ConstExprValue *array_val, size_t start, size_t len, bool is_const);

void init_const_arg_tuple(CodeGen *g, ConstExprValue *const_val, size_t arg_index_start, size_t arg_index_end);
ConstExprValue *create_const_arg_tuple(CodeGen *g, size_t arg_index_start, size_t arg_index_end);

void init_const_undefined(CodeGen *g, ConstExprValue *const_val);

ConstExprValue *create_const_vals(size_t count);

TypeTableEntry *make_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits);
ConstParent *get_const_val_parent(CodeGen *g, ConstExprValue *value);
void expand_undef_array(CodeGen *g, ConstExprValue *const_val);
void update_compile_var(CodeGen *g, Buf *name, ConstExprValue *value);

const char *type_id_name(TypeTableEntryId id);
TypeTableEntryId type_id_at_index(size_t index);
size_t type_id_len();
size_t type_id_index(TypeTableEntry *entry);
TypeTableEntry *get_generic_fn_type(CodeGen *g, FnTypeId *fn_type_id);
bool type_is_copyable(CodeGen *g, TypeTableEntry *type_entry);
LinkLib *create_link_lib(Buf *name);
bool calling_convention_does_first_arg_return(CallingConvention cc);
LinkLib *add_link_lib(CodeGen *codegen, Buf *lib);

uint32_t get_abi_alignment(CodeGen *g, TypeTableEntry *type_entry);
TypeTableEntry *get_align_amt_type(CodeGen *g);
PackageTableEntry *new_anonymous_package(void);

Buf *const_value_to_buffer(ConstExprValue *const_val);
void add_fn_export(CodeGen *g, FnTableEntry *fn_table_entry, Buf *symbol_name, GlobalLinkageId linkage, bool ccc);


ConstExprValue *get_builtin_value(CodeGen *codegen, const char *name);
TypeTableEntry *get_ptr_to_stack_trace_type(CodeGen *g);
bool resolve_inferred_error_set(CodeGen *g, TypeTableEntry *err_set_type, AstNode *source_node);

TypeTableEntry *get_auto_err_set_type(CodeGen *g, FnTableEntry *fn_entry);

uint32_t get_coro_frame_align_bytes(CodeGen *g);
bool fn_type_can_fail(FnTypeId *fn_type_id);
bool type_can_fail(TypeTableEntry *type_entry);
bool fn_eval_cacheable(Scope *scope, TypeTableEntry *return_type);
AstNode *type_decl_node(TypeTableEntry *type_entry);

#endif
