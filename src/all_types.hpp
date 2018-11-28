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
#include "cache_hash.hpp"
#include "zig_llvm.h"
#include "hash_map.hpp"
#include "errmsg.hpp"
#include "bigint.hpp"
#include "bigfloat.hpp"
#include "target.hpp"
#include "tokenizer.hpp"

struct AstNode;
struct ImportTableEntry;
struct ZigFn;
struct Scope;
struct ScopeBlock;
struct ScopeFnDef;
struct ZigType;
struct ZigVar;
struct ErrorTableEntry;
struct BuiltinFnEntry;
struct TypeStructField;
struct CodeGen;
struct ConstExprValue;
struct IrInstruction;
struct IrInstructionAllocaGen;
struct IrInstructionResultPtrCast;
struct IrBasicBlock;
struct ScopeDecls;
struct ZigWindowsSDK;
struct Tld;
struct TldExport;
struct IrAnalyze;

enum X64CABIClass {
    X64CABIClass_Unknown,
    X64CABIClass_MEMORY,
    X64CABIClass_INTEGER,
    X64CABIClass_SSE,
};

struct IrExecutable {
    ZigList<IrBasicBlock *> basic_block_list;
    Buf *name;
    ZigFn *name_fn;
    size_t mem_slot_count;
    size_t next_debug_id;
    size_t *backward_branch_count;
    size_t backward_branch_quota;
    bool invalid;
    bool is_inline;
    bool is_generic_instantiation;
    ZigFn *fn_entry;
    Buf *c_import_buf;
    AstNode *source_node;
    IrExecutable *parent_exec;
    IrExecutable *source_exec;
    IrAnalyze *analysis;
    Scope *begin_scope;
    ZigList<Tld *> tld_list;

    IrInstruction *coro_handle;
    IrInstruction *atomic_state_field_ptr; // this one is shared and in the promise
    IrInstruction *coro_result_ptr_field_ptr;
    IrInstruction *coro_result_field_ptr;
    IrInstruction *await_handle_var_ptr; // this one is where we put the one we extracted from the promise
    IrBasicBlock *coro_early_final;
    IrBasicBlock *coro_normal_final;
    IrBasicBlock *coro_suspend_block;
    IrBasicBlock *coro_final_cleanup_block;
    ZigVar *coro_allocator_var;
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
    ConstParentIdErrUnionCode,
    ConstParentIdErrUnionPayload,
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
            ConstExprValue *err_union_val;
        } p_err_union_code;
        struct {
            ConstExprValue *err_union_val;
        } p_err_union_payload;
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
    ConstArraySpecialBuf,
};

struct ConstArrayValue {
    ConstArraySpecial special;
    union {
        struct {
            ConstExprValue *elements;
            ConstParent parent;
        } s_none;
        Buf *s_buf;
    } data;
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
    // The pointer points to the error set field of an error union
    ConstPtrSpecialBaseErrorUnionCode,
    // The pointer points to the payload field of an error union
    ConstPtrSpecialBaseErrorUnionPayload,
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
    // The pointer points to memory for which it must be inferred whether the
    // value is comptime known or not.
    ConstPtrMutInfer,
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
            ConstExprValue *err_union_val;
        } base_err_union_code;
        struct {
            ConstExprValue *err_union_val;
        } base_err_union_payload;
        struct {
            uint64_t addr;
        } hard_coded_addr;
        struct {
            ZigFn *fn_entry;
        } fn;
    } data;
};

struct ConstErrValue {
    ConstExprValue *error_set;
    ConstExprValue *payload;
    ConstParent parent;
};

struct ConstBoundFnValue {
    ZigFn *fn;
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
    ZigType *type;
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
        ZigType *x_type;
        ConstExprValue *x_optional;
        ConstErrValue x_err_union;
        ErrorTableEntry *x_err_set;
        BigInt x_enum_tag;
        ConstStructValue x_struct;
        ConstUnionValue x_union;
        ConstArrayValue x_array;
        ConstPtrValue x_ptr;
        ImportTableEntry *x_import;
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

    ZigVar *var;
    Buf *extern_lib_name;
    Buf *section_name;
};

struct TldFn {
    Tld base;

    ZigFn *fn_entry;
    Buf *extern_lib_name;
};

struct TldContainer {
    Tld base;

    ScopeDecls *decls_scope;
    ZigType *type_entry;
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
    ZigType *type_entry;
    AstNode *decl_node;
    uint32_t gen_index;
};

