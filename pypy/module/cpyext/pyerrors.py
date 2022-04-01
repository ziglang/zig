import os

from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.interpreter.error import OperationError, oefmt, strerror as _strerror
from pypy.module.cpyext.api import cpython_api, CANNOT_FAIL, CONST_STRING
from pypy.module.cpyext.api import PyObjectFields, cpython_struct
from pypy.module.cpyext.api import bootstrap_function, slot_function
from pypy.module.cpyext.pyobject import make_typedescr
from pypy.module.exceptions.interp_exceptions import W_RuntimeWarning
from pypy.module.exceptions.interp_exceptions import W_StopIteration
from pypy.module.cpyext.pyobject import (
    PyObject, PyObjectP, make_ref, from_ref, decref, get_w_obj_and_decref)
from pypy.module.cpyext.state import State
from pypy.module.cpyext.import_ import PyImport_Import
from rpython.rlib import rposix, jit

PyStopIterationObjectStruct = lltype.ForwardReference()
PyStopIterationObject = lltype.Ptr(PyStopIterationObjectStruct)
PyStopIterationObjectFields = PyObjectFields + \
    (("value", PyObject), )
cpython_struct("PyStopIterationObject", PyStopIterationObjectFields,
               PyStopIterationObjectStruct)

@bootstrap_function
def init_stopiterationobject(space):
    "Type description of PyStopIterationObject"
    make_typedescr(W_StopIteration.typedef,
                   basestruct=PyStopIterationObject.TO,
                   attach=stopiteration_attach,
                   dealloc=stopiteration_dealloc)

def stopiteration_attach(space, py_obj, w_obj, w_userdata=None):
    py_stopiteration = rffi.cast(PyStopIterationObject, py_obj)
    assert isinstance(w_obj, W_StopIteration)
    # note: assumes that w_value is read-only; changes on one side won't
    # be reflected on the other side
    py_stopiteration.c_value = make_ref(space, w_obj.w_value)

@slot_function([PyObject], lltype.Void)
def stopiteration_dealloc(space, py_obj):
    py_stopiteration = rffi.cast(PyStopIterationObject, py_obj)
    decref(space, py_stopiteration.c_value)
    from pypy.module.cpyext.object import _dealloc
    _dealloc(space, py_obj)


@cpython_api([PyObject, PyObject], lltype.Void)
def PyErr_SetObject(space, w_type, w_value):
    """This function is similar to PyErr_SetString() but lets you specify an
    arbitrary Python object for the "value" of the exception."""
    state = space.fromcache(State)
    operr = OperationError(w_type, w_value)
    operr.record_context(space, space.getexecutioncontext())
    state.set_exception(operr)

@cpython_api([PyObject, CONST_STRING], lltype.Void)
def PyErr_SetString(space, w_type, message_ptr):
    message = rffi.charp2str(message_ptr)
    PyErr_SetObject(space, w_type, space.newtext(message))

@cpython_api([PyObject], lltype.Void, error=CANNOT_FAIL)
def PyErr_SetNone(space, w_type):
    """This is a shorthand for PyErr_SetObject(type, Py_None)."""
    PyErr_SetObject(space, w_type, space.w_None)

if os.name == 'nt':
    # For some reason CPython returns a (PyObject*)NULL
    # This confuses the annotator, so set result_is_ll
    @cpython_api([rffi.INT_real], PyObject, error=CANNOT_FAIL, result_is_ll=True)
    def PyErr_SetFromWindowsErr(space, err):
        PyErr_SetObject(space, space.w_OSError, space.newint(err))
        return rffi.cast(PyObject, 0)

@cpython_api([], PyObject, result_borrowed=True)
def PyErr_Occurred(space):
    state = space.fromcache(State)
    operror = state.get_exception()
    if operror is None:
        return None
    return operror.w_type     # borrowed ref

@cpython_api([], lltype.Void)
def PyErr_Clear(space):
    state = space.fromcache(State)
    state.clear_exception()

@cpython_api([PyObjectP, PyObjectP, PyObjectP], lltype.Void)
def PyErr_Fetch(space, ptype, pvalue, ptraceback):
    """Retrieve the error indicator into three variables whose addresses are passed.
    If the error indicator is not set, set all three variables to NULL.  If it is
    set, it will be cleared and you own a reference to each object retrieved.  The
    value and traceback object may be NULL even when the type object is not.

    This function is normally only used by code that needs to handle exceptions or
    by code that needs to save and restore the error indicator temporarily."""
    state = space.fromcache(State)
    operror = state.clear_exception()
    if operror:
        ptype[0] = make_ref(space, operror.w_type)
        pvalue[0] = make_ref(space, operror.get_w_value(space))
        ptraceback[0] = make_ref(space, operror.get_w_traceback(space))
    else:
        ptype[0] = lltype.nullptr(PyObject.TO)
        pvalue[0] = lltype.nullptr(PyObject.TO)
        ptraceback[0] = lltype.nullptr(PyObject.TO)

