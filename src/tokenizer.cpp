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

#define ALPHA_EXCEPT_C \
         'a': \
    case 'b': \
  /*case 'c':*/ \
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

#define ALPHA \
    ALPHA_EXCEPT_C: \
    case 'c'

#define SYMBOL_CHAR \
    ALPHA_EXCEPT_C: \
    case DIGIT: \
    case '_': \
    case 'c'

#define SYMBOL_START \
    ALPHA: \
    case '_'

struct ZigKeyword {
    const char *text;
    TokenId token_id;
};

static const struct ZigKeyword zig_keywords[] = {
    {"align", TokenIdKeywordAlign},
    {"and", TokenIdKeywordAnd},
    {"asm", TokenIdKeywordAsm},
    {"async", TokenIdKeywordAsync},
    {"await", TokenIdKeywordAwait},
    {"break", TokenIdKeywordBreak},
    {"cancel", TokenIdKeywordCancel},
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
    {"nakedcc", TokenIdKeywordNakedCC},
    {"noalias", TokenIdKeywordNoAlias},
    {"null", TokenIdKeywordNull},
    {"or", TokenIdKeywordOr},
    {"orelse", TokenIdKeywordOrElse},
    {"packed", TokenIdKeywordPacked},
    {"promise", TokenIdKeywordPromise},
    {"pub", TokenIdKeywordPub},
    {"resume", TokenIdKeywordResume},
    {"return", TokenIdKeywordReturn},
    {"section", TokenIdKeywordSection},
    {"stdcallcc", TokenIdKeywordStdcallCC},
    {"struct", TokenIdKeywordStruct},
    {"suspend", TokenIdKeywordSuspend},
    {"switch", TokenIdKeywordSwitch},
    {"test", TokenIdKeywordTest},
    {"this", TokenIdKeywordThis},
    {"true", TokenIdKeywordTrue},
    {"try", TokenIdKeywordTry},
    {"undefined", TokenIdKeywordUndefined},
    {"union", TokenIdKeywordUnion},
    {"unreachable", TokenIdKeywordUnreachable},
    {"use", TokenIdKeywordUse},
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
    TokenizeStateSymbolFirstC,
    TokenizeStateZero, // "0", which might lead to "0x"
    TokenizeStateNumber, // "123", "0x123"
    TokenizeStateNumberDot,
    TokenizeStateFloatFraction, // "123.456", "0x123.456"
    TokenizeStateFloatExponentUnsigned, // "123.456e", "123e", "0x123p"
    TokenizeStateFloatExponentNumber, // "123.456e-", "123.456e5", "123.456e5e-5"
    TokenizeStateString,
    TokenizeStateStringEscape,
    TokenizeStateCharLiteral,
    TokenizeStateCharLiteralEnd,
    TokenizeStateSawStar,
    TokenizeStateSawStarPercent,
    TokenizeStateSawSlash,
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
    TokenizeStateLineComment,
    TokenizeStateLineString,
    TokenizeStateLineStringEnd,
    TokenizeStateLineStringContinue,
    TokenizeStateLineStringContinueC,
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
    TokenizeStateLBracket,
    TokenizeStateLBracketStar,
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
    int32_t exp_add_amt;
    bool is_exp_negative;
    size_t char_code_index;
    size_t char_code_end;
    bool unicode;
    uint32_t char_code;
    int exponent_in_bin_or_dec;
    BigInt specified_exponent;
    BigInt significand;
};

