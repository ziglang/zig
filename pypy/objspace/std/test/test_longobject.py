# -*- encoding: utf-8 -*-
import py
from pypy.objspace.std import longobject as lobj
from rpython.rlib.rbigint import rbigint

class TestW_LongObject:
    def test_bigint_w(self):
        space = self.space
        fromlong = lobj.W_LongObject.fromlong
        assert isinstance(space.bigint_w(fromlong(42)), rbigint)
        assert space.bigint_w(fromlong(42)).eq(rbigint.fromint(42))
        assert space.bigint_w(fromlong(-1)).eq(rbigint.fromint(-1))
        w_obj = space.wrap("hello world")
        space.raises_w(space.w_TypeError, space.bigint_w, w_obj)
        w_obj = space.wrap(123.456)
        space.raises_w(space.w_TypeError, space.bigint_w, w_obj)

        w_obj = fromlong(42)
        assert space.unwrap(w_obj) == 42

    def test_overflow_error(self):
        space = self.space
        fromlong = lobj.W_LongObject.fromlong
        w_big = fromlong(10**900)
        space.raises_w(space.w_OverflowError, space.float_w, w_big)

    def test_rint_variants(self):
        from rpython.rtyper.tool.rfficache import platform
        space = self.space
        for r in platform.numbertype_to_rclass.values():
            if r is int:
                continue
            print r
            values = [0, -1, r.MASK>>1, -(r.MASK>>1)-1]
            for x in values:
                if not r.SIGNED:
                    x &= r.MASK
                w_obj = space.newlong_from_rarith_int(r(x))
                assert space.bigint_w(w_obj).eq(rbigint.fromlong(x))

    def test_int_mod_gives_int(self):
        space = self.space
        fromlong = lobj.W_LongObject.fromlong
        x = fromlong(13)
        y = space.newint(2)
        z = space.mod(x, y)
        assert space.eq_w(z, space.newint(1))
        assert not isinstance(z, lobj.W_LongObject)

