from __future__ import with_statement

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef

from rpython.rtyper.lltypesystem import rffi
from rpython.rlib.rdynload import DLLHANDLE, dlsym, dlclose

from pypy.module._cffi_backend.cdataobj import W_CData
from pypy.module._cffi_backend.ctypeobj import W_CType
from pypy.module._cffi_backend import misc


class W_Library(W_Root):
    _immutable_ = True

    def __init__(self, space, w_filename, flags):
        self.space = space
        self.name, self.handle, autoclose = (
            misc.dlopen_w(space, w_filename, flags))
        if autoclose:
            self.register_finalizer(space)

    def _finalize_(self):
        h = self.handle
        if h != rffi.cast(DLLHANDLE, 0):
            self.handle = rffi.cast(DLLHANDLE, 0)
            dlclose(h)

    def repr(self):
        space = self.space
        return space.newtext("<clibrary '%s'>" % self.name)

    def check_closed(self):
        if self.handle == rffi.cast(DLLHANDLE, 0):
            raise oefmt(self.space.w_ValueError,
                        "library '%s' has already been closed",
                        self.name)

    @unwrap_spec(w_ctype=W_CType, name='text')
    def load_function(self, w_ctype, name):
        from pypy.module._cffi_backend import ctypeptr, ctypearray
        self.check_closed()
        space = self.space
        #
        if not isinstance(w_ctype, ctypeptr.W_CTypePtrOrArray):
            raise oefmt(space.w_TypeError,
                        "function or pointer or array cdata expected, got '%s'",
                        w_ctype.name)
        #
        try:
            cdata = dlsym(self.handle, name)
        except KeyError:
            raise oefmt(space.w_AttributeError,
                        "function/symbol '%s' not found in library '%s'",
                        name, self.name)
        if isinstance(w_ctype, ctypearray.W_CTypeArray) and w_ctype.length < 0:
            w_ctype = w_ctype.ctptr
        return W_CData(space, rffi.cast(rffi.CCHARP, cdata), w_ctype)

    @unwrap_spec(w_ctype=W_CType, name='text')
    def read_variable(self, w_ctype, name):
        self.check_closed()
        space = self.space
        try:
            cdata = dlsym(self.handle, name)
        except KeyError:
            raise oefmt(space.w_KeyError,
                        "variable '%s' not found in library '%s'",
                        name, self.name)
        return w_ctype.convert_to_object(rffi.cast(rffi.CCHARP, cdata))

    @unwrap_spec(w_ctype=W_CType, name='text')
    def write_variable(self, w_ctype, name, w_value):
        self.check_closed()
        space = self.space
        try:
            cdata = dlsym(self.handle, name)
        except KeyError:
            raise oefmt(space.w_KeyError,
                        "variable '%s' not found in library '%s'",
                        name, self.name)
        w_ctype.convert_from_object(rffi.cast(rffi.CCHARP, cdata), w_value)

    def close_lib(self):
        self._finalize_()


W_Library.typedef = TypeDef(
    '_cffi_backend.CLibrary',
    __repr__ = interp2app(W_Library.repr),
    load_function = interp2app(W_Library.load_function),
    read_variable = interp2app(W_Library.read_variable),
    write_variable = interp2app(W_Library.write_variable),
    close_lib = interp2app(W_Library.close_lib),
    )
W_Library.typedef.acceptable_as_base_class = False


@unwrap_spec(flags=int)
def load_library(space, w_filename, flags=0):
    lib = W_Library(space, w_filename, flags)
    return lib
