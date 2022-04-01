import sys
from pytest import raises
from types import TracebackType

def ve():
    raise ValueError

def get_tb():
    try:
        ve()
    except ValueError as e:
        return e.__traceback__

def test_mutation():
    tb = get_tb()

    # allowed
    tb.tb_next = None
    assert tb.tb_next is None

    tb2 = get_tb()
    tb.tb_next = tb2
    assert tb.tb_next is tb2

    with raises(TypeError):
        tb.tb_next = "rabc"

    # loops are forbidden
    with raises(ValueError):
        tb2.tb_next = tb

    with raises(ValueError):
        tb.tb_next = tb

    tb.tb_lasti = 1233
    assert tb.tb_lasti == 1233
    with raises(TypeError):
        tb.tb_lasti = "abc"

    tb.tb_lineno = 1233
    assert tb.tb_lineno == 1233
    with raises(TypeError):
        tb.tb_lineno = "abc"

        
def test_construct():
    frame = sys._getframe()
    tb = get_tb()
    tb2 = TracebackType(tb, frame, 1, 2)
    assert tb2.tb_next is tb
    assert tb2.tb_frame is frame
    assert tb2.tb_lasti == 1
    assert tb2.tb_lineno == 2

    tb2 = TracebackType(tb, frame, 1, -1)
    assert tb2.tb_next is tb
    assert tb2.tb_frame is frame
    assert tb2.tb_lasti == 1
    assert tb2.tb_lineno == -1

def test_can_subclass():
    with raises(TypeError):
        class TB(TracebackType):
            pass

