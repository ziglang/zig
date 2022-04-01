from rpython.jit.metainterp.optimizeopt.intutils import IntBound, IntUpperBound, \
     IntLowerBound, IntUnbounded, ConstIntBound, next_pow2_m1

from copy import copy
import sys
from rpython.rlib.rarithmetic import LONG_BIT, ovfcheck

from hypothesis import given, strategies, example

special_values = (
    range(-100, 100) +
    [2 ** i for i in range(1, LONG_BIT)] +
    [-2 ** i for i in range(1, LONG_BIT)] +
    [2 ** i - 1 for i in range(1, LONG_BIT)] +
    [-2 ** i - 1 for i in range(1, LONG_BIT)] +
    [2 ** i + 1 for i in range(1, LONG_BIT)] +
    [-2 ** i + 1 for i in range(1, LONG_BIT)] +
    [sys.maxint, -sys.maxint-1])

special_values = strategies.sampled_from(
    [int(v) for v in special_values if type(int(v)) is int])

ints = strategies.builds(
    int, # strategies.integers sometimes returns a long?
    special_values | strategies.integers(
    min_value=int(-sys.maxint-1), max_value=sys.maxint))

ints_or_none = strategies.none() | ints


def bound(a, b):
    if a is None and b is None:
        return IntUnbounded()
    elif a is None:
        return IntUpperBound(b)
    elif b is None:
        return IntLowerBound(a)
    else:
        return IntBound(a, b)

def const(a):
    return bound(a,a)


def build_bound_with_contained_number(a, b, c):
    a, b, c = sorted([a, b, c])
    r = bound(a, c)
    assert r.contains(b)
    return r, b

unbounded = strategies.builds(
    lambda x: (bound(None, None), int(x)),
    ints
)

lower_bounded = strategies.builds(
    lambda x, y: (bound(min(x, y), None), max(x, y)),
    ints,
    ints
)

upper_bounded = strategies.builds(
    lambda x, y: (bound(None, max(x, y)), min(x, y)),
    ints,
    ints
)

bounded = strategies.builds(
    build_bound_with_contained_number,
    ints, ints, ints
)

constant = strategies.builds(
    lambda x: (const(x), x),
    ints
)

bound_with_contained_number = strategies.one_of(
    unbounded, lower_bounded, upper_bounded, constant, bounded)

def some_bounds():
    brd = [None] + range(-2, 3)
    for lower in brd:
        for upper in brd:
            if lower is not None and upper is not None and lower > upper:
                continue
            yield (lower, upper, bound(lower, upper))

nbr = range(-5, 6)

def test_known():
    for lower, upper, b in some_bounds():
        inside = []
        border = []
        for n in nbr:
            if (lower is None or n >= lower) and \
               (upper is None or n <= upper):
                if n == lower or n ==upper:
                    border.append(n)
                else:
                    inside.append(n)
                    
        for n in nbr:
            c = const(n)
            if n in inside:
                assert b.contains(n)
                assert not b.known_lt(c)
                assert not b.known_gt(c)
                assert not b.known_le(c)
                assert not b.known_ge(c)
            elif n in border:
                assert b.contains(n)
                if n == upper:
                    assert b.known_le(const(upper))
                else:
                    assert b.known_ge(const(lower))
            else:
                assert not b.contains(n)
                some = (border + inside)[0]
                if n < some:
                    assert b.known_gt(c)
                else:
                    assert b.known_lt(c)


def test_make():                            
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            lt = IntUnbounded()
            lt.make_lt(b1)
            lt.make_lt(b2)
            for n in nbr:
                c = const(n)
                if b1.known_le(c) or b2.known_le(c):
                    assert lt.known_lt(c)
                else:
                    assert not lt.known_lt(c)
                assert not lt.known_gt(c)
                assert not lt.known_ge(c)

            gt = IntUnbounded()
            gt.make_gt(b1)
            gt.make_gt(b2)
            for n in nbr:
                c = const(n)
                if b1.known_ge(c) or b2.known_ge(c):
                    assert gt.known_gt(c)
                else:
                    assert not gt.known_gt(c)
            assert not gt.known_lt(c)
            assert not gt.known_le(c)

            le = IntUnbounded()
            le.make_le(b1)
            le.make_le(b2)
            for n in nbr:
                c = const(n)
                if b1.known_le(c) or b2.known_le(c):
                    assert le.known_le(c)
                else:
                    assert not le.known_le(c)
                assert not le.known_gt(c)
                assert not le.known_ge(c)

                
            ge = IntUnbounded()
            ge.make_ge(b1)
            ge.make_ge(b2)
            for n in nbr:
                c = const(n)
                if b1.known_ge(c) or b2.known_ge(c):
                    assert ge.known_ge(c)
                else:
                    assert not ge.known_ge(c)
                assert not ge.known_lt(c)
                assert not ge.known_le(c)

            gl = IntUnbounded()
            gl.make_ge(b1)
            gl.make_le(b2)
            for n in nbr:
                c = const(n)
                if b1.known_ge(c):
                    assert gl.known_ge(c)
                else:
                    assert not gl.known_ge(c)
                    assert not gl.known_gt(c)
                if  b2.known_le(c):
                    assert gl.known_le(c)
                else:
                    assert not gl.known_le(c)
                    assert not gl.known_lt(c)

