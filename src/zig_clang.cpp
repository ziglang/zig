/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


/*
 * The point of this file is to contain all the Clang C++ API interaction so that:
 * 1. The compile time of other files is kept under control.
 * 2. Provide a C interface to the Clang functions we need for self-hosting purposes.
 * 3. Prevent C++ from infecting the rest of the project.
 */
#include "zig_clang.h"

#if __GNUC__ >= 8
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wclass-memaccess"
#endif

#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/AST/Expr.h>

#if __GNUC__ >= 8
#pragma GCC diagnostic pop
#endif

// Detect additions to the enum
void zig2clang_BO(clang::BinaryOperatorKind op) {
    switch (op) {
        case clang::BO_PtrMemD:
        case clang::BO_PtrMemI:
        case clang::BO_Cmp:
        case clang::BO_Mul:
        case clang::BO_Div:
        case clang::BO_Rem:
        case clang::BO_Add:
        case clang::BO_Sub:
        case clang::BO_Shl:
        case clang::BO_Shr:
        case clang::BO_LT:
        case clang::BO_GT:
        case clang::BO_LE:
        case clang::BO_GE:
        case clang::BO_EQ:
        case clang::BO_NE:
        case clang::BO_And:
        case clang::BO_Xor:
        case clang::BO_Or:
        case clang::BO_LAnd:
        case clang::BO_LOr:
        case clang::BO_Assign:
        case clang::BO_Comma:
        case clang::BO_MulAssign:
        case clang::BO_DivAssign:
        case clang::BO_RemAssign:
        case clang::BO_AddAssign:
        case clang::BO_SubAssign:
        case clang::BO_ShlAssign:
        case clang::BO_ShrAssign:
        case clang::BO_AndAssign:
        case clang::BO_XorAssign:
        case clang::BO_OrAssign:
            break;
    }
}

static_assert((clang::BinaryOperatorKind)ZigClangBO_Add == clang::BO_Add, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_AddAssign == clang::BO_AddAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_And == clang::BO_And, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_AndAssign == clang::BO_AndAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Assign == clang::BO_Assign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Cmp == clang::BO_Cmp, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Comma == clang::BO_Comma, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Div == clang::BO_Div, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_DivAssign == clang::BO_DivAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_EQ == clang::BO_EQ, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_GE == clang::BO_GE, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_GT == clang::BO_GT, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_LAnd == clang::BO_LAnd, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_LE == clang::BO_LE, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_LOr == clang::BO_LOr, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_LT == clang::BO_LT, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Mul == clang::BO_Mul, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_MulAssign == clang::BO_MulAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_NE == clang::BO_NE, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Or == clang::BO_Or, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_OrAssign == clang::BO_OrAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_PtrMemD == clang::BO_PtrMemD, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_PtrMemI == clang::BO_PtrMemI, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Rem == clang::BO_Rem, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_RemAssign == clang::BO_RemAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Shl == clang::BO_Shl, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_ShlAssign == clang::BO_ShlAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Shr == clang::BO_Shr, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_ShrAssign == clang::BO_ShrAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Sub == clang::BO_Sub, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_SubAssign == clang::BO_SubAssign, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_Xor == clang::BO_Xor, "");
static_assert((clang::BinaryOperatorKind)ZigClangBO_XorAssign == clang::BO_XorAssign, "");

// Detect additions to the enum
void zig2clang_UO(clang::UnaryOperatorKind op) {
    switch (op) {
        case clang::UO_AddrOf:
        case clang::UO_Coawait:
        case clang::UO_Deref:
        case clang::UO_Extension:
        case clang::UO_Imag:
        case clang::UO_LNot:
        case clang::UO_Minus:
        case clang::UO_Not:
        case clang::UO_Plus:
        case clang::UO_PostDec:
        case clang::UO_PostInc:
        case clang::UO_PreDec:
        case clang::UO_PreInc:
        case clang::UO_Real:
            break;
    }
}

static_assert((clang::UnaryOperatorKind)ZigClangUO_AddrOf == clang::UO_AddrOf, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Coawait == clang::UO_Coawait, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Deref == clang::UO_Deref, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Extension == clang::UO_Extension, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Imag == clang::UO_Imag, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_LNot == clang::UO_LNot, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Minus == clang::UO_Minus, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Not == clang::UO_Not, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Plus == clang::UO_Plus, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_PostDec == clang::UO_PostDec, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_PostInc == clang::UO_PostInc, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_PreDec == clang::UO_PreDec, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_PreInc == clang::UO_PreInc, "");
static_assert((clang::UnaryOperatorKind)ZigClangUO_Real == clang::UO_Real, "");

// Detect additions to the enum
void zig2clang_TypeClass(clang::Type::TypeClass ty) {
    switch (ty) {
        case clang::Type::Builtin:
        case clang::Type::Complex:
        case clang::Type::Pointer:
        case clang::Type::BlockPointer:
        case clang::Type::LValueReference:
        case clang::Type::RValueReference:
        case clang::Type::MemberPointer:
        case clang::Type::ConstantArray:
        case clang::Type::IncompleteArray:
        case clang::Type::VariableArray:
        case clang::Type::DependentSizedArray:
        case clang::Type::DependentSizedExtVector:
        case clang::Type::DependentAddressSpace:
        case clang::Type::Vector:
        case clang::Type::DependentVector:
        case clang::Type::ExtVector:
        case clang::Type::FunctionProto:
        case clang::Type::FunctionNoProto:
        case clang::Type::UnresolvedUsing:
        case clang::Type::Paren:
        case clang::Type::Typedef:
        case clang::Type::Adjusted:
        case clang::Type::Decayed:
        case clang::Type::TypeOfExpr:
        case clang::Type::TypeOf:
        case clang::Type::Decltype:
        case clang::Type::UnaryTransform:
        case clang::Type::Record:
        case clang::Type::Enum:
        case clang::Type::Elaborated:
        case clang::Type::Attributed:
        case clang::Type::TemplateTypeParm:
        case clang::Type::SubstTemplateTypeParm:
        case clang::Type::SubstTemplateTypeParmPack:
        case clang::Type::TemplateSpecialization:
        case clang::Type::Auto:
        case clang::Type::DeducedTemplateSpecialization:
        case clang::Type::InjectedClassName:
        case clang::Type::DependentName:
        case clang::Type::DependentTemplateSpecialization:
        case clang::Type::PackExpansion:
        case clang::Type::ObjCTypeParam:
        case clang::Type::ObjCObject:
        case clang::Type::ObjCInterface:
        case clang::Type::ObjCObjectPointer:
        case clang::Type::Pipe:
        case clang::Type::Atomic:
            break;
    }
}

