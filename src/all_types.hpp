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
#include "bignum.hpp"
#include "target.hpp"

struct AstNode;
struct ImportTableEntry;
struct AsmToken;
struct FnTableEntry;
struct BlockContext;
struct TypeTableEntry;
struct VariableTableEntry;
struct ErrorTableEntry;
struct BuiltinFnEntry;
struct TypeStructField;
struct CodeGen;
struct ConstExprValue;

enum OutType {
    OutTypeUnknown,
    OutTypeExe,
    OutTypeLib,
    OutTypeObj,
};

struct ConstEnumValue {
    uint64_t tag;
    ConstExprValue *payload;
};

struct ConstStructValue {
    ConstExprValue **fields;
};

struct ConstArrayValue {
    ConstExprValue **fields;
};

struct ConstPtrValue {
    ConstExprValue **ptr;
    // len should almost always be 1. exceptions include C strings
    uint64_t len;
};

struct ConstErrValue {
    ErrorTableEntry *err;
    ConstExprValue *payload;
};

struct ConstExprValue {
    bool ok; // true if constant expression evalution worked
    bool depends_on_compile_var;
    bool undef;

    union {
        BigNum x_bignum;
        bool x_bool;
        FnTableEntry *x_fn;
        TypeTableEntry *x_type;
        ConstExprValue *x_maybe;
        ConstErrValue x_err;
        ConstEnumValue x_enum;
        ConstStructValue x_struct;
        ConstArrayValue x_array;
        ConstPtrValue x_ptr;
    } data;
};

enum ReturnKnowledge {
    ReturnKnowledgeUnknown,
    ReturnKnowledgeKnownError,
    ReturnKnowledgeKnownNonError,
    ReturnKnowledgeKnownNull,
    ReturnKnowledgeKnownNonNull,
    ReturnKnowledgeSkipDefers,
};

struct Expr {
    TypeTableEntry *type_entry;
    ReturnKnowledge return_knowledge;

    LLVMValueRef const_llvm_val;
    ConstExprValue const_val;
    bool has_global_const;
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
    NodeTypeDirective,
    NodeTypeReturnExpr,
    NodeTypeDefer,
    NodeTypeVariableDeclaration,
    NodeTypeTypeDecl,
    NodeTypeErrorValueDecl,
    NodeTypeBinOpExpr,
    NodeTypeUnwrapErrorExpr,
    NodeTypeNumberLiteral,
    NodeTypeStringLiteral,
    NodeTypeCharLiteral,
    NodeTypeSymbol,
    NodeTypePrefixOpExpr,
    NodeTypeFnCallExpr,
    NodeTypeArrayAccessExpr,
    NodeTypeSliceExpr,
    NodeTypeFieldAccessExpr,
    NodeTypeImport,
    NodeTypeCImport,
    NodeTypeBoolLiteral,
    NodeTypeNullLiteral,
    NodeTypeUndefinedLiteral,
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
    NodeTypeErrorType,
    NodeTypeTypeLiteral,
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
    ZigList<AstNode *> *directives; // can be null if no directives
    VisibMod visib_mod;
    Buf name;
    ZigList<AstNode *> params;
    AstNode *return_type;
    bool is_var_args;
    bool is_extern;
    bool is_inline;

    // populated by semantic analyzer:

    // the struct decl node this fn proto is inside. can be null.
    AstNode *struct_node;
    // the function definition this fn proto is inside. can be null.
    AstNode *fn_def_node;
    FnTableEntry *fn_table_entry;
    bool skip;
    TopLevelDecl top_level_decl;
    Expr resolved_expr;
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
    // this one is the scope that the block itself introduces
    BlockContext *child_block;
    // this is the innermost scope created by defers and var decls.
    // you can follow its parents up to child_block. it will equal
    // child_block if there are no defers or var decls in the block.
    BlockContext *nested_block;
    Expr resolved_expr;
};

enum ReturnKind {
    ReturnKindUnconditional,
    ReturnKindMaybe,
    ReturnKindError,
};

struct AstNodeReturnExpr {
    ReturnKind kind;
    // might be null in case of return void;
    AstNode *expr;

    // populated by semantic analyzer:
    Expr resolved_expr;
};

struct AstNodeDefer {
    ReturnKind kind;
    AstNode *expr;

    // populated by semantic analyzer:
    Expr resolved_expr;
    int index_in_block;
    LLVMBasicBlockRef basic_block;
    BlockContext *child_block;
};

