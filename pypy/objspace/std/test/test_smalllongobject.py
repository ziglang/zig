import pytest
import sys
from pypy.objspace.std.smalllongobject import W_SmallLongObject
from pypy.objspace.std.test import test_longobject
from pypy.objspace.std.test.test_intobject import AppTestInt, TestW_IntObject
from pypy.tool.pytest.objspace import gettestobjspace
from rpython.rlib.rarithmetic import r_longlong
from pypy.interpreter.error import OperationError


def test_direct():
    space = gettestobjspace(**{"objspace.std.withsmalllong": True})
    w5 = space.wrap(r_longlong(5))
    assert isinstance(w5, W_SmallLongObject)
    wlarge = space.wrap(r_longlong(0x123456789ABCDEFL))
    #
    assert space.int_w(w5) == 5
    if sys.maxint < 0x123456789ABCDEFL:
        with pytest.raises(OperationError):
            space.int_w(wlarge)
    else:
        assert space.int_w(wlarge) == 0x123456789ABCDEF
    #
    assert space.pos(w5) is w5
    assert space.abs(w5) is w5
    wm5 = space.wrap(r_longlong(-5))
    assert space.int_w(space.abs(wm5)) == 5
    assert space.int_w(space.neg(w5)) == -5
    assert space.is_true(w5) is True
    assert space.is_true(wm5) is True
    w0 = space.wrap(r_longlong(0))
    assert space.is_true(w0) is False
    #
    w14000000000000 = space.wrap(r_longlong(0x14000000000000L))
    assert space.is_true(space.eq(
        space.lshift(w5, space.wrap(49)), w14000000000000)) is False
    assert space.is_true(space.eq(
        space.lshift(w5, space.wrap(50)), w14000000000000)) is True
    #
    w_huge = space.sub(space.lshift(w5, space.wrap(150)), space.wrap(1))
    wx = space.and_(w14000000000000, w_huge)
    assert space.is_true(space.eq(wx, w14000000000000))

    w_obj = W_SmallLongObject.fromint(42)
    assert space.unwrap(w_obj) == 42


@pytest.mark.skipif('config.option.runappdirect')
class AppTestSmallLong(test_longobject.AppTestLong):
    spaceconfig = {"objspace.std.withsmalllong": True}

    def setup_class(cls):
        from pypy.interpreter import gateway
        def w__long(space, w_obj):
            assert space.config.objspace.std.withsmalllong
            b = space.bigint_w(w_obj)
            return space.wraplong(b.tolong())
        cls.w__long = cls.space.wrap(gateway.interp2app(w__long))

    def test_sl_simple(self):
        import __pypy__
        s = __pypy__.internal_repr(self._long(5))
        assert 'SmallLong' in s

    def test_sl_hash(self):
        import __pypy__
        x = self._long(5)
        assert 'SmallLong' in __pypy__.internal_repr(x)
        assert hash(5) == hash(x)
        biglong = self._long(5)
        biglong ^= 2**100      # hack based on the fact that xor__Long_Long
        biglong ^= 2**100      # does not call newlong()
        assert biglong == 5
        assert 'SmallLong' not in __pypy__.internal_repr(biglong)
        assert hash(5) == hash(biglong)
        #
        x = self._long(0x123456789ABCDEF)
        assert 'SmallLong' in __pypy__.internal_repr(x)
        biglong = x
        biglong ^= 2**100
        biglong ^= 2**100
        assert biglong == x
        assert 'SmallLong' not in __pypy__.internal_repr(biglong)
        assert hash(biglong) == hash(x)

    def test_sl_int(self):
        x = self._long(0x123456789ABCDEF)
        two = 2
        assert int(x) == x
        assert type(int(x)) == type(0x1234567 ** two)
        y = x >> 32
        assert int(y) == y
        assert type(int(y)) is int

    def test_sl_long(self):
        import __pypy__
        x = self._long(0)
        assert 'SmallLong' in __pypy__.internal_repr(x)

    def test_sl_add(self):
        import __pypy__
        x = self._long(0x123456789ABCDEF)
        assert x + x == 0x2468ACF13579BDE
        assert 'SmallLong' in __pypy__.internal_repr(x + x)
        x = self._long(-0x123456789ABCDEF)
        assert x + x == -0x2468ACF13579BDE
        assert 'SmallLong' in __pypy__.internal_repr(x + x)
        x = self._long(0x723456789ABCDEF0)
        assert x + x == 0xE468ACF13579BDE0
        assert 'SmallLong' not in __pypy__.internal_repr(x + x)
        x = self._long(-0x723456789ABCDEF0)
        assert x + x == -0xE468ACF13579BDE0
        assert 'SmallLong' not in __pypy__.internal_repr(x + x)

    def test_sl_add_32(self):
        import sys, __pypy__
        if sys.maxsize == 2147483647:
            x = 2147483647
            assert x + x == 4294967294
            assert 'SmallLong' in __pypy__.internal_repr(x + x)
            y = -1
            assert x - y == 2147483648
            assert 'SmallLong' in __pypy__.internal_repr(x - y)

    def test_sl_lshift(self):
        for x in [1, self._long(1)]:
            x = 1
            assert x << 1 == 2
            assert x << 30 == 1073741824
            assert x << 31 == 2147483648
            assert x << 32 == 4294967296
            assert x << 62 == 4611686018427387904
            assert x << 63 == 9223372036854775808
            assert x << 64 == 18446744073709551616
            assert (x << 31) << 31 == 4611686018427387904
            assert (x << 32) << 32 == 18446744073709551616


class TestW_IntObjectWithSmallLong(TestW_IntObject):
    spaceconfig = {"objspace.std.withsmalllong": True}


class AppTestIntWithSmallLong(AppTestInt):
    spaceconfig = {"objspace.std.withsmalllong": True}
