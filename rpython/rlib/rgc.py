from __future__ import absolute_import

import gc
import types

from rpython.rlib import jit
from rpython.rlib.objectmodel import we_are_translated, enforceargs, specialize
from rpython.rlib.objectmodel import CDefinedIntSymbolic, not_rpython
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.lltypesystem import lltype, llmemory

# ____________________________________________________________
# General GC features

collect = gc.collect
enable = gc.enable
disable = gc.disable
isenabled = gc.isenabled

def collect_step():
    """
    If the GC is incremental, run a single gc-collect-step.

    Return an integer which encodes the starting and ending GC state. Use
    rgc.{old_state,new_state,is_done} to decode it.

    If the GC is not incremental, do a full collection and return a value on
    which rgc.is_done() return True.
    """
    gc.collect()
    return _encode_states(1, 0)

def _encode_states(oldstate, newstate):
    return oldstate << 8 | newstate

def old_state(states):
    return (states & 0xFF00) >> 8

def new_state(states):
    return states & 0xFF

def is_done(states):
    """
    Return True if the return value of collect_step signals the end of a major
    collection
    """
    old = old_state(states)
    new = new_state(states)
    return is_done__states(old, new)

def is_done__states(oldstate, newstate):
    "Like is_done, but takes oldstate and newstate explicitly"
    # a collection is considered done when it ends up in the starting state
    # (which is usually represented as 0). This logic works for incminimark,
    # which is currently the only gc actually used and for which collect_step
    # is implemented. In case we add more GC in the future, we might want to
    # delegate this logic to the GC itself, but for now it is MUCH simpler to
    # just write it in plain RPython.
    return oldstate != 0 and newstate == 0

def set_max_heap_size(nbytes):
    """Limit the heap size to n bytes.
    """
    pass

def must_split_gc_address_space():
    """Returns True if we have a "split GC address space", i.e. if
    we are translating with an option that doesn't support taking raw
    addresses inside GC objects and "hacking" at them.  This is
    notably the case with --revdb."""
    return False

# for test purposes we allow objects to be pinned and use
# the following list to keep track of the pinned objects
_pinned_objects = []

def pin(obj):
    """If 'obj' can move, then attempt to temporarily fix it.  This
    function returns True if and only if 'obj' could be pinned; this is
    a special state in the GC.  Note that can_move(obj) still returns
    True even on pinned objects, because once unpinned it will indeed be
    able to move again.  In other words, the code that succeeded in
    pinning 'obj' can assume that it won't move until the corresponding
    call to unpin(obj), despite can_move(obj) still being True.  (This
    is important if multiple threads try to os.write() the same string:
    only one of them will succeed in pinning the string.)

    It is expected that the time between pinning and unpinning an object
    is short. Therefore the expected use case is a single function
    invoking pin(obj) and unpin(obj) only a few lines of code apart.

    Note that this can return False for any reason, e.g. if the 'obj' is
    already non-movable or already pinned, if the GC doesn't support
    pinning, or if there are too many pinned objects.

    Note further that pinning an object does not prevent it from being
    collected if it is not used anymore.
    """
    _pinned_objects.append(obj)
    return True
        

class PinEntry(ExtRegistryEntry):
    _about_ = pin

    def compute_result_annotation(self, s_obj):
        from rpython.annotator import model as annmodel
        return annmodel.SomeBool()

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc_pin', hop.args_v, resulttype=hop.r_result)

def unpin(obj):
    """Unpin 'obj', allowing it to move again.
    Must only be called after a call to pin(obj) returned True.
    """
    for i in range(len(_pinned_objects)):
        try:
            if _pinned_objects[i] == obj:
                del _pinned_objects[i]
                return
        except TypeError:
            pass


class UnpinEntry(ExtRegistryEntry):
    _about_ = unpin

    def compute_result_annotation(self, s_obj):
        pass

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        hop.genop('gc_unpin', hop.args_v)

def _is_pinned(obj):
    """Method to check if 'obj' is pinned."""
    for i in range(len(_pinned_objects)):
        try:
            if _pinned_objects[i] == obj:
                return True
        except TypeError:
            pass
    return False


class IsPinnedEntry(ExtRegistryEntry):
    _about_ = _is_pinned

    def compute_result_annotation(self, s_obj):
        from rpython.annotator import model as annmodel
        return annmodel.SomeBool()

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc__is_pinned', hop.args_v, resulttype=hop.r_result)

# ____________________________________________________________
# Annotation and specialization

# Support for collection.

class CollectEntry(ExtRegistryEntry):
    _about_ = gc.collect

    def compute_result_annotation(self, s_gen=None):
        from rpython.annotator import model as annmodel
        return annmodel.s_None

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        args_v = []
        if len(hop.args_s) == 1:
            args_v = hop.inputargs(lltype.Signed)
        return hop.genop('gc__collect', args_v, resulttype=hop.r_result)


class EnableDisableEntry(ExtRegistryEntry):
    _about_ = (gc.enable, gc.disable)

    def compute_result_annotation(self):
        from rpython.annotator import model as annmodel
        return annmodel.s_None

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        opname = self.instance.__name__
        return hop.genop('gc__%s' % opname, hop.args_v, resulttype=hop.r_result)


class IsEnabledEntry(ExtRegistryEntry):
    _about_ = gc.isenabled

    def compute_result_annotation(self):
        from rpython.annotator import model as annmodel
        return annmodel.s_Bool

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc__isenabled', hop.args_v, resulttype=hop.r_result)


class CollectStepEntry(ExtRegistryEntry):
    _about_ = collect_step

    def compute_result_annotation(self):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc__collect_step', hop.args_v, resulttype=hop.r_result)


class SetMaxHeapSizeEntry(ExtRegistryEntry):
    _about_ = set_max_heap_size

    def compute_result_annotation(self, s_nbytes):
        from rpython.annotator import model as annmodel
        return annmodel.s_None

    def specialize_call(self, hop):
        [v_nbytes] = hop.inputargs(lltype.Signed)
        hop.exception_cannot_occur()
        return hop.genop('gc_set_max_heap_size', [v_nbytes],
                         resulttype=lltype.Void)

def can_move(p):
    """Check if the GC object 'p' is at an address that can move.
    Must not be called with None.  With non-moving GCs, it is always False.
    With some moving GCs like the SemiSpace GC, it is always True.
    With other moving GCs like the MiniMark GC, it can be True for some
    time, then False for the same object, when we are sure that it won't
    move any more.
    """
    return True

class SplitAddrSpaceEntry(ExtRegistryEntry):
    _about_ = must_split_gc_address_space
 
    def compute_result_annotation(self):
        config = self.bookkeeper.annotator.translator.config
        result = config.translation.split_gc_address_space
        return self.bookkeeper.immutablevalue(result)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Bool, hop.s_result.const)

