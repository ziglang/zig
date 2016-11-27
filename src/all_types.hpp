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
struct FnTableEntry;
struct BlockContext;
struct TypeTableEntry;
struct VariableTableEntry;
struct ErrorTableEntry;
struct LabelTableEntry;
struct BuiltinFnEntry;
struct TypeStructField;
struct CodeGen;
struct ConstExprValue;
struct IrInstruction;
struct IrInstructionCast;
struct IrBasicBlock;

struct IrExecutable {
    ZigList<IrBasicBlock *> basic_block_list;
    size_t mem_slot_count;
    size_t next_debug_id;
    bool invalid;
    ZigList<LabelTableEntry *> all_labels;
    ZigList<AstNode *> goto_list;
};

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
    ConstExprValue *fields;
};

struct ConstArrayValue {
    ConstExprValue *elements;
    // This will be the same as `len` from the type, but we duplicate the information
    // in the constant value so that pointers pointing to arrays can see this size.
    size_t size;
};

struct ConstPtrValue {
    ConstExprValue *base_ptr;
    // If index is SIZE_MAX, then base_ptr points directly to child type.
    // Otherwise base_ptr points to an array const val and index is offset
    // in object units from base_ptr into the block of memory pointed to
    size_t index;
    // This flag helps us preserve the null byte when performing compile-time
    // concatenation on C strings.
    bool is_c_str;
};

struct ConstErrValue {
    ErrorTableEntry *err;
    ConstExprValue *payload;
};

enum ConstValSpecial {
    ConstValSpecialRuntime,
    ConstValSpecialStatic,
    ConstValSpecialUndef,
    ConstValSpecialZeroes,
};

struct ConstExprValue {
    ConstValSpecial special;
    bool depends_on_compile_var;
    LLVMValueRef llvm_value;
    LLVMValueRef llvm_global;

    // populated if val_type == ConstValTypeOk
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
        ImportTableEntry *x_import;
        BlockContext *x_block;
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

struct StructValExprCodeGen {
    TypeTableEntry *type_entry;
    LLVMValueRef ptr;
    AstNode *source_node;
};

enum VisibMod {
    VisibModPrivate,
    VisibModPub,
    VisibModExport,
};

enum TldResolution {
    TldResolutionUnresolved,
    TldResolutionInvalid,
    TldResolutionOk,
};

struct TopLevelDecl {
    // populated by parser
    Buf *name;
    VisibMod visib_mod;

    // populated by semantic analyzer
    ImportTableEntry *import;
    // set this flag temporarily to detect infinite loops
    bool dep_loop_flag;
    TldResolution resolution;
    AstNode *parent_decl;
    IrInstruction *value;
};

struct TypeEnumField {
    Buf *name;
    TypeTableEntry *type_entry;
    uint32_t value;
};

enum NodeType {
    NodeTypeRoot,
    NodeTypeFnProto,
    NodeTypeFnDef,
    NodeTypeFnDecl,
    NodeTypeParamDecl,
    NodeTypeBlock,
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
    NodeTypeUse,
    NodeTypeBoolLiteral,
    NodeTypeNullLiteral,
    NodeTypeUndefinedLiteral,
    NodeTypeZeroesLiteral,
    NodeTypeThisLiteral,
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
    NodeTypeContainerDecl,
    NodeTypeStructField,
    NodeTypeContainerInitExpr,
    NodeTypeStructValueField,
    NodeTypeArrayType,
    NodeTypeErrorType,
    NodeTypeTypeLiteral,
    NodeTypeVarLiteral,
};

struct AstNodeRoot {
    ZigList<AstNode *> top_level_decls;
};

struct AstNodeFnProto {
    TopLevelDecl top_level_decl;
    Buf *name;
    ZigList<AstNode *> params;
    AstNode *return_type;
    bool is_var_args;
    bool is_extern;
    bool is_inline;
    bool is_coldcc;
    bool is_nakedcc;

    // populated by semantic analyzer:

    // the function definition this fn proto is inside. can be null.
    AstNode *fn_def_node;
    FnTableEntry *fn_table_entry;
    bool skip;
    // computed from params field
    size_t inline_arg_count;
    size_t inline_or_var_type_arg_count;
    // if this is a generic function implementation, this points to the generic node
    AstNode *generic_proto_node;
};

struct AstNodeFnDef {
    AstNode *fn_proto;
    AstNode *body;

    // populated by semantic analyzer
    TypeTableEntry *implicit_return_type;
    // the first child block context
    BlockContext *block_context;
};

struct AstNodeFnDecl {
    AstNode *fn_proto;
};

struct AstNodeParamDecl {
    Buf *name;
    AstNode *type;
    bool is_noalias;
    bool is_inline;

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
};

struct AstNodeDefer {
    ReturnKind kind;
    AstNode *expr;

