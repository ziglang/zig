/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ZIG_CLANG_H
#define ZIG_ZIG_CLANG_H

#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

// ATTENTION: If you modify this file, be sure to update the corresponding
// extern function declarations in the self-hosted compiler file
// src/clang.zig.

// ABI warning
struct Stage2ErrorMsg {
    const char *filename_ptr; // can be null
    size_t filename_len;
    const char *msg_ptr;
    size_t msg_len;
    const char *source; // valid until the ASTUnit is freed. can be null
    unsigned line; // 0 based
    unsigned column; // 0 based
    unsigned offset; // byte offset into source
};

struct ZigClangSourceLocation {
    unsigned ID;
};

struct ZigClangQualType {
    void *ptr;
};

struct ZigClangAPValueLValueBase {
    void *Ptr;
    unsigned CallIndex;
    unsigned Version;
};

enum ZigClangAPValueKind {
    ZigClangAPValueNone,
    ZigClangAPValueIndeterminate,
    ZigClangAPValueInt,
    ZigClangAPValueFloat,
    ZigClangAPValueFixedPoint,
    ZigClangAPValueComplexInt,
    ZigClangAPValueComplexFloat,
    ZigClangAPValueLValue,
    ZigClangAPValueVector,
    ZigClangAPValueArray,
    ZigClangAPValueStruct,
    ZigClangAPValueUnion,
    ZigClangAPValueMemberPointer,
    ZigClangAPValueAddrLabelDiff,
};

struct ZigClangAPValue {
    enum ZigClangAPValueKind Kind;
    // experimentally-derived size of clang::APValue::DataType
#if defined(_WIN32) && defined(__i386__)
    char Data[68];
#elif defined(_WIN32) && defined(_MSC_VER)
    char Data[52];
#elif defined(__i386__)
    char Data[48];
#else
    char Data[68];
#endif
};

struct ZigClangExprEvalResult {
    bool HasSideEffects;
    bool HasUndefinedBehavior;
    void *SmallVectorImpl;
    ZigClangAPValue Val;
};

struct ZigClangAbstractConditionalOperator;
struct ZigClangAPFloat;
struct ZigClangAPInt;
struct ZigClangAPSInt;
struct ZigClangASTContext;
struct ZigClangASTRecordLayout;
struct ZigClangASTUnit;
struct ZigClangArraySubscriptExpr;
struct ZigClangArrayType;
struct ZigClangAttributedType;
struct ZigClangBinaryOperator;
struct ZigClangBinaryConditionalOperator;
struct ZigClangBreakStmt;
struct ZigClangBuiltinType;
struct ZigClangCStyleCastExpr;
struct ZigClangCallExpr;
struct ZigClangCaseStmt;
struct ZigClangCastExpr;
struct ZigClangCharacterLiteral;
struct ZigClangChooseExpr;
struct ZigClangCompoundAssignOperator;
struct ZigClangCompoundStmt;
struct ZigClangConditionalOperator;
struct ZigClangConstantArrayType;
struct ZigClangConstantExpr;
struct ZigClangContinueStmt;
struct ZigClangDecayedType;
struct ZigClangDecl;
struct ZigClangDeclRefExpr;
struct ZigClangDeclStmt;
struct ZigClangDefaultStmt;
struct ZigClangDiagnosticOptions;
struct ZigClangDiagnosticsEngine;
struct ZigClangDoStmt;
struct ZigClangElaboratedType;
struct ZigClangEnumConstantDecl;
struct ZigClangEnumDecl;
struct ZigClangEnumType;
struct ZigClangExpr;
struct ZigClangFieldDecl;
struct ZigClangFileID;
struct ZigClangFileScopeAsmDecl;
struct ZigClangFloatingLiteral;
struct ZigClangForStmt;
struct ZigClangFullSourceLoc;
struct ZigClangFunctionDecl;
struct ZigClangFunctionProtoType;
struct ZigClangFunctionType;
struct ZigClangIfStmt;
struct ZigClangImplicitCastExpr;
struct ZigClangIncompleteArrayType;
struct ZigClangIntegerLiteral;
struct ZigClangMacroDefinitionRecord;
struct ZigClangMacroQualifiedType;
struct ZigClangMemberExpr;
struct ZigClangNamedDecl;
struct ZigClangNone;
struct ZigClangOpaqueValueExpr;
struct ZigClangPCHContainerOperations;
struct ZigClangParenExpr;
struct ZigClangParenType;
struct ZigClangParmVarDecl;
struct ZigClangPointerType;
struct ZigClangPredefinedExpr;
struct ZigClangPreprocessedEntity;
struct ZigClangPreprocessingRecord;
struct ZigClangRecordDecl;
struct ZigClangRecordType;
struct ZigClangReturnStmt;
struct ZigClangSkipFunctionBodiesScope;
struct ZigClangSourceManager;
struct ZigClangSourceRange;
struct ZigClangStmt;
struct ZigClangStmtExpr;
struct ZigClangStringLiteral;
struct ZigClangStringRef;
struct ZigClangSwitchStmt;
struct ZigClangTagDecl;
struct ZigClangType;
struct ZigClangTypedefNameDecl;
struct ZigClangTypedefType;
struct ZigClangUnaryExprOrTypeTraitExpr;
struct ZigClangUnaryOperator;
struct ZigClangValueDecl;
struct ZigClangVarDecl;
struct ZigClangWhileStmt;
struct ZigClangInitListExpr;

typedef struct ZigClangStmt *const * ZigClangCompoundStmt_const_body_iterator;
typedef struct ZigClangDecl *const * ZigClangDeclStmt_const_decl_iterator;

struct ZigClangRecordDecl_field_iterator {
    void *opaque;
};

struct ZigClangEnumDecl_enumerator_iterator {
    void *opaque;
};

struct ZigClangPreprocessingRecord_iterator {
    int I;
    struct ZigClangPreprocessingRecord *Self;
};

enum ZigClangBO {
    ZigClangBO_PtrMemD,
    ZigClangBO_PtrMemI,
    ZigClangBO_Mul,
    ZigClangBO_Div,
    ZigClangBO_Rem,
    ZigClangBO_Add,
    ZigClangBO_Sub,
    ZigClangBO_Shl,
    ZigClangBO_Shr,
    ZigClangBO_Cmp,
    ZigClangBO_LT,
    ZigClangBO_GT,
    ZigClangBO_LE,
    ZigClangBO_GE,
    ZigClangBO_EQ,
    ZigClangBO_NE,
    ZigClangBO_And,
    ZigClangBO_Xor,
    ZigClangBO_Or,
    ZigClangBO_LAnd,
    ZigClangBO_LOr,
    ZigClangBO_Assign,
    ZigClangBO_MulAssign,
    ZigClangBO_DivAssign,
    ZigClangBO_RemAssign,
    ZigClangBO_AddAssign,
    ZigClangBO_SubAssign,
    ZigClangBO_ShlAssign,
    ZigClangBO_ShrAssign,
    ZigClangBO_AndAssign,
    ZigClangBO_XorAssign,
    ZigClangBO_OrAssign,
    ZigClangBO_Comma,
};

enum ZigClangUO {
    ZigClangUO_PostInc,
    ZigClangUO_PostDec,
    ZigClangUO_PreInc,
    ZigClangUO_PreDec,
    ZigClangUO_AddrOf,
    ZigClangUO_Deref,
    ZigClangUO_Plus,
    ZigClangUO_Minus,
    ZigClangUO_Not,
    ZigClangUO_LNot,
    ZigClangUO_Real,
    ZigClangUO_Imag,
    ZigClangUO_Extension,
    ZigClangUO_Coawait,
};

enum ZigClangTypeClass {
    ZigClangType_Adjusted,
    ZigClangType_Decayed,
    ZigClangType_ConstantArray,
    ZigClangType_DependentSizedArray,
    ZigClangType_IncompleteArray,
    ZigClangType_VariableArray,
    ZigClangType_Atomic,
    ZigClangType_Attributed,
    ZigClangType_BTFTagAttributed,
    ZigClangType_BitInt,
    ZigClangType_BlockPointer,
    ZigClangType_Builtin,
    ZigClangType_Complex,
    ZigClangType_Decltype,
    ZigClangType_Auto,
    ZigClangType_DeducedTemplateSpecialization,
    ZigClangType_DependentAddressSpace,
    ZigClangType_DependentBitInt,
    ZigClangType_DependentName,
    ZigClangType_DependentSizedExtVector,
    ZigClangType_DependentTemplateSpecialization,
    ZigClangType_DependentVector,
    ZigClangType_Elaborated,
    ZigClangType_FunctionNoProto,
    ZigClangType_FunctionProto,
    ZigClangType_InjectedClassName,
    ZigClangType_MacroQualified,
    ZigClangType_ConstantMatrix,
    ZigClangType_DependentSizedMatrix,
    ZigClangType_MemberPointer,
    ZigClangType_ObjCObjectPointer,
    ZigClangType_ObjCObject,
    ZigClangType_ObjCInterface,
    ZigClangType_ObjCTypeParam,
    ZigClangType_PackExpansion,
    ZigClangType_Paren,
    ZigClangType_Pipe,
    ZigClangType_Pointer,
    ZigClangType_LValueReference,
    ZigClangType_RValueReference,
    ZigClangType_SubstTemplateTypeParmPack,
    ZigClangType_SubstTemplateTypeParm,
    ZigClangType_Enum,
    ZigClangType_Record,
    ZigClangType_TemplateSpecialization,
    ZigClangType_TemplateTypeParm,
    ZigClangType_TypeOfExpr,
    ZigClangType_TypeOf,
    ZigClangType_Typedef,
    ZigClangType_UnaryTransform,
    ZigClangType_UnresolvedUsing,
    ZigClangType_Using,
    ZigClangType_Vector,
    ZigClangType_ExtVector,
};

