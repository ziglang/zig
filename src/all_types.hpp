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
#include "zig_llvm.h"
#include "hash_map.hpp"
#include "errmsg.hpp"
#include "bigint.hpp"
#include "bigfloat.hpp"
#include "target.hpp"
#include "tokenizer.hpp"

struct AstNode;
struct ImportTableEntry;
struct FnTableEntry;
struct Scope;
struct ScopeBlock;
struct ScopeFnDef;
struct TypeTableEntry;
struct VariableTableEntry;
struct ErrorTableEntry;
struct BuiltinFnEntry;
struct TypeStructField;
struct CodeGen;
struct ConstExprValue;
struct IrInstruction;
struct IrInstructionCast;
struct IrBasicBlock;
struct ScopeDecls;
struct ZigWindowsSDK;
struct Tld;
struct TldExport;
struct IrAnalyze;

struct IrExecutable {
    ZigList<IrBasicBlock *> basic_block_list;
    Buf *name;
    size_t mem_slot_count;
    size_t next_debug_id;
    size_t *backward_branch_count;
    size_t backward_branch_quota;
    bool invalid;
    bool is_inline;
    bool is_generic_instantiation;
    FnTableEntry *fn_entry;
    Buf *c_import_buf;
    AstNode *source_node;
    IrExecutable *parent_exec;
    IrExecutable *source_exec;
    IrAnalyze *analysis;
    Scope *begin_scope;
    ZigList<Tld *> tld_list;

    IrInstruction *coro_handle;
    IrInstruction *coro_awaiter_field_ptr; // this one is shared and in the promise
    IrInstruction *coro_result_ptr_field_ptr;
    IrInstruction *coro_result_field_ptr;
    IrInstruction *await_handle_var_ptr; // this one is where we put the one we extracted from the promise
    IrBasicBlock *coro_early_final;
    IrBasicBlock *coro_normal_final;
    IrBasicBlock *coro_suspend_block;
    IrBasicBlock *coro_final_cleanup_block;
    VariableTableEntry *coro_allocator_var;
};

enum OutType {
    OutTypeUnknown,
    OutTypeExe,
    OutTypeLib,
    OutTypeObj,
};

enum ConstParentId {
    ConstParentIdNone,
    ConstParentIdStruct,
    ConstParentIdArray,
    ConstParentIdUnion,
    ConstParentIdScalar,
};

struct ConstParent {
    ConstParentId id;

    union {
        struct {
            ConstExprValue *array_val;
            size_t elem_index;
        } p_array;
        struct {
            ConstExprValue *struct_val;
            size_t field_index;
        } p_struct;
        struct {
            ConstExprValue *union_val;
        } p_union;
        struct {
            ConstExprValue *scalar_val;
        } p_scalar;
    } data;
};

struct ConstStructValue {
    ConstExprValue *fields;
    ConstParent parent;
};

struct ConstUnionValue {
    BigInt tag;
    ConstExprValue *payload;
    ConstParent parent;
};

enum ConstArraySpecial {
    ConstArraySpecialNone,
    ConstArraySpecialUndef,
};

struct ConstArrayValue {
    ConstArraySpecial special;
    struct {
        ConstExprValue *elements;
        ConstParent parent;
    } s_none;
};

enum ConstPtrSpecial {
    // Enforce explicitly setting this ID by making the zero value invalid.
    ConstPtrSpecialInvalid,
    // The pointer is a reference to a single object.
    ConstPtrSpecialRef,
    // The pointer points to an element in an underlying array.
    ConstPtrSpecialBaseArray,
    // The pointer points to a field in an underlying struct.
    ConstPtrSpecialBaseStruct,
    // This means that we did a compile-time pointer reinterpret and we cannot
    // understand the value of pointee at compile time. However, we will still
    // emit a binary with a compile time known address.
    // In this case index is the numeric address value.
    // We also use this for null pointer. We need the data layout for ConstCastOnly == true
    // types to be the same, so all optionals of pointer types use x_ptr
    // instead of x_optional
    ConstPtrSpecialHardCodedAddr,
    // This means that the pointer represents memory of assigning to _.
    // That is, storing discards the data, and loading is invalid.
    ConstPtrSpecialDiscard,
    // This is actually a function.
    ConstPtrSpecialFunction,
};

enum ConstPtrMut {
    // The pointer points to memory that is known at compile time and immutable.
    ConstPtrMutComptimeConst,
    // This means that the pointer points to memory used by a comptime variable,
    // so attempting to write a non-compile-time known value is an error
    // But the underlying value is allowed to change at compile time.
    ConstPtrMutComptimeVar,
    // The pointer points to memory that is known only at runtime.
    // For example it may point to the initializer value of a variable.
    ConstPtrMutRuntimeVar,
};

struct ConstPtrValue {
    ConstPtrSpecial special;
    ConstPtrMut mut;

    union {
        struct {
            ConstExprValue *pointee;
        } ref;
        struct {
            ConstExprValue *array_val;
            size_t elem_index;
            // This helps us preserve the null byte when performing compile-time
            // concatenation on C strings.
            bool is_cstr;
        } base_array;
        struct {
            ConstExprValue *struct_val;
            size_t field_index;
        } base_struct;
        struct {
            uint64_t addr;
        } hard_coded_addr;
        struct {
            FnTableEntry *fn_entry;
        } fn;
    } data;
};

struct ConstErrValue {
    ErrorTableEntry *err;
    ConstExprValue *payload;
};

struct ConstBoundFnValue {
    FnTableEntry *fn;
    IrInstruction *first_arg;
};

struct ConstArgTuple {
    size_t start_index;
    size_t end_index;
};

enum ConstValSpecial {
    ConstValSpecialRuntime,
    ConstValSpecialStatic,
    ConstValSpecialUndef,
};

enum RuntimeHintErrorUnion {
    RuntimeHintErrorUnionUnknown,
    RuntimeHintErrorUnionError,
    RuntimeHintErrorUnionNonError,
};

enum RuntimeHintOptional {
    RuntimeHintOptionalUnknown,
    RuntimeHintOptionalNull, // TODO is this value even possible? if this is the case it might mean the const value is compile time known.
    RuntimeHintOptionalNonNull,
};

enum RuntimeHintPtr {
    RuntimeHintPtrUnknown,
    RuntimeHintPtrStack,
    RuntimeHintPtrNonStack,
};

enum RuntimeHintSliceId {
    RuntimeHintSliceIdUnknown,
    RuntimeHintSliceIdLen,
};

struct RuntimeHintSlice {
    enum RuntimeHintSliceId id;
    uint64_t len;
};

struct ConstGlobalRefs {
    LLVMValueRef llvm_value;
    LLVMValueRef llvm_global;
};

struct ConstExprValue {
    TypeTableEntry *type;
    ConstValSpecial special;
    ConstGlobalRefs *global_refs;

    union {
        // populated if special == ConstValSpecialStatic
        BigInt x_bigint;
        BigFloat x_bigfloat;
        float16_t x_f16;
        float x_f32;
        double x_f64;
        float128_t x_f128;
        bool x_bool;
        ConstBoundFnValue x_bound_fn;
        TypeTableEntry *x_type;
        ConstExprValue *x_optional;
        ConstErrValue x_err_union;
        ErrorTableEntry *x_err_set;
        BigInt x_enum_tag;
        ConstStructValue x_struct;
        ConstUnionValue x_union;
        ConstArrayValue x_array;
        ConstPtrValue x_ptr;
        ImportTableEntry *x_import;
        Scope *x_block;
        ConstArgTuple x_arg_tuple;

        // populated if special == ConstValSpecialRuntime
        RuntimeHintErrorUnion rh_error_union;
        RuntimeHintOptional rh_maybe;
        RuntimeHintPtr rh_ptr;
        RuntimeHintSlice rh_slice;
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

enum VisibMod {
    VisibModPrivate,
    VisibModPub,
};

enum GlobalLinkageId {
    GlobalLinkageIdInternal,
    GlobalLinkageIdStrong,
    GlobalLinkageIdWeak,
    GlobalLinkageIdLinkOnce,
};

enum TldId {
    TldIdVar,
    TldIdFn,
    TldIdContainer,
    TldIdCompTime,
};

enum TldResolution {
    TldResolutionUnresolved,
    TldResolutionResolving,
    TldResolutionInvalid,
    TldResolutionOk,
};

struct Tld {
    TldId id;
    Buf *name;
    VisibMod visib_mod;
    AstNode *source_node;

    ImportTableEntry *import;
    Scope *parent_scope;
    // set this flag temporarily to detect infinite loops
    bool dep_loop_flag;
    TldResolution resolution;
};

struct TldVar {
    Tld base;

    VariableTableEntry *var;
    Buf *extern_lib_name;
    Buf *section_name;
};

struct TldFn {
    Tld base;

    FnTableEntry *fn_entry;
    Buf *extern_lib_name;
};

struct TldContainer {
    Tld base;

