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
struct ZigFn;
struct Scope;
struct ScopeBlock;
struct ScopeFnDef;
struct ScopeExpr;
struct ZigType;
struct ZigVar;
struct ErrorTableEntry;
struct BuiltinFnEntry;
struct TypeStructField;
struct CodeGen;
struct ZigValue;
struct Stage1ZirInst;
struct Stage1AirInst;
struct Stage1AirInstCast;
struct Stage1AirInstAlloca;
struct Stage1AirInstCall;
struct Stage1AirInstAwait;
struct Stage1ZirBasicBlock;
struct Stage1AirBasicBlock;
struct ScopeDecls;
struct ZigWindowsSDK;
struct Tld;
struct TldExport;
struct IrAnalyze;
struct ResultLoc;
struct ResultLocPeer;
struct ResultLocPeerParent;
struct ResultLocBitCast;
struct ResultLocCast;
struct ResultLocReturn;
struct Stage1Air;

enum FileExt {
    FileExtUnknown,
    FileExtAsm,
    FileExtC,
    FileExtCpp,
    FileExtHeader,
    FileExtLLVMIr,
    FileExtLLVMBitCode,
};

enum PtrLen {
    PtrLenUnknown,
    PtrLenSingle,
    PtrLenC,
};

enum CallingConvention {
    CallingConventionUnspecified,
    CallingConventionC,
    CallingConventionNaked,
    CallingConventionAsync,
    CallingConventionInline,
    CallingConventionInterrupt,
    CallingConventionSignal,
    CallingConventionStdcall,
    CallingConventionFastcall,
    CallingConventionVectorcall,
    CallingConventionThiscall,
    CallingConventionAPCS,
    CallingConventionAAPCS,
    CallingConventionAAPCSVFP,
    CallingConventionSysV
};

// This one corresponds to the builtin.zig enum.
enum BuiltinPtrSize {
    BuiltinPtrSizeOne,
    BuiltinPtrSizeMany,
    BuiltinPtrSizeSlice,
    BuiltinPtrSizeC,
};

enum UndefAllowed {
    UndefOk,
    UndefBad,
    LazyOkNoUndef,
    LazyOk,
};

enum X64CABIClass {
    X64CABIClass_Unknown,
    X64CABIClass_MEMORY,
    X64CABIClass_MEMORY_nobyval,
    X64CABIClass_INTEGER,
    X64CABIClass_SSE,
};

struct Stage1Zir {
    ZigList<Stage1ZirBasicBlock *> basic_block_list;
    Buf *name;
    ZigFn *name_fn;
    Scope *begin_scope;
    ErrorMsg *first_err_trace_msg;
    ZigList<Tld *> tld_list;

    bool is_inline;
    bool need_err_code_spill;
};

struct Stage1Air {
    ZigList<Stage1AirBasicBlock *> basic_block_list;
    Buf *name;
    ZigFn *name_fn;
    size_t mem_slot_count;
    size_t next_debug_id;
    Buf *c_import_buf;
    AstNode *source_node;
    Stage1Air *parent_exec;
    Stage1Zir *source_exec;
    Scope *begin_scope;
    ErrorMsg *first_err_trace_msg;
    ZigList<Tld *> tld_list;

    bool is_inline;
    bool need_err_code_spill;

    // This is a function for use in the debugger to print
    // the source location.
    void src();
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
    ConstParentIdOptionalPayload,
    ConstParentIdArray,
    ConstParentIdUnion,
    ConstParentIdScalar,
};

struct ConstParent {
    ConstParentId id;

    union {
        struct {
            ZigValue *array_val;
            size_t elem_index;
        } p_array;
        struct {
            ZigValue *struct_val;
            size_t field_index;
        } p_struct;
        struct {
            ZigValue *err_union_val;
        } p_err_union_code;
        struct {
            ZigValue *err_union_val;
        } p_err_union_payload;
        struct {
            ZigValue *optional_val;
        } p_optional_payload;
        struct {
            ZigValue *union_val;
        } p_union;
        struct {
            ZigValue *scalar_val;
        } p_scalar;
    } data;
};

struct ConstStructValue {
    ZigValue **fields;
};

struct ConstUnionValue {
    BigInt tag;
    ZigValue *payload;
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
            ZigValue *elements;
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
    // Not to be confused with ConstPtrSpecialSubArray.
    ConstPtrSpecialBaseArray,
    // The pointer points to a field in an underlying struct.
    ConstPtrSpecialBaseStruct,
    // The pointer points to the error set field of an error union
    ConstPtrSpecialBaseErrorUnionCode,
    // The pointer points to the payload field of an error union
    ConstPtrSpecialBaseErrorUnionPayload,
    // The pointer points to the payload field of an optional
    ConstPtrSpecialBaseOptionalPayload,
    // This means that we did a compile-time pointer reinterpret and we cannot
    // understand the value of pointee at compile time. However, we will still
    // emit a binary with a compile time known address.
    // In this case index is the numeric address value.
    ConstPtrSpecialHardCodedAddr,
    // This means that the pointer represents memory of assigning to _.
    // That is, storing discards the data, and loading is invalid.
    ConstPtrSpecialDiscard,
    // This is actually a function.
    ConstPtrSpecialFunction,
    // This means the pointer is null. This is only allowed when the type is ?*T.
    // We use this instead of ConstPtrSpecialHardCodedAddr because often we check
    // for that value to avoid doing comptime work.
    // We need the data layout for ConstCastOnly == true
    // types to be the same, so all optionals of pointer types use x_ptr
    // instead of x_optional.
    ConstPtrSpecialNull,
    // The pointer points to a sub-array (not an individual element).
    // Not to be confused with ConstPtrSpecialBaseArray. However, it uses the same
    // union payload struct (base_array).
    ConstPtrSpecialSubArray,
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
            ZigValue *pointee;
        } ref;
        struct {
            ZigValue *array_val;
            size_t elem_index;
        } base_array;
        struct {
            ZigValue *struct_val;
            size_t field_index;
        } base_struct;
        struct {
            ZigValue *err_union_val;
        } base_err_union_code;
        struct {
            ZigValue *err_union_val;
        } base_err_union_payload;
        struct {
            ZigValue *optional_val;
        } base_optional_payload;
        struct {
            uint64_t addr;
        } hard_coded_addr;
        struct {
            ZigFn *fn_entry;
        } fn;
    } data;
};

struct ConstErrValue {
    ZigValue *error_set;
    ZigValue *payload;
};

struct ConstBoundFnValue {
    ZigFn *fn;
    Stage1AirInst *first_arg;
    AstNode *first_arg_src;
};

struct ConstArgTuple {
    size_t start_index;
    size_t end_index;
};

enum ConstValSpecial {
    // The value is only available at runtime. However there may be runtime hints
    // narrowing the possible values down via the `data.rh_*` fields.
    ConstValSpecialRuntime,
    // The value is comptime-known and resolved. The `data.x_*` fields can be
    // accessed.
    ConstValSpecialStatic,
    // The value is comptime-known to be `undefined`.
    ConstValSpecialUndef,
    // The value is comptime-known, but not yet resolved. The lazy value system
    // helps avoid dependency loops by providing answers to certain questions
    // about values without forcing them to be resolved. For example, the
    // equation `@sizeOf(Foo) == 0` can be resolved without forcing the struct
    // layout of `Foo` because we can know whether `Foo` is zero bits without
    // performing field layout.
    // A `ZigValue` can be converted from Lazy to Static/Undef by calling the
    // appropriate resolve function.
    ConstValSpecialLazy,
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

enum LazyValueId {
    LazyValueIdInvalid,
    LazyValueIdAlignOf,
    LazyValueIdSizeOf,
    LazyValueIdPtrType,
    LazyValueIdPtrTypeSimple,
    LazyValueIdPtrTypeSimpleConst,
    LazyValueIdOptType,
    LazyValueIdSliceType,
    LazyValueIdFnType,
    LazyValueIdErrUnionType,
    LazyValueIdArrayType,
    LazyValueIdTypeInfoDecls,
};

struct LazyValue {
    LazyValueId id;
};

struct LazyValueTypeInfoDecls {
    LazyValue base;

    IrAnalyze *ira;

    ScopeDecls *decls_scope;
    AstNode *source_node;
};

struct LazyValueAlignOf {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *target_type;
};

struct LazyValueSizeOf {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *target_type;

    bool bit_size;
};

struct LazyValueSliceType {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *sentinel; // can be null
    Stage1AirInst *elem_type;
    Stage1AirInst *align_inst; // can be null

    bool is_const;
    bool is_volatile;
    bool is_allowzero;
};

struct LazyValueArrayType {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *sentinel; // can be null
    Stage1AirInst *elem_type;
    uint64_t length;
};

struct LazyValuePtrType {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *sentinel; // can be null
    Stage1AirInst *elem_type;
    Stage1AirInst *align_inst; // can be null

    PtrLen ptr_len;
    uint32_t bit_offset_in_host;

    uint32_t host_int_bytes;
    bool is_const;
    bool is_volatile;
    bool is_allowzero;
};

struct LazyValuePtrTypeSimple {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *elem_type;
};

struct LazyValueOptType {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *payload_type;
};

struct LazyValueFnType {
    LazyValue base;

    IrAnalyze *ira;
    AstNode *proto_node;
    Stage1AirInst **param_types;
    Stage1AirInst *align_inst; // can be null
    Stage1AirInst *return_type;

    CallingConvention cc;
    bool is_generic;
};

struct LazyValueErrUnionType {
    LazyValue base;

    IrAnalyze *ira;
    Stage1AirInst *err_set_type;
    Stage1AirInst *payload_type;
    Buf *type_name;
};

struct ZigValue {
    ZigType *type;
    // This field determines how the value is stored. It must be checked
    // before accessing the `data` union.
    ConstValSpecial special;
    uint32_t llvm_align;
    ConstParent parent;
    LLVMValueRef llvm_value;
    LLVMValueRef llvm_global;

    union {
        // populated if special == ConstValSpecialLazy
        LazyValue *x_lazy;

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
        ZigValue *x_optional;
        ConstErrValue x_err_union;
        ErrorTableEntry *x_err_set;
        BigInt x_enum_tag;
        ConstStructValue x_struct;
        ConstUnionValue x_union;
        ConstArrayValue x_array;
        ConstPtrValue x_ptr;
        ConstArgTuple x_arg_tuple;
        Buf *x_enum_literal;

        // populated if special == ConstValSpecialRuntime
        RuntimeHintErrorUnion rh_error_union;
        RuntimeHintOptional rh_maybe;
        RuntimeHintPtr rh_ptr;
        RuntimeHintSlice rh_slice;
    } data;

    // uncomment this to find bugs. can't leave it uncommented because of a gcc-9 warning
    //ZigValue& operator= (const ZigValue &other) = delete; // use copy_const_val

    ZigValue(const ZigValue &other) = delete; // plz zero initialize with ZigValue val = {};

    // for use in debuggers
    void dump();
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
    TldIdUsingNamespace,
};

enum TldResolution {
    TldResolutionUnresolved,
    TldResolutionResolving,
    TldResolutionInvalid,
    TldResolutionOkLazy,
    TldResolutionOk,
};

struct Tld {
    TldId id;
    Buf *name;
    VisibMod visib_mod;
    AstNode *source_node;

    ZigType *import;
    Scope *parent_scope;
    TldResolution resolution;
};

struct TldVar {
    Tld base;

    ZigVar *var;
    Buf *extern_lib_name;
    bool analyzing_type; // flag to detect dependency loops
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

struct TldUsingNamespace {
    Tld base;

    ZigValue *using_namespace_value;
};

struct TypeEnumField {
    Buf *name;
    BigInt value;
    uint32_t decl_index;
    AstNode *decl_node;
};

struct TypeUnionField {
    Buf *name;
    ZigType *type_entry; // available after ResolveStatusSizeKnown
    ZigValue *type_val; // available after ResolveStatusZeroBitsKnown
    TypeEnumField *enum_field;
    AstNode *decl_node;
    uint32_t gen_index;
    uint32_t align;
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
    NodeTypeCatchExpr,
    NodeTypeFloatLiteral,
    NodeTypeIntLiteral,
    NodeTypeStringLiteral,
    NodeTypeCharLiteral,
    NodeTypeIdentifier,
    NodeTypePrefixOpExpr,
    NodeTypePointerType,
    NodeTypeFnCallExpr,
    NodeTypeArrayAccessExpr,
    NodeTypeSliceExpr,
    NodeTypeFieldAccessExpr,
    NodeTypePtrDeref,
    NodeTypeUnwrapOptional,
    NodeTypeUsingNamespace,
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
    NodeTypeNoSuspend,
    NodeTypeBreak,
    NodeTypeContinue,
    NodeTypeAsmExpr,
    NodeTypeContainerDecl,
    NodeTypeStructField,
    NodeTypeContainerInitExpr,
    NodeTypeStructValueField,
    NodeTypeArrayType,
    NodeTypeInferredArrayType,
    NodeTypeErrorType,
    NodeTypeIfErrorExpr,
    NodeTypeIfOptional,
    NodeTypeErrorSetDecl,
    NodeTypeErrorSetField,
    NodeTypeResume,
    NodeTypeAwaitExpr,
    NodeTypeSuspend,
    NodeTypeAnyFrameType,
    // main_token points to the identifier.
    NodeTypeEnumLiteral,
    NodeTypeAnyTypeField,
};

enum FnInline {
    FnInlineAuto,
    FnInlineAlways,
    FnInlineNever,
};

struct AstNodeFnProto {
    Buf *name;
    ZigList<AstNode *> params;
    AstNode *return_type;
    AstNode *fn_def_node;
    // populated if this is an extern declaration
    Buf *lib_name;
    // populated if the "align A" is present
    AstNode *align_expr;
    // populated if the "section(S)" is present
    AstNode *section_expr;
    // populated if the "callconv(S)" is present
    AstNode *callconv_expr;

