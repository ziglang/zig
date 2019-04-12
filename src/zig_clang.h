/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ZIG_CLANG_H
#define ZIG_ZIG_CLANG_H

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

// ATTENTION: If you modify this file, be sure to update the corresponding
// extern function declarations in the self-hosted compiler.
// Note: not yet, we don't have the corresponding clang.zig yet.

struct ZigClangSourceLocation {
    unsigned ID;
};

struct ZigClangQualType {
    void *ptr;
};

struct ZigClangAPValue;
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

//struct ZigClangCC_AAPCS;
//struct ZigClangCC_AAPCS_VFP;
//struct ZigClangCC_C;
//struct ZigClangCC_IntelOclBicc;
//struct ZigClangCC_OpenCLKernel;
//struct ZigClangCC_PreserveAll;
//struct ZigClangCC_PreserveMost;
//struct ZigClangCC_SpirFunction;
//struct ZigClangCC_Swift;
//struct ZigClangCC_Win64;
//struct ZigClangCC_X86FastCall;
//struct ZigClangCC_X86Pascal;
//struct ZigClangCC_X86RegCall;
//struct ZigClangCC_X86StdCall;
//struct ZigClangCC_X86ThisCall;
//struct ZigClangCC_X86VectorCall;
//struct ZigClangCC_X86_64SysV;

//struct ZigClangCK_ARCConsumeObject;
//struct ZigClangCK_ARCExtendBlockObject;
//struct ZigClangCK_ARCProduceObject;
//struct ZigClangCK_ARCReclaimReturnedObject;
//struct ZigClangCK_AddressSpaceConversion;
//struct ZigClangCK_AnyPointerToBlockPointerCast;
//struct ZigClangCK_ArrayToPointerDecay;
//struct ZigClangCK_AtomicToNonAtomic;
//struct ZigClangCK_BaseToDerived;
//struct ZigClangCK_BaseToDerivedMemberPointer;
//struct ZigClangCK_BitCast;
//struct ZigClangCK_BlockPointerToObjCPointerCast;
//struct ZigClangCK_BooleanToSignedIntegral;
//struct ZigClangCK_BuiltinFnToFnPtr;
//struct ZigClangCK_CPointerToObjCPointerCast;
//struct ZigClangCK_ConstructorConversion;
//struct ZigClangCK_CopyAndAutoreleaseBlockObject;
//struct ZigClangCK_Dependent;
//struct ZigClangCK_DerivedToBase;
//struct ZigClangCK_DerivedToBaseMemberPointer;
//struct ZigClangCK_Dynamic;
//struct ZigClangCK_FloatingCast;
//struct ZigClangCK_FloatingComplexCast;
//struct ZigClangCK_FloatingComplexToBoolean;
//struct ZigClangCK_FloatingComplexToIntegralComplex;
//struct ZigClangCK_FloatingComplexToReal;
//struct ZigClangCK_FloatingRealToComplex;
//struct ZigClangCK_FloatingToBoolean;
//struct ZigClangCK_FloatingToIntegral;
//struct ZigClangCK_FunctionToPointerDecay;
//struct ZigClangCK_IntToOCLSampler;
//struct ZigClangCK_IntegralCast;
//struct ZigClangCK_IntegralComplexCast;
//struct ZigClangCK_IntegralComplexToBoolean;
//struct ZigClangCK_IntegralComplexToFloatingComplex;
//struct ZigClangCK_IntegralComplexToReal;
//struct ZigClangCK_IntegralRealToComplex;
//struct ZigClangCK_IntegralToBoolean;
//struct ZigClangCK_IntegralToFloating;
//struct ZigClangCK_IntegralToPointer;
//struct ZigClangCK_LValueBitCast;
//struct ZigClangCK_LValueToRValue;
//struct ZigClangCK_MemberPointerToBoolean;
//struct ZigClangCK_NoOp;
//struct ZigClangCK_NonAtomicToAtomic;
//struct ZigClangCK_NullToMemberPointer;
//struct ZigClangCK_NullToPointer;
//struct ZigClangCK_ObjCObjectLValueCast;
//struct ZigClangCK_PointerToBoolean;
//struct ZigClangCK_PointerToIntegral;
//struct ZigClangCK_ReinterpretMemberPointer;
//struct ZigClangCK_ToUnion;
//struct ZigClangCK_ToVoid;
//struct ZigClangCK_UncheckedDerivedToBase;
//struct ZigClangCK_UserDefinedConversion;
//struct ZigClangCK_VectorSplat;
//struct ZigClangCK_ZeroToOCLEvent;
//struct ZigClangCK_ZeroToOCLQueue;

//struct ZigClangETK_Class;
//struct ZigClangETK_Enum;
//struct ZigClangETK_Interface;
//struct ZigClangETK_None;
//struct ZigClangETK_Struct;
//struct ZigClangETK_Typename;
//struct ZigClangETK_Union;

//struct ZigClangSC_None;
//struct ZigClangSC_PrivateExtern;
//struct ZigClangSC_Static;