class CanMoveEntry(ExtRegistryEntry):
    _about_ = can_move

    def compute_result_annotation(self, s_p):
        from rpython.annotator import model as annmodel
        return annmodel.SomeBool()

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc_can_move', hop.args_v, resulttype=hop.r_result)

def _make_sure_does_not_move(p):
    """'p' is a non-null GC object.  This (tries to) make sure that the
    object does not move any more, by forcing collections if needed.
    Warning: should ideally only be used with the minimark GC, and only
    on objects that are already a bit old, so have a chance to be
    already non-movable."""
    assert p
    if not we_are_translated():
        # for testing purpose
        return not _is_pinned(p)
    #
    if _is_pinned(p):
        # although a pinned object can't move we must return 'False'.  A pinned
        # object can be unpinned any time and becomes movable.
        return False
    i = -1
    while can_move(p):
        if i > 6:
            raise NotImplementedError("can't make object non-movable!")
        collect(i)
        i += 1
    return True

def needs_write_barrier(obj):
    """ We need to emit write barrier if the right hand of assignment
    is in nursery, used by the JIT for handling set*_gc(Const)
    """
    if not obj:
        return False
    # XXX returning can_move() here might acidentally work for the use
    # cases (see issue #2212), but this is not really safe.  Now we
    # just return True for any non-NULL pointer, and too bad for the
    # few extra 'cond_call_gc_wb'.  It could be improved e.g. to return
    # False if 'obj' is a static prebuilt constant, or if we're not
    # running incminimark...
    return True #can_move(obj)

def _heap_stats():
    raise NotImplementedError # can't be run directly

class DumpHeapEntry(ExtRegistryEntry):
    _about_ = _heap_stats

    def compute_result_annotation(self):
        from rpython.rtyper.llannotation import SomePtr
        from rpython.memory.gc.base import ARRAY_TYPEID_MAP
        return SomePtr(lltype.Ptr(ARRAY_TYPEID_MAP))

    def specialize_call(self, hop):
        hop.exception_is_here()
        return hop.genop('gc_heap_stats', [], resulttype=hop.r_result)


def copy_struct_item(source, dest, si, di):
    TP = lltype.typeOf(source).TO.OF
    i = 0
    while i < len(TP._names):
        setattr(dest[di], TP._names[i], getattr(source[si], TP._names[i]))
        i += 1

class CopyStructEntry(ExtRegistryEntry):
    _about_ = copy_struct_item

    def compute_result_annotation(self, s_source, s_dest, si, di):
        pass

    def specialize_call(self, hop):
        v_source, v_dest, v_si, v_di = hop.inputargs(hop.args_r[0],
                                                     hop.args_r[1],
                                                     lltype.Signed,
                                                     lltype.Signed)
        hop.exception_cannot_occur()
        TP = v_source.concretetype.TO.OF
        for name, TP in TP._flds.iteritems():
            c_name = hop.inputconst(lltype.Void, name)
            v_fld = hop.genop('getinteriorfield', [v_source, v_si, c_name],
                              resulttype=TP)
            hop.genop('setinteriorfield', [v_dest, v_di, c_name, v_fld])


@specialize.ll()
def copy_item(source, dest, si, di):
    TP = lltype.typeOf(source)
    if isinstance(TP.TO.OF, lltype.Struct):
        copy_struct_item(source, dest, si, di)
    else:
        dest[di] = source[si]

@specialize.memo()
def _contains_gcptr(TP):
    if not isinstance(TP, lltype.Struct):
        if isinstance(TP, lltype.Ptr) and TP.TO._gckind == 'gc':
            return True
        return False
    for TP in TP._flds.itervalues():
        if _contains_gcptr(TP):
            return True
    return False


@jit.oopspec('list.ll_arraycopy(source, dest, source_start, dest_start, length)')
@enforceargs(None, None, int, int, int)
@specialize.ll()
def ll_arraycopy(source, dest, source_start, dest_start, length):
    from rpython.rtyper.lltypesystem.lloperation import llop
    from rpython.rlib.objectmodel import keepalive_until_here

    # XXX: Hack to ensure that we get a proper effectinfo.write_descrs_arrays
    # and also, maybe, speed up very small cases
    if length <= 1:
        if length == 1:
            copy_item(source, dest, source_start, dest_start)
        return

    # supports non-overlapping copies only
    if not we_are_translated():
        if source == dest:
            assert (source_start + length <= dest_start or
                    dest_start + length <= source_start)

    TP = lltype.typeOf(source).TO
    assert TP == lltype.typeOf(dest).TO

    slowpath = False
    if must_split_gc_address_space():
        slowpath = True
    elif _contains_gcptr(TP.OF):
        # perform a write barrier that copies necessary flags from
        # source to dest
        if not llop.gc_writebarrier_before_copy(lltype.Bool, source, dest,
                                                source_start, dest_start,
                                                length):
            slowpath = True
    if slowpath:
        # if the write barrier is not supported, or if we translate with
        # the option 'split_gc_address_space', then copy by hand
        i = 0
        while i < length:
            copy_item(source, dest, i + source_start, i + dest_start)
            i += 1
        return
    source_addr = llmemory.cast_ptr_to_adr(source)
    dest_addr   = llmemory.cast_ptr_to_adr(dest)
    cp_source_addr = (source_addr + llmemory.itemoffsetof(TP, 0) +
                      llmemory.sizeof(TP.OF) * source_start)
    cp_dest_addr = (dest_addr + llmemory.itemoffsetof(TP, 0) +
                    llmemory.sizeof(TP.OF) * dest_start)

    llmemory.raw_memcopy(cp_source_addr, cp_dest_addr,
                         llmemory.sizeof(TP.OF) * length)
    keepalive_until_here(source)
    keepalive_until_here(dest)