static_assert((clang::Type::TypeClass)ZigClangType_Builtin == clang::Type::Builtin, "");
static_assert((clang::Type::TypeClass)ZigClangType_Complex == clang::Type::Complex, "");
static_assert((clang::Type::TypeClass)ZigClangType_Pointer == clang::Type::Pointer, "");
static_assert((clang::Type::TypeClass)ZigClangType_BlockPointer == clang::Type::BlockPointer, "");
static_assert((clang::Type::TypeClass)ZigClangType_LValueReference == clang::Type::LValueReference, "");
static_assert((clang::Type::TypeClass)ZigClangType_RValueReference == clang::Type::RValueReference, "");
static_assert((clang::Type::TypeClass)ZigClangType_MemberPointer == clang::Type::MemberPointer, "");
static_assert((clang::Type::TypeClass)ZigClangType_ConstantArray == clang::Type::ConstantArray, "");
static_assert((clang::Type::TypeClass)ZigClangType_IncompleteArray == clang::Type::IncompleteArray, "");
static_assert((clang::Type::TypeClass)ZigClangType_VariableArray == clang::Type::VariableArray, "");
static_assert((clang::Type::TypeClass)ZigClangType_DependentSizedArray == clang::Type::DependentSizedArray, "");
static_assert((clang::Type::TypeClass)ZigClangType_DependentSizedExtVector == clang::Type::DependentSizedExtVector, "");
static_assert((clang::Type::TypeClass)ZigClangType_DependentAddressSpace == clang::Type::DependentAddressSpace, "");
static_assert((clang::Type::TypeClass)ZigClangType_Vector == clang::Type::Vector, "");
static_assert((clang::Type::TypeClass)ZigClangType_DependentVector == clang::Type::DependentVector, "");
static_assert((clang::Type::TypeClass)ZigClangType_ExtVector == clang::Type::ExtVector, "");
static_assert((clang::Type::TypeClass)ZigClangType_FunctionProto == clang::Type::FunctionProto, "");
static_assert((clang::Type::TypeClass)ZigClangType_FunctionNoProto == clang::Type::FunctionNoProto, "");
static_assert((clang::Type::TypeClass)ZigClangType_UnresolvedUsing == clang::Type::UnresolvedUsing, "");
static_assert((clang::Type::TypeClass)ZigClangType_Paren == clang::Type::Paren, "");
static_assert((clang::Type::TypeClass)ZigClangType_Typedef == clang::Type::Typedef, "");
static_assert((clang::Type::TypeClass)ZigClangType_Adjusted == clang::Type::Adjusted, "");
static_assert((clang::Type::TypeClass)ZigClangType_Decayed == clang::Type::Decayed, "");
static_assert((clang::Type::TypeClass)ZigClangType_TypeOfExpr == clang::Type::TypeOfExpr, "");
static_assert((clang::Type::TypeClass)ZigClangType_TypeOf == clang::Type::TypeOf, "");
static_assert((clang::Type::TypeClass)ZigClangType_Decltype == clang::Type::Decltype, "");
static_assert((clang::Type::TypeClass)ZigClangType_UnaryTransform == clang::Type::UnaryTransform, "");
static_assert((clang::Type::TypeClass)ZigClangType_Record == clang::Type::Record, "");
static_assert((clang::Type::TypeClass)ZigClangType_Enum == clang::Type::Enum, "");
static_assert((clang::Type::TypeClass)ZigClangType_Elaborated == clang::Type::Elaborated, "");
static_assert((clang::Type::TypeClass)ZigClangType_Attributed == clang::Type::Attributed, "");
static_assert((clang::Type::TypeClass)ZigClangType_TemplateTypeParm == clang::Type::TemplateTypeParm, "");
static_assert((clang::Type::TypeClass)ZigClangType_SubstTemplateTypeParm == clang::Type::SubstTemplateTypeParm, "");
static_assert((clang::Type::TypeClass)ZigClangType_SubstTemplateTypeParmPack == clang::Type::SubstTemplateTypeParmPack, "");
static_assert((clang::Type::TypeClass)ZigClangType_TemplateSpecialization == clang::Type::TemplateSpecialization, "");
static_assert((clang::Type::TypeClass)ZigClangType_Auto == clang::Type::Auto, "");
static_assert((clang::Type::TypeClass)ZigClangType_DeducedTemplateSpecialization == clang::Type::DeducedTemplateSpecialization, "");
static_assert((clang::Type::TypeClass)ZigClangType_InjectedClassName == clang::Type::InjectedClassName, "");
static_assert((clang::Type::TypeClass)ZigClangType_DependentName == clang::Type::DependentName, "");
static_assert((clang::Type::TypeClass)ZigClangType_DependentTemplateSpecialization == clang::Type::DependentTemplateSpecialization, "");
static_assert((clang::Type::TypeClass)ZigClangType_PackExpansion == clang::Type::PackExpansion, "");
static_assert((clang::Type::TypeClass)ZigClangType_ObjCTypeParam == clang::Type::ObjCTypeParam, "");
static_assert((clang::Type::TypeClass)ZigClangType_ObjCObject == clang::Type::ObjCObject, "");
static_assert((clang::Type::TypeClass)ZigClangType_ObjCInterface == clang::Type::ObjCInterface, "");
static_assert((clang::Type::TypeClass)ZigClangType_ObjCObjectPointer == clang::Type::ObjCObjectPointer, "");
static_assert((clang::Type::TypeClass)ZigClangType_Pipe == clang::Type::Pipe, "");
static_assert((clang::Type::TypeClass)ZigClangType_Atomic == clang::Type::Atomic, "");