    ScopeDecls *decls_scope;
    TypeTableEntry *type_entry;
};

struct TldCompTime {
    Tld base;
};

struct TypeEnumField {
    Buf *name;
    BigInt value;
    uint32_t decl_index;
    AstNode *decl_node;
};

struct TypeUnionField {
    Buf *name;
    TypeEnumField *enum_field;
    TypeTableEntry *type_entry;
    AstNode *decl_node;
    uint32_t gen_index;
};

enum NodeType {
    NodeTypeRoot,
    NodeTypeFnProto,
    NodeTypeFnDef,
    NodeTypeParamDecl,
    NodeTypeBlock,
    NodeTypeGroupedExpr,
    NodeTypeReturnExpr,
    NodeTypeDefer,
    NodeTypeVariableDeclaration,
    NodeTypeTestDecl,
    NodeTypeBinOpExpr,
    NodeTypeUnwrapErrorExpr,
    NodeTypeFloatLiteral,
    NodeTypeIntLiteral,
    NodeTypeStringLiteral,
    NodeTypeCharLiteral,
    NodeTypeSymbol,
    NodeTypePrefixOpExpr,
    NodeTypePointerType,
    NodeTypeFnCallExpr,
    NodeTypeArrayAccessExpr,
    NodeTypeSliceExpr,
    NodeTypeFieldAccessExpr,
    NodeTypePtrDeref,
    NodeTypeUnwrapOptional,
    NodeTypeUse,
    NodeTypeBoolLiteral,
    NodeTypeNullLiteral,
    NodeTypeUndefinedLiteral,
    NodeTypeThisLiteral,
    NodeTypeUnreachable,
    NodeTypeIfBoolExpr,
    NodeTypeWhileExpr,
    NodeTypeForExpr,
    NodeTypeSwitchExpr,
    NodeTypeSwitchProng,
    NodeTypeSwitchRange,
    NodeTypeCompTime,
    NodeTypeBreak,
    NodeTypeContinue,
    NodeTypeAsmExpr,
    NodeTypeContainerDecl,
    NodeTypeStructField,
    NodeTypeContainerInitExpr,
    NodeTypeStructValueField,
    NodeTypeArrayType,
    NodeTypeErrorType,
    NodeTypeIfErrorExpr,
    NodeTypeTestExpr,
    NodeTypeErrorSetDecl,
    NodeTypeCancel,
    NodeTypeResume,
    NodeTypeAwaitExpr,
    NodeTypeSuspend,
    NodeTypePromiseType,
};

struct AstNodeRoot {
    ZigList<AstNode *> top_level_decls;
};

enum CallingConvention {
    CallingConventionUnspecified,
    CallingConventionC,
    CallingConventionCold,
    CallingConventionNaked,
    CallingConventionStdcall,
    CallingConventionAsync,
};

struct AstNodeFnProto {
    VisibMod visib_mod;
    Buf *name;
    ZigList<AstNode *> params;
    AstNode *return_type;
    Token *return_var_token;
    bool is_var_args;
    bool is_extern;
    bool is_export;
    bool is_inline;
    CallingConvention cc;
    AstNode *fn_def_node;
    // populated if this is an extern declaration
    Buf *lib_name;
    // populated if the "align A" is present
    AstNode *align_expr;
    // populated if the "section(S)" is present
    AstNode *section_expr;

    bool auto_err_set;
    AstNode *async_allocator_type;
};

struct AstNodeFnDef {
    AstNode *fn_proto;
    AstNode *body;
};

struct AstNodeParamDecl {
    Buf *name;
    AstNode *type;
    Token *var_token;
    bool is_noalias;
    bool is_inline;
    bool is_var_args;
};

struct AstNodeBlock {
    Buf *name;
    ZigList<AstNode *> statements;
};

enum ReturnKind {
    ReturnKindUnconditional,
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

    // temporary data used in IR generation
    Scope *child_scope;
    Scope *expr_scope;
};

struct AstNodeVariableDeclaration {
    VisibMod visib_mod;
    Buf *symbol;
    bool is_const;
    bool is_comptime;
    bool is_export;
    bool is_extern;
    // one or both of type and expr will be non null
    AstNode *type;
    AstNode *expr;
    // populated if this is an extern declaration
    Buf *lib_name;
    // populated if the "align(A)" is present
    AstNode *align_expr;
    // populated if the "section(S)" is present
    AstNode *section_expr;
};

struct AstNodeTestDecl {
    Buf *name;

    AstNode *body;
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
    BinOpTypeAssignBitShiftRight,
    BinOpTypeAssignBitAnd,
    BinOpTypeAssignBitXor,
    BinOpTypeAssignBitOr,
    BinOpTypeAssignMergeErrorSets,
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
    BinOpTypeAddWrap,
    BinOpTypeSub,
    BinOpTypeSubWrap,
    BinOpTypeMult,
    BinOpTypeMultWrap,
    BinOpTypeDiv,
    BinOpTypeMod,
    BinOpTypeUnwrapOptional,
    BinOpTypeArrayCat,
    BinOpTypeArrayMult,
    BinOpTypeErrorUnion,
    BinOpTypeMergeErrorSets,
};

struct AstNodeBinOpExpr {
    AstNode *op1;
    BinOpType bin_op;
    AstNode *op2;
};

struct AstNodeCatchExpr {
    AstNode *op1;
    AstNode *symbol; // can be null
    AstNode *op2;
};

struct AstNodeUnwrapOptional {
    AstNode *expr;
};

enum CastOp {
    CastOpNoCast, // signifies the function call expression is not a cast
    CastOpNoop, // fn call expr is a cast, but does nothing
    CastOpIntToFloat,
    CastOpFloatToInt,
    CastOpBoolToInt,
    CastOpResizeSlice,
    CastOpBytesToSlice,
    CastOpNumLitToConcrete,
    CastOpErrSet,
    CastOpBitCast,
    CastOpPtrOfArrayToSlice,
};

struct AstNodeFnCallExpr {
    AstNode *fn_ref_expr;
    ZigList<AstNode *> params;
    bool is_builtin;
    bool is_async;
    AstNode *async_allocator;
};

struct AstNodeArrayAccessExpr {
    AstNode *array_ref_expr;
    AstNode *subscript;
};

struct AstNodeSliceExpr {
    AstNode *array_ref_expr;
    AstNode *start;
    AstNode *end;
};

struct AstNodeFieldAccessExpr {
    AstNode *struct_expr;
    Buf *field_name;
};

struct AstNodePtrDerefExpr {
    AstNode *target;
};

enum PrefixOp {
    PrefixOpInvalid,
    PrefixOpBoolNot,
    PrefixOpBinNot,
    PrefixOpNegation,
    PrefixOpNegationWrap,
    PrefixOpOptional,
    PrefixOpAddrOf,
};

struct AstNodePrefixOpExpr {
    PrefixOp prefix_op;
    AstNode *primary_expr;
};

struct AstNodePointerType {
    Token *star_token;
    AstNode *align_expr;
    BigInt *bit_offset_start;
    BigInt *bit_offset_end;
    bool is_const;
    bool is_volatile;
    AstNode *op_expr;
};

struct AstNodeArrayType {
    AstNode *size;
    AstNode *child_type;
    AstNode *align_expr;
    bool is_const;
    bool is_volatile;
};

struct AstNodeUse {
    VisibMod visib_mod;
    AstNode *expr;

    TldResolution resolution;
    IrInstruction *value;
};

struct AstNodeIfBoolExpr {
    AstNode *condition;
    AstNode *then_block;
    AstNode *else_node; // null, block node, or other if expr node
};

struct AstNodeTryExpr {
    Buf *var_symbol;
    bool var_is_ptr;
    AstNode *target_node;
    AstNode *then_node;
    AstNode *else_node;
    Buf *err_symbol;
};

struct AstNodeTestExpr {
    Buf *var_symbol;
    bool var_is_ptr;
    AstNode *target_node;
    AstNode *then_node;
    AstNode *else_node; // null, block node, or other if expr node
};

struct AstNodeWhileExpr {
    Buf *name;
    AstNode *condition;
    Buf *var_symbol;
    bool var_is_ptr;
    AstNode *continue_expr;
    AstNode *body;
    AstNode *else_node;
    Buf *err_symbol;
    bool is_inline;
};

struct AstNodeForExpr {
    Buf *name;
    AstNode *array_expr;
    AstNode *elem_node; // always a symbol
    AstNode *index_node; // always a symbol, might be null
    AstNode *body;
    AstNode *else_node; // can be null
    bool elem_is_ptr;
    bool is_inline;
};

struct AstNodeSwitchExpr {
    AstNode *expr;
    ZigList<AstNode *> prongs;
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

struct AstNodeCompTime {
    AstNode *expr;
};

struct AsmOutput {
    Buf *asm_symbolic_name;
    Buf *constraint;
    Buf *variable_name;
    AstNode *return_type; // null unless "=r" and return
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
    AsmTokenIdUniqueId,
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
};

enum ContainerKind {
    ContainerKindStruct,
    ContainerKindEnum,
    ContainerKindUnion,
};

enum ContainerLayout {
    ContainerLayoutAuto,
    ContainerLayoutExtern,
    ContainerLayoutPacked,
};

struct AstNodeContainerDecl {
    ContainerKind kind;
    ZigList<AstNode *> fields;
    ZigList<AstNode *> decls;
    ContainerLayout layout;
    AstNode *init_arg_expr; // enum(T), struct(endianness), or union(T), or union(enum(T))
    bool auto_enum; // union(enum)
};

struct AstNodeErrorSetDecl {
    ZigList<AstNode *> decls;
};

struct AstNodeStructField {
    VisibMod visib_mod;
    Buf *name;
    AstNode *type;
    AstNode *value;
};

struct AstNodeStringLiteral {
    Buf *buf;
    bool c;
};

struct AstNodeCharLiteral {
    uint8_t value;
};

struct AstNodeFloatLiteral {
    BigFloat *bigfloat;

