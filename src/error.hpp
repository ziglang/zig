/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ERROR_HPP
#define ERROR_HPP

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
    ErrorUnsupportedOperatingSystem,
};

const char *err_str(int err);

#endif