@jit.oopspec('list.ll_arraymove(array, source_start, dest_start, length)')
@enforceargs(None, int, int, int)
@specialize.ll()
def ll_arraymove(array, source_start, dest_start, length):
    from rpython.rtyper.lltypesystem.lloperation import llop
    from rpython.rlib.objectmodel import keepalive_until_here

    # XXX: Hack to ensure that we get a proper effectinfo.write_descrs_arrays
    # and also, maybe, speed up very small cases
    if length <= 1:
        if length == 1:
            copy_item(array, array, source_start, dest_start)
        return

    TP = lltype.typeOf(array).TO

    slowpath = False
    if must_split_gc_address_space():
        slowpath = True
    elif _contains_gcptr(TP.OF):
        # if the array has card marks set, then this will perform a
        # general (card-less) write barrier on it, because the marked cards
        # are no longer necessarily the right ones after the move.
        # Otherwise, if the GC doesn't support cards, this is a no-op,
        # because we're not writing any new GC pointer into the array:
        # we're just moving existing ones around.
        llop.gc_writebarrier_before_move(lltype.Void, array)
    if slowpath:
        # if we translate with the option 'split_gc_address_space',
        # then move by hand
        delta = dest_start - source_start
        if delta < 0:
            i = source_start
            stop = source_start + length
            while i < stop:
                copy_item(array, array, i, i + delta)
                i += 1
        elif delta > 0:
            i = source_start + length
            while i > source_start:
                i -= 1
                copy_item(array, array, i, i + delta)
        return
    array_addr = llmemory.cast_ptr_to_adr(array)
    mv_source_addr = (array_addr + llmemory.itemoffsetof(TP, 0) +
                      llmemory.sizeof(TP.OF) * source_start)
    mv_dest_addr = (array_addr + llmemory.itemoffsetof(TP, 0) +
                    llmemory.sizeof(TP.OF) * dest_start)

    llmemory.raw_memmove_no_free(mv_source_addr, mv_dest_addr,
                                 llmemory.sizeof(TP.OF) * length)
    keepalive_until_here(array)

@jit.oopspec('rgc.ll_shrink_array(p, smallerlength)')
@enforceargs(None, int)
@specialize.ll()
def ll_shrink_array(p, smallerlength):
    from rpython.rtyper.lltypesystem.lloperation import llop
    from rpython.rlib.objectmodel import keepalive_until_here

    if llop.shrink_array(lltype.Bool, p, smallerlength):
        return p    # done by the GC
    # XXX we assume for now that the type of p is GcStruct containing a
    # variable array, with no further pointers anywhere, and exactly one
    # field in the fixed part -- like STR and UNICODE.

    TP = lltype.typeOf(p).TO
    newp = lltype.malloc(TP, smallerlength)

    assert len(TP._names) == 2
    field = getattr(p, TP._names[0])
    setattr(newp, TP._names[0], field)

    if must_split_gc_address_space():
        # do the copying element by element
        i = 0
        while i < smallerlength:
            newp.chars[i] = p.chars[i]
            i += 1
        return newp

    ARRAY = getattr(TP, TP._arrayfld)
    offset = (llmemory.offsetof(TP, TP._arrayfld) +
              llmemory.itemoffsetof(ARRAY, 0))
    source_addr = llmemory.cast_ptr_to_adr(p) + offset
    dest_addr = llmemory.cast_ptr_to_adr(newp) + offset
    llmemory.raw_memcopy(source_addr, dest_addr,
                         llmemory.sizeof(ARRAY.OF) * smallerlength)

    keepalive_until_here(p)
    keepalive_until_here(newp)
    return newp

@jit.dont_look_inside
@specialize.ll()
def ll_arrayclear(p):
    # Equivalent to memset(array, 0).  Only for GcArray(primitive-type) for now.
    from rpython.rlib.objectmodel import keepalive_until_here

    length = len(p)
    ARRAY = lltype.typeOf(p).TO
    if must_split_gc_address_space():
        # do the clearing element by element
        from rpython.rtyper.lltypesystem import rffi
        ZERO = rffi.cast(ARRAY.OF, 0)
        i = 0
        while i < length:
            p[i] = ZERO
            i += 1
    else:
        offset = llmemory.itemoffsetof(ARRAY, 0)
        dest_addr = llmemory.cast_ptr_to_adr(p) + offset
        llmemory.raw_memclear(dest_addr, llmemory.sizeof(ARRAY.OF) * length)
    keepalive_until_here(p)


def no_release_gil(func):
    func._dont_inline_ = True
    func._no_release_gil_ = True
    return func

def no_collect(func):
    func._dont_inline_ = True
    func._gc_no_collect_ = True
    return func

def must_be_light_finalizer(func):
    """Mark a __del__ method as being a destructor, calling only a limited
    set of operations.  See pypy/doc/discussion/finalizer-order.rst.  

    If you use the same decorator on a class, this class and all its
    subclasses are only allowed to have __del__ methods which are
    similarly decorated (or no __del__ at all).  It prevents a class
    hierarchy from having destructors in some parent classes, which are
    overridden in subclasses with (non-light, old-style) finalizers.  
    (This case is the original motivation for FinalizerQueue.)
    """
    func._must_be_light_finalizer_ = True
    return func


class FinalizerQueue(object):
    """A finalizer queue.  See pypy/doc/discussion/finalizer-order.rst.
    """
    # Must be subclassed, and the subclass needs these attributes:
    #
    #    Class:
    #        the class (or base class) of finalized objects
    #        --or-- None to handle low-level GCREFs directly
    #
    #    def finalizer_trigger(self):
    #        called to notify that new items have been put in the queue

    def _freeze_(self):
        return True

    @specialize.arg(0)
    @jit.dont_look_inside
    def next_dead(self):
        if we_are_translated():
            from rpython.rtyper.lltypesystem.lloperation import llop
            from rpython.rtyper.lltypesystem.llmemory import GCREF
            from rpython.rtyper.annlowlevel import cast_gcref_to_instance
            tag = FinalizerQueue._get_tag(self)
            ptr = llop.gc_fq_next_dead(GCREF, tag)
            if self.Class is not None:
                ptr = cast_gcref_to_instance(self.Class, ptr)
            return ptr
        try:
            return self._queue.popleft()
        except (AttributeError, IndexError):
            return None

    @specialize.arg(0)
    @jit.dont_look_inside
    def register_finalizer(self, obj):
        from rpython.rtyper.lltypesystem.llmemory import GCREF
        if self.Class is None:
            assert lltype.typeOf(obj) == GCREF
        else:
            assert isinstance(obj, self.Class)
        if we_are_translated():
            from rpython.rtyper.lltypesystem.lloperation import llop
            from rpython.rtyper.annlowlevel import cast_instance_to_gcref
            tag = FinalizerQueue._get_tag(self)
            if self.Class is not None:
                obj = cast_instance_to_gcref(obj)
            llop.gc_fq_register(lltype.Void, tag, obj)
            return
        else:
            self._untranslated_register_finalizer(obj)

    @not_rpython
    def _get_tag(self):
        "special-cased below"

    def _reset(self):
        import collections
        self._weakrefs = set()
        self._queue = collections.deque()

    def _already_registered(self, obj):
        return hasattr(obj, '__enable_del_for_id')

    def _untranslated_register_finalizer(self, obj):
        assert not self._already_registered(obj)

        if not hasattr(self, '_queue'):
            self._reset()

        # Fetch and check the type of 'obj'
        objtyp = obj.__class__
        assert isinstance(objtyp, type), (
            "%r: to run register_finalizer() untranslated, "
            "the object's class must be new-style" % (obj,))
        assert hasattr(obj, '__dict__'), (
            "%r: to run register_finalizer() untranslated, "
            "the object must have a __dict__" % (obj,))
        assert (not hasattr(obj, '__slots__') or
                type(obj).__slots__ == () or
                type(obj).__slots__ == ('__weakref__',)), (
            "%r: to run register_finalizer() untranslated, "
            "the object must not have __slots__" % (obj,))

        # The first time, patch the method __del__ of the class, if
        # any, so that we can disable it on the original 'obj' and
        # enable it only on the 'newobj'
        _fq_patch_class(objtyp)

        # Build a new shadow object with the same class and dict
        newobj = object.__new__(objtyp)
        obj.__dict__ = obj.__dict__.copy() #PyPy: break the dict->obj dependency
        newobj.__dict__ = obj.__dict__

        # A callback that is invoked when (or after) 'obj' is deleted;
        # 'newobj' is still kept alive here
        def callback(wr):
            self._weakrefs.discard(wr)
            self._queue.append(newobj)
            self.finalizer_trigger()

        import weakref
        wr = weakref.ref(obj, callback)
        self._weakrefs.add(wr)

        # Disable __del__ on the original 'obj' and enable it only on
        # the 'newobj'.  Use id() and not a regular reference, because
        # that would make a cycle between 'newobj' and 'obj.__dict__'
        # (which is 'newobj.__dict__' too).
        setattr(obj, '__enable_del_for_id', id(newobj))