// Detect additions to the enum
void zig2clang_StmtClass(clang::Stmt::StmtClass x) {
    switch (x) {
        case clang::Stmt::NoStmtClass:
        case clang::Stmt::NullStmtClass:
        case clang::Stmt::CompoundStmtClass:
        case clang::Stmt::LabelStmtClass:
        case clang::Stmt::AttributedStmtClass:
        case clang::Stmt::IfStmtClass:
        case clang::Stmt::SwitchStmtClass:
        case clang::Stmt::WhileStmtClass:
        case clang::Stmt::DoStmtClass:
        case clang::Stmt::ForStmtClass:
        case clang::Stmt::GotoStmtClass:
        case clang::Stmt::IndirectGotoStmtClass:
        case clang::Stmt::ContinueStmtClass:
        case clang::Stmt::BreakStmtClass:
        case clang::Stmt::ReturnStmtClass:
        case clang::Stmt::DeclStmtClass:
        case clang::Stmt::CaseStmtClass:
        case clang::Stmt::DefaultStmtClass:
        case clang::Stmt::CapturedStmtClass:
        case clang::Stmt::GCCAsmStmtClass:
        case clang::Stmt::MSAsmStmtClass:
        case clang::Stmt::ObjCAtTryStmtClass:
        case clang::Stmt::ObjCAtCatchStmtClass:
        case clang::Stmt::ObjCAtFinallyStmtClass:
        case clang::Stmt::ObjCAtThrowStmtClass:
        case clang::Stmt::ObjCAtSynchronizedStmtClass:
        case clang::Stmt::ObjCForCollectionStmtClass:
        case clang::Stmt::ObjCAutoreleasePoolStmtClass:
        case clang::Stmt::CXXCatchStmtClass:
        case clang::Stmt::CXXTryStmtClass:
        case clang::Stmt::CXXForRangeStmtClass:
        case clang::Stmt::CoroutineBodyStmtClass:
        case clang::Stmt::CoreturnStmtClass:
        case clang::Stmt::PredefinedExprClass:
        case clang::Stmt::DeclRefExprClass:
        case clang::Stmt::IntegerLiteralClass:
        case clang::Stmt::FixedPointLiteralClass:
        case clang::Stmt::FloatingLiteralClass:
        case clang::Stmt::ImaginaryLiteralClass:
        case clang::Stmt::StringLiteralClass:
        case clang::Stmt::CharacterLiteralClass:
        case clang::Stmt::ParenExprClass:
        case clang::Stmt::UnaryOperatorClass:
        case clang::Stmt::OffsetOfExprClass:
        case clang::Stmt::UnaryExprOrTypeTraitExprClass:
        case clang::Stmt::ArraySubscriptExprClass:
        case clang::Stmt::OMPArraySectionExprClass:
        case clang::Stmt::CallExprClass:
        case clang::Stmt::MemberExprClass:
        case clang::Stmt::BinaryOperatorClass:
        case clang::Stmt::CompoundAssignOperatorClass:
        case clang::Stmt::ConditionalOperatorClass:
        case clang::Stmt::BinaryConditionalOperatorClass:
        case clang::Stmt::ImplicitCastExprClass:
        case clang::Stmt::CStyleCastExprClass:
        case clang::Stmt::CompoundLiteralExprClass:
        case clang::Stmt::ExtVectorElementExprClass:
        case clang::Stmt::InitListExprClass:
        case clang::Stmt::DesignatedInitExprClass:
        case clang::Stmt::DesignatedInitUpdateExprClass:
        case clang::Stmt::ImplicitValueInitExprClass:
        case clang::Stmt::NoInitExprClass:
        case clang::Stmt::ArrayInitLoopExprClass:
        case clang::Stmt::ArrayInitIndexExprClass:
        case clang::Stmt::ParenListExprClass:
        case clang::Stmt::VAArgExprClass:
        case clang::Stmt::GenericSelectionExprClass:
        case clang::Stmt::PseudoObjectExprClass:
        case clang::Stmt::ConstantExprClass:
        case clang::Stmt::AtomicExprClass:
        case clang::Stmt::AddrLabelExprClass:
        case clang::Stmt::StmtExprClass:
        case clang::Stmt::ChooseExprClass:
        case clang::Stmt::GNUNullExprClass:
        case clang::Stmt::CXXOperatorCallExprClass:
        case clang::Stmt::CXXMemberCallExprClass:
        case clang::Stmt::CXXStaticCastExprClass:
        case clang::Stmt::CXXDynamicCastExprClass:
        case clang::Stmt::CXXReinterpretCastExprClass:
        case clang::Stmt::CXXConstCastExprClass:
        case clang::Stmt::CXXFunctionalCastExprClass:
        case clang::Stmt::CXXTypeidExprClass:
        case clang::Stmt::UserDefinedLiteralClass:
        case clang::Stmt::CXXBoolLiteralExprClass:
        case clang::Stmt::CXXNullPtrLiteralExprClass:
        case clang::Stmt::CXXThisExprClass:
        case clang::Stmt::CXXThrowExprClass:
        case clang::Stmt::CXXDefaultArgExprClass:
        case clang::Stmt::CXXDefaultInitExprClass:
        case clang::Stmt::CXXScalarValueInitExprClass:
        case clang::Stmt::CXXStdInitializerListExprClass:
        case clang::Stmt::CXXNewExprClass:
        case clang::Stmt::CXXDeleteExprClass:
        case clang::Stmt::CXXPseudoDestructorExprClass:
        case clang::Stmt::TypeTraitExprClass:
        case clang::Stmt::ArrayTypeTraitExprClass:
        case clang::Stmt::ExpressionTraitExprClass:
        case clang::Stmt::DependentScopeDeclRefExprClass:
        case clang::Stmt::CXXConstructExprClass:
        case clang::Stmt::CXXInheritedCtorInitExprClass:
        case clang::Stmt::CXXBindTemporaryExprClass:
        case clang::Stmt::ExprWithCleanupsClass:
        case clang::Stmt::CXXTemporaryObjectExprClass:
        case clang::Stmt::CXXUnresolvedConstructExprClass:
        case clang::Stmt::CXXDependentScopeMemberExprClass:
        case clang::Stmt::UnresolvedLookupExprClass:
        case clang::Stmt::UnresolvedMemberExprClass:
        case clang::Stmt::CXXNoexceptExprClass:
        case clang::Stmt::PackExpansionExprClass:
        case clang::Stmt::SizeOfPackExprClass:
        case clang::Stmt::SubstNonTypeTemplateParmExprClass:
        case clang::Stmt::SubstNonTypeTemplateParmPackExprClass:
        case clang::Stmt::FunctionParmPackExprClass:
        case clang::Stmt::MaterializeTemporaryExprClass:
        case clang::Stmt::LambdaExprClass:
        case clang::Stmt::CXXFoldExprClass:
        case clang::Stmt::CoawaitExprClass:
        case clang::Stmt::DependentCoawaitExprClass:
        case clang::Stmt::CoyieldExprClass:
        case clang::Stmt::ObjCStringLiteralClass:
        case clang::Stmt::ObjCBoxedExprClass:
        case clang::Stmt::ObjCArrayLiteralClass:
        case clang::Stmt::ObjCDictionaryLiteralClass:
        case clang::Stmt::ObjCEncodeExprClass:
        case clang::Stmt::ObjCMessageExprClass:
        case clang::Stmt::ObjCSelectorExprClass:
        case clang::Stmt::ObjCProtocolExprClass:
        case clang::Stmt::ObjCIvarRefExprClass:
        case clang::Stmt::ObjCPropertyRefExprClass:
        case clang::Stmt::ObjCIsaExprClass:
        case clang::Stmt::ObjCIndirectCopyRestoreExprClass:
        case clang::Stmt::ObjCBoolLiteralExprClass:
        case clang::Stmt::ObjCSubscriptRefExprClass:
        case clang::Stmt::ObjCAvailabilityCheckExprClass:
        case clang::Stmt::ObjCBridgedCastExprClass:
        case clang::Stmt::CUDAKernelCallExprClass:
        case clang::Stmt::ShuffleVectorExprClass:
        case clang::Stmt::ConvertVectorExprClass:
        case clang::Stmt::BlockExprClass:
        case clang::Stmt::OpaqueValueExprClass:
        case clang::Stmt::TypoExprClass:
        case clang::Stmt::MSPropertyRefExprClass:
        case clang::Stmt::MSPropertySubscriptExprClass:
        case clang::Stmt::CXXUuidofExprClass:
        case clang::Stmt::SEHTryStmtClass:
        case clang::Stmt::SEHExceptStmtClass:
        case clang::Stmt::SEHFinallyStmtClass:
        case clang::Stmt::SEHLeaveStmtClass:
        case clang::Stmt::MSDependentExistsStmtClass:
        case clang::Stmt::AsTypeExprClass:
        case clang::Stmt::OMPParallelDirectiveClass:
        case clang::Stmt::OMPSimdDirectiveClass:
        case clang::Stmt::OMPForDirectiveClass:
        case clang::Stmt::OMPForSimdDirectiveClass:
        case clang::Stmt::OMPSectionsDirectiveClass:
        case clang::Stmt::OMPSectionDirectiveClass:
        case clang::Stmt::OMPSingleDirectiveClass:
        case clang::Stmt::OMPMasterDirectiveClass:
        case clang::Stmt::OMPCriticalDirectiveClass:
        case clang::Stmt::OMPParallelForDirectiveClass:
        case clang::Stmt::OMPParallelForSimdDirectiveClass:
        case clang::Stmt::OMPParallelSectionsDirectiveClass:
        case clang::Stmt::OMPTaskDirectiveClass:
        case clang::Stmt::OMPTaskyieldDirectiveClass:
        case clang::Stmt::OMPBarrierDirectiveClass:
        case clang::Stmt::OMPTaskwaitDirectiveClass:
        case clang::Stmt::OMPTaskgroupDirectiveClass:
        case clang::Stmt::OMPFlushDirectiveClass:
        case clang::Stmt::OMPOrderedDirectiveClass:
        case clang::Stmt::OMPAtomicDirectiveClass:
        case clang::Stmt::OMPTargetDirectiveClass:
        case clang::Stmt::OMPTargetDataDirectiveClass:
        case clang::Stmt::OMPTargetEnterDataDirectiveClass:
        case clang::Stmt::OMPTargetExitDataDirectiveClass:
        case clang::Stmt::OMPTargetParallelDirectiveClass:
        case clang::Stmt::OMPTargetParallelForDirectiveClass:
        case clang::Stmt::OMPTargetUpdateDirectiveClass:
        case clang::Stmt::OMPTeamsDirectiveClass:
        case clang::Stmt::OMPCancellationPointDirectiveClass:
        case clang::Stmt::OMPCancelDirectiveClass:
        case clang::Stmt::OMPTaskLoopDirectiveClass:
        case clang::Stmt::OMPTaskLoopSimdDirectiveClass:
        case clang::Stmt::OMPDistributeDirectiveClass:
        case clang::Stmt::OMPDistributeParallelForDirectiveClass:
        case clang::Stmt::OMPDistributeParallelForSimdDirectiveClass:
        case clang::Stmt::OMPDistributeSimdDirectiveClass:
        case clang::Stmt::OMPTargetParallelForSimdDirectiveClass:
        case clang::Stmt::OMPTargetSimdDirectiveClass:
        case clang::Stmt::OMPTeamsDistributeDirectiveClass:
        case clang::Stmt::OMPTeamsDistributeSimdDirectiveClass:
        case clang::Stmt::OMPTeamsDistributeParallelForSimdDirectiveClass:
        case clang::Stmt::OMPTeamsDistributeParallelForDirectiveClass:
        case clang::Stmt::OMPTargetTeamsDirectiveClass:
        case clang::Stmt::OMPTargetTeamsDistributeDirectiveClass:
        case clang::Stmt::OMPTargetTeamsDistributeParallelForDirectiveClass:
        case clang::Stmt::OMPTargetTeamsDistributeParallelForSimdDirectiveClass:
        case clang::Stmt::OMPTargetTeamsDistributeSimdDirectiveClass:
            break;
    }
}