    // overflow is true if when parsing the number, we discovered it would not
    // fit without losing data in a double
    bool overflow;
};

struct AstNodeIntLiteral {
    BigInt *bigint;
};

struct AstNodeStructValueField {
    Buf *name;
    AstNode *expr;
};

enum ContainerInitKind {
    ContainerInitKindStruct,
    ContainerInitKindArray,
};

struct AstNodeContainerInitExpr {
    AstNode *type;
    ZigList<AstNode *> entries;
    ContainerInitKind kind;
};

struct AstNodeNullLiteral {
};

struct AstNodeUndefinedLiteral {
};

struct AstNodeThisLiteral {
};

struct AstNodeSymbolExpr {
    Buf *symbol;
};

struct AstNodeBoolLiteral {
    bool value;
};

struct AstNodeBreakExpr {
    Buf *name;
    AstNode *expr; // may be null
};

struct AstNodeCancelExpr {
    AstNode *expr;
};

struct AstNodeResumeExpr {
    AstNode *expr;
};

struct AstNodeContinueExpr {
    Buf *name;
};

struct AstNodeUnreachableExpr {
};


struct AstNodeErrorType {
};

struct AstNodeAwaitExpr {
    AstNode *expr;
};

struct AstNodeSuspend {
    Buf *name;
    AstNode *block;
    AstNode *promise_symbol;
};

struct AstNodePromiseType {
    AstNode *payload_type; // can be NULL
};

struct AstNode {
    enum NodeType type;
    size_t line;
    size_t column;
    ImportTableEntry *owner;
    union {
        AstNodeRoot root;
        AstNodeFnDef fn_def;
        AstNodeFnProto fn_proto;
        AstNodeParamDecl param_decl;
        AstNodeBlock block;
        AstNode * grouped_expr;
        AstNodeReturnExpr return_expr;
        AstNodeDefer defer;
        AstNodeVariableDeclaration variable_declaration;
        AstNodeTestDecl test_decl;
        AstNodeBinOpExpr bin_op_expr;
        AstNodeCatchExpr unwrap_err_expr;
        AstNodeUnwrapOptional unwrap_optional;
        AstNodePrefixOpExpr prefix_op_expr;
        AstNodePointerType pointer_type;
        AstNodeFnCallExpr fn_call_expr;
        AstNodeArrayAccessExpr array_access_expr;
        AstNodeSliceExpr slice_expr;
        AstNodeUse use;
        AstNodeIfBoolExpr if_bool_expr;
        AstNodeTryExpr if_err_expr;
        AstNodeTestExpr test_expr;
        AstNodeWhileExpr while_expr;
        AstNodeForExpr for_expr;
        AstNodeSwitchExpr switch_expr;
        AstNodeSwitchProng switch_prong;
        AstNodeSwitchRange switch_range;
        AstNodeCompTime comptime_expr;
        AstNodeAsmExpr asm_expr;
        AstNodeFieldAccessExpr field_access_expr;
        AstNodePtrDerefExpr ptr_deref_expr;
        AstNodeContainerDecl container_decl;
        AstNodeStructField struct_field;
        AstNodeStringLiteral string_literal;
        AstNodeCharLiteral char_literal;
        AstNodeFloatLiteral float_literal;
        AstNodeIntLiteral int_literal;
        AstNodeContainerInitExpr container_init_expr;
        AstNodeStructValueField struct_val_field;
        AstNodeNullLiteral null_literal;
        AstNodeUndefinedLiteral undefined_literal;
        AstNodeThisLiteral this_literal;
        AstNodeSymbolExpr symbol_expr;
        AstNodeBoolLiteral bool_literal;
        AstNodeBreakExpr break_expr;
        AstNodeContinueExpr continue_expr;
        AstNodeUnreachableExpr unreachable_expr;
        AstNodeArrayType array_type;
        AstNodeErrorType error_type;
        AstNodeErrorSetDecl err_set_decl;
        AstNodeCancelExpr cancel_expr;
        AstNodeResumeExpr resume_expr;
        AstNodeAwaitExpr await_expr;
        AstNodeSuspend suspend;
        AstNodePromiseType promise_type;
    } data;
};

// this struct is allocated with allocate_nonzero
struct FnTypeParamInfo {
    bool is_noalias;
    TypeTableEntry *type;
};

struct GenericFnTypeId {
    FnTableEntry *fn_entry;
    ConstExprValue *params;
    size_t param_count;
};

uint32_t generic_fn_type_id_hash(GenericFnTypeId *id);
bool generic_fn_type_id_eql(GenericFnTypeId *a, GenericFnTypeId *b);

struct FnTypeId {
    TypeTableEntry *return_type;
    FnTypeParamInfo *param_info;
    size_t param_count;
    size_t next_param_index;
    bool is_var_args;
    CallingConvention cc;
    uint32_t alignment;
    TypeTableEntry *async_allocator_type;
};

uint32_t fn_type_id_hash(FnTypeId*);
bool fn_type_id_eql(FnTypeId *a, FnTypeId *b);

enum PtrLen {
    PtrLenUnknown,
    PtrLenSingle,
};

struct TypeTableEntryPointer {
    TypeTableEntry *child_type;
    PtrLen ptr_len;
    bool is_const;
    bool is_volatile;
    uint32_t alignment;
    uint32_t bit_offset;
    uint32_t unaligned_bit_count;
    TypeTableEntry *slice_parent;
};

struct TypeTableEntryInt {
    uint32_t bit_count;
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
    // offset from the memory at gen_index
    size_t packed_bits_offset;
    size_t packed_bits_size;
    size_t unaligned_bit_count;
    AstNode *decl_node;
};
struct TypeTableEntryStruct {
    AstNode *decl_node;
    ContainerLayout layout;
    uint32_t src_field_count;
    uint32_t gen_field_count;
    TypeStructField *fields;
    uint64_t size_bytes;
    bool is_invalid; // true if any fields are invalid
    bool is_slice;
    ScopeDecls *decls_scope;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
    // whether we've finished resolving it
    bool complete;

    // whether any of the fields require comptime
    // the value is not valid until zero_bits_known == true
    bool requires_comptime;

    bool zero_bits_loop_flag;
    bool zero_bits_known;
    uint32_t abi_alignment; // also figured out with zero_bits pass

    HashMap<Buf *, TypeStructField *, buf_hash, buf_eql_buf> fields_by_name;
};

struct TypeTableEntryOptional {
    TypeTableEntry *child_type;
};

struct TypeTableEntryErrorUnion {
    TypeTableEntry *err_set_type;
    TypeTableEntry *payload_type;
};

struct TypeTableEntryErrorSet {
    uint32_t err_count;
    ErrorTableEntry **errors;
    FnTableEntry *infer_fn;
};

struct TypeTableEntryEnum {
    AstNode *decl_node;
    ContainerLayout layout;
    uint32_t src_field_count;
    TypeEnumField *fields;
    bool is_invalid; // true if any fields are invalid
    TypeTableEntry *tag_int_type;

    ScopeDecls *decls_scope;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
    // whether we've finished resolving it
    bool complete;

    bool zero_bits_loop_flag;
    bool zero_bits_known;

    LLVMValueRef name_function;

    HashMap<Buf *, TypeEnumField *, buf_hash, buf_eql_buf> fields_by_name;
};

uint32_t type_ptr_hash(const TypeTableEntry *ptr);
bool type_ptr_eql(const TypeTableEntry *a, const TypeTableEntry *b);

struct TypeTableEntryUnion {
    AstNode *decl_node;
    ContainerLayout layout;
    uint32_t src_field_count;
    uint32_t gen_field_count;
    TypeUnionField *fields;
    bool is_invalid; // true if any fields are invalid
    TypeTableEntry *tag_type; // always an enum or null
    LLVMTypeRef union_type_ref;

    ScopeDecls *decls_scope;

    // set this flag temporarily to detect infinite loops
    bool embedded_in_current;
    bool reported_infinite_err;
    // whether we've finished resolving it
    bool complete;

    // whether any of the fields require comptime
    // the value is not valid until zero_bits_known == true
    bool requires_comptime;

    bool zero_bits_loop_flag;
    bool zero_bits_known;
    uint32_t abi_alignment; // also figured out with zero_bits pass

    size_t gen_union_index;
    size_t gen_tag_index;

    bool have_explicit_tag_type;

    uint32_t union_size_bytes;
    TypeTableEntry *most_aligned_union_member;

    HashMap<Buf *, TypeUnionField *, buf_hash, buf_eql_buf> fields_by_name;
};

struct FnGenParamInfo {
    size_t src_index;
    size_t gen_index;
    bool is_byval;
    TypeTableEntry *type;
};

struct TypeTableEntryFn {
    FnTypeId fn_type_id;
    bool is_generic;
    TypeTableEntry *gen_return_type;
    size_t gen_param_count;
    FnGenParamInfo *gen_param_info;

    LLVMTypeRef raw_type_ref;

    TypeTableEntry *bound_fn_parent;
};

struct TypeTableEntryBoundFn {
    TypeTableEntry *fn_type;
};

struct TypeTableEntryPromise {
    // null if `promise` instead of `promise->T`
    TypeTableEntry *result_type;
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

struct TypeTableEntry {
    TypeTableEntryId id;
    Buf name;

    LLVMTypeRef type_ref;
    ZigLLVMDIType *di_type;

    bool zero_bits; // this is denormalized data
    bool is_copyable;
    bool gen_h_loop_flag;

