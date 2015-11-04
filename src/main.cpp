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
#include "parser.hpp"
#include "tokenizer.hpp"

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

void ast_error(Token *token, const char *format, ...) {
    int line = token->start_line + 1;
    int column = token->start_column + 1;

    va_list ap;
    va_start(ap, format);
    fprintf(stderr, "Error: Line %d, column %d: ", line, column);
    vfprintf(stderr, format, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(EXIT_FAILURE);
}

static const char *node_type_str(NodeType node_type) {
    switch (node_type) {
        case NodeTypeRoot:
            return "Root";
        case NodeTypeFnDecl:
            return "FnDecl";
        case NodeTypeParamDecl:
            return "ParamDecl";
        case NodeTypeType:
            return "Type";
        case NodeTypePointerType:
            return "PointerType";
        case NodeTypeBlock:
            return "Block";
        case NodeTypeStatement:
            return "Statement";
        case NodeTypeExpressionStatement:
            return "ExpressionStatement";
        case NodeTypeReturnStatement:
            return "ReturnStatement";
        case NodeTypeExpression:
            return "Expression";
        case NodeTypeFnCall:
            return "FnCall";
    }
    zig_panic("unreachable");
}

static void ast_print(AstNode *node, int indent) {
    for (int i = 0; i < indent; i += 1) {
        fprintf(stderr, " ");
    }

    switch (node->type) {
        case NodeTypeRoot:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            for (int i = 0; i < node->data.root.fn_decls.length; i += 1) {
                AstNode *child = node->data.root.fn_decls.at(i);
                ast_print(child, indent + 2);
            }
            break;
        case NodeTypeFnDecl:
            {
                Buf *name_buf = &node->data.fn_decl.name;
                fprintf(stderr, "%s '%s'\n", node_type_str(node->type), buf_ptr(name_buf));

                for (int i = 0; i < node->data.fn_decl.params.length; i += 1) {
                    AstNode *child = node->data.fn_decl.params.at(i);
                    ast_print(child, indent + 2);
                }

                ast_print(node->data.fn_decl.return_type, indent + 2);

                ast_print(node->data.fn_decl.body, indent + 2);

                break;
            }
        default:
            fprintf(stderr, "%s\n", node_type_str(node->type));
            break;
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

    ZigList<Token> *tokens = tokenize(in_data, cur_dir_path);

    fprintf(stderr, "\nTokens:\n");
    fprintf(stderr, "---------\n");
    print_tokens(in_data, tokens);

    AstNode *root = ast_parse(in_data, tokens);
    assert(root);
    ast_print(root, 0);


    return EXIT_SUCCESS;
}
