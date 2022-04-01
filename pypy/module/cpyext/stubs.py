#----this file is not imported, only here for reference----

#from pypy.module.cpyext.api import (
#    cpython_api, PyObject, PyObjectP, CANNOT_FAIL
#    )
#from pypy.module.cpyext.complexobject import Py_complex_ptr as Py_complex
#from rpython.rtyper.lltypesystem import rffi, lltype


@cpython_api([rffi.CCHARP], Py_ssize_t, error=-1)
def PyBuffer_SizeFromFormat(space, format):
    """Return the implied itemsize from the struct-stype
    format."""
    raise NotImplementedError

@cpython_api([rffi.INT_real, Py_ssize_t, Py_ssize_t, Py_ssize_t, lltype.Char], lltype.Void)
def PyBuffer_FillContiguousStrides(space, ndim, shape, strides, itemsize, fortran):
    """Fill the strides array with byte-strides of a contiguous (C-style if
    fortran is 'C' or Fortran-style if fortran is 'F') array of the
    given shape with the given number of bytes per element."""
    raise NotImplementedError

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyCell_Check(space, ob):
    """Return true if ob is a cell object; ob must not be NULL."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCell_New(space, ob):
    """Create and return a new cell object containing the value ob. The parameter may
    be NULL."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCell_Get(space, cell):
    """Return the contents of the cell cell."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCell_GET(space, cell):
    """Return the contents of the cell cell, but without checking that cell is
    non-NULL and a cell object."""
    raise NotImplementedError
    borrow_from()

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyCell_Set(space, cell, value):
    """Set the contents of the cell object cell to value.  This releases the
    reference to any current content of the cell. value may be NULL.  cell
    must be non-NULL; if it is not a cell object, -1 will be returned.  On
    success, 0 will be returned."""
    raise NotImplementedError

@cpython_api([PyObject, PyObject], lltype.Void)
def PyCell_SET(space, cell, value):
    """Sets the value of the cell object cell to value.  No reference counts are
    adjusted, and no checks are made for safety; cell must be non-NULL and must
    be a cell object."""
    raise NotImplementedError

@cpython_api([PyObject], rffi.INT_real, error=-1)
def PyCodec_Register(space, search_function):
    """Register a new codec search function.

    As side effect, this tries to load the encodings package, if not yet
    done, to make sure that it is always first in the list of search functions."""
    raise NotImplementedError


@cpython_api([rffi.CCHARP], rffi.INT_real, error=-1)
def PyCodec_KnownEncoding(space, encoding):
    """Return 1 or 0 depending on whether there is a registered codec for
    the given encoding."""
    raise NotImplementedError


@cpython_api([rffi.CCHARP, PyObject, rffi.CCHARP], PyObject)
def PyCodec_StreamReader(space, encoding, stream, errors):
    """Get a StreamReader factory function for the given encoding."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, PyObject, rffi.CCHARP], PyObject)
def PyCodec_StreamWriter(space, encoding, stream, errors):
    """Get a StreamWriter factory function for the given encoding."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, PyObject], rffi.INT_real, error=-1)
def PyCodec_RegisterError(space, name, error):
    """Register the error handling callback function error under the given name.
    This callback function will be called by a codec when it encounters
    unencodable characters/undecodable bytes and name is specified as the error
    parameter in the call to the encode/decode function.

    The callback gets a single argument, an instance of
    UnicodeEncodeError, UnicodeDecodeError or
    UnicodeTranslateError that holds information about the problematic
    sequence of characters or bytes and their offset in the original string (see
    unicodeexceptions for functions to extract this information).  The
    callback must either raise the given exception, or return a two-item tuple
    containing the replacement for the problematic sequence, and an integer
    giving the offset in the original string at which encoding/decoding should be
    resumed.

    Return 0 on success, -1 on error."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP], PyObject)
def PyCodec_LookupError(space, name):
    """Lookup the error handling callback function registered under name.  As a
    special case NULL can be passed, in which case the error handling callback
    for "strict" will be returned."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCodec_StrictErrors(space, exc):
    """Raise exc as an exception."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCodec_IgnoreErrors(space, exc):
    """Ignore the unicode error, skipping the faulty input."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCodec_ReplaceErrors(space, exc):
    """Replace the unicode encode error with ? or U+FFFD."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCodec_XMLCharRefReplaceErrors(space, exc):
    """Replace the unicode encode error with XML character references."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyCodec_BackslashReplaceErrors(space, exc):
    r"""Replace the unicode encode error with backslash escapes (\x, \u and
    \U)."""
    raise NotImplementedError

@cpython_api([Py_complex, Py_complex], Py_complex)
def _Py_c_sum(space, left, right):
    """Return the sum of two complex numbers, using the C Py_complex
    representation."""
    raise NotImplementedError

@cpython_api([Py_complex, Py_complex], Py_complex)
def _Py_c_diff(space, left, right):
    """Return the difference between two complex numbers, using the C
    Py_complex representation."""
    raise NotImplementedError

@cpython_api([Py_complex], Py_complex)
def _Py_c_neg(space, complex):
    """Return the negation of the complex number complex, using the C
    Py_complex representation."""
    raise NotImplementedError

@cpython_api([Py_complex, Py_complex], Py_complex)
def _Py_c_prod(space, left, right):
    """Return the product of two complex numbers, using the C Py_complex
    representation."""
    raise NotImplementedError

@cpython_api([Py_complex, Py_complex], Py_complex)
def _Py_c_quot(space, dividend, divisor):
    """Return the quotient of two complex numbers, using the C Py_complex
    representation.

    If divisor is null, this method returns zero and sets
    errno to EDOM."""
    raise NotImplementedError

@cpython_api([Py_complex, Py_complex], Py_complex)
def _Py_c_pow(space, num, exp):
    """Return the exponentiation of num by exp, using the C Py_complex
    representation.

    If num is null and exp is not a positive real number,
    this method returns zero and sets errno to EDOM."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.CCHARP], rffi.CCHARP)
def PyOS_stricmp(space, s1, s2):
    """Case insensitive comparison of strings. The function works almost
    identically to strcmp() except that it ignores the case.
    """
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.CCHARP, Py_ssize_t], rffi.CCHARP)
def PyOS_strnicmp(space, s1, s2, size):
    """Case insensitive comparison of strings. The function works almost
    identically to strncmp() except that it ignores the case.
    """
    raise NotImplementedError

@cpython_api([PyTypeObjectPtr, PyMemberDef], PyObject)
def PyDescr_NewMember(space, type, meth):
    raise NotImplementedError

@cpython_api([PyTypeObjectPtr, wrapperbase, rffi.VOIDP], PyObject)
def PyDescr_NewWrapper(space, type, wrapper, wrapped):
    raise NotImplementedError

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyDescr_IsData(space, descr):
    """Return true if the descriptor objects descr describes a data attribute, or
    false if it describes a method.  descr must be a descriptor object; there is
    no error checking.
    """
    raise NotImplementedError

@cpython_api([PyObject, PyObject], PyObject)
def PyWrapper_New(space, w_d, w_self):
    raise NotImplementedError

@cpython_api([PyObject, PyObject, rffi.INT_real], rffi.INT_real, error=-1)
def PyDict_MergeFromSeq2(space, a, seq2, override):
    """Update or merge into dictionary a, from the key-value pairs in seq2.
    seq2 must be an iterable object producing iterable objects of length 2,
    viewed as key-value pairs.  In case of duplicate keys, the last wins if
    override is true, else the first wins. Return 0 on success or -1
    if an exception was raised. Equivalent Python (except for the return
    value):

    def PyDict_MergeFromSeq2(a, seq2, override):
        for key, value in seq2:
            if override or key not in a:
                a[key] = value
    """
    raise NotImplementedError

@cpython_api([PyObject, rffi.INT_real], PyObject)
def PyErr_SetExcFromWindowsErr(space, type, ierr):
    """Similar to PyErr_SetFromWindowsErr(), with an additional parameter
    specifying the exception type to be raised. Availability: Windows.

    Return value: always NULL."""
    raise NotImplementedError