    union {
        TypeTableEntryPointer pointer;
        TypeTableEntryInt integral;
        TypeTableEntryFloat floating;
        TypeTableEntryArray array;
        TypeTableEntryStruct structure;
        TypeTableEntryOptional maybe;
        TypeTableEntryErrorUnion error_union;
        TypeTableEntryErrorSet error_set;
        TypeTableEntryEnum enumeration;
        TypeTableEntryUnion unionation;
        TypeTableEntryFn fn;
        TypeTableEntryBoundFn bound_fn;
        TypeTableEntryPromise promise;
    } data;

    // use these fields to make sure we don't duplicate type table entries for the same type
    TypeTableEntry *pointer_parent[2]; // [0 - mut, 1 - const]
    TypeTableEntry *optional_parent;
    TypeTableEntry *promise_parent;
    TypeTableEntry *promise_frame_parent;
    // If we generate a constant name value for this type, we memoize it here.
    // The type of this is array
    ConstExprValue *cached_const_name_val;
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
    ScopeDecls *decls_scope;
    AstNode *c_import_node;
    bool any_imports_failed;
    bool scanned;

    ZigList<AstNode *> use_decls;
};

enum FnAnalState {
    FnAnalStateReady,
    FnAnalStateProbing,
    FnAnalStateComplete,
    FnAnalStateInvalid,
};

enum FnInline {
    FnInlineAuto,
    FnInlineAlways,
    FnInlineNever,
};

struct FnExport {
    Buf name;
    GlobalLinkageId linkage;
};

struct FnTableEntry {
    LLVMValueRef llvm_value;
    const char *llvm_name;
    AstNode *proto_node;
    AstNode *body_node;
    ScopeFnDef *fndef_scope; // parent should be the top level decls or container decls
    Scope *child_scope; // parent is scope for last parameter
    ScopeBlock *def_scope; // parent is child_scope
    Buf symbol_name;
    TypeTableEntry *type_entry; // function type
    // in the case of normal functions this is the implicit return type
    // in the case of async functions this is the implicit return type according to the
    // zig source code, not according to zig ir
    TypeTableEntry *src_implicit_return_type;
    bool is_test;
    FnInline fn_inline;
    FnAnalState anal_state;
    IrExecutable ir_executable;
    IrExecutable analyzed_executable;
    size_t prealloc_bbc;
    AstNode **param_source_nodes;
    Buf **param_names;
    uint32_t align_bytes;

    AstNode *fn_no_inline_set_node;
    AstNode *fn_static_eval_set_node;

    ZigList<IrInstruction *> alloca_list;
    ZigList<VariableTableEntry *> variable_list;

    Buf *section_name;
    AstNode *set_alignstack_node;
    uint32_t alignstack_value;

    AstNode *set_cold_node;
    bool is_cold;

    ZigList<FnExport> export_list;
    bool calls_or_awaits_errorable_fn;
};

uint32_t fn_table_entry_hash(FnTableEntry*);
bool fn_table_entry_eql(FnTableEntry *a, FnTableEntry *b);

enum BuiltinFnId {
    BuiltinFnIdInvalid,
    BuiltinFnIdMemcpy,
    BuiltinFnIdMemset,
    BuiltinFnIdSizeof,
    BuiltinFnIdAlignOf,
    BuiltinFnIdMaxValue,
    BuiltinFnIdMinValue,
    BuiltinFnIdMemberCount,
    BuiltinFnIdMemberType,
    BuiltinFnIdMemberName,
    BuiltinFnIdField,
    BuiltinFnIdTypeInfo,
    BuiltinFnIdTypeof,
    BuiltinFnIdAddWithOverflow,
    BuiltinFnIdSubWithOverflow,
    BuiltinFnIdMulWithOverflow,
    BuiltinFnIdShlWithOverflow,
    BuiltinFnIdCInclude,
    BuiltinFnIdCDefine,
    BuiltinFnIdCUndef,
    BuiltinFnIdCompileErr,
    BuiltinFnIdCompileLog,
    BuiltinFnIdCtz,
    BuiltinFnIdClz,
    BuiltinFnIdPopCount,
    BuiltinFnIdImport,
    BuiltinFnIdCImport,
    BuiltinFnIdErrName,
    BuiltinFnIdBreakpoint,
    BuiltinFnIdReturnAddress,
    BuiltinFnIdFrameAddress,
    BuiltinFnIdEmbedFile,
    BuiltinFnIdCmpxchgWeak,
    BuiltinFnIdCmpxchgStrong,
    BuiltinFnIdFence,
    BuiltinFnIdDivExact,
    BuiltinFnIdDivTrunc,
    BuiltinFnIdDivFloor,
    BuiltinFnIdRem,
    BuiltinFnIdMod,
    BuiltinFnIdSqrt,
    BuiltinFnIdTruncate,
    BuiltinFnIdIntCast,
    BuiltinFnIdFloatCast,
    BuiltinFnIdErrSetCast,
    BuiltinFnIdToBytes,
    BuiltinFnIdFromBytes,
    BuiltinFnIdIntToFloat,
    BuiltinFnIdFloatToInt,
    BuiltinFnIdBoolToInt,
    BuiltinFnIdErrToInt,
    BuiltinFnIdIntToErr,
    BuiltinFnIdEnumToInt,
    BuiltinFnIdIntToEnum,
    BuiltinFnIdIntType,
    BuiltinFnIdSetCold,
    BuiltinFnIdSetRuntimeSafety,
    BuiltinFnIdSetFloatMode,
    BuiltinFnIdTypeName,
    BuiltinFnIdPanic,
    BuiltinFnIdPtrCast,
    BuiltinFnIdBitCast,
    BuiltinFnIdIntToPtr,
    BuiltinFnIdPtrToInt,
    BuiltinFnIdTagName,
    BuiltinFnIdTagType,
    BuiltinFnIdFieldParentPtr,
    BuiltinFnIdOffsetOf,
    BuiltinFnIdInlineCall,
    BuiltinFnIdNoInlineCall,
    BuiltinFnIdNewStackCall,
    BuiltinFnIdTypeId,
    BuiltinFnIdShlExact,
    BuiltinFnIdShrExact,
    BuiltinFnIdSetEvalBranchQuota,
    BuiltinFnIdAlignCast,
    BuiltinFnIdOpaqueType,
    BuiltinFnIdSetAlignStack,
    BuiltinFnIdArgType,
    BuiltinFnIdExport,
    BuiltinFnIdErrorReturnTrace,
    BuiltinFnIdAtomicRmw,
    BuiltinFnIdAtomicLoad,
};

struct BuiltinFnEntry {
    BuiltinFnId id;
    Buf name;
    size_t param_count;
};

enum PanicMsgId {
    PanicMsgIdUnreachable,
    PanicMsgIdBoundsCheckFailure,
    PanicMsgIdCastNegativeToUnsigned,
    PanicMsgIdCastTruncatedData,
    PanicMsgIdIntegerOverflow,
    PanicMsgIdShlOverflowedBits,
    PanicMsgIdShrOverflowedBits,
    PanicMsgIdDivisionByZero,
    PanicMsgIdRemainderDivisionByZero,
    PanicMsgIdExactDivisionRemainder,
    PanicMsgIdSliceWidenRemainder,
    PanicMsgIdUnwrapOptionalFail,
    PanicMsgIdInvalidErrorCode,
    PanicMsgIdIncorrectAlignment,
    PanicMsgIdBadUnionField,
    PanicMsgIdBadEnumValue,
    PanicMsgIdFloatToInt,

    PanicMsgIdCount,
};

uint32_t fn_eval_hash(Scope*);
bool fn_eval_eql(Scope *a, Scope *b);

struct TypeId {
    TypeTableEntryId id;

    union {
        struct {
            TypeTableEntry *child_type;
            PtrLen ptr_len;
            bool is_const;
            bool is_volatile;
            uint32_t alignment;
            uint32_t bit_offset;
            uint32_t unaligned_bit_count;
        } pointer;
        struct {
            TypeTableEntry *child_type;
            uint64_t size;
        } array;
        struct {
            bool is_signed;
            uint32_t bit_count;
        } integer;
        struct {
            TypeTableEntry *err_set_type;
            TypeTableEntry *payload_type;
        } error_union;
    } data;
};

uint32_t type_id_hash(TypeId);
bool type_id_eql(TypeId a, TypeId b);

enum ZigLLVMFnId {
    ZigLLVMFnIdCtz,
    ZigLLVMFnIdClz,
    ZigLLVMFnIdPopCount,
    ZigLLVMFnIdOverflowArithmetic,
    ZigLLVMFnIdFloor,
    ZigLLVMFnIdCeil,
    ZigLLVMFnIdSqrt,
};

enum AddSubMul {
    AddSubMulAdd = 0,
    AddSubMulSub = 1,
    AddSubMulMul = 2,
};

struct ZigLLVMFnKey {
    ZigLLVMFnId id;

    union {
        struct {
            uint32_t bit_count;
        } ctz;
        struct {
            uint32_t bit_count;
        } clz;
        struct {
            uint32_t bit_count;
        } pop_count;
        struct {
            uint32_t bit_count;
        } floating;
        struct {
            AddSubMul add_sub_mul;
            uint32_t bit_count;
            bool is_signed;
        } overflow_arithmetic;
    } data;
};

uint32_t zig_llvm_fn_key_hash(ZigLLVMFnKey);
bool zig_llvm_fn_key_eql(ZigLLVMFnKey a, ZigLLVMFnKey b);

struct TimeEvent {
    double time;
    const char *name;
};

enum BuildMode {
    BuildModeDebug,
    BuildModeFastRelease,
    BuildModeSafeRelease,
    BuildModeSmallRelease,
};

enum EmitFileType {
    EmitFileTypeBinary,
    EmitFileTypeAssembly,
    EmitFileTypeLLVMIr,
};

struct LinkLib {
    Buf *name;
    Buf *path;
    ZigList<Buf *> symbols; // the list of symbols that we depend on from this lib
    bool provided_explicitly;
};

struct CodeGen {
    LLVMModuleRef module;
    ZigList<ErrorMsg*> errors;
    LLVMBuilderRef builder;
    ZigLLVMDIBuilder *dbuilder;
    ZigLLVMDICompileUnit *compile_unit;
    ZigLLVMDIFile *compile_unit_file;

