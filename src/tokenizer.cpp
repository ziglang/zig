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
    ALPHA: \
    case DIGIT: \
    case '_'

#define SYMBOL_START \
    ALPHA: \
    case '_'

const char * zig_keywords[] = {
    "true", "false", "null", "fn", "return", "var", "const", "extern",
    "pub", "export", "use", "if", "else", "goto", "asm",
    "volatile", "struct", "enum", "while", "for", "continue", "break",
    "null", "noalias", "switch", "undefined", "error", "type", "inline",
    "defer",
};

bool is_zig_keyword(Buf *buf) {
    for (int i = 0; i < array_length(zig_keywords); i += 1) {
        if (buf_eql_str(buf, zig_keywords[i])) {
            return true;
        }
    }
    return false;
}

enum TokenizeState {
    TokenizeStateStart,
    TokenizeStateSymbol,
    TokenizeStateSymbolFirst,
    TokenizeStateZero, // "0", which might lead to "0x"
    TokenizeStateNumber, // "123", "0x123"
    TokenizeStateFloatFraction, // "123.456", "0x123.456"
    TokenizeStateFloatExponentUnsigned, // "123.456e", "123e", "0x123p"
    TokenizeStateFloatExponentNumber, // "123.456e-", "123.456e5", "123.456e5e-5"
    TokenizeStateString,
    TokenizeStateCharLiteral,
    TokenizeStateSawStar,
    TokenizeStateSawSlash,
    TokenizeStateSawPercent,
    TokenizeStateSawPlus,
    TokenizeStateSawDash,
    TokenizeStateSawAmpersand,
    TokenizeStateSawAmpersandAmpersand,
    TokenizeStateSawCaret,
    TokenizeStateSawPipe,
    TokenizeStateSawPipePipe,
    TokenizeStateLineComment,
    TokenizeStateMultiLineComment,
    TokenizeStateMultiLineCommentSlash,
    TokenizeStateMultiLineCommentStar,
    TokenizeStateSawEq,
    TokenizeStateSawBang,
    TokenizeStateSawLessThan,
    TokenizeStateSawLessThanLessThan,
    TokenizeStateSawGreaterThan,
    TokenizeStateSawGreaterThanGreaterThan,
    TokenizeStateSawDot,
    TokenizeStateSawDotDot,
    TokenizeStateSawQuestionMark,
    TokenizeStateError,
};


struct Tokenize {
    Buf *buf;
    int pos;
    TokenizeState state;
    ZigList<Token> *tokens;
    int line;
    int column;
    Token *cur_tok;
    int multi_line_comment_count;
    Tokenization *out;
};

__attribute__ ((format (printf, 2, 3)))
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

static void begin_token(Tokenize *t, TokenId id) {
    assert(!t->cur_tok);
    t->tokens->add_one();
    Token *token = &t->tokens->last();
    token->start_line = t->line;
    token->start_column = t->column;
    token->id = id;
    token->start_pos = t->pos;
    token->radix = 0;
    token->decimal_point_pos = 0;
    token->exponent_marker_pos = 0;
    t->cur_tok = token;
}

static void cancel_token(Tokenize *t) {
    t->tokens->pop();
    t->cur_tok = nullptr;
}