    TokenIndex doc_comments;

    // This is set based only on the existence of a noinline or inline keyword.
    // This is then resolved to an is_noinline bool and (potentially .Inline)
    // calling convention in resolve_decl_fn() in analyze.cpp.
    FnInline fn_inline;

    VisibMod visib_mod;
    bool auto_err_set;
    bool is_var_args;
    bool is_extern;
    bool is_export;
};

struct AstNodeFnDef {
    AstNode *fn_proto;
    AstNode *body;
};

struct AstNodeParamDecl {
    Buf *name;
    AstNode *type;
    TokenIndex doc_comments;
    TokenIndex anytype_token;
    bool is_noalias;
    bool is_comptime;
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
    AstNode *err_payload;
    AstNode *expr;

    // temporary data used in IR generation
    Scope *child_scope;
    Scope *expr_scope;
};

struct AstNodeVariableDeclaration {
    Buf *symbol;
    // one or both of type and expr will be non null
    AstNode *type;
    AstNode *expr;
    // populated if this is an extern declaration
    Buf *lib_name;
    // populated if the "align(A)" is present
    AstNode *align_expr;
    // populated if the "section(S)" is present
    AstNode *section_expr;
    TokenIndex doc_comments;

    TokenIndex threadlocal_tok;
    VisibMod visib_mod;
    bool is_const;
    bool is_comptime;
    bool is_export;
    bool is_extern;
};

struct AstNodeTestDecl {
    // nullptr if the test declaration has no name
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

// Must be synchronized with std.builtin.CallOptions.Modifier
enum CallModifier {
    CallModifierNone,
    CallModifierAsync,
    CallModifierNeverTail,
    CallModifierNeverInline,
    CallModifierNoSuspend,
    CallModifierAlwaysTail,
    CallModifierAlwaysInline,
    CallModifierCompileTime,

    // These are additional tags in the compiler, but not exposed in the std lib.
    CallModifierBuiltin,
};

struct AstNodeFnCallExpr {
    AstNode *fn_ref_expr;
    ZigList<AstNode *> params;
    CallModifier modifier;
    bool seen; // used by @compileLog
};

struct AstNodeArrayAccessExpr {
    AstNode *array_ref_expr;
    AstNode *subscript;
};

struct AstNodeSliceExpr {
    AstNode *array_ref_expr;
    AstNode *start;
    AstNode *end;
    AstNode *sentinel; // can be null
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
    TokenIndex star_token;
    TokenIndex allow_zero_token;
    TokenIndex bit_offset_start;
    TokenIndex host_int_bytes;

    AstNode *sentinel;
    AstNode *align_expr;
    AstNode *op_expr;
    bool is_const;
    bool is_volatile;
};

struct AstNodeInferredArrayType {
    AstNode *sentinel; // can be null
    AstNode *child_type;
};

struct AstNodeArrayType {
    AstNode *size;
    AstNode *sentinel;
    AstNode *child_type;
    AstNode *align_expr;
    TokenIndex allow_zero_token;
    bool is_const;
    bool is_volatile;
};

struct AstNodeUsingNamespace {
    VisibMod visib_mod;
    AstNode *expr;
};

struct AstNodeIfBoolExpr {
    AstNode *condition;
    AstNode *then_block;
    AstNode *else_node; // null, block node, or other if expr node
};

struct AstNodeTryExpr {
    Buf *var_symbol;
    AstNode *target_node;
    AstNode *then_node;
    AstNode *else_node;
    Buf *err_symbol;
    bool var_is_ptr;
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
    AstNode *continue_expr;
    AstNode *body;
    AstNode *else_node;
    Buf *err_symbol;
    bool is_inline;
    bool var_is_ptr;
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

struct AstNodeNoSuspend {
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
    TokenIndex volatile_token;
    AstNode *asm_template;
    ZigList<AsmOutput*> output_list;
    ZigList<AsmInput*> input_list;
    ZigList<Buf*> clobber_list;
};

enum ContainerKind {
    ContainerKindStruct,
    ContainerKindEnum,
    ContainerKindUnion,
    ContainerKindOpaque,
};

enum ContainerLayout {
    ContainerLayoutAuto,
    ContainerLayoutExtern,
    ContainerLayoutPacked,
};

struct AstNodeContainerDecl {
    AstNode *init_arg_expr; // enum(T), struct(endianness), or union(T), or union(enum(T))
    ZigList<AstNode *> fields;
    ZigList<AstNode *> decls;
    TokenIndex doc_comments;

    ContainerKind kind;
    ContainerLayout layout;

    bool auto_enum, is_root; // union(enum)
};

struct AstNodeErrorSetField {
    TokenIndex doc_comments;
    AstNode *field_name;
};

struct AstNodeErrorSetDecl {
    // Each AstNode could be AstNodeErrorSetField or just AstNodeSymbolExpr to save memory
    ZigList<AstNode *> decls;
};

struct AstNodeStructField {
    Buf *name;
    AstNode *type;
    AstNode *value;
    // populated if the "align(A)" is present
    AstNode *align_expr;
    TokenIndex doc_comments;
    TokenIndex comptime_token;
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

struct AstNodeIdentifier {
    Buf *name;
};

struct AstNodeEnumLiteral {
    Buf *name;
};

struct AstNodeBoolLiteral {
    bool value;
};

struct AstNodeBreakExpr {
    Buf *name;
    AstNode *expr; // may be null
};

struct AstNodeResumeExpr {
    AstNode *expr;
};

struct AstNodeContinueExpr {
    Buf *name;
};

struct AstNodeAwaitExpr {
    AstNode *expr;
};

struct AstNodeSuspend {
    AstNode *block;
};

struct AstNodeAnyFrameType {
    AstNode *payload_type; // can be NULL
};

struct AstNode {
    enum NodeType type;
    TokenIndex main_token;
    bool already_traced_this_node;
    ZigType *owner;
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
        AstNodeUsingNamespace using_namespace;
        AstNodeIfBoolExpr if_bool_expr;
        AstNodeTryExpr if_err_expr;
        AstNodeTestExpr test_expr;
        AstNodeWhileExpr while_expr;
        AstNodeForExpr for_expr;
        AstNodeSwitchExpr switch_expr;
        AstNodeSwitchProng switch_prong;
        AstNodeSwitchRange switch_range;
        AstNodeCompTime comptime_expr;
        AstNodeNoSuspend nosuspend_expr;
        AstNodeAsmExpr asm_expr;
        AstNodeFieldAccessExpr field_access_expr;
        AstNodePtrDerefExpr ptr_deref_expr;
        AstNodeContainerDecl container_decl;
        AstNodeStructField struct_field;
        AstNodeContainerInitExpr container_init_expr;
        AstNodeStructValueField struct_val_field;
        AstNodeBoolLiteral bool_literal;
        AstNodeBreakExpr break_expr;
        AstNodeContinueExpr continue_expr;
        AstNodeArrayType array_type;
        AstNodeInferredArrayType inferred_array_type;
        AstNodeErrorSetDecl err_set_decl;
        AstNodeErrorSetField err_set_field;
        AstNodeResumeExpr resume_expr;
        AstNodeAwaitExpr await_expr;
        AstNodeSuspend suspend;
        AstNodeAnyFrameType anyframe_type;

        // These are part of an astgen workaround to use less memory by
        // memoizing into the AST. Once astgen is modified to only run once
        // per corresponding source, this workaround can be removed.
        AstNodeIdentifier identifier;
        AstNodeEnumLiteral enum_literal;
    } data;

    // This is a function for use in the debugger to print
    // the source location.
    void src();
};

// this struct is allocated with allocate_nonzero
struct FnTypeParamInfo {
    bool is_noalias;
    ZigType *type;
};

struct GenericFnTypeId {
    CodeGen *codegen;
    ZigFn *fn_entry;
    ZigValue *params;
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
};

uint32_t fn_type_id_hash(FnTypeId*);
bool fn_type_id_eql(FnTypeId *a, FnTypeId *b);

static const uint32_t VECTOR_INDEX_NONE = UINT32_MAX;
static const uint32_t VECTOR_INDEX_RUNTIME = UINT32_MAX - 1;

struct InferredStructField {
    ZigType *inferred_struct_type;
    Buf *field_name;
    bool already_resolved;
};

struct ZigTypePointer {
    ZigType *child_type;
    ZigType *slice_parent;

    // Anonymous struct literal syntax uses this when the result location has
    // no type in it. This field is null if this pointer does not refer to
    // a field of a currently-being-inferred struct type.
    // When this is non-null, the pointer is pointing to the base of the inferred
    // struct.
    InferredStructField *inferred_struct_field;

    // This can be null. If it is non-null, it means the pointer is terminated by this
    // sentinel value. This is most commonly used for C-style strings, with a 0 byte
    // to specify the length of the memory pointed to.
    ZigValue *sentinel;

    PtrLen ptr_len;
    uint32_t explicit_alignment; // 0 means use ABI alignment

    uint32_t bit_offset_in_host;
    // size of host integer. 0 means no host integer; this field is aligned
    // when vector_index != VECTOR_INDEX_NONE this is the len of the containing vector
    uint32_t host_int_bytes;

    uint32_t vector_index; // see the VECTOR_INDEX_* constants
    bool is_const;
    bool is_volatile;
    bool allow_zero;
    bool resolve_loop_flag_zero_bits;
};

struct ZigTypeInt {
    uint32_t bit_count;
    bool is_signed;
};

struct ZigTypeFloat {
    size_t bit_count;
};

// Needs to have the same memory layout as ZigTypeVector
struct ZigTypeArray {
    ZigType *child_type;
    uint64_t len;
    ZigValue *sentinel;
};

struct TypeStructField {
    Buf *name;
    ZigType *type_entry; // available after ResolveStatusSizeKnown
    ZigValue *type_val; // available after ResolveStatusZeroBitsKnown
    size_t src_index;
    size_t gen_index;
    size_t offset; // byte offset from beginning of struct
    AstNode *decl_node;
    ZigValue *init_val; // null and then memoized
    uint32_t bit_offset_in_host; // offset from the memory at gen_index
    uint32_t host_int_bytes; // size of host integer
    uint32_t align;
    bool is_comptime;
};

enum ResolveStatus {
    ResolveStatusUnstarted,
    ResolveStatusInvalid,
    ResolveStatusBeingInferred,
    ResolveStatusZeroBitsKnown,
    ResolveStatusAlignmentKnown,
    ResolveStatusSizeKnown,
    ResolveStatusLLVMFwdDecl,
    ResolveStatusLLVMFull,
};

struct ZigPackage {
    Buf root_src_dir;
    Buf root_src_path; // relative to root_src_dir
    Buf pkg_path; // a.b.c.d which follows the package dependency chain from the root package

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, ZigPackage *, buf_hash, buf_eql_buf> package_table;

    bool added_to_cache;
};

// Stuff that only applies to a struct which is the implicit root struct of a file
struct RootStruct {
    ZigPackage *package;
    Buf *path; // relative to root_package->root_src_dir
    Buf *source_code;
    ZigLLVMDIFile *di_file;
    size_t token_count;
    TokenId *token_ids;
    TokenLoc *token_locs;
};

enum StructSpecial {
    StructSpecialNone,
    StructSpecialSlice,
    StructSpecialInferredTuple,
    StructSpecialInferredStruct,
};

struct ZigTypeStruct {
    AstNode *decl_node;
    TypeStructField **fields;
    ScopeDecls *decls_scope;
    HashMap<Buf *, TypeStructField *, buf_hash, buf_eql_buf> fields_by_name;
    RootStruct *root_struct;
    uint32_t *host_int_bytes; // available for packed structs, indexed by gen_index
    size_t llvm_full_type_queue_index;

    uint32_t src_field_count;
    uint32_t gen_field_count;

    ContainerLayout layout;
    ResolveStatus resolve_status;

    StructSpecial special;
    // whether any of the fields require comptime
    // known after ResolveStatusZeroBitsKnown
    bool requires_comptime;
    bool resolve_loop_flag_zero_bits;
    bool resolve_loop_flag_other;
    bool created_by_at_type;
};

struct ZigTypeOptional {
    ZigType *child_type;
    ResolveStatus resolve_status;
};

struct ZigTypeErrorUnion {
    ZigType *err_set_type;
    ZigType *payload_type;
    size_t pad_bytes;
    LLVMTypeRef pad_llvm_type;
};

struct ZigTypeErrorSet {
    ErrorTableEntry **errors;
    ZigFn *infer_fn;
    uint32_t err_count;
    bool incomplete;
};

struct ZigTypeEnum {
    AstNode *decl_node;
    TypeEnumField *fields;
    ZigType *tag_int_type;