    // populated by semantic analyzer:
    size_t index_in_block;
    LLVMBasicBlockRef basic_block;
    BlockContext *child_block;
};

struct AstNodeVariableDeclaration {
    TopLevelDecl top_level_decl;
    Buf *symbol;
    bool is_const;
    bool is_inline;
    bool is_extern;
    // one or both of type and expr will be non null
    AstNode *type;
    AstNode *expr;

    // populated by semantic analyzer
    VariableTableEntry *variable;
};

struct AstNodeTypeDecl {
    TopLevelDecl top_level_decl;
    Buf *symbol;
    AstNode *child_type;

    // populated by semantic analyzer
    // if this is set, don't process the node; we've already done so
    // and here is the type (with id TypeTableEntryIdTypeDecl)
    TypeTableEntry *override_type;
    TypeTableEntry *child_type_entry;
};

struct AstNodeErrorValueDecl {
    TopLevelDecl top_level_decl;
    Buf *name;

    // populated by semantic analyzer
    ErrorTableEntry *err;
};

enum BinOpType {
    BinOpTypeInvalid,
    BinOpTypeAssign,
    BinOpTypeAssignTimes,
    BinOpTypeAssignTimesWrap,
    BinOpTypeAssignDiv,
    BinOpTypeAssignMod,
    BinOpTypeAssignPlus,
    BinOpTypeAssignPlusWrap,
    BinOpTypeAssignMinus,
    BinOpTypeAssignMinusWrap,
    BinOpTypeAssignBitShiftLeft,
    BinOpTypeAssignBitShiftLeftWrap,
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
    BinOpTypeBitShiftLeftWrap,
    BinOpTypeBitShiftRight,
    BinOpTypeAdd,
    BinOpTypeAddWrap,
    BinOpTypeSub,
    BinOpTypeSubWrap,
    BinOpTypeMult,
    BinOpTypeMultWrap,
    BinOpTypeDiv,
    BinOpTypeMod,
    BinOpTypeUnwrapMaybe,
    BinOpTypeArrayCat,
    BinOpTypeArrayMult,
};

struct AstNodeBinOpExpr {
    AstNode *op1;
    BinOpType bin_op;
    AstNode *op2;

    // populated by semantic analyzer:
    // for when op is BinOpTypeAssign
    VariableTableEntry *var_entry;
};

struct AstNodeUnwrapErrorExpr {
    AstNode *op1;
    AstNode *symbol; // can be null
    AstNode *op2;

    // populated by semantic analyzer:
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
    CastOpNullToMaybe,
    CastOpErrorWrap,
    CastOpPureErrorWrap,
    CastOpPointerReinterpret,
    CastOpErrToInt,
    CastOpIntToFloat,
    CastOpFloatToInt,
    CastOpBoolToInt,
    CastOpResizeSlice,
    CastOpIntToEnum,
    CastOpEnumToInt,
    CastOpBytesToSlice,
};

struct AstNodeFnCallExpr {
    AstNode *fn_ref_expr;
    ZigList<AstNode *> params;
    bool is_builtin;

    // populated by semantic analyzer:
    BuiltinFnEntry *builtin_fn;
    FnTableEntry *fn_entry;
    CastOp cast_op;
    // if cast_op is CastOpArrayToString, this will be a pointer to
    // the string struct on the stack
    LLVMValueRef tmp_ptr;
};

struct AstNodeArrayAccessExpr {
    AstNode *array_ref_expr;
    AstNode *subscript;

    // populated by semantic analyzer:
};

struct AstNodeSliceExpr {
    AstNode *array_ref_expr;
    AstNode *start;
    AstNode *end;
    bool is_const;

    // populated by semantic analyzer:
    StructValExprCodeGen resolved_struct_val_expr;
};

struct AstNodeFieldAccessExpr {
    AstNode *struct_expr;
    Buf *field_name;

    // populated by semantic analyzer
    TypeStructField *type_struct_field;
    TypeEnumField *type_enum_field;
    StructValExprCodeGen resolved_struct_val_expr; // for enum values
    TypeTableEntry *bare_container_type;
    bool is_member_fn;
    AstNode *container_init_expr_node;
};

enum PrefixOp {
    PrefixOpInvalid,
    PrefixOpBoolNot,
    PrefixOpBinNot,
    PrefixOpNegation,
    PrefixOpNegationWrap,
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
};

struct AstNodeUse {
    AstNode *expr;

    // populated by semantic analyzer
    TopLevelDecl top_level_decl;
};

struct AstNodeIfBoolExpr {
    AstNode *condition;
    AstNode *then_block;
    AstNode *else_node; // null, block node, or other if expr node

    // populated by semantic analyzer
};

struct AstNodeIfVarExpr {
    AstNodeVariableDeclaration var_decl;
    AstNode *then_block;
    AstNode *else_node; // null, block node, or other if expr node
    bool var_is_ptr;

