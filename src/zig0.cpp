/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

// This file is the entry point for zig0, which is *only* used to build
// stage2, the self-hosted compiler, into an object file, which is then
// linked by the same build system (cmake) that linked this binary.

#include "stage1.h"
#include "heap.hpp"
#include "stage2.h"
#include "target.hpp"
#include "error.hpp"

#include <stdio.h>
#include <string.h>

static int print_error_usage(const char *arg0) {
    fprintf(stderr, "See `%s --help` for detailed usage information\n", arg0);
    return EXIT_FAILURE;
}

static int print_full_usage(const char *arg0, FILE *file, int return_code) {
    fprintf(file,
        "Usage: %s [options]            builds an object file\n"
        "\n"
        "Options:\n"
        "  --color [auto|off|on]        enable or disable colored error messages\n"
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
        "  -mcpu [cpu]                  specify target CPU and feature set\n"
        "  --verbose-tokenize           enable compiler debug output for tokenization\n"
        "  --verbose-ast                enable compiler debug output for AST parsing\n"
        "  --verbose-ir                 enable compiler debug output for Zig IR\n"
        "  --verbose-llvm-ir            enable compiler debug output for LLVM IR\n"
        "  --verbose-cimport            enable compiler debug output for C imports\n"
        "  --verbose-llvm-cpu-features  enable compiler debug output for LLVM CPU features\n"
        "\n"
    , arg0);
    return return_code;
}

static bool str_starts_with(const char *s1, const char *s2) {
    size_t s2_len = strlen(s2);
    if (strlen(s1) < s2_len) {
        return false;
    }
    return memcmp(s1, s2, s2_len) == 0;
}

int main_exit(Stage2ProgressNode *root_progress_node, int exit_code) {
    if (root_progress_node != nullptr) {
        stage2_progress_end(root_progress_node);
    }
    return exit_code;
}

