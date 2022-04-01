from rpython.rtyper.lltypesystem import lltype, llmemory, llarena, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.debug import ll_assert
from rpython.memory.gcheader import GCHeaderBuilder
from rpython.memory.support import DEFAULT_CHUNK_SIZE
from rpython.memory.support import get_address_stack, get_address_deque
from rpython.memory.support import AddressDict, null_address_dict
from rpython.memory.gc.hook import GcHooks
from rpython.rtyper.lltypesystem.llmemory import NULL, raw_malloc_usage
from rpython.rtyper.annlowlevel import cast_adr_to_nongc_instance

TYPEID_MAP = lltype.GcStruct('TYPEID_MAP', ('count', lltype.Signed),
                             ('size', lltype.Signed),
                             ('links', lltype.Array(lltype.Signed)))
ARRAY_TYPEID_MAP = lltype.GcArray(lltype.Ptr(TYPEID_MAP))

class GCBase(object):
    _alloc_flavor_ = "raw"
    moving_gc = False
    needs_write_barrier = False
    malloc_zero_filled = False
    prebuilt_gc_objects_are_static_roots = True
    can_usually_pin_objects = False
    object_minimal_size = 0
    gcflag_extra = 0   # or a dedicated GC flag that the GC initializes to 0
    gcflag_dummy = 0   # dedicated GC flag set only on rmodel.ll_dummy_value
    _totalroots_rpy = 0   # for inspector.py

    def __init__(self, config, chunk_size=DEFAULT_CHUNK_SIZE,
                 translated_to_c=True, hooks=None):
        self.gcheaderbuilder = GCHeaderBuilder(self.HDR)
        self.AddressStack = get_address_stack(chunk_size)
        self.AddressDeque = get_address_deque(chunk_size)
        self.AddressDict = AddressDict
        self.null_address_dict = null_address_dict
        self.config = config
        assert isinstance(translated_to_c, bool)
        self.translated_to_c = translated_to_c
        if hooks is None:
            hooks = GcHooks() # the default hooks are empty
        self.hooks = hooks

    def setup(self):
        # all runtime mutable values' setup should happen here
        # and in its overriden versions! for the benefit of test_transformed_gc
        self.finalizer_lock = False
        self.run_old_style_finalizers = self.AddressDeque()

    def mark_finalizer_to_run(self, fq_index, obj):
        if fq_index == -1:   # backward compatibility with old-style finalizer
            self.run_old_style_finalizers.append(obj)
            return
        handlers = self.finalizer_handlers()
        self._adr2deque(handlers[fq_index].deque).append(obj)

    def post_setup(self):
        # More stuff that needs to be initialized when the GC is already
        # fully working.  (Only called by gctransform/framework for now.)
        from rpython.memory.gc import env
        self.DEBUG = env.read_from_env('PYPY_GC_DEBUG')

    def _teardown(self):
        pass

    def can_optimize_clean_setarrayitems(self):
        return True     # False in case of card marking

    # The following flag enables costly consistency checks after each
    # collection.  It is automatically set to True by test_gc.py.  The
    # checking logic is translatable, so the flag can be set to True
    # here before translation.  At run-time, if PYPY_GC_DEBUG is set,
    # then it is also set to True.
    DEBUG = False

    def set_query_functions(self, is_varsize, has_gcptr_in_varsize,
                            is_gcarrayofgcptr,
                            finalizer_handlers,
                            destructor_or_custom_trace,
                            is_old_style_finalizer,
                            offsets_to_gc_pointers,
                            fixed_size, varsize_item_sizes,
                            varsize_offset_to_variable_part,
                            varsize_offset_to_length,
                            varsize_offsets_to_gcpointers_in_var_part,
                            weakpointer_offset,
                            member_index,
                            is_rpython_class,
                            has_custom_trace,
                            fast_path_tracing,
                            has_gcptr,
                            cannot_pin,
                            has_memory_pressure,
                            get_memory_pressure_ofs):
        self.finalizer_handlers = finalizer_handlers
        self.destructor_or_custom_trace = destructor_or_custom_trace
        self.is_old_style_finalizer = is_old_style_finalizer
        self.is_varsize = is_varsize
        self.has_gcptr_in_varsize = has_gcptr_in_varsize
        self.is_gcarrayofgcptr = is_gcarrayofgcptr
        self.offsets_to_gc_pointers = offsets_to_gc_pointers
        self.fixed_size = fixed_size
        self.varsize_item_sizes = varsize_item_sizes
        self.varsize_offset_to_variable_part = varsize_offset_to_variable_part
        self.varsize_offset_to_length = varsize_offset_to_length
        self.varsize_offsets_to_gcpointers_in_var_part = varsize_offsets_to_gcpointers_in_var_part
        self.weakpointer_offset = weakpointer_offset
        self.member_index = member_index
        self.is_rpython_class = is_rpython_class
        self.has_custom_trace = has_custom_trace
        self.fast_path_tracing = fast_path_tracing
        self.has_gcptr = has_gcptr
        self.cannot_pin = cannot_pin
        self.has_memory_pressure = has_memory_pressure
        self.get_memory_pressure_ofs = get_memory_pressure_ofs

    def get_member_index(self, type_id):
        return self.member_index(type_id)

    def set_root_walker(self, root_walker):
        self.root_walker = root_walker

    def write_barrier(self, addr_struct):
        pass

    def size_gc_header(self, typeid=0):
        return self.gcheaderbuilder.size_gc_header

    def header(self, addr):
        addr -= self.gcheaderbuilder.size_gc_header
        return llmemory.cast_adr_to_ptr(addr, lltype.Ptr(self.HDR))

    def _get_size_for_typeid(self, obj, typeid):
        size = self.fixed_size(typeid)
        if self.is_varsize(typeid):
            lenaddr = obj + self.varsize_offset_to_length(typeid)
            length = lenaddr.signed[0]
            size += length * self.varsize_item_sizes(typeid)
            size = llarena.round_up_for_allocation(size)
            # XXX maybe we should parametrize round_up_for_allocation()
            # per GC; if we do, we also need to fix the call in
            # gctypelayout.encode_type_shape()
        return size

    def get_size(self, obj):
        return self._get_size_for_typeid(obj, self.get_type_id(obj))

    def get_type_id_cast(self, obj):
        return rffi.cast(lltype.Signed, self.get_type_id(obj))

    def get_size_incl_hash(self, obj):
        return self.get_size(obj)

    # these can be overriden by subclasses, called by the GCTransformer
    def enable(self):
        pass

    def disable(self):
        pass

    def isenabled(self):
        return True

    def collect_step(self):
        self.collect()
        return True

    def malloc(self, typeid, length=0, zero=False):
        """NOT_RPYTHON
        For testing.  The interface used by the gctransformer is
        the four malloc_[fixed,var]size[_clear]() functions.
        """
        size = self.fixed_size(typeid)
        needs_finalizer = (bool(self.destructor_or_custom_trace(typeid))
                           and not self.has_custom_trace(typeid))
        finalizer_is_light = (needs_finalizer and
                              not self.is_old_style_finalizer(typeid))
        contains_weakptr = self.weakpointer_offset(typeid) >= 0
        assert not (needs_finalizer and contains_weakptr)
        if self.is_varsize(typeid):
            assert not contains_weakptr
            assert not needs_finalizer
            itemsize = self.varsize_item_sizes(typeid)
            offset_to_length = self.varsize_offset_to_length(typeid)
            if self.malloc_zero_filled:
                malloc_varsize = self.malloc_varsize_clear
            else:
                malloc_varsize = self.malloc_varsize
            ref = malloc_varsize(typeid, length, size, itemsize,
                                 offset_to_length)
            size += itemsize * length
        else:
            if self.malloc_zero_filled:
                malloc_fixedsize = self.malloc_fixedsize_clear
            else:
                malloc_fixedsize = self.malloc_fixedsize
            ref = malloc_fixedsize(typeid, size, needs_finalizer,
                                   finalizer_is_light,
                                   contains_weakptr)
        # lots of cast and reverse-cast around...
        ref = llmemory.cast_ptr_to_adr(ref)
        if zero and not self.malloc_zero_filled:
            llmemory.raw_memclear(ref, size)
        return ref

    def id(self, ptr):
        return lltype.cast_ptr_to_int(ptr)

    def can_move(self, addr):
        return False

    def malloc_fixed_or_varsize_nonmovable(self, typeid, length):
        raise MemoryError

    def pin(self, addr):
        return False

    def unpin(self, addr):
        pass

    def _is_pinned(self, addr):
        return False

    def set_max_heap_size(self, size):
        raise NotImplementedError

    def trace(self, obj, callback, arg):
        """Enumerate the locations inside the given obj that can contain
        GC pointers.  For each such location, callback(pointer, arg) is
        called, where 'pointer' is an address inside the object.
        Typically, 'callback' is a bound method and 'arg' can be None.
        """
        typeid = self.get_type_id(obj)
        #
        # First, look if we need more than the simple fixed-size tracing
        if not self.fast_path_tracing(typeid):
            #
            # Yes.  Two cases: either we are just a GcArray(gcptr), for
            # which we have a special case for performance, or we call
            # the slow path version.
            if self.is_gcarrayofgcptr(typeid):
                length = (obj + llmemory.gcarrayofptr_lengthoffset).signed[0]
                item = obj + llmemory.gcarrayofptr_itemsoffset
                while length > 0:
                    if self.points_to_valid_gc_object(item):
                        callback(item, arg)
                    item += llmemory.gcarrayofptr_singleitemoffset
                    length -= 1
                return
            self._trace_slow_path(obj, callback, arg)
        #
        # Do the tracing on the fixed-size part of the object.
        offsets = self.offsets_to_gc_pointers(typeid)
        i = 0
        while i < len(offsets):
            item = obj + offsets[i]
            if self.points_to_valid_gc_object(item):
                callback(item, arg)
            i += 1
    trace._annspecialcase_ = 'specialize:arg(2)'

    def _trace_slow_path(self, obj, callback, arg):
        typeid = self.get_type_id(obj)
        if self.has_gcptr_in_varsize(typeid):
            length = (obj + self.varsize_offset_to_length(typeid)).signed[0]
            if length > 0:
                item = obj + self.varsize_offset_to_variable_part(typeid)
                offsets = self.varsize_offsets_to_gcpointers_in_var_part(typeid)
                itemlength = self.varsize_item_sizes(typeid)
                len_offsets = len(offsets)
                if len_offsets == 1:     # common path #1
                    offsets0 = offsets[0]
                    while length > 0:
                        itemobj0 = item + offsets0
                        if self.points_to_valid_gc_object(itemobj0):
                            callback(itemobj0, arg)
                        item += itemlength
                        length -= 1
                elif len_offsets == 2:   # common path #2
                    offsets0 = offsets[0]
                    offsets1 = offsets[1]
                    while length > 0:
                        itemobj0 = item + offsets0
                        if self.points_to_valid_gc_object(itemobj0):
                            callback(itemobj0, arg)
                        itemobj1 = item + offsets1
                        if self.points_to_valid_gc_object(itemobj1):
                            callback(itemobj1, arg)
                        item += itemlength
                        length -= 1
                else:                    # general path
                    while length > 0:
                        j = 0
                        while j < len_offsets:
                            itemobj = item + offsets[j]
                            if self.points_to_valid_gc_object(itemobj):
                                callback(itemobj, arg)
                            j += 1
                        item += itemlength
                        length -= 1
        if self.has_custom_trace(typeid):
            self.custom_trace_dispatcher(obj, typeid, callback, arg)
    _trace_slow_path._annspecialcase_ = 'specialize:arg(2)'

    def _trace_callback(self, callback, arg, addr):
        if self.is_valid_gc_object(addr.address[0]):
            callback(addr, arg)
    _trace_callback._annspecialcase_ = 'specialize:arg(1)'

    def trace_partial(self, obj, start, stop, callback, arg):
        """Like trace(), but only walk the array part, for indices in
        range(start, stop).  Must only be called if has_gcptr_in_varsize().
        """
        length = stop - start
        typeid = self.get_type_id(obj)
        if self.is_gcarrayofgcptr(typeid):
            # a performance shortcut for GcArray(gcptr)
            item = obj + llmemory.gcarrayofptr_itemsoffset
            item += llmemory.gcarrayofptr_singleitemoffset * start
            while length > 0:
                if self.points_to_valid_gc_object(item):
                    callback(item, arg)
                item += llmemory.gcarrayofptr_singleitemoffset
                length -= 1
            return
        ll_assert(self.has_gcptr_in_varsize(typeid),
                  "trace_partial() on object without has_gcptr_in_varsize()")
        item = obj + self.varsize_offset_to_variable_part(typeid)
        offsets = self.varsize_offsets_to_gcpointers_in_var_part(typeid)
        itemlength = self.varsize_item_sizes(typeid)
        item += itemlength * start
        while length > 0:
            j = 0
            while j < len(offsets):
                itemobj = item + offsets[j]
                if self.points_to_valid_gc_object(itemobj):
                    callback(itemobj, arg)
                j += 1
            item += itemlength
            length -= 1
    trace_partial._annspecialcase_ = 'specialize:arg(4)'

    def points_to_valid_gc_object(self, addr):
        return self.is_valid_gc_object(addr.address[0])

    def is_valid_gc_object(self, addr):
        return (addr != NULL and
                (not self.config.taggedpointers or
                 llmemory.cast_adr_to_int(addr) & 1 == 0))

    def enumerate_all_roots(self, callback, arg):
        """For each root object, invoke callback(obj, arg).
        'callback' should not be a bound method.
        Note that this method is not suitable for actually doing the
        collection in a moving GC, because you cannot write back a
        modified address.  It is there only for inspection.
        """
        # overridden in some subclasses, for GCs which have an additional
        # list of last generation roots
        callback2, attrname = _convert_callback_formats(callback)    # :-/
        setattr(self, attrname, arg)
        self.root_walker.walk_roots(callback2, callback2, callback2)
        self.enum_live_with_finalizers(callback, arg)
        self.enum_pending_finalizers(callback, arg)
    enumerate_all_roots._annspecialcase_ = 'specialize:arg(1)'

    def enum_pending_finalizers(self, callback, arg):
        self.run_old_style_finalizers.foreach(callback, arg)
        handlers = self.finalizer_handlers()
        i = 0
        while i < len(handlers):
            self._adr2deque(handlers[i].deque).foreach(callback, arg)
            i += 1
    enum_pending_finalizers._annspecialcase_ = 'specialize:arg(1)'

    def enum_live_with_finalizers(self, callback, arg):
        # as far as possible, enumerates the live objects with finalizers,
        # even if they have not been detected as unreachable yet (but may be)
        pass
    enum_live_with_finalizers._annspecialcase_ = 'specialize:arg(1)'

    def _copy_pending_finalizers_deque(self, deque, copy_fn):
        tmp = self.AddressDeque()
        while deque.non_empty():
            obj = deque.popleft()
            tmp.append(copy_fn(obj))
        while tmp.non_empty():
            deque.append(tmp.popleft())
        tmp.delete()

    def copy_pending_finalizers(self, copy_fn):
        "NOTE: not very efficient, but only for SemiSpaceGC and subclasses"
        self._copy_pending_finalizers_deque(
            self.run_old_style_finalizers, copy_fn)
        handlers = self.finalizer_handlers()
        i = 0
        while i < len(handlers):
            h = handlers[i]
            self._copy_pending_finalizers_deque(
                self._adr2deque(h.deque), copy_fn)
            i += 1

    def call_destructor(self, obj):
        destructor = self.destructor_or_custom_trace(self.get_type_id(obj))
        ll_assert(bool(destructor), "no destructor found")
        destructor(obj)

    def debug_check_consistency(self):
        """To use after a collection.  If self.DEBUG is set, this
        enumerates all roots and traces all objects to check if we didn't
        accidentally free a reachable object or forgot to update a pointer
        to an object that moved.
        """
        if self.DEBUG:
            from rpython.rlib.objectmodel import we_are_translated
            from rpython.memory.support import AddressDict
            self._debug_seen = AddressDict()
            self._debug_pending = self.AddressStack()
            if not we_are_translated():
                self.root_walker._walk_prebuilt_gc(self._debug_record)
            self.enumerate_all_roots(GCBase._debug_callback, self)
            pending = self._debug_pending
            while pending.non_empty():
                obj = pending.pop()
                self.trace(obj, self._debug_callback2, None)
            self._debug_seen.delete()
            self._debug_pending.delete()

    def _debug_record(self, obj):
        seen = self._debug_seen
        if not seen.contains(obj):
            seen.add(obj)
            self.debug_check_object(obj)
            self._debug_pending.append(obj)
    @staticmethod
    def _debug_callback(obj, self):
        self._debug_record(obj)
    def _debug_callback2(self, pointer, ignored):
        obj = pointer.address[0]
        ll_assert(bool(obj), "NULL address from self.trace()")
        self._debug_record(obj)

    def debug_check_object(self, obj):
        pass

    def _adr2deque(self, adr):
        return cast_adr_to_nongc_instance(self.AddressDeque, adr)

    def execute_finalizers(self):
        if self.finalizer_lock:
            return  # the outer invocation of execute_finalizers() will do it
        self.finalizer_lock = True
        try:
            handlers = self.finalizer_handlers()
            i = 0
            while i < len(handlers):
                if self._adr2deque(handlers[i].deque).non_empty():
                    handlers[i].trigger()
                i += 1
            while self.run_old_style_finalizers.non_empty():
                obj = self.run_old_style_finalizers.popleft()
                self.call_destructor(obj)
        finally:
            self.finalizer_lock = False