enum NodeType {
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
    NodeTypeIfOptional,
    NodeTypeErrorSetDecl,
    NodeTypeCancel,
    NodeTypeResume,
    NodeTypeAwaitExpr,
    NodeTypeSuspend,
    NodeTypePromiseType,
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
    BigInt *host_int_bytes;
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
    bool auto_enum, is_root; // union(enum)
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
    AstNode *block;
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
    ZigType *type;
};

struct GenericFnTypeId {
    CodeGen *codegen;
    ZigFn *fn_entry;
    ConstExprValue *params;
    size_t param_count;
};

uint32_t generic_fn_type_id_hash(GenericFnTypeId *id);
bool generic_fn_type_id_eql(GenericFnTypeId *a, GenericFnTypeId *b);

struct FnTypeId {
    ZigType *return_type;
    FnTypeParamInfo *param_info;
    size_t param_count;
    size_t next_param_index;
    bool is_var_args;
    CallingConvention cc;
    uint32_t alignment;
    ZigType *async_allocator_type;
};

uint32_t fn_type_id_hash(FnTypeId*);
bool fn_type_id_eql(FnTypeId *a, FnTypeId *b);

enum PtrLen {
    PtrLenUnknown,
    PtrLenSingle,
};

struct ZigTypePointer {
    ZigType *child_type;
    ZigType *slice_parent;
    PtrLen ptr_len;
    uint32_t explicit_alignment; // 0 means use ABI alignment
    uint32_t bit_offset_in_host;
    uint32_t host_int_bytes; // size of host integer. 0 means no host integer; this field is aligned
    bool is_const;
    bool is_volatile;
};

struct ZigTypeInt {
    uint32_t bit_count;
    bool is_signed;
};

struct ZigTypeFloat {
    size_t bit_count;
};

struct ZigTypeArray {
    ZigType *child_type;
    uint64_t len;
};

struct TypeStructField {
    Buf *name;
    ZigType *type_entry;
    size_t src_index;
    size_t gen_index;
    uint32_t bit_offset_in_host; // offset from the memory at gen_index
    AstNode *decl_node;
};

enum ResolveStatus {
    ResolveStatusUnstarted,
    ResolveStatusInvalid,
    ResolveStatusZeroBitsKnown,
    ResolveStatusAlignmentKnown,
    ResolveStatusSizeKnown,
};

struct ZigTypeStruct {
    AstNode *decl_node;
    TypeStructField *fields;
    ScopeDecls *decls_scope;
    uint64_t size_bytes;
    HashMap<Buf *, TypeStructField *, buf_hash, buf_eql_buf> fields_by_name;

    uint32_t src_field_count;
    uint32_t gen_field_count;

    uint32_t abi_alignment; // known after ResolveStatusAlignmentKnown
    ContainerLayout layout;
    ResolveStatus resolve_status;

    bool is_slice;
    bool resolve_loop_flag; // set this flag temporarily to detect infinite loops
    bool reported_infinite_err;
    // whether any of the fields require comptime
    // known after ResolveStatusZeroBitsKnown
    bool requires_comptime;
};

struct ZigTypeOptional {
    ZigType *child_type;
};

struct ZigTypeErrorUnion {
    ZigType *err_set_type;
    ZigType *payload_type;
};

struct ZigTypeErrorSet {
    uint32_t err_count;
    ErrorTableEntry **errors;
    ZigFn *infer_fn;
};

struct ZigTypeEnum {
    AstNode *decl_node;
    ContainerLayout layout;
    uint32_t src_field_count;
    TypeEnumField *fields;
    bool is_invalid; // true if any fields are invalid
    ZigType *tag_int_type;

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

uint32_t type_ptr_hash(const ZigType *ptr);
bool type_ptr_eql(const ZigType *a, const ZigType *b);

struct ZigTypeUnion {
    AstNode *decl_node;
    ContainerLayout layout;
    uint32_t src_field_count;
    uint32_t gen_field_count;
    TypeUnionField *fields;
    bool is_invalid; // true if any fields are invalid
    ZigType *tag_type; // always an enum or null
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
    ZigType *most_aligned_union_member;

    HashMap<Buf *, TypeUnionField *, buf_hash, buf_eql_buf> fields_by_name;
};

struct FnGenParamInfo {
    size_t src_index;
    size_t gen_index;
    bool is_byval;
    ZigType *type;
};

struct ZigTypeFn {
    FnTypeId fn_type_id;
    bool is_generic;
    ZigType *gen_return_type;
    size_t gen_param_count;
    FnGenParamInfo *gen_param_info;

    LLVMTypeRef raw_type_ref;