enum ZigClangStmtClass {
    ZigClangStmt_NoStmtClass,
    ZigClangStmt_WhileStmtClass,
    ZigClangStmt_LabelStmtClass,
    ZigClangStmt_VAArgExprClass,
    ZigClangStmt_UnaryOperatorClass,
    ZigClangStmt_UnaryExprOrTypeTraitExprClass,
    ZigClangStmt_TypoExprClass,
    ZigClangStmt_TypeTraitExprClass,
    ZigClangStmt_SubstNonTypeTemplateParmPackExprClass,
    ZigClangStmt_SubstNonTypeTemplateParmExprClass,
    ZigClangStmt_StringLiteralClass,
    ZigClangStmt_StmtExprClass,
    ZigClangStmt_SourceLocExprClass,
    ZigClangStmt_SizeOfPackExprClass,
    ZigClangStmt_ShuffleVectorExprClass,
    ZigClangStmt_SYCLUniqueStableNameExprClass,
    ZigClangStmt_RequiresExprClass,
    ZigClangStmt_RecoveryExprClass,
    ZigClangStmt_PseudoObjectExprClass,
    ZigClangStmt_PredefinedExprClass,
    ZigClangStmt_ParenListExprClass,
    ZigClangStmt_ParenExprClass,
    ZigClangStmt_PackExpansionExprClass,
    ZigClangStmt_UnresolvedMemberExprClass,
    ZigClangStmt_UnresolvedLookupExprClass,
    ZigClangStmt_OpaqueValueExprClass,
    ZigClangStmt_OffsetOfExprClass,
    ZigClangStmt_ObjCSubscriptRefExprClass,
    ZigClangStmt_ObjCStringLiteralClass,
    ZigClangStmt_ObjCSelectorExprClass,
    ZigClangStmt_ObjCProtocolExprClass,
    ZigClangStmt_ObjCPropertyRefExprClass,
    ZigClangStmt_ObjCMessageExprClass,
    ZigClangStmt_ObjCIvarRefExprClass,
    ZigClangStmt_ObjCIsaExprClass,
    ZigClangStmt_ObjCIndirectCopyRestoreExprClass,
    ZigClangStmt_ObjCEncodeExprClass,
    ZigClangStmt_ObjCDictionaryLiteralClass,
    ZigClangStmt_ObjCBoxedExprClass,
    ZigClangStmt_ObjCBoolLiteralExprClass,
    ZigClangStmt_ObjCAvailabilityCheckExprClass,
    ZigClangStmt_ObjCArrayLiteralClass,
    ZigClangStmt_OMPIteratorExprClass,
    ZigClangStmt_OMPArrayShapingExprClass,
    ZigClangStmt_OMPArraySectionExprClass,
    ZigClangStmt_NoInitExprClass,
    ZigClangStmt_MemberExprClass,
    ZigClangStmt_MatrixSubscriptExprClass,
    ZigClangStmt_MaterializeTemporaryExprClass,
    ZigClangStmt_MSPropertySubscriptExprClass,
    ZigClangStmt_MSPropertyRefExprClass,
    ZigClangStmt_LambdaExprClass,
    ZigClangStmt_IntegerLiteralClass,
    ZigClangStmt_InitListExprClass,
    ZigClangStmt_ImplicitValueInitExprClass,
    ZigClangStmt_ImaginaryLiteralClass,
    ZigClangStmt_GenericSelectionExprClass,
    ZigClangStmt_GNUNullExprClass,
    ZigClangStmt_FunctionParmPackExprClass,
    ZigClangStmt_ExprWithCleanupsClass,
    ZigClangStmt_ConstantExprClass,
    ZigClangStmt_FloatingLiteralClass,
    ZigClangStmt_FixedPointLiteralClass,
    ZigClangStmt_ExtVectorElementExprClass,
    ZigClangStmt_ExpressionTraitExprClass,
    ZigClangStmt_DesignatedInitUpdateExprClass,
    ZigClangStmt_DesignatedInitExprClass,
    ZigClangStmt_DependentScopeDeclRefExprClass,
    ZigClangStmt_DependentCoawaitExprClass,
    ZigClangStmt_DeclRefExprClass,
    ZigClangStmt_CoyieldExprClass,
    ZigClangStmt_CoawaitExprClass,
    ZigClangStmt_ConvertVectorExprClass,
    ZigClangStmt_ConceptSpecializationExprClass,
    ZigClangStmt_CompoundLiteralExprClass,
    ZigClangStmt_ChooseExprClass,
    ZigClangStmt_CharacterLiteralClass,
    ZigClangStmt_ImplicitCastExprClass,
    ZigClangStmt_ObjCBridgedCastExprClass,
    ZigClangStmt_CXXStaticCastExprClass,
    ZigClangStmt_CXXReinterpretCastExprClass,
    ZigClangStmt_CXXDynamicCastExprClass,
    ZigClangStmt_CXXConstCastExprClass,
    ZigClangStmt_CXXAddrspaceCastExprClass,
    ZigClangStmt_CXXFunctionalCastExprClass,
    ZigClangStmt_CStyleCastExprClass,
    ZigClangStmt_BuiltinBitCastExprClass,
    ZigClangStmt_CallExprClass,
    ZigClangStmt_UserDefinedLiteralClass,
    ZigClangStmt_CXXOperatorCallExprClass,
    ZigClangStmt_CXXMemberCallExprClass,
    ZigClangStmt_CUDAKernelCallExprClass,
    ZigClangStmt_CXXUuidofExprClass,
    ZigClangStmt_CXXUnresolvedConstructExprClass,
    ZigClangStmt_CXXTypeidExprClass,
    ZigClangStmt_CXXThrowExprClass,
    ZigClangStmt_CXXThisExprClass,
    ZigClangStmt_CXXStdInitializerListExprClass,
    ZigClangStmt_CXXScalarValueInitExprClass,
    ZigClangStmt_CXXRewrittenBinaryOperatorClass,
    ZigClangStmt_CXXPseudoDestructorExprClass,
    ZigClangStmt_CXXParenListInitExprClass,
    ZigClangStmt_CXXNullPtrLiteralExprClass,
    ZigClangStmt_CXXNoexceptExprClass,
    ZigClangStmt_CXXNewExprClass,
    ZigClangStmt_CXXInheritedCtorInitExprClass,
    ZigClangStmt_CXXFoldExprClass,
    ZigClangStmt_CXXDependentScopeMemberExprClass,
    ZigClangStmt_CXXDeleteExprClass,
    ZigClangStmt_CXXDefaultInitExprClass,
    ZigClangStmt_CXXDefaultArgExprClass,
    ZigClangStmt_CXXConstructExprClass,
    ZigClangStmt_CXXTemporaryObjectExprClass,
    ZigClangStmt_CXXBoolLiteralExprClass,
    ZigClangStmt_CXXBindTemporaryExprClass,
    ZigClangStmt_BlockExprClass,
    ZigClangStmt_BinaryOperatorClass,
    ZigClangStmt_CompoundAssignOperatorClass,
    ZigClangStmt_AtomicExprClass,
    ZigClangStmt_AsTypeExprClass,
    ZigClangStmt_ArrayTypeTraitExprClass,
    ZigClangStmt_ArraySubscriptExprClass,
    ZigClangStmt_ArrayInitLoopExprClass,
    ZigClangStmt_ArrayInitIndexExprClass,
    ZigClangStmt_AddrLabelExprClass,
    ZigClangStmt_ConditionalOperatorClass,
    ZigClangStmt_BinaryConditionalOperatorClass,
    ZigClangStmt_AttributedStmtClass,
    ZigClangStmt_SwitchStmtClass,
    ZigClangStmt_DefaultStmtClass,
    ZigClangStmt_CaseStmtClass,
    ZigClangStmt_SEHTryStmtClass,
    ZigClangStmt_SEHLeaveStmtClass,
    ZigClangStmt_SEHFinallyStmtClass,
    ZigClangStmt_SEHExceptStmtClass,
    ZigClangStmt_ReturnStmtClass,
    ZigClangStmt_ObjCForCollectionStmtClass,
    ZigClangStmt_ObjCAutoreleasePoolStmtClass,
    ZigClangStmt_ObjCAtTryStmtClass,
    ZigClangStmt_ObjCAtThrowStmtClass,
    ZigClangStmt_ObjCAtSynchronizedStmtClass,
    ZigClangStmt_ObjCAtFinallyStmtClass,
    ZigClangStmt_ObjCAtCatchStmtClass,
    ZigClangStmt_OMPTeamsDirectiveClass,
    ZigClangStmt_OMPTaskyieldDirectiveClass,
    ZigClangStmt_OMPTaskwaitDirectiveClass,
    ZigClangStmt_OMPTaskgroupDirectiveClass,
    ZigClangStmt_OMPTaskDirectiveClass,
    ZigClangStmt_OMPTargetUpdateDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDirectiveClass,
    ZigClangStmt_OMPTargetParallelForDirectiveClass,
    ZigClangStmt_OMPTargetParallelDirectiveClass,
    ZigClangStmt_OMPTargetExitDataDirectiveClass,
    ZigClangStmt_OMPTargetEnterDataDirectiveClass,
    ZigClangStmt_OMPTargetDirectiveClass,
    ZigClangStmt_OMPTargetDataDirectiveClass,
    ZigClangStmt_OMPSingleDirectiveClass,
    ZigClangStmt_OMPSectionsDirectiveClass,
    ZigClangStmt_OMPSectionDirectiveClass,
    ZigClangStmt_OMPScopeDirectiveClass,
    ZigClangStmt_OMPScanDirectiveClass,
    ZigClangStmt_OMPParallelSectionsDirectiveClass,
    ZigClangStmt_OMPParallelMasterDirectiveClass,
    ZigClangStmt_OMPParallelMaskedDirectiveClass,
    ZigClangStmt_OMPParallelDirectiveClass,
    ZigClangStmt_OMPOrderedDirectiveClass,
    ZigClangStmt_OMPMetaDirectiveClass,
    ZigClangStmt_OMPMasterDirectiveClass,
    ZigClangStmt_OMPMaskedDirectiveClass,
    ZigClangStmt_OMPUnrollDirectiveClass,
    ZigClangStmt_OMPTileDirectiveClass,
    ZigClangStmt_OMPTeamsGenericLoopDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeSimdDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeParallelForSimdDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeParallelForDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeDirectiveClass,
    ZigClangStmt_OMPTaskLoopSimdDirectiveClass,
    ZigClangStmt_OMPTaskLoopDirectiveClass,
    ZigClangStmt_OMPTargetTeamsGenericLoopDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeSimdDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeParallelForSimdDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeParallelForDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeDirectiveClass,
    ZigClangStmt_OMPTargetSimdDirectiveClass,
    ZigClangStmt_OMPTargetParallelGenericLoopDirectiveClass,
    ZigClangStmt_OMPTargetParallelForSimdDirectiveClass,
    ZigClangStmt_OMPSimdDirectiveClass,
    ZigClangStmt_OMPParallelMasterTaskLoopSimdDirectiveClass,
    ZigClangStmt_OMPParallelMasterTaskLoopDirectiveClass,
    ZigClangStmt_OMPParallelMaskedTaskLoopSimdDirectiveClass,
    ZigClangStmt_OMPParallelMaskedTaskLoopDirectiveClass,
    ZigClangStmt_OMPParallelGenericLoopDirectiveClass,
    ZigClangStmt_OMPParallelForSimdDirectiveClass,
    ZigClangStmt_OMPParallelForDirectiveClass,
    ZigClangStmt_OMPMasterTaskLoopSimdDirectiveClass,
    ZigClangStmt_OMPMasterTaskLoopDirectiveClass,
    ZigClangStmt_OMPMaskedTaskLoopSimdDirectiveClass,
    ZigClangStmt_OMPMaskedTaskLoopDirectiveClass,
    ZigClangStmt_OMPGenericLoopDirectiveClass,
    ZigClangStmt_OMPForSimdDirectiveClass,
    ZigClangStmt_OMPForDirectiveClass,
    ZigClangStmt_OMPDistributeSimdDirectiveClass,
    ZigClangStmt_OMPDistributeParallelForSimdDirectiveClass,
    ZigClangStmt_OMPDistributeParallelForDirectiveClass,
    ZigClangStmt_OMPDistributeDirectiveClass,
    ZigClangStmt_OMPInteropDirectiveClass,
    ZigClangStmt_OMPFlushDirectiveClass,
    ZigClangStmt_OMPErrorDirectiveClass,
    ZigClangStmt_OMPDispatchDirectiveClass,
    ZigClangStmt_OMPDepobjDirectiveClass,
    ZigClangStmt_OMPCriticalDirectiveClass,
    ZigClangStmt_OMPCancellationPointDirectiveClass,
    ZigClangStmt_OMPCancelDirectiveClass,
    ZigClangStmt_OMPBarrierDirectiveClass,
    ZigClangStmt_OMPAtomicDirectiveClass,
    ZigClangStmt_OMPCanonicalLoopClass,
    ZigClangStmt_NullStmtClass,
    ZigClangStmt_MSDependentExistsStmtClass,
    ZigClangStmt_IndirectGotoStmtClass,
    ZigClangStmt_IfStmtClass,
    ZigClangStmt_GotoStmtClass,
    ZigClangStmt_ForStmtClass,
    ZigClangStmt_DoStmtClass,
    ZigClangStmt_DeclStmtClass,
    ZigClangStmt_CoroutineBodyStmtClass,
    ZigClangStmt_CoreturnStmtClass,
    ZigClangStmt_ContinueStmtClass,
    ZigClangStmt_CompoundStmtClass,
    ZigClangStmt_CapturedStmtClass,
    ZigClangStmt_CXXTryStmtClass,
    ZigClangStmt_CXXForRangeStmtClass,
    ZigClangStmt_CXXCatchStmtClass,
    ZigClangStmt_BreakStmtClass,
    ZigClangStmt_MSAsmStmtClass,
    ZigClangStmt_GCCAsmStmtClass,
};

enum ZigClangCK {
    ZigClangCK_Dependent,
    ZigClangCK_BitCast,
    ZigClangCK_LValueBitCast,
    ZigClangCK_LValueToRValueBitCast,
    ZigClangCK_LValueToRValue,
    ZigClangCK_NoOp,
    ZigClangCK_BaseToDerived,
    ZigClangCK_DerivedToBase,
    ZigClangCK_UncheckedDerivedToBase,
    ZigClangCK_Dynamic,
    ZigClangCK_ToUnion,
    ZigClangCK_ArrayToPointerDecay,
    ZigClangCK_FunctionToPointerDecay,
    ZigClangCK_NullToPointer,
    ZigClangCK_NullToMemberPointer,
    ZigClangCK_BaseToDerivedMemberPointer,
    ZigClangCK_DerivedToBaseMemberPointer,
    ZigClangCK_MemberPointerToBoolean,
    ZigClangCK_ReinterpretMemberPointer,
    ZigClangCK_UserDefinedConversion,
    ZigClangCK_ConstructorConversion,
    ZigClangCK_IntegralToPointer,
    ZigClangCK_PointerToIntegral,
    ZigClangCK_PointerToBoolean,
    ZigClangCK_ToVoid,
    ZigClangCK_MatrixCast,
    ZigClangCK_VectorSplat,
    ZigClangCK_IntegralCast,
    ZigClangCK_IntegralToBoolean,
    ZigClangCK_IntegralToFloating,
    ZigClangCK_FloatingToFixedPoint,
    ZigClangCK_FixedPointToFloating,
    ZigClangCK_FixedPointCast,
    ZigClangCK_FixedPointToIntegral,
    ZigClangCK_IntegralToFixedPoint,
    ZigClangCK_FixedPointToBoolean,
    ZigClangCK_FloatingToIntegral,
    ZigClangCK_FloatingToBoolean,
    ZigClangCK_BooleanToSignedIntegral,
    ZigClangCK_FloatingCast,
    ZigClangCK_CPointerToObjCPointerCast,
    ZigClangCK_BlockPointerToObjCPointerCast,
    ZigClangCK_AnyPointerToBlockPointerCast,
    ZigClangCK_ObjCObjectLValueCast,
    ZigClangCK_FloatingRealToComplex,
    ZigClangCK_FloatingComplexToReal,
    ZigClangCK_FloatingComplexToBoolean,
    ZigClangCK_FloatingComplexCast,
    ZigClangCK_FloatingComplexToIntegralComplex,
    ZigClangCK_IntegralRealToComplex,
    ZigClangCK_IntegralComplexToReal,
    ZigClangCK_IntegralComplexToBoolean,
    ZigClangCK_IntegralComplexCast,
    ZigClangCK_IntegralComplexToFloatingComplex,
    ZigClangCK_ARCProduceObject,
    ZigClangCK_ARCConsumeObject,
    ZigClangCK_ARCReclaimReturnedObject,
    ZigClangCK_ARCExtendBlockObject,
    ZigClangCK_AtomicToNonAtomic,
    ZigClangCK_NonAtomicToAtomic,
    ZigClangCK_CopyAndAutoreleaseBlockObject,
    ZigClangCK_BuiltinFnToFnPtr,
    ZigClangCK_ZeroToOCLOpaqueType,
    ZigClangCK_AddressSpaceConversion,
    ZigClangCK_IntToOCLSampler,
};

