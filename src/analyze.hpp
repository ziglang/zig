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
ErrorMsg *add_token_error(CodeGen *g, ZigType *owner, Token *token, Buf *msg);
ErrorMsg *add_error_note(CodeGen *g, ErrorMsg *parent_msg, AstNode *node, Buf *msg);
void emit_error_notes_for_ref_stack(CodeGen *g, ErrorMsg *msg);
ZigType *new_type_table_entry(ZigTypeId id);
ZigType *get_pointer_to_type(CodeGen *g, ZigType *child_type, bool is_const);
ZigType *get_pointer_to_type_extra(CodeGen *g, ZigType *child_type, bool is_const,
        bool is_volatile, PtrLen ptr_len,
        uint32_t byte_alignment, uint32_t bit_offset, uint32_t unaligned_bit_count,
        bool allow_zero);
uint64_t type_size(CodeGen *g, ZigType *type_entry);
uint64_t type_size_bits(CodeGen *g, ZigType *type_entry);
ZigType *get_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits);
ZigType *get_vector_type(CodeGen *g, uint32_t len, ZigType *elem_type);
ZigType **get_c_int_type_ptr(CodeGen *g, CIntType c_int_type);
ZigType *get_c_int_type(CodeGen *g, CIntType c_int_type);
ZigType *get_fn_type(CodeGen *g, FnTypeId *fn_type_id);
ZigType *get_optional_type(CodeGen *g, ZigType *child_type);
ZigType *get_array_type(CodeGen *g, ZigType *child_type, uint64_t array_size);
ZigType *get_slice_type(CodeGen *g, ZigType *ptr_type);
ZigType *get_partial_container_type(CodeGen *g, Scope *scope, ContainerKind kind,
        AstNode *decl_node, const char *full_name, Buf *bare_name, ContainerLayout layout);
ZigType *get_smallest_unsigned_int_type(CodeGen *g, uint64_t x);
ZigType *get_error_union_type(CodeGen *g, ZigType *err_set_type, ZigType *payload_type);
ZigType *get_bound_fn_type(CodeGen *g, ZigFn *fn_entry);
ZigType *get_opaque_type(CodeGen *g, Scope *scope, AstNode *source_node, const char *full_name, Buf *bare_name);
ZigType *get_struct_type(CodeGen *g, const char *type_name, const char *field_names[],
        ZigType *field_types[], size_t field_count);
ZigType *get_promise_type(CodeGen *g, ZigType *result_type);
ZigType *get_promise_frame_type(CodeGen *g, ZigType *return_type);
ZigType *get_test_fn_type(CodeGen *g);
bool handle_is_ptr(ZigType *type_entry);

bool type_has_bits(ZigType *type_entry);
bool type_allowed_in_extern(CodeGen *g, ZigType *type_entry);
bool ptr_allows_addr_zero(ZigType *ptr_type);
bool type_is_nonnull_ptr(ZigType *type);

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
void resolve_top_level_decl(CodeGen *g, Tld *tld, AstNode *source_node);

ZigType *get_src_ptr_type(ZigType *type);
ZigType *get_codegen_ptr_type(ZigType *type);
uint32_t get_ptr_align(CodeGen *g, ZigType *type);
bool get_ptr_const(ZigType *type);
ZigType *validate_var_type(CodeGen *g, AstNode *source_node, ZigType *type_entry);
ZigType *container_ref_type(ZigType *type_entry);
bool type_is_complete(ZigType *type_entry);
bool type_is_resolved(ZigType *type_entry, ResolveStatus status);
bool type_is_invalid(ZigType *type_entry);
bool type_is_global_error_set(ZigType *err_set_type);
Error resolve_container_type(CodeGen *g, ZigType *type_entry);
ScopeDecls *get_container_scope(ZigType *type_entry);
TypeStructField *find_struct_type_field(ZigType *type_entry, Buf *name);
TypeEnumField *find_enum_type_field(ZigType *enum_type, Buf *name);
TypeUnionField *find_union_type_field(ZigType *type_entry, Buf *name);
TypeEnumField *find_enum_field_by_tag(ZigType *enum_type, const BigInt *tag);
TypeUnionField *find_union_field_by_tag(ZigType *type_entry, const BigInt *tag);

