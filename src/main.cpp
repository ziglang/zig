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
#include "error.hpp"
#include "codegen.hpp"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include <stdint.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <inttypes.h>

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s [command] [options] target\n"
        "Commands:\n"
        "  build          create an executable from target\n"
        "Options:\n"
        "  --output       output file\n"
        "  --version      print version number and exit\n"
        "  -Ipath         add path to header include path\n"
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

static int build(const char *arg0, const char *in_file, const char *out_file, ZigList<char *> *include_paths) {
    static char cur_dir[1024];

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

    fprintf(stderr, "Original source:\n");
    fprintf(stderr, "----------------\n");
    Buf *in_data = fetch_file(in_f);
    fprintf(stderr, "%s\n", buf_ptr(in_data));

    fprintf(stderr, "\nTokens:\n");
    fprintf(stderr, "---------\n");
    ZigList<Token> *tokens = tokenize(in_data, cur_dir_path);
    print_tokens(in_data, tokens);

    fprintf(stderr, "\nAST:\n");
    fprintf(stderr, "------\n");
    AstNode *root = ast_parse(in_data, tokens);
    assert(root);
    ast_print(root, 0);

    fprintf(stderr, "\nSemantic Analysis:\n");
    fprintf(stderr, "--------------------\n");
    CodeGen *codegen = create_codegen(root);
    semantic_analyze(codegen);
    ZigList<ErrorMsg> *errors = codegen_error_messages(codegen);
    if (errors->length == 0) {
        fprintf(stderr, "OK\n");
    } else {
        for (int i = 0; i < errors->length; i += 1) {
            ErrorMsg *err = &errors->at(i);
            fprintf(stderr, "Error: Line %d, column %d: %s\n", err->line_start, err->column_start,
                    buf_ptr(err->msg));
        }
        return 1;
    }

    fprintf(stderr, "\nCode Generation:\n");
    fprintf(stderr, "------------------\n");
    code_gen(codegen);

    return 0;
}

enum Cmd {
    CmdNone,
    CmdBuild,
};

int main(int argc, char **argv) {
    char *arg0 = argv[0];
    char *in_file = NULL;
    char *out_file = NULL;
    ZigList<char *> include_paths = {0};

    Cmd cmd = CmdNone;
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
        } else if (cmd == CmdNone) {
            if (strcmp(arg, "build") == 0) {
                cmd = CmdBuild;
            } else {
                fprintf(stderr, "Unrecognized command: %s\n", arg);
                return usage(arg0);
            }
        } else {
            switch (cmd) {
                case CmdNone:
                    zig_unreachable();
                case CmdBuild:
                    if (!in_file) {
                        in_file = arg;
                    } else {
                        return usage(arg0);
                    }
                    break;
            }
        }
    }

    switch (cmd) {
        case CmdNone:
            return usage(arg0);
        case CmdBuild:
            return build(arg0, in_file, out_file, &include_paths);
    }

    zig_unreachable();
}