def test_intersect():                            
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b = copy(b1)
            b.intersect(b2)
            for n in nbr:
                if b1.contains(n) and b2.contains(n):
                    assert b.contains(n)
                else:
                    assert not b.contains(n)
                    
def test_add():
    for _, _, b1 in some_bounds():
        for n1 in nbr:
            b2 = b1.add(n1)
            for n2 in nbr:
                c1 = const(n2)
                c2 = const(n2 + n1)
                
                if b1.known_le(c1):
                    assert b2.known_le(c2)
                else:
                    assert not b2.known_le(c2)

                if b1.known_ge(c1):
                    assert b2.known_ge(c2)
                else:
                    assert not b2.known_ge(c2)

                if b1.known_le(c1):
                    assert b2.known_le(c2)
                else:
                    assert not b2.known_lt(c2)

                if b1.known_lt(c1):
                    assert b2.known_lt(c2)
                else:
                    assert not b2.known_lt(c2)

                if b1.known_gt(c1):
                    assert b2.known_gt(c2)
                else:
                    assert not b2.known_gt(c2)

def test_add_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b3 = b1.add_bound(b2)
            for n1 in nbr:
                for n2 in nbr:
                    if b1.contains(n1) and b2.contains(n2):
                        assert b3.contains(n1 + n2)

    a=bound(2, 4).add_bound(bound(1, 2))
    assert not a.contains(2)
    assert not a.contains(7)

def test_mul_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b3 = b1.mul_bound(b2)
            for n1 in nbr:
                for n2 in nbr:
                    if b1.contains(n1) and b2.contains(n2):
                        assert b3.contains(n1 * n2)

    a=bound(2, 4).mul_bound(bound(1, 2))
    assert not a.contains(1)
    assert not a.contains(9)

    a=bound(-3, 2).mul_bound(bound(1, 2))
    assert not a.contains(-7)
    assert not a.contains(5)
    assert a.contains(-6)
    assert a.contains(4)

    a=bound(-3, 2).mul(-1)
    for i in range(-2,4):
        assert a.contains(i)
    assert not a.contains(4)
    assert not a.contains(-3)

def test_shift_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            bleft = b1.lshift_bound(b2)
            bright = b1.rshift_bound(b2)
            for n1 in nbr:
                for n2 in range(10):
                    if b1.contains(n1) and b2.contains(n2):
                        assert bleft.contains(n1 << n2)
                        assert bright.contains(n1 >> n2)

def test_shift_overflow():
    b10 = IntBound(0, 10)
    b100 = IntBound(0, 100)
    bmax = IntBound(0, sys.maxint/2)
    assert not b10.lshift_bound(b100).has_upper
    assert not bmax.lshift_bound(b10).has_upper
    assert b10.lshift_bound(b10).has_upper

    for b in (b10, b100, bmax, IntBound(0, 0)):
        for shift_count_bound in (IntBound(7, LONG_BIT), IntBound(-7, 7)):
            #assert not b.lshift_bound(shift_count_bound).has_upper
            assert not b.rshift_bound(shift_count_bound).has_upper


def test_div_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b3 = b1.py_div_bound(b2)
            for n1 in nbr:
                for n2 in nbr:
                    if b1.contains(n1) and b2.contains(n2):
                        if n2 != 0:
                            assert b3.contains(n1 / n2)   # Python-style div

    a=bound(2, 4).py_div_bound(bound(1, 2))
    assert not a.contains(0)
    assert not a.contains(5)

    a=bound(-3, 2).py_div_bound(bound(1, 2))
    assert not a.contains(-4)
    assert not a.contains(3)
    assert a.contains(-3)
    assert a.contains(0)

def test_mod_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b3 = b1.mod_bound(b2)
            for n1 in nbr:
                for n2 in nbr:
                    if b1.contains(n1) and b2.contains(n2):
                        if n2 != 0:
                            assert b3.contains(n1 % n2)   # Python-style div

def test_sub_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b3 = b1.sub_bound(b2)
            for n1 in nbr:
                for n2 in nbr:
                    if b1.contains(n1) and b2.contains(n2):
                        assert b3.contains(n1 - n2)

    a=bound(2, 4).sub_bound(bound(1, 2))
    assert not a.contains(-1)
    assert not a.contains(4)

def test_and_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b3 = b1.and_bound(b2)
            for n1 in nbr:
                for n2 in nbr:
                    if b1.contains(n1) and b2.contains(n2):
                        assert b3.contains(n1 & n2)

