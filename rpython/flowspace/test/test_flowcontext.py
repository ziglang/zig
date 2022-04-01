""" Unit tests for flowcontext.py """
import pytest
from rpython.flowspace.model import Variable, FSException
from rpython.flowspace.flowcontext import (
    Return, Raise, RaiseImplicit, Continue, Break)

@pytest.mark.parametrize('signal', [
    Return(Variable()),
    Raise(FSException(Variable(), Variable())),
    RaiseImplicit(FSException(Variable(), Variable())),
    Break(),
    Continue(42),
])
def test_signals(signal):
    assert signal.rebuild(*signal.args) == signal
