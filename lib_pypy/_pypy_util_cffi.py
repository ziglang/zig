
from _pypy_util_cffi_inner import ffi, lib

class StackNew(object):
    def __init__(self, tp, size=None):
        if size is None:
            total_size = ffi.sizeof(tp)
        else:
            if tp.endswith("[]"):
                total_size = ffi.sizeof(tp[:-2] + "[1]") * size
            else:
                total_size = ffi.sizeof(tp) * size                
        if tp.endswith("[]"):
            tp = tp[:-2] + "*" # XXX dodgu?
        self._p = ffi.cast(tp, lib.malloc(total_size))

    def __enter__(self):
        return self._p

    def __exit__(self, tp, val, tb):
        lib.free(ffi.cast("void*", self._p))