    ZigType *bound_fn_parent;
};

struct ZigTypeBoundFn {
    ZigType *fn_type;
};

struct ZigTypePromise {
    // null if `promise` instead of `promise->T`
    ZigType *result_type;
};

enum ZigTypeId {
    ZigTypeIdInvalid,
    ZigTypeIdMetaType,
    ZigTypeIdVoid,
    ZigTypeIdBool,
    ZigTypeIdUnreachable,
    ZigTypeIdInt,
    ZigTypeIdFloat,
    ZigTypeIdPointer,
    ZigTypeIdArray,
    ZigTypeIdStruct,
    ZigTypeIdComptimeFloat,
    ZigTypeIdComptimeInt,
    ZigTypeIdUndefined,
    ZigTypeIdNull,
    ZigTypeIdOptional,
    ZigTypeIdErrorUnion,
    ZigTypeIdErrorSet,
    ZigTypeIdEnum,
    ZigTypeIdUnion,
    ZigTypeIdFn,
    ZigTypeIdNamespace,
    ZigTypeIdBoundFn,
    ZigTypeIdArgTuple,
    ZigTypeIdOpaque,
    ZigTypeIdPromise,
};

struct ZigType {
    ZigTypeId id;
    Buf name;

    LLVMTypeRef type_ref;
    ZigLLVMDIType *di_type;

    bool zero_bits; // this is denormalized data
    bool gen_h_loop_flag;

    union {
        ZigTypePointer pointer;
        ZigTypeInt integral;
        ZigTypeFloat floating;
        ZigTypeArray array;
        ZigTypeStruct structure;
        ZigTypeOptional maybe;
        ZigTypeErrorUnion error_union;
        ZigTypeErrorSet error_set;
        ZigTypeEnum enumeration;
        ZigTypeUnion unionation;
        ZigTypeFn fn;
        ZigTypeBoundFn bound_fn;
        ZigTypePromise promise;
    } data;

    // use these fields to make sure we don't duplicate type table entries for the same type
    ZigType *pointer_parent[2]; // [0 - mut, 1 - const]
    ZigType *optional_parent;
    ZigType *promise_parent;
    ZigType *promise_frame_parent;
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

struct ZigFn {
    CodeGen *codegen;
    LLVMValueRef llvm_value;
    const char *llvm_name;
    AstNode *proto_node;
    AstNode *body_node;
    ScopeFnDef *fndef_scope; // parent should be the top level decls or container decls
    Scope *child_scope; // parent is scope for last parameter
    ScopeBlock *def_scope; // parent is child_scope
    Buf symbol_name;
    ZigType *type_entry; // function type
    // in the case of normal functions this is the implicit return type
    // in the case of async functions this is the implicit return type according to the
    // zig source code, not according to zig ir
    ZigType *src_implicit_return_type;
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

    ZigList<IrInstructionAllocaGen *> alloca_list;
    ZigList<ZigVar *> variable_list;

    Buf *section_name;
    AstNode *set_alignstack_node;
    uint32_t alignstack_value;

    AstNode *set_cold_node;
    bool is_cold;

    ZigList<FnExport> export_list;
    bool calls_or_awaits_errorable_fn;
};

uint32_t fn_table_entry_hash(ZigFn*);
bool fn_table_entry_eql(ZigFn *a, ZigFn *b);

enum BuiltinFnId {
    BuiltinFnIdInvalid,
    BuiltinFnIdMemcpy,
    BuiltinFnIdMemset,
    BuiltinFnIdSizeof,
    BuiltinFnIdAlignOf,
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
    BuiltinFnIdHandle,
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
    BuiltinFnIdByteOffsetOf,
    BuiltinFnIdBitOffsetOf,
    BuiltinFnIdInlineCall,
    BuiltinFnIdNoInlineCall,
    BuiltinFnIdNewStackCall,
    BuiltinFnIdTypeId,
    BuiltinFnIdShlExact,
    BuiltinFnIdShrExact,
    BuiltinFnIdSetEvalBranchQuota,
    BuiltinFnIdAlignCast,
    BuiltinFnIdOpaqueType,
    BuiltinFnIdThis,
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
    ZigTypeId id;