//struct ZigClangTU_Complete;

ZIG_EXTERN_C ZigClangSourceLocation ZigClangSourceManager_getSpellingLoc(const ZigClangSourceManager *,
        ZigClangSourceLocation Loc);
ZIG_EXTERN_C const char *ZigClangSourceManager_getFilename(const ZigClangSourceManager *,
        ZigClangSourceLocation SpellingLoc);
ZIG_EXTERN_C unsigned ZigClangSourceManager_getSpellingLineNumber(const ZigClangSourceManager *,
        ZigClangSourceLocation Loc);
ZIG_EXTERN_C unsigned ZigClangSourceManager_getSpellingColumnNumber(const ZigClangSourceManager *,
        ZigClangSourceLocation Loc);
ZIG_EXTERN_C const char* ZigClangSourceManager_getCharacterData(const ZigClangSourceManager *,
        ZigClangSourceLocation SL);

ZIG_EXTERN_C ZigClangQualType ZigClangASTContext_getPointerType(const ZigClangASTContext*, ZigClangQualType T);

ZIG_EXTERN_C ZigClangASTContext *ZigClangASTUnit_getASTContext(ZigClangASTUnit *);
ZIG_EXTERN_C ZigClangSourceManager *ZigClangASTUnit_getSourceManager(ZigClangASTUnit *);
ZIG_EXTERN_C bool ZigClangASTUnit_visitLocalTopLevelDecls(ZigClangASTUnit *, void *context, 
    bool (*Fn)(void *context, const ZigClangDecl *decl));

ZIG_EXTERN_C const ZigClangRecordDecl *ZigClangRecordType_getDecl(const ZigClangRecordType *record_ty);
ZIG_EXTERN_C const ZigClangEnumDecl *ZigClangEnumType_getDecl(const ZigClangEnumType *record_ty);

ZIG_EXTERN_C const ZigClangTagDecl *ZigClangRecordDecl_getCanonicalDecl(const ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C const ZigClangTagDecl *ZigClangEnumDecl_getCanonicalDecl(const ZigClangEnumDecl *);
ZIG_EXTERN_C const ZigClangTypedefNameDecl *ZigClangTypedefNameDecl_getCanonicalDecl(const ZigClangTypedefNameDecl *);

ZIG_EXTERN_C const ZigClangRecordDecl *ZigClangRecordDecl_getDefinition(const ZigClangRecordDecl *);
ZIG_EXTERN_C const ZigClangEnumDecl *ZigClangEnumDecl_getDefinition(const ZigClangEnumDecl *);

ZIG_EXTERN_C ZigClangSourceLocation ZigClangRecordDecl_getLocation(const ZigClangRecordDecl *);
ZIG_EXTERN_C ZigClangSourceLocation ZigClangEnumDecl_getLocation(const ZigClangEnumDecl *);
ZIG_EXTERN_C ZigClangSourceLocation ZigClangTypedefNameDecl_getLocation(const ZigClangTypedefNameDecl *);

ZIG_EXTERN_C bool ZigClangRecordDecl_isUnion(const ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C bool ZigClangRecordDecl_isStruct(const ZigClangRecordDecl *record_decl);
ZIG_EXTERN_C bool ZigClangRecordDecl_isAnonymousStructOrUnion(const ZigClangRecordDecl *record_decl);

ZIG_EXTERN_C ZigClangQualType ZigClangEnumDecl_getIntegerType(const ZigClangEnumDecl *);

ZIG_EXTERN_C const char *ZigClangDecl_getName_bytes_begin(const ZigClangDecl *decl);

ZIG_EXTERN_C bool ZigClangSourceLocation_eq(ZigClangSourceLocation a, ZigClangSourceLocation b);

ZIG_EXTERN_C const ZigClangTypedefNameDecl *ZigClangTypedefType_getDecl(const ZigClangTypedefType *);
ZIG_EXTERN_C ZigClangQualType ZigClangTypedefNameDecl_getUnderlyingType(const ZigClangTypedefNameDecl *);

ZIG_EXTERN_C ZigClangQualType ZigClangQualType_getCanonicalType(ZigClangQualType);
ZIG_EXTERN_C const ZigClangType *ZigClangQualType_getTypePtr(ZigClangQualType);
ZIG_EXTERN_C void ZigClangQualType_addConst(ZigClangQualType *);
ZIG_EXTERN_C bool ZigClangQualType_eq(ZigClangQualType, ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isConstQualified(ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isVolatileQualified(ZigClangQualType);
ZIG_EXTERN_C bool ZigClangQualType_isRestrictQualified(ZigClangQualType);

ZIG_EXTERN_C ZigClangTypeClass ZigClangType_getTypeClass(const ZigClangType *self);
ZIG_EXTERN_C bool ZigClangType_isVoidType(const ZigClangType *self);
ZIG_EXTERN_C const char *ZigClangType_getTypeClassName(const ZigClangType *self);
#endif
