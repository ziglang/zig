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

enum TokenId {
    TokenIdAmpersand,
    TokenIdArrow,
    TokenIdAtSign,
    TokenIdBang,
    TokenIdBarBar,
    TokenIdBarBarEq,
    TokenIdBinOr,
    TokenIdBinXor,
    TokenIdBitAndEq,
    TokenIdBitOrEq,
    TokenIdBitShiftLeft,
    TokenIdBitShiftLeftEq,
    TokenIdBitShiftRight,
    TokenIdBitShiftRightEq,
    TokenIdBitXorEq,
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
    TokenIdNumberSign,
    TokenIdPercent,
    TokenIdPercentDot,
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
    TokenIdMultilineStringLiteral,
    TokenIdSymbol,
    TokenIdTilde,
    TokenIdTimesEq,
    TokenIdTimesPercent,
    TokenIdTimesPercentEq,
    TokenIdCount,
};

struct TokenFloatLit {
    BigFloat bigfloat;
    // overflow is true if when parsing the number, we discovered it would not fit
    // without losing data
    bool overflow;
};

struct TokenIntLit {
    BigInt bigint;
};

struct TokenStrLit {
    Buf str;
};

struct TokenCharLit {
    uint32_t c;
};

struct Token {
    TokenId id;
    size_t start_pos;
    size_t end_pos;
    size_t start_line;
    size_t start_column;

    union {
        // TokenIdIntLiteral
        TokenIntLit int_lit;

        // TokenIdFloatLiteral
        TokenFloatLit float_lit;

        // TokenIdStringLiteral, TokenIdMultilineStringLiteral or TokenIdSymbol
        TokenStrLit str_lit;

        // TokenIdCharLiteral
        TokenCharLit char_lit;
    } data;
};
// work around conflicting name Token which is also found in libclang
typedef Token ZigToken;

struct Tokenization {
    ZigList<Token> *tokens;
    ZigList<size_t> *line_offsets;

    // if an error occurred
    Buf *err;
    size_t err_line;
    size_t err_column;
};

void tokenize(Buf *buf, Tokenization *out_tokenization);

void print_tokens(Buf *buf, ZigList<Token> *tokens);

const char * token_name(TokenId id);

bool valid_symbol_starter(uint8_t c);
bool is_zig_keyword(Buf *buf);

#endif
