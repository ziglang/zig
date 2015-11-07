/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "util.hpp"
#include "buffer.hpp"
#include "list.hpp"

#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <limits.h>

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

#define LOWER_ALPHA \
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
    case 'z'

#define UPPER_ALPHA \
    'A': \
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
    LOWER_ALPHA: \
    case UPPER_ALPHA

#define SYMBOL_CHAR \
    ALPHA: \
    case DIGIT: \
    case '_'

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

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s in-grammar.txt out-parser.c\n", arg0);
    return 1;
}

struct Token {
    Buf name;
    int id;
};

struct RuleNode;

struct RuleTuple {
    Buf name;
    ZigList<RuleNode *> children;
    Buf body;
};

struct RuleMany {
    RuleNode *child;
};

struct RuleOption {
    ZigList<RuleNode *> child;
};

struct RuleOr {
    ZigList<RuleTuple *> children;
};

struct RuleToken {
    Token *token;
};

struct RuleList {
    RuleNode *rule;
    RuleToken *separator;
};

struct RuleSubRule {
    RuleNode *child;
};

enum RuleNodeType {
    RuleNodeTypeTuple,
    RuleNodeTypeMany,
    RuleNodeTypeList,
    RuleNodeTypeOption,
    RuleNodeTypeOr,
    RuleNodeTypeToken,
    RuleNodeTypeSubRule,
};

struct RuleNode {
    RuleNodeType type;
    union {
        RuleTuple tuple;
        RuleMany many;
        RuleList list;
        RuleOption option;
        RuleOr _or;
        RuleToken token;
        RuleSubRule sub_rule;
    };
};


enum CodeGenType {
    CodeGenTypeTransition,
    CodeGenTypeError,
    CodeGenTypeSave,
    CodeGenTypePushNode,
    CodeGenTypeCapture,
    CodeGenTypePopNode,
    CodeGenTypeEatToken,
};

struct CodeGenError {
    Buf *msg;
};

struct CodeGenCapture {
    Buf *body;
    bool is_root;
    Buf *field_names;
};

struct CodeGen {
    CodeGenType type;
    union {
        CodeGenError error;
        CodeGenCapture capture;
    };
};

struct ParserState {
    ZigList<CodeGen *> code_gen_list;
    // One for each token ID.
    ParserState **transition;
    int index;
};

enum LexState {
    LexStateStart,
    LexStateRuleName,
    LexStateWaitForColon,
    LexStateTupleRule,
    LexStateFnName,
    LexStateTokenStart,
    LexStateToken,
    LexStateBody,
    LexStateEndOrOr,
};

struct LexStack {
    LexState state;
};

struct Gen {
    ZigList<RuleNode *> rules;
    ParserState *cur_state;
    ZigList<ParserState *> transition_table;
    ZigList<Token *> tokens;
    RuleNode *root;
    int biggest_tuple_len;

    Buf *in_buf;
    LexState lex_state;
    int lex_line;
    int lex_column;
    RuleNode *lex_cur_rule;
    int lex_cur_rule_begin;
    int lex_fn_name_begin;
    int lex_pos;
    ZigList<LexStack> lex_stack;
    int lex_token_name_begin;
    int lex_body_begin;
    int lex_body_end;
};

static ParserState *create_state(Gen *g) {
    ParserState *state = allocate<ParserState>(1);
    state->index = g->transition_table.length;
    state->transition = allocate<ParserState*>(g->tokens.length);
    g->transition_table.append(state);
    return state;
}

static void fill_state_with_transition(Gen *g, ParserState *source, ParserState *dest) {
    for (int i = 0; i < g->tokens.length; i += 1) {
        source->transition[i] = dest;
    }
}

static void state_add_code(ParserState *state, CodeGen *code) {
    state->code_gen_list.append(code);
}

static void state_add_save_token(ParserState *state) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypeSave;
    state_add_code(state, code);
}

static void state_add_error(ParserState *state, Buf *msg) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypeError;
    code->error.msg = msg;
    state_add_code(state, code);
}

static void state_add_transition(ParserState *state) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypeTransition;
    state_add_code(state, code);
}

static void state_add_push_node(ParserState *state) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypePushNode;
    state_add_code(state, code);
}

static CodeGen *codegen_create_capture(Buf *body, bool is_root, int field_name_count) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypeCapture;
    code->capture.body = body;
    code->capture.is_root = is_root;
    code->capture.field_names = allocate<Buf>(field_name_count);
    return code;
}

