from pypy.interpreter.error import OperationError
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import CANNOT_FAIL, cpython_api, CONST_STRING
from pypy.module.cpyext.pyobject import PyObject

@cpython_api([CONST_STRING], PyObject, error=CANNOT_FAIL, result_borrowed=True)
def PySys_GetObject(space, name):
    """Return the object name from the sys module or NULL if it does
    not exist, without setting an exception."""
    name = rffi.charp2str(name)
    w_dict = space.sys.getdict(space)
    w_obj = space.finditem_str(w_dict, name)
    return w_obj       # borrowed ref: kept alive in space.sys.w_dict

@cpython_api([CONST_STRING, PyObject], rffi.INT_real, error=-1)
def PySys_SetObject(space, name, w_obj):
    """Set name in the sys module to v unless v is NULL, in which
    case name is deleted from the sys module. Returns 0 on success, -1
    on error."""
    name = rffi.charp2str(name)
    w_dict = space.sys.getdict(space)
    space.setitem_str(w_dict, name, w_obj)
    return 0