enum ZigClangDeclKind {
    ZigClangDeclTranslationUnit,
    ZigClangDeclRequiresExprBody,
    ZigClangDeclLinkageSpec,
    ZigClangDeclExternCContext,
    ZigClangDeclExport,
    ZigClangDeclCaptured,
    ZigClangDeclBlock,
    ZigClangDeclTopLevelStmt,
    ZigClangDeclStaticAssert,
    ZigClangDeclPragmaDetectMismatch,
    ZigClangDeclPragmaComment,
    ZigClangDeclObjCPropertyImpl,
    ZigClangDeclOMPThreadPrivate,
    ZigClangDeclOMPRequires,
    ZigClangDeclOMPAllocate,
    ZigClangDeclObjCMethod,
    ZigClangDeclObjCProtocol,
    ZigClangDeclObjCInterface,
    ZigClangDeclObjCImplementation,
    ZigClangDeclObjCCategoryImpl,
    ZigClangDeclObjCCategory,
    ZigClangDeclNamespace,
    ZigClangDeclHLSLBuffer,
    ZigClangDeclOMPDeclareReduction,
    ZigClangDeclOMPDeclareMapper,
    ZigClangDeclUnresolvedUsingValue,
    ZigClangDeclUnnamedGlobalConstant,
    ZigClangDeclTemplateParamObject,
    ZigClangDeclMSGuid,
    ZigClangDeclIndirectField,
    ZigClangDeclEnumConstant,
    ZigClangDeclFunction,
    ZigClangDeclCXXMethod,
    ZigClangDeclCXXDestructor,
    ZigClangDeclCXXConversion,
    ZigClangDeclCXXConstructor,
    ZigClangDeclCXXDeductionGuide,
    ZigClangDeclVar,
    ZigClangDeclVarTemplateSpecialization,
    ZigClangDeclVarTemplatePartialSpecialization,
    ZigClangDeclParmVar,
    ZigClangDeclOMPCapturedExpr,
    ZigClangDeclImplicitParam,
    ZigClangDeclDecomposition,
    ZigClangDeclNonTypeTemplateParm,
    ZigClangDeclMSProperty,
    ZigClangDeclField,
    ZigClangDeclObjCIvar,
    ZigClangDeclObjCAtDefsField,
    ZigClangDeclBinding,
    ZigClangDeclUsingShadow,
    ZigClangDeclConstructorUsingShadow,
    ZigClangDeclUsingPack,
    ZigClangDeclUsingDirective,
    ZigClangDeclUnresolvedUsingIfExists,
    ZigClangDeclRecord,
    ZigClangDeclCXXRecord,
    ZigClangDeclClassTemplateSpecialization,
    ZigClangDeclClassTemplatePartialSpecialization,
    ZigClangDeclEnum,
    ZigClangDeclUnresolvedUsingTypename,
    ZigClangDeclTypedef,
    ZigClangDeclTypeAlias,
    ZigClangDeclObjCTypeParam,
    ZigClangDeclTemplateTypeParm,
    ZigClangDeclTemplateTemplateParm,
    ZigClangDeclVarTemplate,
    ZigClangDeclTypeAliasTemplate,
    ZigClangDeclFunctionTemplate,
    ZigClangDeclClassTemplate,
    ZigClangDeclConcept,
    ZigClangDeclBuiltinTemplate,
    ZigClangDeclObjCProperty,
    ZigClangDeclObjCCompatibleAlias,
    ZigClangDeclNamespaceAlias,
    ZigClangDeclLabel,
    ZigClangDeclUsingEnum,
    ZigClangDeclUsing,
    ZigClangDeclLifetimeExtendedTemporary,
    ZigClangDeclImport,
    ZigClangDeclImplicitConceptSpecialization,
    ZigClangDeclFriendTemplate,
    ZigClangDeclFriend,
    ZigClangDeclFileScopeAsm,
    ZigClangDeclEmpty,
    ZigClangDeclAccessSpec,
};

