from rpython.rlib.nonconst import NonConstant
from rpython.rtyper.lltypesystem import rffi, lltype, ll2ctypes
from rpython.rlib.objectmodel import we_are_translated
from pypy.interpreter.error import OperationError, oefmt, new_exception_class
from pypy.module._hpy_universal.apiset import API
#from pypy.module._hpy_universal.bridge import BRIDGE
from pypy.module._hpy_universal import llapi
from pypy.module._hpy_universal.interp_unicode import _maybe_utf8_to_w
from .state import State

## HPy exceptions in PyPy
## ======================
##
## HPy exceptions are implemented using normal RPython exceptions, which means
## that e.g. HPyErr_SetString simply raises an OperationError: see
## e.g. test_exception_transform.test_llhelper_can_raise for a test which
## ensure that exceptions correctly propagate.
##
## Moreover, we need to ensure that it is NOT possible to call RPython code
## when an RPython exception is set, else you get unexpected results. The plan
## is to document that it's forbidden to call most HPy functions if an
## exception has been set, apart for few functions, such as:
##
##     - HPyErr_Occurred()
##     - HPyErr_Fetch()
##     - HPyErr_Clear()
##
## We need to enforce this in debug mode.
##
## ~~~ Implementation ~~~
##
## HPyErr_SetString, HPyErr_Occurred and HPyErr_Clear are implemented in C. See also:
##    - src/hpyerr.c for the source code
##    - state.py:setup.ctx which explicitly stores the C functions in the ctx


## ~~~ @BRIDGE Functions ~~~
## These functions are called from hpyerr.c, and are used only in tests

@API.func("void HPyErr_SetString(HPyContext *ctx, HPy type, const char *message)")
def HPyErr_SetString(space, handles, ctx, h_exc_type, utf8):
    w_obj = _maybe_utf8_to_w(space, utf8)
    w_exc_type = handles.deref(h_exc_type)
    raise OperationError(w_exc_type, w_obj)

@API.func("void HPyErr_SetObject(HPyContext *ctx, HPy type, HPy value)")
def HPyErr_SetObject(space, handles, ctx, h_exc_type, h_exc_value):
    w_exc_type = handles.deref(h_exc_type)
    w_obj = handles.deref(h_exc_value)
    raise OperationError(w_exc_type, w_obj)

@API.func("int HPyErr_Occurred(HPyContext *ctx)", error_value=API.int(-1))
def HPyErr_Occurred(space, handles, ctx):
    state = space.fromcache(State)
    operror = state.get_exception()
    return API.int(operror is not None)

@API.func("void HPyErr_Clear(HPyContext *ctx)")
def HPyErr_Clear(space, handles, ctx):
    state = space.fromcache(State)
    state.clear_exception()


## ~~~ API Functions ~~~~
## The following are normal @API functions, so they contain the "real"
## implementation.

@API.func("HPy HPyErr_NoMemory(HPyContext *ctx)")
def HPyErr_NoMemory(space, handles, ctx):
    # hack to convince the annotator that this function returns an HPy (i.e.,
    # a Signed)
    if NonConstant(False):
        return -42
    raise OperationError(space.w_MemoryError, space.w_None)

@API.func("HPy HPyErr_NewException(HPyContext *ctx, const char *name, HPy base, HPy dict)")
def HPyErr_NewException(space, handles, ctx, c_name, h_base, h_dict):
    name = rffi.constcharp2str(c_name)
    if '.' not in name:
        raise oefmt(space.w_SystemError,
            "PyErr_NewException: name must be module.class")
    if h_base:
        w_base = handles.deref(h_base)
    else:
        w_base = space.w_Exception
    if h_dict:
        w_dict = handles.deref(h_dict)
    else:
        w_dict = None

    return handles.new(new_exception_class(space, name, w_base, w_dict))

@API.func("HPy HPyErr_NewExceptionWithDoc("
    "HPyContext *ctx, const char *name, const char* doc, HPy base, HPy dict)")
def HPyErr_NewExceptionWithDoc(space, handles, ctx, c_name, c_doc, h_base, h_dict):
    name = rffi.constcharp2str(c_name)
    if '.' not in name:
        raise oefmt(space.w_SystemError,
            "PyErr_NewException: name must be module.class")
    if h_base:
        w_base = handles.deref(h_base)
    else:
        w_base = space.w_Exception
    if h_dict:
        w_dict = handles.deref(h_dict)
    else:
        w_dict = space.newdict()
    if c_doc:
        doc = rffi.constcharp2str(c_doc)
        space.setitem_str(w_dict, "__doc__", space.newtext(doc))

    return handles.new(new_exception_class(space, name, w_base, w_dict))
