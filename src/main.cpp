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

static inline bool mem_eql_str(const char *mem, size_t mem_len, const char *str) {
    size_t str_len = strlen(str);
    if (str_len != mem_len)
        return false;
    return memcmp(mem, str, mem_len) == 0;
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
    TokenIdSymbol,
    TokenIdKeywordFn,
    TokenIdKeywordReturn,
    TokenIdKeywordMut,
    TokenIdKeywordConst,
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
    TokenIdColon,
    TokenIdArrow,
    TokenIdDash,
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
    TokenizeStateSymbol,
    TokenizeStateNumber,
    TokenizeStateString,
    TokenizeStateSawDash,
};

struct Tokenize {
    Buf *buf;
    int pos;
    TokenizeState state;
    ZigList<Token> *tokens;
    int line;
    int column;
    Token *cur_tok;
    Buf *cur_dir_path;
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

    char *token_mem = buf_ptr(t->buf) + t->cur_tok->start_pos;
    int token_len = t->cur_tok->end_pos - t->cur_tok->start_pos;

    if (mem_eql_str(token_mem, token_len, "fn")) {
        t->cur_tok->id = TokenIdKeywordFn;
    } else if (mem_eql_str(token_mem, token_len, "return")) {
        t->cur_tok->id = TokenIdKeywordReturn;
    } else if (mem_eql_str(token_mem, token_len, "mut")) {
        t->cur_tok->id = TokenIdKeywordMut;
    } else if (mem_eql_str(token_mem, token_len, "const")) {
        t->cur_tok->id = TokenIdKeywordConst;
    }

    t->cur_tok = nullptr;
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
                    case ':':
                        begin_token(&t, TokenIdColon);
                        end_token(&t);
                        break;
                    case '+':
                        begin_token(&t, TokenIdPlus);
                        end_token(&t);
                        break;
                    case '-':
                        begin_token(&t, TokenIdDash);
                        t.state = TokenizeStateSawDash;
                        break;
                    default:
                        tokenize_error(&t, "invalid character: '%c'", c);
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
                    default:
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
    // EOF
    switch (t.state) {
        case TokenizeStateStart:
            break;
        case TokenizeStateSymbol:
            end_token(&t);
            break;
        case TokenizeStateString:
            tokenize_error(&t, "unterminated string");
            break;
        case TokenizeStateNumber:
            end_token(&t);
            break;
        case TokenizeStateSawDash:
            end_token(&t);
            break;
    }
    assert(!t.cur_tok);
    return t.tokens;
}