    // populated by semantic analyzer
    TypeTableEntry *type;
};

struct AstNodeWhileExpr {
    AstNode *condition;
    AstNode *continue_expr;
    AstNode *body;
    bool is_inline;

    // populated by semantic analyzer
    bool condition_always_true;
    bool contains_break;
    bool contains_continue;
};

struct AstNodeForExpr {
    AstNode *array_expr;
    AstNode *elem_node; // always a symbol
    AstNode *index_node; // always a symbol, might be null
    AstNode *body;
    bool elem_is_ptr;
    bool is_inline;

    // populated by semantic analyzer
    bool contains_break;
    bool contains_continue;
    VariableTableEntry *elem_var;
    VariableTableEntry *index_var;
};

struct AstNodeSwitchExpr {
    AstNode *expr;
    ZigList<AstNode *> prongs;
    bool is_inline;

    // populated by semantic analyzer
};

struct AstNodeSwitchProng {
    ZigList<AstNode *> items;
    AstNode *var_symbol;
    AstNode *expr;
    bool var_is_ptr;
    bool any_items_are_range;
};

struct AstNodeSwitchRange {
    AstNode *start;
    AstNode *end;
};

struct AstNodeLabel {
    Buf *name;
};

struct AstNodeGoto {
    Buf *name;
    bool is_inline;

    // populated by semantic analyzer
    IrBasicBlock *bb;
    size_t instruction_index;
};

struct AsmOutput {
    Buf *asm_symbolic_name;
    Buf *constraint;
    Buf *variable_name;
    AstNode *return_type; // null unless "=r" and return

    // populated by semantic analyzer
    VariableTableEntry *variable;
};

struct AsmInput {
    Buf *asm_symbolic_name;
    Buf *constraint;
    AstNode *expr;
};

struct SrcPos {
    size_t line;
    size_t column;
};

enum AsmTokenId {
    AsmTokenIdTemplate,
    AsmTokenIdPercent,
    AsmTokenIdVar,
};

struct AsmToken {
    enum AsmTokenId id;
    size_t start;
    size_t end;
};

struct AstNodeAsmExpr {
    bool is_volatile;
    Buf *asm_template;
    ZigList<AsmToken> token_list;
    ZigList<AsmOutput*> output_list;
    ZigList<AsmInput*> input_list;
    ZigList<Buf*> clobber_list;

    // populated by semantic analyzer
};

enum ContainerKind {
    ContainerKindStruct,
    ContainerKindEnum,
    ContainerKindUnion,
};

struct AstNodeStructDecl {
    TopLevelDecl top_level_decl;
    Buf *name;
    ContainerKind kind;
    ZigList<AstNode *> generic_params;
    bool generic_params_is_var_args; // always an error but it can happen from parsing
    ZigList<AstNode *> fields;
    ZigList<AstNode *> decls;

    // populated by semantic analyzer
    BlockContext *block_context;
    TypeTableEntry *type_entry;
    TypeTableEntry *generic_fn_type;
    bool skip;
};

struct AstNodeStructField {
    TopLevelDecl top_level_decl;
    Buf *name;
    AstNode *type;
};

struct AstNodeStringLiteral {
    Buf *buf;
    bool c;

    // populated by semantic analyzer:
};

struct AstNodeCharLiteral {
    uint8_t value;

    // populated by semantic analyzer:
};

struct AstNodeNumberLiteral {
    BigNum *bignum;

    // overflow is true if when parsing the number, we discovered it would not
    // fit without losing data in a uint64_t or double
    bool overflow;

    // populated by semantic analyzer
};

struct AstNodeStructValueField {
    Buf *name;
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
    TypeTableEntry *enum_type;
};

struct AstNodeNullLiteral {
    // populated by semantic analyzer
};

struct AstNodeUndefinedLiteral {
    // populated by semantic analyzer
};

struct AstNodeZeroesLiteral {
    // populated by semantic analyzer
};

struct AstNodeThisLiteral {
    // populated by semantic analyzer
};

struct AstNodeSymbolExpr {
    Buf *symbol;

    // populated by semantic analyzer
    TypeEnumField *enum_field;
    uint32_t err_value;
};

struct AstNodeBoolLiteral {
    bool value;

    // populated by semantic analyzer
};

struct AstNodeBreakExpr {
    // populated by semantic analyzer
};

struct AstNodeContinueExpr {
    // populated by semantic analyzer
};

struct AstNodeArrayType {
    AstNode *size;
    AstNode *child_type;
    bool is_const;

