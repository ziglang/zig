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

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

// ATTENTION: If you modify this file, be sure to update the corresponding
// extern function declarations in the self-hosted compiler file
// src-self-hosted/clang.zig.

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

struct ZigClangAPValue;
struct ZigClangAPSInt;
struct ZigClangASTContext;
struct ZigClangASTUnit;
struct ZigClangArraySubscriptExpr;
struct ZigClangArrayType;
struct ZigClangAttributedType;
struct ZigClangBinaryOperator;
struct ZigClangBreakStmt;
struct ZigClangBuiltinType;
struct ZigClangCStyleCastExpr;
struct ZigClangCallExpr;
struct ZigClangCaseStmt;
struct ZigClangCompoundAssignOperator;
struct ZigClangCompoundStmt;
struct ZigClangConditionalOperator;
struct ZigClangConstantArrayType;
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
struct ZigClangForStmt;
struct ZigClangFullSourceLoc;
struct ZigClangFunctionDecl;
struct ZigClangFunctionProtoType;
struct ZigClangIfStmt;
struct ZigClangImplicitCastExpr;
struct ZigClangIncompleteArrayType;
struct ZigClangIntegerLiteral;
struct ZigClangMacroDefinitionRecord;
struct ZigClangMemberExpr;
struct ZigClangNamedDecl;
struct ZigClangNone;
struct ZigClangPCHContainerOperations;
struct ZigClangParenExpr;
struct ZigClangParenType;
struct ZigClangParmVarDecl;
struct ZigClangPointerType;
struct ZigClangPreprocessedEntity;
struct ZigClangRecordDecl;
struct ZigClangRecordType;
struct ZigClangReturnStmt;
struct ZigClangSkipFunctionBodiesScope;
struct ZigClangSourceManager;
struct ZigClangSourceRange;
struct ZigClangStmt;
struct ZigClangStorageClass;
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
    ZigClangType_Builtin,
    ZigClangType_Complex,
    ZigClangType_Pointer,
    ZigClangType_BlockPointer,
    ZigClangType_LValueReference,
    ZigClangType_RValueReference,
    ZigClangType_MemberPointer,
    ZigClangType_ConstantArray,
    ZigClangType_IncompleteArray,
    ZigClangType_VariableArray,
    ZigClangType_DependentSizedArray,
    ZigClangType_DependentSizedExtVector,
    ZigClangType_DependentAddressSpace,
    ZigClangType_Vector,
    ZigClangType_DependentVector,
    ZigClangType_ExtVector,
    ZigClangType_FunctionProto,
    ZigClangType_FunctionNoProto,
    ZigClangType_UnresolvedUsing,
    ZigClangType_Paren,
    ZigClangType_Typedef,
    ZigClangType_Adjusted,
    ZigClangType_Decayed,
    ZigClangType_TypeOfExpr,
    ZigClangType_TypeOf,
    ZigClangType_Decltype,
    ZigClangType_UnaryTransform,
    ZigClangType_Record,
    ZigClangType_Enum,
    ZigClangType_Elaborated,
    ZigClangType_Attributed,
    ZigClangType_TemplateTypeParm,
    ZigClangType_SubstTemplateTypeParm,
    ZigClangType_SubstTemplateTypeParmPack,
    ZigClangType_TemplateSpecialization,
    ZigClangType_Auto,
    ZigClangType_DeducedTemplateSpecialization,
    ZigClangType_InjectedClassName,
    ZigClangType_DependentName,
    ZigClangType_DependentTemplateSpecialization,
    ZigClangType_PackExpansion,
    ZigClangType_ObjCTypeParam,
    ZigClangType_ObjCObject,
    ZigClangType_ObjCInterface,
    ZigClangType_ObjCObjectPointer,
    ZigClangType_Pipe,
    ZigClangType_Atomic,
};