static_assert((clang::Stmt::StmtClass)ZigClangStmt_NoStmtClass == clang::Stmt::NoStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_NullStmtClass == clang::Stmt::NullStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CompoundStmtClass == clang::Stmt::CompoundStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_LabelStmtClass == clang::Stmt::LabelStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_AttributedStmtClass == clang::Stmt::AttributedStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_IfStmtClass == clang::Stmt::IfStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SwitchStmtClass == clang::Stmt::SwitchStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_WhileStmtClass == clang::Stmt::WhileStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DoStmtClass == clang::Stmt::DoStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ForStmtClass == clang::Stmt::ForStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_GotoStmtClass == clang::Stmt::GotoStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_IndirectGotoStmtClass == clang::Stmt::IndirectGotoStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ContinueStmtClass == clang::Stmt::ContinueStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_BreakStmtClass == clang::Stmt::BreakStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ReturnStmtClass == clang::Stmt::ReturnStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DeclStmtClass == clang::Stmt::DeclStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CaseStmtClass == clang::Stmt::CaseStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DefaultStmtClass == clang::Stmt::DefaultStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CapturedStmtClass == clang::Stmt::CapturedStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_GCCAsmStmtClass == clang::Stmt::GCCAsmStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_MSAsmStmtClass == clang::Stmt::MSAsmStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCAtTryStmtClass == clang::Stmt::ObjCAtTryStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCAtCatchStmtClass == clang::Stmt::ObjCAtCatchStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCAtFinallyStmtClass == clang::Stmt::ObjCAtFinallyStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCAtThrowStmtClass == clang::Stmt::ObjCAtThrowStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCAtSynchronizedStmtClass == clang::Stmt::ObjCAtSynchronizedStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCForCollectionStmtClass == clang::Stmt::ObjCForCollectionStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCAutoreleasePoolStmtClass == clang::Stmt::ObjCAutoreleasePoolStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXCatchStmtClass == clang::Stmt::CXXCatchStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXTryStmtClass == clang::Stmt::CXXTryStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXForRangeStmtClass == clang::Stmt::CXXForRangeStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CoroutineBodyStmtClass == clang::Stmt::CoroutineBodyStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CoreturnStmtClass == clang::Stmt::CoreturnStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_PredefinedExprClass == clang::Stmt::PredefinedExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DeclRefExprClass == clang::Stmt::DeclRefExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_IntegerLiteralClass == clang::Stmt::IntegerLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_FixedPointLiteralClass == clang::Stmt::FixedPointLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_FloatingLiteralClass == clang::Stmt::FloatingLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ImaginaryLiteralClass == clang::Stmt::ImaginaryLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_StringLiteralClass == clang::Stmt::StringLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CharacterLiteralClass == clang::Stmt::CharacterLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ParenExprClass == clang::Stmt::ParenExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_UnaryOperatorClass == clang::Stmt::UnaryOperatorClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OffsetOfExprClass == clang::Stmt::OffsetOfExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_UnaryExprOrTypeTraitExprClass == clang::Stmt::UnaryExprOrTypeTraitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ArraySubscriptExprClass == clang::Stmt::ArraySubscriptExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPArraySectionExprClass == clang::Stmt::OMPArraySectionExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CallExprClass == clang::Stmt::CallExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_MemberExprClass == clang::Stmt::MemberExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_BinaryOperatorClass == clang::Stmt::BinaryOperatorClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CompoundAssignOperatorClass == clang::Stmt::CompoundAssignOperatorClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ConditionalOperatorClass == clang::Stmt::ConditionalOperatorClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_BinaryConditionalOperatorClass == clang::Stmt::BinaryConditionalOperatorClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ImplicitCastExprClass == clang::Stmt::ImplicitCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CStyleCastExprClass == clang::Stmt::CStyleCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CompoundLiteralExprClass == clang::Stmt::CompoundLiteralExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ExtVectorElementExprClass == clang::Stmt::ExtVectorElementExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_InitListExprClass == clang::Stmt::InitListExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DesignatedInitExprClass == clang::Stmt::DesignatedInitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DesignatedInitUpdateExprClass == clang::Stmt::DesignatedInitUpdateExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ImplicitValueInitExprClass == clang::Stmt::ImplicitValueInitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_NoInitExprClass == clang::Stmt::NoInitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ArrayInitLoopExprClass == clang::Stmt::ArrayInitLoopExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ArrayInitIndexExprClass == clang::Stmt::ArrayInitIndexExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ParenListExprClass == clang::Stmt::ParenListExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_VAArgExprClass == clang::Stmt::VAArgExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_GenericSelectionExprClass == clang::Stmt::GenericSelectionExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_PseudoObjectExprClass == clang::Stmt::PseudoObjectExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ConstantExprClass == clang::Stmt::ConstantExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_AtomicExprClass == clang::Stmt::AtomicExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_AddrLabelExprClass == clang::Stmt::AddrLabelExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_StmtExprClass == clang::Stmt::StmtExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ChooseExprClass == clang::Stmt::ChooseExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_GNUNullExprClass == clang::Stmt::GNUNullExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXOperatorCallExprClass == clang::Stmt::CXXOperatorCallExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXMemberCallExprClass == clang::Stmt::CXXMemberCallExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXStaticCastExprClass == clang::Stmt::CXXStaticCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXDynamicCastExprClass == clang::Stmt::CXXDynamicCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXReinterpretCastExprClass == clang::Stmt::CXXReinterpretCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXConstCastExprClass == clang::Stmt::CXXConstCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXFunctionalCastExprClass == clang::Stmt::CXXFunctionalCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXTypeidExprClass == clang::Stmt::CXXTypeidExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_UserDefinedLiteralClass == clang::Stmt::UserDefinedLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXBoolLiteralExprClass == clang::Stmt::CXXBoolLiteralExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXNullPtrLiteralExprClass == clang::Stmt::CXXNullPtrLiteralExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXThisExprClass == clang::Stmt::CXXThisExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXThrowExprClass == clang::Stmt::CXXThrowExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXDefaultArgExprClass == clang::Stmt::CXXDefaultArgExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXDefaultInitExprClass == clang::Stmt::CXXDefaultInitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXScalarValueInitExprClass == clang::Stmt::CXXScalarValueInitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXStdInitializerListExprClass == clang::Stmt::CXXStdInitializerListExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXNewExprClass == clang::Stmt::CXXNewExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXDeleteExprClass == clang::Stmt::CXXDeleteExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXPseudoDestructorExprClass == clang::Stmt::CXXPseudoDestructorExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_TypeTraitExprClass == clang::Stmt::TypeTraitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ArrayTypeTraitExprClass == clang::Stmt::ArrayTypeTraitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ExpressionTraitExprClass == clang::Stmt::ExpressionTraitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DependentScopeDeclRefExprClass == clang::Stmt::DependentScopeDeclRefExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXConstructExprClass == clang::Stmt::CXXConstructExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXInheritedCtorInitExprClass == clang::Stmt::CXXInheritedCtorInitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXBindTemporaryExprClass == clang::Stmt::CXXBindTemporaryExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ExprWithCleanupsClass == clang::Stmt::ExprWithCleanupsClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXTemporaryObjectExprClass == clang::Stmt::CXXTemporaryObjectExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXUnresolvedConstructExprClass == clang::Stmt::CXXUnresolvedConstructExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXDependentScopeMemberExprClass == clang::Stmt::CXXDependentScopeMemberExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_UnresolvedLookupExprClass == clang::Stmt::UnresolvedLookupExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_UnresolvedMemberExprClass == clang::Stmt::UnresolvedMemberExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXNoexceptExprClass == clang::Stmt::CXXNoexceptExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_PackExpansionExprClass == clang::Stmt::PackExpansionExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SizeOfPackExprClass == clang::Stmt::SizeOfPackExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SubstNonTypeTemplateParmExprClass == clang::Stmt::SubstNonTypeTemplateParmExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SubstNonTypeTemplateParmPackExprClass == clang::Stmt::SubstNonTypeTemplateParmPackExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_FunctionParmPackExprClass == clang::Stmt::FunctionParmPackExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_MaterializeTemporaryExprClass == clang::Stmt::MaterializeTemporaryExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_LambdaExprClass == clang::Stmt::LambdaExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXFoldExprClass == clang::Stmt::CXXFoldExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CoawaitExprClass == clang::Stmt::CoawaitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_DependentCoawaitExprClass == clang::Stmt::DependentCoawaitExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CoyieldExprClass == clang::Stmt::CoyieldExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCStringLiteralClass == clang::Stmt::ObjCStringLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCBoxedExprClass == clang::Stmt::ObjCBoxedExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCArrayLiteralClass == clang::Stmt::ObjCArrayLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCDictionaryLiteralClass == clang::Stmt::ObjCDictionaryLiteralClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCEncodeExprClass == clang::Stmt::ObjCEncodeExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCMessageExprClass == clang::Stmt::ObjCMessageExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCSelectorExprClass == clang::Stmt::ObjCSelectorExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCProtocolExprClass == clang::Stmt::ObjCProtocolExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCIvarRefExprClass == clang::Stmt::ObjCIvarRefExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCPropertyRefExprClass == clang::Stmt::ObjCPropertyRefExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCIsaExprClass == clang::Stmt::ObjCIsaExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCIndirectCopyRestoreExprClass == clang::Stmt::ObjCIndirectCopyRestoreExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCBoolLiteralExprClass == clang::Stmt::ObjCBoolLiteralExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCSubscriptRefExprClass == clang::Stmt::ObjCSubscriptRefExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCAvailabilityCheckExprClass == clang::Stmt::ObjCAvailabilityCheckExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ObjCBridgedCastExprClass == clang::Stmt::ObjCBridgedCastExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CUDAKernelCallExprClass == clang::Stmt::CUDAKernelCallExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ShuffleVectorExprClass == clang::Stmt::ShuffleVectorExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_ConvertVectorExprClass == clang::Stmt::ConvertVectorExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_BlockExprClass == clang::Stmt::BlockExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OpaqueValueExprClass == clang::Stmt::OpaqueValueExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_TypoExprClass == clang::Stmt::TypoExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_MSPropertyRefExprClass == clang::Stmt::MSPropertyRefExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_MSPropertySubscriptExprClass == clang::Stmt::MSPropertySubscriptExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_CXXUuidofExprClass == clang::Stmt::CXXUuidofExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SEHTryStmtClass == clang::Stmt::SEHTryStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SEHExceptStmtClass == clang::Stmt::SEHExceptStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SEHFinallyStmtClass == clang::Stmt::SEHFinallyStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_SEHLeaveStmtClass == clang::Stmt::SEHLeaveStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_MSDependentExistsStmtClass == clang::Stmt::MSDependentExistsStmtClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_AsTypeExprClass == clang::Stmt::AsTypeExprClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPParallelDirectiveClass == clang::Stmt::OMPParallelDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPSimdDirectiveClass == clang::Stmt::OMPSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPForDirectiveClass == clang::Stmt::OMPForDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPForSimdDirectiveClass == clang::Stmt::OMPForSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPSectionsDirectiveClass == clang::Stmt::OMPSectionsDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPSectionDirectiveClass == clang::Stmt::OMPSectionDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPSingleDirectiveClass == clang::Stmt::OMPSingleDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPMasterDirectiveClass == clang::Stmt::OMPMasterDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPCriticalDirectiveClass == clang::Stmt::OMPCriticalDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPParallelForDirectiveClass == clang::Stmt::OMPParallelForDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPParallelForSimdDirectiveClass == clang::Stmt::OMPParallelForSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPParallelSectionsDirectiveClass == clang::Stmt::OMPParallelSectionsDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTaskDirectiveClass == clang::Stmt::OMPTaskDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTaskyieldDirectiveClass == clang::Stmt::OMPTaskyieldDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPBarrierDirectiveClass == clang::Stmt::OMPBarrierDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTaskwaitDirectiveClass == clang::Stmt::OMPTaskwaitDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTaskgroupDirectiveClass == clang::Stmt::OMPTaskgroupDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPFlushDirectiveClass == clang::Stmt::OMPFlushDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPOrderedDirectiveClass == clang::Stmt::OMPOrderedDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPAtomicDirectiveClass == clang::Stmt::OMPAtomicDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetDirectiveClass == clang::Stmt::OMPTargetDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetDataDirectiveClass == clang::Stmt::OMPTargetDataDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetEnterDataDirectiveClass == clang::Stmt::OMPTargetEnterDataDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetExitDataDirectiveClass == clang::Stmt::OMPTargetExitDataDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetParallelDirectiveClass == clang::Stmt::OMPTargetParallelDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetParallelForDirectiveClass == clang::Stmt::OMPTargetParallelForDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetUpdateDirectiveClass == clang::Stmt::OMPTargetUpdateDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTeamsDirectiveClass == clang::Stmt::OMPTeamsDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPCancellationPointDirectiveClass == clang::Stmt::OMPCancellationPointDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPCancelDirectiveClass == clang::Stmt::OMPCancelDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTaskLoopDirectiveClass == clang::Stmt::OMPTaskLoopDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTaskLoopSimdDirectiveClass == clang::Stmt::OMPTaskLoopSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPDistributeDirectiveClass == clang::Stmt::OMPDistributeDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPDistributeParallelForDirectiveClass == clang::Stmt::OMPDistributeParallelForDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPDistributeParallelForSimdDirectiveClass == clang::Stmt::OMPDistributeParallelForSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPDistributeSimdDirectiveClass == clang::Stmt::OMPDistributeSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetParallelForSimdDirectiveClass == clang::Stmt::OMPTargetParallelForSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetSimdDirectiveClass == clang::Stmt::OMPTargetSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTeamsDistributeDirectiveClass == clang::Stmt::OMPTeamsDistributeDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTeamsDistributeSimdDirectiveClass == clang::Stmt::OMPTeamsDistributeSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTeamsDistributeParallelForSimdDirectiveClass == clang::Stmt::OMPTeamsDistributeParallelForSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTeamsDistributeParallelForDirectiveClass == clang::Stmt::OMPTeamsDistributeParallelForDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetTeamsDirectiveClass == clang::Stmt::OMPTargetTeamsDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetTeamsDistributeDirectiveClass == clang::Stmt::OMPTargetTeamsDistributeDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetTeamsDistributeParallelForDirectiveClass == clang::Stmt::OMPTargetTeamsDistributeParallelForDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetTeamsDistributeParallelForSimdDirectiveClass == clang::Stmt::OMPTargetTeamsDistributeParallelForSimdDirectiveClass, "");
static_assert((clang::Stmt::StmtClass)ZigClangStmt_OMPTargetTeamsDistributeSimdDirectiveClass == clang::Stmt::OMPTargetTeamsDistributeSimdDirectiveClass, "");