    // populated by semantic analyzer
};

struct AstNodeErrorType {
    // populated by semantic analyzer
};

struct AstNodeTypeLiteral {
    // populated by semantic analyzer
};

struct AstNodeVarLiteral {
    // populated by semantic analyzer
};

struct AstNode {
    enum NodeType type;
    size_t line;
    size_t column;
    uint32_t create_index; // for determinism purposes
    ImportTableEntry *owner;
    // the context in which this expression/node is evaluated.
    // for blocks, this points to the containing scope, not the block's own scope for its children.
    BlockContext *block_context;
    union {
        AstNodeRoot root;
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
        AstNodeUndefinedLiteral undefined_literal;
        AstNodeZeroesLiteral zeroes_literal;
        AstNodeThisLiteral this_literal;
        AstNodeSymbolExpr symbol_expr;
        AstNodeBoolLiteral bool_literal;
        AstNodeBreakExpr break_expr;
        AstNodeContinueExpr continue_expr;
        AstNodeArrayType array_type;
        AstNodeErrorType error_type;
        AstNodeTypeLiteral type_literal;
        AstNodeVarLiteral var_literal;
    } data;
};

// this struct is allocated with allocate_nonzero
struct FnTypeParamInfo {
    bool is_noalias;
    TypeTableEntry *type;
};

struct GenericParamValue {
    TypeTableEntry *type;
    AstNode *node;
    size_t impl_index;
};

struct GenericFnTypeId {
    AstNode *decl_node; // the generic fn or container decl node
    GenericParamValue *generic_params;
    size_t generic_param_count;
};

uint32_t generic_fn_type_id_hash(GenericFnTypeId *id);
bool generic_fn_type_id_eql(GenericFnTypeId *a, GenericFnTypeId *b);


struct FnTypeId {
    TypeTableEntry *return_type;
    FnTypeParamInfo *param_info;
    size_t param_count;
    bool is_var_args;
    bool is_naked;
    bool is_cold;
    bool is_extern;
};

uint32_t fn_type_id_hash(FnTypeId*);
bool fn_type_id_eql(FnTypeId *a, FnTypeId *b);

struct TypeTableEntryPointer {
    TypeTableEntry *child_type;
    bool is_const;
};

struct TypeTableEntryInt {
    size_t bit_count;
    bool is_signed;
};

struct TypeTableEntryFloat {
    size_t bit_count;
};

struct TypeTableEntryArray {
    TypeTableEntry *child_type;
    uint64_t len;
};

struct TypeStructField {
    Buf *name;
    TypeTableEntry *type_entry;
    size_t src_index;
    size_t gen_index;
};
struct TypeTableEntryStruct {
    AstNode *decl_node;
    bool is_packed;
    uint32_t src_field_count;
    uint32_t gen_field_count;
    TypeStructField *fields;
    uint64_t size_bytes;
    bool is_invalid; // true if any fields are invalid
    bool is_slice;
    BlockContext *block_context;

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
    uint32_t src_field_count;
    uint32_t gen_field_count;
    TypeEnumField *fields;
    bool is_invalid; // true if any fields are invalid
    TypeTableEntry *tag_type;
    TypeTableEntry *union_type;

    BlockContext *block_context;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
    // whether we've finished resolving it
    bool complete;
};

struct TypeTableEntryUnion {
    AstNode *decl_node;
    uint32_t src_field_count;
    uint32_t gen_field_count;
    TypeStructField *fields;
    uint64_t size_bytes;
    bool is_invalid; // true if any fields are invalid
    BlockContext *block_context;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
    // whether we've finished resolving it
    bool complete;
};

struct FnGenParamInfo {
    size_t src_index;
    size_t gen_index;
    bool is_byval;
    TypeTableEntry *type;
};

struct TypeTableEntryFn {
    FnTypeId fn_type_id;
    TypeTableEntry *gen_return_type;
    size_t gen_param_count;
    FnGenParamInfo *gen_param_info;

    LLVMTypeRef raw_type_ref;
    LLVMCallConv calling_convention;
};

struct TypeTableEntryGenericFn {
    AstNode *decl_node;
};

struct TypeTableEntryTypeDecl {
    TypeTableEntry *child_type;
    TypeTableEntry *canonical_type;
};

enum TypeTableEntryId {
    TypeTableEntryIdInvalid,
    TypeTableEntryIdVar,
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
    TypeTableEntryIdNullLit,
    TypeTableEntryIdMaybe,
    TypeTableEntryIdErrorUnion,
    TypeTableEntryIdPureError,
    TypeTableEntryIdEnum,
    TypeTableEntryIdUnion,
    TypeTableEntryIdFn,
    TypeTableEntryIdTypeDecl,
    TypeTableEntryIdNamespace,
    TypeTableEntryIdBlock,
    TypeTableEntryIdGenericFn,
};

struct TypeTableEntry {
    TypeTableEntryId id;
    Buf name;

    LLVMTypeRef type_ref;
    ZigLLVMDIType *di_type;

    bool zero_bits;
    bool deep_const;