    ZigList<LinkLib *> link_libs_list;
    LinkLib *libc_link_lib;

    // add -framework [name] args to linker
    ZigList<Buf *> darwin_frameworks;
    // add -rpath [name] args to linker
    ZigList<Buf *> rpath_list;


    // reminder: hash tables must be initialized before use
    HashMap<Buf *, ImportTableEntry *, buf_hash, buf_eql_buf> import_table;
    HashMap<Buf *, BuiltinFnEntry *, buf_hash, buf_eql_buf> builtin_fn_table;
    HashMap<Buf *, TypeTableEntry *, buf_hash, buf_eql_buf> primitive_type_table;
    HashMap<TypeId, TypeTableEntry *, type_id_hash, type_id_eql> type_table;
    HashMap<FnTypeId *, TypeTableEntry *, fn_type_id_hash, fn_type_id_eql> fn_type_table;
    HashMap<Buf *, ErrorTableEntry *, buf_hash, buf_eql_buf> error_table;
    HashMap<GenericFnTypeId *, FnTableEntry *, generic_fn_type_id_hash, generic_fn_type_id_eql> generic_table;
    HashMap<Scope *, IrInstruction *, fn_eval_hash, fn_eval_eql> memoized_fn_eval_table;
    HashMap<ZigLLVMFnKey, LLVMValueRef, zig_llvm_fn_key_hash, zig_llvm_fn_key_eql> llvm_fn_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> exported_symbol_names;
    HashMap<Buf *, Tld *, buf_hash, buf_eql_buf> external_prototypes;
    HashMap<Buf *, ConstExprValue *, buf_hash, buf_eql_buf> string_literals_table;
    HashMap<const TypeTableEntry *, ConstExprValue *, type_ptr_hash, type_ptr_eql> type_info_cache;


    ZigList<ImportTableEntry *> import_queue;
    size_t import_queue_index;
    ZigList<Tld *> resolve_queue;
    size_t resolve_queue_index;
    ZigList<AstNode *> use_queue;
    size_t use_queue_index;

    uint32_t next_unresolved_index;

    struct {
        TypeTableEntry *entry_bool;
        TypeTableEntry *entry_int[2][12]; // [signed,unsigned][2,3,4,5,6,7,8,16,29,32,64,128]
        TypeTableEntry *entry_c_int[CIntTypeCount];
        TypeTableEntry *entry_c_longdouble;
        TypeTableEntry *entry_c_void;
        TypeTableEntry *entry_u8;
        TypeTableEntry *entry_u16;
        TypeTableEntry *entry_u32;
        TypeTableEntry *entry_u29;
        TypeTableEntry *entry_u64;
        TypeTableEntry *entry_u128;
        TypeTableEntry *entry_i8;
        TypeTableEntry *entry_i16;
        TypeTableEntry *entry_i32;
        TypeTableEntry *entry_i64;
        TypeTableEntry *entry_i128;
        TypeTableEntry *entry_isize;
        TypeTableEntry *entry_usize;
        TypeTableEntry *entry_f16;
        TypeTableEntry *entry_f32;
        TypeTableEntry *entry_f64;
        TypeTableEntry *entry_f128;
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
        TypeTableEntry *entry_global_error_set;
        TypeTableEntry *entry_arg_tuple;
        TypeTableEntry *entry_promise;
    } builtin_types;

    EmitFileType emit_file_type;
    ZigTarget zig_target;
    LLVMTargetDataRef target_data_ref;
    unsigned pointer_size_bytes;
    bool is_big_endian;
    bool is_static;
    bool strip_debug_symbols;
    bool want_h_file;
    bool have_pub_main;
    bool have_c_main;
    bool have_winmain;
    bool have_winmain_crt_startup;
    bool have_dllmain_crt_startup;
    bool have_pub_panic;
    Buf *libc_lib_dir;
    Buf *libc_static_lib_dir;
    Buf *libc_include_dir;
    Buf *msvc_lib_dir;
    Buf *kernel32_lib_dir;
    Buf *zig_lib_dir;
    Buf *zig_std_dir;
    Buf *zig_c_headers_dir;
    Buf *zig_std_special_dir;
    Buf *dynamic_linker;
    Buf *ar_path;
    ZigWindowsSDK *win_sdk;
    Buf triple_str;
    BuildMode build_mode;
    bool is_test_build;
    bool have_err_ret_tracing;
    uint32_t target_os_index;
    uint32_t target_arch_index;
    uint32_t target_environ_index;
    uint32_t target_oformat_index;
    LLVMTargetMachineRef target_machine;
    ZigLLVMDIFile *dummy_di_file;
    bool is_native_target;
    PackageTableEntry *root_package;
    PackageTableEntry *std_package;
    PackageTableEntry *panic_package;
    PackageTableEntry *test_runner_package;
    PackageTableEntry *compile_var_package;
    ImportTableEntry *compile_var_import;
    Buf *root_out_name;
    bool windows_subsystem_windows;
    bool windows_subsystem_console;
    Buf *mmacosx_version_min;
    Buf *mios_version_min;
    bool linker_rdynamic;
    const char *linker_script;

    // The function definitions this module includes.
    ZigList<FnTableEntry *> fn_defs;
    size_t fn_defs_index;
    ZigList<TldVar *> global_vars;

    OutType out_type;
    FnTableEntry *cur_fn;
    FnTableEntry *main_fn;
    FnTableEntry *panic_fn;
    LLVMValueRef cur_ret_ptr;
    LLVMValueRef cur_fn_val;
    LLVMValueRef cur_err_ret_trace_val_arg;
    LLVMValueRef cur_err_ret_trace_val_stack;
    bool c_want_stdint;
    bool c_want_stdbool;
    AstNode *root_export_decl;
    size_t version_major;
    size_t version_minor;
    size_t version_patch;
    bool verbose_tokenize;
    bool verbose_ast;
    bool verbose_link;
    bool verbose_ir;
    bool verbose_llvm_ir;
    bool verbose_cimport;
    ErrColor err_color;
    ImportTableEntry *root_import;
    ImportTableEntry *bootstrap_import;
    ImportTableEntry *test_runner_import;
    LLVMValueRef memcpy_fn_val;
    LLVMValueRef memset_fn_val;
    LLVMValueRef trap_fn_val;
    LLVMValueRef return_address_fn_val;
    LLVMValueRef frame_address_fn_val;
    LLVMValueRef coro_destroy_fn_val;
    LLVMValueRef coro_id_fn_val;
    LLVMValueRef coro_alloc_fn_val;
    LLVMValueRef coro_size_fn_val;
    LLVMValueRef coro_begin_fn_val;
    LLVMValueRef coro_suspend_fn_val;
    LLVMValueRef coro_end_fn_val;
    LLVMValueRef coro_free_fn_val;
    LLVMValueRef coro_resume_fn_val;
    LLVMValueRef coro_save_fn_val;
    LLVMValueRef coro_promise_fn_val;
    LLVMValueRef coro_alloc_helper_fn_val;
    LLVMValueRef merge_err_ret_traces_fn_val;
    LLVMValueRef add_error_return_trace_addr_fn_val;
    LLVMValueRef stacksave_fn_val;
    LLVMValueRef stackrestore_fn_val;
    LLVMValueRef write_register_fn_val;
    bool error_during_imports;

    LLVMValueRef sp_md_node;

    const char **clang_argv;
    size_t clang_argv_len;
    ZigList<const char *> lib_dirs;

    const char **llvm_argv;
    size_t llvm_argv_len;

    ZigList<FnTableEntry *> test_fns;
    TypeTableEntry *test_fn_type;

    bool each_lib_rpath;

    TypeTableEntry *err_tag_type;
    ZigList<ZigLLVMDIEnumerator *> err_enumerators;
    ZigList<ErrorTableEntry *> errors_by_index;
    bool generate_error_name_table;
    LLVMValueRef err_name_table;
    size_t largest_err_name_len;
    LLVMValueRef safety_crash_err_fn;

    LLVMValueRef return_err_fn;

    IrInstruction *invalid_instruction;
    ConstExprValue const_void_val;

    ConstExprValue panic_msg_vals[PanicMsgIdCount];

    Buf global_asm;
    ZigList<Buf *> link_objects;
    ZigList<Buf *> assembly_files;

    Buf *test_filter;
    Buf *test_name_prefix;

    ZigList<TimeEvent> timing_events;

    Buf *cache_dir;
    Buf *out_h_path;

    ZigList<FnTableEntry *> inline_fns;
    ZigList<AstNode *> tld_ref_source_node_stack;

    TypeTableEntry *align_amt_type;
    TypeTableEntry *stack_trace_type;
    TypeTableEntry *ptr_to_stack_trace_type;

    ZigList<ZigLLVMDIType **> error_di_types;

    ZigList<Buf *> forbidden_libs;