@cpython_api([rffi.INT_real, rffi.CCHARP], PyObject)
def PyErr_SetFromWindowsErrWithFilename(space, ierr, filename):
    """Similar to PyErr_SetFromWindowsErr(), with the additional behavior that
    if filename is not NULL, it is passed to the constructor of
    WindowsError as a third parameter.  filename is decoded from the
    filesystem encoding (sys.getfilesystemencoding()).  Availability:
    Windows.
    Return value: always NULL."""
    raise NotImplementedError

@cpython_api([PyObject, rffi.INT_real, rffi.CCHARP], PyObject)
def PyErr_SetExcFromWindowsErrWithFilename(space, type, ierr, filename):
    """Similar to PyErr_SetFromWindowsErrWithFilename(), with an additional
    parameter specifying the exception type to be raised. Availability: Windows.

    Return value: always NULL."""
    raise NotImplementedError


@cpython_api([rffi.CCHARP, rffi.INT_real, rffi.INT_real], lltype.Void)
def PyErr_SyntaxLocationEx(space, filename, lineno, col_offset):
    """Set file, line, and offset information for the current exception.  If the
    current exception is not a SyntaxError, then it sets additional
    attributes, which make the exception printing subsystem think the exception
    is a SyntaxError. filename is decoded from the filesystem encoding
    (sys.getfilesystemencoding())."""
    raise NotImplementedError


@cpython_api([rffi.CCHARP, rffi.INT_real], lltype.Void)
def PyErr_SyntaxLocation(space, filename, lineno):
    """Like PyErr_SyntaxLocationExc(), but the col_offset parameter is
    omitted."""
    raise NotImplementedError



@cpython_api([rffi.INT_real], rffi.INT_real, error=-1)
def PySignal_SetWakeupFd(space, fd):
    """This utility function specifies a file descriptor to which a '\0' byte will
    be written whenever a signal is received.  It returns the previous such file
    descriptor.  The value -1 disables the feature; this is the initial state.
    This is equivalent to signal.set_wakeup_fd() in Python, but without any
    error checking.  fd should be a valid file descriptor.  The function should
    only be called from the main thread."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.CCHARP, Py_ssize_t, Py_ssize_t, Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicodeDecodeError_Create(space, encoding, object, length, start, end, reason):
    """Create a UnicodeDecodeError object with the attributes encoding,
    object, length, start, end and reason. encoding and reason are
    UTF-8 encoded strings."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, Py_ssize_t, Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicodeEncodeError_Create(space, encoding, object, length, start, end, reason):
    """Create a UnicodeEncodeError object with the attributes encoding,
    object, length, start, end and reason. encoding and reason are
    UTF-8 encoded strings."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, Py_ssize_t, Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicodeTranslateError_Create(space, object, length, start, end, reason):
    """Create a UnicodeTranslateError object with the attributes object,
    length, start, end and reason. reason is an UTF-8 encoded string."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyUnicodeDecodeError_GetEncoding(space, exc):
    """Return the encoding attribute of the given exception object."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyUnicodeDecodeError_GetObject(space, exc):
    """Return the object attribute of the given exception object."""
    raise NotImplementedError

@cpython_api([PyObject, Py_ssize_t], rffi.INT_real, error=-1)
def PyUnicodeDecodeError_GetStart(space, exc, start):
    """Get the start attribute of the given exception object and place it into
    *start.  start must not be NULL.  Return 0 on success, -1 on
    failure."""
    raise NotImplementedError

@cpython_api([PyObject, Py_ssize_t], rffi.INT_real, error=-1)
def PyUnicodeDecodeError_SetStart(space, exc, start):
    """Set the start attribute of the given exception object to start.  Return
    0 on success, -1 on failure."""
    raise NotImplementedError

@cpython_api([PyObject, Py_ssize_t], rffi.INT_real, error=-1)
def PyUnicodeDecodeError_GetEnd(space, exc, end):
    """Get the end attribute of the given exception object and place it into
    *end.  end must not be NULL.  Return 0 on success, -1 on
    failure."""
    raise NotImplementedError

@cpython_api([PyObject, Py_ssize_t], rffi.INT_real, error=-1)
def PyUnicodeDecodeError_SetEnd(space, exc, end):
    """Set the end attribute of the given exception object to end.  Return 0
    on success, -1 on failure."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyUnicodeDecodeError_GetReason(space, exc):
    """Return the reason attribute of the given exception object."""
    raise NotImplementedError

@cpython_api([PyObject, rffi.CCHARP], rffi.INT_real, error=-1)
def PyUnicodeDecodeError_SetReason(space, exc, reason):
    """Set the reason attribute of the given exception object to reason.  Return
    0 on success, -1 on failure."""
    raise NotImplementedError

@cpython_api([], PyObject)
def PyFloat_GetInfo(space):
    """Return a structseq instance which contains information about the
    precision, minimum and maximum values of a float. It's a thin wrapper
    around the header file float.h.
    """
    raise NotImplementedError

@cpython_api([], rffi.DOUBLE, error=CANNOT_FAIL)
def PyFloat_GetMax(space):
    """Return the maximum representable finite float DBL_MAX as C double.
    """
    raise NotImplementedError

@cpython_api([], rffi.DOUBLE, error=CANNOT_FAIL)
def PyFloat_GetMin(space):
    """Return the minimum normalized positive float DBL_MIN as C double.
    """
    raise NotImplementedError

@cpython_api([], rffi.INT_real, error=-1)
def PyFloat_ClearFreeList(space, ):
    """Clear the float free list. Return the number of items that could not
    be freed.
    """
    raise NotImplementedError

@cpython_api([PyObject, PyObject], PyObject)
def PyFunction_New(space, code, globals):
    """Return a new function object associated with the code object code. globals
    must be a dictionary with the global variables accessible to the function.

    The function's docstring, name and __module__ are retrieved from the code
    object, the argument defaults and closure are set to NULL."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyFunction_GetGlobals(space, op):
    """Return the globals dictionary associated with the function object op."""
    raise NotImplementedError
    borrow_from()

@cpython_api([PyObject], PyObject)
def PyFunction_GetModule(space, op):
    """Return the __module__ attribute of the function object op. This is normally
    a string containing the module name, but can be set to any other object by
    Python code."""
    raise NotImplementedError
    borrow_from()

@cpython_api([PyObject], PyObject)
def PyFunction_GetDefaults(space, op):
    """Return the argument default values of the function object op. This can be a
    tuple of arguments or NULL."""
    raise NotImplementedError
    borrow_from()

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyFunction_SetDefaults(space, op, defaults):
    """Set the argument default values for the function object op. defaults must be
    Py_None or a tuple.

    Raises SystemError and returns -1 on failure."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyFunction_GetClosure(space, op):
    """Return the closure associated with the function object op. This can be NULL
    or a tuple of cell objects."""
    raise NotImplementedError
    borrow_from()

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyFunction_SetClosure(space, op, closure):
    """Set the closure associated with the function object op. closure must be
    Py_None or a tuple of cell objects.

    Raises SystemError and returns -1 on failure."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyFunction_GetAnnotations(space, op):
    """Return the annotations of the function object op. This can be a
    mutable dictionary or NULL."""
    raise NotImplementedError


@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyFunction_SetAnnotations(space, op, annotations):
    """Set the annotations for the function object op. annotations
    must be a dictionary or Py_None.

    Raises SystemError and returns -1 on failure."""
    raise NotImplementedError

@cpython_api([PyObject, Py_ssize_t], PyObject)
def PyObject_GC_Resize(space, op, newsize):
    """Resize an object allocated by PyObject_NewVar().  Returns the
    resized object or NULL on failure."""
    raise NotImplementedError

@cpython_api([PyFrameObject], PyObject)
def PyGen_New(space, frame):
    """Create and return a new generator object based on the frame object. A
    reference to frame is stolen by this function. The parameter must not be
    NULL."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, PyObject, rffi.CCHARP, rffi.CCHARP], PyObject)
def PyImport_ExecCodeModuleWithPathnames(space, name, co, pathname, cpathname):
    """Like PyImport_ExecCodeModuleEx(), but the __cached__
    attribute of the module object is set to cpathname if it is
    non-NULL.  Of the three functions, this is the preferred one to use.
    """
    raise NotImplementedError

