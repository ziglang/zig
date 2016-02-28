/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TOKENIZER_HPP
#define ZIG_TOKENIZER_HPP

#include "buffer.hpp"

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
    TokenIdDivEq,
    TokenIdModEq,
    TokenIdPlusEq,
    TokenIdMinusEq,
    TokenIdBitShiftLeftEq,
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

struct Token {
    TokenId id;
    int start_pos;
    int end_pos;
    int start_line;
    int start_column;

    // for id == TokenIdNumberLiteral
    int radix; // if != 10, then skip the first 2 characters
    int decimal_point_pos; // either exponent_marker_pos or the position of the '.'
    int exponent_marker_pos; // either end_pos or the position of the 'e'/'p'
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

int get_digit_value(uint8_t c);

const char * token_name(TokenId id);

bool valid_symbol_starter(uint8_t c);
bool is_zig_keyword(Buf *buf);

#endif
