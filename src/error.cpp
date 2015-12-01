#include "error.hpp"

const char *err_str(int err) {
    switch ((enum Error)err) {
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
    }
    return "(invalid error)";
}
