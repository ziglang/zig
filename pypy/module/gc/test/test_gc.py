import py
import pytest
from rpython.rlib import rgc
from pypy.interpreter.baseobjspace import ObjSpace
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.module.gc.interp_gc import StepCollector, W_GcCollectStepStats

class AppTestGC(object):

    def setup_class(cls):
        if cls.runappdirect:
            pytest.skip("these tests cannot work with -A")
        space = cls.space
        def rgc_isenabled(space):
            return space.newbool(rgc.isenabled())
        cls.w_rgc_isenabled = space.wrap(interp2app(rgc_isenabled))

    def test_collect(self):
        import gc
        gc.collect() # mostly a "does not crash" kind of test
        gc.collect(0) # mostly a "does not crash" kind of test

    def test_disable_finalizers(self):
        import gc

        class X(object):
            created = 0
            deleted = 0
            def __init__(self):
                X.created += 1
            def __del__(self):
                X.deleted += 1

        class OldX:
            created = 0
            deleted = 0
            def __init__(self):
                OldX.created += 1
            def __del__(self):
                OldX.deleted += 1

        def runtest(should_be_enabled):
            runtest1(should_be_enabled, X)
            runtest1(should_be_enabled, OldX)

        def runtest1(should_be_enabled, Cls):
            gc.collect()
            if should_be_enabled:
                assert Cls.deleted == Cls.created
            else:
                old_deleted = Cls.deleted
            Cls(); Cls(); Cls()
            gc.collect()
            if should_be_enabled:
                assert Cls.deleted == Cls.created
            else:
                assert Cls.deleted == old_deleted

        runtest(True)
        gc.disable_finalizers()
        runtest(False)
        runtest(False)
        gc.enable_finalizers()
        runtest(True)
        # test nesting
        gc.disable_finalizers()
        gc.disable_finalizers()
        runtest(False)
        gc.enable_finalizers()
        runtest(False)
        gc.enable_finalizers()
        runtest(True)
        raises(ValueError, gc.enable_finalizers)
        runtest(True)

    def test_enable(self):
        import gc
        assert gc.isenabled()
        assert self.rgc_isenabled()
        gc.disable()
        assert not gc.isenabled()
        assert not self.rgc_isenabled()
        gc.enable()
        assert gc.isenabled()
        assert self.rgc_isenabled()
        gc.enable()
        assert gc.isenabled()
        assert self.rgc_isenabled()

    def test_gc_collect_overrides_gc_disable(self):
        import gc
        deleted = []
        class X(object):
            def __del__(self):
                deleted.append(1)
        assert gc.isenabled()
        gc.disable()
        X()
        gc.collect()
        assert deleted == [1]
        gc.enable()

    def test_gc_collect_step(self):
        import gc

        class X(object):
            deleted = 0
            def __del__(self):
                X.deleted += 1

        gc.disable()
        X(); X(); X();
        n = 0
        while True:
            n += 1
            if gc.collect_step().major_is_done:
                break

        assert n >= 2 # at least one step + 1 finalizing
        assert X.deleted == 3

class AppTestGcDumpHeap(object):
    pytestmark = py.test.mark.xfail(run=False)

    def setup_class(cls):
        import py
        from rpython.tool.udir import udir
        from rpython.rlib import rgc
        class X(object):
            def __init__(self, count, size, links):
                self.count = count
                self.size = size
                self.links = links

        def fake_heap_stats():
            return [X(1, 12, [0, 0]), X(2, 10, [10, 0])]

        cls._heap_stats = rgc._heap_stats
        rgc._heap_stats = fake_heap_stats
        fname = udir.join('gcdump.log')
        cls.w_fname = cls.space.wrap(str(fname))
        cls._fname = fname

    def teardown_class(cls):
        import py
        from rpython.rlib import rgc

        rgc._heap_stats = cls._heap_stats
        assert py.path.local(cls._fname).read() == '1 12 0,0\n2 10 10,0\n'

    def test_gc_heap_stats(self):
        import gc
        gc.dump_heap_stats(self.fname)


class AppTestGcMethodCache(object):

    def test_clear_method_cache(self):
        import gc, weakref
        rlist = []
        def f():
            class C(object):
                def f(self):
                    pass
            C().f()    # Fill the method cache
            rlist.append(weakref.ref(C))
        for i in range(10):
            f()
        gc.collect()    # the classes C should all go away here
        # the last class won't go in mapdict, as long as the code object of f
        # is around
        rlist.pop()
        for r in rlist:
            assert r() is None


    def test_clear_index_cache(self):
        import gc, weakref
        rlist = []
        def f():
            class C(object):
                def f(self):
                    pass
            c = C()
            c.x = 1
            getattr(c, "x") # fill the index cache without using the local cache
            getattr(c, "x")
            rlist.append(weakref.ref(C))
        for i in range(5):
            f()
        gc.collect()    # the classes C should all go away here
        for r in rlist:
            assert r() is None


def test_StepCollector():
    W = W_GcCollectStepStats
    SCANNING = W.STATE_SCANNING
    MARKING = W.STATE_MARKING
    SWEEPING = W.STATE_SWEEPING
    FINALIZING = W.STATE_FINALIZING
    USERDEL = W.STATE_USERDEL

    class MyStepCollector(StepCollector):
        my_steps = 0
        my_done = False
        my_finalized = 0

        def __init__(self):
            StepCollector.__init__(self, space=None)
            self._state_transitions = iter([
                (SCANNING, MARKING),
                (MARKING, SWEEPING),
                (SWEEPING, FINALIZING),
                (FINALIZING, SCANNING)])

        def _collect_step(self):
            self.my_steps += 1
            try:
                oldstate, newstate = next(self._state_transitions)
            except StopIteration:
                assert False, 'should not happen, did you call _collect_step too much?'
            return rgc._encode_states(oldstate, newstate)

        def _run_finalizers(self):
            self.my_finalized += 1

    sc = MyStepCollector()
    transitions = []
    while True:
        result = sc.do()
        transitions.append((result.oldstate, result.newstate, sc.my_finalized))
        if result.major_is_done:
            break

    assert transitions == [
        (SCANNING, MARKING, False),
        (MARKING, SWEEPING, False),
        (SWEEPING, FINALIZING, False),
        (FINALIZING, USERDEL, False),
        (USERDEL, SCANNING, True)
    ]
    # there is one more transition than actual step, because
    # FINALIZING->USERDEL is "virtual"
    assert sc.my_steps == len(transitions) - 1
