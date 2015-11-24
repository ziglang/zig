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
    ZigList<RuleNode *> children;
    Buf body;
};

struct RuleMany {
    RuleNode *child;
};

struct RuleOr {
    Buf name;
    Buf union_field_name;
    ZigList<RuleNode *> children;
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

    // for lexer use only
    Buf name;
};

enum RuleNodeType {
    RuleNodeTypeTuple,
    RuleNodeTypeMany,
    RuleNodeTypeList,
    RuleNodeTypeOr,
    RuleNodeTypeToken,
    RuleNodeTypeSubRule,
};

struct RuleNode {
    RuleNodeType type;
    int lex_line;
    int lex_column;
    union {
        RuleTuple tuple;
        RuleMany many;
        RuleList list;
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
    Buf *union_field_name;
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
    bool is_error;
};

enum LexState {
    LexStateStart,
    LexStateRuleName,
    LexStateRuleFieldNameStart,
    LexStateRuleFieldName,
    LexStateWaitForColon,
    LexStateTupleRule,
    LexStateFnName,
    LexStateTokenStart,
    LexStateToken,
    LexStateBody,
    LexStateEndOrOr,
    LexStateSubTupleName,
};

struct LexStack {
    LexState state;
};

struct Gen {
    ZigList<RuleNode *> rules;

    ZigList<ParserState *> transition_table;
    ParserState *start_state;
    ZigList<Token *> tokens;
    RuleNode *root;
    int biggest_tuple_len;

