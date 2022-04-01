import sys
import pytest
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import r_uint, intmask

from pypy.module._pypyjson.simd import USE_SIMD
from pypy.module._pypyjson.simd import find_end_of_string_slow
from pypy.module._pypyjson.simd import find_end_of_string_slow_no_hash
from pypy.module._pypyjson.simd import print_chars
from pypy.module._pypyjson.simd import find_end_of_string_simd_unaligned, WORD_SIZE
from pypy.module._pypyjson.simd import find_end_of_string_simd_unaligned_no_hash

try:
    from hypothesis import example, given, strategies
except ImportError:
    pytest.skip("missing hypothesis!")

if not USE_SIMD:
    pytest.skip("only implemented for 64 bit for now")

def fill_to_word_size(res, ch=" "):
    if len(res) % WORD_SIZE != 0:
        res += ch * (WORD_SIZE - (len(res) % WORD_SIZE))
    return res

def string_to_word(s):
    assert len(s) == WORD_SIZE
    ll_chars, llobj, flag = rffi.get_nonmovingbuffer_ll_final_null(s)
    try:
        wordarray = rffi.cast(rffi.UNSIGNEDP, ll_chars)
        return wordarray[0]
    finally:
        rffi.free_nonmovingbuffer_ll(ll_chars, llobj, flag)

def ll(callable, string, *args):
    ll_chars, llobj, flag = rffi.get_nonmovingbuffer_ll_final_null(string)
    try:
        return callable(ll_chars, *args)
    finally:
        rffi.free_nonmovingbuffer_ll(ll_chars, llobj, flag)

word = strategies.builds(
    r_uint, strategies.integers(min_value=-sys.maxint-1, max_value=sys.maxint))

def build_string(prefix, content, end, suffix):
    res = prefix + '"' + "".join([chr(x) for x in content]) + end + suffix
    return fill_to_word_size(res), len(prefix) + 1

string_in_context_strategy = strategies.builds(
    build_string, prefix=strategies.binary(),
    content=strategies.lists(strategies.integers(1, 255), min_size=1),
    end=strategies.sampled_from('"\\\x00\x01'),
    suffix=strategies.binary())

def compare(string, res1, res2):
    hash1, nonascii1, endindex1 = res1
    hash2, nonascii2, endindex2 = res2
    assert endindex1 == endindex2
    if string[endindex1 - 1] == '"':
        assert hash1 == hash2
    assert nonascii1 == nonascii2


@example(('"       \x80"      ', 1))
@example(('"\x01"          ', 1))
@example(('"aaaaaaaa"\x00\x00\x00\x00\x00\x00\x00       ', 1))
@example(('"aaaaaaaa"      ', 1))
@example(('"12"', 1))
@example(('"1234567abcdefghAB"', 1))
@example(('"1234567abcdefgh"', 1))
@example((' "123456ABCDEF"        \x00', 2))
@example((' "123456aaaaaaaaABCDEF"\x00', 2))
@given(string_in_context_strategy)
def test_find_end_of_string(a):
    (string, startindex) = a
    res = ll(find_end_of_string_slow, string, startindex, len(string))
    hash, nonascii1, endposition1 = res
    res2 = ll(find_end_of_string_slow_no_hash, string, startindex, len(string))
    assert res2 == (nonascii1, endposition1)
    ch = string[endposition1]
    assert ch == '"' or ch == '\\' or ch < '\x20'
    for ch in string[startindex:endposition1]:
        assert not (ch == '"' or ch == '\\' or ch < '\x20')
    compare(string, res, ll(find_end_of_string_simd_unaligned, string, startindex, len(string)))

    nonascii2, endposition2 = ll(find_end_of_string_simd_unaligned_no_hash, string, startindex, len(string))
    assert nonascii1 == nonascii2
    assert endposition1 == endposition2

@given(string_in_context_strategy, strategies.binary(min_size=1))
def test_find_end_of_string_position_invariance(a, prefix):
    fn = find_end_of_string_simd_unaligned
    (string, startindex) = a
    h1, nonascii1, i1 = ll(fn, string, startindex, len(string))
    string2 = prefix + string
    h2, nonascii2, i2 = ll(fn, string2, startindex + len(prefix), len(string) + len(prefix))
    assert h1 == h2
    assert nonascii1 == nonascii2
    assert i1 + len(prefix) == i2

@given(string_in_context_strategy, strategies.binary(min_size=1))
def test_find_end_of_string_position_invariance_no_hash(a, prefix):
    fn = find_end_of_string_simd_unaligned_no_hash
    (string, startindex) = a
    nonascii1, i1 = ll(fn, string, startindex, len(string))
    string2 = prefix + string
    nonascii2, i2 = ll(fn, string2, startindex + len(prefix), len(string) + len(prefix))
    assert nonascii1 == nonascii2
    assert i1 + len(prefix) == i2

