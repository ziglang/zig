from __future__ import print_function
import pytest

@pytest.fixture
def testfile(tmpdir):
    tmpfile = tmpdir.join('test_execution_context')
    tmpfile.write("""
from __future__ import print_function
import gc
class X(object):
    def __del__(self):
        print("Called", self.num)
def f():
    x1 = X(); x1.num = 1
    x2 = X(); x2.num = 2
    x1.next = x2
f()
gc.collect()
gc.collect()
""")
    return tmpfile


def test_del_not_blocked(testfile):
    # test the behavior fixed in r71420: before, only one __del__
    # would be called
    import os, sys
    if sys.platform == "win32":
        cmdformat = '"%s" "%s"'
    else:
        cmdformat = "'%s' '%s'"
    g = os.popen(cmdformat % (sys.executable, testfile), 'r')
    data = g.read()
    g.close()
    assert 'Called 1' in data
    assert 'Called 2' in data