bool is_ref(ZigType *type_entry);
bool is_array_ref(ZigType *type_entry);
bool is_container_ref(ZigType *type_entry);
bool is_valid_vector_elem_type(ZigType *elem_type);
void scan_decls(CodeGen *g, ScopeDecls *decls_scope, AstNode *node);
void preview_use_decl(CodeGen *g, AstNode *node);
void resolve_use_decl(CodeGen *g, AstNode *node);
ZigFn *scope_fn_entry(Scope *scope);
ZigPackage *scope_package(Scope *scope);
ZigType *get_scope_import(Scope *scope);
void init_tld(Tld *tld, TldId id, Buf *name, VisibMod visib_mod, AstNode *source_node, Scope *parent_scope);
ZigVar *add_variable(CodeGen *g, AstNode *source_node, Scope *parent_scope, Buf *name,
    bool is_const, ConstExprValue *init_value, Tld *src_tld, ZigType *var_type);
ZigType *analyze_type_expr(CodeGen *g, Scope *scope, AstNode *node);
ZigFn *create_fn(CodeGen *g, AstNode *proto_node);
ZigFn *create_fn_raw(CodeGen *g, FnInline inline_value);
void init_fn_type_id(FnTypeId *fn_type_id, AstNode *proto_node, size_t param_count_alloc);
AstNode *get_param_decl_node(ZigFn *fn_entry, size_t index);
Error ATTRIBUTE_MUST_USE ensure_complete_type(CodeGen *g, ZigType *type_entry);
Error ATTRIBUTE_MUST_USE type_resolve(CodeGen *g, ZigType *type_entry, ResolveStatus status);
void complete_enum(CodeGen *g, ZigType *enum_type);
bool ir_get_var_is_comptime(ZigVar *var);
bool const_values_equal(CodeGen *g, ConstExprValue *a, ConstExprValue *b);
void eval_min_max_value(CodeGen *g, ZigType *type_entry, ConstExprValue *const_val, bool is_max);
void eval_min_max_value_int(CodeGen *g, ZigType *int_type, BigInt *bigint, bool is_max);

void render_const_value(CodeGen *g, Buf *buf, ConstExprValue *const_val);
void analyze_fn_ir(CodeGen *g, ZigFn *fn_table_entry, AstNode *return_type_node);

ScopeBlock *create_block_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeDefer *create_defer_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeDeferExpr *create_defer_expr_scope(CodeGen *g, AstNode *node, Scope *parent);
Scope *create_var_scope(CodeGen *g, AstNode *node, Scope *parent, ZigVar *var);
ScopeCImport *create_cimport_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeLoop *create_loop_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeSuspend *create_suspend_scope(CodeGen *g, AstNode *node, Scope *parent);
ScopeFnDef *create_fndef_scope(CodeGen *g, AstNode *node, Scope *parent, ZigFn *fn_entry);
Scope *create_comptime_scope(CodeGen *g, AstNode *node, Scope *parent);
Scope *create_coro_prelude_scope(CodeGen *g, AstNode *node, Scope *parent);
Scope *create_runtime_scope(CodeGen *g, AstNode *node, Scope *parent, IrInstruction *is_comptime);

void init_const_str_lit(CodeGen *g, ConstExprValue *const_val, Buf *str);
ConstExprValue *create_const_str_lit(CodeGen *g, Buf *str);

void init_const_c_str_lit(CodeGen *g, ConstExprValue *const_val, Buf *c_str);
ConstExprValue *create_const_c_str_lit(CodeGen *g, Buf *c_str);

void init_const_bigint(ConstExprValue *const_val, ZigType *type, const BigInt *bigint);
ConstExprValue *create_const_bigint(ZigType *type, const BigInt *bigint);

void init_const_unsigned_negative(ConstExprValue *const_val, ZigType *type, uint64_t x, bool negative);
ConstExprValue *create_const_unsigned_negative(ZigType *type, uint64_t x, bool negative);

