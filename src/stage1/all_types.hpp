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
struct IrInst;
struct IrInstSrc;
struct IrInstGen;
struct IrInstGenCast;
struct IrInstGenAlloca;
struct IrInstGenCall;
struct IrInstGenAwait;
struct Stage1ZirBasicBlock;
struct IrBasicBlockGen;
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
    ZigList<IrBasicBlockGen *> basic_block_list;
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
    IrInstGen *first_arg;
    IrInst *first_arg_src;
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
    IrInst *source_instr;
};

struct LazyValueAlignOf {
    LazyValue base;

    IrAnalyze *ira;
    IrInstGen *target_type;
};

struct LazyValueSizeOf {
    LazyValue base;

    IrAnalyze *ira;
    IrInstGen *target_type;

    bool bit_size;
};

struct LazyValueSliceType {
    LazyValue base;

    IrAnalyze *ira;
    IrInstGen *sentinel; // can be null
    IrInstGen *elem_type;
    IrInstGen *align_inst; // can be null

    bool is_const;
    bool is_volatile;
    bool is_allowzero;
};

struct LazyValueArrayType {
    LazyValue base;

    IrAnalyze *ira;
    IrInstGen *sentinel; // can be null
    IrInstGen *elem_type;
    uint64_t length;
};

struct LazyValuePtrType {
    LazyValue base;

    IrAnalyze *ira;
    IrInstGen *sentinel; // can be null
    IrInstGen *elem_type;
    IrInstGen *align_inst; // can be null

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
    IrInstGen *elem_type;
};

struct LazyValueOptType {
    LazyValue base;

    IrAnalyze *ira;
    IrInstGen *payload_type;
};

struct LazyValueFnType {
    LazyValue base;

    IrAnalyze *ira;
    AstNode *proto_node;
    IrInstGen **param_types;
    IrInstGen *align_inst; // can be null
    IrInstGen *return_type;

    CallingConvention cc;
    bool is_generic;
};

struct LazyValueErrUnionType {
    LazyValue base;

    IrAnalyze *ira;
    IrInstGen *err_set_type;
    IrInstGen *payload_type;
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
    IrInstGen *err_code_spill;
    AstNode *assumed_non_async;

    AstNode *fn_no_inline_set_node;
    AstNode *fn_static_eval_set_node;

    ZigList<IrInstGenAlloca *> alloca_gen_list;
    ZigList<ZigVar *> variable_list;

    Buf *section_name;
    AstNode *set_alignstack_node;

    AstNode *set_cold_node;
    const AstNode *inferred_async_node;
    ZigFn *inferred_async_fn;
    AstNode *non_async_node;

    ZigList<GlobalExport> export_list;
    ZigList<IrInstGenCall *> call_list;
    ZigList<IrInstGenAwait *> await_list;

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

uint32_t type_id_hash(TypeId);
bool type_id_eql(TypeId a, TypeId b);

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

uint32_t zig_llvm_fn_key_hash(ZigLLVMFnKey);
bool zig_llvm_fn_key_eql(ZigLLVMFnKey a, ZigLLVMFnKey b);

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

    IrInstSrc *invalid_inst_src;
    IrInstGen *invalid_inst_gen;
    IrInstGen *unreach_instruction;

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
    IrInstSrc *is_comptime;
    IrInstGen *ptr_instruction;
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
    IrInstSrc *is_comptime;
    ResultLocPeerParent *peer_parent;
    ZigList<IrInstSrc *> *incoming_values;
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
    IrInstSrc *is_comptime;
    ZigList<IrInstSrc *> *incoming_values;
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

    IrInstSrc *is_comptime;
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
    ZigList<IrInstSrc *> instruction_list;
    IrBasicBlockGen *child;
    Scope *scope;
    const char *name_hint;
    IrInst *suspend_instruction_ref;

    uint32_t ref_count;
    uint32_t index; // index into the basic block list

    uint32_t debug_id;
    bool suspended;
    bool in_resume_stack;
};

struct IrBasicBlockGen {
    ZigList<IrInstGen *> instruction_list;
    Scope *scope;
    const char *name_hint;
    LLVMBasicBlockRef llvm_block;
    LLVMBasicBlockRef llvm_exit_block;
    // The instruction that referenced this basic block and caused us to
    // analyze the basic block. If the same instruction wants us to emit
    // the same basic block, then we re-generate it instead of saving it.
    IrInst *ref_instruction;
    // When this is non-null, a branch to this basic block is only allowed
    // if the branch is comptime. The instruction points to the reason
    // the basic block must be comptime.
    IrInst *must_be_comptime_source_instr;

    uint32_t debug_id;
    bool already_appended;
};

