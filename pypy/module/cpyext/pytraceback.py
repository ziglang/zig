from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import (
    PyObjectFields, generic_cpy_call, CONST_STRING, CANNOT_FAIL, Py_ssize_t,
    cpython_api, bootstrap_function, cpython_struct, 
    slot_function)
from pypy.module.cpyext.pyobject import (
    PyObject, make_ref, from_ref, decref, make_typedescr)
from pypy.module.cpyext.frameobject import PyFrameObject
from pypy.interpreter.error import OperationError
from pypy.interpreter.pytraceback import PyTraceback
from pypy.interpreter import pycode


PyTracebackObjectStruct = lltype.ForwardReference()
PyTracebackObject = lltype.Ptr(PyTracebackObjectStruct)
PyTracebackObjectFields = PyObjectFields + (
    ("tb_next", PyTracebackObject),
    ("tb_frame", PyFrameObject),
    ("tb_lasti", rffi.INT),
    ("tb_lineno", rffi.INT),
)
cpython_struct("PyTracebackObject", PyTracebackObjectFields, PyTracebackObjectStruct)

@bootstrap_function
def init_traceback(space):
    make_typedescr(PyTraceback.typedef,
                   basestruct=PyTracebackObject.TO,
                   attach=traceback_attach,
                   dealloc=traceback_dealloc)


def traceback_attach(space, py_obj, w_obj, w_userdata=None):
    py_traceback = rffi.cast(PyTracebackObject, py_obj)
    traceback = space.interp_w(PyTraceback, w_obj)
    if traceback.next is None:
        w_next_traceback = None
    else:
        w_next_traceback = traceback.next
    py_traceback.c_tb_next = rffi.cast(PyTracebackObject, make_ref(space, w_next_traceback))
    py_traceback.c_tb_frame = rffi.cast(PyFrameObject, make_ref(space, traceback.frame))
    rffi.setintfield(py_traceback, 'c_tb_lasti', traceback.lasti)
    rffi.setintfield(py_traceback, 'c_tb_lineno',traceback.get_lineno())

@slot_function([PyObject], lltype.Void)
def traceback_dealloc(space, py_obj):
    py_traceback = rffi.cast(PyTracebackObject, py_obj)
    decref(space, rffi.cast(PyObject, py_traceback.c_tb_next))
    decref(space, rffi.cast(PyObject, py_traceback.c_tb_frame))
    from pypy.module.cpyext.object import _dealloc
    _dealloc(space, py_obj)