@cpython_api([PyObject, PyObject, PyObject], lltype.Void)
def PyErr_Restore(space, py_type, py_value, py_traceback):
    """Set  the error indicator from the three objects.  If the error indicator is
    already set, it is cleared first.  If the objects are NULL, the error
    indicator is cleared.  Do not pass a NULL type and non-NULL value or
    traceback.  The exception type should be a class.  Do not pass an invalid
    exception type or value. (Violating these rules will cause subtle problems
    later.)  This call takes away a reference to each object: you must own a
    reference to each object before the call and after the call you no longer own
    these references.  (If you don't understand this, don't use this function.  I
    warned you.)

    This function is normally only used by code that needs to save and restore the
    error indicator temporarily; use PyErr_Fetch() to save the current
    exception state."""
    state = space.fromcache(State)
    w_type = get_w_obj_and_decref(space, py_type)
    w_value = get_w_obj_and_decref(space, py_value)
    w_traceback = get_w_obj_and_decref(space, py_traceback)

    if w_type is None:
        state.clear_exception()
        return
    state.set_exception(OperationError(w_type, w_value, w_traceback))

@cpython_api([PyObjectP, PyObjectP, PyObjectP], lltype.Void)
def PyErr_NormalizeException(space, exc_p, val_p, tb_p):
    """Under certain circumstances, the values returned by PyErr_Fetch() below
    can be "unnormalized", meaning that *exc is a class object but *val is
    not an instance of the  same class.  This function can be used to instantiate
    the class in that case.  If the values are already normalized, nothing happens.
    The delayed normalization is implemented to improve performance."""
    if exc_p[0]:
        w_etype = from_ref(space, exc_p[0])
    else:
        # There is no exception, so nothing to do
        return
    if val_p[0]:
        w_evalue = from_ref(space, val_p[0])
    else:
        # On CPython, PyErr_SetNone actually sets val to NULL.
        # Sensible code should probably never trigger this path on PyPy, but...
        w_evalue = space.w_None
    operr = OperationError(w_etype, w_evalue)
    operr.normalize_exception(space)
    decref(space, exc_p[0])
    decref(space, val_p[0])
    exc_p[0] = make_ref(space, operr.w_type)
    val_p[0] = make_ref(space, operr.get_w_value(space))

@cpython_api([], rffi.INT_real, error=0)
def PyErr_BadArgument(space):
    """This is a shorthand for PyErr_SetString(PyExc_TypeError, message), where
    message indicates that a built-in operation was invoked with an illegal
    argument.  It is mostly for internal use. In CPython this function always
    raises an exception and returns 0 in all cases, hence the (ab)use of the
    error indicator."""
    raise oefmt(space.w_TypeError, "bad argument type for built-in operation")

@cpython_api([], lltype.Void, error=None)
def PyErr_BadInternalCall(space):
    raise oefmt(space.w_SystemError, "Bad internal call!")

@cpython_api([], PyObject, error=CANNOT_FAIL)
def PyErr_NoMemory(space):
    """This is a shorthand for PyErr_SetNone(PyExc_MemoryError); it returns NULL
    so an object allocation function can write return PyErr_NoMemory(); when it
    runs out of memory.
    Return value: always NULL."""
    PyErr_SetNone(space, space.w_MemoryError)

@cpython_api([PyObject], PyObject)
def PyErr_SetFromErrno(space, w_type):
    """
    This is a convenience function to raise an exception when a C library function
    has returned an error and set the C variable errno.  It constructs a
    tuple object whose first item is the integer errno value and whose
    second item is the corresponding error message (gotten from strerror()),
    and then calls PyErr_SetObject(type, object).  On Unix, when the
    errno value is EINTR, indicating an interrupted system call,
    this calls PyErr_CheckSignals(), and if that set the error indicator,
    leaves it set to that.  The function always returns NULL, so a wrapper
    function around a system call can write return PyErr_SetFromErrno(type);
    when the system call returns an error.
    Return value: always NULL."""
    PyErr_SetFromErrnoWithFilename(space, w_type,
                                   lltype.nullptr(rffi.CCHARP.TO))

