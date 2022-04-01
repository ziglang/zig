
""" test of iterators
"""

from pypy.objspace.std.test.test_proxy_internals import AppProxy

class AppTestProxyIter(AppProxy):
    def test_generator(self):
        def some(l):
            for i in l:
                yield i
        
        g = self.get_proxy(some([1,2,3]))
        assert list(g) == [1,2,3]
        g = self.get_proxy(some([1,2,3]))
        assert next(g) == 1
        assert next(g) == 2