    ScopeDecls *decls_scope;

    LLVMValueRef name_function;

    HashMap<Buf *, TypeEnumField *, buf_hash, buf_eql_buf> fields_by_name;
    uint32_t src_field_count;

    ContainerLayout layout;
    ResolveStatus resolve_status;

    bool has_explicit_tag_type;
    bool non_exhaustive;
    bool resolve_loop_flag;
};

uint32_t type_ptr_hash(const ZigType *ptr);
bool type_ptr_eql(const ZigType *a, const ZigType *b);

uint32_t pkg_ptr_hash(const ZigPackage *ptr);
bool pkg_ptr_eql(const ZigPackage *a, const ZigPackage *b);

uint32_t tld_ptr_hash(const Tld *ptr);
bool tld_ptr_eql(const Tld *a, const Tld *b);

uint32_t node_ptr_hash(const AstNode *ptr);
bool node_ptr_eql(const AstNode *a, const AstNode *b);

uint32_t fn_ptr_hash(const ZigFn *ptr);
bool fn_ptr_eql(const ZigFn *a, const ZigFn *b);

uint32_t err_ptr_hash(const ErrorTableEntry *ptr);
bool err_ptr_eql(const ErrorTableEntry *a, const ErrorTableEntry *b);

struct ZigTypeUnion {
    AstNode *decl_node;
    TypeUnionField *fields;
    ScopeDecls *decls_scope;
    HashMap<Buf *, TypeUnionField *, buf_hash, buf_eql_buf> fields_by_name;
    ZigType *tag_type; // always an enum or null
    LLVMTypeRef union_llvm_type;
    TypeUnionField *most_aligned_union_member;
    size_t gen_union_index;
    size_t gen_tag_index;
    size_t union_abi_size;

    uint32_t src_field_count;
    uint32_t gen_field_count;

    ContainerLayout layout;
    ResolveStatus resolve_status;

    bool have_explicit_tag_type;
    // whether any of the fields require comptime
    // the value is not valid until zero_bits_known == true
    bool requires_comptime;
    bool resolve_loop_flag_zero_bits;
    bool resolve_loop_flag_other;
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
    ZigLLVMDIType *raw_di_type;

    ZigType *bound_fn_parent;
};

struct ZigTypeBoundFn {
    ZigType *fn_type;
};

// Needs to have the same memory layout as ZigTypeArray
struct ZigTypeVector {
    // The type must be a pointer, integer, bool, or float
    ZigType *elem_type;
    uint64_t len;
    size_t padding;
};

// A lot of code is relying on ZigTypeArray and ZigTypeVector having the same layout/size
static_assert(sizeof(ZigTypeVector) == sizeof(ZigTypeArray), "Size of ZigTypeVector and ZigTypeArray do not match!");

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
    ZigTypeIdBoundFn,
    ZigTypeIdOpaque,
    ZigTypeIdFnFrame,
    ZigTypeIdAnyFrame,
    ZigTypeIdVector,
    ZigTypeIdEnumLiteral,
};

enum OnePossibleValue {
    OnePossibleValueInvalid,
    OnePossibleValueNo,
    OnePossibleValueYes,
};

struct ZigTypeOpaque {
    AstNode *decl_node;
    Buf *bare_name;

    ScopeDecls *decls_scope;
};

struct ZigTypeFnFrame {
    ZigFn *fn;
    ZigType *locals_struct;

    // This is set to the type that resolving the frame currently depends on, null if none.
    // It's for generating a helpful error message.
    ZigType *resolve_loop_type;
    AstNode *resolve_loop_src_node;
    bool reported_loop_err;
};

struct ZigTypeAnyFrame {
    ZigType *result_type; // null if `anyframe` instead of `anyframe->T`
};

struct ZigType {
    ZigTypeId id;
    Buf name;

    // These are not supposed to be accessed directly. They're
    // null during semantic analysis, memoized with get_llvm_type
    // and get_llvm_di_type
    LLVMTypeRef llvm_type;
    ZigLLVMDIType *llvm_di_type;

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
        ZigTypeVector vector;
        ZigTypeOpaque opaque;
        ZigTypeFnFrame frame;
        ZigTypeAnyFrame any_frame;
    } data;

    // use these fields to make sure we don't duplicate type table entries for the same type
    ZigType *pointer_parent[2]; // [0 - mut, 1 - const]
    ZigType *optional_parent;
    ZigType *any_frame_parent;
    // If we generate a constant name value for this type, we memoize it here.
    // The type of this is array
    ZigValue *cached_const_name_val;

    OnePossibleValue one_possible_value;
    // Known after ResolveStatusAlignmentKnown.
    uint32_t abi_align;
    // The offset in bytes between consecutive array elements of this type. Known
    // after ResolveStatusSizeKnown.
    size_t abi_size;
    // Number of bits of information in this type. Known after ResolveStatusSizeKnown.
    size_t size_in_bits;
};

enum FnAnalState {
    FnAnalStateReady,
    FnAnalStateProbing,
    FnAnalStateComplete,
    FnAnalStateInvalid,
};

struct GlobalExport {
    Buf name;
    GlobalLinkageId linkage;
};

struct ZigFn {
    LLVMValueRef llvm_value;
    const char *llvm_name;
    AstNode *proto_node;
    AstNode *body_node;
    ScopeFnDef *fndef_scope; // parent should be the top level decls or container decls
    Scope *child_scope; // parent is scope for last parameter
    ScopeBlock *def_scope; // parent is child_scope
    Buf symbol_name;
    // This is the function type assuming the function does not suspend.
    // Note that for an async function, this can be shared with non-async functions. So the value here
    // should only be read for things in common between non-async and async function types.
    ZigType *type_entry;
    // For normal functions one could use the type_entry->raw_type_ref and type_entry->raw_di_type.
    // However for functions that suspend, those values could possibly be their non-suspending equivalents.
    // So these values should be preferred.
    LLVMTypeRef raw_type_ref;
    ZigLLVMDIType *raw_di_type;

    ZigType *frame_type;
    // in the case of normal functions this is the implicit return type
    // in the case of async functions this is the implicit return type according to the
    // zig source code, not according to zig ir
    ZigType *src_implicit_return_type;
    Stage1Zir *stage1_zir;
    Stage1Air analyzed_executable;
    size_t branch_quota;
    AstNode **param_source_nodes;
    Buf **param_names;
    Stage1AirInst *err_code_spill;
    AstNode *assumed_non_async;

    AstNode *fn_no_inline_set_node;
    AstNode *fn_static_eval_set_node;

    ZigList<Stage1AirInstAlloca *> alloca_gen_list;
    ZigList<ZigVar *> variable_list;

    Buf *section_name;
    AstNode *set_alignstack_node;

    AstNode *set_cold_node;
    const AstNode *inferred_async_node;
    ZigFn *inferred_async_fn;
    AstNode *non_async_node;

    ZigList<GlobalExport> export_list;
    ZigList<Stage1AirInstCall *> call_list;
    ZigList<Stage1AirInstAwait *> await_list;

    LLVMValueRef valgrind_client_request_array;

    FnAnalState anal_state;

    uint32_t align_bytes;
    uint32_t alignstack_value;

    bool calls_or_awaits_errorable_fn;
    bool is_cold;
    bool is_test;
    bool is_noinline;
};

uint32_t fn_table_entry_hash(ZigFn*);
bool fn_table_entry_eql(ZigFn *a, ZigFn *b);

enum BuiltinFnId {
    BuiltinFnIdInvalid,
    BuiltinFnIdMemcpy,
    BuiltinFnIdMemset,
    BuiltinFnIdSizeof,
    BuiltinFnIdAlignOf,
    BuiltinFnIdField,
    BuiltinFnIdTypeInfo,
    BuiltinFnIdType,
    BuiltinFnIdHasField,
    BuiltinFnIdTypeof,
    BuiltinFnIdAddWithOverflow,
    BuiltinFnIdSubWithOverflow,
    BuiltinFnIdMulWithOverflow,
    BuiltinFnIdShlWithOverflow,
    BuiltinFnIdMulAdd,
    BuiltinFnIdCInclude,
    BuiltinFnIdCDefine,
    BuiltinFnIdCUndef,
    BuiltinFnIdCompileErr,
    BuiltinFnIdCompileLog,
    BuiltinFnIdCtz,
    BuiltinFnIdClz,
    BuiltinFnIdPopCount,
    BuiltinFnIdBswap,
    BuiltinFnIdBitReverse,
    BuiltinFnIdImport,
    BuiltinFnIdCImport,
    BuiltinFnIdErrName,
    BuiltinFnIdBreakpoint,
    BuiltinFnIdReturnAddress,
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
    BuiltinFnIdSin,
    BuiltinFnIdCos,
    BuiltinFnIdExp,
    BuiltinFnIdExp2,
    BuiltinFnIdLog,
    BuiltinFnIdLog2,
    BuiltinFnIdLog10,
    BuiltinFnIdFabs,
    BuiltinFnIdFloor,
    BuiltinFnIdCeil,
    BuiltinFnIdTrunc,
    BuiltinFnIdNearbyInt,
    BuiltinFnIdRound,
    BuiltinFnIdTruncate,
    BuiltinFnIdIntCast,
    BuiltinFnIdFloatCast,
    BuiltinFnIdErrSetCast,
    BuiltinFnIdIntToFloat,
    BuiltinFnIdFloatToInt,
    BuiltinFnIdBoolToInt,
    BuiltinFnIdErrToInt,
    BuiltinFnIdIntToErr,
    BuiltinFnIdEnumToInt,
    BuiltinFnIdIntToEnum,
    BuiltinFnIdVectorType,
    BuiltinFnIdShuffle,
    BuiltinFnIdSplat,
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
    BuiltinFnIdFieldParentPtr,
    BuiltinFnIdOffsetOf,
    BuiltinFnIdBitOffsetOf,
    BuiltinFnIdAsyncCall,
    BuiltinFnIdShlExact,
    BuiltinFnIdShrExact,
    BuiltinFnIdSetEvalBranchQuota,
    BuiltinFnIdAlignCast,
    BuiltinFnIdThis,
    BuiltinFnIdSetAlignStack,
    BuiltinFnIdExport,
    BuiltinFnIdExtern,
    BuiltinFnIdErrorReturnTrace,
    BuiltinFnIdAtomicRmw,
    BuiltinFnIdAtomicLoad,
    BuiltinFnIdAtomicStore,
    BuiltinFnIdHasDecl,
    BuiltinFnIdUnionInit,
    BuiltinFnIdFrameAddress,
    BuiltinFnIdFrameType,
    BuiltinFnIdFrameHandle,
    BuiltinFnIdFrameSize,
    BuiltinFnIdAs,
    BuiltinFnIdCall,
    BuiltinFnIdBitSizeof,
    BuiltinFnIdWasmMemorySize,
    BuiltinFnIdWasmMemoryGrow,
    BuiltinFnIdSrc,
    BuiltinFnIdReduce,
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
    PanicMsgIdUnwrapOptionalFail,
    PanicMsgIdInvalidErrorCode,
    PanicMsgIdIncorrectAlignment,
    PanicMsgIdBadUnionField,
    PanicMsgIdBadEnumValue,
    PanicMsgIdFloatToInt,
    PanicMsgIdPtrCastNull,
    PanicMsgIdBadResume,
    PanicMsgIdBadAwait,
    PanicMsgIdBadReturn,
    PanicMsgIdResumedAnAwaitingFn,
    PanicMsgIdFrameTooSmall,
    PanicMsgIdResumedFnPendingAwait,
    PanicMsgIdBadNoSuspendCall,
    PanicMsgIdResumeNotSuspendedFn,
    PanicMsgIdBadSentinel,
    PanicMsgIdShxTooBigRhs,

    PanicMsgIdCount,
};

uint32_t fn_eval_hash(Scope*);
bool fn_eval_eql(Scope *a, Scope *b);

struct TypeId {
    ZigTypeId id;

    union {
        struct {
            CodeGen *codegen;
            ZigType *child_type;
            InferredStructField *inferred_struct_field;
            ZigValue *sentinel;
            PtrLen ptr_len;
            uint32_t alignment;

            uint32_t bit_offset_in_host;
            uint32_t host_int_bytes;

            uint32_t vector_index;
            bool is_const;
            bool is_volatile;
            bool allow_zero;
        } pointer;
        struct {
            CodeGen *codegen;
            ZigType *child_type;
            uint64_t size;
            ZigValue *sentinel;
        } array;
        struct {
            bool is_signed;
            uint32_t bit_count;
        } integer;
        struct {
            ZigType *err_set_type;
            ZigType *payload_type;
        } error_union;
        struct {
            ZigType *elem_type;
            uint32_t len;
        } vector;
    } data;
};

uint32_t type_id_hash(TypeId const *);
bool type_id_eql(TypeId const *a, TypeId const *b);

enum ZigLLVMFnId {
    ZigLLVMFnIdCtz,
    ZigLLVMFnIdClz,
    ZigLLVMFnIdPopCount,
    ZigLLVMFnIdOverflowArithmetic,
    ZigLLVMFnIdFMA,
    ZigLLVMFnIdFloatOp,
    ZigLLVMFnIdBswap,
    ZigLLVMFnIdBitReverse,
};

// There are a bunch of places in code that rely on these values being in
// exactly this order.
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
            BuiltinFnId op;
            uint32_t bit_count;
            uint32_t vector_len; // 0 means not a vector
        } floating;
        struct {
            AddSubMul add_sub_mul;
            uint32_t bit_count;
            uint32_t vector_len; // 0 means not a vector
            bool is_signed;
        } overflow_arithmetic;
        struct {
            uint32_t bit_count;
            uint32_t vector_len; // 0 means not a vector
        } bswap;
        struct {
            uint32_t bit_count;
        } bit_reverse;
    } data;
};

