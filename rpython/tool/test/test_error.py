
""" Tests some error handling routines
"""

from rpython.translator.translator import TranslationContext
from rpython.annotator.model import UnionError

import py

def compile_function(function, annotation=[]):
    t = TranslationContext()
    t.buildannotator().build_types(function, annotation)

class AAA(object):
    pass

def test_someobject():
    def someobject_degeneration(n):
        if n == 3:
            a = "a"
        else:
            a = 9
        return a

    py.test.raises(UnionError, compile_function, someobject_degeneration, [int])

def test_someobject2():
    def someobject_deg(n):
        if n == 3:
            a = "a"
        else:
            return AAA()
        return a

    py.test.raises(UnionError, compile_function, someobject_deg, [int])

def test_eval_someobject():
    exec("def f(n):\n if n == 2:\n  return 'a'\n else:\n  return 3")

    py.test.raises(UnionError, compile_function, f, [int])

def test_someobject_from_call():
    def one(x):
        return str(x)

    def two(x):
        return int(x)

    def fn(n):
        if n:
            to_call = one
        else:
            to_call = two
        return to_call(n)

    try:
        compile_function(fn, [int])
    except UnionError as e:
        assert 'function one' in str(e)
        assert 'function two' in str(e)
