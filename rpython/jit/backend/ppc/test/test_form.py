from py.test import raises

from rpython.jit.backend.ppc.form import Form, FormException
from rpython.jit.backend.ppc.field import Field
from rpython.jit.backend.ppc.opassembler import OpAssembler as Assembler

# 0                              31
# +-------------------------------+
# |       h       |       l       |
# +-------------------------------+
# |  hh   |  hl   |  lh   |  ll   |
# +-------------------------------+

test_fieldmap = {
    'l' : Field('l',  16, 31),
    'h' : Field('h',   0, 15),
    'll': Field('ll', 24, 31),
    'lh': Field('lh', 16, 23),
    'hl': Field('hl',  8, 15),
    'hh': Field('hh',  0,  7),
}

def p(a):
    import struct
    w = a.insts[-1].assemble()
    return struct.pack('>i', w)

class TForm(Form):
    fieldmap = test_fieldmap

class TestForms(object):
    def test_bitclash(self):
        raises(FormException, TForm, 'h', 'hh')
        raises(FormException, TForm,
               Field('t1', 0, 0), Field('t2', 0, 0))

    def test_basic(self):
        class T(Assembler):
            i = TForm('h', 'l')()
            j = i(h=1)
            k = i(l=3)
            raises(FormException, k, l=0)
            insts = []
        a = T()
        a.i(5, 6)
        assert p(a) == '\000\005\000\006'
        a = T()
        a.j(2)
        assert p(a) == '\000\001\000\002'
        a = T()
        a.k(4)
        assert p(a) == '\000\004\000\003'

    def test_defdesc(self):
        class T(Assembler):
            i = TForm('hh', 'hl', 'lh', 'll')()
            i.default(hl=0).default(hh=1)
            insts = []
        a = T()
        a.i(1, 2, 3, 4)
        assert p(a) == '\001\002\003\004'
        a = T()
        a.i(1, 3, 4)
        assert p(a) == '\001\000\003\004'
        a = T()
        a.i(3, 4)
        assert p(a) == '\001\000\003\004'
