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
void zig2clang_BO(ZigClangBO op) {
    switch (op) {
        case ZigClangBO_PtrMemD:
        case ZigClangBO_PtrMemI:
        case ZigClangBO_Cmp:
        case ZigClangBO_Mul:
        case ZigClangBO_Div:
        case ZigClangBO_Rem:
        case ZigClangBO_Add:
        case ZigClangBO_Sub:
        case ZigClangBO_Shl:
        case ZigClangBO_Shr:
        case ZigClangBO_LT:
        case ZigClangBO_GT:
        case ZigClangBO_LE:
        case ZigClangBO_GE:
        case ZigClangBO_EQ:
        case ZigClangBO_NE:
        case ZigClangBO_And:
        case ZigClangBO_Xor:
        case ZigClangBO_Or:
        case ZigClangBO_LAnd:
        case ZigClangBO_LOr:
        case ZigClangBO_Assign:
        case ZigClangBO_Comma:
        case ZigClangBO_MulAssign:
        case ZigClangBO_DivAssign:
        case ZigClangBO_RemAssign:
        case ZigClangBO_AddAssign:
        case ZigClangBO_SubAssign:
        case ZigClangBO_ShlAssign:
        case ZigClangBO_ShrAssign:
        case ZigClangBO_AndAssign:
        case ZigClangBO_XorAssign:
        case ZigClangBO_OrAssign:
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
void zig2clang_UO(ZigClangUO op) {
    switch (op) {
        case ZigClangUO_AddrOf:
        case ZigClangUO_Coawait:
        case ZigClangUO_Deref:
        case ZigClangUO_Extension:
        case ZigClangUO_Imag:
        case ZigClangUO_LNot:
        case ZigClangUO_Minus:
        case ZigClangUO_Not:
        case ZigClangUO_Plus:
        case ZigClangUO_PostDec:
        case ZigClangUO_PostInc:
        case ZigClangUO_PreDec:
        case ZigClangUO_PreInc:
        case ZigClangUO_Real:
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

static_assert(sizeof(ZigClangSourceLocation) == sizeof(clang::SourceLocation), "");

static ZigClangSourceLocation bitcast(clang::SourceLocation src) {
    ZigClangSourceLocation dest;
    memcpy(&dest, &src, sizeof(ZigClangSourceLocation));
    return dest;
}

static clang::SourceLocation bitcast(ZigClangSourceLocation src) {
    clang::SourceLocation dest;
    memcpy(&dest, &src, sizeof(ZigClangSourceLocation));
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
    StringRef s = reinterpret_cast<const clang::SourceManager *>(self)->getFilename(bitcast(SpellingLoc));
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
