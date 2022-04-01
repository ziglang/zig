/* =========== CPython-ONLY ===========
   In the following code, we use _py2h and _h2py and we assumed they are the
   ones defined by CPython's version of hpy.universal.

   DO NOT COMPILE THIS FILE UNLESS YOU ARE BUILDING CPython's hpy.universal.

   If you want to compile the debug mode into your own non-CPython version of
   hpy.universal, you should include debug_ctx_not_cpython.c.
   ====================================

   In theory, the debug mode is completely generic and can wrap a generic
   uctx. However, CPython is special because it does not have native support
   for HPy, so uctx contains the logic to call HPy functions from CPython, by
   using _HPy_CallRealFunctionFromTrampoline.

   uctx->ctx_CallRealFunctionFromTrampoline convers PyObject* into UHPy. So
   for the debug mode we need to:

       1. convert the PyObject* args into UHPys.
       2. wrap the UHPys into DHPys.
       3. unwrap the resulting DHPy and convert to PyObject*.
*/

#include <Python.h>
#include "debug_internal.h"
#include "handles.h" // for _py2h and _h2py
#if defined(_MSC_VER)
# include <malloc.h>   /* for alloca() */
#endif

static inline DHPy _py2dh(HPyContext *dctx, PyObject *obj)
{
    return DHPy_open(dctx, _py2h(obj));
}

static inline PyObject *_dh2py(HPyContext *dctx, DHPy dh)
{
    return _h2py(DHPy_unwrap(dctx, dh));
}

static void _buffer_h2py(HPyContext *dctx, const HPy_buffer *src, Py_buffer *dest)
{
    dest->buf = src->buf;
    dest->obj = HPy_AsPyObject(dctx, src->obj);
    dest->len = src->len;
    dest->itemsize = src->itemsize;
    dest->readonly = src->readonly;
    dest->ndim = src->ndim;
    dest->format = src->format;
    dest->shape = src->shape;
    dest->strides = src->strides;
    dest->suboffsets = src->suboffsets;
    dest->internal = src->internal;
}

static void _buffer_py2h(HPyContext *dctx, const Py_buffer *src, HPy_buffer *dest)
{
    dest->buf = src->buf;
    dest->obj = HPy_FromPyObject(dctx, src->obj);
    dest->len = src->len;
    dest->itemsize = src->itemsize;
    dest->readonly = src->readonly;
    dest->ndim = src->ndim;
    dest->format = src->format;
    dest->shape = src->shape;
    dest->strides = src->strides;
    dest->suboffsets = src->suboffsets;
    dest->internal = src->internal;
}