// Src instructions are generated by ir_gen_* functions in ir.cpp from AST.
// ir_analyze_* functions consume Src instructions and produce Gen instructions.
// Src instructions do not have type information; Gen instructions do.
enum IrInstSrcId {
    IrInstSrcIdInvalid,
    IrInstSrcIdDeclVar,
    IrInstSrcIdBr,
    IrInstSrcIdCondBr,
    IrInstSrcIdSwitchBr,
    IrInstSrcIdSwitchVar,
    IrInstSrcIdSwitchElseVar,
    IrInstSrcIdSwitchTarget,
    IrInstSrcIdPhi,
    IrInstSrcIdUnOp,
    IrInstSrcIdBinOp,
    IrInstSrcIdMergeErrSets,
    IrInstSrcIdLoadPtr,
    IrInstSrcIdStorePtr,
    IrInstSrcIdFieldPtr,
    IrInstSrcIdElemPtr,
    IrInstSrcIdVarPtr,
    IrInstSrcIdCall,
    IrInstSrcIdCallArgs,
    IrInstSrcIdCallExtra,
    IrInstSrcIdAsyncCallExtra,
    IrInstSrcIdConst,
    IrInstSrcIdReturn,
    IrInstSrcIdContainerInitList,
    IrInstSrcIdContainerInitFields,
    IrInstSrcIdUnreachable,
    IrInstSrcIdTypeOf,
    IrInstSrcIdSetCold,
    IrInstSrcIdSetRuntimeSafety,
    IrInstSrcIdSetFloatMode,
    IrInstSrcIdArrayType,
    IrInstSrcIdAnyFrameType,
    IrInstSrcIdSliceType,
    IrInstSrcIdAsm,
    IrInstSrcIdSizeOf,
    IrInstSrcIdTestNonNull,
    IrInstSrcIdOptionalUnwrapPtr,
    IrInstSrcIdClz,
    IrInstSrcIdCtz,
    IrInstSrcIdPopCount,
    IrInstSrcIdBswap,
    IrInstSrcIdBitReverse,
    IrInstSrcIdImport,
    IrInstSrcIdCImport,
    IrInstSrcIdCInclude,
    IrInstSrcIdCDefine,
    IrInstSrcIdCUndef,
    IrInstSrcIdRef,
    IrInstSrcIdCompileErr,
    IrInstSrcIdCompileLog,
    IrInstSrcIdErrName,
    IrInstSrcIdEmbedFile,
    IrInstSrcIdCmpxchg,
    IrInstSrcIdFence,
    IrInstSrcIdReduce,
    IrInstSrcIdTruncate,
    IrInstSrcIdIntCast,
    IrInstSrcIdFloatCast,
    IrInstSrcIdIntToFloat,
    IrInstSrcIdFloatToInt,
    IrInstSrcIdBoolToInt,
    IrInstSrcIdVectorType,
    IrInstSrcIdShuffleVector,
    IrInstSrcIdSplat,
    IrInstSrcIdBoolNot,
    IrInstSrcIdMemset,
    IrInstSrcIdMemcpy,
    IrInstSrcIdSlice,
    IrInstSrcIdBreakpoint,
    IrInstSrcIdReturnAddress,
    IrInstSrcIdFrameAddress,
    IrInstSrcIdFrameHandle,
    IrInstSrcIdFrameType,
    IrInstSrcIdFrameSize,
    IrInstSrcIdAlignOf,
    IrInstSrcIdOverflowOp,
    IrInstSrcIdTestErr,
    IrInstSrcIdMulAdd,
    IrInstSrcIdFloatOp,
    IrInstSrcIdUnwrapErrCode,
    IrInstSrcIdUnwrapErrPayload,
    IrInstSrcIdFnProto,
    IrInstSrcIdTestComptime,
    IrInstSrcIdPtrCast,
    IrInstSrcIdBitCast,
    IrInstSrcIdIntToPtr,
    IrInstSrcIdPtrToInt,
    IrInstSrcIdIntToEnum,
    IrInstSrcIdEnumToInt,
    IrInstSrcIdIntToErr,
    IrInstSrcIdErrToInt,
    IrInstSrcIdCheckSwitchProngsUnderYes,
    IrInstSrcIdCheckSwitchProngsUnderNo,
    IrInstSrcIdCheckStatementIsVoid,
    IrInstSrcIdTypeName,
    IrInstSrcIdDeclRef,
    IrInstSrcIdPanic,
    IrInstSrcIdTagName,
    IrInstSrcIdFieldParentPtr,
    IrInstSrcIdOffsetOf,
    IrInstSrcIdBitOffsetOf,
    IrInstSrcIdTypeInfo,
    IrInstSrcIdType,
    IrInstSrcIdHasField,
    IrInstSrcIdSetEvalBranchQuota,
    IrInstSrcIdPtrType,
    IrInstSrcIdPtrTypeSimple,
    IrInstSrcIdPtrTypeSimpleConst,
    IrInstSrcIdAlignCast,
    IrInstSrcIdImplicitCast,
    IrInstSrcIdResolveResult,
    IrInstSrcIdResetResult,
    IrInstSrcIdSetAlignStack,
    IrInstSrcIdArgTypeAllowVarFalse,
    IrInstSrcIdArgTypeAllowVarTrue,
    IrInstSrcIdExport,
    IrInstSrcIdExtern,
    IrInstSrcIdErrorReturnTrace,
    IrInstSrcIdErrorUnion,
    IrInstSrcIdAtomicRmw,
    IrInstSrcIdAtomicLoad,
    IrInstSrcIdAtomicStore,
    IrInstSrcIdSaveErrRetAddr,
    IrInstSrcIdAddImplicitReturnType,
    IrInstSrcIdErrSetCast,
    IrInstSrcIdCheckRuntimeScope,
    IrInstSrcIdHasDecl,
    IrInstSrcIdUndeclaredIdent,
    IrInstSrcIdAlloca,
    IrInstSrcIdEndExpr,
    IrInstSrcIdUnionInitNamedField,
    IrInstSrcIdSuspendBegin,
    IrInstSrcIdSuspendFinish,
    IrInstSrcIdAwait,
    IrInstSrcIdResume,
    IrInstSrcIdSpillBegin,
    IrInstSrcIdSpillEnd,
    IrInstSrcIdWasmMemorySize,
    IrInstSrcIdWasmMemoryGrow,
    IrInstSrcIdSrc,
};