    union {
        struct {
            ZigType *child_type;
            PtrLen ptr_len;
            bool is_const;
            bool is_volatile;
            uint32_t alignment;
            uint32_t bit_offset_in_host;
            uint32_t host_int_bytes;
        } pointer;
        struct {
            ZigType *child_type;
            uint64_t size;
        } array;
        struct {
            bool is_signed;
            uint32_t bit_count;
        } integer;
        struct {
            ZigType *err_set_type;
            ZigType *payload_type;
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

// When adding fields, check if they should be added to the hash computation in build_with_cache
struct CodeGen {
    //////////////////////////// Runtime State
    LLVMModuleRef module;
    ZigList<ErrorMsg*> errors;
    LLVMBuilderRef builder;
    ZigLLVMDIBuilder *dbuilder;
    ZigLLVMDICompileUnit *compile_unit;
    ZigLLVMDIFile *compile_unit_file;
    LinkLib *libc_link_lib;
    LLVMTargetDataRef target_data_ref;
    LLVMTargetMachineRef target_machine;
    ZigLLVMDIFile *dummy_di_file;
    LLVMValueRef cur_ret_ptr;
    LLVMValueRef cur_fn_val;
    LLVMValueRef cur_err_ret_trace_val_arg;
    LLVMValueRef cur_err_ret_trace_val_stack;
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
    LLVMValueRef coro_frame_fn_val;
    LLVMValueRef merge_err_ret_traces_fn_val;
    LLVMValueRef add_error_return_trace_addr_fn_val;
    LLVMValueRef stacksave_fn_val;
    LLVMValueRef stackrestore_fn_val;
    LLVMValueRef write_register_fn_val;
    LLVMValueRef sp_md_node;
    LLVMValueRef err_name_table;
    LLVMValueRef safety_crash_err_fn;
    LLVMValueRef return_err_fn;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, ImportTableEntry *, buf_hash, buf_eql_buf> import_table;
    HashMap<Buf *, BuiltinFnEntry *, buf_hash, buf_eql_buf> builtin_fn_table;
    HashMap<Buf *, ZigType *, buf_hash, buf_eql_buf> primitive_type_table;
    HashMap<TypeId, ZigType *, type_id_hash, type_id_eql> type_table;
    HashMap<FnTypeId *, ZigType *, fn_type_id_hash, fn_type_id_eql> fn_type_table;
    HashMap<Buf *, ErrorTableEntry *, buf_hash, buf_eql_buf> error_table;
    HashMap<GenericFnTypeId *, ZigFn *, generic_fn_type_id_hash, generic_fn_type_id_eql> generic_table;
    HashMap<Scope *, IrInstruction *, fn_eval_hash, fn_eval_eql> memoized_fn_eval_table;
    HashMap<ZigLLVMFnKey, LLVMValueRef, zig_llvm_fn_key_hash, zig_llvm_fn_key_eql> llvm_fn_table;
    HashMap<Buf *, AstNode *, buf_hash, buf_eql_buf> exported_symbol_names;
    HashMap<Buf *, Tld *, buf_hash, buf_eql_buf> external_prototypes;
    HashMap<Buf *, ConstExprValue *, buf_hash, buf_eql_buf> string_literals_table;
    HashMap<const ZigType *, ConstExprValue *, type_ptr_hash, type_ptr_eql> type_info_cache;

    ZigList<ImportTableEntry *> import_queue;
    size_t import_queue_index;
    ZigList<Tld *> resolve_queue;
    size_t resolve_queue_index;
    ZigList<AstNode *> use_queue;
    size_t use_queue_index;
    ZigList<TimeEvent> timing_events;
    ZigList<ZigLLVMDIType **> error_di_types;
    ZigList<AstNode *> tld_ref_source_node_stack;
    ZigList<ZigFn *> inline_fns;
    ZigList<ZigFn *> test_fns;
    ZigList<ZigLLVMDIEnumerator *> err_enumerators;
    ZigList<ErrorTableEntry *> errors_by_index;
    size_t largest_err_name_len;

    PackageTableEntry *std_package;
    PackageTableEntry *panic_package;
    PackageTableEntry *test_runner_package;
    PackageTableEntry *compile_var_package;
    ImportTableEntry *compile_var_import;
    ImportTableEntry *root_import;
    ImportTableEntry *bootstrap_import;
    ImportTableEntry *test_runner_import;

    struct {
        ZigType *entry_bool;
        ZigType *entry_c_int[CIntTypeCount];
        ZigType *entry_c_longdouble;
        ZigType *entry_c_void;
        ZigType *entry_infer;
        ZigType *entry_u8;
        ZigType *entry_u16;
        ZigType *entry_u32;
        ZigType *entry_u29;
        ZigType *entry_u64;
        ZigType *entry_i8;
        ZigType *entry_i32;
        ZigType *entry_i64;
        ZigType *entry_isize;
        ZigType *entry_usize;
        ZigType *entry_f16;
        ZigType *entry_f32;
        ZigType *entry_f64;
        ZigType *entry_f128;
        ZigType *entry_void;
        ZigType *entry_unreachable;
        ZigType *entry_type;
        ZigType *entry_invalid;
        ZigType *entry_namespace;
        ZigType *entry_block;
        ZigType *entry_num_lit_int;
        ZigType *entry_num_lit_float;
        ZigType *entry_undef;
        ZigType *entry_null;
        ZigType *entry_var;
        ZigType *entry_global_error_set;
        ZigType *entry_arg_tuple;
        ZigType *entry_promise;
    } builtin_types;
    ZigType *align_amt_type;
    ZigType *stack_trace_type;
    ZigType *ptr_to_stack_trace_type;
    ZigType *err_tag_type;
    ZigType *test_fn_type;