static void end_token(Tokenize *t) {
    assert(t->cur_tok);
    t->cur_tok->end_pos = t->pos + 1;

    // normalize number literal parsing stuff
    if (t->cur_tok->id == TokenIdNumberLiteral) {
        if (t->cur_tok->exponent_marker_pos == 0) {
            t->cur_tok->exponent_marker_pos = t->cur_tok->end_pos;
        }
        if (t->cur_tok->decimal_point_pos == 0) {
            t->cur_tok->decimal_point_pos = t->cur_tok->exponent_marker_pos;
        }
    }

    char *token_mem = buf_ptr(t->buf) + t->cur_tok->start_pos;
    int token_len = t->cur_tok->end_pos - t->cur_tok->start_pos;

    if (mem_eql_str(token_mem, token_len, "fn")) {
        t->cur_tok->id = TokenIdKeywordFn;
    } else if (mem_eql_str(token_mem, token_len, "return")) {
        t->cur_tok->id = TokenIdKeywordReturn;
    } else if (mem_eql_str(token_mem, token_len, "var")) {
        t->cur_tok->id = TokenIdKeywordVar;
    } else if (mem_eql_str(token_mem, token_len, "const")) {
        t->cur_tok->id = TokenIdKeywordConst;
    } else if (mem_eql_str(token_mem, token_len, "extern")) {
        t->cur_tok->id = TokenIdKeywordExtern;
    } else if (mem_eql_str(token_mem, token_len, "pub")) {
        t->cur_tok->id = TokenIdKeywordPub;
    } else if (mem_eql_str(token_mem, token_len, "export")) {
        t->cur_tok->id = TokenIdKeywordExport;
    } else if (mem_eql_str(token_mem, token_len, "use")) {
        t->cur_tok->id = TokenIdKeywordUse;
    } else if (mem_eql_str(token_mem, token_len, "true")) {
        t->cur_tok->id = TokenIdKeywordTrue;
    } else if (mem_eql_str(token_mem, token_len, "false")) {
        t->cur_tok->id = TokenIdKeywordFalse;
    } else if (mem_eql_str(token_mem, token_len, "if")) {
        t->cur_tok->id = TokenIdKeywordIf;
    } else if (mem_eql_str(token_mem, token_len, "else")) {
        t->cur_tok->id = TokenIdKeywordElse;
    } else if (mem_eql_str(token_mem, token_len, "goto")) {
        t->cur_tok->id = TokenIdKeywordGoto;
    } else if (mem_eql_str(token_mem, token_len, "volatile")) {
        t->cur_tok->id = TokenIdKeywordVolatile;
    } else if (mem_eql_str(token_mem, token_len, "asm")) {
        t->cur_tok->id = TokenIdKeywordAsm;
    } else if (mem_eql_str(token_mem, token_len, "struct")) {
        t->cur_tok->id = TokenIdKeywordStruct;
    } else if (mem_eql_str(token_mem, token_len, "enum")) {
        t->cur_tok->id = TokenIdKeywordEnum;
    } else if (mem_eql_str(token_mem, token_len, "for")) {
        t->cur_tok->id = TokenIdKeywordFor;
    } else if (mem_eql_str(token_mem, token_len, "while")) {
        t->cur_tok->id = TokenIdKeywordWhile;
    } else if (mem_eql_str(token_mem, token_len, "continue")) {
        t->cur_tok->id = TokenIdKeywordContinue;
    } else if (mem_eql_str(token_mem, token_len, "break")) {
        t->cur_tok->id = TokenIdKeywordBreak;
    } else if (mem_eql_str(token_mem, token_len, "null")) {
        t->cur_tok->id = TokenIdKeywordNull;
    } else if (mem_eql_str(token_mem, token_len, "noalias")) {
        t->cur_tok->id = TokenIdKeywordNoAlias;
    } else if (mem_eql_str(token_mem, token_len, "switch")) {
        t->cur_tok->id = TokenIdKeywordSwitch;
    } else if (mem_eql_str(token_mem, token_len, "undefined")) {
        t->cur_tok->id = TokenIdKeywordUndefined;
    } else if (mem_eql_str(token_mem, token_len, "error")) {
        t->cur_tok->id = TokenIdKeywordError;
    } else if (mem_eql_str(token_mem, token_len, "type")) {
        t->cur_tok->id = TokenIdKeywordType;
    } else if (mem_eql_str(token_mem, token_len, "inline")) {
        t->cur_tok->id = TokenIdKeywordInline;
    } else if (mem_eql_str(token_mem, token_len, "defer")) {
        t->cur_tok->id = TokenIdKeywordDefer;
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

int get_digit_value(uint8_t c) {
    if ('0' <= c && c <= '9') {
        return c - '0';
    }
    if ('A' <= c && c <= 'Z') {
        return c - 'A' + 10;
    }
    if ('a' <= c && c <= 'z') {
        return c - 'a' + 10;
    }
    return -1;
}

void tokenize(Buf *buf, Tokenization *out) {
    Tokenize t = {0};
    t.out = out;
    t.tokens = out->tokens = allocate<ZigList<Token>>(1);
    t.buf = buf;

    out->line_offsets = allocate<ZigList<int>>(1);

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
                        t.state = TokenizeStateSymbolFirst;
                        begin_token(&t, TokenIdSymbol);
                        break;
                    case ALPHA_EXCEPT_C:
                    case '_':
                        t.state = TokenizeStateSymbol;
                        begin_token(&t, TokenIdSymbol);
                        break;
                    case '0':
                        t.state = TokenizeStateZero;
                        begin_token(&t, TokenIdNumberLiteral);
                        t.cur_tok->radix = 10;
                        break;
                    case DIGIT_NON_ZERO:
                        t.state = TokenizeStateNumber;
                        begin_token(&t, TokenIdNumberLiteral);
                        t.cur_tok->radix = 10;
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
                        end_token(&t);
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
                        t.state = TokenizeStateSawPipe;
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
                    case '?':
                        begin_token(&t, TokenIdMaybe);
                        t.state = TokenizeStateSawQuestionMark;
                        break;
                    default:
                        tokenize_error(&t, "invalid character: '%c'", c);
                }
                break;
            case TokenizeStateSawQuestionMark:
                switch (c) {
                    case '?':
                        t.cur_tok->id = TokenIdDoubleQuestion;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '=':
                        t.cur_tok->id = TokenIdMaybeAssign;
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
            case TokenizeStateSawDot:
                switch (c) {
                    case '.':
                        t.state = TokenizeStateSawDotDot;
                        t.cur_tok->id = TokenIdEllipsis;
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
                        end_token(&t);
                        break;
                    default:
                        tokenize_error(&t, "invalid character: '%c'", c);
                }
                break;
            case TokenizeStateSawGreaterThan:
                switch (c) {
                    case '=':
                        t.cur_tok->id = TokenIdCmpGreaterOrEq;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '>':
                        t.cur_tok->id = TokenIdBitShiftRight;
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
                        t.cur_tok->id = TokenIdBitShiftRightEq;
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
                        t.cur_tok->id = TokenIdCmpLessOrEq;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '<':
                        t.cur_tok->id = TokenIdBitShiftLeft;
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
                        t.cur_tok->id = TokenIdBitShiftLeftEq;
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
                        t.cur_tok->id = TokenIdCmpNotEq;
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
                        t.cur_tok->id = TokenIdCmpEq;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '>':
                        t.cur_tok->id = TokenIdFatArrow;
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
                        t.cur_tok->id = TokenIdTimesEq;
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
                        t.cur_tok->id = TokenIdModEq;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '.':
                        t.cur_tok->id = TokenIdPercentDot;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '%':
                        t.cur_tok->id = TokenIdPercentPercent;
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
                        t.cur_tok->id = TokenIdPlusEq;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '+':
                        t.cur_tok->id = TokenIdPlusPlus;
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
                        t.cur_tok->id = TokenIdBoolAnd;
                        t.state = TokenizeStateSawAmpersandAmpersand;
                        break;
                    case '=':
                        t.cur_tok->id = TokenIdBitAndEq;
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
            case TokenizeStateSawAmpersandAmpersand:
                switch (c) {
                    case '=':
                        t.cur_tok->id = TokenIdBoolAndEq;
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
                        t.cur_tok->id = TokenIdBitXorEq;
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
            case TokenizeStateSawPipe:
                switch (c) {
                    case '|':
                        t.cur_tok->id = TokenIdBoolOr;
                        t.state = TokenizeStateSawPipePipe;
                        break;
                    case '=':
                        t.cur_tok->id = TokenIdBitOrEq;
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
            case TokenizeStateSawPipePipe:
                switch (c) {
                    case '=':
                        t.cur_tok->id = TokenIdBoolOrEq;
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
                        cancel_token(&t);
                        t.state = TokenizeStateLineComment;
                        break;
                    case '*':
                        cancel_token(&t);
                        t.state = TokenizeStateMultiLineComment;
                        t.multi_line_comment_count = 1;
                        break;
                    case '=':
                        t.cur_tok->id = TokenIdDivEq;
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
            case TokenizeStateMultiLineComment:
                switch (c) {
                    case '*':
                        t.state = TokenizeStateMultiLineCommentStar;
                        break;
                    case '/':
                        t.state = TokenizeStateMultiLineCommentSlash;
                        break;
                    default:
                        // do nothing
                        break;
                }
                break;
            case TokenizeStateMultiLineCommentSlash:
                switch (c) {
                    case '*':
                        t.state = TokenizeStateMultiLineComment;
                        t.multi_line_comment_count += 1;
                        break;
                    case '/':
                        break;
                    default:
                        t.state = TokenizeStateMultiLineComment;
                        break;
                }
                break;
            case TokenizeStateMultiLineCommentStar:
                switch (c) {
                    case '/':
                        t.multi_line_comment_count -= 1;
                        if (t.multi_line_comment_count == 0) {
                            t.state = TokenizeStateStart;
                        } else {
                            t.state = TokenizeStateMultiLineComment;
                        }
                        break;
                    case '*':
                        break;
                    default:
                        t.state = TokenizeStateMultiLineComment;
                        break;
                }
                break;
            case TokenizeStateSymbolFirst:
                switch (c) {
                    case '"':
                        t.cur_tok->id = TokenIdStringLiteral;
                        t.state = TokenizeStateString;
                        break;
                    case SYMBOL_CHAR:
                        t.state = TokenizeStateSymbol;
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
                    default:
                        break;
                }
                break;
            case TokenizeStateCharLiteral:
                switch (c) {
                    case '\'':
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    default:
                        break;
                }
                break;
            case TokenizeStateZero:
                switch (c) {
                    case 'b':
                        t.cur_tok->radix = 2;
                        break;
                    case 'o':
                        t.cur_tok->radix = 8;
                        break;
                    case 'x':
                        t.cur_tok->radix = 16;
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
                        if (t.pos + 1 < buf_len(t.buf)) {
                            uint8_t next_c = buf_ptr(t.buf)[t.pos + 1];
                            if (next_c == '.') {
                                t.pos -= 1;
                                end_token(&t);
                                t.state = TokenizeStateStart;
                                continue;
                            }
                        }
                        t.cur_tok->decimal_point_pos = t.pos;
                        t.state = TokenizeStateFloatFraction;
                        break;
                    }
                    if (is_exponent_signifier(c, t.cur_tok->radix)) {
                        t.cur_tok->exponent_marker_pos = t.pos;
                        t.state = TokenizeStateFloatExponentUnsigned;
                        break;
                    }
                    if (c == '_') {
                        tokenize_error(&t, "invalid character: '%c'", c);
                        break;
                    }
                    int digit_value = get_digit_value(c);
                    if (digit_value >= 0) {
                        if (digit_value >= t.cur_tok->radix) {
                            tokenize_error(&t, "invalid character: '%c'", c);
                            break;
                        }
                        // normal digit
                    } else {
                        // not my char
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }
                    break;
                }
            case TokenizeStateFloatFraction:
                {
                    if (is_exponent_signifier(c, t.cur_tok->radix)) {
                        t.cur_tok->exponent_marker_pos = t.pos;
                        t.state = TokenizeStateFloatExponentUnsigned;
                        break;
                    }
                    if (c == '_') {
                        tokenize_error(&t, "invalid character: '%c'", c);
                        break;
                    }
                    int digit_value = get_digit_value(c);
                    if (digit_value >= 0) {
                        if (digit_value >= t.cur_tok->radix) {
                            tokenize_error(&t, "invalid character: '%c'", c);
                            break;
                        }
                        // normal digit
                    } else {
                        // not my char
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                    }
                    break;
                }
            case TokenizeStateFloatExponentUnsigned:
                switch (c) {
                    case '+':
                    case '-':
                        t.state = TokenizeStateFloatExponentNumber;
                        break;
                    default:
                        // reinterpret as normal exponent number
                        t.pos -= 1;
                        t.state = TokenizeStateFloatExponentNumber;
                        continue;
                }
                break;
            case TokenizeStateFloatExponentNumber:
                switch (c) {
                    case DIGIT:
                        break;
                    case ALPHA:
                    case '_':
                        tokenize_error(&t, "invalid character: '%c'", c);
                        break;
                    default:
                        t.pos -= 1;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        continue;
                }
                break;
            case TokenizeStateSawDash:
                switch (c) {
                    case '>':
                        t.cur_tok->id = TokenIdArrow;
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                    case '=':
                        t.cur_tok->id = TokenIdMinusEq;
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
        case TokenizeStateString:
            tokenize_error(&t, "unterminated string");
            break;
        case TokenizeStateCharLiteral:
            tokenize_error(&t, "unterminated character literal");
            break;
        case TokenizeStateSymbol:
        case TokenizeStateSymbolFirst:
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
        case TokenizeStateSawAmpersandAmpersand:
        case TokenizeStateSawCaret:
        case TokenizeStateSawPipe:
        case TokenizeStateSawPipePipe:
        case TokenizeStateSawEq:
        case TokenizeStateSawBang:
        case TokenizeStateSawLessThan:
        case TokenizeStateSawLessThanLessThan:
        case TokenizeStateSawGreaterThan:
        case TokenizeStateSawGreaterThanGreaterThan:
        case TokenizeStateSawDot:
        case TokenizeStateSawQuestionMark:
            end_token(&t);
            break;
        case TokenizeStateSawDotDot:
            tokenize_error(&t, "unexpected EOF");
            break;
        case TokenizeStateLineComment:
            break;
        case TokenizeStateMultiLineComment:
        case TokenizeStateMultiLineCommentSlash:
        case TokenizeStateMultiLineCommentStar:
            tokenize_error(&t, "unterminated multi-line comment");
            break;
    }
    if (t.state != TokenizeStateError) {
        if (t.tokens->length > 0) {
            Token *last_token = &t.tokens->last();
            t.line = last_token->start_line;
            t.column = last_token->start_column;
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
        case TokenIdEof: return "EOF";
        case TokenIdSymbol: return "Symbol";
        case TokenIdKeywordFn: return "fn";
        case TokenIdKeywordConst: return "const";
        case TokenIdKeywordVar: return "var";
        case TokenIdKeywordReturn: return "return";
        case TokenIdKeywordExtern: return "extern";
        case TokenIdKeywordPub: return "pub";
        case TokenIdKeywordExport: return "export";
        case TokenIdKeywordUse: return "use";
        case TokenIdKeywordTrue: return "true";
        case TokenIdKeywordFalse: return "false";
        case TokenIdKeywordIf: return "if";
        case TokenIdKeywordElse: return "else";
        case TokenIdKeywordGoto: return "goto";
        case TokenIdKeywordVolatile: return "volatile";
        case TokenIdKeywordAsm: return "asm";
        case TokenIdKeywordStruct: return "struct";
        case TokenIdKeywordEnum: return "enum";
        case TokenIdKeywordWhile: return "while";
        case TokenIdKeywordFor: return "for";
        case TokenIdKeywordContinue: return "continue";
        case TokenIdKeywordBreak: return "break";
        case TokenIdKeywordNull: return "null";
        case TokenIdKeywordNoAlias: return "noalias";
        case TokenIdKeywordSwitch: return "switch";
        case TokenIdKeywordUndefined: return "undefined";
        case TokenIdKeywordError: return "error";
        case TokenIdKeywordType: return "type";
        case TokenIdKeywordInline: return "inline";
        case TokenIdKeywordDefer: return "defer";
        case TokenIdLParen: return "(";
        case TokenIdRParen: return ")";
        case TokenIdComma: return ",";
        case TokenIdStar: return "*";
        case TokenIdLBrace: return "{";
        case TokenIdRBrace: return "}";
        case TokenIdLBracket: return "[";
        case TokenIdRBracket: return "]";
        case TokenIdStringLiteral: return "StringLiteral";
        case TokenIdCharLiteral: return "CharLiteral";
        case TokenIdSemicolon: return ";";
        case TokenIdNumberLiteral: return "NumberLiteral";
        case TokenIdPlus: return "+";
        case TokenIdPlusPlus: return "++";
        case TokenIdColon: return ":";
        case TokenIdArrow: return "->";
        case TokenIdFatArrow: return "=>";
        case TokenIdDash: return "-";
        case TokenIdNumberSign: return "#";
        case TokenIdBinOr: return "|";
        case TokenIdAmpersand: return "&";
        case TokenIdBinXor: return "^";
        case TokenIdBoolOr: return "||";
        case TokenIdBoolAnd: return "&&";
        case TokenIdEq: return "=";
        case TokenIdTimesEq: return "*=";
        case TokenIdDivEq: return "/=";
        case TokenIdModEq: return "%=";
        case TokenIdPlusEq: return "+=";
        case TokenIdMinusEq: return "-=";
        case TokenIdBitShiftLeftEq: return "<<=";
        case TokenIdBitShiftRightEq: return ">>=";
        case TokenIdBitAndEq: return "&=";
        case TokenIdBitXorEq: return "^=";
        case TokenIdBitOrEq: return "|=";
        case TokenIdBoolAndEq: return "&&=";
        case TokenIdBoolOrEq: return "||=";
        case TokenIdBang: return "!";
        case TokenIdTilde: return "~";
        case TokenIdCmpEq: return "==";
        case TokenIdCmpNotEq: return "!=";
        case TokenIdCmpLessThan: return "<";
        case TokenIdCmpGreaterThan: return ">";
        case TokenIdCmpLessOrEq: return "<=";
        case TokenIdCmpGreaterOrEq: return ">=";
        case TokenIdBitShiftLeft: return "<<";
        case TokenIdBitShiftRight: return ">>";
        case TokenIdSlash: return "/";
        case TokenIdPercent: return "%";
        case TokenIdPercentPercent: return "%%";
        case TokenIdDot: return ".";
        case TokenIdEllipsis: return "...";
        case TokenIdMaybe: return "?";
        case TokenIdDoubleQuestion: return "??";
        case TokenIdMaybeAssign: return "?=";
        case TokenIdAtSign: return "@";
        case TokenIdPercentDot: return "%.";
    }
    return "(invalid token)";
}

void print_tokens(Buf *buf, ZigList<Token> *tokens) {
    for (int i = 0; i < tokens->length; i += 1) {
        Token *token = &tokens->at(i);
        fprintf(stderr, "%s ", token_name(token->id));
        if (token->start_pos >= 0) {
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
