from pytest import raises
from pypy.tool.pytest.astrewriter import ast_rewrite

def get_assert_explanation(space, src):
    fn = "?"
    w_code = ast_rewrite.rewrite_asserts(space, src, fn)
    w_d = space.newdict(module=True)
    excinfo = space.raises_w(space.w_AssertionError, space.exec_, w_code, w_d, w_d)
    return space.text_w(space.getitem(space.getattr(excinfo.value.get_w_value(space), space.newtext("args")), space.newint(0)))

def test_simple(space):
    src = """
x = 1
def f():
    y = 2
    assert x == y
f()
"""
    expl = get_assert_explanation(space, src)
    assert expl == 'assert 1 == 2'

def test_call(space):
    src = """
x = 1
def g():
    return 15
def f():
    y = 2
    assert g() == x + y
f()
"""
    expl = get_assert_explanation(space, src)
    assert expl == 'assert 15 == (1 == 2)\n +  where 15 = g()'

def test_list(space):
    src = """
x = 1
y = 2
assert [1, 1, x] == [1, 1, y]
"""
    expl = get_assert_explanation(space, src)
    # diff etc disabled for now
    assert expl == 'assert [1, 1, 1] == [1, 1, 2]'

def test_boolop(space):
    src = "x = 1; y = 2; assert x == 1 and y == 3"
    expl = get_assert_explanation(space, src)
    assert expl == 'assert (1 == 1 and 2 == 3)'
    src = "x = 1; y = 2; assert x == 2 and y == 3"
    expl = get_assert_explanation(space, src)
    assert expl == 'assert (1 == 2)'

def test_attribute(space):
    src = """
class A:
    x = 1

def f():
    a = A
    assert a.x == 2
f()
"""
    expl = get_assert_explanation(space, src)
    assert expl == "assert 1 == 2\n +  where 1 = <class 'A'>.x"