struct AstNodeVariableDeclaration {
    Buf symbol;
    bool is_const;
    bool is_extern;
    VisibMod visib_mod;
    // one or both of type and expr will be non null
    AstNode *type;
    AstNode *expr;
    ZigList<AstNode *> *directives;

    // populated by semantic analyzer
    TopLevelDecl top_level_decl;
    Expr resolved_expr;
    VariableTableEntry *variable;
};

struct AstNodeTypeDecl {
    VisibMod visib_mod;
    ZigList<AstNode *> *directives;
    Buf symbol;
    AstNode *child_type;

    // populated by semantic analyzer
    TopLevelDecl top_level_decl;
    // if this is set, don't process the node; we've already done so
    // and here is the type (with id TypeTableEntryIdTypeDecl)
    TypeTableEntry *override_type;
};

struct AstNodeErrorValueDecl {
    Buf name;
    VisibMod visib_mod;
    ZigList<AstNode *> *directives;

    // populated by semantic analyzer
    TopLevelDecl top_level_decl;
    ErrorTableEntry *err;
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
    BinOpTypeStrCat,
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

struct AstNodeUnwrapErrorExpr {
    AstNode *op1;
    AstNode *symbol; // can be null
    AstNode *op2;

    // populated by semantic analyzer:
    Expr resolved_expr;
    VariableTableEntry *var;
};

enum CastOp {
    CastOpNoCast, // signifies the function call expression is not a cast
    CastOpNoop, // fn call expr is a cast, but does nothing
    CastOpPtrToInt,
    CastOpIntToPtr,
    CastOpWidenOrShorten,
    CastOpToUnknownSizeArray,
    CastOpMaybeWrap,
    CastOpErrorWrap,
    CastOpPureErrorWrap,
    CastOpPointerReinterpret,
    CastOpErrToInt,
    CastOpIntToFloat,
    CastOpFloatToInt,
    CastOpBoolToInt,
};

struct AstNodeFnCallExpr {
    AstNode *fn_ref_expr;
    ZigList<AstNode *> params;
    bool is_builtin;

    // populated by semantic analyzer:
    BuiltinFnEntry *builtin_fn;
    Expr resolved_expr;
    FnTableEntry *fn_entry;
    CastOp cast_op;
    TypeTableEntry *enum_type;
    // if cast_op is CastOpArrayToString, this will be a pointer to
    // the string struct on the stack
    LLVMValueRef tmp_ptr;
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
    bool is_fn_call;
    TypeTableEntry *bare_struct_type;
    bool is_member_fn;
};

struct AstNodeDirective {
    Buf name;
    AstNode *expr;
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
    PrefixOpError,
    PrefixOpUnwrapError,
    PrefixOpUnwrapMaybe,
};

struct AstNodePrefixOpExpr {
    PrefixOp prefix_op;
    AstNode *primary_expr;

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeImport {
    Buf path;
    ZigList<AstNode *> *directives;
    VisibMod visib_mod;

    // populated by semantic analyzer
    ImportTableEntry *import;
};

struct AstNodeCImport {
    ZigList<AstNode *> *directives;
    VisibMod visib_mod;
    AstNode *block;

    // populated by semantic analyzer
    TopLevelDecl top_level_decl;
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
    Expr resolved_expr;
};

struct AstNodeWhileExpr {
    AstNode *condition;
    AstNode *body;

    // populated by semantic analyzer
    bool condition_always_true;
    bool contains_break;
    bool contains_continue;
    Expr resolved_expr;
};

struct AstNodeForExpr {
    AstNode *elem_node; // always a symbol
    AstNode *array_expr;
    AstNode *index_node; // always a symbol, might be null
    AstNode *body;

    // populated by semantic analyzer
    bool contains_break;
    bool contains_continue;
    Expr resolved_expr;
    VariableTableEntry *elem_var;
    VariableTableEntry *index_var;
};

struct AstNodeSwitchExpr {
    AstNode *expr;
    ZigList<AstNode *> prongs;

    // populated by semantic analyzer
    Expr resolved_expr;
    int const_chosen_prong_index;
};

struct AstNodeSwitchProng {
    ZigList<AstNode *> items;
    AstNode *var_symbol;
    AstNode *expr;