enum ZigClangStmtClass {
    ZigClangStmt_NoStmtClass = 0,
    ZigClangStmt_GCCAsmStmtClass,
    ZigClangStmt_MSAsmStmtClass,
    ZigClangStmt_AttributedStmtClass,
    ZigClangStmt_BreakStmtClass,
    ZigClangStmt_CXXCatchStmtClass,
    ZigClangStmt_CXXForRangeStmtClass,
    ZigClangStmt_CXXTryStmtClass,
    ZigClangStmt_CapturedStmtClass,
    ZigClangStmt_CompoundStmtClass,
    ZigClangStmt_ContinueStmtClass,
    ZigClangStmt_CoreturnStmtClass,
    ZigClangStmt_CoroutineBodyStmtClass,
    ZigClangStmt_DeclStmtClass,
    ZigClangStmt_DoStmtClass,
    ZigClangStmt_BinaryConditionalOperatorClass,
    ZigClangStmt_ConditionalOperatorClass,
    ZigClangStmt_AddrLabelExprClass,
    ZigClangStmt_ArrayInitIndexExprClass,
    ZigClangStmt_ArrayInitLoopExprClass,
    ZigClangStmt_ArraySubscriptExprClass,
    ZigClangStmt_ArrayTypeTraitExprClass,
    ZigClangStmt_AsTypeExprClass,
    ZigClangStmt_AtomicExprClass,
    ZigClangStmt_BinaryOperatorClass,
    ZigClangStmt_CompoundAssignOperatorClass,
    ZigClangStmt_BlockExprClass,
    ZigClangStmt_CXXBindTemporaryExprClass,
    ZigClangStmt_CXXBoolLiteralExprClass,
    ZigClangStmt_CXXConstructExprClass,
    ZigClangStmt_CXXTemporaryObjectExprClass,
    ZigClangStmt_CXXDefaultArgExprClass,
    ZigClangStmt_CXXDefaultInitExprClass,
    ZigClangStmt_CXXDeleteExprClass,
    ZigClangStmt_CXXDependentScopeMemberExprClass,
    ZigClangStmt_CXXFoldExprClass,
    ZigClangStmt_CXXInheritedCtorInitExprClass,
    ZigClangStmt_CXXNewExprClass,
    ZigClangStmt_CXXNoexceptExprClass,
    ZigClangStmt_CXXNullPtrLiteralExprClass,
    ZigClangStmt_CXXPseudoDestructorExprClass,
    ZigClangStmt_CXXScalarValueInitExprClass,
    ZigClangStmt_CXXStdInitializerListExprClass,
    ZigClangStmt_CXXThisExprClass,
    ZigClangStmt_CXXThrowExprClass,
    ZigClangStmt_CXXTypeidExprClass,
    ZigClangStmt_CXXUnresolvedConstructExprClass,
    ZigClangStmt_CXXUuidofExprClass,
    ZigClangStmt_CallExprClass,
    ZigClangStmt_CUDAKernelCallExprClass,
    ZigClangStmt_CXXMemberCallExprClass,
    ZigClangStmt_CXXOperatorCallExprClass,
    ZigClangStmt_UserDefinedLiteralClass,
    ZigClangStmt_CStyleCastExprClass,
    ZigClangStmt_CXXFunctionalCastExprClass,
    ZigClangStmt_CXXConstCastExprClass,
    ZigClangStmt_CXXDynamicCastExprClass,
    ZigClangStmt_CXXReinterpretCastExprClass,
    ZigClangStmt_CXXStaticCastExprClass,
    ZigClangStmt_ObjCBridgedCastExprClass,
    ZigClangStmt_ImplicitCastExprClass,
    ZigClangStmt_CharacterLiteralClass,
    ZigClangStmt_ChooseExprClass,
    ZigClangStmt_CompoundLiteralExprClass,
    ZigClangStmt_ConvertVectorExprClass,
    ZigClangStmt_CoawaitExprClass,
    ZigClangStmt_CoyieldExprClass,
    ZigClangStmt_DeclRefExprClass,
    ZigClangStmt_DependentCoawaitExprClass,
    ZigClangStmt_DependentScopeDeclRefExprClass,
    ZigClangStmt_DesignatedInitExprClass,
    ZigClangStmt_DesignatedInitUpdateExprClass,
    ZigClangStmt_ExpressionTraitExprClass,
    ZigClangStmt_ExtVectorElementExprClass,
    ZigClangStmt_FixedPointLiteralClass,
    ZigClangStmt_FloatingLiteralClass,
    ZigClangStmt_ConstantExprClass,
    ZigClangStmt_ExprWithCleanupsClass,
    ZigClangStmt_FunctionParmPackExprClass,
    ZigClangStmt_GNUNullExprClass,
    ZigClangStmt_GenericSelectionExprClass,
    ZigClangStmt_ImaginaryLiteralClass,
    ZigClangStmt_ImplicitValueInitExprClass,
    ZigClangStmt_InitListExprClass,
    ZigClangStmt_IntegerLiteralClass,
    ZigClangStmt_LambdaExprClass,
    ZigClangStmt_MSPropertyRefExprClass,
    ZigClangStmt_MSPropertySubscriptExprClass,
    ZigClangStmt_MaterializeTemporaryExprClass,
    ZigClangStmt_MemberExprClass,
    ZigClangStmt_NoInitExprClass,
    ZigClangStmt_OMPArraySectionExprClass,
    ZigClangStmt_ObjCArrayLiteralClass,
    ZigClangStmt_ObjCAvailabilityCheckExprClass,
    ZigClangStmt_ObjCBoolLiteralExprClass,
    ZigClangStmt_ObjCBoxedExprClass,
    ZigClangStmt_ObjCDictionaryLiteralClass,
    ZigClangStmt_ObjCEncodeExprClass,
    ZigClangStmt_ObjCIndirectCopyRestoreExprClass,
    ZigClangStmt_ObjCIsaExprClass,
    ZigClangStmt_ObjCIvarRefExprClass,
    ZigClangStmt_ObjCMessageExprClass,
    ZigClangStmt_ObjCPropertyRefExprClass,
    ZigClangStmt_ObjCProtocolExprClass,
    ZigClangStmt_ObjCSelectorExprClass,
    ZigClangStmt_ObjCStringLiteralClass,
    ZigClangStmt_ObjCSubscriptRefExprClass,
    ZigClangStmt_OffsetOfExprClass,
    ZigClangStmt_OpaqueValueExprClass,
    ZigClangStmt_UnresolvedLookupExprClass,
    ZigClangStmt_UnresolvedMemberExprClass,
    ZigClangStmt_PackExpansionExprClass,
    ZigClangStmt_ParenExprClass,
    ZigClangStmt_ParenListExprClass,
    ZigClangStmt_PredefinedExprClass,
    ZigClangStmt_PseudoObjectExprClass,
    ZigClangStmt_ShuffleVectorExprClass,
    ZigClangStmt_SizeOfPackExprClass,
    ZigClangStmt_StmtExprClass,
    ZigClangStmt_StringLiteralClass,
    ZigClangStmt_SubstNonTypeTemplateParmExprClass,
    ZigClangStmt_SubstNonTypeTemplateParmPackExprClass,
    ZigClangStmt_TypeTraitExprClass,
    ZigClangStmt_TypoExprClass,
    ZigClangStmt_UnaryExprOrTypeTraitExprClass,
    ZigClangStmt_UnaryOperatorClass,
    ZigClangStmt_VAArgExprClass,
    ZigClangStmt_ForStmtClass,
    ZigClangStmt_GotoStmtClass,
    ZigClangStmt_IfStmtClass,
    ZigClangStmt_IndirectGotoStmtClass,
    ZigClangStmt_LabelStmtClass,
    ZigClangStmt_MSDependentExistsStmtClass,
    ZigClangStmt_NullStmtClass,
    ZigClangStmt_OMPAtomicDirectiveClass,
    ZigClangStmt_OMPBarrierDirectiveClass,
    ZigClangStmt_OMPCancelDirectiveClass,
    ZigClangStmt_OMPCancellationPointDirectiveClass,
    ZigClangStmt_OMPCriticalDirectiveClass,
    ZigClangStmt_OMPFlushDirectiveClass,
    ZigClangStmt_OMPDistributeDirectiveClass,
    ZigClangStmt_OMPDistributeParallelForDirectiveClass,
    ZigClangStmt_OMPDistributeParallelForSimdDirectiveClass,
    ZigClangStmt_OMPDistributeSimdDirectiveClass,
    ZigClangStmt_OMPForDirectiveClass,
    ZigClangStmt_OMPForSimdDirectiveClass,
    ZigClangStmt_OMPParallelForDirectiveClass,
    ZigClangStmt_OMPParallelForSimdDirectiveClass,
    ZigClangStmt_OMPSimdDirectiveClass,
    ZigClangStmt_OMPTargetParallelForSimdDirectiveClass,
    ZigClangStmt_OMPTargetSimdDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeParallelForDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeParallelForSimdDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDistributeSimdDirectiveClass,
    ZigClangStmt_OMPTaskLoopDirectiveClass,
    ZigClangStmt_OMPTaskLoopSimdDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeParallelForDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeParallelForSimdDirectiveClass,
    ZigClangStmt_OMPTeamsDistributeSimdDirectiveClass,
    ZigClangStmt_OMPMasterDirectiveClass,
    ZigClangStmt_OMPOrderedDirectiveClass,
    ZigClangStmt_OMPParallelDirectiveClass,
    ZigClangStmt_OMPParallelSectionsDirectiveClass,
    ZigClangStmt_OMPSectionDirectiveClass,
    ZigClangStmt_OMPSectionsDirectiveClass,
    ZigClangStmt_OMPSingleDirectiveClass,
    ZigClangStmt_OMPTargetDataDirectiveClass,
    ZigClangStmt_OMPTargetDirectiveClass,
    ZigClangStmt_OMPTargetEnterDataDirectiveClass,
    ZigClangStmt_OMPTargetExitDataDirectiveClass,
    ZigClangStmt_OMPTargetParallelDirectiveClass,
    ZigClangStmt_OMPTargetParallelForDirectiveClass,
    ZigClangStmt_OMPTargetTeamsDirectiveClass,
    ZigClangStmt_OMPTargetUpdateDirectiveClass,
    ZigClangStmt_OMPTaskDirectiveClass,
    ZigClangStmt_OMPTaskgroupDirectiveClass,
    ZigClangStmt_OMPTaskwaitDirectiveClass,
    ZigClangStmt_OMPTaskyieldDirectiveClass,
    ZigClangStmt_OMPTeamsDirectiveClass,
    ZigClangStmt_ObjCAtCatchStmtClass,
    ZigClangStmt_ObjCAtFinallyStmtClass,
    ZigClangStmt_ObjCAtSynchronizedStmtClass,
    ZigClangStmt_ObjCAtThrowStmtClass,
    ZigClangStmt_ObjCAtTryStmtClass,
    ZigClangStmt_ObjCAutoreleasePoolStmtClass,
    ZigClangStmt_ObjCForCollectionStmtClass,
    ZigClangStmt_ReturnStmtClass,
    ZigClangStmt_SEHExceptStmtClass,
    ZigClangStmt_SEHFinallyStmtClass,
    ZigClangStmt_SEHLeaveStmtClass,
    ZigClangStmt_SEHTryStmtClass,
    ZigClangStmt_CaseStmtClass,
    ZigClangStmt_DefaultStmtClass,
    ZigClangStmt_SwitchStmtClass,
    ZigClangStmt_WhileStmtClass,
};

