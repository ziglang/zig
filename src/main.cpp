/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "config.h"
#include "util.hpp"
#include "list.hpp"
#include "buffer.hpp"

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

static int usage(char *arg0) {
    fprintf(stderr, "Usage: %s --output outfile code.zig\n"
        "Other options:\n"
        "--version      print version number and exit\n"
        "-Ipath         add path to header include path\n"
    , arg0);
    return EXIT_FAILURE;
}

static Buf *fetch_file(FILE *f) {
    int fd = fileno(f);
    struct stat st;
    if (fstat(fd, &st))
        zig_panic("unable to stat file: %s", strerror(errno));
    off_t big_size = st.st_size;
    if (big_size > INT_MAX)
        zig_panic("file too big");
    int size = (int)big_size;

    Buf *buf = buf_alloc_fixed(size);
    size_t amt_read = fread(buf_ptr(buf), 1, buf_len(buf), f);
    if (amt_read != (size_t)buf_len(buf))
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

#define SYMBOL_CHAR \
    ALPHA: \
    case DIGIT: \
    case '_'


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
    int start_line;
    int start_column;
};

enum TokenizeState {
    TokenizeStateStart,
    TokenizeStateDirective,
    TokenizeStateDirectiveName,
    TokenizeStateIncludeQuote,
    TokenizeStateDirectiveEnd,
    TokenizeStateInclude,
    TokenizeStateSymbol,
    TokenizeStateString,
    TokenizeStateNumber,
};

struct Tokenize {
    Buf *buf;
    int pos;
    TokenizeState state;
    ZigList<Token> *tokens;
    int line;
    int column;
    Token *cur_tok;
    Buf *directive_name;
    Buf *cur_dir_path;
    uint8_t unquote_char;
    int quote_start_pos;
    Buf *include_path;
    ZigList<char *> *include_paths;
};

