
from rpython.rtyper.rbytearray import AbstractByteArrayRepr
from rpython.rtyper.lltypesystem import lltype, rstr
from rpython.rtyper.debug import ll_assert

BYTEARRAY = lltype.GcForwardReference()

def mallocbytearray(size):
    return lltype.malloc(BYTEARRAY, size)

_, _, copy_bytearray_contents, _ = rstr._new_copy_contents_fun(BYTEARRAY, BYTEARRAY,
                                                         lltype.Char,
                                                         'bytearray')
_, _, copy_bytearray_contents_from_str, _ = rstr._new_copy_contents_fun(rstr.STR,
                                                                  BYTEARRAY,
                                                                  lltype.Char,
                                                                  'bytearray_from_str')

def _empty_bytearray():
    return empty

BYTEARRAY.become(lltype.GcStruct('rpy_bytearray',
                 ('chars', lltype.Array(lltype.Char)), adtmeths={
    'malloc' : lltype.staticAdtMethod(mallocbytearray),
    'copy_contents' : lltype.staticAdtMethod(copy_bytearray_contents),
    'copy_contents_from_str': lltype.staticAdtMethod(
                                         copy_bytearray_contents_from_str),
    'length': rstr.LLHelpers.ll_length,
    'empty': lltype.staticAdtMethod(_empty_bytearray),
}))

empty = lltype.malloc(BYTEARRAY, 0, immortal=True)

class LLHelpers(rstr.LLHelpers):
    @classmethod
    def ll_strsetitem(cls, s, i, item):
        if i < 0:
            i += s.length()
        cls.ll_strsetitem_nonneg(s, i, item)

    @staticmethod
    def ll_strsetitem_nonneg(s, i, item):
        chars = s.chars
        ll_assert(i >= 0, "negative str getitem index")
        ll_assert(i < len(chars), "str getitem index out of bound")
        chars[i] = chr(item)

    @staticmethod
    def ll_stritem_nonneg(s, i):
        return ord(rstr.LLHelpers.ll_stritem_nonneg(s, i))

class ByteArrayRepr(AbstractByteArrayRepr):
    lowleveltype = lltype.Ptr(BYTEARRAY)

    def __init__(self, *args):
        AbstractByteArrayRepr.__init__(self, *args)
        self.ll = LLHelpers
        self.repr = self

    def convert_const(self, value):
        if value is None:
            return lltype.nullptr(BYTEARRAY)
        p = lltype.malloc(BYTEARRAY, len(value))
        for i, c in enumerate(value):
            p.chars[i] = chr(c)
        return p

    def ll_str(self, ll_b):
        from rpython.rtyper.lltypesystem.rstr import mallocstr, STR
        if ll_b:
            lgt = ll_b.length()
            ll_s = mallocstr(lgt)
            for i in range(lgt):
                ll_s.chars[i] = ll_b.chars[i]
            return ll_s
        else:
            return lltype.nullptr(STR)

bytearray_repr = ByteArrayRepr()

def hlbytearray(ll_b):
    b = bytearray()
    for i in range(ll_b.length()):
        b.append(ll_b.chars[i])
    return b
