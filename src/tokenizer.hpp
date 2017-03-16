/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TOKENIZER_HPP
#define ZIG_TOKENIZER_HPP

#include "buffer.hpp"
#include "bignum.hpp"

enum TokenId {
    TokenIdAmpersand,
    TokenIdArrow,
    TokenIdAtSign,
    TokenIdBang,
    TokenIdBinOr,
    TokenIdBinXor,
    TokenIdBitAndEq,
    TokenIdBitOrEq,
    TokenIdBitShiftLeft,
    TokenIdBitShiftLeftEq,
    TokenIdBitShiftLeftPercent,
    TokenIdBitShiftLeftPercentEq,
    TokenIdBitShiftRight,
    TokenIdBitShiftRightEq,
    TokenIdBitXorEq,
    TokenIdBoolAnd,
    TokenIdBoolAndEq,
    TokenIdBoolOr,
    TokenIdBoolOrEq,
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
    TokenIdDot,
    TokenIdDoubleQuestion,
    TokenIdEllipsis,
    TokenIdEof,
    TokenIdEq,
    TokenIdFatArrow,
    TokenIdKeywordAsm,
    TokenIdKeywordBreak,
    TokenIdKeywordColdCC,
    TokenIdKeywordCompTime,
    TokenIdKeywordConst,
    TokenIdKeywordContinue,
    TokenIdKeywordDefer,
    TokenIdKeywordElse,
    TokenIdKeywordEnum,
    TokenIdKeywordError,
    TokenIdKeywordExport,
    TokenIdKeywordExtern,
    TokenIdKeywordFalse,
    TokenIdKeywordFn,
    TokenIdKeywordFor,
    TokenIdKeywordGoto,
    TokenIdKeywordIf,
    TokenIdKeywordInline,
    TokenIdKeywordNakedCC,
    TokenIdKeywordNoAlias,
    TokenIdKeywordNull,
    TokenIdKeywordPacked,
    TokenIdKeywordPub,
    TokenIdKeywordReturn,
    TokenIdKeywordStruct,
    TokenIdKeywordSwitch,
    TokenIdKeywordTest,
    TokenIdKeywordThis,
    TokenIdKeywordTrue,
    TokenIdKeywordTry,
    TokenIdKeywordType,
    TokenIdKeywordUndefined,
    TokenIdKeywordUnion,
    TokenIdKeywordUse,
    TokenIdKeywordVar,
    TokenIdKeywordVolatile,
    TokenIdKeywordWhile,
    TokenIdLBrace,
    TokenIdLBracket,
    TokenIdLParen,
    TokenIdMaybe,
    TokenIdMaybeAssign,
    TokenIdMinusEq,
    TokenIdMinusPercent,
    TokenIdMinusPercentEq,
    TokenIdModEq,
    TokenIdNumberLiteral,
    TokenIdNumberSign,
    TokenIdPercent,
    TokenIdPercentDot,
    TokenIdPercentPercent,
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
    TokenIdSymbol,
    TokenIdTilde,
    TokenIdTimesEq,
    TokenIdTimesPercent,
    TokenIdTimesPercentEq,
};

struct TokenNumLit {
    BigNum bignum;
    // overflow is true if when parsing the number, we discovered it would not
    // fit without losing data in a uint64_t or double
    bool overflow;
};

struct TokenStrLit {
    Buf str;
    bool is_c_str;
};

struct TokenCharLit {
    uint8_t c;
};

struct Token {
    TokenId id;
    size_t start_pos;
    size_t end_pos;
    size_t start_line;
    size_t start_column;

    union {
        // TokenIdNumberLiteral
        TokenNumLit num_lit;

        // TokenIdStringLiteral or TokenIdSymbol
        TokenStrLit str_lit;

        // TokenIdCharLiteral
        TokenCharLit char_lit;
    } data;
};

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
