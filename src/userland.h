/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_USERLAND_H
#define ZIG_USERLAND_H

#include <stddef.h>
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
};

// ABI warning
enum Stage2TranslateMode {
    Stage2TranslateModeImport,
    Stage2TranslateModeTranslate,
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
        const char **args_begin, const char **args_end, enum Stage2TranslateMode mode,
        const char *resources_path);

// ABI warning
ZIG_EXTERN_C void stage2_free_clang_errors(struct Stage2ErrorMsg *ptr, size_t len);

// ABI warning
ZIG_EXTERN_C void stage2_render_ast(struct Stage2Ast *ast, FILE *output_file);

// ABI warning
ZIG_EXTERN_C void stage2_zen(const char **ptr, size_t *len);

// ABI warning
ZIG_EXTERN_C ZIG_ATTRIBUTE_NORETURN void stage2_panic(const char *ptr, size_t len);

#endif