    union {
        TypeTableEntryPointer pointer;
        TypeTableEntryInt integral;
        TypeTableEntryFloat floating;
        TypeTableEntryArray array;
        TypeTableEntryStruct structure;
        TypeTableEntryMaybe maybe;
        TypeTableEntryError error;
        TypeTableEntryEnum enumeration;
        TypeTableEntryUnion unionation;
        TypeTableEntryFn fn;
        TypeTableEntryTypeDecl type_decl;
        TypeTableEntryGenericFn generic_fn;
    } data;

    // use these fields to make sure we don't duplicate type table entries for the same type
    TypeTableEntry *pointer_parent[2];
    TypeTableEntry *unknown_size_array_parent[2];
    HashMap<uint64_t, TypeTableEntry *, uint64_hash, uint64_eq> arrays_by_size;
    TypeTableEntry *maybe_parent;
    TypeTableEntry *error_parent;
};

struct PackageTableEntry {
    Buf root_src_dir;
    Buf root_src_path; // relative to root_src_dir

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, PackageTableEntry *, buf_hash, buf_eql_buf> package_table;
};

struct ImportTableEntry {
    AstNode *root;
    Buf *path; // relative to root_package->root_src_dir
    PackageTableEntry *package;
    ZigLLVMDIFile *di_file;
    Buf *source_code;
    ZigList<size_t> *line_offsets;
    BlockContext *block_context;
    AstNode *c_import_node;
    bool any_imports_failed;

    ZigList<AstNode *> use_decls;
};

enum FnAnalState {
    FnAnalStateReady,
    FnAnalStateProbing,
    FnAnalStateComplete,
    FnAnalStateSkipped,
};


enum WantPure {
    WantPureAuto,
    WantPureFalse,
    WantPureTrue,
};

enum FnInline {
    FnInlineAuto,
    FnInlineAlways,
    FnInlineNever,
};

struct FnTableEntry {
    LLVMValueRef fn_value;
    AstNode *proto_node;
    AstNode *fn_def_node;
    ImportTableEntry *import_entry;
    // Required to be a pre-order traversal of the AST. (parents must come before children)
    ZigList<BlockContext *> all_block_contexts;
    Buf symbol_name;
    TypeTableEntry *type_entry; // function type
    bool internal_linkage;
    bool is_extern;
    bool is_test;
    bool is_pure;
    WantPure want_pure;
    AstNode *want_pure_attr_node;
    AstNode *want_pure_return_type;
    FnInline fn_inline;
    FnAnalState anal_state;
    IrExecutable ir_executable;
    IrExecutable analyzed_executable;

    AstNode *fn_no_inline_set_node;
    AstNode *fn_export_set_node;
    AstNode *fn_test_set_node;
    AstNode *fn_static_eval_set_node;

    ZigList<IrInstructionCast *> cast_alloca_list;
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
    BuiltinFnIdShlWithOverflow,
    BuiltinFnIdCInclude,
    BuiltinFnIdCDefine,
    BuiltinFnIdCUndef,
    BuiltinFnIdCompileVar,
    BuiltinFnIdCompileErr,
    BuiltinFnIdStaticEval,
    BuiltinFnIdCtz,
    BuiltinFnIdClz,
    BuiltinFnIdImport,
    BuiltinFnIdCImport,
    BuiltinFnIdErrName,
    BuiltinFnIdBreakpoint,
    BuiltinFnIdReturnAddress,
    BuiltinFnIdFrameAddress,
    BuiltinFnIdEmbedFile,
    BuiltinFnIdCmpExchange,
    BuiltinFnIdFence,
    BuiltinFnIdDivExact,
    BuiltinFnIdTruncate,
    BuiltinFnIdIntType,
    BuiltinFnIdUnreachable,
    BuiltinFnIdSetFnTest,
    BuiltinFnIdSetFnVisible,
    BuiltinFnIdSetFnStaticEval,
    BuiltinFnIdSetFnNoInline,
    BuiltinFnIdSetDebugSafety,
};

struct BuiltinFnEntry {
    BuiltinFnId id;
    Buf name;
    size_t param_count;
    TypeTableEntry *return_type;
    TypeTableEntry **param_types;
    uint32_t ref_count;
    LLVMValueRef fn_val;
};

struct CodeGen {
    LLVMModuleRef module;
    ZigList<ErrorMsg*> errors;
    LLVMBuilderRef builder;
    ZigLLVMDIBuilder *dbuilder;
    ZigLLVMDICompileUnit *compile_unit;

    ZigList<Buf *> link_libs; // non-libc link libs
    // add -framework [name] args to linker
    ZigList<Buf *> darwin_frameworks;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, ImportTableEntry *, buf_hash, buf_eql_buf> import_table;
    HashMap<Buf *, BuiltinFnEntry *, buf_hash, buf_eql_buf> builtin_fn_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> primitive_type_table;
    HashMap<FnTypeId *, TypeTableEntry *, fn_type_id_hash, fn_type_id_eql> fn_type_table;
    HashMap<Buf *, ErrorTableEntry *, buf_hash, buf_eql_buf> error_table;
    HashMap<GenericFnTypeId *, AstNode *, generic_fn_type_id_hash, generic_fn_type_id_eql> generic_table;

