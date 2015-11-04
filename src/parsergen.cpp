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
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <limits.h>

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

struct RuleBlock {
    Buf *body;
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

enum ParserStateType {
    ParserStateTypeError,
    ParserStateTypeOk,
};

struct ParserStateError {
    Buf *msg;
};

struct ParserState {
    ParserStateType type;
    // One for each token ID.
    ParserState **transition;
    int index;
    union {
        ParserStateError error;
    };
};

struct Gen {
    ParserState *cur_state;
    ZigList<ParserState *> transition_table;
    ZigList<Token *> tokens;
    RuleNode *root;
};

static ParserState *create_state(Gen *g, ParserStateType type) {
    ParserState *state = allocate<ParserState>(1);
    state->type = type;
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

static void gen(Gen *g, RuleNode *node) {
    switch (node->type) {
        case RuleNodeTypeToken:
            {
                ParserState *ok_state = create_state(g, ParserStateTypeOk);
                ParserState *err_state = create_state(g, ParserStateTypeError);

                err_state->error.msg = buf_sprintf("expected token '%s'", buf_ptr(&node->token.token->name));

                fill_state_with_transition(g, g->cur_state, err_state);
                g->cur_state->transition[node->token.token->id] = ok_state;
                g->cur_state = ok_state;
            }
            break;
        case RuleNodeTypeTuple:
            {
                for (int i = 0; i < node->tuple.children.length; i += 1) {
                    RuleNode *child = node->tuple.children.at(i);
                    gen(g, child);
                }
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
            zig_panic("TODO");
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

    Buf *in_buf = fetch_file(in_f);

    ZigList<RuleNode *> rules = {0};
    Gen g = {0};

    //zig_panic("TODO initialize rules");
    {
        Token *star_token = find_or_create_token(&g, buf_create_from_str("Star"));
        Token *lparen_token = find_or_create_token(&g, buf_create_from_str("LParen"));
        Token *eof_token = find_or_create_token(&g, buf_create_from_str("Eof"));

        RuleNode *root = allocate<RuleNode>(1);
        root->type = RuleNodeTypeTuple;

        RuleNode *star_node = allocate<RuleNode>(1);
        star_node->type = RuleNodeTypeToken;
        star_node->token.token = star_token;
        root->tuple.children.append(star_node);

        RuleNode *lparen_node = allocate<RuleNode>(1);
        lparen_node->type = RuleNodeTypeToken;
        lparen_node->token.token = lparen_token;
        root->tuple.children.append(lparen_node);

        RuleNode *eof_node = allocate<RuleNode>(1);
        eof_node->type = RuleNodeTypeToken;
        eof_node->token.token = eof_token;
        root->tuple.children.append(eof_node);

        rules.append(root);
    }

    g.root = rules.at(0);

    g.cur_state = create_state(&g, ParserStateTypeOk);
    gen(&g, g.root);



    (void)in_buf;

    fprintf(out_f, "/* This file is auto-generated by parsergen.cpp */\n");
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
    fprintf(out_f, "    AstNode *root = nullptr;\n");

    fprintf(out_f, "    for (int i = 0; i < tokens->length; i += 1) {\n");
    fprintf(out_f, "        Token *token = &tokens->at(i);\n");
    fprintf(out_f, "        switch (state) {\n");

    for (int i = 0; i < g.transition_table.length; i += 1) {
        ParserState *state = g.transition_table.at(i);
        fprintf(out_f, "            case %d:\n", i);
        fprintf(out_f, "                fprintf(stderr, \"state = %%d\\n\", state);\n");
        switch (state->type) {
            case ParserStateTypeError:
                fprintf(out_f, "                ast_error(token, \"%s\");\n", buf_ptr(state->error.msg));
                break;
            case ParserStateTypeOk:
                fprintf(out_f, "                assert(transition[%d][token->id] >= 0);\n", state->index);
                fprintf(out_f, "                assert(transition[%d][token->id] < %d);\n",
                        state->index, g.transition_table.length);
                fprintf(out_f, "                state = transition[%d][token->id];\n", state->index);
                break;
        }
        fprintf(out_f, "                break;\n");
    }
    fprintf(out_f, "            default:\n");
    fprintf(out_f, "                zig_panic(\"unreachable\");\n");

    fprintf(out_f, "        }\n");
    fprintf(out_f, "    }\n");
    fprintf(out_f, "    return root;\n");
    fprintf(out_f, "}\n");


}
