/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_USERLAND_H
#define ZIG_USERLAND_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

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
// userland.cpp and src-self-hosted/stage1.zig.

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
    ErrorUnknownSubArchitecture,
    ErrorUnknownCpuFeature,
    ErrorInvalidCpuFeatures,
    ErrorInvalidLlvmCpuFeaturesFormat,
    ErrorUnknownApplicationBinaryInterface,
    ErrorASTUnitFailure,
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
struct Stage2CpuFeatures;

// ABI warning
ZIG_EXTERN_C Error stage2_cpu_features_parse(struct Stage2CpuFeatures **result,
        const char *zig_triple, const char *cpu_name, const char *cpu_features);

// ABI warning
ZIG_EXTERN_C const char *stage2_cpu_features_get_llvm_cpu(const struct Stage2CpuFeatures *cpu_features);

// ABI warning
ZIG_EXTERN_C const char *stage2_cpu_features_get_llvm_features(const struct Stage2CpuFeatures *cpu_features);

// ABI warning
ZIG_EXTERN_C void stage2_cpu_features_get_builtin_str(const struct Stage2CpuFeatures *cpu_features,
        const char **ptr, size_t *len);

// ABI warning
ZIG_EXTERN_C void stage2_cpu_features_get_cache_hash(const struct Stage2CpuFeatures *cpu_features,
        const char **ptr, size_t *len);

// ABI warning
ZIG_EXTERN_C int stage2_cmd_targets(const char *zig_triple);


#endif
