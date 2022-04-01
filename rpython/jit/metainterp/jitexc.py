from rpython.rtyper.annlowlevel import cast_instance_to_base_ptr
from rpython.rtyper.annlowlevel import cast_base_ptr_to_instance
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper import rclass
from rpython.rtyper.llinterp import LLException
from rpython.rlib.objectmodel import we_are_translated
from rpython.jit.codewriter import longlong


class JitException(Exception):
    """The base class for exceptions raised and caught in the JIT.
    The point is that the places that catch any user exception should avoid
    catching exceptions that inherit from JitException.
    """
    _go_through_llinterp_uncaught_ = True     # ugh

class DoneWithThisFrameVoid(JitException):
    def __str__(self):
        return 'DoneWithThisFrameVoid()'

class DoneWithThisFrameInt(JitException):
    def __init__(self, result):
        assert lltype.typeOf(result) is lltype.Signed
        self.result = result

    def __str__(self):
        return 'DoneWithThisFrameInt(%s)' % (self.result,)

class DoneWithThisFrameRef(JitException):
    def __init__(self, result):
        assert lltype.typeOf(result) == llmemory.GCREF
        self.result = result

    def __str__(self):
        return 'DoneWithThisFrameRef(%s)' % (self.result,)

class DoneWithThisFrameFloat(JitException):
    def __init__(self, result):
        assert lltype.typeOf(result) is longlong.FLOATSTORAGE
        self.result = result

    def __str__(self):
        return 'DoneWithThisFrameFloat(%s)' % (self.result,)

class ExitFrameWithExceptionRef(JitException):
    def __init__(self, value):
        assert lltype.typeOf(value) == llmemory.GCREF
        self.value = value

    def __str__(self):
        return 'ExitFrameWithExceptionRef(%s)' % (self.value,)

class ContinueRunningNormally(JitException):
    def __init__(self, gi, gr, gf, ri, rr, rf):
        # the six arguments are: lists of green ints, greens refs,
        # green floats, red ints, red refs, and red floats.
        self.green_int = gi
        self.green_ref = gr
        self.green_float = gf
        self.red_int = ri
        self.red_ref = rr
        self.red_float = rf
    def __str__(self):
        return 'ContinueRunningNormally(%s, %s, %s, %s, %s, %s)' % (
            self.green_int, self.green_ref, self.green_float,
            self.red_int, self.red_ref, self.red_float)

class NotAVectorizeableLoop(JitException):
    def __str__(self):
        return 'NotAVectorizeableLoop()'

class NotAProfitableLoop(JitException):
    def __str__(self):
        return 'NotAProfitableLoop()'


def _get_standard_error(rtyper, Class):
    exdata = rtyper.exceptiondata
    clsdef = rtyper.annotator.bookkeeper.getuniqueclassdef(Class)
    evalue = exdata.get_standard_ll_exc_instance(rtyper, clsdef)
    return evalue

def get_llexception(cpu, e):
    if we_are_translated():
        return cast_instance_to_base_ptr(e)
    assert not isinstance(e, JitException)
    if isinstance(e, LLException):
        return e.args[1]    # ok
    if isinstance(e, OverflowError):
        return _get_standard_error(cpu.rtyper, OverflowError)
    raise   # leave other exceptions to be propagated

def reraise(lle):
    if we_are_translated():
        e = cast_base_ptr_to_instance(Exception, lle)
        raise e
    else:
        etype = rclass.ll_type(lle)
        raise LLException(etype, lle)
