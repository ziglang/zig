/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "tokenizer.hpp"
#include "util.hpp"

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <inttypes.h>
#include <limits.h>
#include <errno.h>

#define WHITESPACE \
         ' ': \
    case '\r': \
    case '\n'

#define DIGIT_NON_ZERO \
         '1': \
    case '2': \
    case '3': \
    case '4': \
    case '5': \
    case '6': \
    case '7': \
    case '8': \
    case '9'
#define DIGIT \
         '0': \
    case DIGIT_NON_ZERO

#define ALPHA \
         'a': \
    case 'b': \
    case 'c': \
    case 'd': \
    case 'e': \
    case 'f': \
    case 'g': \
    case 'h': \
    case 'i': \
    case 'j': \
    case 'k': \
    case 'l': \
    case 'm': \
    case 'n': \
    case 'o': \
    case 'p': \
    case 'q': \
    case 'r': \
    case 's': \
    case 't': \
    case 'u': \
    case 'v': \
    case 'w': \
    case 'x': \
    case 'y': \
    case 'z': \
    case 'A': \
    case 'B': \
    case 'C': \
    case 'D': \
    case 'E': \
    case 'F': \
    case 'G': \
    case 'H': \
    case 'I': \
    case 'J': \
    case 'K': \
    case 'L': \
    case 'M': \
    case 'N': \
    case 'O': \
    case 'P': \
    case 'Q': \
    case 'R': \
    case 'S': \
    case 'T': \
    case 'U': \
    case 'V': \
    case 'W': \
    case 'X': \
    case 'Y': \
    case 'Z'

#define SYMBOL_CHAR \
    ALPHA: \
    case DIGIT: \
    case '_'

#define SYMBOL_START \
    ALPHA: \
    case '_'

struct ZigKeyword {
    const char *text;
    TokenId token_id;
};

static const struct ZigKeyword zig_keywords[] = {
    {"align", TokenIdKeywordAlign},
    {"allowzero", TokenIdKeywordAllowZero},
    {"and", TokenIdKeywordAnd},
    {"anyframe", TokenIdKeywordAnyFrame},
    {"anytype", TokenIdKeywordAnyType},
    {"asm", TokenIdKeywordAsm},
    {"async", TokenIdKeywordAsync},
    {"await", TokenIdKeywordAwait},
    {"break", TokenIdKeywordBreak},
    {"callconv", TokenIdKeywordCallconv},
    {"catch", TokenIdKeywordCatch},
    {"comptime", TokenIdKeywordCompTime},
    {"const", TokenIdKeywordConst},
    {"continue", TokenIdKeywordContinue},
    {"defer", TokenIdKeywordDefer},
    {"else", TokenIdKeywordElse},
    {"enum", TokenIdKeywordEnum},
    {"errdefer", TokenIdKeywordErrdefer},
    {"error", TokenIdKeywordError},
    {"export", TokenIdKeywordExport},
    {"extern", TokenIdKeywordExtern},
    {"false", TokenIdKeywordFalse},
    {"fn", TokenIdKeywordFn},
    {"for", TokenIdKeywordFor},
    {"if", TokenIdKeywordIf},
    {"inline", TokenIdKeywordInline},
    {"noalias", TokenIdKeywordNoAlias},
    {"noinline", TokenIdKeywordNoInline},
    {"nosuspend", TokenIdKeywordNoSuspend},
    {"null", TokenIdKeywordNull},
    {"opaque", TokenIdKeywordOpaque},
    {"or", TokenIdKeywordOr},
    {"orelse", TokenIdKeywordOrElse},
    {"packed", TokenIdKeywordPacked},
    {"pub", TokenIdKeywordPub},
    {"resume", TokenIdKeywordResume},
    {"return", TokenIdKeywordReturn},
    {"linksection", TokenIdKeywordLinkSection},
    {"struct", TokenIdKeywordStruct},
    {"suspend", TokenIdKeywordSuspend},
    {"switch", TokenIdKeywordSwitch},
    {"test", TokenIdKeywordTest},
    {"threadlocal", TokenIdKeywordThreadLocal},
    {"true", TokenIdKeywordTrue},
    {"try", TokenIdKeywordTry},
    {"undefined", TokenIdKeywordUndefined},
    {"union", TokenIdKeywordUnion},
    {"unreachable", TokenIdKeywordUnreachable},
    {"usingnamespace", TokenIdKeywordUsingNamespace},
    {"var", TokenIdKeywordVar},
    {"volatile", TokenIdKeywordVolatile},
    {"while", TokenIdKeywordWhile},
};

bool is_zig_keyword(Buf *buf) {
    for (size_t i = 0; i < array_length(zig_keywords); i += 1) {
        if (buf_eql_str(buf, zig_keywords[i].text)) {
            return true;
        }
    }
    return false;
}

static bool is_symbol_char(uint8_t c) {
    switch (c) {
        case SYMBOL_CHAR:
            return true;
        default:
            return false;
    }
}