enum ZigClangBuiltinTypeKind {
    ZigClangBuiltinTypeOCLImage1dRO,
    ZigClangBuiltinTypeOCLImage1dArrayRO,
    ZigClangBuiltinTypeOCLImage1dBufferRO,
    ZigClangBuiltinTypeOCLImage2dRO,
    ZigClangBuiltinTypeOCLImage2dArrayRO,
    ZigClangBuiltinTypeOCLImage2dDepthRO,
    ZigClangBuiltinTypeOCLImage2dArrayDepthRO,
    ZigClangBuiltinTypeOCLImage2dMSAARO,
    ZigClangBuiltinTypeOCLImage2dArrayMSAARO,
    ZigClangBuiltinTypeOCLImage2dMSAADepthRO,
    ZigClangBuiltinTypeOCLImage2dArrayMSAADepthRO,
    ZigClangBuiltinTypeOCLImage3dRO,
    ZigClangBuiltinTypeOCLImage1dWO,
    ZigClangBuiltinTypeOCLImage1dArrayWO,
    ZigClangBuiltinTypeOCLImage1dBufferWO,
    ZigClangBuiltinTypeOCLImage2dWO,
    ZigClangBuiltinTypeOCLImage2dArrayWO,
    ZigClangBuiltinTypeOCLImage2dDepthWO,
    ZigClangBuiltinTypeOCLImage2dArrayDepthWO,
    ZigClangBuiltinTypeOCLImage2dMSAAWO,
    ZigClangBuiltinTypeOCLImage2dArrayMSAAWO,
    ZigClangBuiltinTypeOCLImage2dMSAADepthWO,
    ZigClangBuiltinTypeOCLImage2dArrayMSAADepthWO,
    ZigClangBuiltinTypeOCLImage3dWO,
    ZigClangBuiltinTypeOCLImage1dRW,
    ZigClangBuiltinTypeOCLImage1dArrayRW,
    ZigClangBuiltinTypeOCLImage1dBufferRW,
    ZigClangBuiltinTypeOCLImage2dRW,
    ZigClangBuiltinTypeOCLImage2dArrayRW,
    ZigClangBuiltinTypeOCLImage2dDepthRW,
    ZigClangBuiltinTypeOCLImage2dArrayDepthRW,
    ZigClangBuiltinTypeOCLImage2dMSAARW,
    ZigClangBuiltinTypeOCLImage2dArrayMSAARW,
    ZigClangBuiltinTypeOCLImage2dMSAADepthRW,
    ZigClangBuiltinTypeOCLImage2dArrayMSAADepthRW,
    ZigClangBuiltinTypeOCLImage3dRW,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCMcePayload,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCImePayload,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCRefPayload,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCSicPayload,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCMceResult,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResult,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCRefResult,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCSicResult,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResultSingleReferenceStreamout,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCImeResultDualReferenceStreamout,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCImeSingleReferenceStreamin,
    ZigClangBuiltinTypeOCLIntelSubgroupAVCImeDualReferenceStreamin,
    ZigClangBuiltinTypeSveInt8,
    ZigClangBuiltinTypeSveInt16,
    ZigClangBuiltinTypeSveInt32,
    ZigClangBuiltinTypeSveInt64,
    ZigClangBuiltinTypeSveUint8,
    ZigClangBuiltinTypeSveUint16,
    ZigClangBuiltinTypeSveUint32,
    ZigClangBuiltinTypeSveUint64,
    ZigClangBuiltinTypeSveFloat16,
    ZigClangBuiltinTypeSveFloat32,
    ZigClangBuiltinTypeSveFloat64,
    ZigClangBuiltinTypeSveBFloat16,
    ZigClangBuiltinTypeSveInt8x2,
    ZigClangBuiltinTypeSveInt16x2,
    ZigClangBuiltinTypeSveInt32x2,
    ZigClangBuiltinTypeSveInt64x2,
    ZigClangBuiltinTypeSveUint8x2,
    ZigClangBuiltinTypeSveUint16x2,
    ZigClangBuiltinTypeSveUint32x2,
    ZigClangBuiltinTypeSveUint64x2,
    ZigClangBuiltinTypeSveFloat16x2,
    ZigClangBuiltinTypeSveFloat32x2,
    ZigClangBuiltinTypeSveFloat64x2,
    ZigClangBuiltinTypeSveBFloat16x2,
    ZigClangBuiltinTypeSveInt8x3,
    ZigClangBuiltinTypeSveInt16x3,
    ZigClangBuiltinTypeSveInt32x3,
    ZigClangBuiltinTypeSveInt64x3,
    ZigClangBuiltinTypeSveUint8x3,
    ZigClangBuiltinTypeSveUint16x3,
    ZigClangBuiltinTypeSveUint32x3,
    ZigClangBuiltinTypeSveUint64x3,
    ZigClangBuiltinTypeSveFloat16x3,
    ZigClangBuiltinTypeSveFloat32x3,
    ZigClangBuiltinTypeSveFloat64x3,
    ZigClangBuiltinTypeSveBFloat16x3,
    ZigClangBuiltinTypeSveInt8x4,
    ZigClangBuiltinTypeSveInt16x4,
    ZigClangBuiltinTypeSveInt32x4,
    ZigClangBuiltinTypeSveInt64x4,
    ZigClangBuiltinTypeSveUint8x4,
    ZigClangBuiltinTypeSveUint16x4,
    ZigClangBuiltinTypeSveUint32x4,
    ZigClangBuiltinTypeSveUint64x4,
    ZigClangBuiltinTypeSveFloat16x4,
    ZigClangBuiltinTypeSveFloat32x4,
    ZigClangBuiltinTypeSveFloat64x4,
    ZigClangBuiltinTypeSveBFloat16x4,
    ZigClangBuiltinTypeSveBool,
    ZigClangBuiltinTypeSveBoolx2,
    ZigClangBuiltinTypeSveBoolx4,
    ZigClangBuiltinTypeSveCount,
    ZigClangBuiltinTypeVectorQuad,
    ZigClangBuiltinTypeVectorPair,
    ZigClangBuiltinTypeRvvInt8mf8,
    ZigClangBuiltinTypeRvvInt8mf4,
    ZigClangBuiltinTypeRvvInt8mf2,
    ZigClangBuiltinTypeRvvInt8m1,
    ZigClangBuiltinTypeRvvInt8m2,
    ZigClangBuiltinTypeRvvInt8m4,
    ZigClangBuiltinTypeRvvInt8m8,
    ZigClangBuiltinTypeRvvUint8mf8,
    ZigClangBuiltinTypeRvvUint8mf4,
    ZigClangBuiltinTypeRvvUint8mf2,
    ZigClangBuiltinTypeRvvUint8m1,
    ZigClangBuiltinTypeRvvUint8m2,
    ZigClangBuiltinTypeRvvUint8m4,
    ZigClangBuiltinTypeRvvUint8m8,
    ZigClangBuiltinTypeRvvInt16mf4,
    ZigClangBuiltinTypeRvvInt16mf2,
    ZigClangBuiltinTypeRvvInt16m1,
    ZigClangBuiltinTypeRvvInt16m2,
    ZigClangBuiltinTypeRvvInt16m4,
    ZigClangBuiltinTypeRvvInt16m8,
    ZigClangBuiltinTypeRvvUint16mf4,
    ZigClangBuiltinTypeRvvUint16mf2,
    ZigClangBuiltinTypeRvvUint16m1,
    ZigClangBuiltinTypeRvvUint16m2,
    ZigClangBuiltinTypeRvvUint16m4,
    ZigClangBuiltinTypeRvvUint16m8,
    ZigClangBuiltinTypeRvvInt32mf2,
    ZigClangBuiltinTypeRvvInt32m1,
    ZigClangBuiltinTypeRvvInt32m2,
    ZigClangBuiltinTypeRvvInt32m4,
    ZigClangBuiltinTypeRvvInt32m8,
    ZigClangBuiltinTypeRvvUint32mf2,
    ZigClangBuiltinTypeRvvUint32m1,
    ZigClangBuiltinTypeRvvUint32m2,
    ZigClangBuiltinTypeRvvUint32m4,
    ZigClangBuiltinTypeRvvUint32m8,
    ZigClangBuiltinTypeRvvInt64m1,
    ZigClangBuiltinTypeRvvInt64m2,
    ZigClangBuiltinTypeRvvInt64m4,
    ZigClangBuiltinTypeRvvInt64m8,
    ZigClangBuiltinTypeRvvUint64m1,
    ZigClangBuiltinTypeRvvUint64m2,
    ZigClangBuiltinTypeRvvUint64m4,
    ZigClangBuiltinTypeRvvUint64m8,
    ZigClangBuiltinTypeRvvFloat16mf4,
    ZigClangBuiltinTypeRvvFloat16mf2,
    ZigClangBuiltinTypeRvvFloat16m1,
    ZigClangBuiltinTypeRvvFloat16m2,
    ZigClangBuiltinTypeRvvFloat16m4,
    ZigClangBuiltinTypeRvvFloat16m8,
    ZigClangBuiltinTypeRvvBFloat16mf4,
    ZigClangBuiltinTypeRvvBFloat16mf2,
    ZigClangBuiltinTypeRvvBFloat16m1,
    ZigClangBuiltinTypeRvvBFloat16m2,
    ZigClangBuiltinTypeRvvBFloat16m4,
    ZigClangBuiltinTypeRvvBFloat16m8,
    ZigClangBuiltinTypeRvvFloat32mf2,
    ZigClangBuiltinTypeRvvFloat32m1,
    ZigClangBuiltinTypeRvvFloat32m2,
    ZigClangBuiltinTypeRvvFloat32m4,
    ZigClangBuiltinTypeRvvFloat32m8,
    ZigClangBuiltinTypeRvvFloat64m1,
    ZigClangBuiltinTypeRvvFloat64m2,
    ZigClangBuiltinTypeRvvFloat64m4,
    ZigClangBuiltinTypeRvvFloat64m8,
    ZigClangBuiltinTypeRvvBool1,
    ZigClangBuiltinTypeRvvBool2,
    ZigClangBuiltinTypeRvvBool4,
    ZigClangBuiltinTypeRvvBool8,
    ZigClangBuiltinTypeRvvBool16,
    ZigClangBuiltinTypeRvvBool32,
    ZigClangBuiltinTypeRvvBool64,
    ZigClangBuiltinTypeRvvInt8mf8x2,
    ZigClangBuiltinTypeRvvInt8mf8x3,
    ZigClangBuiltinTypeRvvInt8mf8x4,
    ZigClangBuiltinTypeRvvInt8mf8x5,
    ZigClangBuiltinTypeRvvInt8mf8x6,
    ZigClangBuiltinTypeRvvInt8mf8x7,
    ZigClangBuiltinTypeRvvInt8mf8x8,
    ZigClangBuiltinTypeRvvInt8mf4x2,
    ZigClangBuiltinTypeRvvInt8mf4x3,
    ZigClangBuiltinTypeRvvInt8mf4x4,
    ZigClangBuiltinTypeRvvInt8mf4x5,
    ZigClangBuiltinTypeRvvInt8mf4x6,
    ZigClangBuiltinTypeRvvInt8mf4x7,
    ZigClangBuiltinTypeRvvInt8mf4x8,
    ZigClangBuiltinTypeRvvInt8mf2x2,
    ZigClangBuiltinTypeRvvInt8mf2x3,
    ZigClangBuiltinTypeRvvInt8mf2x4,
    ZigClangBuiltinTypeRvvInt8mf2x5,
    ZigClangBuiltinTypeRvvInt8mf2x6,
    ZigClangBuiltinTypeRvvInt8mf2x7,
    ZigClangBuiltinTypeRvvInt8mf2x8,
    ZigClangBuiltinTypeRvvInt8m1x2,
    ZigClangBuiltinTypeRvvInt8m1x3,
    ZigClangBuiltinTypeRvvInt8m1x4,
    ZigClangBuiltinTypeRvvInt8m1x5,
    ZigClangBuiltinTypeRvvInt8m1x6,
    ZigClangBuiltinTypeRvvInt8m1x7,
    ZigClangBuiltinTypeRvvInt8m1x8,
    ZigClangBuiltinTypeRvvInt8m2x2,
    ZigClangBuiltinTypeRvvInt8m2x3,
    ZigClangBuiltinTypeRvvInt8m2x4,
    ZigClangBuiltinTypeRvvInt8m4x2,
    ZigClangBuiltinTypeRvvUint8mf8x2,
    ZigClangBuiltinTypeRvvUint8mf8x3,
    ZigClangBuiltinTypeRvvUint8mf8x4,
    ZigClangBuiltinTypeRvvUint8mf8x5,
    ZigClangBuiltinTypeRvvUint8mf8x6,
    ZigClangBuiltinTypeRvvUint8mf8x7,
    ZigClangBuiltinTypeRvvUint8mf8x8,
    ZigClangBuiltinTypeRvvUint8mf4x2,
    ZigClangBuiltinTypeRvvUint8mf4x3,
    ZigClangBuiltinTypeRvvUint8mf4x4,
    ZigClangBuiltinTypeRvvUint8mf4x5,
    ZigClangBuiltinTypeRvvUint8mf4x6,
    ZigClangBuiltinTypeRvvUint8mf4x7,
    ZigClangBuiltinTypeRvvUint8mf4x8,
    ZigClangBuiltinTypeRvvUint8mf2x2,
    ZigClangBuiltinTypeRvvUint8mf2x3,
    ZigClangBuiltinTypeRvvUint8mf2x4,
    ZigClangBuiltinTypeRvvUint8mf2x5,
    ZigClangBuiltinTypeRvvUint8mf2x6,
    ZigClangBuiltinTypeRvvUint8mf2x7,
    ZigClangBuiltinTypeRvvUint8mf2x8,
    ZigClangBuiltinTypeRvvUint8m1x2,
    ZigClangBuiltinTypeRvvUint8m1x3,
    ZigClangBuiltinTypeRvvUint8m1x4,
    ZigClangBuiltinTypeRvvUint8m1x5,
    ZigClangBuiltinTypeRvvUint8m1x6,
    ZigClangBuiltinTypeRvvUint8m1x7,
    ZigClangBuiltinTypeRvvUint8m1x8,
    ZigClangBuiltinTypeRvvUint8m2x2,
    ZigClangBuiltinTypeRvvUint8m2x3,
    ZigClangBuiltinTypeRvvUint8m2x4,
    ZigClangBuiltinTypeRvvUint8m4x2,
    ZigClangBuiltinTypeRvvInt16mf4x2,
    ZigClangBuiltinTypeRvvInt16mf4x3,
    ZigClangBuiltinTypeRvvInt16mf4x4,
    ZigClangBuiltinTypeRvvInt16mf4x5,
    ZigClangBuiltinTypeRvvInt16mf4x6,
    ZigClangBuiltinTypeRvvInt16mf4x7,
    ZigClangBuiltinTypeRvvInt16mf4x8,
    ZigClangBuiltinTypeRvvInt16mf2x2,
    ZigClangBuiltinTypeRvvInt16mf2x3,
    ZigClangBuiltinTypeRvvInt16mf2x4,
    ZigClangBuiltinTypeRvvInt16mf2x5,
    ZigClangBuiltinTypeRvvInt16mf2x6,
    ZigClangBuiltinTypeRvvInt16mf2x7,
    ZigClangBuiltinTypeRvvInt16mf2x8,
    ZigClangBuiltinTypeRvvInt16m1x2,
    ZigClangBuiltinTypeRvvInt16m1x3,
    ZigClangBuiltinTypeRvvInt16m1x4,
    ZigClangBuiltinTypeRvvInt16m1x5,
    ZigClangBuiltinTypeRvvInt16m1x6,
    ZigClangBuiltinTypeRvvInt16m1x7,
    ZigClangBuiltinTypeRvvInt16m1x8,
    ZigClangBuiltinTypeRvvInt16m2x2,
    ZigClangBuiltinTypeRvvInt16m2x3,
    ZigClangBuiltinTypeRvvInt16m2x4,
    ZigClangBuiltinTypeRvvInt16m4x2,
    ZigClangBuiltinTypeRvvUint16mf4x2,
    ZigClangBuiltinTypeRvvUint16mf4x3,
    ZigClangBuiltinTypeRvvUint16mf4x4,
    ZigClangBuiltinTypeRvvUint16mf4x5,
    ZigClangBuiltinTypeRvvUint16mf4x6,
    ZigClangBuiltinTypeRvvUint16mf4x7,
    ZigClangBuiltinTypeRvvUint16mf4x8,
    ZigClangBuiltinTypeRvvUint16mf2x2,
    ZigClangBuiltinTypeRvvUint16mf2x3,
    ZigClangBuiltinTypeRvvUint16mf2x4,
    ZigClangBuiltinTypeRvvUint16mf2x5,
    ZigClangBuiltinTypeRvvUint16mf2x6,
    ZigClangBuiltinTypeRvvUint16mf2x7,
    ZigClangBuiltinTypeRvvUint16mf2x8,
    ZigClangBuiltinTypeRvvUint16m1x2,
    ZigClangBuiltinTypeRvvUint16m1x3,
    ZigClangBuiltinTypeRvvUint16m1x4,
    ZigClangBuiltinTypeRvvUint16m1x5,
    ZigClangBuiltinTypeRvvUint16m1x6,
    ZigClangBuiltinTypeRvvUint16m1x7,
    ZigClangBuiltinTypeRvvUint16m1x8,
    ZigClangBuiltinTypeRvvUint16m2x2,
    ZigClangBuiltinTypeRvvUint16m2x3,
    ZigClangBuiltinTypeRvvUint16m2x4,
    ZigClangBuiltinTypeRvvUint16m4x2,
    ZigClangBuiltinTypeRvvInt32mf2x2,
    ZigClangBuiltinTypeRvvInt32mf2x3,
    ZigClangBuiltinTypeRvvInt32mf2x4,
    ZigClangBuiltinTypeRvvInt32mf2x5,
    ZigClangBuiltinTypeRvvInt32mf2x6,
    ZigClangBuiltinTypeRvvInt32mf2x7,
    ZigClangBuiltinTypeRvvInt32mf2x8,
    ZigClangBuiltinTypeRvvInt32m1x2,
    ZigClangBuiltinTypeRvvInt32m1x3,
    ZigClangBuiltinTypeRvvInt32m1x4,
    ZigClangBuiltinTypeRvvInt32m1x5,
    ZigClangBuiltinTypeRvvInt32m1x6,
    ZigClangBuiltinTypeRvvInt32m1x7,
    ZigClangBuiltinTypeRvvInt32m1x8,
    ZigClangBuiltinTypeRvvInt32m2x2,
    ZigClangBuiltinTypeRvvInt32m2x3,
    ZigClangBuiltinTypeRvvInt32m2x4,
    ZigClangBuiltinTypeRvvInt32m4x2,
    ZigClangBuiltinTypeRvvUint32mf2x2,
    ZigClangBuiltinTypeRvvUint32mf2x3,
    ZigClangBuiltinTypeRvvUint32mf2x4,
    ZigClangBuiltinTypeRvvUint32mf2x5,
    ZigClangBuiltinTypeRvvUint32mf2x6,
    ZigClangBuiltinTypeRvvUint32mf2x7,
    ZigClangBuiltinTypeRvvUint32mf2x8,
    ZigClangBuiltinTypeRvvUint32m1x2,
    ZigClangBuiltinTypeRvvUint32m1x3,
    ZigClangBuiltinTypeRvvUint32m1x4,
    ZigClangBuiltinTypeRvvUint32m1x5,
    ZigClangBuiltinTypeRvvUint32m1x6,
    ZigClangBuiltinTypeRvvUint32m1x7,
    ZigClangBuiltinTypeRvvUint32m1x8,
    ZigClangBuiltinTypeRvvUint32m2x2,
    ZigClangBuiltinTypeRvvUint32m2x3,
    ZigClangBuiltinTypeRvvUint32m2x4,
    ZigClangBuiltinTypeRvvUint32m4x2,
    ZigClangBuiltinTypeRvvInt64m1x2,
    ZigClangBuiltinTypeRvvInt64m1x3,
    ZigClangBuiltinTypeRvvInt64m1x4,
    ZigClangBuiltinTypeRvvInt64m1x5,
    ZigClangBuiltinTypeRvvInt64m1x6,
    ZigClangBuiltinTypeRvvInt64m1x7,
    ZigClangBuiltinTypeRvvInt64m1x8,
    ZigClangBuiltinTypeRvvInt64m2x2,
    ZigClangBuiltinTypeRvvInt64m2x3,
    ZigClangBuiltinTypeRvvInt64m2x4,
    ZigClangBuiltinTypeRvvInt64m4x2,
    ZigClangBuiltinTypeRvvUint64m1x2,
    ZigClangBuiltinTypeRvvUint64m1x3,
    ZigClangBuiltinTypeRvvUint64m1x4,
    ZigClangBuiltinTypeRvvUint64m1x5,
    ZigClangBuiltinTypeRvvUint64m1x6,
    ZigClangBuiltinTypeRvvUint64m1x7,
    ZigClangBuiltinTypeRvvUint64m1x8,
    ZigClangBuiltinTypeRvvUint64m2x2,
    ZigClangBuiltinTypeRvvUint64m2x3,
    ZigClangBuiltinTypeRvvUint64m2x4,
    ZigClangBuiltinTypeRvvUint64m4x2,
    ZigClangBuiltinTypeRvvFloat16mf4x2,
    ZigClangBuiltinTypeRvvFloat16mf4x3,
    ZigClangBuiltinTypeRvvFloat16mf4x4,
    ZigClangBuiltinTypeRvvFloat16mf4x5,
    ZigClangBuiltinTypeRvvFloat16mf4x6,
    ZigClangBuiltinTypeRvvFloat16mf4x7,
    ZigClangBuiltinTypeRvvFloat16mf4x8,
    ZigClangBuiltinTypeRvvFloat16mf2x2,
    ZigClangBuiltinTypeRvvFloat16mf2x3,
    ZigClangBuiltinTypeRvvFloat16mf2x4,
    ZigClangBuiltinTypeRvvFloat16mf2x5,
    ZigClangBuiltinTypeRvvFloat16mf2x6,
    ZigClangBuiltinTypeRvvFloat16mf2x7,
    ZigClangBuiltinTypeRvvFloat16mf2x8,
    ZigClangBuiltinTypeRvvFloat16m1x2,
    ZigClangBuiltinTypeRvvFloat16m1x3,
    ZigClangBuiltinTypeRvvFloat16m1x4,
    ZigClangBuiltinTypeRvvFloat16m1x5,
    ZigClangBuiltinTypeRvvFloat16m1x6,
    ZigClangBuiltinTypeRvvFloat16m1x7,
    ZigClangBuiltinTypeRvvFloat16m1x8,
    ZigClangBuiltinTypeRvvFloat16m2x2,
    ZigClangBuiltinTypeRvvFloat16m2x3,
    ZigClangBuiltinTypeRvvFloat16m2x4,
    ZigClangBuiltinTypeRvvFloat16m4x2,
    ZigClangBuiltinTypeRvvFloat32mf2x2,
    ZigClangBuiltinTypeRvvFloat32mf2x3,
    ZigClangBuiltinTypeRvvFloat32mf2x4,
    ZigClangBuiltinTypeRvvFloat32mf2x5,
    ZigClangBuiltinTypeRvvFloat32mf2x6,
    ZigClangBuiltinTypeRvvFloat32mf2x7,
    ZigClangBuiltinTypeRvvFloat32mf2x8,
    ZigClangBuiltinTypeRvvFloat32m1x2,
    ZigClangBuiltinTypeRvvFloat32m1x3,
    ZigClangBuiltinTypeRvvFloat32m1x4,
    ZigClangBuiltinTypeRvvFloat32m1x5,
    ZigClangBuiltinTypeRvvFloat32m1x6,
    ZigClangBuiltinTypeRvvFloat32m1x7,
    ZigClangBuiltinTypeRvvFloat32m1x8,
    ZigClangBuiltinTypeRvvFloat32m2x2,
    ZigClangBuiltinTypeRvvFloat32m2x3,
    ZigClangBuiltinTypeRvvFloat32m2x4,
    ZigClangBuiltinTypeRvvFloat32m4x2,
    ZigClangBuiltinTypeRvvFloat64m1x2,
    ZigClangBuiltinTypeRvvFloat64m1x3,
    ZigClangBuiltinTypeRvvFloat64m1x4,
    ZigClangBuiltinTypeRvvFloat64m1x5,
    ZigClangBuiltinTypeRvvFloat64m1x6,
    ZigClangBuiltinTypeRvvFloat64m1x7,
    ZigClangBuiltinTypeRvvFloat64m1x8,
    ZigClangBuiltinTypeRvvFloat64m2x2,
    ZigClangBuiltinTypeRvvFloat64m2x3,
    ZigClangBuiltinTypeRvvFloat64m2x4,
    ZigClangBuiltinTypeRvvFloat64m4x2,
    ZigClangBuiltinTypeRvvBFloat16mf4x2,
    ZigClangBuiltinTypeRvvBFloat16mf4x3,
    ZigClangBuiltinTypeRvvBFloat16mf4x4,
    ZigClangBuiltinTypeRvvBFloat16mf4x5,
    ZigClangBuiltinTypeRvvBFloat16mf4x6,
    ZigClangBuiltinTypeRvvBFloat16mf4x7,
    ZigClangBuiltinTypeRvvBFloat16mf4x8,
    ZigClangBuiltinTypeRvvBFloat16mf2x2,
    ZigClangBuiltinTypeRvvBFloat16mf2x3,
    ZigClangBuiltinTypeRvvBFloat16mf2x4,
    ZigClangBuiltinTypeRvvBFloat16mf2x5,
    ZigClangBuiltinTypeRvvBFloat16mf2x6,
    ZigClangBuiltinTypeRvvBFloat16mf2x7,
    ZigClangBuiltinTypeRvvBFloat16mf2x8,
    ZigClangBuiltinTypeRvvBFloat16m1x2,
    ZigClangBuiltinTypeRvvBFloat16m1x3,
    ZigClangBuiltinTypeRvvBFloat16m1x4,
    ZigClangBuiltinTypeRvvBFloat16m1x5,
    ZigClangBuiltinTypeRvvBFloat16m1x6,
    ZigClangBuiltinTypeRvvBFloat16m1x7,
    ZigClangBuiltinTypeRvvBFloat16m1x8,
    ZigClangBuiltinTypeRvvBFloat16m2x2,
    ZigClangBuiltinTypeRvvBFloat16m2x3,
    ZigClangBuiltinTypeRvvBFloat16m2x4,
    ZigClangBuiltinTypeRvvBFloat16m4x2,
    ZigClangBuiltinTypeWasmExternRef,
    ZigClangBuiltinTypeVoid,
    ZigClangBuiltinTypeBool,
    ZigClangBuiltinTypeChar_U,
    ZigClangBuiltinTypeUChar,
    ZigClangBuiltinTypeWChar_U,
    ZigClangBuiltinTypeChar8,
    ZigClangBuiltinTypeChar16,
    ZigClangBuiltinTypeChar32,
    ZigClangBuiltinTypeUShort,
    ZigClangBuiltinTypeUInt,
    ZigClangBuiltinTypeULong,
    ZigClangBuiltinTypeULongLong,
    ZigClangBuiltinTypeUInt128,
    ZigClangBuiltinTypeChar_S,
    ZigClangBuiltinTypeSChar,
    ZigClangBuiltinTypeWChar_S,
    ZigClangBuiltinTypeShort,
    ZigClangBuiltinTypeInt,
    ZigClangBuiltinTypeLong,
    ZigClangBuiltinTypeLongLong,
    ZigClangBuiltinTypeInt128,
    ZigClangBuiltinTypeShortAccum,
    ZigClangBuiltinTypeAccum,
    ZigClangBuiltinTypeLongAccum,
    ZigClangBuiltinTypeUShortAccum,
    ZigClangBuiltinTypeUAccum,
    ZigClangBuiltinTypeULongAccum,
    ZigClangBuiltinTypeShortFract,
    ZigClangBuiltinTypeFract,
    ZigClangBuiltinTypeLongFract,
    ZigClangBuiltinTypeUShortFract,
    ZigClangBuiltinTypeUFract,
    ZigClangBuiltinTypeULongFract,
    ZigClangBuiltinTypeSatShortAccum,
    ZigClangBuiltinTypeSatAccum,
    ZigClangBuiltinTypeSatLongAccum,
    ZigClangBuiltinTypeSatUShortAccum,
    ZigClangBuiltinTypeSatUAccum,
    ZigClangBuiltinTypeSatULongAccum,
    ZigClangBuiltinTypeSatShortFract,
    ZigClangBuiltinTypeSatFract,
    ZigClangBuiltinTypeSatLongFract,
    ZigClangBuiltinTypeSatUShortFract,
    ZigClangBuiltinTypeSatUFract,
    ZigClangBuiltinTypeSatULongFract,
    ZigClangBuiltinTypeHalf,
    ZigClangBuiltinTypeFloat,
    ZigClangBuiltinTypeDouble,
    ZigClangBuiltinTypeLongDouble,
    ZigClangBuiltinTypeFloat16,
    ZigClangBuiltinTypeBFloat16,
    ZigClangBuiltinTypeFloat128,
    ZigClangBuiltinTypeIbm128,
    ZigClangBuiltinTypeNullPtr,
    ZigClangBuiltinTypeObjCId,
    ZigClangBuiltinTypeObjCClass,
    ZigClangBuiltinTypeObjCSel,
    ZigClangBuiltinTypeOCLSampler,
    ZigClangBuiltinTypeOCLEvent,
    ZigClangBuiltinTypeOCLClkEvent,
    ZigClangBuiltinTypeOCLQueue,
    ZigClangBuiltinTypeOCLReserveID,
    ZigClangBuiltinTypeDependent,
    ZigClangBuiltinTypeOverload,
    ZigClangBuiltinTypeBoundMember,
    ZigClangBuiltinTypePseudoObject,
    ZigClangBuiltinTypeUnknownAny,
    ZigClangBuiltinTypeBuiltinFn,
    ZigClangBuiltinTypeARCUnbridgedCast,
    ZigClangBuiltinTypeIncompleteMatrixIdx,
    ZigClangBuiltinTypeOMPArraySection,
    ZigClangBuiltinTypeOMPArrayShaping,
    ZigClangBuiltinTypeOMPIterator,
};

