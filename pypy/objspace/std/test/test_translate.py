from rpython.translator.interactive import Translation
from rpython.rlib.nonconst import NonConstant


def test_newtext_memo(space):
    def f():
        return space.newtext("abc") is space.newtext("abc")

    t = Translation(f, [])
    s_res = t.annotate()
    assert s_res.const is True
