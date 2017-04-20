/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


#ifndef ZIG_C_TOKENIZER_HPP
#define ZIG_C_TOKENIZER_HPP

#include "buffer.hpp"

enum CTokId {
    CTokIdCharLit,
    CTokIdStrLit,
    CTokIdNumLitInt,
    CTokIdNumLitFloat,
    CTokIdSymbol,
    CTokIdMinus,
};

struct CTok {
    enum CTokId id;
    union {
        uint8_t char_lit;
        Buf str_lit;
        uint64_t num_lit_int;
        double num_lit_float;
        Buf symbol;
    } data;
};

enum CTokState {
    CTokStateStart,
    CTokStateExpectChar,
    CTokStateCharEscape,
    CTokStateExpectEndQuot,
    CTokStateOpenComment,
    CTokStateLineComment,
    CTokStateComment,
    CTokStateCommentStar,
    CTokStateBackslash,
    CTokStateString,
    CTokStateIdentifier,
    CTokStateDecimal,
    CTokStateOctal,
    CTokStateGotZero,
    CTokStateHex,
    CTokStateIntSuffix,
    CTokStateIntSuffixLong,
    CTokStateFloat,
    CTokStateExpSign,
    CTokStateFloatExp,
    CTokStateFloatExpFirst,
    CTokStateStrOctal,
};

struct CTokenize {
    ZigList<CTok> tokens;
    CTokState state;
    bool error;
    CTok *cur_tok;
    Buf buf;
    bool unsigned_suffix;
    bool long_suffix;
    uint8_t cur_char;
    int octal_index;
};

void tokenize_c_macro(CTokenize *ctok, const uint8_t *c);

#endif