// ir_render_* functions in codegen.cpp consume Gen instructions and produce LLVM IR.
// Src instructions do not have type information; Gen instructions do.
enum IrInstGenId {
    IrInstGenIdInvalid,
    IrInstGenIdDeclVar,
    IrInstGenIdBr,
    IrInstGenIdCondBr,
    IrInstGenIdSwitchBr,
    IrInstGenIdPhi,
    IrInstGenIdBinaryNot,
    IrInstGenIdNegation,
    IrInstGenIdBinOp,
    IrInstGenIdLoadPtr,
    IrInstGenIdStorePtr,
    IrInstGenIdVectorStoreElem,
    IrInstGenIdStructFieldPtr,
    IrInstGenIdUnionFieldPtr,
    IrInstGenIdElemPtr,
    IrInstGenIdVarPtr,
    IrInstGenIdReturnPtr,
    IrInstGenIdCall,
    IrInstGenIdReturn,
    IrInstGenIdCast,
    IrInstGenIdUnreachable,
    IrInstGenIdAsm,
    IrInstGenIdTestNonNull,
    IrInstGenIdOptionalUnwrapPtr,
    IrInstGenIdOptionalWrap,
    IrInstGenIdUnionTag,
    IrInstGenIdClz,
    IrInstGenIdCtz,
    IrInstGenIdPopCount,
    IrInstGenIdBswap,
    IrInstGenIdBitReverse,
    IrInstGenIdRef,
    IrInstGenIdErrName,
    IrInstGenIdCmpxchg,
    IrInstGenIdFence,
    IrInstGenIdReduce,
    IrInstGenIdTruncate,
    IrInstGenIdShuffleVector,
    IrInstGenIdSplat,
    IrInstGenIdBoolNot,
    IrInstGenIdMemset,
    IrInstGenIdMemcpy,
    IrInstGenIdSlice,
    IrInstGenIdBreakpoint,
    IrInstGenIdReturnAddress,
    IrInstGenIdFrameAddress,
    IrInstGenIdFrameHandle,
    IrInstGenIdFrameSize,
    IrInstGenIdOverflowOp,
    IrInstGenIdTestErr,
    IrInstGenIdMulAdd,
    IrInstGenIdFloatOp,
    IrInstGenIdUnwrapErrCode,
    IrInstGenIdUnwrapErrPayload,
    IrInstGenIdErrWrapCode,
    IrInstGenIdErrWrapPayload,
    IrInstGenIdPtrCast,
    IrInstGenIdBitCast,
    IrInstGenIdWidenOrShorten,
    IrInstGenIdIntToPtr,
    IrInstGenIdPtrToInt,
    IrInstGenIdIntToEnum,
    IrInstGenIdIntToErr,
    IrInstGenIdErrToInt,
    IrInstGenIdPanic,
    IrInstGenIdTagName,
    IrInstGenIdFieldParentPtr,
    IrInstGenIdAlignCast,
    IrInstGenIdErrorReturnTrace,
    IrInstGenIdAtomicRmw,
    IrInstGenIdAtomicLoad,
    IrInstGenIdAtomicStore,
    IrInstGenIdSaveErrRetAddr,
    IrInstGenIdVectorToArray,
    IrInstGenIdArrayToVector,
    IrInstGenIdAssertZero,
    IrInstGenIdAssertNonNull,
    IrInstGenIdPtrOfArrayToSlice,
    IrInstGenIdSuspendBegin,
    IrInstGenIdSuspendFinish,
    IrInstGenIdAwait,
    IrInstGenIdResume,
    IrInstGenIdSpillBegin,
    IrInstGenIdSpillEnd,
    IrInstGenIdVectorExtractElem,
    IrInstGenIdAlloca,
    IrInstGenIdConst,
    IrInstGenIdWasmMemorySize,
    IrInstGenIdWasmMemoryGrow,
    IrInstGenIdExtern,
};

// Common fields between IrInstSrc and IrInstGen.
struct IrInst {
    // if ref_count is zero and the instruction has no side effects,
    // the instruction can be omitted in codegen
    uint32_t ref_count;
    uint32_t debug_id;

    Scope *scope;
    AstNode *source_node;

    // for debugging purposes, these are useful to call to inspect the instruction
    void dump();
    void src();
};

struct IrInstSrc {
    IrInst base;

    IrInstSrcId id;
    // true if this instruction was generated by zig and not from user code
    // this matters for the "unreachable code" compile error
    bool is_gen;
    bool is_noreturn;

    // When analyzing IR, instructions that point to this instruction in the "old ir"
    // can find the instruction that corresponds to this value in the "new ir"
    // with this child field.
    IrInstGen *child;
    Stage1ZirBasicBlock *owner_bb;

    // for debugging purposes, these are useful to call to inspect the instruction
    void dump();
    void src();
};

struct IrInstGen {
    IrInst base;

    IrInstGenId id;

    LLVMValueRef llvm_value;
    ZigValue *value;
    IrBasicBlockGen *owner_bb;
    // Nearly any instruction can have to be stored as a local variable before suspending
    // and then loaded after resuming, in case there is an expression with a suspend point
    // in it, such as: x + await y
    IrInstGen *spill;

    // for debugging purposes, these are useful to call to inspect the instruction
    void dump();
    void src();
};

struct IrInstSrcDeclVar {
    IrInstSrc base;

    ZigVar *var;
    IrInstSrc *var_type;
    IrInstSrc *align_value;
    IrInstSrc *ptr;
};

struct IrInstGenDeclVar {
    IrInstGen base;

    ZigVar *var;
    IrInstGen *var_ptr;
};

struct IrInstSrcCondBr {
    IrInstSrc base;

    IrInstSrc *condition;
    Stage1ZirBasicBlock *then_block;
    Stage1ZirBasicBlock *else_block;
    IrInstSrc *is_comptime;
    ResultLoc *result_loc;
};

struct IrInstGenCondBr {
    IrInstGen base;

    IrInstGen *condition;
    IrBasicBlockGen *then_block;
    IrBasicBlockGen *else_block;
};

struct IrInstSrcBr {
    IrInstSrc base;

    Stage1ZirBasicBlock *dest_block;
    IrInstSrc *is_comptime;
};

struct IrInstGenBr {
    IrInstGen base;

    IrBasicBlockGen *dest_block;
};

struct IrInstSrcSwitchBrCase {
    IrInstSrc *value;
    Stage1ZirBasicBlock *block;
};

struct IrInstSrcSwitchBr {
    IrInstSrc base;

    IrInstSrc *target_value;
    Stage1ZirBasicBlock *else_block;
    size_t case_count;
    IrInstSrcSwitchBrCase *cases;
    IrInstSrc *is_comptime;
    IrInstSrc *switch_prongs_void;
};

struct IrInstGenSwitchBrCase {
    IrInstGen *value;
    IrBasicBlockGen *block;
};

struct IrInstGenSwitchBr {
    IrInstGen base;

    IrInstGen *target_value;
    IrBasicBlockGen *else_block;
    size_t case_count;
    IrInstGenSwitchBrCase *cases;
};

struct IrInstSrcSwitchVar {
    IrInstSrc base;

    IrInstSrc *target_value_ptr;
    IrInstSrc **prongs_ptr;
    size_t prongs_len;
};

struct IrInstSrcSwitchElseVar {
    IrInstSrc base;

    IrInstSrc *target_value_ptr;
    IrInstSrcSwitchBr *switch_br;
};

