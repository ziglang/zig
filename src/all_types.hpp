/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ALL_TYPES_HPP
#define ZIG_ALL_TYPES_HPP

#include "list.hpp"
#include "buffer.hpp"
#include "zig_llvm.hpp"
#include "hash_map.hpp"
#include "errmsg.hpp"

struct AstNode;
struct ImportTableEntry;
struct AsmToken;
struct FnTableEntry;
struct BlockContext;
struct TypeTableEntry;
struct VariableTableEntry;
struct Cast;
struct BuiltinFnEntry;
struct LabelTableEntry;
struct TypeStructField;
struct CodeGen;
struct ConstExprValue;

enum OutType {
    OutTypeUnknown,
    OutTypeExe,
    OutTypeLib,
    OutTypeObj,
};

enum CodeGenBuildType {
    CodeGenBuildTypeDebug,
    CodeGenBuildTypeRelease,
};

enum CastOp {
    CastOpNothing,
    CastOpPtrToInt,
    CastOpIntWidenOrShorten,
    CastOpToUnknownSizeArray,
    CastOpMaybeWrap,
    CastOpPointerReinterpret,
};

struct Cast {
    CastOp op;
    // if op is CastOpArrayToString, this will be a pointer to
    // the string struct on the stack
    LLVMValueRef ptr;
    TypeTableEntry *after_type;
    AstNode *source_node;
};

struct ConstEnumValue {
    uint64_t tag;
    ConstExprValue *payload;
};

struct ConstExprValue {
    bool ok; // true if constant expression evalution worked
    bool depends_on_compile_var;

    union {
        uint64_t x_uint;
        int64_t x_int;
        double x_float;
        bool x_bool;
        FnTableEntry *x_fn;
        TypeTableEntry *x_type;
        ConstExprValue *x_maybe;
        ConstEnumValue x_enum;
    } data;
};

struct Expr {
    TypeTableEntry *type_entry;
    // the context in which this expression is evaluated.
    // for blocks, this points to the containing scope, not the block's own scope for its children.
    BlockContext *block_context;

    // may be null for no cast
    Cast implicit_cast; // happens first
    Cast implicit_maybe_cast; // happens second

    ConstExprValue const_val;
};

struct NumLitCodeGen {
    TypeTableEntry *resolved_type;
};

struct StructValExprCodeGen {
    TypeTableEntry *type_entry;
    LLVMValueRef ptr;
    AstNode *source_node;
};

struct TopLevelDecl {
    // reminder: hash tables must be initialized before use
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> deps;
    Buf *name;
    ImportTableEntry *import;
    // set this flag temporarily to detect infinite loops
    bool in_current_deps;
};

struct TypeEnumField {
    Buf *name;
    TypeTableEntry *type_entry;
    uint32_t value;
};

enum NodeType {
    NodeTypeRoot,
    NodeTypeRootExportDecl,
    NodeTypeFnProto,
    NodeTypeFnDef,
    NodeTypeFnDecl,
    NodeTypeParamDecl,
    NodeTypeBlock,
    NodeTypeExternBlock,
    NodeTypeDirective,
    NodeTypeReturnExpr,
    NodeTypeVariableDeclaration,
    NodeTypeBinOpExpr,
    NodeTypeNumberLiteral,
    NodeTypeStringLiteral,
    NodeTypeCharLiteral,
    NodeTypeSymbol,
    NodeTypePrefixOpExpr,
    NodeTypeFnCallExpr,
    NodeTypeArrayAccessExpr,
    NodeTypeSliceExpr,
    NodeTypeFieldAccessExpr,
    NodeTypeUse,
    NodeTypeBoolLiteral,
    NodeTypeNullLiteral,
    NodeTypeIfBoolExpr,
    NodeTypeIfVarExpr,
    NodeTypeWhileExpr,
    NodeTypeForExpr,
    NodeTypeSwitchExpr,
    NodeTypeSwitchProng,
    NodeTypeSwitchRange,
    NodeTypeLabel,
    NodeTypeGoto,
    NodeTypeBreak,
    NodeTypeContinue,
    NodeTypeAsmExpr,
    NodeTypeStructDecl,
    NodeTypeStructField,
    NodeTypeContainerInitExpr,
    NodeTypeStructValueField,
    NodeTypeArrayType,
};

struct AstNodeRoot {
    ZigList<AstNode *> top_level_decls;
};