    bool no_rosegment_workaround;
};

enum VarLinkage {
    VarLinkageInternal,
    VarLinkageExport,
    VarLinkageExternal,
};

struct VariableTableEntry {
    Buf name;
    ConstExprValue *value;
    LLVMValueRef value_ref;
    bool src_is_const;
    bool gen_is_const;
    IrInstruction *is_comptime;
    // which node is the declaration of the variable
    AstNode *decl_node;
    ZigLLVMDILocalVariable *di_loc_var;
    size_t src_arg_index;
    size_t gen_arg_index;
    Scope *parent_scope;
    Scope *child_scope;
    LLVMValueRef param_value_ref;
    bool shadowable;
    size_t mem_slot_index;
    IrExecutable *owner_exec;
    size_t ref_count;
    VarLinkage linkage;
    IrInstruction *decl_instruction;
    uint32_t align_bytes;
};

struct ErrorTableEntry {
    Buf name;
    uint32_t value;
    AstNode *decl_node;
    TypeTableEntry *set_with_only_this_in_it;
    // If we generate a constant error name value for this error, we memoize it here.
    // The type of this is array
    ConstExprValue *cached_error_name_val;
};

enum ScopeId {
    ScopeIdDecls,
    ScopeIdBlock,
    ScopeIdDefer,
    ScopeIdDeferExpr,
    ScopeIdVarDecl,
    ScopeIdCImport,
    ScopeIdLoop,
    ScopeIdSuspend,
    ScopeIdFnDef,
    ScopeIdCompTime,
    ScopeIdCoroPrelude,
};

struct Scope {
    ScopeId id;
    AstNode *source_node;

    // if the scope has a parent, this is it
    Scope *parent;

    ZigLLVMDIScope *di_scope;
};

// This scope comes from global declarations or from
// declarations in a container declaration
// NodeTypeRoot, NodeTypeContainerDecl
struct ScopeDecls {
    Scope base;

    HashMap<Buf *, Tld *, buf_hash, buf_eql_buf> decl_table;
    bool safety_off;
    AstNode *safety_set_node;
    bool fast_math_off;
    AstNode *fast_math_set_node;
    ImportTableEntry *import;
    // If this is a scope from a container, this is the type entry, otherwise null
    TypeTableEntry *container_type;
};

// This scope comes from a block expression in user code.
// NodeTypeBlock
struct ScopeBlock {
    Scope base;

    Buf *name;
    IrBasicBlock *end_block;
    IrInstruction *is_comptime;
    ZigList<IrInstruction *> *incoming_values;
    ZigList<IrBasicBlock *> *incoming_blocks;

    bool safety_off;
    AstNode *safety_set_node;
    bool fast_math_off;
    AstNode *fast_math_set_node;
};

// This scope is created from every defer expression.
// It's the code following the defer statement.
// NodeTypeDefer
struct ScopeDefer {
    Scope base;
};

// This scope is created from every defer expression.
// It's the parent of the defer expression itself.
// NodeTypeDefer
struct ScopeDeferExpr {
    Scope base;

    bool reported_err;
};

// This scope is created for every variable declaration inside an IrExecutable
// NodeTypeVariableDeclaration, NodeTypeParamDecl
struct ScopeVarDecl {
    Scope base;

    // The variable that creates this scope
    VariableTableEntry *var;
};

// This scope is created for a @cImport
// NodeTypeFnCallExpr
struct ScopeCImport {
    Scope base;

    Buf buf;
};

// This scope is created for a loop such as for or while in order to
// make break and continue statements work.
// NodeTypeForExpr or NodeTypeWhileExpr
struct ScopeLoop {
    Scope base;

    Buf *name;
    IrBasicBlock *break_block;
    IrBasicBlock *continue_block;
    IrInstruction *is_comptime;
    ZigList<IrInstruction *> *incoming_values;
    ZigList<IrBasicBlock *> *incoming_blocks;
};

// This scope is created for a suspend block in order to have labeled
// suspend for breaking out of a suspend and for detecting if a suspend
// block is inside a suspend block.
struct ScopeSuspend {
    Scope base;

    Buf *name;
    IrBasicBlock *resume_block;
    bool reported_err;
};

// This scope is created for a comptime expression.
// NodeTypeCompTime, NodeTypeSwitchExpr
struct ScopeCompTime {
    Scope base;
};


// This scope is created for a function definition.
// NodeTypeFnDef
struct ScopeFnDef {
    Scope base;

    FnTableEntry *fn_entry;
};

// This scope is created to indicate that the code in the scope
// is auto-generated coroutine prelude stuff.
struct ScopeCoroPrelude {
    Scope base;
};

// synchronized with code in define_builtin_compile_vars
enum AtomicOrder {
    AtomicOrderUnordered,
    AtomicOrderMonotonic,
    AtomicOrderAcquire,
    AtomicOrderRelease,
    AtomicOrderAcqRel,
    AtomicOrderSeqCst,
};

// synchronized with the code in define_builtin_compile_vars
enum AtomicRmwOp {
    AtomicRmwOp_xchg,
    AtomicRmwOp_add,
    AtomicRmwOp_sub,
    AtomicRmwOp_and,
    AtomicRmwOp_nand,
    AtomicRmwOp_or,
    AtomicRmwOp_xor,
    AtomicRmwOp_max,
    AtomicRmwOp_min,
};

// A basic block contains no branching. Branches send control flow
// to another basic block.
// Phi instructions must be first in a basic block.
// The last instruction in a basic block must be of type unreachable.
struct IrBasicBlock {
    ZigList<IrInstruction *> instruction_list;
    IrBasicBlock *other;
    Scope *scope;
    const char *name_hint;
    size_t debug_id;
    size_t ref_count;
    LLVMBasicBlockRef llvm_block;
    LLVMBasicBlockRef llvm_exit_block;
    // The instruction that referenced this basic block and caused us to
    // analyze the basic block. If the same instruction wants us to emit
    // the same basic block, then we re-generate it instead of saving it.
    IrInstruction *ref_instruction;
    // When this is non-null, a branch to this basic block is only allowed
    // if the branch is comptime. The instruction points to the reason
    // the basic block must be comptime.
    IrInstruction *must_be_comptime_source_instr;
};

struct LVal {
    bool is_ptr;
    bool is_const;
    bool is_volatile;
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
    IrInstructionIdUnionFieldPtr,
    IrInstructionIdElemPtr,
    IrInstructionIdVarPtr,
    IrInstructionIdCall,
    IrInstructionIdConst,
    IrInstructionIdReturn,
    IrInstructionIdCast,
    IrInstructionIdContainerInitList,
    IrInstructionIdContainerInitFields,
    IrInstructionIdStructInit,
    IrInstructionIdUnionInit,
    IrInstructionIdUnreachable,
    IrInstructionIdTypeOf,
    IrInstructionIdToPtrType,
    IrInstructionIdPtrTypeChild,
    IrInstructionIdSetCold,
    IrInstructionIdSetRuntimeSafety,
    IrInstructionIdSetFloatMode,
    IrInstructionIdArrayType,
    IrInstructionIdPromiseType,
    IrInstructionIdSliceType,
    IrInstructionIdAsm,
    IrInstructionIdSizeOf,
    IrInstructionIdTestNonNull,
    IrInstructionIdUnwrapOptional,
    IrInstructionIdOptionalWrap,
    IrInstructionIdUnionTag,
    IrInstructionIdClz,
    IrInstructionIdCtz,
    IrInstructionIdPopCount,
    IrInstructionIdImport,
    IrInstructionIdCImport,
    IrInstructionIdCInclude,
    IrInstructionIdCDefine,
    IrInstructionIdCUndef,
    IrInstructionIdArrayLen,
    IrInstructionIdRef,
    IrInstructionIdMinValue,
    IrInstructionIdMaxValue,
    IrInstructionIdCompileErr,
    IrInstructionIdCompileLog,
    IrInstructionIdErrName,
    IrInstructionIdEmbedFile,
    IrInstructionIdCmpxchg,
    IrInstructionIdFence,
    IrInstructionIdTruncate,
    IrInstructionIdIntCast,
    IrInstructionIdFloatCast,
    IrInstructionIdIntToFloat,
    IrInstructionIdFloatToInt,
    IrInstructionIdBoolToInt,
    IrInstructionIdIntType,
    IrInstructionIdBoolNot,
    IrInstructionIdMemset,
    IrInstructionIdMemcpy,
    IrInstructionIdSlice,
    IrInstructionIdMemberCount,
    IrInstructionIdMemberType,
    IrInstructionIdMemberName,
    IrInstructionIdBreakpoint,
    IrInstructionIdReturnAddress,
    IrInstructionIdFrameAddress,
    IrInstructionIdAlignOf,
    IrInstructionIdOverflowOp,
    IrInstructionIdTestErr,
    IrInstructionIdUnwrapErrCode,
    IrInstructionIdUnwrapErrPayload,
    IrInstructionIdErrWrapCode,
    IrInstructionIdErrWrapPayload,
    IrInstructionIdFnProto,
    IrInstructionIdTestComptime,
    IrInstructionIdPtrCast,
    IrInstructionIdBitCast,
    IrInstructionIdWidenOrShorten,
    IrInstructionIdIntToPtr,
    IrInstructionIdPtrToInt,
    IrInstructionIdIntToEnum,
    IrInstructionIdEnumToInt,
    IrInstructionIdIntToErr,
    IrInstructionIdErrToInt,
    IrInstructionIdCheckSwitchProngs,
    IrInstructionIdCheckStatementIsVoid,
    IrInstructionIdTypeName,
    IrInstructionIdDeclRef,
    IrInstructionIdPanic,
    IrInstructionIdTagName,
    IrInstructionIdTagType,
    IrInstructionIdFieldParentPtr,
    IrInstructionIdOffsetOf,
    IrInstructionIdTypeInfo,
    IrInstructionIdTypeId,
    IrInstructionIdSetEvalBranchQuota,
    IrInstructionIdPtrType,
    IrInstructionIdAlignCast,
    IrInstructionIdOpaqueType,
    IrInstructionIdSetAlignStack,
    IrInstructionIdArgType,
    IrInstructionIdExport,
    IrInstructionIdErrorReturnTrace,
    IrInstructionIdErrorUnion,
    IrInstructionIdCancel,
    IrInstructionIdGetImplicitAllocator,
    IrInstructionIdCoroId,
    IrInstructionIdCoroAlloc,
    IrInstructionIdCoroSize,
    IrInstructionIdCoroBegin,
    IrInstructionIdCoroAllocFail,
    IrInstructionIdCoroSuspend,
    IrInstructionIdCoroEnd,
    IrInstructionIdCoroFree,
    IrInstructionIdCoroResume,
    IrInstructionIdCoroSave,
    IrInstructionIdCoroPromise,
    IrInstructionIdCoroAllocHelper,
    IrInstructionIdAtomicRmw,
    IrInstructionIdAtomicLoad,
    IrInstructionIdPromiseResultType,
    IrInstructionIdAwaitBookkeeping,
    IrInstructionIdSaveErrRetAddr,
    IrInstructionIdAddImplicitReturnType,
    IrInstructionIdMergeErrRetTraces,
    IrInstructionIdMarkErrRetTracePtr,
    IrInstructionIdSqrt,
    IrInstructionIdErrSetCast,
    IrInstructionIdToBytes,
    IrInstructionIdFromBytes,
};

struct IrInstruction {
    IrInstructionId id;
    Scope *scope;
    AstNode *source_node;
    ConstExprValue value;
    size_t debug_id;
    LLVMValueRef llvm_value;
    // if ref_count is zero and the instruction has no side effects,
    // the instruction can be omitted in codegen
    size_t ref_count;
    IrInstruction *other;
    IrBasicBlock *owner_bb;
    // true if this instruction was generated by zig and not from user code
    bool is_gen;
};

struct IrInstructionCondBr {
    IrInstruction base;

