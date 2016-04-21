/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "c_tokenizer.hpp"
#include <inttypes.h>

#define WHITESPACE_EXCEPT_N \
         ' ': \
    case '\t': \
    case '\v': \
    case '\f'

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

#define IDENT_START \
    ALPHA: \
    case '_'

#define IDENT \
    IDENT_START: \
    case DIGIT


static void begin_token(CTokenize *ctok, CTokId id) {
    assert(ctok->cur_tok == nullptr);
    ctok->tokens.add_one();
    ctok->cur_tok = &ctok->tokens.last();
    ctok->cur_tok->id = id;

    switch (id) {
        case CTokIdStrLit:
            memset(&ctok->cur_tok->data.str_lit, 0, sizeof(Buf));
            buf_resize(&ctok->cur_tok->data.str_lit, 0);
            break;
        case CTokIdSymbol:
            memset(&ctok->cur_tok->data.symbol, 0, sizeof(Buf));
            buf_resize(&ctok->cur_tok->data.symbol, 0);
            break;
        case CTokIdCharLit:
        case CTokIdNumLitInt:
        case CTokIdNumLitFloat:
        case CTokIdMinus:
            break;
    }
}

static void end_token(CTokenize *ctok) {
    ctok->cur_tok = nullptr;
}

static void mark_error(CTokenize *ctok) {
    ctok->error = true;
}

static void add_char(CTokenize *ctok, uint8_t c) {
    assert(ctok->cur_tok);
    if (ctok->cur_tok->id == CTokIdCharLit) {
        ctok->cur_tok->data.char_lit = c;
        ctok->state = CTokStateExpectEndQuot;
    } else if (ctok->cur_tok->id == CTokIdStrLit) {
        buf_append_char(&ctok->cur_tok->data.str_lit, c);
        ctok->state = CTokStateString;
    } else {
        zig_unreachable();
    }
}

static void hex_digit(CTokenize *ctok, uint8_t value) {
    // TODO @mul_with_overflow
    ctok->cur_tok->data.num_lit_int *= 16;
    // TODO @add_with_overflow
    ctok->cur_tok->data.num_lit_int += value;

    static const uint8_t hex_digit[] = "0123456789abcdef";
    buf_append_char(&ctok->buf, hex_digit[value]);
}

static void end_float(CTokenize *ctok) {
    // TODO detect errors, overflow, and underflow
    double value = strtod(buf_ptr(&ctok->buf), nullptr);

    ctok->cur_tok->data.num_lit_float = value;

    end_token(ctok);
    ctok->state = CTokStateStart;

}