uint32_t zig_llvm_fn_key_hash(ZigLLVMFnKey const *);
bool zig_llvm_fn_key_eql(ZigLLVMFnKey const *a, ZigLLVMFnKey const *b);

struct TimeEvent {
    double time;
    const char *name;
};

struct CFile {
    ZigList<const char *> args;
    const char *source_path;
    const char *preprocessor_only_basename;
};

struct CodeGen {
    // Other code depends on this being first.
    ZigStage1 stage1;

    // arena allocator destroyed just prior to codegen emit
    heap::ArenaAllocator *pass1_arena;

    //////////////////////////// Runtime State
    LLVMModuleRef module;
    ZigList<ErrorMsg*> errors;
    ErrorMsg *trace_err;
    LLVMBuilderRef builder;
    ZigLLVMDIBuilder *dbuilder;
    ZigLLVMDICompileUnit *compile_unit;
    ZigLLVMDIFile *compile_unit_file;
    LLVMTargetDataRef target_data_ref;
    LLVMTargetMachineRef target_machine;
    ZigLLVMDIFile *dummy_di_file;
    LLVMValueRef cur_ret_ptr;
    LLVMValueRef cur_frame_ptr;
    LLVMValueRef cur_fn_val;
    LLVMValueRef cur_async_switch_instr;
    LLVMValueRef cur_async_resume_index_ptr;
    LLVMValueRef cur_async_awaiter_ptr;
    LLVMBasicBlockRef cur_preamble_llvm_block;
    size_t cur_resume_block_count;
    LLVMValueRef cur_err_ret_trace_val_arg;
    LLVMValueRef cur_err_ret_trace_val_stack;
    LLVMValueRef cur_bad_not_suspended_index;
    LLVMValueRef memcpy_fn_val;
    LLVMValueRef memset_fn_val;
    LLVMValueRef trap_fn_val;
    LLVMValueRef return_address_fn_val;
    LLVMValueRef frame_address_fn_val;
    LLVMValueRef add_error_return_trace_addr_fn_val;
    LLVMValueRef stacksave_fn_val;
    LLVMValueRef stackrestore_fn_val;
    LLVMValueRef write_register_fn_val;
    LLVMValueRef merge_err_ret_traces_fn_val;
    LLVMValueRef sp_md_node;
    LLVMValueRef err_name_table;
    LLVMValueRef safety_crash_err_fn;
    LLVMValueRef return_err_fn;
    LLVMValueRef wasm_memory_size;
    LLVMValueRef wasm_memory_grow;
    LLVMTypeRef anyframe_fn_type;

    // reminder: hash tables must be initialized before use
    HashMap<Buf *, ZigType *, buf_hash, buf_eql_buf> import_table;
    HashMap<Buf *, BuiltinFnEntry *, buf_hash, buf_eql_buf> builtin_fn_table;
    HashMap<Buf *, ZigType *, buf_hash, buf_eql_buf> primitive_type_table;
    HashMap<TypeId, ZigType *, type_id_hash, type_id_eql> type_table;
    HashMap<FnTypeId *, ZigType *, fn_type_id_hash, fn_type_id_eql> fn_type_table;
    HashMap<Buf *, ErrorTableEntry *, buf_hash, buf_eql_buf> error_table;
    HashMap<GenericFnTypeId *, ZigFn *, generic_fn_type_id_hash, generic_fn_type_id_eql> generic_table;
    HashMap<Scope *, ZigValue *, fn_eval_hash, fn_eval_eql> memoized_fn_eval_table;
    HashMap<ZigLLVMFnKey, LLVMValueRef, zig_llvm_fn_key_hash, zig_llvm_fn_key_eql> llvm_fn_table;
    HashMap<Buf *, Tld *, buf_hash, buf_eql_buf> exported_symbol_names;
    HashMap<Buf *, Tld *, buf_hash, buf_eql_buf> external_symbol_names;
    HashMap<Buf *, ZigValue *, buf_hash, buf_eql_buf> string_literals_table;
    HashMap<const ZigType *, ZigValue *, type_ptr_hash, type_ptr_eql> type_info_cache;
    HashMap<const ZigType *, ZigValue *, type_ptr_hash, type_ptr_eql> one_possible_values;

    ZigList<Tld *> resolve_queue;
    size_t resolve_queue_index;
    ZigList<TimeEvent> timing_events;
    ZigList<ZigFn *> inline_fns;
    ZigList<ZigFn *> test_fns;
    ZigList<ErrorTableEntry *> errors_by_index;
    size_t largest_err_name_len;
    ZigList<ZigType *> type_resolve_stack;

    ZigPackage *std_package;
    ZigPackage *test_runner_package;
    ZigPackage *compile_var_package;
    ZigPackage *root_pkg; // @import("root")
    ZigPackage *main_pkg; // usually same as root_pkg, except for `zig test`
    ZigType *compile_var_import;
    ZigType *root_import;
    ZigType *start_import;
    ZigType *std_builtin_import;

    struct {
        ZigType *entry_bool;
        ZigType *entry_c_int[CIntTypeCount];
        ZigType *entry_c_longdouble;
        ZigType *entry_c_void;
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
        ZigType *entry_block;
        ZigType *entry_num_lit_int;
        ZigType *entry_num_lit_float;
        ZigType *entry_undef;
        ZigType *entry_null;
        ZigType *entry_anytype;
        ZigType *entry_global_error_set;
        ZigType *entry_enum_literal;
        ZigType *entry_any_frame;
    } builtin_types;

    struct Intern {
        ZigValue x_undefined;
        ZigValue x_void;
        ZigValue x_null;
        ZigValue x_unreachable;
        ZigValue zero_byte;

        ZigValue *for_undefined();
        ZigValue *for_void();
        ZigValue *for_null();
        ZigValue *for_unreachable();
        ZigValue *for_zero_byte();
    } intern;

    ZigType *align_amt_type;
    ZigType *stack_trace_type;
    ZigType *err_tag_type;
    ZigType *test_fn_type;

    Buf llvm_triple_str;
    Buf global_asm;
    Buf o_file_output_path;
    Buf h_file_output_path;
    Buf asm_file_output_path;
    Buf llvm_ir_file_output_path;
    Buf analysis_json_output_path;
    Buf docs_output_path;

    Buf *builtin_zig_path;
    Buf *zig_std_special_dir; // Cannot be overridden; derived from zig_lib_dir.

    Stage1ZirInst *invalid_inst_src;
    Stage1AirInst *invalid_inst_gen;
    Stage1AirInst *unreach_instruction;

    ZigValue panic_msg_vals[PanicMsgIdCount];

    // The function definitions this module includes.
    ZigList<ZigFn *> fn_defs;
    size_t fn_defs_index;
    ZigList<TldVar *> global_vars;

    ZigFn *cur_fn;
    ZigFn *panic_fn;

    ZigFn *largest_frame_fn;

    Stage2ProgressNode *main_progress_node;
    Stage2ProgressNode *sub_progress_node;

    ErrColor err_color;
    uint32_t next_unresolved_index;
    unsigned pointer_size_bytes;
    bool is_big_endian;
    bool have_err_ret_tracing;
    bool verbose_ir;
    bool verbose_llvm_ir;
    bool verbose_cimport;
    bool verbose_llvm_cpu_features;
    bool error_during_imports;
    bool generate_error_name_table;
    bool enable_time_report;
    bool enable_stack_report;
    bool reported_bad_link_libc_error;
    bool need_frame_size_prefix_data;
    bool link_libc;
    bool link_libcpp;

    BuildMode build_mode;
    const ZigTarget *zig_target;
    TargetSubsystem subsystem; // careful using this directly; see detect_subsystem
    CodeModel code_model;
    bool strip_debug_symbols;
    bool is_test_build;
    bool is_single_threaded;
    bool have_pic;
    bool have_pie;
    bool have_lto;
    bool unwind_tables;
    bool link_mode_dynamic;
    bool dll_export_fns;
    bool have_stack_probing;
    bool red_zone;
    bool function_sections;
    bool test_is_evented;
    bool valgrind_enabled;
    bool tsan_enabled;

    Buf *root_out_name;
    Buf *test_filter;
    Buf *test_name_prefix;
    Buf *zig_lib_dir;
    Buf *zig_std_dir;
};

struct ZigVar {
    const char *name;
    ZigValue *const_value;
    ZigType *var_type;
    LLVMValueRef value_ref;
    Stage1ZirInst *is_comptime;
    Stage1AirInst *ptr_instruction;
    // which node is the declaration of the variable
    AstNode *decl_node;
    ZigLLVMDILocalVariable *di_loc_var;
    size_t src_arg_index;
    Scope *parent_scope;
    Scope *child_scope;
    LLVMValueRef param_value_ref;

    Buf *section_name;

    // In an inline loop, multiple variables may be created,
    // In this case, a reference to a variable should follow
    // this pointer to the redefined variable.
    ZigVar *next_var;

    ZigList<GlobalExport> export_list;

    uint32_t align_bytes;
    uint32_t ref_count;

    bool shadowable;
    bool src_is_const;
    bool gen_is_const;
    bool is_thread_local;
    bool is_comptime_memoized;
    bool is_comptime_memoized_value;
    bool did_the_decl_codegen;
};

struct ErrorTableEntry {
    Buf name;
    uint32_t value;
    AstNode *decl_node;
    ErrorTableEntry *other; // null, or another error decl that was merged into this
    ZigType *set_with_only_this_in_it;
    // If we generate a constant error name value for this error, we memoize it here.
    // The type of this is array
    ZigValue *cached_error_name_val;
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
    ScopeIdRuntime,
    ScopeIdTypeOf,
    ScopeIdExpr,
    ScopeIdNoSuspend,
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
    ZigList<TldUsingNamespace *> use_decls;
    AstNode *safety_set_node;
    AstNode *fast_math_set_node;
    ZigType *import;
    // If this is a scope from a container, this is the type entry, otherwise null
    ZigType *container_type;
    Buf *bare_name;

    bool safety_off;
    bool fast_math_on;
    bool any_imports_failed;
};

enum LVal {
    LValNone,
    LValPtr,
    LValAssign,
};

// This scope comes from a block expression in user code.
// NodeTypeBlock
struct ScopeBlock {
    Scope base;

    Buf *name;
    Stage1ZirBasicBlock *end_block;
    Stage1ZirInst *is_comptime;
    ResultLocPeerParent *peer_parent;
    ZigList<Stage1ZirInst *> *incoming_values;
    ZigList<Stage1ZirBasicBlock *> *incoming_blocks;

    AstNode *safety_set_node;
    AstNode *fast_math_set_node;

    LVal lval;
    bool safety_off;
    bool fast_math_on;
    bool name_used;
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

    LVal lval;
    Buf *name;
    Stage1ZirBasicBlock *break_block;
    Stage1ZirBasicBlock *continue_block;
    Stage1ZirInst *is_comptime;
    ZigList<Stage1ZirInst *> *incoming_values;
    ZigList<Stage1ZirBasicBlock *> *incoming_blocks;
    ResultLocPeerParent *peer_parent;
    ScopeExpr *spill_scope;

    bool name_used;
};

// This scope blocks certain things from working such as comptime continue
// inside a runtime if expression.
// NodeTypeIfBoolExpr, NodeTypeWhileExpr, NodeTypeForExpr
struct ScopeRuntime {
    Scope base;

    Stage1ZirInst *is_comptime;
};

// This scope is created for a suspend block in order to have labeled
// suspend for breaking out of a suspend and for detecting if a suspend
// block is inside a suspend block.
struct ScopeSuspend {
    Scope base;

    bool reported_err;
};

// This scope is created for a comptime expression.
// NodeTypeCompTime, NodeTypeSwitchExpr
struct ScopeCompTime {
    Scope base;
};

// This scope is created for a nosuspend expression.
// NodeTypeNoSuspend
struct ScopeNoSuspend {
    Scope base;
};

// This scope is created for a function definition.
// NodeTypeFnDef
struct ScopeFnDef {
    Scope base;

    ZigFn *fn_entry;
};

// This scope is created for a @TypeOf.
// All runtime side-effects are elided within it.
// NodeTypeFnCallExpr
struct ScopeTypeOf {
    Scope base;
};

enum MemoizedBool {
    MemoizedBoolUnknown,
    MemoizedBoolFalse,
    MemoizedBoolTrue,
};

// This scope is created for each expression.
// It's used to identify when an instruction needs to be spilled,
// so that it can be accessed after a suspend point.
struct ScopeExpr {
    Scope base;

    ScopeExpr **children_ptr;
    size_t children_len;