@cpython_api([PyObject, CONST_STRING], PyObject)
def PyErr_SetFromErrnoWithFilename(space, w_type, llfilename):
    """Similar to PyErr_SetFromErrno(), with the additional behavior that if
    filename is not NULL, it is passed to the constructor of type as a third
    parameter.  In the case of exceptions such as IOError and OSError,
    this is used to define the filename attribute of the exception instance.
    Return value: always NULL."""
    # XXX Doesn't actually do anything with PyErr_CheckSignals.
    if llfilename:
        filename = rffi.charp2str(llfilename)
        w_filename = space.newfilename(filename)
    else:
        w_filename = space.w_None

    PyErr_SetFromErrnoWithFilenameObject(space, w_type, w_filename)

@cpython_api([PyObject, PyObject], PyObject)
@jit.dont_look_inside       # direct use of _get_errno()
def PyErr_SetFromErrnoWithFilenameObject(space, w_type, w_value):
    """Similar to PyErr_SetFromErrno(), with the additional behavior that if
    w_value is not NULL, it is passed to the constructor of type as a
    third parameter.  In the case of exceptions such as IOError and OSError,
    this is used to define the filename attribute of the exception instance.
    Return value: always NULL."""
    # XXX Doesn't actually do anything with PyErr_CheckSignals.
    errno = rffi.cast(lltype.Signed, rposix._get_errno())
    msg, lgt = _strerror(errno)
    if w_value:
        w_error = space.call_function(w_type,
                                      space.newint(errno),
                                      space.newtext(msg, lgt),
                                      w_value)
    else:
        w_error = space.call_function(w_type,
                                      space.newint(errno),
                                      space.newtext(msg, lgt))
    raise OperationError(w_type, w_error)

@cpython_api([], rffi.INT_real, error=-1)
def PyErr_CheckSignals(space):
    """
    This function interacts with Python's signal handling.  It checks whether a
    signal has been sent to the processes and if so, invokes the corresponding
    signal handler.  If the signal module is supported, this can invoke a
    signal handler written in Python.  In all cases, the default effect for
    SIGINT is to raise the  KeyboardInterrupt exception.  If an
    exception is raised the error indicator is set and the function returns -1;
    otherwise the function returns 0.  The error indicator may or may not be
    cleared if it was previously set."""
    # XXX implement me
    return 0