    ZigList<ImportTableEntry *> import_queue;
    size_t import_queue_index;
    ZigList<AstNode *> resolve_queue;
    size_t resolve_queue_index;
    ZigList<AstNode *> use_queue;
    size_t use_queue_index;

    uint32_t next_unresolved_index;

    struct {
        TypeTableEntry *entry_bool;
        TypeTableEntry *entry_int[2][4]; // [signed,unsigned][8,16,32,64]
        TypeTableEntry *entry_c_int[CIntTypeCount];
        TypeTableEntry *entry_c_long_double;
        TypeTableEntry *entry_c_void;
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
        TypeTableEntry *entry_namespace;
        TypeTableEntry *entry_block;
        TypeTableEntry *entry_num_lit_int;
        TypeTableEntry *entry_num_lit_float;
        TypeTableEntry *entry_undef;
        TypeTableEntry *entry_null;
        TypeTableEntry *entry_var;
        TypeTableEntry *entry_pure_error;
        TypeTableEntry *entry_os_enum;
        TypeTableEntry *entry_arch_enum;
        TypeTableEntry *entry_environ_enum;
        TypeTableEntry *entry_oformat_enum;
        TypeTableEntry *entry_atomic_order_enum;
    } builtin_types;

    ZigTarget zig_target;
    LLVMTargetDataRef target_data_ref;
    unsigned pointer_size_bytes;
    bool is_big_endian;
    bool is_static;
    bool strip_debug_symbols;
    bool want_h_file;
    bool have_exported_main;
    bool link_libc;
    Buf *libc_lib_dir;
    Buf *libc_static_lib_dir;
    Buf *libc_include_dir;
    Buf *zig_std_dir;
    Buf *dynamic_linker;
    Buf *linker_path;
    Buf *ar_path;
    Buf triple_str;
    bool is_release_build;
    bool is_test_build;
    uint32_t target_os_index;
    uint32_t target_arch_index;
    uint32_t target_environ_index;
    uint32_t target_oformat_index;
    LLVMTargetMachineRef target_machine;
    ZigLLVMDIFile *dummy_di_file;
    bool is_native_target;
    PackageTableEntry *root_package;
    PackageTableEntry *std_package;
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

    OutType out_type;
    FnTableEntry *cur_fn;
    FnTableEntry *main_fn;
    LLVMValueRef cur_ret_ptr;
    ZigList<LLVMBasicBlockRef> break_block_stack;
    ZigList<LLVMBasicBlockRef> continue_block_stack;
    bool c_want_stdint;
    bool c_want_stdbool;
    AstNode *root_export_decl;
    size_t version_major;
    size_t version_minor;
    size_t version_patch;
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
    TypeTableEntry *err_tag_type;
    LLVMValueRef int_overflow_fns[2][3][4]; // [0-signed,1-unsigned][0-add,1-sub,2-mul][0-8,1-16,2-32,3-64]
    LLVMValueRef int_builtin_fns[2][4]; // [0-ctz,1-clz][0-8,1-16,2-32,3-64]

    const char **clang_argv;
    size_t clang_argv_len;
    ZigList<const char *> lib_dirs;

    uint32_t test_fn_count;

    bool check_unused;

    ZigList<AstNode *> error_decls;
    bool generate_error_name_table;
    LLVMValueRef err_name_table;

    IrInstruction *invalid_instruction;
};

struct VariableTableEntry {
    Buf name;
    TypeTableEntry *type;
    LLVMValueRef value_ref;
    bool src_is_const;
    bool gen_is_const;
    bool is_inline;
    // which node is the declaration of the variable
    AstNode *decl_node;
    // which node contains the ConstExprValue for this variable's value
    AstNode *val_node;
    ZigLLVMDILocalVariable *di_loc_var;
    size_t src_arg_index;
    size_t gen_arg_index;
    BlockContext *block_context;
    LLVMValueRef param_value_ref;
    bool force_depends_on_compile_var;
    ImportTableEntry *import;
    bool shadowable;
    size_t mem_slot_index;
    size_t ref_count;
};

struct ErrorTableEntry {
    Buf name;
    uint32_t value;
    AstNode *decl_node;
};

struct LabelTableEntry {
    AstNode *decl_node;
    IrBasicBlock *bb;
    bool used;
};

struct BlockContext {
    AstNode *node;

    // any variables that are introduced by this scope
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> decl_table;
    HashMap<Buf *, VariableTableEntry *, buf_hash, buf_eql_buf> var_table;
    HashMap<Buf *, LabelTableEntry *, buf_hash, buf_eql_buf> label_table; 

    // if the block is inside a function, this is the function it is in:
    FnTableEntry *fn_entry;

    // if the block has a parent, this is it
    BlockContext *parent;

