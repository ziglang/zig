"""
Void.
"""

from pypy.module._cffi_backend.ctypeobj import W_CType


class W_CTypeVoid(W_CType):
    _attrs_ = []
    kind = "void"

    def __init__(self, space):
        W_CType.__init__(self, space, -1, "void", len("void"))

    def copy_and_convert_to_object(self, source):
        return self.space.w_None
