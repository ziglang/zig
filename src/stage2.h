/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_STAGE2_H
#define ZIG_STAGE2_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "zig_llvm.h"

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

#if defined(_MSC_VER)
#define ZIG_ATTRIBUTE_NORETURN __declspec(noreturn)
#else
#define ZIG_ATTRIBUTE_NORETURN __attribute__((noreturn))
#endif

// ABI warning: the types and declarations in this file must match both those in
// stage2.cpp and src-self-hosted/stage2.zig.

// ABI warning
enum Error {
    ErrorNone,
    ErrorNoMem,
    ErrorInvalidFormat,
    ErrorSemanticAnalyzeFail,
    ErrorAccess,
    ErrorInterrupted,
    ErrorSystemResources,
    ErrorFileNotFound,
    ErrorFileSystem,
    ErrorFileTooBig,
    ErrorDivByZero,
    ErrorOverflow,
    ErrorPathAlreadyExists,
    ErrorUnexpected,
    ErrorExactDivRemainder,
    ErrorNegativeDenominator,
    ErrorShiftedOutOneBits,
    ErrorCCompileErrors,
    ErrorEndOfFile,
    ErrorIsDir,
    ErrorNotDir,
    ErrorUnsupportedOperatingSystem,
    ErrorSharingViolation,
    ErrorPipeBusy,
    ErrorPrimitiveTypeNotFound,
    ErrorCacheUnavailable,
    ErrorPathTooLong,
    ErrorCCompilerCannotFindFile,
    ErrorNoCCompilerInstalled,
    ErrorReadingDepFile,
    ErrorInvalidDepFile,
    ErrorMissingArchitecture,
    ErrorMissingOperatingSystem,
    ErrorUnknownArchitecture,
    ErrorUnknownOperatingSystem,
    ErrorUnknownABI,
    ErrorInvalidFilename,
    ErrorDiskQuota,
    ErrorDiskSpace,
    ErrorUnexpectedWriteFailure,
    ErrorUnexpectedSeekFailure,
    ErrorUnexpectedFileTruncationFailure,
    ErrorUnimplemented,
    ErrorOperationAborted,
    ErrorBrokenPipe,
    ErrorNoSpaceLeft,
    ErrorNotLazy,
    ErrorIsAsync,
    ErrorImportOutsidePkgPath,
    ErrorUnknownCpu,
    ErrorUnknownCpuFeature,
    ErrorInvalidCpuFeatures,
    ErrorInvalidLlvmCpuFeaturesFormat,
    ErrorUnknownApplicationBinaryInterface,
    ErrorASTUnitFailure,
    ErrorBadPathName,
    ErrorSymLinkLoop,
    ErrorProcessFdQuotaExceeded,
    ErrorSystemFdQuotaExceeded,
    ErrorNoDevice,
    ErrorDeviceBusy,
    ErrorUnableToSpawnCCompiler,
    ErrorCCompilerExitCode,
    ErrorCCompilerCrashed,
    ErrorCCompilerCannotFindHeaders,
    ErrorLibCRuntimeNotFound,
    ErrorLibCStdLibHeaderNotFound,
    ErrorLibCKernel32LibNotFound,
    ErrorUnsupportedArchitecture,
    ErrorWindowsSdkNotFound,
    ErrorUnknownDynamicLinkerPath,
    ErrorTargetHasNoDynamicLinker,
    ErrorInvalidAbiVersion,
    ErrorInvalidOperatingSystemVersion,
    ErrorUnknownClangOption,
    ErrorNestedResponseFile,
    ErrorZigIsTheCCompiler,
    ErrorFileBusy,
    ErrorLocked,
};

// ABI warning
struct Stage2ErrorMsg {
    const char *filename_ptr; // can be null
    size_t filename_len;
    const char *msg_ptr;
    size_t msg_len;
    const char *source; // valid until the ASTUnit is freed. can be null
    unsigned line; // 0 based
    unsigned column; // 0 based
    unsigned offset; // byte offset into source
};

// ABI warning
struct Stage2Ast;

// ABI warning
ZIG_EXTERN_C enum Error stage2_translate_c(struct Stage2Ast **out_ast,
        struct Stage2ErrorMsg **out_errors_ptr, size_t *out_errors_len,
        const char **args_begin, const char **args_end, const char *resources_path);

// ABI warning
ZIG_EXTERN_C void stage2_free_clang_errors(struct Stage2ErrorMsg *ptr, size_t len);

// ABI warning
ZIG_EXTERN_C void stage2_render_ast(struct Stage2Ast *ast, FILE *output_file);

// ABI warning
ZIG_EXTERN_C void stage2_zen(const char **ptr, size_t *len);

// ABI warning
ZIG_EXTERN_C void stage2_attach_segfault_handler(void);

// ABI warning
ZIG_EXTERN_C ZIG_ATTRIBUTE_NORETURN void stage2_panic(const char *ptr, size_t len);

// ABI warning
ZIG_EXTERN_C int stage2_fmt(int argc, char **argv);

// ABI warning
struct stage2_DepTokenizer {
    void *handle;
};

// ABI warning
struct stage2_DepNextResult {
    enum TypeId {
        error,
        null,
        target,
        prereq,
    };

    TypeId type_id;

    // when ent == error --> error text
    // when ent == null --> undefined
    // when ent == target --> target pathname
    // when ent == prereq --> prereq pathname
    const char *textz;
};

// ABI warning
ZIG_EXTERN_C stage2_DepTokenizer stage2_DepTokenizer_init(const char *input, size_t len);

// ABI warning
ZIG_EXTERN_C void stage2_DepTokenizer_deinit(stage2_DepTokenizer *self);

// ABI warning
ZIG_EXTERN_C stage2_DepNextResult stage2_DepTokenizer_next(stage2_DepTokenizer *self);

