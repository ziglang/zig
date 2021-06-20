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
ErrorMsg *add_token_error(CodeGen *g, ZigType *owner, TokenIndex token, Buf *msg);
ErrorMsg *add_token_error_offset(CodeGen *g, ZigType *owner, TokenIndex token, Buf *msg,
        uint32_t bad_index);
ErrorMsg *add_error_note(CodeGen *g, ErrorMsg *parent_msg, const AstNode *node, Buf *msg);
ZigType *new_type_table_entry(ZigTypeId id);
ZigType *get_fn_frame_type(CodeGen *g, ZigFn *fn);
ZigType *get_pointer_to_type(CodeGen *g, ZigType *child_type, bool is_const);
ZigType *get_pointer_to_type_extra(CodeGen *g, ZigType *child_type,
        bool is_const, bool is_volatile, PtrLen ptr_len,
        uint32_t byte_alignment, uint32_t bit_offset, uint32_t unaligned_bit_count,
        bool allow_zero);
ZigType *get_pointer_to_type_extra2(CodeGen *g, ZigType *child_type,
        bool is_const, bool is_volatile, PtrLen ptr_len,
        uint32_t byte_alignment, uint32_t bit_offset, uint32_t unaligned_bit_count,
        bool allow_zero, uint32_t vector_index, InferredStructField *inferred_struct_field,
        ZigValue *sentinel);
uint64_t type_size(CodeGen *g, ZigType *type_entry);
uint64_t type_size_bits(CodeGen *g, ZigType *type_entry);
ZigType *get_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits);
ZigType *get_vector_type(CodeGen *g, uint32_t len, ZigType *elem_type);
ZigType **get_c_int_type_ptr(CodeGen *g, CIntType c_int_type);
ZigType *get_c_int_type(CodeGen *g, CIntType c_int_type);
ZigType *get_fn_type(CodeGen *g, FnTypeId *fn_type_id);
ZigType *get_optional_type(CodeGen *g, ZigType *child_type);
ZigType *get_optional_type2(CodeGen *g, ZigType *child_type);
ZigType *get_array_type(CodeGen *g, ZigType *child_type, uint64_t array_size, ZigValue *sentinel);
ZigType *get_slice_type(CodeGen *g, ZigType *ptr_type);
ZigType *get_partial_container_type(CodeGen *g, Scope *scope, ContainerKind kind,
        AstNode *decl_node, const char *full_name, Buf *bare_name, ContainerLayout layout);
ZigType *get_smallest_unsigned_int_type(CodeGen *g, uint64_t x);
ZigType *get_error_union_type(CodeGen *g, ZigType *err_set_type, ZigType *payload_type);
ZigType *get_bound_fn_type(CodeGen *g, ZigFn *fn_entry);
ZigType *get_opaque_type(CodeGen *g, Scope *scope, AstNode *source_node, const char *full_name, Buf *bare_name);
ZigType *get_test_fn_type(CodeGen *g);
ZigType *get_any_frame_type(CodeGen *g, ZigType *result_type);
bool handle_is_ptr(CodeGen *g, ZigType *type_entry);
Error emit_error_unless_callconv_allowed_for_target(CodeGen *g, AstNode *source_node, CallingConvention cc);
uint32_t get_async_frame_align_bytes(CodeGen *g);

bool type_has_bits(CodeGen *g, ZigType *type_entry);
Error type_has_bits2(CodeGen *g, ZigType *type_entry, bool *result);

enum ExternPosition {
    ExternPositionFunctionParameter,
    ExternPositionFunctionReturn,
    ExternPositionOther, // array element, struct field, optional element, etc
};

Error type_allowed_in_extern(CodeGen *g, ZigType *type_entry, ExternPosition position, bool *result);
bool ptr_allows_addr_zero(ZigType *ptr_type);

// Deprecated, use `type_is_nonnull_ptr2`
bool type_is_nonnull_ptr(CodeGen *g, ZigType *type);
Error type_is_nonnull_ptr2(CodeGen *g, ZigType *type, bool *result);

ZigType *get_codegen_ptr_type_bail(CodeGen *g, ZigType *type);
Error get_codegen_ptr_type(CodeGen *g, ZigType *type, ZigType **result);

enum SourceKind {
    SourceKindRoot,
    SourceKindPkgMain,
    SourceKindNonRoot,
    SourceKindCImport,
};
ZigType *add_source_file(CodeGen *g, ZigPackage *package, Buf *abs_full_path, Buf *source_code,
        SourceKind source_kind);