@cpython_api([], lltype.Signed, error=CANNOT_FAIL)
def PyImport_GetMagicNumber(space):
    """Return the magic number for Python bytecode files (a.k.a. .pyc and
    .pyo files).  The magic number should be present in the first four bytes
    of the bytecode file, in little-endian byte order."""
    raise NotImplementedError

@cpython_api([], rffi.CCHARP)
def PyImport_GetMagicTag(space, ):
    """Return the magic tag string for PEP 3147 format Python bytecode file
    names.
    """
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyImport_GetImporter(space, path):
    """Return an importer object for a sys.path/pkg.__path__ item
    path, possibly by fetching it from the sys.path_importer_cache
    dict.  If it wasn't yet cached, traverse sys.path_hooks until a hook
    is found that can handle the path item.  Return None if no hook could;
    this tells our caller it should fall back to the built-in import mechanism.
    Cache the result in sys.path_importer_cache.  Return a new reference
    to the importer object.
    """
    raise NotImplementedError

@cpython_api([], lltype.Void)
def _PyImport_Init(space):
    """Initialize the import mechanism.  For internal use only."""
    raise NotImplementedError

@cpython_api([], lltype.Void)
def PyImport_Cleanup(space):
    """Empty the module table.  For internal use only."""
    raise NotImplementedError