    Buf triple_str;
    Buf global_asm;
    Buf *out_h_path;
    Buf artifact_dir;
    Buf output_file_path;
    Buf o_file_output_path;
    Buf *wanted_output_file_path;
    Buf cache_dir;

    IrInstruction *invalid_instruction;
    IrInstruction *unreach_instruction;

    ConstExprValue const_void_val;
    ConstExprValue panic_msg_vals[PanicMsgIdCount];

    // The function definitions this module includes.
    ZigList<ZigFn *> fn_defs;
    size_t fn_defs_index;
    ZigList<TldVar *> global_vars;

    ZigFn *cur_fn;
    ZigFn *main_fn;
    ZigFn *panic_fn;
    AstNode *root_export_decl;

    CacheHash cache_hash;
    ErrColor err_color;
    uint32_t next_unresolved_index;
    unsigned pointer_size_bytes;
    uint32_t target_os_index;
    uint32_t target_arch_index;
    uint32_t target_environ_index;
    uint32_t target_oformat_index;
    bool is_big_endian;
    bool have_pub_main;
    bool have_c_main;
    bool have_winmain;
    bool have_winmain_crt_startup;
    bool have_dllmain_crt_startup;
    bool have_pub_panic;
    bool have_err_ret_tracing;
    bool c_want_stdint;
    bool c_want_stdbool;
    bool verbose_tokenize;
    bool verbose_ast;
    bool verbose_link;
    bool verbose_ir;
    bool verbose_llvm_ir;
    bool verbose_cimport;
    bool error_during_imports;
    bool generate_error_name_table;
    bool enable_cache;
    bool enable_time_report;
    bool system_linker_hack;

    //////////////////////////// Participates in Input Parameter Cache Hash
    ZigList<LinkLib *> link_libs_list;
    // add -framework [name] args to linker
    ZigList<Buf *> darwin_frameworks;
    // add -rpath [name] args to linker
    ZigList<Buf *> rpath_list;
    ZigList<Buf *> forbidden_libs;
    ZigList<Buf *> link_objects;
    ZigList<Buf *> assembly_files;
    ZigList<const char *> lib_dirs;

    size_t version_major;
    size_t version_minor;
    size_t version_patch;
    const char *linker_script;

    EmitFileType emit_file_type;
    BuildMode build_mode;
    OutType out_type;
    ZigTarget zig_target;
    bool is_static;
    bool strip_debug_symbols;
    bool is_test_build;
    bool is_native_target;
    bool windows_subsystem_windows;
    bool windows_subsystem_console;
    bool linker_rdynamic;
    bool no_rosegment_workaround;
    bool each_lib_rpath;
    bool disable_pic;

    Buf *mmacosx_version_min;
    Buf *mios_version_min;
    Buf *root_out_name;
    Buf *test_filter;
    Buf *test_name_prefix;
    PackageTableEntry *root_package;

    const char **llvm_argv;
    size_t llvm_argv_len;

    const char **clang_argv;
    size_t clang_argv_len;

    //////////////////////////// Unsorted

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
    ZigWindowsSDK *win_sdk;
};

enum VarLinkage {
    VarLinkageInternal,
    VarLinkageExport,
    VarLinkageExternal,
};

struct ZigVar {
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
    uint32_t align_bytes;

    // In an inline loop, multiple variables may be created,
    // In this case, a reference to a variable should follow
    // this pointer to the redefined variable.
    ZigVar *next_var;
};

struct ErrorTableEntry {
    Buf name;
    uint32_t value;
    AstNode *decl_node;
    ZigType *set_with_only_this_in_it;
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
    ScopeIdRuntime,
};

struct Scope {
    CodeGen *codegen;
    AstNode *source_node;

    // if the scope has a parent, this is it
    Scope *parent;

    ZigLLVMDIScope *di_scope;
    ScopeId id;
};

// This scope comes from global declarations or from
// declarations in a container declaration
// NodeTypeContainerDecl
struct ScopeDecls {
    Scope base;