static_assert(sizeof(ZigClangSourceLocation) == sizeof(clang::SourceLocation), "");
static ZigClangSourceLocation bitcast(clang::SourceLocation src) {
    ZigClangSourceLocation dest;
    memcpy(&dest, static_cast<void *>(&src), sizeof(ZigClangSourceLocation));
    return dest;
}
static clang::SourceLocation bitcast(ZigClangSourceLocation src) {
    clang::SourceLocation dest;
    memcpy(&dest, static_cast<void *>(&src), sizeof(ZigClangSourceLocation));
    return dest;
}

static_assert(sizeof(ZigClangQualType) == sizeof(clang::QualType), "");
static ZigClangQualType bitcast(clang::QualType src) {
    ZigClangQualType dest;
    memcpy(&dest, static_cast<void *>(&src), sizeof(ZigClangQualType));
    return dest;
}
static clang::QualType bitcast(ZigClangQualType src) {
    clang::QualType dest;
    memcpy(&dest, static_cast<void *>(&src), sizeof(ZigClangQualType));
    return dest;
}

ZigClangSourceLocation ZigClangSourceManager_getSpellingLoc(const ZigClangSourceManager *self,
        ZigClangSourceLocation Loc)
{
    return bitcast(reinterpret_cast<const clang::SourceManager *>(self)->getSpellingLoc(bitcast(Loc)));
}

