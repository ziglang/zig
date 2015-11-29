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
    TokenIdKeywordMut,
    TokenIdKeywordConst,
    TokenIdKeywordExtern,
    TokenIdKeywordUnreachable,
    TokenIdKeywordPub,
    TokenIdKeywordExport,
    TokenIdKeywordAs,
    TokenIdLParen,
    TokenIdRParen,
    TokenIdComma,
    TokenIdStar,
    TokenIdLBrace,
    TokenIdRBrace,
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
    TokenIdBinAnd,
    TokenIdBinXor,
    TokenIdEq,
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
};

struct Token {
    TokenId id;
    int start_pos;
    int end_pos;
    int start_line;
    int start_column;
};

ZigList<Token> *tokenize(Buf *buf);

void print_tokens(Buf *buf, ZigList<Token> *tokens);

#endif
