import py
from rpython.tool.frozenlist import frozenlist

def test_frozenlist():
    l = frozenlist([1, 2, 3])
    assert l[0] == 1
    assert l[:2] == [1, 2]
    assert l.index(2) == 1
    py.test.raises(TypeError, "l[0] = 1")
    py.test.raises(TypeError, "del l[0]")
    py.test.raises(TypeError, "l[:] = []")
    py.test.raises(TypeError, "del l[:]")
    py.test.raises(TypeError, "l += []")
    py.test.raises(TypeError, "l *= 2")
    py.test.raises(TypeError, "l.append(1)")
    py.test.raises(TypeError, "l.insert(0, 0)")
    py.test.raises(TypeError, "l.pop()")
    py.test.raises(TypeError, "l.remove(1)")
    py.test.raises(TypeError, "l.reverse()")
    py.test.raises(TypeError, "l.sort()")
    py.test.raises(TypeError, "l.extend([])")
