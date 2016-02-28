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
#include "target.hpp"
#include "link.hpp"

#include <stdio.h>

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s [command] [options]\n"
        "Commands:\n"
        "  build [sources]              create executable, object, or library from source\n"
        "  test [sources]               create and run a test build\n"
        "  parseh [source]              convert a c header file to zig extern declarations\n"
        "  version                      print version number and exit\n"
        "  targets                      list available compilation targets\n"
        "Options:\n"
        "  --release                    build with optimizations on and debug protection off\n"
        "  --static                     output will be statically linked\n"
        "  --strip                      exclude debug symbols\n"
        "  --export [exe|lib|obj]       override output type\n"
        "  --name [name]                override output name\n"
        "  --output [file]              override destination path\n"
        "  --verbose                    turn on compiler debug output\n"
        "  --color [auto|off|on]        enable or disable colored error messages\n"
        "  --libc-lib-dir [path]        directory where libc crt1.o resides\n"
        "  --libc-static-lib-dir [path] directory where libc crtbegin.o resides\n"
        "  --libc-include-dir [path]    directory where libc stdlib.h resides\n"
        "  --dynamic-linker [path]      set the path to ld.so\n"
        "  --ld-path [path]             set the path to the linker\n"
        "  -isystem [dir]               add additional search path for other .h files\n"
        "  -dirafter [dir]              same as -isystem but do it last\n"
        "  --library-path [dir]         add a directory to the library search path\n"
        "  --library [lib]              link against lib\n"
        "  --target-arch [name]         specify target architecture\n"
        "  --target-os [name]           specify target operating system\n"
        "  --target-environ [name]      specify target environment\n"
        "  -mwindows                    (windows only) --subsystem windows to the linker\n"
        "  -mconsole                    (windows only) --subsystem console to the linker\n"
        "  -municode                    (windows only) link with unicode\n"
        "  -mlinker-version [ver]       (darwin only) override linker version\n"
        "  -rdynamic                    add all symbols to the dynamic symbol table\n"
        "  -mmacosx-version-min [ver]   (darwin only) set Mac OS X deployment target\n"
        "  -mios-version-min [ver]      (darwin only) set iOS deployment target\n"
        "  --check-unused               perform semantic analysis on unused declarations\n"
    , arg0);
    return EXIT_FAILURE;
}

static int print_target_list(FILE *f) {
    ZigTarget native;
    get_native_target(&native);

    fprintf(f, "Architectures:\n");
    int arch_count = target_arch_count();
    for (int arch_i = 0; arch_i < arch_count; arch_i += 1) {
        const ArchType *arch = get_target_arch(arch_i);
        char arch_name[50];
        get_arch_name(arch_name, arch);
        const char *native_str = (native.arch.arch == arch->arch && native.arch.sub_arch == arch->sub_arch) ?
            " (native)" : "";
        fprintf(f, "  %s%s\n", arch_name, native_str);
    }

    fprintf(f, "\nOperating Systems:\n");
    int os_count = target_os_count();
    for (int i = 0; i < os_count; i += 1) {
        ZigLLVM_OSType os_type = get_target_os(i);
        const char *native_str = (native.os == os_type) ? " (native)" : "";
        fprintf(f, "  %s%s\n", get_target_os_name(os_type), native_str);
    }

    fprintf(f, "\nEnvironments:\n");
    int environ_count = target_environ_count();
    for (int i = 0; i < environ_count; i += 1) {
        ZigLLVM_EnvironmentType environ_type = get_target_environ(i);
        const char *native_str = (native.env_type == environ_type) ? " (native)" : "";
        fprintf(f, "  %s%s\n", ZigLLVMGetEnvironmentTypeName(environ_type), native_str);
    }

    return EXIT_SUCCESS;
}

enum Cmd {
    CmdInvalid,
    CmdBuild,
    CmdTest,
    CmdVersion,
    CmdParseH,
    CmdTargets,
};

