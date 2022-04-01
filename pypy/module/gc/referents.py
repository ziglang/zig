from rpython.rlib import rgc, jit_hooks
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, interp_attrproperty
from pypy.interpreter.gateway import unwrap_spec, interp2app, WrappedDefault
from pypy.interpreter.error import oefmt, wrap_oserror
from rpython.rlib.objectmodel import we_are_translated


class W_GcRef(W_Root):
    def __init__(self, gcref):
        self.gcref = gcref

W_GcRef.typedef = TypeDef("GcRef")


def try_cast_gcref_to_w_root(gcref):
    if rgc.get_gcflag_dummy(gcref):
        return None
    w_obj = rgc.try_cast_gcref_to_instance(W_Root, gcref)
    # Ignore the instances of W_Root that are not really valid as Python
    # objects.  There is e.g. WeakrefLifeline in module/_weakref that
    # inherits from W_Root for internal reasons.  Such instances don't
    # have a typedef at all (or have a null typedef after translation).
    if not we_are_translated():
        if getattr(w_obj, 'typedef', None) is None:
            return None
    else:
        if w_obj is None or not w_obj.typedef:
            return None
    return w_obj

def wrap(space, gcref):
    w_obj = try_cast_gcref_to_w_root(gcref)
    if w_obj is None:
        w_obj = W_GcRef(gcref)
    return w_obj

def unwrap(space, w_obj):
    if isinstance(w_obj, W_GcRef):
        gcref = w_obj.gcref
    else:
        gcref = rgc.cast_instance_to_gcref(w_obj)
    return gcref

def missing_operation(space):
    return oefmt(space.w_NotImplementedError,
                 "operation not implemented by this GC")


# ____________________________________________________________

def _list_w_obj_referents(gcref, result_w):
    # Get all W_Root reachable directly from gcref, and add them to
    # the list 'result_w'.
    pending = []    # = list of all objects whose gcflag was toggled
    i = 0
    gcrefparent = gcref
    while True:
        for gcref in rgc.get_rpy_referents(gcrefparent):
            if rgc.get_gcflag_extra(gcref):
                continue
            rgc.toggle_gcflag_extra(gcref)
            pending.append(gcref)

        while i < len(pending):
            gcrefparent = pending[i]
            i += 1
            w_obj = try_cast_gcref_to_w_root(gcrefparent)
            if w_obj is not None:
                result_w.append(w_obj)
            else:
                break   # jump back to the start of the outermost loop
        else:
            break   # done

    for gcref in pending:
        rgc.toggle_gcflag_extra(gcref)    # reset the gcflag_extra's

# ____________________________________________________________

def get_rpy_roots(space):
    lst = rgc.get_rpy_roots()
    if lst is None:
        raise missing_operation(space)
    return space.newlist([wrap(space, gcref) for gcref in lst if gcref])

def get_rpy_referents(space, w_obj):
    """Return a list of all the referents, as reported by the GC.
    This is likely to contain a lot of GcRefs."""
    gcref = unwrap(space, w_obj)
    lst = rgc.get_rpy_referents(gcref)
    if lst is None:
        raise missing_operation(space)
    return space.newlist([wrap(space, gcref) for gcref in lst])

def get_rpy_memory_usage(space, w_obj):
    """Return the memory usage of just the given object or GcRef.
    This does not include the internal structures of the object."""
    gcref = unwrap(space, w_obj)
    size = rgc.get_rpy_memory_usage(gcref)
    if size < 0:
        raise missing_operation(space)
    return space.newint(size)

def get_rpy_type_index(space, w_obj):
    """Return an integer identifying the RPython type of the given
    object or GcRef.  The number starts at 1; it is an index in the
    file typeids.txt produced at translation."""
    gcref = unwrap(space, w_obj)
    index = rgc.get_rpy_type_index(gcref)
    if index < 0:
        raise missing_operation(space)
    return space.newint(index)

@unwrap_spec(w_generation=WrappedDefault(None))
def get_objects(space, w_generation=None):
    """Return a list of all app-level objects."""
    space.audit('gc.get_objects', [space.newint(-1)])
    if not space.is_w(w_generation, space.w_None):
        raise oefmt(space.w_NotImplementedError,
                 "get_objects(generation=None) accepts only None on PyPy")
    if not rgc.has_gcflag_extra():
        raise missing_operation(space)
    result_w = rgc.do_get_objects(try_cast_gcref_to_w_root)
    return space.newlist(result_w)

def get_referents(space, args_w):
    """Return a list of objects directly referred to by any of the arguments.
    """
    if not rgc.has_gcflag_extra():
        raise missing_operation(space)
    space.audit('gc.get_referents', args_w)
    result_w = []
    for w_obj in args_w:
        gcref = rgc.cast_instance_to_gcref(w_obj)
        _list_w_obj_referents(gcref, result_w)
    rgc.assert_no_more_gcflags()
    return space.newlist(result_w)