struct IrInstSrcSwitchTarget {
    IrInstSrc base;

    IrInstSrc *target_value_ptr;
};

struct IrInstSrcPhi {
    IrInstSrc base;

    size_t incoming_count;
    Stage1ZirBasicBlock **incoming_blocks;
    IrInstSrc **incoming_values;
    ResultLocPeerParent *peer_parent;
};

struct IrInstGenPhi {
    IrInstGen base;

    size_t incoming_count;
    IrBasicBlockGen **incoming_blocks;
    IrInstGen **incoming_values;
};

enum IrUnOp {
    IrUnOpInvalid,
    IrUnOpBinNot,
    IrUnOpNegation,
    IrUnOpNegationWrap,
    IrUnOpDereference,
    IrUnOpOptional,
};

struct IrInstSrcUnOp {
    IrInstSrc base;

    IrUnOp op_id;
    LVal lval;
    IrInstSrc *value;
    ResultLoc *result_loc;
};

struct IrInstGenBinaryNot {
    IrInstGen base;
    IrInstGen *operand;
};

struct IrInstGenNegation {
    IrInstGen base;
    IrInstGen *operand;
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

struct IrInstSrcBinOp {
    IrInstSrc base;

    IrInstSrc *op1;
    IrInstSrc *op2;
    IrBinOp op_id;
    bool safety_check_on;
};

struct IrInstGenBinOp {
    IrInstGen base;

    IrInstGen *op1;
    IrInstGen *op2;
    IrBinOp op_id;
    bool safety_check_on;
};

struct IrInstSrcMergeErrSets {
    IrInstSrc base;

    IrInstSrc *op1;
    IrInstSrc *op2;
    Buf *type_name;
};

struct IrInstSrcLoadPtr {
    IrInstSrc base;

    IrInstSrc *ptr;
};

struct IrInstGenLoadPtr {
    IrInstGen base;

    IrInstGen *ptr;
    IrInstGen *result_loc;
};

struct IrInstSrcStorePtr {
    IrInstSrc base;

    IrInstSrc *ptr;
    IrInstSrc *value;

    bool allow_write_through_const;
};

struct IrInstGenStorePtr {
    IrInstGen base;

    IrInstGen *ptr;
    IrInstGen *value;
};

struct IrInstGenVectorStoreElem {
    IrInstGen base;

    IrInstGen *vector_ptr;
    IrInstGen *index;
    IrInstGen *value;
};

struct IrInstSrcFieldPtr {
    IrInstSrc base;

    IrInstSrc *container_ptr;
    Buf *field_name_buffer;
    IrInstSrc *field_name_expr;
    bool initializing;
};

struct IrInstGenStructFieldPtr {
    IrInstGen base;

    IrInstGen *struct_ptr;
    TypeStructField *field;
    bool is_const;
};

struct IrInstGenUnionFieldPtr {
    IrInstGen base;

    IrInstGen *union_ptr;
    TypeUnionField *field;
    bool safety_check_on;
    bool initializing;
};

struct IrInstSrcElemPtr {
    IrInstSrc base;

    IrInstSrc *array_ptr;
    IrInstSrc *elem_index;
    AstNode *init_array_type_source_node;
    PtrLen ptr_len;
    bool safety_check_on;
};

struct IrInstGenElemPtr {
    IrInstGen base;

    IrInstGen *array_ptr;
    IrInstGen *elem_index;
    bool safety_check_on;
};

struct IrInstSrcVarPtr {
    IrInstSrc base;

    ZigVar *var;
    ScopeFnDef *crossed_fndef_scope;
};

struct IrInstGenVarPtr {
    IrInstGen base;

    ZigVar *var;
};

// For functions that have a return type for which handle_is_ptr is true, a
// result location pointer is the secret first parameter ("sret"). This
// instruction returns that pointer.
struct IrInstGenReturnPtr {
    IrInstGen base;
};

struct IrInstSrcCall {
    IrInstSrc base;

    IrInstSrc *fn_ref;
    ZigFn *fn_entry;
    size_t arg_count;
    IrInstSrc **args;
    IrInstSrc *ret_ptr;
    ResultLoc *result_loc;

    IrInstSrc *new_stack;

    CallModifier modifier;
    bool is_async_call_builtin;
};

// This is a pass1 instruction, used by @call when the args node is
// a tuple or struct literal.
struct IrInstSrcCallArgs {
    IrInstSrc base;

    IrInstSrc *options;
    IrInstSrc *fn_ref;
    IrInstSrc **args_ptr;
    size_t args_len;
    ResultLoc *result_loc;
};

// This is a pass1 instruction, used by @call, when the args node
// is not a literal.
// `args` is expected to be either a struct or a tuple.
struct IrInstSrcCallExtra {
    IrInstSrc base;

    IrInstSrc *options;
    IrInstSrc *fn_ref;
    IrInstSrc *args;
    ResultLoc *result_loc;
};

// This is a pass1 instruction, used by @asyncCall, when the args node
// is not a literal.
// `args` is expected to be either a struct or a tuple.
struct IrInstSrcAsyncCallExtra {
    IrInstSrc base;

    CallModifier modifier;
    IrInstSrc *fn_ref;
    IrInstSrc *ret_ptr;
    IrInstSrc *new_stack;
    IrInstSrc *args;
    ResultLoc *result_loc;
};

struct IrInstGenCall {
    IrInstGen base;

    IrInstGen *fn_ref;
    ZigFn *fn_entry;
    size_t arg_count;
    IrInstGen **args;
    IrInstGen *result_loc;
    IrInstGen *frame_result_loc;
    IrInstGen *new_stack;

    CallModifier modifier;

    bool is_async_call_builtin;
};

struct IrInstSrcConst {
    IrInstSrc base;

    ZigValue *value;
};

struct IrInstGenConst {
    IrInstGen base;
};

struct IrInstSrcReturn {
    IrInstSrc base;

    IrInstSrc *operand;
};

// When an IrExecutable is not in a function, a return instruction means that
// the expression returns with that value, even though a return statement from
// an AST perspective is invalid.
struct IrInstGenReturn {
    IrInstGen base;

