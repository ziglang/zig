import py
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.jit import JitDriver, dont_look_inside

class TestByteArray(LLJitMixin):

    def test_getitem(self):
        x = bytearray("foobar")
        def fn(n):
            assert n >= 0
            return x[n]
        res = self.interp_operations(fn, [3])
        assert res == ord('b')

    def test_getitem_negative(self):
        x = bytearray("foobar")
        def fn(n):
            return x[n]
        res = self.interp_operations(fn, [-2])
        assert res == ord('a')

    def test_len(self):
        x = bytearray("foobar")
        def fn(n):
            return len(x)
        res = self.interp_operations(fn, [3])
        assert res == 6

    def test_setitem(self):
        @dont_look_inside
        def make_me():
            return bytearray("foobar")
        def fn(n):
            assert n >= 0
            x = make_me()
            x[n] = 3
            return x[3] + 1000 * x[4]

        res = self.interp_operations(fn, [3])
        assert res == 3 + 1000 * ord('a')

    def test_setitem_negative(self):
        @dont_look_inside
        def make_me():
            return bytearray("foobar")
        def fn(n):
            x = make_me()
            x[n] = 3
            return x[3] + 1000 * x[4]

        res = self.interp_operations(fn, [-2])
        assert res == ord('b') + 1000 * 3

    def test_new_bytearray(self):
        def fn(n, m):
            x = bytearray(str(n))
            x[m] = 0x34
            return int(str(x))

        assert fn(610978, 3) == 610478
        res = self.interp_operations(fn, [610978, 3])
        assert res == 610478

    def test_slice(self):
        py.test.skip("XXX later")
        def fn(n, m):
            x = bytearray(str(n))
            x = x[1:5]
            x[m] = 0x35
            return int(str(x))
        res = self.interp_operations(fn, [610978, 1])
        assert res == 1597

    def test_bytearray_from_bytearray(self):
        def fn(n, m):
            x = bytearray(str(n))
            y = bytearray(x)
            x[m] = 0x34
            return int(str(x)) + int(str(y))

        res = self.interp_operations(fn, [610978, 3])
        assert res == 610478 + 610978
