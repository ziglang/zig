from rpython.rlib.buffer import RawByteBuffer

from pypy.interpreter.buffer import RawBufferView, SimpleView


def test_RawBufferView_basic():
    buf = RawByteBuffer(10)
    view = RawBufferView(buf, 'ignored', 2)
    assert view.getlength() == 10
    assert view.getformat() == 'ignored'
    assert view.getitemsize() == 2
    assert view.getndim() == 1
    assert view.getshape() == [5]
    assert view.getstrides() == [2]
    assert view.as_readbuf() is view.as_writebuf() is buf

def test_SimpleView_basic():
    buf = RawByteBuffer(10)
    view = SimpleView(buf)
    assert view.getlength() == 10
    assert view.getformat() == 'B'
    assert view.getitemsize() == 1
    assert view.getndim() == 1
    assert view.getshape() == [10]
    assert view.getstrides() == [1]
    assert view.as_readbuf() is view.as_writebuf() is buf

def test_SimpleView_basic_w_obj():
    buf = RawByteBuffer(10)
    view = SimpleView(buf, w_obj="fake obj")
    assert view.w_obj == "fake obj"
