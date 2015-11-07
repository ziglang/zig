/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_TOKENIZER_HPP
#define ZIG_TOKENIZER_HPP

#include "buffer.hpp"

/*
enum TokenId {
    TokenIdEof,
    TokenIdSymbol,
    TokenIdKeywordFn,
    TokenIdKeywordReturn,
    TokenIdKeywordMut,
    TokenIdKeywordConst,
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
};
*/

// TODO: debug delete this 
enum TokenId {
    TokenIdLParen = 0,
    TokenIdRParen = 1,
    TokenIdEof = 2,
    TokenIdStar = 3,
    TokenIdPlus = 4,
    TokenIdSymbol,
    TokenIdKeywordFn,
    TokenIdKeywordReturn,
    TokenIdKeywordMut,
    TokenIdKeywordConst,
    TokenIdComma,
    TokenIdLBrace,
    TokenIdRBrace,
    TokenIdStringLiteral,
    TokenIdSemicolon,
    TokenIdNumberLiteral,
    TokenIdColon,
    TokenIdArrow,
    TokenIdDash,
};

struct Token {
    TokenId id;
    int start_pos;
    int end_pos;
    int start_line;
    int start_column;
};

enum TokenizeState {
    TokenizeStateStart,
    TokenizeStateSymbol,
    TokenizeStateNumber,
    TokenizeStateString,
    TokenizeStateSawDash,
};

ZigList<Token> *tokenize(Buf *buf, Buf *cur_dir_path);

void print_tokens(Buf *buf, ZigList<Token> *tokens);

#endif
