import py
from rpython.rtyper.test.tool import BaseRtypingTest

class TestRemptydict(BaseRtypingTest):
    def test_empty_dict(self):
        class A:
            pass
        a = A()
        a.d1 = {}
        def func():
            a.d2 = {}
            return bool(a.d1) or bool(a.d2)
        res = self.interpret(func, [])
        assert res is False

    def test_iterate_over_empty_dict(self):
        def f():
            n = 0
            d = {}
            for x in []:                n += x
            for y in d:                 n += y
            for z in d.iterkeys():      n += z
            for s in d.itervalues():    n += s
            for t, u in d.items():      n += t * u
            for t, u in d.iteritems():  n += t * u
            return n
        res = self.interpret(f, [])
        assert res == 0