    IrInstGen *operand;
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
struct IrInstGenCast {
    IrInstGen base;

    IrInstGen *value;
    CastOp cast_op;
};

struct IrInstSrcContainerInitList {
    IrInstSrc base;

    IrInstSrc *elem_type;
    size_t item_count;
    IrInstSrc **elem_result_loc_list;
    IrInstSrc *result_loc;
    AstNode *init_array_type_source_node;
};

struct IrInstSrcContainerInitFieldsField {
    Buf *name;
    AstNode *source_node;
    IrInstSrc *result_loc;
};

struct IrInstSrcContainerInitFields {
    IrInstSrc base;

    size_t field_count;
    IrInstSrcContainerInitFieldsField *fields;
    IrInstSrc *result_loc;
};

struct IrInstSrcUnreachable {
    IrInstSrc base;
};

struct IrInstGenUnreachable {
    IrInstGen base;
};

struct IrInstSrcTypeOf {
    IrInstSrc base;

    union {
        IrInstSrc *scalar; // value_count == 1
        IrInstSrc **list; // value_count > 1
    } value;
    size_t value_count;
};

struct IrInstSrcSetCold {
    IrInstSrc base;

    IrInstSrc *is_cold;
};

struct IrInstSrcSetRuntimeSafety {
    IrInstSrc base;

    IrInstSrc *safety_on;
};

struct IrInstSrcSetFloatMode {
    IrInstSrc base;

    IrInstSrc *scope_value;
    IrInstSrc *mode_value;
};

struct IrInstSrcArrayType {
    IrInstSrc base;

    IrInstSrc *size;
    IrInstSrc *sentinel;
    IrInstSrc *child_type;
};

struct IrInstSrcPtrTypeSimple {
    IrInstSrc base;

    IrInstSrc *child_type;
};

struct IrInstSrcPtrType {
    IrInstSrc base;

    IrInstSrc *sentinel;
    IrInstSrc *align_value;
    IrInstSrc *child_type;
    uint32_t bit_offset_start;
    uint32_t host_int_bytes;
    PtrLen ptr_len;
    bool is_const;
    bool is_volatile;
    bool is_allow_zero;
};

struct IrInstSrcAnyFrameType {
    IrInstSrc base;

    IrInstSrc *payload_type;
};

struct IrInstSrcSliceType {
    IrInstSrc base;

    IrInstSrc *sentinel;
    IrInstSrc *align_value;
    IrInstSrc *child_type;
    bool is_const;
    bool is_volatile;
    bool is_allow_zero;
};

struct IrInstSrcAsm {
    IrInstSrc base;

    IrInstSrc *asm_template;
    IrInstSrc **input_list;
    IrInstSrc **output_types;
    ZigVar **output_vars;
    size_t return_count;
    bool has_side_effects;
    bool is_global;
};

struct IrInstGenAsm {
    IrInstGen base;

    Buf *asm_template;
    AsmToken *token_list;
    size_t token_list_len;
    IrInstGen **input_list;
    IrInstGen **output_types;
    ZigVar **output_vars;
    size_t return_count;
    bool has_side_effects;
};

struct IrInstSrcSizeOf {
    IrInstSrc base;

    IrInstSrc *type_value;
    bool bit_size;
};

// returns true if nonnull, returns false if null
struct IrInstSrcTestNonNull {
    IrInstSrc base;

    IrInstSrc *value;
};

struct IrInstGenTestNonNull {
    IrInstGen base;

    IrInstGen *value;
};

// Takes a pointer to an optional value, returns a pointer
// to the payload.
struct IrInstSrcOptionalUnwrapPtr {
    IrInstSrc base;

    IrInstSrc *base_ptr;
    bool safety_check_on;
};

struct IrInstGenOptionalUnwrapPtr {
    IrInstGen base;

    IrInstGen *base_ptr;
    bool safety_check_on;
    bool initializing;
};

struct IrInstSrcCtz {
    IrInstSrc base;

    IrInstSrc *type;
    IrInstSrc *op;
};

struct IrInstGenCtz {
    IrInstGen base;

    IrInstGen *op;
};

struct IrInstSrcClz {
    IrInstSrc base;

    IrInstSrc *type;
    IrInstSrc *op;
};

struct IrInstGenClz {
    IrInstGen base;

    IrInstGen *op;
};

struct IrInstSrcPopCount {
    IrInstSrc base;

    IrInstSrc *type;
    IrInstSrc *op;
};

struct IrInstGenPopCount {
    IrInstGen base;

    IrInstGen *op;
};

struct IrInstGenUnionTag {
    IrInstGen base;

    IrInstGen *value;
};

struct IrInstSrcImport {
    IrInstSrc base;

    IrInstSrc *name;
};

struct IrInstSrcRef {
    IrInstSrc base;

    IrInstSrc *value;
};

struct IrInstGenRef {
    IrInstGen base;

    IrInstGen *operand;
    IrInstGen *result_loc;
};

struct IrInstSrcCompileErr {
    IrInstSrc base;

    IrInstSrc *msg;
};

struct IrInstSrcCompileLog {
    IrInstSrc base;

    size_t msg_count;
    IrInstSrc **msg_list;
};

struct IrInstSrcErrName {
    IrInstSrc base;

    IrInstSrc *value;
};

struct IrInstGenErrName {
    IrInstGen base;

    IrInstGen *value;
};

struct IrInstSrcCImport {
    IrInstSrc base;
};

struct IrInstSrcCInclude {
    IrInstSrc base;

    IrInstSrc *name;
};

struct IrInstSrcCDefine {
    IrInstSrc base;

    IrInstSrc *name;
    IrInstSrc *value;
};

struct IrInstSrcCUndef {
    IrInstSrc base;

    IrInstSrc *name;
};

struct IrInstSrcEmbedFile {
    IrInstSrc base;

    IrInstSrc *name;
};

struct IrInstSrcCmpxchg {
    IrInstSrc base;

    bool is_weak;
    IrInstSrc *type_value;
    IrInstSrc *ptr;
    IrInstSrc *cmp_value;
    IrInstSrc *new_value;
    IrInstSrc *success_order_value;
    IrInstSrc *failure_order_value;
    ResultLoc *result_loc;
};

struct IrInstGenCmpxchg {
    IrInstGen base;

