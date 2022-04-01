# spaceconfig = {"usemodules" : ["binascii", "time", "struct", "unicodedata"]}
import os
import sys
from random import random
from math import isnan, copysign


def check_div(x, y):
    """Compute complex z=x*y, and check that z/x==y and z/y==x."""
    z = x * y
    if x != 0:
        q = z / x
        assert close(q, y)
        q = z.__truediv__(x)
        assert close(q, y)
    if y != 0:
        q = z / y
        assert close(q, x)
        q = z.__truediv__(y)
        assert close(q, x)

def close(x, y):
    """Return true iff complexes x and y "are close\""""
    return close_abs(x.real, y.real) and close_abs(x.imag, y.imag)

def close_abs(x, y, eps=1e-9):
    """Return true iff floats x and y "are close\""""
    # put the one with larger magnitude second
    if abs(x) > abs(y):
        x, y = y, x
    if y == 0:
        return abs(x) < eps
    if x == 0:
        return abs(y) < eps
    # check that relative difference < eps
    return abs((x - y) / y) < eps

def almost_equal(a, b, eps=1e-9):
    if isinstance(a, complex):
        if isinstance(b, complex):
            return a.real - b.real < eps and a.imag - b.imag < eps
        else:
            return a.real - b < eps and a.imag < eps
    else:
        if isinstance(b, complex):
            return a - b.real < eps and b.imag < eps
        else:
            return a - b < eps

def floats_identical(x, y):
    msg = 'floats {!r} and {!r} are not identical'

    if isnan(x) or isnan(y):
        if isnan(x) and isnan(y):
            return
    elif x == y:
        if x != 0.0:
            return
        # both zero; check that signs match
        elif copysign(1.0, x) == copysign(1.0, y):
            return
        else:
            msg += ': zeros have different signs'
    assert False, msg.format(x, y)

def test_div():
    # XXX this test passed but took waaaaay to long
    # look at dist/lib-python/modified-2.5.2/test/test_complex.py
    #simple_real = [float(i) for i in range(-5, 6)]
    simple_real = [-2.0, 0.0, 1.0]
    simple_complex = [complex(x, y) for x in simple_real for y in simple_real]
    for x in simple_complex:
        for y in simple_complex:
            check_div(x, y)

    # A naive complex division algorithm (such as in 2.0) is very prone to
    # nonsense errors for these (overflows and underflows).
    check_div(complex(1e200, 1e200), 1+0j)
    check_div(complex(1e-200, 1e-200), 1+0j)

    # Just for fun.
    for i in range(100):
        check_div(complex(random(), random()), complex(random(), random()))

    raises(ZeroDivisionError, complex.__truediv__, 1+1j, 0+0j)
    # FIXME: The following currently crashes on Alpha
    raises(OverflowError, pow, 1e200+1j, 1e200+1j)

def test_truediv():
    assert almost_equal(complex.__truediv__(2+0j, 1+1j), 1-1j)
    raises(ZeroDivisionError, complex.__truediv__, 1+1j, 0+0j)

def test_floordiv():
    raises(TypeError, "3+0j // 0+0j")

def test_convert():
    exc = raises(TypeError, complex.__int__, 3j)
    assert str(exc.value) == "can't convert complex to int"
    exc = raises(TypeError, complex.__float__, 3j)
    assert str(exc.value) == "can't convert complex to float"

def test_richcompare():
    import operator
    assert complex.__lt__(1+1j, None) is NotImplemented
    assert complex.__eq__(1+1j, 2+2j) is False
    assert complex.__eq__(1+1j, 1+1j) is True
    assert complex.__ne__(1+1j, 1+1j) is False
    assert complex.__ne__(1+1j, 2+2j) is True
    assert complex.__lt__(1+1j, 2+2j) is NotImplemented
    assert complex.__le__(1+1j, 2+2j) is NotImplemented
    assert complex.__gt__(1+1j, 2+2j) is NotImplemented
    assert complex.__ge__(1+1j, 2+2j) is NotImplemented
    raises(TypeError, operator.lt, 1+1j, 2+2j)
    raises(TypeError, operator.le, 1+1j, 2+2j)
    raises(TypeError, operator.gt, 1+1j, 2+2j)
    raises(TypeError, operator.ge, 1+1j, 2+2j)
    large = 1 << 10000
    assert not (5+0j) == large
    assert not large == (5+0j)
    assert (5+0j) != large
    assert large != (5+0j)

