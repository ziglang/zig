/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "ast_render.hpp"
#include "buffer.hpp"
#include "codegen.hpp"
#include "config.h"
#include "error.hpp"
#include "link.hpp"
#include "os.hpp"
#include "target.hpp"

#include <stdio.h>

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s [command] [options]\n"
        "Commands:\n"
        "  build                        build project from build.zig\n"
        "  build-exe [source]           create executable from source or object files\n"
        "  build-lib [source]           create library from source or object files\n"
        "  build-obj [source]           create object from source or assembly\n"
        "  builtin                      show the source code of that @import(\"builtin\")\n"
        "  run [source]                 create executable and run immediately\n"
        "  translate-c [source]         convert c code to zig code\n"
        "  targets                      list available compilation targets\n"
        "  test [source]                create and run a test build\n"
        "  version                      print version number and exit\n"
        "  zen                          print zen of zig and exit\n"
        "Compile Options:\n"
        "  --assembly [source]          add assembly file to build\n"
        "  --cache-dir [path]           override the cache directory\n"
        "  --color [auto|off|on]        enable or disable colored error messages\n"
        "  --emit [asm|bin|llvm-ir]     emit a specific file format as compilation output\n"
        "  --enable-timing-info         print timing diagnostics\n"
        "  --libc-include-dir [path]    directory where libc stdlib.h resides\n"
        "  --name [name]                override output name\n"
        "  --output [file]              override destination path\n"
        "  --output-h [file]            override generated header file path\n"
        "  --pkg-begin [name] [path]    make package available to import and push current pkg\n"
        "  --pkg-end                    pop current pkg\n"
        "  --release-fast               build with optimizations on and safety off\n"
        "  --release-safe               build with optimizations on and safety on\n"
        "  --release-small              build with size optimizations on and safety off\n"
        "  --static                     output will be statically linked\n"
        "  --strip                      exclude debug symbols\n"
        "  --target-arch [name]         specify target architecture\n"
        "  --target-environ [name]      specify target environment\n"
        "  --target-os [name]           specify target operating system\n"
        "  --verbose-tokenize           turn on compiler debug output for tokenization\n"
        "  --verbose-ast                turn on compiler debug output for parsing into an AST\n"
        "  --verbose-link               turn on compiler debug output for linking\n"
        "  --verbose-ir                 turn on compiler debug output for Zig IR\n"
        "  --verbose-llvm-ir            turn on compiler debug output for LLVM IR\n"
        "  --verbose-cimport            turn on compiler debug output for C imports\n"
        "  -dirafter [dir]              same as -isystem but do it last\n"
        "  -isystem [dir]               add additional search path for other .h files\n"
        "  -mllvm [arg]                 additional arguments to forward to LLVM's option processing\n"
        "Link Options:\n"
        "  --ar-path [path]             set the path to ar\n"
        "  --dynamic-linker [path]      set the path to ld.so\n"
        "  --each-lib-rpath             add rpath for each used dynamic library\n"
        "  --libc-lib-dir [path]        directory where libc crt1.o resides\n"
        "  --libc-static-lib-dir [path] directory where libc crtbegin.o resides\n"
        "  --msvc-lib-dir [path]        (windows) directory where vcruntime.lib resides\n"
        "  --kernel32-lib-dir [path]    (windows) directory where kernel32.lib resides\n"
        "  --library [lib]              link against lib\n"
        "  --forbid-library [lib]       make it an error to link against lib\n"
        "  --library-path [dir]         add a directory to the library search path\n"
        "  --linker-script [path]       use a custom linker script\n"
        "  --object [obj]               add object file to build\n"
        "  -L[dir]                      alias for --library-path\n"
        "  -rdynamic                    add all symbols to the dynamic symbol table\n"
        "  -rpath [path]                add directory to the runtime library search path\n"
        "  --no-rosegment               compromise security to workaround valgrind bug\n"
        "  -mconsole                    (windows) --subsystem console to the linker\n"
        "  -mwindows                    (windows) --subsystem windows to the linker\n"
        "  -framework [name]            (darwin) link against framework\n"
        "  -mios-version-min [ver]      (darwin) set iOS deployment target\n"
        "  -mmacosx-version-min [ver]   (darwin) set Mac OS X deployment target\n"
        "  --ver-major [ver]            dynamic library semver major version\n"
        "  --ver-minor [ver]            dynamic library semver minor version\n"
        "  --ver-patch [ver]            dynamic library semver patch version\n"
        "Test Options:\n"
        "  --test-filter [text]         skip tests that do not match filter\n"
        "  --test-name-prefix [text]    add prefix to all tests\n"
        "  --test-cmd [arg]             specify test execution command one arg at a time\n"
        "  --test-cmd-bin               appends test binary path to test cmd args\n"
    , arg0);
    return EXIT_FAILURE;
}