@cpython_api([], lltype.Void)
def _PyImport_Fini(space):
    """Finalize the import mechanism.  For internal use only."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP], rffi.INT_real, error=-1)
def PyImport_ImportFrozenModule(space, name):
    """Load a frozen module named name.  Return 1 for success, 0 if the
    module is not found, and -1 with an exception set if the initialization
    failed.  To access the imported module on a successful load, use
    PyImport_ImportModule().  (Note the misnomer --- this function would
    reload the module if it was already imported.)"""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.VOIDP], rffi.INT_real, error=-1)
def PyImport_AppendInittab(space, name, initfunc):
    """Add a single module to the existing table of built-in modules.  This is a
    convenience wrapper around PyImport_ExtendInittab(), returning -1 if
    the table could not be extended.  The new module can be imported by the name
    name, and uses the function initfunc as the initialization function called
    on the first attempted import.  This should be called before
    Py_Initialize()."""
    raise NotImplementedError

@cpython_api([_inittab], rffi.INT_real, error=-1)
def PyImport_ExtendInittab(space, newtab):
    """Add a collection of modules to the table of built-in modules.  The newtab
    array must end with a sentinel entry which contains NULL for the name
    field; failure to provide the sentinel value can result in a memory fault.
    Returns 0 on success or -1 if insufficient memory could be allocated to
    extend the internal table.  In the event of failure, no modules are added to the
    internal table.  This should be called before Py_Initialize()."""
    raise NotImplementedError

@cpython_api([], lltype.Void)
def Py_Initialize(space, ):
    """
    Initialize the Python interpreter.  In an application embedding  Python, this
    should be called before using any other Python/C API functions; with the
    exception of Py_SetProgramName(), Py_SetPythonHome() and Py_SetPath().  This initializes
    the table of loaded modules (sys.modules), and creates the fundamental
    modules builtins, __main__ and sys.  It also initializes
    the module search path (sys.path). It does not set sys.argv; use
    PySys_SetArgvEx() for that.  This is a no-op when called for a second time
    (without calling Py_Finalize() first).  There is no return value; it is a
    fatal error if the initialization fails."""
    raise NotImplementedError

@cpython_api([rffi.INT_real], lltype.Void)
def Py_InitializeEx(space, initsigs):
    """This function works like Py_Initialize() if initsigs is 1. If
    initsigs is 0, it skips initialization registration of signal handlers, which
    might be useful when Python is embedded.
    """
    raise NotImplementedError

@cpython_api([], lltype.Void)
def Py_Finalize(space):
    """Undo all initializations made by Py_Initialize() and subsequent use of
    Python/C API functions, and destroy all sub-interpreters (see
    Py_NewInterpreter() below) that were created and not yet destroyed since
    the last call to Py_Initialize().  Ideally, this frees all memory
    allocated by the Python interpreter.  This is a no-op when called for a second
    time (without calling Py_Initialize() again first).  There is no return
    value; errors during finalization are ignored.

    This function is provided for a number of reasons.  An embedding application
    might want to restart Python without having to restart the application itself.
    An application that has loaded the Python interpreter from a dynamically
    loadable library (or DLL) might want to free all memory allocated by Python
    before unloading the DLL. During a hunt for memory leaks in an application a
    developer might want to free all memory allocated by Python before exiting from
    the application.

    Bugs and caveats: The destruction of modules and objects in modules is done
    in random order; this may cause destructors (__del__() methods) to fail
    when they depend on other objects (even functions) or modules.  Dynamically
    loaded extension modules loaded by Python are not unloaded.  Small amounts of
    memory allocated by the Python interpreter may not be freed (if you find a leak,
    please report it).  Memory tied up in circular references between objects is not
    freed.  Some memory allocated by extension modules may not be freed.  Some
    extensions may not work properly if their initialization routine is called more
    than once; this can happen if an application calls Py_Initialize() and
    Py_Finalize() more than once."""
    raise NotImplementedError

@cpython_api([rffi.CWCHARP], lltype.Void)
def Py_SetProgramName(space, name):
    """
    This function should be called before Py_Initialize() is called for
    the first time, if it is called at all.  It tells the interpreter the value
    of the argv[0] argument to the main() function of the program
    (converted to wide characters).
    This is used by Py_GetPath() and some other functions below to find
    the Python run-time libraries relative to the interpreter executable.  The
    default value is 'python'.  The argument should point to a
    zero-terminated wide character string in static storage whose contents will not
    change for the duration of the program's execution.  No code in the Python
    interpreter will change the contents of this storage."""
    raise NotImplementedError

@cpython_api([], rffi.CWCHARP)
def Py_GetPrefix(space):
    """Return the prefix for installed platform-independent files. This is derived
    through a number of complicated rules from the program name set with
    Py_SetProgramName() and some environment variables; for example, if the
    program name is '/usr/local/bin/python', the prefix is '/usr/local'. The
    returned string points into static storage; the caller should not modify its
    value.  This corresponds to the prefix variable in the top-level
    Makefile and the --prefix argument to the configure
    script at build time.  The value is available to Python code as sys.prefix.
    It is only useful on Unix.  See also the next function."""
    raise NotImplementedError

@cpython_api([], rffi.CWCHARP)
def Py_GetExecPrefix(space):
    """Return the exec-prefix for installed platform-dependent files.  This is
    derived through a number of complicated rules from the program name set with
    Py_SetProgramName() and some environment variables; for example, if the
    program name is '/usr/local/bin/python', the exec-prefix is
    '/usr/local'.  The returned string points into static storage; the caller
    should not modify its value.  This corresponds to the exec_prefix
    variable in the top-level Makefile and the --exec-prefix
    argument to the configure script at build  time.  The value is
    available to Python code as sys.exec_prefix.  It is only useful on Unix.

    Background: The exec-prefix differs from the prefix when platform dependent
    files (such as executables and shared libraries) are installed in a different
    directory tree.  In a typical installation, platform dependent files may be
    installed in the /usr/local/plat subtree while platform independent may
    be installed in /usr/local.

    Generally speaking, a platform is a combination of hardware and software
    families, e.g.  Sparc machines running the Solaris 2.x operating system are
    considered the same platform, but Intel machines running Solaris 2.x are another
    platform, and Intel machines running Linux are yet another platform.  Different
    major revisions of the same operating system generally also form different
    platforms.  Non-Unix operating systems are a different story; the installation
    strategies on those systems are so different that the prefix and exec-prefix are
    meaningless, and set to the empty string. Note that compiled Python bytecode
    files are platform independent (but not independent from the Python version by
    which they were compiled!).

    System administrators will know how to configure the mount or
    automount programs to share /usr/local between platforms
    while having /usr/local/plat be a different filesystem for each
    platform."""
    raise NotImplementedError

@cpython_api([], rffi.CWCHARP)
def Py_GetProgramFullPath(space):
    """
    Return the full program name of the Python executable; this is  computed as a
    side-effect of deriving the default module search path  from the program name
    (set by Py_SetProgramName() above). The returned string points into
    static storage; the caller should not modify its value.  The value is available
    to Python code as sys.executable."""
    raise NotImplementedError

@cpython_api([], rffi.CWCHARP)
def Py_GetPath(space, ):
    """
    Return the default module search path; this is computed from the program name
    (set by Py_SetProgramName() above) and some environment variables.
    The returned string consists of a series of directory names separated by a
    platform dependent delimiter character.  The delimiter character is ':'
    on Unix and Mac OS X, ';' on Windows.  The returned string points into
    static storage; the caller should not modify its value.  The list
    sys.path is initialized with this value on interpreter startup; it
    can be (and usually is) modified later to change the search path for loading
    modules.

    XXX should give the exact rules"""
    raise NotImplementedError

@cpython_api([rffi.CWCHARP], lltype.Void)
def Py_SetPath(space, path):
    """
    Set the default module search path.  If this function is called before
    Py_Initialize(), then Py_GetPath() won't attempt to compute a
    default search path but uses the one provided instead.  This is useful if
    Python is embedded by an application that has full knowledge of the location
    of all modules.  The path components should be separated by semicolons.

    This also causes sys.executable to be set only to the raw program
    name (see Py_SetProgramName()) and for sys.prefix and
    sys.exec_prefix to be empty.  It is up to the caller to modify these
    if required after calling Py_Initialize()."""
    raise NotImplementedError


@cpython_api([], rffi.CCHARP)
def Py_GetPlatform(space):
    """
    Return the platform identifier for the current platform.  On Unix, this is
    formed from the "official" name of the operating system, converted to lower
    case, followed by the major revision number; e.g., for Solaris 2.x, which is
    also known as SunOS 5.x, the value is 'sunos5'.  On Mac OS X, it is
    'darwin'.  On Windows, it is 'win'.  The returned string points into
    static storage; the caller should not modify its value.  The value is available
    to Python code as sys.platform."""
    raise NotImplementedError

@cpython_api([], rffi.CCHARP)
def Py_GetCopyright(space):
    """Return the official copyright string for the current Python version, for example

    'Copyright 1991-1995 Stichting Mathematisch Centrum, Amsterdam'

    The returned string points into static storage; the caller should not modify its
    value.  The value is available to Python code as sys.copyright."""
    raise NotImplementedError

@cpython_api([], rffi.CCHARP)
def Py_GetCompiler(space):
    """Return an indication of the compiler used to build the current Python version,
    in square brackets, for example:

    "[GCC 2.7.2.2]"

    The returned string points into static storage; the caller should not modify its
    value.  The value is available to Python code as part of the variable
    sys.version."""
    raise NotImplementedError

@cpython_api([], rffi.CCHARP)
def Py_GetBuildInfo(space):
    """Return information about the sequence number and build date and time  of the
    current Python interpreter instance, for example

    "\#67, Aug  1 1997, 22:34:28"

    The returned string points into static storage; the caller should not modify its
    value.  The value is available to Python code as part of the variable
    sys.version."""
    raise NotImplementedError

@cpython_api([rffi.INT_real, CWCHARPP, rffi.INT_real], lltype.Void)
def PySys_SetArgvEx(space, argc, argv, updatepath):
    """
    Set sys.argv based on argc and argv.  These parameters are
    similar to those passed to the program's main() function with the
    difference that the first entry should refer to the script file to be
    executed rather than the executable hosting the Python interpreter.  If there
    isn't a script that will be run, the first entry in argv can be an empty
    string.  If this function fails to initialize sys.argv, a fatal
    condition is signalled using Py_FatalError().

    If updatepath is zero, this is all the function does.  If updatepath
    is non-zero, the function also modifies sys.path according to the
    following algorithm:

    If the name of an existing script is passed in argv[0], the absolute
    path of the directory where the script is located is prepended to
    sys.path.

    Otherwise (that is, if argc is 0 or argv[0] doesn't point
    to an existing file name), an empty string is prepended to
    sys.path, which is the same as prepending the current working
    directory (".").

    It is recommended that applications embedding the Python interpreter
    for purposes other than executing a single script pass 0 as updatepath,
    and update sys.path themselves if desired.
    See CVE-2008-5983.

    On versions before 3.1.3, you can achieve the same effect by manually
    popping the first sys.path element after having called
    PySys_SetArgv(), for example using:

    PyRun_SimpleString("import sys; sys.path.pop(0)\n");

    XXX impl. doesn't seem consistent in allowing 0/NULL for the params;
    check w/ Guido."""
    raise NotImplementedError

@cpython_api([rffi.INT_real, CWCHARPP], lltype.Void)
def PySys_SetArgv(space, argc, argv):
    """This function works like PySys_SetArgvEx() with updatepath set
    to 1 unless the python interpreter was started with the option -I."""
    raise NotImplementedError

@cpython_api([rffi.CWCHARP], lltype.Void)
def Py_SetPythonHome(space, home):
    """Set the default "home" directory, that is, the location of the standard
    Python libraries.  See PYTHONHOME for the meaning of the
    argument string.

    The argument should point to a zero-terminated character string in static
    storage whose contents will not change for the duration of the program's
    execution.  No code in the Python interpreter will change the contents of
    this storage."""
    raise NotImplementedError

@cpython_api([], rffi.CWCHARP)
def Py_GetPythonHome(space):
    """Return the default "home", that is, the value set by a previous call to
    Py_SetPythonHome(), or the value of the PYTHONHOME
    environment variable if it is set."""
    raise NotImplementedError

@cpython_api([], lltype.Void)
def PyEval_ReInitThreads(space):
    """This function is called from PyOS_AfterFork() to ensure that newly
    created child processes don't hold locks referring to threads which
    are not running in the child process."""
    raise NotImplementedError

@cpython_api([], PyThreadState)
def PyGILState_GetThisThreadState(space, ):
    """Get the current thread state for this thread.  May return NULL if no
    GILState API has been used on the current thread.  Note that the main thread
    always has such a thread-state, even if no auto-thread-state call has been
    made on the main thread.  This is mainly a helper/diagnostic function."""
    raise NotImplementedError


@cpython_api([], PyInterpreterState)
def PyInterpreterState_New(space):
    """Create a new interpreter state object.  The global interpreter lock need not
    be held, but may be held if it is necessary to serialize calls to this
    function."""
    raise NotImplementedError

@cpython_api([PyInterpreterState], lltype.Void)
def PyInterpreterState_Clear(space, interp):
    """Reset all information in an interpreter state object.  The global interpreter
    lock must be held."""
    raise NotImplementedError

@cpython_api([PyInterpreterState], lltype.Void)
def PyInterpreterState_Delete(space, interp):
    """Destroy an interpreter state object.  The global interpreter lock need not be
    held.  The interpreter state must have been reset with a previous call to
    PyInterpreterState_Clear()."""
    raise NotImplementedError

@cpython_api([lltype.Signed, PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyThreadState_SetAsyncExc(space, id, exc):
    """Asynchronously raise an exception in a thread. The id argument is the thread
    id of the target thread; exc is the exception object to be raised. This
    function does not steal any references to exc. To prevent naive misuse, you
    must write your own C extension to call this.  Must be called with the GIL held.
    Returns the number of thread states modified; this is normally one, but will be
    zero if the thread id isn't found.  If exc is NULL, the pending
    exception (if any) for the thread is cleared. This raises no exceptions."""
    raise NotImplementedError

@cpython_api([], lltype.Void)
def PyEval_AcquireLock(space):
    """Acquire the global interpreter lock.  The lock must have been created earlier.
    If this thread already has the lock, a deadlock ensues.

    This function does not update the current thread state.  Please use
    PyEval_RestoreThread() or PyEval_AcquireThread()
    instead."""
    raise NotImplementedError

@cpython_api([], lltype.Void)
def PyEval_ReleaseLock(space):
    """Release the global interpreter lock.  The lock must have been created earlier.

    This function does not update the current thread state.  Please use
    PyEval_SaveThread() or PyEval_ReleaseThread()
    instead."""
    raise NotImplementedError

@cpython_api([], PyThreadState)
def Py_NewInterpreter(space):
    """Create a new sub-interpreter.  This is an (almost) totally separate
    environment for the execution of Python code.  In particular, the new
    interpreter has separate, independent versions of all imported modules,
    including the fundamental modules builtins, __main__ and sys.  The table of
    loaded modules (sys.modules) and the module search path (sys.path) are also
    separate.  The new environment has no sys.argv variable.  It has new standard
    I/O stream file objects sys.stdin, sys.stdout and sys.stderr (however these
    refer to the same underlying file descriptors).

    The return value points to the first thread state created in the new
    sub-interpreter.  This thread state is made in the current thread state.
    Note that no actual thread is created; see the discussion of thread states
    below.  If creation of the new interpreter is unsuccessful, NULL is
    returned; no exception is set since the exception state is stored in the
    current thread state and there may not be a current thread state.  (Like all
    other Python/C API functions, the global interpreter lock must be held before
    calling this function and is still held when it returns; however, unlike most
    other Python/C API functions, there needn't be a current thread state on
    entry.)

    Extension modules are shared between (sub-)interpreters as follows: the first
    time a particular extension is imported, it is initialized normally, and a
    (shallow) copy of its module's dictionary is squirreled away.  When the same
    extension is imported by another (sub-)interpreter, a new module is initialized
    and filled with the contents of this copy; the extension's init function is
    not called.  Note that this is different from what happens when an extension is
    imported after the interpreter has been completely re-initialized by calling
    Py_Finalize() and Py_Initialize(); in that case, the extension's
    initmodule function is called again."""
    raise NotImplementedError

@cpython_api([PyThreadState], lltype.Void)
def Py_EndInterpreter(space, tstate):
    """Destroy the (sub-)interpreter represented by the given thread state. The
    given thread state must be the current thread state.  See the discussion of
    thread states below.  When the call returns, the current thread state is
    NULL.  All thread states associated with this interpreter are destroyed.
    (The global interpreter lock must be held before calling this function and is
    still held when it returns.)  Py_Finalize() will destroy all sub-interpreters
    that haven't been explicitly destroyed at that point."""
    raise NotImplementedError

