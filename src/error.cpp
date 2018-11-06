/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "error.hpp"

const char *err_str(Error err) {
    switch (err) {
        case ErrorNone: return "(no error)";
        case ErrorNoMem: return "out of memory";
        case ErrorInvalidFormat: return "invalid format";
        case ErrorSemanticAnalyzeFail: return "semantic analyze failed";
        case ErrorAccess: return "access denied";
        case ErrorInterrupted: return "interrupted";
        case ErrorSystemResources: return "lack of system resources";
        case ErrorFileNotFound: return "file not found";
        case ErrorFileSystem: return "file system error";
        case ErrorFileTooBig: return "file too big";
        case ErrorDivByZero: return "division by zero";
        case ErrorOverflow: return "overflow";
        case ErrorPathAlreadyExists: return "path already exists";
        case ErrorUnexpected: return "unexpected error";
        case ErrorExactDivRemainder: return "exact division had a remainder";
        case ErrorNegativeDenominator: return "negative denominator";
        case ErrorShiftedOutOneBits: return "exact shift shifted out one bits";
        case ErrorCCompileErrors: return "C compile errors";
        case ErrorEndOfFile: return "end of file";
        case ErrorIsDir: return "is directory";
        case ErrorUnsupportedOperatingSystem: return "unsupported operating system";
        case ErrorSharingViolation: return "sharing violation";
        case ErrorPipeBusy: return "pipe busy";
        case ErrorPrimitiveTypeNotFound: return "primitive type not found";
    }
    return "(invalid error)";
}
