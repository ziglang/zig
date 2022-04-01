from pypy.interpreter.error import oefmt
from pypy.interpreter.astcompiler import consts
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rarithmetic import widen
from pypy.module.cpyext.api import (
    cpython_api, CANNOT_FAIL, CONST_STRING, FILEP, fread, feof, Py_ssize_tP,
    cpython_struct, ferror)
from pypy.module.cpyext.pyobject import PyObject
from pypy.module.cpyext.pyerrors import PyErr_SetFromErrno
from pypy.module.cpyext.frameobject import PyFrameObject
from pypy.module.__builtin__ import compiling

PyCompilerFlags = cpython_struct(
    "PyCompilerFlags", (("cf_flags", rffi.INT),
                        ("cf_feature_version", rffi.INT)))
PyCompilerFlagsPtr = lltype.Ptr(PyCompilerFlags)

PyCF_MASK = (consts.CO_FUTURE_DIVISION |
             consts.CO_FUTURE_ABSOLUTE_IMPORT |
             consts.CO_FUTURE_WITH_STATEMENT |
             consts.CO_FUTURE_PRINT_FUNCTION |
             consts.CO_FUTURE_UNICODE_LITERALS)

@cpython_api([PyObject, PyObject, PyObject], PyObject)
def PyEval_CallObjectWithKeywords(space, w_obj, w_arg, w_kwds):
    return space.call(w_obj, w_arg, w_kwds)

@cpython_api([], PyObject, result_borrowed=True)
def PyEval_GetBuiltins(space):
    """Return a dictionary of the builtins in the current execution
    frame, or the interpreter of the thread state if no frame is
    currently executing."""
    caller = space.getexecutioncontext().gettopframe_nohidden()
    if caller is not None:
        w_globals = caller.get_w_globals()
        w_builtins = space.getitem(w_globals, space.newtext('__builtins__'))
        if not space.isinstance_w(w_builtins, space.w_dict):
            w_builtins = w_builtins.getdict(space)
    else:
        w_builtins = space.builtin.getdict(space)
    return w_builtins      # borrowed ref in all cases

@cpython_api([], PyObject, error=CANNOT_FAIL, result_borrowed=True)
def PyEval_GetLocals(space):
    """Return a dictionary of the local variables in the current execution
    frame, or NULL if no frame is currently executing."""
    caller = space.getexecutioncontext().gettopframe_nohidden()
    if caller is None:
        return None
    return caller.getdictscope()    # borrowed ref

@cpython_api([], PyObject, error=CANNOT_FAIL, result_borrowed=True)
def PyEval_GetGlobals(space):
    """Return a dictionary of the global variables in the current execution
    frame, or NULL if no frame is currently executing."""
    caller = space.getexecutioncontext().gettopframe_nohidden()
    if caller is None:
        return None
    return caller.get_w_globals()    # borrowed ref

@cpython_api([], PyFrameObject, error=CANNOT_FAIL, result_borrowed=True)
def PyEval_GetFrame(space):
    caller = space.getexecutioncontext().gettopframe_nohidden()
    return caller    # borrowed ref, may be null

@cpython_api([PyObject, PyObject, PyObject], PyObject)
def PyEval_EvalCode(space, w_code, w_globals, w_locals):
    """This is a simplified interface to PyEval_EvalCodeEx(), with just
    the code object, and the dictionaries of global and local variables.
    The other arguments are set to NULL."""
    if w_globals is None:
        w_globals = space.w_None
    if w_locals is None:
        w_locals = space.w_None
    return compiling.eval(space, w_code, w_globals, w_locals)

@cpython_api([PyObject, PyObject], PyObject)
def PyObject_CallObject(space, w_obj, w_arg):
    """
    Call a callable Python object callable_object, with arguments given by the
    tuple args.  If no arguments are needed, then args may be NULL.  Returns
    the result of the call on success, or NULL on failure.  This is the equivalent
    of the Python expression apply(callable_object, args) or
    callable_object(*args)."""
    return space.call(w_obj, w_arg)

@cpython_api([PyObject], PyObject)
def _PyObject_CallNoArg(space, w_obj):
    return space.call_function(w_obj)