@cpython_api([Py_tracefunc, PyObject], lltype.Void)
def PyEval_SetProfile(space, func, obj):
    """Set the profiler function to func.  The obj parameter is passed to the
    function as its first parameter, and may be any Python object, or NULL.  If
    the profile function needs to maintain state, using a different value for obj
    for each thread provides a convenient and thread-safe place to store it.  The
    profile function is called for all monitored events except the line-number
    events."""
    raise NotImplementedError

@cpython_api([Py_tracefunc, PyObject], lltype.Void)
def PyEval_SetTrace(space, func, obj):
    """Set the tracing function to func.  This is similar to
    PyEval_SetProfile(), except the tracing function does receive line-number
    events."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyEval_GetCallStats(space, self):
    """Return a tuple of function call counts.  There are constants defined for the
    positions within the tuple:

    Name

    Value

    PCALL_ALL

    0

    PCALL_FUNCTION

    1

    PCALL_FAST_FUNCTION

    2

    PCALL_FASTER_FUNCTION

    3

    PCALL_METHOD

    4

    PCALL_BOUND_METHOD

    5

    PCALL_CFUNCTION

    6

    PCALL_TYPE

    7

    PCALL_GENERATOR

    8

    PCALL_OTHER

    9

    PCALL_POP

    10

    PCALL_FAST_FUNCTION means no argument tuple needs to be created.
    PCALL_FASTER_FUNCTION means that the fast-path frame setup code is used.

    If there is a method call where the call can be optimized by changing
    the argument tuple and calling the function directly, it gets recorded
    twice.

    This function is only present if Python is compiled with CALL_PROFILE
    defined."""
    raise NotImplementedError

@cpython_api([PyInterpreterState], PyThreadState)
def PyInterpreterState_ThreadHead(space, interp):
    """Return the a pointer to the first PyThreadState object in the list of
    threads associated with the interpreter interp.
    """
    raise NotImplementedError

@cpython_api([PyThreadState], PyThreadState)
def PyThreadState_Next(space, tstate):
    """Return the next thread state object after tstate from the list of all such
    objects belonging to the same PyInterpreterState object.
    """
    raise NotImplementedError

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PySeqIter_Check(space, op):
    """Return true if the type of op is PySeqIter_Type.
    """
    raise NotImplementedError

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyCallIter_Check(space, op):
    """Return true if the type of op is PyCallIter_Type.
    """
    raise NotImplementedError

@cpython_api([PyObject, rffi.CCHARP], rffi.INT_real, error=-1)
def PyMapping_DelItemString(space, o, key):
    """Remove the mapping for object key from the object o. Return -1 on
    failure.  This is equivalent to the Python statement del o[key]."""
    raise NotImplementedError

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyMapping_DelItem(space, o, key):
    """Remove the mapping for object key from the object o. Return -1 on
    failure.  This is equivalent to the Python statement del o[key]."""
    raise NotImplementedError

@cpython_api([lltype.Signed, FILE, rffi.INT_real], lltype.Void)
def PyMarshal_WriteLongToFile(space, value, file, version):
    """Marshal a long integer, value, to file.  This will only write
    the least-significant 32 bits of value; regardless of the size of the
    native long type.

    version indicates the file format."""
    raise NotImplementedError

@cpython_api([PyObject, FILE, rffi.INT_real], lltype.Void)
def PyMarshal_WriteObjectToFile(space, value, file, version):
    """Marshal a Python object, value, to file.

    version indicates the file format."""
    raise NotImplementedError

@cpython_api([FILE], lltype.Signed, error=-1)
def PyMarshal_ReadLongFromFile(space, file):
    """Return a C long from the data stream in a FILE* opened
    for reading.  Only a 32-bit value can be read in using this function,
    regardless of the native size of long."""
    raise NotImplementedError

@cpython_api([FILE], rffi.INT_real, error=-1)
def PyMarshal_ReadShortFromFile(space, file):
    """Return a C short from the data stream in a FILE* opened
    for reading.  Only a 16-bit value can be read in using this function,
    regardless of the native size of short."""
    raise NotImplementedError

@cpython_api([FILE], PyObject)
def PyMarshal_ReadObjectFromFile(space, file):
    """Return a Python object from the data stream in a FILE* opened for
    reading.  On error, sets the appropriate exception (EOFError or
    TypeError) and returns NULL."""
    raise NotImplementedError

@cpython_api([FILE], PyObject)
def PyMarshal_ReadLastObjectFromFile(space, file):
    """Return a Python object from the data stream in a FILE* opened for
    reading.  Unlike PyMarshal_ReadObjectFromFile(), this function
    assumes that no further objects will be read from the file, allowing it to
    aggressively load file data into memory so that the de-serialization can
    operate from data in memory rather than reading a byte at a time from the
    file.  Only use these variant if you are certain that you won't be reading
    anything else from the file.  On error, sets the appropriate exception
    (EOFError or TypeError) and returns NULL."""
    raise NotImplementedError

@cpython_api([], rffi.INT_real, error=-1)
def PyMethod_ClearFreeList(space):
    """Clear the free list. Return the total number of freed items.
    """
    raise NotImplementedError

@cpython_api([PyObject], rffi.CCHARP)
def PyModule_GetFilename(space, module):
    """Similar to PyModule_GetFilenameObject() but return the filename
    encoded to 'utf-8'.

    PyModule_GetFilename() raises UnicodeEncodeError on
    unencodable filenames, use PyModule_GetFilenameObject() instead."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyModule_GetFilenameObject(space, module):
    """
    Return the name of the file from which module was loaded using module's
    __file__ attribute.  If this is not defined, or if it is not a
    unicode string, raise SystemError and return NULL; otherwise return
    a reference to a PyUnicodeObject.
    raise NotImplementedError

@cpython_api([PyFrameObject], rffi.INT_real, error=-1)
def PyFrame_GetLineNumber(space, frame):
    """Return the line number that frame is currently executing."""
    raise NotImplementedError

@cpython_api([PyObject], rffi.CCHARP)
def PyEval_GetFuncName(space, func):
    """Return the name of func if it is a function, class or instance object, else the
    name of funcs type."""
    raise NotImplementedError

@cpython_api([PyObject], rffi.CCHARP)
def PyEval_GetFuncDesc(space, func):
    """Return a description string, depending on the type of func.
    Return values include "()" for functions and methods, " constructor",
    " instance", and " object".  Concatenated with the result of
    PyEval_GetFuncName(), the result will be a description of
    func."""
    raise NotImplementedError

@cpython_api([PyObject, PyObject], Py_ssize_t, error=-1)
def PySequence_Count(space, o, value):
    """Return the number of occurrences of value in o, that is, return the number
    of keys for which o[key] == value.  On failure, return -1.  This is
    equivalent to the Python expression o.count(value)."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP], rffi.INT_real, error=-1)
