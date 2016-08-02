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
    TokenIdEof,
    TokenIdSymbol,
    TokenIdKeywordFn,
    TokenIdKeywordReturn,
    TokenIdKeywordVar,
    TokenIdKeywordConst,
    TokenIdKeywordExtern,
    TokenIdKeywordPub,
    TokenIdKeywordUse,
    TokenIdKeywordExport,
    TokenIdKeywordTrue,
    TokenIdKeywordFalse,
    TokenIdKeywordIf,
    TokenIdKeywordElse,
    TokenIdKeywordGoto,
    TokenIdKeywordAsm,
    TokenIdKeywordVolatile,
    TokenIdKeywordStruct,
    TokenIdKeywordEnum,
    TokenIdKeywordUnion,
    TokenIdKeywordWhile,
    TokenIdKeywordFor,
    TokenIdKeywordContinue,
    TokenIdKeywordBreak,
    TokenIdKeywordNull,
    TokenIdKeywordNoAlias,
    TokenIdKeywordSwitch,
    TokenIdKeywordUndefined,
    TokenIdKeywordError,
    TokenIdKeywordType,
    TokenIdKeywordInline,
    TokenIdKeywordDefer,
    TokenIdLParen,
    TokenIdRParen,
    TokenIdComma,
    TokenIdStar,
    TokenIdStarStar,
    TokenIdLBrace,
    TokenIdRBrace,
    TokenIdLBracket,
    TokenIdRBracket,
    TokenIdStringLiteral,
    TokenIdCharLiteral,
    TokenIdSemicolon,
    TokenIdNumberLiteral,
    TokenIdPlus,
    TokenIdPlusPlus,
    TokenIdColon,
    TokenIdArrow,
    TokenIdFatArrow,
    TokenIdDash,
    TokenIdNumberSign,
    TokenIdBoolOr,
    TokenIdBoolAnd,
    TokenIdBinOr,
    TokenIdAmpersand,
    TokenIdBinXor,
    TokenIdEq,
    TokenIdTimesEq,
    TokenIdTimesPercent,
    TokenIdTimesPercentEq,
    TokenIdDivEq,
    TokenIdModEq,
    TokenIdPlusEq,
    TokenIdPlusPercent,
    TokenIdPlusPercentEq,
    TokenIdMinusEq,
    TokenIdMinusPercent,
    TokenIdMinusPercentEq,
    TokenIdBitShiftLeftEq,
    TokenIdBitShiftLeftPercent,
    TokenIdBitShiftLeftPercentEq,
    TokenIdBitShiftRightEq,
    TokenIdBitAndEq,
    TokenIdBitXorEq,
    TokenIdBitOrEq,
    TokenIdBoolAndEq,
    TokenIdBoolOrEq,
    TokenIdCmpEq,
    TokenIdBang,
    TokenIdTilde,
    TokenIdCmpNotEq,
    TokenIdCmpLessThan,
    TokenIdCmpGreaterThan,
    TokenIdCmpLessOrEq,
    TokenIdCmpGreaterOrEq,
    TokenIdBitShiftLeft,
    TokenIdBitShiftRight,
    TokenIdSlash,
    TokenIdPercent,
    TokenIdPercentPercent,
    TokenIdDot,
    TokenIdEllipsis,
    TokenIdMaybe,
    TokenIdDoubleQuestion,
    TokenIdMaybeAssign,
    TokenIdAtSign,
    TokenIdPercentDot,
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
    int start_pos;
    int end_pos;
    int start_line;
    int start_column;

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
    ZigList<int> *line_offsets;

    // if an error occurred
    Buf *err;
    int err_line;
    int err_column;
};

void tokenize(Buf *buf, Tokenization *out_tokenization);

void print_tokens(Buf *buf, ZigList<Token> *tokens);

const char * token_name(TokenId id);

bool valid_symbol_starter(uint8_t c);
bool is_zig_keyword(Buf *buf);

#endif
