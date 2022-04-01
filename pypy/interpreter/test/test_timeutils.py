import pytest
from rpython.rlib.rarithmetic import r_longlong
from pypy.interpreter.error import OperationError
from pypy.interpreter.timeutils import timestamp_w

def test_timestamp_w(space):
    w_1_year = space.newint(365 * 24 * 3600)
    result = timestamp_w(space, w_1_year)
    assert isinstance(result, r_longlong)
    assert result // 10 ** 9 == space.int_w(w_1_year)
    w_millenium = space.mul(w_1_year, space.newint(1000))
    with pytest.raises(OperationError):  # timestamps overflow after ~300 years
        timestamp_w(space, w_millenium)