int main(int argc, char **argv) {
    os_init();

    char *arg0 = argv[0];
    Cmd cmd = CmdInvalid;
    const char *in_file = nullptr;
    const char *out_file = nullptr;
    bool is_release_build = false;
    bool strip = false;
    bool is_static = false;
    OutType out_type = OutTypeUnknown;
    const char *out_name = nullptr;
    bool verbose = false;
    ErrColor color = ErrColorAuto;
    const char *libc_lib_dir = nullptr;
    const char *libc_static_lib_dir = nullptr;
    const char *libc_include_dir = nullptr;
    const char *dynamic_linker = nullptr;
    const char *linker_path = nullptr;
    ZigList<const char *> clang_argv = {0};
    ZigList<const char *> lib_dirs = {0};
    ZigList<const char *> link_libs = {0};
    int err;
    const char *target_arch = nullptr;
    const char *target_os = nullptr;
    const char *target_environ = nullptr;
    bool mwindows = false;
    bool mconsole = false;
    bool municode = false;
    const char *mlinker_version = nullptr;
    bool rdynamic = false;
    const char *mmacosx_version_min = nullptr;
    const char *mios_version_min = nullptr;
    bool check_unused = false;

    for (int i = 1; i < argc; i += 1) {
        char *arg = argv[i];

        if (arg[0] == '-') {
            if (strcmp(arg, "--release") == 0) {
                is_release_build = true;
            } else if (strcmp(arg, "--strip") == 0) {
                strip = true;
            } else if (strcmp(arg, "--static") == 0) {
                is_static = true;
            } else if (strcmp(arg, "--verbose") == 0) {
                verbose = true;
            } else if (strcmp(arg, "-mwindows") == 0) {
                mwindows = true;
            } else if (strcmp(arg, "-mconsole") == 0) {
                mconsole = true;
            } else if (strcmp(arg, "-municode") == 0) {
                municode = true;
            } else if (strcmp(arg, "-rdynamic") == 0) {
                rdynamic = true;
            } else if (strcmp(arg, "--check-unused") == 0) {
                check_unused = true;
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
                } else if (strcmp(arg, "--libc-lib-dir") == 0) {
                    libc_lib_dir = argv[i];
                } else if (strcmp(arg, "--libc-static-lib-dir") == 0) {
                    libc_static_lib_dir = argv[i];
                } else if (strcmp(arg, "--libc-include-dir") == 0) {
                    libc_include_dir = argv[i];
                } else if (strcmp(arg, "--dynamic-linker") == 0) {
                    dynamic_linker = argv[i];
                } else if (strcmp(arg, "--ld-path") == 0) {
                    linker_path = argv[i];
                } else if (strcmp(arg, "-isystem") == 0) {
                    clang_argv.append("-isystem");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-dirafter") == 0) {
                    clang_argv.append("-dirafter");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "--library-path") == 0) {
                    lib_dirs.append(argv[i]);
                } else if (strcmp(arg, "--library") == 0) {
                    link_libs.append(argv[i]);
                } else if (strcmp(arg, "--target-arch") == 0) {
                    target_arch = argv[i];
                } else if (strcmp(arg, "--target-os") == 0) {
                    target_os = argv[i];
                } else if (strcmp(arg, "--target-environ") == 0) {
                    target_environ = argv[i];
                } else if (strcmp(arg, "-mlinker-version") == 0) {
                    mlinker_version = argv[i];
                } else if (strcmp(arg, "-mmacosx-version-min") == 0) {
                    mmacosx_version_min = argv[i];
                } else if (strcmp(arg, "-mios-version-min") == 0) {
                    mios_version_min = argv[i];
                } else {
                    fprintf(stderr, "Invalid argument: %s\n", arg);
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
            } else if (strcmp(arg, "test") == 0) {
                cmd = CmdTest;
            } else if (strcmp(arg, "targets") == 0) {
                cmd = CmdTargets;
            } else {
                fprintf(stderr, "Unrecognized command: %s\n", arg);
                return usage(arg0);
            }
        } else {
            switch (cmd) {
                case CmdBuild:
                case CmdParseH:
                case CmdTest:
                    if (!in_file) {
                        in_file = arg;
                    } else {
                        return usage(arg0);
                    }
                    break;
                case CmdVersion:
                case CmdTargets:
                    return usage(arg0);
                case CmdInvalid:
                    zig_unreachable();
            }
        }
    }

    switch (cmd) {
    case CmdBuild:
    case CmdParseH:
    case CmdTest:
        {
            if (!in_file)
                return usage(arg0);

            if (cmd == CmdBuild && !out_name) {
                fprintf(stderr, "--name [name] not provided\n\n");
                return usage(arg0);
            }

            if (cmd == CmdBuild && out_type == OutTypeUnknown) {
                fprintf(stderr, "--export [exe|lib|obj] not provided\n\n");
                return usage(arg0);
            }

            init_all_targets();

            ZigTarget alloc_target;
            ZigTarget *target;
            if (!target_arch && !target_os && !target_environ) {
                target = nullptr;
            } else {
                target = &alloc_target;
                get_unknown_target(target);
                if (target_arch) {
                    if (parse_target_arch(target_arch, &target->arch)) {
                        fprintf(stderr, "invalid --target-arch argument\n");
                        return usage(arg0);
                    }
                }
                if (target_os) {
                    if (parse_target_os(target_os, &target->os)) {
                        fprintf(stderr, "invalid --target-os argument\n");
                        return usage(arg0);
                    }
                }
                if (target_environ) {
                    if (parse_target_environ(target_environ, &target->env_type)) {
                        fprintf(stderr, "invalid --target-environ argument\n");
                        return usage(arg0);
                    }
                }
            }


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

            CodeGen *g = codegen_create(&root_source_dir, target);
            codegen_set_is_release(g, is_release_build);
            codegen_set_is_test(g, cmd == CmdTest);

            codegen_set_check_unused(g, check_unused);

            codegen_set_clang_argv(g, clang_argv.items, clang_argv.length);
            codegen_set_strip(g, strip);
            codegen_set_is_static(g, is_static);
            if (out_type != OutTypeUnknown) {
                codegen_set_out_type(g, out_type);
            } else if (cmd == CmdTest) {
                codegen_set_out_type(g, OutTypeExe);
            }
            if (out_name) {
                codegen_set_out_name(g, buf_create_from_str(out_name));
            } else if (cmd == CmdTest) {
                codegen_set_out_name(g, buf_create_from_str("test"));
            }
            if (libc_lib_dir)
                codegen_set_libc_lib_dir(g, buf_create_from_str(libc_lib_dir));
            if (libc_static_lib_dir)
                codegen_set_libc_static_lib_dir(g, buf_create_from_str(libc_static_lib_dir));
            if (libc_include_dir)
                codegen_set_libc_include_dir(g, buf_create_from_str(libc_include_dir));
            if (dynamic_linker)
                codegen_set_dynamic_linker(g, buf_create_from_str(dynamic_linker));
            if (linker_path)
                codegen_set_linker_path(g, buf_create_from_str(linker_path));
            codegen_set_verbose(g, verbose);
            codegen_set_errmsg_color(g, color);

            for (int i = 0; i < lib_dirs.length; i += 1) {
                codegen_add_lib_dir(g, lib_dirs.at(i));
            }
            for (int i = 0; i < link_libs.length; i += 1) {
                codegen_add_link_lib(g, link_libs.at(i));
            }

            codegen_set_windows_subsystem(g, mwindows, mconsole);
            codegen_set_windows_unicode(g, municode);
            codegen_set_rdynamic(g, rdynamic);
            if (mlinker_version) {
                codegen_set_mlinker_version(g, buf_create_from_str(mlinker_version));
            }
            if (mmacosx_version_min && mios_version_min) {
                fprintf(stderr, "-mmacosx-version-min and -mios-version-min options not allowed together\n");
                return EXIT_FAILURE;
            }
            if (mmacosx_version_min) {
                codegen_set_mmacosx_version_min(g, buf_create_from_str(mmacosx_version_min));
            }
            if (mios_version_min) {
                codegen_set_mios_version_min(g, buf_create_from_str(mios_version_min));
            }

            if (cmd == CmdBuild) {
                codegen_add_root_code(g, &root_source_dir, &root_source_name, &root_source_code);
                codegen_link(g, out_file);
                return EXIT_SUCCESS;
            } else if (cmd == CmdParseH) {
                codegen_parseh(g, &root_source_dir, &root_source_name, &root_source_code);
                codegen_render_ast(g, stdout, 4);
                return EXIT_SUCCESS;
            } else if (cmd == CmdTest) {
                codegen_add_root_code(g, &root_source_dir, &root_source_name, &root_source_code);
                codegen_link(g, "./test");
                ZigList<const char *> args = {0};
                int return_code;
                os_spawn_process("./test", args, &return_code);
                if (return_code != 0) {
                    fprintf(stderr, "\nTests failed. Use the following command to reproduce the failure:\n");
                    fprintf(stderr, "./test\n");
                }
                return return_code;
            } else {
                zig_unreachable();
            }
        }
    case CmdVersion:
        printf("%s\n", ZIG_VERSION_STRING);
        return EXIT_SUCCESS;
    case CmdTargets:
        return print_target_list(stdout);
    case CmdInvalid:
        return usage(arg0);
    }
}