def _fq_patch_class(Cls):
    if Cls in _fq_patched_classes:
        return
    if '__del__' in Cls.__dict__:
        def __del__(self):
            if not we_are_translated():
                try:
                    if getattr(self, '__enable_del_for_id') != id(self):
                        return
                except AttributeError:
                    pass
            original_del(self)
        original_del = Cls.__del__
        Cls.__del__ = __del__
        _fq_patched_classes.add(Cls)
    for BaseCls in Cls.__bases__:
        _fq_patch_class(BaseCls)

_fq_patched_classes = set()

class FqTagEntry(ExtRegistryEntry):
    _about_ = FinalizerQueue._get_tag.im_func

    def compute_result_annotation(self, s_fq):
        assert s_fq.is_constant()
        fq = s_fq.const
        s_func = self.bookkeeper.immutablevalue(fq.finalizer_trigger)
        self.bookkeeper.emulate_pbc_call(self.bookkeeper.position_key,
                                         s_func, [])
        if not hasattr(fq, '_fq_tag'):
            fq._fq_tag = CDefinedIntSymbolic(
                '0 /*FinalizerQueue TAG for %s*/' % fq.__class__.__name__,
                default=fq)
        return self.bookkeeper.immutablevalue(fq._fq_tag)

    def specialize_call(self, hop):
        from rpython.rtyper.rclass import InstanceRepr
        translator = hop.rtyper.annotator.translator
        fq = hop.args_s[0].const
        graph = translator._graphof(fq.finalizer_trigger.im_func)
        InstanceRepr.check_graph_of_del_does_not_call_too_much(hop.rtyper,
                                                               graph)
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Signed, hop.s_result.const)

@jit.dont_look_inside
@specialize.argtype(0)
def may_ignore_finalizer(obj):
    """Optimization hint: says that it is valid for any finalizer
    for 'obj' to be ignored, depending on the GC."""
    from rpython.rtyper.lltypesystem.lloperation import llop
    llop.gc_ignore_finalizer(lltype.Void, obj)

@jit.dont_look_inside
def move_out_of_nursery(obj):
    """ Returns another object which is a copy of obj; but at any point
        (either now or in the future) the returned object might suddenly
        become identical to the one returned.

        NOTE: Only use for immutable objects!

        NOTE: Might fail on some GCs!  You have to check again
        can_move() afterwards.  It should always work with the default
        GC.  With Boehm, can_move() is always False so
        move_out_of_nursery() should never be called in the first place.
    """
    return obj

class MoveOutOfNurseryEntry(ExtRegistryEntry):
    _about_ = move_out_of_nursery

    def compute_result_annotation(self, s_obj):
        return s_obj

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc_move_out_of_nursery', hop.args_v, resulttype=hop.r_result)

@jit.dont_look_inside
def increase_root_stack_depth(new_depth):
    """Shadowstack: make sure the size of the shadowstack is at least
    'new_depth' pointers."""
    from rpython.rtyper.lltypesystem.lloperation import llop
    llop.gc_increase_root_stack_depth(lltype.Void, new_depth)

# ____________________________________________________________


@not_rpython
def get_rpy_roots():
    # Return the 'roots' from the GC.
    # The gc typically returns a list that ends with a few NULL_GCREFs.
    return [_GcRef(x) for x in gc.get_objects()]

@not_rpython
def get_rpy_referents(gcref):
    x = gcref._x
    if isinstance(x, list):
        d = x
    elif isinstance(x, dict):
        d = x.keys() + x.values()
    else:
        d = []
        if hasattr(x, '__dict__'):
            d = x.__dict__.values()
        if hasattr(type(x), '__slots__'):
            for slot in type(x).__slots__:
                try:
                    d.append(getattr(x, slot))
                except AttributeError:
                    pass
    # discard objects that are too random or that are _freeze_=True
    return [_GcRef(x) for x in d if _keep_object(x)]

def _keep_object(x):
    if isinstance(x, type) or type(x) is types.ClassType:
        return False      # don't keep any type
    if isinstance(x, (list, dict, str)):
        return True       # keep lists and dicts and strings
    if hasattr(x, '_freeze_'):
        return False
    return type(x).__module__ != '__builtin__'   # keep non-builtins

def add_memory_pressure(estimate, object=None):
    """Add memory pressure for OpaquePtrs."""
    pass

class AddMemoryPressureEntry(ExtRegistryEntry):
    _about_ = add_memory_pressure

    def compute_result_annotation(self, s_nbytes, s_object=None):
        from rpython.annotator import model as annmodel
        if s_object is not None:
            if not isinstance(s_object, annmodel.SomeInstance):
                raise Exception("Wrong kind of object passed to "
                                "add memory pressure")
            self.bookkeeper.memory_pressure_types.add(s_object.classdef)
        return annmodel.s_None

    def specialize_call(self, hop):
        v_size = hop.inputarg(lltype.Signed, 0)
        if len(hop.args_v) == 2:
            v_obj = hop.inputarg(hop.args_r[1], 1)
            args = [v_size, v_obj]
        else:
            args = [v_size]
        hop.exception_cannot_occur()
        return hop.genop('gc_add_memory_pressure', args,
                         resulttype=lltype.Void)