void tokenize_c_macro(CTokenize *ctok, const uint8_t *c) {
    ctok->tokens.resize(0);
    ctok->state = CTokStateStart;
    ctok->error = false;
    ctok->cur_tok = nullptr;

    buf_resize(&ctok->buf, 0);

    for (; *c; c += 1) {
        switch (ctok->state) {
            case CTokStateStart:
                switch (*c) {
                    case WHITESPACE_EXCEPT_N:
                        break;
                    case '\'':
                        ctok->state = CTokStateExpectChar;
                        begin_token(ctok, CTokIdCharLit);
                        break;
                    case '\"':
                        ctok->state = CTokStateString;
                        begin_token(ctok, CTokIdStrLit);
                        break;
                    case '/':
                        ctok->state = CTokStateOpenComment;
                        break;
                    case '\\':
                        ctok->state = CTokStateBackslash;
                        break;
                    case '\n':
                        goto found_end_of_macro;
                    case IDENT_START:
                        ctok->state = CTokStateIdentifier;
                        begin_token(ctok, CTokIdSymbol);
                        buf_append_char(&ctok->cur_tok->data.symbol, *c);
                        break;
                    case DIGIT_NON_ZERO:
                        ctok->state = CTokStateDecimal;
                        ctok->unsigned_suffix = false;
                        ctok->long_suffix = false;
                        begin_token(ctok, CTokIdNumLitInt);
                        ctok->cur_tok->data.num_lit_int = *c - '0';
                        buf_resize(&ctok->buf, 0);
                        buf_append_char(&ctok->buf, *c);
                        break;
                    case '0':
                        ctok->state = CTokStateGotZero;
                        ctok->unsigned_suffix = false;
                        ctok->long_suffix = false;
                        begin_token(ctok, CTokIdNumLitInt);
                        ctok->cur_tok->data.num_lit_int = 0;
                        buf_resize(&ctok->buf, 0);
                        buf_append_char(&ctok->buf, '0');
                        break;
                    case '.':
                        begin_token(ctok, CTokIdNumLitFloat);
                        ctok->state = CTokStateFloat;
                        buf_init_from_str(&ctok->buf, "0.");
                        break;
                    default:
                        return mark_error(ctok);
                }
                break;
            case CTokStateFloat:
                switch (*c) {
                    case 'e':
                    case 'E':
                        buf_append_char(&ctok->buf, 'e');
                        ctok->state = CTokStateExpSign;
                        break;
                    case 'f':
                    case 'F':
                    case 'l':
                    case 'L':
                        end_float(ctok);
                        break;
                    case DIGIT:
                        buf_append_char(&ctok->buf, *c);
                        break;
                    default:
                        c -= 1;
                        end_float(ctok);
                        continue;
                }
                break;
            case CTokStateExpSign:
                switch (*c) {
                    case '+':
                    case '-':
                        ctok->state = CTokStateFloatExpFirst;
                        buf_append_char(&ctok->buf, *c);
                        break;
                    case DIGIT:
                        ctok->state = CTokStateFloatExp;
                        buf_append_char(&ctok->buf, *c);
                        break;
                    default:
                        return mark_error(ctok);
                }
                break;
            case CTokStateFloatExpFirst:
                switch (*c) {
                    case DIGIT:
                        buf_append_char(&ctok->buf, *c);
                        ctok->state = CTokStateFloatExp;
                        break;
                    default:
                        return mark_error(ctok);
                }
                break;
            case CTokStateFloatExp:
                switch (*c) {
                    case DIGIT:
                        buf_append_char(&ctok->buf, *c);
                        break;
                    case 'f':
                    case 'F':
                    case 'l':
                    case 'L':
                        end_float(ctok);
                        break;
                    default:
                        c -= 1;
                        end_float(ctok);
                        continue;
                }
                break;
            case CTokStateDecimal:
                switch (*c) {
                    case DIGIT:
                        buf_append_char(&ctok->buf, *c);

                        // TODO @mul_with_overflow
                        ctok->cur_tok->data.num_lit_int *= 10;
                        // TODO @add_with_overflow
                        ctok->cur_tok->data.num_lit_int += *c - '0';
                        break;
                    case '\'':
                        break;
                    case 'u':
                    case 'U':
                        ctok->unsigned_suffix = true;
                        ctok->state = CTokStateIntSuffix;
                        break;
                    case 'l':
                    case 'L':
                        ctok->long_suffix = true;
                        ctok->state = CTokStateIntSuffixLong;
                        break;
                    case '.':
                        buf_append_char(&ctok->buf, '.');
                        ctok->cur_tok->id = CTokIdNumLitFloat;
                        ctok->state = CTokStateFloat;
                        break;
                    default:
                        c -= 1;
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        continue;
                }
                break;
            case CTokStateIntSuffix:
                switch (*c) {
                    case 'l':
                    case 'L':
                        if (ctok->long_suffix) {
                            return mark_error(ctok);
                        }
                        ctok->long_suffix = true;
                        ctok->state = CTokStateIntSuffixLong;
                        break;
                    case 'u':
                    case 'U':
                        if (ctok->unsigned_suffix) {
                            return mark_error(ctok);
                        }
                        ctok->unsigned_suffix = true;
                        break;
                    default:
                        c -= 1;
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        continue;
                }
                break;
            case CTokStateIntSuffixLong:
                switch (*c) {
                    case 'l':
                    case 'L':
                        ctok->state = CTokStateIntSuffix;
                        break;
                    case 'u':
                    case 'U':
                        if (ctok->unsigned_suffix) {
                            return mark_error(ctok);
                        }
                        ctok->unsigned_suffix = true;
                        break;
                    default:
                        c -= 1;
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        continue;
                }
                break;
            case CTokStateGotZero:
                switch (*c) {
                    case 'x':
                    case 'X':
                        ctok->state = CTokStateHex;
                        break;
                    case '.':
                        ctok->state = CTokStateFloat;
                        ctok->cur_tok->id = CTokIdNumLitFloat;
                        buf_append_char(&ctok->buf, '.');
                        break;
                    default:
                        c -= 1;
                        ctok->state = CTokStateOctal;
                        continue;
                }
                break;
            case CTokStateOctal:
                switch (*c) {
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                        // TODO @mul_with_overflow
                        ctok->cur_tok->data.num_lit_int *= 8;
                        // TODO @add_with_overflow
                        ctok->cur_tok->data.num_lit_int += *c - '0';
                        break;
                    case '8':
                    case '9':
                        return mark_error(ctok);
                    case '\'':
                        break;
                    default:
                        c -= 1;
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        continue;
                }
                break;
            case CTokStateHex:
                switch (*c) {
                    case '0':
                        hex_digit(ctok, 0);
                        break;
                    case '1':
                        hex_digit(ctok, 1);
                        break;
                    case '2':
                        hex_digit(ctok, 2);
                        break;
                    case '3':
                        hex_digit(ctok, 3);
                        break;
                    case '4':
                        hex_digit(ctok, 4);
                        break;
                    case '5':
                        hex_digit(ctok, 5);
                        break;
                    case '6':
                        hex_digit(ctok, 6);
                        break;
                    case '7':
                        hex_digit(ctok, 7);
                        break;
                    case '8':
                        hex_digit(ctok, 8);
                        break;
                    case '9':
                        hex_digit(ctok, 9);
                        break;
                    case 'a':
                    case 'A':
                        hex_digit(ctok, 10);
                        break;
                    case 'b':
                    case 'B':
                        hex_digit(ctok, 11);
                        break;
                    case 'c':
                    case 'C':
                        hex_digit(ctok, 12);
                        break;
                    case 'd':
                    case 'D':
                        hex_digit(ctok, 13);
                        break;
                    case 'e':
                    case 'E':
                        hex_digit(ctok, 14);
                        break;
                    case 'f':
                    case 'F':
                        hex_digit(ctok, 15);
                        break;
                    case 'p':
                    case 'P':
                        ctok->cur_tok->id = CTokIdNumLitFloat;
                        ctok->state = CTokStateExpSign;
                        break;
                    default:
                        c -= 1;
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        continue;
                }
                break;
            case CTokStateIdentifier:
                switch (*c) {
                    case IDENT:
                        buf_append_char(&ctok->cur_tok->data.symbol, *c);
                        break;
                    default:
                        c -= 1;
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        continue;
                }
                break;
            case CTokStateString:
                switch (*c) {
                    case '\\':
                        ctok->state = CTokStateCharEscape;
                        break;
                    case '\"':
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        break;
                    default:
                        buf_append_char(&ctok->cur_tok->data.str_lit, *c);
                }
                break;
            case CTokStateExpectChar:
                switch (*c) {
                    case '\\':
                        ctok->state = CTokStateCharEscape;
                        break;
                    case '\'':
                        return mark_error(ctok);
                    default:
                        ctok->cur_tok->data.char_lit = *c;
                        ctok->state = CTokStateExpectEndQuot;
                }
                break;
            case CTokStateCharEscape:
                switch (*c) {
                    case '\'':
                    case '"':
                    case '?':
                    case '\\':
                        add_char(ctok, *c);
                        break;
                    case 'a':
                        add_char(ctok, '\a');
                        break;
                    case 'b':
                        add_char(ctok, '\b');
                        break;
                    case 'f':
                        add_char(ctok, '\f');
                        break;
                    case 'n':
                        add_char(ctok, '\n');
                        break;
                    case 'r':
                        add_char(ctok, '\r');
                        break;
                    case 't':
                        add_char(ctok, '\t');
                        break;
                    case 'v':
                        add_char(ctok, '\v');
                        break;
                    case DIGIT:
                        zig_panic("TODO octal");
                        break;
                    case 'x':
                        zig_panic("TODO hex");
                        break;
                    case 'u':
                        zig_panic("TODO unicode");
                        break;
                    case 'U':
                        zig_panic("TODO Unicode");
                        break;
                    default:
                        return mark_error(ctok);
                }
                break;
            case CTokStateExpectEndQuot:
                switch (*c) {
                    case '\'':
                        end_token(ctok);
                        ctok->state = CTokStateStart;
                        break;
                    default:
                        return mark_error(ctok);
                }
                break;
            case CTokStateOpenComment:
                switch (*c) {
                    case '/':
                        ctok->state = CTokStateLineComment;
                        break;
                    case '*':
                        ctok->state = CTokStateComment;
                        break;
                    default:
                        return mark_error(ctok);
                }
                break;
            case CTokStateLineComment:
                if (*c == '\n') {
                    ctok->state = CTokStateStart;
                    goto found_end_of_macro;
                }
                break;
            case CTokStateComment:
                switch (*c) {
                    case '*':
                        ctok->state = CTokStateCommentStar;
                        break;
                    default:
                        break;
                }
                break;
            case CTokStateCommentStar:
                switch (*c) {
                    case '/':
                        ctok->state = CTokStateStart;
                        break;
                    case '*':
                        break;
                    default:
                        ctok->state = CTokStateComment;
                        break;
                }
                break;
            case CTokStateBackslash:
                switch (*c) {
                    case '\n':
                        ctok->state = CTokStateStart;
                        break;
                    default:
                        return mark_error(ctok);
                }
                break;
        }
    }
found_end_of_macro:

    switch (ctok->state) {
        case CTokStateStart:
            break;
        case CTokStateIdentifier:
        case CTokStateDecimal:
        case CTokStateHex:
        case CTokStateOctal:
        case CTokStateGotZero:
        case CTokStateIntSuffix:
        case CTokStateIntSuffixLong:
            end_token(ctok);
            break;
        case CTokStateFloat:
        case CTokStateFloatExp:
            end_float(ctok);
            break;
        case CTokStateExpectChar:
        case CTokStateExpectEndQuot:
        case CTokStateOpenComment:
        case CTokStateLineComment:
        case CTokStateComment:
        case CTokStateCommentStar:
        case CTokStateCharEscape:
        case CTokStateBackslash:
        case CTokStateString:
        case CTokStateExpSign:
        case CTokStateFloatExpFirst:
            return mark_error(ctok);
    }

    assert(ctok->cur_tok == nullptr);
}