    IrInstruction *condition;
    IrBasicBlock *then_block;
    IrBasicBlock *else_block;
    IrInstruction *is_comptime;
};

struct IrInstructionBr {
    IrInstruction base;

    IrBasicBlock *dest_block;
    IrInstruction *is_comptime;
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
    IrInstruction *is_comptime;
    IrInstruction *switch_prongs_void;
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
    IrUnOpBinNot,
    IrUnOpNegation,
    IrUnOpNegationWrap,
    IrUnOpDereference,
    IrUnOpOptional,
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
    IrBinOpBitShiftLeftLossy,
    IrBinOpBitShiftLeftExact,
    IrBinOpBitShiftRightLossy,
    IrBinOpBitShiftRightExact,
    IrBinOpAdd,
    IrBinOpAddWrap,
    IrBinOpSub,
    IrBinOpSubWrap,
    IrBinOpMult,
    IrBinOpMultWrap,
    IrBinOpDivUnspecified,
    IrBinOpDivExact,
    IrBinOpDivTrunc,
    IrBinOpDivFloor,
    IrBinOpRemUnspecified,
    IrBinOpRemRem,
    IrBinOpRemMod,
    IrBinOpArrayCat,
    IrBinOpArrayMult,
    IrBinOpMergeErrorSets,
};

struct IrInstructionBinOp {
    IrInstruction base;

    IrInstruction *op1;
    IrBinOp op_id;
    IrInstruction *op2;
    bool safety_check_on;
};

struct IrInstructionDeclVar {
    IrInstruction base;

    VariableTableEntry *var;
    IrInstruction *var_type;
    IrInstruction *align_value;
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
    Buf *field_name_buffer;
    IrInstruction *field_name_expr;
    bool is_const;
};

struct IrInstructionStructFieldPtr {
    IrInstruction base;

    IrInstruction *struct_ptr;
    TypeStructField *field;
    bool is_const;
};

struct IrInstructionUnionFieldPtr {
    IrInstruction base;

    IrInstruction *union_ptr;
    TypeUnionField *field;
    bool is_const;
};

struct IrInstructionElemPtr {
    IrInstruction base;

    IrInstruction *array_ptr;
    IrInstruction *elem_index;
    PtrLen ptr_len;
    bool is_const;
    bool safety_check_on;
};

struct IrInstructionVarPtr {
    IrInstruction base;

    VariableTableEntry *var;
};

struct IrInstructionCall {
    IrInstruction base;

    IrInstruction *fn_ref;
    FnTableEntry *fn_entry;
    size_t arg_count;
    IrInstruction **args;
    bool is_comptime;
    LLVMValueRef tmp_ptr;
    FnInline fn_inline;
    bool is_async;

    IrInstruction *async_allocator;
    IrInstruction *new_stack;
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

// TODO get rid of this instruction, replace with instructions for each op code
struct IrInstructionCast {
    IrInstruction base;

