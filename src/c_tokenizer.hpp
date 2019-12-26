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
    CTokIdPlus,
    CTokIdMinus,
    CTokIdLParen,
    CTokIdRParen,
    CTokIdEOF,
    CTokIdDot,
    CTokIdAsterisk,
    CTokIdBang,
    CTokIdTilde,
    CTokIdShl,
    CTokIdShr,
    CTokIdLt,
    CTokIdGt,
    CTokIdInc,
    CTokIdDec,
};

enum CNumLitSuffix {
    CNumLitSuffixNone,
    CNumLitSuffixL,
    CNumLitSuffixU,
    CNumLitSuffixLU,
    CNumLitSuffixLL,
    CNumLitSuffixLLU,
};

enum CNumLitFormat {
    CNumLitFormatNone,
    CNumLitFormatHex,
    CNumLitFormatOctal,
};

struct CNumLitInt {
    uint64_t x;
    CNumLitSuffix suffix;
    CNumLitFormat format;
};

struct CTok {
    enum CTokId id;
    union {
        uint8_t char_lit;
        Buf str_lit;
        CNumLitInt num_lit_int;
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
    CTokStateFloat,
    CTokStateExpSign,
    CTokStateFloatExp,
    CTokStateFloatExpFirst,
    CTokStateStrHex,
    CTokStateStrOctal,
    CTokStateNumLitIntSuffixU,
    CTokStateNumLitIntSuffixL,
    CTokStateNumLitIntSuffixLL,
    CTokStateNumLitIntSuffixUL,
    CTokStateGotLt,
    CTokStateGotGt,
    CTokStateGotPlus,
    CTokStateGotMinus,
};

struct CTokenize {
    ZigList<CTok> tokens;
    CTokState state;
    bool error;
    CTok *cur_tok;
    Buf buf;
    uint8_t cur_char;
    int octal_index;
};

void tokenize_c_macro(CTokenize *ctok, const uint8_t *c);

#endif
