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

#define DIGIT \
    '0': \
    case '1': \
    case '2': \
    case '3': \
    case '4': \
    case '5': \
    case '6': \
    case '7': \
    case '8': \
    case '9'

#define ALPHA_EXCEPT_C \
    'a': \
    case 'b': \
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

enum TokenizeState {
    TokenizeStateStart,
    TokenizeStateSymbol,
    TokenizeStateSymbolFirst,
    TokenizeStateNumber,
    TokenizeStateString,
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
    t->cur_tok = token;
}

static void cancel_token(Tokenize *t) {
    t->tokens->pop();
    t->cur_tok = nullptr;
}

static void end_token(Tokenize *t) {
    assert(t->cur_tok);
    t->cur_tok->end_pos = t->pos + 1;

    char *token_mem = buf_ptr(t->buf) + t->cur_tok->start_pos;
    int token_len = t->cur_tok->end_pos - t->cur_tok->start_pos;

    if (mem_eql_str(token_mem, token_len, "fn")) {
        t->cur_tok->id = TokenIdKeywordFn;
    } else if (mem_eql_str(token_mem, token_len, "return")) {
        t->cur_tok->id = TokenIdKeywordReturn;
    } else if (mem_eql_str(token_mem, token_len, "let")) {
        t->cur_tok->id = TokenIdKeywordLet;
    } else if (mem_eql_str(token_mem, token_len, "mut")) {
        t->cur_tok->id = TokenIdKeywordMut;
    } else if (mem_eql_str(token_mem, token_len, "const")) {
        t->cur_tok->id = TokenIdKeywordConst;
    } else if (mem_eql_str(token_mem, token_len, "extern")) {
        t->cur_tok->id = TokenIdKeywordExtern;
    } else if (mem_eql_str(token_mem, token_len, "unreachable")) {
        t->cur_tok->id = TokenIdKeywordUnreachable;
    } else if (mem_eql_str(token_mem, token_len, "pub")) {
        t->cur_tok->id = TokenIdKeywordPub;
    } else if (mem_eql_str(token_mem, token_len, "export")) {
        t->cur_tok->id = TokenIdKeywordExport;
    } else if (mem_eql_str(token_mem, token_len, "as")) {
        t->cur_tok->id = TokenIdKeywordAs;
    } else if (mem_eql_str(token_mem, token_len, "use")) {
        t->cur_tok->id = TokenIdKeywordUse;
    } else if (mem_eql_str(token_mem, token_len, "void")) {
        t->cur_tok->id = TokenIdKeywordVoid;
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
    }

    t->cur_tok = nullptr;
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
                    case DIGIT:
                        t.state = TokenizeStateNumber;
                        begin_token(&t, TokenIdNumberLiteral);
                        break;
                    case '"':
                        begin_token(&t, TokenIdStringLiteral);
                        t.state = TokenizeStateString;
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
                    default:
                        tokenize_error(&t, "invalid character: '%c'", c);
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
            case TokenizeStateNumber:
                switch (c) {
                    case DIGIT:
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
        case TokenizeStateSymbol:
        case TokenizeStateSymbolFirst:
        case TokenizeStateNumber:
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
        t.pos = -1;
        begin_token(&t, TokenIdEof);
        end_token(&t);
        assert(!t.cur_tok);
    }
}