@not_rpython
def get_rpy_memory_usage(gcref):
    # approximate implementation using CPython's type info
    Class = type(gcref._x)
    size = Class.__basicsize__
    if Class.__itemsize__ > 0:
        size += Class.__itemsize__ * len(gcref._x)
    return size

@not_rpython
def get_rpy_type_index(gcref):
    from rpython.rlib.rarithmetic import intmask
    Class = gcref._x.__class__
    i = intmask(id(Class))
    if i < 0:
        i = ~i    # always return a positive number, at least
    return i

def cast_gcref_to_int(gcref):
    # This is meant to be used on cast_instance_to_gcref results.
    # Don't use this on regular gcrefs obtained e.g. with
    # lltype.cast_opaque_ptr().
    if we_are_translated():
        return lltype.cast_ptr_to_int(gcref)
    else:
        return id(gcref._x)

(TOTAL_MEMORY, TOTAL_ALLOCATED_MEMORY, TOTAL_MEMORY_PRESSURE,
 PEAK_MEMORY, PEAK_ALLOCATED_MEMORY, TOTAL_ARENA_MEMORY,
 TOTAL_RAWMALLOCED_MEMORY, PEAK_ARENA_MEMORY, PEAK_RAWMALLOCED_MEMORY,
 NURSERY_SIZE, TOTAL_GC_TIME) = range(11)

@not_rpython
def get_stats(stat_no):
    """ Long docstring goes here
    """
    raise NotImplementedError

@not_rpython
def dump_rpy_heap(fd):
    raise NotImplementedError

@not_rpython
def get_typeids_z():
    raise NotImplementedError

@not_rpython
def get_typeids_list():
    raise NotImplementedError

@not_rpython
def has_gcflag_extra():
    return True
has_gcflag_extra._subopnum = 1

_gcflag_extras = set()

@not_rpython
def get_gcflag_extra(gcref):
    assert gcref   # not NULL!
    return gcref in _gcflag_extras
get_gcflag_extra._subopnum = 2

@not_rpython
def toggle_gcflag_extra(gcref):
    assert gcref   # not NULL!
    try:
        _gcflag_extras.remove(gcref)
    except KeyError:
        _gcflag_extras.add(gcref)
toggle_gcflag_extra._subopnum = 3

@not_rpython
def get_gcflag_dummy(gcref):
    return False
get_gcflag_dummy._subopnum = 4

def assert_no_more_gcflags():
    if not we_are_translated():
        assert not _gcflag_extras

ARRAY_OF_CHAR = lltype.Array(lltype.Char)
NULL_GCREF = lltype.nullptr(llmemory.GCREF.TO)

class _GcRef(object):
    # implementation-specific: there should not be any after translation
    __slots__ = ['_x', '_handle']
    _TYPE = llmemory.GCREF
    def __init__(self, x):
        self._x = x
    def __hash__(self):
        return object.__hash__(self._x)
    def __eq__(self, other):
        if isinstance(other, lltype._ptr):
            assert other == NULL_GCREF, (
                "comparing a _GcRef with a non-NULL lltype ptr")
            return False
        assert isinstance(other, _GcRef)
        return self._x is other._x
    def __ne__(self, other):
        return not self.__eq__(other)
    def __repr__(self):
        return "_GcRef(%r)" % (self._x, )
    def _freeze_(self):
        raise Exception("instances of rlib.rgc._GcRef cannot be translated")

def cast_instance_to_gcref(x):
    # Before translation, casts an RPython instance into a _GcRef.
    # After translation, it is a variant of cast_object_to_ptr(GCREF).
    if we_are_translated():
        from rpython.rtyper import annlowlevel
        x = annlowlevel.cast_instance_to_base_ptr(x)
        return lltype.cast_opaque_ptr(llmemory.GCREF, x)
    else:
        return _GcRef(x)
cast_instance_to_gcref._annspecialcase_ = 'specialize:argtype(0)'

def try_cast_gcref_to_instance(Class, gcref):
    # Before translation, unwraps the RPython instance contained in a _GcRef.
    # After translation, it is a type-check performed by the GC.
    if we_are_translated():
        from rpython.rtyper.rclass import OBJECTPTR, ll_isinstance
        from rpython.rtyper.annlowlevel import cast_base_ptr_to_instance
        if _is_rpy_instance(gcref):
            objptr = lltype.cast_opaque_ptr(OBJECTPTR, gcref)
            if objptr.typeptr:   # may be NULL, e.g. in rdict's dummykeyobj
                clsptr = _get_llcls_from_cls(Class)
                if ll_isinstance(objptr, clsptr):
                    return cast_base_ptr_to_instance(Class, objptr)
        return None
    else:
        if isinstance(gcref._x, Class):
            return gcref._x
        return None
try_cast_gcref_to_instance._annspecialcase_ = 'specialize:arg(0)'

_ffi_cache = None
def _fetch_ffi():
    global _ffi_cache
    if _ffi_cache is None:
        try:
            import _cffi_backend
            _ffi_cache = _cffi_backend.FFI()
        except (ImportError, AttributeError):
            import py
            py.test.skip("need CFFI >= 1.0")
    return _ffi_cache

@jit.dont_look_inside
def hide_nonmovable_gcref(gcref):
    from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
    if we_are_translated():
        assert lltype.typeOf(gcref) == llmemory.GCREF
        assert not can_move(gcref)
        return rffi.cast(llmemory.Address, gcref)
    else:
        assert isinstance(gcref, _GcRef)
        x = gcref._x
        ffi = _fetch_ffi()
        if not hasattr(x, '__handle'):
            x.__handle = ffi.new_handle(x)
        addr = int(ffi.cast("intptr_t", x.__handle))
        return rffi.cast(llmemory.Address, addr)

@jit.dont_look_inside
def reveal_gcref(addr):
    from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
    assert lltype.typeOf(addr) == llmemory.Address
    if we_are_translated():
        return rffi.cast(llmemory.GCREF, addr)
    else:
        addr = rffi.cast(lltype.Signed, addr)
        if addr == 0:
            return lltype.nullptr(llmemory.GCREF.TO)
        ffi = _fetch_ffi()
        x = ffi.from_handle(ffi.cast("void *", addr))
        return _GcRef(x)

# ------------------- implementation -------------------

_cache_s_list_of_gcrefs = None

def s_list_of_gcrefs():
    global _cache_s_list_of_gcrefs
    if _cache_s_list_of_gcrefs is None:
        from rpython.annotator import model as annmodel
        from rpython.rtyper.llannotation import SomePtr
        from rpython.annotator.listdef import ListDef
        s_gcref = SomePtr(llmemory.GCREF)
        _cache_s_list_of_gcrefs = annmodel.SomeList(
            ListDef(None, s_gcref, mutated=True, resized=False))
    return _cache_s_list_of_gcrefs

