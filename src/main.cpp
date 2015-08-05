/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "config.h"
#include "util.hpp"
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

    //tokenize(in_data);


    return EXIT_SUCCESS;
}
