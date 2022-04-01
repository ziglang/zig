import sys, os
import py
from rpython.tool.nullpath import NullPyPathLocal

def test_nullpath(tmpdir):
    path = NullPyPathLocal(tmpdir)
    assert repr(path).endswith('[fake]')
    foo_txt = path.join('foo.txt')
    assert isinstance(foo_txt, NullPyPathLocal)
    #
    f = foo_txt.open('w')
    assert f.name == os.devnull