class MovingGCBase(GCBase):
    moving_gc = True

    def setup(self):
        GCBase.setup(self)
        self.objects_with_id = self.AddressDict()
        self.id_free_list = self.AddressStack()
        self.next_free_id = 1

    def can_move(self, addr):
        return True

    def id(self, ptr):
        # Default implementation for id(), assuming that "external" objects
        # never move.  Overriden in the HybridGC.
        obj = llmemory.cast_ptr_to_adr(ptr)

        # is it a tagged pointer? or an external object?
        if not self.is_valid_gc_object(obj) or self._is_external(obj):
            return llmemory.cast_adr_to_int(obj)

        # tagged pointers have ids of the form 2n + 1
        # external objects have ids of the form 4n (due to word alignment)
        # self._compute_id returns addresses of the form 2n + 1
        # if we multiply by 2, we get ids of the form 4n + 2, thus we get no
        # clashes
        return llmemory.cast_adr_to_int(self._compute_id(obj)) * 2

    def _next_id(self):
        # return an id not currently in use (as an address instead of an int)
        if self.id_free_list.non_empty():
            result = self.id_free_list.pop()    # reuse a dead id
        else:
            # make up a fresh id number
            result = llmemory.cast_int_to_adr(self.next_free_id)
            self.next_free_id += 2    # only odd numbers, to make lltype
                                      # and llmemory happy and to avoid
                                      # clashes with real addresses
        return result

    def _compute_id(self, obj):
        # look if the object is listed in objects_with_id
        result = self.objects_with_id.get(obj)
        if not result:
            result = self._next_id()
            self.objects_with_id.setitem(obj, result)
        return result

    def update_objects_with_id(self):
        old = self.objects_with_id
        new_objects_with_id = self.AddressDict(old.length())
        old.foreach(self._update_object_id_FAST, new_objects_with_id)
        old.delete()
        self.objects_with_id = new_objects_with_id

    def _update_object_id(self, obj, id, new_objects_with_id):
        # safe version (used by subclasses)
        if self.surviving(obj):
            newobj = self.get_forwarding_address(obj)
            new_objects_with_id.setitem(newobj, id)
        else:
            self.id_free_list.append(id)

    def _update_object_id_FAST(self, obj, id, new_objects_with_id):
        # unsafe version, assumes that the new_objects_with_id is large enough
        if self.surviving(obj):
            newobj = self.get_forwarding_address(obj)
            new_objects_with_id.insertclean(newobj, id)
        else:
            self.id_free_list.append(id)


