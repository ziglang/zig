/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "ast_render.hpp"
#include "buffer.hpp"
#include "codegen.hpp"
#include "compiler.hpp"
#include "config.h"
#include "error.hpp"
#include "heap.hpp"
#include "os.hpp"
#include "target.hpp"
#include "stage2.h"
#include "glibc.hpp"
#include "dump_analysis.hpp"
#include "mem_profile.hpp"

#include <stdio.h>

static int print_error_usage(const char *arg0) {
    fprintf(stderr, "See `%s --help` for detailed usage information\n", arg0);
    return EXIT_FAILURE;
}

static int print_full_usage(const char *arg0, FILE *file, int return_code) {
    fprintf(file,
        "Usage: %s [command] [options]\n"
        "\n"
        "Commands:\n"
        "  build                        build project from build.zig\n"
        "  build-exe [source]           create executable from source or object files\n"
        "  build-lib [source]           create library from source or object files\n"
        "  build-obj [source]           create object from source or assembly\n"
        "  builtin                      show the source code of @import(\"builtin\")\n"
        "  cc                           use Zig as a drop-in C compiler\n"
        "  c++                          use Zig as a drop-in C++ compiler\n"
        "  env                          print lib path, std path, compiler id and version\n"
        "  fmt                          parse files and render in canonical zig format\n"
        "  id                           print the base64-encoded compiler id\n"
        "  init-exe                     initialize a `zig build` application in the cwd\n"
        "  init-lib                     initialize a `zig build` library in the cwd\n"
        "  libc [paths_file]            Display native libc paths file or validate one\n"
        "  run [source] [-- [args]]     create executable and run immediately\n"
        "  translate-c [source]         convert c code to zig code\n"
        "  targets                      list available compilation targets\n"
        "  test [source]                create and run a test build\n"
        "  version                      print version number and exit\n"
        "  zen                          print zen of zig and exit\n"
        "\n"
        "Compile Options:\n"
        "  --c-source [options] [file]  compile C source code\n"
        "  --cache-dir [path]           override the local cache directory\n"
        "  --cache [auto|off|on]        build in cache, print output path to stdout\n"
        "  --color [auto|off|on]        enable or disable colored error messages\n"
        "  --disable-valgrind           omit valgrind client requests in debug builds\n"
        "  --eh-frame-hdr               enable C++ exception handling by passing --eh-frame-hdr to linker\n"
        "  --enable-valgrind            include valgrind client requests release builds\n"
        "  -fstack-check                enable stack probing in unsafe builds\n"
        "  -fno-stack-check             disable stack probing in safe builds\n"
        "  -fsanitize-c                 enable C undefined behavior detection in unsafe builds\n"
        "  -fno-sanitize-c              disable C undefined behavior detection in safe builds\n"
        "  --emit [asm|bin|llvm-ir]     (deprecated) emit a specific file format as compilation output\n"
        "  -fPIC                        enable Position Independent Code\n"
        "  -fno-PIC                     disable Position Independent Code\n"
        "  -ftime-report                print timing diagnostics\n"
        "  -fstack-report               print stack size diagnostics\n"
        "  -fmem-report                 print memory usage diagnostics\n"
        "  -fdump-analysis              write analysis.json file with type information\n"
        "  -femit-docs                  create a docs/ dir with html documentation\n"
        "  -fno-emit-docs               do not produce docs/ dir with html documentation\n"
        "  -femit-bin                   (default) output machine code\n"
        "  -fno-emit-bin                do not output machine code\n"
        "  -femit-asm                   output .s (assembly code)\n"
        "  -fno-emit-asm                (default) do not output .s (assembly code)\n"
        "  -femit-llvm-ir               produce a .ll file with LLVM IR\n"
        "  -fno-emit-llvm-ir            (default) do not produce a .ll file with LLVM IR\n"
        "  -femit-h                      generate a C header file (.h)\n"
        "  -fno-emit-h                  (default) do not generate a C header file (.h)\n"
        "  --libc [file]                Provide a file which specifies libc paths\n"
        "  --name [name]                override output name\n"
        "  --output-dir [dir]           override output directory (defaults to cwd)\n"
        "  --pkg-begin [name] [path]    make pkg available to import and push current pkg\n"
        "  --pkg-end                    pop current pkg\n"
        "  --main-pkg-path              set the directory of the root package\n"
        "  --release-fast               build with optimizations on and safety off\n"
        "  --release-safe               build with optimizations on and safety on\n"
        "  --release-small              build with size optimizations on and safety off\n"
        "  --single-threaded            source may assume it is only used single-threaded\n"
        "  -dynamic                     create a shared library (.so; .dll; .dylib)\n"
        "  --strip                      exclude debug symbols\n"
        "  -target [name]               <arch>-<os>-<abi> see the targets command\n"
        "  --verbose-tokenize           enable compiler debug output for tokenization\n"
        "  --verbose-ast                enable compiler debug output for AST parsing\n"
        "  --verbose-link               enable compiler debug output for linking\n"
        "  --verbose-ir                 enable compiler debug output for Zig IR\n"
        "  --verbose-llvm-ir            enable compiler debug output for LLVM IR\n"
        "  --verbose-cimport            enable compiler debug output for C imports\n"
        "  --verbose-cc                 enable compiler debug output for C compilation\n"
        "  --verbose-llvm-cpu-features  enable compiler debug output for LLVM CPU features\n"
        "  -dirafter [dir]              add directory to AFTER include search path\n"
        "  -isystem [dir]               add directory to SYSTEM include search path\n"
        "  -I[dir]                      add directory to include search path\n"
        "  -mllvm [arg]                 (unsupported) forward an arg to LLVM's option processing\n"
        "  --override-lib-dir [arg]     override path to Zig lib directory\n"
        "  -ffunction-sections          places each function in a separate section\n"
        "  -D[macro]=[value]            define C [macro] to [value] (1 if [value] omitted)\n"
        "  -mcpu [cpu]                  specify target CPU and feature set\n"
        "  -code-model [default|tiny|   set target code model\n"
        "               small|kernel|\n"
        "               medium|large]\n"
        "\n"
        "Link Options:\n"
        "  --bundle-compiler-rt         for static libraries, include compiler-rt symbols\n"
        "  --dynamic-linker [path]      set the path to ld.so\n"
        "  --each-lib-rpath             add rpath for each used dynamic library\n"
        "  --library [lib]              link against lib\n"
        "  --forbid-library [lib]       make it an error to link against lib\n"
        "  --library-path [dir]         add a directory to the library search path\n"
        "  --linker-script [path]       use a custom linker script\n"
        "  --version-script [path]      provide a version .map file\n"
        "  --object [obj]               add object file to build\n"
        "  -L[dir]                      alias for --library-path\n"
        "  -l[lib]                      alias for --library\n"
        "  -rdynamic                    add all symbols to the dynamic symbol table\n"
        "  -rpath [path]                add directory to the runtime library search path\n"
        "  --stack [size]               (linux, windows, Wasm) override default stack size\n"
        "  --subsystem [subsystem]      (windows) /SUBSYSTEM:<subsystem> to the linker\n"
        "  -F[dir]                      (darwin) add search path for frameworks\n"
        "  -framework [name]            (darwin) link against framework\n"
        "  --ver-major [ver]            dynamic library semver major version\n"
        "  --ver-minor [ver]            dynamic library semver minor version\n"
        "  --ver-patch [ver]            dynamic library semver patch version\n"
        "  -Bsymbolic                   bind global references locally\n"
        "\n"
        "Test Options:\n"
        "  --test-filter [text]         skip tests that do not match filter\n"
        "  --test-name-prefix [text]    add prefix to all tests\n"
        "  --test-cmd [arg]             specify test execution command one arg at a time\n"
        "  --test-cmd-bin               appends test binary path to test cmd args\n"
        "  --test-evented-io            runs the test in evented I/O mode\n"
    , arg0);
    return return_code;
}

static int print_libc_usage(const char *arg0, FILE *file, int return_code) {
    fprintf(file,
        "Usage: %s libc\n"
        "\n"
        "Detect the native libc installation and print the resulting paths to stdout.\n"
        "You can save this into a file and then edit the paths to create a cross\n"
        "compilation libc kit. Then you can pass `--libc [file]` for Zig to use it.\n"
        "\n"
        "When compiling natively and no `--libc` argument provided, Zig will create\n"
        "`%s/native_libc.txt`\n"
        "so that it does not have to detect libc on every invocation. You can remove\n"
        "this file to have Zig re-detect the native libc.\n"
        "\n\n"
        "Usage: %s libc [file]\n"
        "\n"
        "Parse a libc installation text file and validate it.\n"
    , arg0, buf_ptr(get_global_cache_dir()), arg0);
    return return_code;
}

enum Cmd {
    CmdNone,
    CmdBuild,
    CmdBuiltin,
    CmdRun,
    CmdTargets,
    CmdTest,
    CmdTranslateC,
    CmdVersion,
    CmdZen,
    CmdLibC,
};

static const char *default_zig_cache_name = "zig-cache";

struct CliPkg {
    const char *name;
    const char *path;
    ZigList<CliPkg *> children;
    CliPkg *parent;
};

