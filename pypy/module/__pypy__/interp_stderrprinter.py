import errno, os

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import wrap_oserror
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import GetSetProperty, TypeDef


class W_StdErrPrinter(W_Root):
    @staticmethod
    @unwrap_spec(fd='c_int')
    def descr_new(space, w_subtype, fd):
        return W_StdErrPrinter(fd)

    def __init__(self, fd):
        self.fd = fd

    def descr_repr(self, space):
        addrstring = self.getaddrstring(space)
        return space.newtext("<StdErrPrinter(fd=%d) object at 0x%s>" %
                                (self.fd, addrstring))

    def descr_noop(self, space):
        pass

    def descr_fileno(self, space):
        return space.newint(self.fd)

    def descr_isatty(self, space):
        try:
            res = os.isatty(self.fd)
        except OSError as e:
            raise wrap_oserror(space, e)
        return space.newbool(res)

    def descr_write(self, space, w_data):
        # Encode to UTF-8-nosg.
        data = space.text_w(w_data)

        try:
            n = os.write(self.fd, data)
        except OSError as e:
            if e.errno == errno.EAGAIN:
                return space.w_None
            raise wrap_oserror(space, e)
        return space.newint(n)

    def descr_get_closed(self, space):
        return space.newbool(False)

    def descr_get_encoding(self, space):
        return space.w_None

    def descr_get_mode(self, space):
        return space.newtext('w')


W_StdErrPrinter.typedef = TypeDef("StdErrPrinter",
    __new__ = interp2app(W_StdErrPrinter.descr_new),
    __repr__ = interp2app(W_StdErrPrinter.descr_repr),
    close = interp2app(W_StdErrPrinter.descr_noop),
    flush = interp2app(W_StdErrPrinter.descr_noop),
    fileno = interp2app(W_StdErrPrinter.descr_fileno),
    isatty = interp2app(W_StdErrPrinter.descr_isatty),
    write = interp2app(W_StdErrPrinter.descr_write),

    closed = GetSetProperty(W_StdErrPrinter.descr_get_closed),
    encoding = GetSetProperty(W_StdErrPrinter.descr_get_encoding),
    mode = GetSetProperty(W_StdErrPrinter.descr_get_mode),
)