const char *ZigClangSourceManager_getFilename(const ZigClangSourceManager *self,
        ZigClangSourceLocation SpellingLoc)
{
    llvm::StringRef s = reinterpret_cast<const clang::SourceManager *>(self)->getFilename(bitcast(SpellingLoc));
    return (const char *)s.bytes_begin();
}

unsigned ZigClangSourceManager_getSpellingLineNumber(const ZigClangSourceManager *self,
        ZigClangSourceLocation Loc)
{
    return reinterpret_cast<const clang::SourceManager *>(self)->getSpellingLineNumber(bitcast(Loc));
}

unsigned ZigClangSourceManager_getSpellingColumnNumber(const ZigClangSourceManager *self,
        ZigClangSourceLocation Loc)
{
    return reinterpret_cast<const clang::SourceManager *>(self)->getSpellingColumnNumber(bitcast(Loc));
}

const char* ZigClangSourceManager_getCharacterData(const ZigClangSourceManager *self,
        ZigClangSourceLocation SL)
{
    return reinterpret_cast<const clang::SourceManager *>(self)->getCharacterData(bitcast(SL));
}

ZigClangQualType ZigClangASTContext_getPointerType(const ZigClangASTContext* self, ZigClangQualType T) {
    return bitcast(reinterpret_cast<const clang::ASTContext *>(self)->getPointerType(bitcast(T)));
}