static void state_add_pop_node(ParserState *state) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypePopNode;
    state_add_code(state, code);
}

static void state_add_eat_token(ParserState *state) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypeEatToken;
    state_add_code(state, code);
}

static void gen(Gen *g, RuleNode *node, Buf *out_field_name) {
    switch (node->type) {
        case RuleNodeTypeToken:
            {
                buf_init_from_str(out_field_name, "token");

                state_add_save_token(g->cur_state);

                ParserState *ok_state = create_state(g);
                ParserState *err_state = create_state(g);
                state_add_error(err_state, buf_sprintf("expected token '%s'", buf_ptr(&node->token.token->name)));

                fill_state_with_transition(g, g->cur_state, err_state);
                g->cur_state->transition[node->token.token->id] = ok_state;
                state_add_transition(g->cur_state);
                state_add_eat_token(g->cur_state);

                g->cur_state = ok_state;
            }
            break;
        case RuleNodeTypeTuple:
            {
                buf_init_from_str(out_field_name, "node");

                state_add_push_node(g->cur_state);

                bool is_root = (node == g->root);
                int field_name_count = node->tuple.children.length;
                CodeGen *code = codegen_create_capture(&node->tuple.body, is_root, field_name_count);

                for (int i = 0; i < node->tuple.children.length; i += 1) {
                    RuleNode *child = node->tuple.children.at(i);
                    gen(g, child, &code->capture.field_names[i]);
                }
                state_add_code(g->cur_state, code);

                state_add_pop_node(g->cur_state);
            }
            break;
        case RuleNodeTypeMany:
            zig_panic("TODO");
            break;
        case RuleNodeTypeList:
            zig_panic("TODO");
            break;
        case RuleNodeTypeOption:
            zig_panic("TODO");
            break;
        case RuleNodeTypeOr:
            zig_panic("TODO");
            break;
        case RuleNodeTypeSubRule:
            {
                RuleNode *child = node->sub_rule.child;
                gen(g, child, out_field_name);
            }
            break;
    }
}

static Token *find_token_by_name(Gen *g, Buf *name) {
    for (int i = 0; i < g->tokens.length; i += 1) {
        Token *token = g->tokens.at(i);
        if (buf_eql_buf(name, &token->name))
            return token;
    }
    return nullptr;
}

static Token *find_or_create_token(Gen *g, Buf *name) {
    Token *token = find_token_by_name(g, name);
    if (!token) {
        token = allocate<Token>(1);
        token->id = g->tokens.length;
        buf_init_from_mem(&token->name, buf_ptr(name), buf_len(name));
        g->tokens.append(token);
    }
    return token;
}