enum TokenizeState {
    TokenizeStateStart,
    TokenizeStateSymbol,
    TokenizeStateZero, // "0", which might lead to "0x"
    TokenizeStateNumber, // "123", "0x123"
    TokenizeStateNumberNoUnderscore, // "12_", "0x12_" next char must be digit
    TokenizeStateNumberDot,
    TokenizeStateFloatFraction, // "123.456", "0x123.456"
    TokenizeStateFloatFractionNoUnderscore, // "123.45_", "0x123.45_"
    TokenizeStateFloatExponentUnsigned, // "123.456e", "123e", "0x123p"
    TokenizeStateFloatExponentNumber, // "123.456e7", "123.456e+7", "123.456e-7"
    TokenizeStateFloatExponentNumberNoUnderscore, // "123.456e7_", "123.456e+7_", "123.456e-7_"
    TokenizeStateString,
    TokenizeStateStringEscape,
    TokenizeStateStringEscapeUnicodeStart,
    TokenizeStateCharLiteral,
    TokenizeStateCharLiteralEnd,
    TokenizeStateCharLiteralUnicode,
    TokenizeStateSawStar,
    TokenizeStateSawStarPercent,
    TokenizeStateSawSlash,
    TokenizeStateSawSlash2,
    TokenizeStateSawSlash3,
    TokenizeStateSawSlashBang,
    TokenizeStateSawBackslash,
    TokenizeStateSawPercent,
    TokenizeStateSawPlus,
    TokenizeStateSawPlusPercent,
    TokenizeStateSawDash,
    TokenizeStateSawMinusPercent,
    TokenizeStateSawAmpersand,
    TokenizeStateSawCaret,
    TokenizeStateSawBar,
    TokenizeStateSawBarBar,
    TokenizeStateDocComment,
    TokenizeStateContainerDocComment,
    TokenizeStateLineComment,
    TokenizeStateLineString,
    TokenizeStateLineStringEnd,
    TokenizeStateLineStringContinue,
    TokenizeStateSawEq,
    TokenizeStateSawBang,
    TokenizeStateSawLessThan,
    TokenizeStateSawLessThanLessThan,
    TokenizeStateSawGreaterThan,
    TokenizeStateSawGreaterThanGreaterThan,
    TokenizeStateSawDot,
    TokenizeStateSawDotDot,
    TokenizeStateSawAtSign,
    TokenizeStateCharCode,
    TokenizeStateError,
};


struct Tokenize {
    Buf *buf;
    size_t pos;
    TokenizeState state;
    ZigList<Token> *tokens;
    int line;
    int column;
    Token *cur_tok;
    Tokenization *out;
    uint32_t radix;
    bool is_trailing_underscore;
    size_t char_code_index;
    bool unicode;
    uint32_t char_code;
    size_t remaining_code_units;
};

ATTRIBUTE_PRINTF(2, 3)
static void tokenize_error(Tokenize *t, const char *format, ...) {
    t->state = TokenizeStateError;

    t->out->err_line = t->line;
    t->out->err_column = t->column;

    va_list ap;
    va_start(ap, format);
    t->out->err = buf_vprintf(format, ap);
    va_end(ap);
}

static void set_token_id(Tokenize *t, Token *token, TokenId id) {
    token->id = id;

    if (id == TokenIdIntLiteral) {
        bigint_init_unsigned(&token->data.int_lit.bigint, 0);
    } else if (id == TokenIdFloatLiteral) {
        bigfloat_init_32(&token->data.float_lit.bigfloat, 0.0f);
        token->data.float_lit.overflow = false;
    } else if (id == TokenIdStringLiteral || id == TokenIdMultilineStringLiteral || id == TokenIdSymbol) {
        memset(&token->data.str_lit.str, 0, sizeof(Buf));
        buf_resize(&token->data.str_lit.str, 0);
    }
}

static void begin_token(Tokenize *t, TokenId id) {
    assert(!t->cur_tok);
    t->tokens->add_one();
    Token *token = &t->tokens->last();
    token->start_line = t->line;
    token->start_column = t->column;
    token->start_pos = t->pos;

    set_token_id(t, token, id);

    t->cur_tok = token;
}

static void cancel_token(Tokenize *t) {
    t->tokens->pop();
    t->cur_tok = nullptr;
}

static void end_float_token(Tokenize *t) {
    uint8_t *ptr_buf = (uint8_t*)buf_ptr(t->buf) + t->cur_tok->start_pos;
    size_t buf_len = t->cur_tok->end_pos - t->cur_tok->start_pos;
    if (bigfloat_init_buf(&t->cur_tok->data.float_lit.bigfloat, ptr_buf, buf_len)) {
        t->cur_tok->data.float_lit.overflow = true;
    }
}

static void end_token(Tokenize *t) {
    assert(t->cur_tok);
    t->cur_tok->end_pos = t->pos + 1;

    if (t->cur_tok->id == TokenIdFloatLiteral) {
        end_float_token(t);
    } else if (t->cur_tok->id == TokenIdSymbol) {
        char *token_mem = buf_ptr(t->buf) + t->cur_tok->start_pos;
        int token_len = (int)(t->cur_tok->end_pos - t->cur_tok->start_pos);

        for (size_t i = 0; i < array_length(zig_keywords); i += 1) {
            if (mem_eql_str(token_mem, token_len, zig_keywords[i].text)) {
                t->cur_tok->id = zig_keywords[i].token_id;
                break;
            }
        }
    }

    t->cur_tok = nullptr;
}

static bool is_exponent_signifier(uint8_t c, int radix) {
    if (radix == 16) {
        return c == 'p' || c == 'P';
    } else {
        return c == 'e' || c == 'E';
    }
}

static uint32_t get_digit_value(uint8_t c) {
    if ('0' <= c && c <= '9') {
        return c - '0';
    }
    if ('A' <= c && c <= 'Z') {
        return c - 'A' + 10;
    }
    if ('a' <= c && c <= 'z') {
        return c - 'a' + 10;
    }
    return UINT32_MAX;
}

static void handle_string_escape(Tokenize *t, uint8_t c) {
    if (t->cur_tok->id == TokenIdCharLiteral) {
        t->cur_tok->data.char_lit.c = c;
        t->state = TokenizeStateCharLiteralEnd;
    } else if (t->cur_tok->id == TokenIdStringLiteral || t->cur_tok->id == TokenIdSymbol) {
        buf_append_char(&t->cur_tok->data.str_lit.str, c);
        t->state = TokenizeStateString;
    } else {
        zig_unreachable();
    }
}

