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

#define HEXDIGIT \
         'a': \
    case 'b': \
    case 'c': \
    case 'd': \
    case 'e': \
    case 'f': \
    case 'A': \
    case 'B': \
    case 'C': \
    case 'D': \
    case 'E': \
    case 'F': \
    case DIGIT

#define ALPHA_EXCEPT_HEX_P_O_X \
         'g': \
    case 'h': \
    case 'i': \
    case 'j': \
    case 'k': \
    case 'l': \
    case 'm': \
    case 'n': \
    case 'q': \
    case 'r': \
    case 's': \
    case 't': \
    case 'u': \
    case 'v': \
    case 'w': \
    case 'y': \
    case 'z': \
    case 'G': \
    case 'H': \
    case 'I': \
    case 'J': \
    case 'K': \
    case 'L': \
    case 'M': \
    case 'N': \
    case 'O': \
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

#define ALPHA_EXCEPT_E_B_O_X \
         ALPHA_EXCEPT_HEX_P_O_X: \
    case 'a': \
    case 'c': \
    case 'd': \
    case 'f': \
    case 'A': \
    case 'B': \
    case 'C': \
    case 'D': \
    case 'F': \
    case 'p': \
    case 'P'

#define ALPHA_EXCEPT_HEX_AND_P \
         ALPHA_EXCEPT_HEX_P_O_X: \
    case 'o': \
    case 'x'

#define ALPHA_EXCEPT_E \
         ALPHA_EXCEPT_HEX_AND_P: \
    case 'a': \
    case 'b': \
    case 'c': \
    case 'd': \
    case 'f': \
    case 'A': \
    case 'B': \
    case 'C': \
    case 'D': \
    case 'F': \
    case 'p': \
    case 'P'

#define ALPHA \
    ALPHA_EXCEPT_E: \
    case 'e': \
    case 'E'

#define IDENTIFIER_CHAR \
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

// Returns TokenIdIdentifier if it is not a keyword.
static TokenId zig_keyword_token(const char *name_ptr, size_t name_len) {
    for (size_t i = 0; i < array_length(zig_keywords); i += 1) {
        if (mem_eql_str(name_ptr, name_len, zig_keywords[i].text)) {
            return zig_keywords[i].token_id;
        }
    }
    return TokenIdIdentifier;
}

enum TokenizeState {
    TokenizeState_start,
    TokenizeState_identifier,
    TokenizeState_builtin,
    TokenizeState_string_literal,
    TokenizeState_string_literal_backslash,
    TokenizeState_multiline_string_literal_line,
    TokenizeState_char_literal,
    TokenizeState_char_literal_backslash,
    TokenizeState_char_literal_hex_escape,
    TokenizeState_char_literal_unicode_escape_saw_u,
    TokenizeState_char_literal_unicode_escape,
    TokenizeState_char_literal_unicode,
    TokenizeState_char_literal_end,
    TokenizeState_backslash,
    TokenizeState_equal,
    TokenizeState_bang,
    TokenizeState_pipe,
    TokenizeState_minus,
    TokenizeState_minus_percent,
    TokenizeState_asterisk,
    TokenizeState_asterisk_percent,
    TokenizeState_slash,
    TokenizeState_line_comment_start,
    TokenizeState_line_comment,
    TokenizeState_doc_comment_start,
    TokenizeState_doc_comment,
    TokenizeState_container_doc_comment,
    TokenizeState_zero,
    TokenizeState_int_literal_dec,
    TokenizeState_int_literal_dec_no_underscore,
    TokenizeState_int_literal_bin,
    TokenizeState_int_literal_bin_no_underscore,
    TokenizeState_int_literal_oct,
    TokenizeState_int_literal_oct_no_underscore,
    TokenizeState_int_literal_hex,
    TokenizeState_int_literal_hex_no_underscore,
    TokenizeState_num_dot_dec,
    TokenizeState_num_dot_hex,
    TokenizeState_float_fraction_dec,
    TokenizeState_float_fraction_dec_no_underscore,
    TokenizeState_float_fraction_hex,
    TokenizeState_float_fraction_hex_no_underscore,
    TokenizeState_float_exponent_unsigned,
    TokenizeState_float_exponent_num,
    TokenizeState_float_exponent_num_no_underscore,
    TokenizeState_ampersand,
    TokenizeState_caret,
    TokenizeState_percent,
    TokenizeState_plus,
    TokenizeState_plus_percent,
    TokenizeState_angle_bracket_left,
    TokenizeState_angle_bracket_angle_bracket_left,
    TokenizeState_angle_bracket_right,
    TokenizeState_angle_bracket_angle_bracket_right,
    TokenizeState_period,
    TokenizeState_period_2,
    TokenizeState_period_asterisk,
    TokenizeState_saw_at_sign,
    TokenizeState_error,
};


