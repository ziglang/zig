#include <Python.h>
#include "hpy.h"
#include "hpy/runtime/ctx_funcs.h"

#ifdef HPY_UNIVERSAL_ABI
   // for _h2py and _py2h
#  include "handles.h"
#endif


_HPy_HIDDEN HPy
ctx_Bytes_FromStringAndSize(HPyContext *ctx, const char *v, HPy_ssize_t len)
{
    if (v == NULL) {
        // The CPython API allows passing a null pointer to
        // PyBytes_FromStringAndSize and returns uninitialized memory of the
        // requested size which can then be initialized after the call.
        // In HPy the underlying memory is opaque and so cannot be initialized
        // after the call and so we raise an error instead.
        HPyErr_SetString(ctx, ctx->h_ValueError,
                         "NULL char * passed to HPyBytes_FromStringAndSize");
        return HPy_NULL;
    }
    return _py2h(PyBytes_FromStringAndSize(v, len));
}