@cpython_api([PyObject, PyObject, PyObject], PyObject)
def PyObject_Call(space, w_obj, w_args, w_kw):
    """
    Call a callable Python object, with arguments given by the
    tuple args, and named arguments given by the dictionary kw. If no named
    arguments are needed, kw may be NULL. args must not be NULL, use an
    empty tuple if no arguments are needed. Returns the result of the call on
    success, or NULL on failure.  This is the equivalent of the Python expression
    apply(callable_object, args, kw) or callable_object(*args, **kw)."""
    return space.call(w_obj, w_args, w_kw)


@cpython_api([PyObject, PyObject, PyObject], PyObject)
def PyCFunction_Call(space, w_obj, w_args, w_kw):
    return space.call(w_obj, w_args, w_kw)

# These constants are also defined in include/eval.h
Py_single_input = 256
Py_file_input = 257
Py_eval_input = 258
Py_func_type_input = 345

def compile_string(space, source, filename, start, flags=0, feature_version=-1):
    w_source = space.newbytes(source)
    start = rffi.cast(lltype.Signed, start)
    if start == Py_file_input:
        mode = 'exec'
    elif start == Py_eval_input:
        mode = 'eval'
    elif start == Py_single_input:
        mode = 'single'
    elif start == Py_func_type_input:
        mode = 'func_type'
    else:
        raise oefmt(space.w_ValueError,
                    "invalid mode parameter for compilation")
    return compiling.compile(space, w_source, filename, mode, flags,
                             _feature_version=feature_version)

def run_string(space, source, filename, start, w_globals, w_locals):
    w_code = compile_string(space, source, filename, start)
    return compiling.eval(space, w_code, w_globals, w_locals)

@cpython_api([CONST_STRING], rffi.INT_real, error=-1)
def PyRun_SimpleString(space, command):
    """This is a simplified interface to PyRun_SimpleStringFlags() below,
    leaving the PyCompilerFlags* argument set to NULL."""
    command = rffi.charp2str(command)
    run_string(space, command, "<string>", Py_file_input,
               space.w_None, space.w_None)
    return 0

@cpython_api([CONST_STRING, rffi.INT_real,PyObject, PyObject], PyObject)
def PyRun_String(space, source, start, w_globals, w_locals):
    """This is a simplified interface to PyRun_StringFlags() below, leaving
    flags set to NULL."""
    source = rffi.charp2str(source)
    filename = "<string>"
    return run_string(space, source, filename, start, w_globals, w_locals)

@cpython_api([CONST_STRING, rffi.INT_real, PyObject, PyObject,
              PyCompilerFlagsPtr], PyObject)
def PyRun_StringFlags(space, source, start, w_globals, w_locals, flagsptr):
    """Execute Python source code from str in the context specified by the
    dictionaries globals and locals with the compiler flags specified by
    flags.  The parameter start specifies the start token that should be used to
    parse the source code.

    Returns the result of executing the code as a Python object, or NULL if an
    exception was raised."""
    source = rffi.charp2str(source)
    if flagsptr:
        flags = rffi.cast(lltype.Signed, flagsptr.c_cf_flags)
        feature_version = rffi.cast(lltype.Signed, flagsptr.c_cf_feature_version)
    else:
        flags = 0
        feature_version = -1
    w_code = compile_string(space, source, "<string>", start, flags=flags,
                            feature_version=feature_version)
    return compiling.eval(space, w_code, w_globals, w_locals)

@cpython_api([FILEP, CONST_STRING, rffi.INT_real, PyObject, PyObject], PyObject)
def PyRun_File(space, fp, filename, start, w_globals, w_locals):
    """This is a simplified interface to PyRun_FileExFlags() below, leaving
    closeit set to 0 and flags set to NULL."""
    BUF_SIZE = 8192
    source = ""
    filename = rffi.charp2str(filename)
    with rffi.scoped_alloc_buffer(BUF_SIZE) as buf:
        while True:
            try:
                count = fread(buf.raw, 1, BUF_SIZE, fp)
            except OSError:
                PyErr_SetFromErrno(space, space.w_IOError)
                return
            count = rffi.cast(lltype.Signed, count)
            source += rffi.charpsize2str(buf.raw, count)
            if count < BUF_SIZE:
                if ferror(fp):
                    PyErr_SetFromErrno(space, space.w_IOError)
                    return
                if feof(fp):
                    break
                PyErr_SetFromErrno(space, space.w_IOError)
    return run_string(space, source, filename, start, w_globals, w_locals)