def test_richcompare_numbers():
    for n in 8, 0.01:
        assert complex.__eq__(n+0j, n)
        assert not complex.__ne__(n+0j, n)
        assert not complex.__eq__(complex(n, n), n)
        assert complex.__ne__(complex(n, n), n)
        assert complex.__lt__(n+0j, n) is NotImplemented

def test_richcompare_boundaries():
    z = 9007199254740992+0j
    i = 9007199254740993
    assert not complex.__eq__(z, i)
    assert complex.__ne__(z, i)

def test_mod():
    a = 3.33+4.43j
    raises(TypeError, "a % a")

def test_divmod():
    raises(TypeError, divmod, 1+1j, 0+0j)

def test_pow():
    assert almost_equal(pow(1+1j, 0+0j), 1.0)
    assert almost_equal(pow(0+0j, 2+0j), 0.0)
    raises(ZeroDivisionError, pow, 0+0j, 1j)
    assert almost_equal(pow(1j, -1), 1/1j)
    assert almost_equal(pow(1j, 200), 1)
    raises(ValueError, pow, 1+1j, 1+1j, 1+1j)

    a = 3.33+4.43j
    assert a ** 0j == 1
    assert a ** 0.+0.j == 1

    assert 3j ** 0j == 1
    assert 3j ** 0 == 1

    raises(ZeroDivisionError, "0j ** a")
    raises(ZeroDivisionError, "0j ** (3-2j)")

    # The following is used to exercise certain code paths
    assert a ** 105 == a ** 105
    assert a ** -105 == a ** -105
    assert a ** -30 == a ** -30
    assert a ** 2 == a * a

    assert 0.0j ** 0 == 1

    b = 5.1+2.3j
    raises(ValueError, pow, a, b, 0)

    b = complex(float('inf'), 0.0) ** complex(10., 3.)
    assert repr(b) == "(nan+nanj)"

def test_boolcontext():
    for i in range(100):
        assert complex(random() + 1e-6, random() + 1e-6)
    assert not complex(0.0, 0.0)

def test_conjugate():
    assert close(complex(5.3, 9.8).conjugate(), 5.3-9.8j)

def test_constructor():
    class NS(object):
        def __init__(self, value):
            self.value = value
        def __complex__(self):
            return self.value
    assert complex(NS(1+10j)) == 1+10j
    assert complex(NS(1+10j), 5) == 1+15j
    assert complex(NS(1+10j), 5j) == -4+10j
    raises(TypeError, complex, NS(2.0))
    raises(TypeError, complex, NS(2))
    raises(TypeError, complex, NS(None))
    raises(TypeError, complex, b'10')

    # -- The following cases are not supported by CPython, but they
    # -- are supported by PyPy, which is most probably ok
    #raises((TypeError, AttributeError), complex, NS(1+10j), NS(1+10j))

    class F(object):
        def __float__(self):
            return 2.0
    assert complex(NS(1+10j), F()) == 1+12j

    assert almost_equal(complex("1+10j"), 1+10j)
    assert almost_equal(complex(10), 10+0j)
    assert almost_equal(complex(10.0), 10+0j)
    assert almost_equal(complex(10+0j), 10+0j)
    assert almost_equal(complex(1,10), 1+10j)
    assert almost_equal(complex(1,10.0), 1+10j)
    assert almost_equal(complex(1.0,10), 1+10j)
    assert almost_equal(complex(1.0,10.0), 1+10j)
    assert almost_equal(complex(3.14+0j), 3.14+0j)
    assert almost_equal(complex(3.14), 3.14+0j)
    assert almost_equal(complex(314), 314.0+0j)
    assert almost_equal(complex(3.14+0j, 0j), 3.14+0j)
    assert almost_equal(complex(3.14, 0.0), 3.14+0j)
    assert almost_equal(complex(314, 0), 314.0+0j)
    assert almost_equal(complex(0j, 3.14j), -3.14+0j)
    assert almost_equal(complex(0.0, 3.14j), -3.14+0j)
    assert almost_equal(complex(0j, 3.14), 3.14j)
    assert almost_equal(complex(0.0, 3.14), 3.14j)
    assert almost_equal(complex("1"), 1+0j)
    assert almost_equal(complex("1j"), 1j)
    assert almost_equal(complex(),  0)
    assert almost_equal(complex("-1"), -1)
    assert almost_equal(complex("+1"), +1)
    assert almost_equal(complex(" ( +3.14-6J ) "), 3.14-6j)
    exc = raises(ValueError, complex, " ( +3.14- 6J ) ")
    assert str(exc.value) == "complex() arg is a malformed string"

    class complex2(complex):
        pass
    assert almost_equal(complex(complex2(1+1j)), 1+1j)
    assert almost_equal(complex(real=17, imag=23), 17+23j)
    assert almost_equal(complex(real=17+23j), 17+23j)
    assert almost_equal(complex(real=17+23j, imag=23), 17+46j)
    assert almost_equal(complex(real=1+2j, imag=3+4j), -3+5j)

    c = 3.14 + 1j
    assert complex(c) is c
    del c

    raises(TypeError, complex, "1", "1")
    raises(TypeError, complex, 1, "1")

    assert complex("  3.14+J  ") == 3.14+1j
    #h.assertEqual(complex(unicode("  3.14+J  ")), 3.14+1j)

    # SF bug 543840:  complex(string) accepts strings with \0
    # Fixed in 2.3.
    raises(ValueError, complex, '1+1j\0j')

    raises(TypeError, int, 5+3j)
    raises(TypeError, float, 5+3j)
    raises(ValueError, complex, "")
    raises(TypeError, complex, None)
    raises(ValueError, complex, "\0")
    raises(TypeError, complex, "1", "2")
    raises(TypeError, complex, "1", 42)
    raises(TypeError, complex, 1, "2")
    raises(ValueError, complex, "1+")
    raises(ValueError, complex, "1+1j+1j")
    raises(ValueError, complex, "--")