    HashMap<Buf *, Tld *, buf_hash, buf_eql_buf> decl_table;
    bool safety_off;
    AstNode *safety_set_node;
    bool fast_math_on;
    AstNode *fast_math_set_node;
    ImportTableEntry *import;
    // If this is a scope from a container, this is the type entry, otherwise null
    ZigType *container_type;
};

// This scope comes from a block expression in user code.
// NodeTypeBlock
struct ScopeBlock {
    Scope base;

    Buf *name;
    IrBasicBlock *end_block;
    IrInstruction *is_comptime;
    IrInstruction *result_loc;
    ZigList<IrInstruction *> *incoming_values;
    ZigList<IrBasicBlock *> *incoming_blocks;

    bool safety_off;
    AstNode *safety_set_node;
    bool fast_math_on;
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
    ZigVar *var;
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
    IrInstruction *result_loc;
    ZigList<IrInstruction *> *incoming_values;
    ZigList<IrBasicBlock *> *incoming_blocks;
};

// This scope blocks certain things from working such as comptime continue
// inside a runtime if expression.
// NodeTypeIfBoolExpr, NodeTypeWhileExpr, NodeTypeForExpr
struct ScopeRuntime {
    Scope base;

    IrInstruction *is_comptime;
};

// This scope is created for a suspend block in order to have labeled
// suspend for breaking out of a suspend and for detecting if a suspend
// block is inside a suspend block.
struct ScopeSuspend {
    Scope base;

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

    ZigFn *fn_entry;
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

enum IrInstructionId {
    IrInstructionIdInvalid,
    IrInstructionIdDeclVarSrc,
    IrInstructionIdDeclVarGen,
    IrInstructionIdBr,
    IrInstructionIdCondBr,
    IrInstructionIdSwitchBr,
    IrInstructionIdSwitchVar,
    IrInstructionIdSwitchTarget,
    IrInstructionIdPhi,
    IrInstructionIdUnOp,
    IrInstructionIdBinOp,
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
    IrInstructionIdRef,
    IrInstructionIdCompileErr,
    IrInstructionIdCompileLog,
    IrInstructionIdErrName,
    IrInstructionIdEmbedFile,
    IrInstructionIdCmpxchgSrc,
    IrInstructionIdCmpxchgGen,
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
    IrInstructionIdHandle,
    IrInstructionIdAlignOf,
    IrInstructionIdOverflowOp,
    IrInstructionIdTestErr,
    IrInstructionIdUnwrapErrCode,
    IrInstructionIdUnwrapErrPayload,
    IrInstructionIdErrWrapCode,
    IrInstructionIdErrWrapPayload,
    IrInstructionIdFnProto,
    IrInstructionIdTestComptime,
    IrInstructionIdPtrCastSrc,
    IrInstructionIdPtrCastGen,
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
    IrInstructionIdByteOffsetOf,
    IrInstructionIdBitOffsetOf,
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
    IrInstructionIdCheckRuntimeScope,
    IrInstructionIdResultOptionalPayload,
    IrInstructionIdResultErrorUnionPayload,
    IrInstructionIdResultErrorUnionCode,
    IrInstructionIdResultSlicePtr,
    IrInstructionIdResultReturn,
    IrInstructionIdResultBytesToSlice,
    IrInstructionIdResultSliceToBytes,
    IrInstructionIdResultPtrCast,
    IrInstructionIdResultCast,
    IrInstructionIdAllocaSrc,
    IrInstructionIdAllocaGen,
    IrInstructionIdAssertNonError,
    IrInstructionIdAssertNonNull,
    IrInstructionIdErrorUnionFieldErrorSet,
    IrInstructionIdFirstArgResultLoc,
    IrInstructionIdInferArrayType,
    IrInstructionIdInferCompTime,
    IrInstructionIdSetNonNullBit,
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
    // When analyzing IR, instructions that point to this instruction in the "old ir"
    // can find the instruction that corresponds to this value in the "new ir"
    // with this child field.
    IrInstruction *child;
    IrBasicBlock *owner_bb;
    // true if this instruction was generated by zig and not from user code
    bool is_gen;
};

struct IrInstructionDeclVarSrc {
    IrInstruction base;

    ZigVar *var;
    IrInstruction *var_type;
    IrInstruction *align_value;
    IrInstruction *ptr;
};

struct IrInstructionDeclVarGen {
    IrInstruction base;

    ZigVar *var;
    IrInstruction *var_ptr;
};

struct IrInstructionCondBr {
    IrInstruction base;

