/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "config.h"
#include "util.hpp"
#include "list.hpp"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <limits.h>
#include <stdint.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

struct Buf {
    int len;
    char ptr[0];
};

static Buf *alloc_buf(int size) {
    Buf *buf = (Buf *)allocate_nonzero<char>(sizeof(Buf) + size + 1);
    buf->len = size;
    buf->ptr[buf->len] = 0;
    return buf;
}

/*
static void fprint_buf(FILE *f, Buf *buf) {
    if (fwrite(buf->ptr, 1, buf->len, f))
        zig_panic("error writing: %s", strerror(errno));
}
*/

static int usage(char *arg0) {
    fprintf(stderr, "Usage: %s --output outfile code.zig\n"
        "Other options:\n"
        "--version      print version number and exit\n"
    , arg0);
    return EXIT_FAILURE;
}

static struct Buf *fetch_file(FILE *f) {
    int fd = fileno(f);
    struct stat st;
    if (fstat(fd, &st))
        zig_panic("unable to stat file: %s", strerror(errno));
    off_t big_size = st.st_size;
    if (big_size > INT_MAX)
        zig_panic("file too big");
    int size = (int)big_size;

    Buf *buf = alloc_buf(size);
    size_t amt_read = fread(buf->ptr, 1, buf->len, f);
    if (amt_read != (size_t)buf->len)
        zig_panic("error reading: %s", strerror(errno));

    return buf;
}

#define WHITESPACE \
    ' ': \
    case '\t': \
    case '\n': \
    case '\f': \
    case '\r': \
    case 0xb

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

enum TokenId {
    TokenIdDirective,
    TokenIdSymbol,
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
};

struct Token {
    TokenId id;
    int start_pos;
    int end_pos;
};

enum TokenizeState {
    TokenizeStateStart,
    TokenizeStateDirective,
    TokenizeStateSymbol,
    TokenizeStateString,
    TokenizeStateNumber,
};

struct Tokenize {
    int pos;
    TokenizeState state;
    ZigList<Token> *tokens;
    int line;
    int column;
    Token *cur_tok;
};

__attribute__ ((format (printf, 2, 3)))
static void tokenize_error(Tokenize *t, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    fprintf(stderr, "Error. Line %d, column %d: ", t->line + 1, t->column + 1);
    vfprintf(stderr, format, ap);
    va_end(ap);
    exit(EXIT_FAILURE);
}

static void begin_token(Tokenize *t, TokenId id) {
    assert(!t->cur_tok);
    t->tokens->add_one();
    Token *token = &t->tokens->last();
    token->id = id;
    token->start_pos = t->pos;
    t->cur_tok = token;
}

static void end_token(Tokenize *t) {
    assert(t->cur_tok);
    t->cur_tok->end_pos = t->pos + 1;
    t->cur_tok = nullptr;
}

static void put_back(Tokenize *t, int count) {
    t->pos -= count;
}

static ZigList<Token> *tokenize(Buf *buf) {
    Tokenize t = {0};
    t.tokens = allocate<ZigList<Token>>(1);
    for (t.pos = 0; t.pos < buf->len; t.pos += 1) {
        uint8_t c = buf->ptr[t.pos];
        switch (t.state) {
            case TokenizeStateStart:
                switch (c) {
                    case WHITESPACE:
                        break;
                    case ALPHA:
                        t.state = TokenizeStateSymbol;
                        begin_token(&t, TokenIdSymbol);
                        break;
                    case DIGIT:
                        t.state = TokenizeStateNumber;
                        begin_token(&t, TokenIdNumberLiteral);
                        break;
                    case '#':
                        t.state = TokenizeStateDirective;
                        begin_token(&t, TokenIdDirective);
                        break;
                    case '(':
                        begin_token(&t, TokenIdLParen);
                        end_token(&t);
                        break;
                    case ')':
                        begin_token(&t, TokenIdLParen);
                        end_token(&t);
                        break;
                    case ',':
                        begin_token(&t, TokenIdComma);
                        end_token(&t);
                        break;
                    case '*':
                        begin_token(&t, TokenIdStar);
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
                    case '"':
                        begin_token(&t, TokenIdStringLiteral);
                        t.state = TokenizeStateString;
                        break;
                    case ';':
                        begin_token(&t, TokenIdSemicolon);
                        end_token(&t);
                        break;
                    case '+':
                        begin_token(&t, TokenIdPlus);
                        end_token(&t);
                        break;
                    default:
                        tokenize_error(&t, "invalid character: '%c'", c);
                }
                break;
            case TokenizeStateDirective:
                if (c == '\n') {
                    assert(t.cur_tok);
                    t.cur_tok->end_pos = t.pos;
                    t.cur_tok = nullptr;
                    t.state = TokenizeStateStart;
                }
                break;
            case TokenizeStateSymbol:
                switch (c) {
                    case ALPHA:
                    case DIGIT:
                    case '_':
                        break;
                    default:
                        put_back(&t, 1);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
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
                        put_back(&t, 1);
                        end_token(&t);
                        t.state = TokenizeStateStart;
                        break;
                }
                break;
        }
        if (c == '\n') {
            t.line += 1;
            t.column = 0;
        } else {
            t.column += 1;
        }
    }
    return t.tokens;
}

static const char * token_name(Token *token) {
    switch (token->id) {
        case TokenIdDirective: return "Directive";
        case TokenIdSymbol: return "Symbol";
        case TokenIdLParen: return "LParen";
        case TokenIdRParen: return "RParen";
        case TokenIdComma: return "Comma";
        case TokenIdStar: return "Star";
        case TokenIdLBrace: return "LBrace";
        case TokenIdRBrace: return "RBrace";
        case TokenIdStringLiteral: return "StringLiteral";
        case TokenIdSemicolon: return "Semicolon";
        case TokenIdNumberLiteral: return "NumberLiteral";
        case TokenIdPlus: return "Plus";
    }
    return "(invalid token)";
}

static void print_tokens(Buf *buf, ZigList<Token> *tokens) {
    for (int i = 0; i < tokens->length; i += 1) {
        Token *token = &tokens->at(i);
        printf("%s ", token_name(token));
        fwrite(buf->ptr + token->start_pos, 1, token->end_pos - token->start_pos, stdout);
        printf("\n");
    }
}

int main(int argc, char **argv) {
    char *arg0 = argv[0];
    char *in_file = NULL;
    char *out_file = NULL;
    for (int i = 1; i < argc; i += 1) {
        char *arg = argv[i];
        if (arg[0] == '-' && arg[1] == '-') {
            if (strcmp(arg, "--version") == 0) {
                printf("%s\n", ZIG_VERSION_STRING);
                return EXIT_SUCCESS;
            } else if (i + 1 >= argc) {
                return usage(arg0);
            } else {
                i += 1;
                if (strcmp(arg, "--output") == 0) {
                    out_file = argv[i];
                } else {
                    return usage(arg0);
                }
            }
        } else if (!in_file) {
            in_file = arg;
        } else {
            return usage(arg0);
        }
    }

    if (!in_file || !out_file)
        return usage(arg0);

    FILE *in_f;
    if (strcmp(in_file, "-") == 0) {
        in_f = stdin;
    } else {
        in_f = fopen(in_file, "rb");
        if (!in_f)
            zig_panic("unable to open %s for reading: %s\n", in_file, strerror(errno));
    }

    struct Buf *in_data = fetch_file(in_f);

    fprintf(stderr, "%s\n", in_data->ptr);

    ZigList<Token> *tokens = tokenize(in_data);

    print_tokens(in_data, tokens);


    return EXIT_SUCCESS;
}