#        if x_test_support.have_unicode:
#            raises(ValueError, complex, unicode("1"*500))
#            raises(ValueError, complex, unicode("x"))
#
    class EvilExc(Exception):
        pass

    class evilcomplex:
        def __complex__(self):
            raise EvilExc

    raises(EvilExc, complex, evilcomplex())

    class float2:
        def __init__(self, value):
            self.value = value
        def __float__(self):
            return self.value

    assert almost_equal(complex(float2(42.)), 42)
    assert almost_equal(complex(real=float2(17.), imag=float2(23.)), 17+23j)
    raises(TypeError, complex, float2(None))

def test_complex_string_underscores():
    valid = [
        '1_00_00j',
        '1_00_00.5j',
        '1_00_00e5_1j',
        '.1_4j',
        '(1_2.5+3_3j)',
        '(.5_6j)',
    ]
    for s in valid:
        assert complex(s) == complex(s.replace("_", ""))
        assert eval(s) == eval(s.replace("_", ""))

    invalid = [
        # Trailing underscores:
        '1.4j_',
        # Multiple consecutive underscores:
        '0.1__4j',
        '1e1__0j',
        # Underscore right before a dot:
        '1_.4j',
        # Underscore right after a dot:
        '1._4j',
        '._5j',
        # Underscore right after a sign:
        '1.0e+_1j',
        # Underscore right before j:
        '1.4e5_j',
        # Underscore right before e:
        '1.4_e1j',
        # Underscore right after e:
        '1.4e_1j',
        # Complex cases with parens:
        '(1+1.5_j_)',
        '(1+1.5_j)',
    ]
    for s in invalid:
        raises(ValueError, complex, s)
        raises(SyntaxError, eval, s)

def test_constructor_bad_error_message():
    err = raises(TypeError, complex, {}).value
    assert "float" not in str(err)
    assert str(err) == "complex() first argument must be a string or a number, not 'dict'"
    err = raises(TypeError, complex, 1, {}).value
    assert "float" not in str(err)
    assert str(err) == "complex() second argument must be a number, not 'dict'"

def test_error_messages():
    err = raises(ZeroDivisionError, "1+1j / 0").value
    assert str(err) == "complex division by zero"
    err = raises(TypeError, "1+1j // 0").value
    assert str(err) == "can't take floor of complex number."


