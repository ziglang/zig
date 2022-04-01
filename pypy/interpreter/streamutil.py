from rpython.rlib.streamio import StreamError
from pypy.interpreter.error import OperationError, wrap_oserror2

def wrap_streamerror(space, e, w_filename=None):
    if isinstance(e, StreamError):
        return OperationError(space.w_ValueError,
                              space.newtext(e.message))
    elif isinstance(e, OSError):
        return wrap_oserror_as_ioerror(space, e, w_filename)
    else:
        # should not happen: wrap_streamerror() is only called when
        # StreamErrors = (OSError, StreamError) are raised
        return OperationError(space.w_IOError, space.w_None)

def wrap_oserror_as_ioerror(space, e, w_filename=None):
    return wrap_oserror2(space, e, w_filename,
                         w_exception_class=space.w_IOError)