ATTRIBUTE_PRINTF(2, 3)
static void tokenize_error(Tokenize *t, const char *format, ...) {
    t->state = TokenizeStateError;

    if (t->cur_tok) {
        t->out->err_line = t->cur_tok->start_line;
        t->out->err_column = t->cur_tok->start_column;
    } else {
        t->out->err_line = t->line;
        t->out->err_column = t->column;
    }

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
    } else if (id == TokenIdStringLiteral || id == TokenIdSymbol) {
        memset(&token->data.str_lit.str, 0, sizeof(Buf));
        buf_resize(&token->data.str_lit.str, 0);
        token->data.str_lit.is_c_str = false;
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
    if (t->radix == 10) {
        uint8_t *ptr_buf = (uint8_t*)buf_ptr(t->buf) + t->cur_tok->start_pos;
        size_t buf_len = t->cur_tok->end_pos - t->cur_tok->start_pos;
        if (bigfloat_init_buf_base10(&t->cur_tok->data.float_lit.bigfloat, ptr_buf, buf_len)) {
            t->cur_tok->data.float_lit.overflow = true;
        }
        return;
    }

    BigInt int_max;
    bigint_init_unsigned(&int_max, INT_MAX);

    if (bigint_cmp(&t->specified_exponent, &int_max) != CmpLT) {
        t->cur_tok->data.float_lit.overflow = true;
        return;
    }

    if (!bigint_fits_in_bits(&t->specified_exponent, 128, true)) {
        t->cur_tok->data.float_lit.overflow = true;
        return;
    }

    int64_t specified_exponent = bigint_as_signed(&t->specified_exponent);
    if (t->is_exp_negative) {
        specified_exponent = -specified_exponent;
    }
    t->exponent_in_bin_or_dec = (int)(t->exponent_in_bin_or_dec + specified_exponent);

    if (!bigint_fits_in_bits(&t->significand, 128, false)) {
        t->cur_tok->data.float_lit.overflow = true;
        return;
    }

    // A SoftFloat-3d float128 is represented internally as a standard
    // quad-precision float with 15bit exponent and 113bit fractional.
    union { uint64_t repr[2]; float128_t actual; } f_bits;

    if (bigint_cmp_zero(&t->significand) == CmpEQ) {
        f_bits.repr[0] = 0;
        f_bits.repr[1] = 0;
    } else {
        // normalize the significand
        if (t->radix == 10) {
            zig_panic("TODO: decimal floats");
        } else {
            int significand_magnitude_in_bin = 127 - bigint_clz(&t->significand, 128);
            t->exponent_in_bin_or_dec += significand_magnitude_in_bin;
            if (!(-16382 <= t->exponent_in_bin_or_dec && t->exponent_in_bin_or_dec <= 16383)) {
                t->cur_tok->data.float_lit.overflow = true;
                return;
            }

            uint64_t sig_bits[2] = {0, 0};
            bigint_write_twos_complement(&t->significand, (uint8_t*) sig_bits, 128, false);

            const uint64_t shift = 112 - significand_magnitude_in_bin;
            const uint64_t exp_shift = 48;
            // Mask the sign bit to 0 since always non-negative lex
            const uint64_t exp_mask = 0xffffull << exp_shift;

            // must be special-cased to avoid undefined behavior on shift == 64
            if (shift == 128) {
                f_bits.repr[0] = 0;
                f_bits.repr[1] = sig_bits[0];
            } else if (shift == 0) {
                f_bits.repr[0] = sig_bits[0];
                f_bits.repr[1] = sig_bits[1];
            } else if (shift >= 64) {
                f_bits.repr[0] = 0;
                f_bits.repr[1] = sig_bits[0] << (shift - 64);
            } else {
                f_bits.repr[0] = sig_bits[0] << shift;
                f_bits.repr[1] = (sig_bits[1] << shift) | (sig_bits[0] >> (64 - shift));
            }

            f_bits.repr[1] &= ~exp_mask;
            f_bits.repr[1] |= (uint64_t)(t->exponent_in_bin_or_dec + 16383) << exp_shift;
        }
    }

    bigfloat_init_128(&t->cur_tok->data.float_lit.bigfloat, f_bits.actual);
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
    } else if (isprint(c)) {
        tokenize_error(t, "invalid character: '%c'", c);
    } else {
        const char *sh = get_escape_shorthand(c);
        if (sh) {
            tokenize_error(t, "invalid character: '%s'", sh);
        } else {
            tokenize_error(t, "invalid character: '\\x%x'", c);
        }
    }
}