    IrInstruction *condition;
    IrBasicBlock *then_block;
    IrBasicBlock *else_block;
    IrInstruction *is_comptime;
    IrInstruction *result_loc;
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
    IrInstruction *result_loc;
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

struct IrInstructionLoadPtr {
    IrInstruction base;

    IrInstruction *ptr;
    IrInstruction *result_loc;
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
    IrInstruction *container_type;
    bool is_const;
};

struct IrInstructionStructFieldPtr {
    IrInstruction base;

    IrInstruction *struct_ptr;
    TypeStructField *field;
    bool is_const;
};

enum IrInstructionUnionFieldPtrId {
    IrInstructionUnionFieldPtrIdRef,
    IrInstructionUnionFieldPtrIdSwitch,
    IrInstructionUnionFieldPtrIdResultPtr,
};

struct IrInstructionUnionFieldPtr {
    IrInstruction base;

    IrInstruction *union_ptr;
    TypeUnionField *field;
    IrInstructionUnionFieldPtrId id;
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

    ZigVar *var;
    ScopeFnDef *crossed_fndef_scope;
};

struct IrInstructionCall {
    IrInstruction base;

    IrInstruction *fn_ref;
    ZigFn *fn_entry;
    size_t arg_count;
    IrInstruction **args;
    IrInstruction *async_allocator;
    IrInstruction *new_stack;
    IrInstruction *result_loc;
    IrInstruction *first_arg_result_loc;
    FnInline fn_inline;
    bool is_async;
    bool is_comptime;
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
    IrInstruction *result_loc;
    ZigType *dest_type;
    CastOp cast_op;
};

struct IrInstructionContainerInitList {
    IrInstruction base;

    IrInstruction *container_type;
    IrInstruction *result_loc;
    size_t elem_count;
    IrInstruction **elem_result_loc_list;
};

struct IrInstructionContainerInitFieldsField {
    Buf *name;
    IrInstruction *result_loc;
    AstNode *source_node;
    TypeStructField *type_struct_field;
};

struct IrInstructionContainerInitFields {
    IrInstruction base;

    IrInstruction *container_type;
    size_t field_count;
    IrInstructionContainerInitFieldsField *fields;
    IrInstruction *result_loc;
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
    uint32_t host_int_bytes;
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
    IrInstruction *child_type;
    bool is_const;
    bool is_volatile;
};

struct IrInstructionAsm {
    IrInstruction base;

    // Most information on inline assembly comes from the source node.
    IrInstruction **input_list;
    IrInstruction **output_types;
    ZigVar **output_vars;
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

struct IrInstructionRef {
    IrInstruction base;

    IrInstruction *value;
    IrInstruction *result_loc;
    bool is_const;
    bool is_volatile;
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

struct IrInstructionCmpxchgSrc {
    IrInstruction base;

    IrInstruction *type_value;
    IrInstruction *ptr;
    IrInstruction *cmp_value;
    IrInstruction *new_value;
    IrInstruction *success_order_value;
    IrInstruction *failure_order_value;
    IrInstruction *result_loc;

    bool is_weak;
};

struct IrInstructionCmpxchgGen {
    IrInstruction base;

    ZigType *type;
    IrInstruction *ptr;
    IrInstruction *cmp_value;
    IrInstruction *new_value;
    IrInstruction *result_loc;

    AtomicOrder success_order;
    AtomicOrder failure_order;

    bool is_weak;
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
    IrInstruction *result_loc;
    bool safety_check_on;
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

struct IrInstructionHandle {
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

    ZigType *result_ptr_type;
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

struct IrInstructionErrorUnionFieldErrorSet {
    IrInstruction base;

    IrInstruction *ptr;
};

struct IrInstructionUnwrapErrPayload {
    IrInstruction base;

    IrInstruction *value;
    bool safety_check_on;
};

struct IrInstructionOptionalWrap {
    IrInstruction base;

    IrInstruction *value;
    IrInstruction *result_loc;
};

struct IrInstructionErrWrapPayload {
    IrInstruction base;

    IrInstruction *value;
    IrInstruction *result_loc;
};

struct IrInstructionErrWrapCode {
    IrInstruction base;

    IrInstruction *value;
    IrInstruction *result_loc;
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

struct IrInstructionPtrCastSrc {
    IrInstruction base;

    IrInstruction *dest_type;
    IrInstruction *ptr;
};

struct IrInstructionPtrCastGen {
    IrInstruction base;

    IrInstruction *ptr;