ZigClangASTContext *ZigClangASTUnit_getASTContext(ZigClangASTUnit *self) {
    clang::ASTContext *result = &reinterpret_cast<clang::ASTUnit *>(self)->getASTContext();
    return reinterpret_cast<ZigClangASTContext *>(result);
}

ZigClangSourceManager *ZigClangASTUnit_getSourceManager(ZigClangASTUnit *self) {
    clang::SourceManager *result = &reinterpret_cast<clang::ASTUnit *>(self)->getSourceManager();
    return reinterpret_cast<ZigClangSourceManager *>(result);
}

bool ZigClangASTUnit_visitLocalTopLevelDecls(ZigClangASTUnit *self, void *context, 
    bool (*Fn)(void *context, const ZigClangDecl *decl))
{
    return reinterpret_cast<clang::ASTUnit *>(self)->visitLocalTopLevelDecls(context,
            reinterpret_cast<bool (*)(void *, const clang::Decl *)>(Fn));
}

const ZigClangRecordDecl *ZigClangRecordType_getDecl(const ZigClangRecordType *record_ty) {
    const clang::RecordDecl *record_decl = reinterpret_cast<const clang::RecordType *>(record_ty)->getDecl();
    return reinterpret_cast<const ZigClangRecordDecl *>(record_decl);
}

const ZigClangEnumDecl *ZigClangEnumType_getDecl(const ZigClangEnumType *enum_ty) {
    const clang::EnumDecl *enum_decl = reinterpret_cast<const clang::EnumType *>(enum_ty)->getDecl();
    return reinterpret_cast<const ZigClangEnumDecl *>(enum_decl);
}

const ZigClangTagDecl *ZigClangRecordDecl_getCanonicalDecl(const ZigClangRecordDecl *record_decl) {
    const clang::TagDecl *tag_decl = reinterpret_cast<const clang::RecordDecl*>(record_decl)->getCanonicalDecl();
    return reinterpret_cast<const ZigClangTagDecl *>(tag_decl);
}

const ZigClangTagDecl *ZigClangEnumDecl_getCanonicalDecl(const ZigClangEnumDecl *enum_decl) {
    const clang::TagDecl *tag_decl = reinterpret_cast<const clang::EnumDecl*>(enum_decl)->getCanonicalDecl();
    return reinterpret_cast<const ZigClangTagDecl *>(tag_decl);
}

const ZigClangTypedefNameDecl *ZigClangTypedefNameDecl_getCanonicalDecl(const ZigClangTypedefNameDecl *self) {
    const clang::TypedefNameDecl *decl = reinterpret_cast<const clang::TypedefNameDecl*>(self)->getCanonicalDecl();
    return reinterpret_cast<const ZigClangTypedefNameDecl *>(decl);
}

