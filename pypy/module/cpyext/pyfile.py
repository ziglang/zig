from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import widen
from pypy.module.cpyext.api import (
    cpython_api, CONST_STRING, FILEP)
from pypy.module.cpyext.pyobject import PyObject
from pypy.module.cpyext.object import Py_PRINT_RAW
from pypy.module._io import interp_io
from pypy.interpreter.error import OperationError, oefmt

@cpython_api([PyObject, rffi.INT_real], PyObject)
def PyFile_GetLine(space, w_obj, n):
    """
    Equivalent to p.readline([n]), this function reads one line from the
    object p.  p may be a file object or any object with a readline()
    method.  If n is 0, exactly one line is read, regardless of the length of
    the line.  If n is greater than 0, no more than n bytes will be read
    from the file; a partial line can be returned.  In both cases, an empty string
    is returned if the end of the file is reached immediately.  If n is less than
    0, however, one line is read regardless of length, but EOFError is
    raised if the end of the file is reached immediately."""
    try:
        w_readline = space.getattr(w_obj, space.newtext('readline'))
    except OperationError:
        raise oefmt(space.w_TypeError,
            "argument must be a file, or have a readline() method.")

    n = rffi.cast(lltype.Signed, n)
    if space.is_true(space.gt(space.newint(n), space.newint(0))):
        return space.call_function(w_readline, space.newint(n))
    elif space.is_true(space.lt(space.newint(n), space.newint(0))):
        return space.call_function(w_readline)
    else:
        # XXX Raise EOFError as specified
        return space.call_function(w_readline)

@cpython_api([CONST_STRING, CONST_STRING], PyObject)
def PyFile_FromString(space, filename, mode):
    """
    On success, return a new file object that is opened on the file given by
    filename, with a file mode given by mode, where mode has the same
    semantics as the standard C routine fopen().  On failure, return NULL."""
    w_filename = space.newbytes(rffi.charp2str(filename))
    w_mode = space.newtext(rffi.charp2str(mode))
    return space.call_method(space.builtin, 'open', w_filename, w_mode)

@cpython_api([rffi.INT_real, CONST_STRING, CONST_STRING, rffi.INT_real, CONST_STRING, CONST_STRING, CONST_STRING, rffi.INT_real], PyObject)
def PyFile_FromFd(space, fd, name, mode, buffering, encoding, errors, newline, closefd):
    """Create a Python file object from the file descriptor of an already
    opened file fd.  The arguments name, encoding, errors and newline
    can be NULL to use the defaults; buffering can be -1 to use the
    default. name is ignored and kept for backward compatibility. Return
    NULL on failure. For a more comprehensive description of the arguments,
    please refer to the io.open() function documentation.

    Since Python streams have their own buffering layer, mixing them with
    OS-level file descriptors can produce various issues (such as unexpected
    ordering of data).

    Ignore name attribute."""

    if not mode:
        raise oefmt(space.w_ValueError, "mode is required")
    mode = rffi.charp2str(mode)
    if encoding:
        encoding_ = rffi.charp2str(encoding)
    else:
        encoding_ = None
    if errors:
        errors_ = rffi.charp2str(errors)
    else:
        errors_ = None
    if newline:
        newline_ = rffi.charp2str(newline)
    else:
        newline_ = None
    w_ret = interp_io.open(space, space.newint(fd), mode, widen(buffering),
                           encoding_, errors_, newline_, widen(closefd))
    return w_ret

@cpython_api([CONST_STRING, PyObject], rffi.INT_real, error=-1)
def PyFile_WriteString(space, s, w_p):
    """Write string s to file object p.  Return 0 on success or -1 on
    failure; the appropriate exception will be set."""
    w_str = space.newtext(rffi.charp2str(s))
    space.call_method(w_p, "write", w_str)
    return 0

@cpython_api([PyObject, PyObject, rffi.INT_real], rffi.INT_real, error=-1)
def PyFile_WriteObject(space, w_obj, w_p, flags):
    """
    Write object obj to file object p.  The only supported flag for flags is
    Py_PRINT_RAW; if given, the str() of the object is written
    instead of the repr().  Return 0 on success or -1 on failure; the
    appropriate exception will be set."""
    if rffi.cast(lltype.Signed, flags) & Py_PRINT_RAW:
        w_str = space.str(w_obj)
    else:
        w_str = space.repr(w_obj)
    space.call_method(w_p, "write", w_str)
    return 0

@cpython_api([PyObject], PyObject)
def PyOS_FSPath(space, w_path):
    """
    Return the file system representation for path. If the object is a str or
    bytes object, then its reference count is incremented. If the object
    implements the os.PathLike interface, then __fspath__() is returned as long
    as it is a str or bytes object. Otherwise TypeError is raised and NULL is
    returned.
    """
    if (space.isinstance_w(w_path, space.w_unicode) or
        space.isinstance_w(w_path, space.w_bytes)):
        return w_path
    if not space.lookup(w_path, '__fspath__'):
        raise oefmt(space.w_TypeError,
                "expected str, bytes or os.PathLike object, not %T", w_path)
    w_ret = space.call_method(w_path, '__fspath__')
    if (space.isinstance_w(w_ret, space.w_unicode) or
        space.isinstance_w(w_ret, space.w_bytes)):
        return w_ret
    raise oefmt(space.w_TypeError,
                "expected %T.__fspath__() to return str or bytes, not %T", w_path, w_ret)