static void add_package(CodeGen *g, CliPkg *cli_pkg, ZigPackage *pkg) {
    for (size_t i = 0; i < cli_pkg->children.length; i += 1) {
        CliPkg *child_cli_pkg = cli_pkg->children.at(i);

        Buf *dirname = buf_alloc();
        Buf *basename = buf_alloc();
        os_path_split(buf_create_from_str(child_cli_pkg->path), dirname, basename);

        ZigPackage *child_pkg = codegen_create_package(g, buf_ptr(dirname), buf_ptr(basename),
                buf_ptr(buf_sprintf("%s.%s", buf_ptr(&pkg->pkg_path), child_cli_pkg->name)));
        auto entry = pkg->package_table.put_unique(buf_create_from_str(child_cli_pkg->name), child_pkg);
        if (entry) {
            ZigPackage *existing_pkg = entry->value;
            Buf *full_path = buf_alloc();
            os_path_join(&existing_pkg->root_src_dir, &existing_pkg->root_src_path, full_path);
            fprintf(stderr, "Unable to add package '%s'->'%s': already exists as '%s'\n",
                    child_cli_pkg->name, child_cli_pkg->path, buf_ptr(full_path));
            exit(EXIT_FAILURE);
        }

        add_package(g, child_cli_pkg, child_pkg);
    }
}

enum CacheOpt {
    CacheOptAuto,
    CacheOptOn,
    CacheOptOff,
};

static bool get_cache_opt(CacheOpt opt, bool default_value) {
    switch (opt) {
        case CacheOptAuto:
            return default_value;
        case CacheOptOn:
            return true;
        case CacheOptOff:
            return false;
    }
    zig_unreachable();
}

static int zig_error_no_build_file(void) {
    fprintf(stderr,
        "No 'build.zig' file found, in the current directory or any parent directories.\n"
        "Initialize a 'build.zig' template file with `zig init-lib` or `zig init-exe`,\n"
        "or see `zig --help` for more options.\n"
    );
    return EXIT_FAILURE;
}

static bool str_starts_with(const char *s1, const char *s2) {
    size_t s2_len = strlen(s2);
    if (strlen(s1) < s2_len) {
        return false;
    }
    return memcmp(s1, s2, s2_len) == 0;
}

extern "C" int ZigClang_main(int argc, char **argv);

#ifdef ZIG_ENABLE_MEM_PROFILE
bool mem_report = false;
#endif

int main_exit(Stage2ProgressNode *root_progress_node, int exit_code) {
    if (root_progress_node != nullptr) {
        stage2_progress_end(root_progress_node);
    }
    return exit_code;
}