__attribute__ ((format (printf, 2, 3)))
static void tokenize_error(Tokenize *t, const char *format, ...) {
    int line;
    int column;
    if (t->cur_tok) {
        line = t->cur_tok->start_line + 1;
        column = t->cur_tok->start_column + 1;
    } else {
        line = t->line + 1;
        column = t->column + 1;
    }

    va_list ap;
    va_start(ap, format);
    fprintf(stderr, "Error: Line %d, column %d: ", line, column);
    vfprintf(stderr, format, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(EXIT_FAILURE);
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

static void end_token(Tokenize *t) {
    assert(t->cur_tok);
    t->cur_tok->end_pos = t->pos + 1;
    t->cur_tok = nullptr;
}

static void put_back(Tokenize *t, int count) {
    t->pos -= count;
}

static void begin_directive(Tokenize *t) {
    t->state = TokenizeStateDirective;
    begin_token(t, TokenIdDirective);
    assert(!t->directive_name);
    t->directive_name = buf_alloc();
}

static bool find_and_include_file(Tokenize *t, char *dir_path, char *file_path) {
    Buf *full_path = buf_sprintf("%s/%s", dir_path, file_path);

    FILE *f = fopen(buf_ptr(full_path), "rb");
    if (!f)
        return false;

    Buf *contents = fetch_file(f);

    buf_splice_buf(t->buf, t->pos, t->pos, contents);

    return true;
}

static void render_include(Tokenize *t, Buf *target_path, char unquote_char) {
    if (unquote_char == '"') {
        if (find_and_include_file(t, buf_ptr(t->cur_dir_path), buf_ptr(target_path)))
            return;
    }
    for (int i = 0; i < t->include_paths->length; i += 1) {
        char *include_path = t->include_paths->at(i);
        if (find_and_include_file(t, include_path, buf_ptr(target_path)))
            return;
    }
    tokenize_error(t, "include path \"%s\" not found", buf_ptr(target_path));
}

static void end_directive(Tokenize *t) {
    end_token(t);
    if (t->include_path) {
        render_include(t, t->include_path, t->unquote_char);
        t->include_path = nullptr;
    }
    t->state = TokenizeStateStart;
}

static void end_directive_name(Tokenize *t) {
    if (buf_eql_str(t->directive_name, "include")) {
        t->state = TokenizeStateInclude;
        t->directive_name = nullptr;
    } else {
        tokenize_error(t, "invalid directive name: \"%s\"", buf_ptr(t->directive_name));
    }
}

static void end_symbol(Tokenize *t) {
    put_back(t, 1);
    end_token(t);
    t->state = TokenizeStateStart;
}

static ZigList<Token> *tokenize(Buf *buf, ZigList<char *> *include_paths, Buf *cur_dir_path) {
    Tokenize t = {0};
    t.tokens = allocate<ZigList<Token>>(1);
    t.buf = buf;
    t.cur_dir_path = cur_dir_path;
    t.include_paths = include_paths;
    for (t.pos = 0; t.pos < buf_len(t.buf); t.pos += 1) {
        uint8_t c = buf_ptr(t.buf)[t.pos];
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
                        begin_directive(&t);
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
                switch (c) {
                    case '\n':
                        end_directive_name(&t);
                        end_directive(&t);
                        break;
                    case ' ':
                    case '\t':
                    case '\f':
                    case '\r':
                    case 0xb:
                        break;
                    case SYMBOL_CHAR:
                        t.state = TokenizeStateDirectiveName;
                        buf_append_char(t.directive_name, c);
                        break;
                    default:
                        tokenize_error(&t, "invalid directive character: '%c'", c);
                        break;
                }
                break;
            case TokenizeStateDirectiveName:
                switch (c) {
                    case WHITESPACE:
                        end_directive_name(&t);
                        break;
                    case SYMBOL_CHAR:
                        buf_append_char(t.directive_name, c);
                        break;
                    default:
                        tokenize_error(&t, "invalid directive name character: '%c'", c);
                        break;
                }
                break;
            case TokenizeStateInclude:
                switch (c) {
                    case WHITESPACE:
                        break;
                    case '<':
                    case '"':
                        t.state = TokenizeStateIncludeQuote;
                        t.quote_start_pos = t.pos;
                        t.unquote_char = (c == '<') ? '>' : '"';
                        break;
                }
                break;
            case TokenizeStateIncludeQuote:
                if (c == t.unquote_char) {
                    t.include_path = buf_slice(t.buf, t.quote_start_pos + 1, t.pos);
                    t.state = TokenizeStateDirectiveEnd;
                }
                break;
            case TokenizeStateDirectiveEnd:
                switch (c) {
                    case '\n':
                        end_directive(&t);
                        break;
                    case ' ':
                    case '\t':
                    case '\f':
                    case '\r':
                    case 0xb:
                        break;
                    default:
                        tokenize_error(&t, "expected whitespace or newline: '%c'", c);
                }
                break;
            case TokenizeStateSymbol:
                switch (c) {
                    case SYMBOL_CHAR:
                        break;
                    default:
                        end_symbol(&t);
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
                        end_symbol(&t);
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
    // EOF
    switch (t.state) {
        case TokenizeStateStart:
            break;
        case TokenizeStateDirective:
            end_directive(&t);
            break;
        case TokenizeStateDirectiveName:
            end_directive_name(&t);
            end_directive(&t);
            break;
        case TokenizeStateInclude:
            tokenize_error(&t, "missing include path");
            break;
        case TokenizeStateSymbol:
            end_symbol(&t);
            break;
        case TokenizeStateString:
            tokenize_error(&t, "unterminated string");
            break;
        case TokenizeStateNumber:
            end_symbol(&t);
            break;
        case TokenizeStateIncludeQuote:
            tokenize_error(&t, "unterminated include path");
            break;
        case TokenizeStateDirectiveEnd:
            end_directive(&t);
            break;
    }
    assert(!t.cur_tok);
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
        fwrite(buf_ptr(buf) + token->start_pos, 1, token->end_pos - token->start_pos, stdout);
        printf("\n");
    }
}

char cur_dir[1024];

int main(int argc, char **argv) {
    char *arg0 = argv[0];
    char *in_file = NULL;
    char *out_file = NULL;
    ZigList<char *> include_paths = {0};
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
        } else if (arg[0] == '-' && arg[1] == 'I') {
            include_paths.append(arg + 2);
        } else if (!in_file) {
            in_file = arg;
        } else {
            return usage(arg0);
        }
    }

    if (!in_file || !out_file)
        return usage(arg0);

    FILE *in_f;
    Buf *cur_dir_path;
    if (strcmp(in_file, "-") == 0) {
        in_f = stdin;
        char *result = getcwd(cur_dir, sizeof(cur_dir));
        if (!result)
            zig_panic("unable to get current working directory: %s", strerror(errno));
        cur_dir_path = buf_from_str(result);
    } else {
        in_f = fopen(in_file, "rb");
        if (!in_f)
            zig_panic("unable to open %s for reading: %s\n", in_file, strerror(errno));
        cur_dir_path = buf_dirname(buf_from_str(in_file));
    }

    Buf *in_data = fetch_file(in_f);

    fprintf(stderr, "Original source:\n%s\n", buf_ptr(in_data));

    ZigList<Token> *tokens = tokenize(in_data, &include_paths, cur_dir_path);

    fprintf(stderr, "\nTokens:\n");
    print_tokens(in_data, tokens);

    /*
    Buf *preprocessed_source = preprocess(in_data, tokens, &include_paths, cur_dir_path);

    fprintf(stderr, "\nPreprocessed source:\n%s\n", buf_ptr(preprocessed_source));
    */


    return EXIT_SUCCESS;
}