enum ZigClangCK {
    ZigClangCK_Dependent,
    ZigClangCK_BitCast,
    ZigClangCK_LValueBitCast,
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
    ZigClangCK_VectorSplat,
    ZigClangCK_IntegralCast,
    ZigClangCK_IntegralToBoolean,
    ZigClangCK_IntegralToFloating,
    ZigClangCK_FixedPointCast,
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

enum ZigClangAPValueKind {
    ZigClangAPValueUninitialized,
    ZigClangAPValueInt,
    ZigClangAPValueFloat,
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

ZIG_EXTERN_C struct ZigClangASTContext *ZigClangASTUnit_getASTContext(struct ZigClangASTUnit *);
ZIG_EXTERN_C struct ZigClangSourceManager *ZigClangASTUnit_getSourceManager(struct ZigClangASTUnit *);
ZIG_EXTERN_C bool ZigClangASTUnit_visitLocalTopLevelDecls(struct ZigClangASTUnit *, void *context, 
    bool (*Fn)(void *context, const struct ZigClangDecl *decl));

ZIG_EXTERN_C const struct ZigClangRecordDecl *ZigClangRecordType_getDecl(const struct ZigClangRecordType *record_ty);
ZIG_EXTERN_C const struct ZigClangEnumDecl *ZigClangEnumType_getDecl(const struct ZigClangEnumType *record_ty);

ZIG_EXTERN_C const struct ZigClangTagDecl *ZigClangRecordDecl_getCanonicalDecl(const struct ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C const struct ZigClangTagDecl *ZigClangEnumDecl_getCanonicalDecl(const struct ZigClangEnumDecl *);
ZIG_EXTERN_C const struct ZigClangTypedefNameDecl *ZigClangTypedefNameDecl_getCanonicalDecl(const struct ZigClangTypedefNameDecl *);

ZIG_EXTERN_C const struct ZigClangRecordDecl *ZigClangRecordDecl_getDefinition(const struct ZigClangRecordDecl *);
ZIG_EXTERN_C const struct ZigClangEnumDecl *ZigClangEnumDecl_getDefinition(const struct ZigClangEnumDecl *);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangRecordDecl_getLocation(const struct ZigClangRecordDecl *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangEnumDecl_getLocation(const struct ZigClangEnumDecl *);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangTypedefNameDecl_getLocation(const struct ZigClangTypedefNameDecl *);

ZIG_EXTERN_C bool ZigClangRecordDecl_isUnion(const struct ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C bool ZigClangRecordDecl_isStruct(const struct ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C bool ZigClangRecordDecl_isAnonymousStructOrUnion(const struct ZigClangRecordDecl *record_decl);

ZIG_EXTERN_C struct ZigClangQualType ZigClangEnumDecl_getIntegerType(const struct ZigClangEnumDecl *);

ZIG_EXTERN_C const char *ZigClangDecl_getName_bytes_begin(const struct ZigClangDecl *decl);

ZIG_EXTERN_C bool ZigClangSourceLocation_eq(struct ZigClangSourceLocation a, struct ZigClangSourceLocation b);

ZIG_EXTERN_C const struct ZigClangTypedefNameDecl *ZigClangTypedefType_getDecl(const struct ZigClangTypedefType *);
ZIG_EXTERN_C struct ZigClangQualType ZigClangTypedefNameDecl_getUnderlyingType(const struct ZigClangTypedefNameDecl *);

ZIG_EXTERN_C struct ZigClangQualType ZigClangQualType_getCanonicalType(struct ZigClangQualType);
ZIG_EXTERN_C const struct ZigClangType *ZigClangQualType_getTypePtr(struct ZigClangQualType);
ZIG_EXTERN_C void ZigClangQualType_addConst(struct ZigClangQualType *);
ZIG_EXTERN_C bool ZigClangQualType_eq(struct ZigClangQualType, struct ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isConstQualified(struct ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isVolatileQualified(struct ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isRestrictQualified(struct ZigClangQualType);

ZIG_EXTERN_C enum ZigClangTypeClass ZigClangType_getTypeClass(const struct ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isVoidType(const struct ZigClangType *self);
ZIG_EXTERN_C const char *ZigClangType_getTypeClassName(const struct ZigClangType *self);

ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangStmt_getBeginLoc(const struct ZigClangStmt *self);
ZIG_EXTERN_C enum ZigClangStmtClass ZigClangStmt_getStmtClass(const struct ZigClangStmt *self);
ZIG_EXTERN_C bool ZigClangStmt_classof_Expr(const struct ZigClangStmt *self);

ZIG_EXTERN_C enum ZigClangStmtClass ZigClangExpr_getStmtClass(const struct ZigClangExpr *self);
ZIG_EXTERN_C struct ZigClangQualType ZigClangExpr_getType(const struct ZigClangExpr *self);
ZIG_EXTERN_C struct ZigClangSourceLocation ZigClangExpr_getBeginLoc(const struct ZigClangExpr *self);

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

ZIG_EXTERN_C const struct ZigClangExpr *ZigClangAPValueLValueBase_dyn_cast_Expr(struct ZigClangAPValueLValueBase self);

#endif