    MemoizedBool need_spill;
    // This is a hack. I apologize for this, I need this to work so that I
    // can make progress on other fronts. I'll pay off this tech debt eventually.
    bool spill_harder;
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

// synchronized with code in define_builtin_compile_vars
enum ReduceOp {
    ReduceOp_and,
    ReduceOp_or,
    ReduceOp_xor,
    ReduceOp_min,
    ReduceOp_max,
    ReduceOp_add,
    ReduceOp_mul,
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
struct Stage1ZirBasicBlock {
    ZigList<Stage1ZirInst *> instruction_list;
    Stage1AirBasicBlock *child;
    Scope *scope;
    const char *name_hint;
    Stage1ZirInst *suspend_instruction_ref;

    uint32_t ref_count;
    uint32_t index; // index into the basic block list

    uint32_t debug_id;
    bool suspended;
    bool in_resume_stack;
};

struct Stage1AirBasicBlock {
    ZigList<Stage1AirInst *> instruction_list;
    Scope *scope;
    const char *name_hint;
    LLVMBasicBlockRef llvm_block;
    LLVMBasicBlockRef llvm_exit_block;
    // The instruction that referenced this basic block and caused us to
    // analyze the basic block. If the same instruction wants us to emit
    // the same basic block, then we re-generate it instead of saving it.
    Stage1ZirInst *ref_instruction;
    // When this is non-null, a branch to this basic block is only allowed
    // if the branch is comptime. The instruction points to the reason
    // the basic block must be comptime.
    AstNode *must_be_comptime_source_node;

    uint32_t debug_id;
    bool already_appended;
};

// Src instructions are generated by ir_gen_* functions in ir.cpp from AST.
// ir_analyze_* functions consume Src instructions and produce Gen instructions.
// Src instructions do not have type information; Gen instructions do.
enum Stage1ZirInstId : uint8_t {
    Stage1ZirInstIdInvalid,
    Stage1ZirInstIdDeclVar,
    Stage1ZirInstIdBr,
    Stage1ZirInstIdCondBr,
    Stage1ZirInstIdSwitchBr,
    Stage1ZirInstIdSwitchVar,
    Stage1ZirInstIdSwitchElseVar,
    Stage1ZirInstIdSwitchTarget,
    Stage1ZirInstIdPhi,
    Stage1ZirInstIdUnOp,
    Stage1ZirInstIdBinOp,
    Stage1ZirInstIdMergeErrSets,
    Stage1ZirInstIdLoadPtr,
    Stage1ZirInstIdStorePtr,
    Stage1ZirInstIdFieldPtr,
    Stage1ZirInstIdElemPtr,
    Stage1ZirInstIdVarPtr,
    Stage1ZirInstIdCall,
    Stage1ZirInstIdCallArgs,
    Stage1ZirInstIdCallExtra,
    Stage1ZirInstIdAsyncCallExtra,
    Stage1ZirInstIdConst,
    Stage1ZirInstIdReturn,
    Stage1ZirInstIdContainerInitList,
    Stage1ZirInstIdContainerInitFields,
    Stage1ZirInstIdUnreachable,
    Stage1ZirInstIdTypeOf,
    Stage1ZirInstIdSetCold,
    Stage1ZirInstIdSetRuntimeSafety,
    Stage1ZirInstIdSetFloatMode,
    Stage1ZirInstIdArrayType,
    Stage1ZirInstIdAnyFrameType,
    Stage1ZirInstIdSliceType,
    Stage1ZirInstIdAsm,
    Stage1ZirInstIdSizeOf,
    Stage1ZirInstIdTestNonNull,
    Stage1ZirInstIdOptionalUnwrapPtr,
    Stage1ZirInstIdClz,
    Stage1ZirInstIdCtz,
    Stage1ZirInstIdPopCount,
    Stage1ZirInstIdBswap,
    Stage1ZirInstIdBitReverse,
    Stage1ZirInstIdImport,
    Stage1ZirInstIdCImport,
    Stage1ZirInstIdCInclude,
    Stage1ZirInstIdCDefine,
    Stage1ZirInstIdCUndef,
    Stage1ZirInstIdRef,
    Stage1ZirInstIdCompileErr,
    Stage1ZirInstIdCompileLog,
    Stage1ZirInstIdErrName,
    Stage1ZirInstIdEmbedFile,
    Stage1ZirInstIdCmpxchg,
    Stage1ZirInstIdFence,
    Stage1ZirInstIdReduce,
    Stage1ZirInstIdTruncate,
    Stage1ZirInstIdIntCast,
    Stage1ZirInstIdFloatCast,
    Stage1ZirInstIdIntToFloat,
    Stage1ZirInstIdFloatToInt,
    Stage1ZirInstIdBoolToInt,
    Stage1ZirInstIdVectorType,
    Stage1ZirInstIdShuffleVector,
    Stage1ZirInstIdSplat,
    Stage1ZirInstIdBoolNot,
    Stage1ZirInstIdMemset,
    Stage1ZirInstIdMemcpy,
    Stage1ZirInstIdSlice,
    Stage1ZirInstIdBreakpoint,
    Stage1ZirInstIdReturnAddress,
    Stage1ZirInstIdFrameAddress,
    Stage1ZirInstIdFrameHandle,
    Stage1ZirInstIdFrameType,
    Stage1ZirInstIdFrameSize,
    Stage1ZirInstIdAlignOf,
    Stage1ZirInstIdOverflowOp,
    Stage1ZirInstIdTestErr,
    Stage1ZirInstIdMulAdd,
    Stage1ZirInstIdFloatOp,
    Stage1ZirInstIdUnwrapErrCode,
    Stage1ZirInstIdUnwrapErrPayload,
    Stage1ZirInstIdFnProto,
    Stage1ZirInstIdTestComptime,
    Stage1ZirInstIdPtrCast,
    Stage1ZirInstIdBitCast,
    Stage1ZirInstIdIntToPtr,
    Stage1ZirInstIdPtrToInt,
    Stage1ZirInstIdIntToEnum,
    Stage1ZirInstIdEnumToInt,
    Stage1ZirInstIdIntToErr,
    Stage1ZirInstIdErrToInt,
    Stage1ZirInstIdCheckSwitchProngsUnderYes,
    Stage1ZirInstIdCheckSwitchProngsUnderNo,
    Stage1ZirInstIdCheckStatementIsVoid,
    Stage1ZirInstIdTypeName,
    Stage1ZirInstIdDeclRef,
    Stage1ZirInstIdPanic,
    Stage1ZirInstIdTagName,
    Stage1ZirInstIdFieldParentPtr,
    Stage1ZirInstIdOffsetOf,
    Stage1ZirInstIdBitOffsetOf,
    Stage1ZirInstIdTypeInfo,
    Stage1ZirInstIdType,
    Stage1ZirInstIdHasField,
    Stage1ZirInstIdSetEvalBranchQuota,
    Stage1ZirInstIdPtrType,
    Stage1ZirInstIdPtrTypeSimple,
    Stage1ZirInstIdPtrTypeSimpleConst,
    Stage1ZirInstIdAlignCast,
    Stage1ZirInstIdImplicitCast,
    Stage1ZirInstIdResolveResult,
    Stage1ZirInstIdResetResult,
    Stage1ZirInstIdSetAlignStack,
    Stage1ZirInstIdArgTypeAllowVarFalse,
    Stage1ZirInstIdArgTypeAllowVarTrue,
    Stage1ZirInstIdExport,
    Stage1ZirInstIdExtern,
    Stage1ZirInstIdErrorReturnTrace,
    Stage1ZirInstIdErrorUnion,
    Stage1ZirInstIdAtomicRmw,
    Stage1ZirInstIdAtomicLoad,
    Stage1ZirInstIdAtomicStore,
    Stage1ZirInstIdSaveErrRetAddr,
    Stage1ZirInstIdAddImplicitReturnType,
    Stage1ZirInstIdErrSetCast,
    Stage1ZirInstIdCheckRuntimeScope,
    Stage1ZirInstIdHasDecl,
    Stage1ZirInstIdUndeclaredIdent,
    Stage1ZirInstIdAlloca,
    Stage1ZirInstIdEndExpr,
    Stage1ZirInstIdUnionInitNamedField,
    Stage1ZirInstIdSuspendBegin,
    Stage1ZirInstIdSuspendFinish,
    Stage1ZirInstIdAwait,
    Stage1ZirInstIdResume,
    Stage1ZirInstIdSpillBegin,
    Stage1ZirInstIdSpillEnd,
    Stage1ZirInstIdWasmMemorySize,
    Stage1ZirInstIdWasmMemoryGrow,
    Stage1ZirInstIdSrc,
};

// ir_render_* functions in codegen.cpp consume Gen instructions and produce LLVM IR.
// Src instructions do not have type information; Gen instructions do.
enum Stage1AirInstId : uint8_t {
    Stage1AirInstIdInvalid,
    Stage1AirInstIdDeclVar,
    Stage1AirInstIdBr,
    Stage1AirInstIdCondBr,
    Stage1AirInstIdSwitchBr,
    Stage1AirInstIdPhi,
    Stage1AirInstIdBinaryNot,
    Stage1AirInstIdNegation,
    Stage1AirInstIdBinOp,
    Stage1AirInstIdLoadPtr,
    Stage1AirInstIdStorePtr,
    Stage1AirInstIdVectorStoreElem,
    Stage1AirInstIdStructFieldPtr,
    Stage1AirInstIdUnionFieldPtr,
    Stage1AirInstIdElemPtr,
    Stage1AirInstIdVarPtr,
    Stage1AirInstIdReturnPtr,
    Stage1AirInstIdCall,
    Stage1AirInstIdReturn,
    Stage1AirInstIdCast,
    Stage1AirInstIdUnreachable,
    Stage1AirInstIdAsm,
    Stage1AirInstIdTestNonNull,
    Stage1AirInstIdOptionalUnwrapPtr,
    Stage1AirInstIdOptionalWrap,
    Stage1AirInstIdUnionTag,
    Stage1AirInstIdClz,
    Stage1AirInstIdCtz,
    Stage1AirInstIdPopCount,
    Stage1AirInstIdBswap,
    Stage1AirInstIdBitReverse,
    Stage1AirInstIdRef,
    Stage1AirInstIdErrName,
    Stage1AirInstIdCmpxchg,
    Stage1AirInstIdFence,
    Stage1AirInstIdReduce,
    Stage1AirInstIdTruncate,
    Stage1AirInstIdShuffleVector,
    Stage1AirInstIdSplat,
    Stage1AirInstIdBoolNot,
    Stage1AirInstIdMemset,
    Stage1AirInstIdMemcpy,
    Stage1AirInstIdSlice,
    Stage1AirInstIdBreakpoint,
    Stage1AirInstIdReturnAddress,
    Stage1AirInstIdFrameAddress,
    Stage1AirInstIdFrameHandle,
    Stage1AirInstIdFrameSize,
    Stage1AirInstIdOverflowOp,
    Stage1AirInstIdTestErr,
    Stage1AirInstIdMulAdd,
    Stage1AirInstIdFloatOp,
    Stage1AirInstIdUnwrapErrCode,
    Stage1AirInstIdUnwrapErrPayload,
    Stage1AirInstIdErrWrapCode,
    Stage1AirInstIdErrWrapPayload,
    Stage1AirInstIdPtrCast,
    Stage1AirInstIdBitCast,
    Stage1AirInstIdWidenOrShorten,
    Stage1AirInstIdIntToPtr,
    Stage1AirInstIdPtrToInt,
    Stage1AirInstIdIntToEnum,
    Stage1AirInstIdIntToErr,
    Stage1AirInstIdErrToInt,
    Stage1AirInstIdPanic,
    Stage1AirInstIdTagName,
    Stage1AirInstIdFieldParentPtr,
    Stage1AirInstIdAlignCast,
    Stage1AirInstIdErrorReturnTrace,
    Stage1AirInstIdAtomicRmw,
    Stage1AirInstIdAtomicLoad,
    Stage1AirInstIdAtomicStore,
    Stage1AirInstIdSaveErrRetAddr,
    Stage1AirInstIdVectorToArray,
    Stage1AirInstIdArrayToVector,
    Stage1AirInstIdAssertZero,
    Stage1AirInstIdAssertNonNull,
    Stage1AirInstIdPtrOfArrayToSlice,
    Stage1AirInstIdSuspendBegin,
    Stage1AirInstIdSuspendFinish,
    Stage1AirInstIdAwait,
    Stage1AirInstIdResume,
    Stage1AirInstIdSpillBegin,
    Stage1AirInstIdSpillEnd,
    Stage1AirInstIdVectorExtractElem,
    Stage1AirInstIdAlloca,
    Stage1AirInstIdConst,
    Stage1AirInstIdWasmMemorySize,
    Stage1AirInstIdWasmMemoryGrow,
    Stage1AirInstIdExtern,
};

struct Stage1ZirInst {
    Stage1ZirInstId id;
    uint16_t ref_count;
    uint32_t debug_id;

    Scope *scope;
    AstNode *source_node;

    // When analyzing IR, instructions that point to this instruction in the "old ir"
    // can find the instruction that corresponds to this value in the "new ir"
    // with this child field.
    Stage1AirInst *child;
    Stage1ZirBasicBlock *owner_bb;