void init_const_signed(ConstExprValue *const_val, ZigType *type, int64_t x);
ConstExprValue *create_const_signed(ZigType *type, int64_t x);

void init_const_usize(CodeGen *g, ConstExprValue *const_val, uint64_t x);
ConstExprValue *create_const_usize(CodeGen *g, uint64_t x);

void init_const_float(ConstExprValue *const_val, ZigType *type, double value);
ConstExprValue *create_const_float(ZigType *type, double value);

void init_const_enum(ConstExprValue *const_val, ZigType *type, const BigInt *tag);
ConstExprValue *create_const_enum(ZigType *type, const BigInt *tag);

void init_const_bool(CodeGen *g, ConstExprValue *const_val, bool value);
ConstExprValue *create_const_bool(CodeGen *g, bool value);

void init_const_type(CodeGen *g, ConstExprValue *const_val, ZigType *type_value);
ConstExprValue *create_const_type(CodeGen *g, ZigType *type_value);

void init_const_runtime(ConstExprValue *const_val, ZigType *type);
ConstExprValue *create_const_runtime(ZigType *type);

void init_const_ptr_ref(CodeGen *g, ConstExprValue *const_val, ConstExprValue *pointee_val, bool is_const);
ConstExprValue *create_const_ptr_ref(CodeGen *g, ConstExprValue *pointee_val, bool is_const);

void init_const_ptr_hard_coded_addr(CodeGen *g, ConstExprValue *const_val, ZigType *pointee_type,
        size_t addr, bool is_const);
ConstExprValue *create_const_ptr_hard_coded_addr(CodeGen *g, ZigType *pointee_type,
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

ZigType *make_int_type(CodeGen *g, bool is_signed, uint32_t size_in_bits);
ConstParent *get_const_val_parent(CodeGen *g, ConstExprValue *value);
void expand_undef_array(CodeGen *g, ConstExprValue *const_val);
void update_compile_var(CodeGen *g, Buf *name, ConstExprValue *value);

const char *type_id_name(ZigTypeId id);
ZigTypeId type_id_at_index(size_t index);
size_t type_id_len();
size_t type_id_index(ZigType *entry);
ZigType *get_generic_fn_type(CodeGen *g, FnTypeId *fn_type_id);
LinkLib *create_link_lib(Buf *name);
LinkLib *add_link_lib(CodeGen *codegen, Buf *lib);

uint32_t get_abi_alignment(CodeGen *g, ZigType *type_entry);
ZigType *get_align_amt_type(CodeGen *g);
ZigPackage *new_anonymous_package(void);

Buf *const_value_to_buffer(ConstExprValue *const_val);
void add_fn_export(CodeGen *g, ZigFn *fn_table_entry, Buf *symbol_name, GlobalLinkageId linkage, bool ccc);


ConstExprValue *get_builtin_value(CodeGen *codegen, const char *name);
ZigType *get_ptr_to_stack_trace_type(CodeGen *g);
bool resolve_inferred_error_set(CodeGen *g, ZigType *err_set_type, AstNode *source_node);

ZigType *get_auto_err_set_type(CodeGen *g, ZigFn *fn_entry);

uint32_t get_coro_frame_align_bytes(CodeGen *g);
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
bool type_is_c_abi_int(CodeGen *g, ZigType *ty);
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
        ConstExprValue *const_val, ZigType *wanted_type);

void typecheck_panic_fn(CodeGen *g, TldFn *tld_fn, ZigFn *panic_fn);
Buf *type_bare_name(ZigType *t);
Buf *type_h_name(ZigType *t);
Error create_c_object_cache(CodeGen *g, CacheHash **out_cache_hash, bool verbose);

LLVMTypeRef get_llvm_type(CodeGen *g, ZigType *type);
ZigLLVMDIType *get_llvm_di_type(CodeGen *g, ZigType *type);

void add_cc_args(CodeGen *g, ZigList<const char *> &args, const char *out_dep_path, bool translate_c);

#endif