struct Tokenize {
    Tokenization *out;
    size_t pos;
    TokenizeState state;
    uint32_t line;
    uint32_t column;
};

ATTRIBUTE_PRINTF(2, 3)
static void tokenize_error(Tokenize *t, const char *format, ...) {
    t->state = TokenizeState_error;

    t->out->err_byte_offset = t->pos;

    va_list ap;
    va_start(ap, format);
    t->out->err = buf_vprintf(format, ap);
    va_end(ap);
}

static void begin_token(Tokenize *t, TokenId id) {
    t->out->ids.append(id);
    TokenLoc tok_loc;
    tok_loc.offset = (uint32_t) t->pos;
    tok_loc.line = t->line;
    tok_loc.column = t->column;
    t->out->locs.append(tok_loc);
}

static void cancel_token(Tokenize *t) {
    t->out->ids.pop();
    t->out->locs.pop();
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

static void invalid_eof(Tokenize *t) {
    return tokenize_error(t, "unexpected End-Of-File");
}

static void invalid_char_error(Tokenize *t, uint8_t c) {
    if (c == 0) {
        return invalid_eof(t);
    }

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

void tokenize(const char *source, Tokenization *out) {
    Tokenize t = {0};
    t.out = out;

    size_t remaining_code_units;
    size_t seen_escape_digits;

    // Skip the UTF-8 BOM if present.
    if (source[0] == (char)0xef &&
        source[1] == (char)0xbb &&
        source[2] == (char)0xbf)
    {
        t.pos += 3;
    }

    // Invalid token takes up index 0 so that index 0 can mean "none".
    begin_token(&t, TokenIdCount);

    for (;;) {
        uint8_t c = source[t.pos];
        switch (t.state) {
            case TokenizeState_error:
                goto eof;
            case TokenizeState_start:
                switch (c) {
                    case 0:
                        goto eof;
                    case WHITESPACE:
                        break;
                    case '"':
                        begin_token(&t, TokenIdStringLiteral);
                        t.state = TokenizeState_string_literal;
                        break;
                    case '\'':
                        begin_token(&t, TokenIdCharLiteral);
                        t.state = TokenizeState_char_literal;
                        break;
                    case ALPHA:
                    case '_':
                        t.state = TokenizeState_identifier;
                        begin_token(&t, TokenIdIdentifier);
                        break;
                    case '@':
                        begin_token(&t, TokenIdBuiltin);
                        t.state = TokenizeState_saw_at_sign;
                        break;
                    case '=':
                        begin_token(&t, TokenIdEq);
                        t.state = TokenizeState_equal;
                        break;
                    case '!':
                        begin_token(&t, TokenIdBang);
                        t.state = TokenizeState_bang;
                        break;
                    case '|':
                        begin_token(&t, TokenIdBinOr);
                        t.state = TokenizeState_pipe;
                        break;
                    case '(':
                        begin_token(&t, TokenIdLParen);
                        break;
                    case ')':
                        begin_token(&t, TokenIdRParen);
                        break;
                    case '[':
                        begin_token(&t, TokenIdLBracket);
                        break;
                    case ']':
                        begin_token(&t, TokenIdRBracket);
                        break;
                    case ';':
                        begin_token(&t, TokenIdSemicolon);
                        break;
                    case ',':
                        begin_token(&t, TokenIdComma);
                        break;
                    case '?':
                        begin_token(&t, TokenIdQuestion);
                        break;
                    case ':':
                        begin_token(&t, TokenIdColon);
                        break;
                    case '%':
                        begin_token(&t, TokenIdPercent);
                        t.state = TokenizeState_percent;
                        break;
                    case '*':
                        begin_token(&t, TokenIdStar);
                        t.state = TokenizeState_asterisk;
                        break;
                    case '+':
                        begin_token(&t, TokenIdPlus);
                        t.state = TokenizeState_plus;
                        break;
                    case '<':
                        begin_token(&t, TokenIdCmpLessThan);
                        t.state = TokenizeState_angle_bracket_left;
                        break;
                    case '>':
                        begin_token(&t, TokenIdCmpGreaterThan);
                        t.state = TokenizeState_angle_bracket_right;
                        break;
                    case '^':
                        begin_token(&t, TokenIdBinXor);
                        t.state = TokenizeState_caret;
                        break;
                    case '\\':
                        begin_token(&t, TokenIdMultilineStringLiteralLine);
                        t.state = TokenizeState_backslash;
                        break;
                    case '{':
                        begin_token(&t, TokenIdLBrace);
                        break;
                    case '}':
                        begin_token(&t, TokenIdRBrace);
                        break;
                    case '~':
                        begin_token(&t, TokenIdTilde);
                        break;
                    case '.':
                        begin_token(&t, TokenIdDot);
                        t.state = TokenizeState_period;
                        break;
                    case '-':
                        begin_token(&t, TokenIdDash);
                        t.state = TokenizeState_minus;
                        break;
                    case '/':
                        begin_token(&t, TokenIdSlash);
                        t.state = TokenizeState_slash;
                        break;
                    case '&':
                        begin_token(&t, TokenIdAmpersand);
                        t.state = TokenizeState_ampersand;
                        break;
                    case '0':
                        t.state = TokenizeState_zero;
                        begin_token(&t, TokenIdIntLiteral);
                        break;
                    case DIGIT_NON_ZERO:
                        t.state = TokenizeState_int_literal_dec;
                        begin_token(&t, TokenIdIntLiteral);
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_saw_at_sign:
                switch (c) {
                    case 0:
                        invalid_eof(&t);
                        goto eof;
                    case '"':
                        t.out->ids.last() = TokenIdIdentifier;
                        t.state = TokenizeState_string_literal;
                        break;
                    case IDENTIFIER_CHAR:
                        t.state = TokenizeState_builtin;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_ampersand:
                switch (c) {
                    case 0:
                        goto eof;
                    case '&':
                        tokenize_error(&t, "`&&` is invalid. Note that `and` is boolean AND");
                        break;
                    case '=':
                        t.out->ids.last() = TokenIdBitAndEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_asterisk:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdTimesEq;
                        t.state = TokenizeState_start;
                        break;
                    case '*':
                        t.out->ids.last() = TokenIdStarStar;
                        t.state = TokenizeState_start;
                        break;
                    case '%':
                        t.state = TokenizeState_asterisk_percent;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_asterisk_percent:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdTimesPercent;
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdTimesPercentEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.out->ids.last() = TokenIdTimesPercent;
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_percent:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdModEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_plus:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdPlusEq;
                        t.state = TokenizeState_start;
                        break;
                    case '+':
                        t.out->ids.last() = TokenIdPlusPlus;
                        t.state = TokenizeState_start;
                        break;
                    case '%':
                        t.state = TokenizeState_plus_percent;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_plus_percent:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdPlusPercent;
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdPlusPercentEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.out->ids.last() = TokenIdPlusPercent;
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_caret:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdBitXorEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_identifier:
                switch (c) {
                    case 0: {
                        uint32_t start_pos = t.out->locs.last().offset;
                        t.out->ids.last() = zig_keyword_token(
                                source + start_pos, t.pos - start_pos);
                        goto eof;
                    }
                    case IDENTIFIER_CHAR:
                        break;
                    default: {
                        uint32_t start_pos = t.out->locs.last().offset;
                        t.out->ids.last() = zig_keyword_token(
                                source + start_pos, t.pos - start_pos);

                        t.state = TokenizeState_start;
                        continue;
                    }
                }
                break;
            case TokenizeState_builtin:
                switch (c) {
                    case 0:
                        goto eof;
                    case IDENTIFIER_CHAR:
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_backslash:
                switch (c) {
                    case '\\':
                        t.state = TokenizeState_multiline_string_literal_line;
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeState_string_literal:
                switch (c) {
                    case 0:
                        invalid_eof(&t);
                        goto eof;
                    case '\\':
                        t.state = TokenizeState_string_literal_backslash;
                        break;
                    case '"':
                        t.state = TokenizeState_start;
                        break;
                    case '\n':
                    case '\r':
                        tokenize_error(&t, "newline not allowed in string literal");
                        break;
                    default:
                        break;
                }
                break;
            case TokenizeState_string_literal_backslash:
                switch (c) {
                    case 0:
                        invalid_eof(&t);
                        goto eof;
                    case '\n':
                    case '\r':
                        tokenize_error(&t, "newline not allowed in string literal");
                        break;
                    default:
                        t.state = TokenizeState_string_literal;
                        break;
                }
                break;
            case TokenizeState_char_literal:
                if (c == 0) {
                    invalid_eof(&t);
                    goto eof;
                } else if (c == '\\') {
                    t.state = TokenizeState_char_literal_backslash;
                } else if (c == '\'') {
                    tokenize_error(&t, "expected character");
                } else if ((c >= 0x80 && c <= 0xbf) || c >= 0xf8) {
                    // 10xxxxxx
                    // 11111xxx
                    invalid_char_error(&t, c);
                } else if (c >= 0xc0 && c <= 0xdf) {
                    // 110xxxxx
                    remaining_code_units = 1;
                    t.state = TokenizeState_char_literal_unicode;
                } else if (c >= 0xe0 && c <= 0xef) {
                    // 1110xxxx
                    remaining_code_units = 2;
                    t.state = TokenizeState_char_literal_unicode;
                } else if (c >= 0xf0 && c <= 0xf7) {
                    // 11110xxx
                    remaining_code_units = 3;
                    t.state = TokenizeState_char_literal_unicode;
                } else {
                    t.state = TokenizeState_char_literal_end;
                }
                break;
            case TokenizeState_char_literal_backslash:
                switch (c) {
                    case 0:
                        invalid_eof(&t);
                        goto eof;
                    case '\n':
                    case '\r':
                        tokenize_error(&t, "newline not allowed in character literal");
                        break;
                    case 'x':
                        t.state = TokenizeState_char_literal_hex_escape;
                        seen_escape_digits = 0;
                        break;
                    case 'u':
                        t.state = TokenizeState_char_literal_unicode_escape_saw_u;
                        break;
                    case 'U':
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_char_literal_end;
                        break;
                }
                break;
            case TokenizeState_char_literal_hex_escape:
                switch (c) {
                    case ALPHA:
                    case DIGIT:
                        seen_escape_digits += 1;
                        if (seen_escape_digits == 2) {
                            t.state = TokenizeState_char_literal_end;
                        }
                        break;
                    default:
                        tokenize_error(&t, "expected hex digit");
                        break;
                }
                break;
            case TokenizeState_char_literal_unicode_escape_saw_u:
                switch (c) {
                    case '{':
                        t.state = TokenizeState_char_literal_unicode_escape;
                        seen_escape_digits = 0;
                        break;
                    default:
                        tokenize_error(&t, "expected '{' to begin unicode escape sequence");
                        break;
                }
                break;
            case TokenizeState_char_literal_unicode_escape:
                switch (c) {
                    case ALPHA:
                    case DIGIT:
                        seen_escape_digits += 1;
                        break;
                    case '}':
                        if (seen_escape_digits == 0) {
                            tokenize_error(&t, "empty unicode escape sequence");
                            break;
                        }
                        t.state = TokenizeState_char_literal_end;
                        break;
                    default:
                        tokenize_error(&t, "expected hex digit");
                        break;
                }
                break;
            case TokenizeState_char_literal_end:
                switch (c) {
                    case '\'':
                        t.state = TokenizeState_start;
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeState_char_literal_unicode:
                if (c >= 0x80 && c <= 0xbf) {
                    remaining_code_units -= 1;
                    if (remaining_code_units == 0) {
                        t.state = TokenizeState_char_literal_end;
                    }
                } else {
                    invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_multiline_string_literal_line:
                switch (c) {
                    case 0:
                        goto eof;
                    case '\n':
                        t.state = TokenizeState_start;
                        break;
                    default:
                        break;
                }
                break;
            case TokenizeState_bang:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdCmpNotEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_pipe:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdBitOrEq;
                        t.state = TokenizeState_start;
                        break;
                    case '|':
                        t.out->ids.last() = TokenIdBarBar;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_equal:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdCmpEq;
                        t.state = TokenizeState_start;
                        break;
                    case '>':
                        t.out->ids.last() = TokenIdFatArrow;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_minus:
                switch (c) {
                    case 0:
                        goto eof;
                    case '>':
                        t.out->ids.last() = TokenIdArrow;
                        t.state = TokenizeState_start;
                        break;
                    case '=':
                        t.out->ids.last() = TokenIdMinusEq;
                        t.state = TokenizeState_start;
                        break;
                    case '%':
                        t.state = TokenizeState_minus_percent;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_minus_percent:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdMinusPercent;
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdMinusPercentEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.out->ids.last() = TokenIdMinusPercent;
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_angle_bracket_left:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdCmpLessOrEq;
                        t.state = TokenizeState_start;
                        break;
                    case '<':
                        t.state = TokenizeState_angle_bracket_angle_bracket_left;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_angle_bracket_angle_bracket_left:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdBitShiftLeft;
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdBitShiftLeftEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.out->ids.last() = TokenIdBitShiftLeft;
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_angle_bracket_right:
                switch (c) {
                    case 0:
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdCmpGreaterOrEq;
                        t.state = TokenizeState_start;
                        break;
                    case '>':
                        t.state = TokenizeState_angle_bracket_angle_bracket_right;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_angle_bracket_angle_bracket_right:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdBitShiftRight;
                        goto eof;
                    case '=':
                        t.out->ids.last() = TokenIdBitShiftRightEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.out->ids.last() = TokenIdBitShiftRight;
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_period:
                switch (c) {
                    case 0:
                        goto eof;
                    case '.':
                        t.state = TokenizeState_period_2;
                        break;
                    case '*':
                        t.state = TokenizeState_period_asterisk;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_period_2:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdEllipsis2;
                        goto eof;
                    case '.':
                        t.out->ids.last() = TokenIdEllipsis3;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.out->ids.last() = TokenIdEllipsis2;
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_period_asterisk:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdDotStar;
                        goto eof;
                    case '*':
                        tokenize_error(&t, "`.*` cannot be followed by `*`. Are you missing a space?");
                        break;
                    default:
                        t.out->ids.last() = TokenIdDotStar;
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_slash:
                switch (c) {
                    case 0:
                        goto eof;
                    case '/':
                        t.state = TokenizeState_line_comment_start;
                        break;
                    case '=':
                        t.out->ids.last() = TokenIdDivEq;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_line_comment_start:
                switch (c) {
                    case 0:
                        goto eof;
                    case '/':
                        t.state = TokenizeState_doc_comment_start;
                        break;
                    case '!':
                        t.out->ids.last() = TokenIdContainerDocComment;
                        t.state = TokenizeState_container_doc_comment;
                        break;
                    case '\n':
                        cancel_token(&t);
                        t.state = TokenizeState_start;
                        break;
                    default:
                        cancel_token(&t);
                        t.state = TokenizeState_line_comment;
                        break;
                }
                break;
            case TokenizeState_doc_comment_start:
                switch (c) {
                    case 0:
                        t.out->ids.last() = TokenIdDocComment;
                        goto eof;
                    case '/':
                        cancel_token(&t);
                        t.state = TokenizeState_line_comment;
                        break;
                    case '\n':
                        t.out->ids.last() = TokenIdDocComment;
                        t.state = TokenizeState_start;
                        break;
                    default:
                        t.out->ids.last() = TokenIdDocComment;
                        t.state = TokenizeState_doc_comment;
                        break;
                }
                break;
            case TokenizeState_line_comment:
                switch (c) {
                    case 0:
                        goto eof;
                    case '\n':
                        t.state = TokenizeState_start;
                        break;
                    default:
                        break;
                }
                break;
            case TokenizeState_doc_comment:
            case TokenizeState_container_doc_comment:
                switch (c) {
                    case 0:
                        goto eof;
                    case '\n':
                        t.state = TokenizeState_start;
                        break;
                    default:
                        // do nothing
                        break;
                }
                break;
            case TokenizeState_zero:
                switch (c) {
                    case 0:
                        goto eof;
                    case 'b':
                        t.state = TokenizeState_int_literal_bin_no_underscore;
                        break;
                    case 'o':
                        t.state = TokenizeState_int_literal_oct_no_underscore;
                        break;
                    case 'x':
                        t.state = TokenizeState_int_literal_hex_no_underscore;
                        break;
                    case DIGIT:
                    case '_':
                    case '.':
                    case 'e':
                    case 'E':
                        // Reinterpret as a decimal number.
                        t.state = TokenizeState_int_literal_dec;
                        continue;
                    case ALPHA_EXCEPT_E_B_O_X:
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_int_literal_bin_no_underscore:
                switch (c) {
                    case '0':
                    case '1':
                        t.state = TokenizeState_int_literal_bin;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_int_literal_bin:
                switch (c) {
                    case 0:
                        goto eof;
                    case '_':
                        t.state = TokenizeState_int_literal_bin_no_underscore;
                        break;
                    case '0':
                    case '1':
                        break;
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                    case '8':
                    case '9':
                    case ALPHA:
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_int_literal_oct_no_underscore:
                switch (c) {
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                        t.state = TokenizeState_int_literal_oct;
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeState_int_literal_oct:
                switch (c) {
                    case 0:
                        goto eof;
                    case '_':
                        t.state = TokenizeState_int_literal_oct_no_underscore;
                        break;
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                        break;
                    case ALPHA:
                    case '8':
                    case '9':
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_int_literal_dec_no_underscore:
                switch (c) {
                    case DIGIT:
                        t.state = TokenizeState_int_literal_dec;
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeState_int_literal_dec:
                switch (c) {
                    case 0:
                        goto eof;
                    case '_':
                        t.state = TokenizeState_int_literal_dec_no_underscore;
                        break;
                    case '.':
                        t.state = TokenizeState_num_dot_dec;
                        t.out->ids.last() = TokenIdFloatLiteral;
                        break;
                    case 'e':
                    case 'E':
                        t.state = TokenizeState_float_exponent_unsigned;
                        t.out->ids.last() = TokenIdFloatLiteral;
                        break;
                    case DIGIT:
                        break;
                    case ALPHA_EXCEPT_E:
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_int_literal_hex_no_underscore:
                switch (c) {
                    case HEXDIGIT:
                        t.state = TokenizeState_int_literal_hex;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_int_literal_hex:
                switch (c) {
                    case 0:
                        goto eof;
                    case '_':
                        t.state = TokenizeState_int_literal_hex_no_underscore;
                        break;
                    case '.':
                        t.state = TokenizeState_num_dot_hex;
                        t.out->ids.last() = TokenIdFloatLiteral;
                        break;
                    case 'p':
                    case 'P':
                        t.state = TokenizeState_float_exponent_unsigned;
                        t.out->ids.last() = TokenIdFloatLiteral;
                        break;
                    case HEXDIGIT:
                        break;
                    case ALPHA_EXCEPT_HEX_AND_P:
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_num_dot_dec:
                switch (c) {
                    case 0:
                        goto eof;
                    case '.':
                        t.out->ids.last() = TokenIdIntLiteral;
                        t.pos -= 1;
                        t.column -= 1;
                        t.state = TokenizeState_start;
                        continue;
                    case DIGIT:
                        t.state = TokenizeState_float_fraction_dec;
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeState_num_dot_hex:
                switch (c) {
                    case 0:
                        goto eof;
                    case '.':
                        t.out->ids.last() = TokenIdIntLiteral;
                        t.pos -= 1;
                        t.column -= 1;
                        t.state = TokenizeState_start;
                        continue;
                    case HEXDIGIT:
                        t.out->ids.last() = TokenIdFloatLiteral;
                        t.state = TokenizeState_float_fraction_hex;
                        break;
                    default:
                        invalid_char_error(&t, c);
                        break;
                }
                break;
            case TokenizeState_float_fraction_dec_no_underscore:
                switch (c) {
                    case DIGIT:
                        t.state = TokenizeState_float_fraction_dec;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_float_fraction_dec:
                switch (c) {
                    case 0:
                        goto eof;
                    case '_':
                        t.state = TokenizeState_float_fraction_dec_no_underscore;
                        break;
                    case 'e':
                    case 'E':
                        t.state = TokenizeState_float_exponent_unsigned;
                        break;
                    case DIGIT:
                        break;
                    case ALPHA_EXCEPT_E:
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_float_fraction_hex_no_underscore:
                switch (c) {
                    case HEXDIGIT:
                        t.state = TokenizeState_float_fraction_hex;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_float_fraction_hex:
                switch (c) {
                    case 0:
                        goto eof;
                    case '_':
                        t.state = TokenizeState_float_fraction_hex_no_underscore;
                        break;
                    case 'p':
                    case 'P':
                        t.state = TokenizeState_float_exponent_unsigned;
                        break;
                    case HEXDIGIT:
                        break;
                    case ALPHA_EXCEPT_HEX_AND_P:
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
            case TokenizeState_float_exponent_unsigned:
                switch (c) {
                    case '+':
                    case '-':
                        t.state = TokenizeState_float_exponent_num_no_underscore;
                        break;
                    default:
                        // Reinterpret as a normal exponent number.
                        t.state = TokenizeState_float_exponent_num_no_underscore;
                        continue;
                }
                break;
            case TokenizeState_float_exponent_num_no_underscore:
                switch (c) {
                    case DIGIT:
                        t.state = TokenizeState_float_exponent_num;
                        break;
                    default:
                        invalid_char_error(&t, c);
                }
                break;
            case TokenizeState_float_exponent_num:
                switch (c) {
                    case 0:
                        goto eof;
                    case '_':
                        t.state = TokenizeState_float_exponent_num_no_underscore;
                        break;
                    case DIGIT:
                        break;
                    case ALPHA:
                        invalid_char_error(&t, c);
                        break;
                    default:
                        t.state = TokenizeState_start;
                        continue;
                }
                break;
        }
        t.pos += 1;
        if (c == '\n') {
            t.line += 1;
            t.column = 0;
        } else {
            t.column += 1;
        }
    }
eof:;

    begin_token(&t, TokenIdEof);
}

const char * token_name(TokenId id) {
    switch (id) {
        case TokenIdAmpersand: return "&";
        case TokenIdArrow: return "->";
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
        case TokenIdPercent: return "%";
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
        case TokenIdMultilineStringLiteralLine: return "MultilineStringLiteralLine";
        case TokenIdIdentifier: return "Identifier";
        case TokenIdTilde: return "~";
        case TokenIdTimesEq: return "*=";
        case TokenIdTimesPercent: return "*%";
        case TokenIdTimesPercentEq: return "*%=";
        case TokenIdBuiltin: return "Builtin";
        case TokenIdCount:
            zig_unreachable();
    }
    return "(invalid token)";
}