ZigVar *find_variable(CodeGen *g, Scope *orig_context, Buf *name, ScopeFnDef **crossed_fndef_scope);
Tld *find_decl(CodeGen *g, Scope *scope, Buf *name);
Tld *find_container_decl(CodeGen *g, ScopeDecls *decls_scope, Buf *name);
void resolve_top_level_decl(CodeGen *g, Tld *tld, AstNode *source_node, bool allow_lazy);
void resolve_container_usingnamespace_decls(CodeGen *g, ScopeDecls *decls_scope);

ZigType *get_src_ptr_type(ZigType *type);
uint32_t get_ptr_align(CodeGen *g, ZigType *type);
bool get_ptr_const(CodeGen *g, ZigType *type);
ZigType *validate_var_type(CodeGen *g, AstNodeVariableDeclaration *source_node, ZigType *type_entry);
ZigType *container_ref_type(ZigType *type_entry);
bool type_is_complete(ZigType *type_entry);
bool type_is_resolved(ZigType *type_entry, ResolveStatus status);
bool type_is_invalid(ZigType *type_entry);
bool type_is_global_error_set(ZigType *err_set_type);
ScopeDecls *get_container_scope(ZigType *type_entry);
TypeStructField *find_struct_type_field(ZigType *type_entry, Buf *name);
TypeEnumField *find_enum_type_field(ZigType *enum_type, Buf *name);
TypeUnionField *find_union_type_field(ZigType *type_entry, Buf *name);
TypeEnumField *find_enum_field_by_tag(ZigType *enum_type, const BigInt *tag);
TypeUnionField *find_union_field_by_tag(ZigType *type_entry, const BigInt *tag);

bool is_ref(ZigType *type_entry);
bool is_array_ref(ZigType *type_entry);
bool is_container_ref(ZigType *type_entry);
Error is_valid_vector_elem_type(CodeGen *g, ZigType *elem_type, bool *result);
void scan_decls(CodeGen *g, ScopeDecls *decls_scope, AstNode *node);
ZigFn *scope_fn_entry(Scope *scope);
ZigPackage *scope_package(Scope *scope);
ZigType *get_scope_import(Scope *scope);
ScopeTypeOf *get_scope_typeof(Scope *scope);
void init_tld(Tld *tld, TldId id, Buf *name, VisibMod visib_mod, AstNode *source_node, Scope *parent_scope);
ZigVar *add_variable(CodeGen *g, AstNode *source_node, Scope *parent_scope, Buf *name,
    bool is_const, ZigValue *init_value, Tld *src_tld, ZigType *var_type);
ZigType *analyze_type_expr(CodeGen *g, Scope *scope, AstNode *node);
void append_namespace_qualification(CodeGen *g, Buf *buf, ZigType *container_type);
ZigFn *create_fn(CodeGen *g, AstNode *proto_node);
void init_fn_type_id(FnTypeId *fn_type_id, AstNode *proto_node, CallingConvention cc, size_t param_count_alloc);
AstNode *get_param_decl_node(ZigFn *fn_entry, size_t index);
Error ATTRIBUTE_MUST_USE type_resolve(CodeGen *g, ZigType *type_entry, ResolveStatus status);
void complete_enum(CodeGen *g, ZigType *enum_type);
bool ir_get_var_is_comptime(ZigVar *var);
bool const_values_equal(CodeGen *g, ZigValue *a, ZigValue *b);
void eval_min_max_value(CodeGen *g, ZigType *type_entry, ZigValue *const_val, bool is_max);
void eval_min_max_value_int(CodeGen *g, ZigType *int_type, BigInt *bigint, bool is_max);

void render_const_value(CodeGen *g, Buf *buf, ZigValue *const_val);

ScopeDecls *create_decls_scope(CodeGen *g, AstNode *node, Scope *parent, ZigType *container_type, ZigType *import, Buf *bare_name);
ScopeBlock *create_block_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeDefer *create_defer_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeDeferExpr *create_defer_expr_scope(CodeGen *g, AstNode *node, Scope *parent);
Scope *create_var_scope(CodeGen *g, AstNode *node, Scope *parent, ZigVar *var);
ScopeCImport *create_cimport_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeLoop *create_loop_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeSuspend *create_suspend_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeFnDef *create_fndef_scope(CodeGen *g, AstNode *node, Scope *parent, ZigFn *fn_entry);
Scope *create_comptime_scope(CodeGen *g, AstNode *node, Scope *parent);
Scope *create_nosuspend_scope(CodeGen *g, AstNode *node, Scope *parent);
Scope *create_runtime_scope(CodeGen *g, AstNode *node, Scope *parent, IrInstSrc *is_comptime);
Scope *create_typeof_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeExpr *create_expr_scope(CodeGen *g, AstNode *node, Scope *parent);