void tokenize(Buf *buf, Tokenization *out) {
    Tokenize t = {0};
    t.out = out;
    t.tokens = out->tokens = allocate<ZigList<Token>>(1);
    t.buf = buf;

    out->line_offsets = allocate<ZigList<size_t>>(1);

    out->line_offsets->append(0);
    for (t.pos = 0; t.pos < buf_len(t.buf); t.pos += 1) {
        uint8_t c = buf_ptr(t.buf)[t.pos];
        switch (t.state) {
            case TokenizeStateError:
                break;
            case TokenizeStateStart:
                switch (c) {
                    case WHITESPACE:
                        break;
                    case 'c':
                        t.state = TokenizeStateSymbolFirstC;
                        begin_token(&t, TokenIdSymbol);
                        buf_append_char(&t.cur_tok->data.str_lit.str, c);
                        break;
                    case ALPHA_EXCEPT_C:
                    case '_':
                        t.state = TokenizeStateSymbol;
                        begin_token(&t, TokenIdSymbol);
                        buf_append_char(&t.cur_tok->data.str_lit.str, c);
                        break;
                    case '0':
                        t.state = TokenizeStateZero;
                        begin_token(&t, TokenIdIntLiteral);
                        t.radix = 10;
                        t.exp_add_amt = 1;
                        t.exponent_in_bin_or_dec = 0;
                        bigint_init_unsigned(&t.cur_tok->data.int_lit.bigint, 0);
                        bigint_init_unsigned(&t.specified_exponent, 0);
                        break;
                    case DIGIT_NON_ZERO:
                        t.state = TokenizeStateNumber;
                        begin_token(&t, TokenIdIntLiteral);
                        t.radix = 10;
                        t.exp_add_amt = 1;
                        t.exponent_in_bin_or_dec = 0;
                        bigint_init_unsigned(&t.cur_tok->data.int_lit.bigint, get_digit_value(c));
                        bigint_init_unsigned(&t.specified_exponent, 0);
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
                        t.state = TokenizeStateLBracket;
                        begin_token(&t, TokenIdLBracket);
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
                        begin_token(&t, TokenIdStringLiteral);
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
            case TokenizeStateLBracket:
                switch (c) {
                    case '*':
                        t.state = TokenizeStateLBracketStar;
                        set_token_id(&t, t.cur_tok, TokenIdBracketStarBracket);
                        break;
                    default:
                        // reinterpret as just an lbracket
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateLBracketStar:
                switch (c) {
                    case ']':
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        invalid_char_error(&t, c);
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
            case TokenizeStateSawSlash:
                switch (c) {
                    case '/':
                        cancel_token(&t);
                        t.state = TokenizeStateLineComment;
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
                    case 'c':
                        if (!t.cur_tok->data.str_lit.is_c_str) {
                            t.pos -= 1;
                            end_token(&t);
                            t.state = TokenizeStateStart;
                            break;
                        }
                        t.state = TokenizeStateLineStringContinueC;
                        break;
                    case '\\':
                        if (t.cur_tok->data.str_lit.is_c_str) {
                            invalid_char_error(&t, c);
                        }
                        t.state = TokenizeStateLineStringContinue;
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateLineStringContinueC:
                switch (c) {
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
            case TokenizeStateSymbolFirstC:
                switch (c) {
                    case '"':
                        set_token_id(&t, t.cur_tok, TokenIdStringLiteral);
                        t.cur_tok->data.str_lit.is_c_str = true;
                        t.state = TokenizeStateString;
                        break;
                    case '\\':
                        set_token_id(&t, t.cur_tok, TokenIdStringLiteral);
                        t.cur_tok->data.str_lit.is_c_str = true;
                        t.state = TokenizeStateSawBackslash;
                        break;
                    case SYMBOL_CHAR:
                        t.state = TokenizeStateSymbol;
                        buf_append_char(&t.cur_tok->data.str_lit.str, c);
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
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
                        t.char_code_end = 2;
                        t.unicode = false;
                        break;
                    case 'u':
                        t.state = TokenizeStateCharCode;
                        t.radix = 16;
                        t.char_code = 0;
                        t.char_code_index = 0;
                        t.char_code_end = 4;
                        t.unicode = true;
                        break;
                    case 'U':
                        t.state = TokenizeStateCharCode;
                        t.radix = 16;
                        t.char_code = 0;
                        t.char_code_index = 0;
                        t.char_code_end = 6;
                        t.unicode = true;
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
            case TokenizeStateCharCode:
                {
                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
                        tokenize_error(&t, "invalid digit: '%c'", c);
                    }
                    t.char_code *= t.radix;
                    t.char_code += digit_value;
                    t.char_code_index += 1;

                    if (t.char_code_index >= t.char_code_end) {
                        if (t.unicode) {
                            if (t.char_code <= 0x7f) {
                                // 00000000 00000000 00000000 0xxxxxxx
                                handle_string_escape(&t, (uint8_t)t.char_code);
                            } else if (t.cur_tok->id == TokenIdCharLiteral) {
                                tokenize_error(&t, "unicode value too large for character literal: %x", t.char_code);
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
                                tokenize_error(&t, "unicode value out of range: %x", t.char_code);
                            }
                        } else {
                            if (t.cur_tok->id == TokenIdCharLiteral && t.char_code > UINT8_MAX) {
                                tokenize_error(&t, "value too large for character literal: '%x'",
                                        t.char_code);
                            }
                            handle_string_escape(&t, (uint8_t)t.char_code);
                        }
                    }
                }
                break;
            case TokenizeStateCharLiteral:
                switch (c) {
                    case '\'':
                        tokenize_error(&t, "expected character");
                    case '\\':
                        t.state = TokenizeStateStringEscape;
                        break;
                    default:
                        t.cur_tok->data.char_lit.c = c;
                        t.state = TokenizeStateCharLiteralEnd;
                        break;
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
            case TokenizeStateZero:
                switch (c) {
                    case 'b':
                        t.radix = 2;
                        t.state = TokenizeStateNumber;
                        break;
                    case 'o':
                        t.radix = 8;
                        t.exp_add_amt = 3;
                        t.state = TokenizeStateNumber;
                        break;
                    case 'x':
                        t.radix = 16;
                        t.exp_add_amt = 4;
                        t.state = TokenizeStateNumber;
                        break;
                    default:
                        // reinterpret as normal number
                        t.pos -= 1;
                        t.state = TokenizeStateNumber;
                        continue;
                }
                break;
            case TokenizeStateNumber:
                {
                    if (c == '.') {
                        t.state = TokenizeStateNumberDot;
                        break;
                    }
                    if (is_exponent_signifier(c, t.radix)) {
                        t.state = TokenizeStateFloatExponentUnsigned;
                        assert(t.cur_tok->id == TokenIdIntLiteral);
                        bigint_init_bigint(&t.significand, &t.cur_tok->data.int_lit.bigint);
                        set_token_id(&t, t.cur_tok, TokenIdFloatLiteral);
                        break;
                    }
                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
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
                    t.pos -= 1;
                    t.state = TokenizeStateFloatFraction;
                    assert(t.cur_tok->id == TokenIdIntLiteral);
                    bigint_init_bigint(&t.significand, &t.cur_tok->data.int_lit.bigint);
                    set_token_id(&t, t.cur_tok, TokenIdFloatLiteral);
                    continue;
                }
            case TokenizeStateFloatFraction:
                {
                    if (is_exponent_signifier(c, t.radix)) {
                        t.state = TokenizeStateFloatExponentUnsigned;
                        break;
                    }
                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
                        if (is_symbol_char(c)) {
                            invalid_char_error(&t, c);
                        }
                        // not my char
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }
                    t.exponent_in_bin_or_dec -= t.exp_add_amt;
                    if (t.radix == 10) {
                        // For now we use strtod to parse decimal floats, so we just have to get to the
                        // end of the token.
                        break;
                    }
                    BigInt digit_value_bi;
                    bigint_init_unsigned(&digit_value_bi, digit_value);

                    BigInt radix_bi;
                    bigint_init_unsigned(&radix_bi, t.radix);

                    BigInt multiplied;
                    bigint_mul(&multiplied, &t.significand, &radix_bi);

                    bigint_add(&t.significand, &multiplied, &digit_value_bi);
                    break;
                }
            case TokenizeStateFloatExponentUnsigned:
                switch (c) {
                    case '+':
                        t.is_exp_negative = false;
                        t.state = TokenizeStateFloatExponentNumber;
                        break;
                    case '-':
                        t.is_exp_negative = true;
                        t.state = TokenizeStateFloatExponentNumber;
                        break;
                    default:
                        // reinterpret as normal exponent number
                        t.pos -= 1;
                        t.is_exp_negative = false;
                        t.state = TokenizeStateFloatExponentNumber;
                        continue;
                }
                break;
            case TokenizeStateFloatExponentNumber:
                {
                    uint32_t digit_value = get_digit_value(c);
                    if (digit_value >= t.radix) {
                        if (is_symbol_char(c)) {
                            invalid_char_error(&t, c);
                        }
                        // not my char
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }
                    if (t.radix == 10) {
                        // For now we use strtod to parse decimal floats, so we just have to get to the
                        // end of the token.
                        break;
                    }
                    BigInt digit_value_bi;
                    bigint_init_unsigned(&digit_value_bi, digit_value);

                    BigInt radix_bi;
                    bigint_init_unsigned(&radix_bi, 10);

                    BigInt multiplied;
                    bigint_mul(&multiplied, &t.specified_exponent, &radix_bi);

                    bigint_add(&t.specified_exponent, &multiplied, &digit_value_bi);
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
        case TokenizeStateNumberDot:
            tokenize_error(&t, "unterminated number literal");
            break;
        case TokenizeStateString:
            tokenize_error(&t, "unterminated string");
            break;
        case TokenizeStateStringEscape:
        case TokenizeStateCharCode:
            if (t.cur_tok->id == TokenIdStringLiteral) {
                tokenize_error(&t, "unterminated string");
            } else if (t.cur_tok->id == TokenIdCharLiteral) {
                tokenize_error(&t, "unterminated character literal");
            } else {
                zig_unreachable();
            }
            break;
        case TokenizeStateCharLiteral:
        case TokenizeStateCharLiteralEnd:
            tokenize_error(&t, "unterminated character literal");
            break;
        case TokenizeStateSymbol:
        case TokenizeStateSymbolFirstC:
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
        case TokenizeStateLBracket:
            end_token(&t);
            break;
        case TokenizeStateSawDotDot:
        case TokenizeStateSawBackslash:
        case TokenizeStateLineStringContinue:
        case TokenizeStateLineStringContinueC:
        case TokenizeStateLBracketStar:
            tokenize_error(&t, "unexpected EOF");
            break;
        case TokenizeStateLineComment:
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
        case TokenIdBracketStarBracket: return "[*]";
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
        case TokenIdDot: return ".";
        case TokenIdEllipsis2: return "..";
        case TokenIdEllipsis3: return "...";
        case TokenIdEof: return "EOF";
        case TokenIdEq: return "=";
        case TokenIdFatArrow: return "=>";
        case TokenIdFloatLiteral: return "FloatLiteral";
        case TokenIdIntLiteral: return "IntLiteral";
        case TokenIdKeywordAsync: return "async";
        case TokenIdKeywordAwait: return "await";
        case TokenIdKeywordResume: return "resume";
        case TokenIdKeywordSuspend: return "suspend";
        case TokenIdKeywordCancel: return "cancel";
        case TokenIdKeywordAlign: return "align";
        case TokenIdKeywordAnd: return "and";
        case TokenIdKeywordAsm: return "asm";
        case TokenIdKeywordBreak: return "break";
        case TokenIdKeywordCatch: return "catch";
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
        case TokenIdKeywordNakedCC: return "nakedcc";
        case TokenIdKeywordNoAlias: return "noalias";
        case TokenIdKeywordNull: return "null";
        case TokenIdKeywordOr: return "or";
        case TokenIdKeywordOrElse: return "orelse";
        case TokenIdKeywordPacked: return "packed";
        case TokenIdKeywordPromise: return "promise";
        case TokenIdKeywordPub: return "pub";
        case TokenIdKeywordReturn: return "return";
        case TokenIdKeywordSection: return "section";
        case TokenIdKeywordStdcallCC: return "stdcallcc";
        case TokenIdKeywordStruct: return "struct";
        case TokenIdKeywordSwitch: return "switch";
        case TokenIdKeywordTest: return "test";
        case TokenIdKeywordThis: return "this";
        case TokenIdKeywordTrue: return "true";
        case TokenIdKeywordTry: return "try";
        case TokenIdKeywordUndefined: return "undefined";
        case TokenIdKeywordUnion: return "union";
        case TokenIdKeywordUnreachable: return "unreachable";
        case TokenIdKeywordUse: return "use";
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
        case TokenIdSymbol: return "Symbol";
        case TokenIdTilde: return "~";
        case TokenIdTimesEq: return "*=";
        case TokenIdTimesPercent: return "*%";
        case TokenIdTimesPercentEq: return "*%=";
        case TokenIdBarBarEq: return "||=";
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