    // for debugging purposes, these are useful to call to inspect the instruction
    void dump();
    void src();
};

struct Stage1AirInst {
    Stage1AirInstId id;
    // if ref_count is zero and the instruction has no side effects,
    // the instruction can be omitted in codegen
    uint16_t ref_count;
    uint32_t debug_id;

    Scope *scope;
    AstNode *source_node;

    LLVMValueRef llvm_value;
    ZigValue *value;
    Stage1AirBasicBlock *owner_bb;
    // Nearly any instruction can have to be stored as a local variable before suspending
    // and then loaded after resuming, in case there is an expression with a suspend point
    // in it, such as: x + await y
    Stage1AirInst *spill;

    // for debugging purposes, these are useful to call to inspect the instruction
    void dump();
    void src();
};

struct Stage1ZirInstDeclVar {
    Stage1ZirInst base;

    ZigVar *var;
    Stage1ZirInst *var_type;
    Stage1ZirInst *align_value;
    Stage1ZirInst *ptr;
};

struct Stage1AirInstDeclVar {
    Stage1AirInst base;

    ZigVar *var;
    Stage1AirInst *var_ptr;
};

struct Stage1ZirInstCondBr {
    Stage1ZirInst base;

    Stage1ZirInst *condition;
    Stage1ZirBasicBlock *then_block;
    Stage1ZirBasicBlock *else_block;
    Stage1ZirInst *is_comptime;
    ResultLoc *result_loc;
};

struct Stage1AirInstCondBr {
    Stage1AirInst base;

    Stage1AirInst *condition;
    Stage1AirBasicBlock *then_block;
    Stage1AirBasicBlock *else_block;
};

struct Stage1ZirInstBr {
    Stage1ZirInst base;

    Stage1ZirBasicBlock *dest_block;
    Stage1ZirInst *is_comptime;
};

struct Stage1AirInstBr {
    Stage1AirInst base;

    Stage1AirBasicBlock *dest_block;
};

struct Stage1ZirInstSwitchBrCase {
    Stage1ZirInst *value;
    Stage1ZirBasicBlock *block;
};

struct Stage1ZirInstSwitchBr {
    Stage1ZirInst base;

    Stage1ZirInst *target_value;
    Stage1ZirBasicBlock *else_block;
    size_t case_count;
    Stage1ZirInstSwitchBrCase *cases;
    Stage1ZirInst *is_comptime;
    Stage1ZirInst *switch_prongs_void;
};

struct Stage1AirInstSwitchBrCase {
    Stage1AirInst *value;
    Stage1AirBasicBlock *block;
};

struct Stage1AirInstSwitchBr {
    Stage1AirInst base;

    Stage1AirInst *target_value;
    Stage1AirBasicBlock *else_block;
    size_t case_count;
    Stage1AirInstSwitchBrCase *cases;
};

struct Stage1ZirInstSwitchVar {
    Stage1ZirInst base;

    Stage1ZirInst *target_value_ptr;
    Stage1ZirInst **prongs_ptr;
    size_t prongs_len;
};

struct Stage1ZirInstSwitchElseVar {
    Stage1ZirInst base;

    Stage1ZirInst *target_value_ptr;
    Stage1ZirInstSwitchBr *switch_br;
};

struct Stage1ZirInstSwitchTarget {
    Stage1ZirInst base;

    Stage1ZirInst *target_value_ptr;
};

struct Stage1ZirInstPhi {
    Stage1ZirInst base;

    size_t incoming_count;
    Stage1ZirBasicBlock **incoming_blocks;
    Stage1ZirInst **incoming_values;
    ResultLocPeerParent *peer_parent;
};

struct Stage1AirInstPhi {
    Stage1AirInst base;

    size_t incoming_count;
    Stage1AirBasicBlock **incoming_blocks;
    Stage1AirInst **incoming_values;
};

enum IrUnOp {
    IrUnOpInvalid,
    IrUnOpBinNot,
    IrUnOpNegation,
    IrUnOpNegationWrap,
    IrUnOpDereference,
    IrUnOpOptional,
};

struct Stage1ZirInstUnOp {
    Stage1ZirInst base;

    IrUnOp op_id;
    LVal lval;
    Stage1ZirInst *value;
    ResultLoc *result_loc;
};

struct Stage1AirInstBinaryNot {
    Stage1AirInst base;
    Stage1AirInst *operand;
};

struct Stage1AirInstNegation {
    Stage1AirInst base;
    Stage1AirInst *operand;
    bool wrapping;
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
};

struct Stage1ZirInstBinOp {
    Stage1ZirInst base;

    Stage1ZirInst *op1;
    Stage1ZirInst *op2;
    IrBinOp op_id;
    bool safety_check_on;
};

struct Stage1AirInstBinOp {
    Stage1AirInst base;

    Stage1AirInst *op1;
    Stage1AirInst *op2;
    IrBinOp op_id;
    bool safety_check_on;
};

struct Stage1ZirInstMergeErrSets {
    Stage1ZirInst base;

    Stage1ZirInst *op1;
    Stage1ZirInst *op2;
    Buf *type_name;
};

struct Stage1ZirInstLoadPtr {
    Stage1ZirInst base;

    Stage1ZirInst *ptr;
};

struct Stage1AirInstLoadPtr {
    Stage1AirInst base;

    Stage1AirInst *ptr;
    Stage1AirInst *result_loc;
};

struct Stage1ZirInstStorePtr {
    Stage1ZirInst base;

    Stage1ZirInst *ptr;
    Stage1ZirInst *value;

    bool allow_write_through_const;
};

struct Stage1AirInstStorePtr {
    Stage1AirInst base;

    Stage1AirInst *ptr;
    Stage1AirInst *value;
};

struct Stage1AirInstVectorStoreElem {
    Stage1AirInst base;

    Stage1AirInst *vector_ptr;
    Stage1AirInst *index;
    Stage1AirInst *value;
};

struct Stage1ZirInstFieldPtr {
    Stage1ZirInst base;

    Stage1ZirInst *container_ptr;
    Buf *field_name_buffer;
    Stage1ZirInst *field_name_expr;
    bool initializing;
};

struct Stage1AirInstStructFieldPtr {
    Stage1AirInst base;

    Stage1AirInst *struct_ptr;
    TypeStructField *field;
    bool is_const;
};

struct Stage1AirInstUnionFieldPtr {
    Stage1AirInst base;

    Stage1AirInst *union_ptr;
    TypeUnionField *field;
    bool safety_check_on;
    bool initializing;
};

struct Stage1ZirInstElemPtr {
    Stage1ZirInst base;

    Stage1ZirInst *array_ptr;
    Stage1ZirInst *elem_index;
    AstNode *init_array_type_source_node;
    PtrLen ptr_len;
    bool safety_check_on;
};

struct Stage1AirInstElemPtr {
    Stage1AirInst base;

    Stage1AirInst *array_ptr;
    Stage1AirInst *elem_index;
    bool safety_check_on;
};

struct Stage1ZirInstVarPtr {
    Stage1ZirInst base;

    ZigVar *var;
    ScopeFnDef *crossed_fndef_scope;
};

struct Stage1AirInstVarPtr {
    Stage1AirInst base;

    ZigVar *var;
};

// For functions that have a return type for which handle_is_ptr is true, a
// result location pointer is the secret first parameter ("sret"). This
// instruction returns that pointer.
struct Stage1AirInstReturnPtr {
    Stage1AirInst base;
};

struct Stage1ZirInstCall {
    Stage1ZirInst base;

    Stage1ZirInst *fn_ref;
    ZigFn *fn_entry;
    size_t arg_count;
    Stage1ZirInst **args;
    Stage1ZirInst *ret_ptr;
    ResultLoc *result_loc;

    Stage1ZirInst *new_stack;

    CallModifier modifier;
    bool is_async_call_builtin;
};

// This is a pass1 instruction, used by @call when the args node is
// a tuple or struct literal.
struct Stage1ZirInstCallArgs {
    Stage1ZirInst base;

    Stage1ZirInst *options;
    Stage1ZirInst *fn_ref;
    Stage1ZirInst **args_ptr;
    size_t args_len;
    ResultLoc *result_loc;
};

// This is a pass1 instruction, used by @call, when the args node
// is not a literal.
// `args` is expected to be either a struct or a tuple.
struct Stage1ZirInstCallExtra {
    Stage1ZirInst base;

    Stage1ZirInst *options;
    Stage1ZirInst *fn_ref;
    Stage1ZirInst *args;
    ResultLoc *result_loc;
};

// This is a pass1 instruction, used by @asyncCall, when the args node
// is not a literal.
// `args` is expected to be either a struct or a tuple.
struct Stage1ZirInstAsyncCallExtra {
    Stage1ZirInst base;

    CallModifier modifier;
    Stage1ZirInst *fn_ref;
    Stage1ZirInst *ret_ptr;
    Stage1ZirInst *new_stack;
    Stage1ZirInst *args;
    ResultLoc *result_loc;
};

struct Stage1AirInstCall {
    Stage1AirInst base;

    Stage1AirInst *fn_ref;
    ZigFn *fn_entry;
    size_t arg_count;
    Stage1AirInst **args;
    Stage1AirInst *result_loc;
    Stage1AirInst *frame_result_loc;
    Stage1AirInst *new_stack;

    CallModifier modifier;

    bool is_async_call_builtin;
};

struct Stage1ZirInstConst {
    Stage1ZirInst base;

    ZigValue *value;
};

struct Stage1AirInstConst {
    Stage1AirInst base;
};

struct Stage1ZirInstReturn {
    Stage1ZirInst base;

    Stage1ZirInst *operand;
};

// When an IrExecutable is not in a function, a return instruction means that
// the expression returns with that value, even though a return statement from
// an AST perspective is invalid.
struct Stage1AirInstReturn {
    Stage1AirInst base;

    Stage1AirInst *operand;
};

enum CastOp {
    CastOpNoCast, // signifies the function call expression is not a cast
    CastOpNoop, // fn call expr is a cast, but does nothing
    CastOpIntToFloat,
    CastOpFloatToInt,
    CastOpBoolToInt,
    CastOpNumLitToConcrete,
    CastOpErrSet,
    CastOpBitCast,
};

// TODO get rid of this instruction, replace with instructions for each op code
struct Stage1AirInstCast {
    Stage1AirInst base;

    Stage1AirInst *value;
    CastOp cast_op;
};

struct Stage1ZirInstContainerInitList {
    Stage1ZirInst base;

    Stage1ZirInst *elem_type;
    size_t item_count;
    Stage1ZirInst **elem_result_loc_list;
    Stage1ZirInst *result_loc;
    AstNode *init_array_type_source_node;
};

struct Stage1ZirInstContainerInitFieldsField {
    Buf *name;
    AstNode *source_node;
    Stage1ZirInst *result_loc;
};

struct Stage1ZirInstContainerInitFields {
    Stage1ZirInst base;

    size_t field_count;
    Stage1ZirInstContainerInitFieldsField *fields;
    Stage1ZirInst *result_loc;
};

struct Stage1ZirInstUnreachable {
    Stage1ZirInst base;
};

struct Stage1AirInstUnreachable {
    Stage1AirInst base;
};

struct Stage1ZirInstTypeOf {
    Stage1ZirInst base;

    union {
        Stage1ZirInst *scalar; // value_count == 1
        Stage1ZirInst **list; // value_count > 1
    } value;
    size_t value_count;
};

struct Stage1ZirInstSetCold {
    Stage1ZirInst base;

    Stage1ZirInst *is_cold;
};

struct Stage1ZirInstSetRuntimeSafety {
    Stage1ZirInst base;

    Stage1ZirInst *safety_on;
};

struct Stage1ZirInstSetFloatMode {
    Stage1ZirInst base;

    Stage1ZirInst *scope_value;
    Stage1ZirInst *mode_value;
};

struct Stage1ZirInstArrayType {
    Stage1ZirInst base;

    Stage1ZirInst *size;
    Stage1ZirInst *sentinel;
    Stage1ZirInst *child_type;
};

struct Stage1ZirInstPtrTypeSimple {
    Stage1ZirInst base;

    Stage1ZirInst *child_type;
};

struct Stage1ZirInstPtrType {
    Stage1ZirInst base;

    Stage1ZirInst *sentinel;
    Stage1ZirInst *align_value;
    Stage1ZirInst *child_type;
    uint32_t bit_offset_start;
    uint32_t host_int_bytes;
    PtrLen ptr_len;
    bool is_const;
    bool is_volatile;
    bool is_allow_zero;
};

struct Stage1ZirInstAnyFrameType {
    Stage1ZirInst base;

    Stage1ZirInst *payload_type;
};

struct Stage1ZirInstSliceType {
    Stage1ZirInst base;

    Stage1ZirInst *sentinel;
    Stage1ZirInst *align_value;
    Stage1ZirInst *child_type;
    bool is_const;
    bool is_volatile;
    bool is_allow_zero;
};

struct Stage1ZirInstAsm {
    Stage1ZirInst base;

    Stage1ZirInst *asm_template;
    Stage1ZirInst **input_list;
    Stage1ZirInst **output_types;
    ZigVar **output_vars;
    size_t return_count;
    bool has_side_effects;
    bool is_global;
};

struct Stage1AirInstAsm {
    Stage1AirInst base;

