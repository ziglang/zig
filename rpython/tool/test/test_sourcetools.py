from rpython.tool.sourcetools import (
    func_renamer, func_with_new_name, rpython_wrapper)

def test_rename():
    def f(x, y=5):
        return x + y
    f.prop = int

    g = func_with_new_name(f, "g")
    assert g(4, 5) == 9
    assert g.__name__ == "g"
    assert f.__defaults__ == (5,)
    assert g.prop is int

def test_rename_decorator():
    @func_renamer("g")
    def f(x, y=5):
        return x + y
    f.prop = int

    assert f(4, 5) == 9

    assert f.__name__ == "g"
    assert f.__defaults__ == (5,)
    assert f.prop is int

def test_func_rename_decorator():
    def bar():
        'doc'

    bar2 = func_with_new_name(bar, 'bar2')
    assert bar.__doc__ == bar2.__doc__ == 'doc'

    bar.__doc__ = 'new doc'
    bar3 = func_with_new_name(bar, 'bar3')
    assert bar3.__doc__ == 'new doc'
    assert bar2.__doc__ != bar3.__doc__


def test_rpython_wrapper():
    calls = []

    def bar(a, b):
        calls.append(('bar', a, b))
        return a+b

    template = """
        def {name}({arglist}):
            calls.append(('decorated', {arglist}))
            return {original}({arglist})
    """
    bar = rpython_wrapper(bar, template, calls=calls)
    assert bar(40, 2) == 42
    assert calls == [
        ('decorated', 40, 2),
        ('bar', 40, 2),
        ]
