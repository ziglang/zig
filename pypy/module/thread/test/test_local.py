from pypy.module.thread.test.support import GenericTestThread


class AppTestLocal(GenericTestThread):

    def test_local_1(self):
        import _thread
        import gc
        from _thread import _local as tlsobject
        freed = []
        class X:
            def __del__(self):
                freed.append(1)

        ok = []
        TLS1 = tlsobject()
        TLS2 = tlsobject()
        TLS1.aa = "hello"
        def f(i):
            success = False
            try:
                a = TLS1.aa = i
                b = TLS1.bbb = X()
                c = TLS2.cccc = i*3
                d = TLS2.ddddd = X()
                self.busywait(0.05)
                assert TLS1.aa == a
                assert TLS1.bbb is b
                assert TLS2.cccc == c
                assert TLS2.ddddd is d
                success = True
            finally:
                ok.append(success)
        for i in range(20):
            _thread.start_new_thread(f, (i,))
        self.waitfor(lambda: len(ok) == 20, delay=3)
        assert ok == 20*[True] # see stdout/stderr for failures in the threads
        gc.collect(); gc.collect(); gc.collect()

        self.waitfor(lambda: len(freed) >= 40, delay=20)
        assert len(freed) == 40
        #  in theory, all X objects should have been freed by now.  Note that
        #  Python's own thread._local objects suffer from the very same "bug" that
        #  tls.py showed originally, and leaves len(freed)==38: the last thread's
        #  __dict__ remains stored in the TLS1/TLS2 instances, although it is not
        #  really accessible any more.

        assert TLS1.aa == "hello"


    def test_local_init(self):
        import _thread
        tags = ['???', 1, 2, 3, 4, 5, 54321]
        seen = []

        raises(TypeError, _thread._local, a=1)
        raises(TypeError, _thread._local, 1)

        class X(_thread._local):
            def __init__(self, n):
                assert n == 42
                self.tag = tags.pop()

        x = X(42)
        assert x.tag == 54321
        assert x.tag == 54321
        def f():
            seen.append(x.tag)
        for i in range(5):
            _thread.start_new_thread(f, ())
        self.waitfor(lambda: len(seen) == 5, delay=2)
        seen1 = seen[:]
        seen1.sort()
        assert seen1 == [1, 2, 3, 4, 5]
        assert tags == ['???']

    def test_local_init2(self):
        import _thread

        class A(object):
            def __init__(self, n):
                assert n == 42
                self.n = n
        class X(_thread._local, A):
            pass

        x = X(42)
        assert x.n == 42

    def test_local_setdict(self):
        import _thread
        x = _thread._local()
        raises(AttributeError, "x.__dict__ = 42")
        raises(AttributeError, "x.__dict__ = {}")

        done = []
        def f(n):
            x.spam = n
            assert x.__dict__["spam"] == n
            done.append(1)
        for i in range(5):
            _thread.start_new_thread(f, (i,))
        self.waitfor(lambda: len(done) == 5, delay=2)
        assert len(done) == 5

    def test_weakrefable(self):
        import _thread, weakref
        weakref.ref(_thread._local())

    def test_local_is_not_immortal(self):
        import _thread, gc, time
        class Local(_thread._local):
            def __del__(self):
                done.append('del')
        done = []
        def f():
            assert not hasattr(l, 'foo')
            l.bar = 42
            done.append('ok')
            self.waitfor(lambda: len(done) == 3, delay=8)
        l = Local()
        l.foo = 42
        _thread.start_new_thread(f, ())
        self.waitfor(lambda: len(done) == 1, delay=2)
        l = None
        gc.collect()
        assert done == ['ok', 'del']
        done.append('shutdown')

def test_local_caching():
    from pypy.module.thread.os_local import Local
    class FakeSpace:
        def getexecutioncontext(self):
            return self.ec

        def getattr(*args):
            pass
        def call_obj_args(*args):
            pass
        def newdict(*args, **kwargs):
            return {}
        def wrap(self, obj):
            return obj
        newtext = wrap
        def type(self, obj):
            return type(obj)
        class config:
            class translation:
                rweakref = True

    class FakeEC:
        def __init__(self, space):
            self.space = space
            self._thread_local_objs = None
    space = FakeSpace()
    ec1 = FakeEC(space)
    space.ec = ec1

    l = Local(space, None)
    assert l.last_dict is l.dicts[ec1]
    assert l.last_ec is ec1
    d1 = l.getdict(space)
    assert d1 is l.last_dict

    ec2 = space.ec = FakeEC(space)
    d2 = l.getdict(space)
    assert l.last_dict is d2
    assert d2 is l.dicts[ec2]
    assert l.last_ec is ec2
    dicts = l.dicts
    l.dicts = "nope"
    assert l.getdict(space) is d2
    l.dicts = dicts

    space.ec = ec1
    assert l.getdict(space) is d1
    l.dicts = "nope"
    assert l.getdict(space) is d1
    l.dicts = dicts

