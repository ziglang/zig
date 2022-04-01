import os
import py
import pytest
from pypy.module.bz2.interp_bz2 import W_BZ2Decompressor, INITIAL_BUFFER_SIZE

if os.name == "nt":
    pytest.skip("bz2 module is not available on Windows")

@pytest.yield_fixture
def w_decomp(space):
    w_decomp = W_BZ2Decompressor(space)
    yield w_decomp

@pytest.mark.parametrize('size', [1234, INITIAL_BUFFER_SIZE, 12345])
def test_decompress_max_length(space, w_decomp, size):
    filename = py.path.local(__file__).new(basename='largetest.bz2')
    with open(str(filename), 'rb') as f:
        data = f.read()
        result = w_decomp.decompress(data, size)
    assert space.int_w(space.len(result)) == size
