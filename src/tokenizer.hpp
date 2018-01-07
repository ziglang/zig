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
    TokenIdDot,
    TokenIdDoubleQuestion,
    TokenIdEllipsis2,
    TokenIdEllipsis3,
    TokenIdEof,
    TokenIdEq,
    TokenIdFatArrow,
    TokenIdFloatLiteral,
    TokenIdIntLiteral,
    TokenIdKeywordAlign,
    TokenIdKeywordSection,
    TokenIdKeywordAnd,
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
    TokenIdKeywordOr,
    TokenIdKeywordPacked,
    TokenIdKeywordPub,
    TokenIdKeywordReturn,
    TokenIdKeywordStdcallCC,
    TokenIdKeywordStruct,
    TokenIdKeywordSwitch,
    TokenIdKeywordTest,
    TokenIdKeywordThis,
    TokenIdKeywordTrue,
    TokenIdKeywordTry,
    TokenIdKeywordUndefined,
    TokenIdKeywordUnion,
    TokenIdKeywordUnreachable,
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
        // TokenIdIntLiteral
        TokenIntLit int_lit;

        // TokenIdFloatLiteral
        TokenFloatLit float_lit;

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