def choose_gc_from_config(config):
    """Return a (GCClass, GC_PARAMS) from the given config object.
    """
    if config.translation.gctransformer != "framework":
        raise AssertionError("fix this test")

    classes = {"semispace": "semispace.SemiSpaceGC",
               "generation": "generation.GenerationGC",
               "hybrid": "hybrid.HybridGC",
               "minimark" : "minimark.MiniMarkGC",
               "incminimark" : "incminimark.IncrementalMiniMarkGC",
               }
    try:
        modulename, classname = classes[config.translation.gc].split('.')
    except KeyError:
        raise ValueError("unknown value for translation.gc: %r" % (
            config.translation.gc,))
    module = __import__("rpython.memory.gc." + modulename,
                        globals(), locals(), [classname])
    GCClass = getattr(module, classname)
    return GCClass, GCClass.TRANSLATION_PARAMS

def _convert_callback_formats(callback):
    callback = getattr(callback, 'im_func', callback)
    if callback not in _converted_callback_formats:
        def callback2(gc, root):
            obj = root.address[0]
            ll_assert(bool(obj), "NULL address from walk_roots()")
            callback(obj, getattr(gc, attrname))
        attrname = '_callback2_arg%d' % len(_converted_callback_formats)
        _converted_callback_formats[callback] = callback2, attrname
    return _converted_callback_formats[callback]

_convert_callback_formats._annspecialcase_ = 'specialize:memo'
_converted_callback_formats = {}
