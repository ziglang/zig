from rpython.memory.gc.hook import GcHooks
from rpython.memory.gc import incminimark
from rpython.rlib import rgc
from rpython.rlib.nonconst import NonConstant
from rpython.rlib.rarithmetic import r_uint, r_longlong, longlongmax
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, interp_attrproperty, GetSetProperty
from pypy.interpreter.executioncontext import AsyncAction

inf = float("inf")

class LowLevelGcHooks(GcHooks):
    """
    These are the low-level hooks which are called directly from the GC.

    They can't do much, because the base class marks the methods as
    @rgc.no_collect.

    This is expected to be a singleton, created by space.fromcache, and it is
    integrated with the translation by targetpypystandalone.get_gchooks
    """

    def __init__(self, space):
        self.space = space
        self.w_hooks = space.fromcache(W_AppLevelHooks)

    def is_gc_minor_enabled(self):
        return self.w_hooks.gc_minor_enabled

    def is_gc_collect_step_enabled(self):
        return self.w_hooks.gc_collect_step_enabled

    def is_gc_collect_enabled(self):
        return self.w_hooks.gc_collect_enabled

    def on_gc_minor(self, duration, total_memory_used, pinned_objects):
        action = self.w_hooks.gc_minor
        action.count += 1
        action.duration += duration
        action.duration_min = min(action.duration_min, duration)
        action.duration_max = max(action.duration_max, duration)
        action.total_memory_used = total_memory_used
        action.pinned_objects = pinned_objects
        action.fire()

    def on_gc_collect_step(self, duration, oldstate, newstate):
        action = self.w_hooks.gc_collect_step
        action.count += 1
        action.duration += duration
        action.duration_min = min(action.duration_min, duration)
        action.duration_max = max(action.duration_max, duration)
        action.oldstate = oldstate
        action.newstate = newstate
        action.fire()

    def on_gc_collect(self, num_major_collects,
                      arenas_count_before, arenas_count_after,
                      arenas_bytes, rawmalloc_bytes_before,
                      rawmalloc_bytes_after):
        action = self.w_hooks.gc_collect
        action.count += 1
        action.num_major_collects = num_major_collects
        action.arenas_count_before = arenas_count_before
        action.arenas_count_after = arenas_count_after
        action.arenas_bytes = arenas_bytes
        action.rawmalloc_bytes_before = rawmalloc_bytes_before
        action.rawmalloc_bytes_after = rawmalloc_bytes_after
        action.fire()


class W_AppLevelHooks(W_Root):

    def __init__(self, space):
        self.space = space
        self.gc_minor_enabled = False
        self.gc_collect_step_enabled = False
        self.gc_collect_enabled = False
        self.gc_minor = GcMinorHookAction(space)
        self.gc_collect_step = GcCollectStepHookAction(space)
        self.gc_collect = GcCollectHookAction(space)

    def descr_get_on_gc_minor(self, space):
        return self.gc_minor.w_callable

    def descr_set_on_gc_minor(self, space, w_obj):
        self.gc_minor_enabled = not space.is_none(w_obj)
        self.gc_minor.w_callable = w_obj
        self.gc_minor.fix_annotation()

    def descr_get_on_gc_collect_step(self, space):
        return self.gc_collect_step.w_callable

    def descr_set_on_gc_collect_step(self, space, w_obj):
        self.gc_collect_step_enabled = not space.is_none(w_obj)
        self.gc_collect_step.w_callable = w_obj
        self.gc_collect_step.fix_annotation()

    def descr_get_on_gc_collect(self, space):
        return self.gc_collect.w_callable

    def descr_set_on_gc_collect(self, space, w_obj):
        self.gc_collect_enabled = not space.is_none(w_obj)
        self.gc_collect.w_callable = w_obj
        self.gc_collect.fix_annotation()

    def descr_set(self, space, w_obj):
        w_a = space.getattr(w_obj, space.newtext('on_gc_minor'))
        w_b = space.getattr(w_obj, space.newtext('on_gc_collect_step'))
        w_c = space.getattr(w_obj, space.newtext('on_gc_collect'))
        self.descr_set_on_gc_minor(space, w_a)
        self.descr_set_on_gc_collect_step(space, w_b)
        self.descr_set_on_gc_collect(space, w_c)

    def descr_reset(self, space):
        self.descr_set_on_gc_minor(space, space.w_None)
        self.descr_set_on_gc_collect_step(space, space.w_None)
        self.descr_set_on_gc_collect(space, space.w_None)