def Py_FdIsInteractive(space, fp, filename):
    """Return true (nonzero) if the standard I/O file fp with name filename is
    deemed interactive.  This is the case for files for which isatty(fileno(fp))
    is true.  If the global flag Py_InteractiveFlag is true, this function
    also returns true if the filename pointer is NULL or if the name is equal to
    one of the strings '<stdin>' or '???'."""
    raise NotImplementedError

@cpython_api([], rffi.INT_real, error=CANNOT_FAIL)
def PyOS_CheckStack(space):
    """Return true when the interpreter runs out of stack space.  This is a reliable
    check, but is only available when USE_STACKCHECK is defined (currently
    on Windows using the Microsoft Visual C++ compiler).  USE_STACKCHECK
    will be defined automatically; you should never change the definition in your
    own code."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, FILE], FILE)
def PySys_GetFile(space, name, def_):
    """Return the FILE* associated with the object name in the
    sys module, or def if name is not in the module or is not associated
    with a FILE*."""
    raise NotImplementedError

@cpython_api([], lltype.Void)
def PySys_ResetWarnOptions(space):
    """Reset sys.warnoptions to an empty list."""
    raise NotImplementedError

@cpython_api([rffi.CWCHARP], lltype.Void)
def PySys_AddWarnOption(space, s):
    """Append s to sys.warnoptions."""
    raise NotImplementedError

@cpython_api([PyObject], lltype.Void)
def PySys_AddWarnOptionUnicode(space, unicode):
    """Append unicode to sys.warnoptions."""
    raise NotImplementedError


@cpython_api([rffi.CWCHARP], lltype.Void)
def PySys_SetPath(space, path):
    """Set sys.path to a list object of paths found in path which should
    be a list of paths separated with the platform's search path delimiter
    (: on Unix, ; on Windows)."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, ], lltype.Void)
def PySys_FormatStdout(space, format, ):
    """Function similar to PySys_WriteStdout() but format the message using
    PyUnicode_FromFormatV() and don't truncate the message to an
    arbitrary length.
    """
    raise NotImplementedError

@cpython_api([rffi.CCHARP, ], lltype.Void)
def PySys_FormatStderr(space, format, ):
    """As PySys_FormatStdout(), but write to sys.stderr or stderr
    instead.
    """
    raise NotImplementedError

@cpython_api([rffi.CWCHARP], lltype.Void)
def PySys_AddXOption(space, s):
    """Parse s as a set of -X options and add them to the current
    options mapping as returned by PySys_GetXOptions().
    """
    raise NotImplementedError

@cpython_api([], PyObject)
def PySys_GetXOptions(space, ):
    """Return the current dictionary of -X options, similarly to
    sys._xoptions.  On error, NULL is returned and an exception is
    set.
    """
    raise NotImplementedError
    borrow_from()

@cpython_api([rffi.INT_real], lltype.Void)
def Py_Exit(space, status):
    """
    Exit the current process.  This calls Py_Finalize() and then calls the
    standard C library function exit(status)."""
    raise NotImplementedError

@cpython_api([], rffi.INT_real, error=-1)
def PyTuple_ClearFreeList(space, ):
    """Clear the free list. Return the total number of freed items."""
    raise NotImplementedError


@cpython_api([], rffi.UINT, error=CANNOT_FAIL)
def PyType_ClearCache(space, ):
    """Clear the internal lookup cache. Return the current version tag."""
    raise NotImplementedError


@cpython_api([], rffi.INT_real, error=-1)
def PyUnicode_ClearFreeList(space, ):
    """Clear the free list. Return the total number of freed items."""
    raise NotImplementedError


@cpython_api([Py_UNICODE], rffi.INT_real, error=CANNOT_FAIL)
def Py_UNICODE_ISPRINTABLE(space, ch):
    """Return 1 or 0 depending on whether ch is a printable character.
    Nonprintable characters are those characters defined in the Unicode character
    database as "Other" or "Separator", excepting the ASCII space (0x20) which is
    considered printable.  (Note that printable characters in this context are
    those which should not be escaped when repr() is invoked on a string.
    It has no bearing on the handling of strings written to sys.stdout or
    sys.stderr.)"""
    raise NotImplementedError

@cpython_api([PyObject], rffi.CArrayPtr(Py_UNICODE))
def PyUnicode_AsUnicodeCopy(space, unicode):
    """Create a copy of a Unicode string ending with a nul character. Return NULL
    and raise a MemoryError exception on memory allocation failure,
    otherwise return a new allocated buffer (use PyMem_Free() to free
    the buffer). Note that the resulting Py_UNICODE* string may contain
    embedded null characters, which would cause the string to be truncated when
    used in most C functions.
    """
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, rffi.CCHARP, rffi.CCHARP], PyObject)
def PyUnicode_Encode(space, s, size, encoding, errors):
    """Encode the Py_UNICODE buffer s of the given size and return a Python
    bytes object.  encoding and errors have the same meaning as the
    parameters of the same name in the Unicode encode() method.  The codec
    to be used is looked up using the Python codec registry.  Return NULL if an
    exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP, Py_ssize_t], PyObject)
def PyUnicode_DecodeUTF8Stateful(space, s, size, errors, consumed):
    """If consumed is NULL, behave like PyUnicode_DecodeUTF8(). If
    consumed is not NULL, trailing incomplete UTF-8 byte sequences will not be
    treated as an error. Those bytes will not be decoded and the number of bytes
    that have been decoded will be stored in consumed."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP, rffi.INTP, Py_ssize_t], PyObject)
def PyUnicode_DecodeUTF32Stateful(space, s, size, errors, byteorder, consumed):
    """If consumed is NULL, behave like PyUnicode_DecodeUTF32(). If
    consumed is not NULL, PyUnicode_DecodeUTF32Stateful() will not treat
    trailing incomplete UTF-32 byte sequences (such as a number of bytes not divisible
    by four) as an error. Those bytes will not be decoded and the number of bytes
    that have been decoded will be stored in consumed."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, rffi.CCHARP, rffi.INT_real], PyObject)
def PyUnicode_EncodeUTF32(space, s, size, errors, byteorder):
    """Return a Python bytes object holding the UTF-32 encoded value of the Unicode
    data in s.  Output is written according to the following byte order:

    byteorder == -1: little endian
    byteorder == 0:  native byte order (writes a BOM mark)
    byteorder == 1:  big endian

    If byteorder is 0, the output string will always start with the Unicode BOM
    mark (U+FEFF). In the other two modes, no BOM mark is prepended.

    If Py_UNICODE_WIDE is not defined, surrogate pairs will be output
    as a single codepoint.

    Return NULL if an exception was raised by the codec.
    """
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP, rffi.INTP, Py_ssize_t], PyObject)
def PyUnicode_DecodeUTF16Stateful(space, s, size, errors, byteorder, consumed):
    """If consumed is NULL, behave like PyUnicode_DecodeUTF16(). If
    consumed is not NULL, PyUnicode_DecodeUTF16Stateful() will not treat
    trailing incomplete UTF-16 byte sequences (such as an odd number of bytes or a
    split surrogate pair) as an error. Those bytes will not be decoded and the
    number of bytes that have been decoded will be stored in consumed."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, rffi.CCHARP, rffi.INT_real], PyObject)