def test_or_bound():
    for _, _, b1 in some_bounds():
        for _, _, b2 in some_bounds():
            b3 = b1.or_bound(b2)
            for n1 in nbr:
                for n2 in nbr:
                    if b1.contains(n1) and b2.contains(n2):
                        assert b3.contains(n1 | n2)
                        assert b3.contains(n1 ^ n2) # we use it for xor too


def test_next_pow2_m1():
    assert next_pow2_m1(0) == 0
    assert next_pow2_m1(1) == 1
    assert next_pow2_m1(7) == 7
    assert next_pow2_m1(256) == 511
    assert next_pow2_m1(255) == 255
    assert next_pow2_m1(80) == 127
    assert next_pow2_m1((1 << 32) - 5) == (1 << 32) - 1
    assert next_pow2_m1((1 << 64) - 1) == (1 << 64) - 1

def test_invert_bound():
    for _, _, b1 in some_bounds():
        b2 = b1.invert_bound()
        for n1 in nbr:
            if b1.contains(n1):
                assert b2.contains(~n1)

def test_neg_bound():
    for _, _, b1 in some_bounds():
        b2 = b1.neg_bound()
        for n1 in nbr:
            if b1.contains(n1):
                assert b2.contains(-n1)

@given(bound_with_contained_number, bound_with_contained_number)
def test_make_random(t1, t2):
    def d(b):
        return b.has_lower, b.lower, b.has_upper, b.upper
    b1, n1 = t1
    b2, n2 = t2

    for meth in [IntBound.make_le, IntBound.make_lt, IntBound.make_ge, IntBound.make_gt]:
        b = b1.clone()
        meth(b, b2)
        data = d(b)
        assert not meth(b, b2)
        assert data == d(b) # idempotent


@given(bound_with_contained_number, bound_with_contained_number)
def test_add_bound_random(t1, t2):
    b1, n1 = t1
    b2, n2 = t2
    print b1, n1
    print b2, n2
    b3 = b1.add_bound(b2)
    try:
        r = ovfcheck(n1 + n2)
    except OverflowError:
        assert not b3.bounded()
    else:
        assert b3.contains(r)

@given(bound_with_contained_number, bound_with_contained_number)
def test_sub_bound_random(t1, t2):
    b1, n1 = t1
    b2, n2 = t2
    print b1, n1
    print b2, n2
    b3 = b1.sub_bound(b2)
    try:
        r = ovfcheck(n1 - n2)
    except OverflowError:
        assert not b3.bounded()
    else:
        assert b3.contains(r)

@given(bound_with_contained_number, bound_with_contained_number)
def test_mul_bound_random(t1, t2):
    b1, n1 = t1
    b2, n2 = t2
    b3 = b1.mul_bound(b2)
    try:
        r = ovfcheck(n1 * n2)
    except OverflowError:
        assert not b3.bounded()
    else:
        assert b3.contains(r)

@given(bound_with_contained_number, bound_with_contained_number)
def test_div_bound_random(t1, t2):
    b1, n1 = t1
    b2, n2 = t2
    b3 = b1.py_div_bound(b2)
    if n1 == -sys.maxint-1 and n2 == -1:
        return # overflow
    if n2 != 0:
        assert b3.contains(n1 / n2)   # Python-style div

@given(bound_with_contained_number, bound_with_contained_number)
def test_mod_bound_random(t1, t2):
    b1, n1 = t1
    b2, n2 = t2
    b3 = b1.mod_bound(b2)
    if n1 == -sys.maxint-1 and n2 == -1:
        return # overflow
    if n2 != 0:
        assert b3.contains(n1 % n2)   # Python-style mod

@given(bound_with_contained_number, bound_with_contained_number)
def test_and_bound_random(t1, t2):
    b1, n1 = t1
    b2, n2 = t2
    b3 = b1.and_bound(b2)
    r = n1 & n2
    assert b3.contains(r)

@given(bound_with_contained_number, bound_with_contained_number)
def test_or_bound_random(t1, t2):
    b1, n1 = t1
    b2, n2 = t2
    b3 = b1.or_bound(b2)
    r = n1 | n2
    assert b3.contains(r)
    r = n1 ^ n2
    assert b3.contains(r)

@given(bound_with_contained_number)
def test_invert_bound_random(t1):
    b1, n1 = t1
    b2 = b1.invert_bound()
    assert b2.contains(~n1)

@given(bound_with_contained_number)
@example((IntUpperBound(-100), -sys.maxint-1))
@example((ConstIntBound(-sys.maxint - 1), -sys.maxint-1))
@example((IntBound(-sys.maxint - 1, -sys.maxint+10), -sys.maxint-1))
def test_neg_bound_random(t1):
    b1, n1 = t1
    b2 = b1.neg_bound()
    if n1 != -sys.maxint - 1:
        assert b2.contains(-n1)
    else:
        assert not b2.has_upper