    // if break or continue is valid in this context, this is the loop node that
    // it would pertain to
    AstNode *parent_loop_node;

    ZigLLVMDIScope *di_scope;
    Buf *c_import_buf;

    bool safety_off;
    AstNode *safety_set_node;
};

enum AtomicOrder {
    AtomicOrderUnordered,
    AtomicOrderMonotonic,
    AtomicOrderAcquire,
    AtomicOrderRelease,
    AtomicOrderAcqRel,
    AtomicOrderSeqCst,
};

// A basic block contains no branching. Branches send control flow
// to another basic block.
// Phi instructions must be first in a basic block.
// The last instruction in a basic block must be an expression of type unreachable.
struct IrBasicBlock {
    ZigList<IrInstruction *> instruction_list;
    IrBasicBlock *other;
    const char *name_hint;
    size_t debug_id;
    size_t ref_count;
    LLVMBasicBlockRef llvm_block;
};

enum IrInstructionId {
    IrInstructionIdInvalid,
    IrInstructionIdBr,
    IrInstructionIdCondBr,
    IrInstructionIdSwitchBr,
    IrInstructionIdSwitchVar,
    IrInstructionIdSwitchTarget,
    IrInstructionIdPhi,
    IrInstructionIdUnOp,
    IrInstructionIdBinOp,
    IrInstructionIdDeclVar,
    IrInstructionIdLoadPtr,
    IrInstructionIdStorePtr,
    IrInstructionIdFieldPtr,
    IrInstructionIdStructFieldPtr,
    IrInstructionIdElemPtr,
    IrInstructionIdVarPtr,
    IrInstructionIdCall,
    IrInstructionIdConst,
    IrInstructionIdReturn,
    IrInstructionIdCast,
    IrInstructionIdContainerInitList,
    IrInstructionIdContainerInitFields,
    IrInstructionIdUnreachable,
    IrInstructionIdTypeOf,
    IrInstructionIdToPtrType,
    IrInstructionIdPtrTypeChild,
    IrInstructionIdSetFnTest,
    IrInstructionIdSetFnVisible,
    IrInstructionIdSetDebugSafety,
    IrInstructionIdArrayType,
    IrInstructionIdSliceType,
    IrInstructionIdAsm,
    IrInstructionIdCompileVar,
    IrInstructionIdSizeOf,
    IrInstructionIdTestNull,
    IrInstructionIdUnwrapMaybe,
    IrInstructionIdEnumTag,
    IrInstructionIdClz,
    IrInstructionIdCtz,
    IrInstructionIdStaticEval,
    IrInstructionIdImport,
    IrInstructionIdArrayLen,
};

struct IrInstruction {
    IrInstructionId id;
    AstNode *source_node;
    ConstExprValue static_value;
    TypeTableEntry *type_entry;
    size_t debug_id;
    LLVMValueRef llvm_value;
    // if ref_count is zero, instruction can be omitted in codegen
    size_t ref_count;
    IrInstruction *other;
    ReturnKnowledge return_knowledge;
};

struct IrInstructionCondBr {
    IrInstruction base;

    IrInstruction *condition;
    IrBasicBlock *then_block;
    IrBasicBlock *else_block;
    bool is_inline;
};

struct IrInstructionBr {
    IrInstruction base;

    IrBasicBlock *dest_block;
    bool is_inline;
};

struct IrInstructionSwitchBrCase {
    IrInstruction *value;
    IrBasicBlock *block;
};

struct IrInstructionSwitchBr {
    IrInstruction base;

    IrInstruction *target_value;
    IrBasicBlock *else_block;
    size_t case_count;
    IrInstructionSwitchBrCase *cases;
    bool is_inline;
};

struct IrInstructionSwitchVar {
    IrInstruction base;

    IrInstruction *target_value_ptr;
    IrInstruction *prong_value;
};

struct IrInstructionSwitchTarget {
    IrInstruction base;

    IrInstruction *target_value_ptr;
};

struct IrInstructionPhi {
    IrInstruction base;

    size_t incoming_count;
    IrBasicBlock **incoming_blocks;
    IrInstruction **incoming_values;
};

enum IrUnOp {
    IrUnOpInvalid,
    IrUnOpBoolNot,
    IrUnOpBinNot,
    IrUnOpNegation,
    IrUnOpNegationWrap,
    IrUnOpAddressOf,
    IrUnOpConstAddressOf,
    IrUnOpDereference,
    IrUnOpError,
    IrUnOpMaybe,
    IrUnOpUnwrapError,
    IrUnOpUnwrapMaybe,
    IrUnOpErrorReturn,
    IrUnOpMaybeReturn,
};

struct IrInstructionUnOp {
    IrInstruction base;