enum VisibMod {
    VisibModPrivate,
    VisibModPub,
    VisibModExport,
};

struct AstNodeFnProto {
    ZigList<AstNode *> *directives;
    VisibMod visib_mod;
    Buf name;
    ZigList<AstNode *> params;
    AstNode *return_type;
    bool is_var_args;

    // populated by semantic analyzer:

    // the extern block this fn proto is inside. can be null.
    AstNode *extern_node;
    // the struct decl node this fn proto is inside. can be null.
    AstNode *struct_node;
    // the function definition this fn proto is inside. can be null.
    AstNode *fn_def_node;
    FnTableEntry *fn_table_entry;
    bool skip;
    TopLevelDecl top_level_decl;
};

struct AstNodeFnDef {
    AstNode *fn_proto;
    AstNode *body;

    // populated by semantic analyzer
    TypeTableEntry *implicit_return_type;
    BlockContext *block_context;
};

struct AstNodeFnDecl {
    AstNode *fn_proto;
};

struct AstNodeParamDecl {
    Buf name;
    AstNode *type;
    bool is_noalias;

    // populated by semantic analyzer
    VariableTableEntry *variable;
};

struct AstNodeBlock {
    ZigList<AstNode *> statements;

    // populated by semantic analyzer
    BlockContext *block_context;
    Expr resolved_expr;
};

struct AstNodeReturnExpr {
    // might be null in case of return void;
    AstNode *expr;

    // populated by semantic analyzer:
    Expr resolved_expr;
};

struct AstNodeVariableDeclaration {
    Buf symbol;
    bool is_const;
    VisibMod visib_mod;
    // one or both of type and expr will be non null
    AstNode *type;
    AstNode *expr;

    // populated by semantic analyzer
    TopLevelDecl top_level_decl;
    Expr resolved_expr;
};

enum BinOpType {
    BinOpTypeInvalid,
    BinOpTypeAssign,
    BinOpTypeAssignTimes,
    BinOpTypeAssignDiv,
    BinOpTypeAssignMod,
    BinOpTypeAssignPlus,
    BinOpTypeAssignMinus,
    BinOpTypeAssignBitShiftLeft,
    BinOpTypeAssignBitShiftRight,
    BinOpTypeAssignBitAnd,
    BinOpTypeAssignBitXor,
    BinOpTypeAssignBitOr,
    BinOpTypeAssignBoolAnd,
    BinOpTypeAssignBoolOr,
    BinOpTypeBoolOr,
    BinOpTypeBoolAnd,
    BinOpTypeCmpEq,
    BinOpTypeCmpNotEq,
    BinOpTypeCmpLessThan,
    BinOpTypeCmpGreaterThan,
    BinOpTypeCmpLessOrEq,
    BinOpTypeCmpGreaterOrEq,
    BinOpTypeBinOr,
    BinOpTypeBinXor,
    BinOpTypeBinAnd,
    BinOpTypeBitShiftLeft,
    BinOpTypeBitShiftRight,
    BinOpTypeAdd,
    BinOpTypeSub,
    BinOpTypeMult,
    BinOpTypeDiv,
    BinOpTypeMod,
    BinOpTypeUnwrapMaybe,
};

struct AstNodeBinOpExpr {
    AstNode *op1;
    BinOpType bin_op;
    AstNode *op2;

    // populated by semantic analyzer:
    // for when op is BinOpTypeAssign
    VariableTableEntry *var_entry;
    Expr resolved_expr;
};

struct AstNodeFnCallExpr {
    AstNode *fn_ref_expr;
    ZigList<AstNode *> params;
    bool is_builtin;

    // populated by semantic analyzer:
    BuiltinFnEntry *builtin_fn;
    Expr resolved_expr;
    NumLitCodeGen resolved_num_lit;
    Cast cast;
    FnTableEntry *fn_entry;
};

struct AstNodeArrayAccessExpr {
    AstNode *array_ref_expr;
    AstNode *subscript;

    // populated by semantic analyzer:
    Expr resolved_expr;
};

struct AstNodeSliceExpr {
    AstNode *array_ref_expr;
    AstNode *start;
    AstNode *end;
    bool is_const;

    // populated by semantic analyzer:
    Expr resolved_expr;
    StructValExprCodeGen resolved_struct_val_expr;
};

struct AstNodeFieldAccessExpr {
    AstNode *struct_expr;
    Buf field_name;