def PyUnicode_EncodeUTF16(space, s, size, errors, byteorder):
    """Return a Python bytes object holding the UTF-16 encoded value of the Unicode
    data in s.  Output is written according to the following byte order:

    byteorder == -1: little endian
    byteorder == 0:  native byte order (writes a BOM mark)
    byteorder == 1:  big endian

    If byteorder is 0, the output string will always start with the Unicode BOM
    mark (U+FEFF). In the other two modes, no BOM mark is prepended.

    If Py_UNICODE_WIDE is defined, a single Py_UNICODE value may get
    represented as a surrogate pair. If it is not defined, each Py_UNICODE
    values is interpreted as an UCS-2 character.

    Return NULL if an exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicode_DecodeUTF7(space, s, size, errors):
    """Create a Unicode object by decoding size bytes of the UTF-7 encoded string
    s.  Return NULL if an exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP, Py_ssize_t], PyObject)
def PyUnicode_DecodeUTF7Stateful(space, s, size, errors, consumed):
    """If consumed is NULL, behave like PyUnicode_DecodeUTF7().  If
    consumed is not NULL, trailing incomplete UTF-7 base-64 sections will not
    be treated as an error.  Those bytes will not be decoded and the number of
    bytes that have been decoded will be stored in consumed."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, rffi.INT_real, rffi.INT_real, rffi.CCHARP], PyObject)
def PyUnicode_EncodeUTF7(space, s, size, base64SetO, base64WhiteSpace, errors):
    """Encode the Py_UNICODE buffer of the given size using UTF-7 and
    return a Python bytes object.  Return NULL if an exception was raised by
    the codec.

    If base64SetO is nonzero, "Set O" (punctuation that has no otherwise
    special meaning) will be encoded in base-64.  If base64WhiteSpace is
    nonzero, whitespace will be encoded in base-64.  Both are set to zero for the
    Python "utf-7" codec."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicode_DecodeUnicodeEscape(space, s, size, errors):
    """Create a Unicode object by decoding size bytes of the Unicode-Escape encoded
    string s.  Return NULL if an exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t], PyObject)
def PyUnicode_EncodeUnicodeEscape(space, s, size):
    """Encode the Py_UNICODE buffer of the given size using Unicode-Escape and
    return a Python string object.  Return NULL if an exception was raised by the
    codec."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicode_DecodeRawUnicodeEscape(space, s, size, errors):
    """Create a Unicode object by decoding size bytes of the Raw-Unicode-Escape
    encoded string s.  Return NULL if an exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicode_EncodeRawUnicodeEscape(space, s, size, errors):
    """Encode the Py_UNICODE buffer of the given size using Raw-Unicode-Escape
    and return a Python string object.  Return NULL if an exception was raised by
    the codec."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyUnicode_AsRawUnicodeEscapeString(space, unicode):
    """Encode a Unicode object using Raw-Unicode-Escape and return the result as
    Python string object. Error handling is "strict". Return NULL if an exception
    was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, PyObject, rffi.CCHARP], PyObject)
def PyUnicode_DecodeCharmap(space, s, size, mapping, errors):
    """Create a Unicode object by decoding size bytes of the encoded string s using
    the given mapping object.  Return NULL if an exception was raised by the
    codec. If mapping is NULL latin-1 decoding will be done. Else it can be a
    dictionary mapping byte or a unicode string, which is treated as a lookup table.
    Byte values greater that the length of the string and U+FFFE "characters" are
    treated as "undefined mapping"."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, PyObject, rffi.CCHARP], PyObject)
def PyUnicode_EncodeCharmap(space, s, size, mapping, errors):
    """Encode the Py_UNICODE buffer of the given size using the given
    mapping object and return a Python string object. Return NULL if an
    exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([PyObject, PyObject], PyObject)
def PyUnicode_AsCharmapString(space, unicode, mapping):
    """Encode a Unicode object using the given mapping object and return the result
    as Python string object.  Error handling is "strict".  Return NULL if an
    exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CArrayPtr(Py_UNICODE), Py_ssize_t, PyObject, rffi.CCHARP], PyObject)
def PyUnicode_TranslateCharmap(space, s, size, table, errors):
    """Translate a Py_UNICODE buffer of the given size by applying a
    character mapping table to it and return the resulting Unicode object.  Return
    NULL when an exception was raised by the codec.

    The mapping table must map Unicode ordinal integers to Unicode ordinal
    integers or None (causing deletion of the character).

    Mapping tables need only provide the __getitem__() interface; dictionaries
    and sequences work well.  Unmapped character ordinals (ones which cause a
    LookupError) are left untouched and are copied as-is."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, Py_ssize_t, rffi.CCHARP], PyObject)
def PyUnicode_DecodeMBCS(space, s, size, errors):
    """Create a Unicode object by decoding size bytes of the MBCS encoded string s.
    Return NULL if an exception was raised by the codec."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.INT_real, rffi.CCHARP, rffi.INTP], PyObject)
def PyUnicode_DecodeMBCSStateful(space, s, size, errors, consumed):
    """If consumed is NULL, behave like PyUnicode_DecodeMBCS(). If
    consumed is not NULL, PyUnicode_DecodeMBCSStateful() will not decode
    trailing lead byte and the number of bytes that have been decoded will be stored
    in consumed."""
    raise NotImplementedError

@cpython_api([PyObject], PyObject)
def PyUnicode_AsMBCSString(space, unicode):
    """Encode a Unicode object using MBCS and return the result as Python bytes
    object.  Error handling is "strict".  Return NULL if an exception was
    raised by the codec."""
    raise NotImplementedError


@cpython_api([PyObject, PyObject, rffi.CCHARP], PyObject)
def PyUnicode_Translate(space, str, table, errors):
    """Translate a string by applying a character mapping table to it and return the
    resulting Unicode object.

    The mapping table must map Unicode ordinal integers to Unicode ordinal integers
    or None (causing deletion of the character).

    Mapping tables need only provide the __getitem__() interface; dictionaries
    and sequences work well.  Unmapped character ordinals (ones which cause a
    LookupError) are left untouched and are copied as-is.

    errors has the usual meaning for codecs. It may be NULL which indicates to
    use the default error handling."""
    raise NotImplementedError

@cpython_api([PyObject, PyObject, rffi.INT_real], PyObject)
def PyUnicode_RichCompare(space, left, right, op):
    """Rich compare two unicode strings and return one of the following:

    NULL in case an exception was raised

    Py_True or Py_False for successful comparisons

    Py_NotImplemented in case the type combination is unknown

    Note that Py_EQ and Py_NE comparisons can cause a
    UnicodeWarning in case the conversion of the arguments to Unicode fails
    with a UnicodeDecodeError.

    Possible values for op are Py_GT, Py_GE, Py_EQ,
    Py_NE, Py_LT, and Py_LE."""
    raise NotImplementedError


@cpython_api([rffi.INT_real, CWCHARPP], rffi.INT_real, error=1)
def Py_Main(space, argc, argv):
    """The main program for the standard interpreter.  This is made available for
    programs which embed Python.  The argc and argv parameters should be
    prepared exactly as those which are passed to a C program's main()
    function (converted to wchar_t according to the user's locale).  It is
    important to note that the argument list may be modified (but the contents of
    the strings pointed to by the argument list are not). The return value will
    be 0 if the interpreter exits normally (i.e., without an exception),
    1 if the interpreter exits due to an exception, or 2 if the parameter
    list does not represent a valid Python command line.

    Note that if an otherwise unhandled SystemExit is raised, this
    function will not return 1, but exit the process, as long as
    Py_InspectFlag is not set."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP], rffi.INT_real, error=-1)
def PyRun_AnyFile(space, fp, filename):
    """This is a simplified interface to PyRun_AnyFileExFlags() below, leaving
    closeit set to 0 and flags set to NULL."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, PyCompilerFlags], rffi.INT_real, error=-1)
def PyRun_AnyFileFlags(space, fp, filename, flags):
    """This is a simplified interface to PyRun_AnyFileExFlags() below, leaving
    the closeit argument set to 0."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real], rffi.INT_real, error=-1)
def PyRun_AnyFileEx(space, fp, filename, closeit):
    """This is a simplified interface to PyRun_AnyFileExFlags() below, leaving
    the flags argument set to NULL."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real, PyCompilerFlags], rffi.INT_real, error=-1)