static const char *ZIG_ZEN = "\n"
" * Communicate intent precisely.\n"
" * Edge cases matter.\n"
" * Favor reading code over writing code.\n"
" * Only one obvious way to do things.\n"
" * Runtime crashes are better than bugs.\n"
" * Compile errors are better than runtime crashes.\n"
" * Incremental improvements.\n"
" * Avoid local maximums.\n"
" * Reduce the amount one must remember.\n"
" * Minimize energy spent on coding style.\n"
" * Together we serve end users.\n";

static int print_target_list(FILE *f) {
    ZigTarget native;
    get_native_target(&native);

    fprintf(f, "Architectures:\n");
    size_t arch_count = target_arch_count();
    for (size_t arch_i = 0; arch_i < arch_count; arch_i += 1) {
        const ArchType *arch = get_target_arch(arch_i);
        char arch_name[50];
        get_arch_name(arch_name, arch);
        const char *native_str = (native.arch.arch == arch->arch && native.arch.sub_arch == arch->sub_arch) ?
            " (native)" : "";
        fprintf(f, "  %s%s\n", arch_name, native_str);
    }

    fprintf(f, "\nOperating Systems:\n");
    size_t os_count = target_os_count();
    for (size_t i = 0; i < os_count; i += 1) {
        Os os_type = get_target_os(i);
        const char *native_str = (native.os == os_type) ? " (native)" : "";
        fprintf(f, "  %s%s\n", get_target_os_name(os_type), native_str);
    }

    fprintf(f, "\nEnvironments:\n");
    size_t environ_count = target_environ_count();
    for (size_t i = 0; i < environ_count; i += 1) {
        ZigLLVM_EnvironmentType environ_type = get_target_environ(i);
        const char *native_str = (native.env_type == environ_type) ? " (native)" : "";
        fprintf(f, "  %s%s\n", ZigLLVMGetEnvironmentTypeName(environ_type), native_str);
    }

    return EXIT_SUCCESS;
}

static bool test_zig_install_prefix(Buf *test_path, Buf *out_zig_lib_dir) {
    Buf lib_buf = BUF_INIT;
    buf_init_from_str(&lib_buf, "lib");

    Buf zig_buf = BUF_INIT;
    buf_init_from_str(&zig_buf, "zig");

    Buf std_buf = BUF_INIT;
    buf_init_from_str(&std_buf, "std");

    Buf index_zig_buf = BUF_INIT;
    buf_init_from_str(&index_zig_buf, "index.zig");

    Buf test_lib_dir = BUF_INIT;
    Buf test_zig_dir = BUF_INIT;
    Buf test_std_dir = BUF_INIT;
    Buf test_index_file = BUF_INIT;

    os_path_join(test_path, &lib_buf, &test_lib_dir);
    os_path_join(&test_lib_dir, &zig_buf, &test_zig_dir);
    os_path_join(&test_zig_dir, &std_buf, &test_std_dir);
    os_path_join(&test_std_dir, &index_zig_buf, &test_index_file);

    int err;
    bool exists;
    if ((err = os_file_exists(&test_index_file, &exists))) {
        exists = false;
    }
    if (exists) {
        buf_init_from_buf(out_zig_lib_dir, &test_zig_dir);
        return true;
    }
    return false;
}

static int find_zig_lib_dir(Buf *out_path) {
    int err;

    Buf self_exe_path = BUF_INIT;
    buf_resize(&self_exe_path, 0);
    if (!(err = os_self_exe_path(&self_exe_path))) {
        Buf *cur_path = &self_exe_path;

        for (;;) {
            Buf *test_dir = buf_alloc();
            os_path_dirname(cur_path, test_dir);

            if (buf_eql_buf(test_dir, cur_path)) {
                break;
            }

            if (test_zig_install_prefix(test_dir, out_path)) {
                return 0;
            }

            cur_path = test_dir;
        }
    }

    return ErrorFileNotFound;
}

static Buf *resolve_zig_lib_dir(void) {
    int err;
    Buf *result = buf_alloc();
    if ((err = find_zig_lib_dir(result))) {
        fprintf(stderr, "Unable to find zig lib directory\n");
        exit(EXIT_FAILURE);
    }
    return result;
}

enum Cmd {
    CmdInvalid,
    CmdBuild,
    CmdBuiltin,
    CmdRun,
    CmdTest,
    CmdVersion,
    CmdZen,
    CmdTranslateC,
    CmdTargets,
};

static const char *default_zig_cache_name = "zig-cache";

struct CliPkg {
    const char *name;
    const char *path;
    ZigList<CliPkg *> children;
    CliPkg *parent;
};