static const char * token_name(Token *token) {
    switch (token->id) {
        case TokenIdSymbol: return "Symbol";
        case TokenIdKeywordFn: return "Fn";
        case TokenIdKeywordConst: return "Const";
        case TokenIdKeywordMut: return "Mut";
        case TokenIdKeywordReturn: return "Return";
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
        case TokenIdColon: return "Colon";
        case TokenIdArrow: return "Arrow";
        case TokenIdDash: return "Dash";
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

struct AstNode;

enum NodeType {
    NodeTypeRoot,
    NodeTypeFnDecl,
    NodeTypeParam,
    NodeTypeType,
    NodeTypeBlock,
};

struct AstNodeFnDecl {
    Buf name;
    ZigList<AstNode *> params;
    AstNode *return_type;
    AstNode *body;
};

struct AstNodeRoot {
    ZigList<AstNode *> fn_decls;
};

enum AstNodeTypeType {
    AstNodeTypeTypePrimitive,
    AstNodeTypeTypePointer,
};

enum AstPrimitiveType {
    AstPrimitiveTypeVoid,
    AstPrimitiveTypeU8,
    AstPrimitiveTypeI8,
    AstPrimitiveTypeU16,
    AstPrimitiveTypeI16,
    AstPrimitiveTypeU32,
    AstPrimitiveTypeI32,
    AstPrimitiveTypeU64,
    AstPrimitiveTypeI64,
    AstPrimitiveTypeUSize,
    AstPrimitiveTypeISize,
    AstPrimitiveTypeF32,
    AstPrimitiveTypeF64,
};


struct AstNodeType {
    AstNodeTypeType type;
    AstPrimitiveType primitive_type;
    AstNode *pointer_type;
    bool is_const;
};

struct AstNodeParam {
    Buf name;
    AstNode *type;
};

enum AstState {
    AstStateStart,
    AstStateFn,
    AstStateFnLParen,
    AstStateFnParamName,
    AstStateParamColon,
    AstStateType,
    AstStateTypeEnd,
    AstStateFnParamComma,
    AstStateFnDeclArrow,
    AstStateFnDeclBlock,
    AstStatePointerType,
    AstStateBlock,
};

struct AstNode {
    enum NodeType type;
    AstNode *parent;
    AstState prev_state;
    union {
        AstNodeRoot root;
        AstNodeFnDecl fn_decl;
        AstNodeType type;
        AstNodeParam param;
    } data;
};

struct BuildAst {
    Buf *buf;
    AstNode *root;
    AstState state;
    int line;
    int column;
    AstNode *cur_node;
};

__attribute__ ((format (printf, 2, 3)))
static void ast_error(BuildAst *b, const char *format, ...) {
    int line = b->line + 1;
    int column = b->column + 1;

    va_list ap;
    va_start(ap, format);
    fprintf(stderr, "Error: Line %d, column %d: ", line, column);
    vfprintf(stderr, format, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(EXIT_FAILURE);
}

static AstNode *ast_create_node(BuildAst *b, NodeType type) {
    AstNode *child = allocate<AstNode>(1);
    child->prev_state = b->state;
    child->parent = b->cur_node;
    child->type = type;
    return child;
}

static void ast_make_node_current(BuildAst *b, AstNode *node) {
    b->cur_node = node;
}

static void ast_up_stack(BuildAst *b) {
    assert(b->cur_node->parent);
    b->state = b->cur_node->prev_state;
    b->cur_node = b->cur_node->parent;
}


static const char *node_type_str(NodeType node_type) {
    switch (node_type) {
        case NodeTypeRoot:      return "Root";
        case NodeTypeFnDecl:    return "FnDecl";
        case NodeTypeParam:     return "Param";
        case NodeTypeType:      return "Type";
        case NodeTypeBlock:     return "Block";
    }
    zig_panic("unreachable");
}

static void print_ast(AstNode *node, int indent) {
    for (int i = 0; i < indent; i += 1) {
        fprintf(stderr, " ");
    }

    switch (node->type) {
        case NodeTypeRoot:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            for (int i = 0; i < node->data.root.fn_decls.length; i += 1) {
                AstNode *child = node->data.root.fn_decls.at(i);
                print_ast(child, indent + 2);
            }
            break;
        case NodeTypeFnDecl:
            {
                Buf *name_buf = &node->data.fn_decl.name;
                fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                for (int i = 0; i < node->data.fn_decl.params.length; i += 1) {
                    AstNode *child = node->data.fn_decl.params.at(i);
                    print_ast(child, indent + 2);
                }

                print_ast(node->data.fn_decl.return_type, indent + 2);

                print_ast(node->data.fn_decl.body, indent + 2);

                break;
            }
        case NodeTypeParam:
            {
                Buf *name_buf = &node->data.param.name;
                fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                print_ast(node->data.param.type, indent + 2);
                break;
            }
        case NodeTypeType:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            break;
        case NodeTypeBlock:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            break;
    }
}

static void ast_end_fn_param_list(BuildAst *b) {
    b->state = AstStateFnDeclArrow;
}

static AstNode *build_ast(Buf *buf, ZigList<Token> *tokens) {
    BuildAst b = {0};
    b.state = AstStateStart;
    b.buf = buf;
    b.root = allocate<AstNode>(1);
    b.root->type = NodeTypeRoot;
    b.cur_node = b.root;

    for (int i = 0; i < tokens->length; i += 1) {
        Token *token = &tokens->at(i);
        char *token_mem = buf_ptr(buf) + token->start_pos;
        int token_len = token->end_pos - token->start_pos;
        b.line = token->start_line;
        b.column = token->start_column;
        switch (b.state) {
            case AstStateStart:
                assert(b.cur_node->type == NodeTypeRoot);
                if (token->id == TokenIdKeywordFn) {
                    AstNode *child = ast_create_node(&b, NodeTypeFnDecl);
                    b.cur_node->data.root.fn_decls.append(child);
                    ast_make_node_current(&b, child);
                    b.state = AstStateFn;
                } else {
                    Buf msg = {0};
                    buf_appendf(&msg, "unexpected %s: '", token_name(token));
                    buf_append_mem(&msg, token_mem, token_len);
                    buf_append_str(&msg, "'");
                    ast_error(&b, "%s", buf_ptr(&msg));
                    break;
                }
                break;
            case AstStateFn:
                if (token->id != TokenIdSymbol)
                    ast_error(&b, "expected symbol");
                buf_init_from_mem(&b.cur_node->data.fn_decl.name, token_mem, token_len);
                b.state = AstStateFnLParen;
                break;
            case AstStateFnLParen:
                if (token->id != TokenIdLParen)
                    ast_error(&b, "expected '('");
                b.state = AstStateFnParamName;
                break;
            case AstStateFnParamName:
                switch (token->id) {
                    case TokenIdSymbol:
                        {
                            b.state = AstStateFnParamComma;
                            AstNode *child = ast_create_node(&b, NodeTypeParam);
                            buf_init_from_mem(&child->data.param.name, token_mem, token_len);
                            b.cur_node->data.fn_decl.params.append(child);
                            ast_make_node_current(&b, child);
                            b.state = AstStateParamColon;
                            break;
                        }
                    case TokenIdRParen:
                        ast_end_fn_param_list(&b);
                        break;
                    default:
                        ast_error(&b, "expected parameter name");
                        break;
                }
                break;
            case AstStateParamColon:
                {
                    if (token->id != TokenIdColon)
                        ast_error(&b, "expected ':'");
                    assert(b.cur_node->type == NodeTypeParam);
                    b.state = AstStateTypeEnd;
                    AstNode *child = ast_create_node(&b, NodeTypeType);
                    b.cur_node->data.param.type = child;
                    ast_make_node_current(&b, child);
                    b.state = AstStateType;
                    break;
                }
            case AstStateType:
                switch (token->id) {
                    case TokenIdSymbol:
                        assert(b.cur_node->type == NodeTypeType);
                        if (mem_eql_str(token_mem, token_len, "u8")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeU8;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "i8")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeI8;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "u16")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeU16;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "i16")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeI16;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "u32")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeU32;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "i32")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeI32;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "u64")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeU64;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "i64")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeI64;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "usize")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeUSize;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "isize")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeISize;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "f32")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeF32;
                            ast_up_stack(&b);
                        } else if (mem_eql_str(token_mem, token_len, "f64")) {
                            b.cur_node->data.type.type = AstNodeTypeTypePrimitive;
                            b.cur_node->data.type.primitive_type = AstPrimitiveTypeF64;
                            ast_up_stack(&b);
                        } else {
                            Buf msg = {0};
                            buf_append_str(&msg, "invalid primitive type: '");
                            buf_append_mem(&msg, token_mem, token_len);
                            buf_append_str(&msg, "'");
                            ast_error(&b, "%s", buf_ptr(&msg));
                        }
                        break;
                    case TokenIdStar:
                        b.cur_node->data.type.type = AstNodeTypeTypePointer;
                        b.state = AstStatePointerType;
                        break;
                    default:
                        ast_error(&b, "expected type name");
                        break;
                }
                break;
            case AstStatePointerType:
                {
                    if (token->id == TokenIdKeywordMut) {
                        b.cur_node->data.type.is_const = false;
                    } else if (token->id == TokenIdKeywordConst) {
                        b.cur_node->data.type.is_const = true;
                    } else {
                        ast_error(&b, "expected 'mut' or 'const'");
                    }
                    b.state = AstStateTypeEnd;
                    AstNode *child = ast_create_node(&b, NodeTypeType);
                    b.cur_node->data.type.pointer_type = child;
                    ast_make_node_current(&b, child);
                    b.state = AstStateType;
                    break;
                }
            case AstStateTypeEnd:
                ast_up_stack(&b);
                i -= 1;
                continue;
            case AstStateFnParamComma:
                switch (token->id) {
                    case TokenIdComma:
                        b.state = AstStateFnParamName;
                        break;
                    case TokenIdRParen:
                        ast_end_fn_param_list(&b);
                        break;
                    default:
                        ast_error(&b, "expected ',' or ')'");
                        break;

                }
                break;
            case AstStateFnDeclArrow:
                switch (token->id) {
                    case TokenIdArrow:
                        {
                            assert(b.cur_node->type == NodeTypeFnDecl);
                            b.state = AstStateFnDeclBlock;
                            AstNode *child = ast_create_node(&b, NodeTypeType);
                            b.cur_node->data.fn_decl.return_type = child;
                            ast_make_node_current(&b, child);
                            b.state = AstStateType;
                            break;
                        }
                    case TokenIdLBrace:
                        {
                            AstNode *node = ast_create_node(&b, NodeTypeType);
                            node->data.type.type = AstNodeTypeTypePrimitive;
                            node->data.type.primitive_type = AstPrimitiveTypeVoid;
                            b.cur_node->data.fn_decl.return_type = node;

                            b.state = AstStateTypeEnd;
                            AstNode *child = ast_create_node(&b, NodeTypeBlock);
                            b.cur_node->data.fn_decl.body = child;
                            ast_make_node_current(&b, child);
                            b.state = AstStateBlock;
                            break;
                        }
                    default:
                        ast_error(&b, "expected '->' or '}'");
                        break;
                }
                break;
            case AstStateFnDeclBlock:
                {
                    if (token->id != TokenIdLBrace)
                        ast_error(&b, "expected '{'");

                    b.state = AstStateTypeEnd;
                    AstNode *child = ast_create_node(&b, NodeTypeBlock);
                    b.cur_node->data.fn_decl.body = child;
                    ast_make_node_current(&b, child);
                    b.state = AstStateBlock;
                    break;
                }
            case AstStateBlock:
                switch (token->id) {
                    case TokenIdSymbol:
                        zig_panic("TODO symbol");
                        break;
                    default:
                        {
                            Buf msg = {0};
                            buf_appendf(&msg, "unexpected %s: '", token_name(token));
                            buf_append_mem(&msg, token_mem, token_len);
                            buf_append_str(&msg, "'");
                            ast_error(&b, "%s", buf_ptr(&msg));
                            break;
                        }
                }
                break;
        }
    }

    return b.root;
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
        cur_dir_path = buf_create_from_str(result);
    } else {
        in_f = fopen(in_file, "rb");
        if (!in_f)
            zig_panic("unable to open %s for reading: %s\n", in_file, strerror(errno));
        cur_dir_path = buf_dirname(buf_create_from_str(in_file));
    }

    Buf *in_data = fetch_file(in_f);

    fprintf(stderr, "Original source:\n");
    fprintf(stderr, "----------------\n");
    fprintf(stderr, "%s\n", buf_ptr(in_data));

    ZigList<Token> *tokens = tokenize(in_data, &include_paths, cur_dir_path);

    fprintf(stderr, "\nTokens:\n");
    fprintf(stderr, "---------\n");
    print_tokens(in_data, tokens);

    AstNode *root = build_ast(in_data, tokens);
    print_ast(root, 0);


    return EXIT_SUCCESS;
}