static const char* get_escape_shorthand(uint8_t c) {
    switch (c) {
        case '\0':
            return "\\0";
        case '\a':
            return "\\a";
        case '\b':
            return "\\b";
        case '\t':
            return "\\t";
        case '\n':
            return "\\n";
        case '\v':
            return "\\v";
        case '\f':
            return "\\f";
        case '\r':
            return "\\r";
        default:
            return nullptr;
    }
}

static void invalid_char_error(Tokenize *t, uint8_t c) {
    if (c == '\r') {
        tokenize_error(t, "invalid carriage return, only '\\n' line endings are supported");
        return;
    }

    const char *sh = get_escape_shorthand(c);
    if (sh) {
        tokenize_error(t, "invalid character: '%s'", sh);
        return;
    }

    if (isprint(c)) {
        tokenize_error(t, "invalid character: '%c'", c);
        return;
    }

    tokenize_error(t, "invalid character: '\\x%02x'", c);
}

void tokenize(Buf *buf, Tokenization *out) {
    Tokenize t = {0};
    t.out = out;
    t.tokens = out->tokens = heap::c_allocator.create<ZigList<Token>>();
    t.buf = buf;

    out->line_offsets = heap::c_allocator.create<ZigList<size_t>>();
    out->line_offsets->append(0);

    // Skip the UTF-8 BOM if present
    if (buf_starts_with_mem(buf, "\xEF\xBB\xBF", 3)) {
        t.pos += 3;
    }

    for (; t.pos < buf_len(t.buf); t.pos += 1) {
        uint8_t c = buf_ptr(t.buf)[t.pos];
        switch (t.state) {
            case TokenizeStateError:
                break;
            case TokenizeStateStart:
                switch (c) {
                    case WHITESPACE:
                        break;
                    case ALPHA:
                    case '_':
                        t.state = TokenizeStateSymbol;
                        begin_token(&t, TokenIdSymbol);
                        buf_append_char(&t.cur_tok->data.str_lit.str, c);
                        break;
                    case '0':
                        t.state = TokenizeStateZero;
                        begin_token(&t, TokenIdIntLiteral);
                        t.is_trailing_underscore = false;
                        t.radix = 10;
                        bigint_init_unsigned(&t.cur_tok->data.int_lit.bigint, 0);
                        break;
                    case DIGIT_NON_ZERO:
                        t.state = TokenizeStateNumber;
                        begin_token(&t, TokenIdIntLiteral);
                        t.is_trailing_underscore = false;
                        t.radix = 10;
                        bigint_init_unsigned(&t.cur_tok->data.int_lit.bigint, get_digit_value(c));
                        break;
                    case '"':
                        begin_token(&t, TokenIdStringLiteral);
                        t.state = TokenizeStateString;
                        break;
                    case '\'':
                        begin_token(&t, TokenIdCharLiteral);
                        t.state = TokenizeStateCharLiteral;
                        break;
                    case '(':
                        begin_token(&t, TokenIdLParen);
                        end_token(&t);
                        break;
                    case ')':
                        begin_token(&t, TokenIdRParen);
                        end_token(&t);
                        break;
                    case ',':
                        begin_token(&t, TokenIdComma);
                        end_token(&t);
                        break;
                    case '?':
                        begin_token(&t, TokenIdQuestion);
                        end_token(&t);
                        break;
                    case '{':
                        begin_token(&t, TokenIdLBrace);
                        end_token(&t);
                        break;
                    case '}':
                        begin_token(&t, TokenIdRBrace);
                        end_token(&t);
                        break;
                    case '[':
                        begin_token(&t, TokenIdLBracket);
                        end_token(&t);
                        break;
                    case ']':
                        begin_token(&t, TokenIdRBracket);
                        end_token(&t);
                        break;
                    case ';':
                        begin_token(&t, TokenIdSemicolon);
                        end_token(&t);
                        break;
                    case ':':
                        begin_token(&t, TokenIdColon);
                        end_token(&t);
                        break;
                    case '#':
                        begin_token(&t, TokenIdNumberSign);
                        end_token(&t);
                        break;
                    case '*':
                        begin_token(&t, TokenIdStar);
                        t.state = TokenizeStateSawStar;
                        break;
                    case '/':
                        begin_token(&t, TokenIdSlash);
                        t.state = TokenizeStateSawSlash;
                        break;
                    case '\\':
                        begin_token(&t, TokenIdMultilineStringLiteral);
                        t.state = TokenizeStateSawBackslash;
                        break;
                    case '%':
                        begin_token(&t, TokenIdPercent);
                        t.state = TokenizeStateSawPercent;
                        break;
                    case '+':
                        begin_token(&t, TokenIdPlus);
                        t.state = TokenizeStateSawPlus;
                        break;
                    case '~':
                        begin_token(&t, TokenIdTilde);
                        end_token(&t);
                        break;
                    case '@':
                        begin_token(&t, TokenIdAtSign);
                        t.state = TokenizeStateSawAtSign;
                        break;
                    case '-':
                        begin_token(&t, TokenIdDash);
                        t.state = TokenizeStateSawDash;
                        break;
                    case '&':
                        begin_token(&t, TokenIdAmpersand);
                        t.state = TokenizeStateSawAmpersand;
                        break;
                    case '^':
                        begin_token(&t, TokenIdBinXor);
                        t.state = TokenizeStateSawCaret;
                        break;
                    case '|':
                        begin_token(&t, TokenIdBinOr);
                        t.state = TokenizeStateSawBar;
                        break;
                    case '=':
                        begin_token(&t, TokenIdEq);
                        t.state = TokenizeStateSawEq;
                        break;
                    case '!':
                        begin_token(&t, TokenIdBang);
                        t.state = TokenizeStateSawBang;
                        break;
                    case '<':
                        begin_token(&t, TokenIdCmpLessThan);
                        t.state = TokenizeStateSawLessThan;
                        break;
                    case '>':
                        begin_token(&t, TokenIdCmpGreaterThan);
                        t.state = TokenizeStateSawGreaterThan;
                        break;
                    case '.':
                        begin_token(&t, TokenIdDot);
                        t.state = TokenizeStateSawDot;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeStateSawDot:
                switch (c) {
                    case '.':
                        t.state = TokenizeStateSawDotDot;
                        set_token_id(&t, t.cur_tok, TokenIdEllipsis2);
                        break;
                    case '*':
                        t.state = TokenizeStateStart;
                        set_token_id(&t, t.cur_tok, TokenIdDotStar);
                        end_token(&t);
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawDotDot:
                switch (c) {
                    case '.':
                        t.state = TokenizeStateStart;
                        set_token_id(&t, t.cur_tok, TokenIdEllipsis3);
                        end_token(&t);
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawGreaterThan:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdCmpGreaterOrEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '>':
                        set_token_id(&t, t.cur_tok, TokenIdBitShiftRight);
                        t.state = TokenizeStateSawGreaterThanGreaterThan;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawGreaterThanGreaterThan:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdBitShiftRightEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawLessThan:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdCmpLessOrEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '<':
                        set_token_id(&t, t.cur_tok, TokenIdBitShiftLeft);
                        t.state = TokenizeStateSawLessThanLessThan;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawLessThanLessThan:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdBitShiftLeftEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawBang:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdCmpNotEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawEq:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdCmpEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '>':
                        set_token_id(&t, t.cur_tok, TokenIdFatArrow);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawStar:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdTimesEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '*':
                        set_token_id(&t, t.cur_tok, TokenIdStarStar);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '%':
                        set_token_id(&t, t.cur_tok, TokenIdTimesPercent);
                        t.state = TokenizeStateSawStarPercent;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawStarPercent:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdTimesPercentEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawPercent:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdModEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '.':
                        set_token_id(&t, t.cur_tok, TokenIdPercentDot);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawPlus:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdPlusEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '+':
                        set_token_id(&t, t.cur_tok, TokenIdPlusPlus);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '%':
                        set_token_id(&t, t.cur_tok, TokenIdPlusPercent);
                        t.state = TokenizeStateSawPlusPercent;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawPlusPercent:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdPlusPercentEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawAmpersand:
                switch (c) {
                    case '&':
                        tokenize_error(&t, "`&&` is invalid. Note that `and` is boolean AND");
                        break;
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdBitAndEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawCaret:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdBitXorEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawBar:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdBitOrEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '|':
                        set_token_id(&t, t.cur_tok, TokenIdBarBar);
                        t.state = TokenizeStateSawBarBar;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawBarBar:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdBarBarEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawSlash:
                switch (c) {
                    case '/':
                        t.state = TokenizeStateSawSlash2;
                        break;
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdDivEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawSlash2:
                switch (c) {
                    case '/':
                        t.state = TokenizeStateSawSlash3;
                        break;
                    case '!':
                        t.state = TokenizeStateSawSlashBang;
                        break;
                    case '\n':
                        cancel_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        cancel_token(&t);
                        t.state = TokenizeStateLineComment;
                        break;
                }
                break;
            case TokenizeStateSawSlash3:
                switch (c) {
                    case '/':
                        cancel_token(&t);
                        t.state = TokenizeStateLineComment;
                        break;
                    case '\n':
                        set_token_id(&t, t.cur_tok, TokenIdDocComment);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        set_token_id(&t, t.cur_tok, TokenIdDocComment);
                        t.state = TokenizeStateDocComment;
                        break;
                }
                break;
            case TokenizeStateSawSlashBang:
                switch (c) {
                    case '\n':
                        set_token_id(&t, t.cur_tok, TokenIdContainerDocComment);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        set_token_id(&t, t.cur_tok, TokenIdContainerDocComment);
                        t.state = TokenizeStateContainerDocComment;
                        break;
                }
                break;
            case TokenizeStateSawBackslash:
                switch (c) {
                    case '\\':
                        t.state = TokenizeStateLineString;
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeStateLineString:
                switch (c) {
                    case '\n':
                        t.state = TokenizeStateLineStringEnd;
                        break;
                    default:
                        buf_append_char(&t.cur_tok->data.str_lit.str, c);
                        break;
                }
                break;
            case TokenizeStateLineStringEnd:
                switch (c) {
                    case WHITESPACE:
                        break;
                    case '\\':
                        t.state = TokenizeStateLineStringContinue;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateLineStringContinue:
                switch (c) {
                    case '\\':
                        t.state = TokenizeStateLineString;
                        buf_append_char(&t.cur_tok->data.str_lit.str, '\n');
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeStateLineComment:
                switch (c) {
                    case '\n':
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        // do nothing
                        break;
                }
                break;
            case TokenizeStateDocComment:
                switch (c) {
                    case '\n':
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        // do nothing
                        break;
                }
                break;
            case TokenizeStateContainerDocComment:
                switch (c) {
                    case '\n':
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        // do nothing
                        break;
                }
                break;
            case TokenizeStateSawAtSign:
                switch (c) {
                    case '"':
                        set_token_id(&t, t.cur_tok, TokenIdSymbol);
                        t.state = TokenizeStateString;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSymbol:
                switch (c) {
                    case SYMBOL_CHAR:
                        buf_append_char(&t.cur_tok->data.str_lit.str, c);
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateString:
                switch (c) {
                    case '"':
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '\n':
                        tokenize_error(&t, "newline not allowed in string literal");
                        break;
                    case '\\':
                        t.state = TokenizeStateStringEscape;
                        break;
                    default:
                        buf_append_char(&t.cur_tok->data.str_lit.str, c);
                        break;
                }
                break;
            case TokenizeStateStringEscape:
                switch (c) {
                    case 'x':
                        t.state = TokenizeStateCharCode;
                        t.radix = 16;
                        t.char_code = 0;
                        t.char_code_index = 0;
                        t.unicode = false;
                        break;
                    case 'u':
                        t.state = TokenizeStateStringEscapeUnicodeStart;
                        break;
                    case 'n':
                        handle_string_escape(&t, '\n');
                        break;
                    case 'r':
                        handle_string_escape(&t, '\r');
                        break;
                    case '\\':
                        handle_string_escape(&t, '\\');
                        break;
                    case 't':
                        handle_string_escape(&t, '\t');
                        break;
                    case '\'':
                        handle_string_escape(&t, '\'');
                        break;
                    case '"':
                        handle_string_escape(&t, '\"');
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeStateStringEscapeUnicodeStart:
                switch (c) {
                    case '{':
                        t.state = TokenizeStateCharCode;
                        t.radix = 16;
                        t.char_code = 0;
                        t.char_code_index = 0;
                        t.unicode = true;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeStateCharCode:
                {
                    if (t.unicode && c == '}') {
                        if (t.char_code_index == 0) {
                            tokenize_error(&t, "empty unicode escape sequence");
                            break;
                        }
                        if (t.char_code > 0x10ffff) {
                            tokenize_error(&t, "unicode value out of range: %x", t.char_code);
                            break;
                        }
                        if (t.cur_tok->id == TokenIdCharLiteral) {
                            t.cur_tok->data.char_lit.c = t.char_code;
                            t.state = TokenizeStateCharLiteralEnd;
                        } else if (t.char_code <= 0x7f) {
                            // 00000000 00000000 00000000 0xxxxxxx
                            handle_string_escape(&t, (uint8_t)t.char_code);
                        } else if (t.char_code <= 0x7ff) {
                            // 00000000 00000000 00000xxx xx000000
                            handle_string_escape(&t, (uint8_t)(0xc0 | (t.char_code >> 6)));
                            // 00000000 00000000 00000000 00xxxxxx
                            handle_string_escape(&t, (uint8_t)(0x80 | (t.char_code & 0x3f)));
                        } else if (t.char_code <= 0xffff) {
                            // 00000000 00000000 xxxx0000 00000000
                            handle_string_escape(&t, (uint8_t)(0xe0 | (t.char_code >> 12)));
                            // 00000000 00000000 0000xxxx xx000000
                            handle_string_escape(&t, (uint8_t)(0x80 | ((t.char_code >> 6) & 0x3f)));
                            // 00000000 00000000 00000000 00xxxxxx
                            handle_string_escape(&t, (uint8_t)(0x80 | (t.char_code & 0x3f)));
                        } else if (t.char_code <= 0x10ffff) {
                            // 00000000 000xxx00 00000000 00000000
                            handle_string_escape(&t, (uint8_t)(0xf0 | (t.char_code >> 18)));
                            // 00000000 000000xx xxxx0000 00000000
                            handle_string_escape(&t, (uint8_t)(0x80 | ((t.char_code >> 12) & 0x3f)));
                            // 00000000 00000000 0000xxxx xx000000
                            handle_string_escape(&t, (uint8_t)(0x80 | ((t.char_code >> 6) & 0x3f)));
                            // 00000000 00000000 00000000 00xxxxxx
                            handle_string_escape(&t, (uint8_t)(0x80 | (t.char_code & 0x3f)));
                        } else {
                            zig_unreachable();
                        }
                        break;
                    }

                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
                        tokenize_error(&t, "invalid digit: '%c'", c);
                        break;
                    }
                    t.char_code *= t.radix;
                    t.char_code += digit_value;
                    t.char_code_index += 1;

                    if (!t.unicode && t.char_code_index >= 2) {
                        assert(t.char_code <= 255);
                        handle_string_escape(&t, (uint8_t)t.char_code);
                    }
                }
                break;
            case TokenizeStateCharLiteral:
                if (c == '\'') {
                    tokenize_error(&t, "expected character");
                } else if (c == '\\') {
                    t.state = TokenizeStateStringEscape;
                } else if ((c >= 0x80 && c <= 0xbf) || c >= 0xf8) {
                    // 10xxxxxx
                    // 11111xxx
                    invalid_char_error(&t, c);
                } else if (c >= 0xc0 && c <= 0xdf) {
                    // 110xxxxx
                    t.cur_tok->data.char_lit.c = c & 0x1f;
                    t.remaining_code_units = 1;
                    t.state = TokenizeStateCharLiteralUnicode;
                } else if (c >= 0xe0 && c <= 0xef) {
                    // 1110xxxx
                    t.cur_tok->data.char_lit.c = c & 0x0f;
                    t.remaining_code_units = 2;
                    t.state = TokenizeStateCharLiteralUnicode;
                } else if (c >= 0xf0 && c <= 0xf7) {
                    // 11110xxx
                    t.cur_tok->data.char_lit.c = c & 0x07;
                    t.remaining_code_units = 3;
                    t.state = TokenizeStateCharLiteralUnicode;
                } else {
                    t.cur_tok->data.char_lit.c = c;
                    t.state = TokenizeStateCharLiteralEnd;
                }
                break;
            case TokenizeStateCharLiteralEnd:
                switch (c) {
                    case '\'':
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeStateCharLiteralUnicode:
                if (c <= 0x7f || c >= 0xc0) {
                    invalid_char_error(&t, c);
                }
                t.cur_tok->data.char_lit.c <<= 6;
                t.cur_tok->data.char_lit.c += c & 0x3f;
                t.remaining_code_units--;
                if (t.remaining_code_units == 0) {
                    t.state = TokenizeStateCharLiteralEnd;
                }
                break;
            case TokenizeStateZero:
                switch (c) {
                    case 'b':
                        t.radix = 2;
                        t.state = TokenizeStateNumberNoUnderscore;
                        break;
                    case 'o':
                        t.radix = 8;
                        t.state = TokenizeStateNumberNoUnderscore;
                        break;
                    case 'x':
                        t.radix = 16;
                        t.state = TokenizeStateNumberNoUnderscore;
                        break;
                    default:
                        // reinterpret as normal number
                        t.pos -= 1;
                        t.state = TokenizeStateNumber;
                        continue;
                }
                break;
            case TokenizeStateNumberNoUnderscore:
                if (c == '_') {
                    invalid_char_error(&t, c);
                    break;
                } else if (get_digit_value(c) < t.radix) {
                    t.is_trailing_underscore = false;
                    t.state = TokenizeStateNumber;
                }
                ZIG_FALLTHROUGH;
            case TokenizeStateNumber:
                {
                    if (c == '_') {
                        t.is_trailing_underscore = true;
                        t.state = TokenizeStateNumberNoUnderscore;
                        break;
                    }
                    if (c == '.') {
                        if (t.is_trailing_underscore) {
                            invalid_char_error(&t, c);
                            break;
                        }
                        t.state = TokenizeStateNumberDot;
                        break;
                    }
                    if (is_exponent_signifier(c, t.radix)) {
                        if (t.is_trailing_underscore) {
                            invalid_char_error(&t, c);
                            break;
                        }
                        if (t.radix != 16 && t.radix != 10) {
                            invalid_char_error(&t, c);
                        }
                        t.state = TokenizeStateFloatExponentUnsigned;
                        t.radix = 10; // exponent is always base 10
                        assert(t.cur_tok->id == TokenIdIntLiteral);
                        set_token_id(&t, t.cur_tok, TokenIdFloatLiteral);
                        break;
                    }
                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
                        if (t.is_trailing_underscore) {
                            invalid_char_error(&t, c);
                            break;
                        }

                        if (is_symbol_char(c)) {
                            invalid_char_error(&t, c);
                        }
                        // not my char
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }
                    BigInt digit_value_bi;
                    bigint_init_unsigned(&digit_value_bi, digit_value);

                    BigInt radix_bi;
                    bigint_init_unsigned(&radix_bi, t.radix);

                    BigInt multiplied;
                    bigint_mul(&multiplied, &t.cur_tok->data.int_lit.bigint, &radix_bi);

                    bigint_add(&t.cur_tok->data.int_lit.bigint, &multiplied, &digit_value_bi);
                    break;
                }
            case TokenizeStateNumberDot:
                {
                    if (c == '.') {
                        t.pos -= 2;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }
                    if (t.radix != 16 && t.radix != 10) {
                        invalid_char_error(&t, c);
                    }
                    t.pos -= 1;
                    t.state = TokenizeStateFloatFractionNoUnderscore;
                    assert(t.cur_tok->id == TokenIdIntLiteral);
                    set_token_id(&t, t.cur_tok, TokenIdFloatLiteral);
                    continue;
                }
            case TokenizeStateFloatFractionNoUnderscore:
                if (c == '_') {
                    invalid_char_error(&t, c);
                } else if (get_digit_value(c) < t.radix) {
                    t.is_trailing_underscore = false;
                    t.state = TokenizeStateFloatFraction;
                }
                ZIG_FALLTHROUGH;
            case TokenizeStateFloatFraction:
                {
                    if (c == '_') {
                        t.is_trailing_underscore = true;
                        t.state = TokenizeStateFloatFractionNoUnderscore;
                        break;
                    }
                    if (is_exponent_signifier(c, t.radix)) {
                        if (t.is_trailing_underscore) {
                            invalid_char_error(&t, c);
                            break;
                        }
                        t.state = TokenizeStateFloatExponentUnsigned;
                        t.radix = 10; // exponent is always base 10
                        break;
                    }
                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
                        if (t.is_trailing_underscore) {
                            invalid_char_error(&t, c);
                            break;
                        }
                        if (is_symbol_char(c)) {
                            invalid_char_error(&t, c);
                        }
                        // not my char
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }

                    // we use parse_f128 to generate the float literal, so just
                    // need to get to the end of the token
                }
                break;
            case TokenizeStateFloatExponentUnsigned:
                switch (c) {
                    case '+':
                        t.state = TokenizeStateFloatExponentNumberNoUnderscore;
                        break;
                    case '-':
                        t.state = TokenizeStateFloatExponentNumberNoUnderscore;
                        break;
                    default:
                        // reinterpret as normal exponent number
                        t.pos -= 1;
                        t.state = TokenizeStateFloatExponentNumberNoUnderscore;
                        continue;
                }
                break;
            case TokenizeStateFloatExponentNumberNoUnderscore:
                if (c == '_') {
                    invalid_char_error(&t, c);
                } else if (get_digit_value(c) < t.radix) {
                    t.is_trailing_underscore = false;
                    t.state = TokenizeStateFloatExponentNumber;
                }
                ZIG_FALLTHROUGH;
            case TokenizeStateFloatExponentNumber:
                {
                    if (c == '_') {
                        t.is_trailing_underscore = true;
                        t.state = TokenizeStateFloatExponentNumberNoUnderscore;
                        break;
                    }
                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
                        if (t.is_trailing_underscore) {
                            invalid_char_error(&t, c);
                            break;
                        }
                        if (is_symbol_char(c)) {
                            invalid_char_error(&t, c);
                        }
                        // not my char
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }

                    // we use parse_f128 to generate the float literal, so just
                    // need to get to the end of the token
                }
                break;
            case TokenizeStateSawDash:
                switch (c) {
                    case '>':
                        set_token_id(&t, t.cur_tok, TokenIdArrow);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdMinusEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '%':
                        set_token_id(&t, t.cur_tok, TokenIdMinusPercent);
                        t.state = TokenizeStateSawMinusPercent;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawMinusPercent:
                switch (c) {
                    case '=':
                        set_token_id(&t, t.cur_tok, TokenIdMinusPercentEq);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
        }
        if (c == '\n') {
            out->line_offsets->append(t.pos + 1);
            t.line += 1;
            t.column = 0;
        } else {
            t.column += 1;
        }
    }
    // EOF
    switch (t.state) {
        case TokenizeStateStart:
        case TokenizeStateError:
            break;
        case TokenizeStateNumberNoUnderscore:
        case TokenizeStateFloatFractionNoUnderscore:
        case TokenizeStateFloatExponentNumberNoUnderscore:
        case TokenizeStateNumberDot:
            tokenize_error(&t, "unterminated number literal");
            break;
        case TokenizeStateString:
            tokenize_error(&t, "unterminated string");
            break;
        case TokenizeStateStringEscape:
        case TokenizeStateStringEscapeUnicodeStart:
        case TokenizeStateCharCode:
            if (t.cur_tok->id == TokenIdStringLiteral) {
                tokenize_error(&t, "unterminated string");
                break;
            } else if (t.cur_tok->id == TokenIdCharLiteral) {
                tokenize_error(&t, "unterminated character literal");
                break;
            } else {
                zig_unreachable();
            }
            break;
        case TokenizeStateCharLiteral:
        case TokenizeStateCharLiteralEnd:
        case TokenizeStateCharLiteralUnicode:
            tokenize_error(&t, "unterminated character literal");
            break;
        case TokenizeStateSymbol:
        case TokenizeStateZero:
        case TokenizeStateNumber:
        case TokenizeStateFloatFraction:
        case TokenizeStateFloatExponentUnsigned:
        case TokenizeStateFloatExponentNumber:
        case TokenizeStateSawStar:
        case TokenizeStateSawSlash:
        case TokenizeStateSawPercent:
        case TokenizeStateSawPlus:
        case TokenizeStateSawDash:
        case TokenizeStateSawAmpersand:
        case TokenizeStateSawCaret:
        case TokenizeStateSawBar:
        case TokenizeStateSawEq:
        case TokenizeStateSawBang:
        case TokenizeStateSawLessThan:
        case TokenizeStateSawLessThanLessThan:
        case TokenizeStateSawGreaterThan:
        case TokenizeStateSawGreaterThanGreaterThan:
        case TokenizeStateSawDot:
        case TokenizeStateSawAtSign:
        case TokenizeStateSawStarPercent:
        case TokenizeStateSawPlusPercent:
        case TokenizeStateSawMinusPercent:
        case TokenizeStateLineString:
        case TokenizeStateLineStringEnd:
        case TokenizeStateSawBarBar:
        case TokenizeStateDocComment:
        case TokenizeStateContainerDocComment:
            end_token(&t);
            break;
        case TokenizeStateSawDotDot:
        case TokenizeStateSawBackslash:
        case TokenizeStateLineStringContinue:
            tokenize_error(&t, "unexpected EOF");
            break;
        case TokenizeStateLineComment:
            break;
        case TokenizeStateSawSlash2:
            cancel_token(&t);
            break;
        case TokenizeStateSawSlash3:
            set_token_id(&t, t.cur_tok, TokenIdDocComment);
            end_token(&t);
            break;
        case TokenizeStateSawSlashBang:
            set_token_id(&t, t.cur_tok, TokenIdContainerDocComment);
            end_token(&t);
            break;
    }
    if (t.state != TokenizeStateError) {
        if (t.tokens->length > 0) {
            Token *last_token = &t.tokens->last();
            t.line = (int)last_token->start_line;
            t.column = (int)last_token->start_column;
            t.pos = last_token->start_pos;
        } else {
            t.pos = 0;
        }
        begin_token(&t, TokenIdEof);
        end_token(&t);
        assert(!t.cur_tok);
    }
}

const char * token_name(TokenId id) {
    switch (id) {
        case TokenIdAmpersand: return "&";
        case TokenIdArrow: return "->";
        case TokenIdAtSign: return "@";
        case TokenIdBang: return "!";
        case TokenIdBarBar: return "||";
        case TokenIdBinOr: return "|";
        case TokenIdBinXor: return "^";
        case TokenIdBitAndEq: return "&=";
        case TokenIdBitOrEq: return "|=";
        case TokenIdBitShiftLeft: return "<<";
        case TokenIdBitShiftLeftEq: return "<<=";
        case TokenIdBitShiftRight: return ">>";
        case TokenIdBitShiftRightEq: return ">>=";
        case TokenIdBitXorEq: return "^=";
        case TokenIdCharLiteral: return "CharLiteral";
        case TokenIdCmpEq: return "==";
        case TokenIdCmpGreaterOrEq: return ">=";
        case TokenIdCmpGreaterThan: return ">";
        case TokenIdCmpLessOrEq: return "<=";
        case TokenIdCmpLessThan: return "<";
        case TokenIdCmpNotEq: return "!=";
        case TokenIdColon: return ":";
        case TokenIdComma: return ",";
        case TokenIdDash: return "-";
        case TokenIdDivEq: return "/=";
        case TokenIdDocComment: return "DocComment";
        case TokenIdContainerDocComment: return "ContainerDocComment";
        case TokenIdDot: return ".";
        case TokenIdDotStar: return ".*";
        case TokenIdEllipsis2: return "..";
        case TokenIdEllipsis3: return "...";
        case TokenIdEof: return "EOF";
        case TokenIdEq: return "=";
        case TokenIdFatArrow: return "=>";
        case TokenIdFloatLiteral: return "FloatLiteral";
        case TokenIdIntLiteral: return "IntLiteral";
        case TokenIdKeywordAsync: return "async";
        case TokenIdKeywordAllowZero: return "allowzero";
        case TokenIdKeywordAwait: return "await";
        case TokenIdKeywordResume: return "resume";
        case TokenIdKeywordSuspend: return "suspend";
        case TokenIdKeywordAlign: return "align";
        case TokenIdKeywordAnd: return "and";
        case TokenIdKeywordAnyFrame: return "anyframe";
        case TokenIdKeywordAnyType: return "anytype";
        case TokenIdKeywordAsm: return "asm";
        case TokenIdKeywordBreak: return "break";
        case TokenIdKeywordCatch: return "catch";
        case TokenIdKeywordCallconv: return "callconv";
        case TokenIdKeywordCompTime: return "comptime";
        case TokenIdKeywordConst: return "const";
        case TokenIdKeywordContinue: return "continue";
        case TokenIdKeywordDefer: return "defer";
        case TokenIdKeywordElse: return "else";
        case TokenIdKeywordEnum: return "enum";
        case TokenIdKeywordErrdefer: return "errdefer";
        case TokenIdKeywordError: return "error";
        case TokenIdKeywordExport: return "export";
        case TokenIdKeywordExtern: return "extern";
        case TokenIdKeywordFalse: return "false";
        case TokenIdKeywordFn: return "fn";
        case TokenIdKeywordFor: return "for";
        case TokenIdKeywordIf: return "if";
        case TokenIdKeywordInline: return "inline";
        case TokenIdKeywordNoAlias: return "noalias";
        case TokenIdKeywordNoInline: return "noinline";
        case TokenIdKeywordNoSuspend: return "nosuspend";
        case TokenIdKeywordNull: return "null";
        case TokenIdKeywordOpaque: return "opaque";
        case TokenIdKeywordOr: return "or";
        case TokenIdKeywordOrElse: return "orelse";
        case TokenIdKeywordPacked: return "packed";
        case TokenIdKeywordPub: return "pub";
        case TokenIdKeywordReturn: return "return";
        case TokenIdKeywordLinkSection: return "linksection";
        case TokenIdKeywordStruct: return "struct";
        case TokenIdKeywordSwitch: return "switch";
        case TokenIdKeywordTest: return "test";
        case TokenIdKeywordThreadLocal: return "threadlocal";
        case TokenIdKeywordTrue: return "true";
        case TokenIdKeywordTry: return "try";
        case TokenIdKeywordUndefined: return "undefined";
        case TokenIdKeywordUnion: return "union";
        case TokenIdKeywordUnreachable: return "unreachable";
        case TokenIdKeywordUsingNamespace: return "usingnamespace";
        case TokenIdKeywordVar: return "var";
        case TokenIdKeywordVolatile: return "volatile";
        case TokenIdKeywordWhile: return "while";
        case TokenIdLBrace: return "{";
        case TokenIdLBracket: return "[";
        case TokenIdLParen: return "(";
        case TokenIdQuestion: return "?";
        case TokenIdMinusEq: return "-=";
        case TokenIdMinusPercent: return "-%";
        case TokenIdMinusPercentEq: return "-%=";
        case TokenIdModEq: return "%=";
        case TokenIdNumberSign: return "#";
        case TokenIdPercent: return "%";
        case TokenIdPercentDot: return "%.";
        case TokenIdPlus: return "+";
        case TokenIdPlusEq: return "+=";
        case TokenIdPlusPercent: return "+%";
        case TokenIdPlusPercentEq: return "+%=";
        case TokenIdPlusPlus: return "++";
        case TokenIdRBrace: return "}";
        case TokenIdRBracket: return "]";
        case TokenIdRParen: return ")";
        case TokenIdSemicolon: return ";";
        case TokenIdSlash: return "/";
        case TokenIdStar: return "*";
        case TokenIdStarStar: return "**";
        case TokenIdStringLiteral: return "StringLiteral";
        case TokenIdMultilineStringLiteral: return "MultilineStringLiteral";
        case TokenIdSymbol: return "Symbol";
        case TokenIdTilde: return "~";
        case TokenIdTimesEq: return "*=";
        case TokenIdTimesPercent: return "*%";
        case TokenIdTimesPercentEq: return "*%=";
        case TokenIdBarBarEq: return "||=";
        case TokenIdCount:
            zig_unreachable();
    }
    return "(invalid token)";
}

void print_tokens(Buf *buf, ZigList<Token> *tokens) {
    for (size_t i = 0; i < tokens->length; i += 1) {
        Token *token = &tokens->at(i);
        fprintf(stderr, "%s ", token_name(token->id));
        if (token->start_pos != SIZE_MAX) {
            fwrite(buf_ptr(buf) + token->start_pos, 1, token->end_pos - token->start_pos, stderr);
        }
        fprintf(stderr, "\n");
    }
}

bool valid_symbol_starter(uint8_t c) {
    switch (c) {
        case SYMBOL_START:
            return true;
    }
    return false;
}