    IrUnOp op_id;
    IrInstruction *value;
};

enum IrBinOp {
    IrBinOpInvalid,
    IrBinOpBoolOr,
    IrBinOpBoolAnd,
    IrBinOpCmpEq,
    IrBinOpCmpNotEq,
    IrBinOpCmpLessThan,
    IrBinOpCmpGreaterThan,
    IrBinOpCmpLessOrEq,
    IrBinOpCmpGreaterOrEq,
    IrBinOpBinOr,
    IrBinOpBinXor,
    IrBinOpBinAnd,
    IrBinOpBitShiftLeft,
    IrBinOpBitShiftLeftWrap,
    IrBinOpBitShiftRight,
    IrBinOpAdd,
    IrBinOpAddWrap,
    IrBinOpSub,
    IrBinOpSubWrap,
    IrBinOpMult,
    IrBinOpMultWrap,
    IrBinOpDiv,
    IrBinOpMod,
    IrBinOpArrayCat,
    IrBinOpArrayMult,
};

struct IrInstructionBinOp {
    IrInstruction base;

    IrInstruction *op1;
    IrBinOp op_id;
    IrInstruction *op2;
};

struct IrInstructionDeclVar {
    IrInstruction base;

    VariableTableEntry *var;
    IrInstruction *var_type;
    IrInstruction *init_value;
};

struct IrInstructionLoadPtr {
    IrInstruction base;

    IrInstruction *ptr;
};

struct IrInstructionStorePtr {
    IrInstruction base;

    IrInstruction *ptr;
    IrInstruction *value;
};

struct IrInstructionFieldPtr {
    IrInstruction base;

    IrInstruction *container_ptr;
    Buf *field_name;
    bool is_const;
};

struct IrInstructionStructFieldPtr {
    IrInstruction base;

    IrInstruction *struct_ptr;
    TypeStructField *field;
    bool is_const;
};

struct IrInstructionElemPtr {
    IrInstruction base;

    IrInstruction *array_ptr;
    IrInstruction *elem_index;
    bool is_const;
    bool safety_check_on;
};

struct IrInstructionVarPtr {
    IrInstruction base;

    VariableTableEntry *var;
    bool is_const;
};

struct IrInstructionCall {
    IrInstruction base;

    IrInstruction *fn;
    size_t arg_count;
    IrInstruction **args;
};

struct IrInstructionConst {
    IrInstruction base;
};

// When an IrExecutable is not in a function, a return instruction means that
// the expression returns with that value, even though a return statement from
// an AST perspective is invalid.
struct IrInstructionReturn {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionCast {
    IrInstruction base;

    IrInstruction *value;
    IrInstruction *dest_type;
    CastOp cast_op;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionContainerInitList {
    IrInstruction base;

    IrInstruction *container_type;
    size_t item_count;
    IrInstruction **items;
};

struct IrInstructionContainerInitFields {
    IrInstruction base;

    IrInstruction *container_type;
    size_t field_count;
    Buf **field_names;
    IrInstruction **field_values;
};

struct IrInstructionUnreachable {
    IrInstruction base;
};

struct IrInstructionTypeOf {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionToPtrType {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionPtrTypeChild {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionSetFnTest {
    IrInstruction base;

    IrInstruction *fn_value;
    IrInstruction *is_test;
};

struct IrInstructionSetFnVisible {
    IrInstruction base;

    IrInstruction *fn_value;
    IrInstruction *is_visible;
};

struct IrInstructionSetDebugSafety {
    IrInstruction base;

    IrInstruction *scope_value;
    IrInstruction *debug_safety_on;
};

struct IrInstructionArrayType {
    IrInstruction base;

    IrInstruction *size;
    IrInstruction *child_type;
};

struct IrInstructionSliceType {
    IrInstruction base;

    bool is_const;
    IrInstruction *child_type;
};

struct IrInstructionAsm {
    IrInstruction base;

    // Most information on inline assembly comes from the source node.
    IrInstruction **input_list;
    IrInstruction **output_types;
    size_t return_count;
    bool has_side_effects;
};

struct IrInstructionCompileVar {
    IrInstruction base;

    IrInstruction *name;
};

struct IrInstructionSizeOf {
    IrInstruction base;

    IrInstruction *type_value;
};

// returns true if nonnull, returns false if null
// this is so that `zeroes` sets maybe values to null
struct IrInstructionTestNull {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionUnwrapMaybe {
    IrInstruction base;

    IrInstruction *value;
    bool safety_check_on;
};

struct IrInstructionCtz {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionClz {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionEnumTag {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionStaticEval {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionImport {
    IrInstruction base;

    IrInstruction *name;
};

struct IrInstructionArrayLen {
    IrInstruction base;

    IrInstruction *array_value;
};

enum LValPurpose {
    LValPurposeNone,
    LValPurposeAssign,
    LValPurposeAddressOf,
};

static const size_t slice_ptr_index = 0;
static const size_t slice_len_index = 1;

static const size_t maybe_child_index = 0;
static const size_t maybe_null_index = 1;

#endif