class AppTestLong:

    def w__long(self, obj):
        # XXX: currently returns a W_LongObject but might return
        # W_IntObject in the future
        huge = 1 << 65
        return obj + huge - huge

    def test_trunc(self):
        import math
        assert math.trunc(self._long(1)) == self._long(1)
        assert math.trunc(-self._long(1)) == -self._long(1)

    def test_add(self):
        x = self._long(123)
        assert int(x + self._long(12443)) == 123 + 12443
        x = -20
        assert x + 2 + self._long(3) + True == -self._long(14)

    def test_sub(self):
        assert int(self._long(58543) - self._long(12332)) == 58543 - 12332
        assert int(self._long(58543) - 12332) == 58543 - 12332
        assert int(58543 - self._long(12332)) == 58543 - 12332
        x = self._long(237123838281233)
        assert x * 12 == x * self._long(12)

    def test_mul(self):
        x = self._long(363)
        assert x * 2 ** 40 == x << 40

    def test_truediv(self):
        a = self._long(31415926) / self._long(10000000)
        assert a == 3.1415926

    def test_floordiv(self):
        x = self._long(31415926)
        a = x // self._long(10000000)
        assert a == self._long(3)

    def test_int_floordiv(self):
        import sys
        long = self._long

        x = long(3000)
        a = x // 1000
        assert a == 3

        x = long(3000)
        a = x // -1000
        assert a == -3

        x = long(3000)
        raises(ZeroDivisionError, "x // 0")

        n = sys.maxsize + 1
        assert n / int(-n) == long(-1)

    def test_numerator_denominator(self):
        assert (self._long(1)).numerator == self._long(1)
        assert (self._long(1)).denominator == self._long(1)
        assert (self._long(42)).numerator == self._long(42)
        assert (self._long(42)).denominator == self._long(1)

    def test_compare(self):
        Z = 0
        ZL = self._long(0)

        assert Z == ZL
        assert not (Z != ZL)
        assert ZL == Z
        assert not (ZL != Z)
        assert Z <= ZL
        assert not (Z < ZL)
        assert ZL <= ZL
        assert not (ZL < ZL)

        for BIG in (self._long(1), self._long(1) << 62, self._long(1) << 9999):
            assert not (Z == BIG)
            assert Z != BIG
            assert not (BIG == Z)
            assert BIG != Z
            assert not (ZL == BIG)
            assert ZL != BIG
            assert Z <= BIG
            assert Z < BIG
            assert not (BIG <= Z)
            assert not (BIG < Z)
            assert ZL <= BIG
            assert ZL < BIG
            assert not (BIG <= ZL)
            assert not (BIG < ZL)
            assert not (Z <= -BIG)
            assert not (Z < -BIG)
            assert -BIG <= Z
            assert -BIG < Z
            assert not (ZL <= -BIG)
            assert not (ZL < -BIG)
            assert -BIG <= ZL
            assert -BIG < ZL
            #
            assert not (BIG <  int(BIG))
            assert     (BIG <= int(BIG))
            assert     (BIG == int(BIG))
            assert not (BIG != int(BIG))
            assert not (BIG >  int(BIG))
            assert     (BIG >= int(BIG))
            #
            assert     (BIG <  int(BIG)+1)
            assert     (BIG <= int(BIG)+1)
            assert not (BIG == int(BIG)+1)
            assert     (BIG != int(BIG)+1)
            assert not (BIG >  int(BIG)+1)
            assert not (BIG >= int(BIG)+1)
            #
            assert not (BIG <  int(BIG)-1)
            assert not (BIG <= int(BIG)-1)
            assert not (BIG == int(BIG)-1)
            assert     (BIG != int(BIG)-1)
            assert     (BIG >  int(BIG)-1)
            assert     (BIG >= int(BIG)-1)
            #
            assert not (int(BIG) <  BIG)
            assert     (int(BIG) <= BIG)
            assert     (int(BIG) == BIG)
            assert not (int(BIG) != BIG)
            assert not (int(BIG) >  BIG)
            assert     (int(BIG) >= BIG)
            #
            assert not (int(BIG)+1 <  BIG)
            assert not (int(BIG)+1 <= BIG)
            assert not (int(BIG)+1 == BIG)
            assert     (int(BIG)+1 != BIG)
            assert     (int(BIG)+1 >  BIG)
            assert     (int(BIG)+1 >= BIG)
            #
            assert     (int(BIG)-1 <  BIG)
            assert     (int(BIG)-1 <= BIG)
            assert not (int(BIG)-1 == BIG)
            assert     (int(BIG)-1 != BIG)
            assert not (int(BIG)-1 >  BIG)
            assert not (int(BIG)-1 >= BIG)

    def test_conversion(self):
        class long2(int):
            pass
        x = self._long(1)
        x = long2(x<<100)
        y = int(x)
        assert type(y) == int
        assert type(+long2(5)) is int
        assert type(long2(5) << 0) is int
        assert type(long2(5) >> 0) is int
        assert type(long2(5) + 0) is int
        assert type(long2(5) - 0) is int
        assert type(long2(5) * 1) is int
        assert type(1 * long2(5)) is int
        assert type(0 + long2(5)) is int
        assert type(-long2(0)) is int
        assert type(long2(5) // 1) is int

    def test_shift(self):
        long = self._long
        assert long(65) >> long(2) == long(16)
        assert long(65) >> 2 == long(16)
        assert 65 >> long(2) == long(16)
        assert long(65) << long(2) == long(65) * 4
        assert long(65) << 2 == long(65) * 4
        assert 65 << long(2) == long(65) * 4
        raises(ValueError, "long(1) << long(-1)")
        raises(ValueError, "long(1) << -1")
        raises(OverflowError, "long(1) << (2 ** 100)")
        raises(ValueError, "long(1) >> long(-1)")
        raises(ValueError, "long(1) >> -1")
        assert long(1) >> (2 ** 100) == 0
        assert long(-1) >> (2 ** 100) == -1
        assert 1 >> (2 ** 100) == 0 # int compatibility
        assert -1 >> (2 ** 100) == -1 # int compatibility
        assert 0 << (1 << 1000) == 0


    def test_pow(self):
        long = self._long
        x = self._long(0)
        assert pow(x, self._long(0), self._long(1)) == self._long(0)
        assert pow(-self._long(1), -self._long(1)) == -1.0
        assert pow(2 ** 68, 0.5) == 2.0 ** 34
        assert pow(2 ** 68, 2) == 2 ** 136
        raises(ValueError, pow, long(2), 5, 0)

        # some rpow tests
        assert pow(0, long(0), long(1)) == long(0)
        assert pow(-1, long(-1)) == -1.0

    def test_int_pow(self):
        long = self._long
        x = long(2)
        assert pow(x, 2) == long(4)
        assert pow(x, 2, 2) == long(0)
        assert pow(x, 2, long(3)) == long(1)

    def test_getnewargs(self):
        assert  self._long(0) .__getnewargs__() == (self._long(0),)
        assert  (-self._long(1)) .__getnewargs__() == (-self._long(1),)

    def test_divmod(self):
        long = self._long
        def check_division(x, y):
            q, r = divmod(x, y)
            pab, pba = x*y, y*x
            assert pab == pba
            assert q == x // y
            assert r == x % y
            assert x == q*y + r
            if y > 0:
                assert 0 <= r < y
            else:
                assert y < r <= 0
        for x in [-self._long(1), self._long(0), self._long(1), self._long(2) ** 100 - 1, -self._long(2) ** 100 - 1]:
            for y in [-self._long(105566530), -self._long(1), self._long(1), self._long(1034522340)]:
                print("checking division for %s, %s" % (x, y))
                check_division(x, y)
                check_division(x, int(y))
                check_division(int(x), y)
        # special case from python tests:
        s1 = 33
        s2 = 2
        x = 16565645174462751485571442763871865344588923363439663038777355323778298703228675004033774331442052275771343018700586987657790981527457655176938756028872904152013524821759375058141439
        x >>= s1*16
        y = 10953035502453784575
        y >>= s2*16
        x = 0x3FE0003FFFFC0001FFF
        y = self._long(0x9800FFC1)
        check_division(x, y)
        raises(ZeroDivisionError, "x // self._long(0)")
        divmod(3, self._long(4))
        raises(ZeroDivisionError, "x % long(0)")
        raises(ZeroDivisionError, divmod, x, long(0))
        raises(ZeroDivisionError, "x // 0")
        raises(ZeroDivisionError, "x % 0")
        raises(ZeroDivisionError, divmod, x, 0)

    def test_int_divmod(self):
        long = self._long
        q, r = divmod(long(100), 11)
        assert q == 9
        assert r == 1

    def test_format(self):
        assert repr(12345678901234567890) == '12345678901234567890'
        assert str(12345678901234567890) == '12345678901234567890'
        assert hex(self._long(0x1234567890ABCDEF)) == '0x1234567890abcdef'
        assert oct(self._long(0o1234567012345670)) == '0o1234567012345670'

    def test_bits(self):
        x = self._long(0xAAAAAAAA)
        assert x | self._long(0x55555555) == self._long(0xFFFFFFFF)
        assert x & self._long(0x55555555) == self._long(0x00000000)
        assert x ^ self._long(0x55555555) == self._long(0xFFFFFFFF)
        assert -x | self._long(0x55555555) == -self._long(0xAAAAAAA9)
        assert x | self._long(0x555555555) == self._long(0x5FFFFFFFF)
        assert x & self._long(0x555555555) == self._long(0x000000000)
        assert x ^ self._long(0x555555555) == self._long(0x5FFFFFFFF)

    def test_hash(self):
        import sys
        modulus = sys.hash_info.modulus
        def longhash(x):
            return hash(self._long(x))
        for x in (list(range(200)) +
                  [1234567890123456789, 18446743523953737727,
                   987685321987685321987685321987685321987685321,
                   10**50]):
            y = x % modulus
            assert longhash(x) == longhash(y)
            assert longhash(-x) == longhash(-y)
        assert longhash(modulus - 1) == modulus - 1
        assert longhash(modulus) == 0
        assert longhash(modulus + 1) == 1

        assert longhash(-1) == -2
        value = -(modulus + 1)
        assert longhash(value) == -2
        assert longhash(value * 2 + 1) == -2
        assert longhash(value * 4 + 3) == -2

    def test_hash_2(self):
        class AAA:
            def __hash__(a):
                return self._long(-1)
        assert hash(AAA()) == -2

    def test_math_log(self):
        import math
        raises(ValueError, math.log, self._long(0))
        raises(ValueError, math.log, -self._long(1))
        raises(ValueError, math.log, -self._long(2))
        raises(ValueError, math.log, -(self._long(1) << 10000))
        #raises(ValueError, math.log, 0)
        raises(ValueError, math.log, -1)
        raises(ValueError, math.log, -2)

    def test_long(self):
        import sys
        n = -sys.maxsize-1
        assert int(n) == n
        assert str(int(n)) == str(n)
        a = memoryview(b'123')
        assert int(a) == self._long(123)

    def test_huge_longs(self):
        import operator
        x = self._long(1)
        huge = x << self._long(40000)
        raises(OverflowError, float, huge)
        raises(OverflowError, operator.truediv, huge, 3)
        raises(OverflowError, operator.truediv, huge, self._long(3))

    def test_just_trunc(self):
        class myint(object):
            def __trunc__(self):
                return 42
        assert int(myint()) == 42

    def test_override___int__(self):
        class myint(int):
            def __int__(self):
                return 42
        assert int(myint(21)) == 42
        class myotherint(int):
            pass
        assert int(myotherint(21)) == 21

    def test___int__(self):
        class A(object):
            def __int__(self):
                return 42
        assert int(A()) == 42

        class IntSubclass(int):
            pass
        class ReturnsIntSubclass(object):
            def __int__(self):
                return IntSubclass(42)
        n = int(ReturnsIntSubclass())
        assert n == 42
        # cpython 3.6 fixed behaviour to actually return type int here
        assert type(n) is int

    def test_trunc_returns(self):
        # but!: (blame CPython 2.7)
        class Integral(object):
            def __int__(self):
                return 42
        class TruncReturnsNonInt(object):
            def __trunc__(self):
                return Integral()
        n = int(TruncReturnsNonInt())
        assert type(n) is int
        assert n == 42

        class IntSubclass(int):
            pass
        class TruncReturnsNonInt(object):
            def __trunc__(self):
                return IntSubclass(42)
        n = int(TruncReturnsNonInt())
        assert n == 42
        assert type(n) is int

    def test_long_before_string(self):
        class A(str):
            def __int__(self):
                return 42
        assert int(A('abc')) == 42

    def test_conjugate(self):
        assert (self._long(7)).conjugate() == self._long(7)
        assert (-self._long(7)).conjugate() == -self._long(7)

        class L(int):
            pass

        assert type(L(7).conjugate()) is int

        class L(int):
            def __pos__(self):
                return 43
        assert L(7).conjugate() == self._long(7)

    def test_bit_length(self):
        assert self._long(8).bit_length() == 4
        assert (-1<<40).bit_length() == 41
        assert ((2**31)-1).bit_length() == 31

    def test_from_bytes(self):
        assert int.from_bytes(b'c', 'little') == 99
        assert int.from_bytes(b'\x01\x01', 'little') == 257
        assert int.from_bytes(b'\x01\x00', 'big') == 256
        assert int.from_bytes(b'\x00\x80', 'little', signed=True) == -32768
        assert int.from_bytes([255, 0, 0], 'big', signed=True) == -65536
        raises(TypeError, int.from_bytes, 0, 'big')
        raises(TypeError, int.from_bytes, '', 'big')
        raises(ValueError, int.from_bytes, b'c', 'foo')

    def test_to_bytes(self):
        assert 65535 .to_bytes(2, 'big') == b'\xff\xff'
        assert (-8388608).to_bytes(3, 'little', signed=True) == b'\x00\x00\x80'
        raises(OverflowError, (-5).to_bytes, 1, 'big')
        raises(ValueError, (-5).to_bytes, 1, 'foo')
        assert 65535 .to_bytes(length=2, byteorder='big') == b'\xff\xff'

    def test_negative_zero(self):
        x = eval("-self._long(0)")
        assert x == self._long(0)

    def test_long_real(self):
        class A(int): pass
        b = A(5).real
        assert type(b) is int

    @py.test.mark.skipif("not config.option.runappdirect and sys.maxunicode == 0xffff")
    def test_long_from_unicode(self):
        raises(ValueError, int, '123L')
        assert int('L', 22) == 21
        s = '\U0001D7CF\U0001D7CE' # 𝟏𝟎
        assert int(s) == 10

    def test_long_from_bytes(self):
        assert int(b'1234') == 1234

    def test_invalid_literal_message(self):
        try:
            int('hello àèìò')
        except ValueError as e:
            assert 'hello àèìò' in str(e)
        else:
            assert False, 'did not raise'

    def test_base_overflow(self):
        raises(ValueError, int, '42', 2**63)

    def test_long_real(self):
        class A(int): pass
        b = A(5).real
        assert type(b) is int

    def test__int__(self):
        class A(int):
            def __int__(self):
                return 42

        assert int(int(3)) == int(3)
        assert int(A(13)) == 42

    def test_long_error_msg(self):
        e = raises(TypeError, int, [])
        assert str(e.value) == (
            "int() argument must be a string, a bytes-like object "
            "or a number, not 'list'")

    def test_linear_long_base_16(self):
        # never finishes if int(_, 16) is not linear-time
        size = 100000
        n = "a" * size
        expected = (2 << (size * 4)) // 3
        assert int(n, 16) == expected

    def test_large_identity(self):
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only')
        a = sys.maxsize + 1
        b = sys.maxsize + 2
        assert a is not b
        b -= 1
        assert a is b

    def test_pow_negative_exponent_modulo(self):
        import math
        mod = 2 ** 100
        res = 519502503658624787456021964081
        assert pow(3**100, -1, mod) == res
        assert pow(3**100, -2, mod) == (519502503658624787456021964081 ** 2) % mod

        for i in range(1, 7):
            i = self._long(i)
            for j in range(2, 7):
                j = self._long(j)
                for sign in [1, -1]:
                    i = i * sign
                    if math.gcd(i, j) != 1:
                        with raises(ValueError):
                            pow(i, -1, j)
                        continue
                    x = pow(i, -1, j)
                    assert (x * i) % j == 1 % j

                    for k in range(2, 4):
                        y = pow(i, -k, j)
                        assert y == pow(x, k, j)