    Buf *in_buf;
    LexState lex_state;
    int lex_line;
    int lex_column;
    RuleNode *lex_cur_or_rule;
    RuleNode *lex_cur_tuple_rule;;
    int lex_cur_rule_begin;
    int lex_fn_name_begin;
    int lex_pos;
    ZigList<LexStack> lex_stack;
    int lex_token_name_begin;
    int lex_body_begin;
    int lex_body_end;
    int lex_sub_tuple_begin;
    int lex_field_name_begin;
};

static ParserState *create_state(Gen *g) {
    ParserState *state = allocate<ParserState>(1);
    state->index = -1;
    state->transition = allocate<ParserState*>(g->tokens.length);
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
    state->is_error = true;
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

static CodeGen *codegen_create_capture(Buf *body, bool is_root, int field_name_count, Buf *union_field_name) {
    CodeGen *code = allocate<CodeGen>(1);
    code->type = CodeGenTypeCapture;
    code->capture.body = body;
    code->capture.is_root = is_root;
    code->capture.field_names = allocate<Buf>(field_name_count);
    code->capture.union_field_name = union_field_name;
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


static void gen(Gen *g, RuleNode *node, Buf *out_field_name, ParserState *cur_state,
        ZigList<ParserState *> *end_states, bool is_root)
{
    struct PossibleState {
        ParserState *test_state;
        ZigList<ParserState *> end_states;
    };
    assert(node);
    switch (node->type) {
        case RuleNodeTypeToken:
            {
                buf_init_from_str(out_field_name, "token");

                state_add_save_token(cur_state);

                ParserState *ok_state = create_state(g);
                ParserState *err_state = create_state(g);
                state_add_error(err_state, buf_sprintf("expected token '%s'", buf_ptr(&node->token.token->name)));

                fill_state_with_transition(g, cur_state, err_state);
                cur_state->transition[node->token.token->id] = ok_state;
                state_add_transition(cur_state);
                state_add_eat_token(cur_state);

                end_states->append(ok_state);
            }
            break;
        case RuleNodeTypeTuple:
            {

                int field_name_count = node->tuple.children.length;
                CodeGen *code = codegen_create_capture(&node->tuple.body, is_root, field_name_count,
                        out_field_name);

                ZigList<ParserState *> *my_end_states = allocate<ZigList<ParserState *>>(1);
                my_end_states->append(cur_state);
                for (int child_index = 0; child_index < node->tuple.children.length; child_index += 1) {
                    RuleNode *child = node->tuple.children.at(child_index);

                    ZigList<ParserState *> *more_end_states = allocate<ZigList<ParserState *>>(1);
                    for (int i = 0; i < my_end_states->length; i += 1) {
                        ParserState *use_state = my_end_states->at(i);
                        gen(g, child, &code->capture.field_names[i], use_state, more_end_states, false);
                    }

                    my_end_states = more_end_states;
                }

                for (int i = 0; i < my_end_states->length; i += 1) {
                    ParserState *use_state = my_end_states->at(i);
                    state_add_code(use_state, code);

                    end_states->append(use_state);
                }
            }
            break;
        case RuleNodeTypeMany:
            zig_panic("TODO");
            break;
        case RuleNodeTypeList:
            zig_panic("TODO");
            break;
        case RuleNodeTypeOr:
            {
                buf_init_from_buf(out_field_name, &node->_or.union_field_name);

                state_add_push_node(cur_state);

                // TODO this probably need to get moved when or can handle conflicts
                state_add_save_token(cur_state);
                state_add_transition(cur_state);
                state_add_eat_token(cur_state);


                int possible_state_count = node->_or.children.length;
                PossibleState *possible_states = allocate<PossibleState>(possible_state_count);
                for (int i = 0; i < possible_state_count; i += 1) {
                    RuleNode *child = node->_or.children.at(i);
                    assert(child->type == RuleNodeTypeTuple);

                    PossibleState *possible_state = &possible_states[i];
                    possible_state->test_state = create_state(g);
                    gen(g, child, &node->_or.union_field_name, possible_state->test_state,
                            &possible_state->end_states, is_root);
                }

                // try to merge all the possible states into new state.
                ParserState *err_state = create_state(g);
                state_add_error(err_state, buf_create_from_str("unexpected token"));
                for (int token_i = 0; token_i < g->tokens.length; token_i += 1) {
                    bool any_called_it = false;
                    bool conflict = false;
                    for (int state_i = 0; state_i < possible_state_count; state_i += 1) {
                        PossibleState *possible_state = &possible_states[state_i];
                        if (!possible_state->test_state->transition[token_i]->is_error) {
                            if (any_called_it) {
                                conflict = true;
                            } else {
                                any_called_it = true;
                            }
                        }
                    }
                    if (conflict) {
                        zig_panic("TODO state transition conflict");
                    } else {
                        cur_state->transition[token_i] = err_state;
                        for (int state_i = 0; state_i < possible_state_count; state_i += 1) {
                            PossibleState *possible_state = &possible_states[state_i];
                            if (!possible_state->test_state->transition[token_i]->is_error) {
                                cur_state->transition[token_i] = possible_state->test_state->transition[token_i];
                            }
                        }
                    }
                }

                for (int state_i = 0; state_i < possible_state_count; state_i += 1) {
                    PossibleState *possible_state = &possible_states[state_i];
                    for (int end_i = 0; end_i < possible_state->end_states.length; end_i += 1) {
                        ParserState *state = possible_state->end_states.at(end_i);
                        state_add_pop_node(state);

                        end_states->append(state);
                    }
                }
            }
            break;
        case RuleNodeTypeSubRule:
            {
                RuleNode *child = node->sub_rule.child;
                gen(g, child, out_field_name, cur_state, end_states, false);
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
    fprintf(stderr, "Grammar Error: Line %d, column %d: ", line, column);
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

static RuleNode *create_rule_node(Gen *g) {
    RuleNode *node = allocate<RuleNode>(1);
    node->lex_line = g->lex_line;
    node->lex_column = g->lex_column;
    return node;
}

static void begin_rule(Gen *g) {
    assert(!g->lex_cur_or_rule);
    assert(!g->lex_cur_tuple_rule);

    g->lex_cur_or_rule = create_rule_node(g);
    g->lex_cur_or_rule->type = RuleNodeTypeOr;

    g->lex_cur_tuple_rule = create_rule_node(g);
    g->lex_cur_tuple_rule->type = RuleNodeTypeTuple;
    g->lex_cur_rule_begin = g->lex_pos;
}

static void end_rule(Gen *g) {
    assert(g->lex_cur_or_rule);
    assert(!g->lex_cur_tuple_rule);

    g->rules.append(g->lex_cur_or_rule);
    g->lex_cur_or_rule = nullptr;
}

static void perform_or(Gen *g) {
    assert(g->lex_cur_or_rule);
    assert(!g->lex_cur_tuple_rule);

    g->lex_cur_tuple_rule = create_rule_node(g);
    g->lex_cur_tuple_rule->type = RuleNodeTypeTuple;
    g->lex_cur_rule_begin = g->lex_pos;
}

static void end_rule_name(Gen *g) {
    assert(g->lex_cur_or_rule);
    char *ptr = &buf_ptr(g->in_buf)[g->lex_cur_rule_begin];
    int len = g->lex_pos - g->lex_cur_rule_begin;
    buf_init_from_mem(&g->lex_cur_or_rule->_or.name, ptr, len);
}

static void begin_rule_field_name(Gen *g) {
    assert(g->lex_cur_or_rule);
    g->lex_field_name_begin = g->lex_pos;
}

static void end_rule_field_name(Gen *g) {
    assert(g->lex_cur_or_rule);
    char *ptr = &buf_ptr(g->in_buf)[g->lex_field_name_begin];
    int len = g->lex_pos - g->lex_field_name_begin;
    buf_init_from_mem(&g->lex_cur_or_rule->_or.union_field_name, ptr, len);
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
    assert(g->lex_cur_tuple_rule);
    assert(g->lex_cur_tuple_rule->type == RuleNodeTypeTuple);

    char *ptr = &buf_ptr(g->in_buf)[g->lex_token_name_begin];
    int len = g->lex_pos - g->lex_token_name_begin;
    Buf token_name = {0};
    buf_init_from_mem(&token_name, ptr, len);

    Token *token = find_or_create_token(g, &token_name);
    RuleNode *node = create_rule_node(g);
    node->type = RuleNodeTypeToken;
    node->token.token = token;

    g->lex_cur_tuple_rule->tuple.children.append(node);


    lex_pop_stack(g);
}

static void begin_tuple_body(Gen *g) {
    assert(g->lex_cur_tuple_rule->type == RuleNodeTypeTuple);
    g->lex_body_begin = g->lex_pos;
}

static void end_tuple_body(Gen *g) {
    assert(g->lex_cur_or_rule);
    assert(g->lex_cur_tuple_rule->type == RuleNodeTypeTuple);
    int end_pos = g->lex_pos + 1;
    char *ptr = &buf_ptr(g->in_buf)[g->lex_body_begin];
    int len = end_pos - g->lex_body_begin;
    buf_init_from_mem(&g->lex_cur_tuple_rule->tuple.body, ptr, len);

    g->lex_cur_or_rule->_or.children.append(g->lex_cur_tuple_rule);
    g->lex_cur_tuple_rule = nullptr;
}

static void begin_sub_tuple(Gen *g) {
    g->lex_sub_tuple_begin = g->lex_pos;
    lex_push_stack(g);
}

static void end_sub_tuple(Gen *g) {
    assert(g->lex_cur_tuple_rule->type == RuleNodeTypeTuple);
    char *ptr = &buf_ptr(g->in_buf)[g->lex_sub_tuple_begin];
    int len = g->lex_pos - g->lex_sub_tuple_begin;

    RuleNode *node = create_rule_node(g);
    node->type = RuleNodeTypeSubRule;
    buf_init_from_mem(&node->sub_rule.name, ptr, len);

    g->lex_cur_tuple_rule->tuple.children.append(node);

    lex_pop_stack(g);
}

static RuleNode *find_rule_node(Gen *g, Buf *name) {
    for (int i = 0; i < g->rules.length; i += 1) {
        RuleNode *node = g->rules.at(i);
        assert(node->type == RuleNodeTypeOr);
        if (buf_eql_buf(&node->_or.name, name)) {
            return node;
        }
    }
    return nullptr;
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
                    case '<':
                        end_rule_name(g);
                        g->lex_state = LexStateRuleFieldNameStart;
                        break;
                    case SYMBOL_CHAR:
                        // ok
                        break;
                    default:
                        lex_error(g, "expected '<', not '%c'", c);
                }
                break;
            case LexStateRuleFieldNameStart:
                switch (c) {
                    case SYMBOL_CHAR:
                        begin_rule_field_name(g);
                        g->lex_state = LexStateRuleFieldName;
                        break;
                    default:
                        lex_error(g, "expected field name, not '%c'", c);
                }
                break;
            case LexStateRuleFieldName:
                switch (c) {
                    case SYMBOL_CHAR:
                        // ok
                        break;
                    case '>':
                        end_rule_field_name(g);
                        g->lex_state = LexStateWaitForColon;
                        break;
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
                    case UPPER_ALPHA:
                        begin_sub_tuple(g);
                        g->lex_state = LexStateSubTupleName;
                        break;
                    case '{':
                        begin_tuple_body(g);
                        g->lex_state = LexStateBody;
                        break;
                    default:
                        lex_error(g, "expected rule, not '%c'", c);
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
                        lex_error(g, "expected token name, not '%c'", c);
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
                        lex_error(g, "expected token name or ')', not '%c'", c);
                }
                break;
            case LexStateBody:
                switch (c) {
                    case '}':
                        end_tuple_body(g);
                        g->lex_state = LexStateEndOrOr;
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
                    case '|':
                        perform_or(g);
                        g->lex_state = LexStateTupleRule;
                        break;
                    default:
                        lex_error(g, "expected ';' or '|'");
                }
                break;
            case LexStateSubTupleName:
                switch (c) {
                    case ALPHA:
                        // ignore
                        break;
                    case WHITESPACE:
                        end_sub_tuple(g);
                        assert(g->lex_state == LexStateTupleRule);
                        break;
                    default:
                        lex_error(g, "expected rule name, not '%c'", c);
                }
                break;
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
        case LexStateSubTupleName:
        case LexStateRuleFieldNameStart:
        case LexStateRuleFieldName:
            lex_error(g, "unexpected EOF");
            break;
    }

    // Iterate over the rules and
    //  * resolve child references into pointers
    //  * calculate the biggest tuple len
    bool any_errors = false;
    for (int or_i = 0; or_i < g->rules.length; or_i += 1) {
        RuleNode *or_node = g->rules.at(or_i);
        assert(or_node->type == RuleNodeTypeOr);

        for (int tuple_i = 0; tuple_i < or_node->_or.children.length; tuple_i += 1) {
            RuleNode *tuple_node = or_node->_or.children.at(tuple_i);
            assert(tuple_node->type == RuleNodeTypeTuple);
            g->biggest_tuple_len = max(g->biggest_tuple_len, tuple_node->tuple.children.length);

            for (int child_i = 0; child_i < tuple_node->tuple.children.length; child_i += 1) {
                RuleNode *child = tuple_node->tuple.children.at(child_i);

                if (child->type == RuleNodeTypeSubRule) {
                    int line = child->lex_line + 1;
                    int column = child->lex_column + 1;
                    RuleNode *referenced_node = find_rule_node(g, &child->sub_rule.name);
                    if (!referenced_node) {
                        fprintf(stderr, "Grammar Error: Line %d, column %d: Rule not defined: '%s'\n",
                                line, column, buf_ptr(&child->sub_rule.name));
                        any_errors = true;
                    }
                    child->sub_rule.child = referenced_node;
                }
            }
        }
    }

    if (any_errors) {
        exit(EXIT_FAILURE);
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

static void build_transition_table(Gen *g, ParserState *state) {
    if (!state)
        return;
    if (state->index >= 0)
        return;
    state->index = g->transition_table.length;
    g->transition_table.append(state);
    for (int i = 0; i < g->tokens.length; i += 1) {
        ParserState *other_state = state->transition[i];
        build_transition_table(g, other_state);
    }
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

    g.start_state = create_state(&g);
    Buf root_field_name = {0};
    ZigList<ParserState *> end_states = {0};
    gen(&g, g.root, &root_field_name, g.start_state, &end_states, true);
    build_transition_table(&g, g.start_state);

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
                    fprintf(out_f, "                if (token->id < 0 || token->id >= %d) {\n", g.tokens.length);
                    fprintf(out_f, "                    ast_invalid_token_error(buf, token);\n");
                    fprintf(out_f, "                }\n");
                    fprintf(out_f, "                assert(transition[%d][token->id] >= 0);\n", state->index);
                    fprintf(out_f, "                assert(transition[%d][token->id] < %d);\n",
                            state->index, g.transition_table.length);
                    fprintf(out_f, "                state = transition[%d][token->id];\n", state->index);
                    break;
                case CodeGenTypeError:
                    fprintf(out_f, "                token_index -= 1;\n");
                    fprintf(out_f, "                token = &tokens->at(token_index);\n");
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
                        fprintf(out_f, "                ParserGenNode *parent_node = stack.at(stack.length - 2);\n");
                        Buf *dest = buf_sprintf("parent_node->data[parent_node->next_index++].%s",
                                buf_ptr(code->capture.union_field_name));
                        Buf *code_text = fill_template(code->capture.body, buf_ptr(dest),
                                code->capture.field_names);
                        fprintf(out_f, "%s\n", buf_ptr(code_text));
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
