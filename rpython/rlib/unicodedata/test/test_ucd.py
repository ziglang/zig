import pytest
from rpython.rlib.runicode import code_to_unichr, MAXUNICODE
from rpython.rlib.unicodedata import unicodedb_5_2_0, unicodedb_11_0_0
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.translator.c.test.test_genc import compile


class TestTranslated(BaseRtypingTest):
    def test_translated(self):
        def f(n):
            if n == 0:
                return -1
            else:
                u = unicodedb_5_2_0.lookup("GOTHIC LETTER FAIHU")
                return u
        res = self.interpret(f, [1])
        print hex(res)
        assert res == f(1)


def test_code_to_unichr():
    def f(c):
        return ord(code_to_unichr(c)[0])
    f1 = compile(f, [int])
    got = f1(0x12346)
    if MAXUNICODE == 65535:
        assert got == 0xd808    # first char of a pair
    else:
        assert got == 0x12346

def test_cjk():
    cases = [
        ('3400', '4DB5'),
        ('4E00', '9FEF'),
        ('20000', '2A6D6'),
        ('2A700', '2B734'),
        ('2B740', '2B81D'),
        ('2B820', '2CEA1'),
    ]
    for first, last in cases:
        first = int(first, 16)
        last = int(last, 16)
        # Test at and inside the boundary
        for i in (first, first + 1, last - 1, last):
            charname = 'CJK UNIFIED IDEOGRAPH-%X'%i
            assert unicodedb_11_0_0.lookup(charname) == i
        # Test outside the boundary
        for i in first - 1, last + 1:
            charname = 'CJK UNIFIED IDEOGRAPH-%X'%i
            with pytest.raises(KeyError):
                unicodedb_11_0_0.lookup(charname)

