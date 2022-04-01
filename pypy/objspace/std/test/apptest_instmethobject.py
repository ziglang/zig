
# NB. instmethobject.py has been removed,
# but the following tests still make sense

def test_callBound():
    boundMethod = [1,2,3].__len__
    assert boundMethod() == 3
    raises(TypeError, boundMethod, 333)

def test_callUnbound():
    unboundMethod = list.__len__
    assert unboundMethod([1,2,3]) == 3
    raises(TypeError, unboundMethod)
    raises(TypeError, unboundMethod, 333)
    raises(TypeError, unboundMethod, [1,2,3], 333)

def test_err_format():
    class C(object):
        def m(self): pass
    try:
        C.m(1)
    except TypeError as e:
        assert str(e) == 'unbound method m() must be called with C instance as first argument (got int instance instead)'

def test_getBound():
    def f(l,x): return l[x+1]
    bound = f.__get__('abcdef')
    assert bound(1) == 'c'
    raises(TypeError, bound)
    raises(TypeError, bound, 2, 3)

def test_getUnbound():
    def f(l,x): return l[x+1]
    unbound = f.__get__(None, str)
    assert unbound('abcdef', 2) == 'd'
    raises(TypeError, unbound)
    raises(TypeError, unbound, 4)
    raises(TypeError, unbound, 4, 5)
