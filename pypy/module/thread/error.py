from pypy.interpreter.error import OperationError

def wrap_thread_error(space, msg):
    w_error = space.w_RuntimeError    # since CPython 3.3
    return OperationError(w_error, space.newtext(msg))
