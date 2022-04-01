#ifndef HPY_COMMON_RUNTIME_ARGPARSE_H
#define HPY_COMMON_RUNTIME_ARGPARSE_H

#include "hpy.h"

HPyAPI_HELPER int
HPyArg_Parse(HPyContext *ctx, HPyTracker *ht, HPy *args, HPy_ssize_t nargs, const char *fmt, ...);

HPyAPI_HELPER int
HPyArg_ParseKeywords(HPyContext *ctx, HPyTracker *ht, HPy *args, HPy_ssize_t nargs, HPy kw,
                     const char *fmt, const char *keywords[], ...);


#endif /* HPY_COMMON_RUNTIME_ARGPARSE_H */