    Buf *asm_template;
    AsmToken *token_list;
    size_t token_list_len;
    Stage1AirInst **input_list;
    Stage1AirInst **output_types;
    ZigVar **output_vars;
    size_t return_count;
    bool has_side_effects;
};

struct Stage1ZirInstSizeOf {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
    bool bit_size;
};

// returns true if nonnull, returns false if null
struct Stage1ZirInstTestNonNull {
    Stage1ZirInst base;

    Stage1ZirInst *value;
};

struct Stage1AirInstTestNonNull {
    Stage1AirInst base;

    Stage1AirInst *value;
};

// Takes a pointer to an optional value, returns a pointer
// to the payload.
struct Stage1ZirInstOptionalUnwrapPtr {
    Stage1ZirInst base;

    Stage1ZirInst *base_ptr;
    bool safety_check_on;
};

struct Stage1AirInstOptionalUnwrapPtr {
    Stage1AirInst base;

    Stage1AirInst *base_ptr;
    bool safety_check_on;
    bool initializing;
};

struct Stage1ZirInstCtz {
    Stage1ZirInst base;

    Stage1ZirInst *type;
    Stage1ZirInst *op;
};

struct Stage1AirInstCtz {
    Stage1AirInst base;

    Stage1AirInst *op;
};

struct Stage1ZirInstClz {
    Stage1ZirInst base;

    Stage1ZirInst *type;
    Stage1ZirInst *op;
};

struct Stage1AirInstClz {
    Stage1AirInst base;

    Stage1AirInst *op;
};

struct Stage1ZirInstPopCount {
    Stage1ZirInst base;

    Stage1ZirInst *type;
    Stage1ZirInst *op;
};

struct Stage1AirInstPopCount {
    Stage1AirInst base;

    Stage1AirInst *op;
};

struct Stage1AirInstUnionTag {
    Stage1AirInst base;

    Stage1AirInst *value;
};

struct Stage1ZirInstImport {
    Stage1ZirInst base;

    Stage1ZirInst *name;
};

struct Stage1ZirInstRef {
    Stage1ZirInst base;

    Stage1ZirInst *value;
};

struct Stage1AirInstRef {
    Stage1AirInst base;

    Stage1AirInst *operand;
    Stage1AirInst *result_loc;
};

struct Stage1ZirInstCompileErr {
    Stage1ZirInst base;

    Stage1ZirInst *msg;
};

struct Stage1ZirInstCompileLog {
    Stage1ZirInst base;

    size_t msg_count;
    Stage1ZirInst **msg_list;
};

struct Stage1ZirInstErrName {
    Stage1ZirInst base;

    Stage1ZirInst *value;
};

struct Stage1AirInstErrName {
    Stage1AirInst base;

    Stage1AirInst *value;
};

struct Stage1ZirInstCImport {
    Stage1ZirInst base;
};

struct Stage1ZirInstCInclude {
    Stage1ZirInst base;

    Stage1ZirInst *name;
};

struct Stage1ZirInstCDefine {
    Stage1ZirInst base;

    Stage1ZirInst *name;
    Stage1ZirInst *value;
};

struct Stage1ZirInstCUndef {
    Stage1ZirInst base;

    Stage1ZirInst *name;
};

struct Stage1ZirInstEmbedFile {
    Stage1ZirInst base;

    Stage1ZirInst *name;
};

struct Stage1ZirInstCmpxchg {
    Stage1ZirInst base;

    bool is_weak;
    Stage1ZirInst *type_value;
    Stage1ZirInst *ptr;
    Stage1ZirInst *cmp_value;
    Stage1ZirInst *new_value;
    Stage1ZirInst *success_order_value;
    Stage1ZirInst *failure_order_value;
    ResultLoc *result_loc;
};

struct Stage1AirInstCmpxchg {
    Stage1AirInst base;

    AtomicOrder success_order;
    AtomicOrder failure_order;
    Stage1AirInst *ptr;
    Stage1AirInst *cmp_value;
    Stage1AirInst *new_value;
    Stage1AirInst *result_loc;
    bool is_weak;
};

struct Stage1ZirInstFence {
    Stage1ZirInst base;

    Stage1ZirInst *order;
};

struct Stage1AirInstFence {
    Stage1AirInst base;

    AtomicOrder order;
};

struct Stage1ZirInstReduce {
    Stage1ZirInst base;

    Stage1ZirInst *op;
    Stage1ZirInst *value;
};

struct Stage1AirInstReduce {
    Stage1AirInst base;

    ReduceOp op;
    Stage1AirInst *value;
};

struct Stage1ZirInstTruncate {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1AirInstTruncate {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstIntCast {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1ZirInstFloatCast {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1ZirInstErrSetCast {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1ZirInstIntToFloat {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1ZirInstFloatToInt {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1ZirInstBoolToInt {
    Stage1ZirInst base;

    Stage1ZirInst *target;
};

struct Stage1ZirInstVectorType {
    Stage1ZirInst base;

    Stage1ZirInst *len;
    Stage1ZirInst *elem_type;
};

struct Stage1ZirInstBoolNot {
    Stage1ZirInst base;

    Stage1ZirInst *value;
};

struct Stage1AirInstBoolNot {
    Stage1AirInst base;

    Stage1AirInst *value;
};

struct Stage1ZirInstMemset {
    Stage1ZirInst base;

    Stage1ZirInst *dest_ptr;
    Stage1ZirInst *byte;
    Stage1ZirInst *count;
};

struct Stage1AirInstMemset {
    Stage1AirInst base;

    Stage1AirInst *dest_ptr;
    Stage1AirInst *byte;
    Stage1AirInst *count;
};

struct Stage1ZirInstMemcpy {
    Stage1ZirInst base;

    Stage1ZirInst *dest_ptr;
    Stage1ZirInst *src_ptr;
    Stage1ZirInst *count;
};

struct Stage1AirInstMemcpy {
    Stage1AirInst base;

    Stage1AirInst *dest_ptr;
    Stage1AirInst *src_ptr;
    Stage1AirInst *count;
};

struct Stage1ZirInstWasmMemorySize {
    Stage1ZirInst base;

    Stage1ZirInst *index;
};

struct Stage1AirInstWasmMemorySize {
    Stage1AirInst base;

    Stage1AirInst *index;
};

struct Stage1ZirInstWasmMemoryGrow {
    Stage1ZirInst base;

    Stage1ZirInst *index;
    Stage1ZirInst *delta;
};

struct Stage1AirInstWasmMemoryGrow {
    Stage1AirInst base;

    Stage1AirInst *index;
    Stage1AirInst *delta;
};

struct Stage1ZirInstSrc {
    Stage1ZirInst base;
};

struct Stage1ZirInstSlice {
    Stage1ZirInst base;

    Stage1ZirInst *ptr;
    Stage1ZirInst *start;
    Stage1ZirInst *end;
    Stage1ZirInst *sentinel;
    ResultLoc *result_loc;
    bool safety_check_on;
};

struct Stage1AirInstSlice {
    Stage1AirInst base;

    Stage1AirInst *ptr;
    Stage1AirInst *start;
    Stage1AirInst *end;
    Stage1AirInst *result_loc;
    ZigValue *sentinel;
    bool safety_check_on;
};

struct Stage1ZirInstBreakpoint {
    Stage1ZirInst base;
};

struct Stage1AirInstBreakpoint {
    Stage1AirInst base;
};

struct Stage1ZirInstReturnAddress {
    Stage1ZirInst base;
};

struct Stage1AirInstReturnAddress {
    Stage1AirInst base;
};

struct Stage1ZirInstFrameAddress {
    Stage1ZirInst base;
};

struct Stage1AirInstFrameAddress {
    Stage1AirInst base;
};

struct Stage1ZirInstFrameHandle {
    Stage1ZirInst base;
};

struct Stage1AirInstFrameHandle {
    Stage1AirInst base;
};

struct Stage1ZirInstFrameType {
    Stage1ZirInst base;

    Stage1ZirInst *fn;
};

struct Stage1ZirInstFrameSize {
    Stage1ZirInst base;

    Stage1ZirInst *fn;
};

struct Stage1AirInstFrameSize {
    Stage1AirInst base;

    Stage1AirInst *fn;
};

enum IrOverflowOp {
    IrOverflowOpAdd,
    IrOverflowOpSub,
    IrOverflowOpMul,
    IrOverflowOpShl,
};

struct Stage1ZirInstOverflowOp {
    Stage1ZirInst base;

    IrOverflowOp op;
    Stage1ZirInst *type_value;
    Stage1ZirInst *op1;
    Stage1ZirInst *op2;
    Stage1ZirInst *result_ptr;
};

struct Stage1AirInstOverflowOp {
    Stage1AirInst base;

    IrOverflowOp op;
    Stage1AirInst *op1;
    Stage1AirInst *op2;
    Stage1AirInst *result_ptr;

    // TODO can this field be removed?
    ZigType *result_ptr_type;
};

struct Stage1ZirInstMulAdd {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
    Stage1ZirInst *op1;
    Stage1ZirInst *op2;
    Stage1ZirInst *op3;
};

struct Stage1AirInstMulAdd {
    Stage1AirInst base;

    Stage1AirInst *op1;
    Stage1AirInst *op2;
    Stage1AirInst *op3;
};

struct Stage1ZirInstAlignOf {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
};

// returns true if error, returns false if not error
struct Stage1ZirInstTestErr {
    Stage1ZirInst base;

    Stage1ZirInst *base_ptr;
    bool resolve_err_set;
    bool base_ptr_is_payload;
};

struct Stage1AirInstTestErr {
    Stage1AirInst base;

    Stage1AirInst *err_union;
};

// Takes an error union pointer, returns a pointer to the error code.
struct Stage1ZirInstUnwrapErrCode {
    Stage1ZirInst base;

    Stage1ZirInst *err_union_ptr;
    bool initializing;
};

struct Stage1AirInstUnwrapErrCode {
    Stage1AirInst base;

    Stage1AirInst *err_union_ptr;
    bool initializing;
};

struct Stage1ZirInstUnwrapErrPayload {
    Stage1ZirInst base;

    Stage1ZirInst *value;
    bool safety_check_on;
    bool initializing;
};

struct Stage1AirInstUnwrapErrPayload {
    Stage1AirInst base;

    Stage1AirInst *value;
    bool safety_check_on;
    bool initializing;
};

struct Stage1AirInstOptionalWrap {
    Stage1AirInst base;

    Stage1AirInst *operand;
    Stage1AirInst *result_loc;
};

struct Stage1AirInstErrWrapPayload {
    Stage1AirInst base;

    Stage1AirInst *operand;
    Stage1AirInst *result_loc;
};

struct Stage1AirInstErrWrapCode {
    Stage1AirInst base;

    Stage1AirInst *operand;
    Stage1AirInst *result_loc;
};

struct Stage1ZirInstFnProto {
    Stage1ZirInst base;

    Stage1ZirInst **param_types;
    Stage1ZirInst *align_value;
    Stage1ZirInst *callconv_value;
    Stage1ZirInst *return_type;
    bool is_var_args;
};

// true if the target value is compile time known, false otherwise
struct Stage1ZirInstTestComptime {
    Stage1ZirInst base;

    Stage1ZirInst *value;
};

struct Stage1ZirInstPtrCast {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *ptr;
    bool safety_check_on;
};

struct Stage1AirInstPtrCast {
    Stage1AirInst base;

    Stage1AirInst *ptr;
    bool safety_check_on;
};

struct Stage1ZirInstImplicitCast {
    Stage1ZirInst base;

    Stage1ZirInst *operand;
    ResultLocCast *result_loc_cast;
};

struct Stage1ZirInstBitCast {
    Stage1ZirInst base;

    Stage1ZirInst *operand;
    ResultLocBitCast *result_loc_bit_cast;
};

struct Stage1AirInstBitCast {
    Stage1AirInst base;

    Stage1AirInst *operand;
};

struct Stage1AirInstWidenOrShorten {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstPtrToInt {
    Stage1ZirInst base;

    Stage1ZirInst *target;
};

struct Stage1AirInstPtrToInt {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstIntToPtr {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1AirInstIntToPtr {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstIntToEnum {
    Stage1ZirInst base;

    Stage1ZirInst *dest_type;
    Stage1ZirInst *target;
};

struct Stage1AirInstIntToEnum {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstEnumToInt {
    Stage1ZirInst base;

    Stage1ZirInst *target;
};

struct Stage1ZirInstIntToErr {
    Stage1ZirInst base;

    Stage1ZirInst *target;
};

struct Stage1AirInstIntToErr {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstErrToInt {
    Stage1ZirInst base;

    Stage1ZirInst *target;
};

struct Stage1AirInstErrToInt {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstCheckSwitchProngsRange {
    Stage1ZirInst *start;
    Stage1ZirInst *end;
};

struct Stage1ZirInstCheckSwitchProngs {
    Stage1ZirInst base;

    Stage1ZirInst *target_value;
    Stage1ZirInstCheckSwitchProngsRange *ranges;
    size_t range_count;
    AstNode* else_prong;
};

struct Stage1ZirInstCheckStatementIsVoid {
    Stage1ZirInst base;

    Stage1ZirInst *statement_value;
};

struct Stage1ZirInstTypeName {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
};

struct Stage1ZirInstDeclRef {
    Stage1ZirInst base;

    LVal lval;
    Tld *tld;
};

struct Stage1ZirInstPanic {
    Stage1ZirInst base;

