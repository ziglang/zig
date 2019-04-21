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
        case ErrorNotDir: return "not a directory";
        case ErrorUnsupportedOperatingSystem: return "unsupported operating system";
        case ErrorSharingViolation: return "sharing violation";
        case ErrorPipeBusy: return "pipe busy";
        case ErrorPrimitiveTypeNotFound: return "primitive type not found";
        case ErrorCacheUnavailable: return "cache unavailable";
        case ErrorPathTooLong: return "path too long";
        case ErrorCCompilerCannotFindFile: return "C compiler cannot find file";
        case ErrorReadingDepFile: return "failed to read .d file";
        case ErrorInvalidDepFile: return "invalid .d file";
        case ErrorMissingArchitecture: return "missing architecture";
        case ErrorMissingOperatingSystem: return "missing operating system";
        case ErrorUnknownArchitecture: return "unrecognized architecture";
        case ErrorUnknownOperatingSystem: return "unrecognized operating system";
        case ErrorUnknownABI: return "unrecognized C ABI";
        case ErrorInvalidFilename: return "invalid filename";
        case ErrorDiskQuota: return "disk space quota exceeded";
        case ErrorDiskSpace: return "out of disk space";
        case ErrorUnexpectedWriteFailure: return "unexpected write failure";
        case ErrorUnexpectedSeekFailure: return "unexpected seek failure";
        case ErrorUnexpectedFileTruncationFailure: return "unexpected file truncation failure";
        case ErrorUnimplemented: return "unimplemented";
        case ErrorOperationAborted: return "operation aborted";
        case ErrorBrokenPipe: return "broken pipe";
        case ErrorNoSpaceLeft: return "no space left";
    }
    return "(invalid error)";
}