    // populated by semantic analyzer
    TypeStructField *type_struct_field;
    TypeEnumField *type_enum_field;
    Expr resolved_expr;
    StructValExprCodeGen resolved_struct_val_expr; // for enum values
};

struct AstNodeExternBlock {
    ZigList<AstNode *> *directives;
    ZigList<AstNode *> fn_decls;
};

struct AstNodeDirective {
    Buf name;
    Buf param;
};

struct AstNodeRootExportDecl {
    Buf type;
    Buf name;
    ZigList<AstNode *> *directives;
};

enum PrefixOp {
    PrefixOpInvalid,
    PrefixOpBoolNot,
    PrefixOpBinNot,
    PrefixOpNegation,
    PrefixOpAddressOf,
    PrefixOpConstAddressOf,
    PrefixOpDereference,
    PrefixOpMaybe,
};

struct AstNodePrefixOpExpr {
    PrefixOp prefix_op;
    AstNode *primary_expr;

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeUse {
    Buf path;
    ZigList<AstNode *> *directives;

    // populated by semantic analyzer
    ImportTableEntry *import;
};

struct AstNodeIfBoolExpr {
    AstNode *condition;
    AstNode *then_block;
    AstNode *else_node; // null, block node, or other if expr node

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeIfVarExpr {
    AstNodeVariableDeclaration var_decl;
    AstNode *then_block;
    AstNode *else_node; // null, block node, or other if expr node

    // populated by semantic analyzer
    TypeTableEntry *type;
    BlockContext *block_context;
    Expr resolved_expr;
};

struct AstNodeWhileExpr {
    AstNode *condition;
    AstNode *body;

    // populated by semantic analyzer
    bool condition_always_true;
    bool contains_break;
    Expr resolved_expr;
    BlockContext *block_context;
};

struct AstNodeForExpr {
    AstNode *elem_node; // always a symbol
    AstNode *array_expr;
    AstNode *index_node; // always a symbol, might be null
    AstNode *body;

    // populated by semantic analyzer
    bool contains_break;
    Expr resolved_expr;
    BlockContext *block_context;
    VariableTableEntry *elem_var;
    VariableTableEntry *index_var;
};

struct AstNodeSwitchExpr {
    AstNode *expr;
    ZigList<AstNode *> prongs;

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeSwitchProng {
    ZigList<AstNode *> items;
    AstNode *var_symbol;
    AstNode *expr;

    // populated by semantic analyzer
    BlockContext *block_context;
    VariableTableEntry *var;
};

struct AstNodeSwitchRange {
    AstNode *start;
    AstNode *end;
};

struct AstNodeLabel {
    Buf name;

    // populated by semantic analyzer
    LabelTableEntry *label_entry;
    Expr resolved_expr;
};

struct AstNodeGoto {
    Buf name;

    // populated by semantic analyzer
    LabelTableEntry *label_entry;
    Expr resolved_expr;
};

struct AsmOutput {
    Buf asm_symbolic_name;
    Buf constraint;
    Buf variable_name;
    AstNode *return_type; // null unless "=r" and return
};

struct AsmInput {
    Buf asm_symbolic_name;
    Buf constraint;
    AstNode *expr;
};

struct SrcPos {
    int line;
    int column;
};

struct AstNodeAsmExpr {
    bool is_volatile;
    Buf asm_template;
    ZigList<SrcPos> offset_map;
    ZigList<AsmToken> token_list;
    ZigList<AsmOutput*> output_list;
    ZigList<AsmInput*> input_list;
    ZigList<Buf*> clobber_list;

    // populated by semantic analyzer
    int return_count;
    Expr resolved_expr;
};

enum ContainerKind {
    ContainerKindStruct,
    ContainerKindEnum,
};

struct AstNodeStructDecl {
    Buf name;
    ContainerKind kind;
    ZigList<AstNode *> fields;
    ZigList<AstNode *> fns;
    ZigList<AstNode *> *directives;
    VisibMod visib_mod;

    // populated by semantic analyzer
    TypeTableEntry *type_entry;
    TopLevelDecl top_level_decl;
};

struct AstNodeStructField {
    Buf name;
    AstNode *type;
    ZigList<AstNode *> *directives;
};

struct AstNodeStringLiteral {
    Buf buf;
    bool c;

    // populated by semantic analyzer:
    Expr resolved_expr;
};

struct AstNodeCharLiteral {
    uint8_t value;

