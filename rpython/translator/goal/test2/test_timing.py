
import py
from rpython.translator.goal.timing import Timer

def test_timing():
    t = Timer(list(reversed([1,2,3,4,5,6])).pop)
    t.start_event('x')
    t.end_event('x')
    t.start_event('y')
    t.end_event('y')
    py.test.raises(AssertionError, "t.end_event('y')")
    t.start_event('z')
    py.test.raises(AssertionError, "t.end_event('y')")
    t.end_event('z')
    assert t.events == [('x', 1), ('y', 1), ('z', 1)]
    assert t.ttime() == 5
    
