from py.test import skip, raises

skip('test needs to be updated')

try:
    from stackless import coroutine, CoroutineExit
except ImportError as e:
    skip('cannot import stackless: %s' % (e,))


class Test_Coroutine:

    def test_is_zombie(self):
        co = coroutine()
        def f():
            print('in coro')
        assert not co.is_zombie
        co.bind(f)
        assert not co.is_zombie
        co.switch()
        assert not co.is_zombie

    def test_is_zombie_del_without_frame(self):
        import gc
        res = []
        class MyCoroutine(coroutine):
            def __del__(self):
                res.append(self.is_zombie)
        def f():
            print('in coro')
        co = MyCoroutine()
        co.bind(f)
        co.switch()
        del co
        for i in range(10):
            gc.collect()
            if res:
                break
        co = coroutine()
        co.bind(f)
        co.switch()
        assert res[0], "is_zombie was False in __del__"

    def test_is_zombie_del_with_frame(self):
        import gc
        res = []
        class MyCoroutine(coroutine):
            def __del__(self):
                res.append(self.is_zombie)
        main = coroutine.getcurrent()
        def f():
            print('in coro')
            main.switch()
        co = MyCoroutine()
        co.bind(f)
        co.switch()
        del co
        for i in range(10):
            gc.collect()
            if res:
                break
        co = coroutine()
        co.bind(f)
        co.switch()
        assert res[0], "is_zombie was False in __del__"

    def test_raise_propagate(self):
        co = coroutine()
        def f():
            return 1/0
        co.bind(f)
        try:
            co.switch()
        except ZeroDivisionError:
            pass
        else:
            raise AssertionError("exception not propagated")

    def test_strange_test(self):
        def f():
            return 42
        def create():
            b = coroutine()
            b.bind(f)
            b.switch()
            return b
        a = coroutine()
        a.bind(create)
        b = a.switch()
        def nothing():
            pass
        a.bind(nothing)
        def kill():
            a.kill()
        b.bind(kill)
        b.switch()

    def test_kill(self):
        co = coroutine()
        def f():
            pass
        assert not co.is_alive
        co.bind(f)
        assert co.is_alive
        co.kill()
        assert not co.is_alive

    def test_catch_coroutineexit(self):
        coroutineexit = []
        co_a = coroutine()
        co_test = coroutine.getcurrent()

        def a():
            try:
                co_test.switch()
            except CoroutineExit:
                coroutineexit.append(True)
                raise 
        
        co_a.bind(a)
        co_a.switch()
        assert co_a.is_alive
        
        co_a.kill()
        assert coroutineexit == [True]
        assert not co_a.is_alive
        
    def test_throw(self):
        exceptions = []
        co = coroutine()
        def f(main):
            try:
                main.switch()
            except RuntimeError:
                exceptions.append(True)
        
        co.bind(f, coroutine.getcurrent())
        co.switch()
        co.throw(RuntimeError)
        assert exceptions == [True]
        
    def test_propagation(self):
        exceptions = []
        co = coroutine()
        co2 = coroutine()
        def f(main):
            main.switch()
        
        co.bind(f, coroutine.getcurrent())
        co.switch()
        
        try:
            co.throw(RuntimeError)
        except RuntimeError:
            exceptions.append(1)
            
        def f2():
            raise RuntimeError
        
        co2.bind(f2)
            
        try:
            co2.switch()
        except RuntimeError:
            exceptions.append(2)
        
        assert exceptions == [1,2]

    def test_bogus_bind(self):
        co = coroutine()
        def f():
            pass
        co.bind(f)
        raises(ValueError, co.bind, f)

    def test_simple_task(self):
        maintask = coroutine.getcurrent()
        def f():pass
        co = coroutine()
        co.bind(f)
        co.switch()
        assert not co.is_alive
        assert maintask is coroutine.getcurrent()

    def test_backto_main(self):
        maintask = coroutine.getcurrent()
        def f(task):
            task.switch()
        co = coroutine()
        co.bind(f,maintask)
        co.switch()

    def test_wrapped_main(self):
        class mwrap(object):
            def __init__(self, coro):
                self._coro = coro

            def __getattr__(self, attr):
                return getattr(self._coro, attr)

        maintask = mwrap(coroutine.getcurrent())
        def f(task):
            task.switch()
        co = coroutine()
        co.bind(f,maintask)
        co.switch()