def PyRun_AnyFileExFlags(space, fp, filename, closeit, flags):
    """If fp refers to a file associated with an interactive device (console or
    terminal input or Unix pseudo-terminal), return the value of
    PyRun_InteractiveLoop(), otherwise return the result of
    PyRun_SimpleFile().  filename is decoded from the filesystem
    encoding (sys.getfilesystemencoding()).  If filename is NULL, this
    function uses "???" as the filename."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, PyCompilerFlags], rffi.INT_real, error=-1)
def PyRun_SimpleStringFlags(space, command, flags):
    """Executes the Python source code from command in the __main__ module
    according to the flags argument. If __main__ does not already exist, it
    is created.  Returns 0 on success or -1 if an exception was raised.  If
    there was an error, there is no way to get the exception information. For the
    meaning of flags, see below.

    Note that if an otherwise unhandled SystemExit is raised, this
    function will not return -1, but exit the process, as long as
    Py_InspectFlag is not set."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP], rffi.INT_real, error=-1)
def PyRun_SimpleFile(space, fp, filename):
    """This is a simplified interface to PyRun_SimpleFileExFlags() below,
    leaving closeit set to 0 and flags set to NULL."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, PyCompilerFlags], rffi.INT_real, error=-1)
def PyRun_SimpleFileFlags(space, fp, filename, flags):
    """This is a simplified interface to PyRun_SimpleFileExFlags() below,
    leaving closeit set to 0."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real], rffi.INT_real, error=-1)
def PyRun_SimpleFileEx(space, fp, filename, closeit):
    """This is a simplified interface to PyRun_SimpleFileExFlags() below,
    leaving flags set to NULL."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real, PyCompilerFlags], rffi.INT_real, error=-1)
def PyRun_SimpleFileExFlags(space, fp, filename, closeit, flags):
    """Similar to PyRun_SimpleStringFlags(), but the Python source code is read
    from fp instead of an in-memory string. filename should be the name of
    the file, it is decoded from the filesystem encoding
    (sys.getfilesystemencoding()).  If closeit is true, the file is
    closed before PyRun_SimpleFileExFlags returns."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP], rffi.INT_real, error=-1)
def PyRun_InteractiveOne(space, fp, filename):
    """This is a simplified interface to PyRun_InteractiveOneFlags() below,
    leaving flags set to NULL."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, PyCompilerFlags], rffi.INT_real, error=-1)
def PyRun_InteractiveOneFlags(space, fp, filename, flags):
    """Read and execute a single statement from a file associated with an
    interactive device according to the flags argument.  The user will be
    prompted using sys.ps1 and sys.ps2.  filename is decoded from the
    filesystem encoding (sys.getfilesystemencoding()).

    Returns 0 when the input was
    executed successfully, -1 if there was an exception, or an error code
    from the errcode.h include file distributed as part of Python if
    there was a parse error.  (Note that errcode.h is not included by
    Python.h, so must be included specifically if needed.)"""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP], rffi.INT_real, error=-1)
def PyRun_InteractiveLoop(space, fp, filename):
    """This is a simplified interface to PyRun_InteractiveLoopFlags() below,
    leaving flags set to NULL."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, PyCompilerFlags], rffi.INT_real, error=-1)
def PyRun_InteractiveLoopFlags(space, fp, filename, flags):
    """Read and execute statements from a file associated with an interactive device
    until EOF is reached.  The user will be prompted using sys.ps1 and
    sys.ps2.  filename is decoded from the filesystem encoding
    (sys.getfilesystemencoding()).  Returns 0 at EOF."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.INT_real], struct_node)
def PyParser_SimpleParseString(space, str, start):
    """This is a simplified interface to
    PyParser_SimpleParseStringFlagsFilename() below, leaving  filename set
    to NULL and flags set to 0."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.INT_real, rffi.INT_real], struct_node)
def PyParser_SimpleParseStringFlags(space, str, start, flags):
    """This is a simplified interface to
    PyParser_SimpleParseStringFlagsFilename() below, leaving  filename set
    to NULL."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.CCHARP, rffi.INT_real, rffi.INT_real], struct_node)
def PyParser_SimpleParseStringFlagsFilename(space, str, filename, start, flags):
    """Parse Python source code from str using the start token start according to
    the flags argument.  The result can be used to create a code object which can
    be evaluated efficiently. This is useful if a code fragment must be evaluated
    many times. filename is decoded from the filesystem encoding
    (sys.getfilesystemencoding())."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real], struct_node)
def PyParser_SimpleParseFile(space, fp, filename, start):
    """This is a simplified interface to PyParser_SimpleParseFileFlags() below,
    leaving flags set to 0"""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real, rffi.INT_real], struct_node)
def PyParser_SimpleParseFileFlags(space, fp, filename, start, flags):
    """Similar to PyParser_SimpleParseStringFlagsFilename(), but the Python
    source code is read from fp instead of an in-memory string."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real, PyObject, PyObject, rffi.INT_real], PyObject)
def PyRun_FileEx(space, fp, filename, start, globals, locals, closeit):
    """This is a simplified interface to PyRun_FileExFlags() below, leaving
    flags set to NULL."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real, PyObject, PyObject, PyCompilerFlags], PyObject)
def PyRun_FileFlags(space, fp, filename, start, globals, locals, flags):
    """This is a simplified interface to PyRun_FileExFlags() below, leaving
    closeit set to 0."""
    raise NotImplementedError

@cpython_api([FILE, rffi.CCHARP, rffi.INT_real, PyObject, PyObject, rffi.INT_real, PyCompilerFlags], PyObject)
def PyRun_FileExFlags(space, fp, filename, start, globals, locals, closeit, flags):
    """Similar to PyRun_StringFlags(), but the Python source code is read from
    fp instead of an in-memory string. filename should be the name of the file,
    it is decoded from the filesystem encoding (sys.getfilesystemencoding()).
    If closeit is true, the file is closed before PyRun_FileExFlags()
    returns."""
    raise NotImplementedError

@cpython_api([rffi.CCHARP, rffi.CCHARP, rffi.INT_real, PyCompilerFlags, rffi.INT_real], PyObject)
def Py_CompileStringExFlags(space, str, filename, start, flags, optimize):
    """Parse and compile the Python source code in str, returning the resulting code
    object.  The start token is given by start; this can be used to constrain the
    code which can be compiled and should be Py_eval_input,
    Py_file_input, or Py_single_input.  The filename specified by
    filename is used to construct the code object and may appear in tracebacks or
    SyntaxError exception messages, it is decoded from the filesystem
    encoding (sys.getfilesystemencoding()).  This returns NULL if the
    code cannot be parsed or compiled.

    The integer optimize specifies the optimization level of the compiler; a
    value of -1 selects the optimization level of the interpreter as given by
    -O options.  Explicit levels are 0 (no optimization;
    __debug__ is true), 1 (asserts are removed, __debug__ is false)
    or 2 (docstrings are removed too).
    """
    raise NotImplementedError


@cpython_api([PyObject, PyObject, PyObject, PyObjectP, rffi.INT_real, PyObjectP, rffi.INT_real, PyObjectP, rffi.INT_real, PyObject], PyObject)
def PyEval_EvalCodeEx(space, co, globals, locals, args, argcount, kws, kwcount, defs, defcount, closure):
    """Evaluate a precompiled code object, given a particular environment for its
    evaluation.  This environment consists of dictionaries of global and local
    variables, arrays of arguments, keywords and defaults, and a closure tuple of
    cells."""
    raise NotImplementedError

@cpython_api([PyFrameObject], PyObject)
def PyEval_EvalFrame(space, f):
    """Evaluate an execution frame.  This is a simplified interface to
    PyEval_EvalFrameEx, for backward compatibility."""
    raise NotImplementedError

@cpython_api([PyFrameObject, rffi.INT_real], PyObject)
def PyEval_EvalFrameEx(space, f, throwflag):
    """This is the main, unvarnished function of Python interpretation.  It is
    literally 2000 lines long.  The code object associated with the execution
    frame f is executed, interpreting bytecode and executing calls as needed.
    The additional throwflag parameter can mostly be ignored - if true, then
    it causes an exception to immediately be thrown; this is used for the
    throw() methods of generator objects."""
    raise NotImplementedError