enum ZigClangCallingConv {
    ZigClangCallingConv_C,
    ZigClangCallingConv_X86StdCall,
    ZigClangCallingConv_X86FastCall,
    ZigClangCallingConv_X86ThisCall,
    ZigClangCallingConv_X86VectorCall,
    ZigClangCallingConv_X86Pascal,
    ZigClangCallingConv_Win64,
    ZigClangCallingConv_X86_64SysV,
    ZigClangCallingConv_X86RegCall,
    ZigClangCallingConv_AAPCS,
    ZigClangCallingConv_AAPCS_VFP,
    ZigClangCallingConv_IntelOclBicc,
    ZigClangCallingConv_SpirFunction,
    ZigClangCallingConv_OpenCLKernel,
    ZigClangCallingConv_Swift,
    ZigClangCallingConv_SwiftAsync,
    ZigClangCallingConv_PreserveMost,
    ZigClangCallingConv_PreserveAll,
    ZigClangCallingConv_AArch64VectorCall,
    ZigClangCallingConv_AArch64SVEPCS,
    ZigClangCallingConv_AMDGPUKernelCall,
    ZigClangCallingConv_M68kRTD,
};

enum ZigClangStorageClass {
    // These are legal on both functions and variables.
    ZigClangStorageClass_None,
    ZigClangStorageClass_Extern,
    ZigClangStorageClass_Static,
    ZigClangStorageClass_PrivateExtern,

    // These are only legal on variables.
    ZigClangStorageClass_Auto,
    ZigClangStorageClass_Register,
};

/// IEEE-754R 4.3: Rounding-direction attributes.
enum ZigClangAPFloat_roundingMode {
    ZigClangAPFloat_roundingMode_TowardZero = 0,
    ZigClangAPFloat_roundingMode_NearestTiesToEven = 1,
    ZigClangAPFloat_roundingMode_TowardPositive = 2,
    ZigClangAPFloat_roundingMode_TowardNegative = 3,
    ZigClangAPFloat_roundingMode_NearestTiesToAway = 4,

    ZigClangAPFloat_roundingMode_Dynamic = 7,
    ZigClangAPFloat_roundingMode_Invalid = -1,
};