    IrInstruction *value;
    TypeTableEntry *dest_type;
    CastOp cast_op;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionContainerInitList {
    IrInstruction base;

    IrInstruction *container_type;
    size_t item_count;
    IrInstruction **items;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionContainerInitFieldsField {
    Buf *name;
    IrInstruction *value;
    AstNode *source_node;
    TypeStructField *type_struct_field;
};

struct IrInstructionContainerInitFields {
    IrInstruction base;

    IrInstruction *container_type;
    size_t field_count;
    IrInstructionContainerInitFieldsField *fields;
};

struct IrInstructionStructInitField {
    IrInstruction *value;
    TypeStructField *type_struct_field;
};

struct IrInstructionStructInit {
    IrInstruction base;

    TypeTableEntry *struct_type;
    size_t field_count;
    IrInstructionStructInitField *fields;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionUnionInit {
    IrInstruction base;

    TypeTableEntry *union_type;
    TypeUnionField *field;
    IrInstruction *init_value;
    LLVMValueRef tmp_ptr;
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

struct IrInstructionSetCold {
    IrInstruction base;

    IrInstruction *is_cold;
};

struct IrInstructionSetRuntimeSafety {
    IrInstruction base;

    IrInstruction *safety_on;
};

struct IrInstructionSetFloatMode {
    IrInstruction base;

    IrInstruction *scope_value;
    IrInstruction *mode_value;
};

struct IrInstructionArrayType {
    IrInstruction base;

    IrInstruction *size;
    IrInstruction *child_type;
};

struct IrInstructionPtrType {
    IrInstruction base;

    IrInstruction *align_value;
    IrInstruction *child_type;
    uint32_t bit_offset_start;
    uint32_t bit_offset_end;
    PtrLen ptr_len;
    bool is_const;
    bool is_volatile;
};

struct IrInstructionPromiseType {
    IrInstruction base;

    IrInstruction *payload_type;
};

struct IrInstructionSliceType {
    IrInstruction base;

    IrInstruction *align_value;
    bool is_const;
    bool is_volatile;
    IrInstruction *child_type;
};

struct IrInstructionAsm {
    IrInstruction base;

    // Most information on inline assembly comes from the source node.
    IrInstruction **input_list;
    IrInstruction **output_types;
    VariableTableEntry **output_vars;
    size_t return_count;
    bool has_side_effects;
};

struct IrInstructionSizeOf {
    IrInstruction base;

    IrInstruction *type_value;
};

// returns true if nonnull, returns false if null
// this is so that `zeroes` sets maybe values to null
struct IrInstructionTestNonNull {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionUnwrapOptional {
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

struct IrInstructionPopCount {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionUnionTag {
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

struct IrInstructionRef {
    IrInstruction base;

    IrInstruction *value;
    LLVMValueRef tmp_ptr;
    bool is_const;
    bool is_volatile;
};

struct IrInstructionMinValue {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionMaxValue {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionCompileErr {
    IrInstruction base;

    IrInstruction *msg;
};

struct IrInstructionCompileLog {
    IrInstruction base;

    size_t msg_count;
    IrInstruction **msg_list;
};

struct IrInstructionErrName {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionCImport {
    IrInstruction base;
};

struct IrInstructionCInclude {
    IrInstruction base;

    IrInstruction *name;
};

struct IrInstructionCDefine {
    IrInstruction base;

    IrInstruction *name;
    IrInstruction *value;
};

struct IrInstructionCUndef {
    IrInstruction base;

    IrInstruction *name;
};

struct IrInstructionEmbedFile {
    IrInstruction base;

    IrInstruction *name;
};

struct IrInstructionCmpxchg {
    IrInstruction base;

    IrInstruction *type_value;
    IrInstruction *ptr;
    IrInstruction *cmp_value;
    IrInstruction *new_value;
    IrInstruction *success_order_value;
    IrInstruction *failure_order_value;

    // if this instruction gets to runtime then we know these values:
    TypeTableEntry *type;
    AtomicOrder success_order;
    AtomicOrder failure_order;

    bool is_weak;

    LLVMValueRef tmp_ptr;
};

struct IrInstructionFence {
    IrInstruction base;

    IrInstruction *order_value;

    // if this instruction gets to runtime then we know these values:
    AtomicOrder order;
};

struct IrInstructionTruncate {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionIntCast {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionFloatCast {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionErrSetCast {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionToBytes {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionFromBytes {
    IrInstruction base;

    IrInstruction *dest_child_type;
    IrInstruction *target;
};

struct IrInstructionIntToFloat {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionFloatToInt {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionBoolToInt {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionIntType {
    IrInstruction base;

    IrInstruction *is_signed;
    IrInstruction *bit_count;
};

struct IrInstructionBoolNot {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionMemset {
    IrInstruction base;

    IrInstruction *dest_ptr;
    IrInstruction *byte;
    IrInstruction *count;
};

struct IrInstructionMemcpy {
    IrInstruction base;

    IrInstruction *dest_ptr;
    IrInstruction *src_ptr;
    IrInstruction *count;
};

struct IrInstructionSlice {
    IrInstruction base;

    IrInstruction *ptr;
    IrInstruction *start;
    IrInstruction *end;
    bool safety_check_on;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionMemberCount {
    IrInstruction base;

    IrInstruction *container;
};

struct IrInstructionMemberType {
    IrInstruction base;

    IrInstruction *container_type;
    IrInstruction *member_index;
};

struct IrInstructionMemberName {
    IrInstruction base;

    IrInstruction *container_type;
    IrInstruction *member_index;
};

struct IrInstructionBreakpoint {
    IrInstruction base;
};

struct IrInstructionReturnAddress {
    IrInstruction base;
};

struct IrInstructionFrameAddress {
    IrInstruction base;
};

enum IrOverflowOp {
    IrOverflowOpAdd,
    IrOverflowOpSub,
    IrOverflowOpMul,
    IrOverflowOpShl,
};

struct IrInstructionOverflowOp {
    IrInstruction base;

    IrOverflowOp op;
    IrInstruction *type_value;
    IrInstruction *op1;
    IrInstruction *op2;
    IrInstruction *result_ptr;

    TypeTableEntry *result_ptr_type;
};

struct IrInstructionAlignOf {
    IrInstruction base;

    IrInstruction *type_value;
};

// returns true if error, returns false if not error
struct IrInstructionTestErr {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionUnwrapErrCode {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionUnwrapErrPayload {
    IrInstruction base;

    IrInstruction *value;
    bool safety_check_on;
};

struct IrInstructionOptionalWrap {
    IrInstruction base;

    IrInstruction *value;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionErrWrapPayload {
    IrInstruction base;

    IrInstruction *value;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionErrWrapCode {
    IrInstruction base;

    IrInstruction *value;
    LLVMValueRef tmp_ptr;
};

struct IrInstructionFnProto {
    IrInstruction base;

    IrInstruction **param_types;
    IrInstruction *align_value;
    IrInstruction *return_type;
    IrInstruction *async_allocator_type_value;
    bool is_var_args;
};

// true if the target value is compile time known, false otherwise
struct IrInstructionTestComptime {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionPtrCast {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *ptr;
};

struct IrInstructionBitCast {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *value;
};

struct IrInstructionWidenOrShorten {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionPtrToInt {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionIntToPtr {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionIntToEnum {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *target;
};

struct IrInstructionEnumToInt {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionIntToErr {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionErrToInt {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionCheckSwitchProngsRange {
    IrInstruction *start;
    IrInstruction *end;
};

struct IrInstructionCheckSwitchProngs {
    IrInstruction base;

    IrInstruction *target_value;
    IrInstructionCheckSwitchProngsRange *ranges;
    size_t range_count;
    bool have_else_prong;
};

struct IrInstructionCheckStatementIsVoid {
    IrInstruction base;

    IrInstruction *statement_value;
};

struct IrInstructionTypeName {
    IrInstruction base;

    IrInstruction *type_value;
};

struct IrInstructionDeclRef {
    IrInstruction base;

    Tld *tld;
    LVal lval;
};

struct IrInstructionPanic {
    IrInstruction base;

    IrInstruction *msg;
};

struct IrInstructionTagName {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionTagType {
    IrInstruction base;

    IrInstruction *target;
};

struct IrInstructionFieldParentPtr {
    IrInstruction base;

    IrInstruction *type_value;
    IrInstruction *field_name;
    IrInstruction *field_ptr;
    TypeStructField *field;
};

struct IrInstructionOffsetOf {
    IrInstruction base;

    IrInstruction *type_value;
    IrInstruction *field_name;
};

struct IrInstructionTypeInfo {
    IrInstruction base;

    IrInstruction *type_value;
};

struct IrInstructionTypeId {
    IrInstruction base;

    IrInstruction *type_value;
};

struct IrInstructionSetEvalBranchQuota {
    IrInstruction base;

    IrInstruction *new_quota;
};

struct IrInstructionAlignCast {
    IrInstruction base;

    IrInstruction *align_bytes;
    IrInstruction *target;
};

struct IrInstructionOpaqueType {
    IrInstruction base;
};

struct IrInstructionSetAlignStack {
    IrInstruction base;

    IrInstruction *align_bytes;
};

struct IrInstructionArgType {
    IrInstruction base;

    IrInstruction *fn_type;
    IrInstruction *arg_index;
};

struct IrInstructionExport {
    IrInstruction base;

    IrInstruction *name;
    IrInstruction *linkage;
    IrInstruction *target;
};

struct IrInstructionErrorReturnTrace {
    IrInstruction base;

    enum Optional {
        Null,
        NonNull,
    } optional;
};

struct IrInstructionErrorUnion {
    IrInstruction base;

    IrInstruction *err_set;
    IrInstruction *payload;
};

struct IrInstructionCancel {
    IrInstruction base;

    IrInstruction *target;
};

enum ImplicitAllocatorId {
    ImplicitAllocatorIdArg,
    ImplicitAllocatorIdLocalVar,
};

struct IrInstructionGetImplicitAllocator {
    IrInstruction base;

    ImplicitAllocatorId id;
};

struct IrInstructionCoroId {
    IrInstruction base;

    IrInstruction *promise_ptr;
};

struct IrInstructionCoroAlloc {
    IrInstruction base;

    IrInstruction *coro_id;
};

struct IrInstructionCoroSize {
    IrInstruction base;
};

struct IrInstructionCoroBegin {
    IrInstruction base;

    IrInstruction *coro_id;
    IrInstruction *coro_mem_ptr;
};

struct IrInstructionCoroAllocFail {
    IrInstruction base;

    IrInstruction *err_val;
};

struct IrInstructionCoroSuspend {
    IrInstruction base;

    IrInstruction *save_point;
    IrInstruction *is_final;
};

struct IrInstructionCoroEnd {
    IrInstruction base;
};

struct IrInstructionCoroFree {
    IrInstruction base;

    IrInstruction *coro_id;
    IrInstruction *coro_handle;
};

struct IrInstructionCoroResume {
    IrInstruction base;

    IrInstruction *awaiter_handle;
};

struct IrInstructionCoroSave {
    IrInstruction base;

    IrInstruction *coro_handle;
};

struct IrInstructionCoroPromise {
    IrInstruction base;

    IrInstruction *coro_handle;
};

struct IrInstructionCoroAllocHelper {
    IrInstruction base;

    IrInstruction *alloc_fn;
    IrInstruction *coro_size;
};

struct IrInstructionAtomicRmw {
    IrInstruction base;

    IrInstruction *operand_type;
    IrInstruction *ptr;
    IrInstruction *op;
    AtomicRmwOp resolved_op;
    IrInstruction *operand;
    IrInstruction *ordering;
    AtomicOrder resolved_ordering;
};

struct IrInstructionAtomicLoad {
    IrInstruction base;

    IrInstruction *operand_type;
    IrInstruction *ptr;
    IrInstruction *ordering;
    AtomicOrder resolved_ordering;
};

struct IrInstructionPromiseResultType {
    IrInstruction base;

    IrInstruction *promise_type;
};

struct IrInstructionAwaitBookkeeping {
    IrInstruction base;

    IrInstruction *promise_result_type;
};

struct IrInstructionSaveErrRetAddr {
    IrInstruction base;
};

struct IrInstructionAddImplicitReturnType {
    IrInstruction base;

    IrInstruction *value;
};

struct IrInstructionMergeErrRetTraces {
    IrInstruction base;

    IrInstruction *coro_promise_ptr;
    IrInstruction *src_err_ret_trace_ptr;
    IrInstruction *dest_err_ret_trace_ptr;
};

struct IrInstructionMarkErrRetTracePtr {
    IrInstruction base;

    IrInstruction *err_ret_trace_ptr;
};

struct IrInstructionSqrt {
    IrInstruction base;

    IrInstruction *type;
    IrInstruction *op;
};

static const size_t slice_ptr_index = 0;
static const size_t slice_len_index = 1;

static const size_t maybe_child_index = 0;
static const size_t maybe_null_index = 1;

static const size_t err_union_err_index = 0;
static const size_t err_union_payload_index = 1;

// TODO call graph analysis to find out what this number needs to be for every function
static const size_t stack_trace_ptr_count = 30;

// these belong to the async function
#define RETURN_ADDRESSES_FIELD_NAME "return_addresses"
#define ERR_RET_TRACE_FIELD_NAME "err_ret_trace"
#define RESULT_FIELD_NAME "result"
#define ASYNC_ALLOC_FIELD_NAME "allocFn"
#define ASYNC_FREE_FIELD_NAME "freeFn"
#define AWAITER_HANDLE_FIELD_NAME "awaiter_handle"
// these point to data belonging to the awaiter
#define ERR_RET_TRACE_PTR_FIELD_NAME "err_ret_trace_ptr"
#define RESULT_PTR_FIELD_NAME "result_ptr"


enum FloatMode {
    FloatModeOptimized,
    FloatModeStrict,
};

#endif
