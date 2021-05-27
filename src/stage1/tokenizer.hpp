/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TOKENIZER_HPP
#define ZIG_TOKENIZER_HPP

#include "buffer.hpp"
#include "bigint.hpp"
#include "bigfloat.hpp"

enum TokenId : uint8_t {
    TokenIdAmpersand,
    TokenIdArrow,
    TokenIdBang,
    TokenIdBarBar,
    TokenIdBinOr,
    TokenIdBinXor,
    TokenIdBitAndEq,
    TokenIdBitOrEq,
    TokenIdBitShiftLeft,
    TokenIdBitShiftLeftEq,
    TokenIdBitShiftRight,
    TokenIdBitShiftRightEq,
    TokenIdBitXorEq,
    TokenIdBuiltin,
    TokenIdCharLiteral,
    TokenIdCmpEq,
    TokenIdCmpGreaterOrEq,
    TokenIdCmpGreaterThan,
    TokenIdCmpLessOrEq,
    TokenIdCmpLessThan,
    TokenIdCmpNotEq,
    TokenIdColon,
    TokenIdComma,
    TokenIdDash,
    TokenIdDivEq,
    TokenIdDocComment,
    TokenIdContainerDocComment,
    TokenIdDot,
    TokenIdDotStar,
    TokenIdEllipsis2,
    TokenIdEllipsis3,
    TokenIdEof,
    TokenIdEq,
    TokenIdFatArrow,
    TokenIdFloatLiteral,
    TokenIdIntLiteral,
    TokenIdKeywordAlign,
    TokenIdKeywordAllowZero,
    TokenIdKeywordAnd,
    TokenIdKeywordAnyFrame,
    TokenIdKeywordAnyType,
    TokenIdKeywordAsm,
    TokenIdKeywordAsync,
    TokenIdKeywordAwait,
    TokenIdKeywordBreak,
    TokenIdKeywordCatch,
    TokenIdKeywordCallconv,
    TokenIdKeywordCompTime,
    TokenIdKeywordConst,
    TokenIdKeywordContinue,
    TokenIdKeywordDefer,
    TokenIdKeywordElse,
    TokenIdKeywordEnum,
    TokenIdKeywordErrdefer,
    TokenIdKeywordError,
    TokenIdKeywordExport,
    TokenIdKeywordExtern,
    TokenIdKeywordFalse,
    TokenIdKeywordFn,
    TokenIdKeywordFor,
    TokenIdKeywordIf,
    TokenIdKeywordInline,
    TokenIdKeywordNoInline,
    TokenIdKeywordLinkSection,
    TokenIdKeywordNoAlias,
    TokenIdKeywordNoSuspend,
    TokenIdKeywordNull,
    TokenIdKeywordOpaque,
    TokenIdKeywordOr,
    TokenIdKeywordOrElse,
    TokenIdKeywordPacked,
    TokenIdKeywordPub,
    TokenIdKeywordResume,
    TokenIdKeywordReturn,
    TokenIdKeywordStruct,
    TokenIdKeywordSuspend,
    TokenIdKeywordSwitch,
    TokenIdKeywordTest,
    TokenIdKeywordThreadLocal,
    TokenIdKeywordTrue,
    TokenIdKeywordTry,
    TokenIdKeywordUndefined,
    TokenIdKeywordUnion,
    TokenIdKeywordUnreachable,
    TokenIdKeywordUsingNamespace,
    TokenIdKeywordVar,
    TokenIdKeywordVolatile,
    TokenIdKeywordWhile,
    TokenIdLBrace,
    TokenIdLBracket,
    TokenIdLParen,
    TokenIdQuestion,
    TokenIdMinusEq,
    TokenIdMinusPercent,
    TokenIdMinusPercentEq,
    TokenIdModEq,
    TokenIdPercent,
    TokenIdPlus,
    TokenIdPlusEq,
    TokenIdPlusPercent,
    TokenIdPlusPercentEq,
    TokenIdPlusPlus,
    TokenIdRBrace,
    TokenIdRBracket,
    TokenIdRParen,
    TokenIdSemicolon,
    TokenIdSlash,
    TokenIdStar,
    TokenIdStarStar,
    TokenIdStringLiteral,
    TokenIdMultilineStringLiteralLine,
    TokenIdIdentifier,
    TokenIdTilde,
    TokenIdTimesEq,
    TokenIdTimesPercent,
    TokenIdTimesPercentEq,

    TokenIdCount,
};

typedef uint32_t TokenIndex;

struct TokenLoc {
    uint32_t offset;
    uint32_t line;
    uint32_t column;
};

struct Tokenization {
    ZigList<TokenId> ids;
    ZigList<TokenLoc> locs;

    // if an error occurred
    Buf *err;
    uint32_t err_byte_offset;
};

void tokenize(const char *source, Tokenization *out_tokenization);

const char * token_name(TokenId id);

#endif
