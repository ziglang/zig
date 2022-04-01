// This is for non-CPython implementations!
//
// If you want to bundle the debug mode into your own version of
// hpy.universal, make sure to compile this file and NOT debug_ctx_cpython.c

#include "debug_internal.h"

void debug_ctx_CallRealFunctionFromTrampoline(HPyContext *dctx,
                                              HPyFunc_Signature sig,
                                              void *func, void *args)
{
    HPyContext *uctx = get_info(dctx)->uctx;
    HPy_FatalError(uctx,
                   "Something is very wrong! _HPy_CallRealFunctionFromTrampoline() "
                   "should be used only by the CPython version of hpy.universal");
}
