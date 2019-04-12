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

// This function detects additions to the enum
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