def get_referrers(space, args_w):
    """Return the list of objects that directly refer to any of objs."""
    if not rgc.has_gcflag_extra():
        raise missing_operation(space)
    # xxx uses a lot of memory to make the list of all W_Root objects,
    # but it's simpler this way and more correct than the previous
    # version of this code (issue #2612).  It is potentially very slow
    # because each of the n calls to _list_w_obj_referents() could take
    # O(n) time as well, in theory, but I hope in practice the whole
    # thing takes much less than O(n^2).  We could re-add an algorithm
    # that visits most objects only once, if needed...
    space.audit('gc.get_referrers', args_w)
    all_objects_w = rgc.do_get_objects(try_cast_gcref_to_w_root)
    result_w = []
    for w_obj in all_objects_w:
        refs_w = []
        gcref = rgc.cast_instance_to_gcref(w_obj)
        _list_w_obj_referents(gcref, refs_w)
        for w_arg in args_w:
            if w_arg in refs_w:
                result_w.append(w_obj)
    rgc.assert_no_more_gcflags()
    return space.newlist(result_w)

@unwrap_spec(fd=int)
def _dump_rpy_heap(space, fd):
    try:
        ok = rgc.dump_rpy_heap(fd)
    except OSError as e:
        raise wrap_oserror(space, e)
    if not ok:
        raise missing_operation(space)

def get_typeids_z(space):
    a = rgc.get_typeids_z()
    s = ''.join([a[i] for i in range(len(a))])
    return space.newbytes(s)

def get_typeids_list(space):
    l = rgc.get_typeids_list()
    list_w = [space.newint(l[i]) for i in range(len(l))]
    return space.newlist(list_w)

class W_GcStats(W_Root):
    def __init__(self, memory_pressure):
        if memory_pressure:
            self.total_memory_pressure = rgc.get_stats(rgc.TOTAL_MEMORY_PRESSURE)
        else:
            self.total_memory_pressure = -1
        self.total_gc_memory = rgc.get_stats(rgc.TOTAL_MEMORY)
        self.total_allocated_memory = rgc.get_stats(rgc.TOTAL_ALLOCATED_MEMORY)
        self.peak_memory = rgc.get_stats(rgc.PEAK_MEMORY)
        self.peak_allocated_memory = rgc.get_stats(rgc.PEAK_ALLOCATED_MEMORY)
        self.jit_backend_allocated = jit_hooks.stats_asmmemmgr_allocated(None)
        self.jit_backend_used = jit_hooks.stats_asmmemmgr_used(None)
        self.total_arena_memory = rgc.get_stats(rgc.TOTAL_ARENA_MEMORY)
        self.total_rawmalloced_memory = rgc.get_stats(
            rgc.TOTAL_RAWMALLOCED_MEMORY)
        self.peak_arena_memory = rgc.get_stats(rgc.PEAK_ARENA_MEMORY)
        self.peak_rawmalloced_memory = rgc.get_stats(rgc.PEAK_RAWMALLOCED_MEMORY)
        self.nursery_size = rgc.get_stats(rgc.NURSERY_SIZE)
        self.total_gc_time = rgc.get_stats(rgc.TOTAL_GC_TIME)

W_GcStats.typedef = TypeDef("GcStats",
    total_memory_pressure=interp_attrproperty("total_memory_pressure",
        cls=W_GcStats, wrapfn="newint"),
    total_gc_memory=interp_attrproperty("total_gc_memory",
        cls=W_GcStats, wrapfn="newint"),
    peak_allocated_memory=interp_attrproperty("peak_allocated_memory",
        cls=W_GcStats, wrapfn="newint"),
    peak_memory=interp_attrproperty("peak_memory",
        cls=W_GcStats, wrapfn="newint"),
    total_allocated_memory=interp_attrproperty("total_allocated_memory",
        cls=W_GcStats, wrapfn="newint"),
    jit_backend_allocated=interp_attrproperty("jit_backend_allocated",
        cls=W_GcStats, wrapfn="newint"),
    jit_backend_used=interp_attrproperty("jit_backend_used",
        cls=W_GcStats, wrapfn="newint"),
    total_arena_memory=interp_attrproperty("total_arena_memory",
        cls=W_GcStats, wrapfn="newint"),
    total_rawmalloced_memory=interp_attrproperty("total_rawmalloced_memory",
        cls=W_GcStats, wrapfn="newint"),
    peak_arena_memory=interp_attrproperty("peak_arena_memory",
        cls=W_GcStats, wrapfn="newint"),
    peak_rawmalloced_memory=interp_attrproperty("peak_rawmalloced_memory",
        cls=W_GcStats, wrapfn="newint"),
    nursery_size=interp_attrproperty("nursery_size",
        cls=W_GcStats, wrapfn="newint"),
    total_gc_time=interp_attrproperty("total_gc_time",
        cls=W_GcStats, wrapfn="newint"),
)

@unwrap_spec(memory_pressure=bool)
def get_stats(space, memory_pressure=False):
    return W_GcStats(memory_pressure)
