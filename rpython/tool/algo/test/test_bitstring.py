from rpython.tool.algo.bitstring import *
from hypothesis import given, strategies

def test_make():
    assert make_bitstring([]) == ''
    assert make_bitstring([0]) == '\x01'
    assert make_bitstring([7]) == '\x80'
    assert make_bitstring([8]) == '\x00\x01'
    assert make_bitstring([2, 4, 20]) == '\x14\x00\x10'

def test_bitcheck():
    assert bitcheck('\x01', 0) is True
    assert bitcheck('\x01', 1) is False
    assert bitcheck('\x01', 10) is False
    assert [n for n in range(32) if bitcheck('\x14\x00\x10', n)] == [2, 4, 20]

@given(strategies.lists(strategies.integers(min_value=0, max_value=299)))
def test_random(lst):
    bitstring = make_bitstring(lst)
    assert set([n for n in range(300) if bitcheck(bitstring, n)]) == set(lst)

def test_num_bits():
    assert num_bits('') == 0
    assert num_bits('a') == 8
    assert num_bits('bcd') == 24
