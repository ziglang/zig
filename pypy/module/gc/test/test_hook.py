import pytest
from rpython.rlib.rarithmetic import r_uint
from pypy.module.gc.hook import LowLevelGcHooks
from pypy.interpreter.baseobjspace import ObjSpace
from pypy.interpreter.gateway import interp2app, unwrap_spec

class AppTestGcHooks(object):

    def setup_class(cls):
        if cls.runappdirect:
            pytest.skip("these tests cannot work with -A")
        space = cls.space
        gchooks = space.fromcache(LowLevelGcHooks)

        @unwrap_spec(ObjSpace, int, r_uint, int)
        def fire_gc_minor(space, duration, total_memory_used, pinned_objects):
            gchooks.fire_gc_minor(duration, total_memory_used, pinned_objects)

        @unwrap_spec(ObjSpace, int, int, int)
        def fire_gc_collect_step(space, duration, oldstate, newstate):
            gchooks.fire_gc_collect_step(duration, oldstate, newstate)

        @unwrap_spec(ObjSpace, int, int, int, r_uint, r_uint, r_uint)
        def fire_gc_collect(space, a, b, c, d, e, f):
            gchooks.fire_gc_collect(a, b, c, d, e, f)

        @unwrap_spec(ObjSpace)
        def fire_many(space):
            gchooks.fire_gc_minor(5.0, 0, 0)
            gchooks.fire_gc_minor(7.0, 0, 0)
            gchooks.fire_gc_collect_step(5.0, 0, 0)
            gchooks.fire_gc_collect_step(15.0, 0, 0)
            gchooks.fire_gc_collect_step(22.0, 0, 0)
            gchooks.fire_gc_collect(1, 2, 3, 4, 5, 6)

        cls.w_fire_gc_minor = space.wrap(interp2app(fire_gc_minor))
        cls.w_fire_gc_collect_step = space.wrap(interp2app(fire_gc_collect_step))
        cls.w_fire_gc_collect = space.wrap(interp2app(fire_gc_collect))
        cls.w_fire_many = space.wrap(interp2app(fire_many))

    def test_default(self):
        import gc
        assert gc.hooks.on_gc_minor is None
        assert gc.hooks.on_gc_collect_step is None
        assert gc.hooks.on_gc_collect is None

    def test_on_gc_minor(self):
        import gc
        lst = []
        def on_gc_minor(stats):
            lst.append((stats.count,
                        stats.duration,
                        stats.total_memory_used,
                        stats.pinned_objects))
        gc.hooks.on_gc_minor = on_gc_minor
        self.fire_gc_minor(10, 20, 30)
        self.fire_gc_minor(40, 50, 60)
        assert lst == [
            (1, 10, 20, 30),
            (1, 40, 50, 60),
            ]
        #
        gc.hooks.on_gc_minor = None
        self.fire_gc_minor(70, 80, 90)  # won't fire because the hooks is disabled
        assert lst == [
            (1, 10, 20, 30),
            (1, 40, 50, 60),
            ]

    def test_on_gc_collect_step(self):
        import gc
        SCANNING = 0
        MARKING = 1
        SWEEPING = 2
        FINALIZING = 3
        lst = []
        def on_gc_collect_step(stats):
            lst.append((stats.count,
                        stats.duration,
                        stats.oldstate,
                        stats.newstate,
                        stats.major_is_done))
        gc.hooks.on_gc_collect_step = on_gc_collect_step
        self.fire_gc_collect_step(10, SCANNING, MARKING)
        self.fire_gc_collect_step(40, FINALIZING, SCANNING)
        assert lst == [
            (1, 10, SCANNING, MARKING, False),
            (1, 40, FINALIZING, SCANNING, True),
            ]
        #
        gc.hooks.on_gc_collect_step = None
        oldlst = lst[:]
        self.fire_gc_collect_step(70, SCANNING, MARKING)  # won't fire
        assert lst == oldlst

    def test_on_gc_collect(self):
        import gc
        lst = []
        def on_gc_collect(stats):
            lst.append((stats.count,
                        stats.num_major_collects,
                        stats.arenas_count_before,
                        stats.arenas_count_after,
                        stats.arenas_bytes,
                        stats.rawmalloc_bytes_before,
                        stats.rawmalloc_bytes_after))
        gc.hooks.on_gc_collect = on_gc_collect
        self.fire_gc_collect(1, 2, 3, 4, 5, 6)
        self.fire_gc_collect(7, 8, 9, 10, 11, 12)
        assert lst == [
            (1, 1, 2, 3, 4, 5, 6),
            (1, 7, 8, 9, 10, 11, 12),
            ]
        #
        gc.hooks.on_gc_collect = None
        self.fire_gc_collect(42, 42, 42, 42, 42, 42)  # won't fire
        assert lst == [
            (1, 1, 2, 3, 4, 5, 6),
            (1, 7, 8, 9, 10, 11, 12),
            ]

    def test_consts(self):
        import gc
        S = gc.GcCollectStepStats
        assert S.STATE_SCANNING == 0
        assert S.STATE_MARKING == 1
        assert S.STATE_SWEEPING == 2
        assert S.STATE_FINALIZING == 3
        assert S.GC_STATES == ('SCANNING', 'MARKING', 'SWEEPING',
                               'FINALIZING', 'USERDEL')

    def test_cumulative(self):
        import gc
        class MyHooks(object):

            def __init__(self):
                self.minors = []
                self.steps = []

            def on_gc_minor(self, stats):
                self.minors.append((stats.count, stats.duration,
                                    stats.duration_min, stats.duration_max))

            def on_gc_collect_step(self, stats):
                self.steps.append((stats.count, stats.duration,
                                   stats.duration_min, stats.duration_max))

            on_gc_collect = None

        myhooks = MyHooks()
        gc.hooks.set(myhooks)
        self.fire_many()
        assert myhooks.minors == [(2, 12, 5, 7)]
        assert myhooks.steps == [(3, 42, 5, 22)]

    def test_clear_queue(self):
        import gc
        class MyHooks(object):

            def __init__(self):
                self.lst = []

            def on_gc_minor(self, stats):
                self.lst.append('minor')

            def on_gc_collect_step(self, stats):
                self.lst.append('step')

            def on_gc_collect(self, stats):
                self.lst.append('collect')

        myhooks = MyHooks()
        gc.hooks.set(myhooks)
        self.fire_many()
        assert myhooks.lst == ['minor', 'step', 'collect']
        myhooks.lst[:] = []
        self.fire_gc_minor(0, 0, 0)
        assert myhooks.lst == ['minor']
        gc.hooks.reset()
        assert gc.hooks.on_gc_minor is None
        assert gc.hooks.on_gc_collect_step is None
        assert gc.hooks.on_gc_collect is None

    def test_no_recursive(self):
        import gc
        lst = []
        def on_gc_minor(stats):
            lst.append((stats.count,
                        stats.duration,
                        stats.total_memory_used,
                        stats.pinned_objects))
            self.fire_gc_minor(1, 2, 3)  # won't fire NOW
        gc.hooks.on_gc_minor = on_gc_minor
        self.fire_gc_minor(10, 20, 30)
        self.fire_gc_minor(40, 50, 60)
        # the duration for the 2nd call is 41, because it also counts the 1
        # which was fired recursively
        assert lst == [
            (1, 10, 20, 30),
            (2, 41, 50, 60),
            ]