# Undocumented function!
@cpython_api([PyObject, Py_ssize_tP], rffi.INT_real, error=0)
def _PyEval_SliceIndex(space, w_obj, pi):
    """Extract a slice index from a PyInt or PyLong or an object with the
    nb_index slot defined, and store in *pi.
    Silently reduce values larger than PY_SSIZE_T_MAX to PY_SSIZE_T_MAX,
    and silently boost values less than -PY_SSIZE_T_MAX-1 to -PY_SSIZE_T_MAX-1.

    Return 0 on error, 1 on success.

    Note:  If v is NULL, return success without storing into *pi.  This
    is because_PyEval_SliceIndex() is called by apply_slice(), which can be
    called by the SLICE opcode with v and/or w equal to NULL.
    """
    if w_obj is not None:
        pi[0] = space.getindex_w(w_obj, None)
    return 1

@cpython_api([CONST_STRING, CONST_STRING, rffi.INT_real, PyCompilerFlagsPtr],
             PyObject)
def Py_CompileStringFlags(space, source, filename, start, flagsptr):
    """Parse and compile the Python source code in str, returning the
    resulting code object.  The start token is given by start; this
    can be used to constrain the code which can be compiled and should
    be Py_eval_input, Py_file_input, or Py_single_input.  The filename
    specified by filename is used to construct the code object and may
    appear in tracebacks or SyntaxError exception messages.  This
    returns NULL if the code cannot be parsed or compiled."""
    source = rffi.charp2str(source)
    filename = rffi.charp2str(filename)
    if flagsptr:
        flags = rffi.cast(lltype.Signed, flagsptr.c_cf_flags)
    else:
        flags = 0
    return compile_string(space, source, filename, start, flags)

@cpython_api([PyCompilerFlagsPtr], rffi.INT_real, error=CANNOT_FAIL)
def PyEval_MergeCompilerFlags(space, cf):
    """This function changes the flags of the current evaluation
    frame, and returns true on success, false on failure."""
    flags = rffi.cast(lltype.Signed, cf.c_cf_flags)
    result = flags != 0
    current_frame = space.getexecutioncontext().gettopframe_nohidden()
    if current_frame:
        codeflags = current_frame.pycode.co_flags
        compilerflags = codeflags & PyCF_MASK
        if compilerflags:
            result = 1
            flags |= compilerflags
        # No future keyword at the moment
        # if codeflags & CO_GENERATOR_ALLOWED:
        #     result = 1
        #     flags |= CO_GENERATOR_ALLOWED
    cf.c_cf_flags = rffi.cast(rffi.INT, flags)
    return result

@cpython_api([], rffi.INT_real, error=CANNOT_FAIL)
def Py_GetRecursionLimit(space):
    from pypy.module.sys.vm import getrecursionlimit
    return space.int_w(getrecursionlimit(space))

@cpython_api([rffi.INT_real], lltype.Void, error=CANNOT_FAIL)
def Py_SetRecursionLimit(space, limit):
    from pypy.module.sys.vm import setrecursionlimit
    setrecursionlimit(space, widen(limit))

limit = 0 # for testing

@cpython_api([CONST_STRING], rffi.INT_real, error=1)
def Py_EnterRecursiveCall(space, where):
    """Marks a point where a recursive C-level call is about to be performed.

    If USE_STACKCHECK is defined, this function checks if the the OS
    stack overflowed using PyOS_CheckStack().  In this is the case, it
    sets a MemoryError and returns a nonzero value.

    The function then checks if the recursion limit is reached.  If this is the
    case, a RuntimeError is set and a nonzero value is returned.
    Otherwise, zero is returned.

    where should be a string such as " in instance check" to be
    concatenated to the RuntimeError message caused by the recursion depth
    limit."""
    if not we_are_translated():
        # XXX hack since the stack checks only work translated
        global limit
        limit += 1
        if limit > 10:
            raise oefmt(space.w_RecursionError,
                 "maximum recursion depth exceeded%s", rffi.charp2str(where))
        return 0
    from rpython.rlib.rstack import stack_almost_full
    if stack_almost_full():
        raise oefmt(space.w_RecursionError,
                 "maximum recursion depth exceeded%s", rffi.charp2str(where))
    return 0

@cpython_api([], lltype.Void)
def Py_LeaveRecursiveCall(space):
    """Ends a Py_EnterRecursiveCall().  Must be called once for each
    successful invocation of Py_EnterRecursiveCall()."""
    # A NOP in PyPy
    if not we_are_translated():
        limit = 0