    // populated by semantic analyzer:
    Expr resolved_expr;
};

enum NumLit {
    NumLitF32,
    NumLitF64,
    NumLitF128,
    NumLitU8,
    NumLitU16,
    NumLitU32,
    NumLitU64,
    NumLitI8,
    NumLitI16,
    NumLitI32,
    NumLitI64,

    NumLitCount
};

struct AstNodeNumberLiteral {
    NumLit kind;

    // overflow is true if when parsing the number, we discovered it would not
    // fit without losing data in a uint64_t, int64_t, or double
    bool overflow;

    union {
        uint64_t x_uint;
        double x_float;
    } data;

    // populated by semantic analyzer
    NumLitCodeGen codegen;
    Expr resolved_expr;
};

struct AstNodeStructValueField {
    Buf name;
    AstNode *expr;

    // populated by semantic analyzer
    TypeStructField *type_struct_field;
};

enum ContainerInitKind {
    ContainerInitKindStruct,
    ContainerInitKindArray,
};

struct AstNodeContainerInitExpr {
    AstNode *type;
    ZigList<AstNode *> entries;
    ContainerInitKind kind;

    // populated by semantic analyzer
    StructValExprCodeGen resolved_struct_val_expr;
    Expr resolved_expr;
};

struct AstNodeNullLiteral {
    // populated by semantic analyzer
    StructValExprCodeGen resolved_struct_val_expr;
    Expr resolved_expr;
};

struct AstNodeSymbolExpr {
    Buf symbol;