int main(int argc, char **argv) {
    zig_stage1_os_init();

    char *arg0 = argv[0];
    Error err;

    const char *in_file = nullptr;
    const char *output_dir = nullptr;
    bool strip = false;
    const char *out_name = nullptr;
    bool verbose_tokenize = false;
    bool verbose_ast = false;
    bool verbose_ir = false;
    bool verbose_llvm_ir = false;
    bool verbose_cimport = false;
    bool verbose_llvm_cpu_features = false;
    ErrColor color = ErrColorAuto;
    const char *dynamic_linker = nullptr;
    bool link_libc = false;
    bool link_libcpp = false;
    const char *target_string = nullptr;
    ZigStage1Pkg *cur_pkg = heap::c_allocator.create<ZigStage1Pkg>();
    BuildMode build_mode = BuildModeDebug;
    TargetSubsystem subsystem = TargetSubsystemAuto;
    const char *override_lib_dir = nullptr;
    const char *main_pkg_path = nullptr;
    const char *mcpu = nullptr;

    for (int i = 1; i < argc; i += 1) {
        char *arg = argv[i];

        if (arg[0] == '-') {
            if (strcmp(arg, "--") == 0) {
                fprintf(stderr, "Unexpected end-of-parameter mark: %s\n", arg);
            } else if (strcmp(arg, "--release-fast") == 0) {
                build_mode = BuildModeFastRelease;
            } else if (strcmp(arg, "--release-safe") == 0) {
                build_mode = BuildModeSafeRelease;
            } else if (strcmp(arg, "--release-small") == 0) {
                build_mode = BuildModeSmallRelease;
            } else if (strcmp(arg, "--help") == 0) {
                return print_full_usage(arg0, stdout, EXIT_SUCCESS);
            } else if (strcmp(arg, "--strip") == 0) {
                strip = true;
            } else if (strcmp(arg, "--verbose-tokenize") == 0) {
                verbose_tokenize = true;
            } else if (strcmp(arg, "--verbose-ast") == 0) {
                verbose_ast = true;
            } else if (strcmp(arg, "--verbose-ir") == 0) {
                verbose_ir = true;
            } else if (strcmp(arg, "--verbose-llvm-ir") == 0) {
                verbose_llvm_ir = true;
            } else if (strcmp(arg, "--verbose-cimport") == 0) {
                verbose_cimport = true;
            } else if (strcmp(arg, "--verbose-llvm-cpu-features") == 0) {
                verbose_llvm_cpu_features = true;
            } else if (arg[1] == 'l' && arg[2] != 0) {
                // alias for --library
                const char *l = &arg[2];
                if (strcmp(l, "c") == 0) {
                    link_libc = true;
                } else if (strcmp(l, "c++") == 0 || strcmp(l, "stdc++") == 0) {
                    link_libcpp = true;
                }
            } else if (strcmp(arg, "--pkg-begin") == 0) {
                if (i + 2 >= argc) {
                    fprintf(stderr, "Expected 2 arguments after --pkg-begin\n");
                    return print_error_usage(arg0);
                }
                ZigStage1Pkg *new_cur_pkg = heap::c_allocator.create<ZigStage1Pkg>();
                i += 1;
                new_cur_pkg->name_ptr = argv[i];
                new_cur_pkg->name_len = strlen(argv[i]);
                i += 1;
                new_cur_pkg->path_ptr = argv[i];
                new_cur_pkg->path_len = strlen(argv[i]);
                new_cur_pkg->parent = cur_pkg;
                cur_pkg->children_ptr = heap::c_allocator.reallocate<ZigStage1Pkg *>(cur_pkg->children_ptr,
                        cur_pkg->children_len, cur_pkg->children_len + 1);
                cur_pkg->children_ptr[cur_pkg->children_len] = new_cur_pkg;
                cur_pkg->children_len += 1;

                cur_pkg = new_cur_pkg;
            } else if (strcmp(arg, "--pkg-end") == 0) {
                if (cur_pkg->parent == nullptr) {
                    fprintf(stderr, "Encountered --pkg-end with no matching --pkg-begin\n");
                    return EXIT_FAILURE;
                }
                cur_pkg = cur_pkg->parent;
            } else if (str_starts_with(arg, "-mcpu=")) {
                mcpu = arg + strlen("-mcpu=");
            } else if (i + 1 >= argc) {
                fprintf(stderr, "Expected another argument after %s\n", arg);
                return print_error_usage(arg0);
            } else {
                i += 1;
                if (strcmp(arg, "--output-dir") == 0) {
                    output_dir = argv[i];
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
                } else if (strcmp(arg, "--name") == 0) {
                    out_name = argv[i];
                } else if (strcmp(arg, "--dynamic-linker") == 0) {
                    dynamic_linker = argv[i];
                } else if (strcmp(arg, "--override-lib-dir") == 0) {
                    override_lib_dir = argv[i];
                } else if (strcmp(arg, "--main-pkg-path") == 0) {
                    main_pkg_path = argv[i];
                } else if (strcmp(arg, "--library") == 0 || strcmp(arg, "-l") == 0) {
                    if (strcmp(argv[i], "c") == 0) {
                        link_libc = true;
                    } else if (strcmp(argv[i], "c++") == 0 || strcmp(argv[i], "stdc++") == 0) {
                        link_libcpp = true;
                    }
                } else if (strcmp(arg, "-target") == 0) {
                    target_string = argv[i];
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
        } else if (!in_file) {
            in_file = arg;
        } else {
            fprintf(stderr, "Unexpected extra parameter: %s\n", arg);
            return print_error_usage(arg0);
        }
    }

    if (cur_pkg->parent != nullptr) {
        fprintf(stderr, "Unmatched --pkg-begin\n");
        return EXIT_FAILURE;
    }

    Stage2Progress *progress = stage2_progress_create();
    Stage2ProgressNode *root_progress_node = stage2_progress_start_root(progress, "", 0, 0);
    if (color == ErrColorOff) stage2_progress_disable_tty(progress);

    ZigTarget target;
    if ((err = target_parse_triple(&target, target_string, mcpu, dynamic_linker))) {
        fprintf(stderr, "invalid target: %s\n", err_str(err));
        return print_error_usage(arg0);
    }

    if (in_file == nullptr) {
        fprintf(stderr, "missing zig file\n");
        return print_error_usage(arg0);
    }

    if (out_name == nullptr) {
        fprintf(stderr, "missing --name\n");
        return print_error_usage(arg0);
    }

    ZigStage1 *stage1 = zig_stage1_create(build_mode,
        main_pkg_path, (main_pkg_path == nullptr) ? 0 : strlen(main_pkg_path),
        in_file, strlen(in_file),
        override_lib_dir, strlen(override_lib_dir), &target, false,
        root_progress_node);

    stage1->root_name_ptr = out_name;
    stage1->root_name_len = strlen(out_name);
    stage1->strip = strip;
    stage1->verbose_tokenize = verbose_tokenize;
    stage1->verbose_ast = verbose_ast;
    stage1->verbose_ir = verbose_ir;
    stage1->verbose_llvm_ir = verbose_llvm_ir;
    stage1->verbose_cimport = verbose_cimport;
    stage1->verbose_llvm_cpu_features = verbose_llvm_cpu_features;
    stage1->output_dir_ptr = output_dir;
    stage1->output_dir_len = strlen(output_dir);
    stage1->root_pkg = cur_pkg;
    stage1->err_color = color;
    stage1->link_libc = link_libc;
    stage1->link_libcpp = link_libcpp;
    stage1->subsystem = subsystem;
    stage1->pic = true;
    stage1->emit_bin = true;

    zig_stage1_build_object(stage1);

    zig_stage1_destroy(stage1);

    return main_exit(root_progress_node, EXIT_SUCCESS);
}
