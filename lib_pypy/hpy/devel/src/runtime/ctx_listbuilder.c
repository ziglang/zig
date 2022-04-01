#include <stddef.h>
#include <Python.h>
#include "hpy.h"

#ifdef HPY_UNIVERSAL_ABI
   // for _h2py and _py2h
#  include "handles.h"
#endif


_HPy_HIDDEN HPyListBuilder
ctx_ListBuilder_New(HPyContext *ctx, HPy_ssize_t initial_size)
{
    PyObject *lst = PyList_New(initial_size);
    if (lst == NULL)
        PyErr_Clear();   /* delay the MemoryError */
    return (HPyListBuilder){(HPy_ssize_t)lst};
}

_HPy_HIDDEN void
ctx_ListBuilder_Set(HPyContext *ctx, HPyListBuilder builder,
                    HPy_ssize_t index, HPy h_item)
{
    PyObject *lst = (PyObject *)builder._lst;
    if (lst != NULL) {
        PyObject *item = _h2py(h_item);
        assert(index >= 0 && index < PyList_GET_SIZE(lst));
        assert(PyList_GET_ITEM(lst, index) == NULL);
        Py_INCREF(item);
        PyList_SET_ITEM(lst, index, item);
    }
}

_HPy_HIDDEN HPy
ctx_ListBuilder_Build(HPyContext *ctx, HPyListBuilder builder)
{
    PyObject *lst = (PyObject *)builder._lst;
    if (lst == NULL) {
        PyErr_NoMemory();
        return HPy_NULL;
    }
    builder._lst = 0;
    return _py2h(lst);
}

_HPy_HIDDEN void
ctx_ListBuilder_Cancel(HPyContext *ctx, HPyListBuilder builder)
{
    PyObject *lst = (PyObject *)builder._lst;
    if (lst == NULL) {
        // we don't report the memory error here: the builder
        // is being cancelled (so the result of the builder is not being used)
        // and likely it's being cancelled during the handling of another error
        return;
    }
    builder._lst = 0;
    Py_XDECREF(lst);
}
