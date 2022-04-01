
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.lltypesystem.rbytearray import hlbytearray
from rpython.rtyper.annlowlevel import llstr, hlstr

class TestByteArray(BaseRtypingTest):
    def test_bytearray_creation(self):
        def f(x):
            if x:
                b = bytearray(str(x))
            else:
                b = bytearray("def")
            return b
        ll_res = self.interpret(f, [0])
        assert hlbytearray(ll_res) == "def"
        ll_res = self.interpret(f, [1])
        assert hlbytearray(ll_res) == "1"

    def test_addition(self):
        def f(x):
            return bytearray("a") + hlstr(x)

        ll_res = self.interpret(f, [llstr("def")])
        assert hlbytearray(ll_res) == "adef"

        def f2(x):
            return hlstr(x) + bytearray("a")

        ll_res = self.interpret(f2, [llstr("def")])
        assert hlbytearray(ll_res) == "defa"

        def f3(x):
            return bytearray(hlstr(x)) + bytearray("a")

        ll_res = self.interpret(f3, [llstr("def")])
        assert hlbytearray(ll_res) == "defa"

    def test_getitem_setitem(self):
        def f(s, i, c):
            b = bytearray(hlstr(s))
            b[i] = c
            return b[i] + b[i + 1] * 255

        ll_res = self.interpret(f, [llstr("abc"), 1, ord('d')])
        assert ll_res == ord('d') + ord('c') * 255

    def test_str_of_bytearray(self):
        def f(x):
            return str(bytearray(str(x)))

        ll_res = self.interpret(f, [123])
        assert hlstr(ll_res) == "123"

    def test_getslice(self):
        def f(x):
            b = bytearray(str(x))
            b = b[1:3]
            b[0] += 5
            return str(b)

        ll_res = self.interpret(f, [12345])
        assert hlstr(ll_res) == f(12345) == "73"

    def test_bytearray_not_constant(self):
        for constant in ['f', 'foo']:
            def f(x):
                i = 0
                total = 0
                while i < x:
                    b = bytearray(constant)
                    b[0] = b[0] + 1
                    total += b[0]
                    i += 1
                return total
            ll_res = self.interpret(f, [5])
            assert ll_res == f(5)
