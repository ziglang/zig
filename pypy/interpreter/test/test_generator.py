def test_should_not_inline(space):
    from pypy.interpreter.generator import should_not_inline
    w_co = space.appexec([], '''():
        def g(x):
            yield x + 5
        return g.__code__
    ''')
    assert should_not_inline(w_co) == False
    w_co = space.appexec([], '''():
        def g(x):
            yield x + 5
            yield x + 6
        return g.__code__
    ''')
    assert should_not_inline(w_co) == True
