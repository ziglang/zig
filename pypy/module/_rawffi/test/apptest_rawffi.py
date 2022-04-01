# spaceconfig = {"usemodules" : ["_rawffi"]}

import pytest
_rawffi = pytest.importorskip("_rawffi")
from _rawffi import Array

def test_array_view_format():
    ffiarray = Array('c')
    assert memoryview(ffiarray(1, autofree=True)).format == 'c'