void debug_ctx_CallRealFunctionFromTrampoline(HPyContext *dctx,
                                              HPyFunc_Signature sig,
                                              void *func, void *args)
{
    switch (sig) {
    case HPyFunc_NOARGS: {
        HPyFunc_noargs f = (HPyFunc_noargs)func;
        _HPyFunc_args_NOARGS *a = (_HPyFunc_args_NOARGS*)args;
        DHPy dh_self = _py2dh(dctx, a->self);
        DHPy dh_result = f(dctx, dh_self);
        a->result = _dh2py(dctx, dh_result);
        DHPy_close(dctx, dh_self);
        DHPy_close(dctx, dh_result);
        return;
    }
    case HPyFunc_O: {
        HPyFunc_o f = (HPyFunc_o)func;
        _HPyFunc_args_O *a = (_HPyFunc_args_O*)args;
        DHPy dh_self = _py2dh(dctx, a->self);
        DHPy dh_arg = _py2dh(dctx, a->arg);
        DHPy dh_result = f(dctx, dh_self, dh_arg);
        a->result = _dh2py(dctx, dh_result);
        DHPy_close(dctx, dh_self);
        DHPy_close(dctx, dh_arg);
        DHPy_close(dctx, dh_result);
        return;
    }
    case HPyFunc_VARARGS: {
        HPyFunc_varargs f = (HPyFunc_varargs)func;
        _HPyFunc_args_VARARGS *a = (_HPyFunc_args_VARARGS*)args;
        DHPy dh_self = _py2dh(dctx, a->self);
        Py_ssize_t nargs = PyTuple_GET_SIZE(a->args);
        DHPy *dh_args = (DHPy *)alloca(nargs * sizeof(DHPy));
        for (Py_ssize_t i = 0; i < nargs; i++) {
            dh_args[i] = _py2dh(dctx, PyTuple_GET_ITEM(a->args, i));
        }
        DHPy dh_result = f(dctx, dh_self, dh_args, nargs);
        a->result = _dh2py(dctx, dh_result);
        DHPy_close(dctx, dh_self);
        for (Py_ssize_t i = 0; i < nargs; i++) {
            DHPy_close(dctx, dh_args[i]);
        }
        DHPy_close(dctx, dh_result);
        return;
    }
    case HPyFunc_KEYWORDS: {
        HPyFunc_keywords f = (HPyFunc_keywords)func;
        _HPyFunc_args_KEYWORDS *a = (_HPyFunc_args_KEYWORDS*)args;
        DHPy dh_self = _py2dh(dctx, a->self);
        Py_ssize_t nargs = PyTuple_GET_SIZE(a->args);
        DHPy *dh_args = (DHPy *)alloca(nargs * sizeof(DHPy));
        for (Py_ssize_t i = 0; i < nargs; i++) {
            dh_args[i] = _py2dh(dctx, PyTuple_GET_ITEM(a->args, i));
        }
        DHPy dh_kw = _py2dh(dctx, a->kw);
        DHPy dh_result = f(dctx, dh_self, dh_args, nargs, dh_kw);
        a->result = _dh2py(dctx, dh_result);
        DHPy_close(dctx, dh_self);
        for (Py_ssize_t i = 0; i < nargs; i++) {
            DHPy_close(dctx, dh_args[i]);
        }
        DHPy_close(dctx, dh_kw);
        DHPy_close(dctx, dh_result);
        return;
    }
    case HPyFunc_INITPROC: {
        HPyFunc_initproc f = (HPyFunc_initproc)func;
        _HPyFunc_args_INITPROC *a = (_HPyFunc_args_INITPROC*)args;
        DHPy dh_self = _py2dh(dctx, a->self);
        Py_ssize_t nargs = PyTuple_GET_SIZE(a->args);
        DHPy *dh_args = (DHPy *)alloca(nargs * sizeof(DHPy));
        for (Py_ssize_t i = 0; i < nargs; i++) {
            dh_args[i] = _py2dh(dctx, PyTuple_GET_ITEM(a->args, i));
        }
        DHPy dh_kw = _py2dh(dctx, a->kw);
        a->result = f(dctx, dh_self, dh_args, nargs, dh_kw);
        DHPy_close(dctx, dh_self);
        for (Py_ssize_t i = 0; i < nargs; i++) {
            DHPy_close(dctx, dh_args[i]);
        }
        DHPy_close(dctx, dh_kw);
        return;
    }
    case HPyFunc_GETBUFFERPROC: {
        HPyFunc_getbufferproc f = (HPyFunc_getbufferproc)func;
        _HPyFunc_args_GETBUFFERPROC *a = (_HPyFunc_args_GETBUFFERPROC*)args;
        HPy_buffer hbuf;
        DHPy dh_self = _py2dh(dctx, a->self);
        a->result = f(dctx, dh_self, &hbuf, a->flags);
        DHPy_close(dctx, dh_self);
        if (a->result < 0) {
            a->view->obj = NULL;
            return;
        }
        _buffer_h2py(dctx, &hbuf, a->view);
        HPy_Close(dctx, hbuf.obj);
        return;
    }
    case HPyFunc_RELEASEBUFFERPROC: {
        HPyFunc_releasebufferproc f = (HPyFunc_releasebufferproc)func;
        _HPyFunc_args_RELEASEBUFFERPROC *a = (_HPyFunc_args_RELEASEBUFFERPROC*)args;
        HPy_buffer hbuf;
        _buffer_py2h(dctx, a->view, &hbuf);
        DHPy dh_self = _py2dh(dctx, a->self);
        f(dctx, dh_self, &hbuf);
        DHPy_close(dctx, dh_self);
        // XXX: copy back from hbuf?
        HPy_Close(dctx, hbuf.obj);
        return;
    }
#include "autogen_debug_ctx_call.i"
    default:
        abort();  // XXX
    }
}