@cpython_api([PyObject, PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyErr_GivenExceptionMatches(space, w_given, w_exc):
    """Return true if the given exception matches the exception in exc.  If
    exc is a class object, this also returns true when given is an instance
    of a subclass.  If exc is a tuple, all exceptions in the tuple (and
    recursively in subtuples) are searched for a match."""
    if space.isinstance_w(w_given, space.w_BaseException):
        w_given_type = space.type(w_given)
    else:
        w_given_type = w_given
    try:
        return space.exception_match(w_given_type, w_exc)
    except:
        return 0

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyErr_ExceptionMatches(space, w_exc):
    """Equivalent to PyErr_GivenExceptionMatches(PyErr_Occurred(), exc).  This
    should only be called when an exception is actually set; a memory access
    violation will occur if no exception has been raised."""
    w_type = PyErr_Occurred(space)
    return PyErr_GivenExceptionMatches(space, w_type, w_exc)


@cpython_api([PyObject, CONST_STRING, rffi.INT_real], rffi.INT_real, error=-1)
def PyErr_WarnEx(space, w_category, message_ptr, stacklevel):
    """Issue a warning message.  The category argument is a warning category (see
    below) or NULL; the message argument is a message string.  stacklevel is a
    positive number giving a number of stack frames; the warning will be issued from
    the  currently executing line of code in that stack frame.  A stacklevel of 1
    is the function calling PyErr_WarnEx(), 2 is  the function above that,
    and so forth.

    This function normally prints a warning message to sys.stderr; however, it is
    also possible that the user has specified that warnings are to be turned into
    errors, and in that case this will raise an exception.  It is also possible that
    the function raises an exception because of a problem with the warning machinery
    (the implementation imports the warnings module to do the heavy lifting).
    The return value is 0 if no exception is raised, or -1 if an exception
    is raised.  (It is not possible to determine whether a warning message is
    actually printed, nor what the reason is for the exception; this is
    intentional.)  If an exception is raised, the caller should do its normal
    exception handling (for example, Py_DECREF() owned references and return
    an error value).

    Warning categories must be subclasses of Warning; the default warning
    category is RuntimeWarning.  The standard Python warning categories are
    available as global variables whose names are PyExc_ followed by the Python
    exception name. These have the type PyObject*; they are all class
    objects. Their names are PyExc_Warning, PyExc_UserWarning,
    PyExc_UnicodeWarning, PyExc_DeprecationWarning,
    PyExc_SyntaxWarning, PyExc_RuntimeWarning, and
    PyExc_FutureWarning.  PyExc_Warning is a subclass of
    PyExc_Exception; the other warning categories are subclasses of
    PyExc_Warning.

    For information about warning control, see the documentation for the
    warnings module and the -W option in the command line
    documentation.  There is no C API for warning control."""
    if w_category is None:
        w_category = space.w_None
    w_message = space.newtext(rffi.charp2str(message_ptr))
    w_stacklevel = space.newint(rffi.cast(lltype.Signed, stacklevel))

    w_module = PyImport_Import(space, space.newtext("warnings"))
    w_warn = space.getattr(w_module, space.newtext("warn"))
    space.call_function(w_warn, w_message, w_category, w_stacklevel)
    return 0

@cpython_api([PyObject, CONST_STRING], rffi.INT_real, error=-1)
def PyErr_Warn(space, w_category, message):
    """Issue a warning message.  The category argument is a warning category (see
    below) or NULL; the message argument is a message string.  The warning will
    appear to be issued from the function calling PyErr_Warn(), equivalent to
    calling PyErr_WarnEx() with a stacklevel of 1.

    Deprecated; use PyErr_WarnEx() instead."""
    return PyErr_WarnEx(space, w_category, message, 1)

@cpython_api(
    [PyObject, CONST_STRING, CONST_STRING, rffi.INT_real, CONST_STRING, PyObject],
    rffi.INT_real, error=-1)
def PyErr_WarnExplicit(space, w_category, message, filename, lineno, module, w_registry):
    """Issue a warning message with explicit control over all warning attributes.  This
    is a straightforward wrapper around the Python function
    warnings.warn_explicit(), see there for more information.  The module
    and registry arguments may be set to NULL to get the default effect
    described there. message and module are UTF-8 encoded strings,
    filename is decoded from the filesystem encoding
    (sys.getfilesystemencoding())."""
    if w_category is None:
        w_category = space.w_UserWarning
    w_message = space.newtext(rffi.charp2str(message))
    # XXX use fsencode
    w_filename = space.newtext(rffi.charp2str(filename))
    w_lineno = space.newint(rffi.cast(lltype.Signed, lineno))
    if module:
        w_module = space.newtext(rffi.charp2str(module))
    else:
        w_module = space.w_None 
    if w_registry is None:
        w_registry = space.w_None
    w_warnings = PyImport_Import(space, space.newtext("warnings"))
    w_warn = space.getattr(w_warnings, space.newtext("warn_explicit"))
    space.call_function(w_warn, w_message, w_category, w_filename, w_lineno,
                        w_module, w_registry)
    return 0


@cpython_api([rffi.INT_real], lltype.Void)
def PyErr_PrintEx(space, set_sys_last_vars):
    """Print a standard traceback to sys.stderr and clear the error indicator.
    Call this function only when the error indicator is set.  (Otherwise it will
    cause a fatal error!)

    If set_sys_last_vars is nonzero, the variables sys.last_type,
    sys.last_value and sys.last_traceback will be set to the
    type, value and traceback of the printed exception, respectively."""
    if not PyErr_Occurred(space):
        PyErr_BadInternalCall(space)

    operror = space.fromcache(State).clear_exception()
    operror.normalize_exception(space)
    w_type = operror.w_type
    w_value = operror.get_w_value(space)
    w_tb = operror.get_w_traceback(space)

    if rffi.cast(lltype.Signed, set_sys_last_vars):
        space.sys.setdictvalue(space, "last_type", w_type)
        space.sys.setdictvalue(space, "last_value", w_value)
        space.sys.setdictvalue(space, "last_traceback", w_tb)

    space.call_function(space.sys.get("excepthook"),
                        w_type, w_value, w_tb)

@cpython_api([], lltype.Void)
def PyErr_Print(space):
    """Alias for PyErr_PrintEx(1)."""
    PyErr_PrintEx(space, 1)

@cpython_api([PyObject, PyObject, PyObject], lltype.Void)
def PyErr_Display(space, w_type, w_value, tb):
    if tb:
        w_tb = from_ref(space, tb)
    else:
        w_tb = space.w_None
    try:
        space.call_function(space.sys.get("excepthook"),
                            w_type, w_value, w_tb)
    except OperationError:
        # Like CPython: This is wrong, but too many callers rely on
        # this behavior.
        pass

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyTraceBack_Print(space, w_tb, w_file):
    space.call_method(w_file, "write", space.newtext(
        'Traceback (most recent call last):\n'))
    w_traceback = space.call_method(space.builtin, '__import__',
                                    space.newtext("traceback"))
    space.call_method(w_traceback, "print_tb", w_tb, space.w_None, w_file)
    return 0

@cpython_api([PyObject], lltype.Void)
def PyErr_WriteUnraisable(space, where):
    """This utility function prints a warning message to sys.stderr when an
    exception has been set but it is impossible for the interpreter to actually
    raise the exception.  It is used, for example, when an exception occurs in
    an __del__() method.

    The function is called with a single argument obj that identifies the
    context in which the unraisable exception occurred. The repr of obj will be
    printed in the warning message."""

    if not where:
        where = ''
    else:
        where = space.text_w(space.repr(from_ref(space, where)))
    state = space.fromcache(State)
    operror = state.clear_exception()
    if operror:
        operror.write_unraisable(space, where)

@cpython_api([CONST_STRING, PyObject], lltype.Void)
def _PyErr_WriteUnraisableMsg(space, where, w_obj):
    """This utility function prints a warning message to sys.stderr when an
    exception has been set but it is impossible for the interpreter to actually
    raise the exception.  It is used, for example, when an exception occurs in
    an __del__() method.

    The function is called with a single argument obj that identifies the
    context in which the unraisable exception occurred. The repr of obj will be
    printed in the warning message."""

    if not where:
        where = ''
    else:
        where = rffi.charp2str(where)
    state = space.fromcache(State)
    operror = state.clear_exception()
    if operror:
        operror.write_unraisable(space, where, w_object=w_obj, with_traceback=True)

@cpython_api([], lltype.Void)
def PyErr_SetInterrupt(space):
    """This function simulates the effect of a SIGINT signal arriving --- the
    next time PyErr_CheckSignals() is called, KeyboardInterrupt will be raised.
    It may be called without holding the interpreter lock."""
    if space.check_signal_action is not None:
        space.check_signal_action.set_interrupt()
    #else:
    #   no 'signal' module present, ignore...  We can't return an error here

@cpython_api([PyObjectP, PyObjectP, PyObjectP], lltype.Void)
def PyErr_GetExcInfo(space, ptype, pvalue, ptraceback):
    """
    Retrieve the exception info, as known from ``sys.exc_info()``.  This
    refers to an exception that was already caught, not to an exception
    that was freshly raised.  Returns new references for the three
    objects, any of which may be *NULL*.  Does not modify the exception
    info state.

    .. note::

       This function is not normally used by code that wants to handle
       exceptions.  Rather, it can be used when code needs to save and
       restore the exception state temporarily.  Use
       :c:func:`PyErr_SetExcInfo` to restore or clear the exception
       state.
    """
    ec = space.getexecutioncontext()
    operror = ec.sys_exc_info()
    if operror:
        ptype[0] = make_ref(space, operror.w_type)
        pvalue[0] = make_ref(space, operror.get_w_value(space))
        ptraceback[0] = make_ref(space, operror.get_w_traceback(space))
    else:
        ptype[0] = lltype.nullptr(PyObject.TO)
        pvalue[0] = lltype.nullptr(PyObject.TO)
        ptraceback[0] = lltype.nullptr(PyObject.TO)

@cpython_api([PyObject, PyObject, PyObject], lltype.Void)
def PyErr_SetExcInfo(space, py_type, py_value, py_traceback):
    """
    Set the exception info, as known from ``sys.exc_info()``.  This refers
    to an exception that was already caught, not to an exception that was
    freshly raised.  This function steals the references of the arguments.
    To clear the exception state, pass *NULL* for all three arguments.
    For general rules about the three arguments, see :c:func:`PyErr_Restore`.

    .. note::

       This function is not normally used by code that wants to handle
       exceptions.  Rather, it can be used when code needs to save and
       restore the exception state temporarily.  Use
       :c:func:`PyErr_GetExcInfo` to read the exception state.
    """
    w_type = get_w_obj_and_decref(space, py_type)
    w_value = get_w_obj_and_decref(space, py_value)
    w_traceback = get_w_obj_and_decref(space, py_traceback)
    #
    ec = space.getexecutioncontext()
    ec.set_sys_exc_info3(w_type, w_value, w_traceback)

@cpython_api([], rffi.INT_real, error=CANNOT_FAIL)
def PyOS_InterruptOccurred(space):
    return 0;
