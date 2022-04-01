import sys
import py
from hypothesis import given, strategies

from rpython.jit.metainterp.optimizeopt.intdiv import magic_numbers, LONG_BIT
from rpython.jit.metainterp.optimizeopt.intdiv import division_operations
from rpython.jit.metainterp.optimizeopt.intdiv import modulo_operations
from rpython.jit.metainterp.optimizeopt.intdiv import unsigned_mul_high
from rpython.jit.metainterp.history import ConstInt
from rpython.jit.metainterp.resoperation import InputArgInt
from rpython.jit.metainterp.executor import execute

not_power_of_two = (strategies.integers(min_value=3, max_value=sys.maxint)
                    .filter(lambda m: (m & (m - 1)) != 0))


@given(strategies.integers(min_value=0, max_value=sys.maxint),
       not_power_of_two)
def test_magic_numbers(n, m):
    k, i = magic_numbers(m)
    k = int(k)    # and no longer r_uint, with wrap-around semantics
    a = (n * k) >> (LONG_BIT + i)
    assert a == n // m


@given(strategies.integers(min_value=0, max_value=2*sys.maxint+1),
       strategies.integers(min_value=0, max_value=2*sys.maxint+1))
def test_unsigned_mul_high(a, b):
    c = unsigned_mul_high(a, b)
    assert c == ((a * b) >> LONG_BIT)


@given(strategies.integers(min_value=-sys.maxint-1, max_value=sys.maxint),
       not_power_of_two,
       strategies.booleans())
def test_division_operations(n, m, known_nonneg):
    if n < 0:
        known_nonneg = False
    n_box = InputArgInt()
    ops = division_operations(n_box, m, known_nonneg)

    constants = {n_box: ConstInt(n)}
    for op in ops:
        argboxes = op.getarglist()
        constantboxes = [constants.get(box, box) for box in argboxes]
        res = execute(None, None, op.getopnum(), None, *constantboxes)
        constants[op] = ConstInt(res)

    assert constants[op].getint() == n // m


@given(strategies.integers(min_value=-sys.maxint-1, max_value=sys.maxint),
       not_power_of_two,
       strategies.booleans())
def test_modulo_operations(n, m, known_nonneg):
    if n < 0:
        known_nonneg = False
    n_box = InputArgInt()
    ops = modulo_operations(n_box, m, known_nonneg)

    constants = {n_box: ConstInt(n)}
    for op in ops:
        argboxes = op.getarglist()
        constantboxes = [constants.get(box, box) for box in argboxes]
        res = execute(None, None, op.getopnum(), None, *constantboxes)
        constants[op] = ConstInt(res)

    assert constants[op].getint() == n % m
