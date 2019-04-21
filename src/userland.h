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
#define ZIG_USERLAND_EXTERN_C extern "C"
#else
#define ZIG_USERLAND_EXTERN_C
#endif

#if defined(_MSC_VER)
#define ZIG_USERLAND_ATTRIBUTE_NORETURN __declspec(noreturn)
#else
#define ZIG_USERLAND_ATTRIBUTE_NORETURN __attribute__((noreturn))
#endif

// The types and declarations in this file must match both those in userland.cpp and
// src-self-hosted/stage1.zig.

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

enum Stage2TranslateMode {
    Stage2TranslateModeImport,
    Stage2TranslateModeTranslate,
};

struct Stage2Ast;

ZIG_USERLAND_EXTERN_C Error stage2_translate_c(struct Stage2Ast **out_ast,
        const char **args_begin, const char **args_end, enum Stage2TranslateMode mode);

ZIG_USERLAND_EXTERN_C void stage2_render_ast(struct Stage2Ast *ast, FILE *output_file);

ZIG_USERLAND_EXTERN_C void stage2_zen(const char **ptr, size_t *len);

ZIG_USERLAND_EXTERN_C ZIG_USERLAND_ATTRIBUTE_NORETURN void stage2_panic(const char *ptr, size_t len);

#endif