enum ZigClangAPFloatBase_Semantics {
    ZigClangAPFloatBase_Semantics_IEEEhalf,
    ZigClangAPFloatBase_Semantics_BFloat,
    ZigClangAPFloatBase_Semantics_IEEEsingle,
    ZigClangAPFloatBase_Semantics_IEEEdouble,
    ZigClangAPFloatBase_Semantics_IEEEquad,
    ZigClangAPFloatBase_Semantics_PPCDoubleDouble,
    ZigClangAPFloatBase_Semantics_Float8E5M2,
    ZigClangAPFloatBase_Semantics_Float8E5M2FNUZ,
    ZigClangAPFloatBase_Semantics_Float8E4M3FN,
    ZigClangAPFloatBase_Semantics_Float8E4M3FNUZ,
    ZigClangAPFloatBase_Semantics_Float8E4M3B11FNUZ,
    ZigClangAPFloatBase_Semantics_FloatTF32,
    ZigClangAPFloatBase_Semantics_x87DoubleExtended,
    ZigClangAPFloatBase_Semantics_MaxSemantics = ZigClangAPFloatBase_Semantics_x87DoubleExtended,
};

enum ZigClangStringLiteral_StringKind {
    ZigClangStringLiteral_StringKind_Ascii,
    ZigClangStringLiteral_StringKind_Wide,
    ZigClangStringLiteral_StringKind_UTF8,
    ZigClangStringLiteral_StringKind_UTF16,
    ZigClangStringLiteral_StringKind_UTF32,
};

enum ZigClangCharacterLiteralKind {
    ZigClangCharacterLiteralKind_Ascii,
    ZigClangCharacterLiteralKind_Wide,
    ZigClangCharacterLiteralKind_UTF8,
    ZigClangCharacterLiteralKind_UTF16,
    ZigClangCharacterLiteralKind_UTF32,
};

enum ZigClangVarDecl_TLSKind {
    ZigClangVarDecl_TLSKind_None,
    ZigClangVarDecl_TLSKind_Static,
    ZigClangVarDecl_TLSKind_Dynamic,
};

enum ZigClangElaboratedTypeKeyword {
    ZigClangElaboratedTypeKeyword_Struct,
    ZigClangElaboratedTypeKeyword_Interface,
    ZigClangElaboratedTypeKeyword_Union,
    ZigClangElaboratedTypeKeyword_Class,
    ZigClangElaboratedTypeKeyword_Enum,
    ZigClangElaboratedTypeKeyword_Typename,
    ZigClangElaboratedTypeKeyword_None,
};

enum ZigClangPreprocessedEntity_EntityKind {
    ZigClangPreprocessedEntity_InvalidKind,
    ZigClangPreprocessedEntity_MacroExpansionKind,
    ZigClangPreprocessedEntity_MacroDefinitionKind,
    ZigClangPreprocessedEntity_InclusionDirectiveKind,
};

enum ZigClangExpr_ConstantExprKind {
    ZigClangExpr_ConstantExprKind_Normal,
    ZigClangExpr_ConstantExprKind_NonClassTemplateArgument,
    ZigClangExpr_ConstantExprKind_ClassTemplateArgument,
    ZigClangExpr_ConstantExprKind_ImmediateInvocation,
};

enum ZigClangUnaryExprOrTypeTrait_Kind {
    ZigClangUnaryExprOrTypeTrait_KindSizeOf,
    ZigClangUnaryExprOrTypeTrait_KindDataSizeOf,
    ZigClangUnaryExprOrTypeTrait_KindAlignOf,
    ZigClangUnaryExprOrTypeTrait_KindPreferredAlignOf,
    ZigClangUnaryExprOrTypeTrait_KindVecStep,
    ZigClangUnaryExprOrTypeTrait_KindOpenMPRequiredSimdAlign,
};

enum ZigClangOffsetOfNode_Kind {
    ZigClangOffsetOfNode_KindArray,
    ZigClangOffsetOfNode_KindField,
    ZigClangOffsetOfNode_KindIdentifier,
    ZigClangOffsetOfNode_KindBase,
};

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangSourceManager_getSpellingLoc(const struct ZigClangSourceManager *,
        struct ZigClangSourceLocation Loc);
ZIG_EXTERN_C const char *ZigClangSourceManager_getFilename(const struct ZigClangSourceManager *,
        struct ZigClangSourceLocation SpellingLoc);
ZIG_EXTERN_C unsigned ZigClangSourceManager_getSpellingLineNumber(const struct ZigClangSourceManager *,
        struct ZigClangSourceLocation Loc);
ZIG_EXTERN_C unsigned ZigClangSourceManager_getSpellingColumnNumber(const struct ZigClangSourceManager *,
        struct ZigClangSourceLocation Loc);
ZIG_EXTERN_C const char* ZigClangSourceManager_getCharacterData(const struct ZigClangSourceManager *,
        struct ZigClangSourceLocation SL);

ZIG_EXTERN_C struct ZigClangQualType ZigClangASTContext_getPointerType(const struct ZigClangASTContext*, struct ZigClangQualType T);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangLexer_getLocForEndOfToken(struct ZigClangSourceLocation,
        const ZigClangSourceManager *, const ZigClangASTUnit *);

// Can return null.
ZIG_EXTERN_C struct ZigClangASTUnit *ZigClangLoadFromCommandLine(
        const char **args_begin, const char **args_end,
        struct Stage2ErrorMsg **errors_ptr, size_t *errors_len, const char *resources_path);
ZIG_EXTERN_C void ZigClangASTUnit_delete(struct ZigClangASTUnit *);
ZIG_EXTERN_C void ZigClangErrorMsg_delete(struct Stage2ErrorMsg *ptr, size_t len);

ZIG_EXTERN_C struct ZigClangASTContext *ZigClangASTUnit_getASTContext(struct ZigClangASTUnit *);
ZIG_EXTERN_C struct ZigClangSourceManager *ZigClangASTUnit_getSourceManager(struct ZigClangASTUnit *);
ZIG_EXTERN_C bool ZigClangASTUnit_visitLocalTopLevelDecls(struct ZigClangASTUnit *, void *context,
    bool (*Fn)(void *context, const struct ZigClangDecl *decl));
ZIG_EXTERN_C struct ZigClangPreprocessingRecord_iterator ZigClangASTUnit_getLocalPreprocessingEntities_begin(struct ZigClangASTUnit *);
ZIG_EXTERN_C struct ZigClangPreprocessingRecord_iterator ZigClangASTUnit_getLocalPreprocessingEntities_end(struct ZigClangASTUnit *);

ZIG_EXTERN_C struct ZigClangPreprocessedEntity *ZigClangPreprocessingRecord_iterator_deref(
        struct ZigClangPreprocessingRecord_iterator);

ZIG_EXTERN_C enum ZigClangPreprocessedEntity_EntityKind ZigClangPreprocessedEntity_getKind(const struct ZigClangPreprocessedEntity *);

ZIG_EXTERN_C const struct ZigClangRecordDecl *ZigClangRecordType_getDecl(const struct ZigClangRecordType *record_ty);
ZIG_EXTERN_C const struct ZigClangEnumDecl *ZigClangEnumType_getDecl(const struct ZigClangEnumType *record_ty);

ZIG_EXTERN_C bool ZigClangTagDecl_isThisDeclarationADefinition(const struct ZigClangTagDecl *);