    Stage1ZirInst *msg;
};

struct Stage1AirInstPanic {
    Stage1AirInst base;

    Stage1AirInst *msg;
};

struct Stage1ZirInstTagName {
    Stage1ZirInst base;

    Stage1ZirInst *target;
};

struct Stage1AirInstTagName {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstFieldParentPtr {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
    Stage1ZirInst *field_name;
    Stage1ZirInst *field_ptr;
};

struct Stage1AirInstFieldParentPtr {
    Stage1AirInst base;

    Stage1AirInst *field_ptr;
    TypeStructField *field;
};

struct Stage1ZirInstOffsetOf {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
    Stage1ZirInst *field_name;
};

struct Stage1ZirInstBitOffsetOf {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
    Stage1ZirInst *field_name;
};

struct Stage1ZirInstTypeInfo {
    Stage1ZirInst base;

    Stage1ZirInst *type_value;
};

struct Stage1ZirInstType {
    Stage1ZirInst base;

    Stage1ZirInst *type_info;
};

struct Stage1ZirInstHasField {
    Stage1ZirInst base;

    Stage1ZirInst *container_type;
    Stage1ZirInst *field_name;
};

struct Stage1ZirInstSetEvalBranchQuota {
    Stage1ZirInst base;

    Stage1ZirInst *new_quota;
};

struct Stage1ZirInstAlignCast {
    Stage1ZirInst base;

    Stage1ZirInst *align_bytes;
    Stage1ZirInst *target;
};

struct Stage1AirInstAlignCast {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstSetAlignStack {
    Stage1ZirInst base;

    Stage1ZirInst *align_bytes;
};

struct Stage1ZirInstArgType {
    Stage1ZirInst base;

    Stage1ZirInst *fn_type;
    Stage1ZirInst *arg_index;
};

struct Stage1ZirInstExport {
    Stage1ZirInst base;

    Stage1ZirInst *target;
    Stage1ZirInst *options;
};

struct Stage1ZirInstExtern {
    Stage1ZirInst base;

    Stage1ZirInst *type;
    Stage1ZirInst *options;
};

struct Stage1AirInstExtern {
    Stage1AirInst base;

    Buf *name;
    GlobalLinkageId linkage;
    bool is_thread_local;
};

enum IrInstErrorReturnTraceOptional {
    IrInstErrorReturnTraceNull,
    IrInstErrorReturnTraceNonNull,
};

struct Stage1ZirInstErrorReturnTrace {
    Stage1ZirInst base;

    IrInstErrorReturnTraceOptional optional;
};

struct Stage1AirInstErrorReturnTrace {
    Stage1AirInst base;

    IrInstErrorReturnTraceOptional optional;
};

struct Stage1ZirInstErrorUnion {
    Stage1ZirInst base;

    Stage1ZirInst *err_set;
    Stage1ZirInst *payload;
    Buf *type_name;
};

struct Stage1ZirInstAtomicRmw {
    Stage1ZirInst base;

    Stage1ZirInst *operand_type;
    Stage1ZirInst *ptr;
    Stage1ZirInst *op;
    Stage1ZirInst *operand;
    Stage1ZirInst *ordering;
};

struct Stage1AirInstAtomicRmw {
    Stage1AirInst base;

    Stage1AirInst *ptr;
    Stage1AirInst *operand;
    AtomicRmwOp op;
    AtomicOrder ordering;
};

struct Stage1ZirInstAtomicLoad {
    Stage1ZirInst base;

    Stage1ZirInst *operand_type;
    Stage1ZirInst *ptr;
    Stage1ZirInst *ordering;
};

struct Stage1AirInstAtomicLoad {
    Stage1AirInst base;

    Stage1AirInst *ptr;
    AtomicOrder ordering;
};

struct Stage1ZirInstAtomicStore {
    Stage1ZirInst base;

    Stage1ZirInst *operand_type;
    Stage1ZirInst *ptr;
    Stage1ZirInst *value;
    Stage1ZirInst *ordering;
};

struct Stage1AirInstAtomicStore {
    Stage1AirInst base;

    Stage1AirInst *ptr;
    Stage1AirInst *value;
    AtomicOrder ordering;
};

struct Stage1ZirInstSaveErrRetAddr {
    Stage1ZirInst base;
};

struct Stage1AirInstSaveErrRetAddr {
    Stage1AirInst base;
};

struct Stage1ZirInstAddImplicitReturnType {
    Stage1ZirInst base;

    Stage1ZirInst *value;
    ResultLocReturn *result_loc_ret;
};

// For float ops that take a single argument
struct Stage1ZirInstFloatOp {
    Stage1ZirInst base;

    Stage1ZirInst *operand;
    BuiltinFnId fn_id;
};

struct Stage1AirInstFloatOp {
    Stage1AirInst base;

    Stage1AirInst *operand;
    BuiltinFnId fn_id;
};

struct Stage1ZirInstCheckRuntimeScope {
    Stage1ZirInst base;

    Stage1ZirInst *scope_is_comptime;
    Stage1ZirInst *is_comptime;
};

struct Stage1ZirInstBswap {
    Stage1ZirInst base;

    Stage1ZirInst *type;
    Stage1ZirInst *op;
};

struct Stage1AirInstBswap {
    Stage1AirInst base;

    Stage1AirInst *op;
};

struct Stage1ZirInstBitReverse {
    Stage1ZirInst base;

    Stage1ZirInst *type;
    Stage1ZirInst *op;
};

struct Stage1AirInstBitReverse {
    Stage1AirInst base;

    Stage1AirInst *op;
};

struct Stage1AirInstArrayToVector {
    Stage1AirInst base;

    Stage1AirInst *array;
};

struct Stage1AirInstVectorToArray {
    Stage1AirInst base;

    Stage1AirInst *vector;
    Stage1AirInst *result_loc;
};

struct Stage1ZirInstShuffleVector {
    Stage1ZirInst base;

    Stage1ZirInst *scalar_type;
    Stage1ZirInst *a;
    Stage1ZirInst *b;
    Stage1ZirInst *mask; // This is in zig-format, not llvm format
};

struct Stage1AirInstShuffleVector {
    Stage1AirInst base;

    Stage1AirInst *a;
    Stage1AirInst *b;
    Stage1AirInst *mask; // This is in zig-format, not llvm format
};

struct Stage1ZirInstSplat {
    Stage1ZirInst base;

    Stage1ZirInst *len;
    Stage1ZirInst *scalar;
};

struct Stage1AirInstSplat {
    Stage1AirInst base;

    Stage1AirInst *scalar;
};

struct Stage1AirInstAssertZero {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1AirInstAssertNonNull {
    Stage1AirInst base;

    Stage1AirInst *target;
};

struct Stage1ZirInstUnionInitNamedField {
    Stage1ZirInst base;

    Stage1ZirInst *union_type;
    Stage1ZirInst *field_name;
    Stage1ZirInst *field_result_loc;
    Stage1ZirInst *result_loc;
};

struct Stage1ZirInstHasDecl {
    Stage1ZirInst base;

    Stage1ZirInst *container;
    Stage1ZirInst *name;
};

struct Stage1ZirInstUndeclaredIdent {
    Stage1ZirInst base;

    Buf *name;
};

struct Stage1ZirInstAlloca {
    Stage1ZirInst base;

    Stage1ZirInst *align;
    Stage1ZirInst *is_comptime;
    const char *name_hint;
};

struct Stage1AirInstAlloca {
    Stage1AirInst base;

    uint32_t align;
    const char *name_hint;
    size_t field_index;
};

struct Stage1ZirInstEndExpr {
    Stage1ZirInst base;

    Stage1ZirInst *value;
    ResultLoc *result_loc;
};

// This one is for writing through the result pointer.
struct Stage1ZirInstResolveResult {
    Stage1ZirInst base;

    ResultLoc *result_loc;
    Stage1ZirInst *ty;
};

struct Stage1ZirInstResetResult {
    Stage1ZirInst base;

    ResultLoc *result_loc;
};

struct Stage1AirInstPtrOfArrayToSlice {
    Stage1AirInst base;

    Stage1AirInst *operand;
    Stage1AirInst *result_loc;
};

struct Stage1ZirInstSuspendBegin {
    Stage1ZirInst base;
};

struct Stage1AirInstSuspendBegin {
    Stage1AirInst base;

    LLVMBasicBlockRef resume_bb;
};

struct Stage1ZirInstSuspendFinish {
    Stage1ZirInst base;

    Stage1ZirInstSuspendBegin *begin;
};

struct Stage1AirInstSuspendFinish {
    Stage1AirInst base;

    Stage1AirInstSuspendBegin *begin;
};

struct Stage1ZirInstAwait {
    Stage1ZirInst base;

    Stage1ZirInst *frame;
    ResultLoc *result_loc;
    bool is_nosuspend;
};

struct Stage1AirInstAwait {
    Stage1AirInst base;

    Stage1AirInst *frame;
    Stage1AirInst *result_loc;
    ZigFn *target_fn;
    bool is_nosuspend;
};

struct Stage1ZirInstResume {
    Stage1ZirInst base;

    Stage1ZirInst *frame;
};

struct Stage1AirInstResume {
    Stage1AirInst base;

    Stage1AirInst *frame;
};

enum SpillId {
    SpillIdInvalid,
    SpillIdRetErrCode,
};

struct Stage1ZirInstSpillBegin {
    Stage1ZirInst base;

    Stage1ZirInst *operand;
    SpillId spill_id;
};

struct Stage1AirInstSpillBegin {
    Stage1AirInst base;

    SpillId spill_id;
    Stage1AirInst *operand;
};

struct Stage1ZirInstSpillEnd {
    Stage1ZirInst base;

    Stage1ZirInstSpillBegin *begin;
};

struct Stage1AirInstSpillEnd {
    Stage1AirInst base;

    Stage1AirInstSpillBegin *begin;
};

struct Stage1AirInstVectorExtractElem {
    Stage1AirInst base;

    Stage1AirInst *vector;
    Stage1AirInst *index;
};

enum ResultLocId {
    ResultLocIdInvalid,
    ResultLocIdNone,
    ResultLocIdVar,
    ResultLocIdReturn,
    ResultLocIdPeer,
    ResultLocIdPeerParent,
    ResultLocIdInstruction,
    ResultLocIdBitCast,
    ResultLocIdCast,
};

// Additions to this struct may need to be handled in
// ir_reset_result
struct ResultLoc {
    ResultLocId id;
    bool written;
    bool allow_write_through_const;
    Stage1AirInst *resolved_loc; // result ptr
    Stage1ZirInst *source_instruction;
    Stage1AirInst *gen_instruction; // value to store to the result loc
    ZigType *implicit_elem_type;
};

struct ResultLocNone {
    ResultLoc base;
};

struct ResultLocVar {
    ResultLoc base;

    ZigVar *var;
};

struct ResultLocReturn {
    ResultLoc base;

    bool implicit_return_type_done;
};

struct IrSuspendPosition {
    size_t basic_block_index;
    size_t instruction_index;
};

struct ResultLocPeerParent {
    ResultLoc base;

    bool skipped;
    bool done_resuming;
    Stage1ZirBasicBlock *end_bb;
    ResultLoc *parent;
    ZigList<ResultLocPeer *> peers;
    ZigType *resolved_type;
    Stage1ZirInst *is_comptime;
};

struct ResultLocPeer {
    ResultLoc base;

    ResultLocPeerParent *parent;
    Stage1ZirBasicBlock *next_bb;
    IrSuspendPosition suspend_pos;
};

// The result location is the source instruction
struct ResultLocInstruction {
    ResultLoc base;
};

// The source_instruction is the destination type
struct ResultLocBitCast {
    ResultLoc base;

    ResultLoc *parent;
};

// The source_instruction is the destination type
struct ResultLocCast {
    ResultLoc base;

    ResultLoc *parent;
};

static const size_t slice_ptr_index = 0;
static const size_t slice_len_index = 1;

static const size_t maybe_child_index = 0;
static const size_t maybe_null_index = 1;

static const size_t err_union_payload_index = 0;
static const size_t err_union_err_index = 1;

// label (grep this): [fn_frame_struct_layout]
static const size_t frame_fn_ptr_index = 0;
static const size_t frame_resume_index = 1;
static const size_t frame_awaiter_index = 2;
static const size_t frame_ret_start = 3;

// TODO https://github.com/ziglang/zig/issues/3056
// We require this to be a power of 2 so that we can use shifting rather than
// remainder division.
static const size_t stack_trace_ptr_count = 32; // Must be a power of 2.

#define NAMESPACE_SEP_CHAR '.'
#define NAMESPACE_SEP_STR "."

#define CACHE_OUT_SUBDIR "o"
#define CACHE_HASH_SUBDIR "h"

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
    LLVMValueRef llvm_fn;
    unsigned gen_i;
};

struct FnWalkCall {
    ZigList<LLVMValueRef> *gen_param_values;
    ZigList<ZigType *> *gen_param_types;
    Stage1AirInstCall *inst;
    bool is_var_args;
};

struct FnWalkTypes {
    ZigList<ZigLLVMDIType *> *param_di_types;
    ZigList<LLVMTypeRef> *gen_param_types;
};

struct FnWalkVars {
    ZigType *import;
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