const ZigClangRecordDecl *ZigClangRecordDecl_getDefinition(const ZigClangRecordDecl *zig_record_decl) {
    const clang::RecordDecl *record_decl = reinterpret_cast<const clang::RecordDecl *>(zig_record_decl);
    const clang::RecordDecl *definition = record_decl->getDefinition();
    return reinterpret_cast<const ZigClangRecordDecl *>(definition);
}

const ZigClangEnumDecl *ZigClangEnumDecl_getDefinition(const ZigClangEnumDecl *zig_enum_decl) {
    const clang::EnumDecl *enum_decl = reinterpret_cast<const clang::EnumDecl *>(zig_enum_decl);
    const clang::EnumDecl *definition = enum_decl->getDefinition();
    return reinterpret_cast<const ZigClangEnumDecl *>(definition);
}

bool ZigClangRecordDecl_isUnion(const ZigClangRecordDecl *record_decl) {
    return reinterpret_cast<const clang::RecordDecl*>(record_decl)->isUnion();
}

bool ZigClangRecordDecl_isStruct(const ZigClangRecordDecl *record_decl) {
    return reinterpret_cast<const clang::RecordDecl*>(record_decl)->isStruct();
}

bool ZigClangRecordDecl_isAnonymousStructOrUnion(const ZigClangRecordDecl *record_decl) {
    return reinterpret_cast<const clang::RecordDecl*>(record_decl)->isAnonymousStructOrUnion();
}

const char *ZigClangDecl_getName_bytes_begin(const ZigClangDecl *zig_decl) {
    const clang::Decl *decl = reinterpret_cast<const clang::Decl *>(zig_decl);
    const clang::NamedDecl *named_decl = static_cast<const clang::NamedDecl *>(decl);
    return (const char *)named_decl->getName().bytes_begin();
}

ZigClangSourceLocation ZigClangRecordDecl_getLocation(const ZigClangRecordDecl *zig_record_decl) {
    const clang::RecordDecl *record_decl = reinterpret_cast<const clang::RecordDecl *>(zig_record_decl);
    return bitcast(record_decl->getLocation());
}

ZigClangSourceLocation ZigClangEnumDecl_getLocation(const ZigClangEnumDecl *self) {
    auto casted = reinterpret_cast<const clang::EnumDecl *>(self);
    return bitcast(casted->getLocation());
}

ZigClangSourceLocation ZigClangTypedefNameDecl_getLocation(const ZigClangTypedefNameDecl *self) {
    auto casted = reinterpret_cast<const clang::TypedefNameDecl *>(self);
    return bitcast(casted->getLocation());
}

bool ZigClangSourceLocation_eq(ZigClangSourceLocation zig_a, ZigClangSourceLocation zig_b) {
    clang::SourceLocation a = bitcast(zig_a);
    clang::SourceLocation b = bitcast(zig_b);
    return a == b;
}

ZigClangQualType ZigClangEnumDecl_getIntegerType(const ZigClangEnumDecl *self) {
    return bitcast(reinterpret_cast<const clang::EnumDecl *>(self)->getIntegerType());
}

const ZigClangTypedefNameDecl *ZigClangTypedefType_getDecl(const ZigClangTypedefType *self) {
    auto casted = reinterpret_cast<const clang::TypedefType *>(self);
    const clang::TypedefNameDecl *name_decl = casted->getDecl();
    return reinterpret_cast<const ZigClangTypedefNameDecl *>(name_decl);
}

ZigClangQualType ZigClangTypedefNameDecl_getUnderlyingType(const ZigClangTypedefNameDecl *self) {
    auto casted = reinterpret_cast<const clang::TypedefNameDecl *>(self);
    clang::QualType ty = casted->getUnderlyingType();
    return bitcast(ty);
}

ZigClangQualType ZigClangQualType_getCanonicalType(ZigClangQualType self) {
    clang::QualType qt = bitcast(self);
    return bitcast(qt.getCanonicalType());
}

const ZigClangType *ZigClangQualType_getTypePtr(ZigClangQualType self) {
    clang::QualType qt = bitcast(self);
    const clang::Type *ty = qt.getTypePtr();
    return reinterpret_cast<const ZigClangType *>(ty);
}

void ZigClangQualType_addConst(ZigClangQualType *self) {
    reinterpret_cast<clang::QualType *>(self)->addConst();
}

bool ZigClangQualType_eq(ZigClangQualType zig_t1, ZigClangQualType zig_t2) {
    clang::QualType t1 = bitcast(zig_t1);
    clang::QualType t2 = bitcast(zig_t2);
    if (t1.isConstQualified() != t2.isConstQualified()) {
        return false;
    }
    if (t1.isVolatileQualified() != t2.isVolatileQualified()) {
        return false;
    }
    if (t1.isRestrictQualified() != t2.isRestrictQualified()) {
        return false;
    }
    return t1.getTypePtr() == t2.getTypePtr();
}

bool ZigClangQualType_isConstQualified(ZigClangQualType self) {
    clang::QualType qt = bitcast(self);
    return qt.isConstQualified();
}

bool ZigClangQualType_isVolatileQualified(ZigClangQualType self) {
    clang::QualType qt = bitcast(self);
    return qt.isVolatileQualified();
}

bool ZigClangQualType_isRestrictQualified(ZigClangQualType self) {
    clang::QualType qt = bitcast(self);
    return qt.isRestrictQualified();
}

ZigClangTypeClass ZigClangType_getTypeClass(const ZigClangType *self) {
    auto casted = reinterpret_cast<const clang::Type *>(self);
    clang::Type::TypeClass tc = casted->getTypeClass();
    return (ZigClangTypeClass)tc;
}

bool ZigClangType_isVoidType(const ZigClangType *self) {
    auto casted = reinterpret_cast<const clang::Type *>(self);
    return casted->isVoidType();
}

const char *ZigClangType_getTypeClassName(const ZigClangType *self) {
    auto casted = reinterpret_cast<const clang::Type *>(self);
    return casted->getTypeClassName();
}

ZigClangSourceLocation ZigClangStmt_getBeginLoc(const ZigClangStmt *self) {
    auto casted = reinterpret_cast<const clang::Stmt *>(self);
    return bitcast(casted->getBeginLoc());
}

bool ZigClangStmt_classof_Expr(const ZigClangStmt *self) {
    auto casted = reinterpret_cast<const clang::Stmt *>(self);
    return clang::Expr::classof(casted);
}

ZigClangStmtClass ZigClangStmt_getStmtClass(const ZigClangStmt *self) {
    auto casted = reinterpret_cast<const clang::Stmt *>(self);
    return (ZigClangStmtClass)casted->getStmtClass();
}
