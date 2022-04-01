from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem.rstr import STR, mallocstr
from rpython.rtyper.annlowlevel import llstr, hlstr
from rpython.rlib.objectmodel import specialize
from rpython.rlib.buffer import GCBuffer
from rpython.rlib import jit

@GCBuffer.decorate
class MutableStringBuffer(GCBuffer):
    """
    A writeable buffer to incrementally fill a string of a fixed size.

    You can fill the string by calling setitem, setslice and typed_write, and
    get the result by calling finish().

    After you call finish(), you can no longer modify the buffer. There is no
    check, you will probably get a segfault after translation.

    You can call finish() only once.
    """
    _attrs_ = ['readonly', 'll_val', 'size']
    _immutable_ = True

    def __init__(self, size):
        self.readonly = False
        self.size = size
        self.ll_val = mallocstr(size)

    def getlength(self):
        return self.size

    def finish(self):
        if not self.ll_val:
            raise ValueError("Cannot call finish() twice")
        result = hlstr(self.ll_val)
        self.ll_val = lltype.nullptr(STR)
        self.readonly = True
        return result

    def as_str(self):
        raise ValueError('as_str() is not supported. Use finish() instead')

    def _hlstr(self):
        assert not we_are_translated() # debug only
        return hlstr(self.ll_val)

    def setitem(self, index, char):
        self.ll_val.chars[index] = char

    @staticmethod
    def _get_gc_data_offset():
        return (llmemory.offsetof(STR, 'chars') +
                llmemory.itemoffsetof(STR.chars, 0))

    def _get_gc_data(self):
        return lltype.cast_opaque_ptr(llmemory.GCREF, self.ll_val)
