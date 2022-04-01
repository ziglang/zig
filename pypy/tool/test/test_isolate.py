import os
import py
from pypy.tool import isolate

def test_init():
    simple = isolate.Isolate('pypy.tool.test.isolate_simple')
    isolate.close_isolate(simple)

def test_init_dir_name():
    simple = isolate.Isolate((os.path.dirname(__file__), 'isolate_simple'))
    isolate.close_isolate(simple)
    
def test_simple():
    simple = isolate.Isolate('pypy.tool.test.isolate_simple')
    f = simple.f
    res =f(1,2)
    assert res == 3
    res = f(2,3)
    assert res == 5
    isolate.close_isolate(simple)

def test_simple_dir_name():
    simple = isolate.Isolate((os.path.dirname(__file__), 'isolate_simple'))
    f = simple.f
    res = f(1,2)
    assert res == 3
    res = f(2,3)
    assert res == 5
    isolate.close_isolate(simple)

def test_raising():
    simple = isolate.Isolate('pypy.tool.test.isolate_simple')
    py.test.raises(ValueError, "simple.g()")
    isolate.close_isolate(simple)

def test_raising_fancy():
    simple = isolate.Isolate('pypy.tool.test.isolate_simple')
    py.test.raises(isolate.IsolateException, "simple.h()")
    isolate.close_isolate(simple)
    #os.system("ps")

def test_bomb():
    simple = isolate.Isolate('pypy.tool.test.isolate_simple')
    py.test.raises(EOFError, "simple.bomb()")
    isolate.close_isolate(simple)


