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
    TokenIdKeywordLet,
    TokenIdKeywordMut,
    TokenIdKeywordConst,
    TokenIdKeywordExtern,
    TokenIdKeywordUnreachable,
    TokenIdKeywordPub,
    TokenIdKeywordExport,
    TokenIdKeywordAs,
    TokenIdKeywordUse,
    TokenIdKeywordVoid,
    TokenIdKeywordTrue,
    TokenIdKeywordFalse,
    TokenIdKeywordIf,
    TokenIdKeywordElse,
    TokenIdKeywordGoto,
    TokenIdKeywordAsm,
    TokenIdKeywordVolatile,
    TokenIdKeywordStruct,
    TokenIdLParen,
    TokenIdRParen,
    TokenIdComma,
    TokenIdStar,
    TokenIdLBrace,
    TokenIdRBrace,
    TokenIdLBracket,
    TokenIdRBracket,
    TokenIdStringLiteral,
    TokenIdSemicolon,
    TokenIdNumberLiteral,
    TokenIdPlus,
    TokenIdColon,
    TokenIdArrow,
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
    TokenIdDot,
    TokenIdEllipsis,
};

struct Token {
    TokenId id;
    int start_pos;
    int end_pos;
    int start_line;
    int start_column;
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

bool is_printable(uint8_t c);

#endif