    AtomicOrder success_order;
    AtomicOrder failure_order;
    IrInstGen *ptr;
    IrInstGen *cmp_value;
    IrInstGen *new_value;
    IrInstGen *result_loc;
    bool is_weak;
};

struct IrInstSrcFence {
    IrInstSrc base;

    IrInstSrc *order;
};

struct IrInstGenFence {
    IrInstGen base;

    AtomicOrder order;
};

struct IrInstSrcReduce {
    IrInstSrc base;

    IrInstSrc *op;
    IrInstSrc *value;
};

struct IrInstGenReduce {
    IrInstGen base;

    ReduceOp op;
    IrInstGen *value;
};

struct IrInstSrcTruncate {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstGenTruncate {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcIntCast {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstSrcFloatCast {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstSrcErrSetCast {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstSrcIntToFloat {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstSrcFloatToInt {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstSrcBoolToInt {
    IrInstSrc base;

    IrInstSrc *target;
};

struct IrInstSrcVectorType {
    IrInstSrc base;

    IrInstSrc *len;
    IrInstSrc *elem_type;
};

struct IrInstSrcBoolNot {
    IrInstSrc base;

    IrInstSrc *value;
};

struct IrInstGenBoolNot {
    IrInstGen base;

    IrInstGen *value;
};

struct IrInstSrcMemset {
    IrInstSrc base;

    IrInstSrc *dest_ptr;
    IrInstSrc *byte;
    IrInstSrc *count;
};

struct IrInstGenMemset {
    IrInstGen base;

    IrInstGen *dest_ptr;
    IrInstGen *byte;
    IrInstGen *count;
};

struct IrInstSrcMemcpy {
    IrInstSrc base;

    IrInstSrc *dest_ptr;
    IrInstSrc *src_ptr;
    IrInstSrc *count;
};

struct IrInstGenMemcpy {
    IrInstGen base;

    IrInstGen *dest_ptr;
    IrInstGen *src_ptr;
    IrInstGen *count;
};

struct IrInstSrcWasmMemorySize {
    IrInstSrc base;

    IrInstSrc *index;
};

struct IrInstGenWasmMemorySize {
    IrInstGen base;

    IrInstGen *index;
};

struct IrInstSrcWasmMemoryGrow {
    IrInstSrc base;

    IrInstSrc *index;
    IrInstSrc *delta;
};

struct IrInstGenWasmMemoryGrow {
    IrInstGen base;

    IrInstGen *index;
    IrInstGen *delta;
};

struct IrInstSrcSrc {
    IrInstSrc base;
};

struct IrInstSrcSlice {
    IrInstSrc base;

    IrInstSrc *ptr;
    IrInstSrc *start;
    IrInstSrc *end;
    IrInstSrc *sentinel;
    ResultLoc *result_loc;
    bool safety_check_on;
};

struct IrInstGenSlice {
    IrInstGen base;

    IrInstGen *ptr;
    IrInstGen *start;
    IrInstGen *end;
    IrInstGen *result_loc;
    ZigValue *sentinel;
    bool safety_check_on;
};

struct IrInstSrcBreakpoint {
    IrInstSrc base;
};

struct IrInstGenBreakpoint {
    IrInstGen base;
};

struct IrInstSrcReturnAddress {
    IrInstSrc base;
};

struct IrInstGenReturnAddress {
    IrInstGen base;
};

struct IrInstSrcFrameAddress {
    IrInstSrc base;
};

struct IrInstGenFrameAddress {
    IrInstGen base;
};

struct IrInstSrcFrameHandle {
    IrInstSrc base;
};

struct IrInstGenFrameHandle {
    IrInstGen base;
};

struct IrInstSrcFrameType {
    IrInstSrc base;

    IrInstSrc *fn;
};

struct IrInstSrcFrameSize {
    IrInstSrc base;

    IrInstSrc *fn;
};

struct IrInstGenFrameSize {
    IrInstGen base;

    IrInstGen *fn;
};

enum IrOverflowOp {
    IrOverflowOpAdd,
    IrOverflowOpSub,
    IrOverflowOpMul,
    IrOverflowOpShl,
};

struct IrInstSrcOverflowOp {
    IrInstSrc base;

    IrOverflowOp op;
    IrInstSrc *type_value;
    IrInstSrc *op1;
    IrInstSrc *op2;
    IrInstSrc *result_ptr;
};

struct IrInstGenOverflowOp {
    IrInstGen base;

    IrOverflowOp op;
    IrInstGen *op1;
    IrInstGen *op2;
    IrInstGen *result_ptr;

    // TODO can this field be removed?
    ZigType *result_ptr_type;
};

struct IrInstSrcMulAdd {
    IrInstSrc base;

    IrInstSrc *type_value;
    IrInstSrc *op1;
    IrInstSrc *op2;
    IrInstSrc *op3;
};

struct IrInstGenMulAdd {
    IrInstGen base;

    IrInstGen *op1;
    IrInstGen *op2;
    IrInstGen *op3;
};

struct IrInstSrcAlignOf {
    IrInstSrc base;

    IrInstSrc *type_value;
};

// returns true if error, returns false if not error
struct IrInstSrcTestErr {
    IrInstSrc base;

    IrInstSrc *base_ptr;
    bool resolve_err_set;
    bool base_ptr_is_payload;
};

struct IrInstGenTestErr {
    IrInstGen base;

    IrInstGen *err_union;
};

// Takes an error union pointer, returns a pointer to the error code.
struct IrInstSrcUnwrapErrCode {
    IrInstSrc base;

    IrInstSrc *err_union_ptr;
    bool initializing;
};

struct IrInstGenUnwrapErrCode {
    IrInstGen base;

    IrInstGen *err_union_ptr;
    bool initializing;
};

struct IrInstSrcUnwrapErrPayload {
    IrInstSrc base;

    IrInstSrc *value;
    bool safety_check_on;
    bool initializing;
};

struct IrInstGenUnwrapErrPayload {
    IrInstGen base;

    IrInstGen *value;
    bool safety_check_on;
    bool initializing;
};

struct IrInstGenOptionalWrap {
    IrInstGen base;