def test_hash():
    for x in range(-30, 30):
        assert hash(x) == hash(complex(x, 0))
        x /= 3.0    # now check against floating point
        assert hash(x) == hash(complex(x, 0.))

def test_abs():
    nums = [complex(x/3., y/7.) for x in range(-9,9) for y in range(-9,9)]
    for num in nums:
        assert almost_equal((num.real**2 + num.imag**2)  ** 0.5, abs(num))

def test_complex_subclass_ctr():
    class j(complex):
        pass
    assert j(100 + 0j) == 100 + 0j
    assert isinstance(j(100), j)
    assert j("100+0j") == 100 + 0j
    exc = raises(ValueError, j, "100 + 0j")
    assert str(exc.value) == "complex() arg is a malformed string"
    x = j(1+0j)
    x.foo = 42
    assert x.foo == 42
    assert type(complex(x)) == complex

def test_infinity():
    inf = 1e200*1e200
    assert complex("1"*500) == complex(inf)
    assert complex("-inf") == complex(-inf)

def test_repr():
    assert repr(1+6j) == '(1+6j)'
    assert repr(1-6j) == '(1-6j)'

    assert repr(-(1+0j)) == '(-1-0j)'
    assert repr(complex( 0.0,  0.0)) == '0j'
    assert repr(complex( 0.0, -0.0)) == '-0j'
    assert repr(complex(-0.0,  0.0)) == '(-0+0j)'
    assert repr(complex(-0.0, -0.0)) == '(-0-0j)'
    assert repr(complex(1e45)) == "(" + repr(1e45) + "+0j)"
    assert repr(complex(1e200*1e200)) == '(inf+0j)'
    assert repr(complex(1,-float("nan"))) == '(1+nanj)'

def test_repr_roundtrip():
    # Copied from CPython
    INF = float("inf")
    NAN = float("nan")
    vals = [0.0, 1e-500, 1e-315, 1e-200, 0.0123, 3.1415, 1e50, INF, NAN]
    vals += [-v for v in vals]

    # complex(repr(z)) should recover z exactly, even for complex
    # numbers involving an infinity, nan, or negative zero
    for x in vals:
        for y in vals:
            z = complex(x, y)
            roundtrip = complex(repr(z))
            floats_identical(z.real, roundtrip.real)
            floats_identical(z.imag, roundtrip.imag)

    # if we predefine some constants, then eval(repr(z)) should
    # also work, except that it might change the sign of zeros
    inf, nan = float('inf'), float('nan')
    infj, nanj = complex(0.0, inf), complex(0.0, nan)
    for x in vals:
        for y in vals:
            z = complex(x, y)
            roundtrip = eval(repr(z))
            # adding 0.0 has no effect beside changing -0.0 to 0.0
            floats_identical(0.0 + z.real, 0.0 + roundtrip.real)
            floats_identical(0.0 + z.imag, 0.0 + roundtrip.imag)

def test_neg():
    assert -(1+6j) == -1-6j

def test_file():
    import os
    import tempfile

    a = 3.33+4.43j
    b = 5.1+2.3j

    fo = None
    try:
        pth = tempfile.mktemp()
        fo = open(pth, "w")
        print(a, b, file=fo)
        fo.close()
        fo = open(pth, "r")
        res = fo.read()
        assert res == "%s %s\n" % (a, b)
    finally:
        if (fo is not None) and (not fo.closed):
            fo.close()
        try:
            os.remove(pth)
        except (OSError, IOError):
            pass

def test_convert():
    import warnings
    raises(TypeError, int, 1+1j)
    raises(TypeError, float, 1+1j)

    class complex0(complex):
        """Test usage of __complex__() when inheriting from 'complex'"""
        def __complex__(self):
            return 42j
    assert complex(complex0(1j)) ==  42j

    class complex1(complex):
        """Test usage of __complex__() with a __new__() method"""
        def __new__(self, value=0j):
            return complex.__new__(self, 2*value)
        def __complex__(self):
            return self
    with warnings.catch_warnings(record=True) as log:
        warnings.simplefilter("always", DeprecationWarning)
        assert complex(complex1(1j)) == 2j
        assert len(log) == 1
        assert log[0].category == DeprecationWarning

    class complex1b(complex):
        """Test usage of a complex subclass without __complex__() method"""
        def __new__(self, value=0j):
            return complex.__new__(self, 2*value)
    with warnings.catch_warnings(record=True) as log:
        warnings.simplefilter("always", DeprecationWarning)
        assert complex(complex1b(1j)) == 2j
        assert len(log) == 0

    class complex1_proxy:
        """Test usage of __complex__() without subclassing complex"""
        def __init__(self, value=0j):
            self.value = value
        def __complex__(self):
            return complex1(self.value)
    with warnings.catch_warnings(record=True) as log:
        warnings.simplefilter("always", DeprecationWarning)
        assert complex(complex1_proxy(1j)) == 2j
        assert len(log) == 1
        assert log[0].category == DeprecationWarning

    class complex2(complex):
        """Make sure that __complex__() calls fail if anything other than a
        complex is returned"""
        def __complex__(self):
            return None
    raises(TypeError, complex, complex2(1j))

