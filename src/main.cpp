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
    fprintf(stderr, "Usage: %s [command] [options]\n"
        "Commands:\n"
        "  build                  create executable, object, or library from target\n"
        "  version                print version number and exit\n"
        "  parseh                 convert a c header file to zig extern declarations\n"
        "Options:\n"
        "  --release              build with optimizations on and debug protection off\n"
        "  --static               output will be statically linked\n"
        "  --strip                exclude debug symbols\n"
        "  --export [exe|lib|obj] override output type\n"
        "  --name [name]          override output name\n"
        "  --output [file]        override destination path\n"
        "  --verbose              turn on compiler debug output\n"
        "  --color [auto|off|on]  enable or disable colored error messages\n"
        "  --libc-path [path]     set the C compiler data path\n"
        "  -isystem [dir]         add additional search path for other .h files\n"
        "  -dirafter [dir]        same as -isystem but do it last\n"
        "  --library-path [dir]   add a directory to the library search path\n"
    , arg0);
    return EXIT_FAILURE;
}

enum Cmd {
    CmdInvalid,
    CmdBuild,
    CmdVersion,
    CmdParseH,
};

int main(int argc, char **argv) {
    char *arg0 = argv[0];
    Cmd cmd = CmdInvalid;
    const char *in_file = nullptr;
    const char *out_file = nullptr;
    bool release = false;
    bool strip = false;
    bool is_static = false;
    OutType out_type = OutTypeUnknown;
    const char *out_name = nullptr;
    bool verbose = false;
    ErrColor color = ErrColorAuto;
    const char *libc_path = nullptr;
    ZigList<const char *> clang_argv = {0};
    ZigList<const char *> lib_dirs = {0};
    int err;

    for (int i = 1; i < argc; i += 1) {
        char *arg = argv[i];

        if (arg[0] == '-') {
            if (strcmp(arg, "--release") == 0) {
                release = true;
            } else if (strcmp(arg, "--strip") == 0) {
                strip = true;
            } else if (strcmp(arg, "--static") == 0) {
                is_static = true;
            } else if (strcmp(arg, "--verbose") == 0) {
                verbose = true;
            } else if (i + 1 >= argc) {
                return usage(arg0);
            } else {
                i += 1;
                if (i >= argc) {
                    return usage(arg0);
                } else if (strcmp(arg, "--output") == 0) {
                    out_file = argv[i];
                } else if (strcmp(arg, "--export") == 0) {
                    if (strcmp(argv[i], "exe") == 0) {
                        out_type = OutTypeExe;
                    } else if (strcmp(argv[i], "lib") == 0) {
                        out_type = OutTypeLib;
                    } else if (strcmp(argv[i], "obj") == 0) {
                        out_type = OutTypeObj;
                    } else {
                        return usage(arg0);
                    }
                } else if (strcmp(arg, "--color") == 0) {
                    if (strcmp(argv[i], "auto") == 0) {
                        color = ErrColorAuto;
                    } else if (strcmp(argv[i], "on") == 0) {
                        color = ErrColorOn;
                    } else if (strcmp(argv[i], "off") == 0) {
                        color = ErrColorOff;
                    } else {
                        return usage(arg0);
                    }
                } else if (strcmp(arg, "--name") == 0) {
                    out_name = argv[i];
                } else if (strcmp(arg, "--libc-path") == 0) {
                    libc_path = argv[i];
                } else if (strcmp(arg, "-isystem") == 0) {
                    clang_argv.append("-isystem");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-dirafter") == 0) {
                    clang_argv.append("-dirafter");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "--library-path") == 0) {
                    lib_dirs.append(argv[i]);
                } else {
                    return usage(arg0);
                }
            }
        } else if (cmd == CmdInvalid) {
            if (strcmp(arg, "build") == 0) {
                cmd = CmdBuild;
            } else if (strcmp(arg, "version") == 0) {
                cmd = CmdVersion;
            } else if (strcmp(arg, "parseh") == 0) {
                cmd = CmdParseH;
            } else {
                fprintf(stderr, "Unrecognized command: %s\n", arg);
                return usage(arg0);
            }
        } else {
            switch (cmd) {
                case CmdBuild:
                case CmdParseH:
                    if (!in_file) {
                        in_file = arg;
                    } else {
                        return usage(arg0);
                    }
                    break;
                case CmdVersion:
                    return usage(arg0);
                case CmdInvalid:
                    zig_unreachable();
            }
        }
    }

    switch (cmd) {
    case CmdBuild:
    case CmdParseH:
        {
            if (!in_file)
                return usage(arg0);

            Buf in_file_buf = BUF_INIT;
            buf_init_from_str(&in_file_buf, in_file);

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
                if ((err = os_fetch_file_path(buf_create_from_str(in_file), &root_source_code))) {
                    fprintf(stderr, "unable to open '%s': %s\n", in_file, err_str(err));
                    return 1;
                }
            }

            CodeGen *g = codegen_create(&root_source_dir);
            codegen_set_build_type(g, release ? CodeGenBuildTypeRelease : CodeGenBuildTypeDebug);
            codegen_set_clang_argv(g, clang_argv.items, clang_argv.length);
            codegen_set_strip(g, strip);
            codegen_set_is_static(g, is_static);
            if (out_type != OutTypeUnknown)
                codegen_set_out_type(g, out_type);
            if (out_name)
                codegen_set_out_name(g, buf_create_from_str(out_name));
            if (libc_path)
                codegen_set_libc_path(g, buf_create_from_str(libc_path));
            codegen_set_verbose(g, verbose);
            codegen_set_errmsg_color(g, color);

            for (int i = 0; i < lib_dirs.length; i += 1) {
                codegen_add_lib_dir(g, lib_dirs.at(i));
            }

            if (cmd == CmdBuild) {
                codegen_add_root_code(g, &root_source_dir, &root_source_name, &root_source_code);
                codegen_link(g, out_file);
                return EXIT_SUCCESS;
            } else if (cmd == CmdParseH) {
                codegen_parseh(g, &root_source_dir, &root_source_name, &root_source_code);
                codegen_render_ast(g, stdout, 4);
                return EXIT_SUCCESS;
            } else {
                zig_unreachable();
            }
        }
    case CmdVersion:
        printf("%s\n", ZIG_VERSION_STRING);
        return EXIT_SUCCESS;
    case CmdInvalid:
        return usage(arg0);
    }
}