    // This instruction supports being created with the child
    // type of the pointer being "infer" which means that a later
    // instruction will replace this one.
    // so we have a reference here to the pass-1 instruction so that
    // the child pointer can be updated to the new pass-2 instruction.
    IrInstructionResultPtrCast *pass1_parent;
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

enum LVal {
    LValNone,
    LValPtr,
    LValErrorUnion,
    LValOptional,
};

struct IrInstructionDeclRef {
    IrInstruction base;

    Tld *tld;
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

struct IrInstructionByteOffsetOf {
    IrInstruction base;

    IrInstruction *type_value;
    IrInstruction *field_name;
};

struct IrInstructionBitOffsetOf {
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

struct IrInstructionCheckRuntimeScope {
    IrInstruction base;

    IrInstruction *scope_is_comptime;
    IrInstruction *is_comptime;
};

struct IrInstructionResultErrorUnionPayload {
    IrInstruction base;

    IrInstruction *prev_result_loc;
};

struct IrInstructionResultErrorUnionCode {
    IrInstruction base;

    IrInstruction *prev_result_loc;
};

struct IrInstructionResultOptionalPayload {
    IrInstruction base;

    IrInstruction *prev_result_loc;
    IrInstruction *payload_type;
    bool make_non_null;
};

struct IrInstructionResultBytesToSlice {
    IrInstruction base;

    IrInstruction *prev_result_loc;
};

struct IrInstructionResultSliceToBytes {
    IrInstruction base;

    IrInstruction *elem_type;
    IrInstruction *prev_result_loc;
};

struct IrInstructionResultSlicePtr {
    IrInstruction base;

    IrInstruction *prev_result_loc;
    uint64_t len;
};

struct IrInstructionResultReturn {
    IrInstruction base;
};

struct IrInstructionResultPtrCast {
    IrInstruction base;

    IrInstruction *elem_type;
    IrInstruction *prev_result_loc;
};

struct IrInstructionResultCast {
    IrInstruction base;

    IrInstruction *elem_type;
    IrInstruction *prev_result_loc;
};

struct IrInstructionAllocaSrc {
    IrInstruction base;

    IrInstruction *child_type;
    IrInstruction *align;
    const char *name_hint;
};

struct IrInstructionAllocaGen {
    IrInstruction base;

    uint32_t align;
    const char *name_hint;
};

struct IrInstructionAssertNonError {
    IrInstruction base;

    IrInstruction *err_code;
};

// This is the safety check when using `.?`.
struct IrInstructionAssertNonNull {
    IrInstruction base;

    IrInstruction *is_non_null;
};

struct IrInstructionFirstArgResultLoc {
    IrInstruction base;

    IrInstruction *prev_result_loc;
    IrInstruction *fn_ref;
};

struct IrInstructionInferArrayType {
    IrInstruction base;

    IrInstruction *src_type;
    size_t elem_count;
};

struct IrInstructionInferCompTime {
    IrInstruction base;

    IrInstruction *prev_result_loc;
    IrInstruction *new_result_loc;
};

struct IrInstructionSetNonNullBit {
    IrInstruction base;

    IrInstruction *prev_result_loc;
    IrInstruction *non_null_bit;
    IrInstruction *new_result_loc;
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
#define ATOMIC_STATE_FIELD_NAME "atomic_state"
// these point to data belonging to the awaiter
#define ERR_RET_TRACE_PTR_FIELD_NAME "err_ret_trace_ptr"
#define RESULT_PTR_FIELD_NAME "result_ptr"


enum FloatMode {
    FloatModeStrict,
    FloatModeOptimized,
};

enum FnWalkId {
    FnWalkIdAttrs,
    FnWalkIdCall,
    FnWalkIdTypes,
    FnWalkIdVars,
    FnWalkIdInits,
};

struct FnWalkAttrs {
    ZigFn *fn;
    unsigned gen_i;
};

struct FnWalkCall {
    ZigList<LLVMValueRef> *gen_param_values;
    IrInstructionCall *inst;
    bool is_var_args;
};

struct FnWalkTypes {
    ZigList<ZigLLVMDIType *> *param_di_types;
    ZigList<LLVMTypeRef> *gen_param_types;
};

struct FnWalkVars {
    ImportTableEntry *import;
    LLVMValueRef llvm_fn;
    ZigFn *fn;
    ZigVar *var;
    unsigned gen_i;
};

struct FnWalkInits {
    LLVMValueRef llvm_fn;
    ZigFn *fn;
    unsigned gen_i;
};

struct FnWalk {
    FnWalkId id;
    union {
        FnWalkAttrs attrs;
        FnWalkCall call;
        FnWalkTypes types;
        FnWalkVars vars;
        FnWalkInits inits;
    } data;
};

#endif
