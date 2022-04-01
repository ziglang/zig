import pytest
_pypy_util_cffi = pytest.importorskip('_pypy_util_cffi')
StackNew = _pypy_util_cffi.StackNew

def test_one():
    with StackNew("char[]", 1) as p:
        p[0] = b'\x13'
        assert p[0] == b'\x13'

    # assert did not crash
    with StackNew("char*") as p:
        pass