class NoRecursiveAction(AsyncAction):
    depth = 0

    def perform(self, ec, frame):
        if self.depth == 0:
            try:
                self.depth += 1
                return self._do_perform(ec, frame)
            finally:
                self.depth -= 1


class GcMinorHookAction(NoRecursiveAction):
    total_memory_used = 0
    pinned_objects = 0

    def __init__(self, space):
        NoRecursiveAction.__init__(self, space)
        self.w_callable = space.w_None
        self.reset()

    def reset(self):
        self.count = 0
        self.duration = 0.0
        self.duration_min = inf
        self.duration_max = 0.0

    def fix_annotation(self):
        # the annotation of the class and its attributes must be completed
        # BEFORE we do the gc transform; this makes sure that everything is
        # annotated with the correct types
        if NonConstant(False):
            self.count = NonConstant(-42)
            self.duration = NonConstant(-53.2)
            self.duration_min = NonConstant(-53.2)
            self.duration_max = NonConstant(-53.2)
            self.total_memory_used = NonConstant(r_uint(42))
            self.pinned_objects = NonConstant(-42)
            self.fire()

    def _do_perform(self, ec, frame):
        w_stats = W_GcMinorStats(
            self.count,
            self.duration,
            self.duration_min,
            self.duration_max,
            self.total_memory_used,
            self.pinned_objects)
        self.reset()
        self.space.call_function(self.w_callable, w_stats)


class GcCollectStepHookAction(NoRecursiveAction):
    oldstate = 0
    newstate = 0

    def __init__(self, space):
        NoRecursiveAction.__init__(self, space)
        self.w_callable = space.w_None
        self.reset()

    def reset(self):
        self.count = 0
        self.duration = 0.0
        self.duration_min = inf
        self.duration_max = 0.0

    def fix_annotation(self):
        # the annotation of the class and its attributes must be completed
        # BEFORE we do the gc transform; this makes sure that everything is
        # annotated with the correct types
        if NonConstant(False):
            self.count = NonConstant(-42)
            self.duration = NonConstant(-53.2)
            self.duration_min = NonConstant(-53.2)
            self.duration_max = NonConstant(-53.2)
            self.oldstate = NonConstant(-42)
            self.newstate = NonConstant(-42)
            self.fire()

    def _do_perform(self, ec, frame):
        w_stats = W_GcCollectStepStats(
            self.count,
            self.duration,
            self.duration_min,
            self.duration_max,
            self.oldstate,
            self.newstate,
            rgc.is_done__states(self.oldstate, self.newstate))
        self.reset()
        self.space.call_function(self.w_callable, w_stats)


class GcCollectHookAction(NoRecursiveAction):
    num_major_collects = 0
    arenas_count_before = 0
    arenas_count_after = 0
    arenas_bytes = 0
    rawmalloc_bytes_before = 0
    rawmalloc_bytes_after = 0

    def __init__(self, space):
        NoRecursiveAction.__init__(self, space)
        self.w_callable = space.w_None
        self.reset()

    def reset(self):
        self.count = 0

    def fix_annotation(self):
        # the annotation of the class and its attributes must be completed
        # BEFORE we do the gc transform; this makes sure that everything is
        # annotated with the correct types
        if NonConstant(False):
            self.count = NonConstant(-42)
            self.num_major_collects = NonConstant(-42)
            self.arenas_count_before = NonConstant(-42)
            self.arenas_count_after = NonConstant(-42)
            self.arenas_bytes = NonConstant(r_uint(42))
            self.rawmalloc_bytes_before = NonConstant(r_uint(42))
            self.rawmalloc_bytes_after = NonConstant(r_uint(42))
            self.fire()

    def _do_perform(self, ec, frame):
        w_stats = W_GcCollectStats(self.count,
                                   self.num_major_collects,
                                   self.arenas_count_before,
                                   self.arenas_count_after,
                                   self.arenas_bytes,
                                   self.rawmalloc_bytes_before,
                                   self.rawmalloc_bytes_after)
        self.reset()
        self.space.call_function(self.w_callable, w_stats)


class W_GcMinorStats(W_Root):

    def __init__(self, count, duration, duration_min, duration_max,
                 total_memory_used, pinned_objects):
        self.count = count
        self.duration = duration
        self.duration_min = duration_min
        self.duration_max = duration_max
        self.total_memory_used = total_memory_used
        self.pinned_objects = pinned_objects


