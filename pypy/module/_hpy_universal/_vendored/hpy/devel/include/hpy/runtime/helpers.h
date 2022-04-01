#ifndef HPY_COMMON_RUNTIME_HELPERS_H
#define HPY_COMMON_RUNTIME_HELPERS_H

#include "hpy.h"
#include "hpy/hpytype.h"

HPyAPI_HELPER int
HPyHelpers_AddType(HPyContext *ctx, HPy obj, const char *name,
                  HPyType_Spec *hpyspec, HPyType_SpecParam *params);

#endif /* HPY_COMMON_RUNTIME_HELPERS_H */