ZIG_EXTERN_C const struct ZigClangTagDecl *ZigClangRecordDecl_getCanonicalDecl(const struct ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C const struct ZigClangTagDecl *ZigClangEnumDecl_getCanonicalDecl(const struct ZigClangEnumDecl *);
ZIG_EXTERN_C const struct ZigClangFieldDecl *ZigClangFieldDecl_getCanonicalDecl(const ZigClangFieldDecl *);
ZIG_EXTERN_C const struct ZigClangTypedefNameDecl *ZigClangTypedefNameDecl_getCanonicalDecl(const struct ZigClangTypedefNameDecl *);
ZIG_EXTERN_C const struct ZigClangFunctionDecl *ZigClangFunctionDecl_getCanonicalDecl(const ZigClangFunctionDecl *self);
ZIG_EXTERN_C const struct ZigClangVarDecl *ZigClangVarDecl_getCanonicalDecl(const ZigClangVarDecl *self);
ZIG_EXTERN_C const char* ZigClangVarDecl_getSectionAttribute(const struct ZigClangVarDecl *self, size_t *len);
ZIG_EXTERN_C const struct ZigClangFunctionDecl *ZigClangVarDecl_getCleanupAttribute(const struct ZigClangVarDecl *self);
ZIG_EXTERN_C unsigned ZigClangVarDecl_getAlignedAttribute(const struct ZigClangVarDecl *self, const ZigClangASTContext* ctx);
ZIG_EXTERN_C unsigned ZigClangFunctionDecl_getAlignedAttribute(const struct ZigClangFunctionDecl *self, const ZigClangASTContext* ctx);
ZIG_EXTERN_C unsigned ZigClangFieldDecl_getAlignedAttribute(const struct ZigClangFieldDecl *self, const ZigClangASTContext* ctx);
ZIG_EXTERN_C bool ZigClangVarDecl_getPackedAttribute(const struct ZigClangVarDecl *self);
ZIG_EXTERN_C bool ZigClangFieldDecl_getPackedAttribute(const struct ZigClangFieldDecl *self);

ZIG_EXTERN_C const struct ZigClangStringLiteral *ZigClangFileScopeAsmDecl_getAsmString(const struct ZigClangFileScopeAsmDecl *self);

ZIG_EXTERN_C struct ZigClangQualType ZigClangParmVarDecl_getOriginalType(const struct ZigClangParmVarDecl *self);

ZIG_EXTERN_C bool ZigClangRecordDecl_getPackedAttribute(const struct ZigClangRecordDecl *);
ZIG_EXTERN_C const struct ZigClangRecordDecl *ZigClangRecordDecl_getDefinition(const struct ZigClangRecordDecl *);
ZIG_EXTERN_C const struct ZigClangEnumDecl *ZigClangEnumDecl_getDefinition(const struct ZigClangEnumDecl *);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangRecordDecl_getLocation(const struct ZigClangRecordDecl *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangEnumDecl_getLocation(const struct ZigClangEnumDecl *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangTypedefNameDecl_getLocation(const struct ZigClangTypedefNameDecl *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangDecl_getLocation(const struct ZigClangDecl *);

ZIG_EXTERN_C const struct ZigClangASTRecordLayout *ZigClangRecordDecl_getASTRecordLayout(const struct ZigClangRecordDecl *, const struct ZigClangASTContext *);

ZIG_EXTERN_C uint64_t ZigClangASTRecordLayout_getFieldOffset(const struct ZigClangASTRecordLayout *, unsigned);
ZIG_EXTERN_C int64_t ZigClangASTRecordLayout_getAlignment(const struct ZigClangASTRecordLayout *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangFunctionDecl_getType(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangFunctionDecl_getLocation(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C bool ZigClangFunctionDecl_hasBody(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C enum ZigClangStorageClass ZigClangFunctionDecl_getStorageClass(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C const struct ZigClangParmVarDecl *ZigClangFunctionDecl_getParamDecl(const struct ZigClangFunctionDecl *, unsigned i);
ZIG_EXTERN_C const struct ZigClangStmt *ZigClangFunctionDecl_getBody(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C bool ZigClangFunctionDecl_doesDeclarationForceExternallyVisibleDefinition(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C bool ZigClangFunctionDecl_isThisDeclarationADefinition(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C bool ZigClangFunctionDecl_doesThisDeclarationHaveABody(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C bool ZigClangFunctionDecl_isInlineSpecified(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C bool ZigClangFunctionDecl_hasAlwaysInlineAttr(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C bool ZigClangFunctionDecl_isDefined(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C const struct ZigClangFunctionDecl* ZigClangFunctionDecl_getDefinition(const struct ZigClangFunctionDecl *);
ZIG_EXTERN_C const char* ZigClangFunctionDecl_getSectionAttribute(const struct ZigClangFunctionDecl *, size_t *);

ZIG_EXTERN_C bool ZigClangRecordDecl_isUnion(const struct ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C bool ZigClangRecordDecl_isStruct(const struct ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C bool ZigClangRecordDecl_isAnonymousStructOrUnion(const struct ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C ZigClangRecordDecl_field_iterator ZigClangRecordDecl_field_begin(const struct ZigClangRecordDecl *);
ZIG_EXTERN_C ZigClangRecordDecl_field_iterator ZigClangRecordDecl_field_end(const struct ZigClangRecordDecl *);
ZIG_EXTERN_C ZigClangRecordDecl_field_iterator ZigClangRecordDecl_field_iterator_next(struct ZigClangRecordDecl_field_iterator);
ZIG_EXTERN_C const struct ZigClangFieldDecl * ZigClangRecordDecl_field_iterator_deref(struct ZigClangRecordDecl_field_iterator);
ZIG_EXTERN_C bool ZigClangRecordDecl_field_iterator_neq(
        struct ZigClangRecordDecl_field_iterator a,
        struct ZigClangRecordDecl_field_iterator b);

ZIG_EXTERN_C struct ZigClangQualType ZigClangEnumDecl_getIntegerType(const struct ZigClangEnumDecl *);
ZIG_EXTERN_C ZigClangEnumDecl_enumerator_iterator ZigClangEnumDecl_enumerator_begin(const struct ZigClangEnumDecl *);
ZIG_EXTERN_C ZigClangEnumDecl_enumerator_iterator ZigClangEnumDecl_enumerator_end(const struct ZigClangEnumDecl *);
ZIG_EXTERN_C ZigClangEnumDecl_enumerator_iterator ZigClangEnumDecl_enumerator_iterator_next(struct ZigClangEnumDecl_enumerator_iterator);
ZIG_EXTERN_C const struct ZigClangEnumConstantDecl * ZigClangEnumDecl_enumerator_iterator_deref(struct ZigClangEnumDecl_enumerator_iterator);
ZIG_EXTERN_C bool ZigClangEnumDecl_enumerator_iterator_neq(
        struct ZigClangEnumDecl_enumerator_iterator a,
        struct ZigClangEnumDecl_enumerator_iterator b);

ZIG_EXTERN_C const ZigClangNamedDecl* ZigClangDecl_castToNamedDecl(const ZigClangDecl *self);
ZIG_EXTERN_C const char *ZigClangNamedDecl_getName_bytes_begin(const struct ZigClangNamedDecl *self);
ZIG_EXTERN_C enum ZigClangDeclKind ZigClangDecl_getKind(const struct ZigClangDecl *decl);
ZIG_EXTERN_C const char *ZigClangDecl_getDeclKindName(const struct ZigClangDecl *decl);

ZIG_EXTERN_C struct ZigClangQualType ZigClangVarDecl_getType(const struct ZigClangVarDecl *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangVarDecl_getInit(const struct ZigClangVarDecl *var_decl);
ZIG_EXTERN_C enum ZigClangVarDecl_TLSKind ZigClangVarDecl_getTLSKind(const struct ZigClangVarDecl *var_decl);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangVarDecl_getLocation(const struct ZigClangVarDecl *);
ZIG_EXTERN_C bool ZigClangVarDecl_hasExternalStorage(const struct ZigClangVarDecl *);
ZIG_EXTERN_C bool ZigClangVarDecl_isFileVarDecl(const struct ZigClangVarDecl *);
ZIG_EXTERN_C bool ZigClangVarDecl_hasInit(const struct ZigClangVarDecl *);
ZIG_EXTERN_C const struct ZigClangAPValue *ZigClangVarDecl_evaluateValue(const struct ZigClangVarDecl *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangVarDecl_getTypeSourceInfo_getType(const struct ZigClangVarDecl *);
ZIG_EXTERN_C enum ZigClangStorageClass ZigClangVarDecl_getStorageClass(const struct ZigClangVarDecl *self);
ZIG_EXTERN_C bool ZigClangVarDecl_isStaticLocal(const struct ZigClangVarDecl *self);

ZIG_EXTERN_C bool ZigClangSourceLocation_eq(struct ZigClangSourceLocation a, struct ZigClangSourceLocation b);

ZIG_EXTERN_C const struct ZigClangTypedefNameDecl *ZigClangTypedefType_getDecl(const struct ZigClangTypedefType *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangTypedefNameDecl_getUnderlyingType(const struct ZigClangTypedefNameDecl *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangQualType_getCanonicalType(struct ZigClangQualType);
ZIG_EXTERN_C const struct ZigClangType *ZigClangQualType_getTypePtr(struct ZigClangQualType);
ZIG_EXTERN_C enum ZigClangTypeClass ZigClangQualType_getTypeClass(struct ZigClangQualType);
ZIG_EXTERN_C void ZigClangQualType_addConst(struct ZigClangQualType *);
ZIG_EXTERN_C bool ZigClangQualType_eq(struct ZigClangQualType, struct ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isConstQualified(struct ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isVolatileQualified(struct ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isRestrictQualified(struct ZigClangQualType);

ZIG_EXTERN_C enum ZigClangTypeClass ZigClangType_getTypeClass(const struct ZigClangType *self);
ZIG_EXTERN_C struct ZigClangQualType ZigClangType_getPointeeType(const struct ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isBooleanType(const struct ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isVoidType(const struct ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isArrayType(const struct ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isRecordType(const struct ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isVectorType(const struct ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isIncompleteOrZeroLengthArrayType(const ZigClangQualType *self, const struct ZigClangASTContext *ctx);
ZIG_EXTERN_C bool ZigClangType_isConstantArrayType(const ZigClangType *self);
ZIG_EXTERN_C const char *ZigClangType_getTypeClassName(const struct ZigClangType *self);
ZIG_EXTERN_C const struct ZigClangArrayType *ZigClangType_getAsArrayTypeUnsafe(const struct ZigClangType *self);
ZIG_EXTERN_C const ZigClangRecordType *ZigClangType_getAsRecordType(const ZigClangType *self);
ZIG_EXTERN_C const ZigClangRecordType *ZigClangType_getAsUnionType(const ZigClangType *self);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangStmt_getBeginLoc(const struct ZigClangStmt *self);
ZIG_EXTERN_C enum ZigClangStmtClass ZigClangStmt_getStmtClass(const struct ZigClangStmt *self);
ZIG_EXTERN_C bool ZigClangStmt_classof_Expr(const struct ZigClangStmt *self);

ZIG_EXTERN_C enum ZigClangStmtClass ZigClangExpr_getStmtClass(const struct ZigClangExpr *self);
ZIG_EXTERN_C struct ZigClangQualType ZigClangExpr_getType(const struct ZigClangExpr *self);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangExpr_getBeginLoc(const struct ZigClangExpr *self);
ZIG_EXTERN_C bool ZigClangExpr_EvaluateAsBooleanCondition(const struct ZigClangExpr *self,
        bool *result, const struct ZigClangASTContext *ctx, bool in_constant_context);
ZIG_EXTERN_C bool ZigClangExpr_EvaluateAsFloat(const struct ZigClangExpr *self,
        ZigClangAPFloat **result, const struct ZigClangASTContext *ctx);
ZIG_EXTERN_C bool ZigClangExpr_EvaluateAsConstantExpr(const struct ZigClangExpr *,
        struct ZigClangExprEvalResult *, ZigClangExpr_ConstantExprKind, const struct ZigClangASTContext *);
ZIG_EXTERN_C const struct ZigClangStringLiteral *ZigClangExpr_castToStringLiteral(const struct ZigClangExpr *self);

ZIG_EXTERN_C const ZigClangExpr *ZigClangInitListExpr_getInit(const ZigClangInitListExpr *, unsigned);
ZIG_EXTERN_C const ZigClangExpr *ZigClangInitListExpr_getArrayFiller(const ZigClangInitListExpr *);
ZIG_EXTERN_C bool ZigClangInitListExpr_hasArrayFiller(const ZigClangInitListExpr *);
ZIG_EXTERN_C bool ZigClangInitListExpr_isStringLiteralInit(const ZigClangInitListExpr *);
ZIG_EXTERN_C unsigned ZigClangInitListExpr_getNumInits(const ZigClangInitListExpr *);
ZIG_EXTERN_C const ZigClangFieldDecl *ZigClangInitListExpr_getInitializedFieldInUnion(const ZigClangInitListExpr *self);

ZIG_EXTERN_C enum ZigClangAPValueKind ZigClangAPValue_getKind(const struct ZigClangAPValue *self);
ZIG_EXTERN_C const struct ZigClangAPSInt *ZigClangAPValue_getInt(const struct ZigClangAPValue *self);
ZIG_EXTERN_C unsigned ZigClangAPValue_getArrayInitializedElts(const struct ZigClangAPValue *self);
ZIG_EXTERN_C const struct ZigClangAPValue *ZigClangAPValue_getArrayInitializedElt(const struct ZigClangAPValue *self, unsigned i);
ZIG_EXTERN_C const struct ZigClangAPValue *ZigClangAPValue_getArrayFiller(const struct ZigClangAPValue *self);
ZIG_EXTERN_C unsigned ZigClangAPValue_getArraySize(const struct ZigClangAPValue *self);
ZIG_EXTERN_C struct ZigClangAPValueLValueBase ZigClangAPValue_getLValueBase(const struct ZigClangAPValue *self);

ZIG_EXTERN_C bool ZigClangAPSInt_isSigned(const struct ZigClangAPSInt *self);
ZIG_EXTERN_C bool ZigClangAPSInt_isNegative(const struct ZigClangAPSInt *self);
ZIG_EXTERN_C const struct ZigClangAPSInt *ZigClangAPSInt_negate(const struct ZigClangAPSInt *self);
ZIG_EXTERN_C void ZigClangAPSInt_free(const struct ZigClangAPSInt *self);
ZIG_EXTERN_C const uint64_t *ZigClangAPSInt_getRawData(const struct ZigClangAPSInt *self);
ZIG_EXTERN_C unsigned ZigClangAPSInt_getNumWords(const struct ZigClangAPSInt *self);
ZIG_EXTERN_C bool ZigClangAPSInt_lessThanEqual(const struct ZigClangAPSInt *self, uint64_t rhs);

ZIG_EXTERN_C uint64_t ZigClangAPInt_getLimitedValue(const struct ZigClangAPInt *self, uint64_t limit);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangAPValueLValueBase_dyn_cast_Expr(struct ZigClangAPValueLValueBase self);

ZIG_EXTERN_C enum ZigClangBuiltinTypeKind ZigClangBuiltinType_getKind(const struct ZigClangBuiltinType *self);

ZIG_EXTERN_C bool ZigClangFunctionType_getNoReturnAttr(const struct ZigClangFunctionType *self);
ZIG_EXTERN_C enum ZigClangCallingConv ZigClangFunctionType_getCallConv(const struct ZigClangFunctionType *self);
ZIG_EXTERN_C struct ZigClangQualType ZigClangFunctionType_getReturnType(const struct ZigClangFunctionType *self);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangGenericSelectionExpr_getResultExpr(const struct ZigClangGenericSelectionExpr *self);

ZIG_EXTERN_C bool ZigClangFunctionProtoType_isVariadic(const struct ZigClangFunctionProtoType *self);
ZIG_EXTERN_C unsigned ZigClangFunctionProtoType_getNumParams(const struct ZigClangFunctionProtoType *self);
ZIG_EXTERN_C struct ZigClangQualType ZigClangFunctionProtoType_getParamType(const struct ZigClangFunctionProtoType *self, unsigned i);
ZIG_EXTERN_C struct ZigClangQualType ZigClangFunctionProtoType_getReturnType(const struct ZigClangFunctionProtoType *self);


ZIG_EXTERN_C ZigClangCompoundStmt_const_body_iterator ZigClangCompoundStmt_body_begin(const struct ZigClangCompoundStmt *self);
ZIG_EXTERN_C ZigClangCompoundStmt_const_body_iterator ZigClangCompoundStmt_body_end(const struct ZigClangCompoundStmt *self);

ZIG_EXTERN_C ZigClangDeclStmt_const_decl_iterator ZigClangDeclStmt_decl_begin(const struct ZigClangDeclStmt *self);
ZIG_EXTERN_C ZigClangDeclStmt_const_decl_iterator ZigClangDeclStmt_decl_end(const struct ZigClangDeclStmt *self);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangDeclStmt_getBeginLoc(const struct ZigClangDeclStmt *self);

ZIG_EXTERN_C unsigned ZigClangAPFloat_convertToHexString(const struct ZigClangAPFloat *self, char *DST,
        unsigned HexDigits, bool UpperCase, enum ZigClangAPFloat_roundingMode RM);
ZIG_EXTERN_C double ZigClangFloatingLiteral_getValueAsApproximateDouble(const ZigClangFloatingLiteral *self);
ZIG_EXTERN_C void ZigClangFloatingLiteral_getValueAsApproximateQuadBits(const ZigClangFloatingLiteral *self, uint64_t *low, uint64_t *high);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangFloatingLiteral_getBeginLoc(const struct ZigClangFloatingLiteral *);
ZIG_EXTERN_C ZigClangAPFloatBase_Semantics ZigClangFloatingLiteral_getRawSemantics(const ZigClangFloatingLiteral *self);


ZIG_EXTERN_C enum ZigClangCharacterLiteralKind ZigClangStringLiteral_getKind(
        const struct ZigClangStringLiteral *self);
ZIG_EXTERN_C uint32_t ZigClangStringLiteral_getCodeUnit(const struct ZigClangStringLiteral *self, size_t i);
ZIG_EXTERN_C unsigned ZigClangStringLiteral_getLength(const struct ZigClangStringLiteral *self);
ZIG_EXTERN_C unsigned ZigClangStringLiteral_getCharByteWidth(const struct ZigClangStringLiteral *self);

ZIG_EXTERN_C const char *ZigClangStringLiteral_getString_bytes_begin_size(const struct ZigClangStringLiteral *self,
        size_t *len);

ZIG_EXTERN_C const struct ZigClangStringLiteral *ZigClangPredefinedExpr_getFunctionName(
        const struct ZigClangPredefinedExpr *self);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangImplicitCastExpr_getBeginLoc(const struct ZigClangImplicitCastExpr *);
ZIG_EXTERN_C enum ZigClangCK ZigClangImplicitCastExpr_getCastKind(const struct ZigClangImplicitCastExpr *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangImplicitCastExpr_getSubExpr(const struct ZigClangImplicitCastExpr *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangArrayType_getElementType(const struct ZigClangArrayType *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangIncompleteArrayType_getElementType(const struct ZigClangIncompleteArrayType *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangConstantArrayType_getElementType(const struct ZigClangConstantArrayType *);
ZIG_EXTERN_C const struct ZigClangAPInt *ZigClangConstantArrayType_getSize(const struct ZigClangConstantArrayType *);

ZIG_EXTERN_C const struct ZigClangValueDecl *ZigClangDeclRefExpr_getDecl(const struct ZigClangDeclRefExpr *);
ZIG_EXTERN_C const struct ZigClangNamedDecl *ZigClangDeclRefExpr_getFoundDecl(const struct ZigClangDeclRefExpr *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangParenType_getInnerType(const struct ZigClangParenType *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangAttributedType_getEquivalentType(const struct ZigClangAttributedType *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangMacroQualifiedType_getModifiedType(const struct ZigClangMacroQualifiedType *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangTypeOfType_getUnmodifiedType(const struct ZigClangTypeOfType *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangTypeOfExprType_getUnderlyingExpr(const struct ZigClangTypeOfExprType *);

ZIG_EXTERN_C enum ZigClangOffsetOfNode_Kind ZigClangOffsetOfNode_getKind(const struct ZigClangOffsetOfNode *);
ZIG_EXTERN_C unsigned ZigClangOffsetOfNode_getArrayExprIndex(const struct ZigClangOffsetOfNode *);
ZIG_EXTERN_C struct ZigClangFieldDecl * ZigClangOffsetOfNode_getField(const struct ZigClangOffsetOfNode *);

ZIG_EXTERN_C unsigned ZigClangOffsetOfExpr_getNumComponents(const struct ZigClangOffsetOfExpr *);
ZIG_EXTERN_C unsigned ZigClangOffsetOfExpr_getNumExpressions(const struct ZigClangOffsetOfExpr *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangOffsetOfExpr_getIndexExpr(const struct ZigClangOffsetOfExpr *, unsigned idx);
ZIG_EXTERN_C const struct ZigClangOffsetOfNode *ZigClangOffsetOfExpr_getComponent(const struct ZigClangOffsetOfExpr *, unsigned idx);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangOffsetOfExpr_getBeginLoc(const struct ZigClangOffsetOfExpr *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangElaboratedType_getNamedType(const struct ZigClangElaboratedType *);
ZIG_EXTERN_C enum ZigClangElaboratedTypeKeyword ZigClangElaboratedType_getKeyword(const struct ZigClangElaboratedType *);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangCStyleCastExpr_getBeginLoc(const struct ZigClangCStyleCastExpr *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangCStyleCastExpr_getSubExpr(const struct ZigClangCStyleCastExpr *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangCStyleCastExpr_getType(const struct ZigClangCStyleCastExpr *);

ZIG_EXTERN_C bool ZigClangIntegerLiteral_EvaluateAsInt(const struct ZigClangIntegerLiteral *, struct ZigClangExprEvalResult *, const struct ZigClangASTContext *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangIntegerLiteral_getBeginLoc(const struct ZigClangIntegerLiteral *);
ZIG_EXTERN_C bool ZigClangIntegerLiteral_getSignum(const struct ZigClangIntegerLiteral *, int *, const struct ZigClangASTContext *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangReturnStmt_getRetValue(const struct ZigClangReturnStmt *);

ZIG_EXTERN_C enum ZigClangBO ZigClangBinaryOperator_getOpcode(const struct ZigClangBinaryOperator *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangBinaryOperator_getBeginLoc(const struct ZigClangBinaryOperator *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangBinaryOperator_getLHS(const struct ZigClangBinaryOperator *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangBinaryOperator_getRHS(const struct ZigClangBinaryOperator *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangBinaryOperator_getType(const struct ZigClangBinaryOperator *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangConvertVectorExpr_getSrcExpr(const struct ZigClangConvertVectorExpr *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangConvertVectorExpr_getTypeSourceInfo_getType(const struct ZigClangConvertVectorExpr *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangDecayedType_getDecayedType(const struct ZigClangDecayedType *);

ZIG_EXTERN_C const struct ZigClangCompoundStmt *ZigClangStmtExpr_getSubStmt(const struct ZigClangStmtExpr *);

ZIG_EXTERN_C enum ZigClangCK ZigClangCastExpr_getCastKind(const struct ZigClangCastExpr *);
ZIG_EXTERN_C const struct ZigClangFieldDecl *ZigClangCastExpr_getTargetFieldForToUnionCast(const struct ZigClangCastExpr *, struct ZigClangQualType, struct ZigClangQualType);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangCharacterLiteral_getBeginLoc(const struct ZigClangCharacterLiteral *);
ZIG_EXTERN_C enum ZigClangCharacterLiteralKind ZigClangCharacterLiteral_getKind(const struct ZigClangCharacterLiteral *);
ZIG_EXTERN_C unsigned ZigClangCharacterLiteral_getValue(const struct ZigClangCharacterLiteral *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangChooseExpr_getChosenSubExpr(const struct ZigClangChooseExpr *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangAbstractConditionalOperator_getCond(const struct ZigClangAbstractConditionalOperator *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangAbstractConditionalOperator_getTrueExpr(const struct ZigClangAbstractConditionalOperator *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangAbstractConditionalOperator_getFalseExpr(const struct ZigClangAbstractConditionalOperator *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangCompoundAssignOperator_getType(const struct ZigClangCompoundAssignOperator *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangCompoundAssignOperator_getComputationLHSType(const struct ZigClangCompoundAssignOperator *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangCompoundAssignOperator_getComputationResultType(const struct ZigClangCompoundAssignOperator *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangCompoundAssignOperator_getBeginLoc(const struct ZigClangCompoundAssignOperator *);
ZIG_EXTERN_C enum ZigClangBO ZigClangCompoundAssignOperator_getOpcode(const struct ZigClangCompoundAssignOperator *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangCompoundAssignOperator_getLHS(const struct ZigClangCompoundAssignOperator *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangCompoundAssignOperator_getRHS(const struct ZigClangCompoundAssignOperator *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangCompoundLiteralExpr_getInitializer(const struct ZigClangCompoundLiteralExpr *);

ZIG_EXTERN_C enum ZigClangUO ZigClangUnaryOperator_getOpcode(const struct ZigClangUnaryOperator *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangUnaryOperator_getType(const struct ZigClangUnaryOperator *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangUnaryOperator_getSubExpr(const struct ZigClangUnaryOperator *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangUnaryOperator_getBeginLoc(const struct ZigClangUnaryOperator *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangValueDecl_getType(const struct ZigClangValueDecl *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangVectorType_getElementType(const struct ZigClangVectorType *);
ZIG_EXTERN_C unsigned ZigClangVectorType_getNumElements(const struct ZigClangVectorType *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangWhileStmt_getCond(const struct ZigClangWhileStmt *);
ZIG_EXTERN_C const struct ZigClangStmt *ZigClangWhileStmt_getBody(const struct ZigClangWhileStmt *);

ZIG_EXTERN_C const struct ZigClangStmt *ZigClangIfStmt_getThen(const struct ZigClangIfStmt *);
ZIG_EXTERN_C const struct ZigClangStmt *ZigClangIfStmt_getElse(const struct ZigClangIfStmt *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangIfStmt_getCond(const struct ZigClangIfStmt *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangCallExpr_getCallee(const struct ZigClangCallExpr *);
ZIG_EXTERN_C unsigned ZigClangCallExpr_getNumArgs(const struct ZigClangCallExpr *);
ZIG_EXTERN_C const struct ZigClangExpr * const * ZigClangCallExpr_getArgs(const struct ZigClangCallExpr *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangMemberExpr_getBase(const struct ZigClangMemberExpr *);
ZIG_EXTERN_C bool ZigClangMemberExpr_isArrow(const struct ZigClangMemberExpr *);
ZIG_EXTERN_C const struct ZigClangValueDecl * ZigClangMemberExpr_getMemberDecl(const struct ZigClangMemberExpr *);

ZIG_EXTERN_C const ZigClangExpr *ZigClangOpaqueValueExpr_getSourceExpr(const struct ZigClangOpaqueValueExpr *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangArraySubscriptExpr_getBase(const struct ZigClangArraySubscriptExpr *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangArraySubscriptExpr_getIdx(const struct ZigClangArraySubscriptExpr *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangUnaryExprOrTypeTraitExpr_getTypeOfArgument(const struct ZigClangUnaryExprOrTypeTraitExpr *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangUnaryExprOrTypeTraitExpr_getBeginLoc(const struct ZigClangUnaryExprOrTypeTraitExpr *);
ZIG_EXTERN_C enum ZigClangUnaryExprOrTypeTrait_Kind ZigClangUnaryExprOrTypeTraitExpr_getKind(const struct ZigClangUnaryExprOrTypeTraitExpr *);

ZIG_EXTERN_C unsigned ZigClangShuffleVectorExpr_getNumSubExprs(const struct ZigClangShuffleVectorExpr *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangShuffleVectorExpr_getExpr(const struct ZigClangShuffleVectorExpr *, unsigned);

ZIG_EXTERN_C const struct ZigClangStmt *ZigClangDoStmt_getBody(const struct ZigClangDoStmt *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangDoStmt_getCond(const struct ZigClangDoStmt *);

ZIG_EXTERN_C const struct ZigClangStmt *ZigClangForStmt_getInit(const struct ZigClangForStmt *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangForStmt_getCond(const struct ZigClangForStmt *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangForStmt_getInc(const struct ZigClangForStmt *);
ZIG_EXTERN_C const struct ZigClangStmt *ZigClangForStmt_getBody(const struct ZigClangForStmt *);

ZIG_EXTERN_C const struct ZigClangDeclStmt *ZigClangSwitchStmt_getConditionVariableDeclStmt(const struct ZigClangSwitchStmt *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangSwitchStmt_getCond(const struct ZigClangSwitchStmt *);
ZIG_EXTERN_C const struct ZigClangStmt *ZigClangSwitchStmt_getBody(const struct ZigClangSwitchStmt *);
ZIG_EXTERN_C bool ZigClangSwitchStmt_isAllEnumCasesCovered(const struct ZigClangSwitchStmt *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangCaseStmt_getLHS(const struct ZigClangCaseStmt *);
ZIG_EXTERN_C const struct ZigClangExpr *ZigClangCaseStmt_getRHS(const struct ZigClangCaseStmt *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangCaseStmt_getBeginLoc(const struct ZigClangCaseStmt *);
ZIG_EXTERN_C const struct ZigClangStmt *ZigClangCaseStmt_getSubStmt(const struct ZigClangCaseStmt *);

ZIG_EXTERN_C const struct ZigClangStmt *ZigClangDefaultStmt_getSubStmt(const struct ZigClangDefaultStmt *);

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangParenExpr_getSubExpr(const struct ZigClangParenExpr *);

ZIG_EXTERN_C const char *ZigClangMacroDefinitionRecord_getName_getNameStart(const struct ZigClangMacroDefinitionRecord *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangMacroDefinitionRecord_getSourceRange_getBegin(const struct ZigClangMacroDefinitionRecord *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangMacroDefinitionRecord_getSourceRange_getEnd(const struct ZigClangMacroDefinitionRecord *);

ZIG_EXTERN_C bool ZigClangFieldDecl_isBitField(const struct ZigClangFieldDecl *);
ZIG_EXTERN_C bool ZigClangFieldDecl_isAnonymousStructOrUnion(const ZigClangFieldDecl *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangFieldDecl_getType(const struct ZigClangFieldDecl *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangFieldDecl_getLocation(const struct ZigClangFieldDecl *);
ZIG_EXTERN_C const struct ZigClangRecordDecl *ZigClangFieldDecl_getParent(const struct ZigClangFieldDecl *);
ZIG_EXTERN_C unsigned ZigClangFieldDecl_getFieldIndex(const struct ZigClangFieldDecl *);

ZIG_EXTERN_C const struct ZigClangAPSInt *ZigClangEnumConstantDecl_getInitVal(const struct ZigClangEnumConstantDecl *);
ZIG_EXTERN_C bool ZigClangIsLLVMUsingSeparateLibcxx();
#endif