// ABI warning
struct Stage2Progress;
// ABI warning
struct Stage2ProgressNode;
// ABI warning
ZIG_EXTERN_C Stage2Progress *stage2_progress_create(void);
// ABI warning
ZIG_EXTERN_C void stage2_progress_disable_tty(Stage2Progress *progress);
// ABI warning
ZIG_EXTERN_C void stage2_progress_destroy(Stage2Progress *progress);
// ABI warning
ZIG_EXTERN_C Stage2ProgressNode *stage2_progress_start_root(Stage2Progress *progress,
        const char *name_ptr, size_t name_len, size_t estimated_total_items);
// ABI warning
ZIG_EXTERN_C Stage2ProgressNode *stage2_progress_start(Stage2ProgressNode *node,
        const char *name_ptr, size_t name_len, size_t estimated_total_items);
// ABI warning
ZIG_EXTERN_C void stage2_progress_end(Stage2ProgressNode *node);
// ABI warning
ZIG_EXTERN_C void stage2_progress_complete_one(Stage2ProgressNode *node);
// ABI warning
ZIG_EXTERN_C void stage2_progress_update_node(Stage2ProgressNode *node,
        size_t completed_count, size_t estimated_total_items);

// ABI warning
struct Stage2LibCInstallation {
    const char *include_dir;
    size_t include_dir_len;
    const char *sys_include_dir;
    size_t sys_include_dir_len;
    const char *crt_dir;
    size_t crt_dir_len;
    const char *msvc_lib_dir;
    size_t msvc_lib_dir_len;
    const char *kernel32_lib_dir;
    size_t kernel32_lib_dir_len;
};

// ABI warning
ZIG_EXTERN_C enum Error stage2_libc_parse(struct Stage2LibCInstallation *libc, const char *libc_file);
// ABI warning
ZIG_EXTERN_C enum Error stage2_libc_render(struct Stage2LibCInstallation *self, FILE *file);
// ABI warning
ZIG_EXTERN_C enum Error stage2_libc_find_native(struct Stage2LibCInstallation *libc);

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
struct Stage2SemVer {
    uint32_t major;
    uint32_t minor;
    uint32_t patch;
};

// ABI warning
struct ZigTarget {
    enum ZigLLVM_ArchType arch;
    enum ZigLLVM_VendorType vendor;

    enum ZigLLVM_EnvironmentType abi;
    Os os;

    bool is_native_os;
    bool is_native_cpu;

    // null means default. this is double-purposed to be darwin min version
    struct Stage2SemVer *glibc_or_darwin_version;

    const char *llvm_cpu_name;
    const char *llvm_cpu_features;
    const char *cpu_builtin_str;
    const char *cache_hash;
    size_t cache_hash_len;
    const char *os_builtin_str;
    const char *dynamic_linker;
    const char *standard_dynamic_linker_path;

    const char **llvm_cpu_features_asm_ptr;
    size_t llvm_cpu_features_asm_len;
};

// ABI warning
ZIG_EXTERN_C enum Error stage2_target_parse(struct ZigTarget *target, const char *zig_triple, const char *mcpu,
        const char *dynamic_linker);

// ABI warning
ZIG_EXTERN_C int stage2_cmd_targets(const char *zig_triple, const char *mcpu, const char *dynamic_linker);


// ABI warning
struct Stage2NativePaths {
    const char **include_dirs_ptr;
    size_t include_dirs_len;
    const char **lib_dirs_ptr;
    size_t lib_dirs_len;
    const char **rpaths_ptr;
    size_t rpaths_len;
    const char **warnings_ptr;
    size_t warnings_len;
};
// ABI warning
ZIG_EXTERN_C enum Error stage2_detect_native_paths(struct Stage2NativePaths *native_paths);

// ABI warning
enum Stage2ClangArg {
    Stage2ClangArgTarget,
    Stage2ClangArgO,
    Stage2ClangArgC,
    Stage2ClangArgOther,
    Stage2ClangArgPositional,
    Stage2ClangArgL,
    Stage2ClangArgIgnore,
    Stage2ClangArgDriverPunt,
    Stage2ClangArgPIC,
    Stage2ClangArgNoPIC,
    Stage2ClangArgNoStdLib,
    Stage2ClangArgNoStdLibCpp,
    Stage2ClangArgShared,
    Stage2ClangArgRDynamic,
    Stage2ClangArgWL,
    Stage2ClangArgPreprocessOrAsm,
    Stage2ClangArgOptimize,
    Stage2ClangArgDebug,
    Stage2ClangArgSanitize,
    Stage2ClangArgLinkerScript,
    Stage2ClangArgVerboseCmds,
    Stage2ClangArgForLinker,
    Stage2ClangArgLinkerInputZ,
    Stage2ClangArgLibDir,
    Stage2ClangArgMCpu,
    Stage2ClangArgDepFile,
    Stage2ClangArgFrameworkDir,
    Stage2ClangArgFramework,
    Stage2ClangArgNoStdLibInc,
};

// ABI warning
struct Stage2ClangArgIterator {
    bool has_next;
    enum Stage2ClangArg kind;
    const char *only_arg;
    const char *second_arg;
    const char **other_args_ptr;
    size_t other_args_len;
    const char **argv_ptr;
    size_t argv_len;
    size_t next_index;
    size_t root_args;
};

// ABI warning
ZIG_EXTERN_C void stage2_clang_arg_iterator(struct Stage2ClangArgIterator *it,
        size_t argc, char **argv);

// ABI warning
ZIG_EXTERN_C enum Error stage2_clang_arg_next(struct Stage2ClangArgIterator *it);

// ABI warning
ZIG_EXTERN_C const bool stage2_is_zig0;

#endif
