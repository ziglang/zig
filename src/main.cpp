/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "config.h"
#include "buffer.hpp"
#include "codegen.hpp"
#include "os.hpp"
#include "error.hpp"

#include <stdio.h>

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s [command] [options] target\n"
        "Commands:\n"
        "  build                  create executable, object, or library from target\n"
        "  version                print version number and exit\n"
        "Optional Options:\n"
        "  --release              build with optimizations on and debug protection off\n"
        "  --static               output will be statically linked\n"
        "  --strip                exclude debug symbols\n"
        "  --export [exe|lib|obj] override output type\n"
        "  --name [name]          override output name\n"
        "  --output [file]        override destination path\n"
        "  --verbose              turn on compiler debug output\n"
        "  --color [auto|off|on]  enable or disable colored error messages\n"
    , arg0);
    return EXIT_FAILURE;
}

static int version(void) {
    printf("%s\n", ZIG_VERSION_STRING);
    return EXIT_SUCCESS;
}

struct Build {
    const char *in_file;
    const char *out_file;
    bool release;
    bool strip;
    bool is_static;
    OutType out_type;
    const char *out_name;
    bool verbose;
    ErrColor color;
};

static int build(const char *arg0, Build *b) {
    int err;

    if (!b->in_file)
        return usage(arg0);

    Buf in_file_buf = BUF_INIT;
    buf_init_from_str(&in_file_buf, b->in_file);

    Buf root_source_dir = BUF_INIT;
    Buf root_source_code = BUF_INIT;
    Buf root_source_name = BUF_INIT;
    if (buf_eql_str(&in_file_buf, "-")) {
        os_get_cwd(&root_source_dir);
        if ((err = os_fetch_file(stdin, &root_source_code))) {
            fprintf(stderr, "unable to read stdin: %s\n", err_str(err));
            return 1;
        }
        buf_init_from_str(&root_source_name, "");
    } else {
        os_path_split(&in_file_buf, &root_source_dir, &root_source_name);
        if ((err = os_fetch_file_path(buf_create_from_str(b->in_file), &root_source_code))) {
            fprintf(stderr, "unable to open '%s': %s\n", b->in_file, err_str(err));
            return 1;
        }
    }

    CodeGen *g = codegen_create(&root_source_dir);
    codegen_set_build_type(g, b->release ? CodeGenBuildTypeRelease : CodeGenBuildTypeDebug);
    codegen_set_strip(g, b->strip);
    codegen_set_is_static(g, b->is_static);
    if (b->out_type != OutTypeUnknown)
        codegen_set_out_type(g, b->out_type);
    if (b->out_name)
        codegen_set_out_name(g, buf_create_from_str(b->out_name));
    codegen_set_verbose(g, b->verbose);
    codegen_set_errmsg_color(g, b->color);
    codegen_add_root_code(g, &root_source_name, &root_source_code);
    codegen_link(g, b->out_file);

    return 0;
}

enum Cmd {
    CmdNone,
    CmdBuild,
    CmdVersion,
};

int main(int argc, char **argv) {
    char *arg0 = argv[0];

    Build b = {0};
    Cmd cmd = CmdNone;

    for (int i = 1; i < argc; i += 1) {
        char *arg = argv[i];
        if (arg[0] == '-' && arg[1] == '-') {
            if (strcmp(arg, "--release") == 0) {
                b.release = true;
            } else if (strcmp(arg, "--strip") == 0) {
                b.strip = true;
            } else if (strcmp(arg, "--static") == 0) {
                b.is_static = true;
            } else if (strcmp(arg, "--verbose") == 0) {
                b.verbose = true;
            } else if (i + 1 >= argc) {
                return usage(arg0);
            } else {
                i += 1;
                if (i >= argc) {
                    return usage(arg0);
                } else if (strcmp(arg, "--output") == 0) {
                    b.out_file = argv[i];
                } else if (strcmp(arg, "--export") == 0) {
                    if (strcmp(argv[i], "exe") == 0) {
                        b.out_type = OutTypeExe;
                    } else if (strcmp(argv[i], "lib") == 0) {
                        b.out_type = OutTypeLib;
                    } else if (strcmp(argv[i], "obj") == 0) {
                        b.out_type = OutTypeObj;
                    } else {
                        return usage(arg0);
                    }
                } else if (strcmp(arg, "--color") == 0) {
                    if (strcmp(argv[i], "auto") == 0) {
                        b.color = ErrColorAuto;
                    } else if (strcmp(argv[i], "on") == 0) {
                        b.color = ErrColorOn;
                    } else if (strcmp(argv[i], "off") == 0) {
                        b.color = ErrColorOff;
                    } else {
                        return usage(arg0);
                    }
                } else if (strcmp(arg, "--name") == 0) {
                    b.out_name = argv[i];
                } else {
                    return usage(arg0);
                }
            }
        } else if (cmd == CmdNone) {
            if (strcmp(arg, "build") == 0) {
                cmd = CmdBuild;
            } else if (strcmp(arg, "version") == 0) {
                cmd = CmdVersion;
            } else {
                fprintf(stderr, "Unrecognized command: %s\n", arg);
                return usage(arg0);
            }
        } else {
            switch (cmd) {
                case CmdNone:
                    zig_unreachable();
                case CmdBuild:
                    if (!b.in_file) {
                        b.in_file = arg;
                    } else {
                        return usage(arg0);
                    }
                    break;
                case CmdVersion:
                    return usage(arg0);
            }
        }
    }

    switch (cmd) {
        case CmdNone:
            return usage(arg0);
        case CmdBuild:
            return build(arg0, &b);
        case CmdVersion:
            return version();
    }

    zig_unreachable();
}