    // populated by semantic analyzer
    BlockContext *block_context;
    VariableTableEntry *var;
    bool var_is_target_expr;
};

struct AstNodeSwitchRange {
    AstNode *start;
    AstNode *end;
};

struct AstNodeLabel {
    Buf name;

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeGoto {
    Buf name;

    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AsmOutput {
    Buf asm_symbolic_name;
    Buf constraint;
    Buf variable_name;
    AstNode *return_type; // null unless "=r" and return

    // populated by semantic analyzer
    VariableTableEntry *variable;
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
    VisibMod visib_mod;
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
    NumLitFloat,
    NumLitUInt,
};

struct AstNodeNumberLiteral {
    NumLit kind;

    // overflow is true if when parsing the number, we discovered it would not
    // fit without losing data in a uint64_t or double
    bool overflow;

    union {
        uint64_t x_uint;
        double x_float;
    } data;

    // populated by semantic analyzer
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

struct AstNodeUndefinedLiteral {
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
    // set this to instead of analyzing the node, pretend it's a type entry and it's this one.
    TypeTableEntry *override_type_entry;
    TypeEnumField *enum_field;
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

struct AstNodeErrorType {
    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNodeTypeLiteral {
    // populated by semantic analyzer
    Expr resolved_expr;
};

struct AstNode {
    enum NodeType type;
    int line;
    int column;
    uint32_t create_index; // for determinism purposes
    ImportTableEntry *owner;
    AstNode **parent_field; // for AST rewriting
    // the context in which this expression/node is evaluated.
    // for blocks, this points to the containing scope, not the block's own scope for its children.
    BlockContext *block_context;
    union {
        AstNodeRoot root;
        AstNodeRootExportDecl root_export_decl;
        AstNodeFnDef fn_def;
        AstNodeFnDecl fn_decl;
        AstNodeFnProto fn_proto;
        AstNodeParamDecl param_decl;
        AstNodeBlock block;
        AstNodeReturnExpr return_expr;
        AstNodeDefer defer;
        AstNodeVariableDeclaration variable_declaration;
        AstNodeTypeDecl type_decl;
        AstNodeErrorValueDecl error_value_decl;
        AstNodeBinOpExpr bin_op_expr;
        AstNodeUnwrapErrorExpr unwrap_err_expr;
        AstNodeDirective directive;
        AstNodePrefixOpExpr prefix_op_expr;
        AstNodeFnCallExpr fn_call_expr;
        AstNodeArrayAccessExpr array_access_expr;
        AstNodeSliceExpr slice_expr;
        AstNodeImport import;
        AstNodeCImport c_import;
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
        AstNodeUndefinedLiteral undefined_literal;
        AstNodeSymbolExpr symbol_expr;
        AstNodeBoolLiteral bool_literal;
        AstNodeBreakExpr break_expr;
        AstNodeContinueExpr continue_expr;
        AstNodeArrayType array_type;
        AstNodeErrorType error_type;
        AstNodeTypeLiteral type_literal;
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

// this struct is allocated with allocate_nonzero
struct FnTypeParamInfo {
    bool is_noalias;
    TypeTableEntry *type;
};

static const int fn_type_id_prealloc_param_info_count = 4;
struct FnTypeId {
    TypeTableEntry *return_type;
    FnTypeParamInfo *param_info;
    int param_count;
    bool is_var_args;
    bool is_naked;
    bool is_cold;
    bool is_extern;
    FnTypeParamInfo prealloc_param_info[fn_type_id_prealloc_param_info_count];
};

uint32_t fn_type_id_hash(FnTypeId*);
bool fn_type_id_eql(FnTypeId *a, FnTypeId *b);


struct TypeTableEntryPointer {
    TypeTableEntry *child_type;
    bool is_const;
};

struct TypeTableEntryInt {
    bool is_signed;
    int bit_count;
};

struct TypeTableEntryFloat {
    int bit_count;
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
    uint32_t src_field_count;
    uint32_t gen_field_count;
    TypeStructField *fields;
    uint64_t size_bytes;
    bool is_invalid; // true if any fields are invalid
    bool is_unknown_size_array;
    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
    // whether we've finished resolving it
    bool complete;
};

struct TypeTableEntryMaybe {
    TypeTableEntry *child_type;
};

struct TypeTableEntryError {
    TypeTableEntry *child_type;
};

struct TypeTableEntryEnum {
    AstNode *decl_node;
    uint32_t field_count;
    uint32_t gen_field_count;
    TypeEnumField *fields;
    bool is_invalid; // true if any fields are invalid
    TypeTableEntry *tag_type;
    TypeTableEntry *union_type;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
    // whether we've finished resolving it
    bool complete;
};

struct FnGenParamInfo {
    int src_index;
    int gen_index;
    bool is_byval;
    TypeTableEntry *type;
};

struct TypeTableEntryFn {
    FnTypeId fn_type_id;
    TypeTableEntry *gen_return_type;
    int gen_param_count;
    FnGenParamInfo *gen_param_info;

    LLVMTypeRef raw_type_ref;
    LLVMCallConv calling_convention;
};

struct TypeTableEntryTypeDecl {
    TypeTableEntry *child_type;
    TypeTableEntry *canonical_type;
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
    TypeTableEntryIdNumLitFloat,
    TypeTableEntryIdNumLitInt,
    TypeTableEntryIdUndefLit,
    TypeTableEntryIdMaybe,
    TypeTableEntryIdErrorUnion,
    TypeTableEntryIdPureError,
    TypeTableEntryIdEnum,
    TypeTableEntryIdFn,
    TypeTableEntryIdTypeDecl,
};

struct TypeTableEntry {
    TypeTableEntryId id;
    Buf name;

    LLVMTypeRef type_ref;
    LLVMZigDIType *di_type;

    bool zero_bits;

    union {
        TypeTableEntryPointer pointer;
        TypeTableEntryInt integral;
        TypeTableEntryFloat floating;
        TypeTableEntryArray array;
        TypeTableEntryStruct structure;
        TypeTableEntryMaybe maybe;
        TypeTableEntryError error;
        TypeTableEntryEnum enumeration;
        TypeTableEntryFn fn;
        TypeTableEntryTypeDecl type_decl;
    } data;

    // use these fields to make sure we don't duplicate type table entries for the same type
    TypeTableEntry *pointer_parent[2];
    TypeTableEntry *unknown_size_array_parent[2];
    HashMap<uint64_t, TypeTableEntry *, uint64_hash, uint64_eq> arrays_by_size;
    TypeTableEntry *maybe_parent;
    TypeTableEntry *error_parent;
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
    AstNode *c_import_node;
    bool any_imports_failed;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, FnTableEntry *, buf_hash, buf_eql_buf> fn_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> type_table;
    HashMap<Buf *, ErrorTableEntry *, buf_hash, buf_eql_buf> error_table;
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
    bool is_test;
    uint32_t ref_count; // if this is 0 we don't have to codegen it

    ZigList<AstNode *> cast_alloca_list;
    ZigList<StructValExprCodeGen *> struct_val_expr_alloca_list;
    ZigList<VariableTableEntry *> variable_list;
};

enum BuiltinFnId {
    BuiltinFnIdInvalid,
    BuiltinFnIdMemcpy,
    BuiltinFnIdMemset,
    BuiltinFnIdSizeof,
    BuiltinFnIdAlignof,
    BuiltinFnIdMaxValue,
    BuiltinFnIdMinValue,
    BuiltinFnIdMemberCount,
    BuiltinFnIdTypeof,
    BuiltinFnIdAddWithOverflow,
    BuiltinFnIdSubWithOverflow,
    BuiltinFnIdMulWithOverflow,
    BuiltinFnIdCInclude,
    BuiltinFnIdCDefine,
    BuiltinFnIdCUndef,
    BuiltinFnIdCompileVar,
    BuiltinFnIdConstEval,
    BuiltinFnIdCtz,
    BuiltinFnIdClz,
};

struct BuiltinFnEntry {
    BuiltinFnId id;
    Buf name;
    int param_count;
    TypeTableEntry *return_type;
    TypeTableEntry **param_types;
    uint32_t ref_count;
    LLVMValueRef fn_val;
};

struct CodeGen {
    LLVMModuleRef module;
    ZigList<ErrorMsg*> errors;
    LLVMBuilderRef builder;
    LLVMZigDIBuilder *dbuilder;
    LLVMZigDICompileUnit *compile_unit;

    ZigList<Buf *> lib_search_paths;
    ZigList<Buf *> link_libs;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, ImportTableEntry *, buf_hash, buf_eql_buf> import_table;
    HashMap<Buf *, BuiltinFnEntry *, buf_hash, buf_eql_buf> builtin_fn_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> primitive_type_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> unresolved_top_level_decls;
    HashMap<FnTypeId *, TypeTableEntry *, fn_type_id_hash, fn_type_id_eql> fn_type_table;
    HashMap<Buf *, ErrorTableEntry *, buf_hash, buf_eql_buf> error_table;

    uint32_t next_unresolved_index;

    struct {
        TypeTableEntry *entry_bool;
        TypeTableEntry *entry_int[2][4]; // [signed,unsigned][8,16,32,64]
        TypeTableEntry *entry_c_int[CIntTypeCount];
        TypeTableEntry *entry_c_long_double;
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
        TypeTableEntry *entry_void;
        TypeTableEntry *entry_unreachable;
        TypeTableEntry *entry_type;
        TypeTableEntry *entry_invalid;
        TypeTableEntry *entry_num_lit_int;
        TypeTableEntry *entry_num_lit_float;
        TypeTableEntry *entry_undef;
        TypeTableEntry *entry_pure_error;
        TypeTableEntry *entry_os_enum;
        TypeTableEntry *entry_arch_enum;
        TypeTableEntry *entry_environ_enum;
    } builtin_types;

    ZigTarget zig_target;
    LLVMTargetDataRef target_data_ref;
    unsigned pointer_size_bytes;
    bool is_big_endian;
    bool is_static;
    bool strip_debug_symbols;
    bool have_exported_main;
    bool link_libc;
    Buf *libc_lib_dir;
    Buf *libc_static_lib_dir;
    Buf *libc_include_dir;
    Buf *dynamic_linker;
    Buf *linker_path;
    Buf triple_str;
    bool is_release_build;
    bool is_test_build;
    uint32_t target_os_index;
    uint32_t target_arch_index;
    uint32_t target_environ_index;
    LLVMTargetMachineRef target_machine;
    LLVMZigDIFile *dummy_di_file;
    bool is_native_target;
    Buf *root_source_dir;
    Buf *root_out_name;
    bool windows_subsystem_windows;
    bool windows_subsystem_console;
    bool windows_linker_unicode;
    Buf *darwin_linker_version;
    Buf *mmacosx_version_min;
    Buf *mios_version_min;
    bool linker_rdynamic;

    // The function definitions this module includes. There must be a corresponding
    // fn_protos entry.
    ZigList<FnTableEntry *> fn_defs;
    // The function prototypes this module includes. In the case of external declarations,
    // there will not be a corresponding fn_defs entry.
    ZigList<FnTableEntry *> fn_protos;
    ZigList<VariableTableEntry *> global_vars;
    ZigList<AstNode *> global_const_list;

    OutType out_type;
    FnTableEntry *cur_fn;
    FnTableEntry *main_fn;
    LLVMValueRef cur_ret_ptr;
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
    ImportTableEntry *test_runner_import;
    LLVMValueRef memcpy_fn_val;
    LLVMValueRef memset_fn_val;
    LLVMValueRef trap_fn_val;
    bool error_during_imports;
    uint32_t next_node_index;
    uint32_t error_value_count;
    TypeTableEntry *err_tag_type;
    LLVMValueRef int_overflow_fns[2][3][4]; // [0-signed,1-unsigned][0-add,1-sub,2-mul][0-8,1-16,2-32,3-64]
    LLVMValueRef int_builtin_fns[2][4]; // [0-ctz,1-clz][0-8,1-16,2-32,3-64]

    const char **clang_argv;
    int clang_argv_len;
    ZigList<const char *> lib_dirs;

    uint32_t test_fn_count;
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
    BlockContext *block_context;
};

struct ErrorTableEntry {
    Buf name;
    uint32_t value;
    AstNode *decl_node;
};

struct BlockContext {
    // One of: NodeTypeFnDef, NodeTypeBlock, NodeTypeRoot, NodeTypeDefer, NodeTypeVariableDeclaration
    AstNode *node;

    // any variables that are introduced by this scope
    HashMap<Buf *, VariableTableEntry *, buf_hash, buf_eql_buf> variable_table;

    // if the block is inside a function, this is the function it is in:
    FnTableEntry *fn_entry;

    // if the block has a parent, this is it
    BlockContext *parent;

    // if break or continue is valid in this context, this is the loop node that
    // it would pertain to
    AstNode *parent_loop_node;

    LLVMZigDIScope *di_scope;
    Buf *c_import_buf;

    // if this is true, then this code will not be generated
    bool codegen_excluded;
};



#endif