static const char * token_name(Token *token) {
    switch (token->id) {
        case TokenIdEof: return "EOF";
        case TokenIdSymbol: return "Symbol";
        case TokenIdKeywordFn: return "Fn";
        case TokenIdKeywordConst: return "Const";
        case TokenIdKeywordMut: return "Mut";
        case TokenIdKeywordReturn: return "Return";
        case TokenIdKeywordLet: return "Let";
        case TokenIdKeywordExtern: return "Extern";
        case TokenIdKeywordUnreachable: return "Unreachable";
        case TokenIdKeywordPub: return "Pub";
        case TokenIdKeywordExport: return "Export";
        case TokenIdKeywordAs: return "As";
        case TokenIdKeywordUse: return "Use";
        case TokenIdKeywordVoid: return "Void";
        case TokenIdKeywordTrue: return "True";
        case TokenIdKeywordFalse: return "False";
        case TokenIdKeywordIf: return "If";
        case TokenIdKeywordElse: return "Else";
        case TokenIdKeywordGoto: return "Goto";
        case TokenIdKeywordVolatile: return "Volatile";
        case TokenIdKeywordAsm: return "Asm";
        case TokenIdKeywordStruct: return "Struct";
        case TokenIdLParen: return "LParen";
        case TokenIdRParen: return "RParen";
        case TokenIdComma: return "Comma";
        case TokenIdStar: return "Star";
        case TokenIdLBrace: return "LBrace";
        case TokenIdRBrace: return "RBrace";
        case TokenIdLBracket: return "LBracket";
        case TokenIdRBracket: return "RBracket";
        case TokenIdStringLiteral: return "StringLiteral";
        case TokenIdSemicolon: return "Semicolon";
        case TokenIdNumberLiteral: return "NumberLiteral";
        case TokenIdPlus: return "Plus";
        case TokenIdColon: return "Colon";
        case TokenIdArrow: return "Arrow";
        case TokenIdDash: return "Dash";
        case TokenIdNumberSign: return "NumberSign";
        case TokenIdBinOr: return "BinOr";
        case TokenIdAmpersand: return "Ampersand";
        case TokenIdBinXor: return "BinXor";
        case TokenIdBoolOr: return "BoolOr";
        case TokenIdBoolAnd: return "BoolAnd";
        case TokenIdEq: return "Eq";
        case TokenIdTimesEq: return "TimesEq";
        case TokenIdDivEq: return "DivEq";
        case TokenIdModEq: return "ModEq";
        case TokenIdPlusEq: return "PlusEq";
        case TokenIdMinusEq: return "MinusEq";
        case TokenIdBitShiftLeftEq: return "BitShiftLeftEq";
        case TokenIdBitShiftRightEq: return "BitShiftRightEq";
        case TokenIdBitAndEq: return "BitAndEq";
        case TokenIdBitXorEq: return "BitXorEq";
        case TokenIdBitOrEq: return "BitOrEq";
        case TokenIdBoolAndEq: return "BoolAndEq";
        case TokenIdBoolOrEq: return "BoolOrEq";
        case TokenIdBang: return "Bang";
        case TokenIdTilde: return "Tilde";
        case TokenIdCmpEq: return "CmpEq";
        case TokenIdCmpNotEq: return "CmpNotEq";
        case TokenIdCmpLessThan: return "CmpLessThan";
        case TokenIdCmpGreaterThan: return "CmpGreaterThan";
        case TokenIdCmpLessOrEq: return "CmpLessOrEq";
        case TokenIdCmpGreaterOrEq: return "CmpGreaterOrEq";
        case TokenIdBitShiftLeft: return "BitShiftLeft";
        case TokenIdBitShiftRight: return "BitShiftRight";
        case TokenIdSlash: return "Slash";
        case TokenIdPercent: return "Percent";
        case TokenIdDot: return "Dot";
        case TokenIdEllipsis: return "Ellipsis";
    }
    return "(invalid token)";
}

void print_tokens(Buf *buf, ZigList<Token> *tokens) {
    for (int i = 0; i < tokens->length; i += 1) {
        Token *token = &tokens->at(i);
        fprintf(stderr, "%s ", token_name(token));
        if (token->start_pos >= 0) {
            fwrite(buf_ptr(buf) + token->start_pos, 1, token->end_pos - token->start_pos, stderr);
        }
        fprintf(stderr, "\n");
    }
}

bool is_printable(uint8_t c) {
    switch (c) {
        default:
            return false;
        case DIGIT:
        case ALPHA:
        case '!':
        case '#':
        case '$':
        case '%':
        case '&':
        case '\'':
        case '(':
        case ')':
        case '*':
        case '+':
        case ',':
        case '-':
        case '.':
        case '/':
        case ':':
        case ';':
        case '<':
        case '=':
        case '>':
        case '?':
        case '@':
        case '^':
        case '_':
        case '`':
        case '~':
        case ' ':
            return true;
    }
}