    IrInstGen *operand;
    IrInstGen *result_loc;
};

struct IrInstGenErrWrapPayload {
    IrInstGen base;

    IrInstGen *operand;
    IrInstGen *result_loc;
};

struct IrInstGenErrWrapCode {
    IrInstGen base;

    IrInstGen *operand;
    IrInstGen *result_loc;
};

struct IrInstSrcFnProto {
    IrInstSrc base;

    IrInstSrc **param_types;
    IrInstSrc *align_value;
    IrInstSrc *callconv_value;
    IrInstSrc *return_type;
    bool is_var_args;
};

// true if the target value is compile time known, false otherwise
struct IrInstSrcTestComptime {
    IrInstSrc base;

    IrInstSrc *value;
};

struct IrInstSrcPtrCast {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *ptr;
    bool safety_check_on;
};

struct IrInstGenPtrCast {
    IrInstGen base;

    IrInstGen *ptr;
    bool safety_check_on;
};

struct IrInstSrcImplicitCast {
    IrInstSrc base;

    IrInstSrc *operand;
    ResultLocCast *result_loc_cast;
};

struct IrInstSrcBitCast {
    IrInstSrc base;

    IrInstSrc *operand;
    ResultLocBitCast *result_loc_bit_cast;
};

struct IrInstGenBitCast {
    IrInstGen base;

    IrInstGen *operand;
};

struct IrInstGenWidenOrShorten {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcPtrToInt {
    IrInstSrc base;

    IrInstSrc *target;
};

struct IrInstGenPtrToInt {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcIntToPtr {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstGenIntToPtr {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcIntToEnum {
    IrInstSrc base;

    IrInstSrc *dest_type;
    IrInstSrc *target;
};

struct IrInstGenIntToEnum {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcEnumToInt {
    IrInstSrc base;

    IrInstSrc *target;
};

struct IrInstSrcIntToErr {
    IrInstSrc base;

    IrInstSrc *target;
};

struct IrInstGenIntToErr {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcErrToInt {
    IrInstSrc base;

    IrInstSrc *target;
};

struct IrInstGenErrToInt {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcCheckSwitchProngsRange {
    IrInstSrc *start;
    IrInstSrc *end;
};

struct IrInstSrcCheckSwitchProngs {
    IrInstSrc base;

    IrInstSrc *target_value;
    IrInstSrcCheckSwitchProngsRange *ranges;
    size_t range_count;
    AstNode* else_prong;
};

struct IrInstSrcCheckStatementIsVoid {
    IrInstSrc base;

    IrInstSrc *statement_value;
};

struct IrInstSrcTypeName {
    IrInstSrc base;

    IrInstSrc *type_value;
};

struct IrInstSrcDeclRef {
    IrInstSrc base;

    LVal lval;
    Tld *tld;
};

struct IrInstSrcPanic {
    IrInstSrc base;

    IrInstSrc *msg;
};

struct IrInstGenPanic {
    IrInstGen base;

    IrInstGen *msg;
};

struct IrInstSrcTagName {
    IrInstSrc base;

    IrInstSrc *target;
};

struct IrInstGenTagName {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcFieldParentPtr {
    IrInstSrc base;

    IrInstSrc *type_value;
    IrInstSrc *field_name;
    IrInstSrc *field_ptr;
};

struct IrInstGenFieldParentPtr {
    IrInstGen base;

    IrInstGen *field_ptr;
    TypeStructField *field;
};

struct IrInstSrcOffsetOf {
    IrInstSrc base;

    IrInstSrc *type_value;
    IrInstSrc *field_name;
};

struct IrInstSrcBitOffsetOf {
    IrInstSrc base;

    IrInstSrc *type_value;
    IrInstSrc *field_name;
};

struct IrInstSrcTypeInfo {
    IrInstSrc base;

    IrInstSrc *type_value;
};

struct IrInstSrcType {
    IrInstSrc base;

    IrInstSrc *type_info;
};

struct IrInstSrcHasField {
    IrInstSrc base;

    IrInstSrc *container_type;
    IrInstSrc *field_name;
};

struct IrInstSrcSetEvalBranchQuota {
    IrInstSrc base;

    IrInstSrc *new_quota;
};

struct IrInstSrcAlignCast {
    IrInstSrc base;

    IrInstSrc *align_bytes;
    IrInstSrc *target;
};

struct IrInstGenAlignCast {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcSetAlignStack {
    IrInstSrc base;

    IrInstSrc *align_bytes;
};

struct IrInstSrcArgType {
    IrInstSrc base;

    IrInstSrc *fn_type;
    IrInstSrc *arg_index;
};

struct IrInstSrcExport {
    IrInstSrc base;

    IrInstSrc *target;
    IrInstSrc *options;
};

struct IrInstSrcExtern {
    IrInstSrc base;

    IrInstSrc *type;
    IrInstSrc *options;
};

struct IrInstGenExtern {
    IrInstGen base;

    Buf *name;
    GlobalLinkageId linkage;
    bool is_thread_local;
};

enum IrInstErrorReturnTraceOptional {
    IrInstErrorReturnTraceNull,
    IrInstErrorReturnTraceNonNull,
};

struct IrInstSrcErrorReturnTrace {
    IrInstSrc base;

    IrInstErrorReturnTraceOptional optional;
};

struct IrInstGenErrorReturnTrace {
    IrInstGen base;

    IrInstErrorReturnTraceOptional optional;
};

struct IrInstSrcErrorUnion {
    IrInstSrc base;

    IrInstSrc *err_set;
    IrInstSrc *payload;
    Buf *type_name;
};

struct IrInstSrcAtomicRmw {
    IrInstSrc base;

    IrInstSrc *operand_type;
    IrInstSrc *ptr;
    IrInstSrc *op;
    IrInstSrc *operand;
    IrInstSrc *ordering;
};

struct IrInstGenAtomicRmw {
    IrInstGen base;

    IrInstGen *ptr;
    IrInstGen *operand;
    AtomicRmwOp op;
    AtomicOrder ordering;
};

struct IrInstSrcAtomicLoad {
    IrInstSrc base;