static void add_package(CodeGen *g, CliPkg *cli_pkg, PackageTableEntry *pkg) {
    for (size_t i = 0; i < cli_pkg->children.length; i += 1) {
        CliPkg *child_cli_pkg = cli_pkg->children.at(i);

        Buf *dirname = buf_alloc();
        Buf *basename = buf_alloc();
        os_path_split(buf_create_from_str(child_cli_pkg->path), dirname, basename);

        PackageTableEntry *child_pkg = codegen_create_package(g, buf_ptr(dirname), buf_ptr(basename));
        auto entry = pkg->package_table.put_unique(buf_create_from_str(child_cli_pkg->name), child_pkg);
        if (entry) {
            PackageTableEntry *existing_pkg = entry->value;
            Buf *full_path = buf_alloc();
            os_path_join(&existing_pkg->root_src_dir, &existing_pkg->root_src_path, full_path);
            fprintf(stderr, "Unable to add package '%s'->'%s': already exists as '%s'\n",
                    child_cli_pkg->name, child_cli_pkg->path, buf_ptr(full_path));
            exit(EXIT_FAILURE);
        }

        add_package(g, child_cli_pkg, child_pkg);
    }
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "BUILD_INFO") == 0) {
        printf("%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n",
                ZIG_CMAKE_BINARY_DIR,
                ZIG_CXX_COMPILER,
                ZIG_LLVM_CONFIG_EXE,
                ZIG_LLD_INCLUDE_PATH,
                ZIG_LLD_LIBRARIES,
                ZIG_STD_FILES,
                ZIG_C_HEADER_FILES,
                ZIG_DIA_GUIDS_LIB);
        return 0;
    }

    os_init();

    char *arg0 = argv[0];
    Cmd cmd = CmdInvalid;
    EmitFileType emit_file_type = EmitFileTypeBinary;
    const char *in_file = nullptr;
    const char *out_file = nullptr;
    const char *out_file_h = nullptr;
    bool strip = false;
    bool is_static = false;
    OutType out_type = OutTypeUnknown;
    const char *out_name = nullptr;
    bool verbose_tokenize = false;
    bool verbose_ast = false;
    bool verbose_link = false;
    bool verbose_ir = false;
    bool verbose_llvm_ir = false;
    bool verbose_cimport = false;
    ErrColor color = ErrColorAuto;
    const char *libc_lib_dir = nullptr;
    const char *libc_static_lib_dir = nullptr;
    const char *libc_include_dir = nullptr;
    const char *msvc_lib_dir = nullptr;
    const char *kernel32_lib_dir = nullptr;
    const char *dynamic_linker = nullptr;
    ZigList<const char *> clang_argv = {0};
    ZigList<const char *> llvm_argv = {0};
    ZigList<const char *> lib_dirs = {0};
    ZigList<const char *> link_libs = {0};
    ZigList<const char *> forbidden_link_libs = {0};
    ZigList<const char *> frameworks = {0};
    int err;
    const char *target_arch = nullptr;
    const char *target_os = nullptr;
    const char *target_environ = nullptr;
    bool mwindows = false;
    bool mconsole = false;
    bool rdynamic = false;
    const char *mmacosx_version_min = nullptr;
    const char *mios_version_min = nullptr;
    const char *linker_script = nullptr;
    ZigList<const char *> rpath_list = {0};
    bool each_lib_rpath = false;
    ZigList<const char *> objects = {0};
    ZigList<const char *> asm_files = {0};
    const char *test_filter = nullptr;
    const char *test_name_prefix = nullptr;
    size_t ver_major = 0;
    size_t ver_minor = 0;
    size_t ver_patch = 0;
    bool timing_info = false;
    const char *cache_dir = nullptr;
    CliPkg *cur_pkg = allocate<CliPkg>(1);
    BuildMode build_mode = BuildModeDebug;
    ZigList<const char *> test_exec_args = {0};
    int comptime_args_end = 0;
    int runtime_args_start = argc;
    bool no_rosegment_workaround = false;

    if (argc >= 2 && strcmp(argv[1], "build") == 0) {
        const char *zig_exe_path = arg0;
        const char *build_file = "build.zig";
        bool asked_for_help = false;
        bool asked_to_init = false;

        init_all_targets();

        ZigList<const char *> args = {0};
        args.append(zig_exe_path);
        args.append(NULL); // placeholder
        args.append(NULL); // placeholder
        for (int i = 2; i < argc; i += 1) {
            if (strcmp(argv[i], "--help") == 0) {
                asked_for_help = true;
                args.append(argv[i]);
            } else if (strcmp(argv[i], "--init") == 0) {
                asked_to_init = true;
                args.append(argv[i]);
            } else if (i + 1 < argc && strcmp(argv[i], "--build-file") == 0) {
                build_file = argv[i + 1];
                i += 1;
            } else if (i + 1 < argc && strcmp(argv[i], "--cache-dir") == 0) {
                cache_dir = argv[i + 1];
                i += 1;
            } else {
                args.append(argv[i]);
            }
        }

        Buf *zig_lib_dir_buf = resolve_zig_lib_dir();

        Buf *zig_std_dir = buf_alloc();
        os_path_join(zig_lib_dir_buf, buf_create_from_str("std"), zig_std_dir);

        Buf *special_dir = buf_alloc();
        os_path_join(zig_std_dir, buf_sprintf("special"), special_dir);

        Buf *build_runner_path = buf_alloc();
        os_path_join(special_dir, buf_create_from_str("build_runner.zig"), build_runner_path);


        CodeGen *g = codegen_create(build_runner_path, nullptr, OutTypeExe, BuildModeDebug, zig_lib_dir_buf);
        codegen_set_out_name(g, buf_create_from_str("build"));

        Buf build_file_abs = BUF_INIT;
        os_path_resolve(buf_create_from_str("."), buf_create_from_str(build_file), &build_file_abs);
        Buf build_file_basename = BUF_INIT;
        Buf build_file_dirname = BUF_INIT;
        os_path_split(&build_file_abs, &build_file_dirname, &build_file_basename);

        Buf *full_cache_dir = buf_alloc();
        if (cache_dir == nullptr) {
            os_path_join(&build_file_dirname, buf_create_from_str(default_zig_cache_name), full_cache_dir);
        } else {
            os_path_resolve(buf_create_from_str("."), buf_create_from_str(cache_dir), full_cache_dir);
        }

        Buf *path_to_build_exe = buf_alloc();
        os_path_join(full_cache_dir, buf_create_from_str("build"), path_to_build_exe);
        codegen_set_cache_dir(g, full_cache_dir);

        args.items[1] = buf_ptr(&build_file_dirname);
        args.items[2] = buf_ptr(full_cache_dir);

        bool build_file_exists;
        if ((err = os_file_exists(&build_file_abs, &build_file_exists))) {
            fprintf(stderr, "unable to open '%s': %s\n", buf_ptr(&build_file_abs), err_str(err));
            return 1;
        }
        if (!build_file_exists) {
            if (asked_for_help) {
                // This usage text has to be synchronized with std/special/build_runner.zig
                fprintf(stdout,
                        "Usage: %s build [options]\n"
                        "\n"
                        "General Options:\n"
                        "  --help                 Print this help and exit\n"
                        "  --init                 Generate a build.zig template\n"
                        "  --build-file [file]    Override path to build.zig\n"
                        "  --cache-dir [path]     Override path to cache directory\n"
                        "  --verbose              Print commands before executing them\n"
                        "  --verbose-tokenize     Enable compiler debug output for tokenization\n"
                        "  --verbose-ast          Enable compiler debug output for parsing into an AST\n"
                        "  --verbose-link         Enable compiler debug output for linking\n"
                        "  --verbose-ir           Enable compiler debug output for Zig IR\n"
                        "  --verbose-llvm-ir      Enable compiler debug output for LLVM IR\n"
                        "  --verbose-cimport      Enable compiler debug output for C imports\n"
                        "  --prefix [path]        Override default install prefix\n"
                        "\n"
                        "Project-specific options become available when the build file is found.\n"
                        "\n"
                        "Advanced Options:\n"
                        "  --build-file [file]    Override path to build.zig\n"
                        "  --cache-dir [path]     Override path to cache directory\n"
                        "  --verbose-tokenize     Enable compiler debug output for tokenization\n"
                        "  --verbose-ast          Enable compiler debug output for parsing into an AST\n"
                        "  --verbose-link         Enable compiler debug output for linking\n"
                        "  --verbose-ir           Enable compiler debug output for Zig IR\n"
                        "  --verbose-llvm-ir      Enable compiler debug output for LLVM IR\n"
                        "  --verbose-cimport      Enable compiler debug output for C imports\n"
                        "\n"
                , zig_exe_path);
                return EXIT_SUCCESS;
            } else if (asked_to_init) {
                Buf *build_template_path = buf_alloc();
                os_path_join(special_dir, buf_create_from_str("build_file_template.zig"), build_template_path);

                if ((err = os_copy_file(build_template_path, &build_file_abs))) {
                    fprintf(stderr, "Unable to write build.zig template: %s\n", err_str(err));
                    return EXIT_FAILURE;
                } else {
                    fprintf(stderr, "Wrote build.zig template\n");
                    return EXIT_SUCCESS;
                }
            }

            fprintf(stderr,
                    "No 'build.zig' file found.\n"
                    "Initialize a 'build.zig' template file with `zig build --init`,\n"
                    "or build an executable directly with `zig build-exe $FILENAME.zig`.\n"
                    "See: `zig build --help` or `zig help` for more options.\n"
                   );
            return EXIT_FAILURE;
        }

        PackageTableEntry *build_pkg = codegen_create_package(g, buf_ptr(&build_file_dirname),
                buf_ptr(&build_file_basename));
        g->root_package->package_table.put(buf_create_from_str("@build"), build_pkg);
        codegen_build(g);
        codegen_link(g, buf_ptr(path_to_build_exe));
        codegen_destroy(g);

        Termination term;
        os_spawn_process(buf_ptr(path_to_build_exe), args, &term);
        if (term.how != TerminationIdClean || term.code != 0) {
            fprintf(stderr, "\nBuild failed. The following command failed:\n");
            fprintf(stderr, "%s", buf_ptr(path_to_build_exe));
            for (size_t i = 0; i < args.length; i += 1) {
                fprintf(stderr, " %s", args.at(i));
            }
            fprintf(stderr, "\n");
        }
        return (term.how == TerminationIdClean) ? term.code : -1;
    }

    for (int i = 1; i < argc; i += 1, comptime_args_end += 1) {
        char *arg = argv[i];

        if (arg[0] == '-') {
            if (strcmp(arg, "--") == 0) {
                // ignore -- from both compile and runtime arg sets
                runtime_args_start = i + 1;
                break;
            } else if (strcmp(arg, "--release-fast") == 0) {
                build_mode = BuildModeFastRelease;
            } else if (strcmp(arg, "--release-safe") == 0) {
                build_mode = BuildModeSafeRelease;
            } else if (strcmp(arg, "--release-small") == 0) {
                build_mode = BuildModeSmallRelease;
            } else if (strcmp(arg, "--strip") == 0) {
                strip = true;
            } else if (strcmp(arg, "--static") == 0) {
                is_static = true;
            } else if (strcmp(arg, "--verbose-tokenize") == 0) {
                verbose_tokenize = true;
            } else if (strcmp(arg, "--verbose-ast") == 0) {
                verbose_ast = true;
            } else if (strcmp(arg, "--verbose-link") == 0) {
                verbose_link = true;
            } else if (strcmp(arg, "--verbose-ir") == 0) {
                verbose_ir = true;
            } else if (strcmp(arg, "--verbose-llvm-ir") == 0) {
                verbose_llvm_ir = true;
            } else if (strcmp(arg, "--verbose-cimport") == 0) {
                verbose_cimport = true;
            } else if (strcmp(arg, "-mwindows") == 0) {
                mwindows = true;
            } else if (strcmp(arg, "-mconsole") == 0) {
                mconsole = true;
            } else if (strcmp(arg, "-rdynamic") == 0) {
                rdynamic = true;
            } else if (strcmp(arg, "--no-rosegment") == 0) {
                no_rosegment_workaround = true;
            } else if (strcmp(arg, "--each-lib-rpath") == 0) {
                each_lib_rpath = true;
            } else if (strcmp(arg, "--enable-timing-info") == 0) {
                timing_info = true;
            } else if (strcmp(arg, "--test-cmd-bin") == 0) {
                test_exec_args.append(nullptr);
            } else if (arg[1] == 'L' && arg[2] != 0) {
                // alias for --library-path
                lib_dirs.append(&arg[2]);
            } else if (strcmp(arg, "--pkg-begin") == 0) {
                if (i + 2 >= argc) {
                    fprintf(stderr, "Expected 2 arguments after --pkg-begin\n");
                    return usage(arg0);
                }
                CliPkg *new_cur_pkg = allocate<CliPkg>(1);
                i += 1;
                new_cur_pkg->name = argv[i];
                i += 1;
                new_cur_pkg->path = argv[i];
                new_cur_pkg->parent = cur_pkg;
                cur_pkg->children.append(new_cur_pkg);
                cur_pkg = new_cur_pkg;
            } else if (strcmp(arg, "--pkg-end") == 0) {
                if (cur_pkg->parent == nullptr) {
                    fprintf(stderr, "Encountered --pkg-end with no matching --pkg-begin\n");
                    return EXIT_FAILURE;
                }
                cur_pkg = cur_pkg->parent;
            } else if (i + 1 >= argc) {
                fprintf(stderr, "Expected another argument after %s\n", arg);
                return usage(arg0);
            } else {
                i += 1;
                if (strcmp(arg, "--output") == 0) {
                    out_file = argv[i];
                } else if (strcmp(arg, "--output-h") == 0) {
                    out_file_h = argv[i];
                } else if (strcmp(arg, "--color") == 0) {
                    if (strcmp(argv[i], "auto") == 0) {
                        color = ErrColorAuto;
                    } else if (strcmp(argv[i], "on") == 0) {
                        color = ErrColorOn;
                    } else if (strcmp(argv[i], "off") == 0) {
                        color = ErrColorOff;
                    } else {
                        fprintf(stderr, "--color options are 'auto', 'on', or 'off'\n");
                        return usage(arg0);
                    }
                } else if (strcmp(arg, "--emit") == 0) {
                    if (strcmp(argv[i], "asm") == 0) {
                        emit_file_type = EmitFileTypeAssembly;
                    } else if (strcmp(argv[i], "bin") == 0) {
                        emit_file_type = EmitFileTypeBinary;
                    } else if (strcmp(argv[i], "llvm-ir") == 0) {
                        emit_file_type = EmitFileTypeLLVMIr;
                    } else {
                        fprintf(stderr, "--emit options are 'asm', 'bin', or 'llvm-ir'\n");
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
                } else if (strcmp(arg, "--msvc-lib-dir") == 0) {
                    msvc_lib_dir = argv[i];
                } else if (strcmp(arg, "--kernel32-lib-dir") == 0) {
                    kernel32_lib_dir = argv[i];
                } else if (strcmp(arg, "--dynamic-linker") == 0) {
                    dynamic_linker = argv[i];
                } else if (strcmp(arg, "-isystem") == 0) {
                    clang_argv.append("-isystem");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-dirafter") == 0) {
                    clang_argv.append("-dirafter");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-mllvm") == 0) {
                    clang_argv.append("-mllvm");
                    clang_argv.append(argv[i]);

                    llvm_argv.append(argv[i]);
                } else if (strcmp(arg, "--library-path") == 0 || strcmp(arg, "-L") == 0) {
                    lib_dirs.append(argv[i]);
                } else if (strcmp(arg, "--library") == 0) {
                    link_libs.append(argv[i]);
                } else if (strcmp(arg, "--forbid-library") == 0) {
                    forbidden_link_libs.append(argv[i]);
                } else if (strcmp(arg, "--object") == 0) {
                    objects.append(argv[i]);
                } else if (strcmp(arg, "--assembly") == 0) {
                    asm_files.append(argv[i]);
                } else if (strcmp(arg, "--cache-dir") == 0) {
                    cache_dir = argv[i];
                } else if (strcmp(arg, "--target-arch") == 0) {
                    target_arch = argv[i];
                } else if (strcmp(arg, "--target-os") == 0) {
                    target_os = argv[i];
                } else if (strcmp(arg, "--target-environ") == 0) {
                    target_environ = argv[i];
                } else if (strcmp(arg, "-mmacosx-version-min") == 0) {
                    mmacosx_version_min = argv[i];
                } else if (strcmp(arg, "-mios-version-min") == 0) {
                    mios_version_min = argv[i];
                } else if (strcmp(arg, "-framework") == 0) {
                    frameworks.append(argv[i]);
                } else if (strcmp(arg, "--linker-script") == 0) {
                    linker_script = argv[i];
                } else if (strcmp(arg, "-rpath") == 0) {
                    rpath_list.append(argv[i]);
                } else if (strcmp(arg, "--test-filter") == 0) {
                    test_filter = argv[i];
                } else if (strcmp(arg, "--test-name-prefix") == 0) {
                    test_name_prefix = argv[i];
                } else if (strcmp(arg, "--ver-major") == 0) {
                    ver_major = atoi(argv[i]);
                } else if (strcmp(arg, "--ver-minor") == 0) {
                    ver_minor = atoi(argv[i]);
                } else if (strcmp(arg, "--ver-patch") == 0) {
                    ver_patch = atoi(argv[i]);
                } else if (strcmp(arg, "--test-cmd") == 0) {
                    test_exec_args.append(argv[i]);
                } else {
                    fprintf(stderr, "Invalid argument: %s\n", arg);
                    return usage(arg0);
                }
            }
        } else if (cmd == CmdInvalid) {
            if (strcmp(arg, "build-exe") == 0) {
                cmd = CmdBuild;
                out_type = OutTypeExe;
            } else if (strcmp(arg, "build-obj") == 0) {
                cmd = CmdBuild;
                out_type = OutTypeObj;
            } else if (strcmp(arg, "build-lib") == 0) {
                cmd = CmdBuild;
                out_type = OutTypeLib;
            } else if (strcmp(arg, "run") == 0) {
                cmd = CmdRun;
                out_type = OutTypeExe;
            } else if (strcmp(arg, "version") == 0) {
                cmd = CmdVersion;
            } else if (strcmp(arg, "zen") == 0) {
                cmd = CmdZen;
            } else if (strcmp(arg, "translate-c") == 0) {
                cmd = CmdTranslateC;
            } else if (strcmp(arg, "test") == 0) {
                cmd = CmdTest;
                out_type = OutTypeExe;
            } else if (strcmp(arg, "targets") == 0) {
                cmd = CmdTargets;
            } else if (strcmp(arg, "builtin") == 0) {
                cmd = CmdBuiltin;
            } else {
                fprintf(stderr, "Unrecognized command: %s\n", arg);
                return usage(arg0);
            }
        } else {
            switch (cmd) {
                case CmdBuild:
                case CmdRun:
                case CmdTranslateC:
                case CmdTest:
                    if (!in_file) {
                        in_file = arg;
                    } else {
                        fprintf(stderr, "Unexpected extra parameter: %s\n", arg);
                        return usage(arg0);
                    }
                    break;
                case CmdBuiltin:
                case CmdVersion:
                case CmdZen:
                case CmdTargets:
                    fprintf(stderr, "Unexpected extra parameter: %s\n", arg);
                    return usage(arg0);
                case CmdInvalid:
                    zig_unreachable();
            }
        }
    }

    if (cur_pkg->parent != nullptr) {
        fprintf(stderr, "Unmatched --pkg-begin\n");
        return EXIT_FAILURE;
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

    switch (cmd) {
    case CmdBuiltin: {
        Buf *zig_lib_dir_buf = resolve_zig_lib_dir();
        CodeGen *g = codegen_create(nullptr, target, out_type, build_mode, zig_lib_dir_buf);
        Buf *builtin_source = codegen_generate_builtin_source(g);
        if (fwrite(buf_ptr(builtin_source), 1, buf_len(builtin_source), stdout) != buf_len(builtin_source)) {
            fprintf(stderr, "unable to write to stdout: %s\n", strerror(ferror(stdout)));
            return EXIT_FAILURE;
        }
        return EXIT_SUCCESS;
    }
    case CmdRun:
    case CmdBuild:
    case CmdTranslateC:
    case CmdTest:
        {
            if (cmd == CmdBuild && !in_file && objects.length == 0 && asm_files.length == 0) {
                fprintf(stderr, "Expected source file argument or at least one --object or --assembly argument.\n");
                return usage(arg0);
            } else if ((cmd == CmdTranslateC || cmd == CmdTest || cmd == CmdRun) && !in_file) {
                fprintf(stderr, "Expected source file argument.\n");
                return usage(arg0);
            } else if (cmd == CmdBuild && out_type == OutTypeObj && objects.length != 0) {
                fprintf(stderr, "When building an object file, --object arguments are invalid.\n");
                return usage(arg0);
            }

            assert(cmd != CmdBuild || out_type != OutTypeUnknown);

            bool need_name = (cmd == CmdBuild || cmd == CmdTranslateC);

            if (cmd == CmdRun) {
                out_name = "run";
            }

            Buf *in_file_buf = nullptr;

            Buf *buf_out_name = (cmd == CmdTest) ? buf_create_from_str("test") :
                (out_name == nullptr) ? nullptr : buf_create_from_str(out_name);

            if (in_file) {
                in_file_buf = buf_create_from_str(in_file);

                if (need_name && buf_out_name == nullptr) {
                    Buf basename = BUF_INIT;
                    os_path_split(in_file_buf, nullptr, &basename);
                    buf_out_name = buf_alloc();
                    os_path_extname(&basename, buf_out_name, nullptr);
                }
            }

            if (need_name && buf_out_name == nullptr) {
                fprintf(stderr, "--name [name] not provided and unable to infer\n\n");
                return usage(arg0);
            }

            Buf *zig_root_source_file = (cmd == CmdTranslateC) ? nullptr : in_file_buf;

            Buf *full_cache_dir = buf_alloc();
            Buf *run_exec_path = buf_alloc();
            if (cmd == CmdRun) {
                if (buf_out_name == nullptr) {
                    buf_out_name = buf_create_from_str("run");
                }

                Buf *global_cache_dir = buf_alloc();
                os_get_global_cache_directory(global_cache_dir);
                os_path_join(global_cache_dir, buf_out_name, run_exec_path);
                os_path_resolve(buf_create_from_str("."), global_cache_dir, full_cache_dir);

                out_file = buf_ptr(run_exec_path);
            } else {
                os_path_resolve(buf_create_from_str("."),
                        buf_create_from_str((cache_dir == nullptr) ? default_zig_cache_name : cache_dir),
                        full_cache_dir);
            }

            Buf *zig_lib_dir_buf = resolve_zig_lib_dir();

            CodeGen *g = codegen_create(zig_root_source_file, target, out_type, build_mode, zig_lib_dir_buf);
            codegen_set_out_name(g, buf_out_name);
            codegen_set_lib_version(g, ver_major, ver_minor, ver_patch);
            codegen_set_is_test(g, cmd == CmdTest);
            codegen_set_linker_script(g, linker_script);
            codegen_set_cache_dir(g, full_cache_dir);
            if (each_lib_rpath)
                codegen_set_each_lib_rpath(g, each_lib_rpath);

            codegen_set_clang_argv(g, clang_argv.items, clang_argv.length);
            codegen_set_llvm_argv(g, llvm_argv.items, llvm_argv.length);
            codegen_set_strip(g, strip);
            codegen_set_is_static(g, is_static);
            if (libc_lib_dir)
                codegen_set_libc_lib_dir(g, buf_create_from_str(libc_lib_dir));
            if (libc_static_lib_dir)
                codegen_set_libc_static_lib_dir(g, buf_create_from_str(libc_static_lib_dir));
            if (libc_include_dir)
                codegen_set_libc_include_dir(g, buf_create_from_str(libc_include_dir));
            if (msvc_lib_dir)
                codegen_set_msvc_lib_dir(g, buf_create_from_str(msvc_lib_dir));
            if (kernel32_lib_dir)
                codegen_set_kernel32_lib_dir(g, buf_create_from_str(kernel32_lib_dir));
            if (dynamic_linker)
                codegen_set_dynamic_linker(g, buf_create_from_str(dynamic_linker));
            g->verbose_tokenize = verbose_tokenize;
            g->verbose_ast = verbose_ast;
            g->verbose_link = verbose_link;
            g->verbose_ir = verbose_ir;
            g->verbose_llvm_ir = verbose_llvm_ir;
            g->verbose_cimport = verbose_cimport;
            codegen_set_errmsg_color(g, color);

            for (size_t i = 0; i < lib_dirs.length; i += 1) {
                codegen_add_lib_dir(g, lib_dirs.at(i));
            }
            for (size_t i = 0; i < link_libs.length; i += 1) {
                LinkLib *link_lib = codegen_add_link_lib(g, buf_create_from_str(link_libs.at(i)));
                link_lib->provided_explicitly = true;
            }
            for (size_t i = 0; i < forbidden_link_libs.length; i += 1) {
                Buf *forbidden_link_lib = buf_create_from_str(forbidden_link_libs.at(i));
                codegen_add_forbidden_lib(g, forbidden_link_lib);
            }
            for (size_t i = 0; i < frameworks.length; i += 1) {
                codegen_add_framework(g, frameworks.at(i));
            }
            for (size_t i = 0; i < rpath_list.length; i += 1) {
                codegen_add_rpath(g, rpath_list.at(i));
            }

            codegen_set_windows_subsystem(g, mwindows, mconsole);
            codegen_set_rdynamic(g, rdynamic);
            g->no_rosegment_workaround = no_rosegment_workaround;
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

            if (test_filter) {
                codegen_set_test_filter(g, buf_create_from_str(test_filter));
            }

            if (test_name_prefix) {
                codegen_set_test_name_prefix(g, buf_create_from_str(test_name_prefix));
            }

            if (out_file_h)
                codegen_set_output_h_path(g, buf_create_from_str(out_file_h));


            add_package(g, cur_pkg, g->root_package);

            if (cmd == CmdBuild || cmd == CmdRun) {
                codegen_set_emit_file_type(g, emit_file_type);

                for (size_t i = 0; i < objects.length; i += 1) {
                    codegen_add_object(g, buf_create_from_str(objects.at(i)));
                }
                for (size_t i = 0; i < asm_files.length; i += 1) {
                    codegen_add_assembly(g, buf_create_from_str(asm_files.at(i)));
                }
                codegen_build(g);
                codegen_link(g, out_file);
                if (timing_info)
                    codegen_print_timing_report(g, stdout);

                if (cmd == CmdRun) {
                    ZigList<const char*> args = {0};
                    for (int i = runtime_args_start; i < argc; ++i) {
                        args.append(argv[i]);
                    }

                    Termination term;
                    os_spawn_process(buf_ptr(run_exec_path), args, &term);
                    return term.code;
                }

                return EXIT_SUCCESS;
            } else if (cmd == CmdTranslateC) {
                codegen_translate_c(g, in_file_buf);
                ast_render(g, stdout, g->root_import->root, 4);
                if (timing_info)
                    codegen_print_timing_report(g, stdout);
                return EXIT_SUCCESS;
            } else if (cmd == CmdTest) {
                codegen_set_emit_file_type(g, emit_file_type);

                ZigTarget native;
                get_native_target(&native);

                ZigTarget *non_null_target = target ? target : &native;

                Buf *test_exe_name = buf_sprintf("test%s", target_exe_file_ext(non_null_target));
                Buf *test_exe_path = buf_alloc();
                os_path_join(full_cache_dir, test_exe_name, test_exe_path);

                for (size_t i = 0; i < test_exec_args.length; i += 1) {
                    if (test_exec_args.items[i] == nullptr) {
                        test_exec_args.items[i] = buf_ptr(test_exe_path);
                    }
                }

                codegen_build(g);
                codegen_link(g, buf_ptr(test_exe_path));

                if (!target_can_exec(&native, target)) {
                    fprintf(stderr, "Created %s but skipping execution because it is non-native.\n",
                            buf_ptr(test_exe_path));
                    return 0;
                }

                Termination term;
                if (test_exec_args.length > 0) {
                    ZigList<const char *> rest_args = {0};
                    for (size_t i = 1; i < test_exec_args.length; i += 1) {
                        rest_args.append(test_exec_args.at(i));
                    }
                    os_spawn_process(test_exec_args.items[0], rest_args, &term);
                } else {
                    ZigList<const char *> no_args = {0};
                    os_spawn_process(buf_ptr(test_exe_path), no_args, &term);
                }

                if (term.how != TerminationIdClean || term.code != 0) {
                    fprintf(stderr, "\nTests failed. Use the following command to reproduce the failure:\n");
                    fprintf(stderr, "%s\n", buf_ptr(test_exe_path));
                } else if (timing_info) {
                    codegen_print_timing_report(g, stdout);
                }
                return (term.how == TerminationIdClean) ? term.code : -1;
            } else {
                zig_unreachable();
            }
        }
    case CmdVersion:
        printf("%s\n", ZIG_VERSION_STRING);
        return EXIT_SUCCESS;
    case CmdZen:
        printf("%s\n", ZIG_ZEN);
        return EXIT_SUCCESS;
    case CmdTargets:
        return print_target_list(stdout);
    case CmdInvalid:
        return usage(arg0);
    }
}
