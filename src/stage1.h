/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

// This file deals with exposing stage1 C++ code to stage2 Zig code.

#ifndef ZIG_STAGE1_H
#define ZIG_STAGE1_H

#include "zig_llvm.h"

#include <stddef.h>

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

// ABI warning
enum ErrColor {
    ErrColorAuto,
    ErrColorOff,
    ErrColorOn,
};

// ABI warning
enum CodeModel {
    CodeModelDefault,
    CodeModelTiny,
    CodeModelSmall,
    CodeModelKernel,
    CodeModelMedium,
    CodeModelLarge,
};

// ABI warning
enum TargetSubsystem {
    TargetSubsystemConsole,
    TargetSubsystemWindows,
    TargetSubsystemPosix,
    TargetSubsystemNative,
    TargetSubsystemEfiApplication,
    TargetSubsystemEfiBootServiceDriver,
    TargetSubsystemEfiRom,
    TargetSubsystemEfiRuntimeDriver,

    // This means Zig should infer the subsystem.
    // It's last so that the indexes of other items can line up
    // with the enum in builtin.zig.
    TargetSubsystemAuto
};


// ABI warning
// Synchronize with target.cpp::os_list
enum Os {
    OsFreestanding,
    OsAnanas,
    OsCloudABI,
    OsDragonFly,
    OsFreeBSD,
    OsFuchsia,
    OsIOS,
    OsKFreeBSD,
    OsLinux,
    OsLv2,        // PS3
    OsMacOSX,
    OsNetBSD,
    OsOpenBSD,
    OsSolaris,
    OsWindows,
    OsHaiku,
    OsMinix,
    OsRTEMS,
    OsNaCl,       // Native Client
    OsCNK,        // BG/P Compute-Node Kernel
    OsAIX,
    OsCUDA,       // NVIDIA CUDA
    OsNVCL,       // NVIDIA OpenCL
    OsAMDHSA,     // AMD HSA Runtime
    OsPS4,
    OsELFIAMCU,
    OsTvOS,       // Apple tvOS
    OsWatchOS,    // Apple watchOS
    OsMesa3D,
    OsContiki,
    OsAMDPAL,
    OsHermitCore,
    OsHurd,
    OsWASI,
    OsEmscripten,
    OsUefi,
    OsOther,
};

// ABI warning
struct ZigTarget {
    enum ZigLLVM_ArchType arch;
    enum ZigLLVM_VendorType vendor;

    enum ZigLLVM_EnvironmentType abi;
    Os os;

    bool is_native_os;
    bool is_native_cpu;

    const char *llvm_cpu_name;
    const char *llvm_cpu_features;
    const char *cpu_builtin_str;
    const char *os_builtin_str;
    const char *dynamic_linker;

    const char **llvm_cpu_features_asm_ptr;
    size_t llvm_cpu_features_asm_len;
};

// ABI warning
struct Stage2Progress;
// ABI warning
struct Stage2ProgressNode;

enum BuildMode {
    BuildModeDebug,
    BuildModeFastRelease,
    BuildModeSafeRelease,
    BuildModeSmallRelease,
};


struct ZigStage1Pkg {
    const char *name_ptr;
    size_t name_len;

    const char *path_ptr;
    size_t path_len;

    struct ZigStage1Pkg **children_ptr;
    size_t children_len;

    struct ZigStage1Pkg *parent;
};

// This struct is used by both main.cpp and stage1.zig.
struct ZigStage1 {
    const char *root_name_ptr;
    size_t root_name_len;

    const char *output_dir_ptr;
    size_t output_dir_len;

    const char *builtin_zig_path_ptr;
    size_t builtin_zig_path_len;

    const char *test_filter_ptr;
    size_t test_filter_len;

    const char *test_name_prefix_ptr;
    size_t test_name_prefix_len;

    const char *zig_lib_dir_ptr;
    size_t zig_lib_dir_len;

    const char *zig_std_dir_ptr;
    size_t zig_std_dir_len;

    void *userdata;
    struct ZigStage1Pkg *root_pkg;

    CodeModel code_model;
    TargetSubsystem subsystem;
    ErrColor err_color;

    bool pic;
    bool link_libc;
    bool link_libcpp;
    bool strip;
    bool is_single_threaded;
    bool dll_export_fns;
    bool link_mode_dynamic;
    bool valgrind_enabled;
    bool function_sections;
    bool enable_stack_probing;
    bool enable_time_report;
    bool enable_stack_report;
    bool dump_analysis;
    bool enable_doc_generation;
    bool emit_bin;
    bool emit_asm;
    bool emit_llvm_ir;
    bool test_is_evented;
    bool verbose_tokenize;
    bool verbose_ast;
    bool verbose_ir;
    bool verbose_llvm_ir;
    bool verbose_cimport;
    bool verbose_llvm_cpu_features;
};

ZIG_EXTERN_C void zig_stage1_os_init(void);

ZIG_EXTERN_C struct ZigStage1 *zig_stage1_create(enum BuildMode optimize_mode,
    const char *main_pkg_path_ptr, size_t main_pkg_path_len,
    const char *root_src_path_ptr, size_t root_src_path_len,
    const char *zig_lib_dir_ptr, size_t zig_lib_dir_len,
    const ZigTarget *target, bool is_test_build, Stage2ProgressNode *progress_node);

ZIG_EXTERN_C void zig_stage1_build_object(struct ZigStage1 *);

ZIG_EXTERN_C void zig_stage1_destroy(struct ZigStage1 *);

#endif