    IrInstSrc *operand_type;
    IrInstSrc *ptr;
    IrInstSrc *ordering;
};

struct IrInstGenAtomicLoad {
    IrInstGen base;

    IrInstGen *ptr;
    AtomicOrder ordering;
};

struct IrInstSrcAtomicStore {
    IrInstSrc base;

    IrInstSrc *operand_type;
    IrInstSrc *ptr;
    IrInstSrc *value;
    IrInstSrc *ordering;
};

struct IrInstGenAtomicStore {
    IrInstGen base;

    IrInstGen *ptr;
    IrInstGen *value;
    AtomicOrder ordering;
};

struct IrInstSrcSaveErrRetAddr {
    IrInstSrc base;
};

struct IrInstGenSaveErrRetAddr {
    IrInstGen base;
};

struct IrInstSrcAddImplicitReturnType {
    IrInstSrc base;

    IrInstSrc *value;
    ResultLocReturn *result_loc_ret;
};

// For float ops that take a single argument
struct IrInstSrcFloatOp {
    IrInstSrc base;

    IrInstSrc *operand;
    BuiltinFnId fn_id;
};

struct IrInstGenFloatOp {
    IrInstGen base;

    IrInstGen *operand;
    BuiltinFnId fn_id;
};

struct IrInstSrcCheckRuntimeScope {
    IrInstSrc base;

    IrInstSrc *scope_is_comptime;
    IrInstSrc *is_comptime;
};

struct IrInstSrcBswap {
    IrInstSrc base;

    IrInstSrc *type;
    IrInstSrc *op;
};

struct IrInstGenBswap {
    IrInstGen base;

    IrInstGen *op;
};

struct IrInstSrcBitReverse {
    IrInstSrc base;

    IrInstSrc *type;
    IrInstSrc *op;
};

struct IrInstGenBitReverse {
    IrInstGen base;

    IrInstGen *op;
};

struct IrInstGenArrayToVector {
    IrInstGen base;

    IrInstGen *array;
};

struct IrInstGenVectorToArray {
    IrInstGen base;

    IrInstGen *vector;
    IrInstGen *result_loc;
};

struct IrInstSrcShuffleVector {
    IrInstSrc base;

    IrInstSrc *scalar_type;
    IrInstSrc *a;
    IrInstSrc *b;
    IrInstSrc *mask; // This is in zig-format, not llvm format
};

struct IrInstGenShuffleVector {
    IrInstGen base;

    IrInstGen *a;
    IrInstGen *b;
    IrInstGen *mask; // This is in zig-format, not llvm format
};

struct IrInstSrcSplat {
    IrInstSrc base;

    IrInstSrc *len;
    IrInstSrc *scalar;
};

struct IrInstGenSplat {
    IrInstGen base;

    IrInstGen *scalar;
};

struct IrInstGenAssertZero {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstGenAssertNonNull {
    IrInstGen base;

    IrInstGen *target;
};

struct IrInstSrcUnionInitNamedField {
    IrInstSrc base;

    IrInstSrc *union_type;
    IrInstSrc *field_name;
    IrInstSrc *field_result_loc;
    IrInstSrc *result_loc;
};

struct IrInstSrcHasDecl {
    IrInstSrc base;

    IrInstSrc *container;
    IrInstSrc *name;
};

struct IrInstSrcUndeclaredIdent {
    IrInstSrc base;

    Buf *name;
};

struct IrInstSrcAlloca {
    IrInstSrc base;

    IrInstSrc *align;
    IrInstSrc *is_comptime;
    const char *name_hint;
};

struct IrInstGenAlloca {
    IrInstGen base;

    uint32_t align;
    const char *name_hint;
    size_t field_index;
};

struct IrInstSrcEndExpr {
    IrInstSrc base;

    IrInstSrc *value;
    ResultLoc *result_loc;
};

// This one is for writing through the result pointer.
struct IrInstSrcResolveResult {
    IrInstSrc base;

    ResultLoc *result_loc;
    IrInstSrc *ty;
};

struct IrInstSrcResetResult {
    IrInstSrc base;

    ResultLoc *result_loc;
};

struct IrInstGenPtrOfArrayToSlice {
    IrInstGen base;

    IrInstGen *operand;
    IrInstGen *result_loc;
};

struct IrInstSrcSuspendBegin {
    IrInstSrc base;
};

struct IrInstGenSuspendBegin {
    IrInstGen base;

    LLVMBasicBlockRef resume_bb;
};

struct IrInstSrcSuspendFinish {
    IrInstSrc base;

    IrInstSrcSuspendBegin *begin;
};

struct IrInstGenSuspendFinish {
    IrInstGen base;

    IrInstGenSuspendBegin *begin;
};

struct IrInstSrcAwait {
    IrInstSrc base;

    IrInstSrc *frame;
    ResultLoc *result_loc;
    bool is_nosuspend;
};

struct IrInstGenAwait {
    IrInstGen base;

    IrInstGen *frame;
    IrInstGen *result_loc;
    ZigFn *target_fn;
    bool is_nosuspend;
};

struct IrInstSrcResume {
    IrInstSrc base;

    IrInstSrc *frame;
};

struct IrInstGenResume {
    IrInstGen base;

    IrInstGen *frame;
};

enum SpillId {
    SpillIdInvalid,
    SpillIdRetErrCode,
};

struct IrInstSrcSpillBegin {
    IrInstSrc base;

    IrInstSrc *operand;
    SpillId spill_id;
};

struct IrInstGenSpillBegin {
    IrInstGen base;

    SpillId spill_id;
    IrInstGen *operand;
};

struct IrInstSrcSpillEnd {
    IrInstSrc base;

    IrInstSrcSpillBegin *begin;
};

struct IrInstGenSpillEnd {
    IrInstGen base;

    IrInstGenSpillBegin *begin;
};

struct IrInstGenVectorExtractElem {
    IrInstGen base;

    IrInstGen *vector;
    IrInstGen *index;
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
    IrInstGen *resolved_loc; // result ptr
    IrInstSrc *source_instruction;
    IrInstGen *gen_instruction; // value to store to the result loc
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
    IrInstSrc *is_comptime;
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
    IrInstGenCall *inst;
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