static int main0(int argc, char **argv) {
    char *arg0 = argv[0];
    Error err;

    if (argc >= 2 && (strcmp(argv[1], "clang") == 0 ||
            strcmp(argv[1], "-cc1") == 0 || strcmp(argv[1], "-cc1as") == 0))
    {
        return ZigClang_main(argc, argv);
    }

    if (argc == 2 && strcmp(argv[1], "id") == 0) {
        Buf *compiler_id;
        if ((err = get_compiler_id(&compiler_id))) {
            fprintf(stderr, "Unable to determine compiler id: %s\n", err_str(err));
            return EXIT_FAILURE;
        }
        printf("%s\n", buf_ptr(compiler_id));
        return EXIT_SUCCESS;
    }

    enum InitKind {
        InitKindNone,
        InitKindExe,
        InitKindLib,
    };
    InitKind init_kind = InitKindNone;
    if (argc >= 2) {
        const char *init_cmd = argv[1];
        if (strcmp(init_cmd, "init-exe") == 0) {
            init_kind = InitKindExe;
        } else if (strcmp(init_cmd, "init-lib") == 0) {
            init_kind = InitKindLib;
        }
        if (init_kind != InitKindNone) {
            if (argc >= 3) {
                fprintf(stderr, "Unexpected extra argument: %s\n", argv[2]);
                return print_error_usage(arg0);
            }
            Buf *cmd_template_path = buf_alloc();
            os_path_join(get_zig_special_dir(get_zig_lib_dir()), buf_create_from_str(init_cmd), cmd_template_path);
            Buf *build_zig_path = buf_alloc();
            os_path_join(cmd_template_path, buf_create_from_str("build.zig"), build_zig_path);
            Buf *src_dir_path = buf_alloc();
            os_path_join(cmd_template_path, buf_create_from_str("src"), src_dir_path);
            Buf *main_zig_path = buf_alloc();
            os_path_join(src_dir_path, buf_create_from_str("main.zig"), main_zig_path);

            Buf *cwd = buf_alloc();
            if ((err = os_get_cwd(cwd))) {
                fprintf(stderr, "Unable to get cwd: %s\n", err_str(err));
                return EXIT_FAILURE;
            }
            Buf *cwd_basename = buf_alloc();
            os_path_split(cwd, nullptr, cwd_basename);

            Buf *build_zig_contents = buf_alloc();
            if ((err = os_fetch_file_path(build_zig_path, build_zig_contents))) {
                fprintf(stderr, "Unable to read %s: %s\n", buf_ptr(build_zig_path), err_str(err));
                return EXIT_FAILURE;
            }
            Buf *modified_build_zig_contents = buf_alloc();
            for (size_t i = 0; i < buf_len(build_zig_contents); i += 1) {
                char c = buf_ptr(build_zig_contents)[i];
                if (c == '$') {
                    buf_append_buf(modified_build_zig_contents, cwd_basename);
                } else {
                    buf_append_char(modified_build_zig_contents, c);
                }
            }

            Buf *main_zig_contents = buf_alloc();
            if ((err = os_fetch_file_path(main_zig_path, main_zig_contents))) {
                fprintf(stderr, "Unable to read %s: %s\n", buf_ptr(main_zig_path), err_str(err));
                return EXIT_FAILURE;
            }

            Buf *out_build_zig_path = buf_create_from_str("build.zig");
            Buf *out_src_dir_path = buf_create_from_str("src");
            Buf *out_main_zig_path = buf_alloc();
            os_path_join(out_src_dir_path, buf_create_from_str("main.zig"), out_main_zig_path);

            bool already_exists;
            if ((err = os_file_exists(out_build_zig_path, &already_exists))) {
                fprintf(stderr, "Unable test existence of %s: %s\n", buf_ptr(out_build_zig_path), err_str(err));
                return EXIT_FAILURE;
            }
            if (already_exists) {
                fprintf(stderr, "This file would be overwritten: %s\n", buf_ptr(out_build_zig_path));
                return EXIT_FAILURE;
            }

            if ((err = os_make_dir(out_src_dir_path))) {
                fprintf(stderr, "Unable to make directory: %s: %s\n", buf_ptr(out_src_dir_path), err_str(err));
                return EXIT_FAILURE;
            }
            if ((err = os_write_file(out_build_zig_path, modified_build_zig_contents))) {
                fprintf(stderr, "Unable to write file: %s: %s\n", buf_ptr(out_build_zig_path), err_str(err));
                return EXIT_FAILURE;
            }
            if ((err = os_write_file(out_main_zig_path, main_zig_contents))) {
                fprintf(stderr, "Unable to write file: %s: %s\n", buf_ptr(out_main_zig_path), err_str(err));
                return EXIT_FAILURE;
            }
            fprintf(stderr, "Created %s\n", buf_ptr(out_build_zig_path));
            fprintf(stderr, "Created %s\n", buf_ptr(out_main_zig_path));
            if (init_kind == InitKindExe) {
                fprintf(stderr, "\nNext, try `zig build --help` or `zig build run`\n");
            } else if (init_kind == InitKindLib) {
                fprintf(stderr, "\nNext, try `zig build --help` or `zig build test`\n");
            } else {
                zig_unreachable();
            }

            return EXIT_SUCCESS;
        }
    }

    Cmd cmd = CmdNone;
    const char *in_file = nullptr;
    Buf *output_dir = nullptr;
    bool strip = false;
    bool is_dynamic = false;
    OutType out_type = OutTypeUnknown;
    const char *out_name = nullptr;
    bool verbose_tokenize = false;
    bool verbose_ast = false;
    bool verbose_link = false;
    bool verbose_ir = false;
    bool verbose_llvm_ir = false;
    bool verbose_cimport = false;
    bool verbose_cc = false;
    bool verbose_llvm_cpu_features = false;
    bool link_eh_frame_hdr = false;
    ErrColor color = ErrColorAuto;
    CacheOpt enable_cache = CacheOptAuto;
    const char *dynamic_linker = nullptr;
    const char *libc_txt = nullptr;
    ZigList<const char *> clang_argv = {0};
    ZigList<const char *> lib_dirs = {0};
    ZigList<const char *> link_libs = {0};
    ZigList<const char *> forbidden_link_libs = {0};
    ZigList<const char *> framework_dirs = {0};
    ZigList<const char *> frameworks = {0};
    bool have_libc = false;
    bool have_libcpp = false;
    const char *target_string = nullptr;
    bool rdynamic = false;
    const char *linker_script = nullptr;
    Buf *version_script = nullptr;
    ZigList<const char *> rpath_list = {0};
    bool each_lib_rpath = false;
    ZigList<const char *> objects = {0};
    ZigList<CFile *> c_source_files = {0};
    const char *test_filter = nullptr;
    const char *test_name_prefix = nullptr;
    bool test_evented_io = false;
    size_t ver_major = 0;
    size_t ver_minor = 0;
    size_t ver_patch = 0;
    bool timing_info = false;
    bool stack_report = false;
    bool enable_dump_analysis = false;
    bool enable_doc_generation = false;
    bool emit_bin = true;
    const char *emit_bin_override_path = nullptr;
    bool emit_asm = false;
    bool emit_llvm_ir = false;
    bool emit_h = false;
    const char *cache_dir = nullptr;
    CliPkg *cur_pkg = heap::c_allocator.create<CliPkg>();
    BuildMode build_mode = BuildModeDebug;
    ZigList<const char *> test_exec_args = {0};
    int runtime_args_start = -1;
    bool system_linker_hack = false;
    TargetSubsystem subsystem = TargetSubsystemAuto;
    bool want_single_threaded = false;
    bool bundle_compiler_rt = false;
    Buf *override_lib_dir = nullptr;
    Buf *main_pkg_path = nullptr;
    ValgrindSupport valgrind_support = ValgrindSupportAuto;
    WantPIC want_pic = WantPICAuto;
    WantStackCheck want_stack_check = WantStackCheckAuto;
    WantCSanitize want_sanitize_c = WantCSanitizeAuto;
    bool function_sections = false;
    const char *mcpu = nullptr;
    CodeModel code_model = CodeModelDefault;
    const char *override_soname = nullptr;
    bool only_pp_or_asm = false;
    bool ensure_libc_on_non_freestanding = false;
    bool ensure_libcpp_on_non_freestanding = false;
    bool disable_c_depfile = false;
    bool want_native_include_dirs = false;
    Buf *linker_optimization = nullptr;
    OptionalBool linker_gc_sections = OptionalBoolNull;
    OptionalBool linker_allow_shlib_undefined = OptionalBoolNull;
    OptionalBool linker_bind_global_refs_locally = OptionalBoolNull;
    bool linker_z_nodelete = false;
    bool linker_z_defs = false;
    size_t stack_size_override = 0;

    ZigList<const char *> llvm_argv = {0};
    llvm_argv.append("zig (LLVM option parsing)");

    if (argc >= 2 && strcmp(argv[1], "build") == 0) {
        Buf zig_exe_path_buf = BUF_INIT;
        if ((err = os_self_exe_path(&zig_exe_path_buf))) {
            fprintf(stderr, "Unable to determine path to zig's own executable\n");
            return EXIT_FAILURE;
        }
        const char *zig_exe_path = buf_ptr(&zig_exe_path_buf);
        const char *build_file = nullptr;

        init_all_targets();

        ZigList<const char *> args = {0};
        args.append(NULL); // placeholder
        args.append(zig_exe_path);
        args.append(NULL); // placeholder
        args.append(NULL); // placeholder
        for (int i = 2; i < argc; i += 1) {
            if (strcmp(argv[i], "--help") == 0) {
                args.append(argv[i]);
            } else if (i + 1 < argc && strcmp(argv[i], "--build-file") == 0) {
                build_file = argv[i + 1];
                i += 1;
            } else if (i + 1 < argc && strcmp(argv[i], "--cache-dir") == 0) {
                cache_dir = argv[i + 1];
                i += 1;
            } else if (i + 1 < argc && strcmp(argv[i], "--override-lib-dir") == 0) {
                override_lib_dir = buf_create_from_str(argv[i + 1]);
                i += 1;

                args.append("--override-lib-dir");
                args.append(buf_ptr(override_lib_dir));
            } else {
                args.append(argv[i]);
            }
        }

        Buf *zig_lib_dir = (override_lib_dir == nullptr) ? get_zig_lib_dir() : override_lib_dir;

        Buf *build_runner_path = buf_alloc();
        os_path_join(get_zig_special_dir(zig_lib_dir), buf_create_from_str("build_runner.zig"), build_runner_path);

        ZigTarget target;
        if ((err = target_parse_triple(&target, "native", nullptr, nullptr))) {
            fprintf(stderr, "Unable to get native target: %s\n", err_str(err));
            return EXIT_FAILURE;
        }

        Buf *build_file_buf = buf_create_from_str((build_file != nullptr) ? build_file : "build.zig");
        Buf build_file_abs = os_path_resolve(&build_file_buf, 1);
        Buf build_file_basename = BUF_INIT;
        Buf build_file_dirname = BUF_INIT;
        os_path_split(&build_file_abs, &build_file_dirname, &build_file_basename);

        for (;;) {
            bool build_file_exists;
            if ((err = os_file_exists(&build_file_abs, &build_file_exists))) {
                fprintf(stderr, "unable to check existence of '%s': %s\n", buf_ptr(&build_file_abs), err_str(err));
                return 1;
            }
            if (build_file_exists)
                break;

            if (build_file != nullptr) {
                // they asked for a specific build file path. only look for that one
                return zig_error_no_build_file();
            }

            Buf *next_dir = buf_alloc();
            os_path_dirname(&build_file_dirname, next_dir);
            if (buf_eql_buf(&build_file_dirname, next_dir)) {
                // no more parent directories to search, give up
                return zig_error_no_build_file();
            }
            os_path_join(next_dir, &build_file_basename, &build_file_abs);
            buf_init_from_buf(&build_file_dirname, next_dir);
        }

        Buf full_cache_dir = BUF_INIT;
        if (cache_dir == nullptr) {
            os_path_join(&build_file_dirname, buf_create_from_str(default_zig_cache_name), &full_cache_dir);
        } else {
            Buf *cache_dir_buf = buf_create_from_str(cache_dir);
            full_cache_dir = os_path_resolve(&cache_dir_buf, 1);
        }
        Stage2ProgressNode *root_progress_node = stage2_progress_start_root(stage2_progress_create(), "", 0, 0);

        CodeGen *g = codegen_create(main_pkg_path, build_runner_path, &target, OutTypeExe,
                BuildModeDebug, override_lib_dir, nullptr, &full_cache_dir, false, root_progress_node);
        g->valgrind_support = valgrind_support;
        g->enable_time_report = timing_info;
        codegen_set_out_name(g, buf_create_from_str("build"));

        args.items[2] = buf_ptr(&build_file_dirname);
        args.items[3] = buf_ptr(&full_cache_dir);

        ZigPackage *build_pkg = codegen_create_package(g, buf_ptr(&build_file_dirname),
                buf_ptr(&build_file_basename), "std.special");
        g->main_pkg->package_table.put(buf_create_from_str("@build"), build_pkg);
        g->enable_cache = get_cache_opt(enable_cache, true);
        codegen_build_and_link(g);
        if (root_progress_node != nullptr) {
            stage2_progress_end(root_progress_node);
            root_progress_node = nullptr;
        }

        Termination term;
        args.items[0] = buf_ptr(&g->bin_file_output_path);
        os_spawn_process(args, &term);
        if (term.how != TerminationIdClean || term.code != 0) {
            fprintf(stderr, "\nBuild failed. The following command failed:\n");
            const char *prefix = "";
            for (size_t i = 0; i < args.length; i += 1) {
                fprintf(stderr, "%s%s", prefix, args.at(i));
                prefix = " ";
            }
            fprintf(stderr, "\n");
        }
        return (term.how == TerminationIdClean) ? term.code : -1;
    } else if (argc >= 2 && strcmp(argv[1], "fmt") == 0) {
        return stage2_fmt(argc, argv);
    } else if (argc >= 2 && strcmp(argv[1], "env") == 0) {
        return stage2_env(argc, argv);
    } else if (argc >= 2 && (strcmp(argv[1], "cc") == 0 || strcmp(argv[1], "c++") == 0)) {
        emit_h = false;
        strip = true;
        ensure_libc_on_non_freestanding = true;
        ensure_libcpp_on_non_freestanding = (strcmp(argv[1], "c++") == 0);
        want_native_include_dirs = true;

        bool c_arg = false;
        Stage2ClangArgIterator it;
        stage2_clang_arg_iterator(&it, argc, argv);
        bool is_shared_lib = false;
        ZigList<Buf *> linker_args = {};
        while (it.has_next) {
            if ((err = stage2_clang_arg_next(&it))) {
                fprintf(stderr, "unable to parse command line parameters: %s\n", err_str(err));
                return EXIT_FAILURE;
            }
            switch (it.kind) {
                case Stage2ClangArgTarget: // example: -target riscv64-linux-unknown
                    target_string = it.only_arg;
                    break;
                case Stage2ClangArgO: // -o
                    emit_bin_override_path = it.only_arg;
                    enable_cache = CacheOptOn;
                    break;
                case Stage2ClangArgC: // -c
                    c_arg = true;
                    break;
                case Stage2ClangArgOther:
                    for (size_t i = 0; i < it.other_args_len; i += 1) {
                        clang_argv.append(it.other_args_ptr[i]);
                    }
                    break;
                case Stage2ClangArgPositional: {
                    FileExt file_ext = classify_file_ext(it.only_arg, strlen(it.only_arg));
                    switch (file_ext) {
                        case FileExtAsm:
                        case FileExtC:
                        case FileExtCpp:
                        case FileExtLLVMIr:
                        case FileExtLLVMBitCode:
                        case FileExtHeader: {
                            CFile *c_file = heap::c_allocator.create<CFile>();
                            c_file->source_path = it.only_arg;
                            c_source_files.append(c_file);
                            break;
                        }
                        case FileExtUnknown:
                            objects.append(it.only_arg);
                            break;
                    }
                    break;
                }
                case Stage2ClangArgL: // -l
                    if (strcmp(it.only_arg, "c") == 0) {
                        have_libc = true;
                        link_libs.append("c");
                    } else if (strcmp(it.only_arg, "c++") == 0 ||
                        strcmp(it.only_arg, "stdc++") == 0)
                    {
                        have_libcpp = true;
                        link_libs.append("c++");
                    } else {
                        link_libs.append(it.only_arg);
                    }
                    break;
                case Stage2ClangArgIgnore:
                    break;
                case Stage2ClangArgDriverPunt:
                    // Never mind what we're doing, just pass the args directly. For example --help.
                    return ZigClang_main(argc, argv);
                case Stage2ClangArgPIC:
                    want_pic = WantPICEnabled;
                    break;
                case Stage2ClangArgNoPIC:
                    want_pic = WantPICDisabled;
                    break;
                case Stage2ClangArgNoStdLib:
                    ensure_libc_on_non_freestanding = false;
                    break;
                case Stage2ClangArgNoStdLibCpp:
                    ensure_libcpp_on_non_freestanding = false;
                    break;
                case Stage2ClangArgShared:
                    is_dynamic = true;
                    is_shared_lib = true;
                    break;
                case Stage2ClangArgRDynamic:
                    rdynamic = true;
                    break;
                case Stage2ClangArgWL: {
                    const char *arg = it.only_arg;
                    for (;;) {
                        size_t pos = 0;
                        while (arg[pos] != ',' && arg[pos] != 0) pos += 1;
                        linker_args.append(buf_create_from_mem(arg, pos));
                        if (arg[pos] == 0) break;
                        arg += pos + 1;
                    }
                    break;
                }
                case Stage2ClangArgPreprocessOrAsm:
                    // this handles both -E and -S
                    only_pp_or_asm = true;
                    for (size_t i = 0; i < it.other_args_len; i += 1) {
                        clang_argv.append(it.other_args_ptr[i]);
                    }
                    break;
                case Stage2ClangArgOptimize:
                    // alright what release mode do they want?
                    if (strcmp(it.only_arg, "Os") == 0) {
                        build_mode = BuildModeSmallRelease;
                    } else if (strcmp(it.only_arg, "O2") == 0 ||
                            strcmp(it.only_arg, "O3") == 0 ||
                            strcmp(it.only_arg, "O4") == 0)
                    {
                        build_mode = BuildModeFastRelease;
                    } else if (strcmp(it.only_arg, "Og") == 0 ||
                            strcmp(it.only_arg, "O0") == 0)
                    {
                        build_mode = BuildModeDebug;
                    } else {
                        for (size_t i = 0; i < it.other_args_len; i += 1) {
                            clang_argv.append(it.other_args_ptr[i]);
                        }
                    }
                    break;
                case Stage2ClangArgDebug:
                    strip = false;
                    if (strcmp(it.only_arg, "-g") == 0) {
                        // we handled with strip = false above
                    } else {
                        for (size_t i = 0; i < it.other_args_len; i += 1) {
                            clang_argv.append(it.other_args_ptr[i]);
                        }
                    }
                    break;
                case Stage2ClangArgSanitize:
                    if (strcmp(it.only_arg, "undefined") == 0) {
                        want_sanitize_c = WantCSanitizeEnabled;
                    } else {
                        for (size_t i = 0; i < it.other_args_len; i += 1) {
                            clang_argv.append(it.other_args_ptr[i]);
                        }
                    }
                    break;
                case Stage2ClangArgLinkerScript:
                    linker_script = it.only_arg;
                    break;
                case Stage2ClangArgVerboseCmds:
                    verbose_cc = true;
                    verbose_link = true;
                    break;
                case Stage2ClangArgForLinker:
                    linker_args.append(buf_create_from_str(it.only_arg));
                    break;
                case Stage2ClangArgLinkerInputZ:
                    linker_args.append(buf_create_from_str("-z"));
                    linker_args.append(buf_create_from_str(it.only_arg));
                    break;
                case Stage2ClangArgLibDir:
                    lib_dirs.append(it.only_arg);
                    break;
                case Stage2ClangArgMCpu:
                    mcpu = it.only_arg;
                    break;
                case Stage2ClangArgDepFile:
                    disable_c_depfile = true;
                    for (size_t i = 0; i < it.other_args_len; i += 1) {
                        clang_argv.append(it.other_args_ptr[i]);
                    }
                    break;
                case Stage2ClangArgFrameworkDir:
                    framework_dirs.append(it.only_arg);
                    break;
                case Stage2ClangArgFramework:
                    frameworks.append(it.only_arg);
                    break;
                case Stage2ClangArgNoStdLibInc:
                    want_native_include_dirs = false;
                    break;
            }
        }
        // Parse linker args
        for (size_t i = 0; i < linker_args.length; i += 1) {
            Buf *arg = linker_args.at(i);
            if (buf_eql_str(arg, "-soname")) {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                Buf *soname_buf = linker_args.at(i);
                override_soname = buf_ptr(soname_buf);
                // use it as --name
                // example: libsoundio.so.2
                size_t prefix = 0;
                if (buf_starts_with_str(soname_buf, "lib")) {
                    prefix = 3;
                }
                size_t end = buf_len(soname_buf);
                if (buf_ends_with_str(soname_buf, ".so")) {
                    end -= 3;
                } else {
                    bool found_digit = false;
                    while (end > 0 && isdigit(buf_ptr(soname_buf)[end - 1])) {
                        found_digit = true;
                        end -= 1;
                    }
                    if (found_digit && end > 0 && buf_ptr(soname_buf)[end - 1] == '.') {
                        end -= 1;
                    } else {
                        end = buf_len(soname_buf);
                    }
                    if (buf_ends_with_str(buf_slice(soname_buf, prefix, end), ".so")) {
                        end -= 3;
                    }
                }
                out_name = buf_ptr(buf_slice(soname_buf, prefix, end));
            } else if (buf_eql_str(arg, "-rpath")) {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                Buf *rpath = linker_args.at(i);
                rpath_list.append(buf_ptr(rpath));
            } else if (buf_eql_str(arg, "-I") ||
                buf_eql_str(arg, "--dynamic-linker") ||
                buf_eql_str(arg, "-dynamic-linker"))
            {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                dynamic_linker = buf_ptr(linker_args.at(i));
            } else if (buf_eql_str(arg, "-E") ||
                buf_eql_str(arg, "--export-dynamic") ||
                buf_eql_str(arg, "-export-dynamic"))
            {
                rdynamic = true;
            } else if (buf_eql_str(arg, "--version-script")) {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                version_script = linker_args.at(i);
            } else if (buf_starts_with_str(arg, "-O")) {
                linker_optimization = arg;
            } else if (buf_eql_str(arg, "--gc-sections")) {
                linker_gc_sections = OptionalBoolTrue;
            } else if (buf_eql_str(arg, "--no-gc-sections")) {
                linker_gc_sections = OptionalBoolFalse;
            } else if (buf_eql_str(arg, "--allow-shlib-undefined") ||
                       buf_eql_str(arg, "-allow-shlib-undefined"))
            {
                linker_allow_shlib_undefined = OptionalBoolTrue;
            } else if (buf_eql_str(arg, "--no-allow-shlib-undefined") ||
                       buf_eql_str(arg, "-no-allow-shlib-undefined"))
            {
                linker_allow_shlib_undefined = OptionalBoolFalse;
            } else if (buf_eql_str(arg, "-Bsymbolic")) {
                linker_bind_global_refs_locally = OptionalBoolTrue;
            } else if (buf_eql_str(arg, "-z")) {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                Buf *z_arg = linker_args.at(i);
                if (buf_eql_str(z_arg, "nodelete")) {
                    linker_z_nodelete = true;
                } else if (buf_eql_str(z_arg, "defs")) {
                    linker_z_defs = true;
                } else {
                    fprintf(stderr, "warning: unsupported linker arg: -z %s\n", buf_ptr(z_arg));
                }
            } else if (buf_eql_str(arg, "--major-image-version")) {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                ver_major = atoi(buf_ptr(linker_args.at(i)));
            } else if (buf_eql_str(arg, "--minor-image-version")) {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                ver_minor = atoi(buf_ptr(linker_args.at(i)));
            } else if (buf_eql_str(arg, "--stack")) {
                i += 1;
                if (i >= linker_args.length) {
                    fprintf(stderr, "expected linker arg after '%s'\n", buf_ptr(arg));
                    return EXIT_FAILURE;
                }
                stack_size_override = atoi(buf_ptr(linker_args.at(i)));
            } else {
                fprintf(stderr, "warning: unsupported linker arg: %s\n", buf_ptr(arg));
            }
        }

        if (want_sanitize_c == WantCSanitizeEnabled && build_mode == BuildModeFastRelease) {
            build_mode = BuildModeSafeRelease;
        }

        if (only_pp_or_asm) {
            cmd = CmdBuild;
            out_type = OutTypeObj;
            emit_bin = false;
            // Transfer "objects" into c_source_files
            for (size_t i = 0; i < objects.length; i += 1) {
                CFile *c_file = heap::c_allocator.create<CFile>();
                c_file->source_path = objects.at(i);
                c_source_files.append(c_file);
            }
            for (size_t i = 0; i < c_source_files.length; i += 1) {
                Buf *src_path;
                if (emit_bin_override_path != nullptr) {
                    src_path = buf_create_from_str(emit_bin_override_path);
                } else {
                    src_path = buf_create_from_str(c_source_files.at(i)->source_path);
                }
                Buf basename = BUF_INIT;
                os_path_split(src_path, nullptr, &basename);
                c_source_files.at(i)->preprocessor_only_basename = buf_ptr(&basename);
            }
        } else if (!c_arg) {
            cmd = CmdBuild;
            if (is_shared_lib) {
                out_type = OutTypeLib;
            } else {
                out_type = OutTypeExe;
            }
            if (emit_bin_override_path == nullptr) {
                emit_bin_override_path = "a.out";
                enable_cache = CacheOptOn;
            }
        } else {
            cmd = CmdBuild;
            out_type = OutTypeObj;
        }
        if (c_source_files.length == 0 && objects.length == 0) {
            // For example `zig cc` and no args should print the "no input files" message.
            return ZigClang_main(argc, argv);
        }
    } else for (int i = 1; i < argc; i += 1) {
        char *arg = argv[i];

        if (arg[0] == '-') {
            if (strcmp(arg, "--") == 0) {
                if (cmd == CmdRun) {
                    runtime_args_start = i + 1;
                    break; // rest of the args are for the program
                } else {
                    fprintf(stderr, "Unexpected end-of-parameter mark: %s\n", arg);
                }
            } else if (strcmp(arg, "--release-fast") == 0) {
                build_mode = BuildModeFastRelease;
            } else if (strcmp(arg, "--release-safe") == 0) {
                build_mode = BuildModeSafeRelease;
            } else if (strcmp(arg, "--release-small") == 0) {
                build_mode = BuildModeSmallRelease;
            } else if (strcmp(arg, "--help") == 0) {
                if (cmd == CmdLibC) {
                    return print_libc_usage(arg0, stdout, EXIT_SUCCESS);
                } else {
                    return print_full_usage(arg0, stdout, EXIT_SUCCESS);
                }
            } else if (strcmp(arg, "--strip") == 0) {
                strip = true;
            } else if (strcmp(arg, "-dynamic") == 0) {
                is_dynamic = true;
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
            } else if (strcmp(arg, "--verbose-cc") == 0) {
                verbose_cc = true;
            } else if (strcmp(arg, "--verbose-llvm-cpu-features") == 0) {
                verbose_llvm_cpu_features = true;
            } else if (strcmp(arg, "-rdynamic") == 0) {
                rdynamic = true;
            } else if (strcmp(arg, "--each-lib-rpath") == 0) {
                each_lib_rpath = true;
            } else if (strcmp(arg, "-ftime-report") == 0) {
                timing_info = true;
            } else if (strcmp(arg, "-fstack-report") == 0) {
                stack_report = true;
            } else if (strcmp(arg, "-fmem-report") == 0) {
#ifdef ZIG_ENABLE_MEM_PROFILE
                mem_report = true;
                mem::report_print = true;
#else
                fprintf(stderr, "-fmem-report requires configuring with -DZIG_ENABLE_MEM_PROFILE=ON\n");
                return print_error_usage(arg0);
#endif
            } else if (strcmp(arg, "-fdump-analysis") == 0) {
                enable_dump_analysis = true;
            } else if (strcmp(arg, "-femit-docs") == 0) {
                enable_doc_generation = true;
            } else if (strcmp(arg, "--enable-valgrind") == 0) {
                valgrind_support = ValgrindSupportEnabled;
            } else if (strcmp(arg, "--disable-valgrind") == 0) {
                valgrind_support = ValgrindSupportDisabled;
            } else if (strcmp(arg, "--eh-frame-hdr") == 0) {
                link_eh_frame_hdr = true;
            } else if (strcmp(arg, "-fPIC") == 0) {
                want_pic = WantPICEnabled;
            } else if (strcmp(arg, "-fno-PIC") == 0) {
                want_pic = WantPICDisabled;
            } else if (strcmp(arg, "-fstack-check") == 0) {
                want_stack_check = WantStackCheckEnabled;
            } else if (strcmp(arg, "-fno-stack-check") == 0) {
                want_stack_check = WantStackCheckDisabled;
            } else if (strcmp(arg, "-fsanitize-c") == 0) {
                want_sanitize_c = WantCSanitizeEnabled;
            } else if (strcmp(arg, "-fno-sanitize-c") == 0) {
                want_sanitize_c = WantCSanitizeDisabled;
            } else if (strcmp(arg, "--system-linker-hack") == 0) {
                system_linker_hack = true;
            } else if (strcmp(arg, "--single-threaded") == 0) {
                want_single_threaded = true;;
            } else if (strcmp(arg, "--bundle-compiler-rt") == 0) {
                bundle_compiler_rt = true;
            } else if (strcmp(arg, "-Bsymbolic") == 0) {
                linker_bind_global_refs_locally = OptionalBoolTrue;
            } else if (strcmp(arg, "--test-cmd-bin") == 0) {
                test_exec_args.append(nullptr);
            } else if (arg[1] == 'D' && arg[2] != 0) {
                clang_argv.append("-D");
                clang_argv.append(&arg[2]);
            } else if (arg[1] == 'L' && arg[2] != 0) {
                // alias for --library-path
                lib_dirs.append(&arg[2]);
            } else if (arg[1] == 'l' && arg[2] != 0) {
                // alias for --library
                const char *l = &arg[2];
                if (strcmp(l, "c") == 0) {
                    have_libc = true;
                    link_libs.append("c");
                } else if (strcmp(l, "c++") == 0 || strcmp(l, "stdc++") == 0) {
                    have_libcpp = true;
                    link_libs.append("c++");
                } else {
                    link_libs.append(l);
                }
            } else if (arg[1] == 'I' && arg[2] != 0) {
                clang_argv.append("-I");
                clang_argv.append(&arg[2]);
            } else if (arg[1] == 'F' && arg[2] != 0) {
                framework_dirs.append(&arg[2]);
            } else if (strcmp(arg, "--pkg-begin") == 0) {
                if (i + 2 >= argc) {
                    fprintf(stderr, "Expected 2 arguments after --pkg-begin\n");
                    return print_error_usage(arg0);
                }
                CliPkg *new_cur_pkg = heap::c_allocator.create<CliPkg>();
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
            } else if (strcmp(arg, "-ffunction-sections") == 0) {
                function_sections = true;
            } else if (strcmp(arg, "--test-evented-io") == 0) {
                test_evented_io = true;
            } else if (strcmp(arg, "-femit-bin") == 0) {
                emit_bin = true;
            } else if (strcmp(arg, "-fno-emit-bin") == 0) {
                emit_bin = false;
            } else if (strcmp(arg, "-femit-asm") == 0) {
                emit_asm = true;
            } else if (strcmp(arg, "-fno-emit-asm") == 0) {
                emit_asm = false;
            } else if (strcmp(arg, "-femit-llvm-ir") == 0) {
                emit_llvm_ir = true;
            } else if (strcmp(arg, "-fno-emit-llvm-ir") == 0) {
                emit_llvm_ir = false;
            } else if (strcmp(arg, "-femit-h") == 0) {
                emit_h = true;
            } else if (strcmp(arg, "-fno-emit-h") == 0 || strcmp(arg, "--disable-gen-h") == 0) {
                // the --disable-gen-h is there to support godbolt. once they upgrade to -fno-emit-h then we can remove this
                emit_h = false;
            } else if (str_starts_with(arg, "-mcpu=")) {
                mcpu = arg + strlen("-mcpu=");
            } else if (i + 1 >= argc) {
                fprintf(stderr, "Expected another argument after %s\n", arg);
                return print_error_usage(arg0);
            } else {
                i += 1;
                if (strcmp(arg, "--output-dir") == 0) {
                    output_dir = buf_create_from_str(argv[i]);
                } else if (strcmp(arg, "--color") == 0) {
                    if (strcmp(argv[i], "auto") == 0) {
                        color = ErrColorAuto;
                    } else if (strcmp(argv[i], "on") == 0) {
                        color = ErrColorOn;
                    } else if (strcmp(argv[i], "off") == 0) {
                        color = ErrColorOff;
                    } else {
                        fprintf(stderr, "--color options are 'auto', 'on', or 'off'\n");
                        return print_error_usage(arg0);
                    }
                } else if (strcmp(arg, "--cache") == 0) {
                    if (strcmp(argv[i], "auto") == 0) {
                        enable_cache = CacheOptAuto;
                    } else if (strcmp(argv[i], "on") == 0) {
                        enable_cache = CacheOptOn;
                    } else if (strcmp(argv[i], "off") == 0) {
                        enable_cache = CacheOptOff;
                    } else {
                        fprintf(stderr, "--cache options are 'auto', 'on', or 'off'\n");
                        return print_error_usage(arg0);
                    }
                } else if (strcmp(arg, "--emit") == 0) {
                    if (strcmp(argv[i], "asm") == 0) {
                        emit_asm = true;
                        emit_bin = false;
                    } else if (strcmp(argv[i], "bin") == 0) {
                        emit_bin = true;
                    } else if (strcmp(argv[i], "llvm-ir") == 0) {
                        emit_llvm_ir = true;
                        emit_bin = false;
                    } else {
                        fprintf(stderr, "--emit options are 'asm', 'bin', or 'llvm-ir'\n");
                        return print_error_usage(arg0);
                    }
                } else if (strcmp(arg, "--name") == 0) {
                    out_name = argv[i];
                } else if (strcmp(arg, "--dynamic-linker") == 0) {
                    dynamic_linker = argv[i];
                } else if (strcmp(arg, "--libc") == 0) {
                    libc_txt = argv[i];
                } else if (strcmp(arg, "-D") == 0) {
                    clang_argv.append("-D");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-isystem") == 0) {
                    clang_argv.append("-isystem");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-I") == 0) {
                    clang_argv.append("-I");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-dirafter") == 0) {
                    clang_argv.append("-dirafter");
                    clang_argv.append(argv[i]);
                } else if (strcmp(arg, "-mllvm") == 0) {
                    clang_argv.append("-mllvm");
                    clang_argv.append(argv[i]);

                    llvm_argv.append(argv[i]);
                } else if (strcmp(arg, "-code-model") == 0) {
                    if (strcmp(argv[i], "default") == 0) {
                        code_model = CodeModelDefault;
                    } else if (strcmp(argv[i], "tiny") == 0) {
                        code_model = CodeModelTiny;
                    } else if (strcmp(argv[i], "small") == 0) {
                        code_model = CodeModelSmall;
                    } else if (strcmp(argv[i], "kernel") == 0) {
                        code_model = CodeModelKernel;
                    } else if (strcmp(argv[i], "medium") == 0) {
                        code_model = CodeModelMedium;
                    } else if (strcmp(argv[i], "large") == 0) {
                        code_model = CodeModelLarge;
                    } else {
                        fprintf(stderr, "-code-model options are 'default', 'tiny', 'small', 'kernel', 'medium', or 'large'\n");
                        return print_error_usage(arg0);
                    }
                } else if (strcmp(arg, "--override-lib-dir") == 0) {
                    override_lib_dir = buf_create_from_str(argv[i]);
                } else if (strcmp(arg, "--main-pkg-path") == 0) {
                    main_pkg_path = buf_create_from_str(argv[i]);
                } else if (strcmp(arg, "--library-path") == 0 || strcmp(arg, "-L") == 0) {
                    lib_dirs.append(argv[i]);
                } else if (strcmp(arg, "-F") == 0) {
                    framework_dirs.append(argv[i]);
                } else if (strcmp(arg, "--library") == 0 || strcmp(arg, "-l") == 0) {
                    if (strcmp(argv[i], "c") == 0) {
                        have_libc = true;
                        link_libs.append("c");
                    } else if (strcmp(argv[i], "c++") == 0 || strcmp(argv[i], "stdc++") == 0) {
                        have_libcpp = true;
                        link_libs.append("c++");
                    } else {
                        link_libs.append(argv[i]);
                    }
                } else if (strcmp(arg, "--forbid-library") == 0) {
                    forbidden_link_libs.append(argv[i]);
                } else if (strcmp(arg, "--object") == 0) {
                    objects.append(argv[i]);
                } else if (strcmp(arg, "--c-source") == 0) {
                    CFile *c_file = heap::c_allocator.create<CFile>();
                    for (;;) {
                        if (argv[i][0] == '-') {
                            c_file->args.append(argv[i]);
                            i += 1;
                            if (i < argc) {
                                continue;
                            }

                            break;
                        } else {
                            c_file->source_path = argv[i];
                            c_source_files.append(c_file);
                            break;
                        }
                    }
                } else if (strcmp(arg, "--cache-dir") == 0) {
                    cache_dir = argv[i];
                } else if (strcmp(arg, "-target") == 0) {
                    target_string = argv[i];
                } else if (strcmp(arg, "-framework") == 0) {
                    frameworks.append(argv[i]);
                } else if (strcmp(arg, "--linker-script") == 0) {
                    linker_script = argv[i];
                } else if (strcmp(arg, "--version-script") == 0) {
                    version_script = buf_create_from_str(argv[i]); 
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
                } else if (strcmp(arg, "--stack") == 0) {
                    stack_size_override = atoi(argv[i]);
                } else if (strcmp(arg, "--subsystem") == 0) {
                    if (strcmp(argv[i], "console") == 0) {
                        subsystem = TargetSubsystemConsole;
                    } else if (strcmp(argv[i], "windows") == 0) {
                        subsystem = TargetSubsystemWindows;
                    } else if (strcmp(argv[i], "posix") == 0) {
                        subsystem = TargetSubsystemPosix;
                    } else if (strcmp(argv[i], "native") == 0) {
                        subsystem = TargetSubsystemNative;
                    } else if (strcmp(argv[i], "efi_application") == 0) {
                        subsystem = TargetSubsystemEfiApplication;
                    } else if (strcmp(argv[i], "efi_boot_service_driver") == 0) {
                        subsystem = TargetSubsystemEfiBootServiceDriver;
                    } else if (strcmp(argv[i], "efi_rom") == 0) {
                        subsystem = TargetSubsystemEfiRom;
                    } else if (strcmp(argv[i], "efi_runtime_driver") == 0) {
                        subsystem = TargetSubsystemEfiRuntimeDriver;
                    } else {
                        fprintf(stderr, "invalid: --subsystem %s\n"
                                "Options are:\n"
                                "  console\n"
                                "  windows\n"
                                "  posix\n"
                                "  native\n"
                                "  efi_application\n"
                                "  efi_boot_service_driver\n"
                                "  efi_rom\n"
                                "  efi_runtime_driver\n"
                            , argv[i]);
                        return EXIT_FAILURE;
                    }
                } else if (strcmp(arg, "-mcpu") == 0) {
                    mcpu = argv[i];
                } else {
                    fprintf(stderr, "Invalid argument: %s\n", arg);
                    return print_error_usage(arg0);
                }
            }
        } else if (cmd == CmdNone) {
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
            } else if (strcmp(arg, "libc") == 0) {
                cmd = CmdLibC;
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
                return print_error_usage(arg0);
            }
        } else {
            switch (cmd) {
                case CmdBuild:
                case CmdRun:
                case CmdTranslateC:
                case CmdTest:
                case CmdLibC:
                    if (!in_file) {
                        in_file = arg;
                    } else {
                        fprintf(stderr, "Unexpected extra parameter: %s\n", arg);
                        return print_error_usage(arg0);
                    }
                    break;
                case CmdBuiltin:
                case CmdVersion:
                case CmdZen:
                case CmdTargets:
                    fprintf(stderr, "Unexpected extra parameter: %s\n", arg);
                    return print_error_usage(arg0);
                case CmdNone:
                    zig_unreachable();
            }
        }
    }

    if (cur_pkg->parent != nullptr) {
        fprintf(stderr, "Unmatched --pkg-begin\n");
        return EXIT_FAILURE;
    }

    Stage2Progress *progress = stage2_progress_create();
    Stage2ProgressNode *root_progress_node = stage2_progress_start_root(progress, "", 0, 0);
    if (color == ErrColorOff) stage2_progress_disable_tty(progress);

    init_all_targets();

    ZigTarget target;
    if ((err = target_parse_triple(&target, target_string, mcpu, dynamic_linker))) {
        fprintf(stderr, "invalid target: %s\n"
                "See `%s targets` to display valid targets.\n", err_str(err), arg0);
        return print_error_usage(arg0);
    }

    if (!have_libc && ensure_libc_on_non_freestanding && target.os != OsFreestanding) {
        have_libc = true;
        link_libs.append("c");
    }
    if (!have_libcpp && ensure_libcpp_on_non_freestanding && target.os != OsFreestanding) {
        have_libcpp = true;
        link_libs.append("c++");
    }

    Buf zig_triple_buf = BUF_INIT;
    target_triple_zig(&zig_triple_buf, &target);

    // If both output_dir and enable_cache are provided, and doing build-lib, we
    // will just do a file copy at the end. This helps when bootstrapping zig from zig0
    // because we want to pass something like this:
    // zig0 build-lib --cache on --output-dir ${CMAKE_BINARY_DIR}
    // And we don't have access to `zig0 build` because that would require detecting native libc
    // on systems where we are not able to build a libc from source for them.
    // But that's the only reason this works, so otherwise we give an error here.
    Buf *final_output_dir_step = nullptr;
    if (output_dir != nullptr && enable_cache == CacheOptOn) {
        if (cmd == CmdBuild && out_type == OutTypeLib) {
            final_output_dir_step = output_dir;
            output_dir = nullptr;
        } else {
            fprintf(stderr, "`--output-dir` is incompatible with --cache on.\n");
            return print_error_usage(arg0);
        }
    }

    if (target_requires_pic(&target, have_libc) && want_pic == WantPICDisabled) {
        fprintf(stderr, "`--disable-pic` is incompatible with target '%s'\n", buf_ptr(&zig_triple_buf));
        return print_error_usage(arg0);
    }

    if ((emit_asm || emit_llvm_ir) && in_file == nullptr) {
        fprintf(stderr, "A root source file is required when using `-femit-asm` or `-femit-llvm-ir`\n");
        return print_error_usage(arg0);
    }

    if (llvm_argv.length > 1) {
        llvm_argv.append(nullptr);
        ZigLLVMParseCommandLineOptions(llvm_argv.length - 1, llvm_argv.items);
    }

    switch (cmd) {
    case CmdLibC: {
        if (in_file) {
            Stage2LibCInstallation libc;
            if ((err = stage2_libc_parse(&libc, in_file))) {
                fprintf(stderr, "unable to parse libc file: %s\n", err_str(err));
                return main_exit(root_progress_node, EXIT_FAILURE);
            }
            return main_exit(root_progress_node, EXIT_SUCCESS);
        }
        Stage2LibCInstallation libc;
        if ((err = stage2_libc_find_native(&libc))) {
            fprintf(stderr, "unable to find native libc file: %s\n", err_str(err));
            return main_exit(root_progress_node, EXIT_FAILURE);
        }
        if ((err = stage2_libc_render(&libc, stdout))) {
            fprintf(stderr, "unable to print libc file: %s\n", err_str(err));
            return main_exit(root_progress_node, EXIT_FAILURE);
        }
        return main_exit(root_progress_node, EXIT_SUCCESS);
    }
    case CmdBuiltin: {
        CodeGen *g = codegen_create(main_pkg_path, nullptr, &target,
                out_type, build_mode, override_lib_dir, nullptr, nullptr, false, root_progress_node);
        codegen_set_strip(g, strip);
        for (size_t i = 0; i < link_libs.length; i += 1) {
            LinkLib *link_lib = codegen_add_link_lib(g, buf_create_from_str(link_libs.at(i)));
            link_lib->provided_explicitly = true;
        }
        g->subsystem = subsystem;
        g->valgrind_support = valgrind_support;
        g->want_pic = want_pic;
        g->want_stack_check = want_stack_check;
        g->want_sanitize_c = want_sanitize_c;
        g->want_single_threaded = want_single_threaded;
        g->test_is_evented = test_evented_io;
        Buf *builtin_source = codegen_generate_builtin_source(g);
        if (fwrite(buf_ptr(builtin_source), 1, buf_len(builtin_source), stdout) != buf_len(builtin_source)) {
            fprintf(stderr, "unable to write to stdout: %s\n", strerror(ferror(stdout)));
            return main_exit(root_progress_node, EXIT_FAILURE);
        }
        return main_exit(root_progress_node, EXIT_SUCCESS);
    }
    case CmdRun:
    case CmdBuild:
    case CmdTranslateC:
    case CmdTest:
        {
            if (cmd == CmdBuild && !in_file && objects.length == 0 &&
                    c_source_files.length == 0)
            {
                fprintf(stderr,
                    "Expected at least one of these things:\n"
                    " * Zig root source file argument\n"
                    " * --object argument\n"
                    " * --c-source argument\n");
                return print_error_usage(arg0);
            } else if ((cmd == CmdTranslateC ||
                        cmd == CmdTest || cmd == CmdRun) && !in_file)
            {
                fprintf(stderr, "Expected source file argument.\n");
                return print_error_usage(arg0);
            } else if (cmd == CmdRun && !emit_bin) {
                fprintf(stderr, "Cannot run without emitting a binary file.\n");
                return print_error_usage(arg0);
            }

            bool any_system_lib_dependencies = false;
            for (size_t i = 0; i < link_libs.length; i += 1) {
                if (!target_is_libc_lib_name(&target, link_libs.at(i)) &&
                    !target_is_libcpp_lib_name(&target, link_libs.at(i)))
                {
                    any_system_lib_dependencies = true;
                    break;
                }
            }

            if (target.is_native_os && (any_system_lib_dependencies || want_native_include_dirs)) {
                Error err;
                Stage2NativePaths paths;
                if ((err = stage2_detect_native_paths(&paths))) {
                    fprintf(stderr, "unable to detect native system paths: %s\n", err_str(err));
                    exit(1);
                }
                for (size_t i = 0; i < paths.warnings_len; i += 1) {
                    const char *warning = paths.warnings_ptr[i];
                    fprintf(stderr, "warning: %s\n", warning);
                }
                for (size_t i = 0; i < paths.include_dirs_len; i += 1) {
                    const char *include_dir = paths.include_dirs_ptr[i];
                    clang_argv.append("-isystem");
                    clang_argv.append(include_dir);
                }
                for (size_t i = 0; i < paths.lib_dirs_len; i += 1) {
                    const char *lib_dir = paths.lib_dirs_ptr[i];
                    lib_dirs.append(lib_dir);
                }
                for (size_t i = 0; i < paths.rpaths_len; i += 1) {
                    const char *rpath = paths.rpaths_ptr[i];
                    rpath_list.append(rpath);
                }
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

            if (need_name && buf_out_name == nullptr && c_source_files.length == 1) {
                Buf basename = BUF_INIT;
                os_path_split(buf_create_from_str(c_source_files.at(0)->source_path), nullptr, &basename);
                buf_out_name = buf_alloc();
                os_path_extname(&basename, buf_out_name, nullptr);
            }
            if (need_name && buf_out_name == nullptr && objects.length == 1) {
                Buf basename = BUF_INIT;
                os_path_split(buf_create_from_str(objects.at(0)), nullptr, &basename);
                buf_out_name = buf_alloc();
                os_path_extname(&basename, buf_out_name, nullptr);
            }
            if (need_name && buf_out_name == nullptr && emit_bin_override_path != nullptr) {
                Buf basename = BUF_INIT;
                os_path_split(buf_create_from_str(emit_bin_override_path), nullptr, &basename);
                buf_out_name = buf_alloc();
                os_path_extname(&basename, buf_out_name, nullptr);
            }

            if (need_name && buf_out_name == nullptr) {
                fprintf(stderr, "--name [name] not provided and unable to infer\n\n");
                return print_error_usage(arg0);
            }

            Buf *zig_root_source_file = (cmd == CmdTranslateC) ? nullptr : in_file_buf;

            if (cmd == CmdRun && buf_out_name == nullptr) {
                buf_out_name = buf_create_from_str("run");
            }
            Stage2LibCInstallation *libc = nullptr;
            if (libc_txt != nullptr) {
                libc = heap::c_allocator.create<Stage2LibCInstallation>();
                if ((err = stage2_libc_parse(libc, libc_txt))) {
                    fprintf(stderr, "Unable to parse --libc text file: %s\n", err_str(err));
                    return main_exit(root_progress_node, EXIT_FAILURE);
                }
            }
            Buf *cache_dir_buf;
            if (cache_dir == nullptr) {
                if (cmd == CmdRun) {
                    cache_dir_buf = get_global_cache_dir();
                } else {
                    cache_dir_buf = buf_create_from_str(default_zig_cache_name);
                }
            } else {
                cache_dir_buf = buf_create_from_str(cache_dir);
            }
            CodeGen *g = codegen_create(main_pkg_path, zig_root_source_file, &target, out_type, build_mode,
                    override_lib_dir, libc, cache_dir_buf, cmd == CmdTest, root_progress_node);
            if (llvm_argv.length >= 2) codegen_set_llvm_argv(g, llvm_argv.items + 1, llvm_argv.length - 2);
            g->valgrind_support = valgrind_support;
            g->link_eh_frame_hdr = link_eh_frame_hdr;
            g->want_pic = want_pic;
            g->want_stack_check = want_stack_check;
            g->want_sanitize_c = want_sanitize_c;
            g->subsystem = subsystem;

            g->enable_time_report = timing_info;
            g->enable_stack_report = stack_report;
            g->enable_dump_analysis = enable_dump_analysis;
            g->enable_doc_generation = enable_doc_generation;
            g->emit_bin = emit_bin;
            g->emit_asm = emit_asm;
            g->emit_llvm_ir = emit_llvm_ir;

            codegen_set_out_name(g, buf_out_name);
            codegen_set_lib_version(g, ver_major, ver_minor, ver_patch);
            g->want_single_threaded = want_single_threaded;
            codegen_set_linker_script(g, linker_script);
            g->version_script_path = version_script; 
            if (each_lib_rpath)
                codegen_set_each_lib_rpath(g, each_lib_rpath);

            codegen_set_clang_argv(g, clang_argv.items, clang_argv.length);

            codegen_set_strip(g, strip);
            g->is_dynamic = is_dynamic;
            g->verbose_tokenize = verbose_tokenize;
            g->verbose_ast = verbose_ast;
            g->verbose_link = verbose_link;
            g->verbose_ir = verbose_ir;
            g->verbose_llvm_ir = verbose_llvm_ir;
            g->verbose_cimport = verbose_cimport;
            g->verbose_cc = verbose_cc;
            g->verbose_llvm_cpu_features = verbose_llvm_cpu_features;
            g->output_dir = output_dir;
            g->disable_gen_h = !emit_h;
            g->bundle_compiler_rt = bundle_compiler_rt;
            codegen_set_errmsg_color(g, color);
            g->system_linker_hack = system_linker_hack;
            g->function_sections = function_sections;
            g->code_model = code_model;
            g->disable_c_depfile = disable_c_depfile;

            g->linker_optimization = linker_optimization;
            g->linker_gc_sections = linker_gc_sections;
            g->linker_allow_shlib_undefined = linker_allow_shlib_undefined;
            g->linker_bind_global_refs_locally = linker_bind_global_refs_locally;
            g->linker_z_nodelete = linker_z_nodelete;
            g->linker_z_defs = linker_z_defs;
            g->stack_size_override = stack_size_override;

            if (override_soname) {
                g->override_soname = buf_create_from_str(override_soname);
            }

            for (size_t i = 0; i < lib_dirs.length; i += 1) {
                codegen_add_lib_dir(g, lib_dirs.at(i));
            }
            for (size_t i = 0; i < framework_dirs.length; i += 1) {
                g->framework_dirs.append(framework_dirs.at(i));
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

            codegen_set_rdynamic(g, rdynamic);

            if (test_filter) {
                codegen_set_test_filter(g, buf_create_from_str(test_filter));
            }
            g->test_is_evented = test_evented_io;

            if (test_name_prefix) {
                codegen_set_test_name_prefix(g, buf_create_from_str(test_name_prefix));
            }

            add_package(g, cur_pkg, g->main_pkg);

            if (cmd == CmdBuild || cmd == CmdRun || cmd == CmdTest) {
                g->c_source_files = c_source_files;
                for (size_t i = 0; i < objects.length; i += 1) {
                    codegen_add_object(g, buf_create_from_str(objects.at(i)));
                }
            }


            if (cmd == CmdBuild || cmd == CmdRun) {
                g->enable_cache = get_cache_opt(enable_cache, cmd == CmdRun);
                codegen_build_and_link(g);
                if (root_progress_node != nullptr) {
                    stage2_progress_end(root_progress_node);
                    root_progress_node = nullptr;
                }
                if (timing_info)
                    codegen_print_timing_report(g, stdout);
                if (stack_report)
                    zig_print_stack_report(g, stdout);

                if (cmd == CmdRun) {
#ifdef ZIG_ENABLE_MEM_PROFILE
                    if (mem::report_print)
                        mem::print_report();
#endif

                    const char *exec_path = buf_ptr(&g->bin_file_output_path);
                    ZigList<const char*> args = {0};

                    args.append(exec_path);
                    if (runtime_args_start != -1) {
                        for (int i = runtime_args_start; i < argc; ++i) {
                            args.append(argv[i]);
                        }
                    }
                    args.append(nullptr);

                    os_execv(exec_path, args.items);

                    args.pop();
                    Termination term;
                    os_spawn_process(args, &term);
                    return term.code;
                } else if (cmd == CmdBuild) {
                    if (emit_bin_override_path != nullptr) {
#if defined(ZIG_OS_WINDOWS)
                        buf_replace(g->output_dir, '/', '\\');
#endif
                        Buf *dest_path = buf_create_from_str(emit_bin_override_path);
                        Buf *source_path;
                        if (only_pp_or_asm) {
                            source_path = buf_alloc();
                            Buf *pp_only_basename = buf_create_from_str(
                                    c_source_files.at(0)->preprocessor_only_basename);
                            os_path_join(g->output_dir, pp_only_basename, source_path);

                        } else {
                            source_path = &g->bin_file_output_path;
                        }
                        if ((err = os_update_file(source_path, dest_path))) {
                            fprintf(stderr, "unable to copy %s to %s: %s\n", buf_ptr(source_path),
                                    buf_ptr(dest_path), err_str(err));
                            return main_exit(root_progress_node, EXIT_FAILURE);
                        }
                    } else if (only_pp_or_asm) {
#if defined(ZIG_OS_WINDOWS)
                        buf_replace(g->c_artifact_dir, '/', '\\');
#endif
                        // dump the preprocessed output to stdout
                        for (size_t i = 0; i < c_source_files.length; i += 1) {
                            Buf *source_path = buf_alloc();
                            Buf *pp_only_basename = buf_create_from_str(
                                    c_source_files.at(i)->preprocessor_only_basename);
                            os_path_join(g->c_artifact_dir, pp_only_basename, source_path);
                            if ((err = os_dump_file(source_path, stdout))) {
                                fprintf(stderr, "unable to read %s: %s\n", buf_ptr(source_path),
                                        err_str(err));
                                return main_exit(root_progress_node, EXIT_FAILURE);
                            }
                        }
                    } else if (g->enable_cache) {
#if defined(ZIG_OS_WINDOWS)
                        buf_replace(&g->bin_file_output_path, '/', '\\');
                        buf_replace(g->output_dir, '/', '\\');
#endif
                        if (final_output_dir_step != nullptr) {
                            Buf *dest_basename = buf_alloc();
                            os_path_split(&g->bin_file_output_path, nullptr, dest_basename);
                            Buf *dest_path = buf_alloc();
                            os_path_join(final_output_dir_step, dest_basename, dest_path);

                            if ((err = os_update_file(&g->bin_file_output_path, dest_path))) {
                                fprintf(stderr, "unable to copy %s to %s: %s\n", buf_ptr(&g->bin_file_output_path),
                                        buf_ptr(dest_path), err_str(err));
                                return main_exit(root_progress_node, EXIT_FAILURE);
                            }
                        } else {
                            if (printf("%s\n", buf_ptr(g->output_dir)) < 0)
                                return main_exit(root_progress_node, EXIT_FAILURE);
                        }
                    }
                    return main_exit(root_progress_node, EXIT_SUCCESS);
                } else {
                    zig_unreachable();
                }
            } else if (cmd == CmdTranslateC) {
                g->enable_cache = get_cache_opt(enable_cache, false);
                codegen_translate_c(g, in_file_buf);
                if (timing_info)
                    codegen_print_timing_report(g, stderr);
                return main_exit(root_progress_node, EXIT_SUCCESS);
            } else if (cmd == CmdTest) {
                ZigTarget native;
                if ((err = target_parse_triple(&native, "native", nullptr, nullptr))) {
                    fprintf(stderr, "Unable to get native target: %s\n", err_str(err));
                    return EXIT_FAILURE;
                }

                g->enable_cache = get_cache_opt(enable_cache, output_dir == nullptr);
                codegen_build_and_link(g);
                if (root_progress_node != nullptr) {
                    stage2_progress_end(root_progress_node);
                    root_progress_node = nullptr;
                }

                if (timing_info) {
                    codegen_print_timing_report(g, stdout);
                }

                if (stack_report) {
                    zig_print_stack_report(g, stdout);
                }

                if (!g->emit_bin) {
                    fprintf(stderr, "Semantic analysis complete. No binary produced due to -fno-emit-bin.\n");
                    return main_exit(root_progress_node, EXIT_SUCCESS);
                }

                Buf *test_exe_path_unresolved = &g->bin_file_output_path;
                Buf *test_exe_path = buf_alloc();
                *test_exe_path = os_path_resolve(&test_exe_path_unresolved, 1);

                if (!g->emit_bin) {
                    fprintf(stderr, "Created %s but skipping execution because no binary generated.\n",
                            buf_ptr(test_exe_path));
                    return main_exit(root_progress_node, EXIT_SUCCESS);
                }

                for (size_t i = 0; i < test_exec_args.length; i += 1) {
                    if (test_exec_args.items[i] == nullptr) {
                        test_exec_args.items[i] = buf_ptr(test_exe_path);
                    }
                }

                if (!target_can_exec(&native, &target) && test_exec_args.length == 0) {
                    fprintf(stderr, "Created %s but skipping execution because it is non-native.\n",
                            buf_ptr(test_exe_path));
                    return main_exit(root_progress_node, EXIT_SUCCESS);
                }

                Termination term;
                if (test_exec_args.length == 0) {
                    test_exec_args.append(buf_ptr(test_exe_path));
                }
                os_spawn_process(test_exec_args, &term);
                if (term.how != TerminationIdClean || term.code != 0) {
                    fprintf(stderr, "\nTests failed. Use the following command to reproduce the failure:\n");
                    fprintf(stderr, "%s\n", buf_ptr(test_exe_path));
                }
                return main_exit(root_progress_node, (term.how == TerminationIdClean) ? term.code : -1);
            } else {
                zig_unreachable();
            }
        }
    case CmdVersion:
        printf("%s\n", ZIG_VERSION_STRING);
        return main_exit(root_progress_node, EXIT_SUCCESS);
    case CmdZen: {
        const char *ptr;
        size_t len;
        stage2_zen(&ptr, &len);
        fwrite(ptr, len, 1, stdout);
        return main_exit(root_progress_node, EXIT_SUCCESS);
    }
    case CmdTargets:
        return stage2_cmd_targets(target_string, mcpu, dynamic_linker);
    case CmdNone:
        return print_full_usage(arg0, stderr, EXIT_FAILURE);
    }
    zig_unreachable();
}

int main(int argc, char **argv) {
    stage2_attach_segfault_handler();
    os_init();
    mem::init();

    auto result = main0(argc, argv);

#ifdef ZIG_ENABLE_MEM_PROFILE
    if (mem::report_print)
        mem::intern_counters.print_report();
#endif
    mem::deinit();
    return result;
}
