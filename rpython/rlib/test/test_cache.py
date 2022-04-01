from rpython.rlib.cache import Cache 

class MyCache(Cache):
    counter = 0
    def _build(self, key):
        self.counter += 1
        return key*7

class TestCache: 
    def test_getorbuild(self):
        cache = MyCache()
        assert cache.getorbuild(1) == 7
        assert cache.counter == 1
        assert cache.getorbuild(1) == 7
        assert cache.counter == 1
        assert cache.getorbuild(3) == 21
        assert cache.counter == 2
        assert cache.getorbuild(1) == 7
        assert cache.counter == 2
        assert cache.getorbuild(3) == 21
        assert cache.counter == 2
