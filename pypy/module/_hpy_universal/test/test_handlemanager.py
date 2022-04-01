import pytest
from pypy.module._hpy_universal.handlemanager import (
    HandleManager, HandleReleaseCallback)


class FakeSpace(object):
    def __init__(self):
        self._cache = {}

    def fromcache(self, cls):
        if cls not in self._cache:
            self._cache[cls] = cls(self)
        return self._cache[cls]

    def __getattr__(self, name):
        return '<fakespace.%s>' % name

@pytest.fixture
def fakespace():
    return FakeSpace()

def test_fakespace(fakespace):
    assert fakespace.w_ValueError == '<fakespace.w_ValueError>'
    def x(space):
        return object()
    assert fakespace.fromcache(x) is fakespace.fromcache(x)

@pytest.fixture
def mgr(fakespace):
    return HandleManager(fakespace, None)

class TestHandleManager(object):

    def test_first_handle_is_not_zero(self, mgr):
        h = mgr.new('hello')
        assert h > 0

    def test_new(self, mgr):
        h = mgr.new('hello')
        assert mgr.handles_w[h] == 'hello'

    def test_close(self, mgr):
        h = mgr.new('hello')
        assert mgr.close(h) is None
        assert mgr.handles_w[h] is None

    def test_deref(self, mgr):
        h = mgr.new('hello')
        assert mgr.deref(h) == 'hello'     # 'hello' is a fake W_Root
        assert mgr.deref(h) == 'hello'

    def test_consume(self, mgr):
        h = mgr.new('hello')
        assert mgr.consume(h) == 'hello'
        assert mgr.handles_w[h] is None

    def test_freelist(self, mgr):
        h0 = mgr.new('hello')
        h1 = mgr.new('world')
        assert mgr.consume(h0) == 'hello'
        assert mgr.free_list == [h0]
        h2 = mgr.new('hello2')
        assert h2 == h0
        assert mgr.free_list == []

    def test_dup(self, mgr):
        h0 = mgr.new('hello')
        h1 = mgr.dup(h0)
        assert h1 != h0
        assert mgr.consume(h0) == mgr.consume(h1) == 'hello'


class TestReleaseCallback(object):

    class MyCallback(HandleReleaseCallback):
        def __init__(self, seen, data):
            self.seen = seen
            self.data = data
        def release(self, h, obj):
            self.seen.append((h, obj, self.data))

    def test_callback(self, mgr):
        seen = []
        h0 = mgr.new('hello')
        h1 = mgr.dup(h0)
        h2 = mgr.dup(h0)
        mgr.attach_release_callback(h0, self.MyCallback(seen, 'foo'))
        mgr.attach_release_callback(h1, self.MyCallback(seen, 'bar'))
        assert seen == []
        #
        mgr.close(h1)
        assert seen == [(h1, 'hello', 'bar')]
        #
        mgr.close(h2)
        assert seen == [(h1, 'hello', 'bar')]
        #
        mgr.close(h0)
        assert seen == [(h1, 'hello', 'bar'),
                        (h0, 'hello', 'foo')]

    def test_clear(self, mgr):
        seen = []
        h0 = mgr.new('hello')
        mgr.attach_release_callback(h0, self.MyCallback(seen, 'foo'))
        mgr.close(h0)
        assert seen == [(h0, 'hello', 'foo')]
        #
        # check that the releaser array is cleared when we close the handle
        # and that we don't run the releaser for a wrong object
        h1 = mgr.new('world')
        assert h1 == h0
        mgr.close(h1)
        assert seen == [(h0, 'hello', 'foo')]

    def test_multiple_releasers(self, mgr):
        seen = []
        h0 = mgr.new('hello')
        mgr.attach_release_callback(h0, self.MyCallback(seen, 'foo'))
        mgr.attach_release_callback(h0, self.MyCallback(seen, 'bar'))
        mgr.close(h0)
        assert seen == [(h0, 'hello', 'foo'),
                        (h0, 'hello', 'bar')]



class TestUsing(object):

    def test_simple(self, mgr):
        with mgr.using('hello') as h:
            assert mgr.handles_w[h] == 'hello'
        assert mgr.handles_w[h] is None

    def test_multiple_handles(self, mgr):
        with mgr.using('hello', 'world', 'foo') as (h1, h2, h3):
            assert mgr.handles_w[h1] == 'hello'
            assert mgr.handles_w[h2] == 'world'
            assert mgr.handles_w[h3] == 'foo'
        assert mgr.handles_w[h1] is None
        assert mgr.handles_w[h2] is None
        assert mgr.handles_w[h3] is None
