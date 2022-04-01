from rpython.rlib.rweakref import has_weakref_support
from rpython.rtyper.test.test_llinterp import interpret


def test_has_weakref_support():
    assert has_weakref_support()

    res = interpret(lambda: has_weakref_support(), [],
                    **{'translation.rweakref': True})
    assert res == True

    res = interpret(lambda: has_weakref_support(), [],
                    **{'translation.rweakref': False})
    assert res == False