__attribute__ ((format (printf, 2, 3)))
static void lex_error(Gen *g, const char *format, ...) {
    int line = g->lex_line + 1;
    int column = g->lex_column + 1;

    va_list ap;
    va_start(ap, format);
    fprintf(stderr, "Error: Line %d, column %d: ", line, column);
    vfprintf(stderr, format, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(EXIT_FAILURE);
}

static void lex_push_stack(Gen *g) {
    g->lex_stack.append({g->lex_state});
}

static void lex_pop_stack(Gen *g) {
    LexStack *entry = &g->lex_stack.last();
    g->lex_state = entry->state;
    g->lex_stack.pop();
}


static void begin_rule(Gen *g) {
    assert(!g->lex_cur_rule);
    g->lex_cur_rule = allocate<RuleNode>(1);
    g->lex_cur_rule->type = RuleNodeTypeTuple;
    g->lex_cur_rule_begin = g->lex_pos;

    g->lex_state = LexStateEndOrOr;
    lex_push_stack(g);
}

static void end_rule(Gen *g) {
    assert(g->lex_cur_rule);
    g->rules.append(g->lex_cur_rule);
    g->lex_cur_rule = nullptr;
}

static void end_rule_name(Gen *g) {
    assert(g->lex_cur_rule);
    char *ptr = &buf_ptr(g->in_buf)[g->lex_cur_rule_begin];
    int len = g->lex_pos - g->lex_cur_rule_begin;
    buf_init_from_mem(&g->lex_cur_rule->tuple.name, ptr, len);
}

static void begin_fn_name(Gen *g) {
    g->lex_fn_name_begin = g->lex_pos;
    lex_push_stack(g);
}

static void end_fn_name(Gen *g) {
    char *ptr = &buf_ptr(g->in_buf)[g->lex_fn_name_begin];
    int len = g->lex_pos - g->lex_fn_name_begin;
    if (mem_eql_str(ptr, len, "token")) {
        g->lex_state = LexStateTokenStart;
    } else {
        lex_error(g, "invalid function name: '%s'", buf_ptr(buf_create_from_mem(ptr, len)));
    }
}

static void begin_token_name(Gen *g) {
    g->lex_token_name_begin = g->lex_pos;
}

static void end_token_name(Gen *g) {
    char *ptr = &buf_ptr(g->in_buf)[g->lex_token_name_begin];
    int len = g->lex_pos - g->lex_token_name_begin;
    Buf token_name = {0};
    buf_init_from_mem(&token_name, ptr, len);

    Token *token = find_or_create_token(g, &token_name);
    RuleNode *node = allocate<RuleNode>(1);
    node->type = RuleNodeTypeToken;
    node->token.token = token;

    assert(g->lex_cur_rule->type == RuleNodeTypeTuple);
    g->lex_cur_rule->tuple.children.append(node);

    g->biggest_tuple_len = max(g->biggest_tuple_len, g->lex_cur_rule->tuple.children.length);


    lex_pop_stack(g);
}

static void begin_tuple_body(Gen *g) {
    assert(g->lex_cur_rule->type == RuleNodeTypeTuple);
    g->lex_body_begin = g->lex_pos;
}

static void end_tuple_body(Gen *g) {
    assert(g->lex_cur_rule->type == RuleNodeTypeTuple);
    int end_pos = g->lex_pos + 1;
    char *ptr = &buf_ptr(g->in_buf)[g->lex_body_begin];
    int len = end_pos - g->lex_body_begin;
    buf_init_from_mem(&g->lex_cur_rule->tuple.body, ptr, len);
}

static void initialize_rules(Gen *g) {
    g->lex_state = LexStateStart;
    for (g->lex_pos = 0; g->lex_pos < buf_len(g->in_buf); g->lex_pos += 1) {
        uint8_t c = buf_ptr(g->in_buf)[g->lex_pos];
        switch (g->lex_state) {
            case LexStateStart:
                switch (c) {
                    case WHITESPACE:
                        // ignore
                        break;
                    case UPPER_ALPHA:
                        begin_rule(g);
                        g->lex_state = LexStateRuleName;
                        break;
                    default:
                        lex_error(g, "invalid char: '%c'", c);
                }
                break;
            case LexStateRuleName:
                switch (c) {
                    case WHITESPACE:
                        end_rule_name(g);
                        g->lex_state = LexStateWaitForColon;
                        break;
                    case ':':
                        end_rule_name(g);
                        g->lex_state = LexStateTupleRule;
                        break;
                    case SYMBOL_CHAR:
                        break;
                    default:
                        lex_error(g, "invalid char: '%c'", c);
                }
                break;
            case LexStateWaitForColon:
                switch (c) {
                    case WHITESPACE:
                        // ignore
                        break;
                    case ':':
                        g->lex_state = LexStateTupleRule;
                        break;
                    default:
                        lex_error(g, "invalid char: '%c'", c);
                }
                break;
            case LexStateTupleRule:
                switch (c) {
                    case WHITESPACE:
                        // ignore
                        break;
                    case LOWER_ALPHA:
                        begin_fn_name(g);
                        g->lex_state = LexStateFnName;
                        break;
                    case '{':
                        begin_tuple_body(g);
                        g->lex_state = LexStateBody;
                        break;
                    default:
                        lex_error(g, "invalid char: '%c'", c);
                }
                break;
            case LexStateFnName:
                switch (c) {
                    case LOWER_ALPHA:
                        // ignore
                        break;
                    case '(':
                        end_fn_name(g);
                        break;
                    default:
                        lex_error(g, "expected '('");
                }
                break;
            case LexStateTokenStart:
                switch (c) {
                    case WHITESPACE:
                        // ignore
                        break;
                    case ALPHA:
                        begin_token_name(g);
                        g->lex_state = LexStateToken;
                        break;
                    default:
                        lex_error(g, "invalid char '%c'", c);
                }
                break;
            case LexStateToken:
                switch (c) {
                    case ALPHA:
                        // ignore
                        break;
                    case ')':
                        end_token_name(g);
                        break;
                    default:
                        lex_error(g, "invalid char '%c'", c);
                }
                break;
            case LexStateBody:
                switch (c) {
                    case '}':
                        end_tuple_body(g);
                        lex_pop_stack(g);
                        break;
                    default:
                        // ignore
                        break;
                }
                break;
            case LexStateEndOrOr:
                switch (c) {
                    case WHITESPACE:
                        // ignore
                        break;
                    case ';':
                        end_rule(g);
                        g->lex_state = LexStateStart;
                        break;
                    default:
                        lex_error(g, "expected ';' or '|'");
                }
        }
        if (c == '\n') {
            g->lex_line += 1;
            g->lex_column = 0;
        } else {
            g->lex_column += 1;
        }
    }
    switch (g->lex_state) {
        case LexStateStart:
            // ok
            break;
        case LexStateEndOrOr:
        case LexStateRuleName:
        case LexStateWaitForColon:
        case LexStateTupleRule:
        case LexStateFnName:
        case LexStateTokenStart:
        case LexStateToken:
        case LexStateBody:
            lex_error(g, "unexpected EOF");
            break;
    }
}

enum TemplateState {
    TemplateStateStart,
    TemplateStateDollar,
    TemplateStateNumber,
};

static Buf *fill_template(Buf *body, const char *result_name, Buf *field_names) {
    //fprintf(stderr, "fill template input:\n%s\n", buf_ptr(body));
    Buf *result = buf_alloc();
    TemplateState state = TemplateStateStart;
    int digit_start;
    for (int i = 0; i < buf_len(body); i += 1) {
        uint8_t c = buf_ptr(body)[i];
        switch (state) {
            case TemplateStateStart:
                switch (c) {
                    case '$':
                        state = TemplateStateDollar;
                        break;
                    default:
                        buf_append_char(result, c);
                        break;
                }
                break;
            case TemplateStateDollar:
                switch (c) {
                    case '$':
                        buf_append_str(result, result_name);
                        state = TemplateStateStart;
                        break;
                    case DIGIT:
                        digit_start = i;
                        state = TemplateStateNumber;
                        break;
                    default:
                        buf_append_char(result, '$');
                        buf_append_char(result, c);
                        state = TemplateStateStart;
                        break;
                }
                break;
            case TemplateStateNumber:
                switch (c) {
                    case DIGIT:
                        // nothing
                        break;
                    default:
                        {
                            Buf *num_buf = buf_create_from_mem(&buf_ptr(body)[digit_start], i - digit_start);
                            int index = atoi(buf_ptr(num_buf)) - 1;
                            buf_appendf(result, "(top_node->data[%d].%s)%c",
                                    index, buf_ptr(&field_names[index]), c);

                            state = TemplateStateStart;
                        }
                        break;
                }
                break;
        }
    }
    switch (state) {
        case TemplateStateStart:
            // OK
            break;
        default:
            zig_panic("unable to fill grammar template");
    }
    //fprintf(stderr, "fill template output:\n%s\n", buf_ptr(result));
    return result;
}

int main(int argc, char **argv) {
    const char *in_filename = argv[1];
    const char *out_filename = argv[2];

    if (!in_filename || !out_filename)
        return usage(argv[0]);

    FILE *in_f;
    if (strcmp(in_filename, "-") == 0) {
        in_f = stdin;
    } else {
        in_f = fopen(in_filename, "rb");
    }

    FILE *out_f;
    if (strcmp(out_filename, "-") == 0) {
        out_f = stdout;
    } else {
        out_f = fopen(out_filename, "wb");
    }

    if (!in_f || !out_f)
        zig_panic("unable to open file(s)");

    Gen g = {0};

    g.in_buf = fetch_file(in_f);
    initialize_rules(&g);

    g.root = g.rules.at(0);

    g.cur_state = create_state(&g);
    Buf root_field_name = {0};
    gen(&g, g.root, &root_field_name);

    fprintf(out_f, "/* This file is generated by parsergen.cpp */\n");
    fprintf(out_f, "\n");
    fprintf(out_f, "#include \"src/parser.hpp\"\n");
    fprintf(out_f, "#include <stdio.h>\n");

    fprintf(out_f, "\n");
    fprintf(out_f, "/*\n");
    fprintf(out_f, "enum TokenId {\n");
    for (int i = 0; i < g.tokens.length; i += 1) {
        Token *token = g.tokens.at(i);
        fprintf(out_f, "    TokenId%s = %d,\n", buf_ptr(&token->name), token->id);
    }
    fprintf(out_f, "};\n");
    fprintf(out_f, "*/\n");
    for (int i = 0; i < g.tokens.length; i += 1) {
        Token *token = g.tokens.at(i);
        fprintf(out_f, "static_assert(TokenId%s == %d, \"wrong token id\");\n",
                buf_ptr(&token->name), token->id);
    }
    fprintf(out_f, "\n");

    fprintf(out_f, "struct ParserGenNode {\n");
    fprintf(out_f, "    int next_index;\n");
    fprintf(out_f, "    union {\n");
    fprintf(out_f, "        Token *token;\n");
    fprintf(out_f, "        AstNode *node;\n");
    fprintf(out_f, "    } data[%d];\n", g.biggest_tuple_len);
    fprintf(out_f, "};\n");
    fprintf(out_f, "\n");

    fprintf(out_f, "AstNode * ast_parse(Buf *buf, ZigList<Token> *tokens) {\n");

    fprintf(out_f, "    static const int transition[%d][%d] = {\n", g.transition_table.length, g.tokens.length);
    for (int state_index = 0; state_index < g.transition_table.length; state_index += 1) {
        ParserState *state = g.transition_table.at(state_index);
        fprintf(out_f, "        {\n");

        for (int token_id = 0; token_id < g.tokens.length; token_id += 1) {
            ParserState *dest = state->transition[token_id];
            fprintf(out_f, "            %d,\n", dest ? dest->index : -1);
        }

        fprintf(out_f, "        },\n");
    }
    fprintf(out_f, "    };\n");


    fprintf(out_f, "    int state = 0;\n");
    fprintf(out_f, "    int token_index = 0;\n");
    fprintf(out_f, "    Token *token = &tokens->at(token_index);\n");
    fprintf(out_f, "    AstNode *root = nullptr;\n");
    fprintf(out_f, "    ZigList<ParserGenNode *> stack = {0};\n");
    fprintf(out_f, "    ParserGenNode *top_node = nullptr;\n");

    fprintf(out_f, "    for (;;) {\n");
    fprintf(out_f, "        switch (state) {\n");

    for (int state_i = 0; state_i < g.transition_table.length; state_i += 1) {
        ParserState *state = g.transition_table.at(state_i);
        fprintf(out_f, "            case %d: {\n", state_i);
        for (int code_i = 0; code_i < state->code_gen_list.length; code_i += 1) {
            CodeGen *code = state->code_gen_list.at(code_i);
            switch (code->type) {
                case CodeGenTypeTransition:
                    fprintf(out_f, "                assert(transition[%d][token->id] >= 0);\n", state->index);
                    fprintf(out_f, "                assert(transition[%d][token->id] < %d);\n",
                            state->index, g.transition_table.length);
                    fprintf(out_f, "                state = transition[%d][token->id];\n", state->index);
                    break;
                case CodeGenTypeError:
                    fprintf(out_f, "                ast_error(token, \"%s\");\n", buf_ptr(code->error.msg));
                    break;
                case CodeGenTypeSave:
                    fprintf(out_f, "                top_node->data[top_node->next_index++].token = token;\n");
                    break;
                case CodeGenTypePushNode:
                    fprintf(out_f, "                top_node = allocate<ParserGenNode>(1);\n");
                    fprintf(out_f, "                stack.append(top_node);\n");
                    break;
                case CodeGenTypeCapture:
                    if (code->capture.is_root) {
                        Buf *code_text = fill_template(code->capture.body, "root", code->capture.field_names);
                        fprintf(out_f, "%s\n", buf_ptr(code_text));
                        fprintf(out_f, "                return root;\n");
                    } else {
                        zig_panic("TODO capture non-root");
                    }
                    break;
                case CodeGenTypePopNode:
                    fprintf(out_f, "                stack.pop();\n");
                    fprintf(out_f, "                top_node = stack.length ? stack.last() : nullptr;\n");
                    break;
                case CodeGenTypeEatToken:
                    fprintf(out_f, "                token_index += 1;\n");
                    fprintf(out_f, "                token = (token_index < tokens->length) ? &tokens->at(token_index) : nullptr;\n");
                    break;
            }
        }
        fprintf(out_f, "                break;\n");
        fprintf(out_f, "            }\n");
    }
    fprintf(out_f, "            default:\n");
    fprintf(out_f, "                zig_panic(\"unreachable\");\n");

    fprintf(out_f, "        }\n");
    fprintf(out_f, "    }\n");
    fprintf(out_f, "    zig_panic(\"unreachable\");\n");
    fprintf(out_f, "}\n");

    return 0;
}
