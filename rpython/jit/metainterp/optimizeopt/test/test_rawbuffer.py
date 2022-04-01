import py
from rpython.jit.metainterp.optimizeopt.rawbuffer import (InvalidRawWrite,
                                                          InvalidRawRead, RawBuffer)

class FakeCPU(object):
    def unpack_arraydescr_size(self, descr):
        return descr, 'foo', 'bar'

def test_write_value():
    buf = RawBuffer(FakeCPU())
    buf.write_value(8, 4, 'descr3', 'three')
    buf.write_value(0, 4, 'descr1', 'one')
    buf.write_value(4, 2, 'descr2', 'two')
    buf.write_value(12, 2, 'descr4', 'four')
    assert buf._get_memory() == [
        ( 0, 4, 'descr1', 'one'),
        ( 4, 2, 'descr2', 'two'),
        ( 8, 4, 'descr3', 'three'),
        (12, 2, 'descr4', 'four'),
    ]

def test_write_value_update():
    buf = RawBuffer(FakeCPU())
    buf.write_value(0, 4, 'descr', 'one')
    buf.write_value(4, 2, 'descr', 'two')
    buf.write_value(0, 4, 'descr', 'ONE')
    assert buf._get_memory() == [
        ( 0, 4, 'descr', 'ONE'),
        ( 4, 2, 'descr', 'two'),
    ]

def test_write_value_invalid_length():
    buf = RawBuffer(FakeCPU())
    buf.write_value(0, 4, 'descr1', 'one')
    with py.test.raises(InvalidRawWrite):
        buf.write_value(0, 5, 'descr1', 'two')
    with py.test.raises(InvalidRawWrite):
        buf.write_value(0, 4, 'descr2', 'two')

def test_write_value_overlapping_next():
    buf = RawBuffer(FakeCPU())
    buf.write_value(0, 4, 'descr', 'one')
    buf.write_value(6, 4, 'descr', 'two')
    with py.test.raises(InvalidRawWrite):
        buf.write_value(4, 4, 'descr', 'three')

def test_write_value_overlapping_prev():
    buf = RawBuffer(FakeCPU())
    buf.write_value(0, 4, 'descr', 'one')
    with py.test.raises(InvalidRawWrite):
        buf.write_value(2, 1, 'descr', 'two')

def test_read_value():
    buf = RawBuffer(FakeCPU())
    buf.write_value(0, 4, 'descr', 'one')
    buf.write_value(4, 4, 'descr', 'two')
    assert buf.read_value(0, 4, 'descr') == 'one'
    assert buf.read_value(4, 4, 'descr') == 'two'
    with py.test.raises(InvalidRawRead):
        buf.read_value(0, 2, 'descr')
    with py.test.raises(InvalidRawRead):
        buf.read_value(8, 2, 'descr')
    with py.test.raises(InvalidRawRead):
        buf.read_value(0, 4, 'another descr')

def test_unpack_descrs():
    ArrayS_8_1 = object()
    ArrayS_8_2 = object()
    ArrayU_8 = object()

    class FakeCPU(object):
        def unpack_arraydescr_size(self, descr):
            if descr in (ArrayS_8_1, ArrayS_8_2):
                return 0, 8, True
            return 0, 8, False

    buf = RawBuffer(FakeCPU())
    buf.write_value(0, 4, ArrayS_8_1, 'one')
    assert buf.read_value(0, 4, ArrayS_8_1) == 'one'
    assert buf.read_value(0, 4, ArrayS_8_2) == 'one' # with a non-identical descr
    #
    buf.write_value(0, 4, ArrayS_8_2, 'two') # with a non-identical descr
    assert buf.read_value(0, 4, ArrayS_8_1) == 'two'
    #
    with py.test.raises(InvalidRawRead):
        buf.read_value(0, 4, ArrayU_8)
    with py.test.raises(InvalidRawWrite):
        buf.write_value(0, 4, ArrayU_8, 'three')