def test_getnewargs():
    assert (1+2j).__getnewargs__() == (1.0, 2.0)

def test_method_not_found_on_newstyle_instance():
    class A(object):
        pass
    a = A()
    a.__complex__ = lambda: 5j     # ignored
    raises(TypeError, complex, a)
    A.__complex__ = lambda self: 42j
    assert complex(a) == 42j

def test_format():
    # empty format string is same as str()
    assert format(1+3j, '') == str(1+3j)
    assert format(1.5+3.5j, '') == str(1.5+3.5j)
    assert format(3j, '') == str(3j)
    assert format(3.2j, '') == str(3.2j)
    assert format(3+0j, '') == str(3+0j)
    assert format(3.2+0j, '') == str(3.2+0j)

    # empty presentation type should still be analogous to str,
    # even when format string is nonempty (issue #5920).

    assert format(3.2, '-') == str(3.2)
    assert format(3.2+0j, '-') == str(3.2+0j)
    assert format(3.2+0j, '<') == str(3.2+0j)
    z = 10/7. - 100j/7.
    assert format(z, '') == str(z)
    assert format(z, '-') == str(z)
    assert format(z, '<') == str(z)
    assert format(z, '10') == str(z)
    z = complex(0.0, 3.0)
    assert format(z, '') == str(z)
    assert format(z, '-') == str(z)
    assert format(z, '<') == str(z)
    assert format(z, '2') == str(z)
    z = complex(-0.0, 2.0)
    assert format(z, '') == str(z)
    assert format(z, '-') == str(z)
    assert format(z, '<') == str(z)
    assert format(z, '3') == str(z)

    assert format(1+3j, 'g') == '1+3j'
    assert format(3j, 'g') == '0+3j'
    assert format(1.5+3.5j, 'g') == '1.5+3.5j'

    assert format(1.5+3.5j, '+g') == '+1.5+3.5j'
    assert format(1.5-3.5j, '+g') == '+1.5-3.5j'
    assert format(1.5-3.5j, '-g') == '1.5-3.5j'
    assert format(1.5+3.5j, ' g') == ' 1.5+3.5j'
    assert format(1.5-3.5j, ' g') == ' 1.5-3.5j'
    assert format(-1.5+3.5j, ' g') == '-1.5+3.5j'
    assert format(-1.5-3.5j, ' g') == '-1.5-3.5j'

    assert format(-1.5-3.5e-20j, 'g') == '-1.5-3.5e-20j'
    assert format(-1.5-3.5j, 'f') == '-1.500000-3.500000j'
    assert format(-1.5-3.5j, 'F') == '-1.500000-3.500000j'
    assert format(-1.5-3.5j, 'e') == '-1.500000e+00-3.500000e+00j'
    assert format(-1.5-3.5j, '.2e') == '-1.50e+00-3.50e+00j'
    assert format(-1.5-3.5j, '.2E') == '-1.50E+00-3.50E+00j'
    assert format(-1.5e10-3.5e5j, '.2G') == '-1.5E+10-3.5E+05j'

    assert format(1.5+3j, '<20g') ==  '1.5+3j              '
    assert format(1.5+3j, '*<20g') == '1.5+3j**************'
    assert format(1.5+3j, '>20g') ==  '              1.5+3j'
    assert format(1.5+3j, '^20g') ==  '       1.5+3j       '
    assert format(1.5+3j, '<20') ==   '(1.5+3j)            '
    assert format(1.5+3j, '>20') ==   '            (1.5+3j)'
    assert format(1.5+3j, '^20') ==   '      (1.5+3j)      '
    assert format(1.123-3.123j, '^20.2') == '     (1.1-3.1j)     '

    assert format(1.5+3j, '20.2f') == '          1.50+3.00j'
    assert format(1.5+3j, '>20.2f') == '          1.50+3.00j'
    assert format(1.5+3j, '<20.2f') == '1.50+3.00j          '
    assert format(1.5e20+3j, '<20.2f') == '150000000000000000000.00+3.00j'
    assert format(1.5e20+3j, '>40.2f') == '          150000000000000000000.00+3.00j'
    assert format(1.5e20+3j, '^40,.2f') == '  150,000,000,000,000,000,000.00+3.00j  '
    assert format(1.5e21+3j, '^40,.2f') == ' 1,500,000,000,000,000,000,000.00+3.00j '
    assert format(1.5e21+3000j, ',.2f') == '1,500,000,000,000,000,000,000.00+3,000.00j'
    assert format(1.5+0.5j, '#f') == '1.500000+0.500000j'

    # zero padding is invalid
    raises(ValueError, (1.5+0.5j).__format__, '010f')

    # '=' alignment is invalid
    raises(ValueError, (1.5+3j).__format__, '=20')

    # integer presentation types are an error
    for t in 'bcdoxX%':
        raises(ValueError, (1.5+0.5j).__format__, t)

    # make sure everything works in ''.format()
    assert '*{0:.3f}*'.format(3.14159+2.71828j) == '*3.142+2.718j*'
    assert '{:-}'.format(1.5+3.5j) == '(1.5+3.5j)'

    INF = float("inf")
    NAN = float("nan")
    # issue 3382: 'f' and 'F' with inf's and nan's
    assert '{0:f}'.format(INF+0j) == 'inf+0.000000j'
    assert '{0:F}'.format(INF+0j) == 'INF+0.000000j'
    assert '{0:f}'.format(-INF+0j) == '-inf+0.000000j'
    assert '{0:F}'.format(-INF+0j) == '-INF+0.000000j'
    assert '{0:f}'.format(complex(INF, INF)) == 'inf+infj'
    assert '{0:F}'.format(complex(INF, INF)) == 'INF+INFj'
    assert '{0:f}'.format(complex(INF, -INF)) == 'inf-infj'
    assert '{0:F}'.format(complex(INF, -INF)) == 'INF-INFj'
    assert '{0:f}'.format(complex(-INF, INF)) == '-inf+infj'
    assert '{0:F}'.format(complex(-INF, INF)) == '-INF+INFj'
    assert '{0:f}'.format(complex(-INF, -INF)) == '-inf-infj'
    assert '{0:F}'.format(complex(-INF, -INF)) == '-INF-INFj'

    assert '{0:f}'.format(complex(NAN, 0)) == 'nan+0.000000j'
    assert '{0:F}'.format(complex(NAN, 0)) == 'NAN+0.000000j'
    assert '{0:f}'.format(complex(NAN, NAN)) == 'nan+nanj'
    assert '{0:F}'.format(complex(NAN, NAN)) == 'NAN+NANj'

def test_complex_two_arguments():
    raises(TypeError, complex, 5, None)

def test_negated_imaginary_literal():
    def sign(x):
        import math
        return math.copysign(1.0, x)
    z0 = -0j
    z1 = -7j
    z2 = -1e1000j
    # Note: In versions of Python < 3.2, a negated imaginary literal
    # accidentally ended up with real part 0.0 instead of -0.0
    assert sign(z0.real) == -1
    assert sign(z0.imag) == -1
    assert sign(z1.real) == -1
    assert sign(z1.imag) == -1
    assert sign(z2.real) == -1
    assert sign(z2.real) == -1

def test_hash_minus_one():
    assert hash(-1.0 + 0j) == -2
    assert (-1.0 + 0j).__hash__() == -2

def test_int_override():
    class MyComplex(complex):
        def __int__(self):
            return 42

    c = MyComplex(0.j)
    assert int(c) == 42

def test_complex_constructor_calls_index():
    class A:
        def __init__(self, val):
            self.val = val
        def __index__(self):
            return self.val
    assert complex(A(1), A(2)) == (1.0+2.0j)

