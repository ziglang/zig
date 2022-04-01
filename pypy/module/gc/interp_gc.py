from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.error import oefmt
from rpython.rlib import rgc
from pypy.module.gc.hook import W_GcCollectStepStats


@unwrap_spec(generation=int)
def collect(space, generation=0):
    "Run a full collection.  The optional argument is ignored."
    # First clear the method and the map cache.
    # See test_gc for an example of why.
    from pypy.objspace.std.typeobject import MethodCache
    from pypy.objspace.std.mapdict import MapAttrCache
    cache = space.fromcache(MethodCache)
    cache.clear()
    cache = space.fromcache(MapAttrCache)
    cache.clear()

    rgc.collect()
    _run_finalizers(space)

def _run_finalizers(space):
    # if we are running in gc.disable() mode but gc.collect() is called,
    # we should still call the finalizers now.  We do this as an attempt
    # to get closer to CPython's behavior: in Py3.5 some tests
    # specifically rely on that.  This is similar to how, in CPython, an
    # explicit gc.collect() will invoke finalizers from cycles and fully
    # ignore the gc.disable() mode.
    temp_reenable = not space.user_del_action.enabled_at_app_level
    if temp_reenable:
        enable_finalizers(space)
    try:
        # fetch the pending finalizers from the queue, where they are
        # likely to have been added by rgc.collect() above, and actually
        # run them now.  This forces them to run before this function
        # returns, and also always in the enable_finalizers() mode.
        space.user_del_action._run_finalizers()
    finally:
        if temp_reenable:
            disable_finalizers(space)

    return space.newint(0)

def enable(space):
    """Non-recursive version.  Enable major collections and finalizers.
    If they were already enabled, no-op.
    If they were disabled even several times, enable them anyway.
    """
    rgc.enable()
    if not space.user_del_action.enabled_at_app_level:
        space.user_del_action.enabled_at_app_level = True
        enable_finalizers(space)

def disable(space):
    """Non-recursive version.  Disable major collections and finalizers.
    Multiple calls to this function are ignored.
    """
    rgc.disable()
    if space.user_del_action.enabled_at_app_level:
        space.user_del_action.enabled_at_app_level = False
        disable_finalizers(space)

def isenabled(space):
    return space.newbool(space.user_del_action.enabled_at_app_level)

def enable_finalizers(space):
    uda = space.user_del_action
    if uda.finalizers_lock_count == 0:
        raise oefmt(space.w_ValueError, "finalizers are already enabled")
    uda.finalizers_lock_count -= 1
    if uda.finalizers_lock_count == 0:
        pending = uda.pending_with_disabled_del
        uda.pending_with_disabled_del = None
        if pending is not None:
            for i in range(len(pending)):
                uda._call_finalizer(pending[i])
                pending[i] = None   # clear the list as we progress

def disable_finalizers(space):
    uda = space.user_del_action
    uda.finalizers_lock_count += 1
    if uda.pending_with_disabled_del is None:
        uda.pending_with_disabled_del = []


class StepCollector(object):
    """
    Invoke rgc.collect_step() until we are done, then run the app-level
    finalizers as a separate step
    """

    def __init__(self, space):
        self.space = space
        self.finalizing = False

    def do(self):
        if self.finalizing:
            self._run_finalizers()
            self.finalizing = False
            oldstate = W_GcCollectStepStats.STATE_USERDEL
            newstate = W_GcCollectStepStats.STATE_SCANNING
            major_is_done = True # now we are finally done
        else:
            states = self._collect_step()
            oldstate = rgc.old_state(states)
            newstate = rgc.new_state(states)
            major_is_done = False  # USERDEL still to do
            if rgc.is_done(states):
                newstate = W_GcCollectStepStats.STATE_USERDEL
                self.finalizing = True
        #
        duration = -1
        return W_GcCollectStepStats(
            count = 1,
            duration = duration,
            duration_min = duration,
            duration_max = duration,
            oldstate = oldstate,
            newstate = newstate,
            major_is_done = major_is_done)

    def _collect_step(self):
        return rgc.collect_step()

    def _run_finalizers(self):
        _run_finalizers(self.space)

def collect_step(space):
    """
    If the GC is incremental, run a single gc-collect-step. Return True when
    the major collection is completed.
    If the GC is not incremental, do a full collection and return True.
    """
    sc = space.fromcache(StepCollector)
    w_stats = sc.do()
    return w_stats

# ____________________________________________________________

@unwrap_spec(filename='fsencode')
def dump_heap_stats(space, filename):
    tb = rgc._heap_stats()
    if not tb:
        raise oefmt(space.w_RuntimeError, "Wrong GC")
    f = open(filename, mode="w")
    for i in range(len(tb)):
        f.write("%d %d " % (tb[i].count, tb[i].size))
        f.write(",".join([str(tb[i].links[j]) for j in range(len(tb))]) + "\n")
    f.close()