    // populated by semantic analyzer
    Expr resolved_expr;
    VariableTableEntry *variable;
    FnTableEntry *fn_entry;
};

struct AstNodeBoolLiteral {
    bool value;

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeBreakExpr {
    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeContinueExpr {
    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeArrayType {
    AstNode *size;
    AstNode *child_type;
    bool is_const;

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNode {
    enum NodeType type;
    int line;
    int column;
    uint32_t create_index; // for determinism purposes
    ImportTableEntry *owner;
    union {
        AstNodeRoot root;
        AstNodeRootExportDecl root_export_decl;
        AstNodeFnDef fn_def;
        AstNodeFnDecl fn_decl;
        AstNodeFnProto fn_proto;
        AstNodeParamDecl param_decl;
        AstNodeBlock block;
        AstNodeReturnExpr return_expr;
        AstNodeVariableDeclaration variable_declaration;
        AstNodeBinOpExpr bin_op_expr;
        AstNodeExternBlock extern_block;
        AstNodeDirective directive;
        AstNodePrefixOpExpr prefix_op_expr;
        AstNodeFnCallExpr fn_call_expr;
        AstNodeArrayAccessExpr array_access_expr;
        AstNodeSliceExpr slice_expr;
        AstNodeUse use;
        AstNodeIfBoolExpr if_bool_expr;
        AstNodeIfVarExpr if_var_expr;
        AstNodeWhileExpr while_expr;
        AstNodeForExpr for_expr;
        AstNodeSwitchExpr switch_expr;
        AstNodeSwitchProng switch_prong;
        AstNodeSwitchRange switch_range;
        AstNodeLabel label;
        AstNodeGoto goto_expr;
        AstNodeAsmExpr asm_expr;
        AstNodeFieldAccessExpr field_access_expr;
        AstNodeStructDecl struct_decl;
        AstNodeStructField struct_field;
        AstNodeStringLiteral string_literal;
        AstNodeCharLiteral char_literal;
        AstNodeNumberLiteral number_literal;
        AstNodeContainerInitExpr container_init_expr;
        AstNodeStructValueField struct_val_field;
        AstNodeNullLiteral null_literal;
        AstNodeSymbolExpr symbol_expr;
        AstNodeBoolLiteral bool_literal;
        AstNodeBreakExpr break_expr;
        AstNodeContinueExpr continue_expr;
        AstNodeArrayType array_type;
    } data;
};

enum AsmTokenId {
    AsmTokenIdTemplate,
    AsmTokenIdPercent,
    AsmTokenIdVar,
};

struct AsmToken {
    enum AsmTokenId id;
    int start;
    int end;
};

struct TypeTableEntryPointer {
    TypeTableEntry *child_type;
    bool is_const;
};

struct TypeTableEntryInt {
    bool is_signed;
    LLVMValueRef add_with_overflow_fn;
    LLVMValueRef sub_with_overflow_fn;
    LLVMValueRef mul_with_overflow_fn;
};

struct TypeTableEntryArray {
    TypeTableEntry *child_type;
    uint64_t len;
};

struct TypeStructField {
    Buf *name;
    TypeTableEntry *type_entry;
    int src_index;
    int gen_index;
};
struct TypeTableEntryStruct {
    AstNode *decl_node;
    bool is_packed;
    uint32_t field_count;
    TypeStructField *fields;
    uint64_t size_bytes;
    bool is_invalid; // true if any fields are invalid
    bool is_unknown_size_array;
    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
};

struct TypeTableEntryNumLit {
    NumLit kind;
};

struct TypeTableEntryMaybe {
    TypeTableEntry *child_type;
};

struct TypeTableEntryEnum {
    AstNode *decl_node;
    uint32_t field_count;
    uint32_t gen_field_count;
    TypeEnumField *fields;
    bool is_invalid; // true if any fields are invalid
    TypeTableEntry *tag_type;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
};

struct TypeTableEntryFn {
    TypeTableEntry *return_type;
    TypeTableEntry **param_types;
    int src_param_count;
    LLVMTypeRef raw_type_ref;
    bool is_var_args;
    int gen_param_count;
    LLVMCallConv calling_convention;
    bool is_naked;
};

enum TypeTableEntryId {
    TypeTableEntryIdInvalid,
    TypeTableEntryIdMetaType,
    TypeTableEntryIdVoid,
    TypeTableEntryIdBool,
    TypeTableEntryIdUnreachable,
    TypeTableEntryIdInt,
    TypeTableEntryIdFloat,
    TypeTableEntryIdPointer,
    TypeTableEntryIdArray,
    TypeTableEntryIdStruct,
    TypeTableEntryIdNumberLiteral,
    TypeTableEntryIdMaybe,
    TypeTableEntryIdEnum,
    TypeTableEntryIdFn,
};

struct TypeTableEntry {
    TypeTableEntryId id;

    LLVMTypeRef type_ref;
    LLVMZigDIType *di_type;
    uint64_t size_in_bits;
    uint64_t align_in_bits;

    Buf name;

    union {
        TypeTableEntryPointer pointer;
        TypeTableEntryInt integral;
        TypeTableEntryArray array;
        TypeTableEntryStruct structure;
        TypeTableEntryNumLit num_lit;
        TypeTableEntryMaybe maybe;
        TypeTableEntryEnum enumeration;
        TypeTableEntryFn fn;
    } data;

    // use these fields to make sure we don't duplicate type table entries for the same type
    TypeTableEntry *pointer_parent[2];
    TypeTableEntry *unknown_size_array_parent[2];
    HashMap<uint64_t, TypeTableEntry *, uint64_hash, uint64_eq> arrays_by_size;
    TypeTableEntry *maybe_parent;
};

struct ImporterInfo {
    ImportTableEntry *import;
    AstNode *source_node;
};

struct ImportTableEntry {
    AstNode *root;
    Buf *path; // relative to root_source_dir
    LLVMZigDIFile *di_file;
    Buf *source_code;
    ZigList<int> *line_offsets;
    BlockContext *block_context;
    ZigList<ImporterInfo> importers;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> fn_type_table;
};

struct LabelTableEntry {
    AstNode *label_node;
    LLVMBasicBlockRef basic_block;
    bool used;
    bool entered_from_fallthrough;
};

struct FnTableEntry {
    LLVMValueRef fn_value;
    AstNode *proto_node;
    AstNode *fn_def_node;
    ImportTableEntry *import_entry;
    // Required to be a pre-order traversal of the AST. (parents must come before children)
    ZigList<BlockContext *> all_block_contexts;
    TypeTableEntry *member_of_struct;
    Buf symbol_name;
    TypeTableEntry *type_entry; // function type
    bool is_inline;
    bool internal_linkage;
    bool is_extern;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, LabelTableEntry *, buf_hash, buf_eql_buf> label_table;
};

enum BuiltinFnId {
    BuiltinFnIdInvalid,
    BuiltinFnIdMemcpy,
    BuiltinFnIdMemset,
    BuiltinFnIdSizeof,
    BuiltinFnIdMaxValue,
    BuiltinFnIdMinValue,
    BuiltinFnIdMemberCount,
    BuiltinFnIdTypeof,
    BuiltinFnIdAddWithOverflow,
    BuiltinFnIdSubWithOverflow,
    BuiltinFnIdMulWithOverflow,
};

struct BuiltinFnEntry {
    BuiltinFnId id;
    Buf name;
    int param_count;
    TypeTableEntry *return_type;
    TypeTableEntry **param_types;
    LLVMValueRef fn_val;
};

struct CodeGen {
    LLVMModuleRef module;
    ZigList<ErrorMsg*> errors;
    LLVMBuilderRef builder;
    LLVMZigDIBuilder *dbuilder;
    LLVMZigDICompileUnit *compile_unit;

    ZigList<Buf *> lib_search_paths;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, LLVMValueRef, buf_hash, buf_eql_buf> str_table;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> link_table;
    HashMap<Buf *, ImportTableEntry *, buf_hash, buf_eql_buf> import_table;
    HashMap<Buf *, BuiltinFnEntry *, buf_hash, buf_eql_buf> builtin_fn_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> primitive_type_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> unresolved_top_level_decls;

    uint32_t next_unresolved_index;

    struct {
        TypeTableEntry *entry_bool;
        TypeTableEntry *entry_int[2][4]; // [signed,unsigned][8,16,32,64]
        TypeTableEntry *entry_u8;
        TypeTableEntry *entry_u16;
        TypeTableEntry *entry_u32;
        TypeTableEntry *entry_u64;
        TypeTableEntry *entry_i8;
        TypeTableEntry *entry_i16;
        TypeTableEntry *entry_i32;
        TypeTableEntry *entry_i64;
        TypeTableEntry *entry_isize;
        TypeTableEntry *entry_usize;
        TypeTableEntry *entry_f32;
        TypeTableEntry *entry_f64;
        TypeTableEntry *entry_c_string_literal;
        TypeTableEntry *entry_void;
        TypeTableEntry *entry_unreachable;
        TypeTableEntry *entry_type;
        TypeTableEntry *entry_invalid;
    } builtin_types;

    TypeTableEntry *num_lit_types[NumLitCount];

    LLVMTargetDataRef target_data_ref;
    unsigned pointer_size_bytes;
    bool is_static;
    bool strip_debug_symbols;
    bool have_exported_main;
    bool link_libc;
    Buf *libc_path;
    CodeGenBuildType build_type;
    LLVMTargetMachineRef target_machine;
    LLVMZigDIFile *dummy_di_file;
    bool is_native_target;
    Buf *root_source_dir;
    Buf *root_out_name;

    // The function definitions this module includes. There must be a corresponding
    // fn_protos entry.
    ZigList<FnTableEntry *> fn_defs;
    // The function prototypes this module includes. In the case of external declarations,
    // there will not be a corresponding fn_defs entry.
    ZigList<FnTableEntry *> fn_protos;
    ZigList<VariableTableEntry *> global_vars;

    OutType out_type;
    FnTableEntry *cur_fn;
    // TODO remove this in favor of get_resolved_expr(expr_node)->context
    BlockContext *cur_block_context;
    ZigList<LLVMBasicBlockRef> break_block_stack;
    ZigList<LLVMBasicBlockRef> continue_block_stack;
    bool c_stdint_used;
    AstNode *root_export_decl;
    int version_major;
    int version_minor;
    int version_patch;
    bool verbose;
    ErrColor err_color;
    ImportTableEntry *root_import;
    ImportTableEntry *bootstrap_import;
    LLVMValueRef memcpy_fn_val;
    LLVMValueRef memset_fn_val;
    bool error_during_imports;
    uint32_t next_node_index;
};

struct VariableTableEntry {
    Buf name;
    TypeTableEntry *type;
    LLVMValueRef value_ref;
    bool is_const;
    bool is_ptr; // if true, value_ref is a pointer
    AstNode *decl_node;
    LLVMZigDILocalVariable *di_loc_var;
    int src_arg_index;
    int gen_arg_index;
};

struct BlockContext {
    AstNode *node; // either NodeTypeFnDef or NodeTypeBlock or NodeTypeRoot
    FnTableEntry *fn_entry; // null at the module scope
    BlockContext *parent; // null when this is the root
    HashMap<Buf *, VariableTableEntry *, buf_hash, buf_eql_buf> variable_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> type_table;
    ZigList<Cast *> cast_expr_alloca_list;
    ZigList<StructValExprCodeGen *> struct_val_expr_alloca_list;
    ZigList<VariableTableEntry *> variable_list;
    AstNode *parent_loop_node;
    LLVMZigDIScope *di_scope;
};

#endif
