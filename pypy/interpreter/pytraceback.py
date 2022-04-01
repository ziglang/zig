import sys

from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter import baseobjspace
from pypy.interpreter.error import oefmt, OperationError

# for some strange reason CPython allows the setting of the lineno to be
# negative. I am not sure why that is useful, but let's use the most negative
# value as a sentinel to denote the default behaviour "please take the lineno
# from the frame and lasti"
LINENO_NOT_COMPUTED = -sys.maxint-1

def offset2lineno(c, stopat):
    # even position in lnotab denote byte increments, odd line increments.
    # see dis.findlinestarts in the python std. library for more details

    tab = c.co_lnotab
    line = c.co_firstlineno
    addr = 0
    for i in range(0, len(tab), 2):
        addr = addr + ord(tab[i])
        if addr > stopat:
            break
        line_offset = ord(tab[i+1])
        # new in Python 3.6: support for negative line offsets by using a
        # signed char interpretation for the line offsets
        if line_offset > 0x80:
            line_offset -= 0x100
        line = line + line_offset
    return line

class PyTraceback(baseobjspace.W_Root):
    """Traceback object

    Public app-level fields:
     * 'tb_frame'
     * 'tb_lasti'
     * 'tb_lineno'
     * 'tb_next'
    """

    def __init__(self, space, frame, lasti, next, lineno=LINENO_NOT_COMPUTED):
        self.space = space
        self.frame = frame
        self.lasti = lasti
        self.next = next
        self.lineno = lineno

    def get_lineno(self):
        if self.lineno == LINENO_NOT_COMPUTED:
            self.lineno = offset2lineno(self.frame.pycode, self.lasti)
        return self.lineno

    def descr_get_tb_lineno(self, space):
        return space.newint(self.get_lineno())

    def descr_set_tb_lineno(self, space, w_lineno):
        self.lineno = space.int_w(w_lineno)

    def descr_get_tb_lasti(self, space):
        return space.newint(self.lasti)

    def descr_set_tb_lasti(self, space, w_lasti):
        self.lasti = space.int_w(w_lasti)

    def descr_get_next(self, space):
        return self.next

    def descr_set_next(self, space, w_next):
        newnext = space.interp_w(PyTraceback, w_next, can_be_None=True)
        # check for loops
        curr = newnext
        while curr is not None and isinstance(curr, PyTraceback):
            if curr is self:
                raise oefmt(space.w_ValueError, 'traceback loop detected')
            curr = curr.next
        self.next = newnext

    @staticmethod
    @unwrap_spec(lasti=int, lineno=int)
    def descr_new(space, w_subtype, w_next, w_frame, lasti, lineno):
        from pypy.interpreter.pyframe import PyFrame
        w_next = space.interp_w(PyTraceback, w_next, can_be_None=True)
        w_frame = space.interp_w(PyFrame, w_frame)
        traceback = space.allocate_instance(PyTraceback, w_subtype)
        PyTraceback.__init__(traceback, space, w_frame, lasti, w_next, lineno)
        return traceback

    def descr__reduce__(self, space):
        from pypy.interpreter.mixedmodule import MixedModule
        w_mod = space.getbuiltinmodule('_pickle_support')
        mod = space.interp_w(MixedModule, w_mod)
        new_inst = mod.get('traceback_new')

        tup_base = []
        tup_state = [
            self.frame,
            space.newint(self.lasti),
            self.next,
            space.newint(self.lineno)
        ]
        nt = space.newtuple
        return nt([new_inst, nt(tup_base), nt(tup_state)])

    def descr__setstate__(self, space, w_args):
        from pypy.interpreter.pyframe import PyFrame
        args_w = space.unpackiterable(w_args, 4)
        w_frame, w_lasti, w_next, w_lineno = args_w
        self.frame = space.interp_w(PyFrame, w_frame)
        self.lasti = space.int_w(w_lasti)
        self.next = space.interp_w(PyTraceback, w_next, can_be_None=True)
        self.lineno = space.int_w(w_lineno)

    def descr__dir__(self, space):
        return space.newlist([space.newtext(n) for n in
            ['tb_frame', 'tb_next', 'tb_lasti', 'tb_lineno']])


def record_application_traceback(space, operror, frame, last_instruction):
    if frame.pycode.hidden_applevel:
        return
    tb = operror.get_traceback()
    tb = PyTraceback(space, frame, last_instruction, tb)
    operror.set_traceback(tb)


def check_traceback(space, w_tb, msg):
    if w_tb is None or not space.isinstance_w(w_tb, space.gettypeobject(PyTraceback.typedef)):
        raise OperationError(space.w_TypeError, space.newtext(msg))
    return w_tb
