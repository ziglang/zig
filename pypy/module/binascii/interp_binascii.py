from pypy.interpreter.error import OperationError
from pypy.interpreter.gateway import Unwrapper

class Cache:
    def __init__(self, space):
        self.w_error = space.new_exception_class("binascii.Error",
                                                 space.w_ValueError)
        self.w_incomplete = space.new_exception_class("binascii.Incomplete")

def raise_Error(space, msg):
    w_error = space.fromcache(Cache).w_error
    raise OperationError(w_error, space.newtext(msg))

def raise_Incomplete(space, msg):
    w_error = space.fromcache(Cache).w_incomplete
    raise OperationError(w_error, space.newtext(msg))

# a2b functions accept bytes and buffers, but also ASCII strings.
class AsciiBufferUnwrapper(Unwrapper):
    def unwrap(self, space, w_value):
        if space.isinstance_w(w_value, space.w_unicode):
            w_value = space.call_method(w_value, "encode", space.newtext("ascii"))
        return space.charbuf_w(w_value)

