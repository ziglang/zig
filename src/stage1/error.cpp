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
        case ErrorNoCCompilerInstalled: return "no C compiler installed";
        case ErrorNotLazy: return "not lazy";
        case ErrorIsAsync: return "is async";
        case ErrorImportOutsidePkgPath: return "import of file outside package path";
        case ErrorUnknownCpu: return "unknown CPU";
        case ErrorUnknownCpuFeature: return "unknown CPU feature";
        case ErrorInvalidCpuFeatures: return "invalid CPU features";
        case ErrorInvalidLlvmCpuFeaturesFormat: return "invalid LLVM CPU features format";
        case ErrorUnknownApplicationBinaryInterface: return "unknown application binary interface";
        case ErrorASTUnitFailure: return "compiler bug: clang encountered a compile error, but the libclang API does not expose the error. See https://github.com/ziglang/zig/issues/4455 for more details";
        case ErrorBadPathName: return "bad path name";
        case ErrorSymLinkLoop: return "sym link loop";
        case ErrorProcessFdQuotaExceeded: return "process fd quota exceeded";
        case ErrorSystemFdQuotaExceeded: return "system fd quota exceeded";
        case ErrorNoDevice: return "no device";
        case ErrorDeviceBusy: return "device busy";
        case ErrorUnableToSpawnCCompiler: return "unable to spawn system C compiler";
        case ErrorCCompilerExitCode: return "system C compiler exited with failure code";
        case ErrorCCompilerCrashed: return "system C compiler crashed";
        case ErrorCCompilerCannotFindHeaders: return "system C compiler cannot find libc headers";
        case ErrorLibCRuntimeNotFound: return "libc runtime not found";
        case ErrorLibCStdLibHeaderNotFound: return "libc std lib headers not found";
        case ErrorLibCKernel32LibNotFound: return "kernel32 library not found";
        case ErrorUnsupportedArchitecture: return "unsupported architecture";
        case ErrorWindowsSdkNotFound: return "Windows SDK not found";
        case ErrorUnknownDynamicLinkerPath: return "unknown dynamic linker path";
        case ErrorTargetHasNoDynamicLinker: return "target has no dynamic linker";
        case ErrorInvalidAbiVersion: return "invalid C ABI version";
        case ErrorInvalidOperatingSystemVersion: return "invalid operating system version";
        case ErrorUnknownClangOption: return "unknown Clang option";
        case ErrorNestedResponseFile: return "nested response file";
        case ErrorZigIsTheCCompiler: return "Zig was not provided with libc installation information, and so it does not know where the libc paths are on the system. Zig attempted to use the system C compiler to find out where the libc paths are, but discovered that Zig is being used as the system C compiler.";
        case ErrorFileBusy: return "file is busy";
        case ErrorLocked: return "file is locked by another process";
        case ErrorInvalidCharacter: return "invalid character";
        case ErrorUnicodePointTooLarge: return "unicode codepoint too large";
    }
    return "(invalid error)";
}
