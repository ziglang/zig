/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

// This file deals with exposing stage2 Zig code to stage1 C++ code.

#ifndef ZIG_STAGE2_H
#define ZIG_STAGE2_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "stage1.h"

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
// stage2.cpp and src/stage1.zig.

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
ZIG_EXTERN_C ZIG_ATTRIBUTE_NORETURN void stage2_panic(const char *ptr, size_t len);

// ABI warning
ZIG_EXTERN_C struct Stage2Progress *stage2_progress_create(void);
// ABI warning
ZIG_EXTERN_C void stage2_progress_disable_tty(struct Stage2Progress *progress);
// ABI warning
ZIG_EXTERN_C void stage2_progress_destroy(struct Stage2Progress *progress);
// ABI warning
ZIG_EXTERN_C struct Stage2ProgressNode *stage2_progress_start_root(struct Stage2Progress *progress,
        const char *name_ptr, size_t name_len, size_t estimated_total_items);
// ABI warning
ZIG_EXTERN_C struct Stage2ProgressNode *stage2_progress_start(struct Stage2ProgressNode *node,
        const char *name_ptr, size_t name_len, size_t estimated_total_items);
// ABI warning
ZIG_EXTERN_C void stage2_progress_end(struct Stage2ProgressNode *node);
// ABI warning
ZIG_EXTERN_C void stage2_progress_complete_one(struct Stage2ProgressNode *node);
// ABI warning
ZIG_EXTERN_C void stage2_progress_update_node(struct Stage2ProgressNode *node,
        size_t completed_count, size_t estimated_total_items);

// ABI warning
struct Stage2SemVer {
    uint32_t major;
    uint32_t minor;
    uint32_t patch;
};

// ABI warning
ZIG_EXTERN_C const char *stage2_version_string(void);

// ABI warning
ZIG_EXTERN_C Stage2SemVer stage2_version(void);

// ABI warning
ZIG_EXTERN_C enum Error stage2_target_parse(struct ZigTarget *target, const char *zig_triple, const char *mcpu,
        const char *dynamic_linker);

// ABI warning
ZIG_EXTERN_C const char *stage2_fetch_file(struct ZigStage1 *stage1, const char *path_ptr, size_t path_len,
        size_t *result_len);

// ABI warning
ZIG_EXTERN_C Error stage2_cimport(struct ZigStage1 *stage1, const char *c_src_ptr, size_t c_src_len,
        const char **out_zig_path_ptr, size_t *out_zig_path_len,
        struct Stage2ErrorMsg **out_errors_ptr, size_t *out_errors_len);

// ABI warning
ZIG_EXTERN_C const char *stage2_add_link_lib(struct ZigStage1 *stage1,
        const char *lib_name_ptr, size_t lib_name_len,
        const char *symbol_name_ptr, size_t symbol_name_len);

#endif
