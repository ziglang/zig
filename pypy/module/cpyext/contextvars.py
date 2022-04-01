# Implement the PyContextVar* functions in terms of the pure-python
# _contextvars module

from pypy.module.cpyext.api import (cpython_api, PyObject, PyObjectP,
    CONST_STRING)
from pypy.module.cpyext.pyobject import make_ref, from_ref
from rpython.rtyper.lltypesystem import rffi
from pypy.module.cpyext.pyobject import incref
from pypy.interpreter.error import OperationError

@cpython_api([CONST_STRING, PyObject], PyObject)
def PyContextVar_New(space, name, default):
    if name:
        w_str = space.newbytes(rffi.charp2str(name))
        w_name = space.call_method(w_str, 'decode', space.newtext("utf-8"))
    else:
        w_name = space.newtext('')
    if default:
        w_def = from_ref(space, default)
        return space.appexec([w_name, w_def], """(name, default):
            from _contextvars import ContextVar
            return ContextVar(name, default=default)
            """)
    else:
        return space.appexec([w_name], """(name,):
            from _contextvars import ContextVar
            return ContextVar(name)
            """)

@cpython_api([PyObject, PyObject], PyObject)
def PyContextVar_Set(space, w_ovar, w_val):
    return space.appexec([w_ovar, w_val], """(ovar, val):
        from _contextvars import ContextVar
        if not isinstance(ovar, ContextVar):
            raise TypeError('an instance of ContextVar was expected') 
        return ovar.set(val)
        """)

@cpython_api([PyObject, PyObject, PyObjectP], rffi.INT_real, error=-1)
def PyContextVar_Get(space, w_ovar, default, val):
    if default:
        w_def = from_ref(space, default)
        w_ret = space.appexec([w_ovar, w_def], """(ovar, default):
            from _contextvars import ContextVar
            if not isinstance(ovar, ContextVar):
                raise TypeError('an instance of ContextVar was expected') 
            return ovar.get(default)
        """)
    else:
        try:
            w_ret = space.appexec([w_ovar], """(ovar,):
                from _contextvars import ContextVar
                if not isinstance(ovar, ContextVar):
                    raise TypeError('an instance of ContextVar was expected') 
                return ovar.get()
            """)
        except OperationError as e:
            if e.match(space, space.w_LookupError):
                val[0] = rffi.cast(PyObject, 0)
                return 0
            raise e
    val[0] = make_ref(space, w_ret)
    return 0
