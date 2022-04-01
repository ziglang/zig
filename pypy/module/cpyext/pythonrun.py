from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import cpython_api, CANNOT_FAIL
from pypy.module.cpyext.state import State
from pypy.module.cpyext.pyobject import PyObject
from pypy.module.cpyext.pyerrors import PyErr_SetNone

@cpython_api([], rffi.INT_real, error=CANNOT_FAIL)
def Py_IsInitialized(space):
    return 1

@cpython_api([], rffi.CWCHARP, error=CANNOT_FAIL)
def Py_GetProgramName(space):
    """
    Return the program name set with Py_SetProgramName(), or the default.
    The returned string points into static storage; the caller should not modify its
    value."""
    return space.fromcache(State).get_programname()

@cpython_api([], rffi.CCHARP)
def Py_GetVersion(space):
    """Return the version of this Python interpreter.  This is a
    string that looks something like

    "1.5 (\#67, Dec 31 1997, 22:34:28) [GCC 2.7.2.2]"

    The first word (up to the first space character) is the current
    Python version; the first three characters are the major and minor
    version separated by a period.  The returned string points into
    static storage; the caller should not modify its value.  The value
    is available to Python code as sys.version."""
    return space.fromcache(State).get_version()

@cpython_api([lltype.Ptr(lltype.FuncType([], lltype.Void))], rffi.INT_real, error=-1)
def Py_AtExit(space, func_ptr):
    """Register a cleanup function to be called by Py_Finalize().  The cleanup
    function will be called with no arguments and should return no value.  At
    most 32 cleanup functions can be registered.  When the registration is
    successful, Py_AtExit() returns 0; on failure, it returns -1.  The cleanup
    function registered last is called first. Each cleanup function will be
    called at most once.  Since Python's internal finalization will have
    completed before the cleanup function, no Python APIs should be called by
    func."""
    from pypy.module.cpyext.moduledef import Module
    w_module = space.getbuiltinmodule('cpyext')
    module = space.interp_w(Module, w_module)
    try:
        module.register_atexit(func_ptr)
    except ValueError:
        return -1
    return 0

@cpython_api([], PyObject, error=CANNOT_FAIL)
def PyThread_exit_thread(space):
    PyErr_SetNone(space, space.w_SystemExit)
