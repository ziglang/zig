#include <Python.h>
#include "hpy.h"

#ifdef HPY_UNIVERSAL_ABI
   // for _h2py and _py2h
#  include "handles.h"
#endif


_HPy_HIDDEN HPy
ctx_Tuple_FromArray(HPyContext *ctx, HPy items[], HPy_ssize_t n)
{
    PyObject *res = PyTuple_New(n);
    if (!res)
        return HPy_NULL;
    for(HPy_ssize_t i=0; i<n; i++) {
        PyObject *item = _h2py(items[i]);
        Py_INCREF(item);
        PyTuple_SET_ITEM(res, i, item);
    }
    return _py2h(res);
}