class Entry(ExtRegistryEntry):
    _about_ = get_rpy_roots
    def compute_result_annotation(self):
        return s_list_of_gcrefs()
    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc_get_rpy_roots', [], resulttype = hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = get_rpy_referents

    def compute_result_annotation(self, s_gcref):
        from rpython.rtyper.llannotation import SomePtr
        assert SomePtr(llmemory.GCREF).contains(s_gcref)
        return s_list_of_gcrefs()

    def specialize_call(self, hop):
        vlist = hop.inputargs(hop.args_r[0])
        hop.exception_cannot_occur()
        return hop.genop('gc_get_rpy_referents', vlist,
                         resulttype=hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = get_rpy_memory_usage
    def compute_result_annotation(self, s_gcref):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()
    def specialize_call(self, hop):
        vlist = hop.inputargs(hop.args_r[0])
        hop.exception_cannot_occur()
        return hop.genop('gc_get_rpy_memory_usage', vlist,
                         resulttype = hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = get_rpy_type_index
    def compute_result_annotation(self, s_gcref):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()
    def specialize_call(self, hop):
        vlist = hop.inputargs(hop.args_r[0])
        hop.exception_cannot_occur()
        return hop.genop('gc_get_rpy_type_index', vlist,
                         resulttype = hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = get_stats
    def compute_result_annotation(self, s_no):
        from rpython.annotator.model import SomeInteger
        if not isinstance(s_no, SomeInteger):
            raise Exception("expecting an integer")
        return SomeInteger()
    def specialize_call(self, hop):
        args = hop.inputargs(lltype.Signed)
        hop.exception_cannot_occur()
        return hop.genop('gc_get_stats', args, resulttype=lltype.Signed)

@not_rpython
def _is_rpy_instance(gcref):
    raise NotImplementedError

@not_rpython
def _get_llcls_from_cls(Class):
    raise NotImplementedError

class Entry(ExtRegistryEntry):
    _about_ = _is_rpy_instance
    def compute_result_annotation(self, s_gcref):
        from rpython.annotator import model as annmodel
        return annmodel.SomeBool()
    def specialize_call(self, hop):
        vlist = hop.inputargs(hop.args_r[0])
        hop.exception_cannot_occur()
        return hop.genop('gc_is_rpy_instance', vlist,
                         resulttype = hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = _get_llcls_from_cls
    def compute_result_annotation(self, s_Class):
        from rpython.rtyper.llannotation import SomePtr
        from rpython.rtyper.rclass import CLASSTYPE
        assert s_Class.is_constant()
        return SomePtr(CLASSTYPE)

    def specialize_call(self, hop):
        from rpython.rtyper.rclass import getclassrepr, CLASSTYPE
        from rpython.flowspace.model import Constant
        Class = hop.args_s[0].const
        classdef = hop.rtyper.annotator.bookkeeper.getuniqueclassdef(Class)
        classrepr = getclassrepr(hop.rtyper, classdef)
        vtable = classrepr.getvtable()
        assert lltype.typeOf(vtable) == CLASSTYPE
        hop.exception_cannot_occur()
        return Constant(vtable, concretetype=CLASSTYPE)

class Entry(ExtRegistryEntry):
    _about_ = dump_rpy_heap
    def compute_result_annotation(self, s_fd):
        from rpython.annotator.model import s_Bool
        return s_Bool
    def specialize_call(self, hop):
        vlist = hop.inputargs(lltype.Signed)
        hop.exception_is_here()
        return hop.genop('gc_dump_rpy_heap', vlist, resulttype = hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = get_typeids_z

    def compute_result_annotation(self):
        from rpython.rtyper.llannotation import SomePtr
        return SomePtr(lltype.Ptr(ARRAY_OF_CHAR))

    def specialize_call(self, hop):
        hop.exception_is_here()
        return hop.genop('gc_typeids_z', [], resulttype = hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = get_typeids_list

    def compute_result_annotation(self):
        from rpython.rtyper.llannotation import SomePtr
        from rpython.rtyper.lltypesystem import llgroup
        return SomePtr(lltype.Ptr(lltype.Array(llgroup.HALFWORD)))

    def specialize_call(self, hop):
        hop.exception_is_here()
        return hop.genop('gc_typeids_list', [], resulttype = hop.r_result)

class Entry(ExtRegistryEntry):
    _about_ = (has_gcflag_extra, get_gcflag_extra, toggle_gcflag_extra,
               get_gcflag_dummy)
    def compute_result_annotation(self, s_arg=None):
        from rpython.annotator.model import s_Bool
        return s_Bool
    def specialize_call(self, hop):
        subopnum = self.instance._subopnum
        vlist = [hop.inputconst(lltype.Signed, subopnum)]
        vlist += hop.inputargs(*hop.args_r)
        hop.exception_cannot_occur()
        return hop.genop('gc_gcflag_extra', vlist, resulttype = hop.r_result)

def lltype_is_gc(TP):
    return getattr(getattr(TP, "TO", None), "_gckind", "?") == 'gc'

def register_custom_trace_hook(TP, lambda_func):
    """ This function does not do anything, but called from any annotated
    place, will tell that "func" is used to trace GC roots inside any instance
    of the type TP.  The func must be specified as "lambda: func" in this
    call, for internal reasons.  Note that the func will be automatically
    specialized on the 'callback' argument value.  Example:

        def customtrace(gc, obj, callback, arg):
            gc._trace_callback(callback, arg, obj + offset_of_x)
        lambda_customtrace = lambda: customtrace
    """

@specialize.ll()
def ll_writebarrier(gc_obj):
    """Use together with custom tracers.  When you update some object pointer
    stored in raw memory, you must call this function on 'gc_obj', which must
    be the object of type TP with the custom tracer (*not* the value stored!).
    This makes sure that the custom hook will be called again."""
    from rpython.rtyper.lltypesystem.lloperation import llop
    llop.gc_writebarrier(lltype.Void, gc_obj)

class RegisterGcTraceEntry(ExtRegistryEntry):
    _about_ = register_custom_trace_hook

    def compute_result_annotation(self, s_tp, s_lambda_func):
        pass

    def specialize_call(self, hop):
        TP = hop.args_s[0].const
        lambda_func = hop.args_s[1].const
        hop.exception_cannot_occur()
        hop.rtyper.custom_trace_funcs.append((TP, lambda_func()))

def register_custom_light_finalizer(TP, lambda_func):
    """ This function does not do anything, but called from any annotated
    place, will tell that "func" is used as a lightweight finalizer for TP.
    The func must be specified as "lambda: func" in this call, for internal
    reasons.
    """

@specialize.arg(0)
def do_get_objects(callback):
    """ Get all the objects that satisfy callback(gcref) -> obj
    """
    roots = get_rpy_roots()
    if not roots:      # is always None on translations using Boehm or None GCs
        return []
    roots = [gcref for gcref in roots if gcref]
    result_w = []
    #
    if not we_are_translated():   # fast path before translation
        seen = set()
        while roots:
            gcref = roots.pop()
            if gcref not in seen:
                seen.add(gcref)
                w_obj = callback(gcref)
                if w_obj is not None:
                    result_w.append(w_obj)
                roots.extend(get_rpy_referents(gcref))
        return result_w
    #
    pending = roots[:]
    while pending:
        gcref = pending.pop()
        if not get_gcflag_extra(gcref):
            toggle_gcflag_extra(gcref)
            w_obj = callback(gcref)
            if w_obj is not None:
                result_w.append(w_obj)
            pending.extend(get_rpy_referents(gcref))
    clear_gcflag_extra(roots)
    assert_no_more_gcflags()
    return result_w

class RegisterCustomLightFinalizer(ExtRegistryEntry):
    _about_ = register_custom_light_finalizer

    def compute_result_annotation(self, s_tp, s_lambda_func):
        pass

    def specialize_call(self, hop):
        from rpython.rtyper.llannotation import SomePtr
        TP = hop.args_s[0].const
        lambda_func = hop.args_s[1].const
        ll_func = lambda_func()
        args_s = [SomePtr(lltype.Ptr(TP))]
        funcptr = hop.rtyper.annotate_helper_fn(ll_func, args_s)
        hop.exception_cannot_occur()
        lltype.attachRuntimeTypeInfo(TP, destrptr=funcptr)

def clear_gcflag_extra(fromlist):
    pending = fromlist[:]
    while pending:
        gcref = pending.pop()
        if get_gcflag_extra(gcref):
            toggle_gcflag_extra(gcref)
            pending.extend(get_rpy_referents(gcref))

all_typeids = {}
        
def get_typeid(obj):
    raise Exception("does not work untranslated")

class GetTypeidEntry(ExtRegistryEntry):
    _about_ = get_typeid

    def compute_result_annotation(self, s_obj):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop('gc_gettypeid', hop.args_v, resulttype=lltype.Signed)

# ____________________________________________________________


class _rawptr_missing_item(object):
    pass
_rawptr_missing_item = _rawptr_missing_item()


class _ResizableListSupportingRawPtr(list):
    """Calling this class is a no-op after translation.

    Before translation, it returns a new instance of
    _ResizableListSupportingRawPtr, on which
    rgc.nonmoving_raw_ptr_for_resizable_list() might be
    used if needed.  For now, only supports lists of chars.
    """
    __slots__ = ('_ll_list',)   # either None or a struct of TYPE=LIST_OF(Char)

    def __init__(self, lst):
        self._ll_list = None
        self.__from_list(lst)

    def __resize(self):
        """Called before an operation changes the size of the list"""
        if self._ll_list is not None:
            list.__init__(self, self.__as_list())
            self._ll_list = None

    def __from_list(self, lst):
        """Initialize the list from a copy of the list 'lst'."""
        assert isinstance(lst, list)
        for x in lst:
            assert isinstance(x, str) and len(x) == 1
        if self is lst:
            return
        if len(self) != len(lst):
            self.__resize()
        if self._ll_list is None:
            list.__init__(self, lst)
        else:
            assert len(self) == self._ll_list.length == len(lst)
            for i in range(len(self)):
                self._ll_list.items[i] = lst[i]

    def __as_list(self):
        """Return a list (the same or a different one) which contains the
        items in the regular way."""
        if self._ll_list is None:
            return self
        length = self._ll_list.length
        assert length == len(self)
        return [self._ll_list.items[i] for i in range(length)]

    def __getitem__(self, index):
        if self._ll_list is None:
            return list.__getitem__(self, index)
        if index < 0:
            index += len(self)
        if not (0 <= index < len(self)):
            raise IndexError
        return self._ll_list.items[index]

    def __setitem__(self, index, new):
        if self._ll_list is None:
            return list.__setitem__(self, index, new)
        if index < 0:
            index += len(self)
        if not (0 <= index < len(self)):
            raise IndexError
        self._ll_list.items[index] = new

    def __delitem__(self, index):
        self.__resize()
        list.__delitem__(self, index)

    def __getslice__(self, i, j):
        return self.__class__(list.__getslice__(self.__as_list(), i, j))

    def __setslice__(self, i, j, new):
        lst = self.__as_list()
        list.__setslice__(lst, i, j, new)
        self.__from_list(lst)

    def __delslice__(self, i, j):
        lst = self.__as_list()
        list.__delslice__(lst, i, j)
        self.__from_list(lst)

    def __iter__(self):
        try:
            i = 0
            while True:
                yield self[i]
                i += 1
        except IndexError:
            pass

    def __reversed__(self):
        i = len(self)
        while i > 0:
            i -= 1
            yield self[i]

    def __contains__(self, item):
        return list.__contains__(self.__as_list(), item)

    def __add__(self, other):
        if isinstance(other, _ResizableListSupportingRawPtr):
            other = other.__as_list()
        return list.__add__(self.__as_list(), other)

    def __radd__(self, other):
        if isinstance(other, _ResizableListSupportingRawPtr):
            other = other.__as_list()
        return list.__add__(other, self.__as_list())

    def __iadd__(self, other):
        self.__resize()
        return list.__iadd__(self, other)

    def __eq__(self, other):
        return list.__eq__(self.__as_list(), other)
    def __ne__(self, other):
        return list.__ne__(self.__as_list(), other)
    def __ge__(self, other):
        return list.__ge__(self.__as_list(), other)
    def __gt__(self, other):
        return list.__gt__(self.__as_list(), other)
    def __le__(self, other):
        return list.__le__(self.__as_list(), other)
    def __lt__(self, other):
        return list.__lt__(self.__as_list(), other)

    def __mul__(self, other):
        return list.__mul__(self.__as_list(), other)

    def __rmul__(self, other):
        return list.__mul__(self.__as_list(), other)

    def __imul__(self, other):
        self.__resize()
        return list.__imul__(self, other)

    def __repr__(self):
        return '_ResizableListSupportingRawPtr(%s)' % (
            list.__repr__(self.__as_list()),)

    def append(self, object):
        self.__resize()
        return list.append(self, object)

    def count(self, value):
        return list.count(self.__as_list(), value)

    def extend(self, iterable):
        self.__resize()
        return list.extend(self, iterable)

    def index(self, value, *start_stop):
        return list.index(self.__as_list(), value, *start_stop)

    def insert(self, index, object):
        self.__resize()
        return list.insert(self, index, object)

    def pop(self, *opt_index):
        self.__resize()
        return list.pop(self, *opt_index)

    def remove(self, value):
        self.__resize()
        return list.remove(self, value)

    def reverse(self):
        lst = self.__as_list()
        list.reverse(lst)
        self.__from_list(lst)

    def sort(self, *args, **kwds):
        lst = self.__as_list()
        list.sort(lst, *args, **kwds)
        self.__from_list(lst)

    def _get_ll_list(self):
        from rpython.rtyper.lltypesystem import rffi
        from rpython.rtyper.lltypesystem.rlist import LIST_OF
        if self._ll_list is None:
            LIST = LIST_OF(lltype.Char)
            existing_items = list(self)
            n = len(self)
            self._ll_list = lltype.malloc(LIST, immortal=True)
            self._ll_list.length = n
            self._ll_list.items = lltype.malloc(LIST.items.TO, n)
            self.__from_list(existing_items)
            assert self._ll_list is not None
        return self._ll_list

    def _nonmoving_raw_ptr_for_resizable_list(self):
        ll_list = self._get_ll_list()
        return ll_nonmovable_raw_ptr_for_resizable_list(ll_list)

def resizable_list_supporting_raw_ptr(lst):
    return _ResizableListSupportingRawPtr(lst)

def nonmoving_raw_ptr_for_resizable_list(lst):
    if must_split_gc_address_space():
        raise ValueError
    return _nonmoving_raw_ptr_for_resizable_list(lst)

def _nonmoving_raw_ptr_for_resizable_list(lst):
    assert isinstance(lst, _ResizableListSupportingRawPtr)
    return lst._nonmoving_raw_ptr_for_resizable_list()

def ll_for_resizable_list(lst):
    """
    This is the equivalent of llstr(), but for lists. It can be called only if
    the list has been created by calling resizable_list_supporting_raw_ptr().

    In theory, all the operations on lst are immediately visible also on
    ll_list. However, support for that is incomplete in
    _ResizableListSupportingRawPtr and as such, the pointer becomes invalid as
    soon as you call a resizing operation on lst.
    """
    assert isinstance(lst, _ResizableListSupportingRawPtr)
    return lst._get_ll_list()

def _check_resizable_list_of_chars(s_list):
    from rpython.annotator import model as annmodel
    from rpython.rlib import debug
    if annmodel.s_None.contains(s_list):
        return    # "None", will likely be generalized later
    if not isinstance(s_list, annmodel.SomeList):
        raise Exception("not a list, got %r" % (s_list,))
    if not isinstance(s_list.listdef.listitem.s_value,
                      (annmodel.SomeChar, annmodel.SomeImpossibleValue)):
        raise debug.NotAListOfChars
    s_list.listdef.resize()    # must be resizable

class Entry(ExtRegistryEntry):
    _about_ = resizable_list_supporting_raw_ptr

    def compute_result_annotation(self, s_list):
        _check_resizable_list_of_chars(s_list)
        return s_list

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem.rlist import LIST_OF
        if hop.args_r[0].LIST != LIST_OF(lltype.Char):
            raise ValueError('Resizable list of chars does not have the '
                             'expected low-level type')
        hop.exception_cannot_occur()
        return hop.inputarg(hop.args_r[0], 0)

class Entry(ExtRegistryEntry):
    _about_ = _nonmoving_raw_ptr_for_resizable_list

    def compute_result_annotation(self, s_list):
        from rpython.rtyper.lltypesystem import lltype, rffi
        from rpython.rtyper.llannotation import SomePtr
        _check_resizable_list_of_chars(s_list)
        return SomePtr(rffi.CCHARP)

    def specialize_call(self, hop):
        v_list = hop.inputarg(hop.args_r[0], 0)
        hop.exception_cannot_occur()   # ignoring MemoryError
        return hop.gendirectcall(ll_nonmovable_raw_ptr_for_resizable_list,
                                 v_list)

class Entry(ExtRegistryEntry):
    _about_ = ll_for_resizable_list

    def compute_result_annotation(self, s_list):
        from rpython.rtyper.lltypesystem.rlist import LIST_OF
        from rpython.rtyper.llannotation import lltype_to_annotation
        _check_resizable_list_of_chars(s_list)
        LIST = LIST_OF(lltype.Char)
        return lltype_to_annotation(lltype.Ptr(LIST))

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        assert hop.args_r[0].lowleveltype == hop.r_result.lowleveltype
        v_ll_list, = hop.inputargs(*hop.args_r)
        return hop.genop('same_as', [v_ll_list],
                         resulttype = hop.r_result.lowleveltype)


@jit.dont_look_inside
def ll_nonmovable_raw_ptr_for_resizable_list(ll_list):
    """
    WARNING: dragons ahead.
    Return the address of the internal char* buffer of 'll_list', which
    must be a resizable list of chars.

    This makes sure that the list items are non-moving, if necessary by
    first copying the GcArray inside 'll_list.items' outside the GC
    nursery.  The returned 'char *' pointer is guaranteed to be valid
    until one of these occurs:

       * 'll_list' gets garbage-collected; or
       * you do an operation on 'll_list' that changes its size.
    """
    from rpython.rtyper.lltypesystem import lltype, rffi
    array = ll_list.items
    if can_move(array):
        length = ll_list.length
        new_array = lltype.malloc(lltype.typeOf(ll_list).TO.items.TO, length,
                                  nonmovable=True)
        ll_arraycopy(array, new_array, 0, 0, length)
        ll_list.items = new_array
        array = new_array
    ptr = lltype.direct_arrayitems(array)
    # ptr is a Ptr(FixedSizeArray(Char, 1)).  Cast it to a rffi.CCHARP
    return rffi.cast(rffi.CCHARP, ptr)

@jit.dont_look_inside
@no_collect
@specialize.ll()
def ll_write_final_null_char(s):
    """'s' is a low-level STR; writes a terminating NULL character after
    the other characters in 's'.  Warning, this only works because of
    the 'extra_item_after_alloc' hack inside the definition of STR.
    """
    from rpython.rtyper.lltypesystem import rffi
    PSTR = lltype.typeOf(s)
    assert has_final_null_char(PSTR) == 1
    n = llmemory.offsetof(PSTR.TO, 'chars')
    n += llmemory.itemoffsetof(PSTR.TO.chars, 0)
    n = llmemory.raw_malloc_usage(n)
    n += len(s.chars)
    # no GC operation from here!
    ptr = rffi.cast(rffi.CCHARP, s)
    ptr[n] = '\x00'

@specialize.memo()
def has_final_null_char(PSTR):
    return PSTR.TO.chars._hints.get('extra_item_after_alloc', 0)
