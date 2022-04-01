import py
from rpython.tool.jitlogparser.storage import LoopStorage

def test_load_codes():
    tmppath = py.test.ensuretemp('load_codes')
    tmppath.join("x.py").write("def f(): pass") # one code
    s = LoopStorage(str(tmppath))
    assert s.load_code(str(tmppath.join('x.py'))) == s.load_code('x.py')