class W_GcCollectStepStats(W_Root):
    # NOTE: this is specific to incminimark: if we want to integrate the
    # applevel gc module with another gc, we probably need a more general
    # approach to this.
    #
    # incminimark has 4 GC states: scanning, marking, sweeping and
    # finalizing. However, from the user point of view, we have an additional
    # "virtual" state: USERDEL, which represent when we run applevel
    # finalizers after having completed a GC major collection. This state is
    # never explicitly visible when using hooks, but it is used for the return
    # value of gc.collect_step (see interp_gc.py)
    STATE_SCANNING = incminimark.STATE_SCANNING
    STATE_MARKING = incminimark.STATE_MARKING
    STATE_SWEEPING = incminimark.STATE_SWEEPING
    STATE_FINALIZING = incminimark.STATE_FINALIZING
    STATE_USERDEL = incminimark.STATE_FINALIZING + 1 # used by StepCollector
    GC_STATES = tuple(incminimark.GC_STATES + ['USERDEL'])

    def __init__(self, count, duration, duration_min, duration_max,
                 oldstate, newstate, major_is_done):
        self.count = count
        self.duration = duration
        self.duration_min = duration_min
        self.duration_max = duration_max
        self.oldstate = oldstate
        self.newstate = newstate
        self.major_is_done = major_is_done


class W_GcCollectStats(W_Root):
    def __init__(self, count, num_major_collects,
                 arenas_count_before, arenas_count_after,
                 arenas_bytes, rawmalloc_bytes_before,
                 rawmalloc_bytes_after):
        self.count = count
        self.num_major_collects = num_major_collects
        self.arenas_count_before = arenas_count_before
        self.arenas_count_after = arenas_count_after
        self.arenas_bytes = arenas_bytes
        self.rawmalloc_bytes_before = rawmalloc_bytes_before
        self.rawmalloc_bytes_after = rawmalloc_bytes_after


# just a shortcut to make the typedefs shorter
def wrap_many(cls, names):
    d = {}
    for name in names:
        if "duration" in name:
            wrapfn = "newfloat"
        else:
            wrapfn = "newint"
        d[name] = interp_attrproperty(name, cls=cls, wrapfn=wrapfn)
    return d


W_AppLevelHooks.typedef = TypeDef(
    "GcHooks",
    on_gc_minor = GetSetProperty(
        W_AppLevelHooks.descr_get_on_gc_minor,
        W_AppLevelHooks.descr_set_on_gc_minor),

    on_gc_collect_step = GetSetProperty(
        W_AppLevelHooks.descr_get_on_gc_collect_step,
        W_AppLevelHooks.descr_set_on_gc_collect_step),

    on_gc_collect = GetSetProperty(
        W_AppLevelHooks.descr_get_on_gc_collect,
        W_AppLevelHooks.descr_set_on_gc_collect),

    set = interp2app(W_AppLevelHooks.descr_set),
    reset = interp2app(W_AppLevelHooks.descr_reset),
    )

W_GcMinorStats.typedef = TypeDef(
    "GcMinorStats",
    **wrap_many(W_GcMinorStats, (
        "count",
        "duration",
        "duration_min",
        "duration_max",
        "total_memory_used",
        "pinned_objects"))
    )

W_GcCollectStepStats.typedef = TypeDef(
    "GcCollectStepStats",
    STATE_SCANNING = W_GcCollectStepStats.STATE_SCANNING,
    STATE_MARKING = W_GcCollectStepStats.STATE_MARKING,
    STATE_SWEEPING = W_GcCollectStepStats.STATE_SWEEPING,
    STATE_FINALIZING = W_GcCollectStepStats.STATE_FINALIZING,
    STATE_USERDEL = W_GcCollectStepStats.STATE_USERDEL,
    GC_STATES = tuple(W_GcCollectStepStats.GC_STATES),
    major_is_done = interp_attrproperty(
        "major_is_done",
        cls=W_GcCollectStepStats,
        wrapfn="newbool"),
    **wrap_many(W_GcCollectStepStats, (
        "count",
        "duration",
        "duration_min",
        "duration_max",
        "oldstate",
        "newstate"))
    )

W_GcCollectStats.typedef = TypeDef(
    "GcCollectStats",
    **wrap_many(W_GcCollectStats, (
        "count",
        "num_major_collects",
        "arenas_count_before",
        "arenas_count_after",
        "arenas_bytes",
        "rawmalloc_bytes_before",
        "rawmalloc_bytes_after"))
    )