void init_const_str_lit(CodeGen *g, ZigValue *const_val, Buf *str, bool move_str);
ZigValue *create_const_str_lit(CodeGen *g, Buf *str);
ZigValue *create_sentineled_str_lit(CodeGen *g, Buf *str, ZigValue *sentinel);

void init_const_bigint(ZigValue *const_val, ZigType *type, const BigInt *bigint);
ZigValue *create_const_bigint(CodeGen *g, ZigType *type, const BigInt *bigint);

void init_const_unsigned_negative(ZigValue *const_val, ZigType *type, uint64_t x, bool negative);
ZigValue *create_const_unsigned_negative(CodeGen *g, ZigType *type, uint64_t x, bool negative);

void init_const_signed(ZigValue *const_val, ZigType *type, int64_t x);
ZigValue *create_const_signed(CodeGen *g, ZigType *type, int64_t x);

void init_const_usize(CodeGen *g, ZigValue *const_val, uint64_t x);
ZigValue *create_const_usize(CodeGen *g, uint64_t x);

void init_const_float(ZigValue *const_val, ZigType *type, double value);
ZigValue *create_const_float(CodeGen *g, ZigType *type, double value);

void init_const_enum(ZigValue *const_val, ZigType *type, const BigInt *tag);
ZigValue *create_const_enum(CodeGen *g, ZigType *type, const BigInt *tag);

void init_const_bool(CodeGen *g, ZigValue *const_val, bool value);
ZigValue *create_const_bool(CodeGen *g, bool value);

void init_const_type(CodeGen *g, ZigValue *const_val, ZigType *type_value);
ZigValue *create_const_type(CodeGen *g, ZigType *type_value);

void init_const_runtime(ZigValue *const_val, ZigType *type);
ZigValue *create_const_runtime(CodeGen *g, ZigType *type);

void init_const_ptr_ref(CodeGen *g, ZigValue *const_val, ZigValue *pointee_val, bool is_const);
ZigValue *create_const_ptr_ref(CodeGen *g, ZigValue *pointee_val, bool is_const);

void init_const_ptr_hard_coded_addr(CodeGen *g, ZigValue *const_val, ZigType *pointee_type,
        size_t addr, bool is_const);
ZigValue *create_const_ptr_hard_coded_addr(CodeGen *g, ZigType *pointee_type,
        size_t addr, bool is_const);

void init_const_ptr_array(CodeGen *g, ZigValue *const_val, ZigValue *array_val,
        size_t elem_index, bool is_const, PtrLen ptr_len);
ZigValue *create_const_ptr_array(CodeGen *g, ZigValue *array_val, size_t elem_index,
        bool is_const, PtrLen ptr_len);

void init_const_slice(CodeGen *g, ZigValue *const_val, ZigValue *array_val,
        size_t start, size_t len, bool is_const, ZigValue *sentinel);
ZigValue *create_const_slice(CodeGen *g, ZigValue *array_val, size_t start, size_t len, bool is_const, ZigValue *sentinel);

void init_const_null(ZigValue *const_val, ZigType *type);
ZigValue *create_const_null(CodeGen *g, ZigType *type);

void init_const_fn(ZigValue *const_val, ZigFn *fn);
ZigValue *create_const_fn(CodeGen *g, ZigFn *fn);

ZigValue **alloc_const_vals_ptrs(CodeGen *g, size_t count);
ZigValue **realloc_const_vals_ptrs(CodeGen *g, ZigValue **ptr, size_t old_count, size_t new_count);

TypeStructField **alloc_type_struct_fields(size_t count);
TypeStructField **realloc_type_struct_fields(TypeStructField **ptr, size_t old_count, size_t new_count);

ZigType *make_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits);
void expand_undef_array(CodeGen *g, ZigValue *const_val);
void expand_undef_struct(CodeGen *g, ZigValue *const_val);
void update_compile_var(CodeGen *g, Buf *name, ZigValue *value);

const char *type_id_name(ZigTypeId id);
ZigTypeId type_id_at_index(size_t index);
size_t type_id_len();
size_t type_id_index(ZigType *entry);
ZigType *get_generic_fn_type(CodeGen *g, FnTypeId *fn_type_id);
bool optional_value_is_null(ZigValue *val);

uint32_t get_abi_alignment(CodeGen *g, ZigType *type_entry);
ZigType *get_align_amt_type(CodeGen *g);
ZigPackage *new_anonymous_package(void);

Buf *const_value_to_buffer(ZigValue *const_val);
void add_fn_export(CodeGen *g, ZigFn *fn_table_entry, const char *symbol_name, GlobalLinkageId linkage, CallingConvention cc);
void add_var_export(CodeGen *g, ZigVar *fn_table_entry, const char *symbol_name, GlobalLinkageId linkage);


