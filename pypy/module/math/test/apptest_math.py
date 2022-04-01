import pytest
import math
import sys

def test_product():
    assert math.prod([1, 2, 3]) == 6
    assert math.prod([1, 2, 3], start=0.5) == 3.0
    assert math.prod([]) == 1.0
    assert math.prod([], start=5) == 5

def test_julians_weird_test_prod():
    class A:
        def __mul__(self, other):
                return 12
        def __imul__(self, other):
                return 13

    # check that the implementation doesn't use *=
    assert math.prod([1, 2], start=A())

def test_more_weird_prod():
    start = [4]
    assert math.prod([2], start=start) == [4, 4]
    assert start == [4]
    start =  object()
    assert math.prod([], start=start) is start


def test_comb():
    from math import comb, factorial

    assert comb(10, 11) == 0
    for n in range(5):
        for k in range(n + 1):
            assert comb(n, k) == factorial(n) // (factorial(k) * factorial(n - k))

    class A:
        def __index__(self):
            return 4

    assert comb(A(), 2) == comb(4, 2)


def test_perm():
    from math import perm, factorial

    assert perm(10, 11) == 0

    for n in range(5):
        for k in range(n + 1):
            assert perm(n, k) == factorial(n) // factorial(n - k)

    class A:
        def __index__(self):
            return 4

    assert perm(A(), 2) == perm(4, 2)

def test_hypot_many_args():
    from math import hypot
    args = math.e, math.pi, math.sqrt(2.0), math.gamma(3.5), math.sin(2.1), 1e48, 2e-47
    for i in range(len(args)+1):
        assert round(
            hypot(*args[:i]) - math.sqrt(sum(s**2 for s in args[:i])), 7) == 0


def test_dist():
    from math import dist
    assert dist((1.0, 2.0, 3.0), (4.0, 2.0, -1.0)) == 5.0
    assert dist((1, 2, 3), (4, 2, -1)) == 5.0
    with pytest.raises(TypeError):
        math.dist(p=(1, 2, 3), q=(2, 3, 4)) # posonly args :-/

def test_nextafter():
    INF = float("inf")
    NAN = float("nan")
    assert math.nextafter(4503599627370496.0, -INF) == 4503599627370495.5
    assert math.nextafter(4503599627370496.0, INF) == 4503599627370497.0
    assert math.nextafter(9223372036854775808.0, 0.0) == 9223372036854774784.0
    assert math.nextafter(-9223372036854775808.0, 0.0) == -9223372036854774784.0

    # around 1.0
    assert math.nextafter(1.0, -INF) == float.fromhex('0x1.fffffffffffffp-1')
    assert math.nextafter(1.0, INF)== float.fromhex('0x1.0000000000001p+0')

    # x == y: y is returned
    assert math.nextafter(2.0, 2.0) == 2.0

    # around 0.0
    smallest_subnormal = sys.float_info.min * sys.float_info.epsilon
    assert math.nextafter(+0.0, INF) == smallest_subnormal
    assert math.nextafter(-0.0, INF) == smallest_subnormal
    assert math.nextafter(+0.0, -INF) == -smallest_subnormal
    assert math.nextafter(-0.0, -INF) == -smallest_subnormal

    # around infinity
    largest_normal = sys.float_info.max
    assert math.nextafter(INF, 0.0) == largest_normal
    assert math.nextafter(-INF, 0.0) == -largest_normal
    assert math.nextafter(largest_normal, INF) == INF
    assert math.nextafter(-largest_normal, -INF) == -INF

    # NaN
    assert math.isnan(math.nextafter(NAN, 1.0))
    assert math.isnan(math.nextafter(1.0, NAN))
    assert math.isnan(math.nextafter(NAN, NAN))

def test_ulp():
    INF = float("inf")
    NAN = float("nan")
    FLOAT_MAX = sys.float_info.max
    assert math.ulp(1.0) == sys.float_info.epsilon
    assert math.ulp(2 ** 52) == 1.0
    assert math.ulp(2 ** 53) == 2.0
    assert math.ulp(2 ** 64) == 4096.0

    assert math.ulp(0.0) == sys.float_info.min * sys.float_info.epsilon
    assert math.ulp(FLOAT_MAX) == FLOAT_MAX - math.nextafter(FLOAT_MAX, -INF)

    # special cases
    assert math.ulp(INF) == INF
    assert math.isnan(math.ulp(math.nan))

    # negative number: ulp(-x) == ulp(x)
    for x in (0.0, 1.0, 2 ** 52, 2 ** 64, INF):
        assert math.ulp(-x) == math.ulp(x)