ZigValue *get_builtin_value(CodeGen *codegen, const char *name);
ZigType *get_builtin_type(CodeGen *codegen, const char *name);
ZigType *get_stack_trace_type(CodeGen *g);
bool resolve_inferred_error_set(CodeGen *g, ZigType *err_set_type, AstNode *source_node);

ZigType *get_auto_err_set_type(CodeGen *g, ZigFn *fn_entry);

bool fn_type_can_fail(FnTypeId *fn_type_id);
bool type_can_fail(ZigType *type_entry);
bool fn_eval_cacheable(Scope *scope, ZigType *return_type);
AstNode *type_decl_node(ZigType *type_entry);

Error get_primitive_type(CodeGen *g, Buf *name, ZigType **result);

bool calling_convention_allows_zig_types(CallingConvention cc);
const char *calling_convention_name(CallingConvention cc);

Error ATTRIBUTE_MUST_USE file_fetch(CodeGen *g, Buf *resolved_path, Buf *contents);

void walk_function_params(CodeGen *g, ZigType *fn_type, FnWalk *fn_walk);
X64CABIClass type_c_abi_x86_64_class(CodeGen *g, ZigType *ty);
bool type_is_c_abi_int_bail(CodeGen *g, ZigType *ty);
Error type_is_c_abi_int(CodeGen *g, ZigType *ty, bool *result);
bool want_first_arg_sret(CodeGen *g, FnTypeId *fn_type_id);
const char *container_string(ContainerKind kind);

uint32_t get_host_int_bytes(CodeGen *g, ZigType *struct_type, TypeStructField *field);

enum ReqCompTime {
    ReqCompTimeInvalid,
    ReqCompTimeNo,
    ReqCompTimeYes,
};
ReqCompTime type_requires_comptime(CodeGen *g, ZigType *type_entry);

OnePossibleValue type_has_one_possible_value(CodeGen *g, ZigType *type_entry);

Error ensure_const_val_repr(IrAnalyze *ira, CodeGen *codegen, AstNode *source_node,
        ZigValue *const_val, ZigType *wanted_type);

void typecheck_panic_fn(CodeGen *g, TldFn *tld_fn, ZigFn *panic_fn);
Buf *type_bare_name(ZigType *t);
Buf *type_h_name(ZigType *t);

LLVMTypeRef get_llvm_type(CodeGen *g, ZigType *type);
ZigLLVMDIType *get_llvm_di_type(CodeGen *g, ZigType *type);

void add_cc_args(CodeGen *g, ZigList<const char *> &args, const char *out_dep_path, bool translate_c,
        FileExt source_kind);

void src_assert_impl(bool ok, AstNode *source_node, const char *file, unsigned int line);
bool is_container(ZigType *type_entry);
ZigValue *analyze_const_value(CodeGen *g, Scope *scope, AstNode *node, ZigType *type_entry,
        Buf *type_name, UndefAllowed undef);

void resolve_llvm_types_fn(CodeGen *g, ZigFn *fn);
bool fn_is_async(ZigFn *fn);
CallingConvention cc_from_fn_proto(AstNodeFnProto *fn_proto);
bool is_valid_return_type(ZigType* type);
bool is_valid_param_type(ZigType* type);

Error type_val_resolve_abi_align(CodeGen *g, AstNode *source_node, ZigValue *type_val, uint32_t *abi_align);
Error type_val_resolve_abi_size(CodeGen *g, AstNode *source_node, ZigValue *type_val,
        size_t *abi_size, size_t *size_in_bits);
Error type_val_resolve_zero_bits(CodeGen *g, ZigValue *type_val, ZigType *parent_type,
        ZigValue *parent_type_val, bool *is_zero_bits);
ZigType *resolve_union_field_type(CodeGen *g, TypeUnionField *union_field);
ZigType *resolve_struct_field_type(CodeGen *g, TypeStructField *struct_field);

void add_async_error_notes(CodeGen *g, ErrorMsg *msg, ZigFn *fn);

Error analyze_import(CodeGen *codegen, ZigType *source_import, Buf *import_target_str,
        ZigType **out_import, Buf **out_import_target_path, Buf *out_full_path);
ZigValue *get_the_one_possible_value(CodeGen *g, ZigType *type_entry);
bool is_anon_container(ZigType *ty);
void copy_const_val(CodeGen *g, ZigValue *dest, ZigValue *src);
bool type_has_optional_repr(ZigType *ty);
bool is_opt_err_set(ZigType *ty);
bool type_is_numeric(ZigType *ty);
const char *float_op_to_name(BuiltinFnId op);

#define src_assert(OK, SOURCE_NODE) src_assert_impl((OK), (SOURCE_NODE), __FILE__, __LINE__)

#endif
